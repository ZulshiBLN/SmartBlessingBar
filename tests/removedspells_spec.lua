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

local function openTab(ns, key)
    if not ns.UI.window:IsShown() then SlashCmdList.SMARTBLESSINGBAR("") end
    for i, page in ipairs(ns.UI.pages) do
        if page.titleKey == key then RUNSCRIPT(ns.UI.tabs[i], "OnClick") return page end
    end
end

local function reopen(ns, key)
    if ns.UI.window:IsShown() then SlashCmdList.SMARTBLESSINGBAR("") end
    return openTab(ns, key)
end

local function rowOf(ns, class)
    for _, r in ipairs(ns.UI.controls.listRows) do
        if r.class == class then return r end
    end
end

-- The families a row shows, from its shown icons
local function families(r)
    local out = {}
    for _, icon in ipairs(r.icons) do
        if icon:IsShown() then out[#out + 1] = icon.family end
    end
    return out
end

local function dragIcon(page, r, from, to)
    local LEFT, ICON = 300, 24 + 6
    r.icons[1].left = LEFT
    STATE.mouseDown = true
    RUNSCRIPT(r.icons[from], "OnMouseDown", "LeftButton")
    STATE.cursor = { LEFT + (to - 1) * ICON + ICON / 2, 0 }
    RUNSCRIPT(page, "OnUpdate", 0.01)
    STATE.mouseDown = false
    RUNSCRIPT(r.icons[from], "OnMouseUp", "LeftButton")
end

local function dragRow(ns, page, from, to)
    local ROW, TOP = 26 + 2, 1000
    local rows = ns.UI.controls.orderRows
    rows[1].top = TOP
    STATE.mouseDown = true
    RUNSCRIPT(rows[from], "OnMouseDown", "LeftButton")
    STATE.cursor = { 0, TOP - (to - 1) * ROW - ROW / 2 }
    RUNSCRIPT(page, "OnUpdate", 0.01)
    STATE.mouseDown = false
    RUNSCRIPT(rows[from], "OnMouseUp", "LeftButton")
end

describe("the settings without a spell the client no longer has", function()
    it("hide Salvation on the Tracking tab, and show it again at the next opening", function()
        local ns = login(raid(), true)
        local c = ns.UI.controls
        openTab(ns, "TAB_TRACKING")
        assert.is_false(c.salvationHeader:IsShown())
        assert.is_false(c.showSalvation:GetParent():IsShown())
        assert.is_false(c.salvationSpeed:GetParent():IsShown())
        for _, line in ipairs(c.salvationLine) do assert.is_false(line:IsShown()) end
        STATE.removed = nil
        reopen(ns, "TAB_TRACKING")
        assert.is_true(c.salvationHeader:IsShown())
        assert.is_true(c.showSalvation:GetParent():IsShown())
        assert.is_true(c.salvationSpeed:GetParent():IsShown())
        for _, line in ipairs(c.salvationLine) do assert.is_true(line:IsShown()) end
    end)

    it("name blessings alone in the renew label, and Salvation again once it returns", function()
        local ns = login(raid(), true)
        local label = ns.UI.controls.renewRow.label
        openTab(ns, "TAB_PRIORITIES")
        assert.are.equal(ns.L.BTN_BLESSINGS, label:GetText())
        STATE.removed = nil
        reopen(ns, "TAB_PRIORITIES")
        assert.are.equal(ns.L.RENEW_BLESSINGS:format("spell" .. D.SALVATION), label:GetText())
    end)

    it("hide its row on the Order tab, and a drag keeps its saved index", function()
        local ns = login(raid({ db = { dbVersion = 12, order = { "AURA", "SALVATION", "FURY", "BLESSING" } } }), true)
        local page = openTab(ns, "TAB_ORDER")
        local rows = ns.UI.controls.orderRows
        assert.is_true(rows[3]:IsShown())
        assert.is_false(rows[4]:IsShown())
        assert.are.equal(ns.L.BTN_BLESSINGS, rows[3].label:GetText())
        dragRow(ns, page, 1, 3)
        assert.are.same({ "FURY", "SALVATION", "BLESSING", "AURA" }, SmartBlessingBarDB.order)
        assert.are.same({ "FURY", "BLESSING", "AURA" }, shownButtons(ns))
        STATE.removed = nil
        reopen(ns, "TAB_ORDER")
        assert.is_true(rows[4]:IsShown())
    end)

    it("leave it out of the report's areas", function()
        local ns = login(raid(), true)
        for _, key in ipairs(ns.ReportAreas()) do assert.are_not.equal("SALVATION", key) end
        STATE.removed = nil
        local found = false
        for _, key in ipairs(ns.ReportAreas()) do found = found or key == "SALVATION" end
        assert.is_true(found)
    end)

    it("show no Light on a class row, and it returns at its old place", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        assert.are.same({ "WISDOM", "KINGS", "MIGHT" }, families(rowOf(ns, "PRIEST")))
        assert.are.same({ "MIGHT", "KINGS" }, families(rowOf(ns, "WARRIOR")))
        STATE.removed = nil
        reopen(ns, "TAB_PRIORITIES")
        assert.are.same({ "WISDOM", "KINGS", "LIGHT", "MIGHT" }, families(rowOf(ns, "PRIEST")))
    end)

    it("keep the aura row whole", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        assert.are.same(D.AURA_ORDER, families(ns.UI.controls.auraRow))
    end)

    it("keep a hidden family's saved index through a drag", function()
        local ns = login(raid(), true)
        local page = openTab(ns, "TAB_PRIORITIES")
        dragIcon(page, rowOf(ns, "PRIEST"), 1, 3)
        assert.are.same({ "KINGS", "MIGHT", "LIGHT", "WISDOM" }, SmartBlessingBarDB.classLists.PRIEST.order)
    end)

    it("do not let the last existing blessing of a class be switched off", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        local r = rowOf(ns, "WARRIOR")
        RUNSCRIPT(r.icons[1], "OnMouseUp", "RightButton")
        assert.are.same({ "KINGS", "LIGHT" }, SmartBlessingBarDB.classLists.WARRIOR.order)
        RUNSCRIPT(r.icons[1], "OnMouseUp", "RightButton")
        assert.are.same({ "KINGS", "LIGHT" }, SmartBlessingBarDB.classLists.WARRIOR.order)
    end)

    it("leave a hidden family off on Enable all", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        local list = SmartBlessingBarDB.classLists.MAGE
        list.order, list.off = { "WISDOM", "KINGS", "MIGHT" }, { LIGHT = true }
        RUNSCRIPT(ns.UI.controls.enableAll, "OnClick")
        assert.is_true(list.off.LIGHT)
        assert.are.same({ "WISDOM", "KINGS", "MIGHT" }, list.order)
    end)

    it("change nothing saved", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        assert.are.same(ns.DefaultClassLists(), SmartBlessingBarDB.classLists)
        assert.are.same(D.DEFAULT_ORDER, SmartBlessingBarDB.order)
        assert.are.equal(D.DB_VERSION, SmartBlessingBarDB.dbVersion)
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the overview without a spell the client no longer has", function()
    local function demoRaid(gone)
        local ns = login(raid(), gone)
        SmartBlessingBarDB.demo = true
        return ns, ns.DemoRaid()
    end

    it("gives demo's raid neither, and no Wisdom to a Warrior or Rogue", function()
        local _, list = demoRaid(true)
        assert.is_true(#list > 0)
        for _, d in ipairs(list) do
            assert.is_nil(d.carried.LIGHT, d.class)
            assert.is_nil(d.carried.SALVATION, d.class)
            assert.is_false(d.next ~= nil and d.next.family == "SALVATION")
            if d.class == "WARRIOR" or d.class == "ROGUE" then assert.is_nil(d.carried.WISDOM, d.class) end
        end
    end)

    it("has the fourth paladin give what a class's list holds and nobody gave", function()
        local _, list = demoRaid(true)
        for _, d in ipairs(list) do
            if d.class == "PALADIN" then
                for _, family in ipairs({ "KINGS", "MIGHT", "WISDOM" }) do
                    assert.is_truthy(d.carried[family], family)
                end
            end
        end
    end)

    it("passes a saved first Light in demo's raid", function()
        local ns, _ = demoRaid(true)
        SmartBlessingBarDB.classLists.MAGE.order = { "LIGHT", "WISDOM", "KINGS", "MIGHT" }
        for _, d in ipairs(ns.DemoRaid()) do
            if d.class == "MAGE" then
                assert.is_nil(d.carried.LIGHT)
                assert.is_true(d.carried.WISDOM.mine)
            end
        end
    end)

    it("gives Light again once it returns, per build", function()
        local ns = demoRaid(true)
        STATE.removed = nil
        local found = false
        for _, d in ipairs(ns.DemoRaid()) do found = found or d.carried.LIGHT ~= nil end
        assert.is_true(found)
    end)

    it("gives the names the room of the two slots", function()
        local ns = login(raid(), true)
        openTab(ns, "TAB_PRIORITIES")
        ns.Refresh()
        local gone = ns.overview.rows[1].nameW
        STATE.removed = nil
        ns.Refresh()
        local back = ns.overview.rows[1].nameW
        assert.are.equal(2 * (16 + 3), gone - back) -- two slots of an icon and its gap
    end)
end)
