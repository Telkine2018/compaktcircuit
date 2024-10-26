
local commons = require("scripts.commons")
local tools = require("scripts.tools")

local prefix = commons.prefix
local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local ccutils = {}


ccutils.special_signals = {
    ["signal-anything"] = true, 
    ["signal-everything"] = true, 
    ["signal-each"] = true
}


---Get procinfo from processor
---@param processor LuaEntity
---@param create boolean?
---@return ProcInfo?
function ccutils.get_procinfo(processor, create)
    if not storage.procinfos then storage.procinfos = {} end
    local procinfo = storage.procinfos[processor.unit_number]
    if not procinfo and create then
        procinfo = {
            processor = processor,
            unit_number = processor.unit_number,
            iopoints = {}, -- external io point
            iopoint_infos = {} -- map: unit_number of internal iopoint => information on point
        }
        storage.procinfos[processor.unit_number] = procinfo
    end
    return procinfo
end

---@param type string
---@param name string
---@return any
function ccutils.check_signal(type, name)
    if type == "virtual" then
        return prototypes.virtual_signal[name]
    elseif type == "item" then
        return prototypes.item[name]
    elseif type == "fluid" then
        return prototypes.fluid[name]
    end
    return true
end

---@param sprite string?
---@return any
function ccutils.check_sprite(sprite)
    if not sprite then return nil end
    local signal = tools.sprite_to_signal(sprite)
    ---@cast signal -nil
    if ccutils.check_signal(signal.type, signal.name) then
        return sprite
    else
        return nil
    end
end

local check_signal = ccutils.check_signal

---@param signal SignalID?
---@return any
function ccutils.check_signal_o(signal)
    if not signal then return true end
    return check_signal(signal.type, signal.name)
end

---@param signal SignalID?
---@return SignalID?
function ccutils.translate_signal(signal)
    if not signal then return nil end
    if ccutils.check_signal_o(signal) then
        return signal
    else
        return nil
    end
end

---Split string by slash '/''
---@param s string
---@return string[]
function ccutils.split_string(s)
    local result = {};
    for m in (s .. "/"):gmatch("(.-)/") do table.insert(result, m); end
    return result
end

local processor_pattern = "^proc%_%d+$"

---@param procinfo ProcInfo
---@return boolean
function ccutils.is_toplevel(procinfo)
    local processor = procinfo.processor
    return processor.valid and
               not string.find(processor.surface.name, processor_pattern)
end

---@param procinfo ProcInfo?
---@return ProcInfo?
function ccutils.get_top_procinfo(procinfo)

    if not procinfo then return nil end
    while true do
        local processor = procinfo.processor
        if not processor.valid then return nil end

        local surface = processor.surface
        if not string.find(surface.name, processor_pattern) then return procinfo end

        procinfo = storage.surface_map[surface.name]
        if not procinfo then return nil end
     end 
end

---@param player LuaPlayer
function ccutils.close_all(player)
end

return ccutils
