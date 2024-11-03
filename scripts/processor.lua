local migration = require("__flib__.migration")

local commons = require("scripts.commons")
local runtime = require("scripts.runtime")

local prefix = commons.prefix
local tools = require("scripts.tools")
local ccutils = require("scripts.ccutils")
local display = require("scripts.display")
local input = require("scripts.input")
local build = require("scripts.build")

local editor = require("scripts.editor")
local inspectlib = require("scripts.inspect")
local models_lib = require("scripts.models_lib")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local get_procinfo = build.get_procinfo

local show_names
local clear_rendering
local show_iopoint_label

---@type ProcInfoTable
procinfos = {}

-----------------------------------------------------

local processor_name = commons.processor_name
local processor_name_1x1 = commons.processor_name_1x1
local processor_pattern = commons.processor_pattern

local iopoint_name = commons.iopoint_name
local epole_name = prefix .. "-epole"
local accu_name = prefix .. "-accu"
local device_name = commons.device_name
local display_name = commons.display_name
local input_name = commons.input_name

local iopoint_with_alt = settings.startup["compaktcircuit-iopoint_with_alt"]
    .value
---@cast iopoint_with_alt boolean

local iopoint_default_color = commons.get_color(
    settings.startup["compaktcircuit-iopoint_default_color"]
    .value, { 0, 1, 0, 1 })
---@cast iopoint_default_color Color

local iopoint_connected_color = commons.get_color(
    settings.startup["compaktcircuit-iopoint_connected_color"]
    .value, { 1, 0, 0, 1 })
---@cast iopoint_connected_color Color

local iopoint_disconnected_color = commons.get_color(
    settings.startup["compaktcircuit-iopoint_disconnected_color"]
    .value, { 0.5, 0.5, 0.5, 1 })
---@cast iopoint_disconnected_color Color

local mine_processor_as_tags_setting = prefix .. "-mine_processor_as_tags"

---@type string[]
commons.entities_to_destroy = tools.table_concat {
    commons.packed_entities, { iopoint_name, epole_name, accu_name, device_name }
}

---Find processor associated with entry
---@param entry LuaEntity
---@return LuaEntity?
local function find_processor(entry)
    local processors = entry.surface.find_entities_filtered {
        name = { processor_name, processor_name_1x1 },
        position = entry.position
    }
    if #processors >= 1 then return processors[1] end
    return nil
end

---Insert new point
---@param iopoint_positions MapPosition[]
---@param x1 number
---@param y1 number
---@param count integer
---@param xi number
---@param yi number
local function create_iopoint_position(iopoint_positions, x1, y1, count, xi, yi)
    for i = 1, count do
        table.insert(iopoint_positions, { x = x1, y = y1 })
        x1 = x1 + xi
        y1 = y1 + yi
    end
end

---@type MapPosition[]
local iopoint_positions_2x2 = {}
create_iopoint_position(iopoint_positions_2x2, -0.8, 0.8, 5, 0.4, 0)
create_iopoint_position(iopoint_positions_2x2, 0.8, 0.4, 3, 0.0, -0.4)
create_iopoint_position(iopoint_positions_2x2, 0.8, -0.8, 5, -0.4, 0)
create_iopoint_position(iopoint_positions_2x2, -0.8, -0.4, 3, 0.0, 0.4)

---@class IOPointRange
---@field index integer
---@field count integer

---@type table<defines.direction, IOPointRange[]>
local iopoint_ranges_2x2 = {

    [defines.direction.north] = { { index = 1, count = 16 } },
    [defines.direction.east] = {
        { index = 13, count = 4 }, { index = 1, count = 12 }
    },
    [defines.direction.south] = { { index = 9, count = 8 }, { index = 1, count = 8 } },
    [defines.direction.west] = { { index = 5, count = 12 }, { index = 1, count = 4 } }
}

local coord_1x1 = 0.3

--- @type MapPosition[]
local iopoint_positions_1x1 = {
    { x = 0,          y = coord_1x1 }, { x = coord_1x1, y = 0 }, { x = 0, y = -coord_1x1 },
    { x = -coord_1x1, y = 0 }
}

---@type table<defines.direction, IOPointRange[]>
local iopoint_ranges_1x1 = {
    [defines.direction.north] = { { index = 1, count = 4 } },
    [defines.direction.east] = { { index = 4, count = 1 }, { index = 1, count = 3 } },
    [defines.direction.south] = { { index = 3, count = 2 }, { index = 1, count = 2 } },
    [defines.direction.west] = { { index = 2, count = 3 }, { index = 1, count = 1 } }
}

---Draw circle on IO point
---@param point LuaEntity
local function draw_iopoint_sprite(point)
    local scale = 0.1
    rendering.draw_sprite {
        surface = point.surface,
        sprite = prefix .. "-circle",
        target = point,
        x_scale = scale,
        y_scale = scale,
        tint = iopoint_default_color,
        only_in_alt_mode = iopoint_with_alt
    }
end

--- Initialize processor
---@param procinfo ProcInfo
local function init_procinfo(procinfo)
    local processor = procinfo.processor
    if not processor.valid then return end
    local position = processor.position
    local x = position.x
    local y = position.y
    local surface = processor.surface
    ---@type LuaEntity[]
    local iopoints = {}

    -- create device for consumption
    local entries = surface.find_entities_filtered {
        name = device_name,
        position = processor.position,
        radius = 0.2
    }
    local entry
    if #entries == 1 then
        entry = entries[1]
    else
        entry = processor.surface.create_entity {
            name = device_name,
            position = processor.position,
            force = processor.force
        }
        entry.destructible = false
    end

    local xradius, yradius = tools.get_radius(processor)
    local area = { { x - xradius, y - yradius }, { x + xradius, y + yradius } }
    local ghosts = surface.find_entities_filtered {
        name = "entity-ghost",
        ghost_name = iopoint_name,
        area = area
    }
    for _, g in pairs(ghosts) do g.silent_revive { raise_revive = true } end

    local find_count = 0

    local ranges
    local positions
    if processor.name == processor_name then
        ranges = iopoint_ranges_2x2[processor.direction]
        positions = iopoint_positions_2x2
    else
        ranges = iopoint_ranges_1x1[processor.direction]
        positions = iopoint_positions_1x1
    end

    for _, range in ipairs(ranges) do
        for index = range.index, range.index + range.count - 1 do
            local x1 = x + positions[index].x
            local y1 = y + positions[index].y
            area = { { x1 - 0.05, y1 - 0.05 }, { x1 + 0.05, y1 + 0.05 } }
            local point
            local points = surface.find_entities_filtered {
                name = iopoint_name,
                area = area
            }
            if #points == 0 then
                point = surface.create_entity {
                    name = iopoint_name,
                    position = { x1, y1 },
                    force = processor.force
                }
            else
                point = points[1]
                find_count = find_count + 1
            end

            ---@cast point -nil
            draw_iopoint_sprite(point)

            point.destructible = false
            point.minable = false
            table.insert(iopoints, point)
        end
    end

    procinfo.iopoints = iopoints
    processor.rotatable = false
    procinfo.draw_version = 1
    editor.draw_sprite(procinfo)

    if procinfo.is_packed then
        if procinfo.blueprint or procinfo.circuits then
            build.create_packed_circuit(procinfo)
        end
    end
end

---@param procinfo ProcInfo
local function draw_iopoints(procinfo)
    if not procinfo.iopoints then return end

    for _, point in pairs(procinfo.iopoints) do
        if point.valid then draw_iopoint_sprite(point) end
    end
end

---@param entity LuaEntity
---@param e EventData.on_robot_built_entity | EventData.script_raised_built | EventData.script_raised_revive | EventData.on_built_entity
---@param  revive boolean?
local function on_build(entity, e, revive)
    if not entity or not entity.valid then return end

    local name = entity.name
    if string.find(name, processor_pattern) then
        local procinfo = get_procinfo(entity, true)
        ---@cast procinfo -nil

        local tags = e.tags
        ---@cast tags ProcInfo
        if not tags then
            tags = (e.stack and e.stack.is_item_with_tags and e.stack.tags) --[[@as ProcInfo]]
        end

        if tags then
            if tags.blueprint then
                procinfo.blueprint = tags.blueprint
            elseif tags.circuits then
                procinfo.circuits = tags.circuits and
                    helpers.json_to_table(tags.circuits --[[@as string]]) --[[@as Circuit[]]
            end
            procinfo.model = tags.model
            procinfo.sprite1 = tags.sprite1
            procinfo.sprite2 = tags.sprite2
            procinfo.label = tags.label
            procinfo.is_packed = true
            procinfo.tick = tags.tick
            procinfo.value_id = tags.value_id
            if tags.input_values then
                procinfo.input_values =
                    helpers.json_to_table(tags.input_values --[[@as string]]) --[[@as table<string, any> ]]
            end
            if procinfo.model then
                local model = build.get_model(entity.force, entity.name,
                    procinfo.model)

                if model and procinfo.tick and model.tick > procinfo.tick then
                    procinfo.sprite1 = model.sprite1
                    procinfo.sprite2 = model.sprite2
                    procinfo.blueprint = model.blueprint
                    procinfo.tick = game.tick
                end
            end
        end

        if not IsProcessorRebuilding then
            procinfo.value_id = tools.get_id()
        else
            tools.upgrade_id(procinfo.value_id)
        end

        init_procinfo(procinfo)
    elseif name == display_name then
        local tags = e.tags
        if not tags then
            tags = (e.stack and e.stack.is_item_with_tags and e.stack.tags) --[[@as Display]]
        end
        if tags then display.register(entity, tags --[[@as Display]]) end
    elseif name == input_name then
        local tags = e.tags
        if not tags then
            tags = (e.stack and e.stack.is_item_with_tags and e.stack.tags) --[[@as Display]]
        end
        if not IsProcessorRebuilding and tags then
            tags.value_id = tools.get_id()
        elseif tags then
            tools.upgrade_id(tags.value_id)
        end
        input.register(entity, tags --[[@as Input]])
    end
end

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

    on_build(entity, ev, true)
end

---@param e EventData.on_built_entity
local function on_player_built(e)
    local entity = e.entity

    on_build(entity, e)
end

---@param processor LuaEntity
---@return ProcInfo
local function destroy_processor(processor)
    local procinfo = procinfos[processor.unit_number]
    if procinfo then
        local surface_name = editor.get_surface_name(procinfo.processor)
        local surface = game.surfaces[surface_name]

        -- case clone
        if surface and storage.surface_map[surface_name] == procinfo then
            editor.clean_surface(procinfo)
            game.delete_surface(surface_name)
            storage.surface_map[surface_name] = nil
        end
        tools.destroy_entities(processor, commons.entities_to_destroy)
        procinfos[processor.unit_number] = nil
    end
    return procinfo
end

---@param e any
local function on_mined(e)
    local entity = e.entity

    if not entity or not entity.valid then return end

    -- debug("mine:" .. entity.name)
    if string.find(entity.name, processor_pattern) then
        local procinfo = destroy_processor(entity)

        if not settings.global[mine_processor_as_tags_setting].value then
            return
        end

        if e.name == defines.events.on_player_mined_entity and procinfo and
            procinfo.blueprint then
            local buffer = e.buffer
            if not buffer then return end

            buffer.clear()
            buffer.insert { name = commons.processor_with_tags, count = 1 }
            buffer[1].set_tag("blueprint", procinfo.blueprint)
            if procinfo.model then
                buffer[1].set_tag("model", procinfo.model)
            end
        end
    elseif entity.name == iopoint_name then
        if e.buffer then e.buffer.clear() end
    elseif entity.name == display_name then
        if e.buffer then e.buffer.clear() end
        display.mine(entity)
    elseif entity.name == input_name then
        if e.buffer then e.buffer.clear() end
        input.mine(entity)
    end
end

---@param ev EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
local function on_player_mined_entity(ev) on_mined(ev) end

---@param event EventData.on_gui_opened
local function on_gui_open_processor_panel(event)
    local player = game.players[event.player_index]
    local entity = event.entity
    if not entity or not entity.valid then return end

    if entity.name == device_name then
        player.opened = nil
        local processor = find_processor(entity)
        if not processor then return end

        editor.edit_selected(player, processor)
    elseif entity.name == iopoint_name then
        player.opened = nil
    end
end

tools.on_event(defines.events.on_gui_opened, on_gui_open_processor_panel)

local build_filter = tools.table_concat {
    {
        { filter = 'name', name = processor_name },
        { filter = 'name', name = processor_name_1x1 },
        { filter = 'name', name = display_name },
        { filter = 'name', name = input_name }
    }
}

tools.on_event(defines.events.on_built_entity, on_player_built)
tools.on_event(defines.events.on_robot_built_entity, on_robot_built)
tools.on_event(defines.events.script_raised_built, on_script_built)
tools.on_event(defines.events.script_raised_revive, on_script_revive)

local mine_filter = {
    { filter = 'name', name = processor_name },
    { filter = 'name', name = processor_name_1x1 },
    { filter = 'name', name = iopoint_name },
    { filter = 'name', name = commons.device_name },
    { filter = 'name', name = commons.display_name },
    { filter = 'name', name = commons.input_name }
}

tools.on_event(defines.events.on_player_mined_entity, on_player_mined_entity,
    mine_filter)
tools.on_event(defines.events.on_robot_mined_entity, on_mined, mine_filter)
tools.on_event(defines.events.on_entity_died, on_mined, mine_filter)
tools.on_event(defines.events.script_raised_destroy, on_mined, mine_filter)

---@param bp LuaItemStack
---@param mapping table<integer, LuaEntity>
---@param surface LuaSurface
local function register_mapping(bp, mapping, surface)
    if next(procinfos) == nil then return end

    local bp_count = bp.get_blueprint_entity_count()
    if #mapping ~= 0 then
        for index = 1, bp_count do
            local entity = mapping[index]
            if entity and entity.valid then
                if string.find(entity.name, processor_pattern) then
                    build.set_processor_tags(bp, index, entity)
                elseif entity.name == commons.internal_iopoint_name then
                    build.set_iopoint_tags(bp, index, entity)
                elseif entity.name == display_name then
                    display.set_bp_tags(bp, index, entity)
                elseif entity.name == input_name then
                    input.set_bp_tags(bp, index, entity)
                end
            end
        end
    elseif bp_count > 0 then
        local bp_entities = bp.get_blueprint_entities()
        if bp_entities then
            for index = 1, bp_count do
                local entity = bp_entities[index]
                if string.find(entity.name, processor_pattern) then
                    local entities = surface.find_entities_filtered {
                        name = { processor_name, processor_name_1x1 },
                        position = entity.position,
                        radius = 0.1
                    }
                    if #entities > 0 then
                        local processor = entities[1]
                        build.set_processor_tags(bp, entity.entity_number,
                            processor)
                    end
                elseif entity.name == commons.internal_iopoint_name then
                    local procinfo = storage.surface_map[surface.name]
                    if procinfo then
                        local entities =
                            surface.find_entities_filtered {
                                name = entity.name,
                                position = entity.position,
                                radius = 0.1
                            }
                        if #entities > 0 then
                            build.set_iopoint_tags(bp, index, entities[1])
                        end
                    end
                elseif entity.name == display_name then
                    local entities = surface.find_entities_filtered {
                        name = display_name,
                        position = entity.position,
                        radius = 0.1
                    }
                    if #entities > 0 then
                        display.set_bp_tags(bp, index, entities[1])
                    end
                elseif entity.name == input_name then
                    local entities = surface.find_entities_filtered {
                        name = input_name,
                        position = entity.position,
                        radius = 0.1
                    }
                    if #entities > 0 then
                        input.set_bp_tags(bp, index, entities[1])
                    end
                end
            end
        end
    end
end

local function on_register_bp(e)
    local player = game.get_player(e.player_index)
    ---@cast player -nil
    local vars = tools.get_vars(player)
    if e.gui_type == defines.gui_type.item and e.item and e.item.is_blueprint and
        e.item.is_blueprint_setup() and player.cursor_stack and
        player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint and
        not player.cursor_stack.is_blueprint_setup() then
        vars.previous_bp = { blueprint = e.item, tick = e.tick }
    else
        vars.previous_bp = nil
    end
end

---@param player LuaPlayer
---@return LuaItemStack?
local function get_bp_to_setup(player)
    -- normal drag-select
    local bp = player.blueprint_to_setup
    if bp and bp.valid_for_read and bp.is_blueprint_setup() then return bp end

    -- alt drag-select (skips configuration dialog)
    bp = player.cursor_stack
    if bp and bp.valid_for_read and bp.is_blueprint and bp.is_blueprint_setup() then
        while bp.is_blueprint_book do
            bp = bp.get_inventory(defines.inventory.item_main)[bp.active_index]
        end
        return bp
    end

    -- update of existing blueprint
    local previous_bp = get_vars(player).previous_bp
    if previous_bp and previous_bp.tick == game.tick and previous_bp.blueprint and
        previous_bp.blueprint.valid_for_read and
        previous_bp.blueprint.is_blueprint_setup() then
        return previous_bp.blueprint
    end
end

tools.on_event(defines.events.on_player_setup_blueprint,
    ---@param e EventData.on_player_setup_blueprint
    function(e)
        local player = game.players[e.player_index]
        ---@type table<integer, LuaEntity>
        local mapping = e.mapping.get()
        local bp = get_bp_to_setup(player)
        if bp then register_mapping(bp, mapping, player.surface) end
    end)

script.on_event("on_script_setup_blueprint",
    ---@param e EventData.on_player_setup_blueprint
    function(e)
        ---@type table<integer, LuaEntity>
        local mapping = e.mapping
        register_mapping(e.stack, mapping, e.surface)
    end)
    
tools.on_event(defines.events.on_gui_closed, on_register_bp)

---@param ev EventData.on_entity_cloned
local function on_entity_cloned(ev)
    local source = ev.source
    local dest = ev.destination
    local source_name = source.name

    if string.find(source_name, processor_pattern) then
        local src_procinfo = get_procinfo(source, true)
        ---@cast src_procinfo -nil
        local dst_procinfo = get_procinfo(dest, true)
        ---@cast dst_procinfo -nil

        dst_procinfo.blueprint = src_procinfo.blueprint
        dst_procinfo.model = src_procinfo.model
        dst_procinfo.sprite1 = src_procinfo.sprite1
        dst_procinfo.sprite2 = src_procinfo.sprite2
        dst_procinfo.tick = src_procinfo.tick
        dst_procinfo.value_id = src_procinfo.value_id
        dst_procinfo.label = src_procinfo.label
        dst_procinfo.input_values = src_procinfo.input_values

        if src_procinfo.origin_surface_name == source.surface.name then
            dst_procinfo.origin_surface_name = dest.surface.name
            local dx = dest.position.x - source.position.x
            local dy = dest.position.y - source.position.y
            dst_procinfo.origin_surface_position = {
                x = src_procinfo.origin_surface_position.x + dx,
                y = src_procinfo.origin_surface_position.y + dy
            }
        end

        for _, player in pairs(game.players) do
            local vars = get_vars(player)
            local procinfo = vars.procinfo
            if procinfo == src_procinfo then
                vars.procinfo = dst_procinfo
            end
        end

        if src_procinfo.is_packed then
            dst_procinfo.is_packed = true
        else
            dst_procinfo.is_packed = false
            if src_procinfo.surface then
                build.disconnect_all_iopoints(src_procinfo)
                if src_procinfo.in_pole then
                    local connectors = src_procinfo.in_pole.get_wire_connectors(false)
                    for _, connector in pairs(connectors) do
                        connector.disconnect_all()
                    end
                end

                local surface = src_procinfo.surface
                dst_procinfo.surface = surface
                src_procinfo.surface = nil
                dst_procinfo.in_pole = src_procinfo.in_pole
                src_procinfo.in_pole = nil
                src_procinfo.is_packed = true

                local surface_name = editor.get_surface_name(
                    dst_procinfo.processor)
                local src_surface_name =
                    editor.get_surface_name(src_procinfo.processor)
                storage.surface_map[src_surface_name] = nil
                storage.surface_map[surface_name] = dst_procinfo
                if surface then surface.name = surface_name end

                dst_procinfo.iopoint_infos = tools.table_dup(
                    src_procinfo.iopoint_infos)
                src_procinfo.iopoint_infos = {}

                init_procinfo(dst_procinfo)
                build.connect_all_iopoints(dst_procinfo)
                editor.connect_energy(dst_procinfo)
                if not dst_procinfo.is_packed then
                    display.update_for_cloning(src_procinfo, dst_procinfo)
                end
                return
            end
        end
        init_procinfo(dst_procinfo)
    elseif source_name == commons.packed_display_name then
        display.clone_packed(source, dest)
    elseif source_name == commons.packed_input_name then
        input.clone(source, dest)
    end
end

local clone_filter = tools.create_name_filter {
    {
        processor_name, processor_name_1x1, commons.packed_display_name,
        commons.packed_input_name
    }
}

script.on_event(defines.events.on_entity_cloned, on_entity_cloned, clone_filter)

local function move_processor(context)
    local entity = context.moved_entity
    local start_pos = context.start_pos
    local name = entity.name
    local player = game.players[context.player_index]
    if name ~= processor_name and name ~= processor_name_1x1 then return end

    local procinfo = get_procinfo(entity, false)
    if not procinfo then return end

    local position = entity.position
    local dx = position.x - start_pos.x
    local dy = position.y - start_pos.y

    local xradius, yradius = tools.get_radius(entity)
    local entities = entity.surface.find_entities_filtered {
        area = {
            left_top = { x = start_pos.x - xradius, y = start_pos.y - yradius },
            right_bottom = {
                x = start_pos.x + xradius,
                y = start_pos.y + yradius
            }
        }
    }

    local move_list = {}
    local failed = false
    for _, e in pairs(entities) do
        name = e.name
        if name ~= processor_name and name ~= processor_name_1x1 then
            local p = e.position
            e.teleport({ x = p.x + dx, y = p.y + dy })
            table.insert(move_list, e)
            if name == iopoint_name then
                local connections = e.circuit_connected_entities
                if connections then
                    for _, entities in pairs(connections) do
                        for _, dst in pairs(entities) do
                            if e.surface == dst.surface and
                                not e.can_wires_reach(dst) then
                                failed = true
                                player.create_local_flying_text {
                                    text = { prefix .. "-message.wires_too_long" },
                                    position = position
                                }
                                goto end_loop
                            end
                        end
                    end
                end
            end
        end
    end
    ::end_loop::
    if failed then
        for _, e in pairs(move_list) do
            local p = e.position
            e.teleport({ x = p.x - dx, y = p.y - dy })
        end
        entity.teleport({ x = start_pos.x, y = start_pos.y })
    end
end

local function picker_dolly_install()
    if remote.interfaces["PickerDollies"] and
        remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
        script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"),
            move_processor)
        remote.call("PickerDollies", "add_blacklist_name", iopoint_name)
        remote.call("PickerDollies", "remove_blacklist_name", processor_name)
        remote.call("PickerDollies", "remove_blacklist_name", processor_name_1x1)
    end
end

local function factory_organizer_install()
    if remote.interfaces["factory_organizer"] then
        remote.add_interface("compaktcircuit_move", {
            ---@param entity LuaEntity
            ---@return LuaEntity[] ?
            collect = function(entity)
                local name = entity.name
                local processor
                if name == iopoint_name then
                    processor = find_processor(entity)
                    if not processor then return nil end
                else
                    if name ~= processor_name and name ~= processor_name_1x1 then
                        return nil
                    end
                    processor = entity
                end
                local xradius, yradius = processor.tile_width / 2,
                    processor.tile_height / 2
                local start_pos = processor.position
                local entities = processor.surface.find_entities_filtered {
                    area = {
                        left_top = {
                            x = start_pos.x - xradius,
                            y = start_pos.y - yradius
                        },
                        right_bottom = {
                            x = start_pos.x + xradius,
                            y = start_pos.y + yradius
                        }
                    }
                }
                return entities
            end
        })
        remote.call("factory_organizer", "add_collect_method", processor_name,
            "compaktcircuit_move", "collect")
        remote.call("factory_organizer", "add_collect_method",
            processor_name_1x1, "compaktcircuit_move", "collect")
        remote.call("factory_organizer", "add_collect_method",
            iopoint_name, "compaktcircuit_move", "collect")
    end
end

local function on_init()
    storage.procinfos = {}
    storage.surface_map = {}
    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    picker_dolly_install()
end

local function on_load()
    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    picker_dolly_install()
    factory_organizer_install()
end

tools.on_init(on_init)
tools.on_load(on_load)

---@param e EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(e)
    local src = e.source
    local dst = e.destination
    local player = game.players[e.player_index]

    if not dst or not dst.valid or not src or not src.valid then return end

    if string.find(src.name, processor_pattern) and src.name == dst.name then
        local src_procinfo = get_procinfo(src)
        ---@cast src_procinfo -nil
        local dst_procinfo = get_procinfo(dst)
        ---@cast dst_procinfo -nil

        models_lib.copy_from(dst_procinfo, src_procinfo, src_procinfo.is_packed)
        dst_procinfo.model = src_procinfo.model
        dst_procinfo.tick = src_procinfo.tick
        dst_procinfo.sprite1 = src_procinfo.sprite1
        dst_procinfo.sprite2 = src_procinfo.sprite2
        dst_procinfo.label = src_procinfo.label
        dst_procinfo.input_values = src_procinfo.input_values
        input.set_values(dst_procinfo)
        editor.draw_sprite(dst_procinfo)
    else
        local dst = player.selected
        local src = player.entity_copy_source

        ---@cast dst -nil
        ---@cast src -nil
        if src.name == iopoint_name and dst.name == iopoint_name then
            local src_processor = find_processor(src)
            local dst_processor = find_processor(dst)
            if not src_processor or not dst_processor or src_processor ~=
                dst_processor then
                return
            end

            local procinfo = get_procinfo(src_processor, false)
            if not procinfo or not procinfo.iopoints then return end

            local src_index
            for index, point in pairs(procinfo.iopoints) do
                if point.unit_number == src.unit_number then
                    src_index = index
                    break
                end
            end

            local dst_index
            for index, point in pairs(procinfo.iopoints) do
                if point.unit_number == dst.unit_number then
                    dst_index = index
                    break
                end
            end

            local surface = src_processor.surface
            local cc_name = prefix .. "-cc"

            ---@param pole LuaEntity
            ---@return {connector_id:defines.wire_connector_id, dst_connector:LuaWireConnector}[]
            local function disconnect_neighbours(pole)
                local connectors = pole.get_wire_connectors(false)
                ---@type {connector_id:defines.wire_connector_id, dst_connector:LuaWireConnector}[]
                local result = {}
                for connector_id, connector in pairs(connectors) do
                    for _, connection in pairs(connector.real_connections) do
                        local t = connection.target.owner
                        if t.surface == surface and t.name ~= cc_name and
                            (connector.wire_type == defines.wire_type.red or
                                connector.wire_type == defines.wire_type.green) then
                            connector.disconnect_from(connection.target)
                            table.insert(result, {
                                    connector_id=connector_id,
                                    dst_connector=connection.target
                                })
                        end
                    end
                end
                return result
            end

            ---@param pole LuaEntity
            ---@param connections {connector_id:defines.wire_connector_id, dst_connector:LuaWireConnector}[]
            local function connect_neighbours(pole, connections)
                if not connections then return end
                for _, connection in pairs(connections) do
                    local connector = pole.get_wire_connector(connection.connector_id, true)
                    connector.connect_to(connection.dst_connector, false)
                end
            end

            if not src_index or not dst_index or src_index == dst_index then
                return
            end

            local src_connections = disconnect_neighbours(src)
            local dst_connections = disconnect_neighbours(dst)

            build.switch_iopoints(procinfo, src_index, dst_index)
            if procinfo.is_packed then
                build.create_packed_circuit(procinfo)
            elseif procinfo.iopoint_infos then
                for _, iopoint_info in pairs(procinfo.iopoint_infos) do
                    local index = iopoint_info.index
                    if index == src_index or index == dst_index then
                        build.disconnect_iopole(procinfo, iopoint_info)
                        if index == src_index then
                            iopoint_info.index = dst_index
                        else
                            iopoint_info.index = src_index
                        end
                        build.connect_iopole(procinfo, iopoint_info)
                    end
                end
            end

            connect_neighbours(src, dst_connections)
            connect_neighbours(dst, src_connections)

            clear_rendering(player)
            show_iopoint_label(player)
        end
    end
end

tools.on_event(defines.events.on_entity_settings_pasted,
    on_entity_settings_pasted)

local disconnect_color = { 0.8, 0.8, 0.8, 1 }

---@param info IOPointInfo
---@return Color
local function get_io_color(info)
    local color
    if info.red_wired then
        if info.green_wired then
            color = { 1, 1, 0, 1 }
        else
            color = { 1, 0, 0, 1 }
        end
    elseif info.green_wired then
        color = { 0, 1, 0, 1 }
    else
        color = disconnect_color
    end
    return color
end

---@param player LuaPlayer
---@param processor LuaEntity
show_names = function(player, processor)
    if not player.mod_settings[prefix .. "-show-iopoint-name"].value then
        return
    end

    local procinfo = get_procinfo(processor, false)
    if not procinfo then return end
    if not procinfo.iopoints then return end

    local position = processor.position
    local surface = processor.surface
    local ids = {}
    get_vars(player).id_names = ids

    local proto = prototypes.entity[processor.name]
    local width = proto.tile_width
    local scale = width / 2

    local label = procinfo.label
    if not label then label = procinfo.model end
    if label then
        local words = string.gmatch(label, "%S+")
        local lines = {}
        local line = nil
        for w in string.gmatch(label, "%S+") do
            if not line then
                line = w
            else
                if #line + #w + 1 >= 12 then
                    table.insert(lines, line)
                    line = w
                else
                    line = line .. " " .. w
                end
            end
        end
        if line then table.insert(lines, line) end
        local lcount = #lines
        local hline = 0.24 * width / 2
        local y = -(lcount - 1) / 2 * hline
        for index, line in ipairs(lines) do
            local id = rendering.draw_text {
                text = line,
                surface = surface,

                target = {
                    entity = processor,
                    offset = { x = 0, y = y }
                },
                alignment = "center",
                color = { 1, 1, 1, 0.8 },
                scale = 0.6 * scale,
                vertical_alignment = "middle",
                use_rich_text = true

            }
            table.insert(ids, id)
            y = y + hline
        end
    end

    local iopoint_map = build.get_iopoint_map(procinfo)
    for index, point in ipairs(procinfo.iopoints) do
        local info = iopoint_map[index]
        if info then
            local io_position = point.position
            local dx = io_position.x - position.x
            local dy = io_position.y - position.y

            local color = get_io_color(info)

            local label
            if info.label and info.label ~= "" then
                label = "(" .. tostring(index) .. "):" .. info.label
            else
                label = "(" .. tostring(index) .. ")"
            end

            local input = info.input == true
            local output = info.output ~= false

            local orientation, alignment, offset
            local delta = 0.20
            local sprite_orientation
            if math.abs(dx) >= math.abs(dy) then
                if dx >= 0 then
                    offset = { delta, 0 }
                    orientation = 0
                    alignment = "left"
                    sprite_orientation = 0
                else
                    offset = { -delta, 0 }
                    orientation = 0
                    alignment = "right"
                    sprite_orientation = 0.5
                end
            else
                if dy >= 0 then
                    offset = { 0.0, delta }
                    orientation = 0.25
                    alignment = "left"
                    sprite_orientation = 0.25
                else
                    offset = { 0.0, -delta }
                    orientation = 0.25
                    alignment = "right"
                    sprite_orientation = 0.75
                end
            end

            local id = rendering.draw_text {
                text = label,
                surface = surface,
                target = {
                    entity = point,
                    offset = offset,
                },

                orientation = orientation,
                alignment = alignment,
                color = { 1, 1, 1, 1 },
                scale = 0.8,
                vertical_alignment = "middle",
                use_rich_text = true
            }
            table.insert(ids, id)

            if input or output then
                local sprite_name
                if input then
                    if output then
                        sprite_name = "-arrowd"
                    else
                        sprite_name = "-arrowr"
                    end
                else
                    sprite_name = "-arrow"
                end

                local sprite_scale = 0.4
                local sprite_id = rendering.draw_sprite {
                    surface = surface,
                    sprite = prefix .. sprite_name,
                    target = point,
                    orientation = sprite_orientation,
                    x_scale = sprite_scale * scale,
                    y_scale = sprite_scale * scale,
                    tint = color

                }
                table.insert(ids, sprite_id)
            end
        end
    end
end

---@param player LuaPlayer
clear_rendering = function(player)
    local vars = get_vars(player)

    if vars.id_names then
        for _, id in ipairs(vars.id_names) do id.destroy() end
        vars.id_names = nil
    end
    if vars.selected_id then
        vars.selected_id.destroy()
        vars.selected_id = nil
    end
end

---comment
---@param player LuaPlayer
show_iopoint_label = function(player)
    clear_rendering(player)

    local found_iopoint = player.selected
    local vars = get_vars(player)
    if not found_iopoint then return end

    local pos = found_iopoint.position
    local entities = found_iopoint.surface.find_entities_filtered {
        area = { { pos.x - 1, pos.y - 1 }, { pos.x + 1, pos.y + 1 } },
        name = { processor_name, processor_name_1x1 }
    }
    if #entities == 0 then return end

    local procinfo
    local found_index
    for _, p in pairs(entities) do
        procinfo = get_procinfo(p, false)
        if procinfo and procinfo.iopoints then
            local processor = procinfo.processor
            if processor.valid then
                local pp = processor.position
                if pos.x > pp.x - processor.tile_width / 2 and pos.x < pp.x +
                    processor.tile_width / 2 and pos.y > pp.y -
                    processor.tile_height / 2 and pos.y < pp.y +
                    processor.tile_height / 2 then
                    for index, point in pairs(procinfo.iopoints) do
                        if point.unit_number == found_iopoint.unit_number then
                            found_index = index
                            break
                        end
                    end
                end
            end
        end
        if found_index then break end
    end
    if not found_index then return end

    ---@cast procinfo -nil

    local iopoint_map = build.get_iopoint_map(procinfo)
    local info = iopoint_map[found_index]

    local label
    local color
    if info then
        if info.label and info.label ~= "" then
            label = "(" .. tostring(found_index) .. "):" .. info.label
        else
            label = "(" .. tostring(found_index) .. ")"
        end
        color = get_io_color(info)
    else
        label = tostring(found_index)
        color = disconnect_color
    end
    if vars.selected_id then
        local otext = vars.selected_id --[[@as LuaRenderObject]]
        otext.text = label
    else
        vars.selected_id = rendering.draw_text {
            text = label,
            surface = found_iopoint.surface,
            color = color,
            only_in_alt_mode = false,
            alignment = "center",
            target = { entity = found_iopoint, offset = { 0, -0.7 } },
            use_rich_text = true
        }
    end
end

---@param e EventData.on_selected_entity_changed
local function on_selected_entity_changed(e)
    local player = game.players[e.player_index]
    local selected = player.selected

    clear_rendering(player)
    if selected ~= nil and selected.name == iopoint_name then
        show_iopoint_label(player)
        return
    end

    if selected ~= nil and string.find(selected.name, processor_pattern) then
        inspectlib.show(player, selected)
        show_names(player, selected)
    else
        inspectlib.clear(player)
    end
end

tools.on_event(defines.events.on_selected_entity_changed,
    on_selected_entity_changed)

script.on_event(prefix .. "-click", function(event)
    local player = game.players[event.player_index]
    local selected = player.selected
    if selected and string.find(selected.name, processor_pattern) and
        player.is_cursor_empty() then
        editor.edit_selected(player, selected)
    end
end)

script.on_event(prefix .. "-control-click", function(event)
    local player = game.players[event.player_index]
    local selected = player.selected
    if selected and string.find(selected.name, processor_pattern) and
        player.is_cursor_empty() then
        local procinfo = build.get_procinfo(selected, false)
        if procinfo and build.is_toplevel(procinfo) then
            input.create_property_table(player, procinfo)
        end
    end
end)

---@param player_index integer?
local function purge(player_index)
    log("Purge: on_configuration_changed")

    if not storage.procinfos then return end

    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    local names = {}
    local missings = {}
    local founds = {}
    for _, procinfo in pairs(procinfos) do
        if not procinfo.processor or not procinfo.processor.valid then
            table.insert(missings, procinfo)
        else
            local name = editor.get_surface_name(procinfo.processor)
            names[name] = true
            table.insert(founds, procinfo)
        end
    end

    local todelete = {}
    for _, surface in pairs(game.surfaces) do
        local name = surface.name
        if string.sub(name, 1, 5) == 'proc_' then
            if not names[name] then table.insert(todelete, name) end
        end
    end

    for _, name in pairs(todelete) do
        game.delete_surface(name)
        storage.surface_map[name] = nil
    end

    for _, procinfo in pairs(missings) do
        procinfos[procinfo.unit_number] = nil
    end

    local msg = "Purge: invalid=" .. #missings .. ", valid=" .. #founds ..
        ", invalid surface=" .. #todelete
    log(msg)
    if player_index then game.players[player_index].print(msg); end
end

local function migration_1_0_7(data)
    purge()

    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    if procinfos then
        for _, procinfo in pairs(procinfos) do
            if not procinfo.draw_version then
                for _, point in pairs(procinfo.iopoints) do
                    rendering.draw_circle {
                        color = iopoint_default_color,
                        filled = false,
                        target = point,
                        surface = point.surface,
                        radius = 0.05,
                        width = 1,
                        only_in_alt_mode = iopoint_with_alt
                    }
                end
                procinfo.draw_version = 1
            end

            if procinfo.accu then
                if procinfo.surface and procinfo.surface.valid then
                    editor.connect_energy(procinfo)
                end
            end
        end
    end
end

local regenerate_packed

local function migration_1_0_14(data)
    purge()
    regenerate_packed()
    for _, player in pairs(game.players) do
        if player.force.technologies[commons.prefix .. "-tech"] then
            player.force.recipes[commons.processor_name_1x1].enabled = true
        end
    end
end

local function migration_1_0_15(data)
    storage.models = {

        [commons.processor_name] = {},
        [commons.processor_name_1x1] = {}
    }

    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    if not procinfos then return end

    for _, procinfo in pairs(procinfos) do
        if procinfo.model then
            local processor = procinfo.processor
            local force = processor.force
            local models = build.get_models(force, processor.name)
            if procinfo.blueprint then
                models[procinfo.model] = {
                    blueprint = procinfo.blueprint,
                    name = procinfo.model,
                    tick = game.tick
                }
            elseif procinfo.circuits then
                models[procinfo.model] = {
                    circuits = procinfo.circuits,
                    name = procinfo.model,
                    tick = game.tick
                }
            end
        end
    end
end

local function migration_1_0_17(data)
    local ids = rendering.get_all_objects("compaktcircuit")
    for _, id in ipairs(ids) do
        local target = id.target
        if target then
            if not target.entity.valid then
                id.destroy()
            elseif target.entity.name == iopoint_name then
                id.destroy()
            end
        end
    end

    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    for _, procinfo in pairs(procinfos) do
        if procinfo.processor and procinfo.processor.valid then
            draw_iopoints(procinfo)
        end
    end
end

local function migration_1_0_25(data)
    for _, player in pairs(game.players) do
        local vars = tools.get_vars(player)
        if vars.procinfo and editor.close_editor_panel(player) then
            editor.create_editor_panel(player, vars.procinfo)
            editor.close_iopanel(player)
        end
    end
end

local function migration_1_1_7(data)
    for _, player in pairs(game.players) do
        local vars = tools.get_vars(player)
        if vars.procinfo and editor.close_editor_panel(player) then
            editor.create_editor_panel(player, vars.procinfo)
            ccutils.close_all(player)
        end
    end
end

local function migration_1_1_11()
    display.update_processors()
end

local function migration_2_0_0()
    display.update_rendering()
end

local migrations_table = {

    ["1.0.7"] = migration_1_0_7,
    ["1.0.8"] = function()
        if not storage.procinfos then return end
        procinfos = storage.procinfos --[[@as ProcInfoTable]]
        for _, procinfo in pairs(procinfos) do
            local processor = procinfo.processor
            if processor and processor.valid then
                processor.direction = defines.direction.north
                processor.rotatable = false
            end
        end
    end,
    ["1.0.14"] = migration_1_0_14,
    ["1.0.15"] = migration_1_0_15,
    ["1.0.17"] = migration_1_0_17,
    ["1.0.25"] = migration_1_0_25,
    ["1.1.7"] = migration_1_1_7,
    ["1.1.11"] = migration_1_1_11,
    ["2.0.0"] = migration_2_0_0,
}

local function on_configuration_changed(data)
    runtime.initialize()
    migration.on_config_changed(data, migrations_table)
end

script.on_configuration_changed(on_configuration_changed)

---@param player_index integer
local function all_pack(player_index)
    local player = game.players[player_index]
    local force = player.force
    local used = {}
    for _, player in pairs(game.players) do
        if player.surface then used[player.surface.name] = true end
    end

    local pack_count = 0
    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    for _, procinfo in pairs(procinfos) do
        if procinfo.processor and procinfo.processor.valid and
            procinfo.processor.force == force then
            local surface = procinfo.surface
            if surface and surface.valid and not used[surface.valid] then
                if not procinfo.is_packed then
                    editor.set_packed(procinfo, true)
                    editor.delete_surface(procinfo)
                    pack_count = pack_count + 1
                end
            end
        end
    end

    game.print("Pack #=" .. pack_count)
end

regenerate_packed = function()
    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    if not procinfos then return end
    local pack_count = 0
    for _, procinfo in pairs(procinfos) do
        if procinfo.processor and procinfo.processor.valid and
            procinfo.is_packed and not procinfo.surface then
            editor.regenerate_packed(procinfo)
            pack_count = pack_count + 1
        end
    end

    game.print("Pack #=" .. pack_count)
end

local function repaire_iopoints()
    local pack_count = 0
    local error_list = {}

    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    for i, procinfo in pairs(procinfos) do
        if procinfo.processor and procinfo.processor.valid then
            local surface = procinfo.processor.surface

            if surface then
                local map = {}
                for _, p in pairs(procinfo.iopoints) do
                    map[p.unit_number] = p
                end

                local area = procinfo.processor.bounding_box
                local points = surface.find_entities_filtered {
                    name = iopoint_name,
                    area = area
                }

                for _, point in pairs(points) do
                    if not map[point.unit_number] then
                        table.insert(error_list, point)
                    end
                end
            end
        end
    end
    for _, point in pairs(error_list) do point.destroy() end
    game.print("Error input/output points: " .. #error_list)
end

local function destroy_all()
    procinfos = storage.procinfos --[[@as ProcInfoTable]]
    local copy = tools.table_dup(procinfos)

    local count = 0
    for _, procinfo in pairs(copy) do
        procinfo.processor.destroy { raise_destroy = true }
        count = count + 1
    end
    game.print("#processor=" .. count)
end


commands.add_command("compaktcircuit_purge", { "compaktcircuit_purge_cmd" },
    function(e) purge(e.player_index) end)
commands.add_command("compaktcircuit_pack", { "compaktcircuit_pack" },
    function(e) all_pack(e.player_index) end)
commands.add_command("compaktcircuit_regenerate_packed",
    { "compaktcircuit_regenerate_packed" },
    function(e) regenerate_packed() end)
commands.add_command("compaktcircuit_repair_iopoints",
    { "compaktcircuit_repair_iopoints" },
    function(e) repaire_iopoints() end)
commands.add_command("compaktcircuit_destroy",
    { "compaktcircuit_destroy" },
    function(e) destroy_all() end)

---@param e EventData.on_player_rotated_entity
local function on_player_rotated_entity(e) local entity = e.entity end

tools.on_event(defines.events.on_player_rotated_entity, on_player_rotated_entity)

------------------
