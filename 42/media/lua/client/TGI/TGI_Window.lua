require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "TGI/TGI_Theme"
require "TGI/TGI_GridPanel"
require "TGI/TGI_Equip"
require "TGI/TGI_Drag"
require "TGI/TGI_Search"

TGI = TGI or {}
local T, Drag, A, G = TGI.Theme, TGI.Drag, TGI.Actions, TGI.Grid
local W = ISPanel:derive("TGIWindow")
TGI.Theme.applyAlpha(W)
TGI.Window = W

local TITLE_H = 26
local PAD = 8

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

local Col = ISPanel:derive("TGIColumn")
TGI.Theme.applyAlpha(Col)
function Col:new(x, y, w, h, title)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = T.panel.r, g = T.panel.g, b = T.panel.b, a = T.panel.a }
    o.borderColor = { r = T.border.r, g = T.border.g, b = T.border.b, a = 0.6 }
    o.title = title
    o.isTGIColumn = true
    o.panels = {}
    o.containers = {}
    return o
end
function Col:createChildren()
    ISPanel.createChildren(self)
    self:addScrollBars()
    self:setScrollChildren(true)

    local sb, col = self.vscroll, self
    if sb then sb.render = W.drawScrollBar end
    if sb then
        local down = sb.onMouseDown
        sb.onMouseDown = function(bar, x, y)
            local part = bar:hitTest(x, y)
            if part ~= "thumb" then
                local mx, my = getMouseX(), getMouseY()
                for _, p in ipairs(col.panels) do
                    local ax, ay = p:getAbsoluteX(), p:getAbsoluteY()
                    if mx >= ax and mx < ax + p.width and my >= ay and my < ay + p.height then
                        return p:onMouseDown(mx - ax, my - ay)
                    end
                end
            end
            return down(bar, x, y)
        end
    end

end

function W.drawScrollBar(bar)
    local par = bar.parent
    local sh = par and par:getScrollHeight() or 0
    local h, w = bar:getHeight(), bar:getWidth()
    if sh <= h then bar.barx, bar.bary, bar.barwidth, bar.barheight = 0, 0, 0, 0; return end
    local boxh = math.max(8, math.ceil(h / sh * (h - 32)))
    local dif = math.ceil((h - 32 - boxh) * (bar.pos or 0))
    bar.barx, bar.bary, bar.barwidth, bar.barheight = 5, 16 + dif, 8, boxh
    local mx, my = bar:getMouseX(), bar:getMouseY()
    local over = bar:isMouseOver()
    local hot = bar.scrolling or (over and bar:isPointOverThumb(mx, my))
    local tw = 6
    local tx = math.floor(w - tw - 3)

    bar:drawRect(tx, 2, tw, h - 4, 0.85, 0.02, 0.02, 0.022)
    bar:drawRectBorder(tx, 2, tw, h - 4, over and 0.7 or 0.4, T.border.r, T.border.g, T.border.b)

    local c = hot and T.accent or T.border
    bar:drawRect(tx + 1, bar.bary, tw - 2, boxh, hot and 0.95 or 0.8, c.r, c.g, c.b)

    local ac = over and T.accent or T.dim
    local cx = tx + tw / 2
    for i = 0, 2 do
        bar:drawRect(cx - i, 6 + i, i * 2 + 1, 1, 0.8, ac.r, ac.g, ac.b)
        bar:drawRect(cx - i, h - 7 - i, i * 2 + 1, 1, 0.8, ac.r, ac.g, ac.b)
    end
end

function Col:onMouseWheel(del)
    self:setYScroll(math.min(0, math.max(self:getYScroll() - del * 60, -(self:getScrollHeight() - self.height))))
    return true
end

function Col:update()
    ISPanel.update(self)

    local sb = self.vscroll
    if sb then
        local want = self.width - sb.width
        if sb:getX() ~= want then sb:setX(want) end
        if sb.height ~= self.height then sb:setHeight(self.height) end
    end
    local d = TGI.Drag.active
    if not d then return end
    local mx, my = getMouseX(), getMouseY()
    local ax, ay = self:getAbsoluteX(), self:getAbsoluteY()
    if mx < ax or mx > ax + self.width then return end
    local edge = 60
    local maxScroll = math.max(0, self:getScrollHeight() - self.height)
    local cur = self:getYScroll()
    if my < ay + edge and my > ay - 30 then
        self:setYScroll(math.min(0, cur + 14 * (1 - (my - ay) / edge)))
    elseif my > ay + self.height - edge and my < ay + self.height + 30 then
        self:setYScroll(math.max(-maxScroll, cur - 14 * (1 - (ay + self.height - my) / edge)))
    end
end
function Col:clear()
    for _, p in ipairs(self.panels) do p:close(); self:removeChild(p) end
    self.panels, self.containers = {}, {}
end
function Col:layout()
    local y = 6

    local sel = self.tabSel
    if sel then
        local found = false
        for _, p in ipairs(self.panels) do if p.model and p.model.container == sel then found = true end end
        if not found then sel = nil; self.tabSel = nil end
    end
    for _, p in ipairs(self.panels) do
        local show = (not sel) or (p.model and p.model.container == sel)
        if p:getIsVisible() ~= show then p:setVisible(show) end
        if show then
            p:setX(6); p:setY(y)
            y = y + p.height + 10
        end
    end
    self:setScrollHeight(y)
end
function Col:add(container, opts)
    local col = self
    opts.onLayout = function() col:layout() end
    local p = TGI.GridPanel:new(6, 0, container, opts)
    p:initialise()
    self:addChild(p)
    p:refresh(true)
    self.panels[#self.panels + 1] = p
    self.containers[#self.containers + 1] = container
    self:layout()
    return p
end

function Col:sameAs(list)
    local src = self.srcList or {}
    if #list ~= #src then return false end
    for i, c in ipairs(list) do if src[i] ~= c.inventory then return false end end
    return true
end

W.TAB_W = 30
local Tabs = ISPanel:derive("TGILootTabs")
if TGI.Theme.applyFont then TGI.Theme.applyFont(Tabs) end
function Tabs:new(x, y, h, col)
    local o = ISPanel:new(x, y, W.TAB_W, h)
    setmetatable(o, self); self.__index = self
    o.col = col
    o.background = false
    return o
end
function Tabs:buttons()
    local out = { { all = true } }
    for _, p in ipairs(self.col.panels) do out[#out + 1] = { panel = p } end
    return out
end
function Tabs:btnAt(y)
    local i = math.floor(y / (W.TAB_W + 2)) + 1
    return self:buttons()[i]
end

function Tabs:select(b)
    if not b then return end
    local c = b.panel and b.panel.model and b.panel.model.container or nil
    if self.col.tabSel == c then return end
    self.col.tabSel = c
    self.col:setYScroll(0)
    self.col:layout()
end
function Tabs:prerender() end
function Tabs:render()
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local bs = W.TAB_W
    for i, b in ipairs(self:buttons()) do
        local y = (i - 1) * (bs + 2)
        if y + bs > self.height then break end
        local c = b.panel and b.panel.model and b.panel.model.container or nil
        local on = self.col.tabSel == c
        local hov = over and my >= y and my < y + bs
        self:drawRect(0, y, bs, bs, 0.9, on and 0.2 or 0.05, on and 0.2 or 0.052, on and 0.19 or 0.052)
        self:drawRectBorder(0, y, bs, bs, on and 1 or 0.6, T.accent.r * (on and 1 or 0.6), T.accent.g * (on and 1 or 0.6), T.accent.b * (on and 1 or 0.6))
        if hov then self:drawRect(0, y, bs, bs, 0.12, 1, 1, 1) end
        local tex = b.all and TGI.Draw.tex("ic_layout") or (b.panel and b.panel.tabIcon)
        if tex then
            if b.all then self:drawTextureScaled(tex, 6, y + 6, bs - 12, bs - 12, 1, T.accent.r, T.accent.g, T.accent.b)
            else self:drawTextureScaledAspect(tex, 3, y + 3, bs - 6, bs - 6, 1, 1, 1, 1) end
        end
        if hov then
            local t = b.all and getText("IGUI_TGI_TabAll") or (b.panel and b.panel.tabTitle) or ""
            local tw = TGI.Theme.measure(UIFont.Small, t)
            self:drawRect(-tw - 12, y + 6, tw + 8, 18, 0.95, 0.04, 0.04, 0.04)
            self:drawText(t, -tw - 8, y + 7, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
        end
    end
end
function Tabs:onMouseDown(x, y) self:select(self:btnAt(y)); return true end
function Tabs:onMouseUp() return true end

function Tabs:onMouseWheel(del)
    local bs = self:buttons()
    if #bs == 0 then return true end
    local cur = 1
    for i, b in ipairs(bs) do
        local c = b.panel and b.panel.model and b.panel.model.container or nil
        if c == self.col.tabSel then cur = i; break end
    end
    local nxt = math.max(1, math.min(#bs, cur + (del > 0 and 1 or -1)))
    self:select(bs[nxt])
    return true
end
function Tabs:update()
    ISPanel.update(self)

    local d = TGI.Drag.active
    if d and self:isMouseOver() then
        local b = self:btnAt(self:getMouseY())
        if b and not b.all then self:select(b) end
    end
end
function Tabs:tgiDropAt(ax, ay, d)

    local b = self:btnAt(ay - self:getAbsoluteY())
    if b and b.panel and b.panel.tgiDropAt then
        local p = b.panel
        return p:tgiDropAt(p:getAbsoluteX() + 2, p:getAbsoluteY() + 2, d)
    end
    return false
end
function Tabs:tgiContains(ax, ay)
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    return ax >= x and ay >= y and ax < x + self.width and ay < y + self.height
end
W.Tabs = Tabs
local function tabsOn() return TGI.Options and TGI.Options.get("lootTabs") == true end

W.live = setmetatable({}, { __mode = "k" })
function W:new(pn)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w, h = math.min(sw - 40, 1500), math.min(sh - 60, 900)

    if not W.savedX then pcall(function()
        local g = getSpecificPlayer(pn or 0):getModData().TGIWin
        if g then W.savedX, W.savedY, W.savedW, W.savedH, W.savedLootAuto = g.x, g.y, g.w, g.h, g.lootAuto == true end
    end) end
    if W.savedW then w, h = math.min(sw, W.savedW), math.min(sh, W.savedH) end
    local x, y = (sw - w) / 2, (sh - h) / 2
    if W.savedX then
        x = math.max(0, math.min(sw - w, W.savedX))
        y = math.max(0, math.min(sh - h, W.savedY))
    end

    local full = TGI.Options.get("fullscreen") == true
    if full then x, y, w, h = 0, 0, sw, sh end
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    o.fullscreen = full
    self.__index = self
    o.pn = pn
    W.live[o] = true
    o.backgroundColor = { r = T.bg.r, g = T.bg.g, b = T.bg.b, a = T.bg.a }
    o.borderColor = { r = T.border.r, g = T.border.g, b = T.border.b, a = 1 }
    o.moveWithMouse = not full
    o.nextUpdate = 0
    o:setWantKeyEvents(true)
    return o
end

W.SECTIONS = { { id = "equip", icon = "shield" }, { id = "mine", icon = "bag" }, { id = "loot", icon = "lootall" } }
function W.hidden()
    if not W.hide then
        W.hide = {}
        pcall(function()
            local g = getSpecificPlayer(0):getModData().TGIWin
            if g and type(g.hide) == "table" then for k, v in pairs(g.hide) do W.hide[k] = v end end
        end)
    end
    return W.hide
end

function W:secShown(id)
    if W.hidden()[id] then return false end
    if id == "loot" and self.autoLootHidden then return false end
    return true
end

function W:rollRect()
    local gx = self:gearRect()
    return gx - (TITLE_H - 4) - 4, 2, TITLE_H - 4, TITLE_H - 4
end
function W:secRects()
    if self.tgiRollHidden then return {} end
    local kx = self:rollRect()
    kx = kx - 12
    local s = TITLE_H - 6
    local out = {}
    for i = #W.SECTIONS, 1, -1 do
        kx = kx - s
        table.insert(out, 1, { x = kx, y = 3, w = s, h = s, sec = W.SECTIONS[i] })
        kx = kx - 3
    end
    return out
end
function W:contentTop() return TITLE_H + PAD end
function W:sectionWidth(id)
    if id == "equip" then return (self.equip and self.equip.width or 300) + PAD end
    if not self:secShown(id) then return 8 * T.CELL + 44 + PAD end
    local col = (id == "mine") and self.mine or self.loot
    return (col and col.width or 300) + PAD + ((id == "loot" and self.tabs) and (W.TAB_W + 4) or 0)
end

function W:applySection(change)

    if self.fullscreen then change.set(); self:relayout(); return end
    local right0 = self:getX() + self.width
    local sw = getCore():getScreenWidth()
    local id, hiding = change.id, change.hiding
    local full = self:sectionWidth(id)
    change.set()
    local w = hiding and (self.width - full) or (self.width + full)
    w = math.min(sw, w)
    self:setWidth(w)
    W.savedW = w
    self:relayout()
    local nx = math.max(0, math.min(sw - self.width, right0 - self.width))
    if nx ~= self:getX() then self:setX(nx) end
    W.savedX = self:getX()
end
function W:toggleSection(id)
    local hide = W.hidden()

    if id == "loot" and self.autoLootHidden then
        self.autoLootOff = true
        self:applySection({ id = id, hiding = false, set = function() self.autoLootHidden = nil end })
        W.sound("OpenBag")
        return
    end
    local shownCount = 0
    for _, sec in ipairs(W.SECTIONS) do if self:secShown(sec.id) then shownCount = shownCount + 1 end end
    local hiding = not hide[id]
    if hiding and shownCount <= 1 then return end
    self:applySection({ id = id, hiding = hiding, set = function() hide[id] = hiding or nil end })
    pcall(function()
        local md = getSpecificPlayer(self.pn or 0):getModData()
        md.TGIWin = md.TGIWin or {}
        md.TGIWin.hide = {}
        for k, v in pairs(hide) do md.TGIWin.hide[k] = v end
    end)
    W.sound(hiding and "CloseBag" or "OpenBag")
end

function W:checkAutoLoot()
    if not (TGI.Options and TGI.Options.get("autoFoldLoot") ~= false) then
        if self.autoLootHidden then self:applySection({ id = "loot", hiding = false, set = function() self.autoLootHidden = nil end }) end
        return
    end
    if self.autoLootOff or W.hidden().loot then return end
    local empty = true
    for _, c in ipairs(self.loot.containers or {}) do
        local t = c.getType and c:getType() or ""
        if t ~= "floor" or not c:getItems():isEmpty() then empty = false; break end
    end

    self.emptyTicks = empty and ((self.emptyTicks or 0) + 1) or 0
    local first = not self.autoChecked
    self.autoChecked = true
    if empty and not self.autoLootHidden and (self.emptyTicks >= 3 or first) then
        local shown = 0
        for _, sec in ipairs(W.SECTIONS) do if self:secShown(sec.id) then shown = shown + 1 end end
        if shown > 1 then self:applySection({ id = "loot", hiding = true, set = function() self.autoLootHidden = true end }) end
    elseif not empty and self.autoLootHidden then
        self:applySection({ id = "loot", hiding = false, set = function() self.autoLootHidden = nil end })
    end
end
function W:sectionAt() return nil end
function W:drawSections() end

function W:createChildren()
    if W.savedLootAuto and TGI.Options.get("autoFoldLoot") ~= false and not W.hidden().loot then self.autoLootHidden = true end
    ISPanel.createChildren(self)
    self.equip = TGI.Equip:new(PAD, TITLE_H + PAD, self.pn)
    self.equip:initialise()
    self:addChild(self.equip)
    local ex = PAD + self.equip.width + PAD
    local colW = math.floor((self.width - ex - PAD * 2) / 2)
    local colH = self.height - TITLE_H - PAD * 2
    self.mine = Col:new(ex, TITLE_H + PAD, colW, colH, getText("IGUI_TGI_Mine"))
    self.mine:initialise(); self:addChild(self.mine)
    self.loot = Col:new(ex + colW + PAD, TITLE_H + PAD, colW, colH, getText("IGUI_TGI_Loot"))
    self.loot:initialise(); self:addChild(self.loot)
    Drag.register(self)

    local tw = TGI.Theme.measure(UIFont.Small, getText("IGUI_TGI_Title")) + PAD * 3

    self.searchFrame = { x = tw, y = 4, w = TITLE_H - 8, h = TITLE_H - 8, full = 220 }
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self.searchBox = ISTextEntryBox:new("", tw + 20, 0, 220 - 24, fh + 2)
    self.searchBox.font = UIFont.Small
    self.searchBox:initialise()
    self.searchBox:instantiate()
    self.searchBox:setY(math.floor(4 + (TITLE_H - 8 - self.searchBox:getHeight()) / 2))
    self.searchBox:setVisible(false)
    self.searchBox.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.searchBox.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    pcall(function() self.searchBox:setTooltip(getText("IGUI_TGI_Find")) end)
    self:addChild(self.searchBox)
    TGI.Draw.filter = nil
    TGI.Draw.catFilter = nil; TGI.Draw._grp = nil
    pcall(function() self:relayout() end)
    self:refreshContainers(true)
end

W.GRIP = 16
function W:minSize()
    local showE = self:secShown("equip")
    local ew = showE and (self.equip and self.equip.width or 300) or 0
    local eh = showE and (self.equip and self.equip.height or 400) or 0

    local colMin = 8 * T.CELL + 24 + 20
    local cols = (self:secShown("mine") and 1 or 0) + (self:secShown("loot") and 1 or 0)
    local tw = (tabsOn() and self:secShown("loot")) and (W.TAB_W + 4) or 0

    local titleMin = 640
    local folded = 3 - cols - (showE and 1 or 0)
    local w = PAD * (2 + cols + (showE and 1 or 0)) + ew + cols * colMin + tw
    return math.max(titleMin, w), math.max(420, TITLE_H + PAD * 2 + eh)
end

W.ROLL_MS, W.ROLL_FADE = 230, 110
function W:setRolled(on, instant)
    if (self.tgiRolled == true) == (on == true) then return end

    if on and not instant and T.anim() and not self.tgiRollFadeOut then
        self.tgiRollFadeOut = getTimestampMs()
        self.tgiRollWant = true
        return
    end
    self.tgiRollFadeOut = nil
    self.tgiRolled = on == true
    if on then
        self.tgiFullH = self.height

        self.tgiRollShown = {}
        for _, ch in pairs(self.children or {}) do
            if ch:getIsVisible() then self.tgiRollShown[#self.tgiRollShown + 1] = ch; ch:setVisible(false) end
        end
        self.searchOpen = false
        self.tgiRollHidden = true
    end
    self.tgiRollT = (not instant and T.anim()) and getTimestampMs() or nil
    if not self.tgiRollT then self:rollStep(1) end
    pcall(function()
        local md = getSpecificPlayer(self.pn or 0):getModData()
        md.TGIWin = md.TGIWin or {}
        md.TGIWin.rolled = self.tgiRolled
    end)
end
function W:rollStep(k)
    local full = self.tgiFullH or self.height
    local e = T.inOutCubic(self.tgiRolled and (1 - k) or k)
    self:setHeight(math.floor(TITLE_H + (full - TITLE_H) * e + 0.5))
    if k >= 1 then
        self.tgiRollT = nil
        if self.tgiRolled then self:setHeight(TITLE_H)
        else
            self:setHeight(full)
            self.tgiRollHidden = nil
            for _, ch in ipairs(self.tgiRollShown or {}) do ch:setVisible(true) end
            self.tgiRollShown = nil
            pcall(self.relayout, self)

            if T.anim() then self.tgiRollFadeIn = getTimestampMs() end
        end
    end
end

function W:relayout()
    if self.tgiRollHidden then return end

    local mw, mh = self:minSize()
    if self.width < mw then
        local sw = getCore():getScreenWidth()
        local w = math.min(mw, sw)
        if self:getX() + w > sw then self:setX(math.max(0, sw - w)) end
        self:setWidth(w)
    end
    if self.height < mh then
        local sh = getCore():getScreenHeight()
        local h = math.min(mh, sh)
        if self:getY() + h > sh then self:setY(math.max(0, sh - h)) end
        self:setHeight(h)
    end
    local showE = self:secShown("equip")
    if self.equip:getIsVisible() ~= showE then self.equip:setVisible(showE) end
    local top = self:contentTop()
    local colH = self.height - top - PAD
    local layout = {}
    local x = PAD

    if showE then
        self.equip:setX(x); self.equip:setY(top)
        layout[#layout + 1] = { sec = W.SECTIONS[1], x = x, w = self.equip.width }
        x = x + self.equip.width + PAD
    end

    local vis, nOpen = {}, 0
    for _, c in ipairs({ { self.mine, "mine", 2 }, { self.loot, "loot", 3 } }) do
        local on = self:secShown(c[2])
        if c[1]:getIsVisible() ~= on then c[1]:setVisible(on) end
        vis[#vis + 1] = { col = c[1], on = on, sec = W.SECTIONS[c[3]] }
        if on then nOpen = nOpen + 1 end
    end
    local tw = (tabsOn() and self:secShown("loot")) and (W.TAB_W + 4) or 0
    local colW = math.floor((self.width - x - PAD * nOpen) / math.max(1, nOpen))
    for _, v in ipairs(vis) do
        if v.on then
            local col = v.col
            local cw = (col == self.loot) and (colW - tw) or colW
            col:setX(x); col:setY(top); col:setWidth(cw); col:setHeight(colH)
            layout[#layout + 1] = { sec = v.sec, x = x, w = colW }
            x = x + colW + PAD
        end
    end
    self.secLayout = layout
    for _, col in ipairs({ self.mine, self.loot }) do
        local cw = col.width
        if col.vscroll then
            col.vscroll:setX(cw - col.vscroll.width); col.vscroll:setHeight(colH)
        end
        for _, p in ipairs(col.panels) do p.lastW = -1; pcall(function() p:refresh(false) end) end
        pcall(function() col:layout() end)
    end

    if tw > 0 then
        if not self.tabs then
            self.tabs = Tabs:new(0, 0, colH, self.loot)
            self.tabs:initialise()
            self:addChild(self.tabs)
            TGI.Drag.register(self.tabs)
        end
        self.tabs:setX(self.loot:getX() + self.loot.width + 4)
        self.tabs:setY(self.loot:getY())
        self.tabs:setHeight(colH)
    elseif self.tabs then
        TGI.Drag.unregister(self.tabs)
        self:removeChild(self.tabs)
        self.tabs = nil
        self.loot.tabSel = nil
        pcall(function() self.loot:layout() end)
    end
end

function W:resizeTo(w, h)
    local mw, mh = self:minSize()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    w = math.max(mw, math.min(sw - self:getX(), w))
    h = math.max(mh, math.min(sh - self:getY(), h))
    if w == self.width and h == self.height then return end
    self:setWidth(w); self:setHeight(h)
    W.savedW, W.savedH = w, h
    self:relayout()
end

function W:onMouseMove(dx, dy)
    if self.resizing then
        self:resizeTo(getMouseX() - self:getAbsoluteX() + self.resizing.ox, getMouseY() - self:getAbsoluteY() + self.resizing.oy)
        return true
    end
    return ISPanel.onMouseMove(self, dx, dy)
end
function W:onMouseMoveOutside(dx, dy)
    if self.resizing then return self:onMouseMove(dx, dy) end
    return ISPanel.onMouseMoveOutside(self, dx, dy)
end

W.KOFI_URL = "https://steamcommunity.com/linkfilter/?u=https://ko-fi.com/loiscoffee"

W.KOFI_SHOW = false
function W:kofiRect()
    local cx = self.width - TITLE_H
    if not W.KOFI_SHOW then return cx, 2, 0, 0 end
    return cx - (TITLE_H - 4) - 4, 2, TITLE_H - 4, TITLE_H - 4
end

function W:gearRect()
    local cx = self.width - TITLE_H
    return cx - (TITLE_H - 4) - 4, 2, TITLE_H - 4, TITLE_H - 4
end
function W.openKofi()
    local url = W.KOFI_URL
    if isSteamOverlayEnabled and isSteamOverlayEnabled() and activateSteamOverlayToWebPage then
        activateSteamOverlayToWebPage(url)
    elseif openUrl then
        openUrl(url)
    end
end
function W:onMouseUp(x, y)
    if self.kofiPress then
        self.kofiPress = nil
        local kx, ky, kw, kh = self:kofiRect()
        if x >= kx and x < kx + kw and y >= ky and y < ky + kh then pcall(W.openKofi) end
        return true
    end
    if self.closePress then
        self.closePress = nil
        if y < TITLE_H and x >= self.width - TITLE_H - 4 then self:closeAnimated() end
        return true
    end
    if self.resizing then self.resizing = nil; return true end
    return ISPanel.onMouseUp(self, x, y)
end
function W:onMouseUpOutside(x, y)
    self.closePress = nil
    self.kofiPress = nil
    if self.resizing then self.resizing = nil; return true end
    return ISPanel.onMouseUpOutside(self, x, y)
end

W.CATS = {
    { id = "weapons", icon = "damage", groups = { [1] = true } },
    { id = "ammo", icon = "ammo", groups = { [2] = true } },
    { id = "medical", icon = "med", groups = { [3] = true } },
    { id = "food", icon = "hunger", groups = { [4] = true, [5] = true } },
    { id = "tools", icon = "condition", groups = { [6] = true } },
    { id = "clothing", icon = "shield", groups = { [7] = true } },

    { id = "books", icon = "k_book", groups = {}, match = function(it)
        return instanceof(it, "Literature") or instanceof(it, "MapItem")
            or (it.getMediaData and it:getMediaData() ~= nil) end },
}
function W:catRects()
    if self.tgiRollHidden then return {} end
    local sf = self.searchFrame
    local x = (sf and (sf.x + sf.w) or 200) + 10
    local s = TITLE_H - 6
    local out = {}
    for i, c in ipairs(W.CATS) do out[i] = { x = x + (i - 1) * (s + 3), y = 3, w = s, h = s, c = c } end
    return out
end

local function keepHotbarShown()
    local C = rawget(_G, "SMB_AutoHideHUD_Controller")
    if not C or type(C.groups) ~= "table" then return end

    if type(C.smbIsAiming) == "function" and not C.tgiAimWrapped then
        local orig = C.smbIsAiming
        C.smbIsAiming = function(...)
            if W.instance then return false end
            return orig(...)
        end
        C.tgiAimWrapped = true
    end
    for _, g in ipairs(C.groups) do
        if type(g) == "table" and type(g.elements) == "table" and g.elements.hotbar then g.forcedHover = true end
    end
end
function W:prerender()
    self.secTip = nil

    if self.tgiClosing then
        local k = (getTimestampMs() - self.tgiClosing) / W.ANIM_CLOSE
        if k >= 1 then
            self:setY(self.tgiBaseY or self:getY())
            self.tgiFade = nil
            self.tgiClosing = nil
            self:close()
            return
        end
        local e = T.inCubic(k)
        self.tgiFade = 1 - T.outCubic(k)
        if self.tgiBaseY then self:setY(self.tgiBaseY - math.floor(W.ANIM_DY * e + 0.5)) end
    elseif T.anim() and not self.tgiOpenDone then
        self.tgiOpenT = self.tgiOpenT or getTimestampMs()
        self.tgiBaseY = self.tgiBaseY or self:getY()
        local k = (getTimestampMs() - self.tgiOpenT) / W.ANIM_OPEN
        if k >= 1 then
            self.tgiOpenDone = true
            self.tgiFade = nil
            self:setY(self.tgiBaseY)

            self.tgiBaseY = nil
        else
            local e = T.outCubic(k)
            self.tgiFade = 0.05 + 0.95 * T.outCubic(math.min(1, k * 1.4))
            self:setY(self.tgiBaseY - math.floor(W.ANIM_DY * (1 - e) + 0.5))
        end
    else
        self.tgiFade = nil
    end

    if (self.frames or 0) < 3 then
        self.frames = (self.frames or 0) + 1
        local ok, err = pcall(self.relayout, self)
        if not ok and not W.relayoutErr then W.relayoutErr = true; print("TGI relayout: " .. tostring(err)) end
        if self.frames == 1 then pcall(self.checkAutoLoot, self) end
    end
    keepHotbarShown()
    if self.tgiRollFadeOut then
        local k = (getTimestampMs() - self.tgiRollFadeOut) / W.ROLL_FADE
        if k >= 1 then
            self.tgiContentFade = nil
            self:setRolled(true)
        else self.tgiContentFade = 1 - T.outCubic(k) end
    end
    if self.tgiRollT then self:rollStep(math.min(1, (getTimestampMs() - self.tgiRollT) / W.ROLL_MS)) end
    if self.tgiRollFadeIn then
        local k = (getTimestampMs() - self.tgiRollFadeIn) / (W.ROLL_FADE + 40)
        if k >= 1 then self.tgiRollFadeIn = nil; self.tgiContentFade = nil
        else self.tgiContentFade = T.outCubic(k) end
    end

    if not self.tgiRollChecked then
        self.tgiRollChecked = true
        local md = nil
        pcall(function() md = getSpecificPlayer(self.pn or 0):getModData().TGIWin end)
        if md and md.rolled then self:setRolled(true, true) end
    end
    ISPanel.prerender(self)
    T.metalFill(self, 1, 1, self.width - 2, self.height - 2, 0.8)
    self:drawRect(0, 0, self.width, TITLE_H, 0.9, 0.05, 0.052, 0.052)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    if T.modern() then

        local tt = string.upper(getText("IGUI_TGI_Title"))
        local tw = TGI.Theme.measure(UIFont.Small, tt)
        self:drawRect(PAD - 4, 2, tw + 8, TITLE_H - 4, 0.9, 0.06, 0.062, 0.06)
        self:drawRect(PAD - 4, TITLE_H - 3, tw + 8, 2, 1, T.accent.r, T.accent.g, T.accent.b)
        self:drawText(tt, PAD, math.floor((TITLE_H - fh) / 2), T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
        self:drawRect(0, TITLE_H - 1, self.width, 1, 0.5, T.border.r, T.border.g, T.border.b)
    else
    self:drawText(getText("IGUI_TGI_Title"), PAD, math.floor((TITLE_H - fh) / 2), T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
    end

    local g = (self.fullscreen or self.tgiRollHidden) and -100 or W.GRIP
    local gh = self.resizing or (self:isMouseOver() and self:getMouseX() >= self.width - g and self:getMouseY() >= self.height - g)
    if not (self.tgiRollHidden or self.fullscreen) then
        for k = 0, 2 do
            local o = 4 + k * 4
            self:drawRect(self.width - o, self.height - 4, 2, 2, 1, T.accent.r, T.accent.g, T.accent.b)
            self:drawRect(self.width - 4, self.height - o, 2, 2, 1, T.accent.r, T.accent.g, T.accent.b)
        end
    end
    if gh then self:drawRect(self.width - g, self.height - g, g, g, 0.25, T.accent.r, T.accent.g, T.accent.b) end

    local cx = self.width - TITLE_H
    local hov = self:isMouseOver() and self:getMouseX() >= cx and self:getMouseY() < TITLE_H

    do
        local bs = TITLE_H - 4
        self:drawRect(cx, 2, bs, bs, 0.9, hov and 0.32 or 0.04, hov and 0.06 or 0.042, hov and 0.05 or 0.042)
        local bc = hov and { r = 0.85, g = 0.3, b = 0.25 } or { r = T.accent.r * 0.7, g = T.accent.g * 0.7, b = T.accent.b * 0.7 }
        self:drawRectBorder(cx, 2, bs, bs, 1, bc.r, bc.g, bc.b)
        local cc = hov and { r = 1, g = 0.88, b = 0.85 } or T.accent
        local n = math.max(3, math.floor(bs * 0.22))
        local mx1, my1 = cx + math.floor(bs / 2), 2 + math.floor(bs / 2)
        for i = -n, n - 1 do
            self:drawRect(mx1 + i, my1 + i, 2, 2, 1, cc.r, cc.g, cc.b)
            self:drawRect(mx1 + i, my1 - i - 1, 2, 2, 1, cc.r, cc.g, cc.b)
        end
    end

    do
        local mx0, my0 = self:getMouseX(), self:getMouseY()
        local rx, ry, rw, rh = self:rollRect()
        local hv = self:isMouseOver() and mx0 >= rx and my0 >= ry and mx0 < rx + rw and my0 < ry + rh
        self:drawRect(rx, ry, rw, rh, 0.9, 0.04, 0.042, 0.042)
        self:drawRectBorder(rx, ry, rw, rh, 1, T.accent.r * 0.7, T.accent.g * 0.7, T.accent.b * 0.7)
        if hv then self:drawRect(rx, ry, rw, rh, 0.12, 1, 1, 1) end

        local cx0, cy0 = math.floor(rx + rw / 2), math.floor(ry + rh / 2)
        for i = 0, 3 do
            local dy = self.tgiRolled and (i - 2) or (1 - i)
            self:drawRect(cx0 - 4 + i, cy0 + dy, 2, 2, 1, T.accent.r, T.accent.g, T.accent.b)
            self:drawRect(cx0 + 2 - i, cy0 + dy, 2, 2, 1, T.accent.r, T.accent.g, T.accent.b)
        end
        if hv then
            local t = getText(self.tgiRolled and "IGUI_TGI_RollDown" or "IGUI_TGI_RollUp")
            local tw = TGI.Theme.measure(UIFont.Small, t)

            local fx = (self:secRects()[1] or { x = rx }).x
            self.secTip = { t = t, x = math.max(2, fx - tw - 12), w = tw + 8 }
        end
    end

    do
        local mx0, my0 = self:getMouseX(), self:getMouseY()
        local gx, gy, gw, gh = self:gearRect()
        local hv = self:isMouseOver() and mx0 >= gx and my0 >= gy and mx0 < gx + gw and my0 < gy + gh
        local on = TGI.Settings and TGI.Settings.instance ~= nil
        self:drawRect(gx, gy, gw, gh, 0.9, on and 0.16 or 0.04, on and 0.16 or 0.042, on and 0.155 or 0.042)
        self:drawRectBorder(gx, gy, gw, gh, 1, T.accent.r * 0.7, T.accent.g * 0.7, T.accent.b * 0.7)
        if hv then self:drawRect(gx, gy, gw, gh, 0.12, 1, 1, 1) end
        local ic = TGI.Draw.tex("ic_gear")
        if ic then self:drawTextureScaled(ic, gx + 3, gy + 3, gw - 6, gh - 6, 1, T.accent.r, T.accent.g, T.accent.b) end
        if hv then
            local t = getText("IGUI_TGI_Settings")
            local tw = TGI.Theme.measure(UIFont.Small, t)
            self.secTip = { t = t, x = math.max(2, (self:secRects()[1] or { x = (self:rollRect()) }).x - tw - 12), w = tw + 8 }
        end
    end

    local mx, my = self:getMouseX(), self:getMouseY()
    if W.KOFI_SHOW then
        local kx, ky, kw, kh = self:kofiRect()
        local kh2 = self:isMouseOver() and mx >= kx and my >= ky and mx < kx + kw and my < ky + kh
        self:drawRect(kx, ky, kw, kh, kh2 and 0.9 or 0.6, kh2 and 0.25 or 0.06, kh2 and 0.2 or 0.062, kh2 and 0.08 or 0.06)
        self:drawRectBorder(kx, ky, kw, kh, 1, T.accent.r * 0.7, T.accent.g * 0.7, T.accent.b * 0.7)
        local ic = TGI.Draw.tex("ic_kofi")
        if ic then self:drawTextureScaled(ic, kx + 2, ky + 2, kw - 4, kh - 4, 1, T.accent.r, T.accent.g, T.accent.b) end
        if kh2 then
            local t = getText("IGUI_TGI_Kofi")
            local tw = TGI.Theme.measure(UIFont.Small, t)
            local fx = (self:secRects()[1] or { x = (self:rollRect()) }).x
            self:drawText(t, fx - tw - 8, math.floor((TITLE_H - fh) / 2), T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
        end
    end

    local sf = (not self.tgiRollHidden) and self.searchFrame or nil
    if sf then
        local sbx = self.searchBox
        local focused = sbx and W.boxFocused(self)
        local txt = sbx and sbx:getText() or ""
        self:drawRect(sf.x, sf.y, sf.w, sf.h, 0.9, T.cell.r, T.cell.g, T.cell.b)
        local bc = focused and T.accent or T.border
        self:drawRectBorder(sf.x, sf.y, sf.w, sf.h, 1, bc.r, bc.g, bc.b)
        local ic = TGI.Draw.tex("ic_k_research")
        local folded = sf.w < sf.h + 4
        local hv = self:isMouseOver() and mx >= sf.x and my >= sf.y and mx < sf.x + sf.w and my < sf.y + sf.h
        if hv and folded then self:drawRect(sf.x, sf.y, sf.w, sf.h, 0.12, 1, 1, 1) end
        local ix = folded and (sf.x + (sf.w - 12) / 2) or (sf.x + 4)
        local icc = (focused or hv) and T.accent or T.dim
        if ic then self:drawTextureScaled(ic, ix, sf.y + (sf.h - 12) / 2, 12, 12, 1, icc.r, icc.g, icc.b) end
        if txt == "" and not focused and sf.w > sf.full - 10 then
            self:drawText(getText("IGUI_TGI_Find"), sf.x + 22, sf.y + math.floor((sf.h - fh) / 2), T.dim.r, T.dim.g, T.dim.b, 0.7, UIFont.Small)
        end
    end

    for _, r in ipairs(self:secRects()) do
        local on = self:secShown(r.sec.id)
        local hv = self:isMouseOver() and mx >= r.x and my >= r.y and mx < r.x + r.w and my < r.y + r.h
        self:drawRect(r.x, r.y, r.w, r.h, 0.9, on and 0.16 or 0.03, on and 0.16 or 0.03, on and 0.155 or 0.03)
        self:drawRectBorder(r.x, r.y, r.w, r.h, on and 0.9 or 0.45, T.accent.r * (on and 0.9 or 0.45), T.accent.g * (on and 0.9 or 0.45), T.accent.b * (on and 0.9 or 0.45))
        if hv then self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 1) end
        local ic = TGI.Draw.tex("ic_" .. r.sec.icon)
        local c = on and T.accent or T.dim
        if ic then self:drawTextureScaled(ic, r.x + 3, r.y + 3, r.w - 6, r.h - 6, on and 1 or 0.5, c.r, c.g, c.b) end
        if hv then
            local t = getText("IGUI_TGI_Sec_" .. r.sec.id)
            local k = TGI.Options.key("secKey_" .. r.sec.id)
            local okN, kn = pcall(function() return Keyboard.getKeyName(k) end)
            if k and k > 0 and okN and kn then t = t .. " [" .. tostring(kn) .. "]" end
            local tw2 = TGI.Theme.measure(UIFont.Small, t)

            local lx = math.max(2, (self:secRects()[1] or { x = (self:rollRect()) }).x - tw2 - 12)
            self.secTip = { t = t, x = lx, w = tw2 + 8 }
        end
    end

    for _, r in ipairs(self:catRects()) do
        local on = TGI.Draw.catFilter ~= nil and TGI.Draw.catFilter[r.c] == true
        local hv = self:isMouseOver() and mx >= r.x and my >= r.y and mx < r.x + r.w and my < r.y + r.h
        self:drawRect(r.x, r.y, r.w, r.h, 0.9, on and 0.2 or 0.04, on and 0.2 or 0.042, on and 0.19 or 0.042)
        self:drawRectBorder(r.x, r.y, r.w, r.h, on and 1 or 0.6, T.accent.r * (on and 1 or 0.6), T.accent.g * (on and 1 or 0.6), T.accent.b * (on and 1 or 0.6))
        if hv then self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 1) end
        local ic = TGI.Draw.tex("ic_" .. r.c.icon)
        local c = on and T.accent or T.dim
        if ic then self:drawTextureScaled(ic, r.x + 3, r.y + 3, r.w - 6, r.h - 6, 1, c.r, c.g, c.b) end
        if hv then
            local t = getText("IGUI_TGI_Cat_" .. r.c.id)
            local tw = TGI.Theme.measure(UIFont.Small, t)
            local last = self:catRects()
            local lx = last[#last].x + last[#last].w + 8
            self:drawText(t, lx, math.floor((TITLE_H - fh) / 2), T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
        end
    end
end

local function bagKey(inv, p)
    if not inv or inv == p:getInventory() then return "inv" end
    local ok, id = pcall(function() return inv:getContainingItem():getID() end)
    return ok and id and tostring(id) or nil
end
local function playerContainers(pn)
    local page = getPlayerInventory(pn)
    if not page then return {} end
    local list = page.backpacks or {}
    local p = getSpecificPlayer(pn)
    local order = p and p:getModData().TGIBagOrder
    if not order or #order == 0 then return list end
    local rank = {}
    for i, k in ipairs(order) do rank[k] = i end
    local out = {}
    for i, btn in ipairs(list) do out[i] = { btn = btn, i = i, k = bagKey(btn.inventory, p) } end
    table.sort(out, function(a, b)
        if a.k == "inv" then return b.k ~= "inv" and true or a.i < b.i end
        if b.k == "inv" then return false end
        local ra, rb = rank[a.k] or (1000 + a.i), rank[b.k] or (1000 + b.i)
        if ra ~= rb then return ra < rb end
        return a.i < b.i
    end)
    local res = {}
    for i, o in ipairs(out) do res[i] = o.btn end
    return res
end

function W.moveBag(from, to)
    local w = W.instance
    local p = w and getSpecificPlayer(w.pn or 0)
    if not p then return end
    local keys = {}
    for _, pn in ipairs(w.mine.panels or {}) do
        local k = bagKey(pn.model and pn.model.container, p)
        if k and k ~= "inv" then keys[#keys + 1] = k end
    end
    local fk, tk = bagKey(from.model.container, p), bagKey(to.model.container, p)
    if not fk or fk == "inv" or fk == tk then return end
    local res = {}
    for _, k in ipairs(keys) do
        if k ~= fk then
            if k == tk then res[#res + 1] = fk end
            res[#res + 1] = k
        end
    end
    if tk == "inv" then table.insert(res, 1, fk) end
    p:getModData().TGIBagOrder = res
    pcall(function() w:refreshContainers(true) end)
end

local function virtualContainer(inv)
    if not inv then return false end
    local t = inv.getType and inv:getType() or ""
    if t == "proxInv" or string.find(string.lower(t), "proxim", 1, true) then return true end
    local items = inv.getItems and inv:getItems()
    if items and items:size() > 0 then
        local it = items:get(0)
        local c = it and it.getContainer and it:getContainer()
        if c and c ~= inv then return true end
    end
    return false
end
local function lootContainers(pn)
    local page = getPlayerLoot(pn)
    if not page then return {} end
    local out = {}
    for _, b in ipairs(page.backpacks or {}) do
        local ok, virt = pcall(virtualContainer, b.inventory)
        if not (ok and virt) then out[#out + 1] = b end
    end
    return out
end

function W:fill(col, list, isPlayer)
    local oldScroll = col:getYScroll()

    local anchorC, anchorOff = nil, nil
    for _, panel in ipairs(col.panels or {}) do
        local py = panel:getY()
        if py + panel:getHeight() > -oldScroll then
            anchorC = panel.model and panel.model.container
            anchorOff = py + oldScroll
            break
        end
    end
    col:clear()
    col.srcList = {}
    for i, btn in ipairs(list) do col.srcList[i] = btn.inventory end
    for i, btn in ipairs(list) do
        local inv = btn.inventory

        local par = inv and inv.getParent and inv:getParent() or nil
        local p = getSpecificPlayer(self.pn)
        if par and p and instanceof(par, "IsoThumpable") and par.isLockedToCharacter and par:isLockedToCharacter(p) then inv = nil end
        if inv then
            local bag = safe(function() return inv:getContainingItem() end, nil)
            local title = btn.name or btn.tooltip or (bag and bag:getDisplayName()) or ""
            local opts = { playerNum = self.pn, bagItem = bag, title = title }
            if isPlayer and i == 1 then opts.kind = "main"; opts.title = getText("IGUI_TGI_Pockets") end
            if safe(function() return inv:getType() end, "") == "floor" then opts.title = getText("IGUI_TGI_Floor") end
            local pnl = col:add(inv, opts)
            if pnl then pnl.tabIcon = btn.image; pnl.tabTitle = opts.title end
        end
    end
    col:layout()

    local max = math.max(0, col:getScrollHeight() - col.height)
    local want = oldScroll or 0
    if anchorC and oldScroll and oldScroll < 0 then
        for _, panel in ipairs(col.panels) do
            if panel.model and panel.model.container == anchorC then want = anchorOff - panel:getY(); break end
        end
    end
    col:setYScroll(math.max(-max, math.min(0, want)))

    if not isPlayer and W.focus and getTimestampMs() - W.focus.t < 3000 then
        for _, panel in ipairs(col.panels) do
            if panel.model and panel.model.container == W.focus.c then
                W.autoFocusPanel = panel
                if self.tabs then col.tabSel = W.focus.c; col:layout() end
                local max = math.max(0, col:getScrollHeight() - col.height)
                col:setYScroll(-math.min(max, math.max(0, panel:getY() - 4)))
                W.focus = nil
                break
            end
        end
    end
end

function W.gearSig(p)
    local parts = {}
    local worn = p.getWornItems and p:getWornItems() or nil
    if worn and worn.size then
        for i = 0, worn:size() - 1 do
            local wi = worn:get(i)
            local it = wi and wi.getItem and wi:getItem() or nil
            if it and instanceof(it, "InventoryContainer") then parts[#parts + 1] = tostring(it:getID()) end
        end
    end
    local a = p.getPrimaryHandItem and p:getPrimaryHandItem() or nil
    local b = p.getSecondaryHandItem and p:getSecondaryHandItem() or nil
    if a and instanceof(a, "InventoryContainer") then parts[#parts + 1] = "h" .. tostring(a:getID()) end
    if b and instanceof(b, "InventoryContainer") then parts[#parts + 1] = "s" .. tostring(b:getID()) end

    local items = p:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "InventoryContainer") then parts[#parts + 1] = "i" .. tostring(it:getID()) end
    end
    return table.concat(parts, ",")
end

function W:refreshContainers(force)
    local mine, loot = playerContainers(self.pn), lootContainers(self.pn)
    if force or not self.mine:sameAs(mine) then self:fill(self.mine, mine, true) end
    if force or not self.loot:sameAs(loot) then self:fill(self.loot, loot, false) end
end

function W.raiseMenu(pn)
    local cm = getPlayerContextMenu(pn or 0)

    local m = cm
    while m and m.getIsVisible and m:getIsVisible() do
        if not m.tgiTop then m.tgiTop = true; m:setAlwaysOnTop(true) end
        m:bringToTop()
        m = m.subMenu
    end
end

local function raisePopups(self)
    local ui = UIManager.getUI()
    for i = 0, ui:size() - 1 do
        local e = ui:get(i)
        local t = e and e.getTable and e:getTable() or nil
        if t and t ~= self and t ~= self.backdrop and t.isVisible and e:isVisible()
            and (t.Type == "ISModalDialog" or t.Type == "ISModalRichText" or t.Type == "ISTextBox" or t.modal or t.isModal) then
            e:bringToTop()
        end
    end
    W.raiseMenu(self.pn)
end

function W:update()
    ISPanel.update(self)

    if W.bagMove and not isMouseButtonDown(0) then
        W.bagMoveUp = (W.bagMoveUp or 0) + 1
        if W.bagMoveUp > 2 then W.bagMove, W.bagMoveUp = nil, 0 end
    else W.bagMoveUp = 0 end

    local down = isMouseButtonDown(0) or isMouseButtonDown(1)
    if down and not self._wasDown then self._raiseBags = 3 end
    self._wasDown = down
    if self._raiseBags and self._raiseBags > 0 then
        self._raiseBags = self._raiseBags - 1
        local any = false
        for _, f in pairs(W.bags or {}) do any = true; pcall(function() f:bringToTop() end) end
        if any then
            if TGI.Drag.ghost and TGI.Drag.active then pcall(function() TGI.Drag.ghost:bringToTop() end) end
            pcall(W.raiseMenu, self.pn)
        end
    end

    local sf, sbx = self.searchFrame, self.searchBox
    if sf and sbx then
        local txt = sbx:getText() or ""
        local focused = W.boxFocused(self)
        local mx, my = self:getMouseX(), self:getMouseY()
        local over = self:isMouseOver() and mx >= sf.x - 4 and my >= 0 and mx < sf.x + sf.w + 4 and my < TITLE_H
        if focused or txt ~= "" then self.searchOpen = true
        elseif self.searchOpen and not over then self.searchOpen = false end
        local target = self.searchOpen and sf.full or sf.h
        local now = getTimestampMs()
        local dt = math.min(100, now - (self.searchT or now)); self.searchT = now
        local k = math.min(1, dt / 90)
        local nw = sf.w + (target - sf.w) * k
        if math.abs(target - nw) < 1 then nw = target end
        if nw ~= sf.w then
            sf.w = nw
            sbx:setWidth(math.max(10, math.floor(nw) - 24))
        end
        sbx:setVisible(sf.w > sf.full - 10)
        if self.searchFocusNext and sf.w > sf.full - 10 then
            self.searchFocusNext = nil
            pcall(function() sbx:focus() end)
        end
    end

    if (self.moving or self.resizing) and not isMouseButtonDown(0) then
        self.moving = false
        self.resizing = nil
        W.savedX, W.savedY = self:getX(), self:getY()
    end

    local d = TGI.Drag.active
    if d and not d.sticky then
        if isMouseButtonDown(0) then self.upSince = nil
        else
            self.upSince = self.upSince or getTimestampMs()
            if getTimestampMs() - self.upSince > 400 then TGI.Drag.cancel(); self.upSince = nil end
        end
    else self.upSince = nil end
    self:holdCombat()
    if self.searchBox then
        local t = string.lower(self.searchBox:getText() or "")
        TGI.Draw.filter = (t ~= "") and t or nil
    end
    local now = getTimestampMs()
    if now < self.nextUpdate then return end
    self.nextUpdate = now + 250

    pcall(function()
        local ui = UIManager.getUI()
        local bi, wi = -1, -1
        for i = 0, ui:size() - 1 do
            local e = ui:get(i)
            if self.backdrop and e == self.backdrop.javaObject then bi = i end
            if e == self.javaObject then wi = i end
        end
        if bi > wi and W.raiseWindows then W.raiseWindows() end
    end)
    pcall(raisePopups, self)
    pcall(self.checkAutoLoot, self)
    local p = getSpecificPlayer(self.pn)
    if not p or p:isDead() then self:close(); return end
    if TGI.inMenu and TGI.inMenu() then self:close(); return end

    local sq = p:getCurrentSquare()

    local dir = p.getDir and tostring(p:getDir()) or ""
    if dir ~= self.lastDir then self.lastDir = dir; W.containersDirty = true end

    local gear = W.gearSig(p)
    if gear ~= self.lastGear then self.lastGear = gear; W.containersDirty = true end
    if sq ~= self.lastSq or W.containersDirty then
        self.lastSq = sq
        W.containersDirty = false
        pcall(function() getPlayerLoot(self.pn):refreshBackpacks() end)
        pcall(function() getPlayerInventory(self.pn):refreshBackpacks() end)
    end

    local soon = W.refreshSoon and now < W.refreshSoon

    if soon then
        local fs = W.floorSig(sq)
        if fs ~= self.lastFloorSig then
            self.lastFloorSig = fs
            pcall(function() getPlayerLoot(self.pn):refreshBackpacks() end)
        else
            soon = false
        end
    end
    self:refreshContainers(false)
    if soon then
        for _, col in ipairs({ self.mine, self.loot }) do
            for _, panel in ipairs(col.panels) do pcall(function() panel.model.dirty = true end) end
        end
    end
    if TGI.Search then TGI.Search.markPlayerItems(self.pn) end
    for _, col in ipairs({ self.mine, self.loot }) do
        for _, panel in ipairs(col.panels) do panel:refresh(false) end
    end
    self:dropOverflow(p, now)
end

function W.floorSig(sq)
    if not sq then return 0 end
    local n = 0
    pcall(function()
        local cell = getCell()
        local x, y, z = sq:getX(), sq:getY(), sq:getZ()
        for dx = -1, 1 do
            for dy = -1, 1 do
                local s2 = cell:getGridSquare(x + dx, y + dy, z)
                if s2 then n = n * 31 + s2:getWorldObjects():size() + 1 end
            end
        end
    end)
    return n
end

W.overSeen = {}
W.everHeld = {}
function W:dropOverflow(p, now)
    local A = TGI.Actions
    local seen = {}
    local known = self.knownIds

    local cur, over = {}, {}
    for _, panel in ipairs(self.mine.panels) do
        local m = panel.model
        for _, e in ipairs(m and m.overflow or {}) do
            for _, it in ipairs(e.items or { e.item }) do over[it:getID()] = true end
        end
        for _, e in ipairs(m and m.entries or {}) do
            for _, it in ipairs(e.items or { e.item }) do
                local id = it:getID()
                if not over[id] then cur[id] = true end
            end
        end
    end
    self.knownIds = cur

    W.handWas = W.handWas or {}
    for hi = 1, 2 do
        local x = hi == 1 and p:getPrimaryHandItem() or p:getSecondaryHandItem()
        local was = W.handWas[hi]
        if was and not x then

            local craft = false
            pcall(function()
                local q0 = ISTimedActionQueue.getTimedActionQueue(p)
                local cur = q0 and q0.queue and q0.queue[1]
                local tn = cur and cur.Type or ""
                craft = tn ~= "" and (string.find(tn, "Craft", 1, true) or string.find(tn, "Recipe", 1, true)
                    or string.find(tn, "Handcraft", 1, true) or string.find(tn, "AddItem", 1, true)) ~= nil
            end)
            if craft then W.handLost = { hand = hi, t = now, ft = was.ft, id = was.id } end
        end
        W.handWas[hi] = x and { id = x:getID(), ft = x:getFullType() } or nil
        if x and W.handLost and W.handLost.hand == hi then W.handLost = nil end
    end
    for hi = 1, 2 do
        local x = hi == 1 and p:getPrimaryHandItem() or p:getSecondaryHandItem()
        if x then
            local xid = x:getID()
            cur[xid] = true
            if self.baseIds then self.baseIds[xid] = true end

            W.everHeld[xid] = true
            W.everHeldN = (W.everHeldN or 0) + 1
            if W.everHeldN > 500 then W.everHeld, W.everHeldN = { [xid] = true }, 1 end
        end
    end

    if not known then
        local before = W.closedKnown
        if before then
            local base = {}
            for id in pairs(cur) do if before[id] then base[id] = true end end

            for id in pairs(over) do if before[id] then base[id] = true end end
            self.baseIds = base
        else

            local base = {}
            for id in pairs(cur) do base[id] = true end
            for id in pairs(over) do base[id] = true end
            self.baseIds = base
        end
        return
    end

    if TGI.Options and TGI.Options.get("dropOverflow") == false then return end

    if p:getVehicle() then return end

    local placing = false
    pcall(function() placing = getCell():getDrag(self.pn) ~= nil end)
    if placing then
        for id in pairs(W.overSeen) do W.overSeen[id] = now + 3000 end
        for id in pairs(W.carriedSeen) do W.carriedSeen[id] = now + 3000 end
        return
    end
    local base = self.baseIds or {}

    local q = ISTimedActionQueue.getTimedActionQueue(p)
    if q and q.queue and #q.queue > 0 then
        for id in pairs(W.overSeen) do W.overSeen[id] = now end
        self.busyUntil = now + 500
        return
    end
    if self.busyUntil and now < self.busyUntil then return end
    local carriedOver = {}
    self.carriedOver = carriedOver

    local hl = W.handLost
    if hl and now - hl.t < 6000 and A and A.equipHand then
        local free = (hl.hand == 1 and not p:getPrimaryHandItem()) or (hl.hand == 2 and not p:getSecondaryHandItem())
        local pick = nil
        for _, panel in ipairs(self.mine.panels) do
            for _, e in ipairs(panel.model and panel.model.overflow or {}) do
                local it = e.item

                if it and not it:IsClothing() and (it:getID() == hl.id or it:getFullType() == hl.ft
                    or not ((self.baseIds or {})[it:getID()] or W.everHeld[it:getID()])) then
                    if not pick or it:getID() == hl.id or it:getFullType() == hl.ft then pick = it end
                end
            end
        end
        if free and pick then
            W.handLost = nil
            W.everHeld[pick:getID()] = true
            pcall(A.equipHand, self.pn, pick, hl.hand == 1)
            return
        end
    elseif hl and now - hl.t >= 6000 then W.handLost = nil end

    local batch, room = {}, {}
    local function fitsIn(c, it)
        local w = it:getUnequippedWeight() or it:getWeight() or 0
        local used = room[c]
        if used == nil then
            local ok, r = pcall(function() return c:hasRoomFor(p, it) end)
            if not (ok and r) then return false end
            used = 0
        end
        local okC, cap = pcall(function() return c:getEffectiveCapacity(p) - c:getCapacityWeight() end)
        if okC and cap and used + w > cap + 0.001 then return false end
        room[c] = used + w
        return true
    end
    for _, panel in ipairs(self.mine.panels) do
        local m = panel.model
        for _, e in ipairs(m and m.overflow or {}) do
            for _, it in ipairs(e.items or { e.item }) do
                local id = it:getID()
                if base[id] or W.everHeld[id] then
                    carriedOver[id] = true
                    self:moveCarriedOver(p, it, now)
                    id = nil
                end
                if id then seen[id] = true end

                local t0 = id and W.overSeen[id]
                if not id then

                elseif not t0 then W.overSeen[id] = now

                elseif now - t0 > 300 then
                    W.overSeen[id] = now + 1500
                    local busy = (A and A.inflightFor and A.inflightFor(it)) or (A and A.isEquipped(p, it)) or it:isFavorite()
                        or (A and A.isLent and A.isLent(it))
                        or (A and A.noFloorMoveable and A.noFloorMoveable(it))
                        or (A and A.noDrop[id] and getTimestampMs() - A.noDrop[id] < 15000)
                    if not busy then

                        W.overDropped = W.overDropped or {}
                        W.overDroppedN = (W.overDroppedN or 0) + 1
                        if W.overDroppedN > 200 then W.overDropped, W.overDroppedN = {}, 1 end
                        W.overDropped[id] = true

                        local pri = W.overflowTarget(p, it)
                        if pri and not fitsIn(pri, it) then pri = nil end

                        local dst = pri
                        if dst then
                            batch[dst] = batch[dst] or {}
                            table.insert(batch[dst], it)
                        else pcall(ISInventoryPaneContextMenu.dropItem, it, self.pn) end
                    end
                end
            end
        end
    end
    for dst, list in pairs(batch) do pcall(A.transfer, self.pn, list, dst) end
    for id in pairs(W.overSeen) do if not seen[id] then W.overSeen[id] = nil end end
    for id in pairs(W.carriedSeen) do if not carriedOver[id] then W.carriedSeen[id] = nil end end
end

W.carriedSeen = {}

W.carriedWhy = {}
function W:moveCarriedOver(p, it, now)
    local id = it:getID()
    local t0 = W.carriedSeen[id]
    if not t0 then W.carriedSeen[id] = now; return end
    if now - t0 < 3000 then return end
    W.carriedSeen[id] = now
    local A = TGI.Actions
    if not A then return end
    if (A.inflightFor and A.inflightFor(it)) or A.isEquipped(p, it) or it:isFavorite()
        or (A.isLent and A.isLent(it)) or (A.noFloorMoveable and A.noFloorMoveable(it)) then W.carriedWhy[id] = "skipped"; return end

    local c = W.overflowTarget(p, it, true)
    if c and (c == p:getInventory() or c:isInCharacterInventory(p)) then
        local ok = pcall(A.transfer, self.pn, { it }, c)
        W.carriedWhy[id] = "sent to " .. tostring(c:getType()) .. (ok and "" or " (error)")
    else W.carriedWhy[id] = "no target" .. (c and (" (" .. tostring(c:getType()) .. " not mine)") or "") end
end

function W.overflowTarget(p, it, mineOnly)
    for _, c in ipairs(mineOnly and { W.qtMine } or { W.qtMine, W.qtLoot }) do
        local own = instanceof(it, "InventoryContainer") and it:getInventory() or nil
        if c and c ~= it:getContainer() and c ~= own then
            local ok, room = pcall(function()
                if instanceof(it, "InventoryContainer") and c:isInside(it) then return false end
                local mineC = c == p:getInventory() or c:isInCharacterInventory(p)
                if mineC then
                    if c == p:getInventory() then return false end
                    return c:hasRoomFor(p, it) and TGI.Strict and TGI.Strict.roomFor(p, it, c)
                end
                local sq = c:getSourceGrid() or (c:getParent() and c:getParent():getSquare())

                if not sq then
                    local ci = c:getContainingItem()
                    local wi = ci and ci:getWorldItem()
                    sq = wi and wi:getSquare()
                end
                if not sq or not p:getSquare() or sq:DistToProper(p:getSquare()) > 2 or sq:getZ() ~= p:getSquare():getZ() then return false end
                return c:hasRoomFor(p, it)
            end)
            if ok and room then return c end
        end
    end

    local found = nil
    pcall(function()
        local items = p:getInventory():getItems()
        for i = 0, items:size() - 1 do
            local b = items:get(i)
            if b ~= it and instanceof(b, "InventoryContainer") then
                local c = b:getInventory()
                if c and c ~= it:getContainer() and not (instanceof(it, "InventoryContainer") and c:isInside(it))
                    and c:hasRoomFor(p, it) and (not TGI.Strict or TGI.Strict.roomFor(p, it, c)) then
                    found = c; return
                end
            end
        end
    end)
    return found
end

function W:tgiContains(ax, ay)
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    return self:isReallyVisible() and ax >= x and ay >= y and ax < x + self.width and ay < y + self.height
end

function W:tgiDropAt() return nil end

function W:onMouseDown(x, y)

    if y < TITLE_H and x >= self.width - TITLE_H - 4 then self.closePress = true; return true end
    if y < TITLE_H then
        local rx, ry, rw, rh = self:rollRect()
        if x >= rx and x < rx + rw and y >= ry and y < ry + rh then self:setRolled(not self.tgiRolled); return true end

        local now = getTimestampMs()
        local cr = self:catRects()
        local freeX = (#cr > 0 and (cr[#cr].x + cr[#cr].w)) or ((self.searchFrame and self.searchFrame.x) or 120)
        if x < freeX then freeX = -1 end
        local sr = self:secRects()
        local freeEnd = (#sr > 0 and sr[1].x) or rx
        if x > freeX and x < freeEnd then
            if self.tgiBarClick and now - self.tgiBarClick < 350 then
                self.tgiBarClick = nil
                self:setRolled(not self.tgiRolled)
                return true
            end
            self.tgiBarClick = now
        end
    end
    local sf = (not self.tgiRollHidden) and self.searchFrame or nil
    if sf and x >= sf.x and x < sf.x + sf.w and y >= sf.y and y < sf.y + sf.h then
        self.searchOpen = true
        self.searchFocusNext = true
        return true
    end
    if y < TITLE_H then
        local kx, ky, kw, kh = self:kofiRect()
        if x >= kx and x < kx + kw and y >= ky and y < ky + kh then self.kofiPress = true; return true end
        local gx, gy, gw, gh = self:gearRect()
        if x >= gx and x < gx + gw and y >= gy and y < gy + gh then
            if TGI.Settings then pcall(TGI.Settings.open, self) end
            return true
        end
        for _, r in ipairs(self:catRects()) do
            if x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h then

                local f = TGI.Draw.catFilter or {}
                if f[r.c] then f[r.c] = nil else f[r.c] = true end
                local any = false
                for _ in pairs(f) do any = true; break end
                TGI.Draw.catFilter = any and f or nil
                return true
            end
        end
        for _, r in ipairs(self:secRects()) do
            if x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h then
                self:toggleSection(r.sec.id)
                return true
            end
        end

    end
    if not self.fullscreen and not self.tgiRollHidden and x >= self.width - W.GRIP and y >= self.height - W.GRIP then
        self.resizing = { ox = self.width - x, oy = self.height - y }
        return true
    end
    return ISPanel.onMouseDown(self, x, y)
end

local PASS_NAMES = { "Forward", "Backward", "Left", "Right", "Run", "Sprint" }
local function passKey(key)
    if key == Keyboard.KEY_LSHIFT or key == Keyboard.KEY_RSHIFT then return true end
    if key == Keyboard.KEY_W or key == Keyboard.KEY_A or key == Keyboard.KEY_S or key == Keyboard.KEY_D then return true end

    if key ~= Keyboard.KEY_ESCAPE and KeybindId then
        for _, id in ipairs({ "PAUSE", "NORMAL_SPEED", "FAST_FORWARD_X1", "FAST_FORWARD_X2", "FAST_FORWARD_X3" }) do
            local ok, hit = pcall(function() return KeybindId[id] and getCore():isKey(KeybindId[id], key) end)
            if ok and hit then return true end
        end
    end
    for _, n in ipairs(PASS_NAMES) do
        local ok, k = pcall(function() return getCore():getKey(n) end)
        if ok and k == key and k ~= Keyboard.KEY_LCONTROL and k ~= Keyboard.KEY_RCONTROL then return true end
    end
    return false
end
local function isInvKey(key)
    local r = false
    pcall(function() r = TGI.isInvKey(key) end)
    return r or key == TGI.Options.key("openKey")
end

function W:isKeyConsumed(key)
    if W.boxFocused(self) then return true end

    local drag = nil
    pcall(function() drag = getCell():getDrag(self.pn or 0) end)
    if drag then return false end

    if TGI.Options.get("invKeys") == false and not isInvKey(key) then return false end
    return not passKey(key)
end

function W.boxFocused(w)
    if not w or not w.searchBox then return false end
    local ok, v = pcall(function() return w.searchBox:isFocused() end)
    return ok and v == true
end

function W.typing()
    local w = W.instance
    return w and W.boxFocused(w) or false
end

function W:onKeyPress(key)
    if W.typing() then return end

    if isInvKey(key) and TGI.Options.get("replaceVanilla") ~= false then self:closeAnimated(); return end
    for _, sec in ipairs(W.SECTIONS) do
        local k = TGI.Options.key("secKey_" .. sec.id)
        if k and k > 0 and key == k then self:toggleSection(sec.id); return end
    end

    local drag = nil
    pcall(function() drag = getCell():getDrag(self.pn or 0) end)
    if drag then return end
    if key == TGI.Options.key("rotateKey") and TGI.rotateKey then TGI.rotateKey() end
end

function W:onKeyRelease(key)
    if W.boxFocused(self) then
        if key == Keyboard.KEY_ESCAPE then self.searchBox:unfocus() end
        return true
    end
    if key == Keyboard.KEY_ESCAPE or isInvKey(key) then
        self:close()
        return true
    end
    return false
end

function W.sound(name)
    if W.quiet then return end
    if TGI.Options and TGI.Options.get("openSound") == false then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

W.ANIM_OPEN, W.ANIM_CLOSE, W.ANIM_DY = 260, 190, 34
W.ANIM_TAG = "kestrel-0417"

function W:closeAnimated()
    if not T.anim() or self.tgiClosing then return self:close() end
    if W.instance == self then W.instance = nil end

    if self.tgiOpenDone or not self.tgiBaseY then self.tgiBaseY = self:getY() end
    self.tgiClosing = getTimestampMs()
    W.closedAt = getTimestampMs()
end

function W:close()
    if self.tgiClosing then self:setY(self.tgiBaseY or self:getY()); self.tgiClosing = nil end

    if not self.tgiClosed then self.tgiClosed = true; W.sound("CloseBag") end
    W.live[self] = nil
    pcall(function()
        if self.fullscreen then return end
        W.savedX, W.savedY, W.savedW, W.savedH = self:getX(), self:getY(), self.width, (self.tgiRollHidden and self.tgiFullH) or self.height

        W.savedLootAuto = self.autoLootHidden == true
        local md = getSpecificPlayer(self.pn or 0):getModData()
        local old = md.TGIWin or {}
        md.TGIWin = { x = W.savedX, y = W.savedY, w = W.savedW, h = W.savedH, hide = old.hide, lootAuto = W.savedLootAuto, rolled = self.tgiRolled == true }
    end)

    if self.knownIds then
        local k = {}
        for id in pairs(self.knownIds) do k[id] = true end

        for id in pairs(self.carriedOver or {}) do k[id] = true end
        W.closedKnown = k
    end
    W.qolMark(self, false)
    if TGI.Settings then pcall(TGI.Settings.close) end
    if W.instance == self then W.instance = nil end
    if TGI.Rate then pcall(TGI.Rate.onInventoryClosed) end

    if TGI.Appliance and TGI.Appliance.inst then pcall(function() TGI.Appliance.inst:close() end) end

    pcall(function()
        local cm = getPlayerContextMenu(self.pn or 0)
        if cm and cm:getIsVisible() then cm:closeAll() end
    end)
    if self.tabs then pcall(TGI.Drag.unregister, self.tabs) end
    W.autoFocusPanel = nil
    pcall(W.restoreAimKey)
    self.resizing = nil
    for bag, f in pairs(W.bags) do pcall(function() f:close() end) end
    TGI.Draw.filter = nil
    TGI.Draw.catFilter = nil; TGI.Draw._grp = nil
    pcall(function() if TGI.Tip then TGI.Tip.hide() end end)
    pcall(function() self.mine:clear() end)
    pcall(function() self.loot:clear() end)
    pcall(function() self.equip:close() end)
    pcall(function() Drag.unregister(self) end)
    pcall(function() Drag.cancel() end)
    pcall(function() self:setVisible(false) end)
    pcall(function() self:removeFromUIManager() end)
    if self.backdrop then
        pcall(function() if self.backdrop.holder then self.backdrop.holder:setCapture(false) end end)
        pcall(function() self.backdrop:setCapture(false) end)
        pcall(function() self.backdrop:removeFromUIManager() end); self.backdrop = nil
    end
    if W.instance == self then W.instance = nil end
    if self.tabs then pcall(TGI.Drag.unregister, self.tabs) end
    W.autoFocusPanel = nil
    W.closedAt = getTimestampMs()
end

local B = ISPanel:derive("TGIBackdrop")
function B:new()
    local o = ISPanel:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.anchorRight, o.anchorBottom = true, true
    return o
end
function B:prerender() end

function B:update()
    if not self.tgiCap then return end
    local want = TGI.Drag and TGI.Drag.active and true or false
    if self.capOn == want then return end
    self.capOn = want
    pcall(function() self.javaObject:setCapture(want) end)
end

local strayNext = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < strayNext then return end
    strayNext = now + 1000
    local live = W.instance and W.instance.backdrop
    local ui = UIManager.getUI()
    local stray = nil
    for i = 0, ui:size() - 1 do
        local e = ui:get(i)
        local t = e and e:getTable()
        if t and t.Type == "TGIBackdrop" and t ~= live then stray = stray or {}; stray[#stray + 1] = t end
    end
    for _, t in ipairs(stray or {}) do
        pcall(function() if t.holder then t.holder:setCapture(false) end end)
        pcall(function() t:setCapture(false) end)
        pcall(function() t:removeFromUIManager() end)
    end
end)
local function noop() return false end
function B:addHolder()
    local h = ISUIElement:new(0, 0, 1, 1)
    h:initialise()
    h.onMouseDown = noop; h.onMouseUp = noop; h.onRightMouseDown = noop; h.onRightMouseUp = noop
    h.onMouseWheel = noop; h.onFocus = function() end
    h.render = function() end; h.prerender = function() end
    self:addChild(h)
    pcall(function() h:setCapture(true) end)
    self.holder = h
end

local function raiseWindows()
    local w = W.instance
    if not w then return end

    local ours = { [w.javaObject] = true }
    if w.backdrop then ours[w.backdrop.javaObject] = true end
    for _, f in pairs(W.bags or {}) do if f.javaObject then ours[f.javaObject] = true end end
    local above = {}
    pcall(function()
        local ui = UIManager.getUI()
        local wi = -1
        for i = 0, ui:size() - 1 do if ui:get(i) == w.javaObject then wi = i end end
        if wi < 0 then return end
        for i = wi + 1, ui:size() - 1 do
            local o = ui:get(i)
            if o and not ours[o] and o:isVisible() then above[#above + 1] = o end
        end
    end)

    if w.backdrop then pcall(function() w.backdrop:backMost() end) end
    pcall(function() w:bringToTop() end)
    for _, f in pairs(W.bags or {}) do pcall(function() f:bringToTop() end) end

    pcall(function() local hb = getPlayerHotbar(w.pn or 0); if hb then hb:bringToTop() end end)
    if TGI.Quick and TGI.Quick.inst then pcall(function() TGI.Quick.inst:bringToTop() end) end
    for _, o in ipairs(above) do pcall(function() o:bringToTop() end) end
    if TGI.Drag.ghost then pcall(function() TGI.Drag.ghost:bringToTop() end) end
    pcall(W.raiseMenu, w.pn)
end
W.raiseWindows = raiseWindows
function B:onMouseDown() raiseWindows(); return true end
function B:onMouseUp() if TGI.Drag.active then TGI.Drag.finish() end; raiseWindows(); return true end
function B:onRightMouseDown() raiseWindows(); return true end
function B:onRightMouseUp() raiseWindows(); return true end
function B:onMouseUpOutside() raiseWindows() end
function B:onMouseWheel() return true end

local function noAim(p)
    if p and p.isAiming and p.setIsAiming and p:isAiming() then p:setIsAiming(false) end
end
local function aimId() return (KeybindId and KeybindId.AIM) or "Aim" end

function W.releaseAimKey()
    local core = getCore()
    if W.savedAim then return end
    local id = aimId()
    local ok, k, alt = pcall(function() return core:getKey(id), (core.getAltKey and core:getAltKey(id) or 0) end)
    if not ok or not k or (k == 0 and (alt or 0) == 0) then return end

    local function ctrl(x) return x == Keyboard.KEY_LCONTROL or x == Keyboard.KEY_RCONTROL end
    if not (ctrl(k) or ctrl(alt or 0)) then return end
    local done = pcall(function() core:addKeyBinding(id, 0, 0, false, false, false) end)
    if not done then return end

    local sh, ct, al = false, false, false
    pcall(function()
        for _, b in ipairs(keyBinding or {}) do
            if tostring(b.value) == tostring(id) or b.value == "Aim" then sh, ct, al = b.shift == true, b.ctrl == true, b.alt == true; break end
        end
    end)
    W.savedAim = { k = k, alt = alt or 0, sh = sh, ct = ct, al = al }
    pcall(function()
        local wr = getFileWriter("TGI_aimkey.txt", true, false)
        wr:write(tostring(k) .. " " .. tostring(alt or 0)); wr:close()
    end)
end
function W.restoreAimKey()
    local s = W.savedAim
    W.savedAim = nil
    if s then pcall(function() getCore():addKeyBinding(aimId(), s.k, s.alt, s.sh, s.ct, s.al) end) end
    pcall(function()
        local wr = getFileWriter("TGI_aimkey.txt", true, false)
        wr:write(""); wr:close()
    end)
end

local function recoverAimKey()
    if W.instance or W.savedAim then return end
    local ok, k, alt = pcall(function()
        local rd = getFileReader("TGI_aimkey.txt", false)
        if not rd then return nil end
        local l = rd:readLine(); rd:close()
        if not l then return nil end
        local a, b = string.match(l, "(%d+)%s*(%d*)")
        return tonumber(a), tonumber(b) or 0
    end)
    if not (ok and k and k ~= 0) then return end
    pcall(function()
        if getCore():getKey(aimId()) == 0 then getCore():addKeyBinding(aimId(), k, alt or 0, false, false, false) end
    end)
end
Events.OnGameStart.Add(recoverAimKey)
Events.OnMainMenuEnter.Add(recoverAimKey)
function W:holdCombat()

    if self:isMouseOver() then noAim(getSpecificPlayer(self.pn)) end
end

local qolProxy = { getIsVisible = function() return W.instance ~= nil end }
function W.qolMark(win, on)
    if not rawget(_G, "ProjectViewpointQOL") or not ISEntityUI then return end
    pcall(function()
        if ISEntityUI.EnsurePlayers then ISEntityUI.EnsurePlayers() end
        if not ISEntityUI.players then return end
        local pd = ISEntityUI.players[0]
        if not pd then pd = { windows = {} }; ISEntityUI.players[0] = pd end
        pd.windows = pd.windows or {}
        pd.windows.TGIInventory = on and { instance = qolProxy } or nil
    end)
end

function W.dropLost()
    local wi = W.instance
    if not wi then return end
    local found = false
    local ok = pcall(function()
        local ui = UIManager.getUI()
        for i = 0, ui:size() - 1 do if ui:get(i) == wi.javaObject then found = true; break end end
    end)

    if not ok or found then return end
    W.instance = nil
    pcall(function() wi:close() end)
    pcall(function() if wi.backdrop then wi.backdrop:removeFromUIManager() end end)
end

function W.toggle(pn)
    W.dropLost()
    if not W.instance and W.closedAt and getTimestampMs() - W.closedAt < 150 then return end
    if W.instance then
        local wi = W.instance
        W.instance = nil
        wi:closeAnimated()
        return
    end

    for old in pairs(W.live) do pcall(function() old:close() end); W.live[old] = nil end
    pcall(function() T.apply(tonumber(TGI.Options.get("theme")) or 1) end)
    pcall(T.applyScale)
    W.sound("OpenBag")
    local w = W:new(pn or 0)
    local b = B:new()
    b:initialise()
    b:addToUIManager()

    if rawget(_G, "ViewpointLoot") then pcall(function() b:addHolder() end); b.tgiCap = true end
    W.qolMark(w, true)
    w.backdrop = b
    w:initialise()
    w:addToUIManager()
    W.instance = w
    raiseWindows()
    W.releaseAimKey()
end

function W.quickTransfer(pn, entry, model)
    local w = W.instance
    if not w then return end
    local p = getSpecificPlayer(pn)
    local fromPlayer = p and model.container:isInCharacterInventory(p)
    local candidates = {}
    if fromPlayer then
        for _, panel in ipairs(w.loot.panels) do
            if safe(function() return panel.model.container:getType() end, "") ~= "floor" then candidates[#candidates + 1] = panel end
        end
        for _, panel in ipairs(w.loot.panels) do
            if safe(function() return panel.model.container:getType() end, "") == "floor" then candidates[#candidates + 1] = panel end
        end
    else
        for _, panel in ipairs(w.mine.panels) do candidates[#candidates + 1] = panel end
    end

    for _, f in pairs(W.bags or {}) do
        if f.grid and f.grid.model then
            local inMine = p and safe(function() return f.grid.model.container:isInCharacterInventory(p) end, false)
            if inMine ~= fromPlayer then candidates[#candidates + 1] = f.grid end
        end
    end

    local tgt = fromPlayer and W.qtLoot or W.qtMine

    for _, f in pairs(W.bags or {}) do
        local c = f.grid and f.grid.model and f.grid.model.container
        if c and c ~= model.container and (c == W.qtMine or c == W.qtLoot) then
            tgt = c
            local have = false
            for _, panel in ipairs(candidates) do if panel == f.grid then have = true end end
            if not have then candidates[#candidates + 1] = f.grid end
        end
    end
    if tgt then
        for i, panel in ipairs(candidates) do
            if panel.model.container == tgt then table.remove(candidates, i); table.insert(candidates, 1, panel); break end
        end
    end
    for _, panel in ipairs(candidates) do
        local m = panel.model
        if m.container ~= model.container then
            m:ensure()
            local roomy = safe(function() return m.container:hasRoomFor(p, entry.item) end, true)
            local pi, x, y, rot = m:findSpotFor(entry)
            if roomy and pi then
                for _, it in ipairs(entry.items) do A.setPending(it, m:layoutSig(), pi, x, y, rot) end
                A.transfer(pn, entry.items, m.container)
                return true
            end
        end
    end
    return false
end

local F = ISPanel:derive("TGIBagWindow")
TGI.Theme.applyAlpha(F)
TGI.BagWindow = F
function F:new(pn, bag)
    local o = ISPanel:new(getMouseX() + 20, getMouseY() - 40, 200, 100)
    setmetatable(o, self)
    self.__index = self
    o.pn, o.bag = pn, bag
    o.backgroundColor = { r = T.bg.r, g = T.bg.g, b = T.bg.b, a = T.bg.a }
    o.borderColor = { r = T.accent.r, g = T.accent.g, b = T.accent.b, a = 0.8 }
    o.moveWithMouse = true
    return o
end
function F:createChildren()
    local win = self
    self.grid = TGI.GridPanel:new(PAD, TITLE_H, self.bag:getInventory(), {
        playerNum = self.pn, bagItem = self.bag, title = self.bag:getDisplayName(),
        onLayout = function() win:fit() end })
    self.grid:initialise()
    self:addChild(self.grid)
    self:fit()
end

function F:fit()
    local g = self.grid
    if not g then return end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local full = g.height + TITLE_H + PAD
    local maxH = math.max(200, sh - 40)
    local scroll = full > maxH
    if scroll and not self.vscroll then
        self:addScrollBars()
        self:setScrollChildren(true)
        if self.vscroll then self.vscroll.render = W.drawScrollBar end
    end
    local sbw = (scroll and self.vscroll) and self.vscroll.width or 0
    self:setWidth(g.width + PAD * 2 + sbw)
    self:setHeight(math.min(full, maxH))
    if self.vscroll then
        self:setScrollHeight(scroll and full or self.height)
        self.vscroll:setVisible(scroll)
        self.vscroll:setX(self.width - self.vscroll.width)
        self.vscroll:setY(0)
        self.vscroll:setHeight(self.height)
        if not scroll then self:setYScroll(0)
        else self:setYScroll(math.max(-(full - self.height), math.min(0, self:getYScroll()))) end
    end

    self:setX(math.max(0, math.min(self:getX(), sw - self.width)))
    self:setY(math.max(0, math.min(self:getY(), sh - self.height)))
end
function F:onMouseWheel(del)
    if not (self.vscroll and self.vscroll:getIsVisible()) then return false end
    local full = self:getScrollHeight()
    self:setYScroll(math.min(0, math.max(self:getYScroll() - del * 60, -(full - self.height))))
    return true
end
function F:prerender()
    if T.anim() then
        self.tgiOpenT = self.tgiOpenT or getTimestampMs()
        local k = (getTimestampMs() - self.tgiOpenT) / 140
        self.tgiFade = k < 1 and (0.15 + 0.85 * k) or nil
    else self.tgiFade = nil end
    ISPanel.prerender(self)

    do
        local hv = self:isMouseOver() and self:getMouseX() > self.width - 20 and self:getMouseY() < TITLE_H
        local cc = hv and { r = 0.95, g = 0.4, b = 0.35 } or T.dim
        local mx1, my1 = self.width - 10, math.floor(TITLE_H / 2) - 1
        for i = -3, 2 do
            self:drawRect(mx1 + i, my1 + i, 2, 2, 1, cc.r, cc.g, cc.b)
            self:drawRect(mx1 + i, my1 - i - 1, 2, 2, 1, cc.r, cc.g, cc.b)
        end
    end
end
function F:onMouseDown(x, y)
    if x > self.width - 20 and y < TITLE_H then self.closePress = true; return true end
    return ISPanel.onMouseDown(self, x, y)
end
function F:onMouseUp(x, y)
    if self.closePress then
        self.closePress = nil
        if x > self.width - 20 and y < TITLE_H then self:close() end
        return true
    end
    return ISPanel.onMouseUp(self, x, y)
end
function F:onMouseUpOutside(x, y)
    self.closePress = nil
    return ISPanel.onMouseUpOutside(self, x, y)
end
function F:update()
    ISPanel.update(self)

    local nowF = getTimestampMs()

    if self.nextUpdate and nowF < self.nextUpdate then self.grid:refresh(false); return end
    self.nextUpdate = nowF + 250
    local p = getSpecificPlayer(self.pn)
    local cont = self.bag:getContainer()
    local ok = p ~= nil and cont ~= nil and cont:isInCharacterInventory(p)

    local outer, depth = cont, 0
    while not ok and outer and depth < 8 do
        if W.instance then
            for _, c in ipairs(W.instance.loot.containers) do if c == outer then ok = true end end
            for _, c in ipairs(W.instance.mine.containers) do if c == outer then ok = true end end
        end
        if ok then break end
        local holder = nil
        pcall(function() holder = outer:getContainingItem() end)
        outer = holder and holder:getContainer() or nil
        depth = depth + 1
    end

    if not ok and cont then
        for bag in pairs(W.bags) do
            local inv = nil
            pcall(function() inv = bag:getInventory() end)
            if inv == cont then ok = true end
        end
    end
    if not ok then self:close(); return end
    self.grid:refresh(false)
end
function F:close()
    self.grid:close()
    self:removeFromUIManager()
    W.bags[self.bag] = nil
end

W.bags = {}
function W.openBag(pn, bag)

    if W.bags[bag] then pcall(function() W.bags[bag]:close() end); return end
    local f = F:new(pn, bag)
    f:initialise()
    f:addToUIManager()

    pcall(function() f:bringToTop() end)

    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    f:setX(math.max(0, math.min(f:getX(), sw - f.width)))
    f:setY(math.max(0, math.min(f:getY(), sh - f.height)))
    W.bags[bag] = f
end

do
    local held = false
    local function restore()
        if held then
            held = false
            pcall(function() getCore():setOptionUIFBO(true) end)
        end
    end
    local function apply()
        if held or not (TGI.Options and TGI.Options.get("smoothUI") ~= false) then return end
        local ok, on = pcall(function() return getCore():getOptionUIFBO() end)
        if ok and on then
            held = true
            pcall(function() getCore():setOptionUIFBO(false) end)
        end
    end
    local toggle = W.toggle
    W.toggle = function(...)
        local r = toggle(...)
        if W.instance then apply() else restore() end
        return r
    end
    local close = W.close
    W.close = function(self, ...)
        local r = close(self, ...)
        if not W.instance then restore() end
        return r
    end
    W.restoreUIFBO = restore
    Events.OnPlayerDeath.Add(restore)
end

function W:onMouseWheel() return true end

function W:renderActionBar()
    local D = TGI.Draw
    local a = D and D.currentAction and D.currentAction(getSpecificPlayer(self.pn))
    if not a or not a.frac then return end
    local secs = self:secRects()
    local right = (secs[1] and secs[1].x or self.width - 60) - 10

    local cats = self:catRects()
    local last = cats[#cats]
    local left = (last and (last.x + last.w) or 180) + 110
    local w = math.min(260, right - left)
    if w < 90 then return end
    local x = math.floor(left + (right - left - w) / 2)
    local y, h = 4, TITLE_H - 8
    local f = math.max(0, math.min(1, a.frac))
    self:drawRect(x, y, w, h, 0.85, 0.03, 0.03, 0.03)
    self:drawRect(x + 1, y + 1, (w - 2) * f, h - 2, 0.55, T.accent.r, T.accent.g, T.accent.b)
    self:drawRectBorder(x, y, w, h, 0.9, T.accent.r * 0.8, T.accent.g * 0.8, T.accent.b * 0.8)
    local txt = a.name or ""
    if a.item then txt = txt .. ": " .. a.item:getDisplayName() end
    local fh = getTextManager():getFontHeight(UIFont.Small)
    txt = D._short and D._short(txt, w - 8, UIFont.Small) or txt
    self:drawTextCentre(txt, x + w / 2, y + math.floor((h - fh) / 2), T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
end

function W:render()
    if ISPanel.render then ISPanel.render(self) end
    pcall(self.renderActionBar, self)
    local st = self.secTip
    if st then
        local fh = getTextManager():getFontHeight(UIFont.Small)
        self:drawRect(st.x, 3, st.w, TITLE_H - 6, 1, 0.04, 0.04, 0.04)
        self:drawRectBorder(st.x, 3, st.w, TITLE_H - 6, 0.8, T.accent.r, T.accent.g, T.accent.b)
        self:drawText(st.t, st.x + 4, math.floor((TITLE_H - fh) / 2), T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
end

do
    local t = 0
    Events.OnTick.Add(function()
        t = t + 1
        if t % 30 == 0 and W.instance then pcall(W.dropLost) end
    end)
end

W.LIVE_OPTS = { theme = true, colorPreset = true, uiAlpha = true, animations = true, tileColor = true }
local optSig, optTick = nil, 0
local function optionsSig()
    local O = TGI.Options

    for _ in pairs(O.override or {}) do return optSig end
    local t = {}
    for _, r in ipairs(O.LAYOUT or {}) do
        if r.id and not W.LIVE_OPTS[r.id] then t[#t + 1] = r.id .. "=" .. tostring(O.get(r.id)) end
    end
    return table.concat(t, ";")
end
function W.rebuild()
    local w = W.instance
    if not w then return end
    local pn = w.pn or 0
    local settingsOpen = TGI.Settings and TGI.Settings.instance ~= nil
    local animWas = TGI.Theme.anim
    TGI.Theme.anim = function() return false end
    W.quiet = true
    pcall(function()
        W.instance = nil
        w:close()
        W.closedAt = nil
        W.toggle(pn)
    end)
    TGI.Theme.anim = animWas
    W.quiet = nil
    if W.instance then W.instance.tgiOpenDone = true end
    if settingsOpen and TGI.Settings and W.instance then
        pcall(TGI.Settings.close)
        pcall(TGI.Settings.open, W.instance)
    end
end
Events.OnTick.Add(function()
    optTick = optTick + 1
    if optTick % 20 ~= 0 then return end
    local okS, sig = pcall(optionsSig)
    if not okS then return end
    if optSig and sig ~= optSig and W.instance and not W.instance.tgiClosing then pcall(W.rebuild) end
    optSig = sig
end)

local aboveTick = 0
Events.OnTick.Add(function()
    aboveTick = aboveTick + 1
    if aboveTick % 15 ~= 0 or not W.instance or not ISRadioWindow then return end
    for _, list in ipairs({ ISRadioWindow.instances or {}, ISRadioWindow.instancesIso or {} }) do
        for _, rw in pairs(list) do
            if rw and rw.isVisible and rw:isVisible() then pcall(function() rw:bringToTop() end) end
        end
    end
end)

return W
