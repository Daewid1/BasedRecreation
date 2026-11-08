do -- 10_registry.lua
-- ============================================================================
--  10 registry  the tree that holds the apples
--
--  A game module is one table handed to BASED.game{...}. When the hub starts it
--  looks the current game up by universe id, then by place id:
--
--    * a module with `tabs`   -> its tabs are built into the hub, under the
--                                game's own heading, above Universal
--    * a module with `script` -> that script is run (a function, a file inside
--                                BasedRecreation/, or a URL)
--    * no module              -> Universal, and the player is told that no
--                                script has been engineered for this game yet
--
--  Modules compiled into the build live in based/games/*.lua. A .lua file
--  dropped into the executor's BasedRecreation/games/ folder is picked up the same way
--  with no rebuild: it is called with the hub table and calls hub.game{...}.
-- ============================================================================
local S, fs, Window, Config = B.S, B.fs, B.Window, B.Config
local Registry = { games = {}, active = nil, gameName = nil }
B.Registry = Registry

-- spec: id, name, places = {..}, universes = {..}, icon, tabs = function(hub), script,
--       universal (default true; false = the Universal tabs and the systems behind them are never started;
--       a list such as { "visuals" } = only those of visuals / combat / movement / players / world are)
function B.game(spec)
  if type(spec) ~= "table" or type(spec.id) ~= "string" then error("BASED.game needs a table with an id", 2) end
  spec.name = spec.name or spec.id
  spec.places, spec.universes = spec.places or {}, spec.universes or {}
  Registry.games[#Registry.games + 1] = spec
  return spec
end

local function loadDropIns()
  for _, file in ipairs(fs.list(fs.path("games"))) do
    if string.match(file, "%.lua$") or string.match(file, "%.luau$") then
      local source = fs.read(file)
      local name = string.match(file, "([^/]+)$") or file
      if source then
        local chunk, problem = loadstring(source, "=" .. name)
        if chunk then B.try("game file " .. name, chunk, B) else B.fault("game file " .. name, problem) end
      end
    end
  end
end

local function match()
  local universe, place = game.GameId, game.PlaceId
  for _, spec in ipairs(Registry.games) do
    if table.find(spec.universes, universe) then return spec end
  end
  for _, spec in ipairs(Registry.games) do
    if table.find(spec.places, place) then return spec end
  end
  return nil
end

local function runScript(spec)
  local script = spec.script
  if type(script) == "function" then
    task.spawn(B.safe("game script " .. spec.id, script), B)
    return
  end
  if type(script) ~= "string" then return end
  task.spawn(B.safe("game script " .. spec.id, function()
    local source
    if string.match(script, "^https?://") then source = B.httpGet(script) else source = fs.read(fs.path(script)) end
    if not source then error("script not found: " .. script) end
    local chunk, problem = loadstring(source, "=" .. spec.id)
    if not chunk then error(problem) end
    chunk(B)
  end))
end

-- The module for this game, looked up before any page is registered: a module that says
-- `universal = false` keeps the Universal systems from starting at all, not just out of sight.
function Registry.pick()
  if Registry.picked then return Registry.active end
  Registry.picked = true
  loadDropIns()
  Registry.active = match()
  return Registry.active
end
function Registry.universal()
  local spec = Registry.active
  return not (spec and (spec.universal == false or type(spec.universal) == "table"))
end
-- is this one of Universal's tabs loaded in this game?
function Registry.keeps(name)
  local spec = Registry.active
  if not spec or spec.universal == nil or spec.universal == true then return true end
  return type(spec.universal) == "table" and table.find(spec.universal, name) ~= nil
end

function Registry.resolve()
  local spec = Registry.pick()
  -- the game's public name, for the intro and the home card (a web call: never wait on it)
  task.spawn(function()
    local ok, info = pcall(function() return S.MarketplaceService:GetProductInfo(game.PlaceId) end)
    if ok and type(info) == "table" and type(info.Name) == "string" then
      Registry.gameName = info.Name
      if Registry.onName then B.try("registry.name", Registry.onName, info.Name) end
    end
  end)
  if not spec then return end
  if spec.tabs then
    local order = 100
    local hub = { game = spec, B = B, Config = Config, toast = Window.toast }
    -- hub:page{ id, title, icon, build = function(page) ... end }
    function hub:page(pageSpec)
      order += 1
      pageSpec.id = spec.id .. "." .. (pageSpec.id or tostring(order))
      -- in a game that has a script, its first tab is where the hub opens
      if order == 101 then Window.startPage = pageSpec.id end
      pageSpec.group = spec.name
      pageSpec.order = order
      pageSpec.eyebrow = pageSpec.eyebrow or spec.name
      return Window.page(pageSpec)
    end
    B.try("game tabs " .. spec.id, spec.tabs, hub)
  end
  if spec.universal == false then
    for _, page in ipairs(Window.order) do
      if page.group == "Universal" then page.hidden = true end
    end
  end
  if spec.script then runScript(spec) end
end

function Registry.status()
  local spec = Registry.active
  return { engineered = spec ~= nil, name = spec and spec.name or nil, tagline = spec and spec.tagline or nil, gameName = Registry.gameName, count = #Registry.games,
    mode = spec and (spec.tabs and "tabs" or "script") or "universal", universal = Registry.universal(),
    kept = spec and type(spec.universal) == "table" and spec.universal or nil }
end

function Registry.announce()
  if Config.get("app.toasts") == false then return end
  local spec = Registry.active
  if spec then
    Window.toast({ title = "Engineered for " .. spec.name, text = spec.tabs and (Registry.universal() and "Its tabs are in the sidebar." or (type(spec.universal) == "table" and "Its own tabs, and what it keeps of Universal." or "Its own tabs only: Universal is not loaded here.")) or "Its script is running.",
      icon = "badge-check", tone = "ok", time = 5 })
  else
    Window.toast({ title = "No script engineered for this game yet", text = "Universal is loaded and ready.", icon = "info", tone = "accent", time = 6 })
  end
end
end
