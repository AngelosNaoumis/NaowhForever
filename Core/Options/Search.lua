-- Search.lua: the search box at the top of the options window's sidebar.
local ns = _G.NaowhForever
local UI = ns.UI

local TEXT_SEARCH_HINT = ns.L("Search settings")
local INDEX_ADDON = "NaowhForever_SearchIndex"
local NONE = {}
local NOT_LETTERS, LETTER, WORD = "[^%w\128-\255]+", "[%w\128-\255]", "()([%w\128-\255]+)"
local FUZZY_MIN, FUZZY_SHARE, MAX_CAPTURES = 3, 0.5, 32
local PLURALS, STEM_MIN = { "^(.-)s$", "^(.-)es$" }, 3
local CARD_UID = "^(.-):[^:]+$"
local CARD_PARTS = "^(.-):([^:]+)$"
local TEXT_RESULT_GROUP = "%s / %s"
local TEXT_RESULT_OWNER = "%s (%s)"
local RESULTS = { width = 390, rows = 7, rowH = 46, pad = 12, gap = 6, footer = 26,
    titleSize = 13, trailSize = 11, titleY = 8, trailY = 26, fillAlpha = 0.12, raise = 20 }
local TEXT_RESULTS = ns.L("%d-%d of %d results")
local TEXT_NO_RESULTS = ns.L("No matching settings.")
local TEXT_RESULT_PATH = "%s / %s"

local carries = {}
local spreads = {}

local function Words(text)
    return " " .. ns.Lower(text):gsub(NOT_LETTERS, " ") .. " "
end

local function Both(text)
    if not text or text == "" then return "" end
    local shown = ns.L(text)
    return shown == text and text or (text .. " " .. shown)
end

local function Typed(query)
    local typed = {}
    for word in Words(query):gmatch("%S+") do typed[#typed + 1] = word end
    return typed
end

local function Place(page, cardName)
    local parts = {}
    local cat = page.category
    if cat then parts[#parts + 1] = ns.L(page.name) end
    if cardName then parts[#parts + 1] = ns.L(cardName) end
    return ns.L(cat and cat.name or page.title or page.name), table.concat(parts, " / ")
end

local function Entry(page, card, label, help, cardName, group, scope, owner)
    local t, where = Place(page, cardName)
    return { page = page.key, card = card, label = label, tag = t, trail = where, group = group, owner = owner,
        isCard = cardName == nil, scope = scope, name = Words(Both(label or cardName)),
        words = Words(table.concat({ Both(label), Both(help), Both(group), Both(cardName) }, " ")) }
end

local function IndexInto(list, page, scope, Settings, settingsKey)
    Settings.Index(settingsKey, function(card, label, help, cardName, group)
        list[#list + 1] = Entry(page, card, label, help, cardName, group, scope, card and card:match(CARD_UID))
    end)
end

local function AddTerms(list, page, tag, scope)
    local terms = page.terms and ns[page.terms]
    if not terms then return end
    terms(function(label, help, section, off)
        list[#list + 1] = { page = page.key, label = label, tag = tag, trail = section, scope = scope, off = off,
            name = Words(Both(label)), words = Words(table.concat({ Both(label), Both(help), Both(section) }, " ")) }
    end)
end

local function ModuleNames(page)
    local names = {}
    for i, mod in ipairs(page.modules or NONE) do names[i] = Both(mod.label or mod.name) .. " " .. mod.name end
    return table.concat(names, " ")
end

local function PageTarget(list, page)
    local tag, trail = Place(page)
    local words = Words(tag .. " " .. trail .. " " .. ModuleNames(page))
    list[#list + 1] = { page = page.key, tag = tag, trail = trail, name = words, words = words }
    return tag, words
end

local function IndexOff(list, mod, pageKey, id)
    local O = ns.Options
    local card, name = O.ModuleCardUid(mod), O.DisplayName(mod)
    for _, e in ipairs(ns.SEARCH_INDEX and ns.SEARCH_INDEX[pageKey] or NONE) do
        local page = (not id or e[1] == id) and O.PAGES[O.NavPage(pageKey .. ":" .. e[1])]
        if page then
            local tag, trail = Place(page)
            local scope = Words(tag .. " " .. trail .. " " .. name)
            list[#list + 1] = Entry(page, card, e[2] or e[4], e[3], e[2] and e[4] or nil, e[5], scope, pageKey)
        end
    end
end

local function Key(...)
    local parts = { ... }
    for i = 1, select("#", ...) do parts[i] = tostring(parts[i] or "") end
    return table.concat(parts, "\n")
end

local function Shown(t)
    return Key(ns.L(t.label or t.tag), t.tag, t.trail)
end

local function OwnerName(t, others)
    local page = ns.Options.PAGES[t.owner]
    if not page then return nil end
    local mod = page.module
    for _, other in ipairs(others) do
        local them = ns.Options.PAGES[other.owner]
        if them and them.module == mod then return ns.L(page.name) end
    end
    return mod and ns.Options.DisplayName(mod) or ns.L(page.name)
end

local function Tidy(list)
    local kept, seen, groups = {}, {}, {}
    for _, t in ipairs(list) do
        local key = Key(t.page, t.card, t.label, t.group, t.trail)
        if not seen[key] then
            seen[key] = true
            kept[#kept + 1] = t
            if t.label and t.group then
                local row = Key(t.page, t.card, t.label, t.trail)
                groups[row] = (groups[row] or 0) + 1
            end
        end
    end
    local carded = {}
    for _, t in ipairs(kept) do
        if t.label and t.group and groups[Key(t.page, t.card, t.label, t.trail)] > 1 then
            t.trail, t.inGroup = TEXT_RESULT_GROUP:format(t.trail, ns.L(t.group)), t.group
        end
        if t.card then carded[Key(t.page, Shown(t))] = true end
    end
    local out, clashes = {}, {}
    for _, t in ipairs(kept) do
        if t.card or not carded[Key(t.page, Shown(t))] then
            out[#out + 1] = t
            local shown = Shown(t)
            clashes[shown] = clashes[shown] or {}
            table.insert(clashes[shown], t)
        end
    end
    for _, same in pairs(clashes) do
        if #same > 1 then
            for _, t in ipairs(same) do
                local others = {}
                for _, other in ipairs(same) do
                    if other ~= t and other.owner ~= t.owner then others[#others + 1] = other end
                end
                local name = others[1] and OwnerName(t, others)
                if name then t.trail = TEXT_RESULT_OWNER:format(t.trail, name) end
            end
        end
    end
    return out
end

local function Collect()
    local list = {}
    local Settings = ns.Shared and ns.Shared.Settings
    for _, page in ipairs(UI.SearchPages()) do
        local tag, pageWords = PageTarget(list, page)
        AddTerms(list, page, tag, pageWords)
        if Settings then
            IndexInto(list, page, pageWords, Settings, page.key)
            for _, settingsKey in ipairs(carries[page.key] or NONE) do
                IndexInto(list, page, pageWords, Settings, settingsKey)
            end
        end
    end
    local off, offCards = UI.SearchOffPages(), UI.SearchOffCards()
    if (off[1] or offCards[1]) and not ns.SEARCH_INDEX then C_AddOns.LoadAddOn(INDEX_ADDON) end
    for _, tab in ipairs(off) do IndexOff(list, tab.module, tab.key) end
    for _, lent in ipairs(offCards) do
        local pageKey, id = lent.uid:match(CARD_PARTS)
        IndexOff(list, lent.module, pageKey, id)
    end
    return Tidy(list)
end

local function Spread(word)
    local pattern = spreads[word]
    if not pattern then
        pattern = "^" .. word:gsub(".", "()%0.-")
        spreads[word] = pattern
    end
    return pattern
end

local function Close(word, w)
    return #word >= FUZZY_MIN and #word <= MAX_CAPTURES and #word >= #w * FUZZY_SHARE
        and w:find(Spread(word)) ~= nil
end

local function NameWords(target)
    local words = {}
    for _, w in target.name:gmatch(WORD) do words[#words + 1] = w end
    target.nameWords = words
    return words
end

local function Fuzzy(word, target)
    local best
    for _, w in ipairs(target.nameWords or NameWords(target)) do
        if Close(word, w) and (not best or #word / #w > best) then best = #word / #w end
    end
    return best
end

local function Has(text, word, stemmed)
    if not text then return false end
    if not stemmed then return text:find(" " .. word, 1, true) ~= nil end
    for _, plural in ipairs(PLURALS) do
        local stem = word:match(plural)
        if stem and #stem >= STEM_MIN and text:find(" " .. stem, 1, true) then return true end
    end
    return false
end

local function Own(target, word)
    if Has(target.words, word) then return true end
    if Has(target.scope, word) then return false end
    if Has(target.words, word, true) then return true end
    if Has(target.scope, word, true) then return false end
end

local function Matched(target, typed)
    local own, fuzzy, score, named = false, 0, 0, true
    for _, word in ipairs(typed) do
        local mine = Own(target, word)
        if mine then
            own = true
            named = named and (Has(target.name, word) or Has(target.name, word, true))
        elseif mine == false then
            named = false
        else
            local s = Fuzzy(word, target)
            if not s then return false end
            own, fuzzy, score = true, fuzzy + 1, score + s
        end
    end
    return own, fuzzy, score, named and (#typed == #(target.nameWords or NameWords(target)) and 2 or 1) or 0
end

local function Better(a, b)
    if a.named ~= b.named then return a.named > b.named end
    if a.fuzzy ~= b.fuzzy then return a.fuzzy < b.fuzzy end
    if a.score ~= b.score then return a.score > b.score end
    return a.at < b.at
end

local function Matches(list, typed)
    local out = {}
    if #typed == 0 then return out end
    for i, target in ipairs(list) do
        local own, fuzzy, score, named = Matched(target, typed)
        if own then
            target.fuzzy, target.score, target.at, target.named = fuzzy, score, i, named
            out[#out + 1] = target
        end
    end
    table.sort(out, Better)
    return out
end

local function Find(list, query)
    return Matches(list, Typed(query))
end

local function AddMatch(f, t)
    local key = t.page
    if not f.count[key] then
        f.count[key] = 0
        f.order[#f.order + 1] = key
    end
    if not t.card then
        f.all[key] = true
        if t.label then f.count[key] = f.count[key] + 1 end
        if t.off then f.off[#f.off + 1] = t.off end
        return
    end
    f.count[key] = f.count[key] + 1
    f.first[key] = f.first[key] or t.card
    if t.isCard then
        f.cards[t.card] = true
    elseif f.cards[t.card] ~= true then
        local labels = f.cards[t.card] or {}
        labels[t.label] = true
        f.cards[t.card] = labels
    end
end

local function Build(list, query)
    local typed = Typed(query)
    if #typed == 0 then return nil end
    local f = { typed = typed, count = {}, all = {}, cards = {}, order = {}, first = {}, off = {} }
    for _, t in ipairs(Matches(list, typed)) do AddMatch(f, t) end
    return f
end

local function StartsWord(lower, s)
    return s == 1 or not lower:sub(s - 1, s - 1):find(LETTER)
end

local function LitClose(lower, word, lit)
    for at, w in lower:gmatch(WORD) do
        if Close(word, w) then
            lit = lit or {}
            for _, p in ipairs({ w:match(Spread(word)) }) do lit[at + p - 1] = true end
        end
    end
    return lit
end

local function LitWord(lower, word, lit)
    local from, found = 1, false
    while true do
        local s, e = lower:find(word, from, true)
        if not s then break end
        if StartsWord(lower, s) then
            lit, found = lit or {}, true
            for i = s, e do lit[i] = true end
        end
        from = s + 1
    end
    return lit, found
end

local function LitLetters(filter, lower)
    local lit, found
    for _, word in ipairs(filter.typed) do
        lit, found = LitWord(lower, word, lit)
        for _, plural in ipairs(PLURALS) do
            local stem = not found and word:match(plural)
            if stem and #stem >= STEM_MIN then lit, found = LitWord(lower, stem, lit) end
        end
        if not found then lit = LitClose(lower, word, lit) end
    end
    return lit
end

local function Paint(text, lit)
    local out, i = {}, 1
    while i <= #text do
        local on, j = lit[i] == true, i
        while j < #text and (lit[j + 1] == true) == on do j = j + 1 end
        local piece = text:sub(i, j)
        out[#out + 1] = on and ns.Color("accent", piece) or piece
        i = j + 1
    end
    return table.concat(out)
end

local function Mark(filter, text)
    if not (filter and text) then return text end
    local lit = LitLetters(filter, ns.Lower(text))
    if not lit then return text end
    return Paint(text, lit)
end

local function Narrowing(filter, pageKey)
    if filter and not filter.all[pageKey] and (filter.count[pageKey] or 0) > 0 then return filter end
    return nil
end

local function Narrowed(pageKey)
    return Narrowing(UI.filter, pageKey)
end

local function CarriedChanged(before, after)
    for pageKey in pairs(carries) do
        if Narrowing(before, pageKey) or Narrowing(after, pageKey) then return true end
    end
    return false
end

UI.Search = { Collect = Collect, Find = Find, Build = Build, Mark = Mark, Narrowed = Narrowed }

function UI.SearchCarries(pageKey, settingsKey)
    local keys = carries[pageKey] or {}
    keys[#keys + 1] = settingsKey
    carries[pageKey] = keys
end

local box, list, onFilter
local results, matches
local resultOffset, selectedResult = 0, 1

local function PickResult(button)
    local entry = button.entry
    if not entry then return end
    results:Hide()
    UI.GoToSetting(entry.page, entry.label, entry.card, entry.inGroup)
end

local function ResultEnter(button)
    for _, row in ipairs(results.rows) do row.fill:SetShown(row == button) end
    selectedResult = button.index
end

local function PaintResults()
    local count = #matches
    local shown = math.min(RESULTS.rows, count)
    results:SetHeight(shown * RESULTS.rowH + RESULTS.footer)
    for i, row in ipairs(results.rows) do
        local index = resultOffset + i
        local entry = matches[index]
        row.entry, row.index = entry, index
        row:SetShown(i <= shown and entry ~= nil)
        if entry then
            row.title:SetText(Mark(UI.filter, ns.L(entry.label or entry.tag)))
            local trail = entry.trail and entry.trail ~= "" and TEXT_RESULT_PATH:format(entry.tag, entry.trail) or entry.tag
            row.trail:SetText(trail)
            row.fill:SetShown(index == selectedResult)
        end
    end
    results.footer:SetText(count > 0 and ns.L(TEXT_RESULTS, resultOffset + 1, resultOffset + shown, count)
        or TEXT_NO_RESULTS)
end

local function MoveResults(delta)
    if not (results and results:IsShown() and matches and #matches > 0) then return end
    selectedResult = math.max(1, math.min(#matches, selectedResult + delta))
    if selectedResult <= resultOffset then resultOffset = selectedResult - 1 end
    if selectedResult > resultOffset + RESULTS.rows then resultOffset = selectedResult - RESULTS.rows end
    PaintResults()
end

local function NewResults()
    if results then return end
    local T = ns.THEME
    results = CreateFrame("Frame", nil, box)
    results:SetWidth(RESULTS.width)
    results:SetPoint("TOPLEFT", box, "TOPRIGHT", RESULTS.gap, 0)
    results:SetFrameLevel(box:GetFrameLevel() + RESULTS.raise)
    results:SetClampedToScreen(true)
    ns.Solid(results, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(results, T.line)
    results.rows = {}
    results:EnableMouseWheel(true)
    results:SetScript("OnMouseWheel", function(_, delta) MoveResults(-delta) end)
    for i = 1, RESULTS.rows do
        local row = CreateFrame("Button", nil, results)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * RESULTS.rowH)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * RESULTS.rowH)
        row:SetHeight(RESULTS.rowH)
        row.fill = ns.Solid(row, "BACKGROUND", T.accent, RESULTS.fillAlpha)
        row.fill:SetAllPoints()
        row.title = ns.Font(row, RESULTS.titleSize, nil, T.fg)
        row.title:SetPoint("TOPLEFT", RESULTS.pad, -RESULTS.titleY)
        row.title:SetPoint("TOPRIGHT", -RESULTS.pad, -RESULTS.titleY)
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.trail = ns.Font(row, RESULTS.trailSize, nil, T.muted)
        row.trail:SetPoint("TOPLEFT", RESULTS.pad, -RESULTS.trailY)
        row.trail:SetPoint("TOPRIGHT", -RESULTS.pad, -RESULTS.trailY)
        row.trail:SetJustifyH("LEFT")
        row.trail:SetWordWrap(false)
        row:SetScript("OnClick", PickResult)
        row:SetScript("OnEnter", ResultEnter)
        results.rows[i] = row
    end
    results.footer = ns.Font(results, RESULTS.trailSize, nil, T.muted)
    results.footer:SetPoint("BOTTOMLEFT", RESULTS.pad, RESULTS.gap)
    results:Hide()
end

local function ShowResults(text)
    if not text:find("%S") then
        if results then results:Hide() end
        matches = nil
        return
    end
    NewResults()
    matches = Find(list, text)
    resultOffset, selectedResult = 0, 1
    PaintResults()
    results:Show()
end

local function SearchKey(_, key)
    if key == "UP" then MoveResults(-1) elseif key == "DOWN" then MoveResults(1) end
end

local function SearchEnter()
    if not (results and results:IsShown()) then return end
    local button = results.rows[selectedResult - resultOffset]
    if button then PickResult(button) end
end

local function HideResults()
    if results then results:Hide() end
end

local function OnText(text)
    local before = UI.filter
    if text:find("%S") then
        list = list or Collect()
        UI.filter = Build(list, text)
    else
        list, UI.filter = nil, nil
    end
    onFilter()
    if CarriedChanged(before, UI.filter) then UI:RefreshPage(true) end
    ShowResults(text)
end

function UI.FocusSearch()
    box:SetFocus()
    box:HighlightText()
end

function UI.SearchTyped()
    return box:GetText() ~= ""
end

function UI.ClearSearch()
    if box:GetText() ~= "" then box:SetText("") end
    box:ClearFocus()
end

function UI.AttachSearchBox(parent, onChange, columns)
    onFilter = onChange
    box = ns.Shared.Parts.SearchBox(parent, TEXT_SEARCH_HINT, OnText, columns)
    box:SetScript("OnArrowPressed", SearchKey)
    box:SetScript("OnEnterPressed", SearchEnter)
    box:HookScript("OnEscapePressed", HideResults)
    box:HookScript("OnHide", HideResults)
    box:HookScript("OnEditFocusLost", function()
        if not (results and results:IsMouseOver()) then HideResults() end
    end)
    box:HookScript("OnEditFocusGained", function()
        if list then ShowResults(box:GetText()) end
    end)
    UI:RegisterOnHide(UI.ClearSearch)
    return box
end
