require "TGI/TGI_Options"
TGI = TGI or {}
local S = {}

local function empty(t) for _ in pairs(t) do return false end return true end
TGI.Search = S

S.seen = {}
S.active = nil
S.BASE = 0.3
S.PER_CELL = 0.14

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

S.state = {}
S.stateN = 0
function S.stateFor(container)
    local st = S.state[container]
    if not st then
        S.stateN = S.stateN + 1
        if S.stateN > 300 then

            local keep, n = {}, 0
            for c, v in pairs(S.state) do if v.all or #v.queue > 0 then keep[c] = v; n = n + 1 end end
            S.state, S.stateN = keep, n + 1
        end
        st = { all = false, queue = {} }; S.state[container] = st
    end
    return st
end

function S.enabled()
    local O = TGI.Options
    if O.sandbox("SearchEnabled") == false then return false end

    if O.get("noSearch") and (not isClient() or O.sandbox("AllowNoSearch") == true) then
        rawset(_G, "TGIVPSearch", false)
        return false
    end
    return true
end

function S.scatterFor(container, pn)
    return TGI.Options.sandbox("ScatterLoot") ~= false and not S.exempt(container, pn, true)
end

function S.exempt(container, pn, ignoreEnabled)
    if not ignoreEnabled and not S.enabled() then return true end
    if not container then return true end
    local p = getSpecificPlayer(pn or 0)
    if p and safe(function() return container:isInCharacterInventory(p) end, false) then return true end
    local t = safe(function() return container:getType() end, "")
    if t == "floor" then return true end
    return false
end

function S.isSeen(item)
    local id = safe(function() return item:getID() end, nil)
    if id and S.seen[id] then

        local md = safe(function() return item:getModData() end, nil)
        if md and not md.TGIs then S.markSeen(item) end
        return true
    end
    local md = safe(function() return item:getModData() end, nil)
    if md and md.TGIs then
        if id then S.seen[id] = true end
        return true
    end
    return false
end

function S.markSeen(item)
    local id = safe(function() return item:getID() end, nil)
    if id then S.seen[id] = true end
    local was = safe(function() return item:getModData().TGIs end, nil)
    pcall(function() item:getModData().TGIs = true end)

    rawset(_G, "TGIVPGen", (rawget(_G, "TGIVPGen") or 0) + 1)
    if not was and TGI.Sync and TGI.Sync.send then pcall(TGI.Sync.send, "seen", item) end
end

function S.markEntry(entry, animate)
    local now = getTimestampMs()
    for _, it in ipairs(entry.items or { entry.item }) do
        S.markSeen(it)
        if animate then pcall(function() S.revealedAt[it:getID()] = now end) end
    end
end

function S.revealAge(item)

    if empty(S.revealedAt) then return nil end
    local t = item and S.revealedAt[item:getID()]
    if not t then return nil end
    local a = (getTimestampMs() - t) / 1600
    if a >= 1 then S.revealedAt[item:getID()] = nil; return nil end
    return a
end

function S.hidden(entry, container, pn)
    if S.exempt(container, pn) then return false end
    return not S.isSeen(entry.item)
end

local function hasTrait(p, name, enumName)
    if not CharacterTrait or CharacterTrait[enumName] == nil then return false end
    return p:hasTrait(CharacterTrait[enumName]) == true
end

S.speedCache = {}
function S.playerSpeed(pn)
    local p = getSpecificPlayer(pn or 0)
    if not p then return 1 end
    local c = S.speedCache[pn or 0]
    local now = getTimestampMs()
    if c and now - c.t < 2000 then return c.v end
    local ok, v = pcall(S.calcSpeed, p)
    if not ok or type(v) ~= "number" then v = 1 end
    S.speedCache[pn or 0] = { t = now, v = v }
    return v
end

S.XP_LEVELS = { 0, 40, 100, 180, 280, 400, 550, 730, 940, 1200, 1500 }

local fileXP = {}
local function fileName(p)
    local n = "p"
    pcall(function() n = tostring(p:getUsername() or "p") .. "_" .. tostring(p:getDescriptor():getForename()) end)
    n = string.gsub(n, "[^%w_]", "_")
    return "TGI_search_" .. n .. ".txt"
end
local function readFile(p)
    local f = fileName(p)
    if fileXP[f] ~= nil then return fileXP[f] end
    local v = 0
    pcall(function()
        local r = getFileReader(f, false)
        if r then v = tonumber(r:readLine() or "0") or 0; r:close() end
    end)
    fileXP[f] = v
    return v
end
local function writeFile(p, v)
    local f = fileName(p)
    fileXP[f] = v
    pcall(function() local w = getFileWriter(f, true, false); w:write(tostring(v)); w:close() end)
end
function S.xp(p)
    local v = 0
    pcall(function() v = tonumber(p:getModData().TGISearchXP) or 0 end)
    local fv = readFile(p)
    if fv > v then
        v = fv
        pcall(function() p:getModData().TGISearchXP = v end)
    end
    return v
end
function S.levelOf(xp)
    local lv = 0
    for i = 2, #S.XP_LEVELS do if xp >= S.XP_LEVELS[i] then lv = i - 1 end end
    return lv
end

S.PERK_XP = { 30, 60, 110, 180, 280, 420, 600, 850, 1150, 1500 }
function S.perk()
    if S._perk ~= nil then return S._perk or nil end
    local pk = nil
    pcall(function() pk = Perks.FromString("Searching") end)
    if pk and tostring(pk) == "MAX" then pk = nil end
    S._perk = pk or false
    return pk
end

function S.migrate(p)
    local pk = S.perk()
    if not pk then return end
    local md = p:getModData()
    if md.TGISearchMigrated then return end
    md.TGISearchMigrated = true
    local oldLv = S.levelOf(S.xp(p))
    if oldLv > 0 then
        local total = 0
        for i = 1, oldLv do total = total + S.PERK_XP[i] end
        S.giveXP(p, pk, total)
    end
    pcall(function() p:transmitModData() end)
end

S.xpWay = nil
function S.giveXP(p, pk, n)
    if S.xpWay == false or not p or not pk then return end

    if isClient() then
        pcall(sendClientCommand, p, "TGI", "searchXP", { n = n })
        return
    end
    local ways = {
        function() p:getXp():AddXP(pk, n, false, false, true); return true end,
        function() p:getXp():AddXP(pk, n); return true end,
        function() return addXp ~= nil and (addXp(p, pk, n) or true) end,
    }
    local start = S.xpWay or 1
    for i = start, #ways do
        local ok, done = pcall(ways[i])
        if ok and done then S.xpWay = i; return end
    end
    S.xpWay = false
    print("[TGI] search XP could not be given (another mod?), turned off for this session")
end

function S.levelFor(p)
    local pk = S.perk()
    if pk then
        if not p:getModData().TGISearchMigrated then pcall(S.migrate, p) end
        local lv = 0
        pcall(function() lv = p:getPerkLevel(pk) end)
        return lv
    end
    return S.levelOf(S.xp(p))
end
function S.level(pn)
    local p = getSpecificPlayer(pn or 0)
    if not p then return 0 end
    return S.levelFor(p)
end

function S.perkLevel(pn)
    if TGI.Options.sandbox("SearchPerks") == false then return 0 end
    return S.level(pn)
end

S.UNLOCKS = {
    [3] = "IGUI_TGI_Unlock3",
    [4] = "IGUI_TGI_Unlock4",
    [5] = "IGUI_TGI_Unlock5",
    [6] = "IGUI_TGI_Unlock6",
    [8] = "IGUI_TGI_Unlock8",
    [10] = "IGUI_TGI_Unlock10",
}

function S.xpFor(item, stash)
    local v = (TGI.Theme and TGI.Theme.value and TGI.Theme.value(item)) or 5
    local xp

    if v <= 8 then xp = 1 elseif v <= 20 then xp = 2 elseif v <= 45 then xp = 4
    elseif v <= 120 then xp = 6 else xp = 10 end
    if stash then xp = xp + 3 end
    return xp
end

function S.addXP(pn, n)
    local p = getSpecificPlayer(pn or 0)
    n = (n or 0) * (tonumber(TGI.Options.sandbox("SearchXPMult")) or 1)
    if not p or n <= 0 then return end
    local before = S.levelFor(p)
    local pk = S.perk()
    if pk then
        S.giveXP(p, pk, n)
    else
        local nv = S.xp(p) + n
        pcall(function() p:getModData().TGISearchXP = nv end)
        writeFile(p, nv)
        pcall(function() p:transmitModData() end)
    end
    local after = S.levelFor(p)
    if after > before then
        S.speedCache[pn or 0] = nil
        if TGI.halo then
            if not pk then TGI.halo(p, getText("IGUI_TGI_SkillUp", after), true) end
            local u = S.UNLOCKS[after]
            if u and TGI.Options.sandbox("SearchPerks") ~= false then TGI.halo(p, getText(u), true) end
        end
    end
end

function S.calcSpeed(p)
    local m = 1
    local lv = S.levelFor(p)
    m = m * (1 + 0.05 * lv)
    if hasTrait(p, "EagleEyed", "EAGLE_EYED") then m = m * 1.3 end
    if hasTrait(p, "Lucky", "LUCKY") then m = m * 1.1 end
    if hasTrait(p, "ShortSighted", "SHORT_SIGHTED") then m = m * 0.8 end
    if hasTrait(p, "Clumsy", "CLUMSY") then m = m * 0.9 end
    if hasTrait(p, "Dextrous", "DEXTROUS") then m = m * 1.15 end
    if hasTrait(p, "AllThumbs", "ALL_THUMBS") then m = m * 0.85 end

    local pen = 0
    if forageSystem and forageSystem.getLightLevelPenalty then
        pen = forageSystem.getLightLevelPenalty(p, p:getCurrentSquare(), true) or 0
    end
    m = m * (1 - 0.6 * math.max(0, math.min(1, pen)))
    return m
end

function S.duration(entry, pn)
    local w, h = entry.w or 1, entry.h or 1
    local sp = tonumber(TGI.Options.sandbox("SearchSpeed")) or 1
    return (S.BASE + S.PER_CELL * (w * h)) / math.max(0.05, sp * S.playerSpeed(pn))
end

S.lastHealth = {}
function S.danger(pn)
    local p = getSpecificPlayer(pn or 0)
    if not p then return true end
    local hp = 100
    pcall(function() hp = p:getBodyDamage():getOverallBodyHealth() end)
    local last = S.lastHealth[pn or 0]
    S.lastHealth[pn or 0] = hp
    if last and hp < last - 3 then return true end
    local r = tonumber(TGI.Options.sandbox("InterruptRadius")) or 3
    if r <= 0 then return false end
    local near = false
    pcall(function()
        local list = getCell():getZombieList()
        local px, py, pz = p:getX(), p:getY(), p:getZ()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if math.abs(z:getZ() - pz) < 1 and not z:isDead() then
                local dx, dy = z:getX() - px, z:getY() - py
                local d2 = dx * dx + dy * dy

                if d2 <= 2.25 or (d2 <= r * r and z:getTarget() == p) then near = true; break end
            end
        end
    end)
    return near
end

S.panicCache = {}
function S.panic(p)
    local now = getTimestampMs()
    local c = S.panicCache[p]
    if c and now - c.t < 500 then return c.v end
    local v = 0
    local st = p.getStats and p:getStats() or nil
    if st then
        if CharacterStat and CharacterStat.PANIC and st.get then
            local ok, r = pcall(st.get, st, CharacterStat.PANIC)
            if ok and type(r) == "number" then v = r end
        elseif st.getPanic then
            local ok, r = pcall(st.getPanic, st)
            if ok and type(r) == "number" then v = r end
        end
    end
    if v > 1 then v = v / 100 end
    v = math.max(0, math.min(1, v))
    S.panicCache[p] = { t = now, v = v }
    return v
end

function S.panicFactor(pn, danger)
    local p = getSpecificPlayer(pn or 0)
    if not p then return 1 end
    local minSpeed = tonumber(TGI.Options.sandbox("DangerSearchSpeed")) or 0.35
    minSpeed = math.max(0, math.min(1, minSpeed))
    local f = 1 - (1 - minSpeed) * S.panic(p)

    if danger then f = math.min(f, 1 - (1 - minSpeed) * 0.3) end
    return f
end

function S.noise(pn)
    local p = getSpecificPlayer(pn or 0)
    if not p then return end
    pcall(function() p:getEmitter():playSound("DrawerWoodTransferItem") end)
    local r = tonumber(TGI.Options.sandbox("SearchNoise")) or 6
    if S.perkLevel(pn) >= 5 then r = math.floor(r / 2) end
    if r > 0 then pcall(function() addSound(p, p:getX(), p:getY(), p:getZ(), r, r) end) end
end

S.revealedAt = {}

function S.markPlayerItems(pn)
    local p = getSpecificPlayer(pn or 0)
    if not p then return end
    local function walk(inv, depth)
        if not inv or depth > 3 then return end
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            local id = safe(function() return it:getID() end, nil)
            if id and not S.seen[id] then S.markSeen(it) end
            if instanceof(it, "InventoryContainer") then walk(it:getInventory(), depth + 1) end
        end
    end
    pcall(walk, p:getInventory(), 0)
end

function S.bagHasHidden(bag, pn)
    if TGI.Options.sandbox("HideBagContents") == false or not S.enabled() then return false end
    local inv = safe(function() return bag:getInventory() end, nil)
    if not inv or S.exempt(inv, pn) then return false end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        if not S.isSeen(items:get(i)) then return true end
    end
    return false
end

return S
