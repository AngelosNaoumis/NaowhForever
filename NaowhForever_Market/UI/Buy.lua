-- Buy.lua: the Buy page: your Shopping List, a search by name, the listings of what you pick, and buying it.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Buy, Listings, Ladder, Spark = Market.Buy, Market.Listings, Market.Ladder, Market.Spark
local Columns = Market.Columns

local GAP, TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.GAP, St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local PANE_GAP, SECTION_GAP = 12, 12
local SHOP_W, SHOP_HEAD_H, SHOP_ROW_H, SHOP_ICON = 250, 46, 36, 24
local RESULT_ROW_H, RESULT_ICON, LOWEST_W, LISTED_W = 28, 20, 120, 70
local ROW_IN, ICON_GAP, TITLE_SIZE, SUB_GAP = 8, 8, 14, 4
local SEARCH_H, NAME_SIZE, NAME_H = St.SEARCH_H, 16, 24
local QTY_W, QTY_LETTERS, BUY_W = 70, 5, 260
local SCROLL_IN = 4
local FAV_HEAD_H, FAV_ROW_H, FAV_ROWS, STAR, SPARK_W = 30, 30, 5, 18, 110
local FAV_H = FAV_HEAD_H + FAV_ROWS * FAV_ROW_H
local DETAIL_H = NAME_H + SECTION_GAP + Ladder.HEIGHT + SECTION_GAP + BUTTON_H
local TEXT_SHOP = ns.L("Shopping List")
local TEXT_SHOP_SUB = ns.L("From Professions, what you still need")
local TEXT_SHOP_EMPTY = ns.L("Nothing on your Shopping List.")
local TEXT_SHOP_OFF = ns.L("Turn on Professions for its Shopping List.")
local TEXT_MORE = ns.L("%d more")
local TEXT_SEARCH = ns.L("Search the auction house")
local TEXT_SEARCHING = ns.L("Searching")
local TEXT_NO_RESULTS = ns.L("Search by name, then press Enter.")
local TEXT_LADDER = ns.L("Listings now, cheapest first")
local TEXT_LISTED = ns.L("%s listed")
local TEXT_NONE = ns.L("Nobody is selling this")
local TEXT_YOURS = ns.L(" yours")
local TEXT_TAKE = ns.L("%d of %d")
local TEXT_BUY = ns.L("Buy %d for %s")
local TEXT_BUY_ONE = ns.L("Buy for %s")
local TEXT_CONFIRM = ns.L("Confirm %s")
local TEXT_QUOTING = ns.L("Getting the price")
local TEXT_BUYING = ns.L("Buying")
local TEXT_PICK = ns.L("Pick something to buy")
local TEXT_AVERAGE = ns.L("Average %s each")
local TEXT_SHORT = ns.L("Only %d listed.")
local TEXT_QUOTED = ns.L("The price is %s each. Confirm to buy.")
local TEXT_OVER = ns.L("The price went up to %s each. Confirm only if you still want it.")
local TEXT_BOUGHT = ns.L("Bought %d.")
local TEXT_FAILED = ns.L("The purchase did not go through.")
local TEXT_UNAVAILABLE = ns.L("Not enough is left at that price. Pick it again for new listings.")
local TEXT_ITEM, TEXT_LOWEST, TEXT_LISTED_HEAD = ns.L("Item"), ns.L("Lowest"), ns.L("Listed")
local TEXT_FAVOURITES = ns.L("Favourites")
local TEXT_FAV_EMPTY = ns.L("Star an item you buy often and it stays here.")
local TEXT_STAR = ns.L("Favourite")
local TEXT_STAR_TIP = ns.L("Keeps this item under Favourites, one click from its listings.")

local page, shopPane, shopScroll, shopList, shopNote, main, search, resultsScroll, resultsList, resultsNote
local detail, nameText, ladder, quantity, buyButton, statusText, star, spark, sorter
local favPane, favScroll, favList, favNote, itemEvents
local shopRows, resultRows, rungs, favRows, favourites, results = {}, {}, {}, {}, {}, {}
local active, watching = false, false

local Page = {}
Market.Pages.buy = Page

local function Coins(copper)
    return Parts.Coins(copper)
end

local function Quantity()
    return math.max(1, tonumber(quantity:GetText()) or 1)
end

local function KeyLook(itemKey)
    local info = C_AuctionHouse.GetItemKeyInfo(itemKey)
    if not info then return Items.Name(itemKey.itemID), T.fg, nil end
    return info.itemName, ITEM_QUALITY_COLORS[info.quality] or T.fg, info.iconFileID
end

local Enable = St.Enable

local function Panel(frame)
    ns.Solid(frame, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(frame, St.BORDER_RGB)
end

local function Rows(list, count, pool, new, paint, height)
    local y = 0
    for i = 1, count do
        local row = pool[i] or new()
        pool[i] = row
        paint(row, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + height
    end
    for i = count + 1, #pool do pool[i]:Hide() end
    list:SetHeight(math.max(1, y))
end

local function RowEnter(row)
    row.hover:Show()
end

local function RowLeave(row)
    row.hover:Hide()
end

local function NewListRow(parent, icon, onClick)
    local row = CreateFrame("Button", nil, parent)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.icon = Parts.ItemIcon(row, icon)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", onClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function ShopClicked(row)
    Page.PickItem(row.item, row.qty)
end

local function NewShopRow()
    local row = NewListRow(shopList, SHOP_ICON, ShopClicked)
    row:SetHeight(SHOP_ROW_H)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", -ROW_IN, 0)
    row.sub = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", ICON_GAP, 0)
    return row
end

local function FavClicked(row)
    Buy.Pick(Buy.FavouriteKey(row.item))
    quantity:SetText(1)
    Page.Draw()
end

local function NewFavRow()
    local row = NewListRow(favList, SHOP_ICON, FavClicked)
    row:SetHeight(FAV_ROW_H)
    row.price = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.price:SetPoint("RIGHT", -ROW_IN, 0)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.price, "LEFT", -ICON_GAP, 0)
    return row
end

local function PaintFavRow(row, i)
    local item = favourites[i]
    row.item = item
    row.stripe:SetShown(i % 2 == 0)
    row.picked:SetShown(Buy.picked.itemID == item)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(item))
    local color = Items.QualityColor(item) or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(Items.Name(item))
    local scan = ns.AuctionPrice and ns.AuctionPrice(item)
    row.price:SetText(scan and Parts.Coins(scan, true) or "")
end

local function ResultClicked(row)
    Buy.Pick(row.itemKey)
    quantity:SetText(1)
    Page.Draw()
end

local function NewResultRow()
    local row = NewListRow(resultsList, RESULT_ICON, ResultClicked)
    row:SetHeight(RESULT_ROW_H)
    row.listed = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.listed:SetPoint("RIGHT", -ROW_IN, 0)
    row.listed:SetWidth(LISTED_W)
    row.listed:SetJustifyH("RIGHT")
    row.lowest = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.lowest:SetPoint("RIGHT", row.listed, "LEFT", -GAP, 0)
    row.lowest:SetWidth(LOWEST_W)
    row.lowest:SetJustifyH("RIGHT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.lowest, "LEFT", -GAP, 0)
    return row
end

local shopping

local function PaintShopRow(row, i)
    local m = shopping[i]
    row.item, row.qty = m.item, m.qty
    row.stripe:SetShown(i % 2 == 0)
    row.picked:SetShown(Buy.picked.itemID == m.item)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(m.item))
    local color = Items.QualityColor(m.item) or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(m.name ~= "" and m.name or Items.Name(m.item))
    row.sub:SetText(TEXT_MORE:format(m.qty))
end

local function PaintResultRow(row, i)
    local result = results[i]
    row.itemKey = result.itemKey
    row.stripe:SetShown(i % 2 == 0)
    row.picked:SetShown(Buy.picked.itemKey == result.itemKey)
    local name, color, icon = KeyLook(result.itemKey)
    row.icon.texture:SetTexture(icon or C_Item.GetItemIconByID(result.itemKey.itemID))
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(name)
    row.lowest:SetText(Coins(result.minPrice))
    row.listed:SetText(BreakUpLargeNumbers(result.totalQuantity))
end

local function DrawShopping()
    shopping = Buy.ShoppingList()
    local count = shopping and #shopping or 0
    Rows(shopList, count, shopRows, NewShopRow, PaintShopRow, SHOP_ROW_H)
    shopNote:SetShown(count == 0)
    shopNote:SetText(shopping and TEXT_SHOP_EMPTY or TEXT_SHOP_OFF)
end

local function DrawFavourites()
    Buy.Favourites(favourites)
    Rows(favList, #favourites, favRows, NewFavRow, PaintFavRow, FAV_ROW_H)
    favNote:SetShown(#favourites == 0)
end

local function DrawResults()
    wipe(results)
    for i, result in ipairs(Buy.results) do results[i] = result end
    Columns.Sort(sorter, results)
    local count = #results
    Rows(resultsList, count, resultRows, NewResultRow, PaintResultRow, RESULT_ROW_H)
    resultsNote:SetShown(count == 0)
    resultsNote:SetText(Buy.searching and TEXT_SEARCHING or TEXT_NO_RESULTS)
end

local function LadderRungs(want)
    local n, left = 0, want
    for i = 1, math.min(Listings.count, Ladder.ROWS) do
        local row = Listings.rows[i]
        local take = math.min(left, row.quantity - row.own)
        n = n + 1
        local rung = Ladder.Rung(rungs, n)
        rung.price, rung.count = row.price, row.quantity
        rung.label = row.own > 0 and TEXT_YOURS or nil
        if take > 0 then
            rung.lit, rung.countText = true, TEXT_TAKE:format(take, row.quantity)
            left = left - take
        end
    end
    return n
end

local function Status(picked, purchase, count)
    local state = purchase.state
    if state == "quoted" then
        return (purchase.over and TEXT_OVER or TEXT_QUOTED):format(Coins(purchase.unit)), purchase.over and St.WARN_RGB
    end
    if state == "bought" then return TEXT_BOUGHT:format(purchase.quantity), St.HAVE_RGB end
    if state == "failed" then return TEXT_FAILED, St.RED_RGB end
    if state == "unavailable" then return TEXT_UNAVAILABLE, St.WARN_RGB end
    if not picked.commodity or Listings.state ~= "listed" then return "" end
    local cost, short = Buy.Cost(count)
    if short > 0 then return TEXT_SHORT:format(count - short), St.WARN_RGB end
    return TEXT_AVERAGE:format(Coins(math.floor(cost / count + 0.5)))
end

local function BuyLabel(picked, purchase, count)
    local state = purchase.state
    if state == "quoting" then return TEXT_QUOTING, false end
    if state == "buying" then return TEXT_BUYING, false end
    if state == "quoted" then return TEXT_CONFIRM:format(Coins(purchase.total)), true end
    if Listings.state ~= "listed" then return TEXT_PICK, false end
    if picked.commodity then
        local cost, short = Buy.Cost(count)
        return TEXT_BUY:format(count, Coins(cost)), short == 0 and cost > 0 and cost <= GetMoney()
    end
    local row = Buy.Cheapest()
    if not row then return TEXT_PICK, false end
    return TEXT_BUY_ONE:format(Coins(row.price)), row.price <= GetMoney()
end

local function DrawDetail()
    local picked, purchase = Buy.picked, Buy.purchase
    detail:SetShown(picked.itemID ~= nil)
    if not picked.itemID then return end
    local name, color = KeyLook(picked.itemKey)
    nameText:SetTextColor(color.r, color.g, color.b)
    nameText:SetText(name)
    local tint = Buy.IsFavourite(picked.itemID) and St.GOLD_RGB or T.muted
    star.icon:SetVertexColor(tint.r, tint.g, tint.b)
    local drawn = spark:Paint(picked.itemID) > 1
    nameText:SetPoint("RIGHT", drawn and spark.label or star, "LEFT", -PANE_GAP, 0)
    local total = 0
    for i = 1, Listings.count do total = total + Listings.rows[i].quantity end
    if Listings.state == "listed" then
        ladder:SetStatus(total > 0 and TEXT_LISTED:format(BreakUpLargeNumbers(total)) or TEXT_NONE)
    else
        ladder:SetStatus(Listings.state == "noanswer" and "" or TEXT_SEARCHING)
    end
    local count = picked.commodity and Quantity() or 1
    ladder:Paint(rungs, LadderRungs(count))
    quantity:SetShown(picked.commodity == true)
    local text, shade = Status(picked, purchase, count)
    shade = shade or T.muted
    statusText:SetTextColor(shade.r, shade.g, shade.b)
    statusText:SetText(text)
    local label, on = BuyLabel(picked, purchase, count)
    ns.SetButtonText(buyButton, label)
    Enable(buyButton, on)
end

function Page.Draw()
    if not active then return end
    DrawShopping()
    for _, row in ipairs(favRows) do
        if row:IsShown() then row.picked:SetShown(Buy.picked.itemID == row.item) end
    end
    DrawResults()
    DrawDetail()
end

local function StarClicked()
    Buy.ToggleFavourite(Buy.picked.itemKey)
    DrawFavourites()
    Page.Draw()
end

local function ItemLoaded(_, _, itemID)
    if Buy.IsFavourite(itemID) then DrawFavourites() end
end

local function ShoppingChanged()
    if active then DrawShopping() end
end

local function BuyClicked()
    if Buy.Purchase(Buy.picked.commodity and Quantity() or 1) then Page.Draw() end
end

local function QuantityTyped(_, userInput)
    if not userInput then return end
    if Buy.purchase.state == "quoted" or Buy.purchase.state == "quoting" then Buy.Reset() end
    Page.Draw()
end

local function SearchEntered(box)
    Buy.Search(box:GetText() or "")
    Page.Draw()
end

local function BuildShopping()
    shopPane = CreateFrame("Frame", nil, page)
    shopPane:SetPoint("TOPLEFT")
    shopPane:SetPoint("BOTTOMLEFT")
    shopPane:SetWidth(SHOP_W)
    Panel(shopPane)
    local title = ns.Font(shopPane, TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    title:SetText(TEXT_SHOP)
    local sub = ns.Font(shopPane, SMALL_SIZE, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    sub:SetText(TEXT_SHOP_SUB)
    favPane = CreateFrame("Frame", nil, shopPane)
    favPane:SetPoint("BOTTOMLEFT")
    favPane:SetPoint("BOTTOMRIGHT")
    favPane:SetHeight(FAV_H)
    local rule = ns.Solid(favPane, "ARTWORK", St.BORDER_RGB, 1)
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    rule:SetHeight(1)
    local favTitle = ns.Font(favPane, TITLE_SIZE, nil, T.fg, true)
    favTitle:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    favTitle:SetText(TEXT_FAVOURITES)
    favScroll = ns.UI.SlimScroll(favPane)
    favScroll:SetPoint("TOPLEFT", 0, -FAV_HEAD_H)
    favScroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    favList = CreateFrame("Frame", nil, favScroll)
    favList:SetWidth(SHOP_W - St.SCROLLBAR - SCROLL_IN)
    favList:SetHeight(1)
    favScroll:SetScrollChild(favList)
    favNote = ns.Font(favPane, SMALL_SIZE, nil, T.muted)
    favNote:SetPoint("TOPLEFT", ROW_IN, -FAV_HEAD_H)
    favNote:SetPoint("RIGHT", -ROW_IN, 0)
    favNote:SetJustifyH("LEFT")
    favNote:SetText(TEXT_FAV_EMPTY)
    shopScroll = ns.UI.SlimScroll(shopPane)
    shopScroll:SetPoint("TOPLEFT", 0, -SHOP_HEAD_H)
    shopScroll:SetPoint("BOTTOMRIGHT", favPane, "TOPRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    shopList = CreateFrame("Frame", nil, shopScroll)
    shopList:SetWidth(SHOP_W - St.SCROLLBAR - SCROLL_IN)
    shopList:SetHeight(1)
    shopScroll:SetScrollChild(shopList)
    shopNote = ns.Font(shopPane, SMALL_SIZE, nil, T.muted)
    shopNote:SetPoint("TOPLEFT", ROW_IN, -SHOP_HEAD_H)
    shopNote:SetPoint("RIGHT", -ROW_IN, 0)
    shopNote:SetJustifyH("LEFT")
end

local function BuildDetail()
    detail = CreateFrame("Frame", nil, main)
    detail:SetPoint("BOTTOMLEFT")
    detail:SetPoint("BOTTOMRIGHT")
    detail:SetHeight(DETAIL_H)
    star = CreateFrame("Button", nil, detail)
    star:SetSize(STAR, STAR)
    star:SetPoint("TOPRIGHT")
    star.icon = star:CreateTexture(nil, "ARTWORK")
    star.icon:SetAllPoints()
    star.icon:SetTexture(St.STAR)
    star:SetScript("OnClick", StarClicked)
    ns.Tooltip(star, TEXT_STAR, TEXT_STAR_TIP)
    spark = Spark.New(detail, SPARK_W, STAR, true)
    spark:SetPoint("RIGHT", star, "LEFT", -PANE_GAP, 0)
    nameText = ns.Font(detail, NAME_SIZE, nil, T.fg, true)
    nameText:SetPoint("TOPLEFT")
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    ladder = Ladder.New(detail, TEXT_LADDER)
    ladder:SetPoint("TOPLEFT", 0, -(NAME_H + SECTION_GAP))
    ladder:SetPoint("RIGHT")
    buyButton = ns.Button(detail, "", BUY_W, BUTTON_H, BuyClicked)
    ns.PrimaryButton(buyButton)
    buyButton:SetPoint("BOTTOMRIGHT")
    quantity = ns.NewEditBox(detail)
    quantity:SetSize(QTY_W, BUTTON_H)
    quantity:SetPoint("BOTTOMLEFT")
    quantity:SetNumeric(true)
    quantity:SetMaxLetters(QTY_LETTERS)
    quantity:SetJustifyH("CENTER")
    quantity:SetText(1)
    quantity:SetScript("OnTextChanged", QuantityTyped)
    quantity:SetScript("OnEnterPressed", quantity.ClearFocus)
    quantity:SetScript("OnEscapePressed", quantity.ClearFocus)
    statusText = ns.Font(detail, TEXT_SIZE, nil, T.muted)
    statusText:SetPoint("LEFT", quantity, "RIGHT", PANE_GAP, 0)
    statusText:SetPoint("RIGHT", buyButton, "LEFT", -PANE_GAP, 0)
    statusText:SetJustifyH("LEFT")
end

local function BuildResults()
    local head = CreateFrame("Frame", nil, main)
    head:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -SECTION_GAP)
    head:SetPoint("RIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    head:SetHeight(SMALL_SIZE)
    sorter = Columns.New(head, Market.Settings, "sortBuy", "lowest", Page.Draw)
    Columns.Add(sorter, { key = "item", text = TEXT_ITEM, left = ROW_IN + RESULT_ICON + ICON_GAP, up = true,
        value = function(result) return ((KeyLook(result.itemKey)) or ""):lower() end })
    Columns.Add(sorter, { key = "lowest", text = TEXT_LOWEST, right = ROW_IN + LISTED_W + GAP, width = LOWEST_W,
        up = true, value = function(result) return result.minPrice end })
    Columns.Add(sorter, { key = "listed", text = TEXT_LISTED_HEAD, right = ROW_IN, width = LISTED_W,
        value = function(result) return result.totalQuantity end })
    resultsScroll = ns.UI.SlimScroll(main)
    resultsScroll:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SUB_GAP)
    resultsScroll:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", -(St.SCROLLBAR + SCROLL_IN), SECTION_GAP)
    resultsList = CreateFrame("Frame", nil, resultsScroll)
    resultsList:SetHeight(1)
    resultsScroll:SetScrollChild(resultsList)
    resultsScroll:HookScript("OnSizeChanged", function(_, width) resultsList:SetWidth(width) end)
    resultsNote = ns.Font(main, TEXT_SIZE, nil, T.muted)
    resultsNote:SetPoint("TOP", resultsScroll, "TOP", 0, -SECTION_GAP)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildShopping()
    main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", SHOP_W + PANE_GAP, 0)
    main:SetPoint("BOTTOMRIGHT")
    search = Parts.SearchBox(main, TEXT_SEARCH)
    search:SetHeight(SEARCH_H)
    search:SetPoint("TOPLEFT")
    search:SetPoint("TOPRIGHT")
    search:HookScript("OnEnterPressed", SearchEntered)
    BuildDetail()
    BuildResults()
end

function Page.PickItem(itemID, qty)
    Buy.PickItem(itemID, qty)
    quantity:SetText(qty)
    Page.Draw()
end

function Page.Show()
    page:Show()
    resultsList:SetWidth(resultsScroll:GetWidth())
    if not active then
        active = true
        Buy.onChange = Page.Draw
        Buy.Open()
        Listings.Start()
        Listings.onChange = Page.Draw
        if not itemEvents then
            itemEvents = CreateFrame("Frame")
            itemEvents:SetScript("OnEvent", ItemLoaded)
        end
        itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        if not watching then watching = Buy.WatchShopping(ShoppingChanged) end
        DrawFavourites()
    end
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    if not active then return end
    active = false
    itemEvents:UnregisterAllEvents()
    Buy.Close()
    Listings.Stop()
end
