require "Hotbar/ISHotbar"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
require "TGI/TGI_Drag"
require "TGI/TGI_Tooltip"
TGI = TGI or {}
local T, D = TGI.Theme, TGI.Draw

T.applyAlpha(ISHotbar)
local origRender = ISHotbar.render
local origPrerender = ISHotbar.prerender

function ISHotbar:prerender()

    if TGI.Options and TGI.Options.get("hotbarStyle") ~= false then return end
    if origPrerender then return origPrerender(self) end
end
local origUpdate = ISHotbar.update

local function keyName(self, i)
    local ok, k = pcall(function() return self:getKeyForIndex(i) end)
    if ok and k and k > 0 then
        local okn, n = pcall(Keyboard.getKeyName, k)
        if okn and n then return n end
    end
    return tostring(i)
end

local ammoCache, ammoN = {}, 0
local function shortT(ft) return string.match(tostring(ft or ""), "%.([^%.]+)$") or tostring(ft or "") end

local rackKey, rackAt = "", 0
local function rackKeyName()
    local now = getTimestampMs()
    if now - rackAt > 5000 then
        rackAt = now
        rackKey = ""
        pcall(function()
            local k = getCore():getKey("Rack Firearm")
            if k and k > 0 then rackKey = " [" .. Keyboard.getKeyName(k) .. "]" end
        end)
    end
    return rackKey
end

function TGI.ammoInfo(p, gun)
    local id = gun:getID()
    local c = ammoCache[id]
    local now = getTimestampMs()
    if c and now - c.t < 1000 then return c end
    c = { t = now, cur = 0, max = 0, mags = 0, loose = 0 }
    pcall(function() c.cur = gun:getCurrentAmmoCount(); c.max = gun:getMaxAmmo() end)

    c.chamberGun, c.chambered = false, false
    pcall(function()
        if gun:haveChamber() then
            c.chamberGun = true
            c.chambered = gun:isRoundChambered()
        end
    end)
    local inv = p:getInventory()
    pcall(function()
        local mt = gun:getMagazineType()
        if mt and mt ~= "" then c.mags = inv:getCountTypeRecurse(shortT(mt)) end
    end)
    pcall(function()
        local at = gun:getAmmoType()
        local key = at and (at.getItemKey and at:getItemKey()) or at
        if key then c.loose = inv:getCountTypeRecurse(shortT(key)) end
    end)
    if not ammoCache[id] then
        ammoN = (ammoN or 0) + 1
        if ammoN > 50 then ammoCache, ammoN = {}, 1 end
    end
    ammoCache[id] = c
    return c
end

function ISHotbar:tgiHideEmpty()
    return TGI.Options and TGI.Options.get("hotbarStyle") ~= false and TGI.Options.get("hotbarHideEmpty") == true
end
function ISHotbar:tgiBuildVisible()
    local vis, pos = {}, {}
    local dragging = (TGI.Drag and TGI.Drag.active) or ISMouseDrag.dragging

    local invOpen = TGI.Window and TGI.Window.instance ~= nil and TGI.Window.instance:getIsVisible()
    local hide = self:tgiHideEmpty() and not dragging and not invOpen
    for i = 1, #self.availableSlot do
        if not hide or self.attachedItems[i] then vis[#vis + 1] = i; pos[i] = #vis end
    end
    self.tgiVis, self.tgiPos = vis, pos
    return vis
end

function ISHotbar:tgiLayout()
    local n = #(self.tgiVis or {})
    local total = (n == 0) and 0 or (n * self.slotWidth + (n - 1) * self.slotPad + self.margins * 2 + 2)
    self.tgiOx = math.floor((self.width - total) / 2)
    self.tgiTotal = total
end
function ISHotbar:tgiTargetX(k) return (self.tgiOx or 0) + self.margins + 1 + (k - 1) * (self.slotWidth + self.slotPad) end
function ISHotbar:tgiSlotRect(i)
    local k = self.tgiPos and self.tgiPos[i]
    local x
    if k then x = T.ease(self, "x" .. i, self:tgiTargetX(k))
    else x = T.easeGet(self, "x" .. i) or self:tgiTargetX(i) end
    local a = T.easeGet(self, "a" .. i) or (k and 1 or 0)
    local dy = math.floor((1 - a) * (self.slotHeight + 8))
    return x, self.margins + 1 + dy, self.slotWidth, self.slotHeight
end
local origIndexAt = ISHotbar.getSlotIndexAt
function ISHotbar:getSlotIndexAt(x, y)
    if TGI.Options and TGI.Options.get("hotbarStyle") == false or not self.tgiVis then return origIndexAt(self, x, y) end
    if y < 0 or y >= self.height then return -1 end
    for k, i in ipairs(self.tgiVis) do
        local sx = self:tgiTargetX(k)
        if x >= sx - self.slotPad / 2 and x < sx + self.slotWidth + self.slotPad / 2 then return i end
    end
    return -1
end

function ISHotbar:render()
    if not TGI.Options or TGI.Options.get("hotbarStyle") == false then return origRender(self) end

    local gridOpen = TGI.Window and TGI.Window.instance and TGI.Window.instance.pn == self.playerNum
    if (self.playerNum > 0) or (JoypadState.players[self.playerNum + 1] and not gridOpen) then
        self:setVisible(false)
    end
    local vis = self:tgiBuildVisible()
    self:tgiLayout()

    local pf = T.ease(self, "panel", (#vis > 0) and 1 or 0)
    local empty = pf < 0.02
    local bgx = T.ease(self, "bgx", (#vis > 0) and self.tgiOx or (T.easeGet(self, "bgx") or self.tgiOx))
    local bgw = T.ease(self, "bgw", (#vis > 0) and self.tgiTotal or (T.easeGet(self, "bgw") or 0))
    local bgy = math.floor((1 - pf) * (self.height + 10))
    self.tgiBgx, self.tgiBgw = bgx, bgw
    self.tgiFade = pf
    if not empty then self:drawRect(bgx, bgy, bgw, self.height, 0.82, T.bg.r, T.bg.g, T.bg.b) end

    self.tgiFade = nil
    self.tgiAct = D.currentAction(self.chr)
    if self.tgiAct and self.tgiAct.frac > 0 and TGI.Options.get("actionBar") ~= false then
        local act = self.tgiAct
        local bw = 220
        local bx = math.floor(bgx + (bgw - bw) / 2)
        local by = -42
        self:drawRect(bx, by, bw, 18, 0.8, T.bg.r, T.bg.g, T.bg.b)
        self:drawRectBorder(bx, by, bw, 18, 0.9, T.border.r, T.border.g, T.border.b)
        self:drawRect(bx + 2, by + 2, (bw - 4) * math.min(1, act.frac), 14, 0.55, T.accent.r, T.accent.g, T.accent.b)
        local label = act.name
        if act.item and act.item.getDisplayName then label = label .. ": " .. act.item:getDisplayName() end
        label = D._short(label, bw - 8, UIFont.Small)
        self:drawTextCentre(label, bx + bw / 2, by + 1, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
    self.tgiFade = pf
    if not empty then
        T.metalFill(self, bgx, bgy, bgw, self.height, 0.55)
        self:drawRectBorder(bgx, bgy, bgw, self.height, 1, T.border.r, T.border.g, T.border.b)
    end

    local p = self.chr
    local parts = {}
    pcall(function()
        local wt, mw = p:getInventoryWeight(), p:getMaxWeight()
        local f = wt / math.max(1, mw)
        parts[#parts + 1] = { string.format("%.1f/%.0f", wt, mw), f > 1 and { 1, 0.35, 0.3 } or (f > 0.75 and { 1, 0.8, 0.35 } or { 0.5, 0.9, 0.5 }), icon = D.tex("ic_weight") }
    end)
    pcall(function()
        for _, h in ipairs({ p:getPrimaryHandItem(), p:getSecondaryHandItem() }) do
            if h and h:isTorchCone() and instanceof(h, "DrainableComboItem") then
                local u = h:getCurrentUsesFloat()
                parts[#parts + 1] = { string.format("%d%%", math.floor(u * 100 + 0.5)), u < 0.2 and { 1, 0.35, 0.3 } or { 0.9, 0.85, 0.5 }, icon = h:getTex() }
                break
            end
        end
    end)
    pcall(function()
        local g = p:getPrimaryHandItem()
        if g and instanceof(g, "HandWeapon") and g:isRanged() then
            local a = TGI.ammoInfo(p, g)
            local ch = ""
            if a.chamberGun then ch = a.chambered and " +1" or (" " .. getText("IGUI_TGI_Rack")) end
            parts[#parts + 1] = { string.format("%d/%d%s  +%d", a.cur, a.max, ch, a.loose),
                (a.cur == 0 or (a.chamberGun and not a.chambered)) and { 1, 0.45, 0.3 } or { 0.9, 0.9, 0.85 },
                icon = D.tex("ic_ammo") }
        end
    end)
    local ix = math.floor(bgx) + 4
    if TGI.Options.get("hotbarInfo") == false or empty then parts = {} end
    local ifh = getTextManager():getFontHeight(UIFont.Small)
    local ibh = math.max(15, ifh)
    for _, pt in ipairs(parts) do
        local iw = pt.icon and 15 or 0
        local tw = TGI.Theme.measure(UIFont.Small, pt[1]) + 10 + iw
        local by = bgy - ibh - 2
        self:drawRect(ix, by, tw, ibh, 0.75, T.bg.r, T.bg.g, T.bg.b)
        self:drawRectBorder(ix, by, tw, ibh, 0.8, T.border.r, T.border.g, T.border.b)
        if pt.icon then self:drawTextureScaledAspect(pt.icon, ix + 3, by + (ibh - 13) / 2, 13, 13, 1, 1, 1, 1) end
        self:drawText(pt[1], ix + 5 + iw, by + (ibh - ifh) / 2, pt[2][1], pt[2][2], pt[2][3], 1, UIFont.Small)
        ix = ix + tw + 4
    end
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:getSlotIndexAt(mx, my)
    local d = TGI.Drag and TGI.Drag.active
    local dragItem = d and d.entry and d.entry.item
    local vanillaDrag = ISMouseDrag.dragging and ISInventoryPane.getActualItems(ISMouseDrag.dragging) or nil

    for i = 1, #self.availableSlot do
      local sa = T.ease(self, "a" .. i, (self.tgiPos and self.tgiPos[i]) and 1 or 0)
      if sa >= 0.02 then
        self.tgiFade = sa
        local slot = self.availableSlot[i]
        local x, y, w, h = self:tgiSlotRect(i)
        local item = self.attachedItems[i]

        self:drawRect(x, y, w, h, 0.9, T.cell.r, T.cell.g, T.cell.b)
        T.metalFill(self, x, y, w, h, 0.5)
        if item then
            local r, g, b = T.tileColor(item)
            self:drawRect(x + 1, y + 1, w - 2, h - 2, 0.16, r, g, b)
            self:drawRectBorder(x, y, w, h, 0.9, r * 0.6 + 0.16, g * 0.6 + 0.16, b * 0.6 + 0.16)
            local tex = item:getTex()
            if tex then D.icon(self, tex, x + 5, y + 12, w - 10, h - 26, 1, D.isFlipped(item), 0, D.iconTint(item)) end

            local cm = item:getConditionMax()
            if cm and cm > 0 and item:getCondition() < cm then
                local f = item:getCondition() / cm
                self:drawRect(x + 3, y + h - 12, w - 6, 3, 0.8, 0, 0, 0)
                self:drawRect(x + 3, y + h - 12, (w - 6) * f, 3, 0.9, 1 - f, f, 0.15)
            end
            if TGI.Options.get("hotbarAmmo") ~= false and instanceof(item, "HandWeapon") and item:isRanged() then
                local a = TGI.ammoInfo(self.chr, item)
                local ar, ag, ab = 0.9, 0.9, 0.85
                if a.cur == 0 then ar, ag, ab = 1, 0.3, 0.25 elseif a.max > 0 and a.cur <= a.max / 4 then ar, ag, ab = 1, 0.75, 0.3 end

                local cur = a.cur .. "/" .. a.max
                if a.chamberGun then cur = (a.chambered and "+1 " or "") .. cur end
                if a.chamberGun and not a.chambered and a.cur > 0 then

                    ar, ag, ab = 1, 0.55, 0.2
                    self:drawText(getText("IGUI_TGI_Rack") .. rackKeyName(), x + 3, y + 15, 1, 0.55, 0.2, 1, UIFont.NewSmall or UIFont.Small)
                end
                self:drawTextRight(cur, x + w - 2, y + 1, 0, 0, 0, 0.8, UIFont.Small)
                self:drawTextRight(cur, x + w - 3, y, ar, ag, ab, 1, UIFont.Small)
                local spare = (a.mags > 0 and (a.mags .. "m ") or "") .. (a.loose > 0 and ("+" .. a.loose) or "")
                if spare ~= "" then
                    local sf = UIFont.NewSmall or UIFont.Small
                    self:drawTextRight(spare, x + w - 2, y + h - 22, 0, 0, 0, 0.8, sf)
                    self:drawTextRight(spare, x + w - 3, y + h - 23, T.text.r, T.text.g, T.text.b, 0.9, sf)
                end
                if a.cur == 0 then self:drawRectBorder(x, y, w, h, 0.5 + 0.4 * math.abs(math.sin(getTimestampMs() / 250)), 1, 0.25, 0.2) end
            end
            D.powerBadge(self, item, x + 3, y + 3)

            local fs, rs = D.freshState(item), D.rawState(item)
            local sx = x + w - 14
            if fs then local c = D.FRESH_COL[fs]; D.mark(self, fs == "rotten" and "ic_infect" or "ic_clock", sx, y + 16, 11, c[1], c[2], c[3], 1); sx = sx - 12 end
            if rs then local c = D.RAW_COL[rs]; D.mark(self, rs == "burnt" and "ic_burn" or "ic_food", sx, y + 16, 11, c[1], c[2], c[3], 1) end

            if self.tgiAct and (self.tgiAct.item == item or self.tgiAct.gun == item) then
                D.progress(self, x, y, w, h, self.tgiAct.frac)
            end
            if item:isEquipped() then
                self:drawRectBorder(x - 1, y - 1, w + 2, h + 2, 1, T.accent.r, T.accent.g, T.accent.b)
                if not (instanceof(item, "HandWeapon") and item:isRanged()) then
                    self:drawTextRight("E", x + w - 3, y + 1, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
                end
            end
        else
            self:drawRectBorder(x, y, w, h, 0.8, T.border.r, T.border.g, T.border.b)

            if self.tgiAct and self.tgiAct.slotIndex == i then D.progress(self, x, y, w, h, self.tgiAct.frac) end
            if slot.texture then
                self:drawTextureScaledAspect(slot.texture, x + 10, y + 10, w - 20, h - 24, 0.25, 1, 1, 1)
            end
        end

        self:drawRect(x + 1, y + 1, 16, 14, 0.85, 0.02, 0.02, 0.02)
        self:drawTextCentre(keyName(self, i), x + 9, y, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
        local name = getTextOrNull("IGUI_HotbarAttachment_" .. tostring(slot.slotType)) or slot.name or ""
        local nf = UIFont.NewSmall or UIFont.Small
        self:drawTextCentre(D._short(name, w - 4, nf), x + w / 2, y + h - math.max(11, getTextManager():getFontHeight(nf) - 1), T.dim.r, T.dim.g, T.dim.b, 1, nf)

        local cand = dragItem
        if not cand and vanillaDrag then cand = vanillaDrag[1] end
        if cand then
            local ok = self:canBeAttached(slot, cand)
            if ok then
                local a = (i == over) and 0.35 or 0.12
                self:drawRect(x, y, w, h, a, 0.3, 0.9, 0.4)
                self:drawRectBorder(x, y, w, h, 1, 0.35, 0.9, 0.4)
            elseif i == over then
                self:drawRect(x, y, w, h, 0.3, 0.9, 0.2, 0.2)
            end
        elseif i == over then
            self:drawRect(x, y, w, h, 0.1, 1, 1, 1)
        end
      end
    end
    self.tgiFade = nil
    TGI.hotbarTip(self)
end

function TGI.hotbarTip(self)
    local i = self:getSlotIndexAt(self:getMouseX(), self:getMouseY())
    local item = (i ~= -1) and self.attachedItems[i] or nil
    if item and self:isMouseOver() and not getPlayerContextMenu(self.playerNum):isAnyVisible() then
        TGI.Tip.show(item, self, self.playerNum, {})
    else
        TGI.Tip.hide(self)
    end
end

function ISHotbar:update()
    origUpdate(self)
    if not TGI.Options or TGI.Options.get("hotbarStyle") == false then return end
    if self.toolRender then self.toolRender:setVisible(false) end

    if not self.tgiSized then self.tgiSized = true; pcall(function() self:setSizeAndPosition() end) end
    if not self.tgiRegistered then
        self.tgiRegistered = true

        TGI.hotbarTarget = TGI.hotbarTarget or {}
        local pn = self.playerNum or 0
        local old = TGI.hotbarTarget[pn]
        if old and old ~= self then TGI.Drag.unregister(old) end
        TGI.hotbarTarget[pn] = self
        TGI.Drag.register(self)
    end
end

local origDown, origUp, origMove = ISHotbar.onMouseDown, ISHotbar.onMouseUp, ISHotbar.onMouseMove
function ISHotbar:onMouseDown(x, y)
    if TGI.Options and TGI.Options.get("hotbarStyle") ~= false then
        local i = self:getSlotIndexAt(x, y)
        self.tgiPress = (i and i > 0 and self.attachedItems[i]) and { i = i, x = getMouseX(), y = getMouseY() } or nil
    end
    if origDown then return origDown(self, x, y) end
    return true
end
local function tryDrag(self)
    local pr = self.tgiPress
    if not pr or (TGI.Drag and TGI.Drag.active) or not isMouseButtonDown(0) then return end
    if math.abs(getMouseX() - pr.x) + math.abs(getMouseY() - pr.y) <= 6 then return end
    self.tgiPress = nil
    local item = self.attachedItems[pr.i]
    if not item then return end
    local w, h = 1, 1
    pcall(function() w, h = TGI.Size.of(item) end)
    local e = { key = "h:" .. item:getID(), item = item, items = { item }, w = w, h = h }
    TGI.Drag.start(self.playerNum, e, { hotbar = pr.i }, 0, 0, false, nil)
end
function ISHotbar:onMouseMove(dx, dy)
    tryDrag(self)
    if origMove then return origMove(self, dx, dy) end
end
function ISHotbar:onMouseMoveOutside(dx, dy) tryDrag(self) end
function ISHotbar:onMouseUp(x, y)
    self.tgiPress = nil
    if TGI.Drag and TGI.Drag.active then TGI.Drag.finish(); return true end
    if origUp then return origUp(self, x, y) end
end

function ISHotbar:tgiContains(ax, ay)
    if not self:isReallyVisible() then return false end
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    return ax >= x and ay >= y and ax < x + self.width and ay < y + self.height
end

function ISHotbar:tgiDropAt(ax, ay, d)
    local i = self:getSlotIndexAt(ax - self:getAbsoluteX(), ay - self:getAbsoluteY())
    local slot = self.availableSlot[i]
    local item = d.entry and d.entry.item
    if not slot or not item then return true end
    if item ~= self.attachedItems[i] and self:canBeAttached(slot, item) then
        self:attachItem(item, slot.def.attachments[item:getAttachmentType()], i, slot.def, true)
    end
    return true
end

do
    local STUCK_MS = 6000
    local seen, nextCheck = nil, 0
    Events.OnTick.Add(function()
        local now = getTimestampMs()
        if now < nextCheck then return end
        nextCheck = now + 500
        local p = getSpecificPlayer(0)
        if not p then return end
        local q = ISTimedActionQueue.getTimedActionQueue(p)
        local cur = q and q.queue and q.queue[1]
        local t = cur and cur.Type
        if t ~= "ISAttachItemHotbar" and t ~= "ISDetachItemHotbar" then seen = nil; return end
        if not seen or seen.a ~= cur then seen = { a = cur, t = now }; return end
        if now - seen.t > STUCK_MS then
            local ok = pcall(function() cur:forceComplete() end)
            if not ok then pcall(function() cur:forceStop() end) end
            TGI.attachUnstuck = (TGI.attachUnstuck or 0) + 1
            seen = nil
        end
    end)
end
