local isSpawned, isPaused, isDead = false, false, false

RegisterNetEvent('esx:loadPlayerData')
AddEventHandler('esx:loadPlayerData', function(playerData, new)
	ESX.PlayerLoaded = true
	ESX.PlayerData = playerData

	local playerPed = PlayerPedId()

	if Config.EnablePvP then
		SetCanAttackFriendly(playerPed, true, false)
		NetworkSetFriendlyFireOption(true)
	end

	if Config.EnableHud then
		for k,v in ipairs(playerData.accounts) do
			local accountTpl = '<div><img src="img/accounts/' .. v.name .. '.png"/>&nbsp;{{money}}</div>'
			ESX.UI.HUD.RegisterElement('account_' .. v.name, k, 0, accountTpl, {money = ESX.Math.GroupDigits(v.money)})
		end

		local jobTpl = '<div>{{job_label}} - {{grade_label}}</div>'

		if playerData.job.grade_label == '' or playerData.job.grade_label == playerData.job.label then
			jobTpl = '<div>{{job_label}}</div>'
		end

		ESX.UI.HUD.RegisterElement('job', #playerData.accounts, 0, jobTpl, {
			job_label = playerData.job.label,
			grade_label = playerData.job.grade_label
		})
	end

	-- Using spawnmanager now to spawn the player, this is the right way to do it, and it transitions better.
	exports.spawnmanager:spawnPlayer({
		x = playerData.coords.x,
		y = playerData.coords.y,
		z = playerData.coords.z,
		heading = playerData.coords.heading,
		model = Config.DefaultPlayerModel,
		skipFade = true
	}, function()
		DoScreenFadeOut(500)
		SetTimecycleModifier('default')
		local pos = GetEntityCoords(PlayerPedId())
		cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x,pos.y,pos.z+200, 300.00,0.00,0.00, 100.00, false, 0)
		PointCamAtCoord(cam, pos.x,pos.y,pos.z+2)
		SetCamActiveWithInterp(cam, cam2, 2200, true, true)
		Citizen.Wait(500)
		TriggerEvent('esx:playerLoaded', ESX.PlayerData)
		TriggerEvent('esx:onPlayerSpawn')
		TriggerServerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx_ambulancejob:multicharacter')
		TriggerEvent('chat:toggleChat', false)
		if isNew then TriggerEvent('skinchanger:loadDefaultModel') else TriggerEvent('skinchanger:loadSkin') end
		DoScreenFadeIn(500)
		Citizen.Wait(1700)
		
		PlaySoundFrontend(-1, "Zoom_Out", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
		RenderScriptCams(false, true, 500, true, true)
		PlaySoundFrontend(-1, "CAR_BIKE_WHOOSH", "MP_LOBBY_SOUNDS", 1)
		FreezeEntityPosition(PlayerPedId(), false)
		
		Citizen.Wait(500)
		
		SetCamActive(cam, false)
		DestroyCam(cam, true)
		IsChoosing = false
			
		DisplayHud(true)
		DisplayRadar(true)
		ESX.UI.HUD.SetDisplay(1.0)
	
		StartUpdating()
	end)
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
	Logout()
end)

function Logout()
	ESX.PlayerLoaded = false
	ESX.PlayerData = nil
	isSpawned = false
	TriggerServerEvent("kashactersS:SetupCharacters")
	TriggerEvent("kashactersC:SetupCharacters")
end

RegisterNetEvent('es:activateMoney')
AddEventHandler('es:activateMoney', function(money)
	ESX.PlayerData.money = money
end)

RegisterNetEvent('esx:setMaxWeight')
AddEventHandler('esx:setMaxWeight', function(newMaxWeight) ESX.PlayerData.maxWeight = newMaxWeight end)

AddEventHandler('esx:onPlayerSpawn', function() isDead = false isSpawned = true end)
AddEventHandler('esx:onPlayerDeath', function() isDead = true end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
	for k,v in ipairs(ESX.PlayerData.accounts) do
		if v.name == account.name then
			ESX.PlayerData.accounts[k] = account
			break
		end
	end

	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('account_' .. account.name, {
			money = ESX.Math.GroupDigits(account.money)
		})
	end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx:teleport')
AddEventHandler('esx:teleport', function(coords)
	-- The coords x, y and z were having 0.0 added to them here to make them floats
	-- Since we are forcing vectors in the teleport function now we don't need to do it
	ESX.Game.Teleport(PlayerPedId(), coords)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('job', {
			job_label   = job.label,
			grade_label = job.grade_label
		})
	end
end)

RegisterNetEvent('esx:spawnVehicle')
AddEventHandler('esx:spawnVehicle', function(vehicle)
	if IsModelInCdimage(vehicle) then
		local playerPed = PlayerPedId()
		local playerCoords, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)


		if IsPedInAnyVehicle(playerPed, true) then
			local vehicle = GetVehiclePedIsIn(playerPed, false)
			ESX.Game.DeleteVehicle(vehicle)
		end

		ESX.Game.SpawnVehicle(vehicle, playerCoords, playerHeading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		end)
	else
		TriggerEvent('chat:addMessage', { args = { '^1SYSTEM', 'Invalid vehicle model.' } })
	end
end)

RegisterNetEvent('esx:registerSuggestions')
AddEventHandler('esx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

RegisterNetEvent('esx:deleteVehicle')
AddEventHandler('esx:deleteVehicle', function(radius)
	local playerPed = PlayerPedId()

	if radius and tonumber(radius) then
		radius = tonumber(radius) + 0.01
		local vehicles = ESX.Game.GetVehiclesInArea(GetEntityCoords(playerPed), radius)

		for k,entity in ipairs(vehicles) do
			local attempt = 0

			while not NetworkHasControlOfEntity(entity) and attempt < 100 and DoesEntityExist(entity) do
				Wait(100)
				NetworkRequestControlOfEntity(entity)
				attempt = attempt + 1
			end

			if DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
				ESX.Game.DeleteVehicle(entity)
			end
		end
	else
		local vehicle, attempt = ESX.Game.GetVehicleInDirection(), 0

		if IsPedInAnyVehicle(playerPed, true) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		end

		while not NetworkHasControlOfEntity(vehicle) and attempt < 100 and DoesEntityExist(vehicle) do
			Wait(100)
			NetworkRequestControlOfEntity(vehicle)
			attempt = attempt + 1
		end

		if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
			ESX.Game.DeleteVehicle(vehicle)
		end
	end
end)

-- Pause menu disables HUD display
if Config.EnableHud then
	CreateThread(function()
		while true do
			Wait(300)

			if IsPauseMenuActive() and not isPaused then
				isPaused = true
				ESX.UI.HUD.SetDisplay(0.0)
			elseif not IsPauseMenuActive() and isPaused then
				isPaused = false
				ESX.UI.HUD.SetDisplay(1.0)
			end
		end
	end)
end

-- Disable wanted level
if Config.DisableWantedLevel then
	-- Previous they were creating a contstantly running loop to check if the wanted level
	-- changed and then setting back to 0. This is all thats needed to disable a wanted level.
	SetMaxWantedLevel(0)
end

function StartUpdating()
	CreateThread(function()
		local previousCoords = vector3(ESX.PlayerData.coords.x, ESX.PlayerData.coords.y, ESX.PlayerData.coords.z)
		local playerHeading = ESX.PlayerData.heading
		local formattedCoords = {x = ESX.Math.Round(previousCoords.x, 1), y = ESX.Math.Round(previousCoords.y, 1), z = ESX.Math.Round(previousCoords.z, 1), heading = playerHeading}

		while isSpawned do
			local playerPed = PlayerPedId()
			local playerCoords = GetEntityCoords(playerPed)
			local distance = #(playerCoords - previousCoords)

			if distance >= 5 then
				previousCoords = playerCoords
				playerHeading = ESX.Math.Round(GetEntityHeading(playerPed), 1)
				formattedCoords = {x = ESX.Math.Round(playerCoords.x, 1), y = ESX.Math.Round(playerCoords.y, 1), z = ESX.Math.Round(playerCoords.z, 1), heading = playerHeading}
				TriggerServerEvent('esx:updateCoords', formattedCoords)
			end
			Wait(1000)
		end
	end)
end
