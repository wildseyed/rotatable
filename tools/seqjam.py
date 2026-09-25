#!/usr/bin/env python3
"""sequencer movement jam — revives the lead and mutates the 16-step
pattern live for ~3 minutes via the API. usage: python3 tools/seqjam.py [seconds]
"""
import json, time, random, urllib.request, sys

API = "http://localhost:8787"
DUR = int(sys.argv[1]) if len(sys.argv) > 1 else 180

def api(path, payload=None):
    req = urllib.request.Request(API + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="GET" if payload is None else "POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"[warn] {path}: {e}", flush=True)
        return {}

def lua(code): api("/lua", {"code": code})
def st(i, k, v): lua(f'T.set({i}, "{k}", {v})')
def step(s, on=None, pitch=None, vel=None):
    lua(f'T.step({SEQ}, {s}, {str(on).lower() if on is not None else "nil"}, '
        f'{pitch if pitch is not None else "nil"}, '
        f'{vel if vel is not None else "nil"})')

def rotate(i, a): api("/rotate", {"id": i, "angle": a})

def find_ids():
    objs = api("/state").get("objects", [])
    def pick(pred):
        for o in objs:
            if pred(o): return o["id"]
    return {
        "LEAD": pick(lambda o: o["type"] == "oscillator" and o["subtype_name"] == "saw")
                or pick(lambda o: o["type"] == "oscillator"),
        "SEQ":  pick(lambda o: o["type"] == "sequencer"),
        "FLT":  pick(lambda o: o["type"] == "filter"),
        "DLY":  pick(lambda o: o["type"] == "delay"),
        "CHOR": pick(lambda o: o["type"] == "modulator"),
        "OUT":  pick(lambda o: o["type"] == "output"),
    }

_ids = find_ids()
LEAD, SEQ, FLT, DLY, CHOR, OUT = (_ids["LEAD"], _ids["SEQ"], _ids["FLT"],
                                  _ids["DLY"], _ids["CHOR"], _ids["OUT"])
TEMPO = 122
print(f"[jam] ids: {_ids}", flush=True)

# minor pentatonic pools (semitone offsets)
LOW  = [-12, -9, -7, -5, -2, 0]
MID  = [0, 3, 5, 7, 10, 12]
HIGH = [12, 15, 17, 19, 22, 24]

print("[jam] waking the lead up...", flush=True)
lua(f'params:set("rot_tempo", {TEMPO})')
st(LEAD, "amp", 0.7)
st(CHOR, "drywet", 0.35); st(DLY, "feedback", 0.45)
rotate(FLT, 3.6); rotate(OUT, 4.6)
random.seed()

t0, bar = time.time(), 0
density = 0.5
while time.time() - t0 < DUR:
    bar += 1
    phase = (time.time() - t0) / DUR
    # density: thin -> busy -> thin across the jam
    density = 0.35 + 0.5 * (1 - abs(phase - 0.5) * 2)
    pool = LOW if phase < 0.25 else (MID if phase < 0.7 else HIGH)
    # mutate 1-3 steps per bar
    for _ in range(random.randint(1, 3)):
        s = random.randint(1, 16)
        r = random.random()
        if r < density * 0.75:
            step(s, on=True, pitch=random.choice(pool),
                 vel=random.uniform(0.5, 1.0))
        elif r < 0.9:
            step(s, on=False)
        else:
            step(s, vel=random.uniform(0.3, 1.0))
    # accent downbeats as density grows
    if density > 0.6:
        step(random.choice([1, 5, 9, 13]), on=True,
             pitch=random.choice(pool), vel=1.0)
    # occasional global gestures
    if bar % 16 == 0:
        rotate(FLT, random.uniform(2.2, 4.6))
        print(f"[jam] bar {bar}: filter gesture, density {density:.2f}", flush=True)
    if bar % 32 == 0:
        st(DLY, "feedback", random.uniform(0.35, 0.65))
    time.sleep(60 / TEMPO * 4 * 0.9)  # ~one bar

print("[jam] settling: sparse outro pattern", flush=True)
for s in range(1, 17):
    step(s, on=(s in (1, 6, 11)), pitch=(0 if s == 1 else 7), vel=0.7)
st(LEAD, "amp", 0.5)
print(f"[jam] done. {api('/amps')}", flush=True)
