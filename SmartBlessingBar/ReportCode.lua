-- SmartBlessingBar - the bug report as one code (ruleset plan 2026-10-24-bug-report, after
-- SimpleConjureBar's ReportCode.lua)
-- "SBB1:" + Base64 of the report + ":" + its Adler-32 checksum as 8 lowercase hex digits.
-- Encoded, not compressed: no library needed. The checksum catches damage, not forgery.
-- Plain Lua 5.1 arithmetic only - no bit library, which plain Lua lacks - so the same file
-- loads as an addon file and through dofile in tools/decode-report.lua.

local _, ns = ...
if ns and not ns.enabled then return end

local M = {}
M.VERSION = 1

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INDEX = {}
for i = 1, #ALPHABET do INDEX[ALPHABET:sub(i, i)] = i - 1 end

local floor = math.floor

local function Encode64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local q1, q2 = floor(n / 262144), floor(n / 4096) % 64
        local q3, q4 = floor(n / 64) % 64, n % 64
        out[#out + 1] = ALPHABET:sub(q1 + 1, q1 + 1) .. ALPHABET:sub(q2 + 1, q2 + 1)
            .. (b and ALPHABET:sub(q3 + 1, q3 + 1) or "=") .. (c and ALPHABET:sub(q4 + 1, q4 + 1) or "=")
    end
    return table.concat(out)
end

-- nil for anything but whole groups of four Base64 characters
local function Decode64(s)
    if #s % 4 ~= 0 or s:find("[^%w%+/=]") or s:find("=[^=]") then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local chunk = s:sub(i, i + 3)
        local n, pad = 0, 0
        for j = 1, 4 do
            local ch = chunk:sub(j, j)
            if ch == "=" then pad = pad + 1; n = n * 64 else n = n * 64 + INDEX[ch] end
        end
        local a, b, c = floor(n / 65536), floor(n / 256) % 256, n % 256
        out[#out + 1] = string.char(a) .. (pad < 2 and string.char(b) or "") .. (pad < 1 and string.char(c) or "")
    end
    return table.concat(out)
end

-- Adler-32 as two 16-bit halves: string.format's %x takes no value above 2^31 on every build
local function Adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return ("%04x%04x"):format(b, a)
end

function M.Encode(text)
    return ("SBB%d:%s:%s"):format(M.VERSION, Encode64(text), Adler32(text))
end

-- The report from a code wherever it stands in a text - an issue body, a mail - with spaces
-- and line breaks inside it ignored. nil and the reason when it is not a whole, known code.
function M.Decode(text)
    local start = text:find("SBB%d")
    if not start then return nil, "no SBB code found" end
    local packed = text:sub(start):gsub("%s+", "")
    local version = tonumber(packed:match("^SBB(%d+):"))
    if version ~= M.VERSION then return nil, ("unknown code version SBB%s"):format(tostring(version)) end
    local body, sum = packed:match("^SBB%d+:([%w%+/=]*):(%x%x%x%x%x%x%x%x)")
    if not body then return nil, "damaged code: wrong characters or no checksum" end
    local report = Decode64(body)
    if not report then return nil, "damaged code: not valid Base64" end
    if Adler32(report) ~= sum:lower() then return nil, "damaged code: checksum does not match" end
    return report
end

if ns then ns.ReportCode = M end
return M
