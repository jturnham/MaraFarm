local _, MaraFarm = ...
local Loot = {}
MaraFarm.Loot = Loot

local trackedQualities = {
    [2] = "1eff00", -- Uncommon
    [3] = "0070dd", -- Rare
    [4] = "a335ee", -- Epic
}
local qualityByColor = {}
for quality, color in pairs(trackedQualities) do qualityByColor[color] = quality end

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

function Loot.ItemKey(link)
    if MaraFarm.IsSecret(link) or type(link) ~= "string" then return end
    local prefix, key, suffix = link:match("^(.-)|H(item:%d+[^|]*)|h[^|]*|h(.*)$")
    if not key then return end
    if (prefix == "" and suffix == "") or (suffix == "|r"
        and (prefix:match("^|c%x%x%x%x%x%x%x%x$") or prefix:match("^|cn[%w_]+:$"))) then
        return key
    end
end

local function AddFormat(patterns, format, itemField, stackField)
    local pattern, fields = MaraFarm.MessagePattern(format)
    if pattern and fields[itemField] then
        patterns[#patterns + 1] = { pattern = pattern, item = fields[itemField], stack = fields[stackField] }
    end
end

local function MatchMessage(message, patterns)
    for _, format in ipairs(patterns) do
        local fields = { message:match(format.pattern) }
        local link = fields[format.item]
        if Loot.ItemKey(link) then
            local amount = tonumber(fields[format.stack]) or 1
            if amount > 0 then return link, amount end
        end
    end
end

function Loot.Parse(message)
    if MaraFarm.IsSecret(message) or type(message) ~= "string" then return end
    local link, quantity = MatchMessage(message, Loot.receipts)
    if link then return link, quantity, "receipt" end
    link, quantity = MatchMessage(message, Loot.wins)
    if link then return link, quantity, "win" end
end

function Loot.Initialize()
    Loot.pending = {}
    Loot.receipts, Loot.wins = {}, {}
    AddFormat(Loot.receipts, LOOT_ITEM_SELF_MULTIPLE, 1, 2)
    AddFormat(Loot.receipts, LOOT_ITEM_PUSHED_SELF_MULTIPLE, 1, 2)
    AddFormat(Loot.receipts, LOOT_ITEM_SELF, 1)
    AddFormat(Loot.receipts, LOOT_ITEM_PUSHED_SELF, 1)
    AddFormat(Loot.wins, LOOT_ROLL_YOU_WON, 1)
    AddFormat(Loot.wins, LOOT_ROLL_YOU_WON_NO_SPAM_NEED, 3)
    AddFormat(Loot.wins, LOOT_ROLL_YOU_WON_NO_SPAM_GREED, 3)
    for _, run in ipairs(MaraFarm.Tracking.character.runs) do
        for i = #run.loot, 1, -1 do
            local entry = run.loot[i]
            if entry.unitPrice == nil then Loot.Resolve(run, entry, true) end
        end
    end
end

function Loot.Resolve(run, entry, request)
    local _, _, quality, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(entry.link)
    Loot.ApplyItemInfo(run, entry, request, quality, price)
end

function Loot.ApplyItemInfo(run, entry, request, quality, price)
    if MaraFarm.IsSecret(quality) or MaraFarm.IsSecret(price) then
        entry.unavailable = true
        return
    end
    if quality and not trackedQualities[quality] then
        for i, candidate in ipairs(run.loot) do
            if candidate == entry then table.remove(run.loot, i); break end
        end
        return
    end
    entry.quality = quality or entry.quality
    if quality and entry.link:sub(1, 2) == "|H" then
        entry.link = "|cff" .. trackedQualities[quality] .. entry.link .. "|r"
    end
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
    return true
end

function Loot.RecordItem(run, link, quantity, boss)
    -- A link's color is a provisional quality when the item cache is cold.
    local color = link:sub(5, 10):lower()
    local linkQuality = qualityByColor[color] or tonumber(link:match("^|cnIQ(%d+):"))
    local _, _, quality, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(link)
    if MaraFarm.IsSecret(quality) then return end
    local recordedQuality = quality or linkQuality
    if recordedQuality and not trackedQualities[recordedQuality] then return end

    local entry = {
        link = link,
        itemID = tonumber(link:match("|Hitem:(%d+)")),
        quantity = quantity,
        quality = recordedQuality,
        boss = boss or MaraFarm.Source.Take(run, link, quantity),
    }
    run.loot[#run.loot + 1] = entry
    Loot.ApplyItemInfo(run, entry, true, quality, price)
    return entry
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
