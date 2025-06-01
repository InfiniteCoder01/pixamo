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

local function regenerate()
  local skin = load_skin()
  if not skin then return end

  local sprite = app.sprite
  if not sprite then app.alert "There is no active sprite" return end
  local layer = app.layer
  if not layer then app.alert "There is no active layer" return end

  app.transaction("Regenerate pixamo", function()
    local gen_layer = nil
    for _, sp_layer in ipairs(sprite.layers) do
      if sp_layer.name == layer.name .. " generated" then
        gen_layer = sp_layer
        for _, cel in ipairs(gen_layer.cels) do
          sprite:deleteCel(cel)
        end
        break
      end
    end
    if not gen_layer then
      gen_layer = sprite:newLayer()
      gen_layer.name = layer.name .. " generated"
    end

    for _, frame in ipairs(sprite.frames) do
      local cel = layer:cel(frame.frameNumber)
      if not cel then goto skip_cel end

      local image = Image(sprite.width, sprite.height, skin.colorMode)
      pixamo.render(skin, image, cel.image, cel.position)

      sprite:newCel(gen_layer, frame, image, Point(0, 0))
      ::skip_cel::
    end

    app.layer = layer
  end)
end

function init(plugin)
  plugin:newCommand{
    id="RegeneratePixamo",
    title="Regenerate pixamo",
    group="layer_popup_properties",
    onclick=regenerate
  }
end

