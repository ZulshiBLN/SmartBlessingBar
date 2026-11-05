-- Queue.lua: the blessing and Salvation buttons cast the head of their queue; in combat it
-- stays as it was (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Tests, by phase" 3).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

local function know(extra)
    local set = { [K.normal[1]] = true, [D.SALVATION] = true, [D.REVOKE] = true }
    for i = 1, 6 do set[M.normal[i]] = true end
    for _, id in ipairs(extra or {}) do set[id] = true end
    return set
end

local function login(world, extra, symbols)
    local ns = addon.load("enUS", addon.mightFirst(world))
    STATE.known = know(extra)
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    FIRE("PLAYER_LOGIN")
    return ns, ns.blessingButton, ns.salvationButton, SmartBlessingBarDB
end

local function aura(id, mine) return { spellId = id, expirationTime = 3600, mine = mine } end

local function head(b) return { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") } end

describe("the blessing and Salvation buttons", function()
    it("cast the head of their queue, with the count of casts left and the ants", function()
        local _, bless, salv = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        assert.are.same({ "spell", M.normal[6], "player" }, head(bless))
        assert.are.equal("2", bless.count:GetText())
        assert.is_true(bless.ants:IsShown())
        assert.are.same({ "spell", D.SALVATION, "player" }, head(salv))
        assert.are.equal("2", salv.count:GetText())
    end)

    it("have nothing to cast, no count and no ants when the queue is empty", function()
        STATE.units = {}
        local _, bless = login({ units = { player = { class = "PALADIN", auras = { aura(M.normal[6], true) } } } })
        assert.are.same({}, head(bless))
        assert.are.equal("", bless.count:GetText())
        assert.is_false(bless.ants:IsShown())
        assert.is_true(bless.icon:IsDesaturated())
    end)

    -- The blessing button's middle click is Buff & Run (ruleset plan 2026-10-20-buff-and-run,
    -- buffrun_spec.lua); without a target it casts nothing
    it("cast their queue's head on a left click only", function()
        local _, bless, salv = login()
        RUNCLICK(bless, "MiddleButton", true)
        RUNCLICK(salv, "MiddleButton", true)
        assert.are.same({}, STATE.casts)
        RUNCLICK(bless, "LeftButton", true)
        assert.are.same({ { spell = M.normal[6], unit = "player" } }, STATE.casts)
    end)

    it("keep their head through combat, with no error, and move on after it", function()
        local ns, bless = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.units.player.auras = { aura(M.normal[6], true) } -- the head landed in combat
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.are.same({ "spell", M.normal[6], "player" }, head(bless))
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.same({ "spell", K.normal[1], "party1" }, head(bless))
        assert.are.same({}, STATE.errors)
        assert.is_truthy(ns)
    end)

    it("put no Greater entry first at combat start for a class with exceptions", function()
        -- the exception: another paladin gave raid1 Might, so he gets Kings
        local units = { raid1 = { class = "WARRIOR", auras = { aura(M.normal[6]) } } }
        for i = 2, 4 do units["raid" .. i] = { class = "WARRIOR" } end
        local _, bless = login({ group = "raid", units = units }, { M.greater[1] }, 5)
        assert.are.equal(M.greater[1], bless:GetAttribute("spell1"))
        FIRE("PLAYER_REGEN_DISABLED")
        assert.are.same({ "spell", K.normal[1], "raid1" }, head(bless))
    end)

    -- Final release review: a combat starting while auras are already secret still holds the
    -- Greater entry back, from the last queue - and the buff key follows
    it("put no Greater entry first at combat start, also while auras are secret", function()
        local units = { raid1 = { class = "WARRIOR", auras = { aura(M.normal[6]) } } }
        for i = 2, 4 do units["raid" .. i] = { class = "WARRIOR" } end
        local ns, bless = login({ group = "raid", units = units }, { M.greater[1] }, 5)
        assert.are.equal(M.greater[1], bless:GetAttribute("spell1"))
        STATE.aurasSecret = true
        FIRE("PLAYER_REGEN_DISABLED")
        assert.are.same({ "spell", K.normal[1], "raid1" }, head(bless))
        assert.are.equal(K.normal[1], ns.buffKey:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    it("put no Mass Salvation first at combat start for a class with tanks", function()
        local units = { raid1 = { class = "WARRIOR", role = "TANK" } }
        for i = 2, 5 do units["raid" .. i] = { class = "WARRIOR" } end
        local _, _, salv = login({ group = "raid", units = units }, { D.MASS_SALVATION }, 5)
        assert.are.equal(D.MASS_SALVATION, salv:GetAttribute("spell1"))
        FIRE("PLAYER_REGEN_DISABLED")
        assert.are.same({}, head(salv)) -- the only entry is held back
    end)

    it("show the Symbol count on the blessing button only while a Greater form is known", function()
        local _, bless = login(nil, nil, 7)
        assert.are.equal("", bless.symbols:GetText())
        _, bless = login(nil, { M.greater[1] }, 7)
        assert.are.equal("7", bless.symbols:GetText())
    end)

    it("are hidden by their toggles, leaving no gap", function()
        local ns, bless, salv, db = login()
        local step = D.SIZE + D.GAP
        db.showBlessing = false
        ns.Refresh()
        assert.is_false(bless:IsShown())
        assert.are.equal(D.PAD + 2 * step, select(4, salv:GetPoint()))
        db.showSalvation = false
        ns.Refresh()
        assert.is_false(salv:IsShown())
        assert.are.equal(D.PAD + 2 * step - D.GAP + D.PAD, ns.bar:GetWidth())
    end)

    it("plan nothing and cast nothing while their button is hidden", function()
        local ns, bless, salv, db = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        local B, calls = ns.Blessings, {}
        for _, name in ipairs({ "PlanBlessings", "PlanSalvation" }) do
            local fn = B[name]
            B[name] = function(...) calls[name] = (calls[name] or 0) + 1 return fn(...) end
        end
        db.showBlessing, db.showSalvation = false, false
        ns.Refresh()
        assert.are.same({}, calls)
        assert.is_nil(bless:GetAttribute("spell1"))
        assert.is_nil(salv:GetAttribute("spell1"))
        db.showSalvation = true
        ns.Refresh()
        assert.are.same({ PlanSalvation = 1 }, calls)
        assert.are.equal(D.SALVATION, salv:GetAttribute("spell1"))
    end)

    it("show the head's spell and target in the tooltip, or that nothing is left", function()
        local ns, bless = login()
        RUNSCRIPT(bless, "OnEnter")
        assert.are.equal(M.normal[6], GameTooltip.spell)
        STATE.units.player.auras = { aura(M.normal[6], true) }
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        RUNSCRIPT(bless, "OnEnter")
        assert.are.equal(ns.L.BTN_BLESSINGS, GameTooltip:GetText())
        assert.are.equal(ns.L.QUEUE_EMPTY, GameTooltip.lines[1][1])
    end)
end)

-- A queue holding only held entries at combat start casts nothing until combat ends (ruleset
-- plan 2026-10-19-blessing-steering, phase 5)
describe("a queue holding only held entries at combat start", function()
    -- A raid of warriors, one a tank without Salvation: Mass Salvation is the only entry,
    -- held because its Revoke could not follow in combat
    local function raid()
        local units = { raid1 = { class = "WARRIOR", role = "TANK", subgroup = 1 } }
        for i = 2, 5 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
        return { group = "raid", units = units }
    end

    it("keeps its count, without ants or a cast, and says it waits", function()
        local ns, _, salv = login(raid(), { D.MASS_SALVATION }, 1)
        ns.Refresh()
        assert.are.equal(D.MASS_SALVATION, salv:GetAttribute("spell1"))
        assert.is_true(salv.ants:IsShown())
        ns.Refresh(true)
        assert.is_nil(salv:GetAttribute("spell1"))
        assert.are.equal("1", salv.count:GetText())
        assert.is_false(salv.ants:IsShown())
        RUNSCRIPT(salv, "OnEnter")
        assert.are.equal(ns.L.QUEUE_HELD, GameTooltip.lines[1][1])
        assert.are.same({}, STATE.errors)
    end)
end)

-- The tooltips name the class for a Greater Blessing or Mass Salvation, the member otherwise;
-- a right click on the blessing button opens the priorities (ruleset plan
-- 2026-10-20-button-tips-glow)
describe("the queue buttons' tooltips and right click", function()
    local function tip(b)
        RUNSCRIPT(b, "OnEnter")
        local out = {}
        for i, l in ipairs(GameTooltip.lines) do out[i] = { l[1], l[2] } end
        return out
    end

    local function className(ns, class) return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class) end

    it("name the member for a normal blessing and Salvation, with the clicks", function()
        local ns, bless, salv = login({ group = "party", units = { party1 = { class = "MAGE", name = "Jaina" } } })
        local L = ns.L
        assert.are.equal(M.normal[6], bless:GetAttribute("spell1"))
        assert.are.same({ { L.LEFTCLICK, "player" }, { L.MIDDLECLICK, L.BUFF_RUN }, { L.RIGHTCLICK, L.SET_PRIORITIES } },
            tip(bless))
        assert.are.equal(D.SALVATION, salv:GetAttribute("spell1"))
        assert.are.same({ { L.LEFTCLICK, "player" } }, tip(salv)) -- the player first, then Jaina
        STATE.units.player.auras = { aura(D.SALVATION, true) }
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        assert.are.same({ { L.LEFTCLICK, "Jaina" } }, tip(salv))
    end)

    it("name the class for a Greater Blessing and Mass Salvation", function()
        local units = {}
        for i = 1, 4 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
        local ns, bless, salv = login({ group = "raid", units = units }, { M.greater[1], D.MASS_SALVATION }, 5)
        local L = ns.L
        assert.are.equal(M.greater[1], bless:GetAttribute("spell1"))
        assert.are.same({ L.LEFTCLICK, className(ns, "WARRIOR") }, tip(bless)[1])
        assert.are.equal(D.MASS_SALVATION, salv:GetAttribute("spell1"))
        assert.are.same({ { L.LEFTCLICK, className(ns, "WARRIOR") } }, tip(salv))
    end)

    it("name the class of a Greater Blessing whose target left the raid in combat", function()
        local units = {}
        for i = 1, 4 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
        local ns, bless = login({ group = "raid", units = units }, { M.greater[1] }, 5)
        assert.are.equal(M.greater[1], bless:GetAttribute("spell1"))
        STATE.combat = true
        STATE.units[bless:GetAttribute("unit1")] = nil
        assert.are.same({ ns.L.LEFTCLICK, className(ns, "WARRIOR") }, tip(bless)[1])
        assert.are.same({}, STATE.errors)
    end)

    -- After a /reload in combat the first refresh waits for its end
    it("say nothing is left before the first refresh", function()
        local ns = addon.load("enUS", addon.mightFirst({ combat = true }))
        FIRE("PLAYER_LOGIN")
        tip(ns.blessingButton)
        assert.are.same({}, STATE.errors)
        assert.are.equal(ns.L.QUEUE_EMPTY, GameTooltip.lines[1][1])
    end)

    it("name the right click on the blessing button also with nothing to cast", function()
        local ns, bless = login()
        STATE.units.player.auras = { aura(M.normal[6], true) }
        FIRE("UNIT_AURA", "player")
        ns.Refresh()
        local lines = tip(bless)
        assert.are.equal(ns.L.BTN_BLESSINGS, GameTooltip:GetText())
        assert.are.same({ ns.L.RIGHTCLICK, ns.L.SET_PRIORITIES }, lines[#lines])
    end)

    it("open the Priorities tab on a right click on the blessing button, casting nothing", function()
        local ns, bless, salv = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        assert.is_nil(bless:GetAttribute("type2"))
        RUNCLICK(salv, "RightButton", false)
        assert.is_false(ns.UI.window:IsShown())
        RUNCLICK(bless, "RightButton", true) -- the press does nothing; the release opens
        assert.is_false(ns.UI.window:IsShown())
        RUNCLICK(bless, "RightButton", false)
        assert.is_true(ns.SettingsPageShown("TAB_PRIORITIES"))
        assert.is_nil(STATE.menu) -- no menu, as before
        assert.are.same({}, STATE.casts)
        assert.are.same({}, STATE.errors)
    end)

    it("say why the priorities do not open in combat", function()
        local ns, bless = login()
        STATE.combat = true
        RUNCLICK(bless, "RightButton", false)
        assert.is_false(ns.UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)

    -- SimpleConjureBar's F-04: "nothing left" hid that the ones in need are out of range
    it("say that everyone in need is out of range, not that nothing is left", function()
        local ns, bless = login({ group = "party", units = {
            player = { class = "PALADIN", auras = { aura(M.normal[6], true) } },
            party1 = { class = "MAGE", range = false } } })
        assert.is_nil(bless:GetAttribute("spell1"))
        assert.are.same({ ns.L.QUEUE_OUT_OF_RANGE }, tip(bless)[1])
        STATE.units.party1.range = nil
        FIRE("UNIT_AURA", "party1")
        RUNTIMERS()
        assert.are.same({ ns.L.LEFTCLICK, "party1" }, tip(bless)[1])
    end)

    -- The 1.1.0 review's F-08: the Salvation button said "nothing left" for members out of range
    it("say so for Salvation too", function()
        local ns, _, salv = login({ group = "party", units = {
            player = { class = "PALADIN", auras = { aura(M.normal[6], true), aura(D.SALVATION, true) } },
            party1 = { class = "MAGE", range = false }, party2 = { class = "ROGUE", range = false } } })
        assert.is_nil(salv:GetAttribute("spell1"))
        assert.are.same({ ns.L.QUEUE_OUT_OF_RANGE }, tip(salv)[1])
        -- out of range but not in need: carrying Salvation, a tank, too low for it
        for _, far in ipairs({ { class = "MAGE", range = false, auras = { aura(D.SALVATION) } },
                               { class = "WARRIOR", range = false, role = "TANK" },
                               { class = "MAGE", range = false, level = 1 } }) do
            ns, _, salv = login({ group = "party", units = {
                player = { class = "PALADIN", auras = { aura(M.normal[6], true), aura(D.SALVATION, true) } },
                party1 = far } })
            STATE.learned = { [D.SALVATION] = 26 } -- fits from level 16
            ns.Refresh()
            assert.are.same({ ns.L.QUEUE_EMPTY }, tip(salv)[1], far.class .. tostring(far.role) .. tostring(far.level))
        end
    end)

    -- The 1.1.0 review's F-07: a member out of range was counted in the Greater loop and again
    it("count each member out of range once", function()
        local ns = login({ group = "raid", units = {
            player = { class = "PALADIN", auras = { aura(M.normal[6], true) } },
            raid1 = { class = "PALADIN" },
            raid2 = { class = "WARRIOR", range = false }, raid3 = { class = "WARRIOR", range = false },
            raid4 = { class = "WARRIOR", range = false } } }, { M.greater[1] }, 0)
        STATE.units.raid1 = STATE.units.player
        ns.Refresh()
        local line
        for _, l in ipairs(ns.StateSnapshot()) do if l:find("^queue BLESSING ") then line = l end end
        assert.is_truthy(line:find(" far=3$"), line)
    end)
end)
