local _, ns = ...

local Data = ns.TalentPlannerData
local Logic = {}
ns.TalentPlannerLogic = Logic

local MAX_TOTAL_POINTS = 61

local function ResolveTalentIndexByGrid(treeIndex, tier, column)
    if not (treeIndex and tier and column and GetNumTalents and GetTalentInfo) then
        return nil
    end

    local talentCount = GetNumTalents(treeIndex)
    for talentIndex = 1, talentCount do
        local _, _, talentTier, talentColumn = GetTalentInfo(treeIndex, talentIndex)
        if talentTier == tier and talentColumn == column then
            return talentIndex
        end
    end

    return nil
end

function Logic:GetTreeCount()
    return Data:GetTreeCount()
end

function Logic:GetTalentCount(treeIndex)
    return Data:GetTalentCount(treeIndex)
end

function Logic:GetTalentRank(draft, treeIndex, talentIndex)
    draft = Data:EnsureDraftShape(draft)
    local tree = draft.trees[treeIndex]
    if not tree then
        return 0
    end

    return tonumber(tree[talentIndex]) or 0
end

function Logic:SetTalentRank(draft, treeIndex, talentIndex, value)
    draft = Data:EnsureDraftShape(draft)
    draft.trees[treeIndex][talentIndex] = math.max(0, tonumber(value) or 0)
end

function Logic:GetTalentInfo(treeIndex, talentIndex)
    if not (GetTalentInfo and treeIndex and talentIndex) then
        return nil
    end

    local name, iconTexture, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(treeIndex, talentIndex)
    if not name then
        return nil
    end

    local prereqTier, prereqColumn, prereqRank, prereqTalent
    if GetTalentPrereqs then
        prereqTier, prereqColumn, prereqRank = GetTalentPrereqs(treeIndex, talentIndex)
        if type(prereqTier) == "number" and prereqTier > 0
            and type(prereqColumn) == "number" and prereqColumn > 0
            and type(prereqRank) == "number" and prereqRank > 0 then
            prereqTalent = ResolveTalentIndexByGrid(treeIndex, prereqTier, prereqColumn)
        else
            prereqTier = nil
            prereqColumn = nil
            prereqRank = nil
        end
    end

    return {
        name = name,
        icon = iconTexture,
        tier = tier,
        column = column,
        currentRank = currentRank,
        maxRank = maxRank or 0,
        isExceptional = isExceptional,
        meetsPrereq = meetsPrereq,
        prereqTree = prereqTalent and treeIndex or nil,
        prereqTalent = prereqTalent,
        prereqTier = prereqTier,
        prereqColumn = prereqColumn,
        prereqRank = prereqRank,
    }
end

function Logic:GetTabInfo(treeIndex)
    if not (GetTalentTabInfo and treeIndex) then
        return nil
    end

    local first, second, third, fourth, fifth, sixth = GetTalentTabInfo(treeIndex)
    local name, iconTexture, pointsSpent, background

    if type(first) == "number" and type(second) == "string" then
        name = second
        iconTexture = fourth or third
        pointsSpent = fifth
        background = sixth
    else
        name = first
        iconTexture = second
        pointsSpent = third
        background = fourth
    end

    if not name then
        return nil
    end

    return {
        name = name,
        icon = iconTexture,
        pointsSpent = pointsSpent or 0,
        background = background,
    }
end

function Logic:GetTreePoints(draft, treeIndex)
    local total = 0
    local talentCount = self:GetTalentCount(treeIndex)
    for talentIndex = 1, talentCount do
        total = total + self:GetTalentRank(draft, treeIndex, talentIndex)
    end

    return total
end

function Logic:GetTotalPoints(draft)
    local total = 0
    for treeIndex = 1, self:GetTreeCount() do
        total = total + self:GetTreePoints(draft, treeIndex)
    end

    return total
end

function Logic:GetRequiredPointsForTier(tier)
    tier = tonumber(tier) or 1
    return math.max(0, (tier - 1) * 5)
end

function Logic:GetPointsSpentBeforeTier(draft, treeIndex, tier)
    local total = 0
    local talentCount = self:GetTalentCount(treeIndex)
    for talentIndex = 1, talentCount do
        local info = self:GetTalentInfo(treeIndex, talentIndex)
        if info and (tonumber(info.tier) or 1) < tier then
            total = total + self:GetTalentRank(draft, treeIndex, talentIndex)
        end
    end

    return total
end

function Logic:CheckRowRequirement(treeIndex, talentIndex, draft, delta)
    local info = self:GetTalentInfo(treeIndex, talentIndex)
    if not info then
        return false, "Talent data unavailable."
    end

    local pointsBeforeTier = self:GetPointsSpentBeforeTier(draft, treeIndex, tonumber(info.tier) or 1)
    return (pointsBeforeTier + (delta or 0)) >= self:GetRequiredPointsForTier(info.tier)
end

function Logic:CheckPrerequisite(treeIndex, talentIndex, draft)
    local info = self:GetTalentInfo(treeIndex, talentIndex)
    if not info then
        return false, "Talent data unavailable."
    end

    if not info.prereqTalent or not info.prereqRank or info.prereqRank < 1 then
        return true
    end

    local prereqTree = info.prereqTree or treeIndex
    local prereqRank = self:GetTalentRank(draft, prereqTree, info.prereqTalent)
    return prereqRank >= info.prereqRank
end

function Logic:ValidateTreeState(treeIndex, draft)
    local talentCount = self:GetTalentCount(treeIndex)
    for talentIndex = 1, talentCount do
        local rank = self:GetTalentRank(draft, treeIndex, talentIndex)
        if rank > 0 then
            local info = self:GetTalentInfo(treeIndex, talentIndex)
            if not info then
                return false
            end

            if rank > (info.maxRank or 0) then
                return false
            end

            if not self:CheckRowRequirement(treeIndex, talentIndex, draft, 0) then
                return false
            end

            if not self:CheckPrerequisite(treeIndex, talentIndex, draft) then
                return false
            end
        end
    end

    return true
end

function Logic:WouldRemovalInvalidateDependents(treeIndex, talentIndex, draft)
    if self:GetTalentRank(draft, treeIndex, talentIndex) <= 0 then
        return true
    end

    local testDraft = Data:CloneDraft(draft)
    self:SetTalentRank(testDraft, treeIndex, talentIndex, self:GetTalentRank(testDraft, treeIndex, talentIndex) - 1)

    if self:GetTotalPoints(testDraft) > MAX_TOTAL_POINTS then
        return true
    end

    return not self:ValidateTreeState(treeIndex, testDraft)
end

function Logic:CanAddPoint(treeIndex, talentIndex, draft)
    local info = self:GetTalentInfo(treeIndex, talentIndex)
    if not info then
        return false, "Talent data unavailable."
    end

    local rank = self:GetTalentRank(draft, treeIndex, talentIndex)
    if rank >= (info.maxRank or 0) then
        return false, "Talent is already at max rank."
    end

    if self:GetTotalPoints(draft) >= MAX_TOTAL_POINTS then
        return false, "Planner cap reached."
    end

    if not self:CheckRowRequirement(treeIndex, talentIndex, draft, 0) then
        return false, "Requires more points in this tree."
    end

    if not self:CheckPrerequisite(treeIndex, talentIndex, draft) then
        return false, "Prerequisite talent not met."
    end

    return true
end

function Logic:CanRemovePoint(treeIndex, talentIndex, draft)
    if self:GetTalentRank(draft, treeIndex, talentIndex) <= 0 then
        return false, "No points to remove."
    end

    if self:WouldRemovalInvalidateDependents(treeIndex, talentIndex, draft) then
        return false, "Removing this point would invalidate other talents."
    end

    return true
end

function Logic:AddPoint(treeIndex, talentIndex, draft)
    local canAdd, reason = self:CanAddPoint(treeIndex, talentIndex, draft)
    if not canAdd then
        return false, reason
    end

    self:SetTalentRank(draft, treeIndex, talentIndex, self:GetTalentRank(draft, treeIndex, talentIndex) + 1)
    Data:TouchDraft(draft)
    return true
end

function Logic:RemovePoint(treeIndex, talentIndex, draft)
    local canRemove, reason = self:CanRemovePoint(treeIndex, talentIndex, draft)
    if not canRemove then
        return false, reason
    end

    self:SetTalentRank(draft, treeIndex, talentIndex, self:GetTalentRank(draft, treeIndex, talentIndex) - 1)
    Data:TouchDraft(draft)
    return true
end
