local addonName, MaraFarm = ...
local Tracking, Loot, UI = MaraFarm.Tracking, MaraFarm.Loot, MaraFarm.UI
local Overlay = MaraFarm.Overlay
local Source, Coin = MaraFarm.Source, MaraFarm.Coin
local events = CreateFrame("Frame")
local characterKey, resetPattern, resetFields
local initialWorld, reloading
local zoneRevision = 0
local refreshQueued = false
local chartRefreshQueued = false

local function QueueRefresh(refreshCharts)
    chartRefreshQueued = chartRefreshQueued or refreshCharts
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        UI.Refresh()
        Overlay.Refresh()
        MaraFarm.Dashboard.Refresh()
        if chartRefreshQueued then
            chartRefreshQueued = false
            MaraFarm.Charts.Refresh()
        end
    end)
end

local function ObserveWorld(revision, retries)
    if revision ~= zoneRevision then return end

    local inside, instanceType = IsInInstance()
    if MaraFarm.IsSecret(inside) or MaraFarm.IsSecret(instanceType) then return end
    local instance
    if inside and instanceType == "party" then
        local name, _, difficulty, _, _, _, _, mapID = GetInstanceInfo()
        if MaraFarm.IsSecret(name) or MaraFarm.IsSecret(difficulty) or MaraFarm.IsSecret(mapID) then
            return
        end
        if type(name) ~= "string" or name == "" or type(mapID) ~= "number" or mapID <= 0
            or type(difficulty) ~= "number" then
            if retries > 0 then
                C_Timer.After(0.2, function() ObserveWorld(revision, retries - 1) end)
            end
            return
        end
        instance = { key = mapID .. ":" .. difficulty, name = name }
    end

    local previous = Tracking.active
    Tracking.Observe(instance, GetServerTime(), GetTime(), initialWorld, reloading)
    initialWorld, reloading = nil, nil
    if Tracking.active ~= previous then
        if Tracking.active then Source.Clear() else Source.Close() end
        QueueRefresh(true)
    end
end

local function UpdateWorld()
    zoneRevision = zoneRevision + 1
    ObserveWorld(zoneRevision, 5)
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:RegisterEvent("CHAT_MSG_LOOT")
events:RegisterEvent("CHAT_MSG_MONEY")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("BOSS_KILL")
events:RegisterEvent("ENCOUNTER_END")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" and not characterKey then
        local name, realm = UnitFullName("player")
        if MaraFarm.IsSecret(name) or MaraFarm.IsSecret(realm) or not name then return end
        characterKey = (realm and realm ~= "" and realm or GetNormalizedRealmName()) .. ":" .. name
        MaraFarmDB = Tracking.Initialize(MaraFarmDB, characterKey)
        Overlay.settings = MaraFarmDB.overlay
        MaraFarm.MapButton.settings = MaraFarmDB.minimap
        MaraFarm.MapButton.Refresh()
        Loot.Initialize()
        Coin.Initialize()
        resetPattern, resetFields = MaraFarm.MessagePattern(INSTANCE_RESET_SUCCESS)
        local _, reload = ...
        initialWorld, reloading = true, not MaraFarm.IsSecret(reload) and reload == true
    end
    if not characterKey then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateWorld()
    elseif event == "PLAYER_LOGOUT" then
        zoneRevision = zoneRevision + 1
        Tracking.Leave(GetServerTime(), GetTime(), true)
    elseif event == "CHAT_MSG_SYSTEM" or event == "UI_ERROR_MESSAGE" then
        local message, errorText = ...
        if event == "UI_ERROR_MESSAGE" then message = errorText end
        if not MaraFarm.IsSecret(message) and type(message) == "string"
            and (message == ERR_INSTANCE_LIMIT or message == ERR_TOO_MANY_INSTANCES) then
            Tracking.serverWarningUntil = GetServerTime() + 3600
            QueueRefresh()
        end
        if event == "CHAT_MSG_SYSTEM" and resetPattern
            and not MaraFarm.IsSecret(message) and type(message) == "string" then
            local captures = { message:match(resetPattern) }
            local dungeon = captures[resetFields[1]]
            if dungeon then Tracking.Reset(dungeon) end
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        if Source.Capture(Tracking.active) then QueueRefresh() end
    elseif event == "LOOT_CLOSED" then
        Source.Close()
    elseif event == "BOSS_KILL" or event == "ENCOUNTER_END" then
        local _, bossName, _, _, success = ...
        if event == "BOSS_KILL" or (not MaraFarm.IsSecret(success) and success == 1) then
            if Source.RecordBoss(Tracking.active, bossName) then QueueRefresh() end
        end
    elseif event == "CHAT_MSG_LOOT" then
        local message, _, _, _, _, _, _, _, _, _, _, senderGUID = ...
        if Loot.Record(Tracking.active, message, senderGUID, UnitGUID("player")) then QueueRefresh() end
    elseif event == "CHAT_MSG_MONEY" then
        if Coin.Record(Tracking.active, ...) then QueueRefresh() end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local itemID = ...
        if not MaraFarm.IsSecret(itemID) and type(itemID) == "number" and Loot.ItemReady(itemID) then
            QueueRefresh(true)
        end
    end
end)

SLASH_MARAFARM1 = "/mf"
SlashCmdList.MARAFARM = function(message)
    if not characterKey then return end
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "options" then
        Overlay.ToggleOptions()
    elseif command == "summary" or command == "lockouts" then
        MaraFarm.Dashboard.Toggle(command)
    elseif command == "charts" then
        MaraFarm.Charts.Toggle()
    else
        UI.Toggle()
    end
end
