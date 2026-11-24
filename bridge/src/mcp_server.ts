// MCP server with the `say` and `ask_user` tools (claude-bridge D6, D7). Works with
// any MCP client. Keeps one connection to the app, reconnecting lazily, and
// always answers the model with plain text it can act on.
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { Transport } from "@modelcontextprotocol/sdk/shared/transport.js";
import { z } from "zod";
import { AppConnection } from "./app_client";
import { BRIDGE_VERSION, type ClientIdentity } from "./protocol";

export const DEFAULT_ASK_TIMEOUT_S = 600;
export const MAX_ASK_TIMEOUT_S = 1800;
export const PROGRESS_INTERVAL_MS = 20_000;
/** How long a tool call waits for the app's `welcome` before it reports the app as not running. */
export const MCP_CONNECT_TIMEOUT_MS = 300;

const NOT_AVAILABLE =
  "Wobbo is not running, so nothing was shown. Continue in the conversation instead.";

export interface McpOptions {
  agent: string;
  connect?: (client: ClientIdentity) => Promise<AppConnection | null>;
  progressIntervalMs?: number;
  now?: () => number;
}

const text = (t: string) => ({ content: [{ type: "text" as const, text: t }] });

export function createMcpServer(options: McpOptions): McpServer {
  const server = new McpServer({ name: "wobbo", version: BRIDGE_VERSION });
  const connect = options.connect ?? ((client) => AppConnection.connect(client, MCP_CONNECT_TIMEOUT_MS));
  const now = options.now ?? (() => Date.now());
  const progressEvery = options.progressIntervalMs ?? PROGRESS_INTERVAL_MS;
  let conn: AppConnection | null = null;
  let requestCounter = 0;

  async function app(): Promise<AppConnection | null> {
    if (conn && !conn.closed) return conn;
    conn = await connect({
      role: "mcp",
      agent: options.agent,
      pid: process.pid,
      ppid: process.ppid,
      project_dir: process.env.CLAUDE_PROJECT_DIR ?? "",
      client_name: server.server.getClientVersion()?.name ?? "",
    });
    return conn;
  }

  server.registerTool(
    "say",
    {
      title: "Say something through Wobbo",
      description:
        "Show a short message to the user through their Wobbo desktop companion (a small character on " +
        "their screen). Use it for brief, friendly status updates the user should notice even when they are not " +
        "looking at this conversation, for example when a long task is finished. Keep it under one sentence.",
      inputSchema: { text: z.string().min(1).max(500).describe("The message, one short sentence.") },
    },
    async ({ text: message }) => {
      const c = await app();
      if (!c || !c.send({ type: "say", ts: now(), session: null, text: message })) return text(NOT_AVAILABLE);
      return text("Shown to the user in Wobbo.");
    },
  );

  server.registerTool(
    "ask_user",
    {
      title: "Ask the user through Wobbo",
      description:
        "Ask the user a short question through their Wobbo desktop companion and wait for the answer. " +
        "Use it only when you need a decision and the user may not be watching this conversation. Offer a few " +
        "short choices when possible. Returns the user's answer, or tells you to ask in the conversation instead.",
      inputSchema: {
        question: z.string().min(1).max(500).describe("The question, short and self-contained."),
        choices: z.array(z.string().min(1).max(40)).max(6).optional().describe("Answer options, e.g. ['yes', 'no']."),
        allow_text: z.boolean().optional().describe("Whether the user may type a free-text answer."),
        timeout_s: z
          .number()
          .int()
          .min(10)
          .max(MAX_ASK_TIMEOUT_S)
          .optional()
          .describe(`How long to wait for an answer, in seconds (default ${DEFAULT_ASK_TIMEOUT_S}).`),
      },
    },
    async ({ question, choices, allow_text, timeout_s }, extra) => {
      const c = await app();
      if (!c) return text(NOT_AVAILABLE);
      const timeout = timeout_s ?? DEFAULT_ASK_TIMEOUT_S;
      const id = `ask-${process.pid}-${++requestCounter}-${now()}`;
      const sent = c.send({
        type: "request",
        ts: now(),
        id,
        session: null,
        kind: "question",
        text: question,
        choices: choices ?? [],
        allow_text: allow_text ?? (choices ?? []).length === 0,
        timeout_s: timeout,
      });
      if (!sent) return text(NOT_AVAILABLE);
      // Keep the client's idle timer alive while the user thinks.
      const progressToken = extra._meta?.progressToken;
      let ticks = 0;
      const timer =
        progressToken !== undefined
          ? setInterval(() => {
              ticks += 1;
              extra
                .sendNotification({
                  method: "notifications/progress",
                  params: { progressToken, progress: ticks, message: "Waiting for the user in Wobbo" },
                })
                .catch(() => {});
            }, progressEvery)
          : null;
      const answer = await c.waitForAnswer(id, timeout * 1000, extra.signal);
      if (timer) clearInterval(timer);
      if (!answer) {
        c.send({ type: "cancel", ts: now(), id });
        return text("The user did not answer in Wobbo. Ask in the conversation instead if you still need an answer.");
      }
      if (answer.status === "dismissed") {
        return text("The user dismissed the question in Wobbo. Ask in the conversation if you still need an answer.");
      }
      const reply = answer.text?.trim() ? answer.text.trim() : (answer.choice ?? "");
      return text(`The user answered: ${reply}`);
    },
  );

  return server;
}

export async function runMcpServer(agent: string, transport: Transport = new StdioServerTransport()): Promise<void> {
  const server = createMcpServer({ agent });
  // The open app connection would keep the process alive: exit when the
  // client goes away (stdin closes) or the transport closes.
  const exit = () => process.exit(0);
  transport.onclose = exit;
  process.stdin.on("end", exit);
  process.stdin.on("close", exit);
  await server.connect(transport);
}
