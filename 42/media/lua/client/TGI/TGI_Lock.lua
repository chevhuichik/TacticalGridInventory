require "TGI/TGI_StashRules"

require "TimedActions/TGIBreakLockAction"
TGI = TGI or {}
local K = {}
TGI.Lock = K

local function md(container)
    local ok, obj = pcall(function() return container:getParent() end)
    if not ok or not obj or not obj.getModData then return nil, nil end
    local ok2, has = pcall(function() return obj:hasModData() end)
    if ok2 and has == false then return obj, nil end
    return obj, obj:getModData()
end

function K.isStash(container)
    local obj, m = md(container)
    if not (m ~= nil and m.TGIstash == true) then return false end

    local ok, t = pcall(function() return container:getType() end)
    if TGI.stashForbidden and TGI.stashForbidden(ok and t or "", obj) then return false end
    return true
end

function K.lockId(container)
    local _, m = md(container)
    if m and m.TGIlock ~= nil then return m.TGIlock end
    return nil
end

local function findKey(inv, id, depth)
    if not inv or depth > 3 then return nil end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local ok, kid = pcall(function() return it:getKeyId() end)
        if ok and kid == id and instanceof(it, "Key") then return it end
        if instanceof(it, "InventoryContainer") then
            local r = findKey(it:getInventory(), id, depth + 1)
            if r then return r end
        end
    end
    return nil
end

function K.hasKey(p, id)
    return p and findKey(p:getInventory(), id, 0) ~= nil
end

function K.unlock(container, picked)
    local obj, m = md(container)
    if not m then return end
    if isClient() then

        local l = TGI.Sync and TGI.Sync.loc(container)
        local p = getPlayer()
        if l and p and not l.v and not l.bags then
            m.TGIlock = nil
            sendClientCommand(p, "TGI", "unlock", { l = l, pick = picked and true or nil })
        end
    else
        m.TGIlock = nil
        pcall(function() obj:transmitModData() end)
    end
end

function K.locked(container, pn)
    local id = K.lockId(container)
    if id == nil then return false end
    local p = getSpecificPlayer(pn or 0)

    K.keyCache = K.keyCache or {}
    local ck = tostring(id)
    local now = getTimestampMs()
    local c = K.keyCache[ck]
    local has
    if c and now - c.t < 1000 then has = c.v else has = K.hasKey(p, id); K.keyCache[ck] = { t = now, v = has } end
    if has then
        K.unlock(container)

        if K.lockId(container) == nil then TGI.halo(p, getText("IGUI_TGI_KeyOpened"), true) end
        return false
    end
    return true
end

local function bobbyPin(p)
    local inv = p:getInventory()
    local t = nil

    pcall(function() t = inv:getFirstType("BobbyPin") or inv:getFirstType("HandmadeBobbyPin") end)
    return t
end

local PICK_MODS = { "NFsBetterLockpicking", "TheBestLockpicking" }
local function pickMod()
    if BobbyPinWindowNew == nil then return false end
    for _, id in ipairs(PICK_MODS) do
        local ok, on = pcall(function() return getActivatedMods():contains(id) end)
        if ok and on then return true end
    end
    return false
end

function K.tool(p)
    if not p then return nil end
    if pickMod() then local b = bobbyPin(p); if b then return b end end
    local inv = p:getInventory()
    local t = nil
    pcall(function() t = inv:getFirstTypeRecurse("Crowbar") end)
    if not t then pcall(function() t = inv:getFirstTypeRecurse("Screwdriver") end) end
    return t
end

local function minigame(p, obj, container)
    local m = obj:getModData()
    m.LockpickLevel = m.LockpickLevel or { num = ZombRand(1, 4), xp = 5 }
    local id = m.TGIlock
    local proxy = {
        getKeyId = function() return type(id) == "number" and id or 1 end,
        getModData = function() return m end,
        getSquare = function() return obj:getSquare() end,
        getX = function() return obj:getX() end, getY = function() return obj:getY() end, getZ = function() return obj:getZ() end,
        isLockedByKey = function() return K.lockId(container) ~= nil end,
        setLockedByKey = function(_, v) if not v then K.unlock(container) end end,
        getSprite = function() return obj:getSprite() end,
    }
    local w, h = 400, 400
    local win = BobbyPinWindowNew:new(getCore():getScreenWidth() / 2 - w / 2, getCore():getScreenHeight() / 2 - h / 2, w, h)
    win.lockpick_object = proxy
    win.mode = "TGIcontainer"
    win.character = p
    win.addingXP = m.LockpickLevel.xp or 5
    win.doUnlock = function(self)
        K.unlock(container, true)
        pcall(function() p:getXp():AddXP(Perks.Lockpicking, self.addingXP or 5) end)
        if TGI.Search then TGI.Search.gen = (TGI.Search.gen or 0) + 1 end
    end
    win.doLock = function() end

    win.unlockTarget = function() K.unlock(container, true) end
    win:initialise()
    win:addToUIManager()

    local open = false
    pcall(function() open = win:isReallyVisible() end)
    if not open then pcall(function() win:removeFromUIManager() end) end
    return open
end

function K.force(pn, container)
    local p = getSpecificPlayer(pn or 0)
    local obj = md(container)
    if not p or not obj then return end
    if pickMod() and bobbyPin(p) then
        if luautils and luautils.walkAdj then pcall(luautils.walkAdj, p, obj:getSquare()) end
        local ok, open = pcall(minigame, p, obj, container)
        if ok and open then return end
    end
    local tool = K.tool(p)
    if not tool then return end
    if luautils and luautils.walkAdj then pcall(luautils.walkAdj, p, obj:getSquare()) end
    ISTimedActionQueue.add(TGIBreakLockAction:new(p, obj, tool))
end

return K
