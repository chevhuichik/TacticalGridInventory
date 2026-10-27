require "TGI/TGI_FontData"
require "TGI/TGI_FontData_Tektur"
TGI = TGI or {}
local F = {}
TGI.Font = F

local function DATA()
    local O = TGI.Options
    if O and O.get and tonumber(O.get("fontFace")) == 2 and TGI.FontDataTektur then return TGI.FontDataTektur end
    return TGI.FontData
end
local tex = {}

local cpCache, cpN = {}, 0
local function codes(s)
    local c = cpCache[s]
    if c then return c end
    c = {}
    local i, n = 1, #s
    while i <= n do
        local b = string.byte(s, i)
        if b >= 0xC0 and b < 0xF0 and i < n then
            local b2 = string.byte(s, i + 1)
            if b2 and b2 >= 0x80 and b2 < 0xC0 then
                if b < 0xE0 then c[#c + 1] = (b - 0xC0) * 64 + (b2 - 0x80); i = i + 2
                else
                    local b3 = string.byte(s, i + 2) or 0x80
                    c[#c + 1] = (b - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80); i = i + 3
                end
            else c[#c + 1] = b; i = i + 1 end
        else c[#c + 1] = b; i = i + 1 end
    end
    cpN = cpN + 1
    if cpN > 2000 then cpCache, cpN = {}, 1 end
    cpCache[s] = c
    return c
end

local function atlasFor(font)
    local h = getTextManager():getFontHeight(font or UIFont.Small)
    local d = DATA()
    local set = (h <= 15 and d.s) or d.m
    return set, h / set.lineH
end

local function keyOf(set) return set.tex end

local okCache, okN = {}, 0
local function covered(s, set)
    local k = keyOf(set) .. s
    local v = okCache[k]
    if v ~= nil then return v end
    v = true
    for _, c in ipairs(codes(s)) do
        if not set.g[c] then v = false; break end
    end
    okN = okN + 1
    if okN > 2000 then okCache, okN = {}, 1 end
    okCache[k] = v
    return v
end

function F.canDraw(s, font)
    local set = atlasFor(font)
    return covered(tostring(s), set)
end

function F.on() return TGI.Theme and TGI.Theme.modern and TGI.Theme.modern() end

local gwCache, gwN = {}, 0
local function gameW(s, font)
    local k = tostring(font) .. s
    local v = gwCache[k]
    if v then return v end
    v = getTextManager():MeasureStringX(font or UIFont.Small, s)
    gwN = gwN + 1
    if gwN > 3000 then gwCache, gwN = {}, 1 end
    gwCache[k] = v
    return v
end
local function natural(s, set, k)
    local w = 0
    for _, c in ipairs(codes(s)) do w = w + set.g[c][7] end
    return w * k
end

function F.width(s, font)
    s = tostring(s or "")
    local set, k = atlasFor(font)
    if not covered(s, set) then return gameW(s, font) end
    return math.floor(math.min(natural(s, set, k), gameW(s, font)) + 0.5)
end

function F.draw(ui, s, x, y, r, g, b, a, font)
    s = tostring(s or "")
    local set, k = atlasFor(font)
    if not covered(s, set) then return end
    local key = keyOf(set)
    local t = tex[key]
    if t == nil then t = getTexture(set.tex) or false; tex[key] = t end
    local jo = ui.javaObject
    if not t or not jo then return end

    local T = TGI.Theme
    a = (a or 1) * ((T and T.uiAlpha and T.uiAlpha()) or 1) * ((T and T.fadeOf and T.fadeOf(ui)) or 1)

    local nat, gw = natural(s, set, k), gameW(s, font)
    local kx, ky = k, k
    if nat > gw and nat > 0 then
        local ratio = gw / nat
        kx = k * ratio
        ky = k * math.max(ratio, 0.85)
    end
    local y0 = y + (set.lineH * (k - ky)) / 2
    local cx = x
    for _, c in ipairs(codes(s)) do
        local m = set.g[c]
        if c ~= 32 then

            jo:DrawSubTextureRGBA(t, m[1], m[2], m[3], m[4], cx + m[5] * kx, y0 + m[6] * ky, m[3] * kx, m[4] * ky, r, g, b, a)
        end
        cx = cx + m[7] * kx
    end
end
function F.drawRight(ui, s, x, y, r, g, b, a, font)
    F.draw(ui, s, x - F.width(s, font), y, r, g, b, a, font)
end
function F.drawCentre(ui, s, x, y, r, g, b, a, font)
    F.draw(ui, s, x - F.width(s, font) / 2, y, r, g, b, a, font)
end

return F
