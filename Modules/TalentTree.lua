local _, ns = ...
local SnailStuff = ns.SnailStuff

local FRAME_HEIGHT_INCREASE = 250
local MIN_FRAME_SCALE = 0.75
local MAX_FRAME_SCALE = 1.50
local DEFAULT_FRAME_SCALE = 1.00
local DRAG_HANDLE_HEIGHT = 28
local RELOAD_POPUP_KEY = "SNAILSTUFF_TALENTTREE_RELOAD_REQUIRED"

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

local function AttachTooltip(frame, title, text)
    if not frame or not title then
        return
    end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(selfFrame)
        GameTooltip:SetOwner(selfFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        if text and text ~= "" then
            GameTooltip:AddLine(text, 0.92, 0.88, 0.80, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function AttachControlTooltip(control, title, text)
    if not control then
        return
    end

    AttachTooltip(control, title, text)
    if control.check then
        AttachTooltip(control.check, title, text)
    end
    if control.label then
        AttachTooltip(control.label, title, text)
    end
    if control.slider then
        AttachTooltip(control.slider, title, text)
    end
end

local function CompactCheckboxRow(row)
    if not row or not row.check or not row.label then
        return
    end

    row:SetHeight(30)
    if row.description then
        row.description:Hide()
    end

    row.check:ClearAllPoints()
    row.check:SetPoint("LEFT", 0, 0)

    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 1)
    row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.label:SetJustifyV("MIDDLE")
end

local function GetSavedPoint(settings)
    if not settings or not settings.point or type(settings.x) ~= "number" or type(settings.y) ~= "number" then
        return nil
    end

    return settings.point, settings.relativePoint or settings.point, settings.x, settings.y
end

local function EnsureReloadPopup()
    if StaticPopupDialogs[RELOAD_POPUP_KEY] then
        return
    end

    StaticPopupDialogs[RELOAD_POPUP_KEY] = {
        text = "Reload UI to apply Improved Talent Tree changes?",
        button1 = "Reload Now",
        button2 = "Later",
        OnAccept = function()
            if ReloadUI then
                ReloadUI()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
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

module = SnailStuff:CreateModule("TalentTree", {
    displayName = "Improved Talent Tree",
    description = "Keeps the Blizzard player talent frame, but adds saved position, per-window scale, and a taller one-tree view.",
    order = 30,
    defaults = {
        enabled = true,
        frameScale = DEFAULT_FRAME_SCALE,
        point = nil,
        relativePoint = nil,
        x = nil,
        y = nil,
        showAllTrees = false,
    },
    page = {
        key = "ui",
        title = "UI",
        subtitle = "UI modules for map, talent, and player-visibility improvements live here.",
        order = 25,
        build = function(page)
            local talentSection = page:CreateSection("Improved Talent Tree", "")
            talentSection:SetHeight(166)
            page:AnchorFlow(talentSection, 12)
            talentSection.description:Hide()
            talentSection.contentArea:ClearAllPoints()
            talentSection.contentArea:SetPoint("TOPLEFT", talentSection.separator, "BOTTOMLEFT", 0, -10)
            talentSection.contentArea:SetPoint("TOPRIGHT", talentSection.separator, "BOTTOMRIGHT", 0, -10)
            talentSection.contentArea:SetHeight(1)

            local enabledRow = page:CreateCheckbox("Improved Talent Tree", "")
            CompactCheckboxRow(enabledRow)
            AttachControlTooltip(enabledRow, "Improved Talent Tree", "Turns the improved Blizzard talent window on or off. Reload required.")
            page:AnchorSectionControl(talentSection, enabledRow)
            enabledRow.check:SetScript("OnClick", function(check)
                local settings = module:GetSettings()
                if not settings then
                    return
                end

                settings.enabled = check:GetChecked() and true or false
                SnailStuff:RefreshConfig()
                module:ShowReloadRequiredPopup()
            end)

            local scaleRow = page:CreateValueSlider("Scale", MIN_FRAME_SCALE, MAX_FRAME_SCALE, 0.05)
            AttachControlTooltip(scaleRow, "Scale", "Adjusts only the player talent window scale.")
            page:AnchorSectionControl(talentSection, scaleRow, enabledRow, 8)
            scaleRow.slider:SetScript("OnValueChanged", function(_, value)
                value = tonumber(string.format("%.2f", value)) or DEFAULT_FRAME_SCALE
                scaleRow:SetDisplayValue(value)
                if page.isRefreshing then
                    return
                end

                SetNumericSetting("frameScale", value)
            end)

            page:FinalizeFlow(16)

            local previousRefresh = page.RefreshControls
            page.RefreshControls = function()
                if previousRefresh then
                    previousRefresh()
                end

                local settings = module:GetSettings()
                if not settings then
                    return
                end

                page.isRefreshing = true
                enabledRow.check:SetChecked(settings.enabled ~= false)
                scaleRow.slider:SetValue(tonumber(settings.frameScale) or DEFAULT_FRAME_SCALE)
                scaleRow:SetDisplayValue(tonumber(settings.frameScale) or DEFAULT_FRAME_SCALE)
                page.isRefreshing = false
            end
        end,
    },
})

function module:GetSettings()
    return SnailStuff:GetModuleSettings(self.moduleName)
end

function module:ShowReloadRequiredPopup()
    EnsureReloadPopup()
    if StaticPopup_Show then
        StaticPopup_Show(RELOAD_POPUP_KEY)
    end
end

function module:IsGloballyEnabled()
    return SnailStuff.db and SnailStuff.db.profile and SnailStuff.db.profile.enabled ~= false
end

function module:IsOperationalEnabled()
    return self:IsEnabled()
        and self:IsGloballyEnabled()
        and self.runtime
        and self.runtime.sessionEnabled == true
end

function module:ClampFrameScale(value)
    return Clamp(tonumber(value) or DEFAULT_FRAME_SCALE, MIN_FRAME_SCALE, MAX_FRAME_SCALE)
end

function module:GetPlayerTalentFrame()
    local frame = _G.PlayerTalentFrame
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then
        return nil
    end

    return frame
end

function module:EnsureRuntime()
    if self.runtime then
        return
    end

    self.runtime = {
        dragHandle = nil,
        hooked = false,
        original = nil,
        sessionEnabled = nil,
    }
end

function module:MigrateLegacySettings()
    local settings = self:GetSettings()
    if not settings then
        return
    end

    settings.width = nil
    settings.height = nil
end

function module:CaptureSessionSettings(force)
    self:EnsureRuntime()
    if not force and self.runtime.sessionEnabled ~= nil then
        return
    end

    local settings = self:GetSettings()
    self.runtime.sessionEnabled = settings and settings.enabled ~= false or false
end

function module:CaptureOriginalState(frame)
    if not frame or self.runtime.original then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    self.runtime.original = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs,
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        scale = frame:GetScale(),
        clampedToScreen = frame.IsClampedToScreen and frame:IsClampedToScreen() or nil,
    }
end

function module:SaveWindowState()
    local settings = self:GetSettings()
    local frame = self:GetPlayerTalentFrame()
    if not settings or not frame then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if point then
        settings.point = point
        settings.relativePoint = relativePoint or point
        settings.x = xOfs or 0
        settings.y = yOfs or 0
    end
end

function module:ApplySavedPosition(frame)
    local settings = self:GetSettings()
    if not settings or not frame then
        return
    end

    local point, relativePoint, x, y = GetSavedPoint(settings)
    if not point then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
end

function module:ApplyWindowScale(frame)
    local settings = self:GetSettings()
    if not settings or not frame then
        return
    end

    frame:SetScale(self:ClampFrameScale(settings.frameScale))
end

function module:ApplyImprovedSize(frame)
    local original = self.runtime and self.runtime.original
    if not frame or not original then
        return
    end

    local targetWidth = original.width or frame:GetWidth()
    local targetHeight = math.max(original.height or frame:GetHeight(), (original.height or 0) + FRAME_HEIGHT_INCREASE)

    frame:SetSize(targetWidth, targetHeight)
end

function module:RestoreOriginalState()
    local frame = self:GetPlayerTalentFrame()
    local original = self.runtime and self.runtime.original
    if not frame or not original then
        return
    end

    frame:SetScale(original.scale or 1)
    frame:SetSize(original.width or frame:GetWidth(), original.height or frame:GetHeight())
    frame:ClearAllPoints()
    if original.point then
        frame:SetPoint(original.point, original.relativeTo or UIParent, original.relativePoint or original.point, original.x or 0, original.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    if original.clampedToScreen ~= nil and frame.SetClampedToScreen then
        frame:SetClampedToScreen(original.clampedToScreen)
    end
end

function module:EnsureDragHandle(frame)
    if not frame then
        return
    end

    if self.runtime.dragHandle and self.runtime.dragHandle:GetParent() == frame then
        return
    end

    local dragHandle = CreateFrame("Button", nil, frame)
    dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -2)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -2)
    dragHandle:SetHeight(DRAG_HANDLE_HEIGHT)
    dragHandle:SetAlpha(0)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        module:SaveWindowState()
    end)

    self.runtime.dragHandle = dragHandle
end

function module:ApplyOperationalState()
    if not self:IsOperationalEnabled() then
        return
    end

    if not self:EnsureTalentUI() then
        return
    end

    local frame = self:GetPlayerTalentFrame()
    if not frame then
        return
    end

    self:CaptureOriginalState(frame)
    self:EnsureDragHandle(frame)

    frame:SetMovable(true)
    if frame.SetResizable then
        frame:SetResizable(false)
    end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end

    self:ApplyImprovedSize(frame)

    -- Small forehead reduction tweak (delayed so Blizzard doesn't override it)
    hooksecurefunc("PlayerTalentFrame_Update", function()
        local frame = module:GetPlayerTalentFrame()
        if not frame or not frame.ScrollFrame then return end
    
        local scrollFrame = frame.ScrollFrame
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -45, 75)
    end)
    self:ApplyWindowScale(frame)
    self:ApplySavedPosition(frame)
end

function module:EnsureTalentUI()
    if self:GetPlayerTalentFrame() then
        return true
    end

    if TalentFrame_LoadUI then
        TalentFrame_LoadUI()
    end

    return self:GetPlayerTalentFrame() ~= nil
end

function module:InstallHooks()
    self:EnsureRuntime()
    if self.runtime.hooked then
        return
    end

    if not self:EnsureTalentUI() then
        return
    end

    local frame = self:GetPlayerTalentFrame()
    if not frame then
        return
    end

    frame:HookScript("OnShow", function()
        module:ApplyOperationalState()
    end)

    frame:HookScript("OnHide", function()
        if module:IsOperationalEnabled() then
            module:SaveWindowState()
        end
    end)

    self.runtime.hooked = true
end

function module:Refresh()
    self:EnsureRuntime()
    self:MigrateLegacySettings()
    self:CaptureSessionSettings(false)
    self:InstallHooks()

    if self:IsOperationalEnabled() then
        self:ApplyOperationalState()
    end

    SnailStuff:RefreshConfig()
end

function module:OnInitialize()
    EnsureReloadPopup()
    self:EnsureRuntime()
    self:MigrateLegacySettings()
    self:CaptureSessionSettings(true)
end

function module:OnEnable()
    self:EnsureRuntime()
    self:MigrateLegacySettings()
    self:CaptureSessionSettings(true)
    self:RegisterEvent("ADDON_LOADED")
    self:Refresh()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    self:RestoreOriginalState()
end

function module:ADDON_LOADED(event, addonName)
    if addonName ~= "Blizzard_TalentUI" then
        return
    end

    self:InstallHooks()
    if self:IsOperationalEnabled() then
        self:ApplyOperationalState()
    end
end
