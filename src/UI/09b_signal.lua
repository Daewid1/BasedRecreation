do -- 09b_signal.lua
-- ============================================================================
--  09b signal  the second intro: the live game in black and white, framed like
--              a broadcast monitor, cut to the track
--
--  The film intro (09 loader) plays an edit. This one plays nothing recorded:
--  for seven seconds the camera is taken and pointed at the player's own
--  avatar, wherever they stand, in whatever game, with the picture graded to
--  black and white. Shots of it (a close-up that pushes in, low from the
--  ground, backlit from behind, overhead and turning, a dutch tilt, the eyes)
--  cut faster and faster as the track builds; on the drop the wordmark is hit
--  onto the screen. Down both sides run two monitor strips, like the edit the
--  author sent as the look to beat: waveform traces, red level blocks and a
--  twisting ribbon, all driven by the loudness of the track as it plays.
--  Letterbox bars cover the game's own buttons and bars.
--
--  Cues are times in the hub's film track (film.json: the drop at 5.93, the
--  white flash at 9.22); it is played from 2.0. With no track installed the
--  same cues run on the clock, silent, the strips driven by a beat of their own.
-- ============================================================================
local S, util, Motion, Config, Assets = B.S, B.util, B.Motion, B.Config, B.Assets
local UIS, RunService = S.UserInputService, S.RunService
local ease, win = Motion.ease, Motion.window
local Intro = { active = false }
B.SignalIntro = Intro

local BONE = Color3.fromRGB(245, 244, 239)
local DIM = Color3.fromRGB(150, 150, 158)
local RED = Color3.fromRGB(236, 96, 98)
local VIOLET = Color3.fromRGB(132, 124, 255)
local CYAN = Color3.fromRGB(90, 230, 255)
local BLACK = Color3.new(0, 0, 0)

local START, DROP, LEAVE, OUT = 2.0, 5.9333, 8.3833, 9.2167
-- the cuts: faster and faster as the track builds, then the edit's own after the drop
local CUTS = { 2.0, 2.88, 3.62, 4.25, 4.75, 5.15, 5.45, 5.7, 5.9333, 6.8833, 7.6167, 8.3833 }
local ORDER = { "face", "low", "behind", "orbit", "dolly", "dutch", "crane", "eyes", "hero", "orbitWide", "low", "face" }
local LINES = { "SIGNAL ACQUIRED", "SUBJECT  //  %NAME%", "LOCATION  //  %GAME%", "THREAT LEVEL  //  MAXIMUM", "STATUS  //  ARMED",
  "ALL SYSTEMS  //  ONLINE", "LOCKING ON", "" }
Intro.CUTS, Intro.DROP, Intro.OUT, Intro.START = CUTS, DROP, OUT, START

local STRIP = 168            -- design px (the screen's height is 1080 of them) of each monitor strip
local BAR = 112              -- letterbox bars over the game's own top buttons and bottom bars
local TRACE_N, RIBBON_N, STRIPES = 30, 26, 13

-- ---------------------------------------------------------------- the shots
-- Each: from the avatar `s` (root, head, feet, forward, right, yaw) and how far through the shot it
-- is (0..1) -> where the camera is, what it looks at, and the field of view.
local SHOTS = {
  face = function(s, p) return s.head + s.forward * util.lerp(4.4, 2.7, p) + s.right * 0.45 - Vector3.yAxis * 0.35, s.head + Vector3.yAxis * 0.1, 38 end,
  low = function(s, p) return s.feet + s.forward * util.lerp(9.5, 7.2, p) + s.right * 1.6 + Vector3.yAxis * 0.5, s.head + Vector3.yAxis * 2.2, 64 end,
  behind = function(s, p) return s.root - s.forward * util.lerp(7.5, 5.6, p) - s.right * 1.3 - Vector3.yAxis * 1.1, s.head + s.forward * 7 + Vector3.yAxis * 3.2, 56 end,
  orbit = function(s, p)
    local a = s.yaw + p * 1.25
    return s.root + Vector3.new(math.cos(a) * 9, util.lerp(26, 19, p), math.sin(a) * 9), s.root, 50
  end,
  dolly = function(s, p) return s.root + s.right * 7.5 + s.forward * util.lerp(-3.2, 3.2, p) + Vector3.yAxis * 0.8, s.root + Vector3.yAxis * 0.9, 44 end,
  dutch = function(s, p) return s.head + s.forward * 5.2 - s.right * 2.3 + Vector3.yAxis * 0.6, s.head, 40, math.rad(util.lerp(-13, -19, p)) end,
  crane = function(s, p) return s.root + s.forward * 8 + s.right * -1 + Vector3.yAxis * util.lerp(-2, 6.5, p), s.root + Vector3.yAxis * util.lerp(0, 2.2, p), 50 end,
  eyes = function(s, p) return s.head + s.forward * util.lerp(2.5, 1.95, p) + Vector3.yAxis * 0.18, s.head + Vector3.yAxis * 0.18, 30 end,
  hero = function(s, p)
    local a = s.yaw + 0.55 + p * 0.55
    local out = util.lerp(9, 16, ease.outCubic(p))
    return s.root + Vector3.new(math.cos(a) * out, util.lerp(0.6, 4.2, p), math.sin(a) * out), s.root + Vector3.yAxis * 1.6, 72
  end,
  orbitWide = function(s, p)
    local a = s.yaw - 0.9 - p * 0.8
    return s.root + Vector3.new(math.cos(a) * 15, util.lerp(7, 10, p), math.sin(a) * 15), s.root + Vector3.yAxis * 1.2, 60
  end,
}

-- the avatar, or (no body yet) wherever the camera was looking
local function subject(camera, fallback)
  local character = B.LP.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local head = character and character:FindFirstChild("Head")
  if root and head then
    local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
    local right = look:Cross(Vector3.yAxis).Unit
    return { root = root.Position, head = head.Position, feet = root.Position - Vector3.yAxis * 3, forward = look, right = right,
      yaw = math.atan2(look.Z, look.X), body = character }
  end
  local at = fallback or (camera.Focus.Position)
  local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
  look = look.Magnitude > 1e-3 and -look.Unit or Vector3.new(0, 0, 1)
  return { root = at, head = at + Vector3.yAxis * 1.5, feet = at - Vector3.yAxis * 3, forward = look, right = look:Cross(Vector3.yAxis).Unit,
    yaw = math.atan2(look.Z, look.X) }
end

-- ---------------------------------------------------------------- pieces
local function frame(parent, props)
  local item = Instance.new("Frame")
  item.BorderSizePixel = 0
  item.BackgroundColor3 = BONE
  for key, value in pairs(props or {}) do item[key] = value end
  item.Parent = parent
  return item
end
local function label(parent, text, font, size, color, props)
  local item = Instance.new("TextLabel")
  item.BackgroundTransparency = 1
  item.BorderSizePixel = 0
  item.FontFace = B.F[font] or B.F.mono400
  item.TextSize = size
  item.Text = text
  item.TextColor3 = color or BONE
  item.AutomaticSize = Enum.AutomaticSize.XY
  item.TextXAlignment = Enum.TextXAlignment.Left
  for key, value in pairs(props or {}) do item[key] = value end
  item.Parent = parent
  return item
end
-- a straight piece of line from a to b (design px)
local function segment(item, a, b, thick)
  local d = b - a
  local length = d.Magnitude
  item.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
  item.Size = UDim2.fromOffset(length + 1, thick)
  item.Rotation = math.deg(math.atan2(d.Y, d.X))
end

-- One monitor strip: two waveform traces, three red level blocks, a twisting ribbon, ticks and
-- read-outs. `step(t, level, beat)` moves all of it.
local function strip(parent, right, height)
  local holder = frame(parent, { Name = right and "StripRight" or "StripLeft", BackgroundColor3 = BLACK, Size = UDim2.new(0, STRIP, 1, 0),
    AnchorPoint = Vector2.new(right and 1 or 0, 0), Position = UDim2.fromScale(right and 1 or 0, 0), ClipsDescendants = true, ZIndex = 10 })
  frame(holder, { Name = "Edge", Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(right and 0 or 1, 0), AnchorPoint = Vector2.new(right and 0 or 1, 0),
    BackgroundColor3 = Color3.fromRGB(52, 52, 60), ZIndex = 11 })
  local traces = {}
  for index = 1, 2 do
    local list = {}
    for i = 1, TRACE_N do
      list[i] = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = index == 1 and 0.02 or 0.5, ZIndex = 12 })
    end
    traces[index] = { segs = list, x = (index == 1) == right and STRIP * 0.72 or STRIP * 0.3, seed = math.random() * 1000, gain = index == 1 and 1 or 0.6 }
  end
  -- red level blocks: stacks of stripes, each stripe as wide as its band is loud
  local blocks = {}
  for index = 1, 3 do
    local top = height * (index == 1 and 0.12 or (index == 2 and 0.47 or 0.78))
    local list = {}
    for i = 1, STRIPES do
      list[i] = frame(holder, { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = RED, BackgroundTransparency = 0.12, ZIndex = 13,
        Position = UDim2.fromOffset(STRIP * (right and 0.4 or 0.6), top + (i - 1) * 6), Size = UDim2.fromOffset(4, 3) })
    end
    blocks[index] = { stripes = list, seed = math.random() * 1000, centre = STRIP * (right and 0.4 or 0.6) }
  end
  -- the ribbon: a twist seen from the side, each rung as wide as the twist is turned toward us
  local ribbon = {}
  for i = 1, RIBBON_N do
    ribbon[i] = frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.18, ZIndex = 12, Size = UDim2.fromOffset(4, 2) })
  end
  local ribbonX = STRIP * (right and 0.22 or 0.8)
  -- ticks across it, and its read-outs
  local ticks = {}
  for i = 1, 6 do
    ticks[i] = frame(holder, { BackgroundColor3 = VIOLET, BackgroundTransparency = 0.25, ZIndex = 14, Size = UDim2.fromOffset(STRIP * 0.5, 1),
      AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(STRIP / 2, height * math.random()) })
  end
  local reads = {}
  for i = 1, 4 do
    reads[i] = label(holder, "", "mono400", 10, DIM, { ZIndex = 15, Position = UDim2.fromOffset(right and 10 or 12, i <= 2 and (14 + (i - 1) * 14) or (height - 44 + (i - 3) * 14)),
      TextTransparency = 0.15 })
  end
  local api = { holder = holder }
  function api.step(t, level, beat, readout)
    -- traces: noise along the strip, its reach the loudness, a kick on each beat
    for _, trace in ipairs(traces) do
      local prev
      local reach = (8 + 46 * level + 30 * beat) * trace.gain
      for i = 1, TRACE_N + 1 do
        local y = (i - 1) / TRACE_N * height
        local n = math.noise(trace.seed + i * 0.37, t * 7.5) + 0.45 * math.noise(trace.seed * 0.5 + i * 1.9, t * 17)
        local point = Vector2.new(trace.x + n * reach, y)
        if prev then segment(trace.segs[i - 1], prev, point, trace.gain == 1 and 2 or 1) end
        prev = point
      end
    end
    -- blocks: each stripe a band, wider with the level, flaring on the beat
    for _, block in ipairs(blocks) do
      for i, stripe in ipairs(block.stripes) do
        local band = 0.5 + 0.5 * math.noise(block.seed + i * 0.61, t * 9)
        local width = math.clamp((0.1 + 0.9 * level * band + 0.35 * beat) * STRIP * 0.78, 3, STRIP * 0.86)
        stripe.Size = UDim2.fromOffset(width, 3)
        stripe.BackgroundTransparency = 0.05 + 0.5 * (1 - band) * (1 - beat)
      end
    end
    -- the ribbon turns at the tempo of the track
    for i, rung in ipairs(ribbon) do
      local y = (i - 0.5) / RIBBON_N * height
      local turn = math.sin(i * 0.55 + t * (3.2 + 4 * level))
      rung.Position = UDim2.fromOffset(ribbonX, y)
      rung.Size = UDim2.fromOffset(math.max(math.abs(turn) * (22 + 26 * level), 2), turn > 0 and 2 or 1)
      rung.BackgroundTransparency = turn > 0 and 0.08 or 0.55
    end
    -- ticks hop about now and then
    for _, tick in ipairs(ticks) do
      if math.random() < 0.06 + 0.3 * beat then tick.Position = UDim2.fromOffset(STRIP / 2 + (math.random() - 0.5) * 30, height * math.random()) end
      tick.BackgroundTransparency = 0.2 + 0.6 * math.random() * (1 - beat)
    end
    for i, item in ipairs(reads) do item.Text = readout[i] or "" end
  end
  return api
end

-- ---------------------------------------------------------------- the run
function Intro.run(done)
  if Intro.active then return end
  Intro.active = true
  local camera = workspace.CurrentCamera
  local view = B.viewport()
  local k = math.clamp(view.Y / 1080, 0.5, 2.5)
  local W, H = view.X / k, view.Y / k
  local gui = B.screen(9500)
  gui:SetAttribute("OwnLetters", true)       -- (its words keep the film's letters whatever the hub's font)
  local root = frame(gui, { Name = "Signal", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
  -- (a modal button frees the cursor and keeps clicks from the game)
  local veil = Instance.new("TextButton")
  veil.Text, veil.AutoButtonColor, veil.Modal, veil.BorderSizePixel = "", false, true, 0
  veil.Size, veil.BackgroundColor3, veil.BackgroundTransparency = UDim2.fromScale(1, 1), BLACK, 0
  veil.Parent = root
  local layer = frame(root, { Name = "Layer", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), ZIndex = 2 })
  local scale = Instance.new("UIScale"); scale.Scale = k; scale.Parent = layer

  -- ---- the grade: black and white, hard, a little bloom on the highlights
  local grade = Instance.new("ColorCorrectionEffect")
  grade.Name = util.randomName()
  grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = -1, 0.72, -0.07, Color3.fromRGB(238, 240, 248)
  grade.Enabled = false
  grade.Parent = S.Lighting
  local bloom = Instance.new("BloomEffect")
  bloom.Name = util.randomName()
  bloom.Intensity, bloom.Size, bloom.Threshold, bloom.Enabled = 0.55, 30, 0.86, false
  bloom.Parent = S.Lighting
  local blur = Instance.new("BlurEffect")
  blur.Name = util.randomName()
  blur.Size, blur.Enabled = 0, true
  blur.Parent = S.Lighting

  -- ---- the frame: strips, bars, grain
  local height = H
  local left, right = strip(layer, false, height), strip(layer, true, height)
  local barTop = frame(layer, { Name = "BarTop", BackgroundColor3 = BLACK, Size = UDim2.new(1, 0, 0, BAR), ZIndex = 8 })
  local barBottom = frame(layer, { Name = "BarBottom", BackgroundColor3 = BLACK, Size = UDim2.new(1, 0, 0, BAR), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 8 })
  local grain = Instance.new("ImageLabel")
  grain.BackgroundTransparency, grain.Image, grain.ScaleType, grain.TileSize = 1, Assets.image("grain") or "", Enum.ScaleType.Tile, UDim2.fromOffset(384, 384)
  grain.Size, grain.Position, grain.ImageTransparency, grain.ZIndex = UDim2.new(1, 600, 1, 600), UDim2.fromOffset(-300, -300), 0.86, 30
  grain.Parent = layer
  local vignette = Instance.new("ImageLabel")
  vignette.BackgroundTransparency, vignette.Image, vignette.Size, vignette.ImageTransparency, vignette.ZIndex = 1, Assets.image("vignette") or "", UDim2.fromScale(1, 1), 0.2, 7
  vignette.Parent = layer
  local flash = frame(root, { Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

  -- ---- type
  local inner = STRIP + 34
  local registry = B.Registry and B.Registry.status() or {}
  local gameName = string.upper(registry.name or "this game")
  local name = string.upper(B.LP.DisplayName)
  local head = label(layer, "BASED  //  SIGNAL", "wideBold", 13, BONE, { Position = UDim2.fromOffset(inner, BAR / 2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 20, TextTransparency = 1 })
  local rec = label(layer, "", "mono500", 12, BONE, { Position = UDim2.new(1, -inner, 0, BAR / 2), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 20, TextTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Right })
  local dot = frame(layer, { BackgroundColor3 = RED, Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -inner - 168, 0, BAR / 2), ZIndex = 20,
    BackgroundTransparency = 1 })
  local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = dot
  local channel = label(layer, "CH 01  //  " .. gameName, "mono400", 12, DIM, { Position = UDim2.new(0, inner, 1, -BAR / 2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 20, TextTransparency = 1 })
  local skip = label(layer, "SPACE TO SKIP", "mono400", 12, DIM, { Position = UDim2.new(1, -inner, 1, -BAR / 2), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 20, TextTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Right })
  local line = label(layer, "", "mono500", 17, BONE, { Position = UDim2.new(0, inner, 1, -BAR - 26), AnchorPoint = Vector2.new(0, 1), ZIndex = 20, TextStrokeTransparency = 0.55 })
  local lineBar = frame(layer, { BackgroundColor3 = RED, Size = UDim2.fromOffset(0, 3), Position = UDim2.new(0, inner, 1, -BAR - 18), ZIndex = 20 })
  -- the name, huge, letter by letter while the track builds
  local big = label(layer, "", "wideBlack", math.clamp(1200 / math.max(#name, 4), 70, 150), BONE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    ZIndex = 21, TextStrokeTransparency = 0.5, TextTransparency = 0.05, TextXAlignment = Enum.TextXAlignment.Center })
  local bigScale = Instance.new("UIScale"); bigScale.Parent = big
  -- the wordmark, and its two coloured ghosts for the hit
  local wm = Assets.manifest.wordmark
  local function wordmark(color, z)
    local holder = frame(layer, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), ZIndex = z })
    local capPx = math.min(H * 0.17, W * 0.09)
    local width = 0
    if wm and wm.glyphs and Assets.id(wm.glyphs[1].image) then
      local s = capPx / wm.cap
      local x = 0
      for _, glyph in ipairs(wm.glyphs) do
        local image = Instance.new("ImageLabel")
        image.BackgroundTransparency, image.Image, image.ImageColor3, image.ZIndex = 1, Assets.id(glyph.image) or "", color, z
        image.Size, image.Position = UDim2.fromOffset(glyph.w * s, glyph.h * s), UDim2.fromOffset(x - wm.pad * s, 0)
        image.Parent = holder
        x += glyph.advance * s * 0.972
      end
      width = x
      holder.Size = UDim2.fromOffset(width, (wm.cap + wm.pad * 2) * s)
    else
      local text = label(holder, "BASED", "wideBlack", 150, color, { ZIndex = z, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
      local _ = text
      holder.Size = UDim2.fromOffset(620, 170)
    end
    local sizer = Instance.new("UIScale"); sizer.Parent = holder
    holder.Visible = false
    return holder, sizer
  end
  local ghostR, ghostRScale = wordmark(RED, 22)
  local ghostC, ghostCScale = wordmark(CYAN, 22)
  local mark, markScale = wordmark(BONE, 23)
  local tag = label(layer, "ENGINEERED FOR  //  " .. gameName, "wideBold", 15, BONE, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, math.min(H * 0.17, W * 0.09) * 0.75 + 18),
    ZIndex = 23, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center })
  local rule = frame(layer, { BackgroundColor3 = RED, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, math.min(H * 0.17, W * 0.09) * 0.75 + 48), Size = UDim2.fromOffset(0, 3), ZIndex = 23 })
  local keyName = Config.keyLabel(Config.get("app.key.menu"))
  local hint = label(layer, string.upper(keyName) .. "  //  OPENS THE HUB", "mono500", 14, BONE, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, math.min(H * 0.17, W * 0.09) * 0.75 + 66),
    ZIndex = 23, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center })

  -- ---- the track
  local volume = (Config.get("app.introVolume") or 50) / 100
  local film = B.Film and B.Film.spec
  local trackId = film and film.audio and not Assets.lite and Assets.id(film.audio) or nil
  local sound
  if trackId and volume > 0 then
    sound = Instance.new("Sound")
    sound.SoundId, sound.Volume, sound.Looped = trackId, volume, false
    sound.Parent = gui
    local waited = 0
    while not sound.IsLoaded and waited < 1.5 do waited += task.wait() end
    if not sound.IsLoaded then sound:Destroy(); sound = nil end
  end

  -- ---- the camera
  local saved = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Exclude
  params.IgnoreWater = true
  local focusAt = camera.Focus.Position
  local shake = Motion.spring(3, { 0.42, 0.5 }, function() end, 0.02)
  local shot = { index = 0, turn = 0 }
  -- A shot is taken from the side of the avatar that is open: the one asked for, or that one
  -- turned a quarter, a half or three quarters round, whichever has the most room at both ends.
  local function room(from, look)
    local hit = workspace:Raycast(look, from - look, params)
    return hit and hit.Distance / math.max((from - look).Magnitude, 1e-3) or 1
  end
  local function turned(from, look, turn)
    if turn == 0 then return from end
    local offset = from - look
    return look + CFrame.Angles(0, turn, 0):VectorToWorldSpace(offset)
  end
  local function cutTo(index)
    shot.index = index
    local s = subject(camera, focusAt)
    if s.body then params.FilterDescendantsInstances = { s.body } end
    local kind = ORDER[(index - 1) % #ORDER + 1]
    local best, bestRoom = 0, -1
    for _, turn in ipairs({ 0, math.pi / 2, -math.pi / 2, math.pi }) do
      local a1, l1 = SHOTS[kind](s, 0)
      local a2, l2 = SHOTS[kind](s, 1)
      local open = math.min(room(turned(a1, l1, turn), l1), room(turned(a2, l2, turn), l2))
      if open > bestRoom + 0.05 then best, bestRoom = turn, open end
      if open >= 0.999 then break end
    end
    shot.turn = best
  end
  local clock = START
  local function aim()
    local s = subject(camera, focusAt)
    local index = math.max(shot.index, 1)
    local kind = ORDER[(index - 1) % #ORDER + 1]
    local a, b = CUTS[index], CUTS[index + 1] or OUT
    local p = util.clamp01((clock - a) / math.max(b - a, 0.05))
    local from, look, fov, roll = SHOTS[kind](s, p)
    from = turned(from, look, shot.turn)
    -- (still never inside a wall: the camera is brought in front of anything left in the way)
    if s.body then params.FilterDescendantsInstances = { s.body } end
    local origin = look
    local hit = workspace:Raycast(origin, from - origin, params)
    if hit then from = hit.Position + (origin - hit.Position).Unit * 0.6 end
    local x = shake.x
    local cframe = CFrame.lookAt(from, look) * CFrame.Angles(x[2] * 0.004, x[1] * 0.004, (roll or 0) + x[3] * 0.003)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = cframe
    camera.FieldOfView = fov
  end
  RunService:BindToRenderStep("BasedSignalCamera", Enum.RenderPriority.Camera.Value + 10, function()
    if Intro.active then pcall(aim) end
  end)

  -- ---- leaving
  local finished = false
  local inputConnection, job
  local function restore()
    pcall(function() RunService:UnbindFromRenderStep("BasedSignalCamera") end)
    pcall(function()
      camera.CameraType = saved.type
      camera.CameraSubject = saved.subject
      camera.FieldOfView = saved.fov
    end)
    for _, effect in ipairs({ grade, bloom, blur }) do pcall(function() effect:Destroy() end) end
  end
  local function finish(skipped)
    if finished then return end
    finished = true
    flash.BackgroundTransparency = 0
    if job then job.cancel() end
    if inputConnection then inputConnection:Disconnect() end
    restore()
    Intro.active = false
    Intro.last = { skipped = skipped, sound = sound ~= nil, seconds = clock - START }
    if sound then
      local from = sound.Volume
      Motion.tween(skipped and 0.8 or 1.4, ease.outSine, function(p) if sound.Parent then sound.Volume = from * (1 - p) end end, function() pcall(function() sound:Destroy() end) end)
    end
    layer:Destroy()
    veil:Destroy()
    B.try("signal.done", done)
    Motion.tween(0.55, ease.outCubic, function(p) flash.BackgroundTransparency = p end, function()
      if sound and sound.Parent then sound.Parent = nil end
      gui:Destroy()
    end)
  end
  B.onUnload:connect(function() if Intro.active then restore(); Intro.active = false end end)
  inputConnection = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Escape then
      if clock - START > 0.35 and not B.genv.HUSS_BASED_NOSKIP then finish(true) end
    end
  end)

  -- ---- run
  grade.Enabled, bloom.Enabled = true, true
  local started = os.clock()
  if sound then
    sound.TimePosition = START
    sound:Play()
  end
  local level, lastCut, beat, grainAt, typedFor = 0, 0, 0, 0, 0
  local dropped = false
  local frames = 0
  job = Motion.every(function(dt)
    if finished then return end
    if not B.alive then finish(true); return end
    frames += 1
    clock = START + (os.clock() - started)
    -- (tests: getgenv().HUSS_BASED_SIGNAL_FREEZE = a film time holds the picture there)
    local freeze = B.genv.HUSS_BASED_SIGNAL_FREEZE
    if type(freeze) == "number" and clock >= freeze then
      started += clock - freeze
      clock = freeze
    end
    -- the level: the track's own loudness when it plays, a beat of its own when it does not
    local loud
    if sound and sound.IsPlaying then loud = util.clamp01(sound.PlaybackLoudness / 520)
    else loud = 0.35 + 0.35 * math.abs(math.sin(clock * math.pi * 2.9)) end
    level += (loud - level) * (loud > level and 0.55 or 0.12)
    beat = math.max(beat - dt * 3.2, 0)
    -- cuts
    for index = lastCut + 1, #CUTS do
      if clock >= CUTS[index] then
        lastCut = index
        cutTo(index)
        beat = 1
        shake:impulse(1, (math.random() - 0.5) * 260); shake:impulse(2, (math.random() - 0.5) * 200); shake:impulse(3, (math.random() - 0.5) * 140)
        -- a frame of white or black on the cut, like the edit's
        if index > 1 and index ~= 9 then
          flash.BackgroundColor3 = (index % 2 == 0) and Color3.new(1, 1, 1) or BLACK
          flash.BackgroundTransparency = (index % 2 == 0) and 0.55 or 0.25
          task.delay(1 / 30, function() if not finished then flash.BackgroundTransparency = 1 end end)
        end
        blur.Size = index < 9 and 10 or 16
        typedFor = clock
      else
        break
      end
    end
    blur.Size = math.max(blur.Size - dt * 90, 0)
    -- the drop: white, the hit, the wordmark
    if not dropped and clock >= DROP then
      dropped = true
      flash.BackgroundColor3, flash.BackgroundTransparency = Color3.new(1, 1, 1), 0
      Motion.tween(0.5, ease.outCubic, function(p) if not finished then flash.BackgroundTransparency = p end end)
      shake:impulse(1, 900); shake:impulse(2, -700); shake:impulse(3, 500)
      for _, holder in ipairs({ mark, ghostR, ghostC }) do holder.Visible = true end
    end
    -- chrome
    local chrome = win(clock, START + 0.1, 0.4, ease.outCubic)
    head.TextTransparency, channel.TextTransparency, skip.TextTransparency = 1 - chrome, 1 - chrome * 0.85, 1 - chrome * 0.7
    rec.TextTransparency = 1 - chrome
    local seconds = clock - START
    rec.Text = string.format("REC  %02d:%02d:%02d", math.floor(seconds / 60), math.floor(seconds % 60), math.floor((seconds % 1) * 30))
    dot.BackgroundTransparency = (math.floor(clock * 2.5) % 2 == 0) and 0.05 or 0.8
    veil.BackgroundTransparency = win(clock, START, 0.25, ease.outCubic)
    -- the line of the shot, typed out
    local text = LINES[lastCut] or ""
    text = string.gsub(text, "%%NAME%%", name)
    text = string.gsub(text, "%%GAME%%", gameName)
    local typed = math.floor((clock - typedFor) * 46)
    line.Text = string.sub(text, 1, math.max(typed, 0)) .. ((typed < #text and math.floor(clock * 12) % 2 == 0) and "_" or "")
    line.Visible = not dropped
    lineBar.Size = UDim2.fromOffset(dropped and 0 or math.min(typed, #text) * 10.2, 3)
    -- the name, letter by letter while the track builds, gone on the drop
    if clock >= 4.25 and not dropped then
      local count = math.clamp(math.floor((clock - 4.25) / 1.45 * #name) + 1, 1, #name)
      big.Text = string.sub(name, 1, count)
      bigScale.Scale = 1 + 0.06 * win(clock, 4.25, 1.68) + 0.03 * beat
      big.Position = UDim2.new(0.5, (math.random() - 0.5) * 6 * beat, 0.5, (math.random() - 0.5) * 6 * beat)
      big.TextTransparency = 0.05 + 0.4 * (1 - win(clock, 4.25, 0.3))
    else
      big.Text = ""
    end
    -- the wordmark: hit, held, broken up on the way out
    if dropped then
      local hit = win(clock, DROP, 0.55, ease.outExpo)
      markScale.Scale = util.lerp(1.28, 1, hit) * (1 + 0.025 * beat)
      local split = (1 - win(clock, DROP, 0.45, ease.outCubic)) * 16 + 5 * beat
      local leaving = win(clock, LEAVE + 0.15, 0.55, ease.inCubic)
      local jitter = leaving > 0 and (math.random() - 0.5) * 40 * leaving or 0
      mark.Position = UDim2.new(0.5, jitter, 0.46, 0)
      ghostR.Position = UDim2.new(0.5, -split + jitter * 1.6, 0.46, 0)
      ghostC.Position = UDim2.new(0.5, split - jitter * 1.3, 0.46, 0)
      ghostRScale.Scale, ghostCScale.Scale = markScale.Scale, markScale.Scale
      for _, holder in ipairs({ mark, ghostR, ghostC }) do
        local fade = holder == mark and leaving or math.max(leaving, 1 - (split / 21) * 1.3)
        for _, image in ipairs(holder:GetChildren()) do
          if image:IsA("ImageLabel") then image.ImageTransparency = fade + (holder == mark and 0 or 0.35) end
          if image:IsA("TextLabel") then image.TextTransparency = fade + (holder == mark and 0 or 0.35) end
        end
      end
      local under = win(clock, DROP + 0.25, 0.6, ease.outCubic) * (1 - leaving)
      tag.TextTransparency = 1 - under
      rule.Size = UDim2.fromOffset(util.lerp(0, 420, win(clock, DROP + 0.2, 0.7, ease.outExpo)) * (1 - leaving), 3)
      hint.TextTransparency = 1 - win(clock, LEAVE - 0.6, 0.4, ease.outCubic) * (1 - win(clock, OUT - 0.25, 0.25))
    end
    -- the strips
    local readout = {
      string.format("CH.%02d  %s", math.max(lastCut, 1), (math.floor(clock * 2) % 2 == 0) and "REC" or ""),
      string.format("LV %03d", math.floor(level * 999)),
      string.format("T %06.2f", clock),
      string.format("FPS %03d", math.floor(frames / math.max(os.clock() - started, 0.05))),
    }
    left.step(clock, level, beat, readout)
    right.step(clock + 3.7, level, beat, { string.format("SIG %s", string.rep("|", math.floor(level * 8))), string.format("%+05.1f dB", (level - 1) * 24),
      string.format("CUT %02d/%02d", lastCut, #CUTS), "BASED" })
    -- grain at film cadence
    if clock - grainAt > 1 / 24 then
      grainAt = clock
      grain.Position = UDim2.fromOffset(-300 + math.random(-240, 240), -300 + math.random(-240, 240))
      grain.ImageTransparency = 0.84 + 0.05 * math.random()
    end
    barTop.Size, barBottom.Size = UDim2.new(1, 0, 0, BAR), UDim2.new(1, 0, 0, BAR)
    if clock >= OUT then finish(false) end
  end, nil, "signal")
end
if B.Loader then B.Loader.others.signal = Intro.run end
end
