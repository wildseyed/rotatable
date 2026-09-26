# Phase 7 — Engine v2 (SuperCollider)

Depends: phase-6 decisions.

- [ ] Engine-side tempo clock (shared by LFO sync, delay quantize, sequencer if moved)
- [ ] LFO tempo-sync (period = multiple of 32nd note, per spec)
- [ ] Delay tempo-quantization for long values + sweep setting
- [ ] Delay subtypes: pingpong (stereo), reverb
- [ ] Loop subtypes: oneshot, pitchlock (time-stretch — decide SC technique)
- [ ] Waveshaper synth (resampler/compressor/distortion)
- [ ] Audio-in synth (line in, gain)
- [ ] Sampler synth (per phase-6 decision)
- [ ] LFO modulation scaling (per phase-6 decision)
- [ ] Tonality: quantizer utility (Lua or engine?) applied to osc/seq outputs
- [ ] Per-object level polls for visuals (VUs on objects?)
- [ ] CPU re-benchmark with 14 types; adjust object caps
