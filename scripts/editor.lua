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

    local exit_flow = frame.add { type = "flow", direction = "horizontal" }
    local b = exit_flow.add {
        type = "button",
        caption = { button_prefix .. ".exit_editor" },
        name = prefix .. "-exit_editor",
        tooltip = { tooltip_prefix .. ".exit" }
    }
    b.style.width = 160

    b = exit_flow.add {
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
        tooltip = { prefix .. "-tooltip.title" }
    }
    ftitle.style.width = 300
end

-----------------------------------------------------------------

tools.on_event(defines.events.on_gui_elem_changed,
    ---@param e EventData.on_gui_elem_changed
    function(e)
        local player = game.players[e.player_index]
        local name
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

---@param surface LuaSurface
---@param x number
---@param y number
---@return number
---@return number
function editor.find_room(surface, x, y)
    local count = 0
    while true do
        local entities = surface.find_entities({ { x - 1, y - 1 }, { x + 1, y + 1 } })
        if #entities == 0 then break end
        x = x + 1
        if x > EDITOR_SIZE / 2 - 1 then
            x = -EDITOR_SIZE / 2 + 1
            y = y + 1
            if y > EDITOR_SIZE / 2 - 1 then y = -EDITOR_SIZE / 2 + 1 end
        end
        count = count + 1
        if count > 1000 then break end
    end
    return x, y
end

---@param player LuaPlayer
---@param processor LuaEntity
function editor.edit_selected(player, processor)
    if storage.last_click and storage.last_click > game.tick - 120 then return end
    storage.last_click = game.tick

    if not processor or not processor.valid then return end

    local procinfo = get_procinfo(processor, true)
    ---@cast procinfo -nil
    local vars = get_vars(player)
    vars.procinfo = procinfo
    vars.processor = processor
    local surface = editor.get_or_create_surface(procinfo)

    if procinfo.is_packed then
        build.restore_packed_circuits(procinfo)
        input.apply_parameters(procinfo)
    end

    local x, y = editor.find_room(surface, 0, 0)
    procinfo.origin_surface_name = player.surface.name
    procinfo.origin_surface_position = player.position
    player.teleport({ x, y }, surface)
end

---@param procinfo ProcInfo
---@param player LuaPlayer
local function exit_player(procinfo, player)
    local origin_surface_name = procinfo.origin_surface_name
    local origin_surface_position = procinfo.origin_surface_position

    local origin_surface = game.surfaces[origin_surface_name]
    if not origin_surface or not origin_surface.valid then
        origin_surface_name = "nauvis"
        origin_surface_position = { x = 0, y = 0 }
    end
    player.teleport(origin_surface_position, origin_surface_name)
end

---@param e EventData.on_gui_click
local function on_exit_editor(e)
    local player = game.players[e.player_index]
    ccutils.close_all(player)
    editor.close_editor_panel(player)

    local vars = get_vars(player)
    local procinfo = vars.procinfo
    vars.is_standard_exit = true

    exit_player(procinfo, player)
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
    else
        build.destroy_packed_circuit(procinfo)
        build.connect_all_iopoints(procinfo)
        input.apply_parameters(procinfo)
        display.restore(procinfo)
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

            local empty_stack = player.get_main_inventory().find_empty_stack()
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

tools.on_gui_click(prefix .. "-exit_editor", on_exit_editor)
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
        surface = game.create_surface(surface_name, {
            width = EDITOR_SIZE,
            height = EDITOR_SIZE
        })

        surface.always_day = true
        surface.show_clouds = false
        surface.request_to_generate_chunks({ 0, 0 }, 8)
        surface.force_generate_chunk_requests()
        surface.destroy_decoratives({})

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
        text = iopoint_info.label
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

        local iopoint_info = get_iopoint_info(procinfo, iopole)
        if not iopoint_info then return end
        iopoint_info.label = e.element.text
        build.update_io_text(iopoint_info)
    elseif e.element.name == prefix .. "-title" then
        local procinfo = vars.procinfo --[[@as ProcInfo]]
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
        if player.surface == surface then exit_player(procinfo, player) end
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
            if type(id)=="number" then
                rendering.get_object_by_id(id).destroy()
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

    local is_standard_exit = vars.is_standard_exit
    vars.is_standard_exit = false

    if procinfo and not procinfo.processor.valid then
        vars.procinfo = nil
        return
    end

    -- Exiting surface
    if procinfo and procinfo.surface and procinfo.surface.valid and
        procinfo.surface.index == e.surface_index then
        editor.close_iopanel(player)
        editor.close_editor_panel(player)

        player.opened = nil
        vars.procinfo = nil
        vars.processor = nil
        procinfo.tick = game.tick
        build.save_packed_circuits(procinfo)
        if (procinfo.is_packed) then
            if is_standard_exit then
                editor.delete_surface(procinfo)
                local _, recursionError = build.create_packed_circuit(procinfo)
                input.apply_parameters(procinfo)
                if recursionError then
                    player.print {
                        message_prefix .. ".recursion_error", recursionError
                    }
                end
            else
                build.destroy_packed_circuit(procinfo)
                build.connect_all_iopoints(procinfo)
                procinfo.is_packed = false
            end
        end
    end

    local surface_name = player.surface.name
    procinfo = storage.surface_map[surface_name]
    if procinfo then
        vars.procinfo = procinfo
        vars.processor = procinfo.processor
        editor.create_editor_panel(player, procinfo)
    end
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
    local label = ""
    local index
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

---@param entity LuaEntity
---@param e EventData.on_robot_built_entity | EventData.script_raised_built | EventData.on_built_entity | EventData.script_raised_revive
local function on_build(entity, e)
    if not entity or not entity.valid then return end

    local name = entity.name
    local procinfo = storage.surface_map and
        storage.surface_map[entity.surface.name]

    if name == internal_iopoint_name then
        if not procinfo then
            entity.destroy()
            return
        end
        init_internal_point(entity, e.tags, procinfo)
    elseif name == internal_connector_name then
        if not procinfo then
            entity.destroy()
            return
        end
        entity.operable = false
    elseif name == display_name then
        if not procinfo then
            entity.destroy()
            return
        end
    elseif name == input_name then
        if not procinfo then
            entity.destroy()
            return
        end
    elseif name == "entity-ghost" and is_allowed(entity.ghost_name) then
        if entity.ghost_name == internal_iopoint_name or
            entity.ghost_name == internal_connector_name or
            entity.ghost_name == display_name or
            entity.ghost_name == input_name
        then
            if not procinfo then
                entity.destroy()
                return
            end
            local d, new = entity.silent_revive { raise_revive = true }
        else
            if not procinfo then return end
            if e.player_index then
                local player = game.players[e.player_index]
                local controller_type = player.controller_type
                if controller_type == defines.controllers.god then
                    entity.revive { raise_revive = true }
                end
            end
        end
    elseif procinfo and not is_allowed(name) then
        if settings.global[prefix .. "-allow-external"].value then
            if procinfo.is_packed then
                if e.player_index then
                    local player = game.players[e.player_index]
                    player.create_local_flying_text {
                                        text = { message_prefix .. ".not_allowed_packed" },
                                        position = entity.position
                    }
                end
            end
            return
        else
            if e.player_index then
                local player = game.players[e.player_index]
                player.create_local_flying_text {
                        text = { message_prefix .. ".not_allowed" },
                        position = entity.position
                }
            end
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

---@param e EventData.on_marked_for_deconstruction
local function on_marked_for_deconstruction(e)
    local player_index = e.player_index
    if not player_index then return end

    local player = game.players[e.player_index]
    local entity = e.entity
    local procinfo = storage.surface_map and
        storage.surface_map[entity.surface.name]
    if not procinfo then return end

    local controller_type = player.controller_type
    if controller_type == defines.controllers.god then
        if entity.name == internal_iopoint_name then
            editor.destroy_internal_iopoint(entity)
        end
        entity.destroy()
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
        editor.destroy_internal_iopoint(entity)
        if ev.buffer then ev.buffer.clear() end
    elseif entity.name == internal_connector_name then
        if ev.buffer then ev.buffer.clear() end
    elseif entity.name == display_name then
        if ev.buffer then ev.buffer.clear() end
    elseif entity.name == input_name then
        if ev.buffer then ev.buffer.clear() end
    end
end

---@param ev EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
local function on_player_mined_entity(ev) on_mined(ev) end

local mine_filter = {
    { filter = 'name', name = internal_iopoint_name },
    { filter = 'name', name = internal_connector_name },
    { filter = 'name', name = display_name },
    { filter = 'name', name = input_name }
}
tools.on_event(defines.events.on_player_mined_entity, on_player_mined_entity,
    mine_filter)
tools.on_event(defines.events.on_robot_mined_entity, on_mined, mine_filter)
tools.on_event(defines.events.on_entity_died, on_mined, mine_filter)
tools.on_event(defines.events.script_raised_destroy, on_mined, mine_filter)

---@type table<string, boolean>
local forbidden_prototypes = {

    ["container"] = true,
    ["logistic-container"] = true,
    ["assembling-machine"] = true,
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

return editor
