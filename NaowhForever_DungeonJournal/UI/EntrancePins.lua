-- EntrancePins.lua: the dungeon and raid entrances as pins on the world map.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local PERCENT = J.C.PERCENT
local St = J.Style
local KIND_RGB, NAME_RGB, HINT_RGB = St.ENTRANCE_KIND_RGB, St.GOLD_NAME_RGB, St.ENTRANCE_HINT_RGB
local OpenMap = ns.Shared.OpenMap

local TEMPLATE = "NaowhForeverEntrancePinTemplate"
local PIN_SIZE = 18
local MAP_COSMIC, MAP_WORLD, MAP_CONTINENT = 0, 1, 2
local ZONE_SIZE, CONTINENT_SIZE, WORLD_SIZE = 1, 0.75, 0.6
local WORLD_POS_RETURN = 2
local ICON = "dungeon"
local RAID_ICON = "raid"
local FRAME_LEVEL = "PIN_FRAME_LEVEL_AREA_POI"
local SPOT_KEY = "%s:%s:%s"

local TEXT_ENTRANCE_NAME = ns.L("Entrance")
local TEXT_RAID = ns.L("Raid, %d players")
local TEXT_DUNGEON = ns.L("Dungeon")
local TEXT_KIND_LEVELS = "%s, %s"
local TEXT_CLICK = ns.L("Click for a waypoint (again to remove it).")
local TEXT_RIGHT = ns.L("Right-click: open its map.")
local TEXT_RIGHT_MANY = ns.L("Right-click: choose one and open its map.")
local TEXT_ENTRANCE = ns.L(" (entrance)")

local provider, added, events
local spots = {}
local waitingForMap = false

local function On()
    return S.Get("enabled") and S.Get("mapEntrances")
end

local function PinSize(map)
    local info = C_Map.GetMapInfo(map:GetMapID())
    local kind = info and info.mapType
    local step = (kind == MAP_COSMIC or kind == MAP_WORLD) and WORLD_SIZE
        or kind == MAP_CONTINENT and CONTINENT_SIZE or ZONE_SIZE
    return PIN_SIZE * step * (S.Get("mapEntranceScale") or 1)
end

local function OnMap(px, py)
    return px >= 0 and px <= 1 and py >= 0 and py <= 1
end

local function FindSpot(mapID, entrance)
    local x, y = entrance.x / PERCENT, entrance.y / PERCENT
    if entrance.map == mapID then return { x, y } end
    local continent, world = C_Map.GetWorldPosFromMapPos(entrance.map, CreateVector2D(x, y))
    local pos = continent and world and select(WORLD_POS_RETURN, C_Map.GetMapPosFromWorldPos(continent, world, mapID))
    if not pos then return false end
    local px, py = pos:GetXY()
    if OnMap(px, py) then return { px, py } end
    return false
end

local function SpotOn(map, mapID, entrance)
    if entrance.map ~= mapID and OpenMap.On() then
        return OpenMap.Spot(map, entrance.map, entrance.x / PERCENT, entrance.y / PERCENT)
    end
    local known = spots[mapID]
    if not known then
        known = {}
        spots[mapID] = known
    end
    local spot = known[entrance]
    if spot == nil then
        spot = FindSpot(mapID, entrance)
        known[entrance] = spot
    end
    if spot then return spot[1], spot[2] end
end

local function AllRaids(dungeons)
    for _, dungeon in ipairs(dungeons) do
        if not dungeon.raid then return false end
    end
    return true
end

local function KindText(dungeon)
    local levels = J.ColoredLevelRange(dungeon)
    local kind = dungeon.raid and TEXT_RAID:format(dungeon.raid) or TEXT_DUNGEON
    return levels and TEXT_KIND_LEVELS:format(kind, levels) or kind
end

local function GroupName(dungeons, fallback)
    return #dungeons == 1 and dungeons[1].name or dungeons[1].zone or fallback
end

local function OpenDungeon(dungeon, group)
    GameTooltip:Hide()
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    if J.ShowDungeonBesideMap and J.ShowDungeonBesideMap(dungeon, group) then return end
    if J.Maps[dungeon.key] then J.ShowMapOnWorldMap(dungeon) end
end

local function OpenJournal(pin)
    local dungeons = pin.group.dungeons
    if not dungeons[1] then return end
    if not dungeons[2] then
        OpenDungeon(dungeons[1], dungeons)
        return
    end
    ns.ContextMenu(pin, function(_, root)
        root:CreateTitle(GroupName(dungeons, TEXT_ENTRANCE_NAME))
        for i = 1, #dungeons do
            local dungeon = dungeons[i]
            root:CreateButton(dungeon.name, function() OpenDungeon(dungeon, dungeons) end)
        end
    end)
end

local function MakePinMixin()
    NaowhForeverEntrancePinMixin = CreateFromMixins(MapCanvasPinMixin)
    local Pin = NaowhForeverEntrancePinMixin
    Pin.ApplyCurrentScale = ns.Shared.ScalePin

    function Pin:OnLoad()
        self:UseFrameLevelType(FRAME_LEVEL)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    function Pin:CheckMouseButtonPassthrough() end

    function Pin:OnAcquired(group)
        ns.Shared.PinClicks(self)
        self.group = group
        local size = PinSize(self:GetMap())
        self:SetSize(size, size)
        if not (AllRaids(group.dungeons) and self.Icon:SetAtlas(RAID_ICON)) then self.Icon:SetAtlas(ICON) end
        self:SetPosition(group.x, group.y)
        self:ApplyCurrentScale()
    end

    function Pin:OnMouseEnter()
        local dungeons = self.group.dungeons
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(GroupName(dungeons, TEXT_ENTRANCE_NAME), 1, 1, 1)
        for _, dungeon in ipairs(dungeons) do
            local right = KindText(dungeon)
            if #dungeons == 1 then
                GameTooltip:AddLine(right, KIND_RGB.r, KIND_RGB.g, KIND_RGB.b)
            else
                GameTooltip:AddDoubleLine(dungeon.name, right, NAME_RGB.r, NAME_RGB.g, NAME_RGB.b,
                    KIND_RGB.r, KIND_RGB.g, KIND_RGB.b)
            end
        end
        local c = ns.ThemeTint("accentSoft", nil) or HINT_RGB
        GameTooltip:AddLine(TEXT_CLICK, c.r, c.g, c.b)
        if S.Get("entranceJournal") then
            GameTooltip:AddLine(#dungeons > 1 and TEXT_RIGHT_MANY or TEXT_RIGHT, c.r, c.g, c.b)
        end
        GameTooltip:Show()
    end

    function Pin:OnMouseLeave()
        GameTooltip:Hide()
    end

    function Pin:OnClick(button)
        if button == "RightButton" then
            if S.Get("entranceJournal") then OpenJournal(self) end
            return
        end
        if button ~= "LeftButton" then return end
        local dungeons = self.group.dungeons
        local entrance = dungeons[1].entrance
        ns.ToggleWaypoint(GroupName(dungeons, dungeons[1].name), entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE, nil, true)
    end
end

local function GroupBySpot(map, mapID, groups, bySpot, dungeon)
    local entrance = dungeon.entrance
    if not (entrance and J.FactionShown(dungeon)) then return end
    local x, y = SpotOn(map, mapID, entrance)
    if not x then return end
    local key = SPOT_KEY:format(entrance.map, entrance.x, entrance.y)
    local group = bySpot[key]
    if not group then
        group = { x = x, y = y, dungeons = {} }
        bySpot[key] = group
        groups[#groups + 1] = group
    end
    group.dungeons[#group.dungeons + 1] = dungeon
end

local function MakeProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        if not On() then return end
        local map = self:GetMap()
        local mapID = map:GetMapID()
        if not mapID then return end
        local groups, bySpot = {}, {}
        for _, dungeon in ipairs(J.Dungeons()) do GroupBySpot(map, mapID, groups, bySpot, dungeon) end
        for _, group in ipairs(groups) do map:AcquirePin(TEMPLATE, group) end
    end
end

local function Redraw()
    if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

local function Event(_, event)
    if event == "PLAYER_REGEN_ENABLED" then events:UnregisterEvent(event) end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Redraw()
end

local function Resize()
    if not (added and WorldMapFrame:IsShown()) then return end
    for pin in WorldMapFrame:EnumeratePinsByTemplate(TEMPLATE) do
        local size = PinSize(WorldMapFrame)
        pin:SetSize(size, size)
    end
end

local function Setup()
    MakePinMixin()
    MakeProvider()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Event)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        Redraw()
        return
    end
    if not WorldMapFrame then
        if not waitingForMap then
            waitingForMap = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Apply)
        end
        return
    end
    if not provider then Setup() end
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        Redraw()
    end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "mapEntrances" or key == "showAlliance" or key == "showHorde" then
        Apply()
    elseif key == "mapEntranceScale" then
        Resize()
    end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
