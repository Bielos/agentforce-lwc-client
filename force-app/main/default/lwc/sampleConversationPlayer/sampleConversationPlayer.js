import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getConversation from "@salesforce/apex/SampleConversationController.getConversation";
import saveTranscript from "@salesforce/apex/SampleConversationController.saveTranscript";
import getSkillContent from "@salesforce/apex/SampleConversationController.getSkillContent";
import sendAgentMessage from "@salesforce/apex/AgentforceService.sendMessage";
import getConfiguredAgents from "@salesforce/apex/AgentforceService.getConfiguredAgents";
import {
  parseTranscript,
  serializeTranscript
} from "c/sampleConversationTranscript";

const ROLE = Object.freeze({ USER: "user", AGENT: "agent" });

export default class SampleConversationPlayer extends LightningElement {
  @api recordId;

  @track turns = [];
  @track agentOptions = [];
  conversationName = "";
  skillApiName = "";
  agentApiName = "";
  agentOptionsLoaded = false;

  isLoading = false;
  isPlaying = false;
  isSaving = false;
  isDirty = false;
  isEditing = false;
  errorMessage = "";

  _sessionId = null;
  _turnSeq = 0;
  _captured = [];
  _lastUserAt = null;

  connectedCallback() {
    this.loadConversation();
  }

  async loadConversation() {
    if (!this.recordId) {
      this.errorMessage =
        "Open this component on a Sample Conversation record.";
      return;
    }
    this.isLoading = true;
    this.errorMessage = "";
    try {
      const record = await getConversation({ recordId: this.recordId });
      this.conversationName = record?.Name || "";
      this.skillApiName = (record?.Skill_API_Name__c || "").trim();
      this.agentApiName = (record?.Agent_API_Name__c || "").trim();
      this.turns = this.parseTranscript(record?.Transcript__c || "");
      this.isDirty = false;
      // Empty transcripts open in the editor; existing ones open in the
      // richer chat view.
      this.isEditing = this.turns.length === 0;
      this.loadAgents();
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.isLoading = false;
    }
  }

  async loadAgents() {
    if (this.agentOptionsLoaded) {
      return;
    }
    this.agentOptionsLoaded = true;
    try {
      const records = await getConfiguredAgents();
      this.agentOptions = (Array.isArray(records) ? records : [])
        .map((record) => ({
          value: (record?.agentApiName || "").trim(),
          label:
            record?.label && record.label !== record.agentApiName
              ? `${record.label} (${record.agentApiName})`
              : (record?.agentApiName || "").trim()
        }))
        .filter((option) => option.value.length > 0);
    } catch {
      this.agentOptions = [];
    }
  }

  // --- Derived state -------------------------------------------------------

  get hasTurns() {
    return this.turns.length > 0;
  }

  get showEmptyState() {
    return (
      this.isEditing && !this.isLoading && !this.hasTurns && !this.errorMessage
    );
  }

  get showEditor() {
    return this.isEditing;
  }

  get showChat() {
    return !this.isEditing && !this.isLoading;
  }

  get editToggleLabel() {
    return this.isEditing ? "View" : "Edit";
  }

  get editToggleIcon() {
    return this.isEditing ? "utility:preview" : "utility:edit";
  }

  // User turns from the scripted transcript, offered as clickable prompts in the
  // embedded chat so a reviewer can replay the conversation quickly.
  get samplePromptsSeed() {
    return this.turns
      .filter((turn) => turn.role === ROLE.USER && turn.content.trim())
      .map((turn) => turn.content.trim())
      .join("\n");
  }

  // The stored transcript mapped to the message shape c-agentforce-chat renders,
  // so the chat is populated with our sample conversation.
  get chatSeedMessages() {
    return this.turns
      .filter((turn) => turn.content && turn.content.trim())
      .map((turn) => ({
        role: turn.role === ROLE.USER ? "user" : "assistant",
        content: turn.content,
        durationMs: turn.durationMs
      }));
  }

  get chatPlayDisabled() {
    return !this.hasTurns || !this.agentApiName;
  }

  get displayTurns() {
    return this.turns.map((turn) => ({
      ...turn,
      roleLabel: turn.role === ROLE.USER ? "User" : "Agent",
      hasDuration:
        turn.role === ROLE.AGENT && typeof turn.durationMs === "number",
      durationLabel: this.formatDuration(turn.durationMs),
      cssClass:
        turn.role === ROLE.USER
          ? "turn turn_user"
          : turn.updated
            ? "turn turn_agent turn_updated"
            : "turn turn_agent"
    }));
  }

  formatDuration(durationMs) {
    if (typeof durationMs !== "number") {
      return "";
    }
    if (durationMs < 1000) {
      return `${durationMs} ms`;
    }
    return `${(durationMs / 1000).toFixed(1)} s`;
  }

  get canPlay() {
    return this.hasTurns && !this.isPlaying && !this.isLoading;
  }

  get playDisabled() {
    return !this.canPlay || !this.agentApiName;
  }

  get saveDisabled() {
    return !this.isDirty || this.isSaving || this.isPlaying;
  }

  get missingAgent() {
    return this.hasTurns && !this.agentApiName;
  }

  get hasAgentOptions() {
    return this.agentOptions.length > 0;
  }

  get agentComboOptions() {
    // Make sure the current value is always selectable, even if it wasn't
    // returned by getConfiguredAgents (e.g. typed directly on the record).
    if (
      this.agentApiName &&
      !this.agentOptions.some((option) => option.value === this.agentApiName)
    ) {
      return [
        { label: this.agentApiName, value: this.agentApiName },
        ...this.agentOptions
      ];
    }
    return this.agentOptions;
  }

  get subtitle() {
    const parts = [];
    if (this.agentApiName) {
      parts.push(`Agent: ${this.agentApiName}`);
    }
    if (this.skillApiName) {
      parts.push(`Skill: ${this.skillApiName}`);
    }
    return parts.join("  •  ");
  }

  // --- Actions -------------------------------------------------------------

  async handlePlay() {
    if (this.playDisabled) {
      return;
    }
    this.isPlaying = true;
    this.errorMessage = "";
    this._sessionId = null;

    let skillContent = null;
    if (this.skillApiName) {
      try {
        skillContent = await getSkillContent({
          skillApiName: this.skillApiName
        });
      } catch {
        skillContent = null;
      }
    }

    const working = this.turns.map((turn) => ({ ...turn, updated: false }));
    this.turns = working;

    try {
      let firstUserTurn = true;
      for (let i = 0; i < working.length; i++) {
        if (working[i].role !== ROLE.USER) {
          continue;
        }
        const seed = firstUserTurn ? skillContent : null;
        firstUserTurn = false;
        // eslint-disable-next-line no-await-in-loop
        const reply = await this.sendTurn(working[i].content, seed);

        if (i + 1 < working.length && working[i + 1].role === ROLE.AGENT) {
          working[i + 1] = {
            ...working[i + 1],
            content: reply.content,
            durationMs: reply.durationMs,
            updated: true
          };
        } else {
          working.splice(i + 1, 0, {
            id: this.nextTurnId(),
            role: ROLE.AGENT,
            content: reply.content,
            durationMs: reply.durationMs,
            updated: true
          });
          i++;
        }
        this.turns = [...working];
        this.isDirty = true;
      }
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.isPlaying = false;
    }
  }

  async sendTurn(userText, skillContent) {
    const message = skillContent ? `${skillContent}\n\n${userText}` : userText;
    const startedAt = Date.now();
    const response = await sendAgentMessage({
      agentApiName: this.agentApiName,
      message,
      sessionId: this._sessionId
    });
    const durationMs = Date.now() - startedAt;
    if (response?.sessionId) {
      this._sessionId = response.sessionId;
    }
    return {
      content:
        response?.message?.content || "(no response returned by the agent)",
      durationMs
    };
  }

  handleAgentChange(event) {
    const value = (event.detail?.value ?? event.target?.value ?? "").trim();
    if (value === this.agentApiName) {
      return;
    }
    this.agentApiName = value;
    this.isDirty = true;
  }

  handleAddUserTurn() {
    this.addTurn(ROLE.USER);
  }

  handleAddAgentTurn() {
    this.addTurn(ROLE.AGENT);
  }

  addTurn(role) {
    if (this.isPlaying) {
      return;
    }
    this.turns = [
      ...this.turns,
      { id: this.nextTurnId(), role, content: "", updated: false }
    ];
    this.isDirty = true;
  }

  handleDeleteTurn(event) {
    if (this.isPlaying) {
      return;
    }
    const turnId = event.currentTarget.dataset.id;
    this.turns = this.turns.filter((turn) => turn.id !== turnId);
    this.isDirty = true;
  }

  handleTurnEdit(event) {
    const turnId = event.currentTarget.dataset.id;
    const value = event.target.value;
    this.turns = this.turns.map((turn) => {
      if (turn.id !== turnId) {
        return turn;
      }
      return { ...turn, content: value, updated: false };
    });
    this.isDirty = true;
  }

  async handleSave() {
    if (this.saveDisabled) {
      return;
    }
    this.isSaving = true;
    try {
      const serialized = this.serializeTranscript(this.turns);
      const totalMs = this.turns.reduce(
        (sum, turn) =>
          sum + (typeof turn.durationMs === "number" ? turn.durationMs : 0),
        0
      );
      await saveTranscript({
        recordId: this.recordId,
        transcript: serialized,
        agentApiName: this.agentApiName,
        durationSeconds: totalMs > 0 ? Math.round(totalMs / 10) / 100 : null
      });
      this.isDirty = false;
      this.turns = this.turns.map((turn) => ({ ...turn, updated: false }));
      this.toast("Saved", "Transcript updated.", "success");
    } catch (error) {
      this.toast("Save failed", this.readError(error), "error");
    } finally {
      this.isSaving = false;
    }
  }

  handleReload() {
    this.loadConversation();
  }

  handleToggleEdit() {
    if (this.isPlaying) {
      return;
    }
    // Leaving the chat view: start fresh capture next time it is opened.
    this.isEditing = !this.isEditing;
    if (this.isEditing) {
      this._captured = [];
      this._lastUserAt = null;
    }
  }

  // Drive playback through the reused chat component: reset capture, then ask
  // the chat to replay its (seeded) user turns against the agent.
  handleChatReplay() {
    const chat = this.template.querySelector("c-agentforce-chat");
    if (!chat) {
      return;
    }
    this._captured = [];
    this._lastUserAt = null;
    chat.replay();
  }

  // Callback fed by the embedded c-agentforce-chat: each turn it exchanges with
  // the agent is captured back into this component's transcript.
  handleChatMessage(event) {
    const message = event.detail?.message;
    if (!message?.content) {
      return;
    }
    let role;
    if (message.role === "user") {
      role = ROLE.USER;
      this._lastUserAt = Date.now();
    } else if (message.role === "assistant") {
      role = ROLE.AGENT;
    } else {
      return; // ignore system messages
    }

    const turn = {
      id: this.nextTurnId(),
      role,
      content: message.content,
      updated: role === ROLE.AGENT
    };
    if (role === ROLE.AGENT) {
      // Prefer the duration measured by the chat; fall back to our own timing.
      if (typeof message.durationMs === "number") {
        turn.durationMs = message.durationMs;
      } else if (this._lastUserAt) {
        turn.durationMs = Date.now() - this._lastUserAt;
      }
      this._lastUserAt = null;
    }

    this._captured = [...this._captured, turn];
    this.turns = [...this._captured];
    this.isDirty = true;
  }

  // --- Transcript parsing / serialization ----------------------------------

  // Delegates to the shared c/sampleConversationTranscript module, adding the
  // presentation fields (id, updated) this component needs per turn.
  parseTranscript(text) {
    return parseTranscript(text).map((turn) => ({
      ...turn,
      id: this.nextTurnId(),
      updated: false
    }));
  }

  serializeTranscript(turns) {
    return serializeTranscript(turns);
  }

  // --- Helpers -------------------------------------------------------------

  nextTurnId() {
    this._turnSeq += 1;
    return `turn-${this._turnSeq}`;
  }

  readError(error) {
    return (
      error?.body?.message ||
      error?.message ||
      "Something went wrong. Please try again."
    );
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
