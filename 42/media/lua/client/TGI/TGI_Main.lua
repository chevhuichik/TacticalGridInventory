require "TGI/TGI_Options"

require "TGI/TGI_Window"
require "TGI/TGI_Drag"
require "TGI/TGI_Return"

TGI = TGI or {}
TGI.KEY_OPEN = Keyboard.KEY_I

local lastR = 0

function TGI.rotateKey() return TGI._rotateKey() end
local function rotateKey()
    local now = getTimestampMs()
    if now - lastR < 150 then return end
    lastR = now
    if TGI.Drag.active then TGI.Drag.rotate(); return end
    local w = TGI.Window.instance
    if not w then return end
    local mx, my = getMouseX(), getMouseY()
    for _, col in ipairs({ w.mine, w.loot }) do
        for _, panel in ipairs(col.panels) do
            if panel:tgiContains(mx, my) then
                local e = panel:entryAtMouse(mx - panel:getAbsoluteX(), my - panel:getAbsoluteY())
                local m = panel.model
                local pos = e and m.board.entries[e.key]
                if pos then
                    if not m:moveLocal(e, pos.pi, pos.x, pos.y, not pos.rot) then
                        local G = TGI.Grid
                        G.remove(m.board, e.key)
                        local pi, x, y = G.findSpot(m.board, pos.rot and e.w or e.h, pos.rot and e.h or e.w, nil)
                        local ok = pi and m:moveLocal(e, pi, x, y, not pos.rot)
                        if not ok then G.place(m.board, e.key, pos.pi, pos.x, pos.y, e.w, e.h, pos.rot) end
                    end
                end
                return
            end
        end
    end
end

local function onKeyStart(key)
    if TGI.Window.typing and TGI.Window.typing() then return end
    if key == TGI.Options.key("rotateKey") and (TGI.Drag.active or TGI.Window.instance)
        and not (getCell() and getCell():getDrag(0)) then rotateKey() end
end

function TGI.isInvKey(key)
    local core = getCore()
    if KeybindId and KeybindId.TOGGLE_INVENTORY and core.isKey then return core:isKey(KeybindId.TOGGLE_INVENTORY, key) end
    return core:getKey("Toggle Inventory") == key
end

local function inMenu()
    local ok, v = pcall(function() return MainScreen.instance and MainScreen.instance:getIsVisible() end)
    return ok and v == true
end
TGI.inMenu = inMenu

local function onKeyPressed(key)
    if inMenu() then return end
    if TGI.Window.typing and TGI.Window.typing() then return end
    if key == TGI.Options.key("rotateKey") and (TGI.Drag.active or TGI.Window.instance) then
        rotateKey()
        return
    end
    local isInvKey = false
    pcall(function() isInvKey = TGI.isInvKey(key) end)
    if not TGI.Options.get("replaceVanilla") then isInvKey = false end
    if isInvKey or key == TGI.Options.key("openKey") then
        local p = getSpecificPlayer(0)
        if not TGI.usesGrid(0) then

            if isInvKey and ISInventoryPage and ISInventoryPage.onKeyPressed then pcall(ISInventoryPage.onKeyPressed, key)
            elseif TGI.fallback then

                pcall(function()
                    local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
                    local on = not (inv and inv:getIsVisible())
                    if inv then inv:setVisible(on) end
                    if loot then loot:setVisible(on) end
                end)
            end
            return
        end
        if p and not p:isDead() then TGI.Window.toggle(0) end
        return
    end
    if key == Keyboard.KEY_ESCAPE and TGI.Drag and (TGI.Drag.active or (TGI.Drag.justCancelled and getTimestampMs() - TGI.Drag.justCancelled < 300)) then
        TGI.Drag.cancel()
        return
    end
    if key == Keyboard.KEY_ESCAPE and TGI.Window.instance then
        TGI.Window.instance:closeAnimated()
    end
end

local function onContainerUpdate()
    TGI.Window.containersDirty = true
end

Events.OnKeyPressed.Add(onKeyPressed)
if Events.OnKeyStartPressed then Events.OnKeyStartPressed.Add(onKeyStart) end
Events.OnContainerUpdate.Add(onContainerUpdate)
if Events.OnClothingUpdated then Events.OnClothingUpdated.Add(onContainerUpdate) end
if Events.OnEquipPrimary then Events.OnEquipPrimary.Add(onContainerUpdate) end
if Events.OnEquipSecondary then Events.OnEquipSecondary.Add(onContainerUpdate) end
Events.OnPlayerDeath.Add(function() if TGI.Window.instance then TGI.Window.instance:close() end end)

function TGI.usesGrid(pn)
    pn = pn or 0
    if pn ~= 0 then return false end

    if TGI.fallback then return false end
    if JoypadState and JoypadState.players and JoypadState.players[pn + 1] then
        return TGI.Options.get("gamepad") ~= false
    end
    return true
end

local function hideVanilla()
    for i = 0, getNumActivePlayers() - 1 do
        if TGI.usesGrid(i) then pcall(function()
            local inv, loot = getPlayerInventory(i), getPlayerLoot(i)
            if inv and inv:getIsVisible() then inv:setVisible(false) end
            if loot and loot:getIsVisible() then loot:setVisible(false) end
        end) end
    end
end

local keyTaken = false
local function takeOver()
    if not TGI.Options.get("replaceVanilla") then return end
    if not keyTaken and ISInventoryPage and ISInventoryPage.onKeyPressed then
        pcall(function() Events.OnKeyPressed.Remove(ISInventoryPage.onKeyPressed) end)
        keyTaken = true
    end
    hideVanilla()
end
local function giveBackKey()
    if keyTaken and ISInventoryPage and ISInventoryPage.onKeyPressed then
        pcall(function() Events.OnKeyPressed.Add(ISInventoryPage.onKeyPressed) end)
    end
    keyTaken = false
end

local tick = 0
local function onTick()
    tick = tick + 1
    if tick % 20 ~= 0 then return end
    if TGI.Options.get("replaceVanilla") then
        if not keyTaken then takeOver() else hideVanilla() end
    elseif keyTaken then
        giveBackKey()
    end
end

Events.OnGameStart.Add(takeOver)
Events.OnCreatePlayer.Add(function() takeOver() end)
Events.OnTick.Add(onTick)

Events.OnTick.Add(function()
    local okD, drag = pcall(function() return getCell() and getCell():getDrag(0) end)
    if okD and drag then TGI.dragAt = getTimestampMs() end
    if (function() local m = rawget(_G, "ISWorldMap_instance"); return m and m.isVisible and m:isVisible() end)() then TGI.mapAt = getTimestampMs() end
end)

TGI._rotateKey = rotateKey

local function guardPage()
    if not ISInventoryPage or ISInventoryPage.TGIguard then return end
    ISInventoryPage.TGIguard = true
    for _, fn in ipairs({ "prerender", "render" }) do
        local orig = ISInventoryPage[fn]
        if orig then
            ISInventoryPage[fn] = function(self, ...)
                local pn = self.player or 0
                if TGI.Options.get("replaceVanilla") and TGI.usesGrid(pn) then
                    if self:getIsVisible() then self:setVisible(false) end
                    return
                end
                return orig(self, ...)
            end
        end
    end

    local setVis = ISInventoryPage.setVisible
    if setVis then
        ISInventoryPage.setVisible = function(self, v, ...)
            if v and TGI.Options.get("replaceVanilla") and TGI.usesGrid(self.player or 0) then v = false end
            return setVis(self, v, ...)
        end
    end

    local hl = ISInventoryPage.updateContainerHighlight
    if hl then
        ISInventoryPage.updateContainerHighlight = function(self, ...)
            if TGI.Options.get("replaceVanilla") and TGI.usesGrid(self.player or 0) and not TGI.Options.get("nearHighlight") then
                local c = self.isCollapsed
                self.isCollapsed = true
                local ok, r = pcall(hl, self, ...)
                self.isCollapsed = c
                return r
            end
            return hl(self, ...)
        end
    end
end
Events.OnGameStart.Add(guardPage)

local function containerOf(obj)
    if not obj then return nil end
    local c = obj.getContainer and obj:getContainer() or nil
    if c then return c end
    local n = obj.getContainerCount and obj:getContainerCount() or 0
    return n > 0 and obj:getContainerByIndex(0) or nil
end
local function onObjClick(obj)
    if not TGI.Options.get("replaceVanilla") or not TGI.usesGrid(0) then return end
    if TGI.inMenu and TGI.inMenu() then return end
    if TGI.pressOverUI then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() or p:getVehicle() or TGI.Drag and TGI.Drag.active then return end

    local now = getTimestampMs()
    if (p.isAiming and p:isAiming()) or isMouseButtonDown(1) then TGI.lastAim = now; return end
    if TGI.lastAim and now - TGI.lastAim < 400 then return end

    if TGI.radialAt and now - TGI.radialAt < 400 then return end

    local drag = nil
    pcall(function() drag = getCell():getDrag(0) end)
    if drag then TGI.dragAt = now; return end
    if TGI.dragAt and now - TGI.dragAt < 400 then return end

    local mapUp = false
    pcall(function() local m = rawget(_G, "ISWorldMap_instance"); mapUp = m ~= nil and m:isVisible() end)
    if mapUp then TGI.mapAt = now; return end
    if TGI.mapAt and now - TGI.mapAt < 400 then return end
    local sq = obj and obj.getSquare and obj:getSquare()
    local c = containerOf(obj)
    if not (sq and c) or sq:getZ() ~= p:getZ() then return end
    local dx, dy = sq:getX() + 0.5 - p:getX(), sq:getY() + 0.5 - p:getY()
    if dx * dx + dy * dy > 2.5 * 2.5 then return end

    local q = ISTimedActionQueue.getTimedActionQueue(p)
    if TGI.pendingOpen and TGI.pendingOpen.c == c then return end
    TGI.pendingOpen = { c = c, t = now, q = q and q.queue and #q.queue or 0 }
end

local function anyMenu()
    local v = false
    pcall(function() local m = getPlayerContextMenu(0); if m and m:isAnyVisible() then v = true end end)
    pcall(function() local r = getPlayerRadialMenu(0); if r and r:isReallyVisible() then v = true end end)
    return v
end

Events.OnTick.Add(function()
    local r = getPlayerRadialMenu and getPlayerRadialMenu(0)
    if r and r:isReallyVisible() then TGI.radialAt = getTimestampMs() end
end)

Events.OnTick.Add(function()
    local po = TGI.pendingOpen
    if not po then return end
    local now = getTimestampMs()
    if anyMenu() then TGI.pendingOpen = nil; return end
    if now - po.t < 150 then return end
    TGI.pendingOpen = nil
    local p = getSpecificPlayer(0)
    if not p then return end
    local q = ISTimedActionQueue.getTimedActionQueue(p)
    if q and q.queue and #q.queue > po.q then return end
    local W = TGI.Window
    W.focus = { c = po.c, t = now }
    if not W.instance then W.toggle(0) else pcall(function() W.instance:refreshContainers(true) end) end
end)

local wasDown = false
Events.OnTick.Add(function()
    local down = isMouseButtonDown(0)
    if down and not wasDown then
        local over = TGI.Drag and TGI.Drag.active ~= nil
        local W = TGI.Window
        local mx, my = getMouseX(), getMouseY()
        local function hit(e)
            return e and e:isReallyVisible() and mx >= e:getAbsoluteX() and my >= e:getAbsoluteY()
                and mx < e:getAbsoluteX() + e.width and my < e:getAbsoluteY() + e.height
        end
        if not over and TGI.Appliance and hit(TGI.Appliance.inst) then over = true end
        if W and not over then
            if hit(W.instance) then over = true end
            for _, f in pairs(W.bags or {}) do if hit(f) then over = true end end
        end

        if not over then
            pcall(function()
                local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
                local bd = W and W.instance and W.instance.backdrop
                local ui = UIManager.getUI()

                for i = ui:size() - 1, 0, -1 do
                    local e = ui:get(i)
                    if e and e:isVisible() and not (bd and e == bd.javaObject) then

                        local ew, eh = e:getWidth(), e:getHeight()

                        if not (ew >= sw * 0.9 and eh >= sh * 0.9) and e:isMouseOver() then
                            local t = e.getTable and e:getTable() or nil
                            local ty = string.lower(tostring(t and t.Type or ""))
                            local passive = ty:find("tooltip", 1, true) or (#ty > 3 and ty:sub(-3) == "tip")
                            if not passive then over = true; return end
                        end
                    end
                end
            end)
        end
        TGI.pressOverUI = over
    end
    wasDown = down
end)

Events.OnPlayerUpdate.Add(function(p)
    if p == getSpecificPlayer(0) and p.isAiming and p:isAiming() then TGI.lastAim = getTimestampMs() end
end)
if Events.OnObjectLeftMouseButtonUp then
    Events.OnObjectLeftMouseButtonUp.Add(function(obj) pcall(onObjClick, obj) end)
end

local function sidebarClick(self, button, ...)
    local pn = self.chr and self.chr:getPlayerNum() or 0
    if button and button.internal == "INVENTORY" and TGI.Options.get("replaceVanilla")
        and TGI.usesGrid and TGI.usesGrid(pn) and TGI.Window then
        local p = getSpecificPlayer(pn)
        if p and not p:isDead() then TGI.Window.toggle(pn) end
        return
    end
    return ISEquippedItem.onOptionMouseDown(self, button, ...)
end
local sideNext = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < sideNext then return end
    sideNext = now + 1000
    local eq = ISEquippedItem and ISEquippedItem.instance
    local b = eq and eq.invBtn
    if b and b.onclick ~= sidebarClick then b.onclick = sidebarClick end
end)

local aimHeld, aimPrev = nil, nil
local function overOurs()
    local W = TGI.Window
    if not W or not W.instance then return false end
    local mx, my = getMouseX(), getMouseY()
    local function hit(e)
        return e and e:isReallyVisible() and mx >= e:getAbsoluteX() and my >= e:getAbsoluteY()
            and mx < e:getAbsoluteX() + e.width and my < e:getAbsoluteY() + e.height
    end
    if hit(W.instance) then return true end
    for _, f in pairs(W.bags or {}) do if hit(f) then return true end end
    if TGI.Settings and hit(TGI.Settings.instance) then return true end
    return false
end
Events.OnTick.Add(function()
    local p = getSpecificPlayer(0)
    local want = p and not p:isDead() and overOurs() or false
    if aimHeld and (aimHeld ~= p or not want) then
        pcall(function() aimHeld:setIgnoreAimingInput(aimPrev and true or false) end)
        aimHeld, aimPrev = nil, nil
    end
    if want and not aimHeld then
        local okP, prev = pcall(function() return p:isIgnoringAimingInput() end)
        if okP then
            aimHeld, aimPrev = p, prev
            pcall(function() p:nullifyAiming() end)
            pcall(function() p:setIgnoreAimingInput(true) end)
        end
    end
end)
