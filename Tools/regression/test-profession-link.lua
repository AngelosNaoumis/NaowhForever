-- Run with Lua 5.1 from the repository root: the profession window's Link button. Nothing is built
-- until your own profession is open and can be linked; a linked or guild view and the overview hide
-- it. Its menu sends the profession's trade link, read when a channel is picked, and has no Copy
-- entry, which the share menu keeps for callers that hand it text to copy.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local LINK = "|cffffd000|Htrade:Player-1-AAAA:7413:333|h[Enchanting]|h|r"

local view = { own = true, profession = { id = 333 }, canLink = true, link = LINK }
local hooks, built, sent, copied = {}, {}, {}, {}
local menu

local function Entry(text)
    local entry = { text = text, enabled = true }
    function entry:SetEnabled(on) self.enabled = on end
    return entry
end

local function Menu()
    local root = { entries = {} }
    function root:CreateTitle(text) self.title = self.title or text end
    function root:CreateDivider() end
    function root:CreateButton(text, fn)
        local entry = Entry(text)
        entry.click = fn
        self.entries[text] = entry
        return entry
    end
    return root
end

local ns = {
    L = function(text) return text end,
    Color = function(_, text) return text end,
    Shared = { Parts = {} },
    Button = function(_, text, _, _, onClick)
        local button = { text = text, shown = true, click = onClick }
        function button:Hide() self.shown = false end
        function button:SetShown(on) self.shown = on end
        built[#built + 1] = button
        return button
    end,
    Tooltip = function(button, title, body) button.tip = { title, body } end,
    ContextMenu = function(_, fill)
        menu = Menu()
        fill(nil, menu)
    end,
    ShowCopyLine = function(title, text) copied[#copied + 1] = { title, text } end,
    Professions = {
        State = { frame = {} },
        Window = { Render = function() end },
        Book = { Render = function() end },
        TitleButtons = { Add = function(button, order) button.order = order end },
        Recipes = {
            Own = function() return view.own end,
            Profession = function() return view.profession end,
        },
    },
}
local P = ns.Professions

local env = setmetatable({
    NaowhForever = ns,
    TRADESKILL_POST = "Post in chat",
    LINK_TRADESKILL_TOOLTIP = "Click here to create a link to your profession.",
    LE_PARTY_CATEGORY_INSTANCE = 2,
    hooksecurefunc = function(owner, name, fn) hooks[owner] = hooks[owner] or {}; hooks[owner][name] = fn end,
    IsInGroup = function() return false end,
    IsInRaid = function() return false end,
    IsInGuild = function() return true end,
    IsInInstance = function() return false end,
    UnitIsPlayer = function() return false end,
    GetChannelList = function() return 2, "Trade - City", false end,
    C_ChatInfo = {
        InChatMessagingLockdown = function() return false end,
        SendChatMessage = function(text, channel, _, to) sent[#sent + 1] = { text, channel, to } end,
    },
    C_TradeSkillUI = {
        CanTradeSkillListLink = function() return view.canLink end,
        GetTradeSkillListLink = function() return view.link end,
    },
}, { __index = _G })
env._G = env

local function Load(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    local chunk = assert(loadstring(source, path))
    setfenv(chunk, env)
    chunk()
end

Load("Shared/UI/Share.lua")
Load("NaowhForever_Professions/UI/Link.lua")
local Render, RenderBook = hooks[P.Window].Render, hooks[P.Book].Render

-- Someone else's list, or one that cannot be linked: nothing is built.
view.own = false
Render()
check("a linked view builds no button", #built == 0)
view.own, view.canLink = true, false
Render()
check("a profession that cannot be linked builds no button", #built == 0)
view.canLink, view.profession = true, nil
Render()
check("no open profession builds no button", #built == 0)
RenderBook()
check("the overview builds no button", #built == 0)

-- Your own profession: the button, on the title bar.
view.profession = { id = 333 }
Render()
local button = built[1]
check("your own profession shows the button", #built == 1 and button.shown and button.order ~= nil)
check("with the game's own tooltip", button.tip[2] == env.LINK_TRADESKILL_TOOLTIP)
Render()
check("drawing again builds no second button", #built == 1)

-- Its menu posts the trade link, as it is when the channel is picked.
button.click()
check("the menu is titled Post in chat", menu.title == env.TRADESKILL_POST)
check("guild is offered, party and raid are not without a group",
    menu.entries.Guild.enabled and not menu.entries.Party.enabled and not menu.entries.Raid.enabled)
check("trade chat is offered in a city", menu.entries.Trade.enabled)
check("there is nothing to copy", menu.entries.Copy == nil)
view.link = LINK .. "new"
menu.entries.Guild.click()
check("guild gets the trade link", #sent == 1 and sent[1][1] == LINK .. "new" and sent[1][2] == "GUILD")
menu.entries.Trade.click()
check("trade gets it on its channel", sent[2][1] == LINK .. "new" and sent[2][2] == "CHANNEL" and sent[2][3] == 2)

-- The overview and a linked view hide it; your own profession brings it back.
RenderBook()
check("the overview hides the button", not button.shown)
Render()
check("your profession shows it again", button.shown)
view.own = false
Render()
check("a linked view hides it", not button.shown)

-- A caller with text to copy keeps its Copy entry.
ns.Shared.Parts.ShareMenu({}, "Share", "a line", "Title", "a line")
check("the share menu still offers Copy with text to copy", menu.entries.Copy ~= nil)
menu.entries.Copy.click()
check("and copies it", copied[1][1] == "Title" and copied[1][2] == "a line")

print(("test-profession-link: %d checks passed"):format(checks))
