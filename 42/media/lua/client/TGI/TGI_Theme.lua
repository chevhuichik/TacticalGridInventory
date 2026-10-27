TGI = TGI or {}
local T = {}
TGI.Theme = T

T.CELL = 44
T.BASE_CELL = 44
T.GRAIN = 0.0417
T.SCALE = 1
T.HEADER = 22
T.bg = { r = 0.025, g = 0.027, b = 0.027, a = 0.86 }
T.panel = { r = 0.04, g = 0.042, b = 0.042, a = 0.55 }
T.cell = { r = 0.06, g = 0.063, b = 0.063, a = 0.78 }
T.cellLine = { r = 0.13, g = 0.135, b = 0.135, a = 1 }
T.border = { r = 0.22, g = 0.23, b = 0.22, a = 1 }
T.text = { r = 0.86, g = 0.85, b = 0.78 }
T.dim = { r = 0.55, g = 0.56, b = 0.52 }
T.accent = { r = 0.86, g = 0.86, b = 0.82 }
T.ok = { r = 0.25, g = 0.75, b = 0.3, a = 0.35 }
T.bad = { r = 0.85, g = 0.2, b = 0.2, a = 0.35 }
T.hover = { r = 1, g = 1, b = 1, a = 0.07 }

T.THEMES = {
    {
        bg = { 0.025, 0.027, 0.027, 0.86 }, panel = { 0.04, 0.042, 0.042, 0.55 }, cell = { 0.06, 0.063, 0.063, 0.78 },
        cellLine = { 0.13, 0.135, 0.135 }, border = { 0.22, 0.23, 0.22 }, text = { 0.86, 0.85, 0.78 },
        dim = { 0.55, 0.56, 0.52 }, accent = { 0.86, 0.86, 0.82 }, metal = 1 },
    {
        bg = { 0.03, 0.045, 0.03, 0.88 }, panel = { 0.05, 0.07, 0.045, 0.6 }, cell = { 0.07, 0.09, 0.06, 0.8 },
        cellLine = { 0.15, 0.19, 0.13 }, border = { 0.26, 0.32, 0.22 }, text = { 0.84, 0.88, 0.76 },
        dim = { 0.55, 0.62, 0.5 }, accent = { 0.84, 0.87, 0.8 }, metal = 0.7 },
    {
        bg = { 0.0, 0.0, 0.0, 0.75 }, panel = { 0.08, 0.08, 0.08, 0.6 }, cell = { 0.12, 0.12, 0.12, 0.7 },
        cellLine = { 0.22, 0.22, 0.22 }, border = { 0.4, 0.4, 0.4 }, text = { 1, 1, 1 },
        dim = { 0.65, 0.65, 0.65 }, accent = { 0.92, 0.92, 0.9 }, metal = 0 },
    {
        bg = { 0.012, 0.013, 0.013, 0.92 }, panel = { 0.03, 0.032, 0.032, 0.7 }, cell = { 0.045, 0.047, 0.047, 0.85 },
        cellLine = { 0.17, 0.175, 0.17 }, border = { 0.3, 0.3, 0.28 }, text = { 0.8, 0.8, 0.76 },
        dim = { 0.48, 0.48, 0.45 }, accent = { 0.85, 0.85, 0.82 }, metal = 0 },
    {
        bg = { 0.085, 0.09, 0.055, 0.9 }, panel = { 0.11, 0.115, 0.075, 0.6 }, cell = { 0.05, 0.055, 0.04, 0.8 },
        cellLine = { 0.24, 0.25, 0.18 }, border = { 0.5, 0.51, 0.49 }, text = { 0.88, 0.87, 0.8 },
        dim = { 0.6, 0.6, 0.5 }, accent = { 0.88, 0.87, 0.82 }, metal = 1, tex = "canvas" },
    {
        bg = { 0.07, 0.07, 0.068, 0.9 }, panel = { 0.1, 0.1, 0.097, 0.62 }, cell = { 0.13, 0.13, 0.125, 0.82 },
        cellLine = { 0.24, 0.24, 0.23 }, border = { 0.74, 0.6, 0.12 }, text = { 0.9, 0.89, 0.84 },
        dim = { 0.58, 0.57, 0.53 }, accent = { 0.92, 0.78, 0.2 }, metal = 0.5 },
    {
        bg = { 0.06, 0.035, 0.02, 0.9 }, panel = { 0.085, 0.05, 0.03, 0.62 }, cell = { 0.11, 0.07, 0.04, 0.82 },
        cellLine = { 0.22, 0.14, 0.08 }, border = { 0.42, 0.27, 0.15 }, text = { 0.95, 0.86, 0.7 },
        dim = { 0.66, 0.55, 0.42 }, accent = { 0.96, 0.8, 0.52 }, metal = 0 },
    {
        bg = { 0.03, 0.06, 0.06, 0.9 }, panel = { 0.045, 0.085, 0.085, 0.62 }, cell = { 0.06, 0.11, 0.11, 0.82 },
        cellLine = { 0.13, 0.24, 0.23 }, border = { 0.3, 0.52, 0.5 }, text = { 0.86, 0.95, 0.93 },
        dim = { 0.52, 0.66, 0.64 }, accent = { 0.7, 0.92, 0.88 }, metal = 0 },
    {
        bg = { 0.012, 0.016, 0.03, 0.92 }, panel = { 0.022, 0.028, 0.05, 0.66 }, cell = { 0.032, 0.04, 0.07, 0.85 },
        cellLine = { 0.09, 0.11, 0.18 }, border = { 0.2, 0.24, 0.38 }, text = { 0.96, 0.84, 0.62 },
        dim = { 0.6, 0.55, 0.46 }, accent = { 1.0, 0.72, 0.36 }, metal = 0 },
}
T.metalK = 1
local function set(dst, c) dst.r, dst.g, dst.b = c[1], c[2], c[3]; if c[4] then dst.a = c[4] end end
function T.apply(i)
    local th = T.THEMES[i or 1] or T.THEMES[1]
    for _, k in ipairs({ "bg", "panel", "cell", "cellLine", "border", "text", "dim", "accent" }) do set(T[k], th[k]) end
    T.metalK = th.metal
    T.texName = th.tex or "metal"
    T.applyCustom()
end

function T.applyCustom()
    local O = TGI.Options
    local pr = T.PRESETS and T.PRESETS[tonumber(O and O.get and O.get("colorPreset")) or 1]
    if not pr then return end
    local bg, cell, border, text = pr.bg, pr.cell, pr.border, pr.text
    T.bg.r, T.bg.g, T.bg.b = bg[1], bg[2], bg[3]
    T.panel.r, T.panel.g, T.panel.b = bg[1] * 1.4 + 0.01, bg[2] * 1.4 + 0.01, bg[3] * 1.4 + 0.01
    T.cell.r, T.cell.g, T.cell.b = cell[1], cell[2], cell[3]
    T.cellLine.r, T.cellLine.g, T.cellLine.b = math.min(1, cell[1] * 1.8 + 0.04), math.min(1, cell[2] * 1.8 + 0.04), math.min(1, cell[3] * 1.8 + 0.04)
    T.border.r, T.border.g, T.border.b = border[1], border[2], border[3]
    T.text.r, T.text.g, T.text.b = text[1], text[2], text[3]
    T.dim.r, T.dim.g, T.dim.b = text[1] * 0.65, text[2] * 0.65, text[3] * 0.65
    T.accent.r, T.accent.g, T.accent.b = text[1], text[2], text[3]
end

T.PRESETS = {
    nil,
    { id = "Graphite", bg = { 0.04, 0.04, 0.045 }, cell = { 0.075, 0.075, 0.08 }, border = { 0.3, 0.3, 0.32 }, text = { 0.88, 0.88, 0.9 } },
    { id = "Olive",    bg = { 0.045, 0.05, 0.03 }, cell = { 0.085, 0.095, 0.06 }, border = { 0.33, 0.36, 0.24 }, text = { 0.86, 0.88, 0.76 } },
    { id = "Navy",     bg = { 0.02, 0.03, 0.05 },  cell = { 0.045, 0.06, 0.09 }, border = { 0.22, 0.3, 0.42 },  text = { 0.82, 0.87, 0.94 } },
    { id = "Desert",   bg = { 0.07, 0.06, 0.045 }, cell = { 0.12, 0.1, 0.075 },  border = { 0.46, 0.38, 0.26 }, text = { 0.93, 0.88, 0.78 } },
    { id = "Blood",    bg = { 0.05, 0.02, 0.02 },  cell = { 0.09, 0.04, 0.04 },  border = { 0.42, 0.14, 0.12 }, text = { 0.92, 0.84, 0.82 } },
    { id = "Arctic",   bg = { 0.06, 0.07, 0.08 },  cell = { 0.11, 0.13, 0.15 },  border = { 0.45, 0.55, 0.62 }, text = { 0.92, 0.96, 1.0 } },
    { id = "NightVision", bg = { 0.01, 0.04, 0.015 }, cell = { 0.02, 0.08, 0.03 }, border = { 0.12, 0.45, 0.18 }, text = { 0.55, 1.0, 0.6 } },
    { id = "Rust",     bg = { 0.05, 0.03, 0.02 },  cell = { 0.1, 0.06, 0.04 },   border = { 0.5, 0.28, 0.16 },  text = { 0.94, 0.84, 0.74 } },
    { id = "Paper",    bg = { 0.16, 0.15, 0.13 },  cell = { 0.24, 0.22, 0.19 },  border = { 0.5, 0.46, 0.38 },  text = { 0.97, 0.95, 0.9 } },
    { id = "Toxic",    bg = { 0.03, 0.04, 0.01 },  cell = { 0.06, 0.08, 0.02 },  border = { 0.55, 0.62, 0.08 }, text = { 0.88, 0.95, 0.55 } },
    { id = "Copper",   bg = { 0.05, 0.035, 0.03 }, cell = { 0.09, 0.065, 0.05 }, border = { 0.62, 0.38, 0.22 }, text = { 0.98, 0.86, 0.74 } },
    { id = "Moss",     bg = { 0.025, 0.04, 0.03 }, cell = { 0.05, 0.075, 0.055 }, border = { 0.28, 0.42, 0.3 }, text = { 0.8, 0.9, 0.82 } },
    { id = "Dusk",     bg = { 0.05, 0.03, 0.05 },  cell = { 0.09, 0.055, 0.085 }, border = { 0.5, 0.32, 0.46 }, text = { 0.96, 0.86, 0.92 } },
    { id = "Slate",    bg = { 0.04, 0.045, 0.05 }, cell = { 0.075, 0.082, 0.09 }, border = { 0.36, 0.4, 0.44 }, text = { 0.86, 0.9, 0.94 } },
    { id = "Ice",      bg = { 0.02, 0.045, 0.06 }, cell = { 0.04, 0.085, 0.11 }, border = { 0.35, 0.65, 0.8 },  text = { 0.86, 0.97, 1.0 } },
    { id = "Wine",     bg = { 0.045, 0.015, 0.025 }, cell = { 0.085, 0.03, 0.045 }, border = { 0.5, 0.18, 0.26 }, text = { 0.95, 0.85, 0.88 } },
    { id = "Hazard",   bg = { 0.03, 0.03, 0.025 }, cell = { 0.06, 0.06, 0.05 },  border = { 0.9, 0.72, 0.1 },  text = { 0.98, 0.94, 0.8 } },
}

local CAT = {
    Weapon = { 0.34, 0.18, 0.16 }, Ammo = { 0.35, 0.3, 0.12 }, WeaponPart = { 0.3, 0.2, 0.16 },
    Food = { 0.16, 0.26, 0.14 }, FirstAid = { 0.34, 0.14, 0.16 }, Medical = { 0.34, 0.14, 0.16 },
    Clothing = { 0.16, 0.2, 0.28 }, Bag = { 0.2, 0.2, 0.26 }, Container = { 0.2, 0.2, 0.26 },
    Tool = { 0.25, 0.22, 0.17 }, ToolWeapon = { 0.28, 0.2, 0.16 }, Electronics = { 0.15, 0.24, 0.27 },
    Literature = { 0.24, 0.2, 0.26 }, SkillBook = { 0.24, 0.2, 0.26 }, Material = { 0.22, 0.2, 0.17 },
    Key = { 0.3, 0.27, 0.12 }, Junk = { 0.16, 0.16, 0.16 },
}

T.texName = "metal"
local texs = {}
function T.metal()
    local n = T.texName
    if texs[n] == nil then texs[n] = getTexture("media/textures/TGI/" .. n .. ".png") or false end
    return texs[n] or nil
end
function T.grad()

    if T.modern and T.modern() then return nil end
    if T._grad == nil then T._grad = getTexture("media/textures/TGI/grad.png") or false end
    return T._grad or nil
end

local modV, fontV = false, true

local animV = true
function T.modern() return modV end

function T.ownFont() return fontV or modV end
function T.metalFill(ui, x, y, w, h, a)
    if T.modern() then return end
    local t = T.metal()
    if t and T.metalK > 0 then ui:drawTextureTiled(t, x, y, w, h, 1, 1, 1, (a or 0.5) * T.metalK) end
end

T.TIERS = {
    { 8,   0.45, 0.45, 0.45 },
    { 20,  0.30, 0.70, 0.30 },
    { 45,  0.25, 0.50, 0.95 },
    { 120, 0.65, 0.35, 0.90 },
    { 1e9, 0.95, 0.70, 0.20 },
}
local valueCache = {}
function T.value(item)
    local ok, ft = pcall(function() return item:getFullType() end)
    if not ok then return 0 end
    local v = valueCache[ft]
    if v then return v end
    if ALifeTrade and ALifeTrade.value then
        local ok2, r = pcall(ALifeTrade.value, item)
        v = ok2 and r or 0
    else
        local w = 0
        pcall(function() w = item:getActualWeight() end)
        v = 5 + w * 4
        pcall(function() if instanceof(item, "HandWeapon") and item:isRanged() then v = 150 end end)
    end
    valueCache[ft] = v
    return v
end
function T.tierColor(item)
    local v = T.value(item)
    for _, t in ipairs(T.TIERS) do if v <= t[1] then return t[2], t[3], t[4] end end
    return 0.45, 0.45, 0.45
end

local KIND_COL = {
    weapon = { 0.56, 0.32, 0.22 }, ammo = { 0.62, 0.5, 0.26 }, med = { 0.62, 0.32, 0.32 },
    food = { 0.42, 0.47, 0.26 }, tool = { 0.4, 0.44, 0.48 }, cloth = { 0.36, 0.38, 0.44 },
    bag = { 0.46, 0.43, 0.32 }, book = { 0.5, 0.46, 0.38 }, misc = { 0.36, 0.36, 0.35 },
}
local CAT_KIND = {
    Weapon = "weapon", WeaponPart = "weapon", ToolWeapon = "weapon", Explosives = "weapon",
    Ammo = "ammo", FirstAid = "med", Medical = "med", Food = "food", Cooking = "food", Water = "food",
    Tool = "tool", Electronics = "tool", Material = "tool", Gardening = "tool", Fishing = "tool", Camping = "tool",
    Communications = "tool", LightSource = "tool", Clothing = "cloth", Accessory = "cloth", Bag = "bag",
    Container = "bag", Literature = "book", SkillBook = "book", Paint = "misc", Junk = "misc",
}
local kindCache, kindN = {}, 0
function T.kindColor(item)
    local ft = item:getFullType()
    local c = kindCache[ft]
    if not c then
        local cat = ""
        pcall(function() cat = tostring(item:getDisplayCategory() or item:getCategory() or "") end)
        local k = CAT_KIND[cat]
        if not k then
            pcall(function()
                if instanceof(item, "HandWeapon") then k = "weapon"
                elseif instanceof(item, "Food") then k = "food"
                elseif instanceof(item, "InventoryContainer") then k = "bag"
                elseif instanceof(item, "Clothing") then k = "cloth"
                elseif instanceof(item, "Literature") then k = "book" end
            end)
        end
        c = KIND_COL[k or "misc"]
        kindN = kindN + 1
        if kindN > 2000 then kindCache, kindN = {}, 1 end
        kindCache[ft] = c
    end
    return c[1], c[2], c[3]
end

function T.tileColor(item)
    local mode = tonumber(TGI.Options and TGI.Options.get and TGI.Options.get("tileColor")) or 1
    if mode == 2 then return T.tierColor(item) end
    if mode == 3 then return 0.36, 0.36, 0.35 end
    return T.kindColor(item)
end

function T.catColor(cat)
    local c = CAT[cat or ""]
    if c then return c[1], c[2], c[3] end
    return 0.18, 0.19, 0.18
end

T.FONT_SMALL = UIFont.Small
T.FONT_TINY = UIFont.NewSmall or UIFont.Small
T.FONT_COUNT = UIFont.Small

local alphaV = 1
function T.uiAlpha() return alphaV end
local function readLook()
    local O = TGI.Options
    if not (O and O.get) then return end
    modV = O.get("modernUI") == true

    fontV = O.get("ownFont") ~= false and tonumber(O.get("fontFace")) ~= 3

    local sig = tostring(O.get("colorPreset")) .. "/" .. tostring(O.get("theme")) .. "/" .. tostring(O.get("tileColor"))
    if sig ~= T._colSig then
        local first = T._colSig == nil
        T._colSig = sig

        local old = {}
        for _, k in ipairs(T.COLOR_KEYS) do old[k] = { T[k].r, T[k].g, T[k].b } end
        if T.apply then pcall(T.apply, tonumber(O.get("theme")) or 1) end
        if not first then pcall(T.recolorOpen, old) end
    end
    animV = O.get("animations") ~= false
    alphaV = math.max(0.15, math.min(1, tonumber(O.get("uiAlpha") or 1) or 1))
end
T.readLook = readLook

T.COLOR_KEYS = { "bg", "panel", "cell", "cellLine", "border", "text", "dim", "accent" }
local function same(c, o) return c and o and math.abs(c.r - o[1]) < 0.002 and math.abs(c.g - o[2]) < 0.002 and math.abs(c.b - o[3]) < 0.002 end

function T.recolorOpen(old)
    local function fix(c)
        if type(c) ~= "table" or c.r == nil then return end
        for _, k in ipairs(T.COLOR_KEYS) do
            if same(c, old[k]) then c.r, c.g, c.b = T[k].r, T[k].g, T[k].b; return end
        end
    end
    local seen = {}
    local function walk(el, depth)
        if not el or seen[el] or depth > 12 then return end
        seen[el] = true
        fix(el.backgroundColor); fix(el.borderColor)
        for _, ch in pairs(el.children or {}) do walk(ch, depth + 1) end
    end
    local W = TGI.Window
    if W and W.instance then walk(W.instance, 0) end
    for _, f in pairs(W and W.bags or {}) do walk(f, 0) end
    if W and W.instance and W.instance.backdrop then walk(W.instance.backdrop, 0) end
end

function T.measure(font, str)
    local F = TGI.Font
    if F and (fontV or modV) and str ~= nil and F.canDraw(str, font) then return F.width(tostring(str), font) end
    return getTextManager():MeasureStringX(font, str)
end
local lookTick = 0
Events.OnTick.Add(function()
    lookTick = lookTick + 1
    if lookTick % 15 == 0 then pcall(readLook) end
end)
Events.OnGameStart.Add(function() pcall(readLook) end)

local APOS = { drawRect = 5, drawRectBorder = 5, drawTextureScaled = 6, drawTextureScaledAspect = 6,
    drawTexture = 4, drawText = 7, drawTextCentre = 7, drawTextRight = 7,
    drawRectStatic = 5, drawRectBorderStatic = 5, drawTextureTiled = 9 }
function T.anim() return animV end

function T.fadeOf(el)
    local f = el.tgiFade
    if f then return f end
    local p = el.parent
    for _ = 1, 4 do
        if not p then return 1 end
        local pf = p.tgiFade
        if p.tgiContentFade then pf = (pf or 1) * p.tgiContentFade end
        if pf then return pf end
        p = p.parent
    end
    return 1
end
function T.applyAlpha(cls)
    if not cls or cls.tgiAlphaApplied then return end
    cls.tgiAlphaApplied = true
    for name, pos in pairs(APOS) do
        local orig = cls[name]
        if orig then
            cls[name] = function(self, ...)
                local k = T.uiAlpha() * T.fadeOf(self)
                if k >= 0.999 then return orig(self, ...) end
                local n = select("#", ...)
                local a = { ... }
                if type(a[pos]) == "number" then a[pos] = a[pos] * k end
                return orig(self, unpack(a, 1, n))
            end
        end
    end
    T.applyFont(cls)
end

function T.applyFont(cls)
    if not cls or cls.tgiFontApplied then return end
    cls.tgiFontApplied = true
    local function wrap(name, how)
        local orig = cls[name]
        if not orig then return end
        cls[name] = function(self, str, x, y, r, g, b, a, font, ...)
            local F = TGI.Font
            if F and (fontV or modV) and str ~= nil and F.canDraw(str, font) then
                return F[how](self, tostring(str), x, y, r, g, b, a, font)
            end
            return orig(self, str, x, y, r, g, b, a, font, ...)
        end
    end
    wrap("drawText", "draw")
    wrap("drawTextRight", "drawRight")
    wrap("drawTextCentre", "drawCentre")
end

function T.outCubic(k) k = 1 - k; return 1 - k * k * k end
function T.inCubic(k) return k * k * k end
function T.inOutCubic(k) if k < 0.5 then return 4 * k * k * k end; k = -2 * k + 2; return 1 - k * k * k / 2 end
function T.outBack(k) local c = 1.4; k = k - 1; return 1 + (c + 1) * k * k * k + c * k * k end
function T.ease(self, key, target)
    self._ez = self._ez or {}
    local now = getTimestampMs()
    local e = self._ez[key]
    if not e then e = { v = target, t = now }; self._ez[key] = e; return target end
    local dt = math.min(100, now - e.t)
    e.t = now
    if dt > 0 then

        e.v = e.v + (target - e.v) * (1 - math.exp(-dt / 70))
        if math.abs(target - e.v) < 0.5 and math.abs(target) > 2 then e.v = target end
        if math.abs(target - e.v) < 0.01 then e.v = target end
    end
    return e.v
end
function T.easeGet(self, key) local e = self._ez and self._ez[key]; return e and e.v end

local SCALES = { nil, 0.75, 0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0, 2.5, 3.0 }
function T.applyScale()
    local idx = tonumber(TGI.Options and TGI.Options.get("cellScale")) or 1
    local s = SCALES[idx]
    if not s then
        local h = getCore():getScreenHeight()
        s = (h >= 2000 and 1.5) or (h >= 1400 and 1.25) or 1.0
    end

    local H = getCore():getScreenHeight()
    while s > 1.0 do
        local row = math.floor(52 * s + 0.5) + 16 + math.floor(4 * s + 0.5)
        local need = 9 * row + 2 * math.floor(15 * s + 0.5) + 12 + 220
        if need <= H then break end
        s = math.max(1.0, s - 0.05)
    end
    T.SCALE = s

    T.FONT_TINY = (s >= 1.3 and UIFont.Small) or UIFont.NewSmall or UIFont.Small
    T.FONT_COUNT = (s >= 1.3 and UIFont.Medium) or UIFont.Small
    T.CELL = math.floor(T.BASE_CELL * s + 0.5)

    T.HEADER = math.max(22, math.floor(22 * s + 0.5))
    if TGI.Equip and TGI.Equip.applyScale then TGI.Equip.applyScale() end
end

return T
