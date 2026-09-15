import { LightningElement, api } from "lwc";

const MAX_DEPTH = 5;

export default class AgentWidgetCard extends LightningElement {
  @api widgetName;
  @api payload;

  get title() {
    return this.humanizeKey(this.widgetName);
  }

  get nodes() {
    return this.buildNodes(this.payload, null, 0, this.widgetName || "widget");
  }

  handleAction(event) {
    const index = Number(event.currentTarget.dataset.index);
    const actionNode = this.nodes.find(
      (node) => node.isAction && node.actionIndex === index
    );
    if (!actionNode?.prompt) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("action", {
        detail: {
          prompt: actionNode.prompt,
          label: actionNode.label,
          widgetName: this.widgetName
        }
      })
    );
  }

  buildNodes(value, key, depth, path) {
    if (value === null || value === undefined || depth > MAX_DEPTH) {
      return [];
    }
    if (Array.isArray(value)) {
      return this.buildArrayNodes(value, key, depth, path);
    }
    if (typeof value === "object") {
      if (this.isAction(value)) {
        return [
          this.node("action", path, depth, {
            label: value.label,
            prompt: value.prompt,
            actionIndex: 0
          })
        ];
      }
      const childEntries = Object.entries(value).filter(
        ([, child]) => child !== null && child !== undefined && child !== ""
      );
      const children = childEntries.flatMap(([childKey, childValue]) =>
        this.buildNodes(childValue, childKey, key ? depth + 1 : depth, `${path}.${childKey}`)
      );
      if (!key) {
        return this.withActionIndexes(children);
      }
      return this.withActionIndexes([
        this.node("section", path, depth, { label: this.humanizeKey(key) }),
        ...children
      ]);
    }
    if (this.isUrl(value)) {
      return [
        this.node("link", path, depth, {
          label: this.humanizeKey(key),
          href: String(value)
        })
      ];
    }
    return [
      this.node("field", path, depth, {
        label: this.humanizeKey(key),
        value: String(value)
      })
    ];
  }

  buildArrayNodes(values, key, depth, path) {
    if (values.length === 0) {
      return [];
    }
    if (values.every((item) => this.isAction(item))) {
      const actionNodes = values.map((item, index) =>
        this.node("action", `${path}.${index}`, depth, {
          label: item.label,
          prompt: item.prompt,
          actionIndex: index
        })
      );
      if (!key) {
        return actionNodes;
      }
      return [
        this.node("section", path, depth, { label: this.humanizeKey(key) }),
        ...actionNodes
      ];
    }
    const children = values.flatMap((item, index) => {
      const itemKey = this.itemLabel(item, key, index);
      return this.buildNodes(item, itemKey, depth + 1, `${path}.${index}`);
    });
    if (!key) {
      return this.withActionIndexes(children);
    }
    return this.withActionIndexes([
      this.node("section", path, depth, { label: this.humanizeKey(key) }),
      ...children
    ]);
  }

  itemLabel(item, key, index) {
    if (item && typeof item === "object" && !Array.isArray(item)) {
      const named = item.name || item.title || item.label;
      if (named) {
        return String(named);
      }
    }
    const base = this.humanizeKey(key) || "Item";
    return `${base} ${index + 1}`;
  }

  withActionIndexes(nodes) {
    let actionIndex = 0;
    return nodes.map((node) => {
      if (!node.isAction) {
        return node;
      }
      return {
        ...node,
        actionIndex,
        actionIndexLabel: String(actionIndex++)
      };
    });
  }

  node(type, key, depth, extra = {}) {
    return {
      key,
      className: `agent-widget__node agent-widget__node_depth-${Math.min(depth, 4)}`,
      isSection: type === "section",
      isField: type === "field",
      isLink: type === "link",
      isAction: type === "action",
      actionIndex: extra.actionIndex || 0,
      actionIndexLabel: String(extra.actionIndex || 0),
      ...extra
    };
  }

  isAction(value) {
    return (
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      typeof value.label === "string" &&
      typeof value.prompt === "string"
    );
  }

  isUrl(value) {
    return typeof value === "string" && /^https?:\/\//i.test(value);
  }

  humanizeKey(key) {
    if (!key) {
      return "";
    }
    return String(key)
      .replace(/_/g, " ")
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/\b\w/g, (char) => char.toUpperCase())
      .trim();
  }
}
