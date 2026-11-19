-- A frozen copy of two versions' notes for panel_spec: the window's layout checks must not move with each release.
local _, ns = ...
ns.NEWS = {
	{ version = "1.0.0-beta.2", date = "2026-11-19", blocks = {
		{ "b", "Fixed: \"What it learned\" on the Smart page always showed nothing. It now lists what Smart mode remembers, grouped by kind of place, with Save as profile and Reset.", 1 },
		{ "b", "Fixed: labels cut off on the Options, Locations and Profiles pages at the default window size.", 1 },
		{ "b", "The Smart page shows the FPS it is holding when your display tops out below your target.", 1 },
		{ "b", "The status strip at the top of the window fits its text.", 1 },
	} },
	{ version = "1.0.0-beta.1", date = "2026-11-17", blocks = {
		{ "p", "First public beta." },
		{ "b", "Smart mode: holds a target FPS with the best picture your machine can keep. Goal (FPS, Balanced, Fidelity) and Pace (Aggressive, Balanced, Smooth). Ignores short stutters, remembers every zone, changes nothing in combat.", 1 },
		{ "b", "Profiles covering 38 graphics settings, including hidden engine settings. Presets: Low, Fair, Good, High, Ultra, Beyond Ultra and Max FPS.", 1 },
		{ "b", "A profile per kind of place (city, open world, dungeon, raid, battleground, arena) and for specific places.", 1 },
		{ "b", "Find my best settings: a one-time guided run that saves one profile.", 1 },
		{ "b", "A description and an FPS impact for every setting.", 1 },
		{ "b", "FPS readout on the minimap that pulses on changes. Every notification is off by default.", 1 },
		{ "b", "Mouse, keyboard and gamepad.", 1 },
		{ "b", "Restore your original settings at any time.", 1 },
	} },
}
