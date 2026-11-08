do -- 05_config.lua
-- ============================================================================
--  05 config   flags, profiles, keybinds
--
--  Every setting is a flag with an id. Ids under "app." are the hub's own
--  preferences (theme, intro, scale) and live in prefs.json; everything else is
--  a feature setting and lives in the active profile, which can be one file for
--  every game or one per game. Writes are debounced; nothing saves per frame.
-- ============================================================================
local S, fs, util = B.S, B.fs, B.util
local UIS = S.UserInputService
local Config = { profile = "default", changed = B.Signal.new(), loaded = B.Signal.new() }
B.Config = Config

local values, defaults, listeners = {}, {}, {}
local binds = {}            -- flag id -> { key = "E", mode = "toggle" | "hold" }
local actions = {}          -- id -> function, for bindable buttons
local stored = { app = {}, profile = {} }   -- raw decoded files, kept so unknown ids survive a save
local storedBinds = {}
Config.values, Config.defaults, Config.binds = values, defaults, binds

local function isApp(id) return string.sub(id, 1, 4) == "app." end
local function encode(value)
  local kind = typeof(value)
  if kind == "Color3" then return { __c = util.toHex(value) } end
  if kind == "EnumItem" then return { __e = tostring(value.EnumType), v = value.Name } end
  if kind == "table" then
    local out = {}
    for k, v in pairs(value) do out[k] = encode(v) end
    return out
  end
  return value
end
local function decode(value)
  if type(value) ~= "table" then return value end
  if type(value.__c) == "string" then
    local ok, color = pcall(util.hex, value.__c)
    return ok and color or nil
  end
  if value.__e then
    local ok, item = pcall(function() return Enum[value.__e][value.v] end)
    return ok and item or nil
  end
  local out = {}
  for k, v in pairs(value) do out[k] = decode(v) end
  return out
end
local function sameType(a, b)
  return typeof(a) == typeof(b)
end

-- What the hub ships with (based/shipped.json, baked in by the build): the settings a fresh
-- executor starts from. A shipped value takes the place of the default written in the code, so
-- a setting someone has saved still wins and Reset comes back to what shipped.
local shipped = type(B.SHIPPED) == "table" and B.SHIPPED or {}
local shippedValues = type(shipped.values) == "table" and shipped.values or {}
local shippedBinds = type(shipped.binds) == "table" and shipped.binds or {}

local function profilePath(name) return fs.path("config/" .. name .. ".json") end
local PREFS = fs.path("prefs.json")

-- Saving. Only what changed here is written, onto what is on disk at that moment: every account
-- open on this PC shares these files, and writing the whole of one client's memory undid what
-- another had just saved. A change made quietly (a test, a bot starting itself) is never written.
-- Whatever is waiting goes out at once on unload and on a teleport, not 0.6 s later or never.
local dirty, dirtyBinds = {}, {}
local pending = false
local function isDefault(id)
  local a, b = values[id], defaults[id]
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k, v in pairs(b) do if a[k] ~= v then return false end end
  return true
end
local function flush()
  pending = false
  if next(dirty) == nil and next(dirtyBinds) == nil then return end
  local appTouched = false
  local prefs = fs.readJson(PREFS)
  prefs = type(prefs) == "table" and prefs or {}
  local app = type(prefs.values) == "table" and prefs.values or stored.app
  local bindOut = type(prefs.binds) == "table" and prefs.binds or nil
  if not bindOut then
    -- (nothing on disk yet: every key there is, the ones that shipped too, or they would be lost)
    bindOut = {}
    for id, bind in pairs(binds) do bindOut[id] = { key = bind.key, mode = bind.mode } end
    appTouched = true
  end
  local disk = fs.readJson(profilePath(Config.profile))
  local profile = (type(disk) == "table" and type(disk.values) == "table") and disk.values or stored.profile
  local profileTouched = false
  for id in pairs(dirty) do
    local bucket = isApp(id) and app or profile
    if values[id] == nil or isDefault(id) then bucket[id] = nil else bucket[id] = encode(values[id]) end
    if isApp(id) then appTouched = true else profileTouched = true end
  end
  for id in pairs(dirtyBinds) do
    local bind = binds[id]
    bindOut[id] = bind and { key = bind.key, mode = bind.mode } or nil
    appTouched = true
  end
  table.clear(dirty)
  table.clear(dirtyBinds)
  stored.app, stored.profile = app, profile
  if appTouched or prefs.profile ~= Config.profileMode then
    fs.writeJson(PREFS, { values = app, binds = bindOut, profile = Config.profileMode })
  end
  if profileTouched then
    fs.writeJson(profilePath(Config.profile), { values = profile, game = game.GameId, saved = os.time() })
  end
  Config.saved:fire()
end
Config.saved = B.Signal.new()
local later = util.debounce(0.6, function() if pending then B.try("config.save", flush) end end)
local function save() pending = true; later() end
function Config.save() save() end
-- write what is waiting now (unload, teleport, a profile switch)
function Config.flush() if pending or next(dirty) or next(dirtyBinds) then B.try("config.flush", flush) end end
function Config.touch(id) dirty[id] = true; save() end
B.onUnload:connect(function() Config.flush() end)

-- Register a flag. Returns its current value (the saved one when there is one).
function Config.define(id, default)
  if defaults[id] ~= nil then return values[id] end
  local ships = decode(shippedValues[id])
  if ships ~= nil and sameType(ships, default) then default = ships end
  defaults[id] = default
  local bucket = isApp(id) and stored.app or stored.profile
  local saved = decode(bucket[id])
  if saved ~= nil and sameType(saved, default) then values[id] = saved else values[id] = default end
  local savedBind = storedBinds[id]
  if savedBind and savedBind.key and not binds[id] then
    binds[id] = { key = savedBind.key, mode = savedBind.mode or "toggle" }
    -- (a switch made after the keys started listening, on a tab built later: its key works at once)
    if Config.reindex then Config.reindex() end
  end
  return values[id]
end
function Config.get(id) return values[id] end
function Config.set(id, value, quiet)
  if defaults[id] == nil then defaults[id] = value end
  local old = values[id]
  if old == value and type(value) ~= "table" then return end
  values[id] = value
  local list = listeners[id]
  if list then
    for _, fn in ipairs(table.clone(list)) do B.try("config." .. id, fn, value, old) end
  end
  if not quiet then
    dirty[id] = true
    Config.changed:fire(id, value)
    save()
  end
end
function Config.reset(id) if defaults[id] ~= nil then Config.set(id, util.copy(defaults[id])) end end
function Config.isDefault(id) return isDefault(id) end
-- fn(value, old) on every change; `now` also calls it once with the current value.
function Config.on(id, fn, now)
  local list = listeners[id]
  if not list then list = {}; listeners[id] = list end
  list[#list + 1] = fn
  if now and values[id] ~= nil then B.try("config." .. id, fn, values[id], nil) end
  return function()
    local at = table.find(list, fn)
    if at then table.remove(list, at) end
  end
end
-- Mirror a set of flags into a plain table that feature loops can read for free:
--   local O = Config.mirror({ enabled = "esp.enabled", range = "esp.range" })
function Config.mirror(map, onChange)
  local out = {}
  for key, id in pairs(map) do
    out[key] = values[id]
    Config.on(id, function(value)
      out[key] = value
      if onChange then onChange(key, value) end
    end)
  end
  return out
end

-- ---------------------------------------------------------------- profiles
Config.profileMode = "global"     -- "global": one config everywhere; "game": one per game
function Config.profiles()
  local out = {}
  for _, file in ipairs(fs.list(fs.path("config"))) do
    local name = string.match(file, "([^/]+)%.json$")
    if name then out[#out + 1] = name end
  end
  if not table.find(out, "default") then table.insert(out, 1, "default") end
  return out
end
local function readProfile(name)
  local data = fs.readJson(profilePath(name))
  return type(data) == "table" and type(data.values) == "table" and data.values or {}
end
function Config.init()
  local prefs = fs.readJson(PREFS)
  if type(prefs) == "table" then
    stored.app = type(prefs.values) == "table" and prefs.values or {}
    storedBinds = type(prefs.binds) == "table" and prefs.binds or {}
    if prefs.profile == "game" then Config.profileMode = "game" end
  else
    -- nothing saved here yet: the keys that ship. Only then, or a key someone cleared would come back.
    storedBinds = shippedBinds
    -- (and the first launch on this machine: the look is picked before the hub opens, src/13_picker)
    Config.firstRun = true
  end
  Config.profile = Config.profileMode == "game" and ("game_" .. tostring(game.GameId)) or "default"
  stored.profile = readProfile(Config.profile)
  -- (a teleport ends this client: what is waiting is written as it starts)
  pcall(function()
    B.connect(B.LP.OnTeleport, function(state)
      if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then Config.flush() end
    end, "config.teleport")
  end)
end
-- Switch to another profile: every feature flag takes the value saved there.
function Config.load(name)
  Config.flush()                          -- (what is waiting belongs to the profile being left)
  Config.profile = name
  stored.profile = readProfile(name)
  for id, default in pairs(defaults) do
    if not isApp(id) then
      local saved = decode(stored.profile[id])
      if saved == nil or not sameType(saved, default) then saved = util.copy(default) end
      Config.set(id, saved, true)
    end
  end
  Config.loaded:fire(name)
  -- (the mode lives in prefs.json)
  local prefs = fs.readJson(PREFS)
  if type(prefs) == "table" and prefs.profile ~= Config.profileMode then
    prefs.profile = Config.profileMode
    fs.writeJson(PREFS, prefs)
  end
end
function Config.saveAs(name)
  name = string.gsub(name, "[^%w_%-]", "")
  if name == "" then return false end
  Config.flush()
  Config.profile = name
  stored.profile = {}
  for id in pairs(defaults) do
    if not isApp(id) then dirty[id] = true end
  end
  save()
  return true
end
function Config.delete(name)
  if name == "default" then return false end
  return fs.remove(profilePath(name))
end
function Config.setMode(mode)
  Config.profileMode = mode
  Config.load(mode == "game" and ("game_" .. tostring(game.GameId)) or "default")
end
function Config.resetAll(includeApp)
  for id, default in pairs(defaults) do
    if includeApp or not isApp(id) then Config.set(id, util.copy(default)) end
  end
end
-- The share code: EVERY setting (the look too: colours, font, menu style, intro) and every key,
-- as "BASED2:" and base64. Pasted in, the other hub becomes this one: what the code has is set,
-- and what it leaves out is put back to its default, so nothing of theirs is left mixed in.
-- (The first version carried feature settings only, and only ones changed from their defaults:
-- a colour, a key, or a setting the other person had changed and this one had not stayed theirs.)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function toBase64(data)
  return ((string.gsub(data, ".", function(x)
    local r, byte = "", string.byte(x)
    for i = 8, 1, -1 do r ..= (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0") end
    return r
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then return "" end
    local c = 0
    for i = 1, 6 do c += (string.sub(x, i, i) == "1" and 2 ^ (6 - i) or 0) end
    return string.sub(B64, c + 1, c + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function fromBase64(data)
  data = string.gsub(data, "[^" .. B64 .. "=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then return "" end
    local r, f = "", (string.find(B64, x, 1, true) - 1)
    for i = 6, 1, -1 do r ..= (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
    return r
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
    if #x ~= 8 then return "" end
    local c = 0
    for i = 1, 8 do c += (string.sub(x, i, i) == "1" and 2 ^ (8 - i) or 0) end
    return string.char(c)
  end))
end
Config.toBase64, Config.fromBase64 = toBase64, fromBase64
-- where windows sit is the screen's business, not a setup's
local PLACE = { ["app.window.x"] = true, ["app.window.y"] = true, ["app.unnamed.x"] = true, ["app.unnamed.y"] = true, ["app.keyHudX"] = true, ["app.keyHudY"] = true }
-- (and some things are yours alone: a share code leaves them out, and pasting one leaves yours be)
function Config.unshared(id) PLACE[id] = true end
function Config.export()
  local out, keys = {}, {}
  for id, value in pairs(values) do
    if not PLACE[id] and defaults[id] ~= nil and not isDefault(id) then out[id] = encode(value) end
  end
  for id, bind in pairs(binds) do
    if bind.key then keys[id] = { key = bind.key, mode = bind.mode } end
  end
  local ok, json = pcall(S.HttpService.JSONEncode, S.HttpService, { based = 2, values = out, binds = keys, full = true })
  return ok and ("BASED2:" .. toBase64(json)) or nil
end
function Config.import(text)
  text = tostring(text or "")
  local json = text
  local coded = string.match(text, "BASED2:(%S+)")
  if coded then json = fromBase64(coded) end
  local ok, data = pcall(S.HttpService.JSONDecode, S.HttpService, json)
  if not ok or type(data) ~= "table" or type(data.values) ~= "table" then return false, 0 end
  local count = 0
  -- (an old code holds feature settings only, changed ones: those alone are set)
  if data.full then
    for id, default in pairs(defaults) do
      if data.values[id] == nil and not PLACE[id] and not isDefault(id) then Config.set(id, util.copy(default)) end
    end
  end
  for id, raw in pairs(data.values) do
    local default = defaults[id]
    local value = decode(raw)
    if default ~= nil and value ~= nil and sameType(value, default) and not PLACE[id] and (data.full or not isApp(id)) then
      Config.set(id, value)
      count += 1
    end
  end
  if type(data.binds) == "table" then
    for id in pairs(table.clone(binds)) do
      if data.binds[id] == nil then Config.bind(id, nil) end
    end
    for id, bind in pairs(data.binds) do
      if type(bind) == "table" and type(bind.key) == "string" then Config.bind(id, bind.key, bind.mode == "hold" and "hold" or "toggle"); count += 1 end
    end
  end
  return true, count
end

-- ---------------------------------------------------------------- keybinds
local byKey = {}
local function keyName(input)
  if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
  if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
  if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
  return nil
end
Config.keyName = keyName
local function reindex()
  table.clear(byKey)
  for id, bind in pairs(binds) do
    if bind.key then
      local list = byKey[bind.key]
      if not list then list = {}; byKey[bind.key] = list end
      list[#list + 1] = id
    end
  end
end
Config.reindex = reindex
Config.bindsChanged = B.Signal.new()
function Config.bind(id, key, mode)
  if not key then binds[id] = nil else binds[id] = { key = key, mode = mode or (binds[id] and binds[id].mode) or "toggle" } end
  reindex()
  dirtyBinds[id] = true
  Config.bindsChanged:fire(id)
  save()
end
function Config.bindOf(id) return binds[id] end
-- A button that can be bound (an emote, mark the one looked at...). Its saved key comes back here:
-- before, only switches took theirs back (in define), and every key on a button was lost on rejoin.
function Config.action(id, fn)
  actions[id] = fn
  local savedBind = storedBinds[id]
  if savedBind and savedBind.key and not binds[id] then
    binds[id] = { key = savedBind.key, mode = savedBind.mode or "toggle" }
    reindex()
    Config.bindsChanged:fire(id)
  end
end
function Config.isAction(id) return actions[id] ~= nil end
-- Whether a button's work is going on, for the key list to light it like a switch that is on: its
-- own say if it has one (an emote: while it plays), else for a moment after its key was pressed.
local actionStates = {}
Config.ranAt = {}
Config.actionRan = B.Signal.new()
function Config.actionState(id, fn) actionStates[id] = fn end
function Config.isActive(id)
  local state = actionStates[id]
  if state then
    local ok, on = pcall(state)
    if ok and on then return true end
    if ok and on == false then return false end
  end
  local at = Config.ranAt[id]
  return at ~= nil and os.clock() - at < 0.6
end
local SHORT = { LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift", LeftAlt = "LAlt", RightAlt = "RAlt",
  MouseButton2 = "RMB", MouseButton3 = "MMB", Return = "Enter", Backspace = "Bksp", CapsLock = "Caps", Escape = "Esc", Delete = "Del",
  Insert = "Ins", PageUp = "PgUp", PageDown = "PgDn", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
  LeftBracket = "[", RightBracket = "]", Minus = "-", Equals = "=", Backquote = "`", Space = "Space", Unknown = "None",
  One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0" }
function Config.keyLabel(key)
  if not key then return "None" end
  return SHORT[key] or (string.gsub(key, "^Keypad", "Num"))
end
Config.capturing = false   -- true while a keybind control is listening for a key
-- A switch can have a quick panel: its key tapped flips it as always, its key HELD (0.3 s) opens the
-- panel instead and letting go closes it (the ragebot's: who to hunt). { open = fn, close = fn }
Config.holdPanels = {}
local held = {}
local HOLD = 0.3

function Config.listen()
  reindex()
  B.connect(UIS.InputBegan, function(input, processed)
    if Config.capturing then return end
    local key = keyName(input)
    if not key then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
      if UIS:GetFocusedTextBox() then return end
      if key == "K" and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then return end
    elseif processed then
      return
    end
    local list = byKey[key]
    if not list then return end
    for _, id in ipairs(list) do
      local bind = binds[id]
      local panel = Config.holdPanels[id]
      if actions[id] then
        B.try("bind." .. id, actions[id])
        Config.ranAt[id] = os.clock()
        Config.actionRan:fire(id)
      elseif type(values[id]) == "boolean" and panel and bind.mode ~= "hold" then
        -- (decided when it is let go: a tap flips it, a hold opened the panel)
        local mine = { at = os.clock(), key = key }
        held[id] = mine
        task.delay(HOLD, function()
          if held[id] == mine and Config.keyDown(key) then
            mine.opened = true
            B.try("hold." .. id, panel.open, key)
          end
        end)
      elseif type(values[id]) == "boolean" then
        if bind.mode == "hold" then Config.set(id, true) else Config.set(id, not values[id]) end
      end
    end
  end, "keybinds")
  B.connect(UIS.InputEnded, function(input)
    local key = keyName(input)
    local list = key and byKey[key]
    if not list then return end
    for _, id in ipairs(list) do
      local bind = binds[id]
      local press = held[id]
      if press and press.key == key then
        held[id] = nil
        if press.opened then
          local panel = Config.holdPanels[id]
          if panel and panel.close then B.try("hold.close." .. id, panel.close) end
        elseif type(values[id]) == "boolean" then
          Config.set(id, not values[id])
        end
      elseif bind.mode == "hold" and type(values[id]) == "boolean" and not actions[id] then
        Config.set(id, false)
      end
    end
  end, "keybinds")
end
-- true while the key bound to `id` (or `key`) is physically down
function Config.keyDown(key)
  if not key then return false end
  if key == "MouseButton2" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
  if key == "MouseButton3" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
  local ok, code = pcall(function() return Enum.KeyCode[key] end)
  return ok and code ~= nil and UIS:IsKeyDown(code)
end
end
