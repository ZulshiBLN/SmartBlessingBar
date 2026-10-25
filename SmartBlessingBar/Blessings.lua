-- SmartBlessingBar - blessing logic
-- Which rank to cast, roles, what others gave, and the planner behind the blessing and
-- Salvation buttons (ruleset plan 2026-10-19-blessing-core).
-- Runs only while B.AurasReadable(): in combat, and in instances and PvP often out of it too,
-- the client refuses aura reads (code.md), so the callers freeze its results there.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D
local db
ns.OnDBReady(function(d) db = d end)

local B = {}
ns.Blessings = B

-- Whether the client lets the addon read auras now. Not in combat; and since Midnight, in
-- instances and PvP it keeps them secret out of combat too and refuses a read with an error
-- (BugSack, 2026-10-20). Where C_Secrets is missing, one read is tried.
function B.AurasReadable()
    if InCombatLockdown() then return false end
    local secret = C_Secrets and C_Secrets.ShouldAurasBeSecret
    if secret then return not secret() end
    return (pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL"))
end

-- An aura's spell ID, or nil while the game keeps any field the addon reads secret: such a
-- buff counts as unread (code.md). Every reader asks this before using the others.
function B.SpellOf(aura)
    if issecretvalue(aura.spellId) or issecretvalue(aura.expirationTime)
       or issecretvalue(aura.auraInstanceID) or issecretvalue(aura.sourceUnit) then
        return
    end
    return aura.spellId
end

---------------------------------------------------------------------------
-- One read of the group (ruleset plan 2026-10-20-performance-pvp): between B.BeginRead and
-- B.EndRead - a refresh, a Buff & Run click, an overview build - each person's buffs are
-- scanned once and each spell's "known" and each member's level asked once. Outside a read
-- every call asks the client fresh.
---------------------------------------------------------------------------
local read -- { auras = key -> list, known = id -> bool, level = unit -> level } during a read

-- A group member's buffs kept beyond the read (ruleset plan 2026-10-24-kept-snapshots): GUID ->
-- { list, at }, used while younger than D.SNAPSHOT_MAX_AGE and dropped on his UNIT_AURA, a
-- roster change or a loading screen. Members only: the client reports UNIT_AURA for a unit
-- that has a token, and a stranger Buff & Run just blessed has lost `target` before his buff
-- lands. A kept list is read-only.
local kept = {}

function B.BeginRead()
    read = { auras = {}, known = {}, level = {} }
    local now = GetTime()
    for guid, k in pairs(kept) do
        if now - k.at >= D.SNAPSHOT_MAX_AGE then kept[guid] = nil end
    end
end
function B.EndRead() read = nil end

-- The error with the stack where it happened, for BugSack, as a rethrow would lose it
local function WithStack(err)
    return tostring(err) .. "\n" .. debugstack(2)
end

-- fn inside a read: the running one, or one of its own, closed also when fn errors - a
-- read left open would serve its old snapshot to the next click. The error goes on.
function B.WithRead(fn)
    if read then return fn() end
    B.BeginRead()
    local ok, result = xpcall(fn, WithStack)
    B.EndRead()
    if not ok then error(result, 0) end
    return result
end

-- A person's key: his GUID, so `player`, `raidN` and `target` share one snapshot; a GUID the
-- client withholds or keeps secret falls back to the token
local function PersonKey(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or guid == nil then return unit end
    return guid
end

-- A unit's readable buffs, { id, expires, mine, source } each, in the client's order
local function Scan(unit)
    local mineIds, list = {}, {}
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then break end
        if B.SpellOf(aura) then mineIds[aura.auraInstanceID] = true end
        i = i + 1
    end
    i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local id = B.SpellOf(aura)
        if id then
            list[#list + 1] = { id = id, expires = aura.expirationTime,
                                mine = mineIds[aura.auraInstanceID] == true, source = aura.sourceUnit }
        end
        i = i + 1
    end
    return list
end

local NONE = {}

-- A token that names a group member: the client keeps reporting his UNIT_AURA under it
local function GroupToken(unit)
    return unit == "player" or unit:find("^party%d$") ~= nil or unit:find("^raid%d%d?$") ~= nil
end

-- How many members' buffs are kept, for the bug report's state
function B.KeptCount()
    local n = 0
    for _ in pairs(kept) do n = n + 1 end
    return n
end

-- The buffs a unit carries. Demo mode reads none; `real` reads them there too - the aura
-- button's own aura - kept apart from demo mode's empty answer.
function B.Auras(unit, real)
    local demo = ns.IsDemo()
    if demo and not real then return NONE end
    if not read then return Scan(unit) end
    local key = PersonKey(unit)
    local list = read.auras[key]
    if list then return list end
    -- A key that is the token itself has no GUID behind it: never kept. B.BeginRead already
    -- drops lists past D.SNAPSHOT_MAX_AGE; the age test keeps the rule here on its own (F-09).
    local k = key ~= unit and kept[key]
    if k and GetTime() - k.at < D.SNAPSHOT_MAX_AGE then
        list = k.list
    else
        list = Scan(unit)
        if key ~= unit and GroupToken(unit) then kept[key] = { list = list, at = GetTime() } end
    end
    read.auras[key] = list
    return list
end

local keptEvents = CreateFrame("Frame")
keptEvents:RegisterEvent("UNIT_AURA")
keptEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
keptEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
keptEvents:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        -- Lists are kept under group tokens only, and a member's group token always fires;
        -- nameplates and the like fire far more often and need no GUID
        if not (unit and GroupToken(unit)) then return end
        local guid = UnitGUID(unit)
        if not issecretvalue(guid) and guid then kept[guid] = nil end
    else
        kept = {}
    end
end)

-- The one test of a known spell; in demo mode every spell counts as known
function B.Known(id)
    if ns.IsDemo() then return true end
    if not read then return IsPlayerSpell(id) end
    local known = read.known[id]
    if known == nil then
        known = IsPlayerSpell(id)
        read.known[id] = known
    end
    return known
end

-- Whether any Greater Blessing or Mass Salvation is known - only then is a Symbol of Kings
-- of use
function B.AnyGreaterKnown()
    for _, family in ipairs(D.BLESSING_ORDER) do
        if B.Best(D.BLESSINGS[family].greater) then return true end
    end
    return B.Known(D.MASS_SALVATION)
end

-- The group's unit tokens: alone the player, in a party the player and party1-4, in a raid
-- raid1-40. Pets are not members.
function B.Members()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
        end
    end
    return units
end

function B.Eligible(unit)
    return UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)
end

-- The client gives no answer for a rank the player has not learned, which demo mode counts as
-- known: there it counts as in range, so demo mode names what it would cast
function B.InRange(spell, unit)
    if UnitIsUnit(unit, "player") then return true end
    local answer = C_Spell.IsSpellInRange(spell, unit)
    if answer == nil and ns.IsDemo() then return true end
    return answer == true
end

-- The level a spell is learned at, a constant of the spell, kept for the session. Only a
-- positive answer is kept: nil means the client has not loaded it yet (code.md).
local learnedAt = {}
local function Learned(spell)
    local learned = learnedAt[spell]
    if not learned then
        learned = C_Spell.GetSpellLevelLearned(spell)
        if learned and learned > 0 then learnedAt[spell] = learned end
    end
    return learned
end

local function LevelOf(unit)
    if not read then return UnitLevel(unit) end
    local level = read.level[unit]
    if level == nil then
        level = UnitLevel(unit) or false
        read.level[unit] = level
    end
    return level or nil
end

-- Whether the game lets a spell land on a unit's level. A level the game does not give sets
-- no limit; demo mode sets none either.
function B.Fits(spell, unit)
    if ns.IsDemo() then return true end
    local learned, level = Learned(spell), LevelOf(unit)
    if not learned or learned <= 0 or not level or level <= 0 then return true end
    return level >= learned - D.LEVEL_GAP
end

-- The best known entry of a list ordered by rank - IDs do not rise with rank (Data.lua) - and
-- its index, or nil. With a unit only ranks that fit him count.
function B.Best(list, unit)
    local best, index
    for i, id in ipairs(list) do
        if B.Known(id) and (not unit or B.Fits(id, unit)) then best, index = id, i end
    end
    return best, index
end

---------------------------------------------------------------------------
-- Roles and presence (ruleset plan 2026-10-19-blessing-core)
---------------------------------------------------------------------------

-- A member's role: the one the game reports, where the class can play it - a damage dealer
-- gets the class's first damage role - else the class default. Nothing sets a role by hand
-- (Michel, 2026-10-19). Demo mode puts every class on the player, so it reads no role: each
-- class shows its default.
function B.RoleOf(unit, class)
    local roles = D.CLASS_ROLES[class or select(2, UnitClass(unit))]
    if not roles then return end
    if ns.IsDemo() then return roles[1] end
    local reported = UnitGroupRolesAssigned(unit)
    for _, role in ipairs(roles) do
        if role == reported or (reported == "DAMAGER" and D.DAMAGE_ROLES[role]) then return role end
    end
    return roles[1]
end

-- Spell ID -> { family, strength, greater }: a normal rank's strength is its index in the
-- normal list, a Greater rank's the normal index it equals (D.GREATER_EQUALS)
local RANKS = {}
for family, f in pairs(D.BLESSINGS) do
    for i, id in ipairs(f.normal) do RANKS[id] = { family = family, strength = i } end
    for i, id in ipairs(f.greater) do
        local equals = D.GREATER_EQUALS[family]
        RANKS[id] = { family = family, strength = equals and equals[i], greater = true }
    end
end
B.RANKS = RANKS

-- Whether another paladin gave the unit this family: in its Greater form, or a normal rank
-- at least the best one of this paladin's that fits the unit. A lower rank counts as missing
-- - casting it again is worth it (Michel, 2026-10-19). Read out of combat only.
function B.GivenByOthers(unit, family)
    local best = select(2, B.Best(D.BLESSINGS[family].normal, unit)) or 0
    for _, a in ipairs(B.Auras(unit)) do
        local rank = RANKS[a.id]
        if rank and rank.family == family and not a.mine and (rank.greater or rank.strength >= best) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- The planner (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Definitions")
-- Out of combat it decides, from what the group carries, what this paladin casts next.
---------------------------------------------------------------------------
-- Blessings are the families of D.BLESSING_ORDER; Salvation never counts as one
local IS_BLESSING = {}
for _, family in ipairs(D.BLESSING_ORDER) do IS_BLESSING[family] = true end

-- Whether a buff runs out within `minutes`, so it is renewed before it is gone (ruleset plan
-- 2026-10-19-blessing-steering; Righteous Fury's own time, plan 2026-10-20-fury-renew). A
-- buff without expiry never is.
function B.Expiring(a, minutes)
    return a.expires > 0 and a.expires - GetTime() < minutes * 60
end
-- Blessings and Salvation renew with the Priorities tab's time
local function Expiring(a) return B.Expiring(a, db.renewMinutes) end

-- The family and strength of this paladin's blessing on a unit, normal or Greater, or nil -
-- also when it is about to run out, unless `evenExpiring`. A Greater rank's strength is the
-- normal rank it equals, so the two compare (ruleset plan 2026-10-25-rank-glow-fixes).
local function MyBlessingOn(unit, evenExpiring)
    for _, a in ipairs(B.Auras(unit)) do
        local rank = a.mine and RANKS[a.id]
        if rank and IS_BLESSING[rank.family] then
            if Expiring(a) and not evenExpiring then return end
            return rank.family, rank.strength or 0
        end
    end
end

-- The best known Greater rank of a family: its ID and strength, or nil
local function BestGreater(family)
    local best, index = B.Best(D.BLESSINGS[family].greater)
    if best then return best, D.GREATER_EQUALS[family][index] end
end

-- The Symbols of Kings in the bags; demo mode's sample count
function B.Symbols()
    return ns.IsDemo() and D.DEMO_SYMBOLS or C_Item.GetItemCount(D.SYMBOL_OF_KINGS)
end
local Symbols = B.Symbols

-- The first family of the unit's class list, as the player edited it, this paladin can give
-- the unit - a normal rank or the best known Greater one fits - and others have not given
-- (ruleset plan 2026-10-19-priorities: lists by class, roles no longer choose)
function B.ChosenFamily(unit, class)
    for _, family in ipairs(db.classLists[class or select(2, UnitClass(unit))].order) do
        local f = D.BLESSINGS[family]
        local greater = B.Best(f.greater)
        if (B.Best(f.normal, unit) or (greater and B.Fits(greater, unit)))
           and not B.GivenByOthers(unit, family) then
            return family
        end
    end
end

-- Done for this paladin: my blessing on the member, normal or Greater, is of the chosen
-- family and no weaker than my best normal rank that fits him. One of another family is
-- replaced, so a change of list is cast at once (Michel, 2026-10-19); a weaker one of mine
-- counts as missing, as another paladin's does (Michel, 2026-10-25). An equal strength is
-- never weaker, so nothing is cast again and again.
local function Done(chosen, mine, strength, unit)
    if mine == nil or mine ~= chosen then return false end
    local best = select(2, B.Best(D.BLESSINGS[chosen].normal, unit)) or 0
    return strength >= best
end

-- The Greater family of a class: the one chosen for most of its members, ties by
-- D.BLESSING_ORDER
local ORDER_INDEX = {}
for i, family in ipairs(D.BLESSING_ORDER) do ORDER_INDEX[family] = i end
local function GreaterFamily(members)
    local count = {}
    for _, m in ipairs(members) do
        if m.chosen then count[m.chosen] = (count[m.chosen] or 0) + 1 end
    end
    local best
    for family, n in pairs(count) do
        if not best or n > count[best] or (n == count[best] and ORDER_INDEX[family] < ORDER_INDEX[best]) then
            best = family
        end
    end
    return best
end

-- The members the planner works on: { unit, class }. Demo mode shows every class, with its
-- default role and no auras, every entry on the player.
local function Roster()
    local list = {}
    if ns.IsDemo() then
        for _, class in ipairs(D.CLASS_ORDER) do list[#list + 1] = { unit = "player", class = class } end
        return list
    end
    for _, unit in ipairs(B.Members()) do
        -- A class without a list in Data.lua is left out: UnitClass is outside data
        local class = select(2, UnitClass(unit))
        if D.CLASS_LISTS[class or ""] and B.Eligible(unit) then list[#list + 1] = { unit = unit, class = class } end
    end
    return list
end

-- The blessing queue: entries { spell, unit, greater, hold, class }, Greater entries first, then
-- normal ones in group order. `hold`: a Greater entry for a class with exceptions, which must
-- not come first at combat start - the exceptions after it could not follow in combat. Also
-- returns the Symbols its Greater entries use. Out of combat only.
function B.PlanBlessings()
    local byClass, order = {}, {}
    for _, r in ipairs(Roster()) do
        local mine, strength = MyBlessingOn(r.unit)
        local m = { unit = r.unit, chosen = B.ChosenFamily(r.unit, r.class), mine = mine, strength = strength }
        m.done = Done(m.chosen, mine, strength, r.unit)
        byClass[r.class] = byClass[r.class] or {}
        table.insert(byClass[r.class], m)
        order[#order + 1] = m
    end

    local symbols = Symbols()
    -- `far`: members in need out of range, so the tooltip can say why nothing is left
    -- (SimpleConjureBar's F-04)
    local queue, covered, far = {}, {}, 0
    for _, class in ipairs(D.CLASS_ORDER) do
        local members = byClass[class]
        local family = members and GreaterFamily(members)
        local spell, greaterStrength
        if family then spell, greaterStrength = BestGreater(family) end
        if spell then
            -- Only members in range count, so a cast that misses the others is not repeated.
            -- Members it does not fit count for nothing: they get a normal one that fits.
            -- Members out of range count as far only if the Greater one covers them; if not,
            -- the normal loop below counts them
            local lacking, target, exceptions, farHere = 0, nil, false, 0
            for _, m in ipairs(members) do
                m.fitsGreater = B.Fits(spell, m.unit)
                if m.fitsGreater then
                    if m.chosen and m.chosen ~= family then exceptions = true end
                    -- Mine of the family counts unless it is weaker than this Greater rank
                    local needs = m.chosen == family and not (m.mine == family and m.strength >= greaterStrength)
                    if B.InRange(spell, m.unit) then
                        target = target or m.unit
                        if needs then lacking = lacking + 1 end
                    elseif needs then
                        farHere = farHere + 1
                    end
                end
            end
            -- The stronger form wins; between equals the group decides (Michel, 2026-10-19)
            local normalStrength = select(2, B.Best(D.BLESSINGS[family].normal)) or 0
            local useGreater = greaterStrength > normalStrength
                or (greaterStrength == normalStrength and IsInRaid() and lacking >= D.RAID_GREATER_MIN)
            if useGreater and (lacking == 0 or symbols > 0) then
                far = far + farHere
                if lacking > 0 then
                    symbols = symbols - 1
                    queue[#queue + 1] = { spell = spell, unit = target, greater = true, hold = exceptions, class = class }
                end
                for _, m in ipairs(members) do
                    if m.chosen == family and m.fitsGreater then covered[m] = true end
                end
            end
        end
    end

    for _, m in ipairs(order) do
        if m.chosen and not m.done and not covered[m] then
            local spell = B.Best(D.BLESSINGS[m.chosen].normal, m.unit)
            if spell and B.InRange(spell, m.unit) then
                queue[#queue + 1] = { spell = spell, unit = m.unit }
            elseif spell then
                far = far + 1
            end
        end
    end
    queue.far = far
    return queue, Symbols() - symbols
end

-- Whether a unit carries Salvation or Mass Salvation, from anyone. With `renew`, one of mine
-- about to run out counts as absent - for a non-tank; a tank's Revoke sees every Salvation.
local function HasSalvation(unit, renew)
    for _, a in ipairs(B.Auras(unit)) do
        if (a.id == D.SALVATION or a.id == D.MASS_SALVATION) and not (renew and a.mine and Expiring(a)) then
            return true
        end
    end
    return false
end

-- The Salvation queue: Salvation for every member whose role is not tank, Revoke for a tank
-- carrying it from anyone. In a raid a class gets Mass Salvation when its non-tanks in range
-- who lack it reach the threshold plus its tanks, each of whom needs a Revoke after it. Mass
-- Salvation first, then Revoke, then single Salvation in group order. `symbolsUsed` are the
-- Symbols the blessing queue already plans. Out of combat only.
function B.PlanSalvation(symbolsUsed)
    if not B.Known(D.SALVATION) then return {} end
    -- `far`: non-tanks out of range who lack it, so the tooltip can say why nothing is left
    local byClass, classes, position, far = {}, {}, {}, 0
    for i, r in ipairs(Roster()) do
        position[r] = i
        local tank = B.RoleOf(r.unit, r.class) == "TANK"
        if B.InRange(D.SALVATION, r.unit) then
            local m = { unit = r.unit, tank = tank, has = HasSalvation(r.unit, not tank), at = r }
            if not byClass[r.class] then
                byClass[r.class] = {}
                classes[#classes + 1] = r.class
            end
            table.insert(byClass[r.class], m)
        elseif not tank and not HasSalvation(r.unit, true) and B.Fits(D.SALVATION, r.unit) then
            far = far + 1
        end
    end

    local symbols = Symbols() - (symbolsUsed or 0)
    local mass, revoke, single = {}, {}, {}
    for _, class in ipairs(classes) do
        -- Mass Salvation counts only the members it fits; the others get single Salvation
        local lacking, massLacking, massTanks = {}, {}, 0
        for _, m in ipairs(byClass[class]) do
            m.fitsMass = B.Fits(D.MASS_SALVATION, m.unit)
            if m.tank then
                if m.fitsMass then massTanks = massTanks + 1 end
                if m.has and B.Known(D.REVOKE) and B.Fits(D.REVOKE, m.unit) then
                    revoke[#revoke + 1] = { spell = D.REVOKE, unit = m.unit }
                end
            elseif not m.has then
                lacking[#lacking + 1] = m
                if m.fitsMass then massLacking[#massLacking + 1] = m end
            end
        end
        local useMass = IsInRaid() and B.Known(D.MASS_SALVATION) and symbols > 0
            and #massLacking >= D.RAID_GREATER_MIN + massTanks
        if useMass then
            symbols = symbols - 1
            -- `hold`: with tanks it reaches, their Revokes could not follow in combat
            mass[#mass + 1] = { spell = D.MASS_SALVATION, unit = massLacking[1].unit, greater = true,
                                hold = massTanks > 0, class = class }
        end
        for _, m in ipairs(lacking) do
            if not (useMass and m.fitsMass) and B.Fits(D.SALVATION, m.unit) then
                single[#single + 1] = { spell = D.SALVATION, unit = m.unit, at = m.at }
            end
        end
    end
    table.sort(single, function(a, b) return position[a.at] < position[b.at] end)

    local queue = mass
    for _, e in ipairs(revoke) do queue[#queue + 1] = e end
    for _, e in ipairs(single) do queue[#queue + 1] = e end
    queue.far = far
    return queue
end

---------------------------------------------------------------------------
-- The overview (ruleset plan 2026-10-19-overview): what a member carries, from whom, and
-- what this paladin would give him next. Out of combat only, as the planner.
---------------------------------------------------------------------------
-- A member as the overview shows him: `carried` maps a blessing family, or "SALVATION" for
-- Salvation and Mass Salvation, to { spell, mine, source, expires }; `next` is { family,
-- spell } or nil; `greyed` when out of reach; `aura`, for a paladin, the aura he runs himself
-- as { spell, source, expires = 0 }. Demo mode reads no auras.
function B.Describe(unit, class)
    local demo = ns.IsDemo()
    local d = { unit = unit, class = class, role = B.RoleOf(unit, class), carried = {} }
    d.visible = demo or UnitIsVisible(unit)
    if d.visible and not demo then
        for _, a in ipairs(B.Auras(unit)) do
            if class == "PALADIN" and B.AURA_FAMILY[a.id] and a.source and UnitIsUnit(a.source, unit) then
                d.aura = { spell = a.id, source = a.source, expires = 0 }
            end
            local rank = RANKS[a.id]
            local key = rank and IS_BLESSING[rank.family] and rank.family
                or (a.id == D.SALVATION or a.id == D.MASS_SALVATION) and "SALVATION"
            if key then
                d.carried[key] = { spell = a.id, mine = a.mine, source = a.source, expires = a.expires }
            end
        end
    end
    local chosen = B.ChosenFamily(unit, class)
    local mine, strength = MyBlessingOn(unit)
    if chosen and not Done(chosen, mine, strength, unit) then
        local f = D.BLESSINGS[chosen]
        d.next = { family = chosen, spell = B.Best(f.normal, unit) or B.Best(f.greater) }
    end
    -- With no chosen family the range test is skipped
    d.greyed = not B.Eligible(unit) or (d.next ~= nil and not B.InRange(d.next.spell, unit))
    if d.greyed then d.next = nil end
    return d
end

-- The group member a source unit token stands for, or nil when the caster is not in the group
function B.InGroup(source)
    for _, unit in ipairs(B.Members()) do
        if UnitIsUnit(source, unit) then return unit end
    end
end

-- Every member in group order, described; in demo mode the made-up raid (Demo.lua)
function B.Overview()
    if ns.IsDemo() then return ns.DemoRaid() end
    local list = {}
    for _, unit in ipairs(B.Members()) do
        local class = select(2, UnitClass(unit))
        if D.CLASS_LISTS[class or ""] then list[#list + 1] = B.Describe(unit, class) end
    end
    return list
end

---------------------------------------------------------------------------
-- The aura (ruleset plan 2026-10-19-priorities): the first known family on the aura list that
-- no other paladin runs. Out of combat only.
---------------------------------------------------------------------------
local AURA_FAMILY = {}
for family, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do AURA_FAMILY[id] = family end
end
B.AURA_FAMILY = AURA_FAMILY

-- The aura families other paladins run, read from their own buffs: every visible paladin of
-- the group but the player; in a raid only the player's subgroup, as an aura reaches no
-- further. A buff from the player counts nothing, so an aura we share moves this paladin on,
-- as with blessings (Michel, 2026-10-19).
local function TakenAuras()
    local taken = {}
    if ns.IsDemo() then return taken end -- reads no auras; skips the roster too
    local members, subgroup = B.Members(), nil
    if IsInRaid() then
        for i, unit in ipairs(members) do
            if UnitIsUnit(unit, "player") then subgroup = select(3, GetRaidRosterInfo(i)) end
        end
    end
    for i, unit in ipairs(members) do
        if not UnitIsUnit(unit, "player") and select(2, UnitClass(unit)) == "PALADIN" and UnitIsVisible(unit)
           and (not subgroup or select(3, GetRaidRosterInfo(i)) == subgroup) then
            -- Equal auras do not stack: while he runs mine, the game shows mine on him and hides
            -- his (ruleset plan 2026-10-22-hidden-equal-aura). My aura on him with none of his
            -- own counts as his. An aura without a source is neither.
            local myFamily, ownShown = nil, false
            for _, a in ipairs(B.Auras(unit)) do
                local family = AURA_FAMILY[a.id]
                if family then
                    if a.source and UnitIsUnit(a.source, "player") then
                        myFamily = family
                    else
                        taken[family] = true
                        ownShown = ownShown or (a.source ~= nil and UnitIsUnit(a.source, unit))
                    end
                end
            end
            if myFamily and not ownShown then taken[myFamily] = true end
        end
    end
    return taken
end

-- The family the aura button casts: the first known one on the aura list that is not taken;
-- none free, the first known; none known, nil
function B.ChooseAura()
    local taken, firstKnown = TakenAuras(), nil
    for _, family in ipairs(db.auraList) do
        if B.Best(D.AURAS[family]) then
            firstKnown = firstKnown or family
            if not taken[family] then return family end
        end
    end
    return firstKnown
end

---------------------------------------------------------------------------
-- Buff & Run (ruleset plan 2026-10-20-buff-and-run): what the blessing button's middle click
-- casts on its target, any friendly player. Out of combat only.
---------------------------------------------------------------------------
-- The spell for the unit: nil unless it is a friendly player, alive and in reach; else the
-- first family of his class's list another paladin has not given, in the best normal rank
-- that fits him - Greater Blessings reach group members only. A blessing of mine on him,
-- also one running out, stops it: one of another family is kept, one of this family unless
-- it is weaker than that rank (Michel, 2026-10-25). Salvation and auras do not count.
function B.BuffRunSpell(unit)
    if not B.AurasReadable() then return end
    if not (UnitIsPlayer(unit) and UnitCanAssist("player", unit) and B.Eligible(unit)) then return end
    -- Blessing a PvP-flagged player flags the paladin too: only when allowed (Michel,
    -- 2026-10-20), or while the paladin is flagged for good - /pvp, the portrait menu, a
    -- battleground, an arena or a PvP zone - and loses nothing. A flag that runs out came by
    -- accident and does not count (Michel, 2026-10-22)
    if UnitIsPVP(unit) and not db.pvpBlessing
       and not (UnitIsPVP("player") and not IsPVPTimerRunning()) then
        return
    end
    local mine, strength = MyBlessingOn(unit, true)
    local list = db.classLists[select(2, UnitClass(unit))]
    if not list then return end
    for _, family in ipairs(list.order) do
        local spell, best = B.Best(D.BLESSINGS[family].normal, unit)
        if spell and not B.GivenByOthers(unit, family) then
            if mine and (mine ~= family or strength >= best) then return end
            if B.InRange(spell, unit) then return spell end
            return
        end
    end
end
