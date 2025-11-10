local luautil = require("__core__/lualib/util")

local commons = require("scripts.commons")
local tools = require("scripts.tools")
local Runtime = require("scripts.runtime")
local commons = require("scripts.commons")

local comm = {}

local max_x = 1000
local min_width = 700
local min_height = 600
local max_height = 800
local saved_slot_max = 12
local data_col_count = 15
local prefix = commons.prefix

local function np(name)
    return prefix .. "-comm." .. name
end

local red_button = prefix .. "_slot_button_red"
local green_button = prefix .. "_slot_button_green"
local yellow_button = prefix .. "_slot_button_yellow"
local default_button = prefix .. "_slot_button_default"
local label_style_name = prefix .. "_count_label_bottom"

---@enum CommSortMode
comm.sort_mode = {
    count_descending = 1,
    count_ascending = 2,
    category = 3
}

---@param force_index integer
---@param create boolean
---@return CommContext?
function comm.get_context(force_index, create)
    local contexts = storage.comm_contexts
    if not contexts then
        if not create then return nil end
        contexts = {}
        storage.comm_contexts = contexts
    end
    local cctx = contexts[force_index] --[[@as CommContext]]
    if cctx then
        return cctx
    end
    if not create then return nil end

    cctx                              = {
        name_channels = {},
        max_index = 0,
    }
    contexts[force_index]             = cctx

    local sname                       = commons.prefix .. "_comm"
    local surface                     = game.create_surface(sname, {
        width = 2 * max_x,
        height = 2,
        default_enable_all_autoplace_controls = false,
        no_enemies_mode = true,
        autoplace_controls = {}
    })
    surface.always_day                = true
    surface.show_clouds               = false
    surface.generate_with_lab_tiles   = true
    surface.freeze_daytime            = true
    surface.ignore_surface_conditions = true
    -- surface.request_to_generate_chunks({ 0, 0 }, max_x)
    -- surface.force_generate_chunk_requests()
    surface.destroy_decoratives({})
    for _, entity in ipairs(surface.find_entities()) do
        if entity.valid and entity.type ~= "character" then
            entity.destroy()
        end
    end
    for _, force in pairs(game.forces) do
        force.set_surface_hidden(surface, true)
    end
    cctx.surface = surface
    return cctx
end

---@param force_index integer
---@param channel_name string
---@return LuaEntity
function comm.get_router(force_index, channel_name)
    local cctx = comm.get_context(force_index, true)
    ---@cast cctx -nil

    local channel = cctx.name_channels[channel_name]
    if not channel then
        local index = cctx.max_index
        cctx.max_index = index + 1
        channel = {
            name = channel_name,
            index = index,
            instances = {}
        }

        local xpos = -max_x / 2 + index + 0.5
        local router = cctx.surface.create_entity { name = "constant-combinator", force = force_index, position = { xpos, 0.5 } }
        channel.router = router
        cctx.name_channels[channel_name] = channel
    end
    return channel.router
end

function comm.purge()
    local contexts = storage.comm_contexts --[[@as {[integer]:CommContext}]]
    if not contexts then return end

    for _, cctx in pairs(contexts) do
        local to_remove = {}
        for _, channel in pairs(cctx.name_channels) do
            local router = channel.router
            local invalid = true
            if router.valid then
                local connectors = router.get_wire_connectors(false)
                for _, connector in pairs(connectors) do
                    if connector.connection_count > 0 then
                        invalid = false
                        break
                    end
                end
            end
            if invalid then
                table.insert(to_remove, channel)
            end
        end
        for _, channel in pairs(to_remove) do
            channel.router.destroy()
            cctx.name_channels[channel.name] = nil
        end
    end
end

---@param force_index integer
---@return string[]
function comm.get_chanel_names(force_index)
    local cctx = comm.get_context(force_index, false)
    if not cctx then return {} end

    local names = {}
    for name, _ in pairs(cctx.name_channels) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

---@param entity LuaEntity
---@param channel_name string
---@param red boolean?
---@param green boolean?
function comm.connect(entity, channel_name, red, green)
    if not red and not green then return end
    if not channel_name or channel_name == "" then return end

    local router = comm.get_router(entity.force_index, channel_name)
    local result
    if red then
        result = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true).
        connect_to(router.get_wire_connector(defines.wire_connector_id.circuit_red, true), false, defines.wire_origin.script)
        if not result then
            log("Failed to connect comm")
        end
    end
    if green then
        result = entity.get_wire_connector(defines.wire_connector_id.circuit_green, true).
        connect_to(router.get_wire_connector(defines.wire_connector_id.circuit_green, true), false, defines.wire_origin.script)
        if not result then
            log("Failed to connect comm")
        end
    end
end

---@return CommConfig?
function comm.new_config()
    local config = {
        channels = {},
        sort_mode = comm.sort_mode.count_descending,
    }
    return config
end

---@param player LuaPlayer
function comm.get_config_current_signal(player)
    local vars = tools.get_vars(player)
    local current_signal = vars["comm_signal_index"]
    if current_signal then
        return current_signal
    end
    current_signal = "signal-A";
    vars["comm_signal_index"] = current_signal
    return current_signal
end

---@param player LuaPlayer
---@param current_signal string
function comm.set_config_current_signal(player, current_signal)
    local vars = tools.get_vars(player)
    vars["comm_signal_index"] = current_signal
end

---@param player LuaPlayer
---@param create boolean
---@return CommConfig?
function comm.get_current_config(player, create)
    local saved_configs = comm.get_configs_by_index(player)
    local current_signal = comm.get_config_current_signal(player)
    local config = saved_configs[current_signal]
    if config or not create then
        return config
    end
    config = comm.new_config()
    saved_configs[current_signal] = config
    return config
end

---@param player LuaPlayer
---@return integer
function comm.get_config_current_index(player)
    local vars = tools.get_vars(player)
    local config_index = vars["comm_config_index"] --[[@as integer? ]]
    if config_index == nil then
        config_index              = 0
        vars["comm_config_index"] = config_index
    end
    return config_index
end

---@param player LuaPlayer
---@param index integer
function comm.set_config_current_index(player, index)
    local vars = tools.get_vars(player)
    vars["comm_config_index"] = index
end

---@param player LuaPlayer
---@return {[integer]:{[string]:CommConfig}}
function comm.get_config_map(player)
    local vars = tools.get_vars(player)
    local config_map = vars["comm_config_map"]
    if not config_map then
        config_map = {}
        vars["comm_config_map"] = config_map
    end
    return config_map
end

---@param player LuaPlayer
---@return {[string]:CommConfig}
function comm.get_configs_by_index(player)
    local index = comm.get_config_current_index(player)
    local config_map = comm.get_config_map(player)
    local configs = config_map[index]
    if not configs then
        configs = {}
        config_map[index] = configs
    end
    return configs
end

---@param entity LuaEntity
function comm.disconnect(entity)
    local cctx = comm.get_context(entity.force_index, false)
    if not cctx then return end

    local connectors = entity.get_wire_connectors(false)
    if connectors then
        local surface_index = cctx.surface.index
        for _, connector in pairs(connectors) do
            local connections = connector.connections
            for _, connection in pairs(connections) do
                if connection.target.owner.surface_index == surface_index then
                    connector.disconnect_from(connection.target, connection.origin)
                    break
                end
            end
        end
    end
end

---@param player LuaPlayer
---@return LuaGuiElement
local function get_frame(player)
    return player.gui.screen[np("panel")]
end

---@param parent LuaGuiElement
---@return LuaGuiElement
local function add_filter_signal_button(parent)
    local b = parent.add { type = "choose-elem-button", elem_type = "signal" }
    b.style.size = 40
    tools.set_name_handler(b, np("filter_signal"))
    return b
end

---@param config_panel LuaGuiElement
local function build_config_panel(config_panel)
    local player = game.players[config_panel.player_index]

    comm.purge()
    local channel_names = comm.get_chanel_names(player.force_index)
    local config = comm.get_current_config(player, true)
    ---@cast config -nil

    -- flow 1
    local search_flow = config_panel.add { type = "flow", direction = "horizontal" }
    search_flow.add { type = "label", caption = { np("search_name") } }

    local channel_list = search_flow.add {
        type = "drop-down",
        visible = #channel_names > 0,
        items = channel_names,
        name = "channel_name_list" }
    channel_list.style.width = 400
    if #channel_names > 0 then
        channel_list.selected_index = 1
    end
    local add_button = search_flow.add { type = "sprite-button",
        sprite = commons.prefix .. "-add", name = np("add"), tooltip = { np("add-tooltip") } }
    add_button.style.size = 28

    -- flow 2
    local config_flow1 = config_panel.add { type = "flow" }
    config_flow1.style.top_margin = 5
    config_flow1.add { type = "label", caption = { np("sort_mode") } }
    local items = { { np("sort_mode.1") }, { np("sort_mode.2") }, { np("sort_mode.3") } }
    config_flow1.add { type = "drop-down", items = items, selected_index = config.sort_mode, name = np("sort_mode") }

    local label = config_flow1.add { type = "label", caption = { np("filter_group") } }
    label.style.left_margin = 10
    local selection_index = 1
    items = { { np("filter_group_all") } }
    local index = 2
    for _, group in pairs(prototypes.item_group) do
        table.insert(items, group.localised_name)
        if group.name == config.group then
            selection_index = index
        end
        index = index + 1
    end
    local dropdown = config_flow1.add { type = "drop-down", items = items, selected_index = selection_index, name = np("filter_group") }
    dropdown.style.width = 200

    -- flow 3
    local line = config_panel.add { type = "line" }
    line.style.bottom_margin = 5
    local config_flow3 = config_panel.add { type = "flow" }
    config_flow3.add { type = "checkbox", caption = { np("apply_filters") }, state = not not config.apply_filters, name = np("apply_filters") }

    local b = config_flow3.add { type = "sprite-button", sprite = prefix .. "-import_filters", 
        tooltip = { np("import_filters-tooltip") }, name = np("import_filters") }
    b.style.size = 24

    local filter_table = config_flow3.add { type = "table", column_count = 10, name = "filter_table" }
    if config.filters then
        for _, filter in pairs(config.filters) do
            local signal = tools.id_to_signal(filter)
            local b = add_filter_signal_button(filter_table)
            b.elem_value = signal
        end
    end
    add_filter_signal_button(filter_table)
end

---@param player LuaPlayer
function comm.open(player)
    ---@type Params.create_standard_panel
    local params = {
        panel_name           = np("panel"),
        title                = { np("title") },
        is_draggable         = true,
        close_button_name    = np("close"),
        close_button_tooltip = { np("close_button_tooltip") },
        create_inner_frame   = true,
        title_menu_func      = function(flow)
            local b
            b = flow.add {
                type = "button",
                tooltip = { np("show_config_tooltip") },
                caption = { np("show_config") },
                name = np("show_config")
            }
            tools.set_name_handler(b, np("show_config"))

            --[[
                b = flow.add {
                    type = "button",
                    tooltip = { np("unselect_tooltip") },
                    caption = { np("unselect") },
                }
                tools.set_name_handler(b, np("unselect"))
                --]]
        end
    }
    local frame, inner = tools.create_standard_panel(player, params)
    frame.auto_center = true

    ----- save panel
    local saved_configs = comm.get_configs_by_index(player)
    local save_config_panel = inner.add { type = "frame", direction = "vertical" }
    local save_flow = save_config_panel.add { type = "flow" }
    save_flow.style.horizontally_stretchable = true
    local default_style = prefix .. "_slot_button_default"
    local items = {}
    for i = 0, 9 do
        table.insert(items, tostring(i))
    end
    local config_index_field = save_flow.add { type = "drop-down", items = items, name = np("config_index_field") }
    config_index_field.style.width = 60
    config_index_field.style.height = 40
    config_index_field.selected_index = comm.get_config_current_index(player) + 1
    config_index_field.tooltip = { np("config_index_field_tooltip") }
    for i = 0, saved_slot_max do
        local b = save_flow.add { type = "choose-elem-button", elem_type = "signal" }
        b.locked = true
        tools.set_name_handler(b, np("saved_slot"))
        local signal_name = "signal-" .. string.char(i + string.byte("A"))
        b.elem_value = {
            type = "virtual",
            name = signal_name
        }
        b.raise_hover_events = true
    end
    comm.update_slot_table(save_flow)

    ------- config panel
    local config_panel = inner.add { type = "frame", direction = "vertical", name = "config_panel" }
    config_panel.style.horizontally_stretchable = true
    build_config_panel(config_panel)

    ------- data panel
    local data_panel = inner.add { type = "frame", direction = "vertical" }
    local scroll = data_panel.add {
        type = "scroll-pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto-and-reserve-space",
        name = "channel_scroll"
    }
    scroll.style.width = min_width
    scroll.style.minimal_height = min_height
    scroll.style.vertically_stretchable = true

    inner.style.height = max_height
    comm.update(player)
end

---@param parent LuaGuiElement
function comm.update_slot_table(parent)
    local player = game.players[parent.player_index]

    ---@cast parent -nil
    local children = parent.children
    local saved_configs = comm.get_configs_by_index(player)
    local current_signal = comm.get_config_current_signal(player)
    for i = 2, #children do
        local b = children[i]
        local signal_name = b.elem_value.name
        if signal_name == current_signal then
            b.style = yellow_button
        elseif saved_configs[signal_name] and table_size(saved_configs[signal_name].channels) ~= 0 then
            b.style = green_button
        else
            b.style = default_button
        end
    end
end

tools.on_gui_click(np("close"), function(e)
    local player = game.players[e.player_index]
    local frame = get_frame(player)
    if frame then
        frame.destroy()
    end
end)

tools.on_gui_click(np("show_config"), function(e)
    local player = game.players[e.player_index]
    local frame = get_frame(player)
    if not frame then return end

    local config_panel = tools.get_child(frame, "config_panel")
    if not config_panel then return end

    config_panel.visible = not config_panel.visible
end)

tools.on_named_event(np("config_index_field"), defines.events.on_gui_selection_state_changed,
    ---@param e  EventData.on_gui_selection_state_changed
    function(e)
        local player = game.players[e.player_index]
        local index = e.element.selected_index

        comm.set_config_current_index(player, index - 1)
        local parent = e.element.parent
        comm.update_slot_table(parent)
        comm.update_config_panel(player)
        comm.update(player)
    end
)

tools.on_gui_click(np("add"),
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local frame = get_frame(player)
        if not frame then return end

        local config = comm.get_current_config(player, true)

        local channel_name_list = tools.get_child(frame, "channel_name_list")
        if not channel_name_list then return end

        local index = channel_name_list.selected_index
        if not index then return end

        local channel_name = channel_name_list.items[channel_name_list.selected_index]
        local cctx = comm.get_context(player.force_index, false)
        if not cctx then return end

        if not cctx.name_channels[channel_name] then return end

        local config = comm.get_current_config(player, true)
        ---@cast config -nil

        if e.control then
            config.channels = {}
        else
            for _, n in pairs(config.channels) do
                if n == channel_name then
                    return
                end
            end
        end
        table.insert(config.channels, channel_name)
        comm.update(player)
    end)


tools.on_named_event(np("filter_signal"), defines.events.on_gui_elem_changed,
    ---@param e EventData.on_gui_elem_changed
    function(e)
        local player = game.players[e.player_index]

        local index = e.element.get_index_in_parent()
        local parent = e.element.parent
        ---@cast parent -nil
        if e.element.elem_value == nil then
            if index ~= #parent.children then
                e.element.destroy()
            end
        elseif index == #parent.children then
            add_filter_signal_button(parent)
        end

        local config = comm.get_current_config(player, true)
        local signals = {}
        for _, child in pairs(parent.children) do
            if child.elem_value then
                local id = tools.signal_to_id(child.elem_value)
                if id then
                    table.insert(signals, id)
                end
            end
        end
        config.filters = signals
        comm.update(player)
    end)

tools.on_named_event(np("apply_filters"), defines.events.on_gui_checked_state_changed,
    ---@param e EventData.on_gui_checked_state_changed
    function(e)
        local player = game.players[e.player_index]
        local config = comm.get_current_config(player, true)
        config.apply_filters = e.element.state
        comm.update(player)
    end
)

tools.on_named_event(np("import_filters"), defines.events.on_gui_click,
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]

        if not script.active_mods["factory_graph"] then
            player.print("Factory graph not active")
            return
        end
        local config = comm.get_current_config(player, true)
        if not config then return end

        local products = remote.call("factory_graph", "get_ingredients", e.player_index)

        local filters = config.filters or {}
        local filter_map = {}
        for _, id in pairs(filters) do
            filter_map[id] = true
        end
        for name, count in pairs(products) do
            filter_map[name] = true
        end
        config.filters = {}
        for name in pairs(filter_map) do
            table.insert(config.filters, name)
        end
        comm.update_config_panel(player)
        comm.update(player)
    end
)

tools.on_named_event(np("saved_slot"), defines.events.on_gui_hover,
    ---@param e EventData.on_gui_hover
    function(e)
        local player = game.players[e.player_index]
        local name = e.element.elem_value.name
        local configs = comm.get_configs_by_index(player)
        local config = configs[name]
        if not config then
            e.element.tooltip = { np("saved_slot_tooltip") }
        else
            local cctx = comm.get_context(player.force_index, true)
            ---@cast cctx -nil
            local channels = { "" }
            for _, channel in pairs(config.channels) do
                if cctx.name_channels[channel] then
                    table.insert(channels, "[color=green]" .. channel .. "[/color]")
                    table.insert(channels, "\n")
                end
            end
            e.element.tooltip = { np("saved_slot_tooltip_arg"), channels }
        end
    end)

tools.on_named_event(np("saved_slot"),
    defines.events.on_gui_click,
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local saved_configs = comm.get_configs_by_index(player)
        if not e.element.valid then return end
        local name = e.element.elem_value.name
        comm.set_config_current_signal(player, name)
        ---@cast name -nil
        if e.control then
            saved_configs[name] = nil
        end
        comm.update_config_panel(player)
        comm.update_slot_table(e.element.parent)
        comm.update(player)
    end)

---@param player LuaPlayer
function comm.update_config_panel(player)
    local frame = get_frame(player)
    local config_panel = tools.get_child(frame, "config_panel")
    ---@cast config_panel -nil
    config_panel.clear()
    build_config_panel(config_panel)
end

---@class CommSortedSignal : Signal
---@field order string

local type_to_proto = {

    item = function(name, quality)
        local q = prototypes.quality[quality]
        return prototypes.item[name], "_a ", "_" .. ((q and q.level) or 0)
    end,
    fluid = function(name) return prototypes.fluid[name], "_b ", "" end,
    virtual = function(name) return prototypes.virtual_signal[name], "_c ", "" end,
    recipe = function(name) return prototypes.recipe[name], "_d ", "" end,
    quality = function(name) return prototypes.quality[name], "_e ", "" end,
    ["space-location"] = function(name) return prototypes.space_location[name], "_f ", "" end,
    ["asteroid-chunk"] = function(name) return prototypes.asteroid_chunk[name], "_g ", "" end,
    ["entity"] = function(name) return prototypes.entity[name], "_h ", "" end,
}

---@type {[string]:string}
local type_to_proto_cache = {}

---@param signals Signal[]
function comm.sort_by_category(signals)
    ---@cast signals CommSortedSignal[]

    for _, signal in pairs(signals) do
        local type = signal.signal.type or "item"
        local name = signal.signal.name
        local quality = signal.signal.quality or "normal"
        local order
        local key = type .. "/" .. name .. "/" .. quality
        order = type_to_proto_cache[key]
        if not order then
            local f = type_to_proto[type]
            if f then
                local proto, prefix, suffix = f(name, quality)
                order = prefix .. proto.group.order .. " " .. proto.subgroup.order .. " " .. proto.order .. suffix
            else
                order = "_z " .. type .. " " .. name
            end
            type_to_proto_cache[key] = order
        end
        signal.order = order
    end

    table.sort(signals, function(s1, s2)
        return s1.order < s2.order
    end)
end

local signal_to_id = tools.signal_to_id

---@param config CommConfig
---@return {[string]:boolean}?
function comm.filter_to_map(config)
    local filter_map
    if config.apply_filters and config.filters and #config.filters > 0 then
        filter_map = {}
        for _, id in pairs(config.filters) do
            filter_map[id] = true
        end
    end
    return filter_map
end

---@param player LuaPlayer
function comm.update(player)
    local frame = get_frame(player)
    if not frame then return end

    local cctx = comm.get_context(player.force_index, false)
    if not cctx then return end

    local scroll = tools.get_child(frame, "channel_scroll")
    if not scroll then return end

    scroll.clear()

    local config = comm.get_current_config(player, false)
    if not config then return end

    ---@type LuaGuiElement
    local signal_panel

    ---@param signals Signal[]?
    ---@param button_style string
    local function display(signals, button_style)
        if not signals or #signals == 0 then return end

        local filter_map = comm.filter_to_map(config)
        if config.group then
            local new_signals = {}
            for _, signal in pairs(signals) do
                local type = signal.signal.type or "item"
                local name = signal.signal.name

                local f = type_to_proto[type]
                if f then
                    local proto = f(name)
                    if proto then
                        if proto.group.name == config.group then
                            if filter_map and not filter_map[signal_to_id(signal.signal)] then
                                goto skip
                            end
                            table.insert(new_signals, signal)
                            ::skip::
                        end
                    end
                end
            end
            signals = new_signals
        elseif filter_map then
            local new_signals = {}
            for _, signal in pairs(signals) do
                if filter_map[signal_to_id(signal.signal)] then
                    table.insert(new_signals, signal)
                end
            end
            signals = new_signals
        end

        -- table.sort(signals, function(s1, s2) return s1.count > s2.count end)
        if config.sort_mode == comm.sort_mode.category then
            comm.sort_by_category(signals)
        elseif config.sort_mode == comm.sort_mode.count_descending then
            table.sort(signals, function(s1, s2) return s2.count < s1.count end)
        else
            table.sort(signals, function(s1, s2) return s1.count < s2.count end)
        end
        local signal_table = signal_panel.add { type = "table", column_count = data_col_count }

        for i = 1, #signals do
            local signal = signals[i]
            local b = signal_table.add { type = "choose-elem-button", elem_type = "signal" }
            b.elem_value = signal.signal
            b.style = button_style
            b.style.size = 40
            b.locked = true
            tools.set_name_handler(b, np("signal"))

            local qtlabel = b.add { type = "label", style = label_style_name, name = "label", ignored_by_interaction = true }
            qtlabel.caption = luautil.format_number(signal.count, true)
        end
    end

    for _, name in pairs(config.channels) do
        local channel = cctx.name_channels[name]
        if channel then
            local router = channel.router
            if router.valid then
                local cb = router.get_control_behavior()
                if cb then
                    signal_panel = scroll.add { type = "flow", direction = "vertical" }

                    local label_flow = signal_panel.add { type = "flow", direction = "horizontal" }
                    label_flow.add { type = "label", caption = name }

                    local filler = label_flow.add {
                        type = "empty-widget"
                    }
                    filler.style.horizontally_stretchable = true
                    local close_button = label_flow.add {
                        type = "sprite-button",
                        style = "frame_action_button",
                        mouse_button_filter = { "left" },
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        name = np("channel_close")
                    }
                    close_button.tags = { channel_name = name }

                    local red_signals = cb.get_circuit_network(defines.wire_connector_id.circuit_red)
                    ---@cast red_signals -nil
                    display(red_signals.signals, red_button)

                    local green_signals = cb.get_circuit_network(defines.wire_connector_id.circuit_green)
                    ---@cast green_signals -nil
                    display(green_signals.signals, green_button)

                    signal_panel.add { type = "line", direction = "horizontal" }
                    signal_panel.style.horizontally_stretchable = true
                end
            end
        end
    end
end

tools.on_gui_click(np("channel_close"), function(e)
    local player = game.players[e.player_index]
    local config = comm.get_current_config(player, false)
    if not config then return end

    local remove_chanel = e.element.tags["channel_name"]
    local channels = config.channels
    for i = 1, #channels do
        if channels[i] == remove_chanel then
            table.remove(channels, i)
            comm.update(player)
            return
        end
    end
end)


local delay = settings.startup[commons.prefix .. "-comm_interval"].value
tools.on_nth_tick(delay, function()
    for _, player in pairs(game.players) do
        comm.update(player)
    end
end)

tools.on_event(defines.events.on_lua_shortcut,
    ---@param e EventData.on_lua_shortcut
    function(e)
        if (e.prototype_name ~= prefix .. "-comm") then return end
        local player = game.players[e.player_index]

        local frame = get_frame(player)
        if not frame then
            comm.open(player)
        else
            frame.destroy()
        end
    end)

tools.on_named_event(np("sort_mode"), defines.events.on_gui_selection_state_changed,

    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        local player = game.players[e.player_index]
        local config = comm.get_current_config(player, true)
        config.sort_mode = e.element.selected_index
        comm.update(player)
    end
)

tools.on_named_event(np("filter_group"), defines.events.on_gui_selection_state_changed,

    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        local player = game.players[e.player_index]
        local config = comm.get_current_config(player, true)
        local index = e.element.selected_index
        config.group = nil
        if index > 1 then
            local i = 2
            for _, group in pairs(prototypes.item_group) do
                if index == i then
                    config.group = group.name
                    break
                end
                i = i + 1
            end
        end
        comm.update(player)
    end
)

tools.on_named_event(np("signal"), defines.events.on_gui_click,
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local config = comm.get_current_config(player, true)
        ---@cast config -nil

        local id = tools.signal_to_id(e.element.elem_value)

        local frame = get_frame(player)
        if not frame then return end

        local filter_table = tools.get_child(frame, "filter_table")
        ---@cast filter_table -nil

        if not config.filters then
            config.filters = {}
        end
        local index = 1
        for _, filter in pairs(config.filters) do
            if filter == id then
                table.remove(config.filters, index)
                filter_table.children[index].destroy()
                return
            end
            index = index + 1
        end
        table.insert(config.filters, id)
        local last = filter_table.children[#filter_table.children]
        last.elem_value = e.element.elem_value
        add_filter_signal_button(filter_table)
        comm.update(player)
    end
)


return comm
