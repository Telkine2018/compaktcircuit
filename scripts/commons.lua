

local commons = {}

commons.prefix = "compaktcircuit"
local prefix = commons.prefix

commons.processor_name = prefix .. "-processor"
commons.processor_name_1x1 = prefix .. "-processor_1x1"
commons.processor_pattern = "^" .. prefix .. "%-processor"

commons.processor_with_tags = prefix .. "-processor_with_tags"
commons.processor_with_tags_1x1 = prefix .. "-processor_with_tags_1x1"
commons.iopoint_name = prefix .. "-iopoint"
commons.internal_iopoint_name = prefix .. "-internal_iopoint"
commons.internal_connector_name = prefix .. "-internal_connector"
commons.device_name = prefix .. "-device"
commons.display_name = prefix .. "-display"
commons.packed_display_name = prefix .. "-packed-display"
commons.input_name = prefix .. "-input"
commons.packed_input_name = prefix .. "-packed-input"

---@type string[]
commons.packed_entities = {
	prefix .. "-cc",
	prefix .. "-dc",
	prefix .. "-ac",
	prefix .. "-cc2",
	prefix .. "-pole",
	commons.packed_display_name,
	commons.packed_input_name
}

for i = 1, 8 do
	table.insert(commons.packed_entities, prefix .. "-lamp" .. i)
end

commons.entities_to_destroy = {}

function commons.get_color(hexa, default)

	if hexa == nil then return default end
	local value = tonumber(hexa, 16)
	if value == nil then return default end

	local b = math.floor(value % 256 / 255.0)
	local g = ( math.floor(value / 256) % 256 ) / 255.0
	local r = ( math.floor(value / 65536) % 256 ) / 255.0
	local a = 1
	if #hexa == 8 then
		a = (math.floor(value / (65536 * 256) % 256 )) / 255.0
	end
	return { r=r, g=g, b=b, a=a}
end

commons.debug_mode = false

commons.display_all = 0
commons.display_one_line = 1
commons.display_none = 2
commons.boxsize = 0.0001
commons.EDITOR_SIZE = 32

commons.io_red  = 1
commons.io_green  = 2
commons.io_red_and_green  = 3

commons.io_input  = 1
commons.io_output  = 2
commons.io_input_and_output  = 3

return commons