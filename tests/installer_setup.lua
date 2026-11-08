local memory = {}
local env = {}
getgenv = function() return env end
local decoded = nil
game = { GetService = function(_, name)
	if name == "HttpService" then return { JSONDecode = function() return decoded end, JSONEncode = function() return "{}" end } end
	return {}
end }
workspace = { CurrentCamera = { ViewportSize = { Y = 720 } } }
request = function() return { StatusCode = 503 } end
isfile = function(path) return memory[path] ~= nil end
readfile = function(path) return memory[path] end
writefile = function(path, data) memory[path] = data end
isfolder = function() return true end
makefolder = function() end
task = { wait = function() end }
crypt = { hash = function(data) return string.rep(data == "abc" and "a" or "b", 64) end }

