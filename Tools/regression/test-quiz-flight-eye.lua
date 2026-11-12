-- Offline checks for the Quiz (NaowhForever_QoL/Travel/Quiz.lua): its Don't Show on Flights eye shows only when a
-- flight opened the quiz by itself, asked questions are not asked again until the bank runs out, and every
-- question in QuizData.lua is unique with four different answers.
-- These do not emulate client taint or rendering. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function fixture(questions, account)
    local s = { settings = { enabled = true }, account = account or {} }
    local any
    local function noop() return any end
    any = setmetatable({}, { __index = function() return noop end })
    local M = {}
    local meta = { __index = function(_, k)
        if M[k] then return M[k] end
        if k:match("^%u") then return noop end
    end }
    local function new(kind, parent)
        return setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true }, meta)
    end
    function M:SetScript(k, fn) self.scripts[k] = fn end
    function M:Show() self.shown = true end
    function M:Hide() self.shown = false end
    function M:SetShown(v) self.shown = v and true or false end
    function M:IsShown() return self.shown end
    function M:CreateTexture() return new("Texture", self) end
    local function frame(kind, _, parent) return new(kind, parent) end
    local S = {
        Get = function(k) return s.settings[k] end,
        Set = function(k, v) s.settings[k] = v end,
    }
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L, QoLSettings = S,
        THEME = { bg = {}, muted = {}, accent = {}, fg = { r = 1, g = 1, b = 1 } },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"),
            Settings = { Page = function() return { Card = function() end } end } },
        QUIZ_QUESTIONS = questions or { { q = "Question?", a = { "Right", "Wrong", "Wrong", "Wrong" } } },
        AccountSettings = function() return s.account end,
        AllowOffscreen = function() end,
        Solid = function(parent) return new("Texture", parent) end,
        Border = function(parent) return new("Border", parent) end,
        Font = function(parent) return new("FontString", parent) end,
        Button = function(parent)
            local b = new("Button", parent)
            b.label = new("FontString", b)
            return b
        end,
        RegisterMinimapFeature = function() end,
        Apply = function() end,
        FlightGameHideButton = function(parent)
            local b = new("Button", parent)
            b.shown = false
            s.hide = b
            return b
        end,
        FlightGameOffered = function(reason) return reason == "flight" end,
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        CreateFrame = frame, UIParent = new("Frame"),
        InCombatLockdown = function() return false end,
        hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end,
    }, { __index = _G })
    local chunk = assert(loadfile("NaowhForever_QoL/Travel/Quiz.lua"))
    setfenv(chunk, env)
    chunk()
    s.ns = ns
    return s
end

do
    local s = fixture()
    s.ns.QuizOffer("flight")
    check("a flight opening the quiz shows the eye", s.hide and s.hide.shown)
    s.ns.QuizDismiss("flight")
    s.ns.ToggleQuiz()
    check("opened by hand, no eye", not s.hide.shown)
    s.ns.QuizDismiss()
    s.settings.quizCamp = true
    s.ns.QuizOffer("camp")
    check("opened at the campfire, no eye", not s.hide.shown)
end

do
    local bank = {}
    for i = 1, 3 do bank[i] = { q = "Q" .. i, a = { "Right", "B", "C", "D" } } end
    local account = {}
    local s = fixture(bank, account)
    s.ns.ToggleQuiz()
    s.ns.ToggleQuiz()
    local s2 = fixture(bank, account)
    s2.ns.ToggleQuiz()
    local n = 0
    for _ in pairs(account.quizSeen) do n = n + 1 end
    check("a new session asks a question not asked before", n == 2)
    s2.ns.ToggleQuiz()
    s2.ns.ToggleQuiz()
    n = 0
    for _ in pairs(account.quizSeen) do n = n + 1 end
    check("the third question is the one left", n == 3)
    s2.ns.ToggleQuiz()
    s2.ns.ToggleQuiz()
    n = 0
    for _ in pairs(account.quizSeen) do n = n + 1 end
    check("once every question is asked, the bank starts over", n == 1)
end

do
    local ns = {}
    local chunk = assert(loadfile("NaowhForever_QoL/Travel/QuizData.lua"))
    setfenv(chunk, setmetatable({ _G = { NaowhForever = ns } }, { __index = _G }))
    chunk()
    local asked = {}
    for _, q in ipairs(ns.QUIZ_QUESTIONS) do
        check("unique question: " .. q.q, not asked[q.q])
        asked[q.q] = true
        local answers = {}
        for _, a in ipairs(q.a) do answers[a] = true end
        local count = 0
        for _ in pairs(answers) do count = count + 1 end
        check("four different answers: " .. q.q, #q.a == 4 and count == 4)
    end
end

print("test-quiz-flight-eye: " .. checks .. " checks passed")
