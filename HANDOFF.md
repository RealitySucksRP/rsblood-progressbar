# rsblood-progressbar — Engineering Handoff

**Current baseline:** v3.2.0  
**Date:** 2026-07-28  
**Resource:** `rsblood-progressbar`  
**Author:** William Brito — RealitySucksRP

A blood/horror themed FiveM progress bar with a framework-independent native API plus compatibility adapters for the common QBCore/Qbox `progressbar`, ESX `esx_progressbar`, and ox-style data shapes.

Version 3.2.0 preserves the v3.1.0 bridge and lifecycle baseline while replacing the original flat blood panel with the approved compact RS Contamination System presentation. The visual pass is still fully self-contained: no remote fonts, images, icon libraries, or CDN calls.

---

## v3.2.0 visual baseline

The bridge contract and Lua lifecycle remain the locked v3.1.0 behavior. The v3.2.0 work is an NUI presentation pass:

- compact bottom-center **RS Contamination System** panel;
- real task labels and stage messages instead of hard-coded fake phase names;
- visible phase count and completed/current stage rail;
- thicker segmented progress track with percentage and remaining time;
- self-contained blood-drop/pulse emblem drawn as inline SVG;
- responsive layout for smaller resolutions;
- reduced-motion support;
- existing task `theme` field now selects `default`/`blood`, `infection`, `medical`, or `tactical`;
- no remote fonts, image files, Font Awesome, CDN calls, or new runtime dependencies.

Do not replace the inline emblem with an external icon dependency. Do not restore the old fixed `INITIATE / EXTRACT / ANALYZE / COMPLETE` labels because they were inaccurate for arbitrary integrations.

---

## 1. File map and load order

`fxmanifest.lua` is the source of truth:

```lua
client_scripts {
    'lua/config.lua',
    'lua/client.lua',
    'lua/locales/*.lua',
    'lua/provider.lua',
}

server_scripts {
    'lua/server.lua',
}
```

Load order matters:

1. `lua/config.lua` creates `Config`.
2. `lua/client.lua` creates the global `Progress` engine.
3. Locale files call `Progress:_registerLocale(...)`.
4. `lua/provider.lua` registers current-resource exports and replacement aliases.

NUI files:

```text
html/index.html
html/style.css
html/themes.css
html/script.js
html/vue.global.prod.js
```

Vue is vendored locally. The former Google Fonts `@import` was also removed and replaced with system-font stacks. Do not add remote NUI dependencies.

The obsolete root-level `client.lua` remains deleted. Do not restore it.

---

## 2. Replacement-provider behavior

The manifest declares:

```lua
provide 'progressbar'
provide 'esx_progressbar'
```

This allows dependencies that request either standard resource name to accept `rsblood-progressbar` as the provider.

The adapters themselves are now registered **unconditionally**. They no longer depend on `qb-core`, `qbx_core`, `ox_lib`, or `es_extended` being present or already started.

That removes framework load-order sensitivity and makes the bridge usable on:

- QBCore
- Qbox
- ESX
- standalone
- mixed servers using the common `progressbar` API

Do not run an actual `progressbar` or `esx_progressbar` resource at the same time. The server prints a warning when it detects either conflict running.

---

## 3. Native public API

Always available under the actual resource name:

```lua
exports['rsblood-progressbar']:Start(data, callback)
exports['rsblood-progressbar']:Progress(data, callback)
exports['rsblood-progressbar']:isActive()
exports['rsblood-progressbar']:isDoingSomething()
exports['rsblood-progressbar']:Cancel(force)
```

`Start` and `Progress` return:

```text
true   task accepted and started
false  task rejected
```

Internal rejection reasons include:

- `busy`
- `nui_not_ready`
- `invalid_task`
- `player_dead`
- `player_ragdoll` / `player_swimming` / `player_cuffed` / `player_falling` for ox-style tasks
- `start_error`

The exported API returns the boolean only. Callers that need detailed diagnostics should use their own state/logging around the call.

The callback signature is:

```lua
callback(cancelled, minigameResult)
```

---

## 4. Compatibility APIs

### QBCore / Qbox / common progressbar

Available through `exports['progressbar']` and directly on `rsblood-progressbar`:

```text
Progress
isDoingSomething
ProgressWithStartEvent
ProgressWithTickEvent
ProgressWithStartAndTick
```

Standard events are registered:

```text
progressbar:client:cancel
progressbar:client:ToggleBusyness
progressbar:client:progress
progressbar:client:ProgressWithStartEvent
progressbar:client:ProgressWithTickEvent
progressbar:client:ProgressWithStartAndTick
```

`ToggleBusyness` no longer directly mutates `_active`. Direct mutation could strand controls, props, animations, and `inv_busy`. A false value force-cancels a real active task; a true value does not invent one.

When a compatibility call cannot start, its QBCore-style callback is resolved as cancelled instead of being left hanging.

### ESX

Available through:

```lua
exports['esx_progressbar']:Progressbar(message, length, options)
exports['esx_progressbar']:CancelProgressbar()
```

The adapter accepts missing options, handles animation/scenario shapes, safely freezes/unfreezes the current player ped, and calls cancellation callbacks when start is rejected.

### ox-style adapter

Available directly on `rsblood-progressbar`:

```text
progressBar / ox_lib_progressBar
progressCircle / ox_lib_progressCircle
progressActive / ox_lib_progressActive
cancelProgress / ox_lib_cancelProgress
```

Important limitation: this does **not** hijack `lib.progressBar` inside ox_lib. A resource must call this adapter directly or expose a provider setting. Do not replace ox_lib's core `progress.lua` file.

The former ox conversion bug is fixed: `disable`, `prop`, and `position` now convert independently instead of only converting when `anim` was present. String scenario animations are also accepted.

The adapter marks ox tasks internally and enforces ox-style `allowRagdoll`, `allowSwimming`, `allowCuffed`, and `allowFalling` rules at start and while active.

If the task cannot start, the ox promise resolves `false`; it no longer waits forever.

---

## 5. Normalized task contract

`Progress:Start` normalizes the incoming table before use.

Supported aliases include:

```text
animation.dict / animation.animDict
animation.clip / animation.anim / animation.lib
animation.flag / animation.flags
animation.scenario / animation.task
prop.coords / prop.pos
prop.rotation / prop.rot
```

Control disabling accepts either:

```lua
controlDisables = {
    disableMouse = true,
    disableMovement = true,
    disableSprint = true,
    disableCarMovement = true,
    disableCombat = true,
}
```

or top-level aliases:

```lua
disableMouse = true
disableMovement = true
disableSprint = true
disableCarMovement = true
disableCombat = true
```

Lifecycle callbacks:

```text
onStart
on_finish(cancelled, minigameResult)
onFinish(minigameResult)       success only
onCancel(minigameResult)       cancellation only
```

Props:

```text
prop
propTwo
props[]
```

All normalize into one internal `props` array. Maximum: five.

Stages are shallow-copied so internal `triggered` and completion state do not mutate the caller's original stage table.


Presentation compatibility notes:

- `position = 'center-bottom'` is the default.
- `position = 'center'` and ox-style `position = 'middle'` render centered.
- `theme`, `icon`, and `iconColor` remain accepted metadata for compatibility.
- Only the default blood theme is shipped, and the current approved layout does not render an icon.


Only serializable stage metadata is sent to the NUI. Lua functions are represented by boolean `condition` and `minigame` flags instead of being sent through `SendNUIMessage`.

---

## 6. Lifecycle and race protection

Each accepted task receives a monotonically increasing `sessionId`.

Every NUI callback includes that session ID. Lua ignores stale callbacks from an older task.

This closes the important cancel/restart race:

```text
old task cancelled
→ Lua immediately releases old state
→ new task starts
→ delayed old NUI progressFinished arrives
→ stale session is ignored instead of cancelling the new task
```

The NUI also clears delayed finish timers when a new session starts.

Completion now goes through one `_finalize(...)` path, which:

1. validates the active session
2. marks the task inactive
3. stops animations
4. deletes/tracks props
5. releases owned statebags
6. clears the completed run's internal fields
7. invokes callbacks exactly once

Internal state is cleared **before** callbacks. A completion callback may immediately start another progress task without the old cleanup erasing the new task.

Cancellation state is no longer reset inside generic cleanup before callbacks read it. QBCore/ox/ESX callbacks now receive the correct `cancelled` value.

---

## 7. NUI watchdog

Configuration:

```lua
Config.watchdog = {
    enabled = true,
    graceMs = 5000,
}
```

For ordinary timed tasks, Lua schedules a watchdog for:

```text
expected task duration + graceMs
```

If the NUI never reports completion, the watchdog:

- treats the task as cancelled
- sends a cancel message to the NUI
- stops controls and animations
- cleans attached props
- releases `inv_busy`
- resolves callbacks
- prints a client-console diagnostic

Conditional stages intentionally skip the duration watchdog because their waiting period is not bounded by the stage duration.

---

## 8. Inventory-state ownership

Configuration:

```lua
Config.useInventoryBusyState = true
```

The resource publishes:

```lua
LocalPlayer.state.rsblood_progress_active
```

For QBCore/qb-inventory compatibility it can also use:

```lua
LocalPlayer.state.inv_busy
```

Version 3.2.0 only sets `inv_busy` when it was previously false and records that it owns the change. It only clears `inv_busy` when it owns it.

This prevents the progress bar from unlocking an inventory action owned by another resource.

---

## 9. Cancellation key

Configuration:

```lua
Config.cancel = {
    enabled = true,
    key = 'X',
    legacyCommand = false,
}
```

The default key mapping now uses:

```text
+rsblood_progress_cancel
```

The old misspelled command can be enabled only when required:

```lua
Config.cancel.legacyCommand = true
```

It is disabled by default so old persisted bindings cannot create a second hidden `X` cancellation path. Server owners can change or disable the key in one config location when another resource already owns `X`.

The UI locale uses `{key}`, so the displayed cancellation key follows config.

---

## 10. NUI protocol

### Lua to NUI

```text
START_PROGRESS
CANCEL
SET_LOCALE
CONDITIONAL_SKIP
MINIGAME_RESULT
```

Task messages include `sessionId`.

### NUI to Lua

```text
ready
progressFinished
stageStart
stageFinished
stageMinigame
minigameFailed
```

Task callbacks include `sessionId`.

`ready` remains the handshake that unlocks `Start`. If a call arrives before ready, `Start` returns false and prints a diagnostic instead of silently disappearing.

---

## 11. Prop cleanup and server validation

The client now uses branded event names:

```text
rsblood-progressbar:server:register_props
rsblood-progressbar:server:cleanup_props
```

The server still accepts all former keep-progressbar spellings, including the historical typo:

```text
keep-progressbar:server:register_props
keep-progressbar:server:cleanup_props
keep-progressbar:serer:cleanup_props
```

The typo is no longer load-bearing. New code uses the correct branded event; legacy names are compatibility-only.

Server validation now checks:

- both payloads are arrays
- counts match
- no more than five props
- network ID and model are numeric/nonzero
- entity resolves within a bounded replication wait
- entity is an object when the native is available
- entity owner matches the source when the native is available
- actual model matches the claimed model
- model is not blacklisted
- per-player tracked count remains within the limit

Malformed cleanup payloads no longer throw through `ipairs(nil)`.

A short recently-released cache prevents a delayed registration thread from re-tracking a prop that a fast task already cleaned up.

`playerDropped` and resource shutdown both sweep tracked entities.

---

## 12. Resource-stop behavior

The client now checks the stopped resource name:

```lua
if resourceName ~= GetCurrentResourceName() then return end
```

Previously, the generic `onResourceStop` handler could clean the active progress task whenever **any** client resource stopped.

Shutdown cleanup suppresses gameplay completion callbacks while still releasing states and props.

---

## 13. README corrections

The v3.0.0 README contained three integration traps:

1. It called `exports['rsblood-progressbar']:Progress(...)`, but that direct export did not exist.
2. It showed top-level `disableMovement` / `disableCombat`, which the engine ignored.
3. It showed `animation.dict` / `animation.clip` plus task `onFinish` / `onCancel`, which the engine did not consume.

Version 3.2.0 supports those documented shapes and registers the direct export.

The instruction to delete and replace ox_lib's `progress.lua` has been removed. The README now documents direct adapter usage and the exact limitation for third-party resources hardcoded to `lib.progressBar`.

---

## 14. rs-consumables contract

`rs-consumables` should continue preferring the native exports:

```lua
exports['rsblood-progressbar']:Start(...)
exports['rsblood-progressbar']:isActive()
```

Retain its existing rule to fall back rather than abort when the provider is busy or unavailable.

Version 3.2.0 improves that integration by returning a real start boolean and guaranteeing the cancellation callback/state cleanup path.

When both resources expose an `X` binding, disable or change one through config rather than editing engine code.

---

## 15. Validation completed

Completed in this package audit:

- all Lua files parsed with the Lua 5.4 library
- server CFX backtick hash syntax was replaced only in a temporary parser copy
- `html/script.js` passed `node --check`
- Lua harness executed native start, normalization, completion, cancellation, non-cancellable behavior, reentrant next-task start, export/alias registration, ox rejection resolution, and QBCore busy rejection callbacks
- JavaScript harness executed NUI ready, normal completion, stale-session cancellation race, replacement session, and conditional-stage skip
- archive file map and required manifest files checked
- no SQL or external runtime dependency added

Not completed:

- live FiveM client/server runtime test
- live QBCore, Qbox, ESX, and ox consumer test
- live networked prop ownership/replication test

Treat v3.2.0 as statically and browser-harness validated, not yet live-server certified.

---

## 16. Required live smoke test

Before production release:

1. Start with no original `progressbar` or `esx_progressbar` running.
2. Confirm the server prints the v3.2.0 ready line and no conflict warning.
3. Run `/rsbloodtest` with `Config.devMode = true`.
4. Complete once and cancel once.
5. Confirm `LocalPlayer.state.inv_busy` returns to its prior value.
6. Start a second bar immediately from the first callback.
7. Test a QBCore/Qbox `exports['progressbar']:Progress` call.
8. Test one ESX replacement call.
9. Test one direct ox-style adapter call.
10. Test one prop attachment and verify cleanup on complete, cancel, and disconnect.
11. Stop an unrelated resource during a bar and confirm the bar continues.
12. Stop `rsblood-progressbar` during a bar and confirm controls/state release.
13. Return `Config.devMode` to `false`.
