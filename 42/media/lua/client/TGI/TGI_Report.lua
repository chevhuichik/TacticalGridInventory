require "TGI/TGI_Theme"

TGI = TGI or {}
local R = {}
TGI.Report = R
R.URL = "https://steamcommunity.com/workshop/filedetails/discussion/3810674933/586187435308796978/"
local T = setmetatable({}, { __index = function(_, k) return TGI.Theme[k] end })

local seen, lastCount, nextCheck = {}, 0, 0

local function ours(err)

    if string.find(err, "TGIFeatures", 1, true) or string.find(err, "TGIStress", 1, true) then return false end
    err = string.gsub(err, "Tactical Grid Inventory %- Debugger", "")
    err = string.gsub(err, "TGIDebug", "")
    return string.find(err, "Tactical Grid Inventory", 1, true) ~= nil or string.find(err, "TGI_", 1, true) ~= nil
end

local function otherMods(err)
    local out, have = {}, {}
    for name in string.gmatch(err, "%(MOD:([^%)]+)%)") do
        if name ~= "Tactical Grid Inventory" and not string.find(name, "Tactical Grid Inventory", 1, true) and not have[name] then
            have[name] = true
            out[#out + 1] = name
        end
    end
    return out
end

function R.reportText(err)
    local lines = {}
    local ver = "?"
    pcall(function() ver = getModInfoByID("TacticalGridInventory"):getModVersion() end)
    local game = "?"
    pcall(function() game = tostring(getCore():getVersion()) end)
    lines[#lines + 1] = "TGI " .. tostring(ver) .. " | game " .. game .. " | " .. (isClient() and "MP" or "SP")
    local mods = {}
    pcall(function()
        local list = getActivatedMods()
        for i = 0, list:size() - 1 do mods[#mods + 1] = tostring(list:get(i)) end
    end)
    lines[#lines + 1] = "Mods (" .. #mods .. "): " .. table.concat(mods, ", ")
    lines[#lines + 1] = "Error:"
    lines[#lines + 1] = string.sub(err or "", 1, 3000)
    return table.concat(lines, "\n")
end

local N = ISPanel:derive("TGIReportNotice")

if TGI.Theme and TGI.Theme.applyFont then TGI.Theme.applyFont(N) end
local NW = 520
local function nh()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local fm = getTextManager():getFontHeight(UIFont.Medium)
    return 10 + fm + 6 + fh + 2 + fh * 2 + 10 + (fh + 8) + 10
end

function N:new(err, others)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local h = nh()
    local o = ISPanel:new(sw - NW - 20, sh - h - 140, NW, h)
    setmetatable(o, self)
    self.__index = self
    o.err, o.others = err, others
    o.moveWithMouse = true
    o.background = false
    return o
end

N.BTNS = {
    { key = "IGUI_TGI_RepCopy", fn = function(s) s:copy() end },
    { key = "IGUI_TGI_RepOpen", fn = function(s) s:open() end },
    { key = "IGUI_TGI_RepNever", fn = function(s) if TGI.Options.set then TGI.Options.set("errorReports", false) end; R.off = true; s:close() end },
    { key = "IGUI_TGI_RepHide", fn = function(s) s:close() end },
}
function N:btnRects()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local bh = fh + 8
    local n = #N.BTNS
    local bw = math.floor((NW - 24 - (n - 1) * 6) / n)
    local out = {}
    for i, b in ipairs(N.BTNS) do out[i] = { x = 12 + (i - 1) * (bw + 6), y = self.height - bh - 10, w = bw, h = bh, b = b } end
    return out
end

function N:copy()
    pcall(function() Clipboard.setClipboard(R.reportText(self.err)) end)
    self.copied = getTimestampMs()
end

function N:open()
    pcall(function() Clipboard.setClipboard(R.reportText(self.err)) end)
    self.copied = getTimestampMs()
    if isSteamOverlayEnabled and isSteamOverlayEnabled() and activateSteamOverlayToWebPage then
        activateSteamOverlayToWebPage(R.URL)
    elseif openUrl then
        openUrl(R.URL)
    end
end

local function wrap2(text, w)
    local tm = getTextManager()
    if TGI.Theme.measure(UIFont.Small, text) <= w then return { text } end
    local line, rest = "", nil
    for word in string.gmatch(text, "%S+") do
        if rest then rest = rest .. " " .. word
        else
            local try = line == "" and word or (line .. " " .. word)
            if TGI.Theme.measure(UIFont.Small, try) <= w then line = try else rest = word end
        end
    end
    return { line, TGI.Draw._short(rest or "", w, UIFont.Small) }
end

function N:prerender()
    local w, h = self.width, self.height

    self:drawRect(0, 0, w, h, 0.96, T.bg.r, T.bg.g, T.bg.b)
    local fm = getTextManager():getFontHeight(UIFont.Medium)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:drawRect(0, 0, w, fm + 12, 0.9, T.cell.r, T.cell.g, T.cell.b)
    self:drawRect(0, fm + 12, w, 1, 0.8, T.accent.r, T.accent.g, T.accent.b)
    self:drawRectBorder(0, 0, w, h, 1, T.border.r, T.border.g, T.border.b)
    self:drawRect(0, 0, 3, h, 1, 0.9, 0.45, 0.25)
    self:drawText(getText("IGUI_TGI_RepTitle"), 12, 6, 1, 0.6, 0.35, 1, UIFont.Medium)
    local line
    if #self.others > 0 then line = getText("IGUI_TGI_RepConflict") .. " " .. table.concat(self.others, ", ")
    else line = getText("IGUI_TGI_RepOurs") end
    local y = fm + 18
    self:drawText(TGI.Draw._short(line, w - 24, UIFont.Small), 12, y, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    local copied = self.copied and getTimestampMs() - self.copied < 4000
    local hint = copied and getText("IGUI_TGI_RepCopied") or getText("IGUI_TGI_RepHint")
    for i, l in ipairs(wrap2(hint, w - 24)) do
        local c = copied and T.accent or T.dim
        self:drawText(l, 12, y + fh + 2 + (i - 1) * fh, c.r, c.g, c.b, 1, UIFont.Small)
    end
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, r in ipairs(self:btnRects()) do
        local hv = self:isMouseOver() and mx >= r.x and my >= r.y and mx < r.x + r.w and my < r.y + r.h
        self:drawRect(r.x, r.y, r.w, r.h, 0.95, T.cell.r, T.cell.g, T.cell.b)
        if hv then self:drawRect(r.x, r.y, r.w, r.h, 0.12, 1, 1, 1) end
        local bc = hv and T.accent or T.border
        self:drawRectBorder(r.x, r.y, r.w, r.h, 1, bc.r, bc.g, bc.b)
        local t = TGI.Draw._short(getText(r.b.key), r.w - 8, UIFont.Small)
        local c = hv and T.accent or T.text
        self:drawTextCentre(t, r.x + r.w / 2, r.y + 4, c.r, c.g, c.b, 1, UIFont.Small)
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
    if R.notice == self then R.notice = nil end
end

function R.show(err, others)
    R.hadError = true
    if R.notice then R.notice:close() end
    local n = N:new(err, others)
    n:initialise()
    n:addToUIManager()
    n:setAlwaysOnTop(true)
    R.notice = n
end

local winErrs = {}
function R.failSafe(err)
    if TGI.fallback or TGI.Options.get("failSafe") == false then return end

    local top = string.match(err, "Lua%(%(MOD:[^)]*%)%)%.[%w_]*%(([%w_]+)%.lua") or string.match(err, "%(([%w_]+)%.lua:%d+%)") or ""
    if top ~= "TGI_Window" and top ~= "TGI_GridPanel" and top ~= "TGI_Draw" and top ~= "TGI_Drag" then return end
    local now = getTimestampMs()
    winErrs[#winErrs + 1] = now
    while winErrs[1] and now - winErrs[1] > 30000 do table.remove(winErrs, 1) end
    if #winErrs < 5 then return end
    TGI.fallback = true
    pcall(function() if TGI.Window and TGI.Window.instance then TGI.Window.instance:close() end end)
    pcall(function() TGI.halo(getSpecificPlayer(0), getText("IGUI_TGI_Fallback"), false) end)
    print("[TGI] fail-safe: vanilla inventory until restart")
end

local function check()
    if not (TGI.Options and getLuaDebuggerErrorCount) then return end
    local reports = not R.off and TGI.Options.get("errorReports") ~= false
    if not reports and (TGI.fallback or TGI.Options.get("failSafe") == false) then return end
    local n = getLuaDebuggerErrorCount()
    if n <= lastCount then lastCount = n; return end
    local list = getLuaDebuggerErrors()
    local size = list and list:size() or 0
    for i = math.max(0, size - (n - lastCount)), size - 1 do
        local err = tostring(list:get(i) or "")
        if ours(err) then R.failSafe(err) end
        if reports and ours(err) then
            local sig = string.sub(err, 1, 160)
            if not seen[sig] then
                seen[sig] = true
                R.show(err, otherMods(err))
            end
        end
    end
    lastCount = n
end

Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < nextCheck then return end
    nextCheck = now + 3000
    pcall(check)
end)

return R
