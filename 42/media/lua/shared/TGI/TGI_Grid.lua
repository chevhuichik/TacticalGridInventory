TGI = TGI or {}
local G = {}
TGI.Grid = G

function G.newBoard(pockets)
    local b = { pockets = {}, entries = {} }
    for i, p in ipairs(pockets) do
        local cells = {}
        b.pockets[i] = { w = p.w, h = p.h, x0 = p.x0 or 0, y0 = p.y0 or 0, cells = cells, grow = p.grow, label = p.label, labelW = p.labelW }
    end
    return b
end

function G.dims(w, h, rot)
    if rot then return h, w end
    return w, h
end

function G.fits(board, pi, x, y, w, h, ignoreKey)
    local p = board.pockets[pi]
    if not p or x < 0 or y < 0 or x + w > p.w or y + h > p.h then return false end
    for yy = y, y + h - 1 do
        local row = yy * p.w
        for xx = x, x + w - 1 do
            local c = p.cells[row + xx + 1]
            if c ~= nil and c ~= ignoreKey then return false end
        end
    end
    return true
end

function G.mark(board, pi, x, y, w, h, key)
    local p = board.pockets[pi]

    if key == nil and p.ff and y < p.ff then p.ff = y end
    for yy = y, y + h - 1 do
        local row = yy * p.w
        for xx = x, x + w - 1 do p.cells[row + xx + 1] = key end
    end
end

function G.place(board, key, pi, x, y, w, h, rot)
    local dw, dh = G.dims(w, h, rot)
    if not G.fits(board, pi, x, y, dw, dh, key) then return false end
    local old = board.entries[key]
    if old then G.mark(board, old.pi, old.x, old.y, old.dw, old.dh, nil) end
    G.mark(board, pi, x, y, dw, dh, key)
    board.entries[key] = { pi = pi, x = x, y = y, w = w, h = h, rot = rot and true or false, dw = dw, dh = dh }
    return true
end

function G.remove(board, key)
    local e = board.entries[key]
    if not e then return end
    G.mark(board, e.pi, e.x, e.y, e.dw, e.dh, nil)
    board.entries[key] = nil
end

function G.hitsLock(board, pi, x, y, w, h)
    local lk = board.locked and board.locked[pi]
    if not lk then return false end
    local p = board.pockets[pi]
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do if lk[yy * p.w + xx + 1] then return true end end
    end
    return false
end

function G.findSpot(board, w, h, ignoreKey, preferRot)
    local orders = preferRot and { true, false } or { false, true }
    for pi, p in ipairs(board.pockets) do
        for _, rot in ipairs(orders) do
            local dw, dh = G.dims(w, h, rot)
            if dw <= p.w and dh <= p.h then

                local y0 = 0
                if ignoreKey == nil or board.entries[ignoreKey] == nil then
                    local ff = p.ff or 0
                    while ff < p.h do
                        local row, full = ff * p.w, true
                        for xx = 1, p.w do if p.cells[row + xx] == nil then full = false; break end end
                        if not full then break end
                        ff = ff + 1
                    end
                    p.ff = ff
                    y0 = ff
                end
                for y = y0, p.h - dh do
                    for x = 0, p.w - dw do
                        if G.fits(board, pi, x, y, dw, dh, ignoreKey) and not G.hitsLock(board, pi, x, y, dw, dh) then return pi, x, y, rot end
                    end
                end
            end
        end
    end
    return nil
end

function G.randomSpot(board, w, h, ignoreKey, seed)
    local c = {}
    for pi, p in ipairs(board.pockets) do
        for _, rot in ipairs({ false, true }) do
            local dw, dh = G.dims(w, h, rot)
            if dw <= p.w and dh <= p.h and not (rot and w == h) then
                for y = 0, p.h - dh do
                    for x = 0, p.w - dw do
                        if G.fits(board, pi, x, y, dw, dh, ignoreKey) and not G.hitsLock(board, pi, x, y, dw, dh) then c[#c + 1] = { pi, x, y, rot } end
                    end
                end
            end
        end
    end
    if #c == 0 then return nil end
    local sd = math.abs(math.floor(tonumber(seed) or 0)) % 1000003
    local idx = math.floor((sd * 7919 + 104729) % #c) + 1
    if idx < 1 or idx > #c then idx = 1 end
    local r = c[idx]
    return r[1], r[2], r[3], r[4]
end

function G.at(board, pi, x, y)
    local p = board.pockets[pi]
    if not p or x < 0 or y < 0 or x >= p.w or y >= p.h then return nil end
    return p.cells[y * p.w + x + 1]
end

return G
