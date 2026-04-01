local ADDON_NAME, ns = ...

local SnailStuff = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.SnailStuff = SnailStuff
_G.SnailStuff = SnailStuff

SnailStuff.ADDON_NAME = ADDON_NAME
SnailStuff.VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"

SnailStuff.moduleDefinitions = {}
SnailStuff.pageDefinitions = {}
SnailStuff.pageOrder = {}
SnailStuff.runtime = {
    modules = {},
}

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = DeepCopy(entry)
    end

    return copy
end

local function SortPages(a, b)
    if a.order == b.order then
        return a.title < b.title
    end

    return a.order < b.order
end

function SnailStuff:PrintMessage(message)
    self:Print("|cff7fdc7fSnailStuff|r: " .. (message or ""))
end

function SnailStuff:DeepCopy(value)
    return DeepCopy(value)
end

function SnailStuff:RegisterPage(definition)
    if not definition or not definition.key or not definition.title then
        return
    end

    local existing = self.pageDefinitions[definition.key]
    local entry = existing or {}
    local incomingBuild = definition.build

    for key, value in pairs(definition) do
        if key ~= "build" then
            entry[key] = value
        end
    end

    if incomingBuild then
        entry.builders = entry.builders or {}
        entry.builders[#entry.builders + 1] = incomingBuild
        entry.build = function(page)
            for index = 1, #entry.builders do
                entry.builders[index](page)
            end
        end
    end

    entry.order = entry.order or 100
    self.pageDefinitions[definition.key] = entry

    local found = false
    for _, pageKey in ipairs(self.pageOrder) do
        if pageKey == definition.key then
            found = true
            break
        end
    end

    if not found then
        table.insert(self.pageOrder, definition.key)
    end

    table.sort(self.pageOrder, function(leftKey, rightKey)
        return SortPages(self.pageDefinitions[leftKey], self.pageDefinitions[rightKey])
    end)
end

function SnailStuff:GetPages()
    local pages = {}

    for _, key in ipairs(self.pageOrder) do
        pages[#pages + 1] = self.pageDefinitions[key]
    end

    return pages
end

function SnailStuff:RefreshConfig()
    if self.RefreshConfigFrame then
        self:RefreshConfigFrame()
    end
end

function SnailStuff:RefreshAll()
    if self.RefreshAllModules then
        self:RefreshAllModules()
    end

    self:RefreshConfig()
end
