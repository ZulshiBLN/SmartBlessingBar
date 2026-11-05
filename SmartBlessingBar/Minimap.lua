-- SmartBlessingBar - entry points: minimap button, AddOn compartment, options entry
-- As in SimpleConjureBar (ruleset plan 2026-10-18-settings-more). The minimap button is built
-- without a library (project.md): left click = settings, right click = lock, drag = move it
-- around the minimap.

local ADDON_NAME, ns = ...
if not ns.enabled then return end

local D, L = ns.D, ns.L
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

-- The icon the TOC gives the addon list, read from there: one fact, one place
local ICON = C_AddOns.GetAddOnMetadata(ADDON_NAME, "IconTexture")

local function ShowEntryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetText("SmartBlessingBar |cffffffffv" .. ns.VERSION .. "|r")
    GameTooltip:AddLine(" ")
    -- Left, middle, right, as in every tooltip; only the minimap button opens the Priorities tab
    -- and can be dragged
    local minimap = anchor == "ANCHOR_LEFT"
    GameTooltip:AddDoubleLine(L.LEFTCLICK, L.SETTINGS, 0, 1, 0, 1, 1, 1)
    if minimap then GameTooltip:AddDoubleLine(L.MIDDLECLICK, L.TAB_PRIORITIES, 0, 1, 0, 1, 1, 1) end
    -- Away from the bar "Lock" alone says nothing: it names what it locks
    GameTooltip:AddDoubleLine(L.RIGHTCLICK, db.locked and L.UNLOCK_BAR or L.LOCK_BAR, 0, 1, 0, 1, 1, 1)
    if minimap then GameTooltip:AddDoubleLine(L.DRAG, L.MOVE, 0, 1, 0, 1, 1, 1) end
    GameTooltip:Show()
end

-- owner, anchor: the tooltip the click came from, shown again so it says the new state at once
local function ToggleLockWithMessage(owner, anchor)
    ns.ToggleLock()
    ns.Print(db.locked and L.LOCKED or L.UNLOCKED)
    if owner and GameTooltip:IsOwned(owner) then ShowEntryTooltip(owner, anchor) end
end

local function Click(button, owner, anchor)
    if button == "RightButton" then ToggleLockWithMessage(owner, anchor) else ns.ToggleSettings() end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local minimapBtn = CreateFrame("Button", "SmartBlessingBarMinimapButton", Minimap)
ns.minimapButton = minimapBtn
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Centred in the ring (Data.lua, D.MINIMAP_*)
do
    local INNER_X, INNER_Y = D.MINIMAP_INNER_OFFSET[1], D.MINIMAP_INNER_OFFSET[2]
    local ICON_SIZE = D.MINIMAP_ICON_SIZE
    -- One anchor sets no size: the highlight takes the button's, the client gave it none
    local highlight = minimapBtn:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetSize(minimapBtn:GetSize())
    highlight:SetPoint("CENTER", INNER_X, INNER_Y)

    local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    bg:SetPoint("CENTER", INNER_X, INNER_Y)
    minimapBtn.background = bg

    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", INNER_X, INNER_Y)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    -- Round, as the client's own minimap buttons: no corner reaches past the ring
    local mask = minimapBtn:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    minimapBtn.icon = icon

    local ring = minimapBtn:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(53, 53)
    ring:SetPoint("CENTER", D.MINIMAP_RING_OFFSET[1], D.MINIMAP_RING_OFFSET[2])
    minimapBtn.ring = ring
end

-- On a circle around the minimap
local function PlaceMinimapButton()
    local angle = math.rad(db.minimapAngle)
    local radius = (Minimap:GetWidth() / 2) + 10
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.ApplyMinimapButton()
    if db.hideMinimap then minimapBtn:Hide() else minimapBtn:Show() end
    PlaceMinimapButton()
end

local function OnMinimapDrag()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    PlaceMinimapButton()
end
minimapBtn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnMinimapDrag) end)
minimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- A middle click opens the settings on the Priorities tab, with the overview; open on that
-- tab, it closes them. The AddOn compartment keeps its two clicks (ruleset plan
-- 2026-10-19-priorities).
local function PrioritiesClick()
    if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
    if ns.SettingsPageShown("TAB_PRIORITIES") then ns.CloseSettings() else ns.OpenSettingsOn("TAB_PRIORITIES") end
end

-- The Priorities key (Bindings.xml; ruleset plan 2026-10-20-key-bindings): a hidden button its
-- binding clicks, on the release only, so one press toggles once
local prioritiesKey = CreateFrame("Button", "SmartBlessingBarPrioritiesKey", UIParent)
prioritiesKey:RegisterForClicks("AnyUp")
prioritiesKey:SetScript("OnClick", PrioritiesClick)
minimapBtn:SetScript("OnClick", function(self, button)
    if button == "MiddleButton" then PrioritiesClick() else Click(button, self, "ANCHOR_LEFT") end
end)
minimapBtn:SetScript("OnEnter", function(self) ShowEntryTooltip(self, "ANCHOR_LEFT") end)
minimapBtn:SetScript("OnLeave", ns.HideTooltip)

---------------------------------------------------------------------------
-- AddOn compartment: Core.lua's globals call these
---------------------------------------------------------------------------
function ns.CompartmentClick(_, button, menuButton) Click(button, menuButton, "ANCHOR_RIGHT") end
function ns.CompartmentEnter(_, menuButton) ShowEntryTooltip(menuButton, "ANCHOR_RIGHT") end
function ns.CompartmentLeave() ns.HideTooltip() end

---------------------------------------------------------------------------
-- Entry in the client's options (Options > AddOns): a page with a button that opens our window
---------------------------------------------------------------------------
function ns.RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "SmartBlessingBar"

    local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    head:SetTextColor(1, 0.82, 0) -- Blizzard gold
    head:SetPoint("TOP", panel, "TOP", 0, -120)
    head:SetText("SmartBlessingBar")

    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    ver:SetPoint("TOP", head, "BOTTOM", 0, -10)
    SetL(ver, "VERSION", ns.VERSION)

    local helpHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpHint:SetPoint("TOP", ver, "BOTTOM", 0, -18)
    SetL(helpHint, "HELP_HINT", "|cffffd100/sbb help|r")

    local access = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    access:SetPoint("TOP", helpHint, "BOTTOM", 0, -6)
    SetL(access, "ACCESS_OPTIONS", "|cffffd100/sbb|r")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    SetL(open, "OPEN_SETTINGS")
    local function FitOpen()
        open:SetSize(math.max(160, open:GetFontString():GetStringWidth() + 40), 28)
    end
    FitOpen()
    ns.OnLanguageChanged(FitOpen)
    open:SetPoint("TOP", access, "BOTTOM", 0, -18)
    open:SetScript("OnClick", function() ns.OpenSettings(true) end)
    ns.optionsOpenButton = open

    local category = Settings.RegisterCanvasLayoutCategory(panel, "SmartBlessingBar")
    Settings.RegisterAddOnCategory(category)
end
