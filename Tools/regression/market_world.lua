-- The Market's rules loaded against a stubbed auction house, bags and timers, for its tests. Not a test
-- itself (run-all.sh runs only test*.lua). Run from the repo root.
--
--   local World = dofile("Tools/regression/market_world.lua")
--   local t = World.Setup({ bags = { [0] = { World.Stack(2770, 20) } }, status = { [2770] = World.COMMODITY } })
local Load = dofile("Tools/regression/load_files.lua")

local COMMODITY, ITEM, UNKNOWN = 2, 1, 0
local FILES = { "NaowhForever_Market/Market.lua", "NaowhForever_Market/Constants.lua", "NaowhForever_Market/Bags.lua",
    "NaowhForever_Market/Listings.lua", "NaowhForever_Market/Post.lua", "NaowhForever_Market/Sell.lua",
    "NaowhForever_Market/Sales.lua", "NaowhForever_Market/Auctions.lua", "NaowhForever_Market/Buy.lua", "NaowhForever_Market/History.lua",
    "NaowhForever_Market/Worth.lua", "NaowhForever_Market/Crafts.lua",
    "NaowhForever_Market/Runs.lua", "NaowhForever_Market/Farm.lua" }

local function Noop() end

local function Setup(opts)
    opts = opts or {}
    local t = { bags = opts.bags or {}, status = opts.status or {}, scan = opts.scan or {}, vendor = opts.vendor or {},
        searches = {}, posts = {}, confirms = {}, loads = 0, timers = {}, hooks = {},
        owned = opts.owned or {}, keyInfo = opts.keyInfo or {}, queries = 0, cancels = {}, locked = {},
        browses = {}, browse = {}, more = 0, full = true, purchases = {}, bids = {}, money = opts.money or 1000000,
        account = {}, char = {}, scanAt = opts.scanAt, counts = opts.counts or {} }
    local registry = {}
    local copper = opts.copper ~= false
    t.ready = true

    local function Location(bag, slot)
        local loc = { bag = bag, slot = slot }
        function loc:SetBagAndSlot(b, s) self.bag, self.slot = b, s end
        function loc:IsValid() return t.bags[self.bag] and t.bags[self.bag][self.slot] ~= nil end
        return loc
    end
    local function Slot(loc) return t.bags[loc.bag] and t.bags[loc.bag][loc.slot] end

    local frameMethods = {}
    function frameMethods:RegisterEvent(event)
        registry[event] = registry[event] or {}
        registry[event][self] = true
    end
    function frameMethods:UnregisterAllEvents()
        for _, set in pairs(registry) do set[self] = nil end
    end
    function frameMethods:SetScript(_, fn) self.onEvent = fn end

    function t.Fire(event, ...)
        local list = {}
        for frame in pairs(registry[event] or {}) do list[#list + 1] = frame end
        for _, frame in ipairs(list) do frame.onEvent(frame, event, ...) end
    end
    function t.RunTimers()
        local pending = t.timers
        t.timers = {}
        for _, fn in ipairs(pending) do fn() end
    end

    local dialog = { OnAccept = Noop, OnHide = Noop }
    t.dialog = dialog
    local values = {}
    local ns = {
        FEATURES = { market = { enabled = false } },
        UI = { ModuleSettings = function(_, defaults)
            return { Get = function(k) if values[k] == nil then return defaults[k] end return values[k] end,
                Set = function(k, v) values[k] = v end, OnChange = Noop }
        end },
        GamepadStandDown = function() return false end,
        AuctionPrice = function(itemID) return t.scan[itemID], 0 end,
        AuctionPriceList = function() if t.scanAt then return t.scan, t.scanAt end end,
        AccountSettings = function() return t.account end,
        L = function(text) return text end,
        Apply = Noop,
        Shared = {
            CharacterData = function(key, create)
                if create and not t.char[key] then t.char[key] = {} end
                return t.char[key]
            end,
            Places = { SameMap = function(map) return t.sameMap and t.sameMap[map] or map end },
        },
    }
    t.ns = ns
    local results = { commodity = {}, item = {} }
    t.results = results
    local env = setmetatable({
        NUM_BAG_SLOTS = 1,
        AuctionCategories = opts.categories or {},
        Enum = { ItemCommodityStatus = { Unknown = UNKNOWN, Item = ITEM, Commodity = COMMODITY },
            AuctionHouseSortOrder = { Price = 0, Name = 1, Buyout = 4, Bid = 3 },
            AuctionStatus = { Active = 0, Sold = 1 } },
        Constants = { AuctionConstants = { DEFAULT_AUCTION_PRICE_MULTIPLIER = 1.5 } },
        C_CVar = { GetCVarDefault = function(name) return name == "auctionHouseDurationDropdown" and "2" or nil end },
        ItemLocation = { CreateEmpty = function() return Location() end,
            CreateFromBagAndSlot = function(_, bag, slot) return Location(bag, slot) end },
        C_Container = {
            GetContainerNumSlots = function(bag) return t.bags[bag] and #t.bags[bag] or 0 end,
            GetContainerItemInfo = function(bag, slot) return t.bags[bag] and t.bags[bag][slot] or nil end,
        },
        C_Item = {
            GetItemInfo = function(link)
                local id = tonumber(tostring(link):match("(%d+)"))
                if not id then return end
                return "Item " .. id, link, 1, 1, 1, "", "", 1, "", 0, t.vendor[id] or 0
            end,
            GetItemID = function(loc) local s = Slot(loc) return s and s.itemID end,
            GetItemLink = function(loc) local s = Slot(loc) return s and s.hyperlink end,
            IsEquippableItem = function(id) return opts.equippable and opts.equippable[id] or false end,
            RequestLoadItemData = function() t.loads = t.loads + 1 end,
            GetItemCount = function(id) return t.counts[id] or 0 end,
            GetItemInfoInstant = function(link) return tonumber(tostring(link):match("(%d+)")) end,
            GetItemNameByID = function(id) return "Item " .. id end,
            GetItemIconByID = function(id) return id end,
        },
        C_AuctionHouse = {
            IsSellItemValid = function(loc) local s = Slot(loc) return s ~= nil and not s.invalid end,
            GetItemCommodityStatus = function(loc) local s = Slot(loc) return s and (t.status[s.itemID] or ITEM) end,
            IsThrottledMessageSystemReady = function() return t.ready end,
            SupportsCopperValues = function() return copper end,
            MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } end,
            GetItemKeyFromItem = function(loc)
                local s = Slot(loc)
                return { itemID = s.itemID, itemLevel = 30, itemSuffix = 7, battlePetSpeciesID = 0 }
            end,
            GetItemKeyInfo = function(key) return t.keyInfo[key.itemID] end,
            SendSearchQuery = function(key, sorts) t.searches[#t.searches + 1] = { kind = "search", key = key, sorts = sorts } end,
            SendSellSearchQuery = function(key, sorts) t.searches[#t.searches + 1] = { kind = "sell", key = key, sorts = sorts } end,
            GetNumCommoditySearchResults = function(id) return #(results.commodity[id] or {}) end,
            GetCommoditySearchResultInfo = function(id, i) return results.commodity[id][i] end,
            GetNumItemSearchResults = function(key) return #(results.item[key.itemID] or {}) end,
            GetItemSearchResultInfo = function(key, i) return results.item[key.itemID][i] end,
            PostCommodity = function(loc, duration, quantity, price)
                t.posts[#t.posts + 1] = { kind = "commodity", loc = loc, duration = duration, quantity = quantity, price = price }
                return t.needsConfirm
            end,
            PostItem = function(loc, duration, quantity, bid, price)
                t.posts[#t.posts + 1] = { kind = "item", loc = loc, duration = duration, quantity = quantity, bid = bid,
                    price = price }
                return t.needsConfirm
            end,
            ConfirmPostCommodity = function(loc, duration, quantity, price)
                t.confirms[#t.confirms + 1] = { loc = loc, duration = duration, quantity = quantity, price = price }
            end,
            ConfirmPostItem = Noop,
            CalculateCommodityDeposit = function(_, duration, quantity) return 15 * quantity * duration end,
            CalculateItemDeposit = function(_, duration, quantity) return 101 * quantity * duration end,
            QueryOwnedAuctions = function() t.queries = t.queries + 1 end,
            GetNumOwnedAuctions = function() return #t.owned end,
            GetOwnedAuctionInfo = function(i) return t.owned[i] end,
            CanCancelAuction = function(id) return not t.locked[id] end,
            GetCancelCost = function() return 0 end,
            CancelAuction = function(id) t.cancels[#t.cancels + 1] = id end,
            SendBrowseQuery = function(query)
                t.browses[#t.browses + 1] = query.searchString
                t.lastBrowse = query
            end,
            HasFullBrowseResults = function() return t.full end,
            RequestMoreBrowseResults = function() t.more = t.more + 1 end,
            GetBrowseResults = function() return t.browse end,
            StartCommoditiesPurchase = function(id, quantity)
                t.purchases[#t.purchases + 1] = { step = "start", itemID = id, quantity = quantity }
            end,
            ConfirmCommoditiesPurchase = function(id, quantity)
                t.purchases[#t.purchases + 1] = { step = "confirm", itemID = id, quantity = quantity }
            end,
            CancelCommoditiesPurchase = function() t.purchases[#t.purchases + 1] = { step = "cancel" } end,
            PlaceBid = function(id, amount) t.bids[#t.bids + 1] = { auctionID = id, amount = amount } end,
        },
        C_Timer = { After = function(_, fn) t.timers[#t.timers + 1] = fn end },
        GetMoney = function() return t.money end,
        GetNumLootItems = function() return #(t.loot or {}) end,
        GetLootSourceInfo = function(slot) return t.loot[slot].source end,
        GetLootSlotLink = function(slot) return "item:" .. t.loot[slot].item end,
        GetLootSlotInfo = function(slot) return nil, nil, t.loot[slot].qty end,
        IsFishingLoot = function() return t.fishing end,
        GetRealmName = function() return "Realm" end,
        UnitFactionGroup = function() return "Horde" end,
        UnitGUID = function() return "Player-1" end,
        time = function() return t.now or 0 end,
        C_Map = {
            GetMapWorldSize = function() return 1000, 1000 end,
            GetMapInfo = function(map) return { name = "Map " .. map } end,
            GetBestMapForUnit = function() return t.playerMap end,
            GetPlayerMapPosition = function() return t.playerAt end,
        },
        UnitName = function() return "Me" end,
        UnitClass = function() return "Mage", "MAGE" end,
        CreateFrame = function() return setmetatable({}, { __index = frameMethods }) end,
        StaticPopupDialogs = { AUCTION_HOUSE_POST_WARNING = dialog },
        hooksecurefunc = function(target, name, fn)
            local original = target[name]
            target[name] = function(...) original(...) fn(...) end
            t.hooks[#t.hooks + 1] = name
        end,
        wipe = function(tbl) for k in pairs(tbl) do tbl[k] = nil end return tbl end,
    }, { __index = _G })
    env._G = env
    env.NaowhForever = ns
    Load(FILES, env)
    t.M = ns.Market
    t.M.FISH_CATCHES, t.M.FISH_POOLS = {}, {}
    return t
end

local function Stack(itemID, count, extra)
    local slot = { itemID = itemID, stackCount = count, hyperlink = "item:" .. itemID, iconFileID = itemID, quality = 1 }
    for k, v in pairs(extra or {}) do slot[k] = v end
    return slot
end

return { Setup = Setup, Stack = Stack, COMMODITY = COMMODITY, ITEM = ITEM, UNKNOWN = UNKNOWN }
