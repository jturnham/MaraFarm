local _, MaraFarm = ...
local Tracking, Loot = MaraFarm.Tracking, MaraFarm.Loot
local Nova, Source = MaraFarm.Nova, MaraFarm.Source
local UI = {}
MaraFarm.UI = UI

local PAGE_SIZE = 12
local frame, summary, runTotal, heading, previous, nextPage, back, sessionFilter, novaButton
local rows = {}
local page, selectedRun = 1, nil
local selectedSource
local currentSessionOnly = false
local overviewValue

local function Duration(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d:%02d", math.floor(seconds / 3600),
        math.floor(seconds / 60) % 60, seconds % 60)
end

local function Money(copper)
    return string.format("%dg %02ds %02dc", math.floor(copper / 10000),
        math.floor(copper / 100) % 100, copper % 100)
end

local function VendorTotal(run)
    local copper, unresolved = Loot.Total(run)
    local total = Money(copper)
    if unresolved > 0 then total = total .. " + ?" end
    return total
end

local function Text(parent, template, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function Button(parent, label, width, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("BOTTOMLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

UI.Duration = Duration
UI.VendorTotal = VendorTotal
UI.Text = Text
UI.Button = Button

local function CreateWindow()
    frame = CreateFrame("Frame", "MaraFarmWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:Hide()
    frame:SetSize(700, 422)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("MaraFarm")
    tinsert(UISpecialFrames, frame:GetName())

    summary = Text(frame, "GameFontNormal", 20, -34, 660)
    runTotal = Text(frame, "GameFontHighlight", 20, -55, 660)
    heading = {}
    for column, x in ipairs({ 20, 270, 440, 562 }) do
        local width = ({ 245, 165, 117, 118 })[column]
        heading[column] = Text(frame, "GameFontNormalSmall", x, -84, width)
    end

    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(660, 23)
        row:SetPoint("TOPLEFT", 20, -101 - (i - 1) * 23)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.cells = {
            Text(row, "GameFontHighlightSmall", 0, -4, 245),
            Text(row, "GameFontHighlightSmall", 250, -4, 165),
            Text(row, "GameFontHighlightSmall", 420, -4, 117),
            Text(row, "GameFontHighlightSmall", 542, -4, 118),
        }
        row:SetScript("OnClick", function(self)
            if self.run then
                selectedRun = self.run
                page = 1
                UI.Refresh()
            elseif self.source then
                selectedSource = self.source
                page = 1
                UI.Refresh()
            end
        end)
        rows[i] = row
    end

    back = Button(frame, "Runs", 86, 20, 15, function()
        if selectedSource then
            selectedSource = nil
        else
            selectedRun = nil
        end
        page = 1
        UI.Refresh()
    end)
    sessionFilter = Button(frame, "Current session", 125, 20, 15, function()
        currentSessionOnly = not currentSessionOnly
        page = 1
        UI.Refresh()
    end)
    Button(frame, "Options", 86, 399, 15, function()
        MaraFarm.Overlay.ToggleOptions()
    end)
    novaButton = Button(frame, "Nova Log", 96, 291, 15, Nova.Open)
    previous = Button(frame, "Previous", 86, 497, 15, function()
        page = page - 1
        UI.Refresh()
    end)
    nextPage = Button(frame, "Next", 86, 589, 15, function()
        page = page + 1
        UI.Refresh()
    end)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            UI.Refresh(true)
        end
    end)
end

local function UpdateRunHeading(tick)
    runTotal:SetText(string.format("%s  |  %d visits  |  %s inside  |  %s",
        selectedRun.name, selectedRun.visits, Duration(Tracking.Duration(selectedRun, tick)),
        overviewValue))
end

function UI.Refresh(clockOnly)
    if not frame or not frame:IsShown() then return end
    local now, tick = GetServerTime(), GetTime()
    local count, expires = Tracking.Hourly(now)
    local release = count < 10 and "Slot available"
        or (expires and "Earliest expiry in " .. Duration(expires - now) or "Expiry pending")
    local novaCount, novaScope = Nova.Hourly(now)
    local comparison = novaCount and string.format("  |  Nova (%s) %d/10", novaScope, novaCount) or ""
    summary:SetText(string.format("MaraFarm est.  %d/10  |  %s%s", count, release, comparison))
    if clockOnly then
        local active = Tracking.active
        if active and selectedRun == active and not selectedSource then
            UpdateRunHeading(tick)
        elseif active and not selectedRun then
            for _, row in ipairs(rows) do
                if row.run == active then
                    row.cells[3]:SetText(Duration(Tracking.Duration(active, tick)))
                    break
                end
            end
        end
        return
    end
    novaButton:SetShown(Nova.CanOpen())

    local entries = Tracking.character.runs
    local sourceGroup
    if selectedRun then
        entries = Source.Groups(selectedRun)
        if selectedSource then
            for _, group in ipairs(entries) do
                if group.name == selectedSource.name and group.other == selectedSource.other then
                    sourceGroup = group
                    break
                end
            end
            entries = sourceGroup and sourceGroup.loot or {}
        end
    end
    if not selectedRun and currentSessionOnly then
        entries = {}
        for _, run in ipairs(Tracking.character.runs) do
            if run.session == Tracking.character.session then entries[#entries + 1] = run end
        end
    end
    local lastPage = math.max(1, math.ceil(#entries / PAGE_SIZE))
    page = math.max(1, math.min(page, lastPage))
    previous:SetEnabled(page > 1)
    nextPage:SetEnabled(page < lastPage)
    back:SetShown(selectedRun ~= nil)
    back:SetText(selectedSource and "Sources" or "Runs")
    sessionFilter:SetShown(selectedRun == nil)
    sessionFilter:SetText(currentSessionOnly and "All runs" or "Current session")

    local labels
    if selectedSource then
        labels = { "Item", "Quantity", "Vendor / item", "Vendor total" }
        local detail = sourceGroup and #entries > 0 and ("Vendor estimate  " .. VendorTotal(sourceGroup))
            or "No tracked drops"
        runTotal:SetText(selectedSource.name .. "  |  " .. detail)
    elseif selectedRun then
        labels = { "Boss / loot source", "Tracked drops", "", "Vendor total" }
        overviewValue = #entries > 0 and VendorTotal(selectedRun) .. " vendor" or "No tracked drops or bosses"
        UpdateRunHeading(tick)
    else
        labels = { "Dungeon", "First entry", "Time inside", "Vendor estimate" }
        local scope = currentSessionOnly and ("Session " .. Tracking.character.session) or "All sessions"
        runTotal:SetText(string.format("%s  |  %d runs", scope, #entries))
    end
    for i, label in ipairs(labels) do heading[i]:SetText(label) end

    for i, row in ipairs(rows) do
        local index = (page - 1) * PAGE_SIZE + i
        local entry = entries[selectedRun and index or (#entries - index + 1)]
        row:SetShown(entry ~= nil)
        row.run, row.source = nil, nil
        if entry and selectedSource then
            row.cells[1]:SetText(entry.link)
            row.cells[2]:SetText(entry.quantity)
            row.cells[3]:SetText(entry.unitPrice and Money(entry.unitPrice)
                or (entry.unavailable and "Unavailable" or "Pending"))
            row.cells[4]:SetText(entry.unitPrice and Money(entry.unitPrice * entry.quantity) or "-")
        elseif entry and selectedRun then
            row.source = entry
            row.cells[1]:SetText(entry.name)
            row.cells[2]:SetText(#entry.loot)
            row.cells[3]:SetText("")
            row.cells[4]:SetText(VendorTotal(entry))
        elseif entry then
            row.run = entry
            row.cells[1]:SetText(entry.name .. (entry == Tracking.active and "  (active)" or ""))
            row.cells[2]:SetText(date("%Y-%m-%d %H:%M", entry.entered))
            row.cells[3]:SetText(Duration(Tracking.Duration(entry, tick)))
            row.cells[4]:SetText(VendorTotal(entry))
        end
    end
end

function UI.ShowCurrentSession()
    currentSessionOnly, selectedRun, selectedSource, page = true, nil, nil, 1
    UI.Refresh()
end

function UI.Toggle()
    if not frame then CreateWindow() end
    frame:SetShown(not frame:IsShown())
    UI.Refresh()
end
