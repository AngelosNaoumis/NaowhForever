-- Tooltip.lua: The Market's lines on item tooltips: what your stack fetches, how its price moved and what disenchanting it gives.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local C = Market.C
local History = Market.History

local COIN_SIZE = 12
local TEXT_HEAD = "The Market"
local TEXT_STACK = ns.L("Stack of %d")
local TEXT_DAYS = ns.L("Over %d days")
local TEXT_DAY = ns.L("Since yesterday")
local TEXT_CHANGE = "%+.0f%%"
local TEXT_DISENCHANT = ns.L("Disenchant")
local TEXT_ABOUT = ns.L("about %s")
local TEXT_MADE_BY = ns.L("Made by")
local TEXT_YOU = ns.L("You")
local TEXT_WHO = "%s, %s"
local TEXT_MATS = ns.L("Materials %s")
local TEXT_PROFIT = ns.L("profit %s")
local TEXT_LOSS = ns.L("loss %s")
local TEXT_INTO = ns.L("Crafts into")
local TEXT_OVER = ns.L("+%s a craft over selling it")
local TEXT_SOLD = ns.L("You sold %d")
local TEXT_SOLD_AT = ns.L("%s each, %s")

local hooked
local lines = {}
local count = 0

local function On()
    return Market.On() and S.Get("tooltip")
end

local function Coins(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper, COIN_SIZE)
end

local function Add(left, right, color)
    count = count + 1
    local line = lines[count] or {}
    lines[count] = line
    line[1], line[2], line[3] = left, right, color
end

local function StackSize(tooltip, itemID)
    local owner = tooltip:GetOwner()
    local bag = owner and owner.GetBagID and owner:GetBagID()
    local info = bag and C_Container.GetContainerItemInfo(bag, owner:GetID())
    return info and info.itemID == itemID and info.stackCount or 1
end

local function Disenchant(link, itemID)
    local list = ns.AuctionPriceList
    if not list then return end
    local P = ns.Professions
    local values = P and P.DisenchantValues
    if not values then return end
    local _, _, quality, baseLevel, _, _, _, _, equip, _, _, classID = C_Item.GetItemInfo(link)
    if not (quality and values.ItemTakes(itemID, classID, quality, equip)) then return end
    local prices = list()
    if not prices then return end
    local gross = values.Expected(classID, quality, C_Item.GetDetailedItemLevelInfo(link) or baseLevel, prices)
    return gross and values.AfterCut(gross)
end

local function ProfessionName(id)
    local info = id and C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)
    return info and info.professionName or ""
end

local function Who(row)
    return TEXT_WHO:format(row.who or TEXT_YOU, ProfessionName(row.prof))
end

local function CraftLines(itemID)
    local Crafts = Market.Crafts
    local made = Crafts.Made(itemID)
    if made then
        Add(TEXT_MADE_BY, Who(made))
        if made.profit then
            local up = made.profit >= 0
            Add(TEXT_MATS:format(Coins(made.cost)), (up and TEXT_PROFIT or TEXT_LOSS):format(Coins(math.abs(made.profit))),
                up and St.HAVE_RGB or St.RED_RGB)
        end
    end
    local into = Crafts.Into(itemID)
    if into and into ~= made then
        Add(TEXT_INTO, C_Item.GetItemNameByID(into.output) or "")
        Add(Who(into), TEXT_OVER:format(Coins(into.gain)), St.HAVE_RGB)
    end
end

local function Collect(tooltip, itemID, link)
    count = 0
    local each = ns.AuctionPrice and ns.AuctionPrice(itemID)
    local stack = each and StackSize(tooltip, itemID)
    if stack and stack > 1 then Add(TEXT_STACK:format(stack), Coins(each * stack)) end
    local change, days = History.Change(itemID, C.CHANGE_DAYS)
    if change then
        Add(days == 1 and TEXT_DAY or TEXT_DAYS:format(days), TEXT_CHANGE:format(change),
            change >= 0 and St.HAVE_RGB or St.RED_RGB)
    end
    local disenchant = Disenchant(link, itemID)
    if disenchant then Add(TEXT_DISENCHANT, TEXT_ABOUT:format(Coins(disenchant))) end
    CraftLines(itemID)
    local sale = Market.Sales.Last(itemID)
    if sale then Add(TEXT_SOLD:format(sale.qty), TEXT_SOLD_AT:format(Coins(sale.price), ns.Shared.Ago(sale.at))) end
end

local function OnItem(tooltip, data)
    if not On() then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    -- Comparison tooltips have no GetItem: it is GameTooltipDataMixin's, not TooltipDataHandlerMixin's.
    local _, link = TooltipUtil.GetDisplayedItem(tooltip)
    if not link then return end
    Collect(tooltip, id, link)
    if count == 0 then return end
    local head, w, m = T.accent, T.fg, T.muted
    tooltip:AddLine(TEXT_HEAD, head.r, head.g, head.b)
    for i = 1, count do
        local line = lines[i]
        local c = line[3] or w
        tooltip:AddDoubleLine(line[1], line[2], m.r, m.g, m.b, c.r, c.g, c.b)
    end
end

local function Apply()
    if hooked or not On() then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end

S.OnChange(function(key)
    if key == "enabled" or key == "tooltip" then Apply() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    hooksecurefunc(ns, "Apply", Apply)
    Apply()
end)
