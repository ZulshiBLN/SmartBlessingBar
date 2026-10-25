-- SmartBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the highest known rank of the aura
-- its list picks: the first one no other paladin runs (ruleset plan 2026-10-19-priorities).
-- Both buttons glow while what they cast is missing, Righteous Fury also while it is about to
-- run out (ruleset plan 2026-10-20-fury-renew) - known out of combat only, so they freeze in
-- combat like the counts.

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr

local db
ns.OnDBReady(function(d) db = d end)

-- Placed by the bar's layout (Bar.lua), which puts these two first
local function NewButton(name, colorKey, speedKey)
    local b = ns.CreateSecureButton(name, ns.bar)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    ns.AttachAnts(b, colorKey, speedKey)
    return b
end

-- Left click only. No secure action in demo mode.
local function SetSpell(b, spell)
    SetAttr(b, "type1", (spell and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and "player" or nil)
end

local aura = NewButton("SmartBlessingBarAura", "auraAntsColor", "auraAntsSpeed")
local fury = NewButton("SmartBlessingBarFury", "furyAntsColor", "furyAntsSpeed")
ns.auraButton, ns.furyButton = aura, fury

-- A cast of the chosen aura family, or of Righteous Fury, in combat ends that glow (Bar.lua)
ns.WatchCast(aura, function(id) return aura.family ~= nil and B.AURA_FAMILY[id] == aura.family end)
ns.WatchCast(fury, function(id) return id == D.RIGHTEOUS_FURY end)

-- Whether the paladin's own aura of this family is on him; another paladin's does not count
-- Read in demo mode too: the glow follows the real aura there
local function OwnAuraUp(family)
    for _, a in ipairs(B.Auras("player", true)) do
        if a.mine and B.AURA_FAMILY[a.id] == family then return true end
    end
    return false
end

-- Whether Righteous Fury holds: on the paladin with more than its own renewal time left
-- (ruleset plan 2026-10-20-fury-renew). It is self-only, so any Fury on him is his.
local function FuryHolds()
    for _, a in ipairs(B.Auras("player", true)) do
        if a.id == D.RIGHTEOUS_FURY then return not B.Expiring(a, db.furyRenewMinutes) end
    end
    return false
end

local function Update()
    -- None known: the first family on the list, rank 1, greyed and without ants. Hidden, the
    -- button chooses nothing and leaves nothing a /click could cast.
    local family = db.showAura and B.ChooseAura() or nil
    aura.family = family
    local spell = family and B.Best(D.AURAS[family])
    aura.shownSpell = spell or D.AURAS[db.auraList[1]][1]
    SetSpell(aura, spell)
    ns.SetIcon(aura, C_Spell.GetSpellTexture(aura.shownSpell), not spell)
    ns.SetAnts(aura, family ~= nil and not OwnAuraUp(family))

    -- Righteous Fury matters to a tank only: the role the game reports - a group's role
    -- check sets it; alone the game reports none (Michel, 2026-10-19). Demo mode reads no role.
    -- Hidden, it casts nothing and does not glow, as the aura button
    local known = db.showFury and B.Known(D.RIGHTEOUS_FURY)
    local tank = not ns.IsDemo() and UnitGroupRolesAssigned("player") == "TANK"
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    ns.SetIcon(fury, C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY), not (known and tank))
    ns.SetAnts(fury, known and tank and not FuryHolds())
end
table.insert(ns.onRefresh, Update)

-- From the settings alone, also while auras are secret: the icons before the first plan (the
-- Priorities tab shows the aura button's spell), nothing on a hidden button - a /click or the
-- buff key could cast it - and no click action in demo mode
table.insert(ns.onSettings, function()
    if not db.showAura then SetSpell(aura, nil) ns.SetAnts(aura, false) end
    if not db.showFury then SetSpell(fury, nil) ns.SetAnts(fury, false) end
    if not aura.shownSpell then
        aura.shownSpell = D.AURAS[db.auraList[1]][1]
        ns.SetIcon(aura, C_Spell.GetSpellTexture(aura.shownSpell), true)
    end
    if not fury.iconTexture then ns.SetIcon(fury, C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY), true) end
    if ns.IsDemo() then
        SetAttr(aura, "type1", nil)
        SetAttr(fury, "type1", nil)
    end
end)
