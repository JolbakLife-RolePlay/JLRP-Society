local Jobs = {}
local RegisteredSocieties = {}

function GetSociety(name)
	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			return RegisteredSocieties[i]
		end
	end
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		local result = MySQL.query.await('SELECT * FROM jobs')

		for i = 1, #result, 1 do
			Jobs[result[i].name] = result[i]
			Jobs[result[i].name].grades = {}
		end

		local result2 = MySQL.query.await('SELECT * FROM job_grades')

		for i = 1, #result2, 1 do
			Jobs[result2[i].job_name].grades[tostring(result2[i].grade)] = result2[i]
		end
	end
end)

AddEventHandler('JLRP-Society:registerSociety', function(name, label, account, datastore, inventory, data)
	local found = false

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			found, RegisteredSocieties[i] = true, society
			break
		end
	end

	if not found then
		table.insert(RegisteredSocieties, society)
	end
end)

AddEventHandler('JLRP-Society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('JLRP-Society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('JLRP-Society:withdrawMoney')
AddEventHandler('JLRP-Society:withdrawMoney', function(societyName, amount)
	local xPlayer = Core.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	amount = Core.Math.Round(tonumber(amount))

	if xPlayer.getJob().name == society.name then
		TriggerEvent('JLRP-Addons-Account:getSharedAccount', society.account, function(account)
			if amount > 0 and account.money >= amount then
				account.removeMoney(amount)
				xPlayer.addMoney(amount)
				xPlayer.showNotification(_U('have_withdrawn', Core.Math.GroupDigits(amount)))
			else
				xPlayer.showNotification(_U('invalid_amount'))
			end
		end)
	else
		print(('JLRP-Society: %s attempted to call withdrawMoney!'):format(xPlayer.citizenid))
	end
end)

RegisterServerEvent('JLRP-Society:depositMoney')
AddEventHandler('JLRP-Society:depositMoney', function(societyName, amount)
	local xPlayer = Core.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	amount = Core.Math.Round(tonumber(amount))

	if xPlayer.getJob().name == society.name then
		if amount > 0 and xPlayer.getMoney() >= amount then
			TriggerEvent('JLRP-Addons-Account:getSharedAccount', society.account, function(account)
				xPlayer.removeMoney(amount)
				xPlayer.showNotification(_U('have_deposited', Core.Math.GroupDigits(amount)))
				account.addMoney(amount)
			end)
		else
			xPlayer.showNotification(_U('invalid_amount'))
		end
	else
		print(('JLRP-Society: %s attempted to call depositMoney!'):format(xPlayer.citizenid))
	end
end)

RegisterServerEvent('JLRP-Society:washMoney')
AddEventHandler('JLRP-Society:washMoney', function(society, amount)
	local xPlayer = Core.GetPlayerFromId(source)
	local account = xPlayer.getAccount('black_money')
	amount = Core.Math.Round(tonumber(amount))

	if xPlayer.getJob().name == society then
		if amount and amount > 0 and account.money >= amount then
			xPlayer.removeAccountMoney('black_money', amount)

			MySQL.insert('INSERT INTO society_moneywash (citizenid, identifier, society, amount) VALUES (?, ?, ?)', {xPlayer.citizenid, xPlayer.identifier, society, amount},
			function(rowsChanged)
				xPlayer.showNotification(_U('you_have', Core.Math.GroupDigits(amount)))
			end)
		else
			xPlayer.showNotification(_U('invalid_amount'))
		end
	else
		print(('JLRP-Society: %s attempted to call washMoney!'):format(xPlayer.citizenid))
	end
end)

RegisterServerEvent('JLRP-Society:putVehicleInGarage')
AddEventHandler('JLRP-Society:putVehicleInGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('JLRP-Addons-Datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('JLRP-Society:removeVehicleFromGarage')
AddEventHandler('JLRP-Society:removeVehicleFromGarage', function(societyName, vehicle)
	local society = GetSociety(societyName)

	TriggerEvent('JLRP-Addons-Datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if garage[i].plate == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

Core.RegisterServerCallback('JLRP-Society:getSocietyMoney', function(source, cb, societyName)
	local society = GetSociety(societyName)

	if society then
		TriggerEvent('JLRP-Addons-Account:getSharedAccount', society.account, function(account)
			cb(account.money)
		end)
	else
		cb(0)
	end
end)

Core.RegisterServerCallback('JLRP-Society:getEmployees', function(source, cb, society)
	local employees = {}

	local xPlayers = Core.GetExtendedPlayers('job', society)
	for _, xPlayer in pairs(xPlayers) do

		local name = xPlayer.name
		if Config.EnableIdentity and name == GetPlayerName(xPlayer.source) then
			name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
		end

		local job = xPlayer.getJob()

		table.insert(employees, {
			name = name,
			citizenid = xPlayer.citizenid,
			job = {
				name = society,
				label = job.label,
				grade = job.grade,
				grade_name = job.grade_name,
				grade_label = job.grade_label,
				is_boss = job.is_boss,
				onDuty = job.onDuty
			}
		})
	end
		
	local query = 'SELECT citizenid, job FROM `users` WHERE job LIKE ? ORDER BY JSON_VALUE(job,"$.grade") DESC'

	if Config.EnableIdentity then
	query = 'SELECT citizenid, firstname, lastname, job FROM users WHERE job LIKE ? ORDER BY JSON_VALUE(job,"$.grade") DESC'
	end

	MySQL.query(query, {'%"name":"'..society..'"%'},
	function(result)
		for k, row in pairs(result) do
			local alreadyInTable
			local citizenid = row.citizenid

			for k, v in pairs(employees) do
				if v.citizenid == citizenid then
					alreadyInTable = true
					break
				end
			end

			if not alreadyInTable then
				local name = "Name not found." -- maybe this should be a locale instead ¯\_(ツ)_/¯

				if Config.EnableIdentity then
					name = row.firstname .. ' ' .. row.lastname 
				end
				
				local dbJob = json.decode(row.job)
				table.insert(employees, {
					name = name,
					citizenid = citizenid,
					job = {
						name = society,
						label = Jobs[society].label,
						grade = dbJob.grade,
						grade_name = Jobs[society].grades[tostring(dbJob.grade)].name,
						grade_label = Jobs[society].grades[tostring(dbJob.grade)].label,
						is_boss = Jobs[society].grades[tostring(dbJob.grade)].is_boss,
						onDuty = dbJob.onDuty
					}
				})
			end
		end

		cb(employees)
	end)

end)

Core.RegisterServerCallback('JLRP-Society:getJob', function(source, cb, society)
	local job = json.decode(json.encode(Jobs[society]))
	local grades = {}

	for k,v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

Core.RegisterServerCallback('JLRP-Society:setJob', function(source, cb, citizenid, job, grade, type)
	local xPlayer = Core.GetPlayerFromId(source)

	if xPlayer.getJob().is_boss then
		local xTarget = Core.GetPlayerFromCitizenId(citizenid)

		if xTarget then
			local previousJob = xTarget.getJob()
			xTarget.setJob(job, grade)

			if type == 'hire' then
				xTarget.showNotification(_U('you_have_been_hired', job))
			elseif type == 'promote' then
				xTarget.showNotification(_U('you_have_been_promoted'))
			elseif type == 'fire' then
				xTarget.showNotification(_U('you_have_been_fired', previousJob.label))
			end

			cb()
		else
			local temp = xPlayer.getJob()
			xPlayer.setJob(job, grade)
			MySQL.update.await('UPDATE users SET job = ? WHERE citizenid = ?', { json.encode(xPlayer.getJob()), citizenid })
			xPlayer.setJob(temp.name, temp.grade)
			xPlayer.setDuty(true)
			cb()
		end
	else
		print(('JLRP-Society: %s attempted to setJob'):format(xPlayer.citizenid))
		cb()
	end
end)

Core.RegisterServerCallback('JLRP-Society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = Core.GetPlayerFromId(source)

	if isPlayerBoss(xPlayer, job) then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {salary, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].salary = salary
				Core.RefreshJobs()
				Wait(1)
				local xPlayers = Core.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.getJob().grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
		else
			print(('JLRP-Society: %s attempted to setJobSalary over config limit!'):format(xPlayer.citizenid))
			cb()
		end
	else
		print(('JLRP-Society: %s attempted to setJobSalary'):format(xPlayer.citizenid))
		cb()
	end
end)


Core.RegisterServerCallback('JLRP-Society:setJobLabel', function(source, cb, job, grade, label)
	local xPlayer = Core.GetPlayerFromId(source)

	if isPlayerBoss(xPlayer, job) then
			MySQL.update('UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?', {label, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].label = label
				Core.RefreshJobs()
				Wait(1)
				local xPlayers = Core.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.getJob().grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
	else
		print(('JLRP-Society: %s attempted to setJobSalary'):format(xPlayer.citizenid))
		cb()
	end
end)

local getOnlinePlayers, onlinePlayers = false, {}
Core.RegisterServerCallback('JLRP-Society:getOnlinePlayers', function(source, cb)
	if getOnlinePlayers == false and next(onlinePlayers) == nil then -- Prevent multiple xPlayer loops from running in quick succession
		getOnlinePlayers, onlinePlayers = true, {}
		
		local xPlayers = Core.GetExtendedPlayers()
		for _, xPlayer in pairs(xPlayers) do
			table.insert(onlinePlayers, {
				source = xPlayer.source,
				citizenid = xPlayer.citizenid,
				name = xPlayer.name,
				job = xPlayer.getJob()
			})
		end
		cb(onlinePlayers)
		getOnlinePlayers = false
		Wait(1000) -- For the next second any extra requests will receive the cached list
		onlinePlayers = {}
		return
	end
	while getOnlinePlayers do Wait(0) end -- Wait for the xPlayer loop to finish
	cb(onlinePlayers)
end)

Core.RegisterServerCallback('JLRP-Society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)

	TriggerEvent('JLRP-Addons-Datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

Core.RegisterServerCallback('JLRP-Society:isBoss', function(source, cb, job)
	local xPlayer = Core.GetPlayerFromId(source)
	cb(isPlayerBoss(xPlayer, job))
end)

function isPlayerBoss(xPlayer, job)
	local xPlayerJob = xPlayer.getJob()

	if xPlayerJob.name == job and xPlayerJob.is_boss == true then
		return true
	else
		print(('JLRP-Society: %s attempted open a society boss menu!'):format(xPlayer.citizenid))
		return false
	end
end

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i=1, #result, 1 do
			local society = GetSociety(result[i].society)
			local xPlayer = Core.GetPlayerFromCitizenId(result[i].citizenid)

			-- add society money
			TriggerEvent('JLRP-Addons-Account:getSharedAccount', society.account, function(account)
				account.addMoney(result[i].amount)
			end)

			-- send notification if player is online
			if xPlayer then
				xPlayer.showNotification(_U('you_have_laundered', Core.Math.GroupDigits(result[i].amount)))
			end

		end
		MySQL.update('DELETE FROM society_moneywash')
	end)
end

-- TODO
--TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)