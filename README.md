# ai-tts

Read terminal text aloud with native macOS voices, and have **Claude Code speak
when it needs your attention** — with no daemon, no named pipe, and no
background process.

The trick: macOS's `say` command already reads stdin and talks straight to the
native audio layer. It *is* the audio engine. So the whole thing is a one-line
shell function plus a Claude Code hook — config, not a program.

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

Pick a specific voice (default is the always-installed `Samantha`):

```bash
VOICE="Ava (Enhanced)" bash install.sh
```

The installer is **idempotent** (safe to re-run), **non-destructive** (merges
into your shell rc and `settings.json` without clobbering — it backs up
`settings.json` and refuses to touch malformed JSON), and falls back to
`Samantha` if the requested voice isn't installed.

It sets up two things:

1. **A `speak` shell function** in your `~/.zshrc` (or `~/.bashrc`). Speaks its
   arguments, or reads stdin if given none. Run `source ~/.zshrc` or open a new
   terminal to pick it up.
2. **A Claude Code `Notification` hook** in `settings.json`, so Claude speaks its
   notification message whenever it's waiting on you.

## Using `speak`

`say` reads stdin natively, so `speak` slots into any pipeline:

```bash
speak "hello"                          # speak an argument
echo "hello" | speak                   # …or stdin
cat CHANGELOG.md | speak               # read a file aloud
tail -f /var/log/system.log | speak    # narrate a live log stream
make test && speak "tests passed" || speak "tests failed"
```

Change the voice anytime by editing `TTS_VOICE` in your rc file. List voices with
`say -v '?'`; download premium ones in **System Settings → Accessibility →
Spoken Content → Manage Voices**.

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
the **notification hook** is per-config-dir. Hooks take effect on the next Claude
Code session in that dir.

### Why only `Notification`, not `Stop`?

The `Stop` hook fires after *every* response, so wiring `say "Task complete"` to
it means your Mac talks after every single turn — maddening fast. `Notification`
(Claude waiting on you / asking permission) is the one worth hearing. If you do
want an audible end-of-turn for long unattended runs, add a `Stop` entry
yourself.

## What the hook looks like

The installer merges this into `settings.json`:

```jsonc
{
  "hooks": {
    "Notification": [
      { "hooks": [{ "type": "command",
        "command": "jq -r '.message // \"Claude needs your input\"' | say -v \"Samantha\"  # ai-tts-notify" }] }
    ]
  }
}
```

`jq` pulls the real message off the event payload, so you hear *why* Claude needs
you, not a canned phrase.

## Uninstall

- **`speak`**: delete the `# >>> ai-tts >>>` … `# <<< ai-tts <<<` block from your
  rc file.
- **Hook**: remove the entry marked `# ai-tts-notify` from each
  `settings.json`, or restore the `settings.json.bak` the installer left behind.

## Why not a daemon / named pipe?

An earlier design used a background daemon listening on a FIFO. It's unnecessary:
`say` already provides the "pipe text in, hear it out" behaviour via stdin, with
nothing to start, crash, or autostart. The only thing a daemon adds is
cross-process serialization (two *separate* commands speaking at the exact same
instant won't queue) — a rare enough case for one person at one terminal that
it's not worth the machinery. Add it the day it actually bites you, not before.
