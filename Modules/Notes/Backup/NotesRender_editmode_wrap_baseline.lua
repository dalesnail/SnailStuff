local _, ns = ...
local shared = ns.NotesShared
local module = shared and shared.module
if not shared or not module then return end
local constants = shared.constants
local NOTE_TAB_FIELD_INNER_X = constants.NOTE_TAB_FIELD_INNER_X
local NOTE_TAB_FIELD_INNER_Y = constants.NOTE_TAB_FIELD_INNER_Y
local NOTE_TAB_BODY_MIN_CONTENT_HEIGHT = constants.NOTE_TAB_BODY_MIN_CONTENT_HEIGHT
local NOTE_TAB_BODY_NATIVE_LEFT_INSET = constants.NOTE_TAB_BODY_NATIVE_LEFT_INSET
local NOTE_TAB_BODY_NATIVE_TOP_INSET = constants.NOTE_TAB_BODY_NATIVE_TOP_INSET
local NOTE_TAB_BODY_NATIVE_RIGHT_INSET = constants.NOTE_TAB_BODY_NATIVE_RIGHT_INSET
local NOTE_TAB_BODY_NATIVE_BOTTOM_INSET = constants.NOTE_TAB_BODY_NATIVE_BOTTOM_INSET
local NOTE_TAB_BODY_SCROLLBAR_WIDTH = constants.NOTE_TAB_BODY_SCROLLBAR_WIDTH
local NOTE_TAB_BODY_SCROLLBAR_X_OFFSET = constants.NOTE_TAB_BODY_SCROLLBAR_X_OFFSET
local NOTE_TAB_BODY_SCROLLBAR_LEFT_INSET = constants.NOTE_TAB_BODY_SCROLLBAR_LEFT_INSET
local NOTE_TAB_BODY_SCROLLBAR_TOP_INSET = constants.NOTE_TAB_BODY_SCROLLBAR_TOP_INSET
local NOTE_TAB_BODY_SCROLLBAR_GAP = constants.NOTE_TAB_BODY_SCROLLBAR_GAP
local NOTE_TAB_BODY_SCROLLBAR_RIGHT_INSET = constants.NOTE_TAB_BODY_SCROLLBAR_RIGHT_INSET
local NOTE_TAB_BODY_SCROLLBAR_BOTTOM_INSET = constants.NOTE_TAB_BODY_SCROLLBAR_BOTTOM_INSET
local READ_SEPARATOR_COLOR = constants.READ_SEPARATOR_COLOR
local READ_CODE_BACKGROUND_COLOR = constants.READ_CODE_BACKGROUND_COLOR
local READ_LINE_VERTICAL_SPACING = constants.READ_LINE_VERTICAL_SPACING
local READ_HEADER_VERTICAL_SPACING = constants.READ_HEADER_VERTICAL_SPACING
local READ_POST_BULLET_BLOCK_SPACING = constants.READ_POST_BULLET_BLOCK_SPACING
local READ_LINE_FONT_SIZE = constants.READ_LINE_FONT_SIZE
local READ_HEADER1_FONT_SIZE = constants.READ_HEADER1_FONT_SIZE
local READ_HEADER2_FONT_SIZE = constants.READ_HEADER2_FONT_SIZE
local READ_HEADER3_FONT_SIZE = constants.READ_HEADER3_FONT_SIZE
local READ_BULLET_INDENT = constants.READ_BULLET_INDENT
local READ_BLANK_LINE_HEIGHT = constants.READ_BLANK_LINE_HEIGHT
local READ_SEPARATOR_ROW_HEIGHT = constants.READ_SEPARATOR_ROW_HEIGHT
local READ_SEPARATOR_SIDE_INSET = constants.READ_SEPARATOR_SIDE_INSET
local READ_SEPARATOR_THICKNESS = constants.READ_SEPARATOR_THICKNESS
local READ_UNRESOLVED_ITEM_TOKEN_COLOR = constants.READ_UNRESOLVED_ITEM_TOKEN_COLOR
local FONT_REGULAR = constants.FONT_REGULAR
local FONT_ITALIC = constants.FONT_ITALIC
local FONT_BOLD = constants.FONT_BOLD
local FONT_BOLDITALIC = constants.FONT_BOLDITALIC
local DEFAULT_NOTE_BODY = constants.DEFAULT_NOTE_BODY

local function ParseReadViewAtlasLine(rawLine)
    local lineText = tostring(rawLine or "")
    local atlasName, width, height = string.match(lineText, "^%[@atlas%s+([^%s%]]+)%s+(%d+)x(%d+)%s*%]$")
    if atlasName then
        return {
            rawText = lineText,
            atlasName = atlasName,
            width = tonumber(width),
            height = tonumber(height),
        }
    end

    atlasName = string.match(lineText, "^%[@atlas%s+([^%s%]]+)%s*%]$")
    if atlasName then
        return {
            rawText = lineText,
            atlasName = atlasName,
        }
    end

    return nil
end

local function IsReadViewCenteredBlockStart(rawLine)
    return tostring(rawLine or "") == "[c]"
end

local function IsReadViewCenteredBlockEnd(rawLine)
    return tostring(rawLine or "") == "[/c]"
end

local function IsReadViewCodeBlockStart(rawLine)
    return tostring(rawLine or "") == "[code]"
end

local function IsReadViewCodeBlockEnd(rawLine)
    return tostring(rawLine or "") == "[/code]"
end

local function SplitNoteBodyIntoLines(bodyText)
    local text = tostring(bodyText or "")
    local normalizedText = string.gsub(text, "\r\n", "\n")
    normalizedText = string.gsub(normalizedText, "\r", "\n")

    local lines = {}
    if normalizedText == "" then
        lines[1] = ""
        return lines
    end

    for line in string.gmatch(normalizedText .. "\n", "(.-)\n") do
        lines[#lines + 1] = line
    end

    return lines
end

local function ClassifyReadViewLine(rawLine)
    local lineText = tostring(rawLine or "")

    if lineText == "" then
        return "blank", ""
    end

    if string.match(lineText, "^###%s+") then
        return "h3", string.gsub(lineText, "^###%s+", "", 1)
    end

    if string.match(lineText, "^##%s+") then
        return "h2", string.gsub(lineText, "^##%s+", "", 1)
    end

    if string.match(lineText, "^#%s+") then
        return "h1", string.gsub(lineText, "^#%s+", "", 1)
    end

    if string.match(lineText, "^%-%s+") then
        return "bullet", string.gsub(lineText, "^%-%s+", "", 1)
    end

    if lineText == "---" then
        return "separator", ""
    end

    local atlasData = ParseReadViewAtlasLine(lineText)
    if atlasData then
        return "atlas", atlasData
    end

    if string.match(lineText, "^%*%*_.+_%*%*$") then
        local innerText = string.gsub(string.gsub(lineText, "^%*%*_", "", 1), "_%*%*$", "", 1)
        return "bolditalic", innerText
    end

    if string.match(lineText, "^_%*%*.+%*%*_$") then
        local innerText = string.gsub(string.gsub(lineText, "^_%*%*", "", 1), "%*%*_$", "", 1)
        return "bolditalic", innerText
    end

    if string.match(lineText, "^%*%*.+%*%*$") then
        return "bold", string.gsub(string.gsub(lineText, "^%*%*", "", 1), "%*%*$", "", 1)
    end

    if string.match(lineText, "^_.+_$") then
        return "italic", string.gsub(string.gsub(lineText, "^_", "", 1), "_$", "", 1)
    end

    return "plain", lineText
end

local function ParseReadViewInlineSegments(lineText)
    local text = tostring(lineText or "")
    local segments = {}
    local searchStart = 1

    while searchStart <= string.len(text) do
        local tokenStart, tokenEnd, itemId = string.find(text, "%[(%d+)%]", searchStart)
        if not tokenStart then
            break
        end

        if tokenStart > searchStart then
            segments[#segments + 1] = {
                kind = "text",
                text = string.sub(text, searchStart, tokenStart - 1),
            }
        end

        segments[#segments + 1] = {
            kind = "itemToken",
            text = string.sub(text, tokenStart, tokenEnd),
            itemId = itemId,
        }

        searchStart = tokenEnd + 1
    end

    if searchStart <= string.len(text) then
        segments[#segments + 1] = {
            kind = "text",
            text = string.sub(text, searchStart),
        }
    end

    if #segments == 0 then
        segments[1] = {
            kind = "text",
            text = text,
        }
    end

    return segments
end

function module:GetOrCreateNoteReadLineRow(view, index)
    view.bodyLines = view.bodyLines or {}
    local row = view.bodyLines[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, view.bodyContent)
    row:SetHeight(1)

    row.bullet = row:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    row.bullet:SetPoint("TOPLEFT", NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
    row.bullet:SetJustifyH("LEFT")
    row.bullet:SetJustifyV("TOP")
    row.bullet:SetText("")
    row.bullet:Hide()

    row.text = row:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    row.text:SetPoint("TOPLEFT", NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
    row.text:SetPoint("TOPRIGHT", -NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    if row.text.SetNonSpaceWrap then
        row.text:SetNonSpaceWrap(true)
    end
    row.text:SetText("")

    row.separator = row:CreateTexture(nil, "ARTWORK")
    row.separator:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.separator:SetVertexColor(unpack(READ_SEPARATOR_COLOR))
    row.separator:Hide()

    row.codeBackground = row:CreateTexture(nil, "BACKGROUND")
    row.codeBackground:SetAllPoints()
    row.codeBackground:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.codeBackground:SetVertexColor(unpack(READ_CODE_BACKGROUND_COLOR))
    row.codeBackground:Hide()

    row.atlasTexture = row:CreateTexture(nil, "ARTWORK")
    row.atlasTexture:Hide()

    row.measure = row:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    row.measure:Hide()

    row.hoverRegions = {}

    view.bodyLines[index] = row
    return row
end

function module:GetReadViewLineSpacing(previousLineType, currentLineType)
    if previousLineType == "h1" or previousLineType == "h2" or previousLineType == "h3" then
        return READ_HEADER_VERTICAL_SPACING
    end

    if previousLineType == "separator" or currentLineType == "separator" then
        return 6
    end

    if previousLineType == "bullet" and currentLineType ~= "bullet" then
        return READ_POST_BULLET_BLOCK_SPACING
    end

    if (previousLineType == "plain" or previousLineType == "bold" or previousLineType == "italic")
        and (currentLineType == "plain" or currentLineType == "bold" or currentLineType == "italic")
    then
        return READ_LINE_VERTICAL_SPACING
    end

    return 0
end

function module:ResolveReadViewItemTokenText(itemId, fallbackText)
    local numericItemId = tonumber(itemId)
    local fallback = tostring(fallbackText or "")
    if not numericItemId then
        return fallback, false, nil
    end

    local itemName, itemLink = GetItemInfo(numericItemId)
    if itemName and itemLink and itemLink ~= "" then
        return itemLink, true, itemLink
    end

    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(numericItemId)
    end

    return fallback, false, nil
end

function module:ShouldListenForReadItemInfoUpdates()
    if not self.runtime or not self.runtime.noteSlots then
        return false
    end

    for _, tab in ipairs(self.runtime.noteSlots) do
        if tab and tab.assigned and not self:IsNoteTabInEditMode(tab) and tab.hasPendingReadItemInfo then
            return true
        end
    end

    return false
end

function module:UpdateReadItemInfoEventRegistration()
    local shouldListen = self:ShouldListenForReadItemInfoUpdates()
    if shouldListen then
        if not self.runtime.isListeningForReadItemInfo then
            self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
            self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
            self.runtime.isListeningForReadItemInfo = true
        end
    elseif self.runtime and self.runtime.isListeningForReadItemInfo then
        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
        self.runtime.isListeningForReadItemInfo = false
    end
end

function module:TrackPendingReadItemId(pendingItemIds, itemId)
    local numericItemId = tonumber(itemId)
    if not pendingItemIds or not numericItemId then
        return
    end

    pendingItemIds[numericItemId] = true
end

function module:GetReadViewDefaultFont()
    local _, _, fontFlags = ChatFontNormal:GetFont()
    return FONT_REGULAR or STANDARD_TEXT_FONT, fontFlags or ""
end

function module:GetReadViewFontPath(lineType, fallbackFontPath)
    if lineType == "h1italic" or lineType == "h2italic" or lineType == "h3italic" then
        return FONT_BOLDITALIC or FONT_BOLD or FONT_REGULAR or fallbackFontPath
    end

    if lineType == "h1" or lineType == "h2" or lineType == "h3" then
        return FONT_BOLD or FONT_REGULAR or fallbackFontPath
    end

    if lineType == "bold" then
        return FONT_BOLD or FONT_REGULAR or fallbackFontPath
    end

    if lineType == "bolditalic" then
        return FONT_BOLDITALIC or FONT_BOLD or FONT_REGULAR or fallbackFontPath
    end

    if lineType == "italic" then
        return FONT_ITALIC or FONT_REGULAR or fallbackFontPath
    end

    return FONT_REGULAR or fallbackFontPath
end

function module:ApplyReadViewFont(target, preferredFontPath, fallbackFontPath, fontSize, fontFlags)
    if not target or not target.SetFont then
        return
    end

    local didApplyPreferred = preferredFontPath and target:SetFont(preferredFontPath, fontSize, fontFlags)
    if didApplyPreferred then
        return
    end

    target:SetFont(fallbackFontPath or STANDARD_TEXT_FONT, fontSize, fontFlags)
end

function module:GetReadViewRowAvailableWidth(row)
    if not row then
        return 1
    end

    local width = row:GetWidth() or 0
    if width <= 1 and row.GetParent then
        local parent = row:GetParent()
        width = parent and parent:GetWidth() or 0
    end

    return math.max(width - (NOTE_TAB_FIELD_INNER_X * 2), 1)
end

function module:TryApplyReadViewAtlas(row, atlasData)
    if not row or not row.atlasTexture or not atlasData or not atlasData.atlasName or atlasData.atlasName == "" then
        return false
    end

    if C_Texture and C_Texture.GetAtlasElementID and not C_Texture.GetAtlasElementID(atlasData.atlasName) then
        return false
    end

    row.atlasTexture:ClearAllPoints()

    local didSetAtlas
    local intendedWidth
    local intendedHeight
    if atlasData.width and atlasData.height then
        didSetAtlas = pcall(row.atlasTexture.SetAtlas, row.atlasTexture, atlasData.atlasName)
        if not didSetAtlas then
            row.atlasTexture:SetTexture(nil)
            row.atlasTexture:Hide()
            return false
        end
        intendedWidth = atlasData.width
        intendedHeight = atlasData.height
    else
        didSetAtlas = pcall(row.atlasTexture.SetAtlas, row.atlasTexture, atlasData.atlasName, true)
        if not didSetAtlas then
            row.atlasTexture:SetTexture(nil)
            row.atlasTexture:Hide()
            return false
        end

        intendedWidth, intendedHeight = row.atlasTexture:GetSize()
    end

    if not intendedWidth or intendedWidth <= 0 or not intendedHeight or intendedHeight <= 0 then
        row.atlasTexture:SetTexture(nil)
        row.atlasTexture:Hide()
        return false
    end

    local maxWidth = self:GetReadViewRowAvailableWidth(row)
    local scale = 1
    if intendedWidth > maxWidth then
        scale = maxWidth / intendedWidth
    end

    local atlasWidth = math.max(math.floor((intendedWidth * scale) + 0.5), 1)
    local atlasHeight = math.max(math.floor((intendedHeight * scale) + 0.5), 1)
    row.atlasTexture:SetSize(atlasWidth, atlasHeight)

    if row.isCentered then
        row.atlasTexture:SetPoint("TOP", row, "TOP", 0, -NOTE_TAB_FIELD_INNER_Y)
    else
        row.atlasTexture:SetPoint("TOPLEFT", row, "TOPLEFT", NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
    end

    row.atlasWidth = atlasWidth
    row.atlasHeight = atlasHeight
    row.atlasData = atlasData
    row.atlasTexture:Show()
    return true
end

function module:GetOrCreateReadItemHoverRegion(row, index)
    row.hoverRegions = row.hoverRegions or {}
    local region = row.hoverRegions[index]
    if region then
        return region
    end

    region = CreateFrame("Button", nil, row)
    region:SetFrameStrata(row:GetFrameStrata())
    region:SetFrameLevel((row:GetFrameLevel() or 1) + 10)
    region:RegisterForClicks("AnyUp")
    region:EnableMouse(true)
    region:Hide()
    region:SetScript("OnEnter", function(selfRegion)
        local segmentData = selfRegion.segmentData
        if not segmentData then
            return
        end

        GameTooltip:SetOwner(selfRegion, "ANCHOR_RIGHT")
        if segmentData.isResolved and segmentData.itemLink then
            GameTooltip:SetHyperlink(segmentData.itemLink)
        else
            GameTooltip:SetText(segmentData.text or "", 1, 0.82, 0)
            GameTooltip:AddLine("Item invalid or not cached", 0.92, 0.88, 0.80, true)
        end
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    region:SetScript("OnClick", function(selfRegion, button)
        local segmentData = selfRegion.segmentData
        local itemLink = segmentData and segmentData.itemLink or nil
        if not segmentData or not segmentData.isResolved or not itemLink or itemLink == "" then
            return
        end

        if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
            return
        end

        if SetItemRef then
            SetItemRef(itemLink, itemLink, button or "LeftButton", selfRegion)
        end
    end)

    row.hoverRegions[index] = region
    return region
end

function module:HideReadItemHoverRegions(row)
    if not row or not row.hoverRegions then
        return
    end

    for _, region in ipairs(row.hoverRegions) do
        region.segmentData = nil
        region:Hide()
    end
end

function module:RefreshReadItemHoverRegions(row, resolvedFontPath, fallbackFontPath, fontSize, fontFlags)
    if not row or not row.text or not row.measure then
        return
    end

    self:HideReadItemHoverRegions(row)

    local segments = row.inlineSegments
    if not segments or #segments == 0 then
        return
    end

    self:ApplyReadViewFont(row.measure, resolvedFontPath, fallbackFontPath, fontSize, fontFlags)
    row.measure:SetSpacing(row.text.GetSpacing and row.text:GetSpacing() or 0)

    local lineHeight = select(2, row.measure:GetFont())
    local textHeight = row.text:GetStringHeight() or 0
    if not lineHeight or lineHeight <= 0 or textHeight > (lineHeight * 1.5) then
        return
    end

    local prefixText = ""
    local hoverIndex = 0
    for _, segmentData in ipairs(segments) do
        local displayText = segmentData.displayText or segmentData.text or ""
        if segmentData.kind == "itemToken" and displayText ~= "" then
            row.measure:SetText(prefixText)
            local prefixWidth = row.measure:GetStringWidth() or 0

            row.measure:SetText(displayText)
            local segmentWidth = row.measure:GetStringWidth() or 0

            if segmentWidth > 0 then
                hoverIndex = hoverIndex + 1
                local region = self:GetOrCreateReadItemHoverRegion(row, hoverIndex)
                region.segmentData = segmentData
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", row.text, "TOPLEFT", prefixWidth, 0)
                region:SetSize(segmentWidth, math.max(textHeight, lineHeight))
                region:Show()
            end
        end

        prefixText = prefixText .. displayText
    end
end

function module:ApplyReadViewLineStyle(row, lineType, displayText, pendingItemIds)
    if not row or not row.text or not row.bullet then
        return false
    end

    local fallbackFontPath, fontFlags = self:GetReadViewDefaultFont()
    local resolvedFontPath = self:GetReadViewFontPath(lineType, fallbackFontPath)
    local fontSize = READ_LINE_FONT_SIZE
    local isCenteredBullet = lineType == "bullet" and row.isCentered

    row.bullet:Hide()
    row.bullet:SetText("")
    if row.separator then
        row.separator:Hide()
    end
    if row.codeBackground then
        row.codeBackground:Hide()
    end
    if row.atlasTexture then
        row.atlasTexture:Hide()
    end
    row.renderedLineType = nil
    row.atlasWidth = nil
    row.atlasHeight = nil
    row.atlasData = nil

    if lineType == "h1" then
        fontSize = READ_HEADER1_FONT_SIZE
    elseif lineType == "h2" then
        fontSize = READ_HEADER2_FONT_SIZE
    elseif lineType == "h3" then
        fontSize = READ_HEADER3_FONT_SIZE
    elseif lineType == "bold" then
        fontSize = READ_LINE_FONT_SIZE
    elseif lineType == "bolditalic" then
        fontSize = READ_LINE_FONT_SIZE
    elseif lineType == "italic" then
        fontSize = READ_LINE_FONT_SIZE
    elseif lineType == "bullet" then
        if not isCenteredBullet then
            self:ApplyReadViewFont(row.bullet, fallbackFontPath, fallbackFontPath, READ_LINE_FONT_SIZE, fontFlags)
            row.bullet:SetText("•")
            row.bullet:Show()
        end
    elseif lineType == "separator" then
        fontSize = READ_LINE_FONT_SIZE
    elseif lineType == "blank" then
        fontSize = READ_LINE_FONT_SIZE
    end

    row.text:ClearAllPoints()
    if lineType == "bullet" and not isCenteredBullet then
        row.text:SetPoint("TOPLEFT", row.bullet, "TOPRIGHT", 6, 0)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
        row.text:SetJustifyH("LEFT")
    else
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -NOTE_TAB_FIELD_INNER_X, -NOTE_TAB_FIELD_INNER_Y)
        row.text:SetJustifyH(row.isCentered and "CENTER" or "LEFT")
    end
    self:ApplyReadViewFont(row.text, resolvedFontPath, fallbackFontPath, fontSize, fontFlags)
    row.text:SetTextColor(1, 1, 1)
    row.text:SetShadowOffset(0, 0)
    row.text:SetShadowColor(0, 0, 0, 0)

    if lineType == "h1" or lineType == "h2" then
        row.text:SetShadowOffset(3, -3)
        row.text:SetShadowColor(0, 0, 0, 0.60)
    end

    if lineType == "separator" then
        row.renderedLineType = "separator"
        row.text:SetText("")
        row.inlineSegments = nil
        self:HideReadItemHoverRegions(row)
        if row.separator then
            row.separator:ClearAllPoints()
            row.separator:SetPoint("LEFT", row, "LEFT", NOTE_TAB_FIELD_INNER_X + READ_SEPARATOR_SIDE_INSET, 0)
            row.separator:SetPoint("RIGHT", row, "RIGHT", -(NOTE_TAB_FIELD_INNER_X + READ_SEPARATOR_SIDE_INSET), 0)
            row.separator:SetHeight(READ_SEPARATOR_THICKNESS)
            row.separator:Show()
        end
        return false
    end

    if lineType == "code" then
        row.renderedLineType = "code"
        row.inlineSegments = nil
        self:HideReadItemHoverRegions(row)
        if row.codeBackground then
            row.codeBackground:Show()
        end
        row.text:SetJustifyH("LEFT")
        row.text:SetText(tostring(displayText or ""))
        return false
    end

    if lineType == "atlas" then
        row.text:SetText("")
        row.inlineSegments = nil
        self:HideReadItemHoverRegions(row)
        if self:TryApplyReadViewAtlas(row, displayText) then
            row.renderedLineType = "atlas"
            return false
        end

        lineType = "plain"
        displayText = displayText and displayText.rawText or ""
    end

    local segments = ParseReadViewInlineSegments(displayText or "")
    if isCenteredBullet then
        table.insert(segments, 1, {
            kind = "text",
            text = "• ",
            displayText = "• ",
        })
    end
    local formattedSegments = {}
    local hasUnresolvedItemTokens = false

    for _, segmentData in ipairs(segments) do
        if segmentData.kind == "itemToken" then
            local resolvedText, isResolved, itemLink = self:ResolveReadViewItemTokenText(segmentData.itemId, segmentData.text)
            segmentData.displayText = resolvedText
            segmentData.isResolved = isResolved
            segmentData.itemLink = itemLink
            if isResolved then
                formattedSegments[#formattedSegments + 1] = resolvedText
            else
                hasUnresolvedItemTokens = true
                self:TrackPendingReadItemId(pendingItemIds, segmentData.itemId)
                formattedSegments[#formattedSegments + 1] = string.format(
                    "|cff%02x%02x%02x%s|r",
                    math.floor((READ_UNRESOLVED_ITEM_TOKEN_COLOR[1] or 1) * 255),
                    math.floor((READ_UNRESOLVED_ITEM_TOKEN_COLOR[2] or 1) * 255),
                    math.floor((READ_UNRESOLVED_ITEM_TOKEN_COLOR[3] or 1) * 255),
                    resolvedText or ""
                )
            end
        else
            segmentData.displayText = segmentData.text or ""
            formattedSegments[#formattedSegments + 1] = segmentData.text or ""
        end
    end

    row.inlineSegments = segments
    row.renderedLineType = lineType
    row.text:SetText(table.concat(formattedSegments))
    self:RefreshReadItemHoverRegions(row, resolvedFontPath, fallbackFontPath, fontSize, fontFlags)
    return hasUnresolvedItemTokens
end

function module:GetReadViewLineRowHeight(row)
    if not row then
        return 1
    end

    if row.lineType == "blank" then
        return math.max(READ_BLANK_LINE_HEIGHT, 1)
    end

    if row.lineType == "separator" then
        return math.max(READ_SEPARATOR_ROW_HEIGHT, 1)
    end

    if row.lineType == "code" then
        return math.max((row.text and row.text:GetStringHeight() or 0) + (NOTE_TAB_FIELD_INNER_Y * 2), READ_LINE_FONT_SIZE + (NOTE_TAB_FIELD_INNER_Y * 2), 1)
    end

    if row.lineType == "atlas" and row.atlasHeight then
        return math.max(row.atlasHeight + (NOTE_TAB_FIELD_INNER_Y * 2), 1)
    end

    return math.max((row.text and row.text:GetStringHeight() or 0) + (NOTE_TAB_FIELD_INNER_Y * 2), 1)
end

function module:RefreshNoteReadLineRows(view, bodyText)
    if not view or not view.bodyContent then
        return false
    end

    local lines = SplitNoteBodyIntoLines(bodyText)
    local renderedLineCount = 0
    local previousRow = nil
    local previousLineType = nil
    local previousIndentOffset = 0
    local isCenteredBlock = false
    local isCodeBlock = false
    local hasUnresolvedItemTokens = false
    local pendingItemIds = {}
    for _, lineText in ipairs(lines) do
        if isCodeBlock then
            if IsReadViewCodeBlockEnd(lineText) then
                isCodeBlock = false
            else
                renderedLineCount = renderedLineCount + 1
                local row = self:GetOrCreateNoteReadLineRow(view, renderedLineCount)
                local lineType = "code"
                local displayText = lineText
                local indentOffset = 0
                row.isCentered = false
                row:ClearAllPoints()
                row:SetPoint("LEFT", view.bodyContent, "LEFT", indentOffset, 0)
                row:SetPoint("RIGHT", view.bodyContent, "RIGHT", 0, 0)

                local rowHasUnresolvedItemTokens = self:ApplyReadViewLineStyle(row, lineType, displayText, pendingItemIds)
                row.lineType = row.renderedLineType or lineType
                if previousRow then
                    row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", indentOffset - previousIndentOffset, -self:GetReadViewLineSpacing(previousLineType, row.lineType))
                else
                    row:SetPoint("TOPLEFT", view.bodyContent, "TOPLEFT", indentOffset, 0)
                end
                row:SetHeight(self:GetReadViewLineRowHeight(row))
                row:Show()
                previousRow = row
                previousLineType = row.lineType
                previousIndentOffset = indentOffset
                hasUnresolvedItemTokens = hasUnresolvedItemTokens or rowHasUnresolvedItemTokens
            end
        elseif IsReadViewCodeBlockStart(lineText) then
            isCodeBlock = true
        elseif IsReadViewCenteredBlockStart(lineText) then
            isCenteredBlock = true
        elseif IsReadViewCenteredBlockEnd(lineText) then
            isCenteredBlock = false
        else
            renderedLineCount = renderedLineCount + 1
            local row = self:GetOrCreateNoteReadLineRow(view, renderedLineCount)
            local lineType, displayText = ClassifyReadViewLine(lineText)
            local isCenteredRow = isCenteredBlock
            local indentOffset = (lineType == "bullet" and not isCenteredRow) and READ_BULLET_INDENT or 0
            row.isCentered = isCenteredRow
            row:ClearAllPoints()
            row:SetPoint("LEFT", view.bodyContent, "LEFT", indentOffset, 0)
            row:SetPoint("RIGHT", view.bodyContent, "RIGHT", 0, 0)

            local rowHasUnresolvedItemTokens = self:ApplyReadViewLineStyle(row, lineType, displayText, pendingItemIds)
            row.lineType = row.renderedLineType or lineType
            if previousRow then
                row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", indentOffset - previousIndentOffset, -self:GetReadViewLineSpacing(previousLineType, row.lineType))
            else
                row:SetPoint("TOPLEFT", view.bodyContent, "TOPLEFT", indentOffset, 0)
            end
            row:SetHeight(self:GetReadViewLineRowHeight(row))
            row:Show()
            previousRow = row
            previousLineType = row.lineType
            previousIndentOffset = indentOffset
            hasUnresolvedItemTokens = hasUnresolvedItemTokens or rowHasUnresolvedItemTokens
        end
    end

    for index = renderedLineCount + 1, #(view.bodyLines or {}) do
        local row = view.bodyLines[index]
        if row then
            self:HideReadItemHoverRegions(row)
            row:Hide()
            row.lineType = nil
            row.renderedLineType = nil
            row.inlineSegments = nil
            row.atlasData = nil
        end
    end

    view.hasPendingReadItemInfo = hasUnresolvedItemTokens
    view.pendingReadItemIds = pendingItemIds
    return hasUnresolvedItemTokens
end

function module:RefreshNoteReadLineRowHeights(view)
    if not view or not view.bodyLines then
        return
    end

    for _, row in ipairs(view.bodyLines) do
        if row:IsShown() and row.text then
            if row.lineType == "atlas" and row.atlasData then
                self:TryApplyReadViewAtlas(row, row.atlasData)
            end
            row:SetHeight(self:GetReadViewLineRowHeight(row))
        end
    end
end

function module:UpdateNoteBodyEditLayout(tab)
    local view = self:GetNoteTabEditView(tab and tab.panel)
    if not view or not view.bodyFrame or not view.bodyInput or not view.bodyScrollFrame then
        return
    end

    local scrollBar = view.bodyScrollBar

    if view.lineNumberGutter then
        view.lineNumberGutter:ClearAllPoints()
        view.lineNumberGutter:SetPoint("TOPLEFT", view.bodyFrame, "TOPLEFT", NOTE_TAB_BODY_NATIVE_LEFT_INSET, -NOTE_TAB_BODY_NATIVE_TOP_INSET)
        view.lineNumberGutter:SetPoint("BOTTOMLEFT", view.bodyFrame, "BOTTOMLEFT", NOTE_TAB_BODY_NATIVE_LEFT_INSET, NOTE_TAB_BODY_NATIVE_BOTTOM_INSET)
        view.lineNumberGutter:SetWidth(view.lineNumberGutter:GetWidth() or 0)
    end

    view.bodyScrollFrame:ClearAllPoints()
    if view.lineNumberGutter then
        view.bodyScrollFrame:SetPoint("TOPLEFT", view.lineNumberGutter, "TOPRIGHT", view.lineNumberGap or 0, 0)
        view.bodyScrollFrame:SetPoint("BOTTOMLEFT", view.lineNumberGutter, "BOTTOMRIGHT", view.lineNumberGap or 0, 0)
    else
        view.bodyScrollFrame:SetPoint("TOPLEFT", view.bodyFrame, "TOPLEFT", NOTE_TAB_BODY_NATIVE_LEFT_INSET, -NOTE_TAB_BODY_NATIVE_TOP_INSET)
        view.bodyScrollFrame:SetPoint("BOTTOMLEFT", view.bodyFrame, "BOTTOMLEFT", NOTE_TAB_BODY_NATIVE_LEFT_INSET, NOTE_TAB_BODY_NATIVE_BOTTOM_INSET)
    end
    view.bodyScrollFrame:SetPoint("TOPRIGHT", view.bodyFrame, "TOPRIGHT", -NOTE_TAB_BODY_NATIVE_RIGHT_INSET, -NOTE_TAB_BODY_NATIVE_TOP_INSET)
    view.bodyScrollFrame:SetPoint("BOTTOMRIGHT", view.bodyFrame, "BOTTOMRIGHT", -NOTE_TAB_BODY_NATIVE_RIGHT_INSET, NOTE_TAB_BODY_NATIVE_BOTTOM_INSET)

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetWidth(NOTE_TAB_BODY_SCROLLBAR_WIDTH)
        scrollBar:SetPoint("TOPLEFT", view.bodyScrollFrame, "TOPRIGHT", NOTE_TAB_BODY_SCROLLBAR_GAP + NOTE_TAB_BODY_SCROLLBAR_X_OFFSET, -NOTE_TAB_BODY_SCROLLBAR_TOP_INSET)
        scrollBar:SetPoint("BOTTOMRIGHT", view.bodyFrame, "BOTTOMRIGHT", -(NOTE_TAB_BODY_SCROLLBAR_RIGHT_INSET - NOTE_TAB_BODY_SCROLLBAR_X_OFFSET), NOTE_TAB_BODY_NATIVE_BOTTOM_INSET + NOTE_TAB_BODY_SCROLLBAR_BOTTOM_INSET)
    end
end

function module:UpdateNoteBodyReadLayout(tab)
    local view = self:GetNoteTabReadView(tab and tab.panel)
    if not view or not view.bodyFrame or not view.bodyScrollFrame or not view.bodyContent then
        return
    end

    local scrollBar = view.bodyScrollBar
    local reserveScrollbar = scrollBar and scrollBar:IsShown() or false
    local rightInset = NOTE_TAB_BODY_NATIVE_RIGHT_INSET + (reserveScrollbar and (NOTE_TAB_BODY_SCROLLBAR_WIDTH + NOTE_TAB_BODY_SCROLLBAR_GAP) or 0)

    view.bodyScrollFrame:ClearAllPoints()
    view.bodyScrollFrame:SetPoint("TOPLEFT", view.bodyFrame, "TOPLEFT", NOTE_TAB_BODY_NATIVE_LEFT_INSET, -NOTE_TAB_BODY_NATIVE_TOP_INSET)
    view.bodyScrollFrame:SetPoint("BOTTOMRIGHT", view.bodyFrame, "BOTTOMRIGHT", -rightInset, NOTE_TAB_BODY_NATIVE_BOTTOM_INSET)

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetWidth(NOTE_TAB_BODY_SCROLLBAR_WIDTH)
        scrollBar:SetPoint("TOPLEFT", view.bodyFrame, "TOPRIGHT", NOTE_TAB_BODY_SCROLLBAR_LEFT_INSET + NOTE_TAB_BODY_SCROLLBAR_X_OFFSET, -(NOTE_TAB_BODY_NATIVE_TOP_INSET + NOTE_TAB_BODY_SCROLLBAR_TOP_INSET))
        scrollBar:SetPoint("BOTTOMRIGHT", view.bodyFrame, "BOTTOMRIGHT", -(NOTE_TAB_BODY_SCROLLBAR_RIGHT_INSET - NOTE_TAB_BODY_SCROLLBAR_X_OFFSET), NOTE_TAB_BODY_NATIVE_BOTTOM_INSET + NOTE_TAB_BODY_SCROLLBAR_BOTTOM_INSET)
    end

    view.bodyContent:SetWidth(self:GetNoteReadBodyVisibleWidth(view, reserveScrollbar))
    self:RefreshNoteReadLineRowHeights(view)
    view.bodyContent:SetHeight(self:GetNoteReadBodyContentHeight(view))
end

function module:RefreshNoteReadView(tab)
    local readView = self:GetNoteTabReadView(tab and tab.panel)
    if not readView then
        return
    end

    local title = self:GetNoteTabStoredTitle(tab)
    local body = tab and tab.noteData and tab.noteData.body or DEFAULT_NOTE_BODY
    readView.titleText:SetText(title)
    tab.hasPendingReadItemInfo = self:RefreshNoteReadLineRows(readView, body or DEFAULT_NOTE_BODY)
    tab.pendingReadItemIds = readView.pendingReadItemIds
    self:UpdateNoteBodyReadLayout(tab)
    self:UpdateReadItemInfoEventRegistration()
end

function module:QueueDeferredNoteReadViewRefresh(tab)
    if not tab or tab.pendingDeferredReadRefresh then
        return
    end

    tab.pendingDeferredReadRefresh = true
    C_Timer.After(0, function()
        tab.pendingDeferredReadRefresh = nil

        if not tab.panel or module:IsNoteTabInEditMode(tab) then
            return
        end

        local readView = module:GetNoteTabReadView(tab.panel)
        if not readView or not readView:IsShown() then
            return
        end

        module:RefreshNoteReadView(tab)
    end)
end

