local _, MaraFarm = ...
local Stats = {}
MaraFarm.Stats = Stats

function Stats.Session(character, session, maraudonOnly, active, includeSeries)
    local result = { count = 0, seconds = 0, copper = 0, vendor = 0, unresolved = 0, partial = 0 }
    if includeSeries then result.series = {} end
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
                if includeSeries then
                    local value = (run.coin or 0) + vendor
                    result.series[#result.series + 1] = { run = run, value = value }
                    result.maximum = math.max(result.maximum or 0, value)
                end
                first = math.min(first or run.entered, run.entered)
                last = math.max(last or run.lastExit, run.lastExit)
            end
        end
    end
    result.total = result.copper + result.vendor
    if result.count > 0 then result.average = result.total / result.count end
    if result.seconds > 0 then result.insideGPH = result.total * 3600 / result.seconds end
    if first and last > first then
        result.elapsed = last - first
        result.sessionGPH = result.total * 3600 / result.elapsed
    end
    return result
end

function Stats.ParseTarget(text)
    local whole, fraction = text:match("^%s*(%d+)%.?(%d*)%s*$")
    if not whole or #fraction > 4 then return end
    local gold = tonumber(text)
    if gold and gold > 0 and gold <= 1000000 then return math.floor(gold * 10000 + 0.5) end
end

function Stats.Project(sample, target)
    local remaining = math.max(0, target - sample.total)
    if remaining == 0 then return 0, 0, 0 end
    if not sample.average or sample.average <= 0 then return end
    local runs = math.ceil(remaining * sample.count / sample.total)
    local inside = sample.seconds > 0 and runs * sample.seconds / sample.count or nil
    local elapsed = sample.elapsed and runs * sample.elapsed / sample.count or nil
    return runs, inside, elapsed
end
