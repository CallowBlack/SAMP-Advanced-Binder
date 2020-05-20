module = {}
module.__name__ = "Standart"
module.__authors__ = "Callow"
module.__version__ = "1.0"


local function clock() return math.floor(os.clock() * 1000) end

local sampev = require("lib.samp.events")
local keys = require("lib.vkeys")
local encoding = require 'encoding'

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local keysClicked = {}
local function main()
	while true do
		wait(1)
		if #keysClicked > 0 then
			for i, v in ipairs(keysClicked) do
				local dur = clock() - v.start
				if isKeyDown(v.id) and dur > v.duration then
					setVirtualKeyDown(v.id, false)
					table.remove(keysClicked, i)
				elseif not isKeyDown(v.id) then
					table.remove(keysClicked, i)
				end
			end
		end
	end
end

local function getMyId()
	local r, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
	return id and tostring(id) or ""
end

local function getMyNick()
	local number = tonumber(getMyId())
	return number and sampGetPlayerNickname(number) or ""
end

local function getMyName()
	return getMyNick():gsub("_", " ", 1)
end

local function getMyFirst()
	return getMyNick():match("^([^_]+)_")
end

local function getMySecond()
	return getMyNick():match("_(.+)$")
end

local function getNearbyChar()
	local mindist = 9999
	local mped = PLAYER_PED
	local mx, my, mz = getCharCoordinates(mped)
	for k, v in pairs(getAllChars()) do
		local id, r = sampGetPlayerIdByCharHandle(v)
		if PLAYER_PED ~= v and r and r ~= -1 then
			local x, y, z = getCharCoordinates(v)
			local distation = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2 + (mz - z) ^ 2)
			if distation < mindist then
				mped = v
				mindist = distation
			end
		end
	end
	return mped
end

local function getTargetPed()
	local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)
	if not result or sampGetPlayerIdByCharHandle(ped) == -1 then
		ped = getNearbyChar()
	end
	return ped
end

local function getTargetId()
	local r, id = sampGetPlayerIdByCharHandle(getTargetPed())
	return id and tostring(id) or ""
end

local function getTagetNick()
	local number = tonumber(getTargetId())
	return number and sampGetPlayerNickname(number) or ""
end

local function getTagetName()
	return getTagetNick():gsub("_", " ", 1)
end

local function getTagetFirst()
	return getTagetNick():match("^([^_]+)_")
end

local function getTagetSecond()
	return getTagetNick():match("_(.+)")
end

local function pressKey(key, duration)
	duration = tonumber(duration) or 100
	key = key or ""
	local res = keys.name_to_id(key, false)
	if res then
		if duration ~= -1 then
			table.insert(keysClicked, {id = res, start = clock(), duration = duration})
		end
		setVirtualKeyDown(res, true)
	end
end

local function set(t)
	local set = {}
	for i, v in ipairs(t) do
		set[v] = true
	end
	return set
end
-- https://wiki.multitheftauto.com/wiki/Female_Skins --
local females = set{9, 10, 11, 12, 13, 31, 38, 39, 40, 41,
53, 54, 55, 56, 63, 64, 69, 75, 76, 77, 85, 87, 88, 89,
90, 91, 92, 93, 129, 130, 131, 138, 139, 140, 141, 145,
148, 150, 151, 152, 157, 169, 172, 178, 190, 191, 192,
193, 194, 195, 196, 197, 198, 199, 201, 205, 207, 211,
214, 215, 216, 218, 219, 224, 225, 226, 231, 232, 233,
237, 238, 243, 244, 245, 246, 251, 256, 257, 263, 298, 304}

local function maleChoise(male, female)
	male = male or ""
	female = female or ""
	return females[getCharModel(getTargetPed())] and female or male
end

module.__options__ = { thread = main }

module.__keywords__ = {
	{
		name = "myId",
		description_EN = "Returns your id.",
		description_RU = "Возвращает ваш id.",
		func = getMyId
	},
	{
		name = "myNick",
		description_EN = "Returns your nick.",
		description_RU = "Возвращает ваш ник.",
		func = getMyNick
	},
	{
		name = "myFullName",
		description_EN = "Returns your nick without '_'.",
		description_RU = "Возвращает ваше имя и фамилию (ник без '_').",
		func = getMyName
	},
	{
		name = "myFirstName",
		description_EN = "Returns your first name. (Part of nick before '_')",
		description_RU = "Возвращает ваше имя.",
		func = getMyFirst
	},
 	{
		name = "mySecondName",
		description_EN = "Returns your second name. (Part of nick after '_')",
		description_RU = "Возвращает вашу фамилию.",
		func = getMySecond
	},
	{
		name = "targetId",
		description_EN = "Returns player's id you are targeting.\nIf you aren't targeting returns nearest player's id.",
		description_RU = "Возвращает id игрока на которого вы целитесь.\nЕсли вы не целитесь вернёт id ближайшего человека.",
		func = getTargetId
	},
	{
		name = "targetNick",
		description_EN = "Returns player's nick you are targeting.\nIf you aren't targeting returns nearest player's nick.",
		description_RU = "Возвращает ник игрока на которого вы целитесь.\nЕсли вы не целитесь вернёт ник ближайшего человека.",
		func = getTagetNick
	},
	{
		name = "targetFullName",
		description_EN = "Returns player's nick you are targeting without '_'.\nIf you aren't targeting returns nearest player's fullname.",
		description_RU = "Возвращает имя и фамилию игрока (ник без '_') на которого вы целитесь.\nЕсли вы не целитесь вернёт ИФ ближайшего человека.",
		func = getTagetName
	},
	{
		name = "targetFirstName",
		description_EN = "Returns player's first name you are targeting. (Part of nick before '_')\nIf you aren't targeting returns nearest player's first name.",
		description_RU = "Возвращает имя игрока на которого вы целитесь.\nЕсли вы не целитесь вернёт имя ближайшего человека.",
		func = getTagetFirst
	},
	{
		name = "targetSecondName",
		description_EN = "Returns player's second name you are targeting. (Part of nick after '_')\nIf you aren't targeting returns nearest player's second name.",
		description_RU = "Возвращает фамилию игрока на которого вы целитесь.\nЕсли вы не целитесь вернёт фамилию ближайшего человека.",
		func = getTagetSecond
	},
	{
		name = "targetSexChoice",
		description_EN = "Returns one of parameters according to sex player you are targeting. \nIf you aren't targeting choose nearest player.",
		parameters_EN = { "Return this parameter if player is male. Required.", "Return this parameter if player is female. Required." },
		description_RU = "Возвращает один из переданных параметров в зависимости от пола игрока на которого вы целитесь.\nЕсли вы не целитесь выберет ближайшего игрока.",
		parameters_RU = { "Вернёт этот параметр если игрок 'мужчина'. Обязателен.", "Вернёт этот параметр если игрок 'женщина'. Обязателен."},
		func = maleChoise
	},
	--  {
	--  name = "screenshot",
	-- 	description_EN = "Making screenshot.",
	-- 	description_RU = "Делает скриншот. Ничего не возвращает!",
	-- 	func = nil
	-- },
 	{
		name = "pressKey",
		description_EN = "Press key.",
		description_RU = "Нажимает на указаную клавишу. Ничего не возвращает!",
		parameters_EN = { "Key name to press. Required.", "Duration of key press in milliseconds. Optional (Default = 100 ms)." },
		parameters_RU = { "Название клавиши. Обязателен.", "Время задержки до отжатия клавиши в милисекундах. \nЕсли передать -1 не будет отжимать. Опционально (По умолчанию = 100 ms)." },
		func = pressKey
	}
}

return module
