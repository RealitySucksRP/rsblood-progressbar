local MAX_PROPS_PER_PLAYER <const> = 5
local ENTITY_WAIT_MS <const> = 1500
local EVENT_WINDOW_MS <const> = 1000
local MAX_EVENTS_PER_WINDOW <const> = 12

local playerProps = {}
local recentlyReleased = {}
local eventRate = {}

local blacklistedProps = {
    [`prop_beach_fire`] = true,
}

local function log(message)
    print(('[rsblood-progressbar] %s'):format(message))
end

local function ensurePlayerTables(src)
    playerProps[src] = playerProps[src] or {}
    recentlyReleased[src] = recentlyReleased[src] or {}
end

local function allowEvent(src)
    local now = GetGameTimer()
    local rate = eventRate[src]

    if not rate or now - rate.windowStart >= EVENT_WINDOW_MS then
        eventRate[src] = { windowStart = now, count = 1, warned = false }
        return true
    end

    rate.count = rate.count + 1
    if rate.count <= MAX_EVENTS_PER_WINDOW then return true end

    if not rate.warned then
        rate.warned = true
        log(('Rate-limited prop events from player %s.'):format(src))
    end
    return false
end

local function markReleased(src, netId)
    ensurePlayerTables(src)
    recentlyReleased[src][netId] = true
    SetTimeout(5000, function()
        if recentlyReleased[src] then recentlyReleased[src][netId] = nil end
    end)
end

local function waitForEntity(netId)
    local startedAt = GetGameTimer()
    local entity = NetworkGetEntityFromNetworkId(netId)

    while (entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() - startedAt < ENTITY_WAIT_MS do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end

    if entity == 0 or not DoesEntityExist(entity) then return 0 end
    return entity
end

local function entityOwnedBy(entity, src)
    if type(NetworkGetEntityOwner) ~= 'function' then return true end
    local owner = NetworkGetEntityOwner(entity)
    return owner == src
end

local function isObjectEntity(entity)
    if type(GetEntityType) ~= 'function' then return true end
    return GetEntityType(entity) == 3
end

local function deleteTrackedEntity(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function registerProps(src, netIds, models)
    if not allowEvent(src) then return end
    if type(netIds) ~= 'table' or type(models) ~= 'table' then return end
    if #netIds == 0 or #netIds ~= #models or #netIds > MAX_PROPS_PER_PLAYER then
        log(('Rejected malformed prop registration from player %s.'):format(src))
        return
    end

    ensurePlayerTables(src)

    CreateThread(function()
        for index = 1, #netIds do
            if not GetPlayerName(src) then return end

            local netId = tonumber(netIds[index]) or 0
            local claimedModel = tonumber(models[index]) or 0
            if netId == 0 or claimedModel == 0 then
                log(('Rejected invalid prop data from player %s.'):format(src))
                goto continue
            end

            if recentlyReleased[src] and recentlyReleased[src][netId] then goto continue end

            local entity = waitForEntity(netId)
            if entity == 0 then
                log(('Could not resolve prop net ID %s from player %s.'):format(netId, src))
                goto continue
            end

            local actualModel = GetEntityModel(entity)
            local valid = isObjectEntity(entity)
                and entityOwnedBy(entity, src)
                and actualModel == claimedModel
                and not blacklistedProps[actualModel]

            if not valid then
                log(('Rejected prop from player %s (netId=%s, claimed=%s, actual=%s).'):format(
                    src,
                    netId,
                    claimedModel,
                    actualModel
                ))
                if entityOwnedBy(entity, src) then DeleteEntity(entity) end
                goto continue
            end

            local trackedCount = 0
            for _ in pairs(playerProps[src]) do trackedCount = trackedCount + 1 end
            if trackedCount >= MAX_PROPS_PER_PLAYER then
                DeleteEntity(entity)
                log(('Player %s exceeded the prop limit.'):format(src))
                goto continue
            end

            if not GetPlayerName(src) then
                DeleteEntity(entity)
                return
            end
            ensurePlayerTables(src)
            playerProps[src][netId] = true

            ::continue::
        end
    end)
end

local function cleanupProps(src, netIds)
    if not allowEvent(src) then return end
    if type(netIds) ~= 'table' or #netIds > MAX_PROPS_PER_PLAYER then return end
    ensurePlayerTables(src)

    for _, rawNetId in ipairs(netIds) do
        local netId = tonumber(rawNetId) or 0
        if netId ~= 0 then
            markReleased(src, netId)
            if playerProps[src][netId] then
                deleteTrackedEntity(netId)
                playerProps[src][netId] = nil
            end
        end
    end
end

RegisterNetEvent('rsblood-progressbar:server:register_props', function(netIds, models)
    registerProps(source, netIds, models)
end)

RegisterNetEvent('rsblood-progressbar:server:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

-- Legacy keep-progressbar event names remain accepted for older integrations.
RegisterNetEvent('keep-progressbar:server:register_props', function(netIds, models)
    registerProps(source, netIds, models)
end)

RegisterNetEvent('keep-progressbar:server:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

RegisterNetEvent('keep-progressbar:serer:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playerProps[src] then
        for netId in pairs(playerProps[src]) do deleteTrackedEntity(netId) end
    end
    playerProps[src] = nil
    recentlyReleased[src] = nil
    eventRate[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, props in pairs(playerProps) do
        for netId in pairs(props) do deleteTrackedEntity(netId) end
    end
end)

local function actualResourceExists(name)
    for index = 0, GetNumResources() - 1 do
        if GetResourceByFindIndex(index) == name then return true end
    end
    return false
end

CreateThread(function()
    Wait(0)
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'
    log(('v%s ready: native, progressbar/QBCore/Qbox, ox adapter, ESX adapter, and standalone APIs loaded.'):format(version))

    for _, conflictingName in ipairs({ 'progressbar', 'esx_progressbar' }) do
        if actualResourceExists(conflictingName) then
            local state = GetResourceState(conflictingName)
            if state == 'started' or state == 'starting' then
                log(('WARNING: resource "%s" is also running. Stop it or remove the matching provide line to avoid duplicate providers.'):format(conflictingName))
            end
        end
    end
end)
