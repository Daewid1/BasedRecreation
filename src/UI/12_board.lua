do -- 12_board.lua
-- ============================================================================
--  12 board    the film on the Home tab: an ad board that opens when hovered
--
--  Docked, it is part of the Home card: the film runs silently and fades into
--  the card on its left. Rest the mouse on it and it comes forward over the hub,
--  opens to the whole picture and the sound comes in; move off it and it goes
--  back. Click it while it is open and it stays open until it is clicked again.
--
--  Two players share one clock, so they are always on the same frame. Measured
--  on the test machine with the Home tab up (126 fps with no board): the small
--  set played in the card costs nothing that can be measured (128, 129), the
--  1820x1024 set costs up to a tenth (114 to 126). So the card plays the small
--  set, which it shows at less than its own size anyway, and the big one runs
--  only once the mouse is on it. The hand-over happens with both on the same
--  picture in the same place, and the sound joins where the picture already is.
--
--  The film keeps its own rate (24000/1001 frames a second: every frame the
--  file has). Nothing is decoded while it cannot be seen: hub hidden, another
--  tab, the card scrolled away, or switched off in Settings.
-- ============================================================================
local S, util, Motion, T, UI, Config, Window, Assets, Film = B.S, B.util, B.Motion, B.T, B.UI, B.Config, B.Window, B.Assets, B.Film
local UIS = S.UserInputService
local Board = { spec = B.BOARD, p = 0, popped = false, opens = 0 }
B.Board = Board

local DWELL = 0.28        -- seconds the mouse rests on it before it opens: passing over it does nothing
local LINGER = 0.14       -- and how long it may be off it before it goes back
local RADIUS = 18         -- corner radius opened out, in screen pixels
local MARGIN = 28         -- kept clear of the screen edge
local FOCUS = 0.3         -- docked, the card shows a strip of the picture: this far down it
-- docked: clear on the left where the card's words are, the picture itself on the right
local RAMP = { { 0, 1 }, { 0.5, 0.42 }, { 1, 0.04 } }
local DOCK_ALPHA = 0.9
local UNSEEN = 0.001      -- drawn, so it is decoded, and not to be seen

local O
local holder, panel, screen, scrim, rim, shade, bar, fill, chip, still
local dock, big           -- the player in the card, and the one that comes forward
local spring
local origin = os.clock()
local function clock() return os.clock() - origin end
local wantPop, pinned, armed, overSince, offSince = false, false, false, nil, nil
local bigOnShow = false   -- which of the two players is the one being looked at
local handing = false     -- opening, and the big player has no picture yet: the card's keeps its own until it has
local dockShown = 0       -- how visible the card's player is right now

local function enabled() return Board.spec ~= nil and not Assets.lite and O ~= nil and O.on end
-- The BASED window's own Home tab, open: the board is a card on that page alone. (Asked of any look,
-- Novoline's Home deck counted: the BASED window sat hidden with its layout in place, and hovering
-- where the card would have been opened the film over the deck. Seen by the user 2026-10-22.)
local function onHome()
  return Window.open == true and Window.current ~= nil and Window.current.id == "home" and Window.look() == "based"
end
-- docked, the board is on screen only where the page shows through its scroll area
local function inView()
  if not holder or not holder.Parent or not Window.pageHost then return false end
  local top, bottom = holder.AbsolutePosition.Y, holder.AbsolutePosition.Y + holder.AbsoluteSize.Y
  local hostTop = Window.pageHost.AbsolutePosition.Y
  return bottom > hostTop + 12 and top < hostTop + Window.pageHost.AbsoluteSize.Y - 12
end

local function dockRect()
  local at, size = holder.AbsolutePosition - UI.overlay.AbsolutePosition, holder.AbsoluteSize
  return at.X, at.Y, size.X, size.Y
end
local function popRect()
  local view = B.viewport()
  local width = math.min(view.X * O.size / 100, (view.Y - MARGIN * 2) * 16 / 9, view.X - MARGIN * 2)
  local height = width * 9 / 16
  -- over the middle of the hub, and never off the screen
  local centre = Window.holder.AbsolutePosition + Window.holder.AbsoluteSize / 2 - UI.overlay.AbsolutePosition
  local x = math.clamp(centre.X - width / 2, MARGIN, math.max(MARGIN, view.X - width - MARGIN))
  local y = math.clamp(centre.Y - height / 2, MARGIN, math.max(MARGIN, view.Y - height - MARGIN))
  return x, y, width, height
end
local function dockLook()
  return { tl = 0, bl = 0, tr = T.rCard, br = T.rCard, fade = RAMP, focusX = 0.5, focusY = FOCUS }
end

-- Everything that depends on how far open it is: 0 docked, 1 open (a spring, so it may pass 1).
-- It only ever moves the big player: the one in the card stays where it is.
local function apply(p)
  Board.p = p
  if not big or big.dead or not holder.Parent then return end
  local q = util.clamp01(p)
  Board.popped = q > 0.5
  local dx, dy, dw, dh = dockRect()
  local px, py, pw, ph = popRect()
  panel.Position = UDim2.fromOffset(util.lerp(dx, px, p), util.lerp(dy, py, p))
  panel.Size = UDim2.fromOffset(math.max(8, util.lerp(dw, pw, p)), math.max(8, util.lerp(dh, ph, p)))
  -- out here nothing is scaled with the hub: the card's radius is carried over in screen pixels
  local card = T.rCard * UI.unit()
  local left, right = util.lerp(0, RADIUS, q), util.lerp(card, RADIUS, q)
  local fade = false
  if q < 0.995 then
    local keep = (1 - q) ^ 1.6
    fade = { { RAMP[1][1], RAMP[1][2] * keep }, { RAMP[2][1], RAMP[2][2] * keep }, { RAMP[3][1], RAMP[3][2] * keep } }
  end
  big:setLook({ tl = left, bl = left, tr = right, br = right, fade = fade, focusY = util.lerp(FOCUS, 0.5, q) })
  if wantPop or p > 0.002 then big:setAlpha(util.lerp(DOCK_ALPHA, 1, q)) end
  big:setVolume(O.volume / 100 * q * q)
  scrim.BackgroundTransparency = 1 - 0.46 * q
  scrim.Visible = q > 0.01
  rim.Corner.CornerRadius = UDim.new(0, math.floor(right + 0.5))
  rim.Stroke.Transparency = 1 - (pinned and 0.5 or 0.2) * q
  if shade then shade.Transparency = 1 - 0.6 * q end
  bar.Visible = q > 0.6
end

-- the big player, made the first time the mouse comes near
local function makeBig()
  if big and not big.dead then return true end
  local set = Film.pick(O.quality, Board.spec)
  if not set then return false end
  big = Film.new(screen, { spec = Board.spec, set = set, loop = true, audio = true, muted = true, volume = 0, window = true, backdrop = false,
    slots = 6, budget = 2, soundHost = UI.soundHost, clock = clock })
  Board.big = big
  return big ~= nil
end
-- The mouse is on the board: start the big player where the small one is, out of sight, so
-- that by the time the board opens it has a picture to open with.
local function arm()
  if armed or not makeBig() then return end
  armed = true
  panel.Visible = true
  apply(0)
  big:setAlpha(UNSEEN)
  big:play()
end
local function disarm()
  if not armed then return end
  armed = false
  if big and not big.dead then
    big:setMuted(true)
    big:pause()
  end
  panel.Visible, scrim.Visible = false, false
end
local function open(on)
  if not on then pinned = false end
  if wantPop == on then return end
  if on then
    arm()
    if not armed then return end
    wantPop = true
    Board.opens += 1
    big:setMuted(false)
    if chip then chip.Visible = false end
    -- the hand-over, in one go: the big player shows the picture from this frame on, exactly
    -- where the card's player was showing it, and that one stops
    bigOnShow = true
    apply(Board.p)
    handing = true
    spring:to({ 1 }, { 0.5, 0.16 })
  else
    wantPop, handing = false, false
    -- the card's player starts again now, unseen, to be on the right frame when this lands
    if dock and not dock.dead and not dock.playing then dock:play() end
    spring:to({ 0 }, "smooth")
  end
end
-- shut at once, with nothing left over the hub: for when the tab or the hub goes away under it
local function shut()
  wantPop, pinned, overSince, offSince = false, false, nil, nil
  if spring then spring:snap({ 0 }) end
  bigOnShow, handing = false, false
  disarm()
end
Board.open, Board.shut = open, shut
-- held open whatever the mouse does (a click on the open board does this)
function Board.pin(on)
  pinned = on == true
  if pinned then open(true) end
  if big and not big.dead and armed then apply(Board.p) end
end

local function makeDock()
  if dock and not dock.dead then return end
  if not holder or not holder.Parent then return end
  -- the small set is all the card can show; where only the big one is installed, that plays
  local set = Film.has("hd", Board.spec) and "hd" or Film.pick("ultra", Board.spec)
  if not set then return end
  dock = Film.new(holder, { spec = Board.spec, set = set, loop = true, window = true, backdrop = false, slots = 6, budget = 2, look = dockLook(), clock = clock })
  Board.film = dock
  if dock then
    dock:setAlpha(UNSEEN)
    dockShown = 0
  end
end
local function drop()
  shut()
  if big then big:destroy() end
  if dock then dock:destroy() end
  big, dock, Board.big, Board.film = nil, nil, nil, nil
  if still and still.Parent then still.Visible = true end
end

-- Whether the board's film is on this machine at all (it is not part of a public install).
function Board.installed() return Board.spec ~= nil and not Assets.lite and Film.pick("ultra", Board.spec) ~= nil end

-- Called by the Home tab with its card. Returns false when there is no board to show (not
-- installed, lite mode): the card then keeps its still.
function Board.mount(card, stillImage)
  if not Board.installed() then return false end
  Board.define()
  still = stillImage
  holder = UI.frame(card, { Name = "Board", Size = UDim2.new(0.62, 0, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Visible = O.on })

  scrim = UI.new("TextButton", { Name = "BoardScrim", Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 78, Visible = false, Parent = UI.overlay })
  scrim.Activated:Connect(B.safe("board.scrim", function() open(false) end))
  panel = UI.frame(UI.overlay, { Name = "BoardPanel", ZIndex = 80, Visible = false })
  if UI.fx.shadow then
    local host = UI.frame(panel, { Name = "Shadow", Size = UDim2.fromScale(1, 1) })
    UI.corner(host, RADIUS)
    shade = Instance.new("UIShadow")
    shade.BlurRadius = UDim.new(0, 64)
    shade.Offset = UDim2.fromOffset(0, 24)
    shade.Color = Color3.new(0, 0, 0)
    shade.Transparency = 1
    pcall(function() shade.ShowBehindParent = false end)
    shade.Parent = host
  end
  screen = UI.frame(panel, { Name = "Screen", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
  local hit = UI.new("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = panel })
  hit.Activated:Connect(B.safe("board.pin", function()
    if not wantPop then return end
    if pinned then open(false) else Board.pin(true) end
  end))
  -- a hairline round the picture, and how far through it is
  rim = UI.frame(panel, { Name = "Rim", Size = UDim2.fromScale(1, 1), ZIndex = 3 })
  local corner = Instance.new("UICorner")
  corner.Name = "Corner"
  corner.Parent = rim
  local stroke = Instance.new("UIStroke")
  stroke.Name = "Stroke"
  stroke.Color = Color3.new(1, 1, 1)
  stroke.Thickness = 1
  stroke.Transparency = 1
  stroke.Parent = rim
  bar = UI.frame(panel, { Name = "Progress", Size = UDim2.new(1, -RADIUS * 2, 0, 2), Position = UDim2.new(0, RADIUS, 1, -10), BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.78, ZIndex = 4, Visible = false })
  UI.corner(bar, true)
  fill = UI.frame(bar, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1 })
  UI.corner(fill, true)

  -- what the board is for, until it has been opened once
  chip = UI.frame(holder, { Name = "Hint", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(0, 24),
    AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 6, Visible = O.hover })
  UI.corner(chip, true)
  UI.pad(chip, 0, 10, 0, 9)
  UI.list(chip, "x", 6, { v = "Center" })
  local glyph = UI.icon(chip, "volume-x", 13, "ink", { LayoutOrder = 1 })
  glyph.ImageColor3 = Color3.new(1, 1, 1)
  local words = UI.text(chip, "Hover for sound", "caption", "ink", { LayoutOrder = 2, TextSize = 11 })
  words.TextColor3 = Color3.new(1, 1, 1)

  spring = Motion.spring(1, "smooth", function(x) apply(x[1]) end, 0.0008)

  -- Every frame the Home tab is up: the mouse, and which of the two players is the one on show.
  Motion.every(function(dt)
    if not holder.Parent then return end
    local live = dock ~= nil and not dock.dead and enabled() and onHome()
    if not live or UI.popoverOpen() or (not O.hover and not pinned) then
      if wantPop then open(false) elseif armed and Board.p <= 0.002 then disarm() end
      overSince = nil
    else
      local now = os.clock()
      local mouse = UI.mouse()
      local over
      if Board.p > 0.02 then
        over = UI.inside(panel, mouse)
      else
        over = UI.inside(holder, mouse) and UI.inside(Window.pageHost, mouse) and inView() and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
      end
      if over then
        offSince = nil
        overSince = overSince or now
        arm()
        -- open once it has rested there AND the big player has a picture to open with
        if not wantPop and now - overSince >= DWELL and big and big.fresh > 0 then open(true) end
      else
        overSince = nil
        if wantPop and not pinned then
          offSince = offSince or now
          if now - offSince >= LINGER then open(false) end
        elseif armed and not wantPop and Board.p <= 0.002 then
          disarm()
        end
      end
    end
    -- The hand-over back. The big player keeps the picture all the way home, and then sits
    -- exactly where the card's player is until that one has a picture of its own again.
    if dock and not dock.dead then
      if handing and big and big.fresh > 0 then
        handing = false
        if dock.playing then dock:pause() end
        dockShown = 0
        dock:setAlpha(UNSEEN)
      end
      if bigOnShow then
        if not wantPop and Board.p <= 0.002 and dock.fresh > 0 and not handing then
          bigOnShow = false
          dockShown = 1
          dock:setAlpha(DOCK_ALPHA)
          disarm()
          if chip then chip.Visible = O.hover and Board.opens == 0 end
        end
      elseif dock.playing then
        -- on its own in the card: let it in gently when it has just (re)started
        local goal = dock.fresh > 0 and 1 or 0
        if dockShown ~= goal then
          dockShown = goal == 1 and math.min(1, dockShown + dt * 6) or 0
          dock:setAlpha(util.lerp(UNSEEN, DOCK_ALPHA, dockShown))
          if still and still.Parent then still.Visible = dockShown < 1 end
        end
      end
    end
    if big and bar.Visible then fill.Size = UDim2.fromScale(util.clamp01(big.time / big.length), 1) end
  end, nil, "board.mouse")

  -- play only while it can be seen
  Motion.every(function()
    if not holder.Parent then return end
    if not enabled() then
      if dock or big then drop() end
      return
    end
    local seen = onHome() and (Board.p > 0.02 or inView())
    if seen then
      makeDock()
      if dock and not dock.playing and not wantPop and Board.p <= 0.002 then dock:play() end
    else
      if Board.p > 0 or wantPop or armed then shut() end
      if dock and dock.playing then
        dock:pause()
        dockShown = 0
        dock:setAlpha(UNSEEN)
        if still and still.Parent then still.Visible = true end
      end
    end
  end, 8, "board.watch")

  Config.on("home.board", function(on)
    if holder.Parent then holder.Visible = on end
    if not on then drop() end
  end)
  Config.on("home.boardQuality", function()
    shut()
    if big then big:destroy() end
    big, Board.big = nil, nil
  end)
  Config.on("home.boardHover", function(on)
    if chip and chip.Parent then chip.Visible = on and Board.p <= 0.02 and Board.opens == 0 end
    if not on and wantPop then open(false) end
  end)
  Config.on("app.radius", function() if dock and not dock.dead then dock:setLook(dockLook()) end end)
  -- open and at rest, nothing is moving to pick a new volume or size up
  for _, id in ipairs({ "home.boardVolume", "home.boardSize" }) do
    Config.on(id, function() if armed and big and not big.dead then apply(Board.p) end end)
  end
  Window.onShow:connect(function(on) if not on then shut() end end)
  Window.onPage:connect(function() shut() end)
  B.own(function()
    if big then big:destroy() end
    if dock then dock:destroy() end
  end)
  return true
end

function Board.define()
  if O then return end
  Config.define("home.board", true)
  Config.define("home.boardHover", true)
  Config.define("home.boardVolume", 60)
  Config.define("home.boardSize", 56)
  Config.define("home.boardQuality", "ultra")
  O = Config.mirror({ on = "home.board", hover = "home.boardHover", volume = "home.boardVolume", size = "home.boardSize", quality = "home.boardQuality" })
  Board.options = O
end
end
