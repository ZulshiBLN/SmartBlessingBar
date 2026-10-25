-- SmartBlessingBar - static data
-- Spell IDs, layout constants and default settings. Loaded before every other module.
-- IDs are the Classic Era IDs, checked on WoW Forever 1.60.1.70450 (ruleset research
-- 2026-10-18-paladin-facts). Blessing of Sanctuary does not exist there and is left out.

local _, ns = ...

local D = {}
ns.D = D

-- Schema version of SmartBlessingBarDB; a change to its shape raises it and ships a migration
-- in ns.InitDB() (ruleset: project.md, Data)
D.DB_VERSION = 12

-- Salvation is no Blessing on Forever: it takes no blessing slot (checked in game,
-- ruleset decisions 2026-10-19). Revoke, new on Forever, removes it.
D.SALVATION      = 1038
D.MASS_SALVATION = 25895
D.REVOKE         = 1325499

---------------------------------------------------------------------------
-- Spells, lowest rank first. IDs do not rise with rank (Devotion Aura rank 2 is 10290,
-- rank 3 is 643), so code walks these lists and never compares IDs.
---------------------------------------------------------------------------
D.BLESSINGS = {
    MIGHT     = { normal = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 } },
    WISDOM    = { normal = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 } },
    KINGS     = { normal = { 20217 }, greater = { 25898 } },
    LIGHT     = { normal = { 19977, 19978, 19979 }, greater = { 25890 } },
}
D.BLESSING_ORDER = { "MIGHT", "WISDOM", "KINGS", "LIGHT" }

-- The normal rank each Greater rank equals in strength, by index into the normal list: read
-- in game on Forever (Might 112/133 AP, Wisdom 36/40 mana, Light 400/115; ruleset decisions
-- 2026-10-19). Equal strengths make the group decide between the two forms.
D.GREATER_EQUALS = {
    MIGHT  = { 6, 7 },
    WISDOM = { 5, 6 },
    KINGS  = { 1 },
    LIGHT  = { 3 },
}

---------------------------------------------------------------------------
-- Roles (ruleset plan 2026-10-19-blessing-core)
---------------------------------------------------------------------------
D.ROLES = { "TANK", "HEALER", "MELEE", "RANGED", "CASTER" }
-- The roles the game reports as one, "DAMAGER"
D.DAMAGE_ROLES = { MELEE = true, RANGED = true, CASTER = true }
-- The roles a class can play, its default first: the role used when the game reports none.
-- The shaman counts as one that can tank, as sources disagree (ruleset decisions 2026-10-19).
D.CLASS_ROLES = {
    WARRIOR = { "MELEE", "TANK" },
    PALADIN = { "MELEE", "HEALER", "TANK" },
    HUNTER  = { "RANGED" },
    ROGUE   = { "MELEE" },
    PRIEST  = { "HEALER", "CASTER" },
    SHAMAN  = { "HEALER", "CASTER", "MELEE", "TANK" },
    MAGE    = { "CASTER" },
    WARLOCK = { "CASTER" },
    DRUID   = { "CASTER", "HEALER", "MELEE", "TANK" },
}
-- A class's default list, most wanted first, and the blessings it can have at all (Michel's
-- orders, ruleset plan 2026-10-20-class-defaults). Might raises melee attack power only, in
-- Forever too: last for the classes without melee in any spec. Warriors and Rogues use no
-- mana in any spec: no Wisdom.
D.CLASS_LISTS = {
    WARRIOR = { "MIGHT", "KINGS", "LIGHT" },
    ROGUE   = { "MIGHT", "KINGS", "LIGHT" },
    PALADIN = { "KINGS", "MIGHT", "WISDOM", "LIGHT" },
    HUNTER  = { "KINGS", "WISDOM", "MIGHT", "LIGHT" },
    SHAMAN  = { "WISDOM", "KINGS", "MIGHT", "LIGHT" },
    DRUID   = { "WISDOM", "KINGS", "MIGHT", "LIGHT" },
    PRIEST  = { "WISDOM", "KINGS", "LIGHT", "MIGHT" },
    MAGE    = { "WISDOM", "KINGS", "LIGHT", "MIGHT" },
    WARLOCK = { "WISDOM", "KINGS", "LIGHT", "MIGHT" },
}
-- In a raid, the members of a class who must lack a blessing before its Greater form, or
-- Mass Salvation, pays (Michel, 2026-10-19)
D.RAID_GREATER_MIN = 3
-- The game refuses a spell on a target more than this many levels below the level the spell
-- is learned at: "Target is too low level" (seen in game, 2026-10-19)
D.LEVEL_GAP = 10

D.AURAS = {
    DEVOTION      = { 465, 10290, 643, 10291, 1032, 10292, 10293 },
    RETRIBUTION   = { 7294, 10298, 10299, 10300, 10301 },
    CONCENTRATION = { 19746 },
    SHADOW        = { 19876, 19895, 19896 },
    FROST         = { 19888, 19897, 19898 },
    FIRE          = { 19891, 19899, 19900 },
    SANCTITY      = { 20218 },
}
D.AURA_ORDER = { "DEVOTION", "RETRIBUTION", "CONCENTRATION", "SHADOW", "FROST", "FIRE", "SANCTITY" }

D.RIGHTEOUS_FURY = 25780

-- Reagent of every Greater Blessing
D.SYMBOL_OF_KINGS = 21177

-- Demo mode's Symbol count on the blessing button; the auto-buy still reads the real bags
D.DEMO_SYMBOLS = 3
-- Seconds after a purchase in which no new one starts: the bag count lags behind it by more
-- than one second on Forever (ruleset decisions, 2026-10-18)
D.BUY_LOCK = 3

-- The classes, in the order the planner walks them and demo mode shows them
D.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- The bar's default order: aura, Righteous Fury, blessing, Salvation (ruleset plan
-- 2026-10-19-blessing-core)
D.DEFAULT_ORDER = { "AURA", "FURY", "BLESSING", "SALVATION" }

-- Where bug reports go: the issue form with one field for the code
-- (.github/ISSUE_TEMPLATE/bug_report.yml)
D.BUG_REPORT_URL = "https://github.com/ZulshiBLN/SmartBlessingBar/issues/new?template=bug_report.yml"

-- Where a bug happened, as the report form offers it; the report carries the key, the form the
-- text AREA_<key> (ruleset plan 2026-10-24-bug-report)
D.REPORT_AREAS = { "BLESSINGS", "SALVATION", "AURA", "FURY", "BUFF_RUN", "PRIORITIES", "OVERVIEW",
    "SUPPLIES", "KEYS", "SETTINGS", "COMBAT", "OTHER" }
-- The fields a bug report holds, one pattern per kind of line, and nothing else: a spec checks
-- every line of a report against this list. A new field needs an entry here and a line in
-- README's privacy section first (ruleset plan 2026-10-24-bug-report).
D.REPORT_FIELDS = {
    { pattern = "^$" },
    { pattern = "^## SmartBlessingBar bug report$" },
    { pattern = "^%*%*Description:%*%* " },                 -- player's text, filtered
    { pattern = "^%*%*Area:%*%* [%u_]+$" },
    { pattern = "^%*%*Details:%*%* " },                     -- player's text, filtered
    { pattern = "^%- Addon version: [%w%.%-]+$" },
    { pattern = "^%- Client: [%w%.]+ %(build %w+, interface %d+%)$" },
    { pattern = "^%- Client locale: %a+, addon language: [%a<>:%d]+$" }, -- a code or <text:N>
    { pattern = "^%- Character: %u+, level %d+%-%d+, %a+$" }, -- class token, level band, group kind
    { pattern = "^%- Settings: " },                         -- known keys, allowlisted values
    { pattern = "^%*%*Lua errors" },
    { pattern = "^Error %d+ %(x%d+, [%w ,]+, combat: %a+%):$" },
    { pattern = "^```$" },
    { pattern = "^msg " },                                  -- error message, filtered
    { pattern = "^at " },                                   -- stack line, filtered
    { pattern = "^local " },                                -- locals rebuilt by allowlist
    { pattern = "^%*%*Last actions %(seconds since load%):%*%*$" },
    { pattern = "^log " },                                  -- generated, allowlisted values
    { pattern = "^%*%*State:%*%*$" },
    { pattern = "^state " },                                -- generated, allowlisted values
    { pattern = "^%*%*Loaded addons:%*%*$" },
    { pattern = "^addon " },                                -- folder and version, filtered
    { pattern = "^%[%.%.%. cut: the report is too long%]$" },
}
D.REPORT_CUT = "[... cut: the report is too long]"
D.REPORT_MAX_BYTES = 20000 -- fits a GitHub issue (65,536) also as a code, and stays readable
-- Strings a report may carry as they are; any other string becomes <text:N>, its length only.
-- Settings keys and the addon's own keys (buttons, families, classes, roles) count as safe too.
D.REPORT_SAFE = {
    "^player$", "^target$", "^focus$", "^mouseover$", "^pet$", "^party%d$", "^raid%d%d?$", "^NPC$",
    "^%-?%d+%.?%d*$", "^true$", "^false$", "^nil$",
    "^spell$", "^macro$", "^type%d?$", "^spell%d?$", "^unit%d?$", "^macrotext%d?$",
    "^UIParent$", "^TOP$", "^BOTTOM$", "^LEFT$", "^RIGHT$", "^CENTER$", "^TOPLEFT$", "^TOPRIGHT$",
    "^BOTTOMLEFT$", "^BOTTOMRIGHT$",
    "^%l%l%u%u$", "^auto$",                                 -- locale codes
    "^/click SmartBlessingBarBuffRun LeftButton 1$", "^/targetfriendplayer$",
}
-- Characters that show nothing, as code point ranges: zero-width and format characters,
-- direction marks, fillers, variation selectors, tag characters, line separators. Inside or
-- beside a name they hide it, in a decoded report they hide text from the reader. The report
-- drops them, tools/decode-report.lua shows them as <U+XXXX> (ruleset plan
-- 2026-10-24-report-filter-fixes).
D.HIDDEN = {
    { 0xAD, 0xAD }, { 0x34F, 0x34F }, { 0x600, 0x605 }, { 0x61C, 0x61C }, { 0x6DD, 0x6DD },
    { 0x70F, 0x70F }, { 0x890, 0x891 }, { 0x8E2, 0x8E2 }, { 0x115F, 0x1160 }, { 0x17B4, 0x17B5 },
    { 0x180B, 0x180F }, { 0x200B, 0x200F }, { 0x2028, 0x202E }, { 0x2060, 0x206F },
    { 0x3164, 0x3164 }, { 0xFE00, 0xFE0F }, { 0xFEFF, 0xFEFF }, { 0xFFA0, 0xFFA0 },
    { 0xFFF0, 0xFFFB }, { 0x110BD, 0x110BD }, { 0x110CD, 0x110CD }, { 0x13430, 0x13455 },
    { 0x1BCA0, 0x1BCA3 }, { 0x1D173, 0x1D17A }, { 0xE0000, 0xE007F }, { 0xE0100, 0xE01EF },
}

---------------------------------------------------------------------------
-- Look: SimpleConjureBar's, so both addons read as one family
---------------------------------------------------------------------------
D.SIZE, D.GAP, D.PAD = 36, 4, 7 -- button size, gap between buttons, bar padding
D.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
D.BG_COLOR     = { r = 0, g = 0, b = 0, a = 0.6 }       -- bar background
D.BORDER_COLOR = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
D.HANDLE_UNLOCKED = { r = 0.41, g = 0.8, b = 0.94, a = 0.6 }
D.HANDLE_LOCKED   = { r = 0.9, g = 0.25, b = 0.2, a = 0.6 }

-- The buttons' glow: the modern client's proc loop, Blizzard's flipbook atlas of 6 x 5 cells,
-- 30 frames, 1.4 times the button (Michel, seen in game; ruleset plan
-- 2026-10-20-button-tips-glow). Desaturated and tinted by the colour setting.
D.GLOW_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
D.GLOW_ROWS, D.GLOW_COLUMNS, D.GLOW_FRAMES = 6, 5, 30
D.GLOW_SCALE = 1.4
-- Seconds per loop for the speeds 1-5 of the settings; 3 is Blizzard's own second
D.GLOW_DURATIONS = { 2, 1.5, 1, 0.75, 0.5 }
D.ANTS_COLOR  = { r = 1, g = 0.82, b = 0.2, a = 1 } -- SimpleConjureBar's default gold

-- The minimap button's ring sits off its texture's centre: the ring moves by RING_OFFSET, and
-- the highlight, background and round icon centre in it at INNER_OFFSET (measured in game by
-- Michel, 2026-10-20). The background is 2 px wider than the icon.
D.MINIMAP_RING_OFFSET  = { 10, -10 }
D.MINIMAP_INNER_OFFSET = { -0.4, 0.4 }
D.MINIMAP_ICON_SIZE    = 21

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
-- Settings with their defaults; numbers carry their range. Colors are copied into
-- the settings, never referenced, so nothing written to the settings changes these tables.
D.SCALE_MIN, D.SCALE_MAX = 0.5, 2.0
-- The settings and report windows' background as it looked before it could be set, in percent:
-- matched by eye in game for SimpleConjureBar, which draws the same dialog texture
D.WINDOW_OPACITY_TODAY = 60
-- Seconds a group member's buffs are kept between refreshes (ruleset plan
-- 2026-10-24-kept-snapshots); his UNIT_AURA drops them sooner
D.SNAPSHOT_MAX_AGE = 10
-- Seconds a left click on a button counts for a cast in combat whose spell ID the client keeps
-- secret (ruleset plan 2026-10-25-rank-glow-fixes)
D.CAST_PRESS_WINDOW = 1
D.ANTS_SPEED_MIN, D.ANTS_SPEED_MAX = 1, 5
D.BOOL_DEFAULTS = {
    showBorder = true, vertical = false, growRev = false, hideCombat = false,
    showAura = true, showFury = true,
    autoBuy = false, hideMinimap = false, showBlessing = true, showSalvation = true,
    buffRun = true, -- version 9 (ruleset plan 2026-10-20-buff-and-run)
    pvpBlessing = false, -- version 10 (ruleset plan 2026-10-20-performance-pvp)
    showAnchor = true, -- version 12 (ruleset plan 2026-10-22-anchor-and-window-background)
}
D.COLOR_DEFAULTS = {
    bg            = D.BG_COLOR,
    auraAntsColor = D.ANTS_COLOR,
    furyAntsColor = D.ANTS_COLOR,
    blessingAntsColor = D.ANTS_COLOR,
    salvationAntsColor = D.ANTS_COLOR,
    countColor    = { r = 1, g = 1, b = 1, a = 1 },
    -- The Symbol count at or below the warning threshold, and at 0: SimpleConjureBar's
    symbolWarnColor = { r = 1, g = 0.6, b = 0.1, a = 1 },
    symbolZeroColor = { r = 1, g = 0.15, b = 0.15, a = 1 },
}
D.NUMBER_DEFAULTS = {
    scale               = { default = 1, min = D.SCALE_MIN, max = D.SCALE_MAX },
    -- Version 12 (ruleset plan 2026-10-22-anchor-and-window-background)
    windowOpacity       = { default = D.WINDOW_OPACITY_TODAY, min = 0, max = 100, integer = true },
    -- Minutes before an aura of mine runs out at which it is renewed; 0 = once it ran out
    renewMinutes        = { default = 5, min = 0, max = 15, integer = true },
    -- The same for Righteous Fury, which lasts 30 minutes; version 11 (ruleset plan
    -- 2026-10-20-fury-renew)
    furyRenewMinutes    = { default = 3, min = 0, max = 5, integer = true },
    auraAntsSpeed       = { default = 3, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    furyAntsSpeed       = { default = 3, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    blessingAntsSpeed   = { default = 3, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    salvationAntsSpeed  = { default = 3, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    symbolWarn          = { default = 5, min = 0, max = 20, integer = true },   -- 0 = no warning
    symbolAmount        = { default = 20, min = 0, max = 100, integer = true }, -- target in the bags
    goldReserve         = { default = 1, min = 0, max = 1000, integer = true }, -- gold never spent
    minimapAngle        = { default = 225, min = 0, max = 360 },                -- 225 = bottom left
}
