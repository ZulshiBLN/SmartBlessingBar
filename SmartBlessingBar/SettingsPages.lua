-- SmartBlessingBar - settings pages
-- The pages of the settings window, built with the helpers of Settings.lua (ns.UI).

local _, ns = ...
if not ns.enabled then return end

local D, L, UI = ns.D, ns.L, ns.UI
local INSET, Place = UI.INSET, UI.Place
local refreshers, measures, stretchers = UI.refreshers, UI.measures, UI.stretchers

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
local general = UI.NewPage("TAB_GENERAL")
-- The page's controls by name, for the specs
local controls = {}
UI.controls = controls

-- Language: "Automatic" always follows the client language, otherwise a fixed choice
-- (saved account-wide)
do
    local opts = { { value = "auto", text = function()
        return L.LANG_AUTO:format(ns.LOCALE_NAMES[ns.clientLocale] or ns.clientLocale)
    end } }
    for _, code in ipairs(ns.LOCALE_ORDER) do
        opts[#opts + 1] = { value = code, text = function() return ns.LOCALE_NAMES[code] end }
    end
    controls.language = select(2, UI.AddDropdown("OPT_LANGUAGE", opts, function()
        return SmartBlessingBarGlobalDB.language or "auto"
    end, function(v)
        SmartBlessingBarGlobalDB.language = (v ~= "auto") and v or nil
        ns.ApplyLanguage(v == "auto" and ns.clientLocale or v)
    end))
end
controls.hideCombat, controls.hideMinimap = UI.AddCheckRow({
    { label = "OPT_HIDE_COMBAT",  key = "hideCombat",  onChange = function() ns.ApplyCombatHide() end },
    { label = "OPT_HIDE_MINIMAP", key = "hideMinimap", onChange = function() ns.ApplyMinimapButton() end },
})
UI.AddSeparator()

-- Scale: slider in 0.1 steps or number input (0.05 steps). It is the left column of its row;
-- the window background takes the right one (ruleset plan 2026-10-22-anchor-and-window-
-- background), so the row is laid out as UI.AddNumberSlider's columns are.
do
    local ROW = 42
    local row = CreateFrame("Frame", nil, general)
    row:SetHeight(ROW)
    local y = Place(ROW, 6)
    UI.CurrentPage().columnY = y
    row:SetPoint("TOPLEFT", INSET, y)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 0, -4)
    ns.SetL(label, "OPT_SCALE")

    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(44, 20)
    box:SetPoint("TOPRIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(4)
    box:SetJustifyH("CENTER")
    controls.scaleBox = box

    local slider = UI.MakeSlider(row)
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -28) -- level with the right column's slider
    slider:SetMinMaxValues(D.SCALE_MIN, D.SCALE_MAX)
    slider:SetValueStep(0.05) -- fine step, so typed 0.05 values stay where they are
    controls.scaleSlider = slider

    local function Round(v, step) return math.floor(v / step + 0.5) * step end
    local function Format(v) return (("%.2f"):format(v):gsub("0$", "")) end -- 1.00 -> 1.0, 1.05 stays

    local updating = false
    local function SetScaleValue(v, fromSlider)
        v = math.max(D.SCALE_MIN, math.min(D.SCALE_MAX, v))
        v = Round(v, fromSlider and 0.1 or 0.05)
        db.scale = tonumber(("%.2f"):format(v))
        updating = true
        slider:SetValue(db.scale)
        updating = false
        box:SetText(Format(db.scale))
        ns.ApplyScale()
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        SetScaleValue(v, true) -- dragging snaps to 0.1 steps
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        SetScaleValue(db.scale + delta * 0.1, true)
    end)

    local function ApplyBox(self)
        local text = (self:GetText() or ""):gsub(",", ".") -- allow a comma as decimal separator
        local v = tonumber(text)
        -- v == v rejects NaN
        if v and v == v then SetScaleValue(v, false) else self:SetText(Format(db.scale)) end
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", ApplyBox)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(Format(db.scale))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self) self:SetText(Format(db.scale)) end)

    refreshers[#refreshers + 1] = function()
        updating = true
        slider:SetValue(db.scale)
        updating = false
        box:SetText(Format(db.scale))
    end
    measures[#measures + 1] = function() return 2 * (label:GetStringWidth() + 16 + 44) + UI.COLUMN_GAP end
    stretchers[#stretchers + 1] = function(w)
        local rowW = (w - UI.COLUMN_GAP) / 2
        row:SetWidth(rowW)
        slider:SetWidth(rowW - 4)
    end
end

-- The settings and report windows' background, 0 % invisible to 100 % solid
controls.windowOpacity, controls.windowOpacityBox = UI.AddNumberSlider({
    label = "OPT_WINDOW_OPACITY", key = "windowOpacity", column = "right",
    onChange = function()
        ns.ApplyWindowOpacity(UI.window)
        ns.ApplyWindowOpacity(ns.reportWindow)
    end,
})

controls.border, controls.showAnchor = UI.AddCheckRow({
    { label = "OPT_BORDER",      key = "showBorder", onChange = function() ns.ApplyLook() end },
    { label = "OPT_SHOW_ANCHOR", key = "showAnchor", onChange = function() ns.ApplyAnchor() end },
})
controls.bg = UI.AddSwatch("OPT_BG", "bg", 8)
UI.AddSeparator()

-- Orientation and growth direction (anchor point of the bar)
local RefreshDirection
controls.layout = select(2, UI.AddDropdown("OPT_LAYOUT", {
    { value = false, text = function() return L.HORIZONTAL end },
    { value = true,  text = function() return L.VERTICAL end },
}, function() return db.vertical end, function(v)
    db.vertical = v
    -- The direction dropdown names its choices by orientation (right/left or down/up)
    if RefreshDirection then RefreshDirection() end
    ns.Refresh()
end))
RefreshDirection, controls.direction = UI.AddDropdown("OPT_DIRECTION", {
    { value = false, text = function() return (db and db.vertical) and L.DIR_DOWN or L.DIR_RIGHT end },
    { value = true,  text = function() return (db and db.vertical) and L.DIR_UP or L.DIR_LEFT end },
}, function() return db.growRev end, function(v)
    db.growRev = v
    ns.Refresh()
end)

UI.AddSeparator()

-- Demo mode and Buff & Run change the protected bar's buttons; neither can be switched in
-- combat, as the window closes at its start and does not open in it
controls.demo = UI.AddCheck("OPT_DEMO", "demo", function() ns.Refresh() end)

-- Buff & Run on the blessing button's middle click (ruleset plan 2026-10-20-buff-and-run), and
-- under it whether it blesses PvP-flagged players, dimmed while Buff & Run is off as the
-- auto-buy amounts are (ruleset plan 2026-10-20-performance-pvp)
local function DimPvpBlessing()
    controls.pvpBlessing:SetAlpha(db.buffRun and 1 or 0.4)
end
controls.buffRun = UI.AddCheck("OPT_BUFF_RUN", "buffRun", function()
    DimPvpBlessing()
    ns.Refresh()
end)
controls.pvpBlessing = UI.AddCheck("OPT_PVP_BLESSING", "pvpBlessing", nil, 1)
refreshers[#refreshers + 1] = DimPvpBlessing

-- Bottom row: "Report bug" left, "Reload UI" right (own translations, so they follow the language)
do
    local reload = UI.AddButton(general, "RELOAD_UI", function() ReloadUI() end)
    reload:SetPoint("BOTTOMRIGHT", general, "BOTTOMRIGHT", -INSET, INSET - 4)
    controls.reload = reload
    local bug = UI.AddButton(general, "BTN_REPORT_BUG", function() ns.OpenBugReport() end)
    bug:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", INSET, INSET - 4)
    controls.reportBug = bug
    measures[#measures + 1] = function() return bug:GetWidth() + 12 + reload:GetWidth() end
    -- Reserve the space, so the button never overlaps the last element
    Place(22, 8)
end

---------------------------------------------------------------------------
-- Tracking
---------------------------------------------------------------------------
UI.NewPage("TAB_TRACKING")
local function Refresh() ns.Refresh() end

controls.auraHeader = UI.AddHeader("TRACK_AURA", 6)
controls.showAura, controls.auraColor = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showAura", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "auraAntsColor" },
})
controls.auraSpeed = UI.AddSpeedSlider("auraAntsSpeed")
UI.AddSeparator()

-- Righteous Fury is a spell: the client names it (localization.md)
controls.furyHeader = UI.AddHeader(function()
    return ns.LocalName(C_Spell.GetSpellName(D.RIGHTEOUS_FURY), "RIGHTEOUS_FURY")
end, 6)
controls.showFury, controls.furyColor = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showFury", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "furyAntsColor" },
})
do
    local slider, _, value = UI.AddSpeedSlider("furyAntsSpeed")
    controls.furySpeed, controls.furySpeedText = slider, value
end
UI.AddSeparator()

-- The blessing button: shown or not, its ants, and the count color of both queue buttons
controls.blessingHeader = UI.AddHeader("BTN_BLESSINGS", 6)
controls.showBlessing, controls.blessingColors = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showBlessing", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "blessingAntsColor" },
    { label = "LBL_TEXT",      key = "countColor" },
})
controls.blessingSpeed = UI.AddSpeedSlider("blessingAntsSpeed")
controls.salvationLine = UI.AddSeparator()

-- The Salvation button; Salvation is a spell, so the client names it (localization.md)
local function SalvationTitle()
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION")
end
controls.salvationHeader = UI.AddHeader(SalvationTitle, 6)
controls.showSalvation, controls.salvationColors = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showSalvation", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "salvationAntsColor" },
})
controls.salvationSpeed = UI.AddSpeedSlider("salvationAntsSpeed")
-- All of it away while the client has no Salvation, back at the next opening once it has
-- (ruleset plan 2026-11-05-removed-spells)
refreshers[#refreshers + 1] = function()
    local exists = ns.Blessings.Exists(D.SALVATION)
    ns.SetL(controls.salvationHeader, SalvationTitle)
    for _, part in ipairs({ controls.salvationHeader, controls.showSalvation:GetParent(),
                            controls.salvationSpeed:GetParent(), unpack(controls.salvationLine) }) do
        part:SetShown(exists)
    end
end

-- Moves an entry among those of a saved list that `isShown`, from shown slot to shown slot;
-- the hidden ones keep their index, so a spell that returns takes its old place
local function MoveShown(list, isShown, from, to)
    local slots, entries = {}, {}
    for i, entry in ipairs(list) do
        if isShown(entry) then
            slots[#slots + 1] = i
            entries[#entries + 1] = entry
        end
    end
    table.insert(entries, to, table.remove(entries, from))
    for s, i in ipairs(slots) do list[i] = entries[s] end
end

---------------------------------------------------------------------------
-- Supplies: the Symbol of Kings count and the auto-buy
---------------------------------------------------------------------------
UI.NewPage("TAB_SUPPLIES")

-- An item name: the client names it (localization.md)
UI.AddHeader(function()
    return ns.LocalName(C_Item.GetItemNameByID(D.SYMBOL_OF_KINGS), "SYMBOL_OF_KINGS")
end, 6)
controls.symbolWarn, controls.symbolWarnBox = UI.AddNumberSlider({
    label = "OPT_SYMBOL_WARN", key = "symbolWarn", gap = 6, onChange = Refresh,
})
do
    local swatches = select(2, UI.AddToggleColorRow(nil, nil, nil, {
        { label = "LBL_WARNING", key = "symbolWarnColor" },
        { label = "LBL_EMPTY",   key = "symbolZeroColor" },
    }))
    controls.symbolWarnColor, controls.symbolZeroColor = swatches[1], swatches[2]
end
UI.AddSeparator()

-- Auto-buy: the amounts are dimmed while it is off
UI.AddHeader("AUTOBUY_HEADER", 6)
local amountRows = {}
local function ApplyAutoBuyState()
    for _, row in ipairs(amountRows) do row:SetAlpha(db.autoBuy and 1 or 0.4) end
end
controls.autoBuy = UI.AddCheck("OPT_AUTOBUY", "autoBuy", ApplyAutoBuyState)
refreshers[#refreshers + 1] = ApplyAutoBuyState
controls.symbolAmount = UI.AddNumberSlider({
    label = "OPT_SYMBOL_AMOUNT", key = "symbolAmount", gap = 6, rows = amountRows,
})
controls.goldReserve = UI.AddNumberSlider({
    label = "OPT_GOLD_RESERVE", key = "goldReserve", gap = 6, rows = amountRows,
})
controls.amountRows = amountRows

---------------------------------------------------------------------------
-- Priorities: the renewal, the aura list, a priority list per class in two columns and the
-- overview (ruleset plans 2026-10-19-blessing-steering, 2026-10-19-priorities,
-- 2026-10-19-tab-layout)
---------------------------------------------------------------------------
local prioritiesPage = UI.NewPage("TAB_PRIORITIES")

do
    local B = ns.Blessings

    -- The renewal times: blessings and Salvation left, Righteous Fury right (ruleset plan
    -- 2026-10-20-fury-renew); spell names from the client (localization.md)
    controls.renewTitle = UI.AddNote("RENEW_LABEL", 6)
    local function SpellName(id, key) return ns.LocalName(C_Spell.GetSpellName(id), key) end
    local function RenewLabel()
        if not B.Exists(D.SALVATION) then return L.BTN_BLESSINGS end
        return L.RENEW_BLESSINGS:format(SpellName(D.SALVATION, "SALVATION"))
    end
    local _
    controls.renewMinutes, _, controls.renewRow = UI.AddNumberSlider({
        label = RenewLabel,
        key = "renewMinutes", gap = 4, column = "left", onChange = function() ns.Refresh() end })
    controls.furyRenewMinutes, _, controls.furyRenewRow = UI.AddNumberSlider({
        label = function() return SpellName(D.RIGHTEOUS_FURY, "RIGHTEOUS_FURY") end,
        key = "furyRenewMinutes", column = "right", onChange = function() ns.Refresh() end })
    refreshers[#refreshers + 1] = function() ns.SetL(controls.renewRow.label, RenewLabel) end
    UI.AddSeparator()

    local ICON, ICON_GAP, LABEL_W, ROW_GAP = 24, 6, 90, 6
    local COL_W = LABEL_W + #D.BLESSING_ORDER * (ICON + ICON_GAP) + 16
    local LEFT_ROWS = 5 -- five classes left, four right
    local rows = {}
    controls.listRows = rows
    local RefreshLists
    local drag -- { row, index } while dragging

    -- The icons on a row: its entries that exist (the client may have removed a family), on
    local function OnEntries(row)
        local out = {}
        for _, family in ipairs(row.list().order) do
            if row.exists(family) then out[#out + 1] = family end
        end
        return out
    end

    -- The families a row shows: those on, in order, then those off in D.BLESSING_ORDER
    local function Shown(row)
        local out, list = OnEntries(row), row.list()
        for _, family in ipairs(D.BLESSING_ORDER) do
            if list.off[family] and row.exists(family) then out[#out + 1] = family end
        end
        return out
    end

    -- The slot under the cursor among the icons that are on
    local function SlotUnderCursor(row)
        local left = row.icons[1]:GetLeft()
        if not left then return end
        local cx = GetCursorPosition() / row.icons[1]:GetEffectiveScale()
        local slot = math.floor((cx - left) / (ICON + ICON_GAP)) + 1
        return math.max(1, math.min(#OnEntries(row), slot))
    end

    local function StopListDrag()
        if not drag then return end
        drag = nil
        prioritiesPage:SetScript("OnUpdate", nil)
        RefreshLists()
        ns.Refresh() -- the queue is rebuilt only once the icon is dropped
    end

    local function OnDragUpdate()
        -- Safety net: the mouse button was released outside the window
        if not IsMouseButtonDown("LeftButton") then StopListDrag() return end
        local row = rows[drag.row]
        local slot = SlotUnderCursor(row)
        if slot and slot ~= drag.index then
            MoveShown(row.list().order, row.exists, drag.index, slot)
            drag.index = slot
            RefreshLists()
        end
    end

    -- A right click switches a blessing off, greyed after the others, or on again, appended
    -- to the ones on. At least one stays on. Auras are only reordered (Michel, 2026-10-19).
    local function Toggle(row, family)
        if not row.switchable then return end
        local list = row.list()
        if list.off[family] then
            list.off[family] = nil
            table.insert(list.order, family)
        elseif #OnEntries(row) > 1 then
            for i, f in ipairs(list.order) do
                if f == family then table.remove(list.order, i) break end
            end
            list.off[family] = true
        end
        RefreshLists()
        ns.Refresh()
    end

    -- A row: `list()` gives { order, off }, `spells(family)` the family's spell IDs by rank.
    -- The caller places it.
    local function NewRow(r, count, label, list, spells, switchable, exists)
        local row = CreateFrame("Frame", nil, prioritiesPage)
        row:SetHeight(ICON)
        row.list, row.spells, row.switchable, row.labelText = list, spells, switchable, label
        row.exists = exists
        -- A row without a label (the aura row) starts its icons at its left edge
        if label then
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", 4, 0)
            row.label:SetWidth(LABEL_W)
            row.label:SetJustifyH("LEFT")
        end
        row.icons = {}
        for i = 1, count do
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(ICON, ICON)
            if row.label then
                icon:SetPoint("LEFT", row.label, "RIGHT", (i - 1) * (ICON + ICON_GAP), 0)
            else
                icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (ICON + ICON_GAP), 0)
            end
            icon.tex = icon:CreateTexture(nil, "ARTWORK")
            icon.tex:SetAllPoints()
            icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetScript("OnMouseDown", function(_, btn)
                -- Only an icon that is on moves; those off keep their place at the end
                if btn ~= "LeftButton" or i > #OnEntries(row) then return end
                drag = { row = r, index = i }
                RefreshLists()
                prioritiesPage:SetScript("OnUpdate", OnDragUpdate)
            end)
            icon:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then
                    StopListDrag()
                elseif btn == "RightButton" then
                    Toggle(row, self.family)
                end
            end)
            -- The game's own tooltip, of the best rank known, else of rank 1 (Michel)
            icon:SetScript("OnEnter", function(self)
                local ids = row.spells(self.family)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetSpellByID(B.Best(ids) or ids[1])
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", ns.HideTooltip)
            row.icons[i] = icon
        end
        rows[r] = row
        return row
    end

    -- A gold title centred over the page, in the game's normal font (ruleset plan
    -- 2026-10-19-tab-layout)
    local function Title(key)
        local t = prioritiesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", prioritiesPage, "TOP", 0, Place(14, 8))
        ns.SetL(t, key)
        return t
    end

    -- The aura list first, centred under its title, without a label
    controls.auraTitle = Title("AURA_LIST")
    local auraRow = NewRow(#D.CLASS_ORDER + 1, #D.AURA_ORDER, nil,
        function() return { order = db.auraList, off = {} } end,
        function(family) return D.AURAS[family] end, false, function() return true end)
    auraRow:SetWidth(#D.AURA_ORDER * (ICON + ICON_GAP) - ICON_GAP)
    auraRow:SetPoint("TOP", prioritiesPage, "TOP", 0, Place(ICON, 6))
    controls.auraRow = auraRow
    Place(6, 6) -- half a line between the two lists (Michel)

    -- The class rows under their title: two columns, a vertical line between them
    controls.blessingsTitle = Title("BTN_BLESSINGS")
    local function BlessingSpells(family) return D.BLESSINGS[family].normal end
    local rowsTop = Place(LEFT_ROWS * (ICON + ROW_GAP), 6)
    for r, class in ipairs(D.CLASS_ORDER) do
        -- As many icons as the class has blessings (ruleset plan 2026-10-20-class-defaults)
        local row = NewRow(r, #D.CLASS_LISTS[class], function()
            return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class)
        end, function() return db.classLists[class] end, BlessingSpells, true, B.FamilyExists)
        row.label:SetTextColor(C_ClassColor.GetClassColor(class):GetRGB()) -- Michel
        row.class = class
        row.column = r <= LEFT_ROWS and 1 or 2
        local line = (r - 1) % LEFT_ROWS
        row:SetPoint("TOPLEFT", INSET + (row.column - 1) * COL_W, rowsTop - line * (ICON + ROW_GAP))
        row:SetWidth(COL_W - 8)
    end
    local divider = prioritiesPage:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 0.82, 0, 0.4)
    divider:SetSize(1, LEFT_ROWS * (ICON + ROW_GAP) - ROW_GAP)
    divider:SetPoint("TOPLEFT", INSET + COL_W - 8, rowsTop)
    controls.listsDivider = divider
    measures[#measures + 1] = function() return 2 * COL_W end

    -- The hint, centred (Michel)
    local hint = prioritiesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetJustifyH("CENTER")
    hint:SetPoint("TOP", prioritiesPage, "TOP", 0, Place(26, 6))
    ns.SetL(hint, "LISTS_HINT")
    controls.listsHint = hint

    -- Default restores every list, blessings and auras; Enable all switches every blessing
    -- on again, appended after those on, the order kept (Michel, 2026-10-19)
    local reset = UI.AddButton(prioritiesPage, "DEFAULT", function()
        db.classLists = ns.DefaultClassLists()
        db.auraList = { unpack(D.AURA_ORDER) }
        RefreshLists()
        ns.Refresh()
    end)
    local buttonsY = Place(22, 6) - 6
    controls.listsDefault = reset
    local enableAll = UI.AddButton(prioritiesPage, "ENABLE_ALL", function()
        for _, class in ipairs(D.CLASS_ORDER) do
            local list = db.classLists[class]
            for _, family in ipairs(D.BLESSING_ORDER) do
                if list.off[family] and B.FamilyExists(family) then
                    list.off[family] = nil
                    table.insert(list.order, family)
                end
            end
        end
        RefreshLists()
        ns.Refresh()
    end)
    enableAll:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    controls.enableAll = enableAll
    -- The pair centred, equally wide, a button's width apart (Michel); their widths follow the
    -- language, so they are set again on every refresh
    local function CentreButtons()
        local w = math.max(reset:GetFontString():GetStringWidth(), enableAll:GetFontString():GetStringWidth()) + 30
        reset:SetWidth(w)
        enableAll:SetWidth(w)
        enableAll:ClearAllPoints()
        enableAll:SetPoint("LEFT", reset, "RIGHT", w, 0)
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", prioritiesPage, "TOP", -1.5 * w, buttonsY)
    end
    CentreButtons()
    refreshers[#refreshers + 1] = CentreButtons
    UI.AddSeparator()

    RefreshLists = function()
        for r, row in ipairs(rows) do
            local list = row.list()
            if row.label then row.label:SetText(row.labelText()) end
            local shown = Shown(row)
            for i = #shown + 1, #row.icons do
                row.icons[i].family = nil
                row.icons[i]:Hide()
            end
            for i, family in ipairs(shown) do
                local icon = row.icons[i]
                icon:Show()
                icon.family = family
                icon.tex:SetTexture(C_Spell.GetSpellTexture(row.spells(family)[1]))
                icon.tex:SetDesaturated(list.off[family] == true)
                local dragged = drag and drag.row == r and drag.index == i
                icon:SetAlpha(list.off[family] and 0.5 or dragged and 0.7 or 1)
            end
        end
    end
    refreshers[#refreshers + 1] = RefreshLists
    prioritiesPage:SetScript("OnHide", StopListDrag)

    -- The overview: a scroll frame of ten rows in two columns, filled by Overview.lua
    local OVERVIEW_H = 200
    local scroll = CreateFrame("ScrollFrame", nil, prioritiesPage, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", INSET, Place(OVERVIEW_H, 6))
    scroll:SetHeight(OVERVIEW_H)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    stretchers[#stretchers + 1] = function(w) scroll:SetWidth(w - 24) end
    ns.overviewHost = { page = prioritiesPage, scroll = scroll, child = child }
    controls.overviewScroll = scroll
end

---------------------------------------------------------------------------
-- Order: the bar's order by drag and drop, as in SimpleConjureBar
---------------------------------------------------------------------------
local orderPage = UI.NewPage("TAB_ORDER")

-- Name and icon per row
local ORDER_INFO = {
    AURA      = { name = function() return L.TRACK_AURA end,
                  icon = function() return C_Spell.GetSpellTexture(ns.auraButton.shownSpell) end },
    FURY      = { name = function() return ns.LocalName(C_Spell.GetSpellName(D.RIGHTEOUS_FURY), "RIGHTEOUS_FURY") end,
                  icon = function() return C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY) end },
    BLESSING  = { name = function() return L.BTN_BLESSINGS end,
                  icon = function() return C_Spell.GetSpellTexture(D.BLESSINGS.KINGS.normal[1]) end },
    SALVATION = { name = function() return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION") end,
                  icon = function() return C_Spell.GetSpellTexture(D.SALVATION) end },
}

do
    UI.AddNote("ORDER_HINT", 10)

    local ROW, ROW_GAP = 26, 2
    local rows = {}
    controls.orderRows = rows
    local RefreshOrder
    local drag -- { key, index } while dragging

    -- The keys of the rows: the saved order without a button whose spell the client has not
    local function RowKeys()
        local out = {}
        for _, key in ipairs(db.order) do
            if ns.ButtonExists(key) then out[#out + 1] = key end
        end
        return out
    end

    -- Row under the mouse cursor (1..n), no matter where exactly the row is grabbed
    local function SlotUnderCursor()
        local top = rows[1]:GetTop()
        if not top then return end
        local _, cy = GetCursorPosition()
        cy = cy / rows[1]:GetEffectiveScale()
        local slot = math.floor((top - cy) / (ROW + ROW_GAP)) + 1
        return math.max(1, math.min(#RowKeys(), slot))
    end

    local function StopOrderDrag()
        if not drag then return end
        drag = nil
        orderPage:SetScript("OnUpdate", nil)
        RefreshOrder()
        ns.Refresh() -- the bar is rebuilt only once the row is dropped
    end

    local function OnDragUpdate()
        -- Safety net: the mouse button was released outside the window
        if not IsMouseButtonDown("LeftButton") then StopOrderDrag() return end
        local slot = SlotUnderCursor()
        if slot and slot ~= drag.index then
            -- The row moves live under the cursor
            MoveShown(db.order, ns.ButtonExists, drag.index, slot)
            drag.index = slot
            RefreshOrder()
        end
    end

    local function StartOrderDrag(index)
        drag = { key = RowKeys()[index], index = index }
        RefreshOrder()
        orderPage:SetScript("OnUpdate", OnDragUpdate)
    end

    for i = 1, #D.DEFAULT_ORDER do
        local row = CreateFrame("Frame", nil, orderPage)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", INSET, Place(ROW, ROW_GAP))
        row:EnableMouse(true)

        -- Background: subtle on hover, gold while dragging
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)

        row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.num:SetPoint("LEFT", 4, 0)
        row.num:SetWidth(16)
        row.num:SetJustifyH("RIGHT")
        row.num:SetText(i .. ".")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", row.num, "RIGHT", 6, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

        -- Burger grip (three lines) on the right shows that the row can be dragged
        row.grip = {}
        for k = 1, 3 do
            local line = row:CreateTexture(nil, "ARTWORK")
            line:SetSize(14, 2)
            line:SetPoint("RIGHT", row, "RIGHT", -6, (2 - k) * 5)
            line:SetColorTexture(0.6, 0.6, 0.6, 1)
            row.grip[k] = line
        end
        function row.SetGripColor(r, g, b)
            for _, line in ipairs(row.grip) do line:SetColorTexture(r, g, b, 1) end
        end

        row:SetScript("OnEnter", function(self)
            if drag then return end
            self.bg:SetColorTexture(1, 1, 1, 0.06)
            self.SetGripColor(1, 0.82, 0)
        end)
        row:SetScript("OnLeave", function(self)
            if drag then return end
            self.bg:SetColorTexture(1, 1, 1, 0)
            self.SetGripColor(0.6, 0.6, 0.6)
        end)
        row:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then StartOrderDrag(i) end
        end)
        row:SetScript("OnMouseUp", function(_, btn)
            if btn == "LeftButton" then StopOrderDrag() end
        end)

        rows[i] = row
        measures[#measures + 1] = function() return 4 + 16 + 6 + 22 + 8 + row.label:GetStringWidth() + 16 + 20 end
        stretchers[#stretchers + 1] = function(w) row:SetWidth(w) end
    end

    RefreshOrder = function()
        local keys = RowKeys()
        for i, row in ipairs(rows) do
            local info = ORDER_INFO[keys[i]]
            row:SetShown(info ~= nil)
            if info then
                row.label:SetText(info.name())
                row.icon:SetTexture(info.icon())
            end
            if drag and drag.index == i then
                row.bg:SetColorTexture(1, 0.82, 0, 0.18)
                row.SetGripColor(1, 0.82, 0)
            elseif drag or not row:IsMouseOver() then
                row.bg:SetColorTexture(1, 1, 1, 0)
                row.SetGripColor(0.6, 0.6, 0.6)
            end
        end
    end
    refreshers[#refreshers + 1] = RefreshOrder
    orderPage:SetScript("OnHide", StopOrderDrag)

    -- Restores the default order
    local reset = UI.AddButton(orderPage, "DEFAULT", function()
        db.order = { unpack(D.DEFAULT_ORDER) }
        RefreshOrder()
        ns.Refresh()
    end)
    reset:SetPoint("TOPLEFT", INSET, Place(22, 6) - 6)
    controls.orderDefault = reset
end

---------------------------------------------------------------------------
-- Macros: prepared only; which macros are worth it Michel decides in a later plan
---------------------------------------------------------------------------
UI.NewPage("TAB_MACROS")
controls.macrosNote = UI.AddNote("MACROS_LATER", 10)

UI.CreateTabs()
