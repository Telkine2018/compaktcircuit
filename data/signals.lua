
local commons = require("scripts.commons")
local tools = require("scripts.tools")

local combinators = require("data.combinators")
local prefix = commons.prefix
local debug_mode = commons.debug_mode
local png = combinators.png

local declarations = {}
local order = string.byte("a")

table.insert(declarations, {
    type = "item-subgroup",
    name = prefix .. "-signal",
    group = "signals",
    order = "f"
})

local function declare_signal(name)

    table.insert(declarations, {
        type = "virtual-signal",
        name = prefix .. "-" .. name,
        icon = png("signals/" .. name),
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = prefix .. "-signal",
        order = string.char(order)
    })
    order = order + 1
end

declare_signal("hide")
declare_signal("freeze")
declare_signal("x")
declare_signal("y")
declare_signal("scale")

SignalOrder = order

data:extend(declarations)
