-- Searches.lua: the Buy page's Searches view: a list of your saved searches, or the last ones you ran, each run with a click (Market.SearchView).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Searches = Market.Searches

local PICK_W, GAP, NOTE_GAP, NOTE_H, SCROLL_IN = 220, 6, 8, 28, 4
local ROW_H, ROW_IN, LINE_IN, ACT_W = 36, 8, 4, 22
local RECENT = 0
local GOLD = 10000
local ANY_LENGTH, PRICE_LETTERS = 0, 12
local QUALITY_NAME = "ITEM_QUALITY%d_DESC"
local QUALITY_JOIN, PART_JOIN = "/", ", "
local DECIMAL_COMMA, DECIMAL_POINT = ",", "."
local TEXT_LIST_COUNT = "%s (%d)"
local TEXT_SAVE_GLYPH, TEXT_DELETE_GLYPH = "+", "x"
local TEXT_RECENT = ns.L("Recent")
local TEXT_SAVE = ns.L("Save Search")
local TEXT_SAVE_TIP = ns.L("Keeps the search in the auction house window on a list.")
local TEXT_PICK_TIP = ns.L("Pick a list, or make, rename, delete and share one.")
local TEXT_NEW_LIST = ns.L("New List")
local TEXT_RENAME_LIST = ns.L("Rename List")
local TEXT_DELETE_LIST = ns.L("Delete List")
local TEXT_IMPORT = ns.L("Import List")
local TEXT_EXPORT = ns.L("Export List")
local TEXT_NAME_LIST = ns.L("Name the list")
local TEXT_DELETE_ASK = ns.L("Delete the list %s and its %d searches?")
local TEXT_PASTE = ns.L("Paste a search list")
local TEXT_EXPORT_TITLE = ns.L("Search list: %s")
local TEXT_NOT_A_LIST = ns.L("That is not a search list.")
local TEXT_LISTS_FULL = ns.L("You have %d search lists, the most there can be.")
local TEXT_LIST_FULL = ns.L("That list is full: %d searches.")
local TEXT_HAVE = ns.L("That search is already on the list.")
local TEXT_SAVED = ns.L("Saved to %s.")
local TEXT_NOTHING_TYPED = ns.L("Type a search or pick a category in the auction house first.")
local TEXT_HINT = ns.L("Click a search to run it. Right-click it for more.")
local TEXT_EMPTY = ns.L("Nothing saved here yet. Search the auction house, then press Save Search.")
local TEXT_RECENT_HINT = ns.L("Your last searches. Click one to run it again.")
local TEXT_RECENT_EMPTY = ns.L("Search the auction house and it shows here.")
local TEXT_SAVE_TO = ns.L("Save to a List")
local TEXT_DELETE = ns.L("Delete")
local TEXT_RENAME = ns.L("Rename")
local TEXT_EXACT = ns.L("Exact Name")
local TEXT_MAX_PRICE = ns.L("Max Price")
local TEXT_UP, TEXT_DOWN = ns.L("Move Up"), ns.L("Move Down")
local TEXT_SEARCH_FOR = ns.L("Search for")
local TEXT_PRICE_ASK = ns.L("Max price for %s, in gold (0 for none)")
local TEXT_NOT_A_PRICE = ns.L("That is not a price.")
local TEXT_ANY_NAME = ns.L("Any name")
local TEXT_NO_FILTERS = ns.L("No filters")
local TEXT_LEVELS = ns.L("Level %d to %d")
local TEXT_LEVEL_FROM = ns.L("Level %d and up")
local TEXT_LEVEL_TO = ns.L("Up to level %d")
local TEXT_UP_TO = ns.L("Up to %s")

local view, pick, save, note, scroll, list
local rows, parts, qualities = {}, {}, {}
local shown = RECENT
local saving

local View = {}
Market.SearchView = View

local function Entries()
    local picked = Searches.Lists()[shown]
    if picked then return picked.searches end
    shown = RECENT
    return Searches.Recent()
end

local function Name(search)
    return search.text ~= "" and search.text or TEXT_ANY_NAME
end

local function Levels(search)
    if search.min and search.max then return TEXT_LEVELS:format(search.min, search.max) end
    if search.min then return TEXT_LEVEL_FROM:format(search.min) end
    return search.max and TEXT_LEVEL_TO:format(search.max)
end

local function Summary(search)
    wipe(parts)
    if search.exact then parts[#parts + 1] = TEXT_EXACT end
    parts[#parts + 1] = Searches.CategoryName(search)
    parts[#parts + 1] = Levels(search)
    if search.quality then
        wipe(qualities)
        for i, quality in ipairs(search.quality) do qualities[i] = _G[QUALITY_NAME:format(quality)] end
        parts[#parts + 1] = table.concat(qualities, QUALITY_JOIN)
    end
    if search.price then parts[#parts + 1] = TEXT_UP_TO:format(Parts.Coins(search.price)) end
    return #parts > 0 and table.concat(parts, PART_JOIN) or TEXT_NO_FILTERS
end

local function Show(index)
    shown = index
    scroll:SetVerticalScroll(0)
    View.Draw()
end

local function IsShown(index) return shown == index end

local function AddTo(index, search)
    local ok, why = Searches.Add(index, search)
    if ok then return ns.Print(TEXT_SAVED:format(Searches.Lists()[index].name)) end
    ns.Print(why == "full" and TEXT_LIST_FULL:format(Searches.MAX_SEARCHES) or TEXT_HAVE)
end

local function MakeList(name)
    local index = Searches.NewList(name)
    if not index then return ns.Print(TEXT_LISTS_FULL:format(Searches.MAX_LISTS)) end
    if saving then AddTo(index, saving) end
    saving = nil
    Show(index)
end

local function NewList()
    ns.PromptText(TEXT_NAME_LIST, "", Searches.MAX_NAME, MakeList)
end

local function NewPlainList()
    saving = nil
    NewList()
end

local function RenameList()
    local index = shown
    ns.PromptText(TEXT_NAME_LIST, Searches.Lists()[index].name, Searches.MAX_NAME,
        function(name) Searches.RenameList(index, name) end)
end

local function DeleteList()
    local index = shown
    local picked = Searches.Lists()[index]
    ns.Confirm(TEXT_DELETE_ASK:format(picked.name, #picked.searches), function()
        shown = RECENT
        Searches.DeleteList(index)
    end)
end

local function Imported(text)
    local index, why = Searches.Import(text)
    if index then return Show(index) end
    ns.Print(why == "full" and TEXT_LISTS_FULL:format(Searches.MAX_LISTS) or TEXT_NOT_A_LIST)
end

local function Import()
    ns.PromptText(TEXT_PASTE, "", ANY_LENGTH, Imported)
end

local function Export()
    ns.ShowCopyBox(TEXT_EXPORT_TITLE:format(Searches.Lists()[shown].name), Searches.Export(shown))
end

local function ListMenu(_, root)
    root:CreateRadio(TEXT_RECENT, IsShown, Show, RECENT)
    for i, entry in ipairs(Searches.Lists()) do
        root:CreateRadio(TEXT_LIST_COUNT:format(entry.name, #entry.searches), IsShown, Show, i)
    end
    local onList = shown ~= RECENT
    root:CreateDivider()
    root:CreateButton(TEXT_NEW_LIST, NewPlainList)
    root:CreateButton(TEXT_RENAME_LIST, RenameList):SetEnabled(onList)
    root:CreateButton(TEXT_DELETE_LIST, DeleteList):SetEnabled(onList)
    root:CreateDivider()
    root:CreateButton(TEXT_IMPORT, Import)
    root:CreateButton(TEXT_EXPORT, Export):SetEnabled(onList)
end

local function OpenLists()
    ns.ContextMenu(pick, ListMenu)
end

local function SaveToList(index)
    AddTo(index, saving)
end

local function SaveMenu(_, root)
    for i, entry in ipairs(Searches.Lists()) do root:CreateButton(entry.name, SaveToList, i) end
    root:CreateButton(TEXT_NEW_LIST, NewList)
end

local function SaveTo(owner, search)
    saving = search
    ns.ContextMenu(owner, SaveMenu)
end

local function SaveClicked()
    local search = Searches.Current()
    if not search then return ns.Print(TEXT_NOTHING_TYPED) end
    if shown ~= RECENT then return AddTo(shown, search) end
    SaveTo(save, search)
end

local function Rename(at)
    local index = shown
    ns.PromptText(TEXT_SEARCH_FOR, Entries()[at].text, Searches.MAX_TEXT,
        function(text) Searches.Change(index, at, "text", text) end)
end

local function IsExact(at)
    return Entries()[at].exact == true
end

local function ToggleExact(at)
    Searches.Change(shown, at, "exact", not IsExact(at) or nil)
end

local function AskPrice(at)
    local index = shown
    local search = Entries()[at]
    ns.PromptText(TEXT_PRICE_ASK:format(Name(search)), tostring((search.price or 0) / GOLD), PRICE_LETTERS,
        function(text)
            local gold = tonumber((text:gsub(DECIMAL_COMMA, DECIMAL_POINT)))
            local copper = gold and math.floor(gold * GOLD + 0.5)
            if not copper or copper < 0 or copper > Searches.MAX_PRICE then return ns.Print(TEXT_NOT_A_PRICE) end
            Searches.Change(index, at, "price", copper > 0 and copper or nil)
        end)
end

local function MoveUp(at) Searches.Move(shown, at, -1) end

local function MoveDown(at) Searches.Move(shown, at, 1) end

local function Remove(at) Searches.Remove(shown, at) end

local function RowMenu(row, root)
    local at = row.index
    root:CreateButton(TEXT_RENAME, Rename, at)
    root:CreateCheckbox(TEXT_EXACT, IsExact, ToggleExact, at)
    root:CreateButton(TEXT_MAX_PRICE, AskPrice, at)
    root:CreateDivider()
    root:CreateButton(TEXT_UP, MoveUp, at):SetEnabled(at > 1)
    root:CreateButton(TEXT_DOWN, MoveDown, at):SetEnabled(at < #Entries())
    root:CreateDivider()
    root:CreateButton(TEXT_DELETE, Remove, at)
end

local function RowClicked(row, button)
    if button ~= "RightButton" then return Searches.Run(row.search) end
    if shown ~= RECENT then ns.ContextMenu(row, RowMenu) end
end

local function ActClicked(row)
    if shown == RECENT then return SaveTo(row.act, row.search) end
    Remove(row.index)
end

local function RowEnter(row) row.hover:Show() end

local function RowLeave(row) row.hover:Hide() end

local function NewRow()
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Parts.RowBands(row, 0)
    row.act = ns.Button(row, "", ACT_W, ACT_W, function() ActClicked(row) end)
    row.act:SetPoint("RIGHT", -ROW_IN, 0)
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("TOPLEFT", ROW_IN, -LINE_IN)
    row.name:SetPoint("RIGHT", row.act, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.line = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.line:SetPoint("BOTTOMLEFT", ROW_IN, LINE_IN)
    row.line:SetPoint("RIGHT", row.act, "LEFT", -GAP, 0)
    row.line:SetJustifyH("LEFT")
    row.line:SetWordWrap(false)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function PaintRow(row, search, index, recent)
    row.search, row.index = search, index
    row.stripe:SetShown(index % 2 == 0)
    local name, summary = Name(search), Summary(search)
    row.name:SetText(name)
    row.line:SetText(summary)
    ns.SetButtonText(row.act, recent and TEXT_SAVE_GLYPH or TEXT_DELETE_GLYPH)
    ns.Tooltip(row.act, recent and TEXT_SAVE_TO or TEXT_DELETE)
    ns.Tooltip(row, name, summary)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", list, "RIGHT")
    row:Show()
end

local function OnChanged()
    if view:IsVisible() then View.Draw() end
end

function View.Draw()
    local entries = Entries()
    local recent = shown == RECENT
    ns.SetButtonText(pick, recent and TEXT_RECENT or Searches.Lists()[shown].name)
    if recent then
        note:SetText(#entries > 0 and TEXT_RECENT_HINT or TEXT_RECENT_EMPTY)
    else
        note:SetText(#entries > 0 and TEXT_HINT or TEXT_EMPTY)
    end
    for i, search in ipairs(entries) do
        local row = rows[i] or NewRow()
        rows[i] = row
        PaintRow(row, search, i, recent)
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, #entries * ROW_H))
end

function View.Build(parent, width)
    view = CreateFrame("Frame", nil, parent)
    pick = ns.Button(view, TEXT_RECENT, PICK_W, St.SEARCH_H, OpenLists)
    pick:SetPoint("TOPLEFT")
    ns.Tooltip(pick, TEXT_PICK_TIP)
    save = ns.PrimaryButton(ns.Button(view, TEXT_SAVE, width - PICK_W - GAP, St.SEARCH_H, SaveClicked))
    save:SetPoint("LEFT", pick, "RIGHT", GAP, 0)
    ns.Tooltip(save, TEXT_SAVE_TIP)
    note = ns.Font(view, St.SMALL_SIZE, nil, T.muted)
    note:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -NOTE_GAP)
    note:SetSize(width, NOTE_H)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    local pane = CreateFrame("Frame", nil, view)
    pane:SetPoint("TOPLEFT", note, "BOTTOMLEFT")
    pane:SetPoint("BOTTOMRIGHT")
    ns.Solid(pane, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(pane, St.BORDER_RGB)
    scroll = ns.UI.SlimScroll(pane)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetSize(width - St.SCROLLBAR - SCROLL_IN, 1)
    scroll:SetScrollChild(list)
    if #Searches.Lists() > 0 then shown = 1 end
    Searches.onChange = OnChanged
    return view
end
