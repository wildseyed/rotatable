# Phase 13b — Follow-tonality resync fixes — DONE 2026-10-11, device-verified

Source: code investigation 2026-10-11. The toggle and snap math were
correct; the bug was that snapped sub offsets are baked into engine args at
`sync_object` time and several paths that change the inputs never triggered
a re-sync (tonality placement/removal, API edits, slot-recall order).
Factory slot 12 (DRIFT) hit the recall bug (tonality = object #10, after
all four oscs) and was likely never snapped even at build time.

## 1. Centralized: resync from `Audio.sync_object` — DONE

- [x] `Audio.sync_object` calls `Audio.resync_follow()` when
      `o.type == "tonality"` (before the HAS_SYNTH early return; no
      recursion — resync only touches oscillators). Every path funnels
      through sync_object, so this one hook fixed: API root edits
      (`T.set`), tonality placement (`Audio.on_add`), and slot-recall
      order (when the tonality's recall-time sync runs, earlier oscs get
      re-pushed snapped)
- [x] removed the now-redundant `resync_follow` calls in rotatable.lua's
      enc/key wrappers

## 2. Remaining paths — DONE

- [x] `T.notes` now calls `Audio.sync_object(o)` (previously synced
      nothing) → API note-mask edits propagate
- [x] `World.remove` wrapper: captures the type, calls `resync_follow()`
      AFTER `remove0` when a tonality leaves (in `on_remove` the object is
      still in `World.objects`, so the snap would see it) — follow subs
      fall back to their raw offsets

## 3. Device verification (REST harness) — all green

- [x] resync fires on: tonality placement, `/set root`, `T.notes`,
      tonality removal (counter patch on `RotatableAudio.resync_follow`;
      lesson: ws REPL is per-line — patch with globals only, and /lua
      replies need `{braces}` to surface)
- [x] `snap_abs(61, C major) == 60` unit check
- [x] slot 12 recall: resync fires mid-recall, all 12 objects restored
      (pre-fix recall with a broken patch aborted at 10 — the recall loop
      is not error-isolated, good to know)
- [ ] physical-path listening check (toggle + tonality edits) — owner
- [x] e2e regression green

## 4. By design (documented)

LFO pitch drift on the osc's `mod` bus detunes main osc and subs together
after the snap — follow is only exact at mod=0 (DRIFT uses this
deliberately). Documented in README's subs bullet.

- [x] README note
- [x] notebook.md entry
