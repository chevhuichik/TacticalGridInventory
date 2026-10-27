TGI = TGI or {}
local NO_STASH = { "shel", "rack", "seat", "display", "dish", "trash", "garbage", "floor" }

local NO_STASH_EXACT = { bin = true, dumpster = true, recyclingbin = true, trashcan = true }
function TGI.stashForbidden(ctype, obj)
    local t = string.lower(tostring(ctype or ""))
    if NO_STASH_EXACT[t] then return true end
    for _, k in ipairs(NO_STASH) do if string.find(t, k, 1, true) then return true end end
    if obj and instanceof(obj, "BaseVehicle") then
        return string.find(t, "glove", 1, true) == nil and string.find(t, "trunk", 1, true) == nil
    end
    return false
end
return TGI
