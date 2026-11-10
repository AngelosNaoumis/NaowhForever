-- BookPins.lua: library book pins on the world map, and your librarian while you carry books.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local L = Discovery.Library
local Style = Discovery.Style
local OpenMap = ns.Shared.OpenMap

local HINT, QUIET, GOLD = Style.HINT_RGB, Style.QUIET_RGB, Style.GOLD_RGB
local TEMPLATE = "NaowhForeverLibraryPinTemplate"
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local TURN_IN_ICON = "Interface\\Icons\\INV_Misc_Book_07"
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local OWN_KEYS = { enabled = true, mapPins = true, mapPinSize = true, mapTurnIn = true }
local BOOK_PIN_SCALE = 0.5
local TEXT_HAND_IN = ns.L("Hand in to %s, %s")
local TEXT_TAKES_ONE = ns.L("Takes the book you carry.")
local TEXT_TAKES = ns.L("Takes the %d books you carry.")
local TEXT_WAYPOINT = ns.L("Click for a waypoint.")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local added, events
local counts = {}

local function ScaleBookPin(pin)
    ns.Shared.ScalePin(pin, BOOK_PIN_SCALE)
end

NaowhForeverLibraryPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverLibraryPinMixin.ApplyCurrentScale = ScaleBookPin

local function SoftBlue(r, g, b)
    local c = ns.ThemeTint("accentSoft", nil)
    if c then return c.r, c.g, c.b end
    return r, g, b
end

local function On()
    return S.Get("enabled") and S.Get("mapPins")
end

local function BookTip(entry)
    local book, spot = entry.book, entry.spot
    GameTooltip:SetText(book.name, 1, 1, 1)
    GameTooltip:AddLine(L.Where(spot), QUIET.r, QUIET.g, QUIET.b)
    if spot[C.SPOT_NOTE] then GameTooltip:AddLine(spot[C.SPOT_NOTE], 1, 1, 1, true) end
    local npc = L.TurnIn(book)
    local hr, hg, hb = SoftBlue(HINT.r, HINT.g, HINT.b)
    GameTooltip:AddLine(TEXT_HAND_IN:format(npc.name, npc.place), hr, hg, hb, true)
end

local function TurnInTip(entry)
    GameTooltip:SetText(entry.npc.name, 1, 1, 1)
    local text = entry.count == 1 and TEXT_TAKES_ONE or TEXT_TAKES:format(entry.count)
    GameTooltip:AddLine(text, GOLD.r, GOLD.g, GOLD.b)
end

local function CountCarried()
    wipe(counts)
    for _, book in ipairs(ns.LibraryBooks) do
        if L.ForMe(book) and L.Carried(book) then
            local kind = book.turnIn or C.TURN_IN
            counts[kind] = (counts[kind] or 0) + 1
        end
    end
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

function NaowhForeverLibraryPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverLibraryPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverLibraryPinMixin:OnAcquired(entry, x, y)
    ns.Shared.PinClicks(self)
    self.entry = entry
    self:SetSize(S.Get("mapPinSize"), S.Get("mapPinSize"))
    local icon = entry.book and (C_Item.GetItemIconByID(entry.book.item) or BOOK_ICON) or TURN_IN_ICON
    self.Icon:SetTexture(icon)
    self.Icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    self:SetPosition(x, y)
    self:ApplyCurrentScale()
end

function NaowhForeverLibraryPinMixin:OnMouseEnter()
    local entry = self.entry
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if entry.book then BookTip(entry) else TurnInTip(entry) end
    GameTooltip:AddLine(TEXT_WAYPOINT, SoftBlue(HINT.r, HINT.g, HINT.b))
    GameTooltip:Show()
end

function NaowhForeverLibraryPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function NaowhForeverLibraryPinMixin:OnClick(button)
    if button ~= "LeftButton" then return end
    local entry = self.entry
    if entry.book then
        L.PlaceBook(entry.book, entry.spot)
    else
        ns.PlaceWaypoint(entry.npc.name, entry.npc.map, entry.npc.x, entry.npc.y)
    end
end

local function AddBooks(map, mapID)
    for _, item in ipairs(L.OnMap(mapID)) do
        local spot = item[2]
        local x, y = OpenMap.Spot(map, mapID, spot[C.SPOT_X] / C.PERCENT, spot[C.SPOT_Y] / C.PERCENT)
        if x then map:AcquirePin(TEMPLATE, { book = item[1], spot = spot }, x, y) end
    end
end

local function AddTurnIns(map, mapID)
    for kind, n in pairs(counts) do
        local npc = ns.LibraryTurnIns[kind][L.Side()]
        local x, y
        if npc.map == mapID then x, y = OpenMap.Spot(map, mapID, npc.x / C.PERCENT, npc.y / C.PERCENT) end
        if x then map:AcquirePin(TEMPLATE, { npc = npc, count = n }, x, y) end
    end
end

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    CountCarried()
    local turnIns = S.Get("mapTurnIn")
    for _, mapID in ipairs(OpenMap.Maps(map)) do
        AddBooks(map, mapID)
        if turnIns then AddTurnIns(map, mapID) end
    end
end

local function Apply()
    if On() then
        if not added then
            WorldMapFrame:AddDataProvider(provider)
            added = true
        end
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", Redraw)
        end
        events:RegisterEvent("BAG_UPDATE_DELAYED")
        events:RegisterEvent("QUEST_TURNED_IN")
    elseif events then
        events:UnregisterAllEvents()
    end
    Redraw()
end

local function OnSet(key)
    if OWN_KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
