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
- 2026-09-28: **V3 batch 3 done — global FX on output + a nasty engine
  bug found.** rot_out master stage: FreeVerb (rev/room) + Compander
  (comp), neutral defaults; output object gets rev/room/comp params +
  shared set-page (gfx). Output object now ADOPTS master volume on place
  (angle from a lua-tracked master_vol — placing one no longer silences
  the table; slots recall re-asserts saved angle after). THE BUG: engine
  `set` command hardcoded `master.set(\volume, msg[3])` for output nodes
  — every rev/room/comp push overwrote volume (comp=0 → silence). It
  retrospectively explains the whole "master keeps dying, remaster fixes
  it" saga (remaster just restored default volume 0.8). Fixed to named
  set. init's engine.remaster() kept as belt-and-braces anyway. CPU:
  15-obj worst case + FX engaged avg 30.0% / peak 30.7% (was 22.6/23.3)
  — ~7 points for the always-on stage; AT the plan threshold, flagged
  for owner. e2e green.
- 2026-09-28: **v3.0.0 RELEASED** (main f2f28c7, release a193530, tag
  v3.0.0 — first push hit a transient GitHub 500, retry landed). v3 =
  slider (dot + LFO depth fix + fine adjust), tempo object, global FX,
  plus the post-v2 work (subosc, tonality notes, effect envelopes).
  e2e extended with a v3 section (tempo adopt/rotation, output adopt,
  reverb tail), all green ×3. Press: refreshed table-wide, new panel-gfx.
  Announcement drafts delivered in session reply. Parking lot stands:
  poly tenori grid, waveform draw, grid/arc controllers, feel-check
  (real MIDI hardware especially).
- 2026-09-28: **Combo detection window for staggered physical presses**
  (feedback from the NDI-viewer agent: physical K1+K3 always staggers; if
  K3 lands first the solo action fired before K1 arrived and the combo was
  lost). Solo-K3 actions are now deferred by a 120ms window: a quick tap
  fires on release (feels instant), a held press fires on window expiry in
  UI.tick, and a K1 arriving inside the window cancels the pending solo
  and fires the ^K3 combo instead. K1-first path and SYSTEM gesture
  unchanged (master_check also clears the pending). Required some lexical-
  order surgery in ui.lua (fire_k3_combo/fire_k3_solo extracted before
  UI.tick; cycle_mode forward-declared). Verified all four paths on
  device: K1-first, K3-first (60ms stagger -> place menu, no stray
  select), solo tap, held solo; e2e all green. The viewer's atomic
  two-key messages + 250ms min hold were already compatible.
- 2026-09-29: **v3.0.1 bugfix pack** (external review triage, archived to
  `prompt-archive/2026-09-28_extern-review-gaps.md`). Six fixes, all
  device-verified: (1) sampler gate re-raised on trigger — instrument
  mode no longer dies after a MIDI note-off; (2) tonality snaps the
  ABSOLUTE note (`Tonality.snap_abs`) in seq_tick + subs follow — was
  scale-shaped intervals in no key; probe-verified 300 Hz -> D4 293.66;
  (3) hardlink effect-cycle guard (A<->B silence) — hardlinks must
  respect flow direction; (4) reverb rotation = room size (new `room`
  arg/param; feedback = mix), tail tracks room; (5) World.remove
  hardlink cleanup (broken Lua pattern); (6) MIDI legato — held-note
  stack, gate closes only when the last note releases. Deeper items
  deferred to v3.1: norns-clock unification (MIDI clock/Link/crow),
  dur-as-gate-length, generator outward-audio guard, controller target
  filtering. Side quest: one script instance had a frozen seq metro
  after the restart — unreproducible transient; metros die silently on
  callback errors, worth remembering when pos freezes.
- 2026-09-28: **Sample library expansion** (prep for the 16-preset
  re-authoring, plan/phase-11). 26 new WAVs in `presets/audio/`, all 44.1k
  mono 16-bit, peak-normalized: `drums/` = 8 SoX-synthesized 808-style
  voices (kick/snare/clap/chh/ohh/tom/cowbell/clave; CC0 — archive.org's
  raw-WAV drum packs were either 5 GB monoliths, murky licenses, or .sf2
  soundfonts, so we rolled our own); `instruments/` = 9 BBC Philharmonia
  single notes (CC BY 2.5, archive.org `orchestral_samples` — RARs needed
  the rarlab `unrar` static binary; numbered files, pitches recovered by
  autocorrelation and baked into filenames) + a theremin from Berklee/OLPC
  (CC BY 3.0); `animals/` = 8 Red Library clips (CC0, loudest-4s window).
  Full provenance in `presets/audio/SOURCES.md` (ships on release for the
  CC-BY attributions). Authoring note: push the same tree to
  `~/dust/audio/rotatable-drums/` on device so saved slot paths match the
  `restore_factory` rewrite prefix.
- 2026-09-28: **Phase 11 — 16 factory presets, built and verified on
  device.** `Slots.N` 8 -> 16 (ring geometry count-driven; ui.lua texts +
  ABOUT now derive from N). New harness helpers `T.sub` / `T.notes` /
  `T.restore_factory` (subs, tonality masks and restore weren't reachable
  via `T.set`). `tools/presets.py`: scripted builders for all 16 tables
  (angle = source of truth for primary params — the `a_*` helpers invert
  `audio.lua primary()`; controllers must sit within CONNECT_DIST 0.35 or
  be hardlinked; effect chains need <=0.35 hops toward center; >0.7 from
  center = no output fallback). Every slot verified post-recall:
  connection counts, muted-link survival (KIT-808), subs/notes persistence,
  sample-path rewrite via a real RESTORE PRESETS pass, FINALE CPU 11.5%
  avg / 13.4% peak (15 objects + master FX — far under the 30% threshold).
  **Sample gotcha found:** BBC/Berklee sources have 0.1-0.6 s lead-in
  silence; gated short notes only ever played the quiet intro (SOLO read
  0.005 peak). All 10 instrument WAVs re-trimmed at detected onsets —
  worth remembering for any future sample ingestion (trim at onset, not at
  file start). SOLO stays the mellow one by design (random seq + smooth
  theremin), boosted to amp 1.0.
- 2026-09-29: **Frozen sequencer clock, round 2 — now hardened.** Owner
  found presets 1–6 not sequencing. Live probe: seq `pos=0`, clock never
  ticked; a script reload cured it — same transient as 2026-09-28's
  frozen seq metro, now seen twice. Post-mortem was inconclusive (journal
  showed no rotatable lua error for that session; recall path verified
  clean all 16 ways), so the clock is now bulletproof instead of
  mysterious: seq metro callback is pcall-wrapped (errors print,
  rate-limited: first 3 then every 100th), and a 1 s watchdog metro
  restarts `seq_metro` if it ever shows stopped (verified live:
  `seq_metro:stop()` -> watchdog recovered in <2 s). New harness probe
  `T.health()` -> tick counter, running flag, tick error count,
  world-vs-nodes sequencer counts — use it FIRST if sequencing ever looks
  dead again. `Audio.count_type` added for the mirror count.
- 2026-09-29 (later): **The real killer found — per-includer include()
  copies.** Round 2 of "no sequence execution": the clock was healthy this
  time (T.health: tick advancing, 0 errors), but `node_seqs=43` vs
  `world_seqs=1` and scsclang journal spammed `JackDriver: alloc failed`
  (RT memory exhausted). Root cause: norns `include()` does NOT cache —
  ui.lua's `include('lib/audio')` creates a SECOND Audio instance with its
  own empty `nodes` mirror. `UI.init` then ran `Slots.init(World, Audio)`
  wiring ui's Slots copy to ui's Audio copy, so every PHYSICAL slot recall
  or table clear ran the wrong `Audio.reset()` — harness recalls
  (T.recall_slot, my whole phase-11 verification) used rotatable's own
  copies and were clean, which is why device tests never saw it. Engine
  nodes accumulated (~200 adds, 0 frees) until scsynth wedged silent.
  Fix: singleton guards — audio.lua/slots.lua early-return globals
  (`RotatableAudio`/`RotatableSlots`). Verified: polluted the mirror, then
  recalled through the ui-visible singleton table — mirror cleared to match
  the world exactly; 32-recall storm clean, no alloc failures since the
  stack restart. Yesterday's pos=0 incident was likely a genuinely dead
  metro (separate failure, now pcall+watchdogged); today's was this wedge.
  Same symptom, two causes — both now hardened. AGENTS.md gotcha 13 added.
- 2026-09-29 (later still): **K1+E1 slot focus** (owner request): at L1,
  K1+E1 walks a slot focus across occupied slots without loading; K3 then
  acts on the focused slot (tap = recall, long = delete) regardless of
  reticle. Status line shows `SLOT n  ^E1 move | K3 load`; ring highlight
  follows focus via UI.slot_candidate. Focus dismisses on any plain camera
  move (E1/E2/E3), place menu, SYSTEM gesture, table clear, or deleting
  the focused slot; survives a recall (A/B switching). Gotcha while
  testing: K1 must be released before the K3 tap or you get the place
  menu (K1+K3) — same as physical. Verified on device via harness-driven
  gestures: focus walk, focused recall (slots 3/1), dismiss, focused
  delete + restore. Also fixed the stale "8 numbered slots" README line.
- 2026-09-29 (evening): **K1+E1 camera coupling** (owner correction): the
  point of slot focus was to NAVIGATE to each preset — focus alone wasn't
  visible enough. K1+E1 now also sets `cam_target` to the focused slot, so
  the existing hop-easing flies the camera and centers the slot on screen;
  plain E1 (zoom) now also cancels a camera flight, matching E2/E3.
  Verified: camera converges exactly onto Slots.pos(focus), K3 loads the
  centered slot, screenshot shows the focused slot under the reticle.
- 2026-09-29 (docs pass): README gained a per-block **settings guide**
  (replaces the terse config-panels list; universal L2/L3 gesture summary
  up top, then per-block rotation/slider/subtypes + every panel's fields)
  and a **guided tour** under the preset table (per-preset "try this").
  No device verification — norns offline; docs-only. **Suspected bug
  found while documenting:** the L3 "2d" page edits params with a 0..1
  clamp (ui.lua params_2d + the 2d enc branch), but filter cutoff is in
  Hz (40..12000) and delay time in seconds (0.01..2) — first 2d touch on
  a filter slams cutoff to <=1 Hz. modulator/waveshaper (main/drywet are
  0..1) are fine. NOT fixed (no device to verify); candidate fix: give
  params_2d per-param min/max/step like SET_FIELDS. Verify on device, then
  fix.
- 2026-09-29 (handoff): **for the next session (other PC, norns attached)**:
  verify-on-device queue: (1) suspected 2d-page param clamp bug (two notes
  up) — open a filter's 2d page and touch E2; (2) owner listening check of
  all 16 presets (only amp-meter verified so far) + K1+E1 focus-flight feel;
  (3) decide v3.1.0: release branch is still v3.0.1 — everything since
  (16 presets, sample library, metro hardening, include-leak fix, K1+E1,
  docs) is main-only. tools/presets.py rebuilds any preset via the REST
  harness (`python3 tools/presets.py N`, `--pull` fetches slots back).
- 2026-09-29 (other-PC session): **2d-page bug confirmed by owner** (E2
  pinned the cursor at the right edge) and fixed blind: the page clamped
  raw params to 0..1 (cutoff is Hz!), and worse, primary params are
  angle-driven — direct param edits get stomped by the next sync_object.
  Fix: 2d axes that ARE the block's primary param now edit/display via
  the angle (`norm_2d`/`edit_2d` in ui.lua, `Audio.primary_key` exported);
  non-primary axes keep direct param edits, with a real 0.01..2 range for
  delay time (reverb subtype, where rotation drives room). PENDING DEVICE
  VERIFICATION on the other PC: pull, `python3 tools/deploy.py --load`,
  filter 2d page — E2 should sweep cutoff and move the cursor both ways.
- 2026-09-29: **2d-panel fix owner-verified on device; v3.1.0 released**
  (main + release branch, tag v3.1.0). Ships: 16 factory presets + sample
  library, K1+E1 preset navigation with camera flight, seq-clock
  pcall+watchdog, include()-singleton engine-leak fix, 2d-panel angle
  mapping, README settings guide + preset tour.
- 2026-09-29: **slot boxes world-scaled + MOVE camera follow** (owner
  requests). (1) Slot boxes were a constant 4 px screen radius — invisible
  specks when zoomed in. Now `Slots.DRAW_R = 0.08` world units with the
  same clamp as blocks (`render.lua` GLYPH_R formula): they grow with
  zoom. Hit detection unchanged (`nearest_slot` uses a constant 25 px
  screen radius, which still covers the max 14 px box). (2) MOVE glide
  moved the block but never the camera, so blocks glided off screen.
  `UI.tick` now pins the camera to the block while gliding
  (`cam.x, cam.y = nx, ny`, clears `cam_target`); E1 hops still ease via
  `cam_target` since they reset move physics first.
- 2026-09-29: **v3.2.0 released** (main + release branch, tag v3.2.0).
  Ships: world-scaled slot boxes + MOVE camera follow. Device checksum-
  verified against the tag. Note: matron segfaulted once (signal 11 in
  ndi-script-post-init) on the post-deploy reload — did not recur after
  `systemctl restart norns-matron` + reload; one-off, but watch ndi-mod.
- 2026-09-29: **preset 12 replaced: DUB → STACK** (owner request, multi-osc
  patch). Three oscillators (saw 110 Hz + square 110.8 Hz beating detune +
  sine 55 Hz sub-bass), each with sub-oscillators following an A-minor
  tonality, all stacked into one LP filter; slow free-running LFO (0.15 Hz)
  hardlinked to the filter for cutoff drift (osc3 is nearer to the LFO —
  hardlink wins over proximity). No tempo object (no sequencers/synced
  modulation). Builder rewritten in tools/presets.py b12; built on device,
  saved to data slot 12, pulled back to presets/slots/12.lua, and copied
  over the code-dir factory file so RESTORE PRESETS yields STACK. Recall
  path verified end-to-end (amps ~0.37). README table/tour/loop-tip
  updated. Release branch NOT synced (preset content changed since v3.2.0).
- 2026-09-29: **preset 12 revised → DRIFT** (owner: "ethereal movement among
  the oscs + random seq into filter controls"). Both are engine-supported:
  LFO→osc mod bus = pitch drift (per-osc sine LFOs, 0.09/0.13 Hz, depth
  0.15/0.12); sequencer→effect = bare gate retrigger of the effect's param
  ADSR (random subtype, sparse gates → filter env sweeps cutoff ×8,
  a=0.3 d=1.5). Space now from a reverb-delay insert (subtype 3, mix 0.45,
  room 0.7) instead of chorus — see bug below. Levels tuned: peak ~0.45
  on recall (was 0.087 with chorus, 0.37 for STACK). tempo 60 bpm.
- 2026-09-29: **SUSPECTED ENGINE BUG: modulator (chorus) as insert kills
  the chain**. Evidence (device, DRIFT build): filter→output direct peaks
  0.31; filter→chorus(dw 0.4)→output peaks 0.086; chorus dw=0 (should be
  pure dry!) peaks 0.0016 — yet dw=1 peaks 0.177. Node lvl polls show hot
  signal inside the chain (0.77/0.50/0.19) while master reads 0.086, so
  the loss is at the chorus→output hop or in rot_mod's dry path, not the
  sources. The dw=0-silent vs dw=1-audible pair is paradoxical from the
  SynthDef alone (wet derives from dry) — smells like a bus/order issue
  (gotchas 2/9 territory) rather than the mix math. CHOIR/SOLO also use
  chorus inserts — worth re-measuring. NOT fixed; DRIFT avoids chorus.
  Repro: build chain osc→filter→modulator(chorus)→output, measure
  T.amps() at drywet 0 / 0.4 / 1.
- 2026-09-29: **ENGINE BUG FOUND + FIXED: SC operator precedence killed
  effect dry paths**. rot_mod + rot_shaper mixed with
  `wet = (dry * (1 - dw) + wet * dw) * amp` — but SuperCollider binary ops
  are LEFT-ASSOCIATIVE with no precedence, so this parses as
  `(((dry * (1 - dw)) + wet) * dw)`: at drywet=0 the whole synth goes
  EXACTLY silent (any dw multiplies everything), and mixes were wet-
  dominant at all settings. Every chorus/ring/flanger and shaper insert
  ran degraded since the param-envelope change introduced the line
  (CHOIR/SOLO/CRUSH presets were all quieter than designed). Found via
  /g_queryTree + raw-OSC probes (routing verified good, all args correct,
  yet dry=0 in a fresh instance — the code "couldn't" be running, until
  the precedence read). Fix: explicit parens in both lines, deployed,
  full stack restart, verified: ring/chorus dw=0 now passes dry at full
  level. Diagnostic tooling left on device: /tmp/querytree.py
  (/g_queryTree via OSC 57110), /tmp/probe2.py (raw /s_new probes +
  /c_get). CAVEAT for future backups: a copy of the script dir inside
  dust/code (rotatable.bak-*) makes sclang fail the whole class library
  with "duplicate Class found: 'Engine_Rotatable'" — backups must live
  OUTSIDE dust/code (moved to ~/rotatable.bak-20260929).
