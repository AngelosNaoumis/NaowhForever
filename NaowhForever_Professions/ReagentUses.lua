-- ReagentUses.lua: what each reagent goes into across every profession, who knows each recipe, how many your bags make, and whether crafting beats selling (P.ReagentUses).
local ns = _G.NaowhForever

local GetItemCount = C_Item.GetItemCount
local GetItemInfo = C_Item.GetItemInfo
local GetItemNameByID = C_Item.GetItemNameByID

local P = ns.Professions
local C = P.C
local V = P.Vendors
local Prices = P.Prices

local SELL_PRICE = 11
local PROFESSION_SLOTS = 6
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local NO_MAP = 0
local NO_CAP = math.huge
local GUID_REALM = "^%a+%-(%d+)%-"
local YOU, ALT, NEW = 1, 2, 3

local uses, reagents
local skillOf, capOf, slots, seen, where = {}, {}, {}, {}, {}
local pass = 0

local Uses = { YOU = YOU, ALT = ALT, NEW = NEW }
P.ReagentUses = Uses

local function Build()
    uses, reagents = {}, {}
    for prof, line in pairs(ns.RecipeData) do
        for _, r in ipairs(line.recipes) do
            local mats = P.RecipeReagents[r.spell]
            if mats then
                local e = { spell = r.spell, prof = prof, r = r, output = r.item, made = mats.made or 1, need = {} }
                for i = 1, #mats, 2 do
                    local item = mats[i]
                    e.need[item] = mats[i + 1]
                    if not uses[item] then
                        uses[item] = {}
                        reagents[#reagents + 1] = item
                    end
                    table.insert(uses[item], e)
                end
            end
        end
    end
    table.sort(reagents)
end

local function ReadSkills()
    wipe(skillOf)
    wipe(capOf)
    slots[1], slots[2], slots[3], slots[4], slots[5], slots[6] = GetProfessions()
    for i = 1, PROFESSION_SLOTS do
        if slots[i] then
            local _, _, rank, cap, _, _, line, modifier = GetProfessionInfo(slots[i])
            if line then skillOf[line], capOf[line] = rank + (modifier or 0), cap end
        end
    end
end

local function Realm(guid)
    return guid and guid:match(GUID_REALM)
end

local function Knower(e)
    if ns.RecipeFinder.Learned(e.spell) then return YOU end
    local all = e.output and ns.AccountSettings().profMakes
    if type(all) ~= "table" then return NEW end
    local me = UnitGUID("player")
    local realm, alt = Realm(me), nil
    for guid, makes in pairs(all) do
        local m = type(makes) == "table" and makes[e.output]
        if m and m.recipe == e.spell then
            if guid == me then return YOU end
            if Realm(guid) == realm then alt = guid end
        end
    end
    if alt then return ALT, alt end
    return NEW
end

local function SellEach(item)
    local auction = ns.AuctionPrice and ns.AuctionPrice(item)
    return math.max(auction and Prices.AfterCut(auction, 1) or 0, select(SELL_PRICE, GetItemInfo(item)) or 0)
end

local function Price(e)
    if e.pass == pass then return end
    e.pass = pass
    local each = e.output and ns.AuctionPrice and ns.AuctionPrice(e.output)
    e.sale = each and Prices.AfterCut(each, e.made) or nil
    local raw, can = 0, nil
    for item, per in pairs(e.need) do
        local buy = V.IsVendorItem(item) and V.Price(item)
        if buy then
            raw = raw + buy * per
        else
            raw = raw + SellEach(item) * per
            can = math.min(can or math.huge, math.floor(GetItemCount(item) / per))
        end
    end
    e.raw, e.can = raw, can
    e.gain = e.sale and e.sale - raw or nil
    e.rank, e.alt = Knower(e)
end

local function Better(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    local x, y = a.gain or -math.huge, b.gain or -math.huge
    if x ~= y then return x > y end
    return a.spell < b.spell
end

function Uses.Begin()
    if not uses then Build() end
    pass = pass + 1
    ReadSkills()
end

function Uses.Of(item)
    local list = uses[item]
    if not list then return end
    for _, e in ipairs(list) do Price(e) end
    table.sort(list, Better)
    return list
end

function Uses.Read(item, info)
    local list = Uses.Of(item)
    info.item, info.count, info.each, info.list = item, GetItemCount(item), SellEach(item), list
    info.best, info.bestEach = nil, nil
    for _, e in ipairs(list) do
        if e.rank ~= NEW and e.gain and e.gain > 0 then
            local each = e.gain / e.need[item]
            if not info.best or each > info.bestEach then info.best, info.bestEach = e, each end
        end
    end
    return info
end

function Uses.Carried(out)
    wipe(out)
    wipe(seen)
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local item = C_Container.GetContainerItemID(bag, slot)
            if item and uses[item] and not seen[item] then
                seen[item] = true
                out[#out + 1] = item
            end
        end
    end
    return out
end

function Uses.Search(query, out, missing)
    wipe(out)
    for _, item in ipairs(reagents) do
        local name = GetItemNameByID(item)
        if not name then
            missing[#missing + 1] = item
        elseif ns.Lower(name):find(query, 1, true) then
            out[#out + 1] = item
        end
    end
    return out
end

function Uses.Name(e)
    if e.output then return GetItemNameByID(e.output) end
    return C_Spell.GetSpellName(e.spell)
end

function Uses.Icon(e)
    if e.output then return C_Item.GetItemIconByID(e.output) end
    return C_Spell.GetSpellTexture(e.spell)
end

function Uses.Profession(e)
    return C_Spell.GetSpellName(ns.RecipeData[e.prof].skillSpell)
end

function Uses.Skill(e)
    return ns.RecipeFinder.Skill(e.r)
end

function Uses.Status(e)
    local skill, cap = skillOf[e.prof], capOf[e.prof]
    if not skill then return "none", 0, 0 end
    local need = Uses.Skill(e)
    if skill >= need then return "ready", skill, cap end
    if cap < need then return "rank", skill, cap end
    return "later", skill, cap
end

function Uses.Where(e)
    where.data = ns.RecipeData[e.prof]
    where.skill = skillOf[e.prof] or 0
    where.max = capOf[e.prof] or NO_CAP
    return ns.RecipeFinder.Describe(e.r, where)
end

function Uses.Spot(e)
    for _, line in ipairs(Uses.Where(e)) do
        local npc = line.npc
        if npc and npc[C.NPC_MAP] > NO_MAP then return npc end
    end
end

function Uses.Waypoint(e)
    local npc = Uses.Spot(e)
    if not npc then return false end
    return ns.PlaceWaypoint(npc[C.NPC_NAME], npc[C.NPC_MAP], npc[C.NPC_X], npc[C.NPC_Y])
end
