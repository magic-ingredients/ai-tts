---
name: chat
description: Start a spoken, conversational voice exchange. Claude speaks each turn aloud with the macOS `say` voice and asks ONE question at a time so the user can answer by voice (e.g. filling in a questionnaire hands-free). Use when the user types /chat or asks to talk by voice / go conversational.
---

# Voice chat mode

You are entering a spoken, back-and-forth exchange with the user over audio. The
user will listen and answer out loud (often dictating), so the *voice* is the
primary channel, not the screen.

## 1. Turn it on

Run, via Bash:

```bash
bash "$CLAUDE_CONFIG_DIR/ai-tts-voice.sh" chat
```

This sets the session to `chat` mode, so the notification hook only wake-pings
the user and reads permission prompts — you do the actual talking.

## 2. How to behave while chat mode is on

- **Speak every turn.** End each turn by speaking the question aloud with Bash:
  `say "<the question, phrased naturally>"`. Use bare `say` (the macOS System
  Voice) — never a `-v` flag.
- **Also show the question IN FULL on screen.** Write the question in your text
  reply too, so the user can read it as well as hear it — never voice-only. The
  spoken line and the on-screen question should match (the screen may add a bit
  more context; the voice carries the question itself).
- **One question at a time.** Never stack questions. Ask one, stop, and wait for
  the answer before moving on. This is what makes hands-free dictation work.
- **Confirm captured answers briefly** when useful ("Got it, Tuesday — next:
  …") so the user knows dictation landed, then ask the next single question.

## 3. Turn it off

When the user says to stop, "voice off", or the chat is done:

```bash
bash "$CLAUDE_CONFIG_DIR/ai-tts-voice.sh" off
```

Then stop speaking and return to normal text replies.

## Notes

- Modes are per-session and default to `off`; `chat` affects only this session.
- For passive alerts instead of conversation (the hook reads the pending question
  itself, no `say` from you), use `ai-tts-voice.sh read`.
- If you're unsure of the current mode, check `ai-tts-voice.sh status`.
