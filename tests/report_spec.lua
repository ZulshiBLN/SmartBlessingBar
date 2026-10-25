-- The bug report: everything needed to find and fix a bug without asking the player back, and
-- nothing about the player (ruleset plan 2026-10-24-bug-report, after SimpleConjureBar's). Every
-- name and value planted here is made up (CLAUDE.md, secrets).

local addon = require("addon")

local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN"); RUNTIMERS()
    return ns, SmartBlessingBarDB
end

local function contains(lines, pattern)
    for _, l in ipairs(lines) do if l:find(pattern) then return l end end
end

-- A BugGrabber as on Forever: GetDB and GetSessionId; entries with a Unix time and a session
local function grabber(errors, session)
    _G.BugGrabber = {
        GetDB = function() return errors end,
        GetSessionId = function() return session end,
    }
end

local function ourError(at, session, extra)
    local e = { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:10: attempt to index nil",
        stack = "[Interface/AddOns/SmartBlessingBar/Bar.lua]:10: in function 'x'", counter = 2,
        time = at, session = session, locals = "self=<table>" }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

local function build(ns, area, description, details)
    return ns.BuildReport({ area = area, description = description, details = details })
end

-- Every byte sequence a whole UTF-8 character
local function validUtf8(s)
    local i = 1
    while i <= #s do
        local c = s:byte(i)
        local len = c < 0x80 and 1 or c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or 0
        if len == 0 or i + len - 1 > #s then return false end
        for k = i + 1, i + len - 1 do
            local b = s:byte(k)
            if b < 0x80 or b > 0xBF then return false end
        end
        i = i + len
    end
    return true
end

---------------------------------------------------------------------------
-- Privacy (plan criterion 1)
---------------------------------------------------------------------------
-- One value per filter; none may reach a report
local POISON = {
    "Testplayer", "Testsecond", "Testrealm", "Testguild", "Partyone", "partyone", "Tèstname",
    "Raidseven", "Targetguy", "Totguy", "Focusguy", "Mouseguy", "Tradeguy", "Petname", "Partypet",
    "Player-1111-0AAAAAAA", "Somebody#1234", "12345678#1", "john.doe@example.com",
    "Some One", "linuxsomeone", "macsomeone", "Shareuser", "MYACCOUNT", "Program Files",
    -- the 1.1.0 audit's S-01: CJK, Korean and Cyrillic names, non-ASCII capitals
    "张三", "철수", "Иван", "ИВАН", "TÈSTNAME",
}

-- The 1.1.0 audit's S-01: known names beside non-ASCII punctuation, inside text without word
-- spaces, with a Korean particle, in non-ASCII capitals
local S01 = "„Partyone“ hat ¡Raidseven! ¿Totguy? «Focusguy» ‹Mouseguy› Tradeguy… then"
    .. " Petname—and x–Partypet a·Testguild Testplayer　x Testplayer，x 我和张三一起 철수가 x"
    .. " ИВАН x TÈSTNAME x"

local function poison(db)
    STATE.realm, STATE.guild = "Testrealm", "Testguild"
    STATE.group = "raid"
    STATE.units.player = { name = "Testplayer", surname = "Testsecond", class = "PALADIN", level = 34 }
    STATE.units.raid1 = STATE.units.player
    STATE.units.raid2 = { name = "Partyone", class = "PRIEST" }
    STATE.units.raid3 = { name = "Tèstname", class = "DRUID" }
    STATE.units.raid4 = { name = "Иван", class = "ROGUE" }
    STATE.units.raid5 = { name = "张三", class = "HUNTER" }
    STATE.units.raid6 = { name = "철수", class = "WARLOCK" }
    STATE.units.raid7 = { name = "Raidseven", class = "MAGE" }
    STATE.units.target = { name = "Targetguy" }
    STATE.units.targettarget = { name = "Totguy" }
    STATE.units.focus = { name = "Focusguy" }
    STATE.units.mouseover = { name = "Mouseguy" }
    STATE.units.NPC = { name = "Tradeguy" }
    STATE.units.pet = { name = "Petname" }
    STATE.units.raidpet2 = { name = "Partypet" }
    db.someString = "Partyone" -- an unknown string setting
    local free = "Testplayer-Testrealm and partyone saw Tèstname\226\128\139 hit Raidseven, Totguy, Focusguy,"
        .. " Mouseguy, Tradeguy, Petname and Partypet in Testguild; Player-1111-0AAAAAAA Somebody#1234"
        .. " 12345678#1 john.doe@example.com C:\\Users\\Some One\\x.lua /home/linuxsomeone/wow"
        .. " /Users/macsomeone/wow \\\\server\\Shareuser\\x " .. S01
    grabber({ ourError(time(), 1, {
        message = "Interface/AddOns/SmartBlessingBar/Bar.lua:10: " .. free,
        stack = "[C:\\Program Files\\World of Warcraft\\_forever_\\Interface\\AddOns\\SmartBlessingBar\\Bar.lua]:10: in function 'Targetguy'",
        locals = table.concat({
            'name="Partyone"', "self=<table> {", '  Partyone = 1', '  [1] = "Targetguy"',
            '  frame = Testguild {', "  }", "}", 'count=3', 'flag=true', 'unit="raid2"',
            'Somebody#1234 = 5', "not a line we can read",
        }, "\n"),
    }) }, 1)
    return free
end

local function assertClean(ns, text)
    for _, bad in ipairs(POISON) do
        assert.is_nil(text:find(bad, 1, true), bad .. " leaked:\n" .. text)
    end
    assert.is_nil(text:find("%d%d%d%d%-%d%d%-%d%d"), "a date:\n" .. text)
    assert.is_nil(text:find("%d%d:%d%d"), "a clock:\n" .. text)
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local known = false
        for _, f in ipairs(ns.D.REPORT_FIELDS) do
            if line:find(f.pattern) then known = true break end
        end
        assert.is_true(known, "not a listed field: " .. line)
    end
end

describe("the report's privacy", function()
    it("lets no name, GUID, tag, address or path through, and every line is a listed field", function()
        local ns, db = login()
        local free = poison(db)
        -- a path runs to the line end: the WTF folder gets a field of its own
        local text = build(ns, "OTHER", free, S01 .. " WTF\\Account\\MYACCOUNT\\x")
        assertClean(ns, text)
        -- what the developer needs is still there
        assert.is_truthy(text:find("<name>", 1, true))
        assert.is_truthy(text:find("<guid>", 1, true))
        assert.is_truthy(text:find("<tag>", 1, true))
        assert.is_truthy(text:find("<email>", 1, true))
        assert.is_truthy(text:find("at [Interface/AddOns/SmartBlessingBar/Bar.lua]:10:", 1, true), text)
        assert.is_truthy(text:find("local count=3", 1, true), text)
        assert.is_truthy(text:find('local unit="raid2"', 1, true), text)
        assert.is_truthy(text:find("Character: PALADIN, level 30-39, raid", 1, true), text)
        assert.is_truthy(text:find("classLists=WARRIOR:", 1, true), "a table setting, summarized")
        assert.is_nil(text:find("someString", 1, true), "an unknown setting")
    end)

    it("fails when any one filter is taken away", function()
        local ns, db = login()
        local free = poison(db)
        local scrub = ns.Scrub
        -- each filter replaced by one that lets its own kind through
        local escapes = {
            names = function(t, _) return scrub(t, {}) end,
            paths = function(t, names) return (scrub(t, names):gsub("<path>", "C:\\Users\\Some One")) end,
            addresses = function(t, names) return (scrub(t, names):gsub("<email>", "john.doe@example.com")) end,
            guids = function(t, names) return (scrub(t, names):gsub("<guid>", "Player-1111-0AAAAAAA")) end,
            tags = function(t, names) return (scrub(t, names):gsub("<tag>", "Somebody#1234")) end,
            wtf = function(t, names) return (scrub(t, names):gsub("<wtf>", "WTF\\Account\\MYACCOUNT")) end,
        }
        for what, weak in pairs(escapes) do
            ns.Scrub = weak
            local ok = pcall(assertClean, ns, build(ns, "OTHER", free, "WTF\\Account\\MYACCOUNT\\x"))
            assert.is_false(ok, what)
        end
        ns.Scrub = scrub
        local safe = ns.IsSafe
        ns.IsSafe = function() return true end
        STATE.units.raid2.name = "Partyone"
        ns.blessingButton:SetAttribute("unit1", "Partyone")
        assert.is_false(pcall(assertClean, ns, build(ns, "OTHER")), "the allowlist")
        ns.IsSafe = safe
        -- a line of no listed field: the field check notices it
        local fields = ns.D.REPORT_FIELDS
        ns.D.REPORT_FIELDS = { { pattern = "^## SmartBlessingBar bug report$" } }
        assert.is_false(pcall(assertClean, ns, build(ns, "OTHER")), "the field check")
        ns.D.REPORT_FIELDS = fields
    end)

    -- The gaps SimpleConjureBar's security audit found in the free-text filter (its S-01 to S-03)
    it("filters spaced paths, e-mail, the WTF folder, account folders and hidden name joins", function()
        local ns = login()
        local names = { "Testplayer" }
        local cases = {
            { "C:\\Users\\John Doe\\Games\\x.lua:12: boom", "Doe", "<path>:12: boom" },
            { "see /home/John Doe/wow", "Doe", "see <path>" },
            { "see /Users/Jane Roe/wow", "Roe", "see <path>" },
            { "\\\\server\\share\\John Doe\\x", "Doe", "<path>" },
            { "on /Volumes/Data Disk/wow", "Disk", "on <path>" },
            { "in /Applications/World of Warcraft/x", "World", "in <path>" },
            { "write john.doe+wow@example.com now", "john", "write <email> now" },
            { "WTF\\Account\\MYACCOUNT\\SavedVariables\\x.lua", "MYACCOUNT", "<wtf>" },
            { "wtf/Account/MYACCOUNT/x", "MYACCOUNT", "<wtf>" },
            { "folder 12345678#1 here", "12345678", "folder <tag> here" },
            { "Testplayer\226\128\139 did it", "Testplayer", "<name> did it" },       -- U+200B
            { "Testplayer\226\128\153s bar", "Testplayer", "<name>\226\128\153s bar" }, -- U+2019
            { "\226\128\152Testplayer\226\128\153", "Testplayer", "<name>" },
            { "with\194\160Testplayer\194\160too", "Testplayer", "<name>" },          -- U+00A0
            { "Tes\226\129\160tplayer", "Tes", "<name>" },                              -- U+2060
            { "Testplayer\243\160\128\129", "Testplayer", "<name>" },                  -- U+E0001
        }
        for _, c in ipairs(cases) do
            local out = ns.Scrub(c[1], names)
            assert.is_nil(out:find(c[2], 1, true), c[1] .. " -> " .. out)
            assert.is_truthy(out:find(c[3], 1, true), c[1] .. " -> " .. out)
        end
        assert.are.equal("see https://github.com/x and a: b", ns.Scrub("see https://github.com/x and a: b", names))
        -- a name inside a longer word is no name
        assert.are.equal("Testplayerish and Untestplayer", ns.Scrub("Testplayerish and Untestplayer", names))
        assert.are.equal("Interface/AddOns/SmartBlessingBar/Bar.lua:10: x",
            ns.Scrub("C:\\Program Files\\World of Warcraft\\_forever_\\Interface\\AddOns\\SmartBlessingBar\\Bar.lua:10: x", names))
    end)

    -- The 1.1.0 audit's S-01, case by case
    it("replaces names beside non-ASCII punctuation, in text without spaces and in any case", function()
        local ns = login()
        local names = { "Testplayer", "张三", "철수", "Иван", "Tèstname" }
        local cases = {
            { "„Testplayer“ hat", "„<name>“ hat" },
            { "¡Testplayer! ¿Testplayer?", "¡<name>! ¿<name>?" },
            { "«Testplayer» ‹Testplayer›", "«<name>» ‹<name>›" },
            { "Testplayer… then Testplayer—and x–Testplayer a·Testplayer", "<name>… then <name>—and x–<name> a·<name>" },
            { "Testplayer　x Testplayer，x", "<name>　x <name>，x" },
            { "我和张三一起", "我和<name>一起" },
            { "철수가 x", "<name>가 x" },
            { "ИВАН x иван", "<name> x <name>" },
            { "TÈSTNAME x tèstname", "<name> x <name>" },
            { "Testplayer Secondname", "<name> Secondname" },
        }
        for _, c in ipairs(cases) do
            assert.are.equal(c[2], ns.Scrub(c[1], names), c[1])
        end
        -- a name inside a longer word of a spaced script stays a word, before or after it
        assert.are.equal("Testplayerish Иванов Tèstnameé çTestplayer жИван", ns.Scrub("Testplayerish Иванов Tèstnameé çTestplayer жИван", names))
        -- the fold covers Latin-1 and basic Cyrillic only, as README says
        assert.are.equal("łukasz <name>", ns.Scrub("łukasz ÉMILE", { "Łukasz", "Émile" }))
    end)

    -- The 1.1.0 audit's S-02 and S-03 and the code review's F-01
    it("filters a second path on a line, more home folders, and hidden marks inside a name", function()
        local ns = login()
        local names = { "Testplayer" }
        local cases = {
            { "C:\\Users\\JohnRoe\\a.lua:1: in C:\\Users\\JohnRoe\\b.lua:2", { "JohnRoe" }, "<path>:1: in <path>:2" },
            { "C:\\Users\\Jane Doe\\Desktop\\a.lua:1: in C:\\Users\\Jane Doe\\b.lua:2", { "Jane", "Doe" },
              "<path>:1: in <path>:2" },
            { "/Users/janedoe/a.lua:3: then /Users/janedoe/b.lua:4", { "janedoe" }, "<path>:3: then <path>:4" },
            { "x \\\\SERVER\\JaneDoe\\f.lua:5: and \\\\SERVER\\JaneDoe\\g.lua", { "JaneDoe" }, "x <path>:5: and <path>" },
            { "D:\\x.lua:5: see C:\\Users\\Jane Roe\\f", { "Jane Roe" }, "<path>:5: see <path>" },
            { "on /media/janeroe/Games/wow", { "janeroe" }, "on <path>" },
            { "on /run/media/janeroe/wow", { "janeroe" }, "on <path>" },
            { "in Users\\Jane Roe\\Games", { "Jane Roe" }, "in <path>" },
            { "write jérôme@example.ch now", { "jérôme", "j\195" }, "write <email> now" },
            { "Testplayer\239\184\143 x", { "Testplayer" }, "<name> x" },       -- U+FE0F
            { "Testplayer\204\129 x", { "Testplayer" }, "<name> x" },           -- U+0301
            { "Test\205\143player x", { "Test" }, "<name> x" },                 -- U+034F
            { "Test\227\133\164player x", { "Test" }, "<name> x" },             -- U+3164
            { "Test\240\147\145\128player x", { "Test" }, "<name> x" },         -- U+13440
            { "Test\240\147\145\149player x", { "Test" }, "<name> x" },         -- U+13455
        }
        -- an error text with hundreds of paths on one line: no stack overflow, every path gone
        local many = ns.Scrub(("C:\\a.lua:1: "):rep(400) .. ("\\\\:1"):rep(300), names)
        assert.is_nil(many:find("C:\\", 1, true))
        assert.is_nil(many:find("\\\\", 1, true))
        for _, c in ipairs(cases) do
            local out = ns.Scrub(c[1], names)
            for _, bad in ipairs(c[2]) do
                assert.is_nil(out:find(bad, 1, true), c[1] .. " -> " .. out)
            end
            assert.are.equal(c[3], out, c[1])
        end
    end)

    it("knows both of the player's Forever names, pets and the target's target", function()
        local ns = login()
        STATE.units.player = { name = "Firstname", surname = "Secondname", class = "PALADIN" }
        STATE.units.pet = { name = "Petname" }
        STATE.units.targettarget = { name = "Totguy" }
        STATE.units.partypet2 = { name = "Partypet" }
        STATE.units.raidpet7 = { name = "Raidpet" }
        local names = table.concat(ns.KnownNames(), " ")
        for _, n in ipairs({ "Firstname", "Secondname", "Firstname-Secondname", "Petname", "Totguy",
                "Partypet", "Raidpet" }) do
            assert.is_truthy(names:find(n, 1, true), n)
        end
    end)

    it("builds no report while a name is secret", function()
        local ns = login()
        STATE.secretName = true
        assert.is_nil(build(ns, "OTHER", "x"))
    end)
end)

---------------------------------------------------------------------------
-- Errors, log, state, size (plan criterion 2)
---------------------------------------------------------------------------
describe("the report's errors", function()
    it("dates nothing: times are relative to now and to the addon loading", function()
        local ns = login()
        STATE.now = (STATE.now or 0) + 600
        grabber({ ourError(time() - 90, 1) }, 1)
        local text = build(ns, "OTHER")
        assert.is_nil(text:find("Date:", 1, true), text)
        assert.is_truthy(text:find("2 min ago, 510 s after load", 1, true), text)
        -- the clock starts when the addon loads: after a /reload, not at login (review F-10)
        assert.is_truthy(text:find("**Last actions (seconds since load):**", 1, true), text)
    end)

    it("says whether an error came in combat, and keeps earlier sessions out", function()
        local ns = login()
        STATE.now = (STATE.now or 0) + 100
        FIRE("PLAYER_REGEN_DISABLED"); STATE.combat = true
        local inCombat = time()
        STATE.now = STATE.now + 10
        STATE.combat = false; FIRE("PLAYER_REGEN_ENABLED")
        STATE.now = STATE.now + 100
        grabber({
            ourError(inCombat, 3, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:1: in combat" }),
            ourError(time() - 5, 3, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:2: out of combat" }),
            ourError(time() - 99999, 3, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:3: before the log" }),
            ourError(time() - 50, 2, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:4: earlier session" }),
        }, 3)
        local text = build(ns, "OTHER")
        local function flagOf(what)
            for block in text:gmatch("Error %d+ %b()") do
                local _, finish = text:find(block, 1, true)
                if text:sub(finish, finish + 200):find(what, 1, true) then return block:match("combat: (%a+)") end
            end
        end
        assert.are.equal("yes", flagOf("in combat"))
        assert.are.equal("no", flagOf("out of combat"))
        assert.are.equal("unknown", flagOf("before the log"))
        assert.is_nil(text:find("earlier session", 1, true))
    end)

    it("takes only this addon's errors, the newest five, with at most 12 stack lines", function()
        local ns = login()
        local errors = { ourError(time(), 1, { message = "OtherAddon broke", stack = "" }) }
        for i = 1, 7 do errors[#errors + 1] = ourError(time(), 1, { message = "SmartBlessingBar error " .. i }) end
        local long = {}
        for i = 1, 20 do long[i] = "line" .. i end
        errors[#errors + 1] = ourError(time(), 1, { message = "SmartBlessingBar error 8",
            stack = table.concat(long, "\n"), counter = 3 })
        grabber(errors, 1)
        local text = build(ns, "OTHER")
        assert.is_nil(text:find("OtherAddon", 1, true))
        assert.is_truthy(text:find("Error 1 (x3", 1, true)) -- newest first
        assert.is_truthy(text:find("error 4", 1, true))
        assert.is_nil(text:find("error 3", 1, true))
        assert.is_truthy(text:find("at line12\nat ...", 1, true))
        assert.is_nil(text:find("line13", 1, true))
    end)

    it("says when BugGrabber is not installed", function()
        local ns = login({ bugGrabber = false })
        _G.BugGrabber = nil
        assert.is_truthy(build(ns, "OTHER"):find("BugGrabber/BugSack not installed", 1, true))
    end)

    it("stays under 20,000 bytes, cut at a whole character", function()
        local ns = login()
        local errors = {}
        for i = 1, 5 do
            local lines = {}
            for j = 1, 200 do lines[j] = ("v%d=%d"):format(j, j) end
            errors[i] = ourError(time(), 1, { message = ("Interface/AddOns/SmartBlessingBar/Bar.lua:%d: %s"):format(i, ("ü"):rep(3000)),
                locals = table.concat(lines, "\n") })
        end
        grabber(errors, 1)
        local text = build(ns, "OTHER", ("ä"):rep(500), ("ö"):rep(500))
        assert.is_true(#text <= 20000, #text)
        assert.is_truthy(text:find(ns.D.REPORT_CUT, 1, true))
        assert.is_true(validUtf8(text))
    end)
end)

-- A press as the client delivers it: down, then up
local function press(button, mouse)
    RUNCLICK(button, mouse or "LeftButton", true)
    RUNCLICK(button, mouse or "LeftButton", false)
end

local function clicks(ns)
    local found = {}
    for _, l in ipairs(ns.LogLines()) do
        local what = l:match("^%S+ (click .*)$")
        if what then found[#found + 1] = what end
    end
    return found
end

describe("the action log", function()
    it("keeps one entry per press, with the key-down setting on and off", function()
        for _, keyDown in ipairs({ false, true }) do
            local ns = login()
            STATE.keyDown = keyDown
            press(ns.auraButton)
            press(ns.blessingButton, "RightButton")
            local found = clicks(ns)
            assert.are.equal(2, #found, table.concat(found, " | "))
            assert.is_truthy(found[1]:find("^click AURA LeftButton"))
            assert.is_truthy(found[2]:find("^click BLESSING RightButton"))
            STATE.keyDown = true
        end
    end)

    it("logs a Buff & Run click as one blessing and one hidden-button entry", function()
        local ns = login()
        STATE.known[ns.D.BLESSINGS.WISDOM.normal[1]] = true
        STATE.units.target = { class = "MAGE" }
        STATE.friends = { { class = "ROGUE" } }
        press(ns.blessingButton, "MiddleButton")
        local found = clicks(ns)
        assert.are.equal(2, #found, table.concat(found, " | "))
        -- the macro's nested click acts inside the blessing click, so it is logged first
        assert.is_truthy(found[1]:find("^click SmartBlessingBarBuffRun LeftButton type=spell spell=%d+ unit=target"), found[1])
        assert.is_truthy(found[2]:find("^click BLESSING MiddleButton"), found[2])
    end)

    it("holds the last 50 in order", function()
        local ns = login()
        for _ = 1, 60 do press(ns.auraButton) end
        assert.are.equal(50, #ns.LogLines())
        assert.are.equal(50, #clicks(ns))
    end)

    it("never stops a click when a log write fails", function()
        local ns = login()
        STATE.known[ns.D.AURAS.DEVOTION[1]] = true
        ns.Refresh()
        local clock = _G.time
        _G.time = function() error("broken clock") end -- every write reads it
        local before = #STATE.casts
        press(ns.auraButton)
        assert.are.equal(before + 1, #STATE.casts)
        assert.are.same({}, STATE.errors)
        _G.time = clock
        ns.Log("an entry")
        ns.LogFormat = function() error("broken format") end
        assert.are.equal("?", ns.LogLines()[1])
    end)

    it("logs changed settings, combat and the group size", function()
        local ns, db = login()
        ns.ToggleSettings()
        db.renewMinutes = 7
        ns.ToggleSettings()
        assert.is_truthy(contains(ns.LogLines(), " setting renewMinutes=7$"))
        SlashCmdList.SMARTBLESSINGBAR("lock")
        assert.is_truthy(contains(ns.LogLines(), " setting locked=true$"))
        FIRE("PLAYER_REGEN_DISABLED"); STATE.combat = true
        assert.are.equal("yes", ns.CombatAt(time()))
        STATE.combat = false; FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal("unknown", ns.CombatAt(time() - 3600))
        STATE.group = "party"
        STATE.units.party1 = { class = "PRIEST" }
        FIRE("GROUP_ROSTER_UPDATE")
        local lines = ns.LogLines()
        assert.is_truthy(contains(lines, "combat start"))
        assert.is_truthy(contains(lines, "combat end"))
        assert.is_truthy(contains(lines, " group party size="))
    end)
end)

describe("the state snapshot", function()
    it("lists the four buttons, the keys, both queues, Symbols, group, buffs and flags", function()
        local ns = login()
        local D = ns.D
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0 } }
        STATE.bags[D.SYMBOL_OF_KINGS] = 12
        local lines = ns.StateSnapshot()
        for _, key in ipairs(D.DEFAULT_ORDER) do
            assert.is_truthy(contains(lines, "^button " .. key .. " "), key)
        end
        assert.is_truthy(contains(lines, "^button SmartBlessingBarBuffAll "))
        local run = contains(lines, "^button BLESSING ")
        assert.is_truthy(run:find("macrotext3=/click SmartBlessingBarBuffRun LeftButton 1 / /targetfriendplayer", 1, true), run)
        assert.is_truthy(contains(lines, "^queue BLESSING left=%d+ held=%d+ far=%d+$"))
        assert.is_truthy(contains(lines, "^queue SALVATION left=%d+ held=%d+ far=%d+$"))
        assert.is_truthy(contains(lines, "^symbols 12$"))
        assert.is_truthy(contains(lines, "^group solo size=1 PALADIN=1$"))
        assert.is_truthy(contains(lines, "^buffs " .. D.AURAS.DEVOTION[1] .. ":%-$"))
        assert.is_truthy(contains(lines, "^auras readable=yes$"))
        assert.is_truthy(contains(lines, "^demo no$"))
        assert.is_truthy(contains(lines, "^keydown 1$"))
        assert.is_truthy(contains(lines, "^combat no$"))
    end)
end)

-- The 1.1.0 review's F-06 and F-05 and the audit's S-05
describe("the report's own values", function()
    it("leave a secret buff out, and say when buffs cannot be read", function()
        local ns = login()
        local D = ns.D
        local hidden = D.AURAS.RETRIBUTION[1]
        STATE.units.player.auras = { { spellId = hidden, expirationTime = 0 },
            { spellId = D.AURAS.DEVOTION[1], expirationTime = 0 } }
        STATE.secrets = { [hidden] = true }
        assert.is_truthy(contains(ns.StateSnapshot(), "^buffs " .. D.AURAS.DEVOTION[1] .. ":%-$"))
        STATE.secrets = nil
        STATE.aurasSecret = true
        assert.is_truthy(contains(ns.StateSnapshot(), "^buffs unreadable$"))
    end)

    it("report the addon language through the allowlist", function()
        local ns = login()
        SmartBlessingBarGlobalDB.language = "Testplayer"
        assert.is_truthy(build(ns, "OTHER"):find("addon language: <text:10>", 1, true))
    end)

    it("filter the realm in both spellings, a two-letter name, and a name with its second name whole", function()
        local ns = login()
        STATE.realm, STATE.normalizedRealm = "Twin Peaks", "TwinPeaks"
        STATE.units.player = { name = "Testplayer", surname = "Testsecond", class = "PALADIN" }
        STATE.units.party1 = { name = "Al", class = "MAGE" }
        STATE.group = "party"
        local names = ns.KnownNames()
        assert.are.equal("<name> and <name> and <name> hit <name> on <name>",
            ns.Scrub("Twin Peaks and TwinPeaks and Al hit Testplayer-Testsecond on Testsecond", names))
    end)

    it("take errors without a session number only from after the addon loaded", function()
        local ns = login()
        STATE.now = (STATE.now or 0) + 100
        _G.BugGrabber = { GetDB = function() return {
            ourError(time() - 99999, nil, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:1: before" }),
            ourError(time() - 5, nil, { message = "Interface/AddOns/SmartBlessingBar/Bar.lua:2: after" }),
        } end }
        local text = build(ns, "OTHER")
        assert.is_truthy(text:find("after", 1, true), text)
        assert.is_nil(text:find("before", 1, true), text)
    end)

    it("filter names and paths in the loaded addons", function()
        local ns = login()
        STATE.units.player = { name = "Testplayer", class = "PALADIN" }
        STATE.addons = { { name = "Testplayer_Tools", version = "C:\\Users\\JohnRoe\\x", loaded = true },
            { name = "Testplayer", version = "1.0", loaded = true } }
        local text = build(ns, "OTHER")
        assert.is_nil(text:find("JohnRoe", 1, true), text)
        assert.is_truthy(text:find("addon <name> 1.0", 1, true), text)
    end)
end)

describe("the loaded addons", function()
    it("are listed by folder name and version, at most 60", function()
        local ns = login()
        STATE.addons = {}
        for i = 1, 65 do STATE.addons[i] = { name = "Addon" .. i, version = "1.0.0", loaded = i ~= 3 } end
        local lines = ns.AddonList()
        assert.are.equal(61, #lines) -- 60 and the count of the rest
        assert.are.equal("Addon1 1.0.0", lines[1])
        assert.is_nil(contains(lines, "^Addon3 "))
        assert.is_truthy(lines[61]:find("4 more", 1, true))
    end)
end)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
describe("the bug report window", function()
    it("opens from /sbb bug and from General, and replaces the settings window", function()
        local ns = login()
        SlashCmdList.SMARTBLESSINGBAR("")
        assert.is_true(ns.UI.window:IsShown())
        RUNSCRIPT(ns.UI.controls.reportBug, "OnClick")
        assert.is_true(ns.reportWindow:IsShown())
        assert.is_false(ns.UI.window:IsShown())
        assert.are.same({}, STATE.errors)

        local again = login()
        SlashCmdList.SMARTBLESSINGBAR("bug")
        assert.is_true(again.reportWindow:IsShown())
    end)

    it("carries the area key and both texts, and offers every area", function()
        local ns = login()
        grabber({}, 1)
        ns.OpenBugReport()
        local f = ns.reportWindow
        f.desc:SetText("The aura button does nothing"); RUNSCRIPT(f.desc, "OnTextChanged", true)
        f.details:SetText("after a reload in combat"); RUNSCRIPT(f.details, "OnTextChanged", true)
        local entries = MENU(f.areaMenu)
        assert.are.equal(#ns.D.REPORT_AREAS, #entries)
        for i, key in ipairs(ns.D.REPORT_AREAS) do
            assert.are.equal(ns.ReportAreaText(key), entries[i].text)
            assert.is_truthy(entries[i].text and entries[i].text ~= "", key)
        end
        assert.is_true(entries[#entries].selected) -- OTHER until one is chosen
        entries[3].pick()                           -- AURA
        local text = f.BuildText()
        assert.is_truthy(text:find("**Area:** AURA", 1, true), text)
        assert.is_truthy(text:find("The aura button does nothing", 1, true))
        assert.is_truthy(text:find("after a reload in combat", 1, true))
        assert.are.equal(ns.ReportCode.Encode(text), f.report:GetText())
    end)

    it("names the areas in the language just switched to", function()
        local ns = login()
        ns.OpenBugReport()
        local menu = ns.reportWindow.areaMenu
        local before = rawget(menu, "generated") or 0
        ns.ApplyLanguage("deDE")
        assert.is_true((rawget(menu, "generated") or 0) > before)
        assert.are.equal(ns.locales.deDE.AREA_OTHER, MENU(menu)[#ns.D.REPORT_AREAS].text)
    end)

    it("does not open in combat, closes when combat starts and comes back after it", function()
        local ns = login()
        grabber({}, 1)
        _G.CHAT = {}
        STATE.combat = true
        ns.OpenBugReport()
        assert.is_false(ns.reportWindow:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.REPORT_COMBAT, 1, true))
        STATE.combat = false
        ns.OpenBugReport()
        assert.is_true(ns.reportWindow:IsShown())
        FIRE("PLAYER_REGEN_DISABLED")
        assert.is_false(ns.reportWindow:IsShown())
        FIRE("PLAYER_REGEN_ENABLED"); RUNTIMERS()
        assert.is_true(ns.reportWindow:IsShown())
    end)

    it("keeps the window shut while a name is secret, and keeps the last clean report", function()
        local ns = login()
        grabber({}, 1)
        _G.CHAT = {}
        STATE.secretName = true
        ns.OpenBugReport()
        assert.is_false(ns.reportWindow:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.REPORT_SECRET, 1, true))
        STATE.secretName = false
        ns.OpenBugReport()
        local f = ns.reportWindow
        local before = f.report:GetText()
        STATE.secretName = true
        f.desc:SetText("Aldric saw it"); RUNSCRIPT(f.desc, "OnTextChanged", true)
        assert.are.equal(before, f.report:GetText())
        -- the review's F-11: one line in chat however much is typed, again once it changes back
        local said = #CHAT
        for i = 1, 10 do f.desc:SetText("typed " .. i); RUNSCRIPT(f.desc, "OnTextChanged", true) end
        assert.are.equal(said, #CHAT)
        STATE.secretName = false
        f.desc:SetText("clean"); RUNSCRIPT(f.desc, "OnTextChanged", true)
        STATE.secretName = true
        f.desc:SetText("secret again"); RUNSCRIPT(f.desc, "OnTextChanged", true)
        assert.are.equal(said + 1, #CHAT)
    end)

    it("says what the report holds and that an issue is public", function()
        local ns = login()
        ns.OpenBugReport()
        local f = ns.reportWindow
        assert.are.equal(ns.L.REPORT_PRIVACY, f.privacy:GetText())
        assert.are.equal(ns.L.REPORT_PUBLIC, f.public:GetText())
    end)

    it("is listed by /sbb help", function()
        local ns = login()
        SlashCmdList.SMARTBLESSINGBAR("help")
        local found = false
        for _, line in ipairs(CHAT) do
            if line:find("/sbb bug", 1, true) and line:find(ns.L.CMD_BUG, 1, true) then found = true end
        end
        assert.is_true(found)
    end)
end)
