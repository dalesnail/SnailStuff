local _, ns = ...
local SnailStuff = ns.SnailStuff

local UPDATE_INTERVAL = 0.10
local MAX_PIN_SEARCH_DEPTH = 4
local FALLBACK_PIN_SIZE = 24
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local GLOW_COLOR = { 1.00, 0.84, 0.24 }
local PING_TEXTURE = "Interface\\Minimap\\Ping\\ping2"
local PING_BUTTON_WIDTH = 52
local PING_BUTTON_HEIGHT = 22
local PING_COLOR = { 1.00, 0.82, 0.20 }
local DEBUG_PREFIX = "|cffd8b34f[SnailStuff:WorldMap:DEBUG]|r "

local module

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function SafeToString(value)
    if value == nil then
        return "nil"
    end

    return tostring(value)
end

local function DebugPrint(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(DEBUG_PREFIX .. SafeToString(message))
        return
    end

    if print then
        print(DEBUG_PREFIX .. SafeToString(message))
    end
end

local function SetBooleanSetting(key, value)
    local settings = module:GetSettings()
    if not settings or settings[key] == value then
        return
    end

    settings[key] = value and true or false
    module:Refresh()
end

local function SetNumericSetting(key, value)
    local settings = module:GetSettings()
    if not settings or type(value) ~= "number" then
        return
    end

    local currentValue = tonumber(settings[key])
    if currentValue and math.abs(currentValue - value) < 0.0001 then
        return
    end

    settings[key] = value
    module:Refresh()
end

module = SnailStuff:CreateModule("WorldMap", {
    displayName = "World Map",
    description = "Adds a configurable glow overlay to make the player marker easier to spot on the world map.",
    order = 20,
    defaults = {
        enabled = true,
        glowEnabled = true,
        glowScale = 1.0,
        glowAlpha = 1.0,
        pingButtonEnabled = true,
        pingSize = 1.0,
        pingDuration = 1.0,
    },
    page = {
        key = "ui",
        title = "UI",
        subtitle = "UI modules for map and player-visibility improvements live here.",
        order = 25,
        build = function(page)
            local worldMapSection = page:CreateSection("World Map", "Highlight your player position on the world map with a simple glow overlay.")
            page:AnchorTopLevel(worldMapSection)
            worldMapSection:SetHeight(430)

            local enabledRow = page:CreateCheckbox("Enable World Map", "Turns the world map glow overlay on or off without clearing saved settings.")
            page:AnchorSectionControl(worldMapSection, enabledRow)
            enabledRow.check:SetScript("OnClick", function(check)
                SnailStuff:SetModuleEnabled(module.moduleName, check:GetChecked())
            end)

            local glowToggle = page:CreateCheckbox("Enable Glow", "Shows the glow overlay at the player marker whenever the marker can be resolved.")
            page:AnchorSectionControl(worldMapSection, glowToggle, enabledRow, 12)
            glowToggle.check:SetScript("OnClick", function(check)
                SetBooleanSetting("glowEnabled", check:GetChecked())
            end)

            local glowScale = page:CreateValueSlider("Glow Scale", 0.5, 2.0, 0.05)
            page:AnchorSectionControl(worldMapSection, glowScale, glowToggle, 14)
            glowScale.slider:SetScript("OnValueChanged", function(_, value)
                value = tonumber(string.format("%.2f", value)) or 1.0
                glowScale:SetDisplayValue(value)
                if page.isRefreshing then
                    return
                end

                SetNumericSetting("glowScale", value)
            end)

            local glowAlpha = page:CreateValueSlider("Glow Alpha", 0.1, 1.0, 0.05)
            page:AnchorSectionControl(worldMapSection, glowAlpha, glowScale, 12)
            glowAlpha.slider:SetScript("OnValueChanged", function(_, value)
                value = tonumber(string.format("%.2f", value)) or 1.0
                glowAlpha:SetDisplayValue(value)
                if page.isRefreshing then
                    return
                end

                SetNumericSetting("glowAlpha", value)
            end)

            local pingToggle = page:CreateCheckbox("Enable Ping Button", "Shows a small world map button that triggers a ping-style highlight at your player marker.")
            page:AnchorSectionControl(worldMapSection, pingToggle, glowAlpha, 14)
            pingToggle.check:SetScript("OnClick", function(check)
                SetBooleanSetting("pingButtonEnabled", check:GetChecked())
            end)

            local pingSize = page:CreateValueSlider("Ping Size", 0.5, 2.0, 0.05)
            page:AnchorSectionControl(worldMapSection, pingSize, pingToggle, 12)
            pingSize.slider:SetScript("OnValueChanged", function(_, value)
                value = tonumber(string.format("%.2f", value)) or 1.0
                pingSize:SetDisplayValue(value)
                if page.isRefreshing then
                    return
                end

                SetNumericSetting("pingSize", value)
            end)

            local pingDuration = page:CreateValueSlider("Ping Duration", 0.25, 3.0, 0.05)
            page:AnchorSectionControl(worldMapSection, pingDuration, pingSize, 12)
            pingDuration.slider:SetScript("OnValueChanged", function(_, value)
                value = tonumber(string.format("%.2f", value)) or 1.0
                pingDuration:SetDisplayValue(value)
                if page.isRefreshing then
                    return
                end

                SetNumericSetting("pingDuration", value)
            end)

            page.content:SetHeight(worldMapSection:GetHeight() + 20)

            page.RefreshControls = function()
                local settings = module:GetSettings()
                if not settings then
                    return
                end

                page.isRefreshing = true
                enabledRow.check:SetChecked(settings.enabled ~= false)
                glowToggle.check:SetChecked(settings.glowEnabled ~= false)
                glowScale.slider:SetValue(settings.glowScale or 1.0)
                glowScale:SetDisplayValue(settings.glowScale or 1.0)
                glowAlpha.slider:SetValue(settings.glowAlpha or 1.0)
                glowAlpha:SetDisplayValue(settings.glowAlpha or 1.0)
                pingToggle.check:SetChecked(settings.pingButtonEnabled ~= false)
                pingSize.slider:SetValue(settings.pingSize or 1.0)
                pingSize:SetDisplayValue(settings.pingSize or 1.0)
                pingDuration.slider:SetValue(settings.pingDuration or 1.0)
                pingDuration:SetDisplayValue(settings.pingDuration or 1.0)
                page.isRefreshing = false
            end
        end,
    },
})

function module:GetSettings()
    return SnailStuff:GetModuleSettings(self.moduleName)
end

function module:IsGloballyEnabled()
    return SnailStuff.db and SnailStuff.db.profile and SnailStuff.db.profile.enabled ~= false
end

function module:IsOperationalEnabled()
    local settings = self:GetSettings()
    return self:IsEnabled()
        and self:IsGloballyEnabled()
        and settings
        and settings.enabled ~= false
        and settings.glowEnabled ~= false
end

function module:IsPingButtonEnabled()
    local settings = self:GetSettings()
    return self:IsEnabled()
        and self:IsGloballyEnabled()
        and settings
        and settings.enabled ~= false
        and settings.pingButtonEnabled ~= false
end

function module:EnsureRuntime()
    if self.runtime then
        return
    end

    self.runtime = {
        glowFrame = nil,
        glowTexture = nil,
        pingButton = nil,
        pingFrame = nil,
        pingTexture = nil,
        pingAnimation = {
            active = false,
            elapsed = 0,
        },
        updateDriver = CreateFrame("Frame"),
        updateElapsed = 0,
        hooksInstalled = false,
        hookedWorldMapFrame = nil,
        hookedScrollContainer = nil,
        resolvedWorldMapFrame = nil,
        resolvedOverlayParent = nil,
        resolvedButtonAnchor = nil,
        resolvedPin = nil,
        lastAnchorMode = nil,
        debugCache = {},
    }

    self.runtime.updateDriver:Hide()
    self.runtime.updateDriver:SetScript("OnUpdate", function(_, elapsed)
        module:OnUpdate(elapsed)
    end)
end

function module:DebugState(key, value)
    self:EnsureRuntime()

    local normalized = SafeToString(value)
    if self.runtime.debugCache[key] == normalized then
        return
    end

    self.runtime.debugCache[key] = normalized
    DebugPrint(normalized)
end

function module:DescribeFrame(frame)
    if not frame then
        return "nil"
    end

    local name = frame.GetName and frame:GetName()
    if name and name ~= "" then
        return name
    end

    local objectType = frame.GetObjectType and frame:GetObjectType()
    if objectType then
        return objectType
    end

    return "frame"
end

function module:IsFrameUsable(frame)
    if not frame then
        return false
    end

    if self.runtime and (frame == self.runtime.glowFrame or frame == self.runtime.pingFrame or frame == self.runtime.pingButton) then
        return false
    end

    if frame.IsForbidden and frame:IsForbidden() then
        return false
    end

    return true
end

function module:IsDrawableFrame(frame)
    if not self:IsFrameUsable(frame) then
        return false
    end

    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    return width > 0 and height > 0
end

function module:FindNamedFrame(frameName)
    if not frameName then
        return nil
    end

    local directFrame = _G and _G[frameName]
    if self:IsFrameUsable(directFrame) then
        return directFrame
    end

    if not EnumerateFrames then
        return nil
    end

    local frame = EnumerateFrames()
    while frame do
        if self:IsFrameUsable(frame) and frame.GetName and frame:GetName() == frameName then
            return frame
        end

        frame = EnumerateFrames(frame)
    end

    return nil
end

function module:GetWorldMapFrame()
    self:EnsureRuntime()

    local worldMapFrame = self.runtime.resolvedWorldMapFrame
    if self:IsFrameUsable(worldMapFrame) then
        return worldMapFrame
    end

    worldMapFrame = self:FindNamedFrame("WorldMapFrame")
    self.runtime.resolvedWorldMapFrame = worldMapFrame

    if worldMapFrame then
        self:DebugState("worldMapFrame", "world map frame resolved: " .. self:DescribeFrame(worldMapFrame))
    else
        self:DebugState("worldMapFrame", "world map frame resolved: failed")
    end

    return worldMapFrame
end

function module:GetCurrentMapID()
    local worldMapFrame = self:GetWorldMapFrame()
    if worldMapFrame and worldMapFrame.GetMapID then
        local mapID = worldMapFrame:GetMapID()
        if mapID then
            return mapID
        end
    end

    if worldMapFrame and worldMapFrame.mapID then
        return worldMapFrame.mapID
    end

    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end

    return nil
end

function module:ResolveOverlayParent()
    self:EnsureRuntime()

    local overlayParent = self.runtime.resolvedOverlayParent
    if self:IsDrawableFrame(overlayParent) then
        return overlayParent
    end

    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then
        self.runtime.resolvedOverlayParent = nil
        self:DebugState("overlayParent", "overlay parent resolved: failed")
        return nil
    end

    local candidates = {
        worldMapFrame.ScrollContainer and worldMapFrame.ScrollContainer.Child,
        worldMapFrame.ScrollContainer and worldMapFrame.ScrollContainer.ScrollChild,
        worldMapFrame.ScrollContainer,
        worldMapFrame.Child,
        worldMapFrame,
    }

    for index = 1, #candidates do
        local candidate = candidates[index]
        if self:IsDrawableFrame(candidate) then
            self.runtime.resolvedOverlayParent = candidate
            self:DebugState("overlayParent", "overlay parent resolved: " .. self:DescribeFrame(candidate))
            return candidate
        end
    end

    self.runtime.resolvedOverlayParent = nil
    self:DebugState("overlayParent", "overlay parent resolved: failed")
    return nil
end

function module:ResolvePingButtonAnchor()
    self:EnsureRuntime()

    local anchor = self.runtime.resolvedButtonAnchor
    if self:IsFrameUsable(anchor) then
        return anchor
    end

    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then
        self.runtime.resolvedButtonAnchor = nil
        return nil
    end

    anchor = worldMapFrame.ScrollContainer or worldMapFrame.BorderFrame or worldMapFrame
    if self:IsFrameUsable(anchor) then
        self.runtime.resolvedButtonAnchor = anchor
        return anchor
    end

    self.runtime.resolvedButtonAnchor = worldMapFrame
    return worldMapFrame
end

function module:EnsureHooks()
    self:EnsureRuntime()

    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then
        return
    end

    if self.runtime.hookedWorldMapFrame ~= worldMapFrame then
        worldMapFrame:HookScript("OnShow", function()
            module:OnWorldMapShown()
        end)
        worldMapFrame:HookScript("OnHide", function()
            module:OnWorldMapHidden()
        end)
        self.runtime.hookedWorldMapFrame = worldMapFrame
    end

    local scrollContainer = worldMapFrame.ScrollContainer
    if scrollContainer and self.runtime.hookedScrollContainer ~= scrollContainer then
        scrollContainer:HookScript("OnSizeChanged", function()
            module:RequestImmediateUpdate()
        end)
        self.runtime.hookedScrollContainer = scrollContainer
    end

    self.runtime.hooksInstalled = true
end

function module:GetMapCanvas()
    return self:ResolveOverlayParent()
end

function module:EnsureGlowFrame(parent)
    self:EnsureRuntime()

    parent = parent or self:ResolveOverlayParent()
    if not parent then
        return nil
    end

    if self.runtime.glowFrame and self.runtime.glowFrame:GetParent() ~= parent then
        self.runtime.glowFrame:SetParent(parent)
    end

    if self.runtime.glowFrame then
        return self.runtime.glowFrame
    end

    local glowFrame = CreateFrame("Frame", nil, parent)
    glowFrame:Hide()
    glowFrame:SetClampedToScreen(false)

    local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
    glowTexture:SetAllPoints()
    glowTexture:SetTexture(GLOW_TEXTURE)
    glowTexture:SetBlendMode("ADD")
    glowTexture:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 1)

    self.runtime.glowFrame = glowFrame
    self.runtime.glowTexture = glowTexture

    return glowFrame
end

function module:PositionPingButton()
    local button = self.runtime and self.runtime.pingButton
    if not button then
        return
    end

    local worldMapFrame = self:GetWorldMapFrame()
    local anchor = self:ResolvePingButtonAnchor()
    if not worldMapFrame or not anchor then
        return
    end

    button:ClearAllPoints()

    if anchor == worldMapFrame then
        button:SetPoint("TOPRIGHT", worldMapFrame, "TOPRIGHT", -48, -32)
        return
    end

    button:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -10, -10)
end

function module:EnsurePingButton()
    self:EnsureRuntime()

    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame then
        return nil
    end

    if self.runtime.pingButton and self.runtime.pingButton:GetParent() ~= worldMapFrame then
        self.runtime.pingButton:SetParent(worldMapFrame)
    end

    if self.runtime.pingButton then
        self:PositionPingButton()
        return self.runtime.pingButton
    end

    local button = CreateFrame("Button", nil, worldMapFrame, "UIPanelButtonTemplate")
    button:SetSize(PING_BUTTON_WIDTH, PING_BUTTON_HEIGHT)
    button:SetText("Ping")
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((worldMapFrame:GetFrameLevel() or 1) + 20)
    button:SetScript("OnClick", function()
        module:TriggerPing()
    end)
    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Player Ping", 1, 0.82, 0)
        GameTooltip:AddLine("Play a ping-style highlight at your current player marker.", 0.92, 0.88, 0.80, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.runtime.pingButton = button
    self:PositionPingButton()
    return button
end

function module:EnsurePingFrame(parent)
    self:EnsureRuntime()

    parent = parent or self:ResolveOverlayParent()
    if not parent then
        return nil
    end

    if self.runtime.pingFrame and self.runtime.pingFrame:GetParent() ~= parent then
        self.runtime.pingFrame:SetParent(parent)
    end

    if self.runtime.pingFrame then
        return self.runtime.pingFrame
    end

    local pingFrame = CreateFrame("Frame", nil, parent)
    pingFrame:Hide()
    pingFrame:SetClampedToScreen(false)

    local pingTexture = pingFrame:CreateTexture(nil, "ARTWORK")
    pingTexture:SetAllPoints()
    pingTexture:SetTexture(PING_TEXTURE)
    pingTexture:SetBlendMode("ADD")
    pingTexture:SetVertexColor(PING_COLOR[1], PING_COLOR[2], PING_COLOR[3], 1)

    self.runtime.pingFrame = pingFrame
    self.runtime.pingTexture = pingTexture
    return pingFrame
end

function module:HideGlow()
    self:EnsureRuntime()

    self.runtime.lastAnchorMode = nil

    if self.runtime.glowFrame then
        self.runtime.glowFrame:Hide()
    end
end

function module:HidePing()
    self:EnsureRuntime()

    self.runtime.pingAnimation.active = false
    self.runtime.pingAnimation.elapsed = 0

    if self.runtime.pingFrame then
        self.runtime.pingFrame:Hide()
    end
end

function module:RefreshPingButton()
    self:EnsureRuntime()
    self:EnsureHooks()

    local button = self:EnsurePingButton()
    local worldMapFrame = self:GetWorldMapFrame()
    if not button or not worldMapFrame then
        self:DebugState("pingButton", "ping button hidden: no world map frame")
        return
    end

    self:PositionPingButton()

    if self:IsPingButtonEnabled() and worldMapFrame:IsShown() then
        button:Show()
        self:DebugState("pingButton", "ping button shown")
    else
        button:Hide()
        self:DebugState("pingButton", "ping button hidden")
    end
end

function module:ShouldTrack()
    local worldMapFrame = self:GetWorldMapFrame()
    return self:IsOperationalEnabled()
        and worldMapFrame
        and worldMapFrame:IsShown()
end

function module:ShouldAnimatePing()
    return self.runtime
        and self.runtime.pingAnimation
        and self.runtime.pingAnimation.active
        and self.runtime.pingFrame
        and self.runtime.pingFrame:IsShown()
end

function module:RefreshTicker()
    self:EnsureRuntime()

    if self:ShouldTrack() or self:ShouldAnimatePing() then
        self.runtime.updateElapsed = UPDATE_INTERVAL
        self.runtime.updateDriver:Show()
    else
        self.runtime.updateDriver:Hide()
        self.runtime.updateElapsed = 0
    end
end

function module:ResetResolvedTargets()
    self:EnsureRuntime()
    self.runtime.resolvedOverlayParent = nil
    self.runtime.resolvedButtonAnchor = nil
    self.runtime.resolvedPin = nil
end

function module:RequestImmediateUpdate()
    self:EnsureRuntime()
    self:EnsureHooks()
    self:ResetResolvedTargets()
    self.runtime.updateElapsed = UPDATE_INTERVAL
    self:UpdateGlow()
    self:RefreshPingButton()
    if not self:IsPingButtonEnabled() or not self:GetWorldMapFrame() or not self:GetWorldMapFrame():IsShown() then
        self:HidePing()
    end
    self:RefreshTicker()
end

function module:OnUpdate(elapsed)
    self:EnsureHooks()

    self.runtime.updateElapsed = self.runtime.updateElapsed + (elapsed or 0)
    if self.runtime.updateElapsed < UPDATE_INTERVAL then
        return
    end

    local tickElapsed = self.runtime.updateElapsed
    self.runtime.updateElapsed = 0
    self:ResetResolvedTargets()
    self:UpdateGlow()
    self:UpdatePingAnimation(tickElapsed)
    self:RefreshPingButton()
end

function module:FrameLooksLikePlayerPin(frame)
    if not self:IsFrameUsable(frame) then
        return false
    end

    if frame.unit == "player" or frame.unitToken == "player" then
        return true
    end

    if frame.GetUnit and frame:GetUnit() == "player" then
        return true
    end

    local playerGUID = UnitGUID and UnitGUID("player")
    if playerGUID and frame.guid == playerGUID then
        return true
    end

    local template = frame.pinTemplate or frame.template or frame.layoutIndex or frame.dataProvider
    if type(template) == "string" and string.find(string.lower(template), "player", 1, true) then
        return true
    end

    local name = frame.GetName and frame:GetName()
    if type(name) == "string" then
        local lowerName = string.lower(name)
        if string.find(lowerName, "player", 1, true) and (string.find(lowerName, "pin", 1, true) or string.find(lowerName, "marker", 1, true)) then
            return true
        end
    end

    return false
end

function module:FindPlayerPin(frame, depth)
    if depth > MAX_PIN_SEARCH_DEPTH or not self:IsFrameUsable(frame) then
        return nil
    end

    if self:FrameLooksLikePlayerPin(frame) then
        return frame
    end

    local children = { frame:GetChildren() }
    for index = 1, #children do
        local child = children[index]
        local playerPin = self:FindPlayerPin(child, depth + 1)
        if playerPin then
            return playerPin
        end
    end

    return nil
end

function module:ResolvePlayerPin()
    self:EnsureRuntime()

    local playerPin = self.runtime.resolvedPin
    if self:FrameLooksLikePlayerPin(playerPin) then
        self:DebugState("playerPin", "player pin resolved: " .. self:DescribeFrame(playerPin))
        return playerPin
    end

    local overlayParent = self:ResolveOverlayParent()
    local worldMapFrame = self:GetWorldMapFrame()
    local searchRoots = {
        overlayParent,
        worldMapFrame and worldMapFrame.ScrollContainer,
        worldMapFrame,
    }

    for index = 1, #searchRoots do
        local root = searchRoots[index]
        if self:IsFrameUsable(root) then
            playerPin = self:FindPlayerPin(root, 0)
            if playerPin then
                self.runtime.resolvedPin = playerPin
                self:DebugState("playerPin", "player pin resolved: " .. self:DescribeFrame(playerPin))
                return playerPin
            end
        end
    end

    self.runtime.resolvedPin = nil
    self:DebugState("playerPin", "player pin resolved: failed")
    return nil
end

function module:ResolvePlayerCoordinates()
    local overlayParent = self:ResolveOverlayParent()
    local mapID = self:GetCurrentMapID()
    if not overlayParent or not mapID then
        self:DebugState("playerCoords", "player coordinates failed")
        return nil
    end

    local x
    local y

    if C_Map and C_Map.GetPlayerMapPosition then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position and position.GetXY then
            x, y = position:GetXY()
        end
    end

    if (type(x) ~= "number" or type(y) ~= "number") and GetPlayerMapPosition then
        x, y = GetPlayerMapPosition("player")
    end

    if type(x) ~= "number" or type(y) ~= "number" then
        self:DebugState("playerCoords", "player coordinates failed")
        return nil
    end

    if x <= 0 or y <= 0 or x > 1 or y > 1 then
        self:DebugState("playerCoords", "player coordinates failed")
        return nil
    end

    local worldMapFrame = self:GetWorldMapFrame()
    local coordinateParent = overlayParent
    if worldMapFrame and worldMapFrame.ScrollContainer then
        local scrollContainer = worldMapFrame.ScrollContainer
        local scrollChild = scrollContainer.Child or scrollContainer.ScrollChild
        if self:IsDrawableFrame(scrollChild) then
            coordinateParent = scrollChild
        elseif self:IsDrawableFrame(scrollContainer) then
            coordinateParent = scrollContainer
        end
    end

    local width = coordinateParent.GetWidth and coordinateParent:GetWidth() or 0
    local height = coordinateParent.GetHeight and coordinateParent:GetHeight() or 0
    if width <= 0 or height <= 0 then
        self:DebugState("playerCoords", "player coordinates failed")
        return nil
    end

    self:DebugState("playerCoords", string.format("player coordinates resolved: map=%s x=%.3f y=%.3f", tostring(mapID), x, y))
    return x, y, coordinateParent
end

function module:GetGlowSize()
    local settings = self:GetSettings()
    local scale = settings and tonumber(settings.glowScale) or 1.0
    scale = Clamp(scale, 0.5, 2.0)

    local pin = self.runtime and self.runtime.resolvedPin
    local baseSize = FALLBACK_PIN_SIZE
    if pin and pin.GetWidth and pin.GetHeight then
        local pinWidth = pin:GetWidth() or 0
        local pinHeight = pin:GetHeight() or 0
        baseSize = math.max(baseSize, pinWidth, pinHeight)
    end

    return baseSize * 2.6 * scale
end

function module:GetPingSize()
    local settings = self:GetSettings()
    local scale = settings and tonumber(settings.pingSize) or 1.0
    scale = Clamp(scale, 0.5, 2.0)

    local pin = self.runtime and self.runtime.resolvedPin
    local baseSize = FALLBACK_PIN_SIZE
    if pin and pin.GetWidth and pin.GetHeight then
        local pinWidth = pin:GetWidth() or 0
        local pinHeight = pin:GetHeight() or 0
        baseSize = math.max(baseSize, pinWidth, pinHeight)
    end

    return baseSize * 3.2 * scale
end

function module:GetPingDuration()
    local settings = self:GetSettings()
    local duration = settings and tonumber(settings.pingDuration) or 1.0
    return Clamp(duration, 0.25, 3.0)
end

function module:ApplyGlowVisuals(frame)
    local settings = self:GetSettings()
    if not frame or not settings or not self.runtime or not self.runtime.glowTexture then
        return
    end

    local alpha = Clamp(tonumber(settings.glowAlpha) or 1.0, 0.1, 1.0)
    local size = self:GetGlowSize()

    frame:SetSize(size, size)
    self.runtime.glowTexture:SetAlpha(alpha)
    self.runtime.glowTexture:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], alpha)
end

function module:ApplyPingVisuals(progress)
    if not self.runtime or not self.runtime.pingFrame or not self.runtime.pingTexture then
        return
    end

    progress = Clamp(progress or 0, 0, 1)

    local startSize = self:GetPingSize() * 0.45
    local endSize = self:GetPingSize()
    local size = startSize + ((endSize - startSize) * progress)
    local alpha = 1 - progress

    self.runtime.pingFrame:SetSize(size, size)
    self.runtime.pingTexture:SetAlpha(alpha)
    self.runtime.pingTexture:SetVertexColor(PING_COLOR[1], PING_COLOR[2], PING_COLOR[3], alpha)
end

function module:AnchorGlowToPin(playerPin)
    local parent = playerPin and playerPin:GetParent()
    local glowFrame = self:EnsureGlowFrame(parent)
    if not glowFrame or not parent then
        self:HideGlow()
        return
    end

    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("CENTER", playerPin, "CENTER", 0, 0)
    glowFrame:SetFrameStrata(playerPin:GetFrameStrata())
    glowFrame:SetFrameLevel(math.max((playerPin:GetFrameLevel() or 1) - 1, 1))

    self.runtime.resolvedPin = playerPin
    self.runtime.lastAnchorMode = "pin"
    self:ApplyGlowVisuals(glowFrame)
    glowFrame:Show()
end

function module:AnchorGlowToPosition(x, y, parent)
    local glowFrame = self:EnsureGlowFrame(parent)
    if not glowFrame or not parent then
        self:HideGlow()
        return
    end

    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("CENTER", parent, "TOPLEFT", x * parent:GetWidth(), -y * parent:GetHeight())
    glowFrame:SetFrameStrata("DIALOG")
    glowFrame:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)

    self.runtime.lastAnchorMode = "position"
    self:ApplyGlowVisuals(glowFrame)
    glowFrame:Show()
end

function module:AnchorPingToPin(playerPin)
    local parent = playerPin and playerPin:GetParent()
    local pingFrame = self:EnsurePingFrame(parent)
    if not pingFrame or not parent then
        self:HidePing()
        return false
    end

    pingFrame:ClearAllPoints()
    pingFrame:SetPoint("CENTER", playerPin, "CENTER", 0, 0)
    pingFrame:SetFrameStrata(playerPin:GetFrameStrata())
    pingFrame:SetFrameLevel((playerPin:GetFrameLevel() or 1) + 1)
    self.runtime.resolvedPin = playerPin
    return true
end

function module:AnchorPingToPosition(x, y, parent)
    local pingFrame = self:EnsurePingFrame(parent)
    if not pingFrame or not parent then
        self:HidePing()
        return false
    end

    pingFrame:ClearAllPoints()
    pingFrame:SetPoint("CENTER", parent, "TOPLEFT", x * parent:GetWidth(), -y * parent:GetHeight())
    pingFrame:SetFrameStrata("DIALOG")
    pingFrame:SetFrameLevel((parent:GetFrameLevel() or 1) + 21)
    return true
end

function module:ResolvePlayerMarker()
    local x, y, parent = self:ResolvePlayerCoordinates()

    if x and y and parent then
        return "position", x, y, parent
    end

    local playerPin = self:ResolvePlayerPin()
    if playerPin then
        return "pin", playerPin
    end

    return nil
end

function module:UpdateGlow()
    self:EnsureRuntime()

    if not self:ShouldTrack() then
        self:HideGlow()
        return
    end

    local anchorMode, value1, value2, value3 = self:ResolvePlayerMarker()
    if anchorMode == "position" then
        self:AnchorGlowToPosition(value1, value2, value3)
        return
    end

    if anchorMode == "pin" then
        self:AnchorGlowToPin(value1)
        return
    end

    self:HideGlow()
end

function module:UpdatePingAnimation(elapsed)
    self:EnsureRuntime()

    if not self:ShouldAnimatePing() then
        return
    end

    local animation = self.runtime.pingAnimation
    animation.elapsed = animation.elapsed + (elapsed or 0)

    local duration = self:GetPingDuration()
    local progress = animation.elapsed / duration
    if progress >= 1 then
        self:HidePing()
        self:RefreshTicker()
        return
    end

    self:ApplyPingVisuals(progress)
end

function module:TriggerPing()
    self:EnsureRuntime()
    self:EnsureHooks()

    if not self:IsPingButtonEnabled() then
        self:HidePing()
        self:RefreshPingButton()
        self:RefreshTicker()
        return false
    end

    local worldMapFrame = self:GetWorldMapFrame()
    if not worldMapFrame or not worldMapFrame:IsShown() then
        self:HidePing()
        self:RefreshTicker()
        return false
    end

    self:ResetResolvedTargets()

    local anchorMode, value1, value2, value3 = self:ResolvePlayerMarker()
    local anchored = false
    if anchorMode == "position" then
        anchored = self:AnchorPingToPosition(value1, value2, value3)
    elseif anchorMode == "pin" then
        anchored = self:AnchorPingToPin(value1)
    end

    if not anchored then
        self:HidePing()
        self:RefreshTicker()
        return false
    end

    self.runtime.pingAnimation.active = true
    self.runtime.pingAnimation.elapsed = 0
    self:ApplyPingVisuals(0)
    self.runtime.pingFrame:Show()
    self:RefreshTicker()
    return true
end

function module:Refresh()
    self:EnsureRuntime()
    self:EnsureHooks()
    self:RefreshTicker()
    self:RequestImmediateUpdate()
    SnailStuff:RefreshConfig()
end

function module:OnInitialize()
    self:EnsureRuntime()
end

function module:OnEnable()
    self:EnsureRuntime()
    self:EnsureHooks()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestImmediateUpdate")
    self:RegisterEvent("ZONE_CHANGED", "RequestImmediateUpdate")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "RequestImmediateUpdate")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "RequestImmediateUpdate")

    self:Refresh()
end

function module:OnDisable()
    self:UnregisterAllEvents()

    if self.runtime then
        self.runtime.updateDriver:Hide()
        self.runtime.updateElapsed = 0
    end

    self:HideGlow()
    self:HidePing()
    self:RefreshPingButton()
end

function module:OnWorldMapShown()
    self:RequestImmediateUpdate()
end

function module:OnWorldMapHidden()
    self:RefreshPingButton()
    self:HideGlow()
    self:HidePing()
    self:RefreshTicker()
end
