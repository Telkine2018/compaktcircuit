local commons = require("scripts.commons")

local prefix = commons.prefix
local tools = require("scripts.tools")
local display = require("scripts.display")
local input = require("scripts.input")
local build = require("scripts.build")
local ccutils = require("scripts.ccutils")

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

---@param player LuaPlayer
---@param processor_name string
---@return string[] @ Model names
local function get_model_list(player, processor_name)
    local models = build.get_models(player.force, processor_name)
    local model_table = {}
    if models then
        for name, _ in pairs(models) do table.insert(model_table, name) end
    end

    table.sort(model_table)
    table.insert(model_table, 1, "---------------------------------")
    return model_table
end

---@param player LuaPlayer
---@param procinfo ProcInfo
---@return string[]
---@return integer
local function get_model_position(player, procinfo)
    local model = procinfo.model or ""
    local models = get_model_list(player, procinfo.processor.name)
    local selected_index = 1
    if model ~= "" then
        for index, m in ipairs(models) do
            if m == model then
                selected_index = index
                break
            end
        end
    end
    return models, selected_index
end

local internal_panel_name = prefix .. "-intern_panel"

---@param player LuaPlayer
---@param procinfo ProcInfo
function editor.create_editor_panel(player, procinfo)
    editor.close_editor_panel(player)
    display.close(player)
    input.close(player)

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

    local b = frame.add {
        type = "button",
        caption = { button_prefix .. ".exit_editor" },
        name = prefix .. "-exit_editor",
        tooltip = { tooltip_prefix .. ".exit" }
    }
    b.style.width = 200

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

    local models, selected_index = get_model_position(player, procinfo)
    local modelFlow = frame.add {
        type = "flow",
        direction = "horizontal",
        name = "model_flow"
    }
    modelFlow.add { type = "label", caption = { label_prefix .. ".model" } }
    local dp = modelFlow.add {
        type = "drop-down",
        name = prefix .. "-model_list",
        items = models,
        selected_index = selected_index
    }
    dp.style.width = 380
    modelFlow.style.top_margin = 5

    local f
    f = modelFlow.add { type = "textfield", name = prefix .. "-model_name" }
    f.visible = false
    f.style.width = 380

    local modelButtonFlow = frame.add {
        type = "flow",
        direction = "horizontal",
        name = "model_button_flow"
    }
    modelButtonFlow.style.top_margin = 5
    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-new_model_button",
        caption = { button_prefix .. ".new_model" },
        tooltip = { tooltip_prefix .. ".new_model" }
    }
    f.style.width = 80
    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-rename_button",
        caption = { button_prefix .. ".rename_model" },
        tooltip = { tooltip_prefix .. ".rename_model" }
    }
    f.style.width = 80
    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".apply_model" },
        tooltip = { tooltip_prefix .. ".apply_model" },
        name = prefix .. "-apply_model"
    }
    b.style.width = 80
    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".import_model" },
        tooltip = { tooltip_prefix .. ".import_model" },
        name = prefix .. "-import_model"
    }
    b.style.width = 80
    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".remove_model" },
        tooltip = { tooltip_prefix .. ".remove_model" },
        name = prefix .. "-remove_model"
    }
    b.style.width = 80

    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".export_models" },
        tooltip = { tooltip_prefix .. ".export_models" },
        name = prefix .. "-export_models"
    }
    b.style.width = 100

    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".import_models" },
        tooltip = { tooltip_prefix .. ".import_models" },
        name = prefix .. "-import_models"
    }
    b.style.width = 100

    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-ok_button",
        caption = { button_prefix .. ".ok" }
    }
    f.visible = false
    f.style.width = 160
    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-cancel_button",
        caption = { button_prefix .. ".cancel" }
    }
    f.visible = false
    f.style.width = 160


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

---@param player LuaPlayer
---@return LuaGuiElement
local function get_model_flow(player)
    return
        tools.get_child(player.gui.left[internal_panel_name], "model_flow") or
        {}
end

---@param player LuaPlayer
---@return LuaGuiElement
local function get_model_button_flow(player)
    return tools.get_child(player.gui.left[internal_panel_name],
        "model_button_flow") or {}
end

---@param player LuaPlayer
---@param text_mode boolean
---@param action_mode boolean
---@param ok_text string | string[] | nil
local function set_label_mode(player, text_mode, action_mode, ok_text)
    local model_flow = get_model_flow(player)
    local model_button_flow = get_model_button_flow(player)

    model_flow[prefix .. "-model_list"].visible = not text_mode

    model_button_flow[prefix .. "-new_model_button"].visible = not action_mode
    model_button_flow[prefix .. "-rename_button"].visible = not action_mode
    model_button_flow[prefix .. "-apply_model"].visible = not action_mode
    model_button_flow[prefix .. "-import_model"].visible = not action_mode
    model_button_flow[prefix .. "-remove_model"].visible = not action_mode
    model_button_flow[prefix .. "-import_models"].visible = not action_mode
    model_button_flow[prefix .. "-export_models"].visible = not action_mode

    model_flow[prefix .. "-model_name"].visible = text_mode
    model_button_flow[prefix .. "-ok_button"].visible = action_mode
    model_button_flow[prefix .. "-cancel_button"].visible = action_mode
    if ok_text then
        model_button_flow[prefix .. "-ok_button"].caption = ok_text
    end
    if text_mode then model_flow[prefix .. "-model_name"].focus() end
end

local function refresh_model_list(player, procinfo)
    local model_flow = get_model_flow(player)
    local model_list, index = get_model_position(player, procinfo)
    local cb = model_flow[prefix .. "-model_list"]
    cb.items = model_list
    cb.selected_index = index
end

local function add_model(player)
    local procinfo = global.surface_map[player.surface.name]
    local model_flow = get_model_flow(player)
    local model_name = model_flow[prefix .. "-model_name"].text

    if model_name == "" then
        procinfo.model = nil
    else
        if build.get_model(player.force, procinfo.processor.name, model_name) then
            player.print { message_prefix .. ".model_already_exists" }
            return
        end
        procinfo.model = model_name
        build.save_packed_circuits(procinfo)
        local models = build.get_models(player.force, procinfo.processor.name)
        models[model_name] = {
            blueprint = procinfo.blueprint,
            references = procinfo.references,
            tick = game.tick,
            name = model_name,
            sprite1 = procinfo.sprite1,
            sprite2 = procinfo.sprite2
        }
    end

    refresh_model_list(player, procinfo)
end

---@param player LuaPlayer
local function import_model(player)
    --- @type ProcInfo
    local procinfo = global.surface_map[player.surface.name]
    if procinfo.model == nil then return end

    local models = build.get_models(player.force, procinfo.processor.name)
    local model_info = models[procinfo.model]
    if not model_info then return end

    local position = player.position
    player.teleport { -EDITOR_SIZE / 2 + 1, -EDITOR_SIZE / 2 + 1 }
    editor.clean_surface(procinfo)
    procinfo.circuits = model_info.circuits
    procinfo.blueprint = model_info.blueprint
    procinfo.references = model_info.references
    procinfo.sprite1 = model_info.sprite1
    procinfo.sprite2 = model_info.sprite2
    procinfo.tick = game.tick
    build.restore_packed_circuits(procinfo)
    editor.draw_sprite(procinfo)

    local frame = player.gui.left[internal_panel_name]
    local b_sprite1 = tools.get_child(frame, prefix .. "-sprite1")
    local b_sprite2 = tools.get_child(frame, prefix .. "-sprite2")
    if b_sprite1 and b_sprite2 then
        b_sprite1.elem_value = ccutils.check_signal_o(tools.sprite_to_signal(model_info.sprite1) --[[@as SignalID ]])
        b_sprite2.elem_value = ccutils.check_signal_o(tools.sprite_to_signal(model_info.sprite2) --[[@as SignalID ]])
    end

    local x, y = editor.find_room(player.surface, position.x, position.y)
    player.teleport({ x, y })
    input.apply_parameters(procinfo)
end

---@param player LuaPlayer
local function rename_model(player)
    ---@type ProcInfo
    local procinfo = global.surface_map[player.surface.name]
    if procinfo.model == nil then return end

    --[[
    local bp,inv,entities = build.create_blueprint(procinfo, player)
    if bp and bp.valid_for_read and bp.is_blueprint_setup then
        player.cursor_stack.set_stack(bp)
        return
    end
    --]]

    local pmodel = procinfo.processor.name
    local model_flow = get_model_flow(player)
    local new_model = model_flow[prefix .. "-model_name"].text
    if new_model == "" then return end

    if build.get_model(player.force, pmodel, new_model) then
        player.print { message_prefix .. ".model_already_exists" }
        return
    end

    local old_model = procinfo.model

    for i, p in pairs(global.procinfos) do
        ---@cast p ProcInfo
        if p.processor and p.processor.valid and p.processor.force ==
            player.force and p.processor.name == pmodel then
            if p.model == old_model then p.model = new_model end
            if p.blueprint then
                p.blueprint = build.rename(p.blueprint, old_model, new_model, pmodel)
            end
        end
    end

    local model1s = build.get_models(player.force, commons.processor_name)
    local model2s = build.get_models(player.force, commons.processor_name_1x1)
    for _, list in pairs({ model1s, model2s }) do
        for _, model in pairs(list) do
            if model.blueprint then
                model.blueprint = build.rename(model.blueprint, old_model,
                    new_model, pmodel)
            end
        end
    end

    local models = build.get_models(player.force, procinfo.processor.name)
    if not models[old_model] then return end
    models[new_model] = models[old_model]
    models[new_model].name = new_model
    models[old_model] = nil

    refresh_model_list(player, procinfo)
end

---@param models table<string,Model>
---@param model_name string
---@param references string[]
---@param already_checked table<string, boolean>
---@return boolean
local function check_model_in_references(models, model_name, references,
                                         already_checked)
    if not references then return false end
    if references[model_name] then return true end
    for m, _ in pairs(references) do
        if not already_checked[m] then
            already_checked[m] = true

            local model = models[m]
            if model then
                if check_model_in_references(models, model_name,
                        model.references, already_checked) then
                    return true
                end
            end
        end
    end
    return false
end

---@param procinfo ProcInfo
---@param model Model
---@param current ProcInfo
---@return integer
function editor.update_model(procinfo, model, current)
    if procinfo == current then return 0 end

    local count = 0
    if procinfo.model == model.name and procinfo.processor.name ==
        current.processor.name then
        procinfo.blueprint = model.blueprint
        procinfo.references = model.references
        procinfo.sprite1 = model.sprite1
        procinfo.sprite2 = model.sprite2
        if procinfo.surface then
            editor.clean_surface(procinfo)
            build.restore_packed_circuits(procinfo)
            input.apply_parameters(procinfo)
        end
        count = 1
        editor.draw_sprite(procinfo)
    else
        if procinfo.surface ~= nil then
            local processors = procinfo.surface.find_entities_filtered {
                name = { commons.processor_name, commons.processor_name_1x1 }
            }

            for _, processor in pairs(processors) do
                if processor.valid then
                    local procinfo1 = get_procinfo(processor, false)
                    if procinfo1 then
                        count = count +
                            editor.update_model(procinfo1, model,
                                current)
                    end
                end
            end
        end
    end
    if procinfo.is_packed then
        local update_count = build.create_packed_circuit(procinfo)
        input.apply_parameters(procinfo)
        if update_count then count = count + update_count end
    end
    return count
end

---@param player LuaPlayer
local function apply_model(player)
    ---@type ProcInfo
    local model_procinfo = global.surface_map[player.surface.name]
    if not model_procinfo.model then return end

    local force = player.force
    build.save_packed_circuits(model_procinfo)

    local processor_name = model_procinfo.processor.name
    local models = build.get_models(player.force, processor_name)
    local model = {
        blueprint = model_procinfo.blueprint,
        references = model_procinfo.references,
        tick = game.tick,
        sprite1 = model_procinfo.sprite1,
        sprite2 = model_procinfo.sprite2
    }
    models[model_procinfo.model] = model

    local count = 0
    local model_name = model_procinfo.model
    if not model.name then model.name = model_name end

    local outer_list = {}
    local inner_list = {}
    for _, procinfo in pairs(global.procinfos) do
        ---@cast procinfo ProcInfo
        if procinfo.processor and procinfo.processor.valid and
            procinfo.processor.force == force and
            (procinfo ~= model_procinfo or procinfo.processor.name ~=
                processor_name) and build.is_toplevel(procinfo) then
            if (procinfo.model == model_name) and
                (procinfo.processor.name == processor_name) then
                table.insert(outer_list, procinfo)
            else
                local references = procinfo.references
                if check_model_in_references(models, model_name, references, {}) then
                    table.insert(inner_list, procinfo)
                end
            end
        end
    end
    for _, procinfo in pairs(outer_list) do
        ---@cast procinfo ProcInfo
        editor.copy_from(procinfo, model_procinfo, procinfo.is_packed)
        procinfo.sprite1 = model_procinfo.sprite1
        procinfo.sprite2 = model_procinfo.sprite2
        editor.draw_sprite(procinfo)
        count = count + 1
    end
    for _, procinfo in pairs(inner_list) do
        ---@cast procinfo ProcInfo
        count = count + editor.update_model(procinfo, model, model_procinfo)
    end
end

---@param player LuaPlayer
local function remove_model(player)
    ---@type ProcInfo
    local procinfo = global.surface_map[player.surface.name]

    if not procinfo.model then return end
    local models = build.get_models(player.force, procinfo.processor.name)
    models[procinfo.model] = nil
    procinfo.model = nil
    refresh_model_list(player, procinfo)
end

---@param player LuaPlayer
local function execute_model_action(player)
    local model_action = get_vars(player).model_action
    set_label_mode(player, false, false)
    if model_action == "add" then
        add_model(player)
    elseif model_action == "rename" then
        rename_model(player)
    elseif model_action == "apply" then
        apply_model(player)
    elseif model_action == "import" then
        import_model(player)
    elseif model_action == "remove" then
        remove_model(player)
    end
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

        local procinfo = global.surface_map[player.surface.name]
        if not procinfo then return end
        procinfo[name] =
            tools.signal_to_sprite(e.element.elem_value --[[@as SignalID]])
        editor.draw_sprite(procinfo)
    end)

tools.on_event(defines.events.on_gui_selection_state_changed,
    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        if not e.element.valid or e.element.name ~= prefix .. "-model_list" then return end

        local player = game.players[e.player_index]
        local procinfo = global.surface_map[player.surface.name]
        if e.element.selected_index == 1 then
            procinfo.model = nil
        else
            procinfo.model = e.element.items[e.element.selected_index]
        end
    end)

tools.on_event(defines.events.on_gui_confirmed,
    ---@param e EventData.on_gui_confirmed
    function(e)
        if not e.element.valid or e.element.name ~= prefix .. "-model_name" then return end
        local player = game.players[e.player_index]
        execute_model_action(player)
    end)

tools.on_gui_click(prefix .. "-new_model_button",
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        get_vars(player).model_action = "add"
        set_label_mode(player, true, true, { button_prefix .. ".new_model" })
    end)

tools.on_gui_click(prefix .. "-rename_button",
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]

        local procinfo = global.surface_map[player.surface.name]
        if procinfo.model == nil then return end

        local model_flow = get_model_flow(player)
        model_flow[prefix .. "-model_name"].text = procinfo.model

        get_vars(player).model_action = "rename"
        set_label_mode(player, true, true, { button_prefix .. ".rename_model" })
    end)

tools.on_gui_click(prefix .. "-import_model", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        get_vars(player).model_action = "import"
        set_label_mode(player, false, true,
            { button_prefix .. ".import_model_confirm" })
    end)

tools.on_gui_click(prefix .. "-apply_model", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        get_vars(player).model_action = "apply"
        set_label_mode(player, false, true,
            { button_prefix .. ".apply_model_confirm" })
    end)

tools.on_gui_click(prefix .. "-remove_model", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        get_vars(player).model_action = "remove"
        set_label_mode(player, false, true,
            { button_prefix .. ".remove_model_confirm" })
    end)

tools.on_gui_click(prefix .. "-export_models", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]

        player.clear_cursor()

        local item = player.cursor_stack
        item.set_stack({ name = "blueprint-book", count = 1 })

        local inventory = item.get_inventory(defines.inventory.item_main)
        ---@cast inventory -nil

        local index = 1
        for _, processor_name in pairs({ commons.processor_name_1x1, commons.processor_name }) do
            local models = build.get_models(player.force, processor_name)

            if models then
                for name, model in pairs(models) do
                    inventory.insert { name = "blueprint", count = 1 }
                    local bp = inventory[index]
                    index = index + 1
                    bp.set_blueprint_entities {
                        {
                            entity_number = 1,
                            name = processor_name,
                            position = { 0, 0 },
                            direction = defines.direction.north,
                            tags = {
                                model = model.name,
                                sprite1 = model.sprite1,
                                sprite2 = model.sprite2,
                                blueprint = model.blueprint,
                                references=model.references
                            }
                        }
                    }
                    bp.label = model.name
                end
            end
        end
    end)

tools.on_gui_click(prefix .. "-import_models", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        local stack = player.cursor_stack
        if not stack or not stack.is_blueprint_book then
            player.print { "compaktcircuit-message.need_a_blueprint_book" }
            return
        end

        local inventory = stack.get_inventory(defines.inventory.item_main)
        ---@cast inventory -nil

        for i = 1, #inventory do
            ---@type LuaItemStack
            local bp = inventory[i]
            if bp and bp.is_blueprint then
                local entities = bp.get_blueprint_entities()
                local model_name = bp.label
                if entities and #entities == 1 then
                    local proc = entities[1]
                    if proc.name == commons.processor_name or proc.name == commons.processor_name_1x1 then
                        local tags = proc.tags

                        if not build.get_model(player.force, proc.name, model_name) then
                            local models = build.get_models(player.force, proc.name)
                            models[model_name] = {
                                blueprint = tags.blueprint --[[@as string]],
                                tick = game.tick,
                                name = model_name,
                                sprite1 = tags.sprite1 --[[@as string]],
                                sprite2 = tags.sprite2 --[[@as string]],
                                references = tags.references --[[@as string[] ]]
                            }
                        end
                    end
                end
            end
        end
        local procinfo = global.surface_map[player.surface.name]
        refresh_model_list(player, procinfo)
    end)

tools.on_gui_click(prefix .. "-cancel_button",
    ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        set_label_mode(player, false, false)
    end)

tools.on_gui_click(prefix .. "-ok_button", ---@param e EventData.on_gui_click
    function(e)
        local player = game.players[e.player_index]
        execute_model_action(player)
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
    if global.last_click and global.last_click > game.tick - 120 then return end
    global.last_click = game.tick

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
    editor.close_iopanel(player)
    display.close(player)
    input.close(player)
    editor.close_editor_panel(player)

    local vars = get_vars(player)
    local procinfo = vars.procinfo
    vars.is_standard_exit = true

    exit_player(procinfo, player)
end

---@param e EventData.on_gui_checked_state_changed
local function on_gui_checked_state_changed(e)
    if not e.element or e.element.name ~= prefix .. "-is_packed" then return end
    local player = game.players[e.player_index]

    local surface = player.surface
    local vars = get_vars(player)
    local procinfo = vars.procinfo
    local new_packed = e.element.state
    editor.set_packed(procinfo, new_packed)
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
function editor.set_packed(procinfo, is_packed)
    if procinfo.is_packed == is_packed then return end
    procinfo.is_packed = is_packed
    if is_packed then
        editor.recursive_pack(procinfo)
        build.save_packed_circuits(procinfo)
        build.disconnect_all_iopoints(procinfo)
        build.create_packed_circuit(procinfo)
        input.apply_parameters(procinfo)
    else
        build.destroy_packed_circuit(procinfo)
        build.connect_all_iopoints(procinfo)
        input.apply_parameters(procinfo)
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
                player.surface.spill_item_stack(player.position, { stack })
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


tools.on_gui_click(prefix .. "-exit_editor", on_exit_editor)
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
    if not global.surface_map then
        ---@type table<string, ProcInfo>
        global.surface_map = {}
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
        if not game.tile_prototypes[tile_proto] then
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
    global.surface_map[surface_name] = procinfo
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
    local panel = player.gui.left[iopanel_name]
    if panel then panel.destroy() end
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
        editor.close_iopanel(player)
        return
    end

    player.opened = nil

    local vars = get_vars(player)
    local procinfo = global.surface_map[entity.surface.name]

    local ids = {}
    for i = 1, #procinfo.iopoints do table.insert(ids, tostring(i)) end

    editor.close_iopanel(player)

    vars.iopole = entity
    local iopoint_info = procinfo.iopoint_infos[entity.unit_number]

    local outer_frame = player.gui.left.add {
        type = "frame",
        direction = "vertical",
        name = iopanel_name,
        caption = { prefix .. "-iopanel.title" }
    }

    local frame = outer_frame.add {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding",
    }

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

    frame.add {
        type = "button",
        caption = { button_prefix .. ".ok" },
        name = prefix .. ".iopole_ok"
    }
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
---@param src_procinfo ProcInfo
---@param packed boolean
function editor.copy_from(procinfo, src_procinfo, packed)
    if src_procinfo.blueprint then
        procinfo.blueprint = src_procinfo.blueprint
    elseif src_procinfo.circuits then
        procinfo.circuits = src_procinfo.circuits
    else
        return
    end

    if not procinfo.is_packed then
        if packed then
            editor.delete_surface(procinfo)
            build.create_packed_circuit(procinfo)
            procinfo.is_packed = true
        else
            procinfo.surface = nil
            editor.get_or_create_surface(procinfo)
            build.restore_packed_circuits(procinfo)
        end
    else
        build.create_packed_circuit(procinfo)
    end
end

---------------------------------------------------------------

---@param procinfo ProcInfo
function editor.delete_surface(procinfo)
    if not procinfo.surface then return end

    editor.clean_surface(procinfo)
    global.surface_map[procinfo.surface.name] = nil
    game.delete_surface(procinfo.surface)
    procinfo.surface = nil
end

---@param e EventData.on_pre_surface_deleted
function editor.on_pre_surface_deleted(e)
    local surface = game.surfaces[e.surface_index]
    local procinfo = global.surface_map[surface.name]

    if procinfo == nil then return end

    editor.clean_surface(procinfo)
    global.surface_map[surface.name] = nil
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
        for _, id in pairs(procinfo.sprite_ids) do rendering.destroy(id) end
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
            target = processor,
            target_offset = { 0, target_y * scale },
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
            target = processor,
            target_offset = { 0, target_y * scale },
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
    procinfo = global.surface_map[surface_name]
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
    if global.surface_restoring then return index end

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

---@param name string
---@return string?
local function is_allowed(name)
    local packed_name = allowed_name_map[name]
    if packed_name then return packed_name end
    if textplate_map[name] then return name end
    if remote_name_map[name] then return name end
    return nil
end

---@param entity LuaEntity
---@param e EventData.on_robot_built_entity | EventData.script_raised_built | EventData.on_built_entity | EventData.script_raised_revive
local function on_build(entity, e)
    if not entity or not entity.valid then return end

    local name = entity.name
    local procinfo = global.surface_map and
        global.surface_map[entity.surface.name]

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
        if not global.destroy_list then
            global.destroy_list = { entity }
        else
            table.insert(global.destroy_list, entity)
        end
    end
end

---@param entity LuaEntity
local function destroy_invalid(entity)
    entity.surface.create_entity {
        name = "flying-text",
        position = entity.position,
        text = { message_prefix .. ".not_allowed" }
    }
    local m = entity.prototype.mineable_properties
    local position = entity.position
    local surface = entity.surface
    local force = entity.force --[[@as LuaForce]]
    if not entity.mine { raise_destroyed = true, ignore_minable = true } then
        entity.destroy()
    end
    if m.minable and m.products then
        for _, p in pairs(m.products) do
            surface.spill_item_stack(position,
                { name = p.name, count = p.amount }, true,
                force)
        end
    end
end

tools.on_nth_tick(5, function()
    if not global.destroy_list then return end
    for _, entity in ipairs(global.destroy_list) do
        if entity.valid then destroy_invalid(entity) end
    end
    global.destroy_list = nil
end)

---@param ev EventData.on_robot_built_entity
local function on_robot_built(ev)
    local entity = ev.created_entity

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
    local entity = ev.created_entity

    on_build(entity, ev)
end

---@param e EventData.on_marked_for_deconstruction
local function on_marked_for_deconstruction(e)
    local player_index = e.player_index
    if not player_index then return end

    local player = game.players[e.player_index]
    local entity = e.entity
    local procinfo = global.surface_map and
        global.surface_map[entity.surface.name]
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
    "constant-combinator", "decider-combinator", "arithmetic-combinator",
    "big-electric-pole", "small-electric-pole", "medium-electric-pole",
    "substation", internal_iopoint_name, "small-lamp"
}

for name, _ in pairs(textplate_map) do table.insert(surface_name_filter, name) end

---------------------------------------------------------------

---@param entity LuaEntity
function editor.destroy_internal_iopoint(entity)
    if not entity.valid then return end

    ---@type ProcInfo
    local procinfo = global.surface_map[entity.surface.name]
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

    local proto = game.entity_prototypes[driver.name]
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
