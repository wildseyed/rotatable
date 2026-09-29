# rotatable

a [Reactable](https://en.wikipedia.org/wiki/Reactable) emulator for monome norns —
the tangible table synth, recreated virtually: no camera, no pucks, just the
round table on screen, patched by proximity, driven by 3 encoders + 3 keys.

**v3.0.1** · [github](https://github.com/wildseyed/rotatable) · [discussion](https://github.com/wildseyed/rotatable/discussions)

**new in v3**: the slider — every block shows a value dot on its right
side (E3 in ROTATE, K1+E3 fine-tune) · tempo object: rotation = BPM on
the table · global FX on the output object (master reverb + compression)
· oscillator sub-oscillators (4 subs + follow-tonality) · tonality scale
editing (12 toggleable degrees) · effect envelopes — sequencer/MIDI notes
sweep filter cutoff, delay feedback, dry-wet

**new in v2**: 13 object types (adds sampler, audio-in, waveshaper,
tonality, midi-in) · tempo sync everywhere (LFO multiply, delay quantize +
sweep, loop bar-entry) · sequencer: 6 patterns per object, per-step
velocity + duration, random subtype · subtype pictograms on every block,
animated signal flow, tempo pulse, per-object VU meters · SYSTEM menu
(hold K1+K2+K3) with factory presets · synced settings panels ·
melodic sampler with base-pitch tuning

**new in v3**: on-block slider dot · tempo object · master reverb +
compression · suboscillators · editable tonality scales · effect
envelopes · **16 factory presets** — a tutorial arc of full musical
tables, with a bundled sample library (synthesized drums, orchestral
instruments, animal sounds; sources in `presets/audio/SOURCES.md`)

## screenshots

![the table: objects patched toward the output point, tempo object
lower-left](https://raw.githubusercontent.com/wildseyed/rotatable/main/press/table-wide.png)

![a chain in detail: loop, shaper, delay, filter, osc — subtype
pictograms and signal-flow dashes](https://raw.githubusercontent.com/wildseyed/rotatable/main/press/chain-detail.png)

![the sequencer steps panel](https://raw.githubusercontent.com/wildseyed/rotatable/main/press/panel-steps.png)

![the output object's global FX panel](https://raw.githubusercontent.com/wildseyed/rotatable/main/press/panel-gfx.png)

## install

on your norns, in maiden's REPL:

```
;install https://github.com/wildseyed/rotatable
```

then **SYSTEM > RESTART** (first run compiles the engine), and SELECT > rotatable.

samples for the loop browser: drop WAVs anywhere under `~/dust/audio/`.

## the idea

objects on a round table are synth modules. move them close together and they
connect: generators feed effects, effects chain toward the output point at the
table center, controllers (LFO, sequencer) drive their closest neighbor.
everything connected to the center dot is heard.

## your first patch (30 seconds)

1. `K1+K3` → place menu → `K3` places an **oscillator** at the reticle
2. it's already selected in MOVE mode — E2/E3 slide it near the center dot;
   a line forms → you're hearing it
3. `K3` once → ROTATE mode: **E2 sweeps pitch**, E3 loudness,
   `K1+E2` cycles sine/saw/square/noise
4. `K1+K3` → place a **filter**, MOVE it onto the line between the osc and the
   center — the audio now routes through it; rotate the filter to sweep cutoff
5. `K1+K3` → place a **sequencer** near the osc — a melody starts;
   select it, `K1+K3` to edit its 16 steps

## levels & keys

the UI is a hierarchy; `K3` acts, `K2` backs out, `K1` modifies.

| level | you are here | keys |
|---|---|---|
| L1 NAVIGATE | flying over the table | E1 zoom, E2/E3 pan; `K3` select object; `K1+K3` place menu; `K1+K2` clear table (with confirm) |
| L0 PLACE | the object menu | E2 scroll; `K3` place at reticle; `K2` cancel |
| L2 OBJECT | one block selected | `K3` cycles MOVE → ROTATE → LINK; `K1+K3` dive into config; `K1+K2` delete block |
| L3 CONFIG | a block's panels | E1 page, E2/E3 edit; `K2` back |
| SYSTEM | master menu | **hold `K1+K2+K3` for 1 s** to open; E2 scroll, `K3` select, `K2` close |

**L2 modes**

- **MOVE**: E2/E3 glide the object with accel/decel physics (connections
  form/break live as it slides)
- **ROTATE**: E2 = main param, E3 = the slider (amp / dry-wet / feedback /
  depth / resonance per type), `K1+E3` = fine adjust, `K1+E2` = subtype
- **LINK**: E2 cycles targets by proximity; `K3` toggles hardlink
  (permanent, bright line); `K1+K3` mutes the connection (dimmed)
- **E1 hops selection between objects in every L2 mode**, centering the
  camera on each
- `K2` walks back through modes (LINK → ROTATE → MOVE → NAV)

> **subtype cycling**: most objects have several flavors (sine/saw/square/
> noise, lp/bp/hp, ring/chorus/flanger…). hold `K1` and turn `E2` to cycle
> them — works in ROTATE mode and on every config (L3) page; the subtype
> name shows in the status line / panel header.

## object reference

| object | role | rotation (E2) | E3 | subtypes (K1+E2) |
|---|---|---|---|---|
| oscillator | generator | pitch | amp | sine / saw / square / noise |
| loop | generator | playback rate | amp | loop / oneshot (browser panel) |
| sampler | generator | pitch | amp | instrument / drum (browser + base pitch panels) |
| input | generator | gain | — | line |
| filter | effect | cutoff | resonance | lp / bp / hp |
| delay | effect | time | feedback | feedback / pingpong / reverb |
| modulator | effect | main (pitch/depth/rate) | dry-wet | ring / chorus / flanger |
| waveshaper | effect | main | dry-wet | resampler / compressor / distortion |
| lfo | controller | rate | depth | sine / saw / square / random |
| sequencer | controller | pattern preset (1–6) | — | mono / poly / random |
| midi | controller | transpose ±24 st | — | in |
| tonality | global | root key | — | major / minor / pentatonic / chromatic |
| tempo | global | BPM (40–240) | — | bpm (label shows the value) |
| output | global | master volume | — | — (the star; never connects) |

**midi in**: vport + channel in PARAMETERS (`midi in vport`,
`midi in channel`). notes route to the midi object's closest object,
velocity sets amp, note-off releases the gate.

## capabilities in depth

### patching & connections

all connections form by proximity — no menus, no cables:

- **generators** connect to the nearest effect in range, else straight to
  the output point (the white dot at the table center)
- **effects** chain toward the center: an effect connects to the next
  effect closer to the output point, else to the output point itself
- **controllers** (lfo, sequencer, midi) drive their closest non-global
  object
- **hardlink** (LINK mode, `K3`): pins two objects permanently, bright
  double line — a controller can drive a specific target regardless of
  distance
- **mute** (LINK mode, `K1+K3`): temporarily cuts a connection, dimmed
- audio connections are solid lines with bright dashes marching in the
  signal direction; control connections are dotted
- everything with a path to the output point is heard; the output point
  pulses at the current tempo

### tempo & sync

one BPM (`rot_tempo` param, 40–240) drives everything; the tempo object
puts it on the table (rotation = BPM) and the output point pulses it:

- **lfo**: `sync` + `mult` — period = N 32nd notes (1–128)
- **delay**: `sync` quantizes delay time to 32nd notes; `sweep` glides
  time changes
- **loop**: `sync` = start on the next 32nd/quarter/bar boundary
- **sequencer**: 32nd-note clock; per-step duration in 32nds

### the sequencer

16 steps × 6 stored patterns per object (rotation switches, header shows
`p1`–`p6`); per-step pitch (±24 st), velocity, and duration. targets:

- **oscillator / sampler**: plays the note (velocity → amp, ADSR gate)
- **any effect**: retriggers its param envelope (cutoff / feedback /
  dry-wet sweep)
- **random subtype**: improvises, snapped to the table tonality —
  with a restricted scale this is the original's "automatic solos";
  the steps page shows the improvised-note history live

### tonality

one tonality object sets the table's scale (root on rotation, first
object wins). it constrains sequencer notes, random improvisation, and
sampler/subs pitches. the scale itself is editable: 12 toggleable
degrees on the notes panel; subtypes are preset loads (major/minor/
pentatonic/chromatic) you can then customize.

### sound design extras

- **sub-oscillators** (oscillator): 4 subs × waveform/amp/detune/offset,
  with a follow-tonality toggle that snaps sub pitches to the scale
- **effect envelopes**: every effect has a sequencer-triggered ADSR on
  its signature parameter — idle-neutral by default
- **sampler**: single WAV pitched melodically; `base` tunes the sample's
  natural pitch in semitones from C4; instrument (gated ADSR) and drum
  (one-shot) subtypes
- **global FX** (output object): master reverb (mix + room) and
  compression on the output bus; neutral when the output object is absent
- **midi in**: notes land on the closest object (pitched or envelope
  trigger), rotation = transpose ±24 st

**visuals**: blocks carry a subtype pictogram on their rim (orbits with
rotation) and a slider dot on their right side (distance from center =
slider value, like the reactable's draggable dot); audio connections show
signal-flow dashes, control connections marching dots; the output point
pulses at the tempo; sounding objects get a VU bar under the glyph.

**config panels** (`K1+K3` on a selected object, E1 switches pages)

- **2D** (effects): E2/E3 = X/Y on the control surface
- **env** (oscillator, loop, sampler, and all effects): ADSR — E2 picks a
  stage, E3 adjusts. generators: amplitude envelope. effects: param
  envelope, retriggered by sequencer/MIDI notes — filter → cutoff,
  delay → feedback, modulator/waveshaper → dry-wet (page footer shows the
  target); default is idle-neutral (s=0), so it only moves when triggered
- **set** (lfo, delay, loop, sampler, output): tempo-sync & pitch/FX settings —
  E2 picks a field, E3 adjusts. lfo: `sync` on/off + `mult` (period in
  32nd notes); delay: `sync` (32nd-note quantize) + `sweep` (time glide);
  loop: `sync` immediate/quarter/bar (grid entry on load); sampler: `base`
  (the sample's natural pitch, in semitones from C4); output: global FX —
  `rev` (master reverb mix), `room`, `comp` (master compression)
- **steps** (sequencer): E2 step, E3 pitch (−24..+24), `K1+E3` velocity,
  `K3` toggles the step. random subtype: shows the improvised-note history
  (E3 = velocity). rotation (ROTATE mode, E2) switches 6 stored patterns —
  the header shows the active one (`p1`–`p6`)
- **subs** (oscillator): 4 sub-oscillators, E2 picks a field, E3 adjusts —
  `follow tonality` toggle (snaps sub pitches to the table's scale), then
  per sub: waveform, amp, detune (cents), offset (semitones)
- **notes** (tonality): the scale as 12 toggleable degrees — E2 picks,
  E3/`K3` toggles. subtype cycling reloads the preset (custom edits
  replaced); root still on rotation
- **vel** (sequencer): per-step velocity — E2 step, E3 value, `K3` toggles
- **dur** (sequencer): per-step length in 32nd notes (1–8; 2 = 16th) —
  E2 step, E3 value, `K3` toggles
- **browser** (loop, sampler): E2 scrolls `dust/audio`, `K3` loads;
  `>` marks the loaded file

tempo lives in PARAMETERS (40–240 BPM) — or on the table, via the tempo
object's rotation.

## patch slots

pan outside the table edge: 8 numbered slots in a ring.

- **long-press K3** empty slot → store the whole patch (objects, params,
  sequences, samples, links, tempo)
- **short press K3** occupied slot → recall
- **long-press K3** occupied slot → delete

slots persist as files (`~/dust/data/rotatable/slots/`) — they survive
restarts and reinstalls.

**factory presets** — the SYSTEM menu (`K1+K2+K3` held 1 s) has
`RESTORE PRESETS`, which overwrites all 16 slots with the bundled factory
set (with a confirm). the sixteen form a tutorial arc: each is a complete
musical sketch that also teaches one or two concepts.

| slot | name | BPM | teaches | what's in it |
|---|---|---|---|---|
| 1 | HELLO | 110 | proximity patching, rotation = pitch, slider dot = amp | saw osc + mono sequencer melody + tempo object |
| 2 | BEAT | 120 | sampler, hardlink (`LINK K3`), step editor, velocity | synth kick + clap, each with a hardlinked 16-step sequencer |
| 3 | KIT-808 | 124 | multiple hardlinks, mute (`LINK K1+K3`), output compression | TR-909 kick/snare/hat + clap, each own sequencer; muted alt-snare ready to unmute; comp 0.3 |
| 4 | KEY | 100 | tonality snapping, root key, editable scale mask | saw + sequencer + a *custom* harmonic-minor tonality — check its notes panel |
| 5 | SUB | 95 | suboscillators, LP filter, resonance slider | saw + 2 subs (octave-down follows tonality, detuned fifth) → LP, A-minor bassline |
| 6 | ACID | 128 | LFO controllers, tempo sync (mult), filter bite | saw → LP, saw LFO locked to quarter notes on the cutoff, minor tonality |
| 7 | PING | 100 | delay subtypes, pingpong, effect envelopes | clave + cowbell → tempo-quantized pingpong; a third sequencer's notes retrigger the delay's envelope so feedback swells |
| 8 | WASH | — | audio input, compressor, reverb delay, output FX | line in → compressor → reverb — run a radio/synth through the table (silent until you plug something in) |
| 9 | CHOIR | 60 | parallel generators at the output, chorus, vibrato LFO | cello + violin a fifth apart + sub-osc drone, chorus, whole-note LFO swell, big reverb |
| 10 | POLY | 108 | poly sequencer, pattern presets 1–6 (rotate to compare) | poly sequencer → trumpet, mono sequencer → noise "snare"; two contrasting patterns written into presets 1–2 |
| 11 | SOLO | 112 | random sequencer + pentatonic = automatic solos | random sequencer → theremin → chorus → feedback delay; every dice roll is in scale |
| 12 | DUB | 90 | loop player, quantized feedback delay, delay-time LFO | half-speed kick loop as bass pulse → dotted-eighth delay, slow LFO on delay time, roomy output |
| 13 | CRUSH | 96 | waveshaper resampler, HP filter, random LFO on dry-wet | double-time snare-stutter loop → bitcrusher → HP, crush amount wanders |
| 14 | PLUCK | 118 | instrument sampler + tonality, oneshot loops, call-and-response | mandolin and saxophone trade a D-minor melody (two sequencers), oneshot snare backbeat |
| 15 | ZOO | 80 | sound design: generators don't have to be musical | elephant → bandpass → pingpong call-and-response; double-time crickets as a shaker; quarter-speed bear-growl drone through the bitcrusher; frog one-shots |
| 16 | FINALE | 122 | everything at once | 15 objects: drum kit, tuba bass, horn stabs, theremin pad, A-minor tonality, full master FX — the demo you play people |

## dev

development branch: `main` (docs, plans, tooling). the default `release`
branch is what `;install` clones — script files only.
