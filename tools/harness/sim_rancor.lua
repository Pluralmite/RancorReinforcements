-- Simulated Rancor fights for the harness: a vortex in the scene, a player, the CharacterID enum and the
-- game's spawn request (GenerateManager.requestGenerate). The script's spawn hook is driven with wave
-- requests and the outcome of every big-enemy slot is counted.
local M = MOCK
local SIM = { ids = {}, names = {}, results = {}, swaps = {}, slots = 0, errors_logged = {} }
SIM_ = SIM

local IDS = {
    "Invalid", "ch261000_00", "ch254001_60", "ch226003_60", "ch227002_00", "ch227003_00", "ch231000_00", "ch226002_60",
    "ch257003_10", "ch261001_00", "ch253000_60", "ch270000_00", "ch255000_01", "ch253012_00", "ch257001_00",
    "ch255010_00", "ch258000_10", "ch252000_00", "ch271000_00", "ch272002_00", "ch223003_00", "ch226003_50", "ch227000_10", "ch257000_00", "ch257000_50", "ch253010_00", "ch221006_00", "ch272000_00", "ch256001_50", "ch251001_50",
    -- these five reinforcements existed in the script but not here, so the simulator could never produce them:
    -- Hydra, Brine Golem, Brine Sphinx, Brine Dullahan, Brine Cyclops
    "ch255000_90", "ch252000_13", "ch253001_50", "ch229000_50", "ch250000_51",
}
-- v1.9.124: extra IDs from the realistic layouts (set by run_sim.py before this file runs)
do
    local have = {}
    for _, n in ipairs(IDS) do have[n] = true end
    for _, n in ipairs(SIM_EXTRA_IDS or {}) do if not have[n] then have[n] = true; IDS[#IDS + 1] = n end end
end
local vals = {}
for i, n in ipairs(IDS) do vals[n] = (n == "Invalid") and -1 or (1000 + i); SIM.ids[n] = vals[n]; SIM.names[vals[n]] = n end
M.define_enum("app.CharacterID", vals)

M.define_method("app.GenerateManager", "requestGenerate",
    { "app.GenerateInfo.GenerateInfoContainer", "System.Action`1<app.PrefabInstantiateResults>" }, "System.Void")

-- scene: transforms (a vortex while a fight is on) and monsters (none: nothing ever actually spawns)
local scene = M.obj("via.Scene")
M.native["via.SceneManager"] = M.obj("via.SceneManager")
M.method_results["native.get_CurrentScene()"] = function() return scene end
SIM.vortex = false
local vortex_go = M.obj("via.GameObject")
-- must be a name the script actually looks up: K.VORTEX_NAMES = { "15_CS_Vortexrage" }
vortex_go.__f.__name = "15_CS_Vortexrage"
M.method_results["via.GameObject.get_Name"] = function(self) return self.__f.__name end
-- v1.9.102+ caches the vortex GameObject and re-checks get_Valid before rescanning. A literal `true` here
-- meant the cached object stayed valid forever, so the vortex never ENDED: refresh_vortex never saw the
-- transition, never reset `event`, and the per-Rancor reinforcement quota was spent on fight 1 and never
-- replenished. Variants and finale rolls kept working because they do not draw on that quota, which is
-- exactly why the aggregate showed ~50% Brine variants next to ~0% pool picks.
M.method_results["via.GameObject.get_Valid"] = function(self)
    if self == vortex_go then return SIM.vortex and true or false end
    return true
end
local vortex_tr = M.obj("via.Transform")
M.method_results["via.Transform.get_GameObject"] = function(self) return self.__f.go end
vortex_tr.__f.go = vortex_go
-- v1.9.156 replaced the full-scene Transform scan with a direct name lookup. The mock did not implement it,
-- so pcall failed, K.FIND_GO went false and NO vortex was ever detected - every simulated fight since has
-- swapped nothing while still reporting "0 errors". This is that lookup.
SIM.vortex_names = { ["15_CS_Vortexrage"] = true }
M.method_results["via.Scene.findGameObject(System.String)"] = function(self, nm)
    if not SIM.vortex then return nil end
    nm = tostring(nm)
    if SIM.vortex_names[nm] or nm == vortex_go.__f.__name then return vortex_go end
    return nil
end
M.method_results["via.Scene.findComponents(System.Type)"] = function(self, t)
    local tn = t and t.__f and t.__f.name
    local list = {}
    if tn == "via.Transform" and SIM.vortex then list[1] = vortex_tr end
    return M.obj(tostring(tn) .. "[]", { __elements = list })
end

-- player
SIM.pos = { x = 100, y = 10, z = 100 }
local ptr = M.obj("via.Transform")
M.method_results["via.Transform.get_Position"] = function() return Vector3f.new(SIM.pos.x, SIM.pos.y, SIM.pos.z) end
M.method_results["via.Transform.get_UniversalPosition"] = function() return Vector3f.new(SIM.pos.x, SIM.pos.y, SIM.pos.z) end
M.method_results["via.Transform.get_AxisZ"] = function() return Vector3f.new(0, 0, 1) end
local player = M.obj("app.Character")
M.method_results["app.Character.get_Transform"] = function() return ptr end
M.singletons["app.CharacterManager"] = M.obj("app.CharacterManager", { ["<ManualPlayer>k__BackingField"] = player })

-- the game's Rancor manager: which Rancor is running (ProcessingVoidEventID; -1 = none)
SIM.void_id = -1
M.singletons["app.AppraiseCycleManager"] = M.obj("app.AppraiseCycleManager")
M.method_results["app.AppraiseCycleManager.get_ProcessingVoidEventID"] = function() return SIM.void_id end
M.method_results["app.AppraiseCycleManager.get_IsProcessingHighLevelVoid"] = function() return SIM.void_id == 3606 end
-- v1.9.187: the game's own classification + its "I am building the last boss wave" flag
M.method_results["app.AppraiseCycleManager.isProcessingHighLevelVoidBattle"] = function() return SIM.void_id == 3606 end
M.method_results["app.AppraiseCycleManager.isMiddleVoidEvent"] = function(_, id)
    id = tonumber(id) or SIM.void_id
    return id ~= 3606 and id >= 0 and (id % 100) >= 50
end
SIM.last_boss_node = false
M.method_results["app.AppraiseCycleManager.get_IsProcessingVoidLastBossNode"] = function() return SIM.last_boss_node end

-- the game's "Death defeated" check (DefeatCh227003Condition.evaluateImpl): run the script's post hook on `game_says`
function SIM.death_check(game_says)
    for _, h in ipairs(M.hooks) do
        local m = h.method
        if type(m) == "table" and m.td and m.td.name == "app.appraiseCycle.condition.DefeatCh227003Condition" and m.name == "evaluateImpl" then
            if not h.post then return game_says end
            local r = h.post(game_says and 1 or 0)
            if type(r) == "table" then r = r.__ptr or r.v end
            return r == 1 or r == true
        end
    end
    return game_says
end

-- one realistic fight: waves = list of lists of character IDs, void_id = the Rancor's ID (3606 = Devouring)
function SIM.fight_layout(waves, void_id, devour)
    SIM.pos = devour and { x = -2304, y = 648, z = -3802 } or { x = 100, y = 10, z = 100 }
    SIM.void_id = void_id
    SIM.vortex = true
    SIM.advance(2)
    local fight = { swaps = {}, n = 0 }
    local recs = {}
    for wi, wave in ipairs(waves) do
        -- the game raises this while it builds the Rancor's final boss wave
        SIM.last_boss_node = (wi == #waves)
        for _, slot in ipairs(wave) do
            local got, info, idobj = SIM.request(slot)
            if got ~= slot then fight.n = fight.n + 1; fight.swaps[#fight.swaps + 1] = slot .. ">" .. got end
            recs[#recs + 1] = { idobj = idobj, orig = slot }
            SIM.advance(0.5)
        end
        SIM.advance(25)
    end
    for _, r in ipairs(recs) do
        if SIM.names[r.idobj.__f._SelectedCharacterID] ~= r.orig then SIM.unrestored = (SIM.unrestored or 0) + 1 end
    end
    SIM.last_boss_node = false
    fight.death_after = SIM.death_check(false)
    SIM.vortex = false
    SIM.void_id = -1
    SIM.advance(40)
    return fight
end

function SIM.find_hook()
    for _, h in ipairs(M.hooks) do
        local m = h.method
        if type(m) == "table" and m.td and m.td.name == "app.GenerateManager" and m.name == "requestGenerate" then return h end
    end
end

function SIM.advance(sec, step)
    step = step or 0.5
    local t = 0
    while t < sec do
        M.clock = M.clock + step
        t = t + step
        HARNESS.frames(1)
    end
end

-- one spawn request; returns the ID the game would spawn
function SIM.request(name, wave_callback)
    local h = SIM.hook or SIM.find_hook()
    SIM.hook = h
    if not h then error("requestGenerate hook not installed") end
    local idobj = M.obj("app.ObjectID", { _SelectedCharacterID = SIM.ids[name] })
    local info = M.obj("app.GenerateInfo.GenerateInfoContainer", {
        _CommonInfo = M.obj("app.GenerateInfo.CommonInfo", { _ObjectID = idobj }),
        _StatusInfo = M.obj("app.GenerateInfo.StatusInfo", { ["<ScaleRate>k__BackingField"] = 1.0 }),
    })
    local args = { 0, 0, M.ptr_of(info), wave_callback == false and 0 or 0x5000 }
    SIM.keep = SIM.keep or {}
    SIM.keep[#SIM.keep + 1] = info
    h.pre(args)
    local got = SIM.names[idobj.__f._SelectedCharacterID] or tostring(idobj.__f._SelectedCharacterID)
    return got, info, idobj
end

function SIM.count(kind, from, to)
    local k = kind .. " | " .. from .. " -> " .. to
    SIM.results[k] = (SIM.results[k] or 0) + 1
end

-- one Rancor fight: waves of requests with gaps, then the vortex closes
function SIM.fight(waves, devour)
    SIM.pos = devour and { x = -2304, y = 648, z = -3802 } or { x = 100, y = 10, z = 100 }
    SIM.void_id = devour and 3606 or 3202
    SIM.vortex = true
    SIM.advance(2)
    local fight = { swaps = {} }
    for wi, wave in ipairs(waves) do
        for _, slot in ipairs(wave) do
            local got, info, idobj = SIM.request(slot)
            local kind = (slot == "ch257003_10") and "final" or ((slot:sub(1, 8) == "ch231000" or slot:sub(1, 8) == "ch226002") and "minor" or "major")
            SIM.count((devour and "devour " or "regular ") .. kind, slot, got)
            if got ~= slot then fight.swaps[#fight.swaps + 1] = got end
            fight.idobjs = fight.idobjs or {}
            fight.idobjs[#fight.idobjs + 1] = { idobj = idobj, orig = slot }
            SIM.advance(0.5)
        end
        SIM.advance(25)   -- the wave plays out; swaps that never spawned are put back after 15 s
    end
    -- every swapped spawn record must have been restored by now
    for _, r in ipairs(fight.idobjs or {}) do
        local now = SIM.names[r.idobj.__f._SelectedCharacterID]
        if now ~= r.orig then
            SIM.unrestored = (SIM.unrestored or 0) + 1
        end
    end
    SIM.vortex = false
    SIM.void_id = -1
    SIM.advance(40)
    SIM.fights = (SIM.fights or 0) + 1
    local per = {}
    for _, s in ipairs(fight.swaps) do per[s] = (per[s] or 0) + 1 end
    for k, n in pairs(per) do
        SIM.max_per_fight = SIM.max_per_fight or {}
        if n > (SIM.max_per_fight[k] or 0) then SIM.max_per_fight[k] = n end
    end
    return fight
end

-- a Satanica wave: nothing in it may be touched
function SIM.satanica_check()
    SIM.void_id = 3606
    SIM.vortex = true
    SIM.advance(2)
    SIM.request("ch261001_00")
    local touched = 0
    for i = 1, 6 do
        local got = SIM.request("ch261000_00")
        if got ~= "ch261000_00" then touched = touched + 1 end
        SIM.advance(1)
    end
    SIM.vortex = false
    SIM.advance(700)
    return touched
end
return SIM
