# Phase 7 — Engine v2 (SuperCollider)

Depends: phase-6 decisions (done 2026-09-26 → `docs/behavior-spec.md` §9).

- [x] Engine-side tempo control bus (hybrid decision): `tempo` command sets
  bpm on a control bus; lua `rot_tempo` param is the single source of truth
  (pushes both the seq metro and `engine.tempo`). Consumed by LFO sync,
  delay quantize, loop bar-entry. Sequencer stays on Lua metro
- [x] LFO tempo-sync (`sync=1`: freq = tempo grid, `mult` = period in 32nd
  notes) + per-target modulation scale: mod bus is now bipolar ±depth;
  pitch-like targets (osc/sampler freq, loop rate, filter cutoff) scale
  2^mod, delay time 2^(mod/2), amp/dry-wet/gain targets stay unipolar
- [x] Delay tempo-quantization (`sync=1` snaps time to 32nd notes) + `sweep`
  (lag time on time changes)
- [x] Delay subtypes: pingpong (cross-feedback dual tap, mono-compatible),
  reverb (FreeVerb)
- [x] Loop subtype: oneshot via PlayBuf + `t_trig` (pitchlock OUT per phase-6)
- [x] Waveshaper synth (resampler/compressor/distortion)
- [x] Audio-in synth (line in, gain)
- [x] Sampler synth: single-sample melodic player (instrument = gated ADSR,
  drum = one-shot perc env), Phasor→Sweep→**PlayBuf+t_trig** after trigger
  saga; notes via `trigger` command (freq + t_trig, type-aware)
- [x] Tonality quantizer (`lib/tonality.lua`: major/minor/pentatonic/
  chromatic; snaps seq + random-seq + sampler notes when a tonality object
  is on the table; osc rotation stays free). Random seq subtype improvised
  notes included
- [x] Loop bar-entry sync (`sync` 0/1/2 = immediate/quarter/bar) via tempo bus
- [x] Per-object level polls: fixed pool of 16 `lvl_N` polls registered at
  engine load (matron discovers polls only at load); slot mirror in
  `lib/audio.lua` (`T.lvl(id)` / `Audio.lvl_poll(id)`)
- [x] CPU re-benchmark with 13 types: **avg 23.3%, peak 24.1%** (was 16% in
  v1) — headroom fine, no cap change needed

## Gotchas learned (phase 7)

- **`t_` trigger args are hoisted to the FRONT of the SynthDef control
  list** — index-based `s_get`/`s_set` must not assume declaration order.
  (Cost hours of stale-index debugging.)
- One-shots: PlayBuf + `t_trig` is the reliable pattern. Changed.kr(control)
  retrigger and Phasor/Sweep edge hacks all failed or wrapped; PlayBuf is
  silent after sample end for free (no DC hold).
- Engine `trigger` is type-aware: sampler/loop get freq + t_trig (single-pair
  sets), oscillators keep the gate -1→1 edge.
- Testing discipline: `T.clear()` does NOT reset `next_id` — always take ids
  from `/state`; buffer numbers don't survive a server restart; verify
  `b_info` frames before trusting playback tests; matron only discovers
  engine polls at engine load (register pools upfront).

## Phase-8 hooks ready

- All 13 types in `World.TYPES`/`World.MENU` (place menu works, glyphs by
  category; panels/polish are phase 8)
- `lvl_1..16` polls + `Audio.lvl_poll(id)` for per-object VU visuals
- `sync`/`sweep`/`mult`/`base` params flow through `sync_object`
