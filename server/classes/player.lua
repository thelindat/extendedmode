function CreateExtendedPlayer(playerId, identifier, group, accounts, weight, job, name, coords, discord)
	local self = {}

	self.accounts = accounts
	self.inventory = {}
	self.coords = coords
	self.group = group
	self.identifier = identifier
	self.job = job
	self.name = name
	self.playerId = playerId
	self.source = playerId
	self.variables = {}
	self.weight = weight
	self.discord = discord

	ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.discord, self.group))

	self.triggerEvent = function(eventName, ...)
		TriggerClientEvent(eventName, self.source, ...)
	end

	self.setCoords = function(coords)
		self.updateCoords(coords)
		self.triggerEvent('esx:teleport', coords)
	end

	self.updateCoords = function(coords)
		self.coords = {x = ESX.Math.Round(coords.x, 1), y = ESX.Math.Round(coords.y, 1), z = ESX.Math.Round(coords.z, 1), heading = ESX.Math.Round(coords.heading or 0.0, 1)}
	end

	self.getCoords = function(vector)
		if vector then
			return vector3(self.coords.x, self.coords.y, self.coords.z)
		else
			return self.coords
		end
	end

	self.kick = function(reason)
		DropPlayer(self.source, reason)
	end

	self.setMoney = function(money)
		money = ESX.Math.Round(money)
		self.setAccountMoney('money', money)
	end

	self.getBank = function()
		return self.getAccount('bank').money
	end

	self.removeBank = function(money)
		self.removeAccountMoney('bank', money)
	end

	self.addBank = function(money)
		self.addAccountMoney('bank', money)
	end

	self.getMoney = function()
		return self.getAccount('money').money
	end

	self.addMoney = function(money)
		money = ESX.Math.Round(money)
		self.addAccountMoney('money', money)
	end

	self.removeMoney = function(money)
		money = ESX.Math.Round(money)
		self.removeAccountMoney('money', money)
	end

	self.getIdentifier = function()
		return self.identifier
	end

	self.setGroup = function(newGroup)
		ExecuteCommand(('remove_principal identifier.%s group.%s'):format(self.discord, self.group))
		self.group = newGroup
		ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.discord, self.group))
	end

	self.getGroup = function()
		return self.group
	end

	self.set = function(k, v)
		self.variables[k] = v
	end

	self.get = function(k)
		return self.variables[k]
	end

	self.getAccounts = function(minimal)
		if minimal then
			local minimalAccounts = {}

			for k,v in ipairs(self.accounts) do
				minimalAccounts[v.name] = v.money
			end

			return minimalAccounts
		else
			return self.accounts
		end
	end

	self.getAccount = function(account)
		for k,v in ipairs(self.accounts) do
			if v.name == account then
				return v
			end
		end
	end

	self.setAccount = function(account)
		for k,v in ipairs(self.accounts) do
			if v.name == account.name then
				self.accounts[k] = account
			end
		end
	end

	self.getInventory = function(minimal)
		return exports['linden_inventory']:getPlayerInventory(self, minimal)
	end

	self.getJob = function()
		return self.job
	end

	self.getName = function()
		return self.name
	end

	self.setName = function(newName)
		self.name = newName
	end

	self.setAccountMoney = function(accountName, money)
		if money >= 0 then
			local account = self.getAccount(accountName)

			if account then
				local prevMoney = account.money
				local newMoney = ESX.Math.Round(money)
				account.money = newMoney
				if accountName ~= 'bank' then exports['linden_inventory']:setInventoryItem(self, accountName, money) end
				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.addAccountMoney = function(accountName, money)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money + ESX.Math.Round(money)
				account.money = newMoney
				if accountName ~= 'bank' then exports['linden_inventory']:addInventoryItem(self, accountName, money) end
				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.removeAccountMoney = function(accountName, money)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money - ESX.Math.Round(money)
				account.money = newMoney
				if accountName ~= 'bank' then exports['linden_inventory']:removeInventoryItem(self, accountName, money) end
				self.triggerEvent('esx:setAccountMoney', account)
			end
		end
	end

	self.getPlayerSlot = function(slot)
		return exports['linden_inventory']:getPlayerSlot(self, slot)
	end

	self.getInventoryItem = function(name, metadata)
		return exports['linden_inventory']:getInventoryItem(self, name, metadata)
	end

	self.addInventoryItem = function(name, count, metadata, slot)
		exports['linden_inventory']:addInventoryItem(self, name, count, metadata, slot)
	end

	self.removeInventoryItem = function(name, count, metadata)
		exports['linden_inventory']:removeInventoryItem(self, name, count, metadata)
	end

	self.setInventoryItem = function(name, count, metadata)
		exports['linden_inventory']:setInventoryItem(self, name, count, metadata)
	end

	self.getWeight = function()
		return exports['linden_inventory']:getWeight(self)
	end

	self.getMaxWeight = function()
		return exports['linden_inventory']:getMaxWeight(self)
	end

	self.canCarryItem = function(name, count)
		return exports['linden_inventory']:canCarryItem(self, name, count)
	end

	self.canSwapItem = function(firstItem, firstItemCount, testItem, testItemCount)
		return exports['linden_inventory']:canSwapItem(self, firstItem, firstItemCount, testItem, testItemCount)
	end

	self.setMaxWeight = function(newWeight)
		return exports['linden_inventory']:getMaxWeight(self, newWeight)
	end

	self.setJob = function(job, grade)
		grade = tostring(grade)
		local lastJob = json.decode(json.encode(self.job))

		if ESX.DoesJobExist(job, grade) then
			local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

			self.job.id    = jobObject.id
			self.job.name  = jobObject.name
			self.job.label = jobObject.label

			self.job.grade        = tonumber(grade)
			self.job.grade_name   = gradeObject.name
			self.job.grade_label  = gradeObject.label
			self.job.grade_salary = gradeObject.salary

			if gradeObject.skin_male then
				self.job.skin_male = json.decode(gradeObject.skin_male)
			else
				self.job.skin_male = {}
			end

			if gradeObject.skin_female then
				self.job.skin_female = json.decode(gradeObject.skin_female)
			else
				self.job.skin_female = {}
			end

			TriggerEvent('esx:setJob', self.source, self.job, lastJob)
			self.triggerEvent('esx:setJob', self.job)
		else
			print(('[ExtendedMode] [^3WARNING^7] Ignoring invalid .setJob() usage for "%s"'):format(self.discord))
		end
	end

	self.showNotification = function(msg, flash, saveToBrief, hudColorIndex)
		self.triggerEvent('esx:showNotification', msg, flash, saveToBrief, hudColorIndex)
	end

	self.showHelpNotification = function(msg, thisFrame, beep, duration)
		self.triggerEvent('esx:showHelpNotification', msg, thisFrame, beep, duration)
	end

	return self
end
