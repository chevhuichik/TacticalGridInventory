require "ISUI/ISPanel"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
TGI = TGI or {}
local T, D = TGI.Theme, TGI.Draw
local AP = ISPanel:derive("TGIAppliancePanel")
TGI.Theme.applyAlpha(AP)
TGI.Appliance = AP

local W, PAD, HEAD = 420, 16, 40
local SEC_H = 92
local FOOT = 52

local OVEN_TEMP = { 0, 50, 100, 150, 200, 250, 300 }
local OVEN_TIME = { 0, 1, 2, 3, 5, 10, 15, 20, 30, 40, 60, 90, 120 }
local MW_POWER = { 50, 70, 90, 110, 130 }
local MW_TIME = { 0, 1, 2, 3, 5, 7, 10, 15, 20, 30, 45, 60 }

local FS = UIFont.Small
local function fh(f) return getTextManager():getFontHeight(f) end
local function tw(f, s) return TGI.Theme.measure(f, s) end
local GREEN = { r = 0.45, g = 0.9, b = 0.45 }

function AP:new(pn, oven)
    local micro = oven.isMicrowave and oven:isMicrowave() or false
    local h = HEAD + 14 + SEC_H * 2 + FOOT
    local o = ISPanel:new(getCore():getScreenWidth() / 2 - W / 2, getCore():getScreenHeight() / 2 - h / 2, W, h)
    setmetatable(o, self)
    self.__index = self
    o.pn, o.oven, o.micro = pn, oven, micro
    o.temps = micro and MW_POWER or OVEN_TEMP
    o.times = micro and MW_TIME or OVEN_TIME
    o.moveWithMouse = true
    o.background = false
    return o
end

function AP.open(pn, oven)
    if not oven then return end
    if AP.inst then AP.inst:close() end
    local p = AP:new(pn, oven)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    AP.inst = p
end

function AP:close()
    if self.tgiCap then pcall(function() self:setCapture(false) end); self.tgiCap = nil end
    self:setVisible(false)
    self:removeFromUIManager()
    if AP.inst == self then AP.inst = nil end
end

function AP:powered()
    local c = self.oven:getContainer()
    return c ~= nil and c:isPowered()
end

function AP:degrees(v)
    if getCore():isCelsius() then return string.format("%d C", v) end
    return string.format("%d F", math.floor(v * 9 / 5 + 32 + 0.5))
end
function AP:tempText(v)
    if self.micro then return string.format("%d%%", v) end
    if v <= 0 then return getText("IGUI_TGI_Off") end
    return self:degrees(v)
end
function AP:timeText(m)
    if m <= 0 then return getText("IGUI_TGI_NoTimer") end
    if m >= 60 and m % 60 == 0 then return (m / 60) .. " " .. getText("IGUI_TGI_HourShort") end
    if m > 60 then return math.floor(m / 60) .. " " .. getText("IGUI_TGI_HourShort") .. " " .. (m % 60) .. " " .. getText("IGUI_TGI_MinShort") end
    return m .. " " .. getText("IGUI_TGI_MinShort")
end
function AP:minutesLeft()
    local o = self.oven
    local t = o:getTimer() or 0
    local run = o.isRunningFor and o:isRunningFor() or 0
    if run > 0 then return math.max(0, math.ceil((t - run) / 60)) end
    return math.floor(t / 60)
end

local function nearest(list, v)
    local bi, bd = 1, math.huge
    for i, x in ipairs(list) do
        local d = math.abs(x - v)
        if d < bd then bi, bd = i, d end
    end
    return bi
end

function AP:section(i)
    local top = HEAD + 14 + (i - 1) * SEC_H
    return {
        top = top,
        track = { x = PAD + 6, y = top + 42, w = W - PAD * 2 - 12, h = 8 },
    }
end
function AP:stepX(tr, list, i)
    if #list <= 1 then return tr.x end
    return tr.x + (i - 1) * tr.w / (#list - 1)
end
function AP:buttons()
    local by = self.height - FOOT + 12
    return { x = PAD, y = by, w = W - PAD * 2 - 118, h = 28 },
        { x = W - PAD - 110, y = by, w = 110, h = 28 },
        { x = W - 30, y = 9, w = 22, h = 22 }
end
local function inR(r, x, y) return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h end

function AP:apply(temp, minutes)
    local o = self.oven
    if temp then o:setMaxTemperature(temp) end
    if minutes then o:setTimer(minutes * 60) end
    if o.sync then o:sync() end
    if o.syncSpriteGridObjects then o:syncSpriteGridObjects(false, true) end
end

function AP:toggle()
    local o = self.oven
    local p = getSpecificPlayer(self.pn)
    if not p or not self:powered() then return end
    sendClientCommand(p, "stove", "setOvenParamsAndToggle",
        { x = o:getX(), y = o:getY(), z = o:getZ(), timer = o:getTimer(), maxTemperature = o:getMaxTemperature() })
    getSoundManager():playUISound("UIActivateMainMenuItem")
end

function AP:pickStep(sec, list, mx)
    local tr = self:section(sec).track
    local f = math.max(0, math.min(1, (mx - tr.x) / tr.w))
    return math.floor(f * (#list - 1) + 0.5) + 1
end
function AP:dragTo(mx)
    local d = self.drag
    if not d then return end
    local list = d == 1 and self.temps or self.times
    local i = self:pickStep(d, list, mx)
    if i ~= self.dragIdx then
        self.dragIdx = i
        if d == 1 then self:apply(list[i], nil) else self:apply(nil, list[i]) end
        getSoundManager():playUISound("UISelectListItem")
    end
end

function AP:onMouseDown(x, y)
    local onR, closeR, xR = self:buttons()
    if inR(onR, x, y) then self:toggle(); return true end

    if inR(closeR, x, y) or inR(xR, x, y) then self.closeDown = true; return true end
    for i = 1, 2 do
        local tr = self:section(i).track
        if x >= tr.x - 10 and x <= tr.x + tr.w + 10 and y >= tr.y - 14 and y <= tr.y + tr.h + 22 then
            self.drag, self.dragIdx = i, nil
            self:dragTo(x)
            return true
        end
    end
    return ISPanel.onMouseDown(self, x, y)
end
function AP:onMouseMove(dx, dy)
    if self.drag then self:dragTo(self:getMouseX()); return end
    ISPanel.onMouseMove(self, dx, dy)
end
function AP:onMouseMoveOutside(dx, dy)
    if self.drag then self:dragTo(self:getMouseX()); return end
    ISPanel.onMouseMoveOutside(self, dx, dy)
end
function AP:onMouseUp(x, y)
    self.drag = nil
    if self.closeDown then
        self.closeDown = nil
        local _, closeR, xR = self:buttons()
        if inR(closeR, x, y) or inR(xR, x, y) then self:close(); return true end
    end
    return ISPanel.onMouseUp(self, x, y)
end
function AP:onMouseUpOutside(x, y) self.drag = nil; self.closeDown = nil; return ISPanel.onMouseUpOutside(self, x, y) end

function AP:update()
    ISPanel.update(self)

    if rawget(_G, "ViewpointLoot") then
        local want = not (TGI.Window and TGI.Window.instance)
        if self.tgiCap ~= want then
            self.tgiCap = want
            pcall(function() self:setCapture(want) end)
        end
    end
    local p = getSpecificPlayer(self.pn)
    local o = self.oven
    if not p or p:isDead() or not o:getSquare() or p:DistTo(o:getX(), o:getY()) > 3 then self:close() end
end

function AP:button(r, text, primary, enabled, hover, icon, icol)
    local a = enabled and 1 or 0.35
    if primary then
        self:drawRect(r.x, r.y, r.w, r.h, 0.9 * a, T.accent.r * 0.45, T.accent.g * 0.45, T.accent.b * 0.3)
        self:drawRect(r.x, r.y, r.w, 1, 0.9 * a, T.accent.r, T.accent.g, T.accent.b)
    else
        self:drawRect(r.x, r.y, r.w, r.h, 0.85, 0.07, 0.075, 0.075)
    end
    self:drawRectBorder(r.x, r.y, r.w, r.h, 0.8 * a, T.accent.r * 0.8, T.accent.g * 0.8, T.accent.b * 0.8)
    if hover and enabled then self:drawRect(r.x, r.y, r.w, r.h, 0.10, 1, 1, 1) end
    local c = primary and T.accent or T.text
    if icon then
        local ic = D.tex(icon)
        local tx = tw(FS, text)
        local x0 = r.x + (r.w - tx - 22) / 2
        if ic then self:drawTextureScaled(ic, x0, r.y + (r.h - 16) / 2, 16, 16, a, icol and icol.r or c.r, icol and icol.g or c.g, icol and icol.b or c.b) end
        self:drawText(text, x0 + 22, r.y + (r.h - fh(FS)) / 2, c.r, c.g, c.b, a, FS)
        return
    end
    self:drawTextCentre(text, r.x + r.w / 2, r.y + (r.h - fh(FS)) / 2, c.r, c.g, c.b, a, FS)
end

function AP:slider(i, caption, icon, list, cur, textOf, heat, marker)
    local s = self:section(i)
    local tr = s.track
    local top = s.top
    local ic = D.tex(icon)
    if ic then self:drawTextureScaled(ic, PAD, top + 2, 16, 16, 0.9, T.dim.r, T.dim.g, T.dim.b) end
    self:drawText(caption, PAD + 22, top + 2, T.dim.r, T.dim.g, T.dim.b, 1, FS)
    self:drawTextRight(textOf(list[cur]), W - PAD, top - 2, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Medium)

    local hx = self:stepX(tr, list, cur)
    self:drawRect(tr.x - 1, tr.y - 1, tr.w + 2, tr.h + 2, 1, 0.01, 0.01, 0.01)
    self:drawRect(tr.x, tr.y, tr.w, tr.h, 1, 0.09, 0.095, 0.095)
    local tex = D.tex(heat and "track_heat" or "track_plain")
    local fillW = hx - tr.x
    if tex and fillW > 0 then
        if heat then

            self:setStencilRect(tr.x, tr.y, fillW, tr.h)
            self:drawTextureScaled(tex, tr.x, tr.y, tr.w, tr.h, 0.95, 1, 1, 1)
            self:clearStencilRect()
        else
            self:drawTextureScaled(tex, tr.x, tr.y, fillW, tr.h, 0.9, T.accent.r, T.accent.g, T.accent.b)
        end
    end

    for k = 1, #list do
        local x = math.floor(self:stepX(tr, list, k))
        local passed = k <= cur
        self:drawRect(x, tr.y + tr.h + 3, 1, 4, passed and 0.9 or 0.5, T.dim.r, T.dim.g, T.dim.b)
    end

    self:drawText(textOf(list[1]), tr.x - 2, tr.y + tr.h + 8, T.dim.r, T.dim.g, T.dim.b, 0.8, FS)
    self:drawTextRight(textOf(list[#list]), tr.x + tr.w + 2, tr.y + tr.h + 8, T.dim.r, T.dim.g, T.dim.b, 0.8, FS)

    if marker then
        local mx = tr.x + math.max(0, math.min(1, marker.f)) * tr.w
        self:drawRect(mx - 1, tr.y - 5, 2, tr.h + 10, 1, 1, 1, 1)
        if marker.text then
            local t = marker.text
            local x = math.max(tr.x, math.min(tr.x + tr.w - tw(FS, t), mx - tw(FS, t) / 2))
            self:drawText(t, x, tr.y - 5 - fh(FS), 1, 1, 1, 0.9, FS)
        end
    end

    local hover = self:isMouseOver() and math.abs(self:getMouseX() - hx) < 10 and math.abs(self:getMouseY() - tr.y) < 14
    self:drawRect(hx - 6, tr.y - 7, 12, tr.h + 14, 1, 0.05, 0.05, 0.05)
    self:drawRect(hx - 5, tr.y - 6, 10, tr.h + 12, 1, T.accent.r, T.accent.g, T.accent.b)
    self:drawRect(hx - 1, tr.y - 2, 2, tr.h + 4, 0.8, 0.1, 0.1, 0.1)
    if hover or self.drag == i then self:drawRectBorder(hx - 7, tr.y - 8, 14, tr.h + 16, 0.9, 1, 1, 1) end
end

function AP:prerender()
    local w, h = self.width, self.height
    self:drawRect(0, 0, w, h, 0.96, T.bg.r, T.bg.g, T.bg.b)
    if T.metalFill then T.metalFill(self, 0, 0, w, h, 0.55) end
    self:drawRect(0, 0, w, HEAD, 0.75, 0.04, 0.04, 0.04)
    local grad = T.grad and T.grad()
    local on = self.oven:Activated()
    if grad then
        local c = on and { r = 1, g = 0.45, b = 0.15 } or T.accent
        self:drawTextureScaled(grad, 0, 0, w, HEAD, on and 0.35 or 0.2, c.r, c.g, c.b)
    end
    self:drawRect(0, HEAD, w, 1, 0.9, T.accent.r, T.accent.g, T.accent.b)
    self:drawRect(PAD, HEAD + 14 + SEC_H - 8, w - PAD * 2, 1, 0.5, T.border.r, T.border.g, T.border.b)
    self:drawRect(0, h - FOOT, w, 1, 0.6, T.border.r, T.border.g, T.border.b)
    self:drawRect(0, h - FOOT, w, FOOT, 0.35, 0, 0, 0)
    self:drawRectBorder(0, 0, w, h, 1, T.border.r, T.border.g, T.border.b)
end

function AP:render()
    local o = self.oven
    local on = o:Activated()
    local powered = self:powered()

    local ic = D.tex(self.micro and "ic_microwave" or "ic_stove")
    if ic then self:drawTextureScaled(ic, PAD, 10, 20, 20, 1, T.accent.r, T.accent.g, T.accent.b) end
    self:drawText(getText(self.micro and "IGUI_TGI_Microwave" or "IGUI_TGI_Stove"), PAD + 28, (HEAD - fh(UIFont.Medium)) / 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Medium)
    local st, sc
    if not powered then st, sc = getText("IGUI_TGI_NoPower"), { r = 0.9, g = 0.35, b = 0.3 }
    elseif on then st, sc = getText("IGUI_TGI_StateOn"), GREEN
    else st, sc = getText("IGUI_TGI_StateOff"), T.dim end
    local pw = tw(FS, st) + 24
    local px = W - 40 - pw
    self:drawRect(px, 11, pw, 18, 0.8, 0.03, 0.03, 0.03)
    self:drawRectBorder(px, 11, pw, 18, 0.9, sc.r * 0.8, sc.g * 0.8, sc.b * 0.8)
    self:drawRect(px + 7, 17, 6, 6, 1, sc.r, sc.g, sc.b)
    self:drawText(st, px + 17, 11 + (18 - fh(FS)) / 2, sc.r, sc.g, sc.b, 1, FS)
    local _, _, xR = self:buttons()
    local xh = self:isMouseOver() and inR(xR, self:getMouseX(), self:getMouseY())
    self:drawTextCentre("X", xR.x + xR.w / 2, xR.y + (xR.h - fh(FS)) / 2, xh and 1 or T.dim.r, xh and 1 or T.dim.g, xh and 1 or T.dim.b, 1, FS)

    local mt = o:getMaxTemperature() or 0
    local ti = nearest(self.temps, mt)
    local marker = nil
    local cur = o.getCurrentTemperature and o:getCurrentTemperature() or nil
    if on and cur and not self.micro and cur > 1 then
        marker = { f = cur / self.temps[#self.temps], text = getText("IGUI_TGI_Now", self:degrees(math.floor(cur))) }
    end
    self:slider(1, getText(self.micro and "IGUI_TGI_Power" or "IGUI_TGI_Temp"), self.micro and "ic_speed" or "ic_insul",
        self.temps, ti, function(v) return self:tempText(v) end, not self.micro, marker)

    local tm = math.floor((o:getTimer() or 0) / 60)
    local ci = nearest(self.times, tm)
    local tmark = nil
    local left = self:minutesLeft()
    if on and tm > 0 and left > 0 then
        tmark = { f = (nearest(self.times, left) - 1) / (#self.times - 1), text = getText("IGUI_TGI_TimeLeft", self:timeText(left)) }
    end
    self:slider(2, getText("IGUI_TGI_Timer"), "ic_clock", self.times, ci, function(v) return self:timeText(v) end, false, tmark)

    local onR, closeR = self:buttons()
    local mx, my = self:getMouseX(), self:getMouseY()
    local hov = self:isMouseOver()
    self:button(onR, getText(on and "IGUI_TGI_TurnOff" or "IGUI_TGI_TurnOn"), true, powered, hov and inR(onR, mx, my),
        "ic_power", on and GREEN or nil)
    self:button(closeR, getText("IGUI_TGI_Close"), false, true, hov and inR(closeR, mx, my))
end

local function hook()
    if not ISOvenUITimedAction or ISOvenUITimedAction._tgi then return end
    ISOvenUITimedAction._tgi = true
    local base = ISOvenUITimedAction.perform
    ISOvenUITimedAction.perform = function(self)
        local pn = self.character:getPlayerNum()
        if TGI.usesGrid and TGI.usesGrid(pn) then
            ISBaseTimedAction.perform(self)
            AP.open(pn, self.stove or self.mcwave)
            return
        end
        base(self)
    end
end
Events.OnGameStart.Add(hook)

return AP
