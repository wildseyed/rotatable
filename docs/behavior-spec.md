# Rotatable — Behavior Specification

*Distilled from the mirrored Reactable Live! manual (`reference/manual/md/`,
2011) plus online research (Reactable mobile manual at reactable.com/mobile/manual/,
TEI'07 paper, reviews — see Sources). This is the spec of the **original**
instrument; Norns-specific design lives in `docs/interaction-design.md`.*

## 1. Object model

Four categories, shape-coded; **14 object types** total.

| Category | Shape | Role | Types |
|---|---|---|---|
| Generators | square | Produce sound; audible unconnected; auto-connect to output/effects | Oscillator, Loop Player, Sampler, Audio Input |
| Effects & Filters | rounded square | Need audio in from generator/effect; accept control in | Filter, Delay, Modulator, Wave Shaper |
| Controllers | (round) | Send control data to their **closest** object | LFO, Sequencer, MIDI Input |
| Global Controllers | star | Never connect; app-wide behavior | Song Settings, Output, Tonality |

- Every object has a **subtype icon** on the player-facing side.
- Screen center holds a **white output point**: everything connected to it is
  heard; it pulses a wave at the current tempo for sync reference.

## 2. Connection rules

- Two kinds: **audio connections** (visualize sound waves) and **control
  connections** (visualize control data); visually distinct.
- **All connections are automatic, based on distance.** Generators auto-connect
  to output or effects; effects placed **on a generator's connecting line**
  auto-apply to it. Controllers connect to their **closest object**.
- Rotation does **not** form connections — proximity only.
- **Hardlink**: move two objects very close together → red, unbreakable link;
  repeat gesture to undo. (Mobile/Android: lets one controller drive several
  targets.)
- **Mute/cut**: draw a line across a connection (or hold a finger over it) →
  temporary break; repeat to restore.

## 3. Per-object specification

Universal mapping: **rotation = primary parameter**; **right-side dot/slider =
amplitude (generators), dry/wet (effects), feedback (delay), depth (LFO)** —
draggable away from the object to lock (sampler: until red).

### 3.1 Oscillator (Generator)
- Rotation: pitch + triggers envelope. Display: outer half-circle = semitone,
  inner circle = octave. White noise subtype: "pitch" = lowpass cutoff.
- Subtypes: Sine, Sawtooth (antialiased), Square, White noise (through
  lowpass), User-drawn (freehand waveform; auto-selected when drawn).
- Panels: Envelope (amplitude ADSR), Suboscillators (4 subs: waveform,
  amplitude, detune, offset; toggle for pitch-follows-tonality), Waveform draw.

### 3.2 Loop Player (Generator)
- Rotation: loop select — **4 loops per side (8 total)**; in Oneshot mode,
  playback speed directly.
- Subtypes: Loop player (tempo-synced; enters at first bar), Oneshot (plays
  immediately on placement), Pitch-locked loop (time-stretched, tempo-
  independent pitch).
- Panels: Sample browser (16-bit WAV, 44.1 kHz preferred), Envelope (amplitude,
  applied when sequencer-connected), Settings (Sync = immediate/quarter/bar;
  Gain dB).

### 3.3 Sampler (Generator)
- Plays **SoundFont 2** instruments; one soundfont per session. Note triggers on
  placement and rotation.
- Rotation: base pitch (semitone/octave display) + note trigger; in Instrument
  mode, rotating pitch-shifts a running sequence.
- Subtypes: Instrument (played note = base + sequencer note), Drum (sequencer
  notes stay in one octave).
- Panels: Instrument browser.

### 3.4 Audio Input (Generator)
- Live mic/line input, processable like any generator.
- Rotation: input gain. No subtypes, no panels.

### 3.5 Filter (Effect)
- Rotation: cutoff (LP/HP) or center frequency (BP). Finger: resonance/Q.
- Subtypes: Low-pass, Band-pass, High-pass.
- Panels: 2D Control (X=freq, Y=resonance, shows filter envelope), Envelope
  (ADSR of **filter frequency**, triggered by sequencer notes).

### 3.6 Delay (Effect)
- Rotation: delay time — continuous (pitch-like) near zero, **tempo-quantized**
  at long values. Finger: feedback (max = infinite repeat at unity).
- Subtypes: Feedback delay, Ping-Pong, Reverb.
- Panels: 2D Control (X=time, Y=feedback), Envelope (ADSR of **feedback**;
  sequencer note also changes delay time), Settings (Sweep = time to glide
  delay-time changes).

### 3.7 Modulator (Effect)
- Rotation: main param — ring mod: modulation pitch; chorus: depth; flanger:
  flanging frequency. Right slider: dry/wet (min = bypass).
- Subtypes: Ring modulator, Chorus (settings: rate), Flanger (settings: depth,
  min delay, feedback).
- Panels: 2D Control (X=main, Y=dry/wet), Envelope (ADSR of **dry/wet**).

### 3.8 Wave Shaper (Effect)
- Rotation: main param. Right slider: dry/wet.
- Subtypes: Resampler (sample-rate reduction), Compressor, Distortion.
- Panels: 2D Control (X=main, Y=dry/wet), Envelope (ADSR of **dry/wet**).
- Inputs: LFO → main param; sequencer note → envelope trigger + main param.

### 3.9 LFO (Controller)
- Rotation: frequency (<20 Hz; period = multiple of a 32nd note, **tempo-synced**).
- Amplitude control: depth on target.
- Subtypes: Sine, Sawtooth, Square, Random (one value per period).

### 3.10 Sequencer (Controller)
- **16-step** loop; note events. Rotation: switch among **6 stored presets**
  (arrow points to current slot).
- On-object programming: tap step to enable/disable; drag outward from a step
  to set its volume.
- Subtypes: Monophonic, Polyphonic (2D "tenori" grid), Random (with Tonality =
  "automatic solos").
- Panels: Mono pitch (draw melody, −12..+12 semitones relative to target's base
  note), Poly pitch grid, Velocity (per-step), Step Duration (per-step, note
  values; multiples of 32nd notes).

### 3.11 MIDI Input (Controller)
- Sends external MIDI notes to Reactable synths. Rotation: transposition.

### 3.12 Song Settings (Global)
- Rotation: tempo (BPM shown) — or current patch, in Patch Selector subtype.
- Subtypes: Tempo, Patch Selector, Table Background.
- Panels: Session Change, Patch Load/Save (one preset per .rtp), Background
  Color/Image. Patch switching **never stops audio**; on-table objects keep old
  settings until re-placed.

### 3.13 Output (Global)
- Rotation: master volume. Panels: Global Effects (reverb, compression levels).

### 3.14 Tonality (Global)
- Rotation: switch among **6 tonality presets**. On-object: touch fields around
  it to edit notes.
- Panels: Tonality Key (base key), Predefined Tonalities.
- Gates sampler ("Tonalizer") and oscillator suboscillators (follow-tonality
  toggle); random sequencer solos.

## 4. Gesture set (original)

Move; rotate (primary param; generators also trigger envelope/note); subtype
menu (drag icon left); panels (drag icon right, tabs, drag panel by left arrow
to orbit object, close with "x"); parameter lock (drag dot outward); hardlink
(bring close, red); mute/cut (draw across connection); waveform drawing;
sequencer step toggle/volume; tonality field editing; browser scroll/select.
Mobile additions: dock for drag-in/drag-off, double-tap = open panel,
double-tap-hold + drag = rotate, two-finger rotate.

## 5. Panels (original)

| Panel | Edits | Objects |
|---|---|---|
| 2D Control | point on 2D surface → two params at once | Filter, Delay, Modulator, Waveshaper |
| Envelope | ADSR sliders; target varies (amplitude / filter freq / feedback / dry-wet) | most objects; triggered by sequencer notes + rotation |
| Browser | files/instruments/sessions/images; subfolders highlighted | Loop, Sampler, Song Settings |
| Suboscillators | 4 subs × (waveform, amp, detune, offset) + tonality toggle | Oscillator |
| Sequence (mono/poly) | pitch per step, relative to target base note | Sequencer |
| Step Duration | per-step duration, multiples of 32nd notes | Sequencer |
| Velocity | per-step velocity | Sequencer |
| Settings | subtype extras (loop sync/gain, delay sweep, modulator params) | Loop, Delay, Modulator |
| Global Effects | reverb + compression levels | Output |
| Tonality Key / Predefined | scale base + presets | Tonality |
| Patch Load/Save, Session Change | persistence | Song Settings |

## 6. Global behaviors

- **Tempo/sync**: global BPM via Song Settings; output point pulses. Synced:
  LFO period, loop playback (incl. time-stretched pitch-locked), delay time
  quantization, loop start (immediate/quarter/bar).
- **Tonality**: 6 presets, per-note edit, base key; constrains oscillators
  (subosc toggle), samplers, random sequencer.
- **Persistence**: Set = full table snapshot; Session = collection of sets;
  .rtp files/dirs. Sample import: 16-bit WAV. Instruments: SF2, one per session.

## 7. Gaps in the original spec (emulator must decide)

1. Connection geometry: no distance thresholds, tie-breaking, max fan-out.
   (Hardlink presumably pins a controller to a non-closest target.)
2. No object-count limits stated.
3. Effect chain ordering when several effects sit near one generator line.
4. Sequencer note → parameter scaling on non-pitch targets (filter freq,
   delay time, dry/wet) undefined. **Resolved (v1): sequencer drives only
   oscillator targets (freq + gate retrigger); other targets deferred.**
5. LFO → target param mapping only specified for waveshaper (main param);
   presumably "the rotation parameter" elsewhere. **Resolved (v1): LFO is
   unipolar 0..depth and modulates target amp (generators/filter/delay) or
   dry/wet (modulator) via control-bus mapping.**
6. Oscillator rotation→pitch: continuous vs quantized, range — undefined.
   **Resolved (v1): continuous, 55–880 Hz (4 octaves, exponential over one
   full turn).**
7. Sequencer: are the 6 presets per-object? (presumably yes). Step-volume
   gesture vs Velocity panel: same value or separate? (unclear).
   **Partially resolved (v1): rotation selects among 6 preset slots
   (per-object); only one fixed 16-step minor-pentatonic pattern (odd steps
   on) exists so far.**
8. No numeric ranges anywhere: BPM, LFO range, filter cutoff range, feedback,
   detune, MIDI transpose — all must be chosen. **Resolved (v1, engine):**
   - tempo: 40–240 BPM, default 120 (params: `rot_tempo`); sequencer step =
     16th note
   - oscillator freq: 55–880 Hz (angle); amp 0–1
   - filter cutoff: 40–12000 Hz log; res 0–1 → rq 0.05–1
   - delay time: 0.01–2 s (angle, log); feedback 0–0.99
   - modulator ring freq: 10–2000 Hz log; chorus rate 0.1–8 Hz; flanger rate
     0.05–2 Hz; dry/wet 0–1
   - LFO freq: 0.05–20 Hz (angle, log, not yet tempo-synced); depth 0–1
   - loop rate: 0.25–4 (angle, log)
   - master volume: 0–1, default 0.8
9. Output point vs Output object relationship unstated. **Resolved (v1): the
   table-origin output point IS the engine's master bus; the Output object
   sets master volume.**
10. Delay time range/min/max unspecified; "continuous near zero" implies
    comb territory. **Resolved (v1): 0.01–2 s continuous; no tempo
    quantization yet.**
11. Loop "8 loop slots" vs sample browser relationship unclear.
12. Mobile vs table differences (accelerometer object, dock UI) — Norns design
    borrows selectively, noted in interaction-design.md.

## 8. Sources

- `reference/manual/md/*.md` — Reactable Live! manual mirror (2011), primary.
- reactable.com/mobile/manual/ — live Reactable mobile manual (legacy site;
  company dissolved 2022, founders maintain preservation mirror). Filled the
  accelerometer/mobile-navigation gaps.
- reactable.com — legacy site root; rotor/snap/steps product pages.
- Jordà, Geiger, Alonso, Kaltenbrunner, "The reacTable", TEI'07 (SuperCollider
  runtime-patched engine architecture).
- reacTIVision (github.com/mkalten/reacTIVision), TUIO spec (tuio.org) —
  original object model is (fiducial ID → type, x, y, angle) streamed
  continuously; maps trivially onto our encoder-driven virtual objects.
- Sound on Sound Reactable Mobile review; YouTube @ReactableSystems.

## 9. v2 decisions (2026-09-26, owner-approved)

1. **Sampler**: single-sample melodic player — one WAV pitched across notes
   (Phasor+BufRd, reuses the loop browser). Instrument + Drum subtypes. No
   SoundFont/multi-zone in v2.
2. **Audio-in**: include; line-in only (shield has no mic); rotation = input
   gain.
3. **MIDI-in**: include; device + channel via norns params; rotation =
   transpose (±24 st); notes land on the closest connectable object.
4. **Song Settings**: skipped as an object. Tempo stays in params
   (`rot_tempo`); patch selector redundant with patch slots; background N/A.
5. **Waveshaper**: all three subtypes (resampler, compressor, distortion).
6. **Tonality**: constrains sequencer note output, random sequencer, sampler
   notes, and suboscillators (follow-tonality toggle). Oscillator main
   rotation stays continuous.
7. **Tempo sync**: hybrid — engine-side tempo control bus for LFO sync, delay
   tempo-quantize, loop bar-entry; sequencer keeps its Lua metro on the same
   BPM param (single source of truth).
8. **LFO→param scaling**: per-target scale table, engine-side; bipolar around
   current value for pitch-like params, unipolar for amp/dry-wet.
9. **Sequencer**: 6 rotation-switched preset slots per object + random
   subtype (with Tonality = "automatic solos"). Poly tenori grid deferred.
10. **Connection model**: v1 model kept; edge rules documented (nearest-effect
    wins, chains order by distance-to-output, hardlink pins control targets).
    No fan-out limit.
11. **v1 leftovers**: oneshot loop subtype, pingpong + reverb delay subtypes,
    LINK ring declutter all in. **Pitchlock loop subtype out** (real
    time-stretch = phase vocoder, poor cost/benefit in v2).
12. **Label collisions**: resolved 2026-09-26 (v1.x, renderer label queue).
