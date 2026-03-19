# Hook State Machine

How Claude Code tab state tracking works and why certain hooks are avoided.

## States

```mermaid
stateDiagram-v2
    [*] --> idle : SessionStart (startup|resume)

    idle --> running : UserPromptSubmit
    running --> asking : PreToolUse (AskUserQuestion|ExitPlanMode)
    running --> asking : PermissionRequest
    running --> running : PreToolUse (other tools)
    running --> running : SubagentStart
    asking --> running : PostToolUse (catch-all)
    running --> asking : Elicitation (MCP input)
    running --> idle : Stop
    running --> idle : StopFailure (API error)

    idle --> [*] : SessionEnd (clear)
```

| State | Color | Icon | Meaning |
|-------|-------|------|---------|
| `idle` | green | check | Waiting for user prompt |
| `running` | blue | sparkle | Executing tools / thinking |
| `asking` | peach | question | Needs user input |

## Data Flow

```mermaid
flowchart LR
    A["Claude Code<br/>hook event"] -->|spawns| B["claude-state.sh<br/>walks /proc for PTY"]
    B -->|"OSC 1337<br/>SetUserVar"| C["WezTerm<br/>pane.user_vars"]
    C -->|"format-tab-title"| D["claude.lua<br/>style_for_state()"]
    D -->|"{bg, fg, icon}"| E["theme.lua<br/>powerline renderer"]
```

Inside tmux, the OSC is wrapped in DCS passthrough (`\ePtmux;...\e\\`).

## Happy Path

```mermaid
sequenceDiagram
    participant U as User
    participant CC as Claude Code
    participant H as Hook Script
    participant W as WezTerm Tab

    CC->>H: SessionStart (startup)
    H->>W: idle (green)

    U->>CC: prompt
    CC->>H: UserPromptSubmit
    H->>W: running (blue)

    CC->>H: PreToolUse (Read)
    H->>W: running (blue)

    CC->>H: PreToolUse (AskUserQuestion)
    H->>W: asking (peach)

    U->>CC: answer
    CC->>H: PostToolUse (AskUserQuestion)
    H->>W: running (blue)

    CC->>H: PreToolUse (Bash)
    H->>W: running (blue)

    CC->>H: Stop
    H->>W: idle (green)

    CC->>H: SessionEnd
    H->>W: clear
```

## Avoided Hooks

Two hooks were removed after causing race conditions.

### SubagentStop Double-Fire

`SubagentStop` fires **twice** per subagent — the second completes after `Stop`, overwriting idle back to running.

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant H as Hook Script
    participant W as WezTerm Tab

    CC->>H: SubagentStart
    H->>W: running (blue)

    Note over CC: subagent works...

    CC->>H: Stop (inner, converted)
    H->>W: idle (green)
    CC->>H: SubagentStop #1
    H->>W: running (blue) !!

    CC->>H: Stop (outer)
    H->>W: idle (green)
    CC->>H: SubagentStop #2
    H->>W: running (blue) !!

    Note over W: stuck on running
```

Fix: removed `SubagentStop` entirely. `PreToolUse` and `SubagentStart` already cover all running transitions.

### Notification Async Race

`Notification` hooks are async backup signals that can arrive after `PostToolUse`/`Stop` have already moved the state forward.

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant H as Hook Script
    participant W as WezTerm Tab

    CC->>H: PreToolUse (AskUserQuestion)
    H->>W: asking (peach)

    Note over CC: user answers

    CC->>H: PostToolUse (AskUserQuestion)
    H->>W: running (blue)

    CC->>H: Stop
    H->>W: idle (green)

    CC-->>H: Notification (async, late)
    H->>W: asking (peach) !!

    Note over W: stuck on asking
```

Fix: removed all `Notification` hooks. `PermissionRequest` and `PreToolUse` already cover asking transitions synchronously.

## Quick Reference

| Event | Matcher | Emits |
|-------|---------|-------|
| SessionStart | `startup\|resume` | idle |
| UserPromptSubmit | -- | running |
| PreToolUse | `AskUserQuestion\|ExitPlanMode` | asking |
| PreToolUse | `^(?!AskUserQuestion$\|ExitPlanMode$)` | running |
| PostToolUse | -- | running |
| PermissionRequest | -- | asking |
| SubagentStart | -- | running |
| Elicitation | -- | asking |
| Stop | -- | idle |
| StopFailure | -- | idle |
| SessionEnd | -- | clear |
