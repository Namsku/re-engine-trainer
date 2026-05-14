--[[
    Biorand RE3R Trainer v1.0
    by namsku / Biorand

    Features
    ────────
    • D2D overlay: enemy ESP, item ESP, all-object ESP
      Each label shows: GameObject name · GUID · type · distance
    • ImGui window: Enemy viewer, Item viewer, Object viewer, Settings
    • Distance filter (configurable, default 30 m)
    • Draws from offline.EnemyController, item types, full scene walk

    Placement (REFramework autorun):
      reframework/autorun/biorand_re3r_trainer.lua
      (emv_engine lives one level up: ../emv_engine/init.lua)
]]

if reframework:get_game_name() ~= "re3" then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- Config & Persistence
-- ═══════════════════════════════════════════════════════════════════════════

local TITLE    = "Biorand RE3R Trainer v1.0"
local CFG_FILE = "biorand_re3r_trainer.json"

local C = {
    -- ESP toggles
    show_enemy_esp  = true,
    show_item_esp   = true,
    show_obj_esp    = false,   -- all-object overlay (expensive at high range)
    show_dev_overlay = true,   -- top-left dev panel

    -- Distance filter (meters from player)
    esp_range       = 30.0,

    -- Labels to display per entity
    show_guid       = true,    -- GUID (via get_GUID API; hidden when unavailable)
    show_go_name    = true,    -- raw GameObject name
    show_type       = true,    -- component type name
    show_hp         = true,    -- HP for enemies (when available)
    show_dist       = true,    -- distance label

    -- Overlay style
    font_name       = "Consolas",
    font_size       = 16,
    hide_dead       = true,

    -- Object scan
    obj_scan_range  = 20.0,    -- separate, tighter range for obj overlay
    obj_max_results = 200,     -- cap to avoid spam

    -- Scanner throttle (frames between full rescans)
    scan_interval   = 45,

    -- UI state
    ui_visible      = true,
    ui_tab          = 1,
    scan_paused     = false,   -- freeze scanner so records stay stable for copying
}

local function cfg_save() pcall(json.dump_file, CFG_FILE, C) end
local function cfg_load()
    local ok, d = pcall(json.load_file, CFG_FILE)
    if ok and type(d) == "table" then
        for k, v in pairs(d) do
            if C[k] ~= nil and type(v) == type(C[k]) then C[k] = v end
        end
    end
end
cfg_load()
re.on_config_save(cfg_save)

-- ═══════════════════════════════════════════════════════════════════════════
-- Runtime State
-- ═══════════════════════════════════════════════════════════════════════════

local R = {
    tick          = 0,
    sw            = 1920,
    sh            = 1080,
    player_pos    = nil,   -- {x,y,z}  (camera fallback when player GO unavailable)
    player_hp     = 0,
    player_mhp    = 0,
    dev_rotation  = nil,   -- yaw in degrees from camera quaternion

    enemies       = {},    -- { name, guid, go_name, type_name, pos, hp, mhp, dist, dead }
    items         = {},    -- { name, guid, go_name, type_name, pos, dist }
    objects       = {},    -- { name, guid, go_name, type_name, pos, dist }
    scenarios     = {},    -- { no, name, is_advance } active ScenarioController entries

    dev = {                -- game-state fields for top-left overlay
        scene         = "",
        map_id        = nil,
        area_id       = nil,
        rank          = nil,
        playtime      = nil,
        player_name   = "",
        player_state  = "",
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Engine Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local _sm    = sdk.get_native_singleton("via.SceneManager")
local _sm_td = sdk.find_type_definition("via.SceneManager")
local _script_dir = nil
local _map_lookup = { loaded = false, by_key = {}, by_id = {}, rows = {} }
local to_int
local read_named_int

-- Note: RE3R SceneManager method uses "()" suffix
local function get_scene()
    local ok, s = pcall(sdk.call_native_func, _sm, _sm_td, "get_CurrentScene()")
    return ok and s or nil
end

local function get_script_dir()
    if _script_dir ~= nil then return _script_dir end
    _script_dir = ""
    pcall(function()
        local info = debug.getinfo(1, "S")
        if info and info.source then
            _script_dir = info.source:gsub("^@", ""):match("(.+[\\/])") or ""
        end
    end)
    return _script_dir
end

local function trim(s)
    if s == nil then return "" end
    return tostring(s):match("^%s*(.-)%s*$") or ""
end

local function parse_csv_line(line)
    local result = {}
    local current = {}
    local in_quotes = false
    local i = 1
    while i <= #line do
        local ch = line:sub(i, i)
        if ch == "\"" then
            if in_quotes and line:sub(i + 1, i + 1) == "\"" then
                current[#current + 1] = "\""
                i = i + 1
            else
                in_quotes = not in_quotes
            end
        elseif ch == "," and not in_quotes then
            result[#result + 1] = table.concat(current)
            current = {}
        else
            current[#current + 1] = ch
        end
        i = i + 1
    end
    result[#result + 1] = table.concat(current)
    return result
end

local function normalize_scene_key(value)
    local s = trim(value)
    if s == "" then return nil end
    s = s:lower():gsub("\\", "/")
    s = s:match("([^/]+)$") or s
    s = s:gsub("%.scn%.20$", "")
    s = s:gsub("%.pfb%.17$", "")
    s = s:gsub("^scene%[", "")
    s = s:gsub("@.*$", "")
    s = s:gsub("%]", "")
    s = s:gsub("%s+", "_")
    s = s:gsub("[^%w_]+", "_")
    s = s:gsub("_+", "_")
    s = s:gsub("^_+", "")
    s = s:gsub("_+$", "")
    if s == "" then return nil end
    return s
end

local function register_map_lookup(entry, raw_key)
    local key = normalize_scene_key(raw_key)
    if not key or key == "" then return end
    if not _map_lookup.by_key[key] then
        _map_lookup.by_key[key] = entry
    end
end

local function load_map_lookup()
    if _map_lookup.loaded then return end
    _map_lookup.loaded = true

    local base_dir = get_script_dir()
    local candidates = {
        base_dir .. "..\\..\\src\\BioRand.RE3R\\data\\map.csv",
        base_dir .. "..\\src\\BioRand.RE3R\\data\\map.csv",
        base_dir .. "map.csv",
        base_dir .. "..\\map.csv",
        base_dir .. "..\\..\\map.csv",
    }

    local handle = nil
    for _, path in ipairs(candidates) do
        local file = io.open(path, "r")
        if file then
            handle = file
            break
        end
    end
    if not handle then return end

    for line in handle:lines() do
        if not line:match("^MapID,") then
            local cells = parse_csv_line(line)
            local map_id = tonumber(trim(cells[1] or ""))
            if map_id then
                local entry = {
                    map_id = map_id,
                    area_id = trim(cells[2] or ""),
                    name = trim(cells[3] or ""),
                    debug_name = trim(cells[4] or ""),
                    description = trim(cells[5] or ""),
                }
                _map_lookup.by_id[map_id] = _map_lookup.by_id[map_id] or entry
                _map_lookup.rows[#_map_lookup.rows + 1] = entry
                register_map_lookup(entry, entry.debug_name)
                register_map_lookup(entry, entry.name)
                register_map_lookup(entry, entry.description)
            end
        end
    end
    handle:close()
end

local function resolve_map_lookup_key(raw)
    load_map_lookup()
    local key = normalize_scene_key(raw)
    if not key then return nil end

    local exact = _map_lookup.by_key[key]
    if exact then return exact end

    local best = nil
    local best_score = 0
    for candidate_key, entry in pairs(_map_lookup.by_key) do
        if key:find(candidate_key, 1, true) or candidate_key:find(key, 1, true) then
            local score = #candidate_key
            if score > best_score then
                best = entry
                best_score = score
            end
        end
    end
    return best
end

local function resolve_map_area_from_metadata()
    load_map_lookup()

    if R.dev.map_id ~= nil then
        local entry = _map_lookup.by_id[to_int(R.dev.map_id)]
        if entry and (R.dev.area_id == nil or R.dev.area_id == "?") and entry.area_id ~= "" then
            R.dev.area_id = entry.area_id
        end
        if entry then return entry end
    end

    local adv_name = nil
    for _, scenario in ipairs(R.scenarios or {}) do
        if scenario.is_advance and scenario.name then
            adv_name = scenario.name
            break
        end
    end
    if not adv_name and R.scenarios and #R.scenarios > 0 then
        adv_name = R.scenarios[1].name
    end

    local entry = resolve_map_lookup_key(R.dev.scene)
        or resolve_map_lookup_key(adv_name)
    if entry then
        if R.dev.map_id == nil then R.dev.map_id = entry.map_id end
        if (R.dev.area_id == nil or R.dev.area_id == "") and entry.area_id ~= "" then
            R.dev.area_id = entry.area_id
        end
    end
    return entry
end

local function resolve_map_id_from_enemy_manager()
    local enemy_manager = nil
    pcall(function()
        local enemy_manager_type = sdk.game_namespace and sdk.game_namespace("EnemyManager") or nil
        if enemy_manager_type then
            enemy_manager = sdk.get_managed_singleton(enemy_manager_type)
        end
    end)
    if not enemy_manager then
        pcall(function() enemy_manager = sdk.get_managed_singleton("app.EnemyManager") end)
    end
    if not enemy_manager then
        pcall(function() enemy_manager = sdk.get_managed_singleton("offline.EnemyManager") end)
    end
    if not enemy_manager then return nil end

    return read_named_int(enemy_manager, {
        "<LastPlayerStaySceneID>k__BackingField",
        "LastPlayerStaySceneID",
        "_LastPlayerStaySceneID",
        "get_LastPlayerStaySceneID",
        "<LastPlayerStayMapID>k__BackingField",
        "LastPlayerStayMapID",
        "_LastPlayerStayMapID",
        "get_LastPlayerStayMapID",
    })
end

local function dist3(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- GUID format validator: must be 8-4-4-4-12 hex with hyphens
local _guid_pat = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function extract_guid(go)
    if not go then return nil end
    -- Try the proper GUID API (returns System.Guid value type)
    local ok, g = pcall(go.call, go, "get_GUID()")
    if ok and g then
        local ok2, s2 = pcall(g.call, g, "ToString()")
        if ok2 and s2 then
            local str = tostring(s2)
            if str:match(_guid_pat) then return str end
        end
    end
    -- Fall back to parsing ToString() — but only accept real UUID shape.
    -- In RE3R, ToString() returns "GameObject[name@HEXADDR]", which is a
    -- memory address that changes every session. Return nil for those.
    local ok3, s = pcall(go.call, go, "ToString()")
    if not ok3 or not s then return nil end
    local raw = tostring(s):match("@([%x%-]+)%]$")
    if raw and raw:match(_guid_pat) then return raw end
    return nil  -- memory address — don't surface as GUID
end

-- Get component of a known type from a GameObject
local _type_cache = {}
local function get_component(go, type_name)
    if not go then return nil end
    if not _type_cache[type_name] then
        _type_cache[type_name] = sdk.typeof(type_name)
    end
    local t = _type_cache[type_name]
    if not t then return nil end
    local ok, comp = pcall(go.call, go, "getComponent(System.Type)", t)
    return ok and comp or nil
end

-- Read HP fields from offline.HitPointController
local function get_hp(go)
    local hpc = get_component(go, "offline.HitPointController")
    if not hpc then return nil, nil end
    local hp, mhp = nil, nil
    pcall(function() hp  = hpc:get_field("CurrentHitPoint") end)
    pcall(function() hp  = hp  or hpc:call("get_CurrentHitPoint") end)
    pcall(function() mhp = hpc:get_field("HitPointMax") end)
    pcall(function() mhp = mhp or hpc:call("get_HitPointMax") end)
    return hp, mhp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Access
-- ═══════════════════════════════════════════════════════════════════════════

local function get_player_go()
    local go = nil
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if pm then
            go = pm:get_field("PlayerObj")
            if not go then
                local ok, pg = pcall(pm.call, pm, "get_Player")
                if ok then go = pg end
            end
        end
    end)
    if not go then
        pcall(function()
            local om = sdk.get_managed_singleton("app.ObjectManager")
            if om then
                go = om:get_field("PlayerObj")
                if not go then
                    local ok, pg = pcall(om.call, om, "get_Player")
                    if ok then go = pg end
                end
            end
        end)
    end
    return go
end

local function update_player_pos()
    local updated = false

    -- Primary: try player GameObject
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local pos = xf:call("get_Position")
        if pos then
            R.player_pos = {x = pos.x, y = pos.y, z = pos.z}
            updated = true
        end
    end)

    -- Fallback: camera position (always available, accurate reference)
    if not updated then
        pcall(function()
            local cam = sdk.get_primary_camera()
            if not cam then return end
            local go = cam:call("get_GameObject")
            if not go then return end
            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if pos then
                R.player_pos = {x = pos.x, y = pos.y, z = pos.z}
            end
        end)
    end
end

-- ── Quaternion → Euler yaw (degrees) ──────────────────────────────────────
local function quat_yaw(q)
    if not q then return nil end
    local siny = 2.0 * (q.w * q.y - q.z * q.x)
    siny = math.max(-1.0, math.min(1.0, siny))
    return math.deg(math.asin(siny))
end

local function update_camera_rotation()
    pcall(function()
        local scene = get_scene()
        if not scene then return end
        local mv = scene:call("get_MainView")
        if not mv then return end
        local cam = mv:call("get_PrimaryCamera")
        if not cam then return end
        local go = cam:call("get_GameObject")
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local q = xf:call("get_Rotation")
        if q then R.dev_rotation = quat_yaw(q) end
    end)
end

local function update_player_hp()
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local hp, mhp = get_hp(go)
        if hp  then R.player_hp  = hp  end
        if mhp then R.player_mhp = mhp end
    end)
end

-- ── Game state scan (rank, scene, flags) ──────────────────────────────────
to_int = function(v)
    if v == nil then return nil end
    if type(v) == "number" then return math.tointeger(v) or v end
    local n = tonumber(v)
    if n then return math.tointeger(n) or n end
    local ok, s = pcall(tostring, v)
    if ok and s then
        n = tonumber(s)
        if n then return math.tointeger(n) or n end
    end
    return nil
end

read_named_int = function(obj, names)
    if not obj then return nil end

    for _, name in ipairs(names) do
        local ok, value = pcall(obj.call, obj, name)
        value = ok and to_int(value) or nil
        if value ~= nil then return value end
    end

    for _, name in ipairs(names) do
        local ok, value = pcall(obj.get_field, obj, name)
        value = ok and to_int(value) or nil
        if value ~= nil then return value end
    end

    return nil
end

local function get_any_singleton(name)
    local singleton = nil
    pcall(function() singleton = sdk.get_managed_singleton(name) end)
    if singleton then return singleton end
    pcall(function() singleton = sdk.get_native_singleton(name) end)
    return singleton
end

local function probe_runtime_int(singleton_names, value_names, nested_names)
    for _, singleton_name in ipairs(singleton_names) do
        local singleton = get_any_singleton(singleton_name)
        if singleton then
            local direct = read_named_int(singleton, value_names)
            if direct ~= nil then return direct end

            for _, nested_name in ipairs(nested_names) do
                local nested = nil
                local ok, value = pcall(singleton.call, singleton, nested_name)
                if ok then nested = value end
                if not nested then
                    ok, value = pcall(singleton.get_field, singleton, nested_name)
                    if ok then nested = value end
                end
                if nested then
                    local nested_value = read_named_int(nested, value_names)
                    if nested_value ~= nil then return nested_value end
                end
            end
        end
    end

    return nil
end

local function scan_map_area_ids()
    local manager_names = {
        "offline.gamemastering.ScenarioSequenceManager",
        "offline.GameProgressManager",
        "offline.SceneManager",
        "offline.PlayerManager",
        "offline.gamemastering.MapManager",
        "offline.gamemastering.AreaManager",
        "app.MapManager",
        "app.AreaManager",
        "app.RoomManager",
        "app.StageManager",
    }
    local nested_names = {
        "get_GameSaveData",
        "GameSaveData",
        "_GameSaveData",
        "get_SaveData",
        "SaveData",
        "_SaveData",
    }
    local map_names = {
        "get_MapID",
        "get_MapId",
        "get_CurrentMapID",
        "get_CurrentMapId",
        "getCurrentMapID",
        "getCurrentMapId",
        "MapID",
        "MapId",
        "_MapID",
        "_MapId",
        "CurrentMapID",
        "CurrentMapId",
        "_CurrentMapID",
        "_CurrentMapId",
        "<MapID>k__BackingField",
        "<MapId>k__BackingField",
    }
    local area_names = {
        "get_AreaID",
        "get_AreaId",
        "get_CurrentAreaID",
        "get_CurrentAreaId",
        "getCurrentAreaID",
        "getCurrentAreaId",
        "get_AreaNo",
        "get_CurrentAreaNo",
        "getCurrentAreaNo",
        "AreaID",
        "AreaId",
        "_AreaID",
        "_AreaId",
        "CurrentAreaID",
        "CurrentAreaId",
        "_CurrentAreaID",
        "_CurrentAreaId",
        "AreaNo",
        "_AreaNo",
        "CurrentAreaNo",
        "_CurrentAreaNo",
        "<AreaID>k__BackingField",
        "<AreaId>k__BackingField",
        "<AreaNo>k__BackingField",
    }

    local scene = get_scene()
    R.dev.map_id = resolve_map_id_from_enemy_manager()
        or read_named_int(scene, map_names)
        or probe_runtime_int(manager_names, map_names, nested_names)
    R.dev.area_id = read_named_int(scene, area_names)
        or probe_runtime_int(manager_names, area_names, nested_names)
    resolve_map_area_from_metadata()
end

local function scan_game_state()
    -- Scene name from current scene object
    pcall(function()
        local scene = get_scene()
        if not scene then return end
        local name = nil
        pcall(function() name = tostring(scene:call("get_Name")  or "") end)
        if not name or name == "" or name == "nil" then
            pcall(function() name = tostring(scene:call("get_name") or "") end)
        end
        -- ToString fallback: "SceneView[name@guid]"
        if not name or name == "" or name == "nil" then
            local s = tostring(scene)
            name = s:match("%[(.-)@") or s:match("Scene%[(.-)%]") or ""
        end
        if name and name ~= "" and name ~= "nil" then
            R.dev.scene = name
        end
    end)

    scan_map_area_ids()

    -- Rank: try offline.GameRankManager
    pcall(function()
        local rm = sdk.get_managed_singleton("offline.GameRankManager")
        if not rm then return end
        local rank = nil
        pcall(function() rank = rm:call("getCurrentRank") end)
        if not rank then pcall(function() rank = rm:get_field("_Rank") end) end
        if not rank then pcall(function() rank = rm:get_field("<Rank>k__BackingField") end) end
        if rank ~= nil then R.dev.rank = rank end
    end)

    -- Player name / state from PlayerManager
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        -- Figure out which player (Jill = pl0000, Carlos = pl2000)
        local go = get_player_go()
        if go then
            local n = ""
            pcall(function() n = tostring(go:call("get_Name") or "") end)
            if n:find("pl0000") or n:find("Jill") then R.dev.player_name = "Jill"
            elseif n:find("pl2000") or n:find("Carlos") then R.dev.player_name = "Carlos"
            elseif n ~= "" then R.dev.player_name = n end
        end
        -- Player state enum
        local state = nil
        pcall(function() state = pm:call("get_GamePlayerState") end)
        if not state then pcall(function() state = pm:get_field("_PlayerState") end) end
        if state ~= nil then R.dev.player_state = tostring(state) end
    end)

    -- Playtime: try several known paths
    pcall(function()
        local sm = sdk.get_managed_singleton("offline.SceneManager")
        if sm then
            pcall(function() R.dev.playtime = sm:call("get_PlayTime") end)
        end
        if not R.dev.playtime then
            local gm = sdk.get_managed_singleton("offline.GameProgressManager")
            if gm then
                pcall(function() R.dev.playtime = gm:call("get_PlayTime") end)
            end
        end
    end)
end

-- ── Scenario Controller ───────────────────────────────────────────────────
-- offline.ScenarioDefine.ScenarioNo enum: values 0–62 from rszre3 data
local SCENARIO_NAMES = {
    [0]="S00_0000",[1]="S00_0100",[2]="S00_0200",[3]="S00_0300",
    [4]="S00_3000",[5]="S00_3100",[6]="S00_3200",[7]="S00_3300",
    [8]="S00_3400",[9]="S01_0000",[10]="S01_0100",[11]="S01_0200",
    [12]="S01_0300",[13]="S01_0400",[14]="S01_0500",[15]="S01_0600",
    [16]="S01_0700",[17]="S03_0000",[18]="S03_0100",[19]="S03_1000",
    [20]="S03_1100",[21]="S03_1200",[22]="S03_1500",[23]="S03_2000",
    [24]="S03_2100",[25]="S03_2200",[26]="S03_2300",[27]="S03_2500",
    [28]="S02_0000",[29]="S02_0100",[30]="S02_0200",[31]="S02_0300",
    [32]="S02_0400",[33]="S02_0500",[34]="S02_0600",[35]="S02_0700",
    [36]="S02_0800",[37]="S02_0900",[38]="S03_3000",[39]="S03_3100",
    [40]="S03_3200",[41]="S03_3500",[42]="S03_3600",[43]="S04_0000",
    [44]="S04_0100",[45]="S04_0200",[46]="S04_0300",[47]="S04_0400",
    [48]="S04_0500",[49]="S04_0600",[50]="S04_5000",[51]="S04_5100",
    [52]="S04_5200",[53]="S04_5300",[54]="S04_5400",[55]="S04_5500",
    [56]="S05_0000",[57]="S05_0100",[58]="S05_0200",[59]="S05_0300",
    [60]="S05_0400",[61]="S05_0500",[62]="S05_0600",
}

-- Scenario debug state — populated by scan_scenarios(), shown in ImGui panel
local _scn_debug = { ssm_found = false, method_used = "", raw_val = nil, methods = {} }

local function scan_scenarios()
    local results = {}
    _scn_debug.ssm_found = false
    _scn_debug.method_used = ""
    _scn_debug.raw_val = nil

    pcall(function()
        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end
        _scn_debug.ssm_found = true

        -- Dump method names once (first successful singleton access)
        if #_scn_debug.methods == 0 then
            pcall(function()
                local td = sdk.find_type_definition("offline.gamemastering.ScenarioSequenceManager")
                if td then
                    local ms = td:get_methods()
                    for _, m in ipairs(ms) do
                        local mn = m:get_name()
                        if mn then _scn_debug.methods[#_scn_debug.methods + 1] = mn end
                    end
                    table.sort(_scn_debug.methods)
                end
            end)
        end

        -- Try every plausible way to read ScenarioNo from the singleton
        local sno = nil
        local function try(label, fn)
            if sno ~= nil then return end
            local ok, v = pcall(fn)
            if ok and v ~= nil and type(v) == "number" then
                sno = math.tointeger(v)
                _scn_debug.method_used = label
                _scn_debug.raw_val = v
            end
        end

        -- Direct field access (various naming conventions)
        try("get_field ScenarioNo",                function() return ssm:get_field("ScenarioNo") end)
        try("get_field _ScenarioNo",               function() return ssm:get_field("_ScenarioNo") end)
        try("get_field currentScenarioNo",         function() return ssm:get_field("currentScenarioNo") end)
        try("get_field _currentScenarioNo",        function() return ssm:get_field("_currentScenarioNo") end)
        try("get_field <ScenarioNo>k__BackingField", function() return ssm:get_field("<ScenarioNo>k__BackingField") end)

        -- Method calls
        try("call get_ScenarioNo",        function() return ssm:call("get_ScenarioNo") end)
        try("call get_CurrentScenarioNo", function() return ssm:call("get_CurrentScenarioNo") end)
        try("call getCurrentScenarioNo",  function() return ssm:call("getCurrentScenarioNo") end)

        -- Via GameSaveData nested struct
        try("GameSaveData.ScenarioNo", function()
            local sd = nil
            pcall(function() sd = ssm:call("get_GameSaveData") end)
            if not sd then pcall(function() sd = ssm:get_field("_GameSaveData") end) end
            if not sd then pcall(function() sd = ssm:get_field("GameSaveData") end) end
            if sd then return sd:get_field("ScenarioNo") end
        end)

        if sno ~= nil then
            results[#results + 1] = {
                no         = sno,
                name       = SCENARIO_NAMES[sno] or ("?" .. tostring(sno)),
                is_advance = true,
            }
        end
    end)

    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Camera / Screen
-- ═══════════════════════════════════════════════════════════════════════════

local function update_screen_size()
    pcall(function()
        local view = sdk.call_native_func(_sm, _sm_td, "get_MainView")
        if view then
            local w = view:call("get_WindowWidth")
            local h = view:call("get_WindowHeight")
            if w and w > 0 then R.sw = w end
            if h and h > 0 then R.sh = h end
        end
    end)
end

-- Convert world pos {x,y,z} to screen. Returns nil if behind camera or W2S unavailable.
-- Called inline at render time — matches the dev trainer pattern.
local _has_w2s = (draw ~= nil) and (draw.world_to_screen ~= nil)
local function world_to_screen(pos, y_off)
    if not _has_w2s or not pos then return nil end
    local ok, sp = pcall(draw.world_to_screen,
        Vector3f.new(pos.x, pos.y + (y_off or 0), pos.z))
    if not ok or not sp then return nil end
    if sp.x ~= sp.x or sp.y ~= sp.y then return nil end  -- NaN guard
    return sp
end

-- ── Scene Hierarchy Path ──────────────────────────────────────────────────
-- Walk Transform.get_Parent() chain to produce "/Root/Area/GO" path.
local function get_transform_path(xf)
    if not xf then return "" end
    local parts = {}
    local cur = xf
    local prev_addr = nil
    for _ = 1, 20 do
        local go, name = nil, ""
        pcall(function() go = cur:call("get_GameObject") end)
        if go then
            pcall(function() name = tostring(go:call("get_Name") or "") end)
        end
        if name ~= "" then table.insert(parts, 1, name) end

        local par = nil
        pcall(function() par = cur:call("get_Parent") end)
        if not par then break end
        local addr = nil
        pcall(function() addr = par:get_address() end)
        if not addr or addr == prev_addr then break end
        prev_addr = addr
        cur = par
    end
    return #parts > 0 and ("/" .. table.concat(parts, "/")) or ""
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scanners
-- ═══════════════════════════════════════════════════════════════════════════

-- findComponents helper — returns the managed array and its count
local function find_comps(type_name)
    local scene = get_scene()
    if not scene then return nil, 0 end
    local td = sdk.find_type_definition(type_name)
    if not td then return nil, 0 end
    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", td:get_runtime_type()) end)
    if not comps then return nil, 0 end
    local ok, n = pcall(comps.call, comps, "get_Count")
    return comps, (ok and n) or 0
end

-- Build a record from a component's owner GameObject
local function build_record(comp, cat)
    local go = nil
    pcall(function() go = comp:call("get_GameObject") end)
    if not go then return nil end

    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then return nil end

    local pos = nil
    pcall(function() pos = xf:call("get_Position") end)
    if not pos then return nil end

    local pp = R.player_pos
    local dist = pp and dist3(pos.x, pos.y, pos.z, pp.x, pp.y, pp.z) or 0

    -- Only process within filter range (with a margin for the scanner)
    if dist > C.esp_range * 1.5 then return nil end

    local go_name = ""
    pcall(function() go_name = tostring(go:call("get_Name") or "") end)

    local guid = extract_guid(go)

    -- Full component type name (namespace.ClassName)
    local type_name = ""
    pcall(function()
        local td = comp:get_type_definition()
        if td then type_name = td:get_full_name() or "" end
    end)

    -- Scene hierarchy path via Transform parent chain
    local path = get_transform_path(xf)

    local rec = {
        name      = go_name,
        go_name   = go_name,
        guid      = guid,
        type_name = type_name,
        path      = path,
        pos       = { x = pos.x, y = pos.y, z = pos.z },
        dist      = dist,
        sx        = nil,   -- screen x, updated every frame
        sy        = nil,   -- screen y, updated every frame
    }

    if cat == "enemy" then
        local hp, mhp = get_hp(go)
        rec.hp   = hp
        rec.mhp  = mhp
        rec.dead = (hp and hp <= 0) or false
    end

    return rec
end

-- Enemy scanner: offline.EnemyController
local function scan_enemies()
    local comps, n = find_comps("offline.EnemyController")
    if not comps or n <= 0 then return {} end
    local results = {}
    local seen = {}
    for i = 0, math.min(n - 1, 150) do
        pcall(function()
            local c = comps:call("get_Item", i)
            if not c then return end
            local addr = c:get_address()
            if seen[addr] then return end
            seen[addr] = true
            local rec = build_record(c, "enemy")
            if rec then results[#results + 1] = rec end
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

-- Item scanner: multiple RE3R item types
local ITEM_TYPES = {
    "offline.gamemastering.Item",
    "offline.HandHeldItem",
    "offline.gimmick.action.SetItem",
}

local function scan_items()
    local results = {}
    local seen = {}
    for _, tname in ipairs(ITEM_TYPES) do
        pcall(function()
            local comps, n = find_comps(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n - 1, 150) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local addr = c:get_address()
                    if seen[addr] then return end
                    seen[addr] = true
                    local rec = build_record(c, "item")
                    if rec then results[#results + 1] = rec end
                end)
            end
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

-- Object scanner: all scene transforms within obj_scan_range
local function scan_objects()
    local scene = get_scene()
    if not scene then return {} end
    local td = sdk.find_type_definition("via.Transform")
    if not td then return {} end

    local comps = nil
    pcall(function()
        comps = scene:call("findComponents(System.Type)", td:get_runtime_type())
    end)
    if not comps then return {} end

    local n = 0
    pcall(function()
        local ok, cnt = pcall(comps.call, comps, "get_Count")
        n = ok and cnt or 0
    end)
    if n <= 0 then return {} end

    local results = {}
    local pp = R.player_pos
    local max_range = C.obj_scan_range
    local max_results = C.obj_max_results

    -- Collect a set of enemy/item addresses to skip duplicates
    local skip = {}
    for _, e in ipairs(R.enemies) do skip[e.go_name] = true end
    for _, itm in ipairs(R.items)   do skip[itm.go_name] = true end

    for i = 0, math.min(n - 1, 3000) do
        if #results >= max_results then break end
        pcall(function()
            local xf = comps:call("get_Item", i)
            if not xf then return end

            -- Quick position check first (cheap)
            local pos = nil
            pcall(function() pos = xf:call("get_Position") end)
            if not pos then return end

            local dist = pp and dist3(pos.x, pos.y, pos.z, pp.x, pp.y, pp.z) or 0
            if dist > max_range then return end

            local go = nil
            pcall(function() go = xf:call("get_GameObject") end)
            if not go then return end

            local go_name = ""
            pcall(function() go_name = tostring(go:call("get_Name") or "") end)
            if go_name == "" or #go_name <= 1 then return end
            if skip[go_name] then return end  -- already in enemy/item lists

            local guid = extract_guid(go)

            -- First non-Transform component type name
            local type_name = ""
            pcall(function()
                local count = go:call("get_ComponentCount") or 0
                for ci = 0, math.min(count - 1, 6) do
                    pcall(function()
                        local comp = go:call("getComponent(System.Int32)", ci)
                        if not comp then return end
                        local ctd = comp:get_type_definition()
                        if ctd then
                            local cn = ctd:get_full_name() or ""
                            if cn ~= "via.Transform" and cn ~= "" then
                                type_name = cn
                            end
                        end
                    end)
                    if type_name ~= "" then break end
                end
            end)

            -- Scene hierarchy path
            local path = get_transform_path(xf)

            results[#results + 1] = {
                name      = go_name,
                go_name   = go_name,
                guid      = guid,
                type_name = type_name,
                path      = path,
                pos       = { x = pos.x, y = pos.y, z = pos.z },
                dist      = dist,
                sx        = nil,
                sy        = nil,
            }
        end)
    end

    table.sort(results, function(a, b) return a.dist < b.dist end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Rendering Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local has_d2d  = (d2d  ~= nil)
local has_draw = (draw ~= nil)

-- _d2d_confirmed: set to true the FIRST time the d2d render callback fires.
-- If D2D is installed but broken in RE3R (callback never fires),
-- this stays false and the draw API fallback runs instead.
local _d2d_confirmed = false
local _using_d2d     = false   -- true only while inside the d2d render callback

-- W2S diagnostic counters (reset each render, shown in dev overlay)
local _w2s_ok    = 0
local _w2s_total = 0

-- D2D font cache (only used when _using_d2d = true)
local _fonts = {}
local function get_font(sz, bold)
    if not _using_d2d then return nil end
    local key = sz .. (bold and "B" or "R")
    if not _fonts[key] then
        pcall(function() _fonts[key] = d2d.Font.new(C.font_name, sz, bold or false) end)
    end
    return _fonts[key]
end

-- Unified text with shadow — works in both D2D and draw contexts
local function dtext(font, text, x, y, col)
    if _using_d2d and font then
        pcall(d2d.text, font, text, x + 1, y + 1, 0xCC000000)
        pcall(d2d.text, font, text, x, y, col)
    elseif has_draw then
        pcall(draw.text, text, x + 1, y + 1, 0xCC000000)
        pcall(draw.text, text, x, y, col)
    end
end

-- Unified filled rectangle
local function fill_rect(x, y, w, h, col)
    if _using_d2d then
        pcall(d2d.fill_rect, x, y, w, h, col)
    elseif has_draw then
        pcall(draw.filled_rect, x, y, w, h, col)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dev Overlay — Top-Left Panel
-- ═══════════════════════════════════════════════════════════════════════════

local function render_dev_overlay()
    if not C.show_dev_overlay then return end
    if not has_d2d and not has_draw then return end

    local info = {}
    local function ln(text, col) info[#info + 1] = {text = text, col = col} end

    -- Title
    ln(" BIORAND RE3R", 0xFF44FF88)

    -- Player name
    if R.dev.player_name ~= "" then
        ln(" Player:  " .. R.dev.player_name, 0xFF88CCFF)
    end

    -- Position
    local pos = R.player_pos
    if pos then
        ln(string.format(" Pos:  %.2f,  %.2f,  %.2f", pos.x, pos.y, pos.z), 0xFFE0E0E0)
    else
        ln(" Pos:  (unavailable)", 0xFF888888)
    end

    local map_id = R.dev.map_id ~= nil and tostring(R.dev.map_id) or "?"
    local area_id = R.dev.area_id ~= nil and tostring(R.dev.area_id) or "?"
    ln(string.format(" MapID: %s   AreaID: %s", map_id, area_id), 0xFFCCCCCC)

    -- Camera yaw
    if R.dev_rotation then
        ln(string.format(" Yaw:  %.1f°", R.dev_rotation), 0xFFCCCCCC)
    end

    -- Player HP
    if R.player_hp > 0 or R.player_mhp > 0 then
        local ratio = R.player_mhp > 0 and (R.player_hp / R.player_mhp) or 1
        local hp_col = ratio > 0.5 and 0xFF44FF88 or (ratio > 0.25 and 0xFFFFAA44 or 0xFFFF5555)
        ln(string.format(" HP:   %d / %d", math.floor(R.player_hp), math.floor(R.player_mhp)), hp_col)
    end

    -- Scene: prefer the advancing ScenarioController name, fall back to scene name
    do
        local adv_name = nil
        for _, s in ipairs(R.scenarios) do
            if s.is_advance then adv_name = s.name; break end
        end
        if not adv_name and #R.scenarios > 0 then
            adv_name = R.scenarios[1].name  -- first enabled if none marked advancing
        end
        local scene_str = adv_name or (R.dev.scene ~= "" and R.dev.scene or nil)
        if scene_str then
            ln(" Scene: " .. scene_str, 0xFFFFCC44)
        end
    end

    -- Rank
    if R.dev.rank ~= nil then
        ln(" Rank:  " .. tostring(R.dev.rank), 0xFF88CCFF)
    end

    -- Player state flags
    if R.dev.player_state ~= "" then
        ln(" State: " .. R.dev.player_state, 0xFFAABBCC)
    end

    -- Playtime
    if R.dev.playtime and R.dev.playtime > 0 then
        local t = math.floor(R.dev.playtime)
        ln(string.format(" Time:  %d:%02d", t // 60, t % 60), 0xFF888888)
    end

    -- Enemy / item counts + scan pause indicator
    local counts_col = C.scan_paused and 0xFFFFAA44 or 0xFF666666
    local pause_tag = C.scan_paused and "  [PAUSED]" or ""
    ln(string.format(" En: %d  Items: %d  Obj: %d%s",
        #R.enemies, #R.items, #R.objects, pause_tag), counts_col)

    -- W2S diagnostic: shows whether world_to_screen is producing valid coordinates
    if not _has_w2s then
        ln(" W2S: unavailable", 0xFFFF5555)
    elseif _w2s_total > 0 then
        local w2s_col = _w2s_ok > 0 and 0xFF44FF88 or 0xFFFF5555
        ln(string.format(" W2S: %d/%d", _w2s_ok, _w2s_total), w2s_col)
    end

    -- Render (works in both D2D and draw API contexts via fill_rect/dtext)
    local x, y = 24, 10
    local line_h = 19
    local pad = 6
    local panel_h = pad * 2 + #info * line_h
    local panel_w = 400

    local f_title = get_font(16, true)   -- non-nil only in D2D context
    local f_body  = get_font(14, false)

    fill_rect(x - pad, y - pad, panel_w, panel_h, 0xCC0A0A1E)
    fill_rect(x - pad, y - pad, 3,       panel_h, 0xDD44FF88)

    for i, entry in ipairs(info) do
        local f = (i == 1) and f_title or (f_body or f_title)
        dtext(f, entry.text, x, y, entry.col or 0xFFE0E0E0)
        y = y + line_h
    end
end

-- HP gradient: green→yellow→red
local function hp_color(ratio)
    local r, g
    if ratio > 0.5 then
        r = math.floor((1 - ratio) * 2 * 255)
        g = 255
    else
        r = 255
        g = math.floor(ratio * 2 * 255)
    end
    return 0xFF000000 | (r << 16) | (g << 8)
end

-- Render one ESP label. col_main is the category color — used only for the
-- anchor dot so you know enemy/item/object. Line colors come from ln.col.
local function render_label(sx, sy, lines, col_main)
    if not sx or not sy then return end
    if sx < -400 or sx > R.sw + 400 then return end
    if sy < -400 or sy > R.sh + 400 then return end

    local font    = get_font(C.font_size, true)
    local font_sm = get_font(math.max(11, C.font_size - 4), false)

    local lh = C.font_size + 3
    local draw_y = sy - #lines * lh  -- stack lines above the anchor point

    for i, ln in ipairs(lines) do
        local f   = (i == 1) and font or (font_sm or font)
        local col = ln.col or 0xFFFFFFFF  -- each line carries its own color
        local tw  = #ln.text * C.font_size * 0.52
        dtext(f, ln.text, sx - tw * 0.5, draw_y, col)
        draw_y = draw_y + lh
    end

    -- Anchor dot: category color tells you enemy (red) / item (green) / object (yellow)
    fill_rect(sx - 2, sy - 2, 4, 4, col_main)
end

local COL_ENEMY    = 0xFFFF5555  -- Red    (anchor dot / category)
local COL_ITEM     = 0xFF55FF99  -- Green  (anchor dot / category)
local COL_OBJ      = 0xFFFFDD55  -- Yellow (anchor dot / category)
local COL_NAME     = 0xFFFFFFFF  -- White  — always the GO name line
local COL_GUID     = 0xFF44EEFF  -- Cyan   — always the GUID line (distinct from every category color)
local COL_TYPE     = 0xFF8899BB  -- Dim blue-gray — type path (secondary info)
local COL_DIST     = 0xFFAAAAAA  -- Light gray — distance
local COL_HP_GOOD  = 0xFF55FF88
local COL_HP_LOW   = 0xFFFFAA44
local COL_HP_CRIT  = 0xFFFF5555

local function build_label_lines(rec, is_enemy)
    local lines = {}

    -- GO name: always white — category is shown via the anchor dot color only
    lines[#lines + 1] = { text = rec.go_name or "?", col = COL_NAME }

    -- GUID: always cyan — unmistakably different from the white name and dim-blue type
    if C.show_guid and rec.guid and rec.guid ~= "" then
        lines[#lines + 1] = { text = rec.guid, col = COL_GUID }
    end

    -- Type path: dim blue-gray — tertiary info
    if C.show_type and rec.type_name and rec.type_name ~= "" then
        lines[#lines + 1] = { text = rec.type_name, col = COL_TYPE }
    end

    -- HP for enemies
    if is_enemy and C.show_hp and rec.hp then
        local mhp = rec.mhp or rec.hp
        local ratio = mhp > 0 and math.max(0, math.min(1, rec.hp / mhp)) or 0
        local hp_col = ratio > 0.5 and COL_HP_GOOD or (ratio > 0.25 and COL_HP_LOW or COL_HP_CRIT)
        lines[#lines + 1] = {
            text = string.format("HP %d / %d", math.floor(rec.hp), math.floor(mhp)),
            col  = hp_col,
        }
    end

    -- Distance
    if C.show_dist then
        lines[#lines + 1] = { text = string.format("%.1f m", rec.dist), col = COL_DIST }
    end

    return lines
end

local function render_esp_list(list, col_main, max_range, is_enemy, slots)
    -- slots: shared across all lists so labels from different categories don't collide.
    -- Each entry: {sx, top, bot} where top/bot are screen Y of the label block.
    slots = slots or {}

    for _, rec in ipairs(list) do
        if rec.dist > max_range then break end  -- list is sorted by dist
        if is_enemy and C.hide_dead and rec.dead then goto next end
        if rec.pos then
            _w2s_total = _w2s_total + 1
            local sp = world_to_screen(rec.pos)
            if sp then
                _w2s_ok = _w2s_ok + 1
                local lines = build_label_lines(rec, is_enemy)
                local lh = C.font_size + 3
                local label_h = #lines * lh
                local sx, sy = sp.x, sp.y

                -- Push this label upward if it would overlap a previously-rendered one
                for _, slot in ipairs(slots) do
                    if math.abs(slot.sx - sx) < 150 then
                        -- overlap horizontally — check vertical collision
                        local top = sy - label_h
                        if sy > slot.top and top < slot.bot then
                            sy = slot.top  -- place bottom of this label at top of existing
                        end
                    end
                end

                slots[#slots + 1] = { sx = sx, top = sy - label_h, bot = sy }
                render_label(sx, sy, lines, col_main)
            end
        end
        ::next::
    end
end

local function render_overlay()
    _w2s_ok    = 0
    _w2s_total = 0
    -- Shared slot pool so enemies, items, and objects all avoid each other.
    local slots = {}
    if C.show_enemy_esp then
        render_esp_list(R.enemies, COL_ENEMY, C.esp_range, true,  slots)
    end
    if C.show_item_esp then
        render_esp_list(R.items,   COL_ITEM,  C.esp_range, false, slots)
    end
    if C.show_obj_esp then
        render_esp_list(R.objects, COL_OBJ, C.obj_scan_range, false, slots)
    end
end

-- Register D2D callback (optional — RE3R may not support D2D)
-- _d2d_confirmed is set to true the FIRST time this callback fires.
-- If it never fires, the draw API fallback takes over automatically.
if has_d2d then
    d2d.register(function()
        _fonts = {}  -- D2D device reset — recreate fonts
    end, function()
        _d2d_confirmed = true
        _using_d2d     = true
        pcall(render_overlay)
        pcall(render_dev_overlay)
        _using_d2d = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Main Frame Loop
-- ═══════════════════════════════════════════════════════════════════════════

re.on_frame(function()
    R.tick = R.tick + 1

    -- EMV Engine frame hooks (if loaded)
    if _G.EMV then
        if _G.EMV.process_on_frame_calls then pcall(_G.EMV.process_on_frame_calls) end
        if _G.EMV.process_deferred_calls  then pcall(_G.EMV.process_deferred_calls) end
        if _G.EMV.ObjectCache             then pcall(_G.EMV.ObjectCache.sweep, _G.EMV.ObjectCache) end
        if _G.EMV.objects_background_update then pcall(_G.EMV.objects_background_update) end
    end

    -- Every 10 frames: player position (with camera fallback) + HP + camera rotation
    -- Must run BEFORE scanners so R.player_pos is current for distance calculations.
    if R.tick % 10 == 0 then
        pcall(update_player_pos)
        pcall(update_player_hp)
        pcall(update_camera_rotation)
    end

    -- Every 60 frames: screen size + game state (scene, rank, flags, scenarios)
    if R.tick % 60 == 1 then
        pcall(update_screen_size)
        pcall(scan_game_state)
        pcall(function() R.scenarios = scan_scenarios() end)
    end

    -- Scanners: skip entirely when paused so records stay stable for copying
    if not C.scan_paused then
        if R.tick % C.scan_interval == 0 then
            pcall(function() R.enemies = scan_enemies() end)
            pcall(function() R.items   = scan_items() end)
        end
        -- Object scan (slower — more expensive)
        if C.show_obj_esp and R.tick % (C.scan_interval * 2) == 5 then
            pcall(function() R.objects = scan_objects() end)
        end
    end

    -- Draw API rendering:
    --   • Always runs when D2D is absent
    --   • Also runs when D2D is installed but its callback hasn't fired yet
    --     (RE3R doesn't support D2D rendering — _d2d_confirmed stays false)
    if has_draw and not _d2d_confirmed then
        _using_d2d = false
        pcall(render_overlay)
        pcall(render_dev_overlay)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Viewer Window
-- ═══════════════════════════════════════════════════════════════════════════

local function colored_header(text, col)
    imgui.push_style_color(0, col or 0xFFFFDD88)
    imgui.separator()
    imgui.text(text)
    imgui.pop_style_color(1)
    imgui.spacing()
end

-- Copy button: clicking it copies value to the system clipboard
local function copy_btn(id, value)
    imgui.same_line()
    if imgui.button("Copy##" .. id) then
        imgui.set_clipboard_text(value or "")
    end
end

-- Labeled row with a colored tag, value text, and a copy button
local function info_row(tag, tag_col, value, key)
    imgui.text_colored(tag, tag_col or 0xFFE0E0E0)
    imgui.same_line()
    imgui.text(value or "")
    copy_btn(key, value)
end

-- Expandable entity record — all fields copyable via [C] buttons
local function record_row(label, rec, key)
    local dist_str = string.format("%.1f m", rec.dist)
    local header = string.format("[%s]  %s##%s", dist_str, rec.go_name or "?", key)
    if imgui.tree_node(header) then

        info_row("GO Name :", 0xFF88CCFF, rec.go_name or "",     "go_"   .. key)
        info_row("GUID    :", 0xFFFFCC44, rec.guid    or "",     "guid_" .. key)
        info_row("Type    :", 0xFFAABBCC, rec.type_name or "",   "type_" .. key)

        if rec.path and rec.path ~= "" then
            info_row("Path    :", 0xFFCCDDEE, rec.path,         "path_" .. key)
        end

        if rec.pos then
            local pos_str = string.format("%.4f, %.4f, %.4f",
                rec.pos.x, rec.pos.y, rec.pos.z)
            info_row("Pos     :", 0xFFE0E0E0, pos_str,          "pos_"  .. key)
        end

        if rec.hp then
            local hp_str = string.format("%d / %d",
                math.floor(rec.hp), math.floor(rec.mhp or rec.hp))
            info_row("HP      :", 0xFF44FF88, hp_str,           "hp_"   .. key)
        end

        imgui.spacing()
        imgui.tree_pop()
    end
end

-- ── Enemy Tab ──────────────────────────────────────────────────────────────
local function ui_enemies()
    local ch
    ch, C.show_enemy_esp = imgui.checkbox("Show Enemy ESP Overlay", C.show_enemy_esp)

    colored_header(string.format("Enemies within %.0fm  (%d total scanned)", C.esp_range, #R.enemies))

    local shown = 0
    for i, e in ipairs(R.enemies) do
        if e.dist > C.esp_range then break end
        if C.hide_dead and e.dead then goto skip_e end
        record_row("e", e, "e" .. i)
        shown = shown + 1
        ::skip_e::
    end
    if shown == 0 then
        imgui.text_colored("  (none in range)", 0xFF888888)
    end
end

-- ── Item Tab ───────────────────────────────────────────────────────────────
local function ui_items()
    local ch
    ch, C.show_item_esp = imgui.checkbox("Show Item ESP Overlay", C.show_item_esp)

    colored_header(string.format("Items within %.0fm  (%d total scanned)", C.esp_range, #R.items))

    local shown = 0
    for i, itm in ipairs(R.items) do
        if itm.dist > C.esp_range then break end
        record_row("i", itm, "i" .. i)
        shown = shown + 1
    end
    if shown == 0 then
        imgui.text_colored("  (none in range)", 0xFF888888)
    end
end

-- ── Objects Tab ────────────────────────────────────────────────────────────
local function ui_objects()
    local ch
    ch, C.show_obj_esp = imgui.checkbox("Show Object ESP Overlay", C.show_obj_esp)

    -- EMV Objects tab when available
    if _G.EMV and EMV.render_objects_tab then
        imgui.spacing()
        imgui.separator()
        imgui.text_colored("  EMV Engine — Scene Browser", 0xFFAADDFF)
        imgui.spacing()
        pcall(EMV.render_objects_tab)
        return
    end

    -- Fallback: plain list of nearby objects
    colored_header(string.format("Objects within %.0fm  (%d scanned)", C.obj_scan_range, #R.objects))

    local shown = 0
    for i, obj in ipairs(R.objects) do
        if obj.dist > C.obj_scan_range then break end
        if shown >= 100 then
            imgui.text_colored("  ... more objects not shown (raise scan range or increase limit)", 0xFF888888)
            break
        end
        record_row("o", obj, "o" .. i)
        shown = shown + 1
    end
    if shown == 0 then
        imgui.text_colored("  (none in range — toggle Show Object ESP or increase obj_scan_range)", 0xFF888888)
    end
end

-- ── Inspector Tab (EMV) ────────────────────────────────────────────────────
local function ui_inspector()
    if _G.EMV and EMV.render_method_inspector then
        pcall(EMV.render_method_inspector)
    elseif _G.EMV and EMV.render_viewer_tab then
        pcall(EMV.render_viewer_tab)
    else
        imgui.text_colored("EMV Engine not loaded (Inspector unavailable).", 0xFFFF8888)
    end
end

-- ── Settings Tab ───────────────────────────────────────────────────────────
local function ui_settings()
    local ch

    colored_header("Dev Overlay")
    ch, C.show_dev_overlay = imgui.checkbox("Show Dev Overlay (top-left)", C.show_dev_overlay)
    imgui.spacing()
    -- Live state display inside settings
    if C.show_dev_overlay then
        local pos = R.player_pos
        if pos then
            imgui.text_colored(string.format("  Pos:  %.2f, %.2f, %.2f", pos.x, pos.y, pos.z), 0xFF88CCFF)
        end
        local map_id = R.dev.map_id ~= nil and tostring(R.dev.map_id) or "?"
        local area_id = R.dev.area_id ~= nil and tostring(R.dev.area_id) or "?"
        imgui.text_colored(string.format("  MapID: %s   AreaID: %s", map_id, area_id), 0xFFCCCCCC)
        imgui.text_colored("  Scene:  " .. (R.dev.scene ~= "" and R.dev.scene or "(none)"), 0xFFFFCC44)
        if R.dev.rank ~= nil then
            imgui.text_colored("  Rank:   " .. tostring(R.dev.rank), 0xFF88CCFF)
        end
        if R.dev.player_name ~= "" then
            imgui.text_colored("  Player: " .. R.dev.player_name, 0xFF44FF88)
        end
        if R.dev.player_state ~= "" then
            imgui.text_colored("  State:  " .. R.dev.player_state, 0xFFAABBCC)
        end
    end

    colored_header("Scenario Controllers")
    -- Singleton status
    local ssm_col = _scn_debug.ssm_found and 0xFF44FF88 or 0xFFFF5555
    imgui.text_colored("  SSM singleton: " .. (_scn_debug.ssm_found and "found" or "NOT found"), ssm_col)

    if #R.scenarios > 0 then
        for i, s in ipairs(R.scenarios) do
            imgui.text_colored(string.format("  %s (%d)", s.name, s.no), 0xFFFFCC44)
            imgui.same_line()
            if imgui.button("Copy##sc" .. i) then imgui.set_clipboard_text(s.name) end
        end
        if _scn_debug.method_used ~= "" then
            imgui.text_colored("  via: " .. _scn_debug.method_used, 0xFF888888)
        end
    else
        imgui.text_colored("  (no value read yet)", 0xFF888888)
        if _scn_debug.method_used ~= "" then
            imgui.text_colored("  tried: " .. _scn_debug.method_used, 0xFF888888)
        end
    end

    -- Method dump — only shown when singleton is accessible
    if _scn_debug.ssm_found and #_scn_debug.methods > 0 then
        imgui.spacing()
        imgui.text_colored("  SSM methods:", 0xFF888888)
        for _, mn in ipairs(_scn_debug.methods) do
            imgui.text_colored("    " .. mn, 0xFF666666)
            imgui.same_line()
            if imgui.small_button("C##m_" .. mn) then imgui.set_clipboard_text(mn) end
        end
    end

    colored_header("ESP Distances")
    ch, C.esp_range = imgui.drag_float("Enemy/Item Range (m)##er", C.esp_range, 0.5, 5, 200, "%.1f m")
    ch, C.obj_scan_range = imgui.drag_float("Object Range (m)##or", C.obj_scan_range, 0.5, 5, 100, "%.1f m")
    ch, C.obj_max_results = imgui.drag_int("Object Max Results##om", C.obj_max_results, 10, 10, 500)

    colored_header("Label Content")
    ch, C.show_guid    = imgui.checkbox("Show GUID", C.show_guid)
    ch, C.show_go_name = imgui.checkbox("Show GO Name", C.show_go_name)
    ch, C.show_type    = imgui.checkbox("Show Component Type", C.show_type)
    ch, C.show_hp      = imgui.checkbox("Show HP (enemies)", C.show_hp)
    ch, C.show_dist    = imgui.checkbox("Show Distance", C.show_dist)
    ch, C.hide_dead    = imgui.checkbox("Hide Dead Enemies", C.hide_dead)

    colored_header("Font")
    ch, C.font_size = imgui.drag_int("Font Size##fs", C.font_size, 1, 8, 32)
    if ch then _fonts = {} end  -- invalidate font cache

    colored_header("Scanner")
    ch, C.scan_interval = imgui.drag_int("Scan Interval (frames)##si", C.scan_interval, 1, 5, 300)

    imgui.spacing()
    imgui.separator()
    if imgui.button("Save Settings") then
        cfg_save()
        imgui.text_colored("Saved!", 0xFF44FF88)
    end
end

-- ── Tab definitions ────────────────────────────────────────────────────────
local TABS = {
    { name = "Enemies",   fn = ui_enemies  },
    { name = "Items",     fn = ui_items    },
    { name = "Objects",   fn = ui_objects  },
    { name = "Inspector", fn = ui_inspector },
    { name = "Settings",  fn = ui_settings },
}

re.on_draw_ui(function()
    local ch
    ch, C.ui_visible = imgui.checkbox(TITLE, C.ui_visible)
    if not C.ui_visible then return end

    if imgui.begin_window(TITLE .. "###biorand_re3r_w", true, 0) then

        -- Status line + pause toggle
        local status_col = C.scan_paused and 0xFFFFAA44 or 0xFF88DDFF
        imgui.text_colored(
            string.format("  Enemies: %d   Items: %d   Objects: %d",
                #R.enemies, #R.items, #R.objects),
            status_col)
        imgui.same_line()
        local pause_label = C.scan_paused and "  [RESUME SCAN]  " or "  [PAUSE SCAN]  "
        local pause_col   = C.scan_paused and 0xFFFFAA44 or 0xFF44AA44
        imgui.push_style_color(0,  pause_col)
        imgui.push_style_color(21, 0xFF333344)
        if imgui.button(pause_label) then
            C.scan_paused = not C.scan_paused
        end
        imgui.pop_style_color(2)
        imgui.separator()

        -- Tab bar
        for i, tab in ipairs(TABS) do
            if i > 1 then imgui.same_line() end
            local active = (C.ui_tab == i)
            if active then
                imgui.push_style_color(21, 0xFF44FF88)
                imgui.push_style_color(22, 0xFF44FF88)
                imgui.push_style_color(23, 0xFF44FF88)
                imgui.push_style_color(0,  0xFF1A1A2E)
            else
                imgui.push_style_color(21, 0xFF333344)
                imgui.push_style_color(22, 0xFF444466)
                imgui.push_style_color(23, 0xFF555577)
                imgui.push_style_color(0,  0xFFAAAAAA)
            end
            if imgui.button(tab.name .. "##t" .. i) then C.ui_tab = i end
            imgui.pop_style_color(4)
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- Active tab content
        local sel = TABS[C.ui_tab or 1]
        if sel and sel.fn then pcall(sel.fn) end

        imgui.end_window()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EMV Engine Loader
-- ═══════════════════════════════════════════════════════════════════════════

pcall(function()
    local emv_path = get_script_dir() .. "..\\emv_engine\\init.lua"
    local fn = loadfile(emv_path)
    if fn then
        pcall(fn, _G)
        log.info("[RE3R Trainer] EMV Engine loaded from " .. emv_path)
    else
        log.warn("[RE3R Trainer] EMV Engine not found at " .. emv_path)
    end
end)

-- Make EMV available as a local after load
local EMV = _G.EMV or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

re.on_script_reset(function()
    R.enemies      = {}
    R.items        = {}
    R.objects      = {}
    R.scenarios    = {}
    R.player_pos   = nil
    R.player_hp    = 0
    R.player_mhp   = 0
    R.dev_rotation = nil
    R.dev          = { scene = "", rank = nil, playtime = nil, player_name = "", player_state = "" }
    _fonts         = {}
    _type_cache    = {}
end)

log.info("[RE3R Trainer] " .. TITLE .. " loaded.")
