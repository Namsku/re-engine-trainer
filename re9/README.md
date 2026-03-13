# Requiem Trainer — RE9 (Resident Evil 9)

**REFramework Lua Trainer for Resident Evil 9**

## Installation

1. Install [REFramework](https://github.com/praydog/REFramework-nightly/releases) for RE9
2. Copy `requiem_trainer.lua` and the `requiem_trainer/` folder into:
   ```
   RE9/reframework/autorun/
   ```
3. Launch the game — press **Insert** to toggle the trainer

## Folder Structure

```
reframework/autorun/
├── requiem_trainer.lua            ← Main entry point
└── requiem_trainer/
    ├── hooks.lua                  ← SDK hook installations
    ├── features.lua               ← Core feature logic
    ├── ui.lua                     ← ImGui tab UI
    ├── rendering.lua              ← D2D overlay rendering
    ├── gravity_gun.lua            ← Gravity Gun module
    ├── features/                  ← Feature modules
    │   ├── chapters.lua
    │   ├── costumes.lua
    │   ├── difficulty.lua
    │   ├── item_indicator.lua
    │   └── noclip.lua
    └── emv_engine/                ← EMV Engine (runtime framework)
        ├── init.lua
        ├── object_explorer.lua
        ├── objects_tab.lua
        ├── type_db.lua
        ├── rsz_types.lua          ← RSZ type database (generated)
        ├── rsz_enums.lua          ← Enum database (generated)
        └── ... (core modules)
```

## Features

- **Player**: God Mode, HP Lock, Noclip, Speed, FOV
- **Combat**: One-Hit Kill, Infinite Ammo/Grenades, No Recoil/Reload, Rapid Fire, Auto Parry
- **Enemies**: ESP, Speed control, Motion Freeze, Stealth, Damage Tracking
- **Inventory**: Weapon modification, Free Craft, Unlock Recipes
- **Items**: 3D Item ESP with category colors, distance labels
- **World**: Game Speed, Skip Cutscenes, Costume Override, Difficulty Override
- **Saves**: Unlimited Saves, Remote Storage
- **Dev Tools**: Object Explorer (RSZ type-aware), Spawn Points, Position Save/Warp
- **Overlay (D2D)**: Enemy Panel, ESP, Damage Numbers, HUD Strip, Toast Notifications

## Default Hotkeys

| Key | Action |
|---|---|
| Insert | Toggle Trainer UI |
| F1 | God Mode |
| F2 | One-Hit Kill |
| F3 | Infinite Ammo |
| F5 | Noclip |
| F6 | Game Speed |

## Requirements

- [REFramework](https://github.com/praydog/REFramework-nightly/releases) (latest nightly)
- Resident Evil 9 (Steam)
