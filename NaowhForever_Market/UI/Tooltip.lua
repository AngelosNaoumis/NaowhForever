-- Tooltip.lua: The Market's lines on item tooltips: what your stack fetches, how its price moved, what disenchanting it gives and the best way to sell it.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local C = Market.C
local History = Market.History
local Worth = Market.Worth

local COIN_SIZE = 12
local VENDOR_PRICE = 11
local COMPACT, EACH, STACK = "compact", "each", "stack"
local TEXT_HEAD = "The Market"
local TEXT_STACK = ns.L("Stack of %d")
local TEXT_DAYS = ns.L("Over %d days")
local TEXT_DAY = ns.L("Since yesterday")
local TEXT_CHANGE = "%+.0f%%"
local TEXT_DISENCHANT = ns.L("Disenchant")
local TEXT_ABOUT = ns.L("about %s")
local TEXT_AUCTION = ns.L("Auction")
local TEXT_VENDOR = ns.L("Vendor")
local TEXT_EACH = ns.L("%s each")
local TEXT_EACH_STACK = ns.L("%s each, %s (stack)")
local TEXT_COUNT = ns.L("%s x%d")
local TEXT_BEST = { vendor = ns.L("Best: Vendor"), auction = ns.L("Best: Auction"),
    disenchant = ns.L("Best: Disenchant") }
local TEXT_BETTER = { vendor = ns.L("Better: Vendor"), auction = ns.L("Better: Auction"),
    disenchant = ns.L("Better: Disenchant") }
local TEXT_MARGIN = { vendor = ns.L("+%s over Vendor"), auction = ns.L("+%s over Auction"),
    disenchant = ns.L("+%s over Disenchant") }
local TEXT_UNDER_MARGIN = ns.L("Auction only +%s")
local TEXT_MADE_BY = ns.L("Made by")
local TEXT_YOU = ns.L("You")
local TEXT_WHO = "%s, %s"
local TEXT_MATS = ns.L("Materials %s")
local TEXT_PROFIT = ns.L("profit %s")
local TEXT_LOSS = ns.L("loss %s")
local TEXT_INTO = ns.L("Crafts into")
local TEXT_OVER = ns.L("+%s a craft over selling it")
local TEXT_VIA = "%s (%s)"
local OUTLETS = { disenchant = TEXT_DISENCHANT, vendor = ns.L("Vendor") }
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

local function Add(left, right, color, leftColor)
    count = count + 1
    local line = lines[count] or {}
    lines[count] = line
    line[1], line[2], line[3], line[4] = left, right, color, leftColor
end

local function BagSlot(tooltip, itemID)
    local owner = tooltip:GetOwner()
    local bag = owner and owner.GetBagID and owner:GetBagID()
    local info = bag and C_Container.GetContainerItemInfo(bag, owner:GetID())
    if info and info.itemID == itemID then return info end
end

local function StackSize(tooltip, itemID)
    local info = BagSlot(tooltip, itemID)
    return info and info.stackCount or 1
end

local function Disenchant(link, itemID)
    local values = ns.Professions and ns.Professions.DisenchantValues
    if not values then return end
    local _, _, quality, baseLevel, _, _, _, _, equip, _, _, classID = C_Item.GetItemInfo(link)
    if not (quality and values.ItemTakes(itemID, classID, quality, equip)) then return end
    local level = C_Item.GetDetailedItemLevelInfo(link) or baseLevel
    local required = values.RequiredSkill(level, quality)
    local prices = ns.AuctionPriceList and ns.AuctionPriceList()
    local gross = prices and values.Expected(classID, quality, level, prices)
    return gross and values.AfterCut(gross), required
end

local function Price(each, stack, how)
    if stack == 1 then return Coins(each) end
    if how == EACH then return TEXT_EACH:format(Coins(each)) end
    if how == STACK then return Coins(each * stack) end
    return TEXT_EACH_STACK:format(Coins(each), Coins(each * stack))
end

local function Counted(text, stack, how)
    if stack == 1 or how == EACH then return text end
    return TEXT_COUNT:format(text, stack)
end

local function AddBest(info, each, vendor, disenchant, required, stack)
    local auction = each and Market.AfterCut(each)
    if info and info.isBound then auction = false end
    local P = ns.Professions
    local yours = false
    if P and required then yours = P.DisenchantDeals.MeetsSkill(required) and disenchant end
    local best, margin, second, complete = Worth.Best(vendor, auction, yours)
    if not best then return end
    if stack > 1 and S.Get("tooltipStack") ~= EACH then margin = margin * stack end
    local right = margin < 0 and TEXT_UNDER_MARGIN:format(Coins(-margin)) or TEXT_MARGIN[second]:format(Coins(margin))
    Add((complete and TEXT_BEST or TEXT_BETTER)[best], right, St.HAVE_RGB, T.accent)
end

local function ProfessionName(id)
    local info = id and C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)
    return info and info.professionName or ""
end

local function Who(row)
    return TEXT_WHO:format(row.who or TEXT_YOU, ProfessionName(row.prof))
end

local function Via(text, row)
    local outlet = OUTLETS[row.outlet]
    if not outlet then return text end
    return TEXT_VIA:format(text, outlet)
end

local function CraftLines(itemID)
    local Crafts = Market.Crafts
    local made = Crafts.Made(itemID)
    if made then
        Add(TEXT_MADE_BY, Who(made))
        if made.profit then
            local up = made.profit >= 0
            Add(TEXT_MATS:format(Coins(made.cost)),
                Via((up and TEXT_PROFIT or TEXT_LOSS):format(Coins(math.abs(made.profit))), made),
                up and St.HAVE_RGB or St.RED_RGB)
        end
    end
    local into = Crafts.Into(itemID)
    if into and into ~= made then
        Add(TEXT_INTO, Via(C_Item.GetItemNameByID(into.output) or "", into))
        Add(Who(into), TEXT_OVER:format(Coins(into.gain)), St.HAVE_RGB)
    end
end

local function CompactLines(each, vendor, disenchant, stack)
    local how = S.Get("tooltipStack")
    if each then Add(Counted(TEXT_AUCTION, stack, how), Price(each, stack, how)) end
    if vendor and vendor > 0 then Add(Counted(TEXT_VENDOR, stack, how), Price(vendor, stack, how)) end
    if disenchant then Add(TEXT_DISENCHANT, TEXT_ABOUT:format(Coins(disenchant))) end
end

local function DetailedLines(itemID, each, disenchant, stack)
    if each and stack > 1 and S.Get("tooltipStack") ~= EACH then Add(TEXT_STACK:format(stack), Coins(each * stack)) end
    local change, days = History.Change(itemID, C.CHANGE_DAYS)
    if change then
        Add(days == 1 and TEXT_DAY or TEXT_DAYS:format(days), TEXT_CHANGE:format(change),
            change >= 0 and St.HAVE_RGB or St.RED_RGB)
    end
    if disenchant then Add(TEXT_DISENCHANT, TEXT_ABOUT:format(Coins(disenchant))) end
    CraftLines(itemID)
    local sale = Market.Sales.Last(itemID)
    if sale then Add(TEXT_SOLD:format(sale.qty), TEXT_SOLD_AT:format(Coins(sale.price), ns.Shared.Ago(sale.at))) end
end

local function Collect(tooltip, itemID, link)
    count = 0
    local each = ns.AuctionPrice and ns.AuctionPrice(itemID)
    local info = BagSlot(tooltip, itemID)
    local stack = info and info.stackCount or 1
    local disenchant, required = Disenchant(link, itemID)
    local compact, best = S.Get("tooltipStyle") == COMPACT, S.Get("tooltipBest")
    local vendor = (compact or best) and select(VENDOR_PRICE, C_Item.GetItemInfo(link))
    if best then AddBest(info, each, vendor, disenchant, required, stack) end
    if compact then return CompactLines(each, vendor, disenchant, stack) end
    DetailedLines(itemID, each, disenchant, stack)
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
    local w, m = T.fg, T.muted
    if S.Get("tooltipStyle") ~= COMPACT then
        local head = T.accent
        tooltip:AddLine(TEXT_HEAD, head.r, head.g, head.b)
    end
    for i = 1, count do
        local line = lines[i]
        local c, l = line[3] or w, line[4] or m
        tooltip:AddDoubleLine(line[1], line[2], l.r, l.g, l.b, c.r, c.g, c.b)
    end
end

function Market.ShowsPrice(tooltip, itemID)
    if not (hooked and On() and select(2, TooltipUtil.GetDisplayedItem(tooltip))) then return false end
    if S.Get("tooltipStyle") == COMPACT then return true end
    return S.Get("tooltipStack") == STACK and StackSize(tooltip, itemID) > 1
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
