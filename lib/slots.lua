-- slots.lua — patch slots: store/recall/delete patches outside the table edge
-- (plan/phase-5/patch-slots.md, owner feature 2026-09-25)

local Slots = {}

Slots.N = 8
Slots.RADIUS = 1.18 -- world units, ring just outside the table (r=1.0)

local DIR = _path.data .. "rotatable/slots/"

local World, Audio

function Slots.init(world, audio)
  World, Audio = world, audio
  util.make_dir(DIR)
end

-- world position of slot i (1..N); slot 1 at top, clockwise
function Slots.pos(i)
  local a = -math.pi / 2 + (i - 1) * 2 * math.pi / Slots.N
  return Slots.RADIUS * math.cos(a), Slots.RADIUS * math.sin(a)
end

function Slots.path(i)
  return DIR .. i .. ".lua"
end

function Slots.occupied(i)
  return util.file_exists(Slots.path(i))
end

-- ---------- serialize ----------

local function gather()
  local objs, idx_of = {}, {}
  for _, o in ipairs(World.objects) do
    idx_of[o.id] = #objs + 1
    local e = {
      type = o.type, subtype = o.subtype,
      x = o.x, y = o.y, angle = o.angle,
      params = {}, env = { a = o.env.a, d = o.env.d, s = o.env.s, r = o.env.r },
      sample = o.sample, steps = o.steps,
    }
    for k, v in pairs(o.params) do e.params[k] = v end
    table.insert(objs, e)
  end
  local links = {}
  for k in pairs(World.hardlinks) do
    local a, b = k:match("(%d+):(%d+)")
    a, b = idx_of[tonumber(a)], idx_of[tonumber(b)]
    if a and b then table.insert(links, { a, b }) end
  end
  local mutes = {}
  for _, c in ipairs(World.connections) do
    if c.muted then
      table.insert(mutes, {
        a = idx_of[c.a.id],
        b = c.b == "output" and "output" or idx_of[c.b.id],
      })
    end
  end
  return { objects = objs, hardlinks = links, mutes = mutes,
    tempo = params:get("rot_tempo") }
end

function Slots.save(i)
  tab.save(gather(), Slots.path(i))
end

function Slots.delete(i)
  if Slots.occupied(i) then os.remove(Slots.path(i)) end
end

function Slots.recall(i)
  local data = tab.load(Slots.path(i))
  if not data then return false end
  Audio.reset()
  World.objects = {}
  World.hardlinks = {}
  local new_ids = {}
  for _, e in ipairs(data.objects) do
    local o = World.add(e.type, e.x, e.y, e.angle)
    o.subtype = e.subtype
    for k, v in pairs(e.params) do o.params[k] = v end
    o.env = { a = e.env.a, d = e.env.d, s = e.env.s, r = e.env.r }
    if e.steps then o.steps = e.steps end
    if e.sample then Audio.load_sample(o, e.sample) end
    Audio.sync_object(o)
    table.insert(new_ids, o.id)
  end
  for _, l in ipairs(data.hardlinks or {}) do
    if new_ids[l[1]] and new_ids[l[2]] then
      World.hardlinks[World.link_key(new_ids[l[1]], new_ids[l[2]])] = true
    end
  end
  World.recompute()
  -- restore mutes by matching recomputed connections
  for _, m in ipairs(data.mutes or {}) do
    local a_id, b_id = new_ids[m.a], m.b ~= "output" and new_ids[m.b] or nil
    if a_id and b_id then World.toggle_mute(a_id, b_id) end
  end
  if data.tempo then params:set("rot_tempo", data.tempo) end
  return true
end

-- ---------- render ----------

function Slots.draw(w2s, cam, candidate)
  for i = 1, Slots.N do
    local wx, wy = Slots.pos(i)
    local sx, sy = w2s(wx, wy)
    if sx > -10 and sx < 138 and sy > -10 and sy < 74 then
      local occ = Slots.occupied(i)
      local r = 4
      local lvl = occ and 10 or 3
      if candidate == i then lvl = 15 end
      screen.level(lvl)
      screen.rect(sx - r, sy - r, r * 2, r * 2)
      screen.stroke()
      if occ then
        screen.pixel(sx, sy)
        screen.fill()
      end
      if cam.zoom >= 24 then
        screen.level(candidate == i and 15 or (occ and 8 or 2))
        screen.move(sx, sy + r + 5)
        screen.text_center(i)
      end
    end
  end
end

return Slots
