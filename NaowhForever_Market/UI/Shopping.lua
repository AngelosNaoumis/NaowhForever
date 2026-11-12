-- Shopping.lua: the panel's Shopping List page: what your Shopping List and your alts' still need, each counted on its own list when bought.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Finder = Market.Finder

local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP, GAP = 40, 32, 15, 8, 3, 10
local BUTTON_W, BUTTON_H = 86, 24
local ROSTER = "marketCharacters"
local BUY_EVENTS = { "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED" }
local TEXT_LIST = ns.L("From Professions, what you still need")
local TEXT_EMPTY = ns.L("Nothing on your Shopping List.")
local TEXT_MORE = ns.L("%d more")
local TEXT_MORE_FOR = ns.L("%d more for %s")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")

local page, head, watch, finder, events, roster
local entries, pool, alts = {}, {}, {}
local buying = {}

local Page = {}
Market.Pages.shop = Page

local function Shopping()
    local P = ns.Professions
    return P and P.Shopping
end

local function Add(materials, owner, who)
    for _, m in ipairs(materials) do
        local n = #entries + 1
        local e = pool[n] or {}
        pool[n] = e
        e.item, e.qty, e.owner, e.who = m.item, m.qty, owner, who
        entries[n] = e
    end
end

local function ByAltName(a, b)
    local x, y = roster[a].name, roster[b].name
    if x ~= y then return x < y end
    return a < b
end

function Page.Entries()
    wipe(entries)
    local shopping = Shopping()
    if not shopping then return entries end
    Add((shopping.Materials()))
    roster = ns.AccountSettings()[ROSTER]
    if not roster then return entries end
    wipe(alts)
    local me, myName, house = UnitGUID("player"), UnitName("player"), Market.HouseKey()
    for guid, alt in pairs(roster) do
        if guid ~= me and alt.name ~= myName and alt.house == house and shopping.HasList(guid, alt.name) then
            alts[#alts + 1] = guid
        end
    end
    table.sort(alts, ByAltName)
    for _, guid in ipairs(alts) do
        local name = roster[guid].name
        Add((shopping.MaterialsOf(guid, name)), guid, name)
    end
    return entries
end

local function FromList(found)
    wipe(found)
    for i, e in ipairs(Page.Entries()) do found[i] = e.item end
    return #found > 0 and TEXT_LIST or TEXT_EMPTY
end

local function Side(i)
    local e = entries[i]
    if not e then return end
    return e.who and TEXT_MORE_FOR:format(e.qty, e.who) or TEXT_MORE:format(e.qty)
end

function Page.Picked()
    local at = finder and finder.listed and finder.at
    local e = at and entries[at]
    if e and e.item == finder.picked then return e end
end

local function DrawHead(itemID)
    head:SetShown(itemID ~= nil)
    Finder.PaintWatch(watch, itemID)
    if not itemID then return end
    head.icon.texture:SetTexture(C_Item.GetItemIconByID(itemID))
    local color = Items.QualityColor(itemID) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(Items.Name(itemID))
    local scan = Finder.Scan(itemID)
    head.sub:SetText(scan and TEXT_SCAN_SUB:format(Parts.Coins(scan)) or TEXT_NO_SCAN_SUB)
end

function Page.Draw()
    Finder.Draw(finder)
    DrawHead(finder.picked)
end

local function Done()
    wipe(buying)
    events:UnregisterAllEvents()
end

local function OnBuyNow(dialog)
    Done()
    local e = page:IsVisible() and Page.Picked()
    if not (e and e.item == dialog.itemID) then return end
    buying.item, buying.qty, buying.owner, buying.who = e.item, dialog.quantity, e.owner, e.who
    for _, event in ipairs(BUY_EVENTS) do events:RegisterEvent(event) end
end

local function OnEvent(_, event)
    local item, qty, owner, who = buying.item, buying.qty, buying.owner, buying.who
    Done()
    if event ~= "COMMODITY_PURCHASE_SUCCEEDED" then return end
    local shopping = Shopping()
    if owner then
        shopping.BoughtFor(owner, who, item, qty)
        if page:IsShown() then Page.Draw() end
    else
        shopping.Bought(item, qty)
        shopping.Redraw()
    end
end

local function OnListChanged()
    if page:IsShown() then Page.Draw() end
end

local function BuildHead()
    head = CreateFrame("Frame", nil, page)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head.icon = Parts.ItemIcon(head, HEAD_ICON)
    head.icon:SetPoint("LEFT")
    head.name = ns.Font(head, NAME_SIZE, nil, T.fg, true)
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", NAME_GAP, 0)
    head.name:SetPoint("RIGHT")
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.sub = ns.Font(head, St.SMALL_SIZE, nil, T.muted)
    head.sub:SetPoint("TOPLEFT", head.name, "BOTTOMLEFT", 0, -SUB_GAP)
    watch = Finder.Watch(page, BUTTON_W, BUTTON_H, Page.Draw)
    watch:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    watch:SetPoint("RIGHT")
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildHead()
    finder = Finder.New(page, St.DOCK_W - St.DOCK_PAD * 2, FromList, Page.Draw)
    finder.side = Side
    finder.frame:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -GAP)
    finder.frame:SetPoint("BOTTOMRIGHT")
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    hooksecurefunc(_G.AuctionHouseFrame.BuyDialog, "BuyNow", OnBuyNow)
    Shopping().OnChange(OnListChanged)
end

function Page.Show()
    page:Show()
    Page.Draw()
end

function Page.Refresh()
    Page.Draw()
end

function Page.Hide()
    page:Hide()
end
