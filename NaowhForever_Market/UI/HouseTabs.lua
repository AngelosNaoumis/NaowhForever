-- HouseTabs.lua: The Market's tabs along the bottom of Blizzard's auction house, drawn as Blizzard's own tabs beside them are, stock or skinned (Market.HouseTabs).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local Parts = ns.Shared.Parts

local MIN_W, TEXT_PAD = 70, 40
local LINE_H = 1
local SKIN_FILL_RGB = { r = 0.068, g = 0.056, b = 0.052 }
local IDLE = { "Left", "Middle", "Right" }
local ACTIVE = { "LeftActive", "MiddleActive", "RightActive" }
local HOVER = { "LeftHighlight", "MiddleHighlight", "RightHighlight" }
local LAYERS = { Left = "BACKGROUND", Middle = "BACKGROUND", Right = "BACKGROUND", LeftActive = "BACKGROUND",
    MiddleActive = "BACKGROUND", RightActive = "BACKGROUND", LeftHighlight = "HIGHLIGHT",
    MiddleHighlight = "HIGHLIGHT", RightHighlight = "HIGHLIGHT" }

local names = {}

local HouseTabs = {}
Market.HouseTabs = HouseTabs

local function Blank(value)
    return value == nil or value == ""
end

local function SkinLabel(tab)
    local text = tab.Text:GetText()
    for _, region in ipairs({ tab:GetRegions() }) do
        if region ~= tab.Text and region:GetObjectType() == "FontString" and region:IsShown()
            and region:GetText() == text then
            return region
        end
    end
end

local function Picked(tabs)
    local on, off
    for _, tab in ipairs(tabs) do
        if tab:IsEnabled() then off = off or tab else on = on or tab end
    end
    return on or off, off or on
end

local function Offset(label)
    local _, _, _, x, y = label:GetPoint(1)
    return x or 0, y or 0
end

local function CopyArt(button, model)
    wipe(names)
    for name in pairs(LAYERS) do names[model[name]] = name end
    for name, texture in pairs(button.art) do
        local from = model[name]
        texture:SetAtlas(from:GetAtlas(), true)
        texture:SetAlpha(from:GetAlpha())
        texture:SetBlendMode(from:GetBlendMode())
        texture:SetHorizTile(from:GetHorizTile())
        texture:ClearAllPoints()
        for i = 1, from:GetNumPoints() do
            local point, relative, relativePoint, x, y = from:GetPoint(i)
            local key = relative and names[relative]
            texture:SetPoint(point, key and button.art[key] or button, relativePoint, x, y)
        end
    end
end

local function ReadLook(look, tabs)
    local model = tabs[#tabs]
    local on, off = Picked(tabs)
    local onLabel, offLabel = SkinLabel(on), SkinLabel(off)
    look.stock = not (Blank(model.Left:GetAtlas()) and Blank(model.Left:GetTexture()))
    look.skin = not look.stock and onLabel ~= nil and offLabel ~= nil
    look.height, look.level = model:GetHeight(), model:GetFrameLevel()
    look.font, look.hoverFont = model:GetNormalFontObject(), model:GetHighlightFontObject()
    look.onFont = on:GetDisabledFontObject()
    look.onX, look.onY = Offset(onLabel or on.Text)
    look.offX, look.offY = Offset(offLabel or off.Text)
    if not look.skin then return end
    look.face, look.size, look.flags = offLabel:GetFont()
    look.onRGB, look.offRGB = { onLabel:GetTextColor() }, { offLabel:GetTextColor() }
    look.shadowRGB, look.shadowX, look.shadowY = { offLabel:GetShadowColor() }, offLabel:GetShadowOffset()
end

local function PaintLabel(button, look, on)
    local label = button.label
    if look.skin then
        label:SetFont(look.face, look.size, look.flags)
        label:SetShadowColor(unpack(look.shadowRGB))
        label:SetShadowOffset(look.shadowX, look.shadowY)
        label:SetTextColor(unpack(on and look.onRGB or look.offRGB))
    else
        label:SetFontObject(on and look.onFont or button:IsMouseOver() and look.hoverFont or look.font)
    end
    label:ClearAllPoints()
    label:SetPoint("CENTER", on and look.onX or look.offX, on and look.onY or look.offY)
end

local function PaintTab(button)
    local row = button:GetParent()
    local look, on = row.look, button.key == row.shown
    for _, name in ipairs(IDLE) do button.art[name]:SetShown(look.stock and not on) end
    for _, name in ipairs(ACTIVE) do button.art[name]:SetShown(look.stock and on) end
    for _, name in ipairs(HOVER) do button.art[name]:SetShown(look.stock and not on) end
    button.fill:SetShown(not look.stock)
    button.line:SetShown(not look.stock and on)
    PaintLabel(button, look, on)
end

local function TabClicked(button)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    button:GetParent().onClick(button.key)
end

local function TabEnter(button)
    PaintTab(button)
    Parts.TipLines(button, "ANCHOR_TOP", button.title, button.tip)
end

local function TabLeave(button)
    PaintTab(button)
    GameTooltip:Hide()
end

local function NewTab(row, page)
    local button = CreateFrame("Button", nil, row)
    button.key, button.title, button.tip = page.key, page.label, page.tip
    button.art = {}
    for name, layer in pairs(LAYERS) do
        button.art[name] = button:CreateTexture(nil, layer)
    end
    button.fill = ns.Solid(button, "BACKGROUND", SKIN_FILL_RGB, 1)
    button.fill:SetAllPoints()
    button.line = ns.Solid(button, "OVERLAY", T.accent, 1)
    button.line:SetPoint("BOTTOMLEFT")
    button.line:SetPoint("BOTTOMRIGHT")
    button.line:SetHeight(LINE_H)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button:SetScript("OnClick", TabClicked)
    button:SetScript("OnEnter", TabEnter)
    button:SetScript("OnLeave", TabLeave)
    return button
end

function HouseTabs.New(parent, pages, onClick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(1, 1)
    row.onClick, row.look, row.buttons = onClick, {}, {}
    for i, page in ipairs(pages) do row.buttons[i] = NewTab(row, page) end
    return row
end

function HouseTabs.Style(row, after, tabs)
    local look = row.look
    ReadLook(look, tabs)
    local model = tabs[#tabs]
    local seam = model:GetLeft() - tabs[#tabs - 1]:GetRight()
    local previous = after
    for _, button in ipairs(row.buttons) do
        if look.stock then CopyArt(button, model) end
        button:SetFrameLevel(look.level)
        PaintLabel(button, look, false)
        button.label:SetText(ns.L(button.title))
        button:SetSize(math.max(MIN_W, button.label:GetStringWidth() + TEXT_PAD), look.height)
        button:ClearAllPoints()
        button:SetPoint("LEFT", previous, "RIGHT", seam, 0)
        previous = button
        PaintTab(button)
    end
end

function HouseTabs.Paint(row, key)
    row.shown = key
    for _, button in ipairs(row.buttons) do PaintTab(button) end
end
