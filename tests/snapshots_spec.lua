-- Buff snapshots kept between refreshes (ruleset plan 2026-10-24-kept-snapshots): a group
-- member's buffs are scanned again only after his UNIT_AURA, a roster change, a loading screen
-- or 10 s; anyone else is scanned once per read, as before. The mock counts scans per person.

local addon = require("addon")

local D = addon.load("enUS").D
local W = D.BLESSINGS.WISDOM

local function login(units, group)
    local ns = addon.load("enUS", { group = group, units = units })
    STATE.known = { [W.normal[1]] = true, [D.BLESSINGS.KINGS.normal[1]] = true,
        [D.BLESSINGS.MIGHT.normal[1]] = true, [D.AURAS.DEVOTION[1]] = true }
    STATE.now = 100
    FIRE("PLAYER_LOGIN"); RUNTIMERS()
    ns.Refresh()
    STATE.scans = {}
    return ns
end

-- Every scan of one person, both filters together
local function scansOf(record)
    local n = 0
    for _, c in pairs((STATE.scans or {})[record] or {}) do n = n + c end
    return n
end

local function total()
    local n = 0
    for record in pairs(STATE.scans or {}) do n = n + scansOf(record) end
    return n
end

local function party()
    local units = {}
    for i = 1, 4 do units["party" .. i] = { class = D.CLASS_ORDER[i], guid = "Player-1-" .. i } end
    return units
end

local function kept(ns)
    for _, l in ipairs(ns.StateSnapshot()) do
        local n = l:match("^snapshots (%d+)$")
        if n then return tonumber(n) end
    end
end

describe("kept buff snapshots", function()
    it("let a second refresh a second later scan nobody, alone and in a party", function()
        for _, world in ipairs({ { nil, nil }, { party(), "party" } }) do
            local ns = login(world[1], world[2])
            STATE.now = STATE.now + 1
            ns.Refresh()
            assert.are.equal(0, total())
        end
    end)

    it("scan the player alone at most every 10 s over 30 s of the ticker", function()
        login()
        for _ = 1, 30 do
            STATE.now = STATE.now + 1
            TICK()
        end
        assert.is_true(scansOf(STATE.units.player) <= 4 * 2, scansOf(STATE.units.player)) -- two filters a scan
        assert.are.same({}, STATE.errors)
    end)

    it("scan a member again after his UNIT_AURA only, everyone after a roster change, a loading screen or 11 s", function()
        local ns = login(party(), "party")
        local p1, p2 = STATE.units.party1, STATE.units.party2
        FIRE("UNIT_AURA", "party1")
        ns.Refresh()
        assert.is_true(scansOf(p1) > 0)
        assert.are.equal(0, scansOf(p2))
        for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
            STATE.scans = {}
            FIRE(event); RUNTIMERS()
            ns.Refresh()
            assert.is_true(scansOf(p2) > 0, event)
        end
        STATE.scans = {}
        STATE.now = STATE.now + 11
        ns.Refresh()
        assert.is_true(scansOf(p2) > 0, "11 s")
    end)

    it("use a member's kept list when he is the target, and follow a blessing his UNIT_AURA reports", function()
        local ns = login(party(), "party")
        local p1 = STATE.units.party1
        STATE.units.target = p1
        ns.Blessings.WithRead(function() return ns.Blessings.BuffRunSpell("target") end)
        assert.are.equal(0, scansOf(p1))
        local before = ns.blessingButton.left
        assert.is_true(before > 0)
        local spell = ns.blessingButton.head.spell
        local unit = ns.blessingButton.head.unit
        STATE.units[unit].auras = { { spellId = spell, expirationTime = STATE.now + 3600, mine = true } }
        FIRE("UNIT_AURA", unit)
        ns.Refresh()
        assert.are.equal(before - 1, ns.blessingButton.left)
    end)
end)

describe("people outside the group", function()
    it("are scanned on each read: a stranger just blessed is seen with it, targeted again within 10 s", function()
        local ns = login()
        local a = { class = "MAGE", guid = "Player-1-A" }
        local b = { class = "ROGUE", guid = "Player-1-B" }
        STATE.units.target = a
        local B = ns.Blessings
        assert.is_not_nil(B.WithRead(function() return B.BuffRunSpell("target") end))
        STATE.units.target = b
        a.auras = { { spellId = W.normal[1], expirationTime = STATE.now + 3600, mine = true } } -- no UNIT_AURA
        STATE.now = STATE.now + 3
        STATE.units.target = a
        assert.is_nil(B.WithRead(function() return B.BuffRunSpell("target") end))
    end)

    it("are never kept, and a member whose GUID is secret is scanned each read", function()
        local ns = login(party(), "party")
        local B = ns.Blessings
        for i = 1, 20 do
            STATE.units.target = { class = "MAGE", guid = "Player-9-" .. i }
            B.WithRead(function() return B.BuffRunSpell("target") end)
        end
        assert.are.equal(5, kept(ns)) -- the player and four members
        STATE.secrets = { ["Player-1-1"] = true }
        STATE.scans = {}
        ns.Refresh()
        STATE.now = STATE.now + 1
        ns.Refresh()
        assert.are.equal(2 * 2, scansOf(STATE.units.party1))
    end)
end)
