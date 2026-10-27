require "TGI/TGI_Sync"
local Y = TGI.Sync

function Y.send(cmd, item, data)
    if not isClient() then return end
    local p = getPlayer()
    if not p then return end
    local cont = item:getContainer()
    if not cont then return end
    if cont:isInCharacterInventory(p) then return end
    local l = Y.loc(cont)
    if not l then return end
    sendClientCommand(p, "TGI", cmd, { l = l, id = item:getID(), d = data })
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "TGI" or (command ~= "pos" and command ~= "seen") then return end
    local p = getPlayer()
    if p and args.from == p:getOnlineID() then return end
    pcall(Y.apply, command, args)
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "TGI" or command ~= "lockResult" then return end
    local p = getPlayer()
    if p and TGI.halo then TGI.halo(p, getText(args and args.ok and "IGUI_TGI_Forced" or "IGUI_TGI_ForceFail"), args and args.ok) end
    if TGI.Window then TGI.Window.containersDirty = true end
end)
