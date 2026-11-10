-- Takeover.lua: Naowh's window over Blizzard's profession window: when it shows, what of Blizzard's it docks, and the events.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local Links = P.Links
local Style = P.Style

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local FALLBACK_STRATA = "HIGH"
local TABS_DROP = -60
local FIT_SLACK = 1
local FLIP = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT",
    BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" }
local UNLEARN_GAP = 6
local UNLEARN_ATLAS = "Profession-button-red-crossmark"
local UNLEARN_FALLBACK = "Interface/RAIDFRAME/ReadyCheck-NotReady"
local UNLEARN_SIZE = 20
local TAB_OUTLINE_ATLAS, TAB_OUTLINE_SUBLEVEL = "common-sidetab-hover", 7
local CARD_LEVEL, UNLEARN_LEVEL = 3, 10
local RANK_INSET = 2
local BURST = 0.1
local CARD_ART = { "Background", "ProfessionName", "specialization", "missingHeader", "missingText", "StatusBar" }
local QUIET = { ITEM_DATA_LOAD_RESULT = true, BAG_UPDATE_DELAYED = true, PLAYERBANKSLOTS_CHANGED = true,
    AUCTION_HOUSE_SHOW = true, AUCTION_HOUSE_CLOSED = true, TRACKED_RECIPE_UPDATE = true,
    GROUP_ROSTER_UPDATE = true }
local REREAD = { APPLY = true, ADDON_LOADED = true, TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true,
    TRADE_SKILL_DATA_SOURCE_CHANGED = true, TRADE_SKILL_NAME_UPDATE = true, NEW_RECIPE_LEARNED = true,
    SKILL_LINES_CHANGED = true, TRADE_SKILL_FAVORITES_CHANGED = true }
local EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_NAME_UPDATE", "NEW_RECIPE_LEARNED",
    "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PLAYERBANKSLOTS_CHANGED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "TRACKED_RECIPE_UPDATE", "GROUP_ROSTER_UPDATE", "TRADE_SKILL_FAVORITES_CHANGED" }
local REDRAW_KEYS = { vendorMaterials = true, bagReagents = true, bankReagents = true, ahSearch = true,
    skillThresholds = true, skillUpChances = true, skillUpPlan = true, skillUpPlanLater = true, skillUpPlanBest = true,
    learnedRecipeVendors = true,
    craftProfit = true, craftProfitList = true, buyMaterials = true, buyVendor = true, craftOrders = true,
    orderTip = true, ownedAuctions = true, makeReagents = true }
local PROFESSIONS_ADDON = "Blizzard_Professions"

local EMPTY = {}
local waiting = R.waiting
local win, hooked, lastMode
local queued = false
local savedTabPoints, tabsLeft
local mirrored = {}
local flippedArt = setmetatable({}, { __mode = "k" })
local hookedArt = setmetatable({}, { __mode = "k" })
local placing = false
local docked = {}
local outlines = setmetatable({}, { __mode = "k" })
local bookDocked, bookPending = false, nil
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end

local function NextStrata(strata)
    for i, s in ipairs(STRATA) do
        if s == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return FALLBACK_STRATA
end

local function OutlineTab(tab, on)
    local outline = outlines[tab]
    if on and not outline then
        local accent = ns.THEME.accent
        outline = tab:CreateTexture(nil, "ARTWORK", nil, TAB_OUTLINE_SUBLEVEL)
        outline:SetAtlas(TAB_OUTLINE_ATLAS, true)
        outline:SetPoint("CENTER")
        outline:SetDesaturated(true)
        outline:SetVertexColor(accent.r, accent.g, accent.b)
        outlines[tab] = outline
    end
    if outline then outline:SetShown(on) end
end

local function ShowUnlearn(button)
    local icon = button.Icon
    if not icon then return end
    if not C_Texture.GetAtlasInfo(UNLEARN_ATLAS) then icon:SetTexture(UNLEARN_FALLBACK) end
    icon:SetSize(UNLEARN_SIZE, UNLEARN_SIZE)
    icon:SetAlpha(1)
    if button.Overlay then button.Overlay:SetSize(UNLEARN_SIZE, UNLEARN_SIZE) end
end

local function Points(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return points
end

local function FlipPoints(region, tab, points)
    placing = true
    region:ClearAllPoints()
    for _, pt in ipairs(points) do
        local point, rel, relPoint, x, y = unpack(pt)
        if rel == tab then
            region:SetPoint(FLIP[point] or point, rel, FLIP[relPoint] or relPoint, -(x or 0), y or 0)
        else
            region:SetPoint(unpack(pt))
        end
    end
    placing = false
end

local function OnTabArtPlaced(region)
    local saved = flippedArt[region]
    if placing or not (saved and savedTabPoints) then return end
    local _, rel = region:GetPoint(1)
    if rel ~= saved.tab then return end
    FlipPoints(region, saved.tab, Points(region))
end

local function MirrorRegion(region, tab)
    local saved = { region = region, tab = tab, points = Points(region) }
    local kind = region:GetObjectType()
    if kind == "Texture" and region:GetAtlas() then
        saved.coords = { region:GetTexCoord() }
        local ulx, uly, llx, lly, urx, ury, lrx, lry = region:GetTexCoord()
        region:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly)
    elseif kind == "MaskTexture" and region.SetRotation then
        saved.rotation = region:GetRotation()
        region:SetRotation(saved.rotation + math.pi)
    end
    mirrored[#mirrored + 1] = saved
    if #saved.points == 0 then return end
    flippedArt[region] = saved
    if not hookedArt[region] then
        hookedArt[region] = true
        hooksecurefunc(region, "SetPoint", OnTabArtPlaced)
    end
    FlipPoints(region, tab, saved.points)
end

local function MirrorTab(tab)
    for _, region in ipairs({ tab:GetRegions() }) do MirrorRegion(region, tab) end
end

local function Unmirror()
    for _, saved in ipairs(mirrored) do
        local region = saved.region
        if saved.coords then region:SetTexCoord(unpack(saved.coords)) end
        if saved.rotation then region:SetRotation(saved.rotation) end
        if #saved.points > 0 then
            placing = true
            region:ClearAllPoints()
            for _, pt in ipairs(saved.points) do region:SetPoint(unpack(pt)) end
            placing = false
        end
    end
    wipe(mirrored)
end

local function DockTabs(on)
    local head = ProfessionsFrame.ProfessionsOverviewTab
    if not head then return end
    local tabs = ProfessionsFrame.rightProfessionTabs or EMPTY
    if on then
        if not savedTabPoints then
            savedTabPoints = Points(head)
            if tabsLeft then
                MirrorTab(head)
                for _, tab in ipairs(tabs) do MirrorTab(tab) end
            end
        end
        local point, relPoint = "TOPLEFT", "TOPRIGHT"
        if tabsLeft then point, relPoint = "TOPRIGHT", "TOPLEFT" end
        head:ClearAllPoints()
        head:SetPoint(point, win, relPoint, 0, TABS_DROP)
    elseif savedTabPoints then
        head:ClearAllPoints()
        for _, pt in ipairs(savedTabPoints) do head:SetPoint(unpack(pt)) end
        savedTabPoints = nil
        Unmirror()
    end
    local outline = on and not tabsLeft
    if head.SetIgnoreParentAlpha then head:SetIgnoreParentAlpha(on) end
    OutlineTab(head, outline)
    for _, tab in ipairs(tabs) do
        if tab.SetIgnoreParentAlpha then tab:SetIgnoreParentAlpha(on) end
        OutlineTab(tab, outline)
    end
end

local function Place(frame, place, level)
    frame:ClearAllPoints()
    place(frame)
    frame:SetFrameStrata(win:GetFrameStrata())
    frame:SetFrameLevel(level)
end

local function HideCardArt(frame, saved)
    for _, key in ipairs(CARD_ART) do
        local region = frame[key]
        if type(region) == "table" and region.SetAlpha then
            local art = { region = region, alpha = region:GetAlpha() }
            if region.IsMouseEnabled then
                art.mouse = region:IsMouseEnabled()
                region:EnableMouse(false)
            end
            region:SetAlpha(0)
            saved.art[#saved.art + 1] = art
        end
    end
end

local function Dock(frame, place, level, parent)
    local saved = docked[frame]
    if not saved then
        local points = {}
        for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
        saved = { points = points, parent = frame:GetParent(), strata = frame:GetFrameStrata(),
            level = frame:GetFrameLevel(), art = {} }
        docked[frame] = saved
        if parent then
            frame:SetParent(parent)
            HideCardArt(frame, saved)
        end
    end
    saved.place, saved.onLevel = place, level
    Place(frame, place, level)
end

local function Redock()
    if not bookDocked or InCombatLockdown() then return end
    for frame, saved in pairs(docked) do Place(frame, saved.place, saved.onLevel) end
end

local function Undock()
    for frame, saved in pairs(docked) do
        frame:SetParent(saved.parent)
        frame:ClearAllPoints()
        for _, pt in ipairs(saved.points) do frame:SetPoint(unpack(pt)) end
        frame:SetFrameStrata(saved.strata)
        frame:SetFrameLevel(saved.level)
        for _, art in ipairs(saved.art) do
            art.region:SetAlpha(art.alpha)
            if art.mouse ~= nil then art.region:EnableMouse(art.mouse) end
        end
    end
    wipe(docked)
end

local function DockCards(content)
    for i, key in ipairs(P.Book.ORDER) do
        local blizz, card = content[key], win.book.cards[i]
        if blizz then
            Dock(blizz, function(f) f:SetAllPoints(card) end, card:GetFrameLevel() + CARD_LEVEL, card)
            if type(blizz.UnlearnButton) == "table" then
                Dock(blizz.UnlearnButton, function(f) f:SetPoint("LEFT", card.bar, "RIGHT", UNLEARN_GAP, 0) end,
                    card:GetFrameLevel() + UNLEARN_LEVEL)
                ShowUnlearn(blizz.UnlearnButton)
            end
        end
    end
end

local function DockBook(on)
    if on == bookDocked then
        bookPending = nil
        return
    end
    if InCombatLockdown() then
        bookPending = on
        return
    end
    bookPending, bookDocked = nil, on
    if not on then return Undock() end
    local content = ProfessionsFrame.BookPage and ProfessionsFrame.BookPage.ProfessionsContentFrame
    if not content then return end
    DockCards(content)
end

local function Deactivate()
    wipe(waiting)
    ns.ProfBagChanges = ns.ProfBagChanges + 1
    if win and InCombatLockdown() and win:IsProtected() then
        win:SetAlpha(0)
    elseif win then
        win:Hide()
    end
    if ProfessionsFrame and hooked then
        DockTabs(false)
        DockBook(false)
        ProfessionsFrame:SetAlpha(1)
    end
end

local Drag = {}

function Drag.Follow()
    local pos = S.Get("windowPos")
    if not (win and win:IsShown() and pos) then return end
    if InCombatLockdown() then
        Drag.pending = true
        return
    end
    Drag.pending, Drag.following = nil, true
    local scale = win:GetEffectiveScale() / ProfessionsFrame:GetEffectiveScale()
    local x, y = pos.x * scale, pos.y * scale
    local eui = _G.EllesmereUIDB
    if type(eui) == "table" and eui.shifterEnabled then
        eui.shifterPositions = eui.shifterPositions or {}
        eui.shifterPositions.ProfessionsFrame = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = x, y = y }
    end
    ProfessionsFrame:ClearAllPoints()
    ProfessionsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    Drag.following = false
    Drag.Place()
end

function Drag.Place()
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 0, 0)
end

function Drag.Save()
    S.Set("windowPos", { x = win:GetLeft(), y = win:GetTop() })
end

local function Stretch(frame, scale, left, right, bottom, top)
    if not (frame and frame:IsShown()) then return left, right, bottom, top end
    local l, b = frame:GetLeft(), frame:GetBottom()
    if not (l and b) then return left, right, bottom, top end
    local s = frame:GetEffectiveScale() / scale
    return math.min(left, l * s), math.max(right, frame:GetRight() * s),
        math.min(bottom, b * s), math.max(top, frame:GetTop() * s)
end

local function Shift(low, high, size)
    if low < 0 then return -low end
    if high > size then return math.max(size - high, -low) end
    return 0
end

function Drag.Fit()
    if not (win and win:IsShown() and savedTabPoints) or Drag.pending then return end
    local winLeft, winTop = win:GetLeft(), win:GetTop()
    if not (winLeft and winTop) then return end
    local scale = win:GetEffectiveScale()
    local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
    left, right, bottom, top = Stretch(ProfessionsFrame.ProfessionsOverviewTab, scale, left, right, bottom, top)
    for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs or EMPTY) do
        left, right, bottom, top = Stretch(tab, scale, left, right, bottom, top)
    end
    left, right, bottom, top = Stretch(ns.DockedShoppingList(), scale, left, right, bottom, top)
    if left == math.huge then return end
    local screen = UIParent:GetEffectiveScale() / scale
    local dx = Shift(left, right, UIParent:GetWidth() * screen)
    local dy = Shift(bottom, top, UIParent:GetHeight() * screen)
    if math.abs(dx) < FIT_SLACK and math.abs(dy) < FIT_SLACK then return end
    S.Set("windowPos", { x = winLeft + dx, y = winTop + dy })
    Drag.Follow()
end

local function OnDragStart(self)
    if InCombatLockdown() then return end
    local x, y = self:GetLeft(), self:GetTop()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    self:StartMoving()
    Drag.moving = true
end

local function OnDragStop(self)
    if not Drag.moving then return end
    Drag.moving = false
    self:StopMovingOrSizing()
    Drag.Save()
    Drag.Follow()
    Drag.Fit()
end

local function FirstBuild(strata)
    tabsLeft = S.Get("shoppingListDock")
    win = P.Window.Build()
    if ns.ShoppingListAttach then ns.ShoppingListAttach(win) end
    win:SetFrameStrata(NextStrata(strata))
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    ns.AllowOffscreen(win)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", OnDragStart)
    win:SetScript("OnDragStop", OnDragStop)
    win:HookScript("OnHide", OnDragStop)
    Drag.Place()
end

local function ShowParts(book, linked)
    win.rank:SetShown(not book)
    win.search:SetShown(not book)
    win.search:SetWidth(linked and Style.LEFT_W or (Style.LEFT_W - Style.FILTER_W - Style.FILTER_GAP))
    win.filter:SetShown(not book and not linked)
    win.list:SetShown(not book)
    win.mid:SetShown(not book)
end

local function Activate(mode)
    local pf = ProfessionsFrame
    if not win then FirstBuild(pf:GetFrameStrata()) end
    pf:SetAlpha(0)
    win:SetAlpha(1)
    local linked = mode == "linked"
    local orders = linked and not R.Alt()
    local width = orders and Style.WINDOW_W + Style.ORDER_W + Style.PAD or Style.WINDOW_W
    local wasWidth = win:GetWidth()
    if not InCombatLockdown() then
        win:SetSize(math.max(width, pf:GetWidth()), math.max(Style.MIN_H, pf:GetHeight()))
    end
    if not win:IsShown() or linked ~= W.linked or mode ~= lastMode then W.stale = true end
    lastMode = mode
    local opening = not win:IsShown() or linked ~= W.linked or orders ~= W.orders
    if opening then
        W.selectedID, W.selectedUnlearned, W.offset = nil, nil, 0
        win:Show()
        Drag.Follow()
    end
    W.linked, W.orders = linked, orders
    win.rank:SetWidth(width - Style.PAD * 2 - RANK_INSET * 2)
    win.order:SetShown(orders)
    DockTabs(true)
    if opening or win:GetWidth() ~= wasWidth then Drag.Fit() end
    local book = mode == "book"
    ShowParts(book, linked)
    if book then win.rankBanner:Hide() end
    if not (bookDocked and InCombatLockdown()) then win.book:SetShown(book) end
    DockBook(book)
    if book then
        P.Book.Render()
        Redock()
    else
        P.Window.Render()
    end
end

local function BookOpen()
    local book = ProfessionsFrame.BookPage
    return book and book:IsShown()
end

local function Update()
    if not (On() and ProfessionsFrame and ProfessionsFrame:IsShown()) then return Deactivate() end
    if BookOpen() and not Links.Viewing() and not C_TradeSkillUI.IsTradeSkillGuild() then
        return Activate("book")
    end
    if R.Linked() then
        if R.Profession() then return Activate("linked") end
        return Deactivate()
    end
    if not R.Own() then return Deactivate() end
    if BookOpen() then return Activate("book") end
    if R.Profession() then return Activate("craft") end
    Deactivate()
end

local function Flush()
    queued = false
    Update()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Flush)
end

local function Soon()
    if queued then return end
    queued = true
    C_Timer.After(BURST, Flush)
end

local function Refresh(reread)
    if reread then W.stale = true end
    Queue()
end

local function OnBlizzardShow()
    if On() then ProfessionsFrame:SetAlpha(0) end
    Queue()
end

local function OnBlizzardHide()
    Links.End()
    Deactivate()
end

local function OnBlizzardPlaced()
    if not Drag.following then Drag.Follow() end
end

local function HookBlizzard()
    hooked = true
    ProfessionsFrame:HookScript("OnShow", OnBlizzardShow)
    ProfessionsFrame:HookScript("OnHide", OnBlizzardHide)
    ProfessionsFrame:HookScript("OnSizeChanged", Queue)
    hooksecurefunc(ProfessionsFrame, "SetPoint", OnBlizzardPlaced)
    local book = ProfessionsFrame.BookPage
    if not book then return end
    book:HookScript("OnShow", Queue)
    book:HookScript("OnHide", Queue)
    if book.Update then hooksecurefunc(book, "Update", Redock) end
    if book.FormatProfession then hooksecurefunc(book, "FormatProfession", Redock) end
end

local function OnEvent(_, event, name, loaded)
    if event == "BAG_UPDATE_DELAYED" then ns.ProfBagChanges = ns.ProfBagChanges + 1 end
    if event == "ITEM_DATA_LOAD_RESULT" then
        if not waiting[name] then return end
        waiting[name] = nil
        if not loaded then return end
    end
    if QUIET[event] and not (win and win:IsShown()) then return end
    if event == "GROUP_ROSTER_UPDATE" and not W.linked then return end
    if event == "ADDON_LOADED" then
        if name ~= PROFESSIONS_ADDON then return end
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_DISABLED" then
        if Drag.moving and win:IsProtected() then OnDragStop(win) end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bookPending ~= nil then DockBook(bookPending) end
        if Drag.pending then
            Drag.Follow()
            Drag.Fit()
        end
    end
    if not hooked and ProfessionsFrame then HookBlizzard() end
    if REREAD[event] then W.stale = true end
    if event == "TRADE_SKILL_LIST_UPDATE" then W.listChanged = true end
    if QUIET[event] or event == "TRADE_SKILL_LIST_UPDATE" then return Soon() end
    Queue()
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then return Deactivate() end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    if not C_AddOns.IsAddOnLoaded(PROFESSIONS_ADDON) then events:RegisterEvent("ADDON_LOADED") end
    OnEvent(events, "APPLY")
end

local function OnSettingChanged(key)
    if key == "enabled" then Apply() end
    if REDRAW_KEYS[key] then Queue() end
end

ns.ProfWindowRefresh = Refresh
ns.ProfWindowFit = Drag.Fit

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
