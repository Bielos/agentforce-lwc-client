import { LightningElement, api, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getConversations from "@salesforce/apex/SampleConversationController.getConversations";
import saveTranscript from "@salesforce/apex/SampleConversationController.saveTranscript";
import importConversations from "@salesforce/apex/SampleConversationController.importConversations";
import {
  ROLE,
  parseTranscript,
  serializeTranscript
} from "c/sampleConversationTranscript";

const NO_SKILL = "(no skill)";
const IMPORT_FIELDS = [
  "Name",
  "Skill_API_Name__c",
  "Agent_API_Name__c",
  "Description__c",
  "Transcript__c"
];

function parseImportJson(text) {
  const parsed = JSON.parse(text);
  const rawRecords = Array.isArray(parsed)
    ? parsed
    : Array.isArray(parsed?.records)
      ? parsed.records
      : null;
  if (!rawRecords) {
    throw new Error(
      'JSON must be a { "records": [...] } tree, or an array of records.'
    );
  }

  const inputs = [];
  rawRecords.forEach((raw) => {
    if (!raw || typeof raw !== "object") {
      return;
    }
    const type = raw.attributes?.type;
    if (type && type !== "Sample_Conversation__c") {
      return;
    }
    const name = typeof raw.Name === "string" ? raw.Name.trim() : "";
    if (!name) {
      return;
    }
    const input = { Name: name };
    IMPORT_FIELDS.slice(1).forEach((field) => {
      const value = raw[field];
      if (value != null && String(value).length > 0) {
        input[field] = String(value);
      }
    });
    inputs.push(input);
  });
  return inputs;
}

function buildExportTree(records) {
  return {
    records: records.map((record, index) => {
      const item = {
        attributes: {
          type: "Sample_Conversation__c",
          referenceId: `SC_${index + 1}`
        },
        Name: record.Name
      };
      IMPORT_FIELDS.slice(1).forEach((field) => {
        const value = record[field];
        if (value != null && String(value).length > 0) {
          item[field] = String(value);
        }
      });
      return item;
    })
  };
}

export default class SampleConversationBatchPlayer extends NavigationMixin(
  LightningElement
) {
  @track conversations = [];
  selectedSkill = null;
  selectedId = null;
  isLoading = false;
  isImporting = false;
  isPlaying = false;
  errorMessage = "";

  _records = new Map();
  _detailCaptured = [];
  _detailLastUserAt = null;

  connectedCallback() {
    this.loadConversations();
  }

  async loadConversations() {
    this.isLoading = true;
    this.errorMessage = "";
    try {
      const records = await getConversations();
      this._records = new Map();
      this.conversations = (records || []).map((record) => {
        this._records.set(record.Id, record);
        return {
          id: record.Id,
          name: record.Name,
          description: record.Description__c || "",
          skill: (record.Skill_API_Name__c || "").trim() || NO_SKILL,
          agent: (record.Agent_API_Name__c || "").trim(),
          status: "",
          durationLabel:
            typeof record.Last_Play_Duration__c === "number"
              ? `${record.Last_Play_Duration__c} s`
              : "",
          lastPlayed:
            typeof record.Last_Play_Duration__c === "number"
              ? record.LastModifiedDate
              : null
        };
      });
      this.selectDefaultSkill();
    } catch (error) {
      this.errorMessage = this.readError(error);
    } finally {
      this.isLoading = false;
    }
  }

  // --- Skill picker --------------------------------------------------------

  // One selectable card per skill (with a conversation count), rendered as a
  // list in the left column — no dropdown, no grid.
  get skillList() {
    const counts = {};
    this.conversations.forEach((conversation) => {
      counts[conversation.skill] = (counts[conversation.skill] || 0) + 1;
    });
    return Object.keys(counts)
      .sort((a, b) => a.localeCompare(b))
      .map((key) => {
        const isSelected = key === this.selectedSkill;
        return {
          value: key,
          name: key,
          count: counts[key],
          isSelected,
          cardClass: isSelected ? "skill-card skill-card_active" : "skill-card"
        };
      });
  }

  get conversationsForSkill() {
    return this.conversations.filter(
      (conversation) => conversation.skill === this.selectedSkill
    );
  }

  // Conversation list decorated with selection state for the template.
  get conversationList() {
    return this.conversationsForSkill.map((conversation) => {
      const isSelected = conversation.id === this.selectedId;
      return {
        ...conversation,
        isSelected,
        itemClass: isSelected
          ? "conv-list__item conv-list__item_active"
          : "conv-list__item",
        metaLabel: [conversation.status, conversation.durationLabel]
          .filter(Boolean)
          .join(" · ")
      };
    });
  }

  get hasRows() {
    return this.conversations.length > 0;
  }

  get actionsDisabled() {
    return this.isPlaying || this.isLoading || this.isImporting;
  }

  get showSpinner() {
    return this.isLoading || this.isImporting;
  }

  get spinnerLabel() {
    return this.isImporting
      ? "Importing conversations"
      : "Loading conversations";
  }

  // Pick the first skill, then open its first conversation.
  selectDefaultSkill() {
    const skills = this.skillList;
    this.selectedSkill = skills.length ? skills[0].value : null;
    this.selectFirstConversation();
  }

  selectFirstConversation() {
    const list = this.conversationsForSkill;
    this.selectedId = list.length ? list[0].id : null;
  }

  handleSelectSkill(event) {
    this.selectedSkill = event.currentTarget.dataset.skill;
    this.selectFirstConversation();
  }

  handleSelectConversation(event) {
    this.selectedId = event.currentTarget.dataset.id;
  }

  // --- Right-hand detail pane ---------------------------------------------

  get detailConversation() {
    return this.conversations.find((c) => c.id === this.selectedId) || null;
  }

  get showDetail() {
    return Boolean(this.detailConversation);
  }

  get detailPlayDisabled() {
    const conversation = this.detailConversation;
    return this.isPlaying || !conversation || !conversation.agent;
  }

  // Single-element list so the detail (and its embedded chat) is keyed by the
  // selected id and remounts when the selection changes.
  get detailItems() {
    const conversation = this.detailConversation;
    if (!conversation) {
      return [];
    }
    return [
      {
        key: conversation.id,
        name: conversation.name,
        description: conversation.description,
        agent: conversation.agent,
        lastPlayedLabel: this.formatLastPlayed(conversation),
        seedMessages: this.buildSeedMessages(conversation.id)
      }
    ];
  }

  // "Last played" line for a conversation: only shown once it has a recorded
  // play duration, combined with when the transcript was last saved.
  formatLastPlayed(conversation) {
    if (!conversation.durationLabel) {
      return "";
    }
    const when = this.formatDateTime(conversation.lastPlayed);
    return when
      ? `Last played ${when} · ${conversation.durationLabel}`
      : `Last played · ${conversation.durationLabel}`;
  }

  formatDateTime(value) {
    if (!value) {
      return "";
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "";
    }
    return date.toLocaleString(undefined, {
      dateStyle: "medium",
      timeStyle: "short"
    });
  }

  // Replay through the embedded chat so turns stream in live (no blocking
  // overlay); capture them and persist once the replay finishes.
  async handlePlayDetail() {
    if (this.detailPlayDisabled) {
      return;
    }
    const id = this.selectedId;
    const chat = this.template.querySelector("c-agentforce-chat");
    if (!chat) {
      return;
    }
    this._detailCaptured = [];
    this._detailLastUserAt = null;
    this.isPlaying = true;
    try {
      await chat.replay();
      if (this._detailCaptured.length > 0) {
        const transcript = serializeTranscript(this._detailCaptured);
        const totalMs = this._detailCaptured.reduce(
          (sum, turn) =>
            sum + (typeof turn.durationMs === "number" ? turn.durationMs : 0),
          0
        );
        const record = this._records.get(id);
        const agent = (record?.Agent_API_Name__c || "").trim();
        const durationSeconds = this.toSeconds(totalMs);
        // Persist and fold the saved record back in, so the transcript,
        // duration and last-played time reflect what the server stored.
        const saved = await saveTranscript({
          recordId: id,
          transcript,
          agentApiName: agent,
          durationSeconds
        });
        const merged = {
          ...record,
          Transcript__c: transcript,
          Last_Play_Duration__c: durationSeconds,
          ...(saved || {})
        };
        this._records.set(id, merged);
        const savedDuration =
          typeof merged.Last_Play_Duration__c === "number"
            ? merged.Last_Play_Duration__c
            : durationSeconds;
        this.patchConversation(id, {
          status: "Done",
          durationLabel: `${savedDuration} s`,
          lastPlayed: merged.LastModifiedDate || new Date().toISOString()
        });
        this.toast("Played", "Conversation replayed and saved.", "success");
      }
    } catch (error) {
      this.patchConversation(id, {
        status: `Error — ${this.readError(error)}`
      });
      this.toast("Play failed", this.readError(error), "error");
    } finally {
      this.isPlaying = false;
    }
  }

  // Captures each turn the detail chat exchanges during a replay.
  handleDetailChatMessage(event) {
    const message = event.detail?.message;
    if (!message?.content) {
      return;
    }
    if (message.role === "user") {
      this._detailLastUserAt = Date.now();
      this._detailCaptured = [
        ...this._detailCaptured,
        { role: ROLE.USER, content: message.content }
      ];
    } else if (message.role === "assistant") {
      const turn = { role: ROLE.AGENT, content: message.content };
      if (typeof message.durationMs === "number") {
        turn.durationMs = message.durationMs;
      } else if (this._detailLastUserAt) {
        turn.durationMs = Date.now() - this._detailLastUserAt;
      }
      this._detailLastUserAt = null;
      this._detailCaptured = [...this._detailCaptured, turn];
    }
  }

  get showEmptyState() {
    return (
      !this.isLoading &&
      !this.isImporting &&
      !this.hasRows &&
      !this.errorMessage
    );
  }

  handleOpenRecord() {
    const id = this.selectedId;
    if (!id) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: id,
        objectApiName: "Sample_Conversation__c",
        actionName: "view"
      }
    });
  }

  // Map the stored transcript to the message shape c-agentforce-chat renders,
  // so the inline preview reuses the same chat component as the record page.
  buildSeedMessages(id) {
    const record = this._records.get(id);
    if (!record) {
      return [];
    }
    return parseTranscript(record.Transcript__c || "").map((turn) => ({
      role: turn.role === ROLE.USER ? "user" : "assistant",
      content: turn.content,
      durationMs: turn.durationMs
    }));
  }

  toSeconds(durationMs) {
    return Math.round(durationMs / 10) / 100;
  }

  handleRefresh() {
    this.loadConversations();
  }

  handleImportClick() {
    if (this.actionsDisabled) {
      return;
    }
    this.template.querySelector('[data-id="import-file"]')?.click();
  }

  handleDownloadClick() {
    if (this.actionsDisabled) {
      return;
    }
    const tree = this.getExportTree();
    if (!tree.records.length) {
      this.toast(
        "Download failed",
        "No sample conversations to download.",
        "error"
      );
      return;
    }
    const blob = new Blob([JSON.stringify(tree, null, 2)], {
      type: "application/json"
    });
    const url = URL.createObjectURL(blob);
    const anchor = this.template.querySelector('[data-id="download-file"]');
    if (!anchor) {
      URL.revokeObjectURL(url);
      return;
    }
    anchor.href = url;
    anchor.click();
    // Delay revoke so the browser can start the download.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  /**
   * Current conversations as a sample-data JSON tree, matching import.
   *
   * @return {{records: object[]}}
   */
  @api
  getExportTree() {
    return buildExportTree([...this._records.values()]);
  }

  async handleImportFile(event) {
    const input = event.target;
    const files = event.detail?.files || input.files;
    const file = files?.[0];
    if (!file || this.actionsDisabled) {
      this.resetFileInput(input);
      return;
    }
    try {
      await this.importJsonText(await this.readFileText(file));
    } finally {
      this.resetFileInput(input);
    }
  }

  /**
   * Parse a sample-data JSON tree (or record array) and create conversations.
   *
   * @param {string} text Raw JSON file contents.
   */
  @api
  async importJsonText(text) {
    if (this.actionsDisabled) {
      return;
    }
    this.isImporting = true;
    this.errorMessage = "";
    try {
      const inputs = parseImportJson(text);
      if (inputs.length === 0) {
        this.toast(
          "Import failed",
          "No sample conversations found in that file.",
          "error"
        );
        return;
      }
      const { created, failures } = await this.createConversations(inputs);
      if (created > 0) {
        await this.loadConversations();
      }
      this.toastImportResult(created, inputs.length, failures);
    } catch (error) {
      const message =
        error instanceof SyntaxError
          ? "The file is not valid JSON."
          : this.readError(error);
      this.toast("Import failed", message, "error");
    } finally {
      this.isImporting = false;
    }
  }

  resetFileInput(input) {
    try {
      input.value = "";
    } catch {
      // File inputs only accept an empty string; jsdom may reject the write.
    }
  }

  async createConversations(inputs) {
    const result = await importConversations({ records: inputs });
    return {
      created: result?.created || 0,
      failures: result?.failures || []
    };
  }

  toastImportResult(created, total, failures) {
    if (created === 0) {
      this.toast(
        "Import failed",
        failures[0] || "No records were created.",
        "error"
      );
      return;
    }
    if (failures.length) {
      this.toast(
        "Import complete",
        `Created ${created} of ${total}. ${failures.length} failed.`,
        "warning"
      );
      return;
    }
    this.toast(
      "Import complete",
      `Created ${created} conversation${created === 1 ? "" : "s"}.`,
      "success"
    );
  }

  async readFileText(file) {
    if (typeof file.text === "function") {
      return file.text();
    }
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error);
      reader.readAsText(file);
    });
  }

  patchConversation(id, patch) {
    this.conversations = this.conversations.map((conversation) => {
      if (conversation.id !== id) {
        return conversation;
      }
      return { ...conversation, ...patch };
    });
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
