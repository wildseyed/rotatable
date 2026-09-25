# rotatable

a [Reactable](https://en.wikipedia.org/wiki/Reactable) emulator for monome norns —
the tangible table synth, recreated virtually: no camera, no pucks, just the
round table on screen, patched by proximity, driven by 3 encoders + 3 keys.

## the idea

objects on a round table are synth modules. move them close together and they
connect: generators feed effects, effects chain toward the output point at the
table center, controllers (LFO, sequencer) drive their closest neighbor.
everything connected to the center dot is heard.

## quick start

1. `K1+K3` opens the **place menu**; E2 scrolls, `K3` places at the reticle
2. the new object is auto-selected: E2/E3 **move** it (watch connections form)
3. `K3` cycles modes: **MOVE → ROTATE → LINK**
   - MOVE: E2/E3 move the object, **E1 hops selection between objects,
     centering the camera on each**
   - ROTATE: E2 = main param (pitch/cutoff/time/freq/volume), E3 = amp /
     dry-wet / feedback / depth, `K1+E2` = subtype
   - LINK: E2 picks a target, `K3` = hardlink (permanent), `K1+K3` = mute
4. `K1+K3` dives into **config** (L3): E1 switches pages, E2/E3 edit
   - effects: 2D control surface
   - everything: ADSR envelope
   - sequencer: 16-step editor (E2 step, E3 pitch, K1+E3 velocity, K3 on/off)
   - loop: sample browser (E2 scroll, K3 loads; `>` marks the loaded file)
5. `K2` backs out, everywhere. **`K1+K2` deletes at the current scope**:
   in L2 it removes the selected object; at L1 it arms **clear table**
   (status asks `CLEAR TABLE? K3 yes / K2 no`).

## patch slots

pan outside the table edge: 8 numbered slots in a ring.

- **long-press K3** empty slot → store the whole patch (objects, params,
  sequences, samples, links, tempo)
- **short press K3** occupied slot → recall
- **long-press K3** occupied slot → delete

## object types (v1)

generators: **oscillator** (sine/saw/square/noise), **loop** (WAV player)
effects: **filter** (lp/bp/hp), **delay**, **modulator** (ring/chorus/flanger)
controllers: **lfo**, **sequencer** (16 steps, tempo-synced via global tempo)
globals: **output** (master volume; never connects — the star)

tempo lives in PARAMETERS (40–240 BPM).

## install

on your norns, in maiden's REPL:

```
;install https://github.com/wildseyed/rotatable
```

then SYSTEM > RESTART (first run compiles the engine), and SELECT > rotatable.

samples for the loop browser: drop WAVs anywhere under `~/dust/audio/`.

## dev

see `AGENTS.md` — deploy tooling (`tools/deploy.py`), REST testing API
(`tools/api.py`), behavior spec and interaction design in `docs/`.
