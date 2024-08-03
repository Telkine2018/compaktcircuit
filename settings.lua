

local commons = require("scripts.commons")

local prefix = commons.prefix

data:extend(
    {
		{
			type = "bool-setting",
			name = prefix .. "-mine_processor_as_tags",
			setting_type = "runtime-global",
			default_value = false,
			order = "aa"
		},
		{
			type = "bool-setting",
			name = prefix .. "-iopoint_with_alt",
			setting_type = "startup",
			default_value = true,
			order = "ab"
		},
		{
			type = "string-setting",
			name = prefix .. "-iopoint_default_color",
			setting_type = "startup",
			default_value = "00FF00",
			order = "color1"
		},
		{
			type = "string-setting",
			name = prefix .. "-iopoint_connected_color",
			setting_type = "startup",
			default_value = "FF0000",
			order = "color2"
		},
		{
			type = "string-setting",
			name = prefix .. "-iopoint_disconnected_color",
			setting_type = "startup",
			default_value = "FFFF00",
			order = "color3"
		},
		{
			type = "string-setting",
			name = prefix .. "-iopoint_color",
			setting_type = "startup",
			default_value = "0000FF",
			order = "color4"
		},
		{
			type = "string-setting",
			name = prefix .. "-iopoint_text_color",
			setting_type = "startup",
			default_value = "0000FF",
			order = "color5"
		},
		{
			type = "bool-setting",
			name = prefix .. "-no_energy",
			setting_type = "startup",
			default_value = false,
			order = "da"
		},
		{
			type = "bool-setting",
			name = prefix .. "-show-iopoint-name",
			setting_type = "runtime-per-user",
			default_value = true,
			order = "ea"
		},
		{
			type = "int-setting",
			name = prefix .. "-entity-per-tick",
			setting_type = "runtime-global",
			default_value = 50,
			minimum_value = 1,
			order = "ga"
		},
		{
			type = "int-setting",
			name = prefix .. "-response-time",
			setting_type = "runtime-global",
			default_value = 20,
			minimum_value = 10,
			order = "ha"
		},
		{
			type = "bool-setting",
			name = prefix .. "-disable-display",
			setting_type = "runtime-global",
			default_value = false,
			order="ia"
		},
		{
			type = "bool-setting",
			name = prefix .. "-no_processor_in_build",
			setting_type = "startup",
			default_value = false,
			order = "ja"
		},
		{
			type = "bool-setting",
			name = prefix .. "-autosave",
			setting_type = "runtime-per-user",
			default_value = true,
			order = "ka"
		},
		{
			type = "bool-setting",
			name = prefix .. "-allow-external",
			setting_type = "runtime-global",
			default_value = false,
			order="la"
		},

})
