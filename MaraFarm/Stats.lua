local _, MaraFarm = ...
local Stats = {}
MaraFarm.Stats = Stats

function Stats.Session(character, session, maraudonOnly, active)
    local result = { count = 0, seconds = 0, copper = 0, vendor = 0, unresolved = 0, partial = 0 }
    local first, last
    for _, run in ipairs(character.runs) do
        if (not session or run.session == session) and (not maraudonOnly or MaraFarm.Tracking.IsMaraudon(run)) then
            if run == active then
                result.active = run
            elseif run.partial or not run.lastExit then
                result.partial = result.partial + 1
            else
                result.count = result.count + 1
                result.seconds = result.seconds + run.seconds
                result.copper = result.copper + (run.coin or 0)
                local vendor, pending = MaraFarm.Loot.Total(run)
                result.vendor = result.vendor + vendor
                result.unresolved = result.unresolved + pending
                if run.coin == nil or run.coinUnknown then result.coinUnknown = true end
                first = math.min(first or run.entered, run.entered)
                last = math.max(last or run.lastExit, run.lastExit)
            end
        end
    end
    result.total = result.copper + result.vendor
    if result.count > 0 then result.average = result.total / result.count end
    if result.seconds > 0 then result.insideGPH = result.total * 3600 / result.seconds end
    if first and last > first then result.sessionGPH = result.total * 3600 / (last - first) end
    return result
end
