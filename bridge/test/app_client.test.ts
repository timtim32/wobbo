import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AppConnection, findAppInfo, infoPaths, readAppInfo } from "../src/app_client";
import { BRIDGE_VERSION } from "../src/protocol";
import { type FakeApp, startFakeApp } from "./fake_app";

const client = { role: "hook" as const, agent: "test", pid: process.pid, ppid: process.ppid, project_dir: "/tmp/x" };
let app: FakeApp | null = null;

afterEach(() => {
  app?.stop();
  app = null;
});

function tempFile(content: string): string {
  const path = join(mkdtempSync(join(tmpdir(), "wobbo-")), "bridge.json");
  writeFileSync(path, content);
  return path;
}

test("reads a valid bridge.json", () => {
  const info = readAppInfo(tempFile(JSON.stringify({ port: 1234, token: "t", pid: process.pid, protocol: 1 })));
  expect(info).toEqual({ port: 1234, token: "t", pid: process.pid, protocol: 1 });
});

test("missing, invalid, stale or other-protocol files mean: app not available", () => {
  expect(readAppInfo("/nonexistent/bridge.json")).toBeNull();
  expect(readAppInfo(tempFile("{not json"))).toBeNull();
  expect(readAppInfo(tempFile(JSON.stringify({ port: 1, token: "t", pid: 999999, protocol: 1 })))).toBeNull();
  expect(readAppInfo(tempFile(JSON.stringify({ port: 1, token: "t", pid: process.pid, protocol: 2 })))).toBeNull();
});

test("handshake succeeds with the right token", async () => {
  app = startFakeApp();
  const conn = await AppConnection.connect(client, 500, readAppInfo(app.infoPath));
  expect(conn).not.toBeNull();
  expect(app.hellos[0].client).toMatchObject({ role: "hook", agent: "test", bridge_version: BRIDGE_VERSION });
  await conn!.close();
});

test("a wrong token gives null", async () => {
  app = startFakeApp("right");
  const info = { ...readAppInfo(app.infoPath)!, token: "wrong" };
  expect(await AppConnection.connect(client, 500, info)).toBeNull();
});

test("fails fast when nothing listens", async () => {
  const start = performance.now();
  const conn = await AppConnection.connect(client, 200, { port: 1, token: "t", pid: process.pid, protocol: 1 });
  expect(conn).toBeNull();
  expect(performance.now() - start).toBeLessThan(400);
});

test("sent messages arrive before close", async () => {
  app = startFakeApp();
  const conn = (await AppConnection.connect(client, 500, readAppInfo(app.infoPath)))!;
  conn.send({ type: "say", ts: 1, session: null, text: "hi" });
  await conn.close();
  expect(await app.waitFor((m) => m.type === "say")).toMatchObject({ text: "hi" });
});

test("waitForAnswer resolves on the answer and on time-out", async () => {
  app = startFakeApp();
  const conn = (await AppConnection.connect(client, 500, readAppInfo(app.infoPath)))!;
  const pending = conn.waitForAnswer("q1", 2000);
  app.answer("q1", "answered", "yes");
  expect(await pending).toMatchObject({ id: "q1", status: "answered", choice: "yes" });
  expect(await conn.waitForAnswer("q2", 50)).toBeNull();
  await conn.close();
});

test("looks in Wobbo's folder, then in the folder from before the rename", () => {
  expect(infoPaths({}, "/Users/x")).toEqual([
    "/Users/x/Library/Application Support/Wobbo/bridge.json",
    "/Users/x/Library/Application Support/ClaudeBuddy/bridge.json",
  ]);
});

test("WOBBO_INFO and CLAUDE_BUDDY_INFO replace both folders", () => {
  expect(infoPaths({ WOBBO_INFO: "/a/bridge.json", CLAUDE_BUDDY_INFO: "/b/bridge.json" }, "/Users/x")).toEqual(["/a/bridge.json"]);
  expect(infoPaths({ CLAUDE_BUDDY_INFO: "/b/bridge.json" }, "/Users/x")).toEqual(["/b/bridge.json"]);
});

test("uses the first file whose app runs", () => {
  const alive = (port: number) => tempFile(JSON.stringify({ port, token: "t", pid: process.pid, protocol: 1 }));
  const stale = tempFile(JSON.stringify({ port: 1, token: "t", pid: 999999, protocol: 1 }));
  expect(findAppInfo([alive(10), alive(20)])?.port).toBe(10); // only/first: the new file
  expect(findAppInfo(["/nonexistent/bridge.json", alive(20)])?.port).toBe(20); // only the old file
  expect(findAppInfo([stale, alive(20)])?.port).toBe(20); // the new one is stale
  expect(findAppInfo([stale, "/nonexistent/bridge.json"])).toBeNull();
});
