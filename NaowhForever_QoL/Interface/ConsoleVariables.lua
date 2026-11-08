-- ConsoleVariables.lua: the Console Variables window (ns.OpenConsoleVariables): every console variable with its value and default, to change, export and import.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St, View = Shared.Parts, Shared.Style, Shared.View
local S = ns.QoLSettings

local GetCVarInfo, SetCVar = C_CVar.GetCVarInfo, C_CVar.SetCVar

local PAGE = "QoL/Interface"
local SWITCH = "consoleVariables"
local CARD_ORDER = 75
local WIDTH, HEIGHT = 640, 600
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local SEARCH_H, TAB_H, BAR_GAP, INSET = St.SEARCH_H, St.TAB_H, St.BAR_GAP, St.CONTENT_INSET
local TEXT_SIZE, SMALL_SIZE, HOVER, GAP, ACTION = St.TEXT_SIZE, St.SMALL_SIZE, St.HOVER, St.GAP, St.ACTION
local CARD_INSET = 6
local SEARCH_DROP = 4
local SCROLL_GAP = 4
local VIEW_SPARE = 8
local VIEW_W = WIDTH - INSET - SCROLLBAR - PAD - VIEW_SPARE
local TABS_W = 160
local HEAD_H = 20
local ROW_H = 20
local SUMMARY_H = 16
local VALUE_W = 150
local DEFAULT_RIGHT = ACTION + GAP
local VALUE_RIGHT = DEFAULT_RIGHT + VALUE_W + GAP
local SHOWN_MAX = 150
local LISTED_MAX = 8
local SHOWN_VALUE = 24
local ANY_LENGTH = 0
local SHARE = "!NFCV1!"
local SHARE_PATTERN = "^%s*" .. SHARE .. "(%S+)%s*$"
local VERSION = 1
local MAX_CVARS = 1000
local MAX_NAME, MAX_VALUE = 64, 255
local SHARE_FIELDS = 2
local LIMITS = { maxChars = 200000, maxBytes = 524288, maxDepth = 1, maxValues = MAX_CVARS + SHARE_FIELDS }
local UNSAFE = "[%c|]"
local ONE_WORD = "^%S+$"
local CVAR = Enum.ConsoleCommandType.Cvar
local NOT_SHARED = {
    lastcharacterindex = true, plunderstormrealm = true, portal = true,
    locale = true, textlocale = true, audiolocale = true,
    gxmonitor = true, gxadapter = true, gxapi = true,
    gxwindowedresolution = true, gxfullscreenresolution = true, gxnewresolution = true,
    sound_outputdrivername = true, sound_outputdriverindex = true,
    sound_voicechatoutputdrivername = true, sound_voicechatoutputdriverindex = true,
    sound_voicechatinputdrivername = true, sound_voicechatinputdriverindex = true,
}
local CHANGED, ALL = "changed", "all"
local EVENTS = { "CVAR_UPDATE" }
local TABS = {
    { key = CHANGED, label = "Changed", tip = "The ones you changed from their default." },
    { key = ALL, label = "All", tip = "Every one you can change." },
}

local TEXT_TITLE = ns.L("Console Variables")
local TEXT_SUBTITLE = ns.L("The game's settings by their console names. Click one to change it.")
local TEXT_SEARCH = ns.L("Search")
local TEXT_NAME, TEXT_VALUE, TEXT_DEFAULT = ns.L("Name"), ns.L("Value"), ns.L("Default")
local TEXT_IMPORT, TEXT_IMPORT_TIP = ns.L("Import"), ns.L("Paste a Console Variables string to set them all at once.")
local TEXT_EXPORT, TEXT_EXPORT_TIP = ns.L("Export"), ns.L("The list as it is shown, as a string to share.")
local TEXT_RESET = ns.L("Reset to Default")
local TEXT_CLICK = ns.L("Click to change it.")
local TEXT_SET = ns.L("Set %s")
local TEXT_RESET_ASK = ns.L("Set %s back to its default, %s?")
local TEXT_REFUSED = ns.L("The game did not take that value for %s.")
local TEXT_COMBAT = ns.L("Game settings can only be changed out of combat.")
local TEXT_COUNT_ONE, TEXT_COUNT = ns.L("%d console variable"), ns.L("%d console variables")
local TEXT_FIRST_OF = ns.L("The first %d of %d; type more to narrow it down.")
local TEXT_NONE_CHANGED = ns.L("You have not changed any console variable from its default.")
local TEXT_NO_MATCH = ns.L("No console variable matches your search.")
local TEXT_PASTE = ns.L("Paste a Console Variables string")
local TEXT_NOT_A_STRING = ns.L("That isn't a Console Variables string.")
local TEXT_NOTHING_NEW = ns.L("Nothing in that string changes anything here.")
local TEXT_CHANGE_ONE, TEXT_CHANGE = ns.L("Change %d console variable?"), ns.L("Change %d console variables?")
local TEXT_LINE = ns.L("%s: %s to %s")
local TEXT_MORE = ns.L("And %d more")
local TEXT_AND_MORE = ns.L(" and %d more")
local TEXT_LEFT_ONE = ns.L("%d is left out: not one an import can change.")
local TEXT_LEFT = ns.L("%d are left out: not ones an import can change.")
local TEXT_CHANGED_ONE, TEXT_CHANGED = ns.L("Changed %d console variable."), ns.L("Changed %d console variables.")
local TEXT_CHANGED_SOME = ns.L("Changed %d of %d console variables; the game refused %s.")
local TEXT_NOTHING_TO_EXPORT = ns.L("Nothing in the list to export.")
local TEXT_TOO_MANY = ns.L("The list has %d; search until it has %d or fewer to export it.")
local TEXT_EXPORT_TITLE = ns.L("Console Variables (%d)")
local TEXT_BLANK = "\"\""
local TEXT_CUT = "..."

local window, view, tabs, summary
local names, lowered, about, byLower
local values, defaults = {}, {}
local filter, shownTab = "", CHANGED

local function ByName(a, b)
    return lowered[a] < lowered[b]
end

local function Index()
    if names then return end
    names, lowered, about, byLower = {}, {}, {}, {}
    for _, info in ipairs(ConsoleGetAllCommands()) do
        local name = info.command
        if info.commandType == CVAR and not about[name] then
            names[#names + 1] = name
            lowered[name] = name:lower()
            about[name] = info.help
            byLower[lowered[name]] = name
        end
    end
    table.sort(names, ByName)
end

local function Same(a, b)
    if a == b then return true end
    local x = tonumber(a)
    return x ~= nil and x == tonumber(b)
end

local function Usable(name)
    local value, default, _, _, locked, secure, readOnly = GetCVarInfo(name)
    if value == nil or locked or secure or readOnly then return nil end
    return value, default
end

local function Cache(name)
    values[name], defaults[name] = Usable(name)
end

local function CacheAll()
    Index()
    for _, name in ipairs(names) do Cache(name) end
end

local function Listed(name)
    local value, default = values[name], defaults[name]
    if value == nil or (filter ~= "" and not lowered[name]:find(filter, 1, true)) then return nil end
    if shownTab == CHANGED and Same(value, default) then return nil end
    return value, default
end

local function Private(name)
    return NOT_SHARED[name:lower()] == true
end

local function Shown(value)
    if value == "" then return TEXT_BLANK end
    if #value > SHOWN_VALUE then return value:sub(1, SHOWN_VALUE) .. TEXT_CUT end
    return value
end

local function Fits(text, max)
    return type(text) == "string" and #text <= max and not text:find(UNSAFE)
end

local function Shareable(name, value)
    return Fits(name, MAX_NAME) and name:find(ONE_WORD) ~= nil and Fits(value, MAX_VALUE)
end

local function Names(list)
    local shown = math.min(#list, LISTED_MAX)
    local text = table.concat(list, ", ", 1, shown)
    if #list > shown then text = text .. TEXT_AND_MORE:format(#list - shown) end
    return text
end

local function Set(name, value)
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    if not SetCVar(name, value) then ns.Print(TEXT_REFUSED:format(name)) end
    Cache(name)
    view:QueueRedraw()
end

local function Edit(row)
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    local name = row.cvar
    ns.PromptText(TEXT_SET:format(name), (GetCVarInfo(name)), MAX_VALUE, function(value) Set(name, value) end)
end

local function ResetClicked(button)
    local row = button:GetParent()
    local name, default = row.cvar, row.default
    ns.Confirm(TEXT_RESET_ASK:format(name, Shown(default)), function() Set(name, default) end)
end

local function RowEnter(row)
    row.hover:Show()
    local help = about[row.cvar]
    Parts.TipLines(row, "ANCHOR_RIGHT", row.cvar, help ~= "" and help .. "|n" .. TEXT_CLICK or TEXT_CLICK)
end

local function RowLeave(row)
    if row:IsMouseOver() then return end
    row.hover:Hide()
    GameTooltip:Hide()
end

local function PartLeave(part)
    RowLeave(part:GetParent())
end

local function Column(row, right, color)
    local text = ns.Font(row, TEXT_SIZE, nil, color)
    text:SetPoint("RIGHT", -right, 0)
    text:SetWidth(VALUE_W)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.reset = Parts.IconButton(row, ResetClicked, St.RESET, 0, TEXT_RESET)
    row.reset:SetPoint("RIGHT")
    row.reset:HookScript("OnLeave", PartLeave)
    row.defaultText = Column(row, DEFAULT_RIGHT, T.muted)
    row.valueText = Column(row, VALUE_RIGHT, T.fg)
    row.nameText = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.nameText:SetPoint("LEFT")
    row.nameText:SetPoint("RIGHT", row.valueText, "LEFT", -GAP, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row:SetScript("OnClick", Edit)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function SetRow(row, name, value, default)
    row.cvar, row.default = name, default
    row.hover:Hide()
    row.nameText:SetText(name)
    row.valueText:SetText(value == "" and TEXT_BLANK or value)
    row.defaultText:SetText(default == "" and TEXT_BLANK or default)
    local changed = not Same(value, default)
    local color = changed and T.accent or T.fg
    row.valueText:SetTextColor(color.r, color.g, color.b)
    row.reset:SetShown(changed)
    return ROW_H
end

local Draw = {}

function Draw:OnEvent(_, name)
    local known = type(name) == "string" and byLower[name:lower()]
    if not known then return end
    Cache(known)
    self:QueueRedraw()
end

function Draw:Redraw()
    self:Clear()
    local matched = 0
    for _, name in ipairs(names) do
        local value, default = Listed(name)
        if value then
            matched = matched + 1
            if matched <= SHOWN_MAX then self:Add("cvar", name, value, default) end
        end
    end
    if matched == 0 then self:Note((filter == "" and shownTab == CHANGED) and TEXT_NONE_CHANGED or TEXT_NO_MATCH) end
    if matched > SHOWN_MAX then
        summary:SetText(TEXT_FIRST_OF:format(SHOWN_MAX, matched))
    else
        summary:SetText((matched == 1 and TEXT_COUNT_ONE or TEXT_COUNT):format(matched))
    end
    self:Fit(EVENTS)
end

local function Read(text)
    local body = type(text) == "string" and text:match(SHARE_PATTERN)
    local data = body and Shared.Decode.String(body, LIMITS)
    if type(data) ~= "table" or data.v ~= VERSION or type(data.cvars) ~= "table" then return nil end
    for name, value in pairs(data.cvars) do
        if not Shareable(name, value) then return nil end
    end
    return data.cvars
end

local function Plan(cvars)
    Index()
    local changes, left = {}, 0
    for name, value in pairs(cvars) do
        local current = about[name] and not Private(name) and Usable(name) or nil
        if current == nil then
            left = left + 1
        elseif not Same(current, value) then
            changes[#changes + 1] = name
        end
    end
    table.sort(changes, ByName)
    return changes, left
end

local function Question(cvars, changes, left)
    local lines = { (#changes == 1 and TEXT_CHANGE_ONE or TEXT_CHANGE):format(#changes) }
    for i = 1, math.min(#changes, LISTED_MAX) do
        local name = changes[i]
        lines[#lines + 1] = TEXT_LINE:format(name, Shown((GetCVarInfo(name))), ns.Color("accent", Shown(cvars[name])))
    end
    if #changes > LISTED_MAX then lines[#lines + 1] = TEXT_MORE:format(#changes - LISTED_MAX) end
    if left > 0 then lines[#lines + 1] = (left == 1 and TEXT_LEFT_ONE or TEXT_LEFT):format(left) end
    return table.concat(lines, "|n")
end

local function Apply(cvars, changes)
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    local refused = {}
    for _, name in ipairs(changes) do
        if not SetCVar(name, cvars[name]) then refused[#refused + 1] = name end
        Cache(name)
    end
    local done = #changes - #refused
    if #refused == 0 then
        ns.Print((done == 1 and TEXT_CHANGED_ONE or TEXT_CHANGED):format(done))
    else
        ns.Print(TEXT_CHANGED_SOME:format(done, #changes, Names(refused)))
    end
    if view then view:QueueRedraw() end
end

function ns.ImportConsoleVariables(text)
    local cvars = Read(text)
    if not cvars then return ns.Print(TEXT_NOT_A_STRING) end
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    local changes, left = Plan(cvars)
    if #changes == 0 then return ns.Print(TEXT_NOTHING_NEW) end
    ns.Confirm(Question(cvars, changes, left), function() Apply(cvars, changes) end)
end

local function ImportPrompt()
    ns.PromptText(TEXT_PASTE, "", ANY_LENGTH, ns.ImportConsoleVariables)
end

local function Export()
    local cvars, count = {}, 0
    for _, name in ipairs(names) do
        local value = Listed(name)
        if value and Shareable(name, value) and not Private(name) then
            cvars[name] = value
            count = count + 1
        end
    end
    if count == 0 then return ns.Print(TEXT_NOTHING_TO_EXPORT) end
    if count > MAX_CVARS then return ns.Print(TEXT_TOO_MANY:format(count, MAX_CVARS)) end
    ns.ShowCopyBox(TEXT_EXPORT_TITLE:format(count), Shared.Encode.String(SHARE, { v = VERSION, cvars = cvars }))
end

local function OnTab(key)
    shownTab = key
    Parts.PaintTabs(tabs, key)
    view:Redraw()
end

local function OnSearch(text)
    filter = (text or ""):lower()
    if view then view:Redraw() end
end

local function OnSettingChanged(key)
    if key == SWITCH and not S.Get(SWITCH) then window:Hide() end
end

local function HeadLabel(head, text)
    local label = ns.Font(head, SMALL_SIZE, nil, T.muted)
    label:SetText(text)
    return label
end

local function BuildHead(top)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT", INSET, -top)
    head:SetSize(VIEW_W, HEAD_H)
    HeadLabel(head, TEXT_NAME):SetPoint("LEFT")
    HeadLabel(head, TEXT_VALUE):SetPoint("LEFT", head, "RIGHT", -(VALUE_RIGHT + VALUE_W), 0)
    HeadLabel(head, TEXT_DEFAULT):SetPoint("LEFT", head, "RIGHT", -(DEFAULT_RIGHT + VALUE_W), 0)
end

local function BuildBar()
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    local import = Parts.BarButton(window, St.IMPORT, TEXT_IMPORT, TEXT_IMPORT_TIP, ImportPrompt)
    import:SetPoint("RIGHT", close, "LEFT", -BAR_GAP * 2, 0)
    local export = Parts.BarButton(window, St.EXPORT, TEXT_EXPORT, TEXT_EXPORT_TIP, Export)
    export:SetPoint("RIGHT", import, "LEFT", -BAR_GAP, 0)
    Parts.FooterBrand(window, PAGE)
end

local function BuildList(top)
    summary = ns.Font(window, SMALL_SIZE, nil, T.muted)
    summary:SetPoint("BOTTOMLEFT", INSET, FOOTER + PAD)
    summary:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    summary:SetJustifyH("LEFT")
    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(top + HEAD_H))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + SUMMARY_H)
    local kinds = View.NewKinds()
    kinds.cvar = { New = NewRow, Set = SetRow }
    view = View.New(scroll, kinds, Draw)
    view:SetWidth(VIEW_W)
    scroll:SetScrollChild(view)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "consoleVariablesWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    BuildBar()
    local top = HEADER + PAD + SEARCH_DROP
    tabs = Parts.Tabs(window, TABS_W, TABS, OnTab)
    tabs:SetPoint("TOPLEFT", INSET, -top)
    Parts.PaintTabs(tabs, shownTab)
    local search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetPoint("TOPLEFT", INSET + TABS_W + GAP, -top)
    search:SetPoint("TOPRIGHT", -INSET, -top)
    search:SetHeight(SEARCH_H)
    top = top + TAB_H + PAD
    BuildHead(top)
    BuildList(top)
    hooksecurefunc(S, "Set", OnSettingChanged)
end

function ns.OpenConsoleVariables()
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    CacheAll()
    view:Redraw()
end

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "consoleVariables", name = "Console Variables", order = CARD_ORDER, switch = SWITCH,
    help = "Every console variable the game has, to change, export and import.",
    rows = {
        { label = "Console Variables Window", button = function() ns.OpenFromOptions(ns.OpenConsoleVariables) end,
          buttonText = "Open",
          help = "Search them and see each one's value beside its default.",
          search = "cvar cvars console" },
    },
})
