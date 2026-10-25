-- A secret value errors when it is compared or truth-tested (rules/code.md, WoW Forever), so
-- `issecretvalue` must come first (ruleset plan 2026-10-24-review-code-fixes). Lua 5.1 cannot
-- trap `x == nil` or `if x`, and the mock's secrets compare freely, so this reads the source:
-- in each region the first comparison or truth test of the value comes after its secret check.

local addon = require("addon")

local function source(file)
    local f = assert(io.open("SmartBlessingBar/" .. file, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

-- The text from the first line holding `start` up to the first line after it matching `stop`
local function region(text, start, stop)
    local s = assert(text:find(start, 1, true), start)
    local lineEnd = text:find("\n", s, true)
    local pos = lineEnd + 1
    while true do
        local nl = text:find("\n", pos, true)
        local line = text:sub(pos, (nl or #text + 1) - 1)
        if line:find(stop) then return text:sub(s, nl or #text) end
        assert(nl, "no end for " .. start)
        pos = nl + 1
    end
end

-- Where `v` is first compared or truth-tested in `text`, or nil
local function firstTest(text, v)
    local w = "%f[%w_]" .. v .. "%f[^%w_]"
    local best
    for _, p in ipairs({ w .. "%s*[=~]=", "[=~]=%s*" .. w, "if%s+" .. w, "not%s+" .. w,
                         "and%s+" .. w, "or%s+" .. w, w .. "%s+and", w .. "%s+or", w .. "%s+then" }) do
        local at = text:find(p)
        if at and (not best or at < best) then best = at end
    end
    return best
end

-- Where `v` is first passed to a secret check
local function firstCheck(text, v)
    local a = text:find("issecretvalue%(" .. v .. "%)")
    local b = text:find("Secret%(" .. v .. "%)")
    if a and b then return math.min(a, b) end
    return a or b
end

local function assertCheckedFirst(text, v, what)
    local test, check = firstTest(text, v), firstCheck(text, v)
    assert.is_truthy(check, what .. ": no secret check of " .. v)
    assert.is_true(test == nil or check < test, what .. ": " .. v .. " is tested before its secret check")
end

describe("secret values", function()
    it("are checked before they are compared or truth-tested", function()
        local blessings, privacy = source("Blessings.lua"), source("Privacy.lua")
        assertCheckedFirst(region(blessings, 'keptEvents:SetScript("OnEvent"', "^end%)"), "guid",
            "UNIT_AURA handler")
        assertCheckedFirst(region(blessings, "local function PersonKey", "^end"), "guid", "PersonKey")
        local known = region(privacy, "function ns.KnownNames", "^end")
        assertCheckedFirst(region(known, "local function Add(v)", "^    end"), "v", "KnownNames' Add")
        local loop = region(known, "local name, realm = UnitName(u)", "^    end")
        assertCheckedFirst(loop, "name", "KnownNames' name and realm")
        assertCheckedFirst(loop, "realm", "KnownNames' name and realm")
        -- The overview's giver (ruleset plan 2026-10-25-rank-glow-fixes)
        assertCheckedFirst(region(source("Overview.lua"), "local function ShowIconTooltip", "^end"), "name",
            "the overview's giver")
    end)

    -- The 1.1.0 review's F-05: a secret instance ID must not become a table key, and the mock
    -- cannot catch a secret used as a key either
    it("are not used as a key: Scan keys an aura by its instance only after B.SpellOf", function()
        local scan = region(source("Blessings.lua"), "local function Scan", "^end")
        local loops = 0
        for body in scan:gmatch("while true do(.-)\n    end") do
            loops = loops + 1
            local key = body:find("[aura.auraInstanceID]", 1, true)
            local check = body:find("B.SpellOf(aura)", 1, true)
            assert.is_truthy(key and check and check < key, body)
        end
        assert.are.equal(2, loops)
    end)

    it("are not asked for at all for a token outside the group", function()
        addon.load("enUS")
        FIRE("PLAYER_LOGIN"); RUNTIMERS()
        STATE.guidAsked = {}
        FIRE("UNIT_AURA", "nameplate1")
        assert.is_nil(STATE.guidAsked.nameplate1)
    end)
end)
