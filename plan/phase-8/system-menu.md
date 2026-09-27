# Phase 8 — SYSTEM master menu + factory presets

Owner-requested 2026-09-27. Bundles the 8 device presets in the repo and adds
a master menu for special functions.

- [x] Bundle presets: `presets/slots/{1..8}.lua` + the 5 referenced drum WAVs
  in `presets/audio/` (KIT-808: Dark_Bd/909_Sd/Clhh; PING: Syn_Rim; DUB:
  Dark_Bd; CRUSH: Rough_Sd) — pulled from the device, committed on `main`
- [x] `Slots.restore_factory()`: copy bundled slot files over
  `~/dust/data/rotatable/slots/`, rewriting absolute sample paths
  (`/home/we/dust/audio/rotatable-drums/` → bundled `presets/audio/`)
- [x] SYSTEM menu: hold K1+K2+K3 for 1 s → full-screen overlay (new UI level
  `"SYS"`). While all three are held, the K1+K2 table-clear arm and the
  K1+K3 place menu are suppressed/neutralized; releasing any key < 1 s
  cancels. E2 scroll, K3 select, K2 close.
- [x] Menu entries: `RESTORE PRESETS` (confirm screen, overwrites all 8
  slots — owner-approved semantics) and `ABOUT` (version + preset count)
- [x] `tools/deploy.py`: sync `presets/` to the device
- [x] Device-test: gesture open/cancel, restore, recall a restored preset,
  verify no interaction regressions (place menu, clear arm, slot gestures)
- [x] README: gesture + restore docs + the 8-preset recipe table; notebook
  entry
- [x] (phase 9 decision, still open) whether `presets/` ships on the `release` branch

Defaults taken on open questions: restore = overwrite-with-confirm; menu
name SYSTEM; release-branch bundling deferred to phase 9.
