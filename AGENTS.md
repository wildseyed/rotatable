# AGENTS.md — Rotatable

A Reactable emulator for the Monome Norns. This file is the project guide for
AI agents (and humans) working in this repo.

## Project overview

The [Reactable](https://en.wikipedia.org/wiki/Reactable) (Reactable Systems,
Barcelona, defunct) is a tangible music table: acrylic objects on a camera-
tracked surface act as synthesizer modules (generators, effects, controllers),
patched by proximity and rotation. **Rotatable** recreates it on Norns —
virtually, with no camera: objects are placed and manipulated entirely through
Norns' 3 encoders + 3 buttons on its 128×64 screen.

## Architecture

Norns' standard split applies:

- **Lua** (`lib/`, main script) — all UI: vector rendering of the round table,
  zoom/pan navigation, multi-level interaction hierarchy, menus, object
  placement/movement/rotation/connections.
- **SuperCollider** (engine) — all DSP, replicating the Reactable sound-object
  set: oscillator, loop, sampler, audio-in, filter, delay, modulator,
  waveshaper, LFO, sequencer, tonality, output. Runtime-patchable node graph.
- Communication: standard Norns engine/OSC plumbing.

No computer vision. reacTIVision/TUIO is **not** part of this project.

## Key interaction decisions (so far)

- Multi-level hierarchy: L1 table navigation (E1=zoom, E2=X, E3=Y; CCW negative,
  CW positive) → block selection menu → object manipulation (move/rotate/
  connect) → block configuration.
- Vector graphics only (no bitmaps); table renders at arbitrary zoom. Faint
  dashed/dotted grid superimposed for motion perception; table edge is an arc.
- Full behavior spec source: `reference/` (mirror of the original 2011 manual;
  see `reference/README.md`).

## Working conventions (project owner's rules)

- Plans live in Markdown files with **checkable todo lists** (`- [ ]` / `- [x]`);
  keep them updated as work progresses.
- Archive superseded plans in `plan-archive/` and session prompts/braindumps in
  `prompt-archive/`.
- `notebook.md` is the running project notebook — keep it current.
- **Small tasks, frequent file writes.** Never produce giant single-write
  files; break work into pieces to survive context limits.
- Do not start coding until the plan is approved by the project owner.

## Testing / deployment

- Target hardware: a real Norns with SSH access — **verified reachable** at the
  IP in `.device/norns-ip-address` with credentials in
  `.device/norns-ssh-credetials` (reference those files; never copy the
  password elsewhere). SSH from the dev machine via Python `paramiko`
  (no `sshpass`/`expect` installed).
- **Deploy**: `python3 tools/deploy.py [--load] [--shot]` — SFTP-syncs
  `rotatable/` to `~/dust/code/rotatable`, optionally loads the script via
  matron's websocket REPL (`ws://<host>:5555`, subprotocol
  `bus.sp.nanomsg.org`, plain-text Lua **newline-terminated**; replies are
  NUL-terminated), optionally pulls a screenshot to `/tmp/norns.png`.
- `screen.export_screenshot('name')` writes `~/dust/data/<script>/name.png`.
- **REST testing API** (owner request): `python3 tools/api.py [port]`
  (default 8787, localhost). GET: `/state` `/amps`. POST, direct
  manipulation: `/place /move /rotate /set /load /step /mute /remove /clear`.
  POST, UI simulation (goes through the interaction state machine):
  `/key /enc`. Escape hatch: `/lua`. Each call is one ws message (ordering
  preserved). State JSON comes from `T.state()` in the script.
- Norns conventions: scripts live in `~/dust/code/`, engines in
  `~/dust/code/<script>/lib/` or the engine dir; use `matron`/screen API for
  drawing and standard engine registration for SC.
- **Gotchas learned**: (1) never name an engine command `load` — it collides
  with `Engine.load` and fails as `SCRIPT ERROR: missing <arg>`; we use
  `loadbuf`. (2) Engine synths must live in `context.xg` or amp polls don't
  see them; audio buses zero per block so writers must `moveBefore` readers.
  (3) Changing an engine `.sc` needs the full ordered restart:
  `systemctl restart norns-jack`, wait 5 s, then
  `norns-sclang norns-crone norns-matron`; subset restarts wedge jackd.
  (4) PlayBuf needs a trigger edge (easy to miss at synth start); Phasor+BufRd
  avoids the whole problem. (5) Default `buf=0` poisons BufRateScale with NaN —
  always start buffer synths on a real silent buffer.

## Repo layout

```
rotatable.lua       main script (repo root = installable script dir)
lib/                world/ui/render/audio/slots + Engine_Rotatable.sc
README.md           user-facing usage + install docs
notebook.md         running notes/braindump (authoritative current state)
plan.md             milestone index only — links into plan/
plan/phase-N/       detailed checkable todo lists (small files, edit freely)
plan-archive/       superseded plans
prompt-archive/     archived session prompts/braindumps
docs/               behavior-spec.md, interaction-design.md (approved designs)
reference/          original Reactable manual mirror (read-only)
tools/              deploy.py, api.py, djset.py, seqjam.py
.device/            device IP/credentials (never copy secrets elsewhere)
```

The repo root IS the norns script (community-publish layout, required for
maiden `;install`): `rotatable.lua` + `lib/` at root.
