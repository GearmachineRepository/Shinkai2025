--!strict
local Players = game:GetService("Players")

local ADMINS = {
	"Odawg566",
	"SkiMag80",
	"lmCenti"
}

local AdminCommands = {}
local Commands = {}
local CommandMetadata = {}

local function IsAdmin(Player: Player): boolean
	return table.find(ADMINS, Player.Name) ~= nil
end

local function ParseCommand(Message: string): (string, {string})
	local Args = string.split(Message, " ")
	local CommandName = table.remove(Args, 1):lower()
	return CommandName, Args
end

function AdminCommands.RegisterCommand(CommandName: string, CommandData: any)
	if typeof(CommandData) == "function" then
		Commands[CommandName] = CommandData
		CommandMetadata[CommandName] = {
			Description = "No description",
			Usage = "!" .. CommandName,
		}
	elseif typeof(CommandData) == "table" then
		Commands[CommandName] = CommandData.Execute
		CommandMetadata[CommandName] = {
			Description = CommandData.Description or "No description",
			Usage = CommandData.Usage or "!" .. CommandName,
		}
	end
end

function AdminCommands.GetAllCommands()
	return CommandMetadata
end

function AdminCommands.Initialize()
	local CommandsFolder = script.Parent:WaitForChild("Commands")

	for _, CommandModule in CommandsFolder:GetChildren() do
		if CommandModule:IsA("ModuleScript") then
			local Success, Result = pcall(require, CommandModule)

			if Success then
				local CommandName = CommandModule.Name:lower()
				AdminCommands.RegisterCommand(CommandName, Result)
			else
				warn("Failed to load command:", CommandModule.Name, Result)
			end
		end
	end

	-- Pass metadata to help command after all commands are loaded
	if Commands["help"] then
		local OriginalHelp = Commands["help"]
		Commands["help"] = function(Player: Player)
			OriginalHelp(Player, CommandMetadata)
		end
	end
end

Players.PlayerAdded:Connect(function(Player)
	if not IsAdmin(Player) then
		return
	end

	Player.Chatted:Connect(function(Message)
		if Message:sub(1, 1) ~= "!" then
			return
		end

		local CommandName, Args = ParseCommand(Message:sub(2))

		local CommandFunc = Commands[CommandName]
		if not CommandFunc then
			warn("Unknown command:", CommandName)
			return
		end

		local Success, Error = pcall(CommandFunc, Player, table.unpack(Args))

		if not Success then
			warn("Command error:", Error)
		end
	end)
end)

AdminCommands.Initialize()

return AdminCommands