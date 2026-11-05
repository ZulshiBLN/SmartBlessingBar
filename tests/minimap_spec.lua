-- Minimap.lua: the minimap button, the AddOn compartment and the options entry (ruleset plan
-- 2026-10-18-settings-more, IMPLEMENTATION "Tests, by phase" 4).

local addon = require("addon")

local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    return ns, SmartBlessingBarDB
end

local function lines()
    local out = {}
    for _, l in ipairs(GameTooltip.lines) do out[#out + 1] = l[2] and (l[1] .. "|" .. l[2]) or l[1] end
    return out
end

describe("the minimap button", function()
    it("opens and closes the settings on a left click, and locks on a right click", function()
        local ns, db = login()
        local btn = ns.minimapButton
        assert.are.equal("SmartBlessingBarMinimapButton", btn:GetName())
        RUNSCRIPT(btn, "OnClick", "LeftButton")
        assert.is_true(ns.UI.window:IsShown())
        RUNSCRIPT(btn, "OnClick", "LeftButton")
        assert.is_false(ns.UI.window:IsShown())
        RUNSCRIPT(btn, "OnClick", "RightButton")
        assert.is_true(db.locked)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.LOCKED, 1, true))
    end)

    it("shows the TOC's icon", function()
        local ns = login()
        assert.are.equal(C_AddOns.GetAddOnMetadata("SmartBlessingBar", "IconTexture"), ns.minimapButton.icon:GetTexture())
    end)

    -- Measured in game by Michel (2026-10-20): the ring's circle sits off its texture's centre,
    -- so the ring is moved and the round icon centred in it
    it("centres a round icon in its ring", function()
        local ns = login()
        local D, btn = ns.D, ns.minimapButton
        local icon, bg, ring, highlight = btn.icon, btn.background, btn.ring, btn:GetHighlightTexture()
        local inner, ringAt = D.MINIMAP_INNER_OFFSET, D.MINIMAP_RING_OFFSET
        assert.are.same({ D.MINIMAP_ICON_SIZE, D.MINIMAP_ICON_SIZE }, { icon:GetSize() })
        assert.are.same({ D.MINIMAP_ICON_SIZE + 2, D.MINIMAP_ICON_SIZE + 2 }, { bg:GetSize() })
        for _, t in ipairs({ icon, bg, highlight }) do
            assert.are.same({ "CENTER", inner[1], inner[2] }, { t:GetPoint() })
        end
        assert.are.same({ "CENTER", ringAt[1], ringAt[2] }, { ring:GetPoint() })
        -- One anchor sets no size: the highlight keeps the button's, or it would not show
        assert.are.same({ btn:GetSize() }, { highlight:GetSize() })
        assert.are.equal(1, #icon.masks)
        assert.are.equal("Interface\\CharacterFrame\\TempPortraitAlphaMask", icon.masks[1]:GetTexture())
    end)

    it("moves around the minimap while dragged, and stops on release", function()
        local ns, db = login()
        local btn = ns.minimapButton
        assert.are.equal(ns.D.NUMBER_DEFAULTS.minimapAngle.default, db.minimapAngle)
        local mx, my = Minimap:GetCenter()
        STATE.cursor = { mx, my + 50 } -- straight above the centre
        RUNSCRIPT(btn, "OnDragStart")
        RUNSCRIPT(btn, "OnUpdate", 0.01)
        assert.are.equal(90, db.minimapAngle)
        local p, rel, relP, x, y = btn:GetPoint()
        assert.are.same({ "CENTER", Minimap, "CENTER" }, { p, rel, relP })
        assert.is_true(math.abs(x) < 0.001)
        assert.are.equal(Minimap:GetWidth() / 2 + 10, y)
        RUNSCRIPT(btn, "OnDragStop")
        assert.is_nil(btn:GetScript("OnUpdate"))
    end)

    it("names its clicks and the drag in its tooltip", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.minimapButton, "OnEnter")
        assert.are.equal("ANCHOR_LEFT", GameTooltip.anchor)
        assert.is_truthy(GameTooltip:GetText():find(ns.VERSION, 1, true))
        assert.are.same({ " ", L.LEFTCLICK .. "|" .. L.SETTINGS, L.MIDDLECLICK .. "|" .. L.TAB_PRIORITIES,
                          L.RIGHTCLICK .. "|" .. L.LOCK_BAR, L.DRAG .. "|" .. L.MOVE }, lines())
    end)

    it("hides with the General setting, and stays hidden and in place after a login", function()
        local ns, db = login()
        SlashCmdList.SMARTBLESSINGBAR("")
        local cb = ns.UI.controls.hideMinimap
        cb:SetChecked(true)
        RUNSCRIPT(cb, "OnClick")
        assert.is_true(db.hideMinimap)
        assert.is_false(ns.minimapButton:IsShown())
        db.minimapAngle = 90
        local again = login({ db = db })
        assert.is_true(SmartBlessingBarDB.hideMinimap)
        assert.are.equal(90, SmartBlessingBarDB.minimapAngle)
        assert.is_false(again.minimapButton:IsShown())
    end)
end)

describe("the AddOn compartment", function()
    it("opens the settings, locks, and shows a tooltip without the drag", function()
        local ns, db = login()
        SmartBlessingBar_OnCompartmentClick(nil, "LeftButton")
        assert.is_true(ns.UI.window:IsShown())
        SmartBlessingBar_OnCompartmentClick(nil, "RightButton")
        assert.is_true(db.locked)
        local entry = NEWOBJ("Button")
        SmartBlessingBar_OnCompartmentEnter(nil, entry)
        assert.are.equal(entry, GameTooltip.owner)
        assert.are.equal("ANCHOR_RIGHT", GameTooltip.anchor)
        assert.are.equal(3, #GameTooltip.lines)
        SmartBlessingBar_OnCompartmentLeave()
        assert.is_false(GameTooltip:IsShown())
    end)

    it("does nothing for any other class, and raises no error", function()
        local ns = addon.load("enUS", { class = "MAGE" })
        FIRE("PLAYER_LOGIN")
        assert.is_nil(ns.CompartmentClick) -- Minimap.lua stopped at its paladin check
        local ok = pcall(function()
            SmartBlessingBar_OnCompartmentClick(nil, "LeftButton")
            SmartBlessingBar_OnCompartmentEnter(nil, NEWOBJ("Button"))
            SmartBlessingBar_OnCompartmentLeave()
        end)
        assert.is_true(ok)
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the options entry", function()
    it("registers a page whose button opens the window above the client's options", function()
        local ns = login()
        assert.are.equal("SmartBlessingBar", STATE.options.category.name)
        assert.are.equal(STATE.options.category, STATE.options.registered)
        RUNSCRIPT(ns.optionsOpenButton, "OnClick")
        local window = ns.UI.window
        assert.is_true(window:IsShown())
        assert.are.equal("FULLSCREEN_DIALOG", window:GetFrameStrata())
        RUNSCRIPT(ns.optionsOpenButton, "OnClick") -- opens, never closes
        assert.is_true(window:IsShown())
        window:Hide()
        assert.are.equal("DIALOG", window:GetFrameStrata())
    end)
end)

describe("the minimap button's right click", function()
    it("shows the new lock state in the open tooltip at once", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.minimapButton, "OnEnter")
        RUNSCRIPT(ns.minimapButton, "OnClick", "RightButton")
        assert.is_true(SmartBlessingBarDB.locked)
        local found
        for _, l in ipairs(GameTooltip.lines) do
            if l[1] == L.RIGHTCLICK then found = l[2] end
        end
        assert.are.equal(L.UNLOCK_BAR, found)
    end)
end)
