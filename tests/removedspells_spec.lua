-- Spells the client no longer has leave the bar, the lists and demo mode, and return by
-- themselves (ruleset plan 2026-11-05-removed-spells). Blizzard removed these shortly before
-- launch; live build 70790 answers for them as the mock does with STATE.removed.

local addon = require("addon")

local D = addon.load("enUS").D
local M, L = D.BLESSINGS.MIGHT, D.BLESSINGS.LIGHT
local DEVOTION = D.AURAS.DEVOTION[1]

local function removed()
    local set = { [D.SALVATION] = true, [D.MASS_SALVATION] = true, [D.REVOKE] = true }
    for _, id in ipairs(L.normal) do set[id] = true end
    for _, id in ipairs(L.greater) do set[id] = true end
    return set
end

-- A paladin in a raid with three mages, knowing everything in `know`
local function raid(world)
    world = world or {}
    world.group = "raid"
    world.units = world.units or {
        player = { class = "PALADIN" }, raid1 = { class = "MAGE" }, raid2 = { class = "MAGE" }, raid3 = { class = "MAGE" },
    }
    return world
end

local function login(world, gone)
    local ns = addon.load("enUS", world)
    STATE.removed = gone and removed() or nil
    STATE.known = { [DEVOTION] = true, [D.RIGHTEOUS_FURY] = true, [M.normal[1]] = true, [L.normal[1]] = true,
                    [D.SALVATION] = true, [D.MASS_SALVATION] = true, [D.REVOKE] = true }
    FIRE("PLAYER_LOGIN")
    return ns
end

local function shownButtons(ns)
    local names = { [ns.auraButton] = "AURA", [ns.furyButton] = "FURY",
                    [ns.blessingButton] = "BLESSING", [ns.salvationButton] = "SALVATION" }
    local list = {}
    for b, name in pairs(names) do
        if b:IsShown() then list[#list + 1] = { name = name, off = select(4, b:GetPoint()) } end
    end
    table.sort(list, function(a, c) return a.off < c.off end)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.name end
    return out
end

local function holdsNoRemoved(ns, b)
    local gone = removed()
    assert.is_nil(gone[b:GetAttribute("spell1")], b:GetName())
    for _, entry in ipairs(b.queue or {}) do assert.is_nil(gone[entry.spell]) end
    return ns
end

describe("a spell the client no longer has", function()
    it("does not exist and is not known, in demo mode neither", function()
        local ns = login(raid(), true)
        local B = ns.Blessings
        assert.is_false(B.Exists(D.SALVATION))
        assert.is_false(B.Known(D.SALVATION))
        assert.is_nil((B.Best(L.normal)))
        assert.is_false(B.FamilyExists("LIGHT"))
        assert.is_true(B.FamilyExists("MIGHT"))
        SmartBlessingBarDB.demo = true
        assert.is_false(B.Known(D.SALVATION))
        assert.is_false(B.Known(L.greater[1]))
        assert.is_true(B.Known(M.normal[7]))
    end)

    it("exists where the client has no such call", function()
        local ns = login(raid(), true)
        C_Spell.DoesSpellExist = nil
        assert.is_true(ns.Blessings.Exists(D.SALVATION))
    end)

    it("leaves three buttons on the bar, without a gap", function()
        local ns = login(raid(), true)
        assert.are.same({ "AURA", "FURY", "BLESSING" }, shownButtons(ns))
        local width = 3 * (D.SIZE + D.GAP) - D.GAP + 2 * D.PAD
        assert.are.equal(width, ns.bar:GetWidth())
        assert.are.same({}, STATE.errors)
    end)

    it("is in no queue, click or buff key", function()
        local ns = login(raid(), true)
        for _, b in ipairs({ ns.blessingButton, ns.salvationButton, ns.buffKey }) do holdsNoRemoved(ns, b) end
        assert.are.equal(0, ns.salvationButton.left)
        assert.are.same({}, STATE.errors)
    end)

    it("leaves the buff key empty once nothing else glows", function()
        local ns = login(raid({ units = { player = { class = "PALADIN", auras = {
            { spellId = DEVOTION, expirationTime = 3600, mine = true },
            { spellId = M.normal[1], expirationTime = 3600, mine = true },
        } } } }), true)
        assert.is_nil(ns.buffKey:GetAttribute("spell1"))
    end)

    it("empties a queue kept from before, also while auras are secret", function()
        local ns = login(raid())
        assert.is_truthy(ns.salvationButton.head)
        STATE.removed = removed()
        STATE.aurasSecret = true
        ns.Refresh()
        assert.are.equal(0, ns.salvationButton.left)
        assert.is_nil(ns.salvationButton:GetAttribute("spell1"))
        assert.are.same({ "AURA", "FURY", "BLESSING" }, shownButtons(ns))
        assert.are.same({}, STATE.errors)
    end)

    it("raises no error in demo mode, and demo plans none of them", function()
        local ns = login(raid(), true)
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        for _, b in ipairs({ ns.blessingButton, ns.salvationButton, ns.buffKey }) do holdsNoRemoved(ns, b) end
        assert.are.equal(0, ns.salvationButton.left)
        assert.are.same({ "AURA", "FURY", "BLESSING" }, shownButtons(ns))
        assert.are.same({}, STATE.errors)
    end)

    it("comes back by itself at the next refresh, nothing saved changed", function()
        local ns = login(raid(), true)
        local order = { unpack(SmartBlessingBarDB.order) }
        STATE.removed = nil
        ns.Refresh()
        assert.are.same(D.DEFAULT_ORDER, shownButtons(ns))
        assert.is_truthy(ns.salvationButton.head)
        assert.are.same(order, SmartBlessingBarDB.order)
    end)
end)
