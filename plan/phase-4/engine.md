# Phase 4 — Audio engine (SuperCollider)

- [x] `Engine_Rotatable : CroneEngine` skeleton: groups, bus dictionary, addCommand set, free
- [x] Object lifecycle commands: add/remove object, connect/disconnect (audio + control), set param
- [~] Generators: oscillator (4 waves; no drawn waveform), loop player (def + load cmd, untested), sampler, audio-in
- [~] Effects: filter (LP/BP/HP), delay (feedback only; no pingpong/reverb), modulator (ring/chorus/flanger), waveshaper
- [x] Controllers: LFO (4 shapes; not tempo-synced), sequencer (16-step pentatonic, Lua-clocked; no presets UI)
- [~] Globals: tempo (param `rot_tempo` 40–240), output (master volume) — tonality/reverb/comp deferred
- [x] Proximity→routing glue in Lua (`lib/audio.lua` hooks World.add/remove/recompute/toggle_mute)
- [x] Master amp polls wired for REPL verification (per-object level polls deferred)
- [x] Numeric ranges decided — recorded in behavior-spec.md §7

## Decisions (2026-09-25)

- Architecture per brief: one synth + private inBus per object in a `nodeGroup`;
  master `rot_out` synth (in context.xg, after nodeGroup) reads masterBus → volume
  → context.out_b. Silent bus = destination for unconnected/muted sources.
- **Critical scsynth lesson**: audio buses are zeroed at the start of every
  control block, so a reader must execute *after* the writer in the node tree.
  `connect_audio` therefore calls `src.moveBefore(dst)`; all node synths live in
  nodeGroup (addToTail), master after it. Also: engine synths must live in
  `context.xg` (before crone's amp monitor synths) or amp polls see nothing.
- Extra commands beyond the brief: `connect_control`/`disconnect_control`
  (LFO→param bus mapping), plus silent debug commands `probe`/`tree`/`remaster`.
- Ranges (also in spec §7): osc 55–880 Hz (angle, 4 oct exp); filter cutoff
  40–12000 Hz log, res 0–1 → rq 0.05–1; delay 0.01–2 s, feedback 0–0.99; mod
  ring 10–2000 Hz / chorus 0.1–8 Hz / flanger 0.05–2 Hz; LFO 0.05–20 Hz, depth
  0–1 unipolar; loop rate 0.25–4; tempo 40–240 default 120; master vol 0–1.
- LFO→target mapping (spec gap 5): v1 = unipolar 0..depth onto target amp
  (dry/wet for modulator) via control-bus `.map`.
- Sequencer (spec gap 4): v1 drives only oscillator targets: fixed 16-step
  minor-pentatonic pattern (odd steps on), 16th notes, `engine.trigger` =
  freq set + gate force-retrigger (negative gate trick).

## TODO / untested

- Loop player: `rot_loop` def + `load` command exist but untested (no sample).
- Modulator: def exists; only smoke-tested via set commands, not polled.
- Pingpong/reverb delay subtypes, waveshaper, sampler, audio-in, tonality,
  global FX: not started (deferred to later phases per v1 core-8 scope).
- LFO tempo-sync, delay tempo quantization, loop sync modes: not implemented.
- Subtype switching updates `select` live but SelectX crossfades — fine.
