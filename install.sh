#!/usr/bin/env bash
#
# ai-tts — read terminal text aloud with native macOS voices, and have
# Claude Code speak when it needs your attention.
#
# What it does (idempotent — safe to re-run):
#   1. Adds a `speak` shell function + TTS_VOICE to your shell rc file.
#   2. Adds a Notification hook to ~/.claude/settings.json so Claude Code
#      speaks the message whenever it's waiting on you. Existing settings
#      and hooks are preserved (merged with jq, never clobbered).
#
# Usage:    bash install.sh
# Voice:    VOICE="Ava (Enhanced)" bash install.sh   # override the voice
#
# No daemon, no named pipe, no background process: macOS `say` already
# reads stdin and talks straight to the native audio layer.

set -euo pipefail

# --- config ----------------------------------------------------------------
VOICE="${VOICE:-Samantha}"                      # override with: VOICE="..." bash install.sh
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
MARKER="ai-tts-notify"                           # used to detect a prior install

# --- preflight -------------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { echo "✗ This tool is macOS-only (uses the \`say\` command)." >&2; exit 1; }
command -v say >/dev/null || { echo "✗ \`say\` not found — is this macOS?" >&2; exit 1; }
command -v jq  >/dev/null || { echo "✗ \`jq\` is required. Install it: brew install jq" >&2; exit 1; }

# Make sure the chosen voice exists; otherwise fall back to Samantha.
if ! say -v '?' | grep -q "^${VOICE}[[:space:]]"; then
  echo "⚠ Voice \"$VOICE\" not installed — falling back to Samantha."
  echo "  Higher-quality voices available on this Mac:"
  say -v '?' | grep -Ei '\(Premium\)|\(Enhanced\)' | sed 's/^/    /' || echo "    (none — download some in System Settings → Accessibility → Spoken Content → Manage Voices)"
  VOICE="Samantha"
fi

# --- 1. shell function -----------------------------------------------------
case "${SHELL:-}" in
  *zsh) RC="$HOME/.zshrc" ;;
  *)    RC="$HOME/.bashrc" ;;
esac
touch "$RC"

if grep -q ">>> ai-tts >>>" "$RC"; then
  echo "✓ \`speak\` already present in $RC (skipping)."
else
  cat >> "$RC" <<EOF

# >>> ai-tts >>>
# Read terminal text aloud with a native macOS voice.
# Change TTS_VOICE to any name from \`say -v '?'\` (e.g. a downloaded premium voice).
export TTS_VOICE="$VOICE"
# speak: speaks its arguments, or reads stdin if given none.
#   speak "hello"      cat notes.txt | speak      npm run build && speak "done"
speak() { say -v "\$TTS_VOICE" "\$@"; }
# <<< ai-tts <<<
EOF
  echo "✓ Added \`speak\` to $RC"
fi

# --- 2. Claude Code notification hook --------------------------------------
mkdir -p "$CLAUDE_DIR"
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
  CMD="jq -r '.message // \"Claude needs your input\"' | say -v \"$VOICE\"  # $MARKER"
  tmp="$(mktemp)"
  jq --arg cmd "$CMD" \
    '.hooks.Notification = ((.hooks.Notification // []) + [{hooks: [{type: "command", command: $cmd}]}])' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Added Notification hook to $SETTINGS (backup: $SETTINGS.bak)"
fi

# --- done ------------------------------------------------------------------
cat <<EOF

Done. Two things are now set up:

  • speak  — run \`source $RC\` (or open a new terminal), then:
                 speak "hello"
                 cat file.txt | speak
                 npm run build && speak "build done"

  • Claude Code will speak its notification message whenever it needs you.
    (Takes effect on the next Claude Code session.)

Voice in use: $VOICE
Tip: download a premium voice in System Settings → Accessibility →
     Spoken Content → Manage Voices, then set TTS_VOICE / re-run with VOICE=.

Note: \`Stop\` (end-of-turn) is intentionally NOT hooked — it fires after
every single response and gets maddening fast. Notification is the useful one.
EOF
