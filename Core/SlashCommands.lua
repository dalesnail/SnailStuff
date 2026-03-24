local _, ns = ...
local SnailStuff = ns.SnailStuff

local function NormalizeToken(value)
    if not value then
        return nil
    end

    value = strtrim(value)
    if value == "" then
        return nil
    end

    return string.lower(value)
end

function SnailStuff:SetupSlashCommands()
    self:RegisterChatCommand("snailstuff", "HandleSlashCommand")
    self:RegisterChatCommand("snail", "HandleSlashCommand")
    self:RegisterChatCommand("ss", "HandleSlashCommand")
end

function SnailStuff:HandleSlashCommand(input)
    local command, remainder = self:GetArgs(input or "", 1)
    command = NormalizeToken(command)

    if not command or command == "config" or command == "options" then
        self:OpenConfig()
        return
    end

    if command == "modules" or command == "automation" then
        self:OpenConfig("automation")
        return
    end

    if command == "about" then
        self:OpenConfig("about")
        return
    end

    local target = NormalizeToken(remainder)
    if command == "module" and target then
        for moduleName, definition in pairs(self.moduleDefinitions) do
            local page = definition.page
            if page and (string.lower(moduleName) == target or target == "carrot" or target == "autocarrot") then
                self:OpenConfig(page.key)
                return
            end
        end
    end

    self:PrintMessage("Commands: /ss, /ss automation, /ss about, /ss module carrot")
end
