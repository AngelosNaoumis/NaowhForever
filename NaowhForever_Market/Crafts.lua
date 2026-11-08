-- Crafts.lua: what your characters' known recipes make, priced from your last scan, and how many your bags can make (Market.Crafts).
local ns = _G.NaowhForever

local GetItemCount = C_Item.GetItemCount
local GetItemInfo = C_Item.GetItemInfo

local Market = ns.Market

local ROSTER = "marketCharacters"
local VENDOR_PRICE = 11

local rows, spare, byOutput, byPart = {}, {}, {}, {}
local stale = true

local Crafts = { rows = rows }
Market.Crafts = Crafts

local function Shop()
    local P = ns.Professions
    return P and P.Shopping
end

local function Net(itemID)
    local scan = ns.AuctionPrice and ns.AuctionPrice(itemID)
    return scan and Market.AfterCut(scan)
end

local function Raw(itemID)
    return math.max(Net(itemID) or 0, select(VENDOR_PRICE, GetItemInfo(itemID)) or 0)
end

local function Roster()
    local account = ns.AccountSettings()
    account[ROSTER] = account[ROSTER] or {}
    return account[ROSTER]
end

function Crafts.NoteMe()
    local guid = UnitGUID("player")
    if not guid then return end
    Roster()[guid] = { name = UnitName("player"), class = select(2, UnitClass("player")), house = Market.HouseKey() }
end

local function AddRow(shop, guid, who, output, m)
    local each = Net(output)
    if not (each and type(m.need) == "table") then return end
    local row = table.remove(spare) or {}
    row.guid, row.who, row.output, row.recipe, row.prof, row.need = guid, who, output, m.recipe, m.prof, m.need
    row.made = math.max(1, m.made or 1)
    row.sale = each * row.made
    local cost, raw, can, fromBags = 0, 0, math.huge, false
    for part, per in pairs(m.need) do
        local buy = shop.BuyPrice(part)
        cost = cost and buy and cost + buy * per or nil
        if shop.VendorPrice(part) then
            raw = raw + (buy or 0) * per
        else
            raw = raw + Raw(part) * per
            fromBags = true
            can = math.min(can, math.floor(GetItemCount(part) / per))
        end
    end
    row.cost, row.gain = cost, row.sale - raw
    row.profit = cost and row.sale - cost
    row.can = fromBags and can or 0
    rows[#rows + 1] = row
    if not byOutput[output] then byOutput[output] = row end
    if row.gain > 0 then
        for part in pairs(m.need) do
            local best = byPart[part]
            if not best or row.gain > best.gain then byPart[part] = row end
        end
    end
end

local function AddCharacter(shop, guid, who, makes, seen)
    for output, m in pairs(makes) do
        if not seen[output] then
            seen[output] = true
            AddRow(shop, guid, who, output, m)
        end
    end
end

function Crafts.Read()
    for i = #rows, 1, -1 do spare[#spare + 1] = table.remove(rows, i) end
    wipe(byOutput)
    wipe(byPart)
    stale = false
    local shop = Shop()
    if not (shop and shop.MakesOf) then return false end
    local me, seen = UnitGUID("player"), {}
    AddCharacter(shop, me, nil, shop.Makes(), seen)
    local house = Market.HouseKey()
    for guid, alt in pairs(Roster()) do
        local makes = guid ~= me and alt.house == house and shop.MakesOf(guid)
        if makes then AddCharacter(shop, guid, alt.name, makes, seen) end
    end
    return true
end

local function MoreFromBags(a, b)
    local x, y = math.max(0, a.gain) * a.can, math.max(0, b.gain) * b.can
    if x ~= y then return x > y end
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.output < b.output
end

local function MoreProfit(a, b)
    local x, y = a.profit or -math.huge, b.profit or -math.huge
    if x ~= y then return x > y end
    return a.output < b.output
end

function Crafts.View(fromBags, out)
    wipe(out)
    for _, row in ipairs(rows) do
        if not fromBags or row.can > 0 then out[#out + 1] = row end
    end
    table.sort(out, fromBags and MoreFromBags or MoreProfit)
    return out
end

local function MoreGain(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    return a.output < b.output
end

function Crafts.Total()
    local P = ns.Professions
    local shop = P and P.Shopping
    local order, left = {}, {}
    for _, row in ipairs(rows) do
        if row.can > 0 and row.gain > 0 then order[#order + 1] = row end
    end
    table.sort(order, MoreGain)
    local total, n = 0, 0
    for _, row in ipairs(order) do
        local make = math.huge
        for part, per in pairs(row.need) do
            if not shop.VendorPrice(part) then
                left[part] = left[part] or GetItemCount(part)
                make = math.min(make, math.floor(left[part] / per))
            end
        end
        if make > 0 then
            for part, per in pairs(row.need) do
                if left[part] then left[part] = left[part] - make * per end
            end
            total, n = total + row.gain * make, n + 1
        end
    end
    return total, n
end

function Crafts.Fresh()
    if stale then return Crafts.Read() end
    return Shop() ~= nil
end

function Crafts.Made(itemID)
    if stale then Crafts.Read() end
    return byOutput[itemID]
end

function Crafts.Into(itemID)
    if stale then Crafts.Read() end
    return byPart[itemID]
end

function Crafts.CanQueue(row)
    local P = ns.Professions
    return row.who == nil and P ~= nil and P.CraftQueue ~= nil and P.Settings.Get("craftQueue") == true
end

function Crafts.Queue(row, count)
    local P = ns.Professions
    if not (P and Crafts.CanQueue(row)) then return false end
    P.CraftQueue.AddWithShopping({ recipeID = row.recipe, name = C_Item.GetItemNameByID(row.output),
        icon = C_Item.GetItemIconByID(row.output), need = row.need, prof = row.prof }, count)
    return true
end

function Crafts.Changed()
    stale = true
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if Market.On() then Crafts.NoteMe() end
end)
