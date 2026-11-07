-- Spells.lua: the paladin blessings, auras and Righteous Fury, every rank by spell ID, and the codes plans use.
local ns = _G.NaowhForever

local B = ns.Blessings

B.BLESSINGS = {
    { key = "might", code = "m", ranks = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 } },
    { key = "wisdom", code = "w", ranks = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 } },
    { key = "kings", code = "k", ranks = { 20217 }, greater = { 25898 } },
}

B.AURAS = {
    { key = "devotion", code = "D", ranks = { 465, 10290, 643, 10291, 1032, 10292, 10293 } },
    { key = "retribution", code = "R", ranks = { 7294, 10298, 10299, 10300, 10301 } },
    { key = "concentration", code = "C", ranks = { 19746 } },
    { key = "shadow", code = "S", ranks = { 19876, 19895, 19896 } },
    { key = "frost", code = "F", ranks = { 19888, 19897, 19898 } },
    { key = "fire", code = "I", ranks = { 19891, 19899, 19900 } },
    { key = "sanctity", code = "T", ranks = { 20218 } },
}

B.FURY = { key = "fury", ranks = { 25780 } }

B.SEALS = {
    { key = "sealRighteousness", ranks = { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293 } },
    { key = "sealCommand", ranks = { 20375, 20915, 20918, 20919, 20920 } },
    { key = "sealFury", ranks = { 1311649, 1311656, 20163, 20419, 20421, 20422, 20423 } },
    { key = "sealCrusader", ranks = { 21082, 20162, 20305, 20306, 20307, 20308 } },
    { key = "sealJustice", ranks = { 20164 } },
    { key = "sealLight", ranks = { 20165, 20347, 20348, 20349 } },
    { key = "sealWisdom", ranks = { 20166, 20356, 20357 } },
}

B.SYMBOL_OF_KINGS = 21177

B.FREE_FLAG = "X"
