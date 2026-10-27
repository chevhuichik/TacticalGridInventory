require "TGI/TGI_Model"
require "TimedActions/ISInventoryTransferAction"

TGI = TGI or {}
local St = { refused = {} }
TGI.Strict = St

function St.wasRefused(item)
    local t = item and St.refused[item:getID()]
    return t ~= nil and getTimestampMs() - t < 10000
end

local cache, cacheN = {}, 0
local lastHalo = 0

local function modelFor(pn, c, isMain)
    local now = getTimestampMs()
    local e = cache[c]
    if e and now - e.t < 5000 then e.m.dirty = true; return e.m end
    local bag = nil
    pcall(function() bag = c:getContainingItem() end)

    local m = TGI.Model.new(c, { playerNum = pn, bagItem = bag, kind = isMain and "main" or nil })
    cacheN = cacheN + 1
    if cacheN > 40 then cache, cacheN = {}, 1 end
    cache[c] = { m = m, t = now }
    return m
end

local MOVES = { ISInventoryTransferAction = true, ISGrabItemAction = true }
local function preparesSomething(act)
    local q = ISTimedActionQueue.getTimedActionQueue(act.character)
    if not q or not q.queue then return false end
    local after = false
    for _, a in ipairs(q.queue) do
        if a == act then after = true
        elseif after and not MOVES[a.Type or ""] then return true end
    end
    return false
end

function St.roomFor(p, item, dest)
    if not (p and item and dest) or not TGI.Model.strictOn() then return true end
    local inPlayer = dest == p:getInventory()
    if not inPlayer then
        local ok, v = pcall(function() return dest:isInCharacterInventory(p) end)
        inPlayer = ok and v
    end
    if not inPlayer then return true end

    if item:getContainer() == dest then return true end

    if instanceof(item, "Moveable") then return true end
    local m = modelFor(p:getPlayerNum(), dest, dest == p:getInventory())
    local ok, room = pcall(function() return m:hasRoomFor(item) end)
    return (not ok) or room
end

local function refuse(p)
    local now = getTimestampMs()
    if now - lastHalo > 1500 and TGI.halo then
        lastHalo = now
        TGI.halo(p, getText("IGUI_TGI_NoRoom"), false)
    end
end

local function check(act, item)
    if act.tgiPrep then return true end
    if act.tgiRoomT and getTimestampMs() - act.tgiRoomT < 400 then return true end
    if not TGI.Model.strictOn() then return true end

    if not act.tgiSeen then
        act.tgiSeen = true
        act.tgiOwn = TGI.Actions and TGI.Actions.queuing == true
        return true
    end

    if not act.tgiOwn and TGI.Options.get("strictOthers") ~= true then return true end
    local p = act.character
    if not item or not p or not p:isLocalPlayer() then return true end
    if preparesSomething(act) then act.tgiPrep = true; return true end

    if TGI.Actions and TGI.Actions.pending and TGI.Actions.pending[item:getID()] then act.tgiPrep = true; return true end
    if St.roomFor(p, item, act.destContainer) then act.tgiRoomT = getTimestampMs(); return true end
    refuse(p)

    St.refusedN = (St.refusedN or 0) + 1
    if St.refusedN > 200 then St.refused, St.refusedN = {}, 1 end
    St.refused[item:getID()] = getTimestampMs()
    return false
end

if not ISInventoryTransferAction.tgiStrictWrapped then
    local orig = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self, ...)
        if not orig(self, ...) then return false end
        if self.dontAdd then return true end
        local ok, v = pcall(check, self, self.item)
        return (not ok) or v
    end
    ISInventoryTransferAction.tgiStrictWrapped = true
end

local function wrapGrab()
    if not ISGrabItemAction or ISGrabItemAction.tgiStrictWrapped then return end
    local orig = ISGrabItemAction.isValid
    ISGrabItemAction.isValid = function(self, ...)
        if not orig(self, ...) then return false end
        local it = nil
        pcall(function() it = self.item and self.item:getItem() end)
        local ok, v = pcall(check, self, it)
        return (not ok) or v
    end
    ISGrabItemAction.tgiStrictWrapped = true
end
pcall(function() require "TimedActions/ISGrabItemAction" end)
wrapGrab()
Events.OnGameStart.Add(wrapGrab)

return St
