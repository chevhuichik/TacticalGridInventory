TGI = TGI or {}
local Y = {}
TGI.Sync = Y
Y.gen = 0

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

function Y.loc(container, depth)
    depth = depth or 0
    if not container or depth > 2 then return nil end
    local bag = safe(function() return container:getContainingItem() end, nil)
    if bag then
        local outer = safe(function() return bag:getContainer() end, nil)
        local l = Y.loc(outer, depth + 1)
        if not l then return nil end
        l.bags = l.bags or {}
        l.bags[#l.bags + 1] = bag:getID()
        return l
    end
    local part = safe(function() return container:getVehiclePart() end, nil)
    if part then
        local v = part:getVehicle()
        return { v = v:getId(), p = part:getId() }
    end
    local obj = safe(function() return container:getParent() end, nil)
    if not obj or instanceof(obj, "IsoGameCharacter") then return nil end
    local sq = safe(function() return obj:getSquare() end, nil)
    if not sq then return nil end
    local oi = sq:getObjects():indexOf(obj)
    if oi < 0 then return nil end
    local ci = 0
    for i = 0, obj:getContainerCount() - 1 do
        if obj:getContainerByIndex(i) == container then ci = i; break end
    end
    return { x = sq:getX(), y = sq:getY(), z = sq:getZ(), o = oi, c = ci }
end

function Y.resolve(l)
    if not l then return nil end
    local cont
    if l.v then
        local veh = safe(function() return getVehicleById(l.v) end, nil)
        local part = veh and safe(function() return veh:getPartById(l.p) end, nil)
        cont = part and safe(function() return part:getItemContainer() end, nil)
    else
        local sq = getCell():getGridSquare(l.x, l.y, l.z)
        if not sq then return nil end
        local objs = sq:getObjects()
        if l.o >= objs:size() then return nil end
        local obj = objs:get(l.o)
        cont = obj and safe(function() return obj:getContainerByIndex(l.c) end, nil)
    end
    if cont and l.bags then
        for _, id in ipairs(l.bags) do
            local b = safe(function() return cont:getItemById(id) end, nil)
            cont = b and instanceof(b, "InventoryContainer") and b:getInventory() or nil
            if not cont then return nil end
        end
    end
    return cont
end

function Y.apply(cmd, args)
    local cont = Y.resolve(args.l)
    if not cont then return false end
    local it = safe(function() return cont:getItemById(args.id) end, nil)
    if not it then return false end
    local md = it:getModData()
    if cmd == "pos" then
        md.TGI = args.d
    elseif cmd == "seen" then
        md.TGIs = true
        if TGI.Search and TGI.Search.seen then TGI.Search.seen[args.id] = true end
    end
    Y.gen = Y.gen + 1
    return true
end
