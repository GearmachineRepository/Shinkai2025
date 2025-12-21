local Character = script.Parent :: Model

task.wait(5)

warn("Stunning")

local Entity = require(game.ServerScriptService.Server.Framework.Core.Entity)
if not Entity then return end

local EntityInstance = Entity.GetEntity(Character)

if EntityInstance then
    local States = EntityInstance:GetComponent("States")
    if not States then return end

    States:SetState("Stunned", true)

    task.wait(5)

    States:SetState("Stunned", false)

end