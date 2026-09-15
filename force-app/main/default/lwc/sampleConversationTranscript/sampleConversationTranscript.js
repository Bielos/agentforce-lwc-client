/**
 * Shared helpers for the Sample Conversation transcript format, reused by the
 * single-record player and the batch player so both parse/serialize identically.
 *
 * Transcript format: each turn is a block prefixed with "User:" or "Agent:".
 * Agent turns may carry a response-duration annotation, e.g. "Agent (1.8s): ...".
 * Line breaks may be real newlines or the literal "\n" sequences produced by CSV
 * imports.
 */

export const ROLE = Object.freeze({ USER: "user", AGENT: "agent" });

const TURN_HEADER =
  /^\s*(user|agent|assistant)\s*(?:\(\s*([^)]*?)\s*\))?\s*:\s*(.*)$/i;

export function normalizeTranscriptLines(text) {
  return String(text || "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/\\r\\n/g, "\n")
    .replace(/\\n/g, "\n")
    .split("\n");
}

// Compact duration token used inside the transcript, e.g. "450ms" / "1.8s".
export function formatDurationToken(durationMs) {
  if (typeof durationMs !== "number") {
    return "";
  }
  if (durationMs < 1000) {
    return `${durationMs}ms`;
  }
  return `${(durationMs / 1000).toFixed(1)}s`;
}

// Parse a transcript duration token back to milliseconds; null when absent.
export function parseDurationToken(token) {
  if (!token) {
    return null;
  }
  const match = token.trim().match(/^([\d.]+)\s*(ms|s)$/i);
  if (!match) {
    return null;
  }
  const value = parseFloat(match[1]);
  if (Number.isNaN(value)) {
    return null;
  }
  return match[2].toLowerCase() === "s"
    ? Math.round(value * 1000)
    : Math.round(value);
}

/**
 * Parse a transcript string into turns: [{ role, content, durationMs? }].
 * Callers add their own presentation fields (id, updated, ...).
 */
export function parseTranscript(text) {
  const lines = normalizeTranscriptLines(text);
  const turns = [];
  let current = null;

  const push = () => {
    if (current) {
      current.content = current.content.trim();
      turns.push(current);
    }
  };

  lines.forEach((line) => {
    const match = line.match(TURN_HEADER);
    if (match) {
      push();
      const role =
        match[1].toLowerCase() === ROLE.USER ? ROLE.USER : ROLE.AGENT;
      current = { role, content: match[3] };
      const durationMs = parseDurationToken(match[2]);
      if (role === ROLE.AGENT && durationMs !== null) {
        current.durationMs = durationMs;
      }
    } else if (current) {
      current.content += `\n${line}`;
    }
  });
  push();

  return turns.filter(
    (turn) => turn.content.length > 0 || turn.role === ROLE.AGENT
  );
}

export function serializeTranscript(turns) {
  return turns
    .map((turn) => {
      if (turn.role === ROLE.USER) {
        return `User: ${turn.content}`;
      }
      const token =
        typeof turn.durationMs === "number"
          ? ` (${formatDurationToken(turn.durationMs)})`
          : "";
      return `Agent${token}: ${turn.content}`;
    })
    .join("\n\n");
}
