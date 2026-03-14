--[[
    Requiem Trainer v5.0 — Modular
    Resident Evil 9 / Biohazard Requiem — REFramework
    Author: namsku

    Module layout:
      requiem_trainer.lua          — Config, state, utilities, module loader, frame loop, UI shell
      requiem_trainer/features.lua — Gameplay functions (God mode, speed, arsenal, enemies, saves, etc.)
      requiem_trainer/hooks.lua    — All SDK hook installations
      requiem_trainer/rendering.lua — D2D overlays (damage numbers, ESP, panel, HUD, toasts)
      requiem_trainer/ui.lua       — ImGui tab functions and hotkey binder
]]

local TITLE   = "Requiem Trainer v5.0 by namsku"
local CFG     = "requiem_trainer_v3.json"

-- ═══════════════════════════════════════════════════════════════════════════
-- Config / Persistence
-- ═══════════════════════════════════════════════════════════════════════════

local C = {
    god_mode       = false,
    hp_lock        = false,
    hp_lock_val    = 1000,
    player_speed_on = false,
    player_speed   = 1.3,
    walk_speed     = 1.3,
    run_speed      = 1.3,
    ohk            = false,
    no_recoil      = false,
    no_reload      = false,
    inf_grenades   = false,
    inf_ammo       = false,
    inf_melee      = false,
    highlight      = false,
    noclip         = false,
    enemy_panel    = false,
    enemy_esp      = false,
    esp_range      = 30.0,
    motion_freeze  = false,
    game_speed_on  = false,
    game_speed     = 1.0,
    skip_cutscenes = false,
    panel_x        = 24,
    panel_y        = 180,
    panel_rows     = 6,
    panel_font     = 16,
    panel_w        = 480,
    panel_bar_w    = 150,
    panel_bar_h    = 8,
    show_rank      = true,
    show_da        = true,
    show_pct       = false,
    show_bars      = true,
    dist_color     = false,
    hide_dead      = true,
    filter_full_hp = false,
    show_timer     = true,
    esp_bar_w      = 200,
    esp_bar_h      = 18,
    esp_font       = 24,
    overlay_font   = "Consolas",
    esp_alpha      = true,
    esp_alpha_start = 30.0,
    esp_min_alpha  = 0.20,
    esp_scale      = true,
    esp_min_scale  = 0.55,
    esp_world_y    = 1.9,
    esp_screen_y   = 24,
    esp_in_sight   = false,
    esp_bg_plates  = true,   -- background pills behind ESP text
    ui_dpi_scale   = true,   -- scale UI widgets for DPI
    freeze_x       = false,
    freeze_y       = false,
    freeze_z       = false,
    show_damage    = false,
    dmg_crosshair  = true,
    dmg_font_size  = 28,
    dmg_shadow     = 2,
    dmg_duration   = 1.2,
    dmg_speed      = 80,
    dmg_color_on   = true,
    dmg_thresh_big = 200,
    dmg_thresh_huge = 500,
    dmg_combine    = false,
    -- Hotkeys (virtual key codes, 0 = disabled)
    hk_god         = 0x70,  -- F1
    hk_speed       = 0x71,  -- F2
    hk_overlay     = 0x72,  -- F3
    hk_freeze      = 0x73,  -- F4
    hk_gamespeed   = 0x74,  -- F5
    hk_save        = 0x76,  -- F7
    hk_load        = 0x77,  -- F8
    hk_skip        = 0,     -- Auto-Skip Cutscenes (unbound)
    -- Overlay
    show_igt       = false,
    show_area      = false,
    death_warp     = false,
    show_hud       = true,
    -- Phase 2 features
    auto_parry     = false,
    stealth        = false,
    fov_enabled    = false,
    fov_fps_def    = 0.0,
    fov_fps_ads    = 0.0,
    fov_tps_def    = 0.0,
    fov_tps_ads    = 0.0,
    free_craft     = false,
    rapid_fire     = false,
    -- Merged features
    inf_injector       = false,
    headshot_boost_on  = false,
    headshot_mult      = 2.0,
    map_reveal         = false,
    disable_film_grain = false,
    super_accuracy     = false,
    highlight_items    = false,
    unlock_recipes     = false,
    unlimited_saves    = false,
    remote_storage     = false,
    hk_remote_storage  = 0,
    enemy_speed_on     = false,
    enemy_speed        = 1.0,
    -- Dev
    show_dev_overlay   = true,
    show_spawns        = false,
    spawn_range        = 100,
    spawn_style        = 1,    -- 1=Cylinder, 2=Diamond, 3=Beacon, 4=Minimal
    obj_overlay_style  = 5,    -- 1=Cylinder, 2=Diamond, 3=Beacon, 4=Minimal, 5=Text
    obj_enabled        = false,
    obj_show_overlay   = false,
    obj_max_distance   = 15,
    obj_sort_by_dist   = true,
    obj_filter_idx     = 1,
    obj_hide_static    = true,
    obj_scan_interval  = 2.0,
    -- NoClip
    noclip             = false,
    noclip_speed       = 7.5,
    noclip_vert_speed  = 7.5,
    noclip_boost       = 3.0,
    noclip_slow        = 0.35,
    noclip_yaw_offset  = 180.0,
    noclip_anti_death  = true,
    noclip_no_fall     = true,
    noclip_sync_rotation = true,
    hk_noclip          = 0x71,  -- F2
    -- Save slot bindings
    quick_save_slot    = 0,      -- slot offset for Quick Save hotkey
    quick_load_slot    = 0,      -- slot offset for Quick Load hotkey
    slot_bindings      = {},     -- per-slot hotkeys: { ["3_0"] = { save = vk, load = vk }, ... }
    -- Item Indicator
    show_items         = false,
    show_item_core     = true,
    show_item_spawner  = true,
    show_key_items     = true,
    show_box_items     = true,
    show_raccoon       = true,
    item_distance      = 50.0,
    item_scan_interval = 1.0,
    color_item_normal  = 0xFFFFFFFF,
    color_item_key     = 0xFF0000FF,
    color_item_box     = 0xFF808080,
    color_item_raccoon = 0xFFE99237,
    color_item_core    = 0xFF00DDFF,
    color_item_spawner = 0xFFFF44FF,
    item_font_size     = 20,
    -- GUID overlay display
    show_guid_titles   = false,
    -- Gravity Gun (config keys auto-merged by module on init)
    gravity_gun_enabled = false,
    -- Phase 3: Competitor gap features
    no_sway            = false,
    inf_durability     = false,
    cp_value           = 9999999,
    playtime_freeze    = false,
    playtime_hours     = 0,
    playtime_minutes   = 0,
    playtime_seconds   = 0,
    camera_pan_enabled = false,
    camera_pan_x       = 0.0,
    camera_pan_y       = 0.0,
    camera_offset_z    = 0.0,
    -- UI state
    ui_tab             = 1,
}

-- Key name lookup for display
local VK_NAMES = {
    [0x08]="Bksp", [0x09]="Tab", [0x0D]="Enter", [0x10]="Shift", [0x11]="Ctrl", [0x12]="Alt",
    [0x1B]="Esc", [0x20]="Space", [0x21]="PgUp", [0x22]="PgDn", [0x23]="End", [0x24]="Home",
    [0x25]="Left", [0x26]="Up", [0x27]="Right", [0x28]="Down",
    [0x2D]="Ins", [0x2E]="Del",
    [0x60]="Num0",[0x61]="Num1",[0x62]="Num2",[0x63]="Num3",[0x64]="Num4",
    [0x65]="Num5",[0x66]="Num6",[0x67]="Num7",[0x68]="Num8",[0x69]="Num9",
    [0x6A]="Num*",[0x6B]="Num+",[0x6D]="Num-",[0x6E]="Num.",[0x6F]="Num/",
    [0x70]="F1",[0x71]="F2",[0x72]="F3",[0x73]="F4",[0x74]="F5",[0x75]="F6",
    [0x76]="F7",[0x77]="F8",[0x78]="F9",[0x79]="F10",[0x7A]="F11",[0x7B]="F12",
    [0xBA]=";",[0xBB]="=",[0xBC]=",",[0xBD]="-",[0xBE]=".",[0xBF]="/",[0xC0]="`",
    [0xDB]="[",[0xDC]="\\",[0xDD]="]",[0xDE]="'",
}
for i = 0x30, 0x39 do VK_NAMES[i] = string.char(i) end
for i = 0x41, 0x5A do VK_NAMES[i] = string.char(i) end

local function vk_name(vk)
    if not vk or vk == 0 then return "None" end
    return VK_NAMES[vk] or ("0x%02X"):format(vk)
end

local PERSIST_KEYS = {}
for k, _ in pairs(C) do PERSIST_KEYS[#PERSIST_KEYS + 1] = k end

local cfg_dirty = false
local STICKY_CFG = "requiem_trainer_sticky.cfg"

-- Sticky backup: plain text key=value for booleans/numbers (survives json failures)
local function cfg_save_sticky()
    local ok, file = pcall(io.open, STICKY_CFG, "w")
    if not ok or not file then return end
    for _, k in ipairs(PERSIST_KEYS) do
        local v = C[k]
        local t = type(v)
        if t == "boolean" then
            pcall(function() file:write(k .. "=" .. (v and "1" or "0") .. "\n") end)
        elseif t == "number" then
            pcall(function() file:write(k .. "=" .. tostring(v) .. "\n") end)
        elseif t == "table" and json then
            -- Serialize tables as JSON strings prefixed with T:
            pcall(function()
                local encoded = json.dump_string(v)
                if encoded then file:write(k .. "=T:" .. encoded .. "\n") end
            end)
        end
    end
    pcall(function() file:close() end)
end

local function cfg_load_sticky()
    local ok, file = pcall(io.open, STICKY_CFG, "r")
    if not ok or not file then return false end
    local loaded = false
    for line in file:lines() do
        local key, raw = line:match("^([%w_]+)=(.+)$")
        if key and raw and C[key] ~= nil then
            local t = type(C[key])
            if t == "boolean" then
                C[key] = (raw == "1" or raw == "true")
                loaded = true
            elseif t == "number" then
                local n = tonumber(raw)
                if n then C[key] = n; loaded = true end
            elseif t == "table" and json and raw:sub(1, 2) == "T:" then
                -- Deserialize JSON-encoded table values
                pcall(function()
                    local decoded = json.load_string(raw:sub(3))
                    if type(decoded) == "table" then C[key] = decoded; loaded = true end
                end)
            end
        end
    end
    pcall(function() file:close() end)
    return loaded
end

local cfg_last_save_err = nil

local function cfg_save()
    -- Primary: JSON
    if json then
        local ok, err = pcall(json.dump_file, CFG, C)
        if not ok then
            cfg_last_save_err = tostring(err)
            if log then log.warn("[Trainer] cfg_save JSON failed: " .. cfg_last_save_err) end
        else
            cfg_last_save_err = nil
        end
    end
    -- Backup: sticky text file (always attempt)
    pcall(cfg_save_sticky)
    cfg_dirty = false
    -- Sync error state to shared T table for UI display
    if _G.__REQUIEM_T then _G.__REQUIEM_T.cfg_last_save_err = cfg_last_save_err end
end

local function cfg_flush()
    if not cfg_dirty then return end
    cfg_save()
end

local function cfg_load()
    local loaded_json = false
    -- Primary: JSON
    if json then
        local ok, d = pcall(json.load_file, CFG)
        if ok and type(d) == "table" then
            for _, k in ipairs(PERSIST_KEYS) do
                if d[k] ~= nil and type(d[k]) == type(C[k]) then C[k] = d[k] end
            end
            loaded_json = true
            if log then log.info("[Trainer] Settings loaded from JSON") end
        end
    end
    -- Fallback: sticky text file
    if not loaded_json then
        local sticky_ok = cfg_load_sticky()
        if sticky_ok and log then log.info("[Trainer] Settings loaded from sticky backup") end
    end
end
pcall(cfg_load)

-- ═══════════════════════════════════════════════════════════════════════════
-- Runtime State (NOT persisted)
-- ═══════════════════════════════════════════════════════════════════════════

local R = {
    tick         = 0,
    hooks_ok     = false,
    session_start = os.clock(),
    hp_ref       = nil,
    bookmark     = nil,
    frozen_pos   = nil,
    enemies      = {},
    total_enemies = 0,
    orig_speed   = nil,
    speed_factor = 1.0,
    speed_reset_frames = 0,
    save_slots   = {},
    save_time    = nil,
    items        = {},
    rank_data    = nil,
    death_pos    = nil,
    area_name    = "",
    igt_text     = "",
    load_method  = nil,
    dev_scene    = "",
    dev_rotation = nil,
    -- Item indicator
    item_indicators = {},       -- addr -> {name, pos, category, is_key, update_time}
    item_last_scan  = 0,
    item_detail_cache = {},     -- item_id -> {name, category}
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Toast Notification System
-- ═══════════════════════════════════════════════════════════════════════════

local toast_list = {}

local function toast(msg, col)
    toast_list[#toast_list + 1] = {
        text = msg, color = col or 0xFFFFFFFF,
        time = os.clock(), duration = 2.5,
    }
    while #toast_list > 5 do table.remove(toast_list, 1) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Singleton Cache (uses ObjectCache when available, raw table fallback)
-- ═══════════════════════════════════════════════════════════════════════════

local _s = {}                   -- raw fallback table (pre-EMV)
local TrainerCache = nil        -- ObjectCache instance, created after EMV loads
local _ObjectCache_class = nil  -- ObjectCache class ref for lazy init

--- Initialise TrainerCache from the ObjectCache class (called once after EMV load).
local function init_trainer_cache(OC_class)
    if TrainerCache then return end
    if not OC_class then return end
    _ObjectCache_class = OC_class
    TrainerCache = OC_class:new({name = "trainer", max_size = 600, default_ttl = 120})
    -- Migrate any entries already in the raw table
    for k, v in pairs(_s) do
        TrainerCache:set(k, v, 120)
    end
    _s = {}  -- raw table no longer needed
    if log then log.info("[Trainer] TrainerCache initialised (ObjectCache)") end
end

local function mgr(name)
    if TrainerCache then
        local o = TrainerCache:get(name)
        if o then return o end
        local ok, inst = pcall(sdk.get_managed_singleton, name)
        if ok and inst then TrainerCache:set(name, inst, 120); return inst end
        return nil
    end
    -- Fallback: raw table (before EMV loads)
    local o = _s[name]
    if o then if pcall(o.get_type_definition, o) then return o end; _s[name] = nil end
    local ok, inst = pcall(sdk.get_managed_singleton, name)
    if ok and inst then _s[name] = inst; return inst end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Accessors
-- ═══════════════════════════════════════════════════════════════════════════

local function pctx()
    local m = mgr("app.CharacterManager")
    if not m then return nil end
    local ok, c = pcall(m.call, m, "getPlayerContextRef")
    return ok and c or nil
end

local function php()
    local c = pctx()
    if not c then return nil end
    local ok, h = pcall(c.call, c, "get_HitPoint")
    return ok and h or nil
end

local function pxf()
    local c = pctx()
    if not c then return nil end
    local ok, go = pcall(c.call, c, "get_GameObject")
    if not ok or not go then return nil end
    local ok2, xf = pcall(go.call, go, "get_Transform")
    return ok2 and xf or nil
end

-- Cached SDK lookups (avoid per-frame sdk.find_type_definition)
local _sm_singleton = sdk.get_native_singleton("via.SceneManager")
local _sm_td = sdk.find_type_definition("via.SceneManager")

local function ppos()
    local xf = pxf()
    if not xf then return nil end
    local ok, p = pcall(xf.call, xf, "get_Position")
    if ok and p then
        -- Reuse R._pp to avoid GC churn (5-10 calls/frame)
        local pp = R._pp
        if not pp then pp = {x=0,y=0,z=0}; R._pp = pp end
        pp.x, pp.y, pp.z = p.x, p.y, p.z
        return pp
    end
    return nil
end

--- Get current scene (delegates to EMV when available, fallback to raw SDK).
--- @return userdata|nil  via.Scene
local function get_scene()
    if _G.EMV and _G.EMV.get_scene then return _G.EMV.get_scene() end
    local scene = nil
    pcall(function()
        scene = sdk.call_native_func(_sm_singleton, _sm_td, "get_CurrentScene")
    end)
    return scene
end

local function hp_vals()
    local h = php()
    if not h then return nil, nil end
    local c, m
    pcall(function() c = h:call("get_CurrentHitPoint") end)
    pcall(function() m = h:call("get_CurrentMaximumHitPoint") end)
    return c, m
end

--- Get the enemy context list and count from CharacterManager.
--- @return userdata|nil list  The enemy context list
--- @return number count       Enemy count (0 if unavailable)
local function get_enemy_list()
    local m = mgr("app.CharacterManager")
    if not m then return nil, 0 end
    local ok, el = pcall(m.call, m, "get_EnemyContextList")
    if not ok or not el then return nil, 0 end
    local ok2, n = pcall(el.call, el, "get_Count")
    if not ok2 or not n or n <= 0 then return el, 0 end
    return el, n
end

--- Euclidean distance between two {x,y,z} tables (shared helper — used by 9+ sites).
local function dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Type Resolution (KindID)
-- ═══════════════════════════════════════════════════════════════════════════

local function get_kind_name(ctx)
    if not ctx then return nil end
    local ok, kind_obj = pcall(ctx.call, ctx, "get_KindID")
    if not ok or not kind_obj then return nil end
    local name = nil
    pcall(function()
        local s = kind_obj:ToString()
        if s and s ~= "" then name = tostring(s) end
    end)
    if name then return name end
    local val = nil
    pcall(function() val = tonumber(kind_obj:asValue()) end)
    if not val then pcall(function() val = tonumber(kind_obj) end) end
    if val then return string.format("Enemy_%d", val) end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Localized Character Names
-- ═══════════════════════════════════════════════════════════════════════════

local _msg_guid_method = nil
local _msg_get_method = nil
local _localized_cache = {}

pcall(function()
    local td = sdk.find_type_definition("via.gui.message")
    if td then
        _msg_guid_method = td:get_method("getGuidByName(System.String)")
        _msg_get_method  = td:get_method("get(System.Guid)")
    end
end)

local function get_localized_name(kind_obj)
    if not kind_obj then return nil end
    if not _msg_guid_method or not _msg_get_method then return nil end
    local val = nil
    pcall(function() val = tonumber(kind_obj:asValue()) end)
    if not val then return nil end
    if _localized_cache[val] ~= nil then
        return _localized_cache[val] or nil
    end
    local result = nil
    pcall(function()
        local cm = mgr("app.CharacterManager")
        if not cm then return end
        local config = cm:call("getCharacterConfiguration", kind_obj)
        if not config then return end
        local msg_config = config:call("get_CharacterMessageConfiguration")
        if not msg_config then return end
        local speaker_id = msg_config:call("get_SpeakerID")
        if not speaker_id then return end
        local speaker_str = tostring(speaker_id)
        if speaker_str == "" then return end
        local msg_name = speaker_str
        if not msg_name:find("CharaName_", 1, true) then
            msg_name = "CharaName_" .. msg_name
        end
        local guid = _msg_guid_method:call(nil, msg_name)
        if not guid then return end
        local text = _msg_get_method:call(nil, guid)
        if text then result = tostring(text) end
    end)
    _localized_cache[val] = result or false
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Rank / Dynamic Adjustment Data
-- ═══════════════════════════════════════════════════════════════════════════

local function fetch_rank_data()
    local data = {rank = nil, points = nil, e_dmg = nil, e_wince = nil, e_move = nil, p_dmg = nil,
                  ch_e_dmg = nil, ch_e_wince = nil, ch_e_move = nil, ch_p_dmg = nil, ch_r_point = nil}
    pcall(function()
        local rm = mgr("app.RankManager")
        if not rm then return end
        pcall(function() data.rank    = rm:call("getCurrentRank") end)
        pcall(function() data.e_dmg   = rm:call("getEnemyDamageFactor") end)
        pcall(function() data.e_wince = rm:call("getEnemyWinceFactor") end)
        pcall(function() data.e_move  = rm:call("getEnemyMoveFactor") end)
        pcall(function() data.p_dmg   = rm:call("getPlayerDamageFactor") end)
        pcall(function()
            local profile = rm:get_field("<ActiveRankProfile>k__BackingField")
            if profile then data.points = profile:call("get_RankPoints") end
        end)
        pcall(function()
            local cs = rm:get_field("<RankChapterSettings>k__BackingField")
            if cs and data.rank then
                pcall(function() data.ch_e_dmg   = cs:call("getEnemyDamageFactor", data.rank) end)
                pcall(function() data.ch_e_wince = cs:call("getEnemyWinceFactor", data.rank) end)
                pcall(function() data.ch_e_move  = cs:call("getEnemyMoveFactor", data.rank) end)
                pcall(function() data.ch_p_dmg   = cs:call("getPlayerDamageFactor", data.rank) end)
                pcall(function() data.ch_r_point = cs:call("getRankPointFactor", data.rank) end)
            end
        end)
    end)
    return data
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player name via character context
-- ═══════════════════════════════════════════════════════════════════════════

local function player_name()
    local c = pctx()
    if not c then return "Player" end
    local loc_name = nil
    pcall(function()
        local ok, kind_obj = pcall(c.call, c, "get_KindID")
        if ok and kind_obj then loc_name = get_localized_name(kind_obj) end
    end)
    if loc_name then return loc_name end
    local kn = get_kind_name(c)
    if kn then return kn end
    return "Player"
end

local function player_hp_level()
    local h = php()
    if not h then return nil, nil end
    local lv, mlv = nil, nil
    pcall(function() lv  = h:call("get_CurrentHitPointLevel") end)
    pcall(function() mlv = h:call("get_MaxHitPointLevel") end)
    return lv, mlv
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Friendly Enemy Names
-- ═══════════════════════════════════════════════════════════════════════════

local ENEMY_NAMES = {
    cp_B000 = "Zombie",
    cp_B001 = "Nurse",
    cp_B002 = "Chief",
    cp_B003 = "Singers",
    cp_B007 = "Lighter",
    cp_B050 = "Ghoul",
    cp_B051 = "Chainsaw Man",
    cp_B052 = "Blister",
    cp_B053 = "Harpon",
    cp_B060 = "Zombie",
    cp_B070 = "Zombie",
    cp_B004 = "Cleaner",
    cp_B006 = "Silent",
    cp_B600 = "Licker",
    cp_B700 = "Titan Spinner",
    cp_C100 = "Chunk",
    cp_C600 = "Elite Guards",
    cp_6010 = "The Commander",
    cp_C700 = "Spider",
    cp_B800 = "The Girl",
    cp_B801 = "The Girl",
    cp_B802 = "The Girl",
    cp_B803 = "The Girl",
    cp_B804 = "The Girl",
    cp_B805 = "The Girl",
}

local function friendly_name(raw)
    if not raw then return "Enemy" end
    return ENEMY_NAMES[raw] or raw
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Scanner
-- ═══════════════════════════════════════════════════════════════════════════

-- Shared helper: extract the real GUID from a GameObject
-- ToString() returns "GameObject[name@xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx]"
local function extract_go_guid(go)
    if not go then return nil end
    local guid = nil
    pcall(function()
        local s = go:call("ToString()")
        if s then
            guid = tostring(s):match("@([%x%-]+)%]$")
        end
    end)
    return guid
end

-- Extract the folder path of a GameObject (stable, human-readable identifier)
local function extract_go_addr(go)
    if not go then return nil end
    local path_id = nil
    pcall(function()
        local folder = go:call("get_Folder")
        if folder then
            local ts = folder:call("ToString()")
            if ts then
                -- ToString() returns "Folder[path]"
                local p = tostring(ts):match("%[(.+)%]$")
                if p then path_id = p; return end
            end
            local fpath = folder:call("get_Path")
            local name = go:call("get_Name")
            if fpath and fpath ~= "" and name then
                path_id = fpath .. "/" .. name
            elseif name then
                path_id = name
            end
        else
            local name = go:call("get_Name")
            if name then path_id = tostring(name) end
        end
    end)
    return path_id
end

-- Extract a GUID field from a component (e.g. _SpawnID on spawn param components)
local function extract_field_guid(obj, field_name)
    if not obj then return nil end
    local result = nil
    pcall(function()
        local raw = obj:get_field(field_name)
        if not raw then return end
        local ok, s = pcall(raw.call, raw, "ToString()")
        if ok and s then result = tostring(s) end
    end)
    return result
end

local function scan_enemies()
    local out = {}
    local el, n = get_enemy_list()
    if not el or n <= 0 then R.total_enemies = 0; return out end

    R.total_enemies = n
    local pp = ppos()
    for i = 0, n - 1 do
        pcall(function()
            local ctx = el:call("get_Item", i)
            if not ctx then return end
            local hp_obj = ctx:call("get_HitPoint")
            if not hp_obj then return end
            local is_dead = false
            pcall(function() is_dead = hp_obj:call("get_IsDead") end)
            local cur = hp_obj:call("get_CurrentHitPoint") or 0
            local mx  = hp_obj:call("get_CurrentMaximumHitPoint") or 0
            local lv, mlv = nil, nil
            pcall(function() lv  = hp_obj:call("get_CurrentHitPointLevel") end)
            pcall(function() mlv = hp_obj:call("get_MaxHitPointLevel") end)
            local kind = friendly_name(get_kind_name(ctx))
            local pos = nil
            pcall(function()
                local wp = ctx:call("get_Position")
                if wp then pos = {x = wp.x, y = wp.y, z = wp.z} end
            end)
            if not pos then
                pcall(function()
                    local go = ctx:call("get_GameObject")
                    if go then
                        local xf = go:call("get_Transform")
                        if xf then
                            local p = xf:call("get_Position")
                            if p then pos = {x = p.x, y = p.y, z = p.z} end
                        end
                    end
                end)
            end
            local dist = 0
            if pp and pos then dist = dist3(pos, pp) end
            if not pos then return end
            if cur <= 0 and mx <= 0 then return end

            -- Extract path, address, real name, type, and spawn origin from the GameObject
            local go_guid = nil
            local go_addr = nil
            local go_name = nil
            local enemy_type = nil
            local spawn_id = nil
            pcall(function()
                local go = ctx:call("get_GameObject")
                if not go then return end
                -- Path from folder + name (stable across loads)
                go_guid = extract_go_guid(go)
                -- Memory address (session GUID)
                go_addr = extract_go_addr(go)
                -- Real GameObject name (like spawn points show)
                pcall(function() go_name = go:call("get_Name") end)
                -- Enemy type from context type definition
                pcall(function()
                    local ctx_td = ctx:get_type_definition()
                    if ctx_td then enemy_type = ctx_td:get_full_name() end
                end)
                -- Try to find spawn origin:
                -- Check for SpawnParam-like components on the GameObject
                pcall(function()
                    local num_comps = go:call("get_ComponentCount")
                    if not num_comps then return end
                    for ci = 0, num_comps - 1 do
                        pcall(function()
                            local comp = go:call("getComponent(System.Int32)", ci)
                            if not comp then return end
                            local comp_td = comp:get_type_definition()
                            if not comp_td then return end
                            local comp_name = comp_td:get_name()
                            if comp_name and comp_name:find("Spawn") then
                                local sid = extract_field_guid(comp, "_SpawnID")
                                if sid then spawn_id = sid end
                            end
                        end)
                    end
                end)
                -- Fallback: try to get spawn ID from context
                if not spawn_id then
                    pcall(function()
                        spawn_id = extract_field_guid(ctx, "_SpawnID")
                    end)
                end
            end)
            -- KindID fallback for type — use ToString() not tostring()
            if not enemy_type then
                pcall(function()
                    local kind_obj = ctx:call("get_KindID")
                    if kind_obj then
                        local tok, ts = pcall(kind_obj.call, kind_obj, "ToString()")
                        if tok and ts then
                            enemy_type = tostring(ts)
                        end
                    end
                end)
            end
            out[#out + 1] = {
                ctx = ctx, name = kind, hp = cur, mhp = mx, pos = pos, dist = dist,
                hp_obj = hp_obj, lv = lv, mlv = mlv, dead = is_dead,
                guid = go_guid, go_addr = go_addr, go_name = go_name, kind_type = enemy_type, spawn_id = spawn_id,
            }
        end)
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Fast position-only update (runs between full scans for fluid ESP)
local function update_enemy_positions()
    local pp = ppos()
    for _, e in ipairs(R.enemies) do
        pcall(function()
            if not e.ctx then return end
            -- Update HP
            if e.hp_obj then
                pcall(function() e.dead = e.hp_obj:call("get_IsDead") end)
                pcall(function() e.hp  = e.hp_obj:call("get_CurrentHitPoint") or e.hp end)
                pcall(function() e.mhp = e.hp_obj:call("get_CurrentMaximumHitPoint") or e.mhp end)
            end
            -- Update position
            local wp = nil
            pcall(function() wp = e.ctx:call("get_Position") end)
            if not wp then
                pcall(function()
                    local go = e.ctx:call("get_GameObject")
                    if go then
                        local xf = go:call("get_Transform")
                        if xf then wp = xf:call("get_Position") end
                    end
                end)
            end
            if wp then
                if not e.pos then e.pos = {x=0,y=0,z=0} end
                e.pos.x, e.pos.y, e.pos.z = wp.x, wp.y, wp.z
            end
            -- Update distance
            if pp and e.pos then e.dist = dist3(e.pos, pp) end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Shared Context Table (T) for modules
-- ═══════════════════════════════════════════════════════════════════════════

local T = {
    -- Config & state
    C = C,
    R = R,
    CFG = CFG,
    TITLE = TITLE,
    PERSIST_KEYS = PERSIST_KEYS,
    cfg_dirty = false,
    cfg_last_save_err = nil,
    toast_list = toast_list,

    -- Utilities
    mgr = mgr,
    toast = toast,
    vk_name = vk_name,
    cfg_save = cfg_save,
    cfg_flush = cfg_flush,
    TrainerCache = nil,  -- set after EMV loads (ObjectCache instance)

    -- Player accessors
    php = php,
    pctx = pctx,
    ppos = ppos,
    pxf = pxf,
    get_scene = get_scene,
    hp_vals = hp_vals,
    player_name = player_name,
    player_hp_level = player_hp_level,

    -- Enemy helpers
    scan_enemies = scan_enemies,
    get_kind_name = get_kind_name,
    get_enemy_list = get_enemy_list,
    fetch_rank_data = fetch_rank_data,
    extract_go_guid = extract_go_guid,
    extract_go_addr = extract_go_addr,
    extract_field_guid = extract_field_guid,
    dist3 = dist3,

    -- Press-to-bind state (shared mutable)
    hk_listening = nil,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Module Loader
-- ═══════════════════════════════════════════════════════════════════════════

-- Make T available as a global so modules loaded via dofile/loadfile can access it
_G.__REQUIEM_T = T

local MODULES = {
    "features",
    -- Feature sub-modules (extracted from features.lua)
    "features/noclip",
    "features/chapters",
    "features/costumes",
    "features/difficulty",
    "features/item_indicator",
    -- Core modules
    "hooks", "rendering", "gravity_gun", "ui",
}

-- Discover the autorun directory path
local _script_dir = nil
pcall(function()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local src = info.source:gsub("^@", "")
        _script_dir = src:match("(.+)[/\\][^/\\]+$")
    end
end)

for _, mod_name in ipairs(MODULES) do
    local loaded = false
    local last_err = nil

    -- Strategy 1: absolute path from script directory
    if _script_dir and not loaded then
        local abs = _script_dir .. "/requiem_trainer/" .. mod_name .. ".lua"
        local ok, err = pcall(function()
            local chunk, lerr = loadfile(abs)
            if chunk then chunk(T); loaded = true
            else last_err = lerr end
        end)
        if not ok then last_err = err end
    end

    -- Strategy 2: relative from autorun
    if not loaded then
        local ok, err = pcall(function()
            local chunk, lerr = loadfile("requiem_trainer/" .. mod_name .. ".lua")
            if chunk then chunk(T); loaded = true
            else last_err = lerr end
        end)
        if not ok then last_err = err end
    end

    -- Strategy 3: dofile (REFramework sometimes handles this differently)
    if not loaded then
        local paths_to_try = {
            "requiem_trainer/" .. mod_name .. ".lua",
            "autorun/requiem_trainer/" .. mod_name .. ".lua",
        }
        if _script_dir then
            table.insert(paths_to_try, 1, _script_dir .. "/requiem_trainer/" .. mod_name .. ".lua")
        end
        for _, p in ipairs(paths_to_try) do
            if loaded then break end
            local ok, err = pcall(dofile, p)
            if ok then loaded = true
            else last_err = err end
        end
    end

    if loaded then
        log.info("[Trainer] Module loaded: " .. mod_name)
    else
        log.error("[Trainer] FAILED to load module '" .. mod_name .. "': " .. tostring(last_err))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EMV Engine Loader
-- ═══════════════════════════════════════════════════════════════════════════

pcall(function()
    local emv_path = nil
    if _script_dir then
        emv_path = _script_dir .. "/requiem_trainer/emv_engine/init.lua"
    else
        emv_path = "requiem_trainer/emv_engine/init.lua"
    end
    local emv_fn = loadfile(emv_path)
    if emv_fn then
        emv_fn(T)
        log.info("[Trainer] EMV Engine loaded from " .. emv_path)
        -- Initialise TrainerCache now that EMV's ObjectCache class is available
        if _G.EMV and _G.EMV.ObjectCache then
            -- EMV exposes an instance; grab the class from the module loader
            local oc_path = emv_path:gsub("init%.lua$", "object_cache.lua")
            local oc_fn = loadfile(oc_path)
            if oc_fn then
                local oc_class = oc_fn()
                if oc_class then
                    init_trainer_cache(oc_class)
                    T.TrainerCache = TrainerCache
                end
            end
        end
    else
        log.warn("[Trainer] EMV Engine not found at " .. emv_path)
    end
end)

-- Register EMV tab UI functions on T (so TAB_DEFS tab buttons work)
T.ui_emv_objects = function()
    if EMV and EMV.render_objects_tab then
        pcall(EMV.render_objects_tab)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF6666)
    end
end

T.ui_emv_spawner = function()
    if EMV and EMV.render_spawner_tab then
        pcall(EMV.render_spawner_tab)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF6666)
    end
end

T.ui_emv_viewer = function()
    if EMV and EMV.render_viewer_tab then
        pcall(EMV.render_viewer_tab)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF6666)
    end
end

T.ui_emv_method_inspector = function()
    if EMV and EMV.render_method_inspector then
        pcall(EMV.render_method_inspector)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF6666)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FRAME LOOP
-- ═══════════════════════════════════════════════════════════════════════════

re.on_frame(function()
    R.tick = R.tick + 1
    -- EMV Engine per-frame hooks
    if EMV then
        if EMV.process_on_frame_calls then pcall(EMV.process_on_frame_calls) end
        if EMV.process_deferred_calls then pcall(EMV.process_deferred_calls) end
        if EMV.ObjectCache then pcall(EMV.ObjectCache.sweep, EMV.ObjectCache) end
    end
    -- Trainer ObjectCache sweep (singletons, GO browser, etc.)
    if TrainerCache then pcall(TrainerCache.sweep, TrainerCache) end
    -- Cache screen dimensions
    if R.tick % 60 == 1 then
        pcall(function()
            local view = sdk.call_native_func(_sm_singleton, _sm_td, "get_MainView")
            if view then
                local w = view:call("get_WindowWidth")
                local h = view:call("get_WindowHeight")
                if w and w > 0 then R.screen_w = w end
                if h and h > 0 then R.screen_h = h end
            end
        end)
    end
    if not R.hooks_ok and T.install_hooks then pcall(T.install_hooks) end
    -- Deferred config save
    if R.tick % 120 == 0 then pcall(cfg_flush) end
    -- God mode
    if C.god_mode and T.god_on then pcall(T.god_on) end
    if C.hp_lock then pcall(function() local h = php(); if h then h:call("set_CurrentHitPoint", C.hp_lock_val) end end) end
    -- Arsenal
    if R.tick % 4 == 0 and (C.inf_ammo or C.inf_melee or C.inf_durability) and T.arsenal_tick then pcall(T.arsenal_tick) end
    -- Game speed
    if R.tick % 15 == 0 and T.game_speed_tick then pcall(T.game_speed_tick) end
    -- Enemy scan + freeze
    if R.tick % 30 == 0 and (C.enemy_esp or C.motion_freeze or C.enemy_panel) then
        R.enemies = scan_enemies()
        if C.motion_freeze and T.freeze_enemies then pcall(T.freeze_enemies) end
        if C.show_rank or C.show_da then pcall(function() R.rank_data = fetch_rank_data() end) end
    elseif R.tick % 2 == 0 and #R.enemies > 0 and (C.enemy_esp or C.enemy_panel) then
        pcall(update_enemy_positions)
    end
    -- Skip cutscenes
    if R.tick % 3 == 0 and T.skip_cutscene then pcall(T.skip_cutscene) end
    -- Enemy speed override
    if C.enemy_speed_on and R.tick % 15 == 0 then
        pcall(function()
            local motion_type = R._motion_type
            if not motion_type then
                motion_type = sdk.typeof("via.motion.Motion")
                R._motion_type = motion_type
            end
            if not motion_type then return end
            local list, count = get_enemy_list()
            if not list or count <= 0 then return end
            local skip_kw = {"attack","finish","execution","dead","death","damage","grapple","stun","down"}
            for i = 0, count - 1 do
                pcall(function()
                    local ctx = list:call("get_Item", i)
                    if not ctx then return end
                    local hp_obj = ctx:call("get_HitPoint")
                    if hp_obj then
                        local cur = hp_obj:call("get_CurrentHitPoint") or 0
                        if cur <= 0 then return end
                    end
                    local go = ctx:call("get_GameObject")
                    if not go then return end
                    local motion = go:call("getComponent(System.Type)", motion_type)
                    if not motion then return end
                    local layer = motion:call("getLayer", 0)
                    if not layer then return end
                    local node = layer:call("get_HighestWeightMotionNode")
                    if not node then return end
                    local anim_name = node:call("get_MotionName")
                    if not anim_name then return end
                    local lower = anim_name:lower()
                    for _, kw in ipairs(skip_kw) do
                        if lower:find(kw, 1, true) then return end
                    end
                    if lower:find("walk", 1, true) or lower:find("run", 1, true) then
                        layer:call("set_Speed", C.enemy_speed)
                    else
                        layer:call("set_Speed", 1.0)
                    end
                end)
            end
        end)
    end
    -- Remote storage hotkey
    if C.remote_storage and C.hk_remote_storage > 0 and T.toggle_remote_storage then
        local down = false
        pcall(function() down = reframework:is_key_down(C.hk_remote_storage) end)
        if not T._remote_storage_latch then T._remote_storage_latch = false end
        if down and not T._remote_storage_latch then pcall(T.toggle_remote_storage) end
        T._remote_storage_latch = down
    end
    -- Film grain disable
    if C.disable_film_grain and R.tick % 60 == 0 then
        pcall(function()
            local rm = mgr("app.RenderingManager")
            if rm and rm:call("get__IsFilmGrainCustomFilterEnable") then
                rm:call("set__IsFilmGrainCustomFilterEnable", false)
            end
        end)
    end
    -- Misc features
    if R.tick % 10 == 0 and T.track_death_position then pcall(T.track_death_position) end
    if R.tick % 120 == 0 and C.show_area and T.scan_area_name then pcall(T.scan_area_name) end
    if R.tick % 30 == 0 and C.show_igt and T.scan_igt then pcall(T.scan_igt) end
    -- EMV Objects overlay background scan (self-throttled by scan_interval)
    if _G.EMV and _G.EMV.objects_background_update then pcall(_G.EMV.objects_background_update) end
    -- Item indicator scan (self-throttled by scan_interval)
    if C.show_items and T.scan_indicator_items then pcall(T.scan_indicator_items) end
    -- Item indicator render (every frame for smooth display)
    if C.show_items and T.render_item_indicators then pcall(T.render_item_indicators) end
    -- Level Flow indicators (every frame)
    if T.render_level_flow then pcall(T.render_level_flow) end
    -- Gravity Gun debug visualization (update runs in LateUpdateBehavior)
    if T.GravityGun then pcall(T.GravityGun.render_world) end
    -- Rapid fire
    if C.rapid_fire and R.tick % 2 == 0 then
        pcall(function()
            local cm = mgr("app.CharacterManager")
            if not cm then return end
            local ctx = cm:call("getPlayerContextRef")
            if not ctx then return end
            local go = ctx:call("get_GameObject")
            if not go then return end
            local t = sdk.typeof("app.PlayerEquipment")
            if not t then return end
            local pe = go:call("getComponent(System.Type)", t)
            if not pe then return end
            pe:set_field("_ShotInterval", 0.005)
            pe:set_field("_CalcShotInterval", 0.005)
            pe:set_field("_ExcessShotInterval", 0.0)
            pe:set_field("_EquipShotType", 1)
        end)
    end
    -- NoClip (new system from features.lua)
    if T.noclip_tick then pcall(T.noclip_tick) end
    -- NoClip hotkey (F2 by default)
    if C.hk_noclip and C.hk_noclip > 0 then
        local nc_down = false
        pcall(function() nc_down = reframework:is_key_down(C.hk_noclip) end)
        if not R._nc_latch then R._nc_latch = false end
        if nc_down and not R._nc_latch then
            if C.noclip then
                if T.noclip_off then pcall(T.noclip_off) end
            else
                if T.noclip_on then pcall(T.noclip_on) end
            end
            pcall(cfg_save)
        end
        R._nc_latch = nc_down
    end
    if T.pos_freeze then pcall(T.pos_freeze) end
    if T.hotkeys then pcall(T.hotkeys) end
    -- Playtime freeze (every frame)
    if T.freeze_playtime_tick then pcall(T.freeze_playtime_tick) end
    -- Quick Load scene jump (delayed)
    if T.load_scene_jump_tick then pcall(T.load_scene_jump_tick) end
    -- Chapter jump continuation monitor
    if T.process_jump_continuation then pcall(T.process_jump_continuation) end
    -- Chapter detection (every 120 frames)
    if R.tick % 120 == 10 then
        if T.scan_chapter then pcall(T.scan_chapter) end
        if T.scan_level_flow_controllers then pcall(T.scan_level_flow_controllers) end
    end
    -- Damage numbers
    if C.show_damage then
        if T.install_dmg_hooks then pcall(T.install_dmg_hooks) end
        if T.dmg_flush_coalesce then pcall(T.dmg_flush_coalesce) end
        if R.tick % 3 == 0 and T.dmg_update_cache then pcall(T.dmg_update_cache) end
        if T.dmg_scan_deltas then pcall(T.dmg_scan_deltas) end
    end
    -- D2D fallback panel
    if not T.has_d2d and T.has_draw and T.draw_enemy_panel then pcall(T.draw_enemy_panel) end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════

re.on_script_reset(function()
    if C.god_mode and T.god_off then pcall(T.god_off) end
    if (C.inf_ammo or C.inf_melee) and T.arsenal_off then pcall(T.arsenal_off) end
    if C.game_speed_on and T.game_speed_revert then pcall(T.game_speed_revert) end
    if T.reset_speed then pcall(T.reset_speed) end
    if C.noclip and T.noclip_off then pcall(T.noclip_off) end
    if C.motion_freeze and T.freeze_enemies then C.motion_freeze = false; pcall(T.freeze_enemies) end
    if C.disable_film_grain then
        pcall(function()
            local rm = mgr("app.RenderingManager")
            if rm then rm:call("set__IsFilmGrainCustomFilterEnable", true) end
        end)
    end
    -- Trainer ObjectCache cleanup
    if TrainerCache then pcall(TrainerCache.clear, TrainerCache) end
    -- EMV Engine cleanup is handled by its own re.on_script_reset in init.lua
end)

re.on_config_save(cfg_save)

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN UI — Floating Window + Tab Bar
-- ═══════════════════════════════════════════════════════════════════════════

local trainer_visible = true

local TAB_DEFS = {
    { name = "Player",    fn = "ui_player" },
    { name = "Combat",    fn = "ui_combat" },
    { name = "Enemies",   fn = "ui_enemies" },
    { name = "Inventory", fn = "ui_weapons" },
    { name = "Items",     fn = "ui_item_indicator" },
    { name = "Saves",     fn = "ui_saves" },
    { name = "World",     fn = "ui_world" },
    --{ name = "Gravity",   fn = "ui_gravity_gun" },
    { name = "Settings",  fn = "ui_settings" },
    { name = "Dev",       fn = "ui_dev" },
    { name = "Objects",   fn = "ui_emv_objects" },
    --{ name = "Inspector", fn = "ui_emv_method_inspector" },
    --{ name = "Spawner",   fn = "ui_emv_spawner" },
    --{ name = "Viewer",    fn = "ui_emv_viewer" },
}

re.on_draw_ui(function()
    local changed
    changed, trainer_visible = imgui.checkbox(TITLE, trainer_visible)
    if not trainer_visible then return end

    if imgui.begin_window(TITLE .. "###trainer_main", true, 0) then
        -- ── Enhanced Status Bar ──
        local active = 0
        for _, k in ipairs({"god_mode","hp_lock","ohk","no_recoil","no_reload","inf_grenades","inf_ammo","inf_melee","highlight","noclip","enemy_panel","enemy_esp","motion_freeze","game_speed_on","skip_cutscenes","player_speed_on","show_damage","auto_parry","stealth","fov_enabled","free_craft","rapid_fire","super_accuracy","highlight_items","unlock_recipes","unlimited_saves","remote_storage","enemy_speed_on","show_items","gravity_gun_enabled"}) do
            if C[k] then active = active + 1 end
        end

        -- Player HP inline
        local p_cur, p_max
        pcall(function()
            local h = php()
            if h then
                p_cur = h:call("get_CurrentHitPoint")
                p_max = h:call("get_CurrentMaximumHitPoint")
            end
        end)
        if p_cur and p_max and p_max > 0 then
            local ratio = math.max(0, math.min(1, p_cur / p_max))
            local hp_col
            if ratio > 0.6 then hp_col = 0xFF44FF88
            elseif ratio > 0.3 then hp_col = 0xFF44DDFF
            else hp_col = 0xFF4444FF end
            imgui.text_colored(("HP %d/%d"):format(math.ceil(p_cur), math.ceil(p_max)), hp_col)
            imgui.same_line()
        end

        if active > 0 then
            imgui.text_colored(("%d active"):format(active), 0xFF44FF88)
        else
            imgui.text_colored("idle", 0xFF777777)
        end

        if #R.enemies > 0 then
            imgui.same_line()
            imgui.text_colored(("%d enemies"):format(#R.enemies), 0xFFFFAA44)
        end

        -- Area name (if available)
        if R.area_name and R.area_name ~= "" then
            imgui.same_line()
            imgui.text_colored("  " .. R.area_name, 0xFF777777)
        end

        imgui.separator()

        -- Run the press-to-bind key scanner every frame (must be outside any tab)
        if T.hk_scanner then pcall(T.hk_scanner) end

        -- ── Button-based Tab Selector ──
        for i, tab in ipairs(TAB_DEFS) do
            if T[tab.fn] then
                if i > 1 then imgui.same_line() end
                local is_active = (C.ui_tab == i)
                if is_active then
                    imgui.push_style_color(21, 0xFF44FF88) -- ImGuiCol_Button
                    imgui.push_style_color(22, 0xFF44FF88) -- ImGuiCol_ButtonHovered
                    imgui.push_style_color(23, 0xFF44FF88) -- ImGuiCol_ButtonActive
                    imgui.push_style_color(0, 0xFF1A1A2E)  -- ImGuiCol_Text (dark on green)
                else
                    imgui.push_style_color(21, 0xFF333344) -- ImGuiCol_Button
                    imgui.push_style_color(22, 0xFF444466) -- ImGuiCol_ButtonHovered
                    imgui.push_style_color(23, 0xFF555577) -- ImGuiCol_ButtonActive
                    imgui.push_style_color(0, 0xFFAAAAAA) -- ImGuiCol_Text
                end
                if imgui.button(tab.name .. "##tab" .. i) then
                    C.ui_tab = i
                end
                imgui.pop_style_color(4)
            end
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- ── Draw selected tab content ──
        local sel = TAB_DEFS[C.ui_tab or 1]
        if sel and T[sel.fn] then
            pcall(T[sel.fn])
        end

        imgui.end_window()
    end
end)

log.info(("[Trainer] %s loaded (modular)"):format(TITLE))
