-- PriceShare.lua: Prices for Other Addons, Auctionator's price API answered from Auction Prices while Auctionator is not installed.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local NAME = "Auctionator"
local MAX_AGE_DAYS = 21
local SECONDS_PER_DAY = ns.QoLConstants.SECONDS_PER_DAY
local CLASS_INDEX = 6
local GEAR = { [Enum.ItemClass.Weapon] = true, [Enum.ItemClass.Armor] = true }
local TEXT_CALLER = "Auctionator.API.v1.%s: callerID must be your addon's name"
local TEXT_USAGE = "Auctionator.API.v1.%s: %s must be a %s"

local api = {}
local stand = { API = { v1 = api } }
local callbacks = {}

local function Check(name, callerID, value, arg, kind)
    if type(callerID) ~= "string" or callerID == "" then error(TEXT_CALLER:format(name), 3) end
    if type(value) ~= kind then error(TEXT_USAGE:format(name, arg, kind), 3) end
end

local function LinkID(link)
    return (C_Item.GetItemInfoInstant(link))
end

local function Owned()
    return _G.Auctionator == stand
end

local function Price(itemID)
    if not Owned() then return end
    return (ns.AuctionPrice(itemID))
end

local function Age(itemID)
    if not Owned() then return end
    local price, at = ns.AuctionPrice(itemID)
    if not price then return end
    local days = math.max(0, math.floor((GetServerTime() - at) / SECONDS_PER_DAY))
    if days <= MAX_AGE_DAYS then return days end
end

local function Vendor(itemID)
    local P = ns.Professions
    if P and Owned() then return P.Vendors.Price(itemID) end
end

local function Disenchant(item)
    local P = ns.Professions
    local values = P and P.DisenchantValues
    if not (values and item and Owned()) then return end
    local _, _, quality, baseLevel, _, _, _, _, equip, _, _, classID = C_Item.GetItemInfo(item)
    if not (quality and values.ItemTakes(LinkID(item), classID, quality, equip)) then return end
    local prices = ns.AuctionPriceList()
    if not prices then return end
    local level = C_Item.GetDetailedItemLevelInfo(item) or baseLevel
    return (values.Expected(classID, quality, level, prices))
end

function api.GetAuctionPriceByItemID(callerID, itemID)
    Check("GetAuctionPriceByItemID", callerID, itemID, "itemID", "number")
    return Price(itemID)
end

function api.GetAuctionPriceByItemLink(callerID, itemLink)
    Check("GetAuctionPriceByItemLink", callerID, itemLink, "itemLink", "string")
    return Price(LinkID(itemLink))
end

function api.GetAuctionAgeByItemID(callerID, itemID)
    Check("GetAuctionAgeByItemID", callerID, itemID, "itemID", "number")
    return Age(itemID)
end

function api.GetAuctionAgeByItemLink(callerID, itemLink)
    Check("GetAuctionAgeByItemLink", callerID, itemLink, "itemLink", "string")
    return Age(LinkID(itemLink))
end

function api.IsAuctionDataExactByItemID(callerID, itemID)
    Check("IsAuctionDataExactByItemID", callerID, itemID, "itemID", "number")
    return Price(itemID) ~= nil
end

function api.IsAuctionDataExactByItemLink(callerID, itemLink)
    Check("IsAuctionDataExactByItemLink", callerID, itemLink, "itemLink", "string")
    if GEAR[select(CLASS_INDEX, C_Item.GetItemInfoInstant(itemLink))] then return false end
    return Price(LinkID(itemLink)) ~= nil
end

function api.GetVendorPriceByItemID(callerID, itemID)
    Check("GetVendorPriceByItemID", callerID, itemID, "itemID", "number")
    return Vendor(itemID)
end

function api.GetVendorPriceByItemLink(callerID, itemLink)
    Check("GetVendorPriceByItemLink", callerID, itemLink, "itemLink", "string")
    return Vendor(LinkID(itemLink))
end

function api.GetDisenchantPriceByItemID(callerID, itemID)
    Check("GetDisenchantPriceByItemID", callerID, itemID, "itemID", "number")
    return Disenchant(itemID)
end

function api.GetDisenchantPriceByItemLink(callerID, itemLink)
    Check("GetDisenchantPriceByItemLink", callerID, itemLink, "itemLink", "string")
    return Disenchant(itemLink)
end

function api.RegisterForDBUpdate(callerID, callback)
    Check("RegisterForDBUpdate", callerID, callback, "callback", "function")
    callbacks[#callbacks + 1] = callback
end

function ns.AuctionPricesChanged()
    if not Owned() then return end
    local handler = geterrorhandler()
    for _, callback in ipairs(callbacks) do xpcall(callback, handler) end
end

local function Installed()
    return C_AddOns.DoesAddOnExist(NAME) and C_AddOns.IsAddOnLoadable(NAME, UnitGUID("player"))
end

function ns.PriceShareFree()
    return not Installed()
end

local function Apply()
    local on = S.Get("ahShare")
    if on and _G.Auctionator == nil and not Installed() then
        _G.Auctionator = stand
    elseif not on and _G.Auctionator == stand then
        _G.Auctionator = nil
    end
end

hooksecurefunc(S, "Set", function(key)
    if key == "ahShare" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
Apply()
