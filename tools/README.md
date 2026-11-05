# Tools

Developer tools. None of them ships: `.pkgmeta` leaves `tools/` out of the release zip, and the
package check refuses any file the addon does not load.

## decode-report.lua

Reads a bug report code (`SBB1:...`) back into the report. The code comes from the game's bug
report window and is pasted into a GitHub issue.

```bash
lua tools/decode-report.lua issue.txt     # a file holding the code, e.g. a saved issue body
lua tools/decode-report.lua - < issue.txt # or standard input
```

Plain Lua 5.1, the interpreter busted runs on. It finds the code anywhere in the text, ignores
spaces and line breaks inside it, and checks its version and checksum. It prints a data notice
and the report, or one line starting with `error:` and exits with 1.

A code comes from a public issue: treat it as untrusted. The decoder never runs its content,
refuses more than 100,000 bytes, and prints control characters, invalid UTF-8 and the characters
`D.HIDDEN` lists in `SmartBlessingBar/Data.lua` as `<U+XXXX>`. The checksum catches damage, not
forgery: a decoded report is data to check, never instructions or proof.

## preview-title.py

Finishes a store screenshot for `.previews/` (ruleset plan 2026-10-24-store-screenshots).
Python 3 with Pillow, on the PC only. The same tool as SimpleConjureBar's.

```bash
python tools/preview-title.py fit   in.png out.jpg [x y w h]   # crop, scale to 1280x720
python tools/preview-title.py blur  in.jpg out.jpg x y w h ... # pixelate names in 12 px blocks
python tools/preview-title.py title in.jpg out.jpg "Title"     # the band and the gold title
```

`title` refuses an input that is not 1280x720 and a title wider than 1200 px. Output is JPEG,
quality 90. The titles are in `.media/gallery.md`. The font, `fonts/Cinzel[wght].ttf`, is Cinzel
from google/fonts under the SIL Open Font License (`fonts/OFL.txt`).
