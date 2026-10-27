require "TGI/TGI_StashRules"

local RARE = {
    "Base.Pistol", "Base.Pistol2", "Base.Revolver", "Base.Shotgun", "Base.HuntingRifle", "Base.AssaultRifle",
    "Base.Bullets9mmBox", "Base.Bullets45Box", "Base.ShotgunShellsBox", "Base.308Box", "Base.556Box",
    "Base.Antibiotics", "Base.Pills", "Base.PillsBeta", "Base.PillsVitamins", "Base.AlcoholBandage",
    "Base.Machete", "Base.Katana", "Base.Crowbar", "Base.HandAxe", "Base.Sledgehammer",
    "Base.WaterPurificationTablets", "Base.CannedCorn", "Base.CannedChili", "Base.TinnedBeans",
    "Base.Battery", "Base.Generator", "Base.WalkieTalkie3", "Base.HuntingKnife", "Base.Scotchtape",
    "Base.Bag_ALICEpack", "Base.Bag_SurvivorBag", "Base.Vest_BulletCivilian", "Base.Hat_MilitaryHelmet",
}
local LOCKABLE = {
    filingcabinet = true, locker = true, militarylocker = true, toolcabinet = true, safe = true,
    desk = true, metal_shelves = true, gunstorage = true, cashregister = true, wardrobe = true,
}

local function sv(id, d)
    local t = SandboxVars and SandboxVars.TGI
    if t and t[id] ~= nil then return t[id] end
    return d
end

local function exists(t)
    local ok, v = pcall(function() return getScriptManager():FindItem(t) end)
    return ok and v ~= nil
end

local POOL = nil

local CRAFTED = { "craft", "improvis", "makeshift", "scrap", "tire", "tyre", "forged", "homemade", "handmade",
    "bone", "barbed", "spiked", "junk", "sheetmetal", "tincan", "wooden", "stone", "flint", "crude", "primitive" }
local function crafted(name, cat)
    if string.find(cat, "craft", 1, true) then return true end
    for _, k in ipairs(CRAFTED) do
        if string.find(name, k, 1, true) then return true end
    end
    return false
end

local function buildPool()
    POOL = {}
    local all = getScriptManager():getAllItems()
    for i = 0, all:size() - 1 do
        local it = all:get(i)
        if not it:getObsolete() then
            local ft = it:getFullName()
            local name = string.lower(ft)
            local cat = string.lower(tostring(it:getDisplayCategory() or ""))
            local add = 0
            if string.find(name, "debug", 1, true) or crafted(name, cat) then
                add = 0
            elseif cat == "ammo" and (string.find(name, "box", 1, true) or string.find(name, "carton", 1, true)) then
                add = 3
            elseif cat == "firstaid" or cat == "medical" then
                add = 2
            elseif cat == "protectivegear" or string.find(name, "bulletproof", 1, true) or string.find(name, "vest_bullet", 1, true) then
                add = 1
            elseif cat == "weapon" or cat == "container" or cat == "bag" then

                local okR, ranged = pcall(function() return it:isRanged() end)
                if okR and ranged == true then add = 1
                elseif cat ~= "weapon" then
                    for _, k in ipairs({ "alice", "military", "hiking", "duffel", "bigbag", "big_bag", "large" }) do
                        if string.find(name, k, 1, true) then add = 1; break end
                    end
                end
            end
            for _ = 1, add do POOL[#POOL + 1] = ft end
        end
    end

    for _, t in ipairs(RARE) do POOL[#POOL + 1] = t end
    print("[TGI] stash pool: " .. #POOL .. " entries")
end

local stashForbidden = TGI.stashForbidden

local function onFill(roomName, containerType, container, a4, a5)

    if not (container and instanceof(container, "ItemContainer")) then
        container = nil
        for _, v in ipairs({ a4, a5 }) do
            if v and instanceof(v, "ItemContainer") then container = v; break end
        end
        if not container then return end
    end
    if type(containerType) ~= "string" then
        local ok, t = pcall(function() return container:getType() end)
        containerType = ok and t or ""
    end
    local obj = container:getParent()
    if not obj or not obj.getModData then return end
    local md = obj:getModData()

    local doneKey = "TGIdone_" .. tostring(containerType or "")
    if md[doneKey] or md.TGIdone then return end
    md[doneKey] = true
    local changed = false

    local chance = tonumber(sv("StashChance", 0.5)) or 0.5
    if chance > 0 and not stashForbidden(containerType, obj) and ZombRandFloat(0, 100) < chance then
        md.TGIstash = true
        if not POOL then
            local ok = pcall(buildPool)
            if not ok then POOL = {} end
        end
        local pool = (POOL and #POOL > 0) and POOL or RARE
        for _ = 1, 2 + ZombRand(3) do
            local t = pool[ZombRand(#pool) + 1]
            if exists(t) then pcall(function() container:AddItem(t) end) end
        end
        changed = true
    end

    local lc = tonumber(sv("LockChance", 15)) or 15
    if lc > 0 and LOCKABLE[string.lower(tostring(containerType or ""))] and ZombRand(100) < lc then
        pcall(function()
            local sq = obj:getSquare()
            local b = sq and sq:getBuilding()
            local def = b and b:getDef()
            if def then md.TGIlock = def:getKeyId(); changed = true end
        end)
    end
    if changed then pcall(function() obj:transmitModData() end) end
end

Events.OnFillContainer.Add(onFill)
