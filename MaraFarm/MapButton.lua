local _, MaraFarm = ...
local MapButton = {}
MaraFarm.MapButton = MapButton
local button

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
        button = CreateFrame("Button", "MaraFarmMinimapButton", Minimap, "BackdropTemplate")
        button:SetSize(27, 27)
        button:SetFrameStrata("MEDIUM")
        MaraFarm.Skin.Panel(button)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetTextColor(unpack(MaraFarm.Skin.accent))
        label:SetText("MF")
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
