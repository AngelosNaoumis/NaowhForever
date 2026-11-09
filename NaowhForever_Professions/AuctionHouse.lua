-- AuctionHouse.lua: whether the auction house is open, the edge its side panels sit beside, searching it for an item, and Shift-click on an item.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local ItemName = P.Recipes.ItemName

local edge

local function PointEdge()
    local window = ns.MarketAuctionWindow and ns.MarketAuctionWindow() or _G.AuctionHouseFrame
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", window, "TOPRIGHT")
end

local function Edge()
    if not edge then
        edge = CreateFrame("Frame", nil, UIParent)
        edge:SetSize(1, 1)
    end
    PointEdge()
    return edge
end

function ns.AuctionWindowChanged()
    if edge then PointEdge() end
end

local function AuctionHouseOpen()
    local ah = _G.AuctionHouseFrame
    return ah and ah:IsShown() and ah.SearchBar ~= nil
end

local function SearchAuctionHouse(name)
    if not (name and AuctionHouseOpen()) then return end
    local ah = _G.AuctionHouseFrame
    if ah.SetDisplayMode and _G.AuctionHouseFrameDisplayMode then
        pcall(ah.SetDisplayMode, ah, _G.AuctionHouseFrameDisplayMode.Buy)
    end
    ah.SearchBar:SetSearchText(name)
    ah.SearchBar:StartSearch()
end

local function TypingInChat()
    local box = ChatFrameUtil.GetActiveWindow()
    return box ~= nil and box:HasFocus()
end

local function ShiftClick(itemID, link)
    if S.Get("ahShiftClick") and AuctionHouseOpen() and not TypingInChat() then
        local name = ItemName(itemID)
        if name then return SearchAuctionHouse(name) end
    end
    if link then ChatFrameUtil.InsertLink(link) end
end

P.AH = {
    Open = AuctionHouseOpen,
    Edge = Edge,
    Search = SearchAuctionHouse,
    ShiftClick = ShiftClick,
}
