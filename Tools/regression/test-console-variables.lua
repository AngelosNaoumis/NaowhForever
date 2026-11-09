-- Run with Lua 5.1 from the repository root: QoL's Console Variables window and its share string, on stubs with the
-- real Shared files and the real LibSerialize and LibDeflate. Nothing is made or read at load; the list shows the
-- changed or every usable console variable, searched and capped; edits and imports are refused in combat; and
-- an import string is data only: malformed, oversized and wrong-version strings are refused whole, unknown names,
-- console commands, secure, read-only or locked console variables and the ones that name this account, client or
-- computer are left out, and nothing but C_CVar.SetCVar runs, after a confirmation that lists the changes. The
-- values are read once per open: a CVAR_UPDATE re-reads only its own, and search and tabs read none. Offline: no
-- client taint, rendering or real console.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local FILE = "NaowhForever_QoL/Interface/ConsoleVariables.lua"
local SHARE = "!NFCV1!"
local CVAR, COMMAND, SCRIPT = 0, 1, 3
local FILLERS, QUIET = 200, 900

local NOTHING = function() end
local Frame
local made = 0
local frames = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = f.scripts[script] or fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    GetWidth = function() return 400 end,
    GetHeight = function() return 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTextColor = function(f, r, g, b) f.color = { r, g, b } end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetFrameLevel = function() return 1 end,
    IsForbidden = function() return false end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    CreateAnimationGroup = function(f) return Frame(f) end,
    CreateAnimation = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, events = {}, parent = parent }, META)
end

local THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = { r = 0, g = 0.5, b = 1 } }
setmetatable(THEME, { __index = function() return { r = 1, g = 1, b = 1 } end })
local timers = {}
local tooltip = Frame()
tooltip.GetOwner = function() return nil end
tooltip.AddLine = function(f, text) f.line = text end

local settings = { consoleVariables = false }
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end,
    Default = function() return false end }
local printed, confirms, prompts, copies = {}, {}, {}, {}
local handedOff
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    Print = function(text) printed[#printed + 1] = text end,
    Confirm = function(text, onYes) confirms[#confirms + 1] = { text = text, yes = onYes } end,
    PromptText = function(title, text, max, onAccept)
        prompts[#prompts + 1] = { title = title, text = text, max = max, accept = onAccept }
    end,
    ShowCopyBox = function(title, text) copies[#copies + 1] = { title = title, text = text } end,
    Apply = NOTHING, AccountSettings = function() return {} end,
    THEME = THEME,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent)
        local f = Frame(parent)
        frames[#frames + 1] = f
        return f
    end,
    Solid = function(parent) return Frame(parent) end,
    ThemeTint = function(_, literal) return literal end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    Border = function() return { SetColor = NOTHING } end,
    AccentBorder = function() return { SetColor = NOTHING } end,
    AllowOffscreen = NOTHING,
    Button = function(parent) return Frame(parent) end,
    NewSearchBox = function(parent, _, onChange)
        local box = Frame(parent)
        box.onChange, box.hint, box.border = onChange, Frame(box), { SetColor = NOTHING }
        frames[#frames + 1] = box
        return box
    end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    UI = { Keep = NOTHING, SlimScroll = function(parent) return Frame(parent) end, CloseOnEscape = NOTHING },
    RegisterMinimapFeature = NOTHING,
    OpenFromOptions = function(open) handedOff = open end,
}

-- The client: every console command, and each console variable's value, default and flags.
local commands, cvars = {}, {}
local function AddCVar(name, value, default, flags)
    local help = flags and flags.help or ""
    if flags and flags.noHelp then help = nil end
    commands[#commands + 1] = { command = name, help = help, category = 4, commandType = CVAR,
        scriptContents = "", scriptParameters = "" }
    cvars[name] = { value = value, default = default, locked = flags and flags.locked, secure = flags and flags.secure,
        readOnly = flags and flags.readOnly, refuse = flags and flags.refuse }
end
AddCVar("cameraDistanceMaxZoomFactor", "2.6", "1.9", { help = "Max camera distance." })
AddCVar("SpellQueueWindow", "120", "400", { noHelp = true })
AddCVar("nameplateTopInset", "0.08", "0.080000")
AddCVar("autoLootDefault", "1", "1")
AddCVar("graphicsQuality", "7", "3", { refuse = true })
AddCVar("secureThing", "5", "1", { secure = true })
AddCVar("readOnlyThing", "5", "1", { readOnly = true })
AddCVar("lockedThing", "5", "1", { locked = true })
AddCVar("longThing", string.rep("x", 256), "")
AddCVar("pipeThing", "a|cffff0000b", "")
AddCVar("blankThing", "", "on")
AddCVar("GxMonitor", "1", "0")
AddCVar("textLocale", "deDE", "")
AddCVar("lastCharacterIndex", "3", "0")
AddCVar("portal", "EU", "")
AddCVar("Sound_OutputDriverName", "Speakers", "Primary Sound Driver")
for i = 1, FILLERS do AddCVar(("zFiller%03d"):format(i), "1", "0") end
for i = 1, QUIET do AddCVar(("yQuiet%03d"):format(i), "0", "0") end
commands[#commands + 1] = { command = "reloadui", help = "Reloads the UI.", category = 2, commandType = COMMAND,
    scriptContents = "", scriptParameters = "" }
commands[#commands + 1] = { command = "runThing", help = "", category = 2, commandType = SCRIPT,
    scriptContents = "RunScript('x')", scriptParameters = "" }
cvars.reloadui = { value = "0", default = "0" }

local listings, sets, executed, reads = 0, {}, 0, 0
local combat = false
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        made = made + 1
        local f = Frame(parent)
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(a, b, c)
        if type(a) ~= "table" then return end
        local original = a[b]
        a[b] = function(...) original(...); c(...) end
    end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = { GetItemInfo = NOTHING, GetItemIconByID = NOTHING },
    C_CVar = {
        GetCVarInfo = function(name)
            reads = reads + 1
            local c = cvars[name]
            if not c then return end
            return c.value, c.default, false, false, c.locked == true, c.secure == true, c.readOnly == true
        end,
        SetCVar = function(name, value)
            sets[#sets + 1] = { name = name, value = value }
            local c = cvars[name]
            if not c or c.refuse or c.secure or c.readOnly then return false end
            c.value = value
            return true
        end,
    },
    ConsoleGetAllCommands = function()
        listings = listings + 1
        local out = {}
        for i, info in ipairs(commands) do
            out[i] = {}
            for k, v in pairs(info) do out[i][k] = v end
        end
        return out
    end,
    ConsoleExec = function() executed = executed + 1 end,
    RunScript = function() executed = executed + 1 end,
    Enum = { ConsoleCommandType = { Cvar = CVAR, Command = COMMAND, Macro = 2, Script = SCRIPT } },
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    GameTooltip = tooltip,
    InCombatLockdown = function() return combat end,
    CreateColor = function() return Frame() end,
    UIParent = Frame(),
}, { __index = _G })
env._G = env

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local source = Read(FILE)
for _, word in ipairs({ "ConsoleExec", "RunScript", "loadstring", "securecall", "ConsoleEcho" }) do
    check("the file never runs anything: no " .. word, not source:find(word, 1, true))
end

Load({ "Core/Features.lua" }, env)
check("the switch is off by default, in Core/Features.lua", ns.FEATURES.qol.consoleVariables == false)

local files = TocFiles("^Shared/.*%.lua$")
for i = #files, 1, -1 do
    if files[i] == "Shared/UI/CopyCard.lua" then table.remove(files, i) end
end
Load(files, env)
local views = {}
local NewView = ns.Shared.View.New
ns.Shared.View.New = function(...)
    local view = NewView(...)
    views[#views + 1] = view
    return view
end
made = 0
Load({ FILE }, env)

check("off and closed, it costs nothing: no frame made and no command list read at load",
    made == 0 and #views == 0 and listings == 0)
local Settings = ns.Shared.Settings
local card = Settings.pages["QoL/Interface"].cards.consoleVariables
check("its card is on QoL > Interface, with its own switch", card ~= nil and card.switch == "consoleVariables")
card.rows[1].button()
check("the card opens the window from the options window, with a way back", handedOff == ns.OpenConsoleVariables)
check("the button waits for the switch", Settings.Off(card.rows[1]) == true)
settings.consoleVariables = true
check("and works once it is on", Settings.Off(card.rows[1]) == false)

local function Flush()
    while #timers > 0 do table.remove(timers, 1)() end
end

local cvarCount = 0
for _, info in ipairs(commands) do
    if info.commandType == CVAR then cvarCount = cvarCount + 1 end
end
ns.OpenConsoleVariables()
local view = views[1]
local window = view:GetParent():GetParent()
check("opening builds it once and reads the command list once", view ~= nil and made > 0 and listings == 1)
check("and reads each console variable once", reads == cvarCount)
local openReads = reads
check("it redraws on CVAR_UPDATE while shown", view.events.CVAR_UPDATE == true)

local function Rows()
    local out = {}
    for i = 1, view.pools.cvar.used do
        local row = view.pools.cvar[i]
        if row:IsShown() then out[#out + 1] = row end
    end
    return out
end
local function RowOf(name)
    for _, row in ipairs(Rows()) do
        if row.cvar == name then return row end
    end
end
local function Find(test)
    for _, f in ipairs(frames) do
        if test(f) then return f end
    end
end
local FIRST_OF = "The first 150 of 211; type more to narrow it down."
local summary = Find(function(f) return rawget(f, "text") == FIRST_OF end)

local shown = Rows()
check("Changed lists only what differs from its default, capped at 150 rows", #shown == 150)
check("it says how many matched", summary ~= nil)
check("in name order, any case", shown[1].cvar == "blankThing" and shown[2].cvar == "cameraDistanceMaxZoomFactor")
check("a value equal to its default as a number is not changed", RowOf("nameplateTopInset") == nil)
check("an unchanged one is not listed", RowOf("autoLootDefault") == nil)
check("secure, read-only and locked ones are left out", RowOf("secureThing") == nil and RowOf("readOnlyThing") == nil
    and RowOf("lockedThing") == nil)
check("console commands and scripts are not console variables", RowOf("reloadui") == nil and RowOf("runThing") == nil)
local camera = RowOf("cameraDistanceMaxZoomFactor")
check("a row shows its value and its default", camera.valueText.text == "2.6" and camera.defaultText.text == "1.9")
check("a changed value is in the accent, with a reset", camera.valueText.color[1] == THEME.accent.r
    and camera.reset.shown ~= false)
check("an empty value shows as quotes", RowOf("blankThing").valueText.text == "\"\"")
local quiet = RowOf("SpellQueueWindow")
tooltip.line = nil
check("one the game gives no help text for is listed and its hover still works", quiet ~= nil
    and pcall(quiet.scripts.OnEnter, quiet) and tooltip.line == "Click to change it.")

local search = Find(function(f) return rawget(f, "onChange") ~= nil end)
search.onChange("CAMERA")
check("the search narrows by name, any case", #Rows() == 1 and Rows()[1].cvar == "cameraDistanceMaxZoomFactor"
    and summary.text == "1 console variable")
search.onChange("nothing like it")
check("no match says so", #Rows() == 0 and view.pools.note.used == 1)

local allTab = Find(function(f) return rawget(f, "key") == "all" and f.scripts.OnClick ~= nil end)
search.onChange("auto")
allTab.scripts.OnClick(allTab)
check("All lists the unchanged ones too", RowOf("autoLootDefault") ~= nil
    and RowOf("autoLootDefault").valueText.color[1] == THEME.fg.r and RowOf("autoLootDefault").reset.shown == false)
search.onChange("")
check("All still leaves out what cannot be changed", RowOf("secureThing") == nil and RowOf("reloadui") == nil)
check("searching and switching tabs read nothing again", reads == openReads)

cvars.SpellQueueWindow.value = "77"
search.onChange("spell")
local updateReads = reads
view:OnEvent("CVAR_UPDATE", "SPELLQUEUEWINDOW", "77")
Flush()
check("a CVAR_UPDATE re-reads only its own console variable, named in any case", reads == updateReads + 1
    and RowOf("SpellQueueWindow").valueText.text == "77")
local queued = #timers
view:OnEvent("CVAR_UPDATE", "someAddonsOwnCVar", "1")
check("one the list does not have reads and redraws nothing", reads == updateReads + 1 and #timers == queued)
cvars.SpellQueueWindow.value = "120"
view:OnEvent("CVAR_UPDATE", "SpellQueueWindow", "120")
Flush()
search.onChange("")

search.onChange("camera")
camera = RowOf("cameraDistanceMaxZoomFactor")
combat = true
camera.scripts.OnClick(camera)
check("in combat a click only says it cannot change it now", #prompts == 0 and printed[#printed]
    == "Game settings can only be changed out of combat.")
combat = false
camera.scripts.OnClick(camera)
local prompt = prompts[#prompts]
check("a click asks for its new value, starting from the current one", prompt.title == "Set cameraDistanceMaxZoomFactor"
    and prompt.text == "2.6" and prompt.max == 255)
prompt.accept("2.0")
check("and sets it through C_CVar.SetCVar", sets[#sets].name == "cameraDistanceMaxZoomFactor"
    and sets[#sets].value == "2.0" and cvars.cameraDistanceMaxZoomFactor.value == "2.0")
Flush()
check("the list follows", RowOf("cameraDistanceMaxZoomFactor").valueText.text == "2.0")

search.onChange("graphics")
local graphics = RowOf("graphicsQuality")
graphics.scripts.OnClick(graphics)
prompts[#prompts].accept("9")
check("a value the game refuses says so", printed[#printed] == "The game did not take that value for graphicsQuality.")

search.onChange("camera")
camera = RowOf("cameraDistanceMaxZoomFactor")
camera.reset.scripts.OnClick(camera.reset)
local ask = confirms[#confirms]
check("its reset asks first, naming the default", ask.text == "Set cameraDistanceMaxZoomFactor back to its default, 1.9?")
local resetBefore = #sets
combat = true
ask.yes()
check("a reset confirmed in combat is refused", #sets == resetBefore)
combat = false
ask.yes()
check("and out of combat puts the default back", sets[#sets].value == "1.9"
    and cvars.cameraDistanceMaxZoomFactor.value == "1.9")
cvars.cameraDistanceMaxZoomFactor.value = "2.6"
view:OnEvent("CVAR_UPDATE", "cameraDistanceMaxZoomFactor", "2.6")
search.onChange("")

local function Payload(text)
    local body = text:match("^" .. SHARE .. "(%S+)$")
    return body and select(2, LS:Deserialize(LD:DecompressDeflate(LD:DecodeForPrint(body))))
end
local function Pack(value)
    return SHARE .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(value)))
end

local changedTab = Find(function(f) return rawget(f, "key") == "changed" and f.scripts.OnClick ~= nil end)
changedTab.scripts.OnClick(changedTab)
local exportButton = Find(function(f) return rawget(f, "tip") == "Export" and f.scripts.OnClick ~= nil end)
local importButton = Find(function(f) return rawget(f, "tip") == "Import" and f.scripts.OnClick ~= nil end)
search.onChange("gx")
check("this computer's own ones are still listed, to change here", RowOf("GxMonitor") ~= nil)
search.onChange("a")
exportButton.scripts.OnClick(exportButton)
local copy = copies[#copies]
local data = Payload(copy.text)
check("Export writes the list as shown, as a !NFCV1! string", copy.text:sub(1, #SHARE) == SHARE and data.v == 1
    and data.cvars.cameraDistanceMaxZoomFactor == "2.6" and data.cvars.graphicsQuality == "7"
    and data.cvars.blankThing == "")
check("only what the search shows", data.cvars.SpellQueueWindow == nil and data.cvars.zFiller001 == nil)
check("never the ones naming this account, client or computer", data.cvars.lastCharacterIndex == nil
    and data.cvars.portal == nil and data.cvars.textLocale == nil and data.cvars.Sound_OutputDriverName == nil)
check("its title counts them", copy.title == "Console Variables (3)")
search.onChange("thing")
exportButton.scripts.OnClick(exportButton)
data = Payload(copies[#copies].text)
check("not what it could not read back: a long value or one with a pipe", data.cvars.blankThing == ""
    and data.cvars.longThing == nil and data.cvars.pipeThing == nil and data.cvars.secureThing == nil)
search.onChange("")
exportButton.scripts.OnClick(exportButton)
local everything = copies[#copies].text
local count = 0
for _ in pairs(Payload(everything).cvars) do count = count + 1 end
check("every changed one when nothing is searched", count == 204 and Payload(everything).cvars.zFiller200 == "1")
allTab.scripts.OnClick(allTab)
search.onChange("auto")
exportButton.scripts.OnClick(exportButton)
local all = Payload(copies[#copies].text)
check("All exports the unchanged ones too", all.cvars.autoLootDefault == "1")
search.onChange("")
local copied = #copies
exportButton.scripts.OnClick(exportButton)
check("past 1000 it asks for a search first", #copies == copied
    and printed[#printed] == "The list has 1106; search until it has 1000 or fewer to export it.")
search.onChange("nothing like it")
exportButton.scripts.OnClick(exportButton)
check("an empty list exports nothing", printed[#printed] == "Nothing in the list to export.")
search.onChange("")
changedTab.scripts.OnClick(changedTab)

importButton.scripts.OnClick(importButton)
check("Import asks for a string of any length", prompts[#prompts].title == "Paste a Console Variables string"
    and prompts[#prompts].max == 0 and prompts[#prompts].accept == ns.ImportConsoleVariables)

local Import = ns.ImportConsoleVariables
local function Refused(label, text)
    local asked, setBefore = #confirms, #sets
    Import(text)
    check(label .. " is refused whole", #confirms == asked and #sets == setBefore
        and printed[#printed] == "That isn't a Console Variables string.")
end
Refused("nothing", nil)
Refused("an empty string", "")
Refused("another addon's string", "!NFM1!" .. Pack({ v = 1, cvars = {} }):sub(#SHARE + 1))
Refused("a damaged body", SHARE .. "not!a$string")
Refused("a cut string", Pack({ v = 1, cvars = { SpellQueueWindow = "100" } }):sub(1, 20))
Refused("a newer version", Pack({ v = 2, cvars = { SpellQueueWindow = "100" } }))
Refused("no list", Pack({ v = 1 }))
Refused("a list that is not a table", Pack({ v = 1, cvars = "SpellQueueWindow=100" }))
Refused("a number for a value", Pack({ v = 1, cvars = { SpellQueueWindow = 100 } }))
Refused("a boolean for a value", Pack({ v = 1, cvars = { SpellQueueWindow = true } }))
Refused("a table for a value", Pack({ v = 1, cvars = { SpellQueueWindow = { "100" } } }))
Refused("a number for a name", Pack({ v = 1, cvars = { [1] = "100" } }))
Refused("a name with a space", Pack({ v = 1, cvars = { ["Spell QueueWindow"] = "100" } }))
Refused("a name with a pipe", Pack({ v = 1, cvars = { ["SpellQueueWindow|r"] = "100" } }))
Refused("an empty name", Pack({ v = 1, cvars = { [""] = "100" } }))
Refused("a name past 64 letters", Pack({ v = 1, cvars = { [string.rep("a", 65)] = "1" } }))
Refused("a value past 255 letters", Pack({ v = 1, cvars = { SpellQueueWindow = string.rep("1", 256) } }))
Refused("a value with a line break", Pack({ v = 1, cvars = { SpellQueueWindow = "100\n/reload" } }))
Refused("a value with an escape code", Pack({ v = 1, cvars = { SpellQueueWindow = "|cffff0000100" } }))
local thousand, more = {}, {}
for i = 1, 1001 do more[("cvar%04d"):format(i)] = "1" end
for i = 1, 1000 do thousand[("cvar%04d"):format(i)] = "1" end
Refused("more than 1000 console variables", Pack({ v = 1, cvars = more }))
Refused("a string past its size cap", SHARE .. string.rep("a", 200001))
Refused("a decompression bomb", SHARE .. LD:EncodeForPrint(LD:CompressDeflate(string.rep("A", 1024 * 1024))))
check("nothing was ever run", executed == 0)

Import(Pack({ v = 1, cvars = thousand }))
check("1000 is the most, and names this client does not have change nothing",
    printed[#printed] == "Nothing in that string changes anything here.")
Import(Pack({ v = 1, cvars = { SpellQueueWindow = "120", nameplateTopInset = "0.080", secureThing = "9",
    readOnlyThing = "9", lockedThing = "9", reloadui = "1", runThing = "1" } }))
check("nor do the same values, secure, read-only or locked ones, or console commands",
    printed[#printed] == "Nothing in that string changes anything here." and #confirms == 1)
Import(Pack({ v = 1, cvars = { GxMonitor = "2", textLocale = "frFR", lastCharacterIndex = "1", portal = "US",
    Sound_OutputDriverName = "Headset" } }))
check("nor do the ones naming this account, client or computer",
    printed[#printed] == "Nothing in that string changes anything here." and #confirms == 1)
Import(Pack({ v = 1, cvars = { GxMonitor = "2", GxAdapter = "Other GPU", textLocale = "frFR", portal = "US",
    cameraDistanceMaxZoomFactor = "3.0", graphicsQuality = "5" } }))
check("they are left out while graphics and camera ones go through", confirms[#confirms].text
    == "Change 2 console variables?|ncameraDistanceMaxZoomFactor: 2.6 to 3.0|ngraphicsQuality: 7 to 5"
    .. "|n4 are left out: not ones an import can change.")

local asked = #confirms
combat = true
Import(Pack({ v = 1, cvars = { SpellQueueWindow = "100" } }))
check("in combat an import is refused", printed[#printed] == "Game settings can only be changed out of combat."
    and #confirms == asked)
combat = false

local before = #sets
Import(Pack({ v = 1, cvars = { SpellQueueWindow = "100", cameraDistanceMaxZoomFactor = "2.6",
    autoLootDefault = "0", unknownThing = "1", secureThing = "9", reloadui = "1",
    blankThing = string.rep("b", 255) } }))
ask = confirms[#confirms]
check("an import asks first", ask ~= nil and #sets == before)
check("listing what changes, from what to what, in name order", ask.text == "Change 3 console variables?"
    .. "|nautoLootDefault: 1 to 0"
    .. "|nblankThing: \"\" to " .. string.rep("b", 24) .. "..."
    .. "|nSpellQueueWindow: 120 to 100"
    .. "|n3 are left out: not ones an import can change.")
combat = true
ask.yes()
check("an import confirmed after combat starts is refused", #sets == before
    and printed[#printed] == "Game settings can only be changed out of combat.")
combat = false
ask.yes()
check("confirmed, only the changes are set, through C_CVar.SetCVar", #sets == before + 3
    and cvars.SpellQueueWindow.value == "100" and cvars.autoLootDefault.value == "0"
    and cvars.blankThing.value == string.rep("b", 255) and cvars.cameraDistanceMaxZoomFactor.value == "2.6"
    and cvars.secureThing.value == "5" and cvars.reloadui.value == "0")
check("and it says so", printed[#printed] == "Changed 3 console variables.")

Import(Pack({ v = 1, cvars = { SpellQueueWindow = "90", graphicsQuality = "1" } }))
confirms[#confirms].yes()
check("what the game refused is named", printed[#printed]
    == "Changed 1 of 2 console variables; the game refused graphicsQuality.")

local many = {}
for i = 1, 12 do many[("zFiller%03d"):format(i)] = "5" end
Import(Pack({ v = 1, cvars = many }))
local text = confirms[#confirms].text
local _, lines = text:gsub("|n", "")
check("a long import lists the first eight and counts the rest", text:find("^Change 12 console variables%?")
    and lines == 9 and text:find("|nAnd 4 more$"))
check("only after a yes", cvars.zFiller001.value == "1")

local fresh = Payload(everything).cvars
for name in pairs(fresh) do cvars[name].value = cvars[name].default end
Import(everything)
confirms[#confirms].yes()
local back = 0
for name, value in pairs(fresh) do
    if cvars[name].value == value then back = back + 1 end
end
check("an exported string imports back whole, but for what the game refuses", back == 204 - 1)

window:Hide()
local reopenReads = reads
ns.OpenConsoleVariables()
check("opening again reads each one again, once", reads - reopenReads == cvarCount)

S.Set("consoleVariables", false)
check("turning the switch off closes the window", window.shown == false)

print(("test-console-variables: %d checks passed"):format(checks))
