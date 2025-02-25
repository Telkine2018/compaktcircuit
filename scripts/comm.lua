local commons = require("scripts.commons")
local tools = require("scripts.tools")
local Runtime = require("scripts.runtime")
local commons = require("scripts.commons")

local comm = {}
local max_x = 1000


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

return comm
