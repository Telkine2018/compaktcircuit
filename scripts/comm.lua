local luautil = require("__core__/lualib/util")

local commons = require("scripts.commons")
local tools = require("scripts.tools")
local Runtime = require("scripts.runtime")
local commons = require("scripts.commons")

local comm = {}
local max_x = 1000
local min_width = 600
local min_height = 600

local prefix = commons.prefix

local function np(name)
    return prefix .. "-comm." .. name
end

local red_button = prefix .. "_slot_button_red"
local green_button = prefix .. "_slot_button_green"
local label_style_name = prefix .. "_count_label_bottom"


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
        connect_to(router.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
        if not result then
            log("Failed to connect comm")
        end
    end
    if green then
        result = entity.get_wire_connector(defines.wire_connector_id.circuit_green, true).
        connect_to(router.get_wire_connector(defines.wire_connector_id.circuit_green, true), false)
        if not result then
            log("Failed to connect comm")
        end
    end
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
                    connector.disconnect_from(connection.target)
                    break
                end
            end
        end
    end
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
            --[[
                local b
                b = flow.add {
                    type = "button",
                    tooltip = { np("tag_used_tooltip") },
                    caption = { np("tag_used") },
                }
                tools.set_name_handler(b, np("tag_used"))

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

    local search_panel = inner.add { type = "frame", direction = "vertical" }
    search_panel.style.minimal_width = min_width

    local search_flow = search_panel.add { type = "flow", direction = "horizontal" }
    search_flow.add { type = "label", caption = { np("search_name") } }

    comm.purge()
    local channel_names = comm.get_chanel_names(player.force_index)

    local channel_list = search_flow.add {
        type = "drop-down",
        visible = #channel_names > 0,
        items = channel_names,
        name = "channel_name_list" }
    channel_list.style.width = 200
    if #channel_names > 0 then
        channel_list.selected_index = 1
    end

    local add_button = search_flow.add { type = "sprite-button", sprite = commons.prefix .. "-add", name = np("add"), tooltip = { np("add-tooltip") } }
    add_button.style.size = 28

    -- search_flow.add {type=}
    local data_panel = inner.add { type = "frame", direction = "vertical" }
    local scroll = data_panel.add {
        type = "scroll-pane",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto-and-reserve-space",
        name = "channel_scroll"
    }
    scroll.style.minimal_width = min_width
    scroll.style.minimal_height = min_height

    comm.update(player)
end

tools.on_gui_click(np("close"), function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.screen[np("panel")]
    if frame then
        frame.destroy()
    end
end)

tools.on_gui_click(np("add"), function(e)
    local player = game.players[e.player_index]
    local frame = player.gui.screen[np("panel")]
    if not frame then return end

    local channel_name_list = tools.get_child(frame, "channel_name_list")
    if not channel_name_list then return end

    local index = channel_name_list.selected_index
    if not index then return end

    local channel_name = channel_name_list.items[channel_name_list.selected_index]
    local cctx = comm.get_context(player.force_index, false)
    if not cctx then return end

    if not cctx.name_channels[channel_name] then return end

    local vars = tools.get_vars(player)
    local channel_names = vars["comm_selection"] --[[@as string[] ]]

    if not channel_names or e.control then
        channel_names = {}
    else
        for _, n in pairs(channel_names) do
            if n == channel_name then
                return
            end
        end
    end
    table.insert(channel_names, channel_name)
    vars["comm_selection"] = channel_names
    comm.update(player)
end)

---@param player LuaPlayer
function comm.update(player)
    local frame = player.gui.screen[np("panel")]
    if not frame then return end

    cctx = comm.get_context(player.force_index, false)
    if not cctx then return end

    local scroll = tools.get_child(frame, "channel_scroll")
    if not scroll then return end

    scroll.clear()

    local vars = tools.get_vars(player)
    local channel_names = vars["comm_selection"] --[[@as string[] ]]
    if not channel_names then return end

    ---@type LuaGuiElement
    local signal_panel
    local function display(signals, button_style)
        if not signals or #signals == 0 then return end

        table.sort(signals, function(s1, s2) return s1.count > s2.count end)
        local signal_table = signal_panel.add { type = "table", column_count = 12 }

        for i = 1, #signals do
            local signal = signals[i]
            local b = signal_table.add { type = "choose-elem-button", elem_type = "signal" }
            b.elem_value = signal.signal
            b.style = button_style
            b.locked = true

            local qtlabel = b.add { type = "label", style = label_style_name, name = "label", ignored_by_interaction = true }
            qtlabel.caption = luautil.format_number(signal.count, true)
        end
    end

    for _, name in pairs(channel_names) do
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
    local vars = tools.get_vars(player)
    local channel_names = vars["comm_selection"] --[[@as string[] ]]
    if not channel_names then return end

    local remove_chanel = e.element.tags["channel_name"]
    for i = 1, #channel_names do
        if channel_names[i] == remove_chanel then
            table.remove(channel_names, i)
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

return comm
