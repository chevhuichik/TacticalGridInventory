require "TimedActions/ISBaseTimedAction"
require "TGI/TGI_NoNest"

TGIBreakLockAction = ISBaseTimedAction:derive("TGIBreakLockAction")

local function isCrowbar(tool)
    local t = tool and tool:getType() or ""
    return string.find(string.lower(t), "crowbar", 1, true) ~= nil
end

local function allowedTool(tool)
    local t = string.lower(tool and tool:getType() or "")
    return string.find(t, "crowbar", 1, true) ~= nil or string.find(t, "screwdriver", 1, true) ~= nil
        or string.find(t, "bobbypin", 1, true) ~= nil or string.find(t, "hairpin", 1, true) ~= nil
end
function TGIBreakLockAction:isValid()
    if not (self.object and self.object:getSquare() and self.tool) then return false end
    if not self.character:getInventory():containsRecursive(self.tool) or not allowedTool(self.tool) then return false end
    if self.object:getModData().TGIlock == nil then return false end
    local sq, cs = self.object:getSquare(), self.character:getCurrentSquare()
    if not cs or sq:getZ() ~= cs:getZ() then return false end
    return math.abs(sq:getX() - cs:getX()) <= 2 and math.abs(sq:getY() - cs:getY()) <= 2
end

function TGIBreakLockAction:waitToStart()
    self.character:faceThisObject(self.object)
    return self.character:shouldBeTurning()
end

function TGIBreakLockAction:update()
    self.character:faceThisObject(self.object)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function TGIBreakLockAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self.sound = self.character:playSound(isCrowbar(self.tool) and "BreakLockOnWindow" or "DrawerMetalTransferItem")
end

function TGIBreakLockAction:stop()
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
    ISBaseTimedAction.stop(self)
end

local function unlock(obj)
    local md = obj:getModData()
    md.TGIlock = nil
    md.TGIforced = true
    if obj.transmitModData then obj:transmitModData() end
end

function TGIBreakLockAction:perform()
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
    ISBaseTimedAction.perform(self)
end

local function tell(character, ok)
    if isServer() then
        sendServerCommand(character, "TGI", "lockResult", { ok = ok })
    elseif TGI and TGI.halo then
        pcall(TGI.halo, character, getText(ok and "IGUI_TGI_Forced" or "IGUI_TGI_ForceFail"), ok)
        if TGI.Window then TGI.Window.containersDirty = true end
    end
end

function TGIBreakLockAction:complete()
    local crow = isCrowbar(self.tool)
    local ok = crow
    if not crow then
        local lvl = self.character:getPerkLevel(Perks.Nimble) + self.character:getPerkLevel(Perks.Mechanics)
        ok = ZombRand(100) < 30 + lvl * 6
    end
    if crow then
        addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 15, 15)
    end
    if ZombRand(crow and 4 or 3) == 0 then
        self.tool:setCondition(math.max(0, self.tool:getCondition() - 1))
        if self.tool.syncItemFields then self.tool:syncItemFields() end
        if isServer() and sendItemStats then pcall(sendItemStats, self.tool) end
    end
    if ok then unlock(self.object) end
    tell(self.character, ok)
    return true
end

function TGIBreakLockAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return isCrowbar(self.tool) and 160 or 280
end

function TGIBreakLockAction:new(character, object, tool)
    local o = ISBaseTimedAction.new(self, character)
    o.object = object
    o.tool = tool
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
