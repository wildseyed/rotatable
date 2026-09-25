# Rotatable — Working Plan

*A Reactable emulator for Monome Norns. This file is the milestone index only;
detailed checkable todo lists live in `plan/phase-N/*.md` — edit those freely,
add new files as work evolves, and keep this index stable.*

## Milestones

- [x] **Phase 0 — Groundwork** → `plan/phase-0/`
  - [x] [behavior-spec](plan/phase-0/behavior-spec.md) — manual + research → `docs/behavior-spec.md`
  - [x] [interaction-design](plan/phase-0/interaction-design.md) — **approved 2026-09-24** → `docs/interaction-design.md` v2
- [~] **Phase 1 — Dev loop & hello world** → [dev-loop](plan/phase-1/dev-loop.md) — deploy/load/screenshot verified on device; only encoder-feel tuning (owner, on hardware) remains
- [x] **Phase 2 — Table renderer & navigation (Lua)** → [renderer](plan/phase-2/renderer.md) — verified on device; 2 polish items parked
- [x] **Phase 3 — Interaction hierarchy (Lua)** → [interaction](plan/phase-3/interaction.md) — all modes verified on device via REPL-driven tests
- [x] **Phase 4 — Audio engine (SuperCollider)** → [engine](plan/phase-4/engine.md) — verified via device polls; loop player & mod character untested; owner listening check pending
- [x] **Panels: sequencer step editor + loop sample browser** (owner-prioritized gap, 2026-09-25) — built and verified
- [x] **Patch slots** → [patch-slots](plan/phase-5/patch-slots.md) — implemented & REPL-verified; owner feel-check pending
- [x] **Phase 5 — Integration & polish** → [integration](plan/phase-5/integration.md) — CPU 16%, polish fixes, README; owner feel-check pending; v2 backlog listed

## Parking lot (undecided / later)

- Grid/MIDI controller support
- Sequencer/tonality depth vs. original
- Accelerometer-object equivalent (norns has no tilt; maybe arc?)
- ROTOR-era ideas worth backporting?

## Conventions

- Plans: Markdown, checkable todos, small files, frequent writes.
- Superseded plan files → `plan-archive/`; session prompts → `prompt-archive/`.
- `notebook.md` = running notes; `AGENTS.md` = project guide. Keep both current.
