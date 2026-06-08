---
id: install-bootstrap
uuid: 019ea782-afc8-7c73-b873-f555d2572dc1
prd_id: ai-tts
number: 6
title: Install & bootstrap
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# Install & bootstrap

## Overview

`ai-tts init` makes setup one command: write a default config, wire the Claude
Code hooks into `.claude/settings.json`, and optionally install a launchd agent
so the daemon autostarts at login. `ai-tts voices` lists detected voices and the
auto-selected one for quick verification.

## Rationale

The manual steps in the naive writeup (nano the script, chmod, edit .zshrc, edit
CLAUDE.md) are error-prone. A single `init` that merges hook entries into
`settings.json` without clobbering existing hooks, and an opt-in launchd plist,
turns setup into something reproducible and reversible.

## Acceptance Criteria

- `ai-tts voices` prints available voices and marks the auto-selected one.
- `ai-tts init` writes a default `~/.config/ai-tts/config.toml` if none exists
  (never overwrites an existing one without a flag).
- `ai-tts init` merges the `ai-tts hook` entries into `.claude/settings.json`
  hook arrays for the configured events, preserving any existing hooks (idempotent
  — re-running does not duplicate).
- An opt-in flag installs a launchd agent that runs `ai-tts daemon` at login;
  another removes it.
- The settings.json merge logic is unit-tested (existing-hooks-preserved,
  idempotent re-run, empty-file) against in-memory JSON.

## Tasks

### 1. Add voices command
id: 019ea782-afc8-7bae-a22f-795be487f2e8
Wire `ai-tts voices` to print detected voices and the auto-selected one, reusing
the voice-detection module.

**Files to create/modify:**
- `src/cmd/voices.rs`
- `src/main.rs`

### 2. Add settings.json hook merge
id: 019ea782-afc9-795b-82d5-3e336db92d30
Implement idempotent merging of `ai-tts hook` entries into a Claude Code
`settings.json` hooks structure, preserving existing hooks. Unit-test
preserve/idempotent/empty cases against in-memory JSON.

**Files to create:**
- `src/settings.rs`

### 3. Add init command with config write and optional launchd agent
id: 019ea782-afc9-77e4-8345-820f801b2526
Wire `ai-tts init`: write default config (no clobber), apply the settings.json
merge, and behind opt-in flags install/remove a launchd agent for the daemon.

**Files to create/modify:**
- `src/cmd/init.rs`
- `src/main.rs`
