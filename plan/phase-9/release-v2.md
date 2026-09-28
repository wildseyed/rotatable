# Phase 9 — Integration, release v2.0.0

- [x] End-to-end test script via REST API covering all 13 types →
  `tools/e2e.py` (all green 2026-09-27; also flushed out + fixed: sticky
  master volume from removed output objects, missing cleanup() orphan
  drones, ws REPL 8 s/call latency)
- [x] Patch-slot format v2: **backward-compatible** — v1 `steps` files
  migrate into pattern 1 on recall (implemented batch 2, factory presets
  prove the path)
- [x] Performance pass on CM3 with worst-case patch (2026-09-27): 14
  objects / 12 connections / seq+midi+loops running — **avg 22.6%, peak
  23.3%** (phase 7 was 23.3/24.1); idle with redraw+16 VU polls 11.8/12.8.
  Batch-3 additions cost nothing measurable on scsynth
- [x] README update; header version bump; new press screenshots
  (`press/table-wide.png`, `chain-detail.png`, `panel-steps.png`)
- [x] main → release branch publish, tag v2.0.0 (pushed 2026-09-28;
  release branch now includes `presets/` — AGENTS.md updated)
- [ ] Announcement posts (drafts delivered 2026-09-28; owner posts:
  lines thread update + r/synthesizers)
- [x] Catalog PR monome/norns-community#409 — checked 2026-09-28: entry
  fields still accurate (description/tags), no update needed; PR still
  open awaiting maintainer merge
