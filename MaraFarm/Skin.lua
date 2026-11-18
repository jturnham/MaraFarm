local _, MaraFarm = ...
local Skin = {}
MaraFarm.Skin = Skin

Skin.ink = { 0.91, 0.94, 0.93 }
Skin.muted = { 0.63, 0.70, 0.70 }
Skin.accent = { 0.49, 0.83, 0.74 }
Skin.gold = { 0.91, 0.78, 0.52 }
Skin.line = { 0.20, 0.29, 0.31, 1 }
Skin.surface = { 0.075, 0.11, 0.13, 1 }
Skin.stripe = { 0.065, 0.092, 0.11, 1 }

local white = "Interface\\Buttons\\WHITE8X8"
local backdrop = { bgFile = white, edgeFile = white, edgeSize = 1 }

function Skin.Fill(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(unpack(color))
    return texture
end

function Skin.Band(parent, top, height, inset, color)
    local texture = Skin.Fill(parent, "BORDER", color)
    texture:SetPoint("TOPLEFT", inset, -top)
    texture:SetPoint("TOPRIGHT", -inset, -top)
    texture:SetHeight(height)
    return texture
end

function Skin.Panel(frame, alpha)
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(0.038, 0.060, 0.072, alpha or 0.98)
    frame:SetBackdropBorderColor(unpack(Skin.line))
end

function Skin.Text(parent, template, x, y, width, color, alignment)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH(alignment or "LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(unpack(color or Skin.ink))
    return text
end

function Skin.Button(parent, label, width, x, y, onClick, accent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 26)
    button:SetPoint("BOTTOMLEFT", x, y)

    local normal = Skin.Fill(button, "BACKGROUND", Skin.surface)
    normal:SetAllPoints()
    button:SetNormalTexture(normal)
    local highlight = Skin.Fill(button, "HIGHLIGHT", { 0.41, 0.69, 0.63, 0.20 })
    highlight:SetAllPoints()
    button:SetHighlightTexture(highlight)
    local pressed = Skin.Fill(button, "ARTWORK", { 0.16, 0.27, 0.27, 1 })
    pressed:SetAllPoints()
    button:SetPushedTexture(pressed)
    Skin.Band(button, 25, 1, 0, Skin.line)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetTextColor(unpack(accent and Skin.accent or Skin.ink))
    button:SetFontString(text)
    button:SetText(label)
    button:SetScript("OnEnable", function() text:SetAlpha(1) end)
    button:SetScript("OnDisable", function() text:SetAlpha(0.38) end)
    button:SetScript("OnClick", onClick)
    return button
end

function Skin.Window(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    Skin.Panel(frame)
    Skin.Band(frame, 1, 49, 1, Skin.surface)
    Skin.Band(frame, 50, 1, 1, Skin.line)
    local mark = Skin.Fill(frame, "ARTWORK", Skin.accent)
    mark:SetPoint("TOPLEFT", 18, -15)
    mark:SetSize(3, 20)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -52, 0)
    header:SetHeight(50)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    Skin.Text(header, "GameFontHighlightLarge", 29, -17, width - 85):SetText(title)

    Skin.Button(frame, "Close", 48, width - 62, height - 38, function() frame:Hide() end)
    tinsert(UISpecialFrames, name)
    return frame
end
