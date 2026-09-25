# Rotatable — Project Notebook

*Running project notes. Plan: `plan.md` + `plan/phase-N/`. Session archives:
`prompt-archive/`. Project guide: `AGENTS.md`.*

**STATUS (2026-09-25): v1 feature-complete.** All 6 plan phases done; instrument
plays on the device. Pending: owner hands-on feel-check. v2 backlog in
`plan/phase-5/integration.md`.

---

## Working conventions (project owner's preferences)

- **Plans as Markdown with checkable todo lists** (`- [ ]` / `- [x]`) so progress is trackable.
- **Archives**: old plans go in `plan-archive/`, old prompts in `prompt-archive/` — both for posterity and as recovery insurance against context compaction losing the thread.
- **Small tasks, frequent writes**: break work into small pieces and write to file often, to avoid context exhaustion on large file writes and half-finished work.

## Vision (from the project owner)

### Multi-level navigation hierarchy
- Level 1: navigation of the table surface; deeper levels: place blocks from a
  menu, enter/configure blocks, move/rotate/connect objects.
- Table is **round**, **larger than the screen**. **E1 = Z (zoom), E2 = X,
  E3 = Y**; CCW negative, CW positive.
- **Vector display only** (arbitrary zoom); faint dotted grid for motion
  perception (clipped to the table); table edge = arc.
- **Lua = UI, SuperCollider = DSP**; replicate the Reactable sound objects as
  a runtime-patchable norns engine. **No webcam/computer vision** — objects are
  virtual. Mechanics design delegated to the assistant.

## Reference material

- `reference/` — full mirror of the original Reactable manual (2011), Markdown
  in `manual/md/`. See `reference/README.md`.
- reactable.com lives on as a founder-maintained legacy site (company dissolved
  2022); the mobile manual is live and filled the accelerometer/navigation gaps.

## Norns device access (verified 2026-09-24)

- Host `norns` @ IP in `.device/norns-ip-address`, user `we`, password in
  `.device/norns-ssh-credetials`. Reference those files; never copy secrets.
- SSH via Python paramiko (no sshpass/expect on desktop).
- Deploy: `tools/deploy.py`; testing API: `tools/api.py` (port 8787).
  Norns/engine gotchas: see AGENTS.md "Gotchas learned".

## Open questions — all resolved or moved to v2 backlog

(Interaction mechanics, level transitions, connection gestures, engine
architecture — all answered in `docs/interaction-design.md` and built.
Remaining deferred work is listed in `plan/phase-5/integration.md`.)

## Decisions log (chronological)

- 2026-09-24: Research → `docs/behavior-spec.md` (incl. §7 gap list, 20 items).
  Norns facts: no native dashed lines or screen.scale → hand-rolled grid +
  own world→screen transform; CroneEngine + bus dictionary is the pattern.
- 2026-09-24: **Interaction design APPROVED (v2)** — E1 CW = zoom in; LINK
  target = cycle by proximity; subtype = K1+E2; v1 scope = core 8 types;
  v1 panels = envelope + 2D.
- 2026-09-24: **Phase 1** — dev loop working (deploy/load/screenshot).
  Matron REPL: ws :5555, plain-text Lua, newline-terminated (norns#1084).
- 2026-09-24: **Phase 2** — renderer verified (glyphs, proximity connections).
- 2026-09-24: **Phase 3** — interaction hierarchy verified on device.
- 2026-09-25: **Key map v3 (owner)** — K1 tap = system menu; K2 = BACK;
  K3 = action; K1+K3 = shifted; K1+K2 = remove. Lesson: verify multi-step
  REPL flows as ONE Lua chunk (matron reorders rapid separate messages).
- 2026-09-25: **Phase 4 engine verified** — Engine_Rotatable + audio.lua glue;
  poll-verified signal flow. Engine lessons in AGENTS.md gotchas.
- 2026-09-25: Filter "no effect" = sine single-partial perception; engine fine.
- 2026-09-25: **REST testing API** (owner idea) — `tools/api.py`.
- 2026-09-25: **Panels + loop player fixed** — step editor + sample browser;
  `load`→`loadbuf` (Engine.load collision, "missing N"); Phasor+BufRd +
  silentBuf. Effect-chain rule fixed (effects connect toward output point).
- 2026-09-25: **Patch slots (owner feature)** — 8-slot ring at r=1.18;
  long-press K3 = store/delete, short = recall. 40 drum one-shots pulled from
  archive.org into `dust/audio/rotatable-drums/`.
- 2026-09-25: **Scope-sensitive delete (owner request)** — K1+K2 in L2 removes selected block (existed); K1+K2 at L1 arms table-clear with status-line confirm (K3 yes / K2 no). Verified: arm/cancel/confirm. Rejected: trash icons (screen cost), extra nav layer (complexity), long-press (slot conflict). Future option: drag-off-rim removal. Multi-circuit demo patch (3 independent chains) saved to slot 1.
- 2026-09-25: **E1 object-hop in MOVE mode (owner feature)** — cycles selection through objects, centering the camera on each; status hint "E1 hop". Verified: hop cycles all objects both directions, camera follows. Also: REST API completed with `/set /load /step` direct-manipulation endpoints; `tools/djset.py` + `tools/seqjam.py` performance scripts exist (lessons: discover fresh ids from /state, deploy-reload wipes table).
- 2026-09-25: **Phase 5 polish done** — CPU avg 16%/peak 17%; overlap fixes;
  README.md. v1 complete pending owner feel-check.
