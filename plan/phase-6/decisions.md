# Phase 6 — v2 design decisions (no code)

Resolve before building, same as Phase 0 did for v1. Each item needs a decision
recorded in docs/behavior-spec.md §7 (gap items) or docs/interaction-design.md.

**All decisions recorded in `docs/behavior-spec.md` §9 (2026-09-26, owner-approved).**

## Object-level decisions
- [x] **Sampler**: single-sample melodic player (one WAV, Phasor+BufRd, reuses
  browser); Instrument + Drum subtypes; no SF2/multi-zone in v2
- [x] **Audio-in**: in — line-in only (no mic on shield), rotation = input gain
- [x] **MIDI-in**: in — device/channel via params, rotation = transpose ±24 st,
  notes → closest connectable object
- [x] **Tonality**: quantizes sequencer notes, random sequencer, sampler,
  suboscillators (toggle); osc main rotation stays continuous
- [x] **Song settings**: skipped as object — tempo in params, patch selector
  redundant with slots, background N/A
- [x] **Waveshaper**: all three subtypes (resampler, compressor, distortion)

## Subsystem decisions
- [x] **Tempo sync architecture**: hybrid — engine tempo control bus for
  LFO/delay/loop sync; Lua metro keeps sequencer on the same BPM param
- [x] **LFO→param scaling**: per-target scale table engine-side; bipolar for
  pitch-like params, unipolar for amp/dry-wet
- [x] **Sequencer**: 6 preset slots (rotation) + random subtype in; poly
  tenori grid deferred
- [x] **Connection model v2**: v1 model kept, edge rules documented; no
  fan-out limit
- [x] **v1 leftovers**: oneshot loop, pingpong/reverb delay, LINK ring
  declutter in; **pitchlock out** (phase vocoder cost/benefit); label
  collisions already done (2026-09-26)
- [ ] **Owner feel-check findings** from v1 play sessions — none reported yet;
  collect during v2 dev
