# Phase 8 — UI & panels v2 (Lua)

Depends: phase-7 (or parallel where independent). Phase-6 decisions in
`docs/behavior-spec.md` §9.

- [ ] Place menu with all 13 types (windowed scroll already works; verify feel)
- [ ] Suboscillators panel (oscillator: 4 subs × waveform/amp/detune/offset +
  follow-tonality toggle)
- [ ] Sequencer pages: velocity page, step-duration page (multiples of 32nd)
- [ ] Sequencer preset slots (rotation switches 6 stored patterns per object;
  today rotation writes an inert `preset` param — audit 2026-09-27)
- [ ] Sequencer random subtype UI (poly grid deferred per phase-6)
- [ ] Settings pages: loop (sync immediate/quarter/bar + gain), delay (sweep),
  modulator (extras)
- [ ] Sampler browser (reuse loop browser; instrument/drum subtype toggle) —
  currently no on-device way to load a sample into a sampler at all
- [ ] MIDI-in: device select + channel in params; note routing to closest object
- [ ] Tonality UI: preset ring around the star? edit notes on-object (design needed)
- [ ] ~~Song settings~~ — dropped per phase-6 (tempo stays in params)
- [ ] Waveform draw for oscillator (user waveforms) — feasible? gesture = draw
  with encoders on a page
- [ ] Visual polish: LINK ring clutter,
  connection animation (signal flow dashes), tempo pulse at output point

## UI-reachability gaps (audit 2026-09-27, owner request)

Engine + `params` support these; the keys can't reach them. Presets ACID /
DUB / CHOIR already rely on them, so they're un-rebuildable on-device.

- [ ] **Sync settings page** (one shared L3 pattern): LFO `sync` + `mult`
  (period in 32nd notes); delay `sync` (32nd quantize) — sweep already
  covered by the delay settings page above; loop `sync` likewise
- [ ] **Sampler `base`** pitch (sample's natural pitch) — settings page or
  ROTATE E3 slot for sampler
- [ ] **Steps editor pitch range** UI ±12 vs engine ±24 — align to ±24
- [ ] README: call out that subtypes cycle with K1+E2 in ROTATE (RANDOM
  etc. were undiscoverable — owner feedback)
