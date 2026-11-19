# Changelog

## 1.0.0-beta.3 — 2026-11-19

- New: hold a profile from a macro. `/fsg profile <name>` uses that profile everywhere, `/fsg profile auto` goes back to switching by location, and `/fsg profile toggle <name>` does both from one button. Your location setup is left alone, and Smart mode keeps adjusting on top of the held profile.
- New: a What's new window opens once after each update and lists what changed. Tick "Never show again" to turn it off; `/fsg whatsnew` brings it back.
- The window shows when a profile is held, and the Overview page has a "Back to automatic" button.

## 1.0.0-beta.2 — 2026-11-19

- Fixed: "What it learned" on the Smart page always showed nothing. It now lists what Smart mode remembers, grouped by kind of place, with Save as profile and Reset.
- Fixed: labels cut off on the Options, Locations and Profiles pages at the default window size.
- The Smart page shows the FPS it is holding when your display tops out below your target.
- The status strip at the top of the window fits its text.

## 1.0.0-beta.1 — 2026-11-17

First public beta.

- Smart mode: holds a target FPS with the best picture your machine can keep. Goal (FPS, Balanced, Fidelity) and Pace (Aggressive, Balanced, Smooth). Ignores short stutters, remembers every zone, changes nothing in combat.
- Profiles covering 38 graphics settings, including hidden engine settings. Presets: Low, Fair, Good, High, Ultra, Beyond Ultra and Max FPS.
- A profile per kind of place (city, open world, dungeon, raid, battleground, arena) and for specific places.
- Find my best settings: a one-time guided run that saves one profile.
- A description and an FPS impact for every setting.
- FPS readout on the minimap that pulses on changes. Every notification is off by default.
- Mouse, keyboard and gamepad.
- Restore your original settings at any time.
