TGI = TGI or {}
local K = {}
TGI.Keys = K

local function eachKey(inv, fn, depth)
    if not inv or (depth or 0) > 3 then return end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "Key") then fn(it) end
        if instanceof(it, "InventoryContainer") then eachKey(it:getInventory(), fn, (depth or 0) + 1) end
    end
end

local function label(p, id, data)
    if id == nil or id == -1 then return end
    eachKey(p:getInventory(), function(key)
        if key:getKeyId() == id then
            local md = key:getModData()
            if not md.TGIkey or md.TGIkey.x ~= data.x or md.TGIkey.v ~= data.v then md.TGIkey = data end
        end
    end)
end

local last = 0
local function tick()
    local now = getTimestampMs()
    if now - last < 2000 then return end
    last = now
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local veh = p:getVehicle()
    if veh and veh.getKeyId then
        local name = nil
        local sc = veh:getScript()
        if sc then
            local n = sc:getName()
            local t = getText("IGUI_VehicleName" .. n)
            name = (t ~= "IGUI_VehicleName" .. n) and t or n
        end
        label(p, veh:getKeyId(), { v = name or "?" })
        return
    end
    local sq = p:getCurrentSquare()
    local b = sq and sq:getBuilding()
    local def = b and b:getDef()
    if def and def.getKeyId then
        label(p, def:getKeyId(), { x = math.floor(def:getX() + def:getW() / 2), y = math.floor(def:getY() + def:getH() / 2) })
    end
end
Events.OnPlayerUpdate.Add(function(p) if p == getSpecificPlayer(0) then tick() end end)

local DIRS = { "IGUI_TGI_DirE", "IGUI_TGI_DirSE", "IGUI_TGI_DirS", "IGUI_TGI_DirSW", "IGUI_TGI_DirW", "IGUI_TGI_DirNW", "IGUI_TGI_DirN", "IGUI_TGI_DirNE" }

function K.describe(key, p)
    local md = key:hasModData() and key:getModData() or nil
    local k = md and md.TGIkey
    if not k then return nil end
    if k.v then return getText("IGUI_TGI_KeyCar", tostring(k.v)) end
    if not (p and k.x) then return nil end
    local dx, dy = k.x - p:getX(), k.y - p:getY()
    local dist = math.floor(math.sqrt(dx * dx + dy * dy))
    if dist < 15 then return getText("IGUI_TGI_KeyHouseHere") end

    local a = math.atan2(dy, dx)
    local i = math.floor((a / (2 * math.pi) * 8) + 0.5)
    i = ((i % 8) + 8) % 8
    local dir = DIRS[i + 1]
    if not dir then return nil end
    return getText("IGUI_TGI_KeyHouse", tostring(dist), getText(dir))
end

return K
