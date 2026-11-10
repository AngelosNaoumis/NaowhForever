-- HomePage.lua: the options window's Home page: a button for every module window, then the features for the player's class.
local ns = _G.NaowhForever
local UI = ns.UI
local O = ns.Options

local CLASS_PAGE = "Home/Class"
local TEXT_WINDOWS = "Open a Window"
local TEXT_CLASS = "Your Class"
local TEXT_OPEN = "Open"

local function OpenClicked(mod)
    local open = ns[mod.open]
    if open then ns.OpenFromOptions(open) end
end

local function WindowRow(mod)
    if not mod then return nil end
    return { type = "button", text = mod.label or mod.name, buttonText = TEXT_OPEN, tooltip = mod.subtitle,
        onClick = function() OpenClicked(mod) end }
end

local function Windows(parent, y)
    local mods = O.Windows()
    if #mods == 0 then return y end
    local W = UI.Widgets
    local _, h = W:SectionHeader(parent, TEXT_WINDOWS, y)
    y = y - h
    for i = 1, #mods, 2 do
        _, h = W:DualRow(parent, y, WindowRow(mods[i]), WindowRow(mods[i + 1]))
        y = y - h
    end
    return y
end

local function ClassResized(host, height)
    if host.building then
        host.resized = height
        return
    end
    if height == host.resized then return end
    host.resized = height
    UI:RefreshPage(true)
end

local function ClassHost(parent)
    local host = parent.classHost
    if host then return host end
    host = CreateFrame("Frame", nil, parent)
    host.onResize = function(height) ClassResized(host, height) end
    parent.classHost = host
    return host
end

local function ClassCards(parent, y)
    local items = O.ClassItems()
    local host = ClassHost(parent)
    host:SetShown(#items > 0)
    if #items == 0 then return y end
    local Settings = ns.Shared.Settings
    local _, h = UI.Widgets:SectionHeader(parent, TEXT_CLASS, y)
    y = y - h
    Settings.Compose(CLASS_PAGE, items)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    host:SetWidth(parent:GetWidth())
    host.building = true
    local height = Settings.Render(host, CLASS_PAGE, host.onResize)
    host.building = false
    host:SetHeight(height)
    return y - height
end

function ns.BuildHomePage(parent, y)
    y = Windows(parent, y)
    return ClassCards(parent, y)
end
