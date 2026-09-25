-- ui.lua — interaction hierarchy: L0 place menu / L1 navigate / L2 object / L3 config
-- K1 = shift (held; tap = norns system menu), K2 = back, K3 = action
-- (docs/interaction-design.md v3, key remap approved 2026-09-25)

local UI = {}
local Audio = include('lib/audio')
local Slots = include('lib/slots')

local World, cam, w2s, mark_dirty

local SELECT_SCREEN_R = 25 -- px; how near the reticle an object must be to select

-- state
local level = "L1"          -- L1 | L0 | L2 | L3
local mode = "MOVE"         -- L2 modes: MOVE | ROTATE | LINK
local modes = { "MOVE", "ROTATE", "LINK" }
local selected = nil        -- object ref (L2/L3)
local menu_idx = 1          -- L0 cursor (over selectable items)
local link_idx = 1          -- LINK target candidate index
local link_candidates = {}
local page_idx = 1          -- L3 page
local field_idx = 1         -- L3 field within page
local step_idx = 1          -- L3 steps page: selected step 1..16
local browser = { files = nil, idx = 1 } -- L3 browser page (lazy scan)
local k1_down = false
local clear_armed = false   -- K1+K2 at L1 arms table-clear; K3 confirms, K2 cancels
local k3_slot_press = nil   -- util.time() of K3 press when armed on a slot
local slot_cand = nil       -- slot index near reticle at L1 (nil = none)
local SLOT_LONG = 0.8       -- s; long-press threshold for slot store/delete

function UI.init(ctx)
  World, cam, w2s, mark_dirty = ctx.world, ctx.cam, ctx.w2s, ctx.mark_dirty
end

function UI.level() return level end
function UI.selected() return selected end

local function dirty() mark_dirty() end

-- ---------- helpers ----------

local function nearest_to_reticle()
  local best, best_d = nil, SELECT_SCREEN_R
  for _, o in ipairs(World.objects) do
    local sx, sy = w2s(o.x, o.y)
    local d = math.sqrt((sx - 64) ^ 2 + (sy - 32) ^ 2)
    if d < best_d then best, best_d = o, d end
  end
  return best
end

-- patch slot near the reticle (objects win: caller checks objects first)
local function nearest_slot()
  local best, best_d = nil, SELECT_SCREEN_R
  for i = 1, Slots.N do
    local wx, wy = Slots.pos(i)
    local sx, sy = w2s(wx, wy)
    local d = math.sqrt((sx - 64) ^ 2 + (sy - 32) ^ 2)
    if d < best_d then best, best_d = i, d end
  end
  return best
end

local function menu_selectables()
  local list = {}
  for _, item in ipairs(World.MENU) do
    if type(item) == "string" then table.insert(list, item) end
  end
  return list
end

local function rebuild_link_candidates()
  link_candidates = {}
  if not selected then return end
  for _, o in ipairs(World.objects) do
    if o.id ~= selected.id then
      local d = math.sqrt((o.x - selected.x) ^ 2 + (o.y - selected.y) ^ 2)
      table.insert(link_candidates, { obj = o, d = d })
    end
  end
  table.sort(link_candidates, function(a, b) return a.d < b.d end)
  link_idx = 1
end

-- L3 pages per object: envelope always; 2d for two-param effects;
-- steps editor for sequencer; sample browser for loop
local function pages_for(o)
  local p = { "env" }
  local c = World.TYPES[o.type].category
  if c == "effect" then table.insert(p, 1, "2d") end
  if o.type == "sequencer" then table.insert(p, 1, "steps") end
  if o.type == "loop" then table.insert(p, 1, "browser") end
  return p
end

-- recursive WAV scan of dust/audio (depth-capped, count-capped)
local function scan_audio_files()
  local out = {}
  local function walk(dir, rel, depth)
    if depth > 3 or #out >= 256 then return end
    local ok, entries = pcall(util.scandir, dir)
    if not ok or not entries then return end
    for _, name in ipairs(entries) do
      if #out >= 256 then return end
      if name:sub(1, 1) ~= "." then
        local full = dir .. "/" .. name
        local r = rel == "" and name or (rel .. "/" .. name)
        if name:lower():match("%.wav$") then
          table.insert(out, r)
        else
          walk(full, r, depth + 1) -- non-wav: maybe a directory
        end
      end
    end
  end
  walk(_path.audio, "", 1)
  table.sort(out)
  return out
end

local ENV_FIELDS = { "a", "d", "s", "r" }

local function params_2d(o)
  -- X, Y param keys for the 2d page, mirroring the original panels
  if o.type == "filter" then return "cutoff", "res"
  elseif o.type == "delay" then return "time", "feedback"
  else return "main", "drywet" end
end

-- ---------- input ----------

local function enter_l2(o)
  selected = o
  level = "L2"
  mode = "MOVE"
  rebuild_link_candidates()
end

-- E1 in MOVE mode: hop selection to the next/previous object (by id),
-- centering the camera on it (owner feature 2026-09-25)
local function cycle_selected(d)
  local n = #World.objects
  if n == 0 then return end
  local i = 0
  for j, o in ipairs(World.objects) do
    if selected and o.id == selected.id then i = j end
  end
  selected = World.objects[((i - 1 + d) % n) + 1]
  cam.x, cam.y = selected.x, selected.y
  rebuild_link_candidates()
end

local function cycle_mode(dir)
  local i = 1
  for j, m in ipairs(modes) do if m == mode then i = j end end
  mode = modes[((i - 1 + (dir or 1)) % #modes) + 1]
  if mode == "LINK" then rebuild_link_candidates() end
end

function UI.enc(n, d)
  if level == "L1" then
    if n == 1 then
      cam.zoom = util.clamp(cam.zoom * (1 + d * 0.04), 8, 480)
    elseif n == 2 then
      cam.x = cam.x + d * 0.01 * (48 / cam.zoom)
    elseif n == 3 then
      cam.y = cam.y + d * 0.01 * (48 / cam.zoom)
    end
  elseif level == "L0" then
    local items = menu_selectables()
    if n == 2 then
      menu_idx = util.clamp(menu_idx + d, 1, #items)
    end
  elseif level == "L2" and selected then
    local step = 0.01 * (48 / cam.zoom)
    if mode == "MOVE" then
      if n == 1 then cycle_selected(d > 0 and 1 or -1)
      elseif n == 2 then selected.x = selected.x + d * step
      elseif n == 3 then selected.y = selected.y + d * step end
      World.recompute()
    elseif mode == "ROTATE" then
      if k1_down then
        if n == 2 then World.cycle_subtype(selected, d > 0 and 1 or -1) end
      else
        if n == 2 then
          selected.angle = (selected.angle + d * 0.05) % (2 * math.pi)
        elseif n == 3 then
          -- right-dot parameter: amp for generators, second param otherwise
          local key = World.TYPES[selected.type].category == "generator" and "amp" or select(2, params_2d(selected))
          if selected.params[key] ~= nil then
            selected.params[key] = util.clamp((selected.params[key] or 0) + d * 0.02, 0, 1)
          end
        end
      end
    elseif mode == "LINK" then
      if n == 2 and #link_candidates > 0 then
        link_idx = ((link_idx - 1 + d) % #link_candidates) + 1
      end
    end
  elseif level == "L3" and selected then
    local pages = pages_for(selected)
    local page = pages[page_idx]
    if n == 1 then
      page_idx = 1 + (page_idx % #pages)
      field_idx = 1
    elseif page == "2d" then
      local kx, ky = params_2d(selected)
      if n == 2 then selected.params[kx] = util.clamp(selected.params[kx] + d * 0.02, 0, 1)
      elseif n == 3 then selected.params[ky] = util.clamp(selected.params[ky] + d * 0.02, 0, 1) end
    elseif page == "steps" then
      if n == 2 then
        step_idx = util.clamp(step_idx + d, 1, 16)
      elseif n == 3 then
        local st = selected.steps[step_idx]
        if k1_down then
          st.vel = util.clamp(st.vel + d * 0.02, 0, 1)
        else
          st.pitch = util.clamp(st.pitch + d, -12, 12)
        end
      end
    elseif page == "browser" then
      if n == 2 and #browser.files > 0 then
        browser.idx = util.clamp(browser.idx + d, 1, #browser.files)
      end
    else -- env
      if n == 2 then field_idx = util.clamp(field_idx + d, 1, #ENV_FIELDS)
      elseif n == 3 then
        local f = ENV_FIELDS[field_idx]
        selected.env[f] = util.clamp(selected.env[f] + d * 0.02, 0, 4)
      end
    end
  end
  dirty()
end

function UI.key(n, z)
  if n == 1 then
    -- K1 = held shift only; its short tap belongs to the norns system menu
    k1_down = (z == 1)
  elseif n == 2 and z == 1 then
    -- K2 = BACK (K1+K2 = delete at current scope: object in L2, table at L1)
    if clear_armed then
      clear_armed = false -- cancel
    elseif k1_down and level == "L2" and selected then
      World.remove(selected.id)
      selected = nil
      level = "L1"
    elseif k1_down and level == "L1" and #World.objects > 0 then
      clear_armed = true
    elseif level == "L3" then level = "L2"
    elseif level == "L2" then level = "L1"; selected = nil
    elseif level == "L0" then level = "L1"
    end
  elseif n == 3 then
    -- K3 = ACTION (K1+K3 = shifted action). At L1 with a patch slot under
    -- the reticle, K3 becomes a press/release gesture: short = recall,
    -- long = store (empty slot) or delete (occupied slot).
    if z == 1 then
      if clear_armed then
        -- confirm table clear
        Audio.reset()
        World.objects = {}
        World.hardlinks = {}
        World.recompute()
        clear_armed = false
      elseif k1_down then
        if level == "L1" then
          level = "L0"; menu_idx = 1
        elseif level == "L2" and selected then
          if mode == "LINK" and link_candidates[link_idx] then
            World.toggle_mute(selected.id, link_candidates[link_idx].obj.id)
          else
            level = "L3"; page_idx = 1; field_idx = 1; step_idx = 1
            browser.files = nil; browser.idx = 1
          end
        end
      else
        if level == "L1" then
          if nearest_to_reticle() == nil then
            slot_cand = nearest_slot()
            if slot_cand then
              k3_slot_press = util.time()
            else
              local o = nearest_to_reticle()
              if o then enter_l2(o) end
            end
          else
            enter_l2(nearest_to_reticle())
          end
        elseif level == "L0" then
          local items = menu_selectables()
          local o = World.add(items[menu_idx], cam.x, cam.y, 0)
          enter_l2(o) -- placed at reticle, auto-selected in MOVE
        elseif level == "L2" then
          if mode == "LINK" and link_candidates[link_idx] then
            World.toggle_hardlink(selected.id, link_candidates[link_idx].obj.id)
          else
            cycle_mode(1)
          end
        elseif level == "L3" and selected then
          local page = pages_for(selected)[page_idx]
          if page == "steps" then
            local st = selected.steps[step_idx]
            st.on = not st.on
          elseif page == "browser" then
            if browser.files == nil then browser.files = scan_audio_files() end
            local f = browser.files[browser.idx]
            if f then Audio.load_sample(selected, _path.audio .. f) end
          end
        end
      end
    else -- z == 0, release
      if k3_slot_press and slot_cand and level == "L1" then
        local held = util.time() - k3_slot_press
        if held >= SLOT_LONG then
          if Slots.occupied(slot_cand) then Slots.delete(slot_cand)
          else Slots.save(slot_cand) end
        else
          if Slots.occupied(slot_cand) then Slots.recall(slot_cand) end
        end
      end
      k3_slot_press = nil
      slot_cand = nil
    end
  end
  dirty()
end

-- ---------- drawing ----------

local function draw_menu()
  screen.level(0)
  screen.rect(14, 2, 100, 60)
  screen.fill()
  screen.level(8)
  screen.rect(14, 2, 100, 60)
  screen.stroke()
  -- flat row list with selectable indices, windowed around the cursor
  local rows = {}
  local sel_row = 1
  for _, item in ipairs(World.MENU) do
    if type(item) == "table" then
      table.insert(rows, { header = item.header })
    else
      table.insert(rows, { type = item })
    end
  end
  local si = 0
  for i, row in ipairs(rows) do
    if row.type then
      si = si + 1
      if si == menu_idx then sel_row = i end
    end
  end
  local max_rows = 7
  local first = util.clamp(sel_row - 3, 1, math.max(1, #rows - max_rows + 1))
  local y = 10
  si = 0
  for i = first, math.min(#rows, first + max_rows - 1) do
    local row = rows[i]
    if row.header then
      screen.level(3)
      screen.move(18, y)
      screen.text(row.header)
    else
      si = 0
      for j = 1, i do if rows[j].type then si = si + 1 end end
      local t = World.TYPES[row.type]
      if si == menu_idx then
        screen.level(15)
        screen.rect(16, y - 5, 96, 7)
        screen.fill()
        screen.level(0)
      else
        screen.level(10)
      end
      screen.move(20, y)
      screen.text(t.label .. "  " .. row.type)
    end
    y = y + 7
  end
end

local function draw_l3()
  local pages = pages_for(selected)
  local page = pages[page_idx]
  screen.level(0)
  screen.rect(8, 2, 112, 60)
  screen.fill()
  screen.level(8)
  screen.rect(8, 2, 112, 60)
  screen.stroke()
  screen.level(12)
  screen.move(12, 10)
  screen.text(World.TYPES[selected.type].label .. "#" .. selected.id ..
    " " .. World.subtype_name(selected) .. "  [" .. page .. " " .. page_idx .. "/" .. #pages .. "]")
  if page == "env" then
    for i, f in ipairs(ENV_FIELDS) do
      local x = 20 + (i - 1) * 26
      local v = selected.env[f]
      local h = util.clamp(v / 4, 0, 1) * 38
      screen.level(i == field_idx and 15 or 6)
      screen.rect(x, 52 - h, 8, h)
      screen.stroke()
      screen.move(x, 60)
      screen.text(f)
    end
  elseif page == "steps" then
    -- 16 steps: bar height = pitch (-12..+12 around midline), brightness = vel
    local x0, mid = 14, 36
    screen.level(3)
    screen.move(x0, mid) screen.line(118, mid)
    screen.stroke()
    for i = 1, 16 do
      local st = selected.steps[i]
      local x = x0 + (i - 1) * 7
      local h = util.clamp(st.pitch, -12, 12) / 12 * 16
      local lvl = st.on and (2 + math.floor(st.vel * 12)) or 2
      if i == step_idx then lvl = 15 end
      screen.level(lvl)
      if st.on then
        screen.move(x, mid)
        screen.line(x, mid - h)
        screen.stroke()
        if i == step_idx then
          screen.pixel(x - 1, mid - h) screen.pixel(x + 1, mid - h)
          screen.fill()
        end
      else
        screen.pixel(x, mid)
        screen.fill()
      end
    end
    local st = selected.steps[step_idx]
    screen.level(6)
    screen.move(12, 60)
    screen.text(string.format("st%d %s %+d vel %.2f", step_idx,
      st.on and "ON" or "off", st.pitch, st.vel))
  elseif page == "browser" then
    if browser.files == nil then browser.files = scan_audio_files() end
    local n = #browser.files
    if n == 0 then
      screen.level(6)
      screen.move(12, 34)
      screen.text("no wavs in dust/audio")
    else
      local first = util.clamp(browser.idx - 2, 1, math.max(1, n - 5))
      for i = first, math.min(n, first + 5) do
        local y = 18 + (i - first) * 7
        local name = browser.files[i]
        local full = _path.audio .. name
        local loaded = selected.sample == full
        if #name > 20 then name = ".." .. name:sub(-18) end
        if loaded then name = "> " .. name end
        if i == browser.idx then
          screen.level(15)
          screen.rect(10, y - 5, 106, 7)
          screen.fill()
          screen.level(0)
        else
          screen.level(loaded and 12 or 8)
        end
        screen.move(12, y)
        screen.text(name)
      end
    end
  else -- 2d
    local kx, ky = params_2d(selected)
    local px = 16 + util.clamp(selected.params[kx], 0, 1) * 90
    local py = 54 - util.clamp(selected.params[ky], 0, 1) * 38
    screen.level(4)
    screen.rect(16, 16, 90, 38)
    screen.stroke()
    screen.level(15)
    screen.move(px - 3, py) screen.line(px + 3, py)
    screen.move(px, py - 3) screen.line(px, py + 3)
    screen.stroke()
    screen.level(6)
    screen.move(16, 62)
    screen.text(kx .. " " .. string.format("%.2f", selected.params[kx]) ..
      "  " .. ky .. " " .. string.format("%.2f", selected.params[ky]))
  end
end

function UI.draw_overlay()
  if level == "L0" then draw_menu()
  elseif level == "L3" and selected then draw_l3() end
end

function UI.overlay_open()
  return level == "L0" or (level == "L3" and selected ~= nil)
end

function UI.link_candidate()
  if level == "L2" and mode == "LINK" then
    local c = link_candidates[link_idx]
    return c and c.obj or nil
  end
end

function UI.slot_candidate()
  if level == "L1" and nearest_to_reticle() == nil then
    return nearest_slot()
  end
end

function UI.status()
  if clear_armed then
    return "CLEAR TABLE?  K3 yes  K2 no"
  end
  if level == "L1" then
    return "NAV  E1 zoom E2 x E3 y | K3 sel ^K3 place"
  elseif level == "L0" then
    return "PLACE  E2 scroll | K3 place K2 back"
  elseif level == "L2" and selected then
    local extra = ""
    if mode == "ROTATE" then
      extra = "  " .. World.subtype_name(selected)
    elseif mode == "LINK" and link_candidates[link_idx] then
      local t = link_candidates[link_idx].obj
      extra = " -> " .. World.TYPES[t.type].label .. "#" .. t.id ..
        (World.is_hardlinked(selected.id, t.id) and " [HARD]" or "")
    end
    local act = mode == "LINK" and "hard" or "mode"
    local sact = mode == "LINK" and "mute" or "cfg"
    local e1 = mode == "MOVE" and " E1 hop" or ""
    return mode .. " " .. World.TYPES[selected.type].label .. "#" .. selected.id ..
      extra .. " |" .. e1 .. " K3 " .. act .. " ^K3 " .. sact .. " K2 back"
  elseif level == "L3" and selected then
    return "CONFIG  E1 page E2/E3 edit | K2 back"
  end
  return ""
end

return UI
