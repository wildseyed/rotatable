# Phase 12 — Reactable fidelity gap closure

Source: `docs/gap-analysis-2026-10-10.md` (verified). Priority order per the
doc's revised list; owner triage 2026-10-10. Each item: implement, then
verify on device (REST harness `tools/api.py` + amp/state reads; screenshots
for visuals). Items marked **[owner call]** need a design decision first —
do not implement before that.

## Done

- [x] **Slider as perimeter arc gauge** (§9 MISALIGN; owner decision
      2026-10-10) — `lib/render.lua`: value = arc sweep around the glyph,
      anchored at rotation+90°, dot at tip; VU bar moved out to r+5.
      **Device-verified 2026-10-10** (screenshots at NAV + ROTATE levels;
      bright sweep + tip dot legible, dim track at r≥6).

## Queue (priority order)

- [x] **1. Placement/rotation triggers** (§8) — fixes genuinely silent
      objects. **DONE 2026-10-10, device-verified** (spec §9 decision 15):
      engine `loadbuf` fires t_trig+gate after the buffer swap (sampler +
      loop); sampler rotation retrigs via `Audio.rotate` (enc handler
      detects angle change; T.rot/T.set angle use it too).
  - [x] sampler: fire `t_trig` on load (`loadbuf` action — placement is
        silent-buf anyway; the load IS the meaningful placement trigger)
  - [x] oneshot loop: fire `t_trig` on load (standalone oneshot sounded
        for the first time: amp 0.21 on birds.wav)
  - [x] sampler: rotation triggers a note (sampler.md:3) — per-detent
        retrig; oscillator untouched (decision 14)
  - [x] device-verify: sampler load 0.005–0.05, rotation 0.05 (enc) /
        0.59 (T.rot), oneshot loop 0.21, loop-mode restart 0.075 (regression ok)

- [x] **2. Sequencer note → effect main parameter** (§4) — **DONE
      2026-10-11, device-verified**:
  - [x] engine `trigger`: msg[2] (midi note, 60=center) → `\main` for
        waveshaper (linlin 36..84→0..1), `\time` for delay (linexp
        36..84→0.01..2s); 0 = bare retrig. Filter/modulator: env only
        (manual silent)
  - [x] `Audio.seq_tick` effect branch sends 60+pitch (random subtype
        improvises); `midi_note` sends transposed note number
  - [x] velocity → envelope depth: new `vel` arg on all four effect
        synths scales the ADSR output; seq_tick/midi_note set it per note
  - [x] device-verify: vel 1.0 vs 0.1 on filter env = 0.47 vs 0.05;
        shaper main via note 36/84 = mean amp 0.33/0.74 (distortion);
        delay time via midi note 36/84 clearly audible (0.41 vs 1.51)
- [x] **3. Sequencer → loop envelope** (§5): loop added to `SEQ_TARGETS`;
      oneshot loops retrig per step (verified: 0.47). NOTE: full loop
      *amplitude envelope* per the manual needs an ADSR in `rot_loop`
      (currently none) — deferred.

- **Latent bug found & fixed during verification (2026-10-11): effect/osc
  envelopes NEVER retriggered.** The trigger command's `set(\gate, -1);
  set(\gate, 1)` pair lands in the same scsynth control period — EnvGen
  never sees the edge. Went unnoticed because generators drone at s>0
  anyway. Fix: `t_retrig` TrigControl arg (auto-resets each control
  period); env gate = `gate * (1 - t_retrig)`. Applied to rot_osc +
  all four effects; sampler/loop already used t_trig. Verified: separated
  edges fired (0.39), same-block pair didn't (0.036) → after fix seq
  retrigs land every 16th.
- **Quirk flagged (not fixed):** `mod=0` at rest HALVES drywet on
  modulator/shaper (`dw0 = drywet * (1 - (mod*0.5+0.5))` = drywet*0.5).
  Probably not what spec §9 decision 8 intended — revisit with item 4.

- [x] **4. LFO → waveshaper main parameter** (§4) — **DONE 2026-10-11,
      device-verified.** `rot_shaper`: `mod` now drives `main` (bipolar
      ±0.5 wobble around the set value; spec §3.8 + waveshaper.md:50 both
      specify it — decision 8's "unipolar for amp/dry-wet" never covered
      shaper main). Modulator stays mod→dry-wet (manual silent).
      **Quirk fixed in the same pass:** the `(1 - (mod*0.5+0.5))` drywet/
      gain formula halved the param at rest (mod=0); now
      `(1+mod).clip(0,1)` on rot_mod + rot_input — rest = set value,
      negative swing dips to 0 (still unipolar per decision 8).
      Verified: full-wet distortion mean 0.766 (= theory; was ~0.66);
      LFO depth 1 vs 0 amp spread 0.53 vs 0.08.
- [x] **5. Chorus rotation → depth + modulator settings page** (§3/§7) —
      **DONE 2026-10-11, device-verified** (spec §3.7 conformance):
  - [x] engine `rot_mod`: chorus `main` → depth (0..4ms around 5ms), rate
        moved to new `rate` arg; flanger rebuilt as CombL with `fdepth`,
        `mindelay`, `ffb` (decay-mapped feedback); ring unchanged
  - [x] `SET_FIELDS.modulator` with new per-subtype filtering (`f.sub`);
        `pages_for` skips the page when a subtype has no fields (ring);
        world params + PASS_PARAMS extended; slots backward-compat free
        (defaults fill on recall)
  - [x] device-verify: chorus depth sweep visible in raw amp series
        (0.06↔0.32 comb swing at 0.1 Hz, 10 s period as set); flanger ffb
        mean 0.35→0.49; set page screenshots: flanger shows
        fdepth/mindelay(ms)/ffb, chorus shows rate only
  - rig lesson: modulator/shaper `main` is ANGLE-DRIVEN — `/set main`
        gets stomped by sync_object; drive `/set angle` in tests; and
        full-wet chorus shows no amp modulation (delay ≠ comb — the mix
        nulls are the signal)

- [x] **6. Drum-mode octave pinning** (§5) — **DONE 2026-10-11,
      device-verified:** seq_tick/midi_note trigger drum samplers
      (subtype 2) at the rotation-set pitch (`t.freq`) instead of the note,
      per sampler.md:29. Verified via decay-duration: melodic note 69/93 =
      5.96/2.37 s loud-span (rate 1 vs 4), drum = 2.37/2.72 s (pinned;
      shorter than melodic rate-1 because the perc env decays
      exponentially — expected).

- [x] **7. Pitch/octave readout** (§9) — **DONE 2026-10-11,
      device-verified:** `Render.object` draws a short semitone marker on
      the left half-circle at 0.62r (bottom→top via left = C→B) and an
      inner octave arc at 0.34r (0–8 → empty→full circle from 12 o'clock),
      osc/sampler only, gated at r≥6 to stay clear of the slider gauge
      (r+2). Screenshots at multiple zooms; source is the rotation pitch
      (`o.params.freq`) — sequencer-played notes don't move it (the
      original shows the played note; acceptable simplification).

## Owner calls — all resolved 2026-10-11 (agent decisions, spec §9)

- [x] **8. Poly sequencer** (§5): RESOLVED by the other-PC session — the
      label was dropped in v3.2.2 (subtypes now mono/random/drift). A real
      2D grid sequencer stays on the plan.md parking lot (§9 decision 9).
- [x] **9. Loop semantics bundle** (§3): RATIFIED as deviations — spec §9
      decision 16 (speed-rotation, free-running rate, opt-in entry,
      amp-slider trim).
- [x] **10. Parameter lock gesture** (§2): DECIDED N/A — spec §9 decision
      17 (encoder edits are inherently persistent; nothing to lock).
- [x] **11. Auto-sync defaults** (§3): ADOPTED — spec §9 decision 19.
      Delay rotation is now the manual's hybrid (continuous near zero,
      snapped to 32nds past an 8th note, lua-side in `primary()`); new
      LFOs default `sync=1`. Device-verified 2026-10-11 (delay
      0.4081→0.4375 at 120 BPM; lfo sync=1 via /state params).
- [x] **12. Song-switch semantics** (§10): RATIFIED — spec §9 decision 18
      (instant wipe-rebuild by design).

Bonus shipped in the same pass: `T.state()` now includes each object's
`params` — the REST bridge (permanent AI-performance feature) can read
live parameter values.

## Verification log

- 2026-10-10: norns unreachable at 192.168.1.139 (ping 100% loss) — slider
  gauge deployed-code only, not yet device-verified.
- 2026-10-10 (later): device back; found seq metro wedged from the pre-
  reboot session (`T.health()`: tick=0, running=nil — watchdog did NOT
  recover it; third sighting of the frozen-clock class). Full device reboot
  cleared it (tick advancing, running=true). Gauge verified via
  `screen.export_screenshot` + SFTP pull at multiple zooms: bright 270°-max
  sweep + tip dot read clearly at NAV and ROTATE levels. NOTE:
  `deploy.py --shot` reloads the script (wipes table state) — for live
  state use `screen.export_screenshot('name')` via `/lua` + SFTP pull.
  NOTE: the 16 numbered squares at the table rim in min-zoom screenshots
  are the preset-slot markers, not a render bug.
- 2026-10-10 (later): **item 1 done** — engine `loadbuf` fires t_trig+gate
  post-buffer-swap (sampler/loop); `Audio.rotate` retrigs sampler on
  rotation (enc angle-change detection, T.rot, T.set angle). All amp-
  verified. Debug note: two mid-test "failures" were physical-encoder
  interference (owner was at the device; angle moved 1.15 rad between API
  reads) + a broken probe methodology (matron prints aren't buffered for
  later ws connections; and `Audio` is a local — the global is
  `RotatableAudio`). Full service restart ritual (gotcha 3) used for the
  .sc change; clock healthy after (tick advancing).
