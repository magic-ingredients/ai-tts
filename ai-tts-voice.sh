#!/usr/bin/env bash
#
# ai-tts voice mode for THIS Claude Code session.  # ai-tts-voice
#
# State is per-session — keyed by $CLAUDE_CODE_SESSION_ID — and defaults to OFF:
# a fresh session is silent until something sets a mode. "off" is just the
# absence of the flag file; there is nothing to reset between sessions, and one
# session's mode never affects another.
#
# Modes:
#   off    no spoken notifications.
#   read   the notification hook reads the pending question aloud — the passive
#          behaviour, good for unattended runs you're not actively chatting with.
#   chat   conversational: Claude speaks each turn itself via `say`, one question
#          at a time, and you answer by voice. The hook then only wake-pings you
#          and reads permission prompts (which Claude can't speak while blocked).
#
# Claude itself can run this (its shell has CLAUDE_CODE_SESSION_ID) to switch
# voice on for a chat and off again for heads-down work.
#
#   ai-tts-voice.sh off | read | chat | status      (alias: on == chat)
#
# With no argument it prints the current mode.

set -uo pipefail

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ai-tts-state"
sid="${CLAUDE_CODE_SESSION_ID:-default}"
state="$dir/$sid"
mkdir -p "$dir"

# Opportunistically sweep flags left by sessions that ended long ago (>1 day).
find "$dir" -type f -mtime +1 -delete 2>/dev/null || true

case "${1:-status}" in
  off)      rm -f "$state";          echo "🔇 voice OFF  — this session is silent";;
  read)     printf 'read\n' > "$state"; echo "📖 voice READ — the hook reads the pending question aloud";;
  on|chat)  printf 'chat\n' > "$state"; echo "💬 voice CHAT — Claude speaks each turn (one question at a time); hook wake-pings + permission";;
  status)   if [ -f "$state" ]; then m="$(tr -d '[:space:]' < "$state")"; echo "${m:-read}"; else echo "off"; fi;;
  *)        echo "usage: ai-tts-voice.sh off|read|chat|status" >&2; exit 2;;
esac
