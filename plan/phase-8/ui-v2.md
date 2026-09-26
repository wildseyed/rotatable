# Phase 8 — UI & panels v2 (Lua)

Depends: phase-7 (or parallel where independent). Phase-6 decisions in
`docs/behavior-spec.md` §9.

- [ ] Place menu with all 13 types (windowed scroll already works; verify feel)
- [ ] Suboscillators panel (oscillator: 4 subs × waveform/amp/detune/offset +
  follow-tonality toggle)
- [ ] Sequencer pages: velocity page, step-duration page (multiples of 32nd)
- [ ] Sequencer preset slots (rotation switches 6 stored patterns per object)
- [ ] Sequencer random subtype UI (poly grid deferred per phase-6)
- [ ] Settings pages: loop (sync immediate/quarter/bar + gain), delay (sweep),
  modulator (extras)
- [ ] Sampler browser (reuse loop browser; instrument/drum subtype toggle)
- [ ] MIDI-in: device select + channel in params; note routing to closest object
- [ ] Tonality UI: preset ring around the star? edit notes on-object (design needed)
- [ ] ~~Song settings~~ — dropped per phase-6 (tempo stays in params)
- [ ] Waveform draw for oscillator (user waveforms) — feasible? gesture = draw
  with encoders on a page
- [ ] Visual polish: LINK ring clutter,
  connection animation (signal flow dashes), tempo pulse at output point
