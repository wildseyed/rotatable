# rotatable

a [Reactable](https://en.wikipedia.org/wiki/Reactable) emulator for monome norns —
the tangible table synth, recreated virtually: no camera, no pucks, just the
round table on screen, patched by proximity, driven by 3 encoders + 3 keys.

**v1.0.0** · [lines thread](https://llllllll.co/t/rotatable-a-reactable-emulator/75521) · [github](https://github.com/wildseyed/rotatable)

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

**L2 modes**

- **MOVE**: E2/E3 drag the object (connections form/break live);
  **E1 hops selection between objects, centering the camera on each**
- **ROTATE**: E2 = main param, E3 = secondary param, `K1+E2` = subtype
- **LINK**: E2 cycles targets by proximity; `K3` toggles hardlink
  (permanent, bright line); `K1+K3` mutes the connection (dimmed)

## object reference

| object | role | rotation (E2) | E3 | subtypes (K1+E2) |
|---|---|---|---|---|
| oscillator | generator | pitch | amp | sine / saw / square / noise |
| loop | generator | playback rate | amp | loop (browser panel) |
| filter | effect | cutoff | resonance | lp / bp / hp |
| delay | effect | time | feedback | feedback |
| modulator | effect | main (pitch/depth/rate) | dry-wet | ring / chorus / flanger |
| lfo | controller | rate | depth | sine / saw / square / random |
| sequencer | controller | preset slot | — | mono (step editor) |
| output | global | master volume | — | — (the star; never connects) |

**config panels** (`K1+K3` on a selected object, E1 switches pages)

- **2D** (effects): E2/E3 = X/Y on the control surface
- **env** (all): ADSR — E2 picks a stage, E3 adjusts
- **steps** (sequencer): E2 step, E3 pitch (−12..+12), `K1+E3` velocity,
  `K3` toggles the step
- **browser** (loop): E2 scrolls `dust/audio`, `K3` loads;
  `>` marks the loaded file

tempo lives in PARAMETERS (40–240 BPM).

## patch slots

pan outside the table edge: 8 numbered slots in a ring.

- **long-press K3** empty slot → store the whole patch (objects, params,
  sequences, samples, links, tempo)
- **short press K3** occupied slot → recall
- **long-press K3** occupied slot → delete

## dev

development branch: `main` (docs, plans, tooling). the default `release`
branch is what `;install` clones — script files only.
