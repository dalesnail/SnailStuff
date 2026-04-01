local _, ns = ...
local SnailStuff = ns.SnailStuff

local defaults = {
    profile = {
        enabled = true,
        window = {
            width = 920,
            height = 620,
        },
        modules = {},
    },
    global = {
        talentPlanner = {
            drafts = {},
            profiles = {},
        },
    },
}

function SnailStuff:BuildDefaults()
    local builtDefaults = self:DeepCopy(defaults)
    builtDefaults.profile.modules = builtDefaults.profile.modules or {}

    for moduleName, definition in pairs(self.moduleDefinitions) do
        local moduleDefaults = {
            enabled = definition.defaultEnabled ~= false,
        }

        if definition.defaults then
            for key, value in pairs(definition.defaults) do
                moduleDefaults[key] = value
            end
        end

        builtDefaults.profile.modules[moduleName] = moduleDefaults
    end

    return builtDefaults
end

function SnailStuff:OnInitialize()
    local aceDB = LibStub("AceDB-3.0")
    self.db = aceDB:New("SnailStuffDB", self:BuildDefaults(), true)

    local modules = self.db and self.db.profile and self.db.profile.modules
    if modules and modules.AutoCarrot and not modules.Carrot then
        modules.Carrot = self:DeepCopy(modules.AutoCarrot)
    end

    self:RegisterCorePages()
    self:SetupSlashCommands()
end
