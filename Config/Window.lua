local ADDON_NAME, ns = ...
local SnailStuff = ns.SnailStuff

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local WINDOW_MIN_WIDTH = 860
local WINDOW_MIN_HEIGHT = 560
local NAV_WIDTH = 130
local NAV_TOP_PADDING = 18
local PAGE_INSET_X = 8
local PAGE_HEADER_TOP = -22
local PAGE_HEADER_HEIGHT = 58
local WINDOW_RESIZE_OFFSET_X = -6
local WINDOW_RESIZE_OFFSET_Y = 6
local WINDOW_RESIZE_FRAME_LEVEL_OFFSET = 18

local COLORS = {
    gold = { 1.00, 0.82, 0.00 },
    goldDim = { 0.94, 0.80, 0.34 },
    section = { 0.98, 0.92, 0.78 },
    text = { 0.92, 0.88, 0.80 },
    muted = { 0.72, 0.68, 0.60 },
    border = { 0.70, 0.62, 0.45, 0.16 },
    panel = { 0.00, 0.00, 0.00, 0.20 },
    panelHeader = { 0.18, 0.17, 0.14, 0.12 },
    panelFooter = { 0.00, 0.00, 0.00, 0.20 },
    hover = { 0.18, 0.14, 0.08, 0.10 },
    navHover = { 0.22, 0.17, 0.08, 0.34 },
    selected = { 0.22, 0.17, 0.08, 0.58 },
}

local FONT_STYLES = {
    pageTitle = { template = "GameFontNormalLarge", size = 20, color = COLORS.gold, shadow = 0.95 },
    pageSubtitle = { template = "GameFontHighlight", size = 13, color = COLORS.text, shadow = 0.55 },
    sectionTitle = { template = "GameFontNormal", size = 14, color = COLORS.section, shadow = 0.75 },
    body = { template = "GameFontHighlight", size = 13, color = COLORS.text, shadow = 0.45 },
    bodySmall = { template = "GameFontHighlightSmall", size = 12, color = COLORS.text, shadow = 0.35 },
    muted = { template = "GameFontHighlightSmall", size = 12, color = COLORS.muted, shadow = 0.25 },
    value = { template = "GameFontHighlight", size = 12, color = COLORS.text, shadow = 0.55 },
    nav = { template = "GameFontNormalLarge", size = 19, color = { 0.54, 0.54, 0.54 }, shadow = 0.55 },
    navSelected = { template = "GameFontNormalLarge", size = 19, color = COLORS.gold, shadow = 0.85 },
}

local sliderNameIndex = 0

local function GetMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    end

    if GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, field)
    end

    return nil
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

local function StyleText(fontString, fontObject, size, color)
    local shadowAlpha = 0.65
    if type(fontObject) == "table" then
        local style = fontObject
        fontObject = style.template
        size = style.size
        color = style.color
        shadowAlpha = style.shadow or shadowAlpha
    end

    if fontObject and _G[fontObject] then
        fontString:SetFontObject(_G[fontObject])
    end

    if size then
        local fontPath, _, flags = fontString:GetFont()
        if fontPath then
            fontString:SetFont(fontPath, size, flags)
        end
    end

    if color then
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end

    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, shadowAlpha)
end

local function ApplyFontStyle(fontString, style)
    StyleText(fontString, style)
    fontString:SetShadowColor(0, 0, 0, style.shadow or 0.65)
end

local function CreateStyledText(parent, layer, style, text)
    local fontString = parent:CreateFontString(nil, layer or "ARTWORK", style.template or "GameFontHighlight")
    ApplyFontStyle(fontString, style)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    fontString:SetText(text or "")
    return fontString
end

local function CreateText(parent, template, text, style)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    fontString:SetText(text or "")

    if style then
        StyleText(fontString, style)
    else
        StyleText(fontString, template)
    end

    return fontString
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
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
    panel.bg:SetVertexColor(0, 0, 0, 0)
    panel.bg:Hide()

    panel.topShade = panel:CreateTexture(nil, "BORDER")
    panel.topShade:SetPoint("TOPLEFT", 1, -1)
    panel.topShade:SetPoint("TOPRIGHT", -1, -1)
    panel.topShade:SetHeight(54)
    panel.topShade:SetTexture("Interface\\Buttons\\WHITE8x8")
    panel.topShade:Hide()

    panel.bottomShade = panel:CreateTexture(nil, "ARTWORK")
    panel.bottomShade:SetPoint("BOTTOMLEFT", 1, 1)
    panel.bottomShade:SetPoint("BOTTOMRIGHT", -1, 1)
    panel.bottomShade:SetHeight(62)
    panel.bottomShade:SetTexture("Interface\\Buttons\\WHITE8x8")
    panel.bottomShade:Hide()

    panel.innerLine = panel:CreateTexture(nil, "OVERLAY")
    panel.innerLine:SetPoint("TOPLEFT", 1, -1)
    panel.innerLine:SetPoint("TOPRIGHT", -1, -1)
    panel.innerLine:SetHeight(1)
    panel.innerLine:SetColorTexture(1, 0.88, 0.60, 0.03)

    return panel
end

local function CreateSeparator(parent, topAnchor)
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.90, 0.78, 0.48, 0.16)
    line:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -12)
    line:SetPoint("TOPRIGHT", topAnchor, "BOTTOMRIGHT", 0, -12)
    line:SetHeight(1)
    return line
end

local function AnchorTopLevel(content, frame, previous, spacing)
    frame:ClearAllPoints()
    if previous then
        frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(spacing or 12))
    else
        frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    end
    frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
end

local function AnchorSectionControl(section, frame, previous, spacing, leftOffset, rightOffset)
    local anchor = section.contentArea or section
    frame:SetParent(anchor)
    frame:ClearAllPoints()
    if previous then
        frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(spacing or 10))
    else
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", leftOffset or 0, 0)
    end
    frame:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -(rightOffset or 0), 0)
end

local function CreatePageHeader(parent, titleText, subtitleText)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(PAGE_HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PAGE_INSET_X, PAGE_HEADER_TOP)
    header:SetPoint("TOPRIGHT", -PAGE_INSET_X, PAGE_HEADER_TOP)

    header.title = CreateStyledText(header, "ARTWORK", FONT_STYLES.pageTitle, titleText)
    header.title:SetPoint("TOPLEFT", 0, 0)
    header.title:SetPoint("TOPRIGHT", 0, 0)

    header.subtitle = CreateStyledText(header, "ARTWORK", FONT_STYLES.pageSubtitle, subtitleText or "")
    header.subtitle:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -5)
    header.subtitle:SetPoint("TOPRIGHT", 0, 0)
    header.subtitle:SetSpacing(2)

    header.divider = CreateSeparator(header, header.subtitle)

    return header
end

local function CreateSection(parent, title, description)
    local panel = CreatePanel(parent)
    panel:SetHeight(126)
    panel.bg:Show()
    panel.bg:SetVertexColor(0, 0, 0, 0.22)

    panel.title = CreateStyledText(panel, "ARTWORK", FONT_STYLES.sectionTitle, title)
    panel.title:SetPoint("TOPLEFT", 16, -14)
    panel.title:SetPoint("TOPRIGHT", -16, -14)

    panel.separator = CreateSeparator(panel, panel.title)

    panel.description = CreateStyledText(panel, "ARTWORK", FONT_STYLES.bodySmall, description or "")
    panel.description:SetPoint("TOPLEFT", panel.separator, "BOTTOMLEFT", 0, -14)
    panel.description:SetPoint("TOPRIGHT", -16, -38)
    panel.description:SetSpacing(2)
    panel.description:SetJustifyV("TOP")

    panel.contentArea = CreateFrame("Frame", nil, panel)
    panel.contentArea:SetPoint("TOPLEFT", panel.description, "BOTTOMLEFT", 0, -14)
    panel.contentArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, 0)
    panel.contentArea:SetHeight(1)

    return panel
end

local function CreateCheckboxRow(parent, title, description)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(58)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetPoint("TOPLEFT", 0, 0)

    row.label = CreateStyledText(row, "ARTWORK", FONT_STYLES.sectionTitle, title)
    row.label:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 10, -3)
    row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    row.description = CreateStyledText(row, "ARTWORK", FONT_STYLES.bodySmall, description or "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -5)
    row.description:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.description:SetSpacing(2)

    return row
end

local function CreateDropdownRow(parent, title, description)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(92)

    row.label = CreateStyledText(row, "ARTWORK", FONT_STYLES.sectionTitle, title)
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", 0, 0)

    row.description = CreateStyledText(row, "ARTWORK", FONT_STYLES.bodySmall, description or "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -5)
    row.description:SetPoint("TOPRIGHT", 0, 0)
    row.description:SetSpacing(2)

    row.dropdown = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    row.dropdown:SetPoint("TOPLEFT", row.description, "BOTTOMLEFT", -16, -8)

    return row
end

local function CreateValueSlider(parent, title, minValue, maxValue, step)
    sliderNameIndex = sliderNameIndex + 1

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(60)

    row.label = CreateStyledText(row, "ARTWORK", FONT_STYLES.sectionTitle, title)
    row.label:SetPoint("TOPLEFT", 0, 0)

    row.valueFrame = CreateFrame("Button", nil, row)
    row.valueFrame:SetPoint("TOPRIGHT", 2, 2)
    row.valueFrame:SetSize(64, 20)

    row.valueText = CreateStyledText(row.valueFrame, "ARTWORK", FONT_STYLES.value, "")
    row.valueText:ClearAllPoints()
    row.valueText:SetPoint("RIGHT", row.valueFrame, "RIGHT", -6, 0)
    row.valueText:SetJustifyH("RIGHT")
    row.valueText:SetJustifyV("MIDDLE")

    row.valueEdit = CreateFrame("EditBox", nil, row.valueFrame, "InputBoxTemplate")
    row.valueEdit:SetPoint("TOPLEFT", 0, 0)
    row.valueEdit:SetPoint("BOTTOMRIGHT", -6, 0)
    row.valueEdit:SetAutoFocus(false)
    row.valueEdit:SetNumeric(false)
    row.valueEdit:SetJustifyH("RIGHT")
    row.valueEdit:SetJustifyV("MIDDLE")
    row.valueEdit:SetTextInsets(0, 0, 0, 0)
    row.valueEdit:SetMaxLetters(8)
    row.valueEdit:Hide()

    local valueFontPath, valueFontSize, valueFontFlags = row.valueText:GetFont()
    if valueFontPath then
        row.valueEdit:SetFont(valueFontPath, valueFontSize, valueFontFlags)
    end

    row.valueEdit:SetTextColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3])
    row.valueEdit:SetShadowOffset(1, -1)
    row.valueEdit:SetShadowColor(0, 0, 0, 0.75)

    for _, regionName in ipairs({
        "Left", "Middle", "Right",
        "LeftMiddle", "MiddleMiddle", "RightMiddle",
        "TopLeft", "TopMiddle", "TopRight",
        "BottomLeft", "BottomMiddle", "BottomRight",
    }) do
        local region = row.valueEdit[regionName]
        if region then
            region:Hide()
        end
    end

    local function ShowEdit(self)
        self.valueText:Hide()
        self.valueEdit:Show()
        self.valueEdit:SetText(self.valueText:GetText())
        self.valueEdit:HighlightText()
        self.valueEdit:SetFocus()
    end

    local function HideEdit(self, apply)
        if apply then
            local text = self.valueEdit:GetText()
            local num = tonumber(text)
            if num then
                local minVal, maxVal = self.slider:GetMinMaxValues()
                num = math.max(minVal, math.min(maxVal, num))
                self.slider:SetValue(num)
            end
        end

        self.valueEdit:Hide()
        self.valueText:Show()
    end

    row.valueFrame:EnableMouse(true)
    row.valueFrame:SetScript("OnMouseDown", function()
        ShowEdit(row)
    end)
    row.valueEdit:SetScript("OnEnterPressed", function()
        HideEdit(row, true)
    end)
    row.valueEdit:SetScript("OnEscapePressed", function()
        HideEdit(row, false)
    end)
    row.valueEdit:SetScript("OnEditFocusLost", function()
        HideEdit(row, true)
    end)
    row.valueFrame:SetScript("OnEnter", function()
        row.valueText:SetAlpha(1)
    end)
    row.valueFrame:SetScript("OnLeave", function()
        row.valueText:SetAlpha(0.85)
    end)
    row.valueText:SetAlpha(0.85)

    row.slider = CreateFrame("Slider", "SnailStuffValueSlider" .. sliderNameIndex, row)
    row.slider:SetOrientation("HORIZONTAL")
    row.slider:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -11)
    row.slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -24)
    row.slider:SetHeight(20)
    row.slider:SetMinMaxValues(minValue, maxValue)
    row.slider:SetValueStep(step)
    if row.slider.SetObeyStepOnDrag then
        row.slider:SetObeyStepOnDrag(true)
    end
    row.slider:EnableMouse(true)
    row.slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")

    row.slider.trackShadow = row.slider:CreateTexture(nil, "BACKGROUND")
    row.slider.trackShadow:SetPoint("LEFT", row.slider, "LEFT", 3, -1)
    row.slider.trackShadow:SetPoint("RIGHT", row.slider, "RIGHT", -3, -1)
    row.slider.trackShadow:SetHeight(8)
    row.slider.trackShadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.slider.trackShadow:SetVertexColor(0, 0, 0, 0.30)

    row.slider.trackLeft = row.slider:CreateTexture(nil, "ARTWORK")
    row.slider.trackLeft:SetPoint("LEFT", row.slider, "LEFT", 0, 0)
    if row.slider.trackLeft.SetAtlas and AtlasExists("Minimal_SliderBar_Left") then
        row.slider.trackLeft:SetAtlas("Minimal_SliderBar_Left", true)
    else
        row.slider.trackLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.slider.trackLeft:SetSize(8, 8)
        row.slider.trackLeft:SetVertexColor(0.65, 0.65, 0.65, 1)
    end

    row.slider.trackRight = row.slider:CreateTexture(nil, "ARTWORK")
    row.slider.trackRight:SetPoint("RIGHT", row.slider, "RIGHT", 0, 0)
    if row.slider.trackRight.SetAtlas and AtlasExists("Minimal_SliderBar_Right") then
        row.slider.trackRight:SetAtlas("Minimal_SliderBar_Right", true)
    else
        row.slider.trackRight:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.slider.trackRight:SetSize(8, 8)
        row.slider.trackRight:SetVertexColor(0.65, 0.65, 0.65, 1)
    end

    row.slider.trackMiddle = row.slider:CreateTexture(nil, "ARTWORK")
    row.slider.trackMiddle:SetPoint("LEFT", row.slider.trackLeft, "RIGHT", 0, 0)
    row.slider.trackMiddle:SetPoint("RIGHT", row.slider.trackRight, "LEFT", 0, 0)
    row.slider.trackMiddle:SetPoint("TOP", row.slider.trackLeft, "TOP", 0, 0)
    row.slider.trackMiddle:SetPoint("BOTTOM", row.slider.trackLeft, "BOTTOM", 0, 0)
    if row.slider.trackMiddle.SetAtlas and AtlasExists("_Minimal_SliderBar_Middle") then
        row.slider.trackMiddle:SetAtlas("_Minimal_SliderBar_Middle", false)
    else
        row.slider.trackMiddle:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.slider.trackMiddle:SetVertexColor(0.65, 0.65, 0.65, 1)
    end

    local thumb = row.slider.GetThumbTexture and row.slider:GetThumbTexture()
    if thumb then
        if thumb.SetAtlas and AtlasExists("Minimal_SliderBar_Button") then
            thumb:SetAtlas("Minimal_SliderBar_Button", true)
        else
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            thumb:SetVertexColor(0.95, 0.78, 0.22, 1)
        end
        thumb:SetDrawLayer("OVERLAY", 1)
    end

    if thumb then
        row.slider.thumbGlow = row.slider:CreateTexture(nil, "ARTWORK", nil, 0)
        row.slider.thumbGlow:SetPoint("CENTER", thumb, "CENTER", 0, -1)
        row.slider.thumbGlow:SetSize(30, 30)

        if row.slider.thumbGlow.SetAtlas and AtlasExists("DK-Rune-Glow") then
            row.slider.thumbGlow:SetAtlas("DK-Rune-Glow", false)
            row.slider.thumbGlow:SetVertexColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 0.9)
        else
            row.slider.thumbGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
            row.slider.thumbGlow:SetVertexColor(1.0, 0.82, 0.25, 0.20)
        end

        row.slider.thumbGlow:SetBlendMode("ADD")
        row.slider.thumbGlow:SetAlpha(0)
        row.slider.thumbGlow:Show()

        row.slider.thumbGlow.fadeIn = row.slider.thumbGlow:CreateAnimationGroup()
        local fadeIn = row.slider.thumbGlow.fadeIn:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.25)
        fadeIn:SetOrder(1)

        row.slider.thumbGlow.fadeOut = row.slider.thumbGlow:CreateAnimationGroup()
        local fadeOut = row.slider.thumbGlow.fadeOut:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.25)
        fadeOut:SetOrder(1)

        row.slider.thumbGlow.isVisible = false
        row.slider.thumbGlow.fadeIn:SetScript("OnFinished", function()
            row.slider.thumbGlow:SetAlpha(1)
        end)
        row.slider.thumbGlow.fadeOut:SetScript("OnFinished", function()
            row.slider.thumbGlow:SetAlpha(0)
        end)

        row.slider:SetScript("OnUpdate", function(self)
            local thumbTex = self:GetThumbTexture()
            if not thumbTex or not thumbTex:IsShown() then
                if self.thumbGlow.isVisible or self.thumbGlow:GetAlpha() > 0 then
                    if self.thumbGlow.fadeIn:IsPlaying() then
                        self.thumbGlow.fadeIn:Stop()
                    end
                    if not self.thumbGlow.fadeOut:IsPlaying() then
                        self.thumbGlow.fadeOut:Play()
                    end
                    self.thumbGlow.isVisible = false
                end
                return
            end

            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            mx, my = mx / scale, my / scale

            local left = thumbTex:GetLeft()
            local right = thumbTex:GetRight()
            local top = thumbTex:GetTop()
            local bottom = thumbTex:GetBottom()
            if not (left and right and top and bottom) then
                return
            end

            local hoveringThumb = mx >= left and mx <= right and my >= bottom and my <= top
            if hoveringThumb then
                if not self.thumbGlow.isVisible then
                    if self.thumbGlow.fadeOut:IsPlaying() then
                        self.thumbGlow.fadeOut:Stop()
                    end
                    self.thumbGlow.fadeIn:Stop()
                    self.thumbGlow.fadeIn:Play()
                    self.thumbGlow.isVisible = true
                end
            elseif self.thumbGlow.isVisible then
                if self.thumbGlow.fadeIn:IsPlaying() then
                    self.thumbGlow.fadeIn:Stop()
                end
                self.thumbGlow.fadeOut:Stop()
                self.thumbGlow.fadeOut:Play()
                self.thumbGlow.isVisible = false
            end
        end)
    end

    function row:SetDisplayValue(value)
        if math.abs(value - math.floor(value + 0.5)) < 0.001 then
            self.valueText:SetText(tostring(math.floor(value + 0.5)))
        elseif math.abs((value * 10) - math.floor((value * 10) + 0.5)) < 0.001 then
            self.valueText:SetText(string.format("%.1f", value))
        else
            self.valueText:SetText(string.format("%.2f", value))
        end
    end

    return row
end

local function CreateActionButton(parent, width, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 22)
    button:SetText(text or "")
    return button
end

local function ClampWindowSize(width, height)
    width = math.max(WINDOW_MIN_WIDTH, math.floor((width or WINDOW_MIN_WIDTH) + 0.5))
    height = math.max(WINDOW_MIN_HEIGHT, math.floor((height or WINDOW_MIN_HEIGHT) + 0.5))
    return width, height
end

local function CreateSelectableButtonChrome(button, accentWidth)
    if button.SetBackdrop then
        button:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        button:SetBackdropBorderColor(0, 0, 0, 0)
    end

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.fill:SetVertexColor(0, 0, 0, 0)

    button.hoverFill = button:CreateTexture(nil, "BORDER")
    button.hoverFill:SetPoint("TOPLEFT", 1, -1)
    button.hoverFill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.hoverFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    button.hoverFill:SetVertexColor(COLORS.hover[1], COLORS.hover[2], COLORS.hover[3], COLORS.hover[4])
    button.hoverFill:SetAlpha(0)

    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT", 1, -1)
    button.accent:SetPoint("BOTTOMLEFT", 1, 1)
    button.accent:SetWidth(accentWidth or 3)
    button.accent:SetColorTexture(1, 0.83, 0.24, 1)
    button.accent:SetAlpha(0)
end

local function ApplySelectableButtonVisuals(button, selected, normalStyle, hoverStyle, selectedStyle)
    button.selected = selected and true or false
    button.visualPalette = {
        normalFill = { 0, 0, 0, 0 },
        hoverFill = { 0, 0, 0, 0 },
        selectedFill = { 0, 0, 0, 0 },
        showSelectedAccent = false,
    }

    button.fill:SetVertexColor(0, 0, 0, 0)
    button.hoverFill:SetAlpha(0)
    button.accent:SetAlpha(0)
    ApplyFontStyle(button.text, button.selected and selectedStyle or normalStyle)

    button:SetScript("OnEnter", function(selfButton)
        ApplyFontStyle(selfButton.text, selfButton.selected and selectedStyle or hoverStyle)
    end)

    button:SetScript("OnLeave", function(selfButton)
        ApplyFontStyle(selfButton.text, selfButton.selected and selectedStyle or normalStyle)
    end)
end

local function CreateNavButton(parent, text)
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetHeight(36)
    CreateSelectableButtonChrome(button, 3)

    button.text = CreateStyledText(button, "ARTWORK", FONT_STYLES.nav, text)
    button.text:SetPoint("LEFT", 14, 0)
    button.text:SetPoint("RIGHT", -12, 0)
    button.text:SetJustifyH("LEFT")

    function button:SetSelected(selected)
        ApplySelectableButtonVisuals(self, selected, FONT_STYLES.nav, FONT_STYLES.navSelected, FONT_STYLES.navSelected)
    end

    button:SetSelected(false)

    return button
end

local function CreateScrollPage(parent, definition)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local headerHeight = definition.subtitle and PAGE_HEADER_HEIGHT or 28
    local subtitleOffset = -6
    local bodyOffset = -18

    if definition.compactHeader and definition.subtitle then
        headerHeight = PAGE_HEADER_HEIGHT - 4
        subtitleOffset = -4
        bodyOffset = -14
    end

    page.header = CreateFrame("Frame", nil, page)
    page.header:SetPoint("TOPLEFT", PAGE_INSET_X, PAGE_HEADER_TOP)
    page.header:SetPoint("TOPRIGHT", -PAGE_INSET_X, PAGE_HEADER_TOP)
    page.header:SetHeight(headerHeight)

    page.title = CreateText(page.header, "GameFontNormalLarge", definition.title, FONT_STYLES.pageTitle)
    page.title:SetPoint("TOPLEFT", 0, 0)
    page.title:SetPoint("TOPRIGHT", 0, 0)
    if definition.subtitle then
        page.subtitle = CreateText(page.header, "GameFontHighlight", definition.subtitle, FONT_STYLES.pageSubtitle)
        page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, subtitleOffset)
        page.subtitle:SetPoint("TOPRIGHT", page.title, "BOTTOMRIGHT", 0, subtitleOffset)
    end

    page.body = CreateFrame("Frame", nil, page)
    page.body:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, bodyOffset)
    page.body:SetPoint("TOPRIGHT", page.header, "BOTTOMRIGHT", 0, bodyOffset)
    page.body:SetPoint("BOTTOMLEFT", PAGE_INSET_X, 0)
    page.body:SetPoint("BOTTOMRIGHT", -PAGE_INSET_X, 0)

    page.scrollFrame = CreateFrame("ScrollFrame", nil, page.body, "UIPanelScrollFrameTemplate")
    page.scrollFrame:SetPoint("TOPLEFT", page.body, "TOPLEFT", 0, 0)
    page.scrollFrame:SetPoint("BOTTOMRIGHT", page.body, "BOTTOMRIGHT", -28, 0)

    page.content = CreateFrame("Frame", nil, page.scrollFrame)
    page.content:SetPoint("TOPLEFT", 0, 0)
    page.content:SetSize(1, 1)
    page.scrollFrame:SetScrollChild(page.content)
    page.scrollFrame:SetScript("OnSizeChanged", function(scrollFrame, width, height)
        page.content:SetWidth(math.max((width or 0) - 24, 1))
        if page.content:GetHeight() < (height or 1) then
            page.content:SetHeight(height or 1)
        end
    end)

    return page
end

local function SaveWindowSize(self, frame)
    if not self.db or not frame then
        return
    end

    local width, height = ClampWindowSize(frame:GetWidth(), frame:GetHeight())
    self.db.profile.window.width = width
    self.db.profile.window.height = height
end

local function CreateResizeGrip(frame, onStop)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", WINDOW_RESIZE_OFFSET_X, WINDOW_RESIZE_OFFSET_Y)

    grip.texture = grip:CreateTexture(nil, "ARTWORK")
    grip.texture:SetAllPoints()
    grip.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end

        frame:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if onStop then
            onStop()
        end
    end)

    return grip
end

function SnailStuff:RegisterCorePages()
    self:RegisterPage({
        key = "general",
        title = "General",
        subtitle = "Core addon controls and the shared settings shell for future SnailStuff modules.",
        order = 10,
        compactHeader = true,
        build = function(page)
            local row = CreateCheckboxRow(page.content, "Enable SnailStuff", "Globally enables or disables active SnailStuff modules without changing their saved settings.")
            AnchorTopLevel(page.content, row)
            row.check:SetScript("OnClick", function(check)
                SnailStuff.db.profile.enabled = check:GetChecked() and true or false
                SnailStuff:RefreshAll()
            end)
            page.globalRow = row

            local shell = CreateSection(page.content, "Config Framework", "This window now follows the GG reference shell closely so SnailStuff modules can plug into a shared frame, navigation, section, and control system.")
            AnchorTopLevel(page.content, shell, row, 14)
            shell:SetHeight(136)
            shell.contentArea:Hide()

            local commands = CreateSection(page.content, "Commands", "Use /ss, /snailstuff, or /snail to open the window. Module pages can also be opened with /ss module <name> when available.")
            AnchorTopLevel(page.content, commands, shell, 12)
            commands:SetHeight(118)
            commands.contentArea:Hide()

            page.content:SetHeight(350)

            page.RefreshControls = function(currentPage)
                currentPage.globalRow.check:SetChecked(SnailStuff.db.profile.enabled ~= false)
            end
        end,
    })

    self:RegisterPage({
        key = "about",
        title = "About",
        subtitle = "High-level addon info and the current foundation this toolbox is built on.",
        order = 30,
        build = function(page)
            local summary = CreateSection(page.content, "Addon", "SnailStuff is a shared home for lightweight quality-of-life tools that are easier to maintain together than as many tiny standalone addons.")
            AnchorTopLevel(page.content, summary)
            summary:SetHeight(180)
            page.summary = summary

            summary.nameLabel = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.sectionTitle, "Addon Name")
            summary.nameLabel:SetPoint("TOPLEFT", 0, 0)
            summary.nameValue = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.bodySmall, GetMetadata("Title") or ADDON_NAME)
            summary.nameValue:SetPoint("LEFT", 140, 0)
            summary.nameValue:SetPoint("TOP", summary.nameLabel, "TOP")

            summary.versionLabel = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.sectionTitle, "Version")
            summary.versionLabel:SetPoint("TOPLEFT", summary.nameLabel, "BOTTOMLEFT", 0, -6)
            summary.versionValue = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.bodySmall, GetMetadata("Version") or "Unknown")
            summary.versionValue:SetPoint("LEFT", 140, 0)
            summary.versionValue:SetPoint("TOP", summary.versionLabel, "TOP")

            summary.commandsLabel = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.sectionTitle, "Commands")
            summary.commandsLabel:SetPoint("TOPLEFT", summary.versionLabel, "BOTTOMLEFT", 0, -6)
            summary.commandsValue = CreateStyledText(summary.contentArea, "ARTWORK", FONT_STYLES.bodySmall, "/ss, /snailstuff, /snail")
            summary.commandsValue:SetPoint("LEFT", 140, 0)
            summary.commandsValue:SetPoint("TOP", summary.commandsLabel, "TOP")

            local notes = CreateSection(page.content, "Foundation", "This pass keeps the module and page API intact while rebuilding the visible shell, page chrome, navigation, sections, and reusable controls around the GG reference framework.")
            AnchorTopLevel(page.content, notes, summary, 12)
            notes:SetHeight(126)
            notes.contentArea:Hide()

            page.content:SetHeight(340)

            page.RefreshControls = function(currentPage)
                currentPage.summary.nameValue:SetText(GetMetadata("Title") or ADDON_NAME)
                currentPage.summary.versionValue:SetText(GetMetadata("Version") or "Unknown")
            end
        end,
    })
end

function SnailStuff:BuildPage(definition, parent)
    local page = CreateScrollPage(parent, definition)
    page.definition = definition
    page.flowBottom = nil
    page.flowHeight = 0
    page.AnchorTopLevel = function(_, frame, previous, spacing)
        AnchorTopLevel(page.content, frame, previous, spacing)
    end
    page.AnchorFlow = function(_, frame, spacing)
        AnchorTopLevel(page.content, frame, page.flowBottom, spacing)

        local frameHeight = frame.GetHeight and frame:GetHeight() or 0
        if page.flowBottom then
            page.flowHeight = page.flowHeight + (spacing or 12) + frameHeight
        else
            page.flowHeight = frameHeight
        end

        page.flowBottom = frame
    end
    page.FinalizeFlow = function(_, bottomPadding)
        page.content:SetHeight((page.flowHeight or 0) + (bottomPadding or 0))
    end
    page.AnchorSectionControl = function(_, section, frame, previous, spacing, leftOffset, rightOffset)
        AnchorSectionControl(section, frame, previous, spacing, leftOffset, rightOffset)
    end
    page.CreateCheckbox = function(_, title, description)
        return CreateCheckboxRow(page.content, title, description)
    end
    page.CreateSection = function(_, title, description)
        return CreateSection(page.content, title, description)
    end
    page.CreateDropdownRow = function(_, title, description)
        return CreateDropdownRow(page.content, title, description)
    end
    page.CreateValueSlider = function(_, title, minValue, maxValue, step)
        return CreateValueSlider(page.content, title, minValue, maxValue, step)
    end
    page.CreateActionButton = function(_, width, text)
        return CreateActionButton(page.content, width, text)
    end

    if definition.build then
        definition.build(page)
    end

    return page
end

function SnailStuff:SelectPage(pageKey)
    local frame = self.configFrame
    if not frame or not frame.pages[pageKey] then
        return
    end

    for key, page in pairs(frame.pages) do
        page:SetShown(key == pageKey)
        if key == pageKey and page.RefreshControls then
            page:RefreshControls()
        end
    end

    for key, button in pairs(frame.navButtons) do
        button:SetSelected(key == pageKey)
    end

    frame.currentPage = pageKey
end

function SnailStuff:CreateConfigFrame()
    if self.configFrame then
        return self.configFrame
    end

    local frame = CreateFrame("Frame", "SnailStuffConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    local width, height = ClampWindowSize(self.db.profile.window.width, self.db.profile.window.height)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    if frame.SetMinResize then
        frame:SetMinResize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
    end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
    end

    if frame.Bg then
        frame.Bg:Hide()
        frame.Bg:SetAlpha(0)
    end
    if frame.TopTileStreaks then
        frame.TopTileStreaks:Show()
        frame.TopTileStreaks:SetAlpha(1)
    end
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
        frame.TitleText:SetText("SnailStuff")
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
    frame.surfaceOverlay:Hide()

    frame.surfaceTopFade = frame.surfaceHost:CreateTexture(nil, "ARTWORK")
    frame.surfaceTopFade:SetPoint("TOPLEFT", frame.surfaceHost, "TOPLEFT", 0, 0)
    frame.surfaceTopFade:SetPoint("TOPRIGHT", frame.surfaceHost, "TOPRIGHT", 0, 0)
    frame.surfaceTopFade:SetHeight(88)
    frame.surfaceTopFade:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceTopFade:Hide()

    frame.surfaceBottomFade = frame.surfaceHost:CreateTexture(nil, "ARTWORK")
    frame.surfaceBottomFade:SetPoint("BOTTOMLEFT", frame.surfaceHost, "BOTTOMLEFT", 0, 0)
    frame.surfaceBottomFade:SetPoint("BOTTOMRIGHT", frame.surfaceHost, "BOTTOMRIGHT", 0, 0)
    frame.surfaceBottomFade:SetHeight(90)
    frame.surfaceBottomFade:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.surfaceBottomFade:Hide()

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(panel)
        panel:StopMovingOrSizing()
        SaveWindowSize(SnailStuff, panel)
    end)
    frame:SetScript("OnHide", function(panel)
        SaveWindowSize(SnailStuff, panel)
    end)
    frame:SetScript("OnShow", function(panel)
        local newWidth, newHeight = ClampWindowSize(SnailStuff.db.profile.window.width, SnailStuff.db.profile.window.height)
        panel:SetSize(newWidth, newHeight)
        SnailStuff:SelectPage(panel.currentPage or "general")
    end)
    frame:SetScript("OnSizeChanged", function(panel, newWidth, newHeight)
        local clampedWidth, clampedHeight = ClampWindowSize(newWidth, newHeight)
        if not panel.enforcingSize and (math.abs(newWidth - clampedWidth) > 0.5 or math.abs(newHeight - clampedHeight) > 0.5) then
            panel.enforcingSize = true
            panel:SetSize(clampedWidth, clampedHeight)
            panel.enforcingSize = false
            return
        end

        SaveWindowSize(SnailStuff, panel)
    end)

    frame.nav = CreateFrame("Frame", nil, frame.Inset or frame)
    frame.nav:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", 12, -24)
    frame.nav:SetPoint("BOTTOMLEFT", frame.Inset or frame, "BOTTOMLEFT", 12, 12)
    frame.nav:SetWidth(NAV_WIDTH)

    frame.navTopLine = frame.nav:CreateTexture(nil, "BORDER")
    frame.navTopLine:SetColorTexture(1, 0.82, 0, 0.10)
    frame.navTopLine:SetPoint("TOPLEFT", 0, -2)
    frame.navTopLine:SetPoint("TOPRIGHT", 0, -2)
    frame.navTopLine:SetHeight(1)

    frame.divider = frame.surfaceHost:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.divider:SetWidth(1)
    frame.divider:SetColorTexture(1.0, 0.84, 0.38, 0.06)
    frame.divider:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 12, -2)
    frame.divider:SetPoint("BOTTOMLEFT", frame.nav, "BOTTOMRIGHT", 12, 2)

    frame.content = CreateFrame("Frame", nil, frame.Inset or frame)
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 24, 0)
    frame.content:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", -12, 12)

    frame.navButtons = {}
    frame.pages = {}

    local previousButton
    for _, definition in ipairs(self:GetPages()) do
        local button = CreateNavButton(frame.nav, definition.title)
        button:SetPoint("LEFT", 0, 0)
        button:SetPoint("RIGHT", 0, 0)
        if previousButton then
            button:SetPoint("TOPLEFT", previousButton, "BOTTOMLEFT", 0, -8)
        else
            button:SetPoint("TOPLEFT", 0, -NAV_TOP_PADDING)
        end

        button:SetScript("OnClick", function()
            SnailStuff:SelectPage(definition.key)
        end)

        previousButton = button
        frame.navButtons[definition.key] = button

        local page = self:BuildPage(definition, frame.content)
        page:Hide()
        frame.pages[definition.key] = page
    end

    frame.resizeGrip = CreateResizeGrip(frame, function()
        SaveWindowSize(SnailStuff, frame)
    end)
    frame.resizeGrip:SetFrameStrata(frame:GetFrameStrata())
    frame.resizeGrip:SetFrameLevel(frame:GetFrameLevel() + WINDOW_RESIZE_FRAME_LEVEL_OFFSET)

    self.configFrame = frame
    self:SelectPage("general")

    return frame
end

function SnailStuff:RefreshConfigFrame()
    local frame = self.configFrame
    if not frame then
        return
    end

    if frame.currentPage and frame.pages[frame.currentPage] and frame.pages[frame.currentPage].RefreshControls then
        frame.pages[frame.currentPage]:RefreshControls()
    end

end

function SnailStuff:OpenConfig(pageKey)
    local frame = self:CreateConfigFrame()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end

    self:SelectPage(pageKey or frame.currentPage or "general")
end
