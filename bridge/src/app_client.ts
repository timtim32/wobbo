// Connection to the Wobbo app (claude-bridge D1, D2). Every failure means "app
// not available" and is reported as null, never thrown, so callers can stay
// silent towards the agent.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  type AppMessage,
  type Answer,
  BRIDGE_VERSION,
  type ClientIdentity,
  type ClientMessage,
  PROTOCOL_VERSION,
} from "./protocol";

export interface AppInfo {
  port: number;
  token: string;
  pid: number;
  protocol: number;
}

/** How long a connection that stays open waits for the app's `welcome`. */
export const CONNECT_TIMEOUT_MS = 200;
/** How long a hook event may take, from connecting until the app closes the connection. */
export const HOOK_SEND_TIMEOUT_MS = 300;
/** How long close() waits for unsent data to leave the socket. */
const CLOSE_FLUSH_MS = 200;

/**
 * Where the app's bridge.json may be, in order (standalone-app D8): Wobbo's data
 * folder, then the folder of the app from before the rename. WOBBO_INFO (or the
 * older CLAUDE_BUDDY_INFO) replaces both, for tests. The ClaudeBuddy paths are
 * Claude Buddy compatibility (renamed to Wobbo on 2026-11-24, standalone-app D5): remove once no 0.1.x installs remain.
 */
export function infoPaths(env: Record<string, string | undefined> = process.env, home = homedir()): string[] {
  const override = env.WOBBO_INFO ?? env.CLAUDE_BUDDY_INFO;
  if (override) return [override];
  const support = join(home, "Library", "Application Support");
  return [join(support, "Wobbo", "bridge.json"), join(support, "ClaudeBuddy", "bridge.json")];
}

function isRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as NodeJS.ErrnoException).code === "EPERM";
  }
}

/** The first bridge.json that belongs to a running app; null when there is none. */
export function findAppInfo(paths = infoPaths()): AppInfo | null {
  for (const path of paths) {
    const info = readAppInfo(path);
    if (info) return info;
  }
  return null;
}

/** Reads bridge.json; null when missing, invalid, another protocol, or stale (app not running). */
export function readAppInfo(path: string): AppInfo | null {
  try {
    const info = JSON.parse(readFileSync(path, "utf8")) as AppInfo;
    if (typeof info.port !== "number" || typeof info.token !== "string") return null;
    if (info.protocol !== PROTOCOL_VERSION) return null;
    if (typeof info.pid === "number" && !isRunning(info.pid)) return null;
    return info;
  } catch {
    return null;
  }
}

/** The `hello` frame that opens every connection (PROTOCOL.md). */
function helloFrame(info: AppInfo, client: ClientIdentity) {
  return { v: PROTOCOL_VERSION, type: "hello", token: info.token, client: { ...client, bridge_version: BRIDGE_VERSION } };
}

/**
 * Hook events: sends `hello` and `message` together as soon as the socket
 * opens (no wait for `welcome`), then waits until the app closes the
 * connection (PROTOCOL.md, "Hook connections"). Saves one app frame per hook.
 * Returns whether the app accepted it; never throws.
 */
export async function sendOnce(
  client: ClientIdentity,
  message: ClientMessage,
  timeoutMs = HOOK_SEND_TIMEOUT_MS,
  info: AppInfo | null = findAppInfo(),
): Promise<boolean> {
  if (!info) return false;
  return new Promise<boolean>((resolve) => {
    let ws: WebSocket;
    let accepted = false;
    try {
      ws = new WebSocket(`ws://127.0.0.1:${info.port}/`);
    } catch {
      return resolve(false);
    }
    const timer = setTimeout(() => {
      try {
        ws.close();
      } catch {}
      resolve(accepted);
    }, timeoutMs);
    ws.onopen = () => {
      ws.send(JSON.stringify(helloFrame(info, client)));
      ws.send(JSON.stringify({ v: PROTOCOL_VERSION, ...message }));
    };
    ws.onmessage = (e) => {
      try {
        accepted = JSON.parse(String(e.data)).type === "welcome";
      } catch {}
    };
    ws.onerror = ws.onclose = () => {
      clearTimeout(timer);
      resolve(accepted);
    };
  });
}

export class AppConnection {
  private listeners = new Set<(msg: AppMessage) => void>();
  private closedListeners = new Set<() => void>();
  closed = false;

  private constructor(private ws: WebSocket) {
    ws.onmessage = (e) => {
      let msg: AppMessage;
      try {
        msg = JSON.parse(String(e.data));
      } catch {
        return;
      }
      for (const l of this.listeners) l(msg);
    };
    ws.onclose = () => {
      this.closed = true;
      for (const l of this.closedListeners) l();
    };
  }

  /** Connects and completes the hello/welcome handshake, or returns null. */
  static async connect(
    client: ClientIdentity,
    timeoutMs = CONNECT_TIMEOUT_MS,
    info: AppInfo | null = findAppInfo(),
  ): Promise<AppConnection | null> {
    if (!info) return null;
    let ws: WebSocket;
    try {
      ws = new WebSocket(`ws://127.0.0.1:${info.port}/`);
    } catch {
      return null;
    }
    const welcomed = new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => resolve(false), timeoutMs);
      ws.onopen = () => ws.send(JSON.stringify(helloFrame(info, client)));
      ws.onmessage = (e) => {
        clearTimeout(timer);
        try {
          resolve(JSON.parse(String(e.data)).type === "welcome");
        } catch {
          resolve(false);
        }
      };
      ws.onerror = () => {
        clearTimeout(timer);
        resolve(false);
      };
      ws.onclose = () => {
        clearTimeout(timer);
        resolve(false);
      };
    });
    if (!(await welcomed)) {
      try {
        ws.close();
      } catch {}
      return null;
    }
    return new AppConnection(ws);
  }

  send(msg: ClientMessage): boolean {
    if (this.closed) return false;
    try {
      this.ws.send(JSON.stringify({ v: PROTOCOL_VERSION, ...msg }));
      return true;
    } catch {
      return false;
    }
  }

  onMessage(listener: (msg: AppMessage) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  onClose(listener: () => void): () => void {
    this.closedListeners.add(listener);
    return () => this.closedListeners.delete(listener);
  }

  /** Waits for the answer to request `id`; null on time-out or disconnect. */
  waitForAnswer(id: string, timeoutMs: number, signal?: AbortSignal): Promise<Answer | null> {
    return new Promise((resolve) => {
      if (this.closed) return resolve(null);
      const done = (value: Answer | null) => {
        clearTimeout(timer);
        offMessage();
        offClose();
        signal?.removeEventListener("abort", onAbort);
        resolve(value);
      };
      const onAbort = () => done(null);
      const timer = setTimeout(() => done(null), timeoutMs);
      const offMessage = this.onMessage((msg) => {
        if (msg.type === "answer" && msg.id === id) done(msg);
      });
      const offClose = this.onClose(() => done(null));
      signal?.addEventListener("abort", onAbort);
    });
  }

  /** Closes after the socket has flushed what was sent. */
  async close(): Promise<void> {
    if (this.closed) return;
    const flushed = Date.now() + CLOSE_FLUSH_MS;
    while ((this.ws as WebSocket & { bufferedAmount: number }).bufferedAmount > 0 && Date.now() < flushed) {
      await Bun.sleep(1);
    }
    try {
      this.ws.close(1000);
    } catch {}
    this.closed = true;
  }
}
