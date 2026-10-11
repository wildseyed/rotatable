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
| Sequencer (mono/poly/random) | mono/poly/random labels | MISALIGN (§5; poly deferral is §9 decision 9) |
| MIDI Input | implemented, transpose ✓ | ok |
| Tonality | 4 presets + 12-mask + root | partial (§6) |
| Output | volume + global reverb/comp | ok |
| Song Settings (tempo/patch/bg) | tempo object + slots | DECIDED (flattened; but see §10) |

## 2. Gestures (manual: gestures.md)

- Subtype menu, panel pages, hardlinks, mute — all implemented. ok
- **GAP: parameter lock.** Original (gestures.md:22-24): drag the
  finger-controlled dot (amp/resonance/drywet) away from the object to lock
  it (it turns red, sampler.md:14); drag again to unlock. Nothing in
  ui/render/audio implements or represents lock state (verified: no lock
  field in `world.lua:106-120`; dot is display-only, `render.lua:253-268`).
- Minor: original has **two** temporary-mute gestures on a connection —
  holding a finger over it *and* drawing a line across it
  (gestures.md:36-38). We only have the explicit toggle
  (`World.toggle_mute`, K1+K3 in LINK mode). Cosmetic-equivalent, low
  priority.

## 3. Rotation semantics per object (manual vs `primary()` in audio.lua)

- Oscillator/sampler/input/filter/modulator-ring+flanger/waveshaper/LFO/
  output/sequencer-preset/midi-transpose/tempo/tonality-root — match. ok
- **MISALIGN: Loop rotation.** Original: in *Loop* mode rotation **selects
  among 8 loops** (4 per side, loop.md:8-10); speed is only direct in
  *Oneshot* mode (loop.md:12-14). Ours: one sample per object, rotation =
  playback rate (0.25..4) in both modes (`audio.lua:60`, no subtype branch).
  The "8 loop slots per object" concept is absent.
- **MISALIGN: Loop mode is not tempo-synced.** Original: loop subtype "plays
  back loops synchronized to the main tempo" and "when put on the table the
  loop enters in the first bar" (loop.md:29). Ours: free-running phasor at
  rate 0.25..4 (`Engine_Rotatable.sc:78-85`); the tempo bus only quantizes
  the *start point* (`sync` arg, `Engine_Rotatable.sc:63-77`), never fits
  loop duration to the beat — and `sync` defaults to 0 (`world.lua:29`).
- ~~MISALIGN: Chorus rotation drives rate, not depth~~ **FIXED 2026-10-11
  (phase 12):** rotation now drives chorus depth (0–4 ms around 5 ms) and
  rate lives on the new settings page, per modulator.md:29. Flanger also
  gained its settings (depth/min-delay/feedback via CombL).
- **MISALIGN: Delay time quantization.** Original: continuous near zero,
  *automatically* quantized to tempo durations for long values
  (delay.md:8-10). Ours: explicit `sync` toggle in the set page
  (`ui.lua:116-119`); off = never quantized (default off, `world.lua:41`).
  When on, ours snaps to 32nd-note multiples — in the spirit of the
  original, but all-or-nothing and opt-in.
- **MISALIGN: LFO frequency.** Original: always beat-synced, period is a
  multiple of a 32nd note (lfo.md:8-10). Ours: free-running 0.05–20 Hz by
  default, sync optional (`audio.lua:70`, `world.lua:50`). Our synced mode's
  unit (mult of 32nd notes, `Engine_Rotatable.sc:164`) matches the original
  concept — only the default differs. Superset, low priority.
- Minor: loop settings panel lacks the original's per-loop **Gain in dB**
  trim (loop.md:53); ours has only `sync` + the shared amp slider.

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
- **GAP: polyphonic sequencer is a label.** Subtype 2 ("poly") exists but
  `seq_steps`/`seq_tick` play exactly one note per step, identical to mono
  (subtype 2 is never read in audio.lua; only a cosmetic icon in
  `render.lua:122-124`). Original: 2D grid panel, several notes
  simultaneously (sequencer.md:27-29). Note: spec §9 decision 9 records
  "poly tenori grid deferred" — DECIDED-deferred rather than open.
- ~~GAP: sequencer → loop does nothing~~ **FIXED 2026-10-11 (phase 12):**
  loop added to `SEQ_TARGETS`; oneshot loops retrig per step (the engine
  `\loop` trigger branch already existed). Partial: the manual's loop
  *amplitude envelope* would need an ADSR in `rot_loop` (it has none) —
  deferred.
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

- **GAP (semantic): seamless song switching.** Original: switching songs
  never stops sound; objects on the table "retain their settings, and these
  will only switch to the new setting when they are removed and put back
  again" (songsettings.md:58). Ours: `Slots.recall` wipes and rebuilds the
  whole table instantly (`slots.lua:105-133`). The flattening of Song
  Settings is DECIDED (§1), but this specific behavior is nowhere
  acknowledged.

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
   retrig; full loop ADSR deferred).
4. ~~**LFO → main parameter for waveshaper** (§4)~~ — **DONE 2026-10-11**
   (+ fixed the rest-halving drywet quirk on mod/input; decision 8
   re-anchored: unipolar dipper, rest = set value).
5. ~~**Chorus rotation → depth** (§3/§7)~~ — **DONE 2026-10-11**: chorus
   depth on rotation, rate on a new per-subtype modulator settings page
   (flanger: depth/mindelay/feedback via CombL rebuild).
6. **Poly sequencer** (§5) — moved to owner calls (deferral already in
   §9 decision 9).
7. **Loop semantics bundle** (§3) — moved to owner calls (8-slot rotation
   vs ratify speed-rotation; tempo-sync; bar entry; gain trim).
8. ~~**Drum-mode octave pinning** (§5)~~ — **DONE 2026-10-11**.
9. **Parameter lock gesture** (§2): fits our "dot" UI; parked-design
   candidate.
10. ~~**Pitch/octave visual** (§9)~~ — **DONE 2026-10-11**;
    **delay/LFO auto-sync defaults** (§3); **song-switch semantics**
    (§10): ratify or implement.
