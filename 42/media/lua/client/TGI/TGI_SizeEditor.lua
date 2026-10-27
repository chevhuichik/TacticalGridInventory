TGI = TGI or {}
local S = TGI.Size
local T = setmetatable({}, { __index = function(_, k) return TGI.Theme[k] end })
local Ed = ISPanel:derive("TGISizeEditor")
if TGI.Theme.applyFont then TGI.Theme.applyFont(Ed) end
TGI.SizeEditor = Ed

local W, H = 340, 250
local CELL = 22

local function canEditServer()
    if not isClient() then return false end
    local p = getPlayer()
    if not p then return false end
    local ok, v = pcall(function() return p:getRole():hasCapability(Capability.EditItem) end)
    if ok and v then return true end
    ok, v = pcall(function() return isAdmin() end)
    return ok and v == true
end

function Ed:new(item)
    local o = ISPanel:new(getCore():getScreenWidth() / 2 - W / 2, getCore():getScreenHeight() / 2 - H / 2, W, H)
    setmetatable(o, self)
    self.__index = self
    o.item = item
    o.ft = item:getFullType()
    o.w, o.h = S.of(item)
    o.moveWithMouse = true
    o.backgroundColor = { r = T.bg.r, g = T.bg.g, b = T.bg.b, a = 0.97 }
    o.borderColor = { r = T.accent.r, g = T.accent.g, b = T.accent.b, a = 0.8 }
    return o
end

local function btn(self, x, y, w, h, text, fn)
    local b = ISButton:new(x, y, w, h, text, self, fn)
    b:initialise(); b:instantiate()
    b.borderColor = { r = T.border.r, g = T.border.g, b = T.border.b, a = 1 }
    self:addChild(b)
    return b
end

function Ed:createChildren()
    ISPanel.createChildren(self)
    local y = 150
    btn(self, 12, 40, 26, 22, "-", function(s) s.w = math.max(1, s.w - 1) end)
    btn(self, 100, 40, 26, 22, "+", function(s) s.w = math.min(10, s.w + 1) end)
    btn(self, 12, 70, 26, 22, "-", function(s) s.h = math.max(1, s.h - 1) end)
    btn(self, 100, 70, 26, 22, "+", function(s) s.h = math.min(10, s.h + 1) end)
    btn(self, 12, 100, 114, 22, getText("IGUI_TGI_SizeRotate"), function(s) s.w, s.h = s.h, s.w end)
    local bw = math.floor((W - 36) / 2)
    btn(self, 12, y + 34, bw, 24, getText("IGUI_TGI_SizeSaveMine"), Ed.saveMine)
    self.srvBtn = btn(self, 24 + bw, y + 34, bw, 24, getText("IGUI_TGI_SizeSaveServer"), Ed.saveServer)
    self.srvBtn:setVisible(canEditServer())
    btn(self, 12, y + 64, bw, 24, getText("IGUI_TGI_SizeAuto"), Ed.reset)
    btn(self, 24 + bw, y + 64, bw, 24, getText("IGUI_TGI_SizeClose"), function(s) s:close() end)
end

function Ed:saveMine()
    S.setUser(self.ft, self.w, self.h)
    self:close()
end
function Ed:saveServer()
    sendClientCommand(getPlayer(), "TGI", "sizeSet", { ft = self.ft, w = self.w, h = self.h })
    self:close()
end
function Ed:reset()
    if S.overrides[self.ft] then S.setUser(self.ft, nil, nil) end
    if S.server[self.ft] and canEditServer() then
        sendClientCommand(getPlayer(), "TGI", "sizeSet", { ft = self.ft })
    end
    self.w, self.h = S.auto(self.item)
end

function Ed:prerender()
    ISPanel.prerender(self)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:drawText(TGI.Draw._short(self.item:getDisplayName(), W - 24, UIFont.Medium), 12, 8, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Medium)
    self:drawText(getText("IGUI_TGI_SizeW") .. ": " .. self.w, 44, 40 + (22 - fh) / 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    self:drawText(getText("IGUI_TGI_SizeH") .. ": " .. self.h, 44, 70 + (22 - fh) / 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)

    local ox, oy = 142, 40
    local c = math.min(CELL, math.floor(math.min((W - ox - 12) / self.w, 100 / self.h)))
    for gx = 0, self.w - 1 do for gy = 0, self.h - 1 do
        self:drawRect(ox + gx * c, oy + gy * c, c - 1, c - 1, 0.9, T.cell.r, T.cell.g, T.cell.b)
    end end
    self:drawRectBorder(ox - 1, oy - 1, self.w * c + 1, self.h * c + 1, 1, T.accent.r, T.accent.g, T.accent.b)
    local tex = self.item:getTex()
    if tex then self:drawTextureScaledAspect(tex, ox + 2, oy + 2, self.w * c - 4, self.h * c - 4, 1, 1, 1, 1) end

    local src = S.source(self.ft)
    local aw, ah = S.auto(self.item)
    local line = getText("IGUI_TGI_SizeFrom_" .. src) .. "   " .. getText("IGUI_TGI_SizeAutoIs") .. " " .. aw .. "x" .. ah
    self:drawText(line, 12, 150, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
    self:drawText(self.ft, 12, 150 + fh, T.dim.r, T.dim.g, T.dim.b, 0.7, UIFont.Small)
end

function Ed:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if Ed.inst == self then Ed.inst = nil end
end

function Ed.open(item)
    if not item then return end
    if Ed.inst then Ed.inst:close() end
    local e = Ed:new(item)
    e:initialise()
    e:addToUIManager()
    e:setAlwaysOnTop(true)
    if rawget(_G, "ViewpointLoot") then pcall(function() e:setCapture(true) end) end
    Ed.inst = e
end

Events.OnFillInventoryObjectContextMenu.Add(function(pn, context, items)
    if not (TGI.Options and TGI.Options.get("sizeEditor")) then return end
    local it = items and items[1]
    if type(it) == "table" then it = it.items and it.items[1] end
    if not it or not it.getFullType then return end
    local w, h = S.of(it)
    context:addOption(getText("IGUI_TGI_SizeMenu") .. " (" .. w .. "x" .. h .. ")", it, Ed.open)
end)

local asked = false
Events.OnTick.Add(function()
    if asked or not isClient() then return end
    local p = getPlayer()
    if not p then return end
    asked = true
    sendClientCommand(p, "TGI", "sizesReq", {})
end)
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "TGI" then return end
    if command == "sizes" and type(args) == "table" then
        S.server = {}
        for ft, v in pairs(args.list or {}) do
            if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then S.server[ft] = { tonumber(v[1]), tonumber(v[2]) } end
        end
        S.changed()
    elseif command == "sizeSet" and type(args) == "table" and type(args.ft) == "string" then
        if tonumber(args.w) and tonumber(args.h) then S.server[args.ft] = { tonumber(args.w), tonumber(args.h) }
        else S.server[args.ft] = nil end
        S.changed()
    end
end)
