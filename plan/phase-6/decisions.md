# Phase 6 — v2 design decisions (no code)

Resolve before building, same as Phase 0 did for v1. Each item needs a decision
recorded in docs/behavior-spec.md §7 (gap items) or docs/interaction-design.md.

## Object-level decisions
- [ ] **Sampler**: original used SoundFont 2 — no SF2 player in scsynth. Decide:
  simple multi-zone WAV sampler (our own format), single-sample melodic player,
  or skip sampler in v2?
- [ ] **Audio-in**: norns line/mic in — gain staging, monitoring etiquette
  (feedback risk on built-in mic? shield has no mic — line in only)
- [ ] **MIDI-in**: which norns MIDI device mapping; rotation = transpose;
  where do notes land (closest object, per spec)
- [ ] **Tonality**: global scale quantizer — affects what exactly in v1 core
  (osc freq quantize? sequencer note output? both, toggleable?)
- [ ] **Song settings**: tempo already in params; what else survives v2
  (patch selector redundant with our slots?)
- [ ] **Waveshaper**: resampler/compressor/distortion subtypes — all three or subset?

## Subsystem decisions
- [ ] **Tempo sync architecture**: Lua metro (current, sequencers) vs engine-side
  clock — needed for LFO tempo-sync + delay tempo-quantization
- [ ] **LFO→param scaling**: engine-side modulation ranges (currently LFO maps
  raw 0..depth onto amp; spec §7.5) — bipolar? per-target scale table?
- [ ] **Sequencer**: poly subtype worth it at 128×64? random subtype + tonality
  ("automatic solos")? 6 preset slots per sequencer (rotation) — implement?
- [ ] **Connection model v2**: fan-out limits, effect chain ordering edge cases,
  control-connection retargeting when hardlinked
- [ ] **v1 leftovers**: oneshot/pitchlock loop subtypes; pingpong/reverb delay
  subtypes; label collisions; LINK ring clutter
- [ ] **Owner feel-check findings** from v1 play sessions — collect and rank
