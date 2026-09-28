# rotatable

a [Reactable](https://en.wikipedia.org/wiki/Reactable) emulator for monome norns —
the tangible table synth, recreated virtually: no camera, no pucks, just the
round table on screen, patched by proximity, driven by 3 encoders + 3 keys.

**v1.1.0** · [github](https://github.com/wildseyed/rotatable) · [discussion](https://github.com/wildseyed/rotatable/discussions)

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
- **ROTATE**: E2 = main param, E3 = secondary param, `K1+E2` = subtype
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
| loop | generator | playback rate | amp | loop (browser panel) |
| filter | effect | cutoff | resonance | lp / bp / hp |
| delay | effect | time | feedback | feedback |
| modulator | effect | main (pitch/depth/rate) | dry-wet | ring / chorus / flanger |
| lfo | controller | rate | depth | sine / saw / square / random |
| sequencer | controller | pattern preset (1–6) | — | mono / poly / random |
| output | global | master volume | — | — (the star; never connects) |

**config panels** (`K1+K3` on a selected object, E1 switches pages)

- **2D** (effects): E2/E3 = X/Y on the control surface
- **env** (all): ADSR — E2 picks a stage, E3 adjusts
- **set** (lfo, delay, loop, sampler): tempo-sync & pitch settings —
  E2 picks a field, E3 adjusts. lfo: `sync` on/off + `mult` (period in
  32nd notes); delay: `sync` (32nd-note quantize) + `sweep` (time glide);
  loop: `sync` immediate/quarter/bar (grid entry on load); sampler: `base`
  (the sample's natural pitch, in semitones from C4)
- **steps** (sequencer): E2 step, E3 pitch (−24..+24), `K1+E3` velocity,
  `K3` toggles the step. random subtype: shows the improvised-note history
  (E3 = velocity). rotation (ROTATE mode, E2) switches 6 stored patterns —
  the header shows the active one (`p1`–`p6`)
- **vel** (sequencer): per-step velocity — E2 step, E3 value, `K3` toggles
- **dur** (sequencer): per-step length in 32nd notes (1–8; 2 = 16th) —
  E2 step, E3 value, `K3` toggles
- **browser** (loop, sampler): E2 scrolls `dust/audio`, `K3` loads;
  `>` marks the loaded file

tempo lives in PARAMETERS (40–240 BPM).

## patch slots

pan outside the table edge: 8 numbered slots in a ring.

- **long-press K3** empty slot → store the whole patch (objects, params,
  sequences, samples, links, tempo)
- **short press K3** occupied slot → recall
- **long-press K3** occupied slot → delete

slots persist as files (`~/dust/data/rotatable/slots/`) — they survive
restarts and reinstalls.

**factory presets** — the SYSTEM menu (`K1+K2+K3` held 1 s) has
`RESTORE PRESETS`, which overwrites all 8 slots with the bundled factory
set (with a confirm). the eight:

| slot | name | what's in it |
|---|---|---|
| 1 | KIT-808 | kick/snare/hat drum samplers, each with its own 16-step sequencer (hardlinked), 124 BPM |
| 2 | ACID | saw osc → resonant LP, minor tonality snapping the sequencer, tempo-synced LFO on cutoff, 128 BPM |
| 3 | DUB | looped kick as pulsing bass → tempo-quantized feedback delay, slow LFO on delay time, 90 BPM |
| 4 | PING | rim sampler → pingpong delay, syncopated sequencer, 100 BPM |
| 5 | SOLO | random sequencer → square osc → chorus, pentatonic tonality ("automatic solos"), 112 BPM |
| 6 | CRUSH | snare-stutter loop → bitcrusher → HP filter, random LFO on dry-wet, 96 BPM |
| 7 | WASH | line in → compressor → reverb — run external gear through the table |
| 8 | CHOIR | two sines a fifth apart → chorus → reverb, slow synced vibrato, 60 BPM |

## dev

development branch: `main` (docs, plans, tooling). the default `release`
branch is what `;install` clones — script files only.
