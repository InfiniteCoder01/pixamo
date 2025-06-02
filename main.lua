-- local pixamo = require "pixamo"
-- print(pixamo)
local pixamo = dofile "pixamo.lua"

local function open_skin_file()
  local spr = app.activeSprite
  if not spr then app.alert "There is no active sprite" return end

  local filename = app.fs.filePathAndTitle(spr.filename) .. ".skin." .. app.fs.fileExtension(spr.filename)
  for _, sprite in ipairs(app.sprites) do
    if sprite.filename == filename then
      return sprite
    end
  end

  local skin = app.open(filename)
  if not skin then app.alert "No skin file found" return end
  app.activeSprite = spr
  return skin
end

local function load_skin()
  local sprite = open_skin_file()
  if not sprite then return end
  if #sprite.layers < 2 then app.alert "First two layers must be bones and skin!" return end
  local image = sprite.layers[1]:cel(1)
  local bones = sprite.layers[2]:cel(1)
  if not image or not bones then app.alert "Internal error" return end
  local skin = pixamo.load_skin(image.image, bones.image, bones.position - image.position)
  skin.colorMode = image.image.colorMode
  return skin
end

---@param sprite Sprite
---@param name string
local function find_gen_layer(sprite, name)
    for _, sp_layer in ipairs(sprite.layers) do
      if sp_layer.name == name then
        return sp_layer
      end
    end
    local gen_layer = sprite:newLayer()
    gen_layer.name = name
    return gen_layer
end

---@param one_cel boolean
local function regenerate(one_cel)
  local skin = load_skin()
  if not skin then return end

  local sprite = app.activeSprite
  if not sprite then app.alert "There is no active sprite" return end
  local layer = app.activeLayer
  if not layer then app.alert "There is no active layer" return end
  if one_cel then
    if not app.activeCel then app.alert "There is no active cel" return end
  end


  app.transaction("Regenerate pixamo", function()
    local gen_layer = find_gen_layer(sprite, layer.name .. " generated")

    ---@param frame integer
    local function regenerate_cel(frame)
      local cel = layer:cel(frame)
      if not cel then return end
      if gen_layer:cel(frame) then sprite:deleteCel(gen_layer:cel(frame)) end

      local image = Image(sprite.width, sprite.height, skin.colorMode)
      pixamo.render(skin, image, cel.image, cel.position)

      sprite:newCel(gen_layer, frame, image, Point(0, 0))
    end

    if one_cel then
      regenerate_cel(app.activeCel.frameNumber)
    else
      for _, frame in ipairs(sprite.frames) do
        regenerate_cel(frame.frameNumber)
      end
    end

    app.activeLayer = layer
  end)
  app.command.Refresh()
end

function init(plugin)
  plugin:newCommand{
    id="RegeneratePixamo",
    title="Regenerate pixamo",
    group="layer_popup_properties",
    onclick=function() regenerate(false) end
  }
  plugin:newCommand{
    id="RegeneratePixamo",
    title="Regenerate pixamo",
    group="cel_popup_properties",
    onclick=function() regenerate(true) end
  }
end

