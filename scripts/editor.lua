local commons = require("scripts.commons")

local prefix = commons.prefix
local ccutils = require("scripts.ccutils")
local tools = require("scripts.tools")
local display = require("scripts.display")
local input = require("scripts.input")
local build = require("scripts.build")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local EDITOR_SIZE = commons.EDITOR_SIZE
local internal_iopoint_name = commons.internal_iopoint_name
local internal_connector_name = commons.internal_connector_name
local display_name = commons.display_name
local input_name = commons.input_name

local allowed_name_map = build.allowed_name_map
local remote_name_map = build.remote_name_map
local textplate_map = build.textplate_map

local editor = {}
local button_prefix = prefix .. "-button"
local label_prefix = prefix .. "-label"
local checkbox_prefix = prefix .. "-checkbox"
local message_prefix = prefix .. "-message"
local tooltip_prefix = prefix .. "-tooltip"
local iopanel_name = prefix .. "-iopole_panel"

-- Chosen slightly at random; I tried to pick a value that looked okay w/ a small-ish game-window ...
local editor_remote_zoom = 1.0

---@param player LuaPlayer
---@return boolean
function editor.close_editor_panel(player)
    ---@type LuaGuiElement
    local b = player.gui.left[prefix .. "-intern_panel"]
    if b then
        b.destroy()
        return true
    end
    return false
end

local get_procinfo = build.get_procinfo
editor.get_proc_info = build.get_procinfo

---@param processor LuaEntity
---@return string
function editor.get_surface_name(processor)
    return "proc_" .. processor.unit_number
end

---@param name string
---@return string?
local function is_allowed(name)
    local packed_name = allowed_name_map[name]
    if packed_name then return packed_name end
    if textplate_map[name] then return name end
    if remote_name_map[name] then return name end
    return nil
end

local internal_panel_name = commons.internal_panel_name

---@param player LuaPlayer
---@param procinfo ProcInfo
function editor.create_editor_panel(player, procinfo)
    ccutils.close_all(player)
    editor.close_editor_panel(player)

    local outer_frame = player.gui.left.add {
        type = "frame",
        direction = "vertical",
        name = internal_panel_name,
        caption = { prefix .. ".main-title" }
    }

    local frame = outer_frame.add {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }

    local top_flow = frame.add { type = "flow", direction = "horizontal" }
    local b = top_flow.add {
        type = "button",
        caption = { button_prefix .. ".models" },
        name = prefix .. "-models",
        tooltip = { tooltip_prefix .. ".models" }
    }
    b.style.width = 160

    local add_flow = frame.add {
        type = "flow",
        direction = "horizontal"
    }
    local label = add_flow.add {
        type = "label",
        caption = { prefix .. ".add_component_label" }
    }
    label.style.top_margin = 10

    b = add_flow.add {
        type = "sprite-button",
        tooltip = { tooltip_prefix .. ".add_iopole" },
        name = prefix .. "-add_iopole",
        sprite = "item/" .. commons.internal_iopoint_name
    }
    b = add_flow.add {
        type = "sprite-button",
        tooltip = { tooltip_prefix .. ".add__internal_connector" },
        name = prefix .. "-add_internal_connector",
        sprite = "item/" .. internal_connector_name
    }
    b = add_flow.add {
        type = "sprite-button",
        tooltip = { tooltip_prefix .. ".add_display" },
        name = prefix .. "-add_display",
        sprite = "item/" .. display_name
    }
    b = add_flow.add {
        type = "sprite-button",
        tooltip = { tooltip_prefix .. ".add_input" },
        name = prefix .. "-add_input",
        sprite = "item/" .. commons.input_name
    }

    local info_flow = frame.add {
        type = "flow",
        direction = "horizontal",
        name = "info_flow"
    }
    b = info_flow.add {
        type = "checkbox",
        state = procinfo.is_packed or false,
        caption = { prefix .. "-parameters.is_packed" },
        tooltip = { tooltip_prefix .. ".is_packed" },
        name = prefix .. "-is_packed"
    }
    b.style.right_margin = 10
    b.style.top_margin = 10
    b = info_flow.add {
        type = "choose-elem-button",
        tooltip = { tooltip_prefix .. ".sprite1" },
        name = prefix .. "-sprite1",
        elem_type = "signal",
        signal = ccutils.translate_signal(tools.sprite_to_signal(procinfo.sprite1))
    }
    b = info_flow.add {
        type = "choose-elem-button",
        tooltip = { tooltip_prefix .. ".sprite2" },
        name = prefix .. "-sprite2",
        elem_type = "signal",
        signal = ccutils.translate_signal(tools.sprite_to_signal(procinfo.sprite2))
    }

    local title_flow = frame.add {
        type = "flow",
        direction = "horizontal"
    }
    title_flow.style.top_margin = 5
    local label = title_flow.add {
        type = "label",
        caption = { prefix .. ".title_label" }
    }
    local ftitle = title_flow.add {
        type = "textfield",
        name = prefix .. "-title",
        text = procinfo.label or "",
        tooltip = { prefix .. "-tooltip.title" },
        icon_selector = true
    }
    ftitle.style.width = 300
end

-----------------------------------------------------------------

tools.on_event(defines.events.on_gui_elem_changed,
    ---@param e EventData.on_gui_elem_changed
    function(e)
        local player = game.players[e.player_index]
        local name
        if not e.element.valid then return end
        if e.element.name == prefix .. "-sprite1" then
            name = "sprite1"
        elseif e.element.name == prefix .. "-sprite2" then
            name = "sprite2"
        else
            return
        end

        local procinfo = storage.surface_map[player.surface.name]
        if not procinfo then return end
        procinfo[name] = tools.signal_to_sprite(e.element.elem_value --[[@as SignalID]])
        editor.draw_sprite(procinfo)
    end)

-----------------------------------------------------------------

-- Controller types supported for processor entry
-- https://lua-api.factorio.com/latest/defines.html#defines.controllers
local allow_controller_types = {
    [defines.controllers.character] = true,
    [defines.controllers.remote] = true,
    [defines.controllers.editor] = true,
    [defines.controllers.god] = true,
    [defines.controllers.spectator] = true
}

local controller_names = {}
for name, value in pairs(defines.controllers) do
    if type(value) == "number" then
        controller_names[value] = name
    end
end

---@param player LuaPlayer
---@return string?
local function get_processor_entry_block_reason(player)
    if not allow_controller_types[player.controller_type] then
        return "controller is unsupported"
    end

    if player.controller_type ~= defines.controllers.remote then
        return nil
    end

    if not allow_controller_types[player.physical_controller_type] then
        return "remote view backing controller is unsupported"
    end

    return nil
end

---@param player LuaPlayer
---@param processor LuaEntity
function editor.edit_selected(player, processor)
    if storage.last_click and storage.last_click > game.tick - 120 then
        debug("edit_selected: ignored bounce click player=" .. player.index)
        return
    end
    storage.last_click = game.tick

    local blocked_reason = get_processor_entry_block_reason(player)
    if blocked_reason then
        debug("edit_selected: blocked unsafe entry player=" .. player.index ..
            " controller=" .. tostring(player.controller_type) ..
            " physical_controller=" .. tostring(player.physical_controller_type) ..
            " physical_surface=" .. tostring(player.physical_surface_index) ..
            " reason=" .. blocked_reason)
        player.print("CompaktCircuits: unsafe processor entry blocked from " ..
            (controller_names[player.controller_type] or tostring(player.controller_type)) ..
            " (" .. blocked_reason .. ").")
        return
    end

    if not processor or not processor.valid then
        debug("edit_selected: invalid processor player=" .. player.index)
        return
    end

    local procinfo = get_procinfo(processor, true)
    ---@cast procinfo -nil
    local vars = get_vars(player)
    vars.procinfo = procinfo
    vars.processor = processor
    local surface = editor.get_or_create_surface(procinfo)

    editor.hide_surface_list(player, "edit_selected")

    if procinfo.is_packed then
        build.restore_packed_circuits(procinfo)
        input.apply_parameters(procinfo)
        input.disconnect_comms(surface)
    end

    procinfo.origin_surface_name = player.surface.name
    procinfo.origin_surface_position = player.position
    procinfo.origin_controller_type = player.controller_type
    procinfo.physical_surface_index = player.physical_surface_index
    procinfo.physical_controller_type = player.physical_controller_type
    procinfo.physical_position = player.physical_position

    debug("edit_selected: enter remote player=" .. player.index ..
        " processor=" .. tostring(processor.unit_number) ..
        " origin_surface=" .. tostring(procinfo.origin_surface_name) ..
        " origin_controller=" .. tostring(procinfo.origin_controller_type) ..
        " target_surface=" .. tostring(surface.name))
    vars.pending_processor_entry_surface = surface.name
    vars.pending_processor_entry_tick = game.tick
    player.set_controller {
        type = defines.controllers.remote,
        position = { 0, 0 },
        surface = surface
    }
    player.zoom = editor_remote_zoom
end

---@param procinfo ProcInfo
---@param player LuaPlayer
local function restore_player_controller(procinfo, player)
    ---@type string
    local ret_surface_name
    ---@type MapPosition
    local ret_surface_position
    ---@type defines.controllers
    local ret_controller_type
    ---@type LuaSurface
    local ret_surface

    ret_surface_name = procinfo.origin_surface_name
    ret_surface_position = procinfo.origin_surface_position
    ret_controller_type = procinfo.origin_controller_type or defines.controllers.character
    ret_surface = game.surfaces[ret_surface_name]

    if not ret_surface or not ret_surface.valid then
        ret_surface_name = "nauvis"
        ret_surface_position = { x = 0, y = 0 }
    end

    debug("restore_player_controller: player=" .. player.index ..
        " return_controller=" .. tostring(ret_controller_type) ..
        " return_surface=" .. tostring(ret_surface_name) ..
        " return_pos=" .. tostring(ret_surface_position.x) .. "," .. tostring(ret_surface_position.y))

    if ret_controller_type == defines.controllers.character then
        local character = player.character
        if character and character.valid then
            if player.surface ~= character.surface then
                player.set_controller {
                    type = defines.controllers.remote,
                    position = character.position,
                    surface = character.surface
                }
            end
            debug("restore_player_controller: restore character controller player=" .. player.index)
            player.set_controller {
                type = defines.controllers.character,
                character = character
            }
        end
    elseif ret_controller_type == defines.controllers.god then
        debug("restore_player_controller: teleport return player=" .. player.index)
        player.set_controller {
            type = defines.controllers.god
        }
        player.teleport(ret_surface_position, ret_surface_name)
        local surface = game.surfaces[ret_surface_name]
        local platform = surface.platform
        if platform then
            player.enter_space_platform(platform)
        end
    else
        if procinfo.physical_controller_type then
            debug("restore_player_controller: restore physical player=" .. player.index ..
                " surface=" .. tostring(procinfo.physical_surface_index))
            player.teleport(procinfo.physical_position, procinfo.physical_surface_index, false, false)
            local surface = game.surfaces[procinfo.physical_surface_index]
            local platform = surface.platform
            if platform then
                player.enter_space_platform(platform)
            end
        end
        debug("restore_player_controller: set_controller return player=" .. player.index)
        player.set_controller {
            type = ret_controller_type,
            position = ret_surface_position,
            surface = ret_surface_name
        }
    end

    editor.restore_surface_list(player, "restore_player_controller")
end

---@param player LuaPlayer
---@param context string
function editor.restore_surface_list(player, context)
    local vars = tools.get_vars(player)
    if vars.show_surface_list_before_editor ~= nil then
        player.game_view_settings.show_surface_list = vars.show_surface_list_before_editor
        debug(context .. ": restore surface list player=" .. player.index ..
            " value=" .. tostring(vars.show_surface_list_before_editor))
        vars.show_surface_list_before_editor = nil
    end
end

---@param player LuaPlayer
---@param context string
function editor.hide_surface_list(player, context)
    local vars = tools.get_vars(player)
    if vars.show_surface_list_before_editor == nil then
        vars.show_surface_list_before_editor = player.game_view_settings.show_surface_list
    end
    if player.game_view_settings.show_surface_list then
        player.game_view_settings.show_surface_list = false
        debug(context .. ": hide surface list player=" .. player.index)
    end
end

---@param player LuaPlayer
function editor.close_all(player)
    editor.close_iopanel(player)
    display.close(player)
    input.close(player)
    tools.fire_user_event("models.close", player)
end

ccutils.close_all = editor.close_all

---@param e EventData.on_gui_checked_state_changed
local function on_gui_checked_state_changed(e)
    if not e.element or e.element.name ~= prefix .. "-is_packed" then return end
    local player = game.players[e.player_index]

    local vars = get_vars(player)
    local procinfo = vars.procinfo
    if not procinfo then return end
    local new_packed = e.element.state
    editor.set_packed(procinfo, new_packed, player)
end

---@param parent ProcInfo
function editor.recursive_pack(parent)
    if not parent.surface then return end
    local processors = parent.surface.find_entities_filtered {
        name = { commons.processor_name, commons.processor_name_1x1 }
    }
    for _, processor in pairs(processors) do
        local procinfo = get_procinfo(processor, false)
        if procinfo and not procinfo.is_packed then
            editor.recursive_pack(procinfo)
            build.save_packed_circuits(procinfo)
            build.disconnect_all_iopoints(procinfo)
            build.create_packed_circuit(procinfo)
            editor.delete_surface(procinfo)
            procinfo.is_packed = true
        end
    end
end

---@param procinfo ProcInfo
---@param is_packed boolean
---@param player LuaPlayer?
function editor.set_packed(procinfo, is_packed, player)
    if procinfo.is_packed == is_packed then return end

    procinfo.is_packed = is_packed
    if is_packed then
        editor.recursive_pack(procinfo)
        build.save_packed_circuits(procinfo)
        build.disconnect_all_iopoints(procinfo)
        local _, _, externals = build.create_packed_circuit(procinfo)
        if externals and #externals > 0 and player then
            player.print({ "compaktcircuit-message.external_present" })
        end
        input.apply_parameters(procinfo)
        input.disconnect_comms(procinfo.surface)
    else
        build.destroy_packed_circuit(procinfo)
        build.connect_all_iopoints(procinfo)
        input.apply_parameters(procinfo)
        display.restore(procinfo)
        input.disconnect_comms(procinfo.surface)
        input.connect_comms(procinfo.surface)
    end
end

---@param procinfo ProcInfo
function editor.regenerate_packed(procinfo)
    if not procinfo.is_packed then return end

    build.create_packed_circuit(procinfo)
end

tools.on_event(defines.events.on_gui_checked_state_changed,
    on_gui_checked_state_changed)

---@param player LuaPlayer
---@return boolean
local function check_stack(player)
    local stack = player.cursor_stack
    if stack and stack.valid then
        if stack.count > 0 then
            if stack.name == internal_iopoint_name
                or stack.name == internal_connector_name
                or stack.name == display_name
                or stack.name == input_name
            then
                return true
            end

            local main_inventory = player.get_main_inventory()
            if not main_inventory then return false end
            local empty_stack = main_inventory.find_empty_stack()
            if empty_stack then
                empty_stack.transfer_stack(stack)
            else
                player.surface.spill_item_stack { position = player.position, stack = stack }
            end
            stack.clear()
        end
        return true
    end

    return false
end

---@param e EventData.on_gui_click
local function on_add_pole(e)
    local player = game.players[e.player_index]
    if check_stack(player) then player.cursor_ghost = internal_iopoint_name end
end

---@param e EventData.on_gui_click
local function on_add_internal_connector(e)
    local player = game.players[e.player_index]
    if check_stack(player) then
        player.cursor_ghost = internal_connector_name
    end
end

---@param e EventData.on_gui_click
local function on_add_display(e)
    local player = game.players[e.player_index]
    if check_stack(player) then
        player.cursor_ghost = display_name
    end
end

---@param e EventData.on_gui_click
local function on_add_input(e)
    local player = game.players[e.player_index]
    if check_stack(player) then
        player.cursor_ghost = commons.input_name
    end
end

---@param e EventData.on_gui_click
local function on_models_open(e)
    local player = game.players[e.player_index]
    tools.fire_user_event("models.open", player)
end

tools.on_gui_click(prefix .. "-models", on_models_open)
tools.on_gui_click(prefix .. "-add_iopole", on_add_pole)
tools.on_gui_click(prefix .. "-add_internal_connector",
    on_add_internal_connector)
tools.on_gui_click(prefix .. "-add_display",
    on_add_display)
tools.on_gui_click(prefix .. "-add_input",
    on_add_input)

---------------------------------------------------------------

---@param procinfo ProcInfo
---@return LuaSurface
function editor.get_or_create_surface(procinfo)
    if not storage.surface_map then
        ---@type table<string, ProcInfo>
        storage.surface_map = {}
    end

    local surface_name = editor.get_surface_name(procinfo.processor)
    local surface = game.get_surface(surface_name)
    if surface and surface == procinfo.surface and surface.valid then
        return surface
    end

    if not surface or not surface.valid then
        local mgs = {
            width = EDITOR_SIZE,
            height = EDITOR_SIZE,
            no_enemies_mode = true,
            property_expression_names = {},
            default_enable_all_autoplace_controls = false,
                autoplace_settings = {
                entity = { treat_missing_as_default = false, frequency = "none" },
                tile = { treat_missing_as_default = false },
                decorative = { treat_missing_as_default = false, frequency = "none" }
            },
        }
        surface = game.create_surface(surface_name, mgs)


        surface.always_day = true
        surface.show_clouds = false
        surface.request_to_generate_chunks({ 0, 0 }, 8)
        surface.force_generate_chunk_requests()
        surface.destroy_decoratives({})

        for _, force in pairs(game.forces) do
            force.set_surface_hidden(surface, true)
        end

        local tiles = {}
        local tile_proto = prefix .. "-ground"
        if not prototypes.tile[tile_proto] then
            tile_proto = "refined-concrete"
        end

        for _, tile in ipairs(surface.find_tiles_filtered {
            position = { 0, 0 },
            radius = EDITOR_SIZE + 2
        }) do
            local position = tile.position
            if (math.abs(position.x) > EDITOR_SIZE / 2 or math.abs(position.y) >
                    EDITOR_SIZE / 2) then
                table.insert(tiles, { name = "out-of-map", position = position })
            else
                table.insert(tiles, { name = tile_proto, position = position })
            end
        end

        surface.set_tiles(tiles)
    end

    procinfo.surface = surface
    storage.surface_map[surface_name] = procinfo
    editor.clean_surface(procinfo)
    return surface
end

---@param procinfo ProcInfo
function editor.clean_surface(procinfo)
    if not procinfo.surface then return end
    for _, entity in ipairs(procinfo.surface.find_entities()) do
        if entity.valid and entity.type ~= "character" then
            if not entity.mine({ raise_destroyed = true }) then
                entity.destroy()
            end
        end
    end
    for _, entity in ipairs(procinfo.surface.find_entities()) do
        if entity.valid and entity.type ~= "character" then
            entity.destroy()
        end
    end
    editor.connect_energy(procinfo)
end

---------------------------------------------------------------

---@param procinfo ProcInfo
function editor.connect_energy(procinfo)
    local processor = procinfo.processor
    local in_pole = procinfo.in_pole
    if not in_pole or not in_pole.valid then
        in_pole = procinfo.surface.create_entity {
            name = prefix .. "-energy_pole",
            position = { EDITOR_SIZE / 2 + 4, 4 },
            force = processor.force
        }
        procinfo.in_pole = in_pole
        in_pole.destructible = false
    end

    local generator = procinfo.generator
    if not generator or not generator.valid then
        generator = procinfo.surface.create_entity {
            name = prefix .. "-energy_source",
            position = { EDITOR_SIZE / 2 + 4, 10 },
            force = processor.force
        }
        procinfo.generator = generator
        generator.destructible = false
    end

    local radar_name = prefix .. "-radar"
    local radar_proto = prototypes.entity[radar_name]
    if radar_proto then
        local radar = procinfo.surface.create_entity {
            name = radar_name,
            position = { EDITOR_SIZE / 2 + 10, 16 },
            force = processor.force
        }
        radar.destructible = false
    end

    -- Old stuff
    local energy_pole = procinfo.energ_pole
    if energy_pole and energy_pole.valid then
        energy_pole.destroy()
        procinfo.energ_pole = nil
    end

    local accu = procinfo.accu
    if accu and accu.valid then
        accu.destroy()
        procinfo.accu = nil
    end
end

---------------------------------------------------------------

---@param player LuaPlayer
function editor.close_iopanel(player)
    local panel = player.gui.screen[iopanel_name]
    if panel then
        tools.get_vars(player).edit_location = panel.location
        panel.destroy()
    end

    panel = player.gui.left[iopanel_name]
    if panel then
        panel.destroy()
    end
end

---------------------------------------------------------------

local display_options = {

    { prefix .. "-dropdown.all" }, { prefix .. "-dropdown.one_line" },
    { prefix .. "-dropdown.none" }
}

---@param player LuaPlayer
---@param entity LuaEntity
function editor.open_iopole(player, entity)
    if not entity or not entity.valid or entity.name ~= internal_iopoint_name then
        return
    end

    ccutils.close_all(player)

    player.opened = nil

    local vars = get_vars(player)
    local procinfo = storage.surface_map[entity.surface.name]

    local ids = {}
    for i = 1, #procinfo.iopoints do table.insert(ids, tostring(i)) end


    vars.iopole = entity
    local iopoint_info = procinfo.iopoint_infos[entity.unit_number]

    local outer_frame, frame = tools.create_standard_panel(player, {
        panel_name = iopanel_name,
        title = { prefix .. "-iopanel.title" },
        is_draggable = true,
        create_inner_frame = true,
        close_button_name = prefix .. ".iopole_ok"
    })

    local flow = frame.add { type = "flow", direction = "horizontal" }
    local label1 = flow.add {
        type = "label",
        caption = { label_prefix .. ".iopole_id" }
    }
    label1.style.width = 200
    local combo = flow.add {
        type = "drop-down",
        name = prefix .. ".iopole_index",
        items = ids,
        selected_index = iopoint_info.index
    }
    combo.style.width = 100

    flow = frame.add { type = "flow", direction = "horizontal" }
    local label2 = flow.add {
        type = "label",
        caption = { label_prefix .. ".iopole_name" }
    }
    label2.style.width = 200
    local name = flow.add {
        type = "textfield",
        name = prefix .. ".iopole_name",
        text = iopoint_info.label,
        icon_selector = true
    }
    flow.style.bottom_margin = 10

    flow = frame.add { type = "flow", direction = "horizontal" }
    flow.style.bottom_margin = 10
    label1 = flow.add {
        type = "label",
        caption = { label_prefix .. ".io_direction" }
    }
    label1.style.width = 200
    local cb = flow.add {
        type = "checkbox",
        caption = { checkbox_prefix .. ".io_input" },
        name = prefix .. ".io_input",
        state = iopoint_info.input == true
    }
    cb.style.right_margin = 20
    flow.add {
        type = "checkbox",
        caption = { checkbox_prefix .. ".io_output" },
        name = prefix .. ".io_output",
        state = iopoint_info.output ~= false
    }

    flow = frame.add { type = "flow", direction = "horizontal" }
    flow.style.bottom_margin = 10
    flow.add { type = "label", caption = { label_prefix .. ".red_display" } }
    flow.add {
        type = "drop-down",
        name = prefix .. ".red_display",
        items = display_options,
        selected_index = iopoint_info.red_display and iopoint_info.red_display +
            1 or 1
    }

    local d = flow.add {
        type = "label",
        caption = { label_prefix .. ".green_display" }
    }
    d.style.left_margin = 10
    flow.add {
        type = "drop-down",
        name = prefix .. ".green_display",
        items = display_options,
        selected_index = iopoint_info.green_display and
            iopoint_info.green_display + 1 or 1
    }

    local edit_location = vars.edit_location
    if edit_location then
        outer_frame.location = edit_location
    else
        outer_frame.force_auto_center()
    end
end

---@param e EventData.on_gui_opened
local function on_gui_open_iopole(e)
    local player = game.players[e.player_index]
    local entity = e.entity
    editor.open_iopole(player, entity)
end

---------------------------------------------------------------

---@param procinfo ProcInfo
---@param iopole LuaEntity
---@return IOPointInfo?
function editor.get_iopoint_info(procinfo, iopole)
    if not iopole.valid then return nil end
    local iopoint_infos = procinfo.iopoint_infos
    local iopoint_info = iopoint_infos[iopole.unit_number]
    if not iopoint_info then
        iopoint_info = {}
        iopoint_infos[iopole.unit_number] = iopoint_info
    end
    return iopoint_info
end

local get_iopoint_info = editor.get_iopoint_info

---------------------------------------------------------------

---@type table<string, boolean>
local iopole_fields = {
    [prefix .. ".iopole_index"] = true,
    [prefix .. ".red_display"] = true,
    [prefix .. ".green_display"] = true

}

---@param e EventData.on_gui_selection_state_changed
local function on_gui_selection_state_changed(e)
    if not e.element then return end

    local name = e.element.name
    if not iopole_fields[name] then return end

    local player = game.players[e.player_index]
    local vars = get_vars(player)

    ---@type LuaEntity
    local iopole = vars.iopole
    if not iopole or not iopole.valid then return end

    ---@type ProcInfo
    local procinfo = vars.procinfo
    if not procinfo then return end
    local iopole_info = get_iopoint_info(procinfo, iopole)

    if name == prefix .. ".iopole_index" then
        ---@cast iopole_info -nil
        if not procinfo.is_packed then
            build.disconnect_iopole(procinfo, iopole_info)
        end
        iopole_info.index = e.element.selected_index
        if not procinfo.is_packed then
            build.connect_iopole(procinfo, iopole_info)
        end
    elseif name == prefix .. ".red_display" then
        iopole_info.red_display = e.element.selected_index - 1
    elseif name == prefix .. ".green_display" then
        iopole_info.green_display = e.element.selected_index - 1
    end
end

---@param e EventData.on_gui_checked_state_changed(
local function on_gui_checked_state_changed(e)
    if not e.element then return end

    local name = e.element.name
    local player = game.players[e.player_index]
    local vars = get_vars(player)

    ---@type LuaEntity
    local iopole = vars.iopole
    if not (iopole and iopole.valid) then return end

    ---@type ProcInfo
    local procinfo = vars.procinfo
    if not procinfo then return end

    local iopole_info = get_iopoint_info(procinfo, iopole)
    if name == prefix .. ".io_input" then
        iopole_info.input = e.element.state
    elseif name == prefix .. ".io_output" then
        iopole_info.output = e.element.state
    end
end

---------------------------------------------------------------

---@param e EventData.on_gui_text_changed
local function on_gui_text_changed(e)
    if not e.element or not e.element.valid then return end

    local player = game.players[e.player_index]
    local vars = get_vars(player)
    if e.element.name == prefix .. ".iopole_name" then
        local iopole = vars.iopole
        if not iopole or not iopole.valid then return end
        local procinfo = vars.procinfo
        if not procinfo then return end

        local iopoint_info = get_iopoint_info(procinfo, iopole)
        if not iopoint_info then return end
        iopoint_info.label = e.element.text
        build.update_io_text(iopoint_info)
    elseif e.element.name == prefix .. "-title" then
        local procinfo = vars.procinfo
        if not procinfo then return end
        ---@type string | nil
        local text
        text = e.element.text
        if text == '' then text = nil end
        procinfo.label = text
    end
end

---@param e EventData.on_gui_confirmed
local function on_gui_confirmed(e)
    local player = game.players[e.player_index]
    editor.close_iopanel(player)
end


---------------------------------------------------------------

---@param procinfo ProcInfo
function editor.delete_surface(procinfo)
    if not procinfo.surface then return end

    editor.clean_surface(procinfo)
    storage.surface_map[procinfo.surface.name] = nil
    game.delete_surface(procinfo.surface)
    procinfo.surface = nil
end

---@param e EventData.on_pre_surface_deleted
function editor.on_pre_surface_deleted(e)
    local surface = game.surfaces[e.surface_index]
    local procinfo = storage.surface_map[surface.name]

    if procinfo == nil then return end

    editor.clean_surface(procinfo)
    storage.surface_map[surface.name] = nil
    procinfo.surface = nil
    for _, player in pairs(game.players) do
        if player.surface == surface then restore_player_controller(procinfo, player) end
    end
end

tools.on_event(defines.events.on_pre_surface_deleted,
    editor.on_pre_surface_deleted)

---------------------------------------------------------------

---@param procinfo ProcInfo
function editor.draw_sprite(procinfo)
    local processor = procinfo.processor
    if not (processor and processor.valid) then return end

    if procinfo.sprite_ids then
        for _, id in pairs(procinfo.sprite_ids) do
            if type(id) == "number" then
                local o = rendering.get_object_by_id(id)
                if o then
                    o.destroy()
                end
            else
                id.destroy()
            end
        end
        procinfo.sprite_ids = nil
    end

    if not procinfo.sprite1 and not procinfo.sprite2 then return end

    ---@type number[]
    local ids = {}
    local scale, scale2
    local target_y = -0.07
    if processor.name == commons.processor_name then
        scale = 1.65
        scale2 = 1.2
    else
        scale = 0.85
        scale2 = 0.6
    end

    local sprite1 = ccutils.check_sprite(procinfo.sprite1)
    if sprite1 then
        local id = rendering.draw_sprite {
            surface = processor.surface,
            sprite = sprite1,
            target = {
                offset = { 0, target_y * scale },
                entity = processor
            },
            x_scale = scale,
            y_scale = scale,
            render_layer = "lower-object"
        }
        table.insert(ids, id)
    end

    local sprite2 = ccutils.check_sprite(procinfo.sprite2)
    if sprite2 then
        local id = rendering.draw_sprite {
            surface = processor.surface,
            sprite = sprite2,
            target = {
                offset = { 0, target_y * scale },
                entity = processor
            },
            x_scale = scale2,
            y_scale = scale2,
            render_layer = "lower-object"
        }
        table.insert(ids, id)
    end

    procinfo.sprite_ids = ids
end

---------------------------------------------------------------

---@param e EventData.on_player_changed_surface
local function on_player_changed_surface(e)
    local player = game.players[e.player_index]
    local vars = get_vars(player)
    local procinfo = vars.procinfo
    local previous_surface = game.surfaces[e.surface_index]
    local from_proc_surface = previous_surface and previous_surface.valid and
        storage.surface_map[previous_surface.name] ~= nil

    local is_standard_exit = vars.is_standard_exit
    vars.is_standard_exit = false

    debug("on_player_changed_surface: player=" .. e.player_index ..
        " from_surface_index=" .. tostring(e.surface_index) ..
        " current_surface=" .. tostring(player.surface.name) ..
        " has_procinfo=" .. tostring(procinfo ~= nil) ..
        " is_standard_exit=" .. tostring(is_standard_exit))

    if procinfo and (not procinfo.processor or not procinfo.processor.valid) then
        editor.restore_surface_list(player, "on_player_changed_surface")
        vars.procinfo = nil
        return
    end

    local function finish_processor_exit(current_procinfo, standard_exit, context)
        editor.close_all(player)
        editor.close_editor_panel(player)
        editor.restore_surface_list(player, context)

        player.opened = nil
        vars.procinfo = nil
        vars.processor = nil
        current_procinfo.tick = game.tick
        build.save_packed_circuits(current_procinfo)
        if current_procinfo.is_packed then
            if standard_exit then
                editor.delete_surface(current_procinfo)
                local _, recursionError = build.create_packed_circuit(current_procinfo)
                input.apply_parameters(procinfo)
                if recursionError then
                    player.print {
                        message_prefix .. ".recursion_error", recursionError
                    }
                end
            else
                build.destroy_packed_circuit(current_procinfo)
                build.connect_all_iopoints(current_procinfo)
                current_procinfo.is_packed = false
            end
        end
    end

    -- Exiting surface
    if procinfo and procinfo.surface and procinfo.surface.valid and
        procinfo.surface.index == e.surface_index then
        debug("on_player_changed_surface: leaving editor surface player=" .. e.player_index ..
            " surface=" .. tostring(procinfo.surface.name) ..
            " packed=" .. tostring(procinfo.is_packed))
        finish_processor_exit(procinfo, is_standard_exit, "on_player_changed_surface")

        -- Fallback for mod interactions where remote exits directly to physical character
        -- before controller-changed restoration can run (for example sandbox god flows).
        if not is_standard_exit and
            procinfo.origin_controller_type == defines.controllers.god and
            player.surface and player.surface.name ~= procinfo.origin_surface_name then
            debug("on_player_changed_surface: fallback restore god-origin player=" .. e.player_index ..
                " current_surface=" .. tostring(player.surface.name) ..
                " origin_surface=" .. tostring(procinfo.origin_surface_name))
            restore_player_controller(procinfo, player)
        end
    end

    local surface_name = player.surface.name
    procinfo = storage.surface_map[surface_name]
    if procinfo then
        local intentional_processor_entry =
            vars.pending_processor_entry_surface == surface_name and
            vars.pending_processor_entry_tick == game.tick
        vars.pending_processor_entry_surface = nil
        vars.pending_processor_entry_tick = nil

        if not intentional_processor_entry and
            from_proc_surface then
            debug("on_player_changed_surface: editor nested escape hard-unwind player=" .. e.player_index ..
                " surface=" .. tostring(surface_name) ..
                " origin_surface=" .. tostring(procinfo.origin_surface_name))
            finish_processor_exit(procinfo, false, "on_player_changed_surface/editor_nested_escape")
            restore_player_controller(procinfo, player)
            return
        end

        debug("on_player_changed_surface: entering editor surface player=" .. e.player_index ..
            " surface=" .. tostring(surface_name) ..
            " processor=" .. tostring(procinfo.processor and procinfo.processor.name))
        editor.hide_surface_list(player, "on_player_changed_surface")
        vars.procinfo = procinfo
        vars.processor = procinfo.processor
        if from_proc_surface and math.abs(player.zoom - editor_remote_zoom) > 0.001 then
            player.zoom = editor_remote_zoom
        end
        player.surface.request_to_generate_chunks(player.position, 8)
        player.force.chart_all(player.surface)
        editor.create_editor_panel(player, procinfo)
    end
end

---@param e EventData.on_player_controller_changed
local function on_player_controller_changed(e)
    if e.old_type ~= defines.controllers.remote then return end

    local player = game.players[e.player_index]
    if player.controller_type == defines.controllers.remote then return end

    local vars = get_vars(player)
    local procinfo = vars.procinfo
    if not procinfo or not procinfo.surface or not procinfo.surface.valid then return end
    if player.surface ~= procinfo.surface then return end

    debug("on_player_controller_changed: restoring player=" .. e.player_index ..
        " old_controller=" .. (controller_names[e.old_type] or tostring(e.old_type)) ..
        " new_controller=" .. (controller_names[player.controller_type] or tostring(player.controller_type)) ..
        " surface=" .. tostring(player.surface.name))

    editor.close_all(player)
    editor.close_editor_panel(player)
    editor.restore_surface_list(player, "on_player_controller_changed")

    player.opened = nil
    vars.procinfo = nil
    vars.processor = nil
    procinfo.tick = game.tick
    build.save_packed_circuits(procinfo)
    restore_player_controller(procinfo, player)
end

---------------------------------------------------------------

---@param e EventData.on_gui_click
tools.on_gui_click(prefix .. ".iopole_ok", function(e)
    local player = game.players[e.player_index]
    editor.close_iopanel(player)
end)

tools.on_event(defines.events.on_gui_opened, on_gui_open_iopole)
tools.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)
tools.on_event(defines.events.on_gui_selection_state_changed,
    on_gui_selection_state_changed)
tools.on_event(defines.events.on_gui_checked_state_changed,
    on_gui_checked_state_changed)
tools.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
tools.on_event(defines.events.on_player_changed_surface,
    on_player_changed_surface)
tools.on_event(defines.events.on_player_controller_changed,
    on_player_controller_changed)

--------------------------------------------------------------------------------------

---@param procinfo ProcInfo
---@return table<integer, IOPointInfo>
local function get_iopoint_map(procinfo)
    local map = {}
    for _, iopoint_info in pairs(procinfo.iopoint_infos) do
        if iopoint_info.index then map[iopoint_info.index] = iopoint_info end
    end
    return map
end

---@param procinfo ProcInfo
---@return integer
local function find_iopoint_index(procinfo)
    local map = get_iopoint_map(procinfo)
    for i = 1, #procinfo.iopoints do if not map[i] then return i end end
    return 1
end

---@param procinfo ProcInfo
---@param index integer
---@return integer
local function check_ipoint_index(procinfo, index)
    if storage.surface_restoring then return index end

    local map = get_iopoint_map(procinfo)
    if index then
        if index > #procinfo.iopoints then index = 1 end
        if not map[index] then return index end
    end
    for i = 1, #procinfo.iopoints do if not map[i] then return i end end
    return 1
end


---@param entity LuaEntity
---@param tags Tags
---@param procinfo ProcInfo
local function init_internal_point(entity, tags, procinfo)
    ---@type IOPointInfo
    local circuit = { label = "" }
    if tags then
        local iotags = tags --[[@as IOPointInfo ]]
        circuit.label = iotags.label
        circuit.index = check_ipoint_index(procinfo, iotags.index)
        circuit.input = iotags.input
        circuit.output = iotags.output
        circuit.red_display = iotags.red_display
        circuit.green_display = iotags.green_display
    else
        circuit.index = find_iopoint_index(procinfo)
    end
    local iopoint_info = build.create_iopoint(procinfo, entity, circuit)
    build.update_io_text(iopoint_info)
end

editor.init_internal_point = init_internal_point


---@param player_index integer?
---@param text LocalisedString
---@param position MapPosition?
local function fly_text(player_index, text, position)
    if not player_index then return end

    local player = game.players[player_index]
    player.create_local_flying_text {
        text = text,
        create_at_cursor = not position and true,
        position = position,
        color = { r = 1.0, a = 0.5 },
        speed = 40
    }
end

local ghost_classes = {
    [internal_iopoint_name]   = true,
    [internal_connector_name] = true,
    [display_name]            = true,
    [input_name]              = true

}

---@param entity LuaEntity
---@param e EventData.on_robot_built_entity | EventData.script_raised_built | EventData.on_built_entity | EventData.script_raised_revive
local function on_build(entity, e)
    if not entity or not entity.valid then return end

    local name = entity.name
    local procinfo = storage.surface_map and storage.surface_map[entity.surface.name]
    if not procinfo then
        return
    end

    local tags = e.tags
    if not tags then
        tags = (e.stack and e.stack.is_item_with_tags and e.stack.tags)
    end
    if tags then
        if tags.__ then tags = tags.__ end
        if tags.__delete then
            entity.destroy()
            return
        end
    end

    if name == display_name then
        if tags then
            display.register(entity, tags --[[@as Display]])
        end
    elseif name == input_name then
        if not IsProcessorRebuilding and tags then
            tags.value_id = tools.get_id()
        elseif tags then
            tools.upgrade_id(tags.value_id)
        end
        input.register(entity, tags --[[@as Input]])
    elseif name == internal_iopoint_name then
        init_internal_point(entity, tags, procinfo)
    elseif name == internal_connector_name then
        entity.operable = false
    elseif name == "entity-ghost" and is_allowed(entity.ghost_name) then
        if ghost_classes[entity.ghost_name] then
            local d, new = entity.silent_revive { raise_revive = true }
        else
            if e.player_index then
                local player = game.players[e.player_index]
                if commons.remote_controllers[player.controller_type] then
                    -- TODO: Implement item-request-proxy handling? vanilla combinators / allowed
                    --       editor entities do not rely on modules, etc; but other mods may want
                    --       that functionality to work?
                    entity.revive { raise_revive = true }
                end
            end
        end
    elseif procinfo and not is_allowed(name) then
        if settings.global[prefix .. "-allow-external"].value then
            if procinfo.is_packed then
                fly_text(e.player_index, { message_prefix .. ".not_allowed_packed" }, entity.position)
            end
            return
        else
            fly_text(e.player_index, { message_prefix .. ".not_allowed" }, entity.position)
        end
        if not storage.destroy_list then
            storage.destroy_list = { entity }
        else
            table.insert(storage.destroy_list, entity)
        end
    end
end

---@param entity LuaEntity
local function destroy_invalid(entity)
    local m = entity.prototype.mineable_properties
    local position = entity.position
    local surface = entity.surface
    local force = entity.force --[[@as LuaForce]]
    if not entity.mine { raise_destroyed = true, ignore_minable = true } then
        entity.destroy()
    end
    if m.minable and m.products then
        for _, p in pairs(m.products) do
            surface.spill_item_stack { position = position,
                stack = { name = p.name, count = p.amount },
                enable_looted = true,
                force = force }
        end
    end
end

tools.on_nth_tick(5, function()
    if not storage.destroy_list then return end
    for _, entity in ipairs(storage.destroy_list) do
        if entity.valid then destroy_invalid(entity) end
    end
    storage.destroy_list = nil
end)

---@param ev EventData.on_robot_built_entity
local function on_robot_built(ev)
    local entity = ev.entity

    on_build(entity, ev)
end

---@param ev EventData.script_raised_built
local function on_script_built(ev)
    local entity = ev.entity

    on_build(entity, ev)
end

---@param ev EventData.script_raised_revive
local function on_script_revive(ev)
    local entity = ev.entity

    on_build(entity, ev)
end

---@param ev EventData.on_built_entity
local function on_player_built(ev)
    local entity = ev.entity

    on_build(entity, ev)
end

local class_to_save = {
    [input_name] = true,
    [display_name] = true,
    [internal_iopoint_name] = true
}

---@param e EventData.on_marked_for_deconstruction
local function on_marked_for_deconstruction(e)
    local player_index = e.player_index
    if not player_index then return end

    local player = game.players[e.player_index]
    local entity = e.entity
    local procinfo = storage.surface_map and storage.surface_map[entity.surface.name]
    if not procinfo then return end

    if not entity.valid then return end

    local name = entity.name
    local need_mining = false
    if e.player_index then
        if name == internal_iopoint_name then
            editor.save_undo_tags(e.player_index, entity.position, build.get_internal_iopoint_tags(entity))
            need_mining = true
        elseif name == input_name then
            local tags = input.get_tags(entity)
            editor.save_undo_tags(e.player_index, entity.position, tags)
            need_mining = true
        elseif name == display_name then
            local tags = display.get_tags(entity)
            editor.save_undo_tags(e.player_index, entity.position, tags)
            need_mining = true
        elseif name == commons.internal_connector_name then
            need_mining = true
        elseif commons.processor_names[name] then
            return
        end
    end

    local player_surface = player.surface
    local is_same_surface = player_surface and player_surface.valid and player_surface == entity.surface
    if entity.valid and is_same_surface and (commons.remote_controllers[player.controller_type] or need_mining) then
        if entity.name == internal_iopoint_name then
            editor.destroy_internal_iopoint(entity)
        end
        entity.mine { raise_destroyed = true }
    end
end

tools.on_event(defines.events.on_built_entity, on_player_built)
tools.on_event(defines.events.on_robot_built_entity, on_robot_built)
tools.on_event(defines.events.script_raised_built, on_script_built)
tools.on_event(defines.events.script_raised_revive, on_script_revive)
tools.on_event(defines.events.on_marked_for_deconstruction,
    on_marked_for_deconstruction)

--------------------------------------------------------------------------------------

local filter_names = { {} }

---@type string[]
local surface_name_filter = {
    "constant-combinator", "decider-combinator", "arithmetic-combinator", "selector-combinator",
    "big-electric-pole", "small-electric-pole", "medium-electric-pole",
    "substation", internal_iopoint_name, "small-lamp"
}

for name, _ in pairs(textplate_map) do table.insert(surface_name_filter, name) end

---------------------------------------------------------------

---@param entity LuaEntity
function editor.destroy_internal_iopoint(entity)
    if not entity.valid then return end

    ---@type ProcInfo
    local procinfo = storage.surface_map[entity.surface.name]
    if not procinfo then return end

    procinfo.iopoint_infos[entity.unit_number] = nil
    tools.close_ui(entity.unit_number, editor.close_iopanel, "iopole")
end

local function on_mined(ev)
    local entity = ev.entity
    if entity.name == internal_iopoint_name then
        if ev.player_index then
            editor.save_undo_tags(ev.player_index, entity.position, build.get_internal_iopoint_tags(entity))
        end
        editor.destroy_internal_iopoint(entity)
        if ev.buffer then ev.buffer.clear() end
    elseif entity.name == internal_connector_name then
        if ev.buffer then ev.buffer.clear() end
    elseif entity.name == display_name then
        if ev.buffer then ev.buffer.clear() end
        if ev.player_index then
            local tags = display.get_tags(entity)
            editor.save_undo_tags(ev.player_index, entity.position, tags)
        end
        display.mine(entity)
    elseif entity.name == input_name then
        if ev.buffer then ev.buffer.clear() end
        if ev.player_index then
            local tags = input.get_tags(entity)
            editor.save_undo_tags(ev.player_index, entity.position, tags)
        end
        input.mine(entity)
    end
end

---@param ev EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
local function on_player_mined_entity(ev)
    on_mined(ev)
end

local mine_filter = {
    { filter = 'name', name = internal_iopoint_name },
    { filter = 'name', name = internal_connector_name },
    { filter = 'name', name = display_name },
    { filter = 'name', name = input_name }
}
tools.on_event(defines.events.on_player_mined_entity, on_player_mined_entity, mine_filter)
tools.on_event(defines.events.on_robot_mined_entity, on_mined, mine_filter)
tools.on_event(defines.events.on_entity_died, on_mined, mine_filter)
tools.on_event(defines.events.script_raised_destroy, on_mined, mine_filter)

---@type table<string, boolean>
local forbidden_prototypes = {

    ["container"] = true,
    ["logistic-container"] = true,
    ["assembling-machine"] = false, -- Recipe Combinator is implemented as an assembling machine - https://mods.factorio.com/mod/lo-recipe-combinator - but it tested to work fine if allow it!
    ["boiler"] = true,
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true,
    ["pipe"] = true,
    ["pipe-to-ground"] = true,
    ["rail"] = true
}

---@param driver RemoteInterface
function editor.add_combinator(driver)
    if remote_name_map[driver.name] then return end

    local proto = prototypes.entity[driver.name]
    if forbidden_prototypes[proto.type] then return end

    remote_name_map[driver.name] = driver
    table.insert(surface_name_filter, driver.name)
    local packed_names = driver.packed_names
    if packed_names then
        for _, name in ipairs(packed_names) do
            table.insert(commons.packed_entities, name)
            table.insert(commons.entities_to_destroy, name)
        end
    end
end

---@param name string
function editor.remove_combinator(name)
    local driver = remote_name_map[name]
    if not driver then return end

    remote_name_map[name] = driver
    for i, n in ipairs(surface_name_filter) do
        if n == name then
            table.remove(surface_name_filter, i)
            break
        end
    end

    local packed_names = driver.packed_names
    if packed_names then
        for _, np in ipairs(packed_names) do
            for i, n in ipairs(commons.packed_entities) do
                if n == np then
                    table.remove(commons.packed_entities, i)
                    break
                end
            end
            for i, n in ipairs(commons.entities_to_destroy) do
                if n == np then
                    table.remove(commons.entities_to_destroy, i)
                    break
                end
            end
        end
    end
end

remote.add_interface(prefix, {
    add_combinator = editor.add_combinator,
    remove_combinator = editor.remove_combinator
})

--[[
    Remote fields:

        name: string, entity name

        packed_names: string[] , liste of entities used in packed mode

        interface_name : name of reverse interface

    Reverse interface:

        get_info(entity) : add private information on entities
            return {a structure containing private information}
            reserved fields:
                name,  index, position, direction

        create_packed_entity(info, surface, position, force)
            create a packed entity from 'info' structure'

        create_entity(info, surface, force)
            create a normal entity from information
            (position, direction, name) is in 'info' structure

--]]

---@param player_index integer
---@param pos MapPosition
---@param tags Tags
function editor.save_undo_tags(player_index, pos, tags)
end

-- eager chunk generation at surface creation isn't always enough; the game
-- defers some of it, leaving a black map until generation catches up. re-requesting
-- periodically while a player is inside covers the gap.
--
-- approach copied shamelessley from Blueprint Sandboxes:
-- <https://github.com/cameronleger/blueprint-sandboxes/blob/06b7612d/control.lua#L221-L222>,
-- <https://github.com/cameronleger/blueprint-sandboxes/blob/06b7612d/scripts/remote-view.lua#L106-L118>
tools.on_nth_tick(300, function()
    local charted = {}
    for _, player in pairs(game.players) do
        local surface = player.surface
        if surface and surface.valid and string.find(surface.name, commons.surface_name_pattern) then
            local key = player.force.name .. surface.name
            if not charted[key] then
                surface.request_to_generate_chunks(player.position, 8)
                player.force.chart_all(surface)
                charted[key] = true
            end
        end
    end
end)

return editor
