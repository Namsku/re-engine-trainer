-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Item Indicator Sub-Module
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast = T.mgr, T.toast
local dist3 = T.dist3
local ppos = T.ppos
local get_scene = T.get_scene
local _message_td = sdk.find_type_definition("via.gui.message")
local _message_get = _message_td and _message_td:get_method("get")
local _item_category_td = sdk.find_type_definition("app.ItemCategory")

-- Build item category map once
local _item_category_map = {}
pcall(function()
    if _item_category_td then
        local fields = _item_category_td:get_fields()
        for _, f in ipairs(fields) do
            if f:is_static() and f:get_type() == _item_category_td then
                local val = f:get_data(nil)
                _item_category_map[val] = f:get_name()
            end
        end
    end
end)

-- Cache app.ItemSpawner type for GUID lookup
local _item_spawner_type = nil
pcall(function()
    _item_spawner_type = sdk.typeof("app.ItemSpawner")
end)

-- Remove markup tags from item names
local function remove_str_tag(text)
    if not text then return "" end
    return text:gsub("<[^>]+>", "")
end

-- Get item detail (cached)
local function get_item_detail(item_id)
    if R.item_detail_cache[item_id] then
        return R.item_detail_cache[item_id]
    end
    local data = nil
    pcall(function()
        local im = mgr("app.ItemManager")
        if not im then return end
        local catalog = im:get_field("_ItemCatalog")
        if not catalog then return end
        local detail = catalog:call("getValue", item_id, nil)
        if not detail then return end
        local msg_id = detail:get_field("_NameMessageId")
        local name = _message_get and _message_get:call(nil, msg_id) or nil
        local cat_val = detail:get_field("_ItemCategory")
        data = {
            name = name and remove_str_tag(tostring(name)) or ("Item#" .. tostring(item_id)),
            category = _item_category_map[cat_val] or "Unknown",
            is_key = (_item_category_map[cat_val] == "KeyItem"),
        }
    end)
    if data then R.item_detail_cache[item_id] = data end
    return data
end

-- Check if item is inside a gimmick (hidden container)
local function is_item_in_gimmick(go)
    if not go then return false end
    local result = false
    pcall(function()
        local xf = go:call("get_Transform")
        if not xf then return end
        local parent = xf:call("get_Parent")
        if not parent then return end
        local pgo = parent:call("get_GameObject")
        if not pgo then return end
        local pname = pgo:call("get_Name")
        if pname and type(pname) == "string" and pname:sub(1, 5) == "sm81_" then
            result = true
        end
    end)
    return result
end

-- Scan normal items from ItemManager
local function scan_indicator_items()
    if not C.show_items then return end
    local now = os.clock()
    if now - R.item_last_scan < C.item_scan_interval then return end
    R.item_last_scan = now

    local pp = ppos()
    if not pp then return end

    -- Scan normal items
    pcall(function()
        local im = mgr("app.ItemManager")
        if not im then return end
        local list = im:get_field("_ValidateCheckItems")
        if not list then return end
        local ok, count = pcall(list.call, list, "get_Count")
        if not ok or not count or count <= 0 then return end
        for i = 0, math.min(count - 1, 200) do
            pcall(function()
                local item = list:call("get_Item", i)
                if not item then return end
                local ok2, setupped = pcall(item.call, item, "get_Setupped")
                if not ok2 or not setupped then return end
                local go = item:call("get_GameObject")
                if not go then return end
                local is_draw = go:call("get_Draw")
                if not is_draw or is_item_in_gimmick(go) then return end
                local xf = go:call("get_Transform")
                if not xf then return end
                local pos = xf:call("get_Position")
                if not pos then return end
                local dist = dist3(pos, pp)
                if dist > C.item_distance then return end
                local ok3, item_id = pcall(item.call, item, "get_ItemID")
                if not ok3 then return end
                local detail = get_item_detail(item_id)
                if not detail then return end
                local addr = item:get_address()
                -- Extract path, address, and GO name
                local go_guid = nil
                local go_addr = nil
                local go_name = nil
                pcall(function()
                    if T.extract_go_guid then go_guid = T.extract_go_guid(go) end
                    if T.extract_go_addr then go_addr = T.extract_go_addr(go) end
                    go_name = go:call("get_Name")
                    if go_name then go_name = tostring(go_name) end
                end)
                -- Filter by source type
                if not C.show_item_core then return end
                -- Height arrow
                local suffix = ""
                if pos.y > pp.y + 4 then suffix = " ↑"
                elseif pos.y < pp.y - 4 then suffix = " ↓" end
                R.item_indicators[addr] = {
                    name = detail.name,
                    pos = pos,
                    category = detail.category,
                    is_key = detail.is_key,
                    dist = dist,
                    suffix = suffix,
                    update_time = now,
                    guid = go_guid,
                    source = "core",
                    go_addr = go_addr,
                    go_name = go_name,
                }
            end)
        end
    end)

    -- Scan gimmick items (boxes, barrels, raccoons)
    if C.show_box_items or C.show_raccoon then
        pcall(function()
            local gm = mgr("app.GimmickManager")
            if not gm then return end
            local db = gm:get_field("_GimmickCoreDB")
            if not db then return end
            local entries = db:get_field("_entries")
            if not entries then return end
            local ok, size = pcall(entries.call, entries, "get_size")
            if not ok or not size or size <= 0 then return end
            local GimmickLabels = { Gm17="Box", Gm16="Barrel", Gm15="Jar", Gm18="Box", Gm19="Cabinet" }
            for i = 0, math.min(size - 1, 1000) do
                pcall(function()
                    local entry = entries:call("get_element", i)
                    if not entry then return end
                    local core = entry:get_field("value")
                    if not core then return end
                    local is_done = core:get_field("_IsDone")
                    if is_done then return end
                    local go = core:call("get_GameObject")
                    if not go then return end
                    local xf = go:call("get_Transform")
                    if not xf then return end
                    local pos = xf:call("get_Position")
                    if not pos then return end
                    local dist = dist3(pos, pp)
                    if dist > C.item_distance then return end
                    local bases = core:get_field("_GmBases")
                    if not bases then return end
                    local ok2, blen = pcall(bases.call, bases, "get_size")
                    if not ok2 or not blen then return end
                    local has_drop, dropped, is_raccoon = false, false, false
                    for j = 0, math.min(blen - 1, 10) do
                        pcall(function()
                            local base = bases:call("get_element", j)
                            if not base then return end
                            local btype = base:get_type_definition()
                            if not btype then return end
                            local bname = btype:get_full_name()
                            if bname == "app.GmItemDrop" then
                                has_drop = true
                                dropped = (true == base:get_field("_IsItemDrop"))
                            elseif bname == "app.GmMultipleItemDrop" then
                                has_drop = true
                            elseif bname == "app.GmFragileSymbol" then
                                is_raccoon = true
                            end
                        end)
                    end
                    local addr = core:get_address()
                    local suffix = ""
                    if pos.y > pp.y + 4 then suffix = " ↑"
                    elseif pos.y < pp.y - 4 then suffix = " ↓" end
                    -- Extract path, address, and GO name for gimmick objects
                    local gm_guid = nil
                    local gm_addr = nil
                    local gm_go_name = nil
                    pcall(function()
                        if T.extract_go_guid then gm_guid = T.extract_go_guid(go) end
                        if T.extract_go_addr then gm_addr = T.extract_go_addr(go) end
                        gm_go_name = go:call("get_Name")
                        if gm_go_name then gm_go_name = tostring(gm_go_name) end
                    end)
                    if is_raccoon and C.show_raccoon then
                        R.item_indicators[addr] = {
                            name = "Mr. Raccoon",
                            pos = pos, category = "Raccoon",
                            dist = dist, suffix = suffix, update_time = now,
                            guid = gm_guid, go_addr = gm_addr, go_name = gm_go_name,
                        }
                    elseif has_drop and not dropped and C.show_box_items then
                        local obj_name = gm_go_name or ""
                        local prefix = type(obj_name) == "string" and obj_name:sub(1, 4) or ""
                        local label = GimmickLabels[prefix]
                        if label then
                            R.item_indicators[addr] = {
                                name = label,
                                pos = pos, category = "Box",
                                dist = dist, suffix = suffix, update_time = now,
                                guid = gm_guid, go_addr = gm_addr, go_name = gm_go_name,
                            }
                        end
                    end
                end)
            end
        end)
    end

    -- Scan app.ItemSpawner components directly from the scene
    if C.show_item_spawner and _item_spawner_type then
        pcall(function()
            local scene = get_scene()
            if not scene then return end
            local rt = sdk.find_type_definition("app.ItemSpawner")
            if not rt then return end
            local comps = scene:call("findComponents(System.Type)", rt:get_runtime_type())
            if not comps then return end
            local ok_c, comp_count = pcall(comps.call, comps, "get_Count")
            if not ok_c or not comp_count or comp_count <= 0 then return end
            for i = 0, math.min(comp_count - 1, 500) do
                pcall(function()
                    local spawner = comps:call("get_Item", i)
                    if not spawner then return end
                    local go = spawner:call("get_GameObject")
                    if not go then return end
                    local xf = go:call("get_Transform")
                    if not xf then return end
                    local pos = xf:call("get_Position")
                    if not pos then return end
                    local dist = dist3(pos, pp)
                    if dist > C.item_distance then return end
                    local sp_guid = nil
                    local sp_addr = nil
                    local sp_name = nil
                    pcall(function()
                        if T.extract_go_guid then sp_guid = T.extract_go_guid(go) end
                        if T.extract_go_addr then sp_addr = T.extract_go_addr(go) end
                        sp_name = go:call("get_Name")
                        if sp_name then sp_name = tostring(sp_name) end
                    end)
                    local suffix = ""
                    if pos.y > pp.y + 4 then suffix = " ↑"
                    elseif pos.y < pp.y - 4 then suffix = " ↓" end
                    local addr = spawner:get_address()
                    R.item_indicators[addr] = {
                        name = sp_name or "ItemSpawner",
                        pos = pos,
                        category = "Spawner",
                        is_key = false,
                        dist = dist,
                        suffix = suffix,
                        update_time = now,
                        guid = sp_guid,
                        source = "spawner",
                        go_addr = sp_addr,
                        go_name = sp_name,
                    }
                end)
            end
        end)
    end

    -- Merge pass: when an ItemCore and ItemSpawner overlap at the same position,
    -- keep one entry with the item's name + spawner's GUID (remove the duplicate)
    local spawners = {}
    local cores = {}
    for addr, itm in pairs(R.item_indicators) do
        if itm.source == "spawner" then
            spawners[#spawners + 1] = { addr = addr, itm = itm }
        elseif itm.source == "core" then
            cores[#cores + 1] = { addr = addr, itm = itm }
        end
    end
    for _, sp in ipairs(spawners) do
        for _, co in ipairs(cores) do
            if sp.itm.pos and co.itm.pos then
                local dx = sp.itm.pos.x - co.itm.pos.x
                local dy = sp.itm.pos.y - co.itm.pos.y
                local dz = sp.itm.pos.z - co.itm.pos.z
                local d2 = dx*dx + dy*dy + dz*dz
                if d2 < 4.0 then  -- within 2m
                    -- Merge: keep core entry with spawner's GUID
                    co.itm.guid = sp.itm.guid or co.itm.guid
                    co.itm.source = "spawner"
                    co.itm.category = co.itm.category  -- keep original category
                    -- Remove the spawner duplicate
                    R.item_indicators[sp.addr] = nil
                    break
                end
            end
        end
    end

    -- Prune stale entries
    for addr, itm in pairs(R.item_indicators) do
        if now - itm.update_time > C.item_scan_interval + 1.0 then
            R.item_indicators[addr] = nil
        end
    end
end

-- Exports
T.scan_indicator_items = scan_indicator_items

log.info("[Trainer] Item Indicator sub-module loaded")
