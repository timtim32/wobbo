import { afterEach, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { AppConnection, readAppInfo, sendOnce } from "../src/app_client";
import { askedQuestion, describePermission, focusUrl, NEXT_STEP_TOOL, type HookContext, isBuddyTool, permissionDecision, runHook, toEvent, toolLabel } from "../src/adapters/claude_code";
import { type FakeApp, startFakeApp } from "./fake_app";

const samples: Record<string, any> = JSON.parse(readFileSync(join(import.meta.dir, "hook_samples.json"), "utf8"));
let app: FakeApp | null = null;

afterEach(() => {
  app?.stop();
  app = null;
});

function ctx(overrides: Partial<HookContext> = {}): HookContext {
  return {
    ppid: 4100,
    pid: 4242,
    projectDir: "/Users/me/Projects/api",
    now: () => 1_000,
    permissionWaitMs: 2000,
    connect: (client, timeoutMs) => AppConnection.connect(client, timeoutMs, app ? readAppInfo(app.infoPath) : null),
    sendEvent: (client, message) => sendOnce(client, message, 300, app ? readAppInfo(app.infoPath) : null),
    ...overrides,
  };
}

test("maps every status hook to a protocol event", () => {
  const expected: Record<string, string | null> = {
    SessionStart: "session_start",
    UserPromptSubmit: "prompt",
    PreToolUse: "tool_start",
    PostToolUse: "tool_end",
    PostToolUseFailure: "tool_error",
    Notification: "input_wait", // the sample is a permission prompt (work-and-wait D1)
    Stop: "turn_end",
    StopFailure: "turn_error",
    SessionEnd: "session_end",
    SubagentStart: null,
  };
  for (const [event, kind] of Object.entries(expected)) {
    expect<string | null>(toEvent(samples[event])?.kind ?? null).toBe(kind);
  }
  expect(toEvent(samples.PreToolUse)!.data).toEqual({ tool: "Bash" });
  expect(toEvent(samples.PostToolUseFailure)!.data).toMatchObject({ tool: "Bash", error: "Command failed with exit code 1" });
});

test("sends the event with session, ppid and project dir", async () => {
  app = startFakeApp();
  expect(await runHook(JSON.stringify(samples.PreToolUse), ctx())).toBe("");
  const msg = await app.waitFor((m) => m.type === "event");
  expect(msg).toMatchObject({
    kind: "tool_start",
    ts: 1000,
    session: { id: "5c1e-session", agent: "claude-code", project_dir: "/Users/me/Projects/api" },
  });
  expect(app.hellos[0].client).toMatchObject({ role: "hook", ppid: 4100, agent: "claude-code" });
});

test("no app: no output, no error, fast", async () => {
  const start = performance.now();
  expect(await runHook(JSON.stringify(samples.Stop), ctx())).toBe("");
  expect(await runHook(JSON.stringify(samples.PermissionRequest), ctx())).toBe("");
  expect(await runHook("not json", ctx())).toBe("");
  expect(performance.now() - start).toBeLessThan(100);
});

test("permission allowed in the app", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "allow" });
  const out = await runHook(JSON.stringify(samples.PermissionRequest), ctx());
  expect(JSON.parse(out)).toEqual({
    hookSpecificOutput: { hookEventName: "PermissionRequest", decision: { behavior: "allow" } },
  });
  const request = await app.waitFor((m) => m.type === "request");
  expect(request).toMatchObject({ kind: "permission", text: "Bash: rm -rf build", choices: ["allow", "deny"] });
});

test("permission denied in the app", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "deny" });
  const out = JSON.parse(await runHook(JSON.stringify(samples.PermissionRequest), ctx()));
  expect(out.hookSpecificOutput.decision.behavior).toBe("deny");
  expect(out.hookSpecificOutput.decision.message).toContain("denied");
});

test("permission not decided in time: no output, request cancelled", async () => {
  app = startFakeApp();
  const out = await runHook(JSON.stringify(samples.PermissionRequest), ctx({ permissionWaitMs: 100 }));
  expect(out).toBe("");
  expect(await app.waitFor((m) => m.type === "cancel")).toBeDefined();
});

test("permission dismissed: no output", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "dismissed" });
  expect(await runHook(JSON.stringify(samples.PermissionRequest), ctx())).toBe("");
});

test("describes permissions briefly", () => {
  expect(describePermission({ tool_name: "Edit", tool_input: { file_path: "/a/b.ts", old_string: "x" } })).toBe(
    "Edit: /a/b.ts",
  );
  expect(describePermission({ tool_name: "WebFetch", tool_input: { url: "https://x.y" } })).toBe("WebFetch: https://x.y");
  expect(describePermission({ tool_name: "Bash", tool_input: { command: "x".repeat(400) } }).length).toBe(300);
  expect(JSON.parse(permissionDecision("allow")).hookSpecificOutput.hookEventName).toBe("PermissionRequest");
});

test("MCP tools are described readably, not as JSON", () => {
  expect(toolLabel("mcp__plugin_buddy-bridge_buddy__ask_user")).toBe("buddy · ask_user");
  expect(toolLabel("mcp__github__create_issue")).toBe("github · create_issue");
  expect(toolLabel("Bash")).toBe("Bash");
  expect(
    describePermission({ tool_name: "mcp__github__create_issue", tool_input: { repo: "a/b", title: "Bug", body: "x" } }),
  ).toBe("github · create_issue: a/b");
  expect(describePermission({ tool_name: "mcp__x__y", tool_input: { count: 3 } })).toBe("x · y: count");
});

test("the buddy's own tools are not mirrored to the app", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "allow" });
  expect(isBuddyTool("mcp__plugin_buddy-bridge_buddy__ask_user")).toBe(true);
  expect(isBuddyTool("mcp__plugin_buddy-bridge_buddy__say")).toBe(true);
  expect(isBuddyTool("mcp__plugin_wobbo_wobbo__say")).toBe(true);
  expect(isBuddyTool("mcp__wobbo__ask_user")).toBe(true);
  expect(isBuddyTool("mcp__github__say")).toBe(false);
  const input = { ...samples.PermissionRequest, tool_name: "mcp__plugin_buddy-bridge_buddy__ask_user",
    tool_input: { question: "Verder?" } };
  expect(await runHook(JSON.stringify(input), ctx())).toBe("");
  expect(app.received.length).toBe(0);
});

test("waiting for the user is reported as input_wait", () => {
  const pre = (tool_name: string) => toEvent({ ...samples.PreToolUse, tool_name });
  expect(pre("AskUserQuestion")).toEqual({ kind: "input_wait", data: { reason: "tool", tool: "AskUserQuestion" } });
  expect(pre("ExitPlanMode")!.kind).toBe("input_wait");
  expect(pre("Bash")!.kind).toBe("tool_start");
  const note = (notification_type: string) => toEvent({ ...samples.Notification, notification_type });
  expect(note("permission_prompt")).toEqual({ kind: "input_wait", data: { reason: "permission_prompt" } });
  expect(note("elicitation_dialog")!.kind).toBe("input_wait");
  expect(note("idle_prompt")!.kind).toBe("notification");
  expect(note("")!.kind).toBe("notification");
});

test("asking the user is not mirrored as a permission request", async () => {
  app = startFakeApp();
  app.autoAnswer = () => ({ status: "answered", choice: "allow" });
  for (const tool_name of ["AskUserQuestion", "ExitPlanMode"]) {
    const input = { ...samples.PermissionRequest, tool_name, tool_input: {} };
    expect(await runHook(JSON.stringify(input), ctx())).toBe("");
  }
  expect(app.received.length).toBe(0);
});

test("sessions in the Claude app carry a focus link", () => {
  expect(focusUrl("local_43ed222a-03b3-4ecf-9560-7190644f9d85")).toBe(
    "claude://code/continue?session=local_43ed222a-03b3-4ecf-9560-7190644f9d85",
  );
  expect(focusUrl(undefined)).toBeUndefined();
  expect(focusUrl("x&y=1")).toBeUndefined();
});

test("the event's session has the focus link only in the Claude app", async () => {
  app = startFakeApp();
  await runHook(JSON.stringify(samples.UserPromptSubmit), ctx({ hostSessionId: "local_abc" }));
  await runHook(JSON.stringify(samples.UserPromptSubmit), ctx());
  const sessions = app.received.filter((m: any) => m.type === "event").map((m: any) => m.session);
  expect(sessions[0].focus_url).toBe("claude://code/continue?session=local_abc");
  expect(sessions[1].focus_url).toBeUndefined();
});

// --- balloons-and-speech D11: questions asked in Claude's own UI -------------------

test("the question tool sends its first question and options", () => {
  const e = toEvent({ ...samples.PreToolUse, tool_name: "AskUserQuestion", tool_input: {
    questions: [{ question: "Which database?", header: "DB", multiSelect: false,
      options: [{ label: "Postgres", description: "" }, { label: "SQLite", description: "" }] }] } });
  expect(e).toEqual({ kind: "input_wait", data: { reason: "tool", tool: "AskUserQuestion",
    question: "Which database?", choices: ["Postgres", "SQLite"], question_until: "answer" } });
});

test("several questions are counted", () => {
  const q = askedQuestion("AskUserQuestion", { questions: [{ question: "One?" }, { question: "Two?" }, { question: "Three?" }] });
  expect(q!.question).toBe("One? (+2 more)");
  expect(q!.choices).toEqual([]);
});

test("plan approval asks for approval", () => {
  expect(askedQuestion("ExitPlanMode", { plan: "# Plan" })).toEqual({
    question: "Plan ready for your approval", choices: [], question_until: "answer" });
});

test("the Claude app's next-step box stays a tool start with its question", () => {
  const e = toEvent({ ...samples.PreToolUse, tool_name: NEXT_STEP_TOOL, tool_input: {
    recap: "Built it.", ask: "Shall I commit this and open a PR?",
    actions: [{ label: "Commit and PR" }, { label: "Try it first" }] } });
  expect(e).toEqual({ kind: "tool_start", data: { tool: NEXT_STEP_TOOL,
    question: "Shall I commit this and open a PR?", choices: ["Commit and PR", "Try it first"], question_until: "prompt" } });
});

test("a next-step box without a question, or with odd fields, is a plain tool start", () => {
  const plain = { kind: "tool_start" as const, data: { tool: NEXT_STEP_TOOL } };
  expect(toEvent({ ...samples.PreToolUse, tool_name: NEXT_STEP_TOOL, tool_input: { recap: "Done." } })).toEqual(plain);
  expect(toEvent({ ...samples.PreToolUse, tool_name: NEXT_STEP_TOOL, tool_input: { ask: 42, actions: "x" } })).toEqual(plain);
  const odd = askedQuestion(NEXT_STEP_TOOL, { ask: "Go?", actions: [{ label: 3 }, null, { label: "Yes" }, "No"] });
  expect(odd!.choices).toEqual(["Yes"]);
});

test("long questions and choices are cut", () => {
  const q = askedQuestion(NEXT_STEP_TOOL, { ask: "x".repeat(900), actions: Array(9).fill({ label: "y".repeat(90) }) });
  expect(q!.question.length).toBe(500);
  expect(q!.choices.length).toBe(6);
  expect(q!.choices[0].length).toBe(40);
});
