-- SmartBlessingBar - core
-- Class check, chat output and saved variables. Every other module builds on this file.

local ADDON_NAME, ns = ...
local D = ns.D

-- The AddOn compartment: the TOC names these three functions for every class, so they exist
-- before the paladin check below. For a paladin Minimap.lua sets what they call; for any other
-- class a click does nothing.
function SmartBlessingBar_OnCompartmentClick(...)
    if ns.CompartmentClick then ns.CompartmentClick(...) end
end
function SmartBlessingBar_OnCompartmentEnter(...)
    if ns.CompartmentEnter then ns.CompartmentEnter(...) end
end
function SmartBlessingBar_OnCompartmentLeave(...)
    if ns.CompartmentLeave then ns.CompartmentLeave(...) end
end

-- The addon is paladin-only. Every later module checks this flag and stops loading otherwise.
local _, playerClass = UnitClass("player")
ns.enabled = (playerClass == "PALADIN")
if not ns.enabled then return end

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
function ns.Print(msg)
    print("|cfff58cbaSmartBlessingBar|r: " .. msg)
end

---------------------------------------------------------------------------
-- Runtime language switch, as in SimpleConjureBar
-- Every localized text is registered with its key (and format arguments), so a language
-- change re-renders exactly these texts. No text is ever matched by its content.
---------------------------------------------------------------------------
local registry = setmetatable({}, { __mode = "k" }) -- object -> key | function | { key, args... }
local languageCallbacks = {}

local function Resolve(entry)
    local kind = type(entry)
    if kind == "function" then return entry() end
    if kind == "table" then return ns.L[entry[1]]:format(unpack(entry, 2)) end
    return ns.L[entry]
end

-- Sets a localized text on a FontString or Button and keeps it current on language changes.
-- key: locale key, or a function returning the text. Extra arguments are format arguments.
function ns.SetL(obj, key, ...)
    local entry = key
    if select("#", ...) > 0 then entry = { key, ... } end
    registry[obj] = entry
    obj:SetText(Resolve(entry))
end

-- A name the client provides (a spell): the client's own while the addon speaks the client's
-- language, else the addon's translation under `key` (localization.md)
function ns.LocalName(clientName, key)
    if clientName and ns.GetLocaleCode() == ns.clientLocale then return clientName end
    return ns.L[key]
end

-- fn runs after every language change (layout updates that depend on text widths)
function ns.OnLanguageChanged(fn)
    languageCallbacks[#languageCallbacks + 1] = fn
end

function ns.ApplyLanguage(code)
    if code == ns.GetLocaleCode() then return end
    ns.SetLocale(code)
    for obj, entry in pairs(registry) do obj:SetText(Resolve(entry)) end
    for _, fn in ipairs(languageCallbacks) do fn() end
end

---------------------------------------------------------------------------
-- Secure attributes
---------------------------------------------------------------------------
-- The only way the addon writes a secure attribute. In combat the client refuses the
-- write; it is skipped, and the full refresh on PLAYER_REGEN_ENABLED writes it then.
-- Unchanged values are not written: every SetAttribute fires OnAttributeChanged on the
-- button.
function ns.SetAttr(button, key, value)
    if InCombatLockdown() then return end
    if button:GetAttribute(key) ~= value then button:SetAttribute(key, value) end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local db
local dbCallbacks = {}

-- Modules keep their own local reference to the settings table; it exists after PLAYER_LOGIN.
function ns.OnDBReady(fn)
    dbCallbacks[#dbCallbacks + 1] = fn
    if db then fn(db) end
end

-- x ~= x is true only for NaN; math.huge passes the type check but is no number to use
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

-- The client's anchor names; SetPoint raises an error on any other
local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
                  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- A number from saved data, clamped to [lo, hi]; a wrong type, NaN or infinity becomes the
-- default.
local function Num(v, lo, hi, default, integer)
    v = tonumber(v)
    if not finite(v) then v = default end
    v = math.max(lo, math.min(hi, v))
    if integer then v = math.floor(v + 0.5) end
    return v
end

local function CopyColor(c) return { r = c.r, g = c.g, b = c.b, a = c.a } end
ns.CopyColor = CopyColor

-- An order of keys as saved: each of `default`'s keys once. Unknown keys and doubles are
-- dropped, missing ones appended in default order; a non-table becomes a copy of the default.
local function ValidOrder(saved, default)
    local valid, seen, out = {}, {}, {}
    for _, k in ipairs(default) do valid[k] = true end
    if type(saved) == "table" then
        for _, k in ipairs(saved) do
            if valid[k] and not seen[k] then
                out[#out + 1] = k
                seen[k] = true
            end
        end
    end
    for _, k in ipairs(default) do
        if not seen[k] then out[#out + 1] = k end
    end
    return out
end

-- The priority lists as the player edits them: per class the families on, in order, and those
-- switched off (ruleset plans 2026-10-19-blessing-steering, 2026-10-19-priorities). A class's
-- default and the blessings it can have are D.CLASS_LISTS (ruleset plan
-- 2026-10-20-class-defaults). A family the class does not have goes from both parts; a class
-- whose entry is damaged, or whose saved order keeps no family, gets its default; otherwise a
-- family of the class in neither part is appended, in the class's order.
local function DefaultClassList(class)
    return { order = { unpack(D.CLASS_LISTS[class]) }, off = {} }
end

local function ValidList(entry, class)
    if type(entry) ~= "table" or type(entry.order) ~= "table" or type(entry.off) ~= "table" then
        return DefaultClassList(class)
    end
    local has = {}
    for _, family in ipairs(D.CLASS_LISTS[class]) do has[family] = true end
    local order, off, seen = {}, {}, {}
    for _, family in ipairs(entry.order) do
        if has[family] and not seen[family] then
            order[#order + 1] = family
            seen[family] = true
        end
    end
    if #order == 0 then return DefaultClassList(class) end
    for family, v in pairs(entry.off) do
        if has[family] and not seen[family] and v == true then off[family] = true end
    end
    for _, family in ipairs(D.CLASS_LISTS[class]) do
        if not seen[family] and not off[family] then order[#order + 1] = family end
    end
    return { order = order, off = off }
end

local function ValidClassLists(saved)
    local lists = {}
    for _, class in ipairs(D.CLASS_ORDER) do
        lists[class] = ValidList(type(saved) == "table" and saved[class], class)
    end
    return lists
end

-- Fresh default lists, for the Priorities tab's Default
function ns.DefaultClassLists() return ValidClassLists(nil) end

-- Saved variables are plain files that can be edited or damaged, so every value is checked
-- before anything reads it.
function ns.InitDB()
    if type(SmartBlessingBarDB) ~= "table" then SmartBlessingBarDB = {} end
    if type(SmartBlessingBarGlobalDB) ~= "table" then SmartBlessingBarGlobalDB = {} end
    db = SmartBlessingBarDB

    local lang = SmartBlessingBarGlobalDB.language
    if lang ~= nil and not ns.locales[lang] then
        SmartBlessingBarGlobalDB.language = nil -- unknown language code
    end

    -- Version 6 replaces the class buttons with the blessing and Salvation buttons (ruleset
    -- plan 2026-10-19-blessing-core). It runs before the checks below, which would otherwise
    -- create the new ants settings at their defaults and drop the old order key.
    if (tonumber(db.dbVersion) or 0) < 6 then
        if db.classAntsColor ~= nil then db.blessingAntsColor = db.classAntsColor end
        if db.classAntsSpeed ~= nil then db.blessingAntsSpeed = db.classAntsSpeed end
        db.classAntsColor, db.classAntsSpeed = nil, nil
        if type(db.order) == "table" then
            local order = {}
            for _, key in ipairs(db.order) do
                if key == "CLASSES" then
                    order[#order + 1] = "BLESSING"
                    order[#order + 1] = "SALVATION"
                else
                    order[#order + 1] = key
                end
            end
            db.order = order
        end
        db.assign, db.classOrder = nil, nil
    end

    -- Version 8 (ruleset plan 2026-10-19-priorities): blessing lists by class instead of by
    -- role, auras by a list instead of one choice, the flyout settings gone. A class takes the
    -- saved list of its default role; the saved aura leads the aura list. Before the checks
    -- below, which would replace both with their defaults. Each conversion runs only on its
    -- old input: a file whose version got lost keeps its current lists (code.md, migrations
    -- safe to run twice).
    if (tonumber(db.dbVersion) or 0) < 8 then
        if type(db.auraList) ~= "table" then
            local auraList = {}
            if D.AURAS[db.aura] then auraList[1] = db.aura end
            for _, family in ipairs(D.AURA_ORDER) do
                if family ~= db.aura then auraList[#auraList + 1] = family end
            end
            db.auraList = auraList
        end
        if type(db.classLists) ~= "table" or type(db.roleLists) == "table" then
            local classLists = {}
            if type(db.roleLists) == "table" then
                for _, class in ipairs(D.CLASS_ORDER) do
                    classLists[class] = ValidList(db.roleLists[D.CLASS_ROLES[class][1]], class)
                end
            end
            db.classLists = classLists
        end
        db.aura, db.roleLists = nil, nil
        db.flyoutAutoClose, db.flyoutAutoCloseTime, db.flyoutDir = nil, nil, nil
    end

    -- Version 1 held nothing but its version; version 2 adds the fields below. The checks
    -- that follow create them, so the migration is these checks, and running it twice
    -- changes nothing.
    if type(db.locked) ~= "boolean" then db.locked = false end
    if not ANCHORS[db.point] or not ANCHORS[db.rel] or not finite(db.x) or not finite(db.y) then
        db.point, db.rel, db.x, db.y = nil, nil, nil, nil
    end

    -- Version 3 adds the look, layout and highlight settings; the same checks create them.
    for key, default in pairs(D.BOOL_DEFAULTS) do
        if type(db[key]) ~= "boolean" then db[key] = default end
    end
    for key, n in pairs(D.NUMBER_DEFAULTS) do
        db[key] = Num(db[key], n.min, n.max, n.default, n.integer)
    end
    for key, color in pairs(D.COLOR_DEFAULTS) do
        local c = db[key]
        if type(c) ~= "table" then
            db[key] = CopyColor(color)
        else
            for _, part in ipairs({ "r", "g", "b", "a" }) do c[part] = Num(c[part], 0, 1, color[part]) end
        end
    end
    db.demo = false -- demo mode always starts switched off

    -- Version 5 adds the supplies (the loops above) and the bar's order
    db.order = ValidOrder(db.order, D.DEFAULT_ORDER)

    -- Version 8: the blessing lists per class and the aura list
    db.classLists = ValidClassLists(db.classLists)
    db.auraList = ValidOrder(db.auraList, D.AURA_ORDER)

    db.dbVersion = D.DB_VERSION

    for _, fn in ipairs(dbCallbacks) do fn(db) end
end

-- Demo mode: everything counts as known and no click casts (ruleset plan
-- 2026-10-18-settings-window, IMPLEMENTATION "Demo"). Never saved: off at every login.
function ns.IsDemo() return db ~= nil and db.demo == true end

function ns.DemoPrint(fmt, ...)
    ns.Print("|cffff9933" .. ns.L.DEMO .. "|r: " .. fmt:format(...))
end
