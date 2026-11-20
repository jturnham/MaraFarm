local _, MaraFarm = ...
local Source = {}
MaraFarm.Source = Source

local maraudon = {
    [12201] = "Princess Theradras",
    [12203] = "Landslide",
    [12225] = "Celebras the Cursed",
    [12236] = "Lord Vyletongue",
    [12237] = "Meshlok the Harvester",
    [12258] = "Razorlash",
    [13282] = "Noxxion",
    [13596] = "Rotgrip",
    [13601] = "Tinkerer Gizlock",
}
local units = { "target", "mouseover", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }
local snapshot

function Source.RecordBoss(run, name)
    if not run or MaraFarm.IsSecret(name) or type(name) ~= "string" or name == "" then return end
    run.bosses = run.bosses or {}
    if run.visit then
        local visit = run.visit
        visit.bosses = visit.bosses or {}
        if visit.bosses[name] == nil then visit.bosses[name] = run.bosses[name] == nil end
    end
    if run.bosses[name] then return end
    run.bosses[name] = true
    return true
end

function Source.MoveVisit(previous, run)
    if snapshot and snapshot.run == previous then snapshot.run = run end
    for name, added in pairs(run.visit.bosses or {}) do
        if added then previous.bosses[name] = nil end
        run.bosses = run.bosses or {}
        run.bosses[name] = true
    end
end

local function BossName(run, ok, guid, _, extraGUID)
    if not ok or MaraFarm.IsSecret(guid) or type(guid) ~= "string"
        or MaraFarm.IsSecret(extraGUID) or extraGUID ~= nil then return end

    local npc = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npc then return end
    local fallback = run.key:match("^349:") and maraudon[npc]
    for index, unit in ipairs(units) do
        local unitGUID = UnitGUID(unit)
        if not MaraFarm.IsSecret(unitGUID) and unitGUID == guid then
            local name = UnitName(unit)
            if not MaraFarm.IsSecret(name) and type(name) == "string"
                and (fallback or index >= 4 or (run.bosses and run.bosses[name])) then
                return name
            end
        end
    end
    return fallback or nil
end

local function ItemKey(link)
    if not MaraFarm.IsSecret(link) and type(link) == "string" then
        return link:match("|H(item:[^|]+)|h")
    end
end

function Source.Capture(run)
    if not run or not GetLootSourceInfo then return end
    if snapshot and snapshot.run == run and not snapshot.closed then return end
    local count = GetNumLootItems()
    if MaraFarm.IsSecret(count) or type(count) ~= "number" or count < 1 then return end

    snapshot = { run = run, items = {} }
    local changed = false
    for slot = 1, count do
        local key = ItemKey(GetLootSlotLink(slot))
        if key then
            local _, _, quantity = GetLootSlotInfo(slot)
            local boss = BossName(run, pcall(GetLootSourceInfo, slot))
            if Source.RecordBoss(run, boss) then changed = true end
            local candidate = snapshot.items[key]
            if candidate then
                -- Identical links from different or unreadable sources are ambiguous.
                if not boss or candidate.boss ~= boss then candidate.boss = nil end
            else
                candidate = { boss = boss, quantity = 0 }
                snapshot.items[key] = candidate
            end
            if not MaraFarm.IsSecret(quantity) and type(quantity) == "number" then
                candidate.quantity = candidate.quantity + quantity
            else
                candidate.boss = nil
            end
        end
    end
    return changed
end

function Source.Close()
    if snapshot and not snapshot.closed then snapshot.closed = GetTime() end
end

function Source.Clear()
    snapshot = nil
end

function Source.RunForLateLoot(link, quantity)
    if not snapshot or not snapshot.closed or GetTime() - snapshot.closed > 1 then return end
    local candidate = snapshot.items[ItemKey(link)]
    if candidate and candidate.boss and candidate.quantity >= quantity then return snapshot.run end
end

function Source.Take(run, link, quantity)
    if not snapshot or snapshot.run ~= run
        or (snapshot.closed and GetTime() - snapshot.closed > 1) then return end
    local candidate = snapshot.items[ItemKey(link)]
    if not candidate or candidate.quantity < quantity then return end
    candidate.quantity = candidate.quantity - quantity
    return candidate.boss
end

function Source.Groups(run)
    local groups, byName = {}, {}
    for name in pairs(run.bosses or {}) do
        local group = { name = name, loot = {} }
        byName[name] = group
        groups[#groups + 1] = group
    end
    table.sort(groups, function(a, b) return a.name < b.name end)

    local other = { name = "Other / unknown source", loot = {}, other = true }
    for _, entry in ipairs(run.loot) do
        local group = byName[entry.boss] or other
        group.loot[#group.loot + 1] = entry
    end
    if #other.loot > 0 then groups[#groups + 1] = other end
    return groups
end
