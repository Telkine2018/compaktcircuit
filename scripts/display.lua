local commons = require("scripts.commons")

local tools = require("scripts.tools")
local Runtime = require("scripts.runtime")
local ccutils = require("scripts.ccutils")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local prefix = commons.prefix
local display_name = commons.display_name

local processor_name = commons.processor_name
local processor_name_1x1 = commons.processor_name_1x1

local frame_name = prefix .. "-display"
local button_prefix = prefix .. "-button"

local function np(name) return prefix .. "-display." .. name end

local display = {}

local multi_signal_h_v = 1
local multi_signal_rh_v = 2
local multi_signal_h_rv = 3
local multi_signal_rh_rv = 4

local multi_signal_v = 5
local multi_signal_v_h = 5
local multi_signal_vh_r = 6
local multi_signal_v_vh = 7
local multi_signal_rv_rh = 8

local multi_square = 9
local multi_square_h_v = 9
local multi_square_rh_v = 10
local multi_square_h_rv = 11
local multi_square_rh_rv = 12

local v_hide = prefix .. "-hide"
local v_freeze = prefix .. "-freeze"
local v_x = prefix .. "-x"
local v_y = prefix .. "-y"
local v_scale = prefix .. "-scale"

local vs_hide = { type = "virtual", name = v_hide }
local vs_freeze = { type = "virtual", name = v_freeze }

---@type Runtime
local display_runtime

display.types = { signal = 1, sprite = 2, text = 3, meta = 4, multi_signal = 5 }
display.sprites = {
    prefix .. "_display_signal",
    prefix .. "_display_sprite",
    prefix .. "_display_text",
    prefix .. "_display_meta",
    prefix .. "_display_multi_signal"
}

local all_colors = {
    ["signal-red"] = { b = 0, g = 0, r = 1 },
    ["signal-yellow"] = { b = 0, g = 1, r = 1 },
    ["signal-green"] = { b = 0, g = 1, r = 0 },
    ["signal-blue"] = { b = 1, g = 0, r = 0 },
    ["signal-pink"] = { b = 1, g = 0, r = 1 },
    ["signal-cyan"] = { b = 1, g = 1, r = 0 },
    ["signal-white"] = { b = 1, g = 1, r = 1 },
    ["signal-black"] = { b = 0, g = 0, r = 0 },
    ["signal-grey"] = { b = 0.3, g = 0.3, r = 0.3 }
}

local all_colors_rgb = {
    { b = 0,   g = 0,   r = 1 },
    { b = 0,   g = 1,   r = 1 },
    { b = 0,   g = 1,   r = 0 },
    { b = 1,   g = 0,   r = 0 },
    { b = 1,   g = 0,   r = 1 },
    { b = 1,   g = 1,   r = 0 },
    { b = 1,   g = 1,   r = 1 },
    { b = 0,   g = 0,   r = 0 },
    { b = 0.3, g = 0.3, r = 0.3 }
}

local all_color_priorities = {
    ["signal-red"] = 1,
    ["signal-yellow"] = 2,
    ["signal-green"] = 3,
    ["signal-blue"] = 4,
    ["signal-pink"] = 5,
    ["signal-cyan"] = 6,
    ["signal-white"] = 7,
    ["signal-black"] = 8,
    ["signal-grey"] = 9
}

display.horizontal_alignments = { "left", "center", "right" }
display.vertical_alignments = { "top", "middle", "baseline", "bottom" }

local display_signal_type = display.types.signal
local display_sprite_type = display.types.sprite
local display_text_type = display.types.text
local display_meta_type = display.types.meta
local display_multi_signal_type = display.types.multi_signal

local meta_input1 = 1
local meta_input2 = 2
local meta_output = 3

---@param value number?
---@return string string?
local function number_to_text(value)
    if not value then return "" end
    return tostring(value)
end

---@param field LuaGuiElement
---@return number?
local function field_to_number(field)
    if not field then return nil end
    local text = field.text
    if not text or text == "" then return nil end
    return tonumber(text)
end

---@param player LuaPlayer
---@return LuaGuiElement
function display.get_frame(player) return player.gui.screen[frame_name] end

---@param rt DisplayRuntime
local function remove_source(rt)
    ---@cast rt SpriteDisplayRuntime
    display_runtime:remove(rt)
    if rt.renderid then rendering.destroy(rt.renderid) end
    if rt.renderids then
        for _, id in pairs(rt.renderids) do rendering.destroy(id) end
    end
end

---@param type integer
---@return SignalDisplay | SpriteDisplay | TextDisplay
function display.create(type)
    if type == display_signal_type then
        return {
            type = display.types.signal,
            scale = 1,
            offsetx = 0,
            offsety = 0,
            orientation = 0,
            halign = 2,
            valign = 2,
            signal = nil
        }
    elseif type == display_sprite_type then
        return {
            type = display.types.sprite,
            scale = 1,
            offsetx = 0,
            offsety = 0,
            orientation = 0
        }
    elseif type == display_text_type then
        return {
            type = display.types.sprite,
            scale = 1,
            offsetx = 0,
            offsety = 0,
            orientation = 0,
            halign = 2,
            valign = 2,
            text = nil
        }
    elseif type == display_meta_type then
        return { type = display.types.meta, location = 1 }
    elseif type == display_multi_signal_type then
        return {
            type = display_multi_signal_type,
            scale = 1,
            offsetx = 0,
            offsety = 0,
            orientation = 0,
            has_background = true,
            background_color = 8

        }
    end
    return {}
end

local right_margin = 10
local field_width = 80

---@param ptable LuaGuiElement
---@param props table
---@param name string
---@param initial_color integer?
---@return LuaGuiElement
local function create_color_field(ptable, props, name, initial_color)
    local label = ptable.add {
        type = "label",
        caption = { np(name) }
    }
    label.style.right_margin = right_margin
    local items = {}
    for color, _ in pairs(all_colors) do
        table.insert(items, "[virtual-signal=" .. color .. "]")
    end
    local field = ptable.add {
        type = "drop-down",
        name = name,
        items = items,
        selected_index = initial_color or 7
    }
    field.style.width = 60
    return field
end

---@param type integer
---@param ptable LuaGuiElement
---@param props table
function display.add_properties(type, ptable, props)
    local label
    local field
    local flow

    if type ~= display_meta_type then
        label = ptable.add { type = "label", caption = { np("internal") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "checkbox",
            name = "internal",
            tooltip = { np("internal-tooltip") },
            state = props.is_internal or false
        }

        label = ptable.add { type = "label", caption = { np("scale") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "scale",
            tooltip = { np("scale-tooltip") },
            numeric = true,
            allow_decimal = true,
            allow_negative = false,
            text = number_to_text(props.scale)
        }
        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("offset") } }
        label.style.right_margin = right_margin
        flow = ptable.add {
            type = "flow",
            direction = "horizontal",
            name = "offset"
        }
        field = flow.add {
            type = "textfield",
            name = "offsetx",
            tooltip = { np("offsetx-tooltip") },
            numeric = true,
            allow_decimal = true,
            allow_negative = true,
            text = number_to_text(props.offsetx)
        }
        field.style.width = field_width
        field = flow.add {
            type = "textfield",
            name = "offsety",
            tooltip = { np("offsety-tooltip") },
            numeric = true,
            allow_decimal = true,
            allow_negative = true,
            text = number_to_text(props.offsety)
        }
        field.style.width = field_width

        if type ~= display_multi_signal_type then
            label = ptable.add { type = "label", caption = { np("orientation") } }
            label.style.right_margin = right_margin
            field = ptable.add {
                type = "textfield",
                name = "orientation",
                tooltip = { np("orientation-tooltip") },
                numeric = true,
                allow_decimal = true,
                allow_negative = true,
                text = number_to_text(props.orientation)
            }
            field.style.width = field_width
        end
    end

    if type == display_signal_type or type == display_text_type then
        label = ptable.add { type = "label", caption = { np("halign") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "drop-down",
            name = "halign",
            tooltip = { np("halign-tooltip") },
            items = {
                { np("halign-left") }, { np("halign-center") }, { np("halign-right") }
            },
            selected_index = props.halign
        }

        label = ptable.add { type = "label", caption = { np("valign") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "drop-down",
            name = "valign",
            tooltip = { np("valign-tooltip") },
            items = {
                { np("valign-top") }, { np("valign-middle") },
                { np("valign-baseline") }, { np("valign-bottom") }
            },
            selected_index = props.valign
        }
    end

    if type == display_signal_type then
        label = ptable.add { type = "label", caption = { np("signal") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "choose-elem-button",
            elem_type = "signal",
            name = "signal"
        }
        if props.signal then
            field.elem_value = tools.sprite_to_signal(props.signal) --[[@as SignalID]]
        end
    end

    if type == display_text_type then
        field = create_color_field(ptable, props, "text-color", props.color)

        label = ptable.add { type = "label", caption = { np("text") } }
        label.style.right_margin = right_margin
        field = ptable.add { type = "text-box", name = "display_text" }
        field.style.width = 400
        field.style.height = 60
        if props.text then field.text = props.text end
    elseif type == display_meta_type then
        label = ptable.add { type = "label", caption = { np("meta-location") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "drop-down",
            name = "meta-location",
            tooltip = { np("meta-location-tooltip") },
            items = {
                { np("meta-input-1") }, { np("meta-input-2") }, { np("meta-output") }
            },
            selected_index = props.location
        }
    elseif type == display_multi_signal_type then
        ---@cast props MultiSignalDisplay

        label = ptable.add { type = "label", caption = { np("multi-signal-mode") } }
        label.style.right_margin = right_margin
        if props.mode and props.mode >= 12 then
            props.mode = 1
        end
        field = ptable.add {
            type = "drop-down",
            name = "multi-signal-mode",
            tooltip = { np("multi-signal-mode-tooltip") },
            items = {
                { np("multi-signal-h-v") }, { np("multi-signal-rh-v") },
                { np("multi-signal-h-rv") }, { np("multi-signal-rh-rv") },
                { np("multi-signal-v-h") }, { np("multi-signal-rv-h") },
                { np("multi-signal-v-rh") }, { np("multi-signal-rv-rh") },
                { np("multi-signal-square-h-v") },
                { np("multi-signal-square-rh-v") },
                { np("multi-signal-square-h-rv") },
                { np("multi-signal-square-rh-rv") }
            },
            selected_index = props.mode or 1
        }

        label = ptable.add {
            type = "label",
            caption = { np("multi-signal-dim-size") }
        }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "multi-signal-dim-size",
            tooltip = { np("multi-signal-dim-size-tooltip") },
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
            text = number_to_text(props.dim_size or 1)
        }
        field.style.width = field_width

        label = ptable.add {
            type = "label",
            caption = { np("multi-signal-col-width") }
        }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "multi-signal-col-width",
            numeric = true,
            allow_decimal = true,
            allow_negative = true,
            text = number_to_text(props.col_width or 2)
        }
        field.style.width = field_width

        label = ptable.add { type = "label", caption = { np("multi-signal-max") } }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "multi-signal-max",
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
            text = number_to_text(props.max or 100)
        }

        field = create_color_field(ptable, props, "multi-signal-color", props.color)

        label = ptable.add {
            type = "label",
            caption = { np("multi-signal-has-frame") }
        }
        label.style.right_margin = right_margin
        if props.has_frame == nil then props.has_frame = true end
        field = ptable.add {
            type = "checkbox",
            name = "multi-signal-has-frame",
            state = props.has_frame
        }
        field.style.width = field_width

        label = ptable.add {
            type = "label",
            caption = { np("multi-signal-has-background") }
        }
        label.style.right_margin = right_margin
        if props.has_background == nil then props.has_background = false end
        field = ptable.add {
            type = "checkbox",
            name = "multi-signal-has-background",
            state = props.has_background
        }
        field.style.width = field_width

        field = create_color_field(ptable, props, "multi-signal-background-color", props.background_color)

        field.style.width = 60
        label = ptable.add {
            type = "label",
            caption = { np("multi-signal-offset") }
        }
        label.style.right_margin = right_margin
        field = ptable.add {
            type = "textfield",
            name = "multi-signal-offset",
            tooltip = { np("multi-signal-offset-tooltip") },
            numeric = true,
            allow_decimal = false,
            allow_negative = true,
            text = number_to_text(props.offset or 0)
        }
        field.style.width = field_width
    end
end

---@param player LuaPlayer
---@param entity LuaEntity
function display.open(player, entity)

    if not entity or not entity.valid or entity.name ~= display_name then
        return
    end

    player.opened = nil
    local vars = get_vars(player)
    if vars.display_entity and vars.display_entity.valid and vars.display_entity == entity then
        return
    end

    ccutils.close_all(player)
    vars.display_entity = entity

    local outer_frame, frame = tools.create_standard_panel(player, {
        panel_name = frame_name,
        title = { np("title") },
        is_draggable = true,
        create_inner_frame = true,
        close_button_name = np("close")
    })

    -- Load previous
    ---@type Display?
    local props
    if global.display_infos then
        local di = global.display_infos[entity.unit_number]
        if di then props = di.props end
    end
    if not props then props = display.create(display_signal_type) end

    local flow, field

    local ttable = frame.add { type = "table", column_count = 2 }
    ttable.style.bottom_cell_padding = 5

    local label = ttable.add { type = "label", caption = { np("type") } }
    label.style.right_margin = right_margin
    field = ttable.add {
        type = "drop-down",
        name = np("display_type"),
        tooltip = { np("type-tooltip") },
        items = {
            { np("type-signal") }, { np("type-sprite") }, { np("type-text") },
            { np("type-meta") }, { np("type-multisignal") }
        },
        selected_index = props.type
    }
    local ftype = field

    local ptable = frame.add { type = "table", column_count = 2, name = "ptable" }
    ptable.style.bottom_cell_padding = 5
    vars.property_table = ptable

    local type = ftype.selected_index
    display.add_properties(type, ptable, props)

    local line = frame.add{type="line"}

    local valid_flow = frame.add{type="flow", direction="horizontal"}
    local empty = valid_flow.add{type="empty-widget"}
    empty.style.horizontally_stretchable = true
    local b = valid_flow.add {
        type = "button",
        caption = { button_prefix .. ".save_and_close" },
        name = np("ok"),
        style = "confirm_button"
    }
    b.style.top_margin = 10
    local edit_location = vars.edit_location
    if edit_location then
        outer_frame.location = edit_location
    else
        outer_frame.force_auto_center()
    end
end

tools.on_gui_click(np("close"), function(e)
    display.close(game.players[e.player_index], true)
end)

tools.on_named_event(np("display_type"),
    defines.events.on_gui_selection_state_changed,
    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        local type = e.element.selected_index
        local props = display.create(type)

        local player = game.players[e.player_index]
        local vars = tools.get_vars(player)
        local property_table = vars.property_table
        property_table.clear()
        display.add_properties(type, property_table, props)
    end)

---@param player LuaPlayer
---@param nosave boolean?
function display.close(player, nosave)
    local frame = display.get_frame(player)
    if frame then
        if not nosave and player.mod_settings[prefix .. "-autosave"].value then
            display.get_edition(player)
        end
        local vars = tools.get_vars(player)
        vars.edit_location = frame.location
        vars.display_entity = nil
        frame.destroy()
    end

    local panel = player.gui.left[frame_name]
    if panel then
        panel.destroy()
    end
end

---@param e EventData.on_gui_opened
local function on_gui_opened(e)
    local player = game.players[e.player_index]
    local entity = e.entity
    display.open(player, entity)
end

function display.get_edition(player)
    local vars = tools.get_vars(player)
    local entity = vars.display_entity
    if not entity or not entity.valid then return end

    local frame = display.get_frame(player)
    local type = tools.get_child(frame, np("display_type")).selected_index
    local ptable = tools.get_child(frame, "ptable")
    ---@cast ptable -nil

    local props = { type = type }

    if type == display_meta_type then
        props.location = ptable["meta-location"].selected_index
    else
        props.scale = field_to_number(ptable["scale"])
        props.is_internal = ptable["internal"].state
        props.offsetx = field_to_number(ptable["offset"]["offsetx"])
        props.offsety = field_to_number(ptable["offset"]["offsety"])
        props.orientation = field_to_number(ptable["orientation"])

        if type == display_signal_type or type == display_text_type then
            props.halign = ptable["halign"].selected_index
            props.valign = ptable["valign"].selected_index
            if type == display_signal_type then
                props.signal = tools.signal_to_sprite(ptable["signal"]
                    .elem_value)
            elseif type == display_text_type then
                props.text = ptable["display_text"].text
                props.color = ptable["text-color"].selected_index
            end
        elseif type == display_multi_signal_type then
            ---@cast props MultiSignalDisplay

            props.mode = ptable["multi-signal-mode"].selected_index
            props.dim_size = field_to_number(ptable["multi-signal-dim-size"])
            props.col_width = field_to_number(ptable["multi-signal-col-width"])
            props.max = field_to_number(ptable["multi-signal-max"])
            props.color = ptable["multi-signal-color"].selected_index
            props.has_frame = ptable["multi-signal-has-frame"].state
            props.has_background = ptable["multi-signal-has-background"].state
            props.background_color = ptable["multi-signal-background-color"].selected_index
            props.offset = field_to_number(ptable["multi-signal-offset"])
        end
    end

    display.register(entity, props)
end

---@param entity LuaEntity
function display.mine(entity)
    if not global.display_infos then return end
    global.display_infos[entity.unit_number] = nil

    for _, player in pairs(game.players) do
        local vars = tools.get_vars(player)
        if vars.display_entity and vars.display_entity.valid and
            vars.display_entity.unit_number == entity.unit_number then
            display.close(player, true)
        end
    end
end

---@param id integer
---@return DisplayInfo?
function display.get(id)
    if not global.display_infos then return nil end
    return global.display_infos[id]
end

---@param entity LuaEntity
---@param props Display
function display.register(entity, props)
    if not global.display_infos then global.display_infos = {} end

    ---@type DisplayInfo
    local display_info = global.display_infos[entity.unit_number]
    if display_info then
        display_info.props = props
    else
        display_info = { entity = entity, props = props, id = entity.unit_number }
        global.display_infos[entity.unit_number] = display_info
    end
    display.set_icon(display_info)
    if display_info.internal then
        remove_source(display_info.internal)
        display_info.internal = nil
    end
    if props.is_internal then
        display_info.internal = display.start(props, entity)
    end
end

---@param display_info DisplayInfo
function display.set_icon(display_info)
    if display_info.typeid then
        rendering.destroy(display_info.typeid)
        display_info.typeid = nil
    end
    if display_info.dataid then
        rendering.destroy(display_info.dataid)
        display_info.dataid = nil
    end
    if display_info.props and display_info.props.type then
        local type = display_info.props.type
        local sprite = display.sprites[type]

        if not sprite then return end

        local scale = 0.5
        display_info.typeid = rendering.draw_sprite {
            sprite = sprite,
            target = display_info.entity,
            surface = display_info.entity.surface,
            only_in_alt_mode = true,
            x_scale = scale,
            y_scale = scale,
            target_offset = { x = 0.5, y = -0.5 }
        }

        if type == display.types.signal then
            local dsignal = display_info.props --[[@as SignalDisplay]]
            if dsignal.signal and ccutils.check_sprite(dsignal.signal) then
                display_info.typeid = rendering.draw_sprite {
                    sprite = dsignal.signal,
                    target = display_info.entity,
                    surface = display_info.entity.surface,
                    only_in_alt_mode = true,
                    x_scale = scale,
                    y_scale = scale,
                    target_offset = { x = 0.5, y = -0.3 }
                }
            end
        end
    end
end

---@param bp LuaItemStack
---@param index integer
---@param entity LuaEntity
function display.set_bp_tags(bp, index, entity)
    local unit_number = entity.unit_number

    local info = display.get(unit_number)
    if info then bp.set_blueprint_entity_tags(index, info.props) end
end

---@param e EventData.on_gui_confirmed
local function on_gui_confirmed(e)
    local player = game.players[e.player_index]
    if not e.element.valid then return end
    if not tools.is_child_of(e.element, frame_name) then return end
    display.get_edition(player)
    display.close(player, true)
end

tools.on_event(defines.events.on_gui_opened, on_gui_opened)
tools.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)
tools.on_gui_click(np("ok"), on_gui_confirmed)

-------------------------------------------------------------------------------

---@param tags Display
---@param source LuaEntity
---@return DisplayRuntime?
function display.start(tags, source)
    if not tags then return nil end

    ---@type TextDisplayRuntime
    local rt = { props = tags, source = source }
    rt.id = source.unit_number
    display_runtime:add(rt)
    display_runtime.boost = true
    return rt
end

---@param rt DisplayRuntime
local function is_source_invalid(rt)
    ---@cast rt SpriteDisplayRuntime
    if not rt.source.valid then
        remove_source(rt)
        return true
    end
    return false
end

---@param rt DisplayRuntime
---@return LuaEntity?
local function find_source(rt)
    if rt.props.is_internal then
        return rt.source
    else
        local rtpos = rt.source.position
        local entities = rt.source.surface.find_entities_filtered {
            name = { processor_name, processor_name_1x1 },
            position = rtpos,
            radius = 1
        }
        if #entities == 0 then return nil end

        for _, p in pairs(entities) do
            if rtpos.x >= p.position.x - p.tile_width / 2 and rtpos.x <=
                p.position.x + p.tile_width / 2 and rtpos.y >= p.position.y -
                p.tile_height / 2 and rtpos.y <= p.position.y +
                p.tile_height / 2 then
                return p
            end
        end
        return nil
    end
end

---@param rt EntityWithIdAndProcess
local function process_signal(rt)
    ---@cast rt SignalDisplayRuntime
    if not rt.source.valid then
        remove_source(rt)
        return
    end

    if rt.hidden then
        if (rt.source.get_merged_signal(vs_hide) == 0) then
            rt.hidden = nil
            rt.value = nil
        else
            return
        end
    end

    if rt.freeze then
        if (rt.source.get_merged_signal(vs_freeze) == 0) then
            rt.freeze = nil
        else
            return
        end
    end

    local props = rt.props --[[@as SignalDisplay]]
    if not rt.renderid then
        local source = find_source(rt)
        if not source or not source.valid then
            display_runtime:remove(rt)
            return
        end

        rt.signal = tools.sprite_to_signal(props.signal)
        if not rt.signal then
            display_runtime:remove(rt)
            return
        end

        rt.renderid = rendering.draw_text {
            text = "",
            use_rich_text = true,
            surface = source.surface,
            target = source,
            target_offset = { x = props.offsetx or 0, y = props.offsety or 0 },
            color = { 1, 1, 1 },
            scale = props.scale or 1,
            forces = { source.force },
            orientation = props.orientation or 0,
            alignment = display.horizontal_alignments[props.halign],
            vertical_alignment = display.vertical_alignments[props.valign]
        }
    end

    local cb = rt.source.get_control_behavior()
    if not cb then return end

    local sname = rt.signal.name
    local signals = rt.source.get_merged_signals()
    local count

    local x, y, scale
    if signals then
        local color, color_priority, color_name

        for _, signal in pairs(signals) do
            local name = signal.signal.name
            if name == v_x then
                x = signal.count
            elseif name == v_y then
                y = signal.count
            elseif name == v_scale then
                scale = signal.count
            elseif name == v_hide then
                rt.hidden = true
                if rt.renderid then
                    rendering.destroy(rt.renderid);
                    rt.renderid = nil
                    return
                end
                return
            elseif name == v_freeze then
                rt.freeze = true
            elseif name == sname then
                count = signal.count
            else
                local c = all_colors[name]
                if c then
                    local cp = all_color_priorities[name]
                    if not color or color_priority > cp then
                        color = c
                        color_priority = cp
                        color_name = name
                    end
                end
            end
        end
        if color and color_name ~= rt.color then
            rt.color = color_name
            rendering.set_color(rt.renderid, color)
        end
    end

    if count then
        if count ~= rt.value then
            rt.value = count
            rendering.set_text(rt.renderid, tostring(count))
        end
    elseif rt.value ~= 0 then
        rendering.set_text(rt.renderid, "0")
        rt.value = 0
    end

    if x ~= rt.x or y ~= rt.y then
        local processor = rendering.get_target(rt.renderid).entity
        rendering.set_target(rt.renderid, processor, {
            x = (props.offsetx or 0) + (x or 0) / 32,
            y = (props.offsety or 0) + (y or 0) / 32
        })
        rt.x = x
        rt.y = y
    end
    if scale ~= rt.scale then
        local real_scale = (props.scale or 1) * ((scale or 100) / 100)
        rendering.set_scale(rt.renderid, real_scale)
        rt.scale = scale
    end
end

---@param rt EntityWithIdAndProcess
local function process_sprite(rt)
    ---@cast rt SpriteDisplayRuntime
    if is_source_invalid(rt) then return end

    if rt.hidden then
        if (rt.source.get_merged_signal(vs_hide) == 0) then
            rt.hidden = nil
            rt.sprite_name = nil
        else
            return
        end
    end

    if rt.freeze then
        if (rt.source.get_merged_signal(vs_freeze) == 0) then
            rt.freeze = nil
        else
            return
        end
    end

    local props = rt.props --[[@as SignalDisplay]]
    if not rt.renderid then
        local source = find_source(rt)
        if not source or not source.valid then
            display_runtime:remove(rt)
            return
        end
        rt.renderid = rendering.draw_sprite {
            sprite = prefix .. "-invisible",
            surface = source.surface,
            target = source,
            target_offset = { x = props.offsetx or 0, y = props.offsety or 0 },
            x_scale = props.scale or 1,
            y_scale = props.scale or 1,
            forces = { source.force },
            orientation = props.orientation or 0
        }
    end

    local cb = rt.source.get_control_behavior()
    if not cb then return end

    local signals = rt.source.get_merged_signals()
    local sname
    local x, y, scale
    if signals then
        local max_signal
        for _, signal in pairs(signals) do
            local pname = signal.signal.name
            if pname == v_x then
                x = signal.count
            elseif pname == v_y then
                y = signal.count
            elseif pname == v_scale then
                scale = signal.count
            elseif pname == v_hide then
                rt.hidden = true
                if rt.renderid then
                    rendering.destroy(rt.renderid)
                    rt.renderid = nil
                end
                return
            elseif pname == v_freeze then
                rt.freeze = true
                return
            elseif not max_signal or max_signal.count < signal.count then
                max_signal = signal
            end
        end
        if max_signal then
            sname = tools.signal_to_sprite(max_signal.signal)
        end
    end
    if not sname then sname = prefix .. "-invisible" end
    if rt.sprite_name ~= sname then
        rendering.set_sprite(rt.renderid, sname)
        rt.sprite_name = sname
    end
    if x ~= rt.x or y ~= rt.y then
        local processor = rendering.get_target(rt.renderid).entity
        rendering.set_target(rt.renderid, processor, {
            x = (props.offsetx or 0) + (x or 0) / 32,
            y = (props.offsety or 0) + (y or 0) / 32
        })
        rt.x = x
        rt.y = y
    end
    if scale ~= rt.scale then
        local real_scale = (props.scale or 1) * ((scale or 100) / 100)
        rendering.set_x_scale(rt.renderid, real_scale)
        rendering.set_y_scale(rt.renderid, real_scale)
        rt.scale = scale
    end
end

---@param rt EntityWithIdAndProcess
local function process_text(rt)
    ---@cast rt TextDisplayRuntime
    if is_source_invalid(rt) then return end

    if rt.hidden then
        if (rt.source.get_merged_signal(vs_hide) == 0) then
            rt.hidden = nil
            rt.text = nil
        else
            return
        end
    end

    if rt.freeze then
        if (rt.source.get_merged_signal(vs_freeze) == 0) then
            rt.freeze = nil
        else
            return
        end
    end

    local function clear()
        if rt.renderid then
            rendering.destroy(rt.renderid)
            rt.renderid = nil
        end
        if rt.renderids then
            for _, id in pairs(rt.renderids) do rendering.destroy(id) end
            rt.renderids = nil
        end
    end

    local props = rt.props --[[@as TextDisplay]]

    local signals = rt.source.get_merged_signals()
    if not signals and rt.text then
        return
    end

    local lines = rt.lines
    local text = props.text
    if rt.text ~= text or not lines then
        if not text then
            clear()
            return
        end

        local startofline, endofline, start
        lines = {}
        start = 1
        while (true) do
            startofline, endofline = string.find(text, "\n", start)
            if startofline then
                local line = string.sub(text, start, startofline - 1)
                table.insert(lines, line)
                start = endofline + 1
            else
                break
            end
        end
        table.insert(lines, string.sub(text, start, #text))
        rt.lines = lines
    end

    local x, y, scale, color_index
    x = props.offsetx or 0
    y = props.offsety or 0
    scale = props.scale or 1
    if signals then
        for _, signal in pairs(signals) do
            local name = signal.signal.name
            if name == v_hide then
                rt.hidden = true
                clear()
                return
            elseif name == v_freeze then
                rt.freeze = true
                return
            elseif name == v_x then
                x = x + (signal.count / 32)
            elseif name == v_y then
                y = y + (signal.count / 32)
            elseif name == v_scale then
                scale = scale * (signal.count / 100)
            else
                local local_color = all_colors[name]
                if local_color then
                    local local_index = all_color_priorities[name]
                    if not color_index or local_index > color_index then
                        color_index = local_index
                    end
                end
            end
        end
    end

    if not color_index then
        color_index = props.color or 7
    end

    if #lines == 1 then
        if not rt.renderid then
            local source = find_source(rt)
            if not source or not source.valid then
                display_runtime:remove(rt)
                return
            end
            rt.renderid = rendering.draw_text {
                text = text,
                surface = source.surface,
                target = source,
                target_offset = { x = x, y = y },
                color = all_colors_rgb[color_index],
                scale = scale,
                forces = { source.force },
                orientation = props.orientation or 0,
                alignment = display.horizontal_alignments[props.halign],
                vertical_alignment = display.vertical_alignments[props.valign],
                use_rich_text = true
            }
        else
            if text ~= rt.text then
                rendering.set_text(rt.renderid, text)
            end
            if x ~= rt.x or y ~= rt.y then
                local processor = rendering.get_target(rt.renderid).entity
                rendering.set_target(rt.renderid, processor, {
                    x = x,
                    y = y
                })
            end
            if scale ~= rt.scale then
                rendering.set_scale(rt.renderid, scale)
            end
            if color_index ~= rt.color_index then
                rendering.set_color(rt.renderid, all_colors_rgb[color_index])
            end
        end
    else -- multi_line
        local change = rt.text ~= text or
            rt.x ~= x or
            rt.y ~= y or
            rt.scale ~= scale or
            rt.color_index ~= color_index

        if not change then return end

        clear()
        local source = find_source(rt)
        if not source or not source.valid then
            display_runtime:remove(rt)
            return
        end

        rt.renderids = {}
        local yc = y
        for i = 1, #lines do
            local renderid = rendering.draw_text {
                text = lines[i],
                surface = source.surface,
                target = source,
                target_offset = { x = x, y = yc },
                color = all_colors_rgb[color_index],
                scale = scale,
                forces = { source.force },
                orientation = props.orientation or 0,
                alignment = display.horizontal_alignments[props.halign],
                vertical_alignment = display.vertical_alignments[props.valign],
                use_rich_text = true
            }
            table.insert(rt.renderids, renderid)
            yc = yc + 0.45 * scale
        end
    end
    rt.text = text
    rt.x = x
    rt.y = y
    rt.scale = scale
    rt.color_index = color_index
end

local meta_radius = 1 / 8.0

local special_signals = ccutils.special_signals

---@param rt EntityWithIdAndProcess
local function process_meta(rt)
    ---@cast rt MetaRuntime+
    if is_source_invalid(rt) then return end

    if rt.hidden then
        if (rt.source.get_merged_signal(vs_hide) == 0) then
            rt.hidden = nil
            rt.signals = nil
        else
            return
        end
    end

    if rt.freeze then
        if (rt.source.get_merged_signal(vs_freeze) == 0) then
            rt.freeze = nil
        else
            return
        end
    end

    local source = rt.source

    local cn = source.get_circuit_network(defines.wire_type.red --[[@as integer]])
    if not cn then return end

    local signals = cn.signals
    if not signals then return end

    local max_signal
    for _, signal in pairs(signals) do
        if not max_signal or max_signal.count < signal.count then
            max_signal = signal
        end
    end

    if not max_signal then return end

    local connected = source.circuit_connected_entities.green
    if not connected or #connected < 1 then return end

    local dst_combinator = connected[1]
    if dst_combinator.type ~= "arithmetic-combinator" and dst_combinator.type ~=
        "decider-combinator" then
        return
    end

    local cb = dst_combinator.get_control_behavior()
    if not cb then return end

    local props = rt.props --[[@as MetaDisplay]]

    ---@cast cb LuaArithmeticCombinatorControlBehavior
    local parameters = cb.parameters

    local location = props.location
    if location == meta_input1 then
        parameters.first_signal = max_signal.signal
        if parameters.output_signal and
            special_signals[parameters.output_signal.name] then
            parameters.output_signal.name = "signal-A"
        end
    elseif location == meta_input2 then
        parameters.second_signal = max_signal.signal
    elseif location == meta_output then
        parameters.output_signal = max_signal.signal
        if parameters.first_signal and parameters.first_signal.name and
            special_signals[parameters.first_signal.name] then
            parameters.first_signal.name = "signal-A"
        end
    end
    cb.parameters = parameters

    rt.signal = tools.signal_to_sprite(max_signal.signal)
end

local multi_signals_delta = {
    { x = 1, y = 1 }, { x = -1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = -1 },

    { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 },

    { x = 1, y = 1 }, { x = -1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = -1 },


}

---@param rt EntityWithIdAndProcess
local function process_multisignal(rt)
    ---@cast rt MultiSignalRuntime

    local function clear()
        if rt.renderids then
            for _, id in pairs(rt.renderids) do rendering.destroy(id) end
            rt.renderids = nil
        end
        rt.signals = nil
    end

    if not rt.source.valid then
        remove_source(rt)
        rt.signals = nil
        return
    end

    if rt.hidden then
        if (rt.source.get_merged_signal(vs_hide) == 0) then
            rt.hidden = nil
            rt.signals = nil
        else
            return
        end
    end

    if rt.freeze then
        if (rt.source.get_merged_signal(vs_freeze) == 0) then
            rt.freeze = nil
        else
            return
        end
    end

    local props = rt.props --[[@as MultiSignalDisplay]]

    local source = rt.processor
    if not source then
        source = find_source(rt)
        if not source or not source.valid then
            display_runtime:remove(rt)
            return
        end
        rt.processor = source
        rt.signals = nil
    elseif not rt.processor.valid then
        display_runtime:remove(rt)
        rt.signals = nil
        return
    end

    local signals = rt.source.get_merged_signals()

    local offsetx, offsety, scale
    offsetx = props.offsetx or 0
    offsety = props.offsety or 0
    scale = props.scale or 1

    if not signals then
        clear()
        return
    end

    if (rt.source.get_merged_signal(vs_freeze) ~= 0) then
        rt.freeze = true
        return
    end

    local max = props.max or 100

    local index = 0
    local line_height = scale * 0.7
    local renderids = nil

    local mode = props.mode or multi_signal_h_v
    if mode < 1 then mode = multi_signal_h_v end
    local colcount
    local color_index = props.color or 1
    local color = all_colors_rgb[color_index]

    local col_width = props.col_width or 2
    local xfirst
    if mode >= multi_square then
        if mode >= multi_square_rh_rv then
            mode = multi_square_rh_rv
        end
        colcount = math.ceil(math.sqrt(math.min(table_size(signals), max)))
        if colcount < 1 then colcount = 1 end
        xfirst = false
    else
        colcount = props.dim_size or 1
        xfirst = mode < multi_signal_v
    end

    local coefs = multi_signals_delta[mode]
    local xd, yd
    xd = col_width * scale
    yd = line_height

    local col = 1
    local x, y = offsetx, offsety
    local count = 1

    if rt.signals then
        if rt.color_index ~= color_index or
            rt.offsetx ~= offsetx or
            rt.offsety ~= offsety or
            rt.colcount ~= colcount or
            rt.max ~= max or
            rt.scale ~= scale or
            rt.xd ~= xd or
            rt.yd ~= yd or
            rt.has_background ~= props.has_background or
            rt.has_frame ~= props.has_frame or
            rt.background_color ~= props.background_color or
            rt.offset ~= props.offset then
            goto not_same
        end

        local count = #rt.signals
        if count ~= #signals then goto not_same end
        if count > max then count = max end
        for i = 1, count do
            if rt.signals[i].count ~= signals[i].count then
                goto not_same
            end
            if rt.signals[i].signal.name ~= signals[i].signal.name then
                goto not_same
            end
        end
        return
    end
    ::not_same::
    clear()
    rt.signals = signals
    rt.color_index = color_index
    rt.offsetx = offsetx
    rt.offsety = offsety
    rt.colcount = colcount
    rt.max = max
    rt.scale = scale
    rt.xd = xd
    rt.yd = yd
    rt.has_frame = props.has_frame

    local signal_count = math.min(max, #signals)
    local linecount = math.ceil(signal_count / colcount)

    renderids = {}
    rt.renderids = renderids

    local has_frame = props.has_frame
    local has_background = props.has_background
    local background_color = props.background_color or 8

    local x1, x2, y1, y2

    local lenx, leny
    local margin = 0.1
    local offset = props.offset or 0

    if xfirst then
        lenx = xd * colcount
        leny = yd * linecount
    else
        lenx = xd * linecount
        leny = yd * colcount
    end
    offsetx = offsetx - (coefs.x < 0 and (lenx + margin) or 0) + (coefs.x > 0 and margin or 0)
    offsety = offsety - (coefs.y < 0 and (leny + margin) or 0) + (coefs.y > 0 and margin or 0)
    x1 = offsetx - margin
    x2 = offsetx + lenx + margin
    y1 = offsety - margin
    y2 = offsety + leny + margin
    x = offsetx
    y = offsety
    xd = math.abs(xd)
    yd = math.abs(yd)

    if has_background then
        local renderid = rendering.draw_rectangle {
            surface = source.surface,
            forces = { source.force },
            left_top = source,
            right_bottom = source,
            left_top_offset = { x = x1, y = y1 },
            right_bottom_offset = { x = x2, y = y2 },
            color = all_colors_rgb[background_color],
            filled = true
        }
        table.insert(renderids, renderid)
    end

    if has_frame then
        local renderid = rendering.draw_rectangle {
            surface = source.surface,
            forces = { source.force },
            left_top = source,
            right_bottom = source,
            left_top_offset = { x = x1, y = y1 },
            right_bottom_offset = { x = x2, y = y2 },
            color = color
        }
        table.insert(renderids, renderid)
    end

    rt.has_frame = has_frame
    rt.has_background = has_background
    rt.background_color = background_color
    rt.offset = offset

    if not xfirst then
        local temp = colcount
        colcount = linecount
        linecount = temp
    end

    for _, signal in pairs(signals) do
        local s = signal.signal
        local sname = signal.signal.name
        if sname == nil then goto skip end
        if sname == v_hide then
            rt.hidden = true
            clear()
            return
        end

        local type = s.type
        if type == "virtual" then type = "virtual-signal" end
        local text = "[" .. type .. "=" .. sname .. "] " ..
            tostring(signal.count - offset)
        local renderid = rendering.draw_text {
            text = text,
            surface = source.surface,
            target = source,
            target_offset = { x = x, y = y },
            color = color,
            scale = scale,
            forces = { source.force },
            orientation = 0,
            alignment = "left",
            vertical_alignment = "top",
            use_rich_text = true,
            draw_on_ground = true
        }
        index = index + 1
        table.insert(renderids, renderid)
        if col >= colcount then
            col = 1
            x = offsetx
            y = y + yd
        else
            x = x + xd
            col = col + 1
        end
        count = count + 1
        if count > max then break end
        ::skip::
    end
end

---@type table<int, fun(DisplayRuntime) >
local process_table = {

    process_signal, process_sprite, process_text, process_meta,
    process_multisignal
}

---@param rt DisplayRuntime
local function process_display(rt)
    if is_source_invalid(rt) then return end

    if rt.id ~= rt.source.unit_number then
        rt.renderid = rt.id
        display_runtime.map[rt.id] = nil
        rt.id = rt.source.unit_number
        display_runtime.map[rt.id] = rt
        display_runtime.currentid = nil
        return
    end

    rt.process = process_table[rt.props.type]
    if not rt.process then
        display_runtime:remove(rt)
        return
    end
    rt.process(rt)
end

--------------------

function display.clone_packed(src, dst)
    local from_rt = display_runtime.map[src.unit_number] --[[@as DisplayRuntime]]
    if not from_rt then return end

    display.start(from_rt.props, dst)
end

--------------------

local function on_load()
    display_runtime = Runtime.get("Display")
    display.reload_config()
end

function display.reload_config()
    display_runtime.config.max_per_tick =
        (settings.global[prefix .. "-entity-per-tick"].value) --[[@as integer]]
    local time = (settings.global[prefix .. "-response-time"].value) --[[@as integer]] -- millis
    display_runtime.config.refresh_rate = time / display_runtime.config.ntick
    display_runtime:update_config()
    display.load_disable_config()
end

tools.on_load(on_load)
tools.on_init(function() on_load() end)

Runtime.register {
    name = "Display",
    global_name = "display_runtime",
    process = process_display,
    refresh_rate = 1,
    max_per_tick = 10
}

tools.on_event(defines.events.on_runtime_mod_setting_changed,
    display.reload_config)

--------------------

---@param e EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(e)
    local src = e.source
    local dst = e.destination
    local player = game.players[e.player_index]

    if not dst or not dst.valid or not src or not src.valid then return end

    if dst.name == display_name and src.name == display_name then
        local si = global.display_infos[src.unit_number]
        if not si or si.props == nil then return end
        display.register(dst, si.props)
    end
end

tools.on_event(defines.events.on_entity_settings_pasted,
    on_entity_settings_pasted)

--------------------

function display.load_disable_config()
    display_runtime.disabled = settings.global[prefix .. "-disable-display"]
        .value --[[@as boolean]]
end

-- #endregion
return display
