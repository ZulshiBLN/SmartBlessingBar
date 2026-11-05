-- The workflows' rights (ruleset plan 2026-10-24-workflow-rights): no checkout keeps the job's
-- token in .git/config - nothing in them pushes - and the upload jobs only read; the github job
-- keeps the write right release.yml gives it, to create the release. Read as text: a few line
-- checks need no YAML parser.

local WORKFLOWS = { "build.yml", "ci.yml", "publish.yml", "release.yml" }

local function read(name)
    local f = assert(io.open(".github/workflows/" .. name, "rb"))
    local text = f:read("*a"):gsub("\r", "")
    f:close()
    return text
end

local function lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = l end
    return out
end

-- Every checkout's step - the lines indented deeper than its "- uses" - says
-- `persist-credentials: false`, inline (`with: { ... }`) or in a `with:` block
local function checkoutProblems(name, text)
    local out, ls = {}, lines(text)
    for i, l in ipairs(ls) do
        local indent = l:match("^(%s*)%- uses: actions/checkout@")
        if indent then
            local step = {}
            for j = i + 1, #ls do
                local own = ls[j]:match("^(%s*)%S")
                if own and #own <= #indent then break end
                step[#step + 1] = ls[j]
            end
            if not table.concat(step, "\n"):find("persist%-credentials:%s*false") then
                out[#out + 1] = ("%s:%d keeps the token"):format(name, i)
            end
        end
    end
    return out
end

-- The jobs of a workflow, key -> its lines up to the next job
local function jobs(text)
    local out, key, started = {}, nil, false
    for _, l in ipairs(lines(text)) do
        if l:find("^jobs:") then started = true
        elseif started and l:find("^  [%w_-]+:%s*$") then
            key = l:match("^  ([%w_-]+):")
            out[key] = {}
        elseif started and key then
            table.insert(out[key], l)
        end
    end
    for k, ls in pairs(out) do out[k] = table.concat(ls, "\n") end
    return out
end

-- The lines of one job of publish.yml, up to the next job
local function job(text, key)
    return jobs(text)[key] or ""
end

local UPLOAD_JOBS = { "preflight", "curseforge", "wago", "curseforge-dry", "wago-dry" }

local function publishProblems(text)
    local out = {}
    for _, key in ipairs(UPLOAD_JOBS) do
        if not job(text, key):find("\n?%s*permissions:%s*{%s*contents:%s*read%s*}") then
            out[#out + 1] = key .. " has no read-only permissions"
        end
    end
    if job(text, "github"):find("permissions:", 1, true) then
        out[#out + 1] = "github sets its own permissions"
    end
    return out
end

-- The upload tokens (ruleset plan 2026-10-24-release-environment): only release.yml's publish
-- job passes them, by name - GitHub resolves an environment secret in a called workflow only
-- when the caller passes it - and only publish.yml's jobs in the environment "release", which
-- only v* tag runs may use, read them
local function tokenProblems(files)
    local out = {}
    for name, text in pairs(files) do
        for key, body in pairs(jobs(text)) do
            if body:find("secrets%.CF_API_TOKEN") or body:find("secrets%.WAGO_API_TOKEN") then
                local passes = name == "release.yml" and key == "publish"
                local reads = name == "publish.yml" and body:find("\n%s*environment:%s*release%s*\n") ~= nil
                if not (passes or reads) then out[#out + 1] = name .. ": " .. key .. " gets a token" end
            end
        end
    end
    local publish = jobs(files["release.yml"]).publish or ""
    for _, s in ipairs({ "CF_API_TOKEN", "WAGO_API_TOKEN" }) do
        if not publish:find(s .. ":%s*%${{%s*secrets%." .. s .. "%s*}}") then
            out[#out + 1] = "release.yml: publish does not pass " .. s
        end
    end
    local p = jobs(files["publish.yml"])
    for _, key in ipairs({ "preflight", "curseforge", "wago" }) do
        local body = p[key] or ""
        if not body:find("\n%s*environment:%s*release%s*\n") then out[#out + 1] = key .. " is not in release" end
        if not body:find("if:%s*%${{%s*!inputs%.dry_run%s*}}") then out[#out + 1] = key .. " runs in a dry run" end
    end
    for _, key in ipairs({ "curseforge", "wago", "github" }) do
        if not (p[key] or ""):find("needs:%s*preflight") then out[#out + 1] = key .. " does not need preflight" end
    end
    if not (p.github or ""):find("!cancelled%(%) && needs%.preflight%.result != 'failure'") then
        out[#out + 1] = "github may publish after a failed preflight"
    end
    for _, key in ipairs({ "curseforge-dry", "wago-dry" }) do
        local body = p[key] or ""
        if body == "" or body:find("environment:") or body:find("secrets%.") then
            out[#out + 1] = key .. " is missing or gets the environment"
        end
    end
    return out
end

local function allFiles()
    local files = {}
    for _, name in ipairs(WORKFLOWS) do files[name] = read(name) end
    return files
end

describe("the upload tokens", function()
    it("are passed only by release.yml's publish job and read only in the environment release", function()
        assert.are.same({}, tokenProblems(allFiles()))
    end)

    it("notice a rehearsal that gets them, a publish job that does not pass them, and a job outside release", function()
        local files = allFiles()
        local leak = files["ci.yml"]:gsub("(\n  rehearsal:\n)", "%1    secrets:\n      CF_API_TOKEN: ${{ secrets.CF_API_TOKEN }}\n", 1)
        assert.is_true(#tokenProblems({ ["ci.yml"] = leak, ["release.yml"] = files["release.yml"],
            ["publish.yml"] = files["publish.yml"], ["build.yml"] = files["build.yml"] }) > 0)
        local dropped = files["release.yml"]:gsub("\n      CF_API_TOKEN: %${{ secrets%.CF_API_TOKEN }}", "")
        assert.is_true(#tokenProblems({ ["ci.yml"] = files["ci.yml"], ["release.yml"] = dropped,
            ["publish.yml"] = files["publish.yml"], ["build.yml"] = files["build.yml"] }) > 0)
        local outside = files["publish.yml"]:gsub("\n    environment: release\n", "\n", 1)
        assert.is_true(#tokenProblems({ ["ci.yml"] = files["ci.yml"], ["release.yml"] = files["release.yml"],
            ["publish.yml"] = outside, ["build.yml"] = files["build.yml"] }) > 0)
    end)
end)

describe("the workflows' rights", function()
    it("store no token in any checkout, and let the upload jobs only read", function()
        local problems = {}
        for _, name in ipairs(WORKFLOWS) do
            for _, p in ipairs(checkoutProblems(name, read(name))) do problems[#problems + 1] = p end
        end
        for _, p in ipairs(publishProblems(read("publish.yml"))) do problems[#problems + 1] = p end
        assert.are.same({}, problems)
    end)

    it("notice one checkout that keeps the token, and an upload job with write rights", function()
        local text = read("publish.yml")
        local oneLost = text:gsub("\n%s*with:%s*{%s*persist%-credentials:%s*false%s*}[^\n]*", "", 1)
        assert.are.equal(1, #checkoutProblems("publish.yml", oneLost))
        local writable = text:gsub("permissions:%s*{%s*contents:%s*read%s*}", "permissions: { contents: write }", 1)
        assert.are.equal(1, #publishProblems(writable))
    end)
end)
