# RE3R Trainer — Research Notes

## RE3R Namespace: `offline` (not `app`)

| Entity | Type Name |
|--------|-----------|
| Enemy controller | `offline.EnemyController` |
| HP component | `offline.HitPointController` |
| Player manager | `offline.PlayerManager` |
| Item | `offline.gamemastering.Item` |
| Hand-held item | `offline.HandHeldItem` |
| Set item (gimmick) | `offline.gimmick.action.SetItem` |

## HP Fields on `offline.HitPointController`
- Field: `CurrentHitPoint` or method `get_CurrentHitPoint()`
- Field: `HitPointMax` or method `get_HitPointMax()`

## Player Access
```lua
local pm = sdk.get_managed_singleton("offline.PlayerManager")
local player_go = pm:get_field("PlayerObj") or pm:call("get_Player")
-- Fallback:
local om = sdk.get_managed_singleton("app.ObjectManager")
local player_go = om:get_field("PlayerObj") or om:call("get_Player")
```

## GUID Extraction from GameObject
`via.GameObject` RSZ data has NO GUID field (`Name`, `Tag`, `UpdateSelf`, `DrawSelf`, `Timescale` only).
`ToString()` in RE3R returns `"GameObject[name@HEXADDRESS]"` where `@hex` is a **memory address** — changes every session. Do NOT parse this as a GUID.

Correct approach — try the proper API first:
```lua
local ok, g = pcall(go.call, go, "get_GUID()")
if ok and g then
    local ok2, s = pcall(g.call, g, "ToString()")
    -- s will be "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" if the API exists
end
-- If get_GUID() is unsupported (RE3R may not expose it), return nil.
-- Dynamically spawned enemies have no stable scene GUID anyway.
```

## Scene / Camera
```lua
local sm = sdk.get_native_singleton("via.SceneManager")
local sm_td = sdk.find_type_definition("via.SceneManager")
-- Note: uses parentheses in method name!
local scene = sdk.call_native_func(sm, sm_td, "get_CurrentScene()")
```

## World-to-Screen
- `draw` API: `draw.world_to_screen(Vector3f)` → {x, y} — built-in, easy
- D2D: Manual VPM projection required:
  ```lua
  local cam = sdk.get_primary_camera()
  local vpm = cam:call("get_ViewProjectionMatrix")
  -- or: cam:call("get_ViewProjMatrix")
  local v0,v1,v2,v3 = vpm[0],vpm[1],vpm[2],vpm[3]
  local cX = v0.x*wx + v1.x*wy + v2.x*wz + v3.x
  local cY = v0.y*wx + v1.y*wy + v2.y*wz + v3.y
  local cW = v0.w*wx + v1.w*wy + v2.w*wz + v3.w
  if cW > 0.001 then
      sx = (1 + cX/cW) * 0.5 * screen_w
      sy = (1 - cY/cW) * 0.5 * screen_h
  end
  ```

## Color Format
- Both `draw.text` and `d2d.text` use **ARGB** format: `0xAARRGGBB`
- Example: `0xFFFF4444` = full alpha, full red, dim green, dim blue → red
- The RE3R dev trainer has a buggy `argb()` conversion — DO NOT use it

## Game Speed
```lua
sdk.call_native_func(
    sdk.get_native_singleton("via.Application"),
    sdk.find_type_definition("via.Application"),
    "set_GlobalSpeed", speed)
```

## EMV Engine Path (from re3r/ subfolder)
```lua
local emv_path = my_dir .. "../emv_engine/init.lua"
```

## Enemy Types (from RE3 resources file)
- em0000: Zombie
- em1000: Hunter Gamma
- em3000: Zombie Dog
- em3300, em3400, em3500, em3600: Various zombie variants
- em4000: Drain Deimos
- em7000: Unknown
- em9000-em9400: Nemesis (various forms)

## Enemy Manager (Enemy Spawner reference)
```lua
local em = sdk.get_managed_singleton(sdk.game_namespace("EnemyManager"))
-- or: sdk.get_managed_singleton("app.EnemyManager")
local active_list = em:call("get_ActiveEnemyList")
```
Note: `offline.EnemyController` found via `findComponents` is more reliable.

## findComponents Pattern
```lua
local td = sdk.find_type_definition("offline.EnemyController")
local comps = scene:call("findComponents(System.Type)", td:get_runtime_type())
local count = comps:call("get_Count")
for i = 0, count - 1 do
    local c = comps:call("get_Item", i)
    -- ...
end
```
