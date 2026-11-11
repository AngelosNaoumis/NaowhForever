-- Bosses.lua: the dungeon bosses that drop a Tarnished Undermine Real once a day: encounter ID to NPC ID.
local ns = _G.NaowhForever

local UR = ns.UndermineReal

UR.ITEM = 226404

UR.BOSSES = {
    -- Blackrock Depths
    [234] = 9056, -- Fineous Darkvire
    [232] = 9017, -- Lord Incendius
    [238] = 9537, -- Hurley Blackbreath
    [239] = 9502, -- Phalanx
    [236] = 9033, -- General Angerforge
    [237] = 8983, -- Golem Lord Argelmach
    [242] = 9156, -- Ambassador Flamelash
    [244] = 9938, -- Magmus
    [2790] = 9019, -- Emperor Dagran Thaurissan
    -- Lower Blackrock Spire
    [267] = 9196, -- Highlord Omokk
    [268] = 9236, -- Shadow Hunter Vosh'gajin
    [269] = 9237, -- War Master Voone
    [270] = 10596, -- Mother Smolderweb
    [271] = 10584, -- Urok Doomhowl
    [273] = 10268, -- Gizrul the Slavener
    [274] = 10220, -- Halycon
    [275] = 9568, -- Overlord Wyrmthalak
    -- Upper Blackrock Spire
    [3062] = 9816, -- Pyroguard Emberseer
    [3063] = 10429, -- Warchief Rend Blackhand
    [3068] = 10430, -- The Beast
    [3069] = 10363, -- General Drakkisath
    -- Dire Maul
    [2792] = 14354, -- Pusillin
    [345] = 14327, -- Lethtendris
    [344] = 13280, -- Hydrospawn
    [343] = 11490, -- Zevrim Thornhoof
    [346] = 11492, -- Alzzin the Wildshaper
    [368] = 11501, -- King Gordok
    [350] = 11489, -- Tendris Warpwood
    [348] = 11487, -- Magister Kalendris
    [347] = 11488, -- Illyanna Ravenoak
    [349] = 11496, -- Immol'thar
    [361] = 11486, -- Prince Tortheldrin
    -- Scholomance
    [2809] = 10433, -- Marduk Blackpool
    [2813] = 10432, -- Vectus
    [2802] = 11261, -- Doctor Theolen Krastinov
    [2803] = 10505, -- Instructor Malicia
    [2808] = 10901, -- Lorekeeper Polkelt
    [2807] = 10504, -- Lord Alexei Barov
    [2812] = 10507, -- The Ravenian
    [2806] = 10502, -- Lady Illucia Barov
    [2805] = 10506, -- Kirtonos the Herald
    [2801] = 1853, -- Darkmaster Gandling
    [2804] = 10503, -- Jandice Barov
    [2811] = 11622, -- Rattlegore
    [2810] = 10508, -- Ras Frostwhisper
    -- Stratholme
    [472] = 10516, -- The Unforgiven
    [2798] = 11143, -- Postmaster Malown
    [474] = 10808, -- Timmy the Cruel
    [475] = 10997, -- Cannon Master Willey
    [477] = 10811, -- Archivist Galford
    [482] = 10435, -- Magistrate Barthilas
    [480] = 10437, -- Nerub'enkan
    [481] = 10438, -- Maleki the Pallid
    [479] = 10436, -- Baroness Anastari
    [483] = 10439, -- Ramstein the Gorger
    [484] = 10440, -- Baron Rivendare
}
