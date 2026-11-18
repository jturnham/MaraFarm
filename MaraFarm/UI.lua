local _, MaraFarm = ...
local Tracking, Loot = MaraFarm.Tracking, MaraFarm.Loot
local Nova, Source = MaraFarm.Nova, MaraFarm.Source
local Skin = MaraFarm.Skin
local UI = {}
MaraFarm.UI = UI

local PAGE_SIZE = 12
local frame, summary, runTotal, heading, previous, nextPage, back, sessionFilter, novaButton
local pageText, empty, dungeonFilter
local rows = {}
local page, selectedRun = 1, nil
local selectedSource
local selectedSession, maraudonOnly
local overviewValue

local function Duration(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d:%02d", math.floor(seconds / 3600),
        math.floor(seconds / 60) % 60, seconds % 60)
end

local function Money(copper)
    copper = math.floor(copper + 0.5)
    return string.format("%dg %02ds %02dc", math.floor(copper / 10000),
        math.floor(copper / 100) % 100, copper % 100)
end

local function VendorTotal(run)
    local copper, unresolved = Loot.Total(run)
    local total = Money(copper)
    if unresolved > 0 then total = total .. " + ?" end
    return total
end

local Text, Button = Skin.Text, Skin.Button

UI.Duration = Duration
UI.Money = Money
UI.VendorTotal = VendorTotal

function UI.Scope()
    return selectedSession, maraudonOnly
end

local function CycleSession()
    local character = Tracking.character
    if not selectedSession then
        selectedSession = character.session
        return
    end
    local previousSession
    for _, run in ipairs(character.runs) do
        if run.session < selectedSession and (not previousSession or run.session > previousSession) then
            previousSession = run.session
        end
    end
    selectedSession = previousSession
end

local function CreateWindow()
    frame = Skin.Window("MaraFarmWindow", "MaraFarm  /  Run history", 740, 498)
    local chartsButton = Button(frame, "Charts", 82, 580, 460, MaraFarm.Charts.Toggle, true)
    chartsButton:SetFrameLevel(frame:GetFrameLevel() + 3)
    Skin.Band(frame, 63, 33, 18, Skin.surface)
    Skin.Band(frame, 132, 27, 18, Skin.surface)
    Skin.Band(frame, 452, 1, 18, Skin.line)
    summary = Text(frame, "GameFontHighlight", 30, -73, 680, Skin.accent)
    runTotal = Text(frame, "GameFontHighlight", 20, -110, 570)
    empty = Text(frame, "GameFontHighlight", 20, -207, 700, Skin.muted, "CENTER")
    pageText = Text(frame, "GameFontHighlightSmall", 581, -472, 58, Skin.muted, "CENTER")
    heading = {}
    local columns = {
        { 12, 246, "LEFT" },
        { 274, 139, "LEFT" },
        { 424, 121, "RIGHT" },
        { 558, 116, "RIGHT" },
    }
    for column, layout in ipairs(columns) do
        heading[column] = Text(frame, "GameFontHighlightSmall", 18 + layout[1], -141,
            layout[2], Skin.muted, layout[3])
    end

    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(704, 24)
        row:SetPoint("TOPLEFT", 18, -160 - (i - 1) * 24)
        if i % 2 == 1 then Skin.Fill(row, "BACKGROUND", Skin.stripe):SetAllPoints() end
        local highlight = Skin.Fill(row, "HIGHLIGHT", { 0.41, 0.69, 0.63, 0.18 })
        highlight:SetAllPoints()
        row:SetHighlightTexture(highlight)
        row.cells = {}
        for column, layout in ipairs(columns) do
            row.cells[column] = Text(row, "GameFontHighlightSmall", layout[1], -7, layout[2],
                column == 4 and Skin.gold or Skin.ink, layout[3])
        end
        row.arrow = Text(row, "GameFontHighlightSmall", 686, -7, 12, Skin.accent)
        row.arrow:SetText(">")
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

    back = Button(frame, "Runs", 105, 18, 13, function()
        if selectedSource then
            selectedSource = nil
        else
            selectedRun = nil
        end
        page = 1
        UI.Refresh()
    end, true)
    sessionFilter = Button(frame, "Session", 125, 18, 13, function()
        CycleSession()
        page = 1
        UI.Refresh()
        MaraFarm.Dashboard.Refresh()
        MaraFarm.Charts.Refresh()
    end)
    dungeonFilter = Button(frame, "All dungeons", 123, 599, 368, function()
        maraudonOnly = not maraudonOnly
        page = 1
        UI.Refresh()
        MaraFarm.Dashboard.Refresh()
        MaraFarm.Charts.Refresh()
    end)
    Button(frame, "Options", 78, 153, 13, function()
        MaraFarm.Overlay.ToggleOptions()
    end)
    novaButton = Button(frame, "Nova Log", 86, 241, 13, Nova.Open)
    Button(frame, "Summary", 74, 336, 13, function() MaraFarm.Dashboard.Toggle("summary") end)
    Button(frame, "Lockouts", 74, 416, 13, function() MaraFarm.Dashboard.Toggle("lockouts") end)
    previous = Button(frame, "Previous", 80, 495, 13, function()
        page = page - 1
        UI.Refresh()
    end)
    nextPage = Button(frame, "Next", 76, 646, 13, function()
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
    summary:SetText(string.format("Hourly lockout estimate  %d / 10  |  %s%s", count, release, comparison))
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
    if not selectedRun and (selectedSession or maraudonOnly) then
        entries = {}
        for _, run in ipairs(Tracking.character.runs) do
            if (not selectedSession or run.session == selectedSession)
                and (not maraudonOnly or Tracking.IsMaraudon(run)) then
                entries[#entries + 1] = run
            end
        end
    end
    local lastPage = math.max(1, math.ceil(#entries / PAGE_SIZE))
    page = math.max(1, math.min(page, lastPage))
    pageText:SetText(string.format("%d / %d", page, lastPage))
    previous:SetEnabled(page > 1)
    nextPage:SetEnabled(page < lastPage)
    back:SetShown(selectedRun ~= nil)
    back:SetText(selectedSource and "< Loot sources" or "< Run history")
    sessionFilter:SetShown(selectedRun == nil)
    sessionFilter:SetText(selectedSession and ("Session " .. selectedSession .. "  >") or "All sessions  >")
    dungeonFilter:SetShown(not selectedRun)
    dungeonFilter:SetText(maraudonOnly and "Maraudon only" or "All dungeons")
    empty:SetShown(#entries == 0)
    if #entries == 0 then
        if selectedRun then
            empty:SetText(selectedSource and "No tracked drops from this source." or "No bosses or tracked loot recorded.")
        else
            empty:SetText("Enter a dungeon to record a run.")
        end
    end

    local labels
    if selectedSource then
        labels = { "Item", "Quantity", "Vendor / item", "Vendor total" }
        local detail = #entries > 0 and ("  |  Vendor estimate  " .. VendorTotal(sourceGroup)) or ""
        runTotal:SetText(selectedSource.name .. detail)
    elseif selectedRun then
        labels = { "Boss / loot source", "Tracked drops", "", "Vendor total" }
        overviewValue = VendorTotal(selectedRun) .. " vendor"
        UpdateRunHeading(tick)
    else
        labels = { "Dungeon", "First entry", "Time inside", "Vendor estimate" }
        local scope = selectedSession and ("Session " .. selectedSession) or "All sessions"
        runTotal:SetText(string.format("%s  |  %d runs", scope, #entries))
    end
    for i, label in ipairs(labels) do heading[i]:SetText(label) end

    for i, row in ipairs(rows) do
        local index = (page - 1) * PAGE_SIZE + i
        local entry = entries[selectedRun and index or (#entries - index + 1)]
        row:SetShown(entry ~= nil)
        row.arrow:SetShown(selectedSource == nil)
        row:EnableMouse(selectedSource == nil)
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
            local status = entry == Tracking.active and "  (active)" or entry.partial and "  (partial)" or ""
            row.cells[1]:SetText(entry.name .. status)
            row.cells[2]:SetText(date("%Y-%m-%d %H:%M", entry.entered))
            row.cells[3]:SetText(Duration(Tracking.Duration(entry, tick)))
            row.cells[4]:SetText(VendorTotal(entry))
        end
    end
end

function UI.ShowCurrentSession()
    selectedSession, selectedRun, selectedSource, page = Tracking.character.session, nil, nil, 1
    UI.Refresh()
    MaraFarm.Charts.Refresh()
end

function UI.Toggle()
    if not frame then CreateWindow() end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then MaraFarm.Charts.Position() end
    UI.Refresh()
end
