--[[
    objects_tab.lua — Objects Browser + Live Editor
    EMV Engine Module (Phase 4)

    Uses the SAME discovery methods as the trainer's ESP/indicators:
    - Enemies:  mgr("app.CharacterManager") → get_EnemyContextList()
    - Items:    mgr("app.ItemManager") → _ValidateCheckItems
    - Spawners: scene:findComponents(rt:get_runtime_type()) for app.ItemSpawner
    - Gimmicks: mgr("app.GimmickManager") → _GimmickCoreDB
    - All:      scene:get_FirstTransform → get_Next linked list
]]

local ObjectsTab = {}
local CoreFunctions, ControlPanel, ImguiHelpers, ObjectExplorer

-- ═══════════════════════════════════════════════════════════════════════════
-- Helpers — delegate to trainer cache when available, fallback to raw SDK
-- ═══════════════════════════════════════════════════════════════════════════

local _trainer_mgr = nil  -- set in setup() if trainer T table available

local function mgr(name)
    if _trainer_mgr then return _trainer_mgr(name) end
    local r = nil
    pcall(function() r = sdk.get_managed_singleton(name) end)
    return r
end

local _trainer_ppos = nil  -- set in setup() if trainer T table available

local function ppos()
    if _trainer_ppos then return _trainer_ppos() end
    local pp = nil
    pcall(function()
        local cam = sdk.get_primary_camera()
        if not cam then return end
        local go = cam:call("get_GameObject")
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local p = xf:call("get_Position")
        if p then pp = {x=p.x, y=p.y, z=p.z} end
    end)
    return pp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════════════

local state = {
    objects       = {},
    filtered      = {},
    total         = 0,
    search_text   = "",
    max_distance  = 100,
    sort_by_dist  = true,
    filter_idx    = 1,
    last_scan     = 0,
    scan_interval = 3.0,
    needs_rescan  = true,
    scan_info     = "...",
    hide_static   = true,
    show_overlay  = false,
    enabled       = false,
    pp            = nil,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Categories
-- ═══════════════════════════════════════════════════════════════════════════

local CATEGORIES = {
    { label = "All",       scan = "all" },
    { label = "Enemies",   scan = "enemies" },
    { label = "Items",     scan = "items" },
    { label = "Spawners",  scan = "spawners" },
    { label = "Gimmicks",  scan = "gimmicks" },
    { label = "Meshes",    scan = "components", type_name = "via.render.Mesh" },
    { label = "Animated",  scan = "components", type_name = "via.motion.Motion" },
    { label = "Lights",    scan = "components", type_name = "via.render.Light" },
    { label = "Cameras",   scan = "components", type_name = "via.Camera" },
}

-- Static mesh name pattern
local function is_static_name(name)
    if not name then return false end
    if name:match("^sm%d+_") then return true end
    if name:match("^x%d+.*z%d+") then return true end
    if name == "" or name:match("^StayRequester") or name:match("^Collider_") then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Setup
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab.setup(deps)
    CoreFunctions = deps.CoreFunctions
    ControlPanel = deps.ControlPanel
    ImguiHelpers = deps.ImguiHelpers
    ObjectExplorer = deps.ObjectExplorer
    -- Wire trainer cache if running inside Requiem Trainer
    local T = _G.__REQUIEM_T
    if T then
        _trainer_mgr = T.mgr
        _trainer_ppos = T.ppos
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Build entry helper
-- ═══════════════════════════════════════════════════════════════════════════

local function make_entry(go, extra_name)
    if not go then return nil end
    local name = extra_name or "?"
    if not extra_name then
        pcall(function() name = tostring(go:call("get_Name")) end)
    end

    local px, py, pz, has_pos, dist = 0, 0, 0, false, nil
    pcall(function()
        local xf = go:call("get_Transform")
        if xf then
            local p = xf:call("get_Position")
            if p then
                px, py, pz = p.x, p.y, p.z; has_pos = true
                if state.pp then
                    local dx = px - state.pp.x
                    local dy = py - state.pp.y
                    local dz = pz - state.pp.z
                    dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                end
            end
        end
    end)

    if state.max_distance > 0 and dist and dist > state.max_distance then return nil end

    -- GUID + folder path (same as trainer's extract_go_guid / extract_go_addr)
    local guid = nil
    pcall(function()
        local s = go:call("ToString()")
        if s then guid = tostring(s):match("@([%x%-]+)%]$") end
    end)

    local folder_path = nil
    pcall(function()
        local folder = go:call("get_Folder")
        if folder then
            -- Try ToString() first
            local ts = folder:call("ToString()")
            if ts then
                local p = tostring(ts):match("%[(.+)%]$")
                if p then folder_path = p; return end
            end
            -- Fallback: get_Path + name
            local fpath = folder:call("get_Path")
            if fpath and fpath ~= "" then
                folder_path = fpath .. "/" .. (name or "")
            end
        end
    end)

    -- Component list
    local comp_list = {}
    pcall(function()
        local cnt = go:call("get_ComponentCount") or 0
        for ci = 0, math.min(cnt - 1, 30) do
            pcall(function()
                local c = go:call("getComponent(System.Int32)", ci)
                if c then
                    local td = c:get_type_definition()
                    if td then comp_list[#comp_list + 1] = td:get_full_name() end
                end
            end)
        end
    end)

    return {
        name = name, x = px, y = py, z = pz, has_pos = has_pos,
        dist = dist, gameobj = go, comp_list = comp_list,
        guid = guid, folder_path = folder_path,
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: Enemies (exact same as scan_enemies in requiem_trainer.lua:631)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_enemies()
    local out = {}
    local m = mgr("app.CharacterManager")
    if not m then return out, 0, "CharacterManager not found" end

    -- Also add the player
    pcall(function()
        local pctx = m:call("getPlayerContextRef")
        if not pctx then
            pctx = m:call("get_PlayerContextFast") or m:get_field("<PlayerContextFast>k__BackingField")
        end
        if pctx then
            local go = pctx:call("get_GameObject")
            if go then
                local entry = make_entry(go)
                if entry then
                    entry.name = "[Player] " .. entry.name
                    out[#out + 1] = entry
                end
            end
        end
    end)

    -- Enemies
    local ok, el = pcall(m.call, m, "get_EnemyContextList")
    if not ok or not el then return out, 0, "no enemy list" end
    local ok2, n = pcall(el.call, el, "get_Count")
    if not ok2 or not n or n <= 0 then return out, #out, #out .. " (no enemies)" end

    for i = 0, n - 1 do
        pcall(function()
            local ctx = el:call("get_Item", i)
            if not ctx then return end
            local go = ctx:call("get_GameObject")
            if not go then return end

            local entry = make_entry(go)
            if not entry then return end

            -- Add HP info to name
            pcall(function()
                local hp_obj = ctx:call("get_HitPoint")
                if hp_obj then
                    local cur = hp_obj:call("get_CurrentHitPoint") or 0
                    local mx = hp_obj:call("get_CurrentMaximumHitPoint") or 0
                    local dead = hp_obj:call("get_IsDead")
                    entry.name = entry.name .. string.format(" [HP:%d/%d%s]", cur, mx, dead and " DEAD" or "")
                end
            end)

            out[#out + 1] = entry
        end)
    end

    return out, n, n .. " enemies + player"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: Items (exact same as scan_indicator_items in features.lua:3002)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_items()
    local out = {}
    local im = mgr("app.ItemManager")
    if not im then return out, 0, "ItemManager not found" end

    local list = im:get_field("_ValidateCheckItems")
    if not list then return out, 0, "no _ValidateCheckItems" end

    local ok, count = pcall(list.call, list, "get_Count")
    if not ok or not count or count <= 0 then return out, 0, "0 items" end

    for i = 0, math.min(count - 1, 500) do
        pcall(function()
            local item = list:call("get_Item", i)
            if not item then return end
            local go = item:call("get_GameObject")
            if not go then return end
            local entry = make_entry(go)
            if not entry then return end

            -- Try to get item name from ItemCatalog
            pcall(function()
                local item_id = item:call("get_ItemID")
                if item_id then
                    local catalog = im:get_field("_ItemCatalog")
                    if catalog then
                        local detail = catalog:call("getValue", item_id, nil)
                        if detail then
                            local msg_id = detail:get_field("_NameMessageId")
                            if msg_id then
                                local msg_td = sdk.find_type_definition("via.gui.message")
                                local msg_get = msg_td and msg_td:get_method("get")
                                if msg_get then
                                    local name = msg_get:call(nil, msg_id)
                                    if name then
                                        entry.name = tostring(name):gsub("<[^>]+>", "") .. " (" .. entry.name .. ")"
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            out[#out + 1] = entry
        end)
    end

    return out, count, count .. " items"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: Item Spawners (exact same as features.lua:3164)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_spawners()
    local out = {}
    local scene = CoreFunctions and CoreFunctions.get_scene() or nil
    if not scene then return out, 0, "no scene" end

    local rt = sdk.find_type_definition("app.ItemSpawner")
    if not rt then return out, 0, "ItemSpawner type not found" end

    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", rt:get_runtime_type()) end)
    if not comps then return out, 0, "findComponents nil" end

    local ok, n = pcall(comps.call, comps, "get_Count")
    if not ok or not n or n <= 0 then return out, 0, "0 spawners" end

    for i = 0, math.min(n - 1, 500) do
        pcall(function()
            local sp = comps:call("get_Item", i)
            if not sp then return end
            local go = sp:call("get_GameObject")
            if not go then return end
            local entry = make_entry(go)
            if entry then out[#out + 1] = entry end
        end)
    end

    return out, n, n .. " spawners"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: Gimmicks (exact same as features.lua:3074)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_gimmicks()
    local out = {}
    local gm = mgr("app.GimmickManager")
    if not gm then return out, 0, "GimmickManager not found" end

    local db = gm:get_field("_GimmickCoreDB")
    if not db then return out, 0, "no _GimmickCoreDB" end

    local entries = db:get_field("_entries")
    if not entries then return out, 0, "no entries" end

    local ok, size = pcall(entries.call, entries, "get_size")
    if not ok or not size or size <= 0 then return out, 0, "0 gimmicks" end

    for i = 0, math.min(size - 1, 500) do
        pcall(function()
            local e = entries:call("get_element", i)
            if not e then return end
            local core = e:get_field("value")
            if not core then return end
            local go = core:call("get_GameObject")
            if not go then return end
            local entry = make_entry(go)
            if not entry then return end

            -- Add done status
            pcall(function()
                local done = core:get_field("_IsDone")
                if done then entry.name = entry.name .. " [DONE]" end
            end)

            out[#out + 1] = entry
        end)
    end

    return out, size, size .. " gimmick entries"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: All transforms (GameObjectsDisplay.cpp style)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_all_transforms()
    local out = {}
    local count, skipped = 0, 0

    local first_xf = nil
    pcall(function()
        local scene = CoreFunctions and CoreFunctions.get_scene() or nil
        if scene then first_xf = scene:call("get_FirstTransform") end
    end)
    if not first_xf then return out, 0, "no transforms" end

    local xf = first_xf
    local seen = {}
    while xf and count < 8000 do
        count = count + 1
        pcall(function()
            local go = xf:call("get_GameObject")
            if not go then return end
            local addr = go:get_address()
            if seen[addr] then return end
            seen[addr] = true

            local name = "?"
            pcall(function() name = tostring(go:call("get_Name")) end)

            if state.hide_static and is_static_name(name) then
                skipped = skipped + 1
                return
            end

            local entry = make_entry(go, name)
            if entry then out[#out + 1] = entry end
        end)

        local next_xf = nil
        pcall(function() next_xf = xf:call("get_Next") end)
        xf = next_xf
    end

    return out, count, count .. " transforms (" .. #out .. " shown, " .. skipped .. " static hidden)"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SCAN: By component type (for Meshes, Animated, Lights, Cameras)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_by_component(type_name)
    local out = {}
    local scene = CoreFunctions and CoreFunctions.get_scene() or nil
    if not scene then return out, 0, "no scene" end

    local rt = sdk.find_type_definition(type_name)
    if not rt then return out, 0, "type not found: " .. type_name end

    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", rt:get_runtime_type()) end)
    if not comps then return out, 0, "findComponents nil" end

    local ok, n = pcall(comps.call, comps, "get_Count")
    if not ok or not n or n <= 0 then return out, 0, "0 " .. type_name end

    local seen = {}
    for i = 0, math.min(n - 1, 500) do
        pcall(function()
            local comp = comps:call("get_Item", i)
            if not comp then return end
            local go = comp:call("get_GameObject")
            if not go then return end
            local addr = go:get_address()
            if seen[addr] then return end
            seen[addr] = true
            local entry = make_entry(go)
            if entry then out[#out + 1] = entry end
        end)
    end

    return out, n, n .. " " .. type_name .. " components"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Main scan
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._scan()
    state.pp = ppos()
    local cat = CATEGORIES[state.filter_idx] or CATEGORIES[1]
    local objects, total, info

    if cat.scan == "enemies" then
        objects, total, info = scan_enemies()
    elseif cat.scan == "items" then
        objects, total, info = scan_items()
    elseif cat.scan == "spawners" then
        objects, total, info = scan_spawners()
    elseif cat.scan == "gimmicks" then
        objects, total, info = scan_gimmicks()
    elseif cat.scan == "components" then
        objects, total, info = scan_by_component(cat.type_name)
    else  -- "all"
        objects, total, info = scan_all_transforms()
    end

    state.total = total
    state.scan_info = cat.label .. ": " .. info
    state.objects = objects
    ObjectsTab._apply_search()

    -- Export overlay data to EMV global (read by rendering.lua)
    if _G.EMV then
        _G.EMV._overlay_cfg = { enabled = state.show_overlay }
        if state.show_overlay then
            local overlay = {}
            for _, e in ipairs(objects) do
                if e.has_pos then
                    overlay[#overlay + 1] = {
                        name = e.name, x = e.x, y = e.y, z = e.z, dist = e.dist,
                        guid = e.guid, folder_path = e.folder_path,
                    }
                end
            end
            _G.EMV._overlay_objects = overlay
        else
            _G.EMV._overlay_objects = {}
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Search + Sort
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._apply_search()
    local q = state.search_text ~= "" and state.search_text:lower() or nil
    local out = {}
    for _, e in ipairs(state.objects) do
        if q then
            local found = false
            if e.name and e.name:lower():find(q, 1, true) then found = true end
            if not found then
                for _, cn in ipairs(e.comp_list) do
                    if cn:lower():find(q, 1, true) then found = true; break end
                end
            end
            if not found then goto skip end
        end
        out[#out + 1] = e
        ::skip::
    end
    if state.sort_by_dist then
        table.sort(out, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)
    else
        table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    end
    state.filtered = out
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Tab
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab.render()
    -- Enable toggle (saves CPU/memory when not in use)
    local ec, ev = imgui.checkbox("Enable Objects Browser", state.enabled)
    if ec then
        state.enabled = ev
        if not ev then
            -- Clear data when disabled
            state.objects = {}; state.filtered = {}
            if _G.EMV then _G.EMV._overlay_objects = {}; _G.EMV._overlay_cfg = { enabled = false } end
        end
    end
    if not state.enabled then
        imgui.text_colored("Enable to scan scene objects (uses CPU/memory)", 0xFF888888)
        return
    end

    local now = os.clock()
    if state.needs_rescan or (now - state.last_scan) > state.scan_interval then
        pcall(ObjectsTab._scan)
        state.needs_rescan = false
        state.last_scan = now
    end

    imgui.text(state.scan_info)
    imgui.same_line()
    if imgui.button("Refresh##obj") then state.needs_rescan = true end

    imgui.spacing()
    for i, cat in ipairs(CATEGORIES) do
        if i > 1 then imgui.same_line() end
        local sel = (state.filter_idx == i)
        if sel then imgui.push_style_color(21, 0xFF44FF88) end
        if imgui.button(cat.label .. "##cat" .. i) then
            if state.filter_idx ~= i then
                state.filter_idx = i
                state.needs_rescan = true
            end
        end
        if sel then imgui.pop_style_color(1) end
    end

    local dc, dv = imgui.drag_float("Max Dist##od", state.max_distance, 1.0, 0, 5000)
    if dc then state.max_distance = math.max(0, dv); state.needs_rescan = true end
    imgui.same_line(); imgui.text("(0=all)")

    local sc, st = imgui.input_text("Search##obj_s", state.search_text, 256)
    if sc then state.search_text = st; ObjectsTab._apply_search() end

    local sbc, sbv = imgui.checkbox("Sort by distance", state.sort_by_dist)
    if sbc then state.sort_by_dist = sbv; ObjectsTab._apply_search() end

    if CATEGORIES[state.filter_idx].scan == "all" then
        imgui.same_line()
        local hc, hv = imgui.checkbox("Hide static", state.hide_static)
        if hc then state.hide_static = hv; state.needs_rescan = true end
    end

    -- Overlay toggle
    local oc, ov = imgui.checkbox("3D Overlay", state.show_overlay)
    if oc then
        state.show_overlay = ov
        -- Update immediately
        if _G.EMV then
            _G.EMV._overlay_cfg = { enabled = ov }
            if not ov then _G.EMV._overlay_objects = {} end
        end
        if ov then state.needs_rescan = true end
    end

    imgui.separator()

    local list = state.filtered
    imgui.text("Results: " .. #list)
    imgui.spacing()

    local max_show = 300
    for i = 1, math.min(#list, max_show) do
        if list[i] then pcall(ObjectsTab._draw_entry, list[i], i) end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Entry — full inspector
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._draw_entry(e, idx)
    -- Use memory address as stable ID (survives re-sort)
    local sid = string.format("%X", e.gameobj:get_address())
    local dist_str = e.dist and string.format(" [%.1fm]", e.dist) or ""
    local label = (e.name or "?") .. dist_str .. "##e" .. sid
    if not imgui.tree_node(label) then return end

    -- Use the full Object Explorer if available
    if ObjectExplorer and ObjectExplorer.explore_gameobj then
        local ok, err = pcall(ObjectExplorer.explore_gameobj, e.gameobj, sid)
        if not ok then
            imgui.text_colored("Explorer error: " .. tostring(err), 0xFF4444FF)
        end
    else
        -- Fallback to simple view
        imgui.text_colored("0x" .. sid, 0xFF888888)

        -- GUID + Folder Path
        if e.guid then
            imgui.text("GUID: " .. e.guid)
            imgui.same_line()
            if imgui.button("Copy##guid" .. sid) then pcall(function() imgui.set_clipboard(e.guid) end) end
        end
        if e.folder_path then
            imgui.text("Path: " .. e.folder_path)
            imgui.same_line()
            if imgui.button("Copy##path" .. sid) then pcall(function() imgui.set_clipboard(e.folder_path) end) end
        end

        if e.has_pos then
            imgui.text(string.format("Pos: %.2f, %.2f, %.2f", e.x, e.y, e.z))
        end

        -- GameObject
        if imgui.tree_node("GameObject##go" .. sid) then
            ObjectsTab._draw_go(e.gameobj, sid)
            imgui.tree_pop()
        end

        -- Transform (editable)
        if imgui.tree_node("Transform##xf" .. sid) then
            ObjectsTab._draw_xf(e.gameobj, sid)
            imgui.tree_pop()
        end

        -- Components
        ObjectsTab._draw_comps(e.gameobj, sid)
    end

    imgui.tree_pop()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GameObject props (editable)
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._draw_go(go, idx)
    pcall(function() imgui.text("Type: " .. go:get_type_definition():get_full_name()) end)
    pcall(function()
        local v = go:call("get_UpdateSelf")
        local c, nv = imgui.checkbox("UpdateSelf##gou" .. idx, v)
        if c then pcall(go.call, go, "set_UpdateSelf", nv) end
    end)
    pcall(function()
        local v = go:call("get_DrawSelf")
        local c, nv = imgui.checkbox("DrawSelf##god" .. idx, v)
        if c then pcall(go.call, go, "set_DrawSelf", nv) end
    end)
    pcall(function()
        local v = go:call("get_TimeScale")
        if v then
            local c, nv = imgui.drag_float("TimeScale##gots" .. idx, v, 0.01, 0, 10)
            if c then pcall(go.call, go, "set_TimeScale", nv) end
        end
    end)
    pcall(function() imgui.text("Layer: " .. tostring(go:call("get_Layer"))) end)
    pcall(function() imgui.text("Tag: " .. tostring(go:call("get_Tag"))) end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform (editable position + scale)
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._draw_xf(go, idx)
    pcall(function()
        local xf = go:call("get_Transform")
        if not xf then imgui.text("(none)"); return end
        pcall(function()
            local p = xf:call("get_Position")
            if p then
                local c, nv = imgui.drag_float3("Pos##xfp" .. idx, {p.x, p.y, p.z}, 0.1)
                if c then pcall(xf.call, xf, "set_Position", Vector3f.new(nv[1], nv[2], nv[3])) end
            end
        end)
        pcall(function()
            local s = xf:call("get_LocalScale")
            if s then
                local c, nv = imgui.drag_float3("Scale##xfs" .. idx, {s.x, s.y, s.z}, 0.01)
                if c then pcall(xf.call, xf, "set_LocalScale", Vector3f.new(nv[1], nv[2], nv[3])) end
            end
        end)
        pcall(function()
            local r = xf:call("get_LocalRotation")
            if r then imgui.text(string.format("Rot: %.3f, %.3f, %.3f, %.3f", r.x, r.y, r.z, r.w)) end
        end)
        pcall(function()
            local p = xf:call("get_Parent")
            if p then
                local pgo = p:call("get_GameObject")
                imgui.text("Parent: " .. tostring(pgo and pgo:call("get_Name") or "?"))
            else
                imgui.text("Parent: (root)")
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Components — fields with editing + methods
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._draw_comps(go, idx)
    local cnt = 0
    pcall(function() cnt = go:call("get_ComponentCount") or 0 end)
    if cnt == 0 then return end
    if not imgui.tree_node("Components (" .. cnt .. ")##comps" .. idx) then return end

    for ci = 0, math.min(cnt - 1, 30) do
        pcall(function()
            local comp = go:call("getComponent(System.Int32)", ci)
            if not comp then return end
            local td = comp:get_type_definition()
            if not td then return end

            if imgui.tree_node(td:get_full_name() .. "##c" .. idx .. "_" .. ci) then
                imgui.text_colored("0x" .. string.format("%X", comp:get_address()), 0xFF888888)
                pcall(function()
                    local en = comp:call("get_Enabled")
                    local c, nv = imgui.checkbox("Enabled##ce" .. idx .. "_" .. ci, en)
                    if c then pcall(comp.call, comp, "set_Enabled", nv) end
                end)
                -- Use full recursive inspector if available, otherwise fall back
                if ControlPanel and ControlPanel.managed_object_control_panel then
                    local ok, err = pcall(ControlPanel.managed_object_control_panel, comp, "cp_" .. idx .. "_" .. ci)
                    if not ok then
                        imgui.text_colored("Error: " .. tostring(err), 0xFF4444FF)
                    end
                else
                    ObjectsTab._draw_fields_flat(comp, td, idx .. "_" .. ci)
                    ObjectsTab._draw_methods_flat(td, idx .. "_" .. ci)
                end
                imgui.tree_pop()
            end
        end)
    end
    imgui.tree_pop()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Fallback flat field/method display (used when ControlPanel not available)
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectsTab._draw_fields_flat(obj, td, uid)
    local fields = nil
    pcall(function() fields = td:get_fields() end)
    if not fields or #fields == 0 then return end
    if not imgui.tree_node("Fields (" .. #fields .. ")##fld" .. uid) then return end

    for fi = 1, math.min(#fields, 100) do
        pcall(function()
            local field = fields[fi]
            local fname = field:get_name()
            local ftype = field:get_type()
            local ftname = ftype and ftype:get_full_name() or "?"
            if field:is_static() then
                imgui.text_colored(ftname .. " " .. fname .. " (static)", 0xFF666666)
                return
            end

            local val = nil
            pcall(function() val = obj:get_field(fname) end)

            if type(val) == "boolean" then
                local c, nv = imgui.checkbox(fname .. "##fb" .. uid .. fi, val)
                if c then pcall(obj.set_field, obj, fname, nv) end
                imgui.same_line(); imgui.text_colored(ftname, 0xFF888888)
            elseif type(val) == "number" then
                if ftname:find("Int") or ftname:find("Byte") or ftname:find("UInt") then
                    local c, nv = imgui.drag_int(fname .. "##fi" .. uid .. fi, math.floor(val), 1)
                    if c then pcall(obj.set_field, obj, fname, nv) end
                else
                    local c, nv = imgui.drag_float(fname .. "##ff" .. uid .. fi, val, 0.01)
                    if c then pcall(obj.set_field, obj, fname, nv) end
                end
                imgui.same_line(); imgui.text_colored(ftname, 0xFF888888)
            elseif type(val) == "string" then
                local c, nv = imgui.input_text(fname .. "##fs" .. uid .. fi, val, 256)
                if c then pcall(obj.set_field, obj, fname, nv) end
                imgui.same_line(); imgui.text_colored(ftname, 0xFF888888)
            elseif type(val) == "userdata" then
                local desc = "[obj]"
                pcall(function() desc = "[0x" .. string.format("%X", val:get_address()) .. "]" end)
                pcall(function() local ts = val:call("ToString()"); if ts then desc = tostring(ts) end end)
                imgui.text(ftname .. " " .. fname .. " = " .. desc)
            elseif val == nil then
                imgui.text_colored(ftname .. " " .. fname .. " = nil", 0xFF888888)
            else
                imgui.text(ftname .. " " .. fname .. " = " .. tostring(val))
            end
        end)
    end
    imgui.tree_pop()
end

function ObjectsTab._draw_methods_flat(td, uid)
    local methods = nil
    pcall(function() methods = td:get_methods() end)
    if not methods or #methods == 0 then return end
    if not imgui.tree_node("Methods (" .. #methods .. ")##mtd" .. uid) then return end

    for mi = 1, math.min(#methods, 80) do
        pcall(function()
            local m = methods[mi]
            local mn = m:get_name()
            local rn = "void"
            pcall(function() local r = m:get_return_type(); if r then rn = r:get_full_name() end end)
            local ps = ""
            pcall(function()
                local params = m:get_params()
                if params and #params > 0 then
                    local pp = {}
                    for _, p in ipairs(params) do
                        pcall(function()
                            local pt = p:get_type()
                            pp[#pp+1] = (pt and pt:get_full_name() or "?") .. " " .. (p:get_name() or "")
                        end)
                    end
                    ps = table.concat(pp, ", ")
                end
            end)
            imgui.text_colored(rn .. " " .. mn .. "(" .. ps .. ")", 0xFFAAAADD)
        end)
    end
    imgui.tree_pop()
end

return ObjectsTab
