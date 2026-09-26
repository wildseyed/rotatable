# Rotatable — Working Plan

*A Reactable emulator for Monome Norns. This file is the milestone index only;
detailed checkable todo lists live in `plan/phase-N/*.md` — edit those freely,
add new files as work evolves, and keep this index stable.*

## Milestones

### v1 (complete)
- [x] **Phase 0 — Groundwork** → `plan/phase-0/`
  - [x] [behavior-spec](plan/phase-0/behavior-spec.md) — manual + research → `docs/behavior-spec.md`
  - [x] [interaction-design](plan/phase-0/interaction-design.md) — **approved 2026-09-24** → `docs/interaction-design.md` v2
- [x] **Phase 1 — Dev loop & hello world** → [dev-loop](plan/phase-1/dev-loop.md) — deploy/load/screenshot verified on device
- [x] **Phase 2 — Table renderer & navigation (Lua)** → [renderer](plan/phase-2/renderer.md) — verified on device; 2 polish items parked
- [x] **Phase 3 — Interaction hierarchy (Lua)** → [interaction](plan/phase-3/interaction.md) — all modes verified on device via REPL-driven tests
- [x] **Phase 4 — Audio engine (SuperCollider)** → [engine](plan/phase-4/engine.md) — verified via device polls; loop player & mod character untested; owner listening check pending
- [x] **Panels: sequencer step editor + loop sample browser** (owner-prioritized gap, 2026-09-25) — built and verified
- [x] **Patch slots** → [patch-slots](plan/phase-5/patch-slots.md) — implemented & REPL-verified; owner feel-check pending
- [x] **Phase 5 — Integration & polish** → [integration](plan/phase-5/integration.md) — CPU 16%, polish fixes, README; owner feel-check pending; v2 backlog listed
- [x] **Published** (2026-09-25): v1.0.0 on GitHub (main + lean release branch), lines thread, catalog PR monome/norns-community#409 (discussion → GitHub Discussions)

### v2 (planned 2026-09-25)
- [x] **Phase 6 — v2 design decisions** → [decisions](plan/phase-6/decisions.md) — all resolved 2026-09-26 → `docs/behavior-spec.md` §9; feel-check findings still welcome
- [ ] **Phase 7 — Engine v2** → [engine-v2](plan/phase-7/engine-v2.md) — new synths, tempo clock, modulation scaling
- [ ] **Phase 8 — UI & panels v2** → [ui-v2](plan/phase-8/ui-v2.md) — 14-type place menu, remaining panels, visual polish
- [ ] **Phase 9 — Integration & release v2.0.0** → [release-v2](plan/phase-9/release-v2.md)

## Parking lot (undecided / later)

- Grid/MIDI controller support
- Sequencer/tonality depth vs. original
- Accelerometer-object equivalent (norns has no tilt; maybe arc?)
- ROTOR-era ideas worth backporting?

## Conventions

- Plans: Markdown, checkable todos, small files, frequent writes.
- Superseded plan files → `plan-archive/`; session prompts → `prompt-archive/`.
- `notebook.md` = running notes; `AGENTS.md` = project guide. Keep both current.
