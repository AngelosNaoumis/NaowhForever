-- Run with Lua 5.1 from the repository root: Shared/UI/Menus.lua, every Naowh right-click menu and dropdown, on
-- stubs. With keyboard and mouse it hands the generator to the game's MenuUtil and Menu manager unchanged. Under
-- the Gamepad interface style it opens none of the game's menus (they run the menu's close tainted and the gamepad
-- action bar's protected call is then forbidden): Naowh's own list shows titles, dividers, buttons, submenus with
-- a Back row, radios and checkboxes, keeps the game's responses (a checkbox stays open, a radio or button closes,
-- MenuResponse.Open keeps it open), skips disabled rows, shows a row's tooltip, splits a long list into columns,
-- is made parentless then parented to the owner's top window, and closes on a click elsewhere. It holds the
-- gamepad like a window (B goes back a level, then closes) and a right-click menu opens under the gamepad's
-- focus. Group Inspect adds to the game's unit menus only off the style. No Naowh file but this one calls
-- MenuUtil or Menu.GetManager.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end

local function Region(kind)
    local r = { kind = kind, shown = kind ~= "Frame" and kind ~= "Button", scripts = {}, events = {}, h = 0, w = 0 }
    function r:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
    function r:SetShown(on) if on then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:SetScript(name, fn) self.scripts[name] = fn end
    function r:GetScript(name) return self.scripts[name] end
    function r:SetParent(p) self.parent = p end
    function r:GetParent() return rawget(self, "parent") end
    function r:SetHeight(h) self.h = h end
    function r:GetHeight() return self.h end
    function r:SetWidth(w) self.w = w end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetPoint(...) self.point = { ... } end
    function r:ClearAllPoints() self.point = nil end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:GetStringWidth() return #(self.text or "") * 6 end
    function r:SetTextColor(cr, cg, cb) self.color = { cr, cg, cb } end
    function r:SetTexture(t) self.texture = t end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:UnregisterEvent(e) self.events[e] = nil end
    function r:IsMouseOver() return self.over == true end
    function r:GetEffectiveScale() return 1 end
    function r:CreateTexture() return Region("Texture") end
    function r:CreateFontString() return Region("FontString") end
    return setmetatable(r, { __index = function() return NOTHING end })
end

local made = {}
local UIParent = Region("Frame")
UIParent.shown = true
UIParent.h = 1000
local tooltip = Region("Frame")
function tooltip:SetOwner(owner) self.owner = owner end
local gamepad = false
local game = { contexts = 0, opened = 0 }

local env = setmetatable({
    UIParent = UIParent, GameTooltip = tooltip,
    CreateFrame = function(kind, _, parent)
        local f = Region(kind)
        f.parent = parent
        made[#made + 1] = { frame = f, parent = parent }
        return f
    end,
    GetCursorPosition = function() return 300, 400 end,
    MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 },
    MenuUtil = {
        CreateContextMenu = function(owner, generator)
            game.contexts = game.contexts + 1
            game.owner, game.generator = owner, generator
            return "game menu"
        end,
        CreateRootMenuDescription = function()
            return { SetScrollMode = function(self, h) self.height = h end }
        end,
    },
    MenuVariants = { GetDefaultMenuMixin = NOTHING },
    AnchorUtil = { CreateAnchor = function(...) return { ... } end },
    Menu = { GetManager = function()
        return {
            OpenMenu = function(_, owner, desc, anchor)
                game.opened = game.opened + 1
                game.dropOwner, game.desc, game.anchor = owner, desc, anchor
                return "game dropdown"
            end,
            IsAnyMenuOpen = function() return false end,
        }
    end },
}, { __index = _G })

local pad = {}
local T = { bg = {}, fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, line = {}, accent = {} }
local ns = {
    THEME = T, L = function(s) return s end,
    GamepadStandDown = function() return gamepad end,
    PadWindow = function(frame, spec) pad.frame, pad.spec = frame, spec end,
    PadFocus = function() return pad.focus end,
    PadPressFocus = function() return pad.pressing and pad.focus end,
    Font = function(parent) return parent:CreateFontString() end,
    Solid = function(parent) return parent:CreateTexture() end,
    Border = function() return {} end,
    Hairline = NOTHING,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { Arrow = function(p) return p:CreateTexture() end } },
}
env._G = { NaowhForever = ns }
local chunk = assert(loadfile("Shared/UI/Menus.lua"))
setfenv(chunk, env)
chunk()

-- Keyboard and mouse: the game's menus, unchanged.
local window = Region("Frame")
window.parent = UIParent
local owner = Region("Button")
owner.parent = window
local function Generator(_, root) root:CreateButton("A", NOTHING) end
check("a context menu with keyboard and mouse is the game's",
    ns.ContextMenu(owner, Generator) == "game menu" and game.owner == owner and game.generator == Generator)
local filled
check("a dropdown with keyboard and mouse is the game's, under its owner and as tall as asked",
    ns.DropdownMenu(owner, function(desc) filled = desc end, 300) == "game dropdown"
    and game.dropOwner == owner and filled == game.desc and game.desc.height == 300
    and game.anchor[1] == "TOPLEFT" and game.anchor[2] == owner and game.anchor[3] == "BOTTOMLEFT")
check("nothing of Naowh's own list is made with keyboard and mouse", #made == 0 and not ns.MenuOpen())

-- Under the Gamepad interface style: Naowh's own list.
gamepad = true
game.contexts, game.opened = 0, 0
local log = {}
local checked, picked = false, "b"
local function Fill(_, root)
    root:CreateTitle("Title")
    root:CreateButton("Run", function(data) log[#log + 1] = "run " .. tostring(data) end, 7)
    local off = root:CreateButton("Off", function() log[#log + 1] = "off" end)
    off:SetEnabled(false)
    off:SetTooltip(function(tip, e) tip.said = e.text end)
    root:CreateDivider()
    root:CreateCheckbox("Check", function() return checked end, function() checked = not checked end)
    root:CreateRadio("Pick A", function(v) return picked == v end, function(v) picked = v end, "a")
    root:CreateRadio("Pick B", function(v) return picked == v end, function(v) picked = v end, "b")
    local more = root:CreateButton("More")
    more:CreateButton("Deep", function() log[#log + 1] = "deep" end)
    more:CreateButton("Stay", function() log[#log + 1] = "stay"; return env.MenuResponse.Open end)
end

local handle = ns.ContextMenu(owner, Fill)
local list = handle and made[1] and made[1].frame
check("under the style no game menu opens", game.contexts == 0 and game.opened == 0)
check("the list is made parentless", made[1].parent == nil)
local parentless = true
for i = 2, #made do
    if made[i].parent ~= nil then parentless = false end
end
check("every row is made parentless too", parentless)
check("then parented to the owner's top window", list.parent == window)
check("it is open, and says so", list:IsShown() and ns.MenuOpen() and handle:IsShown())
check("it opens at the cursor", list.point and list.point[1] == "TOPLEFT" and list.point[4] == 300 and list.point[5] == 400)
check("it closes on a click elsewhere only while open", list.events.GLOBAL_MOUSE_DOWN == true)

local function Rows()
    local out = {}
    for _, m in ipairs(made) do
        local f = m.frame
        if f.kind == "Button" and f.parent == list and f:IsShown() then out[#out + 1] = f end
    end
    return out
end
local function Row(text)
    for _, r in ipairs(Rows()) do
        if r.element and r.element.text == text then return r end
    end
end
local function Click(text) local r = Row(text); r.scripts.OnClick(r, "LeftButton") end

check("it lists every element in order",
    #Rows() == 8 and Row("Title") and Row("Run") and Row("Off") and Row("Check") and Row("More"))
check("a title is muted", Row("Title").text.color[1] == T.muted.r)
check("the chosen radio shows its dot", Row("Pick B").dot:IsShown() and not Row("Pick A").dot:IsShown())
check("a submenu row shows its arrow", Row("More").arrow:IsShown() and not Row("Run").arrow:IsShown())

Click("Title")
Click("Off")
check("a title and a disabled row do nothing", #log == 0 and list:IsShown())
Row("Off").scripts.OnEnter(Row("Off"))
check("a disabled row still shows its tooltip", tooltip.owner == Row("Off") and tooltip.said == "Off")

Click("Check")
check("a checkbox stays open and shows its new state", checked and list:IsShown() and Row("Check").mark:IsShown())
Click("Pick A")
check("a radio picks and closes", picked == "a" and not list:IsShown() and not ns.MenuOpen() and not handle:IsShown())
check("closing stops listening for clicks", list.events.GLOBAL_MOUSE_DOWN == nil)

ns.ContextMenu(owner, Fill)
Click("Run")
check("a button runs with its data and closes", log[1] == "run 7" and not list:IsShown())

ns.ContextMenu(owner, Fill)
Click("More")
check("a submenu opens in place with a Back row", Row("Back") and Row("Deep") and not Row("Run") and list:IsShown())
Click("Stay")
check("MenuResponse.Open keeps it open", log[2] == "stay" and list:IsShown())
Click("Back")
check("Back returns to the menu above", Row("Run") and not Row("Deep"))
Click("More")
Click("Deep")
check("a submenu's button closes the whole menu", log[3] == "deep" and not list:IsShown())

ns.ContextMenu(owner, Fill)
list.over = false
owner.over = true
list.scripts.OnEvent(list, "GLOBAL_MOUSE_DOWN")
check("a click on the owner leaves it to the owner", list:IsShown())
owner.over = false
list.over = true
list.scripts.OnEvent(list, "GLOBAL_MOUSE_DOWN")
check("a click on the list keeps it", list:IsShown())
list.over = false
list.scripts.OnEvent(list, "GLOBAL_MOUSE_DOWN")
check("a click elsewhere closes it", not list:IsShown())

ns.ContextMenu(owner, Fill)
list.scripts.OnHide(list)
check("hidden with its window, it is closed, not left open behind it", not list:IsShown() and not ns.MenuOpen())

ns.ContextMenu(UIParent, Fill)
list.over = false
UIParent.over = true
list.scripts.OnEvent(list, "GLOBAL_MOUSE_DOWN")
check("a menu owned by UIParent still closes on a click elsewhere", not list:IsShown())
UIParent.over = false

local first = ns.DropdownMenu(owner, function(root)
    for i = 1, 30 do root:CreateRadio("Choice " .. i, function() return false end, NOTHING, i) end
end, 200)
check("a dropdown opens under its owner",
    list.point[1] == "TOPLEFT" and list.point[2] == owner and list.point[3] == "BOTTOMLEFT" and game.opened == 0)
local columns = {}
for _, r in ipairs(Rows()) do columns[r.point[2]] = true end
local count = 0
for _ in pairs(columns) do count = count + 1 end
check("a list taller than asked splits into columns, three at most", count == 3)
check("past three columns it pages, with a More row", Row("Choice 26") and not Row("Choice 27") and Row("More"))
Click("More")
check("More shows the next page", Row("Choice 27") and Row("Choice 30") and not Row("Choice 1") and list:IsShown())
Click("More")
check("and wraps back to the first", Row("Choice 1") and not Row("Choice 27"))
ns.DropdownMenu(owner, function(root)
    for i = 1, 30 do root:CreateRadio("Choice " .. i, function(v) return v == 28 end, NOTHING, i) end
end, 200)
check("a paged list opens on the page with the chosen radio", Row("Choice 28") and not Row("Choice 1"))
local second = ns.ContextMenu(owner, Fill)
check("a new menu replaces the open one", second:IsShown() and not first:IsShown())
first:Close()
check("an old handle cannot close the new menu", second:IsShown())
second:Close()
check("its own handle can", not list:IsShown())

-- With the gamepad (GamepadNav.lua): the list holds it, B goes back a level then closes, and a right-click menu
-- opened by an A press opens under the gamepad's focus.
check("the list holds the gamepad like a window", pad.frame == list and pad.spec.initial and pad.spec.back)
ns.ContextMenu(owner, Fill)
check("titles, dividers and disabled rows are not the gamepad's", Row("Title").padSkip and Row("Off").padSkip
    and not Row("Run").padSkip)
check("the gamepad starts on the radio picked", pad.spec.initial(Rows()) == Row("Pick A"))
Click("More")
pad.spec.back()
check("B in a submenu goes back a level", Row("Run") and list:IsShown())
pad.spec.back()
check("B at the top closes the list", not list:IsShown())
pad.focus = Region("Button")
ns.ContextMenu(owner, Fill)
check("a menu the cursor opens opens at the cursor, wherever the gamepad's focus is", list.point[2] == UIParent)
pad.pressing = true
ns.ContextMenu(owner, Fill)
check("a right-click menu an A press opens opens under the gamepad's focus", list.point[1] == "TOPLEFT"
    and list.point[2] == pad.focus and list.point[3] == "BOTTOMLEFT")
pad.focus, pad.pressing = nil, nil
handle = ns.ContextMenu(owner, Fill)
handle.Close()

-- The Group Finder's Dungeon menu uses our list under the style and searches the picked dungeon.
local search = { LEVEL = "level", ALL = "all", pick = "level" }
function search.Activities(out) out[1] = 1; return 1 end
function search.Suits() return true end
function search.Run(pick) search.pick = pick; return true end
local parts = ns.Shared.Parts
parts.Link = function(parent, click)
    local link = Region("Button")
    link:SetParent(parent)
    link.click = click
    return link
end
parts.SetLink = function(link, text) link.label = text end
parts.SearchBox = function() return Region("Frame") end
ns.GroupFinder = {
    Settings = { Get = function() return "newest" end, OnChange = NOTHING },
    Listings = { Activity = function() return { short = "DM", min = 17, max = 26 } end },
    Search = search,
    UI = { Style = { FILTER_GAP = 8, SEARCH_H = 24, CONTENT_W = 500 } },
}
local browse = assert(loadfile("NaowhForever_Utilities/GroupFinder/UI/BrowseBar.lua"))
setfenv(browse, env)
browse()
local bar = ns.GroupFinder.UI.BrowseBar(window, NOTHING)
bar.dungeon.click(bar.dungeon)
check("the Dungeon menu opens our choices without opening a game menu",
    Row("DM 17-26") and list:IsShown() and game.contexts == 0 and game.opened == 0)
Click("DM 17-26")
check("picking a dungeon searches it, updates the label and closes the menu",
    search.pick == 1 and bar.dungeon.label == "Dungeon: DM 17-26" and not list:IsShown())

-- Group Inspect adds to the game's unit menus only off the style.
local modified = 0
local giEnv = setmetatable({
    Menu = { ModifyMenu = function() modified = modified + 1; return { Unregister = NOTHING } end },
    hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end,
    IsInGroup = function() return true end,
}, { __index = _G })
local giNs = { L = ns.L, GamepadStandDown = function() return gamepad end, Apply = NOTHING,
    QoLSettings = { OnChange = NOTHING }, GroupInspect = { On = function() return true end } }
giEnv._G = { NaowhForever = giNs }
local gi = assert(loadfile("NaowhForever_Utilities/GroupInspect/UI/Menu.lua"))
setfenv(gi, giEnv)
gi()
giNs.Apply()
check("under the style Group Inspect leaves the game's unit menus alone", modified == 0)
gamepad = false
giNs.Apply()
check("with keyboard and mouse it adds itself to them", modified == 3)

-- The rule: only Menus.lua opens the game's menus.
local HELPER = "Shared/UI/Menus.lua"
local MODIFY_OK = "NaowhForever_Utilities/GroupInspect/UI/Menu.lua"
local offenders = {}
for _, path in ipairs(TocFiles("%.lua$")) do
    if path ~= HELPER and not path:find("^Libs/") then
        local f = assert(io.open(path, "rb"))
        local source = f:read("*a")
        f:close()
        if source:find("MenuUtil%s*%.") or source:find("Menu%s*%.%s*GetManager") then
            offenders[#offenders + 1] = path
        end
        if source:find("Menu%s*%.%s*ModifyMenu") and not (path == MODIFY_OK and source:find("GamepadStandDown")) then
            offenders[#offenders + 1] = path
        end
    end
end
check("no Naowh file but " .. HELPER .. " calls MenuUtil or Menu.GetManager: " .. table.concat(offenders, ", "),
    #offenders == 0)

print(("menus: %d checks passed"):format(checks))
