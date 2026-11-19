# Changelog

This file records user-facing changes by GitHub release tag.

## Unreleased

### Fixed

- Run History and the farm summary default to the current session after reload. Resetting selects the new session without changing older runs or hourly lockouts.
- A dungeon copy identified after its first encounter stays in the session that was current when you entered.

## [0.7.1](https://github.com/jturnham/MaraFarm/releases/tag/v0.7.1) · 2026-11-19

### Fixed

- Distinguishes more fresh dungeon copies after resets. A locally requested reset without a readable result is marked provisional, and fighting a previously defeated boss after re-entry separates the new run.

## [0.7.0](https://github.com/jturnham/MaraFarm/releases/tag/v0.7.0) · 2026-11-18

### Added

- Tracks Epic drops alongside Uncommon and Rare loot. Epic drops retain their purple item links, and their vendor estimates count toward earnings and GPH.
- Adds a dungeon checklist under **/mf options** → **Show overlay in dungeons**. The checklist controls overlay visibility independently of run tracking.

### Fixed

- Recognizes personal Need and Greed wins, newer Forever item links, and awards received after leaving the dungeon when the roll was observed inside. Matching roll and receipt notifications count once.

## [0.1](https://github.com/jturnham/MaraFarm/releases/tag/v0.1) · 2026-11-18

First packaged GitHub release for WoW Forever. The bundled addon reported version `0.6.3` in game.

- Dungeon run timing, session history, and an estimated rolling hourly lockout with an optional Nova Instance Tracker comparison.
- Boss loot drill-down for Uncommon and Rare drops, vendor estimates, looted coin, and farming summaries.
- Charts for session and overall earnings per run, plus projections for a gold target.
- Configurable dungeon overlay with live run GPH and a movable Princess Theradras minimap button.
