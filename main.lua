-- local pixamo = require "pixamo"
-- print(pixamo)
local pixamo = dofile "pixamo.lua"

local function open_skin_file()
  local spr = app.sprite
  if not spr then app.alert "There is no active sprite" return end

  local filename = app.fs.filePathAndTitle(spr.filename) .. ".skin." .. app.fs.fileExtension(spr.filename)
  for _, sprite in ipairs(app.sprites) do
    if sprite.filename == filename then
      return sprite
    end
  end

  local skin = app.open(filename)
  if not skin then app.alert "No skin file found" return end
  app.sprite = spr
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

---@param layer Layer
local function find_gen_layer(layer)
    for _, sp_layer in ipairs(layer.sprite.layers) do
      if sp_layer.name == layer.name .. " generated" then
        return sp_layer
      end
    end
    local gen_layer = layer.sprite:newLayer()
    gen_layer.name = layer.name .. " generated"
    return gen_layer
end

---@param skin Skin
---@param cel Cel | nil
---@param gen_layer Layer
local function regenerate_cel(skin, cel, gen_layer)
  if not cel then return end
  if gen_layer:cel(cel.frameNumber) then gen_layer.sprite:deleteCel(gen_layer:cel(cel.frameNumber)) end

  local image = Image(gen_layer.sprite.width, gen_layer.sprite.height, skin.colorMode)
  pixamo.render(skin, image, cel.image, cel.position)

  gen_layer.sprite:newCel(gen_layer, cel.frameNumber, image, Point(0, 0))
end

local function regenerate()
  local skin = load_skin()
  if not skin then return end

  local cels = nil
  if app.range and app.range.type == RangeType.CELS then
    cels = app.range.cels
  elseif app.layer then
    cels = app.layer.cels
  else
    app.alert "Neither layer nor cels are selected"
    return
  end
  if #cels == 0 then return end

  app.transaction("Regenerate pixamo", function()
    local layer = cels[1].layer
    local gen_layer = find_gen_layer(layer)
    for _, cel in ipairs(cels) do
      regenerate_cel(skin, cel, gen_layer)
    end
    app.layer = layer
  end)
  app.command.Refresh()
end

function init(plugin)
  plugin:newCommand{
    id="RegeneratePixamo",
    title="Regenerate pixamo",
    group="layer_popup_properties",
    onclick=regenerate
  }
  plugin:newCommand{
    id="RegeneratePixamoCels",
    title="Regenerate pixamo",
    group="cel_popup_properties",
    onclick=regenerate
  }
end

