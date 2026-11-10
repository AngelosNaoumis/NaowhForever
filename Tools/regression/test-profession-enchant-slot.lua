-- Run with Lua 5.1 from the repository root: the Enchanting item slot (UI/EnchantSlot.lua, Recipes.lua Craft).
-- An Enchanting recipe gets a slot under its description. Picking an item in it makes Create cast
-- CraftEnchant on that item, once; without one Create starts the recipe and leaves the targeting cursor.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end

local methods = {}
for _, name in ipairs({ "SetSize", "SetFrameStrata", "EnableMouse", "EnableMouseWheel", "SetClampedToScreen",
    "SetAllPoints", "SetJustifyH", "SetWordWrap", "SetTexCoord", "SetTexture", "SetAlpha", "RegisterForClicks",
    "SetTextColor" }) do
    methods[name] = Noop
end
local widgetMeta = { __index = methods }

local function Widget(parent)
    return setmetatable({ shown = true, scripts = {}, hooks = {}, points = {}, parent = parent }, widgetMeta)
end

function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.hooks[name] = fn end
function methods.Show(self) self.shown = true end
function methods.Hide(self)
    self.shown = false
    if self.hooks.OnHide then self.hooks.OnHide(self) end
end
function methods.IsShown(self) return self.shown end
function methods.SetText(self, text) self.text = text end
function methods.GetStringHeight() return 12 end
function methods.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetHeight(self, h) self.height = h end
function methods.CreateTexture(self) return Widget(self) end
function methods.CreateFontString(self) return Widget(self) end

local color = { r = 1, g = 1, b = 1 }
local items = { guidA = "Zweihander", guidB = "Axe", guidC = "Mace" }
local valid = { guidA = true, guidB = true, guidC = true }
local casts, renders, buttons, frames = {}, 0, {}, {}

local ns = {
    L = function(text) return text end,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = { fg = color, muted = color, accent = color, bg = color, line = color, panel = color },
    Shared = { Style = dofile("Tools/regression/shared_style.lua") },
    Font = function(parent) return Widget(parent) end,
    Solid = function(parent) return Widget(parent) end,
    Border = function(parent) return Widget(parent) end,
    Tooltip = Noop,
    Button = function(parent, text, _, _, onClick)
        local b = Widget(parent)
        b.label = text
        b.scripts.OnClick = onClick
        return b
    end,
    Professions = {
        Settings = { DB = function() return {} end },
        State = {},
        Links = { Viewing = function() return false end },
        Detail = { Render = function() renders = renders + 1 end },
    },
}
local P = ns.Professions

local recipes = {
    [7418] = { recipeID = 7418, learned = true },
    [7421] = { recipeID = 7421, learned = true },
    [13642] = { recipeID = 13642, learned = false },
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(kind, _, parent)
        local w = Widget(parent)
        if kind == "Button" then buttons[#buttons + 1] = w end
        frames[#frames + 1] = w
        return w
    end,
    CreateColor = function() return {} end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UIParent = Widget(),
    Item = {
        CreateFromItemGUID = function(_, guid)
            local name = items[guid]
            return {
                GetItemID = function() return #name end,
                GetItemIcon = function() return guid end,
                GetItemName = function() return name end,
                GetItemLink = function() return "[" .. name .. "]" end,
            }
        end,
    },
    C_Item = { GetItemLocation = function(guid) return { guid = guid } end },
    C_TradeSkillUI = {
        IsTradeSkillLinked = function() return false end,
        IsTradeSkillGuild = function() return false end,
        GetRecipeInfo = function(id) return recipes[id] end,
        GetEnchantItems = function() return { "guidA", "guidB", "guidC" } end,
        IsEnchantTargetValid = function(_, guid) return valid[guid] end,
        CraftRecipe = function(id, count) casts[#casts + 1] = { "recipe", id, count } end,
        CraftEnchant = function(id, count, reagents, target)
            casts[#casts + 1] = { "enchant", id, count, reagents, target.guid }
        end,
    },
}, { __index = _G })
env._G = env

Load({
    "NaowhForever_Professions/Data/EnchantSlots.lua",
    "NaowhForever_Professions/View/Style.lua",
    "NaowhForever_Professions/View/Widgets.lua",
    "NaowhForever_Professions/View/Popup.lua",
    "NaowhForever_Professions/Recipes.lua",
    "NaowhForever_Professions/UI/EnchantSlot.lua",
}, env)

local W, R, Slot = P.State, P.Recipes, P.EnchantSlot
local win = { detail = Widget() }
Slot.Build(win, win.detail)
local slot = buttons[1]

local function Select(id)
    W.selectedID = id
    return R.SelectedInfo()
end

local function Click(button)
    slot.scripts.OnClick(slot, button or "LeftButton")
end

local function Picker()
    for _, w in ipairs(frames) do if w.rows then return w end end
end

local info = Select(7418)
check("a learned Enchanting recipe shows the slot and takes room", Slot.Render(info, 0) > 0 and slot:IsShown())
check("the slot starts empty", Slot.Location(7418) == nil)

check("a recipe with no gear slot shows none", Slot.Render(Select(7421), 0) == 0 and not slot:IsShown())
check("an unlearned recipe shows none", Slot.Render(Select(13642) or recipes[13642], 0) == 0)
W.selectedID = 7418
info = R.SelectedInfo()
W.linked = true
check("a linked profession shows none", Slot.Render(info, 0) == 0)
W.linked = false
W.orders = true
check("the order panel shows none", Slot.Render(info, 0) == 0)
W.orders = false
check("it returns", Slot.Render(info, 0) > 0)

Click()
check("clicking the slot opens the picker", Picker() and Picker():IsShown())
check("the list is sorted by name", Picker().rows[1].name.text == "[Axe]" and Picker().rows[3].name.text == "[Zweihander]")
Picker().rows[2].button.scripts.OnClick()
check("choosing an item closes the picker and redraws", not Picker():IsShown() and renders == 1)
check("Location is the chosen item", Slot.Location(7418).guid == "guidC")
Slot.Render(info, 0)
check("the slot shows the item's name", slot.label.text == "[Mace]")
Slot.Render(Select(7421), 0)
check("another recipe does not keep the choice", Slot.Location(7418) == nil)
Select(7418)
Click()
Picker().rows[2].button.scripts.OnClick()
Slot.Render(info, 0)
valid.guidC = false
Slot.Render(info, 0)
check("an item that stops fitting is dropped", Slot.Location(7418) == nil and slot.label.text == "Choose an item")
valid.guidC = true

Click()
Picker().rows[1].button.scripts.OnClick()
Click("RightButton")
check("right-click clears the slot", Slot.Location(7418) == nil)

Click()
Picker().rows[1].button.scripts.OnClick()
slot:Hide()
check("hiding the slot closes the picker", not Picker():IsShown())

W.selectedID = 7418
R.Craft(5)
check("Create enchants the chosen item once, no cursor",
    #casts == 1 and casts[1][1] == "enchant" and casts[1][2] == 7418 and casts[1][3] == 1
    and casts[1][4] == nil and casts[1][5] == "guidB")
Click("RightButton")
R.Craft(5)
check("without an item Create starts the recipe", casts[2][1] == "recipe" and casts[2][2] == 7418 and casts[2][3] == 5)

print(("test-profession-enchant-slot: %d checks passed"):format(checks))
