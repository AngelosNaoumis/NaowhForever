-- Mail.lua: what a mail's attachments would fetch at auction, as one line on the inbox's own tooltip.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings

local COIN_SIZE = 12
local TOTAL_KEEP = 0.5
local TEXT_TOTAL = ns.L("Attachments: %s at auction")

local hooked
local keptIndex, keptAt, keptTotal

local function On()
    return Market.On() and S.Get("tooltip") and S.Get("tooltipMail")
end

local function Total(index)
    local now = GetTime()
    if index == keptIndex and now - keptAt < TOTAL_KEEP then return keptTotal end
    local total = 0
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local _, itemID, _, count = GetInboxItem(index, i)
        local price = itemID and ns.AuctionPrice and ns.AuctionPrice(itemID)
        if price then total = total + price * (count or 1) end
    end
    keptIndex, keptAt, keptTotal = index, now, total
    return total
end

local function OnInboxEnter(button)
    if not (On() and button.hasItem) then return end
    local total = Total(button.index)
    if total == 0 then return end
    local c = T.fg
    GameTooltip:AddLine(TEXT_TOTAL:format(C_CurrencyInfo.GetCoinTextureString(total, COIN_SIZE)), c.r, c.g, c.b)
    GameTooltip:Show()
end

local function Apply()
    if hooked or not On() then return end
    hooked = true
    hooksecurefunc("InboxFrameItem_OnEnter", OnInboxEnter)
end

S.OnChange(function(key)
    if key == "enabled" or key == "tooltip" or key == "tooltipMail" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
