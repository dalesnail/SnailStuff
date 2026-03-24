local _, ns = ...
local SnailStuff = ns.SnailStuff

function SnailStuff:ApplyModuleEnabledState(moduleName)
    local module = self:GetModule(moduleName, true)
    if not module then
        return
    end

    local shouldEnable = self:IsModuleEnabled(moduleName)
    if shouldEnable then
        if not module:IsEnabled() then
            self:EnableModule(moduleName)
        end
    elseif module:IsEnabled() then
        self:DisableModule(moduleName)
    end
end

function SnailStuff:CreateModule(moduleName, definition)
    definition = definition or {}
    definition.name = moduleName
    definition.displayName = definition.displayName or moduleName
    definition.order = definition.order or 100

    self.moduleDefinitions[moduleName] = definition

    local module = self:NewModule(moduleName, "AceEvent-3.0", "AceTimer-3.0")
    module.moduleName = moduleName
    module.displayName = definition.displayName
    module.description = definition.description
    module.definition = definition

    if definition.page then
        local pageDefinition = self:DeepCopy(definition.page)
        pageDefinition.moduleName = moduleName
        pageDefinition.order = pageDefinition.order or (200 + definition.order)
        self:RegisterPage(pageDefinition)
    end

    return module
end

function SnailStuff:GetModuleSettings(moduleName)
    local modules = self.db and self.db.profile and self.db.profile.modules
    if not modules then
        return nil
    end

    return modules[moduleName]
end

function SnailStuff:IsModuleEnabled(moduleName)
    local settings = self:GetModuleSettings(moduleName)
    return settings and settings.enabled ~= false
end

function SnailStuff:SetModuleEnabled(moduleName, enabled)
    local settings = self:GetModuleSettings(moduleName)
    if not settings then
        return
    end

    settings.enabled = enabled and true or false
    self:ApplyModuleEnabledState(moduleName)

    local module = self:GetModule(moduleName, true)
    if not module then
        self:RefreshConfig()
        return
    end

    if module:IsEnabled() and module.Refresh then
        module:Refresh()
    end

    self:RefreshConfig()
end

function SnailStuff:GetOrderedModules()
    local modules = {}

    for moduleName, definition in pairs(self.moduleDefinitions) do
        local module = self:GetModule(moduleName, true)
        modules[#modules + 1] = {
            name = moduleName,
            displayName = definition.displayName or moduleName,
            description = definition.description,
            order = definition.order or 100,
            hasPage = definition.page and true or false,
            module = module,
            enabled = self:IsModuleEnabled(moduleName),
        }
    end

    table.sort(modules, function(left, right)
        if left.order == right.order then
            return left.displayName < right.displayName
        end

        return left.order < right.order
    end)

    return modules
end

function SnailStuff:RefreshModule(moduleName)
    local module = self:GetModule(moduleName, true)
    if module and module:IsEnabled() and module.Refresh then
        module:Refresh()
    end
end

function SnailStuff:RefreshAllModules()
    for moduleName in pairs(self.moduleDefinitions) do
        self:ApplyModuleEnabledState(moduleName)
        self:RefreshModule(moduleName)
    end
end

function SnailStuff:OnEnable()
    self:RefreshAllModules()
end
