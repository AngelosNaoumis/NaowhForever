-- Window.lua: the options window, a module's own window, and the lifecycle half of ns.UI.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local O = ns.Options

local SYSTEM_PAGES, MODULES, PAGES, CATEGORIES = O.SYSTEM_PAGES, O.MODULES, O.PAGES, O.CATEGORIES
local DisplayName, Loaded, ModuleOn, SetModuleOn = O.DisplayName, O.Loaded, O.ModuleOn, O.SetModuleOn

local MEDIA = ns.MEDIA
local LINK_ICONS = MEDIA .. "Links\\"
local NAV_ICONS = MEDIA .. "Navigation\\"
local BRAND_LOGO = MEDIA .. "BrandLogo.tga"
local NAV_DOT_TEXTURE = MEDIA .. "circle_mask.tga"
local SIDEBAR_W, CONTENT_W, WINDOW_W, WINDOW_H = 240, 1000, 1440, 852
local MIN_WINDOW_H = 620
local TOP_H, PAGE_HEADER_H = 64, 128
local HEADER_H, TAB_H, NAV_H = 76, 32, 32
local TAB_TUCK = 12
local NAV_INSET, NAV_GUTTER, NAV_ICON_X, NAV_ICON_SIZE, NAV_LABEL_X = 8, 12, 14, 20, 42
local SEARCH = { h = 26, top = 10, gap = 4, left = NAV_INSET, right = NAV_INSET + NAV_GUTTER,
    columns = { icon = NAV_ICON_X + NAV_ICON_SIZE / 2, text = NAV_LABEL_X } }
local SCROLL_BAR_GAP = 12
local NAV_STEP = 30
local NAV_DOT = 6
local NAV_COUNT_SIZE = 12
local NAV_ROW, NAV_OFF_ALPHA = 28, 0.45
local MISS_ALPHA = 0.3
local NAV_BUTTON_EXTRA, NAV_FILL_ALPHA, NAV_MARKER_W = 6, 0.16, 3
local NAV_TEXT_SIZE, NAV_TEXT_X, NAV_TEXT_RIGHT, NAV_COUNT_RIGHT = 14, 18, 10, 14
local FOOTER_H_SIDEBAR = 28
local BRAND = { artW = 448, artH = 139, texW = 512, texH = 256, height = 56, inset = 8 }
local CONTENT_X, CONTENT_RIGHT = 26, 30
local SCROLL_X, SCROLL_Y, SCROLL_BOTTOM, CHILD_ROOM = 6, 8, 14, 36
local TAB_MARGIN = 28
local PAGE_TOP, PAGE_ROOM = 6, 30
local SETTING_AT = 1 / 3
local SCREEN_MARGIN, MIN_FIT = 32, 0.25
local DEFAULT_SCALE = 100
local NAV_BAR = { w = 10, inset = 1 }
local SOON = { titleSize = 16, textSize = 12, top = 60, gap = 12, inset = 60, height = 180 }
local HEAD = { flashSeconds = 1.5, flashAlpha = 0.12, crumbSize = 12, crumbY = 24, titleSize = 24, titleY = 51, titleRoom = 300, subSize = 12, subY = 94,
    tabDrop = 14 }
local SIDE = { groupSize = 11, groupX = 20, groupY = 10, groupStep = 28, utilityRow = 28, utilityTop = 4,
    utilityRoom = 6, versionSize = 10, versionX = 20, versionY = 10, linksRight = 14, linksY = 8, linkSize = 16,
    linkGap = 10 }
local TOP = { gap = 18, close = 28, hudW = 140, reloadW = 110, buttonH = 32 }
local MW = { titleSize = 20, titleX = 30, titleY = 18, subSize = 12, subX = 1, subGap = 6, close = 26,
    closeInset = 12, switchGap = 14, tabX = 30, tabDrop = 2, tabRoom = 60, scrollX = 10, scrollY = 5,
    scrollRight = 30, scrollBottom = 22, childRoom = 40, h = 560, minH = 360, switchRaise = 2 }
local OPTIONS_NAME = "NaowhForeverOptions"
local FIRST_PAGE = O.HOME
local LINKS = {
    { "Discord", "discord", function() return "https://discord.gg/V2eSJMBynn" end },
    { "Website", "website", function() return "https://naowh.gg" end },
    { "GitHub", "github", function() return "https://github.com/naowh-gaming/NaowhForever" end },
}
local SYSTEM_NAV = { { "Settings", "settings" }, { UI.PROFILES_PAGE, "person" }, { "Patch Notes", "notes" }, { "Credits", "heart" } }
local TEXT_VERSION, TEXT_UNKNOWN = "v", ns.L("unknown")
local TEXT_COMING_SOON = ns.L("Coming soon")
local TEXT_BRAND = "Naowh Forever"
local TEXT_CLOSE = "X"
local TEXT_HUD_EDITOR = ns.L("HUD Editor")
local TEXT_HUD_HELP = ns.L("Place and size each display. Exit Config returns to this window.")
local TEXT_RELOAD = ns.L("Reload UI")
local TEXT_BACK = ns.L("Back to Settings")
local TEXT_ON = ns.L("On. Click to turn the whole module off.")
local TEXT_OFF = ns.L("Off. Click to turn it back on.")
local TEXT_SWITCHED_OFF = ns.L("%s is switched off. Turn it on under Settings > Modules.")
local TEXT_NO_MATCH = ns.L("Nothing on this page matches the search.")

ns.LINKS, ns.LINK_ICONS = LINKS, LINK_ICONS

local window, scrollFrame, scrollChild, tabLine, headerTitle, headerSub
local contentHeader, searchBox, breadcrumb
local lastPages = {}
local navButtons, tabStrips = {}, {}
local wrappers = {}
local currentPage = FIRST_PAGE
local pendingRefresh
local onHideCallbacks = {}
local moduleWindows = {}
local refreshQueued, builtLoaded
local lastFilter, searchJump
local NO_TABS = {}
local Forever = { insetLeft = 3, insetRight = 4, insetBottom = 6, tabTop = 8, titleY = 8, crumbGap = 4,
    subGap = 12, headRoom = 560, edge = 16, buttonGap = 10, buttonH = 26, navText = 15,
    itemX = 24, groupGap = 6, groupBelow = 2, railOut = 6, rodRaise = 5 }

function ns.VersionText()
    return TEXT_VERSION .. (ns.CODE_BUILD or C_AddOns.GetAddOnMetadata(ns.MODULE_KEY, "Version") or TEXT_UNKNOWN)
end

function UI:RegisterOnHide(fn) onHideCallbacks[#onHideCallbacks + 1] = fn end

local function SoonPage(parent, text)
    local head, body = parent.soonHead, parent.soonBody
    if not head then
        head = ns.Font(parent, SOON.titleSize, "OUTLINE", T.muted)
        head:SetPoint("TOP", parent, "TOP", 0, -SOON.top)
        body = ns.Font(parent, SOON.textSize, nil, T.muted)
        body:SetPoint("TOP", head, "BOTTOM", 0, -SOON.gap)
        body:SetPoint("LEFT", parent, "LEFT", SOON.inset, 0)
        body:SetPoint("RIGHT", parent, "RIGHT", -SOON.inset, 0)
        body:SetJustifyH("CENTER")
        body:SetWordWrap(true)
        parent.soonHead, parent.soonBody = head, body
    end
    head:SetText(ns.L(TEXT_COMING_SOON))
    body:SetText(text)
    return -SOON.height
end

local function BuildPageInto(page, parent, filter)
    if page.soon then return SoonPage(parent, page.soon) end
    local Settings = ns.Shared and ns.Shared.Settings
    if Settings then O.Compose(page) end
    if Settings and Settings.pages[page.key] then
        return -Settings.Render(parent, page.key, function(height)
            parent:SetHeight(height + PAGE_ROOM)
            local child = parent:GetParent()
            if child and parent:IsShown() then child:SetHeight(parent:GetHeight()) end
        end, filter)
    end
    local fn = ns[page.build]
    if not fn then return -PAGE_TOP end
    local y = -PAGE_TOP
    if filter and not filter.count[page.key] then
        local _, h = UI.Widgets:Note(parent, TEXT_NO_MATCH, y)
        y = y - h
    end
    return fn(parent, y, page.arg)
end

local function ActiveNav()
    local page = PAGES[currentPage]
    return page.category and page.category.name or page.key
end

local function PaintTabs(bar, shown, filter)
    ns.Shared.Parts.PaintTabs(bar, shown)
    for _, button in ipairs(bar.buttons) do
        local page = PAGES[button.key]
        local alpha = 1
        if page and page.soon then
            alpha = NAV_OFF_ALPHA
        elseif filter and not filter.count[button.key] then
            alpha = MISS_ALPHA
        end
        button.text:SetAlpha(alpha)
    end
end

local function PaintNavButton(btn, hover)
    local active = btn.marker:IsShown()
    local found = UI.filter and btn.found
    local c = active and not ns.foreverSkin and T.accentSoft
        or (active or hover) and T.fg or (ns.foreverSkin and T.accent or T.muted)
    local a = (found == false and not active and not hover) and MISS_ALPHA or 1
    btn.label:SetTextColor(c.r, c.g, c.b, a)
    if btn.icon then btn.icon:SetVertexColor(c.r, c.g, c.b, a) end
    if btn.forever then ns.Shared.Parts.PaintForeverNav(btn, active, hover) end
    btn.count:SetText(found and found > 0 and found or "")
end

local function Found(filter, name, btn)
    local n = filter.count[name]
    for _, page in ipairs(btn.cat and btn.cat.tabs or NO_TABS) do
        local c = filter.count[page.key]
        if c then n = (n or 0) + c end
    end
    return n or false
end

local function PaintNav()
    local nav = ActiveNav()
    local filter = UI.filter
    for name, btn in pairs(navButtons) do
        local active = name == nav
        btn.fill:SetShown(active and ns.foreverSkin == true)
        btn.marker:SetShown(active)
        btn.found = nil
        if filter then btn.found = Found(filter, name, btn) end
        PaintNavButton(btn, btn:IsMouseOver())
    end
    for _, bar in pairs(tabStrips) do PaintTabs(bar, currentPage, filter) end
end

local function LayoutHeader(page, headerH)
    local cat = page.category
    headerTitle:SetText(ns.L(cat and cat.name or page.title))
    breadcrumb:SetText(cat and (ns.L(cat.name) .. " / " .. ns.L(page.name)) or TEXT_BRAND)
    headerSub:SetText(ns.L(cat and cat.subtitle or page.subtitle))
    if headerH then
        contentHeader:ClearAllPoints()
        contentHeader:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR_W, -TOP_H)
        contentHeader:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -TOP_H)
        contentHeader:SetHeight(headerH)
    end
end

local function LayoutContent()
    local page = PAGES[currentPage]
    local cat = page.category
    if window.forever then return Forever.Layout(page, cat) end
    local left, top = SIDEBAR_W, TOP_H
    local headerH = PAGE_HEADER_H + (cat and TAB_H - TAB_TUCK or 0)
    LayoutHeader(page, headerH)
    for name, strip in pairs(tabStrips) do strip:SetShown(cat ~= nil and name == cat.name) end
    tabLine:ClearAllPoints()
    tabLine:SetPoint("TOPLEFT", window, "TOPLEFT", left + CONTENT_X, -(top + headerH))
    tabLine:SetPoint("TOPRIGHT", window, "TOPRIGHT", -CONTENT_RIGHT, -(top + headerH))
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", window, "TOPLEFT", left + SCROLL_X, -(top + headerH + SCROLL_Y))
    scrollFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -CONTENT_RIGHT, SCROLL_BOTTOM)
    scrollChild:SetWidth(window:GetWidth() - left - CHILD_ROOM)
end

local function NewWrapper(child)
    local wrapper = CreateFrame("Frame", nil, child)
    wrapper:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    wrapper:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    wrapper:SetHeight(1)
    wrapper._dirty = true
    return wrapper
end

local function BuildWrapper(wrapper, child, key, filter)
    wrapper._builtWidth = child:GetWidth()
    wrapper._dirty = nil
    wrapper._nsuiCollapsed = nil
    if PAGES[key].reuse then UI.BeginReusableRows(wrapper) end
    local usedY = BuildPageInto(PAGES[key], wrapper, filter)
    wrapper:SetHeight(math.abs(usedY) + PAGE_ROOM)
end

local function ShowWrapper(pageWrappers, child, key, filter)
    for name, w in pairs(pageWrappers) do
        w:SetShown(name == key)
    end
    if not pageWrappers[key] then pageWrappers[key] = NewWrapper(child) end
    local wrapper = pageWrappers[key]
    if wrapper._builtWidth ~= child:GetWidth() then wrapper._dirty = true end
    if wrapper._dirty then BuildWrapper(wrapper, child, key, filter) end
    child:SetHeight(wrapper:GetHeight())
end

local function ShowPage(key)
    currentPage = key
    if PAGES[key].category then lastPages[PAGES[key].category.name] = key end
    LayoutContent()
    ShowWrapper(wrappers, scrollChild, key, UI.filter)
    scrollFrame:UpdateScrollChildRect()
    scrollFrame:SetVerticalScroll(0)
    PaintNav()
end

function UI.SearchPages()
    local pages = {}
    for _, page in ipairs(SYSTEM_PAGES) do pages[#pages + 1] = page end
    for _, cat in ipairs(CATEGORIES) do
        for _, page in ipairs(cat.pages) do
            O.Compose(page)
            pages[#pages + 1] = page
        end
    end
    return pages
end

function UI.SearchOffPages()
    local pages = {}
    for _, mod in ipairs(MODULES) do
        for _, tab in ipairs(mod.tabs) do
            if not tab.soon and not Loaded(mod) then pages[#pages + 1] = tab end
        end
    end
    return pages
end

function UI.HighlightSetting(row)
    if not row then return end
    if not row.settingHighlight then
        row.settingHighlight = ns.Solid(row, "BACKGROUND", T.accent, HEAD.flashAlpha)
        row.settingHighlight:SetAllPoints()
        row:HookScript("OnHide", function() row.settingHighlight:Hide() end)
    end
    row.settingHighlight:Show()
    row.settingHighlightGeneration = (row.settingHighlightGeneration or 0) + 1
    local generation = row.settingHighlightGeneration
    C_Timer.After(HEAD.flashSeconds, function()
        if row.settingHighlightGeneration == generation then row.settingHighlight:Hide() end
    end)
end

local function ScrollToSetting(key, label, card)
    local Settings = ns.Shared.Settings
    if not (card and wrappers[key]) then return end
    local row, top = Settings.FindRow(wrappers[key], label, card)
    if not top then return end
    UI.HighlightSetting(row)
    scrollFrame:UpdateScrollChildRect()
    local y = top - scrollFrame:GetHeight() * SETTING_AT
    scrollFrame:SetVerticalScroll(math.min(scrollFrame:GetVerticalScrollRange(), math.max(0, y)))
end

function UI.GoToSetting(key, label, card)
    key = O.NavPage(card or key) or O.NavPage(key)
    if not (window and key) then return end
    if O.IsModuleCard(card) then label = nil end
    if UI.SearchTyped() then
        searchJump = true
        UI.ClearSearch()
        searchJump = false
    end
    if card then ns.Shared.Settings.Reveal(card, label) end
    if wrappers[key] then wrappers[key]._dirty = true end
    ShowPage(key)
    ScrollToSetting(key, label, card)
end

local function ShowModulePage(win, key)
    win.page = key
    ShowWrapper(win.wrappers, win.scrollChild, key)
    win.scrollFrame:SetVerticalScroll(0)
    win.switch._refreshValue()
    PaintTabs(win.tabs, key)
end

local function InvalidatePages(pageWrappers)
    for name, w in pairs(pageWrappers) do
        if PAGES[name].reuse or PAGES[name].soon then
            w._dirty = true
        else
            w:Hide()
            w:SetParent(nil)
            pageWrappers[name] = nil
        end
    end
end

local function RebuildModuleWindow(win)
    if not win:IsShown() then
        win.pendingRefresh = true
        return
    end
    local scroll = win.scrollFrame:GetVerticalScroll()
    InvalidatePages(win.wrappers)
    ShowModulePage(win, win.page)
    win.scrollFrame:UpdateScrollChildRect()
    win.scrollFrame:SetVerticalScroll(scroll)
end

local function RebuildPages()
    refreshQueued = false
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
    if window and window:IsShown() then
        local scroll = scrollFrame:GetVerticalScroll()
        InvalidatePages(wrappers)
        ShowPage(currentPage)
        scrollFrame:UpdateScrollChildRect()
        scrollFrame:SetVerticalScroll(scroll)
    else
        pendingRefresh = true
    end
    for _, win in pairs(moduleWindows) do RebuildModuleWindow(win) end
end

local function InvalidateFiltered()
    for _, w in pairs(wrappers) do w._dirty = true end
end

local function FirstMatch(filter, key)
    for _, k in ipairs(filter.order) do
        if PAGES[k].category then key = k break end
    end
    if not filter.count[key] and filter.order[1] then key = filter.order[1] end
    return key
end

local function RevealFound(last, key)
    for uid in pairs(last.cards) do
        local card = ns.Shared.Settings.CardOf(uid)
        if card and card.page.key == key then ns.Shared.Settings.Reveal(uid) end
    end
    return last.first[key]
end

local function OnSearch()
    local filter, last = UI.filter, lastFilter
    lastFilter = filter
    if not (window and window:IsShown()) then
        pendingRefresh = true
        return
    end
    if searchJump then
        InvalidateFiltered()
        return
    end
    local key, found = currentPage, nil
    if filter and not filter.count[key] then
        key = FirstMatch(filter, key)
    elseif not filter and last and last.first[key] and not last.all[key] then
        found = RevealFound(last, key)
    end
    InvalidateFiltered()
    ShowPage(key)
    if found then ScrollToSetting(key, nil, found) end
end

local function AnyWindowShown()
    if window and window:IsShown() then return true end
    for _, win in pairs(moduleWindows) do
        if win:IsShown() then return true end
    end
    return false
end

function UI:RefreshPage(force)
    if not AnyWindowShown() then
        pendingRefresh = true
        for _, win in pairs(moduleWindows) do win.pendingRefresh = true end
        return
    end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, RebuildPages)
end

local function OnEquipmentChanged(_, _, slot)
    if slot == INVSLOT_TRINKET1 or slot == INVSLOT_TRINKET2 then UI:RefreshPage(true) end
end

local equipWatcher = CreateFrame("Frame")
equipWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipWatcher:SetScript("OnEvent", OnEquipmentChanged)

local function FitMainWindow()
    if not window then return end
    local fit = math.min((UIParent:GetWidth() - SCREEN_MARGIN) / window:GetWidth(),
        (UIParent:GetHeight() - SCREEN_MARGIN) / window:GetHeight())
    window:SetScale(math.min(ns.UIScale(), math.max(MIN_FIT, fit)))
    ns.RefitPixels()
end

function ns.SetWindowScale(pct)
    ns.AccountSettings().windowScale = tonumber(pct) or DEFAULT_SCALE
    FitMainWindow()
    for _, win in pairs(moduleWindows) do win:SetScale(ns.UIScale()) end
    ns.RefitPixels()
end

local function EnterUnlockMode()
    if ns.ShowUnlockMode then ns.ShowUnlockMode() end
end

local function DragRegion(frame, target)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() target:StartMoving() end)
    frame:SetScript("OnDragStop", function() target:StopMovingOrSizing() end)
    ns.AllowOffscreen(target)
end

local function Resizable(frame, key, child, inset, minW, minH)
    local function Fit()
        child:SetWidth(frame:GetWidth() - (type(inset) == "function" and inset() or inset))
    end
    local function Released()
        local width = child:GetWidth()
        Fit()
        if frame == window then FitMainWindow() end
        if child:GetWidth() ~= width then UI:RefreshPage(true) end
    end
    ns.Shared.Parts.Resizable(frame, key, minW, minH, nil, Released)
    Fit()
end

local function CloseOnEscape(self, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false)
        C_Timer.After(0, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    else
        self:SetPropagateKeyboardInput(true)
    end
end
UI.CloseOnEscape = CloseOnEscape

local function TabStrip(parent, tabs, onPick, maxW)
    local items = {}
    for i, tab in ipairs(tabs) do items[i] = { key = tab.key, label = ns.L(tab.name) } end
    local Parts = ns.Shared.Parts
    local bar = Parts.Tabs(parent, 1, items, onPick, true, true)
    Parts.FitTabs(bar, items, TAB_MARGIN, maxW)
    return bar
end

local function ClampNav(scroll)
    local range = scroll:GetVerticalScrollRange()
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScroll(), range)))
end

local function RefreshNavRange(scroll)
    scroll:GetScript("OnScrollRangeChanged")(scroll)
    ClampNav(scroll)
end

local function RefitNav(scroll)
    scroll:UpdateScrollChildRect()
    RefreshNavRange(scroll)
end

local function NavigationScroll(parent, top, bottom, width)
    local scroll = UI.SlimScroll(parent, NAV_BAR.w, NAV_BAR.inset)
    scroll:SetPoint("TOPLEFT", 0, -top)
    scroll:SetPoint("BOTTOMRIGHT", -NAV_GUTTER, bottom)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - NAV_GUTTER, 1)
    scroll:SetScrollChild(child)
    scroll:HookScript("OnScrollRangeChanged", ClampNav)
    scroll:HookScript("OnShow", RefreshNavRange)
    scroll:SetScript("OnSizeChanged", RefitNav)
    UI.SmoothWheel(scroll, NAV_H)
    return child
end

local function NavEnter(btn)
    PaintNavButton(btn, true)
end

local function NavLeave(btn)
    if btn:IsMouseOver() then return end
    PaintNavButton(btn, false)
end

local function NavIcon(btn, icon)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(NAV_ICON_SIZE, NAV_ICON_SIZE)
    btn.icon:SetPoint("LEFT", NAV_ICON_X, 0)
    btn.icon:SetTexture(NAV_ICONS .. icon .. ".tga")
    btn.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
end

local function NavigationButton(parent, label, y, onClick, icon, listed)
    if ns.foreverSkin then icon = nil end
    local lined = ns.foreverSkin and listed
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", NAV_INSET, y)
    btn:SetPoint("TOPRIGHT", -NAV_INSET, y)
    btn:SetHeight(NAV_ROW + NAV_BUTTON_EXTRA)
    btn.fill = ns.Solid(btn, "BACKGROUND", T.accent, NAV_FILL_ALPHA)
    btn.fill:SetAllPoints()
    btn.fill:Hide()
    btn.marker = ns.Solid(btn, "ARTWORK", T.accent, 1)
    btn.marker:SetPoint("TOPLEFT"); btn.marker:SetPoint("BOTTOMLEFT"); btn.marker:SetWidth(NAV_MARKER_W)
    btn.marker:Hide()
    if not ns.foreverSkin then
        btn.marker:ClearAllPoints()
        btn.marker:SetTexture(NAV_DOT_TEXTURE, nil, nil, "TRILINEAR")
        btn.marker:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
        btn.marker:SetSize(NAV_DOT, NAV_DOT)
        btn.marker:SetPoint("LEFT", 0, 0)
    end
    if lined then
        ns.Shared.Parts.ForeverNavLine(btn)
    elseif ns.foreverSkin then
        ns.Shared.Parts.ForeverNavButton(btn)
    end
    btn.label = ns.Font(btn, ns.foreverSkin and Forever.navText or NAV_TEXT_SIZE, nil, T.muted, true)
    btn.label:SetPoint("LEFT", lined and Forever.itemX or icon and NAV_LABEL_X or NAV_TEXT_X, 0)
    btn.label:SetPoint("RIGHT", -NAV_TEXT_RIGHT, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.label:SetText(label)
    btn.count = ns.Font(btn, NAV_COUNT_SIZE, nil, T.accent)
    btn.count:SetPoint("RIGHT", -NAV_COUNT_RIGHT, 0)
    if icon then NavIcon(btn, icon) end
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", NavEnter)
    btn:SetScript("OnLeave", NavLeave)
    return btn
end

local function OnWindowKeyDown(self, key)
    if InCombatLockdown() then return end
    local open = key == "F" and IsControlKeyDown()
    if not (open or (key == "ESCAPE" and UI.SearchTyped())) then return CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    if open then UI.FocusSearch() else UI.ClearSearch() end
    C_Timer.After(0, function()
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
end

local function WindowFrame()
    window = CreateFrame("Frame", OPTIONS_NAME, UIParent)
    window:SetSize(WINDOW_W, WINDOW_H)
    window:SetScale(ns.UIScale())
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    if ns.foreverSkin then
        ns.Shared.Parts.Backdrop(window):Paint(1)
    else
        ns.Solid(window, "BACKGROUND", T.bg, 1):SetAllPoints()
    end
    ns.Shared.Parts.Shadow(window)
    local border = ns.Border(window, ns.Shared.Style.BORDER_RGB)
    if ns.foreverSkin then ns.Shared.Parts.ForeverFrame(window) end
    window:SetScript("OnKeyDown", OnWindowKeyDown)
    return border
end

local function Brand(top, border)
    local brand = CreateFrame("Frame", nil, top)
    brand:SetPoint("TOPLEFT")
    brand:SetSize(SIDEBAR_W, TOP_H)
    ns.Solid(brand, "BACKGROUND", ns.foreverSkin and T.panel or T.bg, 1):SetAllPoints()
    if not ns.foreverSkin then
        local St = ns.Shared.Style
        ns.Solid(brand, "BACKGROUND", St.BORDER_RGB, St.SIDEBAR_SHADE):SetAllPoints()
    end
    local brandEdge = ns.Solid(brand, "ARTWORK", T.line, 1)
    brandEdge:SetPoint("TOPRIGHT"); brandEdge:SetPoint("BOTTOMRIGHT"); ns.Hairline(brandEdge, "v")
    local logo = brand:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(BRAND_LOGO, nil, nil, "TRILINEAR")
    logo:SetTexCoord(0, BRAND.artW / BRAND.texW, 0, BRAND.artH / BRAND.texH)
    logo:SetSize(BRAND.height * BRAND.artW / BRAND.artH, BRAND.height)
    logo:SetPoint("TOPLEFT", brand, "TOPLEFT", BRAND.inset, -BRAND.inset)
    border._frame:SetFrameLevel(brand:GetFrameLevel() + 1)
end

local function TopBar(border)
    local top = CreateFrame("Frame", nil, window)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(TOP_H)
    DragRegion(top, window)
    local topLine = ns.Solid(top, "ARTWORK", T.line, 1)
    topLine:SetPoint("BOTTOMLEFT"); topLine:SetPoint("BOTTOMRIGHT"); ns.Hairline(topLine, "h")
    Brand(top, border)
    local close = ns.Button(top, TEXT_CLOSE, TOP.close, TOP.close, function() window:Hide() end)
    close:SetPoint("RIGHT", -TOP.gap, 0)
    local unlock = ns.Button(top, TEXT_HUD_EDITOR, TOP.hudW, TOP.buttonH, EnterUnlockMode)
    ns.PrimaryButton(unlock)
    unlock:SetPoint("RIGHT", close, "LEFT", -TOP.gap, 0)
    ns.Tooltip(unlock, TEXT_HUD_EDITOR, TEXT_HUD_HELP)
    local reload = ns.ReloadButton(top, TEXT_RELOAD, TOP.reloadW, TOP.buttonH)
    reload:SetPoint("RIGHT", unlock, "LEFT", -TOP.gap, 0)
end

local function BandHeading(nav, band, ny)
    if ns.foreverSkin then
        local bar = CreateFrame("Frame", nil, nav)
        bar:SetPoint("TOPLEFT", NAV_INSET, ny - Forever.groupGap)
        bar:SetPoint("TOPRIGHT", -NAV_INSET, ny - Forever.groupGap)
        bar:SetHeight(NAV_ROW)
        ns.Shared.Parts.ForeverGroupBar(bar, ns.L(band))
        return ny - Forever.groupGap - NAV_ROW - Forever.groupBelow
    end
    local label = ns.Font(nav, SIDE.groupSize, nil, T.muted, true)
    label:SetPoint("TOPLEFT", SIDE.groupX, ny - SIDE.groupY); label:SetText(ns.L(band))
    return ny - SIDE.groupStep
end

local function NavRow(nav, key, label, icon, ny, onClick)
    local btn = NavigationButton(nav, ns.L(label), ny, onClick, icon, true)
    btn:SetHeight(NAV_ROW)
    navButtons[key] = btn
    return btn, ny - NAV_ROW
end

local function CategoryNav(nav)
    local home = PAGES[FIRST_PAGE]
    local _, ny = NavRow(nav, home.key, home.name, home.navIcon, 0, function() ShowPage(home.key) end)
    local band
    for _, cat in ipairs(CATEGORIES) do
        if cat.band and cat.band ~= band then ny = BandHeading(nav, cat.band, ny) end
        band = cat.band
        local btn
        btn, ny = NavRow(nav, cat.name, cat.name, cat.navIcon, ny,
            function() ShowPage(lastPages[cat.name] or cat.overview.key) end)
        btn.cat = cat
    end
    nav:SetHeight(-ny + Forever.NavRoom())
end

local function SystemNav(sidebar)
    local utility = CreateFrame("Frame", nil, sidebar)
    utility:SetPoint("BOTTOMLEFT", 0, FOOTER_H_SIDEBAR); utility:SetPoint("BOTTOMRIGHT", 0, FOOTER_H_SIDEBAR)
    utility:SetHeight(NAV_STEP * #SYSTEM_NAV + SIDE.utilityRoom)
    local utilityLine = ns.Solid(utility, "ARTWORK", T.line, 1)
    utilityLine:SetPoint("TOPLEFT"); utilityLine:SetPoint("TOPRIGHT"); ns.Hairline(utilityLine, "h")
    if window.forever then Forever.Rod(utility, utilityLine) end
    for i, entry in ipairs(SYSTEM_NAV) do
        local key = entry[1]
        local btn = NavigationButton(utility, ns.L(key), -SIDE.utilityTop - (i - 1) * NAV_STEP, function() ShowPage(key) end,
            entry[2])
        btn:SetHeight(SIDE.utilityRow)
        navButtons[key] = btn
    end
end

local function SidebarFooter(sidebar)
    local version = ns.Font(sidebar, SIDE.versionSize, nil, T.muted)
    version:SetPoint("BOTTOMLEFT", SIDE.versionX, SIDE.versionY)
    version:SetText(ns.VersionText())
    local Parts = ns.Shared.Parts
    local right = -SIDE.linksRight
    for i = #LINKS, 1, -1 do
        local name, icon, url = LINKS[i][1], LINKS[i][2], LINKS[i][3]
        local link = Parts.IconButton(sidebar, function() ns.ShowCopyLine(name, url()) end, LINK_ICONS .. icon .. ".tga",
            nil, name)
        link:SetSize(SIDE.linkSize, SIDE.linkSize)
        link.icon:SetSize(SIDE.linkSize, SIDE.linkSize)
        link:SetPoint("BOTTOMRIGHT", right, SIDE.linksY)
        right = right - SIDE.linkSize - SIDE.linkGap
    end
end

function Forever.NavRoom()
    if not window.forever then return 0 end
    local St = ns.Shared.Style
    return St.FOREVER_DRAGON.h + St.FOREVER_RAIL / 2
end

function Forever.Rod(utility, line)
    local rod = ns.Shared.Parts.ForeverRod(utility)
    if not rod then return end
    line:Hide()
    rod:SetPoint("LEFT", utility, "TOPLEFT")
    rod:SetPoint("RIGHT", utility, "TOPRIGHT")
    rod:SetFrameLevel(utility:GetFrameLevel() + Forever.rodRaise)
    Forever.rod = rod
end

function Forever.Top()
    local St = ns.Shared.Style
    return St.FOREVER_BAND_H + St.FOREVER_RAIL
end

function Forever.Frame()
    ns.Shared.Parts.ForeverPanes(window, ns.Shared.Style.FOREVER_BAND_H, SIDEBAR_W)
end

local function Sidebar()
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 0, -(window.forever and Forever.Top() or TOP_H)); sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(SIDEBAR_W)
    if not window.forever then
        local St = ns.Shared.Style
        ns.Solid(sidebar, "BACKGROUND", T.bg, 1):SetAllPoints()
        ns.Solid(sidebar, "BACKGROUND", St.BORDER_RGB, St.SIDEBAR_SHADE):SetAllPoints()
    end
    local edge = ns.Solid(sidebar, "ARTWORK", T.line, 1)
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); ns.Hairline(edge, "v")
    if window.forever then edge:Hide() end
    searchBox = UI.AttachSearchBox(sidebar, OnSearch, SEARCH.columns)
    searchBox:SetPoint("TOPLEFT", SEARCH.left, -SEARCH.top)
    searchBox:SetPoint("TOPRIGHT", -SEARCH.right, -SEARCH.top)
    searchBox:SetHeight(SEARCH.h)
    local top = SEARCH.top + SEARCH.h + SEARCH.gap
    local bottom = FOOTER_H_SIDEBAR + SIDE.utilityRoom + NAV_STEP * #SYSTEM_NAV
    local nav = NavigationScroll(sidebar, top, bottom, SIDEBAR_W)
    CategoryNav(nav)
    SystemNav(sidebar)
    SidebarFooter(sidebar)
    return sidebar
end

local function ContentHeader()
    contentHeader = CreateFrame("Frame", nil, window)
    contentHeader:SetHeight(PAGE_HEADER_H)
    breadcrumb = ns.Font(contentHeader, HEAD.crumbSize, nil, T.muted)
    breadcrumb:SetPoint("TOPLEFT", CONTENT_X, -HEAD.crumbY)
    headerTitle = ns.Font(contentHeader, HEAD.titleSize, nil, ns.foreverSkin and T.accent or nil, true)
    headerTitle:SetPoint("TOPLEFT", CONTENT_X, -HEAD.titleY)
    headerTitle:SetPoint("TOPRIGHT", contentHeader, "TOPRIGHT", -HEAD.titleRoom, -HEAD.titleY)
    headerTitle:SetJustifyH("LEFT"); headerTitle:SetWordWrap(false)
    headerSub = ns.Font(contentHeader, HEAD.subSize, nil, T.muted)
    headerSub:SetPoint("TOPLEFT", CONTENT_X, -HEAD.subY)
    headerSub:SetPoint("TOPRIGHT", -CONTENT_RIGHT, -HEAD.subY); headerSub:SetJustifyH("LEFT"); headerSub:SetWordWrap(false)
    local tabsW = WINDOW_W - SIDEBAR_W - CONTENT_X - CONTENT_RIGHT
    if window.forever then tabsW = tabsW - ns.Shared.Style.FOREVER_RAIL end
    for _, cat in ipairs(CATEGORIES) do
        local bar = TabStrip(contentHeader, cat.tabs, ShowPage, tabsW)
        bar:SetPoint("TOPLEFT", contentHeader, "TOPLEFT", CONTENT_X, -(PAGE_HEADER_H - HEAD.tabDrop))
        bar:Hide()
        tabStrips[cat.name] = bar
    end
    tabLine = ns.Solid(window, "ARTWORK", T.line, 1); ns.Hairline(tabLine, "h")
    if window.forever then Forever.Header() end
end

function Forever.Buttons()
    local unlock = ns.Button(contentHeader, TEXT_HUD_EDITOR, TOP.hudW, Forever.buttonH, EnterUnlockMode)
    ns.Tooltip(unlock, TEXT_HUD_EDITOR, TEXT_HUD_HELP)
    local reload = ns.AccentBorder(ns.ReloadButton(contentHeader, TEXT_RELOAD, TOP.reloadW, Forever.buttonH))
    reload:SetPoint("RIGHT", contentHeader, "RIGHT", -Forever.edge, 0)
    unlock:SetPoint("RIGHT", reload, "LEFT", -Forever.buttonGap, 0)
end

function Forever.Header()
    local St = ns.Shared.Style
    contentHeader:ClearAllPoints()
    contentHeader:SetPoint("TOPLEFT", window, "TOPLEFT")
    contentHeader:SetPoint("TOPRIGHT", window, "TOPRIGHT")
    contentHeader:SetHeight(St.FOREVER_BAND_H)
    DragRegion(contentHeader, window)
    headerTitle:ClearAllPoints()
    headerTitle:SetPoint("TOPLEFT", St.FOREVER_PORTRAIT_ROOM, -Forever.titleY)
    headerTitle:SetPoint("TOPRIGHT", contentHeader, "TOPRIGHT", -Forever.headRoom, -Forever.titleY)
    breadcrumb:ClearAllPoints()
    breadcrumb:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -Forever.crumbGap)
    headerSub:ClearAllPoints()
    headerSub:SetPoint("LEFT", breadcrumb, "RIGHT", Forever.subGap, 0)
    headerSub:SetPoint("RIGHT", contentHeader, "RIGHT", -Forever.headRoom, 0)
    Forever.Buttons()
    local tabX = SIDEBAR_W + St.FOREVER_RAIL + CONTENT_X
    local tabY = Forever.Top() + Forever.tabTop
    for _, bar in pairs(tabStrips) do
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", window, "TOPLEFT", tabX, -tabY)
    end
    tabLine:Hide()
    Forever.tabRail = ns.Shared.Parts.ForeverRail(window)
    Forever.tabRail:SetPoint("TOPLEFT", window, "TOPLEFT", tabX - Forever.railOut, -(tabY + St.TAB_H))
    Forever.tabRail:SetPoint("TOPRIGHT", window, "TOPRIGHT", -CONTENT_RIGHT, -(tabY + St.TAB_H))
    Forever.tabRail:Hide()
end

function Forever.Layout(page, cat)
    LayoutHeader(page)
    for name, strip in pairs(tabStrips) do strip:SetShown(cat ~= nil and name == cat.name) end
    Forever.tabRail:SetShown(cat ~= nil)
    local top = Forever.Top() + (cat and Forever.tabTop + TAB_H or 0)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR_W + ns.Shared.Style.FOREVER_RAIL + SCROLL_X,
        -(top + SCROLL_Y))
    scrollFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -CONTENT_RIGHT, SCROLL_BOTTOM)
    scrollChild:SetWidth(window:GetWidth() - SIDEBAR_W - CHILD_ROOM)
end

local function LoadedNow()
    local loaded = {}
    for i, mod in ipairs(MODULES) do loaded[i] = Loaded(mod) and "1" or "0" end
    return table.concat(loaded)
end

local function OnWindowShow(self)
    FitMainWindow()
    if not InCombatLockdown() then
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end
    local loaded = LoadedNow()
    if pendingRefresh or loaded ~= builtLoaded then
        pendingRefresh, builtLoaded = nil, loaded
        InvalidatePages(wrappers)
    end
    ShowPage(currentPage)
end

local function OnWindowHide()
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
    for i = 1, #onHideCallbacks do onHideCallbacks[i]() end
    ns.HideUnlockMode(true)
end

local function ActiveNavButton()
    return navButtons[ActiveNav()]
end

local function CreateWindow()
    local border = WindowFrame()
    if window.forever then Forever.Frame() else TopBar(border) end
    local sidebar = Sidebar()
    ContentHeader()
    scrollFrame = UI.SlimScroll(window, nil, SCROLL_BAR_GAP)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(WINDOW_W - SIDEBAR_W - CHILD_ROOM, 1)
    scrollFrame:SetScrollChild(scrollChild)
    Resizable(window, "main", scrollChild, SIDEBAR_W + CHILD_ROOM, WINDOW_W, MIN_WINDOW_H)
    window:SetScript("OnShow", OnWindowShow)
    window:SetScript("OnHide", OnWindowHide)
    FitMainWindow()
    window:Hide()
    ns.PadWindow(window, { nav = sidebar, navFocus = ActiveNavButton, content = scrollFrame })
end

function ns.OpenOptionsWindow(pageName)
    if pageName then currentPage = O.NavPage(pageName) or currentPage end
    if not window then CreateWindow() end
    if window:IsShown() and pageName then
        ShowPage(currentPage)
    end
    window:Show()
end

function ns.OpenFromOptions(open)
    if not (window and window:IsShown()) then return open() end
    local page = currentPage
    ns.Shared.Parts.OpenWithBack(open, window, function() ns.OpenOptionsWindow(page) end, TEXT_BACK)
end

function ns.StashOptionsWindow()
    if window and window:IsShown() then
        window:Hide()
        return true
    end
    return false
end

function ns.ToggleOptionsWindow(pageName)
    if window and window:IsShown() then
        window:Hide()
    else
        ns.OpenOptionsWindow(pageName)
    end
end

local function ModuleWindowFrame()
    local win = CreateFrame("Frame", nil, UIParent)
    win:Hide()
    win:SetSize(CONTENT_W, MW.h)
    win:SetScale(ns.UIScale())
    win:SetPoint("CENTER")
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    if ns.foreverSkin then
        ns.Shared.Parts.Backdrop(win):Paint(1)
    else
        ns.Solid(win, "BACKGROUND", T.bg, 1):SetAllPoints()
    end
    ns.Border(win, ns.Shared.Style.BORDER_RGB)
    if ns.foreverSkin then ns.Shared.Parts.ForeverFrame(win) end
    win:SetScript("OnKeyDown", CloseOnEscape)
    return win
end

local function ModuleSwitchTip(mod)
    return function() return ModuleOn(mod) and TEXT_ON or TEXT_OFF end
end

local function ModuleHeader(win, mod)
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_H)
    DragRegion(header, win)
    local title = ns.Font(header, MW.titleSize, nil, ns.foreverSkin and T.accent or nil, true)
    title:SetPoint("TOPLEFT", header, "TOPLEFT", win.forever and ns.Shared.Style.FOREVER_PORTRAIT_ROOM or MW.titleX,
        -MW.titleY)
    title:SetText(DisplayName(mod))
    local sub = ns.Font(header, MW.subSize, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", MW.subX, -MW.subGap)
    sub:SetText(ns.L(mod.subtitle))
    local close = ns.Button(header, TEXT_CLOSE, MW.close, MW.close, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -MW.closeInset, -MW.closeInset)
    local switch = UI.BuildToggleControl(header, header:GetFrameLevel() + MW.switchRaise,
        function() return ModuleOn(mod) end,
        function(v) SetModuleOn(mod, v) end)
    switch:SetPoint("RIGHT", close, "LEFT", -MW.switchGap, 0)
    ns.Tooltip(switch, DisplayName(mod), ModuleSwitchTip(mod))
    win.switch = switch
    if not win.forever then return end
    close:Hide()
    switch:ClearAllPoints()
    switch:SetPoint("TOPRIGHT", header, "TOPRIGHT", -MW.closeInset, -MW.closeInset)
end

local function ModuleBody(win, mod)
    win.tabs = TabStrip(win, mod.tabs, function(key) ShowModulePage(win, key) end, CONTENT_W - MW.tabRoom)
    win.tabs:SetPoint("TOPLEFT", win, "TOPLEFT", MW.tabX, -(HEADER_H + MW.tabDrop))
    local offset = HEADER_H + TAB_H
    local line = ns.Solid(win, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -offset)
    line:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -offset)
    ns.Hairline(line, "h")
    if win.forever then
        local inset = ns.Shared.Parts.ForeverInset(win)
        inset:SetPoint("TOPLEFT", win, "TOPLEFT", Forever.insetLeft, -offset)
        inset:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -Forever.insetRight, Forever.insetBottom)
    end
    win.scrollFrame = UI.SlimScroll(win, nil, SCROLL_BAR_GAP)
    win.scrollFrame:SetPoint("TOPLEFT", win, "TOPLEFT", MW.scrollX, -(offset + MW.scrollY))
    win.scrollFrame:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -MW.scrollRight, MW.scrollBottom)
    win.scrollChild = CreateFrame("Frame", nil, win.scrollFrame)
    win.scrollChild:SetSize(CONTENT_W - MW.childRoom, 1)
    win.scrollFrame:SetScrollChild(win.scrollChild)
    Resizable(win, "module:" .. mod.name, win.scrollChild, MW.childRoom, CONTENT_W, MW.minH)
end

local function OnModuleWindowShow(self)
    if not InCombatLockdown() then
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end
    if self.pendingRefresh then
        self.pendingRefresh = nil
        InvalidatePages(self.wrappers)
    end
    ShowModulePage(self, self.page)
end

local function OnModuleWindowHide()
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
end

local function CreateModuleWindow(mod)
    local win = ModuleWindowFrame()
    ModuleHeader(win, mod)
    ModuleBody(win, mod)
    win.wrappers = {}
    win.page = mod.tabs[1].key
    win:SetScript("OnShow", OnModuleWindowShow)
    win:SetScript("OnHide", OnModuleWindowHide)
    return win
end

local function ToggleModuleWindow(mod)
    local win = moduleWindows[mod.name]
    if not win then
        win = CreateModuleWindow(mod)
        moduleWindows[mod.name] = win
    end
    win:SetShown(not win:IsShown())
end

local function OpenModule(mod)
    if not Loaded(mod) then return ns.Print(TEXT_SWITCHED_OFF:format(DisplayName(mod))) end
    if mod.open and ns[mod.open] then ns[mod.open]() else ToggleModuleWindow(mod) end
end

O.OpenModule = OpenModule
