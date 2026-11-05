-- Guards that every spec passed by before: removing one left the suite green (the 1.1.0 code
-- review's F-04 and F-05; ruleset plan 2026-10-24-review-code-fixes, phase 2).

local addon = require("addon")

local function login()
    local ns = addon.load("enUS")
    FIRE("PLAYER_LOGIN"); RUNTIMERS()
    return ns
end

describe("the guards", function()
    it("write no secure attribute in combat", function()
        local ns = login()
        local b = ns.blessingButton
        local before = b:GetAttribute("spell1")
        STATE.combat = true
        ns.SetAttr(b, "spell1", 424242)
        assert.are.equal(before, b:GetAttribute("spell1"))
        STATE.combat = false
        ns.SetAttr(b, "spell1", 424242)
        assert.are.equal(424242, b:GetAttribute("spell1"))
    end)

    it("keep the action log's last 50 in order once it wraps", function()
        local ns = login()
        for i = 1, 60 do ns.Log("entry " .. i) end
        local lines = ns.LogLines()
        assert.are.equal(50, #lines)
        assert.is_truthy(lines[1]:find("entry 11$"), lines[1])
        assert.is_truthy(lines[50]:find("entry 60$"), lines[50])
    end)

    it("hide the handle after a drag while Show anchor is off", function()
        local ns = login()
        SmartBlessingBarDB.showAnchor = false
        local h = ns.handle
        RUNSCRIPT(h, "OnMouseDown", "LeftButton")
        assert.are.equal(1, h:GetAlpha())
        RUNSCRIPT(h, "OnMouseUp", "LeftButton")
        assert.are.equal(0, h:GetAlpha())
    end)

    it("leave no spell from an earlier Buff & Run click when the choice fails", function()
        local ns = login()
        local D = ns.D
        STATE.known = { [D.BLESSINGS.WISDOM.normal[1]] = true }
        STATE.units.target = { class = "MAGE" }
        ns.Refresh()
        local b = ns.blessingButton
        RUNSCRIPT(b, "PreClick", "MiddleButton", true)
        local run = _G.SmartBlessingBarBuffRun
        assert.are.equal(D.BLESSINGS.WISDOM.normal[1], run:GetAttribute("spell"))
        ns.Blessings.BuffRunSpell = function() error("broken choice") end
        pcall(RUNSCRIPT, b, "PreClick", "MiddleButton", true)
        assert.is_nil(run:GetAttribute("spell"))
    end)
end)
