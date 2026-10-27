TGI = TGI or {}
local R = {}
TGI.Repair = R

local SEWING = { Needle = true, Thread = true, RippedSheets = true, DenimStrips = true, LeatherStrips = true,
    SutureNeedle = true, Scissors = true }

local findCache = {}

function R.find(tool, target)
    if not tool or not target or tool == target then return nil end
    local tt = tool:getType()
    if instanceof(target, "Clothing") and SEWING[tt] then return "garment" end

    local key = tt .. ">" .. tostring(target:getFullType())
    local c = findCache[key]
    if c then return c[1], c[2] end
    local res1, res2 = nil, nil
    findCache[key] = { nil, nil }
    pcall(function()
        local fixes = FixingManager.getFixes(target)
        if not fixes then return end
        for i = 0, fixes:size() - 1 do
            local fixers = fixes:get(i):getFixers()
            for j = 0, fixers:size() - 1 do
                if fixers:get(j):getFixerName() == tt then res1, res2 = i, j; return end
            end
        end
    end)
    findCache[key] = { res1, res2 }
    return res1, res2
end

function R.can(tool, target)
    if not target then return false end
    local a = R.find(tool, target)
    if a == nil then return false end
    if a == "garment" then return true end

    local ok, v = pcall(function() return target:getCondition() < target:getConditionMax() end)
    return ok and v
end

function R.apply(pn, tool, target)
    local p = getSpecificPlayer(pn)
    local a, b = R.find(tool, target)
    if a == nil or not p then return false end
    if a == "garment" then
        pcall(ISInventoryPaneContextMenu.onInspectClothing, p, target)
    else
        pcall(ISInventoryPaneContextMenu.onFix, target, pn, a, b)
    end
    return true
end

return R
