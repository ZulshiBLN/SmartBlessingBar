-- The overview at the foot of the Priorities tab: members sorted by class in two columns,
-- names in class colour, a paladin's aura, the blessings they carry, mine marked, the next one
-- faint (ruleset plans 2026-10-19-overview, 2026-10-19-priorities, 2026-10-19-tab-layout).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- A paladin knowing Might 1-6, Kings, Wisdom 1 and Salvation, the settings open on the
-- Priorities tab; `world` as for addon.load
local function login(world)
    world = world or {}
    local ns = addon.load("enUS", world)
    STATE.known = { [K.normal[1]] = true, [W.normal[1]] = true, [D.SALVATION] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    FIRE("PLAYER_LOGIN")
    ns.OpenSettingsOn("TAB_PRIORITIES")
    return ns, ns.overview
end

local function aura(id, opts)
    opts = opts or {}
    return { spellId = id, expirationTime = opts.expires or 3600, mine = opts.mine, source = opts.source }
end

-- The shown rows: { name, class, greyed }
local function rows(o)
    local out = {}
    for _, r in ipairs(o.rows) do
        if r:IsShown() then out[#out + 1] = { r.name:GetText(), r.class, r.greyed == true } end
    end
    return out
end

local function row(o, unit)
    for _, r in ipairs(o.rows) do
        if r:IsShown() and r.unit == unit then return r end
    end
end

-- A row's icons by slot: family -> { mine, faint }
local function icons(r)
    local out = {}
    for _, s in ipairs(r.slots) do
        if s:IsShown() then
            assert.are.equal(s.mine == true, s.glow:IsShown(), s.family) -- the glow marks mine
            out[s.family] = { s.mine == true, s.faint == true }
        end
    end
    return out
end

-- A column's width: half the scroll frame's
local function colW(ns) return math.floor(ns.overviewHost.scroll:GetWidth() / 2) end

-- The shown rows' places: { x, y } each
local function places(o)
    local out = {}
    for _, r in ipairs(o.rows) do
        if r:IsShown() then out[#out + 1] = { select(2, r:GetPoint()) } end
    end
    return out
end

-- An element's x offset in its row
local function x(f) return select(2, f:GetPoint()) end

describe("the overview", function()
    it("lists every member sorted by class, in group order within it", function()
        local ns, o = login({ group = "party", units = {
            party1 = { class = "MAGE", name = "Jaina" },
            party2 = { class = "WARRIOR", role = "TANK", name = "Grom" },
            party3 = { class = "PRIEST", name = "Anna" },
            party4 = { class = "MAGE", name = "Aegwynn" } } })
        assert.are.same({ { "Grom", "WARRIOR", false }, { "player", "PALADIN", false },
                          { "Anna", "PRIEST", false }, { "Jaina", "MAGE", false },
                          { "Aegwynn", "MAGE", false } }, rows(o))
        assert.is_true(ns.overviewHost.page:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("shows the game's role as an icon before a tank's or healer's name, which moves in", function()
        local ns, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK" }, party2 = { class = "PRIEST" }, party3 = { class = "MAGE" } } })
        local w = colW(ns)
        for unit, atlas in pairs({ party1 = "UI-LFG-RoleIcon-Tank", party2 = "UI-LFG-RoleIcon-Healer" }) do
            local r = row(o, unit)
            assert.is_true(r.roleIcon:IsShown(), unit)
            assert.are.equal(atlas, r.roleIcon.atlas)
            assert.are.same({ 14, 14 }, { r.roleIcon:GetWidth(), r.roleIcon:GetHeight() })
            assert.are.equal(10, x(r.roleIcon))
            assert.are.equal(10 + 16, x(r.name))
            assert.are.equal(w - 146 - 16, r.name:GetWidth())
        end
        STATE.units.party1.range = false
        ns.Refresh()
        assert.are.equal(0.4, row(o, "party1").roleIcon:GetAlpha()) -- dimmed with its row
        local mage = row(o, "party3")
        assert.is_false(mage.roleIcon:IsShown())
        assert.are.equal(10, x(mage.name))
        assert.are.equal(w - 146, mage.name:GetWidth())
        for lang, t in pairs(ns.locales) do
            assert.is_nil(rawget(t, "OV_TANK"), lang)
            assert.is_nil(rawget(t, "OV_HEALER"), lang)
        end
    end)

    it("puts the first half, rounded up, in the left column, the rest in the right, both from the top", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" }, party2 = { class = "MAGE" },
                                                        party3 = { class = "ROGUE" }, party4 = { class = "DRUID" } } })
        local w = colW(ns)
        assert.are.same({ { 0, 0 }, { 0, -20 }, { 0, -40 }, { w, 0 }, { w, -20 } }, places(o))
        assert.are.equal(w, o.rows[1]:GetWidth())
    end)

    it("draws a line between the columns, as high as the longer one", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" }, party2 = { class = "MAGE" } } })
        local line = o.divider
        assert.is_true(line:IsShown())
        assert.are.same({ "TOPLEFT", colW(ns), 0 }, { line:GetPoint() })
        assert.are.same({ 1, 40 }, { line:GetWidth(), line:GetHeight() })
    end)

    it("colours each name by its class, a greyed one dimmed", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", range = false },
                                                        party2 = { class = "MAGE" } } })
        for _, unit in ipairs({ "party1", "party2", "player" }) do
            local r = row(o, unit)
            local want = { C_ClassColor.GetClassColor(r.class):GetRGB() }
            assert.are.same(want, { unpack(r.name.textColor, 1, 3) }, unit)
        end
        assert.are.equal(0.4, row(o, "party1").name:GetAlpha())
        assert.are.equal(1, row(o, "party2").name:GetAlpha())
    end)

    it("lays a row out: 10 px, the name unwrapped, 10 px, the aura, 5 px, the slots, 10 px", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        local w, r = colW(ns), row(o, "party1")
        assert.are.equal(10, x(r.name))
        assert.are.equal(w - 146, r.name:GetWidth())
        assert.is_false(r.name:GetWordWrap())
        assert.are.equal(10 + r.name:GetWidth() + 10, x(r.aura))
        assert.are.equal(x(r.aura) + 16 + 5, x(r.slots[1]))
        for s = 2, 5 do assert.are.equal(x(r.slots[1]) + (s - 1) * 19, x(r.slots[s])) end
        assert.are.equal(w - 10, x(r.slots[5]) + 19)
    end)

    it("follows the window's width", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        for _, st in ipairs(ns.UI.stretchers) do st(600) end
        assert.are.equal(288, colW(ns))
        assert.are.equal(288 - 146, row(o, "party1").name:GetWidth())
        assert.are.equal(288, select(2, o.divider:GetPoint()))
    end)

    it("has no footer, no class titles and no texts for them any more", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "PALADIN" } } })
        assert.is_nil(o.footer)
        assert.is_nil(o.headers)
        assert.is_nil(ns.Blessings.Footer)
        assert.is_nil(ns.Blessings.FamilyName)
        for _, key in ipairs({ "OV_OTHERS", "OV_LINE", "OV_COUNT", "OV_SEP", "OV_NONE" }) do
            for lang, t in pairs(ns.locales) do assert.is_nil(rawget(t, key), lang .. " " .. key) end
        end
    end)

    it("names a member without his second name", function()
        local _, o = login({ group = "party", units = { party1 = { class = "ROGUE", name = "Grom", surname = "Hellscream" } } })
        assert.are.equal("Grom", row(o, "party1").name:GetText())
    end)

    it("shows the blessings and Salvation carried, mine glowing", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", auras = {
            aura(M.normal[6], { mine = true }), aura(K.normal[1], { source = "party2" }), aura(D.SALVATION, { mine = true }) } },
            party2 = { class = "PALADIN" } } })
        local r = row(o, "party1")
        assert.are.same({ MIGHT = { true, false }, KINGS = { false, false }, SALVATION = { true, false } }, icons(r))
        -- the action button's gold border, 1.8 times the icon, centred; no yellow border any more
        local glow = r.slots[1].glow
        assert.are.equal("Interface\\Buttons\\UI-ActionButton-Border", glow:GetTexture())
        assert.are.same({ 16 * 1.8, 16 * 1.8 }, { glow:GetWidth(), glow:GetHeight() })
        assert.are.same({ "CENTER" }, { glow:GetPoint() })
        assert.are.equal("ADD", glow.blend)
        for _, s in ipairs(r.slots) do assert.is_nil(s.border) end
    end)

    it("shows the next blessing faint, also over another's lower rank", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", auras = { aura(M.normal[1]) } } } })
        assert.are.same({ MIGHT = { false, true } }, icons(row(o, "party1")))
        local slot
        for _, s in ipairs(row(o, "party1").slots) do if s.family == "MIGHT" then slot = s end end
        assert.are.equal("+", slot.plus:GetText())
        assert.are.equal(M.normal[6], slot.spell)
    end)

    it("shows my blessing running out faint in its place", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR",
            auras = { aura(M.normal[6], { mine = true, expires = 60 }) } } } })
        ns.Refresh()
        assert.are.same({ MIGHT = { false, true } }, icons(row(o, "party1")))
    end)

    it("greys a member out of range or dead, without the faint icon", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", range = false },
                                                        party2 = { class = "ROGUE", dead = true } } })
        assert.is_true(row(o, "party1").greyed)
        assert.is_true(row(o, "party2").greyed)
        assert.are.same({}, icons(row(o, "party1")))
        assert.is_false(row(o, "player").greyed)
    end)

    it("shows no icons for a member who is not visible", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", visible = false,
            auras = { aura(K.normal[1], { source = "player" }) } } } })
        assert.is_true(row(o, "party1").greyed)
        assert.are.same({}, icons(row(o, "party1")))
    end)

    it("explains an icon: the spell, who gave it and the minutes left", function()
        STATE.now = 0
        local ns, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", auras = { aura(K.normal[1], { source = "party2", expires = 600 }),
                                                    aura(D.SALVATION, { expires = 0 }) } },
            party2 = { class = "PALADIN", name = "Tyr", surname = "Lightbringer" } } })
        local function tip(family)
            for _, s in ipairs(row(o, "party1").slots) do
                if s.family == family then
                    RUNSCRIPT(s, "OnEnter")
                    local lines = {}
                    for _, l in ipairs(GameTooltip.lines) do lines[#lines + 1] = l[1] end
                    return GameTooltip.spell, lines
                end
            end
        end
        local spell, lines = tip("KINGS")
        assert.are.equal(K.normal[1], spell)
        assert.are.same({ ns.L.OV_FROM:format("Tyr"), ns.L.OV_LEFT:format(10) }, lines)
        spell, lines = tip("SALVATION")
        assert.are.equal(D.SALVATION, spell)
        assert.are.same({ ns.L.OV_FROM:format(ns.L.OV_ANOTHER) }, lines)
        assert.are.same({}, STATE.errors)
        -- In an instance the giver's name can be secret: he is "another paladin" (ruleset plan
        -- 2026-10-25-rank-glow-fixes)
        STATE.secrets = { Tyr = true }
        lines = select(2, tip("KINGS"))
        assert.are.same({ ns.L.OV_FROM:format(ns.L.OV_ANOTHER), ns.L.OV_LEFT:format(10) }, lines)
        assert.are.same({}, STATE.errors)
    end)

    it("shows twenty members without scrolling, the 21st makes it scroll", function()
        local units = {}
        for i = 1, 20 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
        local ns, o = login({ group = "raid", units = units })
        assert.are.equal(20, #rows(o))
        assert.are.equal(ns.overviewHost.scroll:GetHeight(), o:GetHeight())
        STATE.units.raid21 = { class = "WARRIOR", subgroup = 1 }
        ns.Refresh()
        assert.are.equal(21, #rows(o))
        assert.is_true(o:GetHeight() > ns.overviewHost.scroll:GetHeight())
        assert.are.equal(2 * colW(ns), o:GetWidth())
    end)

    it("follows the refresh while shown", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        STATE.units.party1.auras = { aura(M.normal[6], { mine = true }) }
        FIRE("UNIT_AURA", "party1")
        ns.Refresh()
        assert.are.same({ MIGHT = { true, false } }, icons(row(o, "party1")))
    end)

    it("follows a language switch while open", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR",
            auras = { aura(K.normal[1], { source = "party2" }) } }, party2 = { class = "PALADIN", name = "Tyr" } } })
        ns.ApplyLanguage("koKR")
        local s = row(o, "party1").slots[3]
        RUNSCRIPT(s, "OnEnter")
        assert.are.equal(ns.locales.koKR.OV_FROM:format("Tyr"), GameTooltip.lines[1][1])
    end)

    it("explains the faint icon with its spell, a Greater one when only that fits", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR", level = 30 } } })
        STATE.known[M.greater[1]] = true
        STATE.learned = {}
        for i = 1, 6 do STATE.learned[M.normal[i]] = 60 end
        STATE.learned[M.greater[1]] = 40
        ns.Refresh()
        local slot
        for _, s in ipairs(row(o, "party1").slots) do if s.family == "MIGHT" then slot = s end end
        assert.is_true(slot.faint)
        RUNSCRIPT(slot, "OnEnter")
        assert.are.equal(M.greater[1], GameTooltip.spell)
    end)

    it("opens no menu on a right click, on a row or on the blessing button, Shift or not", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        RUNSCRIPT(row(o, "party1"), "OnMouseUp", "RightButton")
        for _, shift in ipairs({ false, true }) do
            STATE.shift = shift
            RUNCLICK(ns.blessingButton, "RightButton", true)
            RUNCLICK(ns.blessingButton, "RightButton", false)
        end
        assert.is_nil(STATE.menu)
        assert.are.same({}, STATE.errors)
    end)
end)

-- The aura slot: in front of a paladin's blessings, the aura he runs himself
-- (ruleset plan 2026-10-19-tab-layout)
describe("the overview's aura slot", function()
    local DEV, RET = D.AURAS.DEVOTION[7], D.AURAS.RETRIBUTION[1]

    it("shows the aura a paladin runs, without border, not the one another gives him", function()
        local _, o = login({ group = "party", units = {
            player = { class = "PALADIN", auras = { aura(DEV, { source = "player", mine = true }),
                                                    aura(RET, { source = "party1" }) } },
            party1 = { class = "PALADIN", auras = { aura(RET, { source = "party1" }),
                                                    aura(DEV, { source = "player" }) } } } })
        local mine, his = row(o, "player").aura, row(o, "party1").aura
        assert.is_true(mine:IsShown())
        assert.are.equal(DEV, mine.spell)
        assert.are.equal("icon" .. DEV, mine.tex:GetTexture())
        assert.is_nil(mine.border)
        assert.is_true(his:IsShown())
        assert.are.equal(RET, his.spell)
    end)

    it("leaves the slot empty for every other class and a paladin without aura, his own blessing aside", function()
        local _, o = login({ group = "party", units = {
            player = { class = "PALADIN" },
            party1 = { class = "WARRIOR", auras = { aura(DEV, { source = "party1" }) } },
            party2 = { class = "PALADIN", auras = { aura(M.normal[1], { source = "party2" }) } } } })
        assert.is_false(row(o, "party1").aura:IsShown())
        assert.is_false(row(o, "player").aura:IsShown())
        assert.is_false(row(o, "party2").aura:IsShown())
    end)

    it("hides a secret aura", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "PALADIN",
            auras = { aura(DEV, { source = "party1" }) } } } })
        assert.is_true(row(o, "party1").aura:IsShown())
        STATE.secrets = { [DEV] = true }
        FIRE("UNIT_AURA", "party1")
        ns.Refresh()
        assert.is_false(row(o, "party1").aura:IsShown())
    end)

    it("dims the aura of a greyed paladin and shows none for one out of sight", function()
        local _, o = login({ group = "party", units = {
            party1 = { class = "PALADIN", range = false, auras = { aura(DEV, { source = "party1" }) } },
            party2 = { class = "PALADIN", visible = false, auras = { aura(RET, { source = "party2" }) } } } })
        assert.are.equal(0.4, row(o, "party1").aura.tex:GetAlpha())
        assert.is_false(row(o, "party2").aura:IsShown())
    end)

    it("explains the aura as the other icons, without minutes", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "PALADIN", name = "Tyr",
            auras = { aura(DEV, { source = "party1" }) } } } })
        RUNSCRIPT(row(o, "party1").aura, "OnEnter")
        local lines = {}
        for _, l in ipairs(GameTooltip.lines) do lines[#lines + 1] = l[1] end
        assert.are.equal(DEV, GameTooltip.spell)
        assert.are.same({ ns.L.OV_FROM:format("Tyr") }, lines)
    end)

end)

-- Opening: the minimap button's middle click, nothing else (ruleset plan 2026-10-19-priorities)
describe("opening the overview", function()
    local function fresh()
        local ns = addon.load("enUS")
        STATE.known = { [M.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        return ns, ns.UI.window, ns.overviewHost.page
    end

    it("opens the settings on the Priorities tab with a middle click on the minimap button", function()
        local ns, window, page = fresh()
        local mb = ns.minimapButton
        assert.is_truthy(table.concat(mb.clicks, ","):find("MiddleButtonUp", 1, true))
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_true(page:IsShown())
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_false(window:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("switches to the Priorities tab when the window shows another", function()
        local ns, window, page = fresh()
        SlashCmdList.SMARTBLESSINGBAR("")
        RUNSCRIPT(ns.UI.tabs[1], "OnClick")
        assert.is_false(page:IsShown())
        RUNSCRIPT(ns.minimapButton, "OnClick", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_true(page:IsShown())
    end)

    it("names the middle click in the minimap button's tooltip", function()
        local ns = fresh()
        RUNSCRIPT(ns.minimapButton, "OnEnter")
        local found = false
        for _, l in ipairs(GameTooltip.lines) do
            if l[1] == ns.L.MIDDLECLICK and l[2] == ns.L.TAB_PRIORITIES then found = true end
        end
        assert.is_true(found)
    end)

    it("says why nothing opens in combat", function()
        local ns, window = fresh()
        STATE.combat = true
        RUNSCRIPT(ns.minimapButton, "OnClick", "MiddleButton")
        assert.is_false(window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)

    it("has no chat command and no window of its own any more", function()
        local ns = fresh()
        SlashCmdList.SMARTBLESSINGBAR("overview")
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.CMD_UNKNOWN:format("|cffffd100/sbb help|r"), 1, true))
        assert.is_nil(ns.ToggleOverview)
        assert.is_nil(_G.SmartBlessingBarOverview)
    end)
end)
