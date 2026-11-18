local _, MaraFarm = ...
local UI, Tracking = MaraFarm.UI, MaraFarm.Tracking
local Skin = MaraFarm.Skin
local Overlay = {}
MaraFarm.Overlay = Overlay

local overlay, options, title, timer, vendor, lockout, vendorLabel, lockoutLabel, previewButton, sessionLabel
local preview = false
local checks = {}

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

function Overlay.Refresh(clockOnly)
    local settings = Overlay.settings
    local run = Tracking.active
    if not settings or not (preview or (settings.enabled and run)) then
        if overlay then overlay:Hide() end
        return
    end

    if not overlay then CreateOverlay() end
    timer:SetText(preview and "0:08:24" or UI.Duration(Tracking.Duration(run, GetTime())))
    if clockOnly then
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

    overlay:SetHeight(bottom + 4)
    overlay:Show()
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
    options = Skin.Window("MaraFarmOptions", "MaraFarm  /  Options", 414, 375)
    options:SetFrameStrata("DIALOG")
    Skin.Band(options, 63, 25, 18, Skin.surface)
    Skin.Text(options, "GameFontHighlightSmall", 28, -71, 355, Skin.accent):SetText("Dungeon overlay")
    Check("Show overlay in dungeons", "enabled", -92, Overlay.settings, Overlay.Refresh)
    Check("Show estimated vendor value", "vendor", -121, Overlay.settings, Overlay.Refresh)
    Check("Show estimated hourly lockout count", "lockout", -150, Overlay.settings, Overlay.Refresh)
    Check("Show minimap button", "enabled", -289, MaraFarm.MapButton.settings, MaraFarm.MapButton.Refresh)

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
        preview = false
        Overlay.Refresh()
    end)

    Skin.Band(options, 233, 25, 18, Skin.surface)
    sessionLabel = Skin.Text(options, "GameFontHighlightSmall", 28, -241, 350, Skin.accent)
    local description = Skin.Text(options, "GameFontHighlightSmall", 20, -271, 374, Skin.muted)
    description:SetText("Run history and hourly lockout entries are kept.")
    Skin.Button(options, "Reset session", 128, 20, 18, function()
        StaticPopup_Show("MARAFARM_NEW_SESSION")
    end)
end

StaticPopupDialogs.MARAFARM_NEW_SESSION = {
    text = "Start a new MaraFarm session? The next new dungeon run starts the session. Existing runs and hourly lockout entries are kept.",
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
    RefreshOptions()
end
