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
local k2_down = false
local k3_down = false
local clear_armed = false   -- K1+K2 at L1 arms table-clear; K3 confirms, K2 cancels
local k3_slot_press = nil   -- util.time() of K3 press when armed on a slot
local slot_cand = nil       -- slot index near reticle at L1 (nil = none)
local SLOT_LONG = 0.8       -- s; long-press threshold for slot store/delete
-- SYSTEM master menu: hold K1+K2+K3 for MASTER_LONG seconds (owner, 2026-09-27)
local master_t = nil        -- util.time() when the third key came down
local MASTER_LONG = 1.0
local sys_idx = 1
local sys_confirm = nil     -- "restore" while the restore confirm is showing
local sys_msg = nil         -- transient bottom-line message
local SYS_ITEMS = { "RESTORE PRESETS", "ABOUT" }

function UI.init(ctx)
  World, cam, w2s, mark_dirty = ctx.world, ctx.cam, ctx.w2s, ctx.mark_dirty
  -- audio/slots are singletons (global-guarded against per-includer
  -- include() copies); re-init with the same wiring is harmless
  Slots.init(World, Audio)
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

-- L3 "set" page (phase 8 batch 1): one shared pattern for tempo-sync and
-- pitch settings. Fields per type: lfo sync+mult, delay sync+sweep,
-- loop sync, sampler base pitch.
local SET_FIELDS = {
  lfo = {
    { k = "sync", min = 0, max = 1, step = 1 },
    { k = "mult", min = 1, max = 128, step = 1 },
  },
  delay = {
    { k = "sync", min = 0, max = 1, step = 1 },
    { k = "sweep", min = 0.01, max = 2, step = 0.02 },
  },
  loop = {
    { k = "sync", min = 0, max = 2, step = 1 }, -- 0 immediate, 1 quarter, 2 bar
  },
  sampler = {
    { k = "base", min = -48, max = 48, step = 1 }, -- semitones from C4
  },
  output = { -- global FX (spec §3.13): master reverb + compression
    { k = "rev", min = 0, max = 1, step = 0.02 },
    { k = "room", min = 0, max = 1, step = 0.02 },
    { k = "comp", min = 0, max = 1, step = 0.02 },
  },
}

local C4 = 261.6256 -- sampler base reference pitch (params.base is in Hz)
local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local function base_semis(o)
  return math.floor(12 * math.log((o.params.base or C4) / C4) / math.log(2) + 0.5)
end

local function set_field_str(o, f)
  local v = o.params[f.k]
  if f.k == "sync" then
    if o.type == "loop" then
      return ({ "immed", "quarter", "bar" })[util.clamp(math.floor(v + 0.5), 0, 2) + 1]
    end
    return v >= 0.5 and "on" or "off"
  elseif f.k == "mult" then
    return string.format("%d 32nds", math.floor(v + 0.5))
  elseif f.k == "sweep" then
    return string.format("%.2f s", v)
  elseif f.k == "base" then
    local st = base_semis(o)
    return string.format("%s%d (%d Hz)",
      NOTE_NAMES[(st % 12) + 1], 4 + math.floor(st / 12), math.floor(v + 0.5))
  end
  return tostring(v)
end

-- sub-oscillator page (oscillator): follow toggle + 4 subs x 4 fields
local SUB_WAVES = { "sine", "saw", "sqr", "noi" }
local SUB_FIELDS = { { follow = true } }
for i = 1, 4 do
  for _, k in ipairs({ "wave", "amp", "det", "off" }) do
    table.insert(SUB_FIELDS, { i = i, k = k })
  end
end

-- env page where sync_object pushes ADSR: generators (amplitude) and
-- effects (param envelopes, sequencer-triggered; footer shows the target)
local ENV_TYPES = { oscillator = true, loop = true, sampler = true,
  filter = true, delay = true, modulator = true, waveshaper = true }
local ENV_TARGET = { filter = "cutoff", delay = "fdbk",
  modulator = "drywet", waveshaper = "drywet" }

-- L3 pages per object: 2d for two-param effects; steps/vel/dur for
-- sequencer; sample browser for loop+sampler; settings page for syncable
-- types + sampler; subs for oscillator; notes for tonality;
-- envelope for envelope-driven generators
local function pages_for(o)
  local p = {}
  local c = World.TYPES[o.type].category
  if c == "effect" then table.insert(p, "2d") end
  if o.type == "sequencer" then
    table.insert(p, 1, "dur")
    table.insert(p, 1, "vel")
    table.insert(p, 1, "steps")
  end
  if o.type == "oscillator" then table.insert(p, 1, "subs") end
  if o.type == "tonality" then table.insert(p, 1, "notes") end
  if o.type == "loop" or o.type == "sampler" then table.insert(p, 1, "browser") end
  if SET_FIELDS[o.type] then table.insert(p, 1, "set") end
  if ENV_TYPES[o.type] then table.insert(p, "env") end
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
  reset_move_physics()
  rebuild_link_candidates()
end

-- camera easing: hops set a target, UI.tick flies the camera there
-- (owner, 2026-09-26: instant teleport felt wrong)
local cam_target = nil
local CAM_EASE = 0.18     -- fraction of remaining distance per 1/15 s frame
local CAM_EPS = 0.002

-- E1 in any L2 mode: hop selection to the next/previous object (by id),
-- easing the camera onto it (owner feature 2026-09-25, generalized 2026-09-26)
local function cycle_selected(d)
  local n = #World.objects
  if n == 0 then return end
  local i = 0
  for j, o in ipairs(World.objects) do
    if selected and o.id == selected.id then i = j end
  end
  selected = World.objects[((i - 1 + d) % n) + 1]
  cam_target = { x = selected.x, y = selected.y }
  rebuild_link_candidates()
end

-- MOVE physics: encoder turns add velocity; UI.tick integrates with friction
-- so blocks glide with accel/decel (owner, 2026-09-26)
local vel_x, vel_y = 0, 0
local FRICTION = 0.92      -- per 1/15 s frame; higher = longer glide
local VEL_EPS = 0.0005

local function zoom_scale() return 48 / cam.zoom end
local function clamp_vel(v)
  local m = 0.04 * zoom_scale()
  return util.clamp(v, -m, m)
end
function reset_move_physics()
  vel_x, vel_y = 0, 0
end

-- drop any selection/mode state (used by table-clear and the T harness)
function UI.deselect()
  selected = nil
  level = "L1"
  mode = "MOVE"
  reset_move_physics()
  clear_armed = false
end

-- deferred solo-K3 (combo detection window, NDI-agent feedback 2026-09-28):
-- physical K1+K3 presses always stagger; if K3 lands first we must not
-- commit to the solo action until K1 has had a chance to form the combo.
local k3_pending = nil -- util.time() of a K3-down awaiting the window
local COMBO_WINDOW = 0.12 -- s
local cycle_mode -- forward decl: fire_k3_solo runs before its definition

-- ^K3 shifted action: place menu at L1, dive to config at L2, mute in LINK
local function fire_k3_combo()
  if level == "L1" then
    level = "L0"; menu_idx = 1
  elseif level == "L2" and selected then
    if mode == "LINK" and link_candidates[link_idx] then
      World.toggle_mute(selected.id, link_candidates[link_idx].obj.id)
    elseif #pages_for(selected) > 0 then
      level = "L3"; page_idx = 1; field_idx = 1; step_idx = 1
      browser.files = nil; browser.idx = 1
    end
  end
end

-- solo K3 action (fires on window expiry, or on release for a quick tap)
local function fire_k3_solo()
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
    if page == "steps" or page == "vel" or page == "dur" then
      local st = World.seq_steps(selected)[step_idx]
      st.on = not st.on
    elseif page == "notes" then
      local d0 = field_idx - 1
      selected.notes[d0] = not selected.notes[d0]
    elseif page == "browser" then
      if browser.files == nil then browser.files = scan_audio_files() end
      local f = browser.files[browser.idx]
      if f then Audio.load_sample(selected, _path.audio .. f) end
    end
  end
end

-- called from the redraw metro; returns true while a move is animating
function UI.tick()
  -- SYSTEM menu: all three keys held past the threshold
  if master_t and util.time() - master_t >= MASTER_LONG then
    master_t = nil
    level = "SYS"
    sys_idx = 1
    sys_confirm = nil
    sys_msg = nil
    selected = nil
    return true
  end
  -- deferred solo-K3: window expired with no combo partner (held press)
  if k3_pending and util.time() - k3_pending >= COMBO_WINDOW then
    k3_pending = nil
    fire_k3_solo()
    return true
  end
  local moving = false
  -- camera ease toward hop target
  if cam_target then
    local dx, dy = cam_target.x - cam.x, cam_target.y - cam.y
    if math.abs(dx) < CAM_EPS and math.abs(dy) < CAM_EPS then
      cam.x, cam.y = cam_target.x, cam_target.y
      cam_target = nil
    else
      cam.x, cam.y = cam.x + dx * CAM_EASE, cam.y + dy * CAM_EASE
      moving = true
    end
  end
  -- block glide physics
  if level ~= "L2" or mode ~= "MOVE" or not selected then return moving end
  if math.abs(vel_x) < VEL_EPS and math.abs(vel_y) < VEL_EPS then
    vel_x, vel_y = 0, 0
    return moving
  end
  local nx = selected.x + vel_x
  local ny = selected.y + vel_y
  local r = math.sqrt(nx * nx + ny * ny)
  if r > 0.95 then -- soft wall at the rim
    local s = 0.95 / r
    nx, ny = nx * s, ny * s
    vel_x, vel_y = 0, 0
  end
  selected.x, selected.y = nx, ny
  vel_x, vel_y = vel_x * FRICTION, vel_y * FRICTION
  World.recompute()
  return true
end

function cycle_mode(dir)
  local i = 1
  for j, m in ipairs(modes) do if m == mode then i = j end end
  mode = modes[((i - 1 + (dir or 1)) % #modes) + 1]
  if mode == "LINK" then rebuild_link_candidates() end
end

function UI.enc(n, d)
  if level == "SYS" then
    if n == 2 then
      sys_idx = util.clamp(sys_idx + d, 1, #SYS_ITEMS)
      sys_msg = nil
    end
    dirty()
    return
  end
  if level == "L1" then
    if n == 1 then
      cam.zoom = util.clamp(cam.zoom * (1 + d * 0.04), 8, 480)
    elseif n == 2 then
      cam_target = nil
      cam.x = cam.x + d * 0.01 * (48 / cam.zoom)
    elseif n == 3 then
      cam_target = nil
      cam.y = cam.y + d * 0.01 * (48 / cam.zoom)
    end
  elseif level == "L0" then
    local items = menu_selectables()
    if n == 2 then
      menu_idx = util.clamp(menu_idx + d, 1, #items)
    end
  elseif level == "L2" and selected then
    -- E1 hops selection in every L2 mode (owner, 2026-09-26)
    if n == 1 then
      cycle_selected(d > 0 and 1 or -1)
      if mode == "MOVE" then reset_move_physics() end
    elseif mode == "MOVE" then
      -- accel/decel glide: encoders add velocity, UI.tick integrates
      local imp = d * 0.0007 * (48 / cam.zoom) -- 3x less sensitive (owner, 2026-09-26)
      if n == 2 then vel_x = clamp_vel(vel_x + imp)
      elseif n == 3 then vel_y = clamp_vel(vel_y + imp) end
    elseif mode == "ROTATE" then
      if n == 2 and k1_down then
        World.cycle_subtype(selected, d > 0 and 1 or -1)
      elseif n == 2 then
        selected.angle = (selected.angle + d * 0.05) % (2 * math.pi)
      elseif n == 3 then
        -- the slider (spec §3): E3 = slider param, K1+E3 = fine adjust
        local key = World.SLIDER_PARAM[selected.type]
        if key then
          local step = k1_down and 0.004 or 0.02
          selected.params[key] = util.clamp(selected.params[key] + d * step, 0, 1)
        end
      end
    elseif mode == "LINK" then
      if n == 2 and #link_candidates > 0 then
        link_idx = ((link_idx - 1 + d) % #link_candidates) + 1
      end
    end
  elseif level == "L3" and selected then
    if k1_down and n == 2 then
      -- subtype cycling from any config page (same as K1+E2 in ROTATE)
      World.cycle_subtype(selected, d > 0 and 1 or -1)
      dirty()
      return
    end
    local pages = pages_for(selected)
    local page = pages[page_idx]
    if n == 1 then
      page_idx = 1 + (page_idx % #pages)
      field_idx = 1
    elseif page == "2d" then
      local kx, ky = params_2d(selected)
      if n == 2 then selected.params[kx] = util.clamp(selected.params[kx] + d * 0.02, 0, 1)
      elseif n == 3 then selected.params[ky] = util.clamp(selected.params[ky] + d * 0.02, 0, 1) end
    elseif page == "steps" or page == "vel" or page == "dur" then
      if n == 2 then
        step_idx = util.clamp(step_idx + d, 1, 16)
      elseif n == 3 then
        local st = World.seq_steps(selected)[step_idx]
        if page == "vel" then
          st.vel = util.clamp(st.vel + d * 0.02, 0, 1)
        elseif page == "dur" then
          st.dur = util.clamp((st.dur or 2) + d, 1, 8)
        elseif selected.subtype == 3 then
          -- random: pitch is improvised; E3 edits velocity here
          st.vel = util.clamp(st.vel + d * 0.02, 0, 1)
        elseif k1_down then
          st.vel = util.clamp(st.vel + d * 0.02, 0, 1)
        else
          st.pitch = util.clamp(st.pitch + d, -24, 24)
        end
      end
    elseif page == "set" then
      local fields = SET_FIELDS[selected.type]
      if n == 2 then
        field_idx = util.clamp(field_idx + d, 1, #fields)
      elseif n == 3 then
        local f = fields[field_idx]
        if f.k == "base" then
          local st = util.clamp(base_semis(selected) + d, f.min, f.max)
          selected.params.base = C4 * (2 ^ (st / 12))
        else
          selected.params[f.k] =
            util.clamp(selected.params[f.k] + d * f.step, f.min, f.max)
        end
      end
    elseif page == "subs" then
      if n == 2 then
        field_idx = util.clamp(field_idx + d, 1, #SUB_FIELDS)
      elseif n == 3 then
        local f = SUB_FIELDS[field_idx]
        if f.follow then
          selected.subs.follow = util.clamp(selected.subs.follow + d, 0, 1)
        else
          local s = selected.subs[f.i]
          if f.k == "wave" then s.wave = util.clamp(s.wave + d, 0, 3)
          elseif f.k == "amp" then s.amp = util.clamp(s.amp + d * 0.02, 0, 1)
          elseif f.k == "det" then s.det = util.clamp(s.det + d * 2, -100, 100)
          else s.off = util.clamp(s.off + d, -24, 24) end
        end
      end
    elseif page == "notes" then
      if n == 2 then
        field_idx = util.clamp(field_idx + d, 1, 12)
      elseif n == 3 then
        local d0 = field_idx - 1
        selected.notes[d0] = not selected.notes[d0]
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

-- third key down while the other two are held: start the SYSTEM-menu timer
-- and neutralize whatever the two-key combos already did
local function master_check()
  if k1_down and k2_down and k3_down and not master_t then
    master_t = util.time()
    clear_armed = false
    k3_slot_press = nil -- a slot press superseded by the gesture must not
    slot_cand = nil     -- fire store/recall on release
    k3_pending = nil    -- nor a deferred solo-K3
    if level == "L0" then level = "L1" end
  end
end

function UI.key(n, z)
  if n == 1 then
    -- K1 = held shift only; its short tap belongs to the norns system menu
    k1_down = (z == 1)
    -- K1 may be the LAST key of the three down (owner physical press 2026-09-27)
    if z == 1 then master_check() else master_t = nil end
    -- late combo: K3 was waiting out the window when K1 arrived
    if z == 1 and k3_pending and not master_t then
      k3_pending = nil
      fire_k3_combo()
      dirty()
      return
    end
  elseif n == 2 then
    k2_down = (z == 1)
    if z == 1 then master_check() else master_t = nil end
  elseif n == 3 then
    k3_down = (z == 1)
    if z == 1 then master_check() else master_t = nil end
  end
  -- SYSTEM level: E2 scroll / K3 select / K2 close; swallow everything else
  if level == "SYS" then
    if n == 2 and z == 1 then
      if sys_confirm then sys_confirm = nil else level = "L1" end
    elseif n == 3 and z == 1 then
      if sys_confirm == "restore" then
        sys_msg = "restored " .. Slots.restore_factory() .. " presets"
        sys_confirm = nil
      elseif SYS_ITEMS[sys_idx] == "RESTORE PRESETS" then
        sys_confirm = "restore"
      elseif SYS_ITEMS[sys_idx] == "ABOUT" then
        sys_msg = "rotatable v3 | " .. (Slots.factory_available() and
          Slots.N .. " factory presets" or "no presets bundled")
      end
    end
    dirty()
    return
  end
  if master_t then dirty() return end -- all three held: suppress combos
  if n == 2 and z == 1 then
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
    elseif level == "L2" then
      -- back walks through modes in reverse before leaving to NAV (owner, 2026-09-26)
      if mode == "MOVE" then
        level = "L1"; selected = nil
      else
        cycle_mode(-1)
      end
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
        UI.deselect()
      elseif k1_down then
        fire_k3_combo()
      else
        k3_pending = util.time() -- wait out the combo window (see above)
      end
    else -- z == 0, release
      if k3_pending then
        -- quick tap: no combo partner arrived, fire the solo action now
        k3_pending = nil
        fire_k3_solo()
      end
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
    " " .. World.subtype_name(selected) ..
    (selected.type == "sequencer" and " p" .. (selected.params.preset or 1) or "") ..
    "  [" .. page .. " " .. page_idx .. "/" .. #pages .. "]")
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
    local tgt = ENV_TARGET[selected.type]
    if tgt then
      screen.level(3)
      screen.move(96, 60)
      screen.text(tgt)
    end
  elseif page == "steps" or page == "vel" or page == "dur" then
    -- 16 steps around a midline. steps: bar = pitch (-24..+24; random
    -- subtype shows its improvised history instead), vel: bar = velocity,
    -- dur: bar = step length in 32nds. brightness = vel, dot = step off
    local steps = World.seq_steps(selected)
    local random = selected.subtype == 3
    local x0, mid = 14, 36
    screen.level(3)
    screen.move(x0, mid) screen.line(118, mid)
    screen.stroke()
    for i = 1, 16 do
      local st = steps[i]
      local x = x0 + (i - 1) * 7
      local lvl = st.on and (2 + math.floor(st.vel * 12)) or 2
      if i == step_idx then lvl = 15 end
      screen.level(lvl)
      local h
      if page == "steps" then
        local pitch = st.pitch
        if random then pitch = (selected._hist and selected._hist[i]) or 0 end
        h = util.clamp(pitch, -24, 24) / 24 * 16
      elseif page == "vel" then
        h = st.vel * 16
      else -- dur
        h = ((st.dur or 2) / 8) * 16
      end
      local show = st.on or
        (page == "steps" and random and selected._hist and selected._hist[i])
      if show then
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
    local st = steps[step_idx]
    screen.level(6)
    screen.move(12, 60)
    if page == "steps" then
      if random then
        screen.text(string.format("st%d %s RND last %+d", step_idx,
          st.on and "ON" or "off",
          (selected._hist and selected._hist[step_idx]) or 0))
      else
        screen.text(string.format("st%d %s %+d vel %.2f", step_idx,
          st.on and "ON" or "off", st.pitch, st.vel))
      end
    elseif page == "vel" then
      screen.text(string.format("st%d %s vel %.2f", step_idx,
        st.on and "ON" or "off", st.vel))
    else
      screen.text(string.format("st%d %s dur %d/32", step_idx,
        st.on and "ON" or "off", st.dur or 2))
    end
  elseif page == "set" then
    local fields = SET_FIELDS[selected.type]
    local y = 24
    for i, f in ipairs(fields) do
      if i == field_idx then
        screen.level(15)
        screen.rect(10, y - 6, 106, 9)
        screen.fill()
        screen.level(0)
      else
        screen.level(10)
      end
      screen.move(14, y)
      screen.text(f.k)
      screen.move(50, y)
      screen.text(set_field_str(selected, f))
      y = y + 11
    end
    screen.level(3)
    screen.move(12, 60)
    screen.text("E2 field  E3 edit")
  elseif page == "subs" then
    -- follow toggle + 4 sub rows (wave/amp/det/off)
    screen.level(field_idx == 1 and 15 or 8)
    screen.move(14, 20)
    screen.text("follow tonality")
    screen.move(96, 20)
    screen.text(selected.subs.follow == 1 and "on" or "off")
    local y = 29
    for i = 1, 4 do
      local s = selected.subs[i]
      local b = 2 + (i - 1) * 4
      screen.level(6)
      screen.move(14, y)
      screen.text("s" .. i)
      local cells = {
        { b, 30, SUB_WAVES[s.wave + 1] },
        { b + 1, 56, string.format("%.2f", s.amp) },
        { b + 2, 80, string.format("%+d", s.det) },
        { b + 3, 100, string.format("%+d", s.off) },
      }
      for _, c in ipairs(cells) do
        screen.level(field_idx == c[1] and 15 or 8)
        screen.move(c[2], y)
        screen.text(c[3])
      end
      y = y + 9
    end
  elseif page == "notes" then
    -- editable 12-degree scale mask; bright = in scale
    local NAMES = { "1", "b2", "2", "b3", "3", "4", "b5", "5", "b6", "6", "b7", "7" }
    local n_on = 0
    for d0 = 0, 11 do
      local col = d0 % 6
      local row = math.floor(d0 / 6)
      local x = 16 + col * 16
      local y = 32 + row * 15
      if field_idx == d0 + 1 then
        screen.level(15)
        screen.rect(x - 3, y - 8, 14, 11)
        screen.stroke()
      end
      screen.level(selected.notes[d0] and 12 or 3)
      screen.move(x, y)
      screen.text(NAMES[d0 + 1])
      if selected.notes[d0] then
        n_on = n_on + 1
        screen.move(x, y + 3)
        screen.line(x + 6, y + 3)
        screen.stroke()
      end
    end
    screen.level(6)
    screen.move(12, 60)
    screen.text(n_on .. " notes  E2 pick  E3/K3 toggle")
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

-- SYSTEM master menu (K1+K2+K3 long-hold)
local function draw_sys()
  screen.level(0)
  screen.rect(14, 2, 100, 60)
  screen.fill()
  screen.level(8)
  screen.rect(14, 2, 100, 60)
  screen.stroke()
  screen.level(3)
  screen.move(18, 12)
  screen.text("SYSTEM")
  if sys_confirm == "restore" then
    screen.level(10)
    screen.move(18, 28)
    screen.text("restore presets?")
    screen.level(3)
    screen.move(18, 38)
    screen.text("replaces all " .. Slots.N .. " slots")
    screen.level(10)
    screen.move(18, 52)
    screen.text("K3 yes   K2 no")
  else
    local y = 26
    for i, item in ipairs(SYS_ITEMS) do
      if i == sys_idx then
        screen.level(15)
        screen.rect(16, y - 5, 96, 7)
        screen.fill()
        screen.level(0)
      else
        screen.level(10)
      end
      screen.move(18, y)
      screen.text(item)
      y = y + 10
    end
    if sys_msg then
      screen.level(6)
      screen.move(18, 56)
      screen.text(sys_msg)
    end
  end
end

function UI.draw_overlay()
  if level == "L0" then draw_menu()
  elseif level == "SYS" then draw_sys()
  elseif level == "L3" and selected then draw_l3() end
end

function UI.overlay_open()
  return level == "L0" or level == "SYS" or (level == "L3" and selected ~= nil)
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
      if selected.type == "sequencer" then
        extra = extra .. " p" .. (selected.params.preset or 1)
      end
    elseif mode == "LINK" and link_candidates[link_idx] then
      local t = link_candidates[link_idx].obj
      extra = " -> " .. World.TYPES[t.type].label .. "#" .. t.id ..
        (World.is_hardlinked(selected.id, t.id) and " [HARD]" or "")
    end
    local act = mode == "LINK" and "hard" or "mode"
    local sact = mode == "LINK" and "mute"
      or (#pages_for(selected) > 0 and "cfg" or "--")
    local e1 = mode == "MOVE" and " E1 hop" or ""
    return mode .. " " .. World.TYPES[selected.type].label .. "#" .. selected.id ..
      extra .. " |" .. e1 .. " K3 " .. act .. " ^K3 " .. sact .. " K2 back"
  elseif level == "SYS" then
    return "SYSTEM  E2 scroll | K3 select K2 back"
  elseif level == "L3" and selected then
    return "CONFIG  E1 page E2/E3 edit | K2 back"
  end
  return ""
end

return UI
