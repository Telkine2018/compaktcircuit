local commons = require("scripts.commons")

local prefix = commons.prefix
local tools = require("scripts.tools")
local ccutils = require("scripts.ccutils")
local input = require("scripts.input")
local display = require("scripts.display")
local comm = require("scripts.comm")

local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip
local EDITOR_SIZE = commons.EDITOR_SIZE

local build = {}

local internal_iopoint_name = commons.internal_iopoint_name
local display_name = commons.display_name
local input_name = commons.input_name

local special = "@"

local iopoint_text_color = commons.get_color(
    settings.startup["compaktcircuit-iopoint_text_color"]
    .value, { 0, 0, 1, 1 })
local iopoint_name = commons.iopoint_name

IsProcessorRebuilding = false

--- @type table<string, string>
local allowed_name_map = {
    ["constant-combinator"] = prefix .. "-cc",
    ["decider-combinator"] = prefix .. "-dc",
    ["selector-combinator"] = prefix .. "-sc",
    ["arithmetic-combinator"] = prefix .. "-ac",
    ["big-electric-pole"] = prefix .. "-cc",
    ["small-electric-pole"] = prefix .. "-cc",
    ["medium-electric-pole"] = prefix .. "-cc",
    [internal_iopoint_name] = prefix .. "-cc",
    [commons.internal_connector_name] = prefix .. "-cc",
    ["substation"] = prefix .. "-cc",
    ["small-lamp"] = prefix .. "-cc",
    [commons.processor_name] = "@",
    [commons.processor_name_1x1] = "@",
    [iopoint_name] = prefix .. "-cc",
    [display_name] = commons.packed_display_name,
    [input_name] = commons.packed_input_name
}
build.allowed_name_map = allowed_name_map

---@type table<string, RemoteInterface>
local remote_name_map = {}
build.remote_name_map = remote_name_map

local idp = "idp"

local textplate_map = {
    ["textplate-small-concrete"] = true,
    ["textplate-large-concrete"] = true,
    ["textplate-small-copper"] = true,
    ["textplate-large-copper"] = true,
    ["textplate-small-glass"] = true,
    ["textplate-large-glass"] = true,
    ["textplate-small-gold"] = true,
    ["textplate-large-gold"] = true,
    ["textplate-small-iron"] = true,
    ["textplate-large-iron"] = true,
    ["textplate-small-plastic"] = true,
    ["textplate-large-plastic"] = true,
    ["textplate-small-steel"] = true,
    ["textplate-large-steel"] = true,
    ["textplate-small-stone"] = true,
    ["textplate-large-stone"] = true,
    ["textplate-small-uranium"] = true,
    ["textplate-large-uranium"] = true,
    ["copper-display-small"] = idp,
    ["copper-display-medium"] = idp,
    ["copper-display"] = idp,
    ["iron-display-small"] = idp,
    ["iron-display-medium"] = idp,
    ["iron-display"] = idp,
    ["steel-display-small"] = idp,
    ["steel-display-medium"] = idp,
    ["steel-display"] = idp
}

build.textplate_map = textplate_map

---@type fun(LuaEntity, boolean?):ProcInfo?
build.get_procinfo = ccutils.get_procinfo

---Get procinfo from processor
---@param procinfo ProcInfo
---@param player LuaPlayer
---@return LuaItemStack | nil
---@return LuaInventory | nil
---@return table<integer, LuaEntity> | nil
function build.create_blueprint(procinfo, player)
    local surface = procinfo.surface
    if not surface or not surface.valid then return nil end

    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]

    bp.set_stack { name = "blueprint", count = 1 }
    local entities = bp.create_blueprint {
        surface = surface,
        force = procinfo.processor.force,
        area = {
            { -EDITOR_SIZE / 2 - 1, -EDITOR_SIZE / 2 - 1 },
            { EDITOR_SIZE / 2 + 1,  EDITOR_SIZE / 2 + 1 }
        }
    }

    return bp, inv, entities
end

---Save processor editor in blueprint
---@param procinfo ProcInfo
---@return boolean @ If success
function build.save_packed_circuits2(procinfo)
    local surface = procinfo.surface
    if not surface or not surface.valid then return false end

    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]

    bp.set_stack { name = "blueprint", count = 1 }
    local entities = bp.create_blueprint {
        surface = surface,
        force = procinfo.processor.force,
        area = {
            { -EDITOR_SIZE / 2 - 1, -EDITOR_SIZE / 2 - 1 },
            { EDITOR_SIZE / 2 + 1,  EDITOR_SIZE / 2 + 1 }
        }
    }

    local area
    local sprite_map
    local references = {}
    if entities then
        ---@class MapToProc
        ---@field proc_index integer
        ---@field iopoint_index integer

        ---@type table<Entity.unit_number, MapToProc>
        local iopoint_map_to_proc = {}

        ---@type IOPointInfo[]
        local iopoints = {}

        for index, entity in ipairs(entities) do
            local name = entity.name
            local position = entity.position

            if remote_name_map[name] then
                local remote_driver = remote_name_map[name]
                local remoteInfo = remote.call(remote_driver.interface_name,
                    "get_info", entity)
                bp.set_blueprint_entity_tags(index, remoteInfo)
            elseif name == "small-lamp" then
                if not area then
                    area = {
                        min = { x = position.x, y = position.y },
                        max = { x = position.x, y = position.y }
                    }
                else
                    if position.x < area.min.x then
                        area.min.x = position.x
                    end
                    if position.y < area.min.y then
                        area.min.y = position.y
                    end
                    if position.x > area.max.x then
                        area.max.x = position.x
                    end
                    if position.y > area.max.y then
                        area.max.y = position.y
                    end
                end
            elseif name == commons.processor_name or name ==
                commons.processor_name_1x1 then
                build.set_processor_tags(bp, index, entity)
                local procinfo1 = build.get_procinfo(entity, false)
                ---@cast procinfo1 -nil
                if procinfo1.model then
                    references[procinfo1.model] = true
                end
                for i, iopoint in pairs(procinfo1.iopoints) do
                    iopoint_map_to_proc[iopoint.unit_number] = {
                        proc_index = index,
                        iopoint_index = i
                    }
                end
            elseif name == iopoint_name then
                table.insert(iopoints, { id = entity.unit_number, index = index })
            elseif name == internal_iopoint_name then
                local iopoint_info = procinfo.iopoint_infos[entity.unit_number]
                if iopoint_info then
                    bp.set_blueprint_entity_tags(index, {
                        index = iopoint_info.index,
                        label = iopoint_info.label,
                        input = iopoint_info.input,
                        output = iopoint_info.output,
                        red_display = iopoint_info.red_display,
                        green_display = iopoint_info.green_display
                    })
                end
            elseif name == display_name then
                local display_info = display.get(entity.unit_number)
                if display_info then
                    bp.set_blueprint_entity_tags(index, display_info.props)
                end
            elseif name == input_name then
                local props = input.get(entity.unit_number)
                if props then
                    bp.set_blueprint_entity_tags(index, props)
                end
            elseif textplate_map[name] == idp then
                sprite_map = build.get_reverse_sprite_map(sprite_map)
                local sprite_type, sprite_name =
                    build.get_render_sprite_info(sprite_map, entity)
                if sprite_type then
                    bp.set_blueprint_entity_tags(index, {
                        ["display-plate-sprite-type"] = sprite_type,
                        ["display-plate-sprite-name"] = sprite_name,
                    })
                end
            end
        end

        for _, io in pairs(iopoints) do
            local id = io.id
            local ref = iopoint_map_to_proc[id]
            if ref then
                bp.set_blueprint_entity_tags(io.index, ref)
            else
                bp.set_blueprint_entity_tags(io.index, { __delete = true })
            end
        end

        if area then
            local size = math.max(area.max.x - area.min.x,
                area.max.y - area.min.y)
            local width = 1.5
            local lamp_name
            local size1 = size + 1

            local selection_box = procinfo.processor.selection_box
            local selection_width = selection_box.right_bottom.x -
                selection_box.left_top.x
            local scale = selection_width / 2.4

            if size < 1 then size = 1 end

            local resize_coef = 0.58
            local lamp_index = math.ceil(math.log(
                math.ceil(size1 / width *
                    resize_coef / scale),
                2)) + 1
            if lamp_index < 1 then
                lamp_index = 1
            elseif lamp_index >= 8 then
                lamp_index = 8
            end

            local center = {
                x = (area.max.x + area.min.x) / 2,
                y = (area.min.y + area.max.y) / 2
            }

            local lamp_size = math.pow(0.5, lamp_index - 1) * resize_coef
            local coef = lamp_size
            lamp_name = prefix .. "-lamp" .. lamp_index

            for index, entity in pairs(entities) do
                if entity.name == "small-lamp" then
                    local x = (entity.position.x - center.x) * coef
                    local y = (entity.position.y - center.y) * coef - scale *
                        0.1
                    bp.set_blueprint_entity_tags(index, {
                        ext_position = { x = x, y = y },
                        ext_name = lamp_name
                    })
                end
            end
        end
    end

    local content = bp.export_stack()
    inv.destroy()
    procinfo.blueprint = content
    procinfo.references = references
    return true
end

---@param procinfo ProcInfo
function build.save_packed_circuits(procinfo)
    procinfo.circuits = nil
    build.save_packed_circuits2(procinfo)
end

---------------------------------------------------------------

local check_signal_o = ccutils.check_signal_o


---------------------------------------------------------------

local iopoint_name = prefix .. "-iopoint"

---@param procinfo ProcInfo
---@return boolean      @ If success
function build.restore_packed_circuits2(procinfo)
    if not procinfo.blueprint then return false end

    IsProcessorRebuilding = true
    local entities = {}
    local force = procinfo.processor.force
    procinfo.iopoint_infos = {}

    storage.surface_restoring = true
    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]
    bp.set_stack { name = "blueprint", count = 1 }
    if bp.import_stack(procinfo.blueprint) ~= 1 then
        local bp_entities = bp.get_blueprint_entities()
        if bp_entities then
            ---@type number,number,number,number
            local x1, y1, x2, y2
            for _, e in pairs(bp_entities) do
                local name = e.name
                local proto = prototypes.entity[name]
                local direction = e.direction
                local w, h
                if direction == defines.direction.north or direction ==
                    defines.direction.south then
                    w = proto.tile_width / 2
                    h = proto.tile_height / 2
                else
                    w = proto.tile_height / 2
                    h = proto.tile_width / 2
                end

                if not x1 then
                    x1 = e.position.x - w / 2
                    y1 = e.position.y - h / 2
                    x2 = x1 + w / 2
                    y2 = y1 + h / 2
                else
                    x1 = math.min(x1, e.position.x - w / 2)
                    y1 = math.min(y1, e.position.y - h / 2)
                    x2 = math.max(x2, e.position.x + w / 2)
                    y2 = math.max(y2, e.position.y + h / 2)
                end
            end

            if x1 then
                local w = x2 - x1
                local h = y2 - y1
                local x = x1 + w / 2 - 0.1
                local y = y1 + h / 2 - 0.1
                local entities = bp.build_blueprint {
                    surface = procinfo.surface,
                    force = procinfo.processor.force,
                    position = { x, y },
                    force_build = true
                }
                for _, entity in pairs(entities) do
                    if entity.valid then
                        entity.silent_revive { raise_revive = true }
                    end
                end
            end
        end
    end
    inv.destroy()
    storage.surface_restoring = false
    IsProcessorRebuilding = false
    return true
end

---@param procinfo ProcInfo
function build.restore_packed_circuits(procinfo)
    build.restore_packed_circuits2(procinfo)
end

---------------------------------------------------------------

---@param procinfo ProcInfo
---@return boolean
---@return integer?
---@return string?   @ Error recursion model
---@return string[]?  @ external
function build.create_packed_circuit_v2(procinfo)
    build.destroy_packed_circuit(procinfo)
    local input_list = {}
    procinfo.input_list = input_list
    local result, update_count, errorModel, externals = build.create_packed_circuit_internal(procinfo, false, {}, procinfo, input_list)
    input.normalize(procinfo.input_list)
    input.set_values(procinfo)
    return result, update_count, errorModel, externals
end

---@param procinfo ProcInfo
---@param nolamp boolean
---@param recursionSet table<string, boolean>
---@param top ProcInfo
---@param input_list InputProperty[]
---@return boolean
---@return integer?
---@return string?   @ Error recursion model
---@return string[]?  @ external
function build.create_packed_circuit_internal(procinfo, nolamp, recursionSet, top, input_list)
    if not procinfo.blueprint then return false end

    local processor = procinfo.processor
    local position = processor.position
    local surface = processor.surface
    local force = processor.force --[[@as LuaForce]]

    if not surface.valid then return false end

    local update_count = 0
    local errorModel

    if procinfo.model then
        local procname = procinfo.name or processor.name
        local model = build.get_model(force, procname, procinfo.model)

        if model and procinfo.tick and procinfo.tick < model.tick then
            procinfo.blueprint = model.blueprint
            procinfo.sprite1 = model.sprite1
            procinfo.sprite2 = model.sprite2
            procinfo.tick = game.tick
            update_count = 1
        end

        if recursionSet[procinfo.model] then
            return true, 0, procinfo.model
        end

        recursionSet[procinfo.model] = true
    end

    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]
    bp.set_stack { name = "blueprint", count = 1 }
    bp.import_stack(procinfo.blueprint)

    local proto = procinfo.processor.prototype
    local scale = proto.tile_width / 2.4

    --- @type table<integer, integer>
    local index_map = {}
    ---@type LuaEntity[]
    local entities = {}

    local bp_entities = bp.get_blueprint_entities()
    local externals = {}
    if bp_entities then
        ---@type table<integer, ProcInfo>
        local inner_processors = {}

        for index, bpentity in pairs(bp_entities) do
            local name = bpentity.name
            local packed_name = allowed_name_map[name]

            if packed_name then
                local tags = bpentity.tags
                if packed_name ~= special then
                    local pos = position
                    if not nolamp and tags and tags.ext_name then
                        packed_name = tags.ext_name --[[@as string ]]
                        pos = {
                            x = position.x + tags.ext_position.x,
                            y = position.y + tags.ext_position.y
                        }
                    else
                        pos = {
                            x = pos.x + bpentity.position.x / 32 * scale,
                            y = pos.y + bpentity.position.y / 32 * scale
                        }
                    end

                    local entity = surface.create_entity {
                        name = packed_name,
                        position = pos,
                        direction = bpentity.direction,
                        force = force
                    }
                    ---@cast entity -nil
                    table.insert(entities, entity)
                    index_map[index] = #entities

                    if name == "constant-combinator" then
                        local cb = entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
                        if bpentity.control_behavior then
                            local bp_cb = bpentity.control_behavior --[[@as any]]
                            local lsections = bp_cb.sections
                            if lsections then
                                local sections = lsections.sections --[[@as LuaLogisticSection[] ]]
                                if sections then
                                    for _, bp_section in pairs(sections) do
                                        local section = cb.get_section(bp_section.index)
                                        if not section then
                                            section = cb.add_section(bp_section.group or "")
                                        else
                                            section.group = bp_section.group or ""
                                        end
                                        ---@cast section -nil
                                        if section.group == "" or #section.filters == 0 then
                                            if bp_section.filters then
                                                ---@type LogisticFilter[]
                                                local filters = {}
                                                for _, entry in pairs(bp_section.filters) do
                                                    ---@cast entry any
                                                    ---@type LogisticFilter
                                                    local filter = {
                                                        value = {
                                                            name = entry.name,
                                                            type = entry.type,
                                                            quality = entry.quality,
                                                            comparator = entry.comparator
                                                        },
                                                        min = entry.count
                                                    }
                                                    table.insert(filters, filter)
                                                end
                                                section.filters = filters
                                            end
                                        end
                                    end
                                end
                            end
                            cb.enabled = bp_cb.is_on ~= false
                        end
                    elseif name == "arithmetic-combinator" then
                        local cb = entity.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
                        if bpentity.control_behavior and cb then
                            local parameters = bpentity.control_behavior.arithmetic_conditions
                            cb.parameters = parameters
                        end
                    elseif name == "decider-combinator" then
                        local cb = entity.get_or_create_control_behavior() --[[@as LuaDeciderCombinatorControlBehavior]]
                        if bpentity.control_behavior and cb then
                            local parameters = {
                                conditions = bpentity.control_behavior.decider_conditions.conditions,
                                outputs = bpentity.control_behavior.decider_conditions.outputs
                            }
                            cb.parameters = parameters
                        end
                    elseif name == "selector-combinator" then
                        local cb = entity.get_or_create_control_behavior() --[[@as LuaSelectorCombinatorControlBehavior]]
                        if bpentity.control_behavior and cb then
                            local parameters = bpentity.control_behavior --[[@as any]]
                            cb.parameters = parameters
                        end
                    elseif name == internal_iopoint_name then
                        if tags then
                            local iopoint = procinfo.iopoints[tags.index]
                            if iopoint and iopoint.valid then
                                iopoint.active = false

                                local success1 = iopoint.get_wire_connector(defines.wire_connector_id.circuit_green, true)
                                    .connect_to(entity.get_wire_connector(defines.wire_connector_id.circuit_green, true), false)
                                local success2 = iopoint.get_wire_connector(defines.wire_connector_id.circuit_red, true)
                                    .connect_to(entity.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
                                if not success1 or not success2 then
                                    debug("Failed to connect iopoint: " ..
                                        tags.index .. "," ..
                                        strip(entity.position) .. " to " ..
                                        strip(iopoint.position))
                                    debug("Failed to connect iopoint: " ..
                                        entity.name .. " to " .. iopoint.name)
                                    debug("Failed to connect iopoint: " ..
                                        entity.unit_number .. " to " ..
                                        iopoint.unit_number)
                                end
                            end
                        end
                    elseif name == "small-lamp" and not nolamp then
                        if bpentity.control_behavior then
                            local cb = entity.get_or_create_control_behavior()
                            ---@cast cb LuaLampControlBehavior
                            local bcontrol = bpentity.control_behavior --[[@as any]]
                            if bcontrol.use_colors then
                                cb.color_mode = defines.control_behavior.lamp.color_mode.color_mapping
                                cb.use_colors = true
                            end
                            if bpentity.control_behavior.circuit_condition then
                                local condition = {}
                                for name, value in pairs(bpentity.control_behavior.circuit_condition) do
                                    condition[name] = value
                                end
                                cb.circuit_condition = condition
                                cb.circuit_enable_disable = true
                            end

                            if bcontrol.connect_to_logistic_network then
                                cb.connect_to_logistic_network = true
                                if bcontrol.logistic_condition then
                                    local condition = {}
                                    condition = cb.logistic_condition
                                    for name, value in pairs(bcontrol.logistic_condition) do
                                        condition[name] = value
                                    end
                                    cb.logistic_condition = condition
                                end
                            end
                        end
                    elseif name == iopoint_name then
                        if tags then
                            if tags.__delete then
                                entity.destroy()
                            else
                                local proc_index = tags.proc_index
                                local proc = inner_processors[proc_index]
                                if not proc then
                                    proc = { iopoints = {} }
                                    inner_processors[proc_index] = proc
                                end
                                proc.iopoints[tags.iopoint_index] = entity
                            end
                        end
                    elseif name == display_name then
                        if tags and not tags.is_internal then
                            display.start(tags, entity)
                        end
                    elseif name == input_name then
                        ---@cast tags -nil
                        ---@type InputProperty
                        local input_prop = {
                            input = tags,
                            x = pos.x,
                            y = pos.y,
                            entity = entity,
                            value_id = (tags and tags.value_id) or tools.get_id() --[[@as string]],
                            label = tags.label --[[@as string]]
                        }
                        if input_prop.input.type == input.types.comm then
                            local comm_input = input_prop.input
                            comm.connect(entity, comm_input.channel_name, comm_input.channel_red, comm_input.channel_green)
                        end
                        table.insert(input_list, input_prop)
                    end
                elseif name == commons.processor_name or name ==
                    commons.processor_name_1x1 then
                    local proc = inner_processors[index]
                    if not proc then
                        proc = { iopoints = {} }
                        inner_processors[index] = proc
                    end
                    proc.name = name
                    if tags then
                        proc.blueprint = tags.blueprint --[[@as string]]
                        proc.tick = tags.tick --[[@as integer]]
                        proc.model = tags.model --[[@as string]]
                        proc.label = tags.label --[[@as string]]
                    end
                    local value_id = (tags and tags.value_id) or tools.get_id()
                    proc.inner_input = {
                        x = position.x + bpentity.position.x / 32,
                        y = position.y + bpentity.position.y / 32,
                        value_id = value_id --[[@as string]],
                        inner_inputs = {},
                        label = proc.label or proc.model
                    }
                    table.insert(input_list, proc.inner_input)
                end
            elseif remote_name_map[name] then
                local tags = bp.get_blueprint_entity_tags(index)
                local remote_driver = remote_name_map[name]
                local pos = {
                    x = position.x + bpentity.position.x / 32,
                    y = position.y + bpentity.position.y / 32
                }
                local entity = remote.call(remote_driver.interface_name,
                    "create_packed_entity", tags,
                    surface, pos, force)
                if entity then
                    table.insert(entities, entity)
                    index_map[index] = #entities
                end
            elseif build.textplate_map[name] then

            else
                table.insert(externals, name)
            end
        end

        for index, bpentity in pairs(bp_entities) do
            local dst_index = index_map[index]
            local entity = entities[dst_index]
            if entity then
                if bpentity.wires then
                    -- need CHECKee
                    for _, wire in pairs(bpentity.wires) do
                        if wire[2] < 5 and wire[4] < 5 then
                            local index1 = index_map[wire[1]]
                            local index2 = index_map[wire[3]]
                            if index1 <= index2 then
                                local src_entity = entities[index1]
                                local dst_entity = entities[index2]

                                local connector1 = src_entity.get_wire_connector(wire[2], true)
                                local connector2 = dst_entity.get_wire_connector(wire[4], true)
                                local success = connector1.connect_to(connector2, false)
                                if not success then
                                    debug(
                                        "Failed to connect: " .. wire[1] ..
                                        " to " .. wire[3] ..
                                        "(" ..
                                        tools.get_constant_name(wire[2] --[[@as integer]], defines.wire_type) ..
                                        ")")
                                end
                            end
                        end
                    end
                end
            end
        end

        for _, proc in pairs(inner_processors) do
            proc.processor = processor
            if proc.blueprint then
                local res, update_count1, newErrorModel, externals1 = build.create_packed_circuit_internal(proc, true,
                    recursionSet, top, proc.inner_input.inner_inputs)
                update_count = update_count + update_count1
                if externals1 then
                    for _, e in pairs(externals1) do
                        table.insert(externals, e)
                    end
                end
                if newErrorModel then errorModel = newErrorModel end
            end
        end
    end

    inv.destroy()
    if procinfo.model then recursionSet[procinfo.model] = nil end

    return true, update_count, errorModel, externals
end

---@param procinfo  ProcInfo
---@return integer? @ Update count
---@return string ?
---@return string[]?
function build.create_packed_circuit(procinfo)
    local result, update_count, recursionError, externals = build.create_packed_circuit_v2(procinfo)
    procinfo.circuits = nil
    return update_count, recursionError, externals
end

---@param procinfo ProcInfo
function build.destroy_packed_circuit(procinfo)
    local processor = procinfo.processor

    tools.destroy_entities(processor, commons.packed_entities)
end

---@param procinfo ProcInfo
---@return table<Entity.unit_number, IOPointInfo>
function build.get_iopoint_map(procinfo)
    if not procinfo.blueprint then
        local map = {}
        if procinfo.circuits then
            for _, entity in ipairs(procinfo.circuits) do
                if entity.name == commons.internal_iopoint_name then
                    map[entity.index] = entity
                end
            end
        end
        return map
    end

    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]

    bp.set_stack { name = "blueprint", count = 1 }
    if bp.import_stack(procinfo.blueprint) == 1 then return {} end

    ---@type table<Entity.unit_number, IOPointInfo>
    local map = {}
    local bpentities = bp.get_blueprint_entities()
    if bpentities then
        for _, bpentity in ipairs(bpentities) do
            if bpentity.name == commons.internal_iopoint_name then
                local tags = bpentity.tags
                if tags then
                    local index = tags.index
                    local prev = map[index]
                    if prev then
                        prev.input = (prev.input or tags.input) --[[@as boolean]]
                        prev.output = (prev.output or tags.output) --[[@as boolean]]
                        if tags.label and tags.label ~= "" then
                            if prev.label and prev.label ~= "" then
                                prev.label = prev.label .. "/" .. tags.label
                            else
                                prev.label = tags.label --[[@as string]]
                            end
                        end
                        tags = prev
                    else
                        map[index] = tags
                    end


                    if bpentity.wires then
                        -- need CHECK
                        for _, wire in pairs(bpentity.wires) do
                            if wire[2] == defines.wire_connector_id.combinator_input_green or
                                wire[2] == defines.wire_connector_id.combinator_output_green then
                                tags["green_wired"] = true
                            elseif wire[2] == defines.wire_connector_id.combinator_input_red or
                                wire[2] == defines.wire_connector_id.combinator_output_red then
                                tags["red_wired"] = true
                            end
                        end
                    end
                end
            end
        end
    end
    inv.destroy()
    return map
end

---@param entity LuaEntity
---@return Tags?
function build.get_processor_tags(entity)
    ---@type ProcInfo
    local procinfo = storage.procinfos[entity.unit_number]
    if procinfo and procinfo.blueprint then
        return {
            blueprint = procinfo.blueprint,
            circuits = procinfo.circuits and
                helpers.table_to_json(procinfo.circuits),
            model = procinfo.model,
            sprite1 = procinfo.sprite1,
            sprite2 = procinfo.sprite2,
            tick = game.tick,
            value_id = procinfo.value_id,
            label = procinfo.label,
            input_values = procinfo.input_values and
                helpers.table_to_json(procinfo.input_values) or nil
        }
    end
    return {}
end

local get_processor_tags = build.get_processor_tags

---@param bp LuaItemStack
---@param index Entity.unit_number
---@param entity LuaEntity
function build.set_processor_tags(bp, index, entity)
    local tags = get_processor_tags(entity)
    if tags then
        bp.set_blueprint_entity_tags(index, tags)
    end
end

---@param entity LuaEntity
---@return Tags?
function build.get_internal_iopoint_tags(entity)
    ---@type ProcInfo
    local procinfo = storage.surface_map[entity.surface.name]
    if procinfo then
        local unit_number = entity.unit_number
        for id, iopoint_info in pairs(procinfo.iopoint_infos) do
            if id == unit_number then
                return {
                    label = iopoint_info.label,
                    index = iopoint_info.index,
                    input = iopoint_info.input,
                    output = iopoint_info.output,
                    red_display = iopoint_info.red_display,
                    green_display = iopoint_info.green_display,
                    tick = game.tick
                }
            end
        end
    end
    return nil
end

---@param bp LuaItemStack
---@param index integer
---@param entity LuaEntity
function build.set_internal_iopoint_tags(bp, index, entity)
    local tags = build.get_internal_iopoint_tags(entity)
    if tags then
        bp.set_blueprint_entity_tags(index, tags)
    end
end

---Get sprite id from entity unit number
---@param map table<integer, LuaRenderObject>
---@return table<integer, LuaRenderObject>
function build.get_reverse_sprite_map(map)
    if map then return map end

    map = {}
    local objects = rendering.get_all_objects("DisplayPlatesForked")
    for _, o in pairs(objects) do
        if o.type ~= "rectangle" then
            local target = o.target
            if target then
                local entity = target.entity
                if entity and entity.valid and entity.unit_number then
                    map[entity.unit_number] = o
                end
            end
        end
    end
    return map
end

---Split string by slash '/''
---@param s string
---@return string[]
local function split_string(s)
    local result = {};
    for m in (s .. "/"):gmatch("(.-)/") do table.insert(result, m); end
    return result
end

---Get sprite (type, name) from entity
---@param map table<integer, LuaRenderObject>
---@param entity LuaEntity
---@return unknown
---@return unknown
function build.get_render_sprite_info(map, entity)
    local id = map[entity.unit_number]
    if id then
        local sprite = id.sprite
        ---@cast sprite -nil
        local strings = split_string(sprite)
        return strings[1], strings[2]
    end
    return nil, nil
end

---@param procinfo ProcInfo
---@param entity LuaEntity
---@param circuit IOPointInfo | Circuit
---@return table
function build.create_iopoint(procinfo, entity, circuit)
    local iopoint_info = {
        entity = entity,
        index = circuit.index,
        label = circuit.label,
        input = circuit.input,
        output = circuit.output,
        red_display = circuit.red_display,
        green_display = circuit.green_display
    }

    local old_pointinfo = procinfo.iopoint_infos[entity.unit_number]
    if old_pointinfo then
        build.disconnect_iopole(procinfo, old_pointinfo)
    end

    procinfo.iopoint_infos[entity.unit_number] = iopoint_info
    if not procinfo.is_packed then
        build.connect_iopole(procinfo, iopoint_info)
    end
    return iopoint_info
end

---@param procinfo ProcInfo
---@param iopole_info IOPointInfo
function build.connect_iopole(procinfo, iopole_info)
    local index = iopole_info.index
    if not index then
        index = 1
        iopole_info.index = 1
    end
    if index <= 0 then return end
    local point = procinfo.iopoints[index]

    -- debug("Try connect to iopole: extern=" .. point.unit_number .. "=> internl=" .. iopole_info.entity.unit_number)
    local target_entity = iopole_info.entity

    local success1, success2
    if point and target_entity then
        success1 = point.get_wire_connector(defines.wire_connector_id.circuit_green, true)
            .connect_to(target_entity.get_wire_connector(defines.wire_connector_id.circuit_green, true), false)
        success2 = point.get_wire_connector(defines.wire_connector_id.circuit_red, true)
            .connect_to(target_entity.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    end
    if not success1 or not success2 then debug("Failed connect to iopole") end
end

---@param procinfo ProcInfo
function build.connect_all_iopoints(procinfo)
    for _, iopoint_info in pairs(procinfo.iopoint_infos) do
        build.connect_iopole(procinfo, iopoint_info)
    end
end

---@param procinfo ProcInfo
---@param iopoint_info IOPointInfo
function build.disconnect_iopole(procinfo, iopoint_info)
    local index = iopoint_info.index
    if index == nil then return false end
    if index <= 0 then return false end
    local point = procinfo.iopoints[index]

    local target_entity = iopoint_info.entity
    if target_entity and point then
        local point_connectors = point.get_wire_connectors(false)
        for _, connector in pairs(point_connectors) do
            if connector.wire_type == defines.wire_type.green or connector.wire_type == defines.wire_type.red then
                for _, connection in pairs(connector.connections) do
                    if connection.target.owner == target_entity then
                        connector.disconnect_from(connection.target)
                    end
                end
            end
        end
    end
    return true
end

---@param procinfo ProcInfo
function build.disconnect_all_iopoints(procinfo)
    local to_remove
    for unit_number, iopoint_info in pairs(procinfo.iopoint_infos) do
        if not build.disconnect_iopole(procinfo, iopoint_info) then
            if not to_remove then to_remove = {} end
            table.insert(to_remove, unit_number)
        end
    end

    if to_remove then
        for _, unit_number in ipairs(to_remove) do
            procinfo.iopoint_infos[unit_number] = nil
        end
    end
end

---@param iopoint_info IOPointInfo
function build.update_io_text(iopoint_info)
    if iopoint_info.label == "" then
        if iopoint_info.text_id then
            iopoint_info.text_id.destroy()
            iopoint_info.text_id = nil
        end
    elseif iopoint_info.text_id then
        iopoint_info.text_id.text = iopoint_info.label
        iopoint_info.text_id.color = iopoint_text_color
    else
        iopoint_info.text_id = rendering.draw_text {
            text = iopoint_info.label,
            surface = iopoint_info.entity.surface,
            target = {
                entity = iopoint_info.entity,
                offset = { 0, -4 }
            },
            color = iopoint_text_color,
            only_in_alt_mode = true,
            alignment = "center",
            use_rich_text = true,
        }
    end
end

---@param force LuaForce | string | integer
---@param processor_name string
---@return table<string, Model>
function build.get_models(force, processor_name)
    local ty = type(force)
    if ty ~= "string" then
        if ty == "table" or ty == "userdata" then
            force = force.name
        else
            force = game.forces[force]
        end
    end

    local key = "/model/" .. force .. "/" .. processor_name

    ---@type table<string, Model>
    local models = storage[key]

    if not models then
        models = {}
        storage[key] = models
    end
    return models
end

---@param force LuaForce | string | integer
---@param processor_name string
---@return Model
function build.get_model(force, processor_name, model)
    return build.get_models(force, processor_name)[model]
end

---@param blueprint string
---@param old_name string
---@param new_name string
---@param pmodel string
---@return string
function build.rename(blueprint, old_name, new_name, pmodel)
    local inv = game.create_inventory(1)
    ---@LuaItemStack
    local bp = inv[1]
    bp.set_stack { name = "blueprint", count = 1 }
    bp.import_stack(blueprint)

    local entities = bp.get_blueprint_entities()

    if entities then
        for index, entity in pairs(entities) do
            if entity.name == pmodel then
                local tags = entity.tags

                if tags then
                    if tags.model == old_name then
                        bp.set_blueprint_entity_tag(index, "model", new_name)
                    end
                    if tags.blueprint then
                        local new_blueprint =
                            build.rename(tags.blueprint, old_name, new_name,
                                pmodel)

                        bp.set_blueprint_entity_tag(index, "blueprint",
                            new_blueprint)
                    end
                end
            end
        end
    end
    blueprint = bp.export_stack()
    inv.destroy()
    return blueprint
end

---@param procinfo ProcInfo
---@param index1 integer
---@param index2 integer
---@return table?
function build.switch_iopoints(procinfo, index1, index2)
    if not procinfo.blueprint then return nil end
    local inv = game.create_inventory(1)
    ---@type LuaItemStack
    local bp = inv[1]
    bp.set_stack { name = "blueprint", count = 1 }
    if bp.import_stack(procinfo.blueprint) == 1 then return {} end

    local map = {}
    local bpentities = bp.get_blueprint_entities()
    if bpentities then
        for i, entity in ipairs(bpentities) do
            if entity.name == commons.internal_iopoint_name then
                local tags = entity.tags
                if tags then
                    local index = tags.index
                    if index == index1 then
                        bp.set_blueprint_entity_tag(i, "index", index2)
                    elseif index == index2 then
                        bp.set_blueprint_entity_tag(i, "index", index1)
                    end
                end
            end
        end
    end
    local content = bp.export_stack()
    procinfo.blueprint = content
    inv.destroy()
    return map
end

---@type fun(ProcInfo) : boolean
build.is_toplevel = ccutils.is_toplevel

return build
