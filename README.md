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

Hiding a bar keeps its position, scale, layout, client actions and assigned keys. Showing the same numbered bar restores them. Configured bars are saved through reload; named preference profiles leave them unchanged. Bars initially stack above the main bar. Select an action bar, **Pet bar** or **Forms / stances** in `/bab`, use **Scale (%)** to choose 50–200%, or **Reset** for the selected bar. Enable **Unlock** and drag anywhere on a visible bar while its ordinary icons stay visible. Action input and icon dragging are blocked while unlocked. Buttons can reach the screen edges; titles do not reserve an extra gap. Closing or minimizing Action Bars, changing pages in the Booty window, disabling the bars or stopping the addon locks editing and cancels an unfinished drag. Gameplay continues when you close configuration.

Use **Columns** to arrange an ordinary bar's twelve buttons in 1–12 columns and **Spacing** to choose a gap of 0–20. Buttons fill each row from left to right; a partial final row starts at the left edge. Every bar keeps its twelve actions and keybindings. The default is twelve columns with a gap of four.

Use **Title**, **Hotkeys**, **Counts**, **Macro names** and **Empty buttons** to show or hide the selected bar's labels and empty slots. These are visible by default. Macro names apply to ordinary action bars. Hiding key labels keeps assigned keys working; hidden empty slots do not accept gameplay input. **Unlock** and **Assign keys** reveal ordinary empty slots for placement or selection.

Use **Button size** (24–64), **Icon inset** (0–8), **Opacity (%)** (20–100) and **Label size** (8–16) to customize each bar. The configuration page scrolls when the window is too short to show all controls. **Reset** restores the selected bar's position, geometry, appearance and labels while retaining actions and keys.

Use `/bab unlock` to open Action Bars and edit an enabled layout; `/bab lock` finishes editing. `/bab scale 1 100` sets Bar 1 to 100%; `/bab columns 1 6` sets six columns, `/bab gap 1 4` sets its gap, and `/bab reset 1` resets that bar. Use `/bab title 1 off`, `/bab hotkeys 1 off`, `/bab counts 1 off`, `/bab macronames 1 off` or `/bab empty 1 off` to hide them; replace `off` with `on` to show them again. Layout and appearance survive hide/show and reload; edit mode starts locked. General preference profiles leave layouts unchanged.

**Layout profiles** on the Action Bars page save all eight bars' position, geometry, appearance and Show/Hide choices. Enter a name and **Save layout**, then select it to **Load** or **Delete**. Replacing, loading and deleting ask for confirmation. **Undo load** restores the layout from before the last load during the current session. Up to 20 profiles are supported. Profiles retain client actions, keybindings and the current test-bar/native-hiding switches.

The main bar follows the client's current page: ordinary pages 1–6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Wide bars show the current action slots in their title; narrow bars show a compact bar number. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing page cancels held keys; press again to use the new action. No separate custom Prowl page is added.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. SuperMacro and CleveRoids macro icons, item counts, cooldowns and tooltips follow their resolved actions. Conditional CleveRoids updates also refresh the matching visible buttons. Arbitrary third-party macro engines and scripts require separate compatibility testing.

Alternatively, use **Assign keys** in `/bab`, or `/bab bind`. Click a button, or select its bar and button number in the panel, then press a key with any modifiers. The clicked button stays visibly selected until a key is staged, then releases its selection. Both draft keys appear on its icon immediately, even if ordinary key labels are hidden. Hover alone does not select. Each button supports two keys; Escape clears the selected button. **Save keys** commits the draft to the current client binding set; conflicting keys show the affected assignments for confirmation. **Cancel** or closing Action Bars discards the draft and restores ordinary labels. Gameplay input is suspended while assigning keys. Pet/form buttons can be selected in the panel even without a current pet or form.

Keys follow the twelve visible button positions on every page and form: the same key uses the action currently shown at that position. Hover highlights a button, and holding its key or mouse button shows pressed feedback even when the action cannot be used.

Usable actions are white; actions outside the reported target range are red, insufficient mana is blue, and other unavailable actions are gray. Range updates follow movement with the same target. An unknown range keeps the normal usability color. Macro range depends on the installed provider/client range API. Removing the target stops distance checks.

With current BootyProfiler installed, **Advanced Profiler → Profile Action Bars** records this test bar's action updates, including range checks and macro notifications, and cooldown animation. The bar works normally without BootyProfiler.

Optional native hiding is off by default. Disable DiscordActionBars, Bongos and pfUI and reload, then enable the test bar and use `/bab native on` or **Hide native buttons**. This hides the native main and bonus action buttons on every supported page and form, including stealth and its exit animation. Native pet/form bars hide when the corresponding BootyActionBars bar is visible. Bags, menu and other native controls remain available. Use `/bab native off` or **Show native buttons** to restore the buttons; disabling the test bar also restores them. Hiding a BAB pet/form bar restores its native counterpart; an unavailable edit preview does not hide native controls.

Native action buttons stay hidden when changing page, entering a form or leaving stealth. Assign the BootyActionBars keys for its visible buttons. Form icons follow the current class state. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before hiding native buttons again.

Select **Pet bar** or **Forms / stances**, then **Show**. They appear when your pet or class forms are available and use the same movement, scale, columns, spacing and label controls. Use `/bab pet on|off` or `/bab stance on|off`; layout commands use bar 7 for Pet and bar 8 for Forms. The global test-bar switch controls them together with action bars. Assign **Pet action 1–10** and **Form / stance 1–10** under **Key Bindings → BootyActionBars**. Their labels show only these assigned keys; existing native pet/shapeshift keys remain unchanged and are not copied automatically. Right-click a pet ability to toggle autocast; Shift-drag rearranges supported pet actions. Form buttons select the corresponding form or stance.

**Show grid** displays a static positioning grid while unlocked. **Show anchors** displays movable placeholders for hidden or unavailable bars, including pet/forms. Position them without enabling their actions. Anchors and the grid hide when editing ends; saved positions remain when bars become available.
