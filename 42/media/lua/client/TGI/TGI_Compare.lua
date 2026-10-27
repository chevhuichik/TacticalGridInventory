TGI = TGI or {}
local C = {}
TGI.Compare = C

local function row(out, label, a, b, fmt, lower)
    if a == nil or b == nil or math.abs(a - b) < 0.001 then return end
    out[#out + 1] = { label = getText(label), new = a, old = b, fmt = fmt or "%.0f", lower = lower }
end

function C.rows(p, item)
    if not p or not item then return nil end
    local other, out = nil, {}
    if instanceof(item, "HandWeapon") and TGI.Model.isRealWeapon(item) then
        other = p:getPrimaryHandItem()
        if not other or other == item or not TGI.Model.isRealWeapon(other) then return nil end
        row(out, "IGUI_TGI_CmpDamage", item:getMaxDamage(), other:getMaxDamage(), "%.1f")
        row(out, "IGUI_TGI_CmpRange", item:getMaxRange(), other:getMaxRange(), "%.1f")
        row(out, "IGUI_TGI_CmpSpeed", item:getBaseSpeed(), other:getBaseSpeed(), "%.2f")
        row(out, "IGUI_TGI_CmpCondition", item:getCondition(), other:getCondition())
        row(out, "IGUI_TGI_CmpWeight", item:getActualWeight(), other:getActualWeight(), "%.1f", true)
    else
        if not (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer")) then return nil end
        local loc = nil
        if instanceof(item, "Clothing") then loc = item:getBodyLocation() else loc = item:canBeEquipped() end
        if not loc or tostring(loc) == "" then return nil end
        local ok = pcall(function() other = p:getWornItem(loc) end)
        if not ok then other = nil end

        if not other or other == item then
            other = nil
            local worn = p:getWornItems()
            local grp = worn and worn.getBodyLocationGroup and worn:getBodyLocationGroup() or nil
            if worn and grp then
                for i = 0, worn:size() - 1 do
                    local wi = worn:get(i)
                    local it = wi:getItem()
                    if it ~= item and grp:isExclusive(loc, wi:getLocation()) then other = it; break end
                end
            end
        end
        if not other or other == item then return nil end
        if instanceof(item, "Clothing") and instanceof(other, "Clothing") then
            row(out, "IGUI_TGI_CmpBite", item:getBiteDefense(), other:getBiteDefense())
            row(out, "IGUI_TGI_CmpScratch", item:getScratchDefense(), other:getScratchDefense())
            row(out, "IGUI_TGI_CmpBullet", item:getBulletDefense(), other:getBulletDefense())
            row(out, "IGUI_TGI_CmpInsul", item:getInsulation() * 100, other:getInsulation() * 100)
            row(out, "IGUI_TGI_CmpWind", item:getWindresistance() * 100, other:getWindresistance() * 100)
        end
        if instanceof(item, "InventoryContainer") and instanceof(other, "InventoryContainer") then
            row(out, "IGUI_TGI_CmpCapacity", item:getCapacity(), other:getCapacity())
            row(out, "IGUI_TGI_CmpReduce", item:getWeightReduction(), other:getWeightReduction())

            local inside = 0
            pcall(function() inside = other:getInventory():getContentsWeight() end)
            local over = inside - item:getCapacity()
            if over > 0.05 then
                out[#out + 1] = { label = getText("IGUI_TGI_CmpNoFit"), new = over, old = 0, fmt = "%.1f", lower = true }
            end
        end
    end
    if #out == 0 then return nil end
    return other, out
end

local MAIN = {}
C._v = {}
function C.verdict(p, item)
    if not p or not item then return 0 end
    local id = item:getID()
    local now = getTimestampMs()
    local c = C._v[id]
    if c and now - c.t < 1000 then return c.v end
    if not c then
        C._n = (C._n or 0) + 1
        if C._n > 3000 then C._v, C._n = {}, 1 end
    end
    local v = 0
    local ok, other, rows = pcall(C.rows, p, item)
    if ok and rows and #rows > 0 then
        if not MAIN[1] then
            MAIN = { [getText("IGUI_TGI_CmpDamage")] = 2, [getText("IGUI_TGI_CmpBite")] = 2,
                [getText("IGUI_TGI_CmpScratch")] = 2, [getText("IGUI_TGI_CmpCapacity")] = 2, [1] = true }
        end
        local score = 0
        for _, r in ipairs(rows) do
            local d = r.new - r.old
            local s = (d > 0) and 1 or -1
            if r.lower then s = -s end
            score = score + s * (MAIN[r.label] or 1)
        end
        v = score > 0 and 1 or (score < 0 and -1 or 0)
    end
    C._v[id] = { t = now, v = v }
    return v
end

return C
