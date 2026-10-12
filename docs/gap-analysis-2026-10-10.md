# Gap analysis — Rotatable vs. original Reactable Live!

Date: 2026-10-10. Method: full read of `reference/manual/md/` (Live! manual)
compared against `lib/world.lua`, `lib/audio.lua`, `lib/Engine_Rotatable.sc`,
`lib/ui.lua`, `lib/render.lua`, `lib/tonality.lua`, `rotatable.lua`, plus
`docs/behavior-spec.md` §7/§9 decision history. Physical-table gaps
(camera, multitouch surface, projector, calibration, file sharing) are
excluded by request.

**Verification pass (same day):** every claim below was re-checked against
manual and code. Two errors in the original draft were corrected (§4 minor
note, §8: rotation never retriggers notes — the draft had claimed it as
implemented), and the missed gaps found by the sweep were added (§3 loop
tempo-sync, §4 velocity, §5 seq→loop / drum pitch, §8 oneshot loop,
§10 session semantics, assorted minors). Verified line citations included.

Classified as:
- **GAP** — original feature absent, not yet an explicit project decision.
- **MISALIGN** — feature exists but behaves differently from the original.
- **DECIDED** — deviation already ratified in spec §9 / notebook (listed for completeness).

---

## 1. Object set

| Original | Rotatable | Status |
|---|---|---|
| Oscillator (sine/saw/square/noise/user-drawn) | 4 subtypes, no user-drawn | GAP (parked, owner design pending) |
| Loop (loop / oneshot / pitch-locked) | loop / oneshot | DECIDED (pitchlock dropped phase 6) |
| Sampler (SF2 instrument / drum) | WAV single-sample / drum | DECIDED (phase 6: no SF2/multi-zone) |
| Audio Input (mic) | line-in | DECIDED (shield has no mic) |
| Filter (hp/bp/lp) | lp/bp/hp | ok |
| Delay (reverb/pingpong/feedback) | feedback/pingpong/reverb | ok |
| Modulator (flanger/chorus/ringmod) | ring/chorus/flanger | MISALIGN (settings §7, chorus rotation §3) |
| Wave Shaper (resampler/compressor/distortion) | same 3 | ok |
| LFO (sine/saw/square/random) | sine/saw/square/random | ok |
| Sequencer (mono/poly/random) | mono/random/drift | RESOLVED (poly dropped v3.2.2; drift added v3.3.0) |
| MIDI Input | implemented, transpose ✓ | ok |
| Tonality | 4 presets + 12-mask + root | partial (§6) |
| Output | volume + global reverb/comp | ok |
| Song Settings (tempo/patch/bg) | tempo object + slots | DECIDED (flattened; but see §10) |

## 2. Gestures (manual: gestures.md)

- Subtype menu, panel pages, hardlinks, mute — all implemented. ok
- ~~GAP: parameter lock~~ **DECIDED N/A (spec §9 decision 17,
  2026-10-11):** the lock exists because a finger can't stay on a dot;
  encoder edits are inherently persistent, so there is nothing to lock.
  Deviation ratified.
- Minor: original has **two** temporary-mute gestures on a connection —
  holding a finger over it *and* drawing a line across it
  (gestures.md:36-38). We only have the explicit toggle
  (`World.toggle_mute`, K1+K3 in LINK mode). Cosmetic-equivalent, low
  priority.

## 3. Rotation semantics per object (manual vs `primary()` in audio.lua)

- Oscillator/sampler/input/filter/modulator-ring+flanger/waveshaper/LFO/
  output/sequencer-preset/midi-transpose/tempo/tonality-root — match. ok
- ~~MISALIGN: Loop rotation~~ **DECIDED (spec §9 decision 16, 2026-10-11):**
  rotation stays playback-rate in both subtypes; the 8-loop-slots model has
  no analogue in our one-sample browser model. Deviation ratified.
- ~~MISALIGN: Loop mode is not tempo-synced~~ **DECIDED (§9 decision 16):**
  loop mode stays free-running; tempo only quantizes entry (`sync`,
  opt-in, default immediate). Per-loop dB trim covered by the amp slider.
- ~~MISALIGN: Chorus rotation drives rate, not depth~~ **FIXED 2026-10-11
  (phase 12):** rotation now drives chorus depth (0–4 ms around 5 ms) and
  rate lives on the new settings page, per modulator.md:29. Flanger also
  gained its settings (depth/min-delay/feedback via CombL).
- ~~MISALIGN: Delay time quantization~~ **FIXED 2026-10-11 (§9 decision
  19):** rotation is now the manual's hybrid — continuous near zero,
  snapped to 32nd notes of the tempo past an 8th note (lua-side in
  `primary()`); the `sync` toggle stays as the always-quantized mode.
  Device-verified (0.4081 → 0.4375 at 120 BPM).
- ~~MISALIGN: LFO frequency~~ **FIXED 2026-10-11 (§9 decision 19):** new
  LFOs default to `sync=1` (mult 8 = quarter note), matching the
  original's always-beat-locked behavior; free-running stays a toggle away.

## 4. Control-signal targets (manual vs engine `mod`/note handling)

- ~~MISALIGN: LFO → waveshaper main parameter~~ **FIXED 2026-10-11 (phase
  12):** `rot_shaper`'s `mod` now drives `main` (bipolar wobble, rest =
  set value), per waveshaper.md:50-52 and spec §3.8. Same pass fixed a
  related quirk: the `(1-(mod*0.5+0.5))` drywet/gain formula halved the
  parameter at rest; rot_mod/rot_input now use `(1+mod).clip(0,1)`
  (unipolar dipper, decision 8 intact). Modulator LFO target stays dry-wet
  (manual silent — the original draft's claim there was an inference).
- ~~GAP: sequencer note → effect parameter~~ **FIXED 2026-10-11 (phase
  12):** engine `trigger` maps the note number (60 = center) to `\main` on
  waveshaper (linlin 36..84→0..1) and `\time` on delay (linexp
  36..84→0.01..2 s); `seq_tick`/`midi_note` send it. Filter/modulator stay
  envelope-only (manual silent). Device-verified.
- ~~Minor: velocity discarded for effect targets~~ **FIXED 2026-10-11:**
  new `vel` arg on the four effect synths scales ADSR depth; set per note
  from seq velocity / MIDI velocity.
- **BUG FOUND during the fix (latent since v3):** effect and oscillator
  envelopes *never actually retriggered* — the trigger command's
  back-to-back `set(\gate,-1); set(\gate,1)` lands in one scsynth control
  period and EnvGen never sees the edge. Fixed with a `t_retrig`
  TrigControl (`gate * (1 - t_retrig)`). Device-verified.
- Filter env→cutoff, delay env→feedback, modulator/shaper env→drywet,
  generators env→amp — all match the manual (verified:
  `Engine_Rotatable.sc:97,126,154,190,54-56,216-219`). ok
- Minor (corrected): panels.md:19 says envelopes also trigger "when rotating
  the objects". The original draft claimed ours retriggers on rotation for
  osc/sampler — **wrong**: `engine.trigger` is called only from `seq_tick`
  and `midi_note`; rotation only does `engine.set`. The deviation is total.
  For oscillator it is DECIDED (spec §9 decision 14: rotation is a
  continuous sweep, retrigger would stutter); for sampler see §8.

## 5. Sequencer (manual: sequencer.md)

- 16 steps, 6 rotation-switched presets, velocity, per-step duration,
  random subtype + tonality interplay — all implemented (verified:
  `world.lua:121-136`, `audio.lua:71,307-347`). ok
- ~~GAP: polyphonic sequencer is a label~~ **RESOLVED 2026-10-11 by
  removal (v3.2.2):** the unimplemented "poly" subtype was dropped;
  subtypes are now mono / random / drift (drift added v3.3.0). A real 2D
  grid sequencer remains possible future work (§9 decision 9).
- ~~GAP: sequencer → loop does nothing~~ **FIXED 2026-10-11 (phase 12):**
  loop added to `SEQ_TARGETS`; oneshot loops retrig per step (the engine
  `\loop` trigger branch already existed). ~~Partial: the manual's loop
  *amplitude envelope* would need an ADSR in `rot_loop` (it has none) —
  deferred.~~ **CLOSED 2026-10-11 (phase 13):** `rot_loop` gained a full
  amplitude ADSR (t_retrig on seq/MIDI/reload, vel depth, s=1 default =
  free-running loops unchanged). Device-verified.
- ~~GAP: drum sampler pitch-follows sequencer notes~~ **FIXED 2026-10-11
  (phase 12):** drum subtype now triggers at the rotation-set pitch
  regardless of note, per sampler.md:29. Decay-duration verified.
- Minor: mono pitch panel range is −12..+12 semitones in the original
  (panels.md:40); ours edits ±24 (`ui.lua:527`). Superset. Also our
  per-step duration caps at 8×32nds (a quarter note, `ui.lua:520`); the
  manual implies longer spans ("16th notes, 8th notes, and so on",
  sequencer.md:53). The original mono panel is a one-sweep melody draw;
  ours edits stepwise.

## 6. Tonality (manual: tonality.md)

- Rotation presets + per-note programming + root — implemented. ok
- Partial: original offers 6 rotation presets and a larger predefined-scale
  library plus a key panel (tonality.md:10); ours has 4 scales
  (major/minor/pentatonic/chromatic, `tonality.lua:8-13`) + free 12-degree
  mask + root param. Superset in editing, smaller in presets. Low priority.

## 7. Modulator settings (manual: modulator.md)

- ~~GAP: subtype settings panel~~ **FIXED 2026-10-11 (phase 12):**
  `SET_FIELDS.modulator` added with per-subtype fields (`f.sub` filtering —
  chorus: rate; flanger: depth/min-delay/feedback; ring: no page). Engine
  `rot_mod` gained `rate`/`fdepth`/`mindelay`/`ffb` args; flanger rebuilt
  as CombL for feedback. Device-verified + set-page screenshots.

## 8. Placement & rotation triggers (manual: sampler.md, loop.md)

**FIXED 2026-10-10 (phase 12, device-verified):** engine `loadbuf` now fires
`t_trig` (+gate) after the buffer swap for sampler and loop (covers
placement-with-sample and load-while-on-table; loop-mode restarts via
`Changed.kr(buf)` as before), and sampler rotation retriggers via
`Audio.rotate` (ratified as spec §9 decision 15; oscillator stays
trigger-free per decision 14). Verified: standalone oneshot loop sounds on
load (amp 0.21), sampler placement (amp 0.05–0.59), rotation retrigger via
both `T.rot` (0.59) and the physical enc path (0.05). Original text below
for the record:

- ~~GAP: "A note is triggered as soon as the object is put on the table"
  (sampler.md:3).~~ `Audio.on_add` never fired `t_trig`; a freshly placed
  sampler was silent until sequencer/MIDI.
- ~~GAP: oneshot loop is silent when placed~~ (loop.md:33): `rot_loop`'s
  PlayBuf fired only on sequencer/MIDI `t_trig`; a standalone oneshot never
  sounded.
- ~~GAP: sampler rotation does not trigger a note~~ (sampler.md:3,9).

## 9. Visual language (manual: general.md, oscillator.md, output.md)

- Output point + tempo pulse, auto-connect generators, effect auto-insert,
  controller→closest — all implemented (verified: `rotatable.lua:314-320`,
  `world.lua:263-297`). ok
- ~~GAP: pitch readout on the object~~ **FIXED 2026-10-11 (phase 12):**
  osc/sampler now show a semitone marker on the left half-circle (0.62r)
  and an inner octave arc (0.34r), per oscillator.md:10/sampler.md:10.
  Shows the rotation pitch; gated to r≥6 so it composes with the slider
  gauge.
- **MISALIGN: slider presentation.** Original renders the finger-controlled
  parameter as a track **around the object's perimeter** (an orbital ring
  the dot rides on, draggable outward to lock). Ours encodes value as the
  radial distance of a dot on a short stub at rotation+90°
  (`render.lua:253-268`) — crammed into the glyph center, hard to read at
  small zoom. **Owner decision (2026-10-10): adopt the Reactable
  perimeter-ring style.** Design sketch: full or partial ring at ~1.15–1.3×
  glyph radius; value shown as an arc sweep and/or a dot riding the ring at
  the value position; dot offsettable outward for the future lock gesture
  (§2); must stay legible down to r=3 (current cutoff) and coexist with the
  rotation tick, subtype pictogram, and VU bar.
- DECIDED: audio connections "show the soundwaves" and control connections
  visualize control data (general.md:38); ours uses animated dashes + VU
  levels. Owner ratified 2026-10-10: keeps the low-res display clean.
- Cosmetic minors: sequencer preset ring — original shows the current
  preset as an arrow on a 6-slot ring (sequencer.md:10), ours is text
  (`p1`..`p6`); filter 2D panel — original "shows the filter envelope"
  (filter.md:41), ours draws only the crosshair (`ui.lua:944-959`).

## 10. Session & slots (manual: songsettings.md)

- ~~GAP (semantic): seamless song switching~~ **DECIDED (spec §9
  decision 18, 2026-10-11):** slot recall is an instant wipe-rebuild by
  design (Song Settings flattening, decision 4); the seamless per-object
  handoff is not pursued.

## 11. Online cross-check (Wikipedia / reacTable era)

Beyond the Live! manual, the 2005 reacTable had two tangibles Live! dropped:
**radar** (periodic trigger) and **tonalizer** (scale limiter — our tonality
object covers it). Multi-function cubes (one physical object, several faces)
have no virtual analogue need. Baseline here is Live!, so radar is out of
scope; noted only for completeness.

---

## Suggested priority (owner to confirm)

1. ~~**Placement/rotation triggers** (§8)~~ — **DONE 2026-10-10**: engine
   `loadbuf` fires `t_trig`+gate after the buffer swap (sampler + loop);
   sampler rotation retriggers via `Audio.rotate` (spec §9 decision 15).
   Device-verified.
2. ~~**Sequencer note → effect main parameter** (§4)~~ — **DONE
   2026-10-11**: note→main for waveshaper/delay, velocity→env depth on all
   effects. Surfaced + fixed a latent engine bug: gate-edge retrig never
   worked (same-control-period); now `t_retrig` TrigControl.
3. ~~**Sequencer → loop envelope** (§5)~~ — **DONE 2026-10-11** (oneshot
   retrig; ~~full loop ADSR deferred~~ full loop ADSR landed in phase 13,
   same day).
4. ~~**LFO → main parameter for waveshaper** (§4)~~ — **DONE 2026-10-11**
   (+ fixed the rest-halving drywet quirk on mod/input; decision 8
   re-anchored: unipolar dipper, rest = set value).
5. ~~**Chorus rotation → depth** (§3/§7)~~ — **DONE 2026-10-11**: chorus
   depth on rotation, rate on a new per-subtype modulator settings page
   (flanger: depth/mindelay/feedback via CombL rebuild).
6. ~~**Poly sequencer** (§5)~~ — **RESOLVED by removal (v3.2.2)**; a real
   grid sequencer stays on the parking lot (§9 decision 9).
7. ~~**Loop semantics bundle** (§3)~~ — **DECIDED (§9 decision 16)**:
   speed-rotation, free-running rate, opt-in entry, amp-slider trim all
   ratified.
8. ~~**Drum-mode octave pinning** (§5)~~ — **DONE 2026-10-11**.
9. ~~**Parameter lock gesture** (§2)~~ — **DECIDED N/A (§9 decision 17)**:
   encoder edits are inherently persistent.
10. ~~**Pitch/octave visual** (§9)~~ — **DONE 2026-10-11**;
    ~~**delay/LFO auto-sync defaults** (§3)~~ — **DONE 2026-10-11** (§9
    decision 19); ~~**song-switch semantics** (§10)~~ — **DECIDED** (§9
    decision 18).

**All items closed as of 2026-10-11** (v3.4.x): every gap is either FIXED,
DECIDED, or RESOLVED. Remaining open ideas live in plan.md's parking lot.
