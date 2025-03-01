

--- Class that contains information about a processor
---
---@class ProcInfo
---@field id integer
---@field processor LuaEntity           @ Processor object
---@field surface LuaSurface            @ Editor surface of the processor
---@field iopoints LuaEntity[]          @ List of external IO points object
---@field is_packed boolean             @ Circuit is packed
---@field blueprint string              @ Content blueprint as string
---@field model  string                 @ Model name
---@field tick integer
---@field circuits Circuit[]
---@field iopoint_infos IOPointInfo[]   @ Internal IO points
---@field sprite1 string
---@field sprite2 string
---@field references string[]
---@field origin_surface_name string
---@field origin_surface_position MapPosition
---@field origin_controller_type defines.controllers
---@field physical_surface_index integer
---@field physical_position MapPosition
---@field physical_controller_type defines.controllers
---@field in_pole LuaEntity?            @ Energy pole
---@field generator LuaEntity?          @ Electrical generator
---@field sprite_ids LuaRenderObject[]
---@field accu LuaEntity
---@field name string
---@field input_list InputProperty[]    @ Properties of the processor
---@field inner_input InputProperty     @ For inner computation
---@field value_id integer
---@field label string?
---@field input_values table<string, any> 
---@field draw_version integer
---@field energ_pole LuaEntity?
---@field wires WireDefinition[]

---@class WireDefinition
---@field iopoint_index integer
---@field src_connector defines.wire_connector_id
---@field dst_connector  defines.wire_connector_id
---@field dst_name string
---@field dst_pos MapPosition

---@class Circuit
---@field name string
---@field ext_name string
---@field ext_position MapPosition
---@field index integer         @ Index for ip point
---@field sprite_type string
---@field sprite_name string
---@field position MapPosition
---@field direction number
---@field graphics_variation integer
---@field parameters any
---@field enabled boolean?
---@field circuit_condition CircuitConditionDefinition?
---@field use_colors boolean
---@field connections CircuitConnection[]

---@class CircuitConnection
---@field target_entity integer
---@field wire integer
---@field source_circuit_id integer
---@field target_circuit_id integer

--- Class that contains information about an internal IO point
---
---@class IOPointInfo
---@field index integer
---@field entity LuaEntity
---@field id integer
---@field label string
---@field input boolean
---@field output boolean
---@field red_display integer
---@field green_display integer
---@field text_id LuaRenderObject
---@field iopoint_text_color Color
---@field red_wired boolean
---@field green_wired boolean

---@class RemoteInterface
---@field interface_name string
---@field name string
---@field packed_names string[]

---@class Model
---@field blueprint string
---@field references string[] @ Names of referenced models
---@field tick integer
---@field name string
---@field sprite1 string
---@field sprite2 string
---@field circuits Circuit[]

---@alias ProcInfoTable table<integer,ProcInfo>

--------------------------------

---@class Display
---@field type integer
---@field is_internal boolean?

---@class GraphicDisplay : Display
---@field scale number?
---@field offsetx number?
---@field offsety number?
---@field orientation number?

---@class StringDisplay : GraphicDisplay
---@field halign  integer
---@field valign  integer

---@class SignalDisplay : StringDisplay
---@field signal string?

---@class TextDisplay : StringDisplay
---@field text string
---@field color integer?

---@class SpriteDisplay : GraphicDisplay

---@class MetaDisplay : GraphicDisplay
---@field location integer

---@class MultiSignalDisplay : GraphicDisplay
---@field mode integer
---@field col_size integer?
---@field dim_size integer?
---@field col_width integer?
---@field max integer?
---@field color integer?
---@field has_frame boolean?
---@field has_background boolean?
---@field background_color integer?
---@field offset integer?

---@class DisplayInfo
---@field id integer
---@field props Display
---@field entity LuaEntity
---@field typeid LuaRenderObject?
---@field dataid LuaRenderObject?
---@field internal DisplayRuntime?

---@class DisplayRuntime : EntityWithIdAndProcess
---@field renderid LuaRenderObject?
---@field renderids LuaRenderObject[]?
---@field props Display
---@field source LuaEntity
---@field proc LuaEntity
---@field freeze boolean?
---@field hidden boolean?
---@field signals Signal[]
---@field x integer?
---@field y integer?
---@field scale integer?

---@class SignalDisplayRuntime : DisplayRuntime
---@field signal SignalID?
---@field color string
---@field value number

---@class SpriteDisplayRuntime : DisplayRuntime
---@field sprite_name string

---@class TextDisplayRuntime : DisplayRuntime
---@field color_index integer?
---@field text string
---@field active boolean
---@field lines string[]

---@class MetaRuntime : DisplayRuntime
---@field signal string?

---@class MultiSignalRuntime : DisplayRuntime
---@field processor LuaEntity?
---@field offsetx number?
---@field offsety number?
---@field xinit number?
---@field yinit number?
---@field color_index integer?
---@field max integer?
---@field xd number?
---@field yd number?
---@field colcount integer?
---@field has_frame boolean?
---@field has_background boolean?
---@field background_color integer?
---@field offset integer?

--------------------------------

---@class Input
---@field type integer
---@field label string
---@field value_id integer
---@field typeid LuaRenderObject?
---@field dataid LuaRenderObject?

---@class IntegerInput : Input
---@field min integer?
---@field max integer?
---@field width integer?
---@field signal string?
---@field default_value integer?

---@class SliderInput : Input
---@field min integer?
---@field max integer?
---@field width integer?
---@field signal string?
---@field default_value integer?

---@class ToggleInput : Input
---@field signal string
---@field count integer?
---@field tooltips string

---@class DropDownInput : Input
---@field signal string
---@field labels string 

---@class ChooseSignalsInput : Input
---@field count integer

---@class ChooseSignalsWithCountInput : Input
---@field count integer

---@class InputProperty
---@field gid string
---@field value_id string?
---@field input Input | CommInput
---@field entity LuaEntity
---@field x integer
---@field y integer
---@field label string
---@field inner_inputs InputProperty[]

--------------------------------
---@class CommInput : Input
---@field channel_name string
---@field channel_red boolean
---@field channel_green boolean

---@class CommContext
---@field name_channels {[string]:CommChannel}
---@field max_index integer
---@field surface LuaSurface

---@class CommChannel
---@field name string
---@field index integer
---@field router LuaEntity

---@class CommConfig
---@field channels string[]
---@field sort_mode CommSortMode
---@field apply_filters boolean?
---@field filters string[]
---@field group string
---@field subgroup string
---@field min number?

