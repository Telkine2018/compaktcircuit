local commons = require("scripts.commons")
local tools = require("scripts.tools")

local combinators = require("data.combinators")
local prefix = commons.prefix
local debug_mode = commons.debug_mode
local png = combinators.png

local invisible_sprite = {
    count = 1,
    filename = png("invisible"),
    width = 1,
    height = 1,
    direction_count = 1
}

local select_input = {
    type = "custom-input",
    key_sequence = "mouse-button-1",
    name = prefix .. "-click"
}

local control_select_input = {
    type = "custom-input",
    key_sequence = "CONTROL + mouse-button-1",
    name = prefix .. "-control-click"
}

data:extend{select_input, control_select_input}

local styles = data.raw["gui-style"].default

for _, color in pairs {
    "default", "grey", "red", "orange", "yellow", "green", "cyan", "blue",
    "purple", "pink"
} do
    styles[prefix .. "_slot_button_" .. color] = {
        type = "button_style",
        parent = "flib_slot_button_" .. color,
        size = 40
    }
end

---------------------------

-- Item definition
local display_item = table.deepcopy(data.raw["item"]["small-lamp"])
display_item = tools.table_merge {
    display_item, {
        name = commons.display_name,
        icon = png("item/display"),
        stack_size = 1,
        enabled = true,
        place_result = prefix .. "-display",
        subgroup = 'circuit-network',
        order = 'a[miniaturization]-d[display]',
        flags = { "hide-from-bonus-gui", "only-in-cursor", }
    }
}

-- Entity definition
local display_entity = table.deepcopy(data.raw["lamp"]["small-lamp"])
display_entity = tools.table_merge {
    display_entity, {
        name = commons.display_name,
        hidden_in_factoriopedia = true,
        icon = png("item/display"),
        active_energy_usage = '1kW',
        energy_source = {type = "void"},
        render_no_network_icon = false,
        render_no_power_icon = false,
        minable = {mining_time = 0.1, result = commons.display_name}
    }
}
---@diagnostic disable-next-line: undefined-field
display_entity.picture_off.layers[1].filename = png("entity/display/hr-display")
---@diagnostic disable-next-line: undefined-field

local invisible_image = {
    filename = png("invisible"),
    height = 32,
    width = 32,
    x = 0,
    y = 0
}

--- Internal display
local packed_display_entity = {

    circuit_connector_sprites = {
        led_blue = invisible_image,
        led_green = invisible_image,
        led_light = {intensity = 0, size = 0.1},
        led_red = invisible_image,
        red_green_led_light_offset = {0, 0}
    },
    circuit_wire_connection_point = {
        shadow = {green = {0, 0}, red = {0, 0}},
        wire = {green = {0, 0}, red = {0, 0}}
    },
    circuit_wire_max_distance = 9,
    collision_box = {{-0.01, -0.01}, {0.01, 0.01}},
    collision_mask = { layers={} },
    draw_circuit_wires = false,
    draw_copper_wires = false,
    energy_source = {type = "void"},
    energy_usage_per_tick = "1J",
    flags = {
        "hide-alt-info", "not-on-map", "not-upgradable", "not-deconstructable",
        "not-blueprintable", "placeable-off-grid"
    },
    glow_color_intensity = 0,
    glow_render_mode = "multiplicative",
    glow_size = 0.01,
    hidden_in_factoriopedia = true,
    icon = "__base__/graphics/icons/small-lamp.png",
    icon_mipmaps = 4,
    icon_size = 64,
    darkness_for_all_lamps_off = 0.01,
    darkness_for_all_lamps_on = 0.01,
    light = {color = {b = 0.75, g = 1, r = 1}, intensity = 0.01, size = 0.01},
    light_when_colored = {
        color = {b = 0.75, g = 1, r = 1},
        intensity = 0.01,
        size = 0.01
    },
    max_health = 100,
    name = commons.packed_display_name,
    picture_on = {layers = {invisible_sprite}},
    picture_off = {layers = {invisible_sprite}},
    selectable_in_game = false,
    selection_box = {{-0.1, -0.1}, {0.1, 0.1}},
    type = "lamp"
}

local invisible_sprite_def = {
    name = prefix .. "-invisible",
    filename = png("invisible"),
    width = 32,
    height = 32,
    type = "sprite"
}

-- Item definition
local input_item = table.deepcopy(data.raw["item"]["constant-combinator"])
input_item = tools.table_merge {
    input_item, {
        name = commons.input_name,
        icon = png("item/input"),
        stack_size = 1,
        enabled = true,
        place_result = prefix .. "-input",
        subgroup = 'circuit-network',
        order = 'a[miniaturization]-[input]',
        flags = { "hide-from-bonus-gui", "only-in-cursor", }
    }
}

-- Entity definition
local input_entity = table.deepcopy(
                         data.raw["constant-combinator"]["constant-combinator"])
input_entity = tools.table_merge {
    input_entity, {
        name = commons.input_name,
        hidden_in_factoriopedia = true,
        icon = png("item/input"),
        item_slot_count = 32,
        active_energy_usage = '1kW',
        energy_source = {type = "void"},
        render_no_network_icon = false,
        render_no_power_icon = false,
        minable = {mining_time = 0.1, result = commons.input_name}
    }
}

---@cast input_entity any
local sprite = png("entity/constant-combinator/constant-combinator")
local hr_sprite = png("entity/constant-combinator/hr-constant-combinator")
input_entity.sprites.east.layers[1].filename = hr_sprite
input_entity.sprites.west.layers[1].filename = hr_sprite
input_entity.sprites.north.layers[1].filename = hr_sprite
input_entity.sprites.south.layers[1].filename = hr_sprite

local declarations = {
    display_item, display_entity, packed_display_entity, invisible_sprite_def,
    input_entity, input_item
}

data:extend(declarations)

-- log(serpent.block(data.raw["electric-pole"]["substation"]))
