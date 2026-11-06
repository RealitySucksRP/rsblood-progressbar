local function warnBridge(message)
    print(('[rsblood-progressbar] %s'):format(message))
end

local function replaceExport(resourceName, exportName, func)
    local eventName = ('__cfx_export_%s_%s'):format(resourceName, exportName)
    AddEventHandler(eventName, function(setCB)
        setCB(func)
    end)
end

local function rejectCallback(callback)
    if type(callback) ~= 'function' then return end
    SetTimeout(0, function()
        pcall(callback, true, nil)
    end)
end

-- --------------------------------------------------------------------------
-- progressbar / QBCore-compatible API
-- Registered unconditionally. It does not require qb-core and therefore also
-- works for Qbox, ESX, and standalone resources that use the common API.
-- --------------------------------------------------------------------------

local function qbProgress(data, onFinish)
    local started = Progress:Start(data, nil, onFinish)
    if not started then rejectCallback(onFinish) end
    return started
end

local function qbProgressWithStart(data, onStart, onFinish)
    local started = Progress:Start(data, onStart, onFinish)
    if not started then rejectCallback(onFinish) end
    return started
end

local function qbProgressWithTick(data, onTick, onFinish)
    local started = Progress:Start(data, nil, onFinish, onTick)
    if not started then rejectCallback(onFinish) end
    return started
end

local function qbProgressWithStartAndTick(data, onStart, onTick, onFinish)
    local started = Progress:Start(data, onStart, onFinish, onTick)
    if not started then rejectCallback(onFinish) end
    return started
end

local progressbarExports = {
    Progress = qbProgress,
    isDoingSomething = function()
        return Progress:IsActive()
    end,
    ProgressWithStartEvent = qbProgressWithStart,
    ProgressWithTickEvent = qbProgressWithTick,
    ProgressWithStartAndTick = qbProgressWithStartAndTick,
}

for name, func in pairs(progressbarExports) do
    exports(name, func)
    replaceExport('progressbar', name, func)
end

local progressbarEvents = {
    ['progressbar:client:cancel'] = function()
        Progress:Cancel(true, 'progressbar_event')
    end,
    ['progressbar:client:ToggleBusyness'] = function(value)
        -- The original resource exposes this event, but directly assigning
        -- _active can strand props, controls, animations, and inv_busy.
        if value == false and Progress:IsActive() then
            Progress:Cancel(true, 'toggle_busyness')
        elseif value == true and not Progress:IsActive() and Config.devMode then
            warnBridge('Ignored ToggleBusyness(true); no progress task exists to own that state.')
        end
    end,
    ['progressbar:client:progress'] = qbProgress,
    ['progressbar:client:ProgressWithStartEvent'] = qbProgressWithStart,
    ['progressbar:client:ProgressWithTickEvent'] = qbProgressWithTick,
    ['progressbar:client:ProgressWithStartAndTick'] = qbProgressWithStartAndTick,
}

for eventName, handler in pairs(progressbarEvents) do
    RegisterNetEvent(eventName, handler)
end

-- --------------------------------------------------------------------------
-- ox_lib-compatible adapter
-- These exports live on rsblood-progressbar. No ox_lib file replacement is
-- required for resources that call this adapter directly.
-- --------------------------------------------------------------------------

local function oxCancel()
    return Progress:Cancel(false, 'ox_lib')
end

local function normalizeOxProp(prop)
    if type(prop) ~= 'table' then return nil end
    return {
        model = prop.model,
        bone = prop.bone,
        coords = prop.pos or prop.coords,
        rotation = prop.rot or prop.rotation,
        rotOrder = prop.rotOrder,
    }
end

local function oxProgressStart(input)
    if type(input) ~= 'table' then return false end

    local data = {}
    for key, value in pairs(input) do data[key] = value end
    data._oxSemantics = true

    if type(input.anim) == 'string' then
        data.animation = { task = input.anim }
    elseif type(input.anim) == 'table' then
        local anim = input.anim
        data.animation = {
            animDict = anim.dict,
            anim = anim.clip,
            flags = anim.flag,
            duration = anim.duration,
            blendIn = anim.blendIn,
            blendOut = anim.blendOut,
            lockX = anim.lockX,
            lockY = anim.lockY,
            lockZ = anim.lockZ,
            playbackRate = anim.playbackRate,
            task = anim.scenario,
        }
    end

    if type(input.disable) == 'table' then
        data.controlDisables = {
            disableMovement = input.disable.move,
            disableMouse = input.disable.mouse,
            disableSprint = input.disable.sprint,
            disableCarMovement = input.disable.car,
            disableCombat = input.disable.combat,
        }
    end

    if type(input.prop) == 'table' then
        if input.prop.model then
            data.prop = normalizeOxProp(input.prop)
        else
            data.props = {}
            for _, prop in ipairs(input.prop) do
                local normalized = normalizeOxProp(prop)
                if normalized then data.props[#data.props + 1] = normalized end
            end
        end
    end

    if input.position == 'middle' then
        data.position = 'center'
    elseif input.position == 'bottom' then
        data.position = 'center-bottom'
    end

    local deferred = promise.new()
    local started = Progress:Start(data, nil, function(cancelled)
        deferred:resolve(not cancelled)
    end)

    if not started then
        deferred:resolve(false)
    end

    return Citizen.Await(deferred)
end

local function oxProgressActive()
    return Progress:IsActive()
end

local oxExports = {
    ox_lib_cancelProgress = oxCancel,
    ox_lib_progressBar = oxProgressStart,
    ox_lib_progressCircle = oxProgressStart,
    ox_lib_progressActive = oxProgressActive,
    cancelProgress = oxCancel,
    progressBar = oxProgressStart,
    progressCircle = oxProgressStart,
    progressActive = oxProgressActive,
}

for name, func in pairs(oxExports) do
    exports(name, func)
end

-- --------------------------------------------------------------------------
-- esx_progressbar-compatible API
-- Registered unconditionally because the adapter itself has no ESX dependency.
-- --------------------------------------------------------------------------

local function esxCancel()
    return Progress:Cancel(true, 'esx_progressbar')
end

local function esxProgressbar(message, length, options)
    options = type(options) == 'table' and options or {}

    local data = {
        label = message,
        duration = length,
        canCancel = options.canCancel ~= false,
        controlDisables = options.controlDisables,
        onFinish = options.onFinish,
        onCancel = options.onCancel,
    }

    if type(options.animation) == 'table' then
        if options.animation.type == 'anim' then
            data.animation = {
                animDict = options.animation.dict,
                anim = options.animation.lib or options.animation.clip,
                flags = options.animation.flag or options.animation.flags,
            }
        elseif options.animation.type == 'Scenario' or options.animation.type == 'scenario' then
            data.animation = {
                task = options.animation.Scenario or options.animation.scenario,
            }
        end
    end

    local ped = PlayerPedId()
    if options.FreezePlayer then FreezeEntityPosition(ped, true) end

    local started = Progress:Start(data, nil, function(cancelled, minigameResult)
        if options.FreezePlayer then FreezeEntityPosition(ped, false) end
        if type(options.onComplete) == 'function' then
            pcall(options.onComplete, cancelled, minigameResult)
        end
    end)

    if not started then
        if options.FreezePlayer then FreezeEntityPosition(ped, false) end
        if type(options.onCancel) == 'function' then SetTimeout(0, options.onCancel) end
    end

    return started
end

replaceExport('esx_progressbar', 'Progressbar', esxProgressbar)
replaceExport('esx_progressbar', 'CancelProgressbar', esxCancel)
exports('ESXProgressbar', esxProgressbar)
exports('ESXCancelProgressbar', esxCancel)
