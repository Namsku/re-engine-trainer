--[[
    Biorand RE3R Trainer v3.0
    by namsku / Biorand

    Features
    ────────
    • D2D overlay: enemy ESP (world-space), item ESP, dev info panel (top-left)
    • D2D panels (top-right): Enemy Spawn overlay, LevelFlow overlay
    • ImGui window: Enemies / Spawn Groups / Scenarios / Items / Settings tabs
    • B key: append scanned enemies to reframework/data/extra_enemies.csv

    Placement (REFramework autorun):
      reframework/autorun/biorand_re3r_trainer.lua
]]

if reframework:get_game_name() ~= "re3" then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- MapID Enum — offline.gamemastering.Map.ID
-- ═══════════════════════════════════════════════════════════════════════════

local MAP_ID_NAMES = {
    [0]="Invalid",
    [1]="st00_0101_0",[2]="st00_0102_0",[3]="st00_0201_0",[4]="st00_0202_0",
    [5]="st00_0203_0",[6]="st00_0204_0",[7]="st00_0205_0",[8]="st00_0206_0",
    [9]="st00_0207_0",[10]="st00_0208_0",[11]="st00_0209_0",
    [12]="st01_0101_0",[13]="st01_0102_0",[14]="st01_0103_0",[15]="st01_0104_0",
    [16]="st01_0201_0",[17]="st01_0202_0",[18]="st01_0301_0",[19]="st01_0302_0",
    [20]="st01_0303_0",[21]="st01_0304_0",[22]="st01_0305_0",[23]="st01_0306_0",
    [24]="st01_0307_0",[25]="st01_0308_0",[26]="st01_0401_0",[27]="st01_0501_0",
    [28]="st01_0502_0",[29]="st01_0601_0",
    [30]="st02_0101_0",[31]="st02_0102_0",[32]="st02_0103_0",[33]="st02_0104_0",
    [34]="st02_0105_0",[35]="st02_0106_0",[36]="st02_0201_0",[37]="st02_0202_0",
    [38]="st02_0203_0",[39]="st02_0204_0",[40]="st02_0205_0",[41]="st02_0206_0",
    [42]="st02_0207_0",[43]="st02_0208_0",[44]="st02_0209_0",[45]="st02_0210_0",
    [46]="st02_0211_0",[47]="st02_0212_0",[48]="st02_0213_0",[49]="st02_0214_0",
    [50]="st02_0215_0",[51]="st02_0216_0",[52]="st02_0217_0",
    [53]="st02_0301_0",[54]="st02_0302_0",[55]="st02_0303_0",[56]="st02_0304_0",
    [57]="st02_0305_0",[58]="st02_0306_0",[59]="st02_0307_0",[60]="st02_0308_0",
    [61]="st02_0309_0",[62]="st02_0310_0",[63]="st02_0311_0",[64]="st02_0312_0",
    [65]="st02_0313_0",[66]="st02_0314_0",
    [67]="st02_0401_0",[68]="st02_0401_1",[69]="st02_0402_0",[70]="st02_0403_0",
    [71]="st02_0404_0",[72]="st02_0405_0",[73]="st02_0406_0",[74]="st02_0407_0",
    [75]="st02_0408_0",[76]="st02_0409_0",[77]="st02_0410_0",[78]="st02_0411_0",
    [79]="st02_0412_0",
    [80]="st02_0501_0",[81]="st02_0502_0",[82]="st02_0503_0",[83]="st02_0504_0",
    [84]="st02_0505_0",[85]="st02_0506_0",[86]="st02_0507_0",[87]="st02_0508_0",
    [88]="st02_0601_0",[89]="st02_0602_0",[90]="st02_0603_0",[91]="st02_0604_0",
    [92]="st02_0605_0",[93]="st02_0606_0",[94]="st02_0607_0",[95]="st02_0608_0",
    [96]="st02_0609_0",[97]="st02_0610_0",
    [98]="st02_0650_0",
    [99]="st02_0701_0",[100]="st02_0702_0",[101]="st02_0703_0",[102]="st02_0704_0",
    [103]="st02_0705_0",[104]="st02_0708_0",[105]="st02_0709_0",[106]="st02_0710_0",
    [107]="st02_0711_0",[108]="st02_0712_0",[109]="st02_0713_0",[110]="st02_0714_0",
    [111]="st02_0715_0",[112]="st02_0716_0",[113]="st02_0717_0",
    [114]="st02_0750_0",[115]="st02_0751_0",[116]="st02_0752_0",[117]="st02_0753_0",
    [118]="st02_0754_0",[119]="st02_0755_0",
    [120]="st02_0800_0",
    [121]="st02_0509_0",
    [122]="st03_0101_0",[123]="st03_0102_0",[124]="st03_0103_0",[125]="st03_0104_0",
    [126]="st03_0105_0",[127]="st03_0106_0",[128]="st03_0107_0",[129]="st03_0108_0",
    [130]="st03_0151_0",[131]="st03_0152_0",[132]="st03_0153_0",[133]="st03_0154_0",
    [134]="st03_0201_0",[135]="st03_0202_0",[136]="st03_0203_0",[137]="st03_0204_0",
    [138]="st03_0205_0",[139]="st03_0206_0",[140]="st03_0207_0",[141]="st03_0208_0",
    [142]="st03_0209_0",[143]="st03_0210_0",[144]="st03_0211_0",[145]="st03_0212_0",
    [146]="st03_0213_0",[147]="st03_0214_0",[148]="st03_0215_0",[149]="st03_0216_0",
    [150]="st03_0217_0",[151]="st03_0218_0",[152]="st03_0219_0",[153]="st03_0220_0",
    [154]="st03_0221_0",[155]="st03_0222_0",[156]="st03_0223_0",[157]="st03_0224_0",
    [158]="st03_0225_0",[159]="st03_0226_0",[160]="st03_0227_0",[161]="st03_0228_0",
    [162]="st03_0229_0",[163]="st03_0230_0",[164]="st03_0231_0",[165]="st03_0232_0",
    [166]="st03_0233_0",[167]="st03_0234_0",[168]="st03_0235_0",[169]="st03_0236_0",
    [170]="st03_0251_0",[171]="st03_0252_0",[172]="st03_0253_0",[173]="st03_0254_0",
    [174]="st03_0255_0",[175]="st03_0256_0",[176]="st03_0257_0",[177]="st03_0258_0",
    [178]="st03_0259_0",[179]="st03_0260_0",[180]="st03_0261_0",[181]="st03_0262_0",
    [182]="st03_0301_0",[183]="st03_0302_0",[184]="st03_0303_0",[185]="st03_0304_0",
    [186]="st03_0305_0",[187]="st03_0306_0",[188]="st03_0307_0",[189]="st03_0308_0",
    [190]="st03_0309_0",[191]="st03_0310_0",[192]="st03_0311_0",[193]="st03_0312_0",
    [194]="st03_0313_0",[195]="st03_0314_0",[196]="st03_0315_0",
    [197]="st03_0401_0",[198]="st03_0402_0",[199]="st03_0403_0",[200]="st03_0404_0",
    [201]="st03_0451_0",[202]="st03_0452_0",
    [203]="st03_0501_0",[204]="st03_0502_0",[205]="st03_0503_0",
    [206]="st03_0601_0",[207]="st03_0602_0",[208]="st03_0603_0",[209]="st03_0604_0",
    [210]="st03_0605_0",[211]="st03_0606_0",[212]="st03_0607_0",[213]="st03_0608_0",
    [214]="st03_0609_0",[215]="st03_0610_0",[216]="st03_0611_0",[217]="st03_0612_0",
    [218]="st03_0613_0",[219]="st03_0614_0",[220]="st03_0615_0",[221]="st03_0616_0",
    [222]="st03_0617_0",[223]="st03_0618_0",[224]="st03_0619_0",[225]="st03_0620_0",
    [226]="st03_0621_0",
    [227]="st03_0701_0",[228]="st03_0702_0",[229]="st03_0703_0",[230]="st03_0704_0",
    [231]="st03_0705_0",[232]="st03_0706_0",
    [233]="st03_0751_0",[234]="st03_0752_0",[235]="st03_0753_0",[236]="st03_0754_0",
    [237]="st03_0801_0",[238]="st03_0802_0",[239]="st03_0803_0",[240]="st03_0804_0",
    [241]="st03_0805_0",[242]="st03_0806_0",
    [243]="st04_0101_0",[244]="st04_0102_0",[245]="st04_0103_0",[246]="st04_0104_0",
    [247]="st04_0105_0",[248]="st04_0106_0",[249]="st04_0107_0",[250]="st04_0108_0",
    [251]="st04_0109_0",[252]="st04_0110_0",[253]="st04_0111_0",[254]="st04_0112_0",
    [255]="st04_0113_0",
    [256]="st04_0201_0",[257]="st04_0202_0",[258]="st04_0203_0",[259]="st04_0204_0",
    [260]="st04_0205_0",[261]="st04_0206_0",[262]="st04_0207_0",[263]="st04_0208_0",
    [264]="st04_0209_0",[265]="st04_0210_0",[266]="st04_0211_0",
    [267]="st04_0501_0",
    [268]="st04_0101_1",[269]="st04_0102_1",[270]="st04_0103_1",[271]="st04_0104_1",
    [272]="st04_0105_1",[273]="st04_0106_1",[274]="st04_0107_1",[275]="st04_0108_1",
    [276]="st04_0109_1",[277]="st04_0110_1",[278]="st04_0111_1",[279]="st04_0112_1",
    [280]="st04_0113_1",
    [281]="st04_0201_1",[282]="st04_0202_1",[283]="st04_0203_1",[284]="st04_0204_1",
    [285]="st04_0205_1",[286]="st04_0206_1",[287]="st04_0207_1",[288]="st04_0208_1",
    [289]="st04_0209_1",[290]="st04_0210_1",[291]="st04_0211_1",
    [292]="st04_0301_1",[293]="st04_0302_1",
    [294]="st04_0401_1",[295]="st04_0402_1",[296]="st04_0403_1",[297]="st04_0404_1",
    [298]="st04_0405_1",[299]="st04_0406_1",[300]="st04_0407_1",[301]="st04_0408_1",
    [302]="st04_0409_1",[303]="st04_0410_1",
    [304]="st05_0101_0",[305]="st05_0102_0",[306]="st05_0103_0",[307]="st05_0104_0",
    [308]="st05_0105_0",[309]="st05_0106_0",[310]="st05_0107_0",[311]="st05_0108_0",
    [312]="st05_0109_0",[313]="st05_0110_0",[314]="st05_0111_0",[315]="st05_0112_0",
    [316]="st05_0201_0",[317]="st05_0202_0",[318]="st05_0203_0",
    [319]="st05_0301_0",[320]="st05_0302_0",[321]="st05_0303_0",
    [322]="st05_0401_0",
    [323]="st05_0501_0",
    [324]="st05_0601_0",
}

local function map_id_str(id)
    if id == nil then return "?" end
    local n = math.tointeger(id) or id
    local name = MAP_ID_NAMES[n]
    if name then return string.format("%d  (%s)", n, name) end
    return tostring(n)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Names
-- ═══════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════
-- KindID names for RE3R
-- ═══════════════════════════════════════════════════════════════════════════

local KIND_NAMES = {
    [4]  = "Zombie",
    [5]  = "Zombie Dog",
    [6]  = "Licker",
    [7]  = "Hunter",
    [18] = "Nemesis",
}

local function kind_name(id)
    if id == nil then return "?" end
    local n = math.tointeger(id) or id
    return KIND_NAMES[n] or ("Kind:" .. tostring(n))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Config & Persistence
-- ═══════════════════════════════════════════════════════════════════════════

local TITLE    = "Biorand RE3R Trainer v3.0"
local CFG_FILE = "biorand_re3r_trainer.json"

local cfg = {
    show_dev_overlay        = true,
    show_enemy_esp          = true,
    show_item_esp           = true,
    show_spawn_overlay      = true,
    show_levelflow_overlay  = true,
    show_ui                 = true,

    enemy_esp_range         = 30.0,
    item_esp_range          = 30.0,
    hide_dead               = true,

    col_enemy_name          = 0xFFFFFFFF,
    col_item_name           = 0xFF55FF99,
    col_object_name         = 0xFFFFCC88,

    show_object_esp                = false,
    object_esp_range               = 15.0,
    object_esp_only_tagged         = true,
    show_levelflow_catalog_overlay = false,
    go_highlight_selected          = false,

    font_size               = 16,
    scan_interval           = 45,
}

local PERSIST_KEYS = {}
for k in pairs(cfg) do PERSIST_KEYS[#PERSIST_KEYS + 1] = k end

local function cfg_save()
    if not json then return end
    local data = {}
    for _, k in ipairs(PERSIST_KEYS) do data[k] = cfg[k] end
    local ok, err = pcall(json.dump_file, CFG_FILE, data)
    if not ok then log.warn("[RE3R Trainer] cfg_save failed: " .. tostring(err)) end
end

local function cfg_load()
    if not json then return end
    local ok, data = pcall(json.load_file, CFG_FILE)
    if not ok or type(data) ~= "table" then return end
    for _, k in ipairs(PERSIST_KEYS) do
        if data[k] ~= nil and type(data[k]) == type(cfg[k]) then
            cfg[k] = data[k]
        end
    end
end

cfg_load()
re.on_config_save(cfg_save)

-- ═══════════════════════════════════════════════════════════════════════════
-- Constants
-- ═══════════════════════════════════════════════════════════════════════════

local SPAWN_OVERLAY_LIMIT     = 12
local SPAWN_NAME_MAX_CHARS    = 28
local LEVELFLOW_NAME_MAX_CHARS = 36
local LEVELFLOW_HIGHLIGHT_WINDOW = 30.0

-- ═══════════════════════════════════════════════════════════════════════════
-- Runtime State
-- ═══════════════════════════════════════════════════════════════════════════

local state = {
    tick            = 0,
    sw              = 1920,
    sh              = 1080,
    player_pos      = nil,
    player_hp       = 0,
    dev_rotation    = nil,

    enemies         = {},
    items           = {},
    spawn_groups    = {},
    scenarios       = {},
    objects         = {},

    scenario_state_history = {},
    spawn_scene_address    = 0,
    scenario_scene_address = 0,

    status_msg      = "",
    status_until    = 0,

    dev = {
        scene        = "",
        map_id       = nil,
        rank         = nil,
        playtime     = nil,
        player_name  = "",
        player_state = "",
    },

    sel_type = nil,   -- "enemy", "spawn", "item", "scenario"
    sel_data = nil,   -- shallow copy of the selected row's data table
    ui_tab = 1,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Engine / Scene Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local _sm    = sdk.get_native_singleton("via.SceneManager")
local _sm_td = sdk.find_type_definition("via.SceneManager")

local function get_scene()
    local ok, s = pcall(sdk.call_native_func, _sm, _sm_td, "get_CurrentScene()")
    return ok and s or nil
end

local function get_window_size()
    local mv = nil
    pcall(function() mv = sdk.call_native_func(_sm, _sm_td, "get_MainView") end)
    if not mv then return nil end
    local sz = nil
    pcall(function() sz = mv:call("get_WindowSize") end)
    return sz
end

local function update_screen_size()
    local sz = get_window_size()
    if sz and sz.w and sz.w > 0 then state.sw = sz.w end
    if sz and sz.h and sz.h > 0 then state.sh = sz.h end
end

local function dist3(a, b)
    if not a or not b then return 0 end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function clamp_text(text, max_chars)
    local s = tostring(text or "")
    if #s <= max_chars then return s end
    return s:sub(1, max_chars - 3) .. "..."
end

local function to_int(v)
    if v == nil then return nil end
    if type(v) == "number" then return math.tointeger(v) or v end
    local n = tonumber(v)
    if n then return math.tointeger(n) or n end
    local ok, s = pcall(tostring, v)
    if ok then n = tonumber(s); if n then return math.tointeger(n) or n end end
    return nil
end

-- ── Type cache ────────────────────────────────────────────────────────────

local _type_cache = {}

local function get_rt(type_name)
    if not _type_cache[type_name] then
        _type_cache[type_name] = sdk.typeof(type_name)
    end
    return _type_cache[type_name]
end

local function get_component(go, type_name)
    if not go then return nil end
    local rt = get_rt(type_name)
    if not rt then return nil end
    local ok, c = pcall(go.call, go, "getComponent(System.Type)", rt)
    return ok and c or nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GUID Extraction
-- ═══════════════════════════════════════════════════════════════════════════

-- Stable GUID from GameObject.ToString(), pattern "Name@guid]"
local function extract_guid(go)
    if not go then return nil end
    local ok, ts = pcall(go.call, go, "ToString()")
    if ok and ts then
        local guid = tostring(ts):match("@([%x%-]+)%]$")
        if guid and guid ~= "" then return guid end
    end
    return nil
end

-- Stable spawn-entry GUID from EnemyController.get_ContextGUID
local function extract_context_guid(comp)
    if not comp then return nil end
    local ok, cg = pcall(comp.call, comp, "get_ContextGUID")
    if not ok or cg == nil then return nil end
    local ok2, ts = pcall(cg.call, cg, "ToString()")
    if ok2 and ts then
        local s = tostring(ts)
        if s ~= "" and s ~= "nil" then return s end
    end
    return nil
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
    return go
end

local function update_player_pos()
    local updated = false
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local pos = xf:call("get_Position")
        if pos then
            state.player_pos = { x = pos.x, y = pos.y, z = pos.z }
            updated = true
        end
    end)
    if not updated then
        pcall(function()
            local cam = sdk.get_primary_camera()
            if not cam then return end
            local go = cam:call("get_GameObject")
            if not go then return end
            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if pos then state.player_pos = { x = pos.x, y = pos.y, z = pos.z } end
        end)
    end
end

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
        if q then state.dev_rotation = quat_yaw(q) end
    end)
end

local function get_enemy_hp(go)
    local hpc = get_component(go, "offline.HitPointController")
    if not hpc then return nil end
    local hp = nil
    pcall(function() hp = hpc:get_field("CurrentHitPoint") end)
    if hp == nil then pcall(function() hp = hpc:call("get_CurrentHitPoint") end) end
    return hp
end

local function update_player_hp()
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local hp = get_enemy_hp(go)
        if hp then state.player_hp = hp end
    end)
end

-- ── Game-state scanning ───────────────────────────────────────────────────

local function read_named_int(obj, names)
    if not obj then return nil end
    for _, name in ipairs(names) do
        local ok, v = pcall(obj.call, obj, name)
        local n = ok and to_int(v) or nil
        if n ~= nil then return n end
    end
    for _, name in ipairs(names) do
        local ok, v = pcall(obj.get_field, obj, name)
        local n = ok and to_int(v) or nil
        if n ~= nil then return n end
    end
    return nil
end

local function scan_game_state()
    -- Scene name
    pcall(function()
        local scene = get_scene()
        if not scene then return end
        local name = nil
        pcall(function() name = tostring(scene:call("get_Name") or "") end)
        if not name or name == "" or name == "nil" then
            local s = tostring(scene)
            name = s:match("%[(.-)@") or s:match("Scene%[(.-)%]") or ""
        end
        if name and name ~= "" and name ~= "nil" then state.dev.scene = name end
    end)

    -- MapID via EnemyManager (confirmed working path)
    local map_id = nil
    pcall(function()
        local em = sdk.get_managed_singleton("offline.EnemyManager")
        if not em then return end
        map_id = read_named_int(em, {
            "<LastPlayerStaySceneID>k__BackingField",
            "LastPlayerStaySceneID",
            "<LastPlayerStayMapID>k__BackingField",
            "LastPlayerStayMapID",
        })
    end)
    if map_id then state.dev.map_id = map_id end

    -- Rank
    pcall(function()
        local rm = sdk.get_managed_singleton("offline.GameRankManager")
        if not rm then return end
        local rank = nil
        pcall(function() rank = rm:call("getCurrentRank") end)
        if not rank then pcall(function() rank = rm:get_field("_Rank") end) end
        if rank ~= nil then state.dev.rank = rank end
    end)

    -- Player name
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local n = ""
        pcall(function() n = tostring(go:call("get_Name") or "") end)
        if n:find("pl0000") or n:find("Jill") then state.dev.player_name = "Jill"
        elseif n:find("pl2000") or n:find("Carlos") then state.dev.player_name = "Carlos"
        elseif n ~= "" then state.dev.player_name = n end
    end)

    -- Player state
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        local st = nil
        pcall(function() st = pm:call("get_GamePlayerState") end)
        if not st then pcall(function() st = pm:get_field("_PlayerState") end) end
        if st ~= nil then state.dev.player_state = tostring(st) end
    end)

    -- Playtime
    pcall(function()
        local sm = sdk.get_managed_singleton("offline.SceneManager")
        if sm then pcall(function() state.dev.playtime = sm:call("get_PlayTime") end) end
        if not state.dev.playtime then
            local gm = sdk.get_managed_singleton("offline.GameProgressManager")
            if gm then pcall(function() state.dev.playtime = gm:call("get_PlayTime") end) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BT State Helper (used by scenarios and spawn groups)
-- ═══════════════════════════════════════════════════════════════════════════

local function get_bt_state(go)
    if not go then return nil end
    local bt_rt = get_rt("via.behaviortree.BehaviorTree")
    if not bt_rt then return nil end
    local bt = nil
    pcall(function() bt = go:call("getComponent(System.Type)", bt_rt) end)
    if not bt then return nil end
    local s = nil
    pcall(function() s = bt:call("getCurrentNodeName", 0) end)
    if s == nil then return nil end
    local text = tostring(s)
    if text == "" or text == "nil" then return nil end
    return text
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Scanning (ScenarioController list from SSM)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_scenarios()
    local results = {}
    local now = os.clock()

    pcall(function()
        local scene = get_scene()
        local scene_addr = 0
        pcall(function() scene_addr = scene and scene:get_address() or 0 end)
        if state.scenario_scene_address ~= scene_addr then
            state.scenario_scene_address = scene_addr
            state.scenario_state_history = {}
        end

        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end

        local ctrl_list = nil
        pcall(function() ctrl_list = ssm:get_field("_ScenarioControllerList") end)
        if not ctrl_list then return end

        local n = 0
        pcall(function() n = ctrl_list:call("get_Count") or 0 end)

        for i = 0, n - 1 do
            pcall(function()
                local ctrl = ctrl_list:call("get_Item", i)
                if not ctrl then return end

                local go = ctrl:call("get_GameObject")
                if not go then return end

                local go_name = tostring(go:call("get_Name") or "?")
                local is_advance = false
                local scenario_no = nil
                pcall(function() is_advance = ctrl:get_field("IsAdvanceNo") == true end)
                pcall(function() scenario_no = to_int(ctrl:get_field("ScenarioNo")) end)

                local bt_state = get_bt_state(go)
                local addr = 0
                pcall(function() addr = go:get_address() end)

                local prev = state.scenario_state_history[addr]
                local changed_at = prev and prev.changed_at or 0
                if prev and prev.bt_state ~= bt_state then
                    changed_at = now
                end
                state.scenario_state_history[addr] = { bt_state = bt_state, changed_at = changed_at }

                results[#results + 1] = {
                    go_name    = go_name,
                    bt_state   = bt_state or "-",
                    is_advance = is_advance,
                    scenario_no = scenario_no,
                    changed_at = changed_at,
                }
            end)
        end
    end)

    state.scenarios = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- findComponents Helper
-- ═══════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Context Type (em0000.Em0000 format from the Context component)
-- ═══════════════════════════════════════════════════════════════════════════

local _ESCAPE_PFX = "offline.escape.enemy."
local _ENEMY_PFX  = "offline.enemy."
local _CTX_SFX    = "Context"

local function get_enemy_context_type(go)
    if not go then return nil end
    local result = nil
    pcall(function()
        local comps = go:call("get_Components")
        if not comps then return end
        local n = 0
        pcall(function() n = comps:call("get_Count") end)
        for i = 0, n - 1 do
            if result then break end
            pcall(function()
                local c = comps:call("get_Item", i)
                if not c then return end
                local td = c:get_type_definition()
                if not td then return end
                local fname = td:get_full_name() or ""
                local s, matched = fname, false
                if fname:sub(1, #_ESCAPE_PFX) == _ESCAPE_PFX then
                    s = fname:sub(#_ESCAPE_PFX + 1); matched = true
                elseif fname:sub(1, #_ENEMY_PFX) == _ENEMY_PFX then
                    s = fname:sub(#_ENEMY_PFX + 1); matched = true
                end
                if matched and s:sub(-#_CTX_SFX) == _CTX_SFX then
                    result = s:sub(1, -(#_CTX_SFX + 1))
                end
            end)
        end
    end)
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Scanning (EnemyController)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_enemies()
    local comps, n = find_comps("offline.EnemyController")
    if not comps or n <= 0 then state.enemies = {}; return end
    local results = {}
    local seen = {}
    for i = 0, math.min(n - 1, 150) do
        pcall(function()
            local comp = comps:call("get_Item", i)
            if not comp then return end
            local addr = comp:get_address()
            if seen[addr] then return end
            seen[addr] = true

            local go = comp:call("get_GameObject")
            if not go then return end

            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if not pos then return end

            local go_name = tostring(go:call("get_Name") or "?")
            local go_guid = extract_guid(go)
            local context_guid = extract_context_guid(comp)

            local kind_id = nil
            pcall(function() kind_id = to_int(comp:call("get_KindID")) end)
            local map_id = nil
            pcall(function() map_id = to_int(comp:call("get_AssignMapID")) end)

            local hp = get_enemy_hp(go)
            local dead = hp ~= nil and hp <= 0

            local bt_state = get_bt_state(go)

            local rot = nil
            pcall(function()
                local q = xf:call("get_Rotation")
                if q then rot = { x = q.x, y = q.y, z = q.z } end
            end)

            local enemy_type = get_enemy_context_type(go)

            local d = dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos)

            results[#results + 1] = {
                go_name      = go_name,
                go_guid      = go_guid,
                context_guid = context_guid,
                guid         = context_guid or go_guid,
                kind_id      = kind_id,
                kind_name    = kind_name(kind_id),
                map_id       = map_id,
                hp           = hp,
                dead         = dead,
                bt_state     = bt_state,
                pos          = { x = pos.x, y = pos.y, z = pos.z },
                rot          = rot,
                enemy_type   = enemy_type,
                dist         = d,
            }
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.enemies = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawn Group Scanning (EnemySpawnController)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_spawn_groups()
    local scene = get_scene()
    local scene_addr = 0
    pcall(function() scene_addr = scene and scene:get_address() or 0 end)
    if state.spawn_scene_address ~= scene_addr then
        state.spawn_scene_address = scene_addr
    end

    local comps, n = find_comps("offline.EnemySpawnController")
    if not comps or n <= 0 then state.spawn_groups = {}; return end

    local results = {}
    local seen = {}
    for i = 0, n - 1 do
        pcall(function()
            local esc = comps:call("get_Item", i)
            if not esc then return end
            local addr = esc:get_address()
            if seen[addr] then return end
            seen[addr] = true

            local go = esc:call("get_GameObject")
            if not go then return end

            local go_name = tostring(go:call("get_Name") or "?")
            local go_guid = extract_guid(go)

            local is_spawned = false
            local is_vanished = false
            local all_dead = false
            local enabled_difficulty = false
            local enabled_map = false
            local init_difficulty = nil

            pcall(function() is_spawned      = esc:call("get_IsSpawned") == true end)
            pcall(function() is_vanished     = esc:call("get_IsVanished") == true end)
            pcall(function() all_dead        = esc:call("get_AllDead") == true end)
            pcall(function() enabled_difficulty = esc:call("get_EnabledDifficulty") == true end)
            pcall(function() enabled_map     = esc:call("get_EnabledMapID") == true end)
            pcall(function() init_difficulty = to_int(esc:get_field("InitializeSetDifficulty")) end)

            local pos = nil
            pcall(function()
                local xf = go:call("get_Transform")
                if xf then pos = xf:call("get_Position") end
            end)

            local d = pos and dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos) or 0
            local bt_state = get_bt_state(go)

            results[#results + 1] = {
                go_name          = go_name,
                go_guid          = go_guid,
                is_spawned       = is_spawned,
                is_vanished      = is_vanished,
                all_dead         = all_dead,
                enabled_difficulty = enabled_difficulty,
                enabled_map      = enabled_map,
                init_difficulty  = init_difficulty,
                bt_state         = bt_state,
                pos              = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
                dist             = d,
            }
        end)
    end

    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.spawn_groups = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Scanning (SetItem + HandHeldItem)
-- ═══════════════════════════════════════════════════════════════════════════

local ITEM_TYPES = {
    "offline.gimmick.action.SetItem",
    "offline.HandHeldItem",
}

local function scan_items()
    local results = {}
    local seen = {}
    for _, type_name in ipairs(ITEM_TYPES) do
        pcall(function()
            local comps, n = find_comps(type_name)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n - 1, 150) do
                pcall(function()
                    local comp = comps:call("get_Item", i)
                    if not comp then return end
                    local addr = comp:get_address()
                    if seen[addr] then return end
                    seen[addr] = true

                    local go = comp:call("get_GameObject")
                    if not go then return end
                    local xf = go:call("get_Transform")
                    if not xf then return end
                    local pos = xf:call("get_Position")
                    if not pos then return end

                    local go_name = tostring(go:call("get_Name") or "?")
                    local go_guid = extract_guid(go)

                    local bullet_id   = nil
                    local add_item_id = nil
                    local add_wpn_id  = nil
                    local pos_guid    = nil

                    pcall(function() bullet_id   = to_int(comp:get_field("BulletId")) end)
                    pcall(function() add_item_id = to_int(comp:get_field("AdditionalItemId")) end)
                    pcall(function() add_wpn_id  = to_int(comp:get_field("AdditionalWeaponId")) end)
                    pcall(function()
                        local pg = comp:get_field("ItemPositionGuid")
                        if pg then
                            local ok, ts = pcall(pg.call, pg, "ToString()")
                            if ok and ts then pos_guid = tostring(ts) end
                        end
                    end)

                    local d = dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos)

                    results[#results + 1] = {
                        go_name      = go_name,
                        go_guid      = go_guid,
                        bullet_id    = bullet_id,
                        add_item_id  = add_item_id,
                        add_wpn_id   = add_wpn_id,
                        pos_guid     = pos_guid,
                        pos          = { x = pos.x, y = pos.y, z = pos.z },
                        dist         = d,
                        type_name    = type_name,
                    }
                end)
            end
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.items = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- All-Objects Scanning (via.Transform = one per GO)
-- ═══════════════════════════════════════════════════════════════════════════

local _KNOWN_COMP_TYPES = nil
local function get_known_comp_types()
    if _KNOWN_COMP_TYPES then return _KNOWN_COMP_TYPES end
    local defs = {
        { tag = "Enemy",    type = "offline.EnemyController"          },
        { tag = "Spawn",    type = "offline.EnemySpawnController"     },
        { tag = "Item",     type = "offline.gimmick.action.SetItem"   },
        { tag = "Scenario", type = "offline.ScenarioController"       },
        { tag = "HP",       type = "offline.HitPointController"       },
        { tag = "Motion",   type = "via.motion.Motion"                },
    }
    for _, d in ipairs(defs) do
        local td = sdk.find_type_definition(d.type)
        d.rt = td and td:get_runtime_type()
    end
    _KNOWN_COMP_TYPES = defs
    return defs
end

local _xf_rt = nil
local function get_xf_rt()
    if not _xf_rt then
        local td = sdk.find_type_definition("via.Transform")
        _xf_rt = td and td:get_runtime_type()
    end
    return _xf_rt
end

local _obj_filter           = ""   -- filter for Objects tab table
local _go_inspector_filter  = ""   -- filter for GO inspector field names

local function scan_all_objects()
    local scene = get_scene()
    if not scene then state.objects = {}; return end
    local rt = get_xf_rt()
    if not rt then state.objects = {}; return end

    local all = nil
    pcall(function() all = scene:call("findComponents(System.Type)", rt) end)
    if not all then state.objects = {}; return end
    local total = all:call("get_Count") or 0

    local known = get_known_comp_types()
    local results = {}
    -- first pass: position + distance for all, then take 300 closest
    local raw = {}
    for i = 0, total - 1 do
        pcall(function()
            local xf  = all:call("get_Item", i)
            local go  = xf and xf:call("get_GameObject")
            if not go then return end
            local pos = xf:call("get_Position")
            local d   = pos and dist3({ x=pos.x, y=pos.y, z=pos.z }, state.player_pos) or 999999
            raw[#raw+1] = { xf=xf, go=go, d=d }
        end)
    end
    table.sort(raw, function(a, b) return a.d < b.d end)

    local limit = math.min(#raw, 300)
    for i = 1, limit do
        pcall(function()
            local r   = raw[i]
            local go  = r.go
            local name = tostring(go:call("get_Name") or "")
            local guid = extract_guid(go)
            local active = false
            pcall(function() active = go:call("get_ActiveSelf") == true end)
            local pos  = r.xf:call("get_Position")

            local tags = {}
            for _, k in ipairs(known) do
                if k.rt then
                    local c = nil
                    pcall(function() c = go:call("getComponent(System.Type)", k.rt) end)
                    if c then tags[#tags+1] = k.tag end
                end
            end

            results[#results+1] = {
                go_name = name,
                go_guid = guid,
                active  = active,
                pos     = pos and { x=pos.x, y=pos.y, z=pos.z } or nil,
                dist    = r.d,
                tags    = tags,
                _go_ref = go,
            }
        end)
    end
    state.objects = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Progress (RE3R level-flow equivalent via SSM)
-- ═══════════════════════════════════════════════════════════════════════════

-- _prog_entries: sorted list of { name, value=scenario_no, bt_state,
--                                  is_cur, is_done, is_adv, go_name, changed_at }
local _prog_entries          = {}
local _catalog_found         = false   -- true when SSM accessible
local _current_scenario_no   = nil     -- SSM._CurrentScenarioNo

local rebuild_prog_entries  -- forward declaration

-- Full scan: read SSM directly + resolve all controller data
local function scan_levelflow_catalog()
    _catalog_found = false
    pcall(function()
        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end
        _catalog_found = true

        local cn = nil
        pcall(function() cn = to_int(ssm:get_field("_CurrentScenarioNo")) end)
        if cn ~= nil then _current_scenario_no = cn end

        -- collect all controllers with a valid ScenarioNo
        local cl = ssm:get_field("_ScenarioControllerList")
        if not cl then return end
        local n = 0; pcall(function() n = cl:call("get_Count") or 0 end)

        local entries = {}
        for i = 0, n - 1 do
            pcall(function()
                local ctrl = cl:call("get_Item", i)
                if not ctrl then return end
                local sno = nil
                pcall(function() sno = to_int(ctrl:get_field("ScenarioNo")) end)
                if not sno or sno < 0 then return end

                local adv = false
                pcall(function() adv = ctrl:get_field("IsAdvanceNo") == true end)

                local go = ctrl:call("get_GameObject")
                local bt = get_bt_state(go) or "-"
                local go_name = ""
                pcall(function() go_name = tostring(go:call("get_Name") or "") end)

                local s_name = SCENARIO_NAMES[sno] or string.format("S??_%04d", sno)
                local is_done = bt:lower():find("suicide") ~= nil

                entries[#entries + 1] = {
                    name       = s_name,
                    value      = sno,
                    bt_state   = bt,
                    is_cur     = sno == _current_scenario_no,
                    is_done    = is_done,
                    is_adv     = adv,
                    go_name    = go_name,
                    changed_at = 0,
                }
            end)
        end
        table.sort(entries, function(a, b) return (a.value or 0) < (b.value or 0) end)
        _prog_entries = entries
    end)
end

-- Fast refresh: update BT states + current scenario from already-scanned state.scenarios
local function scan_levelflow_values()
    -- Update current scenario no from SSM (cheap)
    pcall(function()
        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end
        local cn = nil
        pcall(function() cn = to_int(ssm:get_field("_CurrentScenarioNo")) end)
        if cn ~= nil then _current_scenario_no = cn end
    end)
    rebuild_prog_entries()
end

-- Rebuild _prog_entries from the already-populated state.scenarios (fast path)
rebuild_prog_entries = function()
    if not _catalog_found then return end
    local entries = {}
    for _, sc in ipairs(state.scenarios) do
        if sc.scenario_no and sc.scenario_no >= 0 then
            local s_name  = SCENARIO_NAMES[sc.scenario_no] or string.format("S??_%04d", sc.scenario_no)
            local bt      = sc.bt_state or "-"
            local is_done = bt:lower():find("suicide") ~= nil
            entries[#entries + 1] = {
                name       = s_name,
                value      = sc.scenario_no,
                bt_state   = bt,
                is_cur     = sc.scenario_no == _current_scenario_no,
                is_done    = is_done,
                is_adv     = sc.is_advance,
                go_name    = sc.go_name,
                changed_at = sc.changed_at,
            }
        end
    end
    table.sort(entries, function(a, b) return (a.value or 0) < (b.value or 0) end)
    _prog_entries = entries
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Overlay Fonts
-- ═══════════════════════════════════════════════════════════════════════════

local _overlay_font_regular = nil
local _overlay_font_bold    = nil

local function get_overlay_font(bold)
    if not d2d then return nil end
    if bold then
        if not _overlay_font_bold then
            pcall(function() _overlay_font_bold = d2d.Font.new("Consolas", 18, true) end)
        end
        return _overlay_font_bold
    end
    if not _overlay_font_regular then
        pcall(function() _overlay_font_regular = d2d.Font.new("Consolas", 18, false) end)
    end
    return _overlay_font_regular
end

local function reset_overlay_fonts()
    _overlay_font_regular = nil
    _overlay_font_bold    = nil
end

-- ── ESP fonts (configurable size) ─────────────────────────────────────────

local _esp_fonts = {}

local function get_esp_font(sz, bold)
    local key = tostring(sz) .. (bold and "B" or "R")
    if not _esp_fonts[key] then
        pcall(function() _esp_fonts[key] = d2d.Font.new("Consolas", sz, bold or false) end)
    end
    return _esp_fonts[key]
end

local function reset_esp_fonts()
    _esp_fonts = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- D2D Draw Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local function d2d_text(font, text, x, y, col)
    if d2d and font then
        pcall(d2d.text, font, text, x + 1, y + 1, 0xCC000000)
        pcall(d2d.text, font, text, x, y, col)
    elseif draw then
        pcall(draw.text, text, x + 1, y + 1, 0xCC000000)
        pcall(draw.text, text, x, y, col)
    end
end

local function d2d_fill_rect(x, y, w, h, col)
    if d2d then
        pcall(d2d.fill_rect, x, y, w, h, col)
    elseif draw then
        pcall(draw.filled_rect, x, y, w, h, col)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- World-to-Screen
-- ═══════════════════════════════════════════════════════════════════════════

local _has_w2s = (draw ~= nil) and (draw.world_to_screen ~= nil)

local function world_to_screen(pos, y_off)
    if not _has_w2s or not pos then return nil end
    local ok, sp = pcall(draw.world_to_screen,
        Vector3f.new(pos.x, pos.y + (y_off or 0), pos.z))
    if not ok or not sp then return nil end
    if sp.x ~= sp.x or sp.y ~= sp.y then return nil end
    return sp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dev Overlay (top-left panel)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_dev_overlay()
    if not cfg.show_dev_overlay then return end

    local LH      = 20
    local PAD     = 14   -- matches spawn overlay padding
    local VX      = 92   -- value column offset from content left
    local PANEL_W = 420
    local DIV_H   = 9
    local TITLE_H = LH + 4

    local lime   = 0xFF44FF88
    local cyan   = 0xFF88DDFF
    local yellow = 0xFFFFCC44
    local grey   = 0xFF888888
    local white  = 0xFFFFFFFF
    local dkgrey = 0xFF888888

    local hf = get_overlay_font(true)
    local vf = get_overlay_font(false)

    -- Row builders (div() skips consecutive dividers and leading/trailing ones)
    local rows = {}
    local function kv(label, value, val_col)
        local vs = tostring(value ~= nil and value or "")
        if vs == "" or vs == "nil" then return end
        rows[#rows+1] = { t="kv", label=label, value=vs, vcol=val_col or white }
    end
    local function div()
        if #rows > 0 and rows[#rows].t ~= "div" then
            rows[#rows+1] = { t="div" }
        end
    end

    -- ── Section 1: Player ────────────────────────────────────────────────────
    if state.dev.player_name ~= "" then
        kv("Player", state.dev.player_name, cyan)
    end
    if state.player_hp and state.player_hp > 0 then
        local hp  = state.player_hp
        local hpc = hp > 500 and 0xFF44FF88 or (hp > 200 and 0xFFFFAA44 or 0xFFFF5555)
        kv("HP", math.floor(hp), hpc)
    end
    if state.dev.player_state ~= "" then
        kv("State", state.dev.player_state, 0xFFAABBCC)
    end

    -- ── Section 2: World ─────────────────────────────────────────────────────
    div()
    if state.dev.scene ~= "" then kv("Scene", state.dev.scene, yellow) end
    kv("Map ID", map_id_str(state.dev.map_id), white)
    if state.dev.rank ~= nil then kv("Rank", state.dev.rank, cyan) end
    if state.dev.playtime and state.dev.playtime > 0 then
        local t = math.floor(state.dev.playtime)
        kv("Time", string.format("%d:%02d", t // 60, t % 60), white)
    end

    -- ── Section 3: Transform ─────────────────────────────────────────────────
    div()
    local pos = state.player_pos
    if pos then
        kv("X", string.format("%.3f", pos.x), white)
        kv("Y", string.format("%.3f", pos.y), white)
        kv("Z", string.format("%.3f", pos.z), white)
    else
        kv("Pos", "(unavailable)", dkgrey)
    end
    if state.dev_rotation then
        kv("Yaw", string.format("%.1f\xC2\xB0", state.dev_rotation), white)
    end

    -- ── Section 4: Counts ────────────────────────────────────────────────────
    div()
    kv("Enemies", #state.enemies, white)
    kv("Items",   #state.items,   white)
    kv("Spawns",  #state.spawn_groups, white)

    -- ── Status flash ─────────────────────────────────────────────────────────
    if state.status_msg ~= "" and state.tick < state.status_until then
        div()
        kv(">>", state.status_msg, lime)
    end

    -- Remove trailing divider
    if #rows > 0 and rows[#rows].t == "div" then rows[#rows] = nil end

    -- Calculate panel height
    local total_h = 6 + TITLE_H
    for _, r in ipairs(rows) do
        total_h = total_h + (r.t == "div" and DIV_H or LH)
    end
    total_h = total_h + PAD

    local x = 30   -- matches spawn overlay left margin
    local y = 80   -- matches spawn overlay top margin

    -- Background + 4 px left accent bar
    d2d_fill_rect(x, y, PANEL_W, total_h, 0xCC000000)
    d2d_fill_rect(x, y, 4, total_h, lime)

    -- Content origin (matches spawn overlay: x + PAD)
    local cx = x + PAD
    local ty = y + 6   -- matches spawn overlay title offset

    -- Title
    d2d_text(hf, "BIORAND RE3R", cx, ty, lime)
    ty = ty + TITLE_H

    for _, r in ipairs(rows) do
        if r.t == "div" then
            d2d_fill_rect(cx, ty + DIV_H // 2, PANEL_W - PAD * 2, 1, 0xFF2A2A2A)
            ty = ty + DIV_H
        else
            d2d_text(vf, r.label,        cx,      ty, grey)
            d2d_text(vf, r.value,        cx + VX, ty, r.vcol)
            ty = ty + LH
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Spawn Overlay (top-right panel)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_spawn_overlay()
    if not cfg.show_spawn_overlay then return end

    local entries = state.spawn_groups
    if not entries or #entries == 0 then return end

    local visible = math.min(#entries, SPAWN_OVERLAY_LIMIT)

    local spawned_count, vanished_count, dead_count = 0, 0, 0
    for _, e in ipairs(entries) do
        if e.is_spawned  then spawned_count  = spawned_count  + 1 end
        if e.is_vanished then vanished_count = vanished_count + 1 end
        if e.all_dead    then dead_count     = dead_count     + 1 end
    end

    -- Fixed pixel column offsets (relative to panel content left = x + PAD)
    -- Name col needs ~260px for 31-char names at ~8px/char in draw font
    local PAD   = 14
    local CX    = { dist=0, name=42, sp=308, va=340, dd=372, df=404, state=436 }
    local PANEL_W = 700
    local LH    = 20  -- row height in px

    local lime  = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey  = 0xFF888888
    local hf    = get_overlay_font(true)
    local vf    = get_overlay_font(false)

    -- Build rows
    local rows = {}
    for i = 1, visible do
        local e = entries[i]
        local col
        if e.all_dead        then col = 0xFFFF5555
        elseif e.is_vanished then col = 0xFFCC88FF
        elseif e.is_spawned  then col = 0xFF44FF88
        else                      col = 0xFFFFFFFF end
        rows[#rows + 1] = {
            dist  = string.format("%dm", math.floor(e.dist + 0.5)),
            name  = clamp_text(e.go_name, SPAWN_NAME_MAX_CHARS),
            sp    = e.is_spawned        and "Y" or "N",
            va    = e.is_vanished       and "Y" or "N",
            dd    = e.all_dead          and "Y" or "N",
            df    = e.enabled_difficulty and "Y" or "N",
            state = e.bt_state or "-",
            col   = col,
        }
    end

    -- Panel geometry
    local header_h = LH * 3 + 10  -- title + summary + col header
    local height   = header_h + (#rows * LH) + 12
    local x, y    = 30, 80

    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
        if sz.h and (y + height + 30) > sz.h then
            y = math.max(30, sz.h - height - 30)
        end
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, lime)

    -- Title
    local cy = y + 6
    d2d_text(hf, "Enemy Spawns", x + PAD, cy, lime)
    cy = cy + LH

    -- Summary
    local summary = string.format(
        "total:%d  spawned:%d  vanished:%d  dead:%d",
        #entries, spawned_count, vanished_count, dead_count)
    d2d_text(vf, summary, x + PAD, cy, grey)
    cy = cy + LH

    -- Column headers
    local cx = x + PAD
    d2d_text(vf, "Dist",  cx + CX.dist,  cy, grey)
    d2d_text(vf, "Name",  cx + CX.name,  cy, grey)
    d2d_text(vf, "Sp",    cx + CX.sp,    cy, grey)
    d2d_text(vf, "Va",    cx + CX.va,    cy, grey)
    d2d_text(vf, "Dd",    cx + CX.dd,    cy, grey)
    d2d_text(vf, "Df",    cx + CX.df,    cy, grey)
    d2d_text(vf, "State", cx + CX.state, cy, grey)
    cy = cy + LH + 2

    -- Data rows
    for _, row in ipairs(rows) do
        local c = row.col
        d2d_text(vf, row.dist,  cx + CX.dist,  cy, grey)
        d2d_text(vf, row.name,  cx + CX.name,  cy, c)
        d2d_text(vf, row.sp,    cx + CX.sp,    cy, c)
        d2d_text(vf, row.va,    cx + CX.va,    cy, c)
        d2d_text(vf, row.dd,    cx + CX.dd,    cy, c)
        d2d_text(vf, row.df,    cx + CX.df,    cy, c)
        d2d_text(vf, row.state, cx + CX.state, cy, c)
        cy = cy + LH
    end

    return height + 10  -- consumed height for stacking the levelflow overlay below
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlow Overlay (right side, below spawn overlay)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_levelflow_overlay(offset_y)
    if not cfg.show_levelflow_overlay then return end

    local items = state.scenarios
    if not items or #items == 0 then return end

    local now = os.clock()

    -- Fixed pixel column offsets
    -- Name col needs ~265px for 32-char names at ~8px/char in draw font
    local PAD      = 14
    local CX_NAME  = 0
    local CX_STATE = 270
    local PANEL_W  = 520
    local LH      = 20

    local lime  = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey  = 0xFF888888
    local hf    = get_overlay_font(true)
    local vf    = get_overlay_font(false)

    local height = LH * 2 + 10 + (#items * LH)
    local x, y  = 30, 80 + (offset_y or 0)

    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, lime)

    local cy = y + 6
    d2d_text(hf, "Active Scenarios", x + PAD, cy, lime)
    cy = cy + LH

    -- Column headers
    local cx = x + PAD
    d2d_text(vf, "Name",  cx + CX_NAME,  cy, grey)
    d2d_text(vf, "State", cx + CX_STATE, cy, grey)
    cy = cy + LH + 2

    for _, item in ipairs(items) do
        local changed_recently = item.changed_at > 0 and
            ((now - item.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
        local col = changed_recently and lime or white
        local display_name = (item.scenario_no and item.scenario_no >= 0 and SCENARIO_NAMES[item.scenario_no])
            or item.go_name
        d2d_text(vf, clamp_text(display_name, LEVELFLOW_NAME_MAX_CHARS), cx + CX_NAME,  cy, col)
        d2d_text(vf, tostring(item.bt_state or "-"),                      cx + CX_STATE, cy, col)
        cy = cy + LH
    end

    return height + 10  -- consumed height for stacking below
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlow Catalog Overlay (right side, below other right-side overlays)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_levelflow_catalog_overlay(offset_y)
    if not cfg.show_levelflow_catalog_overlay then return end
    if not _catalog_found then return end

    local PAD     = 14
    local CX_BT   = 220   -- bt_state column offset from content left
    local PANEL_W = 420
    local LH      = 20

    local cyan   = 0xFF44EEFF
    local grey   = 0xFF888888
    local lime   = 0xFF44FF88
    local white  = 0xFFFFFFFF
    local dkgrey = 0xFF444444
    local yellow = 0xFFFFDD44

    local hf = get_overlay_font(true)
    local vf = get_overlay_font(false)

    local visible = math.min(#_prog_entries, 20)
    local height  = LH * 2 + 10 + (visible * LH) + 8

    local x, y = 30, 80 + (offset_y or 0)
    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, cyan)

    local cy = y + 6
    local cx = x + PAD

    -- Title + current scenario on same line
    local cur_label = _current_scenario_no ~= nil
        and (SCENARIO_NAMES[_current_scenario_no] or string.format("S??_%04d", _current_scenario_no))
        or "?"
    d2d_text(hf, "Scenario Progress", cx, cy, cyan)
    d2d_text(hf, cur_label, cx + CX_BT, cy, yellow)
    cy = cy + LH

    -- Column headers
    d2d_text(vf, "Scenario",   cx,          cy, grey)
    d2d_text(vf, "BT State",   cx + CX_BT,  cy, grey)
    cy = cy + LH + 2

    for i = 1, visible do
        local e = _prog_entries[i]

        local name_col, bt_col
        local prefix = "  "

        if e.is_cur then
            name_col = lime
            bt_col   = lime
            prefix   = "> "
        elseif e.is_done then
            name_col = dkgrey
            bt_col   = dkgrey
        else
            name_col = white
            bt_col   = grey
        end

        local bt_short = e.bt_state or "-"
        -- Shorten long BT state names for readability
        bt_short = bt_short:gsub("^app%.levelflow%.", "")

        d2d_text(vf, prefix .. clamp_text(e.name or "?", 26), cx,         cy, name_col)
        d2d_text(vf, clamp_text(bt_short, 18),                cx + CX_BT, cy, bt_col)
        cy = cy + LH
    end

    if #_prog_entries > visible then
        d2d_text(vf, string.format("  ... +%d more", #_prog_entries - visible), cx, cy, grey)
    end

    return height + 10
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ESP Rendering (world-space labels)
-- ═══════════════════════════════════════════════════════════════════════════

local function render_esp_enemies()
    if not cfg.show_enemy_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    -- Determine selected enemy id for highlight
    local sel_id = state.sel_type == "enemy" and state.sel_data and
                   (state.sel_data.guid or state.sel_data.go_guid)

    for _, e in ipairs(state.enemies) do
        if e.dist > cfg.enemy_esp_range then break end
        if cfg.hide_dead and e.dead then goto next_e end
        if not e.pos then goto next_e end

        local sp = world_to_screen(e.pos, 1.8)
        if sp then
            local is_selected = sel_id and sel_id ~= false and
                                (e.guid == sel_id or e.go_guid == sel_id)

            local name_col = is_selected and 0xFFFFFF44 or cfg.col_enemy_name
            local lines = {
                { text = e.go_name or "?",            col = name_col },
                { text = e.guid or "",                col = 0xFF44EEFF },
                { text = e.kind_name,                 col = 0xFFCCCCCC },
                { text = string.format("%.1fm", e.dist), col = 0xFFAAAAAA },
                { text = map_id_str(e.map_id),        col = 0xFF666666 },
            }
            if e.hp then
                local hp_col = e.hp > 200 and 0xFF55FF88 or (e.hp > 50 and 0xFFFFAA44 or 0xFFFF5555)
                table.insert(lines, 3, { text = string.format("HP %d", math.floor(e.hp)), col = hp_col })
            end

            -- Compute background dimensions
            local total_h = #lines * lh
            local max_w   = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * cfg.font_size * 0.52
                if w > max_w then max_w = w end
            end

            local draw_y = sp.y - total_h
            local bx     = sp.x - max_w * 0.5 - 4
            local by     = draw_y - 2

            -- Semi-transparent background
            d2d_fill_rect(bx, by, max_w + 8, total_h + 4, 0xAA000000)

            -- Yellow outline if selected (4 border strips, 2px wide)
            if is_selected then
                local bw = max_w + 8
                local bh = total_h + 4
                d2d_fill_rect(bx,          by,          bw, 2,  0xFFFFFF44) -- top
                d2d_fill_rect(bx,          by + bh - 2, bw, 2,  0xFFFFFF44) -- bottom
                d2d_fill_rect(bx,          by,          2,  bh, 0xFFFFFF44) -- left
                d2d_fill_rect(bx + bw - 2, by,          2,  bh, 0xFFFFFF44) -- right
            end

            -- Draw label lines
            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw * 0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end

            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFFFF5555)
        end
        ::next_e::
    end
end

local function render_esp_items()
    if not cfg.show_item_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    for _, item in ipairs(state.items) do
        if item.dist > cfg.item_esp_range then break end
        if not item.pos then goto next_i end

        local sp = world_to_screen(item.pos, 0.5)
        if sp then
            local lines = {
                { text = item.go_name or "?",          col = cfg.col_item_name },
                { text = item.go_guid or "",           col = 0xFF44EEFF },
                { text = string.format("%.1fm", item.dist), col = 0xFFAAAAAA },
            }
            local draw_y = sp.y - #lines * lh
            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw * 0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFF55FF99)
        end
        ::next_i::
    end
end

local function render_esp_objects()
    if not cfg.show_object_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    for _, obj in ipairs(state.objects) do
        if obj.dist > cfg.object_esp_range then break end
        if cfg.object_esp_only_tagged and #obj.tags == 0 then goto next_obj end
        if not obj.pos then goto next_obj end

        local sp = world_to_screen(obj.pos, 0.0)
        if sp then
            local tag_str = #obj.tags > 0 and ("[" .. table.concat(obj.tags, " ") .. "]") or ""
            local name_col = obj.active and cfg.col_object_name or 0xFF888888
            local lines = {
                { text = obj.go_name or "?", col = name_col },
            }
            if tag_str ~= "" then
                table.insert(lines, 2, { text = tag_str, col = 0xFF88FFCC })
            end
            table.insert(lines, { text = string.format("%.1fm", obj.dist), col = 0xFFAAAAAA })

            local draw_y = sp.y - #lines * lh
            local max_w  = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * cfg.font_size * 0.52
                if w > max_w then max_w = w end
            end

            d2d_fill_rect(sp.x - max_w*0.5 - 4, draw_y - 2, max_w + 8, #lines*lh + 4, 0xAA000000)

            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw*0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFFFFCC88)
        end
        ::next_obj::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- D2D Registration
-- ═══════════════════════════════════════════════════════════════════════════

if d2d then
    d2d.register(
        function()
            -- reset callback: fonts are invalidated
            reset_overlay_fonts()
            reset_esp_fonts()
        end,
        function()
            -- Each right-side overlay returns its height so the next stacks below
            local spawn_height = 0
            pcall(function() spawn_height = draw_spawn_overlay() or 0 end)
            local lf_height = 0
            pcall(function() lf_height = draw_levelflow_overlay(spawn_height) or 0 end)
            pcall(function() draw_levelflow_catalog_overlay(spawn_height + lf_height) end)
            pcall(draw_dev_overlay)
            pcall(render_esp_enemies)
            pcall(render_esp_items)
            pcall(render_esp_objects)
            pcall(render_selected_go_highlight)
        end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- B Key — Export enemies to CSV
-- ═══════════════════════════════════════════════════════════════════════════

local CSV_PATH = "reframework/data/extra_enemies.csv"

local function export_enemies_csv()
    local path   = CSV_PATH
    local exists = io.open(path, "r")
    if exists then exists:close() end

    local f = io.open(path, "a")
    if not f then
        state.status_msg   = "CSV write failed: " .. path
        state.status_until = state.tick + 240
        return
    end

    if not exists then
        f:write("GUID,Name,EnemyType,MapID,X,Y,Z,RX,RY,RZ,HasDropData,Tags,Exclude\n")
    end

    local map_id  = tostring(state.dev.map_id or 0)
    local written = 0
    for _, e in ipairs(state.enemies) do
        if e.dist <= cfg.enemy_esp_range then
            local guid  = e.context_guid or e.go_guid or "00000000-0000-0000-0000-000000000000"
            local x     = e.pos and string.format("%.3f", e.pos.x) or "0.000"
            local y     = e.pos and string.format("%.3f", e.pos.y) or "0.000"
            local z     = e.pos and string.format("%.3f", e.pos.z) or "0.000"
            local rx    = e.rot and string.format("%.3f", e.rot.x) or "0.000"
            local ry    = e.rot and string.format("%.3f", e.rot.y) or "0.000"
            local rz    = e.rot and string.format("%.3f", e.rot.z) or "0.000"
            local etype = e.enemy_type or ""
            f:write(string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,FALSE,,\n",
                guid, e.go_name or "unknown", etype,
                map_id, x, y, z, rx, ry, rz))
            written = written + 1
        end
    end
    f:close()

    state.status_msg   = string.format("[B] Exported %d enemies", written)
    state.status_until = state.tick + 240
    log.info("[RE3R Trainer] " .. state.status_msg)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Selected GO World Highlight (capsule drawn at selected GO's live position)
-- ═══════════════════════════════════════════════════════════════════════════

local function render_selected_go_highlight()
    if not cfg.go_highlight_selected then return end
    if state.sel_type ~= "go" then return end
    local data = state.sel_data
    if not data then return end

    -- Prefer live transform position over cached
    local pos = nil
    local go  = data._go_ref
    if go then
        pcall(function()
            local xf = go:call("get_Transform")
            if xf then
                local p = xf:call("get_Position")
                if p then pos = p end
            end
        end)
    end
    if not pos and data.pos then
        pos = Vector3f.new(data.pos.x, data.pos.y, data.pos.z)
    end
    if not pos then return end

    local col_cap  = 0xFFFFFF44  -- yellow capsule
    local col_text = 0xFFFFFF44

    -- Capsule: position is center; offset up so it straddles the transform point
    local cap_center = Vector3f.new(pos.x, pos.y + 0.9, pos.z)
    pcall(draw.capsule, cap_center, 0.35, 1.8, col_cap)

    -- World-space label above the capsule
    local label_pos = Vector3f.new(pos.x, pos.y + 2.4, pos.z)
    pcall(draw.world_text, data.go_name or "?", label_pos, col_text)

    -- Small sphere at the transform origin so we know exactly where it is
    pcall(draw.sphere, pos, 0.06, 0xFFFF4444)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Main Frame Loop
-- ═══════════════════════════════════════════════════════════════════════════

local _b_was_down = false

re.on_frame(function()
    state.tick = state.tick + 1

    -- Every 10 ticks: player pos, HP, camera yaw
    if state.tick % 10 == 0 then
        pcall(update_player_pos)
        pcall(update_player_hp)
        pcall(update_camera_rotation)
    end

    -- Every 60 ticks: screen size, game state, scenarios
    if state.tick % 60 == 1 then
        pcall(update_screen_size)
        pcall(scan_game_state)
        pcall(scan_scenarios)
    end

    -- Every scan_interval ticks: enemies, items
    if state.tick % cfg.scan_interval == 0 then
        pcall(scan_enemies)
        pcall(scan_items)
    end

    -- Every scan_interval*2 ticks: spawn groups
    if state.tick % (cfg.scan_interval * 2) == 5 then
        pcall(scan_spawn_groups)
    end

    -- Every 150 ticks: all-objects scan (via.Transform, 300 closest)
    if state.tick % 150 == 7 then
        pcall(scan_all_objects)
    end

    -- Every 300 ticks (~5 s): re-discover level flow catalog (slow, component scan)
    if state.tick % 300 == 23 then
        pcall(scan_levelflow_catalog)
    end

    -- Every 90 ticks (~1.5 s): refresh current progress values from manager
    if state.tick % 90 == 29 then
        pcall(scan_levelflow_values)
    end

    -- B key: rising-edge export
    local b_down = reframework:is_key_down(0x42)
    if b_down and not _b_was_down then
        pcall(export_enemies_csv)
    end
    _b_was_down = b_down

    -- Fallback rendering if d2d not available (RE3R has no d2d support)
    if draw and not d2d then
        local spawn_height = 0
        pcall(function() spawn_height = draw_spawn_overlay() or 0 end)
        local lf_height = 0
        pcall(function() lf_height = draw_levelflow_overlay(spawn_height) or 0 end)
        pcall(function() draw_levelflow_catalog_overlay(spawn_height + lf_height) end)
        pcall(draw_dev_overlay)
        pcall(render_esp_enemies)
        pcall(render_esp_items)
        pcall(render_esp_objects)
        pcall(render_selected_go_highlight)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Helpers
-- ═══════════════════════════════════════════════════════════════════════════

-- REFramework imgui uses ABGR; our colors are ARGB. Convert before imgui calls.
local function to_imgui(c)
    return (c & 0xFF000000)
        | ((c & 0x000000FF) << 16)
        | (c  & 0x0000FF00)
        | ((c >> 16) & 0xFF)
end

local function colored_header(text, col)
    imgui.push_style_color(0, to_imgui(col or 0xFFFFDD88))
    imgui.separator()
    imgui.text(text)
    imgui.pop_style_color(1)
    imgui.spacing()
end

local function copy_btn(id, value)
    imgui.same_line()
    if imgui.button("Copy##" .. tostring(id)) then
        imgui.set_clipboard_text(value or "")
    end
end

local function label_row(tag, tag_col, value, key)
    imgui.text_colored(tag, to_imgui(tag_col or 0xFFE0E0E0))
    imgui.same_line()
    imgui.text(value or "")
    copy_btn(key, value)
end

local COLOR_PRESETS = {
    { "White",  0xFFFFFFFF },
    { "Red",    0xFFFF5555 },
    { "Green",  0xFF55FF99 },
    { "Yellow", 0xFFFFDD55 },
    { "Cyan",   0xFF44EEFF },
    { "Orange", 0xFFFFAA44 },
    { "Purple", 0xFFCC88FF },
    { "Blue",   0xFF88AAFF },
}

local function color_picker_row(label, config_key)
    imgui.text_colored(label, to_imgui(0xFFAAAAAA))
    for _, p in ipairs(COLOR_PRESETS) do
        imgui.same_line()
        local sel = (cfg[config_key] == p[2])
        imgui.push_style_color(0,  to_imgui(p[2]))
        imgui.push_style_color(21, sel and 0xFF2A3A2A or 0xFF1A1A2E)
        imgui.push_style_color(22, sel and 0xFF4A5A4A or 0xFF2A2A3E)
        if imgui.small_button(p[1] .. "##cp_" .. config_key) then
            cfg[config_key] = p[2]
        end
        imgui.pop_style_color(3)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Enemies
-- ═══════════════════════════════════════════════════════════════════════════

local select_obj  -- forward declaration; defined after all ui_* functions

local function ui_enemies()
    local ch
    ch, cfg.show_enemy_esp  = imgui.checkbox("Show Enemy ESP Overlay", cfg.show_enemy_esp)
    ch, cfg.enemy_esp_range = imgui.drag_float("Range (m)##er", cfg.enemy_esp_range, 0.5, 5, 200, "%.1f m")
    ch, cfg.hide_dead       = imgui.checkbox("Hide Dead Enemies", cfg.hide_dead)
    color_picker_row("Name Color:", "col_enemy_name")

    colored_header(string.format("Enemies — %d total", #state.enemies), 0xFFFFDD88)

    -- Table
    if imgui.begin_table("enemy_table", 8, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",     16, 28,  0)
        imgui.table_setup_column("Dist",  16, 56,  0)
        imgui.table_setup_column("Name",  0,  1,   0)
        imgui.table_setup_column("GUID",  16, 320, 0)
        imgui.table_setup_column("Kind",  16, 100, 0)
        imgui.table_setup_column("HP",    16, 70,  0)
        imgui.table_setup_column("State", 16, 120, 0)
        imgui.table_setup_column("Pos",   16, 200, 0)
        imgui.table_headers_row()

        for i, e in ipairs(state.enemies) do
            if cfg.hide_dead and e.dead then goto skip_en end
            imgui.table_next_row()

            local row_col = e.dead and to_imgui(0xFFFF5555) or to_imgui(0xFF44FF88)

            imgui.table_next_column()
            if imgui.small_button(">##sel_enemy_" .. i) then
                select_obj("enemy", e)
            end

            imgui.table_next_column()
            imgui.text_colored(string.format("%.0fm", e.dist), row_col)

            imgui.table_next_column()
            imgui.text_colored(e.go_name or "?", row_col)

            imgui.table_next_column()
            local guid_str = e.guid or ""
            imgui.push_item_width(310)
            imgui.input_text("##eguid_" .. i, guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##ec_" .. i) then
                imgui.set_clipboard_text(guid_str)
            end

            imgui.table_next_column()
            imgui.text_colored(e.kind_name, row_col)

            imgui.table_next_column()
            imgui.text_colored(e.hp and tostring(math.floor(e.hp)) or "-", row_col)

            imgui.table_next_column()
            imgui.text_colored(e.bt_state or "-", 0xFFDDDDDD)

            imgui.table_next_column()
            if e.pos then
                imgui.text(string.format("%.1f, %.1f, %.1f", e.pos.x, e.pos.y, e.pos.z))
            end

            ::skip_en::
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Spawn Groups
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_spawn_groups()
    local ch
    ch, cfg.show_spawn_overlay = imgui.checkbox("Show Spawn Overlay (D2D)", cfg.show_spawn_overlay)

    colored_header(string.format("Spawn Groups — %d total", #state.spawn_groups), 0xFFFFDD88)

    if imgui.begin_table("spawn_table", 9, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",       16, 28,  0)
        imgui.table_setup_column("Name",    0,  1,   0)
        imgui.table_setup_column("GO GUID", 16, 320, 0)
        imgui.table_setup_column("Spawned", 16, 70,  0)
        imgui.table_setup_column("Vanished",16, 70,  0)
        imgui.table_setup_column("AllDead", 16, 70,  0)
        imgui.table_setup_column("Diff",    16, 50,  0)
        imgui.table_setup_column("MapID",   16, 55,  0)
        imgui.table_setup_column("State",   16, 120, 0)
        imgui.table_headers_row()

        for i, sg in ipairs(state.spawn_groups) do
            imgui.table_next_row()

            local row_col
            if sg.all_dead    then row_col = to_imgui(0xFFFF5555)
            elseif sg.is_vanished then row_col = to_imgui(0xFFCC88FF)
            elseif sg.is_spawned  then row_col = to_imgui(0xFF44FF88)
            else                      row_col = to_imgui(0xFFCCCCCC) end

            imgui.table_next_column()
            if imgui.small_button(">##sel_spawn_" .. i) then
                select_obj("spawn", sg)
            end

            imgui.table_next_column()
            imgui.text_colored(sg.go_name or "?", row_col)

            imgui.table_next_column()
            local guid_str = sg.go_guid or ""
            imgui.push_item_width(310)
            imgui.input_text("##sgguid_" .. i, guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##sgc_" .. i) then
                imgui.set_clipboard_text(guid_str)
            end

            imgui.table_next_column()
            imgui.text_colored(sg.is_spawned  and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.is_vanished and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.all_dead    and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.enabled_difficulty and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.enabled_map and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.bt_state or "-", to_imgui(0xFFDDDDDD))
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Scenarios
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_scenarios()
    local ch
    ch, cfg.show_levelflow_overlay = imgui.checkbox("Show LevelFlow Overlay (D2D)", cfg.show_levelflow_overlay)

    colored_header(string.format("Scenario Controllers — %d", #state.scenarios), 0xFFFFDD88)

    local now = os.clock()
    if imgui.begin_table("scenario_table", 5, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",          16, 28,  0)
        imgui.table_setup_column("GO Name",    0,  1,   0)
        imgui.table_setup_column("BT State",   16, 130, 0)
        imgui.table_setup_column("IsAdvance",  16, 80,  0)
        imgui.table_setup_column("ScenarioNo", 16, 100, 0)
        imgui.table_headers_row()

        for i, sc in ipairs(state.scenarios) do
            imgui.table_next_row()

            local changed_recently = sc.changed_at > 0 and
                ((now - sc.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
            local row_col = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFCCCCCC)

            imgui.table_next_column()
            if imgui.small_button(">##sel_scenario_" .. i) then
                select_obj("scenario", sc)
            end

            imgui.table_next_column()
            imgui.text_colored(sc.go_name or "?", row_col)

            imgui.table_next_column()
            imgui.text_colored(sc.bt_state or "-", row_col)

            imgui.table_next_column()
            imgui.text_colored(sc.is_advance and "Y" or "N", row_col)

            imgui.table_next_column()
            local sno = sc.scenario_no
            local sno_str = sno and (tostring(sno) .. "  " .. (SCENARIO_NAMES[sno] or "")) or "-"
            imgui.text_colored(sno_str, row_col)
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Items
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_items()
    local ch
    ch, cfg.show_item_esp  = imgui.checkbox("Show Item ESP Overlay", cfg.show_item_esp)
    ch, cfg.item_esp_range = imgui.drag_float("Range (m)##ir", cfg.item_esp_range, 0.5, 5, 200, "%.1f m")
    color_picker_row("Name Color:", "col_item_name")

    colored_header(string.format("Items — %d total", #state.items), 0xFFFFDD88)

    if imgui.begin_table("item_table", 7, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",       16, 28,  0)
        imgui.table_setup_column("Dist",    16, 56,  0)
        imgui.table_setup_column("Name",    0,  1,   0)
        imgui.table_setup_column("GO GUID", 16, 320, 0)
        imgui.table_setup_column("BulletID",16, 80,  0)
        imgui.table_setup_column("ItemID",  16, 80,  0)
        imgui.table_setup_column("Pos",     16, 200, 0)
        imgui.table_headers_row()

        for i, itm in ipairs(state.items) do
            imgui.table_next_row()

            imgui.table_next_column()
            if imgui.small_button(">##sel_item_" .. i) then
                select_obj("item", itm)
            end

            imgui.table_next_column()
            imgui.text(string.format("%.0fm", itm.dist))

            imgui.table_next_column()
            imgui.text(itm.go_name or "?")

            imgui.table_next_column()
            local guid_str = itm.go_guid or ""
            imgui.push_item_width(310)
            imgui.input_text("##iguid_" .. i, guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##ic_" .. i) then
                imgui.set_clipboard_text(guid_str)
            end

            imgui.table_next_column()
            imgui.text(itm.bullet_id and tostring(itm.bullet_id) or "-")

            imgui.table_next_column()
            imgui.text(itm.add_item_id and tostring(itm.add_item_id) or "-")

            imgui.table_next_column()
            if itm.pos then
                imgui.text(string.format("%.1f, %.1f, %.1f", itm.pos.x, itm.pos.y, itm.pos.z))
            end
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Settings
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_settings()
    local ch

    colored_header("Dev Overlay")
    ch, cfg.show_dev_overlay = imgui.checkbox("Show Dev Overlay (top-left)", cfg.show_dev_overlay)

    colored_header("Level Flow Catalog")
    ch, cfg.show_levelflow_catalog_overlay = imgui.checkbox(
        "Show Level Flow Progress Overlay", cfg.show_levelflow_catalog_overlay)
    imgui.spacing()
    local cur_name = _current_scenario_no ~= nil
        and (SCENARIO_NAMES[_current_scenario_no] or string.format("#%d", _current_scenario_no))
        or "?"
    imgui.text_colored(string.format(
        "  SSM: %s   Entries: %d   Current: %s",
        _catalog_found and "OK" or "not found",
        #_prog_entries,
        cur_name),
        to_imgui(0xFF888888))
    if imgui.button("Rescan Catalog##lfc") then
        pcall(scan_levelflow_catalog)
        pcall(scan_levelflow_values)
    end
    if cfg.show_dev_overlay then
        imgui.spacing()
        imgui.text_colored("  MapID: " .. map_id_str(state.dev.map_id), to_imgui(0xFFCCCCCC))
        imgui.text_colored("  Scene: " .. (state.dev.scene ~= "" and state.dev.scene or "(none)"), to_imgui(0xFFFFCC44))
        if state.dev.rank ~= nil then
            imgui.text_colored("  Rank:  " .. tostring(state.dev.rank), to_imgui(0xFF88CCFF))
        end
        if state.dev.player_name ~= "" then
            imgui.text_colored("  Player: " .. state.dev.player_name, to_imgui(0xFF44FF88))
        end
    end

    colored_header("Label Content")
    ch, cfg.hide_dead = imgui.checkbox("Hide Dead Enemies in ESP", cfg.hide_dead)

    colored_header("Font")
    local fc
    fc, cfg.font_size = imgui.drag_int("ESP Font Size##fs", cfg.font_size, 1, 8, 32)
    if fc then reset_esp_fonts() end

    colored_header("Scanner")
    ch, cfg.scan_interval = imgui.drag_int("Scan Interval (frames)##si", cfg.scan_interval, 1, 5, 300)

    colored_header("B Key Export")
    imgui.text_colored("  Press B in-game to append current enemies to:", to_imgui(0xFFCCCCCC))
    imgui.text_colored("  reframework/data/extra_enemies.csv", to_imgui(0xFF88CCFF))
    imgui.text_colored("  Format: GUID / Name / KindID / MapID / X Y Z", to_imgui(0xFF888888))

    imgui.spacing()
    imgui.separator()
    if imgui.button("Save Settings") then cfg_save() end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Object Viewer / Inspector
-- ═══════════════════════════════════════════════════════════════════════════

local TABS  -- forward declaration

select_obj = function(obj_type, data)
    state.sel_type = obj_type
    state.sel_data = {}
    for k, v in pairs(data) do state.sel_data[k] = v end
    -- floating window appears automatically from sel_data being non-nil
end

-- vi_copyable: label (grey) + value + [C] copy button
local function vi_copyable(label, value, uid)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text(tostring(value or ""))
    imgui.same_line()
    if imgui.small_button("C##vic_" .. tostring(uid)) then
        imgui.set_clipboard_text(tostring(value or ""))
    end
end

-- vi_field: label (grey) + colored value text
local function vi_field(label, value, col)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text_colored(tostring(value or ""), to_imgui(col or 0xFFE0E0E0))
end

-- vi_bool: label (grey) + YES/NO colored
local function vi_bool(label, val, col_true, col_false)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    if val then
        imgui.text_colored("YES", to_imgui(col_true  or 0xFF44FF88))
    else
        imgui.text_colored("NO",  to_imgui(col_false or 0xFFFF5555))
    end
end

-- vi_section: spacing + colored section title + spacing (reuses colored_header)
local function vi_section(title)
    colored_header(title, 0xFF44CCFF)
end

-- Per-kind approximate max HP table
local ENEMY_MAX_HP = { [4]=350, [5]=200, [6]=400 }
local ENEMY_MAX_HP_DEFAULT = 300

-- view_enemy: full detail panel for an enemy entry
local function view_enemy(e)
    -- Header
    local alive_col  = (not e.dead) and to_imgui(0xFF44FF88) or to_imgui(0xFFFF5555)
    local alive_text = (not e.dead) and "[ALIVE]" or "[DEAD]"
    imgui.text_colored(e.go_name or "?", to_imgui(0xFFFFFFFF))
    imgui.same_line()
    imgui.text_colored(alive_text, alive_col)

    vi_section("IDENTITY")
    vi_copyable("GO GUID:",      e.go_guid      or "-", "e_goguid")
    vi_copyable("Context GUID:", e.context_guid or "-", "e_ctxguid")
    local kind_str = string.format("%s (ID %s)", e.kind_name or "?", tostring(e.kind_id or "?"))
    vi_field("Kind:", kind_str, 0xFFCCCCCC)
    vi_field("Map:",  map_id_str(e.map_id), 0xFFCCCCCC)

    vi_section("COMBAT")
    if e.hp ~= nil then
        local hp_val = math.floor(e.hp)
        local hp_col = (e.hp > 200) and 0xFF44FF88 or ((e.hp > 50) and 0xFFFFAA44 or 0xFFFF5555)
        vi_field("HP:", tostring(hp_val), hp_col)

        local max_hp = ENEMY_MAX_HP[e.kind_id] or ENEMY_MAX_HP_DEFAULT
        local frac   = math.max(0, math.min(1, e.hp / max_hp))
        local bar_col = hp_col
        local bg_col  = 0xFF333333
        imgui.push_style_color(8, to_imgui(bar_col))
        imgui.push_style_color(9, to_imgui(bg_col))
        imgui.progress_bar(frac, Vector2f.new(-1, 8), "")
        imgui.pop_style_color(2)
    else
        vi_field("HP:", "-", 0xFF888888)
    end
    vi_bool("Dead:",     e.dead,     0xFFFF5555, 0xFF44FF88)
    vi_field("BT State:", e.bt_state or "-", 0xFFDDDDDD)

    vi_section("POSITION")
    if e.pos then
        vi_field("X:", string.format("%.3f", e.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", e.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", e.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", e.dist or 0), 0xFFAAAAAA)
end

-- view_spawn: detail panel for a spawn group entry
local function view_spawn(sg)
    -- Header color: lime=spawned, purple=vanished, red=all_dead, white=else
    local hcol
    if sg.is_spawned  then hcol = to_imgui(0xFF44FF88)
    elseif sg.is_vanished then hcol = to_imgui(0xFFCC88FF)
    elseif sg.all_dead    then hcol = to_imgui(0xFFFF5555)
    else                       hcol = to_imgui(0xFFFFFFFF) end
    imgui.text_colored(sg.go_name or "?", hcol)

    vi_section("IDENTITY")
    vi_copyable("GO GUID:", sg.go_guid or "-", "sg_goguid")

    vi_section("FLAGS")
    vi_bool("Spawned:",            sg.is_spawned,       0xFF44FF88, 0xFFAAAAAA)
    vi_bool("Vanished:",           sg.is_vanished,      0xFFCC88FF, 0xFFAAAAAA)
    vi_bool("All Dead:",           sg.all_dead,         0xFFFF5555, 0xFFAAAAAA)
    vi_bool("Difficulty Enabled:", sg.enabled_difficulty, 0xFF44FF88, 0xFFAAAAAA)
    vi_bool("Map ID Enabled:",     sg.enabled_map,      0xFF44FF88, 0xFFAAAAAA)
    vi_field("Init Difficulty:",   tostring(sg.init_difficulty or "-"), 0xFFCCCCCC)

    vi_section("BEHAVIOUR")
    vi_field("BT State:", sg.bt_state or "-", 0xFFDDDDDD)

    vi_section("POSITION")
    if sg.pos then
        vi_field("X:", string.format("%.3f", sg.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", sg.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", sg.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", sg.dist or 0), 0xFFAAAAAA)
end

-- view_item: detail panel for an item entry
local function view_item(itm)
    imgui.text_colored(itm.go_name or "?", to_imgui(0xFF44EEFF))

    vi_section("IDENTITY")
    vi_copyable("GO GUID:", itm.go_guid or "-", "itm_goguid")
    vi_field("Bullet ID:", tostring(itm.bullet_id   or "-"), 0xFFCCCCCC)
    vi_field("Item ID:",   tostring(itm.add_item_id or "-"), 0xFFCCCCCC)

    vi_section("POSITION")
    if itm.pos then
        vi_field("X:", string.format("%.3f", itm.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", itm.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", itm.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", itm.dist or 0), 0xFFAAAAAA)
end

-- view_scenario: detail panel for a scenario entry
local function view_scenario(sc)
    local now = os.clock()
    local changed_recently = sc.changed_at > 0 and
        ((now - sc.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
    local hcol = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFFFFFFF)
    imgui.text_colored(sc.go_name or "?", hcol)

    vi_section("SCENARIO")
    local sno     = sc.scenario_no
    local sno_str = sno and (tostring(sno) .. "  " .. (SCENARIO_NAMES[sno] or "")) or "-"
    vi_field("ScenarioNo:", sno_str, 0xFFCCCCCC)
    vi_bool("IsAdvance:", sc.is_advance, 0xFF44FF88, 0xFFAAAAAA)

    vi_section("BEHAVIOUR")
    local bt_col = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFDDDDDD)
    imgui.text_colored("BT State:", to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text_colored(sc.bt_state or "-", bt_col)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Component enumeration helpers
-- ═══════════════════════════════════════════════════════════════════════════

local _via_comp_rt = nil
local function get_via_comp_rt()
    if not _via_comp_rt then
        local td = sdk.find_type_definition("via.Component")
        _via_comp_rt = td and td:get_runtime_type()
    end
    return _via_comp_rt
end

-- Returns a list of all live component objects on a GO.
-- Tries getComponents(via.Component) first; falls back to known type list.
local function get_all_go_components(go)
    if not go then return {} end
    local comps = {}

    pcall(function()
        local rt = get_via_comp_rt()
        if not rt then return end
        local list = go:call("getComponents(System.Type)", rt)
        if not list then return end
        local n = 0
        pcall(function() n = list:call("get_Count") end)
        if n == 0 then pcall(function() n = #list end) end
        for i = 0, n - 1 do
            local c = nil
            pcall(function() c = list:call("get_Item", i) end)
            if c == nil then pcall(function() c = list[i] end) end
            if c then comps[#comps + 1] = c end
        end
    end)

    if #comps == 0 then
        local known = get_known_comp_types()
        for _, k in ipairs(known) do
            if k.rt then
                local c = nil
                pcall(function() c = go:call("getComponent(System.Type)", k.rt) end)
                if c then comps[#comps + 1] = c end
            end
        end
    end

    return comps
end

-- ═══════════════════════════════════════════════════════════════════════════
-- view_generic_go: full inspector panel for a generic GO (Objects tab)
-- ═══════════════════════════════════════════════════════════════════════════

local function view_generic_go(data)
    local go = data._go_ref

    -- ── Header ────────────────────────────────────────────────────────────────
    imgui.text_colored(data.go_name or "?",
        to_imgui(data.active and 0xFFFFFFFF or 0xFF888888))
    imgui.same_line()
    imgui.text_colored(data.active and "[ACTIVE]" or "[INACTIVE]",
        data.active and to_imgui(0xFF44FF88) or to_imgui(0xFF555555))

    vi_copyable("GO GUID:", data.go_guid or "-", "vgo_guid")
    if data.tags and #data.tags > 0 then
        vi_field("Tags:", table.concat(data.tags, "  "), 0xFF88FFCC)
    end
    if data.pos then
        vi_field("Pos:",
            string.format("%.2f, %.2f, %.2f  (%.1f m)",
                data.pos.x, data.pos.y, data.pos.z, data.dist or 0),
            0xFFAAAAAA)
    end

    -- World highlight toggle
    imgui.spacing()
    local ch
    ch, cfg.go_highlight_selected = imgui.checkbox(
        "Highlight in World##gohl", cfg.go_highlight_selected)
    imgui.spacing()

    if not go then
        imgui.text_colored("  (live GO reference lost — rescan objects)",
            to_imgui(0xFF888888))
        return
    end

    -- ── Live GO hierarchy info ─────────────────────────────────────────────
    local parent_name, child_count = nil, 0
    pcall(function()
        local parent_go = go:call("get_Parent")
        if parent_go then
            parent_name = tostring(parent_go:call("get_Name") or "?")
        end
        local xf = go:call("get_Transform")
        if xf then
            pcall(function() child_count = xf:call("get_ChildCount") or 0 end)
        end
    end)
    if parent_name then vi_field("Parent:", parent_name, 0xFFCCAA88) end
    if child_count > 0 then vi_field("Children:", tostring(child_count), 0xFFCCAA88) end

    imgui.spacing()

    -- ── Component list ────────────────────────────────────────────────────
    local comps = get_all_go_components(go)
    imgui.text_colored(
        string.format("  %d component(s)", #comps),
        to_imgui(0xFF88DDFF))

    local fc
    fc, _go_inspector_filter = imgui.input_text(
        "Filter fields##gofltr", _go_inspector_filter, 128)
    local filter_lo = _go_inspector_filter:lower()

    imgui.spacing()

    -- Scrollable inspector area
    if imgui.begin_child("go_comps##vgo", Vector2f.new(-1, 0), true) then
        if #comps == 0 then
            imgui.text_colored("  (no components found)", to_imgui(0xFF555555))
        end

        for ci, comp in ipairs(comps) do
            -- Resolve full type name
            local ctype_full, ctype_short = "unknown", "unknown"
            pcall(function()
                local td = comp:get_type_definition()
                if td then
                    ctype_full  = td:get_full_name() or td:get_name() or "unknown"
                    ctype_short = td:get_name()       or ctype_full
                end
            end)

            -- Collapsible tree node per component (first starts open)
            local node_label = string.format("[%d]  %s##cn%d", ci, ctype_short, ci)
            imgui.push_style_color(0, to_imgui(0xFF44CCFF))
            if ci == 1 then
                -- ImGuiCond_Once = 2: open on first encounter, user can collapse
                imgui.set_next_item_open(true, 2)
            end
            local open = imgui.tree_node(node_label)
            imgui.pop_style_color(1)

            if open then
                -- Full type name if it differs from short
                if ctype_full ~= ctype_short then
                    imgui.text_colored("  " .. ctype_full, to_imgui(0xFF555555))
                end
                imgui.spacing()

                pcall(function()
                    local td = comp:get_type_definition()
                    if not td then
                        imgui.text_colored("  (no TypeDefinition)", to_imgui(0xFF555555))
                        return
                    end
                    local fields = td:get_fields()
                    if not fields then
                        imgui.text_colored("  (no fields)", to_imgui(0xFF555555))
                        return
                    end

                    local n = 0
                    pcall(function()
                        local len = #fields
                        if type(len) == "number" and len > 0 then n = len end
                    end)
                    if n == 0 then pcall(function() n = fields.Length or 0 end) end
                    if n == 0 then n = 300 end

                    local shown = 0
                    for fi_i = 0, n - 1 do
                        local fi = fields[fi_i]
                        if fi == nil then break end

                        local fname = "?"
                        pcall(function() fname = tostring(fi:get_name()) end)

                        if filter_lo ~= "" and
                           not fname:lower():find(filter_lo, 1, true) then
                            goto next_fi
                        end

                        local ftype_name = ""
                        pcall(function()
                            local ft = fi:get_type()
                            if ft then ftype_name = ft:get_name() or "" end
                        end)

                        local fval_str, fval_col = "?", 0xFFE0E0E0
                        pcall(function()
                            local v = fi:get_data(comp)
                            if v == nil then
                                fval_str = "nil"
                                fval_col = 0xFF555555
                            elseif type(v) == "boolean" then
                                fval_str = v and "true" or "false"
                                fval_col = v and 0xFF44FF88 or 0xFFFF5555
                            elseif type(v) == "number" then
                                fval_str = (v ~= math.floor(v))
                                    and string.format("%.5g", v)
                                    or tostring(math.floor(v))
                                fval_col = 0xFFFFCC88
                            else
                                fval_str = tostring(v)
                                local fn = ftype_name:lower()
                                if fn:find("vec3") or fn:find("vector3") then
                                    fval_col = 0xFFAADDFF
                                elseif fn:find("vec4") or fn:find("quaternion") then
                                    fval_col = 0xFFCCAAFF
                                elseif fn:find("vec2") or fn:find("vector2") then
                                    fval_col = 0xFF88EEFF
                                elseif fn:find("string") then
                                    fval_col = 0xFFFFCC44
                                end
                            end
                        end)

                        -- Row: name (light) | value (typed color) | type (dim)
                        imgui.text_colored("  " .. fname, to_imgui(0xFFCCCCCC))
                        imgui.same_line()
                        imgui.text_colored(fval_str, to_imgui(fval_col))
                        if ftype_name ~= "" then
                            imgui.same_line()
                            imgui.text_colored("  " .. ftype_name, to_imgui(0xFF444444))
                        end

                        shown = shown + 1
                        ::next_fi::
                    end

                    if shown == 0 then
                        if filter_lo ~= "" then
                            imgui.text_colored(
                                "  (no fields match \"" .. _go_inspector_filter .. "\")",
                                to_imgui(0xFF555555))
                        else
                            imgui.text_colored("  (no fields)", to_imgui(0xFF555555))
                        end
                    end
                end)

                imgui.tree_pop()
                imgui.spacing()
            end
        end

        imgui.end_child()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ui_objects: Objects tab — scene browser (all GOs sorted by distance)
-- ═══════════════════════════════════════════════════════════════════════════

local _obj_filter = ""

local function ui_objects()
    local ch

    -- ESP controls
    ch, cfg.show_object_esp = imgui.checkbox("Show Objects ESP Overlay", cfg.show_object_esp)
    if cfg.show_object_esp then
        imgui.same_line()
        ch, cfg.object_esp_only_tagged = imgui.checkbox("Tagged only##ot", cfg.object_esp_only_tagged)
        ch, cfg.object_esp_range = imgui.drag_float("Range (m)##or", cfg.object_esp_range, 0.5, 2, 100, "%.1f m")
        color_picker_row("Label Color:", "col_object_name")
    end

    imgui.spacing()
    imgui.text_colored(
        string.format("  %d GOs loaded (300 closest shown, sorted by distance)",
            #state.objects),
        to_imgui(0xFF88DDFF))

    -- Filter
    local fc
    fc, _obj_filter = imgui.input_text("Filter##objf", _obj_filter, 128)

    imgui.spacing()

    local filter_lo = _obj_filter:lower()

    if imgui.begin_table("obj_table", 6, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",        16, 28,  0)
        imgui.table_setup_column("Tags",     16, 110, 0)
        imgui.table_setup_column("Name",     0,  1,   0)
        imgui.table_setup_column("GO GUID",  16, 280, 0)
        imgui.table_setup_column("Active",   16, 55,  0)
        imgui.table_setup_column("Dist",     16, 56,  0)
        imgui.table_headers_row()

        local shown = 0
        for i, obj in ipairs(state.objects) do
            if filter_lo == "" or obj.go_name:lower():find(filter_lo, 1, true) then
                imgui.table_next_row()

                imgui.table_next_column()
                if imgui.small_button(">##osel_" .. i) then
                    select_obj("go", obj)
                end

                imgui.table_next_column()
                local tag_str = #obj.tags > 0 and table.concat(obj.tags, " ") or ""
                local tag_col = #obj.tags > 0 and to_imgui(0xFF88FFCC) or to_imgui(0xFF555555)
                imgui.text_colored(tag_str, tag_col)

                imgui.table_next_column()
                local name_col = obj.active and to_imgui(0xFFFFFFFF) or to_imgui(0xFF888888)
                imgui.text_colored(obj.go_name, name_col)

                imgui.table_next_column()
                local guid_str = obj.go_guid or ""
                imgui.push_item_width(270)
                imgui.input_text("##oguid_" .. i, guid_str, 2048)
                imgui.pop_item_width()
                imgui.same_line()
                if imgui.small_button("C##oc_" .. i) then
                    imgui.set_clipboard_text(guid_str)
                end

                imgui.table_next_column()
                imgui.text_colored(obj.active and "Y" or "N",
                    obj.active and to_imgui(0xFF44FF88) or to_imgui(0xFF555555))

                imgui.table_next_column()
                imgui.text(string.format("%.0fm", obj.dist))

                shown = shown + 1
                if shown >= 200 then break end  -- cap ImGui rows
            end
        end
        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ui_object: floating inspector viewer content
-- ═══════════════════════════════════════════════════════════════════════════

-- ui_object: Object tab content
local function ui_object()
    if not state.sel_data then
        imgui.spacing()
        imgui.text_colored("  No object selected.", to_imgui(0xFF888888))
        imgui.spacing()
        imgui.text_colored("  Click  >  next to any row in another tab.", to_imgui(0xFF555555))
        return
    end

    local tp  = state.sel_type or "?"
    local obj = state.sel_data

    local badges = { enemy="ENEMY", spawn="SPAWN GROUP", item="ITEM", scenario="SCENARIO", go="GAME OBJECT" }
    imgui.text_colored("[ " .. (badges[tp] or tp) .. " ]", to_imgui(0xFF44EEFF))
    imgui.same_line()
    if imgui.small_button("Close") then
        state.sel_type = nil
        state.sel_data = nil
        return
    end
    imgui.separator()
    imgui.spacing()

    if     tp == "enemy"    then pcall(view_enemy,      obj)
    elseif tp == "spawn"    then pcall(view_spawn,      obj)
    elseif tp == "item"     then pcall(view_item,       obj)
    elseif tp == "scenario" then pcall(view_scenario,   obj)
    elseif tp == "go"       then pcall(view_generic_go, obj)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Window
-- ═══════════════════════════════════════════════════════════════════════════

TABS = {
    { name = "Enemies",      fn = ui_enemies      },
    { name = "Spawn Groups", fn = ui_spawn_groups },
    { name = "Scenarios",    fn = ui_scenarios    },
    { name = "Items",        fn = ui_items        },
    { name = "Objects",      fn = ui_objects      },
    { name = "Settings",     fn = ui_settings     },
}

re.on_draw_ui(function()
    local ch
    ch, cfg.show_ui = imgui.checkbox(TITLE, cfg.show_ui)
    if not cfg.show_ui then return end

    if imgui.begin_window(TITLE .. "###biorand_re3r_w", true, 0) then

        -- Status bar
        imgui.text_colored(
            string.format("  Enemies: %d   Spawns: %d   Items: %d   MapID: %s",
                #state.enemies, #state.spawn_groups, #state.items, map_id_str(state.dev.map_id)),
            to_imgui(0xFF88DDFF))
        imgui.separator()

        -- Tab bar
        for i, tab in ipairs(TABS) do
            if i > 1 then imgui.same_line() end
            local active = (state.ui_tab == i)
            if active then
                imgui.push_style_color(21, to_imgui(0xFF44FF88))
                imgui.push_style_color(22, to_imgui(0xFF44FF88))
                imgui.push_style_color(23, to_imgui(0xFF44FF88))
                imgui.push_style_color(0,  to_imgui(0xFF1A1A2E))
            else
                imgui.push_style_color(21, to_imgui(0xFF333344))
                imgui.push_style_color(22, to_imgui(0xFF444466))
                imgui.push_style_color(23, to_imgui(0xFF555577))
                imgui.push_style_color(0,  to_imgui(0xFFAAAAAA))
            end
            if imgui.button(tab.name .. "##t" .. i) then state.ui_tab = i end
            imgui.pop_style_color(4)
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        local sel = TABS[state.ui_tab or 1]
        if sel and sel.fn then pcall(sel.fn) end

        imgui.end_window()
    end

    -- Floating Object Inspector — appears when anything is selected via >
    -- Only ui_object() renders the viewer; nothing else does, so no ID conflicts.
    if state.sel_data then
        if imgui.begin_window("Inspector###biorand_insp", true, 0) then
            pcall(ui_object)
            imgui.end_window()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

re.on_script_reset(function()
    state.enemies         = {}
    state.items           = {}
    state.spawn_groups    = {}
    state.scenarios       = {}
    state.player_pos      = nil
    state.player_hp       = 0
    state.dev_rotation    = nil
    state.dev             = { scene = "", map_id = nil, rank = nil, playtime = nil,
                               player_name = "", player_state = "" }
    state.scenario_state_history = {}
    state.spawn_scene_address    = 0
    state.scenario_scene_address = 0
    state.sel_type        = nil
    state.sel_data        = nil
    state.objects         = {}
    _KNOWN_COMP_TYPES     = nil
    _xf_rt                = nil
    _via_comp_rt          = nil
    _prog_entries         = {}
    _catalog_found        = false
    _current_scenario_no  = nil
    state.status_msg      = ""
    _type_cache           = {}
    reset_overlay_fonts()
    reset_esp_fonts()
end)

log.info("[RE3R Trainer] " .. TITLE .. " loaded.")
