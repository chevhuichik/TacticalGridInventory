TGI = TGI or {}
local K = {}
TGI.Marks = K

local function on()
    if rawget(_G, "ViewpointLoot") then return false end
    return not TGI.Options or TGI.Options.get("searchedMarks") ~= false
end

function K.markContainer(c, pn)
    if not c then return end
    local ok, t = pcall(function() return c:getType() end)
    if not ok or t == "floor" then return end
    local p = getSpecificPlayer(pn or 0)
    if p and c:isInCharacterInventory(p) then return end
    local obj = c:getParent()
    if not obj or not obj.getModData or not obj.getSquare or not obj:getSquare() then return end
    if instanceof(obj, "BaseVehicle") or instanceof(obj, "IsoGameCharacter") then return end
    local md = obj:getModData()
    local n = c:getItems():size()

    if n == 0 or md.TGIOwn then md.TGISeen = nil; return end
    md.TGISeen = n
end

local function markOwn(c)
    if not c then return end
    local ok, t = pcall(function() return c:getType() end)
    if not ok or t == "floor" then return end
    local obj = c:getParent()
    if not obj or not obj.getModData or instanceof(obj, "IsoGameCharacter") or instanceof(obj, "BaseVehicle") then return end
    local md = obj:getModData()
    md.TGIOwn = true
    md.TGISeen = nil
end
K.markOwn = markOwn
if ISInventoryTransferAction and ISInventoryTransferAction.perform and not ISInventoryTransferAction.tgiMarkWrapped then
    local orig = ISInventoryTransferAction.perform
    ISInventoryTransferAction.perform = function(self, ...)
        pcall(function()
            local dest = self.destContainer
            local p = self.character
            if dest and p and p == getSpecificPlayer(0) and not dest:isInCharacterInventory(p) then markOwn(dest) end
        end)
        return orig(self, ...)
    end
    ISInventoryTransferAction.tgiMarkWrapped = true
end

local list, nextScan = {}, 0
local function scan(p)
    list = {}
    local sq0 = p:getCurrentSquare()
    if not sq0 then return end
    local cell, z = getCell(), sq0:getZ()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(sq0:getX() + dx, sq0:getY() + dy, z)

            if sq and sq ~= sq0 and not sq0:canReachTo(sq) then sq = nil end
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    local c = o and o:getContainer()
                    local md = c and o:getModData()
                    local seen = md and md.TGISeen
                    if seen then

                        local n = c:getItems():size()
                        if type(seen) ~= "number" or n > seen or n == 0 then md.TGISeen = nil
                        else
                            if n < seen then md.TGISeen = n end
                            list[#list + 1] = { sq:getX(), sq:getY(), z }
                            break
                        end
                    end
                end
            end
        end
    end
end

local El = ISUIElement:derive("TGIMarks")
function El:new()

    local o = ISUIElement:new(0, 0, 1, 1)
    setmetatable(o, self); self.__index = self
    return o
end

function El:instantiate()
    ISUIElement.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end
function El:render()
    if not on() then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local now = getTimestampMs()
    if now >= nextScan then nextScan = now + 250; pcall(scan, p) end
    if #list == 0 then return end
    local tex = TGI.Draw and TGI.Draw.tex("ic_check")
    if not tex then return end
    local zoom = getCore():getZoom(0)
    local ox, oy = IsoCamera.getOffX(), IsoCamera.getOffY()
    for _, m in ipairs(list) do
        local sx = (IsoUtils.XToScreen(m[1] + 0.5, m[2] + 0.5, m[3], 0) - ox) / zoom
        local sy = (IsoUtils.YToScreen(m[1] + 0.5, m[2] + 0.5, m[3], 0) - oy) / zoom
        local sz = 14
        self:drawRect(sx - sz / 2 - 2, sy - 52 / zoom - 2, sz + 4, sz + 4, 0.55, 0, 0, 0)
        self:drawTextureScaled(tex, sx - sz / 2, sy - 52 / zoom, sz, sz, 0.85, 0.45, 0.95, 0.5)
    end
end

Events.OnGameStart.Add(function()
    if K.el then return end
    local e = El:new()
    e:initialise()
    e:addToUIManager()
    e:backMost()
    K.el = e
end)

return K
