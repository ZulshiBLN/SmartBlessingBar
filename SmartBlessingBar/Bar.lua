-- SmartBlessingBar - the bar
-- Handle, position and lock, the look, and the layout of its four buttons: aura, Righteous
-- Fury, blessing and Salvation (ruleset plan 2026-10-19-blessing-core). Out of combat the
-- refresh writes what changed; in combat nothing is rewritten and the buttons keep what they
-- had.

local _, ns = ...
if not ns.enabled then return end

local D, L = ns.D, ns.L

local SIZE, GAP, PAD = D.SIZE, D.GAP, D.PAD

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- The bar's look: SimpleConjureBar's
---------------------------------------------------------------------------
function ns.ApplyBackdrop(frame)
    frame:SetBackdrop(D.BACKDROP)
    local c, e = D.BG_COLOR, D.BORDER_COLOR
    frame:SetBackdropColor(c.r, c.g, c.b, c.a)
    frame:SetBackdropBorderColor(e.r, e.g, e.b, e.a)
end

-- A secure button with its own action button look, as in SimpleConjureBar. Deliberately
-- without ActionButtonTemplate: its scripts override a secure button's click handling.
function ns.CreateSecureButton(name, parent)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)

    -- Pixel-exact symmetric border: dark background, icon inset by 1 px
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 1)

    b.icon = b:CreateTexture(nil, "BORDER")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Pushed and hover textures exactly on the icon
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pushed = b:GetPushedTexture()
    pushed:ClearAllPoints()
    pushed:SetAllPoints(b.icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = b:GetHighlightTexture()
    hl:ClearAllPoints()
    hl:SetAllPoints(b.icon)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)

    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    return b
end

-- A button's icon, and a font string's text, written only when they change: the refresh
-- runs every second (ruleset plan 2026-10-20-performance-pvp)
function ns.SetIcon(b, texture, desaturated)
    if b.iconTexture ~= texture then
        b.iconTexture = texture
        b.icon:SetTexture(texture)
    end
    if b.iconDesaturated ~= desaturated then
        b.iconDesaturated = desaturated
        b.icon:SetDesaturated(desaturated)
    end
end

function ns.SetText(fs, text)
    if fs.shownText ~= text then
        fs.shownText = text
        fs:SetText(text)
    end
end

-- The spell a main button casts, as the game's own tooltip, and whom the left click reaches
function ns.ShowSpellTooltip(self)
    local spell = self:GetAttribute("spell1")
    if not spell then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(spell)
    GameTooltip:AddDoubleLine(L.LEFTCLICK, (UnitName("player")), 1, 1, 1)
    GameTooltip:Show()
end

function ns.HideTooltip()
    GameTooltip:Hide()
end

-- The highlight, shared by all four buttons of the bar: the modern client's proc glow
-- (ruleset plan 2026-10-20-button-tips-glow; the "ants" of SimpleConjureBar before, whose
-- names the code and the settings keep). It sits on its own frame above the button; the
-- client plays its flipbook only while it is visible. Color and speed are settings: colorKey
-- and speedKey name them. ns.ApplyLook colors it and sets its speed.
local antsButtons = {}
function ns.AttachAnts(b, colorKey, speedKey)
    local holder = CreateFrame("Frame", nil, b)
    holder:SetAllPoints()
    holder:SetFrameLevel(b:GetFrameLevel() + 2)

    local ants = holder:CreateTexture(nil, "OVERLAY")
    ants:SetAtlas(D.GLOW_ATLAS)
    ants:SetDesaturated(true)
    ants:SetPoint("CENTER")
    ants:SetSize(SIZE * D.GLOW_SCALE, SIZE * D.GLOW_SCALE)
    ants:Hide()

    local anim = ants:CreateAnimationGroup()
    anim:SetLooping("REPEAT")
    local flip = anim:CreateAnimation("FlipBook")
    flip:SetFlipBookRows(D.GLOW_ROWS)
    flip:SetFlipBookColumns(D.GLOW_COLUMNS)
    flip:SetFlipBookFrames(D.GLOW_FRAMES)

    b.ants, b.antsHolder, b.antsAnim, b.antsFlip = ants, holder, anim, flip
    b.antsColorKey, b.antsSpeedKey = colorKey, speedKey
    antsButtons[#antsButtons + 1] = b
end

-- Shows or hides a button's highlight and starts or stops its animation
function ns.SetAnts(b, shown)
    -- A button cast in combat stays dark until the planners read the group again
    if b.cast then shown = false end
    if shown == b.antsShown then return end
    b.antsShown = shown
    if shown then
        b.ants:Show()
        b.antsAnim:Play()
    else
        b.ants:Hide()
        b.antsAnim:Stop()
    end
end

---------------------------------------------------------------------------
-- Bar and handle
---------------------------------------------------------------------------
local bar = CreateFrame("Frame", "SmartBlessingBarFrame", UIParent, "BackdropTemplate")
ns.bar = bar
bar:SetSize(SIZE + 2 * PAD, SIZE + 2 * PAD)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150) -- start position, replaced at login
ns.ApplyBackdrop(bar)

-- Drag handle; visible while Show anchor is on, else only while the mouse is over it or while
-- dragging (ruleset plan 2026-10-22-anchor-and-window-background)
local handle = CreateFrame("Frame", nil, bar)
ns.handle = handle
handle:SetSize(10, SIZE)
handle:SetPoint("RIGHT", bar, "LEFT", -1, 0)
handle:EnableMouse(true)
handle:SetAlpha(0)
local handleTex = handle:CreateTexture(nil, "BACKGROUND")
handleTex:SetAllPoints()
-- SimpleConjureBar's handle tooltip: the lock state and what each click does
local function ShowHandleTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SmartBlessingBar")
    if db.locked then
        GameTooltip:AddLine(L.TIP_LOCKED, 1, 0.3, 0.3)
    else
        GameTooltip:AddLine(L.TIP_UNLOCKED, 0.4, 0.8, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.LEFTCLICK, L.MOVE, 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.MIDDLECLICK, L.SETTINGS, 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.RIGHTCLICK, db.locked and L.UNLOCK or L.LOCK, 0, 1, 0, 1, 1, 1)
    GameTooltip:Show()
end
-- The handle's alpha is not protected: applied at once, in combat too
function ns.ApplyAnchor()
    handle:SetAlpha((db.showAnchor or handle.moving or handle:IsMouseOver()) and 1 or 0)
end
handle:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    ShowHandleTooltip(self)
end)
handle:SetScript("OnLeave", function(self)
    if not self.moving then self:SetAlpha(db.showAnchor and 1 or 0) end
    GameTooltip:Hide()
end)

-- The layout the refresh last wrote; nil makes the next refresh lay out and re-anchor
local layoutKey

function ns.LoadPosition()
    layoutKey = nil
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "CENTER", UIParent, db.rel or "CENTER", db.x or 0, db.y or -150)
end

-- The anchor point depends on orientation and growth: the bar grows away from it when
-- buttons are added (right -> left edge, left -> right edge and so on), as in SimpleConjureBar.
function ns.AnchorPoint()
    if db.vertical then return db.growRev and "BOTTOM" or "TOP" end
    return db.growRev and "RIGHT" or "LEFT"
end

-- Re-anchors the bar at its anchor point without moving it on screen, and saves the position
function ns.ReAnchor()
    if InCombatLockdown() then return end
    local l, b, w, h = bar:GetRect()
    if not l then return end
    local point = ns.AnchorPoint()
    local x, y
    if point == "LEFT" then x, y = l, b + h / 2
    elseif point == "RIGHT" then x, y = l + w, b + h / 2
    elseif point == "TOP" then x, y = l + w / 2, b + h
    else x, y = l + w / 2, b end
    bar:ClearAllPoints()
    bar:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
    db.point, db.rel, db.x, db.y = point, "BOTTOMLEFT", x, y
end

-- Scale 0.5 - 2.0, out of combat only. The bar stays at the same screen position: positions
-- are stored in the scaled coordinate system and are converted.
local scalePending = false
function ns.ApplyScale()
    if InCombatLockdown() then scalePending = true return end -- the bar is protected in combat
    scalePending = false
    local new, old = db.scale, bar:GetScale()
    if math.abs(new - old) < 0.001 then return end
    local cx, cy = bar:GetCenter()
    bar:SetScale(new)
    if cx and cy then
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * old / new, cy * old / new)
        ns.ReAnchor()
    end
end

-- Hide in combat: a secure state driver, set or cleared out of combat only
local combatPending = false
function ns.ApplyCombatHide()
    if InCombatLockdown() then combatPending = true return end
    combatPending = false
    if db.hideCombat then
        RegisterStateDriver(bar, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Show()
    end
end

-- Background and border of the bar, the queue buttons' count color and every button's glow,
-- its color and its speed. None of it is protected, so this works in combat too.
function ns.ApplyLook()
    local c, e = db.bg, D.BORDER_COLOR
    bar:SetBackdropColor(c.r, c.g, c.b, c.a)
    bar:SetBackdropBorderColor(e.r, e.g, e.b, db.showBorder and e.a or 0)
    local n = db.countColor
    for _, b in ipairs(ns.queueButtons) do b.count:SetTextColor(n.r, n.g, n.b, n.a) end
    for _, b in ipairs(antsButtons) do
        local a = db[b.antsColorKey]
        b.ants:SetVertexColor(a.r, a.g, a.b, a.a)
        b.antsFlip:SetDuration(D.GLOW_DURATIONS[db[b.antsSpeedKey]])
    end
end

-- Locked = red, unlocked = blue
function ns.ApplyLock()
    local c = db.locked and D.HANDLE_LOCKED or D.HANDLE_UNLOCKED
    handleTex:SetColorTexture(c.r, c.g, c.b, c.a)
end

function ns.ToggleLock()
    db.locked = not db.locked
    ns.ApplyLock()
end

-- The bar holds secure buttons, so it is protected in combat: it cannot move then.
handle:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        if InCombatLockdown() then
            ns.Print(L.NOT_IN_COMBAT)
        elseif not db.locked then
            self.moving = true
            bar:StartMoving()
        end
    elseif button == "RightButton" then
        ns.ToggleLock()
        ShowHandleTooltip(self) -- the tooltip shows the new state
    elseif button == "MiddleButton" then
        ns.ToggleSettings() -- refuses to open in combat itself
    end
end)

-- StopMovingOrSizing must not be called once the lockdown is active.
local function StopDrag()
    if not handle.moving then return end
    handle.moving = false
    if InCombatLockdown() then return end
    bar:StopMovingOrSizing()
    ns.ReAnchor()
    ns.ApplyAnchor()
end
handle:SetScript("OnMouseUp", StopDrag)

---------------------------------------------------------------------------
-- The Symbol count, shown on the blessing button (Queue.lua)
---------------------------------------------------------------------------
-- The Symbol count: white, the warning color at or below the threshold, the empty color at 0
local WHITE = { r = 1, g = 1, b = 1, a = 1 }
local function UpdateSymbols(b, shown)
    if not shown then
        ns.SetText(b.symbols, "")
        return
    end
    local n = ns.Blessings.Symbols()
    local c = WHITE
    if n == 0 then c = db.symbolZeroColor
    elseif db.symbolWarn > 0 and n <= db.symbolWarn then c = db.symbolWarnColor end
    ns.SetText(b.symbols, tostring(n))
    -- A colour the settings change is a new table, so the table tells a change
    if b.symbolsColor ~= c then
        b.symbolsColor = c
        b.symbols:SetTextColor(c.r, c.g, c.b, c.a)
    end
end
ns.UpdateSymbols = UpdateSymbols

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- The buttons refresh with the bar: functions added here run after the layout, out of combat
-- and while auras are readable. They get `combatStart`, true for the refresh right before the
-- lockdown.
ns.onRefresh = {}
-- Functions that write what the settings alone decide - Buff & Run's macro, demo mode's
-- empty clicks, the idle icons, a hidden button's empty click - run on every refresh before
-- the planners, even while auras are secret. They get `combatStart` and whether auras are
-- readable.
ns.onSettings = {}
-- The blessing and Salvation buttons (Queue.lua)
ns.queueButtons = {}

-- Places the shown buttons from the anchor point, sizes the bar, puts the handle on the
-- anchor side.
local function Arrange(shown)
    local point = ns.AnchorPoint()
    for i, b in ipairs(shown) do
        local off = PAD + (i - 1) * (SIZE + GAP)
        b:ClearAllPoints()
        if point == "LEFT" then b:SetPoint("LEFT", bar, "LEFT", off, 0)
        elseif point == "RIGHT" then b:SetPoint("RIGHT", bar, "RIGHT", -off, 0)
        elseif point == "TOP" then b:SetPoint("TOP", bar, "TOP", 0, -off)
        else b:SetPoint("BOTTOM", bar, "BOTTOM", 0, off) end
    end
    local long = math.max(1, #shown) * (SIZE + GAP) - GAP + 2 * PAD
    if db.vertical then bar:SetSize(SIZE + 2 * PAD, long) else bar:SetSize(long, SIZE + 2 * PAD) end

    handle:ClearAllPoints()
    if point == "LEFT" then
        handle:SetSize(10, SIZE); handle:SetPoint("RIGHT", bar, "LEFT", -1, 0)
    elseif point == "RIGHT" then
        handle:SetSize(10, SIZE); handle:SetPoint("LEFT", bar, "RIGHT", 1, 0)
    elseif point == "TOP" then
        handle:SetSize(SIZE, 10); handle:SetPoint("BOTTOM", bar, "TOP", 0, 1)
    else
        handle:SetSize(SIZE, 10); handle:SetPoint("TOP", bar, "BOTTOM", 0, -1)
    end
end

-- The four buttons by order key, each with the setting that shows it; the buff key reads it
-- too (Queue.lua)
local BUTTONS = {
    AURA = { function() return ns.auraButton end, "showAura" },
    FURY = { function() return ns.furyButton end, "showFury" },
    BLESSING = { function() return ns.blessingButton end, "showBlessing" },
    SALVATION = { function() return ns.salvationButton end, "showSalvation" },
}
ns.BAR_BUTTONS = BUTTONS

-- What the layout depends on; layoutKey (above ns.LoadPosition) is the last one laid out
local function LayoutKey()
    local parts = { tostring(db.vertical), tostring(db.growRev), tostring(db.scale) }
    for _, k in ipairs(db.order) do parts[#parts + 1] = k .. "=" .. tostring(db[BUTTONS[k][2]]) end
    return table.concat(parts, ",")
end

-- Reads the group out of combat and writes what changed to the buttons. In combat it does
-- nothing: aura data is unreadable then and the buttons are protected. While the client keeps
-- auras secret out of combat it lays out and writes the settings, and the planners wait.
-- PLAYER_REGEN_ENABLED runs it again, which also applies anything ns.SetAttr skipped.
function ns.Refresh(combatStart)
    -- Not before ns.InitBar placed the bar after a login in combat: re-anchoring the unplaced
    -- bar would save its start position over the player's (ruleset plan
    -- 2026-10-22-combat-login-position)
    if not db or InCombatLockdown() or ns.barPending then return end

    -- The layout only when it changed (ruleset plan 2026-10-20-performance-pvp): the ticker runs
    -- this every second
    local key = LayoutKey()
    if key ~= layoutKey then
        layoutKey = key
        -- The four buttons in the order set on the Order page, each if the settings show it.
        -- A hidden button leaves no gap.
        local shown = {}
        for _, k in ipairs(db.order) do
            local b, showKey = BUTTONS[k][1](), BUTTONS[k][2]
            if db[showKey] then
                b:Show()
                shown[#shown + 1] = b
            else
                b:Hide()
            end
        end
        -- A drag in progress keeps its own anchor; it re-anchors when it ends
        if not handle.moving then ns.ReAnchor() end
        Arrange(shown)
    end
    -- What comes from the settings alone, also while the client keeps auras secret
    local readable = ns.Blessings.AurasReadable()
    for _, fn in ipairs(ns.onSettings) do fn(combatStart, readable) end
    -- The planners read auras: not while the client keeps them secret, then the buttons keep
    -- what they had (third release review: the layout and settings must not wait for it)
    if not readable then return end
    -- The planners see what was cast in combat: the marks of those casts go
    for _, w in ipairs(ns.castWatch) do w.button.cast = nil end
    -- One read of the group for every planner and the overview
    ns.Blessings.WithRead(function()
        for _, fn in ipairs(ns.onRefresh) do fn(combatStart) end
    end)
end

-- Several events arrive together (a raid's UNIT_AURA); they share one refresh.
local scheduled = false
local function Schedule()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.2, function()
        scheduled = false
        ns.Refresh()
    end)
end

---------------------------------------------------------------------------
-- A cast in combat ends its button's glow (ruleset plan 2026-10-25-rank-glow-fixes). Auras are
-- unreadable in combat and the refresh waits for its end; the cast event says what was cast.
-- Count, secure action and buff key stay: nothing secure changes in combat.
---------------------------------------------------------------------------
ns.castWatch = {} -- { button, matches(spellId) }
local inCombat = false -- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED runs

-- A button whose glow a cast of `matches` ends; its left clicks are remembered for a cast
-- whose spell ID the client keeps secret
function ns.WatchCast(b, matches)
    ns.castWatch[#ns.castWatch + 1] = { button = b, matches = matches }
    b:HookScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then b.pressedAt = GetTime() end
    end)
end

local function MarkCast(b)
    b.cast = true
    ns.SetAnts(b, false)
end

local casts = CreateFrame("Frame")
casts:RegisterEvent("PLAYER_REGEN_DISABLED")
casts:RegisterEvent("PLAYER_REGEN_ENABLED")
casts:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
casts:SetScript("OnEvent", function(_, event, unit, _, spellId)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        return
    end
    if unit ~= "player" or not inCombat then return end
    if issecretvalue(spellId) then
        -- The button left-clicked last, within the window - a press early in a fight must not
        -- match a cast much later
        local latest
        for _, w in ipairs(ns.castWatch) do
            local at = w.button.pressedAt
            if at and GetTime() - at <= D.CAST_PRESS_WINDOW and (not latest or at > latest.button.pressedAt) then
                latest = w
            end
        end
        if latest then MarkCast(latest.button) end
        return
    end
    for _, w in ipairs(ns.castWatch) do
        if w.matches(spellId) then MarkCast(w.button) end
    end
end)

local events = CreateFrame("Frame")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_AURA", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
-- The unit tokens of group members. A member's aura change fires for his group token too, so
-- the many from nameplates, the target and pets change nothing the buttons show.
local function GroupUnit(unit)
    return unit == "player" or unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil
end

events:SetScript("OnEvent", function(_, event, unit)
    if not db then return end
    if event == "UNIT_AURA" and not GroupUnit(unit) then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Fires right before the lockdown: the last moment to stop a drag and to write
        -- the freshest state.
        StopDrag()
        ns.Refresh(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Counts were frozen in combat and changes may wait: always refresh at its end
        if ns.barPending then
            ns.InitBar()
        else
            if scalePending then ns.ApplyScale() end
            if combatPending then ns.ApplyCombatHide() end
            ns.Refresh()
        end
    else
        Schedule()
    end
end)

-- Range changes fire no event; a ticker keeps targets current out of combat.
local ticker

-- At login. The bar is protected once it holds secure buttons, so after a /reload in
-- combat its position waits for the end of combat.
function ns.InitBar()
    ns.ApplyAnchor()
    if InCombatLockdown() then
        ns.barPending = true
        return
    end
    ns.barPending = false
    bar:SetScale(db.scale) -- before positioning: the position is stored in the scaled system
    ns.LoadPosition()
    ns.ApplyLock()
    ns.ApplyCombatHide()
    ns.ApplyLook()
    -- The ticker before the first refresh, so an error in it does not stop the updates
    if not ticker then
        ticker = C_Timer.NewTicker(1, function()
            if not InCombatLockdown() then ns.Refresh() end
        end)
    end
    ns.Refresh()
end
