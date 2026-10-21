-- Minimal stand-in for REFramework's Lua API (DD2), for loading and exercising scripts outside the game.
-- Game objects are stubs: unknown members give nil, so scripts run their "nothing there" paths.
-- Scenarios can register singletons and per-method results through MOCK.

local M = {
    hooks = {}, frame = {}, ui = {}, entry = {}, reset = {}, config_save = {},
    files = {}, json_files = {}, labels = {}, writes = {}, singletons = {}, method_results = {},
    imgui_tree = true, imgui_buttons = false, next_addr = 0x10000, storage = {},
}
MOCK = M
M.clock = 1000.0
M.real_clock = os.clock
os.clock = function() return M.clock end
M.native = {}
M.components = {}
M.method_params = {}

local function next_addr() M.next_addr = M.next_addr + 0x40; return M.next_addr end

-- ---------- type definitions ----------
local TD_cache = {}
local TD = {}
TD.__index = TD
local Method = {}
Method.__index = Method
local Field = {}
Field.__index = Field

local function count_params(sig)
    local inside = sig:match("%((.*)%)")
    if not inside or inside == "" then return 0 end
    local n = 1
    for _ in inside:gmatch(",") do n = n + 1 end
    return n
end

function M.td(name)
    name = tostring(name)
    local t = TD_cache[name]
    if not t then
        t = setmetatable({ name = name, methods = {}, fields = {} }, TD)
        TD_cache[name] = t
    end
    return t
end
function TD:get_full_name() return self.name end
function TD:get_name() return self.name:match("([^%.]+)$") end
function TD:get_namespace() return self.name:match("^(.*)%.") or "" end
function TD:get_method(sig)
    local m = self.methods[sig]
    if not m then
        m = setmetatable({ td = self, sig = sig, name = sig:match("^([^%(]+)") }, Method)
        self.methods[sig] = m
    end
    return m
end
function TD:get_methods() local out = {}; for _, m in pairs(self.methods) do out[#out + 1] = m end; return out end
function TD:get_field(name)
    local f = self.fields[name]
    if not f then f = setmetatable({ td = self, name = name }, Field); self.fields[name] = f end
    return f
end
function TD:get_fields() local out = {}; for _, f in pairs(self.fields) do out[#out + 1] = f end; return out end
function TD:get_parent_type() return self.parent and M.td(self.parent) or nil end
function TD:is_value_type() return false end
function TD:is_a(other) return false end
function TD:get_runtime_type() return M.obj("System.RuntimeType") end
function TD:create_instance() return M.obj(self.name) end
function TD:get_size() return 0x10 end
function TD:get_valuetype_size() return 0x10 end

function Method:get_name() return self.name end
function Method:get_num_params() return self.params and #self.params or count_params(self.sig) end
function Method:get_param_types()
    local out = {}
    for _, n in ipairs(self.params or {}) do out[#out + 1] = M.td(n) end
    return out
end
function Method:get_return_type() return M.td(self.ret or "System.Object") end
function Method:get_declaring_type() return self.td end
function Method:is_static() return false end
function Method:get_function() return 0 end
function Method:call(obj, ...)
    local r = M.method_results[self.td.name .. "." .. self.sig]
    if type(r) == "function" then return r(obj, ...) end
    return r
end
Method.__call = function(self, obj, ...) return self:call(obj, ...) end

function Field:get_name() return self.name end
function Field:get_type() return M.td("System.Object") end
function Field:is_static() return self.static or false end
function Field:get_offset_from_base() return 0 end
function Field:get_data(obj)
    if self.static then return self.value end
    if obj and type(obj) == "table" and rawget(obj, "__f") then return obj.__f[self.name] end
    return nil
end
function Field:set_data(obj, v)
    if obj and type(obj) == "table" and rawget(obj, "__f") then obj.__f[self.name] = v end
end

function M.define_method(tdname, name, params, ret)
    local m = M.td(tdname):get_method(name .. "(" .. table.concat(params or {}, ", ") .. ")")
    m.name, m.params, m.ret = name, params, ret
    return m
end
function M.define_enum(tdname, values)
    local t = M.td(tdname)
    t.parent = "System.Enum"
    for k, v in pairs(values) do
        local f = t:get_field(k)
        f.static, f.value = true, v
    end
    return t
end

-- ---------- managed objects ----------
local Obj = {}
local ObjMT = {}
function M.obj(type_name, fields)
    return setmetatable({ __tn = type_name or "System.Object", __f = fields or {}, __addr = next_addr() }, ObjMT)
end
ObjMT.__index = function(t, k)
    local f = rawget(t, "__f")
    if f[k] ~= nil then return f[k] end
    local o = Obj[k]
    if o then return o end
    -- unknown member: method-looking names become functions returning nil, field-looking names are nil
    if type(k) == "string" and k:match("^[a-z]") then
        return function(self, ...) return Obj.call(self, k, ...) end
    end
    return nil
end
ObjMT.__newindex = function(t, k, v) rawget(t, "__f")[k] = v end
function Obj.call(self, name, ...)
    local key = rawget(self, "__tn") .. "." .. tostring(name)
    local r = M.method_results[key]
    if r == nil then r = M.method_results["*." .. tostring(name)] end
    if type(r) == "function" then return r(self, ...) end
    return r
end
function Obj.get_field(self, name) return rawget(self, "__f")[name] end
function Obj.set_field(self, name, v) rawget(self, "__f")[name] = v end
function Obj.get_type_definition(self) return M.td(rawget(self, "__tn")) end
function Obj.get_address(self) return rawget(self, "__addr") end
function Obj.add_ref(self) return self end
function Obj.release(self) end
function Obj.force_release(self) end
function Obj.get_elements(self) return rawget(self, "__f").__elements or {} end
function Obj.get_size(self) return #(rawget(self, "__f").__elements or {}) end
function Obj.get_reference_count(self) return 1 end
function Obj.write_float(self) end
function Obj.write_dword(self) end
function Obj.read_dword(self) return 0 end
function Obj.read_float(self) return 0.0 end
function Obj.read_byte(self) return 0 end
function Obj.read_qword(self) return 0 end

-- ---------- vectors ----------
local function vec_mt(n)
    local mt = {}
    mt.__index = function(t, k)
        if k == "length" then return function(s) return math.sqrt(s.x * s.x + s.y * s.y + (s.z or 0) * (s.z or 0)) end end
        if k == "normalized" then return function(s) return s end end
        if k == "dot" then return function(a, b) return a.x * b.x + a.y * b.y + (a.z or 0) * (b.z or 0) end end
        return nil
    end
    mt.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = (a.z or 0) + (b.z or 0), w = a.w }, mt) end
    mt.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = (a.z or 0) - (b.z or 0), w = a.w }, mt) end
    mt.__mul = function(a, b)
        if type(a) == "number" then a, b = b, a end
        return setmetatable({ x = a.x * b, y = a.y * b, z = (a.z or 0) * b, w = a.w }, mt)
    end
    return mt
end
local V3, V4 = vec_mt(3), vec_mt(4)
Vector2f = { new = function(x, y) return setmetatable({ x = x or 0, y = y or 0 }, V3) end }
Vector3f = { new = function(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3) end }
Vector4f = { new = function(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 0 }, V4) end }
Quaternion = { new = function(w, x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 1 }, V4) end,
    identity = function() return setmetatable({ x = 0, y = 0, z = 0, w = 1 }, V4) end }
Matrix4x4f = { new = function() return {} end }
ValueType = { new = function(td) return M.obj(td and td.name or "System.ValueType") end }

-- ---------- sdk ----------
sdk = {}
sdk.PreHookResult = { CALL_ORIGINAL = 0, SKIP_ORIGINAL = 1 }
function sdk.find_type_definition(name) if name == nil then return nil end return M.td(name) end
function sdk.get_managed_singleton(name) return M.singletons[name] end
function sdk.get_native_singleton(name) return M.native[name] end
function sdk.typeof(name) return M.obj("System.RuntimeType", { name = name }) end
function sdk.hook(method, pre, post, ignore_jmp)
    if method == nil then error("sdk.hook: method is nil", 2) end
    M.hooks[#M.hooks + 1] = { method = method, pre = pre, post = post }
end
function sdk.hook_vtable() end
local objs_by_addr = setmetatable({}, { __mode = "v" })
function M.ptr_of(o) if type(o) == "table" and rawget(o, "__addr") then objs_by_addr[o.__addr] = o; return o.__addr end return o end
function sdk.to_managed_object(p)
    if type(p) == "table" then return p end
    if type(p) == "number" and p ~= 0 then return objs_by_addr[p] end
    return nil
end
function sdk.to_int64(p)
    if type(p) == "number" then return math.tointeger(p) or 0 end
    if type(p) == "boolean" then return p and 1 or 0 end
    if type(p) == "table" and rawget(p, "__addr") then return p.__addr end
    return 0
end
function sdk.to_ptr(v)
    if type(v) == "boolean" then return v and 1 or 0 end
    if type(v) == "table" then return M.ptr_of(v) end
    return v or 0
end
function sdk.to_float(p) return 0.0 end
function sdk.to_double(p) return 0.0 end
function sdk.float_to_ptr(f) return 0 end
function sdk.to_valuetype(p, tn) return M.obj(tn) end
function sdk.create_instance(tn) return M.obj(tn) end
function sdk.create_managed_string(s) return M.obj("System.String", { value = s }) end
function sdk.create_managed_array(tn, n) local el = {}; return M.obj(tn .. "[]", { __elements = el }) end
function sdk.create_resource(tn, path) return nil end
function sdk.create_userdata(tn, path) return nil end
function sdk.call_native_func(obj, td, sig, ...)
    local r = M.method_results["native." .. tostring(sig)]
    if type(r) == "function" then return r(obj, td, ...) end
    return r
end
function sdk.call_object_func() return nil end
function sdk.get_tdb() return nil end
function sdk.is_managed_object(o) return type(o) == "table" and rawget(o, "__tn") ~= nil end
function sdk.get_primary_camera() return nil end
function sdk.deserialize() return {} end

-- ---------- re ----------
re = {}
function re.on_frame(f) M.frame[#M.frame + 1] = f end
function re.on_draw_ui(f) M.ui[#M.ui + 1] = f end
function re.on_pre_application_entry(name, f) M.entry[#M.entry + 1] = { name = name, f = f, pre = true } end
function re.on_application_entry(name, f) M.entry[#M.entry + 1] = { name = name, f = f } end
function re.on_script_reset(f) M.reset[#M.reset + 1] = f end
function re.on_config_save(f) M.config_save[#M.config_save + 1] = f end
function re.on_pre_gui_draw_element() end
function re.on_gui_draw_element() end
function re.msg() end

-- ---------- imgui ----------
local function label_of(a) if type(a) == "string" then M.labels[a] = true end end
imgui = setmetatable({}, { __index = function(_, k)
    if k == "tree_node" or k == "collapsing_header" or k == "begin_window" or k == "begin_child_window" or k == "tree_node_str_id" then
        return function(label) label_of(label); return M.imgui_tree end
    end
    if k == "button" or k == "small_button" or k == "menu_item" or k == "selectable" then
        return function(label) label_of(label); return M.imgui_buttons end
    end
    if k == "text" or k == "text_colored" or k == "same_line" or k == "separator" or k == "spacing" or k == "tree_pop"
        or k == "end_window" or k == "end_child_window" or k == "push_id" or k == "pop_id" or k == "new_line"
        or k == "push_item_width" or k == "pop_item_width" or k == "set_next_window_size" or k == "set_tooltip" then
        return function(a) if k ~= "text" then label_of(a) end end
    end
    if k == "is_item_hovered" then return function() return false end end
    -- value widgets: (label, value, ...) -> changed, value
    return function(label, value) label_of(label); return false, value end
end })

-- ---------- files / json ----------
fs = {}
function fs.write(name, text) M.writes[#M.writes + 1] = name; M.files[name] = tostring(text) end
function fs.read(name) return M.files[name] end

-- v1.9.185 made the script APPEND its event log with io.open(name, "a") instead of rewriting it with
-- fs.write, so the mock stopped seeing it and "error lines in the mod's log" became vacuously 0.
-- Route io.open on the script's own data files into M.files; everything else goes to the real io.
do
    local real_open = io.open
    local function mine(n) return n:match("^RancorReinforcements") or n:match("^rr_") or n:match("^claude_") end
    io.open = function(name, mode)
        local n = tostring(name)
        if not mine(n) then return real_open(name, mode) end
        mode = tostring(mode or "r")
        if mode:find("r") then
            local cur = M.files[n]
            if cur == nil then return nil end
            local done = false
            return {
                read = function(_, fmt)
                    if done then return nil end
                    done = true
                    return cur
                end,
                lines = function() local sent = false
                    return function() if sent then return nil end; sent = true; return cur end end,
                close = function() return true end,
            }
        end
        if not mode:find("a") then M.files[n] = "" end
        M.writes[#M.writes + 1] = n
        return {
            write = function(self, text) M.files[n] = (M.files[n] or "") .. tostring(text); return self end,
            close = function() return true end,
        }
    end
end
function fs.glob() return {} end
json = {}
local function deep(v) if type(v) ~= "table" then return v end local o = {}; for k, x in pairs(v) do o[k] = deep(x) end; return o end
function json.load_file(name) local v = M.json_files[name]; return v ~= nil and deep(v) or nil end
function json.dump_file(name, t) M.json_files[name] = deep(t); return true end
function json.load_string(s) return nil end
function json.dump_string(t) return "{}" end

-- ---------- misc ----------
thread = {}
function thread.get_hook_storage() return M.storage end
function thread.get_id() return 1 end
log = { info = function() end, debug = function() end, warn = function() end, error = function() end }
draw = setmetatable({}, { __index = function() return function() return nil end end })
reframework = setmetatable({}, { __index = function(_, k)
    if k == "get_game_name" then return function() return "dd2" end end
    return function() return false end
end })

return M
