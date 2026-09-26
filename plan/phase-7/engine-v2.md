# Phase 7 — Engine v2 (SuperCollider)

Depends: phase-6 decisions (done 2026-09-26 → `docs/behavior-spec.md` §9).

- [ ] Engine-side tempo control bus (hybrid decision): tempo set via engine
  command; single source of truth = BPM param. Consumed by LFO sync, delay
  quantize, loop bar-entry. Sequencer stays on Lua metro
- [ ] LFO tempo-sync (period = multiple of 32nd note, per spec) + per-target
  modulation scale table (bipolar pitch-like, unipolar amp/dry-wet)
- [ ] Delay tempo-quantization for long values + sweep setting
- [ ] Delay subtypes: pingpong (stereo), reverb
- [ ] Loop subtype: oneshot (pitchlock OUT per phase-6)
- [ ] Waveshaper synth (resampler/compressor/distortion)
- [ ] Audio-in synth (line in, gain)
- [ ] Sampler synth: single-sample melodic player (Instrument + Drum
  subtypes), one WAV pitched via Phasor+BufRd, note triggers from
  rotation/sequencer
- [ ] Tonality quantizer (Lua-side utility is enough: constrains seq notes,
  random seq, sampler notes, subosc toggle; osc rotation stays free)
- [ ] Loop bar-entry sync (immediate/quarter/bar) via tempo bus
- [ ] Per-object level polls for visuals (VUs on objects?)
- [ ] CPU re-benchmark with 13 types; adjust object caps
