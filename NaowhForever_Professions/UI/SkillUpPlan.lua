-- SkillUpPlan.lua: the Skill-up Plan in the window's middle column, and the title bar button that opens it.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local Plan = P.SkillUpPlan
local Prices = P.Prices
local Queue = P.CraftQueue
local Shopping = P.Shopping
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local TitleButtons = P.TitleButtons
local SetColor = Widgets.SetColor
local EnableButton = Widgets.EnableButton

local OPEN_W, OPEN_H, OPEN_ORDER = 100, 22, 5
local SUB_GAP = 4
local HEAD_H = 58
local ROW_H = Style.ROW_H
local MAX_ROWS = 18
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local TEXT_GAP = 6
local RANGE_W, CRAFTS_W, COST_W = 60, 44, 92
local EDGE = Style.PANEL_EDGE
local ACTION_W = 128
local NOTE_GAP = 6
local TEXT_TITLE = ns.L("Skill-up Plan")
local TEXT_FROM = ns.L("From skill %d to your cap of %d")
local TEXT_AT_CAP = ns.L("You are at your cap of %d. Train the next rank to go on.")
local TEXT_STUCK = ns.L("No recipe you know or can train now raises your skill past %d.")
local TEXT_RANGE = "%d-%d"
local TEXT_CRAFTS = "x%d"
local TEXT_TRAIN = ns.L("Train: %s")
local TEXT_TRAIN_AT = ns.L("Train at %d: %s")
local TEXT_UNKNOWN = "?"
local TEXT_TOTAL = ns.L("%d skill-ups: about %d crafts, %s")
local TEXT_TOTAL_UNPRICED = ns.L("%d skill-ups: about %d crafts")
local TEXT_UNPRICED = ns.L("Some steps have no price yet; scan the auction house to plan by cost.")
local TEXT_VENDOR = ns.L("Costs count what each craft sells to a vendor for, not its auction house price.")
local TEXT_BEST = ns.L("Costs count each craft at its best sale: the auction house when it has %d or more auctions, "
    .. "disenchanting, or a vendor.")
local TEXT_MORE = ns.L("+%d more steps")
local TEXT_QUEUE = ns.L("Queue Plan")
local TEXT_LIST = ns.L("Add Plan to List")
local TIP_OPEN_HELP = ns.L("Shows the cheapest crafts from your skill to your cap.")
local TIP_QUEUE_HELP = ns.L("Queues every step and lists their missing materials.")
local TIP_LIST_HELP = ns.L("Puts every step's materials on your shopping list.")
local TIP_QUEUE_UPTO = ns.L("Queues the steps up to skill %d and lists their missing materials.")
local TIP_LIST_UPTO = ns.L("Puts the materials of the steps up to skill %d on your shopping list.")
local TIP_TRAIN_FIRST = ns.L("Learn the recipes marked Train first.")
local TIP_TRAIN_COST = ns.L("Learn it at a trainer first: %s")
local TIP_TRAIN_AT = ns.L("Learn it at a trainer once your skill is %d: %s")

local pane, opener
local View = {}
P.SkillUpPlanView = View

local function On()
    return S.Get("enabled") and S.Get("skillUpPlan") and not W.linked and R.Own()
end

local function QueueOn()
    return S.Get("shoppingList") and S.Get("craftQueue")
end

local function Money(copper)
    if copper >= 0 then return Text.Money(copper) end
    return Text.Hex(Style.PROFIT_RGB) .. Text.Money(-copper, true) .. "|r"
end

local function Close()
    W.planOpen = nil
end

local function OnRowClick(self)
    local step = self.step
    if not step then return end
    Close()
    if step.info then
        W.selectedID, W.selectedUnlearned = step.info.recipeID, nil
    else
        W.selectedUnlearned = step.r
    end
    P.List.Render()
    P.Detail.Render()
end

local function OnRowEnter(self)
    local step = self.step
    if not step then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if step.info then
        if not pcall(GameTooltip.SetRecipeResultItem, GameTooltip, step.info.recipeID) then
            GameTooltip:SetSpellByID(step.info.recipeID)
        end
    else
        GameTooltip:SetSpellByID(step.r.spell)
        if step.trainAt then
            GameTooltip:AddLine(TIP_TRAIN_AT:format(step.trainAt, Money(step.c.train)), 1, 1, 1)
        else
            GameTooltip:AddLine(TIP_TRAIN_COST:format(Money(step.c.train)), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function OnAction()
    local plan = Plan.Get()
    if not plan or Plan.NeedsTraining(plan) then return end
    local queue = QueueOn()
    for i = 1, Plan.Doable(plan) do
        local step = plan.steps[i]
        if queue then
            Queue.AddWithShopping(step.info, step.count)
        else
            Shopping.Add(step.info, step.count, nil, true, nil, true)
        end
    end
    if queue then return ns.OpenCraftQueue() end
    Shopping.Redraw()
    ns.OpenShoppingList()
end

local function Column(row, width, anchor)
    local fs = ns.Font(row, Style.FONT, nil)
    fs:SetWidth(width)
    fs:SetJustifyH("RIGHT")
    if anchor then
        fs:SetPoint("RIGHT", anchor, "LEFT", -TEXT_GAP, 0)
    else
        fs:SetPoint("RIGHT")
    end
    return fs
end

local function NewRow(i)
    local row = CreateFrame("Button", nil, pane)
    row:SetSize(Style.PANE_INNER_W, ROW_H)
    row:SetPoint("TOPLEFT", Style.PANE_EDGE, -HEAD_H - (i - 1) * ROW_H)
    ns.Solid(row, "HIGHLIGHT", T.fg, Style.HIGHLIGHT_ALPHA):SetAllPoints()
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_H - ICON_SHRINK, ROW_H - ICON_SHRINK)
    row.icon:SetPoint("LEFT")
    row.cost = Column(row, COST_W)
    row.crafts = Column(row, CRAFTS_W, row.cost)
    row.range = Column(row, RANGE_W, row.crafts)
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", TEXT_GAP, 0)
    row.name:SetPoint("RIGHT", row.range, "LEFT", -TEXT_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    pane.rows[i] = row
    return row
end

local function FillRow(row, step)
    row.step = step
    local id = step.info and step.info.recipeID or step.r.spell
    row.icon:SetTexture(step.info and step.info.icon or C_Spell.GetSpellTexture(id))
    row.icon:Show()
    local name = step.info and step.info.name or C_Spell.GetSpellName(id) or tostring(id)
    if step.info then
        row.name:SetText(name)
        SetColor(row.name, Style.DIFFICULTY_RGB[step.band] or T.fg)
    elseif step.trainAt then
        row.name:SetText(TEXT_TRAIN_AT:format(step.trainAt, name))
        SetColor(row.name, T.muted)
    else
        row.name:SetText(TEXT_TRAIN:format(name))
        SetColor(row.name, Style.READY_RGB)
    end
    row.range:SetText(TEXT_RANGE:format(step.from, step.to))
    row.crafts:SetText(TEXT_CRAFTS:format(step.count))
    row.cost:SetText(step.cost and Money(step.cost) or TEXT_UNKNOWN)
    SetColor(row.cost, step.cost and T.fg or T.muted)
    row:Show()
end

local function FillMore(row, more)
    row.step = nil
    row.icon:Hide()
    row.name:SetText(TEXT_MORE:format(more))
    SetColor(row.name, T.muted)
    row.range:SetText("")
    row.crafts:SetText("")
    row.cost:SetText("")
    row:Show()
end

local function Subtitle(plan)
    if plan.atCap then return TEXT_AT_CAP:format(plan.to) end
    if plan.reach < plan.to then
        local stuck = TEXT_STUCK:format(plan.reach)
        if #plan.steps == 0 then return stuck end
        return TEXT_FROM:format(plan.from, plan.to) .. "\n" .. stuck
    end
    return TEXT_FROM:format(plan.from, plan.to)
end

local function FillFooter(plan)
    local points = plan.reach - plan.from
    local empty = #plan.steps == 0
    pane.total:SetShown(not empty)
    if plan.total then
        pane.total:SetText(TEXT_TOTAL:format(points, plan.crafts, Money(plan.total)))
    else
        pane.total:SetText(TEXT_TOTAL_UNPRICED:format(points, plan.crafts))
    end
    pane.note:SetShown(not empty)
    local valued = S.Get("skillUpPlanBest") and TEXT_BEST:format(Prices.LISTED_ENOUGH) or TEXT_VENDOR
    pane.note:SetText(plan.priced and valued or valued .. "\n" .. TEXT_UNPRICED)
    local queue = QueueOn()
    local action = pane.action
    action:SetShown(not empty and (queue or S.Get("shoppingList")) and true or false)
    ns.SetButtonText(action, queue and TEXT_QUEUE or TEXT_LIST)
    local training = Plan.NeedsTraining(plan)
    EnableButton(action, not training)
    action._tipTitle = queue and TEXT_QUEUE or TEXT_LIST
    local doable = Plan.Doable(plan)
    if training then
        action._tipBody = TIP_TRAIN_FIRST
    elseif doable < #plan.steps then
        action._tipBody = (queue and TIP_QUEUE_UPTO or TIP_LIST_UPTO):format(plan.steps[doable + 1].from)
    else
        action._tipBody = queue and TIP_QUEUE_HELP or TIP_LIST_HELP
    end
end

local function Build(mid)
    pane = CreateFrame("Frame", nil, mid)
    pane:SetAllPoints()
    pane.rows = {}
    W.frame.plan = pane
    pane.title = ns.Font(pane, Style.FONT_NAME, nil, T.accent)
    pane.title:SetPoint("TOPLEFT", Style.PANE_EDGE, -Style.PANE_EDGE)
    pane.title:SetText(TEXT_TITLE)
    pane.sub = ns.Font(pane, Style.FONT, nil, T.muted)
    pane.sub:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -SUB_GAP)
    pane.sub:SetWidth(Style.PANE_INNER_W)
    pane.sub:SetJustifyH("LEFT")
    pane.action = ns.Button(pane, TEXT_QUEUE, ACTION_W, Style.BUTTON_H, OnAction)
    pane.action:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    pane.action:SetMotionScriptsWhileDisabled(true)
    ns.Tooltip(pane.action, TEXT_QUEUE, TIP_QUEUE_HELP)
    pane.total = ns.Font(pane, Style.FONT, nil)
    pane.total:SetPoint("LEFT", pane, "BOTTOMLEFT", Style.PANE_EDGE, EDGE + Style.BUTTON_H / 2)
    pane.total:SetPoint("RIGHT", pane.action, "LEFT", -TEXT_GAP, 0)
    pane.total:SetJustifyH("LEFT")
    pane.note = ns.Font(pane, Style.FONT_SMALL, nil, T.muted)
    pane.note:SetPoint("BOTTOMLEFT", pane.action, "TOPLEFT", 0, NOTE_GAP)
    pane.note:SetPoint("LEFT", pane, "LEFT", Style.PANE_EDGE, 0)
    pane.note:SetPoint("RIGHT", pane, "RIGHT", -EDGE, 0)
    pane.note:SetJustifyH("LEFT")
end

function View.Render()
    if not On() then
        Close()
        return false
    end
    local win = W.frame
    win.detail:Hide()
    win.learn:Hide()
    win.empty:Hide()
    if not pane then Build(win.mid) end
    local plan = Plan.Get()
    if not plan then
        Close()
        return false
    end
    pane.sub:SetText(Subtitle(plan))
    local shown = math.min(#plan.steps, MAX_ROWS)
    if #plan.steps > MAX_ROWS then shown = MAX_ROWS - 1 end
    for i = 1, shown do FillRow(pane.rows[i] or NewRow(i), plan.steps[i]) end
    local used = shown
    if shown < #plan.steps then
        used = used + 1
        FillMore(pane.rows[used] or NewRow(used), #plan.steps - shown)
    end
    for i = used + 1, #pane.rows do pane.rows[i]:Hide() end
    FillFooter(plan)
    pane:Show()
    return true
end

local function Toggle()
    W.planOpen = not W.planOpen or nil
    if W.planOpen then Plan.Invalidate() end
    P.Detail.Render()
end

local function PlaceOpener()
    local win = W.frame
    if not win then return end
    local on = On()
    if not on then Close() end
    if not opener then
        if not on then return end
        opener = ns.Button(win, TEXT_TITLE, OPEN_W, OPEN_H, Toggle)
        ns.Tooltip(opener, TEXT_TITLE, TIP_OPEN_HELP)
        opener:Hide()
        TitleButtons.Add(opener, OPEN_ORDER)
    end
    opener:SetShown(on and true or false)
end

hooksecurefunc(P.Window, "Render", PlaceOpener)
