local _, MaraFarm = ...
local UI, Tracking = MaraFarm.UI, MaraFarm.Tracking
local Overlay = {}
MaraFarm.Overlay = Overlay

local overlay, options, title, timer, vendor, lockout, previewButton, sessionLabel
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
    overlay:SetSize(265, 95)
    overlay:SetFrameStrata("MEDIUM")
    overlay:SetClampedToScreen(true)
    overlay:SetMovable(true)
    overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    overlay:SetBackdropColor(0.05, 0.06, 0.08, 0.88)
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

    title = UI.Text(overlay, "GameFontNormal", 12, -9, 241)
    timer = UI.Text(overlay, "GameFontHighlight", 12, -29, 241)
    vendor = UI.Text(overlay, "GameFontHighlight", 12, -47, 241)
    lockout = UI.Text(overlay, "GameFontHighlight", 12, -65, 241)

    local elapsed = 0
    overlay:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            Overlay.Refresh()
        end
    end)
    Position()
end

function Overlay.Refresh()
    local settings = Overlay.settings
    local run = Tracking.active
    if not settings or not (preview or (settings.enabled and run)) then
        if overlay then overlay:Hide() end
        return
    end

    if not overlay then CreateOverlay() end
    overlay:EnableMouse(preview)
    overlay:SetFrameStrata(preview and "DIALOG" or "MEDIUM")
    title:SetText(preview and "Preview - drag to move" or run.name)
    timer:SetText("Time inside  " .. (preview and "0:08:24" or UI.Duration(Tracking.Duration(run, GetTime()))))

    local bottom = 47
    vendor:SetShown(settings.vendor)
    if settings.vendor then
        vendor:SetText("Vendor estimate  " .. (preview and "1g 42s 08c" or UI.VendorTotal(run)))
        bottom = bottom + 18
    end

    lockout:SetShown(settings.lockout)
    if settings.lockout then
        lockout:ClearAllPoints()
        lockout:SetPoint("TOPLEFT", 12, -bottom)
        local count = preview and 4 or Tracking.Hourly(GetServerTime())
        lockout:SetText(string.format("Estimated hourly use  %d/10", count))
        bottom = bottom + 18
    end

    overlay:SetHeight(bottom + 4)
    overlay:Show()
end

local function RefreshOptions()
    if not options or not options:IsShown() then return end
    for key, check in pairs(checks) do
        check:SetChecked(Overlay.settings[key])
    end
    previewButton:SetText(preview and "Finish positioning" or "Preview / move")
    sessionLabel:SetText("Current session  " .. Tracking.character.session)
end

local function Check(label, key, y)
    local check = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 14, y)
    local text = UI.Text(check, "GameFontHighlight", 31, -9, 325)
    text:SetText(label)
    check:SetScript("OnClick", function(self)
        Overlay.settings[key] = not not self:GetChecked()
        Overlay.Refresh()
    end)
    checks[key] = check
end

local function CreateOptions()
    options = CreateFrame("Frame", "MaraFarmOptions", UIParent, "BasicFrameTemplateWithInset")
    options:Hide()
    options:SetSize(390, 276)
    options:SetPoint("CENTER")
    options:SetFrameStrata("DIALOG")
    options:SetClampedToScreen(true)
    options:EnableMouse(true)
    options:SetMovable(true)
    options:RegisterForDrag("LeftButton")
    options:SetScript("OnDragStart", options.StartMoving)
    options:SetScript("OnDragStop", options.StopMovingOrSizing)
    options.TitleText:SetText("MaraFarm Options")
    tinsert(UISpecialFrames, options:GetName())

    Check("Show overlay in dungeons", "enabled", -29)
    Check("Show estimated vendor value", "vendor", -58)
    Check("Show estimated hourly lockout count", "lockout", -87)

    previewButton = UI.Button(options, "Preview / move", 152, 20, 123, function()
        preview = not preview
        Overlay.Refresh()
        RefreshOptions()
    end)
    UI.Button(options, "Reset position", 128, 181, 123, function()
        Overlay.settings.x, Overlay.settings.y = nil, nil
        if overlay then Position() end
    end)
    options:SetScript("OnHide", function()
        preview = false
        Overlay.Refresh()
    end)

    sessionLabel = UI.Text(options, "GameFontNormal", 20, -173, 350)
    local description = UI.Text(options, "GameFontHighlightSmall", 20, -194, 350)
    description:SetText("Run history and hourly lockout entries are kept.")
    UI.Button(options, "Reset session", 128, 20, 19, function()
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
        RefreshOptions()
    end,
}

function Overlay.ToggleOptions()
    if not options then CreateOptions() end
    options:SetShown(not options:IsShown())
    RefreshOptions()
end
