Config = Config or {}

-- Set true only while testing. Enables additional console diagnostics and /rsbloodtest.
Config.devMode = false

Config.theme = 'default'
Config.locale = 'en'

-- QBCore/qb-inventory compatibility. The resource only clears inv_busy when it
-- was the resource that set it, so it will not unlock another script's action.
Config.useInventoryBusyState = true

-- Keyboard cancellation. Set enabled = false when another resource owns the
-- same cancel key. FiveM players can still rebind this in Settings > Key Bindings.
Config.cancel = {
    enabled = true,
    key = 'X',
    legacyCommand = false,
}

-- Failsafe for a crashed or wedged NUI. The action is treated as cancelled so a
-- visual failure cannot silently grant completion, and inv_busy is always released.
Config.watchdog = {
    enabled = true,
    graceMs = 5000,
}
