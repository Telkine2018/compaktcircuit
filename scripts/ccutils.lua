
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
    if not global.procinfos then global.procinfos = {} end
    local procinfo = global.procinfos[processor.unit_number]
    if not procinfo and create then
        procinfo = {
            processor = processor,
            unit_number = processor.unit_number,
            iopoints = {}, -- external io point
            iopoint_infos = {} -- map: unit_number of internal iopoint => information on point
        }
        global.procinfos[processor.unit_number] = procinfo
    end
    return procinfo
end

---@param type string
---@param name string
---@return any
function ccutils.check_signal(type, name)
    if type == "virtual" then
        return game.virtual_signal_prototypes[name]
    elseif type == "item" then
        return game.item_prototypes[name]
    elseif type == "fluid" then
        return game.fluid_prototypes[name]
    end
    return true
end

local check_signal = ccutils.check_signal

---@param signal SignalID?
---@return any
function ccutils.check_signal_o(signal)
    if not signal then return true end
    return check_signal(signal.type, signal.name)
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

        procinfo = global.surface_map[surface.name]
        if not procinfo then return nil end
     end 
end

return ccutils
