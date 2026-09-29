# rotatable

a [Reactable](https://en.wikipedia.org/wiki/Reactable) emulator for monome norns —
the tangible table synth, recreated virtually: no camera, no pucks, just the
round table on screen, patched by proximity, driven by 3 encoders + 3 keys.

**v3.2.0** · [github](https://github.com/wildseyed/rotatable) · [discussion](https://github.com/wildseyed/rotatable/discussions)

**new in v3.1**: **16 factory presets** — a tutorial arc of full musical
tables, with a bundled sample library (synthesized drums, orchestral
instruments, animal sounds; sources in `presets/audio/SOURCES.md`) ·
K1+E1 preset navigation (the camera flies slot to slot; K3 loads) ·
stability: sequencer-clock watchdog, engine-leak fix · block settings
guide + guided preset tour below

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
  form/break live as it slides); the camera tracks the block so it stays
  under the reticle
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

## block settings guide

every block works the same way: **K3** on a selected block cycles
MOVE → ROTATE → LINK, **`K1+K3`** dives into its config panels, `K2`
backs out, `K1+K2` deletes the block. in ROTATE: **E2** is the block's
main knob (rotation), **E3** is the slider dot, **`K1+E3`** is a fine
adjust, **`K1+E2`** cycles subtypes. inside the panels: **E1** switches
page, **E2** picks a field, **E3** edits it, `K1+E2` still cycles
subtypes.

per block (rotation / slider / subtypes, then its panels):

- **oscillator** — pitch (55–880 Hz) / amp / sine·saw·square·noise (noise:
  rotation = lowpass cutoff). panels: **subs** (4 sub-oscillators; first
  field is a `follow` toggle that snaps sub pitches to the table tonality,
  then per sub: waveform, amp — 0 = off, detune in cents, offset in
  semitones) and **env** (amplitude ADSR, gated by incoming sequencer/MIDI
  notes; without a controller the osc drones at the sustain level, with
  one: low sustain + short decay = plucks).
- **loop** — playback rate (0.25–4×) / amp / loop·oneshot. panels:
  **browser** (scroll `dust/audio`, `K3` loads), **set** (`sync`: restart
  on the next quarter/bar boundary — keeps loops in phase), **env**.
  tips: rate < 0.5 turns drum hits into bass drones (ZOO); oneshot
  fires the whole sample once per trigger instead of free-running.
- **sampler** — played pitch / amp / instrument·drum. panels: **browser**,
  **set** (`base`: the loaded sample's natural pitch — set this to the
  WAV's note so sequenced pitches play in tune; the bundled instruments
  carry it in the filename, e.g. `cello_G3`), **env**. instrument is a
  gated melodic voice; drum is a one-shot that ignores pitch-off.
- **input** — gain / — / line only. no panels. route: INPUT block →
  compressor → reverb (see WASH).
- **filter** — cutoff (40 Hz–12 kHz) / resonance / lp·bp·hp. panels:
  **2d** (X = cutoff, Y = resonance), **env** (param envelope → cutoff;
  triggered by a connected sequencer, it gives the ACID-style bite —
  attack instant, short decay, sustain 0).
- **delay** — time (0.01–2 s) / feedback / feedback·pingpong·reverb
  (reverb: rotation = room size, feedback = mix). panels: **2d** (time /
  feedback), **set** (`sync` quantizes time to 32nd notes of the tempo —
  the rhythmic-delay trick; `sweep` glides time changes like tape), **env**
  (param envelope → feedback; a sequencer targeting the delay makes the
  echoes swell, see PING).
- **modulator** — effect character / dry-wet / ring·chorus·flanger
  (ring: rotation = mod frequency; chorus/flanger: rotation = rate).
  panels: **2d**, **env** (→ dry-wet).
- **waveshaper** — effect amount / dry-wet / resampler·compressor·
  distortion (resampler = bitcrush). panels: **2d**, **env** (→ dry-wet).
- **lfo** — rate / depth / sine·saw·square·random. panel: **set**
  (`sync` locks the rate to the tempo; `mult` = period in 32nd notes —
  8 = quarter note, 32 = whole note). an LFO modulates its closest block's
  signature parameter (pitch, cutoff, time, dry-wet...); hardlink it to
  choose the target.
- **sequencer** — rotation switches 6 stored patterns (`p1`–`p6` in the
  header) / — / mono·poly·random. panels: **steps** (E2 step, E3 pitch
  ±24 st, `K1+E3` velocity, `K3` toggle), **vel**, **dur** (step length in
  32nds, 1–8; 2 = a 16th). random subtype improvises into the tonality;
  its steps page shows the note history it has played.
- **midi** — transpose ±24 st / — / in only. no panels; vport + channel
  live in PARAMETERS.
- **tonality** — root key / — / major·minor·pentatonic·chromatic. panel:
  **notes** — the scale as 12 toggleable degrees (E2 picks, E3/`K3`
  toggles). subtypes load presets you can then customize; your edit
  survives saving, cycling the subtype reloads the preset.
- **tempo** — BPM (40–240) on rotation; the glyph shows the value. no
  panels.
- **output** — master volume on rotation (the star; never connects).
  panel: **set** — global FX: `rev` (master reverb mix), `room` (reverb
  size), `comp` (master compression). neutral when absent.

tempo lives in PARAMETERS (40–240 BPM) — or on the table, via the tempo
object's rotation.

## patch slots

pan outside the table edge: 16 numbered slots in a ring. the boxes are
world-fixed like blocks — they grow as you zoom in, so they stay visible
landing targets when navigating way zoomed in.

- **long-press K3** empty slot → store the whole patch (objects, params,
  sequences, samples, links, tempo)
- **short press K3** occupied slot → recall
- **long-press K3** occupied slot → delete
- **K1+E1** → move a slot focus without loading: the camera flies to
  center each focused slot on screen (status line shows `SLOT n`);
  **K3** loads the focused slot. quick A/B: flick to a slot, K3, flick
  back, K3. any plain camera move (E1/E2/E3) dismisses the focus

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
| 12 | STACK | — | multiple generators into one effect, detune = width, sub stacking | saw + detuned square + sine sub-bass, each with sub-oscillators, stacked into one LP filter; slow LFO drifts the cutoff |
| 13 | CRUSH | 96 | waveshaper resampler, HP filter, random LFO on dry-wet | double-time snare-stutter loop → bitcrusher → HP, crush amount wanders |
| 14 | PLUCK | 118 | instrument sampler + tonality, oneshot loops, call-and-response | mandolin and saxophone trade a D-minor melody (two sequencers), oneshot snare backbeat |
| 15 | ZOO | 80 | sound design: generators don't have to be musical | elephant → bandpass → pingpong call-and-response; double-time crickets as a shaker; quarter-speed bear-growl drone through the bitcrusher; frog one-shots |
| 16 | FINALE | 122 | everything at once | 15 objects: drum kit, tuba bass, horn stabs, theremin pad, A-minor tonality, full master FX — the demo you play people |

**playing the presets** — a tour, in order; each "try" uses the gestures
from the block settings guide above:

1. **HELLO** — the minimum viable table. try: rotate the osc while the
   melody plays (E2 in ROTATE), then rotate the tempo object. move the
   sequencer far from the osc and the melody stops — proximity *is* the
   patch cable.
2. **BEAT** — your first drum machine. try: `^K3` into the kick
   sequencer's steps page; `K3` toggles steps, `K1+E3` sets velocity —
   the ghost kicks are at vel ~0.3.
3. **KIT-808** — the full kit. try: find the dimmed connection to the
   second snare — in LINK mode on the alt snare's sequencer, `K1+K3`
   unmutes it. then check the output's set page for the glue compression.
4. **KEY** — pitch discipline. try: open the tonality's notes page and
   toggle degree `6` (the raised 7th that makes it *harmonic* minor);
   rotate the tonality to transpose the whole table.
5. **SUB** — low end. try: the osc's subs page — raise sub 1's amp and
   the bass gets a floor; the filter's slider (E3) is resonance.
6. **ACID** — the LFO as an invisible hand. try: the LFO's set page —
   `mult` 8 → 32 slows the sweep to a whole note; its slider is depth.
   break the hardlink (LINK, `K3`) and the LFO wanders to nearer blocks.
7. **PING** — rhythmic echo. try: the delay's set page — `sync` off frees
   the time knob from the grid; `sweep` up for tape-style pitch glides.
   the third sequencer only exists to poke the delay's envelope.
8. **WASH** — the table as an effects box. try: plug a phone/synth into
   line in; input rotation is gain, the compressor's slider is dry-wet,
   output `rev` on its set page. (silent until then — that's correct.)
9. **CHOIR** — patience. try: nothing, for a minute — the vibrato LFO has
   a whole-note period. then open the chorus 2d page and push depth up.
10. **POLY** — chords from one sequencer. try: rotate the poly sequencer
    (E2) from p1 to p2 — two contrasting rhythms were written in for you.
11. **SOLO** — hands off. try: nothing — the random sequencer improvises
    and the pentatonic tonality keeps every roll musical. open its steps
    page to watch the note history appear. raise the delay's feedback
    slider for a longer trail.
12. **STACK** — width from numbers. try: rotate any oscillator to retune
    its stack; the subs follow the A-minor tonality. nudge one osc away
    from the filter and it patches straight to the output — an unfiltered
    layer. the LFO on the cutoff is the slow breathe.
13. **CRUSH** — deliberate ugliness. try: the random LFO is modulating the
    bitcrusher's dry-wet — watch the connection dots. filter rotation
    (HP) decides how much of the dirt survives.
14. **PLUCK** — a duet. try: edit a pitch in the mandolin's steps page and
    hear the tonality snap it into D minor; the sax answers every second
    bar. the snare is a oneshot loop — one trigger, one hit.
15. **ZOO** — the weird one. try: rotate the crickets loop — rate 2 is a
    shaker, rate 0.5 is a swamp. the elephant goes through a bandpass and
    a pingpong; the bear drone is a loop at quarter speed into the
    bitcrusher.
16. **FINALE** — perform it. try: mute parts in LINK mode (`K1+K3`) and
    bring them back; ride the output's rotation (master volume); the
    master reverb/compression live on the output's set page.

## dev

development branch: `main` (docs, plans, tooling). the default `release`
branch is what `;install` clones — script files only.
