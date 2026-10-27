require "TGI/TGI_Size"
if not isServer() then return end

local S = TGI.Size
local FILE = "TGI_sizes_server.txt"

local function load()
    S.server = {}
    local r = nil
    pcall(function() r = getFileReader(FILE, false) end)
    if not r then return end
    while true do
        local line = r:readLine()
        if line == nil then break end
        local ft, w, h = S.parseLine(line)
        if ft then S.server[ft] = { w, h } end
    end
    r:close()
end

local function save()
    local wr = getFileWriter(FILE, true, false)
    wr:write("# Tactical Grid Inventory: server item sizes (sent to every player, wins over their own lists)\n")
    wr:write("# One item per line, full type = WxH.\n")
    local keys = {}
    for ft in pairs(S.server) do keys[#keys + 1] = ft end
    table.sort(keys)
    for _, ft in ipairs(keys) do wr:write(ft .. " = " .. S.server[ft][1] .. "x" .. S.server[ft][2] .. "\n") end
    wr:close()
end

local function canEdit(player)
    local ok, v = pcall(function() return player:getRole():hasCapability(Capability.EditItem) end)
    if ok and v then return true end

    ok, v = pcall(function() return string.lower(tostring(player:getAccessLevel() or "")) == "admin" end)
    return ok and v == true
end

local loaded = false
local sizesAsked = {}
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "TGI" then return end
    if not loaded then loaded = true; pcall(load) end
    if command == "sizesReq" then

        local id, now = player:getOnlineID(), getTimestampMs()
        if now - (sizesAsked[id] or -1e9) < 30000 then return end
        sizesAsked[id] = now
        sendServerCommand(player, "TGI", "sizes", { list = S.server })
    elseif command == "sizeSet" then
        if not canEdit(player) or type(args) ~= "table" or type(args.ft) ~= "string" or #args.ft > 128 then return end
        local w, h = tonumber(args.w), tonumber(args.h)
        if w and h then
            w, h = math.floor(w), math.floor(h)
            if w < 1 or h < 1 or w > 10 or h > 10 then return end
            S.server[args.ft] = { w, h }
        else
            S.server[args.ft] = nil
        end
        pcall(save)
        sendServerCommand("TGI", "sizeSet", { ft = args.ft, w = w, h = h })
    end
end)
