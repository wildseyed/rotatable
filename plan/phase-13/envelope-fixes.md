# Phase 13a — Envelope (ADSR) fixes — DONE 2026-10-11, device-verified

Source: code investigation 2026-10-11. All items implemented and verified
on device via the REST harness; e2e green (after fixing a stale e2e
assertion, see below).

## 1. Sampler gated ADSR never retriggers — FIXED

`rot_sampler` was the only retriggerable envelope without the `t_retrig`
mechanism (gotcha 15 fixed osc + effects but not the sampler): first note
played flat at sustain (gate defaulted 1), legato MIDI and dense sequencer
notes never re-articulated.

- [x] `rot_sampler`: `t_retrig` arg; envGated gate =
      `gate.clip(0, 1) * (1 - t_retrig)`; `gate` defaults 0 (instrument
      starts closed → first trigger gets a real attack; drum subtype
      untouched — envDrum lives on `t_trig`)
- [x] engine `trigger` sampler/loop branch: `set(\gate, 1, \t_retrig, 1)`;
      `loadbuf` placement trigger likewise (covers reload-while-open)
- [x] deploy + full ordered restart (gotcha 3)
- [x] device-verify (cello_G3.wav, a=1.5 s): placement trigger ramped
      0.074 → 0.349 (pre-fix: instant sustain); rotation retrig dipped
      0.329 → 0.066 (env restarts while gate stays 1); drum subtype still
      fires on load and self-terminates (hit 0.108, tail 0.000)
- [x] e2e regression green

## 2. Env page: sustain is a level, not seconds — FIXED

- [x] `lib/ui.lua`: `s` edits clamp 0..1 (a/d/r stay 0..4); s bar drawn
      against 1.0 full-scale
- [x] `lib/slots.lua` recall migration: stored `s` clamped to 1.0
- [x] device-verify (UI sim through /key//enc): cranking s lands at 1.0,
      a still scales to 4 s. Note: `T.state` now also exposes `env`
      (additive API extension so the harness can read it back); `T.set`
      intentionally stays unclamped (power-user escape hatch)

## 3. Drift sequencer skips `vel` for effect targets — FIXED

- [x] drift else-branch sets `vel` (0.45+rand*0.4) before the bare retrig,
      mirroring the pitched branch's amp randomization

## 4. Loop player ADSR — IMPLEMENTED (owner-approved option a)

Spec §3.2 amplitude envelope, previously deferred (gap-analysis §5) with a
dead env page as the tell.

- [x] `rot_loop` gains `a/d/s/r/vel/t_retrig`; env (× vel) multiplies the
      signal; `gate` stays 1, retrig via `t_retrig` on seq/MIDI notes and
      sample (re)loads
- [x] `world.lua`: loop env default `s=1` — free-running loops keep full
      rest volume; the env only articulates on retrig. Slot migration:
      stored loop envs with `s=0.7` (provably inert pre-fix) → `s=1`
- [x] device-verify (cello loop, a=2 s): reload retrig dipped
      0.059 → 0.211 (baseline 0.193) — articulates, no volume regression.
      (First attempt with birds.wav was unreadable — staccato content
      masks the envelope; steady samples only for env tests.)
- [x] e2e regression green

## 5. Known artifact (parked, owner-aware)

`t_retrig` restarts the envelope from 0 regardless of current level
(standard SC EnvGen behavior) — an osc retriggered at sustain clicks on
dense sequences. Masked on the sampler (PlayBuf restarts anyway). Park
unless reported.

## Side fix

- [x] `tools/e2e.py`: stale since v3.2.2 — random sequencer subtype was
      renumbered 3→2 when poly was dropped; the "random improvises" check
      set 3 (drift, no `_hist`) and could never pass. Now sets 2.

## Wrap-up

- [x] notebook.md entry
- [x] README: loop env panel now described as functional
