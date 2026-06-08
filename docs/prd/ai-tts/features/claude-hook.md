---
id: claude-hook
uuid: 019ea782-7e16-73dc-89e0-ce1829176459
prd_id: ai-tts
number: 5
title: Claude Code hook handler
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# Claude Code hook handler

## Overview

`ai-tts hook` is invoked by Claude Code's hook system. It reads the event JSON on
stdin, decides whether to speak based on config (which events are enabled, fixed
vs context-aware phrasing), and pushes the resulting line to the channel.

## Rationale

The naive design told Claude, via CLAUDE.md, to `echo … > pipe` before pausing —
and even admitted the model forgets. A hook is the correct mechanism: the harness
runs it deterministically on the configured events, every time, independent of
the model's reasoning. Reading the event payload also lets us speak a
context-aware line ("Claude needs your input: <message>") when configured.

## Acceptance Criteria

- `ai-tts hook` parses the Claude Code hook JSON from stdin, extracting at least
  the event type and (for Notification) the message.
- It speaks only for events present in `hooks.events`; disabled events are a
  silent no-op (exit 0).
- `hooks.style = fixed` uses a canned phrase per event; `style = context` derives
  a short line from the payload (e.g. the notification message).
- Unparseable/empty stdin exits 0 without crashing (never breaks the host
  session).
- Event routing, phrase selection, and payload extraction are unit-tested against
  captured hook-event JSON fixtures using a `FakeSpeaker`.

## Tasks

### 1. Add hook event parsing and routing
id: 019ea782-7e16-7282-b1f3-b0636a940566
Parse the hook event JSON, map event type to enabled/disabled per config, and
extract the message for context style. Unit-test routing and extraction against
fixtures for Notification, Stop, and SubagentStop.

**Files to create:**
- `src/hook.rs`
- `tests/fixtures/hook_notification.json`
- `tests/fixtures/hook_stop.json`

### 2. Add hook command emitting speech to the channel
id: 019ea782-7e16-7863-8a34-21dbbd078476
Wire `ai-tts hook`: build the phrase (fixed or context) and push to the channel,
defaulting to a safe no-op on bad input so the host session is never broken.

**Files to create/modify:**
- `src/cmd/hook.rs`
- `src/main.rs`
