# Phase 11 — Factory presets re-imagined: 16 tutorial-grade tables

Owner request 2026-09-28. The 8 factory presets were authored for v1 and
predate v2/v3 features (tempo object, output FX, suboscillators, tonality
note masks, effect envelopes, pingpong/reverb delay, poly/random sequencers,
oneshot loops, instrument sampler, MIDI in). Re-author as **16 presets**
that (a) form a tutorial arc — each table teaches 1–2 concepts — and (b) are
musically richer and more entertaining than the current set.

## Mechanics (small code changes) — done 2026-09-28

- [x] `lib/slots.lua:6` — `Slots.N = 8 → 16`. Ring geometry is count-driven
  (`Slots.pos`), 22.5° spacing ≈ 22 px apart at default zoom vs 8 px slot
  squares — fits fine; off-screen culling already handles the ring being
  larger than the screen.
- [x] `lib/ui.lua` — confirm text + ABOUT preset count now derive from
  `Slots.N`; ABOUT version string un-staled (v2-dev → v3).
- [x] `Slots.restore_factory()` needs no change (loops `1..Slots.N`) but
  silently skips missing files — all 16 `presets/slots/*.lua` must exist.
- [x] New saves use the v2 `patterns` format (old files were v1 `steps`;
  recall migrates — old files can be deleted once replaced).

## Constraints / gotchas for authoring

- **Samples (expanded 2026-09-28):** `presets/audio/` now bundles 26 new
  WAVs alongside the 5 v1 drum hits — `drums/` (8 synthesized: kick, snare,
  clap, chh, ohh, tom, cowbell, clave; CC0), `instruments/` (9 BBC
  Philharmonia notes CC-BY 2.5 + theremin CC-BY 3.0, pitch-named e.g.
  `cello_G3.wav`), `animals/` (8 Red Library clips CC0). Provenance and
  licenses: `presets/audio/SOURCES.md` (ships on release).
  At authoring time push the same tree to `~/dust/audio/rotatable-drums/`
  so slot files carry the prefix that `restore_factory` rewrites.
- **Authoring path:** scripted on-device via the REST harness
  (`tools/djset.py` pattern) + `POST /lua {"code":"T.save_slot(N)"}`, then
  SFTP the slot files back into `presets/slots/`. `T.set` cannot set
  `subs`, tonality `notes`, or wholesale `patterns` — use single-line `/lua`
  statements for those (AGENTS.md gotcha 11).
- **Effect env trap:** recall force-migrates effect envs with `s == 0.7` to
  `s = 0` (`slots.lua:116-118`) — never author an effect envelope with
  s=0.7; it won't survive save/recall.
- **CPU ceiling:** ~30 % avg on CM3 was accepted for 15 objects + master FX;
  keep the biggest preset ≤ 14 objects and re-benchmark.
- Every preset gets a **tempo object** (v3) and sensible **output FX**
  (rev/room/comp) — these alone modernize the set.

## The 16 tables

Tutorial arc: 1–8 fundamentals (one concept each), 9–13 intermediate
controllers/effects, 14–15 special modes, 16 the showpiece. Names stay
short for the README table.

| # | name | BPM | teaches | contents |
|---|------|-----|---------|----------|
| 1 | HELLO | 110 | proximity patching, rotation = pitch, slider dot = amp, tempo object | saw osc + mono sequencer (8-note nursery pattern) + tempo object; output rev low |
| 2 | BEAT | 120 | sampler, hardlink (LINK K3), step editor, velocity | synth `kick` sampler + 1 hardlinked 16-step sequencer, four-on-floor with ghost claps |
| 3 | KIT-808 | 124 | multiple hardlinks, mute (LINK K1+K3), output comp | the classic grown: TR909 kick/snare/hat + clap, each own sequencer; one connection pre-muted (alt snare) to demo mute; comp 0.3 |
| 4 | KEY | 100 | tonality snapping, root rotation, custom note mask (v3) | osc + sequencer + minor tonality with a *custom* notes mask (harmonic minor) — shows the notes panel is editable |
| 5 | SUB | 95 | suboscillators (v3), LP filter, res (slider on filter) | saw + 2 subs (oct-down follow, detuned fifth), LP cutoff low, mono sequencer bassline |
| 6 | ACID | 128 | LFO controller, tempo sync (sync/mult), env on effect | saw → LP, saw LFO synced 1/4 on cutoff, minor tonality; filter env gives extra bite — the v1 ACID, grown up |
| 7 | PING | 100 | delay subtypes, pingpong, feedback env swell (v3) | clave + cowbell samplers → pingpong delay sync 3/8, syncopated sequencer; effect env swells feedback — the v1 PING, grown up |
| 8 | WASH | — | audio input, waveshaper compressor, reverb delay, output FX | line in → compressor → reverb delay (room high) → output rev; run a radio/synth through the table |
| 9 | CHOIR | 60 | parallel generators mixing at output, chorus, vibrato LFO | cello + violin samplers a fifth apart + subosc root osc, chorus, slow synced sine LFO vibrato, big output rev/room — v1 CHOIR with real strings |
| 10 | POLY | 108 | sequencer poly subtype, pattern presets 1–6 (rotation) | poly sequencer → trumpet sampler, second mono sequencer → noise osc "snare"; patterns set to contrasting presets to invite rotation through 1–6 |
| 11 | SOLO | 112 | random sequencer + pentatonic = automatic solos, velocity dynamics | random seq (wide vel spread) → theremin → chorus → feedback delay; pentatonic tonality — v1 SOLO with an echo trail |
| 12 | DUB | 90 | loop player, sync modes, delay time LFO, room reverb | kick loop (rate ~0.5, bass pulse) → feedback delay quantized to tempo, slow sine LFO on delay time, output room — v1 DUB, deeper |
| 13 | CRUSH | 96 | waveshaper resampler, HP filter, random LFO on dry-wet | snare-stutter loop → resampler → HP, random LFO on resampler dry-wet, comp — v1 CRUSH, nastier |
| 14 | PLUCK | 118 | instrument sampler + tonality, loop oneshot subtype, envelope gating | mandolin + saxophone instrument samplers trading a melodic minor line (two hardlinked sequencers), oneshot snare backbeat |
| 15 | ZOO | 80 | sound design: generators don't have to be musical, slow loop rates, extreme filtering | elephant trumpet → BP filter → pingpong delay call-and-response; crickets loop (rate ~2) as shaker groove; bear growl → resampler drone; frog one-shots. The "wait, THAT'S an option?" preset |
| 16 | FINALE | 122 | everything at once; performance patch | ~13 objects: synth-kit drums, tuba/sub bass, ACID saw lead, horn stabs, theremin pad, tempo object, full output FX (rev+comp). The demo you play people |

## Execution

- [x] Write `tools/presets.py`: one builder function per preset using the
  djset.py REST helpers + new `T.sub`/`T.notes`/`T.restore_factory`
  harness helpers; each ends with `T.save_slot(N)`; `--pull` SFTPs slot
  files back to `presets/slots/`
- [x] Build + device-verify presets 1–8 (post-recall connection counts +
  amp-peak check; KIT-808 mute survives recall)
- [x] Build + device-verify presets 9–16; CPU benchmark on FINALE:
  **11.5 % avg / 13.4 % peak** (15 objects + master FX — well under ~30 %)
- [x] Code changes: `Slots.N`, ui.lua texts, ABOUT count (all derive from N)
- [x] RESTORE PRESETS on device → recall all 16 → sample path rewrite
  verified end-to-end (instrument/animal slots audible post-restore),
  mutes/hardlinks/subs/notes survive. Bonus fix: all 10 instrument WAVs
  re-trimmed at detected onsets (BBC/Berklee lead-in silence made gated
  notes nearly silent)
- [x] README: new 16-row preset table with the "teaches" column; notebook
  entry; plan.md index (phase-11 line)
- [x] Commit on main (`e8917ad`); release-branch bundling follows the
  phase-9 decision (presets already ship on release)

## Post-release field testing (2026-09-29, owner hands-on)

First hands-on session surfaced two same-symptom bugs ("no sequence
execution"), both fixed and committed:

- **Frozen seq metro** (`b8b0f91`): tick callback now pcall-wrapped
  (rate-limited error prints), 1 s watchdog restarts a stopped clock,
  `T.health()` probe added.
- **Engine-node leak** (`12fd30f`): norns `include()` is per-includer, so
  ui.lua's own audio/slots copies had a separate empty node mirror —
  physical recalls/clears never freed engine nodes until scsynth exhausted
  RT memory (`JackDriver: alloc failed`). audio.lua/slots.lua are now
  global-guarded singletons. Harness-only testing had missed this because
  `T.*` always used the correct instances — physical-path coverage matters.
  AGENTS.md gotcha 13.

## Open questions for owner

1. ~~Add melodic WAVs?~~ Resolved 2026-09-28: 26-sample library added
   (drums/instruments/animals).
2. MIDI preset: dropped from the 16 (ZOO took slot 15) — keep a MIDI demo
   as a 17th non-factory example, or leave MIDI to the docs?
3. Preset names: keep the punchy 4–6 char style (proposed above) or more
   descriptive ("1 · FIRST PATCH")?
