local _, ns = ...
local SnailStuff = ns.SnailStuff

local Data = {}
ns.TalentPlannerData = Data

local DEFAULT_TREE_COUNT = 3

local function GetNow()
    if time then
        return time()
    end

    return 0
end

local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    name = strtrim(name)
    if name == "" then
        return nil
    end

    return name
end

local function SortProfiles(profiles)
    table.sort(profiles, function(left, right)
        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")
        if leftName == rightName then
            return (left.name or "") < (right.name or "")
        end

        return leftName < rightName
    end)
end

function Data:GetClassToken()
    local _, classToken = UnitClass("player")
    return classToken or "UNKNOWN"
end

function Data:GetGlobalStore()
    if not SnailStuff.db then
        return nil
    end

    SnailStuff.db.global = SnailStuff.db.global or {}
    local store = SnailStuff.db.global.talentPlanner
    if type(store) ~= "table" then
        store = {}
        SnailStuff.db.global.talentPlanner = store
    end

    store.drafts = store.drafts or {}
    store.profiles = store.profiles or {}
    return store
end

function Data:GetTreeCount()
    local treeCount = GetNumTalentTabs and GetNumTalentTabs() or nil
    if type(treeCount) ~= "number" or treeCount < 1 then
        return DEFAULT_TREE_COUNT
    end

    return math.max(DEFAULT_TREE_COUNT, treeCount)
end

function Data:GetTalentCount(treeIndex)
    if not treeIndex or not GetNumTalents then
        return 0
    end

    local count = GetNumTalents(treeIndex)
    return type(count) == "number" and count or 0
end

function Data:BuildEmptyDraft()
    local treeCount = self:GetTreeCount()
    local draft = {
        activeTree = 1,
        trees = {},
        lastUpdated = 0,
    }

    for treeIndex = 1, treeCount do
        local tree = {}
        local talentCount = self:GetTalentCount(treeIndex)
        for talentIndex = 1, talentCount do
            tree[talentIndex] = 0
        end
        draft.trees[treeIndex] = tree
    end

    return draft
end

function Data:EnsureDraftShape(draft)
    if type(draft) ~= "table" then
        draft = self:BuildEmptyDraft()
    end

    draft.activeTree = tonumber(draft.activeTree) or 1
    draft.trees = draft.trees or {}
    draft.lastUpdated = tonumber(draft.lastUpdated) or 0

    local treeCount = self:GetTreeCount()
    for treeIndex = 1, treeCount do
        local tree = draft.trees[treeIndex]
        if type(tree) ~= "table" then
            tree = {}
            draft.trees[treeIndex] = tree
        end

        local talentCount = self:GetTalentCount(treeIndex)
        for talentIndex = 1, talentCount do
            if type(tree[talentIndex]) ~= "number" then
                tree[talentIndex] = tonumber(tree[talentIndex]) or 0
            end
        end

        for talentIndex = talentCount + 1, #tree do
            tree[talentIndex] = nil
        end
    end

    for treeIndex = treeCount + 1, #draft.trees do
        draft.trees[treeIndex] = nil
    end

    if draft.activeTree < 1 then
        draft.activeTree = 1
    elseif draft.activeTree > treeCount then
        draft.activeTree = treeCount
    end

    return draft
end

function Data:TouchDraft(draft)
    if draft then
        draft.lastUpdated = GetNow()
    end
end

function Data:GetDraft(classToken)
    classToken = classToken or self:GetClassToken()
    local store = self:GetGlobalStore()
    if not store then
        return nil
    end

    local draft = self:EnsureDraftShape(store.drafts[classToken])
    store.drafts[classToken] = draft
    return draft
end

function Data:GetProfileBucket(classToken)
    classToken = classToken or self:GetClassToken()

    local store = self:GetGlobalStore()
    if not store then
        return {}, classToken
    end

    local rawBucket = store.profiles[classToken]
    local bucket = {}

    if type(rawBucket) == "table" then
        local arrayCount = #rawBucket
        for index = 1, arrayCount do
            local profile = rawBucket[index]
            if type(profile) == "table" then
                local record = self:NormalizeProfileRecord(profile, profile.name or ("Profile " .. index))
                bucket[record.name] = record
            end
        end

        for key, value in pairs(rawBucket) do
            if type(key) ~= "number" and type(value) == "table" then
                local record = self:NormalizeProfileRecord(value, key)
                record.name = NormalizeName(key) or record.name
                bucket[record.name] = record
            end
        end
    end

    store.profiles[classToken] = bucket
    return bucket, classToken
end

function Data:NormalizeProfileRecord(profile, fallbackName)
    if type(profile) ~= "table" then
        profile = {}
    end

    local normalizedName = NormalizeName(profile.name) or NormalizeName(fallbackName) or "Profile"
    local normalizedDraft = self:EnsureDraftShape({
        activeTree = profile.activeTree,
        trees = profile.trees,
    })
    local createdAt = tonumber(profile.createdAt) or tonumber(profile.lastUpdated) or tonumber(profile.updatedAt) or 0
    local updatedAt = tonumber(profile.updatedAt) or tonumber(profile.lastUpdated) or createdAt

    return {
        name = normalizedName,
        activeTree = normalizedDraft.activeTree,
        trees = normalizedDraft.trees,
        createdAt = createdAt,
        updatedAt = updatedAt,
    }
end

function Data:GetProfiles(classToken)
    local bucket = self:GetProfileBucket(classToken)
    local profiles = {}

    for _, profile in pairs(bucket or {}) do
        profiles[#profiles + 1] = profile
    end

    SortProfiles(profiles)
    return profiles
end

function Data:CloneDraft(draft)
    draft = self:EnsureDraftShape(SnailStuff:DeepCopy(draft or self:BuildEmptyDraft()))
    return draft
end

function Data:CopyDraftIntoTarget(sourceDraft, targetDraft)
    sourceDraft = self:EnsureDraftShape(sourceDraft)
    targetDraft = self:EnsureDraftShape(targetDraft)

    targetDraft.activeTree = sourceDraft.activeTree

    for treeIndex = 1, self:GetTreeCount() do
        local sourceTree = sourceDraft.trees[treeIndex] or {}
        local targetTree = targetDraft.trees[treeIndex] or {}
        targetDraft.trees[treeIndex] = targetTree

        local talentCount = self:GetTalentCount(treeIndex)
        for talentIndex = 1, talentCount do
            targetTree[talentIndex] = tonumber(sourceTree[talentIndex]) or 0
        end

        for talentIndex = talentCount + 1, #targetTree do
            targetTree[talentIndex] = nil
        end
    end

    self:TouchDraft(targetDraft)
    return targetDraft
end

function Data:ResetDraft(classToken)
    local targetDraft = self:GetDraft(classToken)
    local emptyDraft = self:BuildEmptyDraft()
    emptyDraft.activeTree = tonumber(targetDraft and targetDraft.activeTree) or emptyDraft.activeTree
    return self:CopyDraftIntoTarget(emptyDraft, targetDraft)
end

function Data:GetProfileByName(classToken, profileName)
    profileName = NormalizeName(profileName)
    if not profileName then
        return nil
    end

    local bucket = self:GetProfileBucket(classToken)
    if bucket[profileName] then
        return bucket[profileName], profileName
    end

    local targetName = string.lower(profileName)
    for storedName, profile in pairs(bucket) do
        if string.lower(storedName) == targetName then
            if storedName ~= profileName then
                bucket[storedName] = nil
                profile.name = profileName
                bucket[profileName] = profile
            end
            return bucket[profileName], profileName
        end
    end

    return nil
end

function Data:SaveProfile(classToken, profileName, draft)
    classToken = classToken or self:GetClassToken()
    profileName = NormalizeName(profileName)
    if not profileName then
        return nil, "Invalid profile name."
    end

    local bucket = self:GetProfileBucket(classToken)
    local targetProfile = self:GetProfileByName(classToken, profileName)
    local timestamp = GetNow()

    local copy = self:CloneDraft(draft or self:GetDraft(classToken))
    bucket[profileName] = self:NormalizeProfileRecord({
        name = profileName,
        activeTree = copy.activeTree,
        trees = copy.trees,
        createdAt = tonumber(targetProfile and targetProfile.createdAt) or timestamp,
        updatedAt = timestamp,
    }, profileName)

    local store = self:GetGlobalStore()
    if store then
        store.profiles[classToken] = bucket
    end

    return bucket[profileName]
end

function Data:DeleteProfile(classToken, profileName)
    classToken = classToken or self:GetClassToken()
    profileName = NormalizeName(profileName)
    if not profileName then
        return nil, "Invalid profile name."
    end

    local bucket = self:GetProfileBucket(classToken)
    local profile, storedName = self:GetProfileByName(classToken, profileName)
    if not profile then
        return nil, "Profile not found."
    end

    bucket[storedName or profile.name or profileName] = nil

    local store = self:GetGlobalStore()
    if store then
        store.profiles[classToken] = bucket
    end

    return true
end

function Data:LoadProfileIntoDraft(classToken, profileName)
    classToken = classToken or self:GetClassToken()
    local profile = self:GetProfileByName(classToken, profileName)
    if not profile then
        return nil, "Profile not found."
    end

    local draft = self:GetDraft(classToken)
    self:CopyDraftIntoTarget(profile, draft)
    draft.activeTree = tonumber(profile.activeTree) or draft.activeTree or 1
    self:TouchDraft(draft)
    return draft, profile
end
