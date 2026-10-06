<p align="center"><img src="https://raw.githubusercontent.com/tadamczak/MuklaOfficerSuite/master/Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyActionBars

BootyActionBars is an upcoming action bar addon for WoW 1.12. This early build includes a main bar following client pages and form actions, up to five additional fixed bars, cooldowns, item counts, dragging actions and separate keybindings. The layout editor moves, scales and arranges each bar. Pet controls, separate form buttons and advanced layouts are planned for later builds.

## Contents

- [Installation](#installation)
- [Usage](#usage)

## Installation

Install the `BootyActionBars` and current `BootyLib` folders into `Interface/AddOns`, then restart the game. Keep your current action bar addon installed for this build.

Booty Suite is optional. When installed, it adds Action Bars and its settings to the shared Booty window. Otherwise, BootyActionBars has its own minimap icon and window.

## Usage

Use `/bab` or `/bootyactionbars` to open Action Bars. Use `/bab settings` to open Settings.

Standalone Settings contains **Profile** and **Action Bars**. Use **Profile → General** to add, save, load, delete or export named preference profiles. **Action Bars → General** lets you hide the standalone minimap icon; `/bab` still opens the window.

The test bar is off by default. Enable it from the Action Bars page, **Action Bars → General**, or `/bab test on`. Disable it with `/bab test off`; `/bab test` toggles it. Closing the Booty window keeps the enabled bar working. Activation is saved separately from named preference profiles.

Enable or remove additional bars from the Action Bars page: choose **Bar 2–6**, then **Add** or **Remove**. You can also use `/bab bar 2 on`, `/bab bar 2 off` or `/bab bar 2` to toggle that bar. The test-bar switch enables or stops the main bar and all configured additional bars together. Additional bars use fixed slots 13–24, 25–36, 37–48, 49–60 and 61–72; they keep those slots when the main bar changes page or enters stealth. Their separate **Bar 2–6** bindings appear under **BootyActionBars** in the game's Key Bindings menu.

Removing a bar keeps its client actions and assigned keys. Adding the same numbered bar again restores those bindings. Configured bars are saved through reload; named preference profiles currently leave them unchanged. Bars initially stack above the main bar. Select **Bar 1–6** in `/bab`, use **Scale (%)** to choose 50–200%, or **Reset** for the selected bar. Enable **Edit layout** and drag a gold handle to move a bar. Closing or minimizing Action Bars, changing pages in the Booty window, disabling the bars or stopping the addon locks editing and cancels an unfinished drag. Gameplay continues when you close configuration.

Use **Columns** to arrange a bar's twelve buttons in 1–12 columns and **Spacing** to choose a gap of 0–20. Buttons fill each row from left to right; a partial final row starts at the left edge. Every bar keeps its twelve actions and keybindings. The default is twelve columns with a gap of four. **Reset** restores the selected bar's position, scale, columns and spacing.

Use `/bab unlock` to open Action Bars and edit an enabled layout; `/bab lock` finishes editing. `/bab scale 1 100` sets Bar 1 to 100%; `/bab columns 1 6` sets six columns, `/bab gap 1 4` sets its gap, and `/bab reset 1` resets that bar. Positions, scale and button arrangement are saved per bar, including through removal/re-add and reload; edit mode always starts locked. Preference profiles leave layouts unchanged. Complete layout profiles are planned for a later build.

The main bar follows the client's current page: ordinary pages 1–6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Wide bars show the current action slots in their title; narrow bars show a compact bar number. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing page cancels held keys; press again to use the new action. No separate custom Prowl page is added.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. Dynamic macro visuals need further compatibility testing.

Keys follow the twelve visible button positions on every page and form: the same key uses the action currently shown at that position. Hover highlights a button, and holding its key or mouse button shows pressed feedback even when the action cannot be used.

With current BootyProfiler installed, **Advanced Profiler → Profile Action Bars** records this test bar's event work and cooldown animation. The bar works normally without BootyProfiler.

Optional native replacement is off by default. Disable DiscordActionBars, Bongos and pfUI and reload, then enable the test bar and use `/bab native on` or **Replace native buttons**. This replaces only the twelve main action buttons on page 1, outside forms. Pet, stance, bags, menu and other native controls remain available. Use `/bab native off` to restore the buttons; disabling the test bar also restores them.

Changing page or entering a form restores the native buttons and turns replacement off. Enable replacement again after returning to page 1 and leaving the form. Assign the BootyActionBars keys for its visible buttons. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before another replacement.
