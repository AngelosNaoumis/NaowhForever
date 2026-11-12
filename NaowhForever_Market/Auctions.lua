-- Auctions.lua: your auctions, each checked against the cheapest listing that is not yours, and cancelling them (ns.Market.Auctions).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Listings = Market.Listings

local SOLD = Enum.AuctionStatus.Sold
local OWNED_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
    { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local EVENTS = { "OWNED_AUCTIONS_UPDATED", "AUCTION_CANCELED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "ITEM_KEY_ITEM_INFO_RECEIVED" }
local LADDER_STEP = 2

local list, spare = {}, {}
local lowest, checked, cancelled, ladders = {}, {}, {}, {}
local checking, checkingKey
local wanted = false
local events

local Auctions = { list = list }
Market.Auctions = Auctions

local function Changed()
    if Auctions.onChange then Auctions.onChange() end
end

local function KeyOf(itemKey, commodity)
    if commodity then return itemKey.itemID end
    return itemKey.itemID .. ":" .. itemKey.itemLevel .. ":" .. itemKey.itemSuffix
end

local function Status(auction)
    if auction.sold then return "sold" end
    local low = lowest[auction.key]
    if not checked[auction.key] then return "checking" end
    if low == false then return "noanswer" end
    if not (low and auction.price) or auction.ahead == 0 then return "lowest" end
    return auction.ahead > S.Get("aheadAllowed") and "undercut" or "ahead"
end

local function Ahead(auction)
    local ladder = ladders[auction.key]
    if not (ladder and auction.price) then return 0 end
    local ahead = 0
    for i = 1, #ladder, LADDER_STEP do
        if ladder[i] >= auction.price then break end
        ahead = ahead + ladder[i + 1]
    end
    return ahead
end

local function KeepLadder(key)
    local ladder = ladders[key] or {}
    wipe(ladder)
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        local others = row.quantity - row.own
        if others > 0 then
            ladder[#ladder + 1] = row.price
            ladder[#ladder + 1] = others
        end
    end
    ladders[key] = ladder
end

local function Request()
    if not wanted or not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    wanted = false
    C_AuctionHouse.QueryOwnedAuctions(OWNED_SORTS)
end

local function NextCheck()
    checking = nil
    for _, auction in ipairs(list) do
        if not auction.sold and auction.commodity ~= nil and not checked[auction.key] then
            checking = auction
            break
        end
    end
    if checking then
        checkingKey = checking.key
        Listings.Want(checking)
    else
        Listings.Want(nil)
    end
end

local function Fill(auction)
    local keyInfo = C_AuctionHouse.GetItemKeyInfo(auction.itemKey)
    auction.commodity = keyInfo and keyInfo.isCommodity
    auction.key = keyInfo and KeyOf(auction.itemKey, keyInfo.isCommodity)
    auction.ahead = Ahead(auction)
end

local function Read()
    wipe(cancelled)
    for i = #list, 1, -1 do
        spare[#spare + 1] = list[i]
        list[i] = nil
    end
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info then
            local auction = table.remove(spare) or {}
            auction.auctionID, auction.itemKey, auction.itemID = info.auctionID, info.itemKey, info.itemKey.itemID
            auction.link, auction.quantity, auction.price = info.itemLink, info.quantity, info.buyoutAmount
            auction.seconds, auction.band, auction.sold = info.timeLeftSeconds, info.timeLeft, info.status == SOLD
            Fill(auction)
            list[#list + 1] = auction
        end
    end
    if not checking then NextCheck() end
end

local function Checked()
    local key = checking and checkingKey
    if not key or Listings.state == "searching" or Listings.state == "waiting" then return end
    if Listings.state == "listed" then
        lowest[key] = (Listings.Cheapest())
        KeepLadder(key)
    else
        lowest[key], ladders[key] = false, nil
    end
    checked[key] = true
    for _, auction in ipairs(list) do
        if auction.key == key then auction.ahead = Ahead(auction) end
    end
    NextCheck()
    Changed()
end

local function OnEvent(_, event)
    if event == "OWNED_AUCTIONS_UPDATED" then
        Read()
        return Changed()
    end
    if event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        for _, auction in ipairs(list) do
            if auction.commodity == nil then Fill(auction) end
        end
        if not checking then NextCheck() end
        return Changed()
    end
    if event == "AUCTION_CANCELED" then wanted = true end
    Request()
end

function Auctions.Status(auction)
    return Status(auction), lowest[auction.key]
end

function Auctions.Counts()
    local undercut, listed = 0, 0
    for _, auction in ipairs(list) do
        if Status(auction) == "undercut" then undercut = undercut + 1 end
        if not auction.sold and auction.price then listed = listed + auction.price * auction.quantity end
    end
    return undercut, listed
end

function Auctions.NextUndercut(match)
    for _, auction in ipairs(list) do
        if Status(auction) == "undercut" and Auctions.CanCancel(auction) and (not match or match(auction)) then
            return auction
        end
    end
end

function Auctions.CanCancel(auction)
    return not auction.sold and not cancelled[auction.auctionID] and C_AuctionHouse.CanCancelAuction(auction.auctionID)
end

function Auctions.CancelCost(auction)
    return C_AuctionHouse.GetCancelCost(auction.auctionID)
end

function Auctions.Cancel(auctionID)
    if cancelled[auctionID] or not C_AuctionHouse.CanCancelAuction(auctionID) then return false end
    C_AuctionHouse.CancelAuction(auctionID)
    cancelled[auctionID] = true
    return true
end

function Auctions.Start()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    wipe(lowest)
    wipe(checked)
    wipe(ladders)
    checking, checkingKey = nil, nil
    Listings.Start()
    Listings.onChange = Checked
    wanted = true
    Request()
end

function Auctions.Stop()
    if events then events:UnregisterAllEvents() end
    checking, wanted = nil, false
    Listings.Stop()
end
