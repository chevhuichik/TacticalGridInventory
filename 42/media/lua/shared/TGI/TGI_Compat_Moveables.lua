require "Moveables/ISMoveableSpriteProps"

TGI = TGI or {}
local C = {}
TGI.CompatMoveables = C

C.vanilla = ISMoveableSpriteProps and ISMoveableSpriteProps.placeMoveableInternal or nil

local function fix()
    if not (ISMoveableSpriteProps and C.vanilla) then return end
    local cur = ISMoveableSpriteProps.placeMoveableInternal
    if cur == C.vanilla or cur == C.fixed then return end
    local NMW = rawget(_G, "NicksMoveableWorkstations")
    if not (NMW and NMW.reconstruct) then return end
    local orig = C.vanilla
    C.fixed = function(self, _character, _square, _item, _spriteName)
        local obj = orig(self, _character, _square, _item, _spriteName)
        if obj and NMW.reconstruct.stationForSprite then
            local station = NMW.reconstruct.stationForSprite(_spriteName)
            if station then
                local ok, repaired = pcall(NMW.reconstruct.repair, obj, station)
                if ok and repaired then return repaired end
            end
        end
        return obj
    end
    ISMoveableSpriteProps.placeMoveableInternal = C.fixed
    print("[TGI] furniture placement: Nicks Moveable Workstations wrapper fixed for the 42.21 arguments")
end
C.fix = fix

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(fix) end
    if Events.OnGameStart then Events.OnGameStart.Add(fix) end
    if Events.OnServerStarted then Events.OnServerStarted.Add(fix) end
end

return C
