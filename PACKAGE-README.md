# rsblood-progressbar

I built **rsblood-progressbar** for RealitySucksRP as a free, blood-and-infection themed progress bar for FiveM. It is framework-agnostic, GTA V Legacy and GTA V Enhanced ready, and includes compatibility paths for QBCore, Qbox, ox_lib, ESX, and standalone resources.

The redesigned NUI stays bottom-center with a compact **RS Contamination System** panel, clearer task and stage hierarchy, a readable percentage/timer, a thicker animated progress track, responsive scaling, and four self-contained visual themes.

## What server owners need to know

- No framework is required.
- The native API is always available.
- QBCore/Qbox `progressbar` compatibility is always registered.
- ESX `esx_progressbar` compatibility is always registered.
- ox-style adapter exports are included on this resource.
- Vue is included locally and remote Google Fonts were removed; the UI has no internet dependency.
- A watchdog releases controls, props, and `inv_busy` if the NUI ever stops responding.
- Attached props are limited and checked server-side before being tracked.

## Installation

1. Keep the folder name `rsblood-progressbar`.
2. Place it in your server resources folder.
3. Stop or remove the original `progressbar` and `esx_progressbar` resources if they are installed.
4. Start this resource before scripts that use a progress bar:

```cfg
ensure rsblood-progressbar
```

This resource declares:

```lua
provide 'progressbar'
provide 'esx_progressbar'
```

That lets resources with standard QBCore or ESX progress-bar dependencies use this replacement. **Do not run two providers for the same name.** Version 3.2.0 prints a server-console warning when an actual `progressbar` or `esx_progressbar` resource is also running.

## Recommended native API

Use this for new integrations on every framework:

```lua
local started = exports['rsblood-progressbar']:Start({
    label = 'Extracting Virus Sample...',
    duration = 6000,
    canCancel = true,
    disableMovement = true,
    disableCombat = true,
    animation = {
        dict = 'amb@world_human_seat_wall_tablet@female@base',
        clip = 'base',
        flag = 1,
    },
}, function(cancelled, minigameResult)
    if cancelled then
        print('Extraction cancelled.')
        return
    end

    print('Sample extracted!')
end)

if not started then
    print('Progress could not start because it was busy, not ready, invalid, or the player was dead.')
end
```

The callback can also live inside the task:

```lua
exports['rsblood-progressbar']:Start({
    label = 'Applying Bandage...',
    duration = 4000,
    onFinish = function()
        print('Bandage applied.')
    end,
    onCancel = function()
        print('Bandaging cancelled.')
    end,
})
```

### Native exports

```lua
exports['rsblood-progressbar']:Start(data, callback) -- returns true/false
exports['rsblood-progressbar']:Progress(data, callback) -- QBCore-style alias
exports['rsblood-progressbar']:isActive() -- boolean
exports['rsblood-progressbar']:isDoingSomething() -- boolean alias
exports['rsblood-progressbar']:Cancel(true) -- force-cancel active task
```

## QBCore and Qbox compatibility

Resources using the common API can continue calling:

```lua
exports['progressbar']:Progress(data, function(cancelled)
    if not cancelled then
        print('Completed.')
    end
end)
```

Supported compatibility exports:

- `Progress`
- `isDoingSomething`
- `ProgressWithStartEvent`
- `ProgressWithTickEvent`
- `ProgressWithStartAndTick`

The standard `progressbar:client:*` events are also registered. This adapter does not require `qb-core`, so it remains available on Qbox and standalone servers.

## ESX compatibility

Resources using the standard replacement name can call:

```lua
exports['esx_progressbar']:Progressbar('Searching...', 5000, {
    FreezePlayer = false,
    canCancel = true,
    onFinish = function()
        print('Search completed.')
    end,
    onCancel = function()
        print('Search cancelled.')
    end,
})
```

## ox-style adapter

Do **not** delete or replace ox_lib's own `progress.lua` file. That creates update problems and makes the server harder to support.

For a resource you control, route the call directly to this adapter:

```lua
local completed = exports['rsblood-progressbar']:progressBar({
    duration = 5000,
    label = 'Collecting Blood Sample...',
    canCancel = true,
    disable = {
        move = true,
        combat = true,
    },
    anim = {
        dict = 'amb@medic@standing@tendtodead@base',
        clip = 'base',
    },
})

if completed then
    print('Sample collected.')
end
```

Available adapter exports include both naming styles:

```lua
progressBar / ox_lib_progressBar
progressCircle / ox_lib_progressCircle
progressActive / ox_lib_progressActive
cancelProgress / ox_lib_cancelProgress
```

Existing third-party resources hardcoded to `lib.progressBar` will still use ox_lib unless that individual resource supports selecting a provider. This package intentionally does not hijack ox_lib's exports.

The adapter honors ox-style `allowRagdoll`, `allowSwimming`, `allowCuffed`, and `allowFalling` restrictions and accepts either an animation table or a scenario string.

## Supported task fields

| Field | Purpose |
|---|---|
| `label` | Text displayed on the bar |
| `duration` | Duration in milliseconds |
| `canCancel` | Enables player cancellation; defaults to `true` |
| `useWhileDead` | Allows progress while dead |
| `position` | `center-bottom` by default; `center`/`middle` are supported |
| `progressColor` | Optional fill color |
| `theme` | `default`/`blood`, `infection`, `medical`, or `tactical` |
| `icon`, `iconColor` | Accepted for compatibility; the panel uses its built-in self-contained emblem |
| `controlDisables` | QBCore-style control table |
| `disableMovement`, `disableMouse`, `disableSprint`, `disableCarMovement`, `disableCombat` | Simple top-level aliases |
| `animation` / `anim` | Animation or scenario data; accepts `dict`/`clip` and `animDict`/`anim` names |
| `animations` | Sequential animation list |
| `prop`, `propTwo`, `props` | Attached props, maximum five |
| `stages` | Multi-stage progress tasks, conditions, and minigames |
| `onStart`, `on_finish`, `onFinish`, `onCancel` | Lifecycle callbacks |

## Configuration

Edit `lua/config.lua`:

```lua
Config.devMode = false
Config.theme = 'default'
Config.locale = 'en'
Config.useInventoryBusyState = true

Config.cancel = {
    enabled = true,
    key = 'X',
    legacyCommand = false,
}

Config.watchdog = {
    enabled = true,
    graceMs = 5000,
}
```

### Cancel-key collision

The cancel binding now belongs to `Config.cancel`. When another script already owns `X`, either change the key or set `enabled = false`. The historical misspelled keep-progressbar command is disabled by default; set `legacyCommand = true` only for a deliberate migration need.

### Inventory safety

When `Config.useInventoryBusyState` is enabled, the resource sets QBCore's `inv_busy` state only when it was previously false. It only clears the state when it owns that change, so it does not unlock another resource's active inventory action.

The resource also publishes:

```lua
LocalPlayer.state.rsblood_progress_active
```

## Testing

Set `Config.devMode = true`, restart the resource, and run:

```text
/rsbloodtest
```

The command starts a five-second cancellable test bar. Set dev mode back to `false` before release.

## Important packaging notes

- Keep `html/vue.global.prod.js`; it is intentionally vendored.
- Keep the self-contained system-font stack; do not add a remote font import.
- Do not restore the deleted root-level `client.lua`.
- Do not run the original `progressbar` or `esx_progressbar` beside this replacement.
- No SQL is required.
- No escrow is used.

## Validation status

Version 3.2.0 has been Lua 5.4 parsed, JavaScript syntax-checked, exercised through Lua and JavaScript lifecycle harnesses, and package-audited. A final live FiveM runtime pass is still required before calling it production-verified.

Free community release by **RealitySucksRP**. Engine foundation credited to keep-progressbar.
