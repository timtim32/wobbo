// Demo client for the Wobbo app (run with Bun). It uses
// the long-lived "mcp" role, because a "hook" connection carries one message.
//
//   bun bridge/scripts/demo_client.ts
//
// Plays a fake session through the states, says something, asks a question with
// choices and a free-text option, and prints the answer from the app's debug
// panel. Exits when the question is answered or dismissed.
import { findAppInfo } from "../src/app_client";

const info = findAppInfo() ?? notRunning();

function notRunning(): never {
  console.error("Wobbo is not running (no bridge.json in its data folder).");
  process.exit(1);
}
const session = { id: `demo-${process.pid}`, agent: "demo", project_dir: "/tmp/demo-project" };
const ws = new WebSocket(`ws://127.0.0.1:${info.port}/`);
const send = (msg: object) => ws.send(JSON.stringify({ v: 1, ts: Date.now(), ...msg }));
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

ws.onopen = async () => {
  ws.send(JSON.stringify({ v: 1, type: "hello", token: info.token,
    client: { role: "mcp", agent: "demo", pid: process.pid, ppid: process.ppid, project_dir: session.project_dir } }));
};

ws.onmessage = async (e) => {
  const msg = JSON.parse(String(e.data));
  if (msg.type === "welcome") {
    console.log(`connected to Wobbo ${msg.app_version} on port ${info.port}`);
    for (const [kind, data] of [["session_start", {}], ["prompt", {}], ["tool_start", { tool: "Bash" }],
                                ["tool_end", { tool: "Bash" }], ["turn_end", {}]] as const) {
      send({ type: "event", session, kind, data });
      console.log(`event ${kind}`);
      await sleep(1500);
    }
    send({ type: "say", session, text: "Hello from the demo client" });
    send({ type: "request", session, id: `q-${process.pid}`, kind: "question",
      text: "Does the debug panel work?", choices: ["yes", "no"], allow_text: true, timeout_s: 300 });
    console.log("question sent, answer it in the debug panel…");
  } else if (msg.type === "answer") {
    console.log(`answer: status=${msg.status} choice=${msg.choice ?? ""} text=${msg.text ?? ""}`);
    send({ type: "event", session, kind: "session_end", data: { reason: "demo" } });
    await sleep(200);
    process.exit(0);
  } else if (msg.type === "error") {
    console.error(`rejected: ${msg.reason}`);
    process.exit(1);
  }
};
ws.onclose = () => {
  console.error("The app closed the connection.");
  process.exit(1);
};
ws.onerror = () => {
  console.error("Wobbo is not running (no connection).");
  process.exit(1);
};
