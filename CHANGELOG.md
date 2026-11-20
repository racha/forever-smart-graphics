# Changelog

## 1.0.0-beta.4 — 2026-11-20

- New: render scale above 100%. A profile's Render scale slider now goes up to the game's own maximum, as high as 200%, for a sharper picture. Where the game stops at 100% on your display, the tooltip says so.
- New: an Anti-aliasing setting in a profile's Render group: None, FXAA Low, FXAA High, and CMAA where your graphics card supports it.
- New: Smart mode has a Render scale maximum next to its minimum (`/fsg maxscale <percent>`). It stays at 100% until you raise it, and Smart mode goes above 100% last, when everything else is already at its best.
- New: an Eco goal for Smart mode. It caps your FPS at your target to save battery and never spends spare FPS on looks. Your own FPS cap comes back when you leave Eco.
- Fixed: the hover highlight in the New profile window.
- Fixed: the What's new window showed the version with a stray "v".
- Thanks to pwn4321 on Reddit for suggesting render scale above 100% and the FXAA option.

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
