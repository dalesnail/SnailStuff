local _, ns = ...

local Data = ns.TalentPlannerData
local Logic = ns.TalentPlannerLogic
local UI = {}
ns.TalentPlannerUI = UI

local WINDOW_WIDTH = 1060
local WINDOW_HEIGHT = 782
local TREE_PANEL_WIDTH = 328
local TREE_PANEL_HEIGHT = 677
local TREE_PANEL_GAP = 10
local TREE_START_Y = 34
local TREE_COL_SPACING = 66
local TREE_ROW_SPACING = 66
local TREE_BUTTON_SIZE = 42
local TREE_CONTENT_WIDTH = TREE_PANEL_WIDTH - 2
local TREE_CANVAS_MIN_HEIGHT = 500
local PROFILE_SELECTOR_DROPDOWN_WIDTH = 132
local TOP_ROW_HEIGHT = 34
local TOP_ROW_GAP = 10
local CONNECTOR_BRANCH_TEXTURE = "Interface\\AddOns\\SnailStuff\\Media\\ui-talentbranches.blp"
local CONNECTOR_ARROW_TEXTURE = "Interface\\AddOns\\SnailStuff\\Media\\ui-talentarrows.blp"
local CONNECTOR_BRANCH_SIZE = 32
local CONNECTOR_ARROW_SIZE = 32
local TALENT_BRANCH_TEXTURECOORDS = {
    up = {
        [1] = { 0.12890625, 0.25390625, 0.0, 0.484375 },
        [-1] = { 0.12890625, 0.25390625, 0.515625, 1.0 },
    },
    down = {
        [1] = { 0.0, 0.125, 0.0, 0.484375 },
        [-1] = { 0.0, 0.125, 0.515625, 1.0 },
    },
    left = {
        [1] = { 0.2578125, 0.3828125, 0.0, 0.5 },
        [-1] = { 0.2578125, 0.3828125, 0.5, 1.0 },
    },
    right = {
        [1] = { 0.2578125, 0.3828125, 0.0, 0.5 },
        [-1] = { 0.2578125, 0.3828125, 0.5, 1.0 },
    },
    topright = {
        [1] = { 0.515625, 0.640625, 0.0, 0.5 },
        [-1] = { 0.515625, 0.640625, 0.5, 1.0 },
    },
    topleft = {
        [1] = { 0.640625, 0.515625, 0.0, 0.5 },
        [-1] = { 0.640625, 0.515625, 0.5, 1.0 },
    },
    bottomright = {
        [1] = { 0.38671875, 0.51171875, 0.0, 0.5 },
        [-1] = { 0.38671875, 0.51171875, 0.5, 1.0 },
    },
    bottomleft = {
        [1] = { 0.51171875, 0.38671875, 0.0, 0.5 },
        [-1] = { 0.51171875, 0.38671875, 0.5, 1.0 },
    },
    tdown = {
        [1] = { 0.64453125, 0.76953125, 0.0, 0.5 },
        [-1] = { 0.64453125, 0.76953125, 0.5, 1.0 },
    },
    tup = {
        [1] = { 0.7734375, 0.8984375, 0.0, 0.5 },
        [-1] = { 0.7734375, 0.8984375, 0.5, 1.0 },
    },
}
local TALENT_ARROW_TEXTURECOORDS = {
    top = {
        [1] = { 0.0, 0.5, 0.0, 0.5 },
        [-1] = { 0.0, 0.5, 0.5, 1.0 },
    },
    right = {
        [1] = { 1.0, 0.5, 0.0, 0.5 },
        [-1] = { 1.0, 0.5, 0.5, 1.0 },
    },
    left = {
        [1] = { 0.5, 1.0, 0.0, 0.5 },
        [-1] = { 0.5, 1.0, 0.5, 1.0 },
    },
}
local TREE_BACKGROUND_LEFT_WIDTH = 256
local TREE_BACKGROUND_RIGHT_WIDTH = 44
local TREE_BACKGROUND_TOP_HEIGHT = 256
local TREE_BACKGROUND_BOTTOM_HEIGHT = 128
local TREE_BACKGROUND_TOTAL_WIDTH = TREE_BACKGROUND_LEFT_WIDTH + TREE_BACKGROUND_RIGHT_WIDTH
local TREE_BACKGROUND_TOTAL_HEIGHT = TREE_BACKGROUND_TOP_HEIGHT + 75

local TREE_BACKGROUND_RIGHT_CROP = 0.0
local TREE_BACKGROUND_BOTTOM_CROP = 0.0

local COLORS = {
    gold = { 1.00, 0.82, 0.00 },
    goldDim = { 0.94, 0.80, 0.34 },
    section = { 0.98, 0.92, 0.78 },
    text = { 0.92, 0.88, 0.80 },
    muted = { 0.72, 0.68, 0.60 },
    border = { 0.70, 0.62, 0.45, 0.16 },
    panelBg = { 0.00, 0.00, 0.00, 0.22 },
    panelTop = { 0.18, 0.17, 0.14, 0.12 },
    panelBottom = { 0.00, 0.00, 0.00, 0.20 },
    separator = { 0.90, 0.78, 0.48, 0.16 },
}

local FONT_STYLES = {
    pageTitle = { template = "GameFontNormalLarge", size = 20, color = COLORS.gold, shadow = 0.95 },
    sectionTitle = { template = "GameFontNormal", size = 14, color = COLORS.section, shadow = 0.75 },
    body = { template = "GameFontHighlight", size = 13, color = COLORS.text, shadow = 0.45 },
    bodySmall = { template = "GameFontHighlightSmall", size = 12, color = COLORS.text, shadow = 0.35 },
}

local BORDER_COLORS = {
    spent = { 0.90, 0.72, 0.18, 1.0 },
    available = { 0.0, 0.0, 0.0, 1.0 },
    blocked = { 0.0, 0.0, 0.0, 1.0 },
}
local WARRIOR_TREE_BACKGROUNDS = {
    [1] = "WarriorArms",
    [2] = "WarriorFury",
    [3] = "WarriorProtection",
}

local function GetBackdropTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function AtlasExists(atlas)
    if not atlas then
        return false
    end

    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(atlas) ~= nil
    end

    if GetAtlasInfo then
        return GetAtlasInfo(atlas) ~= nil
    end

    return false
end

local function ApplyTextStyle(fontString, style)
    if not (fontString and style) then
        return
    end

    if style.template and _G[style.template] then
        fontString:SetFontObject(_G[style.template])
    end

    if style.size then
        local fontPath, _, flags = fontString:GetFont()
        if fontPath then
            fontString:SetFont(fontPath, style.size, flags)
        end
    end

    if style.color then
        fontString:SetTextColor(style.color[1], style.color[2], style.color[3], style.color[4] or 1)
    end

    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, style.shadow or 0.65)
end

local function CreateText(parent, style, text)
    local fontString = parent:CreateFontString(nil, "ARTWORK", style.template or "GameFontHighlight")
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetText(text or "")
    ApplyTextStyle(fontString, style)
    return fontString
end

local function CreateSeparator(parent, anchor, yOffset)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetColorTexture(COLORS.separator[1], COLORS.separator[2], COLORS.separator[3], COLORS.separator[4])
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -10)
    line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, yOffset or -10)
    line:SetHeight(1)
    return line
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent, GetBackdropTemplate())
    if panel.SetBackdrop then
        panel:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        panel:SetBackdropBorderColor(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
    end

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    panel.bg:SetVertexColor(COLORS.panelBg[1], COLORS.panelBg[2], COLORS.panelBg[3], COLORS.panelBg[4])

    panel.topShade = panel:CreateTexture(nil, "BORDER")
    panel.topShade:SetPoint("TOPLEFT", 1, -1)
    panel.topShade:SetPoint("TOPRIGHT", -1, -1)
    panel.topShade:SetHeight(54)
    panel.topShade:SetTexture("Interface\\Buttons\\WHITE8x8")
    panel.topShade:SetVertexColor(COLORS.panelTop[1], COLORS.panelTop[2], COLORS.panelTop[3], COLORS.panelTop[4])

    panel.bottomShade = panel:CreateTexture(nil, "ARTWORK")
    panel.bottomShade:SetPoint("BOTTOMLEFT", 1, 1)
    panel.bottomShade:SetPoint("BOTTOMRIGHT", -1, 1)
    panel.bottomShade:SetHeight(62)
    panel.bottomShade:SetTexture("Interface\\Buttons\\WHITE8x8")
    panel.bottomShade:SetVertexColor(COLORS.panelBottom[1], COLORS.panelBottom[2], COLORS.panelBottom[3], COLORS.panelBottom[4])

    panel.innerLine = panel:CreateTexture(nil, "OVERLAY")
    panel.innerLine:SetPoint("TOPLEFT", 1, -1)
    panel.innerLine:SetPoint("TOPRIGHT", -1, -1)
    panel.innerLine:SetHeight(1)
    panel.innerLine:SetColorTexture(1, 0.88, 0.60, 0.03)

    return panel
end

local function StyleDropdown(dropdown, width)
    UIDropDownMenu_SetWidth(dropdown, width or PROFILE_SELECTOR_DROPDOWN_WIDTH)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local name = dropdown and dropdown:GetName()
    if not name then
        return
    end

    local left = _G[name .. "Left"]
    local middle = _G[name .. "Middle"]
    local right = _G[name .. "Right"]
    local text = _G[name .. "Text"]

    if left then
        left:SetAlpha(1)
    end
    if middle then
        middle:SetAlpha(1)
    end
    if right then
        right:SetAlpha(1)
    end

    if text then
        ApplyTextStyle(text, FONT_STYLES.bodySmall)
    end
end

function UI:Initialize(module)
    if self.module then
        return
    end

    self.module = module
end

function UI:GetSettings()
    return self.module and self.module:GetSettings() or nil
end

function UI:GetDraft()
    return Data:GetDraft()
end

function UI:GetCurrentClassToken()
    return Data:GetClassToken()
end

function UI:GetCurrentProfiles()
    return Data:GetProfiles(self:GetCurrentClassToken())
end

function UI:UpdateDeleteButtonState()
    local frame = self.frame
    if not (frame and frame.deleteButton) then
        return
    end

    if self.selectedProfileName then
        frame.deleteButton:Enable()
    else
        frame.deleteButton:Disable()
    end
end

function UI:SetSelectedProfile(profileName)
    local frame = self.frame
    if not frame then
        return
    end

    if profileName then
        local profile = Data:GetProfileByName(self:GetCurrentClassToken(), profileName)
        if profile then
            self.selectedProfileName = profile.name
            if frame.profileSelector then
                UIDropDownMenu_SetSelectedValue(frame.profileSelector, profile.name)
                UIDropDownMenu_SetText(frame.profileSelector, profile.name)
            end
            self:UpdateDeleteButtonState()
            return
        end
    end

    self.selectedProfileName = nil
    if frame.profileSelector then
        UIDropDownMenu_SetSelectedValue(frame.profileSelector, "__draft__")
        UIDropDownMenu_SetText(frame.profileSelector, "Unsaved Draft")
    end
    self:UpdateDeleteButtonState()
end

function UI:HideProfileSelector()
    CloseDropDownMenus()
end

function UI:ShowMessage(text)
    if not text or text == "" then
        return
    end

    if self.module and self.module.PrintMessage then
        self.module:PrintMessage(text)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function UI:HideSaveNameInput()
    local frame = self.frame
    if not frame or not frame.saveNamePanel then
        return
    end

    frame.saveNamePanel:Hide()
    if frame.saveNameInputBox then
        frame.saveNameInputBox:ClearFocus()
    end
end

function UI:HideDeleteConfirm()
    local frame = self.frame
    if frame and frame.deleteConfirmPanel then
        frame.deleteConfirmPanel:Hide()
    end
end

function UI:ShowSaveNameInput()
    local frame = self:EnsureFrame()
    if not frame or not frame.saveNamePanel or not frame.saveNameInputBox then
        return
    end

    self:HideDeleteConfirm()
    self:HideProfileSelector()
    frame.saveNamePanel:Show()
    frame.saveNameInputBox:SetText(self.selectedProfileName or "")
    frame.saveNameInputBox:SetFocus()
    frame.saveNameInputBox:HighlightText()
end

function UI:ConfirmSaveNameInput()
    local frame = self.frame
    if not frame or not frame.saveNameInputBox then
        return
    end

    self:ConfirmSaveProfile(frame.saveNameInputBox:GetText() or "")
end

function UI:PromptDeleteProfile()
    local frame = self:EnsureFrame()
    local profileName = self.selectedProfileName
    if not profileName then
        self:ShowMessage("Select a saved profile to delete.")
        return
    end

    if not frame or not frame.deleteConfirmPanel or not frame.deleteConfirmText then
        return
    end

    self:HideSaveNameInput()
    self:HideProfileSelector()
    frame.deleteConfirmText:SetText(string.format("Delete profile \"%s\"?", profileName))
    frame.deleteConfirmPanel:Show()
end

function UI:ConfirmDeleteProfile()
    local profileName = self.selectedProfileName
    if not profileName then
        self:HideDeleteConfirm()
        self:ShowMessage("Select a saved profile to delete.")
        return
    end

    local ok, err = Data:DeleteProfile(self:GetCurrentClassToken(), profileName)
    if not ok then
        self:ShowMessage(err or "Unable to delete planner profile.")
        return
    end

    self:HideDeleteConfirm()
    self:RefreshProfileSelectorList()
    self:SetSelectedProfile(nil)
    self:Refresh()
end

function UI:LoadSelectedProfile(profileName)
    if not profileName then
        self:SetSelectedProfile(nil)
        self:HideProfileSelector()
        return
    end

    local draft, profile = Data:LoadProfileIntoDraft(self:GetCurrentClassToken(), profileName)
    if not draft then
        return
    end

    self:SetSelectedProfile(profile.name)
    self:HideProfileSelector()
    self:Refresh()
end

function UI:RefreshProfileSelectorList()
    local frame = self.frame
    local dropdown = frame and frame.profileSelector
    if not dropdown then
        return
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local draftInfo = UIDropDownMenu_CreateInfo()
        draftInfo.text = "Unsaved Draft"
        draftInfo.value = "__draft__"
        draftInfo.checked = (UI.selectedProfileName == nil)
        draftInfo.func = function()
            UI:SetSelectedProfile(nil)
        end
        UIDropDownMenu_AddButton(draftInfo, level)

        for _, profile in ipairs(UI:GetCurrentProfiles()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = profile.name
            info.value = profile.name
            info.checked = (UI.selectedProfileName == profile.name)
            info.func = function()
                UI:LoadSelectedProfile(profile.name)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function UI:SaveWindowPosition()
    local settings = self:GetSettings()
    local frame = self.frame
    if not settings or not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        settings.windowPoint = point
        settings.windowRelativePoint = relativePoint or point
        settings.windowX = x or 0
        settings.windowY = y or 0
    end
end

function UI:ApplyWindowPosition()
    local settings = self:GetSettings()
    local frame = self.frame
    if not settings or not frame then
        return
    end

    frame:SetScale(tonumber(settings.windowScale) or 1)
    frame:ClearAllPoints()

    local point = settings.windowPoint
    local relativePoint = settings.windowRelativePoint
    local x = tonumber(settings.windowX)
    local y = tonumber(settings.windowY)
    if point and relativePoint and x and y then
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function UI:ConfirmSaveProfile(profileName)
    local classToken = self:GetCurrentClassToken()
    local profile, err = Data:SaveProfile(classToken, profileName, self:GetDraft())

    if not profile then
        self:ShowMessage(err or "Unable to save planner profile.")
        if self.frame and self.frame.saveNameInputBox then
            self.frame.saveNameInputBox:SetFocus()
            self.frame.saveNameInputBox:HighlightText()
        end
        return
    end

    self:RefreshProfileSelectorList()
    self:SetSelectedProfile(profile.name)
    self:HideDeleteConfirm()
    self:HideSaveNameInput()
    self:HideProfileSelector()
    self:Refresh()
end

function UI:LoadProfile(profileName)
    self:LoadSelectedProfile(profileName)
end

function UI:ResetDraft()
    Data:ResetDraft()
    self:HideDeleteConfirm()
    self:HideSaveNameInput()
    self:HideProfileSelector()
    self:Refresh()
end

function UI:HandleTalentClick(treeIndex, talentIndex, button)
    local draft = self:GetDraft()
    draft.activeTree = treeIndex

    local changed = false
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            while Logic:AddPoint(treeIndex, talentIndex, draft) do
                changed = true
            end
        else
            changed = Logic:AddPoint(treeIndex, talentIndex, draft)
        end
    elseif button == "RightButton" then
        if IsShiftKeyDown() then
            while Logic:RemovePoint(treeIndex, talentIndex, draft) do
                changed = true
            end
        else
            changed = Logic:RemovePoint(treeIndex, talentIndex, draft)
        end
    end

    if changed then
        self:Refresh()
    end
end

function UI:UpdateTooltip(button)
    local draft = self:GetDraft()
    local info = Logic:GetTalentInfo(button.treeIndex, button.talentIndex)
    if not info then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(info.name or "Talent", 1, 0.82, 0)

    local rank = Logic:GetTalentRank(draft, button.treeIndex, button.talentIndex)
    GameTooltip:AddLine(string.format("Planned Rank: %d/%d", rank, info.maxRank or 0), 0.50, 0.85, 1.00)

    local canAdd, addReason = Logic:CanAddPoint(button.treeIndex, button.talentIndex, draft)
    if rank < (info.maxRank or 0) and not canAdd and addReason and addReason ~= "Planner cap reached." then
        GameTooltip:AddLine(addReason, 1.00, 0.30, 0.30, true)
    end

    GameTooltip:AddLine("Left-click: add point", 0.80, 0.80, 0.80)
    GameTooltip:AddLine("Right-click: remove point", 0.80, 0.80, 0.80)
    GameTooltip:Show()
end

function UI:CreateTalentButton(parent, treeIndex, talentIndex)
    local button = CreateFrame("Button", nil, parent, GetBackdropTemplate())
    button:SetSize(TREE_BUTTON_SIZE, TREE_BUTTON_SIZE)
    button.treeIndex = treeIndex
    button.talentIndex = talentIndex
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
    end

    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0.20, 0.20, 0.24, 1.0)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.rankText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.rankText:SetDrawLayer("OVERLAY", 7)
    button.rankText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
    button.rankText:SetJustifyH("RIGHT")
    button.rankText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.rankText:SetShadowOffset(1, -1)
    button.rankText:SetShadowColor(0, 0, 0, 0.9)

    button:SetScript("OnClick", function(selfButton, mouseButton)
        UI:HandleTalentClick(selfButton.treeIndex, selfButton.talentIndex, mouseButton)
    end)
    button:SetScript("OnEnter", function(selfButton)
        UI:UpdateTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

function UI:GetTreeLayout(treeIndex)
    local maxTier = 1
    local minColumn = 1
    local maxColumn = 1
    local talentCount = Logic:GetTalentCount(treeIndex)

    for talentIndex = 1, talentCount do
        local info = Logic:GetTalentInfo(treeIndex, talentIndex)
        if info then
            maxTier = math.max(maxTier, tonumber(info.tier) or 1)
            minColumn = math.min(minColumn, tonumber(info.column) or 1)
            maxColumn = math.max(maxColumn, tonumber(info.column) or 1)
        end
    end

    local height = TREE_START_Y + ((maxTier - 1) * TREE_ROW_SPACING) + TREE_BUTTON_SIZE + 24
    local gridWidth = ((maxColumn - minColumn) * TREE_COL_SPACING) + TREE_BUTTON_SIZE
    local startX = math.floor((TREE_CONTENT_WIDTH - gridWidth) / 2) - ((minColumn - 1) * TREE_COL_SPACING)

    return {
        canvasWidth = TREE_CONTENT_WIDTH,
        canvasHeight = math.max(TREE_CANVAS_MIN_HEIGHT, height),
        startX = startX,
    }
end

function UI:GetButtonMetrics(column, button)
    local canvas = column and column.canvas
    if not (canvas and button and button:IsShown() and canvas:GetLeft() and canvas:GetTop()) then
        return nil
    end

    local left = button:GetLeft()
    local right = button:GetRight()
    local top = button:GetTop()
    local bottom = button:GetBottom()
    if not (left and right and top and bottom) then
        return nil
    end

    local centerX = (left + right) / 2
    local centerY = (top + bottom) / 2

    local relCenterX = centerX - canvas:GetLeft()
    local relCenterY = canvas:GetTop() - centerY
    local half = TREE_BUTTON_SIZE / 2

    return {
        centerX = relCenterX,
        centerY = relCenterY,
        left = relCenterX - half,
        right = relCenterX + half,
        top = relCenterY - half,
        bottom = relCenterY + half,
    }
end

function UI:CreateConnector(parent)
    local connector = CreateFrame("Frame", nil, parent)
    connector.branchPieces = {}
    connector.arrow = parent:CreateTexture(nil, "ARTWORK")

    connector.arrow:SetTexture(CONNECTOR_ARROW_TEXTURE)
    connector.arrow:SetVertexColor(1, 1, 1, 1)
    connector.arrow:SetBlendMode("BLEND")
    connector.arrow:SetTexCoord(0, 1, 0, 1)
    connector.arrow:Hide()

    return connector
end

function UI:GetConnectorPiece(connector, index)
    local piece = connector.branchPieces[index]
    if piece then
        return piece
    end

    piece = connector:GetParent():CreateTexture(nil, "ARTWORK")
    piece:SetTexture(CONNECTOR_BRANCH_TEXTURE)
    piece:SetVertexColor(1, 1, 1, 1)
    piece:SetBlendMode("BLEND")
    piece:SetTexCoord(0, 1, 0, 1)
    piece:Hide()

    connector.branchPieces[index] = piece
    return piece
end

function UI:HideConnector(connector)
    if not connector then
        return
    end

    if connector.arrow then
        connector.arrow:Hide()
    end

    if connector.branchPieces then
        for i = 1, #connector.branchPieces do
            connector.branchPieces[i]:Hide()
        end
    end
end

function UI:ApplyConnectorAppearance(texture, key, active, isArrow)
    local state = active and 1 or -1
    local coords

    if isArrow then
        coords = TALENT_ARROW_TEXTURECOORDS[key] and TALENT_ARROW_TEXTURECOORDS[key][state]
        texture:SetTexture(CONNECTOR_ARROW_TEXTURE)
    else
        coords = TALENT_BRANCH_TEXTURECOORDS[key] and TALENT_BRANCH_TEXTURECOORDS[key][state]
        texture:SetTexture(CONNECTOR_BRANCH_TEXTURE)
    end

    if coords then
        texture:SetTexCoord(unpack(coords))
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end

    texture:SetVertexColor(1, 1, 1, 1)
end

function UI:SetConnectorPiece(column, texture, x, y, key, active, isArrow, width, height)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", column.canvas, "TOPLEFT", x, -y)
    texture:SetSize(width or (isArrow and CONNECTOR_ARROW_SIZE or CONNECTOR_BRANCH_SIZE), height or (isArrow and CONNECTOR_ARROW_SIZE or CONNECTOR_BRANCH_SIZE))
    self:ApplyConnectorAppearance(texture, key, active, isArrow)
    texture:Show()
end

function UI:DrawConnectorRun(column, connector, startPos, endPos, fixedPos, isVertical, key, active, pieceIndex)
    local piece = self:GetConnectorPiece(connector, pieceIndex)
    local distance = math.abs(endPos - startPos)
    local centerPos = (startPos + endPos) / 2

    if isVertical then
        self:SetConnectorPiece(
            column,
            piece,
            fixedPos,
            centerPos,
            key,
            active,
            false,
            CONNECTOR_BRANCH_SIZE,
            math.max(1, distance)
        )
    else
        self:SetConnectorPiece(
            column,
            piece,
            centerPos,
            fixedPos,
            key,
            active,
            false,
            math.max(1, distance),
            CONNECTOR_BRANCH_SIZE
        )
    end

    return pieceIndex + 1
end

function UI:DrawPrereqConnector(column, connector, startMetrics, endMetrics, active)
    self:HideConnector(connector)

    if not (startMetrics and endMetrics) then
        return
    end

    local pieceIndex = 1
    local dx = endMetrics.centerX - startMetrics.centerX
    local dy = endMetrics.centerY - startMetrics.centerY

    if math.abs(dx) < 5 then
        local arrowY = endMetrics.top - 3
        local branchEndY = arrowY - 3

        pieceIndex = self:DrawConnectorRun(
            column,
            connector,
            startMetrics.bottom,
            branchEndY,
            startMetrics.centerX,
            true,
            "down",
            active,
            pieceIndex
        )

        self:SetConnectorPiece(
            column,
            connector.arrow,
            endMetrics.centerX,
            arrowY,
            "top",
            active,
            true
        )
        return
    end

    if math.abs(dy) < 5 then
        local arrowKey = dx > 0 and "right" or "left"
        local arrowX = dx > 0 and (endMetrics.left - 3) or (endMetrics.right + 3)
        local branchEndX = arrowX + (dx > 0 and -3 or 3)

        pieceIndex = self:DrawConnectorRun(
            column,
            connector,
            startMetrics.centerX,
            branchEndX,
            startMetrics.centerY,
            false,
            "right",
            active,
            pieceIndex
        )

        self:SetConnectorPiece(
            column,
            connector.arrow,
            arrowX,
            endMetrics.centerY,
            arrowKey,
            active,
            true
        )
        return
    end

    local arrowKey
    local arrowX
    local arrowY = endMetrics.centerY
    local horizontalEnd
    local cornerKey

    if dx > 0 then
        arrowKey = "right"
        arrowX = endMetrics.left - 3
        horizontalEnd = arrowX - 3
        cornerKey = "topright"
    else
        arrowKey = "left"
        arrowX = endMetrics.right + 3
        horizontalEnd = arrowX + 3
        cornerKey = "topleft"
    end

    pieceIndex = self:DrawConnectorRun(
        column,
        connector,
        startMetrics.bottom,
        endMetrics.centerY,
        startMetrics.centerX,
        true,
        "down",
        active,
        pieceIndex
    )

    local elbow = self:GetConnectorPiece(connector, pieceIndex)
    self:SetConnectorPiece(
        column,
        elbow,
        startMetrics.centerX,
        endMetrics.centerY,
        cornerKey,
        active,
        false
    )
    pieceIndex = pieceIndex + 1

    pieceIndex = self:DrawConnectorRun(
        column,
        connector,
        startMetrics.centerX,
        horizontalEnd,
        endMetrics.centerY,
        false,
        "right",
        active,
        pieceIndex
    )

    self:SetConnectorPiece(
        column,
        connector.arrow,
        arrowX,
        arrowY,
        arrowKey,
        active,
        true
    )
end

function UI:CreateTreeColumn(parent, treeIndex)
    local column = CreatePanel(parent)
    column:SetSize(TREE_PANEL_WIDTH, TREE_PANEL_HEIGHT)

    column.treeName = CreateText(column, FONT_STYLES.sectionTitle, "")
    column.treeName:SetPoint("TOPLEFT", column, "TOPLEFT", 14, -12)
    column.treeName:SetPoint("RIGHT", column, "RIGHT", -90, 0)

    column.treePoints = CreateText(column, FONT_STYLES.bodySmall, "")
    column.treePoints:SetPoint("TOPRIGHT", column, "TOPRIGHT", -14, -14)
    column.treePoints:SetJustifyH("RIGHT")

    column.headerLine = CreateSeparator(column, column.treeName, -10)

    column.content = CreateFrame("Frame", nil, column)
    column.content:SetPoint("TOPLEFT", column, "TOPLEFT", 1, -37)
    column.content:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 14, 1)
    column.content:SetClipsChildren(true)

    column.backgroundHost = CreateFrame("Frame", nil, column.content)

    column.backgroundHost:ClearAllPoints()
    column.backgroundHost:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, 0)
    column.backgroundHost:SetPoint("BOTTOMRIGHT", column.content, "BOTTOMRIGHT", 0, 0)

    column.backgroundHost:SetClipsChildren(true)

    column.bgTopLeft = column.backgroundHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    column.bgTopRight = column.backgroundHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    column.bgBottomLeft = column.backgroundHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    column.bgBottomRight = column.backgroundHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    column.fallbackBackground = column.backgroundHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    column.fallbackBackground:SetAllPoints(column.backgroundHost)
    column.fallbackBackground:SetTexture("Interface\\Buttons\\WHITE8x8")
    column.fallbackBackground:SetVertexColor(0.14, 0.14, 0.15, 0.36)

    column.canvas = CreateFrame("Frame", nil, column.content)
    column.canvas:SetPoint("TOPLEFT", column.content, "TOPLEFT", 0, 0)
    column.canvas:SetSize(TREE_CONTENT_WIDTH, TREE_CANVAS_MIN_HEIGHT)
    column.canvas:SetFrameLevel(column.backgroundHost:GetFrameLevel() + 10)

    column.talentButtons = {}
    column.prereqConnectors = {}
    column.treeIndex = treeIndex
    return column
end

function UI:LayoutTreeBackgroundFill(column, texturePrefix)
    if not (column and column.backgroundHost) then
        return
    end

    local target = column.backgroundHost
    local width = math.max(1, target:GetWidth() or 1)
    local height = math.max(1, target:GetHeight() or 1)
    local widthScale = width / TREE_BACKGROUND_TOTAL_WIDTH
    local heightScale = height / TREE_BACKGROUND_TOTAL_HEIGHT
    local leftWidth = widthScale * TREE_BACKGROUND_LEFT_WIDTH
    local rightWidth = widthScale * TREE_BACKGROUND_RIGHT_WIDTH
    local topHeight = heightScale * TREE_BACKGROUND_TOP_HEIGHT
    local bottomHeight = heightScale * TREE_BACKGROUND_BOTTOM_HEIGHT

    column.bgTopLeft:ClearAllPoints()
    column.bgTopLeft:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    column.bgTopLeft:SetSize(leftWidth, topHeight)
    column.bgTopLeft:SetTexture(texturePrefix .. "-TopLeft")
    column.bgTopLeft:SetTexCoord(0, 1, 0, 1)
    column.bgTopLeft:Show()

    column.bgTopRight:ClearAllPoints()
    column.bgTopRight:SetPoint("TOPLEFT", column.bgTopLeft, "TOPRIGHT", 0, 0)
    column.bgTopRight:SetSize(rightWidth, topHeight)
    column.bgTopRight:SetTexture(texturePrefix .. "-TopRight")
    column.bgTopRight:SetTexCoord(0, 1, 0, 1)
    column.bgTopRight:Show()

    column.bgBottomLeft:ClearAllPoints()
    column.bgBottomLeft:SetPoint("TOPLEFT", column.bgTopLeft, "BOTTOMLEFT", 0, 0)
    column.bgBottomLeft:SetSize(leftWidth, bottomHeight)
    column.bgBottomLeft:SetTexture(texturePrefix .. "-BottomLeft")
    column.bgBottomLeft:SetTexCoord(0, 1, 0, 1)
    column.bgBottomLeft:Show()

    column.bgBottomRight:ClearAllPoints()
    column.bgBottomRight:SetPoint("TOPLEFT", column.bgBottomLeft, "TOPRIGHT", 0, 0)
    column.bgBottomRight:SetSize(rightWidth, bottomHeight)
    column.bgBottomRight:SetTexture(texturePrefix .. "-BottomRight")
    column.bgBottomRight:SetTexCoord(0, 1, 0, 1)
    column.bgBottomRight:Show()
end

function UI:RefreshTreeColumn(treeIndex, draft)
    local frame = self.frame
    local column = frame and frame.treeColumns and frame.treeColumns[treeIndex]
    if not column then
        return
    end

    local tabInfo = Logic:GetTabInfo(treeIndex)
    column:SetShown(tabInfo ~= nil)
    if not tabInfo then
        return
    end

    column.treeName:SetText(tabInfo.name or ("Tree " .. treeIndex))
    column.treePoints:SetText(string.format("%d points", Logic:GetTreePoints(draft, treeIndex)))

    local classToken = self:GetCurrentClassToken()
    local warriorBase = classToken == "WARRIOR" and WARRIOR_TREE_BACKGROUNDS[treeIndex] or nil

    if warriorBase then
        local prefix = "Interface\\TalentFrame\\" .. warriorBase

        if column.bg then
            column.bg:Hide()
        end
        if column.topShade then
            column.topShade:Hide()
        end
        if column.bottomShade then
            column.bottomShade:Hide()
        end

        column.fallbackBackground:Hide()
        self:LayoutTreeBackgroundFill(column, prefix)
    else
        if column.bg then
            column.bg:Show()
        end
        if column.topShade then
            column.topShade:Show()
        end
        if column.bottomShade then
            column.bottomShade:Show()
        end

        column.bgTopLeft:Hide()
        column.bgTopRight:Hide()
        column.bgBottomLeft:Hide()
        column.bgBottomRight:Hide()
        column.fallbackBackground:Show()
    end

    local layout = self:GetTreeLayout(treeIndex)
    column.canvas:SetSize(layout.canvasWidth, layout.canvasHeight)

	local talentCount = Logic:GetTalentCount(treeIndex)
	for talentIndex = 1, talentCount do
		local info = Logic:GetTalentInfo(treeIndex, talentIndex)
		if info then
			local button = column.talentButtons[talentIndex]
			if not button then
				button = self:CreateTalentButton(column.canvas, treeIndex, talentIndex)
				column.talentButtons[talentIndex] = button
			end

			button.treeIndex = treeIndex
			button.talentIndex = talentIndex
			button:Show()
			button.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

			local tier = tonumber(info.tier) or 1
			local columnIndex = tonumber(info.column) or 1
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", column.canvas, "TOPLEFT", layout.startX + ((columnIndex - 1) * TREE_COL_SPACING), -(TREE_START_Y + ((tier - 1) * TREE_ROW_SPACING)))

			local plannedRank = Logic:GetTalentRank(draft, treeIndex, talentIndex)
			local maxRank = tonumber(info.maxRank) or 0
			button.rankText:SetText(string.format("%d/%d", plannedRank, maxRank))

			local canAdd = Logic:CanAddPoint(treeIndex, talentIndex, draft)
			local usable = plannedRank > 0 or canAdd

			if plannedRank > 0 then
				button:SetBackdropBorderColor(BORDER_COLORS.spent[1], BORDER_COLORS.spent[2], BORDER_COLORS.spent[3], BORDER_COLORS.spent[4])
				button.rankText:SetTextColor(1.0, 0.82, 0.24)
				button.icon:SetDesaturated(false)
				button:SetAlpha(1.0)
			elseif usable then
				button:SetBackdropBorderColor(BORDER_COLORS.available[1], BORDER_COLORS.available[2], BORDER_COLORS.available[3], BORDER_COLORS.available[4])
				button.rankText:SetTextColor(0.82, 0.82, 0.82)
				button.icon:SetDesaturated(false)
				button:SetAlpha(0.95)
			else
				button:SetBackdropBorderColor(BORDER_COLORS.blocked[1], BORDER_COLORS.blocked[2], BORDER_COLORS.blocked[3], BORDER_COLORS.blocked[4])
				button.rankText:SetTextColor(0.55, 0.55, 0.55)
				button.icon:SetDesaturated(true)
				button:SetAlpha(0.55)
			end
		end
	end

	for talentIndex = talentCount + 1, #column.talentButtons do
		local button = column.talentButtons[talentIndex]
		if button then
			button:Hide()
		end
	end

    for talentIndex = 1, talentCount do
        local info = Logic:GetTalentInfo(treeIndex, talentIndex)
        local connector = column.prereqConnectors[talentIndex]
        if not connector then
            connector = self:CreateConnector(column.canvas)
            column.prereqConnectors[talentIndex] = connector
        end

        self:HideConnector(connector)

        if info and info.prereqTalent and column.talentButtons[info.prereqTalent] and column.talentButtons[talentIndex] then
            local startMetrics = self:GetButtonMetrics(column, column.talentButtons[info.prereqTalent])
            local endMetrics = self:GetButtonMetrics(column, column.talentButtons[talentIndex])

            if startMetrics and endMetrics then
                local prereqTree = info.prereqTree or treeIndex
                local requiredRank = tonumber(info.prereqRank) or 1
                local prereqMet = Logic:GetTalentRank(draft, prereqTree, info.prereqTalent) >= requiredRank
                local targetRank = Logic:GetTalentRank(draft, treeIndex, talentIndex)
                local canAddTarget = Logic:CanAddPoint(treeIndex, talentIndex, draft)
                local active = prereqMet and (targetRank > 0 or canAddTarget)

                self:DrawPrereqConnector(column, connector, startMetrics, endMetrics, active)
            end
        end
    end

    for talentIndex = talentCount + 1, #column.prereqConnectors do
        local connector = column.prereqConnectors[talentIndex]
        if connector then
            self:HideConnector(connector)
        end
    end
end

function UI:RefreshAllTreeColumns(draft)
    local frame = self.frame
    if not (frame and frame.treeColumns) then
        return
    end

    for treeIndex = 1, Data:GetTreeCount() do
        self:RefreshTreeColumn(treeIndex, draft)
    end
end

function UI:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "SnailStuffTalentPlannerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        UI:SaveWindowPosition()
    end)
    frame:SetScript("OnHide", function()
        UI:SaveWindowPosition()
    end)
    frame:SetScript("OnShow", function()
        UI:ApplyWindowPosition()
        UI:Refresh()
    end)

    if frame.Inset and frame.Inset.Bg then
        frame.Inset.Bg:Hide()
        frame.Inset.Bg:SetAlpha(0)
    end
    if frame.Inset and frame.Inset.NineSlice then
        frame.Inset.NineSlice:Show()
    end
    if frame.NineSlice then
        frame.NineSlice:Show()
    end
    if frame.TitleBg then
        frame.TitleBg:Show()
    end
    if frame.TitleText then
        frame.TitleText:Show()
        frame.TitleText:SetText("Talent Planner")
        frame.TitleText:ClearAllPoints()
        frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -6)
    end

    frame.surfaceHost = CreateFrame("Frame", nil, frame)
    frame.surfaceHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -22)
    frame.surfaceHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)

    frame.surfaceBase = frame.surfaceHost:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.surfaceBase:SetAllPoints(frame.surfaceHost)
    frame.surfaceBase:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceBase:SetVertexColor(0, 0, 0, 0)

    frame.surfaceAtlas = frame.surfaceHost:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.surfaceAtlas:SetAllPoints(frame.surfaceHost)
    frame.surfaceAtlas:SetDrawLayer("ARTWORK", 0)
    if frame.surfaceAtlas.SetAtlas and AtlasExists("auctionhouse-background-index") then
        frame.surfaceAtlas:SetAtlas("auctionhouse-background-index", false)
        frame.surfaceAtlas:SetTexCoord(0, 1, 0, 1)
        frame.surfaceAtlas:SetVertexColor(1, 1, 1, 1)
    else
        frame.surfaceAtlas:SetTexture("Interface\\Buttons\\WHITE8x8")
        frame.surfaceAtlas:SetVertexColor(0.12, 0.12, 0.13, 1)
    end

    frame.surfaceOverlay = frame.surfaceHost:CreateTexture(nil, "BORDER")
    frame.surfaceOverlay:SetAllPoints(frame.surfaceHost)
    frame.surfaceOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceOverlay:SetVertexColor(0, 0, 0, 0.10)

    frame.surfaceTopFade = frame.surfaceHost:CreateTexture(nil, "ARTWORK")
    frame.surfaceTopFade:SetPoint("TOPLEFT", frame.surfaceHost, "TOPLEFT", 0, 0)
    frame.surfaceTopFade:SetPoint("TOPRIGHT", frame.surfaceHost, "TOPRIGHT", 0, 0)
    frame.surfaceTopFade:SetHeight(88)
    frame.surfaceTopFade:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceTopFade:SetVertexColor(0.10, 0.08, 0.04, 0.10)

    frame.surfaceBottomFade = frame.surfaceHost:CreateTexture(nil, "ARTWORK")
    frame.surfaceBottomFade:SetPoint("BOTTOMLEFT", frame.surfaceHost, "BOTTOMLEFT", 0, 0)
    frame.surfaceBottomFade:SetPoint("BOTTOMRIGHT", frame.surfaceHost, "BOTTOMRIGHT", 0, 0)
    frame.surfaceBottomFade:SetHeight(90)
    frame.surfaceBottomFade:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceBottomFade:SetVertexColor(0.00, 0.00, 0.00, 0.16)

    frame.content = CreateFrame("Frame", nil, frame.Inset or frame)
    frame.content:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", 12, -24)
    frame.content:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", -12, 12)

    local treeContainerWidth = (Data:GetTreeCount() * TREE_PANEL_WIDTH) + ((Data:GetTreeCount() - 1) * TREE_PANEL_GAP)

    frame.topRow = CreateFrame("Frame", nil, frame.content)
    frame.topRow:SetPoint("TOP", frame.content, "TOP", 0, -8)
    frame.topRow:SetWidth(treeContainerWidth)
    frame.topRow:SetHeight(TOP_ROW_HEIGHT)

    frame.profileLabel = CreateText(frame.topRow, FONT_STYLES.sectionTitle, "Build:")
    frame.profileLabel:SetPoint("LEFT", frame.topRow, "LEFT", 0, 0)
    frame.profileLabel:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1)

    frame.profileSelector = CreateFrame("Frame", "SnailStuffTalentPlannerProfileDropDown", frame.topRow, "UIDropDownMenuTemplate")
    frame.profileSelector:SetPoint("LEFT", frame.profileLabel, "RIGHT", -12, -2)
    StyleDropdown(frame.profileSelector, PROFILE_SELECTOR_DROPDOWN_WIDTH)

    frame.summaryText = CreateText(frame.topRow, FONT_STYLES.bodySmall, "")
    frame.summaryText:SetPoint("LEFT", frame.profileSelector, "RIGHT", -10, 0)
    frame.summaryText:SetPoint("RIGHT", frame.topRow, "RIGHT", -252, 0)

    frame.saveButton = CreateFrame("Button", nil, frame.topRow, "UIPanelButtonTemplate")
    frame.saveButton:SetSize(72, 22)
    frame.saveButton:SetPoint("RIGHT", frame.topRow, "RIGHT", 0, 0)
    frame.saveButton:SetText("Save")
    frame.saveButton:SetScript("OnClick", function()
        UI:ShowSaveNameInput()
    end)

    frame.resetButton = CreateFrame("Button", nil, frame.topRow, "UIPanelButtonTemplate")
    frame.resetButton:SetSize(72, 22)
    frame.resetButton:SetPoint("RIGHT", frame.saveButton, "LEFT", -6, 0)
    frame.resetButton:SetText("Reset")
    frame.resetButton:SetScript("OnClick", function()
        UI:ResetDraft()
    end)

    frame.deleteButton = CreateFrame("Button", nil, frame.topRow, "UIPanelButtonTemplate")
    frame.deleteButton:SetSize(72, 22)
    frame.deleteButton:SetPoint("RIGHT", frame.resetButton, "LEFT", -6, 0)
    frame.deleteButton:SetText("Delete")
    frame.deleteButton:SetScript("OnClick", function()
        UI:PromptDeleteProfile()
    end)

    frame.treeContainer = CreateFrame("Frame", nil, frame.content)
    frame.treeContainer:SetPoint("TOP", frame.topRow, "BOTTOM", 0, -TOP_ROW_GAP)
    frame.treeContainer:SetSize(treeContainerWidth, TREE_PANEL_HEIGHT)

    frame.treeColumns = {}
    for treeIndex = 1, Data:GetTreeCount() do
        local column = self:CreateTreeColumn(frame.treeContainer, treeIndex)
        if treeIndex == 1 then
            column:SetPoint("TOPLEFT", frame.treeContainer, "TOPLEFT", 0, 0)
        else
            column:SetPoint("TOPLEFT", frame.treeColumns[treeIndex - 1], "TOPRIGHT", TREE_PANEL_GAP, 0)
        end
        frame.treeColumns[treeIndex] = column
    end

    frame.saveNamePanel = CreatePanel(frame.content)
    frame.saveNamePanel:SetPoint("TOPRIGHT", frame.saveButton, "BOTTOMRIGHT", 0, -8)
    frame.saveNamePanel:SetSize(252, 56)
    frame.saveNamePanel:SetFrameStrata("DIALOG")
    frame.saveNamePanel:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.saveNamePanel:Hide()

    frame.saveNameLabel = CreateText(frame.saveNamePanel, FONT_STYLES.bodySmall, "Profile Name")
    frame.saveNameLabel:SetPoint("TOPLEFT", frame.saveNamePanel, "TOPLEFT", 10, -10)

    frame.saveNameInputBox = CreateFrame("EditBox", nil, frame.saveNamePanel, "InputBoxTemplate")
    frame.saveNameInputBox:SetAutoFocus(false)
    frame.saveNameInputBox:SetSize(110, 20)
    frame.saveNameInputBox:SetPoint("TOPLEFT", frame.saveNameLabel, "BOTTOMLEFT", 0, -6)
    frame.saveNameInputBox:SetMaxLetters(40)
    frame.saveNameInputBox:SetScript("OnEnterPressed", function()
        UI:ConfirmSaveNameInput()
    end)
    frame.saveNameInputBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
        UI:HideSaveNameInput()
    end)

    frame.saveNameConfirmButton = CreateFrame("Button", nil, frame.saveNamePanel, "UIPanelButtonTemplate")
    frame.saveNameConfirmButton:SetSize(56, 20)
    frame.saveNameConfirmButton:SetPoint("LEFT", frame.saveNameInputBox, "RIGHT", 8, 0)
    frame.saveNameConfirmButton:SetText("Save")
    frame.saveNameConfirmButton:SetScript("OnClick", function()
        UI:ConfirmSaveNameInput()
    end)

    frame.saveNameCancelButton = CreateFrame("Button", nil, frame.saveNamePanel, "UIPanelButtonTemplate")
    frame.saveNameCancelButton:SetSize(56, 20)
    frame.saveNameCancelButton:SetPoint("LEFT", frame.saveNameConfirmButton, "RIGHT", 6, 0)
    frame.saveNameCancelButton:SetText("Cancel")
    frame.saveNameCancelButton:SetScript("OnClick", function()
        UI:HideSaveNameInput()
    end)

    frame.deleteConfirmPanel = CreatePanel(frame.content)
    frame.deleteConfirmPanel:SetPoint("TOPRIGHT", frame.saveButton, "BOTTOMRIGHT", 0, -8)
    frame.deleteConfirmPanel:SetSize(252, 56)
    frame.deleteConfirmPanel:SetFrameStrata("DIALOG")
    frame.deleteConfirmPanel:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.deleteConfirmPanel:Hide()

    frame.deleteConfirmText = CreateText(frame.deleteConfirmPanel, FONT_STYLES.bodySmall, "")
    frame.deleteConfirmText:SetPoint("TOPLEFT", frame.deleteConfirmPanel, "TOPLEFT", 10, -10)
    frame.deleteConfirmText:SetPoint("TOPRIGHT", frame.deleteConfirmPanel, "TOPRIGHT", -10, -10)

    frame.deleteConfirmButton = CreateFrame("Button", nil, frame.deleteConfirmPanel, "UIPanelButtonTemplate")
    frame.deleteConfirmButton:SetSize(56, 20)
    frame.deleteConfirmButton:SetPoint("BOTTOMRIGHT", frame.deleteConfirmPanel, "BOTTOMRIGHT", -66, 8)
    frame.deleteConfirmButton:SetText("Delete")
    frame.deleteConfirmButton:SetScript("OnClick", function()
        UI:ConfirmDeleteProfile()
    end)

    frame.deleteCancelButton = CreateFrame("Button", nil, frame.deleteConfirmPanel, "UIPanelButtonTemplate")
    frame.deleteCancelButton:SetSize(56, 20)
    frame.deleteCancelButton:SetPoint("LEFT", frame.deleteConfirmButton, "RIGHT", 6, 0)
    frame.deleteCancelButton:SetText("Cancel")
    frame.deleteCancelButton:SetScript("OnClick", function()
        UI:HideDeleteConfirm()
    end)

    self.frame = frame
    self:ApplyWindowPosition()
    self:RefreshProfileSelectorList()
    self:SetSelectedProfile(nil)
    return frame
end

function UI:RefreshSummary(draft)
    local frame = self.frame
    if not frame then
        return
    end

    frame.summaryText:SetText(string.format("%d / 61 points", Logic:GetTotalPoints(draft)))
end

function UI:Refresh()
    local frame = self:EnsureFrame()
    if not frame:IsShown() then
        return
    end

    local draft = self:GetDraft()
    draft = Data:EnsureDraftShape(draft)

    self:RefreshProfileSelectorList()
    self:SetSelectedProfile(self.selectedProfileName)
    self:RefreshSummary(draft)
    self:RefreshAllTreeColumns(draft)
end

function UI:Open()
    local frame = self:EnsureFrame()
    self:HideProfileSelector()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
end

function UI:Hide()
    if self.frame then
        self:HideProfileSelector()
        self.frame:Hide()
    end
end

function UI:IsShown()
    return self.frame and self.frame:IsShown() or false
end
