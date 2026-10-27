TGI = TGI or {}
local S = { overrides = {}, server = {}, cache = {} }
TGI.Size = S

local function safe(fn, default)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return default
end

local function has(s, needle) return s and string.find(string.lower(s), needle, 1, true) ~= nil end

function S.info(item)
    local i = {}
    i.fullType = safe(function() return item:getFullType() end, "")
    i.type = safe(function() return item:getType() end, "")
    i.cat = safe(function() return tostring(item:getDisplayCategory()) end, "")
    i.category = safe(function() return tostring(item:getCategory()) end, "")
    i.weight = tonumber(safe(function() return item:getActualWeight() end, 0.1)) or 0.1

    if not instanceof(item, "InventoryContainer") then
        local sw = tonumber(safe(function() return item:getScriptItem():getActualWeight() end, nil))
        if sw and sw > 0 then i.weight = sw end
    end
    i.isWeapon = safe(function() return instanceof(item, "HandWeapon") end, false)
    i.ranged = i.isWeapon and safe(function() return item:isRanged() end, false)
    i.twoHand = i.isWeapon and safe(function() return item:isTwoHandWeapon() end, false)
    i.maxRange = i.isWeapon and (tonumber(safe(function() return item:getMaxRange() end, 1)) or 1)
    i.isBag = safe(function() return instanceof(item, "InventoryContainer") end, false)
    i.capacity = i.isBag and (tonumber(safe(function() return item:getCapacity() end, 0)) or 0)
    i.bagEmpty = i.isBag and item:getInventory():getItems():isEmpty()
    i.isClothing = safe(function() return instanceof(item, "Clothing") end, false)
    i.bodyLoc = i.isClothing and tostring(item:getBodyLocation() or "") or ""
    if i.isBag then i.bodyLoc = tostring(safe(function() return item:canBeEquipped() end, "") or "") end
    i.isFood = safe(function() return instanceof(item, "Food") end, false)
    i.isLiterature = safe(function() return instanceof(item, "Literature") end, false)
    i.isMag = (not i.isWeapon) and safe(function() return item:getMaxAmmo() > 0 and item:getAmmoType() ~= nil end, false)
    i.isMoveable = safe(function() return instanceof(item, "Moveable") end, false)
    i.isPart = safe(function() return instanceof(item, "WeaponPart") end, false)
    i.isRadio = safe(function() return instanceof(item, "Radio") end, false)

    local fc = item.getFluidContainer and safe(function() return item:getFluidContainer() end, nil) or nil
    if type(fc) ~= "userdata" and type(fc) ~= "table" then fc = nil end
    i.fluidCap = fc and fc.getCapacity and (tonumber(safe(function() return fc:getCapacity() end, 0)) or 0) or 0
    return i
end

function S.rules(i)
    local wt, t, cat = i.weight, i.type, i.cat
    local fx = S.FIXED[t]
    if fx then return fx[1], fx[2] end
    local lt = string.lower(t or "")
    local bl = string.lower(i.bodyLoc or "")

    if i.isClothing and (bl == "tail" or bl:find(":tail", 1, true)) then return 1, 1 end
    if not i.isClothing and not i.isBag then
        local vcat = (cat == "VehicleMaintenance" or cat == "Mechanics" or cat == "CarParts" or i.category == "VehicleMaintenance")

        local repairBit = wt < 2 or lt:find("repair", 1, true) or lt:find("kit", 1, true)
        if not repairBit and (vcat or lt:find("tire", 1, true) or lt:find("cardoor", 1, true) or lt:find("carseat", 1, true)) then
            if lt:find("tire", 1, true) or lt:find("wheel", 1, true) then return 3, 3 end
            if lt:find("windshield", 1, true) then return 5, 3 end
            if lt:find("door", 1, true) or lt:find("hood", 1, true) or lt:find("trunklid", 1, true) or lt:find("bonnet", 1, true) then return 5, 4 end
            if lt:find("window", 1, true) then return 3, 2 end
            if lt:find("seat", 1, true) then return 3, 3 end
            if lt:find("muffler", 1, true) or lt:find("exhaust", 1, true) then return 4, 1 end
            if lt:find("gastank", 1, true) or lt:find("fueltank", 1, true) then return 3, 2 end
            if lt:find("battery", 1, true) or lt:find("brake", 1, true) or lt:find("suspension", 1, true) then return 2, 2 end
        end

        if (lt:find("guitar", 1, true) or lt:find("banjo", 1, true) or lt:find("bass", 1, true)) and cat == "Instrument" and wt >= 1 then return 5, 2 end
        if lt:find("keytar", 1, true) or lt:find("keyboard", 1, true) and cat == "Instrument" then return 4, 2 end
        if lt:find("violin", 1, true) or lt:find("saxophone", 1, true) or lt:find("trumpet", 1, true) then return 3, 1 end
        if lt:find("drum", 1, true) and cat == "Instrument" then return 3, 3 end
        if lt:find("flute", 1, true) or lt:find("recorder", 1, true) and cat == "Instrument" then return 2, 1 end

        if i.isWeapon and not i.ranged and lt:find("spear", 1, true) then return 5, 1 end
        if lt:find("umbrella", 1, true) then return 3, 1 end
        if lt:find("poolcue", 1, true) or lt:find("hockeystick", 1, true) or lt:find("golfclub", 1, true) then return 4, 1 end
    end

    if i.isClothing and (bl:find("knee", 1, true) or bl:find("elbow", 1, true)) then return 1, 1 end

    if i.isClothing and (lt:find("helmet", 1, true) or lt:find("^hat_army")) then return 2, 2 end

    if i.isFood and (lt:find("chop", 1, true) or lt:find("fillet", 1, true) or lt:find("steak", 1, true)
        or lt:find("wings", 1, true) or lt:find("meat$") and wt >= 0.25) then return 2, 1 end

    if i.isFood and (lt:find("^oil") or lt:find("vinegar", 1, true) or lt:find("sauce", 1, true) or lt:find("syrup", 1, true)
        or lt == "ketchup" or lt == "mustard" or lt == "sesameoil") and wt < 1 then return 2, 1 end

    if lt == "rope" or lt == "sheetrope" or lt:find("hose", 1, true) then return 2, 1 end

    if lt == "pan" or lt == "gridlepan" or lt == "saucepan" or lt:find("^saucepan") or (lt:find("kettle", 1, true) and not lt:find("mace", 1, true))
        or lt:find("fryingpan", 1, true) then return 2, 2 end

    if (i.isRadio and wt <= 3 and not i.isBag) or lt:find("cdplayer", 1, true) then return 2, 2 end

    if not i.isBag and not i.isClothing and (lt:find("bowl", 1, true) and not lt:find("bowling", 1, true)
        or lt == "plate" or lt == "clayplate" or lt:find("^plate") or lt:find("plate$") and (i.isFood or cat == "Cooking")) then
        return 1, 2
    end

    if lt:find("^toybear") or lt:find("teddybear", 1, true) then return 2, 2 end

    if lt:find("scissors", 1, true) and not lt:find("spear", 1, true) then return 2, 1 end

    if i.isFood and lt:find("sardine", 1, true) and not lt:find("box", 1, true) then return 2, 1 end

    if i.isClothing and (lt:find("earmuff", 1, true) or lt:find("hearing", 1, true) or lt:find("earprotect", 1, true)) then return 2, 1 end

    if i.isClothing and lt:find("longjohn", 1, true) then return 3, 2 end

    if (i.fluidCap or 0) >= 0.3 and (i.fluidCap or 0) < 1.5 and not lt:find("can", 1, true) and not lt:find("box", 1, true)
        and (lt:find("bottle", 1, true) or lt:find("beer", 1, true) or lt:find("wine", 1, true)) then return 1, 2 end

    if wt <= 0.05 and not i.isBag and not i.ranged and not i.isMoveable then return 1, 1 end
    if i.isMoveable then
        if wt >= 15 then return 6, 5 elseif wt >= 8 then return 5, 4 elseif wt >= 3 then return 4, 3 end
        return 3, 2
    end

    if lt:find("keyring", 1, true) or lt:find("key_ring", 1, true) or has(t, "keychain") then return 1, 1 end
    if i.isBag then
        local c = i.capacity or 0

        if has(i.bodyLoc, "fanny") or has(t, "fanny") then return 2, 1 end
        if has(t, "holster") or has(t, "bandolier") or has(t, "ammostrap") then return 2, 2 end

        if (t == "Bag_TrashBag" or lt:find("garbagebag", 1, true) or lt:find("trashbag", 1, true)) and not i.bagEmpty then return 3, 3 end

        if i.bagEmpty and i.weight <= 0.3 then
            if c <= 12 then return 1, 1 end
            return 2, 1
        end
        if c <= 1 then return 1, 1 elseif c <= 3 then return 1, 2 elseif c <= 6 then return 2, 2
        elseif c <= 16 then return 3, 3 elseif c <= 22 then return 4, 3 elseif c <= 28 then return 4, 4 end
        return 5, 5
    end
    if i.isWeapon then
        if i.ranged then

            local ln = string.lower(t or "")
            if ln:find("pistol", 1, true) or ln:find("revolver", 1, true) or ln:find("glock", 1, true)
                or ln:find("deagle", 1, true) or ln:find("m1911", 1, true) or ln:find("beretta", 1, true) then return 2, 2 end
            if ln:find("sniper", 1, true) or ln:find("barrett", 1, true) or ln:find("lmg", 1, true)
                or ln:find("m249", 1, true) or ln:find("m60", 1, true) or ln:find("pkm", 1, true) then return 5, 2 end
            if ln:find("smg", 1, true) or ln:find("uzi", 1, true) or ln:find("mp5", 1, true) or ln:find("mp7", 1, true)
                or ln:find("mac10", 1, true) or ln:find("mac11", 1, true) or ln:find("vector", 1, true) then return 3, 2 end
            if not i.twoHand then return 2, 2 end

            local lt = string.lower(t or "")
            local long = i.maxRange >= 55 or wt >= 5.5
            if S.LONG_GUNS[lt] then long = true end
            if long then return 5, 2 end
            if wt >= 2.5 or i.maxRange >= 35 then return 4, 2 end
            return 3, 2
        end

        if i.twoHand then
            if wt >= 4.0 then return 5, 2 end
            if wt >= 2.0 then return 4, 2 end
            return 4, 1
        end
        if wt >= 1.5 then return 3, 1 end
        if wt >= 0.6 then return 2, 1 end
        if has(t, "screwdriver") then return 2, 1 end

        if has(t, "knife") or has(t, "dagger") or has(t, "shiv") or has(t, "bayonet") or has(t, "cleaver") then return 2, 1 end
        return 1, 1
    end
    if i.isMag then return 1, 2 end
    local ps = S.PILE_SIZE[t]
    if ps then return ps[1], ps[2] end

    if (i.fluidCap or 0) > 0 and not i.isBag and not i.isClothing and not i.isWeapon then
        local c = i.fluidCap
        if c < 0.35 then return 1, 1 elseif c < 2.5 then return 1, 2 elseif c < 6 then return 2, 2 end
        return 3, 2
    end

    if cat == "Ammo" or (not i.isClothing and (has(t, "bullets") or has(t, "shotgunshells") or has(t, "rounds"))) then
        if has(t, "carton") or wt >= 2 then return 2, 2 end
        if has(t, "box") then return 1, 2 end
        return 1, 1
    end

    if i.isPart or cat == "WeaponPart" or cat == "Weapon Part" then return 1, 2 end
    if i.isLiterature or cat == "Literature" or cat == "SkillBook" or cat == "Cartography" then
        if wt >= 2 then return 2, 2 end
        if wt >= 0.6 then return 2, 1 end
        return 1, 1
    end
    if i.isClothing then

        local loc = string.lower(i.bodyLoc or "")

        if has(t, "holster") or has(t, "bandolier") or has(t, "ammostrap") or has(loc, "holster") or has(loc, "bandolier") then return 2, 2 end
        if has(loc, "belt") and not has(loc, "beltextra") then return 2, 1 end
        local short = loc:gsub("^.*:", "")
        local isHat = short == "hat" or short == "fullhat" or short == "eartop"
        if isHat or has(loc, "mask") or has(loc, "eyes") or has(loc, "ears") or has(loc, "neck")
            or has(loc, "hands") or has(loc, "ring") or has(loc, "wrist") or has(loc, "nose") or has(loc, "belly")
            or has(loc, "scarf") or has(loc, "socks") then
            if wt >= 0.5 then return 2, 1 end
            return 1, 1
        end
        if has(loc, "underwear") or has(loc, "undies") then return 1, 1 end

        if has(loc, "calf") or has(loc, "thigh") or has(loc, "forearm") or has(loc, "elbow") or has(loc, "knee")
            or has(loc, "shoulderpad") or has(loc, "gorget") or has(loc, "codpiece") or has(loc, "gaiter")
            or has(loc, "fullsuithead") then return 2, 1 end

        if (has(loc, "skirt") and not has(loc, "long")) or has(loc, "shortpants") or has(loc, "shortsshort")
            or has(loc, "tshirt") or has(loc, "tanktop") or has(loc, "shortsleeve") then return 2, 1 end

        if has(loc, "fullsuit") or has(loc, "boilersuit") or has(loc, "fulltop")
            or loc:gsub("^.*:", "") == "scba" then return 3, 2 end
        if wt < 0.35 then return 2, 1 end

        if wt >= 4.0 then return 3, 2 end
        return 2, 2
    end
    if i.isFood then
        if wt >= 1.5 then return 2, 2 end
        if wt >= 0.6 then return 1, 2 end
        return 1, 1
    end
    if cat == "FirstAid" or cat == "Medical" then
        if wt >= 1.0 then return 2, 2 end
        return 1, 1
    end
    if cat == "Electronics" or cat == "Communications" or cat == "LightSource" then
        if wt >= 3 then return 3, 2 end
        if wt >= 1 then return 2, 2 end
        if wt >= 0.4 then return 1, 2 end
        return 1, 1
    end
    if cat == "Material" or cat == "Materials" then
        if has(t, "plank") or has(t, "log") or has(t, "pipe") or has(t, "pole") then
            if wt >= 5 then return 5, 2 end
            return 4, 1
        end
        if wt >= 6 then return 3, 3 elseif wt >= 2.5 then return 2, 2 elseif wt >= 0.9 then return 2, 1 end
        return 1, 1
    end
    if cat == "Tool" or cat == "ToolWeapon" or cat == "Gardening" or cat == "Fishing" then
        if has(t, "rod") or has(t, "pole") then return 4, 1 end
        if wt >= 5 then return 3, 3 elseif wt >= 3 then return 3, 2 elseif wt >= 1.5 then return 3, 1 elseif wt >= 0.5 then return 2, 1 end
        return 1, 1
    end

    if wt >= 8 then return 4, 3 elseif wt >= 5 then return 3, 3 elseif wt >= 2.5 then return 3, 2
    elseif wt >= 1 then return 2, 2 elseif wt >= 0.35 then return 2, 1 end
    return 1, 1
end

function S.source(ft)
    if S.server[ft] then return "server" end
    if S.overrides[ft] then return "user" end
    return "auto"
end

function S.of(item)
    local ft = item:getFullType()
    local o = S.server[ft] or S.overrides[ft]
    if o then return o[1], o[2] end
    local isBag = instanceof(item, "InventoryContainer")

    if safe(function() return item:hasTag("base:uncutfish") or item:hasTag("UncutFish") end, false) then
        local kg = safe(function() return item:getActualWeight() end, 0.4)
        if kg < 0.5 then return 2, 1 elseif kg < 1.5 then return 3, 1 elseif kg < 4 then return 3, 2
        elseif kg < 9 then return 4, 2 end
        return 5, 2
    end
    local c = (not isBag) and S.cache[ft]
    if c then return c[1], c[2] end
    local w, h = S.rules(S.info(item))
    if not isBag then S.cache[ft] = { w, h } end
    return w, h
end

S.USER_FILE = "TGI_sizes.txt"
S.userCount = 0
function S.parseLine(line)
    line = string.gsub(line or "", "#.*$", "")
    local ft, w, h = string.match(line, "^%s*([%w_%.%-]+)%s*=%s*(%d+)%s*[xX*]%s*(%d+)%s*$")
    if not ft then return nil end
    w, h = tonumber(w), tonumber(h)
    if w < 1 or h < 1 or w > 10 or h > 10 then return nil end
    if not string.find(ft, ".", 1, true) then ft = "Base." .. ft end
    return ft, w, h
end
function S.loadUserFile()
    if not getFileReader then return end
    local r = nil
    pcall(function() r = getFileReader(S.USER_FILE, false) end)
    if not r then

        pcall(function()
            local wr = getFileWriter(S.USER_FILE, true, false)
            wr:write("# Tactical Grid Inventory: custom item sizes (width x height in cells)\n")
            wr:write("# One item per line, full type = WxH. Lines starting with # are ignored.\n")
            wr:write("# Base.Shotgun = 4x2\n")
            wr:close()
        end)
        return
    end
    local n = 0
    while true do
        local line = r:readLine()
        if line == nil then break end
        local ft, w, h = S.parseLine(line)
        if ft then S.overrides[ft] = { w, h }; n = n + 1 end
    end
    r:close()
    S.userCount = n
    S.cache = {}
    if n > 0 then print("[TGI] custom sizes loaded: " .. n) end
end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function() pcall(S.loadUserFile) end) end

function S.saveUserFile()
    local wr = getFileWriter(S.USER_FILE, true, false)
    wr:write("# Tactical Grid Inventory: custom item sizes (width x height in cells)\n")
    wr:write("# One item per line, full type = WxH. Lines starting with # are ignored.\n")
    wr:write("# Written by the in-game size editor; you can edit it by hand too.\n")
    local keys = {}
    for ft in pairs(S.overrides) do keys[#keys + 1] = ft end
    table.sort(keys)
    for _, ft in ipairs(keys) do
        local o = S.overrides[ft]
        wr:write(ft .. " = " .. o[1] .. "x" .. o[2] .. "\n")
    end
    wr:close()
    S.userCount = #keys
end

function S.changed()
    S.cache = {}
    if TGI.Sync then TGI.Sync.gen = (TGI.Sync.gen or 0) + 1 end
    if TGI.Window then TGI.Window.containersDirty = true end
end
function S.setUser(ft, w, h)
    if w and h then S.overrides[ft] = { w, h } else S.overrides[ft] = nil end
    pcall(S.saveUserFile)
    S.changed()
end

function S.auto(item)
    return S.rules(S.info(item))
end

S.PILES = {
    RippedSheets = 10, RippedSheetsDirty = 10, DenimStrips = 10, DenimStripsDirty = 10,
    LeatherStrips = 10, LeatherStripsDirty = 10, Thread = 5, Twine = 5,
    AlcoholRippedSheets = 10, Bandaid = 10, CottonBalls = 10,
    CigaretteSingle = 5, CigaretteRolled = 5,
    Sheet = 5, SheetDirty = 5, Tarp = 5,
    Bandage = 5, BandageDirty = 5, AlcoholBandage = 5,
    GrassTuft = 10, HayTuft = 10,
}

S.FIXED = { Plunger = { 1, 2 }, Plunger_BarbedWire = { 1, 2 }, Scythe = { 5, 2 },
    M203_Weapon = { 4, 2 },

    Pot = { 2, 2 }, PotForged = { 2, 2 }, PotOfSoup = { 2, 2 }, PotOfStew = { 2, 2 }, PotForgedStew = { 2, 2 },
    Cereal = { 2, 1 }, Salami = { 2, 1 }, Sausage = { 2, 1 }, Pepperoni = { 2, 1 }, Banana = { 2, 1 },
    Oxygen_Tank = { 2, 3 },

    Pasta = { 2, 1 }, Headphones = { 2, 1 }, Sandbag = { 2, 3 },
    Boilersuit = { 2, 3 }, Boilersuit_BlueRed = { 2, 3 }, Boilersuit_Flying = { 2, 3 }, Boilersuit_Prisoner = { 2, 3 },
    Boilersuit_PrisonerKhaki = { 2, 3 }, Boilersuit_SWAT = { 2, 3 }, Boilersuit_Yellow = { 2, 3 },
    BunnySuitPink = { 2, 2 }, BunnySuitBlack = { 2, 2 }, Agn_PocketWatch17 = { 1, 1 },

    Pillow = { 2, 2 }, Pillow_Crafted = { 2, 2 }, Pillow_Happyface = { 2, 2 }, Pillow_Heart = { 2, 2 }, Pillow_Star = { 2, 2 } }
S.LONG_GUNS = { huntingrifle = true, assaultrifle2 = true, msr7t_rifle = true, m24 = true, remington_700 = true,
    model_70 = true, mosin = true, m1903 = true, svd = true, psg1 = true, m14 = true, m1_garand = true, fal = true, g3 = true,
    bar = true, m60 = true }
S.PILE_SIZE = { Sheet = { 2, 2 }, SheetDirty = { 2, 2 }, Tarp = { 2, 2 } }
local function carKey(item, t)
    return t == "CarKey" or string.find(string.lower(t), "carkey", 1, true) ~= nil
end

S.AMMO_PER_CELL = { Bullets9mm = 50, Bullets45 = 50, Bullets38 = 50, Bullets357 = 50,
    Bullets44 = 20, ["308Bullets"] = 20, ["556Bullets"] = 20, ["3030Bullets"] = 20, ShotgunShells = 25 }
local ammoCache, ammoN = {}, 0
function S.ammoPerCell(item)
    local ft = item:getFullType()
    local v = ammoCache[ft]
    if v then return v end
    v = S.AMMO_PER_CELL[item:getType()]
    if not v then
        pcall(function()
            local sm = getScriptManager()
            local mod, t = ft:match("^(.-)%.(.+)$")

            local tries = { t .. "Box", t .. "_Box" }
            for _, w in ipairs({ "Bullets", "Bullet", "Shells", "Shell", "Rounds", "Round" }) do
                local r1 = t:gsub(w, "Box", 1)
                if r1 ~= t then tries[#tries + 1] = r1 end
            end
            local pre = t:match("^([^_]+)_")
            if pre then tries[#tries + 1] = pre .. "_Box" end
            for _, bt in ipairs(tries) do
                local box = sm:FindItem(mod .. "." .. bt)
                if box then
                    local r = box.getDoubleClickRecipe and box:getDoubleClickRecipe() or nil

                    local n = r and tonumber(tostring(r):match("(%d+)"))
                    if n and n > 0 and n <= 200 then v = n; return end
                end
            end
        end)
    end
    v = v or 30
    ammoN = ammoN + 1
    if ammoN > 500 then ammoCache, ammoN = {}, 1 end
    ammoCache[ft] = v
    return v
end

local function opt(id)
    local O = TGI and TGI.Options
    if O and O.get then return O.get(id) end
    return nil
end

local function isMag(item)
    return not safe(function() return instanceof(item, "HandWeapon") end, false)
        and safe(function() return item:getMaxAmmo() end, 0) > 0
end

function S.stackMax(item)
    local t = safe(function() return item:getType() end, "")

    if carKey(item, t) then return 10 end
    if S.PILES[t] then return S.PILES[t] end
    if safe(function() return instanceof(item, "Key") end, false) then return 10 end
    if S.stackable(item) then
        local cat = safe(function() return tostring(item:getDisplayCategory()) end, "")

        local tl = string.lower(t)
        if cat == "Ammo" or has(tl, "shell") or has(tl, "bullet") or has(tl, "casing") or has(tl, "pellet") then
            return opt("ammoBoxCell") == false and 999 or S.ammoPerCell(item)
        end
        return 999
    end
    return nil
end

function S.stackable(item)
    local t0 = safe(function() return item:getType() end, "")
    if carKey(item, t0) then return true end
    if S.PILES[t0] then return true end
    if safe(function() return instanceof(item, "Key") end, false) then return true end
    if isMag(item) then return false end

    local sw, sh = S.of(item)
    if (sw or 1) * (sh or 1) >= 4 then return false end
    local i = S.info(item)
    if i.isWeapon or i.isBag or i.isClothing then return false end
    if safe(function() return item:getConditionMax() end, 0) > 0 and safe(function() return item:getCondition() end, 0) < safe(function() return item:getConditionMax() end, 0) then return false end
    if safe(function() return instanceof(item, "DrainableComboItem") end, false) then return false end
    if i.isFood then return false end
    local t = string.lower(i.type)

    local round = i.cat == "Ammo" or has(t, "shell") or has(t, "bullet") or has(t, "casing") or has(t, "pellet")
    if round and not has(t, "box") and not has(t, "carton") and not has(t, "case") and i.weight <= 0.25 then return true end

    return i.weight <= 0.0501
end

return S
