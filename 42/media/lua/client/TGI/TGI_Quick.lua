require "ISUI/ISPanel"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
require "TGI/TGI_Drag"
require "TGI/TGI_Tooltip"
TGI = TGI or {}
local T, D = TGI.Theme, TGI.Draw
local Q = ISPanel:derive("TGIQuick")
TGI.Theme.applyAlpha(Q)
TGI.Quick = Q

local N = 4
local CELL = 52
local GAP = 6

local function player(pn) return getSpecificPlayer(pn or 0) end

function Q:new(pn)
    local o = ISPanel:new(0, 0, N * (CELL + GAP) + GAP, CELL + GAP * 2)
    setmetatable(o, self)
    self.__index = self
    o.pn = pn or 0
    o.background = false
    o.counts, o.nextCount = {}, 0
    return o
end

function Q:slots()
    local p = player(self.pn)
    if not p then return {} end
    local md = p:getModData()
    md.TGIquick = md.TGIquick or {}
    return md.TGIquick
end

local function shortType(ft) return string.match(ft or "", "%.([^%.]+)$") or ft end

function Q:findItem(ft)
    local p = player(self.pn)
    if not p or not ft then return nil end
    local it = nil

    pcall(function() it = p:getInventory():getFirstEvalRecurse(function(x) return x:getFullType() == ft end) end)
    if not it and not string.find(ft, ".", 1, true) then
        pcall(function() it = p:getInventory():getFirstTypeRecurse(shortType(ft)) end)
    end
    return it
end

local function woundPart(p)
    local best, score = nil, 0
    pcall(function()
        local parts = p:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local bp = parts:get(i)
            if not bp:bandaged() then
                local s = 0
                if bp:bleeding() then s = s + 5 end
                if bp:deepWounded() then s = s + 4 end
                if bp:bitten() then s = s + 3 end
                if bp:isCut() then s = s + 2 end
                if bp:scratched() then s = s + 1 end
                if s > score then best, score = bp, s end
            end
        end
    end)
    return best
end

function Q:use(i)
    local slot = self:slots()[i]
    local p = player(self.pn)
    if not slot or not p then return end
    local item = self:findItem(slot.ft)
    local function note(k) TGI.halo(p, getText(k), false) end
    if not item then return note("IGUI_TGI_QuickNone") end
    if TGI.Quick_isWeaponLike(item) then return note("IGUI_TGI_QuickNoWeapon") end
    local ok = false
    local canBandage = false
    pcall(function() canBandage = item:isCanBandage() end)
    if canBandage then
        local bp = woundPart(p)
        if not bp then return note("IGUI_TGI_QuickNoWound") end
        ok = pcall(ISInventoryPaneContextMenu.applyBandage, item, bp, self.pn)
    elseif string.find(string.lower(item:getType()), "pills", 1, true) then
        ok = pcall(ISInventoryPaneContextMenu.takePill, item, self.pn)
    elseif item:getFluidContainer() and not item:getFluidContainer():isEmpty() then

        ok = pcall(ISInventoryPaneContextMenu.onDrinkFluid, item, 1, p)
    elseif instanceof(item, "Food") then
        ok = pcall(ISInventoryPaneContextMenu.eatItem, item, 1, self.pn)
    else

        ok = TGI.Actions and TGI.Actions.equip(self.pn, item)
    end
    if not ok then note("IGUI_TGI_QuickCant") end
end

function Q:visible()
    local hide = TGI.Options and TGI.Options.get("hotbarHideEmpty") == true
    if hide then
        if TGI.Drag and TGI.Drag.active then hide = false end
        if TGI.Window and TGI.Window.instance and TGI.Window.instance:isReallyVisible() then hide = false end
    end
    local vis, pos, slots = {}, {}, self:slots()
    for i = 1, N do
        if not hide or slots[i] then vis[#vis + 1] = i; pos[i] = #vis end
    end
    self.vis, self.pos = vis, pos
    return vis
end
function Q:targetX(k) return GAP + (k - 1) * (CELL + GAP) end
function Q:cellRect(i)
    local k = self.pos and self.pos[i]
    local x
    if k then x = T.ease(self, "x" .. i, self:targetX(k))
    else x = T.easeGet(self, "x" .. i) or self:targetX(i) end
    local a = T.easeGet(self, "a" .. i) or (k and 1 or 0)
    return x, GAP + math.floor((1 - a) * (CELL + 10)), CELL, CELL
end
function Q:cellAt(x, y)
    if y < GAP or y >= GAP + CELL then return nil end
    for k, i in ipairs(self.vis or self:visible()) do
        local cx = self:targetX(k)
        if x >= cx and x < cx + CELL then return i end
    end
    return nil
end

function Q:keyFor(i)
    local k = TGI.Options and TGI.Options.key and TGI.Options.key("quick" .. i)
    return k
end

function Q:prerender()

    local vis = self:visible()
    local tw = (#vis == 0) and 0 or (#vis * (CELL + GAP) + GAP)
    local pf = T.ease(self, "panel", (#vis > 0) and 1 or 0)
    local bw = T.ease(self, "bgw", (#vis > 0) and tw or (T.easeGet(self, "bgw") or 0))
    self.panelFade = pf
    if pf < 0.02 then return end
    local by = math.floor((1 - pf) * (self.height + 10))
    self.tgiFade = pf
    self:drawRect(0, by, bw, self.height, 0.82, T.bg.r, T.bg.g, T.bg.b)
    T.metalFill(self, 0, by, bw, self.height, 0.55)
    self:drawRectBorder(0, by, bw, self.height, 1, T.border.r, T.border.g, T.border.b)
    self.tgiFade = nil
end

function Q:render()
    local now = getTimestampMs()
    local slots = self:slots()
    if now >= self.nextCount then
        self.nextCount = now + 500
        local p = player(self.pn)
        for i = 1, N do
            local s = slots[i]
            local n = 0
            if s and p then pcall(function() n = p:getInventory():getCountTypeRecurse(s.ft) end) end
            self.counts[i] = n
        end
    end
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver() and self:cellAt(mx, my) or nil
    local d = TGI.Drag and TGI.Drag.active
    for i = 1, N do
      local sa = T.ease(self, "a" .. i, (self.pos and self.pos[i]) and 1 or 0)
      if sa >= 0.02 then
        self.tgiFade = sa
        local x, y, w, h = self:cellRect(i)
        local s = slots[i]
        self:drawRect(x, y, w, h, 0.9, T.cell.r, T.cell.g, T.cell.b)
        if s then
            local n = self.counts[i] or 0
            local tex = s.tex and getTexture(s.tex)
            if tex then self:drawTextureScaledAspect(tex, x + 6, y + 8, w - 12, h - 18, n > 0 and 1 or 0.3, 1, 1, 1) end
            local cr, cg, cb = 1, 1, 1
            if n == 0 then cr, cg, cb = 0.95, 0.35, 0.3 end
            self:drawTextRight(tostring(n), x + w - 3, y + h - 15, cr, cg, cb, 1, UIFont.Small)

            if n > 0 and TGI.Draw and TGI.Draw.powerBadge then
                self.powerItem = self.powerItem or {}
                if now >= (self.nextPower or 0) then
                    for k = 1, N do self.powerItem[k] = slots[k] and self:findItem(slots[k].ft) or nil end
                    self.nextPower = now + 500
                end
                TGI.Draw.powerBadge(self, self.powerItem[i], x + 3, y + h - 12)
            end
            self:drawRectBorder(x, y, w, h, 0.9, n > 0 and T.accent.r or 0.6, n > 0 and T.accent.g or 0.2, n > 0 and T.accent.b or 0.2)
        else
            self:drawRectBorder(x, y, w, h, 0.7, T.border.r, T.border.g, T.border.b)
            self:drawTextCentre("+", x + w / 2, y + h / 2 - 8, T.dim.r, T.dim.g, T.dim.b, 0.6, UIFont.Small)
        end

        local k = self:keyFor(i)
        local kn = k and k > 0 and Keyboard.getKeyName(k) or tostring(i)
        self:drawRect(x + 1, y + 1, 20, 13, 0.85, 0.02, 0.02, 0.02)
        self:drawTextCentre(kn, x + 11, y, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
        if d and i == over then self:drawRect(x, y, w, h, 0.3, 0.3, 0.9, 0.4)
        elseif i == over then self:drawRect(x, y, w, h, 0.1, 1, 1, 1) end
      end
    end
    self.tgiFade = nil

    if over and slots[over] and not d then
        local it = self:findItem(slots[over].ft)
        if it then TGI.Tip.show(it, self, self.pn, {}) else TGI.Tip.hide(self) end
    else
        TGI.Tip.hide(self)
    end
end

function Q:onMouseDown(x, y)
    local i = self:cellAt(x, y)
    self.press = i and { i = i, x = getMouseX(), y = getMouseY() } or nil
    return true
end
function Q:tryDrag()
    local pr = self.press
    if not pr or (TGI.Drag and TGI.Drag.active) or not isMouseButtonDown(0) then return end
    if math.abs(getMouseX() - pr.x) + math.abs(getMouseY() - pr.y) <= 5 then return end
    self.press = nil
    local slot = self:slots()[pr.i]
    local item = slot and self:findItem(slot.ft)
    if not item then return end
    local w, h = 1, 1
    pcall(function() w, h = TGI.Size.of(item) end)
    local e = { key = "q:" .. item:getID(), item = item, items = { item }, w = w, h = h }
    TGI.Drag.start(self.pn, e, { quick = pr.i }, 0, 0, false, nil)
end
function Q:onMouseMove(dx, dy) self:tryDrag() end
function Q:onMouseMoveOutside(dx, dy) self:tryDrag(); TGI.Tip.hide(self) end
function Q:onMouseUp(x, y)
    local pr = self.press
    self.press = nil
    if TGI.Drag and TGI.Drag.active then TGI.Drag.finish(); return true end
    local i = self:cellAt(x, y)
    if i and pr and pr.i == i then self:use(i) end
    return true
end
function Q:onMouseUpOutside(x, y) self.press = nil end
function Q:onRightMouseUp(x, y)
    local i = self:cellAt(x, y)
    if i then
        local s = self:slots()
        s[i] = nil
        local p = player(self.pn)
        if p and isClient() then pcall(function() p:transmitModData() end) end
    end
    return true
end

function TGI.Quick_isWeaponLike(item)
    local ok = false
    pcall(function()
        if instanceof(item, "HandWeapon") then
            ok = TGI.Model.isRealWeapon(item) and not string.find(string.lower(tostring(item:getDisplayCategory())), "explosive", 1, true)
        elseif instanceof(item, "InventoryContainer") or instanceof(item, "Clothing") then ok = true end
    end)
    return ok
end

function Q:tgiContains(ax, ay)
    if not self:isReallyVisible() then return false end
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    return ax >= x and ay >= y and ax < x + self.width and ay < y + self.height
end
function Q:tgiDropAt(ax, ay, d)
    local i = self:cellAt(ax - self:getAbsoluteX(), ay - self:getAbsoluteY())
    local item = d.entry and d.entry.item

    if d.source and d.source.quick then
        if i and i ~= d.source.quick then
            local s = self:slots()
            s[i], s[d.source.quick] = s[d.source.quick], s[i]
            local p = player(self.pn)
            if p and isClient() then pcall(function() p:transmitModData() end) end
        end
        return true
    end
    if item and TGI.Quick_isWeaponLike(item) then
        TGI.halo(player(self.pn), getText("IGUI_TGI_QuickNoWeapon"), false)
        return true
    end
    if i and item then
        local tex = nil
        pcall(function() tex = item:getTex():getName() end)
        self:slots()[i] = { ft = item:getFullType(), tex = tex }
        local p = player(self.pn)
        if p and isClient() then pcall(function() p:transmitModData() end) end
    end
    return true
end

function Q:update()
    ISPanel.update(self)
    local fullW = N * (CELL + GAP) + GAP
    if self.width ~= fullW then self:setWidth(fullW) end
    local hb = getPlayerHotbar and getPlayerHotbar(self.pn)

    if hb and not hb:isVisible() and self.pn == 0 and JoypadState and JoypadState.players[1]
        and TGI.Window and TGI.Window.instance and (not TGI.Options or TGI.Options.get("hotbarStyle") ~= false) then
        hb:setVisible(true)
    end
    if hb and hb:isVisible() then
        local right = hb.tgiBgw and (hb.tgiBgx + hb.tgiBgw) or hb:getWidth()
        if right < 2 then right = hb:getWidth() / 2 end
        self:setX(hb:getX() + right + 8)
        self:setY(hb:getY() + hb:getHeight() - self.height)
    else
        local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
        self:setX(sw / 2 + 200); self:setY(sh - self.height - 4)
    end
    local p = player(self.pn)
    local show = (p ~= nil and not p:isDead() and (not TGI.Options or TGI.Options.get("quickSlots") ~= false)) == true
    if self:getIsVisible() ~= show then self:setVisible(show) end
end

function Q.create(pn)
    if Q.inst then return end
    local q = Q:new(pn or 0)
    q:initialise()
    q:addToUIManager()
    TGI.Drag.register(q)
    Q.inst = q
end

local function onKey(key)
    local q = Q.inst
    if not q or not q:getIsVisible() then return end
    if TGI.inMenu and TGI.inMenu() then return end
    if TGI.Window and TGI.Window.typing and TGI.Window.typing() then return end
    for i = 1, N do
        local k = q:keyFor(i)
        if k and k > 0 and key == k then q:use(i); return end
    end
end

local function freeKeys()
    if TGI.Options and TGI.Options.get("quickSlots") == false then return end
    local ours = {}
    for i = 1, N do local k = TGI.Options.key("quick" .. i); if k then ours[k] = true end end

    local OLD = { TOGGLE_SURVIVAL_GUIDE = "Toggle Survival Guide", PAUSE = "Pause", NORMAL_SPEED = "Normal Speed",
        FAST_FORWARD_X1 = "Fast Forward x1", FAST_FORWARD_X2 = "Fast Forward x2", FAST_FORWARD_X3 = "Fast Forward x3" }
    for name, old in pairs(OLD) do
        local id = (KeybindId and KeybindId[name]) or old
        pcall(function()
            if ours[getCore():getKey(id)] then
                getCore():addKeyBinding(id, 0, 0, false, false, false)
            end
        end)
    end
end

Events.OnGameStart.Add(function() Q.create(0); freeKeys() end)
Events.OnKeyPressed.Add(onKey)
return Q
