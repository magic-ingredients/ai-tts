#!/usr/bin/env bash
#
# ai-tts notification speaker.  # ai-tts-notify
#
# Reads a Claude Code Notification hook payload on stdin and speaks — using the
# macOS System Voice — *what the session actually wants*: the pending question
# and its options, not a generic "waiting for input". The spoken line is
# prefixed with a session label so you can tell which of several sessions is
# talking.
#
#   Label : $CLAUDE_SESSION_NAME if set, else the working-dir basename.
#   Voice : none specified, so `say` follows your macOS System Voice
#           (set it to Siri under Accessibility -> Read & Speak -> System Voice).
#
# It never errors out loud: on any problem it falls back to the generic payload
# message so you still hear *something*.

set -uo pipefail

payload="$(cat)"

# Without jq we can't parse the payload — say a generic line and bail.
if ! command -v jq >/dev/null 2>&1; then
  say "Claude needs your input"
  exit 0
fi

label="$(printf '%s' "$payload" | jq -r 'env.CLAUDE_SESSION_NAME // (.cwd // "session" | split("/") | last)')"
transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // ""')"
message="$(printf '%s' "$payload" | jq -r '.message // "Claude needs your input"')"

# Permission prompts: the payload message ("…needs your permission to use X")
# is already the useful thing — speak it verbatim.
if printf '%s' "$message" | grep -qi 'permission'; then
  say "$label: $message"
  exit 0
fi

# Otherwise we're idle/waiting: dig the pending ask out of the transcript.
spoken=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  spoken="$(jq -rs '
    # content of the LAST assistant message — that is what we are blocked on
    ( [ .[] | select(.type=="assistant") | .message.content // [] ] | last // [] ) as $last
    # an AskUserQuestion in that message, if present
    | ( [ $last[] | select(.type=="tool_use" and .name=="AskUserQuestion") ] | first ) as $ask
    | if $ask then
        ( [ $ask.input.questions[]
            | .question + " Options: " + ( [ .options[].label ] | join(", ") ) ]
          | join(" — ") )
      else
        # otherwise the last text block of that message (the closing question)
        ( [ $last[] | select(.type=="text") | .text ] | last // "" )
      end
  ' "$transcript" 2>/dev/null)"
fi

# Collapse whitespace; fall back to the generic message if we found nothing.
spoken="$(printf '%s' "$spoken" | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//')"
[ -n "$spoken" ] || spoken="$message"

# Cap length so a long answer stays a spoken cue, not an essay.
max=320
if [ "${#spoken}" -gt "$max" ]; then
  spoken="${spoken:0:$max}…"
fi

say "$label: $spoken"
