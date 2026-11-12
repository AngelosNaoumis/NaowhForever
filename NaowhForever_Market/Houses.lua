-- Houses.lua: the other auction house you can reach, the realm's Blackwater house or your faction's while you are at Blackwater: its name, an item's price there and what selling there gains (Market.Houses).
local ns = _G.NaowhForever

local Market = ns.Market

local BLACKWATER = "Blackwater"
local CLEARLY_HIGHER = 0.1
local TEXT_BLACKWATER = ns.L("Blackwater")

local Houses = {}
Market.Houses = Houses

function Houses.Name()
    local side = ns.AuctionOtherHouse and ns.AuctionOtherHouse()
    if side == BLACKWATER then return TEXT_BLACKWATER end
    return side and select(2, UnitFactionGroup("player"))
end

function Houses.Price(itemID)
    if not ns.AuctionOtherPrice then return end
    return ns.AuctionOtherPrice(itemID)
end

function Houses.Age(at)
    return ns.AuctionAge and ns.AuctionAge(GetServerTime() - at)
end

function Houses.Gain(here, there)
    local mine, theirs = Market.AfterCut(here), Market.AfterCut(there)
    local gain = theirs - mine
    if gain == 0 or math.abs(gain) < math.min(mine, theirs) * CLEARLY_HIGHER then return end
    return gain
end
