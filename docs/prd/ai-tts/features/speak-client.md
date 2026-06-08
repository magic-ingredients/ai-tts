---
id: speak-client
uuid: 019ea782-1585-7478-ba41-9ee7c3cab7b2
prd_id: ai-tts
number: 3
title: speak client CLI
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# `speak` client CLI

## Overview

The everyday entry point. `ai-tts speak` takes text from arguments and/or stdin
and writes it to the channel for the daemon to speak. Designed for pipes:
`cat log.txt | ai-tts speak`, `npm run build && ai-tts speak "build done"`.

## Rationale

Writers should not need to know the FIFO path or worry about the daemon being
down. The client centralises "get text in, push to channel," handles streaming
stdin line-by-line (so `tail -f | ai-tts speak` works live), and fails helpfully
when no daemon is listening.

## Acceptance Criteria

- `ai-tts speak "hello"` sends `hello` to the channel.
- `echo hi | ai-tts speak` reads stdin; streamed stdin is forwarded line-by-line
  as it arrives (works with `tail -f`).
- Both args and stdin combine predictably; empty/whitespace-only lines are
  skipped.
- If no daemon is listening, the command exits with a clear, non-zero error
  rather than hanging or silently succeeding.
- Input collection and line-skipping logic are unit-tested against in-memory
  readers/writers (no real FIFO).

## Tasks

### 1. Add input collection from args and stdin
id: 019ea782-1585-7f3f-82a5-ac6c61f0b9c8
Implement reading text from arguments and streaming stdin, line-by-line, skipping
blank lines. Unit-test the collection/filtering against in-memory input.

**Files to create:**
- `src/input.rs`

### 2. Add speak command writing to the channel
id: 019ea782-1585-7700-a098-6f826a44e167
Wire `ai-tts speak`: resolve the channel, stream collected lines to it, and
surface a clear error when no daemon is listening.

**Files to create/modify:**
- `src/cmd/speak.rs`
- `src/main.rs`
