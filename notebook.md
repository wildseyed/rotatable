# Rotatable — Project Notebook

*Running project notes. Plan: `plan.md` + `plan/phase-N/`. Session archives:
`prompt-archive/`. Project guide: `AGENTS.md`.*

**STATUS (2026-09-27): v2 phase 7 done, phase 8 in progress.** Engine v2
verified on hardware; 8 factory presets bundled + SYSTEM menu shipped. Phase 8
plan (`plan/phase-8/ui-v2.md`) is batch-ordered for fresh-session execution:
batch 1 = sync/sample UI gaps, batch 2 = sequencer depth, batch 3 = MIDI +
polish; subosc/tonality-editor/waveform-draw parked pending owner design.

---

## Working conventions (project owner's preferences)

- **Plans as Markdown with checkable todo lists** (`- [ ]` / `- [x]`) so progress is trackable.
- **Archives**: old plans go in `plan-archive/`, old prompts in `prompt-archive/` — both for posterity and as recovery insurance against context compaction losing the thread.
- **Small tasks, frequent writes**: break work into small pieces and write to file often, to avoid context exhaustion on large file writes and half-finished work.

## Vision (from the project owner)

### Multi-level navigation hierarchy
- Level 1: navigation of the table surface; deeper levels: place blocks from a
  menu, enter/configure blocks, move/rotate/connect objects.
- Table is **round**, **larger than the screen**. **E1 = Z (zoom), E2 = X,
  E3 = Y**; CCW negative, CW positive.
- **Vector display only** (arbitrary zoom); faint dotted grid for motion
  perception (clipped to the table); table edge = arc.
- **Lua = UI, SuperCollider = DSP**; replicate the Reactable sound objects as
  a runtime-patchable norns engine. **No webcam/computer vision** — objects are
  virtual. Mechanics design delegated to the assistant.

## Reference material

- `reference/` — full mirror of the original Reactable manual (2011), Markdown
  in `manual/md/`. See `reference/README.md`.
- reactable.com lives on as a founder-maintained legacy site (company dissolved
  2022); the mobile manual is live and filled the accelerometer/navigation gaps.

## Norns device access (verified 2026-09-24)

- Host `norns` @ IP in `.device/norns-ip-address`, user `we`, password in
  `.device/norns-ssh-credetials`. Reference those files; never copy secrets.
- SSH via Python paramiko (no sshpass/expect on desktop).
- Deploy: `tools/deploy.py`; testing API: `tools/api.py` (port 8787).
  Norns/engine gotchas: see AGENTS.md "Gotchas learned".

## Open questions — all resolved or moved to v2 backlog

(Interaction mechanics, level transitions, connection gestures, engine
architecture — all answered in `docs/interaction-design.md` and built.
Remaining deferred work is listed in `plan/phase-5/integration.md`.)

## Decisions log (chronological)

- 2026-09-24: Research → `docs/behavior-spec.md` (incl. §7 gap list, 20 items).
  Norns facts: no native dashed lines or screen.scale → hand-rolled grid +
  own world→screen transform; CroneEngine + bus dictionary is the pattern.
- 2026-09-24: **Interaction design APPROVED (v2)** — E1 CW = zoom in; LINK
  target = cycle by proximity; subtype = K1+E2; v1 scope = core 8 types;
  v1 panels = envelope + 2D.
- 2026-09-24: **Phase 1** — dev loop working (deploy/load/screenshot).
  Matron REPL: ws :5555, plain-text Lua, newline-terminated (norns#1084).
- 2026-09-24: **Phase 2** — renderer verified (glyphs, proximity connections).
- 2026-09-24: **Phase 3** — interaction hierarchy verified on device.
- 2026-09-25: **Key map v3 (owner)** — K1 tap = system menu; K2 = BACK;
  K3 = action; K1+K3 = shifted; K1+K2 = remove. Lesson: verify multi-step
  REPL flows as ONE Lua chunk (matron reorders rapid separate messages).
- 2026-09-25: **Phase 4 engine verified** — Engine_Rotatable + audio.lua glue;
  poll-verified signal flow. Engine lessons in AGENTS.md gotchas.
- 2026-09-25: Filter "no effect" = sine single-partial perception; engine fine.
- 2026-09-25: **REST testing API** (owner idea) — `tools/api.py`.
- 2026-09-25: **Panels + loop player fixed** — step editor + sample browser;
  `load`→`loadbuf` (Engine.load collision, "missing N"); Phasor+BufRd +
  silentBuf. Effect-chain rule fixed (effects connect toward output point).
- 2026-09-25: **Patch slots (owner feature)** — 8-slot ring at r=1.18;
  long-press K3 = store/delete, short = recall. 40 drum one-shots pulled from
  archive.org into `dust/audio/rotatable-drums/`.
- 2026-09-25: **v2 plan drafted** — phases 6–9: design decisions first (sampler/SF2 problem, tonality reach, tempo-sync architecture, LFO scaling), then engine v2, UI/panels v2, release v2.0.0. Same methodology as v1: decisions phase before code.
- 2026-09-25: **Published** — repo restructured to community layout (script at root), v1.0.0 pushed + tagged to github.com/wildseyed/rotatable; script header points to lines thread llllllll.co/t/75521; catalog PR opened: monome/norns-community#409. `.gitignore` shields `.device/` + `reference/`.
- 2026-09-25: **Lean release branch (owner)** — verified no secrets ever tracked (password/IP only in gitignored `.device/`). Dev files live on `main`; default branch is orphan `release` with only rotatable.lua, lib/, README.md, .gitignore — that's what `;install` clones. (Published + this entry were lost in the orphan checkout and are restored here.)
- 2026-09-25: **Scope-sensitive delete (owner request)** — K1+K2 in L2 removes selected block (existed); K1+K2 at L1 arms table-clear with status-line confirm (K3 yes / K2 no). Verified: arm/cancel/confirm. Rejected: trash icons (screen cost), extra nav layer (complexity), long-press (slot conflict). Future option: drag-off-rim removal. Multi-circuit demo patch (3 independent chains) saved to slot 1.
- 2026-09-25: **E1 object-hop in MOVE mode (owner feature)** — cycles selection through objects, centering the camera on each; status hint "E1 hop". Verified: hop cycles all objects both directions, camera follows. Also: REST API completed with `/set /load /step` direct-manipulation endpoints; `tools/djset.py` + `tools/seqjam.py` performance scripts exist (lessons: discover fresh ids from /state, deploy-reload wipes table).
- 2026-09-25: **Phase 5 polish done** — CPU avg 16%/peak 17%; overlap fixes;
  README.md. v1 complete pending owner feel-check.
- 2026-09-26: **Phase 2 backlog cleared** — label collision avoidance landed
  (labels queue per frame in `lib/render.lua`, selected object's label draws
  first, overlapping labels skipped; verified on device via REST API scenes).
  Output-point cap turned out already satisfied (`clamp(0.03*zoom, 2, 5)` in
  `draw_output`) — confirmed at max zoom 480 with a screenshot. Removed the
  now-done label item from the phase-5/phase-8 backlogs.
- 2026-09-26: **Phase 6 done — v2 decisions all owner-approved** → recorded in
  `docs/behavior-spec.md` §9. Headlines: sampler = single-sample melodic (no
  SF2); song-settings object dropped; waveshaper all 3 subtypes; tonality =
  spec-faithful set (seq/random/sampler/subosc, osc rotation free); tempo
  sync = hybrid engine tempo bus + Lua metro sequencer; sequencer = 6 presets
  + random (poly deferred); pitchlock loop OUT; v2 ships 13 of the original
  14 types. Phase-7/8/9 plan files aligned.
- 2026-09-26: **Phase 7 done — engine v2 verified on device.** Tempo control
  bus (`engine.tempo`), LFO tempo-sync + bipolar per-target mod scaling,
  delay pingpong/reverb/quantize/sweep, loop oneshot, waveshaper, audio-in,
  melodic sampler (instrument/drum), tonality quantizer (`lib/tonality.lua`),
  loop bar-entry sync, 16-slot per-object level-poll pool. All 13 types in
  `World.TYPES`. CPU with full 13-object patch: avg 23.3% / peak 24.1%.
  Big gotcha: `t_` trigger args hoist to the FRONT of the control list —
  index-based probing lies; PlayBuf+t_trig won over Changed/Sweep edge
  hacks after a long trigger-debug saga (see plan/phase-7 for the rest).
- 2026-09-27: **8 patch slots populated + two routing bugs fixed.** Slots:
  1 KIT-808 (3 drum samplers + 3 sequencers), 2 ACID (saw+LP+minor tonality
  +synced LFO), 3 DUB (looped kick + synced feedback delay), 4 PING (rim
  sampler + pingpong delay + sequencer), 5 SOLO (random sequencer + square
  +pentatonic tonality), 6 CRUSH (snare loop + resampler + HP + random LFO),
  7 WASH (line-in + compressor + reverb; silent without external signal),
  8 CHOIR (2 detuned sines + chorus + reverb + slow vibrato LFO). Slot
  persistence itself was never broken (tab.save roundtrip + reload verified)
  — but populating exposed: (a) phase-7 regression `in=nil` on all effect
  synths (bus allocated after args array), (b) World.add internal recompute
  racing `Audio.on_add` so routes to newly-added objects never reached the
  engine (mirror lied). Both fixed (AGENTS.md gotchas 9-11). Also: T.link
  (hardlink) + T.load now sets o.sample for slot persistence.
- 2026-09-27: **SYSTEM master menu + factory presets (phase 8 start)** — plan:
  `plan/phase-8/system-menu.md`. Hold K1+K2+K3 for 1 s → SYSTEM overlay
  (E2 scroll, K3 select, K2 close); first entries RESTORE PRESETS
  (overwrite-with-confirm) + ABOUT. `Slots.restore_factory()` rewrites
  absolute sample paths to bundled `presets/audio/`. README documents the
  gesture + the 8 factory patches. Device-verified 2026-09-27 evening:
  gesture, cancel, restore (deleted 7.lua came back), recall from bundled
  sample path, gesture regressions all pass. Committed 680f2fa.
  Follow-up bug: gesture timer armed only on K2/K3 events — physical K1-last
  presses never fired it (scripted tests always sent K1 first). Fixed +
  owner-verified on hardware (5cd47fe).
- 2026-09-27: **Phase 8 batch 1 done — sync & sample gaps, device-verified.**
  New shared L3 "set" page (`lib/ui.lua`): per-type fields — LFO sync on/off
  + mult (32nd-note period), delay sync (32nd quantize) + sweep (time glide),
  loop sync immediate/quarter/bar, sampler base pitch (semitones from C4,
  shown as note name + Hz). Sampler gets the sample browser (pages_for gate
  now loop+sampler; load path was already generic). Steps editor pitch now
  ±24 (was ±12; T.step already allowed it). README: subtype-cycling callout,
  set-page docs, browser/steps fixes. Verified via REST harness +
  screenshots: all four pages render/edit correctly, engine pushes flow
  through PASS_PARAMS, sampler loads 606 wavs from dust/audio, osc→output
  amp check OK, ACID factory slot recalls clean.
- 2026-09-27: **Subtype cycling from L3 config pages** (owner-reported gap:
  no way off sine while editing the envelope). `K1+E2` now cycles subtypes
  on every L3 page, same as in ROTATE — header already shows the subtype
  name. Device-verified: full cycle saw→square→noise→sine→saw both
  directions from the env page. OSC gap audit vs spec §3.1: rotation still
  doesn't retrigger the amplitude envelope (seq-only), no semitone/octave
  glyph display, suboscillators blocked on SynthDef work, user-drawn
  waveform parked.
- 2026-09-27: **Subtype pictograms on glyphs** (owner request: reactable-style
  mode display on the blocks). `lib/render.lua`: `sub_mark()` draws a small
  per-subtype vector mark on the player-facing rim (0.68r along the rotation
  angle, orbits with the block); rotation tick shortened to a 0.35r center
  stub so the two don't collide. Marks for osc/lfo (sine/saw/square/noise),
  loop (ring/play triangle), sampler (note/X), filter (lp/bp/hp slopes),
  delay (arc/two dots/concentric arcs), modulator (ring+dot/twin arcs/X),
  waveshaper (staircase/</>/jagged), sequencer (dot row/grid/scatter);
  input/tonality/output unmarked. Shown when glyph r >= 3.5px (zoom ~44+);
  selected block's label now includes the subtype name. Device-verified with
  a 6-type matrix at multiple zooms. Test gotcha re-confirmed: T.clear()
  doesn't reset next_id — always read ids from /state (two silent no-op
  /set rounds before catching it).
- 2026-09-27: **Phase 8 batch 2 done — sequencer depth, device-verified.**
  6 rotation-switched preset patterns per sequencer (`o.patterns[1..6]`,
  `World.seq_steps`; p1 = penta default, 2-6 blank). Root cause of the old
  "inert preset param": `Audio.sync_object` returned early for synth-less
  types, so rotation never even wrote `o.params.preset` — fixed for
  sequencer + tonality. New L3 pages `vel` + `dur` (steps/vel/dur/env);
  `dur` = per-step length in 32nds (1-8; 2 = old 16th timing) — seq metro
  moved to a 32nd clock, each sequencer free-runs position + countdown
  (`o._pos`/`o._left`). Random subtype: steps page shows improvised-note
  history (`o._hist` per step slot), E3 = velocity there. Slots persist
  `patterns`; v1 `steps` files migrate into pattern 1 (factory presets
  unaffected — KIT-808 recall verified, drums firing). T.step takes `dur`;
  T.seq_state(id) harness getter; api.py /step passes dur. Verified:
  preset isolation (edited p3, p1 intact), dur timing (dur 8 = 2 steps/s
  vs 8 steps/s at dur 2 @120bpm), random history display, slot roundtrip,
  SYSTEM-gesture factory restore. Gotcha x3: T.clear() doesn't reset
  next_id — read ids from /state EVERY time.
- 2026-09-27: **Phase 8 batch 3 done — MIDI-in + visual polish,
  device-verified. Phase 8 feature batches complete.** MIDI-in is the 13th
  type: controller category (proximity control-connect for free), rotation
  = transpose ±24 st, `rot_midi_dev`/`rot_midi_ch` params, note_on triggers
  the control target like a seq note (velocity→amp), note-off releases the
  gate. TWO routing bugs found by testing: midi connections never entered
  `desired` in Audio.sync_connections (guard listed only sequencer), and
  the memo-build elseif was unreachable because the first branch's
  `n.type ~= "sequencer"` guard swallowed midi nodes doing nothing. Verified
  via T.midi_note: gate on/off now audible (note-off → silence).
  Polish: output point pulses at tempo (beat = 8×32nd ticks); audio conns
  = dim base + bright dashes marching toward destination (20 px/s), control
  dots march too; LINK ring glyph-sized (was fixed 10px circle); VU bars
  under sounding glyphs from the lvl_N poll pool (16 lua polls @0.12s,
  sqrt-scaled). **Redraw is now unconditional at 15fps** (animation needs
  frames; the dirty-flag optimization is gone — CPU impact unchecked,
  phase 9 perf pass must measure). Place menu scroll-verified with all 13
  types. Real MIDI hardware test still pending with owner.
- 2026-09-27: **Env page gated to osc/loop/sampler + two owner decisions.**
  The env page was dead UI on effects/controllers (sync_object only pushes
  ADSR for osc/loop/sampler). Owner call: gate it (effect envelopes = future
  engine work, scope with the subosc session). Page-less types
  (input/midi/tonality/output) now skip L3 entirely; status shows `^K3 --`.
  Also decided: osc rotation does NOT retrigger the envelope (continuous
  sweeps would stutter) — spec §9.13/14. Device-verified: filter L3 = 2d
  only, input blocked, osc keeps env.
- 2026-09-27: **Phase 9 partial: e2e suite + CM3 perf pass, plus three real
  bugs found by testing.** `tools/e2e.py` (REST, all 13 types: connections,
  sync params, sample load, seq presets/dur/random, midi note gate,
  hardlink/mute, UI nav, slot roundtrip + factory restore) — all green.
  Bugs it flushed out: (a) output object at angle 0 zeroes master volume
  and it STICKS after removal → `Audio.reset` now restores volume 0.8;
  (b) no `cleanup()` in rotatable.lua → every script reload left orphan
  engine synths droning (also diverged the lvl-pool mirror) → cleanup()
  calls Audio.reset(); (c) test-infra: matron ws REPL gives no `<ok>`
  sentinel for value-returning evals → every API call burned the full 8 s
  timeout; ws_run early-exits on `<ok>` and api.py appends
  `; print("<ok>")` — calls now ~20 ms (was 8 s). Perf (scsynth): idle
  11.8/12.8%, worst-case 14-object patch avg 22.6% / peak 23.3% — batch-3
  redraw+polls cost nothing measurable. Slot-format decision recorded:
  v1 backward-compat kept (steps → pattern 1 migration).
- 2026-09-28: **v2.0.0 RELEASED.** Version bump (rotatable.lua + README),
  what's-new section, 3 fresh press shots (table-wide, chain-detail,
  panel-steps). Release branch now bundles `presets/` (factory presets
  postdate the lean-branch doc; AGENTS.md updated) — also fixed a latent
  gap: release was missing `lib/tonality.lua`. Tagged v2.0.0, pushed
  main+release+tag. Catalog PR #409 checked: fields still accurate, no
  update; still open upstream. Announcement drafts in session reply.
  Next: subosc/tonality design session (owner queue).
- 2026-09-28: **Suboscillators + tonality note editing (post-v2.0.0,
  owner-directed).** Engine: `rot_osc` grew 4 subs × (wave/amp/det-cents/
  off-semitones), summed pre-envelope — required the full jack/sclang/crone/
  matron restart (paramiko). Lua: `o.subs` per osc + `subs` L3 page (follow
  toggle + 16 fields); follow=1 lua-snaps sub pitch to the scale mask before
  pushing. Tonality: per-object editable 12-degree mask `o.notes`
  (subtype cycle = preset reload, documented reset), `notes` L3 page;
  `Tonality.current` reads the mask. Slots persist subs+notes (old slots
  default cleanly). **Big test-harness bug found: `T.enc`/`T.key` bypassed
  rotatable's global enc/key handlers, so UI-driven edits in tests NEVER
  called Audio.sync_object** — physical encoders were always fine; the
  harness now routes through the real handlers. This invalidated earlier
  "UI pushes verified" assumptions; re-verified subs via lvl-poll max-reads
  (0.55 → 1.08). Also learned: single amp reads are useless for A/B when
  signals are phase-locked (beat interference) — sample max over ~1 s.
  Verified: subs page edits audible, notes page mask trim to degree-7-only
  snaps random seq to 3 discrete heights, e2e all green.
- 2026-09-28: **Effect envelopes done** (last big original-feature gap).
  Engine: rot_filter/delay/mod/shaper grew gate+ADSR; filter env ×2^(env·3)
  on cutoff, delay env swells feedback toward 0.99, mod/shaper env swells
  dry-wet toward 1 — all idle-neutral at env=0 (effects get percussive
  default a=0.01 d=0.4 s=0; generators keep s=0.7). Sequencer + MIDI notes
  retrigger effect envs (bare gate edge, no pitch/amp side-effects).
  Slots migrate inert s=0.7 effect envs to s=0 (pre-v2.1 the env page did
  nothing on effects, so 0.7 is provably never deliberate). Env page back
  on for effects with a target-name footer. Verified via per-synth lvl
  polls: filter lvl oscillates with the seq trigger (cutoff sweeping the
  saw's harmonics), delay lvl swells per step. GOTCHA SELF-OWN: spent an
  hour "proving" the new def wasn't loading via master amp polls — they
  were lying (beat/poll artifacts, gotcha 12 lesson); the per-synth lvl
  poll showed it working all along. e2e all green. Spec §9.13 updated.
- 2026-09-28: **V3 planned** → `plan/phase-10/v3.md`. Owner identified the
  remaining gaps: tempo as a table object (Song Settings), global FX on
  output (reverb+compression, spec §3.13), and THE SLIDER — the Reactable's
  second per-block control (right-side dot, finger-dragged). E3 already
  drives the slider param in ROTATE for all types (spec-faithful mapping);
  V3's real work is the persistent on-block slider visual + feel, plus the
  tempo object and the master FX stage. 3 owner questions open (slider
  visual style, tempo object vs page, no-output-object FX behavior).
- 2026-09-28: **V3 batch 1 done — the slider.** Owner answers: settings
  belong on-table (Q3 → neutral without output object); Q1/Q2 spec-
  faithful defaults (radial dot, dedicated tempo object). `World.
  SLIDER_PARAM` explicit map — audit caught a live bug: LFO E3 fell
  through to params_2d → "drywet" (nonexistent), so LFO depth had NO
  control anywhere; now depth. Slider visual: dot at rotation+90°,
  radial distance 0.3..0.8r = value (orbits with the block, spec's
  right-side dot), track line at r≥6. K1+E3 fine adjust (0.2× step).
  Verified: dot positions track values (0.2 inner / 0.55 mid / 0.9
  outer), K1+E2 subtype unaffected, e2e green.
- 2026-09-28: **V3 batch 2 done — tempo object.** 14th type `tempo`
  (GLOBALS, star glyph, label = live BPM). Rotation drives the
  `rot_tempo` param (still the single source of truth — its action fans
  out to metro + engine tempo bus). Placement ADOPTS the current bpm
  (angle initialized from the param) — first version reset BPM to 40 on
  placement, caught in testing. Page-less (^K3 `--`); slots unchanged
  (tempo already persisted). e2e green. This closes the Song Settings
  gap (§9.4 stands: patch selector = slots, background N/A).
