require "ISUI/ISPanel"
require "TGI/TGI_Theme"
require "TGI/TGI_Draw"
require "TGI/TGI_Compare"
TGI = TGI or {}
local T, D = TGI.Theme, TGI.Draw
local Tip = ISPanel:derive("TGITooltip")
if TGI.Theme.applyFont then TGI.Theme.applyFont(Tip) end
TGI.Tip = Tip

local W = 270
local PAD = 8

local function big() return TGI.Options and TGI.Options.get("bigTooltip") == true end
local function FS() return big() and UIFont.Medium or UIFont.Small end
local function FM() return big() and UIFont.Large or UIFont.Medium end
local function lineH()
    if not big() then return 17 end
    return 17 + math.max(0, getTextManager():getFontHeight(UIFont.Medium) - getTextManager():getFontHeight(UIFont.Small))
end

local function tx(key, ...) return getText(key, ...) end
local function catName(item)
    local c = tostring(item:getDisplayCategory() or "")
    if c == "" then return "" end
    local k = "IGUI_ItemCat_" .. c
    local v = getText(k)
    if v == k then return c end
    return v
end

local GOOD, BAD = { r = 0.55, g = 0.85, b = 0.45 }, { r = 0.95, g = 0.45, b = 0.35 }
local function shortT(t) return (string.gsub(tostring(t), "^.-%.", "")) end
local function scriptName(t)
    local n = nil
    pcall(function() local s = getScriptManager():FindItem(t); n = s and s:getDisplayName() end)
    return n or shortT(t)
end
local function ammoKey(item)
    local key = nil
    pcall(function()
        local at = item:getAmmoType()
        key = at and (at.getItemKey and at:getItemKey()) or at
        if key then key = tostring(key) end
    end)
    if key == "" then key = nil end
    return key
end

local function magTypes(gun)
    local out, seen = {}, {}
    local function add(t) if t and t ~= "" and not seen[t] then seen[t] = true; out[#out + 1] = t end end
    pcall(function()
        if Magazine and Magazine.GetMagazineTypesForGun then
            for _, t in ipairs(Magazine.GetMagazineTypesForGun(gun) or {}) do add(t) end
        end
    end)
    pcall(function() add(gun:getMagazineType()) end)
    return out
end
local function haveCount(p, t)
    local n = 0
    if p then pcall(function() n = p:getInventory():getCountTypeRecurse(shortT(t)) end) end
    return n
end

local ICON_KEYS = {
    IGUI_TGI_Weight = "weight", IGUI_TGI_CmpCondition = "condition", IGUI_TGI_Uses = "uses", IGUI_TGI_Wet = "drop",
    IGUI_TGI_CmpDamage = "damage", IGUI_TGI_CmpRange = "range", IGUI_TGI_CmpSpeed = "speed", IGUI_TGI_Crit = "crit",
    IGUI_TGI_Ammo = "ammo", IGUI_TGI_Mag = "mag", IGUI_TGI_Rounds = "rounds", IGUI_TGI_Parts = "condition",
    IGUI_TGI_CmpBite = "bite", IGUI_TGI_CmpScratch = "scratch", IGUI_TGI_CmpBullet = "bullet",
    IGUI_TGI_CmpInsul = "insul", IGUI_TGI_CmpWind = "wind", IGUI_TGI_Blood = "drop", IGUI_TGI_Dirt = "dirt",
    IGUI_TGI_Capacity = "bag", IGUI_TGI_Cells = "inside", IGUI_TGI_CmpReduce = "reduce", IGUI_TGI_Inside = "inside",
    IGUI_TGI_Hunger = "hunger", IGUI_TGI_Thirst = "drop", IGUI_TGI_Calories = "calories",
    IGUI_TGI_Unhappy = "unhappy", IGUI_TGI_Boredom = "boredom", IGUI_TGI_Stress = "stress",
    IGUI_TGI_Volume = "volume", IGUI_TGI_Fluid = "drop", IGUI_TGI_Temp = "insul", IGUI_TGI_Worth = "worth",
}

local ICON_TINT = {
    IGUI_TGI_Wet = { r = 0.35, g = 0.6, b = 1 }, IGUI_TGI_Thirst = { r = 0.4, g = 0.7, b = 1 }, IGUI_TGI_Fluid = { r = 0.4, g = 0.7, b = 1 },
    IGUI_TGI_Blood = { r = 0.85, g = 0.15, b = 0.1 }, IGUI_TGI_Dirt = { r = 0.6, g = 0.45, b = 0.25 },
    IGUI_TGI_Hunger = { r = 0.55, g = 0.85, b = 0.4 }, IGUI_TGI_Calories = { r = 1, g = 0.6, b = 0.25 },
    IGUI_TGI_Worth = { r = 0.95, g = 0.8, b = 0.3 }, IGUI_TGI_Volume = { r = 0.4, g = 0.7, b = 1 },
}
local iconOf, tintOf = nil, nil
local function iconMaps()
    if iconOf then return end
    iconOf, tintOf = {}, {}
    for k, n in pairs(ICON_KEYS) do
        local t = getText(k)
        iconOf[t] = n
        tintOf[t] = ICON_TINT[k]
    end
end

local function build(item, pn, opts)
    local rows = {}
    iconMaps()
    local function kv(l, v, c) rows[#rows + 1] = { kind = "kv", l = l, v = v, c = c, li = iconOf[l], lt = tintOf[l] } end
    local function bar(l, f, v, c) rows[#rows + 1] = { kind = "bar", l = l, f = math.max(0, math.min(1, f or 0)), v = v, c = c, li = iconOf[l], lt = tintOf[l] } end
    local function sep() rows[#rows + 1] = { kind = "sep" } end

    local isBag = instanceof(item, "InventoryContainer")

    local w = item:getUnequippedWeight() or item:getActualWeight()
    kv(tx("IGUI_TGI_Weight"), string.format("%.2f", w))

    local cmax = item:getConditionMax()
    if cmax and cmax > 0 then
        local c = item:getCondition()
        bar(tx("IGUI_TGI_CmpCondition"), c / cmax, c .. " / " .. cmax)
    end

    if item.hasSharpness and item:hasSharpness() == true then
        local sh, mx = tonumber(item:getSharpness()) or 0, tonumber(item:getMaxSharpness()) or 1
        if mx <= 0 then mx = 1 end
        bar(getText("Tooltip_weapon_Sharpness"), sh / mx, string.format("%.0f%%", sh / mx * 100), { 0.75, 0.85, 0.95 })
    end
    if item.hasHeadCondition and item:hasHeadCondition() == true then
        local hc, hm = tonumber(item:getHeadCondition()) or 0, tonumber(item:getHeadConditionMax()) or 0
        if hm > 0 then bar(getText("Tooltip_weapon_HeadCondition"), hc / hm, hc .. " / " .. hm) end
    end
    if instanceof(item, "DrainableComboItem") then
        local u = item:getCurrentUsesFloat()
        bar(tx("IGUI_TGI_Uses"), u, math.floor(u * 100 + 0.5) .. "%")
    end

    if not instanceof(item, "DrainableComboItem") and TGI.Draw.usage then
        local u = TGI.Draw.usage(item)
        if u then bar(tx("IGUI_TGI_Uses"), u, math.floor(u * 100 + 0.5) .. "%") end
    end

    if not instanceof(item, "Clothing") then
        local ok, wv = pcall(function() return item:isWet() and item:getWetCooldown() end)
        if ok and wv then kv(tx("IGUI_TGI_Wet"), "", { 0.3, 0.55, 1 }) end
    end

    do
        local okK, read, learn = pcall(TGI.Draw.knowState, item)
        if okK then
            local LC = TGI.Draw.LEARN_COL or {}
            local function note(key, c, extra)
                rows[#rows + 1] = { kind = "note", v = tx(key) .. (extra or ""), c = c and { r = c[1], g = c[2], b = c[3] } or T.dim }
            end
            if learn then note("IGUI_TGI_Know_" .. learn, LC[learn])
            elseif read == "part" then
                local pages = item.getNumberOfPages and item:getNumberOfPages() or 0
                local done = 0
                pcall(function() done = getSpecificPlayer(pn or 0):getAlreadyReadPages(item:getFullType()) or 0 end)
                note("IGUI_TGI_Know_part", { 1, 0.8, 0.45 }, pages > 0 and (" " .. done .. " / " .. pages) or nil)
            elseif read == true then note("IGUI_TGI_Know_read", { 0.45, 0.85, 0.45 }) end
        end
        local okR, rs = pcall(TGI.Draw.rawState, item)
        if okR and rs then
            local rc = TGI.Draw.RAW_COL[rs]
            rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Food_" .. rs), c = { r = rc[1], g = rc[2], b = rc[3] } }
        end
        local okC, cf, cr, cg, cb, ck = pcall(TGI.Draw.cookState, item)
        if okC and cf then
            rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Cook_" .. ck) .. " " .. math.floor(math.min(1, cf) * 100 + 0.5) .. "%", c = { r = cr, g = cg, b = cb } }
        end
        if TGI.Draw.isUncollected and TGI.Draw.isUncollected(item) then
            rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Know_new"), c = { r = 1, g = 0.95, b = 0.6 } }
        end
    end

    do
        local okM, skills = pcall(TGI.Draw.mediaSkills, item)
        if okM and skills then sep(); kv(tx("IGUI_TGI_Teaches"), skills, T.accent) end
    end
    if instanceof(item, "Literature") then
        local okS, skill = pcall(function() return item:getSkillTrained() end)
        if okS and skill and tostring(skill) ~= "" and tostring(skill) ~= "None" then
            local lo, hi = tonumber(item:getLvlSkillTrained()) or 0, tonumber(item:getMaxLevelTrained()) or 0
            local okP, pname = pcall(function() return PerkFactory.getPerkName(Perks.FromString(tostring(skill))) end)
            sep()
            kv(getText("Tooltip_BookTitle"), (okP and pname or tostring(skill)) .. "  " .. lo .. "-" .. hi, T.accent)
        end
        local pages = tonumber(item:getNumberOfPages()) or 0
        if pages > 0 then kv(getText("Tooltip_literature_Number_of_Pages"), tostring(pages)) end
        local function lmood(label, v)
            v = tonumber(v) or 0
            if math.abs(v) >= 0.5 then kv(label, string.format("%+.0f", v), v > 0 and BAD or GOOD) end
        end
        lmood(tx("IGUI_TGI_Boredom"), item:getBoredomChange())
        lmood(tx("IGUI_TGI_Stress"), item:getStressChange())
        lmood(tx("IGUI_TGI_Unhappy"), item:getUnhappyChange())
    end

    local melee = instanceof(item, "HandWeapon") and (tonumber(item:getMaxDamage()) or 0) >= 0.3
    if instanceof(item, "HandWeapon") and TGI.Model and (TGI.Model.groupOf(item) == 1 or melee) then
        sep()
        kv(tx("IGUI_TGI_CmpDamage"), string.format("%.1f - %.1f", item:getMinDamage(), item:getMaxDamage()))
        kv(tx("IGUI_TGI_CmpRange"), string.format("%.1f", item:getMaxRange()))
        kv(tx("IGUI_TGI_CmpSpeed"), string.format("%.2f", item:getBaseSpeed()))
        kv(tx("IGUI_TGI_Crit"), string.format("%.0f%%", item:getCriticalChance()))
        local okP, parts = pcall(TGI.Draw.weaponParts, item)
        if okP then
            for i, pt in ipairs(parts) do
                kv(i == 1 and tx("IGUI_TGI_Parts") or "", pt:getDisplayName(), T.accent)
            end
        end
        if item:isRanged() then
            kv(tx("IGUI_TGI_Ammo"), item:getCurrentAmmoCount() .. " / " .. item:getMaxAmmo())
            local p = getSpecificPlayer(pn or 0)
            local at = ammoKey(item)
            if at then
                local n = haveCount(p, at)
                kv(tx("IGUI_TGI_Rounds"), scriptName(at) .. "  (" .. n .. ")", n > 0 and GOOD or BAD)
            end
            local mags = magTypes(item)
            for i, mt in ipairs(mags) do
                if i > 3 then kv("", "+" .. (#mags - 3) .. " ..."); break end
                local n = haveCount(p, mt)
                kv(i == 1 and tx("IGUI_TGI_Mag") or "", scriptName(mt) .. "  (" .. n .. ")", n > 0 and GOOD or BAD)
            end
        end
    elseif item.getAmmoType and (select(2, pcall(function() return item:getMaxAmmo() end)) or 0) > 0 then

        local at = ammoKey(item)
        if at then
            sep()
            kv(tx("IGUI_TGI_Rounds"), scriptName(at))
            kv(tx("IGUI_TGI_Ammo"), item:getCurrentAmmoCount() .. " / " .. item:getMaxAmmo())
        end
    end

    if instanceof(item, "Clothing") then
        sep()
        local bite, scr, bul = item:getBiteDefense(), item:getScratchDefense(), item:getBulletDefense()
        if bite > 0 then bar(tx("IGUI_TGI_CmpBite"), bite / 100, string.format("%.0f", bite), { 0.4, 0.75, 0.9 }) end
        if scr > 0 then bar(tx("IGUI_TGI_CmpScratch"), scr / 100, string.format("%.0f", scr), { 0.4, 0.75, 0.9 }) end
        if bul > 0 then bar(tx("IGUI_TGI_CmpBullet"), bul / 100, string.format("%.0f", bul), { 0.4, 0.75, 0.9 }) end
        local ins = select(2, pcall(function() return item:getInsulation() end)) or 0
        ins = tonumber(ins) or 0
        if ins > 0 then bar(tx("IGUI_TGI_CmpInsul"), ins, string.format("%.0f", ins * 100), { 0.95, 0.6, 0.3 }) end
        local wind = select(2, pcall(function() return item:getWindresistance() end)) or 0
        wind = tonumber(wind) or 0
        if wind > 0 then bar(tx("IGUI_TGI_CmpWind"), wind, string.format("%.0f", wind * 100), { 0.7, 0.8, 0.85 }) end

        local okD, disc = pcall(function() return item:getDiscomfortModifier() end)
        disc = okD and tonumber(disc) or 0
        if disc > 0.001 then bar(getText("Tooltip_item_Discomfort"), math.min(1, disc), string.format("%.0f%%", disc * 100), { 0.85, 0.55, 0.3 }) end
        local okV, vis = pcall(function() return item:getVisionModifier() end)
        vis = okV and tonumber(vis) or 1
        if vis < 0.999 and vis >= 0 then bar(getText("Tooltip_item_VisionImpariment"), 1 - vis, string.format("%.0f%%", (1 - vis) * 100), { 0.6, 0.6, 0.85 }) end
        local P = TGI.Draw.pct
        local function g(fn) local ok, v = pcall(fn); return ok and v or 0 end
        local wet = P(g(function() return item:getWetness() end))
        if wet > 0.005 then bar(tx("IGUI_TGI_Wet"), wet, string.format("%.0f%%", wet * 100), { 0.3, 0.55, 1 }) end
        local blood = P(g(function() return item:getBloodLevel() end))
        if blood > 0.005 then bar(tx("IGUI_TGI_Blood"), blood, string.format("%.0f%%", blood * 100), { 0.85, 0.15, 0.1 }) end
        local dirt = P(g(function() return item:getDirtiness() end))
        if dirt > 0.005 then bar(tx("IGUI_TGI_Dirt"), dirt, string.format("%.0f%%", dirt * 100), { 0.55, 0.4, 0.2 }) end
    end

    if instanceof(item, "Key") and TGI.Keys then
        local d = TGI.Keys.describe(item, getSpecificPlayer(pn or 0))
        sep()
        rows[#rows + 1] = { kind = "note", v = d or tx("IGUI_TGI_KeyUnknown"), c = d and T.accent or T.dim }
    end
    if isBag and TGI.Keys and not opts.hiddenBag then
        local inv = item:getInventory()
        local its = inv:getItems()
        local keys = {}
        for i = 0, its:size() - 1 do
            local k = its:get(i)
            if instanceof(k, "Key") then keys[#keys + 1] = k end
        end
        if #keys > 0 then
            sep()
            local p = getSpecificPlayer(pn or 0)
            for i, k in ipairs(keys) do
                if i > 10 then rows[#rows + 1] = { kind = "note", v = "+" .. (#keys - 10) .. " ...", c = T.dim }; break end
                rows[#rows + 1] = { kind = "kv", l = k:getDisplayName(), v = TGI.Keys.describe(k, p) or "?", c = T.accent, li = "key", lt = T.dim }
            end
        end
    end

    local cells = nil
    pcall(function()
        local L = TGI.Layout
        local function count(list) local n = 0; for _, pk in ipairs(list or {}) do n = n + pk.w * pk.h end; return n end
        if isBag then
            local inv = item:getInventory()
            local cap = nil
            local p0 = getSpecificPlayer(pn or 0)
            if p0 and inv.getEffectiveCapacity then cap = inv:getEffectiveCapacity(p0) end
            if not cap or cap <= 0 then cap = item:getCapacity() end
            cells = count((L.pockets(L.kindFor(inv, item), cap, item:getFullType())))
        elseif instanceof(item, "Clothing") and TGI.Options.get("clothingPockets") ~= false then
            local loc = item.getBodyLocation and item:getBodyLocation()
            local strict = TGI.Model and TGI.Model.strictOn and TGI.Model.strictOn()
            if loc then
                local ls = { tostring(loc) }
                if not L.locKnown(ls[1]) then ls[2] = L.nameLoc(item:getType()) or L.nameLoc(item:getDisplayName()) end
                cells = count((L.clothingPockets(ls, true)))
            end
            if cells and not strict then

                local s0 = string.lower(tostring(loc))
                if s0:find("underwear", 1, true) then cells = 0 end
            end
        end
    end)
    if cells and cells > 0 then kv(tx("IGUI_TGI_Cells"), tostring(cells)) end

    if isBag then
        sep()
        kv(tx("IGUI_TGI_Capacity"), tostring(item:getCapacity()))
        kv(tx("IGUI_TGI_CmpReduce"), item:getWeightReduction() .. "%")
        if opts.hiddenBag then
            rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_NotSearched"), c = T.accent }
        else
            local inv = item:getInventory()
            kv(tx("IGUI_TGI_Inside"), string.format("%.1f / %d", inv:getCapacityWeight(), item:getCapacity()))
            local list = {}
            local its = inv:getItems()
            for i = 0, math.min(its:size(), 14) - 1 do list[#list + 1] = its:get(i):getTex() end
            if #list > 0 then rows[#rows + 1] = { kind = "icons", list = list } end
        end
    end

    if instanceof(item, "Food") then
        sep()
        local h = -item:getHungerChange() * 100
        if h ~= 0 then kv(tx("IGUI_TGI_Hunger"), string.format("%.0f", h), { 0.5, 0.85, 0.4 }) end
        local th = -item:getThirstChange() * 100
        if th ~= 0 then kv(tx("IGUI_TGI_Thirst"), string.format("%.0f", th), { 0.4, 0.7, 1 }) end

        local function mood(key, getter)
            local v = item[getter] and item[getter](item) or 0
            v = tonumber(v) or 0
            if math.abs(v) >= 0.5 then
                kv(tx(key), string.format("%+.0f", v), v > 0 and BAD or GOOD)
            end
        end
        mood("IGUI_TGI_Unhappy", "getUnhappyChange")
        mood("IGUI_TGI_Boredom", "getBoredomChange")
        mood("IGUI_TGI_Stress", "getStressChange")
        local en = (tonumber(item:getEnduranceChange()) or 0) * 100
        if math.abs(en) >= 0.5 then kv(getText("Tooltip_food_Endurance"), string.format("%+.0f", en), en > 0 and GOOD or BAD) end
        local fa = (tonumber(item:getFatigueChange()) or 0) * 100
        if math.abs(fa) >= 0.5 then kv(getText("Tooltip_food_Fatigue"), string.format("%+.0f", fa), fa > 0 and BAD or GOOD) end
        local cal = item:getCalories()
        if cal and cal > 0 then
            kv(tx("IGUI_TGI_Calories"), string.format("%.0f", cal))
            local cb, pr, li = tonumber(item:getCarbohydrates()) or 0, tonumber(item:getProteins()) or 0, tonumber(item:getLipids()) or 0
            if cb + pr + li > 0 then
                kv(getText("Tooltip_food_Carbs") .. " / " .. getText("Tooltip_food_Prots") .. " / " .. getText("Tooltip_food_Fat"),
                    string.format("%.0f / %.0f / %.0f", cb, pr, li), T.dim)
            end
        end
        local bad = { r = 0.9, g = 0.3, b = 0.25 }

        local knows = false
        pcall(function()
            local pl = getSpecificPlayer(pn or 0)
            knows = item:isPoison() == true and pl ~= nil and pl:isKnownPoison(item) == true
        end)
        if knows then rows[#rows + 1] = { kind = "note", v = getText("Tooltip_food_Poisonous"), c = bad } end
        if item:isRotten() then rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Rotten"), c = { r = 0.8, g = 0.4, b = 0.2 } }
        elseif item:isFresh() and (tonumber(item:getOffAgeMax()) or 0) < 1000000 then rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Fresh"), c = { r = 0.5, g = 0.85, b = 0.4 } }
        elseif (tonumber(item:getOffAge()) or 0) > 0 and (tonumber(item:getOffAge()) or 0) < 1000000 then
            rows[#rows + 1] = { kind = "note", v = getText("Tooltip_food_Stale"), c = { r = 0.85, g = 0.75, b = 0.4 } }
        end
        local fz = tonumber(item:getFreezingTime()) or 0
        if fz > 0 then kv(getText("IGUI_invpanel_FreezingTime"), math.floor(fz + 0.5) .. "%", { r = 0.45, g = 0.75, b = 1 }) end
    end

    local fc = TGI.Draw and TGI.Draw.fluidOf and TGI.Draw.fluidOf(item) or nil
    local cap = fc and fc.getCapacity and fc:getCapacity() or 0
    if cap > 0 then
        sep()
        local amt = fc.getAmount and fc:getAmount() or 0
        kv(tx("IGUI_TGI_Volume"), string.format("%.2f / %.2f " .. tx("IGUI_TGI_Litre"), amt, cap), { r = 0.4, g = 0.7, b = 1 })
        if amt > 0 and fc.getPrimaryFluid then
            local fl = fc:getPrimaryFluid()
            local nm = fl and fl.getTranslatedName and fl:getTranslatedName() or nil
            if nm then kv(tx("IGUI_TGI_Fluid"), tostring(nm)) end

            local okT, tainted = pcall(function() return fc:isTainted() end)
            local show = true
            pcall(function() show = getSandboxOptions():getOptionByName("EnableTaintedWaterText"):getValue() end)
            if okT and tainted and show then
                rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Tainted"), c = { r = 0.9, g = 0.3, b = 0.25 } }
            end
        end
    end
    local isFood = instanceof(item, "Food")
    if isFood or cap > 0 then
        local heat = 1
        if (isFood or instanceof(item, "DrainableComboItem")) and item.getHeat then heat = item:getHeat() or 1
        elseif item.getItemHeat then heat = item:getItemHeat() or 1 end
        local frozen = isFood and item.isFrozen and item:isFrozen()
        local k, c
        if frozen and heat <= 1.05 then k, c = "Frozen", { r = 0.55, g = 0.8, b = 1 }
        elseif heat >= 1.6 then k, c = "Hot", { r = 1, g = 0.45, b = 0.25 }
        elseif heat > 1.05 then k, c = "Warm", { r = 1, g = 0.75, b = 0.35 }
        elseif heat < 0.95 then k, c = "Cold", { r = 0.5, g = 0.75, b = 1 }
        else k, c = "Room", T.dim end
        if cap <= 0 then sep() end
        kv(tx("IGUI_TGI_Temp"), tx("IGUI_TGI_Temp" .. k), c)
        if k ~= "Room" then rows[#rows].icon = (k == "Hot" or k == "Warm") and "temp_hot" or "temp_cold" end
    end

    local okT, tip = pcall(function() return item:getTooltip() end)
    if okT and tip and tostring(tip) ~= "" then
        local txt = getText(tostring(tip))
        if txt and txt ~= "" and txt ~= tostring(tip) then
            txt = string.gsub(txt, "<br>", " ")
            txt = string.gsub(txt, "<[^>]*>", "")
            sep()

            local line = ""
            for word in string.gmatch(txt, "%S+") do
                if line ~= "" and #line + #word > 44 then
                    rows[#rows + 1] = { kind = "note", v = line, c = T.dim }
                    line = word
                else
                    line = line == "" and word or (line .. " " .. word)
                end
            end
            if line ~= "" then rows[#rows + 1] = { kind = "note", v = line, c = T.dim } end
        end
    end

    if ALifeTrade and ALifeTrade.value then
        local okv, v = pcall(ALifeTrade.value, item)
        if okv and v then
            sep()
            local rate = ALifeTrade.moneyRate and ALifeTrade.moneyRate(nil) or 0
            local mb = ALifeTrade.moneyBase and ALifeTrade.moneyBase(item)
            if mb then kv(tx("IGUI_TGI_Worth"), string.format("%.1f  (x%.2f)", mb * rate, rate), T.accent)
            elseif rate > 0.001 then kv(tx("IGUI_TGI_Worth"), string.format("%d  (~%d $)", v, math.floor(v / rate + 0.5)), T.accent)
            else kv(tx("IGUI_TGI_Worth"), tostring(v), T.accent) end
        end
    end

    local other, cmp = nil, nil
    if not TGI.Options or TGI.Options.get("compare") ~= false then other, cmp = TGI.Compare.rows(getSpecificPlayer(pn), item) end
    if cmp then
        sep()
        rows[#rows + 1] = { kind = "note", v = tx("IGUI_TGI_Compare") .. " " .. other:getDisplayName(), c = T.dim }
        for _, r in ipairs(cmp) do rows[#rows + 1] = { kind = "cmp", l = r.label, new = r.new, old = r.old, fmt = r.fmt, lower = r.lower, li = iconOf[r.label], lt = tintOf[r.label] } end
    end
    return rows
end

function Tip:new()
    local o = ISPanel:new(0, 0, W, 60)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.alwaysOnTop = true
    return o
end

local function rowH(r)
    if r.kind == "sep" then return 7 elseif r.kind == "icons" then return 26 elseif r.kind == "bar" then return lineH() + 2 end
    return lineH()
end

function Tip:setItem(item, pn, opts)

    local now = getTimestampMs()
    if self.item == item and self.hiddenBag == (opts.hiddenBag == true) and now - (self.builtAt or 0) < 1000 then return end
    self.builtAt = now
    self.item, self.hiddenBag = item, opts.hiddenBag == true
    local ok, rows = pcall(build, item, pn, opts)
    self.rows = ok and rows or {}
    self.name = item:getDisplayName()

    local tm = getTextManager()
    local nw = TGI.Theme.measure(FM(), self.name) + PAD * 2

    local cw = 0
    local function mw(t) return TGI.Theme.measure(FS(), tostring(t or "")) end
    for _, r in ipairs(self.rows) do
        local lx = PAD + ((r.li and r.l ~= "") and 19 or 0)
        local need = 0
        if r.kind == "kv" then need = lx + mw(r.l) + 18 + mw(r.v) + (r.icon and 18 or 0) + PAD
        elseif r.kind == "bar" then need = math.max(lx + mw(r.l) + 10, 132) + 60 + 8 + mw(r.v) + PAD
        elseif r.kind == "note" then need = PAD * 2 + mw(r.v)
        elseif r.kind == "cmp" then
            local d = r.new - r.old
            local txt = string.format(r.fmt .. " > " .. r.fmt .. "  (%s" .. r.fmt .. ")", r.old, r.new, d > 0 and "+" or "", d)
            need = lx + mw(r.l) + 18 + mw(txt) + PAD
        end
        if need > cw then cw = need end
    end
    local w = math.max(W, math.min(480, math.max(nw, cw)))
    self:setWidth(w)
    self.nameLines = { self.name }
    if nw > w then
        local a, b = "", ""
        for word in string.gmatch(self.name, "%S+") do
            if b == "" and TGI.Theme.measure(FM(), a .. (a == "" and "" or " ") .. word) <= w - PAD * 2 then
                a = a .. (a == "" and "" or " ") .. word
            else
                b = b .. (b == "" and "" or " ") .. word
            end
        end
        self.nameLines = { a, b }
    end
    self.headH = (big() and 50 or 40) + (#self.nameLines - 1) * (big() and 24 or 18)
    local okc, cat = pcall(catName, item)
    self.cat = okc and cat or ""
    self.tr, self.tg, self.tb = T.tileColor(item)
    local h = self.headH + 4
    for _, r in ipairs(self.rows) do h = h + rowH(r) end
    self:setHeight(h + PAD)
end

function Tip:prerender()
    local w, h = self.width, self.height
    self:drawRect(0, 0, w, h, 0.94, T.bg.r, T.bg.g, T.bg.b)
    T.metalFill(self, 0, 0, w, h, 0.6)

    local grad = T.grad()
    local hh = self.headH or 40
    self:drawRect(0, 0, w, hh, 0.6, 0.05, 0.05, 0.05)
    if grad then self:drawTextureScaled(grad, 0, 0, w, hh, 0.45, self.tr, self.tg, self.tb) end
    self:drawRect(0, hh, w, 1, 0.9, self.tr, self.tg, self.tb)
    self:drawRectBorder(0, 0, w, h, 1, self.tr * 0.7 + 0.1, self.tg * 0.7 + 0.1, self.tb * 0.7 + 0.1)
    for li, ln in ipairs(self.nameLines or { self.name or "" }) do
        self:drawText(D._short(ln, w - PAD * 2, FM()), PAD, 3 + (li - 1) * (big() and 24 or 18), T.text.r, T.text.g, T.text.b, 1, FM())
    end
    self:drawText(self.cat or "", PAD, hh - (big() and 22 or 18), T.dim.r, T.dim.g, T.dim.b, 1, FS())
    local y = hh + 8
    for _, r in ipairs(self.rows or {}) do
        local c = r.c
        local cr, cg, cb = T.text.r, T.text.g, T.text.b
        if c then cr, cg, cb = c.r or c[1], c.g or c[2], c.b or c[3] end
        local lx = PAD
        local li = r.li and r.l ~= "" and D.tex("ic_" .. r.li)
        if li then
            local t = r.lt or (r.kind == "kv" and c and { r = cr, g = cg, b = cb }) or T.dim
            self:drawTextureScaled(li, PAD, y + 1, 14, 14, 0.95, t.r, t.g, t.b)
            lx = PAD + 19
        end
        if r.kind == "kv" then
            self:drawText(r.l, lx, y, T.dim.r, T.dim.g, T.dim.b, 1, FS())
            self:drawTextRight(r.v, w - PAD, y, cr, cg, cb, 1, FS())
            local ic = r.icon and D.tex(r.icon)
            if ic then
                local tw = TGI.Theme.measure(FS(), r.v)
                self:drawTextureScaled(ic, w - PAD - tw - 16, y + 1, 13, 13, 1, cr, cg, cb)
            end
        elseif r.kind == "bar" then
            self:drawText(r.l, lx, y, T.dim.r, T.dim.g, T.dim.b, 1, FS())
            self:drawTextRight(r.v, w - PAD, y, T.text.r, T.text.g, T.text.b, 1, FS())
            local vw = TGI.Theme.measure(FS(), tostring(r.v or ""))
            local bx = math.max(132, lx + TGI.Theme.measure(FS(), r.l) + 10)
            local bw = math.max(30, w - PAD - vw - 10 - bx)
            local by = y + 6
            if not c then
                cr, cg, cb = 1 - r.f, 0.35 + 0.55 * r.f, 0.2
            end
            self:drawRect(bx, by, bw, 5, 0.9, 0.02, 0.02, 0.02)
            self:drawRect(bx, by, bw * r.f, 5, 0.95, cr, cg, cb)
            self:drawRectBorder(bx, by, bw, 5, 0.7, T.border.r, T.border.g, T.border.b)
        elseif r.kind == "sep" then
            self:drawRect(PAD, y + 3, w - PAD * 2, 1, 0.5, T.border.r, T.border.g, T.border.b)
        elseif r.kind == "note" then
            self:drawText(D._short(r.v, w - PAD * 2, FS()), PAD, y, cr, cg, cb, 1, FS())
        elseif r.kind == "cmp" then
            local d = r.new - r.old
            local good = (d > 0) ~= (r.lower == true)
            self:drawText(r.l, lx, y, T.dim.r, T.dim.g, T.dim.b, 1, FS())
            local txt = string.format(r.fmt .. " > " .. r.fmt .. "  (%s" .. r.fmt .. ")", r.old, r.new, d > 0 and "+" or "", d)
            if good then self:drawTextRight(txt, w - PAD, y, 0.45, 0.9, 0.45, 1, FS())
            else self:drawTextRight(txt, w - PAD, y, 0.95, 0.4, 0.35, 1, FS()) end
        elseif r.kind == "icons" then
            for i, t in ipairs(r.list) do
                if t then self:drawTextureScaledAspect(t, PAD + (i - 1) * 18, y + 3, 16, 16, 1, 1, 1, 1) end
            end
        end
        y = y + rowH(r)
    end
end

function Tip.show(item, owner, pn, opts)
    if not item then return Tip.hide(owner) end
    if TGI.Options and TGI.Options.get("tooltips") == false then return Tip.hide(owner) end
    local t = Tip.inst
    if not t then
        t = Tip:new(); t:initialise(); Tip.inst = t
    end
    t.owner = owner
    t:setItem(item, pn or 0, opts or {})
    local mx, my = TGI.mx and TGI.mx() or getMouseX(), TGI.my and TGI.my() or getMouseY()
    local x, y = mx + 18, my + 18
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    if x + t.width > sw then x = mx - t.width - 10 end
    if y + t.height > sh then y = math.max(0, sh - t.height) end
    t:setX(x); t:setY(y)
    if not t.shown then t:addToUIManager(); t.shown = true end
    t:setVisible(true)
    t:bringToTop()
end

function Tip.hide(owner)
    local t = Tip.inst
    if not t or not t.shown then return end
    if owner and t.owner ~= owner then return end
    t:setVisible(false)
    t:removeFromUIManager()
    t.shown = false
    t.item = nil
end

Tip.build = build
return Tip
