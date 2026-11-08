do -- 20_home.lua
-- ============================================================================
--  20 home     what game this is, whether it has a script, session numbers
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Window, Assets, Registry, Hud = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Window, B.Assets, B.Registry, B.Hud
B.pages = B.pages or {}

local function visible() return Window.showing("home") end

local function hero(frame)
  local status = Registry.status()
  local card = UI.surface(frame, { Name = "Hero", Size = UDim2.new(1, 0, 0, 214), ClipsDescendants = true }, "rCard")
  UI.stroke(card, "ink", "strokeA")
  -- The board: a film that plays silently in the card and opens with its sound when the mouse
  -- rests on it. Where it is not installed (or switched off), a still from the intro stands in.
  local film = B.Film and B.Film.spec
  local picture
  if film and not Assets.lite then
    local still = Assets.frame(film.sets.hd.tiles[1].path, 378, film.sets.hd.digits)
    if still then
      picture = UI.new("ImageLabel", { Name = "Still", BackgroundTransparency = 1, Image = still, ScaleType = Enum.ScaleType.Crop, Size = UDim2.new(0.62, 0, 1, 0),
        Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), ImageTransparency = 0.25, Parent = card })
      UI.corner(picture, "rCard")
      UI.gradient(picture, { Transparency = UI.alphaSeq(0, 1, 0.55, 0.35, 1, 0.1) })
    end
  end
  if B.Board then B.try("home.board", B.Board.mount, card, picture) end
  local text = UI.frame(card, { Name = "Text", Size = UDim2.new(0.66, 0, 1, 0) })
  UI.pad(text, 22, 0, 20, 24)
  UI.list(text, "y", 6, { v = "Bottom" })
  local eyebrow = UI.frame(text, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
  UI.list(eyebrow, "x", 8, { v = "Center" })
  local pip = UI.frame(eyebrow, { Size = UDim2.fromOffset(7, 7), LayoutOrder = 1, Theme = { BackgroundColor3 = status.engineered and "ok" or "accent" }, BackgroundTransparency = 0 })
  UI.corner(pip, true)
  UI.text(eyebrow, status.engineered and "ENGINEERED FOR THIS GAME" or "NO SCRIPT ENGINEERED FOR THIS GAME YET", "eyebrow", status.engineered and "ok" or "sub", { LayoutOrder = 2 })
  local title = UI.text(text, status.engineered and status.name or "Universal", "display", "ink", { TextSize = 46, LayoutOrder = 2, TextTruncate = Enum.TextTruncate.AtEnd,
    AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
  local function line()
    local name = Registry.gameName and ("“" .. Registry.gameName .. "”") or "this game"
    if status.engineered then
      if status.kept then return "Its own tabs are in the sidebar. Of Universal, only " .. table.concat(status.kept, ", ") .. " is loaded in this game." end
      if not status.universal then return "Its own tabs are in the sidebar. Universal is not loaded in this game." end
      return status.mode == "tabs" and "Its tabs are in the sidebar, above Universal." or "Its script is running. Universal is here too."
    end
    return "Nothing has been built for " .. name .. " yet, so BASED loaded Universal: aim, ESP, movement and the rest work in any game."
  end
  local sub = UI.text(text, line(), "body", "sub", { TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, LineHeight = 1.25 })
  Registry.onName = function() if sub.Parent then sub.Text = line() end end
  local _ = title
  -- pulse on the status pip
  local ring = UI.frame(pip, { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Theme = { BackgroundColor3 = status.engineered and "ok" or "accent" }, BackgroundTransparency = 0.5 })
  UI.corner(ring, true)
  local phase = 0
  Motion.every(function(dt)
    if not ring.Parent or not visible() then return end
    phase = (phase + dt / 1.8) % 1
    local p = Motion.ease.outCubic(phase)
    ring.Size = UDim2.fromScale(1 + p * 2.4, 1 + p * 2.4)
    ring.BackgroundTransparency = 0.5 + 0.5 * p
  end, 30, "home.pulse")
end

local function stats(frame)
  local row = UI.frame(frame, { Name = "Stats", Size = UDim2.new(1, 0, 0, 74) })
  local tiles = {}
  local specs = {
    { "gauge", "FPS", function() return tostring(math.floor(Hud.fps() + 0.5)) end },
    { "wifi", "PING", function() return math.floor(Hud.ping() + 0.5) .. " ms" end },
    { "users", "PLAYERS", function() return #S.Players:GetPlayers() .. " / " .. S.Players.MaxPlayers end },
    { "timer", "SESSION", function()
      local s = math.floor(os.clock() - B.bootClock)
      return string.format("%d:%02d", s // 60, s % 60)
    end },
  }
  for index, spec in ipairs(specs) do
    local tile = UI.surface(row, { Size = UDim2.new(0.25, -9, 1, 0), Position = UDim2.new((index - 1) * 0.25, (index - 1) * 3, 0, 0) }, "rCard")
    UI.stroke(tile, "ink", "strokeA")
    UI.icon(tile, spec[1], 15, "faint", { Position = UDim2.fromOffset(14, 14) })
    UI.text(tile, spec[2], "eyebrow", "faint", { Position = UDim2.fromOffset(36, 15), TextSize = 9 })
    tiles[index] = { label = UI.text(tile, spec[3](), "monoBold", "ink", { Position = UDim2.fromOffset(14, 40), TextSize = 19 }), read = spec[3] }
  end
  Motion.every(function()
    if not row.Parent or not visible() then return end
    for _, tile in ipairs(tiles) do tile.label.Text = tile.read() end
  end, 2, "home.stats")
end

local function library(page)
  local games = Registry.games
  local section = page:section({ title = "Library", icon = "layers", full = true,
    desc = #games == 0 and "Game scripts show up here as they are engineered." or (#games .. (#games == 1 and " game script installed." or " game scripts installed.")) })
  if #games == 0 then
    section:custom({ height = 148, build = function(frame)
      local box = UI.frame(frame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(470, 0), AutomaticSize = Enum.AutomaticSize.Y })
      UI.list(box, "y", 8, { h = "Center" })
      local orb = UI.frame(box, { Size = UDim2.fromOffset(46, 46), LayoutOrder = 1, Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
      UI.corner(orb, true)
      UI.icon(orb, "sprout", 21, "accent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
      UI.text(box, "The tree is planted. No apples yet.", "heading", "ink", { LayoutOrder = 2 })
      UI.text(box, "When a script is engineered for a game, joining that game switches BASED to its tabs on its own. Everywhere else you get Universal.",
        "caption", "sub", { LayoutOrder = 3, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0),
          AutomaticSize = Enum.AutomaticSize.Y, LineHeight = 1.25 })
    end })
    return
  end
  for _, spec in ipairs(games) do
    local active = Registry.active == spec
    section:custom({ height = 46, build = function(frame)
      UI.icon(frame, spec.icon or "gamepad-2", 17, active and "accent" or "sub", { Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
      UI.text(frame, spec.name, "label", "ink", { Position = UDim2.new(0, 42, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
      if active then
        UI.badge(frame, "ACTIVE", "ok", { Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
      else
        UI.text(frame, spec.tabs and "tabs" or "script", "mono", "faint", { Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
      end
    end })
  end
end

B.pages[#B.pages + 1] = function()
  Window.page({ id = "home", title = "Home", icon = "house", group = "", order = 10, eyebrow = "Welcome back, " .. B.LP.DisplayName, build = function(page)
    page:custom(214, hero)
    page:custom(74, stats)
    library(page)
    local quick = page:section({ title = "Quick actions", icon = "zap" })
    quick:button({ id = "home.rejoin", label = "Rejoin this server", tip = "Leaves and joins this server again.", text = "Rejoin", run = function() if B.HussServer then B.HussServer.rejoin() end end })
    quick:button({ id = "home.hop", label = "Find another server", tip = "Moves you to a different server.", text = "Hop", run = function() if B.HussServer then B.HussServer.hop() end end })
    local tips = page:section({ title = "Good to know", icon = "lightbulb" })
    tips:note({ icon = "keyboard", text = "Right-click a toggle or a button to bind it to a key. Right-click anything to reset it." })
    tips:note({ icon = "search", text = "Ctrl K searches every setting in every tab." })
    tips:note({ icon = "eye-off", text = Config.keyLabel(Config.get("app.key.menu")) .. " hides the hub. The island at the top brings it back." })
  end })
  Window.startPage = Window.startPage or "home"
end
end
