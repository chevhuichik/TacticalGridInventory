TGI = TGI or {}
local J = {}
TGI.Joypad = J

J.cur = nil

local function T() return TGI.Theme end
local function W() return TGI.Window end
local function Drag() return TGI.Drag end

function J.active(pn)
    pn = pn or 0
    return JoypadState and JoypadState.players and JoypadState.players[pn + 1] ~= nil
        and W() and W().instance ~= nil and W().instance.pn == pn
end

local function columns()
    local w = W().instance
    if not w then return {} end
    return { w.mine, w.loot }
end

local function add(out, sp)
    local r = sp.r
    sp.ax, sp.ay = r[1] + r[3] / 2, r[2] + r[4] / 2
    out[#out + 1] = sp
end

local function headerButtons(p)
    local out = {}
    local ok, ib = pcall(p.iconBtnRects, p)
    if ok and ib then
        for _, k in ipairs({ "sort", "qt", "log", "power", "set", "cfg" }) do
            if ib[k] then out[#out + 1] = { k, ib[k] } end
        end
    end
    local ok2, bx, by, bw, bh = pcall(p.searchBtnRect, p)
    if ok2 and bx then out[#out + 1] = { "search", { bx, by, bw, bh } } end
    return out
end

local function spots()
    local out = {}
    local w = W().instance
    if not w then return out end
    local CELL, HEADER = T().CELL, T().HEADER

    local wx, wy = w:getAbsoluteX(), w:getAbsoluteY()
    pcall(function()
        for i, r in ipairs(w:catRects()) do
            add(out, { id = "cat" .. i, kind = "win", el = w, ci = 0, r = { wx + r.x, wy + r.y, r.w, r.h } })
        end
        local kx, ky, kw, kh = w:kofiRect()
        if kw > 0 then add(out, { id = "kofi", kind = "win", el = w, ci = 0, r = { wx + kx, wy + ky, kw, kh } }) end
    end)

    local e = w.equip
    if e and e:isReallyVisible() and TGI.Equip and TGI.Equip.SLOTS then
        local ex, ey = e:getAbsoluteX(), e:getAbsoluteY()
        for _, sl in ipairs(TGI.Equip.SLOTS) do
            local ok, x, y, sw, sh = pcall(e.slotRect, e, sl)
            if ok and x then add(out, { id = "eq:" .. tostring(sl.id), kind = "equip", el = e, ci = 1, r = { ex + x, ey + y, sw, sh } }) end
        end
        pcall(function()
            for i = 1, #(e.others or {}) do
                local x, y, sw, sh = e:rowRect(e:othersY(), i)
                add(out, { id = "eo:" .. i, kind = "equip", el = e, ci = 1, r = { ex + x, ey + y, sw, sh } })
            end
            for i = 1, #(e.belt or {}) do
                local x, y, sw, sh = e:beltRect(i)
                if x then add(out, { id = "eb:" .. i, kind = "equip", el = e, ci = 1, r = { ex + x, ey + y, sw, sh } }) end
            end
        end)
    end

    local pn = w.pn or 0
    local hb = getPlayerHotbar and getPlayerHotbar(pn)
    if hb and hb:isVisible() and hb.tgiVis and hb.tgiSlotRect then
        local hx, hy = hb:getAbsoluteX(), hb:getAbsoluteY()
        for _, i in ipairs(hb.tgiVis) do
            local x, y, sw, sh = hb:tgiSlotRect(i)
            add(out, { id = "hb" .. i, kind = "hot", el = hb, slot = i, ci = 0, r = { hx + x, hy + y, sw, sh } })
        end
    end
    local q = TGI.Quick and TGI.Quick.inst
    if q and q:isReallyVisible() then
        local qx, qy = q:getAbsoluteX(), q:getAbsoluteY()
        for _, i in ipairs(q.vis or q:visible()) do
            local x, y, sw, sh = q:cellRect(i)
            add(out, { id = "qs" .. i, kind = "quick", el = q, slot = i, ci = 0, r = { qx + x, qy + y, sw, sh } })
        end
    end

    local tabs = w.tabs
    if tabs and tabs:isReallyVisible() then
        local tx, ty = tabs:getAbsoluteX(), tabs:getAbsoluteY()
        local bs = W().TAB_W
        for i, bt in ipairs(tabs:buttons()) do
            local y = (i - 1) * (bs + 2)
            if y + bs > tabs.height then break end
            add(out, { id = "tab" .. i, kind = "tab", el = tabs, btn = bt, ci = 3, r = { tx, ty + y, bs, bs } })
        end
    end

    for ci, col in ipairs(columns()) do
        if col and col:isReallyVisible() then
            for pi, p in ipairs(col.panels or {}) do
                if p:getIsVisible() and p.model then
                    local ax, ay = p:getAbsoluteX(), p:getAbsoluteY()
                    local key = "g" .. ci .. ":" .. pi .. ":" .. tostring(p.model.container)
                    local btns = headerButtons(p)
                    local titleW = p.width
                    for _, bt in ipairs(btns) do titleW = math.min(titleW, bt[2][1]) end
                    add(out, { id = key .. ":h", kind = "head", el = p, p = p, col = col, ci = ci + 1, cy = -1,
                        r = { ax, ay, math.max(20, titleW - 4), HEADER } })
                    for _, bt in ipairs(btns) do
                        local r = bt[2]
                        add(out, { id = key .. ":b:" .. bt[1], kind = "btn", el = p, p = p, col = col, ci = ci + 1, cy = -1,
                            r = { ax + r[1], ay + r[2], r[3], r[4] } })
                    end
                    if not p.collapsed and not p.locked then
                        local cw, ch = p.model:extent()
                        for cy = 0, ch - 1 do
                            for cx = 0, cw - 1 do
                                if p.model:pocketAt(cx, cy) then
                                    add(out, { id = key .. ":" .. cx .. ":" .. cy, kind = "cell", el = p, p = p, col = col,
                                        ci = ci + 1, cx = cx, cy = cy,
                                        r = { ax + cx * CELL, ay + HEADER + cy * CELL, CELL, CELL } })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

local function find(list, id)
    if not id then return nil end
    for _, s in ipairs(list) do if s.id == id then return s end end
    return nil
end

local function reveal(s)
    local col = s.col
    if not col or not col.setYScroll then return s end
    local top = col:getAbsoluteY()
    local bot = top + col.height
    local shift = 0
    if s.r[2] < top then shift = top - s.r[2] + 4
    elseif s.r[2] + s.r[4] > bot then shift = bot - (s.r[2] + s.r[4]) - 4 end
    if shift ~= 0 then
        local maxScroll = math.max(0, col:getScrollHeight() - col.height)
        local cur = col:getYScroll()
        local want = math.min(0, math.max(-maxScroll, cur + shift))
        col:setYScroll(want)
        local d = want - cur
        s.r[2] = s.r[2] + d
        s.ay = s.ay + d
    end
    return s
end

local function place(s)
    if not s then J.cur = nil; return end
    s = reveal(s)
    J.cur = s.id
    J.ax, J.ay = math.floor(s.ax), math.floor(s.ay)
    J.placedAt = getTimestampMs()
    pcall(function() Mouse.setXY(J.ax, J.ay) end)
end

local function current()
    local list = spots()
    local s = find(list, J.cur)
    if not s then
        for _, c in ipairs(list) do if c.kind == "cell" then s = c; break end end
        s = s or list[1]
        place(s)
    end
    return s, list
end

function J.move(dx, dy)
    local s, list = current()
    if not s then return end
    local best, bestScore = nil, nil
    for _, c in ipairs(list) do
        local ddx, ddy = c.ax - s.ax, c.ay - s.ay
        local along = dx ~= 0 and ddx * dx or ddy * dy
        local across = dx ~= 0 and math.abs(ddy) or math.abs(ddx)
        if along > 2 then
            local score = along + across * 3
            if not bestScore or score < bestScore then best, bestScore = c, score end
        end
    end
    place(best or s)
end

function J.jumpColumn(step)
    local s, list = current()
    if not s then return end
    local want = (s.ci or 2) + step
    if want < 1 then want = 3 elseif want > 3 then want = 1 end
    for pass = 1, 2 do
        for _, c in ipairs(list) do
            if c.ci == want and (pass == 2 or c.kind == "cell" or c.kind == "equip") then place(c); return end
        end
    end
end

local function local_(s)
    return math.floor(s.ax) - s.el:getAbsoluteX(), math.floor(s.ay) - s.el:getAbsoluteY()
end

local function openMenu(pn)
    local menu = getPlayerContextMenu and getPlayerContextMenu(pn)
    if menu and menu:getIsVisible() then
        menu.origin = W().instance
        menu.mouseOver = 1
        setJoypadFocus(pn, menu)
    end
end

local function equipItem(s)
    local lx, ly = local_(s)
    local sl, item = s.el:hit(lx, ly)
    return item, sl
end

local function slotItem(s)
    if s.kind == "hot" then return s.el.attachedItems and s.el.attachedItems[s.slot] end
    if s.kind == "quick" then
        local sl = s.el:slots()[s.slot]
        return sl and s.el:findItem(sl.ft)
    end
    return nil
end

local function carry(pn, item, prefix, source)
    local w, h = 1, 1
    pcall(function() w, h = TGI.Size.of(item) end)
    local D = Drag()
    D.start(pn, { key = prefix .. item:getID(), item = item, items = { item }, w = w, h = h }, source, 0, 0, false, nil)
    if D.active then D.active.sticky = true end
end

function J.press(button)
    local pn = W().instance and W().instance.pn or 0
    local D = Drag()
    if button == Joypad.BButton then
        if D.active then D.cancel(); D.justCancelled = getTimestampMs()
        else W().toggle(pn) end
        return
    end
    if button == Joypad.RBumper and D.active then D.rotate(); return end
    if button == Joypad.RBumper then J.jumpColumn(1); return end
    if button == Joypad.LBumper then J.jumpColumn(-1); return end
    local s = current()
    if not s then return end
    place(s)
    local lx, ly = local_(s)
    local kind = s.kind
    if button == Joypad.AButton then
        if D.active then D.finish(); return end
        if kind == "win" or kind == "btn" then
            s.el:onMouseDown(lx, ly)
            s.el:onMouseUp(lx, ly)
        elseif kind == "tab" then
            s.el:select(s.btn)
        elseif kind == "head" then
            local p = s.p
            p.collapsed = not p.collapsed
            TGI.GridPanel.rememberCollapsed(p.model.container, p.collapsed)
            p.lastW = -1
            p:refresh(false)
        elseif kind == "equip" then
            local item = equipItem(s)
            if item then carry(pn, item, "e:", { slot = true }) end
        elseif kind == "hot" then
            local item = slotItem(s)
            if item then carry(pn, item, "h:", { hotbar = s.slot }) end
        elseif kind == "quick" then
            local item = slotItem(s)
            if item then carry(pn, item, "q:", { quick = s.slot }) end
        elseif kind == "cell" then
            local p = s.p
            local e, pos, gx, gy = p:entryAtMouse(lx, ly)
            if not e then return end
            if p:isHidden(e) then p:toggleQueue(e); return end
            D.start(pn, e, { model = p.model, panel = p }, gx, gy, pos and pos.rot or false)
            if D.active then D.active.sticky = true end
        end
        return
    end
    if D.active then return end
    if button == Joypad.XButton then
        if kind == "cell" then
            local e = s.p:entryAtMouse(lx, ly)
            if e and not s.p:isHidden(e) then W().quickTransfer(pn, e, s.p.model) end
        elseif kind == "equip" then

            local item, sl = equipItem(s)
            if item then
                local A = TGI.Actions
                if sl == "belt" then A.equip(pn, item) else A.unequip(pn, item) end
            end
        elseif kind == "hot" then
            local item = slotItem(s)
            if item then TGI.Actions.equip(pn, item) end
        elseif kind == "quick" then
            pcall(s.el.use, s.el, s.slot)
        end
        return
    end
    if button == Joypad.YButton then
        if kind == "cell" or kind == "head" then
            s.p:onRightMouseUp(lx, ly)
            openMenu(pn)
        elseif kind == "equip" or kind == "quick" then
            s.el:onRightMouseUp(lx, ly)
            openMenu(pn)
        elseif kind == "hot" then
            local item = slotItem(s)
            if item then
                TGI.Actions.contextMenu(pn, { item }, J.ax, J.ay, true)
                openMenu(pn)
            end
        end
    end
end

local function hintsFor(s)
    local D = Drag()
    local out = {}
    local function h(btn, key) out[#out + 1] = { btn, getText("IGUI_TGI_Pad_" .. key) } end
    if D.active then
        h("AButton", "Put"); h("RBumper", "Rotate"); h("BButton", "Cancel")
        return out
    end
    local k = s and s.kind
    if k == "cell" then
        local lx, ly = s.ax - s.el:getAbsoluteX(), s.ay - s.el:getAbsoluteY()
        local e = s.p:entryAtMouse(lx, ly)
        if e then h("AButton", "Take"); h("XButton", "Move"); h("YButton", "Menu")
        else h("YButton", "Layout") end
    elseif k == "head" then h("AButton", "Collapse"); h("YButton", "Layout")
    elseif k == "btn" or k == "win" or k == "tab" then h("AButton", "Press")
    elseif k == "equip" then
        if equipItem(s) then h("AButton", "Take"); h("XButton", "TakeOff"); h("YButton", "Menu") end
    elseif k == "hot" then
        if slotItem(s) then h("AButton", "Take"); h("XButton", "ToHand"); h("YButton", "Menu") end
    elseif k == "quick" then
        if slotItem(s) then h("AButton", "Take"); h("XButton", "Use") end
    end
    h("LBumper", "Columns")
    h("BButton", "Close")
    return out
end

local function drawHints(ui, w, s)
    local list = hintsFor(s)
    if #list == 0 or not Joypad.Texture then return end
    local tm = getTextManager()
    local fh = tm:getFontHeight(UIFont.Small)
    local isz = math.max(18, fh + 2)
    local gap, pad = 14, 8
    local total = pad
    for _, it in ipairs(list) do
        it.w = TGI.Theme.measure(UIFont.Small, it[2])
        total = total + isz + 4 + it.w + gap
    end
    total = total - gap + pad
    local bh = isz + 8
    local x = math.floor(w:getAbsoluteX() + (w.width - total) / 2)

    local y = w:getAbsoluteY() - bh - 4
    if y < 0 then y = w:getAbsoluteY() + w.height + 4 end
    if y + bh > getCore():getScreenHeight() - 70 then y = w:getAbsoluteY() + 2 end
    local Th = T()
    ui:drawRect(x, y, total, bh, 0.85, Th.bg.r, Th.bg.g, Th.bg.b)
    ui:drawRectBorder(x, y, total, bh, 0.9, Th.border.r, Th.border.g, Th.border.b)
    local cx = x + pad
    for _, it in ipairs(list) do
        local g = Joypad.Texture[it[1]]
        local tex = g and g.getTexture and g:getTexture()
        if tex then ui:drawTextureScaledAspect(tex, cx, y + 4, isz, isz, 1, 1, 1, 1) end
        if it[1] == "LBumper" then

            local g2 = Joypad.Texture.RBumper
            local t2 = g2 and g2.getTexture and g2:getTexture()
            if t2 then cx = cx + isz + 2; ui:drawTextureScaledAspect(t2, cx, y + 4, isz, isz, 1, 1, 1, 1) end
        end
        ui:drawText(it[2], cx + isz + 4, y + 4 + (isz - fh) / 2, Th.text.r, Th.text.g, Th.text.b, 1, UIFont.Small)
        cx = cx + isz + 4 + it.w + gap
    end
end

local El = ISUIElement:derive("TGIJoyCursor")
function El:new()
    local o = ISUIElement:new(0, 0, 1, 1)
    setmetatable(o, self)
    self.__index = self
    return o
end
function El:instantiate()
    ISUIElement.instantiate(self)
    self.javaObject:setConsumeMouseEvents(false)
end
function El:render()
    local w = W() and W().instance
    if not w or not J.cur or not J.active(w.pn) then return end

    local now = getTimestampMs()
    if not J._rs or now - (J._rsT or 0) > 100 then J._rs, J._rsT = spots(), now end
    local s = find(J._rs, J.cur)
    local ok, err = pcall(drawHints, self, w, s)
    if not ok and not J.hintErr then J.hintErr = true; print("[TGI] gamepad hints: " .. tostring(err)) end

    pcall(function()
        local item = nil
        if s and not Drag().active and not getPlayerContextMenu(w.pn):isAnyVisible() then
            if s.kind == "cell" then
                local e = s.p:entryAtMouse(J.ax - s.el:getAbsoluteX(), J.ay - s.el:getAbsoluteY())
                if e and not s.p:isHidden(e) then item = e.item end
            elseif s.kind == "equip" then item = equipItem(s)
            elseif s.kind == "hot" or s.kind == "quick" then item = slotItem(s) end
        end
        if item then
            J.tipItem = item
            TGI.Tip.show(item, J.el, w.pn, {})
        elseif J.tipItem then
            J.tipItem = nil
            TGI.Tip.hide(J.el)
        end
    end)
    if not s then return end
    local x, y, sw, sh = s.r[1], s.r[2], s.r[3], s.r[4]
    local a = T().accent
    local pulse = 0.65 + 0.35 * math.sin(getTimestampMs() / 160)
    for i = 0, 1 do
        self:drawRectBorder(x - i, y - i, sw + i * 2, sh + i * 2, pulse, a.r, a.g, a.b)
    end
end

function J.open(pn)
    local Wm = W()
    if not Wm.instance then Wm.toggle(pn) end
    local w = Wm.instance
    if not w then return end
    setJoypadFocus(pn, w)
    J.cur = nil
    if not J.el then J.el = El:new(); J.el:initialise() end
    J.el:addToUIManager()
    J.el:setAlwaysOnTop(true)
    J.el:bringToTop()
    current()
end

local function install()
    local Wm = W()
    if not Wm or Wm.tgiJoyHooked then return end
    Wm.tgiJoyHooked = true
    function Wm:onJoypadDown(button) pcall(J.press, button) end
    function Wm:onJoypadDirUp() pcall(J.move, 0, -1) end
    function Wm:onJoypadDirDown() pcall(J.move, 0, 1) end
    function Wm:onJoypadDirLeft() pcall(J.move, -1, 0) end
    function Wm:onJoypadDirRight() pcall(J.move, 1, 0) end
    local close = Wm.close
    Wm.close = function(self, ...)
        local pn = self.pn or 0
        local r = close(self, ...)
        pcall(function()
            if JoypadState.players[pn + 1] and getJoypadFocus(pn) == self then setJoypadFocus(pn, nil) end
            if J.el then J.el:removeFromUIManager() end
            if J.tipItem then J.tipItem = nil; TGI.Tip.hide(J.el) end
        end)
        J.cur = nil
        return r
    end

    if ISButtonPrompt then
        for _, name in ipairs({ "cmdShowInventory", "cmdShowLoot" }) do
            local orig = ISButtonPrompt[name]
            if orig then
                ISButtonPrompt[name] = function(self, ...)
                    local pn = self.player or 0
                    if TGI.Options.get("replaceVanilla") and TGI.usesGrid(pn) and JoypadState.players[pn + 1] then
                        local p = getSpecificPlayer(pn)
                        if p and not p:isDead() then J.open(pn) end
                        return
                    end
                    return orig(self, ...)
                end
            end
        end
    end
end

Events.OnGameStart.Add(install)

local function padFresh() return J.ax and J.cur and J.placedAt and getTimestampMs() - J.placedAt < 300 and J.active() end
function TGI.mx()
    if padFresh() then return J.ax end
    return getMouseX()
end
function TGI.my()
    if padFresh() then return J.ay end
    return getMouseY()
end

J._spots = function() return spots() end
J._hints = function(s) return hintsFor(s) end
J._find = function(id) return find(spots(), id) end
