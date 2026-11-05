-- SmartBlessingBar - bug report window
-- Addons cannot send data, open a browser or write to the clipboard. The window therefore builds
-- the report from a short form and the game, shows it as one code (ReportCode.lua), selected for
-- Ctrl+C, and links the GitHub form the code is pasted into. What it may hold: Privacy.lua
-- (ruleset plan 2026-10-24-bug-report).

local _, ns = ...
if not ns.enabled then return end

local D, L = ns.D, ns.L
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- Window background, invisible to solid, for this window and the settings window, which loads
-- after this file (ruleset plan 2026-10-22-anchor-and-window-background). The dialog texture
-- lets the game show through and can never become solid on its own: it fades out below
-- today's value, and a black layer beneath it fills in above. At today's value it is the
-- window as it always was. Frame edge, texts and controls are not touched.
---------------------------------------------------------------------------
-- Called right after SetBackdrop; a client without BackdropTemplate has no backdrop to change
function ns.AddOpacityLayer(window)
    if not window.Center then return end
    local layer = window:CreateTexture(nil, "BACKGROUND", nil, -8)
    layer:SetColorTexture(0, 0, 0, 1)
    layer:SetPoint("TOPLEFT", 11, -12) -- the backdrop's insets
    layer:SetPoint("BOTTOMRIGHT", -12, 11)
    window.Center:SetDrawLayer("BACKGROUND", -7) -- the dialog texture stays above it
    window.opacityLayer = layer
end

function ns.ApplyWindowOpacity(window)
    if not (db and window and window.opacityLayer) then return end
    local o, d = db.windowOpacity / 100, D.WINDOW_OPACITY_TODAY / 100
    window:SetBackdropColor(1, 1, 1, math.min(1, o / d))
    window.opacityLayer:SetAlpha(math.max(0, (o - d) / (1 - d)))
end

local MAX_ERRORS = 5       -- newest errors of this addon included in the report
local MAX_STACK_LINES = 12 -- stack lines per error
local MAX_ADDONS = 60      -- loaded addons named in the report

---------------------------------------------------------------------------
-- State snapshot (ruleset plan 2026-10-24-bug-report): what decides a misbehaviour without a
-- Lua error - each button's click, the queues, the Symbols, the group by class, own buffs - as
-- IDs, tokens and counts
---------------------------------------------------------------------------
local ATTRS = { "type", "spell", "unit", "macrotext" }

local function ButtonLine(label, b)
    local parts = { "button " .. label, "shown=" .. tostring(b:IsShown()) }
    for _, suffix in ipairs({ "", "1", "2", "3" }) do
        for _, a in ipairs(ATTRS) do
            local v = b:GetAttribute(a .. suffix)
            if v ~= nil then
                parts[#parts + 1] = a .. suffix .. "=" .. (a == "macrotext" and ns.SafeMacro(v) or ns.SafeValue(v))
            end
        end
    end
    return table.concat(parts, " ")
end

-- A queue as counts: entries left, held back at combat start, members in need out of range
local function QueueLine(label, b)
    local queue, held = b.queue or {}, 0
    for _, entry in ipairs(queue) do if entry.hold then held = held + 1 end end
    return ("queue %s left=%d held=%d far=%d"):format(label, b.left or 0, held, queue.far or 0)
end

-- The player's buffs, as the aura rule allows reading them; a buff with a secret field is left out
local function OwnBuffs()
    local okRead, readable = pcall(ns.Blessings.AurasReadable)
    if not (okRead and readable) then return "unreadable" end
    local parts = {}
    local GetAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i = 1, 40 do
        local ok, aura = pcall(GetAura, "player", i, "HELPFUL")
        if not ok or not aura then break end
        local id = ns.Blessings.SpellOf(aura)
        if id then
            local e = aura.expirationTime
            local left = type(e) == "number" and e > 0 and math.floor((e - GetTime()) / 60 + 0.5) .. "m" or "-"
            parts[#parts + 1] = tostring(id) .. ":" .. left
        end
    end
    return table.concat(parts, " ")
end

local function GroupLine()
    local kind = IsInRaid() and "raid" or IsInGroup() and "party" or "solo"
    local units, size = { "player" }, 1
    if IsInRaid() then
        size = GetNumGroupMembers()
        units = {}
        for i = 1, size do units[i] = "raid" .. i end
    elseif IsInGroup() then
        size = GetNumSubgroupMembers() + 1
        for i = 1, size - 1 do units[#units + 1] = "party" .. i end
    end
    local byClass, classes = {}, {}
    for _, u in ipairs(units) do
        local _, class = UnitClass(u)
        if not issecretvalue(class) and class then
            if not byClass[class] then classes[#classes + 1] = class end
            byClass[class] = (byClass[class] or 0) + 1
        end
    end
    table.sort(classes)
    local parts = {}
    for _, c in ipairs(classes) do parts[#parts + 1] = c .. "=" .. byClass[c] end
    return ("group %s size=%d %s"):format(kind, size, table.concat(parts, " "))
end

local function YesNo(v) return v and "yes" or "no" end

function ns.StateSnapshot()
    local lines = {}
    local buttons = { AURA = ns.auraButton, FURY = ns.furyButton, BLESSING = ns.blessingButton,
        SALVATION = ns.salvationButton }
    for _, key in ipairs(D.DEFAULT_ORDER) do lines[#lines + 1] = ButtonLine(key, buttons[key]) end
    for _, b in ipairs({ ns.buffKey, SmartBlessingBarBuffRun }) do
        lines[#lines + 1] = ButtonLine(b:GetName(), b)
    end
    lines[#lines + 1] = QueueLine("BLESSING", ns.blessingButton)
    lines[#lines + 1] = QueueLine("SALVATION", ns.salvationButton)
    lines[#lines + 1] = "symbols " .. tostring(C_Item.GetItemCount(D.SYMBOL_OF_KINGS) or 0)
    lines[#lines + 1] = GroupLine()
    lines[#lines + 1] = "buffs " .. OwnBuffs()
    local okRead, readable = pcall(ns.Blessings.AurasReadable)
    lines[#lines + 1] = "auras readable=" .. (okRead and YesNo(readable) or "?")
    lines[#lines + 1] = "snapshots " .. ns.Blessings.KeptCount()
    lines[#lines + 1] = "demo " .. YesNo(ns.IsDemo())
    lines[#lines + 1] = "keydown " .. tostring(GetCVar("ActionButtonUseKeyDown"))
    lines[#lines + 1] = "combat " .. YesNo(InCombatLockdown())
    return lines
end

-- Loaded addons by folder name - the title may carry colour codes - and declared version
function ns.AddonList()
    local lines, extra = {}, 0
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(i) then
            if #lines < MAX_ADDONS then
                local name = C_AddOns.GetAddOnInfo(i)
                lines[#lines + 1] = name .. " " .. tostring(C_AddOns.GetAddOnMetadata(name, "Version") or "?")
            else
                extra = extra + 1
            end
        end
    end
    if extra > 0 then lines[#lines + 1] = ("... %d more"):format(extra) end
    return lines
end

---------------------------------------------------------------------------
-- Report content
---------------------------------------------------------------------------
-- This addon's errors of the current session from BugGrabber (the error collector BugSack
-- builds on), newest first. Errors of earlier sessions come from BugGrabber's saved data and
-- stay out; without a session number, an error from before this addon loaded counts as one of an earlier session.
-- BugGrabber is optional (project.md), and its data comes from outside: checked here.
local function CollectErrors()
    local list = {}
    local grabber = BugGrabber
    if not (grabber and grabber.GetDB) then return list, false end
    local ok, errors = pcall(grabber.GetDB, grabber)
    if not ok or type(errors) ~= "table" then return list, true end
    local okSession, session = pcall(function() return grabber.GetSessionId and grabber:GetSessionId() end)
    if not okSession then session = nil end
    for i = #errors, 1, -1 do
        local e = errors[i]
        if type(e) == "table" then
            local current
            if type(session) == "number" and type(e.session) == "number" then
                current = e.session == session
            else
                current = type(e.time) == "number" and e.time >= ns.logStartClock
            end
            local text = tostring(e.message or "") .. "\n" .. tostring(e.stack or "")
            if current and text:find(ns.ADDON_NAME, 1, true) then
                list[#list + 1] = e
                if #list >= MAX_ERRORS then break end
            end
        end
    end
    return list, true
end

-- The first lines of a text, each with the tag of its report field and filtered
local function FirstLines(text, max, tag, names)
    local out, n = {}, 0
    for line in tostring(text or ""):gmatch("[^\n]+") do
        n = n + 1
        if n > max then out[#out + 1] = tag .. " ..." break end
        out[#out + 1] = tag .. " " .. ns.Scrub(line, names)
    end
    return out
end

-- When an error came, relative only - no date or clock in a report - and whether in combat
local function ErrorWhen(e)
    if type(e.time) ~= "number" then return "time unknown", "unknown" end
    local when = ("%d min ago"):format(math.floor((time() - e.time) / 60 + 0.5))
    local since = e.time - ns.logStartClock
    if since >= 0 then when = when .. (", %d s after load"):format(since) end
    return when, ns.CombatAt(e.time)
end

local function OrDash(s) return (s and s ~= "") and s or "-" end

-- A list of keys, each by allowlist
local function KeyList(list)
    local out = {}
    for i, key in ipairs(list) do out[i] = ns.SafeValue(key) end
    return table.concat(out, ">")
end

-- The settings the addon knows, sorted by name, values by allowlist; a key it does not know is
-- left out (it could hold anything). Tables are summarized, colors left out.
local SETTINGS_EXTRA = { "locked", "point", "rel", "dbVersion" }
local function SettingsText()
    if not db then return "(not loaded)" end
    local keys = {}
    for k in pairs(D.BOOL_DEFAULTS) do keys[#keys + 1] = k end
    for k in pairs(D.NUMBER_DEFAULTS) do keys[#keys + 1] = k end
    for _, k in ipairs(SETTINGS_EXTRA) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = db[k]
        local t = type(v)
        if t == "number" or t == "boolean" or t == "string" then parts[#parts + 1] = k .. "=" .. ns.SafeValue(v) end
    end
    if type(db.order) == "table" then parts[#parts + 1] = "order=" .. KeyList(db.order) end
    if type(db.auraList) == "table" then parts[#parts + 1] = "auraList=" .. KeyList(db.auraList) end
    if type(db.classLists) == "table" then
        local lists = {}
        for _, class in ipairs(D.CLASS_ORDER) do
            local entry = db.classLists[class]
            if type(entry) == "table" and type(entry.order) == "table" then
                lists[#lists + 1] = class .. ":" .. KeyList(entry.order)
            end
        end
        parts[#parts + 1] = "classLists=" .. table.concat(lists, "/")
    end
    return table.concat(parts, ", ")
end

-- The level in a band of ten: enough for ranks, too coarse to tell a character apart
local function LevelBand()
    local level = UnitLevel("player")
    if issecretvalue(level) then level = 0 end
    local low = math.floor((tonumber(level) or 0) / 10) * 10
    return ("%d-%d"):format(low, low + 9)
end

-- Every line belongs to a field of D.REPORT_FIELDS (Privacy.lua). form: { description, area (a
-- key of D.REPORT_AREAS), details }. nil while a name is secret: a name that cannot be compared
-- cannot be filtered, so no report at all, not one without the filter.
function ns.BuildReport(form)
    form = form or {}
    ns.LogSettings()
    local names = ns.KnownNames()
    if not names then return nil end
    local version, build, _, interface = GetBuildInfo()
    local _, classFile = UnitClass("player")
    if issecretvalue(classFile) then classFile = "UNKNOWN" end
    local lines = {
        "## SmartBlessingBar bug report",
        "",
        "**Description:** " .. OrDash(ns.Scrub(form.description, names)),
        "**Area:** " .. (form.area or "OTHER"),
        "**Details:** " .. OrDash(ns.Scrub(form.details, names)),
        "",
        "- Addon version: " .. ns.VERSION,
        "- Client: " .. tostring(version) .. " (build " .. tostring(build) .. ", interface " .. tostring(interface) .. ")",
        "- Client locale: " .. tostring(GetLocale()) .. ", addon language: "
            .. ns.SafeValue(SmartBlessingBarGlobalDB.language or "auto"),
        "- Character: " .. tostring(classFile) .. ", level " .. LevelBand()
            .. (IsInRaid() and ", raid" or IsInGroup() and ", party" or ", solo"),
        "- Settings: " .. SettingsText(),
        "",
    }
    local errors, hasGrabber = CollectErrors()
    if not hasGrabber then
        lines[#lines + 1] = "**Lua errors:** BugGrabber/BugSack not installed"
    elseif #errors == 0 then
        lines[#lines + 1] = "**Lua errors:** none from SmartBlessingBar in this session"
    else
        lines[#lines + 1] = "**Lua errors (newest first):**"
        for i, e in ipairs(errors) do
            local when, combat = ErrorWhen(e)
            lines[#lines + 1] = ""
            lines[#lines + 1] = ("Error %d (x%d, %s, combat: %s):"):format(i, tonumber(e.counter) or 1, when, combat)
            lines[#lines + 1] = "```"
            for _, l in ipairs(FirstLines(e.message, 6, "msg", names)) do lines[#lines + 1] = l end
            for _, l in ipairs(FirstLines(e.stack, MAX_STACK_LINES, "at", names)) do lines[#lines + 1] = l end
            for _, l in ipairs(ns.SafeLocals(e.locals, names)) do lines[#lines + 1] = "local " .. l end
            lines[#lines + 1] = "```"
        end
    end
    local function Block(title, tag, list, scrub)
        lines[#lines + 1] = ""
        lines[#lines + 1] = title
        lines[#lines + 1] = "```"
        for _, l in ipairs(list) do lines[#lines + 1] = tag .. " " .. (scrub and ns.Scrub(l, names) or l) end
        lines[#lines + 1] = "```"
    end
    Block("**Last actions (seconds since load):**", "log", ns.LogLines())
    Block("**State:**", "state", ns.StateSnapshot())
    Block("**Loaded addons:**", "addon", ns.AddonList(), true)
    return ns.CapReport(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local frame
local MAX_TEXT = 500 -- letters of the description and of the details

-- The areas a report offers: not Salvation while the client has no such spell
function ns.ReportAreas()
    local out = {}
    for _, key in ipairs(D.REPORT_AREAS) do
        if key ~= "SALVATION" or ns.Blessings.Exists(D.SALVATION) then out[#out + 1] = key end
    end
    return out
end

-- The text of an area: most areas are parts of the addon that already have a name
local AREA_KEYS = { BLESSINGS = "BTN_BLESSINGS", SALVATION = "SALVATION", AURA = "TRACK_AURA",
    FURY = "RIGHTEOUS_FURY", BUFF_RUN = "BUFF_RUN", PRIORITIES = "TAB_PRIORITIES",
    SUPPLIES = "TAB_SUPPLIES", SETTINGS = "SETTINGS" }
function ns.ReportAreaText(key)
    return L[AREA_KEYS[key] or ("AREA_" .. key)]
end

-- The box shows the code, selected for Ctrl+C, or - "Show content" - the readable report,
-- never selected, so what gets copied is the code
local function Shown() return frame.showContent and frame.reportText or frame.codeText end

local function MarkSelection()
    if frame.showContent then frame.report:HighlightText(0, 0) else frame.report:HighlightText() end
end

local function SelectReport()
    frame.report:SetFocus()
    MarkSelection()
end

local function ShowBox()
    frame.report:SetText(Shown())
    frame.report:SetCursorPosition(0)
    MarkSelection()
    SetL(frame.toggle, frame.showContent and "REPORT_SHOW_CODE" or "REPORT_SHOW_CONTENT")
end

local function FormValues()
    return { description = frame.desc:GetText(), area = frame.area, details = frame.details:GetText() }
end

-- Each keystroke rebuilds the report; while a name is secret the last clean one stays, and the
-- chat says so once, not on every key
local function Refresh()
    local text = ns.BuildReport(FormValues())
    if not text then
        if not frame.secretSaid then ns.Print(L.REPORT_SECRET) end
        frame.secretSaid = true
        return
    end
    frame.secretSaid = false
    frame.reportText = text
    frame.codeText = ns.ReportCode.Encode(text)
    ShowBox()
end

-- A one-line text field: typing rebuilds the report, Enter selects it for copying
local function AddInput(anchor, width)
    local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 6, -4)
    box:SetSize(width, 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(MAX_TEXT)
    box:SetScript("OnTextChanged", function(_, userInput) if userInput then Refresh() end end)
    box:SetScript("OnEnterPressed", SelectReport)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function AddText(anchor, font, key, width, gap)
    local text = frame:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
    if width then
        text:SetWidth(width)
        text:SetJustifyH("LEFT")
    end
    SetL(text, key)
    return text
end

local function CreateWindow()
    local W, H, PAD = 520, 580, 22
    frame = CreateFrame("Frame", "SmartBlessingBarReport", UIParent, "BackdropTemplate")
    ns.reportWindow = frame
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    ns.AddOpacityLayer(frame)
    tinsert(UISpecialFrames, "SmartBlessingBarReport") -- closes with Escape

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    SetL(title, "REPORT_TITLE")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- What the report holds and never holds, and that an issue is public (ruleset plan
    -- 2026-10-24-bug-report)
    local top = CreateFrame("Frame", nil, frame)
    top:SetPoint("TOPLEFT", PAD, -40)
    top:SetSize(1, 1)
    frame.privacy = AddText(top, "GameFontHighlightSmall", "REPORT_PRIVACY", W - 2 * PAD, 0)
    frame.public = AddText(frame.privacy, "GameFontNormalSmall", "REPORT_PUBLIC", W - 2 * PAD, -4)

    -- Step 1: what happened, where (a list, so the developer knows where to look), details
    local step1 = AddText(frame.public, "GameFontHighlight", "REPORT_STEP1", nil, -10)
    frame.desc = AddInput(step1, W - 2 * PAD - 6)

    local where = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    where:SetPoint("TOPLEFT", frame.desc, "BOTTOMLEFT", -6, -14)
    SetL(where, "REPORT_WHERE")
    frame.area = "OTHER"
    local menu = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    menu:SetPoint("LEFT", where, "RIGHT", 12, 0)
    menu:SetWidth(240)
    menu:SetupMenu(function(_, root)
        for _, key in ipairs(ns.ReportAreas()) do
            root:CreateRadio(ns.ReportAreaText(key), function() return frame.area == key end,
                function() frame.SetArea(key) end)
        end
    end)
    frame.areaMenu = menu
    function frame.SetArea(key)
        frame.area = key
        menu:GenerateMenu()
        Refresh()
    end
    -- The dropdown shows its selection's text as of its last generation: regenerated so a
    -- language switch does not keep the old language's word (as in SimpleConjureBar)
    ns.OnLanguageChanged(function() menu:GenerateMenu() end)

    local detailsLabel = AddText(where, "GameFontHighlight", "REPORT_DETAILS", nil, -16)
    frame.details = AddInput(detailsLabel, W - 2 * PAD - 6)

    -- Step 2: the report, selected for Ctrl+C (read-only)
    local step2 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step2:SetPoint("TOPLEFT", frame.details, "BOTTOMLEFT", -6, -12)
    SetL(step2, "REPORT_STEP2")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, 92)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", scroll, -4, 4)
    bg:SetPoint("BOTTOMRIGHT", scroll, 24, -4)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local report = CreateFrame("EditBox", nil, scroll)
    report:SetMultiLine(true)
    report:SetAutoFocus(false)
    report:SetFontObject("ChatFontNormal")
    report:SetWidth(W - 2 * PAD - 30)
    report:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    report:SetScript("OnEditFocusGained", MarkSelection)
    -- Read-only: user edits are undone right away, back to what the box shows
    report:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(Shown() or "")
            MarkSelection()
        end
    end)
    scroll:SetScrollChild(report)
    frame.report = report

    -- Step 3: where to paste it
    local step3 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step3:SetPoint("BOTTOMLEFT", PAD, 66)
    step3:SetPoint("RIGHT", -PAD, 0)
    step3:SetJustifyH("LEFT")
    SetL(step3, "REPORT_STEP3")
    local url = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    url:SetPoint("BOTTOMLEFT", PAD + 6, 40)
    url:SetSize(W - 2 * PAD - 6, 22)
    url:SetAutoFocus(false)
    url:SetText(D.BUG_REPORT_URL)
    url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    url:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(D.BUG_REPORT_URL) self:HighlightText() end
    end)
    url:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetSize(120, 22)
    done:SetPoint("BOTTOMRIGHT", -PAD, 16)
    SetL(done, "CLOSE")
    done:SetScript("OnClick", function() frame:Hide() end)

    local toggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggle:SetSize(160, 22)
    toggle:SetPoint("BOTTOMLEFT", PAD, 16)
    toggle:SetScript("OnClick", function()
        frame.showContent = not frame.showContent
        ShowBox()
    end)
    frame.toggle = toggle

    -- Built out of combat only: names and auras are readable then. The window closes when
    -- combat starts and comes back after it, as the settings window does.
    frame:SetScript("OnShow", function()
        if InCombatLockdown() then
            frame:Hide()
            ns.Print(L.REPORT_COMBAT)
            return
        end
        -- A secret name could not be filtered: no report until it is readable again
        if not ns.KnownNames() then
            frame:Hide()
            ns.Print(L.REPORT_SECRET)
            return
        end
        -- also when the background was set while the window was closed
        ns.ApplyWindowOpacity(frame)
        Refresh()
        SelectReport()
    end)
    local reopen = false
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if frame:IsShown() then reopen = true; frame:Hide() end
        elseif reopen then
            reopen = false
            C_Timer.After(0, function() frame:Show() end)
        end
    end)
    function frame.BuildText() return ns.BuildReport(FormValues()) end
    frame:Hide()
end

-- The report window replaces the settings window
function ns.OpenBugReport()
    if not frame then CreateWindow() end
    ns.CloseSettings()
    frame.desc:SetText("")
    frame.details:SetText("")
    frame.area = "OTHER"
    frame.areaMenu:GenerateMenu()
    frame.showContent = false
    if frame:IsShown() then Refresh() SelectReport() else frame:Show() end
end
