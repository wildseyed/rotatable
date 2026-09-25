# Phase 5 — Patch slots (owner feature, 2026-09-25)

Persistence via "parking spots" outside the table edge — the Reactable
physical metaphor of pucks beside the table.

## Interaction (owner spec)
- Nav outside the table (camera beyond the table edge) shows **patch slots**
- **Long-press K3 on an empty slot** = store current patch there
- **Short press K3 on an occupied slot** = recall it (replaces current table)
- **Long-press K3 on an occupied slot** = delete it

## Implementation notes
- `lib/slots.lua`: ring of 8 slots at world radius 1.18 (slot 1 at top,
  clockwise); serialize via `tab.save` to `_path.data/rotatable/slots/N.lua`.
- Patch contents: objects (type, subtype, x, y, angle, params, env, seq steps,
  loop sample path), hardlinks, mutes, tempo. Camera not stored.
- Objects win over slots when both near the reticle; slots only at L1.
- Long-press threshold 0.8 s (K3 press/release timing at L1 only).
- Recall: rebuilds objects (new ids), remaps hardlinks/mutes, reloads loop
  samples via `Audio.load_sample`, restores tempo param.

## Todos
- [x] Slot ring rendering outside table edge
- [x] Long/short K3 disambiguation at L1 (objects unaffected)
- [x] Serialize/restore World + audio state (incl. seq steps, loop paths, tempo)
- [x] Store / recall / delete flows — verified via REPL (save 2-obj patch → clear → recall → chain intact; delete)
- [x] Survive script reload (slots dir is persistent files)
- [ ] Hands-on feel check by owner (long-press timing, slot findability)
