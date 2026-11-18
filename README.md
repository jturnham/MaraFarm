# MaraFarm

Implementation guide for a World of Warcraft: Forever addon that tracks Maraudon solo farming. This repository contains the design, build sequence, and acceptance checks for the addon.

## 1. Define what the tracker measures

1. Track the estimated rolling hourly lockout across eligible instances. Display slots used, slots remaining out of 10, and the next slot release. The farming view defaults to Maraudon, while other eligible instances still contribute to the lockout.
2. Treat one fresh copy of an instance as one run. Leaving and returning to the same copy adds a visit to the same run. Time inside is the sum of the visit durations.
3. Define estimated gold earned as confirmed looted coin plus the vendor value of looted items. Display both components so the estimate is auditable. Keep values in integer copper and round only for display.
4. Define a session as a collection of runs for one character. Starting a new session archives the previous one. Keep the rolling lockout ledger independent of sessions.
5. Make MaraFarm work with Nova disabled. When supported Nova data is available, show a labeled comparison and allow opening Nova's log.

## 2. Verify the Forever client before implementing the rules

1. Record the client build and TOC interface with **/dump GetBuildInfo()**. The installed Nova 2.32 manifest lists Forever interface 16001. Use the number returned by the target client for the MaraFarm manifest.
2. Use a temporary, opt-in debug logger for timestamped world transitions, instance type and map ID, readable identity candidates, reset result messages, and loot-event availability. Keep names, chat content, and private SavedVariables out of Git.
3. Capture five transitions in Maraudon: first entry, ordinary exit, same-copy re-entry, successful reset followed by entry, and a failed reset. Verify any identity candidate is stable through re-entry and changes after a real reset. The instance map ID from **GetInstanceInfo()** identifies the dungeon map. Verify any map IDs for the Maraudon filter on the target client.
4. Check which identifiers and event values the client allows addons to read. Guard secret or unavailable values before comparing, parsing, indexing, or saving them. Treat missing evidence as unknown.
5. Measure the expiration rule near the cap using normal runs. Vary time spent in two copies, then test entry around both entry-plus-60 and exit-plus-60. Repeat after same-copy re-entry to determine whether its last exit refreshes the expiry. Compare Nova and the server's entry decision. Start with Nova 2.32's exit-first heuristic and label the result an estimate until confirmed. Also test an alt and an eligible non-Maraudon instance to verify the cap's scope and eligibility.
6. Record observations, build, and timestamps in a compatibility note. If copy identity, reset confirmation, or timer behavior is ambiguous, keep the count visibly estimated and document the observed limitation.

## 3. Create the addon and data model

1. Create **MaraFarm/MaraFarm.toc** with the verified interface, title, version, **SavedVariables: MaraFarmDB**, and **OptionalDeps: NovaInstanceTracker**. Load the database and pure tracking logic before event handlers and UI.
2. Start with **Database.lua**, **Tracking.lua**, **Loot.lua**, **Stats.lua**, **UI.lua**, **Nova.lua**, and **Core.lua** within that folder. Core owns event registration and initialization. Keep the calculations callable with sample data and an injected clock.
3. Initialize account-wide SavedVariables on MaraFarm's **ADDON_LOADED**. Version the schema and store characters, sessions, runs, lockout observations, and preferences. Partition lockout buckets using the client scope verified in step 2.5. Preserve existing runs when migrating.
4. Give each run a stable local ID. Save character, session, map and difficulty, optional copy identity with confidence, entry and exit timestamps, visit intervals, state, coin looted, and loot lines. Store each loot line's item link or identity, quantity, unit vendor value, and price state. Keep an index for unresolved prices.
5. Persist timestamps from **GetServerTime()** and use a monotonic clock for live visit durations where available. Maintain a small active-run checkpoint. Close or suspend cleanly at logout, and mark crash recovery or uncertain gaps as partial. Account-wide SavedVariables cover only the local client data available to the addon.

## 4. Track runs and the hourly lockout

1. Observe **PLAYER_ENTERING_WORLD** and relevant zone events. Read a settled snapshot using **IsInInstance()** and **GetInstanceInfo()**. Coalesce duplicate notifications and briefly retry unavailable snapshots. Feed snapshots to one state transition function.
2. On verified fresh entry, create a run and one lockout observation when the instance is eligible. On same-copy re-entry, resume the prior run and add a visit. On confirmed exit, close the visit once and update the observation according to the verified expiry rule. A fresh instance or confirmed reset can close the old run. Show exited runs in the table immediately and revise them if the same copy resumes.
3. When no opaque copy ID is readable, assign a local generation to the observed copy using dungeon, difficulty, character or group context, and confirmed reset evidence. Increment only after evidence of a new copy. A failed reset or duplicate zone event leaves the generation intact. Surface ambiguous transitions and avoid reporting an exact slot count if they could change it.
4. Reconcile the checkpoint on login and reload. Resume a verified matching visit without duplicating the run or ledger entry. Mark uncertain time intervals partial and exclude offline gaps from measured instance time.
5. Build the hourly view from eligible observations grouped by copy identity or estimated generation within the verified scope. For each active slot, compute its expiry from its anchor plus 3,600 seconds. Expire slots when current time reaches the expiry. Sort by expiry, show any active visit whose expiry is provisional, and clamp remaining slots at zero. If several slots expire together, release them together. Refresh countdown text once per second while visible.
6. Preserve observations when starting a fresh farming session. On first install or data gaps, surface incomplete coverage for the affected window. Handle an observed game lockout warning as a signal to display the discrepancy, without fabricating missing copy IDs.

## 5. Capture loot and vendor value

1. Start with **CHAT_MSG_LOOT** if readable on the tested Forever build. Verify a stable event sender identifier where readable. Otherwise match localized Blizzard self-loot message formats, including stack variants, rather than English text or substring matches. Use one authoritative path per acquisition. If the chosen event is restricted, use only a validated allowed alternative and mark unsupported pickups as a coverage limitation.
2. Record successful personal loot against the active run. Verify auto-loot, manual loot, stacks, loot after a kill, and events around zoning. For delayed events with reliable run context, keep the original run ID. Ignore other players' loot and inventory changes from merchants, trades, or mail.
3. Look up unit sell price with **C_Item.GetItemInfo** on the target client. Use the supported item-data request and completion API for cache misses. Distinguish pending, known zero, and unavailable. Update the original loot record even when the player has left the run or switched sessions.
4. Show item name/link, quantity, unit vendor price, and quantity times unit price. Aggregate identical item variants only when their vendor prices match. Keep known loot subtotal and unresolved item count visible. Snapshot resolved prices for historical comparisons.
5. Test **CHAT_MSG_MONEY** and localized looted-coin formats for direct coin. Count confirmed loot coin only. Show coin unavailable on unsupported paths and avoid using wallet changes as a substitute, since vendor sales and repairs change the same balance.

## 6. Build the table, summary popup, and minimap button

1. Add **/marafarm** to open a scrollable window with **Runs** and **Hourly Lockout** tabs. The Runs tab includes time, dungeon, inside duration, looted coin, vendor subtotal, estimated total, and tracking status. Selecting a run opens item rows. Offer current and archived session selection.
2. Show one row per active slot in Hourly Lockout, with dungeon, observed copy label, anchor time, time until expiry, and confidence when needed. Show the same count and next slot release in the summary popup. Display **Slot available now** whenever a slot is already free.
3. Add a small **Summary** popup with completed run count, total inside time, looted coin, vendor subtotal, estimated total, GPH, and average gold per run. Show live run progress separately. A partial run stays visible in history. Exclude it from the completed-run rate sample and show the excluded count. Pending prices make the displayed rates provisional.
4. Use the same completed-run sample for both metrics. **GPH = total estimated copper × 3,600 ÷ total measured inside seconds. Average gold per run = total estimated copper ÷ completed run count.** Show a dash for an undefined result. For a sample of 6g in 5 minutes and 9g in 10 minutes, show 60g/hour and 7g 50s per run.
5. Add a separate **Session GPH** for practical farm efficiency. Divide the same sample's value by elapsed time from its first entry to last exit, including travel, reset time, and lockout waits between runs. Label the main metric **In-instance GPH** so both denominators are clear.
6. Create a draggable, hideable minimap button using native frames or properly packaged minimap libraries. Save its position and visibility. Left-click toggles the table, right-click toggles the popup, and its tooltip shows the lockout count and next release. Keep slash access available when hidden.

## 7. Reset a session and retain history

1. Add **New Session** to the popup or table. Confirm the action, archive the current session with an end timestamp, and create a new session ID. Keep existing run ownership and the hourly ledger intact.
2. During an active visit, offer to start the new session after that visit ends. If the prior copy is later revisited, continue attributing that copy to its original session. The first new copy belongs to the new session.
3. After UI reload or relog, verify the new session, old histories, and lockout countdowns restore. Open an archived session to compare runs, item values, and both GPH metrics.

## 8. Integrate with Nova Instance Tracker

1. The locally installed **NovaInstanceTracker 2.32** declares **NITdatabase**, sets the Forever hourly limit to 10, and exposes a Lua addon object **NIT**. Its **getInstanceLockoutInfo()** returns hourly count, daily count, hourly timestamp, and daily timestamp. Its implementation prefers each record's **leftTime** and falls back to **enteredTime**. This is an observed internal interface. [Nova Instance Tracker project](https://www.curseforge.com/wow/addons/nova-instance-tracker)
2. In **Nova.lua**, detect load state with the tested addon API and validate the version and method before a guarded read. Probe after both addons initialize and on a compatible late load. Require ordinary numeric output in a valid range and check timestamp plausibility. Keep absent, disabled, unsupported, and failed reads safe.
3. For the first adapter, show **Nova observed count** and its supported countdown beside **MaraFarm estimated count**. Label mismatches and provide an **Open Nova Log** button using a verified entry point or the documented **/nit** command. Compare the same character or broader scope where possible.
4. Keep all MaraFarm run, loot, and financial summaries sourced from MaraFarm's own data. Avoid writing into Nova's state or combining counters from both. Add compatibility for another Nova version only after verifying its return values and scope.

## 9. Test and release

| Check | Expected result |
| --- | --- |
| Enter, leave, re-enter, then successfully reset Maraudon | Two runs, two eligible slots, and two visits on the first run |
| Failed reset, repeated zone events, or reload inside | Stable run identity and no duplicate slot or loot |
| Ten eligible copies and expiry at exactly 3,600 seconds | Cap shown at 10, then the correct number of slots released |
| Alternate character and another eligible dungeon | Hourly view follows verified scope while Maraudon summary stays filtered |
| Mixed loot, stacks, uncached and unsellable items | Correct quantity and totals, pending distinct from zero, history updates when price resolves |
| Zero-duration sample, two differently timed runs, and partial run | Undefined rates handled, weighted GPH correct, partial status visible |
| Reset session with a run active, then relog | Requested reset persists, existing history and slots remain, next new copy goes to the new session |
| Nova absent, supported, disabled, or changed | Standalone features work throughout, with comparison only when compatible |

1. Run pure Lua tests for transitions, rolling window boundaries, and copper calculations. Play-test with script errors enabled on the target Forever build. Compare sample loot against merchant tooltip prices and check the lockout estimate during ordinary farming.
2. Package a ZIP containing **MaraFarm/MaraFarm.toc** and its runtime files. Install that folder under **World of Warcraft/_forever_/Interface/AddOns/** and verify it loads from a clean profile with Nova disabled and enabled.
3. Tag the tested version and attach the ZIP to a GitHub release. Record client build, verified Nova version, and any limits in tracking coverage in the release notes.

Client API reference: [Blizzard UI source mirror, Forever branch](https://github.com/Gethe/wow-ui-source/tree/forever).
