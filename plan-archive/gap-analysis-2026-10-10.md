# Gap analysis — Rotatable vs. the original Reactable

Goal: list implementation misalignments and gaps vs. the original instrument
(manual mirror + online sources), excluding physical-hardware gaps
(camera/projector/table). Deliverable: `docs/gap-analysis-2026-10-10.md`.

## Checklist

- [x] Inventory implemented object types/params/panels from code
      (`lib/world.lua`, `lib/audio.lua`, `lib/ui.lua`, `lib/Engine_Rotatable.sc`,
      `lib/tonality.lua`, `lib/render.lua`)
- [x] Re-read manual mirror sections (`reference/manual/md/`) per object +
      gestures/panels/general
- [x] Check online sources (reactable.com legacy site, Wikipedia, TEI'07 paper)
      for features beyond the manual
- [x] Cross-check vs. existing gap lists (`docs/behavior-spec.md` §7/§9,
      notebook) so the new list adds, not repeats
- [x] Write findings incrementally into `docs/gap-analysis-2026-10-10.md`
- [x] Summarize for owner; archive this plan

## Milestones

1. Code + manual inventory done (findings drafted in the doc)
2. Online cross-check + final categorized list ready for owner review
