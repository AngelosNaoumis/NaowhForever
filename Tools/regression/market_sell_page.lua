-- The panel's Sell page (NaowhForever_Market/UI/Sell.lua) built over market_world.lua's stubbed auction house with
-- stub frames, for its tests. Not a test itself (run-all.sh runs only test*.lua). Run from the repo root.
--
--   local Page = dofile("Tools/regression/market_sell_page.lua")
--   local t = Page.Setup({ bags = ..., status = ..., scan = ... })   -- market_world's options
--   t.page.Show()   t.post.click()   t.confirms[1].yes()   t.Key("SPACE")
--   t.Rows()   -- Up Next's rows, top to bottom: row.kind, row.entry, row.section.text, row.star.shown
--   t.Click(row, "RightButton")   t.menus[1].items[1].click()
--   t.moneys[1].Type(2500)   -- the price box; t.moneys[2] is the Starting Bid box, its parent the bid row
--   t.Lines()   -- the listings shown under the form, top to bottom; t.Hover(line) then line.buy.click()
--   t.Chip("All")   -- a chip over the quantity box, by its text: chip.scripts.OnMouseUp(chip, "LeftButton")
--   t.prompts[1].accept("40")   -- a house prompt: its title, text and accept
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local WHITE = { r = 1, g = 1, b = 1 }

local function Setup(opts)
    local t = World.Setup(opts)
    local ns, env = t.ns, t.env
    local worldFrame = getmetatable(env.CreateFrame()).__index
    t.frames, t.confirms, t.menus, t.links, t.moneys, t.tips, t.prompts = {}, {}, {}, {}, {}, {}, {}

    local function Frame(kind, parent)
        local f = { widget = kind, parent = parent, shown = true, scripts = {}, height = 0 }
        return setmetatable(f, { __index = function(_, k)
            if k == "IsShown" then return function(self) return self.shown end end
            if k == "Show" then return function(self) self.shown = true end end
            if k == "Hide" then return function(self)
                if not self.shown then return end
                self.shown = false
                if self.scripts.OnHide then self.scripts.OnHide(self) end
            end end
            if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
            if k == "SetScript" then return function(self, name, fn)
                self.scripts[name] = fn
                if name == "OnEvent" then self.onEvent = fn end
            end end
            if k == "SetText" then return function(self, text) self.text = text end end
            if k == "GetText" then return function(self) return self.text end end
            if k == "SetHeight" then return function(self, h) self.height = h end end
            if k == "SetSize" then return function(self, _, h) self.height = h end end
            if k == "GetScript" then return function(self, name) return self.scripts[name] end end
            if k == "HookScript" then return function(self, name, fn)
                local old = self.scripts[name]
                self.scripts[name] = old and function(...) old(...) fn(...) end or fn
            end end
            if k == "SetTextColor" then return function(self, r, g, b) self.color = { r = r, g = g, b = b } end end
            if k == "GetHeight" then return function(self) return self.height end end
            if k == "SetEnabled" then return function(self, on) self.enabled = on and true or false end end
            if k == "SetAlpha" then return function(self, a) self.alpha = a end end
            if k == "HasFocus" then return function() return false end end
            if k == "CreateTexture" then return function(self) return Frame("Texture", self) end end
            if k == "SetPoint" then return function(self, point, x, y)
                if point == "TOPLEFT" and type(x) == "number" then self.y = -y end
                if point == "TOPLEFT" and type(x) == "table" then self.under = x end
            end end
            if k == "RegisterEvent" or k == "UnregisterAllEvents" then return worldFrame[k] end
            if type(k) == "string" and k:find("^%u") then return function() end end
        end })
    end
    t.Frame = Frame

    env.CreateFrame = function(kind, _, parent)
        local f = Frame(kind, parent)
        t.frames[#t.frames + 1] = f
        return f
    end
    env.GameTooltip = Frame("GameTooltip")
    function env.GameTooltip:SetOwner() t.tips = {} end
    function env.GameTooltip:AddLine(text) t.tips[#t.tips + 1] = text end
    env.ERR_NOT_ENOUGH_MONEY = "You don't have enough money."
    env.GameTooltip_Hide = function() end
    env.BreakUpLargeNumbers = tostring

    ns.THEME = { fg = WHITE, muted = WHITE, accent = WHITE, bg = WHITE }
    ns.Font = function(parent) return Frame("FontString", parent) end
    ns.Solid = function(parent) return Frame("Texture", parent) end
    ns.Border = function() end
    ns.Hairline = function(texture) return texture end
    ns.SetButtonText = function(button, text) button.label = text end
    ns.PrimaryButton = function(button) return button end
    ns.Button = function(parent, text, _, _, onClick)
        local b = Frame("Button", parent)
        b.label, b.click = text, onClick
        if text == "" then t.post = b elseif text == "Skip" then t.skip = b end
        return b
    end
    ns.NewEditBox = function(parent) return Frame("EditBox", parent) end
    ns.UI.SlimScroll = function(parent) return Frame("ScrollFrame", parent) end
    ns.Confirm = function(text, onYes, onNo, yesText, noText)
        local dimmer = Frame("Frame")
        dimmer.onClose = onNo
        dimmer:SetScript("OnHide", function(self)
            local fn = self.onClose
            self.onClose = nil
            if fn then fn() end
        end)
        local confirm = { text = text, yesText = yesText, noText = noText, dimmer = dimmer }
        function confirm.yes()
            dimmer.onClose = nil
            dimmer:Hide()
            onYes()
        end
        function confirm.no() dimmer:Hide() end
        t.confirms[#t.confirms + 1] = confirm
        return Frame("Button"), dimmer
    end
    ns.PromptText = function(title, text, _, onAccept)
        t.prompts[#t.prompts + 1] = { title = title, text = text, accept = onAccept }
    end
    ns.ContextMenu = function(owner, generator)
        local menu = { owner = owner, items = {} }
        local root = {}
        function root.CreateButton(_, text, onClick, data)
            menu.items[#menu.items + 1] = { text = text, click = function() onClick(data) end }
        end
        generator(owner, root)
        t.menus[#t.menus + 1] = menu
        return menu
    end
    ns.Shared.Style = dofile("Tools/regression/shared_style.lua")
    ns.Shared.Items = { Name = function(id) return "Item " .. id end, QualityColor = function() return nil end }
    local function MoneyBox(parent, onChange)
        local money = Frame("Frame", parent)
        money.boxes = { Frame("EditBox", money), Frame("EditBox", money), Frame("EditBox", money) }
        function money.SetAmount(_, v) money.amount = v end
        function money.GetAmount() return money.amount end
        function money.ShowCopper(_, on) money.copper = on end
        function money.HasFocus() return false end
        function money.Type(v)
            money.amount = v
            onChange(money, v)
        end
        t.moneys[#t.moneys + 1] = money
        return money
    end
    ns.Shared.Parts = {
        RowBands = function(row) row.stripe, row.hover = Frame("Texture", row), Frame("Texture", row) end,
        ItemIcon = function(parent)
            local icon = Frame("Frame", parent)
            icon.texture = Frame("Texture", icon)
            return icon
        end,
        Coins = function(copper) return tostring(copper) end,
        MoneyBox = MoneyBox,
        Tabs = function(parent) return Frame("Frame", parent) end,
        PaintTabs = function(bar, shown) bar.picked = shown end,
        ProgressLine = function(parent)
            local line = Frame("Frame", parent)
            function line.SetProgress(_, v) line.progress = v end
            return line
        end,
        Link = function(parent, onClick)
            local link = Frame("Button", parent)
            link.click = onClick
            t.links[#t.links + 1] = link
            return link
        end,
        SetLink = function(link, text) link.text = text end,
        Arrow = function(parent) return Frame("Texture", parent) end,
        Pill = function(parent, _, color)
            local pill = Frame("Frame", parent)
            pill.color = color
            t.frames[#t.frames + 1] = pill
            return pill
        end,
        SetPill = function(pill, text)
            pill.text = text
            return 0
        end,
        ColorPill = function(pill, color) pill.color = color end,
    }
    t.M.Pages = {}
    Load({ "NaowhForever_Market/View/Style.lua", "NaowhForever_Market/View/Listed.lua",
        "NaowhForever_Market/View/Quantity.lua", "NaowhForever_Market/UI/Sell.lua" }, env)
    t.page = t.M.Pages.sell
    t.page.Build(Frame("Frame"))

    function t.Key(key)
        local action = t.page.KeyAction(key)
        if action then action() end
        return action ~= nil
    end

    function t.Click(row, button)
        row.scripts.OnClick(row, button or "LeftButton")
    end

    function t.Lines()
        local found = {}
        for _, f in ipairs(t.frames) do
            if f.shown and rawget(f, "yours") and f.parent.parent.shown and f.parent.parent.parent.shown then
                found[#found + 1] = f
            end
        end
        table.sort(found, function(a, b) return a.y < b.y end)
        return found
    end

    function t.Chip(text)
        for _, f in ipairs(t.frames) do
            if rawget(f, "value") and f.text == text then return f end
        end
    end

    function t.Hover(line)
        line.scripts.OnEnter(line)
    end

    function t.Rows()
        local rows = {}
        for _, f in ipairs(t.frames) do
            if f.shown and rawget(f, "section") then rows[#rows + 1] = f end
        end
        table.sort(rows, function(a, b) return a.y < b.y end)
        return rows
    end

    return t
end

return { Setup = Setup, Stack = World.Stack, COMMODITY = World.COMMODITY, ITEM = World.ITEM }
