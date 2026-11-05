-- How much one refresh reads (ruleset plan 2026-10-20-performance-pvp, criterion 1): each
-- person's buffs at most once per filter, each spell's "known" at most once - also with the
-- overview open. The mock counts per person, so `player` and `raid1` are one.

local addon = require("addon")

local D = addon.load("enUS").D

-- Every spell the addon casts
local function everySpell()
    local set = { [D.SALVATION] = true, [D.MASS_SALVATION] = true, [D.REVOKE] = true, [D.RIGHTEOUS_FURY] = true }
    for _, f in pairs(D.BLESSINGS) do
        for _, id in ipairs(f.normal) do set[id] = true end
        for _, id in ipairs(f.greater) do set[id] = true end
    end
    for _, list in pairs(D.AURAS) do
        for _, id in ipairs(list) do set[id] = true end
    end
    return set
end

-- A 40-player raid of every class, the player raid1; each carries Kings from another
-- paladin and my Salvation; every rank known, Symbols in the bags; the Priorities tab open
local function raid()
    local units = {}
    for i = 1, 40 do
        units["raid" .. i] = { class = D.CLASS_ORDER[(i - 1) % #D.CLASS_ORDER + 1], subgroup = math.ceil(i / 5),
            auras = { { spellId = D.BLESSINGS.KINGS.normal[1], expirationTime = 3600, source = "raid2" },
                      { spellId = D.SALVATION, expirationTime = 3600, mine = true } } }
    end
    units.raid1.class = "PALADIN"
    units.player = units.raid1
    local ns = addon.load("enUS", { group = "raid", units = units })
    STATE.known = everySpell()
    STATE.bags = { [D.SYMBOL_OF_KINGS] = 20 }
    FIRE("PLAYER_LOGIN")
    ns.OpenSettingsOn("TAB_PRIORITIES")
    -- the members' snapshots kept since login (ruleset plan 2026-10-24-kept-snapshots) dropped,
    -- so the refresh reads everyone
    FIRE("GROUP_ROSTER_UPDATE")
    STATE.scans, STATE.spellChecks = {}, {}
    return ns
end

local function most(counts)
    local n = 0
    for _, c in pairs(counts or {}) do
        if type(c) == "table" then
            for _, v in pairs(c) do n = math.max(n, v) end
        else
            n = math.max(n, c)
        end
    end
    return n
end

describe("one refresh in a 40-player raid", function()
    it("scans each person's buffs at most once per filter, the overview open", function()
        local ns = raid()
        ns.Refresh()
        assert.is_true(ns.overview.rows[40]:IsShown()) -- the overview was built
        assert.are.equal(1, most(STATE.scans))
        assert.are.same({}, STATE.errors)
    end)

    it("asks whether a spell is known at most once", function()
        local ns = raid()
        ns.Refresh()
        assert.are.equal(1, most(STATE.spellChecks))
    end)

    -- Demo mode plans as if nobody carried anything; only the aura button reads the player's
    -- real buffs
    it("in demo mode scans only the player's buffs, and plans as if he carried none", function()
        local ns = raid()
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        for r in pairs(STATE.scans) do assert.are.equal(STATE.units.player, r) end
        local counts = { ns.blessingButton.count:GetText(), ns.salvationButton.count:GetText() }
        STATE.units.player.auras = {}
        ns.Refresh()
        assert.are.same(counts, { ns.blessingButton.count:GetText(), ns.salvationButton.count:GetText() })
    end)
end)

-- A spell's level comes from data the client may not have loaded yet (code.md): nil is no
-- answer to keep
describe("a spell's level", function()
    it("is asked again when the client first gave none", function()
        local ns = addon.load("enUS", addon.mightFirst({ group = "party",
            units = { party1 = { class = "WARRIOR", level = 1 } } }))
        local might = D.BLESSINGS.MIGHT.normal
        STATE.known = {}
        for _, id in ipairs(might) do STATE.known[id] = true end
        FIRE("PLAYER_LOGIN")
        local function forParty1()
            for _, e in ipairs((ns.Blessings.PlanBlessings())) do
                if e.unit == "party1" then return e.spell end
            end
        end
        assert.are.equal(might[#might], forParty1()) -- no level known: no limit
        STATE.learned = {}
        for i, id in ipairs(might) do STATE.learned[id] = i == 1 and 4 or 20 + i end
        assert.are.equal(might[1], forParty1())
    end)
end)

-- A read an error broke off must not serve its old snapshot to the next click or build
describe("a read broken off by an error", function()
    it("is closed, so the next read scans fresh", function()
        local ns = addon.load("enUS", addon.mightFirst())
        STATE.known = { [D.BLESSINGS.MIGHT.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        local B, plan = ns.Blessings, ns.Blessings.PlanBlessings
        -- a stranger as target: no snapshot of his outlives a read
        STATE.units.target = { class = "MAGE" }
        B.PlanBlessings = function() B.Auras("target") error("broken") end
        pcall(ns.Refresh)
        B.PlanBlessings = plan
        STATE.scans = {}
        B.WithRead(function() B.Auras("target") end)
        assert.are.equal(1, (STATE.scans[STATE.units.target] or {}).HELPFUL)
    end)
end)

-- An error in a read goes on, with the stack where it happened: a rethrow alone would show
-- BugSack only the rethrow (the client's debugstack, the mock's "STACK")
describe("an error inside a read", function()
    it("goes on, carrying the stack where it happened", function()
        local ns = addon.load("enUS")
        local ok, err = pcall(ns.Blessings.WithRead, function() error("boom") end)
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find("boom", 1, true))
        assert.is_truthy(tostring(err):find("STACK", 1, true))
    end)
end)
