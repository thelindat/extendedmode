RegisterNetEvent('esx:onPlayerJoined')
AddEventHandler('esx:onPlayerJoined', function(src, slot)
	if not ESX.Players[src] then
		onPlayerJoined(src, slot)
	end
end)

function onPlayerJoined(playerId, slot)
	local discord
	local license
	
	for k,v in ipairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, Config.PrimaryIdentifier) then
			discord = v
		end
		if string.match(v, 'license:') then
			license = v
		end
	end

	if discord then
		if ESX.GetPlayerFromIdentifier(discord) then
			DropPlayer(playerId, ('there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			exports.ghmattimysql:scalar('SELECT 1 FROM users WHERE discord = @discord AND slot = @slot', {
				['@discord'] = discord,
				['@slot'] = slot
			}, function(result)
				if result then
					loadESXPlayer(slot, playerId, discord)
				else
					local accounts = {}

					for account,money in pairs(Config.StartingAccountMoney) do
						accounts[account] = money
					end

					exports.ghmattimysql:execute('INSERT INTO users (accounts, discord, license, slot) VALUES (@accounts, @discord, @license, @slot)', {
						['@accounts'] = json.encode(accounts),
						['@discord'] = discord,
						['@license'] = license,
						['@slot'] = slot
					}, function(rowsChanged)
						loadESXPlayer(slot, playerId, discord, true)
					end)
				end
			end)
		end
	else
		DropPlayer(playerId, 'there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
	deferrals.defer()
	local playerId, discord = source
	Wait(100)

	for k,v in ipairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, Config.PrimaryIdentifier) then
			discord = v
			break
		end
	end

	if not ExM.DatabaseReady then
		deferrals.update("The database is not initialized, please wait...")
		while not ExM.DatabaseReady do
			Wait(1000)
		end
	end

	if discord then
		if ESX.GetPlayerFromIdentifier(discord) then
			deferrals.done(('There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			deferrals.done()
		end
	else
		deferrals.done('There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end)


function loadESXPlayer(slot, playerId, discord, isNew)
	
	local userData = {
		accounts = {},
		inventory = {},
		job = {},
		playerName = GetPlayerName(playerId),
		weight = 0
	}

	exports.ghmattimysql:execute('SELECT identifier, accounts, job, job_grade, `group`, position, inventory, status FROM users WHERE slot = @slot AND discord = @discord', {
		['@slot'] = slot,
		['@discord'] = discord
	}, function(result)
		local identifier = result[1].identifier

		local job, grade, jobObject, gradeObject = result[1].job, tostring(result[1].job_grade)
		local foundAccounts, foundItems = {}, {}

		-- Accounts
		if result[1].accounts and result[1].accounts ~= '' then
			local accounts = json.decode(result[1].accounts)

			for account,money in pairs(accounts) do
				foundAccounts[account] = money
			end
		end

		for account,label in pairs(Config.Accounts) do
			table.insert(userData.accounts, {
				name = account,
				money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
				label = label
			})
		end

		-- Job
		if ESX.DoesJobExist(job, grade) then
			jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
		else
			print(('[ExtendedMode] [^3WARNING^7] Ignoring invalid job for %s [job: %s, grade: %s]'):format(identifier, job, grade))
			job, grade = 'unemployed', '0'
			jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
		end

		userData.job.id = jobObject.id
		userData.job.name = jobObject.name
		userData.job.label = jobObject.label

		userData.job.grade = tonumber(grade)
		userData.job.grade_name = gradeObject.name
		userData.job.grade_label = gradeObject.label
		userData.job.grade_salary = gradeObject.salary

		userData.job.skin_male = {}
		userData.job.skin_female = {}

		if gradeObject.skin_male then userData.job.skin_male = json.decode(gradeObject.skin_male) end
		if gradeObject.skin_female then userData.job.skin_female = json.decode(gradeObject.skin_female) end

		-- Inventory
		if result[1].inventory and result[1].inventory ~= '' then
			userData.inventory = json.decode(result[1].inventory)
		end

		-- Group
		if result[1].group then
			userData.group = result[1].group
		else
			userData.group = 'user'
		end

		-- Position
		if result[1].position and result[1].position ~= '' then
			userData.coords = json.decode(result[1].position)
		else
			--print('[ExtendedMode] [^3WARNING^7] Column "position" in "users" table is missing required default value. Using backup coords, fix your database.')
			userData.coords = Config.FirstSpawnCoords
		end


		-- Create Extended Player Object
		local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.weight, userData.job, userData.playerName, userData.coords, discord)
		ESX.Players[playerId] = xPlayer
		TriggerEvent('linden_inventory:setPlayerInventory', xPlayer, userData.inventory)
		TriggerEvent('esx:playerLoaded', playerId, xPlayer, isNew)
		xPlayer.triggerEvent('esx:loadPlayerData', {
			accounts = xPlayer.getAccounts(),
			coords = xPlayer.getCoords(),
			identifier = xPlayer.identifier,
			inventory = xPlayer.getInventory(),
			discord = xPlayer.discord,
			job = xPlayer.getJob(),
			money = xPlayer.getMoney()
		}, isNew)
		local status = {}
		if result[1].status then
			status = json.decode(result[1].status)
		end
		xPlayer.set('status', status)
		TriggerClientEvent('esx_status:load', playerId, status)
		xPlayer.triggerEvent('esx:registerSuggestions', ESX.RegisteredCommands)
	end)
end

AddEventHandler('chatMessage', function(playerId, author, message)
	if message:sub(1, 1) == '/' and playerId > 0 then
		CancelEvent()
		local commandName = message:sub(1):gmatch("%w+")()
		TriggerClientEvent('chat:addMessage', playerId, {args = {'^1SYSTEM', _U('commanderror_invalidcommand', commandName)}})
	end
end)

RegisterCommand('relog', function(source, args, raw)
	TriggerEvent('esx:playerLogout', source)
end, false)

AddEventHandler('esx:playerLogout', function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer then
		TriggerEvent('esx:playerDropped', source, reason)
		ESX.SavePlayer(xPlayer, function()
			ESX.Players[source] = nil
		end)
	end
	TriggerClientEvent("esx:onPlayerLogout",source)
  end)

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		TriggerEvent('esx:playerDropped', playerId, reason)

		ESX.SavePlayer(xPlayer, function()
			ESX.Players[playerId] = nil
		end)
	end
end)

RegisterNetEvent('esx:updateCoords')
AddEventHandler('esx:updateCoords', function(coords)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

RegisterNetEvent('esx:updateWeaponAmmo')
AddEventHandler('esx:updateWeaponAmmo', function()
	local playerId = source
	--Trigger automated ban
end)

RegisterNetEvent('esx:giveInventoryItem')
AddEventHandler('esx:giveInventoryItem', function()
	local playerId = source
	--Trigger automated ban
end)

RegisterNetEvent('esx:useItem')
AddEventHandler('esx:useItem', function(source, itemName)
	--[[ Shouldn't need this anymore
	local xPlayer = ESX.GetPlayerFromId(source)
	local item = xPlayer.getInventoryItem(itemName)
	if item.count > 0 then
		if item.closeonuse then TriggerClientEvent('linden_inventory:closeInventory', source) end
		ESX.UseItem(source, itemName)
	end
]]
end)

ESX.RegisterServerCallback('esx:getPlayerData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getPlayerNames', function(source, cb, players)
	players[source] = nil

	for playerId,v in pairs(players) do
		local xPlayer = ESX.GetPlayerFromId(playerId)

		if xPlayer then
			players[playerId] = xPlayer.getName()
		else
			players[playerId] = nil
		end
	end

	cb(players)
end)
