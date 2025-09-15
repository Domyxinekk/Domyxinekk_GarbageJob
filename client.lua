ESX = exports['es_extended']:getSharedObject()

local onJob = false
local currentVehicle = nil
local currentBin = nil
local binsDone = 0
local carryingBag = false
local bagObj = nil

local binBlip = nil
local deliverZone = nil

local COOLDOWN_MS = 5 * 60 * 1000
local cooldownEnd = 0

local function getCooldownRemainingSeconds()
    local rem = cooldownEnd - GetGameTimer()
    if rem > 0 then
        return math.ceil(rem / 1000)
    end
    return 0
end

local function isOnCooldown()
    return getCooldownRemainingSeconds() > 0
end

local function AttachBag()
    lib.requestModel(`prop_cs_rub_binbag_01`, 5000)
    bagObj = CreateObject(`prop_cs_rub_binbag_01`, 0, 0, 0, true, true, true)
    AttachEntityToEntity(bagObj, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005),
        0.25, 0.0, 0.0, 0.0, 270.0, 180.0,
        true, true, false, true, 1, true)

    RequestAnimDict("anim@heists@narcotics@trash")
    while not HasAnimDictLoaded("anim@heists@narcotics@trash") do Wait(10) end
    TaskPlayAnim(PlayerPedId(), "anim@heists@narcotics@trash", "walk", 8.0, -8, -1, 49, 0, false, false, false)
end

local function RemoveBag()
    if bagObj then DeleteEntity(bagObj) bagObj = nil end
    ClearPedTasks(PlayerPedId())
end

local function TakeBagFromBin(binZone)
    if carryingBag then
        lib.notify({title='Popeláři', description='Už neseš pytel!', type='error'})
        return
    end

    RequestAnimDict("anim@heists@narcotics@trash")
    while not HasAnimDictLoaded("anim@heists@narcotics@trash") do Wait(10) end
    TaskPlayAnim(PlayerPedId(), "anim@heists@narcotics@trash", "pickup", 8.0, -8, -1, 49, 0, false, false, false)

    if lib.progressBar({
        duration = 2500,
        label = 'Sbířáš pytel z popelnice...',
        useWhileDead=false,
        canCancel=false,
        disable={car=true, move=true}
    }) then
        ClearPedTasks(PlayerPedId())
        carryingBag = true
        AttachBag()
        exports.ox_target:removeZone(binZone)
        lib.notify({title='Popeláři', description='Vlož pytel do vozidla', type='inform'})

        exports.ox_target:addLocalEntity(currentVehicle,{
            {
                name='drop_bag',
                icon='fa-solid fa-trash',
                label='Vlož pytel do auta',
                canInteract=function() return carryingBag and onJob end,
                onSelect=function()
                    RequestAnimDict("anim@heists@narcotics@trash")
                    while not HasAnimDictLoaded("anim@heists@narcotics@trash") do Wait(10) end
                    TaskPlayAnim(PlayerPedId(), "anim@heists@narcotics@trash", "throw_a", 8.0, -8, -1, 49, 0, false, false, false)
                    Wait(2000) 

                    carryingBag = false
                    binsDone = binsDone + 1
                    RemoveBag()
                    if binBlip then RemoveBlip(binBlip) binBlip=nil end
                    lib.notify({title='Popeláři', description=('Vysypal si pytel. (%s/%s)'):format(binsDone, Config.TotalStops), type='success'})
                    NextBin()
                end
            }
        })
    else
        ClearPedTasks(PlayerPedId())
    end
end

function NextBin()
    if binsDone >= Config.TotalStops then							
        lib.notify({title='Popeláři', description='Všechny pytle posbíráné, Vrať se prosím zpátky.', type='success'})
        return
    end

    currentBin = Config.Bins[math.random(1,#Config.Bins)]

    if binBlip then RemoveBlip(binBlip) end
    binBlip = AddBlipForCoord(currentBin.x,currentBin.y,currentBin.z)
    SetBlipSprite(binBlip,318)
    SetBlipColour(binBlip,2)
    SetBlipScale(binBlip,0.9)
    SetBlipRoute(binBlip,true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Popelnice')
    EndTextCommandSetBlipName(binBlip)

    if deliverZone then exports.ox_target:removeZone(deliverZone) deliverZone=nil end
    deliverZone = exports.ox_target:addSphereZone({
        coords = currentBin,
        radius = 1.8,
        options = { {
            name='take_trash',
            icon='fa-solid fa-trash',
            label='Seber pytel',
            onSelect=function()
                TakeBagFromBin(deliverZone)
            end
        } }
    })

    lib.notify({title='Popeláři', description=('Zbývá %s/%s pytlů.'):format(binsDone, Config.TotalStops), type='inform'})
end

function StartJob()
    if isOnCooldown() then
        local s = getCooldownRemainingSeconds()
        lib.notify({title='Popeláři', description=('Musíš počkat %s sekund než můžeš začít další směnu.'):format(s), type='error'})
        return
    end

    onJob = true
    binsDone = 0

    DoScreenFadeOut(800)
    Wait(1500)

    lib.progressBar({
        duration=3000,
        label='Vytahuješ si z garáže vozidlo...',
        useWhileDead=false,
        canCancel=false,
        disable={car=true, move=true}
    })

    local spawn = Config.TruckSpawn
    lib.requestModel(Config.Vehicle,5000)
    currentVehicle = CreateVehicle(Config.Vehicle, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetVehicleNumberPlateText(currentVehicle,'TRASH'..math.random(100,999))
    SetEntityAsMissionEntity(currentVehicle,true,true)

    TaskWarpPedIntoVehicle(PlayerPedId(), currentVehicle, -1)

    DoScreenFadeIn(800)
    NextBin()
end

function EndJob()
    if DoesEntityExist(currentVehicle) then DeleteVehicle(currentVehicle) end
    if binBlip then RemoveBlip(binBlip) binBlip=nil end

    local reward = math.random(Config.PaymentMin, Config.PaymentMax)
    TriggerServerEvent('domyxinekk_garbage:finishShift', binsDone, reward)

    lib.notify({title='Popeláři', description=('Dostal jsi: $%s peněz'):format(reward), type='success'})

    onJob=false
    binsDone=0
    currentVehicle=nil
    currentBin=nil
    carryingBag=false
    RemoveBag()

    cooldownEnd = GetGameTimer() + COOLDOWN_MS
    local sec = getCooldownRemainingSeconds()
    lib.notify({title='Popeláři', description=('Další směnu můžeš zahájit za %s sekund'):format(sec), type='inform'})
end

function OpenMainMenu()
    local options = {}

    if not onJob then
        if isOnCooldown() then
            local s = getCooldownRemainingSeconds()
            table.insert(options, {
                title='Na brigádu nemůžeš',
                description=('Počkej ještě %s sekund'):format(s),
                icon='fa-solid fa-clock'
            })
        else
            table.insert(options,{title='Začít brigádu', icon='fa-solid fa-truck-fast', onSelect=StartJob})
        end
    else
        if binsDone >= Config.TotalStops then
            table.insert(options,{title='Ukončit brigádu', icon='fa-solid fa-truck-fast', onSelect=EndJob})
        else
            table.insert(options,{title='Brigáda probíhá', description='Dokonči nejdřív všechny pytle.', icon='fa-solid fa-truck'})
        end
    end

    lib.registerContext({id='garbage_menu', title='Brigáda Popeláře', options=options})
    lib.showContext('garbage_menu')
end

CreateThread(function()
    local npc = Config.NPC
    lib.requestModel(npc.model,5000)
    local ped = CreatePed(0,npc.model,npc.coords.x,npc.coords.y,npc.coords.z-1,npc.coords.w,false,true)

    SetEntityInvincible(ped,true)
    FreezeEntityPosition(ped,true)
    SetEntityAsMissionEntity(ped,true,true)
    TaskStartScenarioInPlace(ped,'WORLD_HUMAN_CLIPBOARD',0,true)

    exports.ox_target:addLocalEntity(ped,{{
        name='garbage_menu_open',
        icon='fa-solid fa-recycle',
        label='Popelářská směna',
        onSelect=OpenMainMenu
    }})

    local npcBlip = AddBlipForCoord(npc.coords.x,npc.coords.y,npc.coords.z)
    SetBlipSprite(npcBlip,318)
    SetBlipScale(npcBlip,0.8)
    SetBlipColour(npcBlip,2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Brigáda Popeláře')
    EndTextCommandSetBlipName(npcBlip)
end)
