// A fake Wobbo app for tests: a WebSocket server on a random port that
// checks the token, records messages and can answer requests.
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ServerWebSocket } from "bun";

export interface FakeApp {
  port: number;
  token: string;
  infoPath: string;
  received: any[];
  hellos: any[];
  answer(id: string, status: "answered" | "dismissed", choice?: string, text?: string): void;
  /** Answer every incoming request automatically. */
  autoAnswer?: (request: any) => { status: "answered" | "dismissed"; choice?: string; text?: string } | null;
  waitFor(predicate: (msg: any) => boolean, timeoutMs?: number): Promise<any>;
  stop(): void;
}

export function startFakeApp(token = "test-token"): FakeApp {
  const sockets = new Set<ServerWebSocket<unknown>>();
  const app: Partial<FakeApp> = { token, received: [], hellos: [] };
  const server = Bun.serve({
    port: 0,
    hostname: "127.0.0.1",
    fetch(req, srv) {
      if (srv.upgrade(req)) return;
      return new Response("no", { status: 400 });
    },
    websocket: {
      open(ws) {
        sockets.add(ws);
      },
      close(ws) {
        sockets.delete(ws);
      },
      message(ws, raw) {
        const msg = JSON.parse(String(raw));
        if (msg.type === "hello") {
          app.hellos!.push(msg);
          if (msg.token !== token) {
            ws.send(JSON.stringify({ v: 1, type: "error", reason: "bad_token" }));
            ws.close();
            return;
          }
          ws.send(JSON.stringify({ v: 1, type: "welcome", app_version: "test" }));
          return;
        }
        app.received!.push(msg);
        if (app.hellos!.at(-1)?.client?.role === "hook" && (msg.type === "event" || msg.type === "say")) {
          ws.close(1000, "done"); // like the real app (PROTOCOL.md, "Hook connections")
        }
        if (msg.type === "request" && app.autoAnswer) {
          const a = app.autoAnswer(msg);
          if (a) ws.send(JSON.stringify({ v: 1, type: "answer", id: msg.id, ...a }));
        }
      },
    },
  });
  const dir = mkdtempSync(join(tmpdir(), "buddy-"));
  const infoPath = join(dir, "bridge.json");
  writeFileSync(infoPath, JSON.stringify({ port: server.port, token, pid: process.pid, protocol: 1 }));
  return Object.assign(app, {
    port: server.port,
    infoPath,
    answer(id: string, status: "answered" | "dismissed", choice?: string, text?: string) {
      for (const ws of sockets) ws.send(JSON.stringify({ v: 1, type: "answer", id, status, choice, text }));
    },
    async waitFor(predicate: (msg: any) => boolean, timeoutMs = 2000) {
      const end = Date.now() + timeoutMs;
      while (Date.now() < end) {
        const hit = app.received!.find(predicate);
        if (hit) return hit;
        await Bun.sleep(5);
      }
      return undefined;
    },
    stop() {
      server.stop(true);
    },
  }) as FakeApp;
}
