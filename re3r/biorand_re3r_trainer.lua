--[[
    Biorand RE3R Trainer v3.0
    by namsku / Biorand

    Features
    ────────
    • D2D overlay: enemy ESP (world-space), item ESP, dev info panel (top-left)
    • D2D panels (top-right): Enemy Spawn overlay, LevelFlow overlay
    • ImGui window: Enemies / Spawn Groups / Scenarios / Items / Settings tabs
    • B key: append spawn points to reframework/data/enemy.csv
    • N key: append item spawn points to reframework/data/item.csv

    Placement (REFramework autorun):
      reframework/autorun/biorand_re3r_trainer.lua
]]

if reframework:get_game_name() ~= "re3" then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- MapID Enum — offline.gamemastering.Map.ID
-- ═══════════════════════════════════════════════════════════════════════════

local MAP_ID_NAMES = {
    [0]="Invalid",
    [1]="st00_0101_0",[2]="st00_0102_0",[3]="st00_0201_0",[4]="st00_0202_0",
    [5]="st00_0203_0",[6]="st00_0204_0",[7]="st00_0205_0",[8]="st00_0206_0",
    [9]="st00_0207_0",[10]="st00_0208_0",[11]="st00_0209_0",
    [12]="st01_0101_0",[13]="st01_0102_0",[14]="st01_0103_0",[15]="st01_0104_0",
    [16]="st01_0201_0",[17]="st01_0202_0",[18]="st01_0301_0",[19]="st01_0302_0",
    [20]="st01_0303_0",[21]="st01_0304_0",[22]="st01_0305_0",[23]="st01_0306_0",
    [24]="st01_0307_0",[25]="st01_0308_0",[26]="st01_0401_0",[27]="st01_0501_0",
    [28]="st01_0502_0",[29]="st01_0601_0",
    [30]="st02_0101_0",[31]="st02_0102_0",[32]="st02_0103_0",[33]="st02_0104_0",
    [34]="st02_0105_0",[35]="st02_0106_0",[36]="st02_0201_0",[37]="st02_0202_0",
    [38]="st02_0203_0",[39]="st02_0204_0",[40]="st02_0205_0",[41]="st02_0206_0",
    [42]="st02_0207_0",[43]="st02_0208_0",[44]="st02_0209_0",[45]="st02_0210_0",
    [46]="st02_0211_0",[47]="st02_0212_0",[48]="st02_0213_0",[49]="st02_0214_0",
    [50]="st02_0215_0",[51]="st02_0216_0",[52]="st02_0217_0",
    [53]="st02_0301_0",[54]="st02_0302_0",[55]="st02_0303_0",[56]="st02_0304_0",
    [57]="st02_0305_0",[58]="st02_0306_0",[59]="st02_0307_0",[60]="st02_0308_0",
    [61]="st02_0309_0",[62]="st02_0310_0",[63]="st02_0311_0",[64]="st02_0312_0",
    [65]="st02_0313_0",[66]="st02_0314_0",
    [67]="st02_0401_0",[68]="st02_0401_1",[69]="st02_0402_0",[70]="st02_0403_0",
    [71]="st02_0404_0",[72]="st02_0405_0",[73]="st02_0406_0",[74]="st02_0407_0",
    [75]="st02_0408_0",[76]="st02_0409_0",[77]="st02_0410_0",[78]="st02_0411_0",
    [79]="st02_0412_0",
    [80]="st02_0501_0",[81]="st02_0502_0",[82]="st02_0503_0",[83]="st02_0504_0",
    [84]="st02_0505_0",[85]="st02_0506_0",[86]="st02_0507_0",[87]="st02_0508_0",
    [88]="st02_0601_0",[89]="st02_0602_0",[90]="st02_0603_0",[91]="st02_0604_0",
    [92]="st02_0605_0",[93]="st02_0606_0",[94]="st02_0607_0",[95]="st02_0608_0",
    [96]="st02_0609_0",[97]="st02_0610_0",
    [98]="st02_0650_0",
    [99]="st02_0701_0",[100]="st02_0702_0",[101]="st02_0703_0",[102]="st02_0704_0",
    [103]="st02_0705_0",[104]="st02_0708_0",[105]="st02_0709_0",[106]="st02_0710_0",
    [107]="st02_0711_0",[108]="st02_0712_0",[109]="st02_0713_0",[110]="st02_0714_0",
    [111]="st02_0715_0",[112]="st02_0716_0",[113]="st02_0717_0",
    [114]="st02_0750_0",[115]="st02_0751_0",[116]="st02_0752_0",[117]="st02_0753_0",
    [118]="st02_0754_0",[119]="st02_0755_0",
    [120]="st02_0800_0",
    [121]="st02_0509_0",
    [122]="st03_0101_0",[123]="st03_0102_0",[124]="st03_0103_0",[125]="st03_0104_0",
    [126]="st03_0105_0",[127]="st03_0106_0",[128]="st03_0107_0",[129]="st03_0108_0",
    [130]="st03_0151_0",[131]="st03_0152_0",[132]="st03_0153_0",[133]="st03_0154_0",
    [134]="st03_0201_0",[135]="st03_0202_0",[136]="st03_0203_0",[137]="st03_0204_0",
    [138]="st03_0205_0",[139]="st03_0206_0",[140]="st03_0207_0",[141]="st03_0208_0",
    [142]="st03_0209_0",[143]="st03_0210_0",[144]="st03_0211_0",[145]="st03_0212_0",
    [146]="st03_0213_0",[147]="st03_0214_0",[148]="st03_0215_0",[149]="st03_0216_0",
    [150]="st03_0217_0",[151]="st03_0218_0",[152]="st03_0219_0",[153]="st03_0220_0",
    [154]="st03_0221_0",[155]="st03_0222_0",[156]="st03_0223_0",[157]="st03_0224_0",
    [158]="st03_0225_0",[159]="st03_0226_0",[160]="st03_0227_0",[161]="st03_0228_0",
    [162]="st03_0229_0",[163]="st03_0230_0",[164]="st03_0231_0",[165]="st03_0232_0",
    [166]="st03_0233_0",[167]="st03_0234_0",[168]="st03_0235_0",[169]="st03_0236_0",
    [170]="st03_0251_0",[171]="st03_0252_0",[172]="st03_0253_0",[173]="st03_0254_0",
    [174]="st03_0255_0",[175]="st03_0256_0",[176]="st03_0257_0",[177]="st03_0258_0",
    [178]="st03_0259_0",[179]="st03_0260_0",[180]="st03_0261_0",[181]="st03_0262_0",
    [182]="st03_0301_0",[183]="st03_0302_0",[184]="st03_0303_0",[185]="st03_0304_0",
    [186]="st03_0305_0",[187]="st03_0306_0",[188]="st03_0307_0",[189]="st03_0308_0",
    [190]="st03_0309_0",[191]="st03_0310_0",[192]="st03_0311_0",[193]="st03_0312_0",
    [194]="st03_0313_0",[195]="st03_0314_0",[196]="st03_0315_0",
    [197]="st03_0401_0",[198]="st03_0402_0",[199]="st03_0403_0",[200]="st03_0404_0",
    [201]="st03_0451_0",[202]="st03_0452_0",
    [203]="st03_0501_0",[204]="st03_0502_0",[205]="st03_0503_0",
    [206]="st03_0601_0",[207]="st03_0602_0",[208]="st03_0603_0",[209]="st03_0604_0",
    [210]="st03_0605_0",[211]="st03_0606_0",[212]="st03_0607_0",[213]="st03_0608_0",
    [214]="st03_0609_0",[215]="st03_0610_0",[216]="st03_0611_0",[217]="st03_0612_0",
    [218]="st03_0613_0",[219]="st03_0614_0",[220]="st03_0615_0",[221]="st03_0616_0",
    [222]="st03_0617_0",[223]="st03_0618_0",[224]="st03_0619_0",[225]="st03_0620_0",
    [226]="st03_0621_0",
    [227]="st03_0701_0",[228]="st03_0702_0",[229]="st03_0703_0",[230]="st03_0704_0",
    [231]="st03_0705_0",[232]="st03_0706_0",
    [233]="st03_0751_0",[234]="st03_0752_0",[235]="st03_0753_0",[236]="st03_0754_0",
    [237]="st03_0801_0",[238]="st03_0802_0",[239]="st03_0803_0",[240]="st03_0804_0",
    [241]="st03_0805_0",[242]="st03_0806_0",
    [243]="st04_0101_0",[244]="st04_0102_0",[245]="st04_0103_0",[246]="st04_0104_0",
    [247]="st04_0105_0",[248]="st04_0106_0",[249]="st04_0107_0",[250]="st04_0108_0",
    [251]="st04_0109_0",[252]="st04_0110_0",[253]="st04_0111_0",[254]="st04_0112_0",
    [255]="st04_0113_0",
    [256]="st04_0201_0",[257]="st04_0202_0",[258]="st04_0203_0",[259]="st04_0204_0",
    [260]="st04_0205_0",[261]="st04_0206_0",[262]="st04_0207_0",[263]="st04_0208_0",
    [264]="st04_0209_0",[265]="st04_0210_0",[266]="st04_0211_0",
    [267]="st04_0501_0",
    [268]="st04_0101_1",[269]="st04_0102_1",[270]="st04_0103_1",[271]="st04_0104_1",
    [272]="st04_0105_1",[273]="st04_0106_1",[274]="st04_0107_1",[275]="st04_0108_1",
    [276]="st04_0109_1",[277]="st04_0110_1",[278]="st04_0111_1",[279]="st04_0112_1",
    [280]="st04_0113_1",
    [281]="st04_0201_1",[282]="st04_0202_1",[283]="st04_0203_1",[284]="st04_0204_1",
    [285]="st04_0205_1",[286]="st04_0206_1",[287]="st04_0207_1",[288]="st04_0208_1",
    [289]="st04_0209_1",[290]="st04_0210_1",[291]="st04_0211_1",
    [292]="st04_0301_1",[293]="st04_0302_1",
    [294]="st04_0401_1",[295]="st04_0402_1",[296]="st04_0403_1",[297]="st04_0404_1",
    [298]="st04_0405_1",[299]="st04_0406_1",[300]="st04_0407_1",[301]="st04_0408_1",
    [302]="st04_0409_1",[303]="st04_0410_1",
    [304]="st05_0101_0",[305]="st05_0102_0",[306]="st05_0103_0",[307]="st05_0104_0",
    [308]="st05_0105_0",[309]="st05_0106_0",[310]="st05_0107_0",[311]="st05_0108_0",
    [312]="st05_0109_0",[313]="st05_0110_0",[314]="st05_0111_0",[315]="st05_0112_0",
    [316]="st05_0201_0",[317]="st05_0202_0",[318]="st05_0203_0",
    [319]="st05_0301_0",[320]="st05_0302_0",[321]="st05_0303_0",
    [322]="st05_0401_0",
    [323]="st05_0501_0",
    [324]="st05_0601_0",
}

local function map_id_str(id)
    if id == nil then return "?" end
    local n = math.tointeger(id) or id
    local name = MAP_ID_NAMES[n]
    if name then return string.format("%d  (%s)", n, name) end
    return tostring(n)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Names
-- ═══════════════════════════════════════════════════════════════════════════

local SCENARIO_NAMES = {
    [0]="S00_0000",[1]="S00_0100",[2]="S00_0200",[3]="S00_0300",
    [4]="S00_3000",[5]="S00_3100",[6]="S00_3200",[7]="S00_3300",
    [8]="S00_3400",[9]="S01_0000",[10]="S01_0100",[11]="S01_0200",
    [12]="S01_0300",[13]="S01_0400",[14]="S01_0500",[15]="S01_0600",
    [16]="S01_0700",[17]="S03_0000",[18]="S03_0100",[19]="S03_1000",
    [20]="S03_1100",[21]="S03_1200",[22]="S03_1500",[23]="S03_2000",
    [24]="S03_2100",[25]="S03_2200",[26]="S03_2300",[27]="S03_2500",
    [28]="S02_0000",[29]="S02_0100",[30]="S02_0200",[31]="S02_0300",
    [32]="S02_0400",[33]="S02_0500",[34]="S02_0600",[35]="S02_0700",
    [36]="S02_0800",[37]="S02_0900",[38]="S03_3000",[39]="S03_3100",
    [40]="S03_3200",[41]="S03_3500",[42]="S03_3600",[43]="S04_0000",
    [44]="S04_0100",[45]="S04_0200",[46]="S04_0300",[47]="S04_0400",
    [48]="S04_0500",[49]="S04_0600",[50]="S04_5000",[51]="S04_5100",
    [52]="S04_5200",[53]="S04_5300",[54]="S04_5400",[55]="S04_5500",
    [56]="S05_0000",[57]="S05_0100",[58]="S05_0200",[59]="S05_0300",
    [60]="S05_0400",[61]="S05_0500",[62]="S05_0600",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- KindID names for RE3R
-- ═══════════════════════════════════════════════════════════════════════════

local KIND_NAMES = {
    [4]  = "Zombie",
    [5]  = "Zombie Dog",
    [6]  = "Licker",
    [7]  = "Hunter",
    [18] = "Nemesis",
}

local function kind_name(id)
    if id == nil then return "?" end
    local n = math.tointeger(id) or id
    return KIND_NAMES[n] or ("Kind:" .. tostring(n))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Catalog (for Item Spawner / Inventory addition)
-- ═══════════════════════════════════════════════════════════════════════════

local ITEM_CATALOG = {
    -- Items
    { id = 1, debugName = "First Aid Spray", isWeapon = false },
    { id = 2, debugName = "Green Herb", isWeapon = false },
    { id = 3, debugName = "Red Herb", isWeapon = false },
    { id = 5, debugName = "Mixed Herb (G+G)", isWeapon = false },
    { id = 6, debugName = "Mixed Herb (G+R)", isWeapon = false },
    { id = 9, debugName = "Mixed Herb (G+G+G)", isWeapon = false },
    { id = 22, debugName = "Green Herb (Alt)", isWeapon = false },
    { id = 23, debugName = "Red Herb (Alt)", isWeapon = false },
    { id = 31, debugName = "Handgun Ammo", isWeapon = false },
    { id = 32, debugName = "Shotgun Shells", isWeapon = false },
    { id = 33, debugName = "Assault Rifle Ammo", isWeapon = false },
    { id = 34, debugName = "MAG Ammo", isWeapon = false },
    { id = 36, debugName = "Mine Rounds", isWeapon = false },
    { id = 37, debugName = "Explosive Rounds", isWeapon = false },
    { id = 38, debugName = "Acid Rounds", isWeapon = false },
    { id = 39, debugName = "Flame Rounds", isWeapon = false },
    { id = 57, debugName = "Ink Ribbon", isWeapon = false },
    { id = 61, debugName = "Gunpowder", isWeapon = false },
    { id = 62, debugName = "High-Grade Gunpowder", isWeapon = false },
    { id = 63, debugName = "Explosive A", isWeapon = false },
    { id = 64, debugName = "Explosive B", isWeapon = false },
    { id = 66, debugName = "High-Grade Gunpowder (Yellow)", isWeapon = false },
    { id = 67, debugName = "High-Grade Gunpowder (White)", isWeapon = false },
    { id = 76, debugName = "Moderator (Handgun)", isWeapon = false },
    { id = 77, debugName = "Dot Sight (Handgun)", isWeapon = false },
    { id = 78, debugName = "Extended Magazine (Handgun)", isWeapon = false },
    { id = 91, debugName = "Semi-Auto Barrel (Shotgun)", isWeapon = false },
    { id = 92, debugName = "Tactical Stock (Shotgun)", isWeapon = false },
    { id = 93, debugName = "Shell Holder (Shotgun)", isWeapon = false },
    { id = 96, debugName = "Scope (Assault Rifle)", isWeapon = false },
    { id = 97, debugName = "Dual Magazine (Assault Rifle)", isWeapon = false },
    { id = 98, debugName = "Tactical Grip (Assault Rifle)", isWeapon = false },
    { id = 101, debugName = "Extended Barrel (MAG)", isWeapon = false },
    { id = 131, debugName = "Audiocassette Tape", isWeapon = false },
    { id = 151, debugName = "Lock Pick", isWeapon = false },
    { id = 152, debugName = "Bolt Cutters", isWeapon = false },
    { id = 161, debugName = "Battery", isWeapon = false },
    { id = 162, debugName = "Key", isWeapon = false },
    { id = 164, debugName = "ID Card", isWeapon = false },
    { id = 165, debugName = "Electronic Gadget", isWeapon = false },
    { id = 166, debugName = "Detonator", isWeapon = false },
    { id = 181, debugName = "Fire Hose", isWeapon = false },
    { id = 182, debugName = "Kendo's Gate Key", isWeapon = false },
    { id = 185, debugName = "Case", isWeapon = false },
    { id = 186, debugName = "Battery Pack", isWeapon = false },
    { id = 187, debugName = "Green Jewel", isWeapon = false },
    { id = 188, debugName = "Blue Jewel", isWeapon = false },
    { id = 189, debugName = "Red Jewel", isWeapon = false },
    { id = 192, debugName = "Fancy Box (Green Jewel)", isWeapon = false },
    { id = 193, debugName = "Fancy Box (Blue Jewel)", isWeapon = false },
    { id = 194, debugName = "Fancy Box (Red Jewel)", isWeapon = false },
    { id = 211, debugName = "Hospital ID Card", isWeapon = false },
    { id = 212, debugName = "Tape Player (Tape Inserted)", isWeapon = false },
    { id = 213, debugName = "Audiocassette Tape (Alt)", isWeapon = false },
    { id = 214, debugName = "Tape Player", isWeapon = false },
    { id = 215, debugName = "Vaccine Sample", isWeapon = false },
    { id = 217, debugName = "Detonator (Alt)", isWeapon = false },
    { id = 218, debugName = "Key (Alt)", isWeapon = false },
    { id = 222, debugName = "Fuse (1)", isWeapon = false },
    { id = 223, debugName = "Fuse (2)", isWeapon = false },
    { id = 224, debugName = "Fuse (3)", isWeapon = false },
    { id = 231, debugName = "Wristband", isWeapon = false },
    { id = 232, debugName = "Flash Drive", isWeapon = false },
    { id = 233, debugName = "Vaccine", isWeapon = false },
    { id = 234, debugName = "Culture Sample", isWeapon = false },
    { id = 235, debugName = "Liquid-filled Test Tube", isWeapon = false },
    { id = 236, debugName = "Vaccine Base", isWeapon = false },
    { id = 246, debugName = "Police Department Map", isWeapon = false },
    { id = 247, debugName = "Map of Downtown RC", isWeapon = false },
    { id = 248, debugName = "Substation Map", isWeapon = false },
    { id = 249, debugName = "Sewers Map", isWeapon = false },
    { id = 250, debugName = "Hospital Map", isWeapon = false },
    { id = 252, debugName = "Underground Storage Map", isWeapon = false },
    { id = 253, debugName = "NEST 2 Map", isWeapon = false },
    { id = 261, debugName = "Hip Pouch", isWeapon = false },
    { id = 264, debugName = "Fire Hose (Alt)", isWeapon = false },
    { id = 301, debugName = "Iron Defense Coin", isWeapon = false },
    { id = 302, debugName = "Assault Coin", isWeapon = false },
    { id = 303, debugName = "Recovery Coin", isWeapon = false },
    { id = 304, debugName = "Crafting Companion", isWeapon = false },
    { id = 305, debugName = "S.T.A.R.S. Combat Manual", isWeapon = false },
    { id = 311, debugName = "Supply Case (Handgun Parts)", isWeapon = false },
    { id = 312, debugName = "Supply Case (Shotgun Parts)", isWeapon = false },
    { id = 313, debugName = "Supply Case (Shotgun Parts Alt)", isWeapon = false },
    { id = 314, debugName = "Supply Case (AR Parts)", isWeapon = false },
    { id = 315, debugName = "Supply Case (MAG Parts)", isWeapon = false },
    { id = 316, debugName = "Supply Case (Flame Rounds)", isWeapon = false },

    -- Weapons
    { id = 1, debugName = "G19 Handgun", isWeapon = true },
    { id = 2, debugName = "G18 Handgun (Burst Model)", isWeapon = true },
    { id = 3, debugName = "G18 Handgun", isWeapon = true },
    { id = 4, debugName = "Samurai Edge", isWeapon = true },
    { id = 7, debugName = "MUP Handgun", isWeapon = true },
    { id = 11, debugName = "M3 Shotgun", isWeapon = true },
    { id = 21, debugName = "CQBR Assault Rifle", isWeapon = true },
    { id = 22, debugName = "Infinite CQBR Assault Rifle", isWeapon = true },
    { id = 31, debugName = ".44 AE Lightning Hawk", isWeapon = true },
    { id = 32, debugName = "RAI-DEN", isWeapon = true },
    { id = 42, debugName = "MGL Grenade Launcher", isWeapon = true },
    { id = 45, debugName = "Rocket Launcher", isWeapon = true },
    { id = 46, debugName = "Combat Knife", isWeapon = true },
    { id = 47, debugName = "Survival Knife", isWeapon = true },
    { id = 48, debugName = "HOT DOGGER", isWeapon = true },
    { id = 49, debugName = "Infinite Rocket Launcher", isWeapon = true },
    { id = 50, debugName = "Railgun", isWeapon = true },
    { id = 65, debugName = "Hand Grenade", isWeapon = true },
    { id = 66, debugName = "Flash Grenade", isWeapon = true }
}

local ITEM_COMBO_LABELS = nil

local function init_item_catalog()
    table.sort(ITEM_CATALOG, function(a, b)
        local name_a = a.debugName:lower()
        local name_b = b.debugName:lower()
        return name_a < name_b
    end)

    ITEM_COMBO_LABELS = {}
    for i, item in ipairs(ITEM_CATALOG) do
        local suffix = item.isWeapon and " (Weapon)" or ""
        ITEM_COMBO_LABELS[i] = string.format("%s%s [ID %d]", item.debugName, suffix, item.id)
    end
end

local function add_item_to_inventory(item_id, count)
    local item_manager = sdk.get_managed_singleton("app.ItemManager")
    if not item_manager then
        log.error("[RE3R Trainer] app.ItemManager not found!")
        return false
    end

    local count = count or 1

    -- Try standard addItem with Boolean (isDirectAdd = true)
    local ok, res = pcall(function()
        return item_manager:call("addItem(offline.gamemastering.item.Type, System.Int32, System.Boolean)", item_id, count, true)
    end)
    if ok then
        log.info("[RE3R Trainer] Added item via addItem(Type, Int32, Boolean): ID " .. tostring(item_id))
        return true
    end

    -- Try standard addItem with Boolean (isDirectAdd = false)
    ok, res = pcall(function()
        return item_manager:call("addItem(offline.gamemastering.item.Type, System.Int32, System.Boolean)", item_id, count, false)
    end)
    if ok then
        log.info("[RE3R Trainer] Added item via addItem(Type, Int32, Boolean=false): ID " .. tostring(item_id))
        return true
    end

    -- Try without Boolean
    ok, res = pcall(function()
        return item_manager:call("addItem(offline.gamemastering.item.Type, System.Int32)", item_id, count)
    end)
    if ok then
        log.info("[RE3R Trainer] Added item via addItem(Type, Int32): ID " .. tostring(item_id))
        return true
    end

    -- Try generic call if type-checking is lax
    ok, res = pcall(function()
        return item_manager:call("addItem", item_id, count)
    end)
    if ok then
        log.info("[RE3R Trainer] Added item via addItem(generic): ID " .. tostring(item_id))
        return true
    end

    log.error("[RE3R Trainer] Failed to add item to inventory: ID " .. tostring(item_id))
    return false
end


-- ═══════════════════════════════════════════════════════════════════════════
-- Config & Persistence
-- ═══════════════════════════════════════════════════════════════════════════

local TITLE    = "Biorand RE3R Trainer v3.0"
local CFG_FILE = "biorand_re3r_trainer.json"

local cfg = {
    show_dev_overlay        = true,
    show_enemy_esp          = true,
    show_item_esp           = true,
    show_spawn_overlay      = true,
    show_levelflow_overlay  = true,
    show_ui                 = true,

    enemy_esp_range         = 30.0,
    item_esp_range          = 30.0,
    hide_dead               = true,

    col_enemy_name          = 0xFFFFFFFF,
    col_item_name           = 0xFF55FF99,
    col_object_name         = 0xFFFFCC88,

    show_object_esp                = false,
    object_esp_range               = 15.0,
    object_esp_only_tagged         = true,
    show_levelflow_catalog_overlay = false,
    go_highlight_selected          = false,
    editor_mode                    = false,

    font_size               = 16,
    scan_interval           = 45,
    precise_mode            = false,
}

local PERSIST_KEYS = {}
for k in pairs(cfg) do PERSIST_KEYS[#PERSIST_KEYS + 1] = k end

local function cfg_save()
    if not json then return end
    local data = {}
    for _, k in ipairs(PERSIST_KEYS) do data[k] = cfg[k] end
    local ok, err = pcall(json.dump_file, CFG_FILE, data)
    if not ok then log.warn("[RE3R Trainer] cfg_save failed: " .. tostring(err)) end
end

local function cfg_load()
    if not json then return end
    local ok, data = pcall(json.load_file, CFG_FILE)
    if not ok or type(data) ~= "table" then return end
    for _, k in ipairs(PERSIST_KEYS) do
        if data[k] ~= nil and type(data[k]) == type(cfg[k]) then
            cfg[k] = data[k]
        end
    end
end

cfg_load()
re.on_config_save(cfg_save)

-- ═══════════════════════════════════════════════════════════════════════════
-- Hardcoded Placements (Custom placements applied automatically on map loads)
-- ═══════════════════════════════════════════════════════════════════════════
local HARDCODED_PLACEMENTS = {
    -- Example entry:
    -- {
    --     go_name = "sm00_typewriter_01",
    --     pos = { x = 12.34, y = 1.20, z = -45.67 },
    --     rot = { x = 0.0, y = 180.0, z = 0.0 },
    --     map_id = 16
    -- }
}


-- ═══════════════════════════════════════════════════════════════════════════
-- Constants
-- ═══════════════════════════════════════════════════════════════════════════

local SPAWN_OVERLAY_LIMIT     = 12
local SPAWN_NAME_MAX_CHARS    = 28
local LEVELFLOW_NAME_MAX_CHARS = 36
local LEVELFLOW_HIGHLIGHT_WINDOW = 30.0

-- ═══════════════════════════════════════════════════════════════════════════
-- Runtime State
-- ═══════════════════════════════════════════════════════════════════════════

local state = {
    tick            = 0,
    sw              = 1920,
    sh              = 1080,
    player_pos      = nil,
    player_hp       = 0,
    dev_rotation    = nil,

    enemies         = {},
    items           = {},
    spawn_groups    = {},
    scenarios       = {},
    objects         = {},

    scenario_state_history = {},
    spawn_scene_address    = 0,
    scenario_scene_address = 0,

    status_msg      = "",
    status_until    = 0,

    dev = {
        scene        = "",
        map_id       = nil,
        rank         = nil,
        playtime     = nil,
        player_name  = "",
        player_state = "",
    },

    sel_type = nil,   -- "enemy", "spawn", "item", "scenario"
    sel_data = nil,   -- shallow copy of the selected row's data table
    ui_tab = 1,
    deferred = {},
    saved_placements = {},
    applied_placements = {},
    key_down = {},
    column_width_set = false,
}

local PLACEMENT_FILE = "biorand_placements.json"

local function save_placements_json()
    if not json then return end
    local ok, err = pcall(json.dump_file, PLACEMENT_FILE, { placements = state.saved_placements })
    if not ok then log.warn("[RE3R Trainer] save_placements_json failed: " .. tostring(err)) end
end

local function load_placements_json()
    if not json then return end
    local ok, data = pcall(json.load_file, PLACEMENT_FILE)
    if ok and type(data) == "table" and type(data.placements) == "table" then
        state.saved_placements = data.placements
    else
        state.saved_placements = {}
    end
end

local function find_placement_entry(name, guid, map_id)
    if not state.saved_placements then return nil end
    -- 1. Search in saved placements
    for _, p in ipairs(state.saved_placements) do
        if p.go_name == name or (guid and p.go_guid == guid) then
            if not p.map_id or p.map_id == map_id then
                return p
            end
        end
    end
    -- 2. Search in hardcoded placements
    for _, p in ipairs(HARDCODED_PLACEMENTS) do
        if p.go_name == name or (guid and p.go_guid == guid) then
            if not p.map_id or p.map_id == map_id then
                return p
            end
        end
    end
    return nil
end

load_placements_json()

-- ═══════════════════════════════════════════════════════════════════════════
-- Engine / Scene Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local _sm    = sdk.get_native_singleton("via.SceneManager")
local _sm_td = sdk.find_type_definition("via.SceneManager")

-- ── SDK Types & Methods for Object Movement ──
local mesh_rt = sdk.typeof("via.render.Mesh")
local rigidbody_set_rt = sdk.typeof("via.dynamics.RigidBodySet")
local colliders_rt = sdk.typeof("via.physics.Colliders")
local character_controller_rt = sdk.typeof("via.physics.CharacterController")
local gimmick_dynamic_prefab_controller_rt = sdk.typeof("app.GimmickDynamicPrefabController")
local dynamics_prop_object_rt = sdk.typeof("app.DynamicsPropObject")

local transform_td = sdk.find_type_definition("via.Transform")
local set_position_method = transform_td and transform_td:get_method("set_Position")
local set_rotation_method = transform_td and transform_td:get_method("set_Rotation")
local set_local_position_method = transform_td and transform_td:get_method("set_LocalPosition")
local set_local_euler_method = transform_td and transform_td:get_method("set_LocalEulerAngle")
local set_local_scale_method = transform_td and transform_td:get_method("set_LocalScale")

local function defer(callback)
    state.deferred[#state.deferred + 1] = callback
end

local function process_deferred()
    if #state.deferred == 0 then
        return
    end

    local queue = state.deferred
    state.deferred = {}
    for _, callback in ipairs(queue) do
        local ok, err = pcall(callback)
        if not ok then
            log.warn("[RE3R Trainer] Deferred update failed: " .. tostring(err))
        end
    end
end

-- ── Keyboard, Camera, and Nudging Hotkey helpers ──

local function is_key_down(vk)
    if not vk or vk == 0 then
        return false
    end
    local ok, down = pcall(function()
        return reframework:is_key_down(vk)
    end)
    return ok and down
end

local function key_just_pressed(name, vk)
    local down = is_key_down(vk)
    local was_down = state.key_down[name] == true
    state.key_down[name] = down
    return down and not was_down
end

local function any_key_just_pressed(name, keys)
    local down = false
    for _, vk in ipairs(keys) do
        if is_key_down(vk) then
            down = true
            break
        end
    end
    local was_down = state.key_down[name] == true
    state.key_down[name] = down
    return down and not was_down
end

local function vec_scale(v, scalar)
    return Vector3f.new(v.x * scalar, v.y * scalar, v.z * scalar)
end

local function vec_normalize_flat(v, fallback)
    if not v then
        return fallback
    end
    local x = v.x or 0
    local z = v.z or 0
    local magnitude = math.sqrt(x * x + z * z)
    if magnitude < 0.0001 then
        return fallback
    end
    return Vector3f.new(x / magnitude, 0, z / magnitude)
end

local function get_camera_basis()
    local right = nil
    local up = nil
    local forward = nil

    pcall(function()
        local camera = sdk.get_primary_camera()
        if not camera then
            return
        end

        local matrix = camera:call("get_WorldMatrix")
        if not matrix then
            return
        end

        local row0 = matrix[0]
        local row1 = matrix[1]
        local row2 = matrix[2]
        if row0 then
            right = Vector3f.new(row0.x, row0.y, row0.z)
        end
        if row1 then
            up = Vector3f.new(row1.x, row1.y, row1.z)
        end
        if row2 then
            forward = Vector3f.new(-row2.x, -row2.y, -row2.z)
        end
    end)

    return right, up, forward
end

local function get_camera_position()
    local position = nil
    pcall(function()
        local camera = sdk.get_primary_camera()
        if not camera then
            return
        end
        local camera_object = camera:call("get_GameObject")
        if not camera_object then
            return
        end
        local xf = camera_object:call("get_Transform")
        if xf then position = xf:call("get_Position") end
    end)
    return position
end

local function get_observer_position()
    local position = nil
    pcall(function()
        local character_manager = sdk.get_managed_singleton("app.CharacterManager")
        if not character_manager then
            return
        end
        local player_context = character_manager:call("getPlayerContextRef")
        if not player_context then
            player_context = character_manager:call("get_PlayerContextFast")
        end
        if not player_context then
            return
        end
        local game_object = player_context:call("get_GameObject")
        if not game_object then
            return
        end
        local xf = game_object:call("get_Transform")
        if xf then position = xf:call("get_Position") end
    end)
    if position then
        return position
    end
    return get_camera_position()
end

local function nudge_selected_object(dx, dy, dz)
    local entry = state.sel_data
    if not entry or not entry._go_ref then
        return false
    end

    local go = entry._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        return false
    end

    local position = nil
    pcall(function() position = xf:call("get_Position") end)
    if not position then
        return false
    end

    local moved = apply_position(
        xf,
        position.x + dx,
        position.y + dy,
        position.z + dz,
        go
    )
    if moved then
        entry.x = position.x + dx
        entry.y = position.y + dy
        entry.z = position.z + dz
        if entry.pos then
            entry.pos.x = position.x + dx
            entry.pos.y = position.y + dy
            entry.pos.z = position.z + dz
        end
    end
    return moved
end

local function rotate_selected_yaw(delta_yaw_deg)
    local entry = state.sel_data
    if not entry or not entry._go_ref then
        return false
    end

    local go = entry._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        return false
    end

    local local_euler = nil
    pcall(function()
        local_euler = xf:call("get_LocalEulerAngle")
    end)
    if not local_euler then
        return false
    end

    local pitch = math.deg(local_euler.x or 0)
    local yaw = math.deg(local_euler.y or 0)
    local roll = math.deg(local_euler.z or 0)
    return apply_local_euler(xf, pitch, yaw + delta_yaw_deg, roll, go)
end

local function move_selected_to_front()
    local entry = state.sel_data
    if not entry or not entry._go_ref then
        return
    end

    local go = entry._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        return
    end

    local observer_position = get_observer_position() or (state.player_pos and Vector3f.new(state.player_pos.x, state.player_pos.y, state.player_pos.z))
    if not observer_position then
        return
    end

    local _, _, forward = get_camera_basis()
    forward = forward or Vector3f.new(0, 0, 1)
    
    local target_x = observer_position.x + forward.x * 1.25
    local target_y = observer_position.y + forward.y * 1.25
    local target_z = observer_position.z + forward.z * 1.25

    defer(function()
        apply_position(xf, target_x, target_y, target_z, go)
        log.info(string.format("[RE3R Trainer] Moved selected to front: %.3f, %.3f, %.3f", target_x, target_y, target_z))
    end)
end

local function cycle_selected_entry(dir)
    local list = nil
    local obj_type = nil
    if state.ui_tab == 1 then
        list = state.enemies
        obj_type = "enemy"
    elseif state.ui_tab == 2 then
        list = state.spawn_groups
        obj_type = "spawn"
    elseif state.ui_tab == 4 then
        list = state.items
        obj_type = "item"
    elseif state.ui_tab == 5 then
        list = state.objects
        obj_type = "go"
    end

    if not list or #list == 0 then
        return
    end

    local current_idx = nil
    if state.sel_data then
        local current_guid = state.sel_data.guid or state.sel_data.go_guid
        for idx, entry in ipairs(list) do
            local entry_guid = entry.guid or entry.go_guid
            if entry_guid == current_guid then
                current_idx = idx
                break
            end
        end
    end

    local next_idx = 1
    if current_idx then
        next_idx = current_idx + dir
        if next_idx > #list then
            next_idx = 1
        elseif next_idx < 1 then
            next_idx = #list
        end
    else
        next_idx = dir > 0 and 1 or #list
    end

    local match = list[next_idx]
    if match then
        select_obj(obj_type, match)
    end
end

local function process_spawn_input()
    -- * (Numpad Multiply): Copy
    if key_just_pressed("copy_selected", 0x6A) then
        local entry = state.sel_data
        if entry and entry._go_ref then
            local go = entry._go_ref
            local xf = nil
            pcall(function() xf = go:call("get_Transform") end)
            if xf then
                local wp = xf:call("get_Position")
                local le = xf:call("get_LocalEulerAngle")
                if wp and le then
                    local text = string.format("%.3f\t%.3f\t%.3f\t%.1f\t%.1f\t%.1f",
                        wp.x, wp.y, wp.z, math.deg(le.x or 0), math.deg(le.y or 0), math.deg(le.z or 0))
                    imgui.set_clipboard_text(text)
                    log.info("[RE3R Trainer] Copied selected transform: " .. text)
                end
            end
        end
    end

    -- C key on keyboard: Copy GUID
    local is_typing = false
    pcall(function()
        local io = imgui.get_io()
        if io and io.WantTextInput then
            is_typing = true
        end
    end)
    if not is_typing and key_just_pressed("copy_selected_guid_keyboard", 0x43) then
        local entry = state.sel_data
        if entry then
            local guid_str = nil
            if state.sel_type == "item" then
                guid_str = entry.pos_guid or entry.go_guid
            elseif state.sel_type == "enemy" then
                guid_str = entry.guid or entry.go_guid
            else
                guid_str = entry.go_guid or entry.guid
            end

            if guid_str and guid_str ~= "" and guid_str ~= "-" then
                imgui.set_clipboard_text(guid_str)
                log.info("[RE3R Trainer] Keyboard copied selected GUID: " .. guid_str)
            else
                log.warn("[RE3R Trainer] Selected object has no valid GUID to copy!")
            end
        end
    end

    -- + (Numpad Add): Paste
    if key_just_pressed("paste_selected", 0x6B) then
        local text = imgui.get_clipboard_text()
        if text and text ~= "" then
            local x, y, z, p, yaw, r = text:match("([%%-%%d%%.]+)[%%s%%t]+([%%-%%d%%.]+)[%%s%%t]+([%%-%%d%%.]+)[%%s%%t]+([%%-%%d%%.]+)[%%s%%t]+([%%-%%d%%.]+)[%%s%%t]+([%%-%%d%%.]+)")
            if x and y and z and p and yaw and r then
                local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
                local np, nyaw, nr = tonumber(p), tonumber(yaw), tonumber(r)
                local go = state.sel_data and state.sel_data._go_ref
                local xf = nil
                pcall(function() xf = go:call("get_Transform") end)
                if xf and go then
                    defer(function()
                        apply_position(xf, nx, ny, nz, go)
                        apply_local_euler(xf, np, nyaw, nr, go)
                        log.info(string.format("[RE3R Trainer] Pasted placement to %.3f, %.3f, %.3f", nx, ny, nz))
                    end)
                end
            end
        end
    end

    -- - (Numpad Subtract): Del
    if key_just_pressed("delete_selected", 0x6D) then
        local go = state.sel_data and state.sel_data._go_ref
        if go then
            pcall(function() go:call("destroy", go) end)
            log.info("[RE3R Trainer] Destroyed selected object")
            state.sel_type = nil
            state.sel_data = nil
        end
    end

    -- Enter: CSV
    if key_just_pressed("copy_selected_csv", 0x0D) then
        local entry = state.sel_data
        if entry and entry._go_ref then
            local go = entry._go_ref
            local xf = nil
            pcall(function() xf = go:call("get_Transform") end)
            if xf then
                local wp = xf:call("get_Position")
                local le = xf:call("get_LocalEulerAngle")
                if wp and le then
                    local name = tostring(go:call("get_Name") or "")
                    local guid = entry.go_guid or extract_guid(go) or ""
                    local text = string.format("%s,%s,%.3f,%.3f,%.3f,%.1f,%.1f,%.1f",
                        name, guid, wp.x, wp.y, wp.z, math.deg(le.x or 0), math.deg(le.y or 0), math.deg(le.z or 0))
                    imgui.set_clipboard_text(text)
                    log.info("[RE3R Trainer] Copied selected CSV: " .. text)
                end
            end
        end
    end

    -- . (Numpad Decimal) or Delete key: Front
    if any_key_just_pressed("move_selected_to_front", { 0x6E, 0x2E }) then
        move_selected_to_front()
    end

    -- , (Comma) and . (Period): Cycle selected
    if key_just_pressed("cycle_selected_prev", 0xBC) then
        cycle_selected_entry(-1)
    end
    if key_just_pressed("cycle_selected_next", 0xBE) then
        cycle_selected_entry(1)
    end

    -- / (Numpad Division): Toggle precise mode
    if key_just_pressed("toggle_precise_mode", 0x6F) then
        cfg.precise_mode = not cfg.precise_mode
        log.info("[RE3R Trainer] Precise mode toggled: " .. tostring(cfg.precise_mode))
    end

    -- Movement nudges (4/8/6/2/1/3) and rotate (7/9)
    if state.sel_data and state.sel_data._go_ref then
        local right, _, forward = get_camera_basis()
        right = vec_normalize_flat(right, Vector3f.new(1, 0, 0))
        forward = vec_normalize_flat(forward, Vector3f.new(0, 0, 1))

        local step = cfg.precise_mode and 0.01 or 0.05
        local rotation_step = cfg.precise_mode and 1.0 or 22.5

        if key_just_pressed("nudge_left", 0x64) then -- Numpad 4
            defer(function()
                nudge_selected_object(-right.x * step, 0, -right.z * step)
            end)
        end
        if key_just_pressed("nudge_up", 0x68) then -- Numpad 8
            defer(function()
                nudge_selected_object(forward.x * step, 0, forward.z * step)
            end)
        end
        if key_just_pressed("nudge_right", 0x66) then -- Numpad 6
            defer(function()
                nudge_selected_object(right.x * step, 0, right.z * step)
            end)
        end
        if key_just_pressed("nudge_down", 0x62) then -- Numpad 2
            defer(function()
                nudge_selected_object(-forward.x * step, 0, -forward.z * step)
            end)
        end
        if key_just_pressed("nudge_y_down", 0x61) then -- Numpad 1
            defer(function()
                nudge_selected_object(0, -step, 0)
            end)
        end
        if key_just_pressed("nudge_y_up", 0x63) then -- Numpad 3
            defer(function()
                nudge_selected_object(0, step, 0)
            end)
        end
        if key_just_pressed("rotate_left", 0x67) then -- Numpad 7
            defer(function()
                rotate_selected_yaw(-rotation_step)
            end)
        end
        if key_just_pressed("rotate_right", 0x69) then -- Numpad 9
            defer(function()
                rotate_selected_yaw(rotation_step)
            end)
        end

        -- Extra TKL Keyboard Shortcuts (Shift + Arrow Keys, Page Up/Down, [ / ])
        local is_shift_down = false
        pcall(function() is_shift_down = reframework:is_key_down(0x10) end)
        
        if is_shift_down then
            if key_just_pressed("tkl_nudge_left", 0x25) then -- Left Arrow
                defer(function() nudge_selected_object(-right.x * step, 0, -right.z * step) end)
            end
            if key_just_pressed("tkl_nudge_up", 0x26) then -- Up Arrow
                defer(function() nudge_selected_object(forward.x * step, 0, forward.z * step) end)
            end
            if key_just_pressed("tkl_nudge_right", 0x27) then -- Right Arrow
                defer(function() nudge_selected_object(right.x * step, 0, right.z * step) end)
            end
            if key_just_pressed("tkl_nudge_down", 0x28) then -- Down Arrow
                defer(function() nudge_selected_object(-forward.x * step, 0, -forward.z * step) end)
            end
            if key_just_pressed("tkl_nudge_y_up", 0x21) then -- Page Up
                defer(function() nudge_selected_object(0, step, 0) end)
            end
            if key_just_pressed("tkl_nudge_y_down", 0x22) then -- Page Down
                defer(function() nudge_selected_object(0, -step, 0) end)
            end
            if key_just_pressed("tkl_rotate_left", 0xDB) then -- [ Key
                defer(function() rotate_selected_yaw(-rotation_step) end)
            end
            if key_just_pressed("tkl_rotate_right", 0xDD) then -- ] Key
                defer(function() rotate_selected_yaw(rotation_step) end)
            end
        end
    end
end

local function get_component(go, component_type)
    if not go or not component_type then
        return nil
    end

    local component = nil
    pcall(function()
        component = go:call("getComponent(System.Type)", component_type)
    end)
    return component
end

local function call_transform_method(xf, method_name, method, value)
    if xf then
        local ok, err = pcall(function() xf:call(method_name, value) end)
        if ok then
            return true
        end
    end

    if method then
        local ok, err = pcall(method.call, method, xf, value)
        if ok then
            return true
        end
        log.warn("[RE3R Trainer] " .. method_name .. " failed: " .. tostring(err))
    end

    if transform_td then
        local ok, err = pcall(sdk.call_native_func, xf, transform_td, method_name, value)
        if ok then
            return true
        end
        log.warn("[RE3R Trainer] " .. method_name .. " native call failed: " .. tostring(err))
    end

    return false
end

local function force_mesh_on_go(go)
    local mesh = get_component(go, mesh_rt)
    if not mesh then
        return
    end

    pcall(function() mesh:call("set_ForceWarp", true) end)
    pcall(function() mesh:call("set_ForceDynamicMesh", true) end)
    pcall(function() mesh:call("set_StaticMesh", false) end)
end

local function prepare_game_object_for_move(go)
    if not go then
        return
    end

    force_mesh_on_go(go)

    local rigidbody_set = get_component(go, rigidbody_set_rt)
    if rigidbody_set then
        pcall(function() rigidbody_set:call("set_Enabled", false) end)
    end

    local gimmick_controller = get_component(go, gimmick_dynamic_prefab_controller_rt)
    if gimmick_controller then
        pcall(function() gimmick_controller:call("set_Enabled", false) end)
    end

    local dynamics_prop = get_component(go, dynamics_prop_object_rt)
    if dynamics_prop then
        pcall(function() dynamics_prop:call("set_Enabled", false) end)
    end

    local colliders = get_component(go, colliders_rt)
    if colliders then
        pcall(function() colliders:call("set_Enabled", false) end)
        pcall(function() colliders:call("set_Static", false) end)
        pcall(function() colliders:call("updatePose") end)
    end

    local character_controller = get_component(go, character_controller_rt)
    if character_controller then
        pcall(function() character_controller:call("set_Enabled", false) end)
        pcall(function() character_controller:call("warp") end)
    end

    -- Disable EnemyController components to freeze active enemy AI
    local enemy_ctrl_types = { "offline.EnemyController", "offline.enemy.EnemyController", "offline.EnemyCharacterController" }
    for _, tname in ipairs(enemy_ctrl_types) do
        local rt = sdk.typeof(tname)
        if rt then
            local comp = get_component(go, rt)
            if comp then
                pcall(function() comp:call("set_Enabled", false) end)
            end
        end
    end
end

local function prepare_transform_tree_for_move(xf, depth)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local child_go = child:call("get_GameObject")
            if child_go then
                prepare_game_object_for_move(child_go)
            end
        end)

        prepare_transform_tree_for_move(child, depth + 1)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function refresh_child_transforms(xf, depth)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local local_position = child:call("get_LocalPosition")
            if local_position then
                call_transform_method(child, "set_LocalPosition", set_local_position_method, local_position)
            end
        end)

        refresh_child_transforms(child, depth + 1)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function move_direct_children_by_delta(xf, dx, dy, dz)
    if not xf then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local child_position = child:call("get_Position")
            if child_position then
                call_transform_method(
                    child,
                    "set_Position",
                    set_position_method,
                    Vector3f.new(child_position.x + dx, child_position.y + dy, child_position.z + dz))
            end

            local local_position = child:call("get_LocalPosition")
            if local_position then
                call_transform_method(child, "set_LocalPosition", set_local_position_method, local_position)
            end
        end)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function collect_mesh_descendants(xf, depth, out)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 100 do
        count = count + 1

        pcall(function()
            local child_go = child:call("get_GameObject")
            if child_go and get_component(child_go, mesh_rt) then
                local child_position = child:call("get_Position")
                if child_position then
                    out[#out + 1] = {
                        xf = child,
                        go = child_go,
                        x = child_position.x,
                        y = child_position.y,
                        z = child_position.z,
                    }
                end
            end
        end)

        collect_mesh_descendants(child, depth + 1, out)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function sync_mesh_descendants(descendants, dx, dy, dz)
    for _, descendant in ipairs(descendants) do
        local expected_x = descendant.x + dx
        local expected_y = descendant.y + dy
        local expected_z = descendant.z + dz

        local current = nil
        pcall(function() current = descendant.xf:call("get_Position") end)
        local needs_move = true
        if current then
            local delta = math.abs(current.x - expected_x) + math.abs(current.y - expected_y) +
                math.abs(current.z - expected_z)
            needs_move = delta > 0.01
        end

        if needs_move then
            prepare_game_object_for_move(descendant.go)
            call_transform_method(
                descendant.xf,
                "set_Position",
                set_position_method,
                Vector3f.new(expected_x, expected_y, expected_z))
        end
    end
end

local function apply_position(xf, x, y, z, go)
    if not xf then
        return false
    end

    local current_position = nil
    pcall(function() current_position = xf:call("get_Position") end)
    local old_x = current_position and current_position.x or nil
    local old_y = current_position and current_position.y or nil
    local old_z = current_position and current_position.z or nil

    local mesh_descendants = {}
    if go then
        collect_mesh_descendants(xf, 0, mesh_descendants)
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local changed = call_transform_method(xf, "set_Position", set_position_method, Vector3f.new(x, y, z))
    if changed and go then
        if old_x and old_y and old_z then
            local dx = x - old_x
            local dy = y - old_y
            local dz = z - old_z
            move_direct_children_by_delta(xf, dx, dy, dz)
            sync_mesh_descendants(mesh_descendants, dx, dy, dz)
        end
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function apply_rotation_quat(xf, quat, go)
    if not xf or not quat then
        return false
    end

    if go then
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local changed = call_transform_method(xf, "set_Rotation", set_rotation_method, quat)
    if changed and go then
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function apply_local_euler(xf, pitch_deg, yaw_deg, roll_deg, go)
    if not xf then
        return false
    end

    if go then
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local euler = Vector3f.new(math.rad(pitch_deg), math.rad(yaw_deg), math.rad(roll_deg))
    local changed = call_transform_method(xf, "set_LocalEulerAngle", set_local_euler_method, euler)
    if changed and go then
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function apply_local_scale(xf, x, y, z, go)
    if not xf then
        return false
    end

    if go then
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local scale = Vector3f.new(x, y, z)
    local changed = call_transform_method(xf, "set_LocalScale", set_local_scale_method, scale)
    if changed and go then
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function get_scene()
    local ok, s = pcall(sdk.call_native_func, _sm, _sm_td, "get_CurrentScene()")
    return ok and s or nil
end

local function get_window_size()
    local mv = nil
    pcall(function() mv = sdk.call_native_func(_sm, _sm_td, "get_MainView") end)
    if not mv then return nil end
    local sz = nil
    pcall(function() sz = mv:call("get_WindowSize") end)
    return sz
end

local function update_screen_size()
    local sz = get_window_size()
    if sz and sz.w and sz.w > 0 then state.sw = sz.w end
    if sz and sz.h and sz.h > 0 then state.sh = sz.h end
end

local function dist3(a, b)
    if not a or not b then return 0 end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function clamp_text(text, max_chars)
    local s = tostring(text or "")
    if #s <= max_chars then return s end
    return s:sub(1, max_chars - 3) .. "..."
end

local function to_int(v)
    if v == nil then return nil end
    if type(v) == "number" then return math.tointeger(v) or v end
    local n = tonumber(v)
    if n then return math.tointeger(n) or n end
    local ok, s = pcall(tostring, v)
    if ok then n = tonumber(s); if n then return math.tointeger(n) or n end end
    return nil
end

-- ── Type cache ────────────────────────────────────────────────────────────

local _type_cache = {}

local function get_rt(type_name)
    if not _type_cache[type_name] then
        _type_cache[type_name] = sdk.typeof(type_name)
    end
    return _type_cache[type_name]
end

local function get_component(go, type_name)
    if not go then return nil end
    local rt = get_rt(type_name)
    if not rt then return nil end
    local ok, c = pcall(go.call, go, "getComponent(System.Type)", rt)
    return ok and c or nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GUID Extraction
-- ═══════════════════════════════════════════════════════════════════════════

-- Stable GUID from GameObject.ToString(), pattern "Name@guid]"
local function extract_guid(go)
    if not go then return nil end
    local ok, ts = pcall(go.call, go, "ToString()")
    if ok and ts then
        local guid = tostring(ts):match("@([%x%-]+)%]$")
        if guid and guid ~= "" then return guid end
    end
    return nil
end

-- Stable spawn-entry GUID from EnemyController.get_ContextGUID
local function extract_context_guid(comp)
    if not comp then return nil end
    local ok, cg = pcall(comp.call, comp, "get_ContextGUID")
    if not ok or cg == nil then return nil end
    local ok2, ts = pcall(cg.call, cg, "ToString()")
    if ok2 and ts then
        local s = tostring(ts)
        if s ~= "" and s ~= "nil" then return s end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Access
-- ═══════════════════════════════════════════════════════════════════════════

local function get_player_go()
    local go = nil
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        -- RE3R: get_CurrentPlayer returns PlayerCondition (a Component with get_GameObject)
        local pc = pm:call("get_CurrentPlayer")
        if pc then
            go = pc:call("get_GameObject")
        end
    end)
    return go
end

local function update_player_pos()
    local updated = false
    -- Primary: PlayerManager.get_CurrentPosition (proven working in RE3R)
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        local pos = pm:call("get_CurrentPosition")
        if pos then
            state.player_pos = { x = pos.x, y = pos.y, z = pos.z }
            updated = true
        end
    end)
    -- Fallback: player GameObject → Transform
    if not updated then
        pcall(function()
            local go = get_player_go()
            if not go then return end
            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if pos then
                state.player_pos = { x = pos.x, y = pos.y, z = pos.z }
                updated = true
            end
        end)
    end
    -- Fallback: camera
    if not updated then
        pcall(function()
            local cam = sdk.get_primary_camera()
            if not cam then return end
            local go = cam:call("get_GameObject")
            if not go then return end
            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if pos then state.player_pos = { x = pos.x, y = pos.y, z = pos.z } end
        end)
    end
end

local function quat_yaw(q)
    if not q then return nil end
    local siny = 2.0 * (q.w * q.y - q.z * q.x)
    siny = math.max(-1.0, math.min(1.0, siny))
    return math.deg(math.asin(siny))
end

local function update_camera_rotation()
    pcall(function()
        local scene = get_scene()
        if not scene then return end
        local mv = scene:call("get_MainView")
        if not mv then return end
        local cam = mv:call("get_PrimaryCamera")
        if not cam then return end
        local go = cam:call("get_GameObject")
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local q = xf:call("get_Rotation")
        if q then state.dev_rotation = quat_yaw(q) end
    end)
end

local function get_enemy_hp(go)
    local hpc = get_component(go, "offline.HitPointController")
    if not hpc then return nil end
    local hp = nil
    pcall(function() hp = hpc:get_field("CurrentHitPoint") end)
    if hp == nil then pcall(function() hp = hpc:call("get_CurrentHitPoint") end) end
    return hp
end

local function update_player_hp()
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local hp = get_enemy_hp(go)
        if hp then state.player_hp = hp end
    end)
end

-- ── Game-state scanning ───────────────────────────────────────────────────

local function read_named_int(obj, names)
    if not obj then return nil end
    for _, name in ipairs(names) do
        local ok, v = pcall(obj.call, obj, name)
        local n = ok and to_int(v) or nil
        if n ~= nil then return n end
    end
    for _, name in ipairs(names) do
        local ok, v = pcall(obj.get_field, obj, name)
        local n = ok and to_int(v) or nil
        if n ~= nil then return n end
    end
    return nil
end

local function scan_game_state()
    -- Scene name
    pcall(function()
        local scene = get_scene()
        if not scene then return end
        local name = nil
        pcall(function() name = tostring(scene:call("get_Name") or "") end)
        if not name or name == "" or name == "nil" then
            local s = tostring(scene)
            name = s:match("%[(.-)@") or s:match("Scene%[(.-)%]") or ""
        end
        if name and name ~= "" and name ~= "nil" then state.dev.scene = name end
    end)

    -- MapID via EnemyManager (confirmed working path)
    local map_id = nil
    pcall(function()
        local em = sdk.get_managed_singleton("offline.EnemyManager")
        if not em then return end
        map_id = read_named_int(em, {
            "<LastPlayerStaySceneID>k__BackingField",
            "LastPlayerStaySceneID",
            "<LastPlayerStayMapID>k__BackingField",
            "LastPlayerStayMapID",
        })
    end)
    if map_id and map_id ~= state.dev.map_id then
        state.dev.map_id = map_id
        state.applied_placements = {}
    end

    -- Rank
    pcall(function()
        local rm = sdk.get_managed_singleton("offline.GameRankManager")
        if not rm then return end
        local rank = nil
        pcall(function() rank = rm:call("getCurrentRank") end)
        if not rank then pcall(function() rank = rm:get_field("_Rank") end) end
        if rank ~= nil then state.dev.rank = rank end
    end)

    -- Player name
    pcall(function()
        local go = get_player_go()
        if not go then return end
        local n = ""
        pcall(function() n = tostring(go:call("get_Name") or "") end)
        if n:find("pl0000") or n:find("Jill") then state.dev.player_name = "Jill"
        elseif n:find("pl2000") or n:find("Carlos") then state.dev.player_name = "Carlos"
        elseif n ~= "" then state.dev.player_name = n end
    end)

    -- Player state
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        local st = nil
        pcall(function() st = pm:call("get_GamePlayerState") end)
        if not st then pcall(function() st = pm:get_field("_PlayerState") end) end
        if st ~= nil then state.dev.player_state = tostring(st) end
    end)

    -- Playtime
    pcall(function()
        local sm = sdk.get_managed_singleton("offline.SceneManager")
        if sm then pcall(function() state.dev.playtime = sm:call("get_PlayTime") end) end
        if not state.dev.playtime then
            local gm = sdk.get_managed_singleton("offline.GameProgressManager")
            if gm then pcall(function() state.dev.playtime = gm:call("get_PlayTime") end) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BT State Helper (used by scenarios and spawn groups)
-- ═══════════════════════════════════════════════════════════════════════════

local function get_bt_state(go)
    if not go then return nil end
    local bt_rt = get_rt("via.behaviortree.BehaviorTree")
    if not bt_rt then return nil end
    local bt = nil
    pcall(function() bt = go:call("getComponent(System.Type)", bt_rt) end)
    if not bt then return nil end
    local s = nil
    pcall(function() s = bt:call("getCurrentNodeName", 0) end)
    if s == nil then return nil end
    local text = tostring(s)
    if text == "" or text == "nil" then return nil end
    return text
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Scanning (ScenarioController list from SSM)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_scenarios()
    local results = {}
    local now = os.clock()

    pcall(function()
        local scene = get_scene()
        local scene_addr = 0
        pcall(function() scene_addr = scene and scene:get_address() or 0 end)
        if state.scenario_scene_address ~= scene_addr then
            state.scenario_scene_address = scene_addr
            state.scenario_state_history = {}
        end

        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end

        local ctrl_list = nil
        pcall(function() ctrl_list = ssm:get_field("_ScenarioControllerList") end)
        if not ctrl_list then return end

        local n = 0
        pcall(function() n = ctrl_list:call("get_Count") or 0 end)

        for i = 0, n - 1 do
            pcall(function()
                local ctrl = ctrl_list:call("get_Item", i)
                if not ctrl then return end

                local go = ctrl:call("get_GameObject")
                if not go then return end

                local go_name = tostring(go:call("get_Name") or "?")
                local is_advance = false
                local scenario_no = nil
                pcall(function() is_advance = ctrl:get_field("IsAdvanceNo") == true end)
                pcall(function() scenario_no = to_int(ctrl:get_field("ScenarioNo")) end)

                local bt_state = get_bt_state(go)
                local addr = 0
                pcall(function() addr = go:get_address() end)

                local prev = state.scenario_state_history[addr]
                local changed_at = prev and prev.changed_at or 0
                if prev and prev.bt_state ~= bt_state then
                    changed_at = now
                end
                state.scenario_state_history[addr] = { bt_state = bt_state, changed_at = changed_at }

                results[#results + 1] = {
                    go_name    = go_name,
                    bt_state   = bt_state or "-",
                    is_advance = is_advance,
                    scenario_no = scenario_no,
                    changed_at = changed_at,
                }
            end)
        end
    end)

    state.scenarios = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- findComponents Helper
-- ═══════════════════════════════════════════════════════════════════════════

local function find_comps(type_name)
    local scene = get_scene()
    if not scene then return nil, 0 end
    local td = sdk.find_type_definition(type_name)
    if not td then return nil, 0 end
    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", td:get_runtime_type()) end)
    if not comps then return nil, 0 end
    local ok, n = pcall(comps.call, comps, "get_Count")
    return comps, (ok and n) or 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Context Type (em0000.Em0000 format from the Context component)
-- ═══════════════════════════════════════════════════════════════════════════

local _ESCAPE_PFX = "offline.escape.enemy."
local _ENEMY_PFX  = "offline.enemy."
local _CTX_SFX    = "Context"

local function get_enemy_context_type(go)
    if not go then return nil end
    local result = nil
    pcall(function()
        local comps = go:call("get_Components")
        if not comps then return end
        local n = 0
        pcall(function() n = comps:call("get_Count") end)
        for i = 0, n - 1 do
            if result then break end
            pcall(function()
                local c = comps:call("get_Item", i)
                if not c then return end
                local td = c:get_type_definition()
                if not td then return end
                local fname = td:get_full_name() or ""
                local s, matched = fname, false
                if fname:sub(1, #_ESCAPE_PFX) == _ESCAPE_PFX then
                    s = fname:sub(#_ESCAPE_PFX + 1); matched = true
                elseif fname:sub(1, #_ENEMY_PFX) == _ENEMY_PFX then
                    s = fname:sub(#_ENEMY_PFX + 1); matched = true
                end
                if matched and s:sub(-#_CTX_SFX) == _CTX_SFX then
                    result = s:sub(1, -(#_CTX_SFX + 1))
                end
            end)
        end
    end)
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Scanning (EnemyController)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_enemies()
    local comps, n = find_comps("offline.EnemyController")
    if not comps or n <= 0 then state.enemies = {}; return end
    local results = {}
    local seen = {}
    for i = 0, math.min(n - 1, 150) do
        pcall(function()
            local comp = comps:call("get_Item", i)
            if not comp then return end
            local addr = comp:get_address()
            if seen[addr] then return end
            seen[addr] = true

            local go = comp:call("get_GameObject")
            if not go then return end

            local xf = go:call("get_Transform")
            if not xf then return end
            local pos = xf:call("get_Position")
            if not pos then return end

            local go_name = tostring(go:call("get_Name") or "?")
            local go_guid = extract_guid(go)
            local context_guid = extract_context_guid(comp)

            local kind_id = nil
            pcall(function() kind_id = to_int(comp:call("get_KindID")) end)
            local map_id = nil
            pcall(function() map_id = to_int(comp:call("get_AssignMapID")) end)

            local hp = get_enemy_hp(go)
            local dead = hp ~= nil and hp <= 0

            local bt_state = get_bt_state(go)

            local rot = nil
            pcall(function()
                local q = xf:call("get_Rotation")
                if q then rot = { x = q.x, y = q.y, z = q.z } end
            end)

            local enemy_type = get_enemy_context_type(go)

            local d = dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos)

            results[#results + 1] = {
                go_name      = go_name,
                go_guid      = go_guid,
                context_guid = context_guid,
                guid         = context_guid or go_guid,
                kind_id      = kind_id,
                kind_name    = kind_name(kind_id),
                map_id       = map_id,
                hp           = hp,
                dead         = dead,
                bt_state     = bt_state,
                pos          = { x = pos.x, y = pos.y, z = pos.z },
                rot          = rot,
                enemy_type   = enemy_type,
                dist         = d,
                _go_ref      = go,
            }
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.enemies = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawn Group Scanning (EnemySpawnController)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_spawn_groups()
    local scene = get_scene()
    local scene_addr = 0
    pcall(function() scene_addr = scene and scene:get_address() or 0 end)
    if state.spawn_scene_address ~= scene_addr then
        state.spawn_scene_address = scene_addr
    end

    local comps, n = find_comps("offline.EnemySpawnController")
    if not comps or n <= 0 then state.spawn_groups = {}; return end

    local results = {}
    local seen = {}
    for i = 0, n - 1 do
        pcall(function()
            local esc = comps:call("get_Item", i)
            if not esc then return end
            local addr = esc:get_address()
            if seen[addr] then return end
            seen[addr] = true

            local go = esc:call("get_GameObject")
            if not go then return end

            local go_name = tostring(go:call("get_Name") or "?")
            local go_guid = extract_guid(go)

            local is_spawned = false
            local is_vanished = false
            local all_dead = false
            local enabled_difficulty = false
            local enabled_map = false
            local init_difficulty = nil

            pcall(function() is_spawned      = esc:call("get_IsSpawned") == true end)
            pcall(function() is_vanished     = esc:call("get_IsVanished") == true end)
            pcall(function() all_dead        = esc:call("get_AllDead") == true end)
            pcall(function() enabled_difficulty = esc:call("get_EnabledDifficulty") == true end)
            pcall(function() enabled_map     = esc:call("get_EnabledMapID") == true end)
            pcall(function() init_difficulty = to_int(esc:get_field("InitializeSetDifficulty")) end)

            local pos = nil
            pcall(function()
                local xf = go:call("get_Transform")
                if xf then pos = xf:call("get_Position") end
            end)

            local d = pos and dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos) or 0
            local bt_state = get_bt_state(go)

            results[#results + 1] = {
                go_name          = go_name,
                go_guid          = go_guid,
                is_spawned       = is_spawned,
                is_vanished      = is_vanished,
                all_dead         = all_dead,
                enabled_difficulty = enabled_difficulty,
                enabled_map      = enabled_map,
                init_difficulty  = init_difficulty,
                bt_state         = bt_state,
                pos              = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
                dist             = d,
                _go_ref          = go,
            }
        end)
    end

    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.spawn_groups = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Scanning (SetItem + HandHeldItem)
-- ═══════════════════════════════════════════════════════════════════════════

local ITEM_TYPES = {
    "offline.gimmick.action.SetItem",
    "offline.HandHeldItem",
}

local function scan_items()
    local results = {}
    local seen = {}
    for _, type_name in ipairs(ITEM_TYPES) do
        pcall(function()
            local comps, n = find_comps(type_name)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n - 1, 150) do
                pcall(function()
                    local comp = comps:call("get_Item", i)
                    if not comp then return end
                    local addr = comp:get_address()
                    if seen[addr] then return end
                    seen[addr] = true

                    local go = comp:call("get_GameObject")
                    if not go then return end
                    local xf = go:call("get_Transform")
                    if not xf then return end
                    local pos = xf:call("get_Position")
                    if not pos then return end

                    local go_name = tostring(go:call("get_Name") or "?")
                    local go_guid = extract_guid(go)

                    local bullet_id   = nil
                    local add_item_id = nil
                    local add_wpn_id  = nil
                    local pos_guid    = nil

                    pcall(function() bullet_id   = to_int(comp:get_field("BulletId")) end)
                    pcall(function() add_item_id = to_int(comp:get_field("AdditionalItemId")) end)
                    pcall(function() add_wpn_id  = to_int(comp:get_field("AdditionalWeaponId")) end)
                    pcall(function()
                        local pg = comp:get_field("ItemPositionGuid")
                        if pg then
                            local ok, ts = pcall(pg.call, pg, "ToString()")
                            if ok and ts then pos_guid = tostring(ts) end
                        end
                    end)

                    local d = dist3({ x = pos.x, y = pos.y, z = pos.z }, state.player_pos)

                    results[#results + 1] = {
                        go_name      = go_name,
                        go_guid      = go_guid,
                        bullet_id    = bullet_id,
                        add_item_id  = add_item_id,
                        add_wpn_id   = add_wpn_id,
                        pos_guid     = pos_guid,
                        pos          = { x = pos.x, y = pos.y, z = pos.z },
                        dist         = d,
                        type_name    = type_name,
                        _go_ref      = go,
                    }
                end)
            end
        end)
    end
    table.sort(results, function(a, b) return a.dist < b.dist end)
    state.items = results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- All-Objects Scanning (via.Transform = one per GO)
-- ═══════════════════════════════════════════════════════════════════════════

local _KNOWN_COMP_TYPES = nil
local function get_known_comp_types()
    if _KNOWN_COMP_TYPES then return _KNOWN_COMP_TYPES end
    local defs = {
        { tag = "Enemy",    type = "offline.EnemyController"          },
        { tag = "Spawn",    type = "offline.EnemySpawnController"     },
        { tag = "Item",     type = "offline.gimmick.action.SetItem"   },
        { tag = "Scenario", type = "offline.ScenarioController"       },
        { tag = "HP",       type = "offline.HitPointController"       },
        { tag = "Motion",   type = "via.motion.Motion"                },
    }
    for _, d in ipairs(defs) do
        local td = sdk.find_type_definition(d.type)
        d.rt = td and td:get_runtime_type()
    end
    _KNOWN_COMP_TYPES = defs
    return defs
end

local _xf_rt = nil
local function get_xf_rt()
    if not _xf_rt then
        local td = sdk.find_type_definition("via.Transform")
        _xf_rt = td and td:get_runtime_type()
    end
    return _xf_rt
end

local _obj_filter           = ""   -- filter for Objects tab table
local _go_inspector_filter  = ""   -- filter for GO inspector field names

local function scan_all_objects()
    local scene = get_scene()
    if not scene then state.objects = {}; return end
    local rt = get_xf_rt()
    if not rt then state.objects = {}; return end

    local all = nil
    pcall(function() all = scene:call("findComponents(System.Type)", rt) end)
    if not all then state.objects = {}; return end
    local total = all:call("get_Count") or 0

    local known = get_known_comp_types()
    local results = {}
    
    local closest = {} -- sorted array of { xf=xf, d=d }, size <= 300
    local max_dist = 999999
    local limit = 300

    -- First pass: find the 300 closest transforms in an extremely memory-efficient way
    for i = 0, total - 1 do
        pcall(function()
            local xf  = all:call("get_Item", i)
            if not xf then return end
            local pos = xf:call("get_Position")
            local d   = pos and dist3({ x=pos.x, y=pos.y, z=pos.z }, state.player_pos) or 999999
            
            -- Memory gate: if we already have 300 and this is further, discard immediately
            if #closest >= limit and d >= max_dist then
                return
            end
            
            -- Insert into sorted list
            local ins_idx = 1
            for j = #closest, 1, -1 do
                if d >= closest[j].d then
                    ins_idx = j + 1
                    break
                end
            end
            
            table.insert(closest, ins_idx, { xf=xf, d=d })
            
            -- Keep bounded
            if #closest > limit then
                table.remove(closest)
            end
            max_dist = closest[#closest].d
        end)
    end

    -- Second pass: only fetch name, GUID, tags, and _go_ref for the 300 closest transforms!
    for i = 1, #closest do
        pcall(function()
            local r   = closest[i]
            local xf  = r.xf
            local go  = xf:call("get_GameObject")
            if not go then return end
            
            local name = tostring(go:call("get_Name") or "")
            local guid = extract_guid(go)
            local active = false
            pcall(function() active = go:call("get_ActiveSelf") == true end)
            local pos  = xf:call("get_Position")

            local tags = {}
            for _, k in ipairs(known) do
                if k.rt then
                    local c = nil
                    pcall(function() c = go:call("getComponent(System.Type)", k.rt) end)
                    if c then tags[#tags+1] = k.tag end
                end
            end

            results[#results+1] = {
                go_name = name,
                go_guid = guid,
                active  = active,
                pos     = pos and { x=pos.x, y=pos.y, z=pos.z } or nil,
                dist    = r.d,
                tags    = tags,
                _go_ref = go,
            }

            -- Auto-restore saved or hardcoded placements
            pcall(function()
                local addr = go:get_address()
                if addr and not state.applied_placements[addr] then
                    local current_map = state.dev.map_id
                    local match = find_placement_entry(name, guid, current_map)
                    if match then
                        state.applied_placements[addr] = true
                        defer(function()
                            if match.pos then
                                apply_position(xf, match.pos.x, match.pos.y, match.pos.z, go)
                            end
                            if match.rot then
                                apply_local_euler(xf, match.rot.x, match.rot.y, match.rot.z, go)
                            end
                            if match.scale then
                                apply_local_scale(xf, match.scale.x, match.scale.y, match.scale.z, go)
                            end
                            log.info("[RE3R Trainer] Restored placement for " .. tostring(name))
                        end)
                    end
                end
            end)
        end)
    end
    state.objects = results

    -- Force Lua garbage collection step to immediately free discarded C++ wrappers and tables
    pcall(function() collectgarbage("step", 100) end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scenario Progress (RE3R level-flow equivalent via SSM)
-- ═══════════════════════════════════════════════════════════════════════════

-- _prog_entries: sorted list of { name, value=scenario_no, bt_state,
--                                  is_cur, is_done, is_adv, go_name, changed_at }
local _prog_entries          = {}
local _catalog_found         = false   -- true when SSM accessible
local _current_scenario_no   = nil     -- SSM._CurrentScenarioNo

local rebuild_prog_entries  -- forward declaration

-- Full scan: read SSM directly + resolve all controller data
local function scan_levelflow_catalog()
    _catalog_found = false
    pcall(function()
        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end
        _catalog_found = true

        local cn = nil
        pcall(function() cn = to_int(ssm:get_field("_CurrentScenarioNo")) end)
        if cn ~= nil then _current_scenario_no = cn end

        -- collect all controllers with a valid ScenarioNo
        local cl = ssm:get_field("_ScenarioControllerList")
        if not cl then return end
        local n = 0; pcall(function() n = cl:call("get_Count") or 0 end)

        local entries = {}
        for i = 0, n - 1 do
            pcall(function()
                local ctrl = cl:call("get_Item", i)
                if not ctrl then return end
                local sno = nil
                pcall(function() sno = to_int(ctrl:get_field("ScenarioNo")) end)
                if not sno or sno < 0 then return end

                local adv = false
                pcall(function() adv = ctrl:get_field("IsAdvanceNo") == true end)

                local go = ctrl:call("get_GameObject")
                local bt = get_bt_state(go) or "-"
                local go_name = ""
                pcall(function() go_name = tostring(go:call("get_Name") or "") end)

                local s_name = SCENARIO_NAMES[sno] or string.format("S??_%04d", sno)
                local is_done = bt:lower():find("suicide") ~= nil

                entries[#entries + 1] = {
                    name       = s_name,
                    value      = sno,
                    bt_state   = bt,
                    is_cur     = sno == _current_scenario_no,
                    is_done    = is_done,
                    is_adv     = adv,
                    go_name    = go_name,
                    changed_at = 0,
                }
            end)
        end
        table.sort(entries, function(a, b) return (a.value or 0) < (b.value or 0) end)
        _prog_entries = entries
    end)
end

-- Fast refresh: update BT states + current scenario from already-scanned state.scenarios
local function scan_levelflow_values()
    -- Update current scenario no from SSM (cheap)
    pcall(function()
        local ssm = sdk.get_managed_singleton("offline.gamemastering.ScenarioSequenceManager")
        if not ssm then return end
        local cn = nil
        pcall(function() cn = to_int(ssm:get_field("_CurrentScenarioNo")) end)
        if cn ~= nil then _current_scenario_no = cn end
    end)
    rebuild_prog_entries()
end

-- Rebuild _prog_entries from the already-populated state.scenarios (fast path)
rebuild_prog_entries = function()
    if not _catalog_found then return end
    local entries = {}
    for _, sc in ipairs(state.scenarios) do
        if sc.scenario_no and sc.scenario_no >= 0 then
            local s_name  = SCENARIO_NAMES[sc.scenario_no] or string.format("S??_%04d", sc.scenario_no)
            local bt      = sc.bt_state or "-"
            local is_done = bt:lower():find("suicide") ~= nil
            entries[#entries + 1] = {
                name       = s_name,
                value      = sc.scenario_no,
                bt_state   = bt,
                is_cur     = sc.scenario_no == _current_scenario_no,
                is_done    = is_done,
                is_adv     = sc.is_advance,
                go_name    = sc.go_name,
                changed_at = sc.changed_at,
            }
        end
    end
    table.sort(entries, function(a, b) return (a.value or 0) < (b.value or 0) end)
    _prog_entries = entries
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Overlay Fonts
-- ═══════════════════════════════════════════════════════════════════════════

local _overlay_font_regular = nil
local _overlay_font_bold    = nil

local function get_overlay_font(bold)
    if not d2d then return nil end
    if bold then
        if not _overlay_font_bold then
            pcall(function() _overlay_font_bold = d2d.Font.new("Consolas", 18, true) end)
        end
        return _overlay_font_bold
    end
    if not _overlay_font_regular then
        pcall(function() _overlay_font_regular = d2d.Font.new("Consolas", 18, false) end)
    end
    return _overlay_font_regular
end

local function reset_overlay_fonts()
    _overlay_font_regular = nil
    _overlay_font_bold    = nil
end

-- ── ESP fonts (configurable size) ─────────────────────────────────────────

local _esp_fonts = {}

local function get_esp_font(sz, bold)
    local key = tostring(sz) .. (bold and "B" or "R")
    if not _esp_fonts[key] then
        pcall(function() _esp_fonts[key] = d2d.Font.new("Consolas", sz, bold or false) end)
    end
    return _esp_fonts[key]
end

local function reset_esp_fonts()
    _esp_fonts = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- D2D Draw Helpers
-- ═══════════════════════════════════════════════════════════════════════════

local function d2d_text(font, text, x, y, col)
    if d2d and font then
        pcall(d2d.text, font, text, x + 1, y + 1, 0xCC000000)
        pcall(d2d.text, font, text, x, y, col)
    elseif draw then
        pcall(draw.text, text, x + 1, y + 1, 0xCC000000)
        pcall(draw.text, text, x, y, col)
    end
end

local function d2d_fill_rect(x, y, w, h, col)
    if d2d then
        pcall(d2d.fill_rect, x, y, w, h, col)
    elseif draw then
        pcall(draw.filled_rect, x, y, w, h, col)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- World-to-Screen
-- ═══════════════════════════════════════════════════════════════════════════

local _has_w2s = (draw ~= nil) and (draw.world_to_screen ~= nil)

local function world_to_screen(pos, y_off)
    if not _has_w2s or not pos then return nil end
    local ok, sp = pcall(draw.world_to_screen,
        Vector3f.new(pos.x, pos.y + (y_off or 0), pos.z))
    if not ok or not sp then return nil end
    if sp.x ~= sp.x or sp.y ~= sp.y then return nil end
    return sp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dev Overlay (top-left panel)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_dev_overlay()
    if not cfg.show_dev_overlay then return end

    local LH      = 20
    local PAD     = 14   -- matches spawn overlay padding
    local VX      = 92   -- value column offset from content left
    local PANEL_W = 420
    local DIV_H   = 9
    local TITLE_H = LH + 4

    local lime   = 0xFF44FF88
    local cyan   = 0xFF88DDFF
    local yellow = 0xFFFFCC44
    local grey   = 0xFF888888
    local white  = 0xFFFFFFFF
    local dkgrey = 0xFF888888

    local hf = get_overlay_font(true)
    local vf = get_overlay_font(false)

    -- Row builders (div() skips consecutive dividers and leading/trailing ones)
    local rows = {}
    local function kv(label, value, val_col)
        local vs = tostring(value ~= nil and value or "")
        if vs == "" or vs == "nil" then return end
        rows[#rows+1] = { t="kv", label=label, value=vs, vcol=val_col or white }
    end
    local function div()
        if #rows > 0 and rows[#rows].t ~= "div" then
            rows[#rows+1] = { t="div" }
        end
    end

    -- ── Section 1: Player ────────────────────────────────────────────────────
    if state.dev.player_name ~= "" then
        kv("Player", state.dev.player_name, cyan)
    end
    if state.player_hp and state.player_hp > 0 then
        local hp  = state.player_hp
        local hpc = hp > 500 and 0xFF44FF88 or (hp > 200 and 0xFFFFAA44 or 0xFFFF5555)
        kv("HP", math.floor(hp), hpc)
    end
    if state.dev.player_state ~= "" then
        kv("State", state.dev.player_state, 0xFFAABBCC)
    end

    -- ── Section 2: World ─────────────────────────────────────────────────────
    div()
    if state.dev.scene ~= "" then kv("Scene", state.dev.scene, yellow) end
    kv("Map ID", map_id_str(state.dev.map_id), white)
    if state.dev.rank ~= nil then kv("Rank", state.dev.rank, cyan) end
    if state.dev.playtime and state.dev.playtime > 0 then
        local t = math.floor(state.dev.playtime)
        kv("Time", string.format("%d:%02d", t // 60, t % 60), white)
    end

    -- ── Section 3: Transform ─────────────────────────────────────────────────
    div()
    local pos = state.player_pos
    if pos then
        kv("X", string.format("%.3f", pos.x), white)
        kv("Y", string.format("%.3f", pos.y), white)
        kv("Z", string.format("%.3f", pos.z), white)
    else
        kv("Pos", "(unavailable)", dkgrey)
    end
    if state.dev_rotation then
        kv("Yaw", string.format("%.1f\xC2\xB0", state.dev_rotation), white)
    end

    -- ── Section 4: Counts ────────────────────────────────────────────────────
    div()
    kv("Enemies", #state.enemies, white)
    kv("Items",   #state.items,   white)
    kv("Spawns",  #state.spawn_groups, white)

    -- ── Status flash ─────────────────────────────────────────────────────────
    if state.status_msg ~= "" and state.tick < state.status_until then
        div()
        kv(">>", state.status_msg, lime)
    end

    -- Remove trailing divider
    if #rows > 0 and rows[#rows].t == "div" then rows[#rows] = nil end

    -- Calculate panel height
    local total_h = 6 + TITLE_H
    for _, r in ipairs(rows) do
        total_h = total_h + (r.t == "div" and DIV_H or LH)
    end
    total_h = total_h + PAD

    local x = 30   -- matches spawn overlay left margin
    local y = 80   -- matches spawn overlay top margin

    -- Background + 4 px left accent bar
    d2d_fill_rect(x, y, PANEL_W, total_h, 0xCC000000)
    d2d_fill_rect(x, y, 4, total_h, lime)

    -- Content origin (matches spawn overlay: x + PAD)
    local cx = x + PAD
    local ty = y + 6   -- matches spawn overlay title offset

    -- Title
    d2d_text(hf, "BIORAND RE3R", cx, ty, lime)
    ty = ty + TITLE_H

    for _, r in ipairs(rows) do
        if r.t == "div" then
            d2d_fill_rect(cx, ty + DIV_H // 2, PANEL_W - PAD * 2, 1, 0xFF2A2A2A)
            ty = ty + DIV_H
        else
            d2d_text(vf, r.label,        cx,      ty, grey)
            d2d_text(vf, r.value,        cx + VX, ty, r.vcol)
            ty = ty + LH
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Spawn Overlay (top-right panel)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_spawn_overlay()
    if not cfg.show_spawn_overlay then return end

    local entries = state.spawn_groups
    if not entries or #entries == 0 then return end

    local visible = math.min(#entries, SPAWN_OVERLAY_LIMIT)

    local spawned_count, vanished_count, dead_count = 0, 0, 0
    for _, e in ipairs(entries) do
        if e.is_spawned  then spawned_count  = spawned_count  + 1 end
        if e.is_vanished then vanished_count = vanished_count + 1 end
        if e.all_dead    then dead_count     = dead_count     + 1 end
    end

    -- Fixed pixel column offsets (relative to panel content left = x + PAD)
    -- Name col needs ~260px for 31-char names at ~8px/char in draw font
    local PAD   = 14
    local CX    = { dist=0, name=42, sp=308, va=340, dd=372, df=404, state=436 }
    local PANEL_W = 700
    local LH    = 20  -- row height in px

    local lime  = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey  = 0xFF888888
    local hf    = get_overlay_font(true)
    local vf    = get_overlay_font(false)

    -- Build rows
    local rows = {}
    for i = 1, visible do
        local e = entries[i]
        local col
        if e.all_dead        then col = 0xFFFF5555
        elseif e.is_vanished then col = 0xFFCC88FF
        elseif e.is_spawned  then col = 0xFF44FF88
        else                      col = 0xFFFFFFFF end
        rows[#rows + 1] = {
            dist  = string.format("%dm", math.floor(e.dist + 0.5)),
            name  = clamp_text(e.go_name, SPAWN_NAME_MAX_CHARS),
            sp    = e.is_spawned        and "Y" or "N",
            va    = e.is_vanished       and "Y" or "N",
            dd    = e.all_dead          and "Y" or "N",
            df    = e.enabled_difficulty and "Y" or "N",
            state = e.bt_state or "-",
            col   = col,
        }
    end

    -- Panel geometry
    local header_h = LH * 3 + 10  -- title + summary + col header
    local height   = header_h + (#rows * LH) + 12
    local x, y    = 30, 80

    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
        if sz.h and (y + height + 30) > sz.h then
            y = math.max(30, sz.h - height - 30)
        end
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, lime)

    -- Title
    local cy = y + 6
    d2d_text(hf, "Enemy Spawns", x + PAD, cy, lime)
    cy = cy + LH

    -- Summary
    local summary = string.format(
        "total:%d  spawned:%d  vanished:%d  dead:%d",
        #entries, spawned_count, vanished_count, dead_count)
    d2d_text(vf, summary, x + PAD, cy, grey)
    cy = cy + LH

    -- Column headers
    local cx = x + PAD
    d2d_text(vf, "Dist",  cx + CX.dist,  cy, grey)
    d2d_text(vf, "Name",  cx + CX.name,  cy, grey)
    d2d_text(vf, "Sp",    cx + CX.sp,    cy, grey)
    d2d_text(vf, "Va",    cx + CX.va,    cy, grey)
    d2d_text(vf, "Dd",    cx + CX.dd,    cy, grey)
    d2d_text(vf, "Df",    cx + CX.df,    cy, grey)
    d2d_text(vf, "State", cx + CX.state, cy, grey)
    cy = cy + LH + 2

    -- Data rows
    for _, row in ipairs(rows) do
        local c = row.col
        d2d_text(vf, row.dist,  cx + CX.dist,  cy, grey)
        d2d_text(vf, row.name,  cx + CX.name,  cy, c)
        d2d_text(vf, row.sp,    cx + CX.sp,    cy, c)
        d2d_text(vf, row.va,    cx + CX.va,    cy, c)
        d2d_text(vf, row.dd,    cx + CX.dd,    cy, c)
        d2d_text(vf, row.df,    cx + CX.df,    cy, c)
        d2d_text(vf, row.state, cx + CX.state, cy, c)
        cy = cy + LH
    end

    return height + 10  -- consumed height for stacking the levelflow overlay below
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlow Overlay (right side, below spawn overlay)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_levelflow_overlay(offset_y)
    if not cfg.show_levelflow_overlay then return end

    local items = state.scenarios
    if not items or #items == 0 then return end

    local now = os.clock()

    -- Fixed pixel column offsets
    -- Name col needs ~265px for 32-char names at ~8px/char in draw font
    local PAD      = 14
    local CX_NAME  = 0
    local CX_STATE = 270
    local PANEL_W  = 520
    local LH      = 20

    local lime  = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey  = 0xFF888888
    local hf    = get_overlay_font(true)
    local vf    = get_overlay_font(false)

    local height = LH * 2 + 10 + (#items * LH)
    local x, y  = 30, 80 + (offset_y or 0)

    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, lime)

    local cy = y + 6
    d2d_text(hf, "Active Scenarios", x + PAD, cy, lime)
    cy = cy + LH

    -- Column headers
    local cx = x + PAD
    d2d_text(vf, "Name",  cx + CX_NAME,  cy, grey)
    d2d_text(vf, "State", cx + CX_STATE, cy, grey)
    cy = cy + LH + 2

    for _, item in ipairs(items) do
        local changed_recently = item.changed_at > 0 and
            ((now - item.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
        local col = changed_recently and lime or white
        local display_name = (item.scenario_no and item.scenario_no >= 0 and SCENARIO_NAMES[item.scenario_no])
            or item.go_name
        d2d_text(vf, clamp_text(display_name, LEVELFLOW_NAME_MAX_CHARS), cx + CX_NAME,  cy, col)
        d2d_text(vf, tostring(item.bt_state or "-"),                      cx + CX_STATE, cy, col)
        cy = cy + LH
    end

    return height + 10  -- consumed height for stacking below
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlow Catalog Overlay (right side, below other right-side overlays)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_levelflow_catalog_overlay(offset_y)
    if not cfg.show_levelflow_catalog_overlay then return end
    if not _catalog_found then return end

    local PAD     = 14
    local CX_BT   = 220   -- bt_state column offset from content left
    local PANEL_W = 420
    local LH      = 20

    local cyan   = 0xFF44EEFF
    local grey   = 0xFF888888
    local lime   = 0xFF44FF88
    local white  = 0xFFFFFFFF
    local dkgrey = 0xFF444444
    local yellow = 0xFFFFDD44

    local hf = get_overlay_font(true)
    local vf = get_overlay_font(false)

    local visible = math.min(#_prog_entries, 20)
    local height  = LH * 2 + 10 + (visible * LH) + 8

    local x, y = 30, 80 + (offset_y or 0)
    local sz = get_window_size()
    if sz and sz.w then
        x = math.max(30, sz.w - PANEL_W - 30)
    end

    d2d_fill_rect(x, y, PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, cyan)

    local cy = y + 6
    local cx = x + PAD

    -- Title + current scenario on same line
    local cur_label = _current_scenario_no ~= nil
        and (SCENARIO_NAMES[_current_scenario_no] or string.format("S??_%04d", _current_scenario_no))
        or "?"
    d2d_text(hf, "Scenario Progress", cx, cy, cyan)
    d2d_text(hf, cur_label, cx + CX_BT, cy, yellow)
    cy = cy + LH

    -- Column headers
    d2d_text(vf, "Scenario",   cx,          cy, grey)
    d2d_text(vf, "BT State",   cx + CX_BT,  cy, grey)
    cy = cy + LH + 2

    for i = 1, visible do
        local e = _prog_entries[i]

        local name_col, bt_col
        local prefix = "  "

        if e.is_cur then
            name_col = lime
            bt_col   = lime
            prefix   = "> "
        elseif e.is_done then
            name_col = dkgrey
            bt_col   = dkgrey
        else
            name_col = white
            bt_col   = grey
        end

        local bt_short = e.bt_state or "-"
        -- Shorten long BT state names for readability
        bt_short = bt_short:gsub("^app%.levelflow%.", "")

        d2d_text(vf, prefix .. clamp_text(e.name or "?", 26), cx,         cy, name_col)
        d2d_text(vf, clamp_text(bt_short, 18),                cx + CX_BT, cy, bt_col)
        cy = cy + LH
    end

    if #_prog_entries > visible then
        d2d_text(vf, string.format("  ... +%d more", #_prog_entries - visible), cx, cy, grey)
    end

    return height + 10
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ESP Rendering (world-space labels)
-- ═══════════════════════════════════════════════════════════════════════════

local function render_esp_enemies()
    if not cfg.show_enemy_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    -- Determine selected enemy id for highlight
    local sel_id = state.sel_type == "enemy" and state.sel_data and
                   (state.sel_data.guid or state.sel_data.go_guid)

    for _, e in ipairs(state.enemies) do
        if e.dist > cfg.enemy_esp_range then break end
        if cfg.hide_dead and e.dead then goto next_e end
        if not e.pos then goto next_e end

        local sp = world_to_screen(e.pos, 1.8)
        if sp then
            local is_selected = sel_id and sel_id ~= false and
                                (e.guid == sel_id or e.go_guid == sel_id)

            local name_col = is_selected and 0xFFFFFF44 or cfg.col_enemy_name
            local lines = {
                { text = e.go_name or "?",            col = name_col },
                { text = e.guid or "",                col = 0xFF44EEFF },
                { text = e.kind_name,                 col = 0xFFCCCCCC },
                { text = string.format("%.1fm", e.dist), col = 0xFFAAAAAA },
                { text = map_id_str(e.map_id),        col = 0xFF666666 },
            }
            if e.hp then
                local hp_col = e.hp > 200 and 0xFF55FF88 or (e.hp > 50 and 0xFFFFAA44 or 0xFFFF5555)
                table.insert(lines, 3, { text = string.format("HP %d", math.floor(e.hp)), col = hp_col })
            end

            -- Compute background dimensions
            local total_h = #lines * lh
            local max_w   = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * cfg.font_size * 0.52
                if w > max_w then max_w = w end
            end

            local draw_y = sp.y - total_h
            local bx     = sp.x - max_w * 0.5 - 4
            local by     = draw_y - 2

            -- Semi-transparent background
            d2d_fill_rect(bx, by, max_w + 8, total_h + 4, 0xAA000000)

            -- Yellow outline if selected (4 border strips, 2px wide)
            if is_selected then
                local bw = max_w + 8
                local bh = total_h + 4
                d2d_fill_rect(bx,          by,          bw, 2,  0xFFFFFF44) -- top
                d2d_fill_rect(bx,          by + bh - 2, bw, 2,  0xFFFFFF44) -- bottom
                d2d_fill_rect(bx,          by,          2,  bh, 0xFFFFFF44) -- left
                d2d_fill_rect(bx + bw - 2, by,          2,  bh, 0xFFFFFF44) -- right
            end

            -- Draw label lines
            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw * 0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end

            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFFFF5555)
        end
        ::next_e::
    end
end

local function render_esp_items()
    if not cfg.show_item_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    for _, item in ipairs(state.items) do
        if item.dist > cfg.item_esp_range then break end
        if not item.pos then goto next_i end

        local sp = world_to_screen(item.pos, 0.5)
        if sp then
            local lines = {
                { text = item.go_name or "?",          col = cfg.col_item_name },
                { text = item.go_guid or "",           col = 0xFF44EEFF },
                { text = string.format("%.1fm", item.dist), col = 0xFFAAAAAA },
            }
            local draw_y = sp.y - #lines * lh
            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw * 0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFF55FF99)
        end
        ::next_i::
    end
end

local function render_esp_objects()
    if not cfg.show_object_esp then return end
    if not _has_w2s then return end

    local font_big = get_esp_font(cfg.font_size, true)
    local font_sm  = get_esp_font(math.max(11, cfg.font_size - 4), false)
    local lh       = cfg.font_size + 3

    for _, obj in ipairs(state.objects) do
        if obj.dist > cfg.object_esp_range then break end
        if cfg.object_esp_only_tagged and #obj.tags == 0 then goto next_obj end
        if not obj.pos then goto next_obj end

        local sp = world_to_screen(obj.pos, 0.0)
        if sp then
            local tag_str = #obj.tags > 0 and ("[" .. table.concat(obj.tags, " ") .. "]") or ""
            local name_col = obj.active and cfg.col_object_name or 0xFF888888
            local lines = {
                { text = obj.go_name or "?", col = name_col },
            }
            if tag_str ~= "" then
                table.insert(lines, 2, { text = tag_str, col = 0xFF88FFCC })
            end
            table.insert(lines, { text = string.format("%.1fm", obj.dist), col = 0xFFAAAAAA })

            local draw_y = sp.y - #lines * lh
            local max_w  = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * cfg.font_size * 0.52
                if w > max_w then max_w = w end
            end

            d2d_fill_rect(sp.x - max_w*0.5 - 4, draw_y - 2, max_w + 8, #lines*lh + 4, 0xAA000000)

            for i, ln in ipairs(lines) do
                local f  = (i == 1) and font_big or (font_sm or font_big)
                local tw = #ln.text * cfg.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw*0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x - 2, sp.y - 2, 4, 4, 0xFFFFCC88)
        end
        ::next_obj::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- D2D Registration
-- ═══════════════════════════════════════════════════════════════════════════

if d2d then
    d2d.register(
        function()
            -- reset callback: fonts are invalidated
            reset_overlay_fonts()
            reset_esp_fonts()
        end,
        function()
            -- Each right-side overlay returns its height so the next stacks below
            local spawn_height = 0
            pcall(function() spawn_height = draw_spawn_overlay() or 0 end)
            local lf_height = 0
            pcall(function() lf_height = draw_levelflow_overlay(spawn_height) or 0 end)
            pcall(function() draw_levelflow_catalog_overlay(spawn_height + lf_height) end)
            pcall(draw_dev_overlay)
            pcall(render_esp_enemies)
            pcall(render_esp_items)
            pcall(render_esp_objects)
            pcall(render_selected_go_highlight)
        end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- B Key — Place enemy spawn point at player position
-- ═══════════════════════════════════════════════════════════════════════════

local CSV_PATH = "reframework/data/enemy.csv"

-- MapID → Area name lookup (from map.csv)
local function map_id_to_area(mid)
    if not mid then return nil end
    if mid >= 1   and mid <= 11  then return "opening1"   end
    if mid >= 12  and mid <= 29  then return "uptown"     end
    if mid >= 30  and mid <= 121 then return "rpd"        end
    if mid >= 122 and mid <= 236 then return "downtown"   end
    if mid >= 237 and mid <= 242 then return "clocktower" end
    if mid >= 243 and mid <= 303 then return "hospital"   end
    if mid >= 304 and mid <= 324 then return "laboratory" end
    return nil
end

-- Area → default enemy scene path (matches MapsMetadata.GetBiorandEscapePath)
local function area_to_enemy_scene(area)
    if not area or area == "" then return "" end
    return "natives/stm/escape/scene/scenario/scenariono/" .. area .. "/enemy/common.scn.20"
end

-- Auto-increment counter for [EXTRA] entries — survives across B presses in a session.
-- On load, count existing data lines so new entries don't collide with previous runs.
local _extra_enemy_counter = 0
pcall(function()
    local f = io.open(CSV_PATH, "r")
    if not f then return end
    for line in f:lines() do
        if line:find("Biorand_Enemy_") then
            local num = tonumber(line:match("Biorand_Enemy_(%d+)"))
            if num and num > _extra_enemy_counter then _extra_enemy_counter = num end
        end
    end
    f:close()
end)

local ITEM_CSV_PATH = "reframework/data/item.csv"
local _extra_item_counter = 0
pcall(function()
    local f = io.open(ITEM_CSV_PATH, "r")
    if not f then return end
    for line in f:lines() do
        if line:find("Biorand_Item_") then
            local num = tonumber(line:match("Biorand_Item_(%d+)"))
            if num and num > _extra_item_counter then _extra_item_counter = num end
        end
    end
    f:close()
end)

local function export_player_item_position_csv()
    -- Get player position + rotation
    local px, py, pz = 0, 0, 0
    local rx, ry, rz = 0, 0, 0
    local got_pos = false
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        local pos = pm:call("get_CurrentPosition")
        if pos then
            px, py, pz = pos.x, pos.y, pos.z
            got_pos = true
        end
        local pc = pm:call("get_CurrentPlayer")
        if pc then
            local xf = pc:call("get_Transform")
            if xf then
                if not got_pos then
                    local p = xf:call("get_Position")
                    if p then px, py, pz = p.x, p.y, p.z; got_pos = true end
                end
                local q = xf:call("get_Rotation")
                if q then rx, ry, rz = q.x, q.y, q.z end
            end
        end
    end)

    if not got_pos then
        state.status_msg   = "[N] No player position available"
        state.status_until = state.tick + 240
        return
    end

    -- Open/create CSV
    local path   = ITEM_CSV_PATH
    local exists = io.open(path, "r")
    if exists then exists:close() end

    local f = io.open(path, "a")
    if not f then
        state.status_msg   = "CSV write failed: " .. path
        state.status_until = state.tick + 240
        return
    end

    if not exists then
        f:write("Guid,Item,MapID,Room Name,X,Y,Z,RX,RY,RZ,Tags,Include,Exclude,Hash\n")
    end

    -- Resolve MapID and Area
    local mid   = state.dev.map_id or 0
    local area  = map_id_to_area(mid) or "unknown"

    -- Auto-increment name
    _extra_item_counter = _extra_item_counter + 1
    local name = string.format("[EXTRA] Biorand_Item_%04d", _extra_item_counter)

    -- Generate a placeholder GUID
    local guid = string.format("00000000-0000-0000-0000-%012d", _extra_item_counter)

    -- Write entry: Guid, Item, MapID, Room Name, X, Y, Z, RX, RY, RZ, Tags, Include, Exclude, Hash
    f:write(string.format("%s,%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,,item,,\n",
        guid, name, tostring(mid), "Biorand Extra Item " .. area,
        px, py, pz, rx, ry, rz))
    f:close()

    state.status_msg   = string.format("[N] #%d placed at (%.1f, %.1f, %.1f) [%s]",
        _extra_item_counter, px, py, pz, area)
    state.status_until = state.tick + 240
    log.info("[RE3R Trainer] " .. state.status_msg)
end

local function export_player_position_csv()
    -- Get player position + rotation
    local px, py, pz = 0, 0, 0
    local rx, ry, rz = 0, 0, 0
    local got_pos = false
    pcall(function()
        local pm = sdk.get_managed_singleton("offline.PlayerManager")
        if not pm then return end
        -- Primary: get_CurrentPosition returns Vec3 directly
        local pos = pm:call("get_CurrentPosition")
        if pos then
            px, py, pz = pos.x, pos.y, pos.z
            got_pos = true
        end
        -- Rotation from PlayerCondition → Transform
        local pc = pm:call("get_CurrentPlayer")
        if pc then
            local xf = pc:call("get_Transform")
            if xf then
                if not got_pos then
                    local p = xf:call("get_Position")
                    if p then px, py, pz = p.x, p.y, p.z; got_pos = true end
                end
                local q = xf:call("get_Rotation")
                if q then rx, ry, rz = q.x, q.y, q.z end
            end
        end
    end)

    if not got_pos then
        state.status_msg   = "[B] No player position available"
        state.status_until = state.tick + 240
        return
    end

    -- Open/create CSV
    local path   = CSV_PATH
    local exists = io.open(path, "r")
    if exists then exists:close() end

    local f = io.open(path, "a")
    if not f then
        state.status_msg   = "CSV write failed: " .. path
        state.status_until = state.tick + 240
        return
    end

    if not exists then
        f:write("GUID,Name,EnemyType,MapID,X,Y,Z,RX,RY,RZ,HasDropData,Tags,Exclude,ScenePath\n")
    end

    -- Resolve MapID and ScenePath
    local mid   = state.dev.map_id or 0
    local area  = map_id_to_area(mid)
    local scene = area_to_enemy_scene(area)

    -- Auto-increment name
    _extra_enemy_counter = _extra_enemy_counter + 1
    local name = string.format("[EXTRA] Biorand_Enemy_%04d", _extra_enemy_counter)

    -- Generate a placeholder GUID
    local guid = string.format("00000000-0000-0000-0000-%012d", _extra_enemy_counter)

    -- Write entry: GUID, Name, EnemyType(blank), MapID, X,Y,Z, RX,RY,RZ, HasDropData, Tags, Exclude, ScenePath
    f:write(string.format("%s,%s,,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,FALSE,,,%s\n",
        guid, name, tostring(mid),
        px, py, pz, rx, ry, rz, scene))
    f:close()

    state.status_msg   = string.format("[B] #%d placed at (%.1f, %.1f, %.1f) [%s]",
        _extra_enemy_counter, px, py, pz, area or "unknown")
    state.status_until = state.tick + 240
    log.info("[RE3R Trainer] " .. state.status_msg)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Selected GO World Highlight (capsule drawn at selected GO's live position)
-- ═══════════════════════════════════════════════════════════════════════════

local function render_selected_go_highlight()
    if not cfg.go_highlight_selected then return end
    if not state.sel_type or state.sel_type == "scenario" then return end
    local data = state.sel_data
    if not data then return end

    -- Prefer live transform position over cached
    local pos = nil
    local go  = data._go_ref
    if go then
        pcall(function()
            local xf = go:call("get_Transform")
            if xf then
                local p = xf:call("get_Position")
                if p then pos = p end
            end
        end)
    end
    if not pos and data.pos then
        pos = Vector3f.new(data.pos.x, data.pos.y, data.pos.z)
    end
    if not pos then return end

    local col_cap  = 0xFFFFFF44  -- yellow capsule
    local col_text = 0xFFFFFF44

    -- Capsule: position is center; offset up so it straddles the transform point
    local cap_center = Vector3f.new(pos.x, pos.y + 0.9, pos.z)
    pcall(draw.capsule, cap_center, 0.35, 1.8, col_cap)

    -- World-space label above the capsule
    local label_pos = Vector3f.new(pos.x, pos.y + 2.4, pos.z)
    local display_name = data.go_name or "?"
    if state.sel_type == "item" and data.add_item_id then
        local iname = COMMON_ITEMS and COMMON_ITEMS[data.add_item_id]
        if iname then
            display_name = string.format("Item: %s [ID %d]", iname, data.add_item_id)
        end
    end
    pcall(draw.world_text, display_name, label_pos, col_text)

    -- Small sphere at the transform origin so we know exactly where it is
    pcall(draw.sphere, pos, 0.06, 0xFFFF4444)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Main Frame Loop
-- ═══════════════════════════════════════════════════════════════════════════

local _b_was_down = false
local _n_was_down = false

re.on_frame(function()
    state.tick = state.tick + 1

    -- Continuously enforce position inside on_frame for Editor Mode
    if cfg.editor_mode and state.sel_data and state.sel_data._go_ref then
        pcall(function()
            local entry = state.sel_data
            local go = entry._go_ref
            local xf = go:call("get_Transform")
            if xf and entry.x and entry.y and entry.z then
                local current_pos = xf:call("get_Position")
                if current_pos and current_pos.x and current_pos.y and current_pos.z then
                    local dx = current_pos.x - entry.x
                    local dy = current_pos.y - entry.y
                    local dz = current_pos.z - entry.z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    if dist > 0.001 then
                        -- Disable physics/colliders continuously to prevent state resets
                        prepare_game_object_for_move(go)
                        apply_position(xf, entry.x, entry.y, entry.z, go)
                    end
                end
            end
        end)
        -- Check and handle mouse wheel scroll delta to cycle items
        local wheel = 0
        pcall(function()
            local io = imgui.get_io()
            if io and io.MouseWheel then wheel = io.MouseWheel end
        end)
        if wheel ~= 0 then
            pcall(handle_item_wheel_scroll, wheel)
        end
    end
    pcall(process_spawn_input)

    -- Every 10 ticks: player pos, HP, camera yaw
    if state.tick % 10 == 0 then
        pcall(update_player_pos)
        pcall(update_player_hp)
        pcall(update_camera_rotation)
    end

    -- Every 60 ticks: screen size, game state, scenarios
    if state.tick % 60 == 1 then
        pcall(update_screen_size)
        pcall(scan_game_state)
        pcall(scan_scenarios)
    end

    -- Every scan_interval ticks: enemies, items
    if state.tick % cfg.scan_interval == 0 then
        pcall(scan_enemies)
        pcall(scan_items)
    end

    -- Every scan_interval*2 ticks: spawn groups
    if state.tick % (cfg.scan_interval * 2) == 5 then
        pcall(scan_spawn_groups)
    end

    -- Every 150 ticks: all-objects scan (via.Transform, 300 closest)
    if state.tick % 150 == 7 then
        pcall(scan_all_objects)
    end

    -- Every 300 ticks (~5 s): re-discover level flow catalog (slow, component scan)
    if state.tick % 300 == 23 then
        pcall(scan_levelflow_catalog)
    end

    -- Every 90 ticks (~1.5 s): refresh current progress values from manager
    if state.tick % 90 == 29 then
        pcall(scan_levelflow_values)
    end

    -- B key: rising-edge export
    local b_down = reframework:is_key_down(0x42)
    if b_down and not _b_was_down then
        pcall(export_player_position_csv)
    end
    _b_was_down = b_down

    -- N key: rising-edge export for items
    local n_down = reframework:is_key_down(0x4E)
    if n_down and not _n_was_down then
        pcall(export_player_item_position_csv)
    end
    _n_was_down = n_down

    -- Fallback rendering if d2d not available (RE3R has no d2d support)
    if draw and not d2d then
        local spawn_height = 0
        pcall(function() spawn_height = draw_spawn_overlay() or 0 end)
        local lf_height = 0
        pcall(function() lf_height = draw_levelflow_overlay(spawn_height) or 0 end)
        pcall(function() draw_levelflow_catalog_overlay(spawn_height + lf_height) end)
        pcall(draw_dev_overlay)
        pcall(render_esp_enemies)
        pcall(render_esp_items)
        pcall(render_esp_objects)
        pcall(render_selected_go_highlight)
        pcall(draw_selected_object_overlay)
        pcall(draw_key_shortcuts_overlay)
    end
    pcall(process_deferred)
end)

re.on_application_entry("UpdateMotion", function()
    pcall(process_deferred)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Helpers
-- ═══════════════════════════════════════════════════════════════════════════

-- REFramework imgui uses ABGR; our colors are ARGB. Convert before imgui calls.
local function to_imgui(c)
    return (c & 0xFF000000)
        | ((c & 0x000000FF) << 16)
        | (c  & 0x0000FF00)
        | ((c >> 16) & 0xFF)
end

local function colored_header(text, col)
    imgui.push_style_color(0, to_imgui(col or 0xFFFFDD88))
    imgui.separator()
    imgui.text(text)
    imgui.pop_style_color(1)
    imgui.spacing()
end

local function copy_btn(id, value)
    imgui.same_line()
    if imgui.button("Copy##" .. tostring(id)) then
        imgui.set_clipboard_text(value or "")
    end
end

local function label_row(tag, tag_col, value, key)
    imgui.text_colored(tag, to_imgui(tag_col or 0xFFE0E0E0))
    imgui.same_line()
    imgui.text(value or "")
    copy_btn(key, value)
end

local COLOR_PRESETS = {
    { "White",  0xFFFFFFFF },
    { "Red",    0xFFFF5555 },
    { "Green",  0xFF55FF99 },
    { "Yellow", 0xFFFFDD55 },
    { "Cyan",   0xFF44EEFF },
    { "Orange", 0xFFFFAA44 },
    { "Purple", 0xFFCC88FF },
    { "Blue",   0xFF88AAFF },
}

local function color_picker_row(label, config_key)
    imgui.text_colored(label, to_imgui(0xFFAAAAAA))
    for _, p in ipairs(COLOR_PRESETS) do
        imgui.same_line()
        local sel = (cfg[config_key] == p[2])
        imgui.push_style_color(0,  to_imgui(p[2]))
        imgui.push_style_color(21, sel and 0xFF2A3A2A or 0xFF1A1A2E)
        imgui.push_style_color(22, sel and 0xFF4A5A4A or 0xFF2A2A3E)
        if imgui.small_button(p[1] .. "##cp_" .. config_key) then
            cfg[config_key] = p[2]
        end
        imgui.pop_style_color(3)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Enemies
-- ═══════════════════════════════════════════════════════════════════════════

local select_obj  -- forward declaration; defined after all ui_* functions

local function ui_enemies()
    local ch
    ch, cfg.show_enemy_esp  = imgui.checkbox("Show Enemy ESP Overlay", cfg.show_enemy_esp)
    ch, cfg.enemy_esp_range = imgui.drag_float("Range (m)##er", cfg.enemy_esp_range, 0.5, 5, 200, "%.1f m")
    ch, cfg.hide_dead       = imgui.checkbox("Hide Dead Enemies", cfg.hide_dead)
    color_picker_row("Name Color:", "col_enemy_name")

    colored_header(string.format("Enemies — %d total", #state.enemies), 0xFFFFDD88)

    -- Table
    if imgui.begin_table("enemy_table", 8, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",     16, 28,  0)
        imgui.table_setup_column("Dist",  16, 56,  0)
        imgui.table_setup_column("Name",  0,  1,   0)
        imgui.table_setup_column("GUID",  16, 320, 0)
        imgui.table_setup_column("Kind",  16, 100, 0)
        imgui.table_setup_column("HP",    16, 70,  0)
        imgui.table_setup_column("State", 16, 120, 0)
        imgui.table_setup_column("Pos",   16, 200, 0)
        imgui.table_headers_row()

        for i, e in ipairs(state.enemies) do
            if cfg.hide_dead and e.dead then goto skip_en end
            imgui.table_next_row()

            local row_col = e.dead and to_imgui(0xFFFF5555) or to_imgui(0xFF44FF88)

            imgui.table_next_column()
            if imgui.small_button(">##sel_enemy_" .. i) then
                select_obj("enemy", e)
            end

            imgui.table_next_column()
            imgui.text_colored(string.format("%.0fm", e.dist), row_col)

            imgui.table_next_column()
            imgui.text_colored(e.go_name or "?", row_col)

            imgui.table_next_column()
            local guid_str = e.guid or ""
            imgui.push_item_width(310)
            imgui.input_text("##eguid_" .. i, guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##ec_" .. i) then
                imgui.set_clipboard_text(guid_str)
            end

            imgui.table_next_column()
            imgui.text_colored(e.kind_name, row_col)

            imgui.table_next_column()
            imgui.text_colored(e.hp and tostring(math.floor(e.hp)) or "-", row_col)

            imgui.table_next_column()
            imgui.text_colored(e.bt_state or "-", 0xFFDDDDDD)

            imgui.table_next_column()
            if e.pos then
                imgui.text(string.format("%.1f, %.1f, %.1f", e.pos.x, e.pos.y, e.pos.z))
            end

            ::skip_en::
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Spawn Groups
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_spawn_groups()
    local ch
    ch, cfg.show_spawn_overlay = imgui.checkbox("Show Spawn Overlay (D2D)", cfg.show_spawn_overlay)

    colored_header(string.format("Spawn Groups — %d total", #state.spawn_groups), 0xFFFFDD88)

    if imgui.begin_table("spawn_table", 9, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",       16, 28,  0)
        imgui.table_setup_column("Name",    0,  1,   0)
        imgui.table_setup_column("GO GUID", 16, 320, 0)
        imgui.table_setup_column("Spawned", 16, 70,  0)
        imgui.table_setup_column("Vanished",16, 70,  0)
        imgui.table_setup_column("AllDead", 16, 70,  0)
        imgui.table_setup_column("Diff",    16, 50,  0)
        imgui.table_setup_column("MapID",   16, 55,  0)
        imgui.table_setup_column("State",   16, 120, 0)
        imgui.table_headers_row()

        for i, sg in ipairs(state.spawn_groups) do
            imgui.table_next_row()

            local row_col
            if sg.all_dead    then row_col = to_imgui(0xFFFF5555)
            elseif sg.is_vanished then row_col = to_imgui(0xFFCC88FF)
            elseif sg.is_spawned  then row_col = to_imgui(0xFF44FF88)
            else                      row_col = to_imgui(0xFFCCCCCC) end

            imgui.table_next_column()
            if imgui.small_button(">##sel_spawn_" .. i) then
                select_obj("spawn", sg)
            end

            imgui.table_next_column()
            imgui.text_colored(sg.go_name or "?", row_col)

            imgui.table_next_column()
            local guid_str = sg.go_guid or ""
            imgui.push_item_width(310)
            imgui.input_text("##sgguid_" .. i, guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##sgc_" .. i) then
                imgui.set_clipboard_text(guid_str)
            end

            imgui.table_next_column()
            imgui.text_colored(sg.is_spawned  and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.is_vanished and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.all_dead    and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.enabled_difficulty and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.enabled_map and "Y" or "N", row_col)

            imgui.table_next_column()
            imgui.text_colored(sg.bt_state or "-", to_imgui(0xFFDDDDDD))
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Scenarios
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_scenarios()
    local ch
    ch, cfg.show_levelflow_overlay = imgui.checkbox("Show LevelFlow Overlay (D2D)", cfg.show_levelflow_overlay)

    colored_header(string.format("Scenario Controllers — %d", #state.scenarios), 0xFFFFDD88)

    local now = os.clock()
    if imgui.begin_table("scenario_table", 5, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",          16, 28,  0)
        imgui.table_setup_column("GO Name",    0,  1,   0)
        imgui.table_setup_column("BT State",   16, 130, 0)
        imgui.table_setup_column("IsAdvance",  16, 80,  0)
        imgui.table_setup_column("ScenarioNo", 16, 100, 0)
        imgui.table_headers_row()

        for i, sc in ipairs(state.scenarios) do
            imgui.table_next_row()

            local changed_recently = sc.changed_at > 0 and
                ((now - sc.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
            local row_col = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFCCCCCC)

            imgui.table_next_column()
            if imgui.small_button(">##sel_scenario_" .. i) then
                select_obj("scenario", sc)
            end

            imgui.table_next_column()
            imgui.text_colored(sc.go_name or "?", row_col)

            imgui.table_next_column()
            imgui.text_colored(sc.bt_state or "-", row_col)

            imgui.table_next_column()
            imgui.text_colored(sc.is_advance and "Y" or "N", row_col)

            imgui.table_next_column()
            local sno = sc.scenario_no
            local sno_str = sno and (tostring(sno) .. "  " .. (SCENARIO_NAMES[sno] or "")) or "-"
            imgui.text_colored(sno_str, row_col)
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Items
-- ═══════════════════════════════════════════════════════════════════════════

local _add_item_idx = 1
local _add_item_count = 1

local function ui_add_item_section()
    colored_header("Inventory / Add Item", 0xFFFFDD88)

    if not ITEM_COMBO_LABELS then
        init_item_catalog()
    end

    imgui.push_item_width(320)
    local combo_changed, new_idx = imgui.combo("Select Item##additem_combo", _add_item_idx or 1, ITEM_COMBO_LABELS)
    if combo_changed then
        _add_item_idx = new_idx
    end
    imgui.pop_item_width()

    imgui.same_line()
    imgui.push_item_width(70)
    local count_changed, new_count = imgui.drag_int("Count##additem_count", _add_item_count or 1, 0.1, 1, 999)
    if count_changed then
        _add_item_count = math.max(1, new_count)
    end
    imgui.pop_item_width()

    imgui.same_line()
    if imgui.button("Add##additem_btn") then
        local selected_item = ITEM_CATALOG[_add_item_idx]
        if selected_item then
            local ok = add_item_to_inventory(selected_item.id, _add_item_count)
            if ok then
                log.info(string.format("[RE3R Trainer] Added %d %s to inventory", _add_item_count, selected_item.debugName))
            else
                log.error(string.format("[RE3R Trainer] Failed to add %s", selected_item.debugName))
            end
        end
    end

    imgui.spacing()
    imgui.separator()
    imgui.spacing()
end

local function ui_items()
    -- Add item section first!
    pcall(ui_add_item_section)

    local ch
    ch, cfg.show_item_esp  = imgui.checkbox("Show Item ESP Overlay", cfg.show_item_esp)
    ch, cfg.item_esp_range = imgui.drag_float("Range (m)##ir", cfg.item_esp_range, 0.5, 5, 200, "%.1f m")
    color_picker_row("Name Color:", "col_item_name")

    colored_header(string.format("Items — %d total", #state.items), 0xFFFFDD88)

    if imgui.begin_table("item_table", 8, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",       16, 28,  0)
        imgui.table_setup_column("Dist",    16, 56,  0)
        imgui.table_setup_column("Name",    0,  1,   0)
        imgui.table_setup_column("Pos GUID",16, 220, 0)
        imgui.table_setup_column("GO GUID", 16, 220, 0)
        imgui.table_setup_column("BulletID",16, 80,  0)
        imgui.table_setup_column("ItemID",  16, 80,  0)
        imgui.table_setup_column("Pos",     16, 200, 0)
        imgui.table_headers_row()

        for i, itm in ipairs(state.items) do
            imgui.table_next_row()

            imgui.table_next_column()
            if imgui.small_button(">##sel_item_" .. i) then
                select_obj("item", itm)
            end

            imgui.table_next_column()
            imgui.text(string.format("%.0fm", itm.dist))

            imgui.table_next_column()
            imgui.text(itm.go_name or "?")

            imgui.table_next_column()
            local pos_guid_str = itm.pos_guid or ""
            imgui.push_item_width(200)
            imgui.input_text("##ipguid_" .. i, pos_guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##ipc_" .. i) then
                imgui.set_clipboard_text(pos_guid_str)
            end

            imgui.table_next_column()
            local go_guid_str = itm.go_guid or ""
            imgui.push_item_width(200)
            imgui.input_text("##iguid_" .. i, go_guid_str, 2048)
            imgui.pop_item_width()
            imgui.same_line()
            if imgui.small_button("C##ic_" .. i) then
                imgui.set_clipboard_text(go_guid_str)
            end

            imgui.table_next_column()
            imgui.text(itm.bullet_id and tostring(itm.bullet_id) or "-")

            imgui.table_next_column()
            imgui.text(itm.add_item_id and tostring(itm.add_item_id) or "-")

            imgui.table_next_column()
            if itm.pos then
                imgui.text(string.format("%.1f, %.1f, %.1f", itm.pos.x, itm.pos.y, itm.pos.z))
            end
        end

        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Settings
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_settings()
    local ch

    colored_header("Dev Overlay")
    ch, cfg.show_dev_overlay = imgui.checkbox("Show Dev Overlay (top-left)", cfg.show_dev_overlay)

    colored_header("Level Flow Catalog")
    ch, cfg.show_levelflow_catalog_overlay = imgui.checkbox(
        "Show Level Flow Progress Overlay", cfg.show_levelflow_catalog_overlay)
    imgui.spacing()
    local cur_name = _current_scenario_no ~= nil
        and (SCENARIO_NAMES[_current_scenario_no] or string.format("#%d", _current_scenario_no))
        or "?"
    imgui.text_colored(string.format(
        "  SSM: %s   Entries: %d   Current: %s",
        _catalog_found and "OK" or "not found",
        #_prog_entries,
        cur_name),
        to_imgui(0xFF888888))
    if imgui.button("Rescan Catalog##lfc") then
        pcall(scan_levelflow_catalog)
        pcall(scan_levelflow_values)
    end
    if cfg.show_dev_overlay then
        imgui.spacing()
        imgui.text_colored("  MapID: " .. map_id_str(state.dev.map_id), to_imgui(0xFFCCCCCC))
        imgui.text_colored("  Scene: " .. (state.dev.scene ~= "" and state.dev.scene or "(none)"), to_imgui(0xFFFFCC44))
        if state.dev.rank ~= nil then
            imgui.text_colored("  Rank:  " .. tostring(state.dev.rank), to_imgui(0xFF88CCFF))
        end
        if state.dev.player_name ~= "" then
            imgui.text_colored("  Player: " .. state.dev.player_name, to_imgui(0xFF44FF88))
        end
    end

    colored_header("Label Content")
    ch, cfg.hide_dead = imgui.checkbox("Hide Dead Enemies in ESP", cfg.hide_dead)

    colored_header("Font")
    local fc
    fc, cfg.font_size = imgui.drag_int("ESP Font Size##fs", cfg.font_size, 1, 8, 32)
    if fc then reset_esp_fonts() end

    colored_header("Scanner")
    ch, cfg.scan_interval = imgui.drag_int("Scan Interval (frames)##si", cfg.scan_interval, 1, 5, 300)

    colored_header("B Key — Place Enemy Spawn")
    imgui.text_colored("  Press B in-game to place an enemy spawn at your position:", to_imgui(0xFFCCCCCC))
    imgui.text_colored("  reframework/data/enemy.csv", to_imgui(0xFF88CCFF))
    imgui.text_colored("  Name: [EXTRA] Biorand_Enemy_XXXX  |  ScenePath from MapID", to_imgui(0xFF888888))

    colored_header("N Key — Place Item Spawn")
    imgui.text_colored("  Press N in-game to place an item spawn at your position:", to_imgui(0xFFCCCCCC))
    imgui.text_colored("  reframework/data/item.csv", to_imgui(0xFF88CCFF))
    imgui.text_colored("  Name: [EXTRA] Biorand_Item_XXXX  |  ScenePath from MapID", to_imgui(0xFF888888))

    imgui.spacing()
    imgui.separator()
    if imgui.button("Save Settings") then cfg_save() end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Object Viewer / Inspector
-- ═══════════════════════════════════════════════════════════════════════════

local TABS  -- forward declaration
local draw_transform_inspector  -- forward declaration

select_obj = function(obj_type, data)
    state.sel_type = obj_type
    state.sel_data = {}
    for k, v in pairs(data) do state.sel_data[k] = v end

    local go = state.sel_data._go_ref
    if go then
        pcall(function()
            local xf = go:call("get_Transform")
            if xf then
                local pos = xf:call("get_Position")
                if pos then
                    state.sel_data.x = pos.x
                    state.sel_data.y = pos.y
                    state.sel_data.z = pos.z
                    if not state.sel_data.pos then
                        state.sel_data.pos = { x = pos.x, y = pos.y, z = pos.z }
                    else
                        state.sel_data.pos.x = pos.x
                        state.sel_data.pos.y = pos.y
                        state.sel_data.pos.z = pos.z
                    end
                end
            end
        end)
    end
    -- floating window appears automatically from sel_data being non-nil
end

-- vi_copyable: label (grey) + value + [C] copy button
local function vi_copyable(label, value, uid)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text(tostring(value or ""))
    imgui.same_line()
    if imgui.small_button("C##vic_" .. tostring(uid)) then
        imgui.set_clipboard_text(tostring(value or ""))
    end
end

-- vi_field: label (grey) + colored value text
local function vi_field(label, value, col)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text_colored(tostring(value or ""), to_imgui(col or 0xFFE0E0E0))
end

-- vi_bool: label (grey) + YES/NO colored
local function vi_bool(label, val, col_true, col_false)
    imgui.text_colored(label, to_imgui(0xFF888888))
    imgui.same_line()
    if val then
        imgui.text_colored("YES", to_imgui(col_true  or 0xFF44FF88))
    else
        imgui.text_colored("NO",  to_imgui(col_false or 0xFFFF5555))
    end
end

-- vi_section: spacing + colored section title + spacing (reuses colored_header)
local function vi_section(title)
    colored_header(title, 0xFF44CCFF)
end

-- Per-kind approximate max HP table
local ENEMY_MAX_HP = { [4]=350, [5]=200, [6]=400 }
local ENEMY_MAX_HP_DEFAULT = 300

-- view_enemy: full detail panel for an enemy entry
local function view_enemy(e)
    -- Header
    local alive_col  = (not e.dead) and to_imgui(0xFF44FF88) or to_imgui(0xFFFF5555)
    local alive_text = (not e.dead) and "[ALIVE]" or "[DEAD]"
    imgui.text_colored(e.go_name or "?", to_imgui(0xFFFFFFFF))
    imgui.same_line()
    imgui.text_colored(alive_text, alive_col)

    vi_section("IDENTITY")
    vi_copyable("GO GUID:",      e.go_guid      or "-", "e_goguid")
    vi_copyable("Context GUID:", e.context_guid or "-", "e_ctxguid")
    local kind_str = string.format("%s (ID %s)", e.kind_name or "?", tostring(e.kind_id or "?"))
    vi_field("Kind:", kind_str, 0xFFCCCCCC)
    vi_field("Map:",  map_id_str(e.map_id), 0xFFCCCCCC)

    vi_section("COMBAT")
    if e.hp ~= nil then
        local hp_val = math.floor(e.hp)
        local hp_col = (e.hp > 200) and 0xFF44FF88 or ((e.hp > 50) and 0xFFFFAA44 or 0xFFFF5555)
        vi_field("HP:", tostring(hp_val), hp_col)

        local max_hp = ENEMY_MAX_HP[e.kind_id] or ENEMY_MAX_HP_DEFAULT
        local frac   = math.max(0, math.min(1, e.hp / max_hp))
        local bar_col = hp_col
        local bg_col  = 0xFF333333
        imgui.push_style_color(8, to_imgui(bar_col))
        imgui.push_style_color(9, to_imgui(bg_col))
        imgui.progress_bar(frac, Vector2f.new(-1, 8), "")
        imgui.pop_style_color(2)
    else
        vi_field("HP:", "-", 0xFF888888)
    end
    vi_bool("Dead:",     e.dead,     0xFFFF5555, 0xFF44FF88)
    vi_field("BT State:", e.bt_state or "-", 0xFFDDDDDD)

    vi_section("POSITION")
    if e.pos then
        vi_field("X:", string.format("%.3f", e.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", e.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", e.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", e.dist or 0), 0xFFAAAAAA)

    local go = e._go_ref
    if go then
        pcall(function()
            local en = go:call("get_DrawSelf")
            local c, nv = imgui.checkbox("Enabled##enemy_goen", en)
            if c then pcall(go.call, go, "set_DrawSelf", nv) end
        end)
        imgui.same_line()
        if imgui.button("Destroy##enemy_dst") then
            pcall(function() go:call("destroy", go) end)
        end
        local xf = nil
        pcall(function() xf = go:call("get_Transform") end)
        if xf then
            draw_transform_inspector(xf, "enemy_" .. tostring(e.go_guid or "e"), go)
        end
    end
end

-- view_spawn: detail panel for a spawn group entry
local function view_spawn(sg)
    -- Header color: lime=spawned, purple=vanished, red=all_dead, white=else
    local hcol
    if sg.is_spawned  then hcol = to_imgui(0xFF44FF88)
    elseif sg.is_vanished then hcol = to_imgui(0xFFCC88FF)
    elseif sg.all_dead    then hcol = to_imgui(0xFFFF5555)
    else                       hcol = to_imgui(0xFFFFFFFF) end
    imgui.text_colored(sg.go_name or "?", hcol)

    vi_section("IDENTITY")
    vi_copyable("GO GUID:", sg.go_guid or "-", "sg_goguid")

    vi_section("FLAGS")
    vi_bool("Spawned:",            sg.is_spawned,       0xFF44FF88, 0xFFAAAAAA)
    vi_bool("Vanished:",           sg.is_vanished,      0xFFCC88FF, 0xFFAAAAAA)
    vi_bool("All Dead:",           sg.all_dead,         0xFFFF5555, 0xFFAAAAAA)
    vi_bool("Difficulty Enabled:", sg.enabled_difficulty, 0xFF44FF88, 0xFFAAAAAA)
    vi_bool("Map ID Enabled:",     sg.enabled_map,      0xFF44FF88, 0xFFAAAAAA)
    vi_field("Init Difficulty:",   tostring(sg.init_difficulty or "-"), 0xFFCCCCCC)

    vi_section("BEHAVIOUR")
    vi_field("BT State:", sg.bt_state or "-", 0xFFDDDDDD)

    vi_section("POSITION")
    if sg.pos then
        vi_field("X:", string.format("%.3f", sg.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", sg.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", sg.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", sg.dist or 0), 0xFFAAAAAA)

    local go = sg._go_ref
    if go then
        pcall(function()
            local en = go:call("get_DrawSelf")
            local c, nv = imgui.checkbox("Enabled##spawn_goen", en)
            if c then pcall(go.call, go, "set_DrawSelf", nv) end
        end)
        imgui.same_line()
        if imgui.button("Destroy##spawn_dst") then
            pcall(function() go:call("destroy", go) end)
        end
        local xf = nil
        pcall(function() xf = go:call("get_Transform") end)
        if xf then
            draw_transform_inspector(xf, "spawn_" .. tostring(sg.go_guid or "s"), go)
        end
    end
end

-- view_item: detail panel for an item entry
local function view_item(itm)
    imgui.text_colored(itm.go_name or "?", to_imgui(0xFF44EEFF))

    vi_section("IDENTITY")
    vi_copyable("Pos GUID:", itm.pos_guid or "-", "itm_posguid")
    vi_copyable("GO GUID:",  itm.go_guid  or "-", "itm_goguid")
    vi_field("Bullet ID:", tostring(itm.bullet_id   or "-"), 0xFFCCCCCC)
    vi_field("Item ID:",   tostring(itm.add_item_id or "-"), 0xFFCCCCCC)

    vi_section("POSITION")
    if itm.pos then
        vi_field("X:", string.format("%.3f", itm.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", itm.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", itm.pos.z), 0xFFE0E0E0)
    end
    vi_field("Distance:", string.format("%.1f m", itm.dist or 0), 0xFFAAAAAA)

    local go = itm._go_ref
    if go then
        pcall(function()
            local en = go:call("get_DrawSelf")
            local c, nv = imgui.checkbox("Enabled##item_goen", en)
            if c then pcall(go.call, go, "set_DrawSelf", nv) end
        end)
        imgui.same_line()
        if imgui.button("Destroy##item_dst") then
            pcall(function() go:call("destroy", go) end)
        end
        local xf = nil
        pcall(function() xf = go:call("get_Transform") end)
        if xf then
            draw_transform_inspector(xf, "item_" .. tostring(itm.go_guid or "i"), go)
        end
    end
end

-- view_scenario: detail panel for a scenario entry
local function view_scenario(sc)
    local now = os.clock()
    local changed_recently = sc.changed_at > 0 and
        ((now - sc.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
    local hcol = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFFFFFFF)
    imgui.text_colored(sc.go_name or "?", hcol)

    vi_section("SCENARIO")
    local sno     = sc.scenario_no
    local sno_str = sno and (tostring(sno) .. "  " .. (SCENARIO_NAMES[sno] or "")) or "-"
    vi_field("ScenarioNo:", sno_str, 0xFFCCCCCC)
    vi_bool("IsAdvance:", sc.is_advance, 0xFF44FF88, 0xFFAAAAAA)

    vi_section("BEHAVIOUR")
    local bt_col = changed_recently and to_imgui(0xFF44FF88) or to_imgui(0xFFDDDDDD)
    imgui.text_colored("BT State:", to_imgui(0xFF888888))
    imgui.same_line()
    imgui.text_colored(sc.bt_state or "-", bt_col)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Component enumeration helpers
-- ═══════════════════════════════════════════════════════════════════════════

local _via_comp_rt = nil
local function get_via_comp_rt()
    if not _via_comp_rt then
        local td = sdk.find_type_definition("via.Component")
        _via_comp_rt = td and td:get_runtime_type()
    end
    return _via_comp_rt
end

-- Returns a list of all live component objects on a GO.
-- Tries getComponents(via.Component) first; falls back to known type list.
local function get_all_go_components(go)
    if not go then return {} end
    local comps = {}

    pcall(function()
        local rt = get_via_comp_rt()
        if not rt then return end
        local list = go:call("getComponents(System.Type)", rt)
        if not list then return end
        local n = 0
        pcall(function() n = list:call("get_Count") end)
        if n == 0 then pcall(function() n = #list end) end
        for i = 0, n - 1 do
            local c = nil
            pcall(function() c = list:call("get_Item", i) end)
            if c == nil then pcall(function() c = list[i] end) end
            if c then comps[#comps + 1] = c end
        end
    end)

    if #comps == 0 then
        local known = get_known_comp_types()
        for _, k in ipairs(known) do
            if k.rt then
                local c = nil
                pcall(function() c = go:call("getComponent(System.Type)", k.rt) end)
                if c then comps[#comps + 1] = c end
            end
        end
    end

    return comps
end

local COMMON_ITEMS = {
    [1] = "First Aid Spray",
    [2] = "Green Herb",
    [3] = "Red Herb",
    [4] = "Gunpowder",
    [5] = "High-Grade Gunpowder",
    [6] = "Handgun Ammo",
    [7] = "Shotgun Shells",
    [8] = "MAG Ammo",
    [9] = "Acid Rounds",
    [10] = "Flame Rounds",
    [11] = "Mine Rounds",
    [12] = "Explosive A",
    [13] = "Explosive B",
    [25] = "Fancy Box",
    [26] = "Clock T. Jewel (Green)",
    [27] = "Clock T. Jewel (Blue)",
    [28] = "Clock T. Jewel (Red)",
    [31] = "Subway Keycard",
    [32] = "Subway Pickaxe (Bolt Cutters)",
    [33] = "Subway Pick (Lockpick)",
    [37] = "Fire Hose",
    [39] = "Battery",
    [40] = "Detonator",
    [42] = "Audiocassette",
    [43] = "Subway Key",
    [44] = "Locker Key",
    [46] = "Hospital ID Card",
    [48] = "Tape Player",
    [52] = "Vaccine Sample",
    [54] = "Vaccine Base",
    [56] = "Vaccine",
    [62] = "Combat Knife",
    [63] = "Survival Knife",
    [64] = "G19 Handgun",
    [65] = "G18 Handgun (Burst)",
    [66] = "G18 Handgun",
    [67] = "M3 Shotgun",
    [68] = "CQBR Assault Rifle",
    [69] = "Lightning Hawk MAG",
    [70] = "MGL Grenade Launcher",
    [71] = "Infinite Rocket Launcher",
    [81] = "Hip Pouch"
}

local COMMON_ITEM_KEYS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 26, 27, 28, 31, 32, 33, 37, 39, 40, 42, 43, 44, 46, 48, 52, 54, 56, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 81}

local function handle_item_wheel_scroll(delta)
    local entry = state.sel_data
    if not entry then return end
    local go = entry._go_ref
    if not go then return end

    local comp = get_component(go, "offline.gimmick.action.SetItem")
    if not comp then
        pcall(function() comp = go:call("getComponent(System.Type)", sdk.typeof("offline.gimmick.action.SetItem")) end)
    end
    if not comp then return end

    local current_id = entry.add_item_id
    if not current_id then
        pcall(function() current_id = to_int(comp:get_field("AdditionalItemId")) end)
    end
    current_id = current_id or 1

    local current_idx = 1
    for idx, id in ipairs(COMMON_ITEM_KEYS) do
        if id == current_id then
            current_idx = idx
            break
        end
    end

    if delta > 0 then
        current_idx = current_idx + 1
        if current_idx > #COMMON_ITEM_KEYS then current_idx = 1 end
    elseif delta < 0 then
        current_idx = current_idx - 1
        if current_idx < 1 then current_idx = #COMMON_ITEM_KEYS end
    end

    local new_id = COMMON_ITEM_KEYS[current_idx]
    pcall(function()
        comp:set_field("AdditionalItemId", new_id)
        entry.add_item_id = new_id
        if state.sel_data then
            state.sel_data.add_item_id = new_id
        end
        state.status_msg = string.format("Cycled item: %s [ID %d]", COMMON_ITEMS[new_id] or "unknown", new_id)
        state.status_until = state.tick + 120
        log.info("[RE3R Trainer] Cycled selected item to ID " .. tostring(new_id))
    end)
end

local _extra_gimmick_counter = 0

local function teleport_selected_object_to_front()
    local entry = state.sel_data
    if not entry or not entry._go_ref then
        state.status_msg   = "Teleport failed: No selected object"
        state.status_until = state.tick + 180
        return false
    end
    
    local px, py, pz = 0, 0, 0
    pcall(function()
        if state.player_pos then
            px, py, pz = state.player_pos.x, state.player_pos.y, state.player_pos.z
        end
    end)
    if px == 0 and py == 0 and pz == 0 then
        state.status_msg   = "Teleport failed: No player position"
        state.status_until = state.tick + 180
        return false
    end

    -- Get camera forward direction
    local _, _, forward = get_camera_basis()
    forward = vec_normalize_flat(forward, Vector3f.new(0, 0, 1))

    -- Place exactly 2 meters in front of the player
    local target_x = px + forward.x * 2.0
    local target_y = py + 0.1
    local target_z = pz + forward.z * 2.0

    local go = entry._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        state.status_msg   = "Teleport failed: No transform component"
        state.status_until = state.tick + 180
        return false
    end

    local moved = apply_position(xf, target_x, target_y, target_z, go)
    if moved then
        entry.x = target_x
        entry.y = target_y
        entry.z = target_z
        if entry.pos then
            entry.pos.x = target_x
            entry.pos.y = target_y
            entry.pos.z = target_z
        end
        state.status_msg   = string.format("Teleported in front to (%.2f, %.2f, %.2f)", target_x, target_y, target_z)
        state.status_until = state.tick + 180
        log.info("[RE3R Trainer] Teleported selected object in front of player")
    else
        state.status_msg   = "Teleport failed"
        state.status_until = state.tick + 180
    end
    return moved
end

local function export_gimmick_position_csv()
    local entry = state.sel_data
    if not entry or not entry._go_ref then
        state.status_msg   = "Save failed: No selected object"
        state.status_until = state.tick + 180
        return
    end

    local go = entry._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        state.status_msg   = "Save failed: No transform component"
        state.status_until = state.tick + 180
        return
    end

    local wp = nil
    local le = nil
    pcall(function() wp = xf:call("get_Position") end)
    pcall(function() le = xf:call("get_LocalEulerAngle") end)
    if not wp then
        state.status_msg   = "Save failed: Could not get position"
        state.status_until = state.tick + 180
        return
    end

    -- Open/create gimmick.csv
    local path = "reframework\\data\\gimmick.csv"
    local exists = io.open(path, "r")
    if exists then exists:close() end

    local f = io.open(path, "a")
    if not f then
        state.status_msg   = "CSV write failed: " .. path
        state.status_until = state.tick + 180
        return
    end

    if not exists then
        f:write("GUID,Name,MapID,X,Y,Z,RX,RY,RZ,ScenePath\n")
    end

    local mid   = state.dev.map_id or 0
    local area  = map_id_to_area(mid)
    local scene = area_to_enemy_scene(area) -- or any fallback scenepath

    _extra_gimmick_counter = _extra_gimmick_counter + 1
    local go_name = tostring(go:call("get_Name") or "Gimmick")
    local guid = entry.go_guid or extract_guid(go) or string.format("00000000-0000-0000-0000-%012d", _extra_gimmick_counter + 5000)

    local rx = le and math.deg(le.x or 0) or 0
    local ry = le and math.deg(le.y or 0) or 0
    local rz = le and math.deg(le.z or 0) or 0

    f:write(string.format("%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s\n",
        guid, go_name, tostring(mid),
        wp.x, wp.y, wp.z, rx, ry, rz, scene))
    f:close()

    state.status_msg   = string.format("Exported gimmick to gimmick.csv: %s", go_name)
    state.status_until = state.tick + 180
    log.info("[RE3R Trainer] " .. state.status_msg)
end

draw_transform_inspector = function(xf, uid, go)
    if not xf then return end
    uid = uid or "xf"
    if not imgui.tree_node("Transform##xf_" .. uid) then return end

    -- Copy/Reset Utilities
    if imgui.button("Copy Placement##selected_copy_transform") then
        pcall(function()
            local wp = xf:call("get_Position")
            local le = xf:call("get_LocalEulerAngle")
            if wp and le then
                local text = string.format("%.3f\t%.3f\t%.3f\t%.1f\t%.1f\t%.1f",
                    wp.x, wp.y, wp.z, math.deg(le.x or 0), math.deg(le.y or 0), math.deg(le.z or 0))
                imgui.set_clipboard_text(text)
            end
        end)
    end
    imgui.same_line()
    if imgui.button("Reset Rotation##selected_reset_rotation") then
        defer(function()
            apply_local_euler(xf, 0, 0, 0, go)
        end)
    end
    imgui.same_line()
    if imgui.button("Save Placement##selected_save_placement") then
        pcall(function()
            local wp = xf:call("get_Position")
            local le = xf:call("get_LocalEulerAngle")
            local ls = xf:call("get_LocalScale")
            if wp and le then
                local name = tostring(go:call("get_Name") or "")
                local guid = extract_guid(go)
                local current_map = state.dev.map_id

                -- Remove existing entry if any
                for i = #state.saved_placements, 1, -1 do
                    local p = state.saved_placements[i]
                    if p.go_name == name or (guid and p.go_guid == guid) then
                        table.remove(state.saved_placements, i)
                    end
                end

                -- Add new entry
                table.insert(state.saved_placements, {
                    go_name = name,
                    go_guid = guid,
                    map_id  = current_map,
                    pos     = { x = wp.x, y = wp.y, z = wp.z },
                    rot     = { x = math.deg(le.x or 0), y = math.deg(le.y or 0), z = math.deg(le.z or 0) },
                    scale   = ls and { x = ls.x, y = ls.y, z = ls.z } or nil
                })

                save_placements_json()
                state.status_msg = "Saved placement for " .. name
                state.status_until = state.tick + 180
            end
        end)
    end
    imgui.same_line()
    if imgui.button("Clear Saved##selected_clear_placement") then
        pcall(function()
            local name = tostring(go:call("get_Name") or "")
            local guid = extract_guid(go)
            local removed = 0
            for i = #state.saved_placements, 1, -1 do
                local p = state.saved_placements[i]
                if p.go_name == name or (guid and p.go_guid == guid) then
                    table.remove(state.saved_placements, i)
                    removed = removed + 1
                end
            end
            if removed > 0 then
                save_placements_json()
                state.status_msg = "Removed saved placement for " .. name
            else
                state.status_msg = "No saved placement found for " .. name
            end
            state.status_until = state.tick + 180
        end)
    end
    imgui.spacing()

    -- Teleport & Export Utilities
    if imgui.button("Place in Front of Player##selected_teleport_front") then
        pcall(teleport_selected_object_to_front)
    end
    imgui.same_line()
    if imgui.button("Export to gimmick.csv##selected_export_gimmick_csv") then
        pcall(export_gimmick_position_csv)
    end
    imgui.spacing()

    -- Position (world, editable)
    pcall(function()
        local wp = xf:call("get_Position")
        if wp then
            imgui.text_colored("Position", to_imgui(0xFF888888))
            local cx, vx = imgui.drag_float("X##pos_x_" .. uid, wp.x, 0.05, -99999, 99999, "%.3f")
            local cy, vy = imgui.drag_float("Y##pos_y_" .. uid, wp.y, 0.05, -99999, 99999, "%.3f")
            local cz, vz = imgui.drag_float("Z##pos_z_" .. uid, wp.z, 0.05, -99999, 99999, "%.3f")
            if cx or cy or cz then
                local nx = cx and vx or wp.x
                local ny = cy and vy or wp.y
                local nz = cz and vz or wp.z
                if state.sel_data and state.sel_data._go_ref == go then
                    state.sel_data.x = nx
                    state.sel_data.y = ny
                    state.sel_data.z = nz
                    if state.sel_data.pos then
                        state.sel_data.pos.x = nx
                        state.sel_data.pos.y = ny
                        state.sel_data.pos.z = nz
                    end
                end
                defer(function()
                    apply_position(xf, nx, ny, nz, go)
                end)
            end
        end
    end)

    -- Rotation quaternion (read-only)
    pcall(function()
        local r = xf:call("get_Rotation")
        if r then
            imgui.text_colored("Rotation (Quaternion)", to_imgui(0xFF888888))
            imgui.text(string.format("  X: %.4f  Y: %.4f  Z: %.4f  W: %.4f", r.x, r.y, r.z, r.w))
        end
    end)

    -- Scale (read-only)
    pcall(function()
        local s = xf:call("get_Scale")
        if s then
            imgui.text_colored("Scale", to_imgui(0xFF888888))
            imgui.text(string.format("  X: %.3f  Y: %.3f  Z: %.3f", s.x, s.y, s.z))
        end
    end)

    -- Local Position (editable)
    pcall(function()
        local lp = xf:call("get_LocalPosition")
        if lp then
            imgui.text_colored("LocalPos", to_imgui(0xFF888888))
            local cx, vx = imgui.drag_float("X##lp_x_" .. uid, lp.x, 0.05, -99999, 99999, "%.3f")
            local cy, vy = imgui.drag_float("Y##lp_y_" .. uid, lp.y, 0.05, -99999, 99999, "%.3f")
            local cz, vz = imgui.drag_float("Z##lp_z_" .. uid, lp.z, 0.05, -99999, 99999, "%.3f")
            if cx or cy or cz then
                local nx = cx and vx or lp.x
                local ny = cy and vy or lp.y
                local nz = cz and vz or lp.z
                defer(function()
                    if go then
                        prepare_game_object_for_move(go)
                        prepare_transform_tree_for_move(xf, 0)
                    end
                    local target = Vector3f.new(nx, ny, nz)
                    local changed = call_transform_method(xf, "set_LocalPosition", set_local_position_method, target)
                    if changed and go then
                        refresh_child_transforms(xf, 0)
                        local new_wp = xf:call("get_Position")
                        if new_wp and state.sel_data and state.sel_data._go_ref == go then
                            state.sel_data.x = new_wp.x
                            state.sel_data.y = new_wp.y
                            state.sel_data.z = new_wp.z
                            if state.sel_data.pos then
                                state.sel_data.pos.x = new_wp.x
                                state.sel_data.pos.y = new_wp.y
                                state.sel_data.pos.z = new_wp.z
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- Local Euler Angles (editable)
    pcall(function()
        local le = xf:call("get_LocalEulerAngle")
        if le then
            local pitch = math.deg(le.x or 0)
            local yaw = math.deg(le.y or 0)
            local roll = math.deg(le.z or 0)
            imgui.text_colored("LocalEuler", to_imgui(0xFF888888))
            local cp, vp = imgui.drag_float("Pitch##le_p_" .. uid, pitch, 1.0, -360.0, 360.0, "%.1f")
            local cy, vy = imgui.drag_float("Yaw##le_y_" .. uid, yaw, 1.0, -360.0, 360.0, "%.1f")
            local cr, vr = imgui.drag_float("Roll##le_r_" .. uid, roll, 1.0, -360.0, 360.0, "%.1f")
            if cp or cy or cr then
                local np = cp and vp or pitch
                local ny = cy and vy or yaw
                local nr = cr and vr or roll
                defer(function()
                    apply_local_euler(xf, np, ny, nr, go)
                end)
            end
        end
    end)

    -- Local Rotation quaternion (read-only)
    pcall(function()
        local lr = xf:call("get_LocalRotation")
        if lr then
            imgui.text_colored("LocalRot (Quaternion)", to_imgui(0xFF888888))
            imgui.text(string.format("  X: %.4f  Y: %.4f  Z: %.4f  W: %.4f", lr.x, lr.y, lr.z, lr.w))
        end
    end)

    -- Local Scale (editable)
    pcall(function()
        local ls = xf:call("get_LocalScale")
        if ls then
            imgui.text_colored("LocalScale", to_imgui(0xFF888888))
            local cx, vx = imgui.drag_float("X##ls_x_" .. uid, ls.x, 0.01, -99999, 99999, "%.3f")
            local cy, vy = imgui.drag_float("Y##ls_y_" .. uid, ls.y, 0.01, -99999, 99999, "%.3f")
            local cz, vz = imgui.drag_float("Z##ls_z_" .. uid, ls.z, 0.01, -99999, 99999, "%.3f")
            if cx or cy or cz then
                local nx = cx and vx or ls.x
                local ny = cy and vy or ls.y
                local nz = cz and vz or ls.z
                defer(function()
                    apply_local_scale(xf, nx, ny, nz, go)
                end)
            end
        end
    end)

    imgui.tree_pop()
end

local function draw_selected_object_overlay()
    local data = state.sel_data
    if not data or not data._go_ref then
        return
    end

    local go = data._go_ref
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        return
    end

    local position = nil
    pcall(function() position = xf:call("get_Position") end)
    local local_euler = nil
    pcall(function() local_euler = xf:call("get_LocalEulerAngle") end)

    if not position or not local_euler then
        return
    end

    local x = 30
    local width = 520
    local height = 146
    local y = (state.sh) and (state.sh - height - 30) or 800
    local bg = 0xCC000000
    local lime = 0xFF00FF00
    local white = 0xFFFFFFFF

    local pos_text = string.format("%.3f, %.3f, %.3f", position.x, position.y, position.z)
    local rot_text = string.format("%.1f, %.1f, %.1f", 
        math.deg(local_euler.x or 0), 
        math.deg(local_euler.y or 0), 
        math.deg(local_euler.z or 0))

    local title_text = string.format("Selected Object [ %s ]", tostring(state.sel_type or "go"):upper())
    local guid_text = data.go_guid or "-"

    if draw then
        pcall(draw.filled_rect, x, y, width, height, bg)
        pcall(draw.filled_rect, x, y, 4, height, lime)
        pcall(draw.text, title_text, x + 14, y + 10, lime)
        pcall(draw.text, "Name", x + 14, y + 36, lime)
        pcall(draw.text, tostring(data.go_name or "<unnamed>"), x + 90, y + 36, white)
        pcall(draw.text, "Pos", x + 14, y + 62, lime)
        pcall(draw.text, pos_text, x + 90, y + 62, white)
        pcall(draw.text, "Rot", x + 14, y + 88, lime)
        pcall(draw.text, rot_text, x + 90, y + 88, white)
        pcall(draw.text, "Guid", x + 14, y + 114, lime)
        pcall(draw.text, guid_text, x + 90, y + 114, white)
    end
end

local function draw_key_shortcuts_overlay()
    local data = state.sel_data
    if not data or not data._go_ref then
        return
    end

    local size = get_window_size()
    if not size or not size.w or not size.h then
        return
    end

    local width = 444
    local height = 303
    local x = size.w - width - 30
    local y = size.h - height - 30
    local bg = 0xCC000000
    local lime = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey = 0xFFCCCCCC
    local key_bg = 0xFF2A2A2A

    if draw then
        pcall(draw.filled_rect, x, y, width, height, bg)
        pcall(draw.filled_rect, x, y, 4, height, lime)
        pcall(draw.text, "HOTKEYS [NUMPAD]", x + 14, y + 10, lime)

        local x_start = x + 154
        local y_start = y + 42

        local NUMPAD_KEYS = {
            -- Row 0
            { col = 0, row = 0, w = 65, h = 45, main = "Num", sub = "" },
            { col = 1, row = 0, w = 65, h = 45, main = "/", sub = "Mode" },
            { col = 2, row = 0, w = 65, h = 45, main = "*", sub = "Copy" },
            { col = 3, row = 0, w = 65, h = 45, main = "-", sub = "Del" },
            -- Row 1
            { col = 0, row = 1, w = 65, h = 45, main = "7", sub = "Rot L" },
            { col = 1, row = 1, w = 65, h = 45, main = "8", sub = "Fwd" },
            { col = 2, row = 1, w = 65, h = 45, main = "9", sub = "Rot R" },
            -- Row 2
            { col = 0, row = 2, w = 65, h = 45, main = "4", sub = "Left" },
            { col = 1, row = 2, w = 65, h = 45, main = "5", sub = "" },
            { col = 2, row = 2, w = 65, h = 45, main = "6", sub = "Right" },
            -- Row 3
            { col = 0, row = 3, w = 65, h = 45, main = "1", sub = "Y Down" },
            { col = 1, row = 3, w = 65, h = 45, main = "2", sub = "Back" },
            { col = 2, row = 3, w = 65, h = 45, main = "3", sub = "Y Up" },
            -- Row 4
            { col = 0, row = 4, w = 136, h = 45, main = "0", sub = "" },
            { col = 2, row = 4, w = 65, h = 45, main = ".", sub = "Front" },

            -- Right Columns / Spanned Keys
            { col = 3, row = 1, w = 65, h = 96, main = "+", sub = "Paste" },
            { col = 3, row = 3, w = 65, h = 96, main = "Enter", sub = "CSV" },

            -- Left Columns (Col -2 and Col -1, side-by-side left of the 1 key)
            { col = -2, row = 3, w = 65, h = 45, main = "<", sub = "Prev" },
            { col = -1, row = 3, w = 65, h = 45, main = ">", sub = "Next" },
        }

        for _, key in ipairs(NUMPAD_KEYS) do
            local key_x = x_start + key.col * 71
            local key_y = y_start + key.row * 51
            pcall(draw.filled_rect, key_x, key_y, key.w, key.h, key_bg)
            pcall(draw.text, key.main, key_x + 6, key_y + 4, lime)
            if key.sub ~= "" then
                local sub_y = key_y + 24
                if key.h > 45 then
                    sub_y = key_y + key.h - 18
                end
                pcall(draw.text, key.sub, key_x + 6, sub_y, grey)
            end
        end
    end
end

-- Safe ImGui child window wrappers for older/divergent REFramework versions
local function safe_begin_child(id, size, border)
    if type(imgui.begin_child) == "function" then
        local ok, res = pcall(imgui.begin_child, id, size, border)
        if ok then 
            return true, (res == true or res == nil)
        end
    end
    return true, false -- degraded fallback: draw content inline
end

local function safe_end_child(child_active)
    if child_active and type(imgui.end_child) == "function" then
        pcall(imgui.end_child)
    end
end

local function view_generic_go(data)
    local go = data._go_ref

    -- ── Header ────────────────────────────────────────────────────────────────
    imgui.text_colored(data.go_name or "?",
        to_imgui(data.active and 0xFFFFFFFF or 0xFF888888))
    imgui.same_line()
    imgui.text_colored(data.active and "[ACTIVE]" or "[INACTIVE]",
        data.active and to_imgui(0xFF44FF88) or to_imgui(0xFF555555))

    vi_copyable("GO GUID:", data.go_guid or "-", "vgo_guid")
    if data.tags and #data.tags > 0 then
        vi_field("Tags:", table.concat(data.tags, "  "), 0xFF88FFCC)
    end
    if data.pos then
        vi_field("Pos:",
            string.format("%.2f, %.2f, %.2f  (%.1f m)",
                data.pos.x, data.pos.y, data.pos.z, data.dist or 0),
            0xFFAAAAAA)
    end

    -- Enabled Checkbox and Destroy Button
    if go then
        pcall(function()
            local en = go:call("get_DrawSelf")
            local c, nv = imgui.checkbox("Enabled##goen_top", en)
            if c then pcall(go.call, go, "set_DrawSelf", nv) end
        end)
        imgui.same_line()
        if imgui.button("Destroy##dst_top") then
            pcall(function() go:call("destroy", go) end)
        end
    end

    -- World highlight toggle
    imgui.spacing()
    local ch
    ch, cfg.go_highlight_selected = imgui.checkbox(
        "Highlight in World##gohl", cfg.go_highlight_selected)
    imgui.spacing()

    if not go then
        imgui.text_colored("  (live GO reference lost — rescan objects)",
            to_imgui(0xFF888888))
        return
    end

    -- ── Live GO hierarchy info ─────────────────────────────────────────────
    local parent_name, child_count = nil, 0
    pcall(function()
        local parent_go = go:call("get_Parent")
        if parent_go then
            parent_name = tostring(parent_go:call("get_Name") or "?")
        end
        local xf = go:call("get_Transform")
        if xf then
            pcall(function() child_count = xf:call("get_ChildCount") or 0 end)
        end
    end)
    if parent_name then vi_field("Parent:", parent_name, 0xFFCCAA88) end
    if child_count > 0 then vi_field("Children:", tostring(child_count), 0xFFCCAA88) end

    -- ── Transform Inspector section ─────────────────────────────────────────
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if xf then
        draw_transform_inspector(xf, "vgo", go)
    end

    imgui.spacing()

    -- ── Component list ────────────────────────────────────────────────────
    local comps = get_all_go_components(go)
    imgui.text_colored(
        string.format("  %d component(s)", #comps),
        to_imgui(0xFF88DDFF))

    local fc
    fc, _go_inspector_filter = imgui.input_text(
        "Filter fields##gofltr", _go_inspector_filter, 128)
    local filter_lo = _go_inspector_filter:lower()

    imgui.spacing()

    -- Scrollable inspector area
    local draw, child_active = safe_begin_child("go_comps##vgo", Vector2f.new(-1, 0), true)
    if draw then
        if #comps == 0 then
            imgui.text_colored("  (no components found)", to_imgui(0xFF555555))
        end

        for ci, comp in ipairs(comps) do
            -- Resolve full type name
            local ctype_full, ctype_short = "unknown", "unknown"
            pcall(function()
                local td = comp:get_type_definition()
                if td then
                    ctype_full  = td:get_full_name() or td:get_name() or "unknown"
                    ctype_short = td:get_name()       or ctype_full
                end
            end)

            -- Collapsible tree node per component (first starts open)
            local node_label = string.format("[%d]  %s##cn%d", ci, ctype_short, ci)
            imgui.push_style_color(0, to_imgui(0xFF44CCFF))
            if ci == 1 then
                -- ImGuiCond_Once = 2: open on first encounter, user can collapse
                imgui.set_next_item_open(true, 2)
            end
            local open = imgui.tree_node(node_label)
            imgui.pop_style_color(1)

            if open then
                -- Full type name if it differs from short
                if ctype_full ~= ctype_short then
                    imgui.text_colored("  " .. ctype_full, to_imgui(0xFF555555))
                end
                imgui.spacing()

                pcall(function()
                    local td = comp:get_type_definition()
                    if not td then
                        imgui.text_colored("  (no TypeDefinition)", to_imgui(0xFF555555))
                        return
                    end
                    local fields = td:get_fields()
                    if not fields then
                        imgui.text_colored("  (no fields)", to_imgui(0xFF555555))
                        return
                    end

                    local n = 0
                    pcall(function()
                        local len = #fields
                        if type(len) == "number" and len > 0 then n = len end
                    end)
                    if n == 0 then pcall(function() n = fields.Length or 0 end) end
                    if n == 0 then n = 300 end

                    local shown = 0
                    for fi_i = 0, n - 1 do
                        local fi = fields[fi_i]
                        if fi == nil then break end

                        local fname = "?"
                        pcall(function() fname = tostring(fi:get_name()) end)

                        if filter_lo ~= "" and
                           not fname:lower():find(filter_lo, 1, true) then
                            goto next_fi
                        end

                        local ftype_name = ""
                        pcall(function()
                            local ft = fi:get_type()
                            if ft then ftype_name = ft:get_name() or "" end
                        end)

                        local fval_str, fval_col = "?", 0xFFE0E0E0
                        pcall(function()
                            local v = fi:get_data(comp)
                            if v == nil then
                                fval_str = "nil"
                                fval_col = 0xFF555555
                            elseif type(v) == "boolean" then
                                fval_str = v and "true" or "false"
                                fval_col = v and 0xFF44FF88 or 0xFFFF5555
                            elseif type(v) == "number" then
                                fval_str = (v ~= math.floor(v))
                                    and string.format("%.5g", v)
                                    or tostring(math.floor(v))
                                fval_col = 0xFFFFCC88
                            else
                                fval_str = tostring(v)
                                local fn = ftype_name:lower()
                                if fn:find("vec3") or fn:find("vector3") then
                                    fval_col = 0xFFAADDFF
                                elseif fn:find("vec4") or fn:find("quaternion") then
                                    fval_col = 0xFFCCAAFF
                                elseif fn:find("vec2") or fn:find("vector2") then
                                    fval_col = 0xFF88EEFF
                                elseif fn:find("string") then
                                    fval_col = 0xFFFFCC44
                                end
                            end
                        end)

                        -- Row: name (light) | value (typed color) | type (dim)
                        imgui.text_colored("  " .. fname, to_imgui(0xFFCCCCCC))
                        imgui.same_line()
                        imgui.text_colored(fval_str, to_imgui(fval_col))
                        if ftype_name ~= "" then
                            imgui.same_line()
                            imgui.text_colored("  " .. ftype_name, to_imgui(0xFF444444))
                        end

                        shown = shown + 1
                        ::next_fi::
                    end

                    if shown == 0 then
                        if filter_lo ~= "" then
                            imgui.text_colored(
                                "  (no fields match \"" .. _go_inspector_filter .. "\")",
                                to_imgui(0xFF555555))
                        else
                            imgui.text_colored("  (no fields)", to_imgui(0xFF555555))
                        end
                    end
                end)

                imgui.tree_pop()
                imgui.spacing()
            end
        end
        safe_end_child(child_active)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ui_objects: Objects tab — scene browser (all GOs sorted by distance)
-- ═══════════════════════════════════════════════════════════════════════════

local _obj_filter = ""

local function ui_objects()
    local ch

    -- ESP controls
    ch, cfg.show_object_esp = imgui.checkbox("Show Objects ESP Overlay", cfg.show_object_esp)
    if cfg.show_object_esp then
        imgui.same_line()
        ch, cfg.object_esp_only_tagged = imgui.checkbox("Tagged only##ot", cfg.object_esp_only_tagged)
        ch, cfg.object_esp_range = imgui.drag_float("Range (m)##or", cfg.object_esp_range, 0.5, 2, 100, "%.1f m")
        color_picker_row("Label Color:", "col_object_name")
    end

    imgui.spacing()
    imgui.text_colored(
        string.format("  %d GOs loaded (300 closest shown, sorted by distance)",
            #state.objects),
        to_imgui(0xFF88DDFF))

    -- Filter
    local fc
    fc, _obj_filter = imgui.input_text("Filter##objf", _obj_filter, 128)

    imgui.spacing()

    local filter_lo = _obj_filter:lower()

    if imgui.begin_table("obj_table", 6, 513, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column(">",        16, 28,  0)
        imgui.table_setup_column("Tags",     16, 110, 0)
        imgui.table_setup_column("Name",     0,  1,   0)
        imgui.table_setup_column("GO GUID",  16, 280, 0)
        imgui.table_setup_column("Active",   16, 55,  0)
        imgui.table_setup_column("Dist",     16, 56,  0)
        imgui.table_headers_row()

        local shown = 0
        for i, obj in ipairs(state.objects) do
            if filter_lo == "" or obj.go_name:lower():find(filter_lo, 1, true) then
                imgui.table_next_row()

                imgui.table_next_column()
                if imgui.small_button(">##osel_" .. i) then
                    select_obj("go", obj)
                end

                imgui.table_next_column()
                local tag_str = #obj.tags > 0 and table.concat(obj.tags, " ") or ""
                local tag_col = #obj.tags > 0 and to_imgui(0xFF88FFCC) or to_imgui(0xFF555555)
                imgui.text_colored(tag_str, tag_col)

                imgui.table_next_column()
                local name_col = obj.active and to_imgui(0xFFFFFFFF) or to_imgui(0xFF888888)
                imgui.text_colored(obj.go_name, name_col)

                imgui.table_next_column()
                local guid_str = obj.go_guid or ""
                imgui.push_item_width(270)
                imgui.input_text("##oguid_" .. i, guid_str, 2048)
                imgui.pop_item_width()
                imgui.same_line()
                if imgui.small_button("C##oc_" .. i) then
                    imgui.set_clipboard_text(guid_str)
                end

                imgui.table_next_column()
                imgui.text_colored(obj.active and "Y" or "N",
                    obj.active and to_imgui(0xFF44FF88) or to_imgui(0xFF555555))

                imgui.table_next_column()
                imgui.text(string.format("%.0fm", obj.dist))

                shown = shown + 1
                if shown >= 200 then break end  -- cap ImGui rows
            end
        end
        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ui_object: floating inspector viewer content
-- ═══════════════════════════════════════════════════════════════════════════

-- ui_object: Object tab content
local function ui_object()
    if not state.sel_data then
        imgui.spacing()
        imgui.text_colored("  No object selected.", to_imgui(0xFF888888))
        imgui.spacing()
        imgui.text_colored("  Click  >  next to any row in another tab.", to_imgui(0xFF555555))
        return
    end

    local tp  = state.sel_type or "?"
    local obj = state.sel_data

    local badges = { enemy="ENEMY", spawn="SPAWN GROUP", item="ITEM", scenario="SCENARIO", go="GAME OBJECT" }
    imgui.text_colored("[ " .. (badges[tp] or tp) .. " ]", to_imgui(0xFF44EEFF))
    imgui.same_line()
    if imgui.small_button("Close") then
        state.sel_type = nil
        state.sel_data = nil
        return
    end
    imgui.separator()
    imgui.spacing()

    local em_ch
    em_ch, cfg.editor_mode = imgui.checkbox("Editor Mode (Lock Position & Mouse-Scroll Items)", cfg.editor_mode)
    imgui.spacing()

    if     tp == "enemy"    then pcall(view_enemy,      obj)
    elseif tp == "spawn"    then pcall(view_spawn,      obj)
    elseif tp == "item"     then pcall(view_item,       obj)
    elseif tp == "scenario" then pcall(view_scenario,   obj)
    elseif tp == "go"       then pcall(view_generic_go, obj)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui Window
-- ═══════════════════════════════════════════════════════════════════════════

TABS = {
    { name = "Enemies",      fn = ui_enemies      },
    { name = "Spawn Groups", fn = ui_spawn_groups },
    { name = "Scenarios",    fn = ui_scenarios    },
    { name = "Items",        fn = ui_items        },
    { name = "Objects",      fn = ui_objects      },
    { name = "Settings",     fn = ui_settings     },
}

re.on_draw_ui(function()
    local ch
    ch, cfg.show_ui = imgui.checkbox(TITLE, cfg.show_ui)
    if not cfg.show_ui then return end

    -- Set default compact dimensions on first launch
    imgui.set_next_window_size(Vector2f.new(620, 500), 4) -- 4 = ImGuiCond_FirstUseEver

    local main_pos = nil
    local main_size = nil

    if imgui.begin_window(TITLE .. "###biorand_re3r_w", true, 0) then

        -- Status bar
        imgui.text_colored(
            string.format("  Enemies: %d   Spawns: %d   Items: %d   MapID: %s",
                #state.enemies, #state.spawn_groups, #state.items, map_id_str(state.dev.map_id)),
            to_imgui(0xFF88DDFF))
        imgui.separator()

        -- Tab bar
        for i, tab in ipairs(TABS) do
            if i > 1 then imgui.same_line() end
            local active = (state.ui_tab == i)
            if active then
                imgui.push_style_color(21, to_imgui(0xFF44FF88))
                imgui.push_style_color(22, to_imgui(0xFF44FF88))
                imgui.push_style_color(23, to_imgui(0xFF44FF88))
                imgui.push_style_color(0,  to_imgui(0xFF1A1A2E))
            else
                imgui.push_style_color(21, to_imgui(0xFF333344))
                imgui.push_style_color(22, to_imgui(0xFF444466))
                imgui.push_style_color(23, to_imgui(0xFF555577))
                imgui.push_style_color(0,  to_imgui(0xFFAAAAAA))
            end
            if imgui.button(tab.name .. "##t" .. i) then state.ui_tab = i end
            imgui.pop_style_color(4)
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- Scrollable Tab content
        local draw_tab, child_tab_active = safe_begin_child("biorand_tab_content", Vector2f.new(0, 0), false)
        if draw_tab then
            local sel = TABS[state.ui_tab or 1]
            if sel and sel.fn then
                local ok, err = pcall(sel.fn)
                if not ok then
                    imgui.text_colored("Error: " .. tostring(err), to_imgui(0xFFFF5555))
                    log.error("[RE3R Trainer] Tab error: " .. tostring(err))
                end
            end
            safe_end_child(child_tab_active)
        end

        -- Capture position and size of the main window before ending it
        pcall(function()
            main_pos = imgui.get_window_pos()
            main_size = imgui.get_window_size()
        end)

        imgui.end_window()
    end

    -- Floating Inspector Window - dynamically "stuck" to the right of the main window
    if state.sel_data and state.sel_type then
        if main_pos and main_size then
            pcall(imgui.set_next_window_pos, Vector2f.new(main_pos.x + main_size.x + 5, main_pos.y))
            pcall(imgui.set_next_window_size, Vector2f.new(450, main_size.y))
        else
            pcall(imgui.set_next_window_size, Vector2f.new(450, 500), 1)
        end

        local ins_ch, ins_open = imgui.begin_window("Selected Object Inspector###biorand_inspector_w", true, 0)
        if ins_ch then
            local draw_ins, child_ins_active = safe_begin_child("inspector_scroll_area", Vector2f.new(0, 0), false)
            if draw_ins then
                local ok, err = pcall(ui_object)
                if not ok then
                    imgui.text_colored("Error: " .. tostring(err), to_imgui(0xFFFF5555))
                    log.error("[RE3R Trainer] Inspector error: " .. tostring(err))
                end
                safe_end_child(child_ins_active)
            end
            imgui.end_window()
        end
        if ins_open == false then
            state.sel_type = nil
            state.sel_data = nil
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

re.on_script_reset(function()
    state.enemies         = {}
    state.items           = {}
    state.spawn_groups    = {}
    state.scenarios       = {}
    state.player_pos      = nil
    state.player_hp       = 0
    state.dev_rotation    = nil
    state.dev             = { scene = "", map_id = nil, rank = nil, playtime = nil,
                               player_name = "", player_state = "" }
    state.scenario_state_history = {}
    state.spawn_scene_address    = 0
    state.scenario_scene_address = 0
    state.sel_type        = nil
    state.sel_data        = nil
    state.objects         = {}
    state.deferred        = {}
    state.applied_placements = {}
    state.key_down        = {}
    state.column_width_set = false
    load_placements_json()
    _KNOWN_COMP_TYPES     = nil
    _xf_rt                = nil
    _via_comp_rt          = nil
    _prog_entries         = {}
    _catalog_found        = false
    _current_scenario_no  = nil
    state.status_msg      = ""
    _type_cache           = {}
    reset_overlay_fonts()
    reset_esp_fonts()
end)

log.info("[RE3R Trainer] " .. TITLE .. " loaded.")
