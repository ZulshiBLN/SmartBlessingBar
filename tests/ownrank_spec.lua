-- My own weaker blessing counts as missing, as another paladin's does: after a new rank is
-- learned, and my normal one where my Greater one is stronger and used (ruleset plan
-- 2026-10-25-rank-glow-fixes, Michel 2026-10-25). An equal strength is never weaker, so
-- nothing is cast again and again.

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

local function plan(world, know, symbols, learned)
    local ns = addon.load("enUS", addon.mightFirst(world))
    STATE.known = {}
    for _, id in ipairs(know) do STATE.known[id] = true end
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    STATE.learned = learned
    FIRE("PLAYER_LOGIN")
    return ns.Blessings, ns
end

-- Might ranks 1..6 and Kings, plus `extra`
local function know(extra)
    local list = { K.normal[1] }
    for i = 1, 6 do list[#list + 1] = M.normal[i] end
    for _, id in ipairs(extra or {}) do list[#list + 1] = id end
    return list
end

local function mine(id) return { spellId = id, expirationTime = 3600, mine = true } end

local function entries(queue)
    local out = {}
    for i, e in ipairs(queue) do out[i] = { e.spell, e.unit } end
    return out
end

-- Three warriors, each carrying `auras`; one of them at `lowLevel` if given
local function warriors(auras, lowLevel)
    local units = {}
    for i = 1, 3 do
        units["raid" .. i] = { class = "WARRIOR", subgroup = 1, auras = auras(i),
            level = (lowLevel and i == 3) and lowLevel or nil }
    end
    return { group = "raid", units = units }
end

describe("my own weaker blessing", function()
    it("is renewed with my best fitting rank after I learned a higher one", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", auras = { mine(M.normal[3]) } } } },
            know())
        assert.are.same({ { M.normal[6], "player" }, { M.normal[6], "party1" } }, entries((B.PlanBlessings())))
    end)

    it("counts as lacking for my stronger Greater one, also my Greater rank 1 against rank 2", function()
        local B = plan(warriors(function() return { mine(M.normal[6]) } end), know({ M.greater[2] }), 5)
        assert.are.same({ { M.greater[2], "raid1" } }, entries((B.PlanBlessings())))
        B = plan(warriors(function() return { mine(M.greater[1]) } end), know({ M.greater[1], M.greater[2] }), 5)
        assert.are.same({ { M.greater[2], "raid1" } }, entries((B.PlanBlessings())))
    end)

    it("gives a member who does not fit the Greater one my best normal rank, once", function()
        local learned = { [M.greater[2]] = 60 } -- fits from level 50
        local B = plan(warriors(function(i) return { mine(i == 3 and M.normal[3] or M.greater[2]) } end, 40),
            know({ M.greater[2] }), 5, learned)
        assert.are.same({ { M.normal[6], "raid3" } }, entries((B.PlanBlessings())))
        B = plan(warriors(function(i) return { mine(i == 3 and M.normal[6] or M.greater[2]) } end, 40),
            know({ M.greater[2] }), 5, learned)
        assert.are.same({}, entries((B.PlanBlessings())))
    end)

    it("is not cast again at equal strength while the Greater one is not used", function()
        -- Greater no stronger: three members with my best normal rank need nothing
        local B = plan(warriors(function() return { mine(M.normal[6]) } end), know({ M.greater[1] }), 5)
        assert.are.same({}, entries((B.PlanBlessings())))
        -- Greater stronger but no Symbol: the normal rank they carry is my best
        B = plan(warriors(function() return { mine(M.normal[6]) } end), know({ M.greater[2] }), 0)
        assert.are.same({}, entries((B.PlanBlessings())))
    end)

    it("counts a member out of range with my weaker rank as far", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", range = false,
            auras = { mine(M.normal[3]) } } } }, know())
        local q = B.PlanBlessings()
        assert.are.equal(1, q.far)
    end)

    it("shows the next blessing in the overview for a member with my weaker rank", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", auras = { mine(M.normal[3]) } } } },
            know())
        local d = B.WithRead(function() return B.Describe("party1", "WARRIOR") end)
        assert.is_truthy(d.next)
        assert.are.equal("MIGHT", d.next.family)
    end)
end)

describe("Buff & Run and my own weaker blessing", function()
    local function choice(target)
        local B = plan({ units = { target = target } }, know())
        STATE.units.target = target
        return B.BuffRunSpell("target")
    end

    it("re-blesses a weaker rank of the family it would choose, and passes my other family", function()
        assert.are.equal(M.normal[6], choice({ class = "WARRIOR", auras = { mine(M.normal[3]) } }))
        assert.is_nil(choice({ class = "WARRIOR", auras = { mine(M.normal[6]) } }))
        assert.is_nil(choice({ class = "WARRIOR", auras = { mine(K.normal[1]) } }))
    end)
end)
