require "ISUI/ISPanel"
require "ISUI/ISUI3DModel"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
require "TGI/TGI_Drag"
require "TGI/TGI_Actions"
require "TGI/TGI_Tooltip"
require "TGI/TGI_Health"

TGI = TGI or {}
local T, D, Drag, A = TGI.Theme, TGI.Draw, TGI.Drag, TGI.Actions
local E = ISPanel:derive("TGIEquip")
TGI.Theme.applyAlpha(E)
TGI.Equip = E

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

local SLOT = 52
local LABEL = 16
local GAP = 4
local MODEL_W = 200
local VIT_H = 15
local ROW = SLOT + LABEL + GAP
local MINI, BC = 32, 26

E.SLOTS = {

    { id = "head",  label = "IGUI_TGI_Head",   icon = "head",  side = "L", r = 0, part = "Head", dy = -0.02, ax = 0.50, ay = 0.05, locs = { "fullhelmet", "fullhat", "hat", "helmet" } },
    { id = "face",  label = "IGUI_TGI_Face",   icon = "face",  side = "L", r = 1, part = "Head", dy = 0.01, ax = 0.46, ay = 0.09, locs = { "mask", "eyes", "glasses" } },

    { id = "under", label = "IGUI_TGI_Under",  icon = "under", side = "L", r = 3, part = "Torso_Upper", dy = 0.02, ax = 0.44, ay = 0.34, multi = true, locs = { "tanktop", "tshirt", "underwear", "shortsleeveshirt" } },
    { id = "torso", label = "IGUI_TGI_Torso",  icon = "torso", side = "L", r = 2, part = "Torso_Upper", dy = -0.02, ax = 0.40, ay = 0.25, locs = { "jacket", "fullsuit", "fulltop", "sweater", "shirt", "dress", "bathrobe" } },
    { id = "hands", label = "IGUI_TGI_Gloves", icon = "hands", side = "L", r = 4, part = "Hand_R", dy = 0, ax = 0.14, ay = 0.54, locs = { "hands" } },
    { id = "wrist", label = "IGUI_TGI_AccHands", icon = "watch", side = "L", r = 5, part = "ForeArm_R", dy = 0.02, ax = 0.18, ay = 0.50, multi = true, locs = { "wrist", "watch", "bracelet", "ring" } },
    { id = "legs",  label = "IGUI_TGI_Legs",   icon = "legs",  side = "L", r = 6, part = "UpperLeg_R", dy = 0, ax = 0.40, ay = 0.72, locs = { "pants", "legs", "skirt", "shorts" } },
    { id = "pads",  label = "IGUI_TGI_Pads",   icon = "pads", side = "L", r = 7, part = "LowerLeg_R", dy = 0, ax = 0.42, ay = 0.82, multi = true, locs = { "knee", "elbow" } },

    { id = "acc",   label = "IGUI_TGI_AccNeck", icon = "acc",  side = "R", r = 0, part = "Neck", dy = 0, ax = 0.54, ay = 0.14, multi = true, locs = { "necklace", "neck", "scarf", "ears", "eartop", "earring", "nose" } },
    { id = "back",  label = "IGUI_TGI_Back",   icon = "back",  side = "R", r = 1, part = "Torso_Upper", dy = -0.03, ax = 0.70, ay = 0.22, multi = true, locs = { "back", "satchel" } },
    { id = "armor", label = "IGUI_TGI_Armor",  icon = "armor", side = "R", r = 2, part = "Torso_Upper", dy = 0.01, ax = 0.58, ay = 0.30, locs = { "torsoextravest", "vest", "armor" } },
    { id = "rig",   label = "IGUI_TGI_Rig",    icon = "rig",   side = "R", r = 3, part = "Torso_Lower", dy = -0.01, ax = 0.56, ay = 0.40, locs = { "webbing", "rig" } },
    { id = "belt",  label = "IGUI_TGI_Belt",   icon = "belt",  side = "R", r = 4, part = "Torso_Lower", dy = 0.02, ax = 0.56, ay = 0.50, locs = { "belt" } },
    { id = "fanny", label = "IGUI_TGI_Fanny",  icon = "fanny", side = "R", r = 5, part = "Groin", dy = 0, ax = 0.52, ay = 0.54, multi = true, locs = { "fannypack" } },

    { id = "holster", label = "IGUI_TGI_Holster", icon = "belt", side = "R", r = 6, part = "UpperLeg_L", dy = -0.02, ax = 0.62, ay = 0.46, multi = true, locs = { "shoulderholster", "ankleholster", "beltextra", "holster", "ammostrap" } },
    { id = "feet",  label = "IGUI_TGI_Feet",   icon = "feet",  side = "R", r = 7, part = "Foot_L", dy = 0, ax = 0.58, ay = 0.97, multi = true, locs = { "shoes", "socks" } },
    { id = "prim",  label = "IGUI_TGI_Primary",   icon = "primary",   hand = "primary" },
    { id = "sec",   label = "IGUI_TGI_Secondary", icon = "secondary", hand = "secondary" },
}

E.MATCH = { "head", "face", "under", "torso", "hands", "wrist", "pads", "legs", "acc", "armor", "rig",
    "holster", "fanny", "belt", "back", "feet" }
local BYID = {}
for _, s in ipairs(E.SLOTS) do BYID[s.id] = s end

function E.normLoc(loc)
    loc = string.lower(tostring(loc or ""))
    loc = string.gsub(loc, "^.*:", "")
    loc = string.gsub(loc, "[_%s]", "")
    return loc
end

local TEX = {}
local function tex(name)
    if TEX[name] == nil then TEX[name] = getTexture("media/textures/TGI/" .. name .. ".png") or false end
    return TEX[name] or nil
end

function E:new(x, y, pn)
    local w = GAP * 4 + SLOT * 2 + MODEL_W
    local o = ISPanel:new(x, y, w, 9 * ROW + LABEL + 2 * (T.CELL + LABEL + GAP) + 44)
    setmetatable(o, self)
    self.__index = self
    o.pn = pn
    o.background = false
    o.assign, o.others, o.belt, o.multi = {}, {}, {}, {}
    o.dirIndex = 1
    return o
end

local DIRS = { "S", "SW", "W", "NW", "N", "NE", "E", "SE" }

function E:createChildren()
    ISPanel.createChildren(self)
    self:buildModel()
end

function E:outfitSig(p)
    local t = {}
    local wi = p:getWornItems()
    if wi then for i = 0, wi:size() - 1 do local it = wi:get(i):getItem(); if it then t[#t + 1] = it:getID() end end end
    local a, b = p:getPrimaryHandItem(), p:getSecondaryHandItem()
    t[#t + 1] = a and a:getID() or 0
    t[#t + 1] = b and b:getID() or 0
    local ai = p:getAttachedItems()
    if ai then for i = 0, ai:size() - 1 do local it = ai:getItemByIndex(i); if it then t[#t + 1] = it:getID() end end end
    return table.concat(t, ",")
end

function E:checkOutfit()
    self.sigTick = (self.sigTick or 0) + 1
    if self.sigTick % 10 ~= 0 then return end
    local p = getSpecificPlayer(self.pn)
    if not p then return end
    local ok, sig = pcall(self.outfitSig, self, p)
    if not ok then return end
    self.lastSig = sig
end

function E:buildModel()
    local mx = GAP * 2 + SLOT
    self.modelBox = { x = mx, y = LABEL, w = MODEL_W, h = 8 * ROW - GAP - LABEL }
    if self.healthOverlay then self:removeChild(self.healthOverlay); self.healthOverlay = nil end
    if TGI.Health then
        local fh = self.modelBox.h - 4
        self.healthOverlay = TGI.Health.box(self, mx + 2, LABEL + 2, MODEL_W - 4, fh, self.pn)
        local panel = self
        self.healthOverlay.afterFigure = function(ui) panel:drawConnectors(ui) end
    end
end

function E:vitalsMore() return not TGI.Options or TGI.Options.get("vitalsMore") ~= false end
function E:vitalsH()
    if not self:vitalsOn() then return 0 end
    return (self:vitalsMore() and (VIT_H * 2 + 3) or VIT_H) + 8
end
function E:vitalsY() return 9 * ROW + 2 end

function E:drawConnectors(ui)
    local mb = self.modelBox
    local ox, oy = ui:getX(), ui:getY()
    local ov, H = self.healthOverlay, TGI.Health
    local sex = H and H.sex(getSpecificPlayer(self.pn)) or "m"
    for _, s in ipairs(E.SLOTS) do
        if s.ax then
            local x, y, w, h = self:slotRect(s)
            local tx, ty = mb.x + s.ax * mb.w, mb.y + s.ay * mb.h
            if ov and H and s.part then
                local cx, cy = H.center(s.part, ov.width, ov.height, "S", sex)
                if cx then tx, ty = ov:getX() + cx, ov:getY() + cy + (s.dy or 0) * ov.height end
            end
            local sx = (s.side == "L") and (x + w) or x
            local sy = y + h / 2

            local filled = self.assign and self.assign[s.id] ~= nil
            if filled then
                local a, c = 0.28, T.dim
                local midx = (s.side == "L") and (mb.x + 6) or (mb.x + mb.w - 6)
                ui:drawRect(math.min(sx, midx) - ox, sy - oy, math.abs(midx - sx), 1, a, c.r, c.g, c.b)
                ui:drawRect(midx - ox, math.min(sy, ty) - oy, 1, math.abs(ty - sy), a, c.r, c.g, c.b)
                ui:drawRect(math.min(midx, tx) - ox, ty - oy, math.abs(tx - midx), 1, a, c.r, c.g, c.b)
            end
        end
    end

end

function E.applyScale()
    local k = T.SCALE or 1
    SLOT = math.floor(52 * k + 0.5)
    GAP = math.floor(4 * k + 0.5)
    MODEL_W = math.floor(200 * k + 0.5)

    local fh = 15
    local tm = getTextManager and getTextManager()
    if tm then fh = tm:getFontHeight(UIFont.Small) or 15 end
    LABEL = math.max(16, fh + 1)
    VIT_H = math.max(math.floor(15 * k + 0.5), fh)
    ROW = SLOT + LABEL + GAP
    MINI = math.floor(T.CELL * 0.72)
    BC = math.floor(T.CELL * 0.6)
end
E.applyScale()

function E:initialise()
    ISPanel.initialise(self)
    Drag.register(self)
end

function E:close() Drag.unregister(self) end

function E:slotRect(s)
    if s.hand then
        local y = 8 * ROW + LABEL
        if s.hand == "primary" then return GAP, y, SLOT * 2 + MODEL_W - SLOT + GAP, SLOT end
        return GAP * 3 + SLOT * 2 + MODEL_W - SLOT, y, SLOT, SLOT
    end
    local x = (s.side == "L") and GAP or (GAP * 3 + SLOT + MODEL_W)
    return x, s.r * ROW + LABEL, SLOT, SLOT
end

local REGION = { Hand_L = "hands", Hand_R = "hands", ForeArm_L = "arms", ForeArm_R = "arms",
    UpperArm_L = "arms", UpperArm_R = "arms", Torso_Upper = "torso", Torso_Lower = "torso", Back = "torso",
    Head = "head", Neck = "head", Groin = "legs", UpperLeg_L = "legs", UpperLeg_R = "legs",
    LowerLeg_L = "shin", LowerLeg_R = "shin", Foot_L = "feet", Foot_R = "feet" }
local REGION_SLOT = { hands = "hands", arms = "pads", torso = "torso", head = "head", legs = "legs", shin = "pads", feet = "feet" }
local partsCache, partsN = {}, 0
function E.slotByParts(item)
    if not instanceof(item, "Clothing") then return nil end
    local ft = item:getFullType()
    local v = partsCache[ft]
    if v == nil then
        v = false
        pcall(function()
            local cp = item:getCoveredParts()
            if not cp or cp:size() == 0 then return end
            local reg, groin = nil, false
            for i = 0, cp:size() - 1 do
                local pn = tostring(cp:get(i))
                if pn == "Groin" then groin = true end
                local r = REGION[pn]
                if not r then return end

                if r == "shin" and reg == "legs" then r = "legs" end
                if r == "legs" and reg == "shin" then reg = "legs" end
                if r == "arms" and reg == "torso" then r = "torso" end
                if r == "torso" and reg == "arms" then reg = "torso" end
                if reg and reg ~= r then return end
                reg = r
            end

            if reg == "legs" and not groin then reg = "shin" end
            v = reg and REGION_SLOT[reg] or false
        end)
        partsN = partsN + 1
        if partsN > 500 then partsCache, partsN = {}, 1 end
        partsCache[ft] = v
    end
    return v or nil
end

function E.cosmetic(item)
    if TGI.Options.get("hideCosmetic") == false then return false end
    if item:isHidden() == true then return true end
    local ok, res = pcall(function()
        if item:getActualWeight() > 0.001 then return false end
        if not instanceof(item, "Clothing") then return false end
        return item:getBiteDefense() <= 0 and item:getScratchDefense() <= 0 and (item:getInsulation() or 0) <= 0
            and (item:getWindresistance() or 0) <= 0
    end)
    return ok and res == true
end
function E:othersY() return 9 * ROW + LABEL + self:vitalsH() end
function E:perRow() return math.max(1, math.floor((self.width - GAP) / (MINI + 2))) end
function E:othersRows() return math.ceil(#self.others / self:perRow()) end

local BELT_ROWS = 3
function E:beltY()
    local rows = self:othersRows()
    if rows == 0 then return self:othersY() end
    return self:othersY() + rows * (MINI + 2) + LABEL + GAP
end

local function beltRowH() return math.max(26, math.floor(BC * 1.15)) end
function E:beltLayout()
    local out = {}
    local rh = beltRowH()
    for i in ipairs(self.belt or {}) do
        out[i] = { x = GAP, row = i - 1, w = self.width - GAP * 2, h = rh }
    end
    self._beltRowH = rh + 2
    return out, #out
end
function E:beltRows() local _, n = self:beltLayout(); return n end
function E:beltVisibleRows() return math.min(BELT_ROWS, self:beltRows()) end
function E:statsY()
    local y = self:beltY()
    local br = self:beltVisibleRows()
    if br > 0 then return y + br * (beltRowH() + 2) + LABEL + GAP end
    if self:othersRows() == 0 then return y + 4 end
    return y
end

function E:beltRect(i)
    local lay = self._lay or self:beltLayout()
    local t = lay[i]
    if not t then return nil end
    local r = t.row - (self.beltScroll or 0)
    if r < 0 or r >= BELT_ROWS then return nil end
    return t.x, self:beltY() + LABEL + r * (beltRowH() + 2), t.w, t.h
end

function E:beltBarRect()
    local n = self:beltRows()
    if n <= BELT_ROWS then return nil end
    local y = self:beltY() + LABEL
    local h = BELT_ROWS * (beltRowH() + 2) - 2
    local th = math.max(10, math.floor(h * BELT_ROWS / n))
    local ty = y + math.floor((h - th) * (self.beltScroll or 0) / (n - BELT_ROWS))
    return { x = self.width - 5, y = y, w = 4, h = h, ty = ty, th = th, n = n }
end
function E:onMouseWheel(del)
    local my = self:getMouseY()
    local y0 = self:beltY()
    if my >= y0 and my < y0 + LABEL + BELT_ROWS * (beltRowH() + 2) and self:beltRows() > BELT_ROWS then
        self.beltScroll = math.max(0, math.min(self:beltRows() - BELT_ROWS, (self.beltScroll or 0) + (del > 0 and 1 or -1)))
        return true
    end
    return true
end
function E:fitHeight()
    local h = self:statsY() + 56
    if self.height ~= h then self:setHeight(h); if self.parent and self.parent.relayout then pcall(self.parent.relayout, self.parent) end end
end

function E:assignItems()
    local p = getSpecificPlayer(self.pn)
    self.assign, self.others, self.belt, self.multi = {}, {}, {}, {}
    if not p then return end
    local used, worn = {}, {}
    local wi = safe(function() return p:getWornItems() end, nil)
    if wi then
        for i = 0, wi:size() - 1 do
            local w = wi:get(i)
            local item = safe(function() return w:getItem() end, nil)
            local loc = E.normLoc(safe(function() return tostring(w:getLocation()) end, ""))

            local tech = string.find(loc, "bandage", 1, true) or string.find(loc, "wound", 1, true)
                or string.find(loc, "zeddmg", 1, true) or string.find(loc, "_hidden", 1, true)
            if item and not tech then worn[#worn + 1] = { item = item, loc = loc } end
        end
    end
    local order = {}
    for _, s in ipairs(E.SLOTS) do if s.hand then order[#order + 1] = s end end
    for _, id in ipairs(E.MATCH) do if BYID[id] then order[#order + 1] = BYID[id] end end
    for _, s in ipairs(order) do
        if s.hand == "primary" then
            self.assign.prim = safe(function() return p:getPrimaryHandItem() end, nil)
        elseif s.hand == "secondary" then
            local sec = safe(function() return p:getSecondaryHandItem() end, nil)
            if sec and sec ~= self.assign.prim then self.assign.sec = sec end
        elseif s.locs then
            local list = {}
            for _, key in ipairs(s.locs) do
                for _, w in ipairs(worn) do
                    if not used[w.item] and string.find(w.loc, key, 1, true) then
                        list[#list + 1] = w.item; used[w.item] = true
                    end
                end
            end
            if #list > 0 then self.assign[s.id] = list[1]; self.multi[s.id] = list end
            if #list > 4 then for i = 4, #list do self.others[#self.others + 1] = list[i] end end
        else
            for _, key in ipairs(s.locs) do
                if not self.assign[s.id] then
                    for _, w in ipairs(worn) do
                        if not used[w.item] and string.find(w.loc, key, 1, true) then
                            self.assign[s.id] = w.item; used[w.item] = true; break
                        end
                    end
                end
            end
        end
    end
    for _, w in ipairs(worn) do
        if not used[w.item] and not E.cosmetic(w.item) then

            local sid = E.slotByParts(w.item)
            if sid and BYID[sid] then
                local list = self.multi[sid] or {}
                list[#list + 1] = w.item
                self.multi[sid] = list
                self.assign[sid] = self.assign[sid] or w.item
            else
                self.others[#self.others + 1] = w.item
            end
        end
    end

    local inv = p:getInventory():getItems()
    for i = 0, inv:size() - 1 do
        local it = inv:get(i)
        if safe(function() return it:getAttachedSlot() end, -1) >= 0 and it ~= self.assign.prim and it ~= self.assign.sec then
            self.belt[#self.belt + 1] = it
        end
    end
end

local function label(ui, key, x, y, maxW)
    local t = getText(key)
    if T.modern() then t = string.upper(t) end
    if maxW then t = D._short(t, maxW, UIFont.Small) end
    ui:drawText(t, x + 1, y - 2, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
end

local function box(ui, x, y, w, h)
    if T.modern() then

        ui:drawRect(x, y, w, h, 0.92, 0.025, 0.026, 0.026)
        ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.85, T.cell.r + 0.02, T.cell.g + 0.02, T.cell.b + 0.02)
        ui:drawRect(x + 1, y + 1, w - 2, 1, 0.6, T.cellLine.r, T.cellLine.g, T.cellLine.b)
        ui:drawRectBorder(x, y, w, h, 0.9, T.border.r * 0.8, T.border.g * 0.8, T.border.b * 0.8)
        return
    end
    ui:drawRect(x, y, w, h, T.cell.a, T.cell.r, T.cell.g, T.cell.b)
    T.metalFill(ui, x, y, w, h, 0.55)
    ui:drawRectBorder(x, y, w, h, 1, T.border.r, T.border.g, T.border.b)
end

function E:prerender()

    self._aiN = (self._aiN or 0) + 1
    local p = getSpecificPlayer(self.pn)
    local sig = p and safe(function() return p:getWornItems():size() .. ":" .. p:getInventory():getItems():size() end, "") or ""
    if not self.assign or self._aiN >= 6 or sig ~= self._aiSig then
        self._aiN, self._aiSig = 0, sig
        self:assignItems()
    end
    self:fitHeight()
    self.tgiAct = D.currentAction(getSpecificPlayer(self.pn))
    self:checkOutfit()

    local mb = self.modelBox
    self:drawRect(mb.x, mb.y, mb.w, mb.h, 0.35, 0.02, 0.02, 0.02)
    self:drawRectBorder(mb.x, mb.y, mb.w, mb.h, 0.8, T.border.r, T.border.g, T.border.b)
    if self:vitalsOn() then
        local p0 = getSpecificPlayer(self.pn)
        if p0 then self:renderVitals(p0, GAP, self:vitalsY(), self.width - GAP * 2) end
    end
    for _, s in ipairs(E.SLOTS) do
        local x, y, w, h = self:slotRect(s)
        label(self, s.label, x, y - LABEL, s.hand and nil or (s.side == "L" and SLOT + GAP or SLOT + GAP * 2))
        box(self, x, y, w, h)
        if not self.assign[s.id] and s.icon then
            local t = tex("slot_" .. s.icon)
            if t then self:drawTextureScaledAspect(t, x + 9, y + 9, w - 18, h - 18, 0.28, 1, 1, 1) end
        end
    end
    if #self.others > 0 then label(self, "IGUI_TGI_Other", GAP, self:othersY()) end
end

local function entryOf(item)
    return { key = "e:" .. item:getID(), item = item, items = { item }, w = 1, h = 1 }
end

function E:rowRect(base, i)
    local per = self:perRow()
    local r, c = math.floor((i - 1) / per), (i - 1) % per
    return GAP + c * (MINI + 2), base + LABEL + r * (MINI + 2), MINI, MINI
end

function E:subRects(s, n)
    local x, y, w, h = self:slotRect(s)
    if n <= 1 then return { { x, y, w, h } } end
    local hw, hh = math.floor(w / 2), math.floor(h / 2)
    if n == 2 then return { { x, y, hw, h }, { x + hw, y, w - hw, h } } end
    local r = {}
    for i = 0, math.min(n, 4) - 1 do
        r[#r + 1] = { x + (i % 2) * hw, y + math.floor(i / 2) * hh, hw, hh }
    end
    return r
end

function E.targetsFor(item)
    local t = {}
    if not item then return t end
    if instanceof(item, "HandWeapon") then t.prim = true; t.sec = true end
    local loc = ""
    if instanceof(item, "Clothing") then
        loc = E.normLoc(item:getBodyLocation())
    elseif instanceof(item, "InventoryContainer") then
        loc = E.normLoc(item:canBeEquipped())
    end
    if loc ~= "" and loc ~= "nil" then
        for _, id in ipairs(E.MATCH) do
            local sl = BYID[id]
            if sl.locs then
                for _, key in ipairs(sl.locs) do
                    if string.find(loc, key, 1, true) then t[sl.id] = true; break end
                end
                if t[sl.id] then break end
            end
        end
    end
    pcall(function() if item:getAttachmentType() then t.belt = true end end)
    return t
end

function E:render()
    local d = Drag.active

    local hi = nil
    if d then hi = d.entry.item
    elseif TGI.hover and getTimestampMs() - TGI.hover.t < 150 then hi = TGI.hover.item end
    local targets = (hi and TGI.Options.get("slotHighlight") ~= false) and E.targetsFor(hi) or {}
    local pulse = 0.55 + 0.35 * math.abs(math.sin(getTimestampMs() / 260))
    local over = self:tgiContains(getMouseX(), getMouseY())
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, s in ipairs(E.SLOTS) do
        local item = self.assign[s.id]
        local x, y, w, h = self:slotRect(s)
        local list = self.multi[s.id]
        if list and #list > 1 then
            for i, rc in ipairs(self:subRects(s, #list)) do
                local it = list[i]
                D.tile(self, entryOf(it), rc[1], rc[2], rc[3], rc[4], (d and d.entry.item == it) and 0.35 or 1)
                if i == 4 and #list > 4 then
                    self:drawRect(rc[1] + 1, rc[2] + 1, rc[3] - 2, rc[4] - 2, 0.7, 0, 0, 0)
                    self:drawTextCentre("+" .. (#list - 3), rc[1] + rc[3] / 2, rc[2] + 4, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
                end
            end
        elseif item then D.tile(self, entryOf(item), x, y, w, h, (d and d.entry.item == item) and 0.35 or 1) end

        if item and self.tgiAct and (self.tgiAct.item == item or self.tgiAct.gun == item) then D.progress(self, x, y, w, h, self.tgiAct.frac) end
        if list and #list > 1 then
            local txt = "x" .. #list
            local tw = TGI.Theme.measure(UIFont.Small, txt) + 6
            self:drawRect(x + w - tw, y - 1, tw, 14, 0.95, 0.55, 0.42, 0.1)
            self:drawTextCentre(txt, x + w - tw / 2, y - 2, 1, 1, 1, 1, UIFont.Small)
            self:drawRectBorder(x - 1, y - 1, w + 2, h + 2, 0.8, 0.9, 0.7, 0.25)
        end
        if targets[s.id] then
            local a = d and pulse or 0.6
            self:drawRectBorder(x - 1, y - 1, w + 2, h + 2, a, 0.35, 0.9, 0.4)
            self:drawRectBorder(x, y, w, h, a * 0.8, 0.35, 0.9, 0.4)
            self:drawRect(x, y, w, h, (d and 0.12 or 0.07), 0.35, 0.9, 0.4)
        end
        if d and over and mx >= x and my >= y and mx < x + w and my < y + h then
            self:drawRect(x, y, w, h, T.ok.a, T.ok.r, T.ok.g, T.ok.b)
        end
    end
    for i, item in ipairs(self.others) do
        local x, y, w, h = self:rowRect(self:othersY(), i)
        box(self, x, y, w, h)
        D.tile(self, entryOf(item), x, y, w, h, 1)
    end
    self._lay = self:beltLayout()
    if #self.belt > 0 then
        local by = self:beltY()
        self.beltScroll = math.max(0, math.min(math.max(0, self:beltRows() - BELT_ROWS), self.beltScroll or 0))
        label(self, "IGUI_TGI_Attached", GAP, by)
        if self:beltRows() > BELT_ROWS then
            local txt = (self.beltScroll + 1) .. "-" .. (self.beltScroll + BELT_ROWS) .. " / " .. self:beltRows()
            local tw = TGI.Theme.measure(UIFont.Small, txt)
            self:drawText(txt, self.width - tw - GAP, by - 2, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
        end
        for i, item in ipairs(self.belt) do
            local x, y, w, h = self:beltRect(i)
            if x then self:drawBeltRow(item, x, y, w, h, d) end
        end

        local sb = self:beltBarRect()
        if sb then
            self:drawRect(sb.x, sb.y, sb.w, sb.h, 0.5, 0, 0, 0)
            self:drawRect(sb.x, sb.ty, sb.w, sb.th, 0.9, T.accent.r, T.accent.g, T.accent.b)
        end
    end
    self:renderStats()
    self:updateFly(mx, my)
    self:renderFly()

    if not d and (self:isMouseOver() or self:flyHit(mx, my)) then
        local _, it = self:hit(mx, my)
        if it and not getPlayerContextMenu(self.pn):isAnyVisible() then TGI.Tip.show(it, self, self.pn, {})
        else TGI.Tip.hide(self) end
    else
        TGI.Tip.hide(self)
    end
end

function E:onMouseMoveOutside() TGI.Tip.hide(self) end

function E:renderStats()
    local p = getSpecificPlayer(self.pn)
    if not p then return end
    local y = self:statsY()
    local wt = safe(function() return p:getInventoryWeight() end, 0)
    local mw = math.max(1, safe(function() return p:getMaxWeight() end, 1))
    local frac = wt / mw
    local x, bw, bh = GAP, self.width - GAP * 2, 12
    local span = math.max(1.5, frac * 1.05)
    local function px(f) return x + bw * math.min(1, f / span) end
    if T.modern() then

        local fh = D.fh and D.fh(UIFont.Small) or getTextManager():getFontHeight(UIFont.Small)
        local sc = T.SCALE or 1
        local ph = fh + math.floor(9 * sc + 0.5)
        local th = math.max(2, math.floor(3 * sc + 0.5))
        local cr, cg, cb = 0.82, 0.82, 0.78
        if frac > 1.5 then cr, cg, cb = 0.95, 0.25, 0.2 elseif frac > 1 then cr, cg, cb = 0.92, 0.6, 0.25 end
        self:drawRect(x, y, bw, ph, 0.9, 0.035, 0.037, 0.037)
        local wic = D.tex("ic_weight")
        local isz = fh - 2
        if wic then self:drawTextureScaledAspect(wic, x + 4, y + 3, isz, isz, 0.85, cr, cg, cb) end
        self:drawText(string.upper(getText("IGUI_TGI_Weight")), x + isz + 9, y + 2, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
        self:drawTextRight(string.format("%.1f / %.1f", wt, mw), x + bw - 5, y + 2, cr, cg, cb, 1, UIFont.Small)
        local by = y + ph - th - 2
        self:drawRect(x + 3, by, bw - 6, th, 0.85, 0.1, 0.1, 0.1)
        local fw = math.min(bw - 6, px(frac) - x - 3)
        if fw > 0 then self:drawRect(x + 3, by, fw, th, 0.95, cr, cg, cb) end
        local x1, x15 = px(1), px(1.5)
        self:drawRect(x1, by - 3, 1, th + 3, 0.9, 0.92, 0.6, 0.25)
        if x15 < x + bw - 4 then self:drawRect(x15, by - 3, 1, th + 3, 0.9, 0.95, 0.25, 0.2) end
        return
    end
    local wic = D.tex("ic_weight")
    if wic then self:drawTextureScaledAspect(wic, x + 1, y + 1, 13, 13, 0.9, 1, 1, 1) end
    self:drawText(getText("IGUI_TGI_Weight"), x + (wic and 17 or 1), y, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
    local cr, cg, cb = 0.35, 0.72, 0.35
    if frac > 1.5 then cr, cg, cb = 0.9, 0.2, 0.18 elseif frac > 1 then cr, cg, cb = 0.92, 0.55, 0.2 elseif frac > 0.75 then cr, cg, cb = 0.85, 0.75, 0.3 end
    self:drawTextRight(string.format("%.1f / %.1f", wt, mw), x + bw, y, cr, cg, cb, 1, UIFont.Small)
    local by = y + 18
    self:drawRect(x, by, bw, bh, 0.95, 0.02, 0.022, 0.022)
    T.metalFill(self, x, by, bw, bh, 0.6)

    local x1, x15 = px(1), px(1.5)
    self:drawRect(x1, by + 1, x15 - x1, bh - 2, 0.18, 0.95, 0.55, 0.2)
    if x15 < x + bw then self:drawRect(x15, by + 1, x + bw - x15, bh - 2, 0.22, 0.95, 0.2, 0.15) end
    local fw = px(frac) - x
    if fw > 2 then
        self:drawRect(x + 1, by + 1, fw - 2, bh - 2, 0.75, cr * 0.7, cg * 0.7, cb * 0.7)
        local grad = T.grad()
        if grad then self:drawTextureScaled(grad, x + 1, by + 1, fw - 2, bh - 2, 0.55, cr, cg, cb) end
        self:drawRect(x + 1, by + 1, fw - 2, 1, 0.5, 1, 1, 1)
    end
    self:drawRectBorder(x, by, bw, bh, 1, T.border.r, T.border.g, T.border.b)

    local fh = getTextManager():getFontHeight(UIFont.Small)

    local function mark(mx, icon, text, r, g, b)
        self:drawRect(mx, by - 3, 2, bh + 6, 1, r, g, b)
        local sz = 14
        local ix = math.max(x, math.min(x + bw - sz, mx - sz / 2 + 1))
        local t = D.tex(icon)
        if t then self:drawTextureScaled(t, ix, by + bh + 3, sz, sz, 0.95, r, g, b) end
        local mx0, my0 = self:getMouseX(), self:getMouseY()
        if mx0 >= ix - 2 and mx0 < ix + sz + 2 and my0 >= by - 3 and my0 < by + bh + sz + 5 then
            local tw = TGI.Theme.measure(UIFont.Small, text)
            local tx = math.max(0, math.min(self.width - tw - 6, mx - tw / 2))
            self:drawRect(tx - 3, by + bh + sz + 4, tw + 6, fh + 2, 0.9, 0.03, 0.03, 0.03)
            self:drawText(text, tx, by + bh + sz + 5, r, g, b, 1, UIFont.Small)
        end
    end
    mark(x1, "ic_weight", getText("IGUI_TGI_Overload"), 0.95, 0.6, 0.25)
    if x15 < x + bw - 4 then mark(x15, "ic_overload", getText("IGUI_TGI_Overload2"), 0.95, 0.3, 0.2) end
end

function E:vitalsOn() return not TGI.Options or TGI.Options.get("vitals") ~= false end
function E:readVitals(p)
    local now = getTimestampMs()
    if self._vit and now - self._vitT < 500 then return self._vit end
    local v = {}
    v.health = safe(function() return p:getBodyDamage():getOverallBodyHealth() end, 100) / 100

    local st = p:getStats()
    v.food = CharacterStat and 1 - safe(function() return st:get(CharacterStat.HUNGER) end, 0) or 1
    v.water = CharacterStat and 1 - safe(function() return st:get(CharacterStat.THIRST) end, 0) or 1

    v.stamina = CharacterStat and safe(function() return st:get(CharacterStat.ENDURANCE) end, 1) or 1
    v.rest = CharacterStat and 1 - safe(function() return st:get(CharacterStat.FATIGUE) end, 0) or 1
    v.temp = CharacterStat and safe(function() return st:get(CharacterStat.TEMPERATURE) end, 37) or 37
    for k, x in pairs(v) do if k ~= "temp" then v[k] = math.max(0, math.min(1, x)) end end
    self._vit, self._vitT = v, now
    return v
end
function E:renderVitals(p, x, y, bw)
    local v = self:readVitals(p)

    local t = v.temp or 37
    local tr, tg, tb = 0.85, 0.75, 0.35
    if t < 35.5 then tr, tg, tb = 0.35, 0.65, 1 elseif t > 38 then tr, tg, tb = 0.95, 0.3, 0.2 end
    local rows = {
        { { "ic_health", v.health, 0.85, 0.22, 0.2 }, { "ic_hunger", v.food, 0.9, 0.62, 0.2 }, { "ic_drop", v.water, 0.3, 0.62, 0.95 } },
        { { "ic_stamina", v.stamina, 0.4, 0.8, 0.4 }, { "ic_sleep", v.rest, 0.6, 0.55, 0.9 },
          { "ic_temp", math.max(0, math.min(1, (t - 34) / 7)), tr, tg, tb, string.format("%.1f\194\176", t), noBlink = true } },
    }
    if not self:vitalsMore() then rows[2] = nil end
    local gap = 6
    local cw = math.floor((bw - gap * 2) / 3)
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local isz = VIT_H - 2
    for ri, list in ipairs(rows) do
        local ry = y + (ri - 1) * (VIT_H + 3)
        for i, it in ipairs(list) do
            local cx = x + (i - 1) * (cw + gap)
            local f = it[2]
            local r, g, b = it[3], it[4], it[5]

            if f < 0.25 and not it.noBlink then
                local pl = 0.6 + 0.4 * math.abs(math.sin(getTimestampMs() / 250))
                r, g, b = 0.95 * pl, 0.18 * pl, 0.15 * pl
            end
            local ic = D.tex(it[1])
            if T.modern() then

                local sr, sg, sb = 0.82, 0.82, 0.78
                if TGI.Options.get("vitalsColor") ~= 2 then sr, sg, sb = r * 0.85 + 0.1, g * 0.85 + 0.1, b * 0.85 + 0.1 end
                if not it.noBlink then
                    if f < 0.25 then sr, sg, sb = 0.95, 0.25, 0.2
                    elseif f < 0.5 then sr, sg, sb = 0.9, 0.62, 0.25 end
                elseif it[3] ~= 0.85 then sr, sg, sb = r, g, b end
                self:drawRect(cx, ry, cw, VIT_H, 0.9, 0.035, 0.037, 0.037)
                if ic then self:drawTextureScaledAspect(ic, cx + 3, ry + 2, isz - 2, isz - 2, 0.9, sr, sg, sb) end
                local txt = it[6] or tostring(math.floor(f * 100 + 0.5))
                self:drawText(txt, cx + isz + 5, ry + math.floor((VIT_H - fh) / 2) - 1, sr, sg, sb, 1, UIFont.Small)
                local fw = math.floor((cw - 2) * math.max(0, math.min(1, f)))
                local bh = math.max(2, math.floor(2 * (T.SCALE or 1) + 0.5))
                self:drawRect(cx + 1, ry + VIT_H - bh - 1, cw - 2, bh, 0.8, 0.1, 0.1, 0.1)
                if fw > 0 then self:drawRect(cx + 1, ry + VIT_H - bh - 1, fw, bh, 0.95, sr, sg, sb) end
            else
            if ic then self:drawTextureScaledAspect(ic, cx, ry + 1, isz, isz, 1, r, g, b) end
            local bx, bww = cx + isz + 3, cw - isz - 3
            self:drawRect(bx, ry, bww, VIT_H, 0.95, 0.02, 0.022, 0.022)
            T.metalFill(self, bx, ry, bww, VIT_H, 0.35)
            local fw = math.floor((bww - 2) * f)
            if fw > 0 then
                self:drawRect(bx + 1, ry + 1, fw, VIT_H - 2, 0.75, r * 0.7, g * 0.7, b * 0.7)
                local grad = T.grad()
                if grad then self:drawTextureScaled(grad, bx + 1, ry + 1, fw, VIT_H - 2, 0.55, r, g, b) end
                self:drawRect(bx + 1, ry + 1, fw, 1, 0.4, 1, 1, 1)
            end
            self:drawRectBorder(bx, ry, bww, VIT_H, 1, T.border.r, T.border.g, T.border.b)
            local txt = it[6] or tostring(math.floor(f * 100 + 0.5))
            self:drawTextCentre(txt, bx + bww / 2, ry + math.floor((VIT_H - fh) / 2), 1, 1, 1, 0.95, UIFont.Small)
            end
        end
    end
end

local FLY_RH = 30
function E:flyRect()
    local f = self.fly
    if not f then return nil end
    local x = GAP * 2 + SLOT + 4
    local w = MODEL_W - 8 + (f.slot.side == "R" and 0 or 0)
    local h = 22 + #f.list * FLY_RH + 4
    local y = math.max(2, math.min(f.y, self.height - h - 2))
    return x, y, w, h
end
function E:updateFly(mx, my)
    local fx, fy, fw, fh = self:flyRect()
    if fx and mx >= fx - 6 and my >= fy and mx < fx + fw + 6 and my < fy + fh then return end
    self.fly = nil
    if not self:isMouseOver() or Drag.active then return end
    for _, s in ipairs(E.SLOTS) do
        local list = self.multi[s.id]
        if list and #list > 1 then
            local x, y, w, h = self:slotRect(s)
            if mx >= x and my >= y and mx < x + w and my < y + h then
                self.fly = { slot = s, list = list, y = y }
                return
            end
        end
    end
end
function E:flyHit(mx, my)
    local fx, fy, fw, fh = self:flyRect()
    if not fx or mx < fx or mx >= fx + fw or my < fy + 22 or my >= fy + fh then return nil end
    return self.fly.list[math.floor((my - fy - 22) / FLY_RH) + 1]
end

local Fly = ISPanel:derive("TGIEquipFly")
TGI.Theme.applyAlpha(Fly)
function Fly:prerender()
    local e = self.owner
    local f = e and e.fly
    if not f then return end
    local fw, fh = self.width, self.height
    self:drawRect(0, 0, fw, fh, 0.96, T.bg.r, T.bg.g, T.bg.b)
    T.metalFill(self, 0, 0, fw, fh, 0.5)
    self:drawRect(0, 0, fw, 20, 0.8, 0.05, 0.05, 0.05)
    self:drawRect(0, 20, fw, 1, 0.9, T.accent.r, T.accent.g, T.accent.b)
    self:drawRectBorder(0, 0, fw, fh, 1, T.accent.r * 0.7, T.accent.g * 0.7, T.accent.b * 0.7)
    self:drawText(D._short(getText(f.slot.label), fw - 40, UIFont.Small), 6, 2, T.accent.r, T.accent.g, T.accent.b, 1, UIFont.Small)
    self:drawTextRight("x" .. #f.list, fw - 6, 2, T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)
    local hov = e:flyHit(e:getMouseX(), e:getMouseY())
    for i, it in ipairs(f.list) do
        local y = 22 + (i - 1) * FLY_RH
        if it == hov then self:drawRect(1, y, fw - 2, FLY_RH, 0.18, T.accent.r, T.accent.g, T.accent.b) end
        local tex = it:getTex()
        if tex then self:drawTextureScaledAspect(tex, 4, y + 2, FLY_RH - 4, FLY_RH - 4, 1, 1, 1, 1) end
        self:drawText(D._short(it:getDisplayName(), fw - FLY_RH - 12, UIFont.Small), FLY_RH + 4, y + (FLY_RH - getTextManager():getFontHeight(UIFont.Small)) / 2, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
end

function Fly:onMouseDown(x, y) return self.owner:onMouseDown(x + self:getX(), y + self:getY()) end
function Fly:onMouseUp(x, y) return self.owner:onMouseUp(x + self:getX(), y + self:getY()) end
function Fly:onMouseMove(dx, dy) if self.owner.onMouseMove then self.owner:onMouseMove(dx, dy) end end
function Fly:onRightMouseUp(x, y)
    if self.owner.onRightMouseUp then return self.owner:onRightMouseUp(x + self:getX(), y + self:getY()) end
end

function E:renderFly()
    local fx, fy, fw, fh = self:flyRect()
    if not self.flyPanel then
        local p = Fly:new(0, 0, 10, 10)
        p.background = false
        p.owner = self
        p:initialise()
        self:addChild(p)
        self.flyPanel = p
    end
    local p = self.flyPanel
    if not fx then p:setVisible(false); return end
    p:setX(fx); p:setY(fy); p:setWidth(fw); p:setHeight(fh)
    p:setVisible(true)
    p:bringToTop()
end

function E:hit(mx, my)
    local fi = self:flyHit(mx, my)
    if fi then return self.fly.slot, fi end
    for _, s in ipairs(E.SLOTS) do
        local x, y, w, h = self:slotRect(s)
        if mx >= x and my >= y and mx < x + w and my < y + h then
            local list = self.multi[s.id]
            if list and #list > 1 then
                for i, rc in ipairs(self:subRects(s, #list)) do
                    if mx >= rc[1] and my >= rc[2] and mx < rc[1] + rc[3] and my < rc[2] + rc[4] then
                        if i == 4 and #list > 4 then return s, nil, list end
                        return s, list[i]
                    end
                end
            end
            return s, self.assign[s.id]
        end
    end
    for i, item in ipairs(self.others) do
        local x, y, w, h = self:rowRect(self:othersY(), i)
        if mx >= x and my >= y and mx < x + w and my < y + h then return nil, item end
    end
    for i, item in ipairs(self.belt or {}) do
        local x, y, w, h = self:beltRect(i)
        if x and mx >= x and my >= y and mx < x + w and my < y + h then return "belt", item end
    end
    return nil, nil
end

local function hangPlace(item)

    local t = ""
    if item.getAttachedSlotType then t = string.lower(tostring(item:getAttachedSlotType() or "")) end
    if string.find(t, "holster", 1, true) then return "ic_holster", "IGUI_TGI_OnHolster" end
    if string.find(t, "back", 1, true) then return "slot_back", "IGUI_TGI_OnBack" end
    return "slot_belt", "IGUI_TGI_OnBelt"
end
function E:drawBeltRow(item, x, y, w, h, d)
    box(self, x, y, w, h)
    local tw = h * 2
    local e = entryOf(item); e.w, e.h = 2, 1
    D.noLabel = true
    D.tile(self, e, x, y, tw, h, (d and d.entry.item == item) and 0.35 or 1)
    D.noLabel = nil
    local fh = getTextManager():getFontHeight(UIFont.Small)

    local ic, key = hangPlace(item)
    local lbl = getText(key)
    local lw = TGI.Theme.measure(UIFont.Small, lbl)
    local isz = h - 8
    local t = D.tex(ic) or tex(string.gsub(ic, "^slot_", ""))
    local rx = x + w - lw - isz - 10
    if t then self:drawTextureScaledAspect(t, rx, y + 4, isz, isz, 0.9, T.text.r, T.text.g, T.text.b) end
    self:drawText(lbl, rx + isz + 4, y + math.floor((h - fh) / 2), T.dim.r, T.dim.g, T.dim.b, 1, UIFont.Small)

    local nx = x + tw + 6
    local room = rx - nx - 8
    local name = D._short(safe(function() return item:getDisplayName() end, "?"), room, UIFont.Small)
    self:drawText(name, nx, y + 1, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    local cmax = safe(function() return item:getConditionMax() end, 0)
    if cmax and cmax > 0 and room > 10 then
        local f = math.max(0, math.min(1, safe(function() return item:getCondition() end, cmax) / cmax))
        local by = y + h - 7
        self:drawRect(nx, by, room, 4, 0.9, 0.05, 0.05, 0.05)
        local r, g, b = 0.35, 0.8, 0.35
        if f < 0.3 then r, g, b = 0.95, 0.3, 0.2 elseif f < 0.6 then r, g, b = 0.95, 0.75, 0.3 end
        self:drawRect(nx, by, math.floor(room * f), 4, 0.9, r, g, b)
    end
    if self.tgiAct and (self.tgiAct.item == item or self.tgiAct.gun == item) then D.progress(self, x, y, w, h, self.tgiAct.frac) end
end

function E:holsteredGun()
    for _, it in ipairs(self.belt or {}) do
        if instanceof(it, "HandWeapon") and it:isRanged() and not it:isTwoHandWeapon() then return it end
    end
    return nil
end

function E:onMouseDown(x, y)
    local sb = self:beltBarRect()
    if sb and x >= sb.x - 4 and y >= sb.y and y < sb.y + sb.h then
        local f = (y - sb.y) / sb.h
        self.beltScroll = math.max(0, math.min(sb.n - BELT_ROWS, math.floor(f * (sb.n - BELT_ROWS + 1))))
        return true
    end

    local ov = self.healthOverlay
    if ov and ov:getIsVisible() and TGI.Health and TGI.Health.modeClick
        and TGI.Health.modeClick(x - ov:getX(), y - ov:getY()) then return true end
    local s, item = self:hit(x, y)
    if not item then return true end
    local now = getTimestampMs()
    if isAltKeyDown() or (self.lastClick and self.lastClick.item == item and now - self.lastClick.t < 350) then
        self.lastClick = nil

        if s == "belt" then A.equip(self.pn, item); return true end
        local gun = s and type(s) == "table" and s.id == "holster" and self:holsteredGun() or nil
        if gun and not isAltKeyDown() then A.equip(self.pn, gun) else A.unequip(self.pn, item) end
        return true
    end
    if isCtrlKeyDown() and TGI.Window.instance then
        local e = entryOf(item); e.w, e.h = TGI.Size.of(item)
        local main = TGI.Window.instance.mine.panels[1]
        if main then TGI.Window.quickTransfer(self.pn, e, main.model) end
        return true
    end
    self.lastClick = { item = item, t = now }
    self.press = { item = item, x = x, y = y }
    return true
end

function E:onMouseMove()
    local pr = self.press
    if pr and not Drag.active and isMouseButtonDown(0) then
        local mx, my = self:getMouseX(), self:getMouseY()
        if math.abs(mx - pr.x) + math.abs(my - pr.y) > 5 then
            local e = entryOf(pr.item)
            e.w, e.h = TGI.Size.of(pr.item)
            Drag.start(self.pn, e, { slot = true }, 0, 0, false, false)
            self.press = nil
        end
    end
end

function E:onMouseUp() self.press = nil; if Drag.active then Drag.finish() end; return true end
function E:onMouseUpOutside() self.press = nil end

function E:onRightMouseUp(x, y)
    local _, item = self:hit(x, y)
    if item then A.contextMenu(self.pn, { item }, self:getAbsoluteX() + x, self:getAbsoluteY() + y, true); return true end

    local ov = self.healthOverlay
    if ov and TGI.Health and ov:getIsVisible() then
        pcall(function()
            local p = getSpecificPlayer(self.pn)
            local name = TGI.Health.partAt(x - ov:getX(), y - ov:getY(), ov.width, ov.height, "S", TGI.Health.sex(p))
            local part = name and TGI.Health.bodyPart(p, name)
            if not part then return end

            local menu = ISContextMenu.get(self.pn, self:getAbsoluteX() + x, self:getAbsoluteY() + y)
            local n = 0
            if part:bandaged() then
                local opt = menu:addOption(getText("ContextMenu_Remove_Bandage"), p, function(pl)
                    ISTimedActionQueue.add(ISApplyBandage:new(pl, pl, nil, part, false))
                end)
                local bt = part:getBandageType()
                if bt then pcall(function() opt.itemForTexture = instanceItem(bt) end) end
                n = 1
            end
            if TGI.Health.addTreatOptions then n = n + TGI.Health.addTreatOptions(menu, p, name) end
            if n == 0 then menu:setVisible(false) end
        end)
    end
    return true
end

function E:tgiContains(ax, ay)
    if not self:isReallyVisible() then return false end
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    return ax >= x and ay >= y and ax < x + self.width and ay < y + self.height
end

function E:tgiDropAt(ax, ay, d)
    if d.source and d.source.slot then return true end
    local lx, ly = ax - self:getAbsoluteX(), ay - self:getAbsoluteY()
    local s = self:hit(lx, ly)
    local item = d.entry.item

    local mb = self.modelBox
    local ov = self.healthOverlay
    if not s and mb and TGI.Health and ov then
        local ok, res = pcall(TGI.Health.drop, d.pn, lx - ov:getX(), ly - ov:getY(), ov.width, ov.height, "S", d)
        if not ok then print("[TGI] health drop: " .. tostring(res)) end
        if ok and res then return true end
    end
    if s and s.hand == "secondary" then
        A.equipSecondary(d.pn, item)
    elseif s and s.hand == "primary" then
        A.equipHand(d.pn, item, true)
    else
        A.equip(d.pn, item)
    end
    return true
end

return E
