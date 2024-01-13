local commons = require("scripts.commons")
local tools = require("scripts.tools")
local build = require("scripts.build")
local editor = require("scripts.editor")

local inspectlib = {}

local prefix = commons.prefix
local debug = tools.debug
local cdebug = tools.cdebug
local get_vars = tools.get_vars
local strip = tools.strip

local inspect_name = prefix .. "_inspector"
local column_count = 10
local empty = {}
local red_button = prefix .. "_slot_button_red"
local green_button = prefix .. "_slot_button_green"

local get_procinfo = build.get_procinfo

---@param player LuaPlayer
---@param processor LuaEntity
function inspectlib.show(player, processor)

    if not processor.valid then return end
    local procinfo = get_procinfo(processor, false)
    if not procinfo then
        inspectlib.clear(player)
        return
    end

    local frame = player.gui.left[inspect_name]
    if not frame then
        frame = player.gui.left.add {
            type = "frame",
            name = inspect_name,
            direction = "vertical"
        }
    else
        frame.clear()
    end

    tools.get_vars(player).inspectlib_selected = processor
    local iopoint_map = build.get_iopoint_map(procinfo)
    for index, iopoint in pairs(procinfo.iopoints) do

        local info
        if procinfo.surface then
            if procinfo.iopoint_infos then
                for _, i in pairs(procinfo.iopoint_infos) do
                    if i.index == index then
                        info = i
                        break
                    end
                end
            else
                return
            end
        else
            info = iopoint_map[index]
        end

        local cb = iopoint.get_control_behavior()
        if cb and info then

            local red_circuit = cb.get_circuit_network(defines.wire_type.red)
            local green_circuit =
                cb.get_circuit_network(defines.wire_type.green)
            local red_signals = red_circuit and red_circuit.signals or empty
            local green_signals = green_circuit and green_circuit.signals or
                                      empty
            if info.red_display == commons.display_none then
                red_signals = empty
            end
            if info.green_display == commons.display_none then
                green_signals = empty
            end

            if #red_signals > 0 or #green_signals > 0 then
                local label
                if info.label and info.label ~= "" then
                    label = "(" .. tostring(index) .. "):" .. info.label
                else
                    label = "(" .. tostring(index) .. ")"
                end

                frame.add {type = "label", caption = label}

                local function display(signals, color, display)

                    if #signals == 0 then return end

                    local max
                    if display == commons.display_one_line then
                        max = column_count
                    else
                        max = #signals
                    end
                    local signal_table
                    signal_table = frame.add {
                        type = "table",
                        column_count = column_count
                    }
                    table.sort(signals,
                               function(a, b)
                        return a.count > b.count
                    end)
                    for index, signal in pairs(signals) do
                        local s = signal.signal
                        if s.name then
                            local sprite =
                                (s.type == "virtual" and "virtual-signal" or
                                    s.type) .. "/" .. s.name
                            local sprite_button = signal_table.add {
                                type = "sprite-button",
                                sprite = sprite,
                                number = signal.count
                            }
                            sprite_button.style = color
                            if index >= max then
                                break
                            end
                        end
                    end
                end

                display(red_signals, red_button, info.red_display)
                display(green_signals, green_button, info.green_display)
            end
        end
    end
end

---@param player LuaPlayer
function inspectlib.clear(player)
    tools.get_vars(player).inspectlib_selected = nil
    inspectlib.close(player)
end

---@param player LuaPlayer
function inspectlib.close(player)
    local frame = player.gui.left[inspect_name]
    if frame then frame.destroy() end
end

function inspectlib.refresh()
    for _, player in pairs(game.players) do
        local entity = tools.get_vars(player).inspectlib_selected
        if entity then inspectlib.show(player, entity) end
    end
end

tools.on_nth_tick(20, inspectlib.refresh)

return inspectlib
