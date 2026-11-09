-- Rail.lua: The Market window's left rail: a row per page with its count, and your gathering skills under them (Market.Rail).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts

local ROW_H, ROW_IN, ICON, LABEL_X, MARKER_W = 40, 16, 18, 46, 2
local FOREVER_ROW_H, FOREVER_DROP = 48, 3
local SUB_GAP = 1
local OFF_ALPHA, OFF_ICON_ALPHA = 0.7, 0.5
local SKILLS_IN, SKILLS_TOP, SKILLS_HEAD_GAP = 16, 14, 10
local SKILL_ICON, SKILL_GAP, SKILL_ROW_H, SKILL_BAR_H, SKILL_BAR_GAP = 18, 8, 32, 4, 5
local LABEL_SIZE, COUNT_SIZE, HEAD_SIZE, SKILL_SIZE = 14, 12, 12, 13
local NAV_ICONS = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\"
local SKILLS = {
    { kind = "herb", name = ns.L("Herbalism"), icon = "Interface\\Icons\\Trade_Herbalism" },
    { kind = "ore", name = ns.L("Mining"), icon = "Interface\\Icons\\Trade_Mining" },
    { kind = "skin", name = ns.L("Skinning"), icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { kind = "fish", name = ns.L("Fishing"), icon = "Interface\\Icons\\Trade_Fishing" },
}
local TEXT_SKILLS = ns.L("Your gathering")
local TEXT_AWAY = ns.L("At an auctioneer")
local TEXT_UNLEARNED = ns.L("Not learned")
local TEXT_RANK = "%d / %d"

local Rail = {}
Market.Rail = Rail

local rows, skillRows = {}, {}
local shownKey, atAuction

local function PaintRow(row, hover)
    local active = row.key == shownKey
    local dim = row.off and not active and not hover
    local c = (active or hover) and T.fg or T.muted
    row.label:SetTextColor(c.r, c.g, c.b, dim and OFF_ALPHA or 1)
    if row.icon then
        local i = active and T.accentSoft or c
        row.icon:SetVertexColor(i.r, i.g, i.b, dim and OFF_ICON_ALPHA or 1)
    end
    row.fill:SetShown(active)
    row.marker:SetShown(active and not row.forever)
    row.hover:SetShown(hover and not active)
    if row.forever then Parts.PaintForeverNav(row, active, hover) end
end

local function Count(key)
    if key == "sell" then
        local left = Market.Sell.Left()
        return left > 0 and left or nil
    end
    if key == "mine" then
        local undercut = Market.Auctions.Counts()
        if undercut > 0 then return undercut, St.WARN_RGB end
        local total = #Market.Auctions.list
        return total > 0 and total or nil
    end
end

local function DrawRow(row)
    row.off = row.auction and not atAuction
    row.label:ClearAllPoints()
    if row.off then
        row.label:SetPoint("BOTTOMLEFT", row, "LEFT", row.x, SUB_GAP - row.drop)
    else
        row.label:SetPoint("LEFT", row.x, 0)
    end
    row.sub:SetShown(row.off)
    local count, color = nil, nil
    if not row.off then count, color = Count(row.key) end
    local c = color or T.muted
    row.count:SetTextColor(c.r, c.g, c.b)
    row.count:SetText(count or "")
    PaintRow(row, row:IsMouseOver())
end

local function NewRow(parent, page, y, h, onPick)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(h)
    row.key, row.auction = page.key, page.auction
    row.fill = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.fill:SetAllPoints()
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.TAB_HOVER_FILL)
    row.hover:SetAllPoints()
    row.marker = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.marker:SetPoint("TOPLEFT")
    row.marker:SetPoint("BOTTOMLEFT")
    row.marker:SetWidth(MARKER_W)
    if ns.foreverSkin then
        Parts.ForeverNavButton(row)
        row.x, row.drop = ROW_IN, FOREVER_DROP
    else
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("LEFT", ROW_IN, 0)
        row.icon:SetTexture(NAV_ICONS .. page.icon .. ".tga")
        row.x, row.drop = LABEL_X, 0
    end
    row.label = ns.Font(row, LABEL_SIZE, nil, T.muted, true)
    row.label:SetText(ns.L(page.label))
    row.sub = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.sub:SetPoint("TOPLEFT", row, "LEFT", row.x, -SUB_GAP - row.drop)
    row.sub:SetText(TEXT_AWAY)
    row.count = ns.Font(row, COUNT_SIZE, nil, T.muted)
    row.count:SetPoint("RIGHT", -ROW_IN, 0)
    row:SetScript("OnClick", function() onPick(page.key) end)
    row:SetScript("OnEnter", function(self) PaintRow(self, true) end)
    row:SetScript("OnLeave", function(self) PaintRow(self, false) end)
    ns.Tooltip(row, page.label, page.tip)
    return row
end

local function Rank(index, line)
    if not index then return end
    local _, _, rank, max, _, _, skillLine, modifier = GetProfessionInfo(index)
    if skillLine == line then return rank + (modifier or 0), max end
end

local function Skill(kind)
    local G = ns.Glimmer
    local line = G and G.C.PROFESSION_OF[kind]
    local first, second, _, fishing = GetProfessions()
    local rank, max = Rank(first, line)
    if not rank then rank, max = Rank(second, line) end
    if not rank then rank, max = Rank(fishing, line) end
    return rank, max
end

local function NewSkill(parent, skill, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", SKILLS_IN, -y)
    row:SetPoint("TOPRIGHT", -SKILLS_IN, -y)
    row:SetHeight(SKILL_ROW_H)
    row.kind = skill.kind
    row.icon = Parts.ItemIcon(row, SKILL_ICON)
    row.icon:SetPoint("TOPLEFT")
    row.icon.texture:SetTexture(skill.icon)
    row.name = ns.Font(row, SKILL_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", SKILL_GAP, 0)
    row.name:SetText(skill.name)
    row.rank = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.rank:SetPoint("RIGHT", row, "TOPRIGHT", 0, -SKILL_ICON / 2)
    row.bar = ns.Solid(row, "ARTWORK", T.grey, 1)
    row.bar:SetPoint("TOPLEFT", row.icon, "BOTTOMRIGHT", SKILL_GAP, -SKILL_BAR_GAP)
    row.bar:SetPoint("RIGHT")
    row.bar:SetHeight(SKILL_BAR_H)
    row.fill = ns.Solid(row, "OVERLAY", T.muted, 1)
    row.fill:SetPoint("TOPLEFT", row.bar)
    row.fill:SetHeight(SKILL_BAR_H)
    return row
end

local function DrawSkill(row)
    local rank, max = Skill(row.kind)
    row.rank:SetText(rank and TEXT_RANK:format(rank, max) or TEXT_UNLEARNED)
    row.icon:SetAlpha(rank and 1 or OFF_ICON_ALPHA)
    local share = rank and max > 0 and math.min(1, rank / max) or 0
    row.fill:SetWidth(math.max(1, (St.RAIL_W - 2 * SKILLS_IN - SKILL_ICON - SKILL_GAP) * share))
    row.fill:SetShown(share > 0)
end

function Rail.Build(parent, pages, onPick)
    local rail = CreateFrame("Frame", nil, parent)
    rail:SetWidth(St.RAIL_W)
    ns.Solid(rail, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    local edge = ns.Solid(rail, "BORDER", T.line, 1)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    local h = ns.foreverSkin and FOREVER_ROW_H or ROW_H
    for i, page in ipairs(pages) do rows[i] = NewRow(rail, page, ROW_IN / 2 + (i - 1) * h, h, onPick) end
    local skills = CreateFrame("Frame", nil, rail)
    skills:SetPoint("BOTTOMLEFT")
    skills:SetPoint("BOTTOMRIGHT")
    local line = ns.Solid(skills, "BORDER", T.line, 1)
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    local head = ns.Font(skills, HEAD_SIZE, nil, T.muted)
    head:SetPoint("TOPLEFT", SKILLS_IN, -SKILLS_TOP)
    head:SetText(TEXT_SKILLS)
    local y = SKILLS_TOP + HEAD_SIZE + SKILLS_HEAD_GAP
    for i, skill in ipairs(SKILLS) do
        skillRows[i] = NewSkill(skills, skill, y)
        y = y + SKILL_ROW_H
    end
    skills:SetHeight(y)
    return rail
end

function Rail.Paint(key, auction)
    shownKey, atAuction = key, auction
    for _, row in ipairs(rows) do DrawRow(row) end
    for _, row in ipairs(skillRows) do DrawSkill(row) end
end
