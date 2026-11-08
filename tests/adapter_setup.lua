local originalTypeof = typeof
function typeof(value)
	if type(value) == "table" and value.__enum then return "EnumItem" end
	return originalTypeof(value)
end
local function signal()
	local listeners = {}
	return {
		connect = function(_, callback) listeners[#listeners + 1] = callback end,
		fire = function(_, ...) for _, callback in ipairs(table.clone(listeners)) do callback(...) end end,
	}
end
Enum = { KeyCode = {}, UserInputType = { Keyboard = "Keyboard" }, TeleportState = {} }
for _, name in ipairs({ "G", "H", "K", "T", "Unknown", "RightShift", "LeftControl", "RightControl" }) do
	Enum.KeyCode[name] = { Name = name, __enum = true }
end
game = { GameId = 123 }
task = { delay = function() end, defer = function(callback) callback() end }
local files = {}
local B = {
	Signal = { new = signal }, onUnload = signal(), LP = {}, genv = {},
	S = { UserInputService = { InputBegan = {}, InputEnded = {}, GetFocusedTextBox = function() return nil end, IsKeyDown = function() return false end } },
	fs = { path = function(path) return path end, readJson = function(path) return files[path] end,
		writeJson = function(path, data) files[path] = data end, list = function() return {} end },
	util = { copy = function(value) return type(value) == "table" and table.clone(value) or value end, debounce = function(_, callback) return callback end },
	Window = { page = function(spec) return spec end }, UI = {}, Motion = {}, Controls = { bindables = {} },
	try = function(_, callback, ...) return callback(...) end,
	fault = function(_, message) error(message) end,
	connect = function(event, callback) event.callback = callback end,
}

