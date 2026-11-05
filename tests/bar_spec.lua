-- Bar.lua: the blessing button's secure attributes, the refresh and its combat freeze, the
-- handle (ruleset plans 2026-10-18-class-blessing-bar, 2026-10-19-blessing-core). The mock
-- raises an error when a protected frame is changed in combat; specs check STATE.errors
-- stays empty.

local addon = require("addon")

local function known(...)
    local set = {}
    for _, id in ipairs({ ... }) do set[id] = true end
    return set
end

-- A logged-in addon. `world` as for addon.load.
local function login(world)
    local ns = addon.load("enUS", addon.mightFirst(world))
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, ns.D, ns.blessingButton
end

-- The handle as SimpleConjureBar's (ruleset plan 2026-10-18-bar-polish, IMPLEMENTATION
-- "Tests, by phase" 3)
describe("the handle", function()
    local function lines()
        local out = {}
        for _, l in ipairs(GameTooltip.lines) do out[#out + 1] = l[2] and (l[1] .. "|" .. l[2]) or l[1] end
        return out
    end

    it("names the lock state and its three clicks in a tooltip", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.handle, "OnEnter")
        assert.are.equal(ns.handle, GameTooltip.owner)
        assert.are.equal("ANCHOR_LEFT", GameTooltip.anchor)
        assert.are.equal("SmartBlessingBar", GameTooltip:GetText())
        -- Left, middle, right, as in every tooltip (Michel, from SimpleConjureBar 2026-10-22)
        assert.are.same({ L.TIP_UNLOCKED, " ", L.LEFTCLICK .. "|" .. L.MOVE, L.MIDDLECLICK .. "|" .. L.SETTINGS,
                          L.RIGHTCLICK .. "|" .. L.LOCK }, lines())
        assert.are.same({ 0.4, 0.8, 1 }, { unpack(GameTooltip.lines[1], 3, 5) })
        RUNSCRIPT(ns.handle, "OnLeave")
        assert.is_false(GameTooltip:IsShown())
    end)

    it("shows the new state at once after a right click", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.handle, "OnEnter")
        RUNSCRIPT(ns.handle, "OnMouseDown", "RightButton")
        assert.is_true(SmartBlessingBarDB.locked)
        assert.are.equal(L.TIP_LOCKED, GameTooltip.lines[1][1])
        assert.are.same({ 1, 0.3, 0.3 }, { unpack(GameTooltip.lines[1], 3, 5) })
        assert.are.equal(L.RIGHTCLICK .. "|" .. L.UNLOCK, lines()[5])
    end)

    it("opens and closes the settings on a middle click, locked too", function()
        local ns = login()
        local window = ns.UI.window
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_true(window:IsShown())
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_false(window:IsShown())
        SmartBlessingBarDB.locked = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_false(ns.handle.moving == true)
    end)

    it("opens nothing on a middle click in combat, and says why", function()
        local ns = login()
        STATE.combat = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_false(ns.UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.MENU_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the blessing button", function()
    it("casts with the left button only, registered for key down and up", function()
        local _, D, b = login({ known = known(19740) })
        assert.are.same({ "spell", D.BLESSINGS.MIGHT.normal[1], "player" },
            { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") })
        assert.is_nil(b:GetAttribute("type"))
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
        assert.are.same({}, STATE.errors)
    end)

    it("changes only after combat when the group changes in it", function()
        local _, D, b = login({ known = known(19740, 20217), group = "party", units = { party1 = { class = "MAGE" } } })
        STATE.units.player.auras = { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } }
        FIRE("UNIT_AURA", "player")
        TICK()
        assert.are.equal("party1", b:GetAttribute("unit1"))
        STATE.combat = true
        STATE.units.party1 = nil
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        TICK()
        assert.are.equal("party1", b:GetAttribute("unit1"))
        assert.are.same({}, STATE.errors)
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_nil(b:GetAttribute("unit1"))
    end)
end)

describe("the refresh", function()
    local function myMight(D) return { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } } end

    it("follows auras, the roster and the ticker out of combat", function()
        local _, D, b = login({ known = known(19740) })
        assert.are.equal("1", b.count:GetText())

        STATE.units.player.auras = myMight(D)
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.are.equal("", b.count:GetText())

        -- a lost buff the client did not report: the ticker sees it once the snapshot is 10 s old
        STATE.units.player.auras = {}
        STATE.now = (STATE.now or 0) + 11
        TICK()
        assert.are.equal("1", b.count:GetText())

        STATE.group = "party"
        STATE.units.party1 = { class = "WARRIOR" }
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        assert.are.equal("2", b.count:GetText())
    end)

    -- Ruleset plan 2026-10-20-performance-pvp, criterion 2: the 1 s ticker re-wrote the
    -- layout, the saved position and every icon each time
    it("writes nothing on a tick with nothing changed, and re-arranges on a change", function()
        local ns = login({ known = known(19740, 25782), group = "party", units = { party1 = { class = "WARRIOR" } } })
        STATE.bags = { [ns.D.SYMBOL_OF_KINGS] = 4 }
        ns.Refresh()
        local writes = {}
        local function spy(obj, name, methods)
            for _, m in ipairs(methods) do
                local orig = obj[m]
                obj[m] = function(self, ...) writes[#writes + 1] = name .. ":" .. m return orig(self, ...) end
            end
        end
        spy(ns.bar, "bar", { "SetPoint", "ClearAllPoints", "SetSize" })
        spy(ns.handle, "handle", { "SetPoint", "ClearAllPoints" })
        for name, b in pairs({ aura = ns.auraButton, fury = ns.furyButton, blessing = ns.blessingButton,
                               salvation = ns.salvationButton }) do
            spy(b, name, { "SetPoint", "ClearAllPoints", "Show" })
            spy(b.icon, name .. ".icon", { "SetTexture", "SetDesaturated" })
            spy(b.count, name .. ".count", { "SetText" })
        end
        spy(ns.blessingButton.symbols, "symbols", { "SetText", "SetTextColor" })
        SmartBlessingBarDB.point = nil -- a saved position would come back
        TICK()
        assert.are.same({}, writes)
        assert.is_nil(SmartBlessingBarDB.point)
        SmartBlessingBarDB.showFury = false
        TICK()
        assert.is_false(ns.furyButton:IsShown())
        assert.is_truthy(table.concat(writes, " "):find("salvation:SetPoint", 1, true))
        for i = #writes, 1, -1 do writes[i] = nil end
        TICK()
        assert.are.same({}, writes)
        SmartBlessingBarDB.order = { "SALVATION", "BLESSING", "FURY", "AURA" }
        TICK()
        assert.is_truthy(table.concat(writes, " "):find("salvation:SetPoint", 1, true))
    end)

    -- A raid's nameplates and targets fire UNIT_AURA all the time; a member's change also
    -- fires for his group token
    it("follows the auras of group members only", function()
        local _, D, b = login({ known = known(19740), group = "party", units = { party1 = { class = "WARRIOR" } } })
        assert.are.equal("2", b.count:GetText())
        STATE.units.player.auras = myMight(D)
        for _, unit in ipairs({ "nameplate1", "target", "focus", "partypet1" }) do
            FIRE("UNIT_AURA", unit)
            RUNTIMERS()
            assert.are.equal("2", b.count:GetText(), unit)
        end
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.are.equal("1", b.count:GetText())
        STATE.units.party1.auras = myMight(D)
        STATE.units.party1.auras[1].mine = true
        FIRE("UNIT_AURA", "party1")
        RUNTIMERS()
        assert.are.equal("", b.count:GetText())
    end)
end)

describe("the handle", function()
    it("refuses to drag in combat, and saves the position after a drag", function()
        local ns = login()
        STATE.combat = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_not_true(ns.bar.moving)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))

        STATE.combat = false
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_true(ns.bar.moving)
        RUNSCRIPT(ns.handle, "OnMouseUp", "LeftButton")
        assert.is_false(ns.bar.moving)
        assert.are.equal("LEFT", SmartBlessingBarDB.point)
        assert.are.same({}, STATE.errors)
    end)

    it("does not drag a locked bar, and a saved position is restored at login", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, locked = true,
            point = "LEFT", rel = "BOTTOMLEFT", x = 300, y = 400 } })
        FIRE("PLAYER_LOGIN")
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_not_true(ns.bar.moving)
        assert.are.same({ "LEFT", UIParent, "BOTTOMLEFT", 300, 400 }, { ns.bar:GetPoint() })
    end)

    -- project.md: a damaged file must not break the addon. The client refuses an unknown
    -- anchor name, which stopped the login before the minimap button and the options.
    it("starts at the start position when the saved anchor is no anchor", function()
        for _, saved in ipairs({ { point = "FOO", rel = "BOTTOMLEFT" }, { point = "LEFT", rel = "left" } }) do
            local ns = addon.load("enUS", { db = { dbVersion = 9, point = saved.point, rel = saved.rel, x = 300, y = 400 } })
            FIRE("PLAYER_LOGIN")
            assert.are.same({}, STATE.errors)
            assert.is_truthy(STATE.options and STATE.options.registered)
            assert.are.equal("LEFT", SmartBlessingBarDB.point) -- re-anchored from the start position
            assert.is_truthy(ns)
        end
    end)
end)

-- A regression guard: the class buttons went with the blessing core plan's phase 4
describe("the bar's buttons", function()
    it("have no class button and no flyout, in a raid of every class", function()
        local units = {}
        local D = addon.load("enUS").D
        for i, class in ipairs(D.CLASS_ORDER) do units["raid" .. i] = { class = class, subgroup = 1 } end
        local ns = login({ group = "raid", units = units })
        for _, class in ipairs(D.CLASS_ORDER) do
            assert.is_nil(_G["SmartBlessingBarClass" .. class], class)
            assert.is_nil(_G["SmartBlessingBarFlyout" .. class], class)
        end
        -- the aura flyout went with ruleset plan 2026-10-19-priorities
        assert.is_nil(ns.flyouts)
        assert.is_nil(ns.header)
    end)
end)

-- Show anchor (ruleset plan 2026-10-22-anchor-and-window-background, criterion 2)
describe("Show anchor", function()
    it("keeps the handle visible while on, at login, after the mouse leaves and after a drag", function()
        local ns = login()
        local h = ns.handle
        assert.is_true(SmartBlessingBarDB.showAnchor)
        assert.are.equal(1, h:GetAlpha())
        RUNSCRIPT(h, "OnEnter")
        RUNSCRIPT(h, "OnLeave")
        assert.are.equal(1, h:GetAlpha())
        RUNSCRIPT(h, "OnMouseDown", "LeftButton")
        RUNSCRIPT(h, "OnMouseUp", "LeftButton")
        assert.are.equal(1, h:GetAlpha())
    end)

    it("hides the handle at once when switched off, also in combat, and on the mouse leaving", function()
        local ns = login()
        local h = ns.handle
        SlashCmdList.SMARTBLESSINGBAR("")
        local cb = ns.UI.controls.showAnchor
        STATE.combat = true
        cb:SetChecked(false)
        RUNSCRIPT(cb, "OnClick")
        assert.is_false(SmartBlessingBarDB.showAnchor)
        assert.are.equal(0, h:GetAlpha())
        STATE.combat = false
        RUNSCRIPT(h, "OnEnter")
        assert.are.equal(1, h:GetAlpha())
        RUNSCRIPT(h, "OnLeave")
        assert.are.equal(0, h:GetAlpha())
        cb:SetChecked(true)
        RUNSCRIPT(cb, "OnClick")
        assert.are.equal(1, h:GetAlpha())
    end)
end)

-- Ruleset plan 2026-10-22-combat-login-position (SimpleConjureBar's F-01): after a login in
-- combat, a refresh that ran before the bar was positioned saved the start position over the
-- player's
describe("the bar after a login in combat", function()
    it("keeps the saved position when a refresh runs before the end of combat is seen", function()
        local ns = addon.load("enUS", { db = { point = "LEFT", rel = "BOTTOMLEFT", x = 300, y = 400 } })
        STATE.combat = true
        FIRE("PLAYER_LOGIN")
        FIRE("UNIT_AURA", "player")
        STATE.combat = false
        RUNTIMERS()
        assert.are.same({ "LEFT", "BOTTOMLEFT", 300, 400 },
            { SmartBlessingBarDB.point, SmartBlessingBarDB.rel, SmartBlessingBarDB.x, SmartBlessingBarDB.y })
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.same({ "LEFT", "BOTTOMLEFT", 300, 400 },
            { SmartBlessingBarDB.point, SmartBlessingBarDB.rel, SmartBlessingBarDB.x, SmartBlessingBarDB.y })
        assert.is_false(ns.barPending)
    end)
end)

describe("Show anchor's check box", function()
    it("shares the row with Show border, to its right, as in SimpleConjureBar", function()
        local ns = login()
        SlashCmdList.SMARTBLESSINGBAR("") -- the row lays out its boxes when the window opens
        local c = ns.UI.controls
        assert.are.equal(c.border:GetParent(), c.showAnchor:GetParent())
        assert.is_true(select(4, c.showAnchor:GetPoint(1)) > select(4, c.border:GetPoint(1)))
    end)
end)
