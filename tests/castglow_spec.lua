-- A cast in combat ends its button's glow (ruleset plan 2026-10-25-rank-glow-fixes): auras are
-- unreadable in combat, so the refresh waits for its end, but the cast event says what was
-- cast - or, while the client keeps its spell ID secret, a left click just before it.

local addon = require("addon")

local D = addon.load("enUS").D
local M = D.BLESSINGS.MIGHT

-- A paladin tank with a mage in the party: the aura, Fury, blessing and Salvation buttons glow
local function login()
    local ns = addon.load("enUS", { group = "party", units = {
        player = { class = "PALADIN", role = "TANK" }, party1 = { class = "MAGE" } } })
    STATE.known = { [D.AURAS.DEVOTION[1]] = true, [D.RIGHTEOUS_FURY] = true, [D.SALVATION] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    STATE.now = 100
    FIRE("PLAYER_LOGIN"); RUNTIMERS()
    ns.Refresh()
    return ns
end

local function glows(ns)
    return { aura = ns.auraButton.antsShown, fury = ns.furyButton.antsShown,
             blessing = ns.blessingButton.antsShown, salvation = ns.salvationButton.antsShown }
end

local function fight()
    FIRE("PLAYER_REGEN_DISABLED")
    STATE.combat = true
end

local function cast(id) FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", id) end

describe("a cast in combat", function()
    it("ends only its own button's glow", function()
        local ns = login()
        assert.are.same({ aura = true, fury = true, blessing = true, salvation = true }, glows(ns))
        fight()
        cast(D.AURAS.DEVOTION[1])
        assert.are.same({ aura = false, fury = true, blessing = true, salvation = true }, glows(ns))
        cast(D.RIGHTEOUS_FURY)
        assert.are.same({ aura = false, fury = false, blessing = true, salvation = true }, glows(ns))
        cast(ns.blessingButton.head.spell)
        assert.are.same({ aura = false, fury = false, blessing = false, salvation = true }, glows(ns))
        assert.are.same({}, STATE.errors)
    end)

    it("changes nothing out of combat, or for a spell of no button", function()
        local ns = login()
        cast(D.AURAS.DEVOTION[1])
        fight()
        cast(12345)
        assert.are.same({ aura = true, fury = true, blessing = true, salvation = true }, glows(ns))
    end)

    it("with a secret spell ID counts a left click just before it, nothing else", function()
        local ns = login()
        fight()
        local id = ns.blessingButton.head.spell
        STATE.secrets = { [id] = true }
        cast(id) -- no press at all
        assert.is_true(ns.blessingButton.antsShown)
        RUNCLICK(ns.blessingButton, "MiddleButton", false)
        cast(id)
        assert.is_true(ns.blessingButton.antsShown)
        RUNCLICK(ns.blessingButton, "LeftButton", false)
        STATE.now = STATE.now + 2
        cast(id) -- the press is 2 s old
        assert.is_true(ns.blessingButton.antsShown)
        RUNCLICK(ns.blessingButton, "LeftButton", false)
        STATE.now = STATE.now + 0.5
        cast(id)
        assert.is_false(ns.blessingButton.antsShown)
        assert.is_true(ns.salvationButton.antsShown)
    end)

    it("counts a press of the buff key for the button whose action it carries", function()
        local ns = login()
        fight()
        local id = D.AURAS.DEVOTION[1] -- the aura button comes first in the bar's order
        STATE.secrets = { [id] = true }
        RUNCLICK(ns.buffKey, "LeftButton", false)
        cast(id)
        assert.is_false(ns.auraButton.antsShown)
        assert.is_true(ns.blessingButton.antsShown)
    end)

    it("stays dark after combat while auras are secret, and glows again once they are read", function()
        local ns = login()
        fight()
        cast(ns.blessingButton.head.spell)
        STATE.aurasSecret = true
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED"); RUNTIMERS()
        assert.is_false(ns.blessingButton.antsShown)
        STATE.aurasSecret = false
        ns.Refresh()
        assert.is_true(ns.blessingButton.antsShown) -- the blessing never landed
    end)
end)
