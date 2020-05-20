__name__ = "Advanced Binder"
__version__ = "1.0.0"
__author__ = "Callow"

require 'clipboard'
local ImGui = require 'lib.ImGui'
local encoding = require 'encoding'
local vkeys = require 'lib.vkeys'
local sampEvents = require 'lib.samp.events'
local ini = require 'inicfg'

encoding.default = 'CP1251'
local u8 = encoding.UTF8
local defaultPathScript = "moonloader/Advanced Binder/"
local defaultSaveFolder = defaultPathScript .. "Bind Sets"
local defaultKeywordsFolder = defaultPathScript.. "Keywords"

local defaultBindSet = { name = "New set", eventType = 0, startId = 0, sameIdMode = 0, key = 0,
												commandInfo = { block = false, command = "" }, eventName = "", messages = {},
												checkKeyWhileInput = false, saveInChatHistory = false}
local defaultMessage = { text = "", eventType = 1, delay = 1000, autoEnter = true }

local bit = require "bit"
local ffi = require 'ffi'

local saveCheckPeriod = 2000
local updateUrl = nil

local bindSets = {}
local scripts = {}

local cached_allEventNames = {}

local defaultIni = {
	language = "RU",
	saveCheckPeriod = 2000
}

local settings = defaultIni

local strings = {
	RU = {
		windowName = "Advanced Binder",
		isLatestUpdate = "У вас последняя версия",
		saveInChatHistory = "История чата",
		haveUpdate = "Найдено обновления. \nНажмите чтобы скопировать ссылку",
		bindSets = "Набор биндов",
		language = "Язык",
		saveUpdatePeriod = "Период сохранения",
		keywordEvent = "Ключевые слова & События",
		checkForUpdate = "Проверить обновления",
		newBindSetButton = "[+] Добавить набор биндов",
		newNameSet = "Новый набор #",
		bindSetName = "Название: ",
		ok = "Ок",
		cancel = "Отмена",
		rename = "Переименовать",
		typeEvent = "Событие",
		onPressKey = "По нажатию клавиши",
		onSendCommand = "По команде",
		onEvent = "По событию",
		clear = "Очистить",
		whileChat = "Во время чата",
		block = "Блокировать",
		startId = "Начальный id",
		sameId = "Одинак. id",
		first = "Первый",
		random = "Случайный",
		addMessage = "Добавить сообщение",
		message = "Сообщение",
		id = "ID",
		copy = "Копия",
		rmv = "Удл",
		onTimer = "По времени",
		autoSend = "Авто отправка",
		nextId = "Следущий ID",
		scriptName = "Название: ",
		scriptVersion = "Версия: ",
		scriptAutors = "Авторы: ",
		reload = "Перезагрузить",
		unload = "Выгрузить",
		keywords = "Ключевые слова:",
		events = "События:",
		description = "Описание:",
		parameters = "Параметры:",
		additionalKwords = "Добавочные ключевые слова:"
	},
	EN = {
		windowName = "Advanced Binder",
		bindSets = "Bind Sets",
		language = "Language",
		isLatestUpdate = "You have last version",
		saveInChatHistory = "Сhat history",
		haveUpdate = "An update has been found. \nClick to copy link.",
		saveUpdatePeriod = "Save update period",
		keywordEvent = "Keywords & Events",
		checkForUpdate = "Check for update",
		newBindSetButton = "[+] Add new bind set",
		newNameSet = "New set #",
		bindSetName = "Bind set name: ",
		ok = "Ok",
		cancel = "Cancel",
		rename = "Rename",
		typeEvent = "On Event",
		onPressKey = "OnPressKey",
		onSendCommand = "onSendCommand",
		onEvent = "onEvent",
		clear = "Clear",
		whileChat = "While chat",
		block = "Block",
		startId = "Start id",
		sameId = "Same id  ",
		first = "First",
		random = "Random",
		addMessage = "Add new message",
		message = "Message",
		id = "ID",
		copy = "Copy",
		rmv = "Rmv",
		onTimer = "OnTimer",
		autoSend = "Auto send",
		nextId = "Next id",
		scriptName = "Script name: ",
		scriptVersion = "Script version: ",
		scriptAutors = "Script authors: ",
		reload = "Reload",
		unload = "Unload",
		events = "Events:",
		keywords = "Keywords:",
		description = "Description:",
		parameters = "Parameters:",
		additionalKwords= "Additional keywords:"
	}
}

ffi.cdef[[
	typedef int BOOL;
	typedef unsigned long DWORD;
	typedef unsigned short WORD;
	typedef void* HANDLE;
	typedef const char *LPCSTR;
	typedef void* LPSECURITY_ATTRIBUTES;
	typedef char CHAR;

	static const int MAX_PATH = 260;
	static const DWORD INVALID_HANDLE_VALUE = -1;
	typedef struct _FILETIME {
  DWORD dwLowDateTime;
  DWORD dwHighDateTime;
	} FILETIME, *PFILETIME, *LPFILETIME;

	typedef struct _WIN32_FIND_DATAA {
	  DWORD    dwFileAttributes;
	  FILETIME ftCreationTime;
	  FILETIME ftLastAccessTime;
	  FILETIME ftLastWriteTime;
	  DWORD    nFileSizeHigh;
	  DWORD    nFileSizeLow;
	  DWORD    dwReserved0;
	  DWORD    dwReserved1;
	  CHAR     cFileName[MAX_PATH];
	  CHAR     cAlternateFileName[14];
	  DWORD    dwFileType;
	  DWORD    dwCreatorType;
	  WORD     wFinderFlags;
	} WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;

	HANDLE FindFirstFileA(LPCSTR lpFileName,LPWIN32_FIND_DATAA lpFindFileData);
	BOOL FindNextFileA(HANDLE hFindFile,LPWIN32_FIND_DATAA lpFindFileData);
	DWORD __stdcall GetFileAttributesA(LPCSTR lpFileName);
	BOOL CreateDirectoryA(LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
	BOOL FindClose(HANDLE hFindFile);
	typedef void* HANDLE;
]]

--------------------- Utils ----------------------

function scandir(path, recursion)
	if isDir(path) then
		local files = {}
		local fileData = ffi.new("WIN32_FIND_DATAA")
		local hFile = ffi.C.FindFirstFileA(path.."\\*", fileData)
		path = path .. "/"
		if hFile ~= ffi.C.INVALID_HANDLE_VALUE then
			repeat
				local fileName = ffi.string(fileData.cFileName)
				local fileAttributes = tonumber(fileData.dwFileAttributes)
				if fileName ~= "." and fileName ~= ".." then
					if bit.band(fileAttributes, 0x10 -- FILE_ATTRIBUTE_DIRECTORY
											) ~= 0 then
						if recursion then
							files = table.connect(files, scandir(path .. fileName, true))
						end
					else
						table.insert(files, path .. fileName)
					end
				end
			until ffi.C.FindNextFileA(hFile, fileData) == 0
			ffi.C.FindClose(hFile)
		else
			return nil
		end
		return files
	end
	return nil
end

-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua --
function table.connect(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

-- https://gist.github.com/tylerneylon/81333721109155b2d244 --
function table.copy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = setmetatable({}, getmetatable(obj))
    for k, v in pairs(obj) do res[table.copy(k)] = table.copy(v) end
    return res
end

function isDir(path)
	local attributes = ffi.C.GetFileAttributesA(path)
	if attributes == ffi.C.INVALID_HANDLE_VALUE then
	 	return nil
	end
	return bit.band(attributes, 0x10 -- FILE_ATTRIBUTE_DIRECTORY
																	) ~= 0
end

function createFileWithFolders(path)
	local splitedPath = path:split("/")
	local currentPath = ""
	for i = 1, #splitedPath - 1 do
		currentPath = currentPath .. splitedPath[i]
		local checkDir = isDir(currentPath)
		if checkDir == false then
			return nil
		end
		if checkDir == nil then
			ffi.C.CreateDirectoryA(currentPath, nil)
		end
		currentPath = currentPath .. "/"
	end
	return io.open(path, "w")
end

function string:split(separator)
  local a = {}
  for match in self:gmatch("[^" .. separator .. "]+") do
    table.insert(a, match)
  end
  return a
end

function Class(parent)
	local metaclass = {__index = parent}
	local class = {super = parent}
	class.__index = class
	function metaclass:__call(...)
		local instance = setmetatable({}, class)
		if type(class.__init) == "function" then
			return instance, instance:__init(...)
		end
	end
	return setmetatable(class, metaclass)
end

function findIdByScript(script)
	for i, s in ipairs(scripts) do
		if s == script then
			return i
		end
	end
	return nil
end

function safetyCall(func, ...)
	local success, result = pcall(func, ...)
	if success then
			return result
	else
		print("Call function error: " .. result)
	end
	return nil
end

function parseKeywords(kword)
	return {scriptName = kword:match("^([^>:]+)>"),
					fun = kword:match("([^>:]+):") or kword:match("([^>:]+)"),
					params = (kword:match("%:([^>:]+)$") or ""):split(",") or {}}
end

function findBindByName(name)
	for _, bind in ipairs(bindSets) do
		if bind.name == name then
			return bind
		end
	end
	return nil
end

function createLinkTable(t, param)
	local linked = {}
	for i, v in ipairs(t) do
		if v[param] then
			linked[v[param]] = i
		end
	end
	return linked
end

function versionToInt(ver)
	local verInt = 0
	local vers = ver:split(".")
	local multiply = 10^(#vers-1)
	for _,v in pairs(vers) do
		verInt = verInt + multiply*tonumber(v)
		multiply = multiply / 10
	end
	return verInt
end
-------------------- Pickle -------------------------
----------------------------------------------
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- Freeware
----------------------------------------------

function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then
    error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while table.getn(self._refToTable) > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else --error("pickle a "..type(v).." is not supported")
  end
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = table.getn(self._refToTable)
    self._tableToRef[t] = ref
  end
  return ref
end

function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = loadstring("return "..s)
  local tables = gentables()

  for tnum = 1, table.getn(tables) do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end

--------------------- Script ------------------------

local Script = Class()

function Script:__init(scriptPath)
	self.path = scriptPath:gsub("moonloader/", ""):gsub("/","."):gsub(".lua", "")
	self.links = {}
	self:load()
	return self.module ~= nil
end

function Script:load()
	local result, script = pcall(require, self.path)
	if result then
		if type(script.__keywords__) == "table" or type(script.__events__) == "table" then
			if type(script.__options__) and type(script.__options__.thread) == "function" then
				self.thread = lua_thread.create(script.__options__.thread)
			end
			self.module = script
			if type(self.module.__events__) == "table" then
				self.module.__events__.__callback__ = onSampEvent
			end
			if type(self.module.__keywords__) == "table" then
				self.links.keywords = createLinkTable(self.module.__keywords__, "name")
			end
		end
	else
		print("Error while loading script '"..self.path.."': ".. script)
	end
end

function Script:unload()
	self.module = nil
	package.loaded[self.path] = nil
end

function Script:reload()
	self:unload()
	self:load()
	return self.module ~= nil
end

function Script:getEvents()
	return self.module.__events__ or {}
end

function Script:getKeywords()
	return self.module.__keywords__ or {}
end

function Script:executeKeyword(name, ...)
	if type(self.module.__keywords__) == "table" then
		local keyword = self.module.__keywords__[self.links.keywords[name]]
		print(keyword)
		if keyword and type(keyword) == "table" and type(keyword.func) == "function" then
			return safetyCall(keyword.func, ...)
		end
	end
	return nil
end

function Script:getInfo()
	return { name = self.module.__name__ or scriptPath:match("([^/\\]+).lua$"),
					 authors = self.module.__authors__ or "unknown",
					 version = self.module.__version__ or "unknown" }
end

----------------- Script functions -------------------

function scriptLoader()
	local files = scandir(defaultKeywordsFolder)
	if files then
		for i, file in pairs(files) do
			print(file)
			local script, result = Script(file)
			if result then
				table.insert(scripts, script)
			end
		end
	end
	cached_allEventNames = getAllEventNames()
end

function getAllEventNames()
	local names = {""}
	for _, script in pairs(scripts) do
		for name, _ in pairs(script:getEvents()) do
			if not name:match("__[^_]+__") then
				print(name)
				table.insert(names, name)
			end
		end
	end
	return names
end

--------------------- Bind Set ----------------------

local BindSet = Class()

function BindSet:__init(filename, bindSet)
	local data = (filename and self:load(filename) or bindSet) or table.copy(defaultBindSet)
	setmetatable(data, getmetatable(self))

	self.showOptions = false
	self.changed = false
	self.isRenaming = false

	self.currentMessage = nil
	self.lastKeyDown = -1
	self.lastTimeCheck = -1
	self.eventKeywords = nil
	local meta = {__index = data}

	function meta:__newindex(key, value)
			self.changed = true
			rawset(getmetatable(self).__index, key, value)
	end
	setmetatable(self, meta)
	self:updateLast()
end

function BindSet:insertMessage(message, id)
	id = id or (#self.messages + 1)
	message = message or table.copy(defaultMessage)
	message.id = message.id or (#self.messages == 0 and 0 or (self.messages[#self.messages].id + 1))
	message.nextId = message.nextId or message.id + 1
	table.insert(self.messages, id, message)
	self.changed = true
end

function BindSet:load(filename)
	local file = io.open(filename)
	if file then
		local content = file:read("a")
		file:close()
		print("Loaded ".. filename)
		return unpickle(content)
	end
end

function BindSet:rename(newname)
	newname = u8:decode(newname)
	os.rename(defaultSaveFolder .. "/" .. self.name .. ".lua_table", defaultSaveFolder .. "/" .. newname .. ".lua_table")
	self.name = newname
end

function BindSet:remove()
	os.remove(defaultSaveFolder .. "/" .. self.name .. ".lua_table")
	getmetatable(self).__index = nil
	setmetatable(self, {})
	self = nil
end

function BindSet:updateLast()
	for key, value in pairs(defaultBindSet) do
		if self[key] == nil then
			self[key] = value
		end
	end
	for i, message in ipairs(self.messages) do
		for key, value in pairs(defaultMessage) do
			if message[key] == nil then
				message[key] = value
			end
		end
	end
end

function BindSet:save()
	local file = createFileWithFolders(defaultSaveFolder .. "/" .. self.name .. ".lua_table")
	self.changed = false
	if file then
		file:write(pickle(getmetatable(self).__index))
		file:close()
	end
end

------------------ Bind Sets updaters --------------------

function loadAllBindSets()
	local files = scandir(defaultSaveFolder)
	if files then
		for i, filename in pairs(scandir(defaultSaveFolder)) do
			if string.match(filename, ".lua_table$") then
				table.insert(bindSets, BindSet(filename))
			end
		end
	end
end

function saveUpdater()
	while true do
		for i, bind in pairs(bindSets) do
			if bind.changed then
				bind:save()
			end
		end
		wait(saveCheckPeriod)
	end
end

------------------- Bind Handlers --------------------

function SelectNextMessage(bindSet)
	local result = {}
	local id = bindSet.currentMessage and bindSet.currentMessage.nextId or bindSet.startId
	for _, message in ipairs(bindSet.messages) do
		if message.id == id then
			table.insert(result, message)
			if bindSet.sameIdMode == 0 then break end
		end
	end
	bindSet.currentMessage = #result > 0 and result[math.random(#result)] or nil
	if not bindSet.currentMessage then
		bindSet.eventKeywords = nil
	end
	bindSet.lastTimeCheck = os.clock() * 1000
end

function sampEvents.onSendCommand(command)
	local command = string.match(command, "^/([^ ]+)")
	for _, bindSet in pairs(bindSets) do
		if bindSet.eventType == 1 and u8:decode(bindSet.commandInfo.command) == command then
			if not bindSet.currentMessage then
				SelectNextMessage(bindSet)
				if bindSet.commandInfo.block then
					return false
				end
			else
				bindSet.currentMessage = nil
			end
		end
	end
end

function onSampEvent(eventName, keywords)
	for _, bindSet in pairs(bindSets) do
		if bindSet.eventType == 2 and not bindSet.currentMessage and eventName == bindSet.eventName then
			if type(keywords) == "table" then
				bindSet.eventKeywords = keywords
			end
			SelectNextMessage(bindSet)
		end
	end
end

function BindKeyClicked(bindSet)
	if bindSet.key ~= 0 and isKeyDown(bindSet.key) and bindSet.lastKeyDown == -1 then
		bindSet.lastKeyDown = os.clock() * 1000
	elseif (not isKeyDown(bindSet.key)) and bindSet.lastKeyDown > -1 then
		local clicked_time = os.clock() * 1000 - bindSet.lastKeyDown
		bindSet.lastKeyDown = -1
		if clicked_time > 3000 then
			return 2
		else
			return 1
		end
	end
	return 0
end

function SendCurrentMessage(bindSet)
	local kwords = {}
	local cmessage = bindSet.currentMessage.text:gsub("%$([^$]+)%$",
									function(kword)
										local clKword = parseKeywords(kword)
										if bindSet.eventKeywords and bindSet.eventKeywords[clKword.fun] then
											return bindSet.eventKeywords[clKword.fun]
										end
										local res = ""
										for _, script in pairs(scripts) do
											if clKword.scriptName then
												if script:getInfo().name == clKword.scriptName then
													res = script:executeKeyword(clKword.fun, unpack(clKword.params))
													break
												end
											else
												res = script:executeKeyword(clKword.fun, unpack(clKword.params))
												if res then
													break
												end
											end
										end
										res = res and tostring(res) or ""
										return res
									end)
	if #cmessage > 0 then
		cmessage = u8:decode(cmessage)
		if bindSet.currentMessage.autoEnter then
			if bindSet.saveInChatHistory then
				sampProcessChatInput(cmessage)
			else
				sampSendChat(cmessage)
			end
		else
			sampSetChatInputEnabled(true)
			sampSetChatInputText(cmessage)
		end
	end
	SelectNextMessage(bindSet)
end

function BindSetClickHandler()
	while true do
		wait(1)
		for i, bindSet in ipairs(bindSets) do
			local clicked = BindKeyClicked(bindSet)
			local chatActiveCheck = bindSet.checkKeyWhileInput or not sampIsChatInputActive()
			if bindSet.eventType == 0 and not bindSet.currentMessage and clicked ~= 0 and chatActiveCheck then
				SelectNextMessage(bindSet)
			elseif bindSet.currentMessage then
				if (bindSet.currentMessage.eventType == 0 and bindSet.eventType == 0 and clicked == 1 and chatActiveCheck)
					or (bindSet.currentMessage.eventType ~= 0 and os.clock() * 1000 - bindSet.lastTimeCheck >= bindSet.currentMessage.delay and clicked ~= 2) then
					SendCurrentMessage(bindSet)
				elseif clicked == 2 then
					bindSet.currentMessage = nil
				end
			end
		end
	end
end

---------------------- Buffers ----------------------

local buffers = {
	rename = ImGui.ImBuffer(34),
	eventType = ImGui.ImInt(0),
	sameIdMode = ImGui.ImInt(0),
	startId = ImGui.ImInt(0),
	key = ImGui.ImBuffer(36),
	checkKeyWhileInput = ImGui.ImBool(false),
	eventId = ImGui.ImInt(0),
	commandName = ImGui.ImBuffer(48),
	commandBlock = ImGui.ImBool(false),
	saveInChatHistory = ImGui.ImBool(false)
}

function bufferUpdate(bindSet, id)
	local message = bindSet.messages[id]
	if buffers[id] == nil then
		buffers[id] = {
			id = ImGui.ImBuffer(6),
			text = ImGui.ImBuffer(256),
			eventType = ImGui.ImInt(0),
			nextId = ImGui.ImInt(0),
			delay = ImGui.ImInt(0),
			autoEnter = ImGui.ImBool(false)
		}
	end
	buffers[id].id.v = tostring(message.id)
	buffers[id].text.v = message.text
	buffers[id].eventType.v = message.eventType
	buffers[id].nextId.v = message.nextId
	buffers[id].delay.v = message.delay
	buffers[id].autoEnter.v = message.autoEnter or false
end

function bufferPreset(bindSet)
	buffers.eventType.v = bindSet.eventType
	buffers.sameIdMode.v = bindSet.sameIdMode
	buffers.startId.v = bindSet.startId
	buffers.rename.v = u8(bindSet.name)
	buffers.key.v = vkeys.id_to_name(bindSet.key) or ""
	buffers.saveInChatHistory.v = bindSet.saveInChatHistory
	buffers.checkKeyWhileInput.v = bindSet.checkKeyWhileInput or false
	for i, name in ipairs(cached_allEventNames) do
		if name == bindSet.eventName then
			buffers.eventId.v = i - 1
		end
	end
	buffers.commandName.v = bindSet.commandInfo.command
	buffers.commandBlock.v = bindSet.commandInfo.block
	for i = 1, #bindSet.messages do
		bufferUpdate(bindSet, i)
	end
end

------------------------ GUI ------------------------

function ImGui.InputIntUpperZero(label, buffer, step)
	local changed = ImGui.InputInt(label, buffer, step)
	if changed and (buffer.v < 0 or buffer.v == nil) then
		buffer.v = 0
	end
	return changed
end

function styleInit()
		local style = ImGui.GetStyle()

		style.WindowRounding = 0.0
		style.WindowTitleAlign = ImGui.ImVec2(0.5, 0.84)
		style.FrameRounding = 0.0
		style.ScrollbarRounding = 0.0

		style.FrameRounding = 0.0
end
styleInit()


local window_state = ImGui.ImBool(false)
local size = { width = 1220, height = 850}
local currentPage = 0;
function ImGui.OnDrawFrame()
	if window_state.v then
		ImGui.SetNextWindowSize(ImGui.ImVec2(size.width, size.height), ImGui.Cond.FirstUseEver)
		ImGui.PushStyleColor(ImGui.Col.WindowBg, ImGui.ImColor(0, 0, 0, 232):GetVec4())
		-- Main window --
		ImGui.Begin('Advanced Binder', window_state, ImGui.WindowFlags.NoResize + ImGui.WindowFlags.MenuBar)
		--{
			ImGui.BeginMenuBar()
			if ImGui.MenuItem(strings[settings.language].bindSets) then
				currentPage = 0
			end
			if ImGui.MenuItem(strings[settings.language].keywordEvent) then
				currentPage = 1
			end
			if ImGui.BeginMenu(strings[settings.language].checkForUpdate) then
				if updateUrl == nil then
					ImGui.MenuItem(strings[settings.language].isLatestUpdate);
				else
					if ImGui.MenuItem(strings[settings.language].haveUpdate) then
						clipboard.settext(updateUrl)
					end
				end
				ImGui.EndMenu();
			end

			ImGui.EndMenuBar()
			if currentPage == 0 then
				showBindSetsList()
				ImGui.SameLine()
				showBindSetDetails()
			elseif currentPage == 1 then
				showScriptList()
				ImGui.SameLine()
				showScriptDetails()
			end
		--}
	  ImGui.End()
		ImGui.PopStyleColor()
	end
end

------------------ "Bind sets" GUI -----------------------
local currentBindSet = nil
local onlyDigitsFilter = ImGui.ImCallback(function(data) if data.EventChar < 48 or data.EventChar > 57 then data.EventChar = 0 end end)
local printableFilter = ImGui.ImCallback(function(data) if (data.EventChar < 48 or data.EventChar > 57) and
																														(data.EventChar < 65 or data.EventChar > 90) and
																														(data.EventChar < 97 or data.EventChar > 122) and
																														data.EventChar ~= 95 and data.EventChar ~= 45 then
																															data.EventChar = 0
																														end end )

local settingsBuffer = { language = ImGui.ImInt(settings.language == "EN" and 1 or 0), saveCheckPeriod = ImGui.ImInt(settings.saveCheckPeriod) }
function showBindSetsList()
	-- List of bind sets --
	ImGui.BeginChild("Bind Sets", ImGui.ImVec2(size.width * 0.3, size.height - 55), true);
	--{
		ImGui.BeginChild("Bind Sets", ImGui.ImVec2(size.width * 0.3, size.height - 125), false);
		--{
			for i, bind in ipairs(bindSets) do
				ImGui.BeginChild("Set #"..tostring(i), ImGui.ImVec2(size.width * 0.3 - 30, 30), false, ImGui.WindowFlags.NoScrollWithMouse)
				--{
					ImGui.PushStyleColor(ImGui.Col.Button,(bind == currentBindSet and
																								ImGui.ImColor(161, 53, 0, 155) or ImGui.ImColor(215, 66, 55, 155)):GetVec4())

					if ImGui.Button(u8(bind.name), ImGui.ImVec2(size.width * 0.3 - 70, 30)) then -- Bind set button
						currentBindSet = bind
						bufferPreset(currentBindSet)
					end

					ImGui.SameLine()
					if ImGui.Button("X",ImGui.ImVec2(30, 30)) then -- Remove bind set button
						if bind == currentBindSet then
							currentBindSet = nil
						end
						bind:remove()
						table.remove(bindSets, i)
					end

					ImGui.PopStyleColor()
				--}
				ImGui.EndChild()
				ImGui.Separator()
			end
			ImGui.PushStyleColor(ImGui.Col.Button, ImGui.ImColor(215, 66, 55, 155):GetVec4())
			if ImGui.Button(strings[settings.language].newBindSetButton,ImGui.ImVec2(size.width * 0.3 - 31, 30)) then
				table.insert(bindSets, BindSet())
				local j = 1
				local newName = nil
				while true do
					newName = u8:decode(strings[settings.language].newNameSet .. j)
					if not findBindByName(newName) then
						break
					end
					j = j + 1
				end
				bindSets[#bindSets]:rename(u8(newName))
			end
			ImGui.PopStyleColor()
		--}
		ImGui.EndChild()
		ImGui.Separator()
		if ImGui.Combo(strings[settings.language].language, settingsBuffer.language, {"Русский", "English"}) then
			settings.language = settingsBuffer.language.v == 0 and "RU" or "EN"
		end
		if ImGui.InputIntUpperZero(strings[settings.language].saveUpdatePeriod, settingsBuffer.saveCheckPeriod, 100) then
			settings.saveCheckPeriod = settingsBuffer.saveCheckPeriod.v
		end
	--}
	ImGui.EndChild()

end

function showBindSetDetails()
	if currentBindSet then
		-- Bind Set details block --
		ImGui.BeginChild("Bind set details", ImGui.ImVec2(size.width * 0.7 - 25, size.height - 55), true, ImGui.WindowFlags.NoScrollbar + ImGui.WindowFlags.NoScrollWithMouse);
		--{
			-- Bind Set settings --
			ImGui.BeginChild("MainHeader", ImGui.ImVec2(size.width * 0.7 - 10, 70), ImGui.WindowFlags.NoScrollWithMouse)
			--{
				ImGui.AlignTextToFramePadding();

				-- Rename functionality --
				if currentBindSet.isRenaming then
					ImGui.Text(strings[settings.language].bindSetName)
					ImGui.SameLine()
					ImGui.InputText("", buffers.rename)
					ImGui.SameLine()
					if ImGui.Button(strings[settings.language].ok,ImGui.ImVec2(55, 20)) then
						if not findBindByName(u8:decode(buffers.rename.v)) then
							currentBindSet:rename(buffers.rename.v)
							currentBindSet.isRenaming = false
						end
					end
					ImGui.SameLine()
					if ImGui.Button(strings[settings.language].cancel,ImGui.ImVec2(55, 20)) then
						buffers.rename.v = currentBindSet.name
						currentBindSet.isRenaming = false
					end
				else
					ImGui.Text(strings[settings.language].bindSetName .. u8(currentBindSet.name));
					ImGui.SameLine()
					if ImGui.Button(strings[settings.language].rename,ImGui.ImVec2(100, 20)) then
						currentBindSet.isRenaming = true
					end
				end

				ImGui.Columns(4, " ", false)
				ImGui.SetColumnWidth(1, 175); ImGui.SetColumnWidth(2, 175);

				ImGui.AlignTextToFramePadding();
				ImGui.Text(strings[settings.language].typeEvent); ImGui.SameLine()

				if ImGui.Combo('  ', buffers.eventType, {strings[settings.language].onPressKey, strings[settings.language].onSendCommand, strings[settings.language].onEvent}) then -- Event type comboBox
					currentBindSet.eventType = buffers.eventType.v
				end
				ImGui.NextColumn()

				-- Event parameters functionality --
				if currentBindSet.eventType == 0 then -- OnPressKey
					ImGui.InputTextMultiline("   ", buffers.key, ImGui.ImVec2(80, 20),ImGui.InputTextFlags.CallbackAlways,
																	ImGui.ImCallback(
																		function (data)
																			data.SelectionStart = 0; data.SelectionEnd = 0; data.CursorPos = 0
																			--if data.Buf ~= vkeys.id_to_name(currentBindSet.key) then
																				-- Key press handler --
																				for i = vkeys.VK_PRIOR, vkeys.VK_F24 do
																					if ImGui.IsKeyDown(i) and i ~= currentBindSet.key then
																						currentBindSet.key = i
																						break
																					end
																				end
																				data.Buf = (currentBindSet.key ~= 0 and vkeys.id_to_name(currentBindSet.key) or "")
																			--end
																		end
																	))
					ImGui.SameLine();
					if ImGui.Button(strings[settings.language].clear, ImGui.ImVec2(70, 20)) then
						currentBindSet.key = 0
						buffers.key.v = ""
					end
					ImGui.NextColumn();
					if ImGui.Checkbox(strings[settings.language].whileChat, buffers.checkKeyWhileInput) then
						currentBindSet.checkKeyWhileInput = buffers.checkKeyWhileInput.v
					end
				elseif currentBindSet.eventType == 1 then -- OnSendCommand
					if ImGui.InputTextMultiline("   ", buffers.commandName, ImGui.ImVec2(155, 20), ImGui.InputTextFlags.CallbackCharFilter, printableFilter) then
						currentBindSet.commandInfo.command = buffers.commandName.v; currentBindSet.changed = true
					end
					ImGui.SameLine()
					ImGui.NextColumn();
					if ImGui.Checkbox(strings[settings.language].block, buffers.commandBlock) then
						currentBindSet.commandInfo.block = buffers.commandBlock.v; currentBindSet.changed = true
					end
				elseif currentBindSet.eventType == 2 then -- OnEvent
					if ImGui.Combo(' ', buffers.eventId, cached_allEventNames) then
						currentBindSet.eventName = cached_allEventNames[buffers.eventId.v + 1]
					end
					ImGui.NextColumn();
				end
				ImGui.NextColumn()

				ImGui.AlignTextToFramePadding();
				ImGui.Text(strings[settings.language].startId); ImGui.SameLine()
				if ImGui.InputIntUpperZero("    ", buffers.startId) then
					currentBindSet.startId = buffers.startId.v
				end
				ImGui.NextColumn()

				ImGui.AlignTextToFramePadding();
				ImGui.Text(strings[settings.language].sameId); ImGui.SameLine()
				if ImGui.Combo('     ', buffers.sameIdMode, {strings[settings.language].first, strings[settings.language].random}) then
					currentBindSet.sameIdMode = buffers.sameIdMode.v
				end

				ImGui.NextColumn(); ImGui.NextColumn();

				if ImGui.Checkbox(strings[settings.language].saveInChatHistory, buffers.saveInChatHistory) then
					currentBindSet.saveInChatHistory = buffers.saveInChatHistory.v
				end

				ImGui.NextColumn()

				if ImGui.Button(strings[settings.language].addMessage) then
					currentBindSet:insertMessage()
					bufferUpdate(currentBindSet, #currentBindSet.messages)
				end
			--}
			ImGui.EndChild()

			ImGui.Separator(); ImGui.Spacing()
			ImGui.BeginChild("Messages", ImGui.ImVec2(size.width * 0.7 - 35, size.height - 140), false)
			--{
				-- Message List Header --
				ImGui.BeginChild("BindHeader", ImGui.ImVec2(size.width * 0.7 - 25, 20), false, ImGui.WindowFlags.NoScrollWithMouse)
				--{
					ImGui.Columns(4)
					ImGui.SetColumnWidth(0, 55); ImGui.SetColumnWidth(1, 670); ImGui.SetColumnWidth(2, 45); ImGui.SetColumnWidth(3, 45)
					ImGui.Text(strings[settings.language].id); ImGui.NextColumn()
					ImGui.Text(strings[settings.language].message); ImGui.NextColumn()
					ImGui.Text(strings[settings.language].copy); ImGui.NextColumn()
					ImGui.Text(strings[settings.language].rmv); ImGui.NextColumn()
				--}
				ImGui.EndChild()

				-- Mesage List --
				for i, message in ipairs(currentBindSet.messages) do
					showMessageDetail(i, message)
				end
			--}
			ImGui.EndChild()
		--}
		ImGui.EndChild()
	end
end

function showMessageDetail(i, message)
	ImGui.BeginChild("Line #" .. i, ImGui.ImVec2(size.width * 0.7 - 25, 65), false, ImGui.WindowFlags.NoScrollWithMouse)
	--{
		ImGui.Columns(4)
		ImGui.SetColumnWidth(0, 55); ImGui.SetColumnWidth(1, 670); ImGui.SetColumnWidth(2, 45); ImGui.SetColumnWidth(3, 45)

		if ImGui.InputTextMultiline(" ", buffers[i].id, ImGui.ImVec2(65,20),ImGui.InputTextFlags.CallbackCharFilter, onlyDigitsFilter) then -- Message id text input
			if tonumber(buffers[i].id.v) == nil then
				buffers[i].id.v = tostring(0)
			end
			message.id = tonumber(buffers[i].id.v); currentBindSet.changed = true
		end
		ImGui.NextColumn()

		if ImGui.InputTextMultiline("", buffers[i].text, ImGui.ImVec2(675,20)) then -- Message text input
			message.text = buffers[i].text.v; currentBindSet.changed = true
		end
		ImGui.NextColumn()

		if ImGui.Button("C",ImGui.ImVec2(30, 20)) then -- Message "Copy" button
			currentBindSet:insertMessage(table.copy(message), i + 1)
			table.insert(buffers, i + 1, nil)
			bufferUpdate(currentBindSet, i + 1)
		end
		ImGui.NextColumn()

		if ImGui.Button("X",ImGui.ImVec2(30, 20)) then -- Message "Remove" button
			table.remove(currentBindSet.messages, i)
			table.remove(buffers, i)
			-- for j = i, #currentBindSet.messages do
			-- 	bufferUpdate(currentBindSet, j)
			-- end
		else
			ImGui.Columns(1)

			ImGui.BeginChild("Line Options #" .. i, ImGui.ImVec2(size.width * 0.7 - 55, 35), true, ImGui.WindowFlags.NoScrollWithMouse)
			--{
				ImGui.Columns(4, "", false)
				ImGui.SetColumnWidth(1, 150); ImGui.SetColumnWidth(2, 180);

				ImGui.AlignTextToFramePadding();
				ImGui.Text(strings[settings.language].typeEvent); ImGui.SameLine()
				if currentBindSet.eventType == 0 then
					if ImGui.Combo(' ', buffers[i].eventType, {strings[settings.language].onPressKey, strings[settings.language].onTimer}) then
						message.eventType = buffers[i].eventType.v; currentBindSet.changed = true
					end
				else
					ImGui.Combo(' ', ImGui.ImInt(0), {strings[settings.language].onTimer})
				end
				ImGui.NextColumn()

				if (message.eventType == 1  or currentBindSet.eventType ~= 0) and ImGui.InputIntUpperZero("ms", buffers[i].delay, 100) then
					message.delay = buffers[i].delay.v; currentBindSet.changed = true
				end
				ImGui.NextColumn();

				if ImGui.Checkbox(strings[settings.language].autoSend, buffers[i].autoEnter) then
					message.autoEnter = buffers[i].autoEnter.v; currentBindSet.changed = true
				end
				ImGui.NextColumn();

				ImGui.AlignTextToFramePadding();
				ImGui.Text(strings[settings.language].nextId); ImGui.SameLine()
				if ImGui.InputIntUpperZero("  ", buffers[i].nextId) then
					message.nextId = buffers[i].nextId.v; currentBindSet.changed = true
				end
			--}
			ImGui.EndChild()
		end
	--}
	ImGui.EndChild()
end

--------------- "Keywords & Events" GUI ------------------

local currentScript = nil
function showScriptList()
	-- List of scritps --
	ImGui.BeginChild("Bind Sets", ImGui.ImVec2(size.width * 0.3, size.height - 55), true);
	--{
	for i, script in ipairs(scripts) do
		local scriptInfo = script:getInfo()
		ImGui.BeginChild("Set #"..tostring(i), ImGui.ImVec2(size.width * 0.3 - 30, 30), false, ImGui.WindowFlags.NoScrollWithMouse)
		--{
			ImGui.PushStyleColor(ImGui.Col.Button,(script == currentScript and
																						ImGui.ImColor(161, 53, 0, 155) or ImGui.ImColor(215, 66, 55, 155)):GetVec4())

			if ImGui.Button(u8(scriptInfo.name), ImGui.ImVec2(size.width * 0.3 - 20, 30)) then
				currentScript = script
			end

			ImGui.PopStyleColor()
		--}
		ImGui.EndChild()
		ImGui.Separator()
	end
	--}
	ImGui.EndChild()
end

function showScriptDetails()
	if currentScript then
			ImGui.BeginChild("Script details", ImGui.ImVec2(size.width * 0.7 - 25, size.height - 55), true, ImGui.WindowFlags.NoScrollbar + ImGui.WindowFlags.NoScrollWithMouse);
			--{
				ImGui.BeginChild("Main script info", ImGui.ImVec2(size.width * 0.7 - 35, 75), false, ImGui.WindowFlags.NoScrollbar + ImGui.WindowFlags.NoScrollWithMouse);
				--{
					local scriptInfo = currentScript:getInfo()
					ImGui.Columns(2, " ", false)
					ImGui.SetColumnWidth(0, size.width * 0.7 - 130); ImGui.SetColumnWidth(1, 100);
					ImGui.AlignTextToFramePadding()
					ImGui.Text(strings[settings.language].scriptName.. u8(scriptInfo.name))
					ImGui.NextColumn()
					if ImGui.Button(strings[settings.language].reload, ImGui.ImVec2(90, 20)) then
						local result = currentScript:reload()
						if not result then
							local id = findIdByScript(currentScript)
							if id then
								table.remove(scripts, id)
							end
							currentScript = nil
							cached_allEventNames = getAllEventNames()
							ImGui.EndChild(); ImGui.EndChild()
							return
						end
					end
					ImGui.NextColumn()
					ImGui.AlignTextToFramePadding()
					ImGui.Text(strings[settings.language].scriptVersion.. u8(scriptInfo.version))
					ImGui.NextColumn()
					if ImGui.Button(strings[settings.language].unload, ImGui.ImVec2(90, 20)) then
						local id = findIdByScript(currentScript)
						print(id)
						if id then
							table.remove(scripts, id)
						end
						currentScript:unload()
						currentScript = nil
						cached_allEventNames = getAllEventNames()
						ImGui.EndChild(); ImGui.EndChild()
						return
					end
					ImGui.NextColumn()
					ImGui.Text(strings[settings.language].scriptAutors.. u8(scriptInfo.authors))
				--}
				ImGui.EndChild()
				ImGui.Separator()
				ImGui.BeginChild("Keywords and events list", ImGui.ImVec2(size.width * 0.7 - 45, size.height - 125), false);
				--{
					ImGui.Text(strings[settings.language].keywords)
					for i, details in ipairs(currentScript:getKeywords()) do
						drawScriptElementInfo(details, {["description_"..settings.language] = strings[settings.language].description,
																						["parameters_"..settings.language] = strings[settings.language].parameters})
					end
					ImGui.Text(strings[settings.language].events)
					for i, details in ipairs(currentScript:getEvents()) do
						drawScriptElementInfo(details, {["description_"..settings.language] = strings[settings.language].description,
																						["keywords_"..settings.language] = strings[settings.language].additionalKwords})
					end
				--}
				ImGui.EndChild()
			--}
			ImGui.EndChild()
	end
end

function drawScriptElementInfo(details, info)
	if type(details) == "table" then
		ImGui.Indent(10)
		ImGui.Text(details.name)
		for name, s in pairs(info) do
			if details[name] then
				ImGui.Indent(10)
				ImGui.Text(s)
				ImGui.Indent(10)
				if type(details[name]) == "table" then
					for i, v in ipairs(details[name]) do
						ImGui.Text(v)
					end
				else
					ImGui.Text(details[name])
				end
				ImGui.Unindent(10);ImGui.Unindent(10)
			end
		end
		ImGui.Unindent(10)
		ImGui.Separator()
	end
end

-------------------- Status lines -----------------------

local statusLineEnabled = false
local font_flag = require('moonloader').font_flag
local font_status = renderCreateFont('Verdana', 10, font_flag.BOLD + font_flag.SHADOW)
local screenWidth, screenHeight = getScreenResolution()
function statusLines()
	while statusLineEnabled do
		local i = 1
		for _, bindSet in pairs(bindSets) do
			if bindSet.currentMessage then
				local status = ""
				if bindSet.currentMessage.eventType == 0 then
					status = "WK"
				elseif bindSet.currentMessage.eventType == 1 then
 					status = "WT " .. tostring(math.floor(bindSet.currentMessage.delay - (os.clock() * 1000 - bindSet.lastTimeCheck))) .. " ms"
				end

				local keyPressed = ""
				if bindSet.lastKeyDown ~= -1 then
					local time = math.floor(os.clock() * 1000 - bindSet.lastKeyDown)
					keyPressed = "| "
					if time > 3000 then
						keyPressed = keyPressed .. "{FF0000}"
					end
					keyPressed = keyPressed .. tostring(time) .. " ms"
				end

				renderFontDrawText(font_status, string.format("%s | %s | %s %s", bindSet.name, u8:decode(bindSet.currentMessage.text), status, keyPressed),
													 screenWidth / 2 - 300, screenHeight - 20*i, 0xFFFFFFFF)
				i = i + 1
			end
		end
		wait(0)
	end
end

----------------- Update functionality -----------------

local site = "https://sites.google.com/view/callow/samp_scripts"
local defaultUpdateFile = defaultPathScript .. "update.txt"
function checkForUpdate()
	local url = nil
	local file = createFileWithFolders(defaultUpdateFile)
	if file then
		file:close()
	end
	downloadUrlToFile(site, defaultUpdateFile)
	wait(5000)
	local file = io.open(defaultUpdateFile, "r")
	if file then
		local content = file:read("*all")
		file:close()
		os.remove(defaultUpdateFile)
		local version, url = content:match(__name__ .. " | ([^|]+) | ([^|]+) |")
		if version and versionToInt(version) > versionToInt(__version__) then
			updateUrl = url
			sampAddChatMessage("[ABinder] Has been found update. To get link, select \"Check for update\" folder in binder window", 0xFF00FFFF)
		end
	end
end

------------------------ Main --------------------------

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(200) end
	settings = ini.load(defaultIni)

	scriptLoader()
	loadAllBindSets()
	sampRegisterChatCommand("advbind", function(arg) if not window_state.v then window_state.v = true end end)
	sampRegisterChatCommand("advstatus", function(arg)
		statusLineEnabled = not statusLineEnabled
		if statusLineEnabled then lua_thread.create(statusLines) end end
	)
	updateThread = lua_thread.create(checkForUpdate)
	saveUpdaterThread = lua_thread.create(saveUpdater)
	clickHandler = lua_thread.create(BindSetClickHandler)
	while true do
		wait(100)
		ImGui.Process = window_state.v
	end
end

function onExitScript(exit)
	ini.save(settings)
end
