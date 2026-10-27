require "ISUI/ISUIElement"
require "TGI/TGI_Theme"
require "TGI/TGI_BodyMap"

TGI = TGI or {}
local H = { treatments = {}, consumables = {}, injuries = {}, listeners = {} }
TGI.Health = H
local T = TGI.Theme

local function opt() return not TGI.Options or TGI.Options.get("healthOverlay") ~= false end
local function tr(k, ...) return getText("IGUI_TGI_H_" .. k, ...) end
local function call(o, name, d)
    if o and o[name] then local ok, v = pcall(o[name], o); if ok then return v end end
    return d
end

local TEX = {}
local function tex(n)
    if TEX[n] == nil then TEX[n] = getTexture("media/textures/TGI/" .. n .. ".png") or false end
    return TEX[n] or nil
end

local R = {
    Head        = { 0.40, 0.03, 0.60, 0.16 },
    Neck        = { 0.44, 0.16, 0.56, 0.20 },
    Torso_Upper = { 0.35, 0.20, 0.65, 0.37 },
    Torso_Lower = { 0.36, 0.37, 0.64, 0.48 },
    Groin       = { 0.38, 0.48, 0.62, 0.54 },
    UpperArm_R  = { 0.24, 0.21, 0.35, 0.35 },
    ForeArm_R   = { 0.19, 0.35, 0.32, 0.47 },
    Hand_R      = { 0.15, 0.47, 0.29, 0.56 },
    UpperLeg_R  = { 0.37, 0.54, 0.50, 0.71 },
    LowerLeg_R  = { 0.38, 0.71, 0.49, 0.87 },
    Foot_R      = { 0.36, 0.87, 0.49, 0.96 },
}
do
    local mir = {}
    for k, v in pairs(R) do
        if string.sub(k, -2) == "_R" then mir[string.sub(k, 1, -3) .. "_L"] = { 1 - v[3], v[2], 1 - v[1], v[4] } end
    end
    for k, v in pairs(mir) do R[k] = v end
end
H.REGIONS = R

H.ORDER = { "Hand_R", "Hand_L", "Foot_R", "Foot_L", "Neck", "Head", "ForeArm_R", "ForeArm_L", "UpperArm_R", "UpperArm_L",
            "LowerLeg_R", "LowerLeg_L", "UpperLeg_R", "UpperLeg_L", "Groin", "Torso_Lower", "Torso_Upper" }
local NO_SPLINT = { Head = true, Neck = true, Torso_Upper = true, Torso_Lower = true, Groin = true }

local function sortp(list) table.sort(list, function(a, b) return (a.priority or 100) > (b.priority or 100) end) end
local function reg(list, def)
    if type(def) ~= "table" or not def.id then return end
    for i = #list, 1, -1 do if list[i].id == def.id then table.remove(list, i) end end
    list[#list + 1] = def
    sortp(list)
    H._stamp = (H._stamp or 0) + 1
end
function H.registerTreatment(def) reg(H.treatments, def) end
function H.registerConsumable(def) reg(H.consumables, def) end
function H.registerInjury(def) reg(H.injuries, def) end
function H.onTreat(fn) if type(fn) == "function" then H.listeners[#H.listeners + 1] = fn end end
local function notify(kind, item, bp, p, id)
    for _, fn in ipairs(H.listeners) do pcall(fn, kind, item, bp, p, id) end
end

local function typ(it) return it:getType() end
local function tag(it, name)
    if not ItemTag or not ItemTag[name] then return false end
    local ok, v = pcall(it.hasTag, it, ItemTag[name])
    return ok and v
end
H.is = {}
local IS = H.is
function IS.bandage(it) return call(it, "getBandagePower", 0) > 0 end
function IS.cleanBandage(it) return call(it, "getBandagePower", 0) >= 2 end
function IS.alcohol(it)
    local fc = call(it, "getFluidContainer")
    if fc then
        local amt = call(fc, "getAmount", 0)
        if amt <= 0.15 then return false end
        local ok, alc = pcall(function() return fc:getProperties():getAlcohol() end)
        return ok and alc and (alc / amt + 0.001 >= 0.4) or false
    end
    return call(it, "IsDrainable", false) and call(it, "getAlcoholPower", 0) == 4.0
end
function IS.tweezers(it) local t = typ(it); return t == "Tweezers" or t == "SutureNeedleHolder" end
function IS.glassTool(it) return IS.tweezers(it) or tag(it, "REMOVE_GLASS") end
function IS.bulletTool(it) return IS.tweezers(it) or tag(it, "REMOVE_BULLET") end
function IS.suture(it) return typ(it) == "SutureNeedle" end
function IS.needle(it) return typ(it) == "Needle" or tag(it, "SEWING_NEEDLE") end
function IS.thread(it) return (typ(it) == "Thread" or tag(it, "THREAD")) and call(it, "getCurrentUsesFloat", 1) > 0 end
function IS.splint(it) return typ(it) == "Splint" end
local PLANK = { Plank = true, TreeBranch2 = true, WoodenStick2 = true, TreeBranch = true, WoodenStick = true }
function IS.plank(it) return PLANK[typ(it)] == true end
function IS.sheet(it) return typ(it) == "RippedSheets" end
function IS.pill(it) return tag(it, "CONSUMABLE") and instanceof(it, "DrainableComboItem") end
function IS.food(it)
    if it:getCategory() ~= "Food" then return false end
    local s = it:getScriptItem()
    return not (s and s:isCantEat() and not s:getOpeningRecipe())
end
function IS.drink(it)
    local fc = call(it, "getFluidContainer")
    if not fc or call(fc, "isEmpty", false) or call(fc, "getAmount", 0) <= 0 then return false end
    if call(fc, "getCapacity", 0) > 3.0 then return false end
    if call(it, "isWaterSource", false) then return true end
    local ok, good = pcall(function()
        local f = fc:getPrimaryFluid()
        return f and f:isCategory(FluidCategory.Beverage)
    end)
    return ok and good or false
end

local findCache, findT, findN = {}, 0, 0
function H.find(p, key, fn)
    local now = getTimestampMs()
    if now - findT > 600 or findN > 60 then findCache, findT, findN = {}, now, 0 end
    local c = findCache[key]
    if c ~= nil then return c or nil end
    local ok, it = pcall(function()
        return p:getInventory():getFirstEvalRecurse(function(i) return fn(i) end)
    end)
    it = ok and it or nil
    findCache[key] = it or false
    findN = findN + 1
    return it
end

local function bp(p, name)
    local t = BodyPartType[name]
    if not t then return nil end
    local ok, v = pcall(function() return p:getBodyDamage():getBodyPart(t) end)
    return ok and v or nil
end
H.bodyPart = bp

local function readPart(p, part, name)
    local s = { name = name, part = part, icons = {}, lines = {}, advice = {} }
    local sev, minor = false, false
    local function add(icon, text, severe, advice)
        s.icons[#s.icons + 1] = icon
        s.lines[#s.lines + 1] = { text, severe }
        if advice then s.advice[#s.advice + 1] = advice end
        if severe then sev = true else minor = true end
    end
    local bandaged = call(part, "bandaged", false)
    local stitched = call(part, "stitched", false)
    if call(part, "bleeding", false) and not bandaged then add("ic_drop", tr("Bleeding"), true, "bandage") end
    if call(part, "bitten", false) then add("ic_bite", tr("Bite"), true, bandaged and nil or "bandage") end
    if call(part, "haveGlass", false) then add("ic_glass", tr("Glass"), true, "glass") end
    if call(part, "haveBullet", false) then add("ic_bullet", tr("Bullet"), true, "bullet") end
    if call(part, "deepWounded", false) and not stitched then add("ic_stitch", tr("DeepWound"), true, "stitch") end
    if call(part, "getFractureTime", 0) > 0 then
        if call(part, "getSplintFactor", 0) > 0 then add("ic_splint", tr("Splinted"), false)
        else add("ic_fracture", tr("Fracture"), true, not NO_SPLINT[name] and "splint" or nil) end
    end
    if call(part, "getBurnTime", 0) > 0 then
        add("ic_burn", tr("Burn"), not bandaged, call(part, "isNeedBurnWash", false) and "wash" or (not bandaged and "bandage" or nil))
    end
    if call(part, "isCut", false) and not bandaged then add("ic_scratch", tr("Laceration"), false, "bandage") end
    if call(part, "scratched", false) and not bandaged then add("ic_scratch", tr("Scratch"), false, "bandage") end
    if call(part, "isInfectedWound", false) then add("ic_infect", tr("Infected"), true, "disinfect") end
    if stitched then add("ic_stitch", tr("Stitched"), false) end
    if bandaged then
        if call(part, "isBandageDirty", false) then add("ic_bandage", tr("DirtyBandage"), false, "rebandage")
        else add("ic_bandage", tr("Bandaged"), false) end
    end
    for _, inj in ipairs(H.injuries) do
        local ok, hit = pcall(inj.test, part, p)
        if ok and hit then
            local okT, txt = pcall(inj.text or function() return inj.id end, part)
            local okA, adv = pcall(inj.advice or function() return nil end, part)
            add(inj.icon or "ic_med", okT and txt or inj.id, inj.severe and true or false, okA and adv or nil)
        end
    end
    if call(part, "HasInjury", false) and not bandaged and #s.advice > 0 then

        local hasDis = false
        for _, a in ipairs(s.advice) do if a == "disinfect" then hasDis = true end end
        if not hasDis and call(part, "getAlcoholLevel", 1) <= 0 then s.advice[#s.advice + 1] = "disinfect" end
    end
    s.health = call(part, "getHealth", 100)

    pcall(function()
        local t = BodyPartType.FromString(name)
        local idx = BodyPartType.ToIndex(t)
        s.bite = math.floor((tonumber(p:getBodyPartClothingDefense(idx, true, false)) or 0) + 0.5)
        s.scratch = math.floor((tonumber(p:getBodyPartClothingDefense(idx, false, false)) or 0) + 0.5)
        s.bullet = math.floor((tonumber(p:getBodyPartClothingDefense(idx, false, true)) or 0) + 0.5)
        local th = p:getBodyDamage():getThermoregulator()
        local node = th and th:getNodeForType(t)
        if node then s.insul = math.floor((tonumber(node:getInsulation()) or 0) * 100 + 0.5) end
    end)
    s.severe, s.minor = sev, minor
    s.hurt = sev or minor or s.health < 99
    s.treated = bandaged or stitched or call(part, "getSplintFactor", 0) > 0
    return s
end

function H.state(p)
    local now = getTimestampMs()
    if H._st and H._stP == p and now - H._stT < 250 and H._stS == H._stamp then return H._st end
    local st = {}
    for _, name in ipairs(H.ORDER) do
        local part = bp(p, name)
        if part then st[name] = readPart(p, part, name) end
    end
    H._st, H._stP, H._stT, H._stS = st, p, now, H._stamp
    return st
end
function H.invalidate() H._st = nil; findCache = {} end

H.FIT = { top = 0.095, bottom = 0.95, cx = 0.5, w = 1.07 }
local DIR8 = { S = true, SW = true, W = true, NW = true, N = true, NE = true, E = true, SE = true }
local OLD = { S = "front", N = "back" }
function H.view(dir)
    dir = dir or "S"
    if TGI.BodyMap then return DIR8[dir] and dir or nil end
    return OLD[dir]
end
local function maps(view, sex)
    local bm = TGI.BodyMap
    local s = bm and (bm[sex or "m"] or bm.m)
    return s and s[view] or nil
end

H.FIT2 = { top = 0.02, bottom = 0.98, cx = 0.5, w = 1.0 }
function H.frame(w, h)
    local F = H.mode2d and H.FIT2 or H.FIT
    local fh = (F.bottom - F.top) * h
    local fw = fh * 0.4 * (F.w or 1)

    local maxW = w * 0.99
    if fw > maxW then
        local k = maxW / fw

        fw, fh = maxW, math.min(fh, fh * k * 1.12)
        return F.cx * w - fw / 2, (h - fh) / 2, fw, fh
    end
    return F.cx * w - fw / 2, F.top * h, fw, fh
end

function H.rect(name, w, h, dir, sex)
    local view = H.view(dir)
    local mp = view and maps(view, sex)
    if mp then
        local b = mp.parts[name]
        if not b then return nil end
        local fx, fy, fw, fh = H.frame(w, h)
        return fx + b[1] * fw, fy + b[2] * fh, (b[3] - b[1]) * fw, (b[4] - b[2]) * fh
    end

    local r = R[name]
    if not r or not view then return nil end
    local x1, x2 = r[1], r[3]
    if view == "back" or view == "N" then x1, x2 = 1 - r[3], 1 - r[1] end
    return x1 * w, r[2] * h, (x2 - x1) * w, (r[4] - r[2]) * h
end

function H.center(name, w, h, dir, sex)
    local view = H.view(dir)
    local mp = view and maps(view, sex)
    local b = mp and mp.parts[name]
    if b then
        local fx, fy, fw, fh = H.frame(w, h)
        return fx + b[5] * fw, fy + b[6] * fh
    end
    local x, y, rw, rh = H.rect(name, w, h, dir, sex)
    if x then return x + rw / 2, y + rh / 2 end
    return nil
end
function H.partAt(lx, ly, w, h, dir, sex)
    local view = H.view(dir)
    if not view then return nil end
    local mp = maps(view, sex)
    if mp then
        local fx, fy, fw, fh = H.frame(w, h)
        local cx, cy = (lx - fx) / fw, (ly - fy) / fh
        if cx < 0 or cy < 0 or cx >= 1 or cy >= 1 then return nil end
        local row = mp.map[math.floor(cy * #mp.map) + 1]
        if not row then return nil end
        local col = math.floor(cx * string.len(row)) + 1
        local c = string.byte(row, col)
        if not c or c == 46 then return nil end
        return mp.names[c - 48]
    end
    for _, name in ipairs(H.ORDER) do
        local x, y, rw, rh = H.rect(name, w, h, dir, sex)
        if x and lx >= x and ly >= y and lx < x + rw and ly < y + rh then return name end
    end
    return nil
end
local PT = {}
local function partTex(sex, view, name, kind)
    local k = sex .. view .. name .. kind
    if PT[k] == nil then PT[k] = getTexture("media/textures/TGI/body/" .. sex .. "_" .. view .. "_" .. name .. "_" .. kind .. ".png") or false end
    return PT[k] or nil
end
H.partTex = partTex

local function toInv(p, it) if it then ISInventoryPaneContextMenu.transferIfNeeded(p, it) end end
local function injured(part) return call(part, "HasInjury", false) end

local function removeBandageFirst(p, part)
    if call(part, "bandaged", false) then
        ISTimedActionQueue.add(ISApplyBandage:new(p, p, nil, part, false))
    end
end

H.registerTreatment{ id = "glass", priority = 90, icon = "ic_glass",
    test = function(it, part) return call(part, "haveGlass", false) and IS.glassTool(it) end,
    perform = function(it, part, p) toInv(p, it); ISTimedActionQueue.add(ISRemoveGlass:new(p, p, part, false)) end }
H.registerTreatment{ id = "bullet", priority = 85, icon = "ic_bullet",
    test = function(it, part) return call(part, "haveBullet", false) and IS.bulletTool(it) end,
    perform = function(it, part, p) toInv(p, it); ISTimedActionQueue.add(ISRemoveBullet:new(p, p, part)) end }
local function canStitch(part) return injured(part) and call(part, "deepWounded", false) and not call(part, "haveGlass", false) and not call(part, "stitched", false) end
H.registerTreatment{ id = "stitch", priority = 80, icon = "ic_stitch",
    test = function(it, part, p)
        if not canStitch(part) then return false end
        if IS.suture(it) then return true end
        if IS.needle(it) then return H.find(p, "thread", IS.thread) ~= nil end
        if IS.thread(it) then return H.find(p, "needle", IS.needle) ~= nil end
        return false
    end,
    perform = function(it, part, p)
        if IS.suture(it) then toInv(p, it); ISTimedActionQueue.add(ISStitch:new(p, p, it, part, true)); return end
        local needle = IS.needle(it) and it or H.find(p, "needle", IS.needle)
        local thread = IS.thread(it) and it or H.find(p, "thread", IS.thread)
        toInv(p, needle); toInv(p, thread)
        ISTimedActionQueue.add(ISStitch:new(p, p, thread, part, true))
    end }
local function canSplint(part, name)
    return not NO_SPLINT[name] and injured(part) and not call(part, "stitched", false)
        and call(part, "getFractureTime", 0) > 0 and call(part, "getSplintFactor", 0) <= 0
end
H.registerTreatment{ id = "splint", priority = 75, icon = "ic_splint",
    test = function(it, part, p, name)
        if not canSplint(part, name) then return false end
        if IS.splint(it) then return true end
        if IS.plank(it) then return H.find(p, "sheet", IS.sheet) ~= nil end
        if IS.sheet(it) then return H.find(p, "plank", IS.plank) ~= nil end
        return false
    end,
    perform = function(it, part, p)
        if IS.splint(it) then toInv(p, it); ISTimedActionQueue.add(ISSplint:new(p, p, nil, it, part, true)); return end
        local plank = IS.plank(it) and it or H.find(p, "plank", IS.plank)
        local sheet = IS.sheet(it) and it or H.find(p, "sheet", IS.sheet)
        toInv(p, sheet); toInv(p, plank)
        ISTimedActionQueue.add(ISSplint:new(p, p, sheet, plank, part, true))
    end }
H.registerTreatment{ id = "wash", priority = 70, icon = "ic_burn",
    test = function(it, part) return injured(part) and call(part, "isNeedBurnWash", false) and IS.cleanBandage(it) end,
    perform = function(it, part, p) toInv(p, it); ISTimedActionQueue.add(ISCleanBurn:new(p, p, it, part)) end }

local POULTICE = { ComfreyCataplasm = "ISComfreyCataplasm", WildGarlicCataplasm = "ISGarlicCataplasm", PlantainCataplasm = "ISPlantainCataplasm" }
H.registerTreatment{ id = "poultice", priority = 55, icon = "ic_bandage",
    test = function(it, part)
        if not POULTICE[it:getType()] then return false end
        local hurt = call(part, "HasInjury", false) or call(part, "stitched", false) or call(part, "getSplintFactor", 0) > 0
        return hurt and not call(part, "bandaged", false) and call(part, "getPlantainFactor", 0) == 0
            and call(part, "getComfreyFactor", 0) == 0 and call(part, "getGarlicFactor", 0) == 0
    end,
    perform = function(it, part, p)
        local cls = _G[POULTICE[it:getType()]]
        if not cls then return end
        toInv(p, it)
        ISTimedActionQueue.add(cls:new(p, p, it, part))
    end }
H.registerTreatment{ id = "disinfect", priority = 60, icon = "ic_infect",
    test = function(it, part) return injured(part) and IS.alcohol(it) end,
    perform = function(it, part, p) toInv(p, it); ISTimedActionQueue.add(ISDisinfect:new(p, p, it, part)) end }
H.registerTreatment{ id = "bandage", priority = 50, icon = "ic_bandage",
    test = function(it, part)
        if not IS.bandage(it) then return false end
        if call(part, "bandaged", false) then return call(part, "isBandageDirty", false) end
        return injured(part)
    end,
    perform = function(it, part, p)
        toInv(p, it)
        removeBandageFirst(p, part)
        ISTimedActionQueue.add(ISApplyBandage:new(p, p, it, part, true))
    end }

local function eatOk(p)
    local ok, lvl = pcall(function() return p:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) end)
    return not ok or lvl < 3
end
H.registerConsumable{ id = "pill", priority = 60,
    test = function(it) return IS.pill(it) end,
    perform = function(it, p) ISInventoryPaneContextMenu.takePill(it, p:getPlayerNum()) end }
H.registerConsumable{ id = "drink", priority = 55,
    test = function(it) return IS.drink(it) end,
    perform = function(it, p)
        local fc = it:getFluidContainer()

        if fc and not call(fc, "canPlayerEmpty", true) then
            TGI.halo(p, tr("Sealed"), false)
        else
            ISInventoryPaneContextMenu.onDrinkFluid(it, 1, p)
        end
    end }
H.registerConsumable{ id = "food", priority = 50,
    test = function(it) return IS.food(it) end,
    perform = function(it, p)
        if call(it, "getHungChange", 0) < 0 and not eatOk(p) then TGI.halo(p, getText("Tooltip_CantEatMore"), false); return end
        ISInventoryPaneContextMenu.eatItem(it, 1, p:getPlayerNum(), nil, 100)
    end }

H.ADVICE = {
    bandage   = { key = "DoBandage",   find = IS.bandage },
    rebandage = { key = "DoRebandage", find = IS.bandage },
    disinfect = { key = "DoDisinfect", find = IS.alcohol },
    glass     = { key = "DoGlass",     find = IS.glassTool, hands = true },
    bullet    = { key = "DoBullet",    find = IS.bulletTool },
    stitch    = { key = "DoStitch",    find = function(i) return IS.suture(i) or IS.needle(i) end },
    splint    = { key = "DoSplint",    find = function(i) return IS.splint(i) or IS.plank(i) end },
    wash      = { key = "DoWash",      find = IS.cleanBandage },
}

function H.treatmentFor(it, name, p)
    local part = bp(p, name)
    if not part or not it then return nil end
    for _, t in ipairs(H.treatments) do
        local ok, yes = pcall(t.test, it, part, p, name)
        if ok and yes then return t, part end
    end
    return nil
end
function H.consumableFor(it, p)
    if not it then return nil end
    for _, c in ipairs(H.consumables) do
        local ok, yes = pcall(c.test, it, p)
        if ok and yes then return c end
    end
    return nil
end

local hlKey, hlT, hlRes = nil, 0, nil
local function treatableParts(it, p)
    local now = getTimestampMs()
    if hlKey == it and now - hlT < 300 then return hlRes end
    local res = {}
    for _, name in ipairs(H.ORDER) do
        if H.treatmentFor(it, name, p) then res[name] = true end
    end
    hlKey, hlT, hlRes = it, now, res
    return res
end

function H.addTreatOptions(menu, p, name)
    local part = bp(p, name)
    if not part then return 0 end
    local seen, n = {}, 0
    local function scan(c, depth)
        local items = c and c:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            if n >= 12 then return end
            local it = items:get(i)
            local t = H.treatmentFor(it, name, p)
            local key = t and (t.id .. "|" .. it:getFullType())
            if t and not seen[key] then
                seen[key] = true
                n = n + 1
                local adv = H.ADVICE[t.id]
                local label = adv and tr(adv.key) or (t.label and getText(t.label)) or t.id
                label = string.gsub(label, "%s*%b()", "")
                local o = menu:addOption(label .. ": " .. it:getDisplayName(), it, function(item)
                    local ok, err = pcall(t.perform, item, part, p, name)
                    if not ok then print("[TGI] health treatment " .. tostring(t.id) .. " failed: " .. tostring(err)) end
                    H.invalidate()
                    notify("treat", item, part, p, t.id)
                end)
                if o then o.itemForTexture = it end
            end
            if depth == 0 and instanceof(it, "InventoryContainer") then scan(it:getInventory(), 1) end
        end
    end
    scan(p:getInventory(), 0)
    return n
end

function H.drop(pn, lx, ly, w, h, dir, d)
    if not opt() or not d or d.source and d.source.slot then return nil end
    local p = getSpecificPlayer(pn)
    local it = d.entry and d.entry.item
    if not p or not it or p:isDead() then return nil end
    if lx < 0 or ly < 0 or lx >= w or ly >= h then return nil end
    if H.forced or H.mode2d then dir = "S" end
    local name = H.partAt(lx, ly, w, h, dir, H.sex(p))
    if name then
        local t, part = H.treatmentFor(it, name, p)
        if t then
            local ok, err = pcall(t.perform, it, part, p, name)
            if not ok then print("[TGI] health treatment " .. tostring(t.id) .. " failed: " .. tostring(err)) end
            H.invalidate()
            notify("treat", it, part, p, t.id)
            return true
        end
    end
    local c = H.consumableFor(it, p)
    if c then
        local ok, err = pcall(c.perform, it, p)
        if not ok then print("[TGI] consume " .. tostring(c.id) .. " failed: " .. tostring(err)) end
        notify("consume", it, nil, p, c.id)
        return true
    end

    if name and (IS.bandage(it) or IS.alcohol(it) or IS.tweezers(it) or IS.suture(it) or IS.splint(it)) then
        TGI.halo(p, tr("NothingToTreat"), false)
        return true
    end
    return nil
end

local function sevColor(s)
    if s.severe then return 0.95, 0.18, 0.15 end
    if s.minor then return 1.0, 0.62, 0.15 end
    if s.treated then return 0.35, 0.75, 1.0 end

    return 0.72, 0.68, 0.45
end

function H.sex(p) return (p and p.isFemale and p:isFemale()) and "f" or "m" end

local relKey, relT, relRes = nil, 0, false
local function relevant(it, p)
    local now = getTimestampMs()
    if relKey == it and now - relT < 500 then return relRes end
    local r = H.consumableFor(it, p) ~= nil
    if not r then for _ in pairs(treatableParts(it, p)) do r = true; break end end
    if not r then r = IS.bandage(it) or IS.alcohol(it) or IS.tweezers(it) or IS.suture(it) or IS.splint(it) end
    relKey, relT, relRes = it, now, r
    return r
end

function H.anyVisible(set, dir, sex)
    local view = H.view(dir)
    local mp = view and maps(view, sex)
    local any = false
    for name in pairs(set) do
        any = true
        if not mp or mp.parts[name] then return true end
    end
    return not any
end

local function drawPart(ui, sex, view, name, w, h, kind, a, r, g, b)
    local x, y, rw, rh = H.rect(name, w, h, view, sex)
    if not x then return end
    local t = TGI.BodyMap and partTex(sex, view, name, kind)
    if t then ui:drawTextureScaled(t, x, y, rw, rh, a, r, g, b)
    elseif kind == "line" then ui:drawRectBorder(x, y, rw, rh, a, r, g, b)
    else ui:drawRect(x, y, rw, rh, a * 0.6, r, g, b) end
end

local function hpColor(k)

    if k > 0.6 then
        local t = (k - 0.6) / 0.4
        return 0.62 - 0.24 * t, 0.5 - 0.12 * t, 0.22 + 0.16 * t
    end
    local t = k / 0.6
    return 0.55 + 0.07 * t, 0.12 + 0.38 * t, 0.1 + 0.12 * t
end
function H.drawFigure(ui, sex, st, w, h)
    local mp = maps("S", sex)
    if not mp then return end
    ui:drawRect(0, 0, w, h, 0.85, 0.02, 0.022, 0.022)
    local mode = H.viewMode or "health"
    for name in pairs(mp.parts) do
        local s = st[name]
        local r, g, b
        if mode == "protect" and s then

            local k = math.max(0, math.min(1, ((s.bite or 0) + (s.scratch or 0)) / 200))
            r, g, b = 0.3 - k * 0.1, 0.32 + k * 0.16, 0.34 + k * 0.36
        elseif mode == "warm" and s then

            local k = math.max(0, math.min(1, (s.insul or 0) / 100))
            r, g, b = 0.32 + k * 0.38, 0.32 - k * 0.04, 0.33 - k * 0.18
        else
            local hp = s and s.health or 100
            r, g, b = hpColor(math.max(0, math.min(1, hp / 100)))
        end
        drawPart(ui, sex, "S", name, w, h, "fill", 0.9, r, g, b)
        drawPart(ui, sex, "S", name, w, h, "line", 1, 0.01, 0.01, 0.01)
    end

    local font = UIFont.Small
    local fh = getTextManager():getFontHeight(font)
    for name in pairs(mp.parts) do
        local s = st[name]
        local cx, cy = H.center(name, w, h, "S", sex)
        if s and cx then
            local t, cr, cg, cb
            if mode == "protect" then t, cr, cg, cb = (s.bite or 0) .. "/" .. (s.scratch or 0), 0.75, 0.85, 1
            elseif mode == "warm" then t, cr, cg, cb = tostring(s.insul or 0), 1, 0.82, 0.6
            else
                local hp = math.floor(s.health + 0.5)
                t = tostring(hp)
                if hp >= 100 then cr, cg, cb = 0.8, 0.8, 0.74 else cr, cg, cb = 1, 0.62 + hp / 300, 0.45 end
            end
            local tw = T.measure(font, t)
            if TGI.Font and T.ownFont() and TGI.Font.width then
                local okW, fw = pcall(TGI.Font.width, t, font)
                if okW and fw then tw = fw end
            end
            ui:drawRect(cx - tw / 2 - 3, cy + 6, tw + 6, fh, 0.6, 0, 0, 0)
            ui:drawTextCentre(t, cx, cy + 6, cr, cg, cb, 1, font)
        end
    end

    H.drawModeBtn(ui)
end

H.MODES = { "health", "protect", "warm" }
H.MODE_ICON = { health = "ic_health", protect = "ic_shield", warm = "ic_insul" }
function H.modeBtnRect() return 3, 3, 18, 18 end
function H.drawModeBtn(ui)
    local x, y, w, h = H.modeBtnRect()
    local mode = H.viewMode or "health"
    local hv = ui:isMouseOver() and ui:getMouseX() >= x and ui:getMouseY() >= y and ui:getMouseX() < x + w and ui:getMouseY() < y + h
    ui:drawRect(x, y, w, h, 0.85, 0.03, 0.03, 0.03)
    ui:drawRectBorder(x, y, w, h, 1, T.accent.r * 0.8, T.accent.g * 0.8, T.accent.b * 0.8)
    local ic = tex(H.MODE_ICON[mode] or "ic_health")
    if ic then ui:drawTextureScaled(ic, x + 2, y + 2, w - 4, h - 4, 1, T.accent.r, T.accent.g, T.accent.b) end
    if hv then
        local t = tr("Mode_" .. mode)
        ui:drawRect(x + w + 2, y, T.measure(UIFont.Small, t) + 8, h, 0.85, 0.03, 0.03, 0.03)
        ui:drawText(t, x + w + 6, y + 1, T.text.r, T.text.g, T.text.b, 1, UIFont.Small)
    end
end

function H.modeClick(lx, ly)
    local x, y, w, h = H.modeBtnRect()
    if lx < x or ly < y or lx >= x + w or ly >= y + h then return false end
    local cur = H.viewMode or "health"
    for i, m in ipairs(H.MODES) do
        if m == cur then H.viewMode = H.MODES[(i % #H.MODES) + 1]; break end
    end
    H.invalidate()
    return true
end
H.isRelevant = function(it, p) return relevant(it, p) end

function H.render(ui, pn, dir, setDir)
    if not opt() then

        if ui.flat then
            local p0 = getSpecificPlayer(pn); H.mode2d = true; H.drawFigure(ui, H.sex(p0), {}, ui.width, ui.height)
            if ui.afterFigure then ui.afterFigure(ui) end
        end
        return
    end
    local p = getSpecificPlayer(pn)
    if not p or p:isDead() then return end
    local w, h = ui.width, ui.height
    local d = TGI.Drag and TGI.Drag.active
    local dragIt = d and not (d.source and d.source.slot) and d.entry and d.entry.item or nil
    local m2 = ui.flat or (ui.is2d and ui.is2d()) or false
    H.mode2d = m2

    if setDir and not m2 then
        if dragIt and not H.forced and relevant(dragIt, p) and not H.anyVisible(treatableParts(dragIt, p), dir, H.sex(p)) then
            if not H.forced then H.forced = true; setDir("S") end
        elseif H.forced and not dragIt then
            H.forced = false; setDir(dir)
        end
    end
    if H.forced or m2 then dir = "S" end
    local view = H.view(dir)
    if not view then H.hideTip(); return end
    local sex = H.sex(p)
    local st = H.state(p)
    if m2 then H.drawFigure(ui, sex, st, w, h) end
    if ui.afterFigure then ui.afterFigure(ui) end
    local hl = dragIt and treatableParts(dragIt, p) or nil
    local mx, my = ui:getMouseX(), ui:getMouseY()
    local inside = mx >= 0 and my >= 0 and mx < w and my < h
    local hover = inside and H.partAt(mx, my, w, h, dir, sex) or nil
    local pulse = 0.55 + 0.45 * math.abs(math.sin(getTimestampMs() / 300))

    local eat = dragIt and inside and not (hover and hl[hover]) and H.consumableFor(dragIt, p)
    for _, name in ipairs(H.ORDER) do
        local s = st[name]
        if s then
            if eat then
                drawPart(ui, sex, view, name, w, h, "fill", 0.12, 0.35, 0.9, 0.4)
                drawPart(ui, sex, view, name, w, h, "line", pulse * 0.8, 0.35, 0.9, 0.4)
            elseif hl and hl[name] then
                drawPart(ui, sex, view, name, w, h, "fill", hover == name and 0.38 or 0.16, 0.35, 0.9, 0.4)
                drawPart(ui, sex, view, name, w, h, "line", pulse, 0.35, 0.9, 0.4)
            elseif s.hurt then
                local r, g, b = sevColor(s)
                if s.severe or hover == name then drawPart(ui, sex, view, name, w, h, "fill", hover == name and 0.3 or 0.14, r, g, b) end
                drawPart(ui, sex, view, name, w, h, "line", s.severe and pulse or 0.8, r, g, b)
            elseif hover == name or (inside and not d and isShiftKeyDown()) then

                if hover == name then drawPart(ui, sex, view, name, w, h, "fill", 0.12, 1, 1, 1) end
                drawPart(ui, sex, view, name, w, h, "line", 0.5, 1, 1, 1)
            end

            local n = math.min(2, #s.icons)
            if n > 0 then
                local cx, cy = H.center(name, w, h, dir, sex)
                local sz = 12
                local r, g, b = sevColor(s)
                local x0 = cx - (n * (sz + 2)) / 2
                for i = 1, n do
                    local t = s.icons[i]
                    if type(t) == "string" then t = (string.find(t, "/", 1, true) and getTexture(t)) or tex(t) end
                    if t then
                        local ix = x0 + (i - 1) * (sz + 2)
                        ui:drawRect(ix - 1, cy - sz / 2 - 1, sz + 2, sz + 2, 0.75, 0, 0, 0)
                        ui:drawTextureScaled(t, ix, cy - sz / 2, sz, sz, 1, r, g, b)
                    end
                end
            end
        end
    end

    if hover and not d and st[hover] then H.showTip(ui, st[hover], p)
    elseif hover and dragIt and st[hover] then
        local t = H.treatmentFor(dragIt, hover, p)
        H.showTip(ui, st[hover], p, H.actionLabel(t), not t)
    else H.hideTip() end
end

local Tip = ISPanel:derive("TGIHealthTip")
if TGI.Theme.applyFont then TGI.Theme.applyFont(Tip) end
function Tip:new()
    local o = ISPanel:new(0, 0, 10, 10)
    setmetatable(o, self); self.__index = self
    o.background = false
    o.lines = {}
    return o
end
function Tip:prerender()
    local a = T.uiAlpha and T.uiAlpha() or 1
    self:drawRect(0, 0, self.width, self.height, 0.92 * a, 0.05, 0.05, 0.05)
    self:drawRectBorder(0, 0, self.width, self.height, a, T.border.r, T.border.g, T.border.b)
end
function Tip:render()
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local y = 4
    for _, l in ipairs(self.lines) do
        local x = 6
        if l.icon then
            local t = type(l.icon) == "string" and tex(l.icon) or l.icon
            if t then self:drawTextureScaled(t, x, y + 1, fh - 2, fh - 2, 1, l.r, l.g, l.b) end
            x = x + fh + 2
        end
        self:drawText(l.text, x, y, l.r, l.g, l.b, 1, l.font or UIFont.Small)
        y = y + (l.font == UIFont.Medium and getTextManager():getFontHeight(UIFont.Medium) or fh) + 1
    end
end
function Tip:onMouseDown() return false end

local DISPLAY = {}
local function partName(name)
    if not DISPLAY[name] then
        local ok, v = pcall(function() return BodyPartType.getDisplayName(BodyPartType[name]) end)
        DISPLAY[name] = ok and v and v ~= "" and v or name
    end
    return DISPLAY[name]
end

function H.actionLabel(t)
    if not t then return tr("NothingToTreat") end
    if t.label then return t.label end
    local k = "IGUI_TGI_H_Act_" .. t.id
    local v = getText(k)
    return v ~= k and v or t.id
end

local tipKey, tipLines = nil, nil

function H.coverNames(p, name)
    local out = {}
    pcall(function()
        local bp = BodyPartType.FromString(name)
        local blood = BloodBodyPartType.FromIndex(BodyPartType.ToIndex(bp))
        local wi = p:getWornItems()
        for i = 0, wi:size() - 1 do
            local it = wi:get(i):getItem()
            if it and instanceof(it, "Clothing") and it.getCoveredParts then
                local cp = it:getCoveredParts()
                if cp and cp:contains(blood) then out[#out + 1] = it:getDisplayName() end
            end
        end
    end)
    return out
end

function H.showTip(ui, s, p, action, bad)
    if not H.tip then H.tip = Tip:new(); H.tip:initialise() end
    local tip = H.tip
    local key = s.name .. ":" .. tostring(H._stT) .. ":" .. tostring(action) .. ":" .. tostring(bad)
    if key ~= tipKey then
        local L = {}
        local r, g, b = sevColor(s)
        L[#L + 1] = { text = partName(s.name) .. "  " .. math.floor(s.health + 0.5) .. "%", r = 1, g = 1, b = 1, font = UIFont.Medium }
        if (H.viewMode or "health") ~= "health" then
            L[#L + 1] = { text = tr("Bite") .. " " .. (s.bite or 0) .. "%   " .. tr("Scratch") .. " " .. (s.scratch or 0) .. "%   " .. tr("BulletDef") .. " " .. (s.bullet or 0) .. "%", r = 0.6, g = 0.8, b = 1 }
            L[#L + 1] = { text = tr("Insulation") .. " " .. (s.insul or 0), r = 1, g = 0.8, b = 0.5 }
        end
        local cov = p and H.coverNames(p, s.name) or {}
        for i, n in ipairs(cov) do
            L[#L + 1] = { text = (i == 1 and (tr("CoveredBy") .. " ") or "    ") .. n, r = 0.62, g = 0.7, b = 0.78 }
            if i >= 6 and #cov > 6 then L[#L + 1] = { text = "    +" .. (#cov - 6), r = 0.62, g = 0.7, b = 0.78 }; break end
        end
        if action then
            L[#L + 1] = { text = action, icon = "ic_med", r = bad and 0.9 or 0.4, g = bad and 0.4 or 0.95, b = bad and 0.35 or 0.45 }
        end
        if #s.lines == 0 then
            if s.health < 99 then L[#L + 1] = { text = tr("Recovering"), r = 0.72, g = 0.68, b = 0.45 }
            else L[#L + 1] = { text = tr("Healthy"), r = 0.6, g = 0.85, b = 0.6 } end
        end
        for i, l in ipairs(s.lines) do
            L[#L + 1] = { text = l[1], icon = s.icons[i], r = l[2] and 0.95 or 0.9, g = l[2] and 0.35 or 0.75, b = l[2] and 0.3 or 0.4 }
        end
        H.treatHL = nil
        if not action and #s.advice > 0 then
            H.treatHL = {}
            L[#L + 1] = { text = tr("Treat"), r = T.accent.r, g = T.accent.g, b = T.accent.b }
            local seen = {}
            for _, a in ipairs(s.advice) do
                local ad = H.ADVICE[a]
                if not seen[a] then
                    seen[a] = true
                    local txt = ad and tr(ad.key) or a
                    local have = ad and ad.find and H.find(p, "adv_" .. a, ad.find)
                    if have then H.treatHL[have:getID()] = true end
                    if have then txt = txt .. "  (" .. have:getName() .. ")"
                    elseif ad and ad.hands then txt = txt .. "  (" .. tr("Hands") .. ")"
                    elseif ad then txt = txt .. "  - " .. tr("NoItem") end
                    L[#L + 1] = { text = "  " .. txt, r = have and 0.75 or 0.6, g = have and 0.9 or 0.6, b = have and 0.75 or 0.6 }
                end
            end
            L[#L + 1] = { text = tr("DragHint"), r = 0.55, g = 0.55, b = 0.55 }
        end
        tipKey, tipLines = key, L
        local tm, fh = getTextManager(), getTextManager():getFontHeight(UIFont.Small)
        local w, hh = 60, 8
        for _, l in ipairs(L) do
            local f = l.font or UIFont.Small
            w = math.max(w, TGI.Theme.measure(f, l.text) + (l.icon and fh + 2 or 0) + 12)
            hh = hh + (f == UIFont.Medium and tm:getFontHeight(UIFont.Medium) or fh) + 1
        end
        tip.lines = L
        tip:setWidth(w); tip:setHeight(hh)
    end
    local x, y = getMouseX() + 18, getMouseY() + 12
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    if x + tip.width > sw then x = getMouseX() - tip.width - 8 end
    if y + tip.height > sh then y = sh - tip.height end
    tip:setX(x); tip:setY(y)
    if not tip.shown then
        tip:addToUIManager(); tip:setAlwaysOnTop(true); tip.shown = true
    end
    tip:bringToTop()
    H.tipFrame = getTimestampMs()
end
function H.hideTip()
    local tip = H.tip
    if tip and tip.shown then tip:removeFromUIManager(); tip.shown = false; tipKey = nil end
end

function H.treatItems()
    if H.tip and H.tip.shown and getTimestampMs() - (H.tipFrame or 0) < 150 then return H.treatHL end
    return nil
end

local dirtyWarned, dirtyNext = {}, 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < dirtyNext then return end
    dirtyNext = now + 4000
    local p = getSpecificPlayer(0)
    if not p or p:isDead() or not opt() then return end
    for _, name in ipairs(H.ORDER) do
        local part = bp(p, name)
        local dirty = part and call(part, "bandaged", false) and call(part, "isBandageDirty", false)
        if dirty and not dirtyWarned[name] then
            dirtyWarned[name] = true
            if HaloTextHelper and HaloTextHelper.addTextWithArrow and HaloTextHelper.getColorRed then
                pcall(function() HaloTextHelper.addTextWithArrow(p, tr("DirtyBandage") .. ": " .. partName(name), false, HaloTextHelper.getColorRed()) end)
            end
        elseif not dirty then dirtyWarned[name] = nil end
    end
end)

Events.OnTick.Add(function()
    if H.tip and H.tip.shown and getTimestampMs() - (H.tipFrame or 0) > 120 then H.hideTip() end
end)

local Overlay = ISUIElement:derive("TGIHealthOverlay")
if TGI.Theme.applyFont then TGI.Theme.applyFont(Overlay) end
function Overlay:new(x, y, w, h)
    local o = ISUIElement:new(x, y, w, h)
    setmetatable(o, self); self.__index = self
    return o
end
function Overlay:instantiate()
    ISUIElement.instantiate(self)
    pcall(function() self.javaObject:setConsumeMouseEvents(false) end)
end
function Overlay:render()
    if not self.parent or not self.parent:isReallyVisible() then return end
    H.render(self, self.pn, self.getDir and self.getDir() or "S", self.setDir)
end
function Overlay:onMouseDown() return false end
function Overlay:onMouseUp() return false end
function Overlay:onRightMouseUp() return false end
function Overlay:onMouseWheel() return self.flat == true end

function H.attach(model, pn, getDir, setDir, parent)
    if not model or model.tgiHealth then return nil end
    model.tgiHealth = true
    H.forced = false
    parent = parent or model.parent
    if not parent then return nil end
    local o = Overlay:new(model:getX(), model:getY(), model:getWidth(), model:getHeight())
    o:initialise()
    o.model, o.pn, o.getDir, o.setDir = model, pn, getDir, setDir
    parent:addChild(o)
    return o
end

function H.box(parent, x, y, w, h, pn)
    local o = Overlay:new(x, y, w, h)
    o:initialise()
    o.pn, o.flat = pn, true
    H.mode2d = true
    o.getDir = function() return "S" end
    parent:addChild(o)
    return o
end

return H
