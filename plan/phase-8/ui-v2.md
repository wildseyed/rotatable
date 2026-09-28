# Phase 8 — UI & panels v2 (Lua)

Depends: phase-7 (**done**). Phase-6 decisions in `docs/behavior-spec.md` §9.
Sub-part `system-menu.md` (SYSTEM menu + factory presets) is **done**.

## Execution order (agreed with owner 2026-09-27)

Each batch is independently shippable: implement → deploy → device-verify via
the REST API/REPL harness (AGENTS.md "Testing / deployment") → tick boxes →
notebook entry → commit.

**Batch 1 — sync & sample gaps** (presets ACID/DUB/CHOIR depend on these):
- [x] Sync settings L3 page, one shared pattern: LFO `sync`+`mult` (32nd-note
  period), delay `sync` (32nd quantize) + `sweep`, loop `sync`
  (immediate/quarter/bar)
- [x] Sampler browser page (reuse loop browser; swap `pages_for` gate at
  `lib/ui.lua:103` to include sampler) + sampler `base` pitch control
  (settings page or ROTATE E3)
- [x] Steps editor pitch range ±24 (UI currently clamps ±12)
- [x] README: subtype cycling (K1+E2 in ROTATE) callout

**Batch 2 — sequencer depth:**
- [x] Sequencer preset slots: rotation switches 6 stored patterns per object
  (today rotation writes an inert `preset` param)
- [x] Sequencer pages: velocity page, step-duration page (multiples of 32nd)
- [x] Sequencer random subtype UI (poly grid deferred per phase-6)

**Batch 3 — MIDI + polish:**
- [x] MIDI-in: device select + channel in params; note routing to closest
  object; rotation = transpose ±24 st (spec §9.3)
- [x] Place menu with all 13 types: verify feel (works; check windowed scroll)
- [x] Visual polish: LINK ring clutter, connection animation (signal-flow
  dashes), tempo pulse at output point
- [x] Per-object VU meters from `lvl_N` polls (`Audio.lvl_poll(id)`)

**Needs an owner design session first — do NOT implement in batch flow:**
- ~~Suboscillators panel~~ — **done 2026-09-28** (owner-directed post-v2.0.0):
  engine `rot_osc` grew 4 subs × (waveform/amp/detune-cents/offset-semitones),
  summed pre-envelope; L3 `subs` page with follow-tonality toggle (lua snaps
  sub pitch to the scale mask before pushing)
- ~~Tonality UI beyond subtype/root~~ — **done 2026-09-28**: per-object
  editable 12-degree mask (`o.notes`), L3 `notes` page (E2 pick, E3/K3
  toggle); subtype cycling reloads the preset over custom edits
- Oscillator waveform-draw page — feasibility unknown; park unless owner
  prioritizes.

Reference: per-type panel list in `docs/interaction-design.md` §5; original
panels in `docs/behavior-spec.md` §3 table.
