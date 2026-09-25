# Rotatable — Interaction Design (v3, approved)

*How the Reactable's multi-touch/tangible model maps onto Norns' 3 encoders
(E1–E3) + 3 keys (K1–K3) at 128×64. Status: **approved by owner 2026-09-24;
key map revised 2026-09-25** — decisions in §5 are settled. Behavior of the
original: `docs/behavior-spec.md`.*

## 0. Design principles

1. **The camera is the cursor.** Navigation moves a viewport over the table; a
   fixed reticle at screen center is "where your hand is". Selecting, placing,
   and connecting all happen relative to the reticle. This unifies navigation
   with manipulation — no separate cursor level needed.
2. **Proximity does the patching.** The original forms all connections
   automatically by distance. We keep that: you never "draw cables"; you move
   objects and the patch follows. This removes the hardest no-touch problem
   (connection gestures) entirely.
3. **Rotation is the primary gesture** of the original, so rotation gets the
   most accessible encoder assignment at object level.
4. **K3 acts, K2 retreats, K1 modifies.** K1 is a *held* shift only — its short
   tap is reserved for the norns system menu per platform convention.
5. **Encoder accel/sensitivity is built into norns** (`norns.enc.accel/sens`);
   we lean on it instead of inventing fine/coarse modes.

## 1. Level hierarchy

```
L0 PLACE MENU ──⇄ L1 NAVIGATE (default) ──⇄ L2 OBJECT ──⇄ L3 CONFIG (panels)
                  (camera: zoom/pan)        (one object     (parameter pages,
                ^K3 opens place menu         selected)       original "panels")
```

- **Act/confirm**: K3. **Shifted action**: K1+K3. **Back**: K2 — consistent
  everywhere; K2 at L1 does nothing.
- Current level + mode shown in a slim status line (bottom, 8 px).

### L1 — NAVIGATE (top level)
| Control | Action |
|---|---|
| E1 | Zoom (CCW out / CW in — Z axis; CCW negative per spec) |
| E2 | Pan X |
| E3 | Pan Y |
| K3 | Select object nearest reticle → **L2** (if none: nothing) |
| K1+K3 | Open **PLACE menu** (L0) |
| K1 | shift (hold); tap = norns system menu |

Rendering: round table edge as arc, faint dotted grid (motion reference),
objects as vector glyphs with subtype marks, audio vs control connections as
distinct line styles, output point pulsing at tempo.

### L0 — PLACE MENU
- Overlay list of object types (8 in v1), grouped by category (Generators /
  Effects / Controllers / Globals), windowed scrolling.
- E2 scrolls list, K3 places at reticle → enters **L2 MOVE mode** with the new
  object selected (so you can immediately position it). K2 cancels.

### L2 — OBJECT (one object selected, highlighted + name shown)
Three modes, cycled by **K3** (except in LINK, where K3 acts); mode shown in
status line:

| Mode | E1 | E2 | E3 |
|---|---|---|---|
| **MOVE** (default) | hop selection, center camera | object X | object Y |
| **ROTATE** | — | rotation = primary param | right-dot param (amplitude / dry-wet / feedback / depth) |
| **LINK** | — | choose target (cycle objects by proximity) | — |

- MOVE is where patching happens: proximity connections form/break live and
  are drawn as they change.
- ROTATE reproduces the original two-axis mapping: **rotation + finger dot**.
  (Rotation on generators also re-triggers envelope/note, as in the original.)
- LINK mode covers the explicit connection actions:
  - K3 = toggle **hardlink** to the chosen target (bright double line).
  - K1+K3 in LINK = toggle **mute/cut** of that connection (dimmed).
- K1+K3 (in MOVE/ROTATE) → **L3 CONFIG**. K2 → back to L1.
- K1+K2 in L2: **remove object** (shift+back = delete; no long-press timing).
- Subtype change: in ROTATE mode, K1+E2 (shift+encoder) cycles subtypes —
  replaces the original "drag icon left" gesture.

### L3 — CONFIG (the original's panels)
- E1 selects **page** (v1: 2D Control for effects, Envelope for all; later:
  Sequence, Velocity, Step Duration, Suboscillators, Browser, Settings).
- E2/E3 edit: on **2D Control** pages E2=X, E3=Y (exactly the original);
  on **Envelope** E2 selects slider (A/D/S/R), E3 adjusts.
- **Sequencer** pages (later): E1 selects step (1–16), E2 pitch (−12..+12),
  E3 velocity; K3 toggles step enable.
- K2 → back to L2.

## 2. Automatic behaviors kept from the original

- Connections form/break by proximity; controller targets its **closest**
  object unless hardlinked; effects on a generator's line auto-insert.
- Output point at table center pulses at tempo; everything routed to it sounds.
- Patch switch (Song Settings) never stops audio; objects keep settings until
  re-placed. (v1 may simplify: full set save/load via norns PSET-style files.)

## 3. Rendering notes (from norns API research)

- No native dashed lines (cairo dash not exposed) → **hand-draw dotted grid**
  as short segments; cheap at our grid density.
- No `screen.scale` → **our own world→screen transform** in Lua:
  `sx = (wx - cam_x) * zoom + 64`, `sy = (wy - cam_y) * zoom + 32`. All
  geometry stored in world units (table radius = 1.0 nominal).
- `screen.arc/circle/line` + float `line_width` + 16 levels suffice for all
  glyphs; 15 fps redraw metro with dirty-flag (redraw on change only).
- `screen.text_rotate` available for rotated labels; tiny bitmap fonts
  (tom-thumb/scientifica) suit 128×64.

## 4. Engine architecture (from norns research)

- `Engine_Rotatable : CroneEngine` in `lib/Engine_Rotatable.sc`; Lua calls
  `engine.add_object(type, id)`, `engine.connect(id_a, id_b, kind)`,
  `engine.set(id, param, value)` etc. via `addCommand`.
- Per-object = one synth on a **Dictionary of audio/control buses**, Group-
  ordered — the documented runtime-patch pattern (engine-study-3, mx.synths).
- Control connections = control buses mapped to target synth args.
- Budget: CM3 handles dozens of modest nodes; cap ~16 objects v1, meter with
  `cpu_avg` polls during dev. Polls can return per-object levels for visuals.

## 5. Decisions (resolved 2026-09-24, owner-approved)

1. **Zoom**: E1 CW (positive) = zoom **in**, CCW = zoom out.
2. **LINK target**: E2 cycles objects by proximity to the selected one.
3. ~~Remove object: long-press K3~~ → superseded by key remap below.
4. **Subtype change**: K1+E2 in ROTATE mode cycles subtypes.
5. **v1 scope**: core 8 object types — oscillator, loop player, filter, delay,
   modulator, LFO, sequencer, output. Remaining 6 (sampler, waveshaper,
   audio-in, MIDI-in, tonality, song settings) in later iterations.
6. **v1 panels**: envelope + 2D control first; sequencer step editors,
   browsers, suboscillators follow.

## 5b. Key-map revision (2026-09-25, owner-approved)

Rationale: K1's short tap is the norns system-menu convention, so it must not
carry "back". New map:

- **K1** = shift (held only; tap untouched for the system menu)
- **K2** = BACK everywhere (L3→L2, L2→L1, L0→L1)
- **K3** = ACTION/confirm (select, place, cycle mode, hardlink in LINK)
- **K1+K3** = shifted action (open place menu at L1, dive into L3, mute in LINK)
- **K1+K2** = delete at current scope: in L2, remove the selected object;
  at L1, arm table-clear with confirm (`K3` confirms, `K2` cancels).
- Mnemonic: **K3 acts, K2 retreats, K1 modifies.**

Status: **approved — coding phases unlocked.**
