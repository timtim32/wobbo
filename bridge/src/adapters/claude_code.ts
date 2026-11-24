// Claude Code adapter (claude-bridge D5): turns hook stdin into protocol messages.
// Status hooks fire and forget; PermissionRequest waits for the user's choice
// in the app and prints Claude Code's decision JSON (or nothing, so Claude Code
// shows its own prompt).
import { closeSync, fstatSync, openSync, readSync } from "node:fs";
import { AppConnection, CONNECT_TIMEOUT_MS, sendOnce } from "../app_client";
import type { ClientIdentity, ClientMessage, EventKind, SessionRef } from "../protocol";

export const AGENT = "claude-code";

export interface HookInput {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
  tool_name?: string;
  tool_input?: Record<string, unknown>;
  error?: unknown;
  message?: string;
  notification_type?: string;
  source?: string;
  reason?: string;
  transcript_path?: string;
  [key: string]: unknown;
}

export interface HookContext {
  ppid: number;
  pid: number;
  projectDir?: string;
  /** The Claude app's own id of this Code session (CLAUDE_CODE_HOST_SESSION_ID), if any. */
  hostSessionId?: string;
  now: () => number;
  /** How long a permission request waits for the user in the app. */
  permissionWaitMs: number;
  connect: (client: ClientIdentity, timeoutMs: number) => Promise<AppConnection | null>;
  /** Fire-and-forget delivery of one status event. */
  sendEvent: (client: ClientIdentity, message: ClientMessage) => Promise<boolean>;
  /** The session's transcript (its last part, when it is long), or null. */
  readTranscript: (path: string) => string | null;
}

export function defaultContext(): HookContext {
  // CLAUDE_BUDDY_PERMISSION_WAIT_S: Claude Buddy compatibility (renamed to Wobbo on 2026-11-24, standalone-app D5): remove once no 0.1.x installs remain.
  const waitS = Number(process.env.WOBBO_PERMISSION_WAIT_S ?? process.env.CLAUDE_BUDDY_PERMISSION_WAIT_S ?? "20");
  return {
    ppid: process.ppid,
    pid: process.pid,
    projectDir: process.env.CLAUDE_PROJECT_DIR,
    hostSessionId: process.env.CLAUDE_CODE_HOST_SESSION_ID,
    now: () => Date.now(),
    permissionWaitMs: (Number.isFinite(waitS) ? waitS : 20) * 1000,
    connect: (client, timeoutMs) => AppConnection.connect(client, timeoutMs),
    sendEvent: (client, message) => sendOnce(client, message),
    readTranscript: readTail,
  };
}

/** The most of a transcript read at the end of a turn. */
const MAX_TRANSCRIPT_BYTES = 32 * 1024 * 1024;

function readTail(path: string): string | null {
  let fd = -1;
  try {
    fd = openSync(path, "r");
    const size = fstatSync(fd).size;
    const length = Math.min(size, MAX_TRANSCRIPT_BYTES);
    const buf = Buffer.alloc(length);
    readSync(fd, buf, 0, length, size - length);
    return buf.toString("utf8");
  } catch {
    return null;
  } finally {
    if (fd >= 0) closeSync(fd);
  }
}

/**
 * The ids of background commands that still run, read from a Claude Code
 * transcript: a Bash call with `run_in_background` records `"backgroundTaskId"`,
 * and Claude Code adds a `<task-notification>` with that id and a status when it
 * ends. Not a public API, so read defensively: when in doubt, nothing runs.
 */
export function runningBackgroundTasks(transcript: string): string[] {
  const started = new Set<string>();
  for (const m of transcript.matchAll(/"backgroundTaskId":"([\w-]+)"/g)) started.add(m[1]);
  for (const m of transcript.matchAll(/<task-id>([\w-]+)<\/task-id>.{0,2000}?<status>(\w+)<\/status>/g)) {
    if (m[2] !== "running") started.delete(m[1]);
  }
  return [...started];
}

/** Tools with which Claude waits for the user (work-and-wait D1). */
export const WAITS_FOR_USER = ["AskUserQuestion", "ExitPlanMode"];
/** Claude Code notifications that mean it waits for the user. */
export const WAITING_NOTIFICATIONS = ["permission_prompt", "elicitation_dialog"];

/** The Claude app's next-step box: a tool with `ask` and `actions` (balloons-and-speech D11). */
export const NEXT_STEP_TOOL = "mcp__ccd_turn__wrap_up";
const MAX_QUESTION = 500;
const MAX_CHOICE = 40;
const MAX_CHOICES = 6;

export interface AskedQuestion {
  question: string;
  choices: string[];
  /** "answer": closes when the tool ends; "prompt": closes on the next prompt. */
  question_until: "answer" | "prompt";
}

const str = (v: unknown): string => (typeof v === "string" ? v.trim() : "");
const labels = (list: unknown, key: string): string[] =>
  (Array.isArray(list) ? list : [])
    .map((o) => str(o && typeof o === "object" ? (o as Record<string, unknown>)[key] : ""))
    .filter((l) => l)
    .slice(0, MAX_CHOICES)
    .map((l) => l.slice(0, MAX_CHOICE));

/**
 * The question Claude asks in its own UI with this tool, or null: Claude Code's
 * question tool, plan approval, and the Claude app's next-step box. Reads the
 * input defensively, since these shapes are not a public API (balloons-and-speech D11).
 */
export function askedQuestion(tool: string, input: Record<string, unknown> | undefined): AskedQuestion | null {
  const ti = input ?? {};
  if (tool === "AskUserQuestion") {
    const qs = Array.isArray(ti.questions) ? ti.questions : [];
    const first = (qs[0] ?? {}) as Record<string, unknown>;
    let question = str(first.question);
    if (!question) return null;
    if (qs.length > 1) question += ` (+${qs.length - 1} more)`;
    return { question: question.slice(0, MAX_QUESTION), choices: labels(first.options, "label"), question_until: "answer" };
  }
  if (tool === "ExitPlanMode") {
    return { question: "Plan ready for your approval", choices: [], question_until: "answer" };
  }
  if (tool === NEXT_STEP_TOOL) {
    const ask = str(ti.ask);
    if (!ask) return null;
    return { question: ask.slice(0, MAX_QUESTION), choices: labels(ti.actions, "label"), question_until: "prompt" };
  }
  return null;
}

/** Maps a hook event to a protocol event, or null for events we ignore. */
export function toEvent(input: HookInput): { kind: EventKind; data: Record<string, unknown> } | null {
  const tool = input.tool_name ?? "";
  switch (input.hook_event_name) {
    case "SessionStart":
      return { kind: "session_start", data: { source: input.source ?? "" } };
    case "UserPromptSubmit":
      return { kind: "prompt", data: {} };
    case "PreToolUse": {
      const asked = askedQuestion(tool, input.tool_input) ?? {};
      if (WAITS_FOR_USER.includes(tool)) return { kind: "input_wait", data: { reason: "tool", tool, ...asked } };
      return { kind: "tool_start", data: { tool, ...asked } };
    }
    case "PostToolUse":
      return { kind: "tool_end", data: { tool } };
    case "PostToolUseFailure":
      return { kind: "tool_error", data: { tool, error: String(input.error ?? "").slice(0, 500) } };
    case "Notification":
      if (WAITING_NOTIFICATIONS.includes(input.notification_type ?? ""))
        return { kind: "input_wait", data: { reason: input.notification_type } };
      return {
        kind: "notification",
        data: { message: input.message ?? "", notification_type: input.notification_type ?? "" },
      };
    case "Stop":
      return { kind: "turn_end", data: {} };
    case "StopFailure":
      return { kind: "turn_error", data: { error: String(input.error ?? input.message ?? "").slice(0, 500) } };
    case "SessionEnd":
      return { kind: "session_end", data: { reason: input.reason ?? "" } };
    default:
      return null;
  }
}

/**
 * Wobbo's own MCP tools, e.g. `mcp__plugin_wobbo_wobbo__ask_user`. `buddy` matches
 * the old `mcp__plugin_buddy-bridge_buddy__…` names (Claude Buddy compatibility (renamed to Wobbo on 2026-11-24, standalone-app D5): remove once no 0.1.x installs remain.)
 */
export function isWobboTool(tool: string): boolean {
  return /^mcp__.*(buddy|wobbo)__(say|ask_user)$/.test(tool);
}

/** "server · tool" for an MCP tool name, else the name itself. */
export function toolLabel(tool: string): string {
  // mcp__<server>__<tool>, where a plugin server is plugin_<plugin>_<server>
  const m = /^mcp__(.+)__([^_].*)$/.exec(tool);
  if (!m) return tool;
  const server = m[1].replace(/^plugin_[^_]+_/, "");
  return `${server} · ${m[2]}`;
}

const TEXT_FIELDS = ["command", "file_path", "url", "question", "text", "prompt", "query", "message", "path", "pattern"];
const QUOTED_FIELDS = ["question", "text", "prompt", "message"];
/** Fields that only describe or tune a call, so a description may leave them out. */
const MINOR_FIELDS = ["description", "timeout", "run_in_background", "offset", "limit"];
/** The longest description a balloon shows. */
export const MAX_PERMISSION_TEXT = 300;

export interface PermissionText {
  /** One line, at most MAX_PERMISSION_TEXT characters. */
  text: string;
  /** False when the text leaves out part of what is asked: it was cut, or the call has more arguments. */
  complete: boolean;
}

/** One-line, human-readable description of what a permission prompt asks for. */
export function describePermission(input: HookInput): PermissionText {
  const tool = input.tool_name ?? "tool";
  const ti = input.tool_input ?? {};
  const significant = Object.keys(ti).filter((k) => !MINOR_FIELDS.includes(k) && ti[k] !== null && ti[k] !== undefined && ti[k] !== "");
  const field =
    TEXT_FIELDS.find((f) => typeof ti[f] === "string" && ti[f]) ?? significant.find((k) => typeof ti[k] === "string");
  let detail = Object.keys(ti).join(", ");
  if (field) detail = QUOTED_FIELDS.includes(field) ? `"${ti[field]}"` : (ti[field] as string);
  const text = detail ? `${toolLabel(tool)}: ${detail}` : toolLabel(tool);
  const fits = text.length <= MAX_PERMISSION_TEXT;
  return {
    text: fits ? text : `${text.slice(0, MAX_PERMISSION_TEXT - 3)}...`,
    // Every argument that matters must be the one shown, in full (open-source-readiness D4).
    complete: fits && significant.every((k) => k === field),
  };
}

export function permissionDecision(behavior: "allow" | "deny"): string {
  const decision =
    behavior === "allow"
      ? { behavior: "allow" }
      : { behavior: "deny", message: "The user denied this in Wobbo." };
  return JSON.stringify({ hookSpecificOutput: { hookEventName: "PermissionRequest", decision } });
}

function sessionOf(input: HookInput, ctx: HookContext): SessionRef {
  const ref: SessionRef = { id: input.session_id ?? "unknown", agent: AGENT, project_dir: ctx.projectDir ?? input.cwd ?? "" };
  const url = focusUrl(ctx.hostSessionId);
  if (url) ref.focus_url = url;
  return ref;
}

/** The Claude app's link to a Code session (go-to-session D4), or undefined in a terminal. */
export function focusUrl(hostSessionId: string | undefined): string | undefined {
  if (!hostSessionId || !/^[A-Za-z0-9_-]+$/.test(hostSessionId)) return undefined;
  return `claude://code/continue?session=${hostSessionId}`;
}

function clientOf(input: HookInput, ctx: HookContext): ClientIdentity {
  return { role: "hook", agent: AGENT, pid: ctx.pid, ppid: ctx.ppid, project_dir: ctx.projectDir ?? input.cwd ?? "" };
}

/**
 * Handles one hook invocation. Returns what to print on stdout ("" for
 * nothing). Never throws.
 */
export async function runHook(stdin: string, ctx: HookContext = defaultContext()): Promise<string> {
  let input: HookInput;
  try {
    input = JSON.parse(stdin);
  } catch {
    return "";
  }
  try {
    if (input.hook_event_name === "PermissionRequest") return await askPermission(input, ctx);
    const event = toEvent(input);
    if (!event) return "";
    if (event.kind === "turn_end" && input.transcript_path) {
      // Claude waits for a command it runs in the background: still at work.
      const transcript = ctx.readTranscript(input.transcript_path);
      const running = transcript ? runningBackgroundTasks(transcript).length : 0;
      if (running > 0) event.data = { ...event.data, background: running };
    }
    await ctx.sendEvent(clientOf(input, ctx), { type: "event", ts: ctx.now(), session: sessionOf(input, ctx), ...event });
  } catch {
    // Never disturb the agent.
  }
  return "";
}

async function askPermission(input: HookInput, ctx: HookContext): Promise<string> {
  if (ctx.permissionWaitMs <= 0) return "";
  // Asking in the app for permission to ask in the app is circular: leave the
  // Wobbo's own tools to Claude Code's prompt (or the user's allow list).
  if (isWobboTool(input.tool_name ?? "")) return "";
  // Asking the user is the interaction itself: no app prompt to allow it (work-and-wait D1).
  if (WAITS_FOR_USER.includes(input.tool_name ?? "")) return "";
  const { text, complete } = describePermission(input);
  if (!complete) {
    // Never offer Allow for something the balloon can't show in full: Claude
    // Code shows its own prompt at once, and the Wobbo jumps for attention
    // (open-source-readiness D4).
    await ctx.sendEvent(clientOf(input, ctx), {
      type: "event", ts: ctx.now(), session: sessionOf(input, ctx),
      kind: "input_wait", data: { reason: "permission_prompt", tool: input.tool_name ?? "" },
    });
    return "";
  }
  const conn = await ctx.connect(clientOf(input, ctx), CONNECT_TIMEOUT_MS);
  if (!conn) return "";
  const id = `perm-${ctx.pid}-${ctx.now()}`;
  conn.send({
    type: "request",
    ts: ctx.now(),
    id,
    session: sessionOf(input, ctx),
    kind: "permission",
    text,
    choices: ["allow", "deny"],
    allow_text: false,
    timeout_s: Math.round(ctx.permissionWaitMs / 1000),
  });
  const answer = await conn.waitForAnswer(id, ctx.permissionWaitMs);
  if (!answer) conn.send({ type: "cancel", ts: ctx.now(), id });
  await conn.close();
  if (answer?.status === "answered" && (answer.choice === "allow" || answer.choice === "deny")) {
    return permissionDecision(answer.choice);
  }
  return "";
}
