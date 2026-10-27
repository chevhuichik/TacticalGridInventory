TGI = TGI or {}
local U = {}
TGI.Guns = U

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

local function ammoKey(it)
    if not it or not it.getAmmoType then return nil end
    local a = safe(function() return it:getAmmoType() end, nil)
    if a == nil then return nil end
    if type(a) == "string" then return a end
    if a.getItemKey then return safe(function() return a:getItemKey() end, nil) end
    return tostring(a)
end
U.ammoKey = ammoKey

local function isGun(it)
    return it and instanceof(it, "HandWeapon") and safe(function() return it:isRanged() end, false)
end
local function isMag(it)
    return it and not instanceof(it, "HandWeapon") and safe(function() return it:getMaxAmmo() > 0 end, false) and ammoKey(it) ~= nil
end
U.isGun, U.isMag = isGun, isMag

function U.kind(src, target)
    if not src or not target or src == target then return nil end
    local ft = safe(function() return src:getFullType() end, "")
    if isGun(target) then
        local mt = safe(function() return target:getMagazineType() end, nil)
        if mt and mt ~= "" and mt == ft then return "mag" end
        if (not mt or mt == "") and ammoKey(target) == ft
            and safe(function() return target:getCurrentAmmoCount() < target:getMaxAmmo() end, false) then return "load" end
        return nil
    end
    if isMag(target) and ammoKey(target) == ft
        and safe(function() return target:getCurrentAmmoCount() < target:getMaxAmmo() end, false) then return "fill" end
    return nil
end

function U.apply(pn, src, target)
    local p = getSpecificPlayer(pn)
    local k = U.kind(src, target)
    if not p or not k then return false end
    local CM = ISInventoryPaneContextMenu
    if k == "mag" then

        if safe(function() return target:isContainsClip() end, false) then
            CM.transferIfNeeded(p, src)
            CM.equipWeapon(target, true, false, pn)
            ISTimedActionQueue.add(ISEjectMagazine:new(p, target))
            ISTimedActionQueue.add(ISInsertMagazine:new(p, target, src))
        else
            CM.onInsertMagazine(p, target, src)
        end
    elseif k == "load" then
        CM.onLoadBulletsIntoFirearm(p, target)
    elseif k == "fill" then
        local key = ammoKey(target)
        local have = p:getInventory():getItemCountRecurse(key)

        if have <= 0 and src:getContainer() ~= p:getInventory() then
            CM.transferIfNeeded(p, src); have = 1
        end
        local n = math.min(have, target:getMaxAmmo() - target:getCurrentAmmoCount())
        if n <= 0 then return false end
        CM.onLoadBulletsInMagazine(p, target, n)
    end
    return true
end

local fitCache = {}
function U.fitsFor(gun)
    if not isGun(gun) then return nil end
    local ft = gun:getFullType()
    local c = fitCache[ft]
    if c then return c end
    c = {}
    local mt = safe(function() return gun:getMagazineType() end, nil)
    if mt and mt ~= "" then c[mt] = true end
    local ak = ammoKey(gun)
    if ak then c[ak] = true end
    fitCache[ft] = c
    return c
end

return U
