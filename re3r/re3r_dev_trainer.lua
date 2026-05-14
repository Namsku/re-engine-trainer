--[[
    RE3R Dev Trainer v3.0
    Matches RE9/RE7 Architecture + Full ESP + Crash-Proof HP Delta
]]

local TITLE = "RE3R Dev Trainer v3.0"
local CFG_FILE = "re3r_dev_trainer.json"

if reframework:get_game_name() ~= "re3" then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- Config & State
-- ═══════════════════════════════════════════════════════════════════════════

local C = {
    noclip = false, noclip_speed = 0.4,
    game_speed_on = false, game_speed = 1.0, player_scale = 1.0,
    show_dev_overlay = true, enemy_panel = true,
    enemy_esp = true, item_esp = true, spawn_esp = true, show_damage_numbers = true,
    show_bars = true, show_pct = true, hide_dead = true, dist_color = true,
    esp_range = 50.0, esp_font = 18, panel_rows = 15,
    panel_font = 16, panel_w = 460, panel_bar_w = 150, panel_bar_h = 8,
}

local R = {
    tick = 0, toasts = {}, enemies = {}, items = {}, spawners = {}, damage_numbers = {},
    player_pos = nil, player_rot = nil, player_hp = 0, player_max_hp = 0,
    scene_name = "", loaded_scene = "", chapter = "", area_name = "",
    da_score = 0, rank = 0, playtime = 0, difficulty = 0, dev_overlay_bottom = 0,
}

local last_hp_map = {}

local function cfg_save() pcall(function() json.dump_file(CFG_FILE, C) end) end
local function cfg_load()
    pcall(function()
        local t = json.load_file(CFG_FILE)
        if t then for k,v in pairs(t) do if C[k] ~= nil then C[k] = v end end end
    end)
end
cfg_load()

local function toast(msg, dur) R.toasts[#R.toasts+1] = { text=msg, time=os.clock(), dur=dur or 3 } end

-- ═══════════════════════════════════════════════════════════════════════════
-- SDK Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local known_types = {}
local function get_type(name)
    if not known_types[name] then known_types[name] = sdk.typeof(name) end
    return known_types[name]
end

local function getComponent(go, type_name)
    if not go then return nil end
    local t = get_type(type_name)
    if not t then return nil end
    return go:call("getComponent(System.Type)", t)
end

local function get_scene()
    local ok, s = pcall(function()
        return sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
    end)
    return ok and s or nil
end

local function find_components(type_name)
    local scene = get_scene()
    if not scene then return nil, 0 end
    local td = sdk.find_type_definition(type_name)
    if not td then return nil, 0 end
    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", td:get_runtime_type()) end)
    if not comps then return nil, 0 end
    local ok, n = pcall(comps.call, comps, "get_Count")
    return comps, (ok and n or 0)
end

local function quat_to_euler(q)
    if not q then return nil end
    local x,y,z,w = q.x or 0, q.y or 0, q.z or 0, q.w or 0
    local pitch = math.atan(2*(w*x+y*z), 1-2*(x*x+y*y))
    local siny = math.max(-1, math.min(1, 2*(w*y-z*x)))
    local yaw = math.asin(siny)
    local roll = math.atan(2*(w*z+x*y), 1-2*(y*y+z*z))
    return { x=math.deg(pitch), y=math.deg(yaw), z=math.deg(roll) }
end

local function dist3(a, b)
    if not a or not b then return 999 end
    local dx,dy,dz = (a.x or 0)-(b.x or 0), (a.y or 0)-(b.y or 0), (a.z or 0)-(b.z or 0)
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function get_hp(go)
    local hp, mhp = 0, 0
    pcall(function()
        local hpc = getComponent(go, "offline.HitPointController")
        if hpc then
            hp = hpc:get_field("CurrentHitPoint") or hpc:call("get_CurrentHitPoint") or 0
            mhp = hpc:get_field("HitPointMax") or hpc:call("get_HitPointMax") or 0
        end
    end)
    return hp, mhp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Access
-- ═══════════════════════════════════════════════════════════════════════════

local function getLocalPlayer()
    local p = nil
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if pm then p = pm:get_field("PlayerObj") or pm:call("get_Player") end
        if not p then
            local om = sdk.get_managed_singleton("app.ObjectManager")
            if om then p = om:get_field("PlayerObj") or om:call("get_Player") end
        end
    end)
    return p
end

local function get_player_pos()
    local p = getLocalPlayer()
    if not p then return nil end
    local pos
    pcall(function() pos = p:get_Transform():get_Position() end)
    return pos
end

local function get_camera_rot()
    local rot
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
        if q then rot = quat_to_euler(q) end
    end)
    if not rot then
        pcall(function()
            local p = getLocalPlayer()
            if not p then return end
            local xf = p:call("get_Transform")
            if not xf then return end
            local q = xf:call("get_Rotation")
            if q then rot = quat_to_euler(q) end
        end)
    end
    return rot
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scanners (Enemies, Items, Spawners)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_enemies()
    local results = {}
    local ppos = R.player_pos
    local seen = {}
    
    local types = {"offline.EnemyController"}
    for _, tname in ipairs(types) do
        pcall(function()
            local comps, n = find_components(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n-1, 100) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local go = c:call("get_GameObject")
                    if not go then return end
                    local id = tostring(go:get_address())
                    if seen[id] then return end
                    seen[id] = true
                    
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    local hp, mhp = get_hp(go)
                    local name = tostring(go:call("get_Name") or "Enemy")
                    results[#results+1] = {
                        name = name, hp = hp, mhp = mhp, dead = (hp <= 0),
                        dist = dist3(pos, ppos), pos = pos, go = go
                    }
                end)
            end
        end)
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

local function scan_items()
    local results = {}
    local ppos = R.player_pos
    local seen = {}
    
    local types = {
        "offline.gamemastering.Item",
        "offline.HandHeldItem",
        "offline.gimmick.action.SetItem"
    }
    for _, tname in ipairs(types) do
        pcall(function()
            local comps, n = find_components(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n-1, 100) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local go = c:call("get_GameObject")
                    if not go then return end
                    local id = tostring(go:get_address())
                    if seen[id] then return end
                    seen[id] = true
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    local name = tostring(go:call("get_Name") or "Item")
                    results[#results+1] = { name = name, dist = dist3(pos, ppos), pos = pos }
                end)
            end
        end)
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Universal Cheats Implementation
-- ═══════════════════════════════════════════════════════════════════════════

local function do_noclip()
    if not C.noclip then return end
    local player = getLocalPlayer()
    if not player then return end
    pcall(function()
        local xf = player:get_Transform()
        local pos = xf:get_Position()
        local spd = C.noclip_speed
        
        if reframework:is_key_down(0x57) then pos.x = pos.x - spd end -- W
        if reframework:is_key_down(0x53) then pos.x = pos.x + spd end -- S
        if reframework:is_key_down(0x44) then pos.z = pos.z - spd end -- D
        if reframework:is_key_down(0x41) then pos.z = pos.z + spd end -- A
        if reframework:is_key_down(0x20) then pos.y = pos.y + spd end -- Space
        if reframework:is_key_down(0x10) then pos.y = pos.y - spd end -- Shift
        
        local cc = getComponent(player, "via.physics.CharacterController")
        if cc then cc:call("warp") end
        xf:set_Position(pos)
        if cc then cc:call("warp") end
    end)
end

local function apply_game_speed()
    pcall(function()
        if C.game_speed_on then
            sdk.call_native_func(
                sdk.get_native_singleton("via.Application"),
                sdk.find_type_definition("via.Application"), "set_GlobalSpeed", C.game_speed)
        else
            sdk.call_native_func(
                sdk.get_native_singleton("via.Application"),
                sdk.find_type_definition("via.Application"), "set_GlobalSpeed", 1.0)
        end
    end)
end

local function apply_player_scale()
    local p = getLocalPlayer()
    if not p then return end
    pcall(function()
        local xf = p:get_Transform()
        xf:set_LocalScale(Vector3f.new(C.player_scale, C.player_scale, C.player_scale))
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EMV Engine Integration
-- ═══════════════════════════════════════════════════════════════════════════

local my_dir = ""
pcall(function()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        my_dir = info.source:gsub("^@", ""):match("(.+[\\/])") or ""
    end
end)

local emv_path = my_dir .. "../emv_engine/init.lua"
local emv_fn = loadfile(emv_path)
if emv_fn then pcall(emv_fn, _G) else print("[RE3R Trainer] Failed to load EMV Engine from " .. emv_path) end
local EMV = _G.EMV or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- Rendering Helpers (ABGR)
-- ═══════════════════════════════════════════════════════════════════════════

local has_draw_api = (draw ~= nil)
local function argb(col)
    local a = (col >> 24) & 0xFF
    local r = (col >> 16) & 0xFF
    local g = (col >>  8) & 0xFF
    local b = col & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

local DC = {
    DEV_BG       = argb(0xCC0A0A1E), DEV_ACCENT   = argb(0xDD44FF88),
    PANEL_BG     = argb(0x69000000), BAR_FILL     = argb(0xFF76DCA7),
    BAR_EMPTY    = argb(0xFFB8B8B8), BAR_TRACK    = argb(0xFF222233),
    SEP          = argb(0x60FFFFFF), ALT_ROW      = argb(0x12FFFFFF),
    BORDER       = argb(0x30FFFFFF), TEXT         = argb(0xFFE8E8E8),
    TEXT_WHITE   = argb(0xFFE0E0E0), TEXT_GRAY    = argb(0xFFAAAAAA),
    TEXT_GREEN   = argb(0xFF44FF88), TEXT_YELLOW  = argb(0xFFFFCC44),
    TEXT_CYAN    = argb(0xFF44FFFF), TEXT_BLUE    = argb(0xFF88CCFF),
    TEXT_RED     = argb(0xFFFF4444),
    NAME_DEFAULT = argb(0xFFDDDDDD), NAME_CLOSE   = argb(0xFF7777FF),
    NAME_MID     = argb(0xFF66CCFF), HP_GOOD      = argb(0xFFBBBBBB),
    HP_LOW       = argb(0xFFFFAA44), HP_CRIT      = argb(0xFFFF6666),
    HUD_BG       = argb(0xBB1A1A2E), HUD_LINE     = argb(0x44444466),
    HUD_TEXT     = argb(0xDD88CCFF), SHADOW       = argb(0xCC000000),
}

local function hp_gradient(ratio)
    local r_val, g_val
    if ratio > 0.5 then
        r_val = math.floor((1.0 - ratio) * 2 * 255)
        g_val = 255
    else
        r_val = 255
        g_val = math.floor(ratio * 2 * 255)
    end
    return 0xFF000000 + (r_val * 0x10000) + (g_val * 0x100) + r_val
end

-- ── UI Rendering ──
local function render_dev_overlay()
    if not C.show_dev_overlay then return end
    if not has_draw_api then return end
    local pos, rot = R.player_pos, R.player_rot
    local info = { " RE3R DEVELOPER OVERLAY" }
    if pos then info[#info + 1] = string.format(" Pos:  %.2f,  %.2f,  %.2f", pos.x, pos.y, pos.z) end
    if rot then info[#info + 1] = string.format(" Rot:  P %.1f  Y %.1f  R %.1f", rot.x, rot.y, rot.z) end
    if R.scene_name ~= "" then info[#info + 1] = " Scene: " .. R.scene_name end
    info[#info + 1] = string.format(" Rank:  %d     Time: %d s", R.rank, R.playtime)

    local x, y, line_h, pad = 24, 10, 20, 6
    local panel_h = pad * 2 + #info * line_h
    draw.filled_rect(x - pad, y - pad, 360, panel_h, DC.DEV_BG)
    draw.filled_rect(x - pad, y - pad, 3, panel_h, DC.DEV_ACCENT)
    R.dev_overlay_bottom = y - pad + panel_h + 8

    for i, line in ipairs(info) do
        local col = (i == 1) and DC.TEXT_GREEN or DC.TEXT_WHITE
        if line:sub(1, 6) == " Scene" then col = DC.TEXT_YELLOW end
        draw.text(line, x, y, col)
        y = y + line_h
    end
end

local function render_hud_strip()
    if not has_draw_api then return end
    local tags = {}
    if C.noclip then tags[#tags+1]="NOCLIP" end
    if C.game_speed_on then tags[#tags+1]=string.format("SPEED:%.1fx", C.game_speed) end
    if #tags == 0 then return end
    local text = table.concat(tags, "  |  ")
    local tw = #text * 8 + 40
    local sw = 1920
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local scene = sdk.call_native_func(sm, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
        local mv = scene:call("get_MainView")
        local sz = mv:call("get_Size")
        if sz then sw = sz.w end
    end)
    local hx, hy = sw - tw - 16, 16
    draw.filled_rect(hx, hy, tw, 24, DC.HUD_BG)
    draw.filled_rect(hx, hy + 24, tw, 1, DC.HUD_LINE)
    draw.text(text, hx + 10, hy + 4, DC.HUD_TEXT)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI Window & Tabs
-- ═══════════════════════════════════════════════════════════════════════════

local CLR = { ON = 0xFF44FF88, OFF = 0xFFEEEEFF, CAT = 0xFFFFDD88, MUTED = 0xFF999999, WHITE = 0xFFEEEEFF }
local function section(text, color)
    imgui.spacing(); imgui.spacing()
    imgui.push_style_color(27, color or CLR.CAT)
    imgui.separator()
    imgui.pop_style_color(1)
    imgui.text_colored("  " .. text, color or CLR.CAT)
    imgui.spacing()
end
local function tog(label, key, tip)
    local v = C[key]
    imgui.push_style_color(0, v and CLR.ON or CLR.OFF)
    local ch, nv = imgui.checkbox(label, v)
    imgui.pop_style_color(1)
    if ch then C[key] = nv; pcall(cfg_save); toast(nv and (label .. " ON") or (label .. " off")) end
end

local function ui_player()
    section("Engine Interception", CLR.CAT)
    tog("Noclip (WASD + Shift/Space)", "noclip")
    if C.noclip then
        local ch, v = imgui.slider_float("Noclip Speed##nc", C.noclip_speed, 0.1, 2.0, "%.2f")
        if ch then C.noclip_speed = v; cfg_save() end
    end
    imgui.spacing()
    tog("Override Game Speed", "game_speed_on")
    if C.game_speed_on then
        local ch, v = imgui.slider_float("Global Speed##gs", C.game_speed, 0.1, 10.0, "%.1fx")
        if ch then C.game_speed = v; apply_game_speed(); cfg_save() end
    end
    imgui.spacing()
    local ch, v = imgui.slider_float("Player Scale##ps", C.player_scale, 0.1, 5.0, "%.2fx")
    if ch then C.player_scale = v; apply_player_scale(); cfg_save() end
end

local function ui_objects() if EMV.render_objects_tab then pcall(EMV.render_objects_tab) else imgui.text_colored("EMV Engine not loaded properly.", 0xFFFF4444) end end
local function ui_inspector() if EMV.render_method_inspector then pcall(EMV.render_method_inspector) else imgui.text_colored("EMV Engine not loaded.", 0xFFFF4444) end end

local function ui_overlay()
    section("Overlays", CLR.CAT)
    tog("Dev Overlay (top-left)", "show_dev_overlay")
    tog("Damage Numbers", "show_damage_numbers")
    section("3D ESP", CLR.CAT)
    tog("Enemy ESP", "enemy_esp")
    tog("Item ESP", "item_esp")
    local ch, v = imgui.drag_float("ESP Range", C.esp_range, 1.0, 5, 200, "%.0f"); if ch then C.esp_range = v; cfg_save() end
end

local TAB_DEFS = {
    { name = "Player",    fn = ui_player },
    { name = "Objects",   fn = ui_objects },
    { name = "Inspector", fn = ui_inspector },
    { name = "Overlay",   fn = ui_overlay },
}
local cur_tab = 1
local trainer_visible = true

re.on_draw_ui(function()
    local changed; changed, trainer_visible = imgui.checkbox(TITLE, trainer_visible)
    if not trainer_visible then return end
    if imgui.begin_window(TITLE .. "###trainer_main", true, 0) then
        for i, tab in ipairs(TAB_DEFS) do
            if i > 1 then imgui.same_line() end
            if cur_tab == i then
                imgui.push_style_color(21, 0xFF44FF88); imgui.push_style_color(22, 0xFF44FF88); imgui.push_style_color(23, 0xFF44FF88); imgui.push_style_color(0, 0xFF1A1A2E)
            else
                imgui.push_style_color(21, 0xFF333344); imgui.push_style_color(22, 0xFF444466); imgui.push_style_color(23, 0xFF555577); imgui.push_style_color(0, 0xFFAAAAAA)
            end
            if imgui.button(tab.name .. "##tab" .. i) then cur_tab = i end
            imgui.pop_style_color(4)
        end
        imgui.spacing(); imgui.separator(); imgui.spacing()
        local sel = TAB_DEFS[cur_tab]
        if sel and sel.fn then pcall(sel.fn) end
        imgui.end_window()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Main Loop (Delta Trackers & Renderers)
-- ═══════════════════════════════════════════════════════════════════════════

re.on_frame(function()
    R.tick = R.tick + 1
    local now = os.clock()
    
    if EMV.process_on_frame_calls then pcall(EMV.process_on_frame_calls) end
    if EMV.process_deferred_calls then pcall(EMV.process_deferred_calls) end
    if EMV.ObjectCache then pcall(EMV.ObjectCache.sweep, EMV.ObjectCache) end
    if EMV.objects_background_update then pcall(EMV.objects_background_update) end

    if C.noclip then pcall(do_noclip) end

    -- Active Delta HP Tracking (Every Frame)
    if C.show_damage_numbers and R.enemies then
        for _, e in ipairs(R.enemies) do
            local id = tostring(e.go:get_address())
            local hp, mhp = get_hp(e.go)
            if last_hp_map[id] then
                if hp < last_hp_map[id] then
                    local dmg = last_hp_map[id] - hp
                    if dmg > 0 then
                        local ppos = e.go:call("get_Transform"):call("get_Position")
                        table.insert(R.damage_numbers, {
                            dmg = dmg,
                            pos = Vector3f.new(ppos.x, ppos.y + 1.5, ppos.z),
                            timer = now, life = 2.0
                        })
                    end
                end
            end
            last_hp_map[id] = hp
        end
    end

    if R.tick % 15 == 0 then
        pcall(function() R.player_pos = get_player_pos() end)
        pcall(function() R.player_rot = get_camera_rot() end)
        local p = getLocalPlayer()
        if p then R.player_hp, R.player_max_hp = get_hp(p) end
        
        pcall(function() R.enemies = scan_enemies() or {} end)
        pcall(function() R.items = scan_items() or {} end)
    end
    
    -- Cleanup floating text
    local live_dmg = {}
    for _, d in ipairs(R.damage_numbers) do if now - d.timer < d.life then live_dmg[#live_dmg+1] = d end end
    R.damage_numbers = live_dmg
end)

re.on_frame(function()
    if not draw then return end
    pcall(render_dev_overlay)
    pcall(render_hud_strip)

    -- Floating Damage Numbers
    if C.show_damage_numbers then
        local now = os.clock()
        for _, d in ipairs(R.damage_numbers) do
            local sp = draw.world_to_screen(d.pos)
            if sp then
                local age = now - d.timer
                local ratio = age / d.life
                local y_off = ratio * 50
                local alpha = math.floor((1 - ratio) * 255)
                local col = (alpha << 24) | 0x004444FF -- RED
                draw.text(string.format("-%d", d.dmg), sp.x, sp.y - y_off, col)
            end
        end
    end

    -- Enemy ESP
    if C.enemy_esp and R.player_pos then
        for _, e in ipairs(R.enemies) do
            if e.dist < C.esp_range and not e.dead then
                local sp = draw.world_to_screen(e.pos)
                if sp then
                    draw.text(string.format("%s (%.1fm)", e.name, e.dist), sp.x, sp.y, DC.TEXT_RED)
                end
            end
        end
    end

    -- Item ESP
    if C.item_esp and R.player_pos then
        for _, e in ipairs(R.items) do
            if e.dist < C.esp_range then
                local sp = draw.world_to_screen(e.pos)
                if sp then
                    draw.text(string.format("%s (%.1fm)", e.name, e.dist), sp.x, sp.y, DC.TEXT_CYAN)
                end
            end
        end
    end

    -- EMV Live Object 3D ESP
    pcall(function()
        local cfg = _G.EMV and _G.EMV._overlay_cfg
        if not cfg or not cfg.enabled then return end
        local objs = _G.EMV._overlay_objects
        if not objs or #objs == 0 then return end
        local pp = R.player_pos
        for _, obj in ipairs(objs) do
            local wx, wy, wz = obj.x, obj.y, obj.z
            if obj.gameobj then
                pcall(function()
                    local xf = obj.gameobj:call("get_Transform")
                    if xf then local p = xf:call("get_Position"); if p then wx, wy, wz = p.x, p.y, p.z end end
                end)
            end
            if not wx then goto cont end
            local sp = draw.world_to_screen(Vector3f.new(wx, wy, wz))
            if sp then
                local live_dist = pp and math.sqrt((wx-pp.x)^2 + (wy-pp.y)^2 + (wz-pp.z)^2) or obj.dist
                local name = obj.name or "?"
                if #name > 24 then name = name:sub(1, 23) .. "…" end
                draw.text(name, sp.x, sp.y, DC.TEXT)
                if live_dist then draw.text(string.format("%.1fm", live_dist), sp.x, sp.y + 16, DC.TEXT_GRAY) end
                if obj.guid then draw.text(#obj.guid > 12 and obj.guid:sub(1, 11).."…" or obj.guid, sp.x, sp.y + 32, DC.TEXT_YELLOW) end
            end
            ::cont::
        end
    end)
end)

if log then log.info("[RE3R Dev Trainer] v3.0 Loaded.") end
