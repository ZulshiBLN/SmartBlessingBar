-- Values the game may keep secret are checked before they are tested (ruleset plan
-- 2026-11-05-report-filter-guards). A truth test on a secret value raises in the client; Lua 5.1
-- cannot trap it and the mock's secrets compare freely, so these rows change a value's answer.
-- secretorder_spec.lua reads the source for the rest.

local addon = require("addon")

local D = addon.load("enUS").D
local M = D.BLESSINGS.MIGHT
local DEVOTION, RETRIBUTION = D.AURAS.DEVOTION[1], D.AURAS.RETRIBUTION[1]

local function login(world)
    local ns = addon.load("enUS", world)
    STATE.known = { [DEVOTION] = true, [RETRIBUTION] = true, [M.normal[1]] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.Blessings
end

local function raid(units)
    units.player = units.player or { class = "PALADIN" }
    return { group = "raid", units = units }
end

describe("a value the game keeps secret", function()
    it("leaves the range check to decide when the self check is secret", function()
        local _, B = login({ units = { player = { class = "PALADIN", range = false } } })
        assert.is_true(B.InRange(M.normal[1], "player"))
        STATE.secrets = { [true] = true }
        assert.is_false(B.InRange(M.normal[1], "player"))
    end)

    it("leaves a member with a secret class out of the plan", function()
        local _, B = login(raid({ raid1 = { class = "MAGE" } }))
        STATE.secrets = { MAGE = true }
        for _, e in ipairs((B.PlanBlessings())) do assert.are_not.equal("raid1", e.unit) end
        assert.are.same({}, STATE.errors)
    end)

    it("leaves a member with a secret class out of the overview", function()
        local _, B = login(raid({ raid1 = { class = "MAGE" } }))
        STATE.secrets = { MAGE = true }
        for _, d in ipairs(B.Overview()) do assert.are_not.equal("raid1", d.unit) end
    end)

    it("does not count a member with a secret class as another paladin", function()
        local _, B = login({ group = "party", units = {
            player = { class = "PALADIN" },
            party1 = { class = "PALADIN", auras = { { spellId = DEVOTION, expirationTime = 0, source = "party1" } } },
        } })
        assert.are.equal("RETRIBUTION", B.ChooseAura())
        STATE.secrets = { PALADIN = true }
        assert.are.equal("DEVOTION", B.ChooseAura())
    end)

    it("does not count the player as another paladin when the self check is secret", function()
        local player = { class = "PALADIN", auras = { { spellId = DEVOTION, expirationTime = 0, source = "player", mine = true } } }
        local _, B = login({ group = "raid", units = { player = player, raid1 = player } })
        assert.are.equal("DEVOTION", B.ChooseAura())
        local real = _G.UnitIsUnit
        _G.UnitIsUnit = function() return "secret" end
        STATE.secrets = { secret = true }
        local chosen = B.ChooseAura()
        _G.UnitIsUnit = real
        assert.are.equal("DEVOTION", chosen)
    end)

    it("takes a class's default role when the reported role is secret", function()
        local _, B = login({ group = "party", units = { player = { class = "PALADIN" }, party1 = { class = "WARRIOR", role = "TANK" } } })
        assert.are.equal("TANK", B.RoleOf("party1", "WARRIOR"))
        STATE.secrets = { TANK = true }
        assert.are.equal("MELEE", B.RoleOf("party1", "WARRIOR"))
    end)

    it("does not take the player for a tank when his role is secret", function()
        local ns = login({ group = "party", units = { player = { class = "PALADIN", role = "TANK" } } })
        STATE.known[D.RIGHTEOUS_FURY] = true
        ns.Refresh()
        assert.is_true(ns.furyButton.antsShown)
        STATE.secrets = { TANK = true }
        ns.Refresh()
        assert.is_false(ns.furyButton.antsShown)
    end)

    it("counts a target's secret PvP flag as flagged", function()
        local _, B = login({ units = { player = { class = "PALADIN" }, target = { class = "MAGE" } } })
        assert.is_truthy(B.BuffRunSpell("target"))
        STATE.secrets = { [false] = true }
        assert.is_nil(B.BuffRunSpell("target"))
    end)

    it("does not count the player's secret PvP flag as flagged for good", function()
        local _, B = login({ units = { player = { class = "PALADIN", pvp = true }, target = { class = "MAGE", pvp = true } } })
        assert.is_truthy(B.BuffRunSpell("target"))
        STATE.secrets = { [true] = true }
        assert.is_nil(B.BuffRunSpell("target"))
    end)

    it("casts nothing by Buff & Run for a target whose class is secret", function()
        local _, B = login({ units = { player = { class = "PALADIN" }, target = { class = "MAGE" } } })
        STATE.secrets = { MAGE = true }
        assert.is_nil(B.BuffRunSpell("target"))
        assert.are.same({}, STATE.errors)
    end)

    it("counts a secret cooldown as none", function()
        local ns = login({ units = { player = { class = "PALADIN" }, target = { class = "MAGE" } } })
        STATE.now, STATE.gcd = 100, true
        local b = ns.blessingButton
        STATE.secrets = { [C_Spell.GetSpellCooldown(M.normal[1]).startTime] = true }
        RUNSCRIPT(b, "PreClick", "MiddleButton", true)
        assert.are.equal("macro", b:GetAttribute("type3"))
    end)

    it("reports no secret class or level", function()
        local ns = login(raid({ raid1 = { class = "MAGE" } }))
        STATE.units.player.level = 37
        STATE.secrets = { MAGE = true, PALADIN = true, [37] = true }
        local text = ns.BuildReport({ area = "OTHER" })
        assert.is_truthy(text, "a report")
        assert.is_truthy(text:find("Character: UNKNOWN, level 0-9", 1, true), text)
        assert.is_nil(text:find("MAGE=", 1, true), text)
        assert.are.same({}, STATE.errors)
    end)
end)
