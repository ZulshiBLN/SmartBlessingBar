-- Minimal WoW API mock: what the addon calls, nothing more. STATE is the
-- world a spec builds; CHAT collects print.
--
-- STATE.units maps a unit token to a record. Two tokens for the same
-- player share one record, so UnitIsUnit compares records:
--   { class = "MAGE", connected = true, dead = false, visible = true,
--     range = true, subgroup = 1, level = 25,
--     auras = { { spellId = 19740, expirationTime = 100, mine = true } } }
-- connected, visible and range default to true, dead to false, level to 25.
-- STATE.learned maps a spell ID to the level it is learned at; unset, the game gives none.
local noop = function() end
-- Frames get events in the order they first registered: a fixed order, so a spec can rely on
-- one (SimpleConjureBar 3ecc2ea: the random order of pairs had hidden a lost-window bug)
local eventFrames, eventOrder = {}, {}
STATE = {
  class = "PALADIN", locale = "deDE", errors = {},
  units = {},       -- unit token -> record; "player" is added by the loader
  group = nil,      -- nil, "party" or "raid"
  known = {},       -- spell ID -> true for IsPlayerSpell
  bags = {},        -- item ID -> count
  combat = false,
  keyDown = true,   -- ActionButtonUseKeyDown: secure buttons act on key down
  casts = {},       -- spells cast by secure clicks (RUNCLICK)
}
CHAT = {}

-- Frames. A frame made from a Secure template is protected, and so is every
-- frame above it, as in the client. In combat a protected frame refuses
-- attribute, position and visibility changes with an error, as the client
-- does - so a spec sees a write the addon must not make.
local Methods = {}
local function Guard(self, what)
  if STATE.combat and self.protected then error("protected " .. what .. " in combat", 3) end
end
function Methods:RegisterEvent(e)
  self.events[e] = true
  if not eventFrames[self] then eventFrames[self] = true; eventOrder[#eventOrder + 1] = self end
end
function Methods:UnregisterEvent(e) self.events[e] = nil end
function Methods:SetScript(s, f) self.scripts[s] = f end
function Methods:GetScript(s) return self.scripts[s] end
function Methods:HookScript(s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end
function Methods:SetAttribute(k, v) Guard(self, "SetAttribute"); self.attrs[k] = v end
function Methods:GetAttribute(k) return self.attrs[k] end
-- Showing or hiding runs OnShow / OnHide, as in the client, but only on a real change
function Methods:Show()
  Guard(self, "Show")
  if not self.shown then self.shown = true; RUNSCRIPT(self, "OnShow") end
end
function Methods:Hide()
  Guard(self, "Hide")
  if self.shown then self.shown = false; RUNSCRIPT(self, "OnHide") end
end
function Methods:IsShown() return self.shown end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:SetJustifyH(v) self.justifyH = v end
-- A font string wraps its text unless told not to
function Methods:SetWordWrap(v) self.wordWrap = v end
function Methods:GetWordWrap() return rawget(self, "wordWrap") ~= false end
-- The client keeps a moved frame's place unless told not to
function Methods:SetDontSavePosition(v) self.dontSavePosition = v end
-- The client refuses an anchor name it does not know, for the point and the relative point
local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
                  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
function Methods:SetPoint(...)
  Guard(self, "SetPoint")
  for i = 1, 3 do
    local v = select(i, ...)
    if (i == 1 or type(v) == "string") and not ANCHORS[v] then error("SetPoint: invalid anchor " .. tostring(v), 2) end
  end
  self.points[#self.points + 1] = { ... }
end
function Methods:ClearAllPoints() Guard(self, "ClearAllPoints"); self.points = {} end
function Methods:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:SetWidth(w) self.w = w end
function Methods:GetWidth() return self.w end
-- The rectangle from the frame's first point, when it is anchored to UIParent - as the
-- client reports where a frame really is. Otherwise a fixed place.
local OFFSETS = { -- point -> left and bottom offset from the anchor, in widths and heights
  LEFT = { 0, -0.5 }, RIGHT = { -1, -0.5 }, TOP = { -0.5, -1 }, BOTTOM = { -0.5, 0 },
  CENTER = { -0.5, -0.5 }, BOTTOMLEFT = { 0, 0 }, TOPLEFT = { 0, -1 },
}
function Methods:GetRect()
  local w, h = self.w or 0, self.h or 0
  local p = self.points[1]
  if p and p[2] == UIParent and OFFSETS[p[1]] then
    local x, y = p[4] or 0, p[5] or 0
    if p[3] == "CENTER" then x, y = x + 960, y + 540 end
    local o = OFFSETS[p[1]]
    return x + o[1] * w, y + o[2] * h, w, h
  end
  return 100, 200, w, h
end
-- Where a frame sits on screen: STATE.center, if a spec set one, else the lower left quarter
function Methods:GetCenter()
  local c = STATE.center
  if c then return c[1], c[2] end
  return 500, 300
end
function Methods:GetEffectiveScale() return 1 end
-- A frame's top edge only where a spec sets one (frame.top)
function Methods:GetTop() return rawget(self, "top") end
function Methods:GetLeft() return rawget(self, "left") end
function Methods:GetRight() return rawget(self, "right") end
function Methods:GetHeight() return self.h end
function Methods:SetHeight(h) self.h = h end
function Methods:SetScale(s) Guard(self, "SetScale"); self.scale = s end
function Methods:GetScale() return rawget(self, "scale") or 1 end
function Methods:SetRotation(r) self.rotation = r end
function Methods:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end
function Methods:StartMoving() Guard(self, "StartMoving"); self.moving = true end
function Methods:StopMovingOrSizing() Guard(self, "StopMovingOrSizing"); self.moving = false end
function Methods:RegisterForClicks(...) self.clicks = { ... } end
-- A texture records its draw layer and sublevel, and its colour
function Methods:CreateTexture(_, layer, _, sublevel)
  local t = NEWOBJ("Texture")
  t.layer, t.sublevel = layer, sublevel
  return t
end
function Methods:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
function Methods:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
-- A mask texture, and the masks a texture carries (texture.masks)
function Methods:CreateMaskTexture() return NEWOBJ("MaskTexture") end
function Methods:AddMaskTexture(mask)
  self.masks = rawget(self, "masks") or {}
  table.insert(self.masks, mask)
end
function Methods:GetSize() return self.w, self.h end
function Methods:CreateFontString() return NEWOBJ("FontString") end
function Methods:SetTexture(t) self.texture = t end
function Methods:GetTexture() return self.texture end
function Methods:SetDesaturated(v) self.desaturated = v end
function Methods:IsDesaturated() return self.desaturated == true end
function Methods:SetText(t)
  self.text = t
  -- A button shows its text on its own font string, as the client's do
  if self.kind == "Button" then self:GetFontString().text = t end
end
function Methods:GetText() return self.text end
-- An edit box's selection: "all" for HighlightText(), "none" for HighlightText(0, 0); focus
-- runs OnEditFocusGained, as in the client
function Methods:HighlightText(a, b) self.selection = (a == nil and b == nil) and "all" or (a == b and "none" or "part") end
function Methods:SetFocus() self.focused = true; RUNSCRIPT(self, "OnEditFocusGained") end
function Methods:ClearFocus() self.focused = false end
function Methods:GetFontString()
  self.fontString = rawget(self, "fontString") or NEWOBJ("FontString")
  return self.fontString
end
-- Text width as the mock measures it: 7 px per byte
function Methods:GetStringWidth() return #tostring(rawget(self, "text") or "") * 7 end
function Methods:IsMouseOver() return false end
function Methods:GetName() return rawget(self, "name") end
function Methods:GetPushedTexture() self.pushedTex = rawget(self, "pushedTex") or NEWOBJ("Texture"); return self.pushedTex end
function Methods:GetHighlightTexture() self.hlTex = rawget(self, "hlTex") or NEWOBJ("Texture"); return self.hlTex end
-- BackdropTemplate: SetBackdrop makes the centre piece the background is drawn on, in
-- BACKGROUND
function Methods:SetBackdrop(b)
  self.backdrop = b
  if not rawget(self, "Center") then
    self.Center = NEWOBJ("Texture", nil, self)
    self.Center.layer, self.Center.sublevel = "BACKGROUND", -8
  end
end
function Methods:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
function Methods:SetTexCoord(...) self.texCoord = { ... } end
function Methods:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Methods:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Methods:SetBlendMode(m) self.blend = m end
function Methods:SetAtlas(a) self.atlas = a end
-- Animation groups as the client's: they record their animations, looping and play state;
-- the client plays them, a spec reads what was set
function Methods:CreateAnimationGroup()
  local group = { animations = {}, playing = false }
  group.SetLooping = function(g, v) g.looping = v end
  group.Play = function(g) g.playing = true end
  group.Stop = function(g) g.playing = false end
  group.IsPlaying = function(g) return g.playing end
  group.CreateAnimation = function(g, kind)
    local a = { kind = kind }
    a.SetFlipBookRows = function(x, n) x.rows = n end
    a.SetFlipBookColumns = function(x, n) x.columns = n end
    a.SetFlipBookFrames = function(x, n) x.frames = n end
    a.SetDuration = function(x, s) x.duration = s end
    a.GetDuration = function(x) return x.duration end
    table.insert(g.animations, a)
    return a
  end
  return group
end
function Methods:SetFrameStrata(s) self.strata = s end
function Methods:GetFrameStrata() return rawget(self, "strata") or "MEDIUM" end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:GetAlpha() return rawget(self, "alpha") or 1 end
function Methods:GetFrameLevel() return rawget(self, "level") or 1 end
function Methods:SetFrameLevel(l) self.level = l end
function Methods:GetParent() return rawget(self, "parent") end

function NEWOBJ(kind, name, parent)
  local o = { kind = kind, name = name, parent = parent, scripts = {}, hooks = {}, events = {},
              attrs = {}, points = {}, shown = true }
  -- An unknown method is a no-op, as many client methods are to a spec; an unknown field is
  -- nil, as in the client. Only names starting with a capital are methods.
  setmetatable(o, { __index = function(_, k)
    if Methods[k] then return Methods[k] end
    if type(k) == "string" and k:match("^%u") then return noop end
  end })
  return o
end

function CreateFrame(kind, name, parent, template)
  local o = NEWOBJ(kind, name, parent)
  o.template = template
  if template and template:find("Secure") then
    local f = o
    -- rawget: a missing field reads as a method stub through the metatable
    while f do f.protected = true; f = rawget(f, "parent") end
  end
  -- The client's menu dropdown shows its selection on a font string of its own
  if kind == "DropdownButton" then o.Text = NEWOBJ("FontString") end
  if name then _G[name] = o end
  return o
end

-- Runs a frame's script and its hooks, recording errors like FIRE does.
function RUNSCRIPT(frame, script, ...)
  local fns = { frame.scripts[script] }
  for _, h in ipairs(frame.hooks[script] or {}) do fns[#fns + 1] = h end
  for _, fn in ipairs(fns) do
    local ok, err = pcall(fn, frame, ...)
    if not ok then table.insert(STATE.errors, script .. ": " .. tostring(err)) end
  end
end

---------------------------------------------------------------------------
-- Secure snippets. A SecureHandler header wraps a frame's OnClick with a pre
-- and a post body, as WrapScript does. The bodies run in an emulated
-- restricted environment and see frames only through handles, which may
-- change protected frames in combat - the one thing addon code may not.
-- Bodies are compiled with their arguments as locals, like the client's.
---------------------------------------------------------------------------
local handles = setmetatable({}, { __mode = "k" })
local framesOf = setmetatable({}, { __mode = "k" })
local function Handle(frame)
  if not frame then return nil end
  if handles[frame] then return handles[frame] end
  local h = {}
  framesOf[h] = frame
  -- The client's secure auto-hide: recorded here, as the frame's autoHide seconds and the
  -- frames that keep it open (autoHideWith). Like the client it works only on a protected
  -- frame, and a frame joins a registration only after it was made.
  function h:RegisterAutoHide(seconds)
    if not rawget(frame, "protected") then error("RegisterAutoHide on an unprotected frame") end
    frame.autoHide = seconds
    frame.autoHideWith = {}
  end
  function h:AddToAutoHide(other)
    if not rawget(frame, "autoHide") then error("AddToAutoHide before RegisterAutoHide") end
    table.insert(frame.autoHideWith, framesOf[other])
  end
  function h:UnregisterAutoHide() frame.autoHide = nil; frame.autoHideWith = nil end
  function h:GetAttribute(k) return frame.attrs[k] end
  function h:SetAttribute(k, v) frame.attrs[k] = v end
  function h:Show() frame.shown = true end
  function h:Hide() frame.shown = false end
  function h:IsShown() return frame.shown end
  function h:GetParent() return Handle(rawget(frame, "parent")) end
  function h:GetName() return frame.name end
  function h:GetFrameRef(name)
    local refs = rawget(frame, "refs")
    return Handle(refs and refs[name])
  end
  -- In combat the client refuses a handle to a frame that is not protected: any call
  -- through it raises "Invalid frame handle" and stops the snippet.
  for name, fn in pairs(h) do
    h[name] = function(...)
      if STATE.combat and not rawget(frame, "protected") then error("Invalid frame handle") end
      return fn(...)
    end
  end
  handles[frame] = h
  return h
end

local restricted = {
  PlayerInCombat = function() return STATE.combat end,
  newtable = function(...) return { ... } end,
  pairs = pairs, ipairs = ipairs, tostring = tostring, type = type,
}
local function Compile(body, args)
  local chunk = assert(loadstring("local " .. args .. " = ...\n" .. body))
  setfenv(chunk, setmetatable({}, { __index = restricted }))
  return chunk
end

-- rawget throughout: a missing field reads as a method stub through the metatable
local function Wraps(frame, script)
  local wraps = rawget(frame, "wraps")
  return wraps and wraps[script] or {}
end
function Methods:SetFrameRef(name, frame)
  self.refs = rawget(self, "refs") or {}
  self.refs[name] = frame
end
function Methods:WrapScript(frame, script, pre, post)
  frame.wraps = rawget(frame, "wraps") or {}
  frame.wraps[script] = frame.wraps[script] or {}
  table.insert(frame.wraps[script], {
    owner = self,
    pre = pre and Compile(pre, "self, button, down, owner"),
    post = post and Compile(post, "self, message, button, down, owner"),
  })
end

-- A click as the client delivers it to a secure button: the wrappers' pre
-- bodies (false cancels the action and every post body), the secure action
-- (on key down while STATE.keyDown, else on key up), the post bodies of the
-- wrappers that returned a message, then the insecure hooks. A spell cast
-- is appended to STATE.casts as { spell = id, unit = token }.
local function Attr(frame, name, button)
  local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2"
    or button == "MiddleButton" and "3" or ""
  local v = frame.attrs[name .. suffix]
  if v == nil then v = frame.attrs[name] end
  return v
end
-- A macro's lines as the client runs them, as far as the addon writes macros:
-- "/click Name [button] [1]" clicks a named button, key down with the "1"; "/targetfriendplayer"
-- targets the next of STATE.friends (nil when none is left) and counts in STATE.targetedNext
local function RunMacro(text)
  for line in (text or ""):gmatch("[^\n]+") do
    local name, button, down = line:match("^/click%s+(%S+)%s*(%S*)%s*(%S*)")
    if name then
      local target = _G[name]
      if target then RUNCLICK(target, button ~= "" and button or "LeftButton", down == "1") end
    elseif line:match("^/targetfriendplayer") then
      STATE.units.target = table.remove(STATE.friends or {}, 1)
      STATE.targetedNext = (STATE.targetedNext or 0) + 1
    end
  end
end

function RUNCLICK(frame, button, down)
  RUNSCRIPT(frame, "PreClick", button, down)
  local cancelled, messages = false, {}
  for i, w in ipairs(Wraps(frame, "OnClick")) do
    if w.pre then
      local ok, result, message = pcall(w.pre, Handle(frame), button, down, Handle(w.owner))
      if not ok then table.insert(STATE.errors, "snippet: " .. tostring(result)) end
      if result == false then cancelled = true break end
      messages[i] = message
    end
  end
  if not cancelled then
    local template = rawget(frame, "template")
    if template and template:find("SecureActionButtonTemplate") and (down == true) == (STATE.keyDown == true) then
      local kind = Attr(frame, "type", button)
      -- A spell action without a spell does nothing, as in the client
      if kind == "spell" and Attr(frame, "spell", button) ~= nil then
        STATE.casts[#STATE.casts + 1] = { spell = Attr(frame, "spell", button), unit = Attr(frame, "unit", button) }
      elseif kind == "macro" then
        RunMacro(Attr(frame, "macrotext", button))
      end
    end
    for i, w in ipairs(Wraps(frame, "OnClick")) do
      if w.post and messages[i] ~= nil then
        local ok, err = pcall(w.post, Handle(frame), messages[i], button, down, Handle(w.owner))
        if not ok then table.insert(STATE.errors, "snippet: " .. tostring(err)) end
      end
    end
  end
  RUNSCRIPT(frame, "OnClick", button, down)
end

-- Widgets of the settings window
function Methods:SetChecked(v) self.checked = v and true or false end
function Methods:GetChecked() return rawget(self, "checked") == true end
-- A slider runs OnValueChanged when its value changes, as the client's does
function Methods:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
function Methods:SetValue(v)
  local lo, hi = rawget(self, "min"), rawget(self, "max")
  if lo then v = math.max(lo, math.min(hi, v)) end
  if rawget(self, "value") == v then return end
  self.value = v
  RUNSCRIPT(self, "OnValueChanged", v)
end
function Methods:GetValue() return rawget(self, "value") end
-- A menu dropdown keeps its generator; MENU reads the entries it builds
function Methods:SetupMenu(gen) self.menuGen = gen end
function Methods:GenerateMenu() self.generated = (rawget(self, "generated") or 0) + 1 end

-- The entries of a menu dropdown: { text =, selected = bool, pick = function }
function MENU(dd)
  local entries, root = {}, {}
  function root:CreateRadio(text, isSelected, select)
    entries[#entries + 1] = { text = text, selected = isSelected() and true or false, pick = select }
  end
  dd.menuGen(dd, root)
  return entries
end

-- The client's color picker: SetupColorPickerAndShow keeps the info; STATE.pickedColor is
-- what the player has picked, { r, g, b, a }
ColorPickerFrame = NEWOBJ("Frame")
ColorPickerFrame.shown = false
ColorPickerFrame.Content = { ColorPicker = NEWOBJ("Frame") }
function ColorPickerFrame:SetupColorPickerAndShow(info)
  self.info = info
  self:Show()
end
function ColorPickerFrame:GetColorRGB() local c = STATE.pickedColor return c[1], c[2], c[3] end
function ColorPickerFrame:GetColorAlpha() return STATE.pickedColor[4] end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
PixelUtil = { SetSize = function(f, w, h) f:SetSize(w, h) end }

-- The tooltip records its lines: { left, right or nil, r, g, b } per AddLine / AddDoubleLine
GameTooltip = NEWOBJ("GameTooltip")
function GameTooltip:SetOwner(owner, anchor) self.owner, self.anchor, self.lines = owner, anchor, {} end
function GameTooltip:IsOwned(frame) return self.shown == true and self.owner == frame end
function GameTooltip:AddLine(text, r, g, b) table.insert(self.lines, { text, nil, r, g, b }) end
function GameTooltip:AddDoubleLine(left, right, r, g, b) table.insert(self.lines, { left, right, r, g, b }) end
function GameTooltip:SetSpellByID(id) self.spell = id; self.shown = true end

-- Timers: C_Timer.After queues until RUNTIMERS; tickers run on TICK.
local timers, tickers = {}, {}
C_Timer = {
  After = function(_, fn) timers[#timers + 1] = fn end,
  NewTicker = function(_, fn) local t = { fn = fn }; tickers[#tickers + 1] = t; return t end,
}
function RUNTIMERS()
  local list = timers; timers = {}
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn)
    if not ok then table.insert(STATE.errors, "timer: " .. tostring(err)) end
  end
end
function TICK()
  for _, t in ipairs(tickers) do
    local ok, err = pcall(t.fn)
    if not ok then table.insert(STATE.errors, "ticker: " .. tostring(err)) end
  end
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
UISpecialFrames = {}
-- Secure state drivers: STATE.drivers[frame][state] = the driver's text
RegisterStateDriver = function(frame, state, text)
  STATE.drivers = STATE.drivers or {}
  STATE.drivers[frame] = STATE.drivers[frame] or {}
  STATE.drivers[frame][state] = text
end
UnregisterStateDriver = function(frame, state)
  if STATE.drivers and STATE.drivers[frame] then STATE.drivers[frame][state] = nil end
end
ReloadUI = function() STATE.reloaded = true end
tinsert = table.insert

-- Runs every OnEvent script registered for the event; an error is recorded
-- in STATE.errors, as BugGrabber would, instead of stopping the spec.
function FIRE(event, ...)
  for _, f in ipairs(eventOrder) do
    if f.events[event] and f.scripts.OnEvent then
      local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
      if not ok then table.insert(STATE.errors, event .. ": " .. tostring(err)) end
    end
  end
end

-- The field read from the TOC on disk, as the client reads it.
local function TocField(addon, field)
  local f = assert(io.open(addon .. "/" .. addon .. ".toc", "rb"))
  local text = f:read("*a")
  f:close()
  return text:match("\n## " .. field .. ":%s*([^\r\n]-)%s*[\r\n]")
end

print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  CHAT[#CHAT + 1] = table.concat(t, " ")
end
GetLocale = function() return STATE.locale end
-- The loaded addons: STATE.addons, { name, loaded, version } each; this addon alone without it
C_AddOns = {
  GetAddOnMetadata = function(addon, field)
    for _, a in ipairs(STATE.addons or {}) do
      if a.name == addon and field == "Version" then return a.version end
    end
    return TocField(addon, field)
  end,
  GetNumAddOns = function() return STATE.addons and #STATE.addons or 1 end,
  IsAddOnLoaded = function(i) return not STATE.addons or STATE.addons[i].loaded ~= false end,
  GetAddOnInfo = function(i) return STATE.addons and STATE.addons[i].name or "SmartBlessingBar" end,
}
SlashCmdList = {}
InCombatLockdown = function() return STATE.combat end

local function U(unit) return unit and STATE.units[unit] end
UnitExists = function(u) return U(u) ~= nil end
UnitClass = function(u) local r = U(u) if r then return "Class", r.class end end
UnitIsConnected = function(u) local r = U(u) return r ~= nil and r.connected ~= false end
UnitIsDeadOrGhost = function(u) local r = U(u) return r ~= nil and r.dead == true end
UnitIsVisible = function(u) local r = U(u) return r ~= nil and r.visible ~= false end
UnitIsUnit = function(a, b) return U(a) ~= nil and U(a) == U(b) end
-- A record is a player unless `npc`, friendly unless `hostile`
UnitIsPlayer = function(u) local r = U(u) return r ~= nil and r.npc ~= true end
UnitCanAssist = function(_, u) local r = U(u) return r ~= nil and r.hostile ~= true end
-- Flagged for PvP when the record says `pvp`
UnitIsPVP = function(u) local r = U(u) return r ~= nil and r.pvp == true end
-- The player's PvP flag runs out (5 minutes) when STATE.pvpTimer is set
IsPVPTimerRunning = function() return STATE.pvpTimer == true end
-- A player's GUID: the record's guid, else one made from the record, the same for every token.
-- STATE.guidAsked counts the calls per token.
UnitGUID = function(u)
  STATE.guidAsked = STATE.guidAsked or {}
  STATE.guidAsked[u] = (STATE.guidAsked[u] or 0) + 1
  local r = U(u) return r and (r.guid or tostring(r))
end
-- The group role the game reports: the record's role, else "NONE"
-- Forever has no realms: the second value is the character's second name (decisions.md,
-- 2026-10-18), here the record's `surname`
UnitName = function(u) local r = U(u) if r then return r.name or u, r.surname end end
UnitGroupRolesAssigned = function(u) local r = U(u) return r and r.role or "NONE" end

local function countUnits(prefix)
  local n = 0
  for unit in pairs(STATE.units) do
    if unit:match("^" .. prefix .. "%d+$") then n = n + 1 end
  end
  return n
end
IsInRaid = function() return STATE.group == "raid" end
IsInGroup = function() return STATE.group ~= nil end
GetNumGroupMembers = function()
  if STATE.group == "raid" then return countUnits("raid") end
  if STATE.group == "party" then return countUnits("party") + 1 end
  return 0
end
GetNumSubgroupMembers = function() return countUnits("party") end
GetRaidRosterInfo = function(i)
  local r = U("raid" .. i)
  if r then return "Raider" .. i, 0, r.subgroup end
end

-- "HELPFUL|PLAYER" returns only the auras the player cast (mine = true).
C_UnitAuras = {
  GetPlayerAuraBySpellID = function(id)
    for _, a in ipairs(STATE.units.player.auras or {}) do
      if a.spellId == id then return { spellId = a.spellId, expirationTime = a.expirationTime } end
    end
  end,
  -- While STATE.aurasSecret, the client refuses an addon's read with an error, also out of
  -- combat (Midnight's restriction in instances and PvP)
  GetAuraDataByIndex = function(u, i, filter)
    if STATE.aurasSecret then error("Auras cannot be accessed when secret while tainted by 'SmartBlessingBar'") end
    local r = U(u)
    if not r then return end
    -- A scan is the reads from index 1 on: STATE.scans[record][filter] counts them, so the
    -- tokens of one person count together
    if i == 1 then
      STATE.scans = STATE.scans or {}
      STATE.scans[r] = STATE.scans[r] or {}
      STATE.scans[r][filter or ""] = (STATE.scans[r][filter or ""] or 0) + 1
    end
    local n = 0
    for _, a in ipairs(r.auras or {}) do
      if a.mine or not (filter or ""):find("PLAYER") then
        n = n + 1
        -- The aura's own record serves as its instance ID: the same aura in both filters
        -- `source`: the caster's unit token, as sourceUnit; nil for one outside the group
        if n == i then
          return { spellId = a.spellId, expirationTime = a.expirationTime, auraInstanceID = a, sourceUnit = a.source }
        end
      end
    end
  end,
}
-- C_Secrets.ShouldAurasBeSecret answers STATE.aurasSecret; STATE.noSecretsApi leaves it out,
-- as a client without it
C_Secrets = setmetatable({}, { __index = function(_, k)
  if k == "ShouldAurasBeSecret" and not STATE.noSecretsApi then
    return function() return STATE.aurasSecret == true end
  end
end })
C_Spell = {
  -- The client gives no answer for a spell the player does not know
  IsSpellInRange = function(id, u)
    if not (STATE.known and STATE.known[id]) then return nil end
    local r = U(u) return r ~= nil and r.range ~= false
  end,
  -- STATE.removed[id]: the client no longer has the spell (ruleset plan
  -- 2026-11-05-removed-spells), as live build 70790 answers
  DoesSpellExist = function(id) return not (STATE.removed and STATE.removed[id]) end,
  GetSpellTexture = function(id)
    if STATE.removed and STATE.removed[id] then return nil end
    return "icon" .. id
  end,
  GetSpellName = function(id)
    if STATE.removed and STATE.removed[id] then return nil end
    return "spell" .. id
  end,
  GetSpellLevelLearned = function(id) return STATE.learned and STATE.learned[id] end,
  -- STATE.gcd: the global cooldown runs, 1.5 s from GetTime
  GetSpellCooldown = function()
    if STATE.gcd then return { startTime = (STATE.now or 0) + 1, duration = 1.5 } end
    return { startTime = 0, duration = 0 }
  end,
}
C_Item = {
  GetItemCount = function(id) return STATE.bags[id] or 0 end,
  GetItemNameByID = function(id) return "item" .. id end,
}

-- A vendor: STATE.merchant = list of { id =, price =, stack =, maxStack = } (nil = no vendor
-- open); STATE.money in copper; STATE.now for GetTime. BuyMerchantItem puts the items in the
-- bags, pays per item from the stack price - as Forever does (ruleset decisions,
-- 2026-10-18) - and records every call in STATE.bought as { index, quantity }.
local function Ware(i) return STATE.merchant and STATE.merchant[i] end
GetMerchantNumItems = function() return STATE.merchant and #STATE.merchant or 0 end
GetMerchantItemID = function(i) local w = Ware(i) return w and w.id end
GetMerchantItemMaxStack = function(i) local w = Ware(i) return w and w.maxStack end
C_MerchantFrame = {
  GetItemInfo = function(i)
    local w = Ware(i)
    if w then return { price = w.price, stackCount = w.stack } end
  end,
}
BuyMerchantItem = function(i, quantity)
  local w = Ware(i)
  STATE.bought = STATE.bought or {}
  table.insert(STATE.bought, { i, quantity })
  STATE.bags[w.id] = (STATE.bags[w.id] or 0) + quantity
  STATE.money = STATE.money - quantity * w.price / w.stack
end
-- Who the player is, as Forever answers: a first and a second name, the second where a realm
-- used to be - made up, the player record's name and surname when it has them.
-- STATE.secretName makes the name a secret value.
UnitFullName = function()
  local r = STATE.units.player or {}
  return r.name or "Aldric", r.surname or "Vane"
end
GetRealmName = function() return STATE.realm or "Forever" end
-- STATE.normalizedRealm: the realm without spaces, where it differs
GetNormalizedRealmName = function() return STATE.normalizedRealm or STATE.realm or "Forever" end
GetGuildInfo = function() return STATE.guild end
-- The Unix clock, moving with STATE.now as GetTime does
time = function() return 1800000000 + math.floor(STATE.now or 0) end
GetCVar = function(name)
  if name == "ActionButtonUseKeyDown" then return STATE.keyDown and "1" or "0" end
end
UnitLevel = function(u) local r = U(u or "player") return r and r.level or 25 end
GetBuildInfo = function() return "1.60.1", "70450", "Oct 1 2026", 16001 end
date = function() return "2026-10-18 12:00" end
-- STATE.secrets: further values made secret, e.g. a spell ID
issecretvalue = function(v)
  if STATE.secrets and STATE.secrets[v] then return true end
  if STATE.secretName ~= true then return false end
  local first, second = UnitFullName()
  return v == first or v == second
end
-- The client's stack text; a fixed mark the specs find
debugstack = function() return "STACK" end
-- BugGrabber: its errors are STATE.bugs; addon.load removes it for world.bugGrabber == false
BugGrabber = { GetDB = function() return STATE.bugs or {} end }

-- The minimap: 140 px wide, centred where Methods:GetCenter puts frames (STATE.center)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
-- The client's options: the registered panel and category, in STATE.options
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name)
    STATE.options = { panel = panel, category = { name = name } }
    return STATE.options.category
  end,
  RegisterAddOnCategory = function(category) STATE.options.registered = category end,
}
-- The cursor at STATE.cursor = { x, y }; IsMouseButtonDown answers STATE.mouseDown
GetCursorPosition = function() local c = STATE.cursor or { 0, 0 } return c[1], c[2] end
IsMouseButtonDown = function() return STATE.mouseDown == true end
-- STATE.shift: the Shift key is held
IsShiftKeyDown = function() return STATE.shift == true end
LOCALIZED_CLASS_NAMES_MALE = {}
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
  LOCALIZED_CLASS_NAMES_MALE[class] = "class" .. class
end
-- A class colour different for every class, so a spec can tell them apart
C_ClassColor = {
  GetClassColor = function(class)
    local n = 0
    for i, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
      if c == class then n = i end
    end
    return { GetRGB = function() return n / 10, 1 - n / 10, 0.5 end }
  end,
}
GetMoney = function() return STATE.money or 0 end
GetTime = function() return STATE.now or 0 end
C_CurrencyInfo = { GetCoinTextureString = function(copper) return copper .. "c" end }
-- STATE.spellChecks[id] counts the questions
IsPlayerSpell = function(id)
  STATE.spellChecks = STATE.spellChecks or {}
  STATE.spellChecks[id] = (STATE.spellChecks[id] or 0) + 1
  if STATE.removed and STATE.removed[id] then return false end
  return STATE.known[id] == true
end
