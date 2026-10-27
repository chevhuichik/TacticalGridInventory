require "TGI/TGI_Sync"
if not isServer() then return end

local RANGE = 8
local PER_SEC = 30

local budget = {}
local function allowRate(player)
    local id = player:getOnlineID()
    local now = getTimestampMs()
    local b = budget[id]
    if not b then b = { v = PER_SEC, t = now }; budget[id] = b end
    b.v = math.min(PER_SEC, b.v + (now - b.t) * PER_SEC / 1000)
    b.t = now
    if b.v < 1 then return false end
    b.v = b.v - 1
    return true
end
pcall(function() Events.OnPlayerDisconnect.Add(function(p) pcall(function() budget[p:getOnlineID()] = nil end) end) end)

local function near(player, l)
    if type(l) ~= "table" then return false end
    local x, y
    if l.v then
        local veh = getVehicleById(tonumber(l.v) or -1)
        if not veh then return false end
        x, y = veh:getX(), veh:getY()
    else
        x, y = tonumber(l.x), tonumber(l.y)
        if not x or not y then return false end
        if math.abs((tonumber(l.z) or 0) - player:getZ()) > 1 then return false end
    end
    return math.abs(x - player:getX()) <= RANGE and math.abs(y - player:getY()) <= RANGE
end

local function validPos(d)
    local function int(v) return type(v) == "number" and v == math.floor(v) end
    return type(d) == "table" and int(d.pi) and int(d.x) and int(d.y)
        and d.pi >= 0 and d.pi < 32 and d.x >= 0 and d.y >= 0 and d.x < 64 and d.y < 400
end

local function hasKey(inv, id, depth)
    if not inv or depth > 3 then return false end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if instanceof(it, "Key") and it:getKeyId() == id then return true end
        if instanceof(it, "InventoryContainer") and hasKey(it:getInventory(), id, depth + 1) then return true end
    end
    return false
end

local function lockOf(l)
    if type(l) ~= "table" or l.v then return nil end
    local x, y, z, o = tonumber(l.x), tonumber(l.y), tonumber(l.z), tonumber(l.o)
    if not (x and y and z and o) then return nil end
    local sq = getCell():getGridSquare(x, y, z)
    local objs = sq and sq:getObjects()
    local obj = objs and o >= 0 and o < objs:size() and objs:get(o) or nil
    if not obj or not obj:hasModData() then return nil end
    return obj:getModData().TGIlock
end

local xpLast = {}
local PICK_COOLDOWN = 4000
local pickTry = {}
local pickN = 0

local function unlock(player, args)
    local l = args.l
    if type(l) ~= "table" or l.v or l.bags then return end
    local sq = getCell():getGridSquare(l.x, l.y, l.z)
    local objs = sq and sq:getObjects()
    local obj = objs and type(l.o) == "number" and l.o >= 0 and l.o < objs:size() and objs:get(l.o) or nil
    if not obj or not obj:hasModData() then return end
    local md = obj:getModData()
    if md.TGIlock == nil then return end
    local ok = hasKey(player:getInventory(), md.TGIlock, 0)
    if not ok and args.pick == true then

        local inv = player:getInventory()
        local pin = inv:getFirstType("BobbyPin") or inv:getFirstType("HandmadeBobbyPin")
        local key = player:getOnlineID() .. ":" .. l.x .. "," .. l.y .. "," .. l.z .. ":" .. l.o
        local now = getTimestampMs()
        pickN = pickN + 1
        if pickN > 2000 then pickTry, pickN = {}, 1 end
        if pin and now - (pickTry[key] or 0) >= PICK_COOLDOWN then
            pickTry[key] = now
            local lvl = 0
            pcall(function() lvl = player:getPerkLevel(Perks.FromString("Lockpicking")) end)
            pcall(function() lvl = math.max(lvl, player:getPerkLevel(Perks.Nimble)) end)
            ok = ZombRand(100) < 45 + lvl * 6
        end
        if not ok then sendServerCommand(player, "TGI", "lockResult", { ok = false }) end
    end
    if not ok then

        obj:transmitModData()
        return
    end
    md.TGIlock = nil
    obj:transmitModData()
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "TGI" or type(args) ~= "table" or not player then return end
    if not allowRate(player) then return end
    if command == "searchXP" then

        local n = tonumber(args.n)
        local mult = 1
        pcall(function() mult = tonumber(SandboxVars.TGI.SearchXPMult) or 1 end)
        if not n or n <= 0 or n > 13 * math.max(1, mult) then return end
        local now = getTimestampMs()
        local id = player:getOnlineID()
        if now - (xpLast[id] or 0) < 300 then return end
        xpLast[id] = now
        pcall(function()
            local pk = Perks.FromString("Searching")
            if not pk or tostring(pk) == "MAX" then return end

            if addXp then addXp(player, pk, n) else player:getXp():AddXP(pk, n) end
        end)
        return
    end
    if not near(player, args.l) then return end
    if command == "unlock" then
        pcall(unlock, player, args)
        return
    end
    if command ~= "pos" and command ~= "seen" then return end

    local lk = lockOf(args.l)
    if lk ~= nil and not hasKey(player:getInventory(), lk, 0) then return end
    if command == "pos" and not validPos(args.d) then return end
    args.d = command == "pos" and { s = string.sub(tostring(args.d.s or ""), 1, 64), pi = args.d.pi, x = args.d.x, y = args.d.y, r = args.d.r == 1 and 1 or 0 } or nil

    local l = type(args.l) == "table" and args.l or {}
    local bags = {}
    if type(l.bags) == "table" then for i = 1, math.min(3, #l.bags) do bags[i] = tonumber(l.bags[i]) end end
    args = { l = { x = tonumber(l.x), y = tonumber(l.y), z = tonumber(l.z), o = tonumber(l.o), c = tonumber(l.c), v = tonumber(l.v), p = l.p and tostring(l.p) or nil, bags = bags },
        id = tonumber(args.id), d = args.d }
    local ok, done = pcall(TGI.Sync.apply, command, args)
    if not (ok and done) then return end
    args.from = player:getOnlineID()
    sendServerCommand("TGI", command, args)
end)
