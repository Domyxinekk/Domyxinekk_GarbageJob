ESX = exports["es_extended"]:getSharedObject()

local WEBHOOK_URL = "Tvůj Webhook"
local misuseCounter = {}
local MAX_ATTEMPTS = 1 

local function sendLog(title, desc, color)
    local embed = {{
        color = color or 3447003,
        title = title,
        description = desc,
        footer = { text = "Popelář Job | Log" }
    }}
    PerformHttpRequest(WEBHOOK_URL, function() end, "POST", json.encode({
        username = "Garbage Job",
        embeds = embed
    }), { ["Content-Type"] = "application/json" })
end

RegisterNetEvent("domyxinekk_garbage:finishShift", function(stops, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not misuseCounter[src] then misuseCounter[src] = 0 end

    if misuseCounter[src] >= MAX_ATTEMPTS then
        local playerName = GetPlayerName(src) or "Neznámý"
        sendLog(
            "Kick za zneužití triggeru",
            ("Hráč **%s** (ID: %d) byl vykopnut za opakované spouštění `domyxinekk_garbage:finishShift`."):format(playerName, src),
            16711680
        )
        DropPlayer(src, "Dostal si kick za trigger debílku.")
        return
    end

    if amount and amount > 0 then
        xPlayer.addMoney(amount)

        local msg = ("Hráč **%s** (ID: %d) dostal odměnu: **$%s** za %d zastávek."):format(
            xPlayer.getName(), src, amount, stops or 0
        )
        print("Popelář Job " .. msg)
        sendLog("Výplata popeláře", msg, 3066993)
    end

    misuseCounter[src] = misuseCounter[src] + 1
end)

AddEventHandler("playerDropped", function()
    local src = source
    misuseCounter[src] = nil
end)
