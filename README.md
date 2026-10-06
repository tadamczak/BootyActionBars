<p align="center"><img src="https://raw.githubusercontent.com/tadamczak/MuklaOfficerSuite/master/Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyActionBars

BootyActionBars is an upcoming action bar addon for WoW 1.12. This early build includes an optional bar following client pages and form actions, cooldowns, item counts, dragging actions and its own keybindings. Pet controls, separate form buttons and layout editing are planned for later builds.

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

The bar follows the client's current page: ordinary pages 1–6 and the client's bonus actions for forms or stealth on page 1. Use the game's page keys or controls to change pages. Its title shows the current action slots. **Dragging changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action or drop an action onto a button. Changing page cancels held keys; press again to use the new action. No separate custom Prowl page is added.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. Dynamic macro visuals need further compatibility testing.

With current BootyProfiler installed, **Advanced Profiler → Profile Action Bars** records this test bar's event work and cooldown animation. The bar works normally without BootyProfiler.

Optional native replacement is off by default. Disable DiscordActionBars, Bongos and pfUI and reload, then enable the test bar and use `/bab native on` or **Replace native buttons**. This replaces only the twelve main action buttons on page 1, outside forms. Pet, stance, bags, menu and other native controls remain available. Use `/bab native off` to restore the buttons; disabling the test bar also restores them.

Changing page or entering a form restores the native buttons and turns replacement off. Enable replacement again after returning to page 1 and leaving the form. Assign the BootyActionBars keys for its visible buttons. If another addon changes the replaced callbacks during use, BootyActionBars reports the conflict and requires a reload before another replacement.
