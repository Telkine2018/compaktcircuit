local commons = require("scripts.commons")

local debug_mode = commons.debug_mode
local combinators = {}

local function png(name) return ('__compaktcircuit__/graphics/%s.png'):format(name) end

combinators.png = png

local no_energy = settings.startup[commons.prefix .. "-no_energy" ].value
local boxsize = commons.boxsize

function combinators.merge_table(dst, sources)
	for _, src in pairs(sources) do
		for name, value in pairs(src) do
			dst[name] = value
		end
	end
	return dst
end

local function table_add(t, e)
	for _, s in ipairs(t) do
		if s == e then return end
	end
	table.insert(t, e)
end

local merge_table = combinators.merge_table

local function scale_vect(v, scale)
	return { v[1] * scale, v[2] * scale }
end

local function scale_connector(c, scale)

	if not c then return end
	if c.scale then
		c.scale = scale * c.scale
	end
	if c.shift then
		c.shift = scale_vect(c.shift, scale)
	end
	if c.filename then
		c.filename = png("invisible")
		c.width = 1
		c.height = 1
		c.x = 0
		c.y = 0
	end
end

local function scale_picture(p, scale)

	if not p then return end
	if p.scale then
		p.scale = scale * p.scale
	else
		p.scale = scale
	end
	if p.shift then
		p.shift = scale_vect(p.shift, scale)
	end
end

local lamp_definition = {

	circuit_connector_sprites = {
		blue_led_light_offset = { 0.171875, 0.53125 },
		connector_main = {
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04a-base-sequence.png",
			height = 50, priority = "low", scale = 0.5, width = 52, x = 104, y = 150,
			shift = { 0.140625, 0.265625 }
		},
		connector_shadow = {
			draw_as_shadow = true,
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04b-base-shadow-sequence.png",
			height = 46, priority = "low", scale = 0.5, width = 62, x = 124, y = 138, shift = { 0.1875, 0.3125 }

		},
		led_blue = {
			draw_as_glow = true,
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04e-blue-LED-on-sequence.png",
			height = 60, priority = "low", scale = 0.5, shift = { 0.140625, 0.234375 }, width = 60, x = 120, y = 180
		},
		led_blue_off = {
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04f-blue-LED-off-sequence.png",
			height = 44, priority = "low", scale = 0.5, shift = { 0.140625, 0.234375 }, width = 46, x = 92, y = 132
		},
		led_green = {
			draw_as_glow = true,
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04h-green-LED-sequence.png",
			height = 46, priority = "low", scale = 0.5, shift = { 0.140625, 0.234375 }, width = 48, x = 96, y = 138
		},
		led_light = {
			intensity = 0, size = 0.9
		},
		led_red = {
			draw_as_glow = true,
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04i-red-LED-sequence.png",
			height = 46, priority = "low", scale = 0.5, shift = { 0.140625, 0.234375 }, width = 48, x = 96, y = 138
		},
		red_green_led_light_offset = { 0.15625, 0.421875 },
		wire_pins = {
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04c-wire-sequence.png",
			height = 58, priority = "low", scale = 0.5, shift = { 0.140625, 0.234375 }, width = 62, x = 124, y = 174
		},
		wire_pins_shadow = {
			draw_as_shadow = true,
			filename = "__base__/graphics/entity/circuit-connector/hr-ccm-universal-04d-wire-shadow-sequence.png",
			height = 54, priority = "low", scale = 0.5, shift = { 0.296875, 0.359375 }, width = 70, x = 140, y = 162
		}
	},
	circuit_wire_connection_point = {
		shadow = { green = { 0.546875, 0.609375 }, red = { 0.765625, 0.5625 } },
		wire = { green = { 0.5, 0.515625 }, red = { 0.4375, 0.28125 } },
	},
	circuit_wire_max_distance = 9,
	collision_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
	darkness_for_all_lamps_off = 0.3,
	darkness_for_all_lamps_on = 0.5,
	dying_explosion = "lamp-explosion",
	energy_source = {
		type = "electric",
		usage_priority = "lamp"
	},
	energy_usage_per_tick = "5KW",
	flags = {
		"placeable-neutral",
		"player-creation"
	},
	glow_color_intensity = 1,
	glow_render_mode = "multiplicative",
	glow_size = 3,
	icon = "__base__/graphics/icons/small-lamp.png",
	icon_mipmaps = 4,
	icon_size = 64,
	light = { color = { b = 0.75, g = 1, r = 1 }, intensity = 0.9, size = 40 },
	light_when_colored = {
		color = { b = 0.75, g = 1, r = 1 }, intensity = 0, size = 6
	},
	max_health = 100,
	name = "small-lamp",
	picture_off = {
		layers = {
			{
				axially_symmetrical = false,
				direction_count = 1,
				filename = "__base__/graphics/entity/small-lamp/lamp.png",
				frame_count = 1,
				height = 36,
				hr_version = {
					axially_symmetrical = false,
					direction_count = 1,
					filename = "__base__/graphics/entity/small-lamp/hr-lamp.png",
					frame_count = 1,
					height = 70,
					priority = "high",
					scale = 0.5,
					shift = { 0.0078125, 0.09375 },
					width = 83
				},
				priority = "high",
				shift = { 0, 0.09375 },
				width = 42
			},
			{
				axially_symmetrical = false,
				direction_count = 1,
				draw_as_shadow = true,
				filename = "__base__/graphics/entity/small-lamp/lamp-shadow.png",
				frame_count = 1,
				height = 24,
				hr_version = {
					axially_symmetrical = false,
					direction_count = 1,
					draw_as_shadow = true,
					filename = "__base__/graphics/entity/small-lamp/hr-lamp-shadow.png",
					frame_count = 1,
					height = 47,
					priority = "high",
					scale = 0.5,
					shift = { 0.125, 0.1484375 },
					width = 76
				},
				priority = "high",
				shift = { 0.125, 0.15625 },
				width = 38
			}
		}
	},
	picture_on = {
		axially_symmetrical = false,
		direction_count = 1,
		filename = "__base__/graphics/entity/small-lamp/lamp-light.png",
		frame_count = 1,
		height = 40,
		hr_version = {
			axially_symmetrical = false,
			direction_count = 1,
			filename = "__base__/graphics/entity/small-lamp/hr-lamp-light.png",
			frame_count = 1,
			height = 78,
			priority = "high",
			scale = 0.5,
			shift = { 0, -0.21875 },
			width = 90
		},
		priority = "high",
		shift = { 0, -0.21875 },
		width = 46
	},
	selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
	signal_to_color_mapping = {
		{ color = { b = 0, g = 0, r = 1 },
			name = "signal-red",
			type = "virtual"
		},
		{  color = { b = 0, g = 1, r = 0 },
			name = "signal-green",
			type = "virtual"
		},
		{  color = { b = 1, g = 0, 	r = 0 },
			name = "signal-blue",
			type = "virtual"
		},
		{ color = { b = 0, g = 1, r = 1 },
			name = "signal-yellow",
			type = "virtual"
		}, 
		{  color = {  b = 1, g = 0, r = 1 },
			name = "signal-pink",
			type = "virtual"
		},
		{ color = { b = 1, g = 1, r = 0 },
			name = "signal-cyan",
			type = "virtual"
		},
		{ color = { b = 1, g = 1, r = 1 },
			name = "signal-white",
			type = "virtual"
		}
	},
	type = "lamp"
}


local function scale_lamp(name, scale)

	local lamp = table.deepcopy(lamp_definition)
	local connectors = lamp.circuit_connector_sprites

	connectors.blue_led_light_offset = scale_vect(connectors.blue_led_light_offset, scale)
	connectors.red_green_led_light_offset = scale_vect(connectors.red_green_led_light_offset, scale)
	connectors.led_light.size = scale * connectors.led_light.size

	scale_connector(connectors.connector_main, scale)
	scale_connector(connectors.connector_shadow, scale)
	scale_connector(connectors.led_blue, scale)
	scale_connector(connectors.led_blue_off, scale)
	scale_connector(connectors.led_green, scale)
	scale_connector(connectors.led_red, scale)
	scale_connector(connectors.wire_pins, scale)
	scale_connector(connectors.wire_pins_shadow, scale)

	local points = lamp.circuit_wire_connection_point
	points.shadow.green = scale_vect(points.shadow.green, scale)
	points.shadow.red = scale_vect(points.shadow.red, scale)
	points.wire.green = scale_vect(points.wire.green, scale)
	points.wire.red = scale_vect(points.wire.red, scale)

	scale_picture(lamp.picture_off.layers[1], scale)
	scale_picture(lamp.picture_off.layers[1].hr_version, scale)
	scale_picture(lamp.picture_off.layers[2], scale)
	scale_picture(lamp.picture_off.layers[2].hr_version, scale)
	scale_picture(lamp.picture_on, scale)
	scale_picture(lamp.picture_on.hr_version, scale)

	lamp.flags = { "hide-alt-info", "not-on-map", "not-upgradable", "not-deconstructable", "not-blueprintable",
		"placeable-off-grid", "hidden" }
	lamp.name = name
	lamp.collision_box = { { -boxsize, -boxsize }, { boxsize, boxsize } }
	lamp.collision_mask = {}
	lamp.selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } }
	lamp.selectable_in_game = false
	lamp.draw_circuit_wires = false
	lamp.draw_copper_wires = false
	lamp.energy_usage_per_tick = "10W"
	lamp.glow_size = scale * lamp.glow_size 
	lamp.light.size = 3 * scale
	lamp.light_when_colored.size = 2 * scale
	--lamp.always_on = true
	lamp.picture_off.layers[1].filename = png("entity/lamp/lamp")
	lamp.picture_off.layers[1].hr_version.filename = png("entity/lamp/hr-lamp")
	lamp.energy_source = { type = "void" }

	return lamp
end

function combinators.create_internals()

	local invisible_sprite = { filename = png('invisible'), width = 1, height = 1 }
	local wire_conn = { wire = { red = { 0, 0 }, green = { 0, 0 } }, shadow = { red = { 0, 0 }, green = { 0, 0 } } }
	local commons_attr = {
		flags = { 'placeable-off-grid' },
		collision_mask = {},
		minable = nil,
		selectable_in_game = debug_mode,
		circuit_wire_max_distance = 64,
		sprites = invisible_sprite,
		activity_led_sprites = invisible_sprite,
		activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } },
		circuit_wire_connection_points = { wire_conn, wire_conn, wire_conn, wire_conn },
		draw_circuit_wires = debug_mode,
		collision_box = { { -boxsize, -boxsize }, { boxsize, boxsize } },
		created_smoke = nil,
		selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
		maximum_wire_distance = 2

	}

	local energy_attr

	if no_energy then
		energy_attr = {
			active_energy_usage = "0.01KW",
			energy_source = { type = "void" }
		}
	else
		energy_attr = {
			active_energy_usage = "1KW",
			energy_source = {
				type = "electric",
				usage_priority = "secondary-input",
				render_no_power_icon = false,
				render_no_network_icon = false
			}
		}
	end

	if (debug_mode) then
		commons_attr.selection_priority = 60
	end

	local function insert_flags(flags)

		if not debug_mode then
			table_add(flags, "hidden")
			table_add(flags, "hide-alt-info")
			table_add(flags, "not-on-map")
		end
		--table.insert(flags, "placeable-neutral")
		--table.insert(flags, "placeable-player")
		--table.insert(flags, "player-creation")
		table_add(flags, "not-upgradable")
		table_add(flags, "not-deconstructable")
		table_add(flags, "not-blueprintable")
	end

	--------------------------------------------------------

	local constant_combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
	constant_combinator = merge_table(constant_combinator, { commons_attr, {
		name = commons.prefix .. '-cc',
		item_slot_count = 100
	} })
	insert_flags(constant_combinator.flags)

	--------------------------------------------------------

	local cc2 = table.deepcopy(constant_combinator)
	cc2.name = commons.prefix .. "-cc2"

	--------------------------------------------------------

	local packed_input = table.deepcopy(constant_combinator)
	packed_input.name = commons.packed_input_name

	--------------------------------------------------------

	local arithmetic_combinator = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])
	arithmetic_combinator       = merge_table(arithmetic_combinator, {

		commons_attr, {
			name = commons.prefix .. '-ac',
			and_symbol_sprites = invisible_sprite,
			divide_symbol_sprites = invisible_sprite,
			left_shift_symbol_sprites = invisible_sprite,
			minus_symbol_sprites = invisible_sprite,
			plus_symbol_sprites = invisible_sprite,
			power_symbol_sprites = invisible_sprite,
			multiply_symbol_sprites = invisible_sprite,
			or_symbol_sprites = invisible_sprite,
			right_shift_symbol_sprites = invisible_sprite,
			xor_symbol_sprites = invisible_sprite,
			modulo_symbol_sprites = invisible_sprite
		}, energy_attr
	})
	insert_flags(arithmetic_combinator.flags)

	--------------------------------------------------------

	local decider_combinator = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
	decider_combinator       = merge_table(decider_combinator, { commons_attr, {
		name = commons.prefix .. '-dc',
		equal_symbol_sprites = invisible_sprite,
		greater_or_equal_symbol_sprites = invisible_sprite,
		greater_symbol_sprites = invisible_sprite,
		less_or_equal_symbol_sprites = invisible_sprite,
		less_symbol_sprites = invisible_sprite,
		not_equal_symbol_sprites = invisible_sprite
	}, energy_attr })
	insert_flags(decider_combinator.flags)

	--------------------------------------------------------

	local programmable_speaker = table.deepcopy(data.raw["programmable-speaker"]["programmable-speaker"])
	programmable_speaker       = merge_table(programmable_speaker, { commons_attr, {
		name = commons.prefix .. '-ps',
		sprite = invisible_sprite,
		circuit_connector_sprites = {
			connector_main = invisible_sprite,
			connector_shadow = invisible_sprite,
			wire_pins = invisible_sprite,
			wire_pins_shadow = invisible_sprite,
			led_blue = invisible_sprite,
			led_blue_off = invisible_sprite,
			led_green = invisible_sprite,
			led_red = invisible_sprite,
			led_light = programmable_speaker.circuit_connector_sprites.led_light,
			-- blue_led_light_offset = _____,
			-- red_green_led_light_offset = _____,
		},
	}, energy_attr })
	insert_flags(programmable_speaker.flags)

	--------------------------------------------------------

	local pole = {

		type = "electric-pole",
		name = commons.prefix .. "-pole",
		minable = nil,
		collision_box = { { -boxsize, -boxsize }, { boxsize, boxsize } },
		collision_mask = {},
		selection_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
		draw_copper_wires = debug_mode,
		draw_circuit_wires = debug_mode,
		connection_points = {
			{ wire = { red = { 0, 0 }, green = { 0, 0 } }, shadow = { red = { 0, 0 }, green = { 0, 0 } } }
		},
		selectable_in_game = debug_mode,
		pictures = {
			count = 1,
			filename = png("invisible"),
			width = 1,
			height = 1,
			direction_count = 1
		},
		maximum_wire_distance = 3,
		supply_area_distance = 0.5,
		max_health = 10,
		flags = {
			"placeable-off-grid"
		}
	}
	insert_flags(pole.flags)

	--------------------------------------------------------

	local epole = table.deepcopy(pole)
	epole.name = commons.prefix .. "-epole"
	epole.connection_points = {
		{ wire = { copper = { 0, 0 } }, shadow = { copper = { 0, 0 } } }
	}
	epole.draw_copper_wires = true

	--------------------------------------------------------

	local accu = {

		type = "accumulator",
		name = commons.prefix .. "-accu",
		charge_cooldown = 30,
		discharge_cooldown = 60,
		selectable_in_game = debug_mode,
		energy_source = {
			buffer_capacity = "100KJ",
			input_flow_limit = "20MW",
			output_flow_limit = "20MW",
			type = "electric",
			usage_priority = "tertiary",
			render_no_power_icon = false,
			render_no_network_icon = false
		},
		picture = {
			filename = png("invisible"),
			width = 1,
			height = 1,
			direction_count = 1
		},
		flags = {}
	}
	insert_flags(accu.flags)

	--------------------------------------------------------


	data:extend {
		constant_combinator,
		cc2,
		arithmetic_combinator,
		decider_combinator,
		programmable_speaker,
		packed_input,
		pole,
		epole,
		accu
	}

	local lamp_table = {}
	local scale = 1.0
	for i = 1, 8 do
		local lamp = scale_lamp(commons.prefix .. "-lamp" .. i, scale)
		table.insert(lamp_table, lamp)
		scale = scale / 2.0
	end
	data:extend(lamp_table)
end

-- log(serpent.block(data.raw["lamp"]["small-lamp"]))

return combinators
