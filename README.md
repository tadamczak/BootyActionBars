<p align="center"><img src="https://raw.githubusercontent.com/tadamczak/MuklaOfficerSuite/master/Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyActionBars

BootyActionBars is an upcoming action bar addon for WoW 1.12. This early build includes a main bar following client pages and form actions, up to five additional fixed bars, cooldowns, item counts, dragging actions and separate keybindings. The layout editor moves, scales and arranges each bar. Optional pet and form/stance bars include their own keybindings, tooltips and cooldowns.

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

Show or hide additional bars from the Action Bars page: choose **Bar 2–6**, then **Show** or **Hide**. You can also use `/bab bar 2 on`, `/bab bar 2 off` or `/bab bar 2` to toggle that bar. The test-bar switch enables or stops the main bar and all configured additional bars together. Additional bars use fixed slots 13–24, 25–36, 37–48, 49–60 and 61–72; they keep those slots when the main bar changes page or enters stealth. Their separate **Bar 2–6** bindings appear under **BootyActionBars** in the game's Key Bindings menu.

Hiding a bar keeps its position, scale, layout, client actions and assigned keys. Showing the same numbered bar restores them. Configured bars are saved through reload; named preference profiles currently leave them unchanged. Bars initially stack above the main bar. Select an action bar, **Pet bar** or **Forms / stances** in `/bab`, use **Scale (%)** to choose 50–200%, or **Reset** for the selected bar. Enable **Edit layout** and drag a gold handle to move a bar. Closing or minimizing Action Bars, changing pages in the Booty window, disabling the bars or stopping the addon locks editing and cancels an unfinished drag. Gameplay continues when you close configuration.

Use **Columns** to arrange an ordinary bar's twelve buttons in 1–12 columns and **Spacing** to choose a gap of 0–20. Buttons fill each row from left to right; a partial final row starts at the left edge. Every bar keeps its twelve actions and keybindings. The default is twelve columns with a gap of four.

Use **Title**, **Hotkeys** and **Counts** to show or hide the selected bar's title, assigned-key labels and action counts. These are visible by default. Hiding key labels keeps the assigned keys working. The configuration page scrolls when the window is too short to show all controls. **Reset** restores the selected bar's position, scale, columns, spacing and visible labels.

Use `/bab unlock` to open Action Bars and edit an enabled layout; `/bab lock` finishes editing. `/bab scale 1 100` sets Bar 1 to 100%; `/bab columns 1 6` sets six columns, `/bab gap 1 4` sets its gap, and `/bab reset 1` resets that bar. Use `/bab title 1 off`, `/bab hotkeys 1 off` or `/bab counts 1 off` to hide those labels; replace `off` with `on` to show them again. Positions, scale, button arrangement and label visibility are saved per bar, including through hide/show and reload; edit mode always starts locked. Preference profiles leave layouts unchanged. Complete layout profiles are planned for a later build.

The main bar follows the client's current page: ordinary pages 1–6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Wide bars show the current action slots in their title; narrow bars show a compact bar number. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing page cancels held keys; press again to use the new action. No separate custom Prowl page is added.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. Dynamic macro visuals need further compatibility testing.

Keys follow the twelve visible button positions on every page and form: the same key uses the action currently shown at that position. Hover highlights a button, and holding its key or mouse button shows pressed feedback even when the action cannot be used.

With current BootyProfiler installed, **Advanced Profiler → Profile Action Bars** records this test bar's event work and cooldown animation. The bar works normally without BootyProfiler.

Optional native hiding is off by default. Disable DiscordActionBars, Bongos and pfUI and reload, then enable the test bar and use `/bab native on` or **Hide native buttons**. This hides the twelve main action buttons on page 1, outside bonus forms, and native pet/form bars when the corresponding BootyActionBars bar is visible. Bags, menu and other native controls remain available. Use `/bab native off` or **Show native buttons** to restore the buttons; disabling the test bar also restores them. Hiding a BAB pet/form bar restores its native counterpart; an unavailable edit preview does not hide native controls.

Changing page or entering a bonus form restores the twelve main native buttons while retaining your hide choice. Native pet/form bars remain hidden while their BAB counterparts are visible. A later supported page/form event can hide the main buttons again; the client's bonus-bar slide-out can delay this until another event. Assign the BootyActionBars keys for its visible buttons. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before hiding native buttons again.

Select **Pet bar** or **Forms / stances**, then **Show**. They appear when your pet or class forms are available and use the same movement, scale, columns, spacing and label controls. Use `/bab pet on|off` or `/bab stance on|off`; layout commands use bar 7 for Pet and bar 8 for Forms. The global test-bar switch controls them together with action bars. Assign **Pet action 1–10** and **Form / stance 1–10** under **Key Bindings → BootyActionBars**. Their labels show only these assigned keys; existing native pet/shapeshift keys remain unchanged and are not copied automatically. Right-click a pet ability to toggle autocast; Shift-drag rearranges supported pet actions. Form buttons select the corresponding form or stance.

**Edit layout** shows a movable preview of configured pet and form bars even when no pet or forms are available. Set their position, scale and columns in advance. Unavailable previews hide when editing ends; their saved layout is used when the pet or forms return.
