--[[
    object_cache.lua — Managed Object Cache with TTL Eviction
    EMV Engine Module (Phase 1)

    Caches managed objects with add_ref/release lifecycle management,
    TTL-based expiration, and LRU capacity limit.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
]]

local ObjectCache = {}
ObjectCache.__index = ObjectCache

--- Create a new ObjectCache.
--- @param args table  {name, max_size, default_ttl}
--- @return ObjectCache
function ObjectCache:new(args)
    args = args or {}
    local o = setmetatable({}, ObjectCache)
    o.name        = args.name or "cache"
    o.max_size    = args.max_size or 500
    o.default_ttl = args.default_ttl or 30
    o.entries     = {}    -- key → {value, expires_at, last_access}
    o.size        = 0
    o.stats       = {hits = 0, misses = 0, evictions = 0}
    return o
end

--- Store an object in the cache.
--- @param key any         Cache key (usually the managed object itself)
--- @param value any       Value to cache
--- @param ttl number|nil  TTL in seconds (default: self.default_ttl)
function ObjectCache:set(key, value, ttl)
    if key == nil then return end

    -- If already cached, just update
    if self.entries[key] then
        self.entries[key].value       = value
        self.entries[key].expires_at  = os.clock() + (ttl or self.default_ttl)
        self.entries[key].last_access = os.clock()
        return
    end

    -- Evict LRU if at capacity
    if self.size >= self.max_size then
        self:_evict_lru()
    end

    -- add_ref if it's a managed object
    if type(value) == "userdata" then
        pcall(function()
            if sdk.is_managed_object(value) then
                value:add_ref()
            end
        end)
    end

    self.entries[key] = {
        value       = value,
        expires_at  = os.clock() + (ttl or self.default_ttl),
        last_access = os.clock(),
    }
    self.size = self.size + 1
end

--- Retrieve an object from the cache.
--- @param key any  Cache key
--- @return any|nil  Cached value, or nil if not found / expired
function ObjectCache:get(key)
    local entry = self.entries[key]
    if not entry then
        self.stats.misses = self.stats.misses + 1
        return nil
    end

    -- Check expiration
    if os.clock() > entry.expires_at then
        self:remove(key)
        self.stats.misses = self.stats.misses + 1
        return nil
    end

    -- Check validity (managed object may have been collected)
    if type(entry.value) == "userdata" then
        local valid = false
        pcall(function() valid = sdk.is_managed_object(entry.value) end)
        if not valid then
            self:remove(key)
            self.stats.misses = self.stats.misses + 1
            return nil
        end
    end

    entry.last_access = os.clock()
    self.stats.hits = self.stats.hits + 1
    return entry.value
end

--- Remove an entry, releasing the managed object ref.
--- @param key any  Cache key
function ObjectCache:remove(key)
    local entry = self.entries[key]
    if not entry then return end

    -- release if managed
    if type(entry.value) == "userdata" then
        pcall(function()
            if sdk.is_managed_object(entry.value) then
                entry.value:release()
            end
        end)
    end

    self.entries[key] = nil
    self.size = self.size - 1
end

--- Per-frame sweep: remove expired and invalid entries.
function ObjectCache:sweep()
    local now = os.clock()
    local to_remove = {}

    for key, entry in pairs(self.entries) do
        local should_remove = false

        -- TTL expired
        if now > entry.expires_at then
            should_remove = true
        end

        -- Managed object no longer valid
        if not should_remove and type(entry.value) == "userdata" then
            local valid = false
            pcall(function() valid = sdk.is_managed_object(entry.value) end)
            if not valid then should_remove = true end
        end

        if should_remove then
            to_remove[#to_remove + 1] = key
        end
    end

    for _, key in ipairs(to_remove) do
        self:remove(key)
        self.stats.evictions = self.stats.evictions + 1
    end
end

--- Clear all entries.
function ObjectCache:clear()
    for key, _ in pairs(self.entries) do
        self:remove(key)
    end
    self.entries = {}
    self.size = 0
end

--- Evict the least recently accessed entry.
function ObjectCache:_evict_lru()
    local oldest_key = nil
    local oldest_time = math.huge

    for key, entry in pairs(self.entries) do
        if entry.last_access < oldest_time then
            oldest_time = entry.last_access
            oldest_key = key
        end
    end

    if oldest_key then
        self:remove(oldest_key)
        self.stats.evictions = self.stats.evictions + 1
    end
end

return ObjectCache
