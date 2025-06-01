---@diagnostic disable: lowercase-global

---@class (exact) Skin
---@field bones { [pixelColor]: { lines: pixelColor[][], keypoints: integer[], secondary_color: pixelColor } }
---@field order pixelColor[]
Skin = {}

---@param image Image
---@param bones Image
---@param offset Point
---@return Skin
function load_skin(image, bones, offset)
  local skin = { bones = {}, order = {} }
  local function expand(point)
    local dx = 0
    while point.x + dx >= 0 and image:getPixel(point.x + dx, point.y) ~= 0 do
      dx = dx - 1
    end
    dx = dx + 1
    local line = {}
    while point.x + dx < image.width and image:getPixel(point.x + dx, point.y) ~= 0 do
      line[dx] = image:getPixel(point.x + dx, point.y)
      dx = dx + 1
    end
    return line
  end

  for x = 0, bones.width - 1 do
    local bone = nil
    for y = 0, bones.height - 1 do
      local color = bones:getPixel(x, y)
      if color == 0 then
        bone = nil
      else
        if not bone then
          bone = color
          skin.bones[bone] = { offset = y, secondary_color = nil, keypoints = { 0 }, lines = {} }
          table.insert(skin.order, 1, bone)
        elseif color == bone then
          table.insert(skin.bones[bone].keypoints, y - skin.bones[bone].offset)
        elseif not skin.bones[bone].secondary_color then
          skin.bones[bone].secondary_color = color
        end
        table.insert(skin.bones[bone].lines, expand(Point(x, y) + offset))
      end
    end
  end

  return skin
end

---@param skin Skin
---@param image Image
---@param skeleton Image
---@param offset Point
function render(skin, image, skeleton, offset)
  local function render_bone(origin, bone)
    -- Gather points
    local points = {}
    do
      local visited = {}
      local current = origin
      local function closest()
        local function test(p)
          if visited[p.x + p.y * skeleton.width] then return false end
          return skeleton:getPixel(p.x, p.y) == bone.secondary_color
        end
        for r = 1, 20 do
          for dx = 0, r do
            local p = Point(current.x - dx, current.y - r)
            if test(p) then return p end
            p = Point(current.x - dx, current.y + r)
            if test(p) then return p end
            p = Point(current.x + dx, current.y - r)
            if test(p) then return p end
            p = Point(current.x + dx, current.y + r)
            if test(p) then return p end
          end
          for dy = 0, r - 1 do
            local p = Point(current.x - r, current.y - dy)
            if test(p) then return p end
            p = Point(current.x + r, current.y - dy)
            if test(p) then return p end
            p = Point(current.x - r, current.y + dy)
            if test(p) then return p end
            p = Point(current.x + r, current.y + dy)
            if test(p) then return p end
          end
        end
      end

      ::add_point::
      table.insert(points, current + offset)
      visited[current.x + current.y * skeleton.width] = true
      current = closest()
      if current then goto add_point end
    end

    -- Fill gaps
    do
      local i = 1
      while i < #points do
        local p1 = points[i]
        local p2 = points[i + 1]
        local d = p2 - p1
        local steps = math.max(math.abs(d.x), math.abs(d.y))
        for j = 1, steps - 1 do
          local t = j / steps
          table.insert(points, i + j, p1 + Point(math.floor(d.x * t + 0.5), math.floor(d.y * t + 0.5)))
        end
        i = i + 1
      end
    end

    -- Mapping
    local v = Point(0, 1)
    if math.abs(points[math.min(#points, 3)].x - points[1].x) > math.abs(points[math.min(#points, 3)].y - points[1].y) then
      v = Point(points[1].x < points[#points].x and 1 or -1, 0)
    end
    for i, point in ipairs(points) do
      local old_v = v
      if i > 1 then v = point - points[i - 1]
      elseif i < #points then v = points[i + 1] - point end
      if i < #points then v = (v + points[i + 1] - point) / 2 end

      if v.x == 0 and v.y == 0 then v = old_v end
      if v.x ~= 0 and v.y ~= 0 then v = old_v end

      local keypoint = #points < 2 and 1 or math.floor((i - 1) / (#points - 1) * (#bone.lines - 1) + 1.5)
      for dx, color in pairs(bone.lines[keypoint]) do
        local target = point + Point(v.y, -v.x) * dx
        image:drawPixel(target.x, target.y, color)
        if v ~= old_v and i > 1 then
          local diag = v + old_v
          local clockwise = v == Point(-old_v.y, old_v.x)
          if clockwise ~= (dx > 0) then goto skip_fill end
          for dy = 1, math.abs(dx) do
            local fill_point = target - diag * dy
            image:drawPixel(fill_point.x, fill_point.y, color)
          end
          ::skip_fill::
        end
      end
    end
  end

  local origins = {}
  for y = 0, skeleton.height - 1 do
    for x = 0, skeleton.width - 1 do
      local color = skeleton:getPixel(x, y)
      if skin.bones[color] then
        if not origins[color] then origins[color] = {} end
        table.insert(origins[color], Point(x, y))
      end
    end
  end
  for _, color in ipairs(skin.order) do
    if origins[color] then
      for _, origin in ipairs(origins[color]) do
        render_bone(origin, skin.bones[color])
      end
    end
  end
end

return {
  load_skin = load_skin,
  render = render
}
