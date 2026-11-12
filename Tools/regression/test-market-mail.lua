-- Run with Lua 5.1 from the repository root: Mailbox Total, one line on the inbox's own tooltip with what
-- a mail's attachments would fetch at auction, added by a post-hook on the function Blizzard's inbox buttons call.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local LINEN, ORE, UNPRICED = 2589, 2770, 9999
local t = World.Setup()
local ns, env, S = t.ns, t.env, t.ns.MarketSettings
ns.THEME = { fg = { r = 1, g = 1, b = 1 } }
t.scan = { [LINEN] = 240, [ORE] = 1250 }

local mails = {
    [1] = { { LINEN, 20 }, { ORE, 3 }, { UNPRICED, 1 } },
    [2] = { { UNPRICED, 5 } },
    [3] = { { ORE } },
}
local reads, clock, blizzard = 0, 100, 0
local tip = { lines = {}, shows = 0 }
function tip:AddLine(text) self.lines[#self.lines + 1] = text end
function tip:Show() self.shows = self.shows + 1 end
env.GameTooltip = tip
env.ATTACHMENTS_MAX_RECEIVE = 16
env.GetTime = function() return clock end
env.C_CurrencyInfo = { GetCoinTextureString = function(copper) return copper .. "c" end }
env.GetInboxItem = function(index, i)
    reads = reads + 1
    local item = mails[index] and mails[index][i]
    if item then return "name", item[1], 1, item[2] end
end
env.InboxFrameItem_OnEnter = function()
    blizzard = blizzard + 1
    tip.lines = { "Blizzard's own lines" }
end
local hooks = 0
env.hooksecurefunc = function(target, name, fn)
    if type(target) == "string" then
        hooks = hooks + 1
        local original = env[target]
        env[target] = function(...)
            original(...)
            name(...)
        end
        return
    end
    local original = target[name]
    target[name] = function(...)
        original(...)
        fn(...)
    end
end
Load({ "NaowhForever_Market/UI/Mail.lua" }, env)

local function Hover(index, itemCount)
    env.InboxFrameItem_OnEnter({ index = index, hasItem = itemCount, itemCount = itemCount })
    return table.concat(tip.lines, " / ")
end

ns.Apply()
Check("off, its default, nothing is hooked and Blizzard's tooltip is its own", S.Get("tooltipMail") == false
    and hooks == 0 and Hover(1, 3) == "Blizzard's own lines" and reads == 0)
S.Set("enabled", true)
S.Set("tooltipMail", true)
ns.Apply()
ns.Apply()
Check("on, the function the inbox buttons call is hooked once, after Blizzard's own", hooks == 1)
Check("a mail's tooltip gains one line: each attachment's auction price times its count, to the copper",
    Hover(1, 3) == "Blizzard's own lines / Attachments: 8550c at auction" and blizzard == 2)
Check("and the tooltip is shown again so it grows to fit", tip.shows == 1)
Check("an attachment with no count is one", Hover(3, 1) == "Blizzard's own lines / Attachments: 1250c at auction")
Check("a mail whose attachments have no auction price gets no line", Hover(2, 1) == "Blizzard's own lines")
Check("nor does one with no attachments, which is not read at all", (function()
    local before = reads
    return Hover(1, nil) == "Blizzard's own lines" and reads == before
end)())

local before = reads
Hover(1, 3)
local once = reads - before
Hover(1, 3)
Hover(1, 3)
Check("Blizzard's buttons call it every frame while hovered: the attachments are read once, not each frame",
    once == 16 and reads - before == once and tip.lines[2] == "Attachments: 8550c at auction")
clock = clock + 1
mails[1][2] = nil
Check("and read again half a second on, so a mail that changed is counted as it is now",
    Hover(1, 2) == "Blizzard's own lines / Attachments: 4800c at auction" and reads - before == 2 * once)

S.Set("tooltip", false)
Check("with Tooltip Lines off the line is gone", Hover(1, 2) == "Blizzard's own lines")
S.Set("tooltip", true)
S.Set("tooltipMail", false)
Check("and with its own setting off", Hover(1, 2) == "Blizzard's own lines")
S.Set("tooltipMail", true)
S.Set("enabled", false)
Check("and with The Market off", Hover(1, 2) == "Blizzard's own lines")
S.Set("enabled", true)
ns.AuctionPrice = nil
clock = clock + 1
Check("without Auction Prices there is nothing to add", Hover(1, 2) == "Blizzard's own lines")

local source = io.open("NaowhForever_Market/UI/Mail.lua", "rb"):read("*a")
Check("it never sets a script on Blizzard's buttons", not source:find("SetScript", 1, true)
    and not source:find("HookScript", 1, true))

print("market mail: " .. checks .. " checks passed")
