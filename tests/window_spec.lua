-- Settings.lua: the window, its tabs, Escape and combat (ruleset plan 2026-10-18-settings-window,
-- IMPLEMENTATION "Tests, by phase" 2). Opening goes through /sbb.

local addon = require("addon")

local function login()
    local ns = addon.load("enUS")
    FIRE("PLAYER_LOGIN")
    return ns, ns.UI
end

local function sbb(msg) SlashCmdList.SMARTBLESSINGBAR(msg) end

describe("the settings window", function()
    it("opens and closes with /sbb, and closes with Escape", function()
        local _, UI = login()
        local window = UI.window
        assert.is_false(window:IsShown())
        sbb("")
        assert.is_true(window:IsShown())
        sbb("")
        assert.is_false(window:IsShown())
        local escape = false
        for _, name in ipairs(UISpecialFrames) do
            if name == window:GetName() then escape = true end
        end
        assert.is_true(escape)
    end)

    it("has its tabs in order, and a tab shows its page alone", function()
        local ns, UI = login()
        sbb("")
        local names = {}
        for i, tab in ipairs(UI.tabs) do names[i] = tab:GetText() end
        assert.are.same({ ns.L.TAB_GENERAL, ns.L.TAB_TRACKING, ns.L.TAB_SUPPLIES, ns.L.TAB_PRIORITIES,
                          ns.L.TAB_ORDER, ns.L.TAB_MACROS },
            names)
        assert.is_true(UI.pages[1]:IsShown())
        RUNSCRIPT(UI.tabs[2], "OnClick")
        assert.is_false(UI.pages[1]:IsShown())
        assert.is_true(UI.pages[2]:IsShown())
    end)

    it("prepares a Macros tab that says macros come later", function()
        local ns, UI = login()
        sbb("")
        RUNSCRIPT(UI.tabs[5], "OnClick")
        assert.is_true(UI.pages[5]:IsShown())
        assert.are.equal(ns.L.MACROS_LATER, UI.controls.macrosNote:GetText())
        assert.are.same({}, STATE.errors)
    end)

    it("closes when combat starts, and opens again only if combat closed it", function()
        local _, UI = login()
        sbb("")
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        assert.is_false(UI.window:IsShown())
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(UI.window:IsShown())

        sbb("") -- closed by hand before the next fight
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_false(UI.window:IsShown())
    end)

    it("does not open in combat, and says why", function()
        local ns, UI = login()
        STATE.combat = true
        sbb("")
        assert.is_false(UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.MENU_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)

    it("follows a language change in its tab texts", function()
        local ns, UI = login()
        sbb("")
        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.TAB_GENERAL, UI.tabs[1]:GetText())
    end)
end)

-- Window background (ruleset plan 2026-10-22-anchor-and-window-background, criterion 3): the
-- dialog texture fades out below today's value, a black layer beneath it fills in above
describe("the window background", function()
    local function expected(ns, pct)
        local o, d = pct / 100, ns.D.WINDOW_OPACITY_TODAY / 100
        return math.min(1, o / d), math.max(0, (o - d) / (1 - d))
    end
    local function check(ns, window, pct)
        local tex, layer = expected(ns, pct)
        assert.is_true(math.abs(window.backdropColor[4] - tex) < 0.01, pct .. " % texture")
        assert.is_true(math.abs(window.opacityLayer:GetAlpha() - layer) < 0.01, pct .. " % layer")
        assert.are.equal(1, window:GetAlpha())
    end

    it("follows the slider in both windows, an open report at once, today's look at 60 %", function()
        local ns, UI = login()
        sbb("")
        ns.OpenBugReport()
        local report = ns.reportWindow
        sbb("")
        local slider = UI.controls.windowOpacity
        for _, pct in ipairs({ 0, 30, 60, 80, 100 }) do
            slider:SetValue(pct)
            RUNSCRIPT(slider, "OnValueChanged", pct)
            assert.are.equal(pct, SmartBlessingBarDB.windowOpacity)
            check(ns, UI.window, pct)
            check(ns, report, pct)
        end
        assert.are.same({ 1, 0 }, { expected(ns, 60) })
        for _, w in ipairs({ UI.window, report }) do
            assert.are.equal("BACKGROUND", w.opacityLayer.layer)
            assert.is_true(w.opacityLayer.sublevel < w.Center.sublevel)
        end
    end)

    it("opens a closed report with the value set meanwhile", function()
        local ns = login()
        ns.OpenBugReport()
        local report = ns.reportWindow
        report:Hide()
        SmartBlessingBarDB.windowOpacity = 100
        ns.OpenBugReport()
        check(ns, report, 100)
    end)

    it("sits right of Scale in one row and takes 150 typed as 100", function()
        local _, UI = login()
        sbb("")
        local c = UI.controls
        local scaleRow, row = c.scaleSlider:GetParent(), c.windowOpacity:GetParent()
        -- SetPoint("TOPLEFT", x, y)
        assert.are.equal(select(3, scaleRow:GetPoint(1)), select(3, row:GetPoint(1)))
        assert.is_true(select(2, row:GetPoint(1)) > select(2, scaleRow:GetPoint(1)))
        c.windowOpacityBox:SetText("150")
        RUNSCRIPT(c.windowOpacityBox, "OnEnterPressed")
        assert.are.equal(100, SmartBlessingBarDB.windowOpacity)
    end)
end)
