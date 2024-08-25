local commons = require("scripts.commons")
local tools = require("scripts.tools")

---@class RuntimeConfig
---@field name string
---@field max_per_tick integer              @ max execution per tick
---@field refresh_rate integer              @ execution count for a refresh
---@field ntick integer                     @ delay between execution
---@field global_name string
---@field rt_name string
---@field process fun(e : EntityWithId)
---@field max_per_run integer?

---@class EntityWithIdAndProcess : EntityWithId
---@field process  fun(e:EntityWithId)?

---@class RuntimeGlobal
---@field currentid integer
---@field refresh_index number
---@field boost boolean?

---@class Runtime
---@field config RuntimeConfig
---@field map table<int, EntityWithIdAndProcess>
---@field gdata RuntimeGlobal
---@field disabled boolean?

local Runtime = {}

--- @type table<string, RuntimeConfig>
local configs = {}

--- @type table<string, Runtime>
local runtimes = {}

local debug = tools.debug

local mt = { __index = Runtime }

---@param config RuntimeConfig
function Runtime.register(config)
    configs[config.name] = config
    if not config.max_per_tick then config.max_per_tick = 2 end
    if not config.refresh_rate then config.refresh_rate = 1 end
    if not config.ntick then config.ntick = 10 end
    if not config.global_name then config.global_name = config.name end
    if not config.rt_name then config.rt_name = config.global_name .. "_data" end

    ---@type EntityMap<EntityWithId>
    tools.on_init(
        function()
            if not global[config.global_name] then
                global[config.global_name] = {} --[[@as EntityMap<EntityWithId>]]
            end
            if not global[config.rt_name] then
                global[config.rt_name] = { refresh_index = 0 }
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
    local max_per_tick = config.max_per_tick
    local process = config.process

    setmetatable(rt, mt)

    local map = global[config.global_name] --[[@as EntityMap<EntityWithIdAndProcess>]]
    rt.map = map

    ---@type RuntimeGlobal
    local gdata = global[config.rt_name]
    rt.gdata = gdata

    local max_per_run = max_per_tick
    if config.ntick > 0 then max_per_run = max_per_tick * config.ntick end
    if config.max_per_run then max_per_run = config.max_per_run end

    ---@cast max_per_run integer

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
        gdata.boost = nil
    end

    ---@param data NthTickEventData
    local function on_tick(data)
        map = rt.map
        gdata = rt.gdata

        if rt.disabled then return end

        local size = table_size(map)
        if size == 0 then return end

        if gdata.boost then
            boost()
            return
        end

        local run_rate = size / config.refresh_rate
        if run_rate > max_per_run then run_rate = max_per_run end

        gdata.refresh_index = gdata.refresh_index + run_rate
        while (gdata.refresh_index > 0) do
            local currentid, current = next(map, gdata.currentid)
            gdata.currentid = currentid

            if not current then break end

            if tools.tracing then
                debug(config.name .. ":(" .. currentid .. ")")
            end

            local local_process = current.process
            if local_process then
                local_process(current)
            else
                process(current)
            end
            gdata.refresh_index = gdata.refresh_index - 1
        end
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
    map[eid.id] = eid
end

--- Remove object from runtime
---@param self Runtime
---@param eid EntityWithId | integer
function Runtime:remove(eid)
    if not self.map then return end

    ---@type integer
    local id
    if type(eid) == "number" then
        id = eid --[[@as integer]]
    else
        id = eid.id
    end

    if id == self.gdata.currentid then
        self.gdata.currentid = nil
    end
    self.map[id] = nil
end

function Runtime.initialize()
    for _, config in pairs(configs) do
        local rt = Runtime.get(config.name)
        if not rt.map then
            rt.map = {}
            global[rt.config.global_name] = rt.map
        end
        if not rt.gdata then
            local gdata = { refresh_index = 0 }
            global[rt.config.rt_name] = gdata
            rt.gdata = gdata
        end
    end
end

return Runtime
