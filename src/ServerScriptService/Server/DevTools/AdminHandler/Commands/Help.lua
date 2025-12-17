--!strict

return {
	Description = "Show all available commands",
	Usage = "!help",
	Execute = function(_: Player, CommandMetadata: {[string]: any})
		print("=== ADMIN COMMANDS ===")

		local CommandNames = {}

		for CommandName, _ in CommandMetadata do
			table.insert(CommandNames, CommandName)
		end

		table.sort(CommandNames)

		for _, CommandName in CommandNames do
			local Metadata = CommandMetadata[CommandName]
			print(string.format("  %s - %s", Metadata.Usage, Metadata.Description))
		end
	end
}