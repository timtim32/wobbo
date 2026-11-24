// Fake agent sessions for trying out the avatars (session-avatars design D10).
// No dependencies, run with Bun. Every command is one short hook-style
// connection, so sessions live on in the app between commands.
//
//   bun bridge/scripts/fake_sessions.ts add website            new session "website"
//   bun bridge/scripts/fake_sessions.ts add-many 6             sessions "fake-1" … "fake-6"
//   bun bridge/scripts/fake_sessions.ts state website working  idle|thinking|working|done|error
//   bun bridge/scripts/fake_sessions.ts say website "Hello"    a message from the session
//   bun bridge/scripts/fake_sessions.ts ask website            waits until answered in the app
//   bun bridge/scripts/fake_sessions.ts end website            the session ends
//   bun bridge/scripts/fake_sessions.ts end-all fake-1 fake-2  several at once
//
// The session id is "fake-<name>" and the project directory "/tmp/fake/<name>",
// so the app shows <name> as the session's display name.
import { readFileSync } from "node:fs";
import { findAppInfo } from "../src/app_client";

const STATE_EVENTS: Record<string, [string, object]> = {
  idle: ["session_start", {}],
  thinking: ["prompt", {}],
  working: ["tool_start", { tool: "Bash" }],
  done: ["turn_end", {}],
  error: ["turn_error", { error: "fake error" }],
};

const info = findAppInfo() ?? notRunning();

function notRunning(): never {
  console.error("Wobbo is not running (no bridge.json in its data folder).");
  process.exit(1);
}

const session = (name: string) => ({ id: `fake-${name}`, agent: "fake", project_dir: `/tmp/fake/${name}` });

/** Sends one frame on its own hook connection; resolves with the answer for requests. */
function send(frame: object, waitForAnswer = false): Promise<any> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${info.port}/`);
    ws.onopen = () => {
      ws.send(JSON.stringify({ v: 1, type: "hello", token: info.token,
        client: { role: "hook", agent: "fake", pid: process.pid, ppid: process.ppid, project_dir: "" } }));
      ws.send(JSON.stringify({ v: 1, ts: Date.now(), ...frame }));
    };
    ws.onmessage = (e) => {
      const msg = JSON.parse(String(e.data));
      if (msg.type === "error") reject(new Error(`rejected: ${msg.reason}`));
      if (msg.type === "answer") {
        resolve(msg);
        ws.close();
      }
    };
    ws.onclose = () => resolve(null); // the app closes after an event or say
    ws.onerror = () => reject(new Error("Wobbo is not running (no connection)."));
    if (!waitForAnswer) setTimeout(() => resolve(null), 1000);
  });
}

const event = (name: string, kind: string, data: object = {}) =>
  send({ type: "event", session: session(name), kind, data });

async function main(args: string[]) {
  const [cmd, name, ...rest] = args;
  switch (cmd) {
    case "add":
      await event(name, "session_start");
      break;
    case "add-many":
      for (let i = 1; i <= Number(name); i++) {
        await event(`fake-${i}`, "session_start");
        await Bun.sleep(300);
      }
      break;
    case "state": {
      const pair = STATE_EVENTS[rest[0]];
      if (!pair) throw new Error(`unknown state "${rest[0]}" (idle|thinking|working|done|error)`);
      await event(name, pair[0], pair[1]);
      break;
    }
    case "say":
      await send({ type: "say", session: session(name), text: rest.join(" ") || "Hello" });
      break;
    case "ask": {
      const answer = await send({ type: "request", session: session(name), id: `fake-q-${Date.now()}`,
        kind: "question", text: `Question from ${name}`, choices: ["yes", "no"], allow_text: false,
        timeout_s: 600 }, true);
      console.log(`answer: ${answer?.status ?? "none"} ${answer?.choice ?? ""}`);
      break;
    }
    case "end":
      await event(name, "session_end", { reason: "fake" });
      break;
    case "end-all":
      for (const n of [name, ...rest]) await event(n, "session_end", { reason: "fake" });
      break;
    default:
      console.log(readFileSync(import.meta.path, "utf8").split("\n").slice(0, 13).join("\n"));
      process.exit(cmd ? 1 : 0);
  }
}

main(process.argv.slice(2)).then(() => process.exit(0), (e) => {
  console.error(e.message);
  process.exit(1);
});
