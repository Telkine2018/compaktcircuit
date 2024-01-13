local commons = require("scripts.commons")
local tools = require("scripts.tools")

---@class RuntimeConfig
---@field name string
---@field max_per_tick integer              @ max execution per tick
---@field refresh_rate integer              @ execution count for a refresh
---@field ntick integer                     @ delay between execution
---@field global_name string
---@field process fun(e : EntityWithId)
---@field max_per_run integer?

---@class EntityWithIdAndProcess : EntityWithId
---@field process  fun(e:EntityWithId)?

---@class Runtime 
---@field config RuntimeConfig
---@field map table<int, EntityWithIdAndProcess>
---@field currentid integer
---@field boost boolean
---@field disabled boolean
local Runtime = {}

--- @type table<string, RuntimeConfig>
local configs = {}

--- @type table<string, Runtime>
local runtimes = {}

local mt = {__index = Runtime}

---@param config RuntimeConfig
function Runtime.register(config)
    configs[config.name] = config
    if not config.max_per_tick then config.max_per_tick = 1 end
    if not config.refresh_rate then config.refresh_rate = 12 end
    if not config.ntick then config.ntick = 10 end
    if not config.global_name then config.global_name = config.name end

    ---@type EntityMap<EntityWithId>
    tools.on_init(
        function() 
            if not global[config.global_name] then
                global[config.global_name] = {} --[[@as EntityMap<EntityWithId>]] 
            end
        end)

end

-- Get existing runtime
---@param name string
---@return Runtime
function Runtime.get_existing(name) return runtimes[name] end

---Create a new runtime
-- Call by on_load
---@param name string
function Runtime.get(name)

    ---@type Runtime
    local rt = runtimes[name]
    if rt then return rt end

    rt = {}
    runtimes[name] = rt

    local config = configs[name]
    if not config then error("Unknown runtime config:" .. name) end

    rt.config = config
    local process = config.process

    setmetatable(rt, mt)

    local refresh_index = 0
    local map = global[config.global_name] --[[@as EntityMap<EntityWithIdAndProcess>]]
    rt.map = map

    rt:update_config()

    local function boost()

        local map_copy = tools.table_dup(rt.map)
        for _, current in pairs(map_copy) do
            local local_process = current.process
            if local_process then
                local_process(current)
            else
                process(current)
            end
        end

        rt.boost = false
    end

    ---@param data NthTickEventData
    local function on_tick(data)

        GAMETICK = data.tick
        if rt.disabled then return end
        map = rt.map
        if not map then return end

        local currentid = rt.currentid
        local size = table_size(map)
        if size == 0 then return end

        if rt.boost then
            boost()
            return
        end

        local max_per_run = config.max_per_run --[[@as integer]]
        local run_rate = size / config.refresh_rate
        if run_rate > max_per_run then run_rate = max_per_run end

        refresh_index = refresh_index + run_rate
        while (refresh_index > 0) do
            local current
            currentid, current = next(map, currentid)
            if not current then break end
            rt.currentid = currentid
            local local_process = current.process
            if local_process then
                local_process(current)
            else
                process(current)
            end
            currentid = rt.currentid
            refresh_index = refresh_index - 1
        end
        rt.currentid = currentid
    end

        tools.on_nth_tick(config.ntick, on_tick)
    return rt
end

function Runtime:update_config()
    local config = self.config
    local max_per_tick = config.max_per_tick
    local max_per_run = max_per_tick
    if not max_per_tick or max_per_tick < 1 then
        max_per_tick = 1
    end
    if config.ntick > 0 then max_per_run = max_per_tick * config.ntick end
    config.max_per_run = max_per_run
end

---@param map table<int, EntityWithIdAndProcess>
function Runtime:set_map(map)
    self.map = map
    global[self.config.global_name] = map
end

--- Add object to runtime
---@param self Runtime
---@param eid EntityWithIdAndProcess
function Runtime:add(eid)
    local map = self.map
    if not map then
        self:set_map({})
        map = self.map
    end
    map[eid.id] = eid
end

--- Remove object from runtime
---@param self Runtime
---@param eid EntityWithId | integer
function Runtime:remove(eid)

    if not self.map then return end

    ---@type integer
    local id
    if type(id) == "number" then
        id = eid --[[@as integer]]
    else
        id = eid.id
    end

    if id == self.currentid then self.currentid = nil end
    self.map[id] = nil
end

return Runtime
