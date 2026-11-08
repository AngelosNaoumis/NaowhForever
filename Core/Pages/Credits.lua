-- Credits.lua: the Credits page in the options window.
local ns = _G.NaowhForever
local T = ns.THEME

local GOLD = { r = 0xe6 / 255, g = 0xcc / 255, b = 0x80 / 255 }
local ICONS = ns.MEDIA .. "Navigation\\"
local PATRONS = ns.FEATURE_BADGES == ns.BADGES_LIVE
local STAFF_TIER = "developer"

local PAD, GAP, LINE_GAP, STRIP, TEXT_DROP = 14, 8, 4, 2, 1
local GLOW, GLOW_ALPHA = 1.3, 0.35
local SECTION_GAP, TITLE_GAP = 18, 8
local LEAD_EMBLEM, LEAD_PAD, LEAD_NAME_SIZE, LEAD_ROLE_SIZE = 44, 20, 18, 10
local STAFF_EMBLEM, STAFF_SIZE = 26, 12
local CHIP_H, CHIP_GAP, CHIP_PAD, CHIP_SIZE = 20, 5, 8, 11
local TILE_ICON, TILE_PAD, TILE_NAME_SIZE, TILE_COLUMNS = 16, 12, 13, 4
local TIER_EMBLEM, TIER_ICON, TIER_PAD, TIER_NAME_SIZE, TIER_LINE_SIZE = 30, 22, 10, 13, 11
local SOURCE_ICON, SOURCE_PAD, SOURCE_NAME_SIZE, SOURCE_LINE_SIZE, SOURCE_LINE_DROP = 14, 6, 12, 11, 1
local SOURCE_COLUMNS, FULL_ROW = 2, 1

local TEXT_STAFF = ns.L("Staff (team)")
local TEXT_ALSO = ns.L("Also: %s")
local TITLE_TEAM, TITLE_CONTRIBUTORS, TITLE_BUILT = "The Team", "Contributors", "Built With"
local TITLE_THANKS, TITLE_SUPPORTERS = "Thank You", "Supporters"

local function Tier(key)
    return ns.BADGE_TIERS and ns.BADGE_TIERS[key]
end

local function Translator(name, language)
    return name .. " " .. ns.Color("muted", ns.L(language))
end

local LEADS = {
    { tier = "naowh", role = "Founder", name = "Naowh" },
    { tier = "developer", role = "Lead Developer", name = "Glyalith" },
}

local STAFF = { "Alloy", "Grim", "Ns", "Tiif", "Zyan", "Snoozer", "WeepDang", "Slash", "Neil" }

local MODULES = {
    { icon = "hammer", name = "Professions", people = { "filipescp96", "Grim", "Korallis", "Hikayuki", "Joshua Helmle", "Angelos" } },
    { icon = "map", name = "Dungeon Journal", people = { "Grim", "Borderline", "Daniil" } },
    { icon = "compass", name = "Discovery", people = { "Grim" } },
    { icon = "checklist", name = "QoL", people = { "Korallis", "Lyssa", "Jacob Biehler", "Borderline" } },
    { icon = "heart", name = "Consumable Bar", people = { "Zyan", "Korallis" } },
    { icon = "aura", name = "AuraBuffs", people = { "Korallis" } },
    { icon = "spark", name = "Blessings", people = { "Borderline", "Kristjan Ingi" } },
    { icon = "bars", name = "Threat Meter", people = { "Lyssa", "Borderline" } },
    { icon = "settings", name = "Settings", people = { "Zyan", "Lyssa", "Kristjan Ingi" } },
    { icon = "search", name = "Racial and Class Tracking", people = { "Jacob Biehler" } },
    { icon = "pen", name = "Macros", people = { "Kristjan Ingi" } },
    { icon = "notes", name = "Translations", people = { Translator("Checkov23", "German"), Translator("chenjonathanzhang-max", "Chinese") } },
}

local ALSO = { "Jok3r", "Cullen Buchanan" }

local ELLESMERE = { tier = "ellesmere", name = "Ellesmere", line = ns.L("Creator of EllesmereUI, for allowing us to add some of EUI's styling and functionality.") }

local THANKS = {
    { tier = "legendary", badges = true, name = ns.L("Legendary Supporters"), line = ns.L("Everyone wearing the Legendary badge: you keep Naowh Forever going.") },
    { tier = "epic", badges = true, name = ns.L("Epic Supporters"), line = ns.L("Everyone wearing the Epic badge: you keep Naowh Forever going too.") },
    { tier = "basic", badges = true, name = ns.L("Basic Supporters"), line = ns.L("Everyone wearing the Basic badge: you keep Naowh Forever going too.") },
    { icon = "checklist", name = ns.L("Beta Testers"), line = ns.L("Every bug report and screenshot made it better.") },
}

local LIBRARIES = { "LibStub", "CallbackHandler-1.0", "LibDataBroker-1.1", "LibDBIcon-1.0", "LibSharedMedia-3.0",
    "LibCustomGlow-1.0", "LibDeflate", "LibSerialize" }

local DATA = {
    { icon = "search", name = "Wowhead", line = ns.L("WoW Forever's items, quests and NPCs, and what is new in Forever.") },
    { icon = "trophy", name = "wowsrc.com", line = ns.L("The BiS rankings behind the BiS List.") },
    { icon = "bars", name = "WoWSims", line = ns.L("The stat weights each spec starts with.") },
    { icon = "map", name = "Santiago Reyes", line = ns.L("For his maps of the new Forever dungeons.") },
    { icon = "map", name = "tr0tsky", line = ns.L("Ley lines and Elemental Convergences behind Skyborne Spots, from the Skyborne Ley Line & Convergence Marker addon.") },
    { icon = "search", name = "CMaNGOS", line = ns.L("The classic creature database behind Scout's abilities, armor, immunities and tameable beasts.") },
    { icon = "notes", name = "12dicts and ENABLE", line = ns.L("Alan Beale's 12dicts and the ENABLE word list, the public-domain words behind the Daily Word.") },
    { icon = "hammer", name = ns.L("Libraries"), line = table.concat(LIBRARIES, ", ") },
}

local TEXT_ALSO_NAMES = TEXT_ALSO:format(table.concat(ALSO, ", "))

local function Smooth(texture, path)
    texture:SetTexture(path, nil, nil, "TRILINEAR")
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    return texture
end

local function NewEmblem(frame)
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetBlendMode("ADD")
    local art = frame:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("CENTER", art, "CENTER")
    art.glow = glow
    return art
end

local function SetEmblem(art, tier, size)
    art:SetShown(tier ~= nil)
    art.glow:SetShown(tier ~= nil)
    if not tier then return end
    art:SetSize(size, size)
    Smooth(art, tier.large)
    art:SetVertexColor(1, 1, 1, 1)
    art.glow:SetSize(size * GLOW, size * GLOW)
    Smooth(art.glow, tier.large)
    art.glow:SetVertexColor(tier.color.r, tier.color.g, tier.color.b, GLOW_ALPHA)
end

local function NewCard(view)
    local card = CreateFrame("Frame", nil, view)
    local St = ns.Shared.Style
    ns.Solid(card, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    return card
end

local function NewChips(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder.chips = {}
    return holder
end

local function Chip(holder, i)
    local chip = holder.chips[i]
    if not chip then
        chip = CreateFrame("Frame", nil, holder)
        chip:SetHeight(CHIP_H)
        ns.Solid(chip, "BACKGROUND", T.panel, 1):SetAllPoints()
        ns.Border(chip, ns.Shared.Style.BORDER_RGB)
        chip.text = ns.Font(chip, CHIP_SIZE, nil, T.fg)
        chip.text:SetPoint("CENTER", 0, -TEXT_DROP)
        holder.chips[i] = chip
    end
    return chip
end

local function SetChips(holder, names, width)
    local x, y = 0, 0
    for i, name in ipairs(names) do
        local chip = Chip(holder, i)
        chip.text:SetText(name)
        local w = math.ceil(chip.text:GetStringWidth()) + CHIP_PAD * 2
        if x > 0 and x + w > width then
            x, y = 0, y + CHIP_H + CHIP_GAP
        end
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", x, -y)
        chip:Show()
        x = x + w + CHIP_GAP
    end
    for i = #names + 1, #holder.chips do holder.chips[i]:Hide() end
    local height = y + CHIP_H
    holder:SetSize(math.max(1, width), height)
    return height
end

local function NewBand(view)
    local band = NewCard(view)
    band.leads = {}
    for i = 1, #LEADS do
        local cell = { art = NewEmblem(band) }
        cell.name = ns.Font(band, LEAD_NAME_SIZE, nil, T.fg, true)
        cell.role = ns.Font(band, LEAD_ROLE_SIZE, nil, T.fg)
        cell.role:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -LINE_GAP)
        cell.divider = ns.Hairline(ns.Solid(band, "ARTWORK", T.line, 1), "v")
        band.leads[i] = cell
    end
    band.staff = NewEmblem(band)
    band.staffName = ns.Font(band, STAFF_SIZE, nil, T.fg)
    band.staffName:SetPoint("LEFT", band.staff, "RIGHT", GAP, -TEXT_DROP)
    band.names = NewChips(band)
    return band
end

local function SetBand(band)
    local x = 0
    for i, lead in ipairs(LEADS) do
        local cell = band.leads[i]
        local tier = Tier(lead.tier)
        local color = tier and tier.color or T.accentSoft
        SetEmblem(cell.art, tier, LEAD_EMBLEM)
        cell.art:SetPoint("CENTER", band, "LEFT", x + LEAD_PAD + LEAD_EMBLEM / 2, 0)
        cell.name:SetText(lead.name)
        cell.name:SetTextColor(color.r, color.g, color.b, 1)
        cell.role:SetText(ns.Upper(ns.L(lead.role)))
        cell.role:SetTextColor(color.r, color.g, color.b, 1)
        local left = x + LEAD_PAD + LEAD_EMBLEM + GAP
        local block = cell.name:GetStringHeight() + LINE_GAP + cell.role:GetStringHeight()
        cell.name:ClearAllPoints()
        cell.name:SetPoint("TOPLEFT", band, "LEFT", left, block / 2)
        x = left + math.max(cell.name:GetStringWidth(), cell.role:GetStringWidth()) + LEAD_PAD
        cell.divider:ClearAllPoints()
        cell.divider:SetPoint("TOPLEFT", band, "TOPLEFT", x, 0)
        cell.divider:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", x, 0)
    end
    local tier = Tier(STAFF_TIER)
    local color = tier and tier.color or T.accentSoft
    SetEmblem(band.staff, tier, STAFF_EMBLEM)
    band.staff:SetPoint("CENTER", band, "LEFT", x + LEAD_PAD + STAFF_EMBLEM / 2, 0)
    band.staffName:SetText(TEXT_STAFF)
    band.staffName:SetTextColor(color.r, color.g, color.b, 1)
    local left = x + LEAD_PAD + STAFF_EMBLEM + GAP + band.staffName:GetStringWidth() + LEAD_PAD
    local height = SetChips(band.names, STAFF, band:GetWidth() - left - PAD)
    band.names:SetPoint("LEFT", band, "LEFT", left, 0)
    return math.max(LEAD_EMBLEM, height) + 2 * PAD
end

local function NewModule(view)
    local card = NewCard(view)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(TILE_ICON, TILE_ICON)
    card.icon:SetPoint("TOPLEFT", TILE_PAD, -TILE_PAD)
    card.name = ns.Font(card, TILE_NAME_SIZE, nil, T.fg)
    card.name:SetPoint("LEFT", card.icon, "RIGHT", GAP, -TEXT_DROP)
    card.people = NewChips(card)
    card.people:SetPoint("TOPLEFT", TILE_PAD, -(TILE_PAD + TILE_ICON + GAP))
    return card
end

local function SetModule(card, mod, w)
    Smooth(card.icon, ICONS .. mod.icon .. ".tga")
    card.icon:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, 1)
    card.name:SetText(ns.L(mod.name))
    local height = SetChips(card.people, mod.people, w - 2 * TILE_PAD)
    return TILE_PAD + TILE_ICON + GAP + height + TILE_PAD
end

local function NewTier(view)
    local card = NewCard(view)
    card.strip = card:CreateTexture(nil, "ARTWORK")
    card.strip:SetPoint("TOPLEFT")
    card.strip:SetPoint("BOTTOMLEFT")
    card.strip:SetWidth(STRIP)
    card.art = NewEmblem(card)
    card.art:SetPoint("CENTER", card, "LEFT", TIER_PAD + TIER_EMBLEM / 2, 0)
    card.name = ns.Font(card, TIER_NAME_SIZE, nil, T.fg)
    card.line = ns.Font(card, TIER_LINE_SIZE, nil, T.muted)
    card.line:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -LINE_GAP)
    card.line:SetJustifyH("LEFT")
    card.line:SetWordWrap(true)
    return card
end

local function SetTier(card, entry, w)
    local tier = entry.tier and Tier(entry.tier)
    local color = tier and tier.color or T.accentSoft
    card.strip:SetColorTexture(color.r, color.g, color.b, 1)
    SetEmblem(card.art, tier, TIER_EMBLEM)
    if not tier then
        card.art:Show()
        card.art:SetSize(TIER_ICON, TIER_ICON)
        Smooth(card.art, ICONS .. entry.icon .. ".tga")
        card.art:SetVertexColor(color.r, color.g, color.b, 1)
    end
    card.name:SetText(entry.name)
    card.name:SetTextColor(color.r, color.g, color.b, 1)
    local left = TIER_PAD + TIER_EMBLEM + TIER_PAD
    card.line:SetWidth(math.max(1, w - left - TIER_PAD))
    card.line:SetText(entry.line)
    local block = card.name:GetStringHeight() + LINE_GAP + card.line:GetStringHeight()
    card.name:ClearAllPoints()
    card.name:SetPoint("TOPLEFT", card, "LEFT", left, block / 2)
    return math.max(TIER_EMBLEM, block) + 2 * TIER_PAD
end

local function NewSource(view)
    local row = CreateFrame("Frame", nil, view)
    row.name = ns.Font(row, SOURCE_NAME_SIZE, nil, GOLD)
    row.name:SetPoint("TOPLEFT", SOURCE_ICON + GAP, -SOURCE_PAD)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(SOURCE_ICON, SOURCE_ICON)
    row.icon:SetPoint("RIGHT", row.name, "LEFT", -GAP, -TEXT_DROP)
    row.line = ns.Font(row, SOURCE_LINE_SIZE, nil, T.muted)
    row.line:SetPoint("TOPLEFT", row.name, "TOPRIGHT", GAP, -SOURCE_LINE_DROP)
    row.line:SetJustifyH("LEFT")
    row.line:SetWordWrap(true)
    row.rule = ns.Hairline(ns.Solid(row, "ARTWORK", T.line, 1), "h")
    row.rule:SetPoint("BOTTOMLEFT")
    row.rule:SetPoint("BOTTOMRIGHT")
    return row
end

local function SetSource(row, source, w)
    Smooth(row.icon, ICONS .. source.icon .. ".tga")
    row.icon:SetVertexColor(GOLD.r, GOLD.g, GOLD.b, 1)
    row.name:SetText(source.name)
    row.line:SetWidth(math.max(1, w - SOURCE_ICON - GAP - row.name:GetStringWidth() - GAP))
    row.line:SetText(source.line)
    return math.max(row.name:GetStringHeight(), row.line:GetStringHeight() + SOURCE_LINE_DROP) + 2 * SOURCE_PAD
end

local kinds, view
local NO_EVENTS = {}

local Draw = {}

function Draw:DrawCard(entry, kind, _, _, x, w)
    self.left, self.width = x, w
    local card = self:Acquire(kind)
    local height = kinds[kind].Set(card, entry, w)
    self.left, self.width = 0, self:GetWidth()
    return card, height
end

function Draw:Redraw()
    self:Clear()
    self:Section(TITLE_TEAM)
    self:Space(TITLE_GAP)
    self:Add("band")
    self:Space(SECTION_GAP)
    self:Section(TITLE_CONTRIBUTORS)
    self:Space(TITLE_GAP)
    for _, mod in ipairs(MODULES) do self:Gather(mod, "module") end
    self:DrawGrid(nil, TILE_COLUMNS)
    self:Note(TEXT_ALSO_NAMES)
    self:Space(SECTION_GAP)
    self:Section(PATRONS and TITLE_SUPPORTERS or TITLE_THANKS)
    self:Space(TITLE_GAP)
    self:Gather(ELLESMERE, "tier")
    self:DrawGrid(nil, FULL_ROW)
    local shown = 0
    for _, entry in ipairs(THANKS) do
        if PATRONS or not entry.badges then
            self:Gather(entry, "tier")
            shown = shown + 1
        end
    end
    self:DrawGrid(nil, shown)
    self:Space(SECTION_GAP)
    self:Section(TITLE_BUILT)
    self:Space(TITLE_GAP)
    for _, source in ipairs(DATA) do self:Gather(source, "source") end
    self:DrawGrid(SOURCE_COLUMNS)
    self:Fit(NO_EVENTS)
end

local function Kinds()
    if kinds then return kinds end
    kinds = ns.Shared.View.NewKinds()
    kinds.band = { New = NewBand, Set = SetBand }
    kinds.module = { New = NewModule, Set = SetModule }
    kinds.tier = { New = NewTier, Set = SetTier }
    kinds.source = { New = NewSource, Set = SetSource }
    return kinds
end

function ns.BuildCreditsPage(parent, y)
    view = parent.creditsView
    if not view then
        view = ns.Shared.View.New(parent, Kinds(), Draw)
        parent.creditsView = view
    end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI.CONTENT_PAD, y - ns.UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - ns.UI.CONTENT_PAD * 2))
    view:Show()
    view:Redraw()
    return y - view:GetHeight() - ns.UI.CONTENT_PAD
end
