-- The bar's look follows SimpleConjureBar's, so both addons read as one family: backdrop on
-- the bar, a handle that shows only under the mouse, buttons laid out with SimpleConjureBar's
-- size, gap and padding. The aura flyout and its arrow went with ruleset plan
-- 2026-10-19-priorities.

local addon = require("addon")

local function login()
    local ns = addon.load("enUS", { group = "party", units = { party1 = { class = "MAGE" } } })
    local A = ns.D.AURAS
    STATE.known = { [A.DEVOTION[1]] = true, [A.RETRIBUTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.D
end

describe("the look", function()
    it("gives the bar SimpleConjureBar's backdrop and color", function()
        local ns, D = login()
        local c = D.BG_COLOR
        assert.are.equal(D.BACKDROP, ns.bar.backdrop)
        assert.are.same({ c.r, c.g, c.b, c.a }, ns.bar.backdropColor)
    end)

    it("cuts every button's icon alike", function()
        local ns = login()
        for _, b in ipairs({ ns.furyButton, ns.blessingButton, ns.salvationButton }) do
            assert.are.same({ 0.07, 0.93, 0.07, 0.93 }, b.icon.texCoord)
        end
    end)

    it("has no flyout and no arrow on any button", function()
        local ns = login()
        assert.is_nil(ns.flyouts)
        for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }) do
            assert.is_nil(rawget(b, "arrow"))
        end
    end)

    it("shows the handle only while the mouse is over it, Show anchor off", function()
        local ns = login()
        SmartBlessingBarDB.showAnchor = false
        ns.ApplyAnchor()
        assert.are.equal(0, ns.handle:GetAlpha())
        RUNSCRIPT(ns.handle, "OnEnter")
        assert.are.equal(1, ns.handle:GetAlpha())
        RUNSCRIPT(ns.handle, "OnLeave")
        assert.are.equal(0, ns.handle:GetAlpha())
    end)

    it("lays the buttons out with SimpleConjureBar's padding and gap", function()
        local ns, D = login()
        local step = D.SIZE + D.GAP
        assert.are.equal(D.PAD, select(4, ns.auraButton:GetPoint()))
        assert.are.equal(D.PAD + step, select(4, ns.furyButton:GetPoint()))
        assert.are.equal(D.PAD + 2 * step, select(4, ns.blessingButton:GetPoint()))
        assert.are.equal(D.PAD + 3 * step, select(4, ns.salvationButton:GetPoint()))
        assert.are.equal(D.PAD + 4 * step - D.GAP + D.PAD, ns.bar:GetWidth())
    end)
end)
