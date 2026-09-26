-- rotatable
-- v1.1.0 @wildseyed
-- github.com/wildseyed/rotatable
--
-- a reactable emulator:
-- the tangible table synth,
-- virtual on norns
--
-- K1+K3: place objects
-- move close to connect
-- K3 action / K2 back
-- full docs: README.md

engine.name = 'Rotatable'

local World = include('lib/world')
local Render = include('lib/render')
local UI = include('lib/ui')
local Audio = include('lib/audio')
local Slots = include('lib/slots')

local cam = { x = 0.0, y = 0.0, zoom = 48.0 }
local TABLE_R = World.TABLE_R
local GRID_STEP = 0.1
local dirty = true
amp_l, amp_r = 0, 0 -- latest master amp poll values (REPL-visible)

local function w2s(wx, wy)
  return 64 + (wx - cam.x) * cam.zoom, 32 + (wy - cam.y) * cam.zoom
end

UI.init({
  world = World,
  cam = cam,
  w2s = w2s,
  mark_dirty = function() dirty = true end,
})

-- REPL test harness: T.add('oscillator', 0.3, 0.1) / T.key(2,1) / T.enc(1,3) ...
T = {
  add = function(type, x, y, a)
    local o = World.add(type, x, y, a); dirty = true; return o.id
  end,
  move = function(id, x, y)
    local o = World.get(id); o.x, o.y = x, y; World.recompute(); dirty = true
  end,
  rot = function(id, a)
    local o = World.get(id); o.angle = a; Audio.sync_object(o); dirty = true
  end,
  clear = function()
    Audio.reset()
    World.objects = {}; World.hardlinks = {}; World.recompute()
    UI.deselect()
    dirty = true
  end,
  remove = function(id) World.remove(id); dirty = true end,
  mute = function(a, b) local m = World.toggle_mute(a, b); dirty = true; return m end,
  key = function(n, z) UI.key(n, z); dirty = true end,
  enc = function(n, d) UI.enc(n, d); dirty = true end,
  dump = function()
    print("level " .. UI.level() .. " | " .. UI.status())
    for _, c in ipairs(World.connections) do
      local b = c.b == "output" and "OUTPUT" or (c.b.type .. "#" .. c.b.id)
      print("CONN " .. c.kind .. (c.muted and " (muted)" or "") ..
        ": " .. c.a.type .. "#" .. c.a.id .. " -> " .. b)
    end
  end,
  dump_str = function()
    return UI.level() .. " | " .. UI.status() .. " | objs=" .. #World.objects
  end,
  pos = function()
    local o = UI.selected()
    return o and string.format("%.3f,%.3f", o.x, o.y) or "none"
  end,
  amps = function()
    return string.format("amp_l=%.5f amp_r=%.5f", amp_l, amp_r)
  end,
  set = function(id, k, v)
    local o = World.get(id)
    if not o then return "no obj" end
    if k == "subtype" then
      o.subtype = util.clamp(math.floor(v), 1, #World.TYPES[o.type].subtypes)
    elseif k == "angle" then
      o.angle = v
    elseif o.params[k] ~= nil then
      o.params[k] = v
    elseif o.env[k] ~= nil then
      o.env[k] = v
    end
    Audio.sync_object(o); dirty = true
  end,
  load = function(id, path)
    engine.loadbuf(id, path)
  end,
  step = function(id, s, on, pitch, vel)
    local o = World.get(id)
    if not o or not o.steps then return end
    local st = o.steps[util.clamp(s, 1, 16)]
    if on ~= nil then st.on = on end
    if pitch ~= nil then st.pitch = util.clamp(pitch, -24, 24) end
    if vel ~= nil then st.vel = util.clamp(vel, 0, 1) end
    dirty = true
  end,
  save_slot = function(i) Slots.save(i) end,
  recall_slot = function(i) local r = Slots.recall(i); dirty = true; return r end,
  del_slot = function(i) Slots.delete(i); dirty = true end,
  state = function()
    -- minimal JSON for tools/api.py (no json lib on stock norns)
    local ob, cb = {}, {}
    for _, o in ipairs(World.objects) do
      table.insert(ob, string.format(
        '{"id":%d,"type":"%s","subtype":%d,"subtype_name":"%s","x":%.3f,"y":%.3f,"angle":%.3f}',
        o.id, o.type, o.subtype, World.subtype_name(o), o.x, o.y, o.angle))
    end
    for _, c in ipairs(World.connections) do
      local b = c.b == "output" and '"output"' or tostring(c.b.id)
      table.insert(cb, string.format(
        '{"a":%d,"b":%s,"kind":"%s","muted":%s}',
        c.a.id, b, c.kind, tostring(c.muted == true)))
    end
    return string.format(
      '{"level":"%s","status":"%s","amp_l":%.5f,"amp_r":%.5f,"objects":[%s],"connections":[%s]}',
      UI.level(), UI.status(), amp_l, amp_r,
      table.concat(ob, ","), table.concat(cb, ","))
  end,
}

function init()
  norns.enc.accel(0, true)
  Audio.init(World)
  Slots.init(World, Audio)

  params:add_number("rot_tempo", "tempo", 40, 240, 120)
  params:set_action("rot_tempo", function(v)
    seq_metro.time = 60 / v / 4 -- 16th notes
  end)

  -- sequencer clock: pentatonic pattern, every other step on
  local seq_step = 0
  seq_metro = metro.init(function()
    seq_step = (seq_step % 16) + 1
    Audio.seq_tick(seq_step)
  end, 60 / 120 / 4, -1)
  seq_metro:start()

  -- stock amp polls for REPL verification of audio flow
  amp_poll_l = poll.set("amp_out_l", function(v) amp_l = v end)
  amp_poll_r = poll.set("amp_out_r", function(v) amp_r = v end)
  amp_poll_l.time = 0.2
  amp_poll_r.time = 0.2
  amp_poll_l:start()
  amp_poll_r:start()

  redraw_metro = metro.init(function()
    if UI.tick() then dirty = true end
    if dirty then redraw() end
  end, 1/15, -1)
  redraw_metro:start()
end

function enc(n, d)
  UI.enc(n, d)
  local o = UI.selected()
  if o then Audio.sync_object(o) end
end

function key(n, z)
  UI.key(n, z)
  local o = UI.selected()
  if o then Audio.sync_object(o) end
end

local function draw_grid()
  screen.level(2)
  local x0 = cam.x - 70 / cam.zoom
  local x1 = cam.x + 70 / cam.zoom
  local y0 = cam.y - 40 / cam.zoom
  local y1 = cam.y + 40 / cam.zoom
  local gx = math.floor(x0 / GRID_STEP) * GRID_STEP
  while gx <= x1 do
    local gy = math.floor(y0 / GRID_STEP) * GRID_STEP
    while gy <= y1 do
      if gx * gx + gy * gy <= TABLE_R * TABLE_R then
        local sx, sy = w2s(gx, gy)
        screen.pixel(math.floor(sx + 0.5), math.floor(sy + 0.5))
      end
      gy = gy + GRID_STEP
    end
    gx = gx + GRID_STEP
  end
  screen.fill()
end

local function draw_table()
  local cx, cy = w2s(0, 0)
  screen.level(9)
  screen.circle(cx, cy, TABLE_R * cam.zoom)
  screen.stroke()
end

local function draw_output()
  local cx, cy = w2s(0, 0)
  screen.level(15)
  screen.circle(cx, cy, util.clamp(0.03 * cam.zoom, 2, 5))
  screen.fill()
end

local function draw_objects()
  Render.connections(cam, w2s, World)
  local sel = UI.selected()
  Render.begin_labels()
  for _, o in ipairs(World.objects) do
    Render.object(cam, w2s, o, World.TYPES, sel ~= nil and o.id == sel.id)
  end
  -- LINK candidate ring
  local cand = UI.link_candidate()
  if cand then
    local sx, sy = w2s(cand.x, cand.y)
    screen.level(15)
    screen.circle(sx, sy, 10)
    screen.stroke()
  end
  Render.flush_labels()
end

local function draw_reticle()
  screen.level(12)
  screen.move(60, 32) screen.line(56, 32)
  screen.move(68, 32) screen.line(72, 32)
  screen.move(64, 28) screen.line(64, 24)
  screen.move(64, 36) screen.line(64, 40)
  screen.stroke()
end

local function draw_status()
  screen.level(6)
  screen.move(2, 62)
  screen.text(UI.status())
end

function redraw()
  screen.clear()
  draw_grid()
  draw_table()
  Slots.draw(w2s, cam, UI.slot_candidate())
  draw_objects()
  draw_output()
  draw_reticle()
  UI.draw_overlay()
  if not UI.overlay_open() then draw_status() end
  screen.update()
  dirty = false
end
