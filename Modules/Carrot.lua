local _, ns = ...
local SnailStuff = ns.SnailStuff

local GetContainerNumSlots = GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots)
local GetContainerItemLink = GetContainerItemLink or (C_Container and C_Container.GetContainerItemLink)
local IsSubmerged = IsSubmerged or function()
    return false
end

local SLOT_HEAD = 1
local SLOT_WAIST = 6
local SLOT_FEET = 8
local SLOT_HANDS = 10
local SLOT_TRINKET_1 = 13
local SLOT_TRINKET_2 = 14

local ITEM_CARROT = 11122
local ITEM_RIDING_CROP = 25653
local ITEM_SWIFT_RIDING_CROP = 32863
local ITEM_SWIM_BELT = 7052
local ITEM_DIVING_HELM = 10506

local ENCHANT_RIDING_GLOVES = "930"
local ENCHANT_MITHRIL_SPURS = "464"

local BAG_SCAN_DELAY = 0.15
local EVALUATION_DELAY = 0.05
local WATCH_INTERVAL = 0.35
local ACTION_RETRY_DELAY = 0.75
local LOGIN_STABILIZE_DELAY = 1.25
local WARNING_THROTTLE = 90
local WARNING_DISMOUNT_BUFFER = 1.75
local WARNING_SWIM_EXIT_BUFFER = 1.25
local WARNING_SUBMERGE_EXIT_BUFFER = 1.25
local NOTIFICATION_COLOR = { 1, 0.82, 0 }

local MOUNT_TRINKET_IDS = {
    [ITEM_CARROT] = true,
    [ITEM_RIDING_CROP] = true,
    [ITEM_SWIFT_RIDING_CROP] = true,
}

local MOUNT_TRINKET_PRIORITY = {
    [ITEM_SWIFT_RIDING_CROP] = 3,
    [ITEM_RIDING_CROP] = 2,
    [ITEM_CARROT] = 1,
}

local TRACKED_SLOT_KEYS = { "trinket", "hands", "feet", "belt", "head" }
local MANAGED_EQUIPMENT_SLOTS = { SLOT_TRINKET_1, SLOT_TRINKET_2, SLOT_HANDS, SLOT_FEET, SLOT_WAIST, SLOT_HEAD }

local NORMAL_CACHE_KEYS = {
    [SLOT_TRINKET_1] = "trinket13",
    [SLOT_TRINKET_2] = "trinket14",
    [SLOT_HANDS] = "hands",
    [SLOT_FEET] = "feet",
    [SLOT_WAIST] = "belt",
    [SLOT_HEAD] = "head",
}

local module

local function EnsureItemString(itemLink)
    if not itemLink then
        return nil
    end

    return string.match(itemLink, "(item:[^|]+)") or itemLink
end

local function GetItemIDFromReference(reference)
    if not reference then
        return nil
    end

    if type(reference) == "number" then
        return reference
    end

    local itemID = string.match(reference, "item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

local function ParseBagItem(itemLink)
    if not itemLink then
        return nil, nil, nil
    end

    local itemRef = EnsureItemString(itemLink)
    local itemID, enchantID = string.match(itemRef, "item:(%d+):(%d*)")
    return itemID and tonumber(itemID) or nil, enchantID, itemRef
end

local function GetEquippedItemReference(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    return EnsureItemString(itemLink) or GetInventoryItemID("player", slot)
end

local function GetEquippedEnchantID(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then
        return nil
    end

    local itemRef = EnsureItemString(itemLink)
    return string.match(itemRef, "item:%d+:(%d*)")
end

local function NormalizeSlot(slot)
    if slot == SLOT_TRINKET_1 then
        return SLOT_TRINKET_1
    end

    return SLOT_TRINKET_2
end

module = SnailStuff:CreateModule("Carrot", {
    displayName = "Carrot",
    description = "Automatically swaps mount and swim utility gear, then restores your regular set.",
    order = 10,
    defaults = {
        enabled = true,
        notifications = false,
        warnings = false,
        carrot = true,
        ridingGloves = true,
        mithrilSpurs = true,
        swimBelt = true,
        swimHelm = true,
        disableInInstances = false,
        preferredTrinketSlot = SLOT_TRINKET_2,
        normalGearCache = {},
    },
    page = {
        key = "automation",
        title = "Automation",
        subtitle = "Automation modules live here. Carrot is currently the only configurable section.",
        order = 20,
        build = function(page)
            local function InitializeSlotDropdown(_, level)
                if level ~= 1 then
                    return
                end

                local info = UIDropDownMenu_CreateInfo()
                info.text = "Slot 1"
                info.value = SLOT_TRINKET_1
                info.checked = module:GetPreferredTrinketSlot() == SLOT_TRINKET_1
                info.func = function()
                    module:SetPreferredTrinketSlot(SLOT_TRINKET_1)
                    module:Refresh()
                    SnailStuff:RefreshConfig()
                end
                UIDropDownMenu_AddButton(info, level)

                info = UIDropDownMenu_CreateInfo()
                info.text = "Slot 2"
                info.value = SLOT_TRINKET_2
                info.checked = module:GetPreferredTrinketSlot() == SLOT_TRINKET_2
                info.func = function()
                    module:SetPreferredTrinketSlot(SLOT_TRINKET_2)
                    module:Refresh()
                    SnailStuff:RefreshConfig()
                end
                UIDropDownMenu_AddButton(info, level)
            end

            local function AttachTooltip(frame, text)
                if not frame or not text or text == "" then
                    return
                end

                frame:EnableMouse(true)
                frame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(text, 1, 0.82, 0)
                    GameTooltip:Show()
                end)
                frame:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end

            local function AddCheckboxTarget(widget, tooltip)
                AttachTooltip(widget, tooltip)
                if widget.label then
                    AttachTooltip(widget.label, tooltip)
                end
            end

            local function CreateCompactCheckbox(parent, label, key, tooltip, onClick, labelPosition)
                local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                button:SetSize(28, 28)

                button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                if labelPosition == "left" then
                    button.label:SetPoint("RIGHT", button, "LEFT", -2, 0)
                    button.label:SetJustifyH("RIGHT")
                else
                    button.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
                    button.label:SetJustifyH("LEFT")
                end
                button.label:SetText(label)

                button.key = key
                button:SetScript("OnClick", function(self)
                    local checked = self:GetChecked() and true or false
                    if onClick then
                        onClick(checked)
                    else
                        local settings = module:GetSettings()
                        settings[key] = checked
                        module:Refresh()
                        SnailStuff:RefreshConfig()
                    end
                end)

                AddCheckboxTarget(button, tooltip)
                return button
            end

            local sectionTopPadding = 8
            local sectionBottomPadding = 12
            local topRowHeight = 48
            local gridTopSpacing = 10
            local gridHeight = 100

            local carrotSection = page:CreateSection("Carrot", "")
            page:AnchorTopLevel(carrotSection)
            carrotSection:SetHeight(222)
            carrotSection.description:Hide()
            carrotSection.contentArea:ClearAllPoints()
            carrotSection.contentArea:SetPoint("TOPLEFT", carrotSection.separator, "BOTTOMLEFT", 0, -sectionTopPadding)
            carrotSection.contentArea:SetPoint("TOPRIGHT", carrotSection.separator, "BOTTOMRIGHT", 0, -sectionTopPadding)
            carrotSection.contentArea:SetHeight(1)

            local content = carrotSection.contentArea

            local topRow = CreateFrame("Frame", nil, content)
            topRow:SetPoint("TOPLEFT", 0, 0)
            topRow:SetPoint("TOPRIGHT", 0, 0)
            topRow:SetHeight(topRowHeight)

            local slotCluster = CreateFrame("Frame", nil, topRow)
            slotCluster:SetSize(204, 48)
            slotCluster:SetPoint("TOPLEFT", 0, 0)

            slotCluster.label = slotCluster:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            slotCluster.label:SetPoint("TOPLEFT", 0, -1)
            slotCluster.label:SetText("Preferred Trinket Slot")

            slotCluster.dropdown = CreateFrame("Frame", nil, slotCluster, "UIDropDownMenuTemplate")
            slotCluster.dropdown:SetPoint("TOPLEFT", slotCluster.label, "BOTTOMLEFT", -16, -2)
            UIDropDownMenu_SetWidth(slotCluster.dropdown, 116)
            UIDropDownMenu_Initialize(slotCluster.dropdown, InitializeSlotDropdown)
            AttachTooltip(slotCluster, "Choose which trinket slot Carrot should prefer for mount-speed trinkets.")
            AttachTooltip(slotCluster.label, "Choose which trinket slot Carrot should prefer for mount-speed trinkets.")
            AttachTooltip(slotCluster.dropdown, "Choose which trinket slot Carrot should prefer for mount-speed trinkets.")

            local enableToggle = CreateCompactCheckbox(topRow, "Enable", "enabled", "Turn Carrot on or off.", function(checked)
                SnailStuff:SetModuleEnabled(module.moduleName, checked)
            end, "left")
            enableToggle:SetPoint("TOPRIGHT", -6, -14)

            local notificationsToggle = CreateCompactCheckbox(topRow, "Notifications", "notifications", "Print concise yellow chat messages when Carrot equips gear automatically.", nil, "left")
            notificationsToggle:SetPoint("RIGHT", enableToggle.label, "LEFT", -16, 0)

            local warningsToggle = CreateCompactCheckbox(topRow, "Warnings", "warnings", "Warn when special Carrot gear appears stuck outside its intended state.", nil, "left")
            warningsToggle:SetPoint("RIGHT", notificationsToggle.label, "LEFT", -16, 0)

            local grid = CreateFrame("Frame", nil, content)
            grid:SetPoint("TOPLEFT", topRow, "BOTTOMLEFT", 0, -gridTopSpacing)
            grid:SetPoint("TOPRIGHT", topRow, "BOTTOMRIGHT", 0, -gridTopSpacing)
            grid:SetHeight(gridHeight)

            local leftColumn = CreateFrame("Frame", nil, grid)
            leftColumn:SetPoint("TOPLEFT", 0, 0)
            leftColumn:SetWidth(220)
            leftColumn:SetHeight(100)

            local rightColumn = CreateFrame("Frame", nil, grid)
            rightColumn:SetPoint("TOPRIGHT", 0, 0)
            rightColumn:SetWidth(220)
            rightColumn:SetHeight(100)

            local carrotToggle = CreateCompactCheckbox(leftColumn, "Carrot", "carrot", "Use Carrot on a Stick and related mount-speed trinket swapping.", nil)
            carrotToggle:SetPoint("TOPLEFT", 0, 0)

            local boots = CreateCompactCheckbox(leftColumn, "Mithril Spurs", "mithrilSpurs", "Swap in Mithril Spurs boots while mounted.")
            boots:SetPoint("TOPLEFT", carrotToggle, "BOTTOMLEFT", 0, -8)

            local helm = CreateCompactCheckbox(leftColumn, "Swim Helm", "swimHelm", "Swap in the diving helm while submerged.")
            helm:SetPoint("TOPLEFT", boots, "BOTTOMLEFT", 0, -8)

            local gloves = CreateCompactCheckbox(rightColumn, "Riding Gloves", "ridingGloves", "Swap in Riding Skill gloves while mounted.")
            gloves:SetPoint("TOPLEFT", 0, 0)

            local belt = CreateCompactCheckbox(rightColumn, "Swim Belt", "swimBelt", "Swap in the swim-speed belt while swimming.")
            belt:SetPoint("TOPLEFT", gloves, "BOTTOMLEFT", 0, -8)

            local instances = CreateCompactCheckbox(rightColumn, "Disable In Instances", "disableInInstances", "Suspend Carrot inside instances and resume outside.")
            instances:SetPoint("TOPLEFT", belt, "BOTTOMLEFT", 0, -8)

            page.rows = { enableToggle, notificationsToggle, warningsToggle, gloves, boots, instances, belt, helm, carrotToggle }
            page.slotCluster = slotCluster
            page.content:SetHeight(carrotSection:GetHeight() + sectionBottomPadding)

            page.RefreshControls = function()
                local settings = module:GetSettings()
                for _, row in ipairs(page.rows) do
                    row:SetChecked(settings[row.key] and true or false)
                end

                UIDropDownMenu_SetSelectedValue(page.slotCluster.dropdown, settings.preferredTrinketSlot)
                UIDropDownMenu_SetText(page.slotCluster.dropdown, settings.preferredTrinketSlot == SLOT_TRINKET_1 and "Slot 1" or "Slot 2")
            end
        end,
    },
})

function module:GetSettings()
    return SnailStuff:GetModuleSettings(self.moduleName)
end

function module:GetPreferredTrinketSlot()
    local settings = self:GetSettings()
    if settings.preferredTrinketSlot == SLOT_TRINKET_1 then
        return SLOT_TRINKET_1
    end

    return SLOT_TRINKET_2
end

function module:SetPreferredTrinketSlot(slot)
    slot = NormalizeSlot(slot)

    local settings = self:GetSettings()
    if settings.preferredTrinketSlot ~= slot then
        settings.preferredTrinketSlot = slot
        SnailStuff:RefreshConfig()
    end
end

function module:IsGloballyEnabled()
    return SnailStuff.db and SnailStuff.db.profile and SnailStuff.db.profile.enabled ~= false
end

function module:IsUserEnabled()
    local settings = self:GetSettings()
    return settings and settings.enabled ~= false
end

function module:EnsureRuntime()
    if self.runtime then
        return
    end

    self.runtime = {
        hasEnteredWorld = false,
        instanceSuppressed = false,
        evaluationTimer = nil,
        scanTimer = nil,
        watchTimer = nil,
        stabilizationTimer = nil,
        lastEnvironment = nil,
        stateTransitions = {
            leftMountedAt = 0,
            leftSwimmingAt = 0,
            leftSubmergedAt = 0,
        },
        warnings = {
            trinket = self:CreateWarningRecord("Mount trinket still equipped."),
            hands = self:CreateWarningRecord("Riding gloves still equipped."),
            feet = self:CreateWarningRecord("Mithril Spurs still equipped."),
            belt = self:CreateWarningRecord("Swim belt still equipped."),
            head = self:CreateWarningRecord("Diving helm still equipped."),
        },
        inventory = {
            mountItemID = nil,
            mountItemRef = nil,
            ridingGlovesRef = nil,
            spursBootsRef = nil,
        },
        slots = {
            trinket = self:CreateSlotRecord("trinket", SLOT_TRINKET_2, "carrot"),
            hands = self:CreateSlotRecord("hands", SLOT_HANDS, "riding"),
            feet = self:CreateSlotRecord("feet", SLOT_FEET, "riding"),
            belt = self:CreateSlotRecord("belt", SLOT_WAIST, "swimming"),
            head = self:CreateSlotRecord("head", SLOT_HEAD, "swimming"),
        },
    }
end

function module:CreateSlotRecord(key, slot, category)
    return {
        key = key,
        slot = slot,
        category = category,
        savedRef = nil,
        savedItemID = nil,
        desired = nil,
        active = false,
        awaiting = false,
        pendingRestore = false,
        restoreAttempted = false,
        manualOverride = false,
        lastAttemptAt = 0,
    }
end

function module:CreateWarningRecord(message)
    return {
        message = message,
        lastAt = 0,
        ready = true,
    }
end

function module:ResetSlotRecord(record)
    record.savedRef = nil
    record.savedItemID = nil
    record.desired = nil
    record.active = false
    record.awaiting = false
    record.pendingRestore = false
    record.restoreAttempted = false
    record.manualOverride = false
    record.lastAttemptAt = 0
end

function module:GetNormalGearCache()
    local settings = self:GetSettings()
    settings.normalGearCache = settings.normalGearCache or {}
    return settings.normalGearCache
end

function module:GetNormalCacheKey(slot)
    return NORMAL_CACHE_KEYS[slot]
end

function module:GetSlotIdentity(slot)
    return GetInventoryItemID("player", slot), GetEquippedEnchantID(slot), GetEquippedItemReference(slot)
end

function module:IsSpecialUtilityForSlot(slot, itemID, enchantID)
    if slot == SLOT_TRINKET_1 or slot == SLOT_TRINKET_2 then
        return itemID and MOUNT_TRINKET_IDS[itemID] or false
    end

    if slot == SLOT_HANDS then
        return enchantID == ENCHANT_RIDING_GLOVES
    end

    if slot == SLOT_FEET then
        return enchantID == ENCHANT_MITHRIL_SPURS
    end

    if slot == SLOT_WAIST then
        return itemID == ITEM_SWIM_BELT
    end

    if slot == SLOT_HEAD then
        return itemID == ITEM_DIVING_HELM
    end

    return false
end

function module:IsValidNormalSlotItem(slot, itemID, enchantID, itemRef)
    if (not itemRef and not itemID) or self:IsSpecialUtilityForSlot(slot, itemID, enchantID) then
        return false
    end

    return true
end

function module:GetPersistentNormalReference(slot)
    local cacheKey = self:GetNormalCacheKey(slot)
    if not cacheKey then
        return nil, nil
    end

    local entry = self:GetNormalGearCache()[cacheKey]
    if not entry then
        return nil, nil
    end

    return entry.ref or entry.itemID, entry.itemID
end

function module:PersistNormalItem(slot, itemRef, itemID)
    local cacheKey = self:GetNormalCacheKey(slot)
    if not cacheKey or (not itemRef and not itemID) then
        return false
    end

    local cache = self:GetNormalGearCache()
    local normalizedRef = itemRef or itemID
    local existing = cache[cacheKey]
    if existing and existing.ref == normalizedRef and existing.itemID == itemID then
        return false
    end

    cache[cacheKey] = {
        ref = normalizedRef,
        itemID = itemID,
    }

    return true
end

function module:RefreshNormalCacheForSlot(slot)
    local itemID, enchantID, itemRef = self:GetSlotIdentity(slot)
    if not self:IsValidNormalSlotItem(slot, itemID, enchantID, itemRef) then
        return false
    end

    return self:PersistNormalItem(slot, itemRef, itemID)
end

function module:RefreshNormalCacheFromEquipment()
    for _, slot in ipairs(MANAGED_EQUIPMENT_SLOTS) do
        self:RefreshNormalCacheForSlot(slot)
    end
end

function module:ResetWarningRecord(key)
    local warning = self.runtime and self.runtime.warnings and self.runtime.warnings[key]
    if not warning then
        return
    end

    warning.lastAt = 0
    warning.ready = true
end

function module:TrackStateTransitions(previousEnvironment, environment)
    local transitions = self.runtime and self.runtime.stateTransitions
    if not transitions or not previousEnvironment or not environment then
        return
    end

    local now = GetTime()

    if previousEnvironment.mounted and not environment.mounted then
        transitions.leftMountedAt = now
    end

    if previousEnvironment.swimming and not environment.swimming then
        transitions.leftSwimmingAt = now
    end

    if previousEnvironment.submerged and not environment.submerged then
        transitions.leftSubmergedAt = now
    end
end

function module:GetWarningBufferRemaining(record)
    local transitions = self.runtime and self.runtime.stateTransitions
    if not transitions then
        return 0
    end

    local now = GetTime()

    if record.key == "trinket" or record.key == "hands" or record.key == "feet" then
        return WARNING_DISMOUNT_BUFFER - (now - (transitions.leftMountedAt or 0))
    end

    if record.key == "belt" then
        return WARNING_SWIM_EXIT_BUFFER - (now - (transitions.leftSwimmingAt or 0))
    end

    if record.key == "head" then
        return WARNING_SUBMERGE_EXIT_BUFFER - (now - (transitions.leftSubmergedAt or 0))
    end

    return 0
end

function module:IsWarningEligible(record, environment)
    if not self:IsWarningOffenseActive(record) or not self:IsWarningConditionMet(record, environment) then
        return false
    end

    return self:GetWarningBufferRemaining(record) <= 0
end

function module:IsWarningConditionMet(record, environment)
    if record.key == "trinket" or record.key == "hands" or record.key == "feet" then
        return not environment.mounted and not UnitOnTaxi("player")
    end

    if record.key == "belt" then
        return not environment.swimming
    end

    if record.key == "head" then
        return not environment.submerged
    end

    return false
end

function module:IsWarningOffenseActive(record)
    local itemID, enchantID = self:GetSlotIdentity(record.slot)
    return self:IsSpecialUtilityForSlot(record.slot, itemID, enchantID)
end

function module:ProcessSlotWarning(record, environment)
    local warning = self.runtime and self.runtime.warnings and self.runtime.warnings[record.key]
    if not warning then
        return
    end

    if not self:IsWarningOffenseActive(record) or not self:IsWarningConditionMet(record, environment) then
        self:ResetWarningRecord(record.key)
        return
    end

    if not self:IsWarningEligible(record, environment) then
        self:ResetWarningRecord(record.key)
        return
    end

    if warning.ready or (GetTime() - warning.lastAt) >= WARNING_THROTTLE then
        self:Notify(warning.message)
        warning.lastAt = GetTime()
        warning.ready = false
    end
end

function module:ProcessWarnings(environment)
    local settings = self:GetSettings()

    for _, key in ipairs(TRACKED_SLOT_KEYS) do
        local record = self.runtime.slots[key]
        if not self:IsWarningOffenseActive(record) or not self:IsWarningConditionMet(record, environment) then
            self:ResetWarningRecord(record.key)
        elseif environment.operational and settings.warnings and not InCombatLockdown() then
            self:ProcessSlotWarning(record, environment)
        end
    end
end

function module:IsOperationalEnabled()
    return self:IsGloballyEnabled() and self:IsUserEnabled() and not self.runtime.instanceSuppressed
end

function module:CanProcess()
    if not self.runtime.hasEnteredWorld then
        return false
    end

    if not UnitExists("player") or not UnitIsConnected("player") then
        return false
    end

    if UnitIsDeadOrGhost("player") then
        return false
    end

    return true
end

function module:CanEquip()
    if not self:CanProcess() or InCombatLockdown() then
        return false
    end

    return not (StaticPopup1 and StaticPopup1:IsShown())
end

function module:Notify(message)
    local chatFrame = DEFAULT_CHAT_FRAME or SELECTED_CHAT_FRAME
    if chatFrame and chatFrame.AddMessage then
        chatFrame:AddMessage(message, NOTIFICATION_COLOR[1], NOTIFICATION_COLOR[2], NOTIFICATION_COLOR[3])
    else
        print(message)
    end
end

function module:FlushNotifications(notifications)
    local settings = self:GetSettings()
    if not settings.notifications or not notifications then
        return
    end

    if notifications.carrot then
        self:Notify("Carrot equipped!")
    end

    if notifications.riding then
        self:Notify("Riding gear equipped!")
    end

    if notifications.swimming then
        self:Notify("Swimming gear equipped!")
    end

    if notifications.carrotRemoved then
        self:Notify("Carrot removed!")
    end

    if notifications.ridingRemoved then
        self:Notify("Riding gear removed!")
    end

    if notifications.swimmingRemoved then
        self:Notify("Swimming gear removed!")
    end
end

function module:CreateNotificationState()
    return {
        carrot = false,
        riding = false,
        swimming = false,
        carrotRemoved = false,
        ridingRemoved = false,
        swimmingRemoved = false,
    }
end

function module:GetOtherTrinketSlot()
    if self:GetPreferredTrinketSlot() == SLOT_TRINKET_1 then
        return SLOT_TRINKET_2
    end

    return SLOT_TRINKET_1
end

function module:IsDesiredEquipped(record, desired)
    local currentItemID = GetInventoryItemID("player", record.slot)
    if desired.itemID and currentItemID ~= desired.itemID then
        return false
    end

    if desired.enchantID then
        return GetEquippedEnchantID(record.slot) == desired.enchantID
    end

    return true
end

function module:IsManagedSpecialStillEquipped(record)
    if not record.desired then
        return false
    end

    return self:IsDesiredEquipped(record, record.desired)
end

function module:ShouldRetry(record)
    return (GetTime() - (record.lastAttemptAt or 0)) >= ACTION_RETRY_DELAY
end

function module:AttemptEquip(record, reference)
    if not reference or not self:CanEquip() then
        return false
    end

    EquipItemByName(reference, record.slot)
    record.lastAttemptAt = GetTime()
    return true
end

function module:CaptureSavedItem(record)
    local itemID, enchantID, itemRef = self:GetSlotIdentity(record.slot)
    if self:IsValidNormalSlotItem(record.slot, itemID, enchantID, itemRef) then
        record.savedRef = itemRef or itemID
        record.savedItemID = itemID
        self:PersistNormalItem(record.slot, itemRef, itemID)
        return
    end

    record.savedRef, record.savedItemID = self:GetPersistentNormalReference(record.slot)
end

function module:MarkRemovalNotification(record, notifications)
    if not notifications then
        return
    end

    if record.category == "carrot" then
        notifications.carrotRemoved = true
    elseif record.category == "riding" then
        notifications.ridingRemoved = true
    elseif record.category == "swimming" then
        notifications.swimmingRemoved = true
    end
end

function module:HasPlayerReplacedManagedItem(record)
    if not record.desired or self:IsManagedSpecialStillEquipped(record) then
        return false
    end

    local currentItemID = GetInventoryItemID("player", record.slot)
    local currentRef = GetEquippedItemReference(record.slot)

    if record.active then
        return true
    end

    if record.awaiting then
        if not self:ShouldRetry(record) then
            return false
        end

        if not currentItemID and not currentRef then
            return false
        end

        if record.savedItemID and currentItemID == record.savedItemID then
            return false
        end

        if record.savedRef and currentRef == record.savedRef then
            return false
        end

        return true
    end

    return false
end

function module:FinalizeRecordState(record, wantsSpecial, notifications)
    if record.awaiting and record.desired and self:IsDesiredEquipped(record, record.desired) then
        record.awaiting = false
        record.active = true
    end

    if record.pendingRestore and not self:IsManagedSpecialStillEquipped(record) then
        if record.restoreAttempted then
            self:MarkRemovalNotification(record, notifications)
        end
        self:ResetSlotRecord(record)
        return
    end

    if wantsSpecial and (record.active or record.awaiting) and record.desired and self:HasPlayerReplacedManagedItem(record) then
        local itemID, enchantID, itemRef = self:GetSlotIdentity(record.slot)
        if self:IsValidNormalSlotItem(record.slot, itemID, enchantID, itemRef) then
            record.savedRef = itemRef or itemID
            record.savedItemID = itemID
            self:PersistNormalItem(record.slot, itemRef, itemID)
        end

        record.active = false
        record.awaiting = false
        record.pendingRestore = false
        record.restoreAttempted = false
        record.manualOverride = true
        record.desired = nil
        record.lastAttemptAt = 0
    end
end

function module:ApplyDesiredToSlot(record, desired, notifications)
    self:FinalizeRecordState(record, true, notifications)

    if record.manualOverride then
        return
    end

    if self:IsDesiredEquipped(record, desired) then
        record.desired = desired
        record.active = record.savedRef ~= nil
        record.awaiting = false
        record.pendingRestore = false
        record.restoreAttempted = false
        return
    end

    if (record.awaiting or record.active) and record.desired and record.desired.itemID == desired.itemID and record.desired.enchantID == desired.enchantID then
        if not self:ShouldRetry(record) then
            return
        end
    end

    if not record.active and not record.awaiting and not record.pendingRestore then
        self:CaptureSavedItem(record)
    end

    record.desired = desired
    record.pendingRestore = false
    record.restoreAttempted = false

    if self:AttemptEquip(record, desired.ref or desired.itemID) then
        record.awaiting = true
        record.active = false
        notifications[record.category] = true
    end
end

function module:RestoreSlot(record, notifications)
    self:FinalizeRecordState(record, false, notifications)

    if record.manualOverride and not record.active and not record.awaiting and not record.pendingRestore then
        record.manualOverride = false
        return
    end

    local restoreRef = record.savedRef
    local restoreItemID = record.savedItemID
    if not restoreRef then
        restoreRef, restoreItemID = self:GetPersistentNormalReference(record.slot)
    end

    if not restoreRef or not record.desired then
        self:ResetSlotRecord(record)
        return
    end

    if not self:IsManagedSpecialStillEquipped(record) then
        self:ResetSlotRecord(record)
        return
    end

    if record.key == "trinket" and restoreItemID and GetInventoryItemID("player", self:GetOtherTrinketSlot()) == restoreItemID then
        self:ResetSlotRecord(record)
        return
    end

    if not self:CanEquip() then
        record.pendingRestore = true
        record.restoreAttempted = false
        return
    end

    if record.pendingRestore and not self:ShouldRetry(record) then
        return
    end

    if self:AttemptEquip(record, restoreRef) then
        record.pendingRestore = true
        record.restoreAttempted = true
        record.awaiting = false
        record.active = false
    end
end

function module:HasRelevantEnvironment(environment)
    return environment and environment.operational and (environment.mounted or environment.swimming or environment.submerged) or false
end

function module:ShouldReconcileImmediately(previousEnvironment, environment)
    if not environment then
        return false
    end

    if not previousEnvironment then
        return self:HasRelevantEnvironment(environment)
    end

    if previousEnvironment.operational ~= environment.operational then
        return self:HasRelevantEnvironment(previousEnvironment) or self:HasRelevantEnvironment(environment)
    end

    return previousEnvironment.mounted ~= environment.mounted
        or previousEnvironment.swimming ~= environment.swimming
        or previousEnvironment.submerged ~= environment.submerged
end

function module:HandleStateTransition(delay)
    self:UpdateInstanceSuppression()

    local environment = self:GetEnvironmentState()
    if self:ShouldReconcileImmediately(self.runtime.lastEnvironment, environment) then
        self:EvaluateState()
    end

    self:QueueEvaluation(delay or EVALUATION_DELAY)
end

function module:GetEnvironmentState()
    local operational = self:IsOperationalEnabled()
    return {
        operational = operational,
        mounted = operational and IsMounted() and not UnitOnTaxi("player") or false,
        swimming = operational and IsSwimming() or false,
        submerged = operational and IsSubmerged() or false,
    }
end

function module:BuildDesiredState(environment)
    local settings = self:GetSettings()
    local inventory = self.runtime.inventory
    local preferredTrinketSlot = self:GetPreferredTrinketSlot()
    local trinketRecord = self.runtime.slots.trinket

    if not trinketRecord.active and not trinketRecord.awaiting and not trinketRecord.pendingRestore and not trinketRecord.savedRef then
        trinketRecord.slot = preferredTrinketSlot
    end

    local desired = {}

    if environment.mounted and UnitLevel("player") <= 70 then
        if settings.carrot and inventory.mountItemRef then
            desired.trinket = {
                ref = inventory.mountItemRef,
                itemID = inventory.mountItemID,
            }
        end

        if settings.ridingGloves and inventory.ridingGlovesRef then
            desired.hands = {
                ref = inventory.ridingGlovesRef,
                enchantID = ENCHANT_RIDING_GLOVES,
            }
        end

        if settings.mithrilSpurs and inventory.spursBootsRef then
            desired.feet = {
                ref = inventory.spursBootsRef,
                enchantID = ENCHANT_MITHRIL_SPURS,
            }
        end
    end

    if environment.swimming and settings.swimBelt then
        desired.belt = {
            ref = ITEM_SWIM_BELT,
            itemID = ITEM_SWIM_BELT,
        }
    end

    if environment.submerged and settings.swimHelm then
        desired.head = {
            ref = ITEM_DIVING_HELM,
            itemID = ITEM_DIVING_HELM,
        }
    end

    return desired
end

function module:UpdateInstanceSuppression()
    local settings = self:GetSettings()
    local shouldSuppress = false

    if settings.disableInInstances and self.runtime.hasEnteredWorld and IsInInstance then
        shouldSuppress = IsInInstance() and true or false
    end

    self.runtime.instanceSuppressed = shouldSuppress
end

function module:ScheduleInventoryScan()
    if not self:IsEnabled() then
        return
    end

    if self.runtime.scanTimer then
        self:CancelTimer(self.runtime.scanTimer, true)
    end

    self.runtime.scanTimer = self:ScheduleTimer("ScanInventory", BAG_SCAN_DELAY)
end

function module:QueueEvaluation(delay)
    if not self:IsEnabled() then
        return
    end

    if self.runtime.evaluationTimer then
        self:CancelTimer(self.runtime.evaluationTimer, true)
    end

    self.runtime.evaluationTimer = self:ScheduleTimer("EvaluateState", delay or EVALUATION_DELAY)
end

function module:RefreshWatcher(environment)
    environment = environment or self:GetEnvironmentState()

    local needsWatch = false
    if environment.operational and (environment.mounted or environment.swimming or environment.submerged) then
        needsWatch = true
    end

    for _, key in ipairs(TRACKED_SLOT_KEYS) do
        local record = self.runtime.slots[key]
        if record.awaiting or record.pendingRestore then
            needsWatch = true
            break
        end
    end

    if needsWatch and not self.runtime.watchTimer then
        self.runtime.watchTimer = self:ScheduleRepeatingTimer("EvaluateState", WATCH_INTERVAL)
    elseif not needsWatch and self.runtime.watchTimer then
        self:CancelTimer(self.runtime.watchTimer)
        self.runtime.watchTimer = nil
    end
end

function module:SelectBestMountItem(currentItemID, currentRef, candidateItemID, candidateRef)
    local currentPriority = currentItemID and MOUNT_TRINKET_PRIORITY[currentItemID] or 0
    local candidatePriority = candidateItemID and MOUNT_TRINKET_PRIORITY[candidateItemID] or 0
    if candidatePriority <= currentPriority then
        return currentItemID, currentRef
    end

    return candidateItemID, candidateRef
end

function module:ScanInventory()
    self.runtime.scanTimer = nil

    local inventory = self.runtime.inventory
    inventory.mountItemID = nil
    inventory.mountItemRef = nil
    inventory.ridingGlovesRef = nil
    inventory.spursBootsRef = nil

    for _, slot in ipairs({ SLOT_TRINKET_1, SLOT_TRINKET_2 }) do
        local itemID = GetInventoryItemID("player", slot)
        if MOUNT_TRINKET_IDS[itemID] then
            inventory.mountItemID, inventory.mountItemRef = self:SelectBestMountItem(inventory.mountItemID, inventory.mountItemRef, itemID, GetEquippedItemReference(slot) or itemID)
        end
    end

    if GetEquippedEnchantID(SLOT_HANDS) == ENCHANT_RIDING_GLOVES then
        inventory.ridingGlovesRef = GetEquippedItemReference(SLOT_HANDS)
    end

    if GetEquippedEnchantID(SLOT_FEET) == ENCHANT_MITHRIL_SPURS then
        inventory.spursBootsRef = GetEquippedItemReference(SLOT_FEET)
    end

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID, enchantID, itemRef = ParseBagItem(GetContainerItemLink and GetContainerItemLink(bag, slot))
            if itemID and MOUNT_TRINKET_IDS[itemID] then
                inventory.mountItemID, inventory.mountItemRef = self:SelectBestMountItem(inventory.mountItemID, inventory.mountItemRef, itemID, itemRef or itemID)
            end

            if enchantID == ENCHANT_RIDING_GLOVES and not inventory.ridingGlovesRef then
                inventory.ridingGlovesRef = itemRef
            elseif enchantID == ENCHANT_MITHRIL_SPURS and not inventory.spursBootsRef then
                inventory.spursBootsRef = itemRef
            end
        end
    end

    self:QueueEvaluation(EVALUATION_DELAY)
end

function module:RestoreManagedGear(notifications)
    for _, key in ipairs(TRACKED_SLOT_KEYS) do
        self:RestoreSlot(self.runtime.slots[key], notifications)
    end
end

function module:EvaluateState()
    self.runtime.evaluationTimer = nil

    if not self:CanProcess() then
        self:RefreshWatcher()
        return
    end

    self:UpdateInstanceSuppression()

    local environment = self:GetEnvironmentState()
    local notifications = self:CreateNotificationState()
    local desired = self:BuildDesiredState(environment)
    self:TrackStateTransitions(self.runtime.lastEnvironment, environment)

    if not environment.operational then
        self:RestoreManagedGear(notifications)
        self.runtime.lastEnvironment = environment
        self:FlushNotifications(notifications)
        self:RefreshWatcher(environment)
        return
    end

    for _, key in ipairs(TRACKED_SLOT_KEYS) do
        local record = self.runtime.slots[key]
        local desiredState = desired[key]
        if desiredState then
            self:ApplyDesiredToSlot(record, desiredState, notifications)
        else
            self:RestoreSlot(record, notifications)
        end
    end

    self:RefreshNormalCacheFromEquipment()
    self:ProcessWarnings(environment)

    self.runtime.lastEnvironment = environment
    self:FlushNotifications(notifications)
    self:RefreshWatcher(environment)
end

function module:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:EnsureRuntime()
    self:UpdateInstanceSuppression()
    self:ScheduleInventoryScan()
    self:QueueEvaluation()
end

function module:OnInitialize()
    self:EnsureRuntime()
end

function module:OnEnable()
    self:EnsureRuntime()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnPlayerLeavingWorld")
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "OnMountDisplayChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnStateSignal")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
    self:RegisterEvent("PLAYER_ALIVE", "OnStateSignal")
    self:RegisterEvent("PLAYER_UNGHOST", "OnStateSignal")
    self:RegisterEvent("PLAYER_STARTED_MOVING", "OnStateSignal")
    self:RegisterEvent("PLAYER_STOPPED_MOVING", "OnStateSignal")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:RegisterEvent("BAG_UPDATE", "OnInventoryChanged")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "OnEquipmentChanged")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnUnitInventoryChanged")
    self:RegisterEvent("MIRROR_TIMER_START", "OnMirrorTimerChanged")
    self:RegisterEvent("MIRROR_TIMER_STOP", "OnMirrorTimerChanged")

    self:Refresh()
end

function module:OnDisable()
    self:UnregisterAllEvents()

    if self.runtime.scanTimer then
        self:CancelTimer(self.runtime.scanTimer, true)
        self.runtime.scanTimer = nil
    end

    if self.runtime.evaluationTimer then
        self:CancelTimer(self.runtime.evaluationTimer, true)
        self.runtime.evaluationTimer = nil
    end

    if self.runtime.watchTimer then
        self:CancelTimer(self.runtime.watchTimer)
        self.runtime.watchTimer = nil
    end

    if self.runtime.stabilizationTimer then
        self:CancelTimer(self.runtime.stabilizationTimer, true)
        self.runtime.stabilizationTimer = nil
    end

    if self.runtime then
        self:RestoreManagedGear()
    end
end

function module:OnPlayerEnteringWorld()
    self.runtime.hasEnteredWorld = true
    self:ScheduleInventoryScan()
    self:HandleStateTransition()

    if self.runtime.stabilizationTimer then
        self:CancelTimer(self.runtime.stabilizationTimer, true)
    end

    self.runtime.stabilizationTimer = self:ScheduleTimer("RunLoginStabilizationPass", LOGIN_STABILIZE_DELAY)
end

function module:OnPlayerLeavingWorld()
    self.runtime.hasEnteredWorld = false

    if self.runtime.stabilizationTimer then
        self:CancelTimer(self.runtime.stabilizationTimer, true)
        self.runtime.stabilizationTimer = nil
    end

    self:RefreshWatcher({
        operational = false,
        mounted = false,
        swimming = false,
        submerged = false,
    })
end

function module:OnStateSignal()
    self:HandleStateTransition()
end

function module:OnMountDisplayChanged()
    self:HandleStateTransition(0)
end

function module:OnPlayerRegenEnabled()
    self:HandleStateTransition()
end

function module:OnUnitAura(unit)
    if unit == "player" then
        self:HandleStateTransition()
    end
end

function module:OnMirrorTimerChanged()
    self:HandleStateTransition()
end

function module:OnInventoryChanged()
    self:ScheduleInventoryScan()
end

function module:OnEquipmentChanged()
    self:ScheduleInventoryScan()
    self:QueueEvaluation()
end

function module:OnUnitInventoryChanged(unit)
    if unit == "player" then
        self:ScheduleInventoryScan()
        self:QueueEvaluation()
    end
end

function module:RunLoginStabilizationPass()
    self.runtime.stabilizationTimer = nil

    if not self:IsEnabled() or not self:CanProcess() then
        return
    end

    self:RefreshNormalCacheFromEquipment()
    self:ScheduleInventoryScan()
    self:QueueEvaluation(EVALUATION_DELAY)
end
