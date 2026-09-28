-- world.lua — table world model: objects + proximity connections
-- v2: 13 of the original 14 types (phase-6 decisions; song settings dropped,
-- pitchlock dropped, MIDI-in still pending)

local World = {}

local Tonality = include('lib/tonality')

-- 12-degree scale mask from a tonality subtype preset (editable on-object)
local function tonality_mask(subtype_name)
  local m = {}
  for i = 0, 11 do m[i] = false end
  for _, d in ipairs(Tonality.SCALES[subtype_name]) do m[d] = true end
  return m
end
World.tonality_mask = tonality_mask

World.TABLE_R = 1.0
World.CONNECT_DIST = 0.35 -- world units; gap-items decision, tune later

-- type registry: category drives glyph shape + connection behavior
-- params are pushed to the engine by lib/audio.lua (sync_object)
World.TYPES = {
  oscillator = { category = "generator", label = "OSC",
    subtypes = { "sine", "saw", "square", "noise" },
    params = { freq = 220, amp = 0.8 } },
  loop = { category = "generator", label = "LOOP",
    subtypes = { "loop", "oneshot" }, -- pitchlock dropped (phase-6)
    params = { speed = 1.0, amp = 0.8, sync = 0 } }, -- sync: 0 immediate, 1 quarter, 2 bar
  sampler = { category = "generator", label = "SMP",
    subtypes = { "instrument", "drum" },
    params = { freq = 220, base = 261.6256, amp = 0.8 } }, -- base = sample's natural pitch
  input = { category = "generator", label = "IN",
    subtypes = { "line" },
    params = { gain = 0.8 } },
  filter = { category = "effect", label = "FLT",
    subtypes = { "lp", "bp", "hp" },
    params = { cutoff = 1200, res = 0.3 } },
  delay = { category = "effect", label = "DLY",
    subtypes = { "feedback", "pingpong", "reverb" },
    params = { time = 0.3, feedback = 0.4, sync = 0, sweep = 0.2, room = 0.4 } },
  modulator = { category = "effect", label = "MOD",
    subtypes = { "ring", "chorus", "flanger" },
    params = { main = 0.5, drywet = 0.5 } },
  waveshaper = { category = "effect", label = "SHP",
    subtypes = { "resampler", "compressor", "distortion" },
    params = { main = 0.5, drywet = 0.5 } },
  lfo = { category = "controller", label = "LFO",
    subtypes = { "sine", "saw", "square", "random" },
    params = { freq = 2.0, depth = 0.5, sync = 0, mult = 8 } }, -- mult: period in 32nd notes
  sequencer = { category = "controller", label = "SEQ",
    subtypes = { "mono", "poly", "random" },
    params = { preset = 1 } },
  midi = { category = "controller", label = "MIDI",
    subtypes = { "in" },
    params = { transpose = 0 } }, -- transpose: semitones, rotation ±24
  tonality = { category = "global", label = "TON",
    subtypes = { "major", "minor", "pentatonic", "chromatic" },
    params = { root = 0 } }, -- root: semitones from C
  tempo = { category = "global", label = "BPM",
    subtypes = { "bpm" },
    params = {} }, -- rotation drives the rot_tempo param (single source)
  output = { category = "global", label = "OUT",
    subtypes = { "master" },
    params = { volume = 0.8, rev = 0, room = 0.5, comp = 0 } }, -- global FX
}

-- the slider (spec §3 universal mapping): E3 in ROTATE + on-block dot.
-- amp for generators, dry/wet for mod+shaper, feedback for delay,
-- depth for LFO, resonance for filter; nil = no slider
World.SLIDER_PARAM = {
  oscillator = "amp", loop = "amp", sampler = "amp",
  filter = "res", delay = "feedback",
  modulator = "drywet", waveshaper = "drywet",
  lfo = "depth",
}

-- canonical object-type order for the place menu, grouped by category
World.MENU = {
  { header = "GENERATORS" },
  "oscillator", "loop", "sampler", "input",
  { header = "EFFECTS" },
  "filter", "delay", "modulator", "waveshaper",
  { header = "CONTROLLERS" },
  "lfo", "sequencer", "midi",
  { header = "GLOBALS" },
  "tonality", "tempo", "output",
}

World.objects = {}
World.connections = {}
World.hardlinks = {} -- set of "idA:idB" (smaller id first)
local next_id = 1

local function link_key(a, b)
  return a < b and (a .. ":" .. b) or (b .. ":" .. a)
end
World.link_key = link_key

local function default_params(type)
  local p = {}
  for k, v in pairs(World.TYPES[type].params) do p[k] = v end
  return p
end

function World.add(type, x, y, angle)
  local o = {
    id = next_id,
    type = type,
    subtype = 1,
    x = x or 0,
    y = y or 0,
    angle = angle or 0,
    params = default_params(type),
    -- effects get a percussive env (idle-neutral param envelopes);
    -- generators the classic ADSR
    env = World.TYPES[type].category == "effect"
      and { a = 0.01, d = 0.4, s = 0, r = 0.3 }
      or { a = 0.01, d = 0.1, s = 0.7, r = 0.3 },
  }
  if type == "sequencer" then
    -- 6 rotation-switched preset patterns (phase 8 batch 2); pattern 1 =
    -- the phase-4 pentatonic demo (odd steps on), 2-6 blank.
    -- dur = step length in 32nd notes (2 = 16th, the v1 timing)
    local PENTA_ST = { 0, 2, 4, 7, 9, 12, 14, 16 } -- semitone offsets
    o.patterns = {}
    for p = 1, 6 do
      local steps = {}
      for i = 1, 16 do
        local on = p == 1 and i % 2 == 1
        steps[i] = { on = on,
          pitch = on and PENTA_ST[(i - 1) / 2 + 1] or 0,
          vel = 0.8, dur = 2 }
      end
      o.patterns[p] = steps
    end
  elseif type == "oscillator" then
    -- sub-oscillators (spec §3.1): 4 subs x (waveform/amp/detune/offset);
    -- amp 0 = sub off. follow=1 snaps sub pitch to the table tonality
    o.subs = { follow = 0,
      { wave = 0, amp = 0, det = 0, off = -12 },
      { wave = 0, amp = 0, det = 0, off = -12 },
      { wave = 0, amp = 0, det = 0, off = 12 },
      { wave = 0, amp = 0, det = 0, off = 12 } }
  elseif type == "tonality" then
    o.notes = tonality_mask(World.TYPES.tonality.subtypes[1])
  elseif type == "loop" or type == "sampler" then
    o.sample = nil -- path of loaded WAV (browser panel)
  end
  next_id = next_id + 1
  table.insert(World.objects, o)
  World.recompute()
  return o
end

-- active pattern for a sequencer (rotation = preset slot, 1..6)
function World.seq_steps(o)
  return o.patterns[util.clamp(math.floor(o.params.preset or 1), 1, 6)]
end

function World.remove(id)
  for i, o in ipairs(World.objects) do
    if o.id == id then
      table.remove(World.objects, i)
      break
    end
  end
  for k in pairs(World.hardlinks) do
    local ka, kb = k:match("^(%d+):(%d+)$")
    if tonumber(ka) == id or tonumber(kb) == id then
      World.hardlinks[k] = nil
    end
  end
  World.recompute()
end

function World.get(id)
  for _, o in ipairs(World.objects) do
    if o.id == id then return o end
  end
end

function World.cycle_subtype(o, dir)
  local n = #World.TYPES[o.type].subtypes
  o.subtype = ((o.subtype - 1 + dir) % n) + 1
  if o.type == "tonality" then
    -- subtype = preset load: custom note edits are replaced
    o.notes = tonality_mask(World.TYPES.tonality.subtypes[o.subtype])
  end
end

function World.subtype_name(o)
  return World.TYPES[o.type].subtypes[o.subtype]
end

function World.toggle_hardlink(a_id, b_id)
  local k = link_key(a_id, b_id)
  World.hardlinks[k] = not World.hardlinks[k] and true or nil
  World.recompute()
  return World.hardlinks[k] == true
end

function World.is_hardlinked(a_id, b_id)
  return World.hardlinks[link_key(a_id, b_id)] == true
end

function World.toggle_mute(a_id, b_id)
  for _, c in ipairs(World.connections) do
    if c.b ~= "output" and link_key(c.a.id, c.b.id) == link_key(a_id, b_id) then
      c.muted = not c.muted
      return c.muted
    end
  end
  return nil -- no such connection
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local OUT = { x = 0, y = 0 } -- output point at table origin

local function nearest(o, pred, max_d)
  local best, best_d = nil, max_d or math.huge
  for _, p in ipairs(World.objects) do
    if p.id ~= o.id and pred(p) then
      local d = dist(o, p)
      if d < best_d then best, best_d = p, d end
    end
  end
  return best
end

local function cat(o) return World.TYPES[o.type].category end

-- hardlink override: if o is hardlinked to a valid target, return it
local function hardlink_target(o, pred)
  for _, p in ipairs(World.objects) do
    if p.id ~= o.id and World.is_hardlinked(o.id, p.id) and pred(p) then
      return p
    end
  end
end

-- proximity connection model (v2; refined when the engine lands):
--  generators: audio to nearest effect in range, else to the output point
--  effects: audio to nearest effect CLOSER TO THE OUTPUT POINT than itself
--    (signal flows toward the center, like effects sitting on the
--    generator's line in the original), else to the output point
--  controllers: control to hardlinked target, else closest object in range
--  globals: never connect
function World.recompute()
  local prev_mutes = {}
  for _, c in ipairs(World.connections) do
    if c.b ~= "output" and c.muted then
      prev_mutes[link_key(c.a.id, c.b.id)] = true
    end
  end
  World.connections = {}
  for _, o in ipairs(World.objects) do
    local c = cat(o)
    if c == "generator" then
      local fx = hardlink_target(o, function(p) return cat(p) == "effect" end)
        or nearest(o, function(p) return cat(p) == "effect" end, World.CONNECT_DIST)
      if fx then
        local conn = { a = o, b = fx, kind = "audio" }
        if prev_mutes[link_key(o.id, fx.id)] then conn.muted = true end
        table.insert(World.connections, conn)
      elseif dist(o, OUT) <= World.CONNECT_DIST * 2 then
        table.insert(World.connections, { a = o, b = "output", kind = "audio" })
      end
    elseif c == "effect" then
      local my_r = dist(o, OUT)
      -- hardlinks must respect flow direction too: targeting an effect that
      -- is not closer to the center can form a silent A<->B cycle (v3.0.1)
      local fx = hardlink_target(o, function(p)
        return cat(p) == "effect" and dist(p, OUT) < my_r
      end)
        or nearest(o, function(p)
          return cat(p) == "effect" and dist(p, OUT) < my_r
        end, World.CONNECT_DIST)
      if fx then
        local conn = { a = o, b = fx, kind = "audio" }
        if prev_mutes[link_key(o.id, fx.id)] then conn.muted = true end
        table.insert(World.connections, conn)
      elseif my_r <= World.CONNECT_DIST * 2 then
        table.insert(World.connections, { a = o, b = "output", kind = "audio" })
      end
    elseif c == "controller" then
      local t = hardlink_target(o, function(p) return cat(p) ~= "global" end)
        or nearest(o, function(p) return cat(p) ~= "global" end, World.CONNECT_DIST)
      if t then
        local conn = { a = o, b = t, kind = "control" }
        if prev_mutes[link_key(o.id, t.id)] then conn.muted = true end
        table.insert(World.connections, conn)
      end
    end
  end
end

return World
