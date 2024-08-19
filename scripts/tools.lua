
local tools = {}
local log_index = 1
local tracing = true

---@param msg LocalisedString?
function tools.print(msg)

    if game then game.print(msg) end
    log(msg)
end

---@param msg LocalisedString?
local function debug(msg)
    if not tracing then return end

    if not msg then return end

    if type(msg) == "string" then
    msg = "[" .. log_index .. "] " .. msg
    else
        table.insert(msg, 2, "[" .. log_index .. "] ")
    end
    log_index = log_index + 1
    tools.print(msg)
end

tools.debug = debug

---@param cond boolean?
---@param msg string
local function cdebug(cond, msg) if cond then debug(msg) end end

tools.cdebug = cdebug

---@param trace boolean
function tools.set_tracing(trace) tracing = trace end

function tools.is_tracing() return tracing end

---@param o any
function tools.strip(o) 
    local s = string.gsub(serpent.block(o), "%s", "") 
    return s
end

local strip = tools.strip


---@param player LuaPlayer
---@return {[string]:any}
function tools.get_vars(player)
    ---@type {[integer]: {[string]:any}}
    local players = global.players
    if players == nil then
        players = {}
        global.players = players
    end
    local vars = players[player.index]
    if vars == nil then
        vars = {}
        players[player.index] = vars
    end
    return vars
end

---Get force shared variables
---@param force LuaForce
---@return table<string, any>
function tools.get_force_vars(force)

    local forces = global.forces
    if forces == nil then
        forces = {}
        global.forces = forces
    end
    local vars = forces[force.index]
    if vars == nil then
        vars = {}
        forces[force.index] = vars
    end
    return vars
end

---@param unit_number Entity.unit_number
---@param close_proc any
---@param field string ?
function tools.close_ui(unit_number, close_proc, field)

    if not field then field = "selected" end
    if not global.players then return end
    for index, vars in pairs(global.players) do
        local selected = vars[field]
        if selected and selected.valid and selected.unit_number == unit_number then

            vars.selected = nil
            close_proc(game.players[index])
            return
        end
    end
end

---@return integer
function tools.get_id()
    local id = global.id or 1
    global.id = id + 1
    return id
end

---@return integer?
function tools.upgrade_id(newid)
    if not newid then
        return
    end
    local id = global.id or 1
    if id <= newid then
        global.id = newid + 1
    end
end

---@param n any
---@return string
function tools.comma_value(n) -- credit http://richard.warburton.it
    if not n then return "" end
    if type(n) ~= "string" then n = tostring(n) end
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

---@param table table
---@return integer
function tools.table_count(table)
    local count = 0
    for _, _ in pairs(table) do count = count + 1 end
    return count
end

---@generic T
---@param table_list T[][]
---@return T[]
function tools.table_concat(table_list)
    local result = {}
    for _, t in ipairs(table_list) do
        if t then for _, e in pairs(t) do table.insert(result, e) end end
    end
    return result
end

---@generic K
---@generic V
---@param table_list table<K,V>[]
---@return table<K,V>
function tools.table_merge(table_list)
    local result = {}
    for _, t in ipairs(table_list) do
        if t then for name, value in pairs(t) do result[name] = value end end
    end
    return result
end

---@generic T:table
---@param src T
---@return T
local function table_deep_copy(src)
    if not src then return nil end
    local copy = {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            value = table_deep_copy(value)
        end
        copy[key] = value
    end
    return copy
end
tools.table_deep_copy = table_deep_copy

---@generic T
---@param src T[]?
---@return T[]?
function tools.table_copy(src)
    if not src then return nil end

    local copy = {}
    for _, value in pairs(src) do table.insert(copy, value) end
    return copy
end


---@generic T
---@param src T[]?
---@return T[]?
function tools.table_dup(src)
    if not src then return nil end
    local copy = {}
    for key, value in pairs(src) do copy[key] = value end
    return copy
end


---@generic KEY
---@generic VALUE
---@generic MAPPED_KEY
---@generic MAPPED_VALUE
---@param t {[KEY]: VALUE}
---@param f fun(k:KEY, v:VALUE) : MAPPED_KEY, MAPPED_VALUE
---@return {[MAPPED_KEY]: MAPPED_VALUE}
function tools.table_map(t, f)
    local result = {}
    for key, value in pairs(t) do
        local map_key, map_value = f(key, value)
        result[map_key] = map_value
    end
    return result
end

---@generic VALUE
---@generic MAPPED_VALUE
---@param t VALUE[]
---@param f fun(v:VALUE) : MAPPED_VALUE
function tools.table_imap(t, f)
    local result = {}
    for _, value in ipairs(t) do
        local map_value = f(value)
        table.insert(result, map_value)
    end
    return result
end

---@generic KEY
---@generic VALUE
---@param t table<KEY, VALUE>
---@param f fun(KEY, VALUE) : boolean
---@return KEY?
---@return VALUE?
function tools.table_find(t, f)
    local result = {}
    for key, value in pairs(t) do if f(key, value) then return key, value end end
    return nil
end

---@param t table
function tools.table_clear(t)

    while true do
        local key = next(t)
        if key then
            t[key] = nil
        else
            return
        end
    end
end

---@param name_list_list string[][]
---@return ({['filter']:'name'} | {['name']:string})[]
function tools.create_name_filter(name_list_list)
    local filters = {}
    for _, name_list in ipairs(name_list_list) do
        for _, name in ipairs(name_list) do
            table.insert(filters, { filter = 'name', name = name })
        end
    end
    return filters
end

------------------------------------------------

---@param event integer
---@param handler fun(EventData)
---@param filters ({["filter"]:string}|{["name"]:string})[]?
function tools.on_event(event, handler, filters)

    local ievent = event --[[@as integer]]
    local previous = script.get_event_handler(ievent)
    if not previous then
        ---@cast filters EventFilter
        script.on_event(ievent, handler, filters)
    else
        local prev_filters = script.get_event_filter(ievent)
        local new_filters = nil
        if prev_filters == nil then
            new_filters = filters
        elseif filters == nil then
            new_filters = prev_filters
        else
            new_filters = tools.table_concat{prev_filters, filters}
        end

        ---@cast new_filters EventFilter
        script.on_event(ievent, function(e)
            previous(e)
            handler(e)
        end, new_filters)
    end
end


local ntick_handlers = {}

---@param tick integer
---@param handler fun(data:NthTickEventData?)
function tools.on_nth_tick(tick, handler)
    local previous = ntick_handlers[tick]
    if not previous then
        script.on_nth_tick(tick, handler)
        ntick_handlers[tick] = handler
    else
        local new_handler = function(data)
            previous(data)
            handler(data)
        end
        script.on_nth_tick(tick, new_handler)
        ntick_handlers[tick] = new_handler
    end
end

---@type fun()[]
local on_load_handlers

local function on_load_handler()
    if on_load_handlers then
        for _, handler in pairs(on_load_handlers) do
            handler()
        end
    end
end

---@param handler function
function tools.on_load(handler)
    if on_load_handlers then
        table.insert(on_load_handlers, handler)
    else
        on_load_handlers = { handler }
        script.on_load(on_load_handler)
    end
end

---@type fun()[]
local on_init_handlers = nil
---@type boolean?
local load_on_init_flag

---@param handler fun()
function tools.on_init(handler)

    if not on_init_handlers then
        on_init_handlers = {handler}
        script.on_init(function()
            for _, handler in pairs(on_init_handlers) do handler() end
            if load_on_init_flag and on_load_handler then
                on_load_handler()
            end
        end)
    else
        table.insert(on_init_handlers, handler)
    end
end

function tools.fire_on_load() load_on_init_flag = true end

---@type fun(c:ConfigurationChangedData)[]
local configuration_changed_handlers

---@param handler fun(c:ConfigurationChangedData)
function tools.on_configuration_changed(handler)
    if not configuration_changed_handlers then
        configuration_changed_handlers = { handler }
        script.on_configuration_changed(function(data)
            for _, f_handlers in pairs(configuration_changed_handlers) do
                f_handlers(data)
            end
        end)
    else
        table.insert(configuration_changed_handlers, handler)
    end
end

---@type fun(e : EventData.on_tick) | nil
local on_debug_init_handler

function tools.on_debug_init(f)

    if on_debug_init_handler then
        local previous_init = on_debug_init_handler
        ---@param e EventData.on_tick
        on_debug_init_handler = function(e)
            previous_init(e)
            f(e)
        end
    else
        on_debug_init_handler = f
        tools.on_event(defines.events.on_tick ,
        ---@param e EventData.on_tick
            function(e)
            if (on_debug_init_handler) then
                on_debug_init_handler(e)
                on_debug_init_handler = nil
            end
        end)
    end
end

---@type table<string, fun(e:EventData.on_gui_click) >
local on_gui_click_map

---@param e EventData.on_gui_click
local function on_gui_click_handler(e)

    if e.element.valid then
        local handler = on_gui_click_map[e.element.name]
        if handler then handler(e) end
    end
end

---@param button_name string
---@param f fun(e:EventData.on_gui_click)
function tools.on_gui_click(button_name, f)

    if not on_gui_click_map then
        on_gui_click_map = {}
        tools.on_event(defines.events.on_gui_click, on_gui_click_handler)
    end
    on_gui_click_map[button_name] = f
end

---@type table<string, fun(e:EventData) >>
local handler_map = {}

---@type table<integer, boolean>
local handler_registered = {}

local handler_tag = "handler_name"

---@param e EventData
local function call_handler(e)
    local element = e.element --[[@as LuaGuiElement]]
    if not (element and element.valid) then return end

    local name
    if element.tags then name = element.tags[handler_tag] --[[@as string]] end
    if not name then
        name = element.name
        if not name then return end
    end
    local handler = handler_map[name .. "/" .. e.name]
    if handler then handler(e) end
end

---@param name string
---@param event defines.events
---@param callback fun(e:EventData)
function tools.on_named_event(name, event, callback)

    if not handler_registered[event] then
        handler_registered[event] = true
        tools.on_event(event, call_handler)
    end
    local event_index = name .. "/" .. event
    handler_map[event_index] = callback
end

---@param element LuaGuiElement
---@param handler_name string
---@param tags Tags?
function tools.set_name_handler(element, handler_name, tags)
    if not tags then
        element.tags = {[handler_tag] = handler_name}
    else
        tags[handler_tag] = handler_name
        element.tags = tags
    end
end

------------------------------------------------

---@param parent LuaGuiElement
---@param name string
---@return LuaGuiElement?
local function get_child(parent, name)
    ---@type LuaGuiElement?
    local child = parent[name]

    if child then return child end

    local children = parent.children
    if not children then return nil end
    for _, e in ipairs(children) do
        child = get_child(e, name)
        if child then return child end
    end
    return nil
end

tools.get_child = get_child

---@param component LuaGuiElement
---@param parent_name string
function tools.is_child_of(component, parent_name)

    while component do
        if component.name == parent_name then return true end
        component = component.parent
    end
    return false
end

local build_trace = false

---@param value boolean
function tools.set_build_trace(value) build_trace = value end

---@return boolean
function tools.is_build_trace() return build_trace end

---@param parent any
---@return table
function tools.get_fields(parent)
    local fields = {}
    local mt = {
        __index = function(base, key)
            local value = rawget(base, key)
            if value then return value end
            value = tools.get_child(parent, key)
            rawset(base, key, value)
            return value
        end
    }
    setmetatable(fields, mt)
    return fields
end


---@param parent LuaGuiElement
---@param def LuaGuiElement.add_param
---@param path (string|integer)[]
---@param refmap table<string, LuaGuiElement>
---@return LuaGuiElement
local function recursive_build_gui(parent, def, path, refmap)

    local ref = def.ref
    local children = def.children
    local style_mods = def.style_mods
    local tabs = def.tabs

    if (build_trace) then debug("build: def=" .. strip(def)) end

    ---@diagnostic disable-next-line: inject-field
    def.ref = nil
    ---@diagnostic disable-next-line: inject-field
    def.children = nil
    ---@diagnostic disable-next-line: inject-field
    def.style_mods = nil
    ---@diagnostic disable-next-line: inject-field
    def.tabs = nil

    if not def.type then
        if not build_trace then debug("build: def=" .. strip(def)) end
        debug("Missing type")
    end

    local element = parent.add(def)

    if not ref and def.name then refmap[def.name] = element end

    if children then
        if def.type ~= "tabbed-pane" then
            for index, child_def in pairs(children) do
                local name = child_def.name
                if name then
                    table.insert(path, name .. ":" .. index)
                else
                    table.insert(path, index)
                end
                if build_trace then
                    debug("build: path=" .. strip(path))
                end
                recursive_build_gui(element, child_def, path, refmap)
                table.remove(path)
            end
        else
            for index, t in pairs(children) do
                local tab = t.tab
                local content = t.content

                local name = tab.name
                if name then
                    table.insert(path, name .. ":" .. index)
                else
                    table.insert(path, index)
                end
                if build_trace then
                    debug("build: path=" .. strip(path))
                end

                local ui_tab = recursive_build_gui(element, tab, path, refmap)
                local ui_content = recursive_build_gui(element, content, path,
                                                       refmap)
                element.add_tab(ui_tab, ui_content)

                table.remove(path)
            end
        end
    end

    if ref then
        local lmap = refmap
        for index, ipath in ipairs(ref) do
            if index == #ref then
                lmap[ipath] = element
            else
                local m = lmap[ipath]
                if not m then
                    m = {}
                    lmap[ipath] = m
                end
                lmap = m
            end
        end
    end

    if style_mods then
        if build_trace then
            debug("build: style_mods=" .. strip(style_mods))
        end
        for name, value in pairs(style_mods) do
            element.style[name] = value
        end
    end

    return element
end

---@param parent LuaGuiElement
---@param def table
---@return  table<string, any>
function tools.build_gui(parent, def)

    local refmap = {}
    if not def.type then
        for index, subdef in ipairs(def) do
            recursive_build_gui(parent, subdef, { index }, refmap)
        end
    else
        recursive_build_gui(parent, def, {}, refmap)
    end
    return refmap
end


---@type table<string, fun(any)>
local user_event_handlers = {}

---@param name string
---@param handler fun(any)
function tools.register_user_event(name, handler)

    local previous = user_event_handlers[name]
    if not previous then
        user_event_handlers[name] = handler
    else

        local new_handler = function(data)
            previous(data)
            handler(data)
        end
        user_event_handlers[name] = new_handler
    end
end

---@param name string
---@param data any
function tools.fire_user_event(name, data)

    local handler = user_event_handlers[name]
    if handler then handler(data) end
end

---@param signal SignalID
---@return string?
function tools.signal_to_sprite(signal)
    if not signal then return nil end
    local type = signal.type
    if type == "virtual" then
        return "virtual-signal/" .. signal.name
    else
        return type .. "/" .. signal.name
    end
end

local gmatch = string.gmatch

---@param sprite string?
---@return SignalID?
function tools.sprite_to_signal(sprite)
    if not sprite then return nil end
    local split = gmatch(sprite, "([^/]+)[/]([^/]+)")
    local type, name = split()
    if type == "virtual-signal" then type = "virtual" end
    return { type = type, name = name }
end

---@param signal SignalID?
---@return string?
function tools.signal_to_name(signal)
    if not signal then return nil end
    local type = signal.type
    return "[" .. type .. "=" .. signal.name .. "]"
end

---@param index integer
---@return string
function tools.get_event_name(index)
    for name, i in pairs(defines.events) do
        if i == index then return name end
    end
    return "[unknown:"..index.."]"
end

---@param type string
---@param name string
---@return any
local function check_signal(type, name)
    if type == "virtual" then
        return game.virtual_signal_prototypes[name]
    elseif type == "item" then
        return game.item_prototypes[name]
    elseif type == "fluid" then
        return game.fluid_prototypes[name]
    end
    return true
end

---@param sprite string?
---@param default string?
---@return string?
function tools.check_sprite(sprite, default)
    if not sprite then return nil end
    local signal = tools.sprite_to_signal(sprite)
    ---@cast signal -nil
    if check_signal(signal.type, signal.name) then
        return sprite
    else
        return default
    end
end


--- Find dimension of an entity
---@param master LuaEntity
---@return number
---@return number
function tools.get_radius(master)
    local selection_box = master.selection_box
    local xradius = math.floor(selection_box.right_bottom.x -
                                   selection_box.left_top.x) / 2 - 0.1
    local yradius = math.floor(selection_box.right_bottom.y -
                                   selection_box.left_top.y) / 2 - 0.1
    return xradius, yradius
end

---Destroy a set of entities
---@param master LuaEntity
---@param entity_names string[]
function tools.destroy_entities(master, entity_names)

    if not master.surface.valid then return end
    local pos = master.position
    local proto = master.prototype
    local xradius = proto.tile_width / 2 - 0.01
    local yradius = proto.tile_height / 2 - 0.01
	local entities = master.surface.find_entities_filtered {
        area = {
            left_top = {x = pos.x - xradius, y = pos.y - yradius},
            right_bottom = {x = pos.x + xradius, y = pos.y + yradius}
        },
		name = entity_names
	}
    for _, e in pairs(entities) do if e.valid then e.destroy() end end
end


---@param index integer
---@param base table<string, integer>
---@return string
function tools.get_constant_name(index, base)
    for name, i in pairs(base) do if i == index then return name end end
    return "[unknown:"..index.."]"
end

------------------------------------------------

local define_directions = defines.direction

---@param direction integer
---@param pos MapPosition
---@return MapPosition
function tools.get_local_disp(direction, pos)

	if direction == define_directions.north then
		return { x = pos[1], y = pos[2] }
	elseif direction == define_directions.south then
		return { x = -pos[1], y = -pos[2] }
	elseif direction == define_directions.west then
		return { x = pos[2], y = -pos[1] }
	elseif direction == define_directions.east then
		return { x = -pos[2], y = pos[1] }
	else
		error("Invalid direction: " .. direction)
	end
end

---@param direction integer
---@param pos MapPosition
---@return MapPosition
function tools.get_front(direction, pos)
	if direction == define_directions.north then
		return { x = pos.x, y = pos.y - 1 }
	elseif direction == define_directions.south then
		return { x = pos.x, y = pos.y + 1 }
	elseif direction == define_directions.west then
		return { x = pos.x - 1, y = pos.y }
	elseif direction == define_directions.east then
		return { x = pos.x + 1, y = pos.y }
	else
		error("Invalid direction: " .. tostring(direction))
	end
end

---@param direction integer
---@param pos MapPosition
---@return MapPosition
function tools.get_back(direction, pos)
	if direction == define_directions.north then
		return { x = pos.x, y = pos.y + 1 }
	elseif direction == define_directions.south then
		return { x = pos.x, y = pos.y - 1 }
	elseif direction == define_directions.west then
		return { x = pos.x + 1, y = pos.y }
	elseif direction == define_directions.east then
		return { x = pos.x - 1, y = pos.y }
	else
		error("Invalid direction: " .. tostring(direction))
	end
end

tools.opposite_directions = {
    [define_directions.north ] = define_directions.south,
    [define_directions.south ] = define_directions.north,
    [define_directions.east ] = define_directions.west,
    [define_directions.west ] = define_directions.east
}

---@param direction integer
---@return integer
function tools.get_opposite_direction(direction)
	if direction == define_directions.north then
		return define_directions.south
	elseif direction == define_directions.south then
		return define_directions.north
	elseif direction == defines.direction.west then
		return define_directions.east
	elseif direction == defines.direction.east then
		return define_directions.west
	else
		error("Invalid direction: " .. tostring(direction))
	end
end

---@param p1 MapPosition
---@param p2 MapPosition
---@return number
function tools.distance2(p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    return dx * dx + dy * dy
end

---@param p1 MapPosition
---@param p2 MapPosition
---@return number
function tools.distance(p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    return math.sqrt(dx * dx + dy * dy)
end

---@param str string
---@param start string
---@return boolean
function tools.starts_with(str, start) return str:sub(1, #start) == start end

---@param str string
---@param ending string
---@return boolean
function tools.ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

------------------------------------------------

local stack_size_map = {}

---@param name string
function tools.get_item_stack_size(name)

    local stack_size = stack_size_map[name]
    if stack_size then return stack_size end

    local signal = tools.sprite_to_signal(name) --[[@as SignalID]]
    if signal.type == "item" then
        local proto = game.item_prototypes[signal.name]
        if proto then
            stack_size = proto.stack_size
        else
            stack_size = 1
        end
    else
        stack_size = 1
    end

    stack_size_map[signal.name] = stack_size
    stack_size_map[name] = stack_size
    return stack_size
end

local item_prototypes_map = {}

---@param name string
---@return LuaItemPrototype
function tools.get_item_prototype(name)
    local proto = item_prototypes_map[name]
    if proto then return proto end

    proto = game.item_prototypes[name]
    item_prototypes_map[name] = proto
    return proto
end

---@param children LuaGuiElement[]
---@param element LuaGuiElement
---@return integer
function tools.index_of(children, element)
    local index = 1
    for _, c in pairs(children) do
        if c == element then
            return index
        end
        index = index + 1
    end
    return index
end

---@param value any
---@return string
function tools.number_to_text(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

---@param s string?
---@return string
function tools.trim(s)
    if not s then return "" end
    return s:match "^%s*(.-)%s*$"
 end


---@param text string?
---@return number?
function tools.text_to_number(text)
    if text == nil then return nil end
    if text == "" then return nil end
    return tonumber(text)
end

local panel_names = {}

---@param name string
function tools.add_panel_name(name)
    panel_names[name] = true
end

---@param player LuaPlayer
---@param name string
---@return LuaGuiElement?
function tools.get_panel(player, name)
    for _, child in pairs(player.gui.children) do
        local panel = child[name]
        if panel then return panel end
    end
    return nil
end

---@param player LuaPlayer
---@param name string
function tools.close_panel(player, name)
    local panel = tools.get_panel(player, name)
    if panel then panel.destroy() end
end

local close_panel = tools.close_panel

---@param player LuaPlayer
function tools.close_panels(player)
    for name, _ in pairs(panel_names) do
        close_panel(player, name)
    end
end

---@class Params.create_standard_panel
---@field container LuaGuiElement?
---@field panel_name string
---@field title LocalisedString
---@field is_draggable boolean?
---@field title_menu_func fun(titleflow:LuaGuiElement)?
---@field close_button_name string                  @ nil if no close button
---@field close_button_tooltip LocalisedString
---@field close_button_filter string[]?
---@field create_inner_frame boolean?

---@param player LuaPlayer
---@param params Params.create_standard_panel
---@return LuaGuiElement
---@return LuaGuiElement
function tools.create_standard_panel(player, params)
    local container = params.container
    if not container then
        container = player.gui.screen
    end

    ---@type LuaGuiElement
    local frame = container.add {
        type = "frame",
        direction = 'vertical',
        name = params.panel_name
    }

    local title = params.title
    local titleflow = frame.add { type = "flow" }
    titleflow.add {
        type = "label",
        caption = title,
        style = "frame_title",
        ignored_by_interaction = true,
        name = "title"
    }

    local drag = titleflow.add {
        type = "empty-widget"
    }
    if params.is_draggable then
        drag.style = "flib_titlebar_drag_handle"
        drag.drag_target = frame
        titleflow.drag_target = frame
    end

    if params.title_menu_func then
        params.title_menu_func(titleflow)
    end

    if params.close_button_name then
        titleflow.add {
            type = "sprite-button",
            name = params.close_button_name,
            tooltip = params.close_button_tooltip,
            style = "frame_action_button",
            mouse_button_filter = params.close_button_filter or { "left" },
            sprite = "utility/close_white",
            hovered_sprite = "utility/close_black"
        }
    end

    local inner_frame
    if params.create_inner_frame then
        inner_frame = frame.add {
            type = "frame",
            direction = "vertical",
            style = "inside_shallow_frame_with_padding"
        }
        inner_frame.style.vertically_stretchable = true
        inner_frame.style.horizontally_stretchable = true
    else
        inner_frame = frame.add {
            type = "frame",
            direction = "vertical"
        }
        inner_frame.style.vertically_stretchable = true
        inner_frame.style.horizontally_stretchable = true
    end
    return frame, inner_frame
end

local abs = math.abs
local math_precision = 0.000001
local round_digit = 2

---@param value number
---@return number
local function fround(value)
    if abs(value) <= math_precision then
        return 0
    end
    local precision = math.pow(10, math.floor(0.5 + math.log(math.abs(value), 10)) - round_digit)
    value = math.floor(value / precision) * precision
    return value
end

tools.fround = fround

return tools
