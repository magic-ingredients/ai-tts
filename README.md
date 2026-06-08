# ai-tts

Read terminal text aloud with native macOS voices, and have **Claude Code tell
you what it's waiting on** — out loud, across multiple sessions, with no daemon,
no named pipe, and no background process.

When a session needs you, it speaks the **pending question and its options**
(not a generic "waiting for input"), prefixed with a **session label** so you
know *which* of several running sessions is asking.

Voice is **off by default** and **per session**, with three modes you (or
Claude) switch between with `/voice` and `/chat`:

- **`off`** — silent.
- **`read`** — the hook *reads the pending question aloud* (the passive mode
  above) — good for an unattended run you're not actively watching.
- **`chat`** — a spoken **conversation**: Claude speaks each turn itself via
  `say`, asks **one question at a time**, and you answer by voice. The hook drops
  back to just a "needs you" wake-ping plus permission prompts.

The trick: macOS's `say` command already reads stdin and talks straight to the
native audio layer. It *is* the audio engine. So this is just a one-line shell
function plus a small notification helper the installer drops into your Claude
config dir.

```bash
speak "build finished"
cat notes.txt | speak
npm run build && speak "done"
```

## Install

Requires macOS and [`jq`](https://stedolan.github.io/jq/) (`brew install jq`).

```bash
bash install.sh
```

The installer is **idempotent** (safe to re-run) and **non-destructive**: it
merges into your shell rc and `settings.json` without clobbering — backing up
`settings.json` and refusing to touch malformed JSON.

Both `speak` and the notification hook call `say` with **no voice flag**, so
they follow your macOS **System Voice** — see [Choosing the voice](#choosing-the-voice)
below to set it (including Siri).

It sets up these things:

1. **A `speak` shell function** in your `~/.zshrc` (or `~/.bashrc`). Speaks its
   arguments, or reads stdin if given none. Run `source ~/.zshrc` or open a new
   terminal to pick it up.
2. **A notification helper**, `ai-tts-notify.sh`, in your Claude config dir. It
   reads the hook payload, finds the pending question in the session transcript,
   and speaks it with a session label — but only when the session's voice mode
   is on. (Re-running the installer refreshes it.)
3. **A voice-mode toggle**, `ai-tts-voice.sh`, plus a **`/voice` slash command**,
   to set a session's mode (`off` / `read` / `chat`).
4. **A `/chat` skill** that flips a session into conversational mode and tells
   Claude how to behave there (speak each turn via `say`, one question at a time,
   and also show the question in full on screen).
5. **A Claude Code `Notification` hook** in `settings.json` that runs the helper
   whenever a session is waiting on you.

## Using `speak`

`say` reads stdin natively, so `speak` slots into any pipeline:

```bash
speak "hello"                          # speak an argument
echo "hello" | speak                   # …or stdin
cat CHANGELOG.md | speak               # read a file aloud
tail -f /var/log/system.log | speak    # narrate a live log stream
make test && speak "tests passed" || speak "tests failed"
```

## Voice modes (off / read / chat)

Voice is **off by default**, **per session**. Set a mode with the `/voice`
command, or jump straight into a conversation with the `/chat` skill:

```text
/voice read      # the hook reads the pending question aloud (passive)
/voice off       # silent
/voice status    # show the current mode
/voice chat      # same as the /chat skill, without the behaviour prompt

/chat            # start a spoken conversation (sets chat mode + tells Claude
                 #   how to behave: speak each turn, one question at a time)
```

Both are wired so **Claude can drive them too** — it switches voice on for a
chat and off again for heads-down work, by running `ai-tts-voice.sh` (its shell
has `CLAUDE_CODE_SESSION_ID`).

**What each mode does when a session is waiting:**

| Mode   | The hook speaks                          | Claude speaks (via `say`)            |
| ------ | ---------------------------------------- | ------------------------------------ |
| `off`  | nothing                                  | nothing                              |
| `read` | the pending question + permission prompts | —                                    |
| `chat` | a "needs you" wake-ping + permission     | the question itself, one at a time   |

In **chat** mode Claude also shows the question **in full on screen**, so you can
read it as well as hear it — and you answer by voice (handy for filling in a form
or questionnaire hands-free).

**Under the hood:** `ai-tts-voice.sh` writes a per-session flag file (keyed by
`CLAUDE_CODE_SESSION_ID`) whose contents are the mode; the notification helper
reads it before deciding what to speak. Because state is per session and keyed by
session id:

- **Default off** is automatic — a fresh session has no flag, so it's silent
  until something sets a mode. Nothing to reset between sessions.
- **No cross-talk** — setting a mode in one session never affects another.

Stale flags from ended sessions are swept automatically (older than a day).

## What the hook speaks in `read` mode

In `read` mode, when a session triggers a `Notification`, the helper speaks one
of (in `chat` mode it instead wake-pings; in `off` mode, nothing):

- **A permission prompt** → the message verbatim, e.g.
  *"ai-tts: Claude needs your permission to use Bash."*
- **A waiting-for-input prompt** → the **pending ask**, read from the session
  transcript:
  - an `AskUserQuestion` → the question plus each option label
    (*"ai-tts: Deploy now or wait? Options: Deploy, Wait for CI."*), or
  - a plain-text question → the **closing question** of Claude's reply (the
    trailing sentence ending in `?`, not the lead-in explanation), capped so it
    stays a cue rather than an essay.

Every line is prefixed with a **session label** so you can tell which session is
talking when several are open:

- **Default:** the project **folder name** (the session's working dir). This
  already distinguishes sessions running in different repos.
- **Two sessions in the same repo?** Give one an explicit label by exporting
  `CLAUDE_SESSION_NAME` before launching it:

  ```bash
  CLAUDE_SESSION_NAME="backend" claude
  ```

  Hook subprocesses inherit Claude Code's environment, so the helper picks it up.

> **What this can't do:** speak-then-*reply-by-voice* to a specific background
> session. A hook is one-way (payload in → audio out); it has no channel to
> inject your answer back into a non-focused session. Claude Code's built-in
> voice input only feeds the session you're currently focused on. Routing a
> spoken reply to an arbitrary background session would need a terminal-level
> hack (e.g. `tmux send-keys`) and lives outside this repo.

## Choosing the voice

`speak` and the notification hook deliberately run `say` with **no voice flag**,
so both speak in whatever you've set as the macOS **System Voice**. Set it once,
in the GUI, and everything follows:

1. **Set up the Siri voice you want** — System Settings → **Siri** (choose the
   Siri voice/accent).
2. **Point the system at it** — System Settings → **Accessibility** → **Read &
   Speak** → **System Voice** → set to **Siri (Voice 1–4)**.

This is the only way to get the **Siri** voice: `say -v "<name>"` can't, because
the Siri neural engine isn't in the `say` voice catalogue (`say -v '?'` never
lists it). Only unflagged `say` — using the system default — reaches it.

Prefer a classic voice instead? Set the System Voice to any installed voice
(`say -v '?'` lists them; download more under Accessibility → Read & Speak →
Manage Voices). To hard-code one specific voice regardless of the system
setting, edit the `speak()` line in your rc file to `say -v "VoiceName" "$@"`.

## Claude Code notifications & multiple config dirs

Claude Code reads its hooks from `settings.json` inside its **config directory**,
which defaults to `~/.claude`. If you run Claude under a different
`CLAUDE_CONFIG_DIR` — for example a dev alias — its hooks live in *that* dir, and
you need to install into each one you use.

Check which dirs you use:

```bash
alias | grep -i claude          # look for CLAUDE_CONFIG_DIR in your aliases
```

For example, a `claude-dev` alias like:

```bash
alias claude-dev='… CLAUDE_CONFIG_DIR=~/.claude-dev claude …'
```

…reads from `~/.claude-dev`, not `~/.claude`. To cover both your normal and dev
sessions, run the installer once per config dir:

```bash
bash install.sh                                   # default `claude`  → ~/.claude
CLAUDE_CONFIG_DIR=~/.claude-dev bash install.sh   # `claude-dev`      → ~/.claude-dev
```

The `speak` function is shell-level and works in every session regardless — only
the **notification hook and its helper** are per-config-dir. Hooks take effect on
the next Claude Code session in that dir.

### Why only `Notification`, not `Stop`?

The `Stop` hook fires after *every* response, so wiring `say "Task complete"` to
it means your Mac talks after every single turn — maddening fast. `Notification`
(Claude waiting on you / asking permission) is the one worth hearing. If you do
want an audible end-of-turn for long unattended runs, add a `Stop` entry
yourself.

## What the hook looks like

The installer merges this into `settings.json` (the path points at the helper it
wrote into the same config dir):

```jsonc
{
  "hooks": {
    "Notification": [
      { "hooks": [{ "type": "command",
        "command": "bash /Users/you/.claude/ai-tts-notify.sh  # ai-tts-notify" }] }
    ]
  }
}
```

The helper reads the event payload on stdin, resolves the session label and the
pending question, and pipes the result to `say`. It's a few dozen lines of
`bash` + `jq` — readable in `ai-tts-notify.sh`.

## Uninstall

- **`speak`**: delete the `# >>> ai-tts >>>` … `# <<< ai-tts <<<` block from your
  rc file.
- **Hook**: remove the entry marked `# ai-tts-notify` from each
  `settings.json`, or restore the `settings.json.bak` the installer left behind.
- **Helpers, command & skill**: delete `ai-tts-notify.sh`, `ai-tts-voice.sh`,
  `commands/voice.md`, `skills/chat/`, and the `ai-tts-state/` dir from each
  Claude config dir.

## Why not a daemon / named pipe?

An earlier design used a background daemon listening on a FIFO. It's unnecessary:
`say` already provides the "pipe text in, hear it out" behaviour via stdin, with
nothing to start, crash, or autostart. The only thing a daemon adds is
cross-process serialization (two *separate* commands speaking at the exact same
instant won't queue) — a rare enough case for one person at one terminal that
it's not worth the machinery. Add it the day it actually bites you, not before.
