local _, MaraFarm = ...
local MapButton = {}
MaraFarm.MapButton = MapButton
local button
local PRINCESS_THERADRAS_DISPLAY_ID = 12292

local function CreatePortrait()
    local outerMask = button:CreateMaskTexture()
    local innerMask = button:CreateMaskTexture()
    local maskPath = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    outerMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    innerMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    outerMask:SetAllPoints(button)
    innerMask:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    innerMask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    local ring = MaraFarm.Skin.Fill(button, "BACKGROUND", MaraFarm.Skin.gold)
    ring:SetAllPoints(button)
    ring:AddMaskTexture(outerMask)
    local backing = MaraFarm.Skin.Fill(button, "BORDER", MaraFarm.Skin.stripe)
    backing:SetAllPoints(innerMask)
    backing:AddMaskTexture(innerMask)

    local portrait = button:CreateTexture(nil, "ARTWORK")
    portrait:SetAllPoints(innerMask)
    SetPortraitTextureFromCreatureDisplayID(portrait, PRINCESS_THERADRAS_DISPLAY_ID)
    portrait:AddMaskTexture(innerMask)
end

local function Place()
    local angle = math.rad(MapButton.settings.angle)
    local radius = Minimap:GetWidth() / 2 + 4
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Drag()
    local mouseX, mouseY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    if centerX and centerY then
        MapButton.settings.angle = math.deg(math.atan2(mouseY / scale - centerY, mouseX / scale - centerX))
        Place()
    end
end

function MapButton.Refresh()
    if not button then
        button = CreateFrame("Button", "MaraFarmMinimapButton", Minimap)
        button:SetSize(27, 27)
        button:SetFrameStrata("MEDIUM")
        CreatePortrait()
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function(self)
            GameTooltip:Hide()
            self:SetScript("OnUpdate", Drag)
        end)
        button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        button:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        button:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                MaraFarm.Dashboard.Toggle("summary")
            else
                MaraFarm.UI.Toggle()
            end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("MaraFarm")
            local now = GetServerTime()
            local count, expires = MaraFarm.Tracking.Hourly(now)
            GameTooltip:AddLine(string.format("Estimated hourly use  %d / 10", count), 1, 1, 1)
            if count < 10 then
                GameTooltip:AddLine("Slot available now", 1, 1, 1)
            elseif expires then
                GameTooltip:AddLine("Earliest expiry in " .. MaraFarm.UI.Duration(expires - now), 1, 1, 1)
            end
            GameTooltip:AddLine("Left-click: Runs  |  Right-click: Summary", 0.7, 0.8, 0.8)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    Place()
    button:SetShown(MapButton.settings.enabled)
end
