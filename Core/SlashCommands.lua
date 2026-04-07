local _, ns = ...
local SnailStuff = ns.SnailStuff

BINDING_NAME_SNAILSTUFF_TOGGLE_NOTES = "Toggle Notes Window"

function SnailStuff_ToggleNotesBinding()
    if SnailStuff and SnailStuff.ToggleNotesWindow then
        SnailStuff:ToggleNotesWindow()
    end
end

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
    self:RegisterChatCommand("ssnotes", "HandleNotesSlashCommand")
    self:RegisterChatCommand("notes", "HandleNotesSlashCommand")
end

function SnailStuff:OpenNotesWindow()
    local module = self:GetModule("Notes", true)
    if not module or not module.OpenWindow then
        self:PrintMessage("Notes is not available.")
        return
    end

    module:OpenWindow()
end

function SnailStuff:CloseNotesWindow()
    local module = self:GetModule("Notes", true)
    if not module or not module.CloseWindow then
        return
    end

    module:CloseWindow()
end

function SnailStuff:ToggleNotesWindow()
    local module = self:GetModule("Notes", true)
    if not module or not module.OpenWindow or not module.CloseWindow then
        self:PrintMessage("Notes is not available.")
        return
    end

    if module.IsWindowOpen and module:IsWindowOpen() then
        module:CloseWindow()
        return
    end

    module:OpenWindow()
end

function SnailStuff:HandleNotesSlashCommand()
    self:ToggleNotesWindow()
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

    if command == "notes" then
        self:ToggleNotesWindow()
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

    self:PrintMessage("Commands: /ss, /ss automation, /ss about, /ss notes, /ss module carrot, /ssnotes, /notes")
end
