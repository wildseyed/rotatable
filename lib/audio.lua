-- audio.lua — glue: world state -> Engine_Rotatable commands (phase 4 + v2)
-- hooks World.add/remove/recompute/toggle_mute; engine-side stays the source
-- of truth for routing, lua mirrors it in `nodes`.

-- include() is per-includer on norns: ui.lua gets its own copy of this file,
-- whose reset() used to clear a DIFFERENT `nodes` mirror — physical recalls
-- and table-clears leaked every engine node until scsynth ran out of RT
-- memory (2026-09-29). Singleton via a global (nuked on script clear).
if RotatableAudio then return RotatableAudio end

local Audio = {}

local World
local Tonality = include('lib/tonality')

local HAS_SYNTH = { oscillator = true, loop = true, sampler = true,
  input = true, filter = true, delay = true, modulator = true,
  waveshaper = true, lfo = true }

-- sequencer/MIDI note targets: osc+sampler get the pitched note, effects
-- get a bare envelope retrigger (filter cutoff, delay feedback, dry-wet)
local SEQ_TARGETS = { oscillator = true, sampler = true, filter = true,
  delay = true, modulator = true, waveshaper = true }

-- types whose ADSR the engine runs (env page + sync push)
local ENV_TYPES = { oscillator = true, loop = true, sampler = true,
  filter = true, delay = true, modulator = true, waveshaper = true }

-- id -> { type=, out=dst_id|"output"|nil, kind=, muted=, cparam=, freq=,
--         lvl_slot= }
local nodes = {}

-- last-known master volume (engine has no getter; we are the only writer)
local master_vol = 0.8

-- mirror of the engine's level-poll slot pool: the engine pops from the end
-- of its free list per addNode (audio defs only, not lfo) and pushes back on
-- freeNode; adds/removes arrive in the same order we issue them, so this
-- stays in sync. poll name for an object is "lvl_" .. slot.
local lvl_pool = {}
for i = 1, 16 do lvl_pool[i] = i end

-- poll name for an object's level meter, or nil (lfo/no-synth/pool exhausted)
function Audio.lvl_poll(id)
  local n = nodes[id]
  return n and n.lvl_slot and ("lvl_" .. n.lvl_slot) or nil
end

-- how many nodes of a type the mirror holds (T.health diagnostics)
function Audio.count_type(type)
  local n = 0
  for _, nd in pairs(nodes) do if nd.type == type then n = n + 1 end end
  return n
end

-- angle -> primary param (rotation = primary, behavior-spec §3)
local function primary(o)
  local f = o.angle / (2 * math.pi)
  if o.type == "oscillator" then return "freq", 55 * (2 ^ (f * 4))       -- 55..880 Hz
  elseif o.type == "loop" then return "rate", 0.25 * (2 ^ (f * 4))        -- 0.25..4
  elseif o.type == "sampler" then return "freq", 55 * (2 ^ (f * 4))       -- 55..880 Hz
  elseif o.type == "input" then return "gain", f
  elseif o.type == "filter" then return "cutoff", 40 * (300 ^ f)          -- 40..12000 Hz
  elseif o.type == "delay" then
    -- reverb subtype: rotation = room size (time is meaningless there)
    if o.subtype == 3 then return "room", f end
    return "time", 0.01 * (200 ^ f)                                        -- 0.01..2 s
  elseif o.type == "modulator" then return "main", f
  elseif o.type == "waveshaper" then return "main", f
  elseif o.type == "lfo" then return "freq", 0.05 * (400 ^ f)             -- 0.05..20 Hz
  elseif o.type == "sequencer" then return "preset", 1 + math.floor(f * 5.999)
  elseif o.type == "midi" then return "transpose", math.floor(f * 48.999) - 24
  elseif o.type == "tempo" then return "bpm", 40 + f * 200
  elseif o.type == "tonality" then return "root", math.floor(f * 12)
  elseif o.type == "output" then return "volume", f
  end
end

-- engine params pushed verbatim from o.params (everything not type-special)
local PASS_PARAMS = { freq = true, amp = true, cutoff = true, time = true,
  feedback = true, main = true, drywet = true, depth = true, gain = true,
  base = true, sync = true, sweep = true, mult = true, room = true }

-- push an object's params/subtype/angle to the engine
function Audio.sync_object(o)
  if not nodes[o.id] then return end
  local k, v = primary(o)
  if o.type == "output" then
    master_vol = v
    engine.set(o.id, "volume", v)
    engine.set(o.id, "rev", o.params.rev or 0)
    engine.set(o.id, "room", o.params.room or 0.5)
    engine.set(o.id, "comp", o.params.comp or 0)
    return
  end
  if o.type == "tempo" then
    -- rotation drives the param; its action fans out to metro + engine bus
    params:set("rot_tempo", util.clamp(math.floor(v + 0.5), 40, 240))
    return
  end
  if not HAS_SYNTH[o.type] then
    -- no engine node: params still need the rotation write-through
    -- (tonality root, sequencer preset, midi transpose)
    if k and o.params[k] ~= nil then o.params[k] = v end
    return
  end
  engine.set(o.id, "select", o.subtype - 1)
  if k then
    engine.set(o.id, k, v)
    if o.params[k] ~= nil then o.params[k] = v end
  end
  for p, val in pairs(o.params) do
    if p ~= k then
      if o.type == "filter" and p == "res" then
        engine.set(o.id, "rq", 1.05 - util.clamp(val, 0, 1))
      elseif o.type == "loop" and p == "speed" then
        if k ~= "rate" then engine.set(o.id, "rate", val) end
      elseif PASS_PARAMS[p] then
        engine.set(o.id, p, val)
      end
    end
  end
  if ENV_TYPES[o.type] then
    engine.set(o.id, "a", o.env.a)
    engine.set(o.id, "d", o.env.d)
    engine.set(o.id, "s", o.env.s)
    engine.set(o.id, "r", o.env.r)
  end
  if o.type == "oscillator" and o.subs then
    -- sub-oscillators; follow=1 snaps each sub's total pitch offset to the
    -- table tonality (lua-side: engine only knows the resulting off/det)
    local ton = o.subs.follow == 1 and Tonality.current(World) or nil
    for i = 1, 4 do
      local s = o.subs[i]
      local off, det = s.off, s.det
      if ton then
        -- snap the sub's absolute pitch, not just its offset (v3.0.1)
        local base = 69 + 12 * math.log((o.params.freq or 220) / 440, 2)
        local nn = Tonality.snap_abs(base + off + det / 100, ton.root, ton.scale)
        off, det = nn - base, 0
      end
      engine.set(o.id, "sub" .. i .. "w", s.wave)
      engine.set(o.id, "sub" .. i .. "a", s.amp)
      engine.set(o.id, "sub" .. i .. "d", det)
      engine.set(o.id, "sub" .. i .. "o", off)
    end
  end
  if o.type == "oscillator" or o.type == "sampler" then nodes[o.id].freq = v end
end

-- re-push all follow-tonality oscillators (call when tonality changes)
function Audio.resync_follow()
  for _, o in ipairs(World.objects) do
    if o.type == "oscillator" and o.subs and o.subs.follow == 1 then
      Audio.sync_object(o)
    end
  end
end

-- LFO target: all targets take the dedicated \mod arg (bipolar -1..1);
-- each engine synth applies its own scale (pitch-like bipolar, amp/dry-wet
-- unipolar — spec §9 decision 8); user .set calls can't break the mapping
local function lfo_target_param(t)
  return "mod"
end

-- diff World.connections against `nodes`, issue connect/disconnect/mute
function Audio.sync_connections()
  local desired = {}
  for _, c in ipairs(World.connections) do
    if HAS_SYNTH[c.a.type] or c.a.type == "sequencer" or c.a.type == "midi" then
      local dst = c.b == "output" and "output" or c.b.id
      desired[c.a.id] = { dst = dst, kind = c.kind, muted = c.muted == true,
        b = c.b }
    end
  end
  -- tear down routes that vanished
  for id, n in pairs(nodes) do
    if n.out ~= nil and desired[id] == nil then
      if n.kind == "audio" then
        engine.disconnect_audio(id)
      elseif n.kind == "control" then
        if HAS_SYNTH[n.type] and n.out ~= "output" then
          engine.disconnect_control(n.out, n.cparam)
        end
      end
      n.out, n.kind, n.muted = nil, nil, nil
    end
  end
  -- build new routes
  for id, d in pairs(desired) do
    local n = nodes[id]
    if n and n.type ~= "sequencer" and n.type ~= "midi" then
      if d.kind == "audio" then
        if n.out ~= d.dst or n.kind ~= "audio" then
          if d.dst == "output" then engine.connect_output(id)
          else engine.connect_audio(id, d.dst) end
          n.out, n.kind = d.dst, "audio"
        end
        if d.muted ~= (n.muted == true) then
          engine.mute(id, d.muted and 1 or 0)
          n.muted = d.muted
        end
      else -- control
        local t = d.dst ~= "output" and World.get(d.dst) or nil
        if n.type == "lfo" and t and HAS_SYNTH[t.type] then
          local p = lfo_target_param(t)
          if n.out ~= d.dst or n.cparam ~= p then
            engine.connect_control(id, d.dst, p)
            n.out, n.kind, n.cparam = d.dst, "control", p
          end
        end
      end
    elseif n and (n.type == "sequencer" or n.type == "midi") and d.kind == "control" then
      n.out, n.kind, n.muted = d.dst, "control", d.muted
    end
  end
end

function Audio.on_add(o)
  local n = { type = o.type }
  if HAS_SYNTH[o.type] and o.type ~= "lfo" then
    n.lvl_slot = table.remove(lvl_pool) -- engine pops the same end
  end
  if o.type == "tempo" then
    -- adopt the current bpm instead of resetting it to the angle default
    o.angle = (params:get("rot_tempo") - 40) / 200 * 2 * math.pi
  end
  if o.type == "output" then
    -- adopt the current master volume (angle 0 = silence on place)
    o.angle = master_vol * 2 * math.pi
  end
  nodes[o.id] = n
  engine.add(o.id, o.type, o.subtype - 1)
  Audio.sync_object(o)
  -- World.add recomputes (and syncs) BEFORE this engine node existed:
  -- routes pointing AT the new object were silently rejected engine-side
  -- while the mirror marked them done. Drop those memos so they re-issue
  -- now that the node exists.
  for id, m in pairs(nodes) do
    if m.out == o.id then m.out, m.kind = nil, nil end
  end
  Audio.sync_connections()
end

function Audio.on_remove(id)
  local n = nodes[id]
  if n and n.lvl_slot then table.insert(lvl_pool, n.lvl_slot) end
  nodes[id] = nil
  engine.remove(id)
  Audio.sync_connections()
end

function Audio.reset()
  -- mirror the engine: each remove pushes the slot back onto its free list
  local back = {}
  for id, n in pairs(nodes) do
    engine.remove(id)
    if n.lvl_slot then table.insert(back, n.lvl_slot) end
  end
  nodes = {}
  for _, s in ipairs(back) do table.insert(lvl_pool, s) end
  -- a removed output object leaves its volume behind on the master synth;
  -- a bare table (no output object) should not stay silent (e2e 2026-09-27)
  engine.volume(0.8)
  master_vol = 0.8
end

-- hook points: wrap World functions rather than editing its logic
function Audio.init(world)
  World = world
  local add0 = World.add
  local remove0 = World.remove
  local recompute0 = World.recompute
  local mute0 = World.toggle_mute
  World.add = function(...)
    local o = add0(...)
    Audio.on_add(o)
    return o
  end
  World.remove = function(id)
    Audio.on_remove(id)
    remove0(id)
  end
  World.recompute = function(...)
    recompute0(...)
    Audio.sync_connections()
  end
  World.toggle_mute = function(...)
    local m = mute0(...)
    Audio.sync_connections()
    return m
  end
end

-- sequencer clock tick (32nd notes): each sequencer free-runs its own
-- position; a step fires when its countdown (dur, in 32nds) elapses.
-- triggers connected oscillators/samplers. "random" subtype ignores the
-- pattern's pitch and improvises (quantized to the table's tonality when a
-- tonality object is present); its last played pitch per step slot is kept
-- in o._hist for the steps-page display.
function Audio.seq_tick(tick)
  local ton = Tonality.current(World)
  for id, n in pairs(nodes) do
    if n.type == "sequencer" then
      local o = World.get(id)
      if o and o.patterns then
        o._pos = o._pos or 16
        o._left = (o._left or 0) - 1
        if o._left <= 0 then
          o._pos = (o._pos % 16) + 1
          local st = World.seq_steps(o)[o._pos]
          o._left = st.dur or 2
          if st.on and n.kind == "control" and n.out and not n.muted then
            local t = nodes[n.out]
            if t and SEQ_TARGETS[t.type] then
              if t.freq then
                -- pitched target (osc/sampler): snap the ABSOLUTE note to
                -- the tonality (offset-snapping left the base out of key)
                local pitch = st.pitch
                local is_random = o.subtype == 3
                if is_random then pitch = math.random(-12, 24) end
                local base = 69 + 12 * math.log(t.freq / 440, 2)
                local nn = base + pitch
                if ton then nn = Tonality.snap_abs(nn, ton.root, ton.scale) end
                if is_random then
                  o._hist = o._hist or {}
                  o._hist[o._pos] = math.floor(nn - math.floor(base + 0.5) + 0.5)
                end
                engine.set(n.out, "amp", st.vel)
                engine.trigger(n.out, 440 * (2 ^ ((nn - 69) / 12)))
              else
                -- effect target: bare envelope retrigger
                engine.trigger(n.out, 0)
              end
            end
          end
        end
      end
    end
  end
end

-- MIDI-in: every midi object on the table forwards incoming notes to its
-- control target (closest connectable object), transposed by rotation.
-- note_on (vel>0) triggers like a sequencer note; note-off releases the
-- gate (osc/sampler ADSR). lua-side test hook: T.midi_note(n, v).
function Audio.midi_note(note, vel)
  for id, n in pairs(nodes) do
    if n.type == "midi" and n.kind == "control" and n.out and not n.muted then
      local o = World.get(id)
      local t = nodes[n.out]
      if o and t and SEQ_TARGETS[t.type] then
        if t.freq then
          -- legato: gate closes only when the last held note is released
          o._held = o._held or {}
          if vel > 0 then
            o._held[note] = true
            local st = note + (o.params.transpose or 0)
            engine.set(n.out, "amp", util.clamp(vel / 127, 0, 1))
            engine.trigger(n.out, 440 * (2 ^ ((st - 69) / 12)))
          else
            o._held[note] = nil
            if not next(o._held) then
              engine.set(n.out, "gate", 0)
            end
          end
        elseif vel > 0 then
          engine.trigger(n.out, 0) -- effect envelope; note-off ignored
        end
      end
    end
  end
end

-- loop player sample load (browser panel)
function Audio.load_sample(o, path)
  o.sample = path
  engine.loadbuf(o.id, path)
end

RotatableAudio = Audio
return Audio
