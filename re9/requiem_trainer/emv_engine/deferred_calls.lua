--[[
    deferred_calls.lua — Deferred Call System
    EMV Engine Module (Phase 2)

    Queue system for executing calls on the next frame or on a schedule.
    Supports methods, fields, Lua functions, and freeze/unfreeze.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
    Reimplemented with modular architecture.
]]

local DeferredCalls = {}

-- Module references
local CoreFunctions = nil

function DeferredCalls.setup(deps)
    CoreFunctions = deps.CoreFunctions
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Queues
-- ═══════════════════════════════════════════════════════════════════════════

local deferred_queue = {}
local on_frame_queue = {}
local frozen_calls = {}

--- Queue a deferred call for next processing cycle.
function DeferredCalls.queue(call_data)
    deferred_queue[#deferred_queue + 1] = call_data
end

--- Queue an on-frame call (executed every frame).
function DeferredCalls.queue_on_frame(call_data)
    on_frame_queue[#on_frame_queue + 1] = call_data
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Core Call Executor
-- ═══════════════════════════════════════════════════════════════════════════

--- Execute a deferred call.
--- @param obj userdata      Target object (can be nil for global calls)
--- @param method string     Method name, field name, or "lua_func"
--- @param args table        Arguments: {func, field, value, args, freeze}
function DeferredCalls.deferred_call(obj, method, args)
    args = args or {}

    pcall(function()
        if args.func and type(args.func) == "function" then
            -- Lua function call
            args.func(obj, args)

        elseif args.field then
            -- Field set
            if obj and sdk.is_managed_object(obj) then
                obj:set_field(args.field, args.value)
            end

        elseif method and obj then
            -- Method call
            if sdk.is_managed_object(obj) then
                if args.args then
                    obj:call(method, table.unpack(args.args))
                else
                    obj:call(method)
                end
            end
        end
    end)

    -- Freeze: re-queue for next frame
    if args.freeze then
        local freeze_key = tostring(obj) .. "::" .. tostring(method or args.field or "func")
        frozen_calls[freeze_key] = {
            obj = obj,
            method = method,
            args = args,
        }
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Processing (called from hooks)
-- ═══════════════════════════════════════════════════════════════════════════

--- Process all queued deferred calls (called from re.on_frame or UpdateMotion hook).
function DeferredCalls.process_deferred_calls()
    local queue = deferred_queue
    deferred_queue = {}

    for _, call in ipairs(queue) do
        pcall(function()
            DeferredCalls.deferred_call(call.obj, call.method, call)
        end)
    end

    -- Process frozen calls
    for key, call in pairs(frozen_calls) do
        if call.obj and sdk.is_managed_object(call.obj) then
            pcall(function()
                DeferredCalls.deferred_call(call.obj, call.method, call.args)
            end)
        else
            frozen_calls[key] = nil
        end
    end
end

--- Process on-frame calls (lightweight, every frame).
function DeferredCalls.process_on_frame_calls()
    for _, call in ipairs(on_frame_queue) do
        pcall(function()
            if call.func then
                call.func(call.args)
            elseif call.obj and call.method then
                call.obj:call(call.method)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Freeze / Unfreeze
-- ═══════════════════════════════════════════════════════════════════════════

function DeferredCalls.unfreeze(obj, method_or_field)
    local key = tostring(obj) .. "::" .. tostring(method_or_field or "")
    frozen_calls[key] = nil
end

function DeferredCalls.unfreeze_all()
    frozen_calls = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

function DeferredCalls.clear()
    deferred_queue = {}
    on_frame_queue = {}
    frozen_calls = {}
end

return DeferredCalls
