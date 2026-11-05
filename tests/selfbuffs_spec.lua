-- SelfBuffs.lua: the aura and Righteous Fury buttons (ruleset plans
-- 2026-10-18-class-blessing-bar phase 4, 2026-10-18-flyouts phase 2 for the aura glow, and
-- 2026-10-19-priorities for the aura list and Fury by role).

local addon = require("addon")

local function login(known)
    local ns = addon.load("enUS", { known = known or {} })
    FIRE("PLAYER_LOGIN")
    return ns, ns.D
end

local function first(list, n)
    local set = {}
    for i = 1, n do set[list[i]] = true end
    return set
end

local function refresh()
    FIRE("UNIT_AURA", "player")
    RUNTIMERS()
end

describe("the aura button", function()
    local A0 = addon.load("enUS").D.AURAS
    local D_DEV, D_RET = A0.DEVOTION[1], A0.RETRIBUTION[1]
    -- A paladin knowing the first rank of Devotion and Retribution; `world` as for addon.load
    local function withAuras(world)
        local ns = addon.load("enUS", world)
        local A = ns.D.AURAS
        STATE.known = { [A.DEVOTION[1]] = true, [A.RETRIBUTION[1]] = true }
        FIRE("PLAYER_LOGIN")
        return ns, ns.D, ns.auraButton
    end
    local function paladin(id, extra)
        local r = { class = "PALADIN", subgroup = 1, auras = { { spellId = id, expirationTime = 0, source = "self" } } }
        for k, v in pairs(extra or {}) do r[k] = v end
        return r
    end
    -- An aura buff a paladin casts on himself carries his own unit as its source
    local function own(world)
        for unit, r in pairs(world.units) do
            for _, a in ipairs(r.auras or {}) do
                if a.source == "self" then a.source = unit end
            end
        end
        return world
    end

    it("casts the highest known rank of the first aura on the list with the left button only", function()
        local ns = addon.load("enUS")
        local list = ns.D.AURAS.DEVOTION
        STATE.known = first(list, 3)
        FIRE("PLAYER_LOGIN")
        local b = ns.auraButton
        assert.are.equal("spell", b:GetAttribute("type1"))
        assert.are.equal(list[3], b:GetAttribute("spell1"))
        assert.are.equal("player", b:GetAttribute("unit1"))
        assert.is_nil(b:GetAttribute("type"))
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
    end)

    it("follows the order of the aura list", function()
        local ns, D, b = withAuras({ db = { dbVersion = 8, auraList = { "RETRIBUTION", "DEVOTION" } } })
        assert.are.equal(D.AURAS.RETRIBUTION[1], b:GetAttribute("spell1"))
        assert.is_truthy(ns)
    end)

    it("has no action, the list's first aura greyed and no ants while no aura is known", function()
        local ns = login()
        local b = ns.auraButton
        assert.is_nil(b:GetAttribute("type1"))
        assert.is_true(b.icon:IsDesaturated())
        assert.are.equal("icon" .. ns.D.AURAS.DEVOTION[1], b.icon:GetTexture())
        assert.is_false(b.ants:IsShown())
    end)

    it("glows until the chosen aura runs as mine, not another of mine or another's", function()
        local _, D, b = withAuras()
        assert.is_true(b.ants:IsShown())
        STATE.units.player.auras = { { spellId = D.AURAS.RETRIBUTION[1], expirationTime = 0, mine = true } }
        refresh()
        assert.is_true(b.ants:IsShown())
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = false } }
        refresh()
        assert.is_true(b.ants:IsShown())
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        refresh()
        assert.is_false(b.ants:IsShown())
    end)

    it("chooses no aura while its button is hidden", function()
        local ns, _, b = withAuras()
        local calls, choose = 0, ns.Blessings.ChooseAura
        ns.Blessings.ChooseAura = function() calls = calls + 1 return choose() end
        SmartBlessingBarDB.showAura = false
        ns.Refresh()
        assert.are.equal(0, calls)
        assert.is_nil(b:GetAttribute("spell1"))
    end)

    -- code.md: a secret value is never used; an aura whose spell is secret counts as unread
    it("glows on while the game keeps my aura's spell secret", function()
        local _, D, b = withAuras()
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        STATE.secrets = { [D.AURAS.DEVOTION[1]] = true }
        refresh()
        assert.is_true(b.ants:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("moves on from an aura another paladin runs, also one I run too", function()
        local _, D, b = withAuras(own({ group = "party", units = { party1 = paladin(D_DEV) } }))
        assert.are.equal(D.AURAS.RETRIBUTION[1], b:GetAttribute("spell1"))
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        refresh()
        assert.are.equal(D.AURAS.RETRIBUTION[1], b:GetAttribute("spell1"))
        assert.is_true(b.ants:IsShown())
    end)

    -- Ruleset plan 2026-10-22-hidden-equal-aura: equal auras do not stack, the game shows mine
    -- on him and hides his
    it("moves on from my aura on another paladin who shows none of his own", function()
        local mine = { spellId = D_DEV, expirationTime = 0, source = "player", mine = true }
        local _, D, b = withAuras({ group = "party", units = { party1 = { class = "PALADIN", auras = { mine } } } })
        assert.are.equal(D.AURAS.RETRIBUTION[1], b:GetAttribute("spell1"))
    end)

    -- The 1.1.0 review's F-05: a third paladin's aura on him is not his own
    it("moves on from my aura on another paladin who shows only a third paladin's aura", function()
        local mine = { spellId = D_DEV, expirationTime = 0, source = "player", mine = true }
        local third = { spellId = D_RET, expirationTime = 0, source = "party2" }
        local _, D, b = withAuras({ group = "party", units = {
            party1 = { class = "PALADIN", auras = { mine, third } }, party2 = { class = "PALADIN" } } })
        STATE.known[D.AURAS.CONCENTRATION[1]] = true
        FIRE("UNIT_AURA", "party1")
        refresh()
        assert.are.equal(D.AURAS.CONCENTRATION[1], b:GetAttribute("spell1"))
    end)

    it("infers nothing beside his own aura, without my aura on him, or on a non-paladin", function()
        local mine = { spellId = D_DEV, expirationTime = 0, source = "player", mine = true }
        local his = { spellId = D_RET, expirationTime = 0, source = "party1" }
        local _, D, b = withAuras({ group = "party", units = { party1 = { class = "PALADIN", auras = { mine, his } } } })
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
        _, D, b = withAuras({ group = "party", units = { party1 = { class = "PALADIN" } } })
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
        _, D, b = withAuras({ group = "party", units = { party1 = { class = "WARRIOR", auras = { mine } } } })
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
    end)

    it("takes the first known aura when every one is taken", function()
        local _, D, b = withAuras(own({ group = "party", units = { party1 = paladin(D_DEV), party2 = paladin(D_RET) } }))
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
    end)

    it("counts only paladins, visible, and in a raid only my subgroup", function()
        local _, D, b = withAuras(own({ group = "party", units = {
            party1 = { class = "WARRIOR", auras = { { spellId = D_DEV, expirationTime = 0 } } },
            party2 = paladin(D_DEV, { visible = false }) } }))
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
        local _, _, raidButton = withAuras(own({ group = "raid", units = {
            raid1 = { class = "PALADIN", subgroup = 1 }, raid2 = paladin(D_DEV, { subgroup = 2 }) } }))
        STATE.units.raid1 = STATE.units.player
        STATE.units.player.subgroup = 1
        refresh()
        assert.are.equal(D.AURAS.DEVOTION[1], raidButton:GetAttribute("spell1"))
        STATE.units.raid2.subgroup = 1
        refresh()
        assert.are.equal(D.AURAS.RETRIBUTION[1], raidButton:GetAttribute("spell1"))
    end)

    it("counts no aura whose spell is a secret", function()
        local _, D, b = withAuras(own({ group = "party", units = { party1 = paladin(D_DEV) } }))
        STATE.secrets = { [D.AURAS.DEVOTION[1]] = true }
        FIRE("UNIT_AURA", "party1")
        refresh()
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    it("plays its glow only while it is shown", function()
        local ns, D = login()
        local b = ns.auraButton
        assert.is_false(b.antsAnim:IsPlaying())
        STATE.known = first(D.AURAS.DEVOTION, 1)
        refresh()
        assert.is_true(b.ants:IsShown())
        assert.is_true(b.antsAnim:IsPlaying())
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        refresh()
        assert.is_false(b.ants:IsShown())
        assert.is_false(b.antsAnim:IsPlaying())
    end)

    it("keeps its spell and glow in combat", function()
        local _, D, b = withAuras()
        assert.is_true(b.ants:IsShown())
        STATE.combat = true
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        STATE.known = { [D.AURAS.RETRIBUTION[1]] = true }
        refresh()
        TICK()
        assert.is_true(b.ants:IsShown())
        assert.are.equal(D.AURAS.DEVOTION[1], b:GetAttribute("spell1"))
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(D.AURAS.RETRIBUTION[1], b:GetAttribute("spell1"))
    end)

    it("casts the list's first aura in demo mode, ignoring other paladins", function()
        local ns, D, b = withAuras(own({ group = "party", units = { party1 = paladin(D_DEV) } }))
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        assert.are.equal(D.AURAS.DEVOTION[#D.AURAS.DEVOTION], b:GetAttribute("spell1"))
    end)
end)

describe("the Righteous Fury button", function()
    it("casts Righteous Fury with the left button only", function()
        local ns = addon.load("enUS")
        STATE.known[ns.D.RIGHTEOUS_FURY] = true
        FIRE("PLAYER_LOGIN")
        local b = ns.furyButton
        assert.are.equal(ns.D.RIGHTEOUS_FURY, b:GetAttribute("spell1"))
        assert.are.equal("spell", b:GetAttribute("type1"))
        assert.is_nil(b:GetAttribute("type"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
    end)

    it("is highlighted while it is missing out of combat for a tank, and frozen in combat", function()
        local ns = addon.load("enUS", { group = "party", units = { player = { class = "PALADIN", role = "TANK" } } })
        local rf = ns.D.RIGHTEOUS_FURY
        STATE.known[rf] = true
        FIRE("PLAYER_LOGIN")
        local glow = ns.furyButton.ants
        assert.is_true(glow:IsShown())

        STATE.units.player.auras = { { spellId = rf, expirationTime = 1800, mine = true } }
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.is_false(glow:IsShown())

        STATE.combat = true
        STATE.units.player.auras = {}
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.is_false(glow:IsShown())
        assert.are.same({}, STATE.errors)

        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(glow:IsShown())
    end)

    -- Only the game's role counts: a role check sets it (ruleset plan 2026-10-19-priorities)
    it("is greyed without ants unless the game reports the player as tank, and still casts", function()
        local ns = addon.load("enUS")
        local rf = ns.D.RIGHTEOUS_FURY
        STATE.known[rf] = true
        FIRE("PLAYER_LOGIN")
        local b = ns.furyButton
        assert.is_false(b.ants:IsShown())
        assert.is_true(b.icon:IsDesaturated())
        assert.are.equal("spell", b:GetAttribute("type1"))
        STATE.units.player.role = "TANK"
        ns.Refresh()
        assert.is_true(b.ants:IsShown())
        assert.is_false(b.icon:IsDesaturated())
        STATE.units.player.auras = { { spellId = rf, expirationTime = 1800, mine = true } }
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        assert.is_false(b.ants:IsShown())
        assert.is_false(b.icon:IsDesaturated())
    end)

    -- Final release review: hidden, it leaves nothing a /click could cast, as the aura button
    it("casts nothing and does not glow while its button is hidden", function()
        local ns = addon.load("enUS", { group = "party", units = { player = { class = "PALADIN", role = "TANK" } } })
        STATE.known[ns.D.RIGHTEOUS_FURY] = true
        FIRE("PLAYER_LOGIN")
        assert.are.equal("spell", ns.furyButton:GetAttribute("type1"))
        SmartBlessingBarDB.showFury = false
        ns.Refresh()
        assert.is_nil(ns.furyButton:GetAttribute("type1"))
        assert.is_false(ns.furyButton.ants:IsShown())
    end)

    it("is greyed without ants in demo mode, also for a tank", function()
        local ns = addon.load("enUS", { group = "party", units = { player = { class = "PALADIN", role = "TANK" } } })
        FIRE("PLAYER_LOGIN")
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        assert.is_false(ns.furyButton.ants:IsShown())
        assert.is_true(ns.furyButton.icon:IsDesaturated())
    end)

    it("is not highlighted and has no action while it is not learned", function()
        local ns = login()
        assert.is_false(ns.furyButton.ants:IsShown())
        assert.is_nil(ns.furyButton:GetAttribute("type1"))
    end)
end)

-- Ruleset plan 2026-10-20-fury-renew: Fury is renewed before it runs out, with its own time
-- (db.furyRenewMinutes), for a tank only
describe("Righteous Fury's renewal", function()
    local function tankLogin(role)
        local units = { player = { class = "PALADIN", role = role } }
        local ns = addon.load("enUS", { group = "party", units = units })
        STATE.known[ns.D.RIGHTEOUS_FURY] = true
        STATE.now = 1000
        FIRE("PLAYER_LOGIN")
        return ns
    end
    local function furyLeft(ns, seconds)
        STATE.units.player.auras = { { spellId = ns.D.RIGHTEOUS_FURY, expirationTime = STATE.now + seconds, mine = true } }
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        return ns.furyButton.ants:IsShown()
    end

    it("glows for a tank once less than its renewal time is left", function()
        local ns = tankLogin("TANK")
        local minutes = SmartBlessingBarDB.furyRenewMinutes
        assert.are.equal(ns.D.NUMBER_DEFAULTS.furyRenewMinutes.default, minutes)
        assert.is_false(furyLeft(ns, minutes * 60 + 30))
        assert.is_true(furyLeft(ns, minutes * 60 - 30))
    end)

    it("at 0 glows only once Fury is gone", function()
        local ns = tankLogin("TANK")
        SmartBlessingBarDB.furyRenewMinutes = 0
        assert.is_false(furyLeft(ns, 10))
        STATE.units.player.auras = {}
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        assert.is_true(ns.furyButton.ants:IsShown())
    end)

    it("never glows without the tank role", function()
        local ns = tankLogin(nil)
        assert.is_false(furyLeft(ns, 10))
        STATE.units.player.auras = {}
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        assert.is_false(ns.furyButton.ants:IsShown())
    end)

    it("is added by settings version 11 to a version 10 file, a saved value kept and clamped", function()
        local ns = addon.load("enUS", { db = { dbVersion = 10 } })
        ns.InitDB()
        local range = ns.D.NUMBER_DEFAULTS.furyRenewMinutes
        assert.are.equal(ns.D.DB_VERSION, SmartBlessingBarDB.dbVersion)
        assert.are.equal(range.default, SmartBlessingBarDB.furyRenewMinutes)
        for saved, expected in pairs({ [1] = 1, [9] = range.max, x = range.default }) do
            local value = saved == "x" and "soon" or saved
            ns = addon.load("enUS", { db = { dbVersion = 10, furyRenewMinutes = value } })
            ns.InitDB()
            assert.are.equal(expected, SmartBlessingBarDB.furyRenewMinutes, tostring(saved))
        end
    end)
end)

-- Every left click named, as on the blessing buttons (Michel, from SimpleConjureBar 2026-10-22)
describe("the self-buff buttons' tooltip", function()
    it("names whom the left click reaches under the spell", function()
        local ns = login()
        ns.auraButton:SetAttribute("spell1", ns.D.AURAS.DEVOTION[1])
        RUNSCRIPT(ns.auraButton, "OnEnter")
        local last = GameTooltip.lines[#GameTooltip.lines]
        assert.are.same({ ns.L.LEFTCLICK, UnitName("player") }, { last[1], last[2] })
    end)
end)
