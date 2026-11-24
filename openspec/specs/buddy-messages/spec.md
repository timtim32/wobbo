# buddy-messages Specification

## Purpose
Lets the buddies tell the user what their sessions want to say, ask or report, in a speech balloon above the buddy and optionally out loud, and lets the user answer questions and permission prompts right at the buddy.

## Requirements

### Requirement: Messages in a balloon
When the output is Balloons or Balloons and Speech, a message the agent sends with `say` SHALL appear in a speech balloon above that session's buddy. A newer message of the same session SHALL replace the one shown.

#### Scenario: Agent says something
- **WHEN** the agent of the session "api" says "Tests are green" and its buddy is on screen
- **THEN** a balloon with "Tests are green" appears above the "api" buddy

#### Scenario: Newer message replaces the older one
- **WHEN** a balloon shows "Building…" and the same session says "Build done"
- **THEN** the balloon shows "Build done" instead

### Requirement: How long a message stays
A message balloon SHALL close by itself after a reading time that grows with its length: at least 4 and at most 12 seconds. It SHALL stay open while the pointer is on it. Clicking it, or its close button, SHALL close it at once.

#### Scenario: Short message
- **WHEN** a buddy shows a one-word message and the pointer stays away
- **THEN** the balloon closes after about 4 seconds

#### Scenario: Reading a long message
- **WHEN** the user rests the pointer on a message balloon
- **THEN** it stays open until the pointer leaves, and closes after the rest of its time

#### Scenario: Click to close
- **WHEN** the user clicks a message balloon
- **THEN** it closes at once and the click does not go to the session's app

### Requirement: One balloon per buddy
A buddy SHALL show at most one balloon. A pending question or permission prompt SHALL take the place of a message. A message that arrives while a request is shown SHALL NOT hide that request.

#### Scenario: Question over a message
- **WHEN** a buddy shows a message and its session asks a question
- **THEN** the balloon shows the question

#### Scenario: Message while a question is open
- **WHEN** a buddy shows a question and the session says something
- **THEN** the question stays in the balloon

### Requirement: Balloon placement
A balloon SHALL sit above its buddy's head with a tail pointing at the buddy, and SHALL stay fully on that buddy's display. Its header SHALL show the session name, and the buddy's name label SHALL hide while the balloon is open. It SHALL follow its buddy and fit in the strip at every buddy size. Text that does not fit SHALL be cut with "…".

#### Scenario: Buddy near the edge of the screen
- **WHEN** a buddy in the leftmost slot shows a wide balloon
- **THEN** the balloon stays fully on the display and its tail still points at the buddy

#### Scenario: Name in the balloon
- **WHEN** the "api" buddy shows a balloon
- **THEN** the balloon's header says "api" and the name label above its head is hidden until the balloon closes

#### Scenario: Largest buddies
- **WHEN** the buddy size is "Extra large" and a buddy shows a long question
- **THEN** the balloon, its buttons and its text field are fully visible on the strip, with the end of the text cut with "…" if needed

### Requirement: Balloons while carried
A buddy that is picked up SHALL hide its balloon. The balloon SHALL come back, with the same content, once the buddy stands again, unless its content ended meanwhile.

#### Scenario: Carrying a buddy with a question
- **WHEN** the user picks up a buddy that shows a question and drops it elsewhere
- **THEN** the balloon hides while the buddy is carried and shows the question again once it has landed

### Requirement: Interactive without stealing focus
A balloon SHALL be an interactive region of the overlay; everything around it SHALL stay click-through. Clicking a balloon or its buttons SHALL NOT take keyboard focus from the user's frontmost app. Only clicking a balloon's text field SHALL take keyboard focus.

#### Scenario: Pick a choice while typing elsewhere
- **WHEN** the user types in a terminal, clicks a choice button in a balloon, and keeps typing
- **THEN** the answer is sent and the keystrokes still go to the terminal

#### Scenario: Click next to a balloon
- **WHEN** the user clicks just beside a balloon
- **THEN** the click reaches the window below the overlay

### Requirement: Answer a question
A question's balloon SHALL show the question and one button per choice. Clicking a choice SHALL send it to the agent that asked, and the balloon SHALL close.

#### Scenario: Pick a choice
- **WHEN** the agent asks "Deploy to staging now?" with the choices "yes" and "no", and the user clicks "no"
- **THEN** the agent receives "no" and the balloon closes

### Requirement: Free-text answer
When a question allows free text, its balloon SHALL show a text field. Clicking the field SHALL take keyboard focus. Enter SHALL send the text as the answer. Escape SHALL release the focus without answering. After either, focus SHALL return to the previously frontmost app.

#### Scenario: Type an answer
- **WHEN** the user clicks the text field of a question, types "use the blue one" and presses Enter
- **THEN** the agent receives "use the blue one", the balloon closes, and the previously frontmost app has keyboard focus again

#### Scenario: Change of mind
- **WHEN** the user clicks the text field and presses Escape
- **THEN** the question stays open and the previously frontmost app has keyboard focus again

### Requirement: Permission prompt in the balloon
A permission prompt's balloon SHALL describe the action, for example "Bash: rm -rf build", with "Allow" and "Deny" buttons and a bar showing the time left before Claude Code shows its own prompt. The choice SHALL be sent to the agent.

#### Scenario: Allow
- **WHEN** Claude asks permission to run a command and the user clicks "Allow" in the balloon
- **THEN** Claude runs the command without showing its own permission prompt

#### Scenario: Time runs out
- **WHEN** the user does not decide before the bar runs out
- **THEN** the balloon closes and Claude Code shows its own permission prompt

### Requirement: Close a request
A request's balloon SHALL have a close button. Closing a question SHALL dismiss it, so the agent is told to ask in the conversation. Closing a permission prompt SHALL leave the decision to the agent's own prompt.

#### Scenario: Dismiss a question
- **WHEN** the user clicks the close button of a question
- **THEN** the balloon closes and the agent is told the user dismissed the question

#### Scenario: Leave a permission to Claude Code
- **WHEN** the user clicks the close button of a permission prompt
- **THEN** the balloon closes and Claude Code shows its own permission prompt at once

### Requirement: Several requests of one session
When a session has more than one pending request, its balloon SHALL show the oldest one with the number waiting, for example "1 of 2". After it is answered, closed or withdrawn, the next one SHALL appear.

#### Scenario: Two questions
- **WHEN** a session asks two questions in a row
- **THEN** the balloon shows the first one with "1 of 2", and after the user answers it, the second one

### Requirement: Withdrawn requests
When the agent stops waiting for a request (time-out, cancel or disconnect), its balloon SHALL close, or move on to the next request of that session.

#### Scenario: Question times out
- **WHEN** a question's time-out passes without an answer
- **THEN** its balloon closes

### Requirement: Spoken output
When the output is Speech or Balloons and Speech, every message, question, permission prompt and notice SHALL be spoken with a macOS system voice for the user's language, starting with the session name. With Speech alone, messages and notices SHALL be spoken only. Questions and permission prompts SHALL be spoken and also shown in a balloon, so they can be answered.

#### Scenario: Speech only
- **WHEN** the output is Speech and the "api" agent says "Tests are green"
- **THEN** a voice says "api: Tests are green" and no balloon appears

#### Scenario: Question with speech only
- **WHEN** the output is Speech and the "api" agent asks a question
- **THEN** the question is spoken and its balloon appears with the answer buttons

#### Scenario: No voice available
- **WHEN** macOS offers no voice
- **THEN** the speech options are disabled in the menu and balloons keep working

### Requirement: Turn finished notice
When "Turn finished" is on, a session whose turn ends after at least 20 seconds since the user's prompt SHALL show the notice "Done" (spoken: "<name> is done"). Shorter turns SHALL NOT be announced.

#### Scenario: Long task finished
- **WHEN** a turn of the "api" session ends 3 minutes after the prompt
- **THEN** the "api" buddy shows "Done"

#### Scenario: Quick reply
- **WHEN** a turn ends 5 seconds after the prompt
- **THEN** no notice appears

#### Scenario: Turned off
- **WHEN** "Turn finished" is unchecked and a long turn ends
- **THEN** no notice appears and the buddy still does its happy jump

### Requirement: Error notice
When "Errors" is on, a session whose turn fails SHALL show the notice "Something went wrong" with the first line of the error, for about 8 seconds. A failing tool within a turn SHALL NOT be announced.

#### Scenario: Turn fails
- **WHEN** the "api" session's turn fails with "API overloaded"
- **THEN** the "api" buddy shows "Something went wrong: API overloaded"

#### Scenario: Tool fails
- **WHEN** a tool fails but the turn goes on
- **THEN** no notice appears

### Requirement: Output off
When the output is Off, the app SHALL NOT show or speak messages or notices. Every pending and new question and permission prompt SHALL be handed back at once: questions as dismissed, and permission prompts left to the agent's own prompt. Buddies SHALL keep showing their session's state.

#### Scenario: Question while off
- **WHEN** the output is Off and the agent calls `ask_user`
- **THEN** the tool returns at once that the user should be asked in the conversation, and no balloon appears

#### Scenario: Permission while off
- **WHEN** the output is Off and Claude asks permission to run a command
- **THEN** Claude Code shows its own permission prompt without waiting for the app

#### Scenario: Turning output off with a question open
- **WHEN** a balloon shows a question and the user chooses Off
- **THEN** the balloon closes, the question is dismissed and any speech stops

### Requirement: Hidden buddies
While the buddies are hidden from the menu bar, the app SHALL behave as with output Off: nothing is shown or spoken, and questions and permission prompts are handed back at once.

#### Scenario: Permission while hidden
- **WHEN** the buddies are hidden and Claude asks permission to run a command
- **THEN** Claude Code shows its own permission prompt without waiting for the app

### Requirement: Sessions without a buddy on screen
A message or notice for a session whose buddy is not on screen SHALL NOT be shown later. It SHALL still be spoken when speech is on. A question or permission prompt SHALL wait for that session's buddy to come in, which happens because a waiting session comes first.

#### Scenario: Message from a session that was sent home
- **WHEN** a session that was sent home says something and speech is off
- **THEN** no balloon appears and its buddy does not come back for it

#### Scenario: Question from a session without a buddy
- **WHEN** a session without a buddy on screen asks a question
- **THEN** its buddy walks in and shows the question in its balloon

### Requirement: Questions asked in the agent's own window
When the agent asks the user in its own window (Claude Code's question tool, a plan to approve, or the Claude app's next-step question), the buddy SHALL show the question and its options in a balloon to read, with a hint to answer in the session. Clicking the balloon SHALL bring the user to the session. The balloon SHALL close once the session goes on, and SHALL stay while a "Done" notice arrives.

#### Scenario: Next-step question in the Claude app
- **WHEN** a session in the Claude app ends its turn with the question "Shall I commit this and open a PR?" and the buttons "Commit and PR" and "Try it first"
- **THEN** its buddy shows that question with "Commit and PR · Try it first" and "Answer in the session", and no "Done" notice replaces it

#### Scenario: Answer in the session
- **WHEN** the user clicks such a balloon
- **THEN** the app that runs the session comes to the front, like a click on the buddy

#### Scenario: Question answered in the terminal
- **WHEN** Claude Code asks with its question tool and the user answers in the terminal
- **THEN** the buddy's question balloon closes

#### Scenario: Next prompt
- **WHEN** the user sends the next prompt to a session whose buddy shows a next-step question
- **THEN** the balloon closes
