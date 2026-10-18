-- Exercises a REFramework script inside the mock: load, frames, UI, hooks. Collects every uncaught error.
local H = { errors = {}, phases = {} }
HARNESS = H

local function err(phase, e)
    H.errors[#H.errors + 1] = { phase = phase, msg = tostring(e) }
end
local function try(phase, fn, ...)
    local ok, e = xpcall(fn, debug.traceback, ...)
    if not ok then err(phase, e) end
    return ok
end

function H.load_script(src, chunkname)
    local fn, e = load(src, "@" .. chunkname, "t", _ENV)
    if not fn then err("compile", e); return false end
    return try("load", fn)
end

function H.frames(n)
    for i = 1, n do
        for _, e in ipairs(MOCK.entry) do try("entry:" .. e.name, e.f) end
        for _, f in ipairs(MOCK.frame) do try("on_frame", f) end
    end
end

function H.ui(press_buttons)
    MOCK.imgui_buttons = press_buttons and true or false
    for _, f in ipairs(MOCK.ui) do try(press_buttons and "ui(buttons pressed)" or "ui", f) end
    MOCK.imgui_buttons = false
end

-- call every installed hook with empty arguments (pointers = 0)
function H.hooks()
    for i, h in ipairs(MOCK.hooks) do
        local m = h.method
        local name = (type(m) == "table" and m.td and (m.td.name .. "." .. tostring(m.sig))) or tostring(m)
        local args = {}
        for k = 1, 12 do args[k] = 0 end
        if h.pre then try("hook pre " .. name, h.pre, args) end
        if h.post then try("hook post " .. name, h.post, 0) end
    end
end

function H.reset()
    for _, f in ipairs(MOCK.reset) do try("on_script_reset", f) end
    for _, f in ipairs(MOCK.config_save) do try("on_config_save", f) end
end

function H.summary()
    local labels = {}
    for k in pairs(MOCK.labels) do labels[#labels + 1] = k end
    table.sort(labels)
    local files = {}
    for k in pairs(MOCK.files) do files[#files + 1] = k end
    table.sort(files)
    local jf = {}
    for k in pairs(MOCK.json_files) do jf[#jf + 1] = k end
    return { errors = H.errors, hooks = #MOCK.hooks, frame_cbs = #MOCK.frame, ui_cbs = #MOCK.ui, entry_cbs = #MOCK.entry,
        labels = labels, files = files, json_files = jf }
end
return H
