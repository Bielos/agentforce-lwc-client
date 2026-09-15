import { createElement } from "lwc";
import SampleConversationPlayer from "c/sampleConversationPlayer";
import getConversation from "@salesforce/apex/SampleConversationController.getConversation";
import saveTranscript from "@salesforce/apex/SampleConversationController.saveTranscript";
import getSkillContent from "@salesforce/apex/SampleConversationController.getSkillContent";
import sendAgentMessage from "@salesforce/apex/AgentforceService.sendMessage";
import getConfiguredAgents from "@salesforce/apex/AgentforceService.getConfiguredAgents";
import getCoworkerSkills from "@salesforce/apex/CoworkerSkillsController.getSkills";

jest.mock(
  "@salesforce/apex/SampleConversationController.getConversation",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SampleConversationController.saveTranscript",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SampleConversationController.getSkillContent",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/AgentforceService.sendMessage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/AgentforceService.getConfiguredAgents",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
// Imported transitively by the embedded c-agentforce-chat.
jest.mock(
  "@salesforce/apex/CoworkerSkillsController.getSkills",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: class extends CustomEvent {
      constructor(detail) {
        super("lightning__showtoast", { detail });
      }
    }
  }),
  { virtual: true }
);

const flushPromises = () => Promise.resolve();

function createComponent(props = {}) {
  const element = createElement("c-sample-conversation-player", {
    is: SampleConversationPlayer
  });
  Object.assign(element, { recordId: "a01000000000001", ...props });
  document.body.appendChild(element);
  return element;
}

async function enterEditMode(element) {
  element.shadowRoot
    .querySelector("lightning-button[data-id='toggle-edit']")
    .click();
  await flushPromises();
}

describe("c-sample-conversation-player", () => {
  beforeEach(() => {
    getSkillContent.mockResolvedValue(null);
    getConfiguredAgents.mockResolvedValue([]);
    getCoworkerSkills.mockResolvedValue([]);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it("parses transcripts whose line breaks were encoded as \\n (CSV import style)", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Imported",
      Transcript__c:
        "User: My order arrived damaged.\\n\\nAgent: (expected) Offer a replacement.",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });

    const element = createComponent();
    await flushPromises();
    await flushPromises();
    await enterEditMode(element);

    const textareas = element.shadowRoot.querySelectorAll("lightning-textarea");
    expect(textareas.length).toBe(2);
    expect(textareas[0].value).toBe("My order arrived damaged.");
    expect(textareas[1].value).toBe("(expected) Offer a replacement.");
  });

  it("shows the chat view for an existing transcript and the editor on toggle", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent: Hello there",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    // View mode: renders the agentforce chat, no editor textareas.
    expect(
      element.shadowRoot.querySelector("c-agentforce-chat")
    ).not.toBeNull();
    expect(
      element.shadowRoot.querySelectorAll("lightning-textarea").length
    ).toBe(0);

    await enterEditMode(element);

    const textareas = element.shadowRoot.querySelectorAll("lightning-textarea");
    expect(textareas.length).toBe(2);
    expect(textareas[0].value).toBe("Hi");
    expect(textareas[1].value).toBe("Hello there");
  });

  it("captures chat messages back into the transcript via the callback", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent: Hello there",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });
    saveTranscript.mockResolvedValue({});

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const chat = element.shadowRoot.querySelector("c-agentforce-chat");
    chat.dispatchEvent(
      new CustomEvent("message", {
        detail: { message: { role: "user", content: "What are my options?" } }
      })
    );
    chat.dispatchEvent(
      new CustomEvent("message", {
        detail: { message: { role: "assistant", content: "Here are three." } }
      })
    );
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='save']")
      .click();
    await flushPromises();

    const arg = saveTranscript.mock.calls[0][0];
    expect(arg.transcript).toContain("User: What are my options?");
    // Captured Agent turn keeps an optional response-duration annotation.
    expect(arg.transcript).toMatch(/Agent(?: \([^)]*\))?: Here are three\./);
  });

  it("replays the seeded transcript through the chat and captures the result", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent: Hello there",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });
    sendAgentMessage.mockResolvedValue({
      message: { role: "assistant", content: "Replayed answer" },
      sessionId: "s1"
    });
    saveTranscript.mockResolvedValue({});

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='chat-play']")
      .click();
    // Let replay() send the user turn and receive the response.
    for (let i = 0; i < 6; i++) {
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    // The reused chat component contacted the agent with the seeded user turn.
    expect(sendAgentMessage).toHaveBeenCalledWith({
      agentApiName: "SearchAgent",
      message: "Hi",
      sessionId: null
    });

    element.shadowRoot
      .querySelector("lightning-button[data-id='save']")
      .click();
    await flushPromises();

    const arg = saveTranscript.mock.calls[0][0];
    expect(arg.transcript).toMatch(
      /^User: Hi\n\nAgent(?: \([^)]*\))?: Replayed answer$/
    );
  });

  it("plays the conversation and rewrites the Agent turn with the live reply", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent: (pending)",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });
    sendAgentMessage.mockResolvedValue({
      message: { role: "assistant", content: "Live reply" },
      sessionId: "session-1"
    });

    const element = createComponent();
    await flushPromises();
    await flushPromises();
    await enterEditMode(element);

    element.shadowRoot
      .querySelector("lightning-button[data-id='play']")
      .click();
    await flushPromises();
    await flushPromises();
    await flushPromises();

    expect(sendAgentMessage).toHaveBeenCalledWith({
      agentApiName: "SearchAgent",
      message: "Hi",
      sessionId: null
    });
    const textareas = element.shadowRoot.querySelectorAll("lightning-textarea");
    expect(textareas[1].value).toBe("Live reply");

    // A response-duration badge is shown on the played Agent turn.
    const badges = [...element.shadowRoot.querySelectorAll("lightning-badge")];
    const durationBadge = badges.find((b) => /\d+\s*(ms|s)$/.test(b.label));
    expect(durationBadge).toBeTruthy();
  });

  it("reads the response duration from the transcript and shows it in the editor", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent (1.8s): Hello there",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });

    const element = createComponent();
    await flushPromises();
    await flushPromises();
    await enterEditMode(element);

    const badges = [...element.shadowRoot.querySelectorAll("lightning-badge")];
    const durationBadge = badges.find((b) => b.label === "1.8 s");
    expect(durationBadge).toBeTruthy();

    // Round-trips: editing a turn and saving keeps the duration annotation.
    saveTranscript.mockResolvedValue({});
    const [userTurn] =
      element.shadowRoot.querySelectorAll("lightning-textarea");
    userTurn.value = "Hi again";
    userTurn.dispatchEvent(new CustomEvent("change", { target: userTurn }));
    await flushPromises();
    element.shadowRoot
      .querySelector("lightning-button[data-id='save']")
      .click();
    await flushPromises();
    expect(saveTranscript.mock.calls[0][0].transcript).toContain(
      "Agent (1.8s): Hello there"
    );
  });

  it("lets the user add a turn from the empty state", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Empty",
      Transcript__c: "",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    // Empty transcript opens straight into the editor with no turns.
    expect(
      element.shadowRoot.querySelectorAll("lightning-textarea").length
    ).toBe(0);

    const addUser = element.shadowRoot.querySelector(
      "lightning-button[data-id='add-user-empty']"
    );
    addUser.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelectorAll("lightning-textarea").length
    ).toBe(1);
  });

  it("saves the serialized transcript when Save is clicked", async () => {
    getConversation.mockResolvedValue({
      Id: "a01000000000001",
      Name: "Demo",
      Transcript__c: "User: Hi\n\nAgent: Hello",
      Skill_API_Name__c: "",
      Agent_API_Name__c: "SearchAgent"
    });
    saveTranscript.mockResolvedValue({});

    const element = createComponent();
    await flushPromises();
    await flushPromises();
    await enterEditMode(element);

    const [userTurn] =
      element.shadowRoot.querySelectorAll("lightning-textarea");
    userTurn.value = "Hi there";
    userTurn.dispatchEvent(new CustomEvent("change", { target: userTurn }));
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='save']")
      .click();
    await flushPromises();

    expect(saveTranscript).toHaveBeenCalled();
    const arg = saveTranscript.mock.calls[0][0];
    expect(arg.transcript).toContain("Agent: Hello");
    expect(arg.agentApiName).toBe("SearchAgent");
  });
});
