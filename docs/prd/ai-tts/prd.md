---
id: ai-tts
uuid: 019ea781-7532-7317-8c27-04cdf3c5e2e2
title: "ai-tts — Terminal Text-to-Speech for macOS"
version: 1.0.0
status: not_started
created: 2026-06-08
updated: 2026-06-08
author: Claude Code
---

# ai-tts — Terminal Text-to-Speech for macOS

## Purpose

Reading long terminal output, build results, and log streams off the screen is
slow. macOS ships excellent neural voices (Siri, premium voices) via the `say`
command, but `say` alone has no good story for streaming data, no queueing, and
no integration with developer workflows.

`ai-tts` is a single Rust binary that turns the native macOS speech layer into a
**terminal audio channel**: a long-lived daemon listens on a named pipe (FIFO),
and any CLI tool can pipe or echo text to hear it spoken in the background. It
also ships a deterministic Claude Code hook so the agent can speak when it
finishes work or needs your input — wired through the harness, not left to the
model to remember.

## Goals

1. **Stream-safe playback.** Pipe arbitrary text (multi-line, high-volume) into
   a channel and hear all of it, in order, without dropped lines or garbled
   overlapping speech.
2. **Native quality.** Use the best available macOS neural voice, detected at
   runtime — no hard-coded voice that may not be installed.
3. **Zero runtime deps.** One self-contained binary providing daemon, client,
   hook, and install modes. No node/bash/python runtime to manage.
4. **Deterministic Claude integration.** Speak on configurable Claude Code hook
   events via `.claude/settings.json`, so notification is reliable rather than
   dependent on the model remembering a CLAUDE.md directive.
5. **Testable core.** Queue, voice-selection, config, and hook-parsing logic are
   unit-tested with the side-effecting `say` call abstracted behind a trait
   (TDD per repo guidelines).

## Non-Goals

- Cross-platform speech (macOS-only; `say` is the engine).
- Cloud/third-party TTS providers.
- A GUI. This is a CLI/daemon tool.
- Audio mixing, ducking, or playback of non-speech audio.

## User Needs

- **As a developer**, I want to pipe a long build log or file into a command and
  hear it read aloud, so I can keep working while it plays.
- **As a developer running a long task**, I want an audible "done" when a build
  or test suite finishes, so I don't have to watch the terminal.
- **As a Claude Code user**, I want my Mac to speak when Claude finishes or needs
  my input, so I can step away and still know when to come back — reliably, every
  time.
- **As a user with premium voices installed**, I want the best voice picked
  automatically, and the ability to override voice/rate via config.

## Architecture Overview

Single binary `ai-tts` with subcommands:

- `ai-tts daemon` — creates/opens the FIFO, keeps it open across reads, and feeds
  text into a serialized queue (mpsc channel → single worker thread) so only one
  `say` runs at a time and overlapping writers never garble.
- `ai-tts speak [TEXT...]` — client. Reads stdin and/or args and writes lines to
  the FIFO (the channel). Pipe-friendly (`cat x | ai-tts speak`).
- `ai-tts hook` — reads a Claude Code hook event JSON on stdin, decides whether
  to speak based on config (which events are enabled, fixed vs context-aware
  phrase), and emits text to the channel.
- `ai-tts voices` — lists available voices and the one auto-selected.
- `ai-tts init` — bootstraps config and wires the Claude Code hooks into
  `.claude/settings.json`; optionally installs a launchd agent to autostart the
  daemon.

Side effects (`say`, FIFO I/O) live behind traits (`Speaker`, `Channel`) so the
queue, voice-selection, config, and hook logic are unit-tested with fakes.

## Configuration

A config file (`~/.config/ai-tts/config.toml`) controls:
- `voice` — explicit voice name, or `auto` (runtime detection).
- `rate` — words per minute (optional).
- `pipe_path` — FIFO location (default `/tmp/ai-tts.pipe`).
- `hooks.events` — which Claude Code events speak (e.g. `notification`, `stop`,
  `subagent_stop`) — any subset, configurable.
- `hooks.style` — `fixed` (canned phrase per event) or `context` (short line
  derived from the event payload).

## Features

1. [Voice detection & speaker core](features/voice-and-speaker.md)
2. [Audio daemon & serialized queue](features/audio-daemon.md)
3. [`speak` client CLI](features/speak-client.md)
4. [Configuration](features/configuration.md)
5. [Claude Code hook handler](features/claude-hook.md)
6. [Install & bootstrap](features/install-bootstrap.md)

## Success Criteria

- `cat bigfile.txt | ai-tts speak` reads the entire file aloud, in order, no
  dropped lines, while the terminal stays free.
- Two rapid writers to the channel are spoken sequentially, never overlapping.
- On a machine with a Siri/premium voice installed, `ai-tts voices` auto-selects
  it; on a bare machine it falls back to the system default without error.
- After `ai-tts init`, Claude Code speaks on the configured events every time the
  hook fires (verified by triggering a Notification/Stop event).
- Core logic (queue ordering, voice selection, config parsing, hook routing) is
  covered by passing unit tests that never invoke real `say`.
