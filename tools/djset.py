#!/usr/bin/env python3
"""rotatable DJ set — a 20-minute performance driven through tools/api.py.
Runs a timed cuelist against the norns: layering, sweeps, breakdown, outro.
Usage: python3 tools/djset.py
"""
import json, time, urllib.request

API = "http://localhost:8787"
T0 = time.time()

def api(path, payload=None):
    if payload is None:
        req = urllib.request.Request(API + path, method="GET")
    else:
        req = urllib.request.Request(API + path,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"[warn] {path}: {e}")
        return {}

def lua(code):
    api("/lua", {"code": code})

def at(t, fn, *a):
    dt = T0 + t - time.time()
    if dt > 0: time.sleep(dt)
    fn(*a)

def place(type, x, y, angle=0):
    before = {o["id"] for o in api("/state").get("objects", [])}
    api("/place", {"type": type, "x": x, "y": y, "angle": angle})
    after = {o["id"] for o in api("/state").get("objects", [])}
    new = after - before
    return max(new) if new else max(after or {0})

def rotate(i, a): api("/rotate", {"id": i, "angle": a})
def move(i, x, y): api("/move", {"id": i, "x": x, "y": y})
def st(i, k, v): lua(f'T.set({i}, "{k}", {v})')
def mute(a, b): api("/mute", {"a": a, "b": b})
def load(i, p): lua(f'T.load({i}, "{p}")')
def tempo(b): lua(f'params:set("rot_tempo", {b})')
def amps(): return api("/amps")

def sweep(i, a0, a1, dur, steps=24):
    for s in range(steps + 1):
        rotate(i, a0 + (a1 - a0) * s / steps)
        time.sleep(dur / steps)

D = "/home/we/dust/audio/rotatable-drums"
TEHN = "/home/we/dust/audio/tehn"

print("[dj] setting up the booth...")
api("/clear")
tempo(126)

# stage: kick center-left, hats right, melody chain upper arc, bass lower
KICK  = place("loop", 0.35, -0.15, 3.14)
HATS  = place("loop", 0.55, -0.45, 0.0)
CHOR  = place("modulator", 0.22, 0.08, 1.9)
DLY   = place("delay", 0.48, 0.14, 2.6)
FLT   = place("filter", 0.72, 0.22, 0.2)
LEAD  = place("oscillator", 0.93, 0.30, 1.8)
SEQ   = place("sequencer", 0.88, 0.52, 0)
BASS  = place("oscillator", 0.30, -0.55, 4.4)
LFO   = place("lfo", 0.52, -0.28, 1.2)
OUT   = place("output", -0.35, 0.25, 3.8)
print(f"[dj] ids: kick={KICK} hats={HATS} lead={LEAD} bass={BASS} out={OUT}")

st(KICK, "subtype", 1); load(KICK, f"{D}/TR808-Dark_Bd.wav")
st(HATS, "subtype", 1); load(HATS, f"{D}/TR909-Noizclhh.wav"); st(HATS, "amp", 0.4)
st(CHOR, "subtype", 2); st(CHOR, "drywet", 0.35)
st(LEAD, "subtype", 2)                  # saw lead
st(BASS, "subtype", 1)                  # sine sub
st(LFO, "freq", 3.0); st(LFO, "depth", 0.4)

print("[dj] 0:00 — needle drop. kick only, lights low.")

# --- ACT I: the room fills (0:00–4:00) -------------------------------------
at(20, print, "[dj] hats creep in")
at(20, st, HATS, "amp", 0.7)
at(45, print, "[dj] bassline rolls under")
at(45, rotate, BASS, 4.0)
at(60, print, "[dj] melody, muted and moody")
at(60, rotate, LEAD, 1.8)
at(75, print, "[dj] slow filter open, four minutes of patience")
sweep(FLT, 0.2, 3.4, 165)   # 0:75 -> 4:00

# --- ACT II: first drop (4:00–8:00) -----------------------------------------
print("[dj] 4:00 — DROP. full chain open.")
st(DLY, "feedback", 0.55)
st(CHOR, "drywet", 0.5)
rotate(OUT, 5.2)  # master up
sweep(FLT, 3.4, 4.6, 30)
at(300, print, "[dj] riding the groove, delay tails getting longer")
at(300, st, DLY, "feedback", 0.65)
at(330, print, "[dj] LFO leans on the kick")
at(330, move, LFO, 0.42, -0.2)
sweep(FLT, 4.6, 3.0, 90)

# --- ACT III: breakdown (8:00–12:00) ----------------------------------------
print("[dj] 8:00 — BREAKDOWN. drums out, melody breathes.")
st(KICK, "amp", 0.0); st(HATS, "amp", 0.0)
st(BASS, "amp", 0.3)
st(DLY, "feedback", 0.8)
sweep(FLT, 3.0, 1.2, 45)
at(570, print, "[dj] you can hear the room tone now")
at(570, st, LEAD, "amp", 0.4)
at(600, print, "[dj] tempo dips, sway")
at(600, tempo, 116)
at(630, print, "[dj] kick returns. you know what's coming.")
at(630, st, KICK, "amp", 0.8)
at(660, print, "[dj] snare-ish hats back, building")
at(660, st, HATS, "amp", 0.6)
at(690, print, "[dj] tempo climbs home")
at(690, tempo, 126)
sweep(FLT, 1.2, 5.5, 30)  # 11:00 -> 11:30

# --- ACT IV: second drop, bigger (12:00–16:00) -------------------------------
print("[dj] 12:00 — SECOND DROP. everything, louder.")
st(LEAD, "amp", 0.9)
st(BASS, "amp", 0.8)
rotate(OUT, 5.6)
st(DLY, "feedback", 0.5)
sweep(FLT, 5.5, 4.2, 20)
at(760, print, "[dj] fake-out! just the kick for two bars")
at(760, st, LEAD, "amp", 0.1)
at(760, st, HATS, "amp", 0.1)
at(772, print, "[dj] and BACK")
at(772, st, LEAD, "amp", 0.9)
at(772, st, HATS, "amp", 0.7)
at(800, print, "[dj] pitch walks the lead up")
sweep(LEAD, 1.8, 2.8, 60)

# --- ACT V: outro (16:00–20:00) ----------------------------------------------
print("[dj] 16:00 — outro. peeling layers, thanks for dancing.")
st(LEAD, "amp", 0.3)
st(CHOR, "drywet", 0.6)
sweep(FLT, 4.2, 1.5, 60)
at(1020, print, "[dj] melody leaves first")
at(1020, st, LEAD, "amp", 0.0)
at(1050, print, "[dj] hats leave")
at(1050, st, HATS, "amp", 0.0)
at(1080, print, "[dj] tempo rides down, 126 -> 100")
for i, b in enumerate(range(126, 99, -3)):
    at(1080 + i * 6, tempo, b)
at(1140, print, "[dj] last thing you hear: the kick, fading")
sweep(OUT, 5.6, 0.6, 45)
at(1195, st, KICK, "amp", 0.0)
print(f"[dj] 20:00 — good night. final levels {amps()}")
print("[dj] the booth is yours again (table left as the set ended).")
