--[[
    guid_test.lua — Exhaustive GUID/ID hypothesis tester for RE3R
    Drop into reframework/autorun/ alongside the main trainer.

    For each nearby enemy GameObject, tries every known method of
    extracting a stable identifier. Results are shown in an ImGui
    window and written to reframework/guid_test.log.
]]

if reframework:get_game_name() ~= "re3" then return end

local TITLE = "GUID Test — RE3R"
local LOG   = "guid_test.log"
local MAX_ENEMIES = 5      -- test on first N enemies only
local _results  = {}       -- { go_name, tests={label, value} }
local _tick     = 0
local _logged   = false

-- ─── helpers ────────────────────────────────────────────────────────────────

local function try(fn)
    local ok, v = pcall(fn)
    if not ok then return nil, tostring(v) end
    return v, nil
end

local function fmt_val(v)
    if v == nil then return "nil" end
    local t = type(v)
    if t == "string"  then return v end
    if t == "number"  then return tostring(v) end
    if t == "boolean" then return tostring(v) end
    if t == "userdata" then
        -- try ToString() on the value itself
        local ok, s = pcall(v.call, v, "ToString()")
        if ok and s then return "(obj) " .. tostring(s) end
        -- try get_address
        local ok2, addr = pcall(v.get_address, v)
        if ok2 and addr then return string.format("(obj) 0x%X", addr) end
        return "(userdata)"
    end
    return "(" .. t .. ")"
end

local function find_components(type_name)
    local sm  = sdk.get_native_singleton("via.SceneManager")
    local smt = sdk.find_type_definition("via.SceneManager")
    local scene = sdk.call_native_func(sm, smt, "get_CurrentScene()")
    if not scene then return nil, 0 end
    local td    = sdk.find_type_definition(type_name)
    if not td   then return nil, 0 end
    local list  = scene:call("findComponents(System.Type)", td:get_runtime_type())
    if not list then return nil, 0 end
    local n = list:call("get_Count") or 0
    return list, n
end

-- ─── test battery for one GameObject ────────────────────────────────────────

local function run_tests(go, ctx)
    local tests = {}

    local function add(label, fn)
        local v, err = try(fn)
        tests[#tests + 1] = {
            label = label,
            value = v ~= nil and fmt_val(v) or ("ERR: " .. (err or "nil")),
            ok    = v ~= nil,
        }
        return v
    end

    -- ── 1. ToString() extraction (what we had before) ──
    add("ToString() raw", function()
        local s = go:call("ToString()")
        return tostring(s)
    end)
    add("ToString() @-match", function()
        local s = go:call("ToString()")
        return tostring(s):match("@([%x%-]+)%]$")
    end)

    -- ── 2. Proper GUID API candidates ──
    add("go:call get_GUID()", function()
        return go:call("get_GUID()")
    end)
    add("go:call get_Id()", function()
        return go:call("get_Id()")
    end)
    add("go:call get_InstanceID()", function()
        return go:call("get_InstanceID()")
    end)
    add("go:call get_ObjectID()", function()
        return go:call("get_ObjectID()")
    end)

    -- ── 3. Native field reads on go ──
    add("go:get_field _guid",        function() return go:get_field("_guid") end)
    add("go:get_field _id",          function() return go:get_field("_id") end)
    add("go:get_field _ID",          function() return go:get_field("_ID") end)
    add("go:get_field GUID",         function() return go:get_field("GUID") end)
    add("go:get_field Guid",         function() return go:get_field("Guid") end)
    add("go:get_field ObjectID",     function() return go:get_field("ObjectID") end)

    -- ── 4. Transform-based IDs ──
    add("xf:call get_GUID()", function()
        local xf = go:call("get_Transform")
        if not xf then return nil end
        return xf:call("get_GUID()")
    end)
    add("xf:call get_Id()", function()
        local xf = go:call("get_Transform")
        if not xf then return nil end
        return xf:call("get_Id()")
    end)
    add("xf:get_field _guid", function()
        local xf = go:call("get_Transform")
        if not xf then return nil end
        return xf:get_field("_guid")
    end)

    -- ── 5. Folder path (stable across sessions if scene objects) ──
    add("go Folder path", function()
        local folder = go:call("get_Folder")
        if not folder then return nil end
        local ts = folder:call("ToString()")
        if ts then
            local p = tostring(ts):match("%[(.+)%]$")
            if p then return p end
        end
        return folder:call("get_Path")
    end)

    -- ── 6. EnemyController fields ──
    if ctx then
        -- NowhereSafe.lua confirms RE3R enemy GUID lives here: ctx.GUID
        add("ctx:get_field GUID",            function() return ctx:get_field("GUID") end)
        add("ctx:get_field _EnemyID",       function() return ctx:get_field("_EnemyID") end)
        add("ctx:get_field _SpawnID",        function() return ctx:get_field("_SpawnID") end)
        add("ctx:get_field EnemyID",         function() return ctx:get_field("EnemyID") end)
        add("ctx:get_field SpawnID",         function() return ctx:get_field("SpawnID") end)
        add("ctx:get_field _uniqueID",       function() return ctx:get_field("_uniqueID") end)
        add("ctx:get_field UniqueID",        function() return ctx:get_field("UniqueID") end)
        add("ctx:get_field _requestID",      function() return ctx:get_field("_requestID") end)
        add("ctx:call get_EnemyID()",        function() return ctx:call("get_EnemyID()") end)
        add("ctx:call get_SpawnID()",        function() return ctx:call("get_SpawnID()") end)

        -- Dump ALL field names on EnemyController (first time only)
        add("ctx type name", function()
            local td = ctx:get_type_definition()
            return td and td:get_full_name() or nil
        end)
    end

    -- ── 7. Component scan for any GUID-like field ──
    add("component field scan", function()
        local found = {}
        local count = go:call("get_ComponentCount") or 0
        for ci = 0, math.min(count - 1, 10) do
            pcall(function()
                local comp = go:call("getComponent(System.Int32)", ci)
                if not comp then return end
                local td = comp:get_type_definition()
                if not td then return end
                local fields = td:get_fields()
                if not fields then return end
                for _, f in ipairs(fields) do
                    local fname = f:get_name() or ""
                    local fl = fname:lower()
                    if fl:find("guid") or fl:find("_id") or fl == "id" then
                        local ok, v = pcall(comp.get_field, comp, fname)
                        if ok and v ~= nil then
                            found[#found + 1] = td:get_name() .. "." .. fname .. "=" .. fmt_val(v)
                        end
                    end
                end
            end)
        end
        if #found == 0 then return nil end
        return table.concat(found, " | ")
    end)

    -- ── 8. Via.GameObject method dump (first GO only, expensive) ──
    add("go methods containing ID/GUID", function()
        local td = sdk.find_type_definition("via.GameObject")
        if not td then return nil end
        local methods = td:get_methods()
        if not methods then return nil end
        local found = {}
        for _, m in ipairs(methods) do
            local mn = m:get_name() or ""
            local ml = mn:lower()
            if ml:find("guid") or ml:find("get_id") or ml:find("objectid") or ml:find("instanceid") then
                found[#found + 1] = mn
            end
        end
        if #found == 0 then return nil end
        return table.concat(found, ", ")
    end)

    return tests
end

-- ─── scanner ────────────────────────────────────────────────────────────────

local function run_scan()
    _results = {}
    local list, n = find_components("offline.EnemyController")
    if not list or n == 0 then
        _results[1] = { go_name = "(no EnemyController found)", tests = {} }
        return
    end
    local done = 0
    for i = 0, n - 1 do
        if done >= MAX_ENEMIES then break end
        pcall(function()
            local ctx = list:call("get_Item", i)
            if not ctx then return end
            local go  = ctx:call("get_GameObject")
            if not go then return end
            local go_name = ""
            pcall(function() go_name = tostring(go:call("get_Name") or "") end)
            local tests = run_tests(go, ctx)
            done = done + 1
            _results[#_results + 1] = {
                go_name = go_name .. " [" .. i .. "]",
                tests   = tests,
                addr    = string.format("0x%X", go:get_address()),
            }
        end)
    end
    if done == 0 then
        _results[1] = { go_name = "(EnemyController list exists but no valid GOs)", tests = {} }
    end
end

-- ─── log writer ─────────────────────────────────────────────────────────────

local function write_log()
    local lines = { "=== GUID TEST — RE3R ===" }
    for _, r in ipairs(_results) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "GO: " .. r.go_name .. "  addr=" .. (r.addr or "?")
        for _, t in ipairs(r.tests) do
            local mark = t.ok and "[OK ]" or "[ERR]"
            lines[#lines + 1] = string.format("  %s %-40s %s", mark, t.label, t.value)
        end
    end
    local f = io.open("reframework/" .. LOG, "w")
    if f then
        f:write(table.concat(lines, "\n"))
        f:close()
    end
    _logged = true
end

-- ─── ImGui ──────────────────────────────────────────────────────────────────

re.on_draw_ui(function()
    if not imgui.tree_node(TITLE) then return end

    if imgui.button("Run Scan") then
        _logged = false
        pcall(run_scan)
    end
    imgui.same_line()
    if imgui.button("Write Log") then
        pcall(write_log)
    end
    if _logged then
        imgui.same_line()
        imgui.text_colored("Saved → reframework/" .. LOG, 0xFF88FF88)
    end

    imgui.separator()

    for ri, r in ipairs(_results) do
        local hdr = r.go_name .. "  (" .. (r.addr or "?") .. ")"
        if imgui.tree_node(hdr) then
            for _, t in ipairs(r.tests) do
                local col = t.ok and 0xFF88FF88 or 0xFF666666
                imgui.text_colored(string.format("[%-40s]", t.label), col)
                imgui.same_line()
                if t.ok then
                    imgui.text_colored(t.value, 0xFFFFFFFF)
                    imgui.same_line()
                    if imgui.small_button("C##" .. ri .. t.label) then
                        imgui.set_clipboard_text(t.value)
                    end
                else
                    imgui.text_colored(t.value, 0xFF555555)
                end
            end
            imgui.tree_pop()
        end
    end

    imgui.tree_pop()
end)

-- auto-scan once 3 seconds after load (enemies need time to appear)
re.on_frame(function()
    _tick = _tick + 1
    if _tick == 180 then  -- ~3 seconds at 60fps
        pcall(run_scan)
    end
end)
