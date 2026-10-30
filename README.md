# Field Repairs

Collection of small crash, stability and performance fixes for RAID: WW2. Each fix is one hook
and one file in `lua/`; they are independent of each other. Each can be switched off in Options > Field Repairs
(saved in `saves/FieldRepairs.json`, applies at once; the callback queue from the next raid).

Author: BangL

| Fix | Hook | File | Problem |
| --- | --- | --- | --- |
| [Husk customization crash](#husk-customization-crash) | `lib/units/characters/charactercustomization` | `lua/CharacterCustomization.lua` | Engine crash when a joiner aborts while the husk is spawned |
| [Mission script callback queue](#mission-script-callback-queue) | `lib/managers/missionmanager` | `lua/MissionScript.lua` | Frametime spikes in maps with many polling mission elements (Odin's Fall) |
| [Mission world leak](#mission-world-leak) | `core/lib/managers/coreworldcollection` | `lua/CoreWorldCollection.lua` | 10-20 MB of Lua heap stay behind per raid that is started and left |
| [Waypoint without target](#waypoint-without-target) | `lib/managers/hudmanager` | `lua/HUDManager.lua` | Lua error when a waypoint has neither position nor unit |
| [Portal group unit leak](#portal-group-unit-leak) | `core/lib/managers/coreportalmanager` | `lua/CorePortalManager.lua` | Removed units stay referenced in portal unit groups |
| [Corpses in enemy detection](#corpses-in-enemy-detection) | `lib/managers/group_ai_states/groupaistatebase` | `lua/GroupAIStateBase.lua` | Detection walks every corpse per unit and tick, bad frametime in big fights with a high corpse limit |

## Installation

copy the `Field Repairs` folder to `mods/`. Requires SuperBLT 2.x (`blt.pcall`, `BLT:Log`).

## Husk customization crash

`CharacterCustomization:_part_loaded_callback` is replaced by the vanilla function with alive
checks. The dyn_resource callback can fire synchronously while a husk is being spawned
(drop-in). If the husk is destroyed meanwhile (the joiner aborts), the native `get_object`,
`position` and `rotation` calls on dead objects crash the engine.

Differences to vanilla: the husk, the spawned part and both units of the bone loop are checked
with `alive()`; a part that could not be spawned is logged (`[Field Repairs] CharacterCustomization`)
and skipped; bones missing on either unit are skipped instead of erroring.

Risk: the whole function is replaced. A game patch that changes the original is overridden
silently.

## Mission script callback queue

Makes the callback queue of the mission scripts cheap. Fixes the recurring frametime spikes in
**Odin's Fall** (`flakturm`); every other map benefits in proportion to how many timed
mission elements it has.

### Symptom

Frametime spikes in Odin's Fall, about every 250 ms on the reporter's machine. They show up in
stealth too, even with nearly all enemies dead, and they get worse after other maps were played
first on a high difficulty. Other maps are not affected.

### Measurements

Everything was measured in the running game with LuaDebugAPI, difficulty 4, god mode on. The
"after 13 raids" runs follow a full cycle of all raids (`forest_gumpy` to `forest_bunker`).

| Map / state                              | median  | p95     | p99     | spike frames per 30 s |
| ---------------------------------------- | ------- | ------- | ------- | --------------------- |
| Camp                                     | 5.6 ms  | 6.0 ms  | 6.7 ms  | 4                     |
| Silo                                     | 5.6 ms  | 7.9 ms  | 8.7 ms  | 5                     |
| Odin's Fall, after 13 raids, **without** | 9-15 ms | 43 ms   | 68 ms   | 289                   |
| Odin's Fall, after 13 raids, **with**    | 10.6 ms | 11.6 ms | 12.5 ms | 7                     |

A spike frame is a frame gap of more than twice the median. Without the fix the spikes arrive
in a 0.1 s grid (30-45 ms) with larger ones every second (up to 75 ms). With it, only one engine
hitch remains (see "Remaining").

### Cause

- `GameSetup:update` spent on average 33 ms per spike frame in **Lua**, so it is not the
  renderer. Neither the number of enemies, the garbage collector (stopping it changed
  nothing), any single mission element (each takes 3 ms or less), nor any mod is responsible.
- The time is inside `CoreMissionManager.MissionScript:update`, in `CallbackHandler:update`
  (`core/lib/utils/coreevent.lua`). It keeps all timed callbacks in one ascending array and
  pays `table.remove(t, 1)` plus a sorted `table.insert(t, i, cb)` for **every** callback it
  runs.
- In this LuaJIT build `table.remove` is a Lua builtin. Moving one element costs about 1 us,
  and any other Lua operation costs about the same: 2M additions take 1.9 s. Native
  `table.insert` is fast, `table.remove(t, 1)` is not (169 elements: 160 us per call).
- Odin's Fall has about 170 queued callbacks in its `default` script. Almost all are
  `ElementAreaTrigger:update_area` and `update_lookat` polls with 0.1, 0.2 and 1.0 s
  intervals. 64 to 106 of them run per tick, and about 150 once per second. The array work
  is quadratic, which gives 20-35 ms per 0.1 s tick and about 70 ms per second.
- Silo and the camp have far fewer queued callbacks and never reach this.
- Why it gets worse after many other maps is **not** explained. Fresh-start Odin's Fall,
  without prior raids, measured clean.

### Fix

`lua/MissionScript.lua` replaces `__insert_sorted` and `update` on
`CoreMissionManager.MissionScript` (the instances use the core class, not the global
`MissionScript` subclass from `lib/managers/missionmanager`).

The 169 callbacks have only 7 distinct due times. Callbacks with the same due time now share
a bucket. Only the due times are kept in a descending array, so the next one is at the end
and popping it shifts nothing. Inserting a callback is a table lookup and an append. Buckets
and array live in `self._sorted`, so `clear()` resets both.

Semantics stay the same:

- Due callbacks run in ascending due time. On equal due time the newest runs first, as in the
  original, where a new entry was inserted in front of equal ones. A bucket is walked from the
  end.
- `times`, `interval` and re-queueing (`next + interval`) are copied unchanged.
- A callback that adds a new one while running gets it executed in the same update when it is
  already due, as before.
- `remove()` only clears `cb.next`. The entry stays queued and is skipped when its turn comes.
- The `_updators` loop is kept.
- Nothing else in the game or the installed mods reads `_sorted`.

### Verification

- **Differential test.** The same random scenarios (equal and different intervals, `times` of
  -1 to 3, removal of other callbacks and of itself, adding callbacks while running, varying
  frame times) ran through the original `CoreEvent.CallbackHandler` and through the patched
  `MissionScript`. 40 seeds and about 7000 executed callbacks gave 0 differences in order or
  time.
- **In game.** Full cycle of 13 raids with the fix loaded through its hook, then Odin's Fall.
  The queues stay consistent (33 and 168 entries, one expired one-shot callback), time advances
  and the log has no errors from the fix.
- **Not tested:** multiplayer, a complete raid with all scripted events (timers, waves,
  delays), and any before/after comparison on maps other than Odin's Fall.

### Remaining

- One hitch of 35-45 ms every ~4.5 s in Odin's Fall. Lua accounts for only 1-2 ms of it, the
  GC is not the cause, and a similar hitch (every 6-7 s) exists in Silo and the camp. It is an
  engine-side hitch, not specific to Odin's Fall.
- The median in Odin's Fall stays at about 10 ms (Silo: 5.6 ms), probably rendering of the
  level.

### Risks

- Buckets need exactly equal float due times. If they differ, there are just more buckets:
  still correct, only slower.
- A removed callback stays in its bucket until its due time (the original dropped it at the
  next update). Many removed callbacks with long intervals therefore stay in memory longer.
- Writes to `cb.next` of a queued callback from outside the queue are not supported and were
  not exhaustively searched for.
- The whole core `update` is replaced. A game patch to the original, or another mod that
  overrides `MissionScript:update` or `__insert_sorted`, would conflict.

## Mission world leak

Every raid that is started and left without a Lua reload leaves 10 to 20 MB behind in the Lua
heap. `CoreWorldCollection:destroy_world` is wrapped and lets go of what belongs to the
destroyed world, and nothing else:

- **Nav links.** `NavigationManager:unregister_anim_nav_link` removes a link from the engine,
  but the engine keeps its user data table `{element = element}` in the registry, which holds
  the whole mission script. The world never calls `ElementNavLink:destroy`, so the links are
  unregistered here and `element` is cleared in the registry tables.
- **Callbacks of destroyed elements.** `MissionManager._runned_unit_sequences_callbacks` and the
  `_use_unit_callbacks` of the main world definition are only emptied when the whole simulation
  stops. Callbacks of the elements of the destroyed world are removed from them. A callback
  belongs to an element if its first upvalue is that element (callbacks made with
  `callback(object, ...)`).

Failures while collecting or releasing are caught with `blt.pcall` and logged as warnings
(`[Field Repairs] Could not ...`); the original `destroy_world` always runs.

Risks: the registry is scanned once per destroyed world. The upvalue check only finds
callbacks that follow the `callback(object, ...)` pattern; others stay (no wrong removal,
just no gain).

## Waypoint without target

`HUDManager:add_waypoint` does `data.position or data.unit:position()`. If a waypoint has no
position and its unit is nil or dead, that errors. The wrapper skips such a waypoint and logs a
warning (`[Field Repairs] Waypoint <id> has neither position nor unit`). Idea from The Fixes (PD2).

## Portal group unit leak

`PortalUnitGroup:remove_unit_id` only clears the id, the unit stays in `_units`. The wrapper
also removes that unit (by identity) from `_units`. Idea from Celer (PD2).

## Corpses in enemy detection

### Symptom

Big fights (20+ enemies) get slow, 16 FPS in Settlement with the corpse limit (video settings) at 128.

### Measurements

Live with `LuaDebugAPI`, 10 s window, 26 living enemies, 129 corpses:

- `EnemyManager:update` 74% of the frame time, nearly all of it `CopLogicBase._upd_attention_obj_detection`
  (68%, about 3 ms per call, ~210 calls per second).
- Each call walks ~159 attention objects: 129 corpses (slot 17), 26 living enemies, bots and players.
  About 250,000 loop iterations per second, 80% of them for dead units.
- Mission area triggers, `GroupAIStateBase:update`, HUD and movement together stay below 10%.

### Cause

A dead enemy stays a registered attention object until its corpse is disposed of, which happens at
`corpse_limit` (default 32, up to 250). Every living enemy and bot checks every one of them each detection tick.

### Fix

`get_AI_attention_objects_by_filter` returns a copy without dead units once the level is loud. In stealth the vanilla set
is used, guards still find bodies. The copy is cached per filter and rebuilt when an attention object is registered,
changed or removed, and at the latest after a second (units that died since). The vanilla sets are not touched.

### Risks

- Enemies and bots do not react to corpses while loud. Nothing in the vanilla code uses that (only the stealth
  voice lines and alerts for bodies), but this was read from the code, not played through.
- A unit that died stays in the set for up to a second.
