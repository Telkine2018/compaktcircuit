
local commons = require("scripts.commons")

local function png(name) return ('__compaktcircuit__/graphics/%s.png'):format(name) end

data.raw["simple-entity-with-owner"][commons.processor_name].collision_box = { { -0.95, -0.95 }, { 0.95, 0.95 } }
data.raw["simple-entity-with-owner"][commons.processor_name_1x1].collision_box = { { -0.45, -0.45 }, { 0.45, 0.45 } }

local prefix = commons.prefix
local declarations = {}

if mods["space-age"] then
    local planets = data.raw["planet"]
    for _, planet in pairs(planets) do
        -- log(serpent.block(planet))
        table.insert(declarations, {
            type = "virtual-signal",
            name = prefix .. "-" .. planet.name .. "-target",
            localised_name = { "compaktcircuit.target-planet", { "space-location-name." .. planet.name } },
            icons = {
                {
                    icon = planet.icon,
                    icon_size = planet.icon_size or 64
                },
                {
                    icon = png("icons/target")
                }
            },
            subgroup = prefix .. "-signal",
            order = string.char(SignalOrder)
        })
    end

    SignalOrder = SignalOrder + 1
    data:extend(declarations)
end
