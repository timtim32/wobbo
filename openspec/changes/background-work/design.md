# Design

## Context

Claude Code reports status through hooks; the bridge maps `Stop` to `turn_end`, and the app sets the session to `done` (`session_registry.gd`) and may show "Done" (`messages.gd`, `message_policy.gd`). A Bash call with `run_in_background: true` returns at once, so the tool finishes, the turn ends, and the Wobbo reports `done` while the command still runs. When the command ends, Claude Code wakes Claude with a task notification; Claude then uses tools and ends its turn again, which fires `PreToolUse`/`Stop` as usual.

Claude Code (2.1.x) has no hook for "a background command ended" (`TaskCreated`/`TaskCompleted` are for the task list of agent teams). Each hook's input does carry `transcript_path`, the session's JSONL transcript. Observed in this session's transcript:

- The tool result of a background Bash call has `"toolUseResult": {..., "backgroundTaskId": "b78yid9mm"}`.
- When the command ends, Claude Code writes a `queue-operation` (and an attachment) whose content is a `<task-notification>` with `<task-id>b78yid9mm</task-id>` and `<status>completed</status>`. This line is written when the notification arrives, also when it is absorbed in the middle of a turn.

No macOS-specific APIs; Godot 4.7 GDScript as elsewhere.

## Goals / Non-Goals

**Goals:**
- The Wobbo looks busy (`working`) while Claude waits for a command it runs in the background.
- No false "Done" for such a turn; the real "Done" comes when Claude finishes after being woken.
- Never slow down or break Claude Code; when anything is unclear, fall back to today's behaviour (`done`).

**Non-Goals:**
- Background subagents, the Monitor tool, other background task kinds.
- Noticing the end of a command without a later hook (no watcher process).

## Decisions

### D1. Count at the end of the turn, from the transcript

On `Stop` only, the bridge reads the transcript and counts background commands that have started and not ended: ids from `"backgroundTaskId":"<id>"`, minus ids that appear in a `<task-id><id></task-id> … <status>X</status>` with `X` other than `running`. The count goes into `turn_end` as `data.background` (left out when 0).

Alternatives: track starts in the app from `PostToolUse` (needs `tool_response` and still no end signal: the end only shows up in the transcript); a detached watcher process per command (heavy, and hooks must stay short-lived). Reading only at `Stop` keeps every other hook as cheap as now.

Matching uses plain regular expressions over the raw text instead of parsing every JSON line: fast on large transcripts, and the start pattern `"backgroundTaskId":"` only matches real JSON keys, not the same text quoted inside another tool's output (there the quotes are escaped). A notification text quoted inside some tool output could at worst mark a command as ended: that falls back to `done`, the old behaviour.

### D2. Read at most the last 32 MB

Transcripts grow; a command started long ago in a very long session could fall outside. Reading the tail bounds the time of the `Stop` hook (which is `async` anyway). A start that falls outside is simply not counted (old behaviour).

### D3. App: `turn_end` with `background > 0` is `working`

`session_registry.gd` sets `working` with an empty tool, instead of `done`; the work animation plays. The next state event decides again: when Claude is woken it sends `tool_start`/`tool_end`/`turn_end` as usual, and that `turn_end` (now with no background) gives `done`. The timestamp ordering and pending-request handling stay as they are.

`messages.gd` does not call the turn-finished policy for such a `turn_end`. `turn_started_msec` is left untouched, so the later "Done" counts from the user's prompt and is shown (the whole job took longer than 20 s).

### D4. Protocol stays version 1

`background` is an optional field of `turn_end`; an older app ignores it and shows `done` (today's behaviour), a newer app with an older bridge never sees it.

## Risks / Trade-offs

- **[Transcript format is not a public API]** → Spike-like assumption, checked on Claude Code 2.1.331 in this session. If the keys change, the count is 0 and Wobbo falls back to `done`; a test with a sample transcript pins the expected format.
- **[Claude is never woken]** (Claude Code quit, command killed outside Claude) → the Wobbo stays `working` until the next event, `session_end`, or the 30-minute silence rule removes it. Acceptable; a quit session sends `session_end`.
- **[Several background commands]** → when the first ends, Claude is woken and ends its turn; the count is then 1 and the Wobbo stays `working`, which is right.
- **[Cost of reading the transcript]** → only at `Stop`, bounded to 32 MB, in an `async` hook.
