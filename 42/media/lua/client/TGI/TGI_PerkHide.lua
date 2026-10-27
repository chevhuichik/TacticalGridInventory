require "XpSystem/ISUI/ISCharacterInfo"
if ISCharacterInfo and ISCharacterInfo.loadPerk and not ISCharacterInfo.tgiPerkWrapped then
    ISCharacterInfo.tgiPerkWrapped = true
    local orig = ISCharacterInfo.loadPerk
    ISCharacterInfo.loadPerk = function(self, ...)
        local perks = orig(self, ...)
        local S = TGI and TGI.Search
        if type(perks) ~= "table" or not S or not S.enabled or S.enabled() then return perks end
        local pk = S.perk and S.perk()
        if not pk then return perks end
        for parent, list in pairs(perks) do
            for i = #list, 1, -1 do
                if list[i] == pk then table.remove(list, i) end
            end
            if #list == 0 then perks[parent] = nil end
        end
        return perks
    end
end
