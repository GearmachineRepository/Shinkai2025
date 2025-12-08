--!nonstrict
local IronSkin = {
	Name = "IronSkin",
	Description = "Reduce all damage taken by 10%",
}

function IronSkin.Register(Controller)
	return Controller.ModifierRegistry:Register("Damage", 100, function(Damage, _)
		return Damage * 0.9
	end)
end

return IronSkin