do -- 50_settings.lua
-- ============================================================================
--  50 settings   the hub's own preferences and the Settings tab
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Window, Controls = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Window, B.Controls
local Assets = B.Assets
local Prefs = {}
B.Prefs = Prefs
B.pages = B.pages or {}

function Prefs.define()
  Config.define("app.scheme", "dark")
  Config.define("app.accent", Theme.accents[1].color)
  Config.define("app.glass", 60)
  Config.define("app.blur", true)
  Config.define("app.radius", 100)
  Config.define("app.scale", 100)
  Config.define("app.motion", "full")
  Config.define("app.motionSpeed", 100)
  Config.define("app.sfx", true)
  Config.define("app.sfxVolume", 45)
  Config.define("app.key.menu", "RightControl")
  Config.define("app.key.panic", "None")
  Config.define("app.freeCursor", true)
  Config.define("app.window.x", 0.5)
  Config.define("app.window.y", 0.5)
  Config.define("app.intro", "brand")
  Config.define("app.introVolume", 50)
  -- The brand film is everyone's intro from 2026-10-29, for whoever had picked another one too:
  -- it is set once, on the first launch of this build, and from then on the pick is theirs again.
  -- (a counter of its own, kept out of share codes: a pasted code never sets it back)
  Config.define("app.introSeen", 0)
  Config.unshared("app.introSeen")
  if (Config.get("app.introSeen") or 0) < 1 then
    Config.set("app.intro", "brand")
    Config.set("app.introSeen", 1)
  end
  Config.define("app.filmQuality", "auto")
  Config.define("app.island", true)
  Config.define("app.keyHud", true)
  Config.define("app.toasts", true)
  Config.define("app.scrollbar", "always")
  Config.define("app.font", "inter")
end

function Prefs.apply()
  Theme.state.scheme = Config.get("app.scheme")
  Theme.state.accent = Config.get("app.accent")
  Theme.state.glass = Config.get("app.glass") / 100
  Theme.state.radius = Config.get("app.radius") / 100
  Theme.apply()
  Motion.reduced = Config.get("app.motion") == "reduced"
  Motion.speed = Config.get("app.motionSpeed") / 100
  UI.sfxOn = Config.get("app.sfx")
  UI.sfxVolume = Config.get("app.sfxVolume") / 100
  UI.setScrollbar(Config.get("app.scrollbar"))
  B.Blur.set(Config.get("app.blur") == true)
  if Config.get("app.font") ~= "inter" then UI.setLetters(Config.get("app.font")) end
  Config.on("app.font", function(v) UI.setLetters(v) end)
  Motion.every(UI.sweepFonts, 0.1, "ui.fontsweep")

  Config.on("app.scheme", function(v) Theme.set({ scheme = v }) end)
  Config.on("app.accent", function(v) Theme.set({ accent = v }) end)
  Config.on("app.glass", function(v) Theme.set({ glass = v / 100 }) end)
  Config.on("app.radius", function(v) Theme.set({ radius = v / 100 }) end)
  Config.on("app.blur", function(v) B.Blur.set(v == true) end)
  Config.on("app.scale", function() Window.rescale() end)
  Config.on("app.motion", function(v) Motion.reduced = v == "reduced" end)
  Config.on("app.motionSpeed", function(v) Motion.speed = v / 100 end)
  Config.on("app.sfx", function(v) UI.sfxOn = v end)
  Config.on("app.sfxVolume", function(v) UI.sfxVolume = v / 100 end)
  Config.on("app.scrollbar", function(v) UI.setScrollbar(v) end)
  Config.on("app.freeCursor", function(v) if Window.modal then Window.modal.Visible = Window.open and v end end)
end

-- the accent row: a swatch per preset, then a free colour
local function accentPicker(frame)
  local row = UI.frame(frame, { Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 8) })
  UI.list(row, "x", 9, { v = "Center" })
  local rings = {}
  local function mark()
    local current = Config.get("app.accent")
    for color, ring in pairs(rings) do
      Motion.to(ring, "Transparency", util.toHex(color) == util.toHex(current) and 0 or 1, "quick")
    end
  end
  for index, accent in ipairs(Theme.accents) do
    local swatch = UI.frame(row, { Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = accent.color, LayoutOrder = index })
    UI.corner(swatch, true)
    local ring = Instance.new("UIStroke")
    ring.Thickness = 2
    ring.Transparency = 1
    pcall(function() ring.BorderStrokePosition = Enum.BorderStrokePosition.Outer end)
    pcall(function() ring.BorderOffset = UDim.new(0, 2) end)
    Theme.bind(ring, "Color", "ink")
    ring.Parent = swatch
    rings[accent.color] = ring
    local scale = UI.scaleOf(swatch)
    local hit = UI.button(swatch, {
      hover = function(on) Motion.to(scale, "Scale", on and 1.12 or 1, "snappy") end,
      click = function() UI.sfx("click", 0.6); Config.set("app.accent", accent.color) end,
    })
    UI.tooltip(hit, accent.label)
  end
  local custom = UI.frame(row, { Size = UDim2.fromOffset(24, 24), LayoutOrder = 99, Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(custom, true)
  UI.icon(custom, "pipette", 13, "sub", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
  local hit = UI.button(custom, { click = function()
    Controls.colorPopover(custom, Config.get("app.accent"), function(color) Config.set("app.accent", color) end)
  end })
  UI.tooltip(hit, "Any colour")
  Config.on("app.accent", function() if row.Parent then mark() end end)
  mark()
end

B.pages[#B.pages + 1] = function()
  Window.page({ id = "settings", title = "Settings", icon = "settings", group = "Hub", order = 900, eyebrow = "Make it yours", build = function(page)
    local look = page:section({ title = "Appearance", icon = "palette", desc = "Changes apply live." })
    look:dropdown({ id = "app.gui", label = "Menu style", desc = "BASED, the old dark menu, or Novoline's dock.",
      options = { { "based", "BASED" }, { "unnamed", "Unnamed" }, { "novoline", "Novoline" } } })
    do
      local families = {}
      for _, spec in ipairs(UI.FAMILIES) do families[#families + 1] = { spec[1], spec[2] } end
      look:dropdown({ id = "app.font", label = "Font", desc = "Every word in the BASED look.", options = families })
    end
    look:color({ id = "app.unnamed.accent", label = "Unnamed colour", desc = "The line on the Unnamed menu's boxes." })
    if B.Unnamed and B.Unnamed.FONTS then
      local faces = {}
      for _, spec in ipairs(B.Unnamed.FONTS) do faces[#faces + 1] = { spec[1], spec[2] } end
      look:dropdown({ id = "app.unnamed.font", label = "Unnamed font", desc = "Its letters, and its key list's. Monocraft is the Minecraft one.", options = faces })
      look:slider({ id = "app.unnamed.textSize", label = "Unnamed text size", tip = "Text size in the Unnamed look.", min = 80, max = 130, step = 5, suffix = "%" })
      look:toggle({ id = "app.unnamed.watermark", label = "Unnamed watermark", desc = "Name, game, fps, ping and time, top left.", bindable = false })
    end
    if B.Novoline then
      look:color({ id = "app.novoline.accent", label = "Novoline colour", desc = "Its one colour: icons, checks, the island's dot." })
      local faces = {}
      for _, spec in ipairs(B.Novoline.FONTS) do faces[#faces + 1] = { spec[1], spec[2] } end
      look:dropdown({ id = "app.novoline.font", label = "Novoline font", desc = "Gotham is Novoline's own.", options = faces })
      look:slider({ id = "app.novoline.size", label = "Novoline size", tip = "How big the Novoline look is.", min = 70, max = 140, step = 5, suffix = "%" })
      look:slider({ id = "app.novoline.shade", label = "Novoline shade", desc = "How dark the game goes behind it.", min = 0, max = 100, step = 5, suffix = "%" })
      look:toggle({ id = "app.novoline.dock", label = "Keep the dock", desc = "The pill stays at the bottom while it is shut.", bindable = false })
      look:toggle({ id = "app.novoline.island", label = "Novoline island", desc = "The song and every message, top middle.", bindable = false })
    end
    look:segmented({ id = "app.scheme", label = "Scheme", tip = "Dark, light or midnight.", options = { { "dark", "Graphite" }, { "midnight", "Midnight" }, { "light", "Porcelain" } }, width = 232 })
    look:custom({ height = 46, name = "Accent", build = accentPicker })
    look:slider({ id = "app.glass", label = "Glass", desc = "Clear on the left, tinted on the right.", min = 0, max = 100, step = 1, suffix = "%" })
    look:toggle({ id = "app.blur", label = "Real blur", desc = "Blurs the game behind the window. Needs graphics quality 8 or higher.", bindable = false })
    look:slider({ id = "app.radius", label = "Corner roundness", tip = "How round the corners are.", min = 40, max = 130, step = 5, suffix = "%" })
    look:slider({ id = "app.scale", label = "Interface size", desc = "It never grows past the screen.", min = 60, max = 160, step = 5, suffix = "%" })
    look:segmented({ id = "app.scrollbar", label = "Scrollbar", desc = "Drag it, or click beside it to jump.", options = { { "always", "Always" }, { "auto", "Scrolling" }, { "off", "Off" } }, width = 232 })

    local motion = page:section({ title = "Motion & sound", icon = "activity" })
    motion:segmented({ id = "app.motion", label = "Animations", tip = "Full or reduced motion.", options = { { "full", "Full" }, { "reduced", "Reduced" } }, width = 170 })
    motion:slider({ id = "app.motionSpeed", label = "Animation speed", tip = "How fast animations play.", min = 40, max = 250, step = 10, suffix = "%" })
    motion:toggle({ id = "app.sfx", label = "Interface sounds", tip = "Clicks and pops in the menu.", bindable = false })
    motion:slider({ id = "app.sfxVolume", label = "Sound volume", tip = "How loud the menu sounds are.", min = 0, max = 100, step = 5, suffix = "%" })

    local keys = page:section({ title = "Keys", icon = "keyboard" })
    keys:keybind({ tip = "The key that opens and closes the hub.", id = "app.key.menu", label = "Open / close the hub" })
    keys:keybind({ id = "app.key.panic", label = "Panic", desc = "Unloads BASED instantly: every feature off, nothing left behind." })
    keys:toggle({ id = "app.freeCursor", label = "Free the cursor while open", desc = "Unlocks the mouse in first-person games.", bindable = false })
    keys:button({ label = "Every key, on a keyboard", desc = "What each one does, and a click to change it.", text = "Open", bindable = false, run = function() Window.go("keys") end })
    keys:note({ icon = "info", text = "Right-click any toggle or button to bind it to a key." })

    local screen = page:section({ title = "On screen", icon = "monitor", desc = "What stays up while the hub is hidden." })
    screen:toggle({ id = "app.island", label = "The island", desc = "The pill at the top: frame rate and ping, and your speed in flight. Click it to bring the hub back.", bindable = false })
    screen:toggle({ id = "app.keyHud", label = "My keys", desc = "Each bound feature with its key, lit while it is on.", bindable = false })
    screen:toggle({ id = "app.toasts", label = "Say which game this is on launch", tip = "A message naming the game when it loads.", bindable = false })

    if B.Board and B.Board.installed() then
      B.Board.define()
      local board = page:section({ title = "Home board", icon = "film", desc = "The film on the Home tab." })
      board:toggle({ id = "home.board", label = "Play it", desc = "Silent in the card. Off shows a still instead.", bindable = false })
      board:toggle({ id = "home.boardHover", label = "Open on hover", desc = "Rest the mouse on it: it comes forward and the sound comes in.", bindable = false })
      board:slider({ id = "home.boardVolume", label = "Sound volume", tip = "How loud the Home film is.", min = 0, max = 100, step = 5, suffix = "%" })
      board:slider({ id = "home.boardSize", label = "Opened size", desc = "How much of the screen's width it takes.", min = 30, max = 90, step = 2, suffix = "%" })
      board:dropdown({ id = "home.boardQuality", label = "Picture", tip = "Ultra or HD for the Home film.", options = { { "ultra", "Ultra · 1820×1024" }, { "hd", "HD · 1024×576" } } })
    end

    local intro = page:section({ title = "Intro", icon = "clapperboard" })
    intro:dropdown({ id = "app.intro", label = "On launch", desc = "Your edits play with their own sound. Shuffle: a different one each time.",
      options = { { "brand", "BASED brand film" }, { "reel", "Invincible" }, { "lock", "Just use BASED" }, { "prates", "Prates" }, { "richard", "Neverlose vs BASED" }, { "cinematic", "Cinematic" },
        { "signal", "Signal (your avatar, live)" }, { "quick", "Quick" }, { "shuffle", "Shuffle" }, { "off", "Off" } } })
    -- the film and its music are settings only where there is a film: without one the intro is the name alone
    local function anyFilm()
      local quality = Config.get("app.filmQuality")
      if B.Film.pick(quality) or (B.REEL and B.Film.pick(quality, B.REEL)) then return true end
      for _, spec in pairs(B.FILMS or {}) do
        if B.Film.pick(quality, spec) then return true end
      end
      return false
    end
    if B.Film and not B.Assets.lite and anyFilm() then
      intro:slider({ id = "app.introVolume", label = "Music volume", tip = "How loud the intro is.", min = 0, max = 100, step = 5, suffix = "%" })
      -- a choice of picture only where there is one to make: an install fetches the one size its screen suits
      if B.Film.has("hd") and B.Film.has("ultra") then
        intro:dropdown({ id = "app.filmQuality", label = "Film quality", tip = "Ultra or HD for the intro films.", options = { { "auto", "Auto" }, { "ultra", "Ultra · 1820×1024" }, { "hd", "HD · 1024×576" } } })
      end
    end
    intro:button({ label = "Replay the intro", tip = "Plays your intro again.", text = "Play", run = function()
      if not B.Loader then return end
      local chosen = Config.get("app.intro")
      Window.showActive(false)
      B.Loader.run(function() Window.showActive(true) end, chosen == "off" and "signal" or chosen)
    end })

    local data = page:section({ title = "Configs", icon = "save", desc = "Feature settings save on their own." })
    data:segmented({ label = "Saved", tip = "One config for every game, or one per game.", options = { { "global", "One for all games" }, { "game", "One per game" } }, default = Config.profileMode, width = 232,
      changed = function(mode) if mode ~= Config.profileMode then Config.setMode(mode); Window.toast({ title = "Config scope changed", text = mode == "game" and "This game now has its own settings." or "One config for every game.", icon = "save" }) end end })
    data:button({ label = "Copy share code", desc = "Everything: settings, colours, font, keys.", text = "Copy", run = function()
      local code = Config.export()
      if code and B.clipboard(code) then Window.toast({ title = "Share code copied", text = "Whoever pastes it gets your exact setup.", icon = "clipboard", tone = "ok" })
      else Window.toast({ title = "Could not copy", text = "This executor has no clipboard access.", icon = "triangle-alert", tone = "warn" }) end
    end })
    local importBox
    importBox = data:input({ label = "Paste share code", tip = "Paste a code to copy someone's setup.", placeholder = "Paste, then Enter", width = 170, changed = function(text)
      if text == "" then return end
      local ok, count = Config.import(text)
      importBox.box.Text = ""
      Window.toast(ok and { title = "Setup loaded", text = count .. " settings and keys applied.", icon = "circle-check", tone = "ok" }
        or { title = "Not a BASED code", text = "That text could not be read.", icon = "triangle-alert", tone = "warn" })
    end })
    data:button({ label = "Reset every feature", desc = "Appearance and keys are kept.", text = "Reset", style = "danger", run = function()
      Config.resetAll(false)
      Window.toast({ title = "Features reset", text = "Everything is back to its default.", icon = "rotate-ccw" })
    end })

    local about = page:section({ title = "About", icon = "info" })
    local function stat(label, value)
      about:custom({ height = 34, build = function(frame)
        UI.text(frame, label, "label", "sub", { Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13 })
        local text = UI.text(frame, "", "mono", "ink", { Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
        if type(value) == "function" then
          text.Text = tostring(value())
          Motion.every(function() if text.Parent and Window.showing("settings") then text.Text = tostring(value()) end end, 2, "about")
        else text.Text = tostring(value) end
      end })
    end
    stat("Version", B.VERSION .. "  ·  " .. B.BUILD)
    stat("Executor", B.executor)
    stat("Assets", function() return Assets.lite and "missing (lite mode)" or (Assets.calls .. " registered this session") end)
    stat("Started in", function() return (B.bootMs or 0) .. " ms" end)
    stat("Faults", function() return #B.faults end)
    about:button({ label = "Copy diagnostics", tip = "Copies info that helps fix a problem.", text = "Copy", run = function()
      local lines = { "BASED " .. B.VERSION .. " " .. B.BUILD, "executor " .. B.executor, "place " .. game.PlaceId .. " universe " .. game.GameId }
      for _, fault in ipairs(B.faults) do lines[#lines + 1] = string.format("[%.1fs] %s: %s", fault.at, fault.scope, fault.message) end
      B.clipboard(table.concat(lines, "\n"))
      Window.toast({ title = "Diagnostics copied", icon = "clipboard", tone = "ok" })
    end })
    about:button({ label = "Unload BASED", tip = "Turns the hub off completely.", text = "Unload", style = "danger", bindable = false, run = function() B.unload() end })
    about:note({ text = "Fonts: Inter, Instrument Serif, Archivo, Geist Mono (SIL OFL). Icons: Lucide (ISC). Interface sounds: Kenney (CC0)." })
  end })
end
end
