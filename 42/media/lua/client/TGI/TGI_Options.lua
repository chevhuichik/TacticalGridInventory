TGI = TGI or {}
local O = {}
TGI.Options = O

local DEF = {

    replaceVanilla = true,
    nearHighlight = false,
    searchedMarks = true,
    collectMarks = true,
    smoothUI = true,
    fullscreen = false,
    fontFace = 1,
    ownFont = true,
    colorPreset = 1,
    modernUI = false,
    strictGrid = true,
    clothingPockets = true,
    invKeys = true,
    returnItems = true,
    ammoBoxCell = true,
    animations = true,
    dropOverflow = true,
    hideCosmetic = true,
    errorReports = true,
    bigTooltip = false,
    strictOthers = false,
    dragBridge = true,
    failSafe = true,
    autoFoldLoot = true,
    sizeEditor = false,
    cookBar = true,
    learnMarks = true,
    worldLabels = true,
    gamepad = true,
    lootTabs = true,
    noSearch = false,
    autoSearch = false,
    autoSort = false,
    tooltips = true,
    compare = true,
    slotHighlight = true,
    valueTiers = true,
    tileColor = 1,
    iconMenu = true,
    theme = 1,

    hotbarStyle = true,
    hotbarAmmo = true,
    hotbarInfo = true,
    hotbarHideEmpty = false,
    uiAlpha = 1,
    openSound = true,
    healthOverlay = true,
    vitals = true,
    vitalsMore = true,
    vitalsColor = 1,
    cellScale = 1,
    actionBar = true,
    quickSlots = true,
}
local KEYS = {
    openKey = Keyboard.KEY_TAB, rotateKey = Keyboard.KEY_R,
    secKey_equip = Keyboard.KEY_1, secKey_mine = Keyboard.KEY_2, secKey_loot = Keyboard.KEY_3,
    quick1 = Keyboard.KEY_F1, quick2 = Keyboard.KEY_F2, quick3 = Keyboard.KEY_F3, quick4 = Keyboard.KEY_F4,
}

local api = nil

O.LAYOUT = {}
pcall(function()
    if not PZAPI or not PZAPI.ModOptions then return end
    api = PZAPI.ModOptions:create("TacticalGridInventory", "Tactical Grid Inventory")
    local function tick(id, tt)
        api:addTickBox(id, getText("IGUI_TGI_Opt_" .. id), DEF[id], tt and getText("IGUI_TGI_Opt_" .. id .. "_tt") or "")
        O.LAYOUT[#O.LAYOUT + 1] = { k = "tick", id = id, tt = tt and ("IGUI_TGI_Opt_" .. id .. "_tt") or nil }
    end
    local function key(id) api:addKeyBind(id, getText("IGUI_TGI_Opt_" .. id), KEYS[id], "") end

    local function title(k)
        pcall(function() api:addTitle(getText(k)) end)
        O.LAYOUT[#O.LAYOUT + 1] = { k = "title", key = k }
    end
    title("IGUI_TGI_OptSecControls")
    tick("replaceVanilla", true)
    key("openKey")
    key("rotateKey")
    key("secKey_equip")
    key("secKey_mine")
    key("secKey_loot")
    tick("gamepad", true)

    title("IGUI_TGI_OptSecLook")
    local combo = api:addComboBox("theme", getText("IGUI_TGI_Opt_theme"), "")
    combo:addItem(getText("IGUI_TGI_ThemeSteel"), true)
    combo:addItem(getText("IGUI_TGI_ThemeMilitary"), false)
    combo:addItem(getText("IGUI_TGI_ThemeVanilla"), false)
    combo:addItem(getText("IGUI_TGI_ThemeTarkov"), false)
    combo:addItem(getText("IGUI_TGI_ThemeCanvas"), false)
    for _, k in ipairs({ "IGUI_TGI_ThemeBunker", "IGUI_TGI_ThemeCabin", "IGUI_TGI_ThemeHospital", "IGUI_TGI_ThemeNight" }) do combo:addItem(getText(k), false) end
    O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "theme",
        items = { "IGUI_TGI_ThemeSteel", "IGUI_TGI_ThemeMilitary", "IGUI_TGI_ThemeVanilla", "IGUI_TGI_ThemeTarkov", "IGUI_TGI_ThemeCanvas",
            "IGUI_TGI_ThemeBunker", "IGUI_TGI_ThemeCabin", "IGUI_TGI_ThemeHospital", "IGUI_TGI_ThemeNight" } }
    pcall(function()
        local cs = api:addComboBox("cellScale", getText("IGUI_TGI_Opt_cellScale"), getText("IGUI_TGI_Opt_cellScale_tt"))
        cs:addItem(getText("IGUI_TGI_Auto"), true)

        for _, v in ipairs({ "0.75x", "0.85x", "1.0x", "1.15x", "1.3x", "1.5x", "1.75x", "2.0x", "2.5x", "3.0x" }) do cs:addItem(v, false) end
        O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "cellScale", tt = "IGUI_TGI_Opt_cellScale_tt",
            items = { "IGUI_TGI_Auto", "0.75x", "0.85x", "1.0x", "1.15x", "1.3x", "1.5x", "1.75x", "2.0x", "2.5x", "3.0x" } }
    end)
    pcall(function() api:addSlider("uiAlpha", getText("IGUI_TGI_Opt_uiAlpha"), 0.2, 1, 0.05, 1, getText("IGUI_TGI_Opt_uiAlpha_tt")) end)
    O.LAYOUT[#O.LAYOUT + 1] = { k = "slider", id = "uiAlpha", min = 0.2, max = 1, step = 0.05, tt = "IGUI_TGI_Opt_uiAlpha_tt" }
    tick("modernUI", true)
    tick("animations", true)
    tick("bigTooltip", true)

    pcall(function()
        local pc = api:addComboBox("colorPreset", getText("IGUI_TGI_Opt_colorPreset"), getText("IGUI_TGI_Opt_colorPreset_tt"))
        local items = { "IGUI_TGI_PresetNone", "IGUI_TGI_Preset_Graphite", "IGUI_TGI_Preset_Olive", "IGUI_TGI_Preset_Navy",
            "IGUI_TGI_Preset_Desert", "IGUI_TGI_Preset_Blood", "IGUI_TGI_Preset_Arctic", "IGUI_TGI_Preset_NightVision",
            "IGUI_TGI_Preset_Rust", "IGUI_TGI_Preset_Paper", "IGUI_TGI_Preset_Toxic", "IGUI_TGI_Preset_Copper",
            "IGUI_TGI_Preset_Moss", "IGUI_TGI_Preset_Dusk", "IGUI_TGI_Preset_Slate", "IGUI_TGI_Preset_Ice",
            "IGUI_TGI_Preset_Wine", "IGUI_TGI_Preset_Hazard" }
        for i, k in ipairs(items) do pc:addItem(getText(k), i == 1) end
        O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "colorPreset", tt = "IGUI_TGI_Opt_colorPreset_tt", items = items }
    end)
    pcall(function()
        local ff = api:addComboBox("fontFace", getText("IGUI_TGI_Opt_fontFace"), getText("IGUI_TGI_Opt_fontFace_tt"))
        ff:addItem("Jura", true)
        ff:addItem("Tektur", false)
        ff:addItem(getText("IGUI_TGI_GameFont"), false)
        O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "fontFace", tt = "IGUI_TGI_Opt_fontFace_tt", items = { "Jura", "Tektur", "IGUI_TGI_GameFont" } }
    end)
    pcall(function()
        local tc = api:addComboBox("tileColor", getText("IGUI_TGI_Opt_tileColor"), getText("IGUI_TGI_Opt_tileColor_tt"))
        tc:addItem(getText("IGUI_TGI_TileKind"), true)
        tc:addItem(getText("IGUI_TGI_TileRarity"), false)
        tc:addItem(getText("IGUI_TGI_TileNone"), false)
        O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "tileColor", tt = "IGUI_TGI_Opt_tileColor_tt",
            items = { "IGUI_TGI_TileKind", "IGUI_TGI_TileRarity", "IGUI_TGI_TileNone" } }
    end)
    tick("fullscreen", true)
    tick("smoothUI", true)
    tick("openSound", true)

    title("IGUI_TGI_OptSecGrid")
    tick("strictGrid", true)
    tick("clothingPockets", true)
    tick("dropOverflow", true)
    tick("ammoBoxCell", true)
    tick("returnItems", true)
    tick("invKeys", true)
    tick("noSearch", true)
    tick("autoSearch", true)
    tick("autoSort", true)
    tick("autoFoldLoot", true)
    tick("lootTabs", true)
    tick("nearHighlight", true)
    tick("worldLabels", true)
    tick("iconMenu", true)
    tick("sizeEditor", true)

    title("IGUI_TGI_OptSecMarks")
    tick("tooltips")
    tick("compare")
    tick("slotHighlight", true)
    tick("searchedMarks", true)
    tick("learnMarks", true)
    tick("collectMarks", true)
    tick("cookBar", true)

    title("IGUI_TGI_OptSecGear")
    tick("healthOverlay", true)
    tick("vitals", true)
    tick("vitalsMore", true)
    pcall(function()
        local vc = api:addComboBox("vitalsColor", getText("IGUI_TGI_Opt_vitalsColor"), "")
        vc:addItem(getText("IGUI_TGI_VitColor"), true)
        vc:addItem(getText("IGUI_TGI_VitWhite"), false)
        O.LAYOUT[#O.LAYOUT + 1] = { k = "combo", id = "vitalsColor", items = { "IGUI_TGI_VitColor", "IGUI_TGI_VitWhite" } }
    end)
    tick("hideCosmetic", true)

    title("IGUI_TGI_OptSecHotbar")
    tick("hotbarStyle", true)
    tick("hotbarAmmo", true)
    tick("hotbarInfo", true)
    tick("hotbarHideEmpty", true)
    tick("actionBar", true)
    tick("quickSlots", true)
    for i = 1, 4 do key("quick" .. i) end

    title("IGUI_TGI_OptSecOther")
    tick("errorReports", true)
    tick("failSafe", true)
    tick("strictOthers", true)
    tick("dragBridge", true)
end)

pcall(function() if PZAPI.ModOptions.load then PZAPI.ModOptions:load() end end)

local function optVal(id)
    if not api or not api.getOption then return nil end
    local o = api:getOption(id)
    if not o or not o.getValue then return nil end
    return o:getValue()
end

function O.get(id)

    if id == "replaceVanilla" and TGI.Search and TGI.Search.enabled and TGI.Search.enabled() then return true end
    local ov = O.override and O.override[id]
    if ov ~= nil then return ov end
    local v = optVal(id)
    if v ~= nil then return v end
    return DEF[id]
end

function O.set(id, v)
    if not api or not api.getOption then return end
    local o = api:getOption(id)
    if o and o.setValue then o:setValue(v) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then pcall(function() PZAPI.ModOptions:save() end) end
end

function O.key(id)
    local v = optVal(id)
    if type(v) == "number" then return v end
    return KEYS[id]
end

local SDEF = { SearchEnabled = true, AllowNoSearch = false, SearchSpeed = 1.0, ScatterLoot = true, HideBagContents = true,
    SearchNoise = 6, InterruptRadius = 3, BackpackOnRun = true, TransferSpeedByPlace = true }
function O.sandbox(id)
    local sv = SandboxVars and SandboxVars.TGI
    if sv and sv[id] ~= nil then return sv[id] end
    return SDEF[id]
end

return O
