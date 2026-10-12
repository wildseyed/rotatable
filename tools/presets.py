#!/usr/bin/env python3
"""rotatable factory preset builder (plan/phase-11).

Builds the 16 factory preset tables on the device through tools/api.py,
saving each to its patch slot. Then `--pull` fetches the slot files back
into data/slots/ (data/ is hidden from norns' SELECT menu).

    python3 tools/presets.py 1          # build preset 1 only
    python3 tools/presets.py 1-16       # build a range
    python3 tools/presets.py --pull     # SFTP slot files back to the repo

Angle encodes every primary param (lib/audio.lua primary()) — the a_*
helpers invert those mappings so builders can think in real values.
"""
import json, math, os, sys, time, urllib.request

API = "http://localhost:8787"
D = "/home/we/dust/audio/rotatable"
TAU = 2 * math.pi

# ---------- REST helpers (djset.py pattern) ----------

def api(path, payload=None):
    if payload is None:
        req = urllib.request.Request(API + path, method="GET")
    else:
        req = urllib.request.Request(API + path,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())

def lua(code):
    return api("/lua", {"code": code})

def state():
    return api("/state")

def place(type, x, y, angle=0.0):
    before = {o["id"] for o in state().get("objects", [])}
    api("/place", {"type": type, "x": x, "y": y, "angle": angle})
    after = {o["id"] for o in state().get("objects", [])}
    new = after - before
    return max(new) if new else max(after or {0})

def rot(i, a):    api("/rotate", {"id": i, "angle": a})
def st(i, k, v):  api("/set", {"id": i, "param": k, "value": v})
def load(i, p):   api("/load", {"id": i, "path": p})
def link(a, b):   lua(f"T.link({a}, {b})")
def mute(a, b):   api("/mute", {"a": a, "b": b})
def save(i):      lua(f"T.save_slot({i})")

def step(i, s, on, pitch=0, vel=0.8, dur=2):
    api("/step", {"id": i, "step": s, "on": bool(on), "pitch": pitch,
                  "vel": vel, "dur": dur})

def pattern(i, preset, rows):
    """Write a full 16-step pattern into preset slot `preset` of seq i.
    rows: 16 x (on, pitch, vel[, dur])."""
    rot(i, a_preset(preset))
    for s, r in enumerate(rows, 1):
        step(i, s, r[0], r[1] if len(r) > 1 else 0,
             r[2] if len(r) > 2 else 0.8, r[3] if len(r) > 3 else 2)

def sub(i, n, wave=None, amp=None, det=None, off=None):
    for k, v in (("wave", wave), ("amp", amp), ("det", det), ("off", off)):
        if v is not None:
            lua(f'T.sub({i}, {n}, "{k}", {v})')

def subfollow(i, v):
    lua(f'T.sub({i}, "follow", "", {v})')

def notes(i, mask12):
    lua(f"T.notes({i}, {', '.join(str(int(b)) for b in mask12)})")

# ---------- angle (primary param) inverse mappings ----------

def a_freq(v):   return math.log2(v / 55) / 4 * TAU        # osc/sampler 55..880
def a_rate(v):   return math.log2(v / 0.25) / 4 * TAU      # loop 0.25..4
def a_gain(v):   return v * TAU                            # input
def a_cut(v):    return math.log(v / 40) / math.log(300) * TAU   # filter
def a_time(v):   return math.log(v / 0.01) / math.log(200) * TAU # delay
def a_01(v):     return v * TAU    # mod/shaper main, lfo depth? no — main/room/vol
def a_lfo(v):    return math.log(v / 0.05) / math.log(400) * TAU
def a_bpm(v):    return (v - 40) / 200 * TAU
def a_root(r):   return (r + 0.5) / 12 * TAU
def a_preset(p): return (p - 0.5) / 5.999 * TAU
def a_trsp(t):   return (t + 24 + 0.5) / 48.999 * TAU

def tempo_obj(bpm=120, x=0.62, y=0.62):
    t = place("tempo", x, y)
    rot(t, a_bpm(bpm))
    return t

def output_obj(vol=0.8, rev=0.0, room=0.5, comp=0.0, x=-0.62, y=0.62):
    o = place("output", x, y)
    rot(o, a_01(vol))
    st(o, "rev", rev); st(o, "room", room); st(o, "comp", comp)
    return o

# ---------- the 16 tables (plan/phase-11/presets.md) ----------

def b01():  # HELLO — new-age first contact: sine + pentatonic, long breaths
    osc = place("oscillator", 0.42, -0.05, a_freq(261.6))
    st(osc, "subtype", 1)  # sine
    st(osc, "amp", 0.6)
    sub(osc, 1, wave=0, amp=0.35, off=-12)  # soft sub-octave warmth
    for k, v in (("a", 0.01), ("d", 0.3), ("s", 0.6), ("r", 0.6)):
        st(osc, k, v)
    dly = place("delay", 0.20, 0.05, a_time(0.45))
    st(dly, "subtype", 2)  # pingpong, tempo-quantized
    st(dly, "sync", 1)
    st(dly, "feedback", 0.35)
    seq = place("sequencer", 0.62, 0.25, a_preset(1))
    st(seq, "subtype", 1)  # mono
    pattern(seq, 1, [  # C major pentatonic motif, 2 bars, lots of air
        (1, 0, .7, 8), (0, 0, 0, 2), (1, 4, .6, 4), (0, 0, 0, 2),
        (1, 7, .75, 6), (1, 9, .6, 2), (0, 0, 0, 2), (1, 4, .6, 4),
        (1, 2, .7, 8), (0, 0, 0, 2), (1, 4, .6, 4), (0, 0, 0, 2),
        (1, 0, .75, 8), (0, 0, 0, 4), (0, 0, 0, 2), (0, 0, 0, 8)])
    link(seq, osc)
    ton = place("tonality", -0.45, -0.25, a_root(0))
    st(ton, "subtype", 3)  # pentatonic
    tempo_obj(72)
    output_obj(vol=0.8, rev=0.4, room=0.6)

def b02():  # BEAT — hardlinked kit, velocity ghosts, drum pinning demo
    # kick steps carry pitch offsets on purpose: the drum subtype ignores
    # them (one octave always) — variation comes from VELOCITY, not pitch
    kick = place("sampler", 0.35, -0.30, a_freq(261.6))
    st(kick, "subtype", 2)
    load(kick, f"{D}/drums/kick.wav")
    snr = place("sampler", 0.42, 0.05, a_freq(261.6))
    st(snr, "subtype", 2)
    load(snr, f"{D}/drums/snare.wav")
    st(snr, "amp", 0.75)
    hat = place("sampler", 0.35, 0.38, a_freq(261.6))
    st(hat, "subtype", 2)
    load(hat, f"{D}/drums/chh.wav")
    st(hat, "amp", 0.5)
    sq1 = place("sequencer", 0.65, -0.42, a_preset(1))
    pattern(sq1, 1, [
        (1, 0, .95), (0, 0), (0, 0), (1, 7, .35),
        (1, 0, .9), (0, 0), (1, 12, .3), (0, 0),
        (1, 0, .95), (0, 0), (0, 0), (1, 5, .4),
        (1, 0, .9), (0, 0), (1, 0, .35), (1, 0, .5)])
    link(sq1, kick)
    sq2 = place("sequencer", 0.70, 0.10, a_preset(1))
    pattern(sq2, 1, [
        (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (0, 0), (1, 0, .3),
        (0, 0), (0, 0), (1, 0, .25), (0, 0),
        (1, 0, .95), (0, 0), (0, 0), (1, 0, .45)])
    link(sq2, snr)
    sq3 = place("sequencer", 0.65, 0.55, a_preset(1))
    pattern(sq3, 1, [
        (1, 0, .6), (0, 0), (1, 0, .4), (1, 0, .5),
        (1, 0, .6), (0, 0), (1, 0, .4), (0, 0),
        (1, 0, .6), (0, 0), (1, 0, .45), (1, 0, .5),
        (1, 0, .6), (1, 0, .4), (1, 0, .5), (1, 0, .35)])
    link(sq3, hat)
    tempo_obj(122)
    output_obj(vol=0.85, comp=0.2)

def b03():  # KIT-808 — 909 kit, flanged hat (settings page), muted alt snare
    kit = [
        ("TR909-Dark_Bd.wav", "kick", -0.05, -0.42),
        ("TR909-909_Sd.wav",  "snr",   0.32, -0.28),
        ("TR808-Clhh.wav",    "hat",   0.35,  0.18),
        ("drums/clap.wav",    "clap", -0.05,  0.32),
    ]
    pats = {
        "kick": [(1,0,.95),(0,0),(0,0),(0,0),(1,0,.9),(0,0),(0,0),(1,0,.3),
                 (1,0,.95),(0,0),(0,0),(0,0),(1,0,.9),(0,0),(1,0,.35),(0,0)],
        "snr":  [(0,0),(0,0),(0,0),(0,0),(1,0,.9),(0,0),(0,0),(0,0),
                 (0,0),(0,0),(0,0),(0,0),(1,0,.95),(0,0),(0,0),(1,0,.4)],
        "hat":  [(1,0,.7),(0,0),(1,0,.5),(0,0),(1,0,.7),(0,0),(1,0,.5),(0,0),
                 (1,0,.7),(0,0),(1,0,.5),(0,0),(1,0,.7),(0,0),(1,0,.6),(1,0,.45)],
        "clap": [(0,0),(0,0),(0,0),(0,0),(1,0,.85),(0,0),(0,0),(0,0),
                 (0,0),(0,0),(0,0),(0,0),(1,0,.9),(0,0),(0,0),(0,0)],
    }
    fln = None
    for i, (wav, name, x, y) in enumerate(kit):
        smp = place("sampler", x, y, a_freq(261.6))
        st(smp, "subtype", 2)
        load(smp, f"{D}/{wav}")
        sq = place("sequencer", x + 0.5, y - 0.12, a_preset(1))
        pattern(sq, 1, pats[name])
        link(sq, smp)
        if name == "hat":
            # hat -> flanger -> output: metallic sweep from the settings page
            fln = place("modulator", x - 0.18, y + 0.02, a_01(0.55))
            st(fln, "subtype", 3)  # flanger
            st(fln, "drywet", 0.55)
            st(fln, "fdepth", 0.8)
            st(fln, "mindelay", 0.002)
            st(fln, "ffb", 0.6)
    alt = place("sampler", -0.42, -0.05, a_freq(261.6))
    st(alt, "subtype", 2)
    load(alt, f"{D}/TR909-Rough_Sd.wav")
    sq = place("sequencer", -0.30, -0.52, a_preset(1))
    pattern(sq, 1, pats["snr"])
    link(sq, alt)
    mute(sq, alt)
    tempo_obj(124, x=0.68, y=-0.55)
    output_obj(vol=0.85, comp=0.3, x=-0.68, y=0.45)

def b04():  # KEY — dorian BASS RIFF (contrabass) + sparse answers;
    # teaches custom scale masks (dorian is not a preset subtype)
    bass = place("sampler", 0.42, -0.08, a_freq(98))
    st(bass, "subtype", 1)  # instrument
    load(bass, f"{D}/instruments/contrabass_G2.wav")
    st(bass, "base", 98.0)
    st(bass, "amp", 0.85)
    lead = place("oscillator", 0.40, 0.32, a_freq(440))
    st(lead, "subtype", 1)  # sine, answers way up high
    st(lead, "amp", 0.4)
    for k, v in (("a", 0.01), ("d", 0.3), ("s", 0.5), ("r", 0.5)):
        st(lead, k, v)
    dly = place("delay", 0.16, 0.18, a_time(0.4))
    st(dly, "subtype", 2)  # pingpong
    st(dly, "sync", 1)
    st(dly, "feedback", 0.3)
    sq1 = place("sequencer", 0.68, -0.25, a_preset(1))
    pattern(sq1, 1, [  # tresillo-driven dorian riff
        (1, 0, .9, 3), (1, 0, .7, 3), (1, 3, .8, 2),
        (1, 5, .85, 3), (1, 3, .7, 3), (1, 2, .7, 2),
        (1, 0, .9, 3), (1, 0, .7, 3), (1, 7, .8, 2),
        (1, 10, .85, 2), (1, 7, .7, 1),
        (0, 0, 0, 1), (0, 0, 0, 1), (0, 0, 0, 1), (0, 0, 0, 1), (0, 0, 0, 1)])
    link(sq1, bass)
    sq2 = place("sequencer", 0.65, 0.45, a_preset(1))
    pattern(sq2, 1, [  # sine answers in the gaps, 2 bars
        (0, 0, 0, 4), (0, 0, 0, 4), (1, 12, .5, 4), (0, 0, 0, 4),
        (0, 0, 0, 8), (0, 0, 0, 4), (1, 10, .45, 2), (0, 0, 0, 2),
        (0, 0, 0, 4), (0, 0, 0, 4), (1, 15, .5, 4), (0, 0, 0, 4),
        (0, 0, 0, 6), (0, 0, 0, 2), (1, 12, .45, 4), (0, 0, 0, 4)])
    link(sq2, lead)
    ton = place("tonality", -0.45, -0.25, a_root(9))
    st(ton, "subtype", 2)  # minor preset, then edit to dorian (add nat 6)
    notes(ton, [1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0])  # A dorian
    tempo_obj(92)
    output_obj(vol=0.85, rev=0.25, room=0.5)

def b05():  # GRIT — sub-bass stack, distortion, LFO -> shaper main (new!)
    osc = place("oscillator", 0.55, -0.10, a_freq(82.4))  # E2
    st(osc, "subtype", 2)  # saw
    st(osc, "amp", 0.6)
    sub(osc, 1, wave=1, amp=0.55, off=-12)
    sub(osc, 2, wave=1, amp=0.25, off=-5, det=5)
    shp = place("waveshaper", 0.32, -0.02, a_01(0.35))
    st(shp, "subtype", 3)  # distortion
    st(shp, "drywet", 0.65)
    st(shp, "amp", 0.75)
    flt = place("filter", 0.12, -0.06, a_cut(520))
    st(flt, "subtype", 1)  # lp tames the fizz
    st(flt, "res", 0.35)
    lfo = place("lfo", 0.42, 0.28, a_lfo(0.8))
    st(lfo, "subtype", 1)  # sine
    st(lfo, "sync", 1)
    st(lfo, "mult", 16)    # half-note growl cycle
    st(lfo, "depth", 0.5)
    link(lfo, shp)         # wobbles the distortion AMOUNT (note: main, not dry-wet)
    seq = place("sequencer", 0.62, 0.30, a_preset(1))
    pattern(seq, 1, [  # slow greasy minor-pentatonic riff
        (1, 0, .9, 4), (0, 0, 0, 1), (1, 3, .6, 1), (1, 0, .7, 2),
        (0, 0, 0, 1), (1, 5, .8, 3), (1, 3, .6, 1), (1, 0, .8, 3),
        (1, 7, .9, 4), (0, 0, 0, 1), (1, 5, .6, 1), (1, 3, .7, 2),
        (0, 0, 0, 1), (1, 3, .8, 2), (1, 0, .7, 2), (1, -2, .7, 3)])
    link(seq, osc)
    ton = place("tonality", -0.45, -0.35, a_root(4))
    st(ton, "subtype", 2)  # minor preset, then edit to minor pentatonic
    notes(ton, [1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0])  # E minor pentatonic
    tempo_obj(76)
    output_obj(vol=0.85, comp=0.25)

def b06():  # SHINE — Pink Floyd atmosphere: the 4-note motif, pad drone,
    # slow filter tide, pingpong echoes. G dorian, 66 bpm
    pad = place("oscillator", 0.55, -0.30, a_freq(196.8))  # detuned drone
    st(pad, "subtype", 2)  # saw, drones forever at low amp
    st(pad, "amp", 0.28)
    lead = place("oscillator", 0.52, 0.05, a_freq(196.0))  # G3
    st(lead, "subtype", 2)  # saw
    st(lead, "amp", 0.55)
    sub(lead, 1, wave=0, amp=0.4, off=-12)
    for k, v in (("a", 0.02), ("d", 0.4), ("s", 0.55), ("r", 0.9)):
        st(lead, k, v)  # long release — the motif hangs in the air
    flt = place("filter", 0.28, -0.05, a_cut(900))
    st(flt, "subtype", 1)
    st(flt, "res", 0.3)
    lfo = place("lfo", 0.42, 0.30, a_lfo(0.5))
    st(lfo, "subtype", 1)  # sine
    st(lfo, "sync", 1)
    st(lfo, "mult", 64)    # 2-bar filter tide
    st(lfo, "depth", 0.3)
    link(lfo, flt)
    dly = place("delay", 0.10, 0.10, a_time(0.5))
    st(dly, "subtype", 2)  # pingpong
    st(dly, "sync", 1)
    st(dly, "feedback", 0.45)
    sq = place("sequencer", 0.75, -0.10, a_preset(1))
    pattern(sq, 1, [  # Bb–F–G–E, held and unanswered, 2 bars
        (1, 3, .85, 8), (0, 0, 0, 4), (1, 10, .75, 8), (0, 0, 0, 4),
        (1, 0, .85, 8), (0, 0, 0, 4), (1, 9, .8, 10), (0, 0, 0, 2),
        (0, 0, 0, 4), (0, 0, 0, 4), (1, 12, .55, 4), (0, 0, 0, 4),
        (0, 0, 0, 4), (1, 10, .5, 4), (0, 0, 0, 4), (0, 0, 0, 4)])
    link(sq, lead)
    ton = place("tonality", -0.48, -0.30, a_root(7))
    st(ton, "subtype", 2)  # minor preset, then edit to G dorian
    notes(ton, [1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0])  # dorian mask
    tempo_obj(66)
    output_obj(vol=0.8, rev=0.45, room=0.7)

def b07():  # PING — delay subtypes, pingpong, effect-envelope feedback swells
    clv = place("sampler", 0.55, -0.20, a_freq(261.6))
    st(clv, "subtype", 2)
    load(clv, f"{D}/drums/clave.wav")
    cow = place("sampler", 0.60, 0.10, a_freq(261.6))
    st(cow, "subtype", 2)
    load(cow, f"{D}/drums/cowbell.wav")
    st(cow, "amp", 0.55)
    dly = place("delay", 0.28, 0.0, a_time(0.9))
    st(dly, "subtype", 2)   # pingpong
    st(dly, "sync", 1)      # quantize to 32nds -> dotted quarter at 100 bpm
    st(dly, "feedback", 0.45)
    st(dly, "sweep", 0.3)
    # effect envelope: seq3's notes retrigger it, feedback swells toward 0.99
    for k, v in (("a", 0.01), ("d", 0.6), ("s", 0.25), ("r", 0.4)):
        st(dly, k, v)
    sq1 = place("sequencer", 0.78, -0.35, a_preset(1))
    pattern(sq1, 1, [
        (1, 0, .9), (0, 0), (0, 0), (1, 0, .7),
        (0, 0), (0, 0), (1, 0, .9), (0, 0),
        (0, 0), (1, 0, .7), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (1, 0, .6), (0, 0)])
    link(sq1, clv)
    sq2 = place("sequencer", 0.80, 0.28, a_preset(1))
    pattern(sq2, 1, [
        (0, 0), (0, 0), (1, 0, .8), (0, 0),
        (0, 0), (1, 0, .6), (0, 0), (0, 0),
        (0, 0), (0, 0), (0, 0), (1, 0, .7),
        (0, 0), (0, 0), (0, 0), (1, 0, .9)])
    link(sq2, cow)
    sq3 = place("sequencer", 0.10, 0.45, a_preset(1))
    pattern(sq3, 1, [
        (1, 0, .9, 8), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 0, .9, 8), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)])
    link(sq3, dly)
    tempo_obj(100)
    output_obj(vol=0.8, rev=0.15, room=0.45)

def b08():  # SIREN — dub echo: a second sequencer plays the DELAY TIME
    # (note -> delay time, new in v3.4) — echo pitch is a played instrument
    osc = place("oscillator", 0.55, -0.10, a_freq(220))
    st(osc, "subtype", 1)  # sine pluck
    st(osc, "amp", 0.6)
    for k, v in (("a", 0.005), ("d", 0.3), ("s", 0.3), ("r", 0.2)):
        st(osc, k, v)
    dly = place("delay", 0.28, 0.0, a_time(0.25))
    st(dly, "subtype", 1)  # feedback
    st(dly, "feedback", 0.8)   # ringing, near self-oscillation
    st(dly, "sweep", 0.15)     # tape-glide between note-set times
    sq1 = place("sequencer", 0.72, -0.30, a_preset(1))
    pattern(sq1, 1, [  # sparse plucks feed the echo
        (1, 0, .9, 4), (0, 0), (0, 0), (0, 0),
        (0, 0), (0, 0), (1, 3, .7), (0, 0),
        (0, 0), (1, 7, .8, 4), (0, 0), (0, 0),
        (0, 0), (0, 0), (1, 5, .7), (0, 0)])
    link(sq1, osc)
    sq2 = place("sequencer", 0.05, 0.35, a_preset(1))
    pattern(sq2, 1, [  # the echo melody: pitch sweeps the delay time
        (1, -12, .8, 8), (0, 0), (0, 0), (0, 0), (1, -5, .8, 8), (0, 0), (0, 0), (0, 0),
        (1, 0, .8, 8), (0, 0), (0, 0), (0, 0), (1, 7, .8, 8), (0, 0), (0, 0), (0, 0)])
    link(sq2, dly)
    ton = place("tonality", -0.48, -0.25, a_root(9))  # A minor
    st(ton, "subtype", 2)
    tempo_obj(96)
    output_obj(vol=0.8, rev=0.3, room=0.55)

def b09():  # CHOIR — parallel generators, chorus, vibrato LFO, big reverb
    cel = place("sampler", 0.55, -0.15, a_freq(196.0))
    st(cel, "subtype", 1)  # instrument
    load(cel, f"{D}/instruments/cello_G3.wav")
    st(cel, "base", 196.0)
    vln = place("sampler", 0.55, 0.20, a_freq(440.0))
    st(vln, "subtype", 1)
    load(vln, f"{D}/instruments/violin_A4.wav")
    st(vln, "base", 440.0)
    root = place("oscillator", 0.50, -0.48, a_freq(98))
    st(root, "subtype", 1)  # sine drone, straight to output
    st(root, "amp", 0.4)
    sub(root, 1, wave=0, amp=0.5, off=-12)
    chor = place("modulator", 0.28, 0.05, a_01(0.5))
    st(chor, "subtype", 2)  # chorus
    st(chor, "drywet", 0.45)
    lfo = place("lfo", 0.05, 0.30, a_lfo(0.5))
    st(lfo, "subtype", 1)  # sine
    st(lfo, "sync", 1)
    st(lfo, "mult", 32)    # whole-note swell
    st(lfo, "depth", 0.3)
    link(lfo, chor)
    sq1 = place("sequencer", 0.78, -0.30, a_preset(1))
    pattern(sq1, 1, [
        (1, 0, .8, 8), (0, 0), (0, 0), (0, 0), (1, 3, .7, 8), (0, 0), (0, 0), (0, 0),
        (1, 5, .8, 8), (0, 0), (0, 0), (0, 0), (1, 3, .7, 8), (0, 0), (0, 0), (0, 0)])
    link(sq1, cel)
    sq2 = place("sequencer", 0.78, 0.35, a_preset(1))
    pattern(sq2, 1, [  # a fifth-plus-octave above the cello line
        (1, 19, .7, 8), (0, 0), (0, 0), (0, 0), (1, 22, .6, 8), (0, 0), (0, 0), (0, 0),
        (1, 24, .7, 8), (0, 0), (0, 0), (0, 0), (1, 22, .6, 8), (0, 0), (0, 0), (0, 0)])
    link(sq2, vln)
    tempo_obj(60)
    output_obj(vol=0.8, rev=0.5, room=0.7)

def b10():  # TIDE — new-age pulse in F lydian; a second sequencer sweeps
    # the compressor by pitch (note -> main), so the whole table breathes
    osc = place("oscillator", 0.55, -0.10, a_freq(174.61))  # F3
    st(osc, "subtype", 2)  # saw
    st(osc, "amp", 0.5)
    sub(osc, 1, wave=0, amp=0.35, off=12)   # octave shimmer
    sub(osc, 2, wave=0, amp=0.2, off=-12)
    for k, v in (("a", 0.01), ("d", 0.25), ("s", 0.5), ("r", 0.4)):
        st(osc, k, v)
    shp = place("waveshaper", 0.30, -0.02, a_01(0.4))
    st(shp, "subtype", 2)  # compressor — the tide sucks back and swells
    st(shp, "drywet", 0.6)
    dly = place("delay", 0.12, 0.08, a_time(0.5))
    st(dly, "subtype", 2)  # pingpong
    st(dly, "sync", 1)
    st(dly, "feedback", 0.35)
    sq1 = place("sequencer", 0.72, -0.30, a_preset(1))
    pattern(sq1, 1, [  # breathing pulse, lydian #4 (11) as the sparkle, 2 bars
        (1, 0, .5, 4), (1, 7, .35, 4), (1, 4, .55, 4), (1, 7, .35, 4),
        (1, 0, .6, 4), (1, 7, .35, 4), (1, 11, .5, 4), (1, 7, .4, 4),
        (1, 0, .65, 4), (1, 7, .4, 4), (1, 4, .55, 4), (1, 9, .45, 4),
        (1, 6, .5, 4), (1, 4, .4, 4), (1, 7, .55, 4), (1, 4, .4, 4)])
    link(sq1, osc)
    sq2 = place("sequencer", 0.25, 0.40, a_preset(1))
    pattern(sq2, 1, [  # the tide: compression sweeps in and out over 4 bars
        (1, -12, .8, 8), (0, 0, 0, 8), (1, 0, .8, 8), (0, 0, 0, 8),
        (1, 12, .8, 8), (0, 0, 0, 8), (1, 0, .8, 8), (0, 0, 0, 8),
        (1, -5, .8, 8), (0, 0, 0, 8), (1, 5, .8, 8), (0, 0, 0, 8),
        (0, 0, 0, 8), (0, 0, 0, 8), (0, 0, 0, 8), (0, 0, 0, 8)])
    link(sq2, shp)
    ton = place("tonality", -0.48, -0.28, a_root(5))
    st(ton, "subtype", 1)  # major preset, then edit to F lydian
    notes(ton, [1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0])  # lydian mask
    tempo_obj(80)
    output_obj(vol=0.8, rev=0.35, room=0.6)

def b11():  # SOLO — random sequencer + pentatonic = automatic solos
    ther = place("sampler", 0.55, -0.05, a_freq(277.18))
    st(ther, "subtype", 1)
    load(ther, f"{D}/instruments/theremin_Cs4.wav")
    st(ther, "base", 277.18)
    st(ther, "amp", 1.0)   # smooth source, short gates: needs the headroom
    for k, v in (("a", 0.03), ("d", 0.2), ("s", 1.0), ("r", 0.7)):
        st(ther, k, v)  # long release: gate-off glides instead of blipping
    chor = place("modulator", 0.32, 0.0, a_01(0.35))
    st(chor, "subtype", 2)
    st(chor, "drywet", 0.35)
    dly = place("delay", 0.14, 0.10, a_time(0.45))
    st(dly, "subtype", 1)  # feedback
    st(dly, "sync", 1)
    st(dly, "feedback", 0.55)
    seq = place("sequencer", 0.78, -0.25, a_preset(1))
    st(seq, "subtype", 2)  # random: velocity gates the dice, pitch is luck
    pattern(seq, 1, [  # fully dense (the v3.4.2 feel the owner loved),
        # dynamics by velocity, holds long enough for the theremin's
        # slow attack to open before the gate releases
        (1, 0, .90, 4), (1, 0, .45, 2), (1, 0, .50, 3), (1, 0, .70, 4),
        (1, 0, .45, 2), (1, 0, .90, 4), (1, 0, .45, 2), (1, 0, .45, 5),
        (1, 0, .80, 4), (1, 0, .45, 2), (1, 0, .60, 3), (1, 0, .45, 4),
        (1, 0, .90, 4), (1, 0, .50, 2), (1, 0, .45, 3), (1, 0, .70, 5)])
    link(seq, ther)
    ton = place("tonality", -0.48, -0.28, a_root(9))
    st(ton, "subtype", 3)  # pentatonic: every roll is musical
    tempo_obj(112)
    output_obj(vol=0.8, rev=0.3, room=0.5)

def b12():  # DRIFT — multi-osc stack, per-osc drift LFOs, random-seq filter swells
    o1 = place("oscillator", 0.50, -0.18, a_freq(110))
    st(o1, "subtype", 2)  # saw
    st(o1, "amp", 0.65)
    sub(o1, 1, wave=1, amp=0.45, off=-12)     # octave down
    sub(o1, 2, wave=1, amp=0.3, off=7, det=8) # detuned fifth
    subfollow(o1, 1)                           # subs snap to the tonality
    o2 = place("oscillator", 0.50, 0.15, a_freq(110.8))  # beating detune
    st(o2, "subtype", 3)  # square
    st(o2, "amp", 0.5)
    sub(o2, 1, wave=3, amp=0.25, off=12, det=10)  # detuned octave up
    subfollow(o2, 1)
    o3 = place("oscillator", 0.26, 0.32, a_freq(55))
    st(o3, "subtype", 1)  # sine sub-bass
    st(o3, "amp", 0.65)
    flt = place("filter", 0.22, 0.0, a_cut(900))
    st(flt, "subtype", 1)  # lp
    st(flt, "res", 0.45)
    for k, v in (("a", 0.3), ("d", 1.5), ("s", 0.0), ("r", 1.0)):
        st(flt, k, v)  # cutoff swells on each random-seq trigger
    cho = place("delay", 0.02, -0.12, a_01(0.6))  # reverb: rotation = room
    st(cho, "subtype", 3)  # reverb
    st(cho, "room", 0.7)
    st(cho, "feedback", 0.45)  # reverb subtype: feedback arg = mix
    l1 = place("lfo", 0.66, -0.32, a_lfo(0.09))
    st(l1, "subtype", 1)
    st(l1, "depth", 0.15)
    link(l1, o1)         # slow pitch drift on the saw
    l2 = place("lfo", 0.68, 0.28, a_lfo(0.13))
    st(l2, "subtype", 1)
    st(l2, "depth", 0.12)
    link(l2, o2)         # a different drift on the square
    drone = place("oscillator", 0.44, 0.42, a_freq(55))
    st(drone, "subtype", 1)  # sine root drone: anchors the randomness
    st(drone, "amp", 0.3)
    seq = place("sequencer", 0.05, 0.30, a_preset(1))
    st(seq, "subtype", 2)  # random (NOT 3=drift — builder predated renumber)
    pattern(seq, 1, [
        (1, 0, .8), (0, 0), (0, 0), (0, 0),
        (1, 0, .6), (0, 0), (1, 0, .7), (0, 0),
        (0, 0), (0, 0), (1, 0, .8), (0, 0),
        (0, 0), (1, 0, .6), (0, 0), (0, 0)])
    link(seq, flt)       # sparse gates retrigger the filter envelope
    ton = place("tonality", -0.45, -0.35, a_root(9))
    st(ton, "subtype", 3)  # pentatonic: lifts the haze toward new-age
    tempo_obj(66)
    output_obj(vol=0.8, rev=0.4, room=0.7, comp=0.25)

def b13():  # CLAVE — world percussion: double-tresillo clave, answering
    # rim, low tom heartbeat, 3-feel hat accents; a whisper of bitcrush
    clv = place("sampler", 0.45, -0.30, a_freq(261.6))
    st(clv, "subtype", 2)
    load(clv, f"{D}/drums/clave.wav")
    st(clv, "amp", 0.8)
    rim = place("sampler", 0.50, 0.05, a_freq(261.6))
    st(rim, "subtype", 2)
    load(rim, f"{D}/TR909-Syn_Rim.wav")
    st(rim, "amp", 0.65)
    tom = place("sampler", 0.42, 0.40, a_freq(130))
    st(tom, "subtype", 2)
    load(tom, f"{D}/drums/tom.wav")
    st(tom, "amp", 0.85)
    hat = place("sampler", 0.10, -0.45, a_freq(261.6))
    st(hat, "subtype", 2)
    load(hat, f"{D}/drums/chh.wav")
    st(hat, "amp", 0.4)
    shp = place("waveshaper", 0.18, 0.25, a_01(0.5))
    st(shp, "subtype", 1)  # resampler: a whisper of grit on the tom
    st(shp, "drywet", 0.3)
    sq1 = place("sequencer", 0.72, -0.42, a_preset(1))
    pattern(sq1, 1, [  # double tresillo: hits at 0,3,6 / 8,11,14
        (1, 0, .9, 3), (1, 0, .75, 3), (1, 0, .85, 2),
        (1, 0, .9, 3), (1, 0, .75, 3), (1, 0, .85, 2),
        (0, 0, 0, 2), (0, 0, 0, 2), (0, 0, 0, 2), (0, 0, 0, 2),
        (0, 0, 0, 2), (0, 0, 0, 2), (0, 0, 0, 1), (0, 0, 0, 1),
        (0, 0, 0, 1), (0, 0, 0, 1)])
    link(sq1, clv)
    sq2 = place("sequencer", 0.75, 0.10, a_preset(1))
    pattern(sq2, 1, [  # rim answers between the clave hits
        (0, 0, 0, 2), (1, 0, .7, 2), (0, 0, 0, 2), (0, 0, 0, 2),
        (1, 0, .75, 2), (0, 0, 0, 2), (0, 0, 0, 2), (1, 0, .6, 2),
        (0, 0, 0, 2), (1, 0, .7, 2), (0, 0, 0, 2), (0, 0, 0, 2),
        (1, 0, .75, 2), (0, 0, 0, 2), (1, 0, .55, 1), (1, 0, .5, 1)])
    link(sq2, rim)
    sq3 = place("sequencer", 0.68, 0.52, a_preset(1))
    pattern(sq3, 1, [  # tom heartbeat: 1, the and of 2, 3
        (1, 0, .95, 4), (0, 0, 0, 2), (0, 0, 0, 2),
        (1, 0, .8, 2), (0, 0, 0, 2), (1, 0, .6, 2),
        (1, 0, .9, 4), (0, 0, 0, 2), (0, 0, 0, 2),
        (0, 0, 0, 2), (1, 0, .7, 2), (0, 0, 0, 2),
        (0, 0, 0, 2), (0, 0, 0, 1), (0, 0, 0, 1), (0, 0, 0, 2)])
    link(sq3, tom)
    sq4 = place("sequencer", -0.05, -0.62, a_preset(1))
    pattern(sq4, 1, [  # hat 16ths, accents lean on the 3-feel
        (1, 0, .6, 2), (1, 0, .3, 2), (1, 0, .45, 2), (1, 0, .3, 2),
        (1, 0, .55, 2), (1, 0, .3, 2), (1, 0, .45, 2), (1, 0, .35, 2),
        (1, 0, .6, 2), (1, 0, .3, 2), (1, 0, .45, 2), (1, 0, .3, 2),
        (1, 0, .55, 2), (1, 0, .35, 2), (1, 0, .45, 2), (1, 0, .5, 2)])
    link(sq4, hat)
    tempo_obj(104)
    output_obj(vol=0.85, comp=0.25)

def b14():  # SIX — one sequencer, six authored patterns: rotation = section
    # (intro/verse/build/peak/break/outro). the arrangement performance move
    lead = place("oscillator", 0.52, -0.10, a_freq(196))
    st(lead, "subtype", 2)  # saw
    st(lead, "amp", 0.6)
    flt = place("filter", 0.28, -0.02, a_cut(1100))
    st(flt, "subtype", 1)
    st(flt, "res", 0.35)
    kick = place("sampler", 0.35, 0.35, a_freq(261.6))
    st(kick, "subtype", 2)
    load(kick, f"{D}/drums/kick.wav")
    sqk = place("sequencer", 0.62, 0.50, a_preset(1))
    pattern(sqk, 1, [  # steady pulse, all six sections long
        (1, 0, .9), (0, 0), (0, 0), (0, 0),
        (1, 0, .85), (0, 0), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (0, 0), (0, 0),
        (1, 0, .85), (0, 0), (0, 0), (1, 0, .4)])
    link(sqk, kick)
    sq = place("sequencer", 0.72, -0.32, a_preset(1))
    pattern(sq, 1, [  # p1 intro: three notes, lots of air
        (1, 0, .8, 4), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 7, .8, 4), (0, 0), (0, 0), (0, 0), (1, 5, .7), (0, 0), (0, 0), (0, 0)])
    pattern(sq, 2, [  # p2 verse: the theme
        (1, 0, .9), (0, 0), (1, 3, .7), (0, 0),
        (1, 7, .9), (0, 0), (1, 5, .7), (0, 0),
        (1, 0, .9), (0, 0), (1, 10, .8), (0, 0),
        (1, 7, .8), (0, 0), (1, 5, .7, 4), (0, 0)])
    pattern(sq, 3, [  # p3 build: 8ths, climbing
        (1, 0, .85), (1, 3, .6), (1, 5, .7), (1, 7, .8),
        (1, 0, .85), (1, 3, .6), (1, 5, .7), (1, 10, .8),
        (1, 0, .85), (1, 3, .6), (1, 5, .7), (1, 7, .8),
        (1, 12, .9), (1, 10, .7), (1, 7, .8), (1, 5, .7)])
    pattern(sq, 4, [  # p4 peak: 16ths, octave jumps
        (1, 0, .9), (1, 12, .6), (1, 0, .6), (1, 12, .7),
        (1, 3, .8), (1, 15, .6), (1, 3, .6), (1, 15, .7),
        (1, 5, .9), (1, 17, .6), (1, 5, .6), (1, 17, .7),
        (1, 7, .9), (1, 19, .7), (1, 12, .8), (1, 7, .8)])
    pattern(sq, 5, [  # p5 breakdown: long notes, low register
        (1, -12, .85, 8), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0),
        (1, -5, .8, 8), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)])
    pattern(sq, 6, [  # p6 outro: the theme, half as busy, final bar holds
        (1, 0, .85), (0, 0), (1, 3, .6), (0, 0),
        (1, 7, .8), (0, 0), (0, 0), (0, 0),
        (1, 0, .85), (0, 0), (1, 5, .6), (0, 0),
        (1, 0, .9, 8), (0, 0), (0, 0), (0, 0)])
    rot(sq, a_preset(1))
    link(sq, lead)
    ton = place("tonality", -0.48, -0.28, a_root(9))  # A minor
    st(ton, "subtype", 2)
    tempo_obj(118)
    output_obj(vol=0.8, comp=0.2)

def b15():  # ZOO — sound design with animal generators
    ele = place("sampler", 0.55, -0.25, a_freq(200))
    st(ele, "subtype", 2)
    load(ele, f"{D}/animals/elephant.wav")
    st(ele, "amp", 0.8)
    flt = place("filter", 0.30, -0.15, a_cut(900))
    st(flt, "subtype", 2)  # bp: trumpet -> alien bird
    st(flt, "res", 0.6)
    dly = place("delay", 0.12, -0.05, a_time(0.75))
    st(dly, "subtype", 2)  # pingpong
    st(dly, "sync", 1)
    st(dly, "feedback", 0.5)
    cri = place("loop", 0.50, 0.30, a_rate(2))
    st(cri, "subtype", 1)
    load(cri, f"{D}/animals/crickets.wav")
    st(cri, "amp", 0.35)   # rate-2 crickets = shaker groove
    bear = place("loop", 0.15, 0.45, a_rate(0.25))
    st(bear, "subtype", 1)
    load(bear, f"{D}/animals/bear.wav")
    st(bear, "amp", 0.5)   # quarter-speed growl = bass drone
    shp = place("waveshaper", 0.10, 0.25, a_01(0.7))
    st(shp, "subtype", 1)  # resampler grit on the drone
    st(shp, "drywet", 0.5)
    frog = place("sampler", 0.40, 0.50, a_freq(320))
    st(frog, "subtype", 2)
    load(frog, f"{D}/animals/frog.wav")
    sq1 = place("sequencer", 0.80, -0.42, a_preset(1))
    pattern(sq1, 1, [
        (1, 0, .9, 4), (0, 0), (0, 0), (0, 0),
        (0, 0), (0, 0), (0, 0), (1, 0, .7),
        (0, 0), (0, 0), (1, 0, .85, 4), (0, 0),
        (0, 0), (0, 0), (0, 0), (0, 0)])
    link(sq1, ele)
    sq2 = place("sequencer", 0.62, 0.68, a_preset(1))
    pattern(sq2, 1, [
        (0, 0), (0, 0), (1, 0, .8), (0, 0),
        (0, 0), (0, 0), (0, 0), (0, 0),
        (0, 0), (1, 0, .7), (0, 0), (0, 0),
        (0, 0), (0, 0), (1, 0, .9), (0, 0)])
    link(sq2, frog)
    tempo_obj(80)
    output_obj(vol=0.85, rev=0.4, room=0.65)

def b16():  # FINALE — everything at once (15 objects: re-benchmark CPU)
    kick = place("sampler", 0.58, -0.28, a_freq(261.6))
    st(kick, "subtype", 2)
    load(kick, f"{D}/drums/kick.wav")
    snr = place("sampler", 0.60, -0.02, a_freq(261.6))
    st(snr, "subtype", 2)
    load(snr, f"{D}/drums/snare.wav")
    ohh = place("sampler", 0.58, 0.22, a_freq(261.6))
    st(ohh, "subtype", 2)
    load(ohh, f"{D}/drums/ohh.wav")
    st(ohh, "amp", 0.45)
    tuba = place("sampler", 0.30, -0.52, a_freq(116.54))
    st(tuba, "subtype", 1)
    load(tuba, f"{D}/instruments/tuba_As2.wav")
    st(tuba, "base", 116.54)
    horn = place("sampler", 0.32, 0.48, a_freq(392.0))
    st(horn, "subtype", 1)
    load(horn, f"{D}/instruments/horn_G4.wav")
    st(horn, "base", 392.0)
    st(horn, "amp", 0.7)
    ther = place("sampler", -0.02, 0.58, a_freq(277.18))
    st(ther, "subtype", 1)
    load(ther, f"{D}/instruments/theremin_Cs4.wav")
    st(ther, "base", 277.18)
    st(ther, "amp", 0.5)
    sqk = place("sequencer", 0.82, -0.38, a_preset(1))
    pattern(sqk, 1, [
        (1, 0, .95), (0, 0), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (0, 0), (1, 0, .3),
        (1, 0, .95), (0, 0), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (1, 0, .35), (0, 0)])
    link(sqk, kick)
    sqs = place("sequencer", 0.84, -0.08, a_preset(1))
    pattern(sqs, 1, [
        (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 0, .9), (0, 0), (0, 0), (0, 0),
        (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 0, .95), (0, 0), (0, 0), (1, 0, .45)])
    link(sqs, snr)
    sqh = place("sequencer", 0.82, 0.30, a_preset(1))
    pattern(sqh, 1, [
        (0, 0), (0, 0), (1, 0, .6), (0, 0),
        (0, 0), (0, 0), (1, 0, .55), (0, 0),
        (0, 0), (0, 0), (1, 0, .6), (0, 0),
        (0, 0), (0, 0), (1, 0, .55), (1, 0, .45)])
    link(sqh, ohh)
    sqb = place("sequencer", 0.10, -0.68, a_preset(1))
    pattern(sqb, 1, [
        (1, 0, .9), (0, 0), (1, 0, .5), (0, 0),
        (1, 7, .8), (0, 0), (1, 0, .6), (0, 0),
        (1, 0, .9), (0, 0), (1, 12, .8), (0, 0),
        (1, 7, .7), (0, 0), (1, 5, .6), (0, 0)])
    link(sqb, tuba)
    sqn = place("sequencer", 0.52, 0.62, a_preset(1))
    pattern(sqn, 1, [
        (0, 0), (0, 0), (1, 15, .8, 2), (0, 0),
        (0, 0), (0, 0), (0, 0), (1, 12, .7, 2),
        (0, 0), (0, 0), (1, 19, .85, 2), (0, 0),
        (0, 0), (1, 15, .7, 2), (0, 0), (0, 0)])
    link(sqn, horn)
    sqp = place("sequencer", -0.22, 0.70, a_preset(1))
    pattern(sqp, 1, [
        (1, 0, .6, 8), (0, 0), (0, 0), (0, 0),
        (0, 0), (0, 0), (0, 0), (0, 0),
        (1, 3, .55, 8), (0, 0), (0, 0), (0, 0),
        (0, 0), (0, 0), (0, 0), (0, 0)])
    link(sqp, ther)
    ton = place("tonality", -0.50, -0.35, a_root(9))  # A minor
    st(ton, "subtype", 2)
    tempo_obj(122, x=-0.55, y=0.45)
    output_obj(vol=0.85, rev=0.25, room=0.5, comp=0.3, x=0.0, y=-0.80)


BUILDERS = {n: b for n, b in enumerate([b01, b02, b03, b04, b05, b06, b07, b08,
                                  b09, b10, b11, b12, b13, b14, b15, b16], 1)}

# ---------- entry ----------

def build(n):
    print(f"[preset {n}] clearing table")
    api("/clear", {})
    BUILDERS[n]()
    save(n)
    s = state()
    print(f"[preset {n}] saved to slot {n}: "
          f"{len(s['objects'])} objects, {len(s['connections'])} connections")

def pull():
    import paramiko
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from deploy import creds
    host, user, pw = creds()
    t = paramiko.Transport((host, 22)); t.connect(username=user, password=pw)
    sftp = paramiko.SFTPClient.from_transport(t)
    os.makedirs("data/slots", exist_ok=True)
    for i in range(1, 17):
        remote = f"/home/we/dust/data/rotatable/slots/{i}.lua"
        try:
            sftp.get(remote, f"data/slots/{i}.lua")
            print(f"pulled slot {i}")
        except FileNotFoundError:
            print(f"slot {i} missing on device")
    sftp.close(); t.close()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--pull":
        pull()
    elif len(sys.argv) > 1:
        lo, _, hi = sys.argv[1].partition("-")
        for n in range(int(lo), int(hi or lo) + 1):
            build(n)
    else:
        print(__doc__)
