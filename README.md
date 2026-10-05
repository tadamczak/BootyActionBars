<p align="center"><img src="https://raw.githubusercontent.com/tadamczak/MuklaOfficerSuite/master/Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyActionBars

BootyActionBars is an upcoming action bar addon for WoW 1.12. This early build includes an optional test bar for action slots 1–12, cooldowns, item counts, dragging actions and its own keybindings. Paging, shapeshifts, pets and layout editing are planned for later builds.

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

The bar uses fixed client slots 1–12. **Dragging actions changes those same slots on other bars**, including DiscordActionBars. Hold Shift to drag an action from a test button, or drop an action onto it. The test bar does not follow pages or forms yet.

Open the game's **Key Bindings → BootyActionBars** and assign keys to its twelve buttons. No keys are assigned automatically. Disabling the bar stops these commands from executing actions; assigned keys remain in the game's binding configuration. Mouse clicks and ordinary action slots use the current client APIs, including installed API hooks. Dynamic macro visuals need further compatibility testing.
