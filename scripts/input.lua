local commons = require("scripts.commons")

local tools = require("scripts.tools")
local Runtime = require("scripts.runtime")
local ccutils = require("scripts.ccutils")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local prefix = commons.prefix
local input_name = commons.input_name
local frame_name = prefix .. "-input"

local property_frame_name = prefix .. "-property-input"

local button_prefix = prefix .. "-button"

local function np(name) return prefix .. "-input." .. name end

local check_signal_o = ccutils.check_signal_o

---@type Runtime
local display_runtime

local input = {}

input.types = {
    integer = 1,
    slider = 2,
    toggle = 3,
    drop_down = 4,
    choose_signals = 5,
    choose_signals_with_count = 6
}

input.sprites = {
    prefix .. "_input_integer",
    prefix .. "_input_slider",
    prefix .. "_input_toggle",
    prefix .. "_input_drop_down",
    prefix .. "_input_choose_signals",
    prefix .. "_input_choose_signals_with_count"
}

---@param value number?
---@return string string?
local function number_to_text(value)
    if not value then return "" end
    return tostring(value)
end

---@param text string?
---@return number?
local function text_to_number(text)
    if not text or text == "" then return nil end
    return tonumber(text)
end

function input.get_frame(player) return player.gui.left[frame_name] end

---@param type integer
---@return IntegerInput | SliderInput | ToggleInput | DropDownInput | ChooseSignalsInput | ChooseSignalsWithCountInput
function input.create(type)
    if type == input.types.integer then
        return {
            type = input.types.integer,
            label = '',
            min = nil,
            max = nil,
            width = 60,
            signal = nil,
            default = 0
        }
    elseif type == input.types.slider then
        return {
            type = input.types.sprite,
            label = "",
            min = nil,
            max = nil,
            width = 60,
            signal = nil,
            default = 0
        }
    elseif type == input.types.toggle then
        return { type = input.types.sprite, label = "", signal = nil }
    elseif type == input.types.drop_down then
        return {
            type = input.types.sprite,
            label = "",
            signal = nil,
            labels = nil
        }
    elseif type == input.types.choose_signals then
        return { type = input.types.sprite, label = "", count = 1 }
    elseif type == input.types.choose_signals_with_count then
        return { type = input.types.sprite, label = "", count = 1 }
    end
    return {}
end

local right_margin = 10
local field_width = 80

---@param type integer
---@param ptable LuaGuiElement
---@param props table
function input.add_properties(type, ptable, props)
    local label
    local field
    local flow

    label = ptable.add { type = "label", caption = { np("label") } }
    label.style.right_margin = right_margin
    field = ptable.add {
        type = "textfield",
        name = "input-label",
        tooltip = { np("input-label-tooltip") },
        text = props.label
    }
    field.style.width = 300

    if type == input.types.integer or type == input.types.slider then
        label = ptable.add { type = "label", caption = { np("min") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "input-min",
            tooltip = { np("input-min-tooltip") },
            numeric = true,
            allow_negative = true,
            text = number_to_text(props.min)
        }
        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("max") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "input-max",
            tooltip = { np("input-max-tooltip") },
            numeric = true,
            allow_negative = true,
            text = number_to_text(props.max)
        }
        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("width") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "input-width",
            tooltip = { np("input-width-tooltip") },
            numeric = true,
            allow_negative = false,
            text = number_to_text(props.width)
        }

        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("default_value") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "input-default_value",
            tooltip = { np("default_value-tooltip") },
            numeric = true,
            allow_negative = true,
            text = number_to_text(props.default_value)
        }
        field.style.width = field_width
    end

    if type == input.types.integer or
        type == input.types.slider or
        type == input.types.toggle or
        type == input.types.drop_down then
        label = ptable.add { type = "label", caption = { np("signal") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "choose-elem-button",
            elem_type = "signal",
            name = "input-signal",
            tooltip = { np("signal-tooltip") }
        }
        if props.signal then
            local vsignal = tools.sprite_to_signal(props.signal) --[[@as SignalID]]
            if check_signal_o(vsignal) then
                field.elem_value = vsignal
            end
        end
    end

    if type == input.types.toggle then
        label = ptable.add { type = "label", caption = { np("toggle_count") } }
        label.style.right_margin = right_margin

        field = ptable.add {
            type = "textfield",
            name = "input-count",
            tooltip = { np("toggle_count-tooltip") },
            numeric = true,
            allow_negative = true,
            text = number_to_text(props.count) or 1
        }
        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("toggle-tooltips") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "text-box",
            name = "toggle-tooltips",
            tooltip = { np("toggle-tooltips-tooltip") },
            text = props.tooltips
        }
        field.style.height = 100
    end

    if type == input.types.drop_down then
        label = ptable.add { type = "label", caption = { np("dropdown") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "text-box",
            name = "input-dropdown-labels",
            tooltip = { np("dropdown-labels-tooltip") },
            text = props.labels
        }
        field.style.height = 100
    end

    if type == input.types.choose_signals or type ==
        input.types.choose_signals_with_count then
        label = ptable.add { type = "label", caption = { np("count") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "input-count",
            tooltip = { np("count-tooltip") },
            numeric = true,
            allow_negative = true,
            text = number_to_text(props.count)
        }
        field.style.width = field_width
    end
end

---@param player LuaPlayer
---@param entity LuaEntity
function input.open(player, entity)
    if not entity or not entity.valid or entity.name ~= input_name then
        input.close(player)
        return
    end

    player.opened = nil
    local vars = get_vars(player)

    if vars.input_entity and vars.input_entity.valid and vars.input_entity ==
        entity then
        return
    end

    input.close(player)
    vars.input_entity = entity

    local outer_frame = player.gui.left.add {
        type = "frame",
        direction = "vertical",
        name = frame_name,
        caption = { np("title") }
    }

    local frame = outer_frame.add {
        type = "frame",
        name = "property_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }

    -- Load previous
    ---@type Input?
    local props = input.get(entity.unit_number)

    if not props then props = input.create(input.types.integer) --[[@as Input]] end

    local flow, field

    local ttable = frame.add { type = "table", column_count = 2 }
    ttable.style.bottom_cell_padding = 5

    local label = ttable.add { type = "label", caption = { np("type") } }
    label.style.right_margin = right_margin
    field = ttable.add {
        type = "drop-down",
        name = np("input_type"),
        tooltip = { np("type-tooltip") },
        items = {
            { np("type-integer") }, { np("type-slider") }, { np("type-toggle") },
            { np("type-dropdown") }, { np("type-choose_signals") },
            { np("type-choose_signals_with_count") }
        },
        selected_index = props.type
    }
    local ftype = field

    local ptable = frame.add { type = "table", column_count = 2, name = "ptable" }
    ptable.style.bottom_cell_padding = 5
    vars.property_table = ptable

    local type = ftype.selected_index
    input.add_properties(type, ptable, props)

    local b = frame.add {
        type = "button",
        caption = { button_prefix .. ".save_and_close" },
        name = np("input_ok")
    }
    b.style.top_margin = 10
end

tools.on_named_event(np("input_type"),
    defines.events.on_gui_selection_state_changed,
    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        local type = e.element.selected_index
        local props = input.create(type)

        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)
        local property_table = vars.property_table

        local frame = input.get_frame(player)
        local ptable = tools.get_child(frame, "ptable")
        ---@cast ptable -nil
        props.label = ptable["input-label"].text

        property_table.clear()
        input.add_properties(type, property_table, props)
    end)

---@param player LuaPlayer
function input.close(player)
    local frame = input.get_frame(player)
    if frame then
        local vars = tools.get_vars(player)

        vars.input_entity = nil
        frame.destroy()
    end
end

---@param e EventData.on_gui_opened
local function on_gui_opened(e)
    local player = game.players[e.player_index]
    local entity = e.entity
    input.open(player, entity)
end

local compatible_types = {

    [input.types.integer] = true,
    [input.types.slider] = true,
    [input.types.toggle] = true,
    [input.types.drop_down] = true
}

function input.get_edition(player)
    local vars = tools.get_vars(player)
    local entity = vars.input_entity
    if not entity or not entity.valid then return end

    local frame = input.get_frame(player)
    local type = tools.get_child(frame, np("input_type")).selected_index
    local ptable = tools.get_child(frame, "ptable")
    ---@cast ptable -nil

    local previous = input.get(entity.unit_number)

    ---@type Input
    local props = { type = type }
    if previous and previous.type == type then
        props.value_id = previous.value_id
    elseif previous and compatible_types[previous.type] and
        compatible_types[type] then
        props.value_id = previous.value_id
    else
        props.value_id = tools.get_id()
    end

    props.label = ptable["input-label"].text

    if type == input.types.integer or type == input.types.slider then
        ---@cast props SliderInput
        props.min = text_to_number(ptable["input-min"].text)
        props.max = text_to_number(ptable["input-max"].text)
        props.width = text_to_number(ptable["input-width"].text)
        props.default_value = text_to_number(ptable["input-default_value"].text)
    end

    if type == input.types.integer or type == input.types.slider or type ==
        input.types.drop_down or type == input.types.toggle then
        props.signal = tools.signal_to_sprite(ptable["input-signal"].elem_value)
    end

    if type == input.types.toggle then
        ---@cast props ToggleInput
        props.count = text_to_number(ptable["input-count"].text)
        props.tooltips = ptable["toggle-tooltips"].text
    end

    if type == input.types.drop_down then
        ---@cast props DropDownInput
        props.labels = ptable["input-dropdown-labels"].text
    end

    if type == input.types.choose_signals or type ==
        input.types.choose_signals_with_count then
        props.count = text_to_number(ptable["input-count"].text)
    end

    input.register(entity, props)
end

---@param entity LuaEntity
function input.mine(entity)
    if not global.input_infos then return end
    global.input_infos[entity.unit_number] = nil

    for _, player in pairs(game.players) do
        local vars = tools.get_vars(player)
        if vars.input_entity and vars.input_entity.valid and
            vars.input_entity.unit_number == entity.unit_number then
            input.close(player)
        end
    end
end

---@param id integer
---@return Input?
function input.get(id)
    local input_infos = global.input_infos
    if not input_infos then return nil end
    return input_infos[id]
end

---@param entity LuaEntity
---@param props Input
function input.register(entity, props)
    local input_infos = global.input_infos
    if not input_infos then
        input_infos = {}
        global.input_infos = input_infos
    end
    if not props then
        props = input.create(input.types.integer)
        props.value_id = tools.get_id()
    end
    input_infos[entity.unit_number] = props
    input.set_icon(props, entity)
end

---@param bp LuaItemStack
---@param index integer
---@param entity LuaEntity
function input.set_bp_tags(bp, index, entity)
    local unit_number = entity.unit_number

    local info = input.get(unit_number)
    if info then
        local copy = tools.table_dup(info)
        copy.dataid = nil
        copy.typeid = nil
        bp.set_blueprint_entity_tags(index, copy --[[@as any]])
    end
end

---@param e EventData.on_gui_confirmed
local function on_gui_confirmed(e)
    local player = game.players[e.player_index]
    if not e.element.valid then return end
    if not tools.is_child_of(e.element, frame_name) then return end
    input.get_edition(player)
    input.close(player)
end

tools.on_event(defines.events.on_gui_opened, on_gui_opened)
tools.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)
tools.on_gui_click(np("input_ok"), on_gui_confirmed)

--------------------

---@param info Input?
---@return Input?
function input.copy(info)
    if info == nil then return nil end

    ---@type Input
    local new_info = {}
    for name, value in pairs(info) do new_info[name] = value end
    new_info.value_id = tools.get_id()
    return new_info
end

function input.clone(src, dst)
    local props = input.get(src.unit_number)
    if not props then return end
    input.register(dst, props)
end

--------------------

---@param e EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(e)
    local src = e.source
    local dst = e.destination
    local player = game.players[e.player_index]

    if not dst or not dst.valid or not src or not src.valid then return end
    if dst.name == input_name and src.name == input_name then
        local info = input.get(src.unit_number)
        if info then
            local new_info = input.copy(info)
            global.input_infos[dst.unit_number] = new_info
        end
    end
end

tools.on_event(defines.events.on_entity_settings_pasted,
    on_entity_settings_pasted)

--------------------

---@param value number?
---@return string string?
local function number_to_text(value)
    if not value then return "" end
    return tostring(value)
end

function input.close_property_table(player)
    local frame = player.gui.screen[property_frame_name]
    if frame then frame.destroy() end

    local vars = tools.get_vars(player)
    vars.input_procinfo = nil
    vars.input_map = nil
    vars.input_list = nil
end

local field_prefix = prefix .. "_prefix_"

---@class CreateInputContext
---@field property InputProperty
---@field property_table LuaGuiElement
---@field cb LuaConstantCombinatorControlBehavior
---@field value any

local create_field_table

---@param procinfo ProcInfo
function input.create_unpacked_input_list(procinfo, input_list)
    local surface = procinfo.surface
    if not (surface and surface.valid) then return end

    local inputs = surface.find_entities_filtered { name = input_name }
    if #inputs > 0 then
        for _, entity in pairs(inputs) do
            local pos = entity.position

            ---@type Input?
            local input_info = global.input_infos[entity.unit_number]

            if input_info then
                ---@type InputProperty
                local input_prop = {
                    input = input_info,
                    x = pos.x,
                    y = pos.y,
                    entity = entity,
                    value_id = input_info.value_id --[[@as string]],
                    label = input_info.label --[[@as string]]
                }
                table.insert(input_list, input_prop)
            end
        end
    end

    local inner_processors = surface.find_entities_filtered {
        name = { commons.processor_name, commons.processor_name_1x1 }
    }

    if #inner_processors > 0 then
        for _, processor in pairs(inner_processors) do
            local pos = processor.position

            local inner_procinfo = global.procinfos[processor.unit_number] --[[@as ProcInfo?]]
            if inner_procinfo then
                if inner_procinfo.is_packed then
                    if inner_procinfo.input_list and #inner_procinfo.input_list >
                        0 then
                        ---@type InputProperty
                        local input_prop = {
                            x = pos.x,
                            y = pos.y,
                            value_id = tostring(inner_procinfo.value_id),
                            label = (inner_procinfo.label or
                                inner_procinfo.model) --[[@as string]],
                            inner_inputs = inner_procinfo.input_list
                        }
                        table.insert(input_list, input_prop)
                    end
                end

                local inner_list = {}
                input.create_unpacked_input_list(inner_procinfo, inner_list)
                if #inner_list > 0 then
                    ---@type InputProperty
                    local input_prop = {
                        x = pos.x,
                        y = pos.y,
                        value_id = tostring(inner_procinfo.value_id),
                        label = (inner_procinfo.label or inner_procinfo.model) --[[@as string]],
                        inner_inputs = inner_list
                    }
                    table.insert(input_list, input_prop)
                end
            end
        end
    end
end

---@param player LuaPlayer
---@param procinfo ProcInfo
function input.create_property_table(player, procinfo)
    input.close_property_table(player)

    local input_list = procinfo.input_list
    if not procinfo.is_packed then
        input_list = {}
        input.create_unpacked_input_list(procinfo, input_list)
        input.normalize(input_list, "")
    end

    if not input_list or #input_list == 0 then return end

    local frame = player.gui.screen.add {
        type = "frame",
        direction = 'vertical',
        name = property_frame_name
    }

    local titleflow = frame.add { type = "flow" }
    titleflow.add {
        type = "label",
        caption = procinfo.label or procinfo.model or "",
        style = "frame_title",
        ignored_by_interaction = true
    }
    local drag = titleflow.add {
        type = "empty-widget",
        style = "flib_titlebar_drag_handle"
    }
    drag.drag_target = frame
    titleflow.drag_target = frame
    titleflow.add {
        type = "sprite-button",
        name = prefix .. "-property_close",
        tooltip = { prefix .. "-tooltip.close" },
        style = "frame_action_button",
        mouse_button_filter = { "left" },
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black"
    }

    local inner_frame = frame.add {
        type = "frame",
        name = "property_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }

    local scroll = inner_frame.add {
        type = "scroll-pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll.style.maximal_height = 1024

    local property_table = scroll.add {
        type = "table",
        column_count = 2,
        name = "properties"
    }
    property_table.style.cell_padding = 3

    ---@type table<string, InputProperty>
    local input_map = {}

    ---@type CreateInputContext
    local context = { property_table = property_table }

    local values = procinfo.input_values
    if not values then values = {} end

    ---@param input_list InputProperty[]
    ---@param prefix_labels string[]
    local function create_from_list(input_list, prefix_labels)
        for _, property in pairs(input_list) do
            if property.entity then
                if property.entity.valid then
                    local id = property.gid
                    input_map[id] = property
                    table.insert(prefix_labels, property.label or "")
                    property_table.add { type = "label", caption = prefix_labels }
                    table.remove(prefix_labels)

                    context.property = property
                    context.property_table = property_table
                    context.cb = property.entity.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
                    context.value = values[property.gid]

                    local create = create_field_table[property.input.type]
                    if create then create(context) end
                end
            elseif property.inner_inputs then
                if property.label then
                    table.insert(prefix_labels, property.label or "")
                    table.insert(prefix_labels, " - ")
                end
                create_from_list(property.inner_inputs, prefix_labels)
                if property.label then
                    table.remove(prefix_labels)
                    table.remove(prefix_labels)
                end
            end
        end
    end

    create_from_list(input_list, { "" })

    local button_frame = frame.add {
        type = "frame",
        name = "button_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "horizontal"
    }

    local flow = button_frame.add { type = "flow", direction = "horizontal" }

    local ok_button = flow.add {
        type = "button",
        caption = { prefix .. "-button.save" },
        name = prefix .. "-property_save"
    }

    local vars = tools.get_vars(player)
    flow.add {
        type = "checkbox",
        name = prefix .. "-input.auto_save",
        caption = { prefix .. "-input.auto-save" },
        state = vars.input_auto_save or false,
        tooltip = { prefix .. "-input.auto-save-tooltip" }
    }

    vars.input_procinfo = procinfo
    vars.input_map = input_map
    vars.input_list = input_list
    frame.force_auto_center()

    player.opened = frame
end

---@param e any
---@return LuaPlayer?
---@return table<string, any>?
local function get_context(e)
    ---@cast e EventData.on_gui_text_changed
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    local element = e.element
    if not element or not element.valid then return nil end
    if not tools.is_child_of(element, property_frame_name) then return nil end
    return player, vars
end

---@param e EventData.on_gui_text_changed
function input.auto_save(e)
    local player, vars = get_context(e)
    if not player then return end
    ---@cast vars -nil
    if not vars.input_auto_save then return end
    input.save(player)
end

---@param e EventData.on_gui_value_changed
local function on_gui_value_changed(e)
    local player, vars = get_context(e)
    if not player then return end

    local element = e.element
    if element.tags and element.tags.subtype == "slider" then
        element.parent["textfield"].text = tostring(element.slider_value)
    end
    input.save(player, true)
end

---@param e EventData.on_gui_text_changed
local function on_gui_text_changed(e)
    local player, vars = get_context(e)
    if not player then return end

    local element = e.element
    if element.tags and element.tags.subtype == "textfield" then
        local value = tonumber(element.text)
        if value then
            local slider = element.parent["slider"]
            slider.slider_value = value
        end
    end
    input.save(player, true)
end

tools.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
tools.on_event(defines.events.on_gui_checked_state_changed,
    ---@param e EventData.on_gui_checked_state_changed
    function(e)
        local element = e.element
        if not element or not element.valid then return end
        if element.name == prefix .. "-input.auto_save" then
            local player = game.players[e.player_index]
            local vars = tools.get_vars(player)
            vars.input_auto_save = element.state
        else
            input.auto_save(e --[[@as EventData.on_gui_text_changed]])
        end
    end)

tools.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
tools.on_event(defines.events.on_gui_checked_state_changed, input.auto_save)
tools.on_event(defines.events.on_gui_elem_changed, input.auto_save)
tools.on_event(defines.events.on_gui_selection_state_changed, input.auto_save)

create_field_table = {

    [input.types.integer] = ---@param context CreateInputContext
        function(context)
            local input = context.property.input --[[@as IntegerInput]]
            local field = context.property_table.add {
                type = "textfield",
                name = context.property.gid,
                numeric = true,
                allow_negative = true,
                text = number_to_text(context.value)
            }
            local width = input.width
            if not width or width < 20 then width = 20 end
            field.style.width = width
        end,

    [input.types.slider] = ---@param context CreateInputContext
        function(context)
            local input = context.property.input --[[@as SliderInput]]
            local count = context.value
            local min = input.min
            local max = input.max
            if not min then min = 0 end
            if not max then max = 100 end
            if min >= max then max = min + 1 end

            if not count then
                count = input.default_value
                if not count then count = min end
            else
                if count < min then
                    count = min
                elseif count > max then
                    count = max
                end
            end

            local width = input.width
            if not width or width < 10 then width = 100 end

            local slider_flow = context.property_table.add {
                type = "flow",
                direction = "horizontal",
                name = context.property.gid
            }

            local slider = slider_flow.add {
                type = "slider",
                name = "slider",
                minimum_value = min,
                maximum_value = max,
                value_step = 1,
                value = count,
                tags = { subtype = "slider" }
            }
            slider.style.width = width
            slider.style.top_margin = 10

            local textfield = slider_flow.add {
                type = "textfield",
                name = "textfield",
                text = count and tostring(count) or "",
                tags = { subtype = "textfield" }
            }
            textfield.style.width = field_width
        end,

    [input.types.toggle] = ---@param context CreateInputContext
        function(context)
            local input = context.property.input --[[@as ToggleInput]]
            local flow = context.property_table.add {
                type = "flow",
                direction = "horizontal",
                name = context.property.gid
            }

            local value = context.value
            if not value then value = 0 end
            local mask = 1
            local toggle_count = input.count or 1
            if toggle_count < 0 then
                toggle_count = 1
            elseif toggle_count > 31 then
                toggle_count = 31
            end

            local tooltips = input.tooltips
            local tooltip_items = {}
            if tooltips then
                for tooltip in string.gmatch(tooltips, "[^%c]+") do
                    table.insert(tooltip_items, tooltip)
                end
            end

            for i = 1, toggle_count do
                local bit_value = bit32.band(value, mask)
                flow.add {
                    type = "checkbox",
                    state = (bit_value ~= 0) or false,
                    tooltip = tooltip_items[i]
                }
                mask = 2 * mask
            end
        end,

    [input.types.drop_down] = ---@param context CreateInputContext
        function(context)
            local i = context.property.input --[[@as DropDownInput]]
            local count = context.value

            local items = {}
            for item in string.gmatch(i.labels, "[^%c]+") do
                table.insert(items, item)
            end

            if #items == 0 then
                table.insert(items, { prefix .. "-input.missing_labels" })
            end

            if not count or count <= 0 then
                count = 1
            elseif count > #items then
                count = #items
            end

            local field = context.property_table.add {
                type = "drop-down",
                name = context.property.gid,
                items = items,
                selected_index = count
            }
        end,

    [input.types.choose_signals] = ---@param context CreateInputContext
        function(context)
            local input = context.property.input --[[@as ChooseSignalsInput]]
            local count = input.count or 1
            if count > 32 then
                count = 32
            elseif count < 1 then
                count = 1
            end

            local signal_table = context.property_table.add {
                type = "table",
                column_count = 20,
                name = context.property.gid
            }
            signal_table.style.bottom_cell_padding = 5

            local values = (context.value or {}) --[[@as string[] ]]

            local index = 1
            while index <= count do
                local fsignal = signal_table.add {
                    type = "choose-elem-button",
                    elem_type = "signal"
                }
                if index <= #values then
                    local signal_value = tools.sprite_to_signal(values[index])
                    if signal_value and check_signal_o(signal_value) then
                        fsignal.elem_value = signal_value
                    end
                end
                index = index + 1
            end
        end,

    [input.types.choose_signals_with_count] = ---@param context CreateInputContext
        function(context)
            local input = context.property.input --[[@as ChooseSignalsWithCountInput]]
            local count = input.count or 1
            if count > 32 then
                count = 32
            elseif count < 1 then
                count = 1
            end

            local signal_table = context.property_table.add {
                type = "table",
                column_count = 10,
                name = context.property.gid
            }
            signal_table.style.bottom_cell_padding = 4

            local values = (context.value or {}) --[[ @as {signal:string, count:integer}[] ]]
            local index = 1
            while index <= count do
                local fsignal = signal_table.add {
                    type = "choose-elem-button",
                    elem_type = "signal"
                }

                local fcount = signal_table.add {
                    type = "textfield",
                    numeric = true,
                    allow_negative = true
                }
                fcount.style.width = field_width
                if index <= #values then
                    local signal_value =
                        tools.sprite_to_signal(values[index].signal) --[[@as SignalID]]
                    if signal_value and check_signal_o(signal_value) then
                        fsignal.elem_value = signal_value
                        fcount.text = number_to_text(values[index].count)
                    end
                end
                index = index + 1
            end
        end
}

---@param list InputProperty[]
local function sort_inputs(list)
    if not list or #list == 1 then return end
    table.sort(list, function(e1, e2)
        if (e1.y ~= e2.y) then
            return e1.y < e2.y
        else
            return e1.x < e2.x
        end
    end)
end

---@param input_list InputProperty[]
---@param prefix string ?
function input.normalize(input_list, prefix)
    if not input_list then return end
    sort_inputs(input_list)

    if not prefix then prefix = "" end

    for _, property in pairs(input_list) do
        if property.inner_inputs then
            if property.value_id then
                local gid = prefix .. "_" .. property.value_id
                input.normalize(property.inner_inputs, gid)
            else
                property.inner_inputs = nil
            end
        elseif property.input then
            property.gid = prefix .. "_" .. tostring(property.input.value_id)
        end
    end
end

---@class LoadPropertyContext
---@field property InputProperty
---@field field LuaGuiElement

---@type table<integer, fun(LoadPropertyContext):any>
local load_property_table

---@param player LuaPlayer
function input.load_property_values(player)
    local vars = tools.get_vars(player)
    local input_map = vars.input_map --[[@as table<string, InputProperty>]]
    if not input_map then return end

    local frame = player.gui.screen[property_frame_name]
    if not frame then return end

    local procinfo = vars.input_procinfo --[[@as ProcInfo]]

    local property_table = tools.get_child(frame, "properties")
    if not property_table then return end

    local value_map = {}

    ---@type LoadPropertyContext
    local context = {}

    for id, property in pairs(input_map) do
        context.property = property
        local field = property_table[id]
        context.field = field
        local loader = load_property_table[property.input.type]
        if loader then
            local value = loader(context)
            value_map[id] = value
        end
    end
    procinfo.input_values = value_map
end

load_property_table = {

    [input.types.integer] = ---@param context LoadPropertyContext
        function(context)
            local value = tonumber(context.field.text)
            local input = context.property.input --[[@as IntegerInput]]
            if not value then
                if input.default_value then return input.default_value end
                return value
            end
            if input.min and input.min > value then value = input.min end
            if input.max and input.max < value then value = input.max end
            return value
        end,
    [input.types.slider] = ---@param context LoadPropertyContext
        function(context) return context.field["slider"].slider_value end,
    [input.types.toggle] = ---@param context LoadPropertyContext
        function(context)
            local flow = context.field
            local children = flow.children
            local mask = 1
            local value = 0
            for i = 1, #children do
                if children[i].state then value = value + mask end
                mask = mask * 2
            end
            return value
        end,
    [input.types.drop_down] = ---@param context LoadPropertyContext
        function(context) return context.field.selected_index end,
    [input.types.choose_signals] = ---@param context LoadPropertyContext
        function(context)
            local signals = {}
            for _, child in pairs(context.field.children) do
                local signal = child.elem_value --[[@as SignalID?]]
                if signal then
                    table.insert(signals, tools.signal_to_sprite(signal))
                end
            end
            return signals
        end,
    [input.types.choose_signals_with_count] = ---@param context LoadPropertyContext
        function(context)
            local signals = {}
            local children = context.field.children
            local index = 1
            local children_count = #children
            while index < children_count do
                local fsignal = children[index]
                index = index + 1
                local fcount = children[index]
                index = index + 1
                local signal = fsignal.elem_value --[[@as SignalID?]]
                local count = tonumber(fcount.text)
                if signal and signal.name and count then
                    table.insert(signals, {
                        signal = tools.signal_to_sprite(signal),
                        count = count
                    })
                end
            end
            return signals
        end
}

---@param cb LuaConstantCombinatorControlBehavior
---@param index integer
---@param signal string
---@param value integer?
local function set_signal(cb, index, signal, value)
    if signal and value then
        local signal = tools.sprite_to_signal(signal) --[[@as SignalID]]
        if not ccutils.special_signals[signal.name] and check_signal_o(signal) then
            cb.set_signal(index, { signal = signal, count = value })
        end
    else
        cb.set_signal(index, nil)
    end
end

---@class SetterPropertyContext
---@field property InputProperty
---@field value any
---@field cb LuaConstantCombinatorControlBehavior

---@type table<string, fun(SetterPropertyContext)>
local setter_table

---@param procinfo ProcInfo
---@param input_list InputProperty[]?
function input.set_values(procinfo, input_list)
    if not input_list then
        input_list = procinfo.input_list
        if not input_list or #input_list == 0 then return end
    end

    if not procinfo.input_values then return end

    ---@type SetterPropertyContext
    local context = {}

    for _, property in pairs(input_list) do
        context.property = property
        if property.entity then
            if property.entity.valid then
                context.value = procinfo.input_values[property.gid]
                context.cb = property.entity.get_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
                local setter = setter_table[property.input.type]
                if setter then setter(context) end
            end
        elseif property.inner_inputs then
            input.set_values(procinfo, property.inner_inputs)
        end
    end
end

setter_table = {

    [input.types.integer] = ---@param context SetterPropertyContext
        function(context)
            local input = context.property.input --[[@as IntegerInput]]
            set_signal(context.cb, 1, input.signal, context.value)
        end,
    [input.types.slider] = ---@param context SetterPropertyContext
        function(context)
            local input = context.property.input --[[@as SliderInput]]
            set_signal(context.cb, 1, input.signal, context.value)
        end,
    [input.types.toggle] = ---@param context SetterPropertyContext
        function(context)
            local input = context.property.input --[[@as ToggleInput]]
            set_signal(context.cb, 1, input.signal, context.value)
        end,
    [input.types.drop_down] = ---@param context SetterPropertyContext
        function(context)
            local input = context.property.input --[[@as DropDownInput]]
            set_signal(context.cb, 1, input.signal, context.value)
        end,
    [input.types.choose_signals] = ---@param context SetterPropertyContext
        function(context)
            local signals = context.value --[[@as string[] ]]
            if not signals then return end
            local parameters = {}
            local index = 1
            for _, s in pairs(signals) do
                local signal = tools.sprite_to_signal(s) --[[@as SignalID]]
                if not ccutils.special_signals[signal.name] and
                    check_signal_o(signal) then
                    table.insert(parameters,
                        { count = 1, signal = signal, index = index })
                    index = index + 1
                end
            end
            context.cb.parameters = parameters
        end,
    [input.types.choose_signals_with_count] = ---@param context SetterPropertyContext
        function(context)
            local signals = context.value --[[@as {count:integer, signal:string}[] ]]
            if not signals then return end
            local parameters = {}
            local index = 1
            for _, s in pairs(signals) do
                local signal = tools.sprite_to_signal(s.signal) --[[@as SignalID]]
                if not ccutils.special_signals[signal.name] and
                    check_signal_o(signal) then
                    table.insert(parameters,
                        { count = s.count, signal = signal, index = index })
                    index = index + 1
                end
            end
            context.cb.parameters = parameters
        end
}

---@param player LuaPlayer
---@param check_autosave boolean?
function input.save(player, check_autosave)
    input.load_property_values(player)

    local vars = tools.get_vars(player)
    if check_autosave and not vars.input_auto_save then return end

    local procinfo = vars.input_procinfo --[[@as ProcInfo]]
    local input_list = vars.input_list
    if procinfo then input.set_values(procinfo, input_list) end

    display_runtime.boost = true
end

tools.on_gui_click(prefix .. "-property_close", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        input.close_property_table(player)
    end)

tools.on_gui_click(prefix .. "-property_save", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        input.save(player)
        input.close_property_table(player)
    end)

tools.on_event(defines.events.on_gui_confirmed,
    ---@param e EventData.on_gui_confirmed
    function(e)
        local player = game.players[e.player_index]
        if not e.element or not e.element.valid then return end
        if not tools.is_child_of(e.element, property_frame_name) then return end

        input.save(player)
        input.close_property_table(player)
    end)

tools.on_event(defines.events.on_gui_closed, ---@param e EventData.on_gui_closed
    function(e)
        local player = game.players[e.player_index]
        input.close_property_table(player)
    end)

local function on_load() display_runtime = Runtime.get("Display") end
tools.on_load(on_load)
tools.on_init(function() on_load() end)

---@param procinfo ProcInfo?
function input.apply_parameters(procinfo)
    -- Find top processor
    procinfo = ccutils.get_top_procinfo(procinfo)
    if not procinfo then return end

    if procinfo.is_packed then
        input.set_values(procinfo, procinfo.input_list)
    end

    local input_list = {}
    input.create_unpacked_input_list(procinfo, input_list)
    input.normalize(input_list, "")
    input.set_values(procinfo, input_list)
end

---@param input_info Input
---@param entity LuaEntity
function input.set_icon(input_info, entity)
    if input_info.typeid then
        rendering.destroy(input_info.typeid)
        input_info.typeid = nil
    end
    if input_info.dataid then
        rendering.destroy(input_info.dataid)
        input_info.dataid = nil
    end
    if input_info.type then
        local type = input_info.type
        local sprite = input.sprites[type]

        local scale = 0.5
        input_info.typeid = rendering.draw_sprite {
            sprite = sprite,
            target = entity,
            surface = entity.surface,
            only_in_alt_mode = true,
            x_scale = scale,
            y_scale = scale,
            target_offset = { x = 0.5, y = -0.5 }
        }

        if type <= input.types.drop_down then
            local signal = input_info.signal --[[@as string]]
            if signal then
                local s = tools.sprite_to_signal(signal)
                if check_signal_o(s) then
                    input_info.typeid = rendering.draw_sprite {
                        sprite = signal,
                        target = entity,
                        surface = entity.surface,
                        only_in_alt_mode = true,
                        x_scale = scale,
                        y_scale = scale,
                        target_offset = { x = 0.5, y = -0.3 }
                    }
                end
            end
        end
    end
end

return input
