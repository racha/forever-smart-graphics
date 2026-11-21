# Contributing to Forever Smart Graphics

Thanks for helping. Bug reports and pull requests are welcome.

## Reporting a bug

Open an issue with:

1. What you did, what you expected and what happened.
2. The lines `/fsg selftest` and `/fsg status` print.
3. Your Smart mode goal, pace and target FPS, and where you were (zone).
4. Any Lua error. Turn on errors with `/console scriptErrors 1`. If the game says something was blocked, also send the lines that name ForeverSmartGraphics from `Logs/taint.log` after `/console taintLog 2` and a `/reload`.

Please crop out character names and chat from screenshots.

## Layout

```
ForeverSmartGraphics/   the addon (this folder is the release zip)
  Core.lua              namespace, saved settings, events, commands
  News.lua              the What's new notes: which to show after an update
  NewsData.lua          generated from CHANGELOG.md, never edited by hand
  Catalog.lua           every setting: range, description, FPS impact, presets
  Profiles.lua          profiles and their assignment to places
  Location.lua          where you are
  Apply.lua             the one place that writes settings
  Smart.lua             Smart mode
  Calibrate.lua         Find my best settings
  Panel/                the window, notices and the minimap readout
  Media/                the addon's own textures
  tests/                plain-Lua specs with WoW API stubs
```

## Running the checks

You need Lua 5.1 (the game's version). Lua 5.4 works too.

```bash
find ForeverSmartGraphics -name '*.lua' -exec luac -p {} +
```

```bash
for spec in ForeverSmartGraphics/tests/*_spec.lua; do lua "$spec"; done
```

`lua ForeverSmartGraphics/tests/smart_replay.lua` replays Smart mode against a small model of a GPU and prints how many changes it makes.

## Rules for code

- Lua 5.1 syntax. Write settings only through `Apply.Write`.
- Never touch Blizzard's Menu, Dropdown, StaticPopup or Settings frames: they taint.
- Nothing changes in combat unless the player presses a button.
