---
id: audio-daemon
uuid: 019ea781-e66a-7f3f-827b-950f69a4bfaa
prd_id: ai-tts
number: 2
title: Audio daemon & serialized queue
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# Audio daemon & serialized queue

## Overview

The long-lived listener. `ai-tts daemon` creates the FIFO if absent, keeps it
open across reads, and forwards every line into a serialized queue consumed by a
single worker that speaks one item at a time.

## Rationale

This feature directly fixes the two data-loss bugs in the naive bash daemon:

1. **Reopen race / single-line read.** The naive `read -r line < "$PIPE"` reads
   one line then reopens the FIFO, dropping writes that land between cycles. We
   hold the read end open for the daemon's lifetime.
2. **Garbled overlap.** Multiple writers hitting `say` concurrently interleave.
   A single-consumer queue (mpsc channel → one worker thread) guarantees
   sequential, ordered playback.

## Acceptance Criteria

- `ai-tts daemon` creates the FIFO at the configured path (mode 0600) if it does
  not exist, and reuses it if it does.
- The read end stays open across many writes; lines piped in rapid succession are
  all enqueued, in order, with none dropped.
- A single worker consumes the queue and calls the `Speaker` once per item;
  concurrent producers never cause overlapping speech.
- Queue ordering and single-consumer behaviour are unit-tested with a
  `FakeSpeaker` and an in-memory channel (no real FIFO, no real audio).
- Daemon shuts down cleanly on SIGINT/SIGTERM, draining or stopping the queue.

## Tasks

### 1. Add serialized speech queue
id: 019ea781-e66b-798d-946f-2c556b5939b2
Implement an mpsc-backed queue with a single worker that pulls items and calls
the `Speaker` exactly once each, preserving order. Test ordering and
single-consumer guarantees with `FakeSpeaker`.

**Files to create:**
- `src/queue.rs`

### 2. Add FIFO channel reader that holds the pipe open
id: 019ea781-e66b-78b8-b901-4acc6b03835d
Implement a `Channel` abstraction with a FIFO-backed reader that creates the pipe
if needed and yields lines without reopening per line. Test the line-parsing /
framing logic against an in-memory reader.

**Files to create:**
- `src/channel.rs`

### 3. Add daemon command wiring queue + channel + signal handling
id: 019ea781-e66b-79de-8115-99383ff7a31d
Wire `ai-tts daemon`: open the channel, feed lines into the queue, run the
worker, and handle SIGINT/SIGTERM for clean shutdown.

**Files to create/modify:**
- `src/cmd/daemon.rs`
- `src/main.rs`
