local _, MaraFarm = ...
local Nova = {}
MaraFarm.Nova = Nova

local NAME = "NovaInstanceTracker"
local SUPPORTED_VERSION = "2.32"
local nextRead, cachedCount, cachedScope = 0, nil, nil
local cachedExpiry

local function Addon()
    if not C_AddOns or not C_AddOns.IsAddOnLoaded(NAME) or type(NIT) ~= "table" then return end
    if C_AddOns.GetAddOnMetadata(NAME, "Version") == SUPPORTED_VERSION then return NIT end
end

function Nova.Hourly(now)
    if now < nextRead then return cachedCount, cachedScope, cachedExpiry end
    nextRead = now + 5
    cachedCount, cachedScope, cachedExpiry = nil, nil, nil
    local addon = Addon()
    if not addon or type(addon.getInstanceLockoutInfo) ~= "function" then return end
    local ok, count, _, anchor = pcall(addon.getInstanceLockoutInfo, addon)
    if ok and not MaraFarm.IsSecret(count) and type(count) == "number"
        and count >= 0 and count % 1 == 0 then
        cachedCount = count
        cachedScope = addon.perCharOnly and "character" or "Nova scope"
        if count >= 10 and not MaraFarm.IsSecret(anchor) and type(anchor) == "number"
            and anchor > now - 3600 and anchor <= now then
            cachedExpiry = anchor + 3600
        end
    end
    return cachedCount, cachedScope, cachedExpiry
end

function Nova.CanOpen()
    return C_AddOns and C_AddOns.IsAddOnLoaded(NAME) and type(SlashCmdList.NITCMD) == "function"
end

function Nova.Open()
    if Nova.CanOpen() then SlashCmdList.NITCMD("") end
end
