# MaraFarm

A World of Warcraft: Forever addon for tracking Maraudon and other dungeon farms. Record run times, estimate the vendor value of your loot, and see how close you are to the hourly instance cap.

Copy **MaraFarm** into `World of Warcraft/_forever_/Interface/AddOns/`, then type **`/mf`** in game.

## In-game screenshots

The screenshots use synthetic runs, loot, and prices to demonstrate the interface.

### Earnings charts

Use **`/mf charts`** to compare gold per completed run in the current session or across all sessions. Enter a gold target to estimate how many more runs and how much time it will take at your recorded pace.

![Overall earnings chart with estimated gold per run and an average line](docs/screenshots/gold-per-run.png)

![Gold target chart projecting the additional runs and time required to earn 100 gold](docs/screenshots/gold-target.png)

### Run history and boss loot

Use **`/mf`** to browse runs and filter by session or Maraudon. Select a run and then a boss to see tracked green and blue drops, quantities, unit prices, and vendor subtotals.

| Run history | Boss loot |
| --- | --- |
| ![Run History with entry times, dungeon durations, and vendor estimates](docs/screenshots/run-history.png) | ![Princess Theradras loot detail with unit prices and item totals](docs/screenshots/boss-loot.png) |

### Summary and lockouts

Use **`/mf summary`** for looted coin, vendor value, average gold per run, and both in-instance and session GPH. Use **`/mf lockouts`** for estimated slot expiry. Nova Instance Tracker 2.32 can supply a separate comparison count.

| Farm summary | Hourly lockouts |
| --- | --- |
| ![Farm Overview with coin, vendor value, estimated earnings, and gold-per-hour metrics](docs/screenshots/farm-summary.png) | ![Hourly Lockouts with estimated slots used and time remaining for each entry](docs/screenshots/hourly-lockouts.png) |

### Dungeon overlay and settings

The overlay shows time inside, vendor value, estimated lockout usage, and live run GPH. Use **`/mf options`** to preview and reposition it or start a fresh session while keeping earlier runs and lockouts. Left-click the Princess Theradras minimap button for history or right-click for the summary.

| Options | Dungeon overlay preview |
| --- | --- |
| ![Options for overlay visibility, live GPH, positioning, the minimap button, and resetting a session](docs/screenshots/options.png) | ![Dungeon overlay preview showing time inside, vendor estimate, lockouts, and live run GPH](docs/screenshots/dungeon-overlay.png) |
