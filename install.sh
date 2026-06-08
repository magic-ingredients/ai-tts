#!/usr/bin/env bash
#
# ai-tts — read terminal text aloud with the macOS system voice, and have
# Claude Code speak when it needs your attention.
#
# What it does (idempotent — safe to re-run):
#   1. Adds a `speak` shell function to your shell rc file.
#   2. Adds a Notification hook to ~/.claude/settings.json so Claude Code
#      speaks the message whenever it's waiting on you. Existing settings
#      and hooks are preserved (merged with jq, never clobbered).
#
# Both call `say` with NO voice flag, so they follow whatever you've set as
# the macOS System Voice (System Settings → Accessibility → Read & Speak →
# System Voice). Set that to Siri (Voice 1–4) and you get the Siri voice —
# something `say -v` can't do, because the Siri engine isn't in the `say`
# voice catalogue; only the unflagged system default reaches it.
#
# Usage:    bash install.sh
#
# No daemon, no named pipe, no background process: macOS `say` already
# reads stdin and talks straight to the native audio layer.

set -euo pipefail

# --- config ----------------------------------------------------------------
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
MARKER="ai-tts-notify"                           # used to detect a prior install

# --- preflight -------------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { echo "✗ This tool is macOS-only (uses the \`say\` command)." >&2; exit 1; }
command -v say >/dev/null || { echo "✗ \`say\` not found — is this macOS?" >&2; exit 1; }
command -v jq  >/dev/null || { echo "✗ \`jq\` is required. Install it: brew install jq" >&2; exit 1; }

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
  CMD="jq -r '.message // \"Claude needs your input\"' | say  # $MARKER"
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

Both use the macOS System Voice — no voice flag. To pick the voice
(including Siri):

  1. Set up the Siri voice you want (System Settings → Siri).
  2. System Settings → Accessibility → Read & Speak → System Voice
     → set to Siri (Voice 1–4).

Whatever you choose there is what \`speak\` and the notification hook speak.

Note: \`Stop\` (end-of-turn) is intentionally NOT hooked — it fires after
every single response and gets maddening fast. Notification is the useful one.
EOF
