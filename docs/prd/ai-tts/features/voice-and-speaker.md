---
id: voice-and-speaker
uuid: 019ea781-ae2e-731f-93c0-781083ec48c7
prd_id: ai-tts
number: 1
title: Voice detection & speaker core
status: not_started
created: 2026-06-08
updated: 2026-06-08
---

# Voice detection & speaker core

## Overview

The foundation: a `Speaker` trait that abstracts "speak this text", a macOS
adapter that shells out to `say`, and runtime voice selection that picks the best
available neural voice. Everything else in the project speaks through this layer,
and tests substitute a fake `Speaker` so no test ever produces real audio.

## Rationale

The naive design hard-codes `say -v "Siri"`, which fails on any machine where a
Siri voice was never downloaded. Detecting the best voice at runtime makes the
tool work out of the box and degrade gracefully to the system default. Putting
`say` behind a trait is what makes the rest of the codebase testable.

## Acceptance Criteria

- A `Speaker` trait exposes a `speak(text, voice, rate)`-style method.
- `SaySpeaker` (macOS adapter) invokes `say` with the chosen voice/rate; argument
  construction is unit-tested without executing `say`.
- Voice selection parses `say -v ?` output and ranks: premium/Siri/enhanced
  neural voices first, then any English voice, then system default.
- Selection logic is unit-tested against captured `say -v ?` sample output
  (fixtures), including the bare-machine case (no premium voices → default).
- A `FakeSpeaker` records calls for use by other features' tests.

## Tasks

### 1. Add Speaker trait and FakeSpeaker test double
id: 019ea781-ae2e-73d6-b68f-eab6d217c759
Define the `Speaker` trait (speak text with a resolved voice + optional rate) and
a `FakeSpeaker` that records invocations. Drive the shape with tests asserting
recorded calls.

**Files to create:**
- `Cargo.toml`
- `src/lib.rs`
- `src/speaker/mod.rs`
- `src/speaker/fake.rs`

### 2. Add SaySpeaker macOS adapter with tested argument construction
id: 019ea781-ae2e-756a-9567-deba7fcbbb44
Implement the `say`-backed adapter. Factor out a pure function that builds the
`say` argument vector (voice, rate, text) so it can be unit-tested without
spawning a process.

**Files to create/modify:**
- `src/speaker/say.rs`
- `src/speaker/mod.rs`

### 3. Add runtime voice detection and ranking
id: 019ea781-ae2e-7b0f-bd72-e58602aac622
Parse `say -v ?` output into candidate voices and select the best per the ranking
rules, falling back to the system default. Test against fixture output covering
premium-present and premium-absent machines.

**Files to create/modify:**
- `src/voice.rs`
- `tests/fixtures/say_voices_premium.txt`
- `tests/fixtures/say_voices_bare.txt`
