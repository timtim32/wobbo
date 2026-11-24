# How the Wobbos behave

A reference for what the app does, for developers and curious users. The
requirements behind it are in `openspec/specs/`; how to work on the code is in
[DEVELOPMENT.md](DEVELOPMENT.md).

## Several displays

Every connected display gets its own strip along its bottom edge. Together the
strips form one walkway, left to right in the order the displays are arranged
in System Settings → Displays. The Wobbos gather on one **home display**,
chosen in the menu bar under **Screen**:

- **Automatic (follow the mouse)** (default): the home display is the display
  your pointer is on, once it has stayed there for about 2 seconds.
- **A display by name**: the Wobbos stay on that display wherever the mouse
  goes. If it is disconnected, they use the main display until it comes back
  (the menu then shows it as "not connected").

When the home display changes, the Wobbos walk there. Between displays that
stand side by side they walk across the edge. Otherwise they walk off one
display and in at the facing edge of the next. A strip without anything on it
is hidden, so it costs no rendering. The choice is saved with the other
settings.

## The Wobbos

Every coding-agent session that is connected through the bridge (see below) gets
its own monster on the home display. It walks in from an outer edge of your
displays when the session starts, and waves and walks off again when it ends.
With no sessions the strip is empty.

What a Wobbo does shows what its session is doing:

| Session | Wobbo |
|---|---|
| thinking | looks up and taps its chin |
| working (running a tool) | busy at work: quick movements, hammering, typing on a laptop, turning a wrench or leafing through papers, taking and putting away its tool, switching every 8–15 seconds |
| waiting for you (a question, plan approval or permission) | keeps jumping with both arms up until you answer |
| turn finished | a happy jump and a laugh, then strolls around |
| error | a startled flinch, then strolls around |
| idle | strolls around its spot, with short pauses |
| 2 minutes without activity | falls asleep; new activity wakes it up |

- **Going home:** a Wobbo that has slept for 15 minutes walks off by itself.
  Right-click a Wobbo and choose **Send home** to send it away right away (in
  debug mode the menu also has **Type here (debug)**). The session keeps
  running; its Wobbo walks back in as soon as the session is used again (a new
  prompt, a tool, or a question for you). Handy for sessions you leave open to
  continue later.
- **Colours and names:** each Wobbo has its own colour from a set of 8 and a
  label with the project name. A project usually keeps its colour. Hide the
  labels with menu bar → **Show Names**.
- **At most 5 on screen:** with more sessions, the ones waiting for you come
  first, then the most recently active. When another session becomes active,
  the quietest Wobbo walks off to make room.
- **Looking and clicking:** the Wobbos follow your mouse pointer with their
  eye. Click a Wobbo to go to its session, whatever it is doing: the app that
  runs the session comes to the front (the Claude app, a terminal, an
  editor…), found from the agent's process, so it works for any agent. In the
  Claude app it opens exactly that Code session; in terminals and editors only
  the app comes forward, not the exact tab. Only a Wobbo that walks off because
  its session ended ignores the click. Right-clicking always opens its menu.
  The click acts when you let go of the button, so it can tell a click from a
  grab.
- **Picking up and dropping:** press a Wobbo and hold the button for a moment
  (or pull right away) to pick it up. It dangles from the spot you grabbed,
  kicking its legs, and swings as you move. Stir the pointer in small circles,
  about once a second, and it spins round like a hinge. You can carry it
  anywhere on the screen, also to another display. Let go and it flies on with
  your swing, falls, and lands with a squash; you can catch it again while it
  falls. On the home display it takes the nearest spot and the Wobbo that stood
  there swaps places with it; dropped on another display, it walks back home.
  A Wobbo that is walking off cannot be picked up.
- **Size:** menu bar → **Size** sets how big the Wobbos are: Small, Normal
  (default), Large or Extra large (about 80, 110, 140 or 170 points tall). All
  Wobbos change at once, walk at a matching pace, and the choice is saved.
- **Speech balloons:** when Claude says something (the `say` tool), its Wobbo
  shows it in a balloon above its head, with the session name in the header.
  A message stays 4 to 12 seconds depending on its length, stays open while the
  pointer rests on it, and closes when you click it.
- **Answering at the Wobbo:** a question (the `ask_user` tool) shows its
  choices as buttons, and a text field when Claude allows a typed answer. Click
  the field to type and press Enter to send, or Escape to stop typing; only
  then does the app take the keyboard, and it gives it back afterwards. A
  permission prompt shows **Allow** and **Deny** and a bar with the time left
  before Claude Code asks in the terminal. The **×** dismisses a question, or
  leaves a permission prompt to Claude Code at once. With several requests the
  balloon shows them one at a time ("1 of 2").
- **Questions in the session:** when Claude asks something in its own window
  (Claude Code's question tool, a plan to approve, or the question in the
  Claude app's next-step box), the Wobbo shows that question with its options
  as text and "Answer in the session". You answer it in the session: clicking
  the balloon takes you there. It closes once the question is answered or you
  send the next prompt; a **Done** notice does not hide it.
- **Notices:** a Wobbo says **Done** when its turn ends after working for at
  least 20 seconds, and **Something went wrong** when a turn fails. Quick
  replies and tool errors inside a turn are not announced.
- **Messages menu:** menu bar → **Messages** chooses the output: **Balloons**
  (default), **Speech** (spoken with the macOS voice for your language;
  questions still get a balloon so you can answer), **Balloons and Speech**, or
  **Off**. With Off, and while the Wobbos are hidden, nothing is shown or
  spoken and questions and permission prompts go straight back to Claude, so
  it asks in the conversation and Claude Code shows its own permission prompt
  without waiting. **Turn finished** and **Errors** turn the two notices on or
  off. The choices are saved.
- **Making way for the Dock:** with the Dock on automatic hiding at the bottom
  of the screen, the Wobbos on that display jump up onto the Dock as soon as
  it slides into view, and jump back down as it slides away. The app reads
  where the Dock is through the macOS Accessibility API, so the first time
  macOS asks to allow it under System Settings → Privacy & Security →
  Accessibility (while running from the editor the entry is called
  **Godot**). Without that permission the Wobbos follow the pointer instead,
  which is less exact. A Dock that is always visible, or sits on the left or
  right, needs nothing: the Wobbos already stand clear of it.
- **Quiet mode:** while all Wobbos sleep and no balloon is open, or none are
  on screen, the app drops to 10 frames per second to save energy.
- **No vsync:** the frame-rate cap paces drawing instead. With vsync on, a
  Wobbo on a second display walked jerkily: each strip window waited for its
  own display's refresh, and displays with different refresh rates (a 120 Hz
  laptop next to a 75 Hz monitor) made the frames uneven. macOS composites the
  windows, so this does not tear.
- **Demo:** menu bar → **Play Demo** plays a short show with pretend sessions,
  to show the Wobbos without running real agents. **Stop Demo** ends it.
