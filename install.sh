#!/usr/bin/env bash
#
# ai-tts — read terminal text aloud with the macOS system voice, and have
# Claude Code speak what it needs when it's waiting on you.
#
# What it does (idempotent — safe to re-run):
#   1. Adds a `speak` shell function to your shell rc file.
#   2. Writes a notification helper (ai-tts-notify.sh) into your Claude config
#      dir and adds a Notification hook to settings.json that runs it. The
#      helper speaks the *pending question and its options* (read from the
#      session transcript), prefixed with a session label so you can tell which
#      of several sessions is talking. Existing settings and hooks are preserved
#      (merged with jq, never clobbered).
#
# Everything calls `say` with NO voice flag, so it follows whatever you've set
# as the macOS System Voice (System Settings -> Accessibility -> Read & Speak
# -> System Voice). Set that to Siri (Voice 1-4) for the Siri voice — something
# `say -v` can't do, because the Siri engine isn't in the `say` voice catalogue.
#
# Usage:    bash install.sh
#
# No daemon, no named pipe, no background process: macOS `say` already
# reads stdin and talks straight to the native audio layer.

set -euo pipefail

# --- config ----------------------------------------------------------------
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # repo dir (this script's dir)
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
HELPER_SRC="$SRC_DIR/ai-tts-notify.sh"           # shipped alongside this installer
HELPER="$CLAUDE_DIR/ai-tts-notify.sh"            # installed copy
VOICE_SRC="$SRC_DIR/ai-tts-voice.sh"             # voice-mode toggle, shipped too
VOICE="$CLAUDE_DIR/ai-tts-voice.sh"              # installed copy
VOICE_CMD="$CLAUDE_DIR/commands/voice.md"        # /voice slash command
SKILL_SRC="$SRC_DIR/skills/chat/SKILL.md"        # /chat conversational skill
SKILL_DST="$CLAUDE_DIR/skills/chat/SKILL.md"     # installed copy
MARKER="ai-tts-notify"                           # used to detect a prior install

# --- preflight -------------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { echo "✗ This tool is macOS-only (uses the \`say\` command)." >&2; exit 1; }
command -v say >/dev/null || { echo "✗ \`say\` not found — is this macOS?" >&2; exit 1; }
command -v jq  >/dev/null || { echo "✗ \`jq\` is required. Install it: brew install jq" >&2; exit 1; }
[ -f "$HELPER_SRC" ] || { echo "✗ Can't find ai-tts-notify.sh next to install.sh — run this from a clone of the repo." >&2; exit 1; }
[ -f "$VOICE_SRC" ]  || { echo "✗ Can't find ai-tts-voice.sh next to install.sh — run this from a clone of the repo." >&2; exit 1; }
[ -f "$SKILL_SRC" ]  || { echo "✗ Can't find skills/chat/SKILL.md next to install.sh — run this from a clone of the repo." >&2; exit 1; }

# --- 1. shell function -----------------------------------------------------
case "${SHELL:-}" in
  *zsh) RC="$HOME/.zshrc" ;;
  *)    RC="$HOME/.bashrc" ;;
esac
touch "$RC"

if grep -q ">>> ai-tts >>>" "$RC"; then
  echo "✓ \`speak\` already present in $RC (skipping)."
else
  cat >> "$RC" <<'EOF'

# >>> ai-tts >>>
# Read terminal text aloud using the macOS System Voice.
# No voice is specified on purpose: `say` then follows whatever you've set
# under System Settings → Accessibility → Read & Speak → System Voice
# (set it to Siri, Voice 1–4, for the Siri voice).
# speak: speaks its arguments, or reads stdin if given none.
#   speak "hello"      cat notes.txt | speak      npm run build && speak "done"
speak() { say "$@"; }
# <<< ai-tts <<<
EOF
  echo "✓ Added \`speak\` to $RC"
fi

# --- 2. notification helper ------------------------------------------------
mkdir -p "$CLAUDE_DIR"

# Copy the helpers in (overwrite, so re-running picks up improvements).
cp "$HELPER_SRC" "$HELPER"
chmod +x "$HELPER"
echo "✓ Installed notification helper to $HELPER"

cp "$VOICE_SRC" "$VOICE"
chmod +x "$VOICE"
echo "✓ Installed voice-mode toggle to $VOICE"

# Remove the old /chat command + helper from a prior version (now a skill + /voice).
rm -f "$CLAUDE_DIR/ai-tts-chat.sh" "$CLAUDE_DIR/commands/chat.md"

# /voice slash command: set this session's mode (off | read | chat | status).
mkdir -p "$CLAUDE_DIR/commands"
cat > "$VOICE_CMD" <<'EOF'
---
description: Set this session's ai-tts voice mode — off | read | chat | status
---
Run `bash "$CLAUDE_CONFIG_DIR/ai-tts-voice.sh" $ARGUMENTS` and report the new mode
in one short line. Modes: off (silent), read (the hook reads the pending question
aloud), chat (you speak each turn yourself via `say`, one question at a time).
With no argument it prints the current mode. Affects only this session; voice
defaults to off when a session starts.
EOF
echo "✓ Installed /voice command to $VOICE_CMD"

# /chat conversational skill: turns on chat mode + carries the speak-each-turn behaviour.
mkdir -p "$(dirname "$SKILL_DST")"
cp "$SKILL_SRC" "$SKILL_DST"
echo "✓ Installed /chat skill to $SKILL_DST"

# --- 3. Claude Code notification hook --------------------------------------
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Refuse to touch a malformed settings file rather than risk clobbering it.
if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "✗ $SETTINGS is not valid JSON — fix it first; leaving it untouched." >&2
  exit 1
fi

if grep -q "$MARKER" "$SETTINGS"; then
  echo "✓ Claude notification hook already installed (skipping)."
else
  cp "$SETTINGS" "$SETTINGS.bak"   # backup
  CMD="bash $HELPER  # $MARKER"
  tmp="$(mktemp)"
  jq --arg cmd "$CMD" \
    '.hooks.Notification = ((.hooks.Notification // []) + [{hooks: [{type: "command", command: $cmd}]}])' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Added Notification hook to $SETTINGS (backup: $SETTINGS.bak)"
fi

# --- done ------------------------------------------------------------------
cat <<EOF

Done. Set up:

  • speak  — run \`source $RC\` (or open a new terminal), then:
                 speak "hello"
                 cat file.txt | speak
                 npm run build && speak "build done"

  • Voice is OFF by default each session — set a mode per session (Claude can
    flip it too). Modes:
        /voice read      # the hook reads the pending question aloud (passive)
        /voice off       # silent
        /voice status    # show current mode
        /chat            # conversational: Claude speaks each turn via \`say\`,
                         #   one question at a time, and you answer by voice
    (Slash commands + the skill take effect on the next session in this dir.)

Everything uses the macOS System Voice — no voice flag. To pick the voice
(including Siri):

  1. Set up the Siri voice you want (System Settings → Siri).
  2. System Settings → Accessibility → Read & Speak → System Voice
     → set to Siri (Voice 1–4).

Telling sessions apart: the label is the project folder name by default. For
two sessions in the same repo, launch one with a custom label:

     CLAUDE_SESSION_NAME="backend" claude

Note: \`Stop\` (end-of-turn) is intentionally NOT hooked — it fires after
every single response and gets maddening fast. Notification is the useful one.
EOF
