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

The addon starts with its bars off. Open **General** and check **Show BootyActionBars**, or use `/bab test on`. Uncheck it or use `/bab test off` to stop all its bars. Closing the Booty window keeps enabled bars working. Activation is saved separately from profiles. The window has **General**, **Action Bars** and **Keybindings** tabs.

In **Action Bars**, select an action bar, **Pet** or **Forms / stances** in the left list and check its **Show** option on the right. Action Bar 1 can be hidden while other bars keep working. You can also use `/bab bar 2 on|off` or `/bab bar 2` for additional bars. They use fixed slots 13–24, 25–36, 37–48, 49–60 and 61–72 by default. Their separate **Bar 2–6** bindings appear under **BootyActionBars** in the game's Key Bindings menu.

Hiding a bar keeps its position, layout, client actions and assigned keys. Showing it restores them. In **Action Bars → Layout**, enable **Unlock** and drag anywhere on a visible bar while its ordinary icons stay visible. Mouse actions and icon dragging are blocked while unlocked. Buttons can reach the screen edges. Closing or minimizing the window, switching configuration tabs, disabling bars or stopping the addon locks editing and cancels an unfinished drag.

Select **Global** to change the shared geometry, appearance and labels. Bars with **Use Global Layout** checked follow these settings while keeping independent positions. Uncheck it to start individual controls from the current Global values. Later toggles retain your individual overrides. Existing individually configured bars keep their settings. Hidden bars can be configured without showing them.

Use **Columns** to arrange an ordinary bar's twelve buttons in 1–12 columns and **Spacing** to choose a gap of 0–20. Buttons fill each row from left to right; a partial final row starts at the left edge. Every bar keeps its twelve actions and keybindings. The default is twelve columns with a gap of four.

Use **Title**, **Hotkeys**, **Counts**, **Macro names** and **Empty buttons** to show or hide the selected bar's labels and empty slots. These are visible by default. Macro names apply to ordinary action bars. Hiding key labels keeps assigned keys working; hidden empty slots do not accept gameplay input. **Unlock** and **Assign keys** reveal ordinary empty slots for placement or selection.

Use **Button size** (24–64), **Icon inset** (0–8), **Opacity (%)** (20–100) and **Label size** (8–16) to customize Global or an individual bar. The settings pane scrolls when needed; narrow windows place the bar list above it. **Reset local layout** restores position and individual settings while retaining the Global choice, actions and keys.

Use `/bab unlock` to open Action Bars and edit an enabled layout; `/bab lock` finishes editing. `/bab scale 1 100` sets Bar 1 to 100%; `/bab columns 1 6` sets six columns, `/bab gap 1 4` sets its gap, and `/bab reset 1` resets that bar. Use `/bab title 1 off`, `/bab hotkeys 1 off`, `/bab counts 1 off`, `/bab macronames 1 off` or `/bab empty 1 off` to hide them; replace `off` with `on` to show them again. Layout and appearance survive hide/show and reload; edit mode starts locked. General preference profiles leave layouts unchanged.

**General → Layout profiles** saves all eight bars' positions, individual and Global appearance, inheritance and Show choices. Enter a name and **Save layout**, then select it to **Load** or **Delete**. Replacing, loading and deleting ask for confirmation. **Undo load** restores the preceding layout during the current session. Up to 20 profiles are supported. Older layout profiles remain loadable. Profiles retain client actions, keybindings and the current master/native switches.

The main bar follows the client's current page: ordinary pages 1–6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Wide bars show the current action slots in their title; narrow bars show a compact bar number. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing page cancels held keys; press again to use the new action. No separate custom Prowl page is added.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. SuperMacro and CleveRoids macro icons, item counts, cooldowns and tooltips follow their resolved actions. Conditional CleveRoids updates also refresh the matching visible buttons. Arbitrary third-party macro engines and scripts require separate compatibility testing.

Use **Keybindings → Assign keys**, or `/bab bind`. Click a button, or select its bar and number in the panel, then press a key with modifiers. It stays visibly selected until a key is staged, then releases. Both draft keys appear on its icon immediately, even if ordinary key labels are hidden. Hover alone does not select. Each button supports two keys; Escape clears the selection. **Save keys** commits to the current client binding set; conflicting keys ask for confirmation. **Cancel**, switching tabs or closing the window discards the draft. Gameplay input is suspended while assigning keys. Pet/form commands can be selected in the panel while absent.

Keys follow the twelve visible button positions on every page and form: the same key uses the action currently shown at that position. Hover highlights a button, and holding its key or mouse button shows pressed feedback even when the action cannot be used.

Usable actions are white; actions outside the reported target range are red, insufficient mana is blue, and other unavailable actions are gray. Range updates follow movement with the same target. An unknown range keeps the normal usability color. Macro range depends on the installed provider/client range API. Removing the target stops distance checks.

With current BootyProfiler installed, **Advanced Profiler → Profile Action Bars** records this test bar's action updates, including range checks and macro notifications, and cooldown animation. The bar works normally without BootyProfiler.

Native buttons are shown by default. Disable DiscordActionBars, Bongos and pfUI and reload, enable BootyActionBars, then uncheck **General → Show Native buttons** or use `/bab native on`. Main and bonus buttons hide while Action Bar 1 is visible, including stealth transitions. Pet/form bars hide while their BAB counterparts are visible. Bags and menu remain available. Check **Show Native buttons** or use `/bab native off` to restore controls. Disabling BootyActionBars also restores them. Hiding a BAB bar releases its native counterpart; layout anchors do not hide native controls.

Native action buttons stay hidden when changing page, entering a form or leaving stealth. Assign the BootyActionBars keys for its visible buttons. Form icons follow the current class state. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before hiding native buttons again.

Select **Pet** or **Forms / stances** and check **Show Pet Bar** or **Show Form Bar**. They appear when available and share the same layout options. Use `/bab pet on|off` or `/bab stance on|off`; layout commands use bar 7 for Pet and bar 8 for Forms. Assign **Pet action 1–10** and **Form / stance 1–10** under **Keybindings** or the game's **Key Bindings → BootyActionBars**. Native pet/form keys remain unchanged. Right-click pet abilities to toggle autocast; Shift-drag rearranges supported pet actions. Form buttons select the corresponding form or stance.

**Show grid** displays a static positioning grid while unlocked. **Show anchors** displays movable placeholders for hidden or unavailable bars, including pet/forms. Position them without enabling their actions. Anchors and the grid hide when editing ends; saved positions remain when bars become available.
