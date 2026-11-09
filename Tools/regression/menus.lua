-- Loads Shared/UI/Menus.lua (ns.ContextMenu, ns.DropdownMenu, ns.MenuOpen) into a test's own ns, for a
-- test whose stub ns does not load Shared.xml. Keyboard and mouse unless the ns has its own
-- GamepadStandDown. The file's globals (MenuUtil, CreateFrame, ...) are looked up in env when called.
-- Not a test itself (run-all.sh runs only test*.lua). Run from the repo root:
--
--   dofile("Tools/regression/menus.lua")(ns, env)
return function(ns, env)
    if ns.GamepadStandDown == nil then ns.GamepadStandDown = function() return false end end
    if ns.PadWindow == nil then ns.PadWindow = function() end end
    if ns.PadFocus == nil then ns.PadFocus = function() end end
    if ns.PadPressFocus == nil then ns.PadPressFocus = function() end end
    local view = setmetatable({
        Shared = ns.Shared or { Style = dofile("Tools/regression/shared_style.lua") },
        THEME = ns.THEME or {},
        L = ns.L or function(s) return s end,
    }, { __index = ns, __newindex = ns })
    local chunk = assert(loadfile("Shared/UI/Menus.lua"))
    setfenv(chunk, setmetatable({ _G = { NaowhForever = view } }, { __index = env or _G }))
    chunk()
    return ns
end
