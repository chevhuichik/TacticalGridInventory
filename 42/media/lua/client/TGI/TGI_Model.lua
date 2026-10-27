require "TGI/TGI_Grid"
require "TGI/TGI_Size"
require "TGI/TGI_Layout"
require "TGI/TGI_Actions"
require "TGI/TGI_Search"
require "TGI/TGI_SyncClient"

TGI = TGI or {}
local G, S, L, A = TGI.Grid, TGI.Size, TGI.Layout, TGI.Actions
local M = {}
TGI.Model = M
M.__index = M

local function safe(fn, d)
    local ok, v = pcall(fn)
    if ok and v ~= nil then return v end
    return d
end

function M.new(container, opts)
    local o = setmetatable({}, M)
    o.container = container
    o.opts = opts or {}
    o.pn = o.opts.playerNum or 0
    o.bagItem = o.opts.bagItem
    o.kind = o.opts.kind or L.kindFor(container, o.bagItem)
    o.dirty = true
    o.sigCache = nil
    return o
end

local AMMO = { ammo = true }
local MED = { firstaid = true, bandage = true, medical = true, medicine = true }
local TOOLS = { tool = true, toolweapon = false, electronics = true, lightsource = true, communications = true, camping = true, gardening = true, vehiclemaintenance = true, cooking = true }
local MATS = { material = true, recipeResource = true, recipresource = true, junk = true }
local WEAPON_DC = { weapon = true, weaponcrafted = true, explosives = true, weaponimprovised = true }

function M.isRealWeapon(it, dc)
    if not instanceof(it, "HandWeapon") then return false end
    dc = dc or string.lower(safe(function() return tostring(it:getDisplayCategory()) end, ""))
    if WEAPON_DC[dc] then return true end
    if safe(function() return it:isRanged() end, false) then return true end
    if dc == "" or dc == "nil" then return safe(function() return it:getMaxDamage() end, 0) >= 0.7 end
    return false
end
function M.groupOf(it)
    local dc = string.lower(safe(function() return tostring(it:getDisplayCategory()) end, ""))
    local ft = safe(function() return it:getFullType() end, "")
    if M.isRealWeapon(it, dc) then return 1 end

    local gunMag = string.find(ft, "Magazine", 1, true) and safe(function() return it:getMaxAmmo() end, 0) > 0
    if AMMO[dc] or string.find(ft, "Clip", 1, true) or gunMag or string.find(ft, "Bullets", 1, true) or string.find(ft, "Shells", 1, true) then return 2 end
    if MED[dc] or safe(function() return it:isCanBandage() end, false) then return 3 end
    if instanceof(it, "Food") then
        if dc == "water" or dc == "drink" then return 5 end
        return 4
    end
    if dc == "watercontainer" or dc == "water" then return 5 end
    if TOOLS[dc] or instanceof(it, "HandWeapon") then return 6 end
    if instanceof(it, "Clothing") or dc == "clothing" or dc == "accessory" or dc == "protectivegear" then return 7 end
    if instanceof(it, "InventoryContainer") or dc == "bag" or dc == "container" then return 8 end
    if MATS[dc] then return 9 end
    return 10
end

function M:wantAutoSort()
    if self.kind == "main" then return false end
    local on = TGI.Options and TGI.Options.get and TGI.Options.get("autoSort")
    if not on then return false end
    local p = getSpecificPlayer(self.pn)
    if p and safe(function() return self.container:isInCharacterInventory(p) end, false) then return false end
    if TGI.Search and TGI.Search.scatterFor and TGI.Search.scatterFor(self.container, self.pn) then
        local items = self.container:getItems()
        for i = 0, items:size() - 1 do
            if not TGI.Search.isSeen(items:get(i)) then return false end
        end
    end
    return true
end

function M:capacity()
    local p = getSpecificPlayer(self.pn)
    if self.kind == "main" and p then
        local mw = safe(function() return p:getMaxWeight() end, nil)
        if mw and mw > 0 then return tonumber(mw) end
    end
    local c = p and safe(function() return self.container:getEffectiveCapacity(p) end, nil)
    if not c or c <= 0 then c = safe(function() return self.container:getCapacity() end, 10) end
    return tonumber(c) or 10
end

function M:wornLocs()

    local now = getTimestampMs()
    if self._wl and now - (self._wlT or 0) < 250 then return self._wl end
    self._wl, self._wlT, self._ps = self:readWornLocs(), now, nil
    return self._wl
end
function M:pocketSig()
    local locs = self:wornLocs()
    local nb = self:isStrict()
    if not self._ps or self._psN ~= nb then local _, _, ps = L.clothingPockets(locs, nb); self._ps, self._psN = ps, nb end
    return self._ps
end

function M.strictOn()
    return not (TGI.Options and TGI.Options.get("strictGrid") == false)
end
function M:isStrict()
    if not M.strictOn() then return false end
    if self.kind == "main" then return true end
    local now = getTimestampMs()
    if self._stT and now - self._stT < 1000 then return self._st end
    local p = getSpecificPlayer(self.pn)
    self._st = p and safe(function() return self.container:isInCharacterInventory(p) end, false) or false
    self._stT = now
    return self._st
end
function M:readWornLocs()
    local out = {}
    local p = getSpecificPlayer(self.pn)
    local wi = p and p:getWornItems()
    if not wi then return out end
    for i = 0, wi:size() - 1 do
        local e = wi:get(i)
        local l = e and e:getLocation()
        if l then
            l = tostring(l)
            out[#out + 1] = l

            if not L.locKnown(l) then
                local it = e:getItem()
                local g = it and (L.nameLoc(it:getType()) or L.nameLoc(it:getDisplayName()))
                if g then out[#out + 1] = g end
            end
        end
    end
    return out
end
function M:clothingPocketsOn()
    return self.kind == "main" and TGI.Options and TGI.Options.get("clothingPockets") ~= false
end
function M:layoutSig()
    local s = self.kind .. ":" .. tostring(self:capacity())

    if self:clothingPocketsOn() then
        local ps = self:pocketSig()

        if ps ~= "0" then s = s .. ":p" .. ps end
    end
    return s
end

function M:visibleItems()
    local out = {}
    local p = getSpecificPlayer(self.pn)
    local items = self.container:getItems()
    local mainInv = p and p:getInventory() == self.container
    for i = 0, items:size() - 1 do
        local it = items:get(i)

        local hide = it:isHidden() == true
        if not hide and mainInv and p then
            hide = A.isEquipped(p, it) or it:getAttachedSlot() >= 0
        end
        if not hide then out[#out + 1] = it end
    end
    return out
end

function M:signature(list)
    local n, sum = #list, 0
    for _, it in ipairs(list) do
        sum = (sum + it:getID() * 7 + 13) % 2147483647
    end
    local extra = ""
    if self:clothingPocketsOn() then extra = ":" .. self:pocketSig() end
    return n .. ":" .. sum .. ":" .. self:capacity() .. extra
end

local function buildEntries(list)
    local entries, stacks = {}, {}
    for _, it in ipairs(list) do

        local max = S.stackMax(it)
        if max then
            local ft = it:getFullType()
            local e = stacks[ft]
            if e and #e.items >= max then
                e.n = (e.n or 1)
                stacks[ft .. "#" .. e.n] = e
                e = nil
                stacks[ft] = nil
            end
            if not e then
                local n = 1
                while stacks[ft .. "#" .. n] do n = n + 1 end
                e = { key = n == 1 and ("s:" .. ft) or ("s:" .. ft .. "#" .. n), items = {}, stack = true, n = n }
                stacks[ft] = e
                entries[#entries + 1] = e
            end
            e.items[#e.items + 1] = it
        else
            entries[#entries + 1] = { key = "i:" .. it:getID(), items = { it } }
        end
    end
    for _, e in ipairs(entries) do
        e.item = e.items[1]
        e.w, e.h = S.of(e.item)
    end
    return entries
end

local function savedPos(item, sig)
    local md = safe(function() return item:getModData() end, nil)
    if not md then return nil end
    local d = md.TGI
    if sig and not (d and d.s == sig) and md.TGIh and md.TGIh[sig] then return md.TGIh[sig] end
    return d
end

function M:savePos(item, pi, x, y, rot, manual)
    local md = safe(function() return item:getModData() end, nil)
    if not md then return end
    local d = { s = self:layoutSig(), pi = pi, x = x, y = y, r = rot and 1 or 0 }
    local o = md.TGI
    md.TGI = d

    if o and o.s and o.s ~= d.s then
        md.TGIh = md.TGIh or {}
        o.t = o.t or getTimestampMs()
        md.TGIh[o.s] = o
        local n, oldest = 0, nil
        for k, v in pairs(md.TGIh) do n = n + 1; if not oldest or (v.t or 0) < (md.TGIh[oldest].t or 0) then oldest = k end end
        if n > 4 and oldest then md.TGIh[oldest] = nil end
    end
    if md.TGIh then md.TGIh[d.s] = nil end

    if manual and not (o and o.s == d.s and o.pi == d.pi and o.x == d.x and o.y == d.y and o.r == d.r) and TGI.Sync and TGI.Sync.send then
        pcall(TGI.Sync.send, "pos", item, d)
    end
end

function M:rebuild()

    M.lastWhy = (self.rebuildWhy or "direct") .. " " .. tostring(self.kind)
    self.rebuildWhy = nil
    local list = self:visibleItems()
    self.sigCache = self:signature(list)
    local ft = nil
    if self.bagItem then pcall(function() ft = self.bagItem:getFullType() end) end
    local pockets, panelW
    if self:clothingPocketsOn() then pockets, panelW = L.clothingPockets(self:wornLocs(), self:isStrict())
    else pockets, panelW = L.pockets(self.kind, self:capacity(), ft) end
    self.panelW = panelW
    self.board = G.newBoard(pockets)
    self.board.locked = self:lockTable()
    self.entries = buildEntries(list)
    self.byKey = {}
    self.overflow = {}
    local sig = self:layoutSig()
    local sorting = self.sortOnce
    self.sortOnce = false
    if sorting then

        local rank, name = {}, {}
        local cp = self:currentPreset()
        for _, e in ipairs(self.entries) do
            rank[e] = M.groupOf(e.item)
            if cp and M.PRESETS[cp] then
                local pr = M.PRESETS[cp][rank[e]]
                rank[e] = pr and (pr - 100) or rank[e]
            end
            name[e] = safe(function() return e.item:getDisplayName() end, "")
        end
        table.sort(self.entries, function(a, b)
            local ca, cb = rank[a], rank[b]
            if ca ~= cb then return ca < cb end
            local aa, bb = a.w * a.h, b.w * b.h
            if aa ~= bb then return aa > bb end
            if name[a] ~= name[b] then return name[a] < name[b] end
            local aa, bb = a.w * a.h, b.w * b.h
            if aa ~= bb then return aa > bb end
            return a.key < b.key
        end)
    else

    table.sort(self.entries, function(a, b)
        local aa, bb = a.w * a.h, b.w * b.h
        if aa ~= bb then return aa > bb end
        return a.key < b.key
    end)
    end

    local growIdx = nil
    if self.kind ~= "main" and not self:isStrict() then
        for idx, p in ipairs(self.board.pockets) do
            local gb = growIdx and self.board.pockets[growIdx]

            if not gb or p.w > gb.w or (p.w == gb.w and (p.y0 + p.h) > (gb.y0 + gb.h)) then growIdx = idx end
        end
    end
    self.growIdx = growIdx
    local gp = growIdx and self.board.pockets[growIdx]
    local gpH0 = gp and gp.h
    if gp and not sorting then
        for _, e in ipairs(self.entries) do
            local pend = A.pending[e.item:getID()]
            if pend and pend.sig ~= sig then pend = nil end
            local sp = pend or savedPos(e.item, sig)
            if sp and sp.pi == growIdx and sp.y and (pend or sp.s == sig) then
                local rot = (sp.rot ~= nil) and sp.rot or (sp.r == 1)
                local _, dh = G.dims(e.w, e.h, rot)
                if sp.y + dh > gp.h and sp.y + dh <= 400 then gp.h = sp.y + dh end
            end
        end
    end
    local todo = {}
    for _, e in ipairs(self.entries) do
        self.byKey[e.key] = e
        local pend = A.pending[e.item:getID()]
            if pend and pend.sig ~= sig then pend = nil end
        local sp = pend or savedPos(e.item, sig)
        if sorting and not pend then sp = nil end
        local placed = false
        if sp and (pend or sp.s == sig) then
            local rot = (sp.rot ~= nil) and sp.rot or (sp.r == 1)
            placed = G.place(self.board, e.key, sp.pi, sp.x, sp.y, e.w, e.h, rot)
            if pend then
                A.pending[e.item:getID()] = nil
                if placed then
                    self:savePos(e.item, sp.pi, sp.x, sp.y, rot, true)
                    if TGI.Draw and TGI.Draw.markArrived then TGI.Draw.markArrived(e.item) end
                end
            end
        end
        if not placed then todo[#todo + 1] = e end
    end
    local scatter = TGI.Search and TGI.Search.scatterFor(self.container, self.pn)
    local preset = self:layoutPreset()
    for _, e in ipairs(todo) do
        local pi, x, y, rot

        local want = preset and preset[safe(function() return e.item:getFullType() end, "")]
        if want then
            local wp, wx, wy, wr = tonumber(want[1]), tonumber(want[2]), tonumber(want[3]), want[4] == 1
            local dw, dh = G.dims(e.w, e.h, wr)
            if wp and self.board.pockets[wp] and G.fits(self.board, wp, wx, wy, dw, dh, e.key) then pi, x, y, rot = wp, wx, wy, wr end
        end
        if scatter and not sorting and not TGI.Search.isSeen(e.item) then pi, x, y, rot = G.randomSpot(self.board, e.w, e.h, e.key, safe(function() return e.item:getID() end, 0)) end
        if not pi then pi, x, y, rot = G.findSpot(self.board, e.w, e.h, e.key) end
        if not pi then

            local best = growIdx and self.board.pockets[growIdx]
            if best and best.w < math.min(e.w, e.h) then best = nil end
            if best then

                local tries = 0
                local step = math.max(1, math.min(e.w, e.h))
                while not pi and best.h < 400 and tries < 200 do
                    best.h = math.min(400, best.h + step)
                    step = 1
                    tries = tries + 1
                    pi, x, y, rot = G.findSpot(self.board, e.w, e.h, e.key)
                end
            end
        end
        if pi then
            G.place(self.board, e.key, pi, x, y, e.w, e.h, rot)

            for _, it in ipairs(e.items or { e.item }) do self:savePos(it, pi, x, y, rot) end
        else
            self.overflow[#self.overflow + 1] = e
        end
    end

    if gp and gp.h > gpH0 then
        local used = gpH0
        for _, pos in pairs(self.board.entries) do
            if pos.pi == growIdx then used = math.max(used, pos.y + pos.dh) end
        end
        if used < gp.h then gp.h = used end
    end

    if gp and gp.h > gpH0 then
        local d, bottom = gp.h - gpH0, gp.y0 + gpH0
        for _, p in ipairs(self.board.pockets) do
            if p ~= gp and p.y0 >= bottom and p.x0 < gp.x0 + gp.w and p.x0 + p.w > gp.x0 then p.y0 = p.y0 + d end
        end
    end
    self.dirty = false
end

M.PRESETS = {
    ammo = { [2] = 1, [1] = 2, [3] = 3 },
    medical = { [3] = 1, [5] = 2, [4] = 3 },
    food = { [4] = 1, [5] = 2, [3] = 3 },
    tools = { [6] = 1, [9] = 2, [1] = 3 },
}

function M:presetStore()
    local k = self:lockKey()
    if k then
        local md = getSpecificPlayer(self.pn or 0):getModData()
        md.TGIPresets = md.TGIPresets or {}
        return md.TGIPresets, k
    end
    local obj = safe(function() return self.container:getParent() end, nil)
    if obj and obj.getModData then return obj:getModData(), "TGIPreset" end
    return nil
end
function M:currentPreset()
    if self.preset ~= nil then return self.preset or nil end
    local st, k = self:presetStore()
    local v = st and st[k] or nil
    if v == "" then v = nil end
    return v
end
function M:sortNow(preset)
    local st, k = self:presetStore()
    if st then st[k] = preset or "" end
    self.preset = preset
    self.sortOnce = true
    self.dirty = true
    self:ensure()
end

function M:ensure()
    local g = TGI.Sync and TGI.Sync.gen or 0
    if self.syncGen ~= g then self.rebuildWhy = self.syncGen == nil and "new" or "sync"; self.syncGen = g; self.dirty = true end
    if self.dirty then
        if not self.sortedOnce and self:wantAutoSort() then self.sortOnce = true; self.sortedOnce = true end
        self.rebuildWhy = self.rebuildWhy or "dirty"
        return self:rebuild()
    end
    if not self.sortedOnce and (self.asTick or 0) < getTimestampMs() then
        self.asTick = getTimestampMs() + 500
        if self:wantAutoSort() then self.sortOnce = true; self.sortedOnce = true; self.rebuildWhy = "autosort"; return self:rebuild() end
    end

    local now = getTimestampMs()
    local n = -1
    pcall(function() n = self.container:getItems():size() end)
    if n == self.sigN and now < (self.sigAt or 0) then return end
    self.sigN, self.sigAt = n, now + 100
    local list = self:visibleItems()
    local sigNow = self:signature(list)
    if sigNow ~= self.sigCache then
        if self:wantAutoSort() then self.sortOnce = true; self.sortedOnce = true end
        self.rebuildWhy = "items"
        M.lastSigChange = tostring(self.sigCache) .. " -> " .. sigNow
        self:rebuild()
    end
end

function M:extent()

    if self.kind == "main" and #self.board.pockets == 0 then return 0, 1 end
    local w, h = 0, 0
    for _, p in ipairs(self.board.pockets) do
        w = math.max(w, p.x0 + p.w)
        h = math.max(h, p.y0 + p.h)
    end
    return w, h
end

function M:pocketAt(cx, cy)
    for pi, p in ipairs(self.board.pockets) do
        if cx >= p.x0 and cy >= p.y0 and cx < p.x0 + p.w and cy < p.y0 + p.h then
            return pi, cx - p.x0, cy - p.y0
        end
    end
    return nil
end

function M:canPlace(entry, pi, x, y, rot)
    local dw, dh = G.dims(entry.w, entry.h, rot)
    local ignore = (self.byKey[entry.key] == entry) and entry.key or nil
    return G.fits(self.board, pi, x, y, dw, dh, ignore)
end

function M:moveLocal(entry, pi, x, y, rot)
    if G.place(self.board, entry.key, pi, x, y, entry.w, entry.h, rot) then
        for _, it in ipairs(entry.items) do self:savePos(it, pi, x, y, rot, true) end
        return true
    end
    return false
end

function M:lockKey()
    local p = getSpecificPlayer(self.pn or 0)
    if not p then return nil end
    if self.container == p:getInventory() then return "inv" end
    if self.bagItem then return "bag" .. tostring(safe(function() return self.bagItem:getID() end, "?")) end
    return nil
end
function M:lockTable()
    local k = self:lockKey()
    if not k then return nil end
    local md = getSpecificPlayer(self.pn or 0):getModData()
    local saved = md.TGILocks and md.TGILocks[k]
    if not saved then return nil end
    local out = {}
    for pk, list in pairs(saved) do
        local pi = tonumber(pk)
        if pi then
            out[pi] = {}
            for idx in string.gmatch(list, "%d+") do out[pi][tonumber(idx)] = true end
        end
    end
    return out
end
function M:isLocked(pi, x, y)
    local p = self.board.pockets[pi]
    local lk = self.board.locked and self.board.locked[pi]
    return p and lk and lk[y * p.w + x + 1] or false
end
function M:toggleLock(pi, x, y)
    local k = self:lockKey()
    local p = self.board.pockets[pi]
    if not k or not p then return end
    self.board.locked = self.board.locked or {}
    local lk = self.board.locked[pi] or {}
    self.board.locked[pi] = lk
    local idx = y * p.w + x + 1
    if lk[idx] then lk[idx] = nil else lk[idx] = true end
    local parts = {}
    for i in pairs(lk) do parts[#parts + 1] = tostring(i) end
    local md = getSpecificPlayer(self.pn or 0):getModData()
    md.TGILocks = md.TGILocks or {}
    md.TGILocks[k] = md.TGILocks[k] or {}
    md.TGILocks[k][tostring(pi)] = table.concat(parts, ",")
end

function M:layoutPreset()
    local k = self:lockKey()
    if not k then return nil end
    local md = getSpecificPlayer(self.pn or 0):getModData()
    return md.TGILayout and md.TGILayout[k] or nil
end
function M:saveLayoutPreset()
    local k = self:lockKey()
    if not k then return 0 end
    local out, n = {}, 0
    for key, pos in pairs(self.board.entries) do
        local e = self.byKey[key]
        local ft = e and safe(function() return e.item:getFullType() end, nil)
        if ft and not out[ft] then out[ft] = { pos.pi, pos.x, pos.y, pos.rot and 1 or 0 }; n = n + 1 end
    end
    local md = getSpecificPlayer(self.pn or 0):getModData()
    md.TGILayout = md.TGILayout or {}
    md.TGILayout[k] = out
    return n
end
function M:clearLayoutPreset()
    local k = self:lockKey()
    local md = k and getSpecificPlayer(self.pn or 0):getModData()
    if md and md.TGILayout then md.TGILayout[k] = nil end
end

function M:findSpotFor(entry)
    return G.findSpot(self.board, entry.w, entry.h, nil)
end

function M:hasRoomFor(item)
    self:ensure()
    local w, h = S.of(item)
    local max = S.stackMax(item)
    if max then
        local ft = item:getFullType()
        for _, e in ipairs(self.entries or {}) do
            if e.stack and e.item:getFullType() == ft and #e.items < max and self.board.entries[e.key] then return true end
        end
    end
    return G.findSpot(self.board, w, h, nil) ~= nil
end

return M
