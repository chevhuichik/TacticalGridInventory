require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferAction"
require "ISUI/ISInventoryPaneContextMenu"

TGI = TGI or {}
local A = { pending = {}, inflight = {} }

local function empty(t) for _ in pairs(t) do return false end return true end
TGI.Actions = A

local function player(pn) return getSpecificPlayer(pn) end
local function safeMine(p, inv)
    local ok, v = pcall(function() return inv:isInCharacterInventory(p) end)
    return ok and v == true
end

local function try(fn)
    local ok, r = pcall(fn)
    return ok and r == true
end

A.noDrop = {}

function A.isEquipped(p, item)
    return try(function() return p:isEquipped(item) end)

        or try(function() return item:getContainer() == p:getInventory() and item:isEquipped() end)
        or try(function() return p:getWornItems():contains(item) end)
        or try(function() return p:isAttachedItem(item) end)
end

function A.sweepPending()
    local now = getTimestampMs()
    for id, pd in pairs(A.pending) do
        if pd.t and now - pd.t > 30000 then
            if A.inflight[id] and pd.item then pcall(A.inflightFor, pd.item) end
            if not A.inflight[id] then A.pending[id] = nil end
        end
    end

    local old = {}
    for id, f in pairs(A.inflight) do
        if f.t and now - f.t > 30000 and f.item then old[#old + 1] = f.item end
    end
    for _, it in ipairs(old) do pcall(A.inflightFor, it) end
end
local sweepAt = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now - sweepAt < 2000 then return end
    sweepAt = now
    A.sweepPending()
end)

function A.setPending(item, destSig, pi, x, y, rot)
    local w, h = 1, 1
    if TGI.Size then w, h = TGI.Size.of(item) end
    A.pending[item:getID()] = { sig = destSig, pi = pi, x = x, y = y, rot = rot, item = item, w = w, h = h, t = getTimestampMs() }
    A.sweepPending()
end

function A.inflightFor(item)
    if empty(A.inflight) then return nil end
    local f = A.inflight[item:getID()]
    if not f then return nil end
    local p = player(f.pn)
    local done = item:getContainer() == f.dest

    if not done and f.dest and f.dest:getType() == "floor" and item:getWorldItem() ~= nil then done = true end
    local queued = false
    if not done and p then
        local q = ISTimedActionQueue.getTimedActionQueue(p)
        if q and q.queue then
            local id = item:getID()
            for _, a in ipairs(q.queue) do
                if a == f.act or a.item == item then queued = true; break end

                for _, ql in ipairs(a.queueList or {}) do
                    for _, it in ipairs(ql.items or {}) do if it == item then queued = true; break end end
                    if queued then break end
                end
                if queued then break end
            end
        end
    end

    if not done and not queued and f.dest then
        local okD, there = pcall(function() return f.dest:getItemWithID(item:getID()) end)
        if okD and there then done = true end
    end
    if not done and not queued and isClient() then
        local now = getTimestampMs()
        f.goneAt = f.goneAt or now
        if now - f.goneAt < 4000 then return nil end
    end
    if done or not queued then
        A.inflight[item:getID()] = nil
        if not done then A.pending[item:getID()] = nil end
        return nil
    end
    return f
end

function A.progress(item)
    local ok, d = pcall(function() return item:getJobDelta() end)
    return (ok and d) or 0
end

local function opt(id, d)
    if TGI.Options then return TGI.Options.sandbox(id) end
    return d
end

local function locOf(inv)
    local ok, loc = pcall(function() return string.lower(tostring(inv:getContainingItem():getBodyLocation() or "")) end)
    if not ok then
        ok, loc = pcall(function() return string.lower(tostring(inv:getContainingItem():canBeEquipped() or "")) end)
    end
    return ok and loc or ""
end

local function wornBag(p, inv)
    local ok, v = pcall(function()
        local it = inv:getContainingItem()
        return it and (p:isEquipped(it) or p:getWornItems():contains(it))
    end)
    return ok and v
end

local function blockedOnRun(p, inv)
    if not inv or opt("BackpackOnRun", true) == false then return false end
    local running = false
    pcall(function() running = p:isRunning() or p:isSprinting() end)
    if not running then return false end
    return wornBag(p, inv) and string.find(locOf(inv), "back", 1, true) ~= nil
end

local function placeFactor(p, inv)
    if not inv or not wornBag(p, inv) then return 1 end
    local loc = locOf(inv)
    if string.find(loc, "webbing", 1, true) or string.find(loc, "rig", 1, true) then return 0.7 end
    if string.find(loc, "fanny", 1, true) then return 0.8 end
    if string.find(loc, "back", 1, true) then return 1.3 end
    return 1
end

local function isWorld(p, inv)
    if not inv then return false end
    if inv:getType() == "floor" then return false end
    local ok, mine = pcall(function() return inv:isInCharacterInventory(p) end)
    return not (ok and mine)
end

function A.log(p, inv, item, dir)
    pcall(function()
        local obj = inv:getParent()
        if not obj or not obj.getModData then return end
        local md = obj:getModData()
        md.TGIlog = md.TGIlog or {}
        local l = md.TGIlog
        table.insert(l, 1, { n = p:getDisplayName() or p:getUsername() or "?", i = item:getDisplayName(), d = dir,
            t = math.floor(getGameTime():getWorldAgeHours()) })
        while #l > 25 do table.remove(l) end
        if obj.transmitModData then obj:transmitModData() end
    end)
end

local function note(p, key)
    A.lastNote = { key = key, t = getTimestampMs() }
    TGI.halo(p, getText(key), false)
end

function A.wouldNest(item, dest)
    if not item or not dest then return false end
    if not instanceof(item, "InventoryContainer") then return false end
    local ok, own = pcall(function() return item:getInventory() end)
    if ok and own == dest then return true end
    local c = dest
    for _ = 1, 16 do
        local holder = nil
        pcall(function() holder = c:getContainingItem() end)
        if not holder then return false end
        if holder == item or holder:getID() == item:getID() then return true end
        local nxt = nil
        pcall(function() nxt = holder:getContainer() end)
        if not nxt or nxt == c then return false end
        c = nxt
    end
    return true
end

local function worldBag(p, c)
    if not (isClient and isClient()) or not c then return nil end
    local bag = c.getContainingItem and c:getContainingItem() or nil
    if not bag then return nil end

    local SC = rawget(_G, "SaucedCarts")
    if SC and SC.safeIsCart then
        local okC, isCart = pcall(SC.safeIsCart, bag)
        if okC and isCart then return nil end
    end
    local outer = bag:getContainer()
    if not outer or safeMine(p, outer) then return nil end
    for _ = 1, 5 do
        local up = outer.getContainingItem and outer:getContainingItem() or nil
        if not up then break end
        local upOuter = up:getContainer()
        if not upOuter or safeMine(p, upOuter) then break end
        bag, outer = up, upOuter
    end
    return bag, outer
end

function A.transfer(pn, items, dest)
    local p = player(pn)
    if not p or not dest then return end
    local borrowed = {}
    local function borrow(c)
        local bag, outer = worldBag(p, c)
        if not bag or borrowed[bag] then return end
        borrowed[bag] = outer
        local act = ISInventoryTransferAction:new(p, bag, outer, p:getInventory())
        act.tgiPrep = true
        A.lent[bag:getID()] = getTimestampMs()
        ISTimedActionQueue.add(act)
    end
    borrow(dest)
    for _, item in ipairs(items) do borrow(item:getContainer()) end
    A.transferList(pn, p, items, dest)
    for bag, outer in pairs(borrowed) do
        A.giveBack(p, bag, outer)
    end
end

A.borrowed = {}

A.lent = {}
function A.isLent(item)
    local now = getTimestampMs()
    local function lent(it)
        local t = it and A.lent[it:getID()]
        if t and now - t < 60000 then return true end
        if t then A.lent[it:getID()] = nil end
        return false
    end
    if lent(item) then return true end
    local c = item and item:getContainer()
    local bag = c and c.getContainingItem and c:getContainingItem()
    return lent(bag)
end
function A.giveBack(p, bag, outer)
    local act = ISInventoryTransferAction:new(p, bag, p:getInventory(), outer)
    local id = bag:getID()
    local e = A.borrowed[id] or { bag = bag, outer = outer, tries = 0, pn = p:getPlayerNum() }
    e.t = getTimestampMs()
    A.borrowed[id] = e
    local base = act.perform
    act.perform = function(a, ...)
        A.borrowed[id] = nil
        A.lent[id] = nil
        return base(a, ...)
    end
    ISTimedActionQueue.add(act)
end
local nextBorrowCheck = 0
Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now < nextBorrowCheck then return end
    nextBorrowCheck = now + 1000
    for id, e in pairs(A.borrowed) do
        local p = getSpecificPlayer(e.pn or 0)
        local q = p and ISTimedActionQueue.getTimedActionQueue(p)
        local idle = p and not (q and q.queue and #q.queue > 0)
        local c = nil
        pcall(function() c = e.bag:getContainer() end)
        if not p or c ~= p:getInventory() then
            A.borrowed[id] = nil
        elseif idle and now - e.t > 1500 then

            local sq = nil
            pcall(function() sq = e.outer:getSourceGrid() or (e.outer:getParent() and e.outer:getParent():getSquare()) end)
            local near = sq and p:getSquare() and sq:getZ() == p:getZ() and sq:DistToProper(p:getSquare()) <= 2
            A.lent[id] = now
            if near or not sq then
                e.tries = e.tries + 1
                A.giveBack(p, e.bag, e.outer)
            end
            if e.tries >= 3 and not e.told then
                e.told = true
                pcall(TGI.halo, p, getText("IGUI_TGI_BorrowedBag", e.bag:getDisplayName()), false)
            end
            if e.tries >= 10 then A.borrowed[id] = nil end
            return
        end
    end
end)

function A.noFloorMoveable(item)
    return instanceof(item, "Moveable") and not item:CanBeDroppedOnFloor()
end
A.placeWait = nil
function A.placeMoveable(pn, item)
    local p = getSpecificPlayer(pn or 0)
    if not p then return end
    local function start()
        local mo = ISMoveableCursor:new(p)
        getCell():setDrag(mo, mo.player)
        mo:setMoveableMode("place")
        mo:tryInitialItem(item)
    end
    if item:getContainer() == p:getInventory() then pcall(start); return end
    A.transfer(pn, { item }, p:getInventory())
    A.placeWait = { item = item, p = p, start = start, until_ = getTimestampMs() + 10000 }
end
Events.OnTick.Add(function()
    local w = A.placeWait
    if not w then return end
    if getTimestampMs() > w.until_ then A.placeWait = nil; return end
    if w.item:getContainer() == w.p:getInventory() then A.placeWait = nil; pcall(w.start) end
end)

function A.isAnimal(item)
    local t = ""
    pcall(function() t = item:getType() end)
    return t == "CorpseAnimal" or t == "Animal" or instanceof(item, "AnimalInventoryItem")
end

function A.transferList(pn, p, items, dest)
    local isFloor = dest:getType() == "floor"
    if isFloor then
        local rest = {}
        for _, item in ipairs(items) do
            if A.noFloorMoveable(item) then A.placeMoveable(pn, item) else rest[#rest + 1] = item end
        end
        items = rest
    end
    local mainInv = p:getInventory()
    local baseDest = dest
    for _, item in ipairs(items) do repeat
        dest = baseDest

        if dest == mainInv and item:getContainer() ~= mainInv and TGI.Strict and TGI.Strict.roomFor
            and not try(function() return TGI.Strict.roomFor(p, item, mainInv) end) then
            local W = TGI.Window
            local alt = W and W.overflowTarget and W.overflowTarget(p, item, true) or nil
            if alt and alt ~= mainInv and alt ~= item:getContainer() then dest = alt
            else
                note(p, "IGUI_TGI_NoRoom")
                A.pending[item:getID()] = nil
                break
            end
        end
        if not isFloor and dest.isItemAllowed and not dest:isItemAllowed(item) then
            note(p, "IGUI_TGI_NotAllowed")
            A.pending[item:getID()] = nil
            break
        end
        if not isFloor and item:getContainer() ~= dest and dest.hasRoomFor and not dest:hasRoomFor(p, item) then
            note(p, "IGUI_TGI_NoRoom")
            A.pending[item:getID()] = nil
            break
        end
        local src = item:getContainer()
        if not src and item.getWorldItem and item:getWorldItem() then

            pcall(function() getPlayerLoot(pn):refreshBackpacks() end)
            src = item:getContainer()
            if not src then
                local ok, fc = pcall(function() return ISInventoryPage.GetFloorContainer(pn) end)
                if ok and fc then src = fc end
            end
        end

        if src and src ~= dest and src.isRemoveItemAllowed and not try(function() return src:isRemoveItemAllowed(item) end) then
            A.pending[item:getID()] = nil
            break
        end
        local mineSrc = src and safeMine(p, src)
        if item:isFavorite() and mineSrc and not safeMine(p, dest) then
            note(p, "IGUI_TGI_Locked")
            A.pending[item:getID()] = nil
            break
        end
        if A.wouldNest(item, dest) then
            note(p, "IGUI_TGI_NoNest")
            A.pending[item:getID()] = nil
            break
        end
        if blockedOnRun(p, src) or blockedOnRun(p, dest) then
            note(p, "IGUI_TGI_NoRun")
            A.pending[item:getID()] = nil
            break
        end
        if try(function() return p:isAttachedItem(item) end) and ISDetachItemHotbar then
            ISTimedActionQueue.add(ISDetachItemHotbar:new(p, item))
            src = p:getInventory()
        elseif A.isEquipped(p, item) and not A.isAnimal(item) then
            ISTimedActionQueue.add(ISUnequipAction:new(p, item, 50))
            src = p:getInventory()
        end
        if src and src ~= dest then
            do
                local act = ISInventoryTransferAction:new(p, item, src, dest)
                act.tgiOwn = true
                if TGI.Return then TGI.Return.forget(item) end

                if opt("TransferSpeedByPlace", true) ~= false and (tonumber(act.maxTime) or 0) > 0 then
                    pcall(function()
                        local f = math.max(placeFactor(p, src), placeFactor(p, dest))
                        if placeFactor(p, src) < 1 and placeFactor(p, dest) <= 1 then f = placeFactor(p, src) end
                        act.maxTime = math.max(1, math.floor(act.maxTime * f))
                    end)
                end

                local logSrc, logDest = isWorld(p, src), isWorld(p, dest)

                if logSrc or logDest then
                    local base = act.transferItem
                    act.transferItem = function(a, it)
                        base(a, it)
                        if logSrc then pcall(A.log, p, src, it, -1) end
                        if logDest then pcall(A.log, p, dest, it, 1) end
                    end
                end
                ISTimedActionQueue.add(act)
                A.inflight[item:getID()] = { act = act, dest = dest, pn = pn, item = item, t = getTimestampMs() }
            end
        end
    until true end
end

function A.attachHotbar(pn, item)
    local hb = getPlayerHotbar and getPlayerHotbar(pn)
    if not hb or not hb.availableSlot then return false end
    local at = item:getAttachmentType()
    if not at then return false end
    local best, bestIdx = nil, nil
    for idx, slot in pairs(hb.availableSlot) do
        if hb:canBeAttached(slot, item) then
            if not hb.attachedItems[idx] then best, bestIdx = slot, idx; break end
            if not best then best, bestIdx = slot, idx end
        end
    end
    if not best then
        note(player(pn), "IGUI_TGI_NoHotbar")
        return false
    end
    hb:attachItem(item, best.def.attachments[at], bestIdx, best.def, true)
    return true
end

function A.fetch(pn, p, item)
    local inv = p:getInventory()
    local src = item:getContainer()
    if src == inv then return false end
    if src and safeMine(p, src) and src:getType() ~= "floor" then

        return false
    end
    if not src and item.getWorldItem and item:getWorldItem() then
        local ok, fc = pcall(function() return ISInventoryPage.GetFloorContainer(pn) end)
        if ok and fc then src = fc end
    end
    if not src then return false end

    if worldBag(p, src) then A.transfer(pn, { item }, inv); return true end
    local act = ISInventoryTransferAction:new(p, item, src, inv)
    act.tgiOwn = true
    ISTimedActionQueue.add(act)
    return true
end

function A.equip(pn, item)
    local p = player(pn)
    if not p or not item then return end
    local ok, err = pcall(function()
        local weapon = instanceof(item, "HandWeapon") or item:isTwoHandWeapon()
        local wear = (item:IsClothing() or item:IsInventoryContainer()) and item.getBodyLocation and item:getBodyLocation() ~= nil and tostring(item:getBodyLocation()) ~= ""
        if not weapon and not wear and item.canBeEquipped and item:canBeEquipped() and tostring(item:canBeEquipped()) ~= "" then wear = true end
        local src = item:getContainer()
        local carried = src == p:getInventory() or (src and safeMine(p, src) and src:getType() ~= "floor")

        if not carried and not wear and TGI.Strict and TGI.Strict.roomFor then
            local inv = p:getInventory()
            local fits = try(function() return TGI.Strict.roomFor(p, item, inv) end)
            local W = TGI.Window
            if not fits and not (W and W.overflowTarget and W.overflowTarget(p, item, true)) then
                note(p, "IGUI_TGI_NoRoom")
                return
            end
        end
        local fetched = A.fetch(pn, p, item)
        if fetched then
            if weapon or not wear then
                ISTimedActionQueue.add(ISEquipWeaponAction:new(p, item, 50, true, item:isTwoHandWeapon()))
            else
                ISTimedActionQueue.add(ISWearClothing:new(p, item, 50))
            end
        elseif weapon then
            ISInventoryPaneContextMenu.equipWeapon(item, true, item:isTwoHandWeapon(), pn)
        elseif wear then
            ISInventoryPaneContextMenu.wearItem(item, pn)
        else
            ISInventoryPaneContextMenu.equipWeapon(item, true, false, pn)
        end
    end)
    if not ok then print("[TGI] equip failed: " .. tostring(err)) end
    return ok
end

function A.equipHand(pn, item, primary)
    local p = player(pn)
    if not p or not item then return end
    local ok, err = pcall(function()
        local two = primary and item:isTwoHandWeapon() or false
        if A.fetch(pn, p, item) then ISTimedActionQueue.add(ISEquipWeaponAction:new(p, item, 50, primary, two))
        else ISInventoryPaneContextMenu.equipWeapon(item, primary, two, pn) end
    end)
    if not ok then print("[TGI] equip failed: " .. tostring(err)) end
end
function A.equipSecondary(pn, item) A.equipHand(pn, item, false) end

function A.unequip(pn, item)
    local p = player(pn)
    if p and A.isEquipped(p, item) then ISTimedActionQueue.add(ISUnequipAction:new(p, item, 50)) end
end

function A.putInTargets(pn, items)
    local p = player(pn)
    if not p then return {} end
    local inv = p:getInventory()
    local dests = { { c = inv, name = getText("IGUI_TGI_Pockets") } }
    local list = inv:getItems()
    for i = 0, list:size() - 1 do
        local b = list:get(i)
        if instanceof(b, "InventoryContainer") then
            local name = b:getDisplayName()
            if TGI.Labels and TGI.Labels.get then
                local okL, l = pcall(TGI.Labels.get, b:getInventory())
                if okL and l and l.t and l.t ~= "" then name = name .. " (" .. l.t .. ")" end
            end
            dests[#dests + 1] = { c = b:getInventory(), name = name, bag = b }
        end
    end
    local shown = {}
    for _, dst in ipairs(dests) do
        for _, it in ipairs(items) do
            if it ~= dst.bag and it:getContainer() ~= dst.c and not A.wouldNest(it, dst.c) then shown[#shown + 1] = dst; break end
        end
    end
    return shown
end
function A.putIn(pn, items, dst)
    local move = {}
    for _, it in ipairs(items) do
        if it ~= dst.bag and it:getContainer() ~= dst.c then move[#move + 1] = it end
    end
    if #move > 0 then A.transfer(pn, move, dst.c) end
    return move
end

local function cleanMenuItems(pn, items, inPlayerInv)
    local p = getSpecificPlayer(pn)
    if not p then return items end
    local out = {}
    for _, it in ipairs(items) do
        local keep = false
        pcall(function()
            local c = it:getContainer()
            if c then
                local mine = c == p:getInventory() or c:isInCharacterInventory(p)
                keep = (mine and true or false) == (inPlayerInv and true or false)
            end
        end)
        if keep then out[#out + 1] = it end
    end
    if #out == 0 then return items end
    return out
end

function A.contextMenu(pn, items, x, y, inPlayerInv)
    items = cleanMenuItems(pn, items, inPlayerInv)
    local ok, menu = pcall(ISInventoryPaneContextMenu.createMenu, pn, inPlayerInv, items, x, y)
    if not ok then

        local origEvo = getEvolvedRecipes
        local empty = nil
        pcall(function() empty = ArrayList.new() end)
        if empty and origEvo then
            getEvolvedRecipes = function() return empty end
            ok, menu = pcall(ISInventoryPaneContextMenu.createMenu, pn, inPlayerInv, items, x, y)
            getEvolvedRecipes = origEvo
        end
    end
    local before = {}
    if ok and menu then for _, o in ipairs(menu.options or {}) do before[o] = true end end

    if ok and menu and items[1] and instanceof(items[1], "InventoryContainer") then
        pcall(function()
            local bag = items[1]
            local o = menu:addOptionOnTop(getText("IGUI_TGI_OpenBag"), nil, function() TGI.Window.openBag(pn, bag) end)
        end)
    end

    if ok and menu and inPlayerInv and isClient and isClient() then
        pcall(function()
            local p = player(pn)
            local list = getOnlinePlayers()
            for i = 0, list:size() - 1 do
                local o = list:get(i)
                if o ~= p and not o:isDead() and math.abs(o:getZ() - p:getZ()) < 1
                    and (o:getX() - p:getX()) ^ 2 + (o:getY() - p:getY()) ^ 2 <= 4 then
                    menu:addOption(getText("IGUI_TGI_GiveTo", o:getDisplayName()), nil, function()
                        ISWorldObjectContextMenu.onTrade(nil, p, o)
                    end)
                end
            end
        end)
    end

    if ok and menu and items[1] then
        pcall(function()
            local shown = A.putInTargets(pn, items)
            if #shown == 0 then return end
            local opt = menu:addOption(getText("IGUI_TGI_PutIn"), nil, nil)
            local sub = ISContextMenu:getNew(menu)
            menu:addSubMenu(opt, sub)
            for _, dst in ipairs(shown) do
                local o = sub:addOption(dst.name, nil, function() A.putIn(pn, items, dst) end)
                if dst.bag then pcall(function() o.itemForTexture = dst.bag end) end
            end
        end)
    end
    if ok and menu and items[1] and TGI.Draw and (not TGI.Options or TGI.Options.get("iconMenu")) then
        pcall(function()
            local D = TGI.Draw
            local opt = menu:addOption(getText("IGUI_TGI_IconMenu"), nil, nil)
            local sub = ISContextMenu:getNew(menu)
            menu:addSubMenu(opt, sub)
            sub:addOption(getText("IGUI_TGI_RotCW"), items[1], function(it) D.rotateIcon(it, 1) end)
            sub:addOption(getText("IGUI_TGI_RotCCW"), items[1], function(it) D.rotateIcon(it, 3) end)
            sub:addOption(getText("IGUI_TGI_FlipIcon"), items[1], function(it) D.rotateIcon(it, 2) end)
            sub:addOption(getText("IGUI_TGI_Mirror"), items[1], function(it) D.mirrorIcon(it) end)
            sub:addOption(getText("IGUI_TGI_ResetIcon"), items[1], function(it) D.resetIcon(it) end)
        end)
    end
    if ok and menu then

        for i, o in ipairs(menu.options or {}) do
            if not before[o] and i > 1 then o.tgiOwn = true end
        end
    end
    return ok and menu or nil
end

for _, name in ipairs({ "transferList", "fetch" }) do
    local orig = A[name]
    A[name] = function(...)
        local was = A.queuing
        A.queuing = true
        local r = { pcall(orig, ...) }
        A.queuing = was
        if not r[1] then error(r[2]) end
        return unpack(r, 2)
    end
end

return A
