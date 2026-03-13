-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- Requiem Trainer â€” UI Module
-- ImGui tab content: player, combat, enemies, inventory, saves, settings
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast = T.mgr, T.toast
local get_scene = T.get_scene
local cfg_save, cfg_flush = T.cfg_save, T.cfg_flush
local vk_name = T.vk_name
local hp_vals, ppos, pxf, php = T.hp_vals, T.ppos, T.pxf, T.php
local dist3 = T.dist3

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Colors
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local CLR = {
    -- Semantic names (ImGui ABGR format)
    ON        = 0xFF44FF88,    -- green: active toggle
    OFF       = 0xFFEEEEFF,    -- light: inactive toggle
    SUCCESS   = 0xFF44FF88,    -- green: positive action
    DANGER    = 0xFF6666FF,    -- red: destructive action
    ACCENT    = 0xFFFFDD88,    -- gold: highlights
    HEAD      = 0xFFEEEEFF,    -- section headers
    CAT       = 0xFFFFDD88,    -- categories
    MUTED     = 0xFF999999,    -- dim text
    WARN      = 0xFFE0E0E0,    -- warnings
    HP_BG     = 0xFF333344,    -- HP bar background
    WHITE     = 0xFFEEEEFF,    -- default text
    GOLD      = 0xFFE0E0E0,    -- secondary accent
}

--- Convert ImGui ABGR color to D2D ARGB (swap R and B channels).
function CLR.to_d2d(col)
    local a = bit.band(bit.rshift(col, 24), 0xFF)
    local b = bit.band(bit.rshift(col, 16), 0xFF)
    local g = bit.band(bit.rshift(col,  8), 0xFF)
    local r = bit.band(col, 0xFF)
    return bit.bor(bit.lshift(a, 24), bit.lshift(r, 16), bit.lshift(g, 8), b)
end

--- Convert D2D ARGB color to ImGui ABGR (swap R and B channels).
function CLR.to_imgui(col)
    return CLR.to_d2d(col)  -- same transformation (symmetric swap)
end

T.CLR = CLR

-- DPI scale factor: base font size 13.0 (ImGui default)
local function ui_scale()
    local ok, fs = pcall(imgui.get_font_size)
    return ok and fs and (fs / 13.0) or 1.0
end
T.ui_scale = ui_scale

-- Shorthand: scale a pixel value for current DPI (respects C.ui_dpi_scale toggle)
local function scaled(px)
    if C.ui_dpi_scale == false then return px end
    return math.floor(px * ui_scale())
end


-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Helpers
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function section(text, color)
    imgui.spacing()
    imgui.spacing()
    imgui.push_style_color(27, color or CLR.CAT) -- ImGuiCol_Separator
    imgui.separator()
    imgui.pop_style_color(1)
    imgui.text_colored("  " .. text, color or CLR.CAT)
    imgui.spacing()
end

local function hdr(text)
    imgui.spacing()
    imgui.spacing()
    imgui.text_colored(text, CLR.HEAD)
    imgui.separator()
    imgui.spacing()
end

local function tog(label, key, off_fn, hk_key, tip)
    local v = C[key]
    local display = label
    if hk_key then
        local vk = C[hk_key]
        if vk and vk > 0 then
            display = "[" .. vk_name(vk) .. "] " .. label
        end
    end
    imgui.push_style_color(0, v and CLR.ON or CLR.OFF)
    local ch, nv = imgui.checkbox(display, v)
    imgui.pop_style_color(1)
    if tip and imgui.is_item_hovered() then imgui.set_tooltip(tip) end
    if ch then
        C[key] = nv
        if not nv and off_fn then pcall(off_fn) end
        pcall(cfg_save)
    end
end

local function hp_bar(cur, mx, w)
    if not cur or not mx or mx <= 0 then imgui.text_colored("HP: ---", CLR.MUTED); return end
    local r = math.max(0, math.min(1, cur / mx))
    imgui.progress_bar(r, {w, 16}, ("%d / %d"):format(cur, mx))
end
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Player
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_player()
    -- â”€â”€ Health â”€â”€
    section("Health", CLR.CAT)
    do
        local v = C.god_mode
        local display = "God Mode"
        local vk = C.hk_god
        if vk and vk > 0 then display = "[" .. vk_name(vk) .. "] " .. display end
        imgui.push_style_color(0, v and CLR.ON or CLR.OFF)
        local ch, nv = imgui.checkbox(display, v)
        imgui.pop_style_color(1)
        if ch then
            C.god_mode = nv
            if not nv then pcall(T.god_off) end
            pcall(cfg_save)
        end
    end
    tog("Stealth", "stealth", nil, nil, "Enemies cannot see, hear, or touch you")
    tog("Lock HP", "hp_lock")
    if C.hp_lock then
        imgui.same_line()
        local ch, v = imgui.drag_int("##hplv", C.hp_lock_val, 1, 1, 99999)
        if ch then C.hp_lock_val = v end
    end
    local c, m = hp_vals()
    imgui.text("Health:")
    imgui.same_line()
    hp_bar(c, m, 200)

    -- â”€â”€ Movement â”€â”€
    section("Movement", CLR.CAT)
    tog("Player Speed", "player_speed_on", T.reset_speed, "hk_speed")
    if C.player_speed_on then
        local presets = { {1.0, "Default"}, {1.5, "1.5x"}, {2.0, "2x"}, {2.5, "2.5x"}, {3.0, "3x"} }
        for i, p in ipairs(presets) do
            if i > 1 then imgui.same_line() end
            if imgui.button(p[2] .. "##spd") then
                C.walk_speed = p[1]; C.run_speed = p[1]; pcall(cfg_save)
            end
        end
        local ch_w, vw = imgui.slider_float("Walk Speed##ps", C.walk_speed, 0.5, 5.0, "%.2fx")
        if ch_w then C.walk_speed = vw; pcall(cfg_save) end
        local ch_r, vr = imgui.slider_float("Run Speed##ps", C.run_speed, 0.5, 5.0, "%.2fx")
        if ch_r then C.run_speed = vr; pcall(cfg_save) end
    end
    imgui.spacing()
    if imgui.button("Bookmark [B]") then
        local p = ppos(); if p then R.bookmark = p end
    end
    imgui.same_line()
    if R.bookmark then
        if imgui.button("Warp [N]") then
            pcall(function() local xf = pxf(); if xf then xf:call("set_Position", Vector3f.new(R.bookmark.x, R.bookmark.y, R.bookmark.z)) end end)
        end
        imgui.same_line()
        imgui.text_colored(("%.0f, %.0f, %.0f"):format(R.bookmark.x, R.bookmark.y, R.bookmark.z), CLR.MUTED)
    else
        imgui.text_colored("No bookmark", CLR.MUTED)
    end
    if imgui.tree_node("Position##pos_tree") then
        local pos = ppos()
        if pos then
            local ch_x, vx = imgui.drag_float("X##pos", pos.x, 0.5, -99999, 99999, "%.1f")
            local ch_y, vy = imgui.drag_float("Y##pos", pos.y, 0.5, -99999, 99999, "%.1f")
            local ch_z, vz = imgui.drag_float("Z##pos", pos.z, 0.5, -99999, 99999, "%.1f")
            if ch_x or ch_y or ch_z then
                pcall(function()
                    local xf = pxf()
                    if xf then xf:call("set_Position", Vector3f.new(ch_x and vx or pos.x, ch_y and vy or pos.y, ch_z and vz or pos.z)) end
                end)
            end
            tog("Freeze X", "freeze_x"); imgui.same_line(); tog("Freeze Y", "freeze_y"); imgui.same_line(); tog("Freeze Z", "freeze_z")
        else imgui.text_colored("N/A (no player)", CLR.MUTED) end
        imgui.tree_pop()
    end

    -- â”€â”€ NoClip â”€â”€
    section("NoClip", CLR.CAT)
    do
        local nc_label = "NoClip"
        local vk = C.hk_noclip
        if vk and vk > 0 then nc_label = "[" .. vk_name(vk) .. "] " .. nc_label end
        local ch, nv = imgui.checkbox(nc_label, C.noclip)
        if ch then
            if nv then if T.noclip_on then pcall(T.noclip_on) end
            else if T.noclip_off then pcall(T.noclip_off) end end
            pcall(cfg_save)
        end
        if C.noclip then imgui.same_line(); imgui.text_colored("ACTIVE", CLR.ON) end
    end
    if C.noclip and T.nc_state and T.nc_state.pos then
        local np = T.nc_state.pos
        local ch_x, vx = imgui.drag_float("X##nc_pos", np.x, 0.5, -99999, 99999, "%.2f")
        local ch_y, vy = imgui.drag_float("Y##nc_pos", np.y, 0.5, -99999, 99999, "%.2f")
        local ch_z, vz = imgui.drag_float("Z##nc_pos", np.z, 0.5, -99999, 99999, "%.2f")
        if ch_x then T.nc_state.pos = Vector3f.new(vx, np.y, np.z) end
        if ch_y then T.nc_state.pos = Vector3f.new(np.x, vy, np.z) end
        if ch_z then T.nc_state.pos = Vector3f.new(np.x, np.y, vz) end
        if imgui.button("Copy NC Pos##nc") then
            local s = string.format("%.4f, %.4f, %.4f", np.x, np.y, np.z)
            pcall(function() imgui.set_clipboard(s) end)
            toast("Copied: " .. s, 0xFFFFCC44)
        end
    end
    if imgui.tree_node("NoClip Settings##ncs") then
        local ch_s, vs = imgui.slider_float("Speed##nc", C.noclip_speed, 1.0, 50.0, "%.1f")
        if ch_s then C.noclip_speed = vs; pcall(cfg_save) end
        local ch_v, vv = imgui.slider_float("Vert Speed##nc", C.noclip_vert_speed, 1.0, 50.0, "%.1f")
        if ch_v then C.noclip_vert_speed = vv; pcall(cfg_save) end
        local ch_b, vb = imgui.slider_float("Boost##nc", C.noclip_boost, 1.0, 10.0, "%.1fx")
        if ch_b then C.noclip_boost = vb; pcall(cfg_save) end
        local ch_sl, vsl = imgui.slider_float("Slow##nc", C.noclip_slow, 0.05, 1.0, "%.2fx")
        if ch_sl then C.noclip_slow = vsl; pcall(cfg_save) end
        tog("Anti-Death", "noclip_anti_death", nil, nil, "Prevent player death while noclipping")
        tog("No Fall Damage", "noclip_no_fall", nil, nil, "Suppress fall system to prevent fall death")
        local ch_y, vy = imgui.slider_float("Yaw Offset##nc", C.noclip_yaw_offset, 0, 360, "%.0fÂ°")
        if ch_y then C.noclip_yaw_offset = vy; pcall(cfg_save) end
        imgui.tree_pop()
    end

    -- â”€â”€ Overlay â”€â”€
    section("Overlay", CLR.CAT)
    tog("Show IGT", "show_igt")
    if C.show_igt and R.igt_text and R.igt_text ~= "" then
        imgui.same_line(); imgui.text_colored(R.igt_text, CLR.MUTED)
    end
    tog("Enemy HP Panel", "enemy_panel", nil, "hk_overlay")
    if C.enemy_panel then
        tog("Show Rank", "show_rank")
        tog("Show Bars", "show_bars"); imgui.same_line(); tog("Show %", "show_pct")
        tog("Distance Color", "dist_color"); imgui.same_line(); tog("Hide Dead", "hide_dead")
        tog("Filter Full HP", "filter_full_hp")
        if imgui.tree_node("Panel Layout##ep_layout") then
            local ch1, v1 = imgui.drag_int("Panel X##ep", C.panel_x, 1, 0, 8000); if ch1 then C.panel_x = v1; pcall(cfg_save) end
            local ch2, v2 = imgui.drag_int("Panel Y##ep", C.panel_y, 1, 0, 8000); if ch2 then C.panel_y = v2; pcall(cfg_save) end
            local ch4, v4 = imgui.drag_int("Panel Width##ep", C.panel_w, 1, 200, 2000); if ch4 then C.panel_w = v4; pcall(cfg_save) end
            local ch3, v3 = imgui.slider_int("Rows##ep", C.panel_rows, 1, 20); if ch3 then C.panel_rows = v3; pcall(cfg_save) end
            local ch5, v5 = imgui.drag_int("Bar Width##ep", C.panel_bar_w, 1, 20, 1200); if ch5 then C.panel_bar_w = v5; pcall(cfg_save) end
            local ch6, v6 = imgui.drag_int("Bar Height##ep", C.panel_bar_h, 1, 2, 60); if ch6 then C.panel_bar_h = v6; pcall(cfg_save) end
            imgui.tree_pop()
        end
    end

    -- ── Perspective Switcher ──
    section("Perspective Switcher", CLR.CAT)
    imgui.indent(scaled(6))
    if imgui.button("  Toggle 1P / 3P  ##toggle_pov") then
        if T.toggle_perspective then pcall(T.toggle_perspective) end
    end
    if imgui.is_item_hovered() then imgui.set_tooltip("Switch between First-Person and Third-Person camera") end
    do
        local mode = nil
        if T.get_current_view_mode then mode = T.get_current_view_mode() end
        if mode ~= nil then
            local label = mode == 0 and "Third-Person (TPS)" or (mode == 1 and "First-Person (FPS)" or ("Mode " .. tostring(mode)))
            imgui.same_line()
            imgui.text_colored("  Current: " .. label, CLR.ON)
        end
    end
    imgui.unindent(scaled(6))
    imgui.spacing()

    -- ── Costume Changer ──
    section("Costume Changer", CLR.CAT)
    imgui.indent(scaled(6))
    if T._costume_state then
        local cs = T._costume_state
        imgui.text_colored(cs.status, CLR.MUTED)
        imgui.spacing()
        if imgui.button("  Scan Players  ##costume_scan") then
            if T.costume_scan_players then pcall(T.costume_scan_players) end
        end
        for _, key in ipairs({"leon", "grace"}) do
            local pi = cs.players[key]
            if pi and #pi.costumes > 0 then
                imgui.spacing()
                imgui.separator()
                imgui.spacing()
                local cur_display = pi.current_name or "Unknown"
                if T.costume_display_name then cur_display = T.costume_display_name(pi.label, pi.current_name) end
                imgui.text_colored(pi.label .. " — Current: " .. cur_display, CLR.ON)
                local labels = {}
                local name_cnt = {}
                for _, c in ipairs(pi.costumes) do name_cnt[c.display] = (name_cnt[c.display] or 0) + 1 end
                for i, c in ipairs(pi.costumes) do
                    local lbl = c.display
                    if name_cnt[c.display] > 1 and c.name then
                        lbl = lbl .. "  (" .. c.name .. ")"
                    end
                    lbl = lbl .. "##cos_" .. key .. "_" .. i
                    labels[#labels + 1] = lbl
                end
                imgui.set_next_item_width(scaled(220))
                local ch, v = imgui.combo("##costume_" .. key, pi.selected, labels)
                if ch then pi.selected = v end
                imgui.same_line()
                imgui.push_style_color(21, 0xFF336644)
                imgui.push_style_color(22, 0xFF448855)
                imgui.push_style_color(0, 0xFFEEEEFF)
                if imgui.button("  Apply  ##cos_" .. key) then
                    if T.costume_apply then pcall(T.costume_apply, pi) end
                end
                imgui.pop_style_color(3)
            end
        end
        if not cs.players.leon and not cs.players.grace then
            imgui.spacing()
            imgui.text_colored("Load a game and press Scan Players", CLR.MUTED)
        end
    else
        imgui.text_colored("Costume module not loaded", CLR.MUTED)
    end
    imgui.unindent(scaled(6))

end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Combat
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_combat()
    section("Weapons", CLR.CAT)
    tog("One-Hit Kill", "ohk", nil, nil, "Multiply all damage dealt to enemies by 9999x")
    tog("No Recoil", "no_recoil", nil, nil, "Remove all camera recoil and aim shake")
    tog("No Reload", "no_reload", nil, nil, "Never consume ammo when firing")
    tog("Rapid Fire", "rapid_fire", nil, nil, "All weapons fire at maximum rate in full auto")
    tog("Auto Parry", "auto_parry", nil, nil, "Automatically parry all incoming attacks")
    tog("Super Accuracy", "super_accuracy", nil, nil, "Instant crosshair focus â€” no bloom")
    tog("Headshot Damage Boost", "headshot_boost_on", nil, nil, "Multiplies headshot damage (when OHK is off)")
    if C.headshot_boost_on then
        local ch, v = imgui.slider_float("Headshot Mult.##hsmult", C.headshot_mult, 1.0, 10.0, "%.1fx")
        if ch then C.headshot_mult = v; pcall(cfg_save) end
    end
    section("Damage Numbers", CLR.CAT)
    tog("Show Damage Numbers", "show_damage")
    if C.show_damage then
        imgui.spacing()
        local ch, v
        ch, v = imgui.slider_int("Font Size##dmg", C.dmg_font_size, 14, 60)
        if ch then C.dmg_font_size = v end
        ch, v = imgui.slider_int("Shadow##dmg", C.dmg_shadow, 0, 6)
        if ch then C.dmg_shadow = v end
        ch, v = imgui.slider_float("Duration##dmg", C.dmg_duration, 0.3, 3.0, "%.1fs")
        if ch then C.dmg_duration = v end
        ch, v = imgui.slider_float("Float Speed##dmg", C.dmg_speed, 20, 200, "%.0f px/s")
        if ch then C.dmg_speed = v end
        tog("Combine Multi-Hit", "dmg_combine", nil, nil, "Sum shotgun pellets into one number")
        tog("Enable Colors", "dmg_color_on")
        if C.dmg_color_on then
            ch, v = imgui.slider_int("Big Hit (Orange)##dmg", C.dmg_thresh_big, 50, 1000)
            if ch then C.dmg_thresh_big = v end
            ch, v = imgui.slider_int("Huge Hit (Red)##dmg", C.dmg_thresh_huge, 100, 5000)
            if ch then C.dmg_thresh_huge = v end
        end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Enemies
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_enemies()
    section("3D ESP", CLR.CAT)
    tog("3D ESP (Above Head)", "enemy_esp", nil, nil, "Show name + HP bar above each enemy in 3D")
    if C.enemy_esp then
        local ch, v
        ch, v = imgui.slider_float("ESP Range##esp", C.esp_range, 5, 100, "%.0fm")
        if ch then C.esp_range = v; pcall(cfg_save) end
        ch, v = imgui.slider_int("Bar Width##esp", C.esp_bar_w, 50, 400)
        if ch then C.esp_bar_w = v; pcall(cfg_save) end
        ch, v = imgui.slider_int("Bar Height##esp", C.esp_bar_h, 4, 30)
        if ch then C.esp_bar_h = v; pcall(cfg_save) end
        ch, v = imgui.slider_int("Font Size##esp", C.esp_font, 10, 36)
        if ch then C.esp_font = v; pcall(cfg_save) end
        ch, v = imgui.slider_float("Height Offset##esp", C.esp_world_y, 0.5, 5.0, "%.1f")
        if ch then C.esp_world_y = v; pcall(cfg_save) end
        tog("Alpha Fade", "esp_alpha", nil, nil, "Fade out distant ESP markers")
        tog("Scale by Distance", "esp_scale", nil, nil, "Shrink bars for distant enemies")
        tog("Only In Sight", "esp_in_sight", nil, nil, "Hide ESP for enemies behind you")
        tog("Hide Dead", "hide_dead")
    end
    section("Enemy Control", CLR.CAT)
    tog("Freeze All Enemies", "motion_freeze", T.freeze_enemies, "hk_freeze")
    tog("Enemy Speed Override", "enemy_speed_on", nil, nil, "Change enemy walk/run speed")
    if C.enemy_speed_on then
        local ch, v = imgui.slider_float("Enemy Speed##espd", C.enemy_speed, 0.1, 5.0, "%.2fx")
        if ch then C.enemy_speed = v; pcall(cfg_save) end
    end
    imgui.spacing()
    if imgui.button("Refresh") then R.enemies = T.scan_enemies() end
    imgui.same_line()
    imgui.text_colored(("%d tracked"):format(#R.enemies), CLR.MUTED)
    if #R.enemies > 0 and imgui.tree_node("Enemy List") then
        for i, e in ipairs(R.enemies) do
            if i > 30 then imgui.text_colored("...", CLR.MUTED); break end
            local header
            if C.show_guid_titles and e.guid then
                header = string.format("%s  HP:%d/%d  (%.0fm)###enemy_%d", e.guid, e.hp, e.mhp, e.dist, i)
            else
                header = string.format("%s  HP:%d/%d  (%.0fm)###enemy_%d", e.name, e.hp, e.mhp, e.dist, i)
            end
            if imgui.tree_node(header) then
                imgui.text(("Name:     %s"):format(e.name))
                if e.go_name then imgui.text(("Object:   %s"):format(e.go_name)) end
                if e.kind_type then imgui.text(("Type:     %s"):format(e.kind_type)) end
                imgui.text(("HP:       %d / %d"):format(e.hp, e.mhp))
                if e.lv or e.mlv then imgui.text(("HP Level: %s / %s"):format(tostring(e.lv or "?"), tostring(e.mlv or "?"))) end
                imgui.text(("Distance: %.1fm"):format(e.dist))
                if e.pos then imgui.text(("Position: %.3f, %.3f, %.3f"):format(e.pos.x, e.pos.y, e.pos.z)) end
                imgui.text(("Dead:     %s"):format(tostring(e.dead or false)))
                if e.guid then
                    imgui.text(("GUID:     %s"):format(e.guid))
                    imgui.same_line()
                    if imgui.button("Copy##eguid_" .. i) then pcall(function() imgui.set_clipboard(e.guid) end); toast("GUID: " .. e.guid, 0xFF44FF88) end
                end
                if e.go_addr then
                    imgui.text(("Path:     %s"):format(e.go_addr))
                    imgui.same_line()
                    if imgui.button("Copy##epath_" .. i) then pcall(function() imgui.set_clipboard(e.go_addr) end); toast("Path: " .. e.go_addr, 0xFF44FF88) end
                end
                if e.spawn_id then
                    imgui.text(("SpawnID:  %s"):format(e.spawn_id))
                    imgui.same_line()
                    if imgui.button("Copy##esid_" .. i) then toast("SpawnID: " .. e.spawn_id, 0xFF44FF88) end
                end
                imgui.tree_pop()
            end
        end
        imgui.tree_pop()
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Item Indicator
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_item_indicator()
    tog("Show Item Indicators", "show_items")
    if C.show_items then
        section("Source Type", CLR.CAT)
        tog("ItemCore (Pickups)", "show_item_core", nil, nil, "Direct item pickups on the ground")
        tog("ItemSpawner (Triggers)", "show_item_spawner", nil, nil, "Items from drawers, enemy drops, etc.")
        section("Category", CLR.CAT)
        tog("Key Items", "show_key_items")
        tog("Boxes / Barrels", "show_box_items")
        tog("Mr. Raccoon", "show_raccoon")
        imgui.spacing()
        local ch_d, vd = imgui.slider_float("Visible Distance##itm", C.item_distance, 5, 200, "%.0fm")
        if ch_d then C.item_distance = vd; pcall(cfg_save) end
        local ch_s, vs = imgui.slider_float("Scan Interval##itm", C.item_scan_interval, 0.5, 5.0, "%.1fs")
        if ch_s then C.item_scan_interval = vs; pcall(cfg_save) end
        local ch_f, vf = imgui.slider_int("Font Size##itm", C.item_font_size, 12, 48)
        if ch_f then C.item_font_size = vf; pcall(cfg_save) end
        imgui.spacing()
        if imgui.tree_node("Item Colors##itm_col") then
            -- Preset color palette (avoids raw RGBA editor)
            local PRESETS = {
                { name = "Red",     color = 0xFF0000FF },
                { name = "Green",   color = 0xFF00CC44 },
                { name = "Blue",    color = 0xFFFF8800 },
                { name = "Cyan",    color = 0xFFFFDD00 },
                { name = "Yellow",  color = 0xFF00FFFF },
                { name = "Orange",  color = 0xFF00AAFF },
                { name = "Gold",    color = 0xFF00D4FF },
                { name = "Pink",    color = 0xFFBB77FF },
                { name = "Magenta", color = 0xFFFF44FF },
                { name = "Purple",  color = 0xFFCC4488 },
                { name = "Gray",    color = 0xFF808080 },
                { name = "White",   color = 0xFFFFFFFF },
            }
            local preset_names = {}
            for i, p in ipairs(PRESETS) do preset_names[i] = p.name end

            local function color_row(label, cfg_key)
                local cur = C[cfg_key] or 0xFFFFFFFF
                -- Find matching preset index
                local sel_idx = #PRESETS
                for i, p in ipairs(PRESETS) do
                    if p.color == cur then sel_idx = i; break end
                end
                -- Colored label
                imgui.text_colored("■", cur); imgui.same_line()
                local changed, new_idx = imgui.combo(label .. "##cc", sel_idx, preset_names)
                if changed then
                    C[cfg_key] = PRESETS[new_idx].color
                    pcall(cfg_save)
                end
            end

            imgui.text_colored("Category Colors", CLR.HEAD)
            color_row("Key Item",    "color_item_key")
            color_row("Box",         "color_item_box")
            color_row("Raccoon",     "color_item_raccoon")
            imgui.spacing()
            imgui.text_colored("Source Colors", CLR.HEAD)
            color_row("Pickup",      "color_item_core")
            color_row("Spawner",     "color_item_spawner")
            imgui.tree_pop()
        end
        local count = 0
        local sorted_items = {}
        for addr, itm in pairs(R.item_indicators) do count = count + 1; sorted_items[#sorted_items + 1] = { addr = addr, data = itm } end
        imgui.spacing(); imgui.separator()
        if count > 0 and imgui.tree_node(("Item List (%d)###item_list"):format(count)) then
            table.sort(sorted_items, function(a, b) return (a.data.dist or 999) < (b.data.dist or 999) end)
            for i, entry in ipairs(sorted_items) do
                if i > 50 then imgui.text_colored("...", CLR.MUTED); break end
                local itm = entry.data
                local cat_tag = itm.category or "Item"
                local header
                if C.show_guid_titles and itm.guid then
                    header = string.format("[%s] %s  (%.0fm)###itm_%s", cat_tag, itm.guid, itm.dist or 0, tostring(entry.addr))
                else
                    header = string.format("[%s] %s  (%.0fm)###itm_%s", cat_tag, itm.name or "?", itm.dist or 0, tostring(entry.addr))
                end
                if imgui.tree_node(header) then
                    imgui.text(("Name:     %s"):format(itm.name or "?"))
                    if itm.go_name then imgui.text(("Object:   %s"):format(itm.go_name)) end
                    imgui.text(("Category: %s"):format(itm.category or "?"))
                    if itm.source then
                        local src_label = itm.source == "spawner" and "ItemSpawner" or "ItemCore"
                        local src_col = itm.source == "spawner" and 0xFFFF44FF or 0xFF00DDFF
                        imgui.text("Source:   "); imgui.same_line(); imgui.text_colored(src_label, src_col)
                    end
                    imgui.text(("Distance: %.1fm"):format(itm.dist or 0))
                    if itm.pos then imgui.text(("Position: %.3f, %.3f, %.3f"):format(itm.pos.x, itm.pos.y, itm.pos.z)) end
                    if itm.guid then
                        imgui.text(("GUID:     %s"):format(itm.guid))
                        imgui.same_line()
                        if imgui.button("Copy##iguid_" .. tostring(entry.addr)) then pcall(function() imgui.set_clipboard(itm.guid) end); toast("GUID: " .. itm.guid, 0xFF44FF88) end
                    end
                    if itm.go_addr then
                        imgui.text(("Path:     %s"):format(itm.go_addr))
                        imgui.same_line()
                        if imgui.button("Copy##ipath_" .. tostring(entry.addr)) then pcall(function() imgui.set_clipboard(itm.go_addr) end); toast("Path: " .. itm.go_addr, 0xFF44FF88) end
                    end
                    if itm.is_key then imgui.text_colored("â˜… Key Item", 0xFF4444FF) end
                    imgui.tree_pop()
                end
            end
            imgui.tree_pop()
        elseif count == 0 then
            imgui.text_colored("No items in range", CLR.MUTED)
        end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Inventory / Weapons
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_weapons()
    tog("Infinite Ammo", "inf_ammo", T.arsenal_off)
    tog("Indestructible Melee", "inf_melee", T.arsenal_off)
    tog("Infinite Axe/Knife Durability", "inf_durability", nil, nil, "Axe and knife handles never break")
    tog("Infinite Grenades", "inf_grenades")
    tog("Infinite Injector", "inf_injector", nil, nil, "Hemolytic Injector never consumed")
    tog("No Sway", "no_sway", nil, nil, "Suppress all camera sway and shake effects")
    tog("Unlock All Recipes", "unlock_recipes", nil, nil, "Show all crafting recipes")
    section("Remote Storage", CLR.CAT)
    tog("Enable Remote Storage", "remote_storage", nil, nil, "Open the item box from anywhere")
    if C.remote_storage then
        if imgui.button("Open / Close Item Box") then pcall(T.toggle_remote_storage) end
    end

    -- â”€â”€ Item Spawner â”€â”€
    section("Item Spawner", CLR.CAT)
    if T._itemdb then
        local db = T._itemdb
        if #db.items == 0 then
            if T.itemdb_try_build then pcall(T.itemdb_try_build) end
            imgui.text_colored("Loading item database... load a save first.", CLR.MUTED)
        else
            -- Sort items alphabetically once
            if not db._sorted then
                table.sort(db.items, function(a, b) return a.name < b.name end)
                db._sorted = true
            end

            -- Category filter
            imgui.set_next_item_width(scaled(150))
            local cat_idx = 1
            for i, c in ipairs(db.categories) do
                if c == db.sel_cat then cat_idx = i end
            end
            local cc, cv = imgui.combo("Category##ie_cat", cat_idx, db.categories)
            if cc then db.sel_cat = db.categories[cv] or "All"; db._filtered = nil end

            -- Search filter
            imgui.set_next_item_width(-1)
            local sc, sv = imgui.input_text("Search##ie_search", db.search)
            if sc then db.search = sv; db._filtered = nil end
            imgui.spacing()

            -- Build filtered list (cached until filter changes)
            local srch = (db.search or ""):lower()
            if not db._filtered then
                db._filtered = {}
                db._filtered_labels = {}
                -- First pass: count name occurrences to detect duplicates
                local name_counts = {}
                for _, item in ipairs(db.items) do
                    local cat_ok = (db.sel_cat == "All" or db.sel_cat == item.category)
                    local srch_ok = (srch == "" or item.name:lower():find(srch, 1, true))
                    if cat_ok and srch_ok then
                        name_counts[item.name] = (name_counts[item.name] or 0) + 1
                    end
                end
                -- Second pass: build list with unique labels
                for _, item in ipairs(db.items) do
                    local cat_ok = (db.sel_cat == "All" or db.sel_cat == item.category)
                    local srch_ok = (srch == "" or item.name:lower():find(srch, 1, true))
                    if cat_ok and srch_ok then
                        db._filtered[#db._filtered + 1] = item
                        local lbl = item.name
                        -- For duplicate names, show the internal field name to differentiate
                        if name_counts[item.name] and name_counts[item.name] > 1 then
                            local suffix = item.id_text:gsub("^Item_", ""):gsub("_", " ")
                            lbl = lbl .. "  (" .. suffix .. ")"
                        end
                        if item.category and item.category ~= "Other" then
                            lbl = lbl .. "  [" .. item.category .. "]"
                        end
                        lbl = lbl .. "##" .. item.id_text
                        db._filtered_labels[#db._filtered_labels + 1] = lbl
                    end
                end
            end

            -- Item selector combo
            imgui.text_colored(#db._filtered .. " / " .. #db.items .. " items", CLR.MUTED)
            db._sel_idx = db._sel_idx or 1
            if db._sel_idx > #db._filtered then db._sel_idx = 1 end
            imgui.set_next_item_width(-1)
            local ic, iv = imgui.combo("##ie_item", db._sel_idx, db._filtered_labels)
            if ic then db._sel_idx = iv end
            imgui.spacing()

            -- Selected item info + actions
            local sel = db._filtered[db._sel_idx]
            if sel then
                imgui.text_colored("Selected: " .. sel.name, CLR.ON)
                if sel.caption and sel.caption ~= "" then
                    imgui.text_colored(sel.caption, CLR.MUTED)
                end
                imgui.spacing()

                -- Quantity + buttons
                db._qty = db._qty or 1
                if sel.base_cap > 1 then
                    imgui.set_next_item_width(scaled(120))
                    local qc, qv = imgui.slider_int("Qty##ie_qty", db._qty, 1, sel.base_cap)
                    if qc then db._qty = qv end
                    imgui.same_line()
                end
                if imgui.button("  Add  ##ie_add") then
                    if T.item_spawn_add then pcall(T.item_spawn_add, sel, db._qty or 1) end
                end
                if sel.base_cap > 1 then
                    imgui.same_line()
                    if imgui.button("  Max  ##ie_max") then
                        if T.item_spawn_add then pcall(T.item_spawn_add, sel, nil) end
                    end
                end
            else
                imgui.text_colored("No items match filter", CLR.MUTED)
            end
        end
    else
        imgui.text_colored("Item spawner module not loaded", CLR.MUTED)
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Saves
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_saves()
    tog("Unlimited Saves", "unlimited_saves", nil, nil, "Save count never increases â€” unlimited manual saves")
    section("Quick Actions", CLR.CAT)
    imgui.push_style_color(0, 0xFF44BB44)
    if imgui.button("  Quick Save [" .. vk_name(C.hk_save) .. "]  ") then
        local off = C.quick_save_slot or 0
        local save_ok = false
        pcall(function() if T.init_save() then save_ok = T.do_save(3, off) end end)
        if save_ok then toast("Quick Saved (slot " .. off .. ")", 0xFF44BB44)
        else toast("Save failed", 0xFFFF6666) end
    end
    imgui.pop_style_color(1)
    imgui.same_line()
    imgui.push_style_color(0, 0xFF4488DD)
    if imgui.button("  Quick Load [" .. vk_name(C.hk_load) .. "]  ") then
        local off = C.quick_load_slot or 0
        local load_ok = false
        pcall(function() if T.init_save() then load_ok = T.do_load(3, off) end end)
        if load_ok then toast("Loading slot " .. off .. "...", 0xFF4488DD)
        else toast("Load failed", 0xFFFF6666) end
    end
    imgui.pop_style_color(1)
    imgui.spacing()
    local ch_qs, v_qs = imgui.slider_int("Quick Save Slot##qs", C.quick_save_slot or 0, 0, 19)
    if ch_qs then C.quick_save_slot = v_qs; pcall(cfg_save) end
    local ch_ql, v_ql = imgui.slider_int("Quick Load Slot##ql", C.quick_load_slot or 0, 0, 19)
    if ch_ql then C.quick_load_slot = v_ql; pcall(cfg_save) end
    section("Slot Browser", CLR.CAT)
    if imgui.button("Refresh") then T.refresh_saves() end
    imgui.same_line()
    local slot_count = #R.save_slots
    if slot_count > 0 then imgui.text_colored(slot_count .. " slots found", CLR.ON)
    else imgui.text_colored("No slots  (click Refresh)", CLR.MUTED) end
    if R.save_time then imgui.same_line(); imgui.text_colored("  last: " .. R.save_time, CLR.MUTED) end
    imgui.spacing()
    if not C.slot_bindings then C.slot_bindings = {} end
    for i, s in ipairs(R.save_slots) do
        local icon = s.auto_save and "[A]" or "[M]"
        local slot_label = icon .. " Slot " .. s.off
        if s.difficulty and s.difficulty ~= "?" and s.difficulty ~= "" then slot_label = slot_label .. "  |  " .. s.difficulty end
        if s.ng_plus then slot_label = slot_label .. "  [NG+]" end
        local bind_key = s.cat .. "_" .. s.off
        local bind = C.slot_bindings[bind_key] or {}
        local bind_tags = ""
        if bind.save and bind.save > 0 then bind_tags = bind_tags .. " [S:" .. vk_name(bind.save) .. "]" end
        if bind.load and bind.load > 0 then bind_tags = bind_tags .. " [L:" .. vk_name(bind.load) .. "]" end
        slot_label = slot_label .. bind_tags
        if imgui.tree_node(slot_label .. "###sv" .. i) then
            if s.objective and s.objective ~= "" then imgui.text_colored("  Objective:", CLR.MUTED); imgui.same_line(); imgui.text(s.objective) end
            if s.datetime and s.datetime ~= "" then imgui.text_colored("  Date:", CLR.MUTED); imgui.same_line(); imgui.text(s.datetime) end
            if s.ng_plus ~= nil then imgui.text_colored("  Mode:", CLR.MUTED); imgui.same_line(); imgui.text(s.ng_plus and "New Game+" or "Standard") end
            imgui.spacing()
            imgui.push_style_color(0, 0xFF44BB44)
            if imgui.button("  Save  ##sv" .. i) then T.do_save(s.cat, s.off); T.refresh_saves() end
            imgui.pop_style_color(1)
            imgui.same_line()
            imgui.push_style_color(0, 0xFF4488DD)
            if imgui.button("  Load  ##ld" .. i) then pcall(function() if T.init_save() then T.do_load(s.cat, s.off) end end) end
            imgui.pop_style_color(1)
            imgui.spacing()
            imgui.text_colored("Hotkeys:", CLR.MUTED)
            local is_bind_save = (T.hk_listening == "slot_save_" .. bind_key)
            local is_bind_load = (T.hk_listening == "slot_load_" .. bind_key)
            if is_bind_save then imgui.text_colored("  Press key for SAVE... (Esc=cancel)", 0xFF44FFFF)
            else
                local sv_label = (bind.save and bind.save > 0) and ("[" .. vk_name(bind.save) .. "]##ssv_" .. i) or ("[Bind]##ssv_" .. i)
                if imgui.button(sv_label) then T.hk_listening = "slot_save_" .. bind_key end
                if bind.save and bind.save > 0 then imgui.same_line(); if imgui.button("X##xsv" .. i) then bind.save = 0; C.slot_bindings[bind_key] = bind; pcall(cfg_save) end end
                imgui.same_line(); imgui.text("Save Hotkey")
            end
            if is_bind_load then imgui.text_colored("  Press key for LOAD... (Esc=cancel)", 0xFF44FFFF)
            else
                local ld_label = (bind.load and bind.load > 0) and ("[" .. vk_name(bind.load) .. "]##sld_" .. i) or ("[Bind]##sld_" .. i)
                if imgui.button(ld_label) then T.hk_listening = "slot_load_" .. bind_key end
                if bind.load and bind.load > 0 then imgui.same_line(); if imgui.button("X##xld" .. i) then bind.load = 0; C.slot_bindings[bind_key] = bind; pcall(cfg_save) end end
                imgui.same_line(); imgui.text("Load Hotkey")
            end
            imgui.tree_pop()
        end
    end
    imgui.spacing()
    imgui.text_colored("Tip: Always backup saves before overwriting!", CLR.MUTED)
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Items
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_items()
    if imgui.button("Scan Inventory") then R.items = T.scan_items() end
    imgui.same_line()
    imgui.text_colored(("%d items"):format(#R.items), CLR.MUTED)
    for i, item in ipairs(R.items) do
        if i > 80 then imgui.text_colored("...", CLR.MUTED); break end
        local lbl = ("[%d] %s  x%d###it%d"):format(item.id, item.name, item.count, i)
        if imgui.tree_node(lbl) then
            if item.ctx then
                local ch, nv = imgui.drag_int("Qty##it" .. i, item.count, 1, 0, item.max)
                if ch then pcall(function() item.ctx:call("set_Stack", nv) end); pcall(function() item.ctx:call("set_Num", nv) end); item.count = nv end
            end
            imgui.tree_pop()
        end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- Press-to-Bind Scanner
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function hk_scanner()
    if not T.hk_listening then return end
    for vk = 0x08, 0xFF do
        if vk ~= 0x01 and vk ~= 0x02 and vk ~= 0x04
           and vk ~= 0x10 and vk ~= 0x11 and vk ~= 0x12 then
            local ok, down = pcall(function() return reframework:is_key_down(vk) end)
            if ok and down then
                if vk == 0x1B then T.hk_listening = nil
                else
                    local listen_key = T.hk_listening
                    local slot_type, slot_key = listen_key:match("^slot_(save)_(.+)$")
                    if not slot_type then slot_type, slot_key = listen_key:match("^slot_(load)_(.+)$") end
                    if slot_type and slot_key then
                        if not C.slot_bindings then C.slot_bindings = {} end
                        if not C.slot_bindings[slot_key] then C.slot_bindings[slot_key] = {} end
                        C.slot_bindings[slot_key][slot_type] = vk
                    else
                        C[listen_key] = vk
                    end
                    pcall(cfg_save); T.hk_listening = nil
                end
                break
            end
        end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Settings
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_settings()
    -- â”€â”€ Game Options â”€â”€
    section("Game Options", CLR.CAT)
    tog("Show All Items on Map", "map_reveal", nil, nil, "Reveal all undiscovered items on map")
    tog("Highlight Items & Interactables", "highlight_items", nil, nil, "Show interact icons at any distance")
    tog("Disable Film Grain", "disable_film_grain", function()
        pcall(function() local rm = mgr("app.RenderingManager"); if rm then rm:call("set__IsFilmGrainCustomFilterEnable", true) end end)
    end, nil, "Remove the film grain post-processing effect")
    tog("Auto-Skip Cutscenes", "skip_cutscenes", nil, "hk_skip", "Automatically skip all skippable cutscenes as soon as they start")
    if C.skip_cutscenes then
        imgui.same_line()
        if R.cutscene_playing then
            if R.cutscene_skippable then
                imgui.text_colored("SKIPPING", CLR.ON)
            else
                imgui.text_colored("playing (unskippable)", 0xFFFF8844)
            end
        end
        if (R.skip_count or 0) > 0 then
            imgui.text_colored(("  Skipped: %d this session"):format(R.skip_count), CLR.MUTED)
        end
    end

    -- â”€â”€ Display â”€â”€
    section("Display", CLR.CAT)
    tog("Active Feature HUD", "show_hud")
    tog("Show GUID Overlays", "show_guid_titles", nil, nil, "Show GUID below enemy/item/spawn labels in 3D overlay and as tree node titles")
    tog("ESP Background Plates", "esp_bg_plates", nil, nil, "Semi-transparent dark plates behind 3D world text for readability")
    tog("UI DPI Scaling", "ui_dpi_scale", nil, nil, "Scale widget widths and indents based on font size (disable if layout breaks)")
    -- Overlay Font selector (global -- affects all overlays)
    do
        local font_list = {"Segoe UI", "Consolas", "Verdana", "Calibri", "Tahoma", "Arial"}
        local cur_idx = 1
        for i, f in ipairs(font_list) do if f == (C.overlay_font or "Consolas") then cur_idx = i; break end end
        imgui.set_next_item_width(scaled(160))
        local fch, fv = imgui.combo("Overlay Font##ofont", cur_idx, font_list)
        if fch then C.overlay_font = font_list[fv]; pcall(cfg_save) end
    end

    -- â”€â”€ Hotkeys (collapsible) â”€â”€
    if imgui.tree_node("Hotkeys##hk_tree") then
    imgui.text_colored("B = Bookmark  |  N = Warp", CLR.MUTED)
    local function hk_bind_row(label, cfg_key)
        local vk = C[cfg_key] or 0
        local is_listening = (T.hk_listening == cfg_key)
        if is_listening then imgui.text_colored("  Press any key...  (Esc = cancel)", 0xFF44FFFF)
        else
            local btn_label = vk > 0 and ("[" .. vk_name(vk) .. "]##" .. cfg_key) or ("[Bind]##" .. cfg_key)
            if imgui.button(btn_label) then T.hk_listening = cfg_key end
            if vk > 0 then imgui.same_line(); if imgui.button("X##cl" .. cfg_key) then C[cfg_key] = 0; pcall(cfg_save) end end
            imgui.same_line(); imgui.text(label)
        end
    end
    hk_bind_row("God Mode",       "hk_god")
    hk_bind_row("Player Speed",   "hk_speed")
    hk_bind_row("Overlay",        "hk_overlay")
    hk_bind_row("Freeze Enemies", "hk_freeze")
    hk_bind_row("Game Speed",     "hk_gamespeed")
    hk_bind_row("Quick Save",     "hk_save")
    hk_bind_row("Quick Load",     "hk_load")
    hk_bind_row("Remote Storage", "hk_remote_storage")
    hk_bind_row("NoClip",         "hk_noclip")
    hk_bind_row("Skip Cutscenes", "hk_skip")
    imgui.tree_pop()
    end

    -- â”€â”€ System â”€â”€
    section("System", CLR.CAT)
    imgui.text(("Hooks: %s  |  Draw: %s  |  D2D: %s"):format(
        R.hooks_ok and "OK" or "pending", T.has_draw and "OK" or "N/A", T.has_d2d and "OK" or "N/A"))
    if imgui.button("Save Settings") then
        pcall(cfg_save)
        if T.cfg_last_save_err then toast("JSON save failed: " .. T.cfg_last_save_err, 0xFFFF9944)
        else toast("Settings saved", 0xFF44FF88) end
    end
    imgui.same_line()
    if imgui.button("Load Settings") then
        if json then
            local ok, d = pcall(json.load_file, T.CFG)
            if ok and type(d) == "table" then
                for _, k in ipairs(T.PERSIST_KEYS) do if d[k] ~= nil and type(d[k]) == type(C[k]) then C[k] = d[k] end end
                toast("Settings loaded", 0xFF44FF88)
            else toast("No saved settings found", 0xFFFF6666) end
        else toast("json module not available", 0xFFFF6666) end
    end
    if T.cfg_last_save_err then imgui.text_colored("Last save error: " .. T.cfg_last_save_err, 0xFFFF6666) end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Dev (Debug Player + Coordinate Logger)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local DEV_POS_FILE = "requiem_trainer/dev_positions.json"
local dev_positions = {}
local dev_loaded = false

local function dev_load_positions()
    if not json then return end
    local ok, d = pcall(json.load_file, DEV_POS_FILE)
    if ok and type(d) == "table" and type(d.positions) == "table" then dev_positions = d.positions
    else dev_positions = {} end
    dev_loaded = true
end

local function dev_save_positions()
    if not json then return end
    pcall(json.dump_file, DEV_POS_FILE, { positions = dev_positions })
end

local function ui_dev()
    if not dev_loaded then dev_load_positions() end
    tog("Dev Overlay", "show_dev_overlay", nil, nil, "Show debug info overlay at top-left of screen")

    -- TrainerCache stats
    local tc = T.TrainerCache
    if tc then
        local s = tc.stats or {}
        imgui.text_colored(
            string.format("ObjectCache: %d entries | hits:%d miss:%d evict:%d",
                tc.size or 0, s.hits or 0, s.misses or 0, s.evictions or 0),
            CLR.MUTED)
    end

    if imgui.tree_node("Spawn Points") then
        R.spawn_ui_open = true
        tog("Show Spawns", "show_spawns", nil, nil, "Show enemy spawn markers in 3D world")
        if C.show_spawns then
            local SPAWN_STYLES = {"1: Cylinder", "2: Diamond", "3: Beacon", "4: Minimal"}
            local style_ch, style_v = imgui.combo("Spawn Style", C.spawn_style or 1, SPAWN_STYLES)
            if style_ch then C.spawn_style = style_v; pcall(cfg_save) end
            local changed_range, new_range = imgui.slider_int("Spawn Range", C.spawn_range or 100, 10, 500, "%dm")
            if changed_range then C.spawn_range = new_range; pcall(cfg_save) end
            if imgui.button("Rescan Spawns") then
                if T.scan_spawn_points then pcall(T.scan_spawn_points) end
                toast("Rescanned spawn points", 0xFFFFCC44)
            end
            local spawns = R.spawn_cache or {}
            imgui.spacing()
            imgui.text_colored("Spawn Points (" .. #spawns .. " found)", CLR.HEAD)
            if #spawns > 0 then
                local pp = ppos()
                local sorted = {}
                for i, sp in ipairs(spawns) do sorted[i] = sp end
                if pp then
                    table.sort(sorted, function(a, b)
                        local da = math.sqrt((a.x-pp.x)^2 + (a.y-pp.y)^2 + (a.z-pp.z)^2)
                        local db = math.sqrt((b.x-pp.x)^2 + (b.y-pp.y)^2 + (b.z-pp.z)^2)
                        return da < db
                    end)
                end
                for sp_i, sp in ipairs(sorted) do
                    local dist = pp and dist3(sp, pp) or 0
                    local short = (sp.name or "Spawn"):match("cp_(%w+)SpawnParam") or (sp.name or ""):match("cp_(%w+)") or sp.name or "Spawn"
                    local header
                    if C.show_guid_titles and sp.guid then
                        header = string.format("%s  (%.0fm)###sp_%d", sp.guid, dist, sp_i)
                    else
                        header = string.format("%s  (%.0fm)###sp_%d", short, dist, sp_i)
                    end
                    if imgui.tree_node(header) then
                        imgui.text(("Name:     %s"):format(sp.name or "N/A"))
                        imgui.text(("Type:     %s"):format(sp.type or "N/A"))
                        imgui.text(("Position: %.3f, %.3f, %.3f"):format(sp.x, sp.y, sp.z))
                        imgui.text(("Distance: %.1fm"):format(dist))
                        if sp.spawn_id then imgui.text(("SpawnID:  %s"):format(sp.spawn_id)); imgui.same_line()
                            if imgui.button("Copy##sid_" .. sp_i) then toast("SpawnID: " .. sp.spawn_id, 0xFF44FF88) end end
                        if sp.guid then imgui.text(("GUID:     %s"):format(sp.guid)); imgui.same_line()
                            if imgui.button("Copy##guid_" .. sp_i) then pcall(function() imgui.set_clipboard(sp.guid) end); toast("GUID: " .. sp.guid, 0xFF44FF88) end end
                        if sp.go_addr then imgui.text(("Path:     %s"):format(sp.go_addr)); imgui.same_line()
                            if imgui.button("Copy##path_" .. sp_i) then pcall(function() imgui.set_clipboard(sp.go_addr) end); toast("Path: " .. sp.go_addr, 0xFF44FF88) end end
                        if imgui.button("Copy Position##pos_" .. sp_i) then
                            local pos_str = string.format("%.3f, %.3f, %.3f", sp.x, sp.y, sp.z)
                            toast("Pos: " .. pos_str, 0xFF44FF88)
                        end
                        imgui.tree_pop()
                    end
                end
            else imgui.text_colored("No spawn points found. Try Rescan.", CLR.MUTED) end
        end
        imgui.tree_pop()
    else R.spawn_ui_open = false end

    --[[ DISABLED: Chapter Tool
    imgui.spacing(); imgui.separator(); imgui.spacing()
    if imgui.tree_node("Chapter Tool") then
        local now = os.clock()
        if not R._chapter_last_scan or now - R._chapter_last_scan > 2 then
            R._chapter_last_scan = now
            if T.scan_chapter then pcall(T.scan_chapter) end
            if T.discover_runtime_scenes then pcall(T.discover_runtime_scenes) end
        end
        if T.chapter_ui and not T.chapter_ui.progress_discovered then
            T.chapter_ui.progress_discovered = true
            if T.discover_all_progress_names then pcall(T.discover_all_progress_names) end
        end
        local ci = T.chapter_info or {}
        local friendly = T.get_friendly_name and T.get_friendly_name(ci.scene_name) or ci.scene_name or "Unknown"
        imgui.text("Scene Name:     " .. tostring(ci.scene_name or "Unknown"))
        imgui.text("Chapter:        " .. friendly)
        imgui.text("Scenario Time:  " .. tostring(ci.scenario_time or "Unknown"))
        imgui.text("Level Progress: " .. tostring(ci.level_progress or "Unknown"))
        imgui.text("Is Main Game:   " .. tostring(ci.is_main_game or false))
        imgui.spacing(); imgui.separator()
        imgui.text("Jump To Chapter:")
        local ch_list = T.chapter_list or {}
        local ch_scenes = T.chapter_scene_names or {}
        local ch_ui = T.chapter_ui or {}
        if #ch_list > 0 then
            local changed, new_idx = imgui.combo("##chapter_select", ch_ui.selected_index or 1, ch_list)
            if changed then ch_ui.selected_index = new_idx; T.progress_selected_index = 1; T.progress_value_index = 1; ch_ui.progress_target_value = 0 end
            local target_scene = ch_scenes[ch_ui.selected_index or 1]
            if target_scene then imgui.same_line(); imgui.text_colored("(" .. target_scene .. ")", CLR.MUTED) end
            local progress_entries = T.chapter_progress_cache and target_scene and T.chapter_progress_cache[target_scene]
            local sel_progress = nil
            if progress_entries and #progress_entries > 0 then
                local progress_labels = {}
                for i, e in ipairs(progress_entries) do local val_count = e.values and #e.values or 0; progress_labels[i] = e.name .. " (" .. val_count .. " values)" end
                local p_changed, p_idx = imgui.combo("Progress##progress_select", T.progress_selected_index or 1, progress_labels)
                if p_changed then T.progress_selected_index = p_idx; T.progress_value_index = 1 end
                sel_progress = progress_entries[T.progress_selected_index or 1]
                if sel_progress and sel_progress.values and #sel_progress.values > 0 then
                    local value_labels = { "(default)" }
                    for _, v in ipairs(sel_progress.values) do table.insert(value_labels, "#" .. tostring(v)) end
                    local vl_changed, vl_idx = imgui.combo("Value##prog_value", T.progress_value_index or 1, value_labels)
                    if vl_changed then T.progress_value_index = vl_idx
                        if vl_idx == 1 then ch_ui.progress_target_value = 0
                        else ch_ui.progress_target_value = sel_progress.values[vl_idx - 1] end
                    end
                else imgui.text_colored("  (no values yet â€” play through to discover)", CLR.MUTED) end
            else imgui.text_colored("(no progress data â€” play scenes to discover)", CLR.MUTED) end
            if ci.level_progress_name then imgui.text_colored("Current: " .. ci.level_progress_name .. " #" .. tostring(ci.level_progress_no or "?"), 0xFF88CCFF) end
            if imgui.button("Jump!") then
                if target_scene and T.jump_to_chapter then
                    local jump_progress = nil
                    if sel_progress and sel_progress.hash and (ch_ui.progress_target_value or 0) > 0 then
                        jump_progress = { name = sel_progress.name, hash = sel_progress.hash, value = ch_ui.progress_target_value }
                    end
                    local ok, msg = T.jump_to_chapter(target_scene, jump_progress)
                    ch_ui.jump_status = msg or (ok and "Jump initiated" or "Jump failed")
                    ch_ui.jump_status_color = ok and 0xFF00FF00 or 0xFF0000FF
                end
            end
            local jc = T.jump_cont
            if jc and jc.active then imgui.same_line(); imgui.text_colored("[" .. (jc.state or "?") .. " f:" .. jc.frame_count .. "]", 0xFF00FFFF) end
        else imgui.text_colored("(no chapters loaded)", CLR.MUTED) end
        if ch_ui.jump_status and ch_ui.jump_status ~= "" then imgui.text_colored(ch_ui.jump_status, ch_ui.jump_status_color or 0xFFFFFFFF) end
        if imgui.button("Return to Title") then if T.return_to_title then pcall(T.return_to_title) end end
        imgui.same_line()
        if imgui.button("Discover Progress") then
            if T.discover_all_progress_names then
                local disc = T.discover_all_progress_names()
                if disc and disc.all_names and #disc.all_names > 0 then ch_ui.jump_status = "Discovered " .. #disc.all_names .. " progress names!"; ch_ui.jump_status_color = 0xFF00FF00
                else ch_ui.jump_status = "Discovery ran â€” check re9_progress_discovery.json"; ch_ui.jump_status_color = 0xFFFF8800 end
            end
        end
        if ch_ui.runtime_scenes then imgui.spacing(); imgui.text_colored("(" .. #ch_ui.runtime_scenes .. " scenes discovered at runtime)", CLR.MUTED) end
        imgui.spacing(); imgui.tree_pop()
    end
    --]] -- END DISABLED: Chapter Tool

    imgui.spacing(); imgui.separator(); imgui.spacing()
    imgui.text_colored("Debug Player", CLR.HEAD); imgui.spacing()
    local pos = ppos()
    local rot = R.dev_rotation
    local area = R.area_name or ""
    if T.dev_scan_info and not rot then pcall(T.dev_scan_info) end
    if pos then imgui.text(("Position:  %.3f,  %.3f,  %.3f"):format(pos.x, pos.y, pos.z))
    else imgui.text_colored("Position:  N/A (no player)", CLR.MUTED) end
    if rot then imgui.text(("Rotation:  %.1f,  %.1f,  %.1f"):format(rot.x, rot.y, rot.z))
    else imgui.text_colored("Rotation:  N/A", CLR.MUTED) end
    if area ~= "" then imgui.text("Area:      " .. area)
    else imgui.text_colored("Area:      N/A", CLR.MUTED) end
    imgui.spacing()
    imgui.push_style_color(0, 0xFF44BB44)
    if imgui.button("  Save Position  ") then
        if pos then
            local entry = {
                x = math.floor(pos.x * 1000 + 0.5) / 1000, y = math.floor(pos.y * 1000 + 0.5) / 1000, z = math.floor(pos.z * 1000 + 0.5) / 1000,
                pitch = rot and math.floor(rot.x * 10 + 0.5) / 10 or 0, yaw = rot and math.floor(rot.y * 10 + 0.5) / 10 or 0, roll = rot and math.floor(rot.z * 10 + 0.5) / 10 or 0,
                area = area ~= "" and area or nil, time = os.date("%Y-%m-%d %H:%M:%S"),
            }
            dev_positions[#dev_positions + 1] = entry; dev_save_positions()
            toast(("Saved (%.1f, %.1f, %.1f)"):format(pos.x, pos.y, pos.z), 0xFF44FF88)
        else toast("No player â€” cannot save position", 0xFFFF6666) end
    end
    imgui.pop_style_color(1)
    imgui.same_line(); imgui.text_colored(("%d saved"):format(#dev_positions), CLR.MUTED)
    imgui.same_line()
    if #dev_positions > 0 then
        imgui.push_style_color(0, 0xFFFF6666)
        if imgui.button("Clear All") then dev_positions = {}; dev_save_positions(); toast("Cleared all saved positions", 0xFFFF6666) end
        imgui.pop_style_color(1)
    end
    imgui.same_line()
    if imgui.button("Reload") then dev_load_positions(); toast("Reloaded positions from file", 0xFF88DDFF) end

    if #dev_positions > 0 then
        imgui.spacing(); imgui.separator(); imgui.spacing()
        imgui.text_colored("Saved Positions", CLR.HEAD); imgui.spacing()
        local to_remove = nil
        for i, e in ipairs(dev_positions) do
            if i > 50 then imgui.text_colored("...", CLR.MUTED); break end
            local label = ("#%d"):format(i)
            if e.area and e.area ~= "" then label = label .. "  " .. e.area
            elseif e.scene and e.scene ~= "" then label = label .. "  " .. e.scene end
            label = label .. ("###devpos%d"):format(i)
            if imgui.tree_node(label) then
                imgui.text(("  Pos:   %.3f,  %.3f,  %.3f"):format(e.x or 0, e.y or 0, e.z or 0))
                imgui.text(("  Rot:   %.1f,  %.1f,  %.1f"):format(e.pitch or 0, e.yaw or 0, e.roll or 0))
                if e.scene then imgui.text(("  Scene: %s"):format(e.scene)) end
                if e.area then imgui.text(("  Area:  %s"):format(e.area)) end
                if e.time then imgui.text_colored(("  Saved: %s"):format(e.time), CLR.MUTED) end
                imgui.spacing()
                imgui.push_style_color(0, 0xFF4488DD)
                if imgui.button(("Warp##dw%d"):format(i)) then
                    pcall(function() local xf = pxf(); if xf then xf:call("set_Position", Vector3f.new(e.x or 0, e.y or 0, e.z or 0)); toast(("Warped to #%d"):format(i), 0xFF88DDFF) end end)
                end
                imgui.pop_style_color(1)
                imgui.same_line()
                imgui.push_style_color(0, 0xFFFF6666)
                if imgui.button(("Delete##dd%d"):format(i)) then to_remove = i end
                imgui.pop_style_color(1)
                imgui.tree_pop()
            end
        end
        if to_remove then table.remove(dev_positions, to_remove); dev_save_positions(); toast(("Removed position #%d"):format(to_remove), 0xFFFF6666) end
    end

    --[[ DISABLED: GameObject Browser
    imgui.spacing(); imgui.separator(); imgui.spacing()
    imgui.text_colored("GameObject Browser", CLR.HEAD); imgui.spacing()
    R._go_filter = R._go_filter or ""
    R._go_cache = R._go_cache or {}
    R._go_keys  = R._go_keys or {}   -- ordered keys for TrainerCache lookups
    local changed_filter, new_filter = imgui.input_text("Filter", R._go_filter, 256)
    if changed_filter then R._go_filter = new_filter end
    imgui.same_line()
    if imgui.button("Scan Scene") then
        local results = {}
        local keys = {}
        local tc = T.TrainerCache
        -- Clear previous GO entries from TrainerCache
        if tc and R._go_keys then
            for _, k in ipairs(R._go_keys) do pcall(tc.remove, tc, k) end
        end
        pcall(function()
            local scene = get_scene(); if not scene then return end
            local scene_td = sdk.find_type_definition("via.Scene"); if not scene_td then return end
            local first_xf_m = scene_td:get_method("get_FirstTransform"); if not first_xf_m then return end
            local xf = first_xf_m:call(first_xf_m, scene)
            local tf_td = sdk.find_type_definition("via.Transform")
            local get_next_m = tf_td and tf_td:get_method("get_Next")
            local count = 0
            while xf and count < 5000 do
                count = count + 1
                pcall(function()
                    local go = xf:call("get_GameObject"); if not go then return end
                    local name = go:call("get_Name") or ""
                    local p = nil
                    pcall(function() local v = xf:get_Position(); if v then p = { x = v.x, y = v.y, z = v.z } end end)
                    local entry = { name = tostring(name), go = go, xf = xf, pos = p }
                    results[#results + 1] = entry
                    -- Store in TrainerCache with 60s TTL for lifecycle management
                    if tc then
                        local cache_key = "go_" .. count
                        tc:set(cache_key, go, 60)
                        keys[#keys + 1] = cache_key
                    end
                end)
                if get_next_m then local ok, nxt = pcall(get_next_m.call, get_next_m, xf); if ok and nxt then xf = nxt else break end
                else break end
            end
        end)
        R._go_cache = results
        R._go_keys = keys
        toast(#results .. " GameObjects found", 0xFF88DDFF)
    end
    imgui.text_colored(#R._go_cache .. " objects cached", CLR.MUTED)
    if #R._go_cache > 0 then
        local filter = R._go_filter:lower()
        local shown = 0
        for idx, entry in ipairs(R._go_cache) do
            if shown >= 200 then imgui.text_colored("... (200 limit, use filter)", CLR.MUTED); break end
            local name = entry.name or ""
            if filter == "" or name:lower():find(filter, 1, true) then
                shown = shown + 1
                local header = name; if header == "" then header = "(unnamed)" end
                header = header .. "###go_" .. idx
                if imgui.tree_node(header) then
                    if entry.pos then
                        imgui.text(("Pos: %.3f, %.3f, %.3f"):format(entry.pos.x, entry.pos.y, entry.pos.z))
                        imgui.same_line()
                        if imgui.button("Copy Pos##gp_" .. idx) then local s = string.format("%.3f, %.3f, %.3f", entry.pos.x, entry.pos.y, entry.pos.z); toast("Pos: " .. s, 0xFF44FF88) end
                    end
                    local guid_str = nil
                    pcall(function() if T.extract_go_guid and entry.go then guid_str = T.extract_go_guid(entry.go) end end)
                    local path_str = nil
                    pcall(function() if T.extract_go_addr and entry.go then path_str = T.extract_go_addr(entry.go) end end)
                    if not guid_str then guid_str = tostring(entry.go):match("@([%x%-]+)%]") or tostring(entry.go) end
                    if guid_str then imgui.text("GUID: " .. guid_str); imgui.same_line()
                        if imgui.button("Copy##gi_" .. idx) then pcall(function() imgui.set_clipboard(guid_str) end); toast("GUID: " .. guid_str, 0xFF44FF88) end
                    end
                    if path_str then imgui.text("Path: " .. path_str); imgui.same_line()
                        if imgui.button("Copy##gpa_" .. idx) then pcall(function() imgui.set_clipboard(path_str) end); toast("Path: " .. path_str, 0xFF44FF88) end
                    end
                    pcall(function()
                        local go = entry.go; if not go then return end
                        local comps = {}
                        pcall(function() local elements = go:call("get_Components"):get_elements(); if elements then for _, c in ipairs(elements) do if c then comps[#comps + 1] = c end end end end)
                        if #comps > 0 then
                            imgui.text_colored(#comps .. " components:", CLR.MUTED)
                            for ci, c in ipairs(comps) do
                                local ctype = "?"; pcall(function() ctype = c:get_type_definition():get_full_name() end)
                                if imgui.tree_node(ctype .. "###comp_" .. idx .. "_" .. ci) then
                                    pcall(function()
                                        local td = c:get_type_definition(); if not td then return end
                                        local fields = td:get_fields()
                                        if fields then for _, f in ipairs(fields) do pcall(function()
                                            local fname = f:get_name(); if not fname then return end
                                            local val = nil; pcall(function() val = c:get_field(fname) end)
                                            local vstr = tostring(val); if #vstr > 120 then vstr = vstr:sub(1, 120) .. "..." end
                                            imgui.text(("  %s = %s"):format(fname, vstr))
                                        end) end end
                                    end)
                                    imgui.tree_pop()
                                end
                            end
                        else imgui.text_colored("(no components found)", CLR.MUTED) end
                    end)
                    imgui.tree_pop()
                end
            end
        end
        if shown == 0 then imgui.text_colored("No matches for filter", CLR.MUTED) end
    end
    --]] -- END DISABLED: GameObject Browser
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Gravity Gun
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_gravity_gun()
    if T.GravityGun then
        T.GravityGun.render_ui()
    else
        imgui.text_colored("Gravity Gun module not loaded", CLR.MUTED)
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Level Flow
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_level_flow()
    if imgui.button("Scan Now##lfc") then if T.scan_level_flow_controllers then pcall(T.scan_level_flow_controllers) end end
    local lfcs = R.level_flow_controllers or {}
    local count = #lfcs
    imgui.same_line(); imgui.text_colored(count .. " controller(s) found", count > 0 and 0xFF44FF88 or CLR.MUTED)
    imgui.separator()
    if count == 0 then imgui.text_colored("No app.LevelFlowController found in scene", CLR.MUTED); return end
    for idx, lfc in ipairs(lfcs) do
        local go_name = lfc.go_name or "?"
        local is_main = go_name:find("_Main") ~= nil
        local bt_label = lfc.bt_node and (" â†’ " .. lfc.bt_node) or ""
        local header = go_name .. bt_label
        if is_main then imgui.push_style_color(0, 0xFF44FF88) end
        if imgui.tree_node(header .. "##lfc_" .. idx) then
            if is_main then imgui.pop_style_color(1) end
            imgui.text(("GameObject:  %s"):format(go_name))
            imgui.same_line()
            if imgui.button("Copy##lfc_go_" .. idx) then pcall(function() imgui.set_clipboard(go_name) end); toast("Copied: " .. go_name, 0xFF44FF88) end
            if lfc.bt_node then
                imgui.text(("BT Node:    %s"):format(lfc.bt_node))
                imgui.same_line()
                if imgui.button("Copy##lfc_bt_" .. idx) then pcall(function() imgui.set_clipboard(tostring(lfc.bt_node)) end); toast("Copied: " .. tostring(lfc.bt_node), 0xFF44FF88) end
            end
            if lfc.bt_nodes and #lfc.bt_nodes > 0 then
                if imgui.tree_node("BT Layers (" .. #lfc.bt_nodes .. ")##lfc_layers_" .. idx) then
                    for _, layer_node in ipairs(lfc.bt_nodes) do imgui.text(layer_node) end
                    imgui.tree_pop()
                end
            end
            local field_count = 0; for _ in pairs(lfc.fields or {}) do field_count = field_count + 1 end
            if field_count > 0 then
                if imgui.tree_node("Fields (" .. field_count .. ")##lfc_fields_" .. idx) then
                    for fname, fval in pairs(lfc.fields) do imgui.text(("%-30s %s"):format(fname, fval)) end
                    imgui.tree_pop()
                end
            end
            imgui.tree_pop()
        else
            if is_main then imgui.pop_style_color(1) end
        end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- UI â€” Tools (Item Spawner, Perspective, Costume, Difficulty)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

local function ui_world()
    -- ── Difficulty Modifier ──
    section("Difficulty Modifier", CLR.CAT)
    imgui.indent(scaled(6))
    if T._diff_state then
        local ds = T._diff_state
        if not ds.scanned or #ds.rows == 0 then
            imgui.text_colored("Scanning difficulties...", CLR.MUTED)
            local now = os.clock()
            if T.difficulty_scan and (not ds._last_try or now - ds._last_try > 2) then
                ds._last_try = now
                pcall(T.difficulty_scan)
            end
        else
            if ds.current then
                imgui.text_colored("Current: " .. ds.current, CLR.ON)
                imgui.spacing()
            end
            for _, row in ipairs(ds.rows) do
                local is_current = ds.current and ds.current:find(row.key, 1, true)
                if is_current then
                    imgui.push_style_color(21, 0xFF44FF88)
                    imgui.push_style_color(22, 0xFF66FFAA)
                    imgui.push_style_color(0, 0xFF1A1A2E)
                else
                    imgui.push_style_color(21, 0xFF333355)
                    imgui.push_style_color(22, 0xFF444477)
                    imgui.push_style_color(0, 0xFFBBBBDD)
                end
                if imgui.button("  " .. row.name .. "  ##diff_" .. row.key) then
                    if T.difficulty_apply then pcall(T.difficulty_apply, row) end
                end
                imgui.pop_style_color(3)
                imgui.same_line()
            end
            imgui.text("")
        end
    else
        imgui.text_colored("Difficulty module not loaded", CLR.MUTED)
    end
    imgui.unindent(6)
    imgui.spacing()

    -- ── Game Speed ──
    section("Game Speed", CLR.CAT)
    tog("Game Speed", "game_speed_on", T.game_speed_revert, "hk_gamespeed")
    if C.game_speed_on then
        local ch, v = imgui.slider_float("Speed##gs", C.game_speed, 0.05, 5.0, "%.2fx")
        if ch then C.game_speed = v; pcall(cfg_save) end
        if imgui.button("0.25x") then C.game_speed = 0.25; pcall(cfg_save) end; imgui.same_line()
        if imgui.button("0.5x") then C.game_speed = 0.5; pcall(cfg_save) end; imgui.same_line()
        if imgui.button("1x") then C.game_speed = 1.0; pcall(cfg_save) end; imgui.same_line()
        if imgui.button("2x") then C.game_speed = 2.0; pcall(cfg_save) end; imgui.same_line()
        if imgui.button("3x") then C.game_speed = 3.0; pcall(cfg_save) end
    end

    -- ── Clear Points (CP) ──
    section("Clear Points (CP)", CLR.CAT)
    imgui.set_next_item_width(scaled(200))
    local cp_ch, cp_v = imgui.drag_int("##cp_value", C.cp_value, 1000, 0, 99999999, "%d CP")
    if cp_ch then C.cp_value = cp_v; pcall(cfg_save) end
    imgui.same_line()
    if imgui.button("Apply CP##btn_apply_cp") then
        if T.apply_cp then pcall(T.apply_cp) end
    end
    if imgui.is_item_hovered() then imgui.set_tooltip("Set your Clear Points to the specified value") end

    -- ── Playtime Modifier ──
    section("Playtime Modifier", CLR.CAT)
    tog("Freeze Playtime", "playtime_freeze", nil, nil, "Lock elapsed time at the configured value each frame")
    local pt_ch_h, pt_h = imgui.slider_int("Hours##pt_h", C.playtime_hours, 0, 99)
    if pt_ch_h then C.playtime_hours = pt_h; pcall(cfg_save) end
    local pt_ch_m, pt_m = imgui.slider_int("Minutes##pt_m", C.playtime_minutes, 0, 59)
    if pt_ch_m then C.playtime_minutes = pt_m; pcall(cfg_save) end
    local pt_ch_s, pt_s = imgui.slider_int("Seconds##pt_s", C.playtime_seconds, 0, 59)
    if pt_ch_s then C.playtime_seconds = pt_s; pcall(cfg_save) end
    local pt_total = C.playtime_hours * 3600 + C.playtime_minutes * 60 + C.playtime_seconds
    imgui.text_colored("  Target: " .. (T.format_time and T.format_time(pt_total) or "--:--:--"), CLR.ON)
    if imgui.button("Apply Playtime##btn_apply_pt") then
        if T.apply_playtime then pcall(T.apply_playtime) end
    end
    if imgui.is_item_hovered() then imgui.set_tooltip("Set the game clock to the configured time now") end
    if T.get_game_timers then
        local timers = T.get_game_timers()
        if #timers > 0 then
            imgui.spacing()
            imgui.text_colored("  Live Timers:", CLR.MUTED)
            for _, t in ipairs(timers) do
                if t.index <= 2 then
                    imgui.text_colored(string.format("    [%d] %s: %s", t.index, t.name,
                        T.format_time and T.format_time(t.elapsed_secs) or "?"), CLR.ON)
                end
            end
        end
    end

    -- ── Camera Pan / Offset ──
    section("Camera Pan / Offset", CLR.CAT)
    tog("Enable Camera Pan", "camera_pan_enabled", function() if T.cam_apply then pcall(T.cam_apply) end end,
        nil, "Apply custom pan/offset to third-person camera")
    if C.camera_pan_enabled then
        local cam_ch_x, cam_x = imgui.drag_float("Pan X##cam_px", C.camera_pan_x, 0.01, -3.0, 3.0, "%.2f")
        if cam_ch_x then C.camera_pan_x = cam_x; if T.cam_apply then pcall(T.cam_apply) end; pcall(cfg_save) end
        local cam_ch_y, cam_y = imgui.drag_float("Pan Y##cam_py", C.camera_pan_y, 0.01, -3.0, 3.0, "%.2f")
        if cam_ch_y then C.camera_pan_y = cam_y; if T.cam_apply then pcall(T.cam_apply) end; pcall(cfg_save) end
        local cam_ch_z, cam_z = imgui.drag_float("Offset Z##cam_oz", C.camera_offset_z, 0.01, -3.0, 3.0, "%.2f")
        if cam_ch_z then C.camera_offset_z = cam_z; if T.cam_apply then pcall(T.cam_apply) end; pcall(cfg_save) end
        if imgui.button("Reset Pan/Offset##cam_reset") then
            if T.cam_reset then pcall(T.cam_reset) end; pcall(cfg_save)
        end
        if T._cam_state and T._cam_state.native_offset then
            local nat = T._cam_state.native_offset
            imgui.text_colored(string.format("  Native: X %.3f  Y %.3f  Z %.3f", nat.x, nat.y, nat.z), CLR.MUTED)
        elseif C.camera_pan_enabled then
            imgui.text_colored("  Waiting for TPS camera init... move in third person", CLR.MUTED)
        end
    end

    -- ── Unlocks & Bonus ──
    section("Unlocks & Bonus", CLR.CAT)
    if imgui.button("Unlock All Special Content##btn_unlock") then R._do_unlock = true end
    imgui.same_line()
    imgui.push_style_color(21, 0xFF4444FF)
    imgui.push_style_color(22, 0xFF6666FF)
    imgui.push_style_color(23, 0xFF8888FF)
    if imgui.button("Reset All##btn_rbns") then R._do_reset_bonus = true end
    imgui.pop_style_color(3)

    -- ── Challenges ──
    section("Challenges", CLR.CAT)
    if T.get_challenges_info then
        local ci = T.get_challenges_info()
        if ci.total > 0 then
            imgui.text_colored(string.format("  Total: %d  |  Done: %d  |  Active: %d",
                ci.total, ci.done, ci.active), CLR.ON)
            imgui.spacing()
            imgui.push_style_color(0, 0xFF44FF88)
            if imgui.button("Complete All##chal_all") then pcall(T.unlock_challenges, 1) end
            imgui.pop_style_color(1)
            imgui.same_line()
            imgui.push_style_color(0, 0xFFFF8844)
            if imgui.button("Reset All##chal_wipe") then pcall(T.unlock_challenges, 2) end
            imgui.pop_style_color(1)
            imgui.spacing()
            if imgui.tree_node("Individual Challenges##chal_list") then
                for _, e in ipairs(ci.entries) do
                    local status_text = e.completed and "[DONE]" or (e.progress > 0 and string.format("[%d]", e.progress) or "[—]")
                    local status_color = e.completed and CLR.ON or (e.progress > 0 and 0xFFFFAA44 or CLR.MUTED)
                    imgui.text_colored(status_text .. " " .. e.name, status_color)
                    imgui.same_line()
                    if imgui.button((e.completed and "Revert" or "Finish") .. "##ch" .. e.index) then
                        pcall(T.unlock_challenges, 3, e.index)
                    end
                end
                imgui.tree_pop()
            end
        else
            imgui.text_colored("  No challenges found (load a game first)", CLR.MUTED)
        end
    else
        imgui.text_colored("  Challenges module not loaded", CLR.MUTED)
    end

    -- Shared helper for unlock/reset (extracts duplicated code)
    local function bonus_set_all(unlock)
        local ok, err = pcall(function()
            local total = 0
            local exshop = mgr("app.EXShopManager")
            if exshop then local dic = exshop:get_field("_ItemDataDic")
                if dic then local inner = dic:get_field("_Dict"); if inner then
                    local entries = inner:get_field("_entries"); local count = inner:get_field("_count") or 0
                    if entries then for i = 0, count - 1 do pcall(function()
                        local e = entries:get_element(i)
                        if not e or not e.hashCode or e.hashCode < 0 then return end
                        local v = e.value; if not v then return end
                        local actual = v:get_field("_Value"); if not actual then return end
                        pcall(actual.set_field, actual, "_PurchaseUnlocked", unlock)
                        pcall(actual.set_field, actual, "_AcquisitionUnlocked", unlock)
                        pcall(actual.set_field, actual, "_Received", unlock)
                        total = total + 1
                    end) end end
                end end
            end
            local bonus = mgr("app.BonusManager")
            if bonus then local cdc = bonus:get_field("_ContentsContextDic")
                if cdc then local inner = cdc:get_field("_Dict"); if inner then
                    local entries = inner:get_field("_entries"); local count = inner:get_field("_count") or 0
                    if entries then for i = 0, count - 1 do pcall(function()
                        local e = entries:get_element(i)
                        if not e or not e.hashCode or e.hashCode < 0 then return end
                        local v = e.value; if not v then return end
                        local actual = v:get_field("_Value"); if not actual then return end
                        pcall(actual.set_field, actual, "_Completed", unlock)
                        pcall(actual.set_field, actual, "_Unlocked", unlock)
                        total = total + 1
                    end) end end
                end end
                if unlock then
                    pcall(function() bonus:call("tryUnlockContentsList") end)
                    for i = 0, 50 do pcall(function() bonus:call("tryUnlockSpecialContent", i) end) end
                end
            end
            if unlock then
                toast("Unlocked " .. total .. " items", 0xFF44FF88)
            else
                toast("Reset " .. total .. " items to locked", 0xFFFF6666)
            end
        end)
        if not ok then toast("Error: " .. tostring(err), 0xFFFF6666) end
    end

    -- Deferred actions
    if R._do_unlock then R._do_unlock = nil; bonus_set_all(true) end
    if R._do_challenges then
        R._do_challenges = nil
        if T.unlock_challenges then pcall(T.unlock_challenges, 1) else toast("Challenges module not loaded", 0xFFFF6666) end
    end
    if R._do_reset_bonus then R._do_reset_bonus = nil; bonus_set_all(false) end
    if R._do_reset_chal then
        R._do_reset_chal = nil
        if T.unlock_challenges then pcall(T.unlock_challenges, 2) else toast("Challenges module not loaded", 0xFFFF6666) end
    end
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
-- Export
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

T.ui_player = ui_player
T.ui_combat = ui_combat
T.ui_enemies = ui_enemies
T.ui_weapons = ui_weapons
T.ui_saves = ui_saves
T.ui_items = ui_items
T.ui_item_indicator = ui_item_indicator
T.ui_settings = ui_settings
T.ui_world = ui_world
T.ui_dev = ui_dev
T.ui_gravity_gun = ui_gravity_gun
T.ui_level_flow = ui_level_flow
T.hk_scanner = hk_scanner

-- Costume display name: delegate to features.lua's version (avoid duplication)
if not T.costume_display_name then
    T.costume_display_name = function(_, raw) return raw or "Unknown" end
end

log.info("[Trainer] UI module loaded")
