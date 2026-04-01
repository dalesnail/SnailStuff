local _, ns = ...
local SnailStuff = ns.SnailStuff

local Data = ns.TalentPlannerData
local UI = ns.TalentPlannerUI

local module

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

local function SetBooleanSetting(key, value)
    local settings = module:GetSettings()
    if not settings or settings[key] == value then
        return
    end

    settings[key] = value and true or false
    module:Refresh()
end

module = SnailStuff:CreateModule("TalentPlanner", {
    displayName = "Talent Planner",
    description = "A separate faux planner window for experimenting with class talent builds without touching real talents.",
    order = 10,
    defaults = {
        enabled = true,
        showPlannerButton = true,
        windowScale = 1.0,
        windowPoint = nil,
        windowRelativePoint = nil,
        windowX = nil,
        windowY = nil,
    },
    page = {
        key = "extras",
        title = "Extras",
        subtitle = "Small optional quality-of-life features that stay separate from the main Blizzard UI modules.",
        order = 40,
        build = function(page)
            local section = page:CreateSection("Talent Planner", "")
            section:SetHeight(130)
            page:AnchorFlow(section, 12)
            section.description:Hide()
            section.contentArea:ClearAllPoints()
            section.contentArea:SetPoint("TOPLEFT", section.separator, "BOTTOMLEFT", 0, -10)
            section.contentArea:SetPoint("TOPRIGHT", section.separator, "BOTTOMRIGHT", 0, -10)
            section.contentArea:SetHeight(1)

            local enabledRow = page:CreateCheckbox("Enable Talent Planner", "")
            CompactCheckboxRow(enabledRow)
            AttachControlTooltip(enabledRow, "Enable Talent Planner", "Turns the separate faux planner feature on or off.")
            page:AnchorSectionControl(section, enabledRow)
            enabledRow.check:SetScript("OnClick", function(check)
                SnailStuff:SetModuleEnabled(module.moduleName, check:GetChecked())
            end)

            local buttonRow = page:CreateCheckbox("Show Planner Button on Talent Frame", "")
            CompactCheckboxRow(buttonRow)
            AttachControlTooltip(buttonRow, "Show Planner Button on Talent Frame", "Shows an independent temporary Planner button beside the talent tabs.")
            page:AnchorSectionControl(section, buttonRow, enabledRow, 6)
            buttonRow.check:SetScript("OnClick", function(check)
                SetBooleanSetting("showPlannerButton", check:GetChecked())
            end)

            page:FinalizeFlow(16)

            page.RefreshControls = function()
                local settings = module:GetSettings()
                if not settings then
                    return
                end

                enabledRow.check:SetChecked(settings.enabled ~= false)
                buttonRow.check:SetChecked(settings.showPlannerButton ~= false)
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
end

function module:ShouldShowPlannerButton()
    local settings = self:GetSettings()
    return self:IsOperationalEnabled()
        and settings
        and settings.showPlannerButton ~= false
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
        plannerButton = nil,
        hooksInstalled = false,
        hookedFrame = nil,
        updateHookInstalled = false,
    }
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

function module:GetLastTalentTab(frame)
    frame = frame or self:GetPlayerTalentFrame()
    if not frame then
        return nil
    end

    local lastShown
    for index = 1, 8 do
        local tab = _G["PlayerTalentFrameTab" .. index]
        if tab and tab:IsShown() then
            lastShown = tab
        end
    end

    return lastShown
end

function module:EnsurePlannerButton()
    self:EnsureRuntime()
    if self.runtime.plannerButton then
        return self.runtime.plannerButton
    end

    local frame = self:GetPlayerTalentFrame()
    if not frame then
        return nil
    end

    local button = CreateFrame("Button", "SnailStuffPlannerTab", frame, "CharacterFrameTabButtonTemplate")
    button:SetText("Planner")

    PanelTemplates_TabResize(button, 0)
    button:SetID(4)

    local numTabs = PanelTemplates_GetNumTabs and PanelTemplates_GetNumTabs(frame)
    if numTabs then
        PanelTemplates_SetNumTabs(frame, math.max(numTabs, 4))
    end

    button:SetScript("OnClick", function()
        module:OpenPlanner()
    end)
    button:SetFrameStrata(frame:GetFrameStrata())
    button:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    button:SetHitRectInsets(0, 0, 4, 4)
    -- button:SetWidth(76)

    if PanelTemplates_DeselectTab then
        PanelTemplates_DeselectTab(button)
    end

    local text = button.GetFontString and button:GetFontString()
    if text then
        text:SetText("Planner")
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER", 0, 2)
    end

    AttachTooltip(button, "Talent Planner", "Open the build planner")

    self.runtime.plannerButton = button
    return button
end

function module:PositionPlannerButton()
    local button = self.runtime and self.runtime.plannerButton
    local frame = self:GetPlayerTalentFrame()
    if not button or not frame then
        return
    end

    button:ClearAllPoints()
    local lastTab = module:GetLastTalentTab(frame)

    if lastTab then
        button:SetPoint("LEFT", lastTab, "RIGHT", -15, 0)
    else
        button:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 60, 7)
    end
end

function module:RefreshPlannerButton()
    self:EnsureRuntime()
    if not self:EnsureTalentUI() then
        return
    end

    local button = self:EnsurePlannerButton()
    local frame = self:GetPlayerTalentFrame()
    if not button or not frame then
        return
    end

    self:PositionPlannerButton()

    if self:ShouldShowPlannerButton() then
        if button.GetText and button:GetText() ~= "Planner" then
            button:SetText("Planner")
        end
        button:Show()
    else
        button:Hide()
    end
end

function module:OpenPlanner()
    if not self:IsOperationalEnabled() then
        return
    end

    if UI:IsShown() then
        UI:Hide()
    else
        UI:Open()
    end
end

function module:InstallHooks()
    self:EnsureRuntime()
    if self.runtime.hooksInstalled and self.runtime.hookedFrame == self:GetPlayerTalentFrame() then
        return
    end

    if not self:EnsureTalentUI() then
        return
    end

    local frame = self:GetPlayerTalentFrame()
    if not frame then
        return
    end

    if self.runtime.hookedFrame ~= frame then
        frame:HookScript("OnShow", function()
            module:RefreshPlannerButton()
        end)
        frame:HookScript("OnHide", function()
            if module.runtime and module.runtime.plannerButton then
                module.runtime.plannerButton:Hide()
            end
        end)
        self.runtime.hookedFrame = frame
    end

    if not self.runtime.updateHookInstalled and hooksecurefunc then
        hooksecurefunc("PlayerTalentFrame_Update", function()
            module:RefreshPlannerButton()
        end)
        self.runtime.updateHookInstalled = true
    end

    self.runtime.hooksInstalled = true
end

function module:Refresh()
    self:EnsureRuntime()
    Data:GetDraft()
    UI:Initialize(self)
    self:InstallHooks()
    self:RefreshPlannerButton()

    if not self:IsOperationalEnabled() then
        UI:Hide()
    elseif UI.frame and UI.frame:IsShown() then
        UI:Refresh()
    end

    SnailStuff:RefreshConfig()
end

function module:OnInitialize()
    self:EnsureRuntime()
    UI:Initialize(self)
end

function module:OnEnable()
    self:EnsureRuntime()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "Refresh")
    self:Refresh()
end

function module:OnDisable()
    self:UnregisterAllEvents()
    if self.runtime and self.runtime.plannerButton then
        self.runtime.plannerButton:Hide()
    end
    UI:Hide()
end

function module:ADDON_LOADED(_, addonName)
    if addonName ~= "Blizzard_TalentUI" then
        return
    end

    self:InstallHooks()
    self:RefreshPlannerButton()
end
