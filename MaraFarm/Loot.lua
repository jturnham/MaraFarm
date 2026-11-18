local _, MaraFarm = ...
local Loot = {}
MaraFarm.Loot = Loot

function MaraFarm.IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

-- Translate the string and integer substitutions in Blizzard's localized formats.
function MaraFarm.MessagePattern(format)
    if not format then return nil end
    local parts, fields, index, capture = { "^" }, {}, 1, 0
    while index <= #format do
        local char = format:sub(index, index)
        if char == "%" and format:sub(index + 1, index + 1) == "%" then
            parts[#parts + 1] = "%%"
            index = index + 2
        elseif char == "%" then
            local rest = format:sub(index)
            local position, kind, nextIndex = rest:match("^%%(%d+)%$([sd])()")
            if not kind then kind, nextIndex = rest:match("^%%([sd])()") end
            if not kind then return nil end
            -- Capture order follows the text, even when placeholders are reordered.
            capture = capture + 1
            fields[tonumber(position) or capture] = capture
            parts[#parts + 1] = kind == "s" and "(.+)" or "(%d+)"
            index = index + nextIndex - 1
        else
            parts[#parts + 1] = char:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            index = index + 1
        end
    end
    parts[#parts + 1] = "$"
    return table.concat(parts), fields
end

local function ItemFields(message, pattern, fields)
    if not pattern then return nil end
    local captures = { message:match(pattern) }
    local link = captures[fields[1]]
    if not link or not link:find("^|c%x%x%x%x%x%x%x%x|Hitem:%d+") or not link:find("|h|r$") then
        return nil
    end
    -- Reject a stack suffix or a second link captured by a single-item format.
    if link:find("|h|r", 1, true) ~= #link - 3 then return nil end
    return link, tonumber(captures[fields[2]]) or 1
end

function Loot.Initialize()
    Loot.pending = {}
    Loot.single, Loot.singleFields = MaraFarm.MessagePattern(LOOT_ITEM_SELF)
    Loot.multiple, Loot.multipleFields = MaraFarm.MessagePattern(LOOT_ITEM_SELF_MULTIPLE)
    for _, run in ipairs(MaraFarm.Tracking.character.runs) do
        for i = #run.loot, 1, -1 do
            local entry = run.loot[i]
            if entry.unitPrice == nil then Loot.Resolve(run, entry, true) end
        end
    end
end

function Loot.Resolve(run, entry, request)
    local _, _, quality, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(entry.link)
    if MaraFarm.IsSecret(quality) or MaraFarm.IsSecret(price) then
        entry.unavailable = true
        return
    end
    if quality and quality ~= 2 and quality ~= 3 then
        for i, candidate in ipairs(run.loot) do
            if candidate == entry then table.remove(run.loot, i); break end
        end
        return
    end
    entry.quality = quality or entry.quality
    if quality and type(price) == "number" then
        entry.unitPrice = price
        entry.unavailable = nil
        return
    end
    if request then
        local queue = Loot.pending[entry.itemID]
        if not queue then
            queue = {}
            Loot.pending[entry.itemID] = queue
        end
        queue[#queue + 1] = { run = run, entry = entry }
        if #queue == 1 then C_Item.RequestLoadItemDataByID(entry.itemID) end
    else
        entry.unavailable = true
    end
end

function Loot.ItemReady(itemID)
    local queue = Loot.pending[itemID]
    if not queue then return end
    Loot.pending[itemID] = nil
    for _, pending in ipairs(queue) do
        Loot.Resolve(pending.run, pending.entry, false)
    end
end

function Loot.Record(run, message, senderGUID, playerGUID)
    if not run or MaraFarm.IsSecret(message) or type(message) ~= "string" then return end
    if not MaraFarm.IsSecret(senderGUID) and not MaraFarm.IsSecret(playerGUID)
        and senderGUID and senderGUID ~= "" and playerGUID and senderGUID ~= playerGUID then
        return
    end
    local link, quantity = ItemFields(message, Loot.multiple, Loot.multipleFields)
    if not link then link, quantity = ItemFields(message, Loot.single, Loot.singleFields) end
    if not link or quantity < 1 then return end

    -- A link's color is a provisional quality when the item cache is cold.
    local color = link:sub(5, 10):lower()
    local linkQuality = color == "1eff00" and 2 or color == "0070dd" and 3 or nil
    local _, _, quality = C_Item.GetItemInfo(link)
    if MaraFarm.IsSecret(quality) then return end
    quality = quality or linkQuality
    if quality ~= 2 and quality ~= 3 then return end

    local entry = {
        link = link,
        itemID = tonumber(link:match("|Hitem:(%d+)")),
        quantity = quantity,
        quality = quality,
        boss = MaraFarm.Source.Take(run, link, quantity),
    }
    run.loot[#run.loot + 1] = entry
    Loot.Resolve(run, entry, true)
end

function Loot.Total(run)
    local copper, unresolved = 0, 0
    for _, entry in ipairs(run.loot) do
        if entry.unitPrice ~= nil then
            copper = copper + entry.unitPrice * entry.quantity
        else
            unresolved = unresolved + entry.quantity
        end
    end
    return copper, unresolved
end
