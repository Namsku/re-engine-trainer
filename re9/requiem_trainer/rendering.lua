-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Rendering Module
-- D2D overlays: damage numbers, ESP, enemy panel, HUD strip, toasts
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast = T.mgr, T.toast
local get_scene = T.get_scene
local get_enemy_list = T.get_enemy_list
local dist3 = T.dist3
local hp_vals, player_name, player_hp_level = T.hp_vals, T.player_name, T.player_hp_level

local has_d2d  = (d2d ~= nil)
local has_draw = (draw ~= nil)

T.has_d2d = has_d2d
T.has_draw = has_draw

-- ── Centralized Overlay Font Cache ──
-- All overlay elements share C.overlay_font for the font name.
-- OFont.get(size, bold) returns a cached d2d.Font, auto-invalidated on name change.
local _font_cache = {}    -- key = "size_bold" → d2d.Font
local _font_name = ""     -- last known font name

local OFont = {}
function OFont.get(size, bold)
    if not has_d2d then return nil end
    local cur_name = C.overlay_font or "Consolas"
    if cur_name ~= _font_name then
        _font_cache = {}
        _font_name = cur_name
    end
    local key = size .. (bold and "_b" or "_r")
    if not _font_cache[key] then
        pcall(function() _font_cache[key] = d2d.Font.new(cur_name, size, bold) end)
    end
    return _font_cache[key]
end
function OFont.invalidate()
    _font_cache = {}
    _font_name = ""
end
T.OFont = OFont

local function draw_rect(x, y, w, h, col)
    if has_d2d then d2d.fill_rect(x, y, w, h, col)
    elseif has_draw then draw.filled_rect(x, y, w, h, col) end
end

local function draw_text(x, y, col, msg)
    if has_d2d and d2d_font then d2d.text(d2d_font, msg, x, y, col)
    elseif has_draw then draw.text(msg, x, y, col) end
end

local function draw_text_shadow(x, y, col, msg, font)
    local f = font or d2d_font
    if has_d2d and f then
        pcall(d2d.text, f, msg, x + 1, y + 1, 0xCC000000)
        pcall(d2d.text, f, msg, x, y, col)
    elseif has_draw then
        pcall(draw.text, msg, x + 1, y + 1, 0xCC000000)
        pcall(draw.text, msg, x, y, col)
    end
end

-- GuiUtil world→screen projection
local _gui_w2s = nil
local _gui_insight = nil
pcall(function()
    local td = sdk.find_type_definition("app.GuiUtil")
    if td then
        _gui_w2s = td:get_method("transformWorldToScreen(via.vec3, System.Boolean)")
        _gui_insight = td:get_method("isCameraInSide(via.vec3)")
    end
end)

local function world_to_screen(world_pos)
    if not _gui_w2s or not world_pos then return nil end
    local ok, sp = pcall(_gui_w2s.call, _gui_w2s, nil, world_pos, false)
    if not ok or not sp then return nil end
    local sx, sy = tonumber(sp.x), tonumber(sp.y)
    if not sx or not sy then return nil end
    if sx ~= sx or sy ~= sy then return nil end
    if sx == math.huge or sx == -math.huge then return nil end
    if sy == math.huge or sy == -math.huge then return nil end
    return {x = sx, y = sy}
end

local function is_in_sight(world_pos)
    if not _gui_insight or not world_pos then return true end
    local ok, v = pcall(_gui_insight.call, _gui_insight, nil, world_pos)
    if not ok then return true end
    return v == true
end

local function set_alpha(col, ratio)
    if ratio >= 1 then return col end
    local rgb = col & 0xFFFFFF
    local a = (col >> 24) & 0xFF
    a = (math.floor(a * ratio) & 0xFF) << 24
    return a | rgb
end

local function hp_gradient_color(ratio)
    local r_val, g_val
    if ratio > 0.5 then
        r_val = math.floor((1.0 - ratio) * 2 * 255)
        g_val = 255
    else
        r_val = 255
        g_val = math.floor(ratio * 2 * 255)
    end
    return 0xFF000000 + (g_val * 0x100) + r_val
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Panel (D2D)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_enemy_panel()
    if not C.enemy_panel then return end
    if not has_d2d and not has_draw then return end
    init_d2d_font()

    local COL_TEXT = 0xFFE8E8E8
    local COL_BG   = 0x69000000
    local COL_BAR_FILL = 0xFF76DCA7
    local COL_BAR_EMPTY = 0xFFB8B8B8

    local x0, y0 = C.panel_x, C.panel_y
    -- Push panel below dev overlay if they would overlap
    if C.show_dev_overlay and R.dev_overlay_bottom and y0 < R.dev_overlay_bottom then
        y0 = R.dev_overlay_bottom
    end
    local w = C.panel_w or 480
    local pad = 8
    local line_h = C.panel_font + 6
    local bar_w = C.panel_bar_w or 150
    local bar_h = C.panel_bar_h or 8
    local bar_gap = 4

    local nearby = {}
    for _, e in ipairs(R.enemies) do
        if C.hide_dead and (e.dead or e.hp <= 0) then
        elseif C.filter_full_hp and e.hp >= e.mhp then
        elseif e.dist <= C.esp_range then
            nearby[#nearby + 1] = e
        end
    end
    local rows = math.min(#nearby, C.panel_rows)

    local entry_h = line_h + (C.show_bars and (bar_h + bar_gap) or 0)
    local rank_lines = 0
    if C.show_rank and R.rank_data then rank_lines = rank_lines + 1 end
    local sep_h = 6
    local igt_lines = C.show_igt and 1 or 0
    local panel_h = pad + line_h + (C.show_bars and (bar_h + bar_gap) or 0)
                  + (igt_lines * (line_h + 2))
                  + sep_h + line_h
                  + (rank_lines * line_h)
                  + (rows > 0 and sep_h or 0)
                  + (rows * entry_h) + pad

    draw_rect(x0 - pad, y0 - pad, w + pad * 2, panel_h, COL_BG)
    local x, y = x0, y0

    -- Player HP header
    local p_cur, p_max = hp_vals()
    local pname = player_name()
    local plv, pmlv = player_hp_level()
    local hp_str = p_cur and p_max and string.format("%d/%d", math.max(0, math.ceil(p_cur)), math.max(1, math.ceil(p_max))) or "---"
    local lv_str = ""
    if plv or pmlv then lv_str = string.format(" Upgrade: %s/%s", tostring(plv or "?"), tostring(pmlv or "?")) end
    draw_text(x, y, COL_TEXT, string.format("%s - HP %s%s", pname, hp_str, lv_str))
    y = y + line_h

    if C.show_bars and p_cur and p_max and p_max > 0 then
        local r = math.max(0, math.min(1, p_cur / p_max))
        local bx = x + 16
        draw_rect(bx, y, bar_w, bar_h, COL_BAR_EMPTY)
        draw_rect(bx, y, math.floor(bar_w * r), bar_h, COL_BAR_FILL)
        y = y + bar_h + bar_gap
    end

    if C.show_igt then
        y = y + 2
        draw_text(x, y, COL_TEXT, "IGT")
        if R.igt_text and R.igt_text ~= "" then
            draw_text(x + 36, y, COL_TEXT, R.igt_text)
        else
            draw_text(x + 36, y, COL_TEXT, "--:--:--")
        end
        y = y + line_h
    end

    y = y + 2; draw_rect(x, y, w - pad, 1, 0x60FFFFFF); y = y + 4

    if C.show_rank and R.rank_data then
        local rd = R.rank_data
        local fmt_n = function(v) return v and tostring(v) or "N/A" end
        draw_text(x, y, COL_TEXT, string.format("Rank: %s   DA: %s", fmt_n(rd.rank), fmt_n(rd.points)))
        y = y + line_h
    end

    if rows > 0 then
        y = y + 2; draw_rect(x, y, w - pad, 1, 0x60FFFFFF); y = y + 4
    end

    for i = 1, rows do
        local e = nearby[i]
        local hp_cur = math.max(0, math.ceil(e.hp or 0))
        local hp_max = math.max(1, math.ceil(e.mhp or 1))
        local ratio  = hp_max > 0 and math.max(0, math.min(1, hp_cur / hp_max)) or 0

        -- Alternating row background
        if i % 2 == 0 then
            draw_rect(x0 - pad, y - 2, w + pad * 2, entry_h + 2, 0x12FFFFFF)
        end

        -- Name (left) + HP + distance (right)
        local name_col = 0xFFDDDDDD
        if C.dist_color then
            if e.dist < 5 then name_col = 0xFF7777FF
            elseif e.dist < 15 then name_col = 0xFF66CCFF end
        end

        -- Pad name to fixed width for alignment
        local display_name = e.name
        if #display_name > 12 then display_name = display_name:sub(1, 11) .. "\xE2\x80\xA6" end

        local pct_str = ""
        if C.show_pct and hp_max > 0 then pct_str = string.format("  %d%%", math.floor(ratio * 100)) end
        local dist_str = string.format("%.0fm", e.dist)

        -- Left: name
        draw_text(x, y, name_col, display_name)
        -- Right: HP values + distance
        local hp_str = string.format("%d / %d%s   %s", hp_cur, hp_max, pct_str, dist_str)
        local hp_col = 0xFFBBBBBB
        if ratio < 0.25 then hp_col = 0xFFFF6666
        elseif ratio < 0.5 then hp_col = 0xFFFFAA44 end
        draw_text(x + 120, y, hp_col, hp_str)
        y = y + line_h

        -- HP bar with gradient fill
        if C.show_bars and hp_max > 0 then
            local bx = x + 4
            draw_rect(bx, y, bar_w, bar_h, 0xFF222233)
            local fill_col = hp_gradient_color(ratio)
            draw_rect(bx, y, math.floor(bar_w * ratio), bar_h, fill_col)
            -- Thin border
            draw_rect(bx, y, bar_w, 1, 0x30FFFFFF)
            draw_rect(bx, y + bar_h - 1, bar_w, 1, 0x30FFFFFF)
            y = y + bar_h + bar_gap
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3D ESP — Name + HP above enemy heads
-- ═══════════════════════════════════════════════════════════════════════════

-- Estimate text width using font size
local function est_text_w(text, font_size)
    return #text * font_size * 0.55
end
local function est_text_w_sm(text, font_size)
    return #text * font_size * 0.50
end

-- Draw text with a semi-transparent background pill for 3D ESP readability
-- When C.esp_bg_plates is false, falls back to shadow-only rendering
local BG_ESP = 0x99111118  -- near-black with ~60% opacity
local function draw_text_pill(font, text, x, y, text_col, font_size, bg_col)
    if not font or not text then return end
    if C.esp_bg_plates ~= false then
        -- Pill mode: background rect + text
        local tw = #text * (font_size or 14) * 0.55
        local th = (font_size or 14)
        local px, py = 5, 2  -- padding
        local rx, ry = x - px, y - py
        local rw, rh = tw + px * 2, th + py * 2
        pcall(d2d.fill_rect, rx, ry, rw, rh, bg_col or BG_ESP)
        pcall(d2d.text, font, text, x, y, text_col)
    else
        -- Shadow fallback (old behavior)
        pcall(d2d.text, font, text, x + 1, y + 1, 0xCC000000)
        pcall(d2d.text, font, text, x, y, text_col)
    end
end

local function render_esp()
    if not C.enemy_esp then return end
    if not has_d2d then return end
    if #R.enemies == 0 then return end

    local fnt_main = OFont.get(C.esp_font, true)
    local sm_sz = math.max(11, math.floor(C.esp_font * 0.55))
    local fnt_sm = OFont.get(sm_sz, true)
    if not fnt_main then return end

    local bar_w = C.esp_bar_w or 160
    local bar_h = C.esp_bar_h or 6
    local world_y_offset = C.esp_world_y or 1.9
    local accent_w = 3  -- colored left accent strip

    for _, e in ipairs(R.enemies) do
        if C.hide_dead and (e.dead or e.hp <= 0) then goto esp_next end
        if e.dist > C.esp_range then goto esp_next end
        if not e.pos then goto esp_next end

        -- In-sight filter
        local wpos = Vector3f.new(e.pos.x, e.pos.y + world_y_offset, e.pos.z)
        if C.esp_in_sight and not is_in_sight(wpos) then goto esp_next end

        -- Project to screen
        local sp = world_to_screen(wpos)
        if not sp then goto esp_next end

        -- Distance-based alpha fade
        local alpha = 1.0
        if C.esp_alpha and e.dist > C.esp_alpha_start then
            alpha = 1.0 - ((e.dist - C.esp_alpha_start) / (C.esp_range - C.esp_alpha_start))
            alpha = math.max(C.esp_min_alpha, math.min(1.0, alpha))
        end

        -- Distance-based scale
        local scale = 1.0
        if C.esp_scale then
            scale = 1.0 - ((e.dist / C.esp_range) * (1.0 - C.esp_min_scale))
            scale = math.max(C.esp_min_scale, math.min(1.0, scale))
        end

        local cur_bar_w = math.floor(bar_w * scale)
        local cur_bar_h = math.max(3, math.floor(bar_h * scale))
        local cx = sp.x
        local cy = sp.y

        -- HP ratio + colors
        local hp_cur = math.max(0, math.ceil(e.hp or 0))
        local hp_max = math.max(1, math.ceil(e.mhp or 1))
        local ratio = hp_max > 0 and math.max(0, math.min(1, hp_cur / hp_max)) or 0
        local hp_col = hp_gradient_color(ratio)

        -- ── Tiny diamond marker at position ──
        local dm = math.floor(3 * scale)
        pcall(d2d.fill_rect, cx - dm, cy - 1, dm * 2, 2, set_alpha(hp_col, alpha))
        pcall(d2d.fill_rect, cx - 1, cy - dm, 2, dm * 2, set_alpha(hp_col, alpha))

        -- ── Layout: everything anchored above the marker ──
        local layout_y = cy - 8 * scale

        -- HP bar position
        local bx = cx - cur_bar_w / 2
        local by = layout_y - cur_bar_h

        -- Bar background (dark, slim)
        pcall(d2d.fill_rect, bx - accent_w, by - 1, cur_bar_w + accent_w + 1, cur_bar_h + 2, set_alpha(0xBB000000, alpha))
        -- Left accent strip (colored by HP)
        pcall(d2d.fill_rect, bx - accent_w, by - 1, accent_w, cur_bar_h + 2, set_alpha(hp_col, alpha))
        -- Bar track
        pcall(d2d.fill_rect, bx, by, cur_bar_w, cur_bar_h, set_alpha(0xFF222233, alpha))
        -- Bar fill
        local fill_w = math.floor(cur_bar_w * ratio)
        if fill_w > 0 then
            pcall(d2d.fill_rect, bx, by, fill_w, cur_bar_h, set_alpha(hp_col, alpha))
            -- Bright highlight on top pixel of fill
            pcall(d2d.fill_rect, bx, by, fill_w, 1, set_alpha(0x50FFFFFF, alpha))
        end

        -- ── Info text to the right of bar: "78%  7m" ──
        if fnt_sm then
            local pct_text = string.format("%d%%", math.floor(ratio * 100))
            local dist_text = string.format("%.0fm", e.dist)
            local info_text = pct_text .. "  " .. dist_text
            local info_x = bx + cur_bar_w + 6
            local info_y = by + (cur_bar_h - sm_sz * scale) / 2 - 1
            pcall(d2d.text, fnt_sm, info_text, info_x + 1, info_y + 1, set_alpha(0xFF000000, alpha * 0.7))
            pcall(d2d.text, fnt_sm, info_text, info_x, info_y, set_alpha(0xFFAABBCC, alpha))
        end

        -- ── Name above bar (background pill for readability) ──
        local name_text = e.name or "Unknown"
        local name_tw = est_text_w(name_text, C.esp_font * scale)
        local name_x = cx - name_tw / 2
        local name_y = by - math.floor(C.esp_font * scale) - 6
        draw_text_pill(fnt_main, name_text, name_x, name_y,
            set_alpha(0xFFFFFFFF, alpha), C.esp_font * scale,
            set_alpha(BG_ESP, alpha))

        -- ── GUID below marker (abbreviated, when enabled) ──
        if C.show_guid_titles and e.guid and fnt_sm then
            local guid_tw = est_text_w_sm(e.guid, sm_sz * scale)
            local guid_y = cy + 6 * scale
            draw_text_pill(fnt_sm, e.guid, cx - guid_tw / 2, guid_y,
                set_alpha(0xFFFFCC44, alpha * 0.7), sm_sz * scale,
                set_alpha(BG_ESP, alpha * 0.5))
        end

        ::esp_next::
    end
end



-- ═══════════════════════════════════════════════════════════════════════════
-- Damage Numbers
-- ═══════════════════════════════════════════════════════════════════════════

local dmg_list = {}
local dmg_hooks_ok = false
local dmg_hook_pattern = "none"
local dmg_hp_cache = {}
local dmg_prev_hp = {}
local dmg_font_sz_cache = 0
local dmg_dbg = { fires = 0, draws = 0, last = 0 }
local dmg_coalesce = {}
local DMG_COALESCE_WINDOW = 0.15

local function dmg_coalesce_key(wx, wy, wz)
    return string.format("%d_%d_%d", math.floor(wx * 0.5), math.floor(wy * 0.5), math.floor(wz * 0.5))
end

local function dmg_new(damage, wx, wy, wz)
    if not C.show_damage or damage <= 0 then return end
    dmg_dbg.fires = dmg_dbg.fires + 1
    dmg_dbg.last = damage
    if C.dmg_combine then
        local key = dmg_coalesce_key(wx, wy, wz)
        local existing = dmg_coalesce[key]
        if existing and (os.clock() - existing.time) < DMG_COALESCE_WINDOW then
            existing.damage = existing.damage + damage
            existing.time = os.clock()
        else
            dmg_coalesce[key] = { damage = damage, wx = wx, wy = wy, wz = wz, time = os.clock() }
        end
        return
    end
    dmg_list[#dmg_list + 1] = {
        time = os.clock(), text = tostring(math.floor(damage)), val = damage,
        wx = wx, wy = wy, wz = wz, sx = nil, sy = nil,
    }
end

local function dmg_flush_coalesce()
    if not C.dmg_combine then dmg_coalesce = {}; return end
    local now = os.clock()
    local expired = {}
    for key, entry in pairs(dmg_coalesce) do
        if (now - entry.time) >= DMG_COALESCE_WINDOW then
            dmg_list[#dmg_list + 1] = {
                time = now, text = tostring(math.floor(entry.damage)), val = entry.damage,
                wx = entry.wx, wy = entry.wy, wz = entry.wz, sx = nil, sy = nil,
            }
            expired[#expired + 1] = key
        end
    end
    for _, key in ipairs(expired) do dmg_coalesce[key] = nil end
end

local function install_dmg_hooks()
    if dmg_hooks_ok then return end
    pcall(function()
        local td = sdk.find_type_definition("app.EnemyAttackDamageDriver")
        if not td then return end
        local m = td:get_method("updateDamage")
        if not m then return end
        sdk.hook(m,
            function(args)
                if not C.show_damage then return sdk.PreHookResult.CALL_ORIGINAL end
                pcall(function()
                    if not args[2] then return end
                    local driver = sdk.to_managed_object(args[2])
                    if not driver then return end
                    local damage = 0
                    pcall(function()
                        damage = sdk.to_int64(args[4]) & 0xFFFFFFFF
                        if damage > 0x7FFFFFFF then damage = damage - 0x100000000 end
                    end)
                    if damage <= 0 then return end
                    local wx, wy, wz
                    pcall(function()
                        if not args[3] then return end
                        local di = sdk.to_managed_object(args[3])
                        if not di then return end
                        local pos = di:call("get_Position")
                        if pos then wx, wy, wz = pos.x, pos.y, pos.z end
                    end)
                    if not wx then
                        pcall(function()
                            local ctx = driver:call("get_Context")
                            if not ctx then return end
                            local go = ctx:call("get_GameObject")
                            if not go then return end
                            local xf = go:call("get_Transform")
                            if not xf then return end
                            local p = xf:call("get_Position")
                            if p then wx, wy, wz = p.x, p.y + 1.5, p.z end
                        end)
                    end
                    if wx then dmg_new(damage, wx, wy, wz) end
                end)
                return sdk.PreHookResult.CALL_ORIGINAL
            end,
            function(rv) return rv end)
        dmg_hooks_ok = true
        dmg_hook_pattern = "A: updateDamage"
    end)
    if not dmg_hooks_ok then
        pcall(function()
            local hp_td = sdk.find_type_definition("app.HitPoint")
            if not hp_td then return end
            local m = hp_td:get_method("addDamageHitPoint")
            if not m then return end
            sdk.hook(m,
                function(args)
                    if not C.show_damage then return sdk.PreHookResult.CALL_ORIGINAL end
                    pcall(function()
                        if not args[2] or not args[3] then return end
                        local hp_obj = sdk.to_managed_object(args[2])
                        if not hp_obj then return end
                        local damage = 0
                        pcall(function()
                            damage = sdk.to_int64(args[3]) & 0xFFFFFFFF
                            if damage > 0x7FFFFFFF then damage = damage - 0x100000000 end
                        end)
                        if damage <= 0 then return end
                        local addr = hp_obj:get_address()
                        local pos = addr and dmg_hp_cache[addr]
                        if pos then dmg_new(damage, pos.x, pos.y, pos.z) end
                    end)
                    return sdk.PreHookResult.CALL_ORIGINAL
                end,
                function(rv) return rv end)
            dmg_hooks_ok = true
            dmg_hook_pattern = "B: addDamageHitPoint"
        end)
    end
    if not dmg_hooks_ok then
        dmg_hook_pattern = "C: HP scanner"
        dmg_hooks_ok = true
    end
end

local function dmg_scan_deltas()
    if not C.show_damage or dmg_hook_pattern ~= "C: HP scanner" then return end
    local el, n = get_enemy_list()
    if not el or n <= 0 then return end
    local seen = {}
    for i = 0, n - 1 do
        pcall(function()
            local ctx = el:call("get_Item", i)
            if not ctx then return end
            local hp_obj = ctx:call("get_HitPoint")
            if not hp_obj then return end
            local addr = hp_obj:get_address()
            if not addr then return end
            seen[addr] = true
            if hp_obj:call("get_IsDead") then return end
            local cur = hp_obj:call("get_CurrentHitPoint") or 0
            local mx = hp_obj:call("get_CurrentMaximumHitPoint") or 0
            if mx <= 0 then return end
            local old = dmg_prev_hp[addr]
            dmg_prev_hp[addr] = cur
            if old and old > cur then
                local pos = dmg_hp_cache[addr]
                if pos then dmg_new(old - cur, pos.x, pos.y, pos.z) end
            end
        end)
    end
    for addr in pairs(dmg_prev_hp) do if not seen[addr] then dmg_prev_hp[addr] = nil end end
end

local function dmg_update_cache()
    local el, n = get_enemy_list()
    if not el or n <= 0 then return end
    local nc = {}
    for i = 0, n - 1 do
        pcall(function()
            local ctx = el:call("get_Item", i)
            if not ctx then return end
            local hp_obj = ctx:call("get_HitPoint")
            if not hp_obj then return end
            local addr = hp_obj:get_address()
            if not addr then return end
            local go = ctx:call("get_GameObject")
            if not go then return end
            local xf = go:call("get_Transform")
            if not xf then return end
            local p = xf:call("get_Position")
            if p then nc[addr] = {x = p.x, y = p.y + 1.5, z = p.z} end
        end)
    end
    dmg_hp_cache = nc
end

local function render_damage_numbers()
    if not C.show_damage or not has_d2d then return end
    local dmg_font = OFont.get(C.dmg_font_size, true)
    if not dmg_font then return end
    local now = os.clock()
    local alive = {}
    local to_draw = {}
    for _, dn in ipairs(dmg_list) do
        local elapsed = now - dn.time
        if elapsed < 0 then alive[#alive + 1] = dn; goto dmg_collect end
        local t = elapsed / C.dmg_duration
        if t > 1 then goto dmg_collect end
        if t < 0 then t = 0 end
        alive[#alive + 1] = dn
        local alpha = 255
        if t < 0.05 then alpha = math.floor(255 * (t / 0.05))
        elseif t > 0.65 then alpha = math.floor(255 * (1.0 - (t - 0.65) / 0.35)) end
        if alpha < 3 then goto dmg_collect end
        if alpha > 255 then alpha = 255 end
        to_draw[#to_draw + 1] = { dn = dn, t = t, alpha = alpha }
        ::dmg_collect::
    end
    dmg_list = alive
    local sw, sh = d2d.surface_size()
    sw = sw or R.screen_w or 1920
    sh = sh or R.screen_h or 1080
    local DMG_SPREAD = 25
    for idx, entry in ipairs(to_draw) do
        local dn = entry.dn
        local t  = entry.t
        local alpha = entry.alpha
        local spread_idx = idx - 1
        local screen_pos = world_to_screen(Vector3f.new(dn.wx, dn.wy, dn.wz))
        if not screen_pos then goto dmg_skip end
        local sx = screen_pos.x + spread_idx * DMG_SPREAD
        local sy = screen_pos.y - C.dmg_speed * t - spread_idx * DMG_SPREAD
        local r, g, b = 0xFF, 0xF0, 0xE0
        if C.dmg_color_on then
            local dv = tonumber(dn.text) or 0
            if dv >= C.dmg_thresh_huge then r, g, b = 0xFF, 0x33, 0x33
            elseif dv >= C.dmg_thresh_big then r, g, b = 0xFF, 0x88, 0x22 end
        end
        local text_col = (alpha << 24) | (r << 16) | (g << 8) | b
        local shadow_col = (alpha << 24)
        local so = C.dmg_shadow
        dmg_dbg.draws = dmg_dbg.draws + 1
        pcall(d2d.text, dmg_font, dn.text, sx + so, sy + so, shadow_col)
        pcall(d2d.text, dmg_font, dn.text, sx, sy, text_col)
        ::dmg_skip::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Speedrunner Overlay
-- ═══════════════════════════════════════════════════════════════════════════

local function render_speedrunner_overlay()
    if not has_d2d then return end
    if not C.show_igt and not C.show_area then return end
    local sr_font = OFont.get(20, true)
    local sr_font_sm = OFont.get(16, false)
    if not sr_font then return end
    local x, y = 24, 24
    local bg = 0xCC000000
    local white = 0xFFFFFFFF
    local gold  = 0xFFFFDD44
    local muted = 0xFFAAAAAA
    local panel_h = 8
    if C.show_igt then panel_h = panel_h + 52 end
    if C.show_area and R.area_name ~= "" then panel_h = panel_h + 24 end
    if C.death_warp and R.death_pos then panel_h = panel_h + 20 end
    if R.load_method then panel_h = panel_h + 18 end
    pcall(d2d.fill_rect, x - 4, y - 4, 280, panel_h, bg)
    if C.show_igt then
        local elapsed = os.clock() - R.session_start
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = math.floor(elapsed % 60)
        pcall(d2d.text, sr_font, string.format("Session  %02d:%02d:%02d", h, m, s), x, y, white)
        y = y + 26
        if R.igt_text ~= "" then
            pcall(d2d.text, sr_font, "IGT      " .. R.igt_text, x, y, gold)
        else
            pcall(d2d.text, sr_font_sm or sr_font, "IGT      --:--:--", x, y, muted)
        end
        y = y + 26
    end
    if C.show_area and R.area_name ~= "" then
        pcall(d2d.text, sr_font_sm or sr_font, R.area_name, x, y, muted)
        y = y + 24
    end
    if C.death_warp and R.death_pos then
        local dp = R.death_pos
        pcall(d2d.text, sr_font_sm or sr_font,
            string.format("Death: %.0f, %.0f, %.0f", dp.x, dp.y, dp.z), x, y, 0xFFFF6666)
        y = y + 20
    end
    if R.load_method then
        pcall(d2d.text, sr_font_sm or sr_font, "Load: " .. R.load_method, x, y, 0xFF66FF66)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Toast Rendering
-- ═══════════════════════════════════════════════════════════════════════════


local function render_toasts()
    if #T.toast_list == 0 then return end
    if not has_d2d then return end
    local toast_font = OFont.get(18, true)
    if not toast_font then return end
    local sw, sh = d2d.surface_size()
    sw = sw or 1920; sh = sh or 1080
    local now = os.clock()
    local alive = {}
    local to_draw = {}
    local pad = 10
    local line_h = 26
    local panel_w = 320
    for _, t in ipairs(T.toast_list) do
        local elapsed = now - t.time
        if elapsed <= t.duration then
            alive[#alive + 1] = t
            local alpha = 255
            if elapsed < 0.15 then alpha = math.floor(255 * elapsed / 0.15)
            elseif elapsed > t.duration - 0.5 then alpha = math.floor(255 * (t.duration - elapsed) / 0.5) end
            alpha = math.max(0, math.min(255, alpha))
            if alpha >= 3 then to_draw[#to_draw + 1] = { t = t, alpha = alpha } end
        end
    end
    T.toast_list = alive
    local y = sh - 40
    for i = #to_draw, 1, -1 do
        local entry = to_draw[i]
        local t = entry.t
        local alpha = entry.alpha
        local bx = sw - panel_w - 24
        local by = y - line_h - pad
        local bg_alpha = math.floor(alpha * 0.75)
        pcall(d2d.fill_rect, bx, by, panel_w, line_h + pad, (bg_alpha << 24) | 0x1A1A2E)
        local accent_rgb = (t.color or 0xFF44FF88) & 0x00FFFFFF
        pcall(d2d.fill_rect, bx, by, 3, line_h + pad, (alpha << 24) | accent_rgb)
        pcall(d2d.text, toast_font, t.text, bx + 12, by + pad / 2 + 1, (alpha << 24) | 0xEEEEEE)
        y = by - 6
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Active-Feature HUD Strip
-- ═══════════════════════════════════════════════════════════════════════════



local function render_hud_strip()
    if not C.show_hud then return end
    if not has_d2d then return end
    local tags = {}
    if C.god_mode then tags[#tags + 1] = "GOD" end
    if C.hp_lock then tags[#tags + 1] = "HP-LOCK" end
    if C.ohk then tags[#tags + 1] = "OHK" end
    if C.no_recoil then tags[#tags + 1] = "NO-REC" end
    if C.no_reload then tags[#tags + 1] = "NO-RLD" end
    if C.inf_grenades then tags[#tags + 1] = "\xE2\x88\x9EGREN" end
    if C.inf_ammo then tags[#tags + 1] = "\xE2\x88\x9EAMMO" end
    if C.inf_melee then tags[#tags + 1] = "\xE2\x88\x9EMEL" end
    if C.inf_injector then tags[#tags + 1] = "\xE2\x88\x9EINJ" end
    if C.player_speed_on then tags[#tags + 1] = string.format("%.1fx", C.run_speed) end
    if C.game_speed_on then tags[#tags + 1] = string.format("G:%.1fx", C.game_speed) end
    if C.motion_freeze then tags[#tags + 1] = "FREEZE" end
    if C.skip_cutscenes then tags[#tags + 1] = "SKIP" end
    if C.auto_parry then tags[#tags + 1] = "PARRY" end
    if C.stealth then tags[#tags + 1] = "GHOST" end
    if C.free_craft then tags[#tags + 1] = "CRAFT" end
    if C.rapid_fire then tags[#tags + 1] = "RAPID" end
    if C.headshot_boost_on then tags[#tags + 1] = string.format("HS:%.0fx", C.headshot_mult) end
    if C.map_reveal then tags[#tags + 1] = "MAP" end
    if C.super_accuracy then tags[#tags + 1] = "AIM" end
    if C.highlight_items then tags[#tags + 1] = "ITEMS" end
    if C.unlock_recipes then tags[#tags + 1] = "RECIPE" end
    if C.unlimited_saves then tags[#tags + 1] = "∞SAVE" end
    if C.remote_storage then tags[#tags + 1] = "BOX" end
    if C.enemy_speed_on then tags[#tags + 1] = string.format("ESPD:%.1fx", C.enemy_speed) end
    if #tags == 0 then return end
    local hud_font = OFont.get(14, true)
    if not hud_font then return end
    local sw = d2d.surface_size() or 1920
    local text = table.concat(tags, "  \xC2\xB7  ")
    local pad_x = 10
    local h = 24
    local w = #text * 7.5 + pad_x * 2 + 20
    local x = sw - w - 16
    local y = 16
    pcall(d2d.fill_rect, x, y, w, h, 0xBB1A1A2E)
    pcall(d2d.fill_rect, x, y + h, w, 1, 0x44444466)
    pcall(d2d.text, hud_font, text, x + pad_x, y + 4, 0xDD88CCFF)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dev Overlay — Debug player info at top-left
-- ═══════════════════════════════════════════════════════════════════════════



-- Quaternion to Euler (degrees) — works even without get_EulerAngle
local function quat_to_euler(q)
    if not q then return nil end
    local x, y, z, w = q.x or 0, q.y or 0, q.z or 0, q.w or 0
    -- pitch (x)
    local sinp = 2 * (w * x + y * z)
    local cosp = 1 - 2 * (x * x + y * y)
    local pitch = math.atan(sinp, cosp)
    -- yaw (y)
    local siny = 2 * (w * y - z * x)
    if math.abs(siny) >= 1 then
        siny = siny > 0 and 1 or -1
    end
    local yaw_val = math.asin(siny)
    -- roll (z)
    local sinr = 2 * (w * z + x * y)
    local cosr = 1 - 2 * (y * y + z * z)
    local roll = math.atan(sinr, cosr)
    return { x = math.deg(pitch), y = math.deg(yaw_val), z = math.deg(roll) }
end

local function dev_scan_info()
    -- Rotation — use WorldMatrix → quat → euler (most reliable)
    pcall(function()
        if T.get_camera_rotation_euler then
            R.dev_rotation = T.get_camera_rotation_euler()
        end
    end)
    -- Force area scan
    if T.scan_area_name then pcall(T.scan_area_name) end
end

local function render_dev_overlay()
    if not C.show_dev_overlay then return end
    if not has_d2d and not has_draw then return end

    -- Scan: immediately on first call, then every 15 frames
    if not R._dev_first_scan then
        R._dev_first_scan = true
        pcall(dev_scan_info)
    elseif R.tick and R.tick % 15 == 5 then
        pcall(dev_scan_info)
    end

    local pos = T.ppos()
    local rot = R.dev_rotation
    local area = R.area_name or ""

    -- Build text lines
    local info = {}
    info[#info + 1] = " DEV"
    if pos then
        info[#info + 1] = string.format(" Pos:  %.2f,  %.2f,  %.2f", pos.x, pos.y, pos.z)
    end
    if rot then
        info[#info + 1] = string.format(" Rot:  P %.1f  Y %.1f  R %.1f", rot.x, rot.y, rot.z)
    end
    if area ~= "" then
        info[#info + 1] = " Area:  " .. area
    end
    -- Chapter info + Level state
    if R.chapter_info then
        local ci = R.chapter_info
        if ci.chapter_name then
            info[#info + 1] = " Chap:  " .. ci.chapter_name
        elseif ci.scene then
            info[#info + 1] = " Scene: " .. ci.scene
        end
        -- Combined state: Chap3_02_Main_1200
        if ci.level_progress_name and ci.progress then
            info[#info + 1] = " State: " .. ci.level_progress_name .. "_" .. tostring(ci.progress)
        end
    end
    -- NoClip status
    if C.noclip and T.nc_state then
        local nc = T.nc_state
        local nc_pos = nc.pos
        if nc_pos then
            info[#info + 1] = string.format("NC:  %.2f,  %.2f,  %.2f", nc_pos.x, nc_pos.y, nc_pos.z)
        else
            info[#info + 1] = "NC:  (active)"
        end
    end

    if has_d2d then
        local dev_font = OFont.get(16, true)
        local dev_font_sm = OFont.get(14, false)
        if not dev_font then return end

        -- Position below speedrunner overlay if it's active
        local x, y = 24, 10
        if C.show_igt or C.show_area then
            local sr_h = 8
            if C.show_igt then sr_h = sr_h + 52 end
            if C.show_area and R.area_name ~= "" then sr_h = sr_h + 24 end
            if C.death_warp and R.death_pos then sr_h = sr_h + 20 end
            if R.load_method then sr_h = sr_h + 18 end
            y = y + sr_h + 8
        end

        local line_h = 20
        local pad = 6
        local panel_h = pad * 2 + #info * line_h

        pcall(d2d.fill_rect, x - pad, y - pad, 360, panel_h, 0xCC0A0A1E)
        pcall(d2d.fill_rect, x - pad, y - pad, 3, panel_h, 0xDD44FF88)
        R.dev_overlay_bottom = y - pad + panel_h + 8  -- store bottom for panel offset

        local f = dev_font_sm or dev_font
        for i, line in ipairs(info) do
            local col = (i == 1) and 0xFF44FF88 or 0xFFE0E0E0
            if line:sub(1, 4) == "Area" then col = 0xFFAAAAAA end
            if line:sub(1, 4) == "Chap" or line:sub(1, 5) == "Scene" then col = 0xFFFFCC44 end
            if line:sub(1, 2) == "NC" then col = 0xFF44FFFF end
            pcall(d2d.text, (i == 1) and dev_font or f, line, x, y, col)
            y = y + line_h
        end
    elseif has_draw then
        -- Fallback: draw.text at top-left
        local x, y = 16, 16
        if C.show_igt or C.show_area then y = y + 120 end
        for _, line in ipairs(info) do
            draw.text(line, x, y, 0xFFFFFFFF)
            y = y + 24
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawn Point Visualization
-- ═══════════════════════════════════════════════════════════════════════════

local spawn_cache = {}
local spawn_last_scan = 0
local spawn_font = nil  -- set each frame by render_spawn_markers


local function scan_spawn_points()
    local results = {}

    -- Find all GameObjects in the scene via ObjectManager
    pcall(function()
        local scene = get_scene()
        if not scene then return end

        -- Iterate transforms in scene to find spawn param objects
        local xf_td = sdk.find_type_definition("via.Transform")
        if not xf_td then return end

        -- Use ObjectManager to find spawn param components
        local obj_mgr = mgr("app.ObjectManager")
        if not obj_mgr then
            -- Fallback: try finding components by type pattern
            -- Search for known spawn param types
            local spawn_types = {}
            pcall(function()
                -- Try to find types matching the Cp_*SpawnParam pattern
                local type_names = {
                    "app.Cp_E010SpawnParam", "app.Cp_E110SpawnParam",
                    "app.Cp_E210SpawnParam", "app.Cp_E310SpawnParam",
                    "app.Cp_E410SpawnParam", "app.Cp_E510SpawnParam",
                    "app.Cp_B000SpawnParam", "app.Cp_B001SpawnParam",
                    "app.Cp_B002SpawnParam", "app.Cp_B003SpawnParam",
                    "app.Cp_B004SpawnParam", "app.Cp_B007SpawnParam",
                    "app.Cp_B050SpawnParam", "app.Cp_B051SpawnParam",
                    "app.Cp_B052SpawnParam", "app.Cp_B053SpawnParam",
                    "app.Cp_B060SpawnParam", "app.Cp_B070SpawnParam",
                }
                for _, tn in ipairs(type_names) do
                    local td = sdk.find_type_definition(tn)
                    if td then spawn_types[#spawn_types + 1] = td end
                end
            end)

            -- Find components of each type in the scene
            for _, sp_td in ipairs(spawn_types) do
                pcall(function()
                    local comps = scene:call("findComponents(System.Type)", sp_td:get_runtime_type())
                    if comps then
                        local count = comps:call("get_Count")
                        for i = 0, (count or 0) - 1 do
                            pcall(function()
                                local comp = comps:call("get_Item", i)
                                if not comp then return end
                                local go = comp:call("get_GameObject")
                                if not go then return end
                                local xf = go:call("get_Transform")
                                if not xf then return end
                                local pos = xf:get_Position()
                                if not pos then return end
                                local name = go:call("get_Name") or "Spawn"
                                local spawn_id = nil
                                if T.extract_field_guid then
                                    pcall(function() spawn_id = T.extract_field_guid(comp, "_SpawnID") end)
                                end
                                -- Extract GameObject path and address using shared helpers
                                local go_guid = nil
                                local go_addr = nil
                                if T.extract_go_guid then
                                    pcall(function() go_guid = T.extract_go_guid(go) end)
                                end
                                if T.extract_go_addr then
                                    pcall(function() go_addr = T.extract_go_addr(go) end)
                                end
                                results[#results + 1] = {
                                    name = tostring(name),
                                    x = pos.x, y = pos.y, z = pos.z,
                                    type = sp_td:get_name(),
                                    spawn_id = spawn_id and tostring(spawn_id) or nil,
                                    guid = go_guid,
                                    go_addr = go_addr,
                                }
                            end)
                        end
                    end
                end)
            end
            return
        end
    end)

    -- Alternative: iterate all transforms and check for SpawnParam components
    if #results == 0 then
        pcall(function()
            local scene = get_scene()
            if not scene then return end

            -- Find via transform iteration
            local tf_td = sdk.find_type_definition("via.Transform")
            local get_next = tf_td and tf_td:get_method("get_Next")
            local get_child = tf_td and tf_td:get_method("get_Child")
            if not get_next then return end

            -- Try finding spawns by iterating scene objects
            local scene_td = sdk.find_type_definition("via.Scene")
            if not scene_td then return end
            local root_m = scene_td:get_method("get_FirstTransform")
            if not root_m then return end

            local root_xf = root_m:call(root_m, scene)
            if not root_xf then return end

            local count = 0
            local xf = root_xf
            while xf and count < 5000 do
                count = count + 1
                pcall(function()
                    local go = xf:call("get_GameObject")
                    if not go then return end
                    local go_name = go:call("get_Name") or ""
                    -- Check if this is a spawn param object by name pattern
                    if go_name:find("SpawnParam") then
                        local pos = xf:get_Position()
                        if pos then
                            -- Extract GameObject path and address using shared helpers
                            local go_guid = nil
                            local go_addr = nil
                            if T.extract_go_guid then
                                pcall(function() go_guid = T.extract_go_guid(go) end)
                            end
                            if T.extract_go_addr then
                                pcall(function() go_addr = T.extract_go_addr(go) end)
                            end
                            results[#results + 1] = {
                                name = tostring(go_name),
                                x = pos.x, y = pos.y, z = pos.z,
                                type = "SpawnParam",
                                guid = go_guid,
                                go_addr = go_addr,
                            }
                        end
                    end
                end)
                -- Move to next sibling or up
                local next_ok, next_xf = pcall(get_next.call, get_next, xf)
                if next_ok and next_xf then
                    xf = next_xf
                else
                    break
                end
            end
        end)
    end

    spawn_cache = results
end

-- ── Style 1: Cylinder (original) ──

local function render_spawn_cylinder(sp, dist, pp, short)
    local COL_FILL    = 0x5500AAFF
    local COL_BORDER  = 0xCC00CCFF
    local COL_TOP     = 0x4400DDFF
    local COL_LINE    = 0xAA00CCFF
    local COL_TEXT    = 0xFFFFCC44
    local COL_DIST    = 0xFFBBBBBB
    local COL_DOT     = 0xFFFFFFFF

    local wp_bot = Vector3f.new(sp.x, sp.y, sp.z)
    local wp_top = Vector3f.new(sp.x, sp.y + 1.8, sp.z)
    local wp_label = Vector3f.new(sp.x, sp.y + 1.9, sp.z)

    if not is_in_sight(wp_bot) and not is_in_sight(wp_top) then return end

    local sb = world_to_screen(wp_bot)
    local st = world_to_screen(wp_top)
    local sl = world_to_screen(wp_label)
    if not sb or not st then return end

    local cx_bot, cy_bot = sb.x, sb.y
    local cx_top, cy_top = st.x, st.y

    local cyl_h = cy_bot - cy_top
    if cyl_h < 4 then cyl_h = 4 end

    local radius = math.max(8, math.min(40, math.floor(600 / (dist + 5))))

    local oval_h = math.max(3, math.floor(radius * 0.35))
    pcall(d2d.fill_rect, cx_bot - radius, cy_bot - oval_h/2, radius * 2, oval_h, COL_FILL)
    pcall(d2d.fill_rect, cx_bot - radius, cy_bot - 1, radius * 2, 2, COL_BORDER)

    pcall(d2d.fill_rect, cx_top - radius, cy_top, radius * 2, cyl_h, COL_FILL)

    pcall(d2d.fill_rect, cx_bot - radius, cy_top, 2, cyl_h, COL_LINE)
    pcall(d2d.fill_rect, cx_bot + radius - 2, cy_top, 2, cyl_h, COL_LINE)
    pcall(d2d.fill_rect, cx_bot - 1, cy_top, 2, cyl_h, 0x4400CCFF)

    pcall(d2d.fill_rect, cx_top - radius, cy_top - oval_h/2, radius * 2, oval_h, COL_TOP)
    pcall(d2d.fill_rect, cx_top - radius, cy_top - 1, radius * 2, 2, COL_BORDER)

    pcall(d2d.fill_rect, cx_bot - 3, cy_bot - 3, 6, 6, COL_DOT)

    local lx = sl and sl.x or cx_top
    local ly = sl and sl.y or (cy_top - 4)
    local label = pp and string.format("%s  %.0fm", short, dist) or short
    draw_text_pill(spawn_font, label, lx - 20, ly - 14, COL_TEXT, 14)
    if C.show_guid_titles and sp.guid and spawn_font then
        draw_text_pill(spawn_font, sp.guid, lx - 20, ly, 0xFFAABBCC, 14, 0x66111118)
    end
end

-- ── Style 2: Diamond ──

local function render_spawn_diamond(sp, dist, pp, short)
    local COL_FILL   = 0x7700BBFF
    local COL_BORDER = 0xDD00DDFF
    local COL_LINE   = 0x6600AAFF
    local COL_TEXT   = 0xFFFFCC44
    local COL_DIST   = 0xFFBBBBBB
    local COL_DOT    = 0xFFFFFFFF

    local wp_ground = Vector3f.new(sp.x, sp.y, sp.z)
    local wp_mid    = Vector3f.new(sp.x, sp.y + 1.4, sp.z)
    local wp_label  = Vector3f.new(sp.x, sp.y + 1.5, sp.z)

    if not is_in_sight(wp_ground) and not is_in_sight(wp_mid) then return end

    local sg = world_to_screen(wp_ground)
    local sm = world_to_screen(wp_mid)
    local sl = world_to_screen(wp_label)
    if not sm then return end

    local cx, cy = sm.x, sm.y
    local size = math.max(6, math.min(24, math.floor(360 / (dist + 5))))

    for i = 0, size do
        local w = math.floor(size - i)
        if w > 0 then
            pcall(d2d.fill_rect, cx - w, cy - i, w * 2, 1, COL_FILL)
        end
    end
    for i = 0, size do
        local w = math.floor(size - i)
        if w > 0 then
            pcall(d2d.fill_rect, cx - w, cy + i, w * 2, 1, COL_FILL)
        end
    end

    pcall(d2d.fill_rect, cx - 1, cy - size - 1, 2, 2, COL_BORDER)
    pcall(d2d.fill_rect, cx - 1, cy + size, 2, 2, COL_BORDER)
    pcall(d2d.fill_rect, cx - size - 1, cy - 1, 2, 2, COL_BORDER)
    pcall(d2d.fill_rect, cx + size, cy - 1, 2, 2, COL_BORDER)

    if sg then
        local line_h = sg.y - (cy + size)
        if line_h > 2 then
            pcall(d2d.fill_rect, cx - 1, cy + size, 2, line_h, COL_LINE)
        end
        pcall(d2d.fill_rect, sg.x - 3, sg.y - 3, 6, 6, COL_DOT)
    end

    local lx, ly = sl and sl.x or cx, sl and sl.y or (cy - size - 4)
    local label = pp and string.format("%s  %.0fm", short, dist) or short
    draw_text_pill(spawn_font, label, lx - 20, ly - 14, COL_TEXT, 14)
    if C.show_guid_titles and sp.guid and spawn_font then
        draw_text_pill(spawn_font, sp.guid, lx - 20, ly, 0xFFAABBCC, 14, 0x66111118)
    end
end

-- ── Style 3: Beacon ──

local function render_spawn_beacon(sp, dist, pp, short)
    local COL_LINE_MAIN = 0xAA00CCFF
    local COL_LINE_DIM  = 0x4400AAFF
    local COL_TEXT      = 0xFFFFCC44
    local COL_DIST      = 0xFFBBBBBB
    local COL_DOT       = 0xFFFFFFFF

    local wp_ground = Vector3f.new(sp.x, sp.y, sp.z)
    local wp_top    = Vector3f.new(sp.x, sp.y + 4.0, sp.z)
    local wp_label  = Vector3f.new(sp.x, sp.y + 4.1, sp.z)

    if not is_in_sight(wp_ground) and not is_in_sight(wp_top) then return end

    local sg = world_to_screen(wp_ground)
    local st = world_to_screen(wp_top)
    local sl = world_to_screen(wp_label)
    if not sg then return end

    if st then
        local line_h = sg.y - st.y
        if line_h > 2 then
            local mid = math.floor(line_h * 0.4)
            pcall(d2d.fill_rect, sg.x - 1, st.y, 2, line_h - mid, COL_LINE_DIM)
            pcall(d2d.fill_rect, sg.x - 1, st.y + line_h - mid, 2, mid, COL_LINE_MAIN)
        end
    end

    local pulse = (os.clock() * 2.0) % 1.0
    local ring_max = math.max(10, math.min(50, math.floor(800 / (dist + 5))))
    local ring_r = math.floor(ring_max * pulse)
    local ring_alpha = math.floor(200 * (1.0 - pulse))
    local ring_col = (ring_alpha << 24) | 0x00CCFF

    if ring_r > 2 then
        local rx, ry = sg.x, sg.y
        pcall(d2d.fill_rect, rx - ring_r, ry - 1, ring_r * 2, 2, ring_col)
        pcall(d2d.fill_rect, rx - 1, ry - math.floor(ring_r * 0.35), 2, math.floor(ring_r * 0.7), ring_col)
        local arc_w = math.floor(ring_r * 0.7)
        pcall(d2d.fill_rect, rx - arc_w, ry - math.floor(ring_r * 0.35), arc_w * 2, 1, ring_col)
        pcall(d2d.fill_rect, rx - arc_w, ry + math.floor(ring_r * 0.35), arc_w * 2, 1, ring_col)
    end

    pcall(d2d.fill_rect, sg.x - 3, sg.y - 3, 6, 6, COL_DOT)

    local static_r = math.max(6, math.floor(ring_max * 0.3))
    pcall(d2d.fill_rect, sg.x - static_r, sg.y - 1, static_r * 2, 2, 0x8800CCFF)
    local static_arc = math.floor(static_r * 0.5)
    pcall(d2d.fill_rect, sg.x - static_arc, sg.y - math.floor(static_r * 0.2), static_arc * 2, 1, 0x6600CCFF)
    pcall(d2d.fill_rect, sg.x - static_arc, sg.y + math.floor(static_r * 0.2), static_arc * 2, 1, 0x6600CCFF)

    local lx, ly = sl and sl.x or sg.x, sl and sl.y or (sg.y - 40)
    local label = pp and string.format("%s  %.0fm", short, dist) or short
    draw_text_pill(spawn_font, label, lx - 20, ly - 14, COL_TEXT, 14)
    if C.show_guid_titles and sp.guid and spawn_font then
        draw_text_pill(spawn_font, sp.guid, lx - 20, ly, 0xFFAABBCC, 14, 0x66111118)
    end
end

-- ── Style 4: Minimal (text-only) ──

local function render_spawn_minimal(sp, dist, pp, short)
    local COL_TEXT = 0xFFFFCC44
    local COL_DIST = 0xFFBBBBBB
    local COL_BG   = 0x88000000

    local wp = Vector3f.new(sp.x, sp.y + 1.5, sp.z)
    if not is_in_sight(wp) then return end
    local sc = world_to_screen(wp)
    if not sc then return end

    local cx, cy = sc.x, sc.y
    local label = pp and string.format("%s  %.0fm", short, dist) or short
    local text_w = #label * 7 + 12
    pcall(d2d.fill_rect, cx - text_w / 2, cy - 10, text_w, 20, COL_BG)
    pcall(d2d.text, spawn_font, label, cx - text_w / 2 + 6, cy - 8, COL_TEXT)
    if C.show_guid_titles and sp.guid and spawn_font then
        pcall(d2d.text, spawn_font, sp.guid, cx - #sp.guid * 3.5, cy + 12, 0xFFAABBCC)
    end
end

-- ── Spawn Marker Dispatcher ──

local function render_spawn_markers()
    if not C.show_spawns then return end
    if not R.spawn_ui_open then return end
    if not has_d2d then return end

    spawn_font = OFont.get(14, true)
    if not spawn_font then return end

    -- Periodic scan
    local tick = R.tick or 0
    if tick - spawn_last_scan > 120 or #spawn_cache == 0 then
        spawn_last_scan = tick
        pcall(scan_spawn_points)
        R.spawn_cache = spawn_cache  -- expose to UI
    end

    if #spawn_cache == 0 then return end

    local pp = T.ppos()
    local max_dist = C.spawn_range or 100
    local style = C.spawn_style or 1

    for _, sp in ipairs(spawn_cache) do
        pcall(function()
            -- Distance check
            local dist = pp and dist3(sp, pp) or 0
            if dist > max_dist then return end

            -- Shared label info
            local label = sp.name or "Spawn"
            local short = label:match("cp_(%w+)SpawnParam") or label:match("cp_(%w+)") or label

            -- Dispatch to style renderer
            if style == 2 then
                render_spawn_diamond(sp, dist, pp, short)
            elseif style == 3 then
                render_spawn_beacon(sp, dist, pp, short)
            elseif style == 4 then
                render_spawn_minimal(sp, dist, pp, short)
            else
                render_spawn_cylinder(sp, dist, pp, short)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Register D2D rendering
-- ═══════════════════════════════════════════════════════════════════════════

local render_emv_objects_overlay  -- forward declaration (defined below, used in D2D callback)

if has_d2d then
    d2d.register(function() end, function()
        pcall(draw_enemy_panel)
        pcall(render_esp)
        pcall(render_damage_numbers)
        pcall(render_toasts)
        pcall(render_hud_strip)
        pcall(render_dev_overlay)
        pcall(render_spawn_markers)
        pcall(render_emv_objects_overlay)
    end)
end

-- Export
T.draw_enemy_panel = draw_enemy_panel
T.render_esp = render_esp
T.render_damage_numbers = render_damage_numbers
T.render_toasts = render_toasts
T.render_hud_strip = render_hud_strip
T.render_dev_overlay = render_dev_overlay
T.dev_scan_info = dev_scan_info
T.render_spawn_markers = render_spawn_markers
T.scan_spawn_points = scan_spawn_points
T.install_dmg_hooks = install_dmg_hooks
T.dmg_flush_coalesce = dmg_flush_coalesce
T.dmg_update_cache = dmg_update_cache
T.dmg_scan_deltas = dmg_scan_deltas
T.world_to_screen = world_to_screen
T.is_in_sight = is_in_sight
T.OFont = OFont

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Indicator Rendering
-- ═══════════════════════════════════════════════════════════════════════════

local function render_item_indicators()
    if not C.show_items then return end
    local items = R.item_indicators
    if not items or not next(items) then return end

    local camera = sdk.get_primary_camera()
    if not camera then return end
    local vpm = camera:call("get_ViewProjMatrix")
    if not vpm then return end

    local sm = sdk.get_native_singleton("via.SceneManager")
    local sm_td = sdk.find_type_definition("via.SceneManager")
    if not sm or not sm_td then return end
    local mainView = sdk.call_native_func(sm, sm_td, "get_MainView")
    if not mainView then return end
    local screen_size = mainView:call("get_WindowSize")
    if not screen_size then return end
    local sw, sh = screen_size.w, screen_size.h

    for _, itm in pairs(items) do
        local show = true
        if itm.is_key then
            show = C.show_key_items
        elseif itm.category == "Box" then
            show = C.show_box_items
        elseif itm.category == "Raccoon" then
            show = C.show_raccoon
        elseif itm.category == "Spawner" then
            show = C.show_item_spawner
        else
            show = C.show_item_core
        end

        if show and itm.pos then
            local v0, v1, v2, v3 = vpm[0], vpm[1], vpm[2], vpm[3]
            local px, py, pz = itm.pos.x, itm.pos.y, itm.pos.z
            local clipX = v0.x * px + v1.x * py + v2.x * pz + v3.x
            local clipY = v0.y * px + v1.y * py + v2.y * pz + v3.y
            local clipW = v0.w * px + v1.w * py + v2.w * pz + v3.w
            if clipW > 0.001 then
                local nx, ny = clipX / clipW, clipY / clipW
                local sx = (1.0 + nx) * 0.5 * sw
                local sy = (1.0 - ny) * 0.5 * sh

                -- Source color first, then category overrides
                local color = 0xFFCCCCCC -- default gray
                if itm.source == "spawner" then
                    color = C.color_item_spawner
                elseif itm.source == "core" then
                    color = C.color_item_core
                end
                -- Category overrides source
                if itm.is_key then
                    color = C.color_item_key
                elseif itm.category == "Box" then
                    color = C.color_item_box
                elseif itm.category == "Raccoon" then
                    color = C.color_item_raccoon
                end

                local src_tag = ""
                if itm.source == "spawner" then src_tag = " (IS)"
                elseif itm.source == "core" then src_tag = " [C]" end
                local text = string.format("%s%s%s: %.0fm", itm.name, itm.suffix or "", src_tag, itm.dist or 0)
                draw.text(text, sx, sy, color)
                -- GUID below item label (when enabled)
                if C.show_guid_titles and itm.guid then
                    draw.text(itm.guid, sx, sy + 16, 0xFFFFCC44)
                end
            end
        end
    end
end

T.render_item_indicators = render_item_indicators

-- ═══════════════════════════════════════════════════════════════════════════
-- EMV Objects 3D Overlay (same pattern as item indicators)
-- ═══════════════════════════════════════════════════════════════════════════

render_emv_objects_overlay = function()
    local EMV = _G.EMV
    if not EMV then return end
    local cfg = EMV._overlay_cfg
    if not cfg or not cfg.enabled then return end
    local objects = EMV._overlay_objects
    if not objects or #objects == 0 then return end

    local style = cfg.style or C.obj_overlay_style or 5
    local pp = T.ppos()

    -- For styles 1-4 (3D markers), lightweight direct rendering via VPM
    if style >= 1 and style <= 4 and has_d2d then
        spawn_font = OFont.get(14, true)
        if not spawn_font then return end

        local camera = sdk.get_primary_camera()
        if not camera then return end
        local vpm = camera:call("get_ViewProjMatrix")
        if not vpm then return end
        local sw, sh = R.screen_w, R.screen_h
        if (not sw or sw <= 0) then
            pcall(function()
                local sm = sdk.get_native_singleton("via.SceneManager")
                local sm_td = sdk.find_type_definition("via.SceneManager")
                if not sm or not sm_td then return end
                local mainView = sdk.call_native_func(sm, sm_td, "get_MainView")
                if not mainView then return end
                local screen_size = mainView:call("get_WindowSize")
                if screen_size then sw, sh = screen_size.w, screen_size.h end
            end)
        end
        if not sw or sw <= 0 then return end

        local v0, v1, v2, v3 = vpm[0], vpm[1], vpm[2], vpm[3]

        -- Inline project helper (pure math, no SDK calls)
        local function proj(wx, wy, wz)
            local cX = v0.x*wx + v1.x*wy + v2.x*wz + v3.x
            local cY = v0.y*wx + v1.y*wy + v2.y*wz + v3.y
            local cW = v0.w*wx + v1.w*wy + v2.w*wz + v3.w
            if cW <= 0.001 then return nil end
            return (1.0 + cX/cW)*0.5*sw, (1.0 - cY/cW)*0.5*sh
        end

        local world_slots = {}
        local COL_FILL   = 0x5500AAFF
        local COL_BORDER = 0xCC00CCFF
        local COL_TEXT   = 0xFFFFCC44
        local COL_DOT    = 0xFFFFFFFF
        local ppx, ppy, ppz = pp and pp.x, pp and pp.y, pp and pp.z
        local fmt = "%s  %.0fm"

        for i = 1, #objects do
            local obj = objects[i]
            local px, py, pz = obj.x, obj.y, obj.z
            local live_dist = obj.dist or 0

            -- Read live position (single pcall, no nesting)
            local go = obj.gameobj
            if go then
                local ok, xf = pcall(go.call, go, "get_Transform")
                if ok and xf then
                    local ok2, p = pcall(xf.call, xf, "get_Position")
                    if ok2 and p then
                        px, py, pz = p.x, p.y, p.z
                        if ppx then
                            local dx, dy, dz = px - ppx, py - ppy, pz - ppz
                            live_dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                        end
                    end
                end
            end
            if not px then goto next_obj end

            do -- scope block for local variables
                -- World-space stacking
                local wk = math.floor(px*2) .. "," .. math.floor(py*2) .. "," .. math.floor(pz*2)
                local wi = world_slots[wk] or 0
                world_slots[wk] = wi + 1
                local y_stack = wi * 0.4

                local sx, sy = proj(px, py + y_stack, pz)
                if not sx then goto next_obj end

                local short = obj.name or "?"
                local label = string.format(fmt, short, live_dist)
                local radius = math.max(6, math.min(30, math.floor(400 / (live_dist + 5))))

                if style == 1 then
                    -- Cylinder: filled rect below marker point
                    local bot_sx, bot_sy = proj(px, py - 1.8 + y_stack, pz)
                    if bot_sy then
                        local h = math.max(4, bot_sy - sy)
                        pcall(d2d.fill_rect, sx - radius, sy, radius*2, h, COL_FILL)
                        pcall(d2d.fill_rect, sx - radius, sy, 2, h, COL_BORDER)
                        pcall(d2d.fill_rect, sx + radius - 2, sy, 2, h, COL_BORDER)
                        pcall(d2d.fill_rect, sx - radius, sy, radius*2, 2, COL_BORDER)
                        pcall(d2d.fill_rect, sx - radius, bot_sy - 2, radius*2, 2, COL_BORDER)
                    end
                    pcall(d2d.fill_rect, sx - 3, sy - 3, 6, 6, COL_DOT)
                elseif style == 2 then
                    -- Diamond: diamond shape + ground line below
                    local dsx, dsy = proj(px, py - 0.5 + y_stack, pz)  -- diamond sits 0.5m below obj
                    local gsx, gsy = proj(px, py - 1.8 + y_stack, pz)  -- ground point
                    if not dsx then return end
                    local size = math.max(4, math.min(16, radius))
                    -- Draw ground line from diamond to ground
                    if gsy then
                        local line_h = gsy - (dsy + size)
                        if line_h > 2 then
                            pcall(d2d.fill_rect, dsx - 1, dsy + size, 2, line_h, 0x6600AAFF)
                        end
                        pcall(d2d.fill_rect, gsx - 3, gsy - 3, 6, 6, COL_DOT)  -- ground dot
                    end
                    -- Draw diamond shape
                    for i = 0, size do
                        local w = size - i
                        if w > 0 then
                            pcall(d2d.fill_rect, dsx - w, dsy - i, w*2, 1, COL_FILL)
                            pcall(d2d.fill_rect, dsx - w, dsy + i, w*2, 1, COL_FILL)
                        end
                    end
                    -- Corner dots
                    pcall(d2d.fill_rect, dsx - 1, dsy - size - 1, 2, 2, COL_BORDER)
                    pcall(d2d.fill_rect, dsx - 1, dsy + size, 2, 2, COL_BORDER)
                    pcall(d2d.fill_rect, dsx - size - 1, dsy - 1, 2, 2, COL_BORDER)
                    pcall(d2d.fill_rect, dsx + size, dsy - 1, 2, 2, COL_BORDER)
                    sx, sy = dsx, dsy  -- use diamond pos for label
                elseif style == 3 then
                    -- Beacon: pulsing line
                    local bot_sx, bot_sy = proj(px, py - 2.0 + y_stack, pz)
                    if bot_sy then
                        local h = math.max(4, bot_sy - sy)
                        pcall(d2d.fill_rect, sx - 1, sy, 2, h, COL_BORDER)
                    end
                    local pulse = (os.clock() * 2.0) % 1.0
                    local pr = math.floor(radius * pulse)
                    local pa = math.floor(200 * (1.0 - pulse))
                    local pc = (pa << 24) | 0x00CCFF
                    if pr > 2 then
                        pcall(d2d.fill_rect, sx - pr, sy - 1, pr*2, 2, pc)
                    end
                    pcall(d2d.fill_rect, sx - 3, sy - 3, 6, 6, COL_DOT)
                elseif style == 4 then
                    -- Minimal: just the text pill at position
                    pcall(d2d.fill_rect, sx - 3, sy - 3, 6, 6, COL_DOT)
                end

                -- Label above marker
                draw_text_pill(spawn_font, label, sx - 20, sy - 18, COL_TEXT, 14)
                if C.show_guid_titles and obj.guid and spawn_font then
                    draw_text_pill(spawn_font, obj.guid, sx - 20, sy - 4, 0xFFAABBCC, 14, 0x66111118)
                end
            end -- do block
            ::next_obj::
        end
        return
    end

    -- Style 5: Text-only labels (d2d text with VPM projection)
    spawn_font = OFont.get(14, true)
    if not spawn_font then return end

    local camera = sdk.get_primary_camera()
    if not camera then return end
    local vpm = camera:call("get_ViewProjMatrix")
    if not vpm then return end
    local sw, sh = R.screen_w, R.screen_h
    if (not sw or sw <= 0) then
        pcall(function()
            local sm = sdk.get_native_singleton("via.SceneManager")
            local sm_td = sdk.find_type_definition("via.SceneManager")
            if not sm or not sm_td then return end
            local mainView = sdk.call_native_func(sm, sm_td, "get_MainView")
            if not mainView then return end
            local screen_size = mainView:call("get_WindowSize")
            if screen_size then sw, sh = screen_size.w, screen_size.h end
        end)
    end
    if not sw or sw <= 0 then return end

    local v0, v1, v2, v3 = vpm[0], vpm[1], vpm[2], vpm[3]
    local function proj5(wx, wy, wz)
        local cX = v0.x*wx + v1.x*wy + v2.x*wz + v3.x
        local cY = v0.y*wx + v1.y*wy + v2.y*wz + v3.y
        local cW = v0.w*wx + v1.w*wy + v2.w*wz + v3.w
        if cW <= 0.001 then return nil end
        return (1.0 + cX/cW)*0.5*sw, (1.0 - cY/cW)*0.5*sh
    end

    local slots = {}
    local LINE_H = 16
    local ppx, ppy, ppz = pp and pp.x, pp and pp.y, pp and pp.z

    for i = 1, #objects do
        local obj = objects[i]
        local px, py, pz = obj.x, obj.y, obj.z
        local live_dist = obj.dist or 0

        local go = obj.gameobj
        if go then
            local ok, xf = pcall(go.call, go, "get_Transform")
            if ok and xf then
                local ok2, p = pcall(xf.call, xf, "get_Position")
                if ok2 and p then
                    px, py, pz = p.x, p.y, p.z
                    if ppx then
                        local dx, dy, dz = px - ppx, py - ppy, pz - ppz
                        live_dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    end
                end
            end
        end
        if not px then goto next_txt end

        do
            local sx, sy = proj5(px, py, pz)
            if not sx then goto next_txt end

            local slot_key = math.floor(sx / 80) .. "," .. math.floor(sy / 80)
            local slot_idx = slots[slot_key] or 0
            slots[slot_key] = slot_idx + 1

            local lines = 1
            if C.show_guid_titles then
                if obj.guid then lines = lines + 1 end
                if obj.folder_path then lines = lines + 1 end
            end
            local stack_off = slot_idx * (LINE_H * lines + 4)

            local text = string.format("%s  %.0fm", obj.name or "?", live_dist)
            local color = obj.color or 0xFFFFFFFF
            local ly = sy - 10 + stack_off
            draw_text_pill(spawn_font, text, sx - 20, ly, color, 14)

            if C.show_guid_titles and obj.guid then
                draw_text_pill(spawn_font, obj.guid, sx - 20, ly + LINE_H, 0xFFAABBCC, 14, 0x66111118)
            end
            if C.show_guid_titles and obj.folder_path then
                local gy = obj.guid and (ly + LINE_H * 2) or (ly + LINE_H)
                draw_text_pill(spawn_font, obj.folder_path, sx - 20, gy, 0xFF88AACC, 14, 0x66111118)
            end
        end
        ::next_txt::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Level Flow Rendering — show LFC positions in world
-- ═══════════════════════════════════════════════════════════════════════════

local function render_level_flow()
    local lfcs = R.level_flow_controllers
    if not lfcs or #lfcs == 0 then return end

    local camera = sdk.get_primary_camera()
    if not camera then return end
    local vpm = camera:call("get_ViewProjectionMatrix")
    if not vpm then return end
    local sm = sdk.get_native_singleton("via.SceneManager")
    if not sm then return end
    local sm_td = sdk.find_type_definition("via.SceneManager")
    if not sm_td then return end
    local mainView = sdk.call_native_func(sm, sm_td, "get_MainView")
    if not mainView then return end
    local screen_size = mainView:call("get_WindowSize")
    if not screen_size then return end
    local sw, sh = screen_size.w, screen_size.h

    local pp = T.ppos()

    for _, lfc in ipairs(lfcs) do
        if lfc.pos then
            pcall(function()
                local px, py, pz = lfc.pos.x, lfc.pos.y, lfc.pos.z
                local v0, v1, v2, v3 = vpm[0], vpm[1], vpm[2], vpm[3]
                local clipX = v0.x * px + v1.x * py + v2.x * pz + v3.x
                local clipY = v0.y * px + v1.y * py + v2.y * pz + v3.y
                local clipW = v0.w * px + v1.w * py + v2.w * pz + v3.w
                if clipW <= 0.001 then return end
                local nx, ny = clipX / clipW, clipY / clipW
                local sx = (1.0 + nx) * 0.5 * sw
                local sy = (1.0 - ny) * 0.5 * sh

                -- Distance
                local dist = 0
                if pp then
                    local dx, dy, dz = px - pp.x, py - pp.y, pz - pp.z
                    dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                end

                -- Name + BT state
                local go_name = lfc.go_name or "?"
                local is_main = go_name:find("_Main") ~= nil
                local col = is_main and 0xFF44FF88 or 0xFFFFCC44  -- green for main, yellow for sub
                local bt_str = lfc.bt_node and tostring(lfc.bt_node) or ""
                local label = go_name
                if bt_str ~= "" and bt_str ~= "0" then
                    label = label .. " → " .. bt_str
                end
                label = label .. string.format(": %.0fm", dist)

                draw.text(label, sx, sy, col)
            end)
        end
    end
end

T.render_level_flow = render_level_flow

log.info("[Trainer] Rendering module loaded")
