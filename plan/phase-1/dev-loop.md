# Phase 1 — Dev loop & hello world

- [x] Decide deploy transport: **paramiko** (no sshpass/expect on desktop) + matron websocket REPL (port 5555, plain-text Lua, newline-terminated)
- [x] Write `tools/deploy.py`: SFTP sync `rotatable/` → `~/dust/code/rotatable`; `--load` (REPL `norns.script.load`); `--shot` (screenshot → /tmp/norns.png)
- [x] Document deploy usage in `AGENTS.md`
- [x] Minimal script: vector circle + dotted grid, E1 zoom / E2 X / E3 Y
- [x] Deploy + run on device — script loads, `# script init` clean
- [x] Screenshot capture verified (`screen.export_screenshot('shot')` → `~/dust/data/rotatable/shot.png`)
- [x] Zoom/pan verified via REPL-injected `enc()` calls + screenshots
- [ ] Tune encoder feel (accel, sens) on hardware — needs owner's hands on the device
