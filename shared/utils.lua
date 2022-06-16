FRAMEWORK = nil -- To Store the metadata of exports
FRAMEWORKNAME = nil
Core = nil
OX_INVENTORY = exports.ox_inventory
RESOURCENAME = GetCurrentResourceName()
do
    if GetResourceState("JLRP-Framework") ~= "missing" then
        FRAMEWORKNAME = "JLRP-Framework"
        FRAMEWORK = exports[FRAMEWORKNAME]
        Core = FRAMEWORK:GetFrameworkObjects()
    end
end

if IsDuplicityVersion() then -- Only register the body of else in server
else
    AddEventHandler('JLRP-Framework:setPlayerData', function(key, val, last)
		if GetInvokingResource() == FRAMEWORKNAME then
			if FRAMEWORKNAME == 'JLRP-Framework' and key == 'coords' then Core.PlayerData['position'] = val end
			Core.PlayerData[key] = val
		end
	end)
end