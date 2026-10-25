# SmartBlessingBar

A paladin blessing manager for **WoW Forever** (Classic content on the modern Retail client,
Interface 16001): it blesses your group by class, works around what other paladins already gave,
and casts Salvation, auras and Righteous Fury, with a modern look.

![The bar, the handle's tooltip and the settings' General tab](.previews/03-general-settings.jpg)

Exceptions for single characters come later.

## Installation

Install it with the [CurseForge](https://www.curseforge.com/wow/addons/smartblessingbar) app,
[Wago](https://addons.wago.io/addons/smartblessingbar) or WowUp, which also keep it up to
date. By hand:
download `SmartBlessingBar-vX.Y.Z-forever.zip` from the
[GitHub releases](https://github.com/ZulshiBLN/SmartBlessingBar/releases) and unpack it into
`Interface\AddOns` of your WoW Forever installation, so that
`Interface\AddOns\SmartBlessingBar` holds `SmartBlessingBar.toc`.

The addon loads for paladins only.

## The bar

| Button | Left click | Right click |
|---|---|---|
| Aura | Cast the first aura of your list no other paladin runs, highest rank you know - highlighted until it runs | – |
| Righteous Fury | Cast Righteous Fury - highlighted while it is missing or about to run out (see the Priorities tab) and your group's role check made you tank; greyed otherwise, also alone | – |
| Blessings | Cast the next blessing your group needs - highlighted while one is left | Open the Priorities tab |
| Salvation | Cast the next Salvation, Mass Salvation or Revoke your group needs - highlighted while one is left | – |
| Handle (the side the bar grows from; always shown, or only under the mouse with Show anchor off) | Drag to move | Lock or unlock |

A middle click on the handle opens or closes the settings; hover it for a tooltip with the
lock state and its clicks.

**Buff & Run** - a middle click on the blessing button blesses the player you target and then
targets the next friendly player, so you can bless passing players by clicking again and
again. Each gets the first blessing of his class's list he lacks, in the highest normal rank
that fits him. One carrying a blessing of yours is passed, unless it is of that same kind and
weaker than the rank you would give - then he gets the stronger one. The game picks the next player,
sometimes one beyond the blessing's 30 yards: then the click only moves on. A click during the
global cooldown does nothing, so nobody is skipped; in combat a click only moves on. A player
flagged for PvP is passed too - blessing him would flag you - unless "Allow PvP blessing" is
on, or you are flagged for good yourself (/pvp, the portrait menu, a battleground, an arena or
a PvP zone; a flag that runs out does not count). Both are switched on the General tab.

![The blessing button's tooltip with its clicks, beside the Tracking tab](.previews/02-blessing-button-buff-and-run.jpg)

**Auras** come from a priority list on the Priorities tab, so paladins need not agree who runs
which: the button casts the first aura on your list that you know and no other paladin of your
group runs - in a raid, of your subgroup, as an aura reaches no further. An aura you share with
another paladin moves you on to your next one - also while the game shows only yours, as it
does for two equal auras; both of you may then be offered the next one until one casts it.
With every aura taken, it casts the first you
know. In combat it keeps the aura chosen before.

**Blessings.** Nothing is assigned: the addon decides for every member of your group.

- Each class has a priority list, which you can change on the Priorities tab. A member gets
  the first blessing on his class's list that you know and no other paladin has given - in its
  Greater form, or in a rank at least as high as your best. A lower rank counts as missing,
  from someone else and from you - after you learn a higher rank, or where your Greater
  Blessing is stronger than the normal one he carries.
- The default lists, most wanted first:

  | Class | Default |
  |---|---|
  | Warrior, Rogue | Might, Kings, Light |
  | Paladin | Kings, Might, Wisdom, Light |
  | Hunter | Kings, Wisdom, Might, Light |
  | Shaman, Druid | Wisdom, Kings, Might, Light |
  | Priest, Mage, Warlock | Wisdom, Kings, Light, Might |

  Warriors and Rogues never get Wisdom: no spec of theirs uses mana. Might raises melee attack
  power only, so it comes last for the classes that never fight in melee.
- The game refuses a rank on a target more than ten levels below the level you learned it at.
  A low-level member therefore gets the highest rank that reaches him, and a blessing none of
  whose ranks reaches him is skipped for the next on his list.

- A member is done once it carries your blessing of the kind chosen for it, no weaker than your
  best that fits him. One of another kind
  is replaced - a paladin's second blessing on the same target replaces the first - so a change
  of a list is cast at once.
- **Greater or normal:** the stronger form you know is cast. Where both are equally strong, a
  Greater Blessing is cast only in a raid, when at least three members of a class in range lack
  it, and only while you carry a Symbol of Kings. A class gets at most one Greater Blessing from
  you, and it is cast before the normal ones it would overwrite.
- Once you know a Greater Blessing, the number in the middle of the blessing button is how many
  Symbols of Kings you carry: orange at or below the warning threshold, red at 0.
- Blessing of Sanctuary does not exist on WoW Forever.

**Salvation** goes to every member whose role is not tank - the role the game reports, set by
your group's role check; without one, a class's default, never tank. A tank carrying anyone's
Salvation
gets Revoke. In a raid, a class gets Mass Salvation when the members of it in range who lack
Salvation, tanks not counted, are at least three plus the class's tanks; its tanks get Revoke
after it. Mass Salvation costs a Symbol of Kings. Members too low for Salvation, Mass Salvation
or Revoke - more than ten levels below the level you learned it at - are left out of it; Mass
Salvation and Greater Blessings count only the members they reach. The highlight is the
modern client's glow, as on a spell ready to use.

**Both buttons** show how many casts are left; with none left, no number shows and the highlight
stops. Hover a button to see what a left click casts next and on whom - the class for a
Greater Blessing or Mass Salvation, the member otherwise. Dead, offline and out-of-range
players are left out. A blessing, Salvation or Mass Salvation of yours is renewed when less
than 5 minutes are left (see the Priorities tab); another paladin's counts until it runs out.

**In combat** the game hides who has which buff - in instances and PvP often out of combat
too; the bar then behaves as in combat until the game shows them again. The blessing and Salvation buttons keep the
cast that was first when the fight started - a Greater Blessing or Mass Salvation that would be
followed by casts that cannot happen in combat waits for the end of it; if nothing else is
left, the button keeps its number without the highlight, and its tooltip says so. Once a
button's spell is cast in the fight, its highlight goes out; clicking again casts it again.
Everything updates when combat ends, or, in an instance, once the game shows the buffs again.

## Settings

`/sbb`, a middle click on the handle, the minimap button, the AddOn menu next to the minimap,
or the button in the game's Options > AddOns open the settings window; Escape closes it. It
closes when combat starts and opens again when combat ends. Every change takes effect at once.

**General**
- Language: automatic (the client's) or any of the eleven, switched without a reload.
- Hide the bar in combat; hide the minimap button.
- Scale, 0.5 to 2.0: drag the slider or type a number (a comma works too). Beside it **Window
  background (%)** for the settings and report windows: 0 shows none, 100 a solid one, 60 the
  look they always had.
- Border on or off; beside it **Show anchor**, on by default: the handle stays visible - off,
  it shows only under the mouse. The background color with its opacity.
- Orientation (horizontal or vertical) and the direction the bar grows.
- **Demo mode**: plans a blessing and Salvation for every class, each with its default role,
  shows a sample Symbol count, and treats every aura and blessing as learned. Clicks cast
  nothing; the chat says what would be cast. The overview shows a made-up raid of 40 instead
  of your group. Demo mode is off after every login and cannot be switched in combat.
- **Buff & Run** on the blessing button's middle click, on by default; not switched in
  combat. Under it, **Allow PvP blessing**, off by default: off, Buff & Run passes players
  flagged for PvP unless you are flagged for good. Dimmed while Buff & Run is off.
- Report bug, and Reload UI.

**Tracking**
- Aura and Righteous Fury: show the button or not, the highlight's color and its speed.
- Blessings: show the button or not, the highlight's color and speed, and the color of the
  count on the blessing and Salvation buttons.
- Salvation: show the button or not, the highlight's color and its speed.

**Supplies**
- Symbol of Kings: the warning threshold (0 = no warning) and the warning and empty colors of
  its count.
- Auto-buy: at a vendor that sells them, Symbols of Kings are bought up to the amount you want
  in your bags, never spending below the gold reserve. Only once you know a Greater Blessing.
  The chat says what was bought and what it cost.

**Priorities** - a middle click on the minimap button opens the window here.
- Renew with less than this many minutes left (0 = once run out), side by side: blessings and
  Salvation, 0 to 15, 5 by default; Righteous Fury, 0 to 5, 3 by default.
- **Auras:** the aura list - drag an aura left or right to reorder it.
- **Blessings:** a row per class, named in its class colour, with its priority list, in two
  columns: drag a blessing left or right to reorder it; a right click switches it off for
  that class (greyed at the end, never given) or on again. At least one stays on. "Enable all" switches every blessing on
  again, the order kept; "Default" restores every row and the aura list.
- **The overview** of your group in two columns, twenty members before it scrolls: sorted by
  class, each name in its class colour, a tank or healer - the role from the game - with the
  game's role icon before the name; a name too long for its place is cut with "...". In front of a paladin's blessings
  the aura he runs, then the blessings and the Salvation each member carries. Yours glow
  gold; the blessing you would give him next is faint, with a "+". Members dead, offline or
  out of sight are dimmed, and so is one out of range of the blessing you would give him next. Hover an icon for the spell, who gave it - "another
  paladin" for one outside your group - and the minutes left. In demo mode it shows a made-up
  raid of 40, the same until `/reload`: all classes, four paladins with their auras, you one of
  them, tanks and healers, a few members dimmed or without Salvation, and names from 2 to 12
  letters, one cut and one just fitting its place.

![The Priorities tab with the class lists and the overview of demo mode's raid](.previews/01-priorities-and-group-overview.jpg)

**Order**
- Drag the rows to reorder the bar's four buttons. "Default" restores aura, Righteous Fury,
  blessings, Salvation.


**Macros** - prepared; macros follow in a later version.

**Minimap button** - left click opens the settings, right click locks or unlocks the bar, middle
click opens the Priorities tab, drag moves it around the minimap.

| Supplies, with Symbol of Kings auto-buy | Order, the bar's buttons |
|---|---|
| ![Supplies tab](.previews/05-symbol-of-kings-autobuy.jpg) | ![Order tab](.previews/06-button-order.jpg) |

| Eleven languages, switched at once | The minimap button |
|---|---|
| ![The language list on the General tab](.previews/04-eleven-languages.jpg) | ![The minimap button's tooltip](.previews/07-minimap-button.jpg) |

**Bug report** - `/sbb bug` or "Report bug" opens a short form: what happened, where, and
details. The window turns it, with what the addon knows - its errors from BugSack, if
installed, its last actions and state - into one code. Copy it with Ctrl+C and paste it into the
form the link opens; "Show content" shows everything the code holds. It opens out of combat
only. What it holds and filters out: [Bug reports](#bug-reports).

## Chat commands

| Command | Action |
|---|---|
| `/sbb` | Open or close the settings window |
| `/sbb help` | List the commands |
| `/sbb lock` | Lock or unlock the bar |
| `/sbb reset` | Move the bar back to its start position (not in combat) |
| `/sbb bug` | Open the bug report |

## Key bindings

In a section of their own under Options > Key Bindings > SmartBlessingBar:

| Key | Action |
|---|---|
| Cast next buff | One press, one cast: what the first highlighted button of the bar would cast, in the bar's order - the aura, Righteous Fury, your group's next blessing, its next Salvation, Mass Salvation or Revoke. |
| Buff & Run | The blessing button's middle click: blesses the target, then targets the next friendly player. Also with the blessing button hidden. One player per press - holding the key does not repeat it. |
| Set priorities | Opens or closes the settings on the Priorities tab; not in combat. |

In combat the keys do what the bar does: Cast next buff casts what it held when the fight
started, Buff & Run only targets the next player.

## Languages

enUS, deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW. The language follows the client
unless you choose another in the settings.

## Code structure

| File | Content |
|---|---|
| `Locales.lua` | All texts per language, locale switching |
| `Data.lua` | Spell IDs by rank, roles and the default priority lists, defaults, the settings' schema version |
| `Core.lua` | Paladin check, chat output, language registry, secure attributes, saved variables, demo mode |
| `Blessings.lua` | Known spells and ranks, roles, group scan with members' buffs kept up to 10 s, what others gave, the blessing and Salvation planner, the aura choice |
| `Bar.lua` | Bar, handle, position and lock, layout, scale and look, Symbol count, refresh |
| `SelfBuffs.lua` | Aura and Righteous Fury buttons and their highlight |
| `Queue.lua` | Blessing and Salvation buttons, their queue, count and tooltip, the buff key |
| `Bindings.xml` | The key bindings the game's Key Bindings offer |
| `Demo.lua` | Demo mode's chat output and the overview's made-up raid |
| `Overview.lua` | The overview on the Priorities tab: members by class in two columns, their auras and what they carry |
| `Merchant.lua` | Symbol of Kings auto-buy |
| `Minimap.lua` | Minimap button, AddOn compartment, Options entry, the Priorities key |
| `Privacy.lua` | What a bug report may hold: the allowlist, the name and path filter, hidden characters, the size cap |
| `ReportCode.lua` | The bug report as one code, and back |
| `Report.lua` | Bug report: state snapshot, errors, content and window |
| `Settings.lua` | Settings window, tabs, widgets, color picker |
| `SettingsPages.lua` | The General, Tracking, Supplies, Priorities, Order and Macros pages |
| `Main.lua` | Startup and chat commands |
| `Log.lua` | The bug report's action log, in memory only |

`tools/` (not in the release zip) holds the bug report decoder and the store screenshots' title
tool; [tools/README.md](tools/README.md) says how to run them.

Modules share code through the addon namespace (`ns`). Each file is its own Lua chunk, which keeps
every file far below Lua's limit of 200 local variables per chunk.

## Privacy and security

- No network communication; no addon messages are sent yet - what other paladins gave is read
  from the buffs themselves - and no chat messages to other players.
- No dynamic code: secure snippets and macros are built from constants only.
- Saved settings are validated at login (types and ranges), so damaged files cannot break the
  addon.
- No personal data is stored: only your choices and the bar's position.

### Bug reports

A bug report leaves the game only when you copy its code and send it. **A GitHub issue is
public**: everyone can read it. Write no names or personal data into the form's fields.

- **What it holds, and why** - to find and fix the bug you report: your description, where it
  happened and your details; the addon's version and its settings (known keys only); your
  client's version, build and language; your class, level range (e.g. 30-39) and whether you are
  solo, in a party or a raid; this addon's Lua errors of the current session with how long ago
  they came, counted from the addon loading, and whether in combat; its last 50 actions (clicks with spell IDs and unit tokens
  such as `party1`, combat, group size, settings changes); the state of its buttons and queues,
  your Symbols of Kings count, your group by class and your buffs by spell ID; the names and
  versions of your loaded addons, as conflicts need them.
- **What it never holds** - chat, mail or whispers; positions or zones; date or clock time.
  Strings the addon does not know are shown by their length only. The times are relative, but
  with the time GitHub shows on your post they tell roughly when you played.
- **What it filters out** - free text and error messages pass a filter for character, guild,
  group and pet names the game knows right now - on Forever both of a character's names -
  GUIDs, BattleTags, account folders, e-mail addresses, the WTF folder and file paths outside
  `Interface/AddOns`, and characters that show nothing. Names are matched as whole words, in
  any case for Western European (Latin-1) and basic Cyrillic letters; beside punctuation and
  inside Chinese, Japanese or Korean text they are found too. A name you type that the game does
  not know, one that is part of a longer word - an addon folder named after yourself, say - or
  one in other capitals (`Ł`, Greek) can still remain. Check with "Show content".
- **Where it is kept** - the action log in memory only, gone at logout; nothing is written to
  your saved variables for the report.
- **Deletion** - see "Data protection" below.

### Data protection

This is not legal advice; it says how bug reports are handled.

- **Who is responsible** - ZulshiBLN, the author of SmartBlessingBar, Switzerland. Contact
  through GitHub: an issue, or - for anything that should not be public - a private
  vulnerability report on this repository (*Security > Report a vulnerability*).
- **Why** - you choose to send a report; it is used only to fix the bug you report (legitimate
  interest, GDPR Art. 6(1)(f); Swiss FADP). Nothing leaves the game unless you copy and post it.
- **Who receives it** - GitHub, Inc. (USA) hosts the issue. It is public, and people who watch
  the repository get a copy by e-mail. GitHub is responsible for what it hosts under its own
  [privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement);
  for transfers to the USA it relies on the EU-U.S. and Swiss-U.S. Data Privacy Framework.
- **How long** - once the bug is fixed, the author removes the code, with its edit history, from
  the issue; on request earlier, or the whole issue. Copies outside GitHub - e-mail
  notifications, web archives - cannot be recalled.
- **Your rights** - access, correction, deletion and objection, through the contact above. You
  may also complain to the Swiss FDPIC or to the data protection authority of your EU country.
- **Under 16** - ask a parent before you post a report.
- **An older version** - a report from 1.0.0 carries a "Date:" line and names of settings it
  does not filter. Update first; if you cannot, remove the date and any names before you post.

## License

MIT, see [LICENSE](LICENSE). Author: ZulshiBLN. World of Warcraft screenshots and game art are
(c) Blizzard Entertainment and not covered by the MIT license. The font of the screenshots'
titles, Cinzel, is under the SIL Open Font License ([tools/fonts/OFL.txt](tools/fonts/OFL.txt));
it is a tool's and never ships with the addon.
