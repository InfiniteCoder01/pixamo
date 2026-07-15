---@diagnostic disable: lowercase-global

---@class (exact) Skin
---@field bones { [pixelColor]: { lines: pixelColor[][] } }
---@field order pixelColor[]
Skin = {}

---@param image Image
---@param bones Image
---@param offset Point
---@return Skin
function load_skin(image, bones, offset)
  local function expand(x, y)
    local dx = 0
    while x + dx >= 0 and image:getPixel(x + dx, y) ~= 0 do
      dx = dx - 1
    end
    dx = dx + 1
    local line = {}
    while x + dx < image.width and image:getPixel(x + dx, y) ~= 0 do
      line[dx] = image:getPixel(x + dx, y)
      dx = dx + 1
    end
    return line
  end

  local skin = { bones = {}, order = {} }
  for it in bones:pixels() do
    local bone = it()
    if bone then
      if not skin.bones[bone] then
        skin.bones[bone] = {
          lines = {},
        }
        table.insert(skin.order, 1, bone)
      end
      table.insert(skin.bones[bone].lines, expand(it.x + offset.x, it.y + offset.y))
    end
  end

  return skin
end

---@param skin Skin
---@param image Image
---@param skeleton Image
---@param offset Point
function render(skin, image, skeleton, offset)
  local function find_neighbour(point, color)
    local dirs = {
      Point(0, 1),  Point(1, 0),  Point(-1, 0),  Point(0, -1),
      Point(1, 1),  Point(-1, 1),  Point(1, -1),  Point(-1, -1),
      Point(0, 2),  Point(2, 0),  Point(-2, 0),  Point(0, -2),
      Point(0, 2),  Point(2, 0),  Point(-2, 0),  Point(0, -2),
      Point(1, 2), Point(-1, 2),  Point(2, 1), Point(-2, 1),
      Point(2, -1),  Point(-2, -1),  Point(1, -2), Point(-1, -2),
      Point(2, 2),  Point(-2, 2),  Point(2, -2), Point(-2, -2),
    }

    for i, dir in ipairs(dirs) do
      local p = point + dir
      if skeleton:getPixel(p.x, p.y) == color then
        return p, i
      end
    end
    return nil, #dirs + 1
  end

  local key = app.pixelColor.rgba(0, 0, 0)
  local function get_bone(origin, color)
    local points = { origin }
    skeleton:drawPixel(origin.x, origin.y, 0)
    while true do
      local next, _ = find_neighbour(points[#points], color)
      if not next then break end
      skeleton:drawPixel(next.x, next.y, 0)
      table.insert(points, next)
    end
    while true do
      local next, _ = find_neighbour(points[1], color)
      if not next then break end
      skeleton:drawPixel(next.x, next.y, 0)
      table.insert(points, 1, next)
    end

    local key1, dst1 = find_neighbour(points[1], key)
    local key2, dst2 = find_neighbour(points[#points], key)
    if dst2 < dst1 then
      for i = 1, #points//2, 1 do
          points[i], points[#points-i+1] = points[#points-i+1], points[i]
      end
      key2, key1 = key1, key2
    end
    if key1 then
      table.insert(points, 1, key1)
      skeleton:drawPixel(key1.x, key1.y, 0)
    end

    return points
  end

  local function draw_bone(bone, points)
    if not skin.bones[bone] then return end
    local function sign(x) return x < 0 and -1 or (x > 0 and 1 or 0) end
    local function round(x) return math.floor(x + 0.5) end
    local function round2(p, denom)
      return Point(round(p.x / denom), round(p.y / denom))
    end

    -- Drawing
    local dirs = { Point(0, 0) } -- Preff sums
    for i, p in ipairs(points) do
      if i > 1 then
        table.insert(dirs, dirs[#dirs] + p - points[i - 1])
      end
    end

    local last = nil
    local distance = 0
    for i, p in ipairs(points) do
      if i > 1 then
        local delta = p - points[i - 1]
        distance = distance + math.sqrt(delta.x * delta.x + delta.y * delta.y)
      end
      if round(distance) >= #skin.bones[bone].lines then break end
      local line = skin.bones[bone].lines[round(distance) + 1]

      local filter = math.max(math.min(i, #points - i + 1, 2), #line // 4) -- Less smoothing towards edges, more for thicker objects
      local dir = dirs[math.min(i + filter, #dirs)] - dirs[math.max(i - filter, 1)]
      local normal, denom = Point(1, 0), 1
      if dir ~= Point(0, 0) then
        normal = Point(dir.y, -dir.x)
        denom = math.sqrt(dir.x * dir.x + dir.y * dir.y)
      end

      local pts = {}
      for dx, color in pairs(line) do
        local p1 = p + offset + round2(normal * dx, denom)
        pts[dx] = p1

        if last and last[dx] then
          -- Draw line to smooth the transition
          local v = last[dx]
          while v ~= p1 do
            local delta = p1 - v
            if math.abs(delta.x) > math.abs(delta.y) or (
              math.abs(delta.x) == math.abs(delta.y) and
              sign(delta.x * delta.y) ~= sign(dx)
            ) then
              v = v + Point(sign(delta.x), 0)
            else v = v + Point(0, sign(delta.y)) end
            image:drawPixel(v.x, v.y, color)
          end
        else image:drawPixel(p1.x, p1.y, color) end
      end
      last = pts
    end
  end

  local bones = {}
  for color, _ in pairs(skin.bones) do
    bones[color] = {}
  end

  for it in skeleton:pixels() do
    local bone = it()
    if bone ~= 0 and bones[bone] then
      local points = get_bone(Point(it.x, it.y), bone)
      table.insert(bones[bone], points)
    end
  end

  for _, bone in ipairs(skin.order) do
    for _, points in ipairs(bones[bone]) do
      draw_bone(bone, points)
    end
  end
end

return {
  load_skin = load_skin,
  render = render
}
