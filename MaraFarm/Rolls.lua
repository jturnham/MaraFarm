local _, MaraFarm = ...
local Loot, Source, Tracking = MaraFarm.Loot, MaraFarm.Source, MaraFarm.Tracking
local Rolls = {}
MaraFarm.Rolls = Rolls

local pending, recent, seenHistory = {}, {}, {}
local MATCH_SECONDS = 8
local clearedAt

function Rolls.Clear()
    wipe(pending)
    wipe(recent)
    local time = C_LootHistory and C_LootHistory.GetLootHistoryTime and C_LootHistory.GetLootHistoryTime()
    if not MaraFarm.IsSecret(time) and type(time) == "number" then clearedAt = time end
end

local function Prune(entries, now)
    for i = #entries, 1, -1 do
        if entries[i].expires <= now then table.remove(entries, i) end
    end
end

function Rolls.Start(run, rollID, milliseconds)
    if not run or not GetLootRollItemLink or MaraFarm.IsSecret(rollID) or type(rollID) ~= "number" then return end
    local link = GetLootRollItemLink(rollID)
    local key = Loot.ItemKey(link)
    if not key then return end
    local now = GetTime()
    Prune(pending, now)
    for _, roll in ipairs(pending) do
        if roll.id == rollID then return end
    end
    local quantity = GetLootRollItemInfo and select(3, GetLootRollItemInfo(rollID))
    if MaraFarm.IsSecret(quantity) or type(quantity) ~= "number" or quantity < 1 then quantity = 1 end
    local duration = not MaraFarm.IsSecret(milliseconds) and type(milliseconds) == "number"
        and math.max(0, milliseconds / 1000) or 60
    pending[#pending + 1] = {
        id = rollID, key = key, run = run, visit = run.visits, quantity = quantity,
        boss = Source.Take(run, link, quantity), expires = now + duration + MATCH_SECONDS,
    }
end

local function Record(run, link, quantity, signal, boss)
    local now, key = GetTime(), Loot.ItemKey(link)
    if not key then return end
    Prune(pending, now)
    Prune(recent, now)

    -- One loot award can produce multiple notifications in either order.
    for _, record in ipairs(recent) do
        if record.key == key and not record.signals[signal]
            and (not run or (record.run == run and record.visit == run.visits)) then
            record.signals[signal] = true
            local entry = record.entry
            local changed
            if signal == "receipt" and entry.quantity ~= quantity then
                Loot.SetQuantity(record.run, entry, quantity)
                changed = true
            end
            if boss and not entry.boss then
                entry.boss = boss
                changed = true
            end
            return changed and record.run, true
        end
    end

    local roll
    for i, candidate in ipairs(pending) do
        if candidate.key == key and (signal ~= "receipt" or not run
            or (candidate.run == run and candidate.visit == run.visits)) then
            roll = table.remove(pending, i)
            break
        end
    end
    if roll then
        run = roll.run
        boss = roll.boss or boss
        if signal ~= "receipt" then quantity = roll.quantity end
    end
    if not run then return end
    local entry = Loot.RecordItem(run, link, quantity, boss)
    if not entry then return end
    if roll then entry.visit = roll.visit end
    recent[#recent + 1] = {
        key = key, run = run, visit = entry.visit, entry = entry,
        expires = now + MATCH_SECONDS, signals = { [signal] = true },
    }
    return run, true
end

function Rolls.MoveVisit(previous, run)
    for _, records in ipairs({ pending, recent }) do
        for _, record in ipairs(records) do
            if record.run == previous and record.visit == previous.visits then
                record.run, record.visit = run, run.visits
            end
        end
    end
end

function Rolls.Chat(run, message)
    local link, quantity, signal = Loot.Parse(message)
    if link then
        run = run or Source.RunForLateLoot(link, quantity)
        return Record(run, link, quantity, signal)
    end
end

local function IsNumber(value)
    return not MaraFarm.IsSecret(value) and type(value) == "number"
end

local function HistoryDrop(encounterID, drop)
    if MaraFarm.IsSecret(drop) or type(drop) ~= "table" then return end
    local winner = drop.winner
    if MaraFarm.IsSecret(winner) or type(winner) ~= "table" then return end
    local isSelf = winner.isSelf
    if MaraFarm.IsSecret(isSelf) or isSelf == nil then
        local guid, playerGUID = winner.playerGUID, UnitGUID("player")
        isSelf = not MaraFarm.IsSecret(guid) and not MaraFarm.IsSecret(playerGUID)
            and type(guid) == "string" and guid ~= "" and guid == playerGUID
    end
    if isSelf ~= true then return end
    local key = drop.lootListKey
    if MaraFarm.IsSecret(key) then return end
    key = key or drop.lootListID
    local start = drop.startTime
    if not IsNumber(key) or not IsNumber(start) then return end
    if clearedAt and start < clearedAt then return end

    local id = encounterID .. ":" .. key .. ":" .. start
    if seenHistory[id] then return end

    -- Do not assign an old loot-history entry to a new run just because its event
    -- arrived late. A tracked START_LOOT_ROLL can still link it to the prior run.
    local run = Tracking.active
    local historyNow = C_LootHistory.GetLootHistoryTime()
    if run and (not IsNumber(historyNow) or start > historyNow + 1
        or historyNow - start > GetTime() - Tracking.started + 1) then
        run = nil
    end
    local changed, handled = Record(run, drop.itemHyperlink, 1, "history")
    if handled then seenHistory[id] = true end
    return changed
end

function Rolls.History(encounterID, key)
    if not IsNumber(encounterID) then return end
    if IsNumber(key) then
        return HistoryDrop(encounterID, C_LootHistory.GetSortedInfoForDrop(encounterID, key))
    end
    local drops = C_LootHistory.GetSortedDropsForEncounter(encounterID)
    if MaraFarm.IsSecret(drops) or type(drops) ~= "table" then return end
    local changed
    for _, drop in ipairs(drops) do
        local run = HistoryDrop(encounterID, drop)
        if run and (not changed or changed == Tracking.active) then changed = run end
    end
    return changed
end
