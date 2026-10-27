require "TimedActions/ISInventoryTransferAction"
TGI = TGI or {}
local R = {}

local function empty(t) for _ in pairs(t) do return false end return true end
TGI.Return = R

R.origin = {}

local function on()
    return not (TGI.Options and TGI.Options.get("returnItems") == false)
end

local function fetchedForUse(act)
    local q = ISTimedActionQueue.getTimedActionQueue(act.character)
    if not (q and q.queue) then return false end
    local after = false
    for _, a in ipairs(q.queue) do
        if after then
            if a.Type ~= "ISInventoryTransferAction" and a.Type ~= "ISUnequipAction" then return true end
        elseif a == act then
            after = true
        end
    end
    return false
end

local origPerform = ISInventoryTransferAction.perform
function ISInventoryTransferAction:perform(...)
    pcall(function()
        if self.tgiOwn or self.tgiPrep or not on() then return end
        local p, item = self.character, self.item
        local src, dest = self.srcContainer, self.destContainer
        if not (p and item and src and dest) or dest ~= p:getInventory() or src == dest then return end

        if not src:isInCharacterInventory(p) then return end

        if instanceof(item, "Moveable") then return end
        if not fetchedForUse(self) then return end
        R.origin[item:getID()] = { item = item, src = src, pn = p:getPlayerNum(), t = getTimestampMs() }
    end)
    return origPerform(self, ...)
end

function R.forget(item)
    if item then R.origin[item:getID()] = nil end
end

local nextCheck, idleSince = 0, {}
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < nextCheck then return end
    nextCheck = now + 400
    if empty(R.origin) then return end
    local A = TGI.Actions
    for id, e in pairs(R.origin) do
        local p = getSpecificPlayer(e.pn or 0)
        local inv = p and p:getInventory()
        local c = nil
        pcall(function() c = e.item:getContainer() end)
        if not p or p:isDead() or now - e.t > 300000 then
            R.origin[id] = nil
        elseif c ~= inv then

            R.origin[id] = nil
        elseif A and A.isEquipped(p, e.item) then

            if now - e.t > 3000 then R.origin[id] = nil end
        else
            local q = ISTimedActionQueue.getTimedActionQueue(p)

            local placing = false
            pcall(function() placing = getCell():getDrag(e.pn or 0) ~= nil end)
            local busy = placing or (q and q.queue and #q.queue > 0)
            if busy then idleSince[e.pn] = nil
            else
                idleSince[e.pn] = idleSince[e.pn] or now

                if now - idleSince[e.pn] > 1200 then
                    R.origin[id] = nil
                    local ok = false
                    pcall(function()
                        ok = e.src:isInCharacterInventory(p) and e.src:hasRoomFor(p, e.item)
                            and (not TGI.Strict or TGI.Strict.roomFor(p, e.item, e.src))
                    end)
                    if ok and A then
                        pcall(A.transfer, e.pn, { e.item }, e.src)
                        return
                    end
                end
            end
        end
    end
end)

return R
