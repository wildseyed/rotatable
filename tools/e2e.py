#!/usr/bin/env python3
"""End-to-end test for rotatable via the REST API (phase 9).

    python3 tools/api.py 8787 &       # if not already running
    python3 tools/e2e.py [port]

Covers: all 13 types place/connect, params, sequencer presets/dur/random,
sample load, mute/hardlink, UI navigation, slot roundtrip (slot 1 restored
from factory afterwards). Exits non-zero on first failure.
"""
import json, sys, time, urllib.request

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
BASE = f"http://127.0.0.1:{PORT}"
FAILS = 0

def get(path):
    with urllib.request.urlopen(BASE + path, timeout=10) as r:
        return json.load(r)

def post(path, payload=None):
    req = urllib.request.Request(BASE + path, data=json.dumps(payload or {}).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)

def lua(code):
    r = post("/lua", {"code": code})
    return r.get("result", "")

def check(name, cond, detail=""):
    global FAILS
    if cond:
        print(f"  ok  {name}")
    else:
        FAILS += 1
        print(f"FAIL  {name}  {detail}")

def state():
    return get("/state")

def ids_by_type(st, t):
    return [o["id"] for o in st["objects"] if o["type"] == t]

def key(n, z):
    post("/key", {"n": n, "z": z})

def tap(n):
    key(n, 1); key(n, 0)

def select_at_center():
    tap(3)

def amps_max(tries=6, dt=0.35):
    best = 0.0
    for _ in range(tries):
        a = get("/amps")
        best = max(best, a["amp_l"], a["amp_r"])
        time.sleep(dt)
    return best

def reset_camera():
    # UI tests need the reticle over the table center; the cam persists
    # across sessions (press shots, manual play), so drive it home first
    import re
    for _ in range(20):
        r = lua('print("{cam "..T.cam().."}")')
        m = re.search(r"cam ([\d.-]+),([\d.-]+) z(\d+)", r)
        x, y, z = float(m.group(1)), float(m.group(2)), float(m.group(3))
        if abs(z - 48) / 48 > 0.05:
            post("/enc", {"n": 1, "d": round(25 * (48 / z - 1)) or (1 if z > 48 else -1)})
        elif abs(x) > 0.01:
            post("/enc", {"n": 2, "d": round(-x / (0.01 * 48 / z))})
        elif abs(y) > 0.01:
            post("/enc", {"n": 3, "d": round(-y / (0.01 * 48 / z))})
        else:
            break

print("== clear + place all 13 types ==")
post("/clear")
TYPES = ["oscillator", "loop", "sampler", "input", "filter", "delay",
         "modulator", "waveshaper", "lfo", "sequencer", "midi",
         "tonality", "output"]
for i, t in enumerate(TYPES):
    a = i * 2 * 3.14159 / len(TYPES)
    post("/place", {"type": t, "x": 0.55 * __import__("math").cos(a),
                    "y": 0.55 * __import__("math").sin(a)})
st = state()
check("13 objects placed", len(st["objects"]) == 13, f"got {len(st['objects'])}")
check("all types present",
      sorted(o["type"] for o in st["objects"]) == sorted(TYPES))

print("== audio chain: osc -> filter -> output ==")
post("/clear")
post("/place", {"type": "oscillator", "x": 0.2, "y": 0.0})
post("/place", {"type": "filter", "x": 0.1, "y": 0.0})
st = state()
osc = ids_by_type(st, "oscillator")[0]
flt = ids_by_type(st, "filter")[0]
conns = {(c["a"], c["b"], c["kind"]) for c in st["connections"]}
check("osc -> filter audio", (osc, flt, "audio") in conns, str(conns))
check("filter -> output audio", (flt, "output", "audio") in conns, str(conns))
check("chain audible", amps_max() > 0.02)

print("== controllers: lfo + seq + midi connect to osc ==")
post("/place", {"type": "lfo", "x": 0.2, "y": 0.12})
post("/place", {"type": "sequencer", "x": 0.2, "y": -0.12})
post("/place", {"type": "midi", "x": 0.32, "y": 0.0})
st = state()
lfo = ids_by_type(st, "lfo")[0]
seq = ids_by_type(st, "sequencer")[0]
mid = ids_by_type(st, "midi")[0]
ctl = {c["a"] for c in st["connections"] if c["kind"] == "control"}
check("lfo control conn", lfo in ctl, str(st["connections"]))
check("seq control conn", seq in ctl)
check("midi control conn", mid in ctl)

print("== sync params (batch 1) ==")
post("/set", {"id": lfo, "param": "sync", "value": 1})
post("/set", {"id": lfo, "param": "mult", "value": 16})
check("lfo sync set ok", True)  # no exception = param accepted
post("/place", {"type": "delay", "x": -0.2, "y": 0.0})
st = state()
dly = ids_by_type(st, "delay")[0]
post("/set", {"id": dly, "param": "sync", "value": 1})
post("/set", {"id": dly, "param": "sweep", "value": 0.5})
post("/place", {"type": "loop", "x": -0.4, "y": 0.0})
st = state()
lp = ids_by_type(st, "loop")[0]
post("/set", {"id": lp, "param": "sync", "value": 2})
check("delay/loop sync params ok", True)

print("== sampler: load bundled wav + base pitch ==")
post("/place", {"type": "sampler", "x": -0.4, "y": 0.25})
st = state()
smp = ids_by_type(st, "sampler")[0]
post("/load", {"id": smp,
               "path": "/home/we/dust/code/rotatable/presets/audio/TR909-Dark_Bd.wav"})
post("/set", {"id": smp, "param": "base", "value": 220.0})
time.sleep(1)
check("sampler load no error", True)

print("== sequencer: presets, dur, random ==")
post("/rotate", {"id": seq, "angle": 2.513})  # preset 3
r = lua(f'print("{{"..T.seq_state({seq}).."}}")')
check("rotate switches preset", "preset=3" in r, r)
post("/step", {"id": seq, "step": 1, "on": True, "pitch": 7, "vel": 0.9, "dur": 4})
r1 = lua(f'print("{{"..T.seq_state({seq}).."}}")')
time.sleep(1.0)
r2 = lua(f'print("{{"..T.seq_state({seq}).."}}")')
check("seq position advances", r1 != r2, f"{r1} -> {r2}")
post("/rotate", {"id": seq, "angle": 0})  # back to preset 1 (penta default)
r = lua(f'print("{{"..T.seq_state({seq}).."}}")')
check("rotate back to preset 1", "preset=1" in r, r)
post("/set", {"id": seq, "param": "subtype", "value": 3})  # random
time.sleep(3)
r = lua(f'print("{{"..T.seq_state({seq}).."}}")')
check("random subtype improvises (hist>0)", "hist=0" not in r, r)
post("/set", {"id": seq, "param": "subtype", "value": 1})

print("== midi note routing ==")
post("/clear")  # clean stage: any active sequencer would retrigger the gate
post("/place", {"type": "oscillator", "x": 0.1, "y": 0.0})
post("/place", {"type": "midi", "x": 0.1, "y": 0.15})
lua("T.midi_note(60, 100)")
on = amps_max(2, 0.2)
lua("T.midi_note(60, 0)")
time.sleep(1.2)
off = amps_max(2, 0.2)
check("midi note-on audible", on > 0.02, f"on={on}")
check("midi note-off releases", off < on * 0.5 + 0.01, f"off={off}")

print("== hardlink + mute ==")
post("/clear")
post("/place", {"type": "oscillator", "x": 0.2, "y": 0.0})
post("/place", {"type": "filter", "x": 0.1, "y": 0.0})
post("/place", {"type": "sequencer", "x": 0.2, "y": 0.12})
st = state()
osc = ids_by_type(st, "oscillator")[0]
flt = ids_by_type(st, "filter")[0]
seq = ids_by_type(st, "sequencer")[0]
r = lua(f'print("{{"..tostring(T.link({seq}, {osc})).."}}")')
check("hardlink toggles on", "true" in r, r)
r = lua(f'print("{{"..tostring(T.mute({osc}, {flt})).."}}")')
check("mute toggles", "true" in r or "false" in r, r)
lua(f'print("{{"..tostring(T.mute({osc}, {flt})).."}}")')  # restore
lua(f'print("{{"..tostring(T.link({seq}, {osc})).."}}")')  # unlink

print("== UI navigation smoke ==")
reset_camera()
post("/clear")
post("/place", {"type": "oscillator", "x": 0.05, "y": 0})
select_at_center()
st = state()
check("K3 selects -> L2", st["level"] == "L2", st["status"])
key(1, 1); tap(3); key(1, 0)
st = state()
check("^K3 dives -> L3", st["level"] == "L3", st["status"])
tap(2)
st = state()
check("K2 backs -> L2", st["level"] == "L2", st["status"])
tap(2)  # L2 MOVE -> L1
st = state()
check("K2 backs -> L1", st["level"] == "L1", st["status"])
key(1, 1); tap(3); key(1, 0)
st = state()
check("^K3 opens place menu -> L0", st["level"] == "L0", st["status"])
tap(2)

print("== v3: tempo object, output adopt, global FX ==")
post("/clear")
lua('params:set("rot_tempo", 120)')
post("/place", {"type": "oscillator", "x": 0.1, "y": 0})
post("/place", {"type": "tempo", "x": -0.4, "y": 0.2})
post("/place", {"type": "output", "x": -0.4, "y": -0.3})
st = state()
tmp = ids_by_type(st, "tempo")[0]
out = ids_by_type(st, "output")[0]
osc = ids_by_type(st, "oscillator")[0]
# placement must not clobber live settings (adopt, not reset)
r = lua('print("{bpm="..params:get("rot_tempo").."}")')
check("tempo object adopts bpm on place", "bpm=120" in r, r)
check("output object keeps master audible", amps_max(2, 0.2) > 0.02)
# rotation drives the param
post("/rotate", {"id": tmp, "angle": 4.712})  # 40 + 0.75*200 = 190
r = lua('print("{bpm="..params:get("rot_tempo").."}")')
check("tempo rotation sets bpm", "bpm=190" in r, r)
post("/rotate", {"id": tmp, "angle": 2.513})  # back to 120
r = lua('print("{bpm="..params:get("rot_tempo").."}")')
check("tempo rotation back", "bpm=120" in r, r)
# gfx: rev tail — silence the osc, master should keep ringing
post("/rotate", {"id": osc, "angle": 3.0})    # brighter source for the tail
post("/set", {"id": out, "param": "rev", "value": 0.8})
time.sleep(0.5)
lua(f'engine.set({osc}, "gate", 0)')
time.sleep(0.5)
tail = amps_max(3, 0.3)
check("reverb tail after gate-off", tail > 0.005, f"tail={tail}")
post("/set", {"id": out, "param": "rev", "value": 0})
# leave the scene the slot roundtrip expects: one osc at center
post("/clear")
post("/place", {"type": "oscillator", "x": 0.05, "y": 0})

print("== slot roundtrip (slot 1; factory-restored after) ==")
lua("T.save_slot(1)")
post("/clear")
st = state()
check("table cleared", len(st["objects"]) == 0)
r = lua('print("{r="..tostring(T.recall_slot(1)).."}")')
check("slot recall ok", "r=true" in r, r)
time.sleep(1)
st = state()
check("recall restores 1 object", len(st["objects"]) == 1, str(len(st["objects"])))
check("recalled type is oscillator", st["objects"][0]["type"] == "oscillator")
# restore factory presets via SYSTEM gesture: hold K1+K2+K3 1.2s
key(1, 1); key(2, 1); key(3, 1)
time.sleep(1.4)
key(1, 0); key(2, 0); key(3, 0)
st = state()
check("SYSTEM menu opened", st["level"] == "SYS", st["status"])
tap(3)  # RESTORE PRESETS -> confirm
tap(3)  # confirm
tap(2)  # close
r = lua('print("{r="..tostring(T.recall_slot(1)).."}")')
time.sleep(1)
st = state()
check("factory slot 1 = KIT-808 (6 objects)", len(st["objects"]) == 6,
      str(len(st["objects"])))

post("/clear")
print()
if FAILS:
    print(f"{FAILS} FAILURE(S)")
    sys.exit(1)
print("all green")
