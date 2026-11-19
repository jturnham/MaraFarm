local _, MaraFarm = ...
local UI, Tracking = MaraFarm.UI, MaraFarm.Tracking
local Skin = MaraFarm.Skin
local Dungeons = MaraFarm.Dungeons
local Overlay = {}
MaraFarm.Overlay = Overlay

local overlay, options, title, timer, vendor, lockout, gph, vendorLabel, lockoutLabel, gphLabel
local previewButton, sessionLabel, earnings, earningsIncomplete
local preview = false
local checks = {}
local dungeonWindow, dungeonEntries, dungeonMaster, dungeonPageText, dungeonPrevious, dungeonNext
local dungeonRows = {}
local dungeonPage, DUNGEONS_PER_PAGE = 1, 9

local function Position()
    overlay:ClearAllPoints()
    local settings = Overlay.settings
    if settings.x and settings.y then
        overlay:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    else
        overlay:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -240)
    end
end

local function CreateOverlay()
    overlay = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    overlay:Hide()
    overlay:SetSize(274, 106)
    overlay:SetFrameStrata("MEDIUM")
    overlay:SetClampedToScreen(true)
    overlay:SetMovable(true)
    Skin.Panel(overlay, 0.92)
    Skin.Band(overlay, 1, 29, 1, Skin.surface)
    Skin.Band(overlay, 30, 1, 1, Skin.line)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnDragStart", function(self)
        if preview then self:StartMoving() end
    end)
    overlay:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then
            Overlay.settings.x = x - parentX
            Overlay.settings.y = y - parentY
            Position()
        end
    end)

    title = Skin.Text(overlay, "GameFontHighlight", 13, -9, 248, Skin.accent)
    local function Metric(label, top, color)
        local caption = Skin.Text(overlay, "GameFontHighlightSmall", 13, -top, 145, Skin.muted)
        caption:SetText(label)
        return Skin.Text(overlay, "GameFontHighlight", 160, -top, 101, color, "RIGHT"), caption
    end
    timer = Metric("Time inside", 40, Skin.ink)
    vendor, vendorLabel = Metric("Vendor estimate", 60, Skin.gold)
    lockout, lockoutLabel = Metric("Est. hourly lockout", 80, Skin.ink)
    gph, gphLabel = Metric("Live run GPH", 100, Skin.gold)

    local elapsed = 0
    overlay:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            if not preview then Overlay.Refresh(true) end
        end
    end)
    Position()
end

local function UpdateGPH(seconds)
    if seconds <= 0 then
        gph:SetText("-")
    else
        gph:SetText(UI.Money(earnings * 3600 / seconds) .. (earningsIncomplete and " +" or ""))
    end
end

function Overlay.Refresh(clockOnly)
    local settings = Overlay.settings
    local run = Tracking.active
    if not settings or not (preview or (settings.enabled and run and Dungeons.IsEnabled(Dungeons.MapID(run)))) then
        if overlay then overlay:Hide() end
        return
    end

    if not overlay then CreateOverlay() end
    local seconds = preview and 504 or Tracking.Duration(run, GetTime())
    timer:SetText(UI.Duration(seconds))
    if clockOnly then
        if settings.gph then UpdateGPH(seconds) end
        if settings.lockout then
            lockout:SetText(string.format("%d / 10", Tracking.Hourly(GetServerTime())))
        end
        return
    end
    overlay:EnableMouse(preview)
    overlay:SetFrameStrata(preview and "DIALOG" or "MEDIUM")
    title:SetText(preview and "Preview - drag to move" or run.name)

    local bottom = 60
    vendor:SetShown(settings.vendor)
    vendorLabel:SetShown(settings.vendor)
    if settings.vendor then
        vendor:SetText(preview and "1g 42s 08c" or UI.VendorTotal(run))
        bottom = bottom + 20
    end

    lockout:SetShown(settings.lockout)
    lockoutLabel:SetShown(settings.lockout)
    if settings.lockout then
        lockout:ClearAllPoints()
        lockout:SetPoint("TOPLEFT", 160, -bottom)
        lockoutLabel:ClearAllPoints()
        lockoutLabel:SetPoint("TOPLEFT", 13, -bottom)
        local count = preview and 4 or Tracking.Hourly(GetServerTime())
        lockout:SetText(string.format("%d / 10", count))
        bottom = bottom + 20
    end
    gph:SetShown(settings.gph)
    gphLabel:SetShown(settings.gph)
    if settings.gph then
        gph:ClearAllPoints()
        gph:SetPoint("TOPLEFT", 160, -bottom)
        gphLabel:ClearAllPoints()
        gphLabel:SetPoint("TOPLEFT", 13, -bottom)
        if preview then
            earnings, earningsIncomplete = 14208, false
        else
            local subtotal, pending = MaraFarm.Loot.Total(run)
            earnings = subtotal + (run.coin or 0)
            earningsIncomplete = pending > 0 or run.coin == nil or run.coinUnknown or not MaraFarm.Coin.available
        end
        UpdateGPH(seconds)
        bottom = bottom + 20
    end

    overlay:SetHeight(bottom + 4)
    overlay:Show()
end

local function RefreshDungeonRows()
    local pages = math.max(1, math.ceil(#dungeonEntries / DUNGEONS_PER_PAGE))
    dungeonPage = math.max(1, math.min(dungeonPage, pages))
    dungeonMaster:SetChecked(Overlay.settings.enabled)
    for i, row in ipairs(dungeonRows) do
        local entry = dungeonEntries[(dungeonPage - 1) * DUNGEONS_PER_PAGE + i]
        row:SetShown(entry ~= nil)
        if entry then
            row.mapID = entry.id
            row.label:SetText(entry.name)
            row:SetChecked(Dungeons.IsEnabled(entry.id))
        end
    end
    dungeonPageText:SetText(string.format("%d / %d", dungeonPage, pages))
    dungeonPrevious:SetEnabled(dungeonPage > 1)
    dungeonNext:SetEnabled(dungeonPage < pages)
end

function Overlay.RememberDungeon(run)
    if Dungeons.Remember(run) and dungeonWindow and dungeonWindow:IsShown() then
        dungeonEntries = Dungeons.List()
        RefreshDungeonRows()
    end
end

local function DungeonCheck(parent, y, labelWidth, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 14, y)
    check:SetHitRectInsets(0, -labelWidth, 0, 0)
    check.label = Skin.Text(check, "GameFontHighlight", 31, -9, labelWidth)
    check:SetScript("OnClick", onClick)
    return check
end

local function CreateDungeonWindow()
    dungeonWindow = Skin.Window("MaraFarmDungeonOverlayOptions", "MaraFarm  /  Dungeon overlay", 414, 407)
    dungeonWindow:SetParent(options)
    dungeonWindow:SetFrameStrata("DIALOG")
    dungeonWindow:SetFrameLevel(options:GetFrameLevel() + 5)
    dungeonMaster = DungeonCheck(dungeonWindow, -59, 164, function(self)
        Overlay.settings.enabled = not not self:GetChecked()
        Overlay.Refresh()
    end)
    dungeonMaster.label:SetText("Enable overlay")
    local function SelectAll(enabled)
        Dungeons.SetAll(enabled)
        RefreshDungeonRows()
        Overlay.Refresh()
    end
    Skin.Button(dungeonWindow, "Select all", 78, 222, 320, function() SelectAll(true) end)
    Skin.Button(dungeonWindow, "Clear all", 78, 309, 320, function() SelectAll(false) end)
    Skin.Band(dungeonWindow, 94, 1, 18, Skin.line)
    for i = 1, DUNGEONS_PER_PAGE do
        dungeonRows[i] = DungeonCheck(dungeonWindow, -102 - (i - 1) * 28, 322, function(self)
            Dungeons.SetEnabled(self.mapID, not not self:GetChecked())
            Overlay.Refresh()
        end)
    end
    dungeonPageText = Skin.Text(dungeonWindow, "GameFontHighlightSmall", 176, -369, 62, Skin.muted, "CENTER")
    dungeonPrevious = Skin.Button(dungeonWindow, "Previous", 84, 86, 22, function()
        dungeonPage = dungeonPage - 1
        RefreshDungeonRows()
    end)
    dungeonNext = Skin.Button(dungeonWindow, "Next", 84, 244, 22, function()
        dungeonPage = dungeonPage + 1
        RefreshDungeonRows()
    end)
end

local function ToggleDungeonWindow()
    if not dungeonWindow then CreateDungeonWindow() end
    if dungeonWindow:IsShown() then
        dungeonWindow:Hide()
    else
        dungeonEntries = Dungeons.List()
        RefreshDungeonRows()
        dungeonWindow:Show()
    end
end

local function RefreshOptions()
    if not options or not options:IsShown() then return end
    for _, check in ipairs(checks) do
        check:SetChecked(check.settings[check.settingKey])
    end
    previewButton:SetText(preview and "Finish positioning" or "Preview / move")
    sessionLabel:SetText("Current session  " .. Tracking.character.session)
end

local function Check(label, key, y, settings, refresh)
    local check = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 14, y)
    local text = Skin.Text(check, "GameFontHighlight", 31, -9, 325)
    text:SetText(label)
    check:SetScript("OnClick", function(self)
        settings[key] = not not self:GetChecked()
        refresh()
    end)
    check.settings = settings
    checks[#checks + 1] = check
    check.settingKey = key
end

local function CreateOptions()
    options = Skin.Window("MaraFarmOptions", "MaraFarm  /  Options", 414, 404)
    options:SetFrameStrata("DIALOG")
    Skin.Band(options, 63, 25, 18, Skin.surface)
    Skin.Text(options, "GameFontHighlightSmall", 28, -71, 355, Skin.accent):SetText("Dungeon overlay")
    Skin.Button(options, "Show overlay in dungeons  >", 374, 20, 285, ToggleDungeonWindow, true)
    Check("Show estimated vendor value", "vendor", -121, Overlay.settings, Overlay.Refresh)
    Check("Show estimated hourly lockout count", "lockout", -150, Overlay.settings, Overlay.Refresh)
    Check("Show live run gold per hour", "gph", -179, Overlay.settings, Overlay.Refresh)
    Check("Show minimap button", "enabled", -318, MaraFarm.MapButton.settings, MaraFarm.MapButton.Refresh)

    previewButton = Skin.Button(options, "Preview / move", 152, 20, 159, function()
        preview = not preview
        Overlay.Refresh()
        RefreshOptions()
    end, true)
    Skin.Button(options, "Reset position", 128, 181, 159, function()
        Overlay.settings.x, Overlay.settings.y = nil, nil
        if overlay then Position() end
    end)
    options:SetScript("OnHide", function()
        if dungeonWindow then dungeonWindow:Hide() end
        preview = false
        Overlay.Refresh()
    end)
    options:SetScript("OnShow", RefreshOptions)

    Skin.Band(options, 262, 25, 18, Skin.surface)
    sessionLabel = Skin.Text(options, "GameFontHighlightSmall", 28, -270, 350, Skin.accent)
    local description = Skin.Text(options, "GameFontHighlightSmall", 20, -300, 374, Skin.muted)
    description:SetText("Run history and hourly lockout entries are kept.")
    Skin.Button(options, "Reset session", 128, 20, 18, function()
        StaticPopup_Show("MARAFARM_NEW_SESSION")
    end)
end

StaticPopupDialogs.MARAFARM_NEW_SESSION = {
    text = "Start a new MaraFarm session? The next fresh dungeon copy goes into the new session. Any current run, past runs, and hourly lockouts are kept.",
    button1 = "Start new session",
    button2 = CANCEL,
    timeout = 0,
    hideOnEscape = true,
    whileDead = true,
    OnAccept = function()
        Tracking.NewSession()
        UI.ShowCurrentSession()
        MaraFarm.Dashboard.Refresh()
        RefreshOptions()
    end,
}

function Overlay.ToggleOptions()
    if not options then CreateOptions() end
    options:SetShown(not options:IsShown())
end
