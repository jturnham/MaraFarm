local _, MaraFarm = ...
local Skin, UI, Tracking, Stats = MaraFarm.Skin, MaraFarm.UI, MaraFarm.Tracking, MaraFarm.Stats
local Dashboard = {}
MaraFarm.Dashboard = Dashboard

local frame, status, footer, previous, nextPage, novaStatus
local rows = {}
local mode, page, summary = "summary", 1, nil
local PAGE_SIZE = 8

local function CreateWindow()
    frame = Skin.Window("MaraFarmDashboard", "MaraFarm  /  Farm overview", 462, 348)
    frame:SetFrameStrata("DIALOG")
    Skin.Button(frame, "Session summary", 118, 18, 258, function()
        mode = "summary"
        Dashboard.Refresh()
    end, true)
    Skin.Button(frame, "Hourly lockouts", 118, 146, 258, function()
        mode, page = "lockouts", 1
        Dashboard.Refresh()
    end, true)
    Skin.Button(frame, "Charts", 82, 274, 258, function() MaraFarm.Charts.Toggle(frame) end, true)
    status = Skin.Text(frame, "GameFontHighlight", 20, -104, 422, Skin.accent)
    for i = 1, PAGE_SIZE do
        local top = 126 + (i - 1) * 21
        if i % 2 == 1 then Skin.Band(frame, top, 21, 18, Skin.stripe) end
        rows[i] = {
            Skin.Text(frame, "GameFontHighlightSmall", 25, -top - 5, 200),
            Skin.Text(frame, "GameFontHighlightSmall", 226, -top - 5, 210, Skin.gold, "RIGHT"),
        }
    end
    footer = Skin.Text(frame, "GameFontHighlightSmall", 20, -300, 422, Skin.muted)
    novaStatus = Skin.Text(frame, "GameFontHighlightSmall", 20, -320, 252, Skin.muted)
    previous = Skin.Button(frame, "Previous", 77, 282, 11, function()
        page = page - 1
        Dashboard.Refresh()
    end)
    nextPage = Skin.Button(frame, "Next", 77, 367, 11, function()
        page = page + 1
        Dashboard.Refresh()
    end)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            Dashboard.Refresh(true)
        end
    end)
end

local function Row(index, label, value)
    rows[index][1]:SetText(label or "")
    rows[index][2]:SetText(value or "")
end

local function Rate(value, suffix)
    return value and UI.Money(value) .. suffix or "-"
end

local function Summary(clockOnly)
    if not clockOnly or not summary then
        local session, maraudonOnly = UI.Scope()
        summary = Stats.Session(Tracking.character, session, maraudonOnly, Tracking.active)
        status:SetText((session and "Session " .. session or "All sessions")
            .. (maraudonOnly and "  |  Maraudon" or "  |  All dungeons"))
        local coinUnknown = summary.coinUnknown or not MaraFarm.Coin.available
        local uncertain = summary.unresolved > 0 or coinUnknown
        local suffix = uncertain and " +" or ""
        Row(1, "Completed runs / time inside", summary.count .. "  /  " .. UI.Duration(summary.seconds))
        Row(2, "Looted coin", coinUnknown and (summary.copper > 0 and UI.Money(summary.copper) .. " +" or "Unknown")
            or UI.Money(summary.copper))
        Row(3, "Vendor estimate", UI.Money(summary.vendor) .. (summary.unresolved > 0 and " +" or ""))
        Row(4, "Estimated earnings", UI.Money(summary.total) .. suffix)
        Row(5, "Average gold per run", Rate(summary.average, suffix))
        Row(6, "In-instance GPH", Rate(summary.insideGPH, suffix))
        Row(7, "Session GPH", Rate(summary.sessionGPH, suffix))
        footer:SetText(string.format("%d partial runs excluded  |  %d items without prices",
            summary.partial, summary.unresolved))
        novaStatus:Hide()
        previous:Hide()
        nextPage:Hide()
    end
    local active = summary.active
    Row(8, "Active run", active and (active.name .. "  " .. UI.Duration(Tracking.Duration(active, GetTime()))) or "-")
end

local function Lockouts()
    local now, slots = GetServerTime(), {}
    local count = Tracking.Hourly(now, slots)
    table.sort(slots, function(a, b) return (a.expires or math.huge) < (b.expires or math.huge) end)
    local pages = math.max(1, math.ceil(#slots / PAGE_SIZE))
    page = math.max(1, math.min(page, pages))
    for i = 1, PAGE_SIZE do
        local slot = slots[(page - 1) * PAGE_SIZE + i]
        if slot then
            local provisional = slot.run.suspendedAt and " ~" or ""
            local time = slot.active and "Inside" or UI.Duration(slot.expires - now) .. provisional
            Row(i, slot.run.name, date("%H:%M", slot.anchor) .. "  /  " .. time)
        else
            Row(i)
        end
    end
    local warning = (Tracking.serverWarningUntil or 0) > now and "  |  Server reported a cap" or ""
    status:SetText(string.format("Estimated  %d / 10 used  |  %d free%s", count, math.max(0, 10 - count), warning))
    footer:SetText(string.format("Character estimate  |  Anchor / time left  |  %d / %d", page, pages))
    local novaCount, scope, expiry = MaraFarm.Nova.Hourly(now)
    novaStatus:SetShown(novaCount ~= nil)
    if novaCount then
        local detail = expiry and expiry > now and ("  |  " .. UI.Duration(expiry - now) .. " left") or ""
        if scope == "character" and novaCount ~= count and detail == "" then detail = "  |  Counts differ" end
        novaStatus:SetText(string.format("Nova (%s)  %d / 10%s", scope, novaCount, detail))
    end
    previous:SetShown(pages > 1)
    nextPage:SetShown(pages > 1)
    previous:SetEnabled(page > 1)
    nextPage:SetEnabled(page < pages)
end

function Dashboard.Refresh(clockOnly)
    if not frame or not frame:IsShown() then return end
    if mode == "summary" then
        Summary(clockOnly)
    else
        Lockouts()
    end
end

function Dashboard.Toggle(panel)
    MaraFarm.Charts.Dismiss()
    if not frame then CreateWindow() end
    if frame:IsShown() and panel == mode then
        frame:Hide()
        return
    end
    mode, page = panel, 1
    frame:Show()
    Dashboard.Refresh()
end
