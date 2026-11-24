import { afterEach, expect, test } from "bun:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { AppConnection, readAppInfo } from "../src/app_client";
import { createMcpServer } from "../src/mcp_server";
import { type FakeApp, startFakeApp } from "./fake_app";

let app: FakeApp | null = null;

afterEach(() => {
  app?.stop();
  app = null;
});

async function connectClient(withApp: boolean, progressIntervalMs = 20_000) {
  const server = createMcpServer({
    agent: "test-agent",
    progressIntervalMs,
    connect: (client) => AppConnection.connect(client, 500, withApp && app ? readAppInfo(app.infoPath) : null),
  });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await server.connect(serverTransport);
  const client = new Client({ name: "claude-ai", version: "1.0.0" });
  await client.connect(clientTransport);
  return client;
}

const textOf = (result: any) => result.content[0].text as string;

test("lists say and ask_user", async () => {
  const client = await connectClient(false);
  const names = (await client.listTools()).tools.map((t) => t.name).sort();
  expect(names).toEqual(["ask_user", "say"]);
});

test("say shows the message and identifies the MCP client", async () => {
  app = startFakeApp();
  const client = await connectClient(true);
  const result = await client.callTool({ name: "say", arguments: { text: "Tests are green" } });
  expect(textOf(result)).toBe("Shown to the user in Wobbo.");
  expect(await app.waitFor((m) => m.type === "say")).toMatchObject({ text: "Tests are green", session: null });
  expect(app.hellos[0].client).toMatchObject({ role: "mcp", agent: "test-agent", client_name: "claude-ai" });
});

test("ask_user returns the chosen answer", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "no" });
  const client = await connectClient(true);
  const result = await client.callTool({ name: "ask_user", arguments: { question: "Continue?", choices: ["yes", "no"] } });
  expect(textOf(result)).toBe("The user answered: no");
  expect(await app.waitFor((m) => m.type === "request")).toMatchObject({
    kind: "question",
    text: "Continue?",
    choices: ["yes", "no"],
    allow_text: false,
    timeout_s: 600,
  });
});

test("ask_user returns typed text", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "", text: "use staging" });
  const client = await connectClient(true);
  const result = await client.callTool({ name: "ask_user", arguments: { question: "Where?", allow_text: true } });
  expect(textOf(result)).toBe("The user answered: use staging");
});

test("ask_user dismissed", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "dismissed" });
  const client = await connectClient(true);
  const result = await client.callTool({ name: "ask_user", arguments: { question: "Continue?" } });
  expect(textOf(result)).toContain("dismissed");
});

test("ask_user times out, cancels, and sends progress while waiting", async () => {
  app = startFakeApp();
  const client = await connectClient(true, 30);
  const progress: number[] = [];
  const result = await client.callTool(
    { name: "ask_user", arguments: { question: "Continue?", timeout_s: 10 } },
    undefined,
    { onprogress: (p) => progress.push(p.progress), timeout: 15_000 },
  );
  expect(textOf(result)).toContain("did not answer");
  expect(await app.waitFor((m) => m.type === "cancel")).toBeDefined();
  expect(progress.length).toBeGreaterThan(10);
}, 15_000);

test("no app: both tools say so at once", async () => {
  const client = await connectClient(false);
  const start = performance.now();
  expect(textOf(await client.callTool({ name: "say", arguments: { text: "hi" } }))).toContain("not running");
  expect(textOf(await client.callTool({ name: "ask_user", arguments: { question: "?" } }))).toContain("not running");
  expect(performance.now() - start).toBeLessThan(500);
});
