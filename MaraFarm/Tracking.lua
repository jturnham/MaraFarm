local _, MaraFarm = ...
local Tracking = {}
MaraFarm.Tracking = Tracking

local function Anchor(run)
    return run.suspendedAt or run.lastExit or run.entered
end

function Tracking.Initialize(db, characterKey)
    db = db or { version = 1, characters = {} }
    local character = db.characters[characterKey]
    if not character then
        character = { runs = {}, copies = {} }
        db.characters[characterKey] = character
    end
    if not character.session then
        character.session = 1
        for _, run in ipairs(character.runs) do run.session = 1 end
    end
    db.overlay = db.overlay or { enabled = true, vendor = true, lockout = true }
    if db.overlay.gph == nil then db.overlay.gph = true end
    db.minimap = db.minimap or { enabled = true, angle = 225 }
    Tracking.character = character
    Tracking.active = nil
    Tracking.started = nil
    Tracking.recent = {}
    local cutoff = GetServerTime() - 3600
    for _, run in ipairs(character.runs) do
        if Anchor(run) > cutoff then Tracking.recent[run] = true end
    end
    return db
end

function Tracking.Duration(run, tick)
    if run == Tracking.active then
        return run.seconds + math.max(0, tick - Tracking.started)
    end
    return run.seconds
end

function Tracking.Leave(now, tick, suspend)
    local run = Tracking.active
    if not run then return end
    run.seconds = Tracking.Duration(run, tick)
    if suspend then
        run.suspendedAt = now
        Tracking.character.suspended = run.key
    else
        run.lastExit = now
        run.suspendedAt = nil
    end
    Tracking.active = nil
    Tracking.started = nil
end

function Tracking.Observe(instance, now, tick, initial, reload)
    local active = Tracking.active
    if active and instance and active.key == instance.key then return end
    Tracking.Leave(now, tick)
    local character = Tracking.character
    local suspendedKey = character.suspended
    if suspendedKey then
        local suspendedRun = character.runs[character.copies[suspendedKey]]
        if suspendedRun and not (reload and instance and instance.key == suspendedKey) then
            suspendedRun.partial = true
        end
        character.suspended = nil
    end
    if not instance then return end

    local run = character.runs[character.copies[instance.key]]
    if not run then
        run = {
            key = instance.key,
            name = instance.name,
            entered = now,
            session = character.session,
            seconds = 0,
            visits = 0,
            loot = {},
            coin = 0,
            partial = initial or nil,
        }
        local index = #character.runs + 1
        character.runs[index] = run
        character.copies[instance.key] = index
    end
    if not (reload and suspendedKey == instance.key) then
        run.visits = run.visits + 1
        if initial then run.partial = true end
    end
    run.suspendedAt = nil
    Tracking.recent[run] = true
    Tracking.active = run
    Tracking.started = tick
end

function Tracking.NewSession()
    local character = Tracking.character
    character.session = character.session + 1
end

function Tracking.Reset(name)
    for key, index in pairs(Tracking.character.copies) do
        local run = Tracking.character.runs[index]
        if run ~= Tracking.active and run.name == name then
            Tracking.character.copies[key] = nil
        end
    end
end

function Tracking.Hourly(now, slots)
    local count, nextRelease = 0, nil
    for run in pairs(Tracking.recent) do
        if run == Tracking.active then
            count = count + 1
            if slots then slots[#slots + 1] = { run = run, anchor = Anchor(run), active = true } end
        else
            local anchor = Anchor(run)
            local expires = anchor + 3600
            if expires > now then
                count = count + 1
                nextRelease = math.min(nextRelease or expires, expires)
                if slots then slots[#slots + 1] = { run = run, anchor = anchor, expires = expires } end
            else
                Tracking.recent[run] = nil
            end
        end
    end
    return count, nextRelease
end

function Tracking.IsMaraudon(run)
    return run.key:match("^349:") ~= nil
end
