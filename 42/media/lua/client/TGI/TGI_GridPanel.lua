require "ISUI/ISPanel"
require "ISUI/ISToolTipInv"
require "ISUI/ISToolTip"
require "TGI/TGI_Model"
require "TGI/TGI_Theme"
require "TGI/TGI_StackList"
require "TGI/TGI_Draw"
require "TGI/TGI_Drag"
require "TGI/TGI_Search"
require "TGI/TGI_Compare"
require "TGI/TGI_Tooltip"
require "TGI/TGI_Guns"
require "TGI/TGI_Lock"
require "TGI/TGI_Repair"

TGI = TGI or {}
local T, D, Drag, G, A, S = TGI.Theme, TGI.Draw, TGI.Drag, TGI.Grid, TGI.Actions, TGI.Search
local P = ISPanel:derive("TGIGridPanel")
TGI.Theme.applyAlpha(P)
TGI.GridPanel = P
P.collapsedState = {}
P.collapsedN = 0
function P.rememberCollapsed(c, v)
    if P.collapsedState[c] == nil then
        P.collapsedN = P.collapsedN + 1
        if P.collapsedN > 300 then P.collapsedState, P.collapsedN = {}, 1 end
    end
    P.collapsedState[c] = v
end

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

function P:new(x, y, container, opts)
    local o = ISPanel:new(x, y, 100, 100)
    setmetatable(o, self)
    self.__index = self
    o.opts = opts or {}
    o.pn = o.opts.playerNum or 0
    o.model = TGI.Model.new(container, o.opts)
    o.title = o.opts.title or ""
    o.background = false
    o.lastW, o.lastH = -1, -1
    o.press = nil
    o.collapsed = P.collapsedState[container] or false
    return o
end

function P:initialise()
    ISPanel.initialise(self)
    Drag.register(self)
    self:refresh(true)
end

function P:close()
    Drag.unregister(self)
    TGI.Tip.hide(self)
    if self.btip then self.btip:removeFromUIManager(); self.btip = nil end
end

local LOCK_H = 40
function P:refresh(force)
    local p = getSpecificPlayer(self.pn)
    local mine = p and safe(function() return self.model.container:isInCharacterInventory(p) end, false)
    self.locked = (not mine) and TGI.Lock.locked(self.model.container, self.pn) or false
    self.stash = (not mine) and TGI.Lock.isStash(self.model.container) or false
    if force then self.model.dirty = true end
    self.model:ensure()
    local cw, ch = self.model:extent()
    local w = math.max(cw * T.CELL, 220)

    local col = self.parent
    if col and col.isTGIColumn then w = math.max(w, col.width - 24) end
    local over = #self.model.overflow
    local h = T.HEADER + ch * T.CELL + (over > 0 and (P.overRows(over, w) * T.CELL + P.overLabelH() + 6) or 0) + 4
    if self.locked then h = T.HEADER + LOCK_H end
    if self.collapsed then h = T.HEADER end
    if w ~= self.lastW or h ~= self.lastH then
        self:setWidth(w); self:setHeight(h)
        self.lastW, self.lastH = w, h
        if self.opts.onLayout then self.opts.onLayout(self) end
    end
end

function P:cellXY(pi, x, y)
    local p = self.model.board.pockets[pi]
    return (p.x0 + x) * T.CELL, T.HEADER + (p.y0 + y) * T.CELL
end

function P:mouseCell(mx, my)
    return math.floor(mx / T.CELL), math.floor((my - T.HEADER) / T.CELL)
end

function P:entryAtMouse(mx, my)
    if my < T.HEADER then return nil end
    local cx, cy = self:mouseCell(mx, my)
    local pi, lx, ly = self.model:pocketAt(cx, cy)
    if pi then
        local key = G.at(self.model.board, pi, lx, ly)
        if key then
            local e = self.model.byKey[key]
            local pos = self.model.board.entries[key]
            return e, pos, lx - pos.x, ly - pos.y
        end
        return nil
    end

    local cw, ch = self.model:extent()
    local oy = T.HEADER + ch * T.CELL + 2 + P.overLabelH()
    local per = P.overPerRow(self.width)
    if my >= oy and my < oy + P.overRows(#self.model.overflow, self.width) * T.CELL and mx < per * T.CELL then
        local i = math.floor((my - oy) / T.CELL) * per + math.floor(mx / T.CELL) + 1
        local e = self.model.overflow[i]
        if e then return e, nil, 0, 0 end
    end
    return nil
end

function P.overLabelH() return getTextManager():getFontHeight(UIFont.Small) + 4 end

function P.overPerRow(w) return math.max(1, math.floor((w or 0) / T.CELL)) end
function P.overRows(n, w) return math.max(1, math.ceil(n / P.overPerRow(w))) end

function P:isHidden(e)
    if e == nil then return false end
    local gen = (rawget(_G, "TGIVPGen") or 0) + (S.gen or 0) * 1000003
    local now = getTimestampMs()
    local hc = self._hid
    if not hc or hc.gen ~= gen or now > hc.t then hc = { gen = gen, t = now + 250 }; self._hid = hc end
    local v = hc[e]
    if v == nil then v = S.hidden(e, self.model.container, self.pn) and true or false; hc[e] = v end
    return v
end

function P:nextHidden(noSkip)
    if S.exempt(self.model.container, self.pn) then return nil end
    self.skillValueFirst = S.perkLevel(self.pn) >= 6
    local best, bk, bs = nil, nil, nil
    local skip = not noSkip and self:searchState().skip
    for key, pos in pairs(self.model.board.entries) do
        local e = self.model.byKey[key]
        if e and not S.isSeen(e.item) and not (skip and skip[key]) then
            local p = self.model.board.pockets[pos.pi]
            local score = (p.y0 + pos.y) * 1000 + (p.x0 + pos.x)

            if self.skillValueFirst then score = -((TGI.Theme.value and TGI.Theme.value(e.item)) or 0) * 10000 + score end
            if not bs or score < bs then best, bk, bs = e, key, score end
        end
    end
    if not best then
        for _, e in ipairs(self.model.overflow) do
            if not S.isSeen(e.item) then return e, e.key end
        end
    end
    return best, bk
end

function P:update()
    ISPanel.update(self)
    self:searchTick()
end

function P:searchState() return S.stateFor(self.model.container) end

function P:hasHidden()
    local now = getTimestampMs()
    if self._hhT and now - self._hhT < 150 and self._hhGen == S.gen then return self._hh end
    self._hh = self:nextHidden(true) ~= nil
    self._hhT, self._hhGen = now, S.gen
    return self._hh
end

function P:searchTarget()
    local st = self:searchState()
    while #st.queue > 0 do
        local key = st.queue[1]
        local e = self.model.byKey[key]
        if e and not S.isSeen(e.item) then return e, key end
        table.remove(st.queue, 1)
    end
    if st.all then
        if not self:hasHidden() then return nil end
        return self:nextHidden()
    end
    if TGI.Options.get("autoSearch") then

        local fp = TGI.Window and TGI.Window.autoFocusPanel
        if fp and fp ~= self and fp.parent and fp:isReallyVisible() and not fp.locked and fp:hasHidden() then return nil end
        if not self:hasHidden() then return nil end
        return self:nextHidden()
    end
    return nil
end

function P:toggleQueue(e)
    local st = self:searchState()
    for i, k in ipairs(st.queue) do
        if k == e.key then table.remove(st.queue, i); return end
    end
    st.queue[#st.queue + 1] = e.key
    if st.skip then st.skip[e.key] = nil end
end

function P:cancelSearch(e)
    local st = self:searchState()
    for i, k in ipairs(st.queue) do
        if k == e.key then table.remove(st.queue, i); break end
    end
    st.skip = st.skip or {}
    st.skip[e.key] = true
    if self.cur == e.key then self.cur, self.curFrac = nil, 0 end
end

function P:queueIndex(key)
    for i, k in ipairs(self:searchState().queue) do if k == key then return i end end
    return nil
end

function P:searchTick()
    local now = getTimestampMs()
    if self.collapsed or self.locked or not self:isReallyVisible() then return end
    local e, key = self:searchTarget()
    if not e then
        if S.active == self then S.active = nil end
        self.cur = nil
        if not self:hasHidden() then self:searchState().all = false end
        return
    end

    if S.active and S.active ~= self and S.activeT and now - S.activeT < 500 then return end
    S.active, S.activeT = self, now
    local p = getSpecificPlayer(self.pn)
    local moving = p and safe(function() return p:isPlayerMoving() end, false)
    if not self.nextDanger or now >= self.nextDanger then
        self.nextDanger = now + 300
        self.danger = S.danger(self.pn)
    end

    local slow = S.panicFactor(self.pn, self.danger)
    self.slow = slow
    if moving or self.cur ~= key then
        if self.cur ~= key and not moving then S.noise(self.pn) end
        self.cur, self.curT, self.curFrac, self.curLast = key, now, 0, now
        if moving then self.cur = nil end
        return
    end
    local dt = math.min(200, math.max(0, now - (self.curLast or now)))
    self.curLast = now
    if slow <= 0 then return end

    if not isClient() then
        local sp = safe(function() return getGameSpeed() end, 1)
        if sp == 0 then return end
        if sp > 1 then dt = dt * math.min(40, safe(function() return getGameTime():getTrueMultiplier() end, 1)) end
    end
    self.curFrac = (self.curFrac or 0) + dt * slow / (S.duration(e, self.pn) * 1000)
    if self.curFrac >= 1 then
        S.markEntry(e, true)
        self.cur = nil

        S.addXP(self.pn, S.xpFor(e.item, self.stash))
    end
end

function P:searchBtnRect()
    if self.locked or not self:hasHidden() then return nil end
    local w = TGI.Theme.measure(UIFont.Small, getText("IGUI_TGI_SearchBtn")) + 14
    local wtw = TGI.Theme.measure(UIFont.Small, "000.0 / 000") + 16
    return self.width - wtw - w, 1, w, T.HEADER - 4
end

function P:isSearching() return S.active == self and self.cur ~= nil end

function P:iconBtnRects()
    local wtw = TGI.Theme.measure(UIFont.Small, "000.0 / 000") + 16
    local sx = self:searchBtnRect()
    local right = (sx or (self.width - wtw)) - 4
    local r = {}
    r.sort = { right - (T.HEADER - 4), 1, (T.HEADER - 4), (T.HEADER - 4) }
    local nx = right - (T.HEADER - 4) * 2 - 4

    if not self.locked then
        r.qt = { nx, 1, (T.HEADER - 4), (T.HEADER - 4) }; nx = nx - (T.HEADER - 4) - 4
    end
    if self:logList() then r.log = { nx, 1, (T.HEADER - 4), (T.HEADER - 4) }; nx = nx - (T.HEADER - 4) - 4 end
    local obj, cls = self:appliance()
    r.extra = 0
    if obj then

        local tm = getTextManager()

        r.power = { nx, 1, (T.HEADER - 4), (T.HEADER - 4) }; nx = nx - (T.HEADER - 4) - 4; r.extra = r.extra + (T.HEADER - 4) + 4

        if cls == "Stove" then
            local sw = TGI.Theme.measure(UIFont.Small, getText("IGUI_TGI_Settings")) + 12
            r.set = { nx + (T.HEADER - 4) - sw, 1, sw, (T.HEADER - 4) }; nx = nx - sw - 4; r.extra = r.extra + sw + 4
        end
    end

    if #self:objectActions() > 0 then
        local cw = TGI.Theme.measure(UIFont.Small, getText("IGUI_TGI_Actions")) + 12
        r.cfg = { nx + (T.HEADER - 4) - cw, 1, cw, (T.HEADER - 4) }; r.extra = r.extra + cw + 4
    end
    r.n = 1 + (r.log and 1 or 0) + (r.qt and 1 or 0)
    return r
end

local APPLIANCE = { Stove = true, ClothingDryer = true, ClothingWasher = true, CombinationWasherDryer = true }
function P:qtKey()
    local p = getSpecificPlayer(self.pn)
    local mine = p and safe(function() return self.model.container:isInCharacterInventory(p) end, false)
    return mine and "qtMine" or "qtLoot"
end
function P:isQtTarget()
    local c = self.model and self.model.container
    return c ~= nil and (TGI.Window.qtMine == c or TGI.Window.qtLoot == c)
end
function P:toggleQtTarget()
    local k = self:qtKey()
    TGI.Window[k] = (TGI.Window[k] ~= self.model.container) and self.model.container or nil
    getSoundManager():playUISound("UISelectListItem")
end

function P:appliance()
    local c = self.model and self.model.container
    local obj = c and c.getParent and c:getParent() or nil
    if not obj or not obj.getObjectName then return nil end
    local cls = obj:getObjectName()
    if APPLIANCE[cls] then return obj, cls end
    return nil
end

function P:applianceOn()
    local obj, cls = self:appliance()
    if not obj then return false end
    if cls == "Stove" then return obj.Activated and obj:Activated() or false end
    return obj.isActivated and obj:isActivated() or false
end

function P:toggleAppliance()
    local obj, cls = self:appliance()
    local p = getSpecificPlayer(self.pn)
    if not obj or not p then return end
    if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then return end
    local sq = obj:getSquare()
    if not (sq and luautils.walkAdj(p, sq)) then return end
    local A
    if cls == "Stove" then A = ISToggleStoveAction
    elseif cls == "ClothingDryer" then A = ISToggleClothingDryer
    elseif cls == "ClothingWasher" then A = ISToggleClothingWasher
    else A = ISToggleComboWasherDryer end
    if A then ISTimedActionQueue.add(A:new(p, obj)) end
end

local SKIP_HANDLER = { ISLootWindowObjectControlHandler_TakeAll = true, ISLootWindowObjectControlHandler_TakeSameType = true,
    ISLootWindowObjectControlHandler_MoveToFloor = true, ISLootWindowObjectControlHandler_StoveToggle = true,
    ISLootWindowObjectControlHandler_StoveSettings = true,
    ISLootWindowObjectControlHandler_ClothingWasherToggle = true, ISLootWindowObjectControlHandler_ClothingDryerToggle = true,
    ISLootWindowObjectControlHandler_CombinationWasherDryerToggle = true }
function P:fakeLootWindow()
    local c = self.model.container
    local pane = setmetatable({ inventory = c, player = self.pn }, { __index = ISInventoryPane })
    return { onCharacter = false, inventory = c, player = self.pn, inventoryPane = pane,
        getX = function() return getMouseX() end, getY = function() return getMouseY() end, getHeight = function() return 0 end }
end

function P:objectActions()
    local now = getTimestampMs()
    if self._actT and now - self._actT < 400 then return self._acts end
    self._actT = now
    local out = {}
    self._acts = out
    local list = ISLootWindowContainerControls_HandlerList
    local c = self.model and self.model.container

    local outer = c
    for _ = 1, 4 do
        local bag = outer and outer.getContainingItem and outer:getContainingItem() or nil
        local up = bag and bag:getContainer() or nil
        if not up then break end
        outer = up
    end
    local obj = nil
    local part = outer and outer.getVehiclePart and outer:getVehiclePart() or nil
    if part then obj = part:getVehicle()
    else
        local bag = c and c.getContainingItem and c:getContainingItem() or nil
        obj = (bag and bag.getWorldItem and bag:getWorldItem()) or (c and c.getParent and c:getParent()) or nil
    end
    local p = getSpecificPlayer(self.pn)
    if not list or not obj or not p or safe(function() return c:isInCharacterInventory(p) end, false) then return out end
    if not (instanceof(obj, "IsoObject") or instanceof(obj, "BaseVehicle")) then return out end
    self._handlers = self._handlers or {}
    local lw = self:fakeLootWindow()
    for _, cls in ipairs(list) do
        local skip = false
        for name in pairs(SKIP_HANDLER) do if _G[name] == cls then skip = true; break end end
        if not skip then
            local h = self._handlers[cls]
            if not h then
                local ok, v = pcall(cls.new, cls)
                h = ok and v or false
                self._handlers[cls] = h
            end
            if h then
                h.lootWindow, h.playerNum, h.playerObj, h.object, h.container = lw, self.pn, p, obj, c
                local ok, vis = pcall(h.shouldBeVisible, h)
                if ok and vis then out[#out + 1] = h end
            end
        end
    end
    return out
end

function P:actionsMenu()
    local acts = self:objectActions()
    if #acts == 0 then return end
    local menu = ISContextMenu.get(self.pn, TGI.mx(), TGI.my())
    for _, h in ipairs(acts) do pcall(h.handleJoypadContextMenu, h, menu) end
    if menu.numOptions and menu.numOptions <= 1 then menu:setVisible(false) end
end

function P:applianceSettings()
    local obj, cls = self:appliance()
    local p = getSpecificPlayer(self.pn)
    if cls ~= "Stove" or not p or not ISOvenUITimedAction then return end
    if not luautils.walkAdj(p, obj:getSquare()) then return end
    local mw = obj.isMicrowave and obj:isMicrowave()
    ISTimedActionQueue.add(ISOvenUITimedAction:new(p, (not mw) and obj or nil, mw and obj or nil))
end

function P:logList()
    local l = nil
    pcall(function()
        local obj = self.model.container:getParent()
        local md = obj and obj:hasModData() and obj:getModData()
        if md and md.TGIlog and #md.TGIlog > 0 then l = md.TGIlog end
    end)
    return l
end

local function inRect(x, y, rc) return rc and x >= rc[1] and y >= rc[2] and x < rc[1] + rc[3] and y < rc[2] + rc[4] end

function P:drawTextBtn(rc, text, on)
    local x, y, w, h = rc[1], rc[2], rc[3], rc[4]
    local hov = self:isMouseOver() and inRect(self:getMouseX(), self:getMouseY(), rc)
    self:drawRect(x, y, w, h, on and 0.9 or 0.7, on and 0.22 or 0.12, on and 0.22 or 0.12, on and 0.21 or 0.11)
    self:drawRectBorder(x, y, w, h, 0.6, T.accent.r, T.accent.g, T.accent.b)
    if hov then self:drawRect(x, y, w, h, 0.12, 1, 1, 1) end
    self:drawTextCentre(text, x + w / 2, y + math.floor((h - getTextManager():getFontHeight(UIFont.Small)) / 2), T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
end

function P:drawIconBtn(rc, kind)
    local hov = self:isMouseOver() and inRect(self:getMouseX(), self:getMouseY(), rc)
    local x, y, w, h = rc[1], rc[2], rc[3], rc[4]
    self:drawRect(x, y, w, h, 0.7, 0.12, 0.12, 0.11)
    self:drawRectBorder(x, y, w, h, 0.6, T.accent.r, T.accent.g, T.accent.b)
    if hov then self:drawRect(x, y, w, h, 0.12, 1, 1, 1) end
    local c = T.accent
    if kind == "sort" then

        for i = 0, 2 do self:drawRect(x + 4, y + 4 + i * 4, w - 8 - i * 3, 2, 1, c.r, c.g, c.b) end
    else

        self:drawRectBorder(x + 4, y + 3, w - 8, h - 6, 1, c.r, c.g, c.b)
        for i = 0, 2 do self:drawRect(x + 6, y + 6 + i * 3, w - 12, 1, 1, c.r, c.g, c.b) end
    end
end

function P:viewport()
    local col = self.parent
    if not col or not col.isTGIColumn then return nil end
    local top = col:getAbsoluteY() - self:getAbsoluteY()
    return math.max(0, top), math.min(self.height, top + col.height)
end

function P:prerender()
    local vy0, vy1 = self:viewport()
    self.clipping = false
    if vy0 then
        if vy1 <= vy0 then self.hiddenByScroll = true; return end
        self:setStencilRect(0, vy0, self.width, vy1 - vy0)
        self.clipping = true
    end
    self.hiddenByScroll = false
    local C = T.CELL
    local m = self.model

    local modern = T.modern()
    if modern then

        self:drawRect(0, 0, self.width, T.HEADER - 2, 0.95, 0.035, 0.037, 0.037)
        self:drawRect(0, 0, 3, T.HEADER - 2, 0.9, T.accent.r, T.accent.g, T.accent.b)
        self:drawRect(0, T.HEADER - 3, self.width, 1, 0.55, T.accent.r * 0.8, T.accent.g * 0.8, T.accent.b * 0.8)
    else
        self:drawRect(0, 0, self.width, T.HEADER - 2, 0.95, 0.07, 0.072, 0.072)
        T.metalFill(self, 0, 0, self.width, T.HEADER - 2, 0.5)
    end
    if self.stash then
        self:drawRect(0, 0, self.width, T.HEADER - 2, 0.3, 0.6, 0.6, 0.58)
        self:drawRectBorder(0, 0, self.width, self.height, 0.9, 0.85, 0.85, 0.82)
    end

    if self:isQtTarget() then
        local pulse = 0.75 + 0.25 * math.sin(getTimestampMs() / 350)
        self:drawRect(0, 0, self.width, T.HEADER - 2, 0.3, 0.25, 0.6, 1)
        self:drawRectBorder(0, 0, self.width, self.height, pulse, 0.35, 0.7, 1)
        self:drawRectBorder(1, 1, self.width - 2, self.height - 2, pulse * 0.5, 0.35, 0.7, 1)
    end
    local hy = math.floor((T.HEADER - 2 - getTextManager():getFontHeight(UIFont.Small)) / 2)
    self:drawText(self.collapsed and ">" or "v", 6, hy, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
    local wtxt = string.format("%.1f / %d", self:headerWeight(), m:capacity())
    local room = self.width - 30 - TGI.Theme.measure(UIFont.Small, wtxt) - 12 - 16
    local _, _, sbw = self:searchBtnRect()
    if sbw then room = room - sbw - 8 end
    local ib = self:iconBtnRects()
    room = room - ib.n * ((T.HEADER - 4) + 4) - ib.extra - 4
    local status = ""
    if (self.slow or 1) < 0.9 and self:hasHidden() then status = "  " .. getText("IGUI_TGI_Interrupted")
    elseif self:isSearching() then status = "  " .. getText("IGUI_TGI_Searching") end

    local knowsStash = self.stash and (S.perkLevel(self.pn) >= 4 or not self:hasHidden())
    local title = (knowsStash and (getText("IGUI_TGI_Stash") .. ": ") or "") .. (self.locked and (getText("IGUI_TGI_Locked2") .. ": ") or "") .. self.title .. status .. (self.collapsed and ("  (" .. #(m.entries or {}) .. ")") or "")

    local tx0 = 20

    local lbl = TGI.Labels and TGI.Labels.get(m.container)
    if lbl then
        local lr, lg, lb = TGI.Labels.color(lbl)
        local fhL = getTextManager():getFontHeight(UIFont.Small)
        self:drawRect(tx0, hy + 2, 5, fhL - 3, 1, lr, lg, lb)
        tx0 = tx0 + 9
        if lbl.t and lbl.t ~= "" then
            title = lbl.t .. "  |  " .. title
            room = room - 9
        end
    end

    local tm0 = getTextManager()
    local shown = title
    if TGI.Theme.measure(UIFont.Small, shown) > room then
        local noOwner = string.gsub(shown, "^.-'s%s+", "", 1)
        shown = TGI.Draw._short(noOwner, room, UIFont.Small)
    end
    if modern and TGI.Font then
        shown = string.upper(shown)
        if TGI.Font.width(shown, UIFont.Small) > room then
            while #shown > 2 and TGI.Font.width(shown .. "..", UIFont.Small) > room do shown = string.sub(shown, 1, #shown - 1) end
            shown = shown .. ".."
        end
        self:drawText(shown, tx0, hy, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    else
        self:drawText(shown, tx0, hy, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
    if shown ~= title and self:isMouseOver() and self:getMouseY() < T.HEADER and self:getMouseX() < tx0 + room then
        self.tgiTitleTip = title
    else
        self.tgiTitleTip = nil
    end
    local wt = self:headerWeight()
    local cap = m:capacity()
    local label = string.format("%.1f / %d", wt, cap)
    local col = wt > cap and T.bad or T.dim
    self:drawTextRight(label, self.width - 6, hy, col.r, col.g, col.b, 1, UIFont.Small)
    local wic = D.tex("ic_weight")
    if wic then
        local lw = (modern and TGI.Font) and TGI.Font.width(label, UIFont.Small) or TGI.Theme.measure(UIFont.Small, label)
        self:drawTextureScaledAspect(wic, self.width - 6 - lw - 15, hy + 2, 12, 12, 0.85, 1, 1, 1)
    end
    local bx, by, bw, bh = self:searchBtnRect()
    if bx then
        local st = self:searchState()
        local on = st.all or TGI.Options.get("autoSearch")
        local hov = self:isMouseOver() and self:getMouseX() >= bx and self:getMouseX() < bx + bw and self:getMouseY() < T.HEADER
        self:drawRect(bx, by, bw, bh, on and 0.9 or 0.7, on and 0.22 or 0.12, on and 0.22 or 0.12, on and 0.21 or 0.11)
        self:drawRectBorder(bx, by, bw, bh, 0.6, T.accent.r, T.accent.g, T.accent.b)
        if hov then self:drawRect(bx, by, bw, bh, 0.12, 1, 1, 1) end
        self:drawTextCentre(getText(on and "IGUI_TGI_SearchStop" or "IGUI_TGI_SearchBtn"), bx + bw / 2, by + math.floor((bh - getTextManager():getFontHeight(UIFont.Small)) / 2), T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
    end
    if not self.locked then
        self:drawIconBtn(ib.sort, "sort")
        if ib.log then self:drawIconBtn(ib.log, "log") end
    end
    if ib.qt then
        local rc = ib.qt
        local x, y, w, h = rc[1], rc[2], rc[3], rc[4]
        local on = self:isQtTarget()
        local hov = self:isMouseOver() and inRect(self:getMouseX(), self:getMouseY(), rc)
        local c = on and { r = 0.4, g = 0.75, b = 1 } or T.accent
        self:drawRect(x, y, w, h, 0.8, on and 0.08 or 0.12, on and 0.16 or 0.12, on and 0.28 or 0.11)
        self:drawRectBorder(x, y, w, h, on and 1 or 0.6, c.r, c.g, c.b)
        if hov then self:drawRect(x, y, w, h, 0.12, 1, 1, 1) end
        local ic = D.tex("ic_down")
        if ic then self:drawTextureScaled(ic, x + 3, y + 3, w - 6, h - 6, on and 1 or 0.7, c.r, c.g, c.b) end
    end
    if ib.power then
        local on = self:applianceOn()
        local rc = ib.power
        local x, y, w, h = rc[1], rc[2], rc[3], rc[4]
        local hov = self:isMouseOver() and inRect(self:getMouseX(), self:getMouseY(), rc)
        local c = on and { r = 0.4, g = 0.95, b = 0.4 } or T.accent
        self:drawRect(x, y, w, h, 0.8, on and 0.08 or 0.12, on and 0.22 or 0.12, on and 0.08 or 0.11)
        self:drawRectBorder(x, y, w, h, 0.7, c.r, c.g, c.b)
        if hov then self:drawRect(x, y, w, h, 0.12, 1, 1, 1) end
        local ic = D.tex("ic_power")
        if ic then self:drawTextureScaled(ic, x + 3, y + 3, w - 6, h - 6, 1, c.r, c.g, c.b) end

    end
    if ib.cfg then self:drawTextBtn(ib.cfg, getText("IGUI_TGI_Actions"), false) end
    if ib.set then self:drawTextBtn(ib.set, getText("IGUI_TGI_Settings"), TGI.Appliance and TGI.Appliance.inst ~= nil) end
    if self.collapsed then return end
    if self.locked then
        local y0 = T.HEADER
        self:drawRect(0, y0, self.width, LOCK_H, 0.85, 0.06, 0.04, 0.04)
        self:drawRectBorder(0, y0, self.width, LOCK_H, 0.8, 0.5, 0.2, 0.15)
        self:drawText(getText("IGUI_TGI_NeedKey"), 8, y0 + 11, 0.9, 0.55, 0.45, 1, UIFont.Small)
        local rc = self:forceBtnRect()
        if rc then
            local hov = self:isMouseOver() and inRect(self:getMouseX(), self:getMouseY(), rc)
            self:drawRect(rc[1], rc[2], rc[3], rc[4], hov and 0.95 or 0.75, 0.3, 0.12, 0.08)
            self:drawRectBorder(rc[1], rc[2], rc[3], rc[4], 0.9, 0.9, 0.45, 0.3)
            self:drawTextCentre(getText("IGUI_TGI_Force"), rc[1] + rc[3] / 2, rc[2] + math.floor((rc[4] - getTextManager():getFontHeight(UIFont.Small)) / 2), 1, 0.85, 0.75, 1, UIFont.Small)
        end
        return
    end

    for _, p in ipairs(m.board.pockets) do
        local px, py = p.x0 * C, T.HEADER + p.y0 * C
        if T.modern() then

            self:drawRect(px, py, p.w * C, p.h * C, 0.95, 0.02, 0.021, 0.021)

            local vy0, vy1 = self:viewport()
            local g0, g1 = 0, p.h - 1
            if vy0 then
                g0 = math.max(0, math.floor((vy0 - py) / C))
                g1 = math.min(p.h - 1, math.floor((vy1 - py) / C))
            end

            local W, ry0, ry1 = p.w * C, py + g0 * C, py + (g1 + 1) * C
            if g1 >= g0 then
                self:drawRect(px, ry0, W, ry1 - ry0, 0.9, T.cell.r + 0.025, T.cell.g + 0.025, T.cell.b + 0.025)
                for gy = g0, g1 do
                    self:drawRect(px, py + gy * C + 1, W, 1, 0.5, T.cellLine.r, T.cellLine.g, T.cellLine.b)
                end
                for gx = 0, p.w do
                    self:drawRect(px + gx * C - 1, ry0, 2, ry1 - ry0, 0.95, 0.02, 0.021, 0.021)
                end
                for gy = g0, g1 + 1 do
                    self:drawRect(px, py + gy * C - 1, W, 2, 0.95, 0.02, 0.021, 0.021)
                end
            end
            self:drawRectBorder(px, py, p.w * C, p.h * C, 0.9, T.border.r * 0.8, T.border.g * 0.8, T.border.b * 0.8)
        else
        self:drawRect(px, py, p.w * C, p.h * C, T.cell.a, T.cell.r, T.cell.g, T.cell.b)
        T.metalFill(self, px, py, p.w * C, p.h * C, 0.55)
        for gx = 1, p.w - 1 do self:drawRect(px + gx * C, py, 1, p.h * C, 0.6, T.cellLine.r, T.cellLine.g, T.cellLine.b) end
        for gy = 1, p.h - 1 do self:drawRect(px, py + gy * C, p.w * C, 1, 0.6, T.cellLine.r, T.cellLine.g, T.cellLine.b) end
        self:drawRectBorder(px, py, p.w * C, p.h * C, 1, T.border.r, T.border.g, T.border.b)
        end

        if p.label then
            local font = T.FONT_TINY
            local fh = getTextManager():getFontHeight(font)
            local txt = TGI.Draw._short(getText(p.label), (p.labelW or p.w) * C + C - 4, font)
            self:drawText(txt, px + 2, py - fh - 2, T.dim.r, T.dim.g, T.dim.b, 0.9, font)
        end
    end
end

function P:forceBtnRect()
    local tool = TGI.Lock.tool(getSpecificPlayer(self.pn))
    if not tool then return nil end
    local w = TGI.Theme.measure(UIFont.Small, getText("IGUI_TGI_Force")) + 16
    return { self.width - w - 8, T.HEADER + 8, w, LOCK_H - 16 }
end

function P:render()
    if self.hiddenByScroll then return end
    if self.tgiTitleTip then
        local tw = TGI.Theme.measure(UIFont.Small, self.tgiTitleTip)
        local fh = getTextManager():getFontHeight(UIFont.Small)
        self:drawRect(16, 1, tw + 10, fh + 4, 0.95, 0.05, 0.05, 0.05)
        self:drawRectBorder(16, 1, tw + 10, fh + 4, 1, T.accent.r, T.accent.g, T.accent.b)
        self:drawText(self.tgiTitleTip, 21, 3, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
    if self.locked then
        if self.clipping then self:clearStencilRect() end
        return
    end
    self:renderInner()

    local mq = self.marquee
    if mq then
        if not isMouseButtonDown(0) then self.marquee = nil; self:applyMarquee(mq)
        else
            mq.x1, mq.y1 = self:getMouseX(), self:getMouseY()
            local x0, y0 = math.min(mq.x0, mq.x1), math.min(mq.y0, mq.y1)
            local w, h = math.abs(mq.x1 - mq.x0), math.abs(mq.y1 - mq.y0)
            self:drawRect(x0, y0, w, h, 0.12, T.accent.r, T.accent.g, T.accent.b)
            self:drawRectBorder(x0, y0, w, h, 0.9, T.accent.r, T.accent.g, T.accent.b)
        end
    end
    self:drawBtnTip()
    if self.clipping then self:clearStencilRect() end
end

local BTN_TIPS = { { "sort", "IGUI_TGI_TipSort" }, { "qt", "IGUI_TGI_TipQt" }, { "log", "IGUI_TGI_Log" }, { "power", "IGUI_TGI_TipPower" } }
function P:drawBtnTip()
    if not self:isMouseOver() then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    if my >= T.HEADER then return end

    local sbx, sby, sbw, sbh = self:searchBtnRect()
    local sb = sbx and { sbx, sby, sbw, sbh } or nil
    if sb and inRect(mx, my, sb) and S.UNLOCKS then
        local lv = S.level(self.pn) or 0
        local lines = { { getText("IGUI_TGI_SearchLevel", tostring(lv)), true } }
        for _, n in ipairs({ 3, 4, 5, 6, 8, 10 }) do
            if S.UNLOCKS[n] then lines[#lines + 1] = { getText(S.UNLOCKS[n]), lv >= n } end
        end
        local fh = getTextManager():getFontHeight(UIFont.Small)
        local w = 0
        for _, l in ipairs(lines) do w = math.max(w, TGI.Theme.measure(UIFont.Small, l[1])) end
        local h = #lines * fh + 8
        local x = math.max(2, math.min(self.width - w - 14, sb[1] + sb[3] - w - 12))
        local y = sb[2] + sb[4] + 2
        self:drawRect(x, y, w + 12, h, 0.96, 0.04, 0.04, 0.04)
        self:drawRectBorder(x, y, w + 12, h, 1, T.border.r, T.border.g, T.border.b)
        for i, l in ipairs(lines) do
            local c = l[2] and T.text or T.dim
            self:drawText(l[1], x + 6, y + 4 + (i - 1) * fh, c.r, c.g, c.b, 1, UIFont.Small)
        end
        return
    end
    local ib = self:iconBtnRects()
    for _, bt in ipairs(BTN_TIPS) do
        local rc = ib[bt[1]]
        if rc and (bt[1] ~= "sort" or not self.locked) and inRect(mx, my, rc) then
            local t = getText(bt[2])
            if bt[1] == "qt" then t = t .. " " .. getText(self:isQtTarget() and "IGUI_TGI_TipOn" or "IGUI_TGI_TipOff") end
            local tm = getTextManager()
            local tw, fh = TGI.Theme.measure(UIFont.Small, t), tm:getFontHeight(UIFont.Small)
            local x = math.max(2, math.min(self.width - tw - 12, rc[1] + rc[3] - tw - 10))
            local y = rc[2] + rc[4] + 2
            self:drawRect(x, y, tw + 10, fh + 4, 0.96, 0.04, 0.04, 0.04)
            self:drawRectBorder(x, y, tw + 10, fh + 4, 1, T.accent.r, T.accent.g, T.accent.b)
            self:drawText(t, x + 5, y + 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
            return
        end
    end
end

function P:renderInner()

    if not self._markedSeen and self.model and self.model.container and not self:hasHidden() then
        self._markedSeen = true
        if TGI.Marks then pcall(TGI.Marks.markContainer, self.model.container, self.pn) end
    end
    if self.collapsed then return end
    local C = T.CELL
    local m = self.model

    if m.kind == "main" and m.board and #m.board.pockets == 0 then
        self:drawText(getText("IGUI_TGI_NoPockets"), 6, T.HEADER + 4, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
    end
    local d = Drag.active
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:tgiContains(getMouseX(), getMouseY())
    local hoverEntry = (not d) and over and self:isMouseOver() and self:entryAtMouse(mx, my) or nil
    local hoverEntry0 = hoverEntry
    if self:isHidden(hoverEntry) then hoverEntry = nil end
    if hoverEntry then TGI.hover = { item = hoverEntry.item, t = getTimestampMs() } end
    local lvl = S.perkLevel(self.pn)

    local vy0, vy1 = self:viewport()
    local gh = TGI.hover
    local gunFits = gh and gh.item and getTimestampMs() - (gh.t or 0) < 150 and TGI.Guns.fitsFor(gh.item) or nil
    local treatHL = TGI.Health and TGI.Health.treatItems and TGI.Health.treatItems() or nil
    local hoverDrop = d and over and self:entryAtMouse(mx, my) or nil

    if m.board.locked then
        local lockTex = D.tex("ic_lock")
        for pi, lk in pairs(m.board.locked) do
            local p = m.board.pockets[pi]
            if p then
                for idx in pairs(lk) do
                    local lx, ly = (idx - 1) % p.w, math.floor((idx - 1) / p.w)
                    if ly < p.h then
                        local x, y = self:cellXY(pi, lx, ly)
                        self:drawRect(x + 2, y + 2, C - 4, C - 4, 0.35, 0.25, 0.08, 0.06)
                        self:drawRectBorder(x + 2, y + 2, C - 4, C - 4, 0.6, 0.55, 0.25, 0.2)
                        if lockTex then self:drawTextureScaled(lockTex, x + C / 2 - 7, y + C / 2 - 7, 14, 14, 0.5, 0.9, 0.6, 0.5) end
                    end
                end
            end
        end
    end
    for key, pos in pairs(m.board.entries) do
        local e = m.byKey[key]
        local x, y
        if e then x, y = self:cellXY(pos.pi, pos.x, pos.y) end
        if e and vy0 and (y + pos.dh * C < vy0 or y > vy1) then e = nil end
        if e then
            local alpha = (d and d.entry == e and not d.split) and 0.35 or 1
            if self:isHidden(e) then
                D.hiddenTile(self, x, y, pos.dw * C, pos.dh * C, key == self.cur and S.active == self and self.curFrac or nil, self:queueIndex(key),
                    lvl >= 3 and D.kindHint(e.item) or nil, lvl >= 8 and e.item or nil)
                if hoverEntry0 == e then self:drawRect(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, T.hover.a, T.hover.r, T.hover.g, T.hover.b) end
            else
                D.tile(self, e, x, y, pos.dw * C, pos.dh * C, alpha, pos.rot)

                if gunFits and gunFits[e.item:getFullType()] then
                    self:drawRectBorder(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 1, 0.95, 0.8, 0.3)
                    self:drawRectBorder(x + 2, y + 2, pos.dw * C - 4, pos.dh * C - 4, 0.6, 0.95, 0.8, 0.3)
                end

                if treatHL and treatHL[e.item:getID()] then
                    self:drawRectBorder(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 1, 0.35, 0.95, 0.45)
                    self:drawRectBorder(x + 2, y + 2, pos.dw * C - 4, pos.dh * C - 4, 0.6, 0.35, 0.95, 0.45)
                end

                if d and hoverDrop == e and TGI.Guns.kind(d.entry.item, e.item) then
                    self:drawRect(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 0.18, 0.3, 0.9, 0.35)
                    self:drawRectBorder(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 1, 0.3, 0.9, 0.35)
                end
            end
            if hoverEntry == e then

                local ha = T.hover.a
                if T.anim() then
                    if self.hovKey ~= key then self.hovKey, self.hovT = key, getTimestampMs() end
                    ha = ha * (0.25 + 0.75 * T.outCubic(math.min(1, (getTimestampMs() - self.hovT) / 130)))
                end
                self:drawRect(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, ha, T.hover.r, T.hover.g, T.hover.b)

                local v = TGI.Compare and TGI.Compare.verdict(getSpecificPlayer(self.pn), e.item) or 0
                if v ~= 0 then
                    local ic = D.tex(v > 0 and "ic_up" or "ic_down")
                    local ax = x + pos.dw * C - 16
                    if ic then
                        self:drawRect(ax - 1, y + 13, 14, 14, 0.85, 0.02, 0.02, 0.02)
                        self:drawTextureScaled(ic, ax, y + 14, 12, 12, 1, v > 0 and 0.4 or 0.95, v > 0 and 0.95 or 0.35, v > 0 and 0.4 or 0.3)
                    end
                end
            end
            if self.sel and self.sel[e.key] then
                self:drawRect(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 0.16, T.accent.r, T.accent.g, T.accent.b)
                self:drawRectBorder(x + 1, y + 1, pos.dw * C - 2, pos.dh * C - 2, 1, T.accent.r, T.accent.g, T.accent.b)
                self:drawRectBorder(x + 2, y + 2, pos.dw * C - 4, pos.dh * C - 4, 0.6, T.accent.r, T.accent.g, T.accent.b)
            end
        end
    end

    local sig = m:layoutSig()
    for id, pend in pairs(A.pending) do
        if pend.sig == sig and pend.item and pend.item:getContainer() ~= m.container then
            local fl = A.inflightFor(pend.item)
            if fl and fl.dest == m.container and m.board.pockets[pend.pi] then
                local dw, dh = G.dims(pend.w, pend.h, pend.rot)
                local gx, gy = self:cellXY(pend.pi, pend.x, pend.y)
                D.ghost(self, pend.item, gx, gy, dw * C, dh * C, A.progress(pend.item), pend.rot)
            end
        end
    end

    if #m.overflow > 0 then
        local _, ch = m:extent()
        local oy = T.HEADER + ch * C + 2
        self:drawText(getText("IGUI_TGI_Overflow"), 4, oy, T.bad.r, T.bad.g + 0.3, T.bad.b + 0.3, 1, UIFont.Small)
        local per = P.overPerRow(self.width)
        for i, e in ipairs(m.overflow) do
            local col, row = (i - 1) % per, math.floor((i - 1) / per)
            local tx, ty = col * C, oy + P.overLabelH() + row * C
            if self:isHidden(e) then D.hiddenTile(self, tx, ty, C, C, e.key == self.cur and self.curFrac or nil)
            else D.tile(self, e, tx, ty, C, C, 1) end
        end
    end

    if d and over and my >= T.HEADER then
        local re, rpos = self:entryAtMouse(mx, my)
        if re and rpos and re ~= d.entry and not self:isHidden(re) and TGI.Repair.can(d.entry.item, re.item) then
            local rx, ry = self:cellXY(rpos.pi, rpos.x, rpos.y)
            self:drawRect(rx, ry, rpos.dw * C, rpos.dh * C, 0.3, 0.3, 0.8, 0.95)
            self:drawRectBorder(rx, ry, rpos.dw * C, rpos.dh * C, 1, 0.4, 0.85, 1)
            self:drawTextCentre(getText("IGUI_TGI_Repair"), rx + rpos.dw * C / 2, ry + rpos.dh * C / 2 - 8, 1, 1, 1, 1, UIFont.Small)
            self:updateTooltip(nil)
            return
        end
    end

    if d and over and my >= T.HEADER then
        local dw, dh = G.dims(d.entry.w, d.entry.h, d.rot)
        local cx, cy = self:mouseCell(mx, my)
        local ox, oy = cx - d.grabX, cy - d.grabY
        local pi, lx, ly = m:pocketAt(ox, oy)
        local ok = pi and m:canPlace(d.entry, pi, lx, ly, d.rot)
        local be = self:entryAtMouse(mx, my)
        if be and be ~= d.entry and not self:isHidden(be) and safe(function() return instanceof(be.item, "InventoryContainer") end, false) then
            ok = true
        end
        local col = ok and T.ok or T.bad
        self:drawRect(ox * C, T.HEADER + oy * C, dw * C, dh * C, col.a, col.r, col.g, col.b)
    end
    self:updateTooltip(hoverEntry)
end

function P:showLogTip()
    local ib = self:iconBtnRects()
    local mx, my = self:getMouseX(), self:getMouseY()
    local list = ib.log and self:isMouseOver() and inRect(mx, my, ib.log) and self:logList()
    if not list then return false end
    if not self.btip then
        self.btip = ISToolTip:new()
        self.btip:initialise()
        self.btip:setOwner(self)
    end
    local now = math.floor(getGameTime():getWorldAgeHours())
    local lines = {}
    for i = 1, math.min(#list, 12) do
        local e = list[i]
        local ago = now - (e.t or now)
        local col = e.d > 0 and "<RGB:0.4,0.85,0.4>" or "<RGB:0.9,0.45,0.35>"

        lines[#lines + 1] = col .. " " .. (e.d > 0 and "+" or "-") .. " <SPACE> " .. tostring(e.i)
            .. " <SPACE> <RGB:0.8,0.8,0.8> " .. tostring(e.n)
            .. " <SPACE> <RGB:0.6,0.6,0.6> " .. getText("IGUI_TGI_HoursAgo", ago)
    end
    self.btip:setName(getText("IGUI_TGI_Log"))
    self.btip.description = table.concat(lines, " <LINE> ")
    self.btip:setDesiredPosition(getMouseX() + 16, getMouseY() + 16)
    self.btip:addToUIManager()
    self.btip:setVisible(true)
    self.btip:bringToTop()
    return true
end

function P:updateTooltip(entry)
    if self:showLogTip() then
        TGI.Tip.hide(self)
        return
    end
    local item = entry and entry.item or nil
    if item and getPlayerContextMenu(self.pn):isAnyVisible() then item = nil end
    if self.btip then self.btip:removeFromUIManager(); self.btip:setVisible(false) end
    if item then
        local hidden = instanceof(item, "InventoryContainer") and S.bagHasHidden(item, self.pn)
        TGI.Tip.show(item, self, self.pn, { hiddenBag = hidden })
    else
        TGI.Tip.hide(self)
    end
end

function P:onMouseMoveOutside()
    TGI.Tip.hide(self)
    if self.btip then self.btip:removeFromUIManager(); self.btip:setVisible(false) end
    self:onMouseMove()
end

function P:headerWeight()
    local c = self.model and self.model.container
    local p = getSpecificPlayer(self.pn)
    if c and p and c == p:getInventory() then
        return safe(function() return p:getInventoryWeight() end, 0)
    end
    return safe(function() return c:getContentsWeight() end, 0)
end

function P:onMouseDown(x, y)
    if not self:tgiContains(TGI.mx(), TGI.my()) then return false end
    if self.locked then
        if y >= T.HEADER and inRect(x, y, self:forceBtnRect()) then TGI.Lock.force(self.pn, self.model.container) end
        if y >= T.HEADER then return true end
    end
    if y < T.HEADER then
        local bx, by, bw, bh = self:searchBtnRect()
        if bx and x >= bx and x < bx + bw then
            local st = self:searchState()
            st.all = not st.all
            st.skip = nil
            return true
        end
        local ib = self:iconBtnRects()
        if inRect(x, y, ib.sort) then self.model:sortNow(); self.lastW = -1; self:refresh(false); return true end
        if inRect(x, y, ib.log) then return true end
        if ib.qt and inRect(x, y, ib.qt) then self:toggleQtTarget(); return true end
        if ib.power and inRect(x, y, ib.power) then self:toggleAppliance(); return true end

        if ib.cfg and inRect(x, y, ib.cfg) then self.cfgPress = true; return true end
        if ib.set and inRect(x, y, ib.set) then
            local obj = self:appliance()
            local p = getSpecificPlayer(self.pn)
            if obj and p and luautils.walkAdj(p, obj:getSquare()) then
                ISTimedActionQueue.add(ISOvenUITimedAction:new(p, (not obj:isMicrowave()) and obj or nil, obj:isMicrowave() and obj or nil))
            end
            return true
        end

        self.hdrPress = { x = x, y = y }
        return true
    end
    local e, pos, gx, gy = self:entryAtMouse(x, y)

    if not e then
        self.marquee = { x0 = x, y0 = y, x1 = x, y1 = y, add = isShiftKeyDown() }
        return true
    end
    if not e then return true end
    if self:isHidden(e) then self:toggleQueue(e); return true end
    local now = getTimestampMs()
    if isCtrlKeyDown() then
        TGI.Window.quickTransfer(self.pn, e, self.model)
        return true
    end
    if isAltKeyDown() then
        A.equip(self.pn, e.item)
        return true
    end
    if self.lastClick and self.lastClick.key == e.key and now - self.lastClick.t < 400 then
        self.lastClick = nil
        self:onDoubleClick(e)
        return true
    end
    self.lastClick = { key = e.key, t = now }
    self.press = { e = e, x = x, y = y, gx = gx, gy = gy, rot = pos and pos.rot or false, split = isShiftKeyDown() }
    return true
end

function P:applyMarquee(mq)
    local x0, x1 = math.min(mq.x0, mq.x1), math.max(mq.x0, mq.x1)
    local y0, y1 = math.min(mq.y0, mq.y1), math.max(mq.y0, mq.y1)

    if x1 - x0 < 4 and y1 - y0 < 4 then
        if not mq.add then self.sel = nil end
        return
    end
    local C = T.CELL
    self.sel = (mq.add and self.sel) or {}
    for _, e in ipairs(self.model.entries or {}) do
        local pos = self.model.board.entries[e.key]
        if pos and not self:isHidden(e) then
            local ex, ey = self:cellXY(pos.pi, pos.x, pos.y)
            local ew, eh = (pos.dw or pos.w or 1) * C, (pos.dh or pos.h or 1) * C
            if ex < x1 and ex + ew > x0 and ey < y1 and ey + eh > y0 then self.sel[e.key] = true end
        end
    end
    self.lastClick = nil
end

function P:onMouseMove(dx, dy)
    local hp = self.hdrPress
    if hp and isMouseButtonDown(0) and self:isMine() then
        local mx, my = self:getMouseX(), self:getMouseY()
        if math.abs(mx - hp.x) + math.abs(my - hp.y) > 8 then
            self.hdrPress = nil
            TGI.Window.bagMove = self
        end
    end
    if self.marquee then
        if isMouseButtonDown(0) then
            self.marquee.x1, self.marquee.y1 = self:getMouseX(), self:getMouseY()
        else
            local mq = self.marquee; self.marquee = nil; self:applyMarquee(mq)
        end
        return
    end
    local pr = self.press
    if pr and not Drag.active and isMouseButtonDown(0) then
        local mx, my = self:getMouseX(), self:getMouseY()

        local need = pr.split and 16 or 5
        if math.abs(mx - pr.x) + math.abs(my - pr.y) > need then
            local multi = nil
            if self.sel and self.sel[pr.e.key] then
                multi = {}
                for _, e in ipairs(self.model.entries or {}) do
                    if self.sel[e.key] then for _, it in ipairs(e.items or { e.item }) do multi[#multi + 1] = it end end
                end
                if #multi <= #(pr.e.items or {}) then multi = nil end
            end
            Drag.start(self.pn, pr.e, { model = self.model, panel = self }, pr.gx, pr.gy, pr.rot, (not multi) and pr.split or nil)
            if multi and Drag.active then
                Drag.active.multi = multi

                local b = self.model.board
                local p0 = b.entries[pr.e.key]
                local q0 = p0 and b.pockets[p0.pi]
                if q0 then
                    local form = {}
                    for _, e in ipairs(self.model.entries or {}) do
                        local pe = self.sel[e.key] and b.entries[e.key]
                        local q = pe and b.pockets[pe.pi]
                        if q then form[#form + 1] = { e = e, dx = (q.x0 + pe.x) - (q0.x0 + p0.x), dy = (q.y0 + pe.y) - (q0.y0 + p0.y), rot = pe.rot } end
                    end
                    Drag.active.form = form
                end
            end
            self.press = nil
        end
    end
end

function P:isMine()
    local W = TGI.Window and TGI.Window.instance
    if not W then return false end
    for _, pn in ipairs(W.mine and W.mine.panels or {}) do if pn == self then return true end end
    return false
end

function P:onMouseUp(x, y)
    local hp = self.hdrPress
    self.hdrPress = nil
    local W = TGI.Window
    if W and W.bagMove then
        local from = W.bagMove
        W.bagMove = nil
        if from ~= self and self:isMine() then W.moveBag(from, self) end
        return true
    end
    if hp then
        self.collapsed = not self.collapsed
        TGI.GridPanel.rememberCollapsed(self.model.container, self.collapsed)
        self.lastW = -1
        self:refresh(false)
        return true
    end
    if self.cfgPress then
        self.cfgPress = nil
        local ib = self:iconBtnRects()
        if ib.cfg and x >= ib.cfg[1] and y >= ib.cfg[2] and x < ib.cfg[1] + ib.cfg[3] and y < ib.cfg[2] + ib.cfg[4] then
            self:actionsMenu()
        end
        return true
    end
    if self.marquee then
        local mq = self.marquee
        self.marquee = nil
        mq.x1, mq.y1 = x, y
        self:applyMarquee(mq)
        return true
    end
    local pr = self.press
    self.press = nil
    if Drag.active then Drag.finish(); return true end

    if pr and pr.split then
        self.sel = self.sel or {}
        self.sel[pr.e.key] = (not self.sel[pr.e.key]) or nil
        self.lastClick = nil
    elseif pr and self.sel and (function() for _ in pairs(self.sel) do return true end end)() then
        self.sel = nil
    end
    return true
end

function P:selectedItems()
    local out = {}
    if not self.sel then return out end
    for _, e in ipairs(self.model.entries or {}) do
        if self.sel[e.key] and not self:isHidden(e) then for _, it in ipairs(e.items or { e.item }) do out[#out + 1] = it end end
    end
    return out
end

function P:askCount(e, gx, gy)
    local n = #(e.items or {})
    if n < 2 then return end
    local p = getSpecificPlayer(self.pn)
    local w, h = 280, 120
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local panel = self
    local box = ISTextBox:new(x, y, w, h, getText("IGUI_TGI_HowMany", tostring(n)), tostring(math.floor(n / 2)), nil,
        function(_, button)
            if button.internal ~= "OK" then return end
            local v = tonumber(button.parent.entry:getText())
            if not v then return end
            v = math.max(1, math.min(n, math.floor(v)))
            Drag.start(panel.pn, e, { model = panel.model, panel = panel }, 0, 0, false, v)
            if Drag.active then Drag.active.sticky = true end
        end, self.pn)
    box:initialise()
    pcall(function() box.entry:setOnlyNumbers(true) end)
    box:addToUIManager()
end

function P:onMouseUpOutside(x, y)
    if self.marquee then
        local mq = self.marquee
        self.marquee = nil
        mq.x1, mq.y1 = x, y
        self:applyMarquee(mq)
    end
    self.press = nil
    self.cfgPress = nil
    self.hdrPress = nil
end

function P:onRightMouseUp(x, y)
    if not self:tgiContains(TGI.mx(), TGI.my()) then return false end
    local e = self:entryAtMouse(x, y)
    if not e and not self.locked then
        local cx, cy = self:mouseCell(x, y)
        self.menuCell = nil
        if y >= T.HEADER then
            local pi, lx, ly = self.model:pocketAt(cx, cy)
            if pi then self.menuCell = { pi, lx, ly } end
        end
        self:layoutMenu(self:getAbsoluteX() + x, self:getAbsoluteY() + y)
        return true
    end
    if e and self:isHidden(e) then self:cancelSearch(e); return true end
    if not e then return true end
    local p = getSpecificPlayer(self.pn)
    local inPlayer = p and self.model.container:isInCharacterInventory(p)
    local own = e.items or { e.item }
    local items = own
    if self.sel and self.sel[e.key] then
        local all = self:selectedItems()
        if #all > #own then items = all end
    end
    if Drag.justCancelled and getTimestampMs() - Drag.justCancelled < 300 then return true end
    local menu = A.contextMenu(self.pn, items, self:getAbsoluteX() + x, self:getAbsoluteY() + y, inPlayer)
    if menu and items == own and #own > 1 then
        local o = menu:addOption(getText("IGUI_TGI_TakeCount"), self, function(pp) pp:askCount(e) end)
        if o then o.tgiOwn = true end
        local ax, ay = self:getAbsoluteX() + x, self:getAbsoluteY() + y
        o = menu:addOption(getText("IGUI_TGI_ExpandStack"), self, function(pp) TGI.StackList.open(pp, e, ax + 12, ay) end)
        if o then o.tgiOwn = true end
    end
    return true
end

function P:lootAll(list)
    local p = getSpecificPlayer(self.pn)
    if not p then return end
    local inv = p:getInventory()
    local cap = (inv.getEffectiveCapacity and inv:getEffectiveCapacity(p)) or p:getMaxWeight()
    local free = cap - inv:getCapacityWeight()
    local take, left = {}, 0
    for _, it in ipairs(list) do
        local w = it.getUnequippedWeight and it:getUnequippedWeight() or 0.1
        if w <= free then
            take[#take + 1] = it
            free = free - w
            A.noDropN = (A.noDropN or 0) + 1
            if A.noDropN > 300 then A.noDrop, A.noDropN = {}, 1 end
            A.noDrop[it:getID()] = getTimestampMs()
        else
            left = left + 1
        end
    end
    if #take > 0 then A.transfer(self.pn, take, inv) end
    if left > 0 then TGI.halo(p, getText("IGUI_TGI_LootLeft", tostring(left)), false) end
end

local KIND_ICON = { food = "ic_food", medical = "ic_med", ammo = "ic_ammo", weapons = "ic_weapon", tools = "ic_tool" }
local function ico(opt, name)
    if opt and name then local t = TGI.Draw.tex(name); if t then opt.iconTexture = t end end
    return opt
end
function P:layoutMenu(ax, ay)
    local m = self.model
    local menu = ISContextMenu.get(self.pn, ax, ay)
    local p = getSpecificPlayer(self.pn)
    local mine = p and safe(function() return m.container:isInCharacterInventory(p) end, false)

    if not mine and p then
        local list = {}
        for _, e in ipairs(m.entries or {}) do
            if not self:isHidden(e) then for _, it in ipairs(e.items or { e.item }) do list[#list + 1] = it end end
        end
        if #list > 0 then
            ico(menu:addOption(getText("IGUI_TGI_LootAll"), self, function(pp) pp:lootAll(list) end), "ic_lootall")

            local M = TGI.Model
            local gun = p:getPrimaryHandItem()
            local ammoT, magT = nil, nil
            if gun and instanceof(gun, "HandWeapon") and safe(function() return gun:isRanged() end, false) then
                ammoT = safe(function() return gun:getAmmoType() end, nil)
                magT = safe(function() return gun:getMagazineType() end, nil)
                if ammoT and type(ammoT) ~= "string" then ammoT = tostring(ammoT) end
            end
            local filters = {
                { "food", function(it, g) return g == 4 or g == 5 end },
                { "medical", function(it, g) return g == 3 end },
                { "ammo", function(it, g)
                    if not ammoT and not magT then return g == 2 end
                    local ft = it:getFullType()
                    return ft == ammoT or ft == magT or ("Base." .. it:getType()) == ammoT
                        or (ammoT and safe(function() return tostring(it:getAmmoType()) end, "") == ammoT and g == 2)
                end },
                { "weapons", function(it, g) return g == 1 end },
                { "tools", function(it, g) return g == 6 end },
            }
            local sub = nil
            for _, f in ipairs(filters) do
                local pick = {}
                for _, it in ipairs(list) do
                    local g = M and M.groupOf(it) or 10
                    if safe(function() return f[2](it, g) end, false) then pick[#pick + 1] = it end
                end
                if #pick > 0 then
                    if not sub then
                        local opt = ico(menu:addOption(getText("IGUI_TGI_LootKind")), "ic_lootall")
                        sub = ISContextMenu:getNew(menu)
                        menu:addSubMenu(opt, sub)
                    end
                    ico(sub:addOption(getText("IGUI_TGI_LootKind_" .. f[1]) .. " (" .. #pick .. ")", self, function(pp) pp:lootAll(pick) end), KIND_ICON[f[1]])
                end
            end
        end
    end
    if not self:hasHidden() then
        ico(menu:addOption(getText("IGUI_TGI_Sort"), self, function(pp) pp.model:sortNow(nil); pp.lastW = -1; pp:refresh(false) end), "ic_sort")

        local cur = m.currentPreset and m:currentPreset() or nil
        local head = getText("IGUI_TGI_Preset")
        if cur then head = getText("IGUI_TGI_PresetCur", getText("IGUI_TGI_Preset_" .. cur)) end
        local opt = ico(menu:addOption(head), cur and KIND_ICON[cur] or "ic_sort")
        local sub = ISContextMenu:getNew(menu)
        menu:addSubMenu(opt, sub)
        for _, k in ipairs({ "ammo", "medical", "food", "tools" }) do
            local o = ico(sub:addOption(getText("IGUI_TGI_Preset_" .. k), self, function(pp) pp.model:sortNow(k); pp.lastW = -1; pp:refresh(false) end), cur == k and "ic_check" or KIND_ICON[k])
            if o and cur == k then o.tgiOn = true end
        end
        if cur then
            ico(sub:addOption(getText("IGUI_TGI_PresetOff"), self, function(pp) pp.model:sortNow(nil); pp.lastW = -1; pp:refresh(false) end), "ic_unlock")
        end
    end

    if m.lockKey and m:lockKey() then
        ico(menu:addOption(getText("IGUI_TGI_SaveLayout"), self, function(pp)
            local n = pp.model:saveLayoutPreset()
            local pl = getSpecificPlayer(pp.pn)
            if pl then TGI.halo(pl, getText("IGUI_TGI_LayoutSaved", tostring(n)), true) end
        end), "ic_layout")
        if m:layoutPreset() then
            ico(menu:addOption(getText("IGUI_TGI_ClearLayout"), self, function(pp) pp.model:clearLayoutPreset() end), "ic_layout")
        end
    end

    if TGI.Labels then pcall(TGI.Labels.addMenu, menu, self, ico) end

    local mc = self.menuCell
    if mc and m.lockKey and m:lockKey() then
        local on = m:isLocked(mc[1], mc[2], mc[3])
        ico(menu:addOption(getText(on and "IGUI_TGI_UnlockCell" or "IGUI_TGI_LockCell"), self, function(pp)
            pp.model:toggleLock(mc[1], mc[2], mc[3])
        end), on and "ic_unlock" or "ic_lock")
    end
    if menu.numOptions and menu.numOptions <= 1 then menu:setVisible(false) end
    if TGI.SelfTest then
        menu:addOption("TGI: self-test", nil, function() TGI.SelfTest.run() end)
    end
end

function P:onDoubleClick(e)
    local item = e.item
    if safe(function() return instanceof(item, "InventoryContainer") end, false) then
        TGI.Window.openBag(self.pn, item)
    else
        local p = getSpecificPlayer(self.pn)

        local cont = item and item.getContainer and item:getContainer() or nil
        if not cont then return end
        local mine = p and cont:isInCharacterInventory(p) or false
        if mine and ISInventoryPane and ISInventoryPane.doContextualDblClick then

            local ok = pcall(ISInventoryPane.doContextualDblClick, { player = self.pn }, item)
            if not ok then A.equip(self.pn, item) end
        elseif p then

            A.transfer(self.pn, { item }, p:getInventory())
        end
    end
end

function P:tgiContains(ax, ay)
    if not self:isReallyVisible() then return false end
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    local vy0, vy1 = self:viewport()
    local y0, y1 = y, y + self.height
    if vy0 then y0, y1 = y + vy0, y + vy1 end
    return ax >= x and ay >= y0 and ax < x + self.width and ay < y1
end

function P:placeForm(d, mx, my)
    local m = self.model
    m:ensure()
    local b = m.board
    local cx, cy = self:mouseCell(mx, my)
    local ox, oy = cx - (d.grabX or 0), cy - (d.grabY or 0)
    local same = d.source and d.source.model and d.source.model.container == m.container
    local mine = {}
    if same then for _, f in ipairs(d.form) do mine[f.e.key] = true end end
    local spots = {}
    for _, f in ipairs(d.form) do
        local pi, lx, ly = m:pocketAt(ox + f.dx, oy + f.dy)
        if not pi then return false end
        local w, h = G.dims(f.e.w, f.e.h, f.rot)
        local p = b.pockets[pi]
        if lx + w > p.w or ly + h > p.h then return false end
        for yy = ly, ly + h - 1 do
            for xx = lx, lx + w - 1 do
                local c = p.cells[yy * p.w + xx + 1]
                if c ~= nil and not mine[c] then return false end
            end
        end
        spots[#spots + 1] = { f = f, pi = pi, x = lx, y = ly }
    end
    if same then
        for _, sp in ipairs(spots) do G.remove(b, sp.f.e.key) end
        for _, sp in ipairs(spots) do m:moveLocal(sp.f.e, sp.pi, sp.x, sp.y, sp.f.rot) end
        return true
    end
    local all = {}
    for _, sp in ipairs(spots) do
        for _, it in ipairs(sp.f.e.items or { sp.f.e.item }) do
            A.setPending(it, m:layoutSig(), sp.pi, sp.x, sp.y, sp.f.rot)
            all[#all + 1] = it
        end
    end
    A.transfer(d.pn, all, m.container)
    return true
end

function P:tgiDropAt(ax, ay, d)
    if self.locked then return false end
    if d.multi and d.form and not self.collapsed then
        local mx0, my0 = ax - self:getAbsoluteX(), ay - self:getAbsoluteY()
        if my0 >= T.HEADER and self:placeForm(d, mx0, my0) then
            if d.source and d.source.panel then d.source.panel.sel = nil end
            return true
        end
    end
    if d.multi then
        if d.source and d.source.model and d.source.model.container == self.model.container then return true end
        A.transfer(d.pn, d.multi, self.model.container)
        if d.source and d.source.panel then d.source.panel.sel = nil end
        return true
    end
    local mx, my = ax - self:getAbsoluteX(), ay - self:getAbsoluteY()
    local m = self.model
    m:ensure()

    if d.source and d.source.slot then
        local p = getSpecificPlayer(d.pn)
        local it = d.entry and d.entry.item
        if p and it and it:getContainer() == m.container then
            local cx, cy = self:mouseCell(mx, my)
            local pi, lx, ly = m:pocketAt(cx - (d.grabX or 0), cy - (d.grabY or 0))
            if pi and m:canPlace(d.entry, pi, lx, ly, d.rot) then A.setPending(it, m:layoutSig(), pi, lx, ly, d.rot) end
            A.unequip(d.pn, it)
            return true
        end
    end
    if self.collapsed or my < T.HEADER then

        local pi, x, y, rot = m:findSpotFor(d.entry)
        if not pi then return false end
        local items = Drag.items(d)
        if d.source and d.source.model and d.source.model.container == m.container then return true end
        for _, it in ipairs(items) do A.setPending(it, m:layoutSig(), pi, x, y, rot) end
        A.transfer(d.pn, items, m.container)
        return true
    end
    local cx, cy = self:mouseCell(mx, my)
    local ox, oy = cx - d.grabX, cy - d.grabY
    local pi, lx, ly = m:pocketAt(ox, oy)
    local items = Drag.items(d)
    local sameContainer = d.source and d.source.model and d.source.model.container == m.container

    local tEntry = self:entryAtMouse(mx, my)
    if tEntry and self:isHidden(tEntry) then tEntry = nil end
    if tEntry and tEntry ~= d.entry and tEntry.item ~= d.entry.item
        and safe(function() return instanceof(tEntry.item, "InventoryContainer") end, false) then
        A.transfer(d.pn, items, tEntry.item:getInventory())
        return true
    end

    local gEntry = self:entryAtMouse(mx, my)
    if gEntry and gEntry ~= d.entry and not self:isHidden(gEntry) and TGI.Guns.kind(d.entry.item, gEntry.item) then
        TGI.Guns.apply(d.pn, d.entry.item, gEntry.item)
        return true
    end

    local rEntry = self:entryAtMouse(mx, my)
    if rEntry and rEntry ~= d.entry and not self:isHidden(rEntry) and TGI.Repair.can(d.entry.item, rEntry.item) then
        TGI.Repair.apply(d.pn, d.entry.item, rEntry.item)
        return true
    end
    if not pi or not m:canPlace(d.entry, pi, lx, ly, d.rot) then
        return false
    end
    if sameContainer then

        if #items < #(d.entry.items or { d.entry.item }) then return true end
        m:moveLocal(d.entry, pi, lx, ly, d.rot)
        return true
    end
    for _, it in ipairs(items) do A.setPending(it, m:layoutSig(), pi, lx, ly, d.rot) end
    A.transfer(d.pn, items, m.container)
    return true
end

return P
