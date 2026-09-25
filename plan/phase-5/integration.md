# Phase 5 — Integration & polish

- [x] End-to-end: build patch on screen → hear it on device (phases 3–4)
- [x] Persistence: patch slots → [patch-slots](patch-slots.md) (owner design)
- [x] Sample workflow: browser + 40 drum one-shots in `dust/audio/rotatable-drums/`
- [x] Performance on CM3: **avg 16% / peak 17% CPU** with full 8-object patch — large headroom
- [x] Polish: status line hidden under overlays (no more text collisions);
  browser marks loaded sample (`>`); loop one-shots loop rhythmically
- [x] Usage docs: `README.md` (controls, slots, install, dev pointers)
- [ ] Owner feel-check pass (slots timing, panels, general playability)
- [ ] Remaining backlog: label collision avoidance, LINK ring clutter,
  LFO→param scaling (engine-side), pingpong/reverb delay subtypes,
  oneshot/pitchlock loop subtypes, waveshaper/sampler/audio-in/tonality/
  song-settings (the deferred 6 types), LFO tempo-sync, delay tempo-quantize
