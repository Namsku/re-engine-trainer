-- .luacheckrc — Static analysis config for Requiem Trainer
-- Run: luacheck Deploy/ --config .luacheckrc

std = "lua54"
max_line_length = 200

-- REFramework globals
globals = {
    "sdk", "imgui", "re", "d2d", "draw", "log", "json",
    "reframework", "Vector3f", "Vector4f", "ValueType",
    "EMV", "_G",
}

read_globals = {
    "os", "io", "math", "string", "table", "debug", "bit",
    "pcall", "type", "pairs", "ipairs", "tostring", "tonumber",
    "setmetatable", "getmetatable", "loadfile", "dofile", "load",
    "error", "require", "select", "unpack", "arg",
    "rawget", "rawset", "next", "assert", "print",
}

-- Ignore unused self in OOP methods
self = false

-- Ignore unused loop variables (common `for i, v` pattern)
unused_args = false

-- Files to exclude
exclude_files = {
    "Deploy/test/mock_reframework.lua",
}
