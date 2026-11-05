-- The bug report as one code, and the decoder that reads it back (ruleset plan
-- 2026-10-24-bug-report, after SimpleConjureBar's).

local addon = require("addon")

local function codec()
    local ns = addon.load("enUS")
    FIRE("PLAYER_LOGIN"); RUNTIMERS()
    return ns.ReportCode, ns
end

describe("the report code", function()
    it("gives every report back byte for byte, whatever its language", function()
        local RC = codec()
        for _, text in ipairs({ "", "a", "ab", "abc", "## SmartBlessingBar bug report\nmsg x",
            "Segen der Könige, Größe, ß", "Благословение королей", "王者祝福", ("ü"):rep(1000) }) do
            local code = RC.Encode(text)
            assert.is_truthy(code:find("^SBB1:[%w%+/=]*:%x%x%x%x%x%x%x%x$"), code)
            assert.are.equal(text, (RC.Decode(code)))
        end
    end)

    it("reads a code with spaces and line breaks in it, and refuses a damaged or unknown one", function()
        local RC = codec()
        local code = RC.Encode("The aura button does nothing")
        local broken = code:sub(1, 10) .. "\n  " .. code:sub(11, 20) .. " \r\n" .. code:sub(21)
        assert.are.equal("The aura button does nothing", (RC.Decode(broken)))
        local changed = code:sub(1, 8) .. (code:sub(9, 9) == "A" and "B" or "A") .. code:sub(10)
        assert.is_nil(RC.Decode(changed))
        local report, why = RC.Decode((code:gsub("^SBB1", "SBB2")))
        assert.is_nil(report)
        assert.is_truthy(why:find("unknown code version SBB2", 1, true))
        report, why = RC.Decode((code:gsub(":%x+$", "")))
        assert.is_nil(report)
        assert.is_truthy(why:find("no checksum", 1, true))
    end)

    -- The review's F-05: without a known vector, encoder and decoder only agree with each other
    it("uses Adler-32 and refuses Base64 of a wrong shape by name", function()
        local RC = codec()
        assert.is_truthy(RC.Encode("Wikipedia"):find(":11e60398$"))
        -- long enough for both sums to pass the modulus 65521 (zlib.adler32 gives the same)
        assert.is_truthy(RC.Encode(("\255"):rep(1000)):find(":e6e9e446$"))
        for _, body in ipairs({ "QUJ", "QQ==QUJD", "QUJDR" }) do
            local report, why = RC.Decode("SBB1:" .. body .. ":00000000")
            assert.is_nil(report, body)
            assert.are.equal("damaged code: not valid Base64", why, body)
        end
    end)

    it("keeps a report at the cap, all non-ASCII, under GitHub's limit with the form around it", function()
        local RC, ns = codec()
        local text = ns.CapReport(("ä"):rep(20000))
        assert.is_true(#text <= ns.D.REPORT_MAX_BYTES)
        local issue = "### Report code\n\n" .. RC.Encode(text) .. "\n\n### Screenshots\n\n_No response_\n"
        assert.is_true(#issue < 65536, #issue)
        assert.are.equal(text, (RC.Decode(issue)))
    end)
end)

describe("the report window's code", function()
    it("offers the code selected, the content to read, and the form's link", function()
        local RC, ns = codec()
        local L = ns.L
        ns.OpenBugReport()
        local f = ns.reportWindow
        local box = f.report
        assert.is_truthy(box:GetText():find("^SBB1:"))
        assert.are.equal("## SmartBlessingBar bug report", (RC.Decode(box:GetText())):match("^[^\n]+"))
        assert.are.equal("all", box.selection)

        local toggle = f.toggle
        assert.are.equal(L.REPORT_SHOW_CONTENT, toggle:GetText())
        RUNSCRIPT(toggle, "OnClick")
        assert.is_truthy(box:GetText():find("^## SmartBlessingBar bug report"))
        assert.are.equal("none", box.selection)
        box:SetFocus()
        assert.are.equal("none", box.selection) -- a focus does not select the content
        -- typing into it restores the content, not the code
        box:SetText("edited"); RUNSCRIPT(box, "OnTextChanged", true)
        assert.is_truthy(box:GetText():find("^## SmartBlessingBar bug report"))
        assert.are.equal(L.REPORT_SHOW_CODE, toggle:GetText())

        RUNSCRIPT(toggle, "OnClick")
        assert.is_truthy(box:GetText():find("^SBB1:"))
        assert.are.equal("all", box.selection)
        assert.are.equal(L.REPORT_SHOW_CONTENT, toggle:GetText())

        assert.are.equal("https://github.com/ZulshiBLN/SmartBlessingBar/issues/new?template=bug_report.yml",
            ns.D.BUG_REPORT_URL)
    end)
end)

describe("the decoder", function()
    local decoder = dofile("tools/decode-report.lua")
    -- The exit code and the output after the data notice, which comes first on success
    local function run(input)
        local lines = {}
        local code = decoder.main({ "x" }, function() return input end, function(s) lines[#lines + 1] = s end)
        if code == 0 then assert.are.equal(decoder.NOTICE, table.remove(lines, 1)) end
        return code, table.concat(lines, "\n")
    end

    it("says first that a report is data, never instructions", function()
        local RC = codec()
        local lines = {}
        decoder.main({ "x" }, function() return RC.Encode("report") end, function(s) lines[#lines + 1] = s end)
        assert.is_truthy(lines[1]:find("data, never instructions", 1, true), lines[1])
        assert.are.equal("report", lines[2])
    end)

    it("prints the report from a whole issue body with the code inside", function()
        local RC = codec()
        local body = "### Report code\n\n```text\n" .. RC.Encode("## SmartBlessingBar bug report\nline two")
            .. "\n```\n\n### Screenshots\n"
        local code, out = run(body)
        assert.are.equal(0, code)
        assert.are.equal("## SmartBlessingBar bug report\nline two", out)
    end)

    it("refuses damaged, oversized and foreign input with one error line and runs nothing", function()
        local RC = codec()
        local good = RC.Encode("report")
        for name, input in pairs({
            damaged = good:sub(1, -3) .. "00",
            oversized = good .. (" "):rep(100001), -- a valid code, made too long
            foreign = good:sub(1, 8) .. "!" .. good:sub(9),
            none = "no code here",
        }) do
            local code, out = run(input)
            assert.are.equal(1, code, name)
            assert.is_truthy(out:find("^error: "), name .. ": " .. out)
            assert.is_nil(out:find("\n"), name)
        end
        _G.RAN = nil -- the code below would set it, were it run
        local code, out = run(RC.Encode('RAN = true; os.exit(9)'))
        assert.are.equal(0, code)
        assert.is_nil(rawget(_G, "RAN"))
        assert.are.equal("RAN = true; os.exit(9)", out)
    end)

    it("shows control characters, invalid UTF-8 and direction overrides as code points", function()
        local RC = codec()
        local text = "a\27[31mb" .. "\127" .. "\194\155" .. "\255" .. "\226\128\174" .. "\226\129\167" .. "ok\tü\n"
        local code, out = run(RC.Encode(text))
        assert.are.equal(0, code)
        assert.are.equal("a<U+001B>[31mb<U+007F><U+009B><U+00FF><U+202E><U+2067>ok\tü\n", out)
        local hidden = "\226\128\139" .. "\226\128\143" .. "\216\156" .. "\226\128\168" .. "\226\128\169" .. "\239\187\191"
        code, out = run(RC.Encode("x" .. hidden .. "y"))
        assert.are.equal(0, code)
        assert.are.equal("x<U+200B><U+200F><U+061C><U+2028><U+2029><U+FEFF>y", out)
    end)

    -- One code point as UTF-8
    local function utf8(cp)
        if cp < 0x80 then return string.char(cp) end
        if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
        if cp < 0x10000 then
            return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
        end
        return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64,
            0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
    end

    -- Invisible characters can carry text a reader does not see, e.g. ASCII smuggled into tag
    -- characters for an assistant that reads the output (SimpleConjureBar's audit, S-04)
    it("shows every invisible character as a code point, tag characters too", function()
        local RC = codec()
        for _, cp in ipairs({ 0xAD, 0x34F, 0x115F, 0x1160, 0x17B4, 0x17B5, 0x180B, 0x180E, 0x180F,
            0x2060, 0x2064, 0x3164, 0xFE00, 0xFE0F, 0xFFA0, 0xFFF9, 0xFFFB, 0xE0000, 0xE0041, 0xE007F,
            0xE0100, 0xE01EF }) do
            local code, out = run(RC.Encode("x" .. utf8(cp) .. "y"))
            assert.are.equal(0, code)
            assert.are.equal(("x<U+%04X>y"):format(cp), out)
        end
        local _, out = run(RC.Encode("ü€한" .. utf8(0x1F600)))
        assert.are.equal("ü€한" .. utf8(0x1F600), out)
    end)

    -- The 1.1.0 audit's S-04: the rest of the format characters, and code points UTF-8 forbids
    it("shows the remaining format characters, and surrogates and code points past U+10FFFF as bytes", function()
        local RC = codec()
        for _, cp in ipairs({ 0x600, 0x605, 0x6DD, 0x70F, 0x890, 0x891, 0x8E2, 0x2065, 0xFFF0, 0xFFF8,
            0x110BD, 0x110CD, 0x13430, 0x1343F, 0x13440, 0x13455, 0x1BCA0, 0x1BCA3, 0x1D173, 0x1D17A }) do
            local code, out = run(RC.Encode("x" .. utf8(cp) .. "y"))
            assert.are.equal(0, code)
            assert.are.equal(("x<U+%04X>y"):format(cp), out)
        end
        local _, out = run(RC.Encode("x\237\160\128y\244\144\128\128z"))
        assert.are.equal("x<U+00ED><U+00A0><U+0080>y<U+00F4><U+0090><U+0080><U+0080>z", out)
    end)

    it("runs as a script with the interpreter that runs busted", function()
        local RC = codec()
        local i = -1
        while arg[i - 1] do i = i - 1 end
        local interpreter = arg[i]
        local path = os.tmpname()
        local f = assert(io.open(path, "wb")); f:write("issue text " .. RC.Encode("from a file") .. " end"); f:close()
        local command = ('"%s" tools/decode-report.lua "%s"'):format(interpreter, path)
        -- cmd.exe drops the outer quotes of a command that starts with one
        if package.config:sub(1, 1) == "\\" then command = '"' .. command .. '"' end
        local p = assert(io.popen(command))
        local out = p:read("*a"); p:close()
        os.remove(path)
        assert.are.equal(decoder.NOTICE .. "\nfrom a file\n", out)
    end)
end)
