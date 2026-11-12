-- Post.lua: putting an item up on the auction house from a click or key press, and the game's answer (ns.Market.Post).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local WARNING = "AUCTION_HOUSE_POST_WARNING"
local EVENTS = { "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_MULTISELL_UPDATE", "AUCTION_MULTISELL_FAILURE",
    "AUCTION_HOUSE_POST_ERROR" }

local sent = {}
local waiting = false
local confirm
local events, warningHooked
local gen = 0

local Post = {}
Market.Post = Post

local function Done(ok)
    if not waiting then return end
    waiting, confirm = false, nil
    gen = gen + 1
    if Post.onDone then Post.onDone(sent.key, sent.quantity, sent.price, ok, sent.itemID, sent.duration) end
end

local function TimedOut(postGen)
    if postGen == gen then Done(false) end
end

local function Wait()
    gen = gen + 1
    local postGen = gen
    C_Timer.After(C.POST_TIMEOUT, function() TimedOut(postGen) end)
end

local function Confirm()
    local args = confirm
    if not args then return end
    confirm = nil
    if args.commodity then
        C_AuctionHouse.ConfirmPostCommodity(args.location, args.duration, args.quantity, args.price)
    else
        C_AuctionHouse.ConfirmPostItem(args.location, args.duration, args.quantity, args.bid, args.price)
    end
    Wait()
end

local function WarningClosed()
    if confirm then Done(false) end
end

local function HookWarning()
    if warningHooked then return end
    warningHooked = true
    local dialog = StaticPopupDialogs[WARNING]
    hooksecurefunc(dialog, "OnAccept", Confirm)
    hooksecurefunc(dialog, "OnHide", WarningClosed)
end

local function OnEvent(_, event, created, total)
    if not waiting or confirm then return end
    if event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if sent.multisell then Wait() else Done(true) end
    elseif event == "AUCTION_MULTISELL_UPDATE" then
        if created >= total then Done(true) else Wait() end
    else
        Done(false)
    end
end

function Post.Ready()
    return not waiting and C_AuctionHouse.IsThrottledMessageSystemReady()
end

function Post.Waiting()
    return waiting
end

function Post.Deposit(entry, quantity, duration)
    local deposit
    if entry.commodity then
        deposit = C_AuctionHouse.CalculateCommodityDeposit(entry.itemID, duration, quantity)
    else
        local location = Market.Bags.Location(entry)
        deposit = location and C_AuctionHouse.CalculateItemDeposit(location, duration, quantity)
    end
    if deposit and not C_AuctionHouse.SupportsCopperValues() then
        deposit = math.ceil(deposit / C.SILVER) * C.SILVER
    end
    return deposit
end

function Post.Send(entry, quantity, price, duration, bid)
    if not Post.Ready() then return false end
    local location = Market.Bags.Location(entry, true)
    if not location then return false end
    local needsConfirm
    if entry.commodity then
        needsConfirm = C_AuctionHouse.PostCommodity(location, duration, quantity, price)
    else
        needsConfirm = C_AuctionHouse.PostItem(location, duration, quantity, bid, price)
    end
    sent.key, sent.quantity, sent.price = entry.key, quantity, price
    sent.itemID, sent.duration = entry.itemID, duration
    sent.multisell = not entry.commodity and quantity > 1
    waiting = true
    if needsConfirm then
        confirm = { commodity = entry.commodity, location = location, duration = duration, quantity = quantity,
            price = price, bid = bid }
        HookWarning()
    else
        Wait()
    end
    return true
end

function Post.Start()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

function Post.Stop()
    if events then events:UnregisterAllEvents() end
    waiting, confirm = false, nil
    gen = gen + 1
end
