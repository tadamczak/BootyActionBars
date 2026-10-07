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

Standalone Settings contains **Profile** and **Action Bars**. Use **Profile â†’ General** to add, save, load, delete or export named preference profiles. **Action Bars â†’ General** lets you hide the standalone minimap icon; `/bab` still opens the window.

The addon starts with its bars off. Open **General** and check **Show BootyActionBars**, or use `/bab test on`. Uncheck it or use `/bab test off` to stop all its bars. Closing the Booty window keeps enabled bars working. Activation is saved separately from profiles. The window has **General**, **Action Bars** and **Keybindings** tabs.

In **Action Bars**, select **Main Action Bar**, another action bar, **Pet Bar** or **Forms / stances** in the left list and check its **Show** option on the right. Main Action Bar can be hidden while other bars keep working. You can also use `/bab bar 2 on|off` or `/bab bar 2` for additional bars. They use fixed slots 13â€“24, 25â€“36, 37â€“48, 49â€“60 and 61â€“72 by default. Their separate **Bar 2â€“6** bindings appear under **BootyActionBars** in the game's Key Bindings menu.

Hiding a bar keeps its position, layout, client actions and assigned keys. Showing it restores them. In **Action Bars â†’ Layout**, enable **Unlock** and drag anywhere on a visible bar while its ordinary icons stay visible. Mouse actions and icon dragging are blocked while unlocked. Buttons can reach the screen edges. Closing or minimizing the window, switching configuration tabs, disabling bars or stopping the addon locks editing and cancels an unfinished drag.

Select **Global Settings** to change the shared geometry, appearance and labels. Bars with **Use Global Layout** checked follow these settings while keeping independent positions. Uncheck it to start individual controls from the current Global values. Later toggles retain your individual overrides. Existing individually configured bars keep their settings. Hidden bars can be configured without showing them. Bar controls use compact labels and sliders.

The list also includes **Experience / Reputation**, **Keyring**, **Latency**, **Bags** and **Micro Menu**. Enable their **Show** choices to move and scale the existing game controls through BAB. Bags and Micro Menu also offer Columns and Spacing. **Native menu texture** adds the game's matching background to Bags, Micro Menu, Latency and Keyring; it is off by default. XP/reputation and class-specific menu buttons follow their normal availability. Hide returns controls to their native positions. These groups are off by default and begin at separate positions; they share the same Unlock and Show anchors tools. Reset layout retains their Show choice.

Use **Columns** to arrange an ordinary bar's twelve buttons in 1â€“12 columns and **Spacing** to choose a gap of 0â€“20. Buttons fill each row from left to right; a partial final row starts at the left edge. Every bar keeps its twelve actions and keybindings. The default is twelve columns with a gap of four.

Use **Title**, **Hotkeys**, **Counts**, **Macro names** and **Empty buttons** to show or hide the selected bar's labels and empty slots. These are visible by default. Macro names apply to ordinary action bars. Hiding key labels keeps assigned keys working. While dragging an action, hidden empty slots appear as highlighted drop targets and hide again when the drag ends. **Unlock** and **Assign keys** also reveal ordinary empty slots for placement or selection.

Use **Button size** (24â€“64), **Icon inset** (0â€“8), **Opacity (%)** (20â€“100) and **Label size** (8â€“16) to customize Global or an individual bar. The settings pane scrolls when needed; narrow windows place the bar list above it. **Reset local layout** restores position and individual settings while retaining the Global choice, actions and keys.

The same settings also offer separate in-range and out-of-range icon colors, including opacity. Choose **Default**, **Border** or **Shadow** hover feedback and its color/size. Button borders have an independent toggle, color and size; **Button background** hides or shows the fill behind each icon. Pressed and assigned-key feedback remain visible.

**Cooldown numbers** shows remaining time for cooldowns of at least two seconds, with a configurable color, opacity and font size. Short global cooldowns keep their ordinary animation. **Native bar background** shows the stone panel and outer frame; **Native button background** independently shows a native socket beneath each icon. Either, both or neither can be visible. **Texture scale (%)** changes the artwork independently from button size and icon inset; socket size stops growing at adjacent buttons, keeping its complete native frame without overlap. **Button background** separately controls the dark fill. Choose **Left**, **Right** or **Both** gryphons and adjust **Gryphon scale (%)** independently. Gryphons sit beside the top row, above buttons. Global settings can apply these choices to all inherited bars, including Pet and Forms. Geometry, Appearance and Decoration appear in that order; controls use up to three columns when the window has room.

Use `/bab unlock` to open Action Bars and edit an enabled layout; `/bab lock` finishes editing. `/bab scale 1 100` sets Bar 1 to 100%; `/bab columns 1 6` sets six columns, `/bab gap 1 4` sets its gap, and `/bab reset 1` resets that bar. Use `/bab title 1 off`, `/bab hotkeys 1 off`, `/bab counts 1 off`, `/bab macronames 1 off` or `/bab empty 1 off` to hide them; replace `off` with `on` to show them again. Layout and appearance survive hide/show and reload; edit mode starts locked. General preference profiles leave layouts unchanged.

**General â†’ Layout profiles** saves all eight action/pet/form bars' positions, individual and Global appearance, inheritance and Show choices, plus utility groups' positions, scale, layout and Show choices. Enter a name and **Save layout**, then select it to **Load** or **Delete**. Replacing, loading and deleting ask for confirmation. **Undo load** restores the preceding layout during the current session. Up to 20 profiles are supported. Older layout profiles remain loadable and preserve current utility settings. Profiles retain client actions, keybindings and the current master/native switches.

The main bar follows the client's current page: ordinary pages 1â€“6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Wide bars show the current action slots in their title; narrow bars show a compact bar number. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing its source cancels held keys; press again to use the new action.

In **Action Bars â†’ Action Bar 1â€“6 â†’ Behaviors**, use **Add** to choose **Stealth** or an available form and **Change to Action Bar** 1â€“6, then **Save**. Each source number means its fixed twelve native slots: source1 is slots1â€“12, source2 is13â€“24, and so on. Add rules to several bars to change them together. **Edit**, **Remove**, **Up** and **Down** manage up to16 rules per bar; the first matching rule wins. Put a Stealth rule above Cat Form when Prowl should take precedence. Cancel or close the dialog to discard its draft.

Rules apply independently of Global appearance and can be configured while a bar is hidden. When no rule matches, Bar1 follows native pages/forms and the other bars return to their normal fixed slots. Stealth supports Rogue, Prowl and Shadowmeld. Form rules keep the class, client language and exact form name; a missing or differently named form is shown as unavailable and stays inactive. Learning or rearranging forms and changing their icons never moves a rule to another form. Layout profiles include rules; older profiles without rules preserve the current ones.

Open the game's **Key Bindings â†’ BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. SuperMacro and CleveRoids macro icons, item counts, cooldowns and tooltips follow their resolved actions. Conditional CleveRoids updates also refresh the matching visible buttons. Arbitrary third-party macro engines and scripts require separate compatibility testing.

Use **Keybindings â†’ Assign keys**, or `/bab bind`. Click a button, or select its bar and number in the panel, then press a key with modifiers. It stays visibly selected until a key is staged, then releases. Both draft keys appear on its icon immediately, even if ordinary key labels are hidden. Hover alone does not select. Each button supports two keys; Escape clears the selection. **Save keys** commits to the current client binding set; conflicting keys ask for confirmation. **Cancel**, switching tabs or closing the window discards the draft. Gameplay input is suspended while assigning keys. Pet/form commands can be selected in the panel while absent.

Keys follow the twelve visible button positions on every page and form: the same key uses the action currently shown at that position. Hover highlights a button, and holding its key or mouse button shows pressed feedback even when the action cannot be used.

Usable actions use the configured in-range color; actions outside the reported target range use the out-of-range color. Defaults are white and red. Insufficient mana is blue, and other unavailable actions are gray. Range updates follow movement with the same target. An unknown range keeps the normal usability color. Macro range depends on the installed provider/client range API. Removing the target stops distance checks.

With current BootyProfiler installed, **Advanced Profiler â†’ Profile Action Bars** records this test bar's action updates, including range checks and macro notifications, and cooldown animation. The bar works normally without BootyProfiler.

Native controls are shown by default. Disable DiscordActionBars, Bongos and pfUI and reload, then uncheck **General â†’ Show Native Bar** or use `/bab native on`. This hides the native main/bonus, extra action bars, pet/form bars and menu, including stealth transitions. **Show Native Bar** and **Show BootyActionBars** are independent: either, both or neither can be shown. Enabled utility groups remain available at their BAB positions while BAB is on; their controls have a single instance. Check **Show Native Bar** or use `/bab native off` to restore native visibility. Stopping the addon restores all native controls temporarily; Start resumes the saved choices. Hiding one BAB bar leaves the master native choice unchanged.

Native action buttons stay hidden when changing page, entering a form or leaving stealth. Assign the BootyActionBars keys for its visible buttons. Form icons follow the current class state. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before hiding native buttons again.

Select **Pet Bar** or **Forms / stances** and check **Show Pet Bar** or **Show Form Bar**. They appear when available and share the same layout options. Use `/bab pet on|off` or `/bab stance on|off`; layout commands use bar 7 for Pet and bar 8 for Forms. Assign **Pet action 1â€“10** and **Form / stance 1â€“10** under **Keybindings** or the game's **Key Bindings â†’ BootyActionBars**. Native pet/form keys remain unchanged. Right-click pet abilities to toggle autocast; Shift-drag rearranges supported pet actions. Form buttons select the corresponding form or stance.

**Show grid** displays a static positioning grid under interface elements while unlocked. **Show anchors** displays movable placeholders for hidden or unavailable bars, including pet/forms and utility groups. Position them without enabling their actions. Anchors and the grid hide when editing ends; saved positions remain when bars become available.
