local commons = require("scripts.commons")
local tools = require("scripts.tools")

local combinators = require("data.combinators")
local prefix = commons.prefix
local debug_mode = commons.debug_mode
local png = combinators.png

local no_processor_in_build = settings.startup[commons.prefix .. "-no_processor_in_build"].value

local recipe1 = {
    type = 'recipe',
    name = commons.processor_name,
    enabled = false,
    ingredients = {
        { type = 'item', name = 'electronic-circuit', amount = 20 },
        { type = 'item', name = 'advanced-circuit',   amount = 30 }

    },
    results = { { type = 'item', name = commons.processor_name, amount = 1 } }
}

local recipe2 = {
    type = 'recipe',
    name = commons.processor_name_1x1,
    enabled = false,
    ingredients = {
        { type = 'item', name = 'electronic-circuit', amount = 10 },
        { type = 'item', name = 'advanced-circuit',   amount = 10 }
    },
    results = { { type = 'item', name = commons.processor_name_1x1, amount = 1 } }
}

if mods["nullius"] then
    recipe1.name = "nullius-" .. recipe1.name
    recipe1.ingredients = {
        { type = 'item', name = "arithmetic-combinator", amount = 10 },
        { type = 'item', name = "copper-cable",          amount = 10 }
    }
    recipe1.category = "tiny-crafting"
    recipe1.always_show_made_in = true

    recipe2.name = "nullius-" .. recipe2.name
    recipe2.ingredients = {
        { type = 'item', name = "arithmetic-combinator", amount = 20 },
        { type = 'item', name = "copper-cable",          amount = 20 }
    }
    recipe2.category = "tiny-crafting"
    recipe2.always_show_made_in = true
end

local preq = "advanced-circuit"
if not no_processor_in_build then
    table.insert(recipe1.ingredients, { type = 'item', name = 'processing-unit', amount = 10 })
    table.insert(recipe2.ingredients, { type = 'item', name = 'processing-unit', amount = 3 })
    preq = "processing-unit"
end

-- Technology
local tech = {
    type = 'technology',
    name = prefix .. '-tech',
    icon_size = 128,
    icon = png('tech'),
    effects = {
        { type = 'unlock-recipe', recipe = recipe1.name },
        { type = 'unlock-recipe', recipe = recipe2.name }
    },
    prerequisites = { preq },
    unit = {
        count = 100,
        ingredients = {
            { 'automation-science-pack', 1 }, { 'logistic-science-pack', 1 },
            { 'chemical-science-pack',   1 }
        },
        time = 15
    },
    order = 'a-d-d-z'
}

if mods["nullius"] then
    tech.name = "nullius-" .. tech.name
    tech.order = "nullius-z-z-z"
    tech.unit = {
        count = 100,
        ingredients = {
            { "nullius-geology-pack", 1 }, { "nullius-climatology-pack", 1 }, { "nullius-electrical-pack", 1 }
        },
        time = 25
    }
    tech.prerequisites = { "nullius-computation" }
    tech.ignore_tech_tech_cost_multiplier = true
end



data:extend {

    -- Item
    {
        type = 'item',
        name = commons.processor_name,
        icon_size = 64,
        icon = png('item/processor2'),
        icon_mipmaps = 4,
        subgroup = 'circuit-network',
        order = 'p[rocessor]',
        place_result = commons.processor_name,
        stack_size = 50
    }, {
    type = 'item',
    name = commons.processor_name_1x1,
    icon_size = 64,
    icon = png('item/processor_1x1'),
    icon_mipmaps = 4,
    subgroup = 'circuit-network',
    order = 'p[rocessor]-a',
    place_result = commons.processor_name_1x1,
    stack_size = 50
}, {
    type = "item-with-tags",
    name = commons.processor_with_tags,
    icon_size = 64,
    icon = png('item/processor2'),
    icon_mipmaps = 4,
    subgroup = 'circuit-network',
    order = 'p[rocessor]',
    place_result = commons.processor_name,
    stack_size = 1,
    flags = { "not-stackable" }
}, {
    type = 'item',
    name = commons.iopoint_name,
    icon_size = 32,
    icon = png('invisible'),
    subgroup = 'circuit-network',
    order = '[logistic]-b[elt]',
    place_result = commons.iopoint_name,
    stack_size = 50,
    flags = { "hide-from-bonus-gui" }
}, -- Recipes
    recipe1,
    recipe2,
    -- Technology
    tech
}

local base_processor_image = {
    north = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.5
    },
    east = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.5,
        x = 128
    },
    south = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.5,
        x = 256
    },
    west = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.5,
        x = 384
    }
}

local base_processor_image_1x1 = {
    north = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.25
    },
    east = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.25,
        x = 128
    },
    south = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.25,
        x = 256
    },
    west = {
        filename = png("entity/processor4"),
        width = 128,
        height = 128,
        scale = 0.25,
        x = 384
    }
}

local invisible_sprite = {
    count = 1,
    filename = png("invisible"),
    width = 1,
    height = 1,
    direction_count = 1
}

local device = {

    type = "lamp",
    name = commons.device_name,

    icons = { { icon_size = 64, icon = png('item/processor2'), icon_mipmaps = 4 } },
    minable = { mining_time = 0.5, result = commons.processor_name },
    collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    selection_priority = 50,
    picture_on = { layers = { invisible_sprite } },
    picture_off = { layers = { invisible_sprite } },
    always_on = false,
    max_health = 1000,
    collision_mask = { layers={} },
    flags = {
        "hide-alt-info", "not-upgradable", "not-blueprintable",
        "placeable-off-grid"
    },
    energy_usage_per_tick = "1kJ",
    energy_source = { type = "electric", usage_priority = "secondary-input" },
    circuit_wire_connection_point = nil,
    selectable_in_game = false
}

local iopoint_sprite
iopoint_sprite = {
    count = 1,
    filename = png("invisible"),
    width = 1,
    height = 1,
    direction_count = 1
}

local iopoint = {

    type = "lamp",
    name = prefix .. "-iopoint",
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = { layers={} },
    selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    selection_priority = 70,
    minable = nil,
    maximum_wire_distance = 9,
    max_health = 10,
    icon_size = 16,
    icon = png('entity/iopoint'),
    flags = { "placeable-off-grid", "placeable-neutral", "player-creation" },
    circuit_wire_max_distance = 9,

    picture_on = iopoint_sprite,
    picture_off = iopoint_sprite,
    energy_source = { type = "void" },
    energy_usage_per_tick = "1J"
}

local iopoint2
if false then
    local wire_conn = { wire = { red = { 0, 0 }, green = { 0, 0 } }, shadow = { red = { 0, 0 }, green = { 0, 0 } } }
    iopoint2 = {
        type = "constant-combinator",
        name = prefix .. "-iopoint-2",
        collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
        collision_mask = {layers={}},
        selection_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
        selection_priority = 70,
        minable = nil,
        maximum_wire_distance = 9,
        max_health = 10,
        icon_size = 16,
        icon = png('entity/iopoint'),
        flags = { "placeable-off-grid", "placeable-neutral", "player-creation" },
        circuit_wire_max_distance = 9,

        sprites = invisible_sprite,
        activity_led_sprites = invisible_sprite,
        activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
        circuit_wire_connection_points = { wire_conn, wire_conn, wire_conn, wire_conn },
        item_slot_count = 1
    }
end

local energy_source = {

    type = "electric-energy-interface",
    name = prefix .. "-energy_source",
    energy_source = {
        type = "electric",
        render_no_power_icon = true,
        render_no_network_icon = true,
        usage_priority = "tertiary",
        output_flow_limit = "2000MW",
        input_flow_limit = "0MW",
        buffer_capacity = "200MW"
    },
    picture = invisible_sprite,
    energy_production = "2000MW",
    gui_mode = "none",
    flags = { "not-on-map", "hide-alt-info", "not-blueprintable" }
}

local energy_pole = table.deepcopy(
    data.raw["electric-pole"]["medium-electric-pole"])
combinators.merge_table(energy_pole, {
    {
        type = "electric-pole",
        name = prefix .. "-energy_pole",
        draw_copper_wires = false,
        draw_circuit_wires = false,
        supply_area_distance = 64,
        flags = { "not-on-map", "hide-alt-info", "not-blueprintable" }
    }
})

local radar = data.raw["radar"]["radar"]
if radar then
    radar = table.deepcopy(radar)
    radar.name = prefix .. "-radar"
    radar.pictures = invisible_sprite
    data:extend { radar }
end

if not commons.debug_mode then
    energy_pole.pictures = invisible_sprite
    energy_pole.connection_points = { { wire = {}, shadow = {} } }
end

local ground_tile = table.deepcopy(data.raw["tile"]["refined-concrete"])
ground_tile.name = prefix .. "-ground"
ground_tile.minable = nil

local internal_iopoint = table.deepcopy(
    data.raw["electric-pole"]["medium-electric-pole"])

internal_iopoint.name = prefix .. "-internal_iopoint"
internal_iopoint.pictures.layers[1].tint = { 0, 0, 1, 1 }
internal_iopoint.minable = { mining_time = 0.1 }
internal_iopoint.maximum_wire_distance = 64
internal_iopoint.draw_copper_wires = false
internal_iopoint.connection_points[1].wire.copper = nil
internal_iopoint.connection_points[1].shadow.copper = nil
internal_iopoint.flags = { "placeable-neutral", "player-creation" }

local internal_iopoint_item = {
    type = 'item',
    name = prefix .. '-internal_iopoint',
    icons = {
        {
            icon = "__base__/graphics/icons/medium-electric-pole.png",
            icon_size = 64,
            tint = { 0.7, 0.7, 1, 1 }
        }
    },
    subgroup = 'circuit-network',
    order = 'a[miniaturization]-b[internal-iopoint]',
    place_result = prefix .. '-internal_iopoint',
    stack_size = 1,
    flags = { "hide-from-bonus-gui" }
}

---------------------------

local processor = {

    type = "simple-entity-with-owner",
    name = commons.processor_name,

    picture = base_processor_image,
    minable = { mining_time = 1, result = commons.processor_name },
    render_layer = 'floor-mechanics',
    max_health = 250,
    icons = { { icon_size = 64, icon = png('item/processor2'), icon_mipmaps = 4 } },
    collision_box = { { -0.95, -0.95 }, { 0.95, 0.95 } },
    selection_box = { { -1.2, -1.2 }, { 1.2, 1.2 } },
    selection_priority = 60,
    collision_mask = { layers = { ["floor"]=true, ["object"]=true, ["water_tile"]=true } },
    flags = { "placeable-neutral", "player-creation" }
}

---------------------------

local processor_1x1 = {

    type = "simple-entity-with-owner",
    name = commons.processor_name_1x1,
    picture = base_processor_image_1x1,
    minable = { mining_time = 1, result = commons.processor_name_1x1 },
    render_layer = 'floor-mechanics',
    max_health = 250,
    icons = {
        { icon_size = 64, icon = png('item/processor_1x1'), icon_mipmaps = 4 }
    },
    collision_box = { { -0.45, -0.45 }, { 0.45, 0.45 } },
    selection_box = { { -0.6, -0.6 }, { 0.6, 0.6 } },
    selection_priority = 60,
    collision_mask = { layers = { ["floor"]=true, ["object"]=true, ["water_tile"]=true } },
    flags = { "placeable-neutral", "player-creation" }
}

---------------------------

local function add_sprite32(name)
    return {
        type = "sprite",
        name = prefix .. "-" .. name,
        filename = png(name),
        width = 32,
        height = 32
    }
end

local arrow_sprite = add_sprite32("arrow")
local arrowr_sprite = add_sprite32("arrowr")
local arrowd_sprite = add_sprite32("arrowd")
local circle_sprite = add_sprite32("circle")
local add_sprite = add_sprite32("add")

data:extend {
    iopoint, energy_source, energy_pole, internal_iopoint,
    internal_iopoint_item, ground_tile, processor, processor_1x1, device,
    arrow_sprite, arrowr_sprite, arrowd_sprite, circle_sprite, add_sprite
}

---------------------------

local tint = { 1, 1, 1, 1 }

local internal_connector_item = {

    type = 'item',
    name = commons.internal_connector_name,
    icons = { { icon = png("item/iconnector"), icon_size = 64, tint = tint } },
    subgroup = 'circuit-network',
    order = 'a[miniaturization]-b[internal-iopoint]',
    place_result = commons.internal_connector_name,
    stack_size = 1,
    flags = { "hide-from-bonus-gui" }

}

local internal_connector = {
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
    connection_points = {
        {
            shadow = {
                copper = { 0, 0 },
                green = { 1.937, 0.125 },
                red = { 2.359, 0.140 }
            },
            wire = {
                copper = { 0, 0 },
                green = { -0.328, -1.28 },
                red = { 0.343, -1.265 }
            }
        }, {
        shadow = {
            copper = { 0, 0 },
            green = { 2.25, 0.328 },
            red = { 1.718, -0.047 }
        },
        wire = {
            copper = { 0, 0 },
            green = { 0.234, -1.09 },
            red = { -0.234, -1.43 }
        }
    }, {
        shadow = {
            copper = { 0, 0 },
            green = { 1.984, 0.40 },
            red = { 1.984, -0.125 }
        },
        wire = { copper = { 0, 0 }, green = { 0, -1.03 }, red = { 0, -1.51 } }
    }, {
        shadow = {
            copper = { 0, 0 },
            green = { 1.73, 0.31 },
            red = { 2.25, -0.046 }
        },
        wire = {
            copper = { 0, 0 },
            green = { -0.234, -1.105 },
            red = { 0.234, -1.43 }
        }
    }
    },
    activity_led_sprites = invisible_sprite,
    activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
    drawing_box = { { -0.5, -1.5 }, { 0.5, 0.5 } },
    flags = { "placeable-neutral", "player-creation" },
    icon = png("item/iconnector"),
    icon_mipmaps = 4,
    icon_size = 64,
    max_health = 200,
    maximum_wire_distance = 64,
    minable = { mining_time = 0.1, result = commons.internal_connector_name },
    name = commons.internal_connector_name,
    draw_copper_wires = false,
    -- fast_replaceable_group = "electric-pole",
    pictures = {
        layers = {
            {
                direction_count = 4,
                filename = png("entity/iconnector/iconnector"),
                height = 136,
                scale = 0.5,
                priority = "high",
                shift = { 0, -0.484 },
                width = 70,
                tint = tint
            }, {
            direction_count = 4,
            draw_as_shadow = true,
            filename = png("entity/iconnector/iconnector-shadow"),
            height = 52,
            scale = 0.5,
            priority = "high",
            shift = { 0.969, 0.156 },
            width = 186,
            tint = tint
        }
        }
    },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    supply_area_distance = 1,
    type = "electric-pole"
}

data:extend { internal_connector, internal_connector_item }

---------------------------
combinators.create_internals()

data:extend {{
    type = "custom-event",
    name = "on_script_setup_blueprint"
}}


local styles = data.raw["gui-style"].default

styles[commons.prefix .. "_count_label_bottom"] = {
    type = "label_style",
    parent = "count_label",
    height = 28,
    width = 28,
    vertical_align = "bottom",
    horizontal_align = "right",
    right_padding = 2
}
