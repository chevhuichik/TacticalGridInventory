local function nests(item, dest)
    if not item or not dest or not instanceof(item, "InventoryContainer") then return false end
    local ok, own = pcall(function() return item:getInventory() end)
    if ok and own == dest then return true end
    local c, id = dest, item:getID()
    for _ = 1, 16 do
        local holder
        pcall(function() holder = c:getContainingItem() end)
        if not holder then return false end
        if holder == item or holder:getID() == id then return true end
        local nxt
        pcall(function() nxt = holder:getContainer() end)
        if not nxt or nxt == c then return false end
        c = nxt
    end
    return true
end
TGI = TGI or {}
TGI.nests = nests

function TGI.halo(p, text, good)
    if not p or not text then return end
    local ok = pcall(function()
        if good then HaloTextHelper.addGoodText(p, text) else HaloTextHelper.addBadText(p, text) end
    end)
    if not ok then pcall(function() p:setHaloNote(text) end) end
end

local function install()
    if ISInventoryTransferAction and not ISInventoryTransferAction.tgiNoNest then
        local origValid = ISInventoryTransferAction.isValid
        function ISInventoryTransferAction:isValid()
            if nests(self.item, self.destContainer) then return false end
            return origValid(self)
        end
        ISInventoryTransferAction.tgiNoNest = true
    end
end
install()
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(install) end
if Events and Events.OnGameStart then Events.OnGameStart.Add(install) end
