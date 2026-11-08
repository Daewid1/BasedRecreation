do -- 09_loader.lua
-- ============================================================================
--  09 loader   the intro, cut to the film
--
--  Cinematic plays the whole edit, all 18.7 seconds of it, in three acts. Every
--  cue is a time in the film, read from the player's own clock, so type and
--  picture cannot drift apart.
--
--    opening    0.00   the film opens under letterbox bars, with a greeting
--    blackout   2.90   the edit goes black for three seconds: the wordmark
--                      assembles in the dark while the track builds
--    drop       5.93   the picture slams back under the wordmark, bars fly open
--    lines      9.22   the wordmark leaves on the edit's white flash; one line
--                      of type per cut, changing on the cut
--    finale    15.52   the wordmark returns with the key that opens the hub
--    out       18.62   white, and the hub is there when it clears
--
--    quick      4.75 -> 6.88 s of the film (wordmark, drop, out)
--    lock, prates, brand, richard   the 2026-10-29 films (tools/edit_films.py): finished pieces with our
--               mark already in them and their own sound, played whole ("bare": only the quiet
--               chrome round them, no type, bars or flashes of the loader's own)
--    off        straight to the hub
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Assets, Film = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Assets, B.Film
local UIS = S.UserInputService
local Loader = { active = false }
B.Loader = Loader
local ease = Motion.ease
local win = Motion.window

local DROP = 5.9333
-- Each mode plays one film: "intro" (B.FILM, the BASED edit) or "reel" (B.REEL, the author's own
-- edit, tools/film.py --name reel). `drop` is that film's drop; `calm` where its picture settles
-- before it; `greet` when the greeting comes in and goes.
local MODES = {
  -- (type: how its words are set. editorial: serif italic rising out of a mask, side to side;
  -- impact: heavy wide capitals, spaced out, slammed in on the hit, a bar wiping under them)
  cinematic = { film = "intro", type = "editorial", drop = DROP, calm = 2.9, greet = { 0.7, 2.3 }, start = 0, exit = 18.62, word = 3.05, stagger = 0.11, rise = 0.78, hub = 3.78, rule = 4.2,
    status = 4.5, wordOut = 9.2167, wordBack = 15.5167, greeting = true,
    -- one line per cut of the edit, from the flash at 9.22 to the finale
    lines = {
      { 9.2167, "One hub." }, { 10.05, "Every game." }, { 10.75, "Engineered" }, { 11.3833, "for the game" }, { 12.3333, "you’re in." },
      { 13.15, "Universal" }, { 13.95, "everywhere else." }, { 14.65, "Aim. See. Move." },
    }, linesEnd = 15.5167 },
  quick = { film = "intro", drop = DROP, calm = 2.9, start = 4.75, exit = 6.8833, word = 4.8, stagger = 0.06, rise = 0.5, hub = 5.12, rule = 5.3, status = 5.42 },
  -- The author's edit (17.23 s), whole and with its own track, to its last frame (asked for: the full
  -- version). Two hits, a quiet build in space from 1.9 s, the drop at 4.62 s, then a hit every 1.15 s:
  -- the greeting in the quiet, the wordmark assembled over the build and hit on the drop, a line on
  -- each hit, and the wordmark back for the end.
  reel = { film = "reel", type = "impact", drop = 4.6167, calm = 4.4, greet = { 2.0, 3.35 }, margin = 0.125, start = 0, exit = 17.2333, whole = true, word = 3.35, stagger = 0.1, rise = 0.7, hub = 3.95,
    rule = 4.15, status = 4.35, wordOut = 7.0, wordBack = 15.05, greeting = true,
    lines = {
      { 7.0, "One hub." }, { 8.1667, "Every game." }, { 9.3, "Engineered for" }, { 10.4667, "the game you’re in." },
      { 11.6167, "Universal" }, { 12.7667, "everywhere else." }, { 13.9167, "Aim. See. Move." },
    }, linesEnd = 15.05 },
  -- the author's clips made ours (2026-10-29): "Just use BASED" with the mark locked on his head and
  -- the score against each script down the side, the Prates edit the same way, and the pomade ad
  -- with our name on the tin and our card at the end. Each plays to its last frame.
  lock = { film = "lock", bare = true, start = 0, whole = true },
  prates = { film = "prates", bare = true, start = 0, whole = true },
  brand = { film = "brand", bare = true, start = 0, whole = true },
  -- (the son and the father: the son is Neverlose, the father is BASED, coming in on the drop)
  richard = { film = "richard", bare = true, start = 0, whole = true },
}
local function specOf(plan)
  if not plan then return Film.spec end
  if plan.film == "reel" then return B.REEL end
  if B.FILMS and B.FILMS[plan.film] then return B.FILMS[plan.film] end
  return Film.spec
end
-- installed, at some size?
function Loader.has(mode)
  local plan = MODES[mode]
  if not plan then return Loader.others[mode] ~= nil end
  local spec = specOf(plan)
  return spec ~= nil and not Assets.lite and Film.pick(Config.get("app.filmQuality"), spec) ~= nil
end
function Loader.spec(mode) return MODES[mode] end

local BONE, SOFT = Color3.fromRGB(245, 244, 239), Color3.fromRGB(158, 157, 166)

local function label(parent, text, font, size, color, props)
  local item = Instance.new("TextLabel")
  item.BackgroundTransparency = 1
  item.BorderSizePixel = 0
  item.FontFace = B.F[font]
  item.TextSize = size
  item.Text = text
  item.TextColor3 = color or BONE
  item.AutomaticSize = Enum.AutomaticSize.XY
  item.TextXAlignment = Enum.TextXAlignment.Left
  if props then
    for key, value in pairs(props) do item[key] = value end
  end
  item.Parent = parent
  return item
end
-- A line of type that rises out of a mask and leaves through the top of it.
-- side: "left" or "right" (which edge `position` anchors)
local function maskLine(parent, text, font, size, color, side, position)
  local right = side == "right"
  local clip = Instance.new("Frame")
  clip.BackgroundTransparency = 1
  clip.ClipsDescendants = true
  clip.AnchorPoint = Vector2.new(right and 1 or 0, 1)
  clip.Position = position
  clip.Size = UDim2.fromOffset(10, 10)
  clip.Parent = parent
  local item = label(clip, text, font, size, color)
  local function fit()
    local bounds, unit = item.AbsoluteSize, Loader.unit or 1
    clip.Size = UDim2.fromOffset(bounds.X / unit + 14, bounds.Y / unit + 6)
  end
  item:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
  fit()
  local api = { clip = clip, label = item }
  -- enter 0..1 rises in from below; leave 0..1 carries it out through the top
  function api.set(enter, leave)
    local height = clip.Size.Y.Offset
    item.Position = UDim2.fromOffset(4, height * (1 - enter) - height * (leave or 0))
    item.TextTransparency = math.clamp(1 - enter * 1.6 + (leave or 0), 0, 1)
  end
  api.set(0, 0)
  return api
end

-- A line of heavy wide capitals, spaced out, centred: slammed in (from a third bigger, in a tenth
-- of a second and a half), a bar of the accent wiping in under it, and gone up and out. Same shape
-- as maskLine's: { clip, label, set(enter, leave) }.
local HAIR = utf8.char(0x200A)
local function spaced(text)
  local out = {}
  for _, code in utf8.codes(string.upper(text)) do out[#out + 1] = utf8.char(code) end
  return table.concat(out, HAIR)
end
local function impactLine(parent, text, font, size, color, position)
  local clip = Instance.new("Frame")
  clip.BackgroundTransparency = 1
  clip.AnchorPoint = Vector2.new(0.5, 1)
  clip.Position = position
  clip.Size = UDim2.fromOffset(10, 10)
  clip.AutomaticSize = Enum.AutomaticSize.XY
  clip.Parent = parent
  local scale = Instance.new("UIScale")
  scale.Parent = clip
  local item = label(clip, spaced(text), font, size, color, { TextXAlignment = Enum.TextXAlignment.Center })
  local bar = Instance.new("Frame")
  bar.BorderSizePixel = 0
  bar.BackgroundColor3 = B.T.accent
  bar.AnchorPoint = Vector2.new(0.5, 0)
  bar.Position = UDim2.new(0.5, 0, 1, 6)
  bar.Size = UDim2.new(0, 0, 0, 3)
  bar.Parent = clip
  local api = { clip = clip, label = item, bar = bar }
  function api.set(enter, leave)
    leave = leave or 0
    local hit = math.clamp(enter * 1.8, 0, 1)
    scale.Scale = 1 + 0.32 * (1 - hit) ^ 3 + 0.04 * leave
    item.Position = UDim2.fromOffset(0, -22 * leave)
    item.TextTransparency = math.clamp(1 - hit + leave * 1.4, 0, 1)
    bar.Size = UDim2.new(math.clamp(enter, 0, 1) * (1 - leave), 0, 0, 3)
    bar.BackgroundTransparency = math.clamp(0.1 + leave, 0, 1)
  end
  api.set(0, 0)
  return api
end

-- the intros there are (src/09b: "signal"), and the one Shuffle picks from
Loader.others = {}
Loader.SHUFFLE = { "reel", "cinematic", "signal", "lock", "prates", "brand", "richard" }
function Loader.run(done, override)
  -- getgenv().HUSS_BASED_INTRO = "signal" | "cinematic" | "quick" | "shuffle" | "off" forces a mode for one launch (testing)
  local forced = B.genv.HUSS_BASED_INTRO
  override = override or ((MODES[forced] or Loader.others[forced] or forced == "off" or forced == "shuffle") and forced or nil)
  local mode = override or Config.get("app.intro")
  if mode == "shuffle" then
    -- (a different one from last time, when there is a choice)
    local pool = {}
    -- (only the films that are here: one that is not would only fall back to another)
    for _, name in ipairs(Loader.SHUFFLE) do
      if ((MODES[name] and Loader.has(name)) or Loader.others[name]) and name ~= Loader.lastShuffle then pool[#pool + 1] = name end
    end
    mode = pool[math.random(1, math.max(#pool, 1))] or "cinematic"
    Loader.lastShuffle = mode
  end
  if Loader.others[mode] then
    if Loader.active then return end
    Loader.active = true
    return Loader.others[mode](function()
      Loader.active = false
      done()
    end)
  end
  if mode == "off" or not MODES[mode] then
    done()
    return
  end
  if Loader.active then return end
  Loader.active = true
  -- (a film that is not installed: the other one, or the wordmark alone)
  if MODES[mode] and not Loader.has(mode) then
    local instead = "quick"
    for _, other in ipairs({ "reel", "cinematic" }) do
      if other ~= mode and Loader.has(other) then instead = other; break end
    end
    if mode ~= "quick" then mode = instead end
  end
  local plan = MODES[mode]
  local spec = specOf(plan)
  local DROP = plan.drop or DROP
  local bare = plan.bare == true
  -- (a film played whole ends on its own last frame)
  local exitAt = plan.exit or (spec and spec.duration and (spec.duration - 1 / (spec.fps or 60))) or 6
  local gui = B.screen(9500)
  gui:SetAttribute("OwnLetters", true)       -- (its words keep the film's letters whatever the hub's font)
  local view = B.viewport()
  local k = math.clamp(view.Y / 1080, 0.55, 2)
  Loader.unit = k

  local root = UI.frame(gui, { Name = "Intro", Size = UDim2.fromScale(1, 1) })
  -- a modal button: frees the cursor, and swallows clicks so nothing reaches the game
  local veil = UI.new("TextButton", { Name = "Veil", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Modal = true, Parent = root })
  Motion.to(veil, "BackgroundTransparency", 0, "smooth")
  local stage = UI.frame(root, { Name = "Stage", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
  local filmHost = UI.frame(stage, { Name = "FilmHost", Size = UDim2.fromScale(1, 1), ZIndex = 1 })

  -- ---- the player
  local setName = (not Assets.lite) and spec and Film.pick(Config.get("app.filmQuality"), spec) or nil
  local volume = Config.get("app.introVolume") / 100
  local player
  if setName then
    local exitFrame = math.min(spec.count - 1, math.floor(exitAt * spec.fps) + 12)
    player = Film.new(filmHost, { spec = spec, set = setName, slots = 10, audio = volume > 0, volume = 0, start = plan.start, to = exitFrame, warmTo = exitFrame, budget = 2 })
  end
  local cuts = spec and spec.cuts or {}

  -- ---- grade: vignette, grain, bars (a finished film keeps its own grade: none of these)
  local grain
  if not bare then
    UI.image(stage, "vignette", { Name = "Vignette", Size = UDim2.fromScale(1, 1), ImageTransparency = 0.25, ZIndex = 3 })
    grain = UI.image(stage, "grain", { Name = "Grain", Size = UDim2.new(1, 600, 1, 600), Position = UDim2.fromOffset(-300, -300), ScaleType = Enum.ScaleType.Tile,
      TileSize = UDim2.fromOffset(512, 512), ImageTransparency = 0.925, ZIndex = 4 })
  end
  local dim = UI.frame(stage, { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 5 })
  local barHeight = math.floor(view.Y * 0.085)
  local barTop = UI.frame(stage, { Name = "BarTop", Size = UDim2.new(1, 0, 0, barHeight), Position = UDim2.fromOffset(0, -barHeight), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0, ZIndex = 6 })
  local barBottom = UI.frame(stage, { Name = "BarBottom", Size = UDim2.new(1, 0, 0, barHeight), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0, ZIndex = 6 })

  -- ---- type, laid out in 1080p units and scaled to the screen
  local typeLayer = UI.frame(stage, { Name = "Type", Size = UDim2.fromScale(1 / k, 1 / k), ZIndex = 8 })
  local typeScale = Instance.new("UIScale"); typeScale.Scale = k; typeScale.Parent = typeLayer
  local W, H = view.X / k, view.Y / k
  -- (the author's edit has its own monitor strips down both sides: the type keeps inside them)
  local margin = plan.margin and math.floor(W * plan.margin) or 56
  local shadowed = { TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.72 }
  local function small(text, font, color, props)
    local item = label(typeLayer, text, font, 11, color, props)
    for key, value in pairs(shadowed) do item[key] = value end
    item.TextTransparency = 1
    return item
  end
  local topLeft = small("BASED HUB", "wideBold", BONE, { Position = UDim2.fromOffset(margin, 34) })
  local timecode = small("", "mono400", SOFT, { Position = UDim2.new(1, -margin, 0, 34), AnchorPoint = Vector2.new(1, 0) })
  local registry = B.Registry and B.Registry.status() or { engineered = false }
  local gameLine = registry.engineered and ("ENGINEERED FOR  ·  " .. string.upper(registry.name or "THIS GAME")) or "NO SCRIPT ENGINEERED FOR THIS GAME YET  ·  UNIVERSAL LOADED"
  local bottomLeft = small("V" .. B.VERSION .. "  ·  " .. (registry.engineered and "ENGINEERED" or "UNIVERSAL"), "mono400", SOFT, { Position = UDim2.new(0, margin, 1, -44) })
  local skip = small("SPACE TO SKIP", "mono400", SOFT, { Position = UDim2.new(1, -margin, 1, -44), AnchorPoint = Vector2.new(1, 0) })
  local progress = UI.frame(typeLayer, { Name = "Progress", Size = UDim2.new(0, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = BONE, BackgroundTransparency = 0.35 })

  local baseline = -(barHeight / k) - 30
  local greeting1, greeting2
  local impact = plan.type == "impact"
  if plan.greeting and impact then
    greeting1 = impactLine(typeLayer, "Good to see you", "wideBold", 22, SOFT, UDim2.new(0.5, 0, 1, baseline - 84))
    greeting2 = impactLine(typeLayer, B.LP.DisplayName, "wideBlack", 66, BONE, UDim2.new(0.5, 0, 1, baseline))
  elseif plan.greeting then
    greeting1 = maskLine(typeLayer, "Good to see you,", "serifItalic", 62, BONE, "left", UDim2.new(0, margin, 1, baseline - 70))
    greeting2 = maskLine(typeLayer, B.LP.DisplayName .. ".", "serifItalic", 62, BONE, "left", UDim2.new(0, margin, 1, baseline))
  end
  -- the per-cut lines alternate sides, so the eye is carried across the frame
  local lines = {}
  -- In a game that has a script of its own, the edit's two lines about Universal ("Universal",
  -- "everywhere else.") would be about somewhere else: they name the game instead, and the last
  -- line is the game's own if it has one.
  local words = {}
  for index, cue in ipairs(plan.lines or {}) do words[index] = cue[2] end
  local universal = table.find(words, "Universal")
  if registry.engineered and universal then
    words[universal], words[universal + 1] = registry.name or "This game", "is loaded."
    if words[universal + 2] then words[universal + 2] = registry.tagline or words[universal + 2] end
  end
  for index, cue in ipairs(plan.lines or {}) do
    local right = index % 2 == 0
    local line = impact and impactLine(typeLayer, words[index], "wideBlack", 64, BONE, UDim2.new(0.5, 0, 1, baseline))
      or maskLine(typeLayer, words[index], "serifItalic", 92, BONE, right and "right" or "left", UDim2.new(right and 1 or 0, right and -margin or margin, 1, baseline))
    line.clip.Visible = false
    line.label.TextStrokeColor3 = Color3.new(0, 0, 0)
    line.label.TextStrokeTransparency = 0.8
    lines[index] = { at = cue[1], untilTime = (plan.lines[index + 1] and plan.lines[index + 1][1]) or plan.linesEnd, line = line }
  end

  -- ---- wordmark: five glyph images that rise out of their own masks, then "hub"
  local mark = UI.frame(typeLayer, { Name = "Wordmark", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47) })
  local markScale = Instance.new("UIScale"); markScale.Parent = mark
  local wm = Assets.manifest.wordmark
  local letters = {}
  local hubImage
  local markWidth, capPx = 0, math.min(H * 0.16, W * 0.085)
  if wm and wm.glyphs and Assets.id(wm.glyphs[1].image) then
    local s = capPx / wm.cap
    local x = 0
    for index, glyph in ipairs(wm.glyphs) do
      local w, h = glyph.w * s, glyph.h * s
      local clip = UI.frame(mark, { Name = glyph.char, Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x - wm.pad * s, 0), ClipsDescendants = true })
      local image = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 1.05), Image = Assets.id(glyph.image) or "",
        ImageColor3 = BONE, Parent = clip })
      letters[index] = { image = image }
      x += glyph.advance * s * 0.972
    end
    local hub = wm.hub
    local hs = s * (wm.size / 560) * 0.98
    local hw, hh = hub.w * hs, hub.h * hs
    hubImage = UI.new("ImageLabel", { Name = "Hub", BackgroundTransparency = 1, Size = UDim2.fromOffset(hw, hh),
      Position = UDim2.fromOffset(x + 4 * s, (wm.pad + wm.cap) * s - hub.baseline * hs), Image = Assets.id(hub.image) or "", ImageColor3 = T.accent, ImageTransparency = 1, Parent = mark })
    markWidth = x + 4 * s + hw - hub.pad * hs * 2
    mark.Size = UDim2.fromOffset(markWidth, (wm.cap + wm.pad * 2) * s)
  else
    -- no art installed: set the wordmark in type
    local row = UI.frame(mark, { AutomaticSize = Enum.AutomaticSize.XY })
    UI.list(row, "x", 6, { v = "Bottom" })
    letters[1] = { text = label(row, "BASED", "wideBlack", 92, BONE, { LayoutOrder = 1, TextTransparency = 1 }) }
    hubImage = label(row, "hub", "serifItalic", 100, T.accent, { LayoutOrder = 2, TextTransparency = 1 })
    markWidth, capPx = 560, 70
    mark.Size = UDim2.fromOffset(markWidth, 110)
  end
  local glow = UI.image(typeLayer, "glow", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(markWidth * 1.7, capPx * 5.5),
    ImageColor3 = T.accent, ImageTransparency = 1, ZIndex = 0 })
  local below = UI.frame(typeLayer, { Name = "Below", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.47, capPx * 0.5 + 34), Size = UDim2.fromOffset(markWidth, 60) })
  local rule = UI.frame(below, { Name = "Rule", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 0, 0, 1), BackgroundColor3 = BONE, BackgroundTransparency = 0.45 })
  local statusLine = label(below, gameLine, "wideBold", 10.5, registry.engineered and BONE or SOFT, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16),
    TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.75 })
  local keyHint = string.upper(Config.keyLabel(Config.get("app.key.menu"))) .. "  ·  OPENS AND CLOSES THE HUB"
  local flash = UI.frame(root, { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 20 })

  -- ---- prelude: decode the opening frames, and say how far along that is
  local ring = UI.image(typeLayer, "ring", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), ImageTransparency = 1 })
  local sweep = UI.gradient(ring, { Transparency = UI.alphaSeq(0, 0, 0.5, 0.2, 1, 1), Rotation = 0 })
  local percent = label(typeLayer, "00", "mono400", 11, SOFT, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 30), TextTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center })
  local spinning = true
  local spin = Motion.every(function(dt)
    if spinning then sweep.Rotation = (sweep.Rotation + dt * 300) % 360 end
  end, nil, "loader.spin")
  -- only show the spinner if this takes long enough to be noticed
  local showSpinner = Motion.after(0.3, function()
    if spinning then ring.ImageTransparency = 0.2; percent.TextTransparency = 0.3 end
  end, "loader.spinner")
  local wordImages = {}
  for _, entry in ipairs(letters) do
    if entry.image then wordImages[#wordImages + 1] = entry.image end
  end
  task.spawn(function() pcall(function() S.ContentProvider:PreloadAsync(wordImages) end) end)
  if player then
    player:prepare(8, 5, function(p) percent.Text = string.format("%02d", math.floor(p * 99)) end)
    if player.missing then player:destroy(); player = nil end
  else
    task.wait(0.25)
  end
  if not player then
    -- no film installed: the wordmark alone, on the quick cut's timing, then the hub
    plan = MODES.quick
    DROP = plan.drop
    bare, exitAt = false, plan.exit
    for _, entry in ipairs(lines) do entry.line.clip:Destroy() end
    table.clear(lines)
    if greeting1 then greeting1.clip:Destroy(); greeting2.clip:Destroy(); greeting1, greeting2 = nil, nil end
  end
  spinning = false
  showSpinner.cancel(); spin.cancel()
  ring:Destroy(); percent:Destroy()
  if not B.alive then return end

  -- ---- run
  local clockStart = os.clock()
  local finished, exiting = false, false
  local punch = Motion.spring(1, "bouncy", function(x) markScale.Scale = x[1] end, 0.0005)
  punch:snap({ 1 })
  local shake = Motion.spring(2, { 0.5, 0.55 }, function(x) stage.Position = UDim2.fromOffset(x[1], x[2]) end, 0.05)
  local lastCut = plan.start
  local dropped = false
  local grainAt = 0
  local job, inputConnection
  local total = (spec and spec.duration or exitAt)

  local function cleanup()
    if job then job.cancel() end
    if inputConnection then inputConnection:Disconnect() end
    Loader.active = false
    Loader.unit = nil
  end
  local function exit(skipped)
    if exiting then return end
    exiting = true
    -- (a finished film leaves through black, not the loader's white)
    if bare then flash.BackgroundColor3 = Color3.new(0, 0, 0) end
    -- out on white: a flash covers the swap from film to hub
    Motion.tween(0.07, ease.linear, function(p) flash.BackgroundTransparency = 1 - p end, function()
      local track = player and player.sound
      if track then
        track.Parent = gui
        player.sound = nil
        local from = track.Volume
        Motion.tween(skipped and 0.9 or 1.6, ease.outSine, function(p) track.Volume = from * (1 - p) end, function() track:Destroy() end)
      end
      Loader.last = { mode = mode, set = setName, skipped = skipped, stats = player and player.stats or nil, seconds = os.clock() - clockStart }
      if player then player:destroy() end
      stage:Destroy()
      veil:Destroy()
      cleanup()
      B.try("loader.done", done)
      Motion.tween(0.6, ease.outCubic, function(p) flash.BackgroundTransparency = p end, function() gui:Destroy() end)
    end)
  end
  inputConnection = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Escape then
      if os.clock() - clockStart > 0.35 and not B.genv.HUSS_BASED_NOSKIP then exit(true) end
    end
  end)
  B.own(inputConnection)

  if player then
    player:setAlpha(0)
    player:play()
  end
  local wordOut, wordBack = plan.wordOut, plan.wordBack
  job = Motion.every(function()
    local since = os.clock() - clockStart
    local t = player and player.time or (plan.start + since)
    -- picture and sound come up together
    local fadeIn = win(since, 0, 0.55, ease.outCubic)
    if player then
      player:setAlpha(fadeIn)
      if not exiting then player:setVolume(volume * fadeIn) end
      player.zoom.Scale = bare and 1 or (t < DROP and util.lerp(1.07, 1.0, win(t, plan.start, (plan.calm or 2.9) - plan.start + 0.01, ease.outCubic)) or util.lerp(1.05, 1.0, win(t, DROP, 0.7, ease.outExpo)))
    end
    -- letterbox: in for the opening, thrown open by the drop
    local bars = bare and 0 or win(since, 0.05, 0.7, ease.outQuint) * (1 - win(t, DROP - 0.02, 0.32, ease.outExpo))
    barTop.Position = UDim2.fromOffset(0, -barHeight * (1 - bars))
    barBottom.Position = UDim2.new(0, 0, 1, -barHeight * bars)
    local chrome = win(since, 0.3, 0.6, ease.outCubic)
    topLeft.TextTransparency = 1 - chrome
    timecode.TextTransparency = 1 - chrome * 0.8
    bottomLeft.TextTransparency = 1 - chrome * 0.75
    skip.TextTransparency = 1 - chrome * 0.6
    timecode.Text = string.format("%05.2f  /  %05.2f", t, total)
    progress.Size = UDim2.new(util.clamp01((t - plan.start) / (exitAt - plan.start)), 0, 0, 1)
    if bare then
      -- a finished film: picture, sound and the chrome, to its last frame
      if not finished and (t >= exitAt or (player and player.ended)) then
        finished = true
        exit(false)
      end
      return
    end

    -- opening greeting
    if greeting1 then
      local inAt, outAt = plan.greet and plan.greet[1] or 0.7, plan.greet and plan.greet[2] or 2.3
      greeting1.set(win(t, inAt, 0.85, ease.outExpo), win(t, outAt, 0.45, ease.inCubic))
      greeting2.set(win(t, inAt + 0.2, 0.85, ease.outExpo), win(t, outAt + 0.08, 0.45, ease.inCubic))
    end
    -- one line per cut: in on the cut, out just before the next
    for _, entry in ipairs(lines) do
      local on = t >= entry.at - 0.02 and t < entry.untilTime + 0.05
      if entry.line.clip.Visible ~= on then entry.line.clip.Visible = on end
      if on then
        entry.line.set(win(t, entry.at, 0.36, ease.outExpo), win(t, entry.untilTime - 0.16, 0.16, ease.inCubic))
      end
    end

    -- wordmark: in during the blackout, out on the flash, back for the finale
    local inhale = t < DROP and win(t, DROP - 0.16, 0.14, ease.inCubic) or 0
    local leaving = wordOut and t >= wordOut and (not wordBack or t < wordBack)
    local returned = wordBack and t >= wordBack
    for index, entry in ipairs(letters) do
      local y, alpha
      if returned then
        local p = win(t, wordBack + (index - 1) * 0.06, 0.6, ease.outExpo)
        y, alpha = 1.05 * (1 - p), 1
      elseif leaving then
        local p = win(t, wordOut + (index - 1) * 0.035, 0.34, ease.inCubic)
        y, alpha = -1.05 * p, 1
      else
        local p = win(t, plan.word + (index - 1) * plan.stagger, plan.rise, ease.outExpo)
        y, alpha = 1.05 * (1 - p), p
      end
      if entry.image then
        entry.image.Position = UDim2.fromScale(0, y)
        entry.image.ImageTransparency = inhale * 0.7
      else
        entry.text.TextTransparency = 1 - alpha * (1 - inhale * 0.7) * ((leaving and 1 - win(t, wordOut, 0.3)) or 1)
      end
    end
    local hubP, ruleP, statusP
    if returned then
      hubP, ruleP, statusP = win(t, wordBack + 0.32, 0.6, ease.outExpo), win(t, wordBack + 0.5, 0.7, ease.outExpo), win(t, wordBack + 0.72, 0.6, ease.outCubic)
      if statusLine.Text ~= keyHint then statusLine.Text = keyHint; statusLine.TextColor3 = BONE end
    elseif leaving then
      local gone = 1 - win(t, wordOut, 0.3, ease.inCubic)
      hubP, ruleP, statusP = gone, gone, gone
    else
      hubP, ruleP, statusP = win(t, plan.hub, 0.8, ease.outExpo), win(t, plan.rule, 0.75, ease.outExpo), win(t, plan.status, 0.6, ease.outCubic)
    end
    if hubImage:IsA("ImageLabel") then hubImage.ImageTransparency = 1 - hubP * (1 - inhale * 0.7) else hubImage.TextTransparency = 1 - hubP * (1 - inhale * 0.7) end
    rule.Size = UDim2.new(ruleP, 0, 0, 1)
    statusLine.TextTransparency = 1 - statusP * (1 - inhale * 0.6)
    local glowBase = (leaving and 0) or (returned and win(t, wordBack, 0.8, ease.outCubic) * 0.2) or win(t, plan.word + 0.2, 1.4, ease.outCubic) * 0.2
    glow.ImageTransparency = 1 - (glowBase + (t >= DROP and not leaving and 0.16 * (1 - win(t, DROP, 1.2, ease.outCubic)) or 0))
    dim.BackgroundTransparency = 1 - inhale * 0.5

    if not dropped then
      -- anticipation: the mark leans in before the hit
      if t < DROP and t > DROP - 0.75 then punch:snap({ 1 + 0.03 * win(t, DROP - 0.75, 0.75, ease.inCubic) }) end
      if t >= DROP then
        dropped = true
        punch:snap({ 1.11 }); punch:to({ 1 }, "bouncy")
        shake:impulse(1, 900 * k); shake:impulse(2, -520 * k)
        flash.BackgroundTransparency = 0.12
        Motion.tween(0.5, ease.outCubic, function(p) if not exiting then flash.BackgroundTransparency = 0.12 + 0.88 * p end end)
        lastCut = DROP
      end
    else
      -- every later cut of the edit gives the frame a small kick
      for _, cut in ipairs(cuts) do
        if cut > lastCut + 0.05 and cut <= t and cut < exitAt - 0.05 then
          lastCut = cut
          punch:impulse(1, 0.9)
          shake:impulse(1, (math.random() - 0.5) * 420 * k); shake:impulse(2, (math.random() - 0.5) * 300 * k)
          if not exiting then
            flash.BackgroundTransparency = 0.88
            Motion.tween(0.28, ease.outCubic, function(p) if not exiting then flash.BackgroundTransparency = 0.88 + 0.12 * p end end)
          end
        end
      end
    end
    -- film grain drifts at film cadence, not at the display's
    if grain and since - grainAt > 1 / 24 then
      grainAt = since
      grain.Position = UDim2.fromOffset(-300 + math.random(-250, 250), -300 + math.random(-250, 250))
    end
    if not finished and (t >= exitAt or (player and player.ended)) then
      finished = true
      exit(false)
    end
  end, nil, "loader")
end
end
