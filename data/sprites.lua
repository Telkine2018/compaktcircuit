local commons = require("scripts.commons")
local tools = require("scripts.tools")

local combinators = require("data.combinators")
local prefix = commons.prefix
local debug_mode = commons.debug_mode
local png = combinators.png

local declarations = {}

local function add_display_sprite(name)
    local sprite = {
        type = "sprite",
        name = prefix .. "_display_" .. name,
        filename = png("sprites/display/" .. name),
        width = 64,
        height = 64,
        mipmap_count = 4,
        flags = {"group=icon"}
    }
    table.insert(declarations, sprite)
end

for _, name in pairs({"meta","signal","sprite", "text", "multi_signal" }) do
    add_display_sprite(name)    
end

local function add_input_sprite(name)
    local sprite = {
        type = "sprite",
        name = prefix .. "_input_" .. name,
        filename = png("sprites/input/" .. name),
        width = 64,
        height = 64,
        mipmap_count = 4,
        flags = {"group=icon"}
    }
    table.insert(declarations, sprite)
end

for _, name in pairs({"integer","slider","toggle", "drop_down", "choose_signals", "choose_signals_with_count", "comm" }) do
    add_input_sprite(name)    
end

data:extend(declarations)

-- log(serpent.block(data.raw["electric-pole"]["substation"]))
