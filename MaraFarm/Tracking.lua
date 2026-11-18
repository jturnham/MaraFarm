local _, MaraFarm = ...
local Tracking = {}
MaraFarm.Tracking = Tracking

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
    Tracking.character = character
    Tracking.active = nil
    Tracking.started = nil
    return db
end

function Tracking.Duration(run, tick)
    if run == Tracking.active then
        return run.seconds + math.max(0, tick - Tracking.started)
    end
    return run.seconds
end

function Tracking.Leave(now, tick)
    local run = Tracking.active
    if not run then return end
    run.seconds = Tracking.Duration(run, tick)
    run.lastExit = now
    Tracking.active = nil
    Tracking.started = nil
end

function Tracking.Observe(instance, now, tick)
    local active = Tracking.active
    if active and instance and active.key == instance.key then return end
    Tracking.Leave(now, tick)
    if not instance then return end

    local character = Tracking.character
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
        }
        local index = #character.runs + 1
        character.runs[index] = run
        character.copies[instance.key] = index
    end
    run.visits = run.visits + 1
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

function Tracking.Hourly(now)
    local count, nextRelease = 0, nil
    for _, run in ipairs(Tracking.character.runs) do
        if run == Tracking.active then
            count = count + 1
        else
            local expires = (run.lastExit or run.entered) + 3600
            if expires > now then
                count = count + 1
                nextRelease = math.min(nextRelease or expires, expires)
            end
        end
    end
    return count, nextRelease
end
