import { createElement } from "lwc";
import SampleConversationBatchPlayer from "c/sampleConversationBatchPlayer";
import getConversations from "@salesforce/apex/SampleConversationController.getConversations";
import saveTranscript from "@salesforce/apex/SampleConversationController.saveTranscript";
import importConversations from "@salesforce/apex/SampleConversationController.importConversations";
import sendAgentMessage from "@salesforce/apex/AgentforceService.sendMessage";
import getConfiguredAgents from "@salesforce/apex/AgentforceService.getConfiguredAgents";
import getCoworkerSkills from "@salesforce/apex/CoworkerSkillsController.getSkills";

jest.mock(
  "@salesforce/apex/SampleConversationController.getConversations",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SampleConversationController.saveTranscript",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/SampleConversationController.importConversations",
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
        super("lightning__showtoast", {
          detail,
          bubbles: true,
          composed: true
        });
      }
    }
  }),
  { virtual: true }
);

const flushPromises = () => Promise.resolve();

function createComponent() {
  const element = createElement("c-sample-conversation-batch-player", {
    is: SampleConversationBatchPlayer
  });
  document.body.appendChild(element);
  return element;
}

function selectSkill(element, value) {
  const card = [...element.shadowRoot.querySelectorAll(".skill-card")].find(
    (b) => b.dataset.skill === value
  );
  card.click();
}

function seededContents(element) {
  const chat = element.shadowRoot.querySelector("c-agentforce-chat");
  return chat.seededMessages.map((message) => message.content);
}

describe("c-sample-conversation-batch-player", () => {
  beforeEach(() => {
    getConfiguredAgents.mockResolvedValue([]);
    getCoworkerSkills.mockResolvedValue([]);
    importConversations.mockResolvedValue({ created: 1, failures: [] });
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it("builds a skill list with counts", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi\n\nAgent: Hello"
      },
      {
        Id: "a02",
        Name: "Prioritise",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi"
      },
      {
        Id: "a03",
        Name: "Refund",
        Skill_API_Name__c: "billing",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const cards = [...element.shadowRoot.querySelectorAll(".skill-card")];
    expect(cards.map((c) => c.dataset.skill)).toEqual([
      "billing",
      "plan_my_day"
    ]);
    expect(
      cards.map((c) => c.querySelector(".skill-card__count").textContent)
    ).toEqual(["1", "2"]);
  });

  it("auto-opens the first conversation of the first skill in the player", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Later\n\nAgent: Sure"
      },
      {
        Id: "a03",
        Name: "Refund",
        Skill_API_Name__c: "billing",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi\n\nAgent (1.2s): Hello there"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    // billing sorts first, so its only conversation opens automatically.
    const chat = element.shadowRoot.querySelector("c-agentforce-chat");
    expect(chat).not.toBeNull();
    expect(chat.agentApiName).toBe("SearchAgent");
    expect(seededContents(element)).toEqual(["Hi", "Hello there"]);
  });

  it("opens the first conversation of a newly selected skill", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Plan it\n\nAgent: Done"
      },
      {
        Id: "a03",
        Name: "Refund",
        Skill_API_Name__c: "billing",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    selectSkill(element, "plan_my_day");
    await flushPromises();
    await flushPromises();

    expect(seededContents(element)).toEqual(["Plan it", "Done"]);
  });

  it("opens a conversation when its list item is clicked", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: First\n\nAgent: One"
      },
      {
        Id: "a02",
        Name: "Prioritise",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Second\n\nAgent: Two"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const buttons = element.shadowRoot.querySelectorAll(".conv-list__button");
    expect(buttons).toHaveLength(2);
    buttons[1].click();
    await flushPromises();
    await flushPromises();

    expect(seededContents(element)).toEqual(["Second", "Two"]);
  });

  it("replays the open conversation against the agent and saves it", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi\n\nAgent: (pending)"
      }
    ]);
    sendAgentMessage.mockResolvedValue({
      message: { role: "assistant", content: "Live answer" },
      sessionId: "s1"
    });
    saveTranscript.mockResolvedValue({});

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='detail-play']")
      .click();
    for (let i = 0; i < 10; i++) {
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(sendAgentMessage).toHaveBeenCalledWith({
      agentApiName: "SearchAgent",
      message: "Hi",
      sessionId: null
    });
    const arg = saveTranscript.mock.calls[0][0];
    expect(arg.recordId).toBe("a01");
    expect(arg.transcript).toMatch(
      /^User: Hi\n\nAgent(?: \([^)]*\))?: Live answer$/
    );
    expect(typeof arg.durationSeconds).toBe("number");
  });

  it("places Import and Download JSON actions beside reload", async () => {
    getConversations.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const actions = [
      ...element.shadowRoot.querySelectorAll("lightning-button-icon")
    ];
    expect(actions.map((button) => button.iconName)).toEqual([
      "utility:paste",
      "utility:download",
      "utility:refresh"
    ]);
    expect(
      element.shadowRoot.querySelector('[data-id="download-file"]')
    ).not.toBeNull();
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });

  it("imports conversations from a sample-data JSON tree via Apex", async () => {
    getConversations.mockResolvedValueOnce([]).mockResolvedValueOnce([
      {
        Id: "a01new",
        Name: "Plan de journée pour un lundi chargé",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Description__c: "A busy Monday",
        Transcript__c: "User: Organise ma journée.\n\nAgent: Voici le plan."
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) => {
      toasts.push(event.detail);
    });

    await element.importJsonText(
      JSON.stringify({
        records: [
          {
            attributes: {
              type: "Sample_Conversation__c",
              referenceId: "SC_1"
            },
            Name: "Plan de journée pour un lundi chargé",
            Skill_API_Name__c: "plan_my_day",
            Agent_API_Name__c: "SearchAgent",
            Description__c: "A busy Monday",
            Transcript__c: "User: Organise ma journée.\n\nAgent: Voici le plan."
          }
        ]
      })
    );
    await flushPromises();
    await flushPromises();

    expect(importConversations).toHaveBeenCalledTimes(1);
    expect(importConversations).toHaveBeenCalledWith({
      records: [
        {
          Name: "Plan de journée pour un lundi chargé",
          Skill_API_Name__c: "plan_my_day",
          Agent_API_Name__c: "SearchAgent",
          Description__c: "A busy Monday",
          Transcript__c: "User: Organise ma journée.\n\nAgent: Voici le plan."
        }
      ]
    });
    expect(getConversations).toHaveBeenCalledTimes(2);
    expect(toasts[0]).toMatchObject({
      title: "Import complete",
      variant: "success"
    });
    expect(
      [...element.shadowRoot.querySelectorAll(".conv-list__name")].map(
        (node) => node.textContent
      )
    ).toEqual(["Plan de journée pour un lundi chargé"]);
  });

  it("toasts when the import file is not valid JSON", async () => {
    getConversations.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) => {
      toasts.push(event.detail);
    });

    await element.importJsonText("{not json");
    await flushPromises();
    await flushPromises();

    expect(importConversations).not.toHaveBeenCalled();
    expect(toasts[0]).toMatchObject({
      title: "Import failed",
      message: "The pasted text is not valid JSON.",
      variant: "error"
    });
  });

  it("opens a paste modal and imports JSON from the textarea", async () => {
    getConversations.mockResolvedValueOnce([]).mockResolvedValueOnce([
      {
        Id: "a01new",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Hi"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) => {
      toasts.push(event.detail);
    });

    element.shadowRoot
      .querySelector("lightning-button-icon[data-id='import-json']")
      .click();
    await flushPromises();

    const dialog = element.shadowRoot.querySelector('[role="dialog"]');
    expect(dialog).not.toBeNull();

    const textarea = element.shadowRoot.querySelector(
      '[data-id="import-json-text"]'
    );
    textarea.dispatchEvent(
      new CustomEvent("change", {
        detail: {
          value: JSON.stringify({
            records: [
              {
                attributes: {
                  type: "Sample_Conversation__c",
                  referenceId: "SC_1"
                },
                Name: "Plan Monday",
                Skill_API_Name__c: "plan_my_day",
                Agent_API_Name__c: "SearchAgent",
                Transcript__c: "User: Hi"
              }
            ]
          })
        }
      })
    );
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='import-json-submit']")
      .click();
    for (let i = 0; i < 10; i++) {
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(importConversations).toHaveBeenCalledTimes(1);
    expect(toasts[0]).toMatchObject({
      title: "Import complete",
      variant: "success"
    });
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });

  it("keeps the modal open and shows an error for invalid pasted JSON", async () => {
    getConversations.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) => {
      toasts.push(event.detail);
    });

    element.shadowRoot
      .querySelector("lightning-button-icon[data-id='import-json']")
      .click();
    await flushPromises();

    element.shadowRoot
      .querySelector('[data-id="import-json-text"]')
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "{not json" } })
      );
    await flushPromises();

    element.shadowRoot
      .querySelector("lightning-button[data-id='import-json-submit']")
      .click();
    await flushPromises();
    await flushPromises();

    expect(importConversations).not.toHaveBeenCalled();
    expect(toasts).toHaveLength(0);
    expect(element.shadowRoot.querySelector('[role="dialog"]')).not.toBeNull();
    expect(
      element.shadowRoot.querySelector('[role="dialog"] [role="alert"]')
        .textContent
    ).toBe("The pasted text is not valid JSON.");
  });

  it("exports loaded conversations as a sample-data JSON tree", async () => {
    getConversations.mockResolvedValue([
      {
        Id: "a01",
        Name: "Plan Monday",
        Skill_API_Name__c: "plan_my_day",
        Agent_API_Name__c: "SearchAgent",
        Description__c: "A busy Monday",
        Transcript__c: "User: Hi\n\nAgent: Hello"
      },
      {
        Id: "a03",
        Name: "Refund",
        Skill_API_Name__c: "",
        Agent_API_Name__c: "SearchAgent",
        Transcript__c: "User: Please refund"
      }
    ]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    expect(element.getExportTree()).toEqual({
      records: [
        {
          attributes: {
            type: "Sample_Conversation__c",
            referenceId: "SC_1"
          },
          Name: "Plan Monday",
          Skill_API_Name__c: "plan_my_day",
          Agent_API_Name__c: "SearchAgent",
          Description__c: "A busy Monday",
          Transcript__c: "User: Hi\n\nAgent: Hello"
        },
        {
          attributes: {
            type: "Sample_Conversation__c",
            referenceId: "SC_2"
          },
          Name: "Refund",
          Agent_API_Name__c: "SearchAgent",
          Transcript__c: "User: Please refund"
        }
      ]
    });
  });

  it("toasts when download has nothing to export", async () => {
    getConversations.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();
    await flushPromises();

    const toasts = [];
    element.addEventListener("lightning__showtoast", (event) => {
      toasts.push(event.detail);
    });

    element.shadowRoot
      .querySelector("lightning-button-icon[data-id='download-json']")
      .click();
    await flushPromises();

    expect(toasts[0]).toMatchObject({
      title: "Download failed",
      message: "No sample conversations to download.",
      variant: "error"
    });
  });
});
