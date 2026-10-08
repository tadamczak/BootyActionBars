# Changelog

## 0.1.0-dev.29 — 2026-10-08

- Expose Main Action Bar's default page/form following in Behaviours, with an option to keep its normal slots fixed.
- Add Action Bars7–10 for all120 native slots, including their layouts, behaviors, merges, keybindings and profiles.
- Fix the cooldown texture error caused by forwarding an extra argument to the native SetTexCoord API.

## 0.1.0-dev.28 — 2026-10-08

- Remove an unused cooldown state copy while preserving the existing cooldown-number ownership flag.

## 0.1.0-dev.27 — 2026-10-07

- Merge ordinary bars under one layout while retaining their actions, keybindings and individual settings for later separation.
- Separate native stone, frame and button artwork, including independent bar and button texture scales.
- Combine Background shadow, Border shadow and Border hover effects with separate area, thickness and corner radius.
- Keep colored circular or top-to-bottom cooldown indicators inside icons, with optional colored blinking in the last three seconds.

## 0.1.0-dev.26 — 2026-10-07

- Fit complete native sockets into their own cells and draw them above button fills, preserving icon visibility.
- Use complete native socket/frame crops and tiled stone without stretched decorative strips.
- Separate Native bar background and Native button background, preserving older layout profiles.
- Add optional matching native backgrounds to Bags, Micro Menu, Latency and Keyring.

## 0.1.0-dev.25 — 2026-10-07

- Align individual native socket artwork with each button in every row and fill the gaps between slots.
- Scale native artwork independently from button size and inset.
- Anchor gryphons at the top row above buttons and add a separate Gryphon scale option.
- Arrange bar controls in up to three columns with Decoration immediately after Appearance and compact choice menus.

## 0.1.0-dev.24 — 2026-10-07

- Configure and move Experience/Reputation, Keyring, Latency, Bags and Micro Menu using their existing game controls.
- Make native-bar visibility independent of BootyActionBars, including both hidden.
- Use compact bar settings and clearer Main Action Bar, Global Settings and Pet Bar names.
- Keep the layout grid under interface elements; crop and scale native skill artwork without stretching it.
- Offer Native slot artwork independently from empty buttons; reveal empty drop targets during action dragging.
- Include utility positions and visibility in layout profiles, preserving older profiles.

## 0.1.0-dev.23 — 2026-10-07

- Restore action bar list selection on the native client.
- Keep the positioning grid above the game background while unlocked.

## 0.1.0-dev.22

- Hide native multi-action buttons independently while their BootyActionBars equivalents are visible.
- Hide native menu panels and gryphons while replacing the main bar, preserving bags, menu controls and XP.
- Restore native callbacks and artwork on Hide, OFF and Stop without overwriting later owners.
- Release every native replacement immediately after a visibility failure while keeping BootyActionBars usable.

## 0.1.0-dev.21

- Add per-bar stealth/form behaviors with ordered Add, Edit, Remove and priority controls.
- Change several visible bars to fixed source action bars together while keeping button keys and positions.
- Include behaviors in layout profiles and preserve older snapshots and unresolved form identities.
- Keep narrow settings checkbox labels and click areas inside their measured rows.

## 0.1.0-dev.20

- Customize range colors, hover effects, button borders/backgrounds and cooldown numbers per bar or through Global.
- Add optional native menu textures and left/right gryphons to each bar.
- Share countdown and range updates while needed; disable duplicate cooldown text on private BAB models.

## 0.1.0-dev.19

- Organize configuration into General, Action Bars and Keybindings with a left bar list and contextual controls.
- Add Global Layout inheritance, preserved individual overrides and complete layout profiles compatible with older profiles.
- Show or hide Action Bar 1 independently while other bars remain active; configure hidden bars without enabling them.

## 0.1.0-dev.18 — 2026-10-07

- Place the button rectangle flush against screen edges without a reserved title gap.
- Click a button before assigning a key, show both draft keys on its icon, then release its selection; Save commits and Cancel restores labels.
- Move visible bars through transparent whole-bar Unlock surfaces, with optional static grid and inert anchors for hidden bars.

## 0.1.0-dev.17 — 2026-10-07

- Show macro names by default with a separate per-bar toggle; keep labels cached during partial updates.
- Customize button size, icon inset, opacity and label size; hide empty slots while retaining edit previews.
- Stage action/pet/form key assignments with Save, Cancel and explicit conflict confirmation.
- Save, load, replace and delete complete layout profiles, with Undo load and transactional restoration.

## 0.1.0-dev.16 — 2026-10-07

- Refresh SuperMacro/CleveRoids macro icons, item counts, cooldowns and tooltips, including delayed conditional changes.
- Show target range with cached action colors; stop distance checks without a target or active ranged buttons.
- Preserve action input through pages/forms and include shared gameplay updates in scoped profiling.

## 0.1.0-dev.15 — 2026-10-06

- Keep native main and bonus action buttons hidden through stealth, forms, page changes and native exit animations.
- Refresh form icons when their active state changes.
- Preserve native keyboard dispatch and restore both button sets when native hiding ends.

## 0.1.0-dev.14 — 2026-10-06

- Use Show / Hide for bars while retaining layouts, actions and assigned keys.
- Add separate pet and form/stance bindings under BootyActionBars with pressed-key feedback.
- Hide matching native pet/form bars while BAB bars are visible; retain the hide choice across pages and stealth.

## 0.1.0-dev.13 — 2026-10-06

- Position configured pet and form bars in Edit layout even when no pet or forms are available.
- Hide these layout previews when editing ends and reuse their positions when the pet or forms return.

## 0.1.0-dev.12 — 2026-10-06

- Add optional pet and form/stance bars with native keys, tooltips, cooldowns and pet autocast controls.
- Move, scale and arrange these bars using the existing layout editor; unavailable bars hide automatically.
- Keep native pet/form buttons available and mark scoped profiler coverage as partial when these bars are configured.

## 0.1.0-dev.11 — 2026-10-06

- Show or hide each bar's title, key labels and item/charge counts independently.
- Keep hidden labels current without formatting or rewriting them until they are shown.
- Keep all bar settings reachable in shorter windows through the shared scrolling panel.

## 0.1.0-dev.10 — 2026-10-06

- Arrange each bar in 1–12 columns with adjustable spacing, including vertical bars and multiple rows.
- Preserve existing actions, bindings and saved layouts while reusing the same buttons and cooldowns.
- Reset the selected bar's position, scale, columns and spacing together.

## 0.1.0-dev.9 — 2026-10-06

- Restore left/right mouse action clicks by keeping visual press feedback independent of native click dispatch.
- Keep pending mouse releases cancelled across page changes, editing and bar suspension.

## 0.1.0-dev.8 — 2026-10-06

- Fix the native frame error when enabling action bars and when scaling, resetting or restoring a locked layout.
- Keep locked bars stationary through hidden, detached editing handles while retaining the client's required position capability.

## 0.1.0-dev.7 — 2026-10-06

- Move and scale every bar using pooled gold drag handles and selected-bar controls; save completed layouts and cancel unfinished edits on close or stop.
- Keep bar centers stable when scaling and retain user layouts while fitting changed screen/UI scale.

## 0.1.0-dev.6 — 2026-10-06

- Add five optional fixed action bars with separate bindings, pooled add/remove controls and complete cooldown profiling.

## 0.1.0-dev.5 — 2026-10-06

- Show hover and mouse/key press feedback even when an action cannot be used; cancel presses during dragging/page changes and clear feedback when disabling.

## 0.1.0-dev.4 — 2026-10-06

- Add optional reversible replacement of the twelve native main action buttons with `/bab native on|off` and a panel control.
- Restore native callbacks when disabled, hidden or stopped; reject competing bar addons, unsupported pages/forms and changed ownership.
- Follow client pages and bonus form actions for icons, cooldowns, keys, tooltips and dragging; cancel held inputs on page changes.

## 0.1.0-dev.3 — 2026-10-06

- Support the optional targeted Action Bars profile in BootyProfiler without enabling measurements during ordinary play.

## 0.1.0-dev.2 — 2026-10-05

- Add an optional slots1–12 test bar with actions, Shift dragging, native cooldowns and explicit keybindings.
- Add panel, Settings and `/bab test on|off` activation; reuse buttons and stop event work while disabled or hidden.
- Preserve existing bar frames and key assignments; dragged actions share the client's slots with other bars.

## 0.1.0-dev.1 — 2026-10-05

- Add independent preferences, named settings profiles, a window opened on demand and optional Booty Suite integration.
- Add `/bab` and `/bootyactionbars`; preserve existing action bars and keybindings during this early development build.
