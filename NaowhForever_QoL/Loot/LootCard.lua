-- LootCard.lua: the card on Loot & Items that Looting, Vendors, Lockboxes and Mail & Alts put their settings into.
local ns = _G.NaowhForever

ns.Shared.Settings.Page("QoL/Loot & Items", ns.QoLSettings):Card({
    id = "lootTrade", name = "Looting, Vendors & Mail", order = 10,
    help = "Looting, selling and repairing at vendors, and mail with your alts.",
    rows = {},
})
