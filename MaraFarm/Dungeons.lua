local _, MaraFarm = ...
local Dungeons = {}
MaraFarm.Dungeons = Dungeons

-- Instance map IDs, shared by the wings and difficulties of a dungeon.
local catalog = {
    [33] = "Shadowfang Keep",
    [34] = "The Stockade",
    [36] = "The Deadmines",
    [43] = "Wailing Caverns",
    [47] = "Razorfen Kraul",
    [48] = "Blackfathom Deeps",
    [70] = "Uldaman",
    [90] = "Gnomeregan",
    [109] = "Sunken Temple",
    [129] = "Razorfen Downs",
    [189] = "Scarlet Monastery",
    [209] = "Zul'Farrak",
    [229] = "Blackrock Spire",
    [230] = "Blackrock Depths",
    [289] = "Scholomance",
    [329] = "Stratholme",
    [349] = "Maraudon",
    [389] = "Ragefire Chasm",
    [429] = "Dire Maul",
    [2959] = "City of Dalaran",
    [2970] = "The Drowned City",
    [2974] = "Blackmaw Hold",
    [2994] = "Alcaz Prison",
    [2998] = "Excavation Site: Wetlands",
    [2999] = "Ruins of Lordaeron",
    [3001] = "Shaper's Terrace",
    [3039] = "Krol'dok Stronghold",
    [3065] = "Hall of Thanes",
    [3109] = "Manor Mistmantle",
}

function Dungeons.MapID(run)
    return tonumber(run.key:match("^(%d+):"))
end

function Dungeons.Remember(run)
    local id = Dungeons.MapID(run)
    local seen = Dungeons.settings.known
    if id and seen[id] ~= run.name then
        seen[id] = run.name
        return true
    end
end

function Dungeons.Initialize(settings, runs)
    settings.dungeons = settings.dungeons or { default = true, overrides = {}, known = {} }
    Dungeons.settings = settings.dungeons
    for _, run in ipairs(runs) do Dungeons.Remember(run) end
end

function Dungeons.IsEnabled(id)
    local value = Dungeons.settings.overrides[id]
    if value ~= nil then return value end
    return Dungeons.settings.default
end

function Dungeons.SetEnabled(id, enabled)
    local settings = Dungeons.settings
    if enabled == settings.default then
        settings.overrides[id] = nil
    else
        settings.overrides[id] = enabled
    end
end

function Dungeons.SetAll(enabled)
    Dungeons.settings.default = enabled
    wipe(Dungeons.settings.overrides)
end

function Dungeons.List()
    local entries = {}
    local known = Dungeons.settings.known
    for id, fallback in pairs(catalog) do
        local name = known[id] or (GetRealZoneText and GetRealZoneText(id))
        if MaraFarm.IsSecret(name) or type(name) ~= "string" or name == "" or name == UNKNOWN then
            name = fallback
        end
        entries[#entries + 1] = { id = id, name = name }
    end
    for id, name in pairs(known) do
        if not catalog[id] then entries[#entries + 1] = { id = id, name = name } end
    end
    table.sort(entries, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return entries
end
