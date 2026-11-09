-- Window.lua: Discovery's own window (/nfdiscovery): the Library Books, Sleeping Bag, Field Journal, Quest List and Rares tabs.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local Library = Discovery.Library
local Bag = Discovery.Bag
local Field = Discovery.Field
local Style = Discovery.Style
local V = Discovery.View
local Shared = ns.Shared
local Parts = Shared.Parts

local WIDTH, HEIGHT = 760, 720
local CARD = 6
local TAB_MARGIN = 28
local SEARCH_W = 260
local SEARCH_MIN_W = 140
local SEARCH_GAP = 12
local TABS_TOP_GAP = 4
local SCROLL_TOP_GAP = 8
local SCROLL_GAP = 4
local PAGE = "Discovery/Library Books"
local EVENTS = { "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "PLAYERBANKSLOTS_CHANGED" }
local FILTERS = {
    { key = "books", label = "Library Books", tip = "Every book for your faction, a tick on those handed in." },
    { key = "bag", label = "Sleeping Bag", tip = "The Cozy Sleeping Bag's hidden quest chain, step by step." },
    { key = "journal", label = "Field Journal", tip = "The fish you have caught, the herbs you have picked and the dishes you have cooked." },
    { key = "quests", label = "Quest List", tip = "Every quest of every zone, and where you are in each chain." },
    { key = "rares", label = "Rares", tip = "Every rare of every zone, and which of them you have killed." },
}
local QUEST_TABS = { quests = true, rares = true }
local PAGES = {
    { key = "fish", label = "Fish", tip = "Every fish you can catch, and where." },
    { key = "herbs", label = "Herbs", tip = "Every herb you can pick, and where it grows." },
    { key = "dishes", label = "Cooking", tip = "Every dish you can cook, and where to learn it." },
}
local RANKS = { "Apprentice", "Journeyman", "Expert", "Artisan" }
local NO_EVENTS = {}
local TEXT_TITLE = ns.L("Discovery")
local TEXT_ABOUT = ns.L("Library books, the Sleeping Bag, a field journal, quests and rares to find around Azeroth.")
local TEXT_STEPS = ns.L("Steps")
local TEXT_OPTIONAL = ns.L("Optional")
local TEXT_NOT_FOUND = ns.L("Not found yet")
local TEXT_NOBODY = ns.L("Nobody has found this one on Forever yet.")
local TEXT_NO_BOOKS = ns.L("No books for your faction yet.")
local TEXT_SEPARATOR = "  -  "
local TEXT_FOR_FACTION = ns.L(" books for your faction")
local TEXT_SCHOOLS = "Schools of fish"
local TEXT_KEPT = ns.L("Kept for this character.")

local window, scroll, view, questScroll
local filter = "books"
local page = "fish"
local zones
local zoneBooks = {}
local rankCounts = {}

local Draw = {}

local function ZoneOrder()
    local order, seen = {}, {}
    for _, book in ipairs(ns.LibraryBooks) do
        for _, spot in ipairs(book.spots) do
            if not seen[spot[C.SPOT_MAP]] then
                seen[spot[C.SPOT_MAP]] = true
                order[#order + 1] = spot[C.SPOT_MAP]
            end
        end
    end
    return order
end

local function StepState(i, at)
    if not at or i < at then return "done" end
    if i == at then return "now" end
    return "later"
end

local function DrawBag(self)
    self:Add("bagHero")
    self:Space(Style.SECTION_GAP)
    local steps = Bag.Steps()
    local _, at = Bag.Current()
    self:Section(TEXT_STEPS, #steps)
    for i, step in ipairs(steps) do self:Add("step", step, i, StepState(i, at), i % 2 == 0) end
    local side = ns.SleepingBag.optional
    self:Section(TEXT_OPTIONAL)
    local sideDone = C_QuestLog.IsQuestFlaggedCompleted(side.done)
    self:Add("step", side, "", sideDone and "done" or "optional", false)
    self:Fit(EVENTS)
end

local function GatherZone(mapID)
    wipe(zoneBooks)
    for _, book in ipairs(ns.LibraryBooks) do
        if Library.ForMe(book) then
            for _, spot in ipairs(book.spots) do
                if spot[C.SPOT_MAP] == mapID then
                    zoneBooks[#zoneBooks + 1] = book
                    zoneBooks[#zoneBooks + 1] = spot
                end
            end
        end
    end
    return #zoneBooks / 2
end

local function DrawZone(self, mapID)
    local n = GatherZone(mapID)
    if n == 0 then return 0 end
    self:Section(Library.ZoneName(mapID), n)
    for j = 1, n do
        local book, spot = zoneBooks[j * 2 - 1], zoneBooks[j * 2]
        local sub = Library.Where(spot) .. TEXT_SEPARATOR .. Library.TurnIn(book).name
        self:Add("book", book, spot, sub, j % 2 == 0)
    end
    return n
end

local function DrawUnplaced(self)
    local unplaced = 0
    for _, book in ipairs(ns.LibraryBooks) do
        if book.unplaced and Library.ForMe(book) then
            unplaced = unplaced + 1
            if unplaced == 1 then self:Section(TEXT_NOT_FOUND) end
            self:Add("book", book, nil, TEXT_NOBODY, unplaced % 2 == 0)
        end
    end
    return unplaced
end

local function DrawBooks(self)
    self:Add("hero")
    self:Space(Style.SECTION_GAP)
    local shown = 0
    for i = 1, #zones do shown = shown + DrawZone(self, zones[i]) end
    if shown + DrawUnplaced(self) == 0 then self:Note(TEXT_NO_BOOKS) end
    self:Fit(EVENTS)
end

local function CountRanks(entries)
    wipe(rankCounts)
    for _, entry in ipairs(entries) do
        local rank = Field.Rank(entry.skill) or 0
        rankCounts[rank] = (rankCounts[rank] or 0) + 1
    end
end

local function DrawJournal(self)
    self:Add("fieldHero", page)
    self:Space(Style.SECTION_GAP)
    local entries = Field.Entries(page)
    CountRanks(entries)
    local rank, n
    for _, entry in ipairs(entries) do
        local r = Field.Rank(entry.skill) or 0
        if r ~= rank then
            rank, n = r, 0
            self:Section(RANKS[r] or TEXT_SCHOOLS, rankCounts[r])
        end
        n = n + 1
        self:Add("field", page, entry, n % 2 == 0)
    end
    self:Fit(NO_EVENTS)
end

function Draw:Redraw()
    zones = zones or ZoneOrder()
    self:Clear()
    if filter == "bag" then return DrawBag(self) end
    if filter == "journal" then return DrawJournal(self) end
    DrawBooks(self)
end

local function PaintNote()
    local text = TEXT_KEPT
    if filter ~= "journal" then
        local _, total = Library.Progress()
        text = total .. TEXT_FOR_FACTION
    end
    window.note.text:SetText(text)
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
end

local function ShowFilter(opening)
    local quests = QUEST_TABS[filter]
    scroll:SetShown(not quests)
    window.pages:SetShown(filter == "journal")
    if quests then
        ns.Completo.Tabs.Show(filter, opening)
    else
        ns.Completo.Tabs.Hide()
        PaintNote()
        view:Redraw()
    end
end

local function PickFilter(key)
    filter = key
    Parts.PaintTabs(window.filters, filter)
    scroll:SetVerticalScroll(0)
    ShowFilter(false)
end

local function PickPage(key)
    page = key
    Parts.PaintTabs(window.pages, page)
    scroll:SetVerticalScroll(0)
    view:Redraw()
end

local function PlaceScroll(frame, left, top, footer)
    frame:SetPoint("TOPLEFT", left, -top)
    frame:SetPoint("BOTTOMRIGHT", -(CARD + Style.SCROLLBAR + SCROLL_GAP), footer + CARD + Style.WINDOW_PAD)
end

local function Build()
    local header, footer = Style.WINDOW_HEADER, Style.WINDOW_FOOTER
    window = Parts.Window(WIDTH, HEIGHT, "discoveryWindow")
    window.backdrop:Card(CARD, header + CARD, CARD, footer + CARD)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    Parts.FooterBrand(window, PAGE)
    window.note = Parts.FooterNote(window, "")
    local left, top = CARD + Style.CONTENT_INSET, header + CARD + Style.WINDOW_PAD + TABS_TOP_GAP
    window.filters = Parts.Tabs(window, 1, FILTERS, PickFilter)
    Parts.FitTabs(window.filters, FILTERS, TAB_MARGIN, WIDTH - 2 * left - SEARCH_MIN_W - SEARCH_GAP)
    window.filters:SetPoint("TOPLEFT", left, -top)
    local width = WIDTH - left - CARD - Style.SCROLLBAR - Style.CONTENT_INSET
    questScroll = ns.UI.SlimScroll(window)
    local search = ns.Completo.Tabs.Build(window, questScroll, width)
    local room = WIDTH - 2 * left - window.filters:GetWidth() - SEARCH_GAP
    search:SetSize(math.max(SEARCH_MIN_W, math.min(SEARCH_W, room)), Style.SEARCH_H)
    search:SetPoint("RIGHT", window, "TOPRIGHT", -left, -(top + Style.TAB_H / 2))
    window.pages = Parts.Tabs(window, 1, PAGES, PickPage)
    Parts.FitTabs(window.pages, PAGES, TAB_MARGIN, search:GetWidth())
    window.pages:SetPoint("RIGHT", search, "RIGHT")
    top = top + Style.TAB_H + Style.TAB_GAP + SCROLL_TOP_GAP
    scroll = ns.UI.SlimScroll(window)
    PlaceScroll(scroll, left, top, footer)
    PlaceScroll(questScroll, left, top, footer)
    view = Shared.View.New(scroll, V.Kinds, Draw)
    view:SetWidth(width)
    scroll:SetScrollChild(view)
end

local function Paint()
    window.backdrop:Paint(1)
    Parts.PaintTabs(window.filters, filter)
    Parts.PaintTabs(window.pages, page)
    if QUEST_TABS[filter] then return end
    PaintNote()
end

local function IsShown()
    return window ~= nil and window:IsShown()
end

local function OnApply()
    if not IsShown() or QUEST_TABS[filter] then return end
    Paint()
    view:Redraw()
end

local function OnFieldChanged(changed)
    if IsShown() and filter == "journal" and (changed == nil or changed == page) then view:QueueRedraw() end
end

function ns.OpenDiscoveryWindow(tab)
    if tab then filter = tab end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    Paint()
    ShowFilter(true)
end

function ns.ToggleDiscoveryWindow(tab)
    if IsShown() and (not tab or tab == filter) then window:Hide() else ns.OpenDiscoveryWindow(tab) end
end

Field.OnChange(OnFieldChanged)
hooksecurefunc(ns, "Apply", OnApply)
