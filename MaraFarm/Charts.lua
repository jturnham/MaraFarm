local _, MaraFarm = ...
local Skin, UI, Tracking, Stats = MaraFarm.Skin, MaraFarm.UI, MaraFarm.Tracking, MaraFarm.Stats
local Charts = {}
MaraFarm.Charts = Charts

local PAGE_SIZE, PLOT_WIDTH, PLOT_HEIGHT = 12, 616, 158
local frame, plot, status, xTitle, resultText, note, pageText, guide
local targetBox, targetLabel, apply, paceButton, previous, nextPage
local tabs, bars, axis = {}, {}, {}
local mode, overallPace, pageOffset = "session", false, 0
local sample
local restoreDashboard

local function RestoreDashboard()
    if frame:IsShown() then return end
    if not restoreDashboard then return end
    restoreDashboard = false
    MaraFarmDashboard:Show()
    MaraFarm.Dashboard.Refresh()
end

local function ScaleTop(value)
    if value <= 0 then return 10000 end
    local magnitude = 10 ^ math.floor(math.log(value) / math.log(10))
    for _, step in ipairs({ 1, 2, 5, 10 }) do
        if value <= magnitude * step then return magnitude * step end
    end
end

local function ChartScale(maximum)
    local top = ScaleTop(maximum)
    for i, label in ipairs(axis) do
        label:SetText(string.format("%gg", top / 10000 * (i - 1) / 4))
    end
    return top
end

local function ShowBar(index, columns, value, maximum, label, heading, detail, color)
    local bar = bars[index]
    local columnWidth = PLOT_WIDTH / columns
    local center = columnWidth * (index - 0.5)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", center - columnWidth * 0.28, 0)
    bar:SetSize(columnWidth * 0.56, math.max(2, PLOT_HEIGHT * value / maximum))
    bar.fill:SetColorTexture(unpack(color))
    bar.caption:ClearAllPoints()
    bar.caption:SetPoint("TOP", plot, "BOTTOMLEFT", center, -7)
    bar.caption:SetText(label)
    bar.heading, bar.detail, bar.value = heading, detail, UI.Money(value)
    bar:Show()
    bar.caption:Show()
end

local function ShowGuide(value, maximum)
    guide:ClearAllPoints()
    guide:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, PLOT_HEIGHT * value / maximum)
    guide:Show()
end

local function ApplyTarget()
    local target = Stats.ParseTarget(targetBox:GetText())
    if not target then
        note:SetText("Enter a target from 0.0001 to 1,000,000 gold, with up to four decimal places.")
        return
    end
    MaraFarmDB.chartTarget = target
    targetBox:SetText(tostring(target / 10000))
    targetBox:ClearFocus()
    Charts.Refresh(true)
end

local function CreateWindow()
    frame = Skin.Window("MaraFarmCharts", "MaraFarm  /  Charts", 742, 465)
    frame:SetFrameStrata("DIALOG")
    local items = { { "session", "Session runs" }, { "overall", "Overall runs" }, { "projection", "Gold target" } }
    for i, item in ipairs(items) do
        local tab = item[1]
        tabs[tab] = Skin.Button(frame, item[2], 111, 18 + (i - 1) * 120, 374, function()
            mode, pageOffset = tab, 0
            Charts.Refresh()
        end, true)
    end

    targetLabel = Skin.Text(frame, "GameFontHighlightSmall", 400, -73, 60, Skin.muted)
    targetLabel:SetText("Target (g)")
    targetBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    targetBox:SetSize(95, 24)
    targetBox:SetPoint("TOPLEFT", 462, -66)
    targetBox:SetAutoFocus(false)
    targetBox:SetMaxLetters(12)
    targetBox:SetText(tostring((MaraFarmDB.chartTarget or 1000000) / 10000))
    targetBox:SetScript("OnEnterPressed", ApplyTarget)
    targetBox:SetScript("OnEscapePressed", targetBox.ClearFocus)
    frame:SetScript("OnHide", function()
        targetBox:ClearFocus()
        -- Escape may still be closing other entries in UISpecialFrames.
        if restoreDashboard then C_Timer.After(0, RestoreDashboard) end
    end)
    apply = Skin.Button(frame, "Apply", 58, 570, 374, ApplyTarget)
    paceButton = Skin.Button(frame, "Session pace", 88, 636, 374, function()
        overallPace = not overallPace
        Charts.Refresh()
    end)

    status = Skin.Text(frame, "GameFontHighlight", 20, -109, 703, Skin.accent)
    plot = CreateFrame("Frame", nil, frame)
    plot:SetPoint("TOPLEFT", 84, -148)
    plot:SetSize(PLOT_WIDTH, PLOT_HEIGHT)
    Skin.Fill(plot, "BACKGROUND", Skin.stripe):SetAllPoints()
    for i = 0, 4 do
        local y = i * PLOT_HEIGHT / 4
        local line = Skin.Fill(plot, "BORDER", Skin.line)
        line:SetPoint("BOTTOMLEFT", 0, y)
        line:SetSize(PLOT_WIDTH, 1)
        local label = Skin.Text(frame, "GameFontHighlightSmall", 15, -300 + y, 58, Skin.muted, "RIGHT")
        axis[i + 1] = label
    end
    local guideLayer = CreateFrame("Frame", nil, plot)
    guideLayer:SetAllPoints()
    guideLayer:SetFrameLevel(plot:GetFrameLevel() + 2)
    guide = Skin.Fill(guideLayer, "BORDER", Skin.gold)
    guide:SetSize(PLOT_WIDTH, 1)

    for i = 1, PAGE_SIZE do
        local bar = CreateFrame("Frame", nil, plot)
        bar:EnableMouse(true)
        bar.fill = Skin.Fill(bar, "ARTWORK", Skin.accent)
        bar.fill:SetAllPoints()
        bar.caption = Skin.Text(frame, "GameFontHighlightSmall", 0, 0, 100, Skin.muted, "CENTER")
        bar:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.heading)
            GameTooltip:AddLine(self.value, unpack(Skin.gold))
            if self.detail then GameTooltip:AddLine(self.detail, unpack(Skin.muted)) end
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bars[i] = bar
    end
    xTitle = Skin.Text(frame, "GameFontHighlightSmall", 84, -331, PLOT_WIDTH, Skin.muted, "CENTER")
    resultText = Skin.Text(frame, "GameFontHighlight", 20, -366, 703, Skin.ink)
    note = Skin.Text(frame, "GameFontHighlightSmall", 20, -392, 703, Skin.muted)
    pageText = Skin.Text(frame, "GameFontHighlightSmall", 583, -438, 54, Skin.muted, "CENTER")
    previous = Skin.Button(frame, "Previous", 78, 496, 12, function()
        pageOffset = pageOffset + 1
        Charts.Refresh(true)
    end)
    nextPage = Skin.Button(frame, "Next", 78, 646, 12, function()
        pageOffset = pageOffset - 1
        Charts.Refresh(true)
    end)
end

local function History()
    local pages = math.max(1, math.ceil(sample.count / PAGE_SIZE))
    pageOffset = math.min(pageOffset, pages - 1)
    local page = pages - pageOffset
    local first = (page - 1) * PAGE_SIZE + 1
    local maximum = ChartScale(sample.maximum or 0)
    for i = 1, PAGE_SIZE do
        local index = first + i - 1
        local point = sample.series[index]
        if point then
            ShowBar(i, PAGE_SIZE, point.value, maximum, tostring(index),
                point.run.name .. "  |  Run " .. index, date("%Y-%m-%d %H:%M", point.run.entered), Skin.accent)
        end
    end
    if sample.average then ShowGuide(sample.average, maximum) end
    previous:SetEnabled(page > 1)
    nextPage:SetEnabled(page < pages)
    pageText:SetText(string.format("%d / %d", page, pages))
    xTitle:SetText("Completed runs in first-entry order")
    resultText:SetText(sample.average and string.format("%d runs  |  Average %s (gold line)",
        sample.count, UI.Money(sample.average)) or "Complete a measured run to see earnings here.")
end

local function Projection(session)
    local target = MaraFarmDB.chartTarget or 1000000
    local runs, inside, elapsed = Stats.Project(sample, target)
    local maximum = ChartScale(math.max(target, sample.total, sample.total + (runs or 0) * (sample.average or 0)))
    ShowGuide(target, maximum)
    local columns = runs and math.min(runs + 1, 6) or 1
    for i = 1, columns do
        local extra = i == 1 and 0 or math.ceil((i - 1) * runs / (columns - 1))
        ShowBar(i, columns, sample.total + extra * (sample.average or 0), maximum, tostring(extra),
            extra == 0 and "Earned so far" or ("After " .. extra .. " more runs"), nil,
            extra == 0 and Skin.accent or Skin.gold)
    end
    xTitle:SetText("Additional runs  |  Gold line marks the target")
    if not runs then
        resultText:SetText("Complete a measured run with positive earnings to estimate a finish.")
    elseif runs == 0 then
        resultText:SetText("Target reached  |  " .. UI.Money(sample.total) .. " earned")
    else
        local text = string.format("%d more %s  |  %s inside dungeons", runs, runs == 1 and "run" or "runs",
            inside and UI.Duration(inside) or "Unknown time")
        if session and elapsed then text = text .. "  |  " .. UI.Duration(elapsed) .. " at session pace" end
        resultText:SetText(text)
    end
end

function Charts.Refresh(reuseSample)
    if not frame or not frame:IsShown() then return end
    local historySession, maraudonOnly = UI.Scope()
    local projection = mode == "projection"
    local session
    if mode == "session" or (projection and not overallPace) then
        session = historySession or Tracking.character.session
    end
    if not reuseSample or not sample then
        sample = Stats.Session(Tracking.character, session, maraudonOnly, Tracking.active, not projection)
    end
    for tab, button in pairs(tabs) do button:SetEnabled(tab ~= mode) end
    for _, control in ipairs({targetBox, targetLabel, apply, paceButton}) do control:SetShown(projection) end
    paceButton:SetText(overallPace and "Overall pace" or "Session pace")
    for _, control in ipairs({pageText, previous, nextPage}) do control:SetShown(not projection) end
    guide:Hide()
    for _, bar in ipairs(bars) do
        bar:Hide()
        bar.caption:Hide()
    end
    status:SetText((session and "Session " .. session or "All sessions")
        .. (maraudonOnly and "  |  Maraudon" or "  |  All dungeons")
        .. (projection and ("  |  Earned " .. UI.Money(sample.total)) or "  |  Estimated gold per run"))
    if projection then Projection(session) else History() end
    local incomplete = sample.unresolved > 0 or sample.coinUnknown or not MaraFarm.Coin.available
    note:SetText(incomplete and "Estimates use known coin and vendor prices. Some earnings are missing."
        or (projection and "Based on completed-run averages. Future drops and wait times can vary."
            or "Excludes active and partial runs."))
end

function Charts.Dismiss()
    restoreDashboard = false
    if frame and frame:IsShown() then frame:Hide() end
end

function Charts.Position()
    if not frame or not frame:IsShown() then return end
    local history = MaraFarmWindow
    local centerX, centerY = UIParent:GetCenter()
    if not centerX or not centerY then return end

    local x, y
    if history and history:IsShown() then
        local left, right = history:GetLeft(), history:GetRight()
        local _, historyY = history:GetCenter()
        local screenLeft, screenRight = UIParent:GetLeft(), UIParent:GetRight()
        if left and right and historyY and screenLeft and screenRight then
            local halfWidth = frame:GetWidth() / 2
            x = screenRight - right >= left - screenLeft and (right + 12 + halfWidth) or (left - 12 - halfWidth)
            y = historyY
        end
    elseif restoreDashboard then
        x, y = MaraFarmDashboard:GetCenter()
    end
    if x and y then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", x - centerX, y - centerY)
    end
end

function Charts.Toggle()
    if not frame then CreateWindow() end
    if frame:IsShown() then
        frame:Hide()
        return
    end

    restoreDashboard = MaraFarmDashboard and MaraFarmDashboard:IsShown()
    if restoreDashboard then MaraFarmDashboard:Hide() end
    frame:Show()
    Charts.Position()
    Charts.Refresh()
end
