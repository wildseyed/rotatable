-- render.lua — vector drawing for the table world
-- glyphs scale with zoom; everything drawn via cam transform w2s()

local Render = {}

local GLYPH_R = 0.08 -- world units, base object radius

-- polygon helper: n-gon centered at sx,sy, radius r, rotated by rot
local function poly(sx, sy, r, n, rot)
  for i = 0, n do
    local a = rot + i * 2 * math.pi / n
    local x, y = sx + r * math.cos(a), sy + r * math.sin(a)
    if i == 0 then screen.move(x, y) else screen.line(x, y) end
  end
  screen.stroke()
end

local function draw_square(sx, sy, r, rounded)
  if rounded then
    poly(sx, sy, r, 8, math.pi / 8) -- octagon approximates rounded square
  else
    poly(sx, sy, r, 4, math.pi / 4)
  end
end

local function draw_star(sx, sy, r)
  for i = 0, 10 do
    local a = -math.pi / 2 + i * math.pi / 5
    local rr = (i % 2 == 0) and r or r * 0.45
    local x, y = sx + rr * math.cos(a), sy + rr * math.sin(a)
    if i == 0 then screen.move(x, y) else screen.line(x, y) end
  end
  screen.stroke()
end

-- subtype pictograms (reactable-style): a small mark on the player-facing
-- rim of the glyph, orbiting with rotation. s = mark radius in px.
local function mline(pts)
  screen.move(pts[1], pts[2])
  for i = 3, #pts, 2 do screen.line(pts[i], pts[i + 1]) end
  screen.stroke()
end

local function mdot(x, y)
  screen.circle(x, y, 1)
  screen.fill()
end

local function sub_mark(o, px, py, s)
  local t, sub = o.type, o.subtype
  if t == "oscillator" or t == "lfo" then
    if sub == 1 then -- sine
      mline({ px - s, py, px - s * 0.4, py - s * 0.7, px + s * 0.4, py + s * 0.7, px + s, py })
    elseif sub == 2 then -- saw
      mline({ px - s, py + s * 0.6, px + s * 0.5, py - s * 0.6, px + s * 0.5, py + s * 0.6 })
    elseif sub == 3 then -- square
      screen.rect(px - s * 0.6, py - s * 0.6, s * 1.2, s * 1.2)
      screen.stroke()
    else -- noise / random
      mdot(px - s * 0.6, py - s * 0.3) mdot(px, py + s * 0.4) mdot(px + s * 0.6, py - s * 0.5)
    end
  elseif t == "loop" then
    if sub == 1 then -- loop: ring
      screen.circle(px, py, s * 0.6)
      screen.stroke()
    else -- oneshot: play triangle
      mline({ px - s * 0.5, py - s * 0.6, px + s * 0.6, py, px - s * 0.5, py + s * 0.6, px - s * 0.5, py - s * 0.6 })
    end
  elseif t == "sampler" then
    if sub == 1 then -- instrument: note
      mdot(px - s * 0.3, py + s * 0.4)
      mline({ px - s * 0.3 + 1, py + s * 0.4, px - s * 0.3 + 1, py - s * 0.6 })
    else -- drum: X
      mline({ px - s * 0.5, py - s * 0.5, px + s * 0.5, py + s * 0.5 })
      mline({ px - s * 0.5, py + s * 0.5, px + s * 0.5, py - s * 0.5 })
    end
  elseif t == "filter" then -- classic slope pictograms
    if sub == 1 then -- lp
      mline({ px - s, py - s * 0.4, px, py - s * 0.4, px + s, py + s * 0.5 })
    elseif sub == 2 then -- bp
      mline({ px - s, py + s * 0.5, px, py - s * 0.5, px + s, py + s * 0.5 })
    else -- hp
      mline({ px - s, py + s * 0.5, px, py - s * 0.4, px + s, py - s * 0.4 })
    end
  elseif t == "delay" then
    if sub == 1 then -- feedback: near-full arc
      screen.arc(px, py, s * 0.6, 0.4, 5.9)
      screen.stroke()
    elseif sub == 2 then -- pingpong: two dots
      mdot(px - s * 0.5, py) mdot(px + s * 0.5, py)
    else -- reverb: concentric arcs
      screen.arc(px, py, s * 0.35, 0.4, 5.9)
      screen.arc(px, py, s * 0.7, 0.4, 5.9)
      screen.stroke()
    end
  elseif t == "modulator" then
    if sub == 1 then -- ring: circle + center dot
      screen.circle(px, py, s * 0.55)
      screen.stroke()
      mdot(px, py)
    elseif sub == 2 then -- chorus: twin arcs
      screen.arc(px - s * 0.3, py, s * 0.45, 0.4, 5.9)
      screen.arc(px + s * 0.3, py, s * 0.45, 0.4, 5.9)
      screen.stroke()
    else -- flanger: X
      mline({ px - s * 0.5, py - s * 0.5, px + s * 0.5, py + s * 0.5 })
      mline({ px - s * 0.5, py + s * 0.5, px + s * 0.5, py - s * 0.5 })
    end
  elseif t == "waveshaper" then
    if sub == 1 then -- resampler: staircase
      mline({ px - s, py + s * 0.5, px - s * 0.3, py + s * 0.5, px - s * 0.3, py,
        px + s * 0.3, py, px + s * 0.3, py - s * 0.5, px + s, py - s * 0.5 })
    elseif sub == 2 then -- compressor: ><
      mline({ px - s * 0.6, py - s * 0.5, px, py, px - s * 0.6, py + s * 0.5 })
      mline({ px + s * 0.6, py - s * 0.5, px, py, px + s * 0.6, py + s * 0.5 })
    else -- distortion: jagged
      mline({ px - s, py + s * 0.5, px - s * 0.3, py - s * 0.5, px + s * 0.3, py + s * 0.5, px + s, py - s * 0.5 })
    end
  elseif t == "sequencer" then
    if sub == 1 then -- mono: 3 dots in a row
      mdot(px - s * 0.6, py) mdot(px, py) mdot(px + s * 0.6, py)
    elseif sub == 2 then -- poly: dot grid
      mdot(px - s * 0.4, py - s * 0.4) mdot(px + s * 0.4, py - s * 0.4)
      mdot(px - s * 0.4, py + s * 0.4) mdot(px + s * 0.4, py + s * 0.4)
    else -- random: scatter
      mdot(px - s * 0.5, py + s * 0.3) mdot(px + s * 0.1, py - s * 0.5) mdot(px + s * 0.5, py + s * 0.2)
    end
  end
  -- input/tonality/output: single or non-iconic subtypes, no mark
end

-- label de-collision: labels queue up during the frame, then draw selected
-- first and skip any that would overlap an already-drawn label
local label_queue = nil

function Render.begin_labels()
  label_queue = {}
end

function Render.flush_labels()
  if not label_queue then return end
  table.sort(label_queue, function(a, b)
    return (a.sel and 1 or 0) > (b.sel and 1 or 0)
  end)
  local boxes = {}
  screen.level(4)
  for _, l in ipairs(label_queue) do
    local w = screen.text_extents(l.text)
    local x0, x1 = l.x - w / 2 - 1, l.x + w / 2 + 1
    local y0, y1 = l.y - 7, l.y + 1
    local hit = false
    for _, b in ipairs(boxes) do
      if x0 < b[3] and x1 > b[1] and y0 < b[4] and y1 > b[2] then
        hit = true
        break
      end
    end
    if l.sel or not hit then
      screen.move(l.x, l.y)
      screen.text_center(l.text)
      boxes[#boxes + 1] = { x0, y0, x1, y1 }
    end
  end
  label_queue = nil
end

-- connection lines: audio = solid, control = dotted (hand-drawn dots)
-- muted = dim, hardlink = bright double line
local function draw_connection(cam, w2s, world, conn)
  local ax, ay = w2s(conn.a.x, conn.a.y)
  local bx, by
  if conn.b == "output" then
    bx, by = w2s(0, 0)
  else
    bx, by = w2s(conn.b.x, conn.b.y)
  end
  local hard = conn.b ~= "output" and world.is_hardlinked(conn.a.id, conn.b.id)
  local lvl = conn.muted and 2 or (hard and 15 or (conn.kind == "audio" and 7 or 5))
  if conn.kind == "audio" then
    screen.level(lvl)
    screen.move(ax, ay)
    screen.line(bx, by)
    screen.stroke()
    if hard then
      local dx, dy = by - ay, -(bx - ax)
      local len = math.sqrt(dx * dx + dy * dy)
      if len > 0 then
        dx, dy = dx / len * 1.5, dy / len * 1.5
        screen.move(ax + dx, ay + dy)
        screen.line(bx + dx, by + dy)
        screen.move(ax - dx, ay - dy)
        screen.line(bx - dx, by - dy)
        screen.stroke()
      end
    end
  else
    screen.level(lvl)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    local n = math.max(2, math.floor(len / 4))
    for i = 0, n do
      local t = i / n
      screen.pixel(math.floor(ax + dx * t + 0.5), math.floor(ay + dy * t + 0.5))
    end
    screen.fill()
  end
end

function Render.object(cam, w2s, o, types, selected)
  local sx, sy = w2s(o.x, o.y)
  local r = util.clamp(GLYPH_R * cam.zoom, 3, 14)
  -- skip (and skip label) when fully offscreen
  if sx < -20 or sx > 148 or sy < -20 or sy > 84 then return end
  local cat = types[o.type].category
  screen.level(selected and 15 or 10)
  if cat == "generator" then
    draw_square(sx, sy, r, false)
  elseif cat == "effect" then
    draw_square(sx, sy, r, true)
  elseif cat == "controller" then
    screen.circle(sx, sy, r)
    screen.stroke()
  elseif cat == "global" then
    draw_star(sx, sy, r * 1.15)
  end
  -- rotation tick (center stub; the subtype pictogram completes the radius)
  screen.level(selected and 15 or 6)
  screen.move(sx, sy)
  screen.line(sx + 0.35 * r * math.cos(o.angle), sy + 0.35 * r * math.sin(o.angle))
  screen.stroke()
  -- subtype pictogram on the player-facing rim (orbits with rotation)
  if r >= 3.5 then
    local s = util.clamp(r * 0.38, 1.5, 6)
    screen.level(selected and 15 or 9)
    sub_mark(o, sx + 0.68 * r * math.cos(o.angle), sy + 0.68 * r * math.sin(o.angle), s)
  end
  -- label queues up (collision-resolved at flush) when zoomed in enough to read
  if cam.zoom >= 30 and label_queue then
    local text = types[o.type].label
    if selected then
      text = text .. " " .. (types[o.type].subtypes[o.subtype] or "")
    end
    label_queue[#label_queue + 1] = { x = sx, y = sy + r + 6, text = text, sel = selected }
  end
end

function Render.connections(cam, w2s, world)
  for _, conn in ipairs(world.connections) do
    draw_connection(cam, w2s, world, conn)
  end
end

return Render
