# Phase 2 — Table renderer & navigation (Lua)

- [x] World model: table radius, camera (x, y, zoom), world→screen transform
- [x] Table edge arc rendering at any zoom
- [x] Dotted grid (hand-drawn segments), faint level — clipped to table radius (owner request)
- [x] L1 navigation per spec (E1/E2/E3, CCW negative)
- [x] Output point at table center (tempo pulse = later, with engine clock)
- [x] Redraw loop: 15 fps metro + dirty flag
- [x] Object glyph renderer: square=generator, octagon≈rounded-square=effect, circle=controller, star=global; rotation tick; label when zoom ≥30
- [x] Connection line renderer: audio=solid, control=hand-dotted; proximity computation in `lib/world.lua`
- [x] REPL test harness `T.add/move/rot/clear` for driving the world from deploy.py
- [ ] Polish backlog: cap output-point size at high zoom; label collision avoidance
