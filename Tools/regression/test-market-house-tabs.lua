-- Run with Lua 5.1 from the repository root: The Market's Farm, Price Graph and Reagents tabs under Blizzard's auction
-- house look like Blizzard's own tabs beside them. On the stock look they copy its tab art (atlases, anchors), its
-- fonts, label offsets, height, layer and the seam between its tabs; under a skin that strips that art (EllesmereUI's
-- flat tabs) they copy the skin's label font, colours and height and draw the same flat block. The picked tab is the
-- page docked beside the auction house. None of Blizzard's frames is written to.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local writes = 0
local function Region(kind, parent)
    local r = { kind = kind, parent = parent, points = {}, shown = true, scripts = {}, children = {}, regions = {} }
    if parent then parent.regions[#parent.regions + 1] = r end
    function r:GetObjectType() return self.kind end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
    function r:GetNumPoints() return #self.points end
    function r:SetShown(on) self.shown = on and true or false end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetAtlas(atlas, size) self.atlas, self.atlasSize = atlas, size end
    function r:GetAtlas() return self.atlas end
    function r:GetTexture() return self.file end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha or 1 end
    function r:SetBlendMode(m) self.blend = m end
    function r:GetBlendMode() return self.blend or "BLEND" end
    function r:SetHorizTile(t) self.tile = t end
    function r:GetHorizTile() return self.tile or false end
    function r:SetColorTexture(...) self.color = { ... } end
    function r:SetAllPoints() self.all = true end
    function r:SetHeight(h) self.h = h end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetFontObject(f) self.fontObject, self.font = f, nil end
    function r:SetFont(face, size, flags) self.font, self.fontObject = { face, size, flags }, nil end
    function r:GetFont() return unpack(self.font) end
    function r:SetTextColor(...) self.color = { ... } end
    function r:GetTextColor() return unpack(self.color) end
    function r:SetShadowColor(...) self.shadow = { ... } end
    function r:GetShadowColor() return unpack(self.shadow or { 0, 0, 0, 0 }) end
    function r:SetShadowOffset(x, y) self.shadowAt = { x, y } end
    function r:GetShadowOffset() return unpack(self.shadowAt or { 0, 0 }) end
    function r:GetStringWidth() return #(self.text or "") * 6 end
    return r
end

local function Frame(kind, parent)
    local f = Region(kind or "Frame", parent)
    function f:CreateTexture(_, layer) local t = Region("Texture", self); t.layer = layer; return t end
    function f:CreateFontString(_, layer) local t = Region("FontString", self); t.layer = layer; return t end
    function f:GetRegions() return unpack(self.regions) end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetHeight() return self.h end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:GetParent() return self.parent end
    function f:IsMouseOver() return self.over end
    function f:IsEnabled() return not self.picked end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.right end
    function f:GetNormalFontObject() return self.normalFont end
    function f:GetHighlightFontObject() return self.hoverFont end
    function f:GetDisabledFontObject() return self.disabledFont end
    return f
end

local NORMAL, HIGHLIGHT = "GameFontNormalSmall", "GameFontHighlightSmall"
local PIECES = { Left = "uiframe-tab-left", Middle = "_uiframe-tab-center", Right = "uiframe-tab-right",
    LeftActive = "uiframe-activetab-left", MiddleActive = "_uiframe-activetab-center",
    RightActive = "uiframe-activetab-right", LeftHighlight = "uiframe-tab-left",
    MiddleHighlight = "_uiframe-tab-center", RightHighlight = "uiframe-tab-right" }

local function BlizzardTab(text, left, picked)
    local tab = Frame("Button")
    tab.h, tab.level, tab.left, tab.right, tab.picked = 32, 5, left, left + 90, picked
    tab.normalFont, tab.hoverFont, tab.disabledFont = NORMAL, HIGHLIGHT, HIGHLIGHT
    tab.Text = Region("FontString", tab)
    tab.Text.text = text
    tab.Text:SetPoint("CENTER", tab, "CENTER", 0, picked and -3 or 2)
    for name, atlas in pairs(PIECES) do
        local piece = Region("Texture", tab)
        piece.atlas = atlas
        tab[name] = piece
    end
    tab.Left:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 0)
    tab.Right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 7, 0)
    tab.Middle:SetPoint("TOPLEFT", tab.Left, "TOPRIGHT")
    tab.Middle:SetPoint("TOPRIGHT", tab.Right, "TOPLEFT")
    tab.Middle.tile = true
    tab.LeftHighlight.alpha, tab.LeftHighlight.blend = 0.4, "ADD"
    tab.LeftHighlight:SetPoint("TOPLEFT", tab.Left)
    tab.MiddleHighlight:SetPoint("TOPLEFT", tab.Middle, "TOPLEFT")
    tab.RightHighlight:SetPoint("TOPRIGHT", tab.Right)
    tab.LeftActive:SetPoint("TOPLEFT", tab, "TOPLEFT", -1, 0)
    tab.RightActive:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 8, 0)
    tab.MiddleActive:SetPoint("TOPLEFT", tab.LeftActive, "TOPRIGHT")
    tab.MiddleActive:SetPoint("TOPRIGHT", tab.RightActive, "TOPLEFT")
    local writable = {}
    return setmetatable(tab, {
        __newindex = function(t, k, v) writes = writes + 1; rawset(t, k, v) end,
        __index = writable,
    })
end

local function Blizzard()
    local buy = BlizzardTab("Buy", 20, true)
    local sell = BlizzardTab("Sell", 95)
    local auctions = BlizzardTab("Auctions", 170)
    return { buy, sell, auctions }
end

local sounds, clicked, tip = 0, nil, nil
local T = { accent = { r = 0, g = 0.57, b = 0.93 } }
local ns = {
    THEME = T,
    Market = {},
    Shared = { Parts = { TipLines = function(_, _, title, line) tip = { title, line } end } },
    L = function(text) return text end,
    Solid = function(parent, layer, color, alpha)
        local t = parent:CreateTexture(nil, layer)
        t.color = { color.r, color.g, color.b, alpha }
        return t
    end,
}
local fn = assert(loadfile("NaowhForever_Market/UI/HouseTabs.lua"))
setfenv(fn, setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = function(kind, _, parent)
        local f = Frame(kind, parent)
        if parent then parent.children[#parent.children + 1] = f end
        return f
    end,
    PlaySound = function() sounds = sounds + 1 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 },
    GameTooltip = { Hide = function() tip = nil end },
}, { __index = _G }))
fn()
local HouseTabs = ns.Market.HouseTabs

local pages = { { key = "farm", label = "Farm", tip = "farm tip" }, { key = "prices", label = "Price Graph" },
    { key = "reagents", label = "Reagents" } }
local ah = Frame()
local tabs = Blizzard()
local row = HouseTabs.New(ah, pages, function(key) clicked = key end)
writes = 0
HouseTabs.Style(row, tabs[3], tabs)
HouseTabs.Paint(row, nil)
local farm, graph, reagents = row.buttons[1], row.buttons[2], row.buttons[3]

check("a tab for each page, on the auction house, in order", row.parent == ah and #row.buttons == 3
    and farm.key == "farm" and graph.key == "prices" and reagents.key == "reagents")
check("never made from Blizzard's tab templates, so nothing joins its tab list", farm.kind == "Button"
    and #ah.children == 1 and not ah.Tabs)
check("Blizzard's tabs are only read", writes == 0)
check("as tall as Blizzard's, on its layer", farm.h == 32 and farm.level == 5)
check("each label in Blizzard's own font, at its offset", farm.label.fontObject == NORMAL
    and farm.label.text == "Farm" and graph.label.text == "Price Graph" and farm.label.points[1][3] == 2)
check("sized as Blizzard sizes its tabs", farm.w == 70 and graph.w == #"Price Graph" * 6 + 40)
check("following Blizzard's last tab, with the same seam as between its tabs",
    farm.points[1][2] == tabs[3] and farm.points[1][4] == tabs[3].left - tabs[2].right
    and graph.points[1][2] == farm and reagents.points[1][2] == graph)
check("on Blizzard's tab art, copied piece by piece", farm.art.Left.atlas == PIECES.Left
    and farm.art.MiddleActive.atlas == PIECES.MiddleActive and farm.art.LeftHighlight.atlas == PIECES.LeftHighlight
    and farm.art.Left.atlasSize and farm.art.Middle.tile and farm.art.LeftHighlight.alpha == 0.4
    and farm.art.LeftHighlight.blend == "ADD")
check("anchored as Blizzard's pieces are, to this tab and its own pieces",
    farm.art.Left.points[1][2] == farm and farm.art.Left.points[1][4] == -3
    and farm.art.Middle.points[1][2] == farm.art.Left and farm.art.Middle.points[2][2] == farm.art.Right
    and farm.art.LeftHighlight.points[1][2] == farm.art.Left)
check("unpicked, the idle art shows and the active art does not", farm.art.Left.shown and not farm.art.LeftActive.shown
    and not farm.fill.shown and not farm.line.shown)

farm.over = true
farm.scripts.OnEnter(farm)
check("hovering lights the label as Blizzard's does, with the page's tip", farm.label.fontObject == HIGHLIGHT
    and tip[1] == "Farm" and tip[2] == "farm tip")
farm.over = false
farm.scripts.OnLeave(farm)
check("and leaving puts it back", farm.label.fontObject == NORMAL and tip == nil)

farm.scripts.OnClick(farm)
check("a click names its page, with Blizzard's tab sound", clicked == "farm" and sounds == 1)
HouseTabs.Paint(row, "farm")
check("the page docked is the picked tab, drawn as Blizzard's picked tab", farm.art.LeftActive.shown
    and not farm.art.Left.shown and not farm.art.LeftHighlight.shown and farm.label.fontObject == HIGHLIGHT
    and farm.label.points[1][3] == -3)
check("the others stay idle", graph.art.Left.shown and not graph.art.LeftActive.shown
    and graph.label.fontObject == NORMAL)
HouseTabs.Paint(row, nil)
check("with nothing docked, none is picked", farm.art.Left.shown and not farm.art.LeftActive.shown)

-- A skin that strips Blizzard's art and draws its own label (EllesmereUI).
local function Skin(tab, picked)
    for name in pairs(PIECES) do tab[name].atlas, tab[name].file = "", nil end
    rawset(tab, "h", 30)
    local label = Region("FontString", tab)
    label.text = tab.Text.text
    label.font = { "skin.ttf", 11, "OUTLINE" }
    label.color = { 1, 1, 1, picked and 1 or 0.5 }
    label:SetPoint("CENTER", tab, "CENTER", 0, 0)
end
tabs = Blizzard()
Skin(tabs[1], true)
Skin(tabs[2])
Skin(tabs[3])
rawset(tabs[3], "left", tabs[2].right + 1)
writes = 0
HouseTabs.Style(row, tabs[3], tabs)
HouseTabs.Paint(row, "prices")
check("under a skin, the stock art is hidden and the skin's flat block drawn", not farm.art.Left.shown
    and not farm.art.LeftActive.shown and not farm.art.LeftHighlight.shown and farm.fill.shown)
check("at the skin's height and seam", farm.h == 30 and farm.points[1][4] == 1)
check("in the skin's font", farm.label.font[1] == "skin.ttf" and farm.label.font[2] == 11
    and farm.label.font[3] == "OUTLINE" and farm.label.points[1][3] == 0)
check("with its idle and picked label colours", farm.label.color[4] == 0.5 and graph.label.color[4] == 1)
check("and its line under the picked tab only", graph.line.shown and not farm.line.shown)
check("Blizzard's skinned tabs are only read too", writes == 0)

print(("test-market-house-tabs: %d checks passed"):format(checks))
