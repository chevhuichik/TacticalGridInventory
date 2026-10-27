require "ISUI/ISUIElement"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
require "TGI/TGI_Actions"

TGI = TGI or {}
local T, D, A, G = TGI.Theme, TGI.Draw, TGI.Actions, TGI.Grid
local Drag = { active = nil, targets = {} }
TGI.Drag = Drag

local Ghost = ISUIElement:derive("TGIGhost")

if TGI.Theme and TGI.Theme.applyFont then TGI.Theme.applyFont(Ghost) end
function Ghost:new()
    local o = ISUIElement:new(0, 0, 10, 10)
    setmetatable(o, self)
    self.__index = self
    o.anchorLeft, o.anchorTop = true, true
    return o
end
function Ghost:render()
    local d = Drag.active
    if not d then return end
    if d.multi or type(d.split) == "number" then
        local n = d.multi and #d.multi or d.split
        local C = T.CELL
        self:setX(TGI.mx() - C / 2); self:setY(TGI.my() - C / 2)
        self:setWidth(C); self:setHeight(C)
        D.tile(self, d.entry, 0, 0, C, C, 0.8, false)
        self:drawRect(0, C - 16, C, 16, 0.8, 0, 0, 0)
        self:drawTextCentre("x" .. n, C / 2, C - 16, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
        return
    end
    local C = T.CELL
    local dw, dh = G.dims(d.entry.w, d.entry.h, d.rot)
    self:setX(TGI.mx() - (d.grabX + 0.5) * C)
    self:setY(TGI.my() - (d.grabY + 0.5) * C)
    self:setWidth(dw * C); self:setHeight(dh * C)
    D.tile(self, d.entry, 0, 0, dw * C, dh * C, 0.75, d.rot)
end
function Ghost:onMouseUp() Drag.finish(); return true end

function Ghost:onMouseWheel(del)
    local w = TGI.Window and TGI.Window.instance
    if not w then return true end
    local mx = TGI.mx()
    for _, col in ipairs({ w.mine, w.loot }) do
        local ax = col:getAbsoluteX()
        if mx >= ax and mx < ax + col.width then col:onMouseWheel(del) end
    end
    return true
end
function Ghost:onMouseUpOutside() Drag.finish(); return true end

function Drag.register(t) Drag.targets[t] = true end
function Drag.unregister(t) Drag.targets[t] = nil end

function Drag.start(pn, entry, source, grabX, grabY, rot, split)
    Drag.active = { pn = pn, entry = entry, source = source, grabX = grabX or 0, grabY = grabY or 0,
                    rot = rot and true or false, split = split }
    if not Drag.ghost then
        Drag.ghost = Ghost:new()
        Drag.ghost:initialise()
    end
    Drag.ghost:addToUIManager()
    Drag.ghost:setAlwaysOnTop(true)
    Drag.ghost:bringToTop()
end

function Drag.rotate()
    local d = Drag.active
    if not d then return end
    d.rot = not d.rot
    d.grabX, d.grabY = d.grabY, d.grabX
end

function Drag.cancel()
    Drag.active = nil
    if Drag.ghost then Drag.ghost:removeFromUIManager() end
end

function Drag.items(d)
    if d.multi then return d.multi end
    local items = d.entry.items
    if type(d.split) == "number" and #items > 1 then
        local out = {}
        for i = 1, math.min(d.split, #items) do out[i] = items[i] end
        return out
    end
    if d.split and #items > 1 then
        local n = math.floor(#items / 2)
        local out = {}
        for i = 1, n do out[i] = items[i] end
        return out
    end
    return items
end

function Drag.finish()
    local d = Drag.active
    if not d then return end
    local ok, err = pcall(Drag._finish, d)
    if not ok then print("[TGI] drop failed: " .. tostring(err)) end
    Drag.cancel()
end

local function inside(el, mx, my)

    if type(el) ~= "table" or not el.getAbsoluteX or not el.isReallyVisible or not el.getWidth then return false end
    local ok, r = pcall(function()
        local x, y = el:getAbsoluteX(), el:getAbsoluteY()
        return el:isReallyVisible() and mx >= x and my >= y and mx < x + el:getWidth() and my < y + el:getHeight()
    end)
    return ok and r
end
local function findBox(el, mx, my, depth)
    if depth > 8 or not inside(el, mx, my) then return nil end
    if ISItemDropBox and el.defaultVerifyItem == ISItemDropBox.defaultVerifyItem then return el end
    for _, c in pairs(el.children or {}) do
        local b = findBox(c, mx, my, depth + 1)
        if b then return b end
    end
end
local function dropOnBox(d, mx, my)
    if not ISItemDropBox then return false end
    local ui = UIManager.getUI()
    for i = ui:size() - 1, 0, -1 do
        local t = ui:get(i):getTable()
        local box = t and findBox(t, mx, my, 0)
        if box then

            if not box.mouseEnabled or box.isLocked or (not box.allowDropAlways and box.boxOccupied) then return true end
            local verify = box.onVerifyItem or box.defaultVerifyItem
            local items = {}
            for _, it in ipairs(Drag.items(d)) do
                local ok, good = pcall(verify, box.functionTarget, it)
                if ok and good then items[#items + 1] = it end
            end
            if #items == 0 then return true end
            if box.onItemDropped then pcall(box.onItemDropped, box.functionTarget, items)
            else pcall(function() box:itemDropped(items) end) end
            return true
        end
    end
    return false
end

local function foreign(t)
    local ty = type(t) == "table" and t.Type or nil
    return ty and not string.find(ty, "^TGI") and ty ~= "ISHotbar" and ty ~= "ISInventoryPage" and ty ~= "ISMouseDrag"
end
local function deepest(el, mx, my, depth)
    if depth > 10 or not inside(el, mx, my) then return nil end
    for _, c in pairs(el.children or {}) do
        local hit = deepest(c, mx, my, depth + 1)
        if hit then return hit end
    end
    if el.onMouseUp then return el end
end
local function dropOnForeign(d, mx, my)
    if TGI.Options.get("dragBridge") == false or not ISMouseDrag then return false end
    local ui = UIManager.getUI()
    for i = ui:size() - 1, 0, -1 do
        local t = ui:get(i):getTable()
        local see = t and (t.Type == "TGIBackdrop" or t.Type == "TGIGhost" or t.Type == "TGITooltip" or t.Type == "TGIHealthTip")
        if t and not see and inside(t, mx, my) then
            if not foreign(t) then return false end
            local el = deepest(t, mx, my, 0)
            if not el then return false end
            local items = Drag.items(d)
            if #items == 0 then return false end
            ISMouseDrag.dragging = items
            ISMouseDrag.dragOwner = nil
            pcall(function() el:onMouseUp(mx - el:getAbsoluteX(), my - el:getAbsoluteY()) end)
            ISMouseDrag.dragging = nil
            ISMouseDrag.dragOwner = nil
            return true
        end
    end
    return false
end

function Drag._finish(d)
    local mx, my = TGI.mx(), TGI.my()
    if dropOnBox(d, mx, my) then return end
    if dropOnForeign(d, mx, my) then Drag.cancel(); return end
    local handled, over = false, false

    local order, rest = {}, {}
    for t in pairs(Drag.targets) do
        if t.tgiBagGrid or (t.parent and t.parent.bag) then order[#order + 1] = t else rest[#rest + 1] = t end
    end
    for _, t in ipairs(rest) do order[#order + 1] = t end
    for _, t in ipairs(order) do
        if t:isReallyVisible() and t:tgiContains(mx, my) then
            if t ~= TGI.Window.instance then over = true end
            handled = t:tgiDropAt(mx, my, d)
            if handled ~= nil then d.target = t; break end
        end
    end
    local W = TGI.Window and TGI.Window.instance

    if W and d.source and d.source.quick and not (d.target and d.target == (TGI.Quick and TGI.Quick.inst)) then
        local q = TGI.Quick and TGI.Quick.inst
        if q then
            q:slots()[d.source.quick] = nil
            local p = getSpecificPlayer(d.pn)
            if p and isClient() then pcall(function() p:transmitModData() end) end
        end
        if not handled then return end
    end

    if not handled and not W and not over and d.source and (d.source.quick or d.source.hotbar) then
        local p = getSpecificPlayer(d.pn)
        for _, it in ipairs(Drag.items(d)) do
            if it:isFavorite() then TGI.halo(p, getText("IGUI_TGI_Locked"), false)
            elseif TGI.Actions.noFloorMoveable(it) then TGI.Actions.placeMoveable(d.pn, it)
            else ISInventoryPaneContextMenu.dropItem(it, d.pn) end
        end
    end
    if not handled and W and (not over or not W:tgiContains(mx, my)) then

        local p = getSpecificPlayer(d.pn)
        local src = d.source and d.source.model and d.source.model.container
        if p and (d.source and (d.source.slot or d.source.quick or d.source.hotbar) or (src and src:getType() ~= "floor")) then
            local floor, fp = nil, nil
            for _, panel in ipairs(W.loot and W.loot.panels or {}) do
                local c = panel.model and panel.model.container
                if c and c:getType() == "floor" then floor = c; fp = panel; break end
            end
            local list = {}
            for _, it in ipairs(Drag.items(d)) do
                if it:isFavorite() and it:isInPlayerInventory() then TGI.halo(p, getText("IGUI_TGI_Locked"), false)
                else list[#list + 1] = it end
            end
            if floor then

                pcall(function()
                    local m = fp.model
                    m:ensure()
                    local pi, x, y, rot = m:findSpotFor(d.entry)
                    if pi then for _, it in ipairs(list) do TGI.Actions.setPending(it, m:layoutSig(), pi, x, y, rot) end end
                end)
                TGI.Actions.transfer(d.pn, list, floor)
                W.refreshSoon = getTimestampMs() + 4000
            else
                for _, it in ipairs(list) do
                    if TGI.Actions.noFloorMoveable(it) then TGI.Actions.placeMoveable(d.pn, it)
                    elseif it:isInPlayerInventory() then ISInventoryPaneContextMenu.dropItem(it, d.pn) end
                end
            end
        end
    end
    Drag.cancel()
end

local upTicks = 0

local vUp = 0
local function vanillaDrop()
    local items = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    ISMouseDrag.dragging = nil
    ISMouseDrag.dragOwner = nil
    local mx, my = getMouseX(), getMouseY()
    for t in pairs(Drag.targets) do
        local c = t.model and t.model.container
        if c and t:isReallyVisible() and t:tgiContains(mx, my) then

            local list = {}
            for _, it in ipairs(items or {}) do
                if it:getContainer() ~= c and not it:isFavorite() then list[#list + 1] = it end
            end
            if #list > 0 and TGI.Actions then TGI.Actions.transfer(t.pn or 0, list, c) end
            return
        end
    end
end
Events.OnTick.Add(function()
    if ISMouseDrag and ISMouseDrag.dragging and TGI.Window and TGI.Window.instance and not Drag.active then
        if isMouseButtonDown(0) then vUp = 0
        else
            vUp = vUp + 1
            if vUp >= 2 then vUp = 0; pcall(vanillaDrop) end
        end
    else vUp = 0 end
    if not Drag.active then upTicks = 0; return end
    if Drag.active.sticky then

        if isMouseButtonDown(1) or isKeyDown(Keyboard.KEY_ESCAPE) then
            Drag.justCancelled = getTimestampMs()
            Drag.cancel()
        end
        return
    end
    if isMouseButtonDown(0) then upTicks = 0; return end
    upTicks = upTicks + 1
    if upTicks >= 3 then upTicks = 0; Drag.finish() end
end)

return Drag
