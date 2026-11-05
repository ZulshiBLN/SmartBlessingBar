-- SmartBlessingBar - demo mode's chat output
-- In demo mode the main buttons carry no secure action; a left click says what it would cast
-- (ruleset plan 2026-10-18-settings-window; moved from Flyout.lua by plan
-- 2026-10-19-priorities). Loaded after Queue.lua, once all four buttons exist.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D
local db
ns.OnDBReady(function(d) db = d end)

-- Spell ID -> its name key, and whether it is a Greater Blessing (the keys name the normal form)
local NAME_KEYS = {
    [D.RIGHTEOUS_FURY] = { key = "RIGHTEOUS_FURY" },
    [D.SALVATION] = { key = "SALVATION" },
    [D.MASS_SALVATION] = { key = "MASS_SALVATION" },
    [D.REVOKE] = { key = "REVOKE" },
}
for family, f in pairs(D.BLESSINGS) do
    for _, id in ipairs(f.normal) do NAME_KEYS[id] = { key = "BLESSING_" .. family } end
    for _, id in ipairs(f.greater) do NAME_KEYS[id] = { key = "BLESSING_" .. family, greater = true } end
end
for family, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do NAME_KEYS[id] = { key = "AURA_" .. family } end
end

-- Says in the chat what a click would cast
function ns.DemoCast(spell)
    local n = NAME_KEYS[spell]
    local client = C_Spell.GetSpellName(spell)
    local name = ns.LocalName(client, n.key)
    if n.greater and name ~= client then name = ns.L.DEMO_GREATER:format(name) end
    ns.DemoPrint(ns.L.DEMO_CAST, name)
end

local function DemoClick(b, mouseButton, down)
    if down or mouseButton ~= "LeftButton" or not ns.IsDemo() then return end
    local spell = b:GetAttribute("spell1")
    if spell then ns.DemoCast(spell) end
end

for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }) do
    b:HookScript("OnClick", DemoClick)
end

---------------------------------------------------------------------------
-- The demo raid (ruleset plan 2026-10-19-demo-raid): 40 made-up members for the overview,
-- made once per session. A member has no unit; the overview reads his name and the givers
-- from here.
---------------------------------------------------------------------------
local B = ns.Blessings
local SYLLABLES = { "ar", "bel", "cor", "dra", "el", "fen", "gor", "hal", "is", "jor", "ka", "lor", "mir",
                    "nor", "ol", "pyr", "quel", "ras", "sil", "tor", "ul", "val", "wyn", "xan", "yr", "zul" }
-- Wide letters only, for the name at the field's edge: twelve narrow ones fit the field whole
-- (Michel's look in game)
local WIDE_SYLLABLES = { "maw", "wan", "dom", "mag", "wom", "dum", "mow", "gan" }
local WISDOM_CLASSES = { PALADIN = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }
local DAMAGE_ROLES = D.DAMAGE_ROLES
local DPS_CLASSES = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local RAID_SIZE, HOLDERS = 40, 3

local function Pick(list) return list[math.random(#list)] end

local function Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- A made-up first name of `length` letters from `syllables`, a capital first, not in `taken`
local function MakeName(length, taken, syllables)
    local name
    repeat
        local s = ""
        while #s < length do s = s .. Pick(syllables or SYLLABLES) end
        name = s:sub(1, 1):upper() .. s:sub(2, length)
    until not taken[name]
    taken[name] = true
    return name
end

local function DamageRole(class)
    for _, role in ipairs(D.CLASS_ROLES[class]) do
        if DAMAGE_ROLES[role] then return role end
    end
end

local function Last(list) return list[#list] end

-- The raid: `members`, each { name, class, role, aura, greyed, lacking, edge, left = family ->
-- minutes }; `paladins`, the player first, the others with the family each `gives`; `size`
-- and `tanks` per class
local function MakeRaid()
    local members = {}
    local function Add(class, role) members[#members + 1] = { class = class, role = role } end
    for _, class in ipairs({ "WARRIOR", "WARRIOR", "WARRIOR", "DRUID" }) do Add(class, "TANK") end
    for _, class in ipairs({ "PALADIN", "PALADIN", "PALADIN", "PALADIN", "PRIEST", "PRIEST", "PRIEST",
                             "SHAMAN", "SHAMAN", "DRUID" }) do Add(class, "HEALER") end
    for _, class in ipairs({ "HUNTER", "ROGUE", "MAGE", "WARLOCK" }) do Add(class, DamageRole(class)) end
    while #members < RAID_SIZE do
        local class = Pick(DPS_CLASSES)
        Add(class, DamageRole(class))
    end
    Shuffle(members)

    -- Names: the player's own; two damage dealers at the name field's edge, sharing a 12-letter
    -- name - one shows it whole, cut where the field is narrower, the other the longest part
    -- that fits (the overview fits it); one of 2 letters; the rest 3 to 12
    local taken, paladins, two, edges = {}, {}, false, 0
    local edge = MakeName(12, taken, WIDE_SYLLABLES)
    for _, m in ipairs(members) do
        if m.class == "PALADIN" then paladins[#paladins + 1] = m end
        if DAMAGE_ROLES[m.role] and edges < 2 then
            edges = edges + 1
            m.name, m.edge = edge, edges == 1 and "cut" or "fit"
        end
    end
    local me = paladins[1]
    me.name, me.isPlayer = (UnitName("player")), true
    for _, m in ipairs(members) do
        if not m.name then
            m.name = MakeName(two and math.random(3, 12) or 2, taken)
            two = true
        end
    end

    -- Auras: mine the chosen one, the other Paladins the first three besides it
    local mine = B.ChooseAura()
    me.aura = mine
    local others = {}
    for _, family in ipairs(D.AURA_ORDER) do
        if family ~= mine and #others < #paladins - 1 then others[#others + 1] = family end
    end
    for i = 2, #paladins do paladins[i].aura = others[i - 1] end

    -- Blessings, given at each build (ns.DemoRaid): the others Kings, Might or Wisdom, Light;
    -- the minutes each has left, per family
    paladins[2].gives, paladins[3].gives, paladins[4].gives = "KINGS", "MIGHT", "LIGHT"
    local size, tanks = {}, {}
    for _, m in ipairs(members) do
        m.left = {}
        for _, family in ipairs(D.BLESSING_ORDER) do m.left[family] = math.random(15) end
        m.left.SALVATION = math.random(15)
        size[m.class] = (size[m.class] or 0) + 1
        if m.role == "TANK" then tanks[m.class] = (tanks[m.class] or 0) + 1 end
    end

    -- States: three dimmed, three other non-tanks without Salvation; the player in neither
    local candidates = {}
    for _, m in ipairs(members) do
        if not m.isPlayer then candidates[#candidates + 1] = m end
    end
    Shuffle(candidates)
    local lacking = 0
    for i, m in ipairs(candidates) do
        if i <= HOLDERS then
            m.greyed = true
        elseif m.role ~= "TANK" and lacking < HOLDERS then
            m.lacking = true
            lacking = lacking + 1
        end
    end
    return { members = members, paladins = paladins, size = size, tanks = tanks }
end

local raid

-- The rank the planner would give a class of `n`: the Greater form from D.RAID_GREATER_MIN
-- on, else the best normal one
local function RankFor(family, n)
    local f = D.BLESSINGS[family]
    return n >= D.RAID_GREATER_MIN and Last(f.greater) or Last(f.normal)
end

-- What a member carries now: from me the first family of his class's list - read at each
-- build, so a changed list shows at once - and Salvation, Mass Salvation where the planner
-- would cast it; from the others the rest. Expiry times from now, so a tooltip never shows a
-- negative time.
local function Carried(m, now)
    local me, carried = raid.paladins[1], {}
    local n, tanks = raid.size[m.class], raid.tanks[m.class] or 0
    local function Give(family, spell, by, mine)
        carried[family] = { spell = spell, by = by, mine = mine, expires = now + m.left[family] * 60 }
    end
    -- A family the client has not is passed (ruleset plan 2026-11-05-removed-spells)
    local function FirstFree()
        for _, family in ipairs(db.classLists[m.class].order) do
            if B.FamilyExists(family) and not carried[family] then return family end
        end
    end
    local first = FirstFree()
    if first then Give(first, RankFor(first, n), me.name, true) end
    for i = 2, #raid.paladins do
        local family = raid.paladins[i].gives
        if family == "MIGHT" and WISDOM_CLASSES[m.class] then family = "WISDOM" end
        -- Without Light the fourth gives what the class's list holds and nobody gave, if any
        if family == "LIGHT" and not B.FamilyExists("LIGHT") then family = FirstFree() end
        if family and family ~= first then Give(family, RankFor(family, n), raid.paladins[i].name) end
    end
    if m.role ~= "TANK" and not m.lacking and B.Exists(D.SALVATION) then
        local mass = n - tanks >= D.RAID_GREATER_MIN + tanks
        Give("SALVATION", mass and D.MASS_SALVATION or D.SALVATION, me.name, true)
    end
    return carried
end

-- The raid as the overview reads B.Describe's members
function ns.DemoRaid()
    raid = raid or MakeRaid()
    local now, list = GetTime(), {}
    for _, m in ipairs(raid.members) do
        local d = { name = m.name, class = m.class, role = m.role, greyed = m.greyed, edge = m.edge,
                    carried = Carried(m, now) }
        if m.aura then d.aura = { spell = Last(D.AURAS[m.aura]), by = m.name, expires = 0 } end
        if m.lacking and B.Exists(D.SALVATION) then d.next = { family = "SALVATION", spell = D.SALVATION } end
        list[#list + 1] = d
    end
    return list
end
