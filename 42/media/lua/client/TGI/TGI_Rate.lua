require "TGI/TGI_Theme"

TGI = TGI or {}
local Rt = {}
TGI.Rate = Rt
Rt.FILE = "TGI_rate.txt"
Rt.URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3810674933"
Rt.NEED_MIN, Rt.NEED_SESSIONS, Rt.LATER_MIN = 300, 3, 240
local T = setmetatable({}, { __index = function(_, k) return TGI.Theme[k] end })

local data = { minutes = 0, sessions = 0, state = "", next = 0 }

local function load()
    local r
    pcall(function() r = getFileReader(Rt.FILE, false) end)
    if not r then return end
    while true do
        local line = r:readLine()
        if line == nil then break end
        local k, v = string.match(line, "^(%w+)=(.*)$")
        if k then data[k] = tonumber(v) or v end
    end
    r:close()
end

local function save()
    pcall(function()
        local w = getFileWriter(Rt.FILE, true, false)
        for _, k in ipairs({ "minutes", "sessions", "state", "next" }) do w:write(k .. "=" .. tostring(data[k] or "") .. "\n") end
        w:close()
    end)
end

function Rt.eligible()
    if data.state == "rated" or data.state == "never" then return false end
    if Rt.shownThisSession then return false end
    if TGI.Report and TGI.Report.hadError then return false end
    local need = math.max(Rt.NEED_MIN, tonumber(data.next) or 0)
    return (tonumber(data.minutes) or 0) >= need and (tonumber(data.sessions) or 0) >= Rt.NEED_SESSIONS
end

local N = ISPanel:derive("TGIRateNotice")

if TGI.Theme and TGI.Theme.applyFont then TGI.Theme.applyFont(N) end
local NW = 480

function N:new(test)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local fm = getTextManager():getFontHeight(UIFont.Medium)
    local h = 10 + fm + 8 + fh * 3 + 12 + (fh + 8) + 10
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local o = ISPanel:new(sw - NW - 20, sh - h - 140, NW, h)
    setmetatable(o, self)
    self.__index = self
    o.test = test
    o.moveWithMouse = true
    o.background = false
    return o
end

local function finish(s, state, nextMin)
    if not s.test then
        if state then data.state = state end
        if nextMin then data.next = nextMin end
        save()
    end
    s:close()
end

N.BTNS = {
    { key = "IGUI_TGI_RateOpen", fn = function(s)
        if isSteamOverlayEnabled and isSteamOverlayEnabled() and activateSteamOverlayToWebPage then activateSteamOverlayToWebPage(Rt.URL)
        elseif openUrl then openUrl(Rt.URL) end
        finish(s, "rated")
    end },
    { key = "IGUI_TGI_RateLater", fn = function(s) finish(s, nil, (tonumber(data.minutes) or 0) + Rt.LATER_MIN) end },
    { key = "IGUI_TGI_RepNever", fn = function(s) finish(s, "never") end },
}

function N:btnRects()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local bh, n = fh + 8, #N.BTNS
    local bw = math.floor((NW - 24 - (n - 1) * 6) / n)
    local out = {}
    for i, b in ipairs(N.BTNS) do out[i] = { x = 12 + (i - 1) * (bw + 6), y = self.height - bh - 10, w = bw, h = bh, b = b } end
    return out
end

local wrapCache = {}
local function wrap(text, w)
    local ck = text .. "|" .. w .. "|" .. tostring(TGI.Options and TGI.Options.get("fontFace"))
    local hit = wrapCache[ck]
    if hit then return hit end
    local tm, lines, line = getTextManager(), {}, ""
    for word in string.gmatch(text, "%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if TGI.Theme.measure(UIFont.Small, try) <= w then line = try
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    wrapCache[ck] = lines
    return lines
end

function N:prerender()
    local w, h = self.width, self.height
    local fm = getTextManager():getFontHeight(UIFont.Medium)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:drawRect(0, 0, w, h, 0.96, T.bg.r, T.bg.g, T.bg.b)
    self:drawRect(0, 0, w, fm + 12, 0.9, T.cell.r, T.cell.g, T.cell.b)
    self:drawRect(0, fm + 12, w, 1, 0.8, T.accent.r, T.accent.g, T.accent.b)
    self:drawRectBorder(0, 0, w, h, 1, T.border.r, T.border.g, T.border.b)
    self:drawRect(0, 0, 3, h, 1, T.accent.r, T.accent.g, T.accent.b)
    self:drawText(getText("IGUI_TGI_RateTitle"), 12, 6, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Medium)
    local y = fm + 20
    for i, l in ipairs(wrap(getText("IGUI_TGI_RateText"), w - 24)) do
        if i > 3 then break end
        self:drawText(l, 12, y + (i - 1) * fh, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
    local mx, my = self:getMouseX(), self:getMouseY()
    for i, r in ipairs(self:btnRects()) do
        local hv = self:isMouseOver() and mx >= r.x and my >= r.y and mx < r.x + r.w and my < r.y + r.h
        local main = i == 1
        self:drawRect(r.x, r.y, r.w, r.h, 0.95, main and 0.2 or T.cell.r, main and 0.2 or T.cell.g, main and 0.19 or T.cell.b)
        if hv then self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 1) end
        local bc = (hv or main) and T.accent or T.border
        self:drawRectBorder(r.x, r.y, r.w, r.h, 1, bc.r, bc.g, bc.b)
        local c = (hv or main) and T.accent or T.text
        self:drawTextCentre(TGI.Draw._short(getText(r.b.key), r.w - 8, UIFont.Small), r.x + r.w / 2, r.y + 4, c.r, c.g, c.b, 1, UIFont.Small)
    end
end

function N:onMouseDown(x, y)
    for _, r in ipairs(self:btnRects()) do
        if x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h then self.press = r.b; return true end
    end
    return ISPanel.onMouseDown(self, x, y)
end

function N:onMouseUp(x, y)
    local p = self.press
    self.press = nil
    if p then
        for _, r in ipairs(self:btnRects()) do
            if r.b == p and x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h then p.fn(self); return true end
        end
        return true
    end
    return ISPanel.onMouseUp(self, x, y)
end

function N:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if Rt.panel == self then Rt.panel = nil end
end

function Rt.show(test)
    if Rt.panel then Rt.panel:close() end
    Rt.shownThisSession = true
    local n = N:new(test)
    n:initialise()
    n:addToUIManager()
    n:setAlwaysOnTop(true)
    Rt.panel = n
end

function Rt.onInventoryClosed()
    if Rt.eligible() then Rt.show(false) end
end

local lastMin = 0
Events.OnGameStart.Add(function()
    load()
    data.sessions = (tonumber(data.sessions) or 0) + 1
    save()
    lastMin = getTimestampMs()
end)
Events.EveryOneMinute.Add(function()

    local now = getTimestampMs()
    if now - lastMin < 60000 then return end
    lastMin = now
    if isGamePaused and isGamePaused() then return end
    data.minutes = (tonumber(data.minutes) or 0) + 1
    if data.minutes % 5 == 0 then save() end
end)

return Rt
