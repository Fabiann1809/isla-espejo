-- Packs an enemy's strips (assets/sprites/<id>/<id>_<animation>.png, square cells, drawn by its
-- tools/make_<id>_art.py) into an editable Aseprite file: one tag per animation, frame durations
-- from the game's frames per second (as tools/make_temple_enemy_frames.gd plays them).
--   aseprite -b --script-param dir=<repo>/assets/sprites/<id> --script-param id=<id> --script tools/enemy_aseprite.lua
-- Writes source/<id>.aseprite. Extra strips (projectiles, trails, effects) go in their own file each:
--   --script-param extras="trail:8,orb:12"   ->  source/<id>_trail.aseprite, source/<id>_orb.aseprite
-- An extra may name ranges as tags: "trail:8:spawn=1-3;burn=4-7;cool=8-11".

local dir = app.params["dir"]
local id = app.params["id"]
local animations = {
  { "idle", 6 }, { "walk", 10 }, { "attack", 12 }, { "special", 10 }, { "hurt", 9 }, { "death", 8 },
}

local function cells(path)
  local strip = Image { fromFile = path }
  local cell = strip.height
  local out = {}
  for i = 0, strip.width // cell - 1 do
    local img = Image(cell, cell, ColorMode.RGB)
    img:drawImage(strip, Point(-i * cell, 0))
    out[#out + 1] = img
  end
  return out, cell
end

-- list of { tag name, fps, strip file, first cell, last cell } (cells 1-based, inclusive)
local function pack(list, save_as)
  local sprite = nil
  local count = 0
  for _, anim in ipairs(list) do
    local frames, cell = cells(dir .. "/" .. anim[3])
    if sprite == nil then
      sprite = Sprite(cell, cell, ColorMode.RGB)
      sprite.layers[1].name = id
    end
    local first = count + 1
    for i = (anim[4] or 1), (anim[5] or #frames) do
      local frame = (count == 0) and sprite.frames[1] or sprite:newEmptyFrame()
      count = count + 1
      frame.duration = 1 / anim[2]
      sprite:newCel(sprite.layers[1], frame, frames[i], Point(0, 0))
    end
    local tag = sprite:newTag(first, count)
    tag.name = anim[1]
  end
  sprite:saveAs(save_as)
  print(save_as .. " " .. count .. " frames")
end

local list = {}
for _, a in ipairs(animations) do
  list[#list + 1] = { a[1], a[2], id .. "_" .. a[1] .. ".png" }
end
pack(list, dir .. "/source/" .. id .. ".aseprite")

for extra in string.gmatch(app.params["extras"] or "", "[^,]+") do
  local name, fps, ranges = string.match(extra, "^([%w_]+):(%d+):?(.*)$")
  local file = id .. "_" .. name .. ".png"
  local parts = {}
  for tag, a, b in string.gmatch(ranges, "([%w_]+)=(%d+)%-(%d+)") do
    parts[#parts + 1] = { tag, tonumber(fps), file, tonumber(a), tonumber(b) }
  end
  if #parts == 0 then
    parts = { { name, tonumber(fps), file } }
  end
  pack(parts, dir .. "/source/" .. id .. "_" .. name .. ".aseprite")
end
