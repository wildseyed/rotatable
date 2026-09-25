# Phase 3 — Interaction hierarchy (Lua)

- [x] Level state machine (L0/L1/L2/L3) + status line (`lib/ui.lua`)
- [x] L0 place menu: 8 v1 types grouped by category, windowed scroll, K3 place / K2 cancel
- [x] L2 object selection (nearest to reticle within 25 px) + highlight
- [x] L2 MOVE mode: E2/E3 move, live proximity recompute — verified
- [x] L2 ROTATE mode: E2 angle, E3 right-dot param; K1+E2 subtype cycle — verified
- [x] L2 LINK mode: E2 cycles candidates by proximity, K3 hardlink toggle ([HARD], bright double line), K1+K3 mute toggle (dims line, survives recompute) — verified
- [x] Object removal: K1+K2 in L2 (shift+back = delete)
- [x] L3 config framework: E1 page, E2/E3 edit; pages = 2D (effects) + envelope (all) per v1 panel scope
- [x] World model extended: subtypes, per-type params, envelope, hardlinks, mute
- [x] **Key map v3 (owner, 2026-09-25)**: K1 tap reserved for norns system menu; K1 = held shift; K2 = BACK everywhere; K3 = action/confirm; K1+K3 = shifted action (place menu / dive L3 / mute); K1+K2 = remove. Verified as single-message REPL script (A–H transitions all correct)
- [x] REPL harness: `T.key/T.enc/T.dump/T.dump_str`
- [x] **E1 object-hop in MOVE mode (owner, 2026-09-25)**: cycles selection through objects, camera centers on each — fast table traversal
- [ ] Polish backlog: status/menu text overlaps at bottom line; LINK ring when objects overlap is cluttered
- [ ] Note: matron REPL can execute rapid separate ws messages out of order — always verify multi-step flows as ONE Lua chunk
