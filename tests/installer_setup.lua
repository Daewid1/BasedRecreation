local memory = {}
local env = {}
getgenv = function() return env end
local decoded = nil
local hashAvailable = true
local hashedData = nil
Enum = { HashAlgorithm = { Sha256 = "sha256" } }
game = { GetService = function(_, name)
	if name == "HttpService" then return { JSONDecode = function() return decoded end, JSONEncode = function() return "{}" end } end
	if name == "EncodingService" then return { ComputeBufferHash = function(_, data, algorithm)
		assert(hashAvailable, "Hash unavailable")
		assert(algorithm == Enum.HashAlgorithm.Sha256)
		hashedData = buffer.tostring(data)
		return buffer.fromstring(string.rep(hashedData == "abc" and "\170" or "\187", 32))
	end } end
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
crypt = { hash = function() error("Must not use executor string hashing") end }

