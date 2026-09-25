-- audio.lua — glue: world state -> Engine_Rotatable commands (phase 4)
-- hooks World.add/remove/recompute/toggle_mute; engine-side stays the source
-- of truth for routing, lua mirrors it in `nodes`.

local Audio = {}

local World

local HAS_SYNTH = { oscillator = true, loop = true, filter = true,
  delay = true, modulator = true, lfo = true }

-- id -> { type=, out=dst_id|"output"|nil, kind=, muted=, cparam=, freq= }
local nodes = {}

-- angle -> primary param (rotation = primary, behavior-spec §3)
local function primary(o)
  local f = o.angle / (2 * math.pi)
  if o.type == "oscillator" then return "freq", 55 * (2 ^ (f * 4))       -- 55..880 Hz
  elseif o.type == "loop" then return "rate", 0.25 * (2 ^ (f * 4))        -- 0.25..4
  elseif o.type == "filter" then return "cutoff", 40 * (300 ^ f)          -- 40..12000 Hz
  elseif o.type == "delay" then return "time", 0.01 * (200 ^ f)           -- 0.01..2 s
  elseif o.type == "modulator" then return "main", f
  elseif o.type == "lfo" then return "freq", 0.05 * (400 ^ f)             -- 0.05..20 Hz
  elseif o.type == "sequencer" then return "preset", 1 + math.floor(f * 5.999)
  elseif o.type == "output" then return "volume", f
  end
end

-- push an object's params/subtype/angle to the engine
function Audio.sync_object(o)
  if not nodes[o.id] then return end
  local k, v = primary(o)
  if o.type == "output" then
    engine.set(o.id, "volume", v)
    return
  end
  if not HAS_SYNTH[o.type] then return end
  engine.set(o.id, "select", o.subtype - 1)
  if k then engine.set(o.id, k, v) end
  for p, val in pairs(o.params) do
    if p ~= k then
      if o.type == "filter" and p == "res" then
        engine.set(o.id, "rq", 1.05 - util.clamp(val, 0, 1))
      elseif o.type == "loop" and p == "speed" then
        if k ~= "rate" then engine.set(o.id, "rate", val) end
      elseif p == "freq" or p == "amp" or p == "cutoff" or p == "time"
        or p == "feedback" or p == "main" or p == "drywet" or p == "depth" then
        engine.set(o.id, p, val)
      end
    end
  end
  if o.type == "oscillator" or o.type == "loop" then
    engine.set(o.id, "a", o.env.a)
    engine.set(o.id, "d", o.env.d)
    engine.set(o.id, "s", o.env.s)
    engine.set(o.id, "r", o.env.r)
  end
  if o.type == "oscillator" then nodes[o.id].freq = v end
end

-- LFO target param: amp (generators), drywet (modulator), amp elsewhere
local function lfo_target_param(t)
  if World.TYPES[t.type].category == "generator" then return "amp" end
  if t.type == "modulator" then return "drywet" end
  return "amp"
end

-- diff World.connections against `nodes`, issue connect/disconnect/mute
function Audio.sync_connections()
  local desired = {}
  for _, c in ipairs(World.connections) do
    if HAS_SYNTH[c.a.type] or c.a.type == "sequencer" then
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
    if n and n.type ~= "sequencer" then
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
    elseif n and n.type == "sequencer" and d.kind == "control" then
      n.out, n.kind, n.muted = d.dst, "control", d.muted
    end
  end
end

function Audio.on_add(o)
  nodes[o.id] = { type = o.type }
  engine.add(o.id, o.type, o.subtype - 1)
  Audio.sync_object(o)
  Audio.sync_connections()
end

function Audio.on_remove(id)
  nodes[id] = nil
  engine.remove(id)
  Audio.sync_connections()
end

function Audio.reset()
  for id in pairs(nodes) do engine.remove(id) end
  nodes = {}
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

-- sequencer clock tick: plays the object's own 16-step pattern
-- (edited in the L3 steps panel). triggers connected oscillators.
function Audio.seq_tick(step)
  for id, n in pairs(nodes) do
    if n.type == "sequencer" and n.kind == "control" and n.out and not n.muted then
      local o = World.get(id)
      local t = nodes[n.out]
      if o and o.steps and o.steps[step].on
        and t and t.type == "oscillator" and t.freq then
        local st = o.steps[step]
        engine.set(n.out, "amp", st.vel)
        engine.trigger(n.out, t.freq * (2 ^ (st.pitch / 12)))
      end
    end
  end
end

-- loop player sample load (browser panel)
function Audio.load_sample(o, path)
  o.sample = path
  engine.loadbuf(o.id, path)
end

return Audio
