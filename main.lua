local pixamo = dofile "pixamo.lua"

---@param pixamo_layer Layer
---@param id string
local function find_layer(pixamo_layer, id)
  local name = pixamo_layer.name:gsub("%[pixamo%]", id)
  local function search(layers)
    for _, sp_layer in ipairs(layers) do
      if sp_layer.name == name then
        return sp_layer
      end
      if sp_layer.layers then
        local layer = search(sp_layer.layers)
        if layer ~= nil then
          return layer
        end
      end
    end
    return nil
  end
  local layer = search(pixamo_layer.sprite.layers)
  if not layer then
    layer = pixamo_layer.sprite:newLayer()
    layer.name = name
    layer.parent = pixamo_layer.parent
    layer.stackIndex = pixamo_layer.stackIndex
  end
  return layer
end

---@param skin Skin
---@param cel Cel | nil
---@param gen_layer Layer
local function regenerate_cel(skin, cel, gen_layer)
  if not cel then return end
  if gen_layer:cel(cel.frameNumber) then gen_layer.sprite:deleteCel(gen_layer:cel(cel.frameNumber)) end

  local image = Image(gen_layer.sprite.width, gen_layer.sprite.height, skin.colorMode)
  pixamo.render(skin, image, cel.image:clone(), cel.position)

  gen_layer.sprite:newCel(gen_layer, cel.frameNumber, image, Point(0, 0))
end

local function regenerate(cels)
  if not cels then
    if app.cel then cels = {app.cel}
    else
      app.alert "Neither layer nor cels are selected"
      return
    end
  end
  if #cels == 0 then return end

  app.transaction("Regenerate pixamo", function()
    local layer = cels[1].layer
    local skin_layer = find_layer(layer, "[skin]")
    local bones = find_layer(layer, "[bones]")
    local gen_layer = find_layer(layer, "[generated]")
    for _, cel in ipairs(cels) do
      local skin_cel = skin_layer:cel(cel.frame)
      local bones_cel = bones:cel(cel.frame)
      if not skin_cel or not skin_cel.image or not bones_cel or not bones_cel.image then
        app.alert "Skin or bones layers are empty"
        return
      end

      local skin = pixamo.load_skin(
        skin_cel.image,
        bones_cel.image,
        bones_cel.position - skin_cel.position
      )
      skin.colorMode = skin_cel.image.colorMode
      regenerate_cel(skin, cel, gen_layer)
    end
    app.layer = layer
  end)
  app.refresh()
end

local function on_change(ev)
  if ev.fromUndo then return end
  if app.layer.name:find("[pixamo]", 1, true) == nil then return end
  app.sprite.events:off(on_change)
  regenerate()
  app.sprite.events:on("change", on_change)
end

-- Site change
local function before_site_change()
  if not app.sprite then return end
  app.sprite.events:off(on_change)
end

local function on_site_change()
  if not app.sprite then return end
  app.sprite.events:off(on_change)
  app.sprite.events:on("change", on_change)
end

-- Unregister old instance
if PIXAMO ~= nil then PIXAMO.exit() end
PIXAMO = {}

-- Init
function init(plugin)
  plugin:newCommand{
    id="RegeneratePixamo",
    title="Regenerate pixamo",
    group="layer_popup_properties",
    onclick=function() regenerate(app.layer.cels) end
  }
  plugin:newCommand{
    id="RegeneratePixamoCels",
    title="Regenerate pixamo",
    group="cel_popup_properties",
    onclick=function() regenerate(app.range.cels) end
  }
end

app.events:on("beforesitechange", before_site_change)
app.events:on("sitechange", on_site_change)

-- Exit
PIXAMO.exit = function()
  if app.sprite then
    app.sprite.events:off(on_change)
  end
  app.events:off(before_site_change)
  app.events:off(on_site_change)
end

function exit()
  PIXAMO.exit()
end
