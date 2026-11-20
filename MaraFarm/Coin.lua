local _, MaraFarm = ...
local Coin = {}
MaraFarm.Coin = Coin

local messages, amounts = {}, {}

function Coin.Initialize()
    for _, format in pairs({ YOU_LOOT_MONEY, LOOT_MONEY_SPLIT }) do
        local pattern, fields = MaraFarm.MessagePattern(format)
        if pattern and fields[1] then
            messages[#messages + 1] = { pattern = pattern, field = fields[1] }
        end
    end
    for multiplier, format in pairs({ [10000] = GOLD_AMOUNT, [100] = SILVER_AMOUNT, [1] = COPPER_AMOUNT }) do
        local pattern, fields = MaraFarm.MessagePattern(format)
        if pattern and fields[1] == 1 then
            amounts[#amounts + 1] = { pattern = pattern:sub(2, -2), multiplier = multiplier }
        end
    end
    Coin.available = #messages > 0 and #amounts == 3
end

function Coin.Record(run, message)
    if not run or not Coin.available then return end
    local visit = run.visit
    if MaraFarm.IsSecret(message) then
        run.coinUnknown = true
        if visit then visit.coinUnknown = true end
        return true
    end
    if type(message) ~= "string" then return end
    for _, format in ipairs(messages) do
        local captures = { message:match(format.pattern) }
        local text = captures[format.field]
        if text then
            local copper, found = 0, 0
            for _, amount in ipairs(amounts) do
                text = text:gsub(amount.pattern, function(number)
                    copper = copper + tonumber(number) * amount.multiplier
                    found = found + 1
                    return ""
                end)
            end
            text = text:gsub("\194\160", ""):gsub("\226\128\175", "")
            if found == 0 or text:find("[^%s,%.]") then
                run.coinUnknown = true
                if visit then visit.coinUnknown = true end
            else
                if run.coin == nil then run.coinUnknown = true end
                run.coin = (run.coin or 0) + copper
                if visit then visit.coin = visit.coin + copper end
            end
            return true
        end
    end
end
