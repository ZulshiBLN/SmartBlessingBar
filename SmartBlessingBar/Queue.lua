-- SmartBlessingBar - the blessing and Salvation buttons
-- Each casts the head of its queue, which the planner (Blessings.lua) builds out of combat
-- from what the group carries (ruleset plan 2026-10-19-blessing-core). In combat the head
-- stays as the last refresh before it wrote it: aura data is unreadable then, and the secure
-- code cannot tell a cast that landed from one that failed.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr
local db
ns.OnDBReady(function(d) db = d end)

local function SalvationName()
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION")
end

-- Whom the head reaches: the class for a Greater Blessing or Mass Salvation, which reach all
-- of it, else the member (ruleset plan 2026-10-20-button-tips-glow). The planner names the
-- class: in combat the member may have left the group.
local function Target(head)
    if head.greater then
        return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[head.class], "CLASS_" .. head.class)
    end
    return (UnitName(head.unit))
end

-- The queue's head as the game's tooltip, with what a left click reaches; an empty queue says
-- so. The blessing button names its right click too.
local function ShowTooltip(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local head = b.head
    if head then
        GameTooltip:SetSpellByID(head.spell)
        GameTooltip:AddDoubleLine(L.LEFTCLICK, Target(head), 1, 1, 1)
    else
        GameTooltip:SetText(b.title())
        -- Nothing to cast now: every entry held at combat start, or everyone in need out of range
        local why = L.QUEUE_EMPTY
        if b.left > 0 then why = L.QUEUE_HELD elseif (b.queue and b.queue.far or 0) > 0 then why = L.QUEUE_OUT_OF_RANGE end
        GameTooltip:AddLine(why, 1, 1, 1)
    end
    local middle = b.middleClickText and b.middleClickText()
    if middle then GameTooltip:AddDoubleLine(L.MIDDLECLICK, middle, 1, 1, 1) end
    if b.rightClickText then GameTooltip:AddDoubleLine(L.RIGHTCLICK, b.rightClickText(), 1, 1, 1) end
    GameTooltip:Show()
end

local function NewQueueButton(name, colorKey, speedKey, idleSpell, title)
    local b = ns.CreateSecureButton(name, ns.bar)
    -- Nothing left until the first plan, which waits for the end of combat after a /reload and
    -- for readable auras
    b.idleSpell, b.title, b.left = idleSpell, title, 0
    ns.AttachAnts(b, colorKey, speedKey)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    table.insert(ns.queueButtons, b)
    return b
end

local blessing = NewQueueButton("SmartBlessingBarBlessing", "blessingAntsColor",
    "blessingAntsSpeed", D.BLESSINGS.KINGS.normal[1], function() return L.BTN_BLESSINGS end)
local salvation = NewQueueButton("SmartBlessingBarSalvation", "salvationAntsColor",
    "salvationAntsSpeed", D.SALVATION, SalvationName)
ns.blessingButton, ns.salvationButton = blessing, salvation

-- A cast of the head in combat ends that button's glow (Bar.lua)
for _, b in ipairs({ blessing, salvation }) do
    ns.WatchCast(b, function(id) return b.head ~= nil and b.head.spell == id end)
end

-- Buff & Run (ruleset plan 2026-10-20-buff-and-run): the blessing button's middle click casts
-- on the current target what B.BuffRunSpell chose for him, then targets the next friendly
-- player - one macro, as the client lets an addon pick neither spell nor target during a
-- click. The cast goes through a hidden button holding the spell's ID, so the rank fits in
-- every language; "LeftButton 1" clicks it on key down, which works with
-- ActionButtonUseKeyDown on and off.
local buffRun = CreateFrame("Button", "SmartBlessingBarBuffRun", UIParent, "SecureActionButtonTemplate")
buffRun:RegisterForClicks("AnyUp", "AnyDown")
local BUFF_RUN_MACRO = "/click SmartBlessingBarBuffRun LeftButton 1\n/targetfriendplayer"

-- The middle click's attributes as every refresh leaves them, also at combat start: the
-- macro while the switch is on (General tab), and no spell, so in combat a middle click only
-- moves on. The hidden button's action is written here too, not at load: after a /reload in
-- combat the files load in the lockdown, where SetAttr writes nothing.
local function ArmBuffRun()
    local on = db.buffRun
    SetAttr(blessing, "type3", on and "macro" or nil)
    SetAttr(blessing, "macrotext3", on and BUFF_RUN_MACRO or nil)
    SetAttr(buffRun, "type", "spell")
    SetAttr(buffRun, "unit", "target")
    SetAttr(buffRun, "spell", nil)
end

-- Just before a middle click, out of combat: the spell for the current target. During the
-- global cooldown the click does nothing at all, so no player is passed by. Demo mode casts
-- nothing and says once, on the press, what it would cast.
blessing:SetScript("PreClick", function(_, mouseButton, down)
    -- In combat ns.SetAttr writes nothing anyway; the test spares the read (defence in depth
    -- at the secure boundary, code review 1.1.0 F-09)
    if mouseButton ~= "MiddleButton" or InCombatLockdown() or not db.buffRun then return end
    -- No spell from an earlier click, should the choice below fail
    SetAttr(buffRun, "spell", nil)
    local spell = B.WithRead(function() return B.BuffRunSpell("target") end)
    -- The client may answer no cooldown at all, as for a rank demo mode counts as known
    local cd = spell and C_Spell.GetSpellCooldown(spell)
    if cd and cd.startTime > 0 then
        SetAttr(blessing, "type3", nil)
        return
    end
    SetAttr(blessing, "type3", "macro")
    if ns.IsDemo() then
        if spell and down then ns.DemoCast(spell) end
        spell = nil
    end
    SetAttr(buffRun, "spell", spell)
end)

-- A right click on the blessing button opens the lists that steer it, on its release; it
-- casts nothing, as no type2 is set. Not in combat, as the minimap button's middle click.
blessing.rightClickText = function() return L.SET_PRIORITIES end
blessing.middleClickText = function() return db.buffRun and L.BUFF_RUN end
blessing:HookScript("OnClick", function(_, mouseButton, down)
    if mouseButton ~= "RightButton" or down then return end
    if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
    ns.OpenSettingsOn("TAB_PRIORITIES")
end)

-- The blessing button shows the Symbols of Kings in its centre
blessing.symbols = blessing:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
blessing.symbols:SetPoint("CENTER", 0, 0)

-- The head: the first entry, but at combat start never one held back (planner `hold`)
local function Head(queue, combatStart)
    for _, entry in ipairs(queue) do
        if not (combatStart and entry.hold) then return entry end
    end
end

-- Writes a queue to its button, out of combat (the refresh runs only there). Left click
-- only; in demo mode no secure action, the click prints instead (Demo.lua).
local function Show(b, queue, combatStart)
    local head = Head(queue, combatStart)
    b.queue, b.head, b.left = queue, head, #queue
    SetAttr(b, "type1", (head and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", head and head.spell)
    SetAttr(b, "unit1", head and head.unit)
    ns.SetIcon(b, C_Spell.GetSpellTexture(head and head.spell or b.idleSpell), not head)
    ns.SetText(b.count, #queue > 0 and tostring(#queue) or "")
    -- No ants while nothing can be cast, also with held entries left (ruleset plan
    -- 2026-10-19-blessing-steering)
    ns.SetAnts(b, head ~= nil)
end

-- The Symbol count on the blessing button, shown once a Greater form is known
function ns.RefreshSymbols()
    ns.UpdateSymbols(blessing, B.AnyGreaterKnown())
end

---------------------------------------------------------------------------
-- The buff key (ruleset plan 2026-10-20-key-bindings): a hidden button a key binding clicks.
-- It carries the left-click action of the first switched-on, glowing button in the bar's
-- order - the blessing button's being the group's next blessing, the Salvation button's its
-- Salvation, Mass Salvation or Revoke (Michel). Written with the bar, so it too keeps its
-- action in combat.
---------------------------------------------------------------------------
local buffKey = CreateFrame("Button", "SmartBlessingBarBuffAll", UIParent, "SecureActionButtonTemplate")
buffKey:RegisterForClicks("AnyUp", "AnyDown")
ns.buffKey = buffKey
-- The left-click action it copies; made once, as it is read every refresh
local ACTION = { "type1", "spell1", "unit1" }

local function ArmBuffKey()
    local source
    for _, key in ipairs(db.order) do
        local entry = ns.BAR_BUTTONS[key]
        local b = entry[1]()
        -- A hidden button's queue is empty already; asking its setting too keeps the key from
        -- arming a button the player switched off, whatever its ants say (F-09)
        if db[entry[2]] and b.antsShown then
            source = b
            break
        end
    end
    for _, attr in ipairs(ACTION) do
        SetAttr(buffKey, attr, source and source:GetAttribute(attr) or nil)
    end
    -- Out of combat only, as the attributes: in combat the key keeps the action it had
    if not InCombatLockdown() then buffKey.source = source end
end

-- A press of the key counts as a left click on the button whose action it carries, for a cast
-- in combat whose spell ID the client keeps secret (Bar.lua)
buffKey:HookScript("OnClick", function(self, mouseButton)
    if mouseButton == "LeftButton" and self.source then self.source.pressedAt = GetTime() end
end)

-- Demo mode casts nothing; a press says once, on the release, what it would cast
buffKey:HookScript("OnClick", function(self, _, down)
    if down or not ns.IsDemo() then return end
    local spell = self:GetAttribute("spell1")
    if spell then ns.DemoCast(spell) end
end)

-- From the settings alone, also while auras are secret: Buff & Run's macro, no click action in
-- demo mode - the buff key's too - and an icon before the first plan. The lists are made
-- once, as this runs every refresh.
local CLICK_BUTTONS, ICON_BUTTONS = { blessing, salvation, buffKey }, { blessing, salvation }
table.insert(ns.onSettings, function(combatStart, readable)
    ArmBuffRun()
    -- While auras are secret the planners wait: the last queues stay, but a hidden button
    -- empties its own, and the combat start still skips held entries (final release review)
    if not readable then
        Show(blessing, db.showBlessing and blessing.queue or {}, combatStart)
        Show(salvation, db.showSalvation and salvation.queue or {}, combatStart)
        ArmBuffKey()
    end
    if ns.IsDemo() then
        for _, b in ipairs(CLICK_BUTTONS) do SetAttr(b, "type1", nil) end
    end
    for _, b in ipairs(ICON_BUTTONS) do
        if not b.iconTexture then ns.SetIcon(b, C_Spell.GetSpellTexture(b.idleSpell), true) end
    end
end)

-- A hidden button plans nothing: its empty queue also leaves nothing a /click could cast.
-- After the aura and Fury buttons (SelfBuffs.lua loads first), so the buff key sees all four.
table.insert(ns.onRefresh, function(combatStart)
    local queue, symbolsUsed = {}, 0
    if db.showBlessing then queue, symbolsUsed = B.PlanBlessings() end
    Show(blessing, queue, combatStart)
    ns.RefreshSymbols()
    Show(salvation, db.showSalvation and B.PlanSalvation(symbolsUsed) or {}, combatStart)
    ArmBuffKey()
end)
