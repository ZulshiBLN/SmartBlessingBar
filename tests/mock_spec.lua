-- The mock's secure snippets and clicks behave as the client's do, as far as the flyouts
-- rely on it (ruleset plan 2026-10-18-flyouts, IMPLEMENTATION "Tests, by phase" 1).
-- Each case is one rule of the client's WrapScript and SecureActionButtonTemplate.

local addon = require("addon")

-- A fresh mock with a header and one secure button wrapped by it
local function setup(pre, post)
    addon.load("enUS")
    local header = CreateFrame("Frame", "MockHeader", UIParent, "SecureHandlerBaseTemplate")
    local button = CreateFrame("Button", "MockButton", UIParent, "SecureActionButtonTemplate")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("spell1", 100)
    button:SetAttribute("unit1", "player")
    header:WrapScript(button, "OnClick", pre, post)
    return header, button
end

describe("a wrapped secure click in the mock", function()
    it("casts on key down when the pre body lets it through", function()
        local _, button = setup([[ return nil, "go" ]])
        RUNCLICK(button, "LeftButton", true)
        RUNCLICK(button, "LeftButton", false)
        assert.are.same({ { spell = 100, unit = "player" } }, STATE.casts)
        assert.are.same({}, STATE.errors)
    end)

    it("casts on key up instead while ActionButtonUseKeyDown is off", function()
        local _, button = setup([[ return nil, "go" ]])
        STATE.keyDown = false
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(0, #STATE.casts)
        RUNCLICK(button, "LeftButton", false)
        assert.are.equal(1, #STATE.casts)
    end)

    it("stops the action and the post body when the pre body returns false", function()
        local _, button = setup([[ return false ]], [[ self:SetAttribute("posted", true) ]])
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(0, #STATE.casts)
        assert.is_nil(button:GetAttribute("posted"))
    end)

    it("runs the post body only with a message, and hands the message over", function()
        -- A constant: setting `message` would read nil whether the body ran or not
        local _, silent = setup([[ return ]], [[ self:SetAttribute("posted", "ran") ]])
        RUNCLICK(silent, "LeftButton", true)
        assert.are.equal(1, #STATE.casts)
        assert.is_nil(silent:GetAttribute("posted"))

        local _, button = setup([[ return nil, "chosen" ]], [[ self:SetAttribute("posted", message) ]])
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal("chosen", button:GetAttribute("posted"))
    end)

    it("lets a snippet show a protected frame in combat, which addon code may not", function()
        local header, button = setup([[
            owner:GetFrameRef("target"):Show()
            return false
        ]])
        local protected = CreateFrame("Frame", "MockFlyout", UIParent)
        CreateFrame("Button", "MockChild", protected, "SecureActionButtonTemplate")
        header:SetFrameRef("target", protected)
        protected.shown = false
        STATE.combat = true
        assert.has_error(function() protected:Show() end)
        RUNCLICK(button, "RightButton", false)
        assert.is_true(protected:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("takes type1 for the left button, type2 for the right, and plain type for both", function()
        local _, button = setup()
        button:SetAttribute("type2", "spell")
        button:SetAttribute("spell2", 200)
        RUNCLICK(button, "RightButton", true)
        assert.are.equal(200, STATE.casts[1].spell)

        local _, plain = setup()
        plain:SetAttribute("type1", nil)
        plain:SetAttribute("type", "spell")
        plain:SetAttribute("spell", 300)
        RUNCLICK(plain, "RightButton", true)
        assert.are.equal(300, STATE.casts[1].spell)
    end)

    it("allows the auto-hide only on a protected frame, and adds frames only after registering", function()
        local header, button = setup([[
            local plain = owner:GetFrameRef("plain")
            plain:RegisterAutoHide(2)
            return false
        ]])
        header:SetFrameRef("plain", CreateFrame("Frame", "MockPlain", UIParent))
        RUNCLICK(button, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("unprotected", 1, true))

        local header2, button2 = setup([[
            local fly = owner:GetFrameRef("fly")
            fly:AddToAutoHide(self)
            return false
        ]])
        local fly = CreateFrame("Frame", "MockFly", UIParent)
        CreateFrame("Button", "MockFlyChild", fly, "SecureActionButtonTemplate")
        header2:SetFrameRef("fly", fly)
        RUNCLICK(button2, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("before RegisterAutoHide", 1, true))
    end)

    it("refuses a handle to an unprotected frame in combat, as the client does", function()
        local header, button = setup([[
            owner:GetFrameRef("plain"):IsShown()
            return false
        ]])
        header:SetFrameRef("plain", CreateFrame("Frame", "MockPlain2", UIParent))
        RUNCLICK(button, "RightButton", false)
        assert.are.same({}, STATE.errors)
        STATE.combat = true
        RUNCLICK(button, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("Invalid frame handle", 1, true))
    end)

    it("runs insecure hooks after the secure action", function()
        local _, button = setup([[ return nil, "go" ]])
        local seen
        button:HookScript("OnClick", function() seen = #STATE.casts end)
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(1, seen)
    end)
end)

-- What Buff & Run relies on (ruleset plan 2026-10-20-buff-and-run): PreClick, the middle
-- button's attributes, a macro running /click and /targetfriendplayer, friendly players and
-- the cooldown read
describe("the mock for Buff & Run", function()
    local function buttons()
        addon.load("enUS")
        local hidden = CreateFrame("Button", "MockHidden", UIParent, "SecureActionButtonTemplate")
        hidden:SetAttribute("type", "spell")
        hidden:SetAttribute("spell", 19740)
        hidden:SetAttribute("unit", "target")
        local b = CreateFrame("Button", "MockMacro", UIParent, "SecureActionButtonTemplate")
        b:SetAttribute("type3", "macro")
        b:SetAttribute("macrotext3", "/click MockHidden LeftButton 1\n/targetfriendplayer")
        return b, hidden
    end

    it("runs PreClick before the action, and the action reads attributes set there", function()
        local b, hidden = buttons()
        local order = {}
        b:SetScript("PreClick", function(_, button, down)
            order[#order + 1] = "pre " .. button .. " " .. tostring(down)
            hidden:SetAttribute("spell", 20217)
        end)
        STATE.units.target = { class = "MAGE" }
        RUNCLICK(b, "MiddleButton", true)
        assert.are.same({ "pre MiddleButton true" }, order)
        assert.are.same({ { spell = 20217, unit = "target" } }, STATE.casts)
    end)

    it("clicks the named button on key down, then targets the next friendly player", function()
        local b = buttons()
        local first, second = { class = "MAGE" }, { class = "ROGUE" }
        STATE.units.target = first
        STATE.friends = { second }
        RUNCLICK(b, "MiddleButton", true)
        assert.are.same({ { spell = 19740, unit = "target" } }, STATE.casts)
        assert.are.equal(second, STATE.units.target)
        assert.are.equal(1, STATE.targetedNext)
        RUNCLICK(b, "MiddleButton", false) -- key up: no second action
        assert.are.equal(1, STATE.targetedNext)
    end)

    it("does nothing without type3, and nothing for a /click of a button that does not exist", function()
        local b = buttons()
        b:SetAttribute("macrotext3", "/click Nowhere LeftButton 1")
        RUNCLICK(b, "MiddleButton", true)
        b:SetAttribute("type3", nil)
        RUNCLICK(b, "MiddleButton", true)
        assert.are.same({}, STATE.casts)
        assert.are.same({}, STATE.errors)
    end)

    it("tells players from others, friends from foes, and reads a cooldown", function()
        addon.load("enUS")
        STATE.units.target = { class = "MAGE" }
        assert.is_true(UnitIsPlayer("target"))
        assert.is_true(UnitCanAssist("player", "target"))
        STATE.units.target = { npc = true, hostile = true }
        assert.is_false(UnitIsPlayer("target"))
        assert.is_false(UnitCanAssist("player", "target"))
        assert.are.equal(0, C_Spell.GetSpellCooldown(19740).startTime)
        STATE.gcd = true
        local cd = C_Spell.GetSpellCooldown(19740)
        assert.is_true(cd.startTime > 0)
        assert.are.equal(1.5, cd.duration)
    end)
end)

-- Secret auras out of combat (restricted_spec.lua): the client refuses the read with an error;
-- C_Secrets says so beforehand, unless the client has no C_Secrets
describe("secret auras in the mock", function()
    it("refuse a read with an error, and C_Secrets answers or is missing", function()
        addon.load("enUS")
        assert.is_false(C_Secrets.ShouldAurasBeSecret())
        assert.is_true(pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL"))
        STATE.aurasSecret = true
        assert.is_true(C_Secrets.ShouldAurasBeSecret())
        assert.is_false(pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL"))
        STATE.noSecretsApi = true
        assert.is_nil(C_Secrets.ShouldAurasBeSecret)
    end)

    -- A SetPoint with an unknown anchor name errors, as in the client (bar_spec.lua)
    it("refuse an unknown anchor name", function()
        addon.load("enUS")
        local f = CreateFrame("Frame")
        assert.is_true(pcall(f.SetPoint, f, "TOPLEFT", UIParent, "BOTTOMLEFT", 0, 0))
        assert.is_false(pcall(f.SetPoint, f, "FOO"))
        assert.is_false(pcall(f.SetPoint, f, "LEFT", UIParent, "left"))
    end)
end)

-- The counts the read specs rely on (reads_spec.lua): a scan per person and filter, and every
-- IsPlayerSpell question
describe("the mock's read counts", function()
    it("count a scan per person and filter, and each spell question", function()
        addon.load("enUS", { group = "party", units = { party1 = { class = "MAGE", auras = {
            { spellId = 1, expirationTime = 0 }, { spellId = 2, expirationTime = 0, mine = true } } } } })
        local r = STATE.units.party1
        STATE.units.raid9 = r -- a second token of the same person
        for i = 1, 3 do C_UnitAuras.GetAuraDataByIndex("party1", i, "HELPFUL") end
        C_UnitAuras.GetAuraDataByIndex("raid9", 1, "HELPFUL")
        C_UnitAuras.GetAuraDataByIndex("party1", 1, "HELPFUL|PLAYER")
        assert.are.same({ HELPFUL = 2, ["HELPFUL|PLAYER"] = 1 }, STATE.scans[r])
        IsPlayerSpell(5)
        IsPlayerSpell(5)
        assert.are.equal(2, STATE.spellChecks[5])
    end)
end)

-- The PvP flag Buff & Run reads (buffrun_spec.lua)
describe("the mock's PvP flag", function()
    it("answers the record's pvp", function()
        addon.load("enUS")
        assert.is_false(UnitIsPVP("player"))
        STATE.units.player.pvp = true
        assert.is_true(UnitIsPVP("player"))
        assert.is_false(UnitIsPVP("target"))
    end)
end)

-- A fixed order, so a spec can rely on one: in SimpleConjureBar the random order of pairs had
-- hidden a lost-window bug (its 3ecc2ea)
describe("the mock's events", function()
    it("reach the frames in the order they first registered", function()
        require("addon").load("enUS")
        local order, expected = {}, {}
        for i = 1, 30 do
            local f = CreateFrame("Frame")
            f:RegisterEvent("X_EVENT")
            f:RegisterEvent("X_EVENT") -- registering again keeps the first place
            f:SetScript("OnEvent", function() order[#order + 1] = i end)
            expected[i] = i
        end
        FIRE("X_EVENT")
        assert.are.same(expected, order)
    end)
end)
