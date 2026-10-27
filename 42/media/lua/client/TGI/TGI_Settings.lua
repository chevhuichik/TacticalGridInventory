require "ISUI/ISPanel"
require "TGI/TGI_Theme"

TGI = TGI or {}
local T = TGI.Theme
local S = ISPanel:derive("TGISettings")
TGI.Settings = S
T.applyAlpha(S)

local ROW = 22
local PAD = 8
local W0 = 380

local function txt(k)
    local t = getText(k)
    return t
end

function S:new(win)
    local h = math.min(getCore():getScreenHeight() - 80, 560)
    local x = math.max(10, win:getAbsoluteX() + win.width - W0 - 10)
    local y = math.max(10, win:getAbsoluteY() + 30)
    local o = ISPanel:new(x, y, W0, h)
    setmetatable(o, self); self.__index = self
    o.win = win
    o.scroll = 0
    o.moveWithMouse = true
    o.background = false
    return o
end

function S:rows()
    local out = {}
    for _, r in ipairs(TGI.Options.LAYOUT or {}) do out[#out + 1] = r end
    return out
end

local function valueOf(r)
    local v = TGI.Options.get(r.id)
    if r.k == "tick" then return v ~= false end
    if r.k == "combo" then
        local n = tonumber(v) or 1
        if n < 1 or n > #r.items then n = 1 end
        return n
    end
    if r.k == "slider" then return tonumber(v) or r.max end
end

local function afterChange(id)
    local W = TGI.Window
    if T.readLook then pcall(T.readLook) end
    if id == "theme" then pcall(function() T.apply(tonumber(TGI.Options.get("theme")) or 1) end) end
    if id == "cellScale" or id == "fullscreen" then

        pcall(T.applyScale)
        if W and W.instance then
            local pn = W.instance.pn or 0
            W.instance:close()
            W.closedAt = nil
            W.toggle(pn)
            if W.instance then S.open(W.instance) end
        end
    end
end

function S:change(r, dir)
    local v = valueOf(r)
    if r.k == "tick" then TGI.Options.set(r.id, not v)
    elseif r.k == "combo" then

        local n = #r.items
        local nv = math.floor(v) + (dir or 1)
        if nv < 1 then nv = n elseif nv > n then nv = 1 end
        TGI.Options.set(r.id, nv)
    elseif r.k == "slider" then
        local nv = math.max(r.min, math.min(r.max, v + (dir or 1) * r.step))
        nv = math.floor(nv / r.step + 0.5) * r.step
        TGI.Options.set(r.id, nv)
    end
    getSoundManager():playUISound("UIToggleTickBox")
    afterChange(r.id)
end

function S:contentH() return #self:rows() * ROW end
function S:viewTop() return 30 end
function S:viewH() return self.height - self:viewTop() - 44 end

function S:prerender()
    T.metalFill(self, 0, 0, self.width, self.height, 0.6)
    self:drawRect(0, 0, self.width, self.height, 0.96, T.bg.r, T.bg.g, T.bg.b)
    self:drawRectBorder(0, 0, self.width, self.height, 1, T.border.r, T.border.g, T.border.b)
    self:drawRect(0, 0, self.width, 24, 0.95, 0.05, 0.052, 0.052)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:drawText(txt("IGUI_TGI_Settings"), PAD, math.floor((24 - fh) / 2), T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)

    local mx, my = self:getMouseX(), self:getMouseY()
    local hx = self:isMouseOver() and mx >= self.width - 24 and my < 24
    self:drawTextCentre("X", self.width - 12, math.floor((24 - fh) / 2), hx and 1 or 0.8, hx and 0.5 or 0.8, hx and 0.4 or 0.75, 1, UIFont.Small)
end

function S:render()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local top, vh = self:viewTop(), self:viewH()
    local maxS = math.max(0, self:contentH() - vh)
    self.scroll = math.max(0, math.min(maxS, self.scroll))
    self:setStencilRect(0, top, self.width, vh)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    self.hoverRow = nil
    for i, r in ipairs(self:rows()) do
        local y = top + (i - 1) * ROW - self.scroll
        if y + ROW >= top and y <= top + vh then
            local hov = over and my >= y and my < y + ROW and my >= top and my < top + vh
            local ty = y + math.floor((ROW - fh) / 2)
            if r.k == "title" then
                self:drawText(txt(r.key), PAD, ty + 2, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
                self:drawRect(PAD, y + ROW - 2, self.width - PAD * 2, 1, 0.5, T.accent.r, T.accent.g, T.accent.b)
            else
                if hov then self:drawRect(2, y, self.width - 4, ROW, 0.08, 1, 1, 1); self.hoverRow = r end
                local label = txt("IGUI_TGI_Opt_" .. r.id)
                local v = valueOf(r)
                if r.k == "tick" then
                    local bx, by = PAD, y + 4
                    self:drawRectBorder(bx, by, 14, 14, 1, T.border.r + 0.2, T.border.g + 0.2, T.border.b + 0.2)
                    if v then self:drawRect(bx + 3, by + 3, 8, 8, 1, T.accent.r, T.accent.g, T.accent.b) end
                    self:drawText(label, bx + 22, ty, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
                else
                    self:drawText(label, PAD, ty, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
                    local vt
                    if r.k == "combo" then vt = r.items[v] and txt(r.items[v]) or tostring(v)
                    else vt = string.format("%.2f", v) end
                    local right = self.width - PAD
                    self:drawTextRight(">", right, ty, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
                    self:drawTextRight(vt, right - 16, ty, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
                    local vw = T.measure(UIFont.Small, vt)
                    self:drawTextRight("<", right - 22 - vw, ty, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
                end
            end
        end
    end
    self:clearStencilRect()

    local r = self.hoverRow
    local tt = r and r.tt and getText(r.tt) or nil
    if tt and tt ~= r.tt then
        local y0 = self.height - 42
        self:drawRect(0, y0, self.width, 1, 0.6, T.border.r, T.border.g, T.border.b)
        local line, ly = "", y0 + 3
        for word in string.gmatch(tt, "%S+") do
            local tryl = line == "" and word or (line .. " " .. word)
            if T.measure(UIFont.Small, tryl) > self.width - PAD * 2 and line ~= "" then
                self:drawText(line, PAD, ly, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
                ly = ly + fh
                line = word
                if ly > self.height - fh then break end
            else line = tryl end
        end
        if line ~= "" and ly <= self.height - fh then self:drawText(line, PAD, ly, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small) end
    end

    if maxS > 0 then
        local bh = math.max(20, vh * vh / self:contentH())
        local by = top + (vh - bh) * self.scroll / maxS
        self:drawRect(self.width - 4, by, 3, bh, 0.6, T.accent.r, T.accent.g, T.accent.b)
    end
end

function S:onMouseWheel(del)
    self.scroll = self.scroll + del * ROW * 2
    return true
end

function S:onMouseDown(x, y)
    if y < 24 then
        if x >= self.width - 24 then S.close(); return true end
        return ISPanel.onMouseDown(self, x, y)
    end
    local top, vh = self:viewTop(), self:viewH()
    if y < top or y >= top + vh then return true end
    local i = math.floor((y - top + self.scroll) / ROW) + 1
    local r = self:rows()[i]
    if not r or r.k == "title" then return true end
    local dir = 1
    if r.k ~= "tick" and x < self.width / 2 + 40 then dir = -1 end

    if r.k ~= "tick" then
        local v = valueOf(r)
        local vt = r.k == "combo" and (r.items[v] and txt(r.items[v]) or "") or string.format("%.2f", v)
        local vw = T.measure(UIFont.Small, vt)
        local leftArrow = self.width - PAD - 22 - vw - 10
        dir = (x < leftArrow + 14 and x > leftArrow - 10) and -1 or 1
    end
    pcall(self.change, self, r, dir)
    return true
end
function S:onRightMouseDown(x, y)

    local top = self:viewTop()
    local i = math.floor((y - top + self.scroll) / ROW) + 1
    local r = self:rows()[i]
    if r and (r.k == "combo" or r.k == "slider") then pcall(self.change, self, r, -1) end
    return true
end

function S:update()
    ISPanel.update(self)
    if not (TGI.Window and TGI.Window.instance) then S.close() return end
    self:bringToTop()
end

function S.open(win)
    if S.instance then S.close(); return end
    local o = S:new(win)
    o:initialise()
    o:addToUIManager()
    o:setAlwaysOnTop(true)
    S.instance = o
end
function S.close()
    if S.instance then
        pcall(function() S.instance:removeFromUIManager() end)
        S.instance = nil
    end
end

return S
