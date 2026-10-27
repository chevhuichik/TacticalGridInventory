require "TGI/TGI_Theme"

TGI = TGI or {}
local LB = {}
TGI.Labels = LB

LB.COLORS = {
    { 0.85, 0.30, 0.25 }, { 0.90, 0.60, 0.20 }, { 0.90, 0.82, 0.30 },
    { 0.40, 0.78, 0.35 }, { 0.30, 0.60, 0.90 }, { 0.65, 0.45, 0.85 }, { 0.75, 0.75, 0.72 },
}

local function holder(c)
    if not c then return nil end
    local bag = c.getContainingItem and c:getContainingItem() or nil
    if bag then return bag, true end
    local obj = c.getParent and c:getParent() or nil
    if obj and obj.getModData and not instanceof(obj, "IsoGameCharacter") then return obj, false end
    return nil
end

function LB.get(c)
    local h = holder(c)
    if not h then return nil end
    local ok, md = pcall(function() return h:getModData() end)
    local l = ok and md and md.TGILabel
    if type(l) ~= "table" or (not l.t or l.t == "") and not l.c then return nil end
    return l
end

function LB.set(c, text, color)
    local h, isItem = holder(c)
    if not h then return end
    local md = h:getModData()
    local l = md.TGILabel or {}
    if text ~= nil then l.t = text end
    if color ~= nil then l.c = (color > 0) and color or nil end
    if (not l.t or l.t == "") and not l.c then md.TGILabel = nil else md.TGILabel = l end

    if not isItem and isClient() and h.transmitModData then pcall(function() h:transmitModData() end) end
end

function LB.clear(c)
    local h, isItem = holder(c)
    if not h then return end
    h:getModData().TGILabel = nil
    if not isItem and isClient() and h.transmitModData then pcall(function() h:transmitModData() end) end
end

function LB.color(l)
    local c = l and l.c and LB.COLORS[l.c]
    return c and c[1] or 0.78, c and c[2] or 0.68, c and c[3] or 0.42
end

function LB.addMenu(menu, panel, ico)
    local c = panel.model and panel.model.container
    if not c or not holder(c) then return end
    local cur = LB.get(c)
    local opt = menu:addOption(getText("IGUI_TGI_Label"))
    if ico then ico(opt, "ic_tag") end
    local sub = ISContextMenu:getNew(menu)
    menu:addSubMenu(opt, sub)
    sub:addOption(getText("IGUI_TGI_LabelText"), panel, function(pp) LB.ask(pp) end)
    for i, col in ipairs(LB.COLORS) do
        local o = sub:addOption(getText("IGUI_TGI_LabelColor" .. i), panel, function(pp) LB.set(pp.model.container, nil, i) end)
        local t = TGI.Draw and TGI.Draw.tex("ic_tag")
        if o and t then o.iconTexture = t; o.color = { r = col[1], g = col[2], b = col[3] } end
    end
    if cur then sub:addOption(getText("IGUI_TGI_LabelClear"), panel, function(pp) LB.clear(pp.model.container) end) end
end

function LB.ask(panel)
    local c = panel.model.container
    local cur = LB.get(c)
    local w, h = 300, 120
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local box = ISTextBox:new(x, y, w, h, getText("IGUI_TGI_LabelAsk"), cur and cur.t or "", nil,
        function(_, button)
            if button.internal ~= "OK" then return end
            local t = button.parent.entry:getText() or ""
            t = string.sub(t, 1, 24)
            LB.set(c, t, (cur and cur.c) or (t ~= "" and 2 or nil))
        end, panel.pn)
    box:initialise()
    box:addToUIManager()
end

local function worldOn()
    if rawget(_G, "ViewpointLoot") then return false end
    return not TGI.Options or TGI.Options.get("worldLabels") ~= false
end

local list, nextScan = {}, 0
local function scan(p)
    list = {}
    local sq0 = p:getCurrentSquare()
    if not sq0 then return end
    local cell, z = getCell(), sq0:getZ()
    for dx = -1, 1 do for dy = -1, 1 do
        local sq = cell:getGridSquare(sq0:getX() + dx, sq0:getY() + dy, z)

        if sq and sq ~= sq0 and not sq0:canReachTo(sq) then sq = nil end
        if sq then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                local l = o and o:getContainer() and o:getModData().TGILabel
                if type(l) == "table" and (l.t and l.t ~= "" or l.c) then
                    list[#list + 1] = { sq:getX(), sq:getY(), z, l }
                    break
                end
            end
        end
    end end
end

local El = ISUIElement:derive("TGILabelsWorld")

if TGI.Theme and TGI.Theme.applyFont then TGI.Theme.applyFont(El) end
function El:new()
    local o = ISUIElement:new(0, 0, 1, 1)
    setmetatable(o, self); self.__index = self
    return o
end
function El:instantiate()
    ISUIElement.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end
function El:render()
    if not worldOn() then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local now = getTimestampMs()
    if now >= nextScan then nextScan = now + 250; pcall(scan, p) end
    if #list == 0 then return end
    local zoom = getCore():getZoom(0)
    local ox, oy = IsoCamera.getOffX(), IsoCamera.getOffY()
    local tm = getTextManager()
    local fh = tm:getFontHeight(UIFont.Small)
    for _, m in ipairs(list) do
        local l = m[4]
        local sx = (IsoUtils.XToScreen(m[1] + 0.5, m[2] + 0.5, m[3], 0) - ox) / zoom
        local sy = (IsoUtils.YToScreen(m[1] + 0.5, m[2] + 0.5, m[3], 0) - oy) / zoom - 70 / zoom
        local text = (l.t and l.t ~= "") and l.t or ""
        local tw = TGI.Theme.measure(UIFont.Small, text)
        local w = tw + 16
        local r, g, b = LB.color(l)
        self:drawRect(sx - w / 2, sy, w, fh + 4, 0.75, 0.03, 0.03, 0.03)
        self:drawRect(sx - w / 2, sy, 4, fh + 4, 1, r, g, b)
        self:drawRectBorder(sx - w / 2, sy, w, fh + 4, 0.8, r * 0.7, g * 0.7, b * 0.7)
        if text ~= "" then self:drawText(text, sx - w / 2 + 10, sy + 2, 1, 1, 1, 0.95, UIFont.Small) end
    end
end

Events.OnGameStart.Add(function()
    if LB.el then return end
    local e = El:new()
    e:initialise()
    e:addToUIManager()
    e:backMost()
    LB.el = e
end)

return LB
