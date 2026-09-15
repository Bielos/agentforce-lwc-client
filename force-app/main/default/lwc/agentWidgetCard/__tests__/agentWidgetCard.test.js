import { createElement } from "lwc";
import AgentWidgetCard from "c/agentWidgetCard";

const SAMPLE_PAYLOAD = {
  accountName: "Annie Dubois",
  accountUrl: "https://example.salesforce.com/001KB00000HTxdGYAT",
  contacts: [
    {
      name: "Annie Dubois",
      title: "Contact"
    }
  ],
  nextSteps: [
    {
      label: "Prepare the next meeting",
      prompt: "Help me prepare the next meeting."
    }
  ]
};

describe("c-agent-widget-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders a dynamic widget payload without hardcoded field names", async () => {
    const element = createElement("c-agent-widget-card", {
      is: AgentWidgetCard
    });
    element.widgetName = "account_summary";
    element.payload = SAMPLE_PAYLOAD;
    document.body.appendChild(element);

    const title = element.shadowRoot.querySelector("h3");
    expect(title.textContent).toContain("Account Summary");
    expect(element.shadowRoot.textContent).toContain("Annie Dubois");
    expect(element.shadowRoot.textContent).toContain("Account Url");

    const handler = jest.fn();
    element.addEventListener("action", handler);
    const actionButton = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((button) => button.label === "Prepare the next meeting");
    expect(actionButton).toBeDefined();
    actionButton.click();
    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail.prompt).toBe(
      "Help me prepare the next meeting."
    );
    expect(handler.mock.calls[0][0].detail.widgetName).toBe("account_summary");
  });

  it("renders an arbitrary widget key", async () => {
    const element = createElement("c-agent-widget-card", {
      is: AgentWidgetCard
    });
    element.widgetName = "generic_section";
    element.payload = {
      title: "Portfolio",
      rows: [{ name: "Fund A", value: "12%" }]
    };
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("h3").textContent).toContain(
      "Generic Section"
    );
    expect(element.shadowRoot.textContent).toContain("Fund A");
  });
});
