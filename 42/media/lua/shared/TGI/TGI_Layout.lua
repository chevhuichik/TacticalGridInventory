TGI = TGI or {}
local L = {}
TGI.Layout = L

local CELLS_PER_WEIGHT = 2.5

local function has(s, n) return s and string.find(string.lower(s), n, 1, true) ~= nil end

local function arrange(sizes, maxW, gap)
    gap = gap or 1
    local out, x, y, rowH = {}, 0, 0, 0
    for _, s in ipairs(sizes) do
        if x > 0 and x + s[1] > maxW then x = 0; y = y + rowH + gap; rowH = 0 end
        out[#out + 1] = { w = s[1], h = s[2], x0 = x, y0 = y }
        x = x + s[1] + gap
        rowH = math.max(rowH, s[2])
    end
    return out
end

function L.kindFor(container, bagItem)
    if container == nil then return "world" end
    local t = ""
    pcall(function() t = tostring(container:getType()) end)
    if t == "floor" then return "floor" end
    if bagItem then
        local loc = ""
        pcall(function() loc = tostring(bagItem:getBodyLocation() or "") end)
        local ft = ""
        pcall(function() ft = bagItem:getFullType() end)
        if has(loc, "webbing") or has(loc, "vest") or has(loc, "belt") or has(loc, "fanny") or has(loc, "rig")
            or has(ft, "webbing") or has(ft, "rig") or has(ft, "fanny") or has(ft, "belt") then
            return "rig"
        end
        if has(loc, "back") or has(ft, "pack") then return "backpack" end
        return "bag"
    end
    return "world"
end

L.CLOTH_GROUPS = {
    { id = "legs",   sig = "L", label = "IGUI_TGI_PkLegs",   sizes = { { 1, 2 }, { 1, 2 } } },
    { id = "jacket", sig = "J", label = "IGUI_TGI_PkJacket", sizes = { { 1, 2 }, { 1, 2 } } },
    { id = "shirt",  sig = "S2", label = "IGUI_TGI_PkShirt",  sizes = { { 1, 1 }, { 1, 1 } } },
    { id = "vest",   sig = "V", label = "IGUI_TGI_PkVest",   sizes = { { 1, 1 }, { 1, 1 } } },

    { id = "under",  sig = "U", label = "IGUI_TGI_PkUnder",  sizes = { { 1, 2 } }, strictOnly = true },
}

local NAME_HINTS = {
    { "pants", { "trousers", "pants", "jeans", "shorts", "брюки", "штаны", "джинсы", "шорты" } },
    { "jacket", { "jacket", "coat", "parka", "hoodie", "куртк", "пальто", "парка", "толстовк" } },
    { "boilersuit", { "overall", "coverall", "boilersuit", "jumpsuit", "flightsuit", "hazmat", "комбинезон", "спецовк" } },
    { "shirt", { "shirt", "рубашк" } },
    { "vest", { "_vest", " vest", "vest_", "жилет" } },
}
function L.nameLoc(name)
    local n = " " .. string.lower(tostring(name or ""))
    if n == "" or n:find("under", 1, true) or n:find("long johns", 1, true) or n:find("longjohn", 1, true) then return nil end
    for _, h in ipairs(NAME_HINTS) do
        for _, w in ipairs(h[2]) do
            if n:find(w, 1, true) then return h[1] end
        end
    end
    return nil
end
function L.locKnown(loc)
    local _, _, sig = L.clothingPockets({ loc }, true)
    return sig ~= "n"
end

function L.clothingPockets(locs, noBase)
    local got = {}
    for _, l in ipairs(locs or {}) do
        local s = string.lower(tostring(l or "")):gsub("^.*:", "")
        if s == "underwearbottom" or s == "underwear" or s == "underwearextra1" then got.under = true end
        if not (s:find("under", 1, true) or s:find("head", 1, true)) then
            if s:find("fullsuit", 1, true) or s:find("boilersuit", 1, true) then got.legs = true; got.jacket = true
            elseif s:find("pants", 1, true) or s:find("trousers", 1, true) or s:find("shorts", 1, true) or s == "legs" then got.legs = true
            elseif s:find("jacket", 1, true) then got.jacket = true
            elseif (s == "shirt" or s:find("shortsleeveshirt", 1, true)) then got.shirt = true
            elseif s == "torsoextravest" or s == "vest" then got.vest = true end
        end
    end
    local out = noBase and {} or { { w = 4, h = 2, x0 = 0, y0 = 0 } }
    local sig, maxW = noBase and "n" or "", 8

    local x, y, rowH = 0, noBase and 1 or 3, 0
    for _, g in ipairs(L.CLOTH_GROUPS) do
        if got[g.id] and (noBase or not g.strictOnly) then
            sig = sig .. g.sig
            local gw = 0
            for _, sz in ipairs(g.sizes) do gw = gw + sz[1] end
            if x > 0 and x + gw > maxW then x = 0; y = y + rowH + 1; rowH = 0 end
            local first = true
            for _, sz in ipairs(g.sizes) do
                local p = { w = sz[1], h = sz[2], x0 = x, y0 = y }
                if first then p.label = g.label; p.labelW = gw; first = false end
                out[#out + 1] = p
                x = x + sz[1]
                rowH = math.max(rowH, sz[2])
            end
            x = x + 1
        end
    end
    local w = 4
    for _, p in ipairs(out) do w = math.max(w, p.x0 + p.w) end
    return out, w, ((sig == "" or sig == "n") and (noBase and "n" or "0") or sig)
end

function L.pockets(kind, capacity, fullType)

    local sv = SandboxVars and SandboxVars.TGI or {}
    local cpw = tonumber(sv.CellsPerWeight) or CELLS_PER_WEIGHT
    local cells = math.max(4, math.floor((capacity or 10) * cpw + 0.5))
    local cap = tonumber(sv.MaxContainerCells) or 0
    if cap > 0 then cells = math.min(cells, math.max(4, cap)) end
    if kind == "main" then

        return { { w = 4, h = 2, x0 = 0, y0 = 0 } }, 4
    elseif kind == "rig" then

        if cells <= 6 then
            local w = math.ceil(cells / 2)
            return { { w = w, h = 2, x0 = 0, y0 = 0 } }, 8
        end
        local sizes, left = {}, cells
        while left >= 4 and #sizes < 4 do sizes[#sizes + 1] = { 2, 2 }; left = left - 4 end
        local small = 0
        while left >= 2 and small < 4 do sizes[#sizes + 1] = { 1, 2 }; left = left - 2; small = small + 1 end
        if left >= 4 then sizes[#sizes + 1] = { 4, math.ceil(left / 4) }
        elseif left >= 2 then sizes[#sizes + 1] = { left, 1 } end
        return arrange(sizes, 8), 8
    elseif kind == "backpack" then

        local side = (cells >= 30 and not has(fullType, "hydration")) and 2 or 0
        local mainCells = cells - side * 2
        local w = math.max(3, math.min(6, math.ceil(math.sqrt(mainCells))))
        local h = math.max(2, math.ceil(mainCells / w))
        local out = { { w = w, h = h, x0 = 0, y0 = 0 } }

        for i = 1, side do out[#out + 1] = { w = 1, h = 2, x0 = w + 1, y0 = (i - 1) * 3 } end
        return out, 8
    elseif kind == "bag" then
        local w = math.max(2, math.min(6, math.ceil(math.sqrt(cells))))
        return { { w = w, h = math.max(1, math.ceil(cells / w)), x0 = 0, y0 = 0 } }, w
    else
        local w = 8
        return { { w = w, h = math.max(2, math.ceil(cells / w)), x0 = 0, y0 = 0, grow = true } }, w
    end
end

return L
