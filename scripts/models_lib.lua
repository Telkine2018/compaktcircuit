local commons = require("scripts.commons")

local prefix = commons.prefix
local tools = require("scripts.tools")
local display = require("scripts.display")
local input = require("scripts.input")
local build = require("scripts.build")
local ccutils = require("scripts.ccutils")
local editor = require("scripts.editor")

local get_vars = tools.get_vars
local strip = tools.strip

local EDITOR_SIZE = commons.EDITOR_SIZE

local button_prefix = prefix .. "-button"
local label_prefix = prefix .. "-label"
local checkbox_prefix = prefix .. "-checkbox"
local message_prefix = prefix .. "-message"
local tooltip_prefix = prefix .. "-tooltip"

local models_lib = {}

local function np(name) return prefix .. "-models." .. name end

local frame_name = np("frame")

local get_procinfo = build.get_procinfo

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

---@param player LuaPlayer
function models_lib.create_panel(player)

    local procinfo = storage.surface_map[player.surface.name]
    if not procinfo then return end

    ccutils.close_all(player)

    local outer_frame, frame = tools.create_standard_panel(player, {
        panel_name = frame_name,
        title = { np("title") },
        is_draggable = true,
        create_inner_frame = true,
        close_button_name = np("close")
    })

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
    f = modelFlow.add { type = "textfield", name = prefix .. "-model_name",  icon_selector = true }
    f.visible = false
    f.style.width = 380
    local button_width = 110

    local modelButtonFlow = frame.add {
        type = "table",
        column_count = 4,
        name = "model_button_flow"
    }
    modelButtonFlow.style.top_margin = 5
    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-new_model_button",
        caption = { button_prefix .. ".new_model" },
        tooltip = { tooltip_prefix .. ".new_model" }
    }
    f.style.width = button_width
    f = modelButtonFlow.add {
        type = "button",
        name = prefix .. "-rename_button",
        caption = { button_prefix .. ".rename_model" },
        tooltip = { tooltip_prefix .. ".rename_model" }
    }
    f.style.width = button_width
    local b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".apply_model" },
        tooltip = { tooltip_prefix .. ".apply_model" },
        name = prefix .. "-apply_model"
    }
    b.style.width = button_width
    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".import_model" },
        tooltip = { tooltip_prefix .. ".import_model" },
        name = prefix .. "-import_model"
    }
    b.style.width = button_width
    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".remove_model" },
        tooltip = { tooltip_prefix .. ".remove_model" },
        name = prefix .. "-remove_model"
    }
    b.style.width = button_width

    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".export_models" },
        tooltip = { tooltip_prefix .. ".export_models" },
        name = prefix .. "-export_models"
    }
    b.style.width = button_width

    b = modelButtonFlow.add {
        type = "button",
        caption = { button_prefix .. ".import_models" },
        tooltip = { tooltip_prefix .. ".import_models" },
        name = prefix .. "-import_models"
    }
    b.style.width = button_width

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

    local models_location = get_vars(player).models_location
    if models_location then
        outer_frame.location = models_location
    else
        outer_frame.force_auto_center()
    end
end

tools.on_gui_click(np("close"), 
---@param e EventData.on_gui_click
function(e)
    models_lib.close(game.players[e.player_index])
end)

---@param player LuaPlayer
function models_lib.close(player)
    local frame = player.gui.screen[frame_name]
    if frame then
        tools.get_vars(player).models_location = frame.location
        frame.destroy()
    end
end

---@param player LuaPlayer
---@return LuaGuiElement
local function get_model_flow(player)
    return tools.get_child(player.gui.screen[frame_name], "model_flow") or {}
end

---@param player LuaPlayer
---@return LuaGuiElement
local function get_model_button_flow(player)
    return tools.get_child(player.gui.screen[frame_name], "model_button_flow") or {}
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
    local procinfo = storage.surface_map[player.surface.name]
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
    local procinfo = storage.surface_map[player.surface.name]
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

    local frame = player.gui.left[commons.internal_panel_name]
    local b_sprite1 = tools.get_child(frame, prefix .. "-sprite1")
    local b_sprite2 = tools.get_child(frame, prefix .. "-sprite2")
    if b_sprite1 and b_sprite2 then
        local sig1 = tools.sprite_to_signal(model_info.sprite1) --[[@as SignalID ]]
        if ccutils.check_signal_o(sig1) then
            b_sprite1.elem_value = sig1
        end
        local sig2 = tools.sprite_to_signal(model_info.sprite2) --[[@as SignalID ]]
        if ccutils.check_signal_o(sig2) then
            b_sprite2.elem_value = sig2
        end
    end

    local x, y = editor.find_room(player.surface, position.x, position.y)
    player.teleport({ x, y })
    input.apply_parameters(procinfo)
end

---@param player LuaPlayer
local function rename_model(player)
    ---@type ProcInfo
    local procinfo = storage.surface_map[player.surface.name]
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

    for i, p in pairs(storage.procinfos) do
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
function models_lib.update_model(procinfo, model, current)
    if procinfo == current then return 0 end

    local count = 0
    if procinfo.model == model.name and procinfo.processor.name ==
        current.processor.name then
        procinfo.blueprint = model.blueprint
        procinfo.references = model.references
        procinfo.sprite1 = model.sprite1 or procinfo.sprite1
        procinfo.sprite2 = model.sprite2 or procinfo.sprite2
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
                        count = count + models_lib.update_model(procinfo1, model,  current)
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
    local model_procinfo = storage.surface_map[player.surface.name]
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
    for _, procinfo in pairs(storage.procinfos) do
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
        models_lib.copy_from(procinfo, model_procinfo, procinfo.is_packed)
        procinfo.sprite1 = model_procinfo.sprite1 or procinfo.sprite1
        procinfo.sprite2 = model_procinfo.sprite2 or procinfo.sprite2
        editor.draw_sprite(procinfo)
        count = count + 1
    end
    for _, procinfo in pairs(inner_list) do
        ---@cast procinfo ProcInfo
        count = count + models_lib.update_model(procinfo, model, model_procinfo)
    end
end

---@param procinfo ProcInfo
---@param src_procinfo ProcInfo
---@param packed boolean
function models_lib.copy_from(procinfo, src_procinfo, packed)
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

---@param player LuaPlayer
local function remove_model(player)
    ---@type ProcInfo
    local procinfo = storage.surface_map[player.surface.name]

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


tools.on_event(defines.events.on_gui_selection_state_changed,
    ---@param e EventData.on_gui_selection_state_changed
    function(e)
        if not e.element.valid or e.element.name ~= prefix .. "-model_list" then return end

        local player = game.players[e.player_index]
        local procinfo = storage.surface_map[player.surface.name]
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

        local procinfo = storage.surface_map[player.surface.name]
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
        if not item then return end
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

                        ---@cast model_name -nil
                        if not build.get_model(player.force, proc.name, model_name) and tags then
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
        local procinfo = storage.surface_map[player.surface.name]
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

tools.register_user_event("models.open", function(data)
    local player = data --[[@as LuaPlayer]]
    models_lib.create_panel(player)
end)

tools.register_user_event("models.close", function(data)
    local player = data --[[@as LuaPlayer]]
    models_lib.close(player)
end)


return models_lib