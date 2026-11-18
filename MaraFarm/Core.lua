local addonName, MaraFarm = ...
local Tracking, Loot, UI = MaraFarm.Tracking, MaraFarm.Loot, MaraFarm.UI
local events = CreateFrame("Frame")
local characterKey, resetPattern, resetFields
local zoneRevision = 0

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

    Tracking.Observe(instance, GetServerTime(), GetTime())
    UI.Refresh()
end

local function UpdateWorld()
    zoneRevision = zoneRevision + 1
    ObserveWorld(zoneRevision, 5)
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("CHAT_MSG_LOOT")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" and not characterKey then
        local name, realm = UnitFullName("player")
        if MaraFarm.IsSecret(name) or MaraFarm.IsSecret(realm) or not name then return end
        characterKey = (realm and realm ~= "" and realm or GetNormalizedRealmName()) .. ":" .. name
        MaraFarmDB = Tracking.Initialize(MaraFarmDB, characterKey)
        Loot.Initialize()
        resetPattern, resetFields = MaraFarm.MessagePattern(INSTANCE_RESET_SUCCESS)
    end
    if not characterKey then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateWorld()
    elseif event == "PLAYER_LOGOUT" then
        zoneRevision = zoneRevision + 1
        Tracking.Leave(GetServerTime(), GetTime())
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        if resetPattern and not MaraFarm.IsSecret(message) and type(message) == "string" then
            local captures = { message:match(resetPattern) }
            local dungeon = captures[resetFields[1]]
            if dungeon then Tracking.Reset(dungeon) end
        end
    elseif event == "CHAT_MSG_LOOT" then
        local message, _, _, _, _, _, _, _, _, _, _, senderGUID = ...
        Loot.Record(Tracking.active, message, senderGUID, UnitGUID("player"))
        UI.Refresh()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local itemID = ...
        if not MaraFarm.IsSecret(itemID) and type(itemID) == "number" then
            Loot.ItemReady(itemID)
            UI.Refresh()
        end
    end
end)

SLASH_MARAFARM1 = "/mf"
SlashCmdList.MARAFARM = function()
    if characterKey then UI.Toggle() end
end
