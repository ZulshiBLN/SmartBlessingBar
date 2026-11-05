-- SmartBlessingBar - settings window framework
-- The window, its layout system and the reusable widgets, after SimpleConjureBar's. The pages
-- themselves are built in SettingsPages.lua with the helpers exported as ns.UI.
--
-- Layout system: every widget registers
--   refreshers - load the values from the settings into the widget (on show and language change)
--   measures   - return the content width the widget needs (texts differ per language)
--   stretchers - fit the widget to the final content width
-- so the window always fits its content in every language.

local _, ns = ...
if not ns.enabled then return end

local D, L = ns.D, ns.L
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

local UI = {}
ns.UI = UI

local settings = CreateFrame("Frame", "SmartBlessingBarSettings", UIParent, "BackdropTemplate")
UI.window = settings
settings:SetSize(300, 290)
settings:SetPoint("CENTER")
settings:SetFrameStrata("DIALOG")
settings:SetMovable(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", settings.StartMoving)
settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
settings:SetClampedToScreen(true)
settings:Hide()
settings:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
ns.AddOpacityLayer(settings)
tinsert(UISpecialFrames, "SmartBlessingBarSettings") -- closes with Escape

-- The dialog border is about 12 px wide, plus 10 px space to the content
local INSET = 22
local MIN_W = 240
local TOP_Y = -84 -- below the title and the tabs
UI.INSET = INSET

local refreshers, measures, stretchers = {}, {}, {}
UI.refreshers, UI.measures, UI.stretchers = refreshers, measures, stretchers

---------------------------------------------------------------------------
-- Pages (tabs): every page has its own placement cursor
---------------------------------------------------------------------------
local pages, page = {}, nil
UI.pages = pages

function UI.NewPage(titleKey)
    local pg = CreateFrame("Frame", nil, settings)
    pg:SetPoint("TOPLEFT")
    pg:SetPoint("BOTTOMRIGHT")
    pg:Hide()
    pg.cursorY, pg.titleKey = TOP_Y, titleKey
    pages[#pages + 1] = pg
    page = pg
    return pg
end

-- Reserves vertical space on the current page and returns its top offset
function UI.Place(height, gap)
    local y = page.cursorY
    page.cursorY = page.cursorY - height - (gap or 6)
    return y
end

---------------------------------------------------------------------------
-- Title with version, close button
---------------------------------------------------------------------------
local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("SmartBlessingBar")

-- Version slightly smaller and white right after the title
local titleVersion = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
titleVersion:SetText("v" .. ns.VERSION)
titleVersion:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)

-- Center title and version together
local function PlaceTitle()
    local shift = (titleVersion:GetStringWidth() + 6) / 2
    title:ClearAllPoints()
    title:SetPoint("TOP", settings, "TOP", -math.floor(shift), -18)
end
PlaceTitle()
-- Leave room for the close button on both sides of the centered title
measures[#measures + 1] = function()
    PlaceTitle()
    return title:GetStringWidth() + 6 + titleVersion:GetStringWidth() + 2 * 34
end

local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local Place = UI.Place

-- Check box with label, bound to a boolean setting. Shared by all check box widgets.
local function CreateCheck(parent, labelKey, key, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    SetL(text, labelKey)
    cb:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(db[key]) end
    return cb, text
end

-- Single check box in its own row; `indent` moves it right by that many check box widths,
-- under the box it depends on
function UI.AddCheck(labelKey, key, onChange, indent)
    local cb, text = CreateCheck(page, labelKey, key, onChange)
    local x = INSET - 3 + (indent or 0) * 26
    cb:SetPoint("TOPLEFT", x, Place(26, 2))
    measures[#measures + 1] = function() return x - INSET + 26 + 4 + text:GetStringWidth() end
    return cb
end

-- Several check boxes next to each other. items = { { label =, key =, onChange = }, ... }
function UI.AddCheckRow(items)
    local ROW, SPACING = 26, 24
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", INSET - 3, Place(ROW, 2))
    local parts, checks = {}, {}
    for _, it in ipairs(items) do
        local cb, text = CreateCheck(row, it.label, it.key, it.onChange)
        parts[#parts + 1] = { cb = cb, text = text }
        checks[#checks + 1] = cb
    end
    local function Arrange()
        local x = 0
        for _, p in ipairs(parts) do
            p.cb:ClearAllPoints()
            p.cb:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + 26 + 4 + p.text:GetStringWidth() + SPACING
        end
        row.needW = x - SPACING - 3
    end
    refreshers[#refreshers + 1] = Arrange
    measures[#measures + 1] = function() return row.needW or 0 end
    stretchers[#stretchers + 1] = function(w) row:SetWidth(w + 3) end
    return unpack(checks)
end

-- Section header in Blizzard gold. labelKey: locale key or a function (see ns.SetL).
local HEADER_SIZE = 14
function UI.AddHeader(labelKey, gap)
    local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
    h:SetTextColor(1, 0.82, 0)
    h:SetPoint("TOPLEFT", INSET, Place(HEADER_SIZE + 4, (gap or 8) + 4))
    SetL(h, labelKey)
    measures[#measures + 1] = function() return h:GetStringWidth() end
    return h
end

-- Small explanatory text in its own row. lines: number of lines (texts use "\n" breaks)
function UI.AddNote(labelKey, gap, lines)
    local t = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetJustifyH("LEFT")
    t:SetPoint("TOPLEFT", INSET, Place(12 * (lines or 1) + 2 * ((lines or 1) - 1), gap or 8))
    SetL(t, labelKey)
    measures[#measures + 1] = function() return t:GetStringWidth() end
    return t
end

-- Plain slider without template
function UI.MakeSlider(parent)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetHeight(12)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(6)
    track:SetColorTexture(0.25, 0.25, 0.25, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(1, 0.82, 0, 1) -- WoW gold
    slider:SetThumbTexture(thumb)
    slider:EnableMouseWheel(true)
    return slider
end

-- Whole-number slider bound to a setting, with label and value text. fmt(v) returns the
-- shown value; onChange runs after every change. Returns the slider and its row.
function UI.AddIntSlider(labelKey, key, minV, maxV, fmt, onChange, gap)
    local ROW = 36
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", INSET, Place(ROW, gap or 14))

    local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 0, 0)
    SetL(t, labelKey)
    local value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    value:SetPoint("TOPRIGHT", 0, 0)

    local slider = UI.MakeSlider(row)
    slider:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 2, -10)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    -- Tick marks for every step when there are only a few (e.g. 1-5)
    local ticks = {}
    if maxV - minV <= 10 then
        for _ = minV, maxV do
            local tk = slider:CreateTexture(nil, "BORDER")
            tk:SetSize(2, 10)
            tk:SetColorTexture(0.5, 0.5, 0.5, 1)
            ticks[#ticks + 1] = tk
        end
    end

    slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        db[key] = v
        value:SetText(fmt(v))
        if onChange then onChange() end
    end)
    slider:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta) end)

    refreshers[#refreshers + 1] = function()
        slider:SetValue(db[key])
        value:SetText(fmt(db[key]))
    end
    measures[#measures + 1] = function() return t:GetStringWidth() + 16 + math.max(30, value:GetStringWidth()) end
    stretchers[#stretchers + 1] = function(w)
        row:SetWidth(w)
        local sw = w - 4
        slider:SetWidth(sw)
        for i, tk in ipairs(ticks) do
            tk:ClearAllPoints()
            tk:SetPoint("CENTER", slider, "LEFT", 5 + (i - 1) * (sw - 10) / (#ticks - 1), 0)
        end
    end
    return slider, row, value
end

-- Whole-number slider with an input box on the right, bound to a number setting with its
-- range from D.NUMBER_DEFAULTS. o = { label, key, gap, rows (collects the row frames),
-- onChange, column }. `column` "left" or "right" puts two sliders side by side in one row,
-- each half as wide, the right one after the left (ruleset plan 2026-10-20-fury-renew).
-- Returns the slider, the box and the row (its label as row.label).
local COLUMN_GAP = 20
UI.COLUMN_GAP = COLUMN_GAP -- the General tab's Scale row lays out its column with it

-- The page being built, for a row laid out by hand as a left column
function UI.CurrentPage() return page end

function UI.AddNumberSlider(o)
    local range = D.NUMBER_DEFAULTS[o.key]
    local ROW = 42
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW)
    local y
    if o.column == "right" then
        y = page.columnY -- the left column's row
    else
        y = Place(ROW, o.gap or 6)
        page.columnY = y
    end
    row:SetPoint("TOPLEFT", INSET, y)
    if o.rows then o.rows[#o.rows + 1] = row end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 0, -4)
    SetL(label, o.label)
    row.label = label

    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("TOPRIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(#tostring(range.max))
    box:SetJustifyH("CENTER")

    local slider = UI.MakeSlider(row)
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -28)
    slider:SetMinMaxValues(range.min, range.max)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local updating = false
    local function SetValue(v)
        v = math.max(range.min, math.min(range.max, math.floor(v + 0.5)))
        db[o.key] = v
        updating = true
        slider:SetValue(v)
        updating = false
        box:SetText(tostring(v))
        if o.onChange then o.onChange() end
    end
    slider:SetScript("OnValueChanged", function(_, v)
        if not updating then SetValue(v) end
    end)
    slider:SetScript("OnMouseWheel", function(_, delta) SetValue(db[o.key] + delta) end)

    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then SetValue(v) else self:SetText(tostring(db[o.key])) end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db[o.key]))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self) self:SetText(tostring(db[o.key])) end)

    refreshers[#refreshers + 1] = function()
        updating = true
        slider:SetValue(db[o.key])
        updating = false
        box:SetText(tostring(db[o.key]))
    end
    -- A column needs room for two halves its width, so no label in either is cut
    measures[#measures + 1] = function()
        local need = label:GetStringWidth() + 16 + 40
        if o.column then return 2 * need + COLUMN_GAP end
        return need
    end
    stretchers[#stretchers + 1] = function(w)
        local rowW = o.column and (w - COLUMN_GAP) / 2 or w
        row:SetWidth(rowW)
        slider:SetWidth(rowW - 4)
        if o.column == "right" then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", INSET + (w + COLUMN_GAP) / 2, y)
        end
    end
    return slider, box, row
end

-- A highlight's speed, 5 steps, 3 = default; a change shows at once (ns.ApplyLook sets the
-- glow's duration)
function UI.AddSpeedSlider(key)
    return UI.AddIntSlider("OPT_ANTS_SPEED", key, D.ANTS_SPEED_MIN, D.ANTS_SPEED_MAX, function(v)
        return v == D.NUMBER_DEFAULTS[key].default and (v .. " (" .. L.DEFAULT .. ")") or tostring(v)
    end, ns.ApplyLook)
end

-- Centered separator line in WoW style: 2 px gold, strong in the middle, fading to the ends.
-- PixelUtil snaps it to real screen pixels, so all lines look equally thick.
local SEP_HEIGHT = 2
local SEP_R, SEP_G, SEP_B = 1, 0.82, 0
function UI.AddSeparator()
    local y = Place(SEP_HEIGHT, 10)
    page.cursorY = page.cursorY - 4 -- some air above and below the line
    y = math.floor(y - 4)
    local left = page:CreateTexture(nil, "ARTWORK")
    local right = page:CreateTexture(nil, "ARTWORK")
    local halves = { left, right }
    for _, tex in ipairs(halves) do
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetSnapToPixelGrid(true)
        tex:SetTexelSnappingBias(0)
    end
    left:SetPoint("TOPRIGHT", page, "TOP", 0, y)
    right:SetPoint("TOPLEFT", page, "TOP", 0, y)
    local edge, mid = CreateColor(SEP_R, SEP_G, SEP_B, 0), CreateColor(SEP_R, SEP_G, SEP_B, 0.9)
    left:SetGradient("HORIZONTAL", edge, mid)
    right:SetGradient("HORIZONTAL", mid, edge)
    stretchers[#stretchers + 1] = function(w)
        local half = math.floor(w * 0.4)
        for _, tex in ipairs(halves) do PixelUtil.SetSize(tex, half, SEP_HEIGHT) end
    end
    return halves
end

-- Dropdown with the label on the left and the selection on the right, the client's menu
-- dropdown. options = { { value =, text = function }, ... }. Returns its refresh function.
local DD_WIDTH = 180
-- Room a dropdown keeps beside its text: the text inset and the arrow
local DD_TEXT_PAD = 50
function UI.AddDropdown(labelKey, options, get, set)
    local ROW = 28
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", INSET, Place(ROW, 6))

    local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", 0, 0)
    SetL(t, labelKey)

    -- Entry lengths differ per language ("简体中文 (Chinese S.)" was cut short at a fixed
    -- 180 px in SimpleConjureBar), so the dropdown grows to its longest entry.
    local width = DD_WIDTH
    local probe = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    probe:Hide()

    local dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dd:SetWidth(DD_WIDTH)
    dd:SetPoint("RIGHT", 0, 0)
    -- SetupMenu builds the menu at once, but the settings exist only after login, so it is
    -- set up when the window is shown for the first time.
    local isSetup = false
    local function refresh()
        if not db then return end
        local font = dd.Text and dd.Text:GetFontObject()
        if font then probe:SetFontObject(font) end
        local widest = 0
        for _, opt in ipairs(options) do
            probe:SetText(opt.text())
            widest = math.max(widest, probe:GetStringWidth())
        end
        width = math.max(DD_WIDTH, math.ceil(widest) + DD_TEXT_PAD)
        dd:SetWidth(width)
        if not isSetup then
            isSetup = true
            dd:SetupMenu(function(_, root)
                for _, opt in ipairs(options) do
                    root:CreateRadio(opt.text(),
                        function() return db and get() == opt.value end,
                        function() set(opt.value) end)
                end
            end)
        else
            dd:GenerateMenu()
        end
    end
    row.dropdown = dd

    refreshers[#refreshers + 1] = refresh
    measures[#measures + 1] = function() return t:GetStringWidth() + 16 + width end
    stretchers[#stretchers + 1] = function(w) row:SetWidth(w) end
    return refresh, dd
end

-- Push button sized to its (localized) text
function UI.AddButton(parent, labelKey, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetHeight(22)
    SetL(b, labelKey)
    b:SetScript("OnClick", onClick)
    local function Fit() b:SetWidth(b:GetFontString():GetStringWidth() + 30) end
    Fit()
    refreshers[#refreshers + 1] = Fit
    return b
end

---------------------------------------------------------------------------
-- Color picker (the client's ColorPickerFrame)
---------------------------------------------------------------------------
-- After a color changes: the look, the Symbol count, and whatever the caller adds. The picker
-- calls back on every mouse move while dragging, so nothing here plans the group.
local function ColorChanged(onChange)
    ns.ApplyLook()
    ns.RefreshSymbols()
    if onChange then onChange() end
end

-- "Default" button right below the color picker, only shown when this addon opened it
local defaultBtn = CreateFrame("Button", nil, ColorPickerFrame, "UIPanelButtonTemplate")
UI.colorDefault = defaultBtn
defaultBtn:SetSize(110, 22)
defaultBtn:SetPoint("TOP", ColorPickerFrame, "BOTTOM", 0, -2)
SetL(defaultBtn, "DEFAULT")
defaultBtn:Hide()
defaultBtn:SetScript("OnClick", function()
    local key = defaultBtn.key
    if not key then return end
    local d = D.COLOR_DEFAULTS[key]
    db[key] = ns.CopyColor(d)
    local cp = ColorPickerFrame.Content.ColorPicker
    cp:SetColorRGB(d.r, d.g, d.b)
    cp:SetColorAlpha(d.a)
    ColorChanged(defaultBtn.onChange)
end)
ColorPickerFrame:HookScript("OnHide", function() defaultBtn:Hide() end)

-- key: name of the color in the settings (e.g. "bg")
local function OpenColorPicker(key, onChange)
    local old = ns.CopyColor(db[key])
    local function Changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        db[key] = { r = r, g = g, b = b, a = ColorPickerFrame:GetColorAlpha() }
        ColorChanged(onChange)
    end
    local function Cancel()
        db[key] = old
        ColorChanged(onChange)
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = old.r, g = old.g, b = old.b, opacity = old.a, hasOpacity = true,
        swatchFunc = Changed, opacityFunc = Changed, cancelFunc = Cancel,
    })
    defaultBtn.key, defaultBtn.onChange = key, onChange
    defaultBtn:Show()
end

-- Color swatch button: a click opens the client's color picker (with the "Default" button)
local function CreateSwatchButton(parent, key, onChange)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(22, 22)
    swatch:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    swatch:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    local checker = swatch:CreateTexture(nil, "BACKGROUND")
    checker:SetPoint("TOPLEFT", 3, -3)
    checker:SetPoint("BOTTOMRIGHT", -3, 3)
    checker:SetColorTexture(1, 1, 1, 1)
    local color = swatch:CreateTexture(nil, "ARTWORK")
    color:SetAllPoints(checker)
    swatch.color = color

    local function Update()
        local c = db[key]
        color:SetColorTexture(c.r, c.g, c.b, c.a)
        if onChange then onChange() end
    end
    swatch:SetScript("OnClick", function() OpenColorPicker(key, Update) end)
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.OPT_BG_TIP)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", ns.HideTooltip)
    refreshers[#refreshers + 1] = function()
        local c = db[key]
        color:SetColorTexture(c.r, c.g, c.b, c.a)
    end
    return swatch
end

-- Color swatch with label in its own row
function UI.AddSwatch(labelKey, key, gap, onChange)
    local swatch = CreateSwatchButton(page, key, onChange)
    swatch:SetPoint("TOPLEFT", INSET, Place(22, gap or 6))
    local t = swatch:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    SetL(t, labelKey)
    measures[#measures + 1] = function() return 22 + 8 + t:GetStringWidth() end
    return swatch
end

-- One row: optional check box followed by any number of color swatches.
-- colors = { { label = key, key = dbKey }, ... }. Returns the check box and the swatches.
function UI.AddToggleColorRow(checkLabelKey, checkKey, onChange, colors)
    local ROW, SPACING = 26, 18
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", INSET - 3, Place(ROW, 6))

    local cb, cbText
    if checkKey then
        cb, cbText = CreateCheck(row, checkLabelKey, checkKey, onChange)
        cb:SetPoint("LEFT", 0, 0)
    end

    local items, swatches = {}, {}
    for _, c in ipairs(colors) do
        local sw = CreateSwatchButton(row, c.key)
        local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", sw, "RIGHT", 6, 0)
        SetL(t, c.label)
        items[#items + 1] = { sw = sw, text = t }
        swatches[#swatches + 1] = sw
    end

    -- Positions depend on the text widths of the current language
    local function Arrange()
        local x = cbText and (26 + 4 + cbText:GetStringWidth() + SPACING) or 3
        for _, it in ipairs(items) do
            it.sw:ClearAllPoints()
            it.sw:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + 22 + 6 + it.text:GetStringWidth() + SPACING
        end
        row.needW = x - SPACING - 3
    end
    refreshers[#refreshers + 1] = Arrange
    measures[#measures + 1] = function() return row.needW or 0 end
    stretchers[#stretchers + 1] = function(w) row:SetWidth(w + 3) end
    return cb, swatches
end

---------------------------------------------------------------------------
-- Tabs and window layout (called by SettingsPages.lua once all pages exist)
---------------------------------------------------------------------------
local tabs, activePage = {}, 1
UI.tabs = tabs

local function ShowPage(i)
    activePage = i
    for k, pg in ipairs(pages) do
        local tb = tabs[k]
        if k == i then
            pg:Show()
            tb:LockHighlight()
            tb:GetFontString():SetTextColor(1, 0.82, 0)
        else
            pg:Hide()
            tb:UnlockHighlight()
            tb:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

-- Tabs next to each other, width by text
local function ArrangeTabs()
    local x = INSET
    for _, tb in ipairs(tabs) do
        tb:SetWidth(tb:GetFontString():GetStringWidth() + 24)
        tb:ClearAllPoints()
        tb:SetPoint("TOPLEFT", settings, "TOPLEFT", x, -46)
        x = x + tb:GetWidth() + 4
    end
    return x - 4 - INSET
end

-- Width and height follow the content (the tallest page sets the height)
local function LayoutSettings()
    local contentW = MIN_W
    for _, m in ipairs(measures) do contentW = math.max(contentW, math.ceil(m())) end
    for _, st in ipairs(stretchers) do st(contentW) end
    settings:SetWidth(contentW + 2 * INSET)
    local lowest = 0
    for _, pg in ipairs(pages) do lowest = math.min(lowest, pg.cursorY) end
    -- cursorY points below the last element; replace the last gap with the border
    settings:SetHeight(-lowest - 4 + INSET)
end

local function RefreshAll()
    for _, f in ipairs(refreshers) do f() end
    LayoutSettings()
    ShowPage(activePage)
end

function UI.CreateTabs()
    for i, pg in ipairs(pages) do
        local tb = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
        tb:SetHeight(22)
        SetL(tb, pg.titleKey)
        tb:SetScript("OnClick", function() ShowPage(i) end)
        tabs[i] = tb
    end
    measures[#measures + 1] = ArrangeTabs
end

ns.OnLanguageChanged(function()
    ArrangeTabs()
    if settings:IsShown() then RefreshAll() end
end)

---------------------------------------------------------------------------
-- Show / hide, combat handling
---------------------------------------------------------------------------
settings:SetScript("OnShow", function()
    -- Settings change the protected bar, so the window does not open in combat
    if InCombatLockdown() or not db then
        settings:Hide()
        if InCombatLockdown() then ns.Print(L.MENU_COMBAT) end
        return
    end
    ns.ApplyWindowOpacity(settings)
    RefreshAll()
end)

function ns.ToggleSettings()
    if settings:IsShown() then settings:Hide() else settings:Show() end
end

function ns.CloseSettings()
    settings:Hide()
end

-- Opens, never closes: from the client's options it is raised above them. The client's options
-- window is not touched - closing it from addon code risks taint.
function ns.OpenSettings(aboveClient)
    if aboveClient then settings:SetFrameStrata("FULLSCREEN_DIALOG") end
    if settings:IsShown() then settings:Raise() else settings:Show() end
end
settings:HookScript("OnHide", function() settings:SetFrameStrata("DIALOG") end)

-- The window on one tab, for the minimap button's middle click (ruleset plan
-- 2026-10-19-priorities)
local function PageIndex(titleKey)
    for i, pg in ipairs(pages) do
        if pg.titleKey == titleKey then return i end
    end
end

function ns.SettingsPageShown(titleKey)
    return settings:IsShown() and activePage == PageIndex(titleKey)
end

function ns.OpenSettingsOn(titleKey)
    ShowPage(PageIndex(titleKey))
    if not settings:IsShown() then settings:Show() end
end

-- Combat start: close the window, and reopen it afterwards if combat closed it
do
    local reopenAfterCombat = false
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if settings:IsShown() then
                reopenAfterCombat = true
                settings:Hide()
            end
        elseif reopenAfterCombat then
            reopenAfterCombat = false
            settings:Show()
        end
    end)
end
