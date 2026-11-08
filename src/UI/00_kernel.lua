do -- 00_kernel.lua
-- ============================================================================
--  00 kernel   services, ownership, signals, error boundaries, files, helpers
-- ============================================================================
local genv = (type(getgenv) == "function" and getgenv()) or _G
B.genv = genv

-- A second execution replaces the first: the old hub unloads itself completely.
if type(genv.HUSS_BASED) == "table" and type(genv.HUSS_BASED.unload) == "function" then
  pcall(genv.HUSS_BASED.unload, true)
end
genv.HUSS_BASED = B
B.alive = true
B.bootClock = os.clock()

local cloneref = type(cloneref) == "function" and cloneref or function(x) return x end
B.cloneref = cloneref
B.S = setmetatable({}, { __index = function(t, name)
  local ok, service = pcall(game.GetService, game, name)
  if not ok or not service then error("BASED: no service " .. tostring(name), 2) end
  service = cloneref(service)
  rawset(t, name, service)
  return service
end })
local S = B.S
B.LP = S.Players.LocalPlayer

-- ---------------------------------------------------------------- signals
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ list = {} }, Signal) end
function Signal:connect(fn)
  local link = { fn = fn, live = true }
  local list = self.list
  list[#list + 1] = link
  return { disconnect = function()
    if not link.live then return end
    link.live = false
    local at = table.find(list, link)
    if at then table.remove(list, at) end
  end }
end
function Signal:fire(...)
  local list = self.list
  if #list == 0 then return end
  for _, link in ipairs(table.clone(list)) do
    if link.live then B.try("signal", link.fn, ...) end
  end
end
B.Signal = Signal

-- ---------------------------------------------------------------- faults
-- Everything user-facing runs inside B.try: a failing feature logs here and the
-- rest of the hub keeps running. Settings > About shows this list.
B.faults = {}
B.onFault = Signal.new()
local lastFault = {}
function B.fault(scope, err)
  scope = tostring(scope)
  -- something failing every frame must not flood the log: one entry a second per scope
  local now = os.clock()
  local previous = lastFault[scope]
  if previous and now - previous.at < 1 then previous.entry.repeats = (previous.entry.repeats or 0) + 1; return end
  local entry = { scope = scope, message = tostring(err), at = now - B.bootClock }
  lastFault[scope] = { at = now, entry = entry }
  local faults = B.faults
  faults[#faults + 1] = entry
  if #faults > 60 then table.remove(faults, 1) end
  warn("[BASED] " .. entry.scope .. ": " .. entry.message)
  if B.onFault and #B.onFault.list > 0 then
    for _, link in ipairs(table.clone(B.onFault.list)) do pcall(link.fn, entry) end
  end
end
local function trace(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end
function B.try(scope, fn, ...)
  local result = table.pack(xpcall(fn, trace, ...))
  if not result[1] then B.fault(scope, result[2]); return nil end
  return table.unpack(result, 2, result.n)
end
function B.safe(scope, fn)
  return function(...) return B.try(scope, fn, ...) end
end
-- Potassium: calling into game modules drops the thread's Plugin capability and
-- every gethui instance then throws. Callbacks the game invokes call this first.
function B.identity()
  if type(setthreadidentity) == "function" then pcall(setthreadidentity, 8) end
end

-- ---------------------------------------------------------------- ownership
local owned = {}
function B.own(thing)
  owned[#owned + 1] = thing
  return thing
end
-- is this instance the hub's: one it made (B.own), or inside one (its screens, its sound folders, the music's group)
local ownedSet, ownedSeen = {}, 0
function B.owns(instance)
  if #owned < ownedSeen then table.clear(ownedSet); ownedSeen = 0 end
  if #owned ~= ownedSeen then
    for i = ownedSeen + 1, #owned do
      local thing = owned[i]
      if typeof(thing) == "Instance" then ownedSet[thing] = true end
    end
    ownedSeen = #owned
  end
  local node = instance
  while node do
    if ownedSet[node] then return true end
    node = node.Parent
  end
  return false
end
-- What every hooked function costs, by name, while measuring (B.measure): nil the rest of the time,
-- and then a hook costs one look at it. Read with B.measure(seconds) -> lines, worst first.
B.prof = nil
local function charge(scope, seconds)
  local prof = B.prof
  if not prof then return end
  local entry = prof[scope]
  if not entry then entry = { 0, 0, 0 }; prof[scope] = entry end
  entry[1] += seconds
  entry[2] += 1
  if seconds > entry[3] then entry[3] = seconds end
end
B.charge = charge
function B.connect(signal, fn, scope)
  scope = scope or "event"
  local safe = B.safe(scope, fn)
  return B.own(signal:Connect(function(...)
    if not B.prof then return safe(...) end
    local started = os.clock()
    safe(...)
    charge(scope, os.clock() - started)
  end))
end
function B.measure(seconds)
  B.prof = {}
  local frames, started = 0, os.clock()
  local counter = S.RunService.Heartbeat:Connect(function() frames += 1 end)
  task.wait(seconds or 5)
  counter:Disconnect()
  local prof, span = B.prof, os.clock() - started
  B.prof = nil
  local rows = {}
  for scope, entry in pairs(prof) do rows[#rows + 1] = { scope, entry[1], entry[2], entry[3] } end
  table.sort(rows, function(a, b) return a[2] > b[2] end)
  local out = { string.format("%d frames in %.1f s (%.0f fps)", frames, span, frames / math.max(span, 1e-3)) }
  for _, row in ipairs(rows) do
    out[#out + 1] = string.format("%-28s %6.3f ms/frame  %6d calls  worst %.2f ms", row[1], row[2] * 1000 / math.max(frames, 1), row[3], row[4] * 1000)
  end
  return out
end
B.onUnload = Signal.new()
function B.unload()
  if not B.alive then return end
  B.alive = false
  pcall(function() B.onUnload:fire() end)
  for index = #owned, 1, -1 do
    local thing = owned[index]
    pcall(function()
      local kind = typeof(thing)
      if kind == "RBXScriptConnection" then thing:Disconnect()
      elseif kind == "Instance" then thing:Destroy()
      elseif kind == "function" then thing()
      elseif kind == "table" and type(thing.destroy) == "function" then thing:destroy() end
    end)
  end
  table.clear(owned)
  if genv.HUSS_BASED == B then genv.HUSS_BASED = nil end
end

-- ---------------------------------------------------------------- files
local fs = { root = "BasedRecreation" }
fs.ok = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
  and type(makefolder) == "function" and type(isfolder) == "function"
function fs.path(relative) return fs.root .. "/" .. relative end
function fs.exists(path)
  if not fs.ok then return false end
  local ok, present = pcall(isfile, path)
  return ok and present == true
end
function fs.isdir(path)
  if not fs.ok then return false end
  local ok, present = pcall(isfolder, path)
  return ok and present == true
end
function fs.mkdir(path)
  if not fs.ok then return false end
  local built = ""
  for part in string.gmatch(path, "[^/\\]+") do
    built = built == "" and part or (built .. "/" .. part)
    if not fs.isdir(built) then pcall(makefolder, built) end
  end
  return fs.isdir(path)
end
function fs.read(path)
  if not fs.exists(path) then return nil end
  local ok, data = pcall(readfile, path)
  return ok and data or nil
end
function fs.write(path, data)
  if not fs.ok then return false end
  local folder = string.match(path, "^(.*)[/\\][^/\\]+$")
  if folder and not fs.isdir(folder) then fs.mkdir(folder) end
  local ok = pcall(writefile, path, data)
  return ok
end
function fs.remove(path)
  if type(delfile) ~= "function" or not fs.exists(path) then return false end
  return (pcall(delfile, path))
end
function fs.list(path)
  if type(listfiles) ~= "function" or not fs.isdir(path) then return {} end
  local ok, files = pcall(listfiles, path)
  if not ok or type(files) ~= "table" then return {} end
  local out = {}
  for _, file in ipairs(files) do out[#out + 1] = (string.gsub(tostring(file), "\\", "/")) end
  table.sort(out)
  return out
end
function fs.readJson(path)
  local data = fs.read(path)
  if not data or data == "" then return nil end
  local ok, value = pcall(S.HttpService.JSONDecode, S.HttpService, data)
  return ok and value or nil
end
function fs.writeJson(path, value)
  local ok, data = pcall(S.HttpService.JSONEncode, S.HttpService, value)
  return ok and fs.write(path, data) or false
end
B.fs = fs

-- ---------------------------------------------------------------- helpers
local util = {}
function util.clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
function util.lerp(a, b, t) return a + (b - a) * t end
function util.map(x, a, b, c, d, clamp)
  local t = (x - a) / (b - a)
  if clamp then t = util.clamp01(t) end
  return c + (d - c) * t
end
function util.round(x, step)
  step = step or 1
  return math.floor(x / step + 0.5) * step
end
function util.hex(text)
  text = string.gsub(text, "#", "")
  return Color3.fromRGB(tonumber(string.sub(text, 1, 2), 16), tonumber(string.sub(text, 3, 4), 16), tonumber(string.sub(text, 5, 6), 16))
end
function util.toHex(color)
  return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end
function util.luma(color) return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B end
function util.mix(a, b, t) return a:Lerp(b, t) end
function util.format(value, decimals)
  if decimals and decimals > 0 then return string.format("%." .. decimals .. "f", value) end
  return tostring(math.floor(value + 0.5))
end
function util.comma(n)
  local text = tostring(math.floor(n))
  local out = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
  return (string.gsub(out, "^,", ""))
end
function util.copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = util.copy(v) end
  return out
end
function util.keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  return out
end
-- Cheap fuzzy score for the command palette: every query character must appear
-- in order; contiguous runs and word starts score higher. nil = no match.
function util.fuzzy(query, text)
  query, text = string.lower(query), string.lower(text)
  if query == "" then return 0 end
  local score, at, run = 0, 1, 0
  for i = 1, #query do
    local ch = string.sub(query, i, i)
    local found = string.find(text, ch, at, true)
    if not found then return nil end
    if found == at then run += 1; score += 2 + run else run = 0 end
    if found == 1 or string.find(string.sub(text, found - 1, found - 1), "[%s%p]") then score += 3 end
    score -= (found - at) * 0.05
    at = found + 1
  end
  return score - #text * 0.01
end
function util.debounce(seconds, fn)
  local token = 0
  return function(...)
    token += 1
    local mine = token
    local args = table.pack(...)
    task.delay(seconds, function()
      if mine == token and B.alive then B.try("debounce", fn, table.unpack(args, 1, args.n)) end
    end)
  end
end
-- A ray from one point to another, however far apart. Measured on the client: one ray finds
-- nothing more than 15,000 studs away however long it is asked to be, and says so with nil, not
-- an error. So a long one is cast in lengths the engine can see along. nil means the way is
-- clear (or, past `lengths` of them, further than it is worth looking).
local RAY_REACH = 14000
function util.ray(from, to, params, lengths)
  local offset = to - from
  local distance = offset.Magnitude
  if distance <= RAY_REACH then return workspace:Raycast(from, offset, params) end
  local unit = offset / distance
  local at = 0
  for _ = 1, lengths or 8 do
    local reach = math.min(RAY_REACH, distance - at)
    local hit = workspace:Raycast(from + unit * at, unit * reach, params)
    if hit then return hit end
    at += reach
    if at >= distance - 0.01 then break end
  end
  return nil
end
util.RAY_REACH = RAY_REACH
-- a distance for a label: whole studs with a comma, then thousands, then millions
function util.studs(distance)
  if distance >= 99.95e6 then return string.format("%.0fM", distance / 1e6) end
  if distance >= 999500 then return string.format("%.1fM", distance / 1e6) end
  if distance >= 99950 then return string.format("%.0fk", distance / 1000) end
  if distance >= 9995 then return string.format("%.1fk", distance / 1000) end
  return util.comma(distance + 0.5)
end
function util.randomName()
  local chars = {}
  for i = 1, 12 do chars[i] = string.char(math.random(97, 122)) end
  return table.concat(chars)
end
B.util = util

-- ---------------------------------------------------------------- environment
function B.camera() return workspace.CurrentCamera end
function B.viewport()
  local camera = workspace.CurrentCamera
  return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end
function B.character(player)
  player = player or B.LP
  return player and player.Character
end
function B.humanoid(player)
  local character = B.character(player)
  return character and character:FindFirstChildOfClass("Humanoid")
end
function B.root(player)
  local character = B.character(player)
  if not character then return nil end
  return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end
function B.clipboard(text)
  local set = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard)
  if not set then return false end
  return (pcall(set, tostring(text)))
end
B.executor = "Unknown"
pcall(function()
  if type(identifyexecutor) == "function" then B.executor = tostring((identifyexecutor())) end
end)
B.touch = false
pcall(function() B.touch = S.UserInputService.TouchEnabled and not S.UserInputService.MouseEnabled end)

-- The GUI parent: the executor's hidden container when it has one.
function B.host()
  if B._host and B._host.Parent then return B._host end
  local host
  if type(gethui) == "function" then
    local ok, hidden = pcall(gethui)
    if ok and typeof(hidden) == "Instance" then host = hidden end
  end
  if not host then
    local ok, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
    if ok and core and pcall(function() return core.Name end) then host = core end
  end
  if not host and B.LP then host = B.LP:FindFirstChildOfClass("PlayerGui") or B.LP:WaitForChild("PlayerGui", 5) end
  B._host = host
  return host
end
B.screens = {}
function B.screen(order, name)
  local gui = Instance.new("ScreenGui")
  table.insert(B.screens, gui)
  gui.Name = name or util.randomName()
  gui.ResetOnSpawn = false
  gui.IgnoreGuiInset = true
  gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  gui.DisplayOrder = order or 9000
  pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
  pcall(function() gui.ClipToDeviceSafeArea = false end)
  gui.Parent = B.host()
  return B.own(gui)
end
end
