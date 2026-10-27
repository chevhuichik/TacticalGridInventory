TGI = TGI or {}
local V = {}
TGI.CompatViewpoint = V

local function present() return rawget(_G, "ViewpointLoot") ~= nil end

local zbV = nil
local function zbOn()
    if zbV == nil then
        zbV = false
        pcall(function()
            local m = getActivatedMods()
            zbV = m:contains("ZombieBuddy") or m:contains("\\ZombieBuddy")
        end)
    end
    return zbV
end

local function hookSearch()
    local O = TGI.Options
    if not O or not O.sandbox or O.tgiVPWrapped then return end
    O.tgiVPWrapped = true
    local orig = O.sandbox
    O.sandbox = function(id, ...)
        if id == "SearchEnabled" then
            local v = orig(id, ...)

            rawset(_G, "TGIVPSearch", v ~= false)
            if rawget(_G, "TGIVPHiddenText") == nil then rawset(_G, "TGIVPHiddenText", getText("IGUI_TGI_NotSearched")) end

            if present() and not rawget(_G, "TGIViewpointAddon") and not zbOn() then return false end
            return v
        end
        return orig(id, ...)
    end
end
hookSearch()

local function openOn(player, container)
    local W = TGI.Window
    if not W then return false end
    if container then W.focus = { c = container, t = getTimestampMs() } end
    if not W.instance then W.closedAt = nil; W.toggle(player:getPlayerNum())
    else pcall(function() W.instance:refreshContainers(true) end) end
    V.openedByUs = true
    V.openedWin = W.instance
    return true
end

function V.apply()
    local L = rawget(_G, "ViewpointLoot")
    if type(L) ~= "table" or L.tgiWrapped then return end
    L.tgiWrapped = true
    local origOpen, origClose = L.openWindow, L.closeWindow
    L.openWindow = function(player, container, ...)
        if TGI.Options and TGI.Options.get("replaceVanilla") and TGI.usesGrid and TGI.usesGrid(player:getPlayerNum()) then
            if openOn(player, container) then return end
        end
        return origOpen(player, container, ...)
    end

    local function lockedFor(player, item)
        local c = item and item:getContainer()
        return c and TGI.Lock and TGI.Lock.locked and TGI.Lock.locked(c, player:getPlayerNum())
    end
    local function refuse(player)
        if TGI.halo then TGI.halo(player, getText("IGUI_TGI_Locked2"), false) end
    end

    local function intoTarget(player, item, fn)
        local W = TGI.Window
        local c = W and W.qtMine
        local page = getPlayerInventory(player:getPlayerNum())

        if not (c and item and page and c.isInCharacterInventory) then return fn() end
        local ok, fits = pcall(function() return c:isInCharacterInventory(player) and c:hasRoomFor(player, item) end)
        if not (ok and fits) then return fn() end
        local was = page.inventory
        page.inventory = c
        local res = { pcall(fn) }
        page.inventory = was
        if not res[1] then error(res[2]) end
        return unpack(res, 2)
    end
    local origTake, origAll = L.take, L.takeAll
    if origTake then
        L.take = function(player, item, ...)
            local ok, lk = pcall(lockedFor, player, item)
            if ok and lk then refuse(player); return end
            local a = { ... }
            return intoTarget(player, item, function() return origTake(player, item, unpack(a)) end)
        end
    end
    if origAll then
        L.takeAll = function(player, items, ...)

            local ok, lk = pcall(function()
                for i = 0, items:size() - 1 do if lockedFor(player, items:get(i)) then return true end end
                return false
            end)
            if ok and lk then refuse(player); return end
            local a = { ... }
            return intoTarget(player, items:size() > 0 and items:get(0) or nil, function() return origAll(player, items, unpack(a)) end)
        end
    end
    L.closeWindow = function(player, ...)

        if V.openedByUs and TGI.Window and TGI.Window.instance and (V.openedWin == nil or V.openedWin == TGI.Window.instance) then
            V.openedByUs = nil
            pcall(function() TGI.Window.instance:close() end)
            return
        end
        return origClose(player, ...)
    end

    local IA = rawget(_G, "ViewpointInteract")
    if type(IA) == "table" and IA.harvest and not IA.tgiWrapped then
        IA.tgiWrapped = true
        local origHarvest = IA.harvest
        IA.harvest = function(player, object, ...)
            local res = origHarvest(player, object, ...)
            pcall(function()
                if type(res) ~= "table" or not res.labels then return end
                if not rawget(_G, "TGIViewpointAddon") or not (TGI.Search and TGI.Search.enabled()) then return end
                local pn = player:getPlayerNum()
                local target = nil
                for i = 0, (object.getContainerCount and object:getContainerCount() or 0) - 1 do
                    local c = object:getContainerByIndex(i)
                    if c and not TGI.Search.exempt(c, pn) and not (TGI.Lock and TGI.Lock.locked(c, pn)) then
                        local items = c:getItems()
                        for k = 0, items:size() - 1 do
                            if not TGI.Search.isSeen(items:get(k)) then target = c; break end
                        end
                    end
                    if target then break end
                end
                if not target then return end
                local act = {
                    name = getText("IGUI_TGI_SearchHere"), enabled = true, first = true, n = 2,
                    args = { player, target },
                    fn = function(pl, c)
                        if openOn(pl, c) then TGI.Search.stateFor(c).all = true end
                    end,
                }
                table.insert(IA.actions, 1, act)
                table.insert(res.labels, 1, act.name)
                table.insert(res.enabled, 1, true)
            end)
            return res
        end
    end
    print("[TGI] Viewpoint support on")
end

Events.OnGameStart.Add(function() hookSearch(); pcall(V.apply) end)

do
    local saved, held = nil, false
    Events.OnTick.Add(function()
        local opts = rawget(_G, "ProjectViewpointQOLOptions")
        if type(opts) ~= "table" then return end
        local open = (TGI.Window and TGI.Window.instance) or (TGI.Appliance and TGI.Appliance.inst)
        if open then
            if not held then saved, held = opts.enableMouseWheelZoom, true end
            if opts.enableMouseWheelZoom ~= false then opts.enableMouseWheelZoom = false end
        elseif held then
            opts.enableMouseWheelZoom = saved
            saved, held = nil, false
        end
    end)
end

return V
