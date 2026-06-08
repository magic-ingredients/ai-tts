---
id: configuration
uuid: 019ea782-479e-7af5-8733-03b2fe5d4a43
prd_id: ai-tts
number: 4
title: Configuration
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# Configuration

## Overview

A small TOML config (`~/.config/ai-tts/config.toml`) controls voice, rate, pipe
path, and the Claude hook behaviour. Sensible defaults mean the file is optional;
when absent, everything works with auto-detected voice and the default pipe path.

## Rationale

Different machines have different voices installed and different preferences
(rate, which hook events should speak). Centralising this in one typed config —
loaded once, defaulted safely — keeps the daemon, client, and hook handler in
sync and makes "configurable hook events" (the user's requirement) a single
source of truth.

## Acceptance Criteria

- Config loads from `~/.config/ai-tts/config.toml`; a missing file yields
  defaults without error.
- Fields: `voice` (name or `auto`), `rate` (optional WPM), `pipe_path`
  (default `/tmp/ai-tts.pipe`), `hooks.events` (subset of supported events),
  `hooks.style` (`fixed` | `context`).
- Unknown/extra keys are ignored gracefully; malformed TOML produces a clear
  error naming the problem.
- Parsing and defaulting are unit-tested, including empty file, partial file, and
  malformed file cases.

## Tasks

### 1. Add typed config with defaults and loader
id: 019ea782-479e-7e03-b761-e60d775cf04d
Define the config struct (voice, rate, pipe_path, hooks.events, hooks.style) with
defaults, and a loader that reads the TOML path or falls back to defaults.
Unit-test default/partial/malformed cases.

**Files to create:**
- `src/config.rs`
- `tests/fixtures/config_partial.toml`
- `tests/fixtures/config_full.toml`
