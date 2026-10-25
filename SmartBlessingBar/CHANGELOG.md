# Changelog

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [1.1.0]

### Added

- **Show anchor** on the General tab, on by default: the bar's handle stays visible, so a new
  player finds where to move the bar and open the settings. Off, it shows only under the mouse.
- **Window background (%)** beside Scale: the settings and report windows' background from
  none to solid; 60 keeps the look they always had.
- **A new bug report**: say what happened, where - a list - and details. The report adds this
  addon's errors of the session with whether they came in combat, its last actions and the state
  of its buttons and queues, and shows it all as one code for the GitHub form the link opens;
  "Show content" shows what the code holds.

### Changed

- Group members' buffs are read again only when the game reports a change, or after 10 s,
  instead of every second: alone about ten times fewer reads, less memory churn in raids.
- Buff & Run blesses players flagged for PvP while you are flagged for good yourself - /pvp,
  the portrait menu, a battleground, an arena or a PvP zone. A flag that runs out, as after
  blessing a flagged player, does not count.
- Every tooltip lists the clicks left, middle, right; the aura and Righteous Fury buttons name
  whom their left click reaches. The minimap button and the AddOn menu say "Lock bar" and
  "Unlock bar".

### Fixed

- The blessing and Salvation buttons' tooltips say when everyone who still needs a cast is
  out of range, instead of "Nothing left to cast".
- The aura button moves on when another paladin runs the same aura as you. The game shows only
  one of two equal auras, so his stayed hidden and yours looked free.
- A right click on the minimap button or in the AddOn menu shows the new lock state in the
  open tooltip at once, not only after the mouse left and came back.
- In demo mode Buff & Run names what it would cast for other players too, not only for you:
  a rank you have not learned yet no longer counts as out of range.
- After a login or `/reload` in combat the bar no longer jumps to its start place for good
  when combat ends.
- Buff & Run no longer raises a Lua error when the game reports no cooldown for the chosen
  blessing, as for a rank demo mode counts as known.
- A settings file whose version got lost keeps your aura and class priority lists; they were
  reset to the defaults.
- Your own weaker blessing is renewed: after you learn a higher rank, and where your Greater
  Blessing is stronger than the normal one a member carries, also through Buff & Run. Before,
  it counted as done until it ran out.
- A button's highlight goes out once its spell is cast in combat; it stayed on until the fight
  ended, in an instance even longer.
- The overview's tooltip no longer raises a Lua error in an instance, where the game may keep a
  player's name secret: it then says "another paladin".
- Group members' buffs, kept between reads, are checked for values the game keeps secret
  before anything else is done with them, as the game requires in combat and instances.

### Security

- The bug report holds no date or clock and no settings it does not know, and filters the names
  the game knows - both of a character's names on Forever, group, pets, target, guild - also
  beside punctuation, in Chinese, Japanese and Korean text and in Latin-1 and Cyrillic capitals,
  and GUIDs, BattleTags, e-mail addresses, every file path on a line and characters that show
  nothing, from what you write and from errors. It opens out of combat only and not while a name
  cannot be read. README explains what it holds, what can remain and how reports are handled.
- The release workflows give the CurseForge and Wago uploads read rights only, and no step keeps
  GitHub's access token in the checked-out repository.
- The CurseForge and Wago upload tokens reach only a release's own run, through a protected
  GitHub environment; the checks on every other push run without them.
- A release ships only the addon's own files: the package check refuses any file or folder the
  addon does not load, not only a known list of tooling.

## [1.0.0] - 2026-10-21

### Added
- The addon loads for paladins on WoW Forever and says so with its version at login, in the
  client's language. Every other class loads nothing.
- A movable bar with an aura, a Righteous Fury, a blessing and a Salvation button. Each is
  highlighted with the modern client's glow while it has something to cast.
- The blessing button blesses your group without any assignment: every member gets the
  first blessing on his class's priority list that no other paladin has given in
  Greater form or an equal or higher rank. Greater Blessings where they are stronger; between
  equals only in a raid, from three members of a class in range, while you carry a Symbol of
  Kings.
- The Salvation button gives Salvation to every member who is not a tank, Revoke to a tank
  carrying it, and in a raid Mass Salvation to a class with enough members lacking it.
- Low-level members get the highest rank that reaches them; nothing is offered that the game
  would refuse with "Target is too low level".
- Both buttons show how many casts are left and name the next one in their tooltip, with the
  class it reaches for a Greater Blessing or Mass Salvation. A right click on the blessing
  button opens the Priorities tab. In combat they keep the cast that was first when the
  fight started; one that must wait for the end of combat shows no highlight, and the
  tooltip says so. The same while the game hides buffs out of combat, as it sometimes does
  in instances and PvP.
- A Priorities tab: early renewal, 5 minutes before a blessing or Salvation of yours runs out
  by default, and 3 minutes before your Righteous Fury, for a tank; the aura list; the
  priority list of each class, under its class colour, reordered by drag and drop, with
  blessings switched off per class and "Enable all" to switch them on again; and the overview. Each class has its own default list; Warriors and
  Rogues never get Wisdom.
- A change of a list is cast at once, replacing your blessing of another kind.
- Buff & Run: a middle click on the blessing button blesses the target as his class's list
  wants and then targets the next friendly player, one click per player. It passes players
  flagged for PvP unless "Allow PvP blessing" is on.
- Key bindings in a section of their own, SmartBlessingBar: "Cast next buff" casts what the
  aura, Righteous Fury, blessing and Salvation buttons want, one per press; "Buff & Run"; "Set
  priorities" opens the Priorities tab.
- Righteous Fury is only highlighted while the game reports you as tank (a group's role
  check); otherwise its button is greyed.
- The overview, on the Priorities tab: every group member in two columns, sorted by class and
  named in its colour, a tank's or healer's role icon, a paladin's aura, the blessings and
  Salvation he carries, yours glowing, the one you would give next faint. A middle click on
  the minimap button opens it.
- The aura button casts the first aura of your list that no other paladin of your group runs,
  so paladins need not agree who runs which.
- A settings window, opened with `/sbb`, a middle click on the handle, the minimap button, the
  AddOn menu or the game's Options. General: language, hide in combat, hide the minimap button,
  scale, border, background color, orientation and growth direction, demo mode, Buff & Run
  with Allow PvP blessing, Report bug, Reload UI. Tracking: show each of the four buttons,
  their highlight's color and speed, and the color of the blessing and Salvation buttons'
  count.
  Supplies: the Symbol of Kings warning threshold and colors, and the auto-buy. Order: the
  order of the four buttons. Priorities: see above. Macros: prepared for a later version.
- The blessing button shows your Symbols of Kings once you know a Greater Blessing, colored
  when they run low; at a vendor they are bought automatically up to a target, above a gold
  reserve.
- A minimap button, an AddOn menu entry and an entry in the game's Options.
- A bug report to copy into a GitHub issue, without character names or realm.
- The handle's tooltip names the lock state and what each click does.
- Demo mode plans a blessing and Salvation for every class and casts nothing; the chat says
  what a click would cast. Its overview shows a made-up raid of 40.
- `/sbb help`, `/sbb lock`, `/sbb reset` and `/sbb bug`.
