require "TGI/TGI_Theme"
require "TGI/TGI_Options"
require "TGI/TGI_IconDefaults"
TGI = TGI or {}
local T = TGI.Theme
local D = {}
TGI.Draw = D

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

D.flips = nil
local FLIP_FILE = "TGI_iconflip.txt"

local function iconSet() return tostring(rawget(_G, "ICONS3D_SET") or 1) end
function D.loadFlips()
    D.flips = {}
    pcall(function()
        local r = getFileReader(FLIP_FILE, true)
        if not r then return end
        local line = r:readLine()
        local set = line and string.match(line, "^#set=(.+)$")
        if set then line = r:readLine() else set = "1" end
        if set ~= iconSet() then r:close(); return end
        while line do
            if line ~= "" then
                local ft, q, m = string.match(line, "^([^|]+)|(%d)|(%d)$")
                if ft then D.flips[ft] = { q = tonumber(q) % 4, m = m == "1" }
                end
            end
            line = r:readLine()
        end
        r:close()
    end)
end
function D.saveFlips()
    pcall(function()
        local w = getFileWriter(FLIP_FILE, true, false)
        w:write("#set=" .. iconSet() .. "\n")
        for k, v in pairs(D.flips) do
            if v.q ~= 0 or v.m then w:write(k .. "|" .. v.q .. "|" .. (v.m and 1 or 0) .. "\n") end
        end
        w:close()
    end)
end
function D.orient(item)
    if not D.flips then D.loadFlips() end
    local ok, ft = pcall(function() return item:getFullType() end)
    local o = ok and D.flips[ft]
    if o then return o.q, o.m end
    return 0, false
end
local function edit(item, fn)
    if not D.flips then D.loadFlips() end
    local ft = item:getFullType()
    local o = D.flips[ft] or { q = 0, m = false }
    fn(o)
    D.flips[ft] = o
    D.saveFlips()
    D.orientCache = {}
end
function D.rotateIcon(item, dq) edit(item, function(o) o.q = ((o.q + dq) % 4 + 4) % 4 end) end
function D.mirrorIcon(item) edit(item, function(o) o.m = not o.m end) end
function D.resetIcon(item) edit(item, function(o) o.q = 0; o.m = false end) end
function D.toggleFlip(item) D.rotateIcon(item, 2) end

local fhCache = {}
function D.fh(font)
    local v = fhCache[font]
    if not v then v = getTextManager():getFontHeight(font); fhCache[font] = v end
    return v
end

local infoCache, infoCount = {}, 0
function D.isFlipped(item) return item end

function D.icon(ui, tex, x, y, w, h, alpha, who, turns, tint)
    if not tex then return end
    local cr, cg, cb = 1, 1, 1
    if tint then cr, cg, cb = tint[1], tint[2], tint[3] end

    local ic = who and who ~= true and infoCache[who] or nil
    local tw, th
    if ic and ic.tex == tex and ic.tw then tw, th = ic.tw, ic.th else tw, th = tex:getWidth(), tex:getHeight() end
    if tw <= 0 or th <= 0 then return end
    turns = turns or 0

    local uq, um, base, cloth = 0, false, 0, false
    if who and who ~= true then
        local ft = (ic and ic.ft) or who:getFullType()
        D.orientCache = D.orientCache or {}
        local oc = D.orientCache[ft]
        if not oc or oc.tex ~= tex then
            local q, m = D.orient(who)
            local def = TGI.IconDefaults and TGI.IconDefaults[ft] or nil

            if def and rawget(_G, "ICONS3D_NORMALIZED") then def = nil end

            if def then
                local okn, nm = pcall(function() return tex:getName() end)
                if not (okn and nm and string.find(nm, "I3D_", 1, true)) then def = nil end
            end
            local b0 = 0
            if def then
                b0 = def[1]
                if def[2] then m = not m end
            end
            oc = { tex = tex, q = q, m = m, base = b0, cloth = instanceof(who, "Clothing") }
            D.orientN = (D.orientN or 0) + 1
            if D.orientN > 3000 then D.orientCache, D.orientN = {}, 0 end
            D.orientCache[ft] = oc
        end
        uq, um, base, cloth = oc.q, oc.m, oc.base, oc.cloth
    elseif who == true then uq = 2 end

    local vw0, vh0 = tw, th
    if base % 2 == 1 then vw0, vh0 = th, tw end
    local auto = false
    if not cloth then
        auto = (vh0 > vw0 * 1.15 and w > h * 1.15 and turns % 2 == 0) or (vw0 > vh0 * 1.15 and h > w * 1.15 and turns % 2 == 0)
            or (turns % 2 == 1 and ((vh0 > vw0 * 1.15 and h > w * 1.15) or (vw0 > vh0 * 1.15 and w > h * 1.15)))
    end
    local q = (base + (auto and 1 or 0) + turns + uq) % 4
    local vw, vh = tw, th
    if q % 2 == 1 then vw, vh = th, tw end
    local s = math.min(w / vw, h / vh)
    local dw, dh = vw * s, vh * s
    local ox, oy = x + (w - dw) / 2, y + (h - dh) / 2
    if q == 0 and not um then
        ui:drawTextureScaled(tex, ox, oy, dw, dh, alpha or 1, cr, cg, cb)
        return
    end

    local bx, by = ui:getAbsoluteX() + ox, ui:getAbsoluteY() + oy
    local c = { { bx, by }, { bx + dw, by }, { bx + dw, by + dh }, { bx, by + dh } }
    local p = {}
    for i = 0, 3 do p[i + 1] = c[((q + i) % 4) + 1] end
    if um then p = { p[2], p[1], p[4], p[3] } end

    local k = 1
    if ui.tgiAlphaApplied and TGI.Theme and TGI.Theme.uiAlpha then k = TGI.Theme.fadeOf(ui) * (tonumber(TGI.Theme.uiAlpha()) or 1) end
    ui.javaObject:DrawTexture(tex, p[1][1], p[1][2], p[2][1], p[2][2], p[3][1], p[3][2], p[4][1], p[4][2], cr, cg, cb, (alpha or 1) * k)
end

local tintCache, tintN = {}, 0
function D.iconTint(item)
    if instanceof(item, "Clothing") then return nil end
    local ft = item:getFullType()
    local v = tintCache[ft]
    if v == nil then
        v = false
        pcall(function()
            local si = item:getScriptItem()
            local r, g, b = si:getR(), si:getG(), si:getB()
            if r and (r < 0.99 or g < 0.99 or b < 0.99) then v = { r, g, b } end
        end)
        tintN = tintN + 1
        if tintN > 2000 then tintCache, tintN = {}, 1 end
        tintCache[ft] = v
    end
    return v or nil
end

function D.mark(ui, name, x, y, s, r, g, b, a)
    local t = D.tex(name)
    if not t then ui:drawRect(x, y, s, s, a, r, g, b); return end
    ui:drawTextureScaled(t, x + 1, y + 1, s, s, 0.85 * a, 0, 0, 0)
    ui:drawTextureScaled(t, x, y, s, s, a, r, g, b)
end

function D.freshState(item)
    if not instanceof(item, "Food") then return nil end
    local ok, st = pcall(function()
        if (tonumber(item:getOffAgeMax()) or 0) >= 1000000 then return nil end
        if item:isRotten() then return "rotten" end
        if not item:isFresh() then return "stale" end
        return nil
    end)
    return ok and st or nil
end
D.FRESH_COL = { stale = { 0.95, 0.8, 0.3 }, rotten = { 0.55, 0.75, 0.2 } }

function D.powerBadge(ui, item, x, y)
    if not item then return false end
    local can = false
    pcall(function() can = item:canBeActivated() end)
    if not can then return false end
    local on = false
    pcall(function() on = item:isActivated() end)
    local batt = nil
    pcall(function() if instanceof(item, "DrainableComboItem") then batt = item:getCurrentUsesFloat() end end)

    local s = 10
    if on then
        local pulse = 0.8 + 0.2 * math.abs(math.sin(getTimestampMs() / 400))
        D.mark(ui, "ic_power", x, y, s, 1, 0.85 * pulse + 0.1, 0.25, 1)
    else
        D.mark(ui, "ic_power", x, y, s, 0.55, 0.55, 0.55, 0.9)
    end
    if batt then

        ui:drawRect(x + s + 2, y + 3, 14, 5, 0.8, 0, 0, 0)
        local f = math.max(0, math.min(1, batt))
        ui:drawRect(x + s + 3, y + 4, 12 * f, 3, 0.9, 1 - f, 0.3 + 0.6 * f, 0.2)
    end
    return true
end

local nameCache, nameCount = {}, 0
function D.shortName(item, maxW, font, name)
    name = name or item:getDisplayName() or "?"
    local ck = name .. "|" .. maxW .. (T.ownFont() and ("j" .. tostring(TGI.Options.get("fontFace"))) or "")
    local hit = nameCache[ck]
    if hit then return hit end
    if nameCount > 4000 then nameCache, nameCount = {}, 0 end
    local res = D._short(name, maxW, font)
    nameCache[ck] = res; nameCount = nameCount + 1
    return res
end

function D.shortNameF(item, maxW, font, name)
    local F = TGI.Font
    name = name or item:getDisplayName() or "?"
    local ck = "F" .. tostring(TGI.Options.get("fontFace")) .. "|" .. name .. "|" .. maxW
    local hit = nameCache[ck]
    if hit then return hit end
    if nameCount > 4000 then nameCache, nameCount = {}, 0 end
    local res = name
    if F.width(res, font) > maxW then
        while #res > 2 and F.width(res .. "..", font) > maxW do res = string.sub(res, 1, #res - 1) end
        res = res .. ".."
    end
    nameCache[ck] = res; nameCount = nameCount + 1
    return res
end

function D._short(name, maxW, font)
    local tm = getTextManager()
    if T.measure(font, name) <= maxW then return name end
    while #name > 2 and T.measure(font, name .. "..") > maxW do
        name = string.sub(name, 1, #name - 1)
    end
    return name .. ".."
end

function D.progress(ui, x, y, w, h, frac)
    local bw, by = w - 8, y + h - 9
    ui:drawRect(x + 4, by, bw, 5, 0.9, 0, 0, 0)
    ui:drawRect(x + 4, by, bw * math.max(0.03, math.min(1, frac or 0)), 5, 0.95, T.accent.r, T.accent.g, T.accent.b)
    ui:drawRectBorder(x + 4, by, bw, 5, 0.8, 0.45, 0.45, 0.4)
end

local ACT_NAMES = {
    ISReloadWeaponAction = "IGUI_TGI_ActReload", ISInsertMagazine = "IGUI_TGI_ActInsertMag",
    ISEjectMagazine = "IGUI_TGI_ActEjectMag", ISLoadBulletsInMagazine = "IGUI_TGI_ActLoadMag",
    ISUnloadBulletsFromMagazine = "IGUI_TGI_ActUnloadMag", ISUnloadBulletsFromFirearm = "IGUI_TGI_ActUnloadMag",
    ISRackFirearm = "IGUI_TGI_ActRack", ISWearClothing = "IGUI_TGI_ActWear", ISUnequipAction = "IGUI_TGI_ActUnequip",
    ISEquipWeaponAction = "IGUI_TGI_ActEquip", ISInventoryTransferAction = "IGUI_TGI_ActMove",
    ISAttachItemHotbar = "IGUI_TGI_ActAttach", ISDetachItemHotbar = "IGUI_TGI_ActDetach",
    ISEatFoodAction = "IGUI_TGI_ActEat", ISDrinkFromBottle = "IGUI_TGI_ActDrink", ISApplyBandage = "IGUI_TGI_ActBandage",
    ISTakePillAction = "IGUI_TGI_ActPill", TGIBreakLockAction = "IGUI_TGI_ActForce", ISReadABook = "IGUI_TGI_ActRead",
}

function D.currentAction(p)
    if not p then return nil end
    local q = nil
    pcall(function() q = ISTimedActionQueue.getTimedActionQueue(p) end)
    local a = q and q.queue and q.queue[1]
    if not a or not a.action then return nil end
    local frac = nil

    local act = a.action
    if type(act) ~= "userdata" and type(act) ~= "table" then return nil end
    if not act.getJobDelta then return nil end
    pcall(function() frac = act:getJobDelta() end)
    if not frac then return nil end

    if D._actA ~= a then D._actA, D._actT0 = a, getTimestampMs() end
    if frac <= 0.001 then frac = math.min(0.95, (getTimestampMs() - D._actT0) / 700) end
    local key = a.Type and ACT_NAMES[a.Type]
    local name = key and getText(key) or tostring(a.Type or ""):gsub("^IS", ""):gsub("Action$", "")
    local item = a.item or a.gun or a.magazine or a.clothingItem or a.weapon

    if item and not instanceof(item, "InventoryItem") then item = nil end
    local gun = a.gun
    if gun and not instanceof(gun, "InventoryItem") then gun = nil end

    return { frac = frac, name = name, item = item, gun = gun, slotIndex = (a.Type == "ISAttachItemHotbar") and a.slotIndex or nil }
end

function D.ghost(ui, item, x, y, w, h, frac, rot)
    ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.5, 0.3, 0.3, 0.3)
    ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 0.7, 0.55, 0.55, 0.55)
    local ok, tex = pcall(function() return item:getTex() end)
    if ok and tex then D.icon(ui, tex, x + 4, y + 10, w - 8, h - 22, 0.35, D.isFlipped(item), rot and 1 or 0, D.iconTint(item)) end
    D.progress(ui, x, y, w, h, frac)
end

local KIND = { "IGUI_TGI_KWeapon", "IGUI_TGI_KAmmo", "IGUI_TGI_KMed", "IGUI_TGI_KFood", "IGUI_TGI_KFood",
    "IGUI_TGI_KTool", "IGUI_TGI_KCloth", "IGUI_TGI_KBag", "IGUI_TGI_KMisc", "IGUI_TGI_KMisc" }
function D.kindHint(item)
    local ok, g = pcall(function() return TGI.Model.groupOf(item) end)
    if not ok or not g then return nil end
    return getText(KIND[g] or "IGUI_TGI_KMisc")
end

function D.hiddenTile(ui, x, y, w, h, frac, qi, hint, rarityOf)
    ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.92, 0.03, 0.032, 0.032)
    if rarityOf and T.tierColor then
        local r, g, b = T.tierColor(rarityOf)
        ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 0.9, r, g, b)
        ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.12, r, g, b)
    else
        ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 0.7, 0.2, 0.2, 0.19)
    end
    local tm = getTextManager()
    local font = UIFont.Medium
    local fh = tm:getFontHeight(font)
    local a = 0.35
    if frac then

        a = 0.55 + 0.35 * math.abs(math.sin(getTimestampMs() / 180))
    end
    ui:drawTextCentre("?", x + w / 2, y + (h - fh) / 2, T.dim.r, T.dim.g, T.dim.b, a, font)
    if hint and h >= 30 then
        local s = D._short(hint, w - 6, UIFont.Small)
        ui:drawTextCentre(s, x + w / 2, y + h - 16, T.dim.r, T.dim.g, T.dim.b, 0.8, UIFont.Small)
    end
    if frac then D.progress(ui, x, y, w, h, frac) end
    if qi then
        ui:drawRect(x + 3, y + 3, 14, 14, 0.9, T.accent.r * 0.5, T.accent.g * 0.5, T.accent.b * 0.3)
        ui:drawTextCentre(tostring(qi), x + 10, y + 3, 1, 1, 1, 1, UIFont.Small)
    end
end

function D.info(item)
    local now = getTimestampMs()
    local c = infoCache[item]
    if c and now < c.t then return c end

    c = { t = now + 400 + ZombRand(250) }
    c.tex = safe(function() return item:getTex() end, nil)
    c.id = item:getID()
    c.ft = item:getFullType()
    if c.tex then c.tw, c.th = c.tex:getWidth(), c.tex:getHeight() end
    c.name = item:getDisplayName() or "?"
    c.lname = string.lower(c.name)
    c.fav = safe(function() return item:isFavorite() end, false)

    c.tint = D.iconTint(item)
    local cmax = safe(function() return item:getConditionMax() end, 0)
    if cmax and cmax > 0 then
        local cv = safe(function() return item:getCondition() end, cmax)
        c.cond = cv / cmax
        c.condTxt = cv .. "/" .. cmax
    end

    if instanceof(item, "HandWeapon") or (item.getMaxAmmo and safe(function() return item:getMaxAmmo() end, 0) > 0) then
        local mx = safe(function() return item:getMaxAmmo() end, 0)
        local ranged = not instanceof(item, "HandWeapon") or safe(function() return item:isRanged() end, false)
        if mx and mx > 0 and ranged then c.ammoTxt = safe(function() return item:getCurrentAmmoCount() end, 0) .. "/" .. mx end
    end
    c.use, c.ur, c.ug, c.ub = D.usage(item)

    if instanceof(item, "Food") then pcall(function() item:updateAge() end) end
    c.okT, c.tr, c.tg, c.tb, c.ts, c.frozen = pcall(D.temp, item)
    c.read, c.learn = D.knowState(item)
    c.uncollected = D.isUncollected(item)
    c.cook, c.cr, c.cg, c.cb, c.ckind = D.cookState(item)
    c.raw = D.rawState(item)
    c.fresh = D.freshState(item)

    c.unwanted = safe(function() return item:isUnwanted(getSpecificPlayer(0)) end, false) == true
    local okP, parts = pcall(D.weaponParts, item)
    c.nparts = (okP and parts) and #parts or 0

    c.vr, c.vg, c.vb = T.tileColor(item)
    c.wet, c.blood, c.dirt = 0, 0, 0
    if instanceof(item, "Clothing") then
        c.wet = D.pct(safe(function() return item:getWetness() end, 0))
        c.blood = D.pct(safe(function() return item:getBloodLevel() end, 0))
        c.dirt = D.pct(safe(function() return item:getDirtiness() end, 0))
    end
    if not infoCache[item] then
        infoCount = infoCount + 1
        if infoCount > 3017 then infoCache, infoCount = {}, 1 end
    end
    infoCache[item] = c
    return c
end
function D.forget(item) if item then infoCache[item] = nil end end

local function u(n) return math.floor(n * (T.SCALE or 1) + 0.5) end

D.arrivedAt = {}
local arrivedN = 0
function D.markArrived(item)
    if not (T.anim and T.anim()) then return end
    arrivedN = arrivedN + 1
    if arrivedN > 300 then D.arrivedAt, arrivedN = {}, 1 end
    D.arrivedAt[item:getID()] = getTimestampMs()
end
function D.tile(ui, entry, x, y, w, h, alpha, rot)
    local item = entry.item
    if arrivedN > 0 then
        local t0 = D.arrivedAt[item:getID()]
        if t0 then
            local k = (getTimestampMs() - t0) / 300
            if k >= 1 then D.arrivedAt[item:getID()] = nil
            else
                local s = T.outBack(k)
                local ins = math.floor((1 - s) * math.min(w, h) * 0.22 + 0.5)
                x, y, w, h = x + ins, y + ins, w - ins * 2, h - ins * 2
                alpha = (alpha or 1) * (0.2 + 0.8 * T.outCubic(math.min(1, k * 1.6)))
            end
        end
    end
    local age = TGI.Search and TGI.Search.revealAge(item)
    if age and age < 0.2 then

        local k = age / 0.2
        local cw = math.max(2, math.floor(w * k))
        if k < 0.5 then
            D.hiddenTile(ui, x + (w - cw) / 2, y, cw, h)
            return
        end
    end
    local A = alpha or 1
    local info = D.info(item)
    local r, g, b = info.vr, info.vg, info.vb
    local font = T.FONT_TINY
    if T.modern() then

        ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.92 * A, 0.3, 0.31, 0.3)
        ui:drawRect(x + 2, y + 2, w - 4, h - 4, 0.94 * A, 0.045 + (r - 0.045) * 0.24, 0.047 + (g - 0.047) * 0.24, 0.047 + (b - 0.047) * 0.24)
        D.icon(ui, info.tex, x + 4, y + 10, w - 8, h - 14, alpha, D.isFlipped(item), rot and 1 or 0, info.tint)
        if not D.noLabel then
            local F = TGI.Font
            if F then ui:drawTextRight(D.shortNameF(item, w - 6, font, info.name), x + w - 3, y + 1, T.text.r, T.text.g, T.text.b, 0.9 * A, font)
            else ui:drawTextRight(D.shortName(item, w - 6, font, info.name), x + w - 3, y + 1, T.text.r, T.text.g, T.text.b, 0.9 * A, font) end
        end
    else

    ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.9 * A, r * 0.6 + 0.16, g * 0.6 + 0.16, b * 0.6 + 0.16)
    ui:drawRect(x + 2, y + 2, w - 4, h - 4, 0.92 * A, 0.035 + (r - 0.035) * 0.16, 0.037 + (g - 0.037) * 0.16, 0.037 + (b - 0.037) * 0.16)
    D.icon(ui, info.tex, x + 4, y + 12, w - 8, h - 16, alpha, D.isFlipped(item), rot and 1 or 0, info.tint)
    if not D.noLabel then

        local nm = (TGI.Font and T.ownFont()) and D.shortNameF(item, w - 6, font, info.name) or D.shortName(item, w - 6, font, info.name)
        ui:drawText(nm, x + 3, y + 1, T.text.r, T.text.g, T.text.b, 0.95 * (alpha or 1), font)
    end
    end

    if entry.items and #entry.items > 1 then
        local cf = T.FONT_COUNT or UIFont.Small
        ui:drawTextRight(tostring(#entry.items), x + w - 4, y + h - D.fh(cf) - 1, T.accent.r, T.accent.g, T.accent.b, alpha or 1, cf)
    end

    local cond = info.cond
    local use, ur, ug, ub = info.use, info.ur, info.ug, info.ub
    local bw = w - 8
    local by = y + h - 5

    if T.modern() and (info.ammoTxt or (cond and cond < 0.999)) and not (entry.items and #entry.items > 1) then
        local t = info.ammoTxt or info.condTxt
        local cf = T.FONT_TINY
        local fh = D.fh(cf)
        local cr, cg, cb = T.accent.r, T.accent.g, T.accent.b
        if not info.ammoTxt then cr, cg, cb = 1 - cond * 0.4, 0.45 + cond * 0.5, 0.35 end
        ui:drawRect(x + w - 4 - T.measure(cf, t) - 3, y + h - fh - 2, T.measure(cf, t) + 5, fh, 0.55 * A, 0, 0, 0)
        ui:drawTextRight(t, x + w - 4, y + h - fh - 2, cr, cg, cb, A, cf)
        cond = nil
        by = y + h - fh - 6
    end
    if cond and cond < 0.999 then
        cond = math.max(0, math.min(1, cond))
        ui:drawRect(x + 4, by, bw, u(3), 0.8, 0, 0, 0)
        ui:drawRect(x + 4, by, bw * cond, u(3), 0.9, 1 - cond, cond, 0.15)
        by = by - u(4)
    end
    if use then
        use = math.max(0, math.min(1, use))
        ui:drawRect(x + 4, by, bw, u(3), 0.8, 0, 0, 0)
        ui:drawRect(x + 4, by, bw * use, u(3), 0.95, ur, ug, ub)
        by = by - u(4)
    end

    local sx = x + w - 3 - u(11)
    if info.fresh then
        local fc = D.FRESH_COL[info.fresh]
        D.mark(ui, info.fresh == "rotten" and "ic_infect" or "ic_clock", sx, y + h - 5 - u(19), u(11), fc[1], fc[2], fc[3], A or 1)
        sx = sx - u(12)
    end
    if info.raw then
        local rc = D.RAW_COL[info.raw]
        D.mark(ui, info.raw == "burnt" and "ic_burn" or "ic_food", sx, y + h - 5 - u(19), u(11), rc[1], rc[2], rc[3], A or 1)
    end

    if info.cook then
        local f = math.max(0, math.min(1, info.cook))
        ui:drawRect(x + 4, by - 1, bw, 4, 0.85, 0, 0, 0)
        ui:drawRect(x + 4, by, bw * f, 3, A or 1, info.cr, info.cg, info.cb)
    end

    local okT, tr, tg, tb, ts, frozen = info.okT, info.tr, info.tg, info.tb, info.ts, info.frozen
    if okT and tr then
        local hot = tr > tb

        local fx = (hot or frozen) and D.tex(hot and "fx_heat" or "fx_frost") or nil
        local k = 0.35 + 0.65 * ts
        if frozen then
            ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 0.95 * A, 0.7, 0.9, 1)
            ui:drawRectBorder(x + 2, y + 2, w - 4, h - 4, 0.5 * A, 0.7, 0.9, 1)
        end
        if fx then
            local a = (hot and 0.55 or 0.75) * k * A
            if hot then a = a * (0.85 + 0.15 * math.sin(getTimestampMs() / 260)) end
            ui:drawTextureScaled(fx, x + 1, y + 1, w - 2, h - 2, a, tr, tg, tb)
        end
        local ic = D.tex(hot and "temp_hot" or "temp_cold")
        if ic then ui:drawTextureScaled(ic, x + 3, y + h - 5 - u(12), u(12), u(12), 0.95 * A, tr, tg, tb) end
    end

    local learn = info.learn
    if learn and TGI.Options.get("learnMarks") ~= false then
        local col = D.LEARN_COL[learn] or D.LEARN_COL.book
        local ic = D.tex("ic_k_" .. learn)
        ui:drawRect(x + w - 2 - u(14), y + h - 2 - u(14), u(14), u(14), 0.85 * A, 0.02, 0.02, 0.02)
        if ic then ui:drawTextureScaled(ic, x + w - 1 - u(14), y + h - 1 - u(14), u(12), u(12), A, col[1], col[2], col[3])
        else ui:drawRect(x + w - u(14), y + h - u(14), u(10), u(10), A, col[1], col[2], col[3]) end
    end

    if info.uncollected then
        local ic = D.tex("ic_k_new")
        if ic then
            ui:drawTextureScaled(ic, x + w - 2 - u(10), y + 3, u(10), u(10), 0.8 * A, 0, 0, 0)
            ui:drawTextureScaled(ic, x + w - 3 - u(10), y + 2, u(10), u(10), A, 1, 0.95, 0.6)
        end
    end
    if okT ~= nil and not learn then
        local read = info.read
        if read then
            local tick = D._tick or getTexture("media/ui/Tick_Mark-10.png")
            D._tick = tick
            if tick then
                ui:drawRect(x + w - 2 - u(13), y + h - 2 - u(13), u(13), u(13), 0.75 * A, 0.02, 0.02, 0.02)
                ui:drawTextureScaled(tick, x + w - 3 - u(11), y + h - 3 - u(11), u(11), u(11), A, read == "part" and 1 or 0.45, read == "part" and 0.8 or 1, 0.45)
            end
        end
    end

    if info.nparts > 0 then
        local t = "+" .. info.nparts
        local tw = T.measure(UIFont.Small, t)
        ui:drawRect(x + w - tw - 8, y + 13, tw + 5, 14, 0.85 * A, 0.02, 0.02, 0.02)
        ui:drawText(t, x + w - tw - 5, y + 12, T.accent.r, T.accent.g, T.accent.b, A, UIFont.Small)
    end

    local fl = TGI.Actions and TGI.Actions.inflightFor(item)
    if fl then
        ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.55, 0.08, 0.08, 0.08)
        D.progress(ui, x, y, w, h, TGI.Actions.progress(item))
    end

    local mk = y + 14
    local wet, blood, dirt = info.wet, info.blood, info.dirt
    if wet > 0.03 then D.mark(ui, "ic_drop", x + 2, mk, u(9), 0.35, 0.65, 1, 1); mk = mk + u(10) end
    if blood > 0.05 then D.mark(ui, "ic_drop", x + 2, mk, u(9), 0.85, 0.12, 0.1, 1); mk = mk + u(10) end
    if dirt > 0.05 then D.mark(ui, "ic_dirt", x + 2, mk, u(9), 0.6, 0.42, 0.2, 1) end

    if age then
        local ga = (1 - age) * 0.9
        ui:drawRectBorder(x + 1, y + 1, w - 2, h - 2, ga, r, g, b)
        ui:drawRectBorder(x + 2, y + 2, w - 4, h - 4, ga * 0.7, r, g, b)
        ui:drawRect(x + 1, y + 1, w - 2, h - 2, ga * 0.18, r, g, b)
    end
    if info.unwanted then ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.55, 0.02, 0.02, 0.02) end

    if D.catFilter and TGI.Model and TGI.Model.groupOf then
        local id = info.id or item:getID()
        D._grp = D._grp or {}
        local g = D._grp[id]
        if not g then g = TGI.Model.groupOf(item); D._grp[id] = g end
        local hit = false
        for c in pairs(D.catFilter) do if c.groups[g] or (c.match and c.match(item)) then hit = true; break end end
        if not hit then
            ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.72, 0.01, 0.01, 0.01)
        end
    end

    if D.filter and D.filter ~= "" then
        if not string.find(D.info(item).lname, D.filter, 1, true) then
            ui:drawRect(x + 1, y + 1, w - 2, h - 2, 0.72, 0.01, 0.01, 0.01)
        else
            ui:drawRectBorder(x, y, w, h, 1, 1, 0.85, 0.3)
        end
    end

    if D.info(item).fav then
        ui:drawText("*", x + w - 10, y + 1, 1, 0.85, 0.3, 1, UIFont.Small)
    end
end

D._tex = {}
function D.tex(name)
    local t = D._tex[name]
    if t == nil then t = getTexture("media/textures/TGI/" .. name .. ".png") or false; D._tex[name] = t end
    return t or nil
end

function D.weaponParts(item)
    local out = {}
    if not (instanceof(item, "HandWeapon") and item.getAllWeaponParts) then return out end
    local list = item:getAllWeaponParts()
    if list and list.size then
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    end
    return out
end

function D.isRead(item)
    local r = D.knowState(item)
    return r
end

D.LEARN_COL = { book = { 1, 0.8, 0.25 }, recipe = { 0.4, 0.9, 0.4 }, research = { 0.4, 0.9, 0.4 }, media = { 0.4, 0.7, 1 }, map = { 0.9, 0.65, 0.4 } }

local SKILL_CODE = { SPR = "Sprinting", LFT = "Lightfooted", NIM = "Nimble", SNE = "Sneaking", BAA = "Axe",
    BUA = "Blunt", CRP = "Carpentry", COO = "Cooking", FRM = "Farming", DOC = "Doctor", ELC = "Electricity",
    MTL = "MetalWelding", FKN = "FlintKnapping", CRV = "Carving", AIM = "Aiming", REL = "Reloading",
    FIS = "Fishing", TRA = "Trapping", FOR = "Foraging", TAI = "Tailoring", MEC = "Mechanics", CMB = "Combat",
    SPE = "Spear", SBU = "SmallBlunt", LBA = "LongBlade", SBA = "SmallBlade", MAS = "Masonry", POT = "Pottery",
    BLA = "Blacksmith", GLA = "Glassmaking", HUS = "Husbandry", BUT = "Butchering", TRK = "Tracking" }
local mediaSkillCache = {}
function D.mediaSkills(item)
    local md = item.getMediaData and safe(function() return item:getMediaData() end, nil)
    if not md then return nil end
    local id = safe(function() return md:getId() end, nil)
    if id and mediaSkillCache[id] ~= nil then return mediaSkillCache[id] or nil end
    local seen, out = {}, {}
    pcall(function()
        for i = 0, md:getLineCount() - 1 do
            local codes = md:getLine(i):getCodes()
            if codes then
                for code in string.gmatch(tostring(codes), "(%u%u%u)[%+%-]?%d*") do
                    local k = SKILL_CODE[code]
                    if k and not seen[k] then
                        seen[k] = true
                        out[#out + 1] = getText("IGUI_perks_" .. k)
                    end
                end
            end
        end
    end)
    local r = #out > 0 and table.concat(out, ", ") or nil
    if id then mediaSkillCache[id] = r or false end
    return r
end

function D.knowState(item)
    local p = getSpecificPlayer(0)
    if not p then return nil, nil end
    local read, learn = nil, nil
    pcall(function()
        local isLit = instanceof(item, "Literature")
        local ft = item:getFullType()
        local md = item:hasModData() and item:getModData() or nil

        if item.getMediaData and item:getMediaData() then
            if (item.hasBeenSeen and item:hasBeenSeen(p)) or (item.hasBeenHeard and item:hasBeenHeard(p)) then read = true

            else learn = D.mediaSkills(item) and "book" or "media" end
            return
        end

        if instanceof(item, "MapItem") then
            if p:hasReadMap(item) then read = true else learn = "map" end
            return
        end
        if isLit then

            if md then
                if md.literatureTitle and p:isLiteratureRead(md.literatureTitle) then read = true; return end
                if md.printMedia and md.printMedia.title and p.isPrintMediaRead and p:isPrintMediaRead(md.printMedia.title) then read = true; return end
                if md.learnedRecipe then
                    if p:getKnownRecipes():contains(md.learnedRecipe) then read = true; return end
                    learn = "recipe"
                end
            end

            local sb = SkillBook and SkillBook[item:getSkillTrained()]
            if sb and sb.perk and item:getMaxLevelTrained() < p:getPerkLevel(sb.perk) + 1 then read = true; return end
            local lr = item:getLearnedRecipes()
            if lr and not lr:isEmpty() then
                if p:getKnownRecipes():containsAll(lr) then read = true; return end
                learn = "recipe"
            end

            local hbr = p:getModData().P4HasBeenRead
            local key = (md and md.literatureTitle) or ft
            if hbr and hbr.markedMap and hbr.markedMap[key] then read = true; learn = nil; return end
            local pages = item.getNumberOfPages and item:getNumberOfPages() or 0
            if pages and pages > 0 then
                local done = p:getAlreadyReadPages(ft) or 0
                if done >= pages then read = true; learn = nil; return end
                if done > 0 then read = "part"
                elseif sb and sb.perk and not learn then learn = "book" end
            end
            return
        end

        local si = item:getScriptItem()
        if si and si.getResearchableRecipes then
            local list = si:getResearchableRecipes(p, true)
            if list and list:size() > 0 then learn = "research" end
        end
    end)
    return read, learn
end

local function collectible(item)
    return instanceof(item, "Literature") or instanceof(item, "MapItem")
        or (item.getMediaData and item:getMediaData() ~= nil)
end
local function collectedKey(item)
    local md = item:hasModData() and item:getModData() or nil

    if md and md.literatureTitle then return md.literatureTitle end
    if item.getMediaData then
        local m = item:getMediaData()
        if m and m.getId then return "media:" .. tostring(m:getId()) end
    end
    return item:getFullType()
end
function D.collectedTable(p)
    p = p or getSpecificPlayer(0)
    if not p then return nil end
    local md = p:getModData()
    md.TGICollected = md.TGICollected or {}
    return md.TGICollected
end
function D.isUncollected(item)
    if TGI.Options.get("collectMarks") == false then return false end
    local ok, res = pcall(function()
        if not collectible(item) then return false end
        local p = getSpecificPlayer(0)
        if not p then return false end
        if item:isInPlayerInventory() then return false end
        local t = D.collectedTable(p)
        return t[collectedKey(item)] == nil
    end)
    return ok and res == true
end

local nextCollect = 0
local function collectTick()
    local now = getTimestampMs()
    if now < nextCollect then return end
    nextCollect = now + 2000
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local t = D.collectedTable(p)
    local function scan(inv, depth)
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if collectible(it) then
                local k = collectedKey(it)
                if not t[k] then t[k] = true; D.forget(it) end
            elseif depth < 2 and instanceof(it, "InventoryContainer") then
                scan(it:getInventory(), depth + 1)
            end
        end
    end
    pcall(scan, p:getInventory(), 0)
end
Events.OnTick.Add(collectTick)

function D.cookState(item)
    if not instanceof(item, "Food") or TGI.Options.get("cookBar") == false then return nil end
    local ok, f, r, g, b, kind = pcall(function()
        if item:isBurnt() then return nil end
        if item:isFrozen() and item:isThawing() then
            return 1 - (item:getFreezingTime() or 0) / 100, 0.45, 0.75, 1, "thaw"
        end

        local fz = tonumber(item:getFreezingTime()) or 0
        if fz > 0 and fz < 100 and (item:getCookingTime() or 0) <= 0 then
            return fz / 100, 0.45, 0.75, 1, "freeze"
        end
        if not item:isCookable() then return nil end
        local t = item:getCookingTime() or 0
        if t <= 0 then return nil end
        local mc, mb = item:getMinutesToCook() or 0, item:getMinutesToBurn() or 0
        if not item:isCooked() then
            if mc <= 0 then return nil end
            return t / mc, 1, 0.6, 0.2, "cook"
        end

        local c = item:getContainer()
        local hot = c and c.isActive and c:isActive() and (c:getTemperature() or 1) > 1
        if not hot or mb <= mc then return nil end
        local k = (t - mc) / (mb - mc)
        return k, 0.4 + 0.6 * k, 0.85 - 0.6 * k, 0.3, "burn"
    end)
    if ok and f then return f, r, g, b, kind end
    return nil
end

function D.rawState(item)
    if not instanceof(item, "Food") or TGI.Options.get("cookBar") == false then return nil end
    local ok, st = pcall(function()
        if item:isBurnt() then return "burnt" end
        if not item:isCookable() or item:isCooked() then return nil end
        if item.isbDangerousUncooked and item:isbDangerousUncooked() then return "rawbad" end
        return "raw"
    end)
    return ok and st or nil
end
D.RAW_COL = { raw = { 0.95, 0.6, 0.55 }, rawbad = { 1, 0.35, 0.3 }, burnt = { 0.55, 0.45, 0.4 } }

function D.fluidOf(item)
    local fc = nil
    pcall(function() fc = item:getFluidContainer() end)
    if fc then return fc end
    pcall(function()
        local wi = item:getWorldItem()
        if wi and wi.getFluidContainer then fc = wi:getFluidContainer() end
    end)
    return fc
end

function D.temp(item)
    local isFood = instanceof(item, "Food")
    if not isFood then
        local fc = D.fluidOf(item)
        if not (fc and fc.getCapacity and (fc:getCapacity() or 0) > 0) then return nil end
    end
    local heat = 1
    if (isFood or instanceof(item, "DrainableComboItem")) and item.getHeat then heat = item:getHeat() or 1
    elseif item.getItemHeat then heat = item:getItemHeat() or 1 end

    if heat > 1.05 then return 1, 0.4, 0.2, math.min(1, (heat - 1) / 1.0) end
    if isFood and item.isFrozen and item:isFrozen() then return 0.75, 0.9, 1, 1, true end
    if heat < 0.95 then return 0.35, 0.65, 1, math.min(1, (1 - heat) / 0.6) end
    return nil
end

function D.pct(v)
    v = tonumber(v) or 0
    if v > 1 then v = v / 100 end
    return math.max(0, math.min(1, v))
end

function D.usage(item)
    if safe(function() return instanceof(item, "DrainableComboItem") end, false) then
        local u = safe(function() return item:getCurrentUsesFloat() end, nil)
        if u and u < 0.999 then return u, 0.95, 0.8, 0.2 end
        return nil
    end
    local fc = D.fluidOf(item)
    if fc then
        local cap = safe(function() return fc:getCapacity() end, 0)
        if cap and cap > 0 then
            local amt = safe(function() return fc:getAmount() end, 0)
            return amt / cap, 0.3, 0.6, 1
        end
    end
    if safe(function() return instanceof(item, "Food") end, false) then
        local base = safe(function() return item:getBaseHunger() end, 0)
        local cur = safe(function() return item:getHungChange() end, 0)
        if base and base < 0 and cur then
            local f = cur / base
            if f < 0.999 then return f, 0.6, 0.85, 0.3 end
        end
    end
    return nil
end

return D
