require "ISUI/ISPanel"
require "TGI/TGI_Theme"
TGI = TGI or {}
local T = TGI.Theme
local L = ISPanel:derive("TGIStackList")
TGI.StackList = L
T.applyAlpha(L)

local ROW = 26
local MAXROWS = 12

local carNames = nil
local function vehicleName(veh)
    local okS, sn = pcall(function() return veh:getScriptName() end)
    if not okS or type(sn) ~= "string" or sn == "" then return nil end
    local short = sn:match("%.(.+)$") or sn
    local okT, vn = pcall(function() return getTextOrNull and getTextOrNull("IGUI_VehicleName" .. short) or nil end)
    return okT and vn or nil
end
local function buildCarNames()
    carNames = {}
    pcall(function()
        local c = getCell()
        local list = c and c:getVehicles()
        if not list then return end

        local it = list:iterator()
        local n = 0
        while it:hasNext() and n < 500 do
            n = n + 1
            local veh = it:next()
            local okK, id = pcall(function() return veh:getKeyId() end)
            if okK and id and carNames[id] == nil then carNames[id] = vehicleName(veh) or false end
        end
    end)
end

local function rowText(it)
    local name = it:getDisplayName() or "?"

    if instanceof(it, "Key") then
        if not carNames then buildCarNames() end
        local okK, id = pcall(function() return it:getKeyId() end)
        local vn = okK and id and carNames[id]
        if vn then name = name .. " - " .. vn end
    end
    return name
end

function L.open(panel, e, ax, ay)
    L.close()
    carNames = nil
    local items = {}
    for _, it in ipairs(e.items or { e.item }) do items[#items + 1] = it end
    if #items < 2 then return end
    local w = 260
    local h = math.min(#items, MAXROWS) * ROW + 26
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local x = math.max(0, math.min(sw - w, ax))
    local y = math.max(0, math.min(sh - h, ay))
    local o = ISPanel.new(L, x, y, w, h)
    o.background = false
    o.panel, o.entry, o.items, o.pn = panel, e, items, panel.pn
    o.scroll = 0
    o.texts = {}
    for i, it in ipairs(items) do o.texts[i] = rowText(it) end
    o:initialise()
    o:addToUIManager()
    o:setAlwaysOnTop(true)
    o:bringToTop()
    L.inst = o
    return o
end

function L.close()
    if L.inst then pcall(function() L.inst:removeFromUIManager() end) end
    L.inst = nil
end

function L:rowAt(y)
    if y < 22 then return nil end
    local i = math.floor((y - 22) / ROW) + 1 + self.scroll
    if i >= 1 and i <= #self.items then return i end
end

function L:stillValid()
    local c = self.panel and self.panel.model and self.panel.model.container
    for _, it in ipairs(self.items) do
        if it:getContainer() ~= c then return false end
    end
    return self.panel:isReallyVisible()
end

function L:prerender()
    if not self:stillValid() then L.close(); return end
    self:drawRect(0, 0, self.width, self.height, 0.95, T.bg.r, T.bg.g, T.bg.b)
    T.metalFill(self, 0, 0, self.width, self.height, 0.5)
    self:drawRectBorder(0, 0, self.width, self.height, 1, T.border.r, T.border.g, T.border.b)
    self:drawText(getText("IGUI_TGI_StackOf", tostring(#self.items)), 6, 3, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
    local mx, my = self:getMouseX(), self:getMouseY()
    local hover = self:isMouseOver() and self:rowAt(my)
    local last = math.min(#self.items, self.scroll + MAXROWS)
    for i = self.scroll + 1, last do
        local y = 22 + (i - self.scroll - 1) * ROW
        if i == hover then self:drawRect(1, y, self.width - 2, ROW, 0.12, 1, 1, 1) end
        local it = self.items[i]
        local tex = it:getTex()
        if tex then self:drawTextureScaledAspect(tex, 4, y + 2, ROW - 4, ROW - 4, 1, 1, 1, 1) end
        self:drawText(self.texts[i], ROW + 6, y + (ROW - 16) / 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
end

function L:onMouseWheel(d)
    self.scroll = math.max(0, math.min(#self.items - MAXROWS, self.scroll + d))
    return true
end

function L:onMouseDown(x, y)
    local i = self:rowAt(y)
    self.press = i and { i = i, x = x, y = y } or nil
    if i then
        local now = getTimestampMs()
        if self.lastClick and self.lastClick.i == i and now - self.lastClick.t < 400 then
            self.press = nil
            self:take(self.items[i])
            return true
        end
        self.lastClick = { i = i, t = now }
    end
    return true
end

function L:onMouseMove(dx, dy)
    local pr = self.press
    if not pr then return end
    if math.abs(self:getMouseX() - pr.x) + math.abs(self:getMouseY() - pr.y) < 5 then return end
    self.press = nil
    local it = self.items[pr.i]
    local Drag = TGI.Drag
    if not (Drag and it) then return end

    Drag.start(self.pn, self.entry, { model = self.panel.model, panel = self.panel }, 0, 0, false)
    if Drag.active then Drag.active.multi = { it } end
    L.close()
end
function L:onMouseMoveOutside(dx, dy) self:onMouseMove(dx, dy) end
function L:onMouseUp() self.press = nil; return true end

function L:onRightMouseUp(x, y)
    local i = self:rowAt(y)
    if not i then return true end
    local p = getSpecificPlayer(self.pn)
    local inPlayer = p and self.panel.model.container:isInCharacterInventory(p)
    TGI.Actions.contextMenu(self.pn, { self.items[i] }, self:getAbsoluteX() + x, self:getAbsoluteY() + y, inPlayer)
    return true
end

function L:take(it)
    local p = getSpecificPlayer(self.pn)
    if not p then return end
    if it:getContainer() ~= p:getInventory() then TGI.Actions.transfer(self.pn, { it }, p:getInventory()) end
    L.close()
end

Events.OnMouseDown.Add(function()
    local o = L.inst
    if o and not o:isMouseOver() then L.close() end
end)
Events.OnKeyPressed.Add(function(k)
    if L.inst and k == Keyboard.KEY_ESCAPE then L.close() end
end)

return L
