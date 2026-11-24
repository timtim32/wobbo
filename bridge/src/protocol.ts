// Bridge protocol, version 1 (see ../PROTOCOL.md).

export const PROTOCOL_VERSION = 1;
export const BRIDGE_VERSION = "0.2.4";

export type Role = "hook" | "mcp";

export interface ClientInfo {
  role: Role;
  agent: string;
  pid: number;
  ppid: number;
  project_dir: string;
  client_name?: string;
  bridge_version?: string;
}

/** What a bridge process tells the app about itself; `hello` adds `bridge_version`. */
export type ClientIdentity = Omit<ClientInfo, "bridge_version">;

export interface SessionRef {
  id: string;
  agent: string;
  project_dir: string;
  /** Opens this session in the agent's host app (go-to-session D4). Optional. */
  focus_url?: string;
}

export type EventKind =
  | "session_start"
  | "prompt"
  | "tool_start"
  | "tool_end"
  | "tool_error"
  | "notification"
  | "input_wait"
  | "turn_end"
  | "turn_error"
  | "session_end";

export type ClientMessage =
  | { type: "hello"; token: string; client: ClientInfo }
  | { type: "event"; ts: number; session: SessionRef; kind: EventKind; data: Record<string, unknown> }
  | { type: "say"; ts: number; session: SessionRef | null; text: string }
  | {
      type: "request";
      ts: number;
      id: string;
      session: SessionRef | null;
      kind: "question" | "permission";
      text: string;
      choices: string[];
      allow_text: boolean;
      timeout_s: number;
    }
  | { type: "cancel"; ts: number; id: string };

export type AppMessage =
  | { v: number; type: "welcome"; app_version: string }
  | { v: number; type: "error"; reason: string }
  | { v: number; type: "answer"; id: string; status: "answered" | "dismissed"; choice?: string; text?: string };

export type Answer = Extract<AppMessage, { type: "answer" }>;
