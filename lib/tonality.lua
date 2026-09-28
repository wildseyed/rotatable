-- tonality.lua — scale quantizer (phase 7; spec §9 decision 6)
-- constrains sequencer notes, random sequencer, sampler notes, suboscillators.
-- oscillator main rotation stays continuous. If no tonality object is on the
-- table, nothing is constrained.

local Tonality = {}

Tonality.SCALES = {
  major = { 0, 2, 4, 5, 7, 9, 11 },
  minor = { 0, 2, 3, 5, 7, 8, 10 },
  pentatonic = { 0, 2, 4, 7, 9 },
  chromatic = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
}

-- active tonality from the table (first tonality object wins), or nil
function Tonality.current(world)
  for _, o in ipairs(world.objects) do
    if o.type == "tonality" then
      local name = world.TYPES.tonality.subtypes[o.subtype]
      return { root = math.floor(o.params.root or 0), scale = Tonality.SCALES[name] }
    end
  end
end

-- snap a semitone offset to the nearest tone of (root, scale); ties round up
function Tonality.snap(semi, root, scale)
  if not scale then return semi end
  local best, best_d = semi, math.huge
  for octave = -3, 3 do
    for _, degree in ipairs(scale) do
      local v = root + degree + octave * 12
      local d = math.abs(v - semi)
      if d < best_d then best, best_d = v, d end
    end
  end
  return best
end

-- convenience: snap with the table's current tonality (no-op when absent)
function Tonality.constrain(world, semi)
  local t = Tonality.current(world)
  if not t then return semi end
  return Tonality.snap(semi, t.root, t.scale)
end

return Tonality
