do -- 04_ui.lua
-- ============================================================================
--  04 ui       instance factory, glass, text, icons, input, popovers, scroll
-- ============================================================================
local S, util, Motion, Theme, T, Assets = B.S, B.util, B.Motion, B.Theme, B.T, B.Assets
local UIS = S.UserInputService
local UI = { fx = { canvas = true, shadow = false, innerStroke = false }, sfxVolume = 0.5, sfxOn = true }
B.UI = UI

-- ---------------------------------------------------------------- capabilities
pcall(function()
  local probe = Instance.new("UIShadow")
  probe.BlurRadius = UDim.new(0, 4)
  probe:Destroy()
  UI.fx.shadow = true
end)
pcall(function()
  local probe = Instance.new("UIStroke")
  probe.BorderStrokePosition = Enum.BorderStrokePosition.Inner
  probe:Destroy()
  UI.fx.innerStroke = true
end)
pcall(function()
  -- a CanvasGroup is drawn at reduced resolution on the lowest quality levels: text goes soft
  local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
  if saved ~= Enum.SavedQualitySetting.Automatic and saved.Value <= 2 then UI.fx.canvas = false end
end)

-- ---------------------------------------------------------------- factory
local function applyTheme(instance, map)
  for property, spec in pairs(map) do
    if type(spec) == "table" then Theme.bind(instance, property, spec[1], spec[2]) else Theme.bind(instance, property, spec) end
  end
end
function UI.new(class, props, children)
  local instance = Instance.new(class)
  local parent
  if props then
    for key, value in pairs(props) do
      if key == "Parent" then parent = value
      elseif key == "Theme" then applyTheme(instance, value)
      else instance[key] = value end
    end
  end
  if children then
    for _, child in ipairs(children) do child.Parent = instance end
  end
  if parent then instance.Parent = parent end
  return instance
end
local new = UI.new

function UI.frame(parent, props)
  local frame = Instance.new("Frame")
  frame.BackgroundTransparency = 1
  frame.BorderSizePixel = 0
  if props then
    for key, value in pairs(props) do
      if key == "Theme" then applyTheme(frame, value) else frame[key] = value end
    end
  end
  frame.Parent = parent
  return frame
end
-- radius: a token name ("rCard"), a pixel count, or true for a full pill
function UI.corner(instance, radius)
  local corner = Instance.new("UICorner")
  if radius == true then corner.CornerRadius = UDim.new(1, 0)
  elseif type(radius) == "string" then Theme.bind(corner, "CornerRadius", radius, function(value) return UDim.new(0, value) end)
  else corner.CornerRadius = UDim.new(0, radius or 8) end
  corner.Parent = instance
  return corner
end
function UI.stroke(instance, token, alphaToken, thickness)
  local stroke = Instance.new("UIStroke")
  stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  stroke.Thickness = thickness or 1
  Theme.bind(stroke, "Color", token or "ink")
  if type(alphaToken) == "number" then stroke.Transparency = alphaToken else Theme.bind(stroke, "Transparency", alphaToken or "strokeA") end
  if UI.fx.innerStroke then stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
  stroke.Parent = instance
  return stroke
end
function UI.pad(instance, top, right, bottom, left)
  local pad = Instance.new("UIPadding")
  right = right or top
  bottom = bottom or top
  left = left or right
  pad.PaddingTop, pad.PaddingRight, pad.PaddingBottom, pad.PaddingLeft = UDim.new(0, top), UDim.new(0, right), UDim.new(0, bottom), UDim.new(0, left)
  pad.Parent = instance
  return pad
end
function UI.list(instance, direction, gap, align)
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = direction == "x" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, gap or 0)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  if align then
    if align.h then layout.HorizontalAlignment = Enum.HorizontalAlignment[align.h] end
    if align.v then layout.VerticalAlignment = Enum.VerticalAlignment[align.v] end
  end
  layout.Parent = instance
  return layout
end
function UI.scaleOf(instance)
  local scale = instance:FindFirstChildOfClass("UIScale")
  if not scale then scale = Instance.new("UIScale"); scale.Parent = instance end
  return scale
end
function UI.gradient(instance, props)
  local gradient = Instance.new("UIGradient")
  for key, value in pairs(props) do gradient[key] = value end
  gradient.Parent = instance
  return gradient
end
function UI.alphaSeq(...)
  local points, args = {}, { ... }
  for i = 1, #args, 2 do points[#points + 1] = NumberSequenceKeypoint.new(args[i], args[i + 1]) end
  return NumberSequence.new(points)
end

-- ---------------------------------------------------------------- text + icons
local STYLE = Theme.type
-- style: a key of Theme.type; color: a token name
function UI.text(parent, text, style, color, props)
  local spec = STYLE[style or "body"] or STYLE.body
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency = 1
  label.BorderSizePixel = 0
  label.FontFace = B.F[spec[1]]
  if UI.fontKey then UI.fontKey[label] = spec[1] end
  label.TextSize = spec[2]
  label.Text = text or ""
  label.TextXAlignment = Enum.TextXAlignment.Left
  label.TextYAlignment = Enum.TextYAlignment.Center
  label.AutomaticSize = Enum.AutomaticSize.XY
  label.Size = UDim2.new()
  Theme.bind(label, "TextColor3", color or "ink")
  if props then
    for key, value in pairs(props) do label[key] = value end
  end
  label.Parent = parent
  return label
end
function UI.icon(parent, name, size, color, props)
  local image = Instance.new("ImageLabel")
  image.BackgroundTransparency = 1
  image.BorderSizePixel = 0
  image.Size = UDim2.fromOffset(size or 18, size or 18)
  image.ScaleType = Enum.ScaleType.Fit
  Theme.bind(image, "ImageColor3", color or "ink")
  local id, offset, rect = Assets.icon(name)
  if id then
    image.Image, image.ImageRectOffset, image.ImageRectSize = id, offset, rect
  end
  if props then
    for key, value in pairs(props) do image[key] = value end
  end
  image.Parent = parent
  return image
end
function UI.setIcon(image, name)
  local id, offset, rect = Assets.icon(name)
  if id then image.Image, image.ImageRectOffset, image.ImageRectSize = id, offset, rect end
end
function UI.image(parent, name, props)
  local image = Instance.new("ImageLabel")
  image.BackgroundTransparency = 1
  image.BorderSizePixel = 0
  image.Image = Assets.image(name) or ""
  if props then
    for key, value in pairs(props) do
      if key == "Theme" then applyTheme(image, value) else image[key] = value end
    end
  end
  image.Parent = parent
  return image
end

-- ---------------------------------------------------------------- glass
-- A translucent surface: tinted fill, fine grain, a top sheen and a rim that
-- catches light. level: "window" (reads the glass slider), "panel", "popover".
function UI.glass(parent, opts)
  opts = opts or {}
  local level = opts.level or "panel"
  local radius = opts.radius or "rPanel"
  local frame = Instance.new("Frame")
  frame.BorderSizePixel = 0
  frame.Name = opts.name or "Glass"
  if level == "window" then
    Theme.bind(frame, "BackgroundColor3", "base")
    Theme.bind(frame, "BackgroundTransparency", "baseA")
  elseif level == "popover" then
    Theme.bind(frame, "BackgroundColor3", "popover")
    frame.BackgroundTransparency = 0.04
  else
    Theme.bind(frame, "BackgroundColor3", "ink")
    Theme.bind(frame, "BackgroundTransparency", opts.fill or "fill1A")
  end
  UI.corner(frame, radius)
  if opts.grain ~= false and Assets.image("noise") then
    local grain = UI.image(frame, "noise", { Name = "Grain", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Tile,
      TileSize = UDim2.fromOffset(128, 128), ImageTransparency = opts.grainAlpha or 0.955, ZIndex = 0, Interactable = false })
    UI.corner(grain, radius)
  end
  if opts.sheen ~= false then
    local sheen = Instance.new("Frame")
    sheen.Name = "Sheen"
    sheen.BorderSizePixel = 0
    sheen.BackgroundColor3 = Color3.new(1, 1, 1)
    sheen.Size = UDim2.fromScale(1, 1)
    sheen.ZIndex = 0
    sheen.Interactable = false
    UI.corner(sheen, radius)
    UI.gradient(sheen, { Rotation = 90, Transparency = UI.alphaSeq(0, opts.sheenAlpha or 0.93, 0.45, 1, 1, 1) })
    sheen.Parent = frame
  end
  local rim = Instance.new("UIStroke")
  rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  rim.Thickness = 1
  rim.Color = Color3.new(1, 1, 1)
  if UI.fx.innerStroke then rim.BorderStrokePosition = Enum.BorderStrokePosition.Inner end
  local rimGradient = UI.gradient(rim, { Rotation = 52,
    Transparency = UI.alphaSeq(0, opts.rimHi or 0.55, 0.32, 0.9, 0.68, 0.93, 1, opts.rimLo or 0.72) })
  rim.Parent = frame
  if opts.shadow and UI.fx.shadow then
    local shadow = Instance.new("UIShadow")
    shadow.BlurRadius = UDim.new(0, opts.shadow == true and 56 or opts.shadow)
    shadow.Offset = UDim2.fromOffset(0, opts.shadowY or 22)
    shadow.Color = Color3.new(0, 0, 0)
    Theme.bind(shadow, "Transparency", "shadowA")
    pcall(function() shadow.ShowBehindParent = false end)
    shadow.Parent = frame
  end
  if opts.props then
    for key, value in pairs(opts.props) do frame[key] = value end
  end
  frame.Parent = parent
  return frame, rimGradient
end

-- A quiet filled surface (cards, rows): ink at a low alpha with a hairline.
function UI.surface(parent, props, radius, fill)
  local frame = Instance.new("Frame")
  frame.BorderSizePixel = 0
  Theme.bind(frame, "BackgroundColor3", "ink")
  Theme.bind(frame, "BackgroundTransparency", fill or "fill1A")
  UI.corner(frame, radius or "rCard")
  if props then
    for key, value in pairs(props) do frame[key] = value end
  end
  frame.Parent = parent
  return frame
end

-- A container that can fade as one. Falls back to a plain frame where a
-- CanvasGroup would soften text; UI.fade then just shows or hides it.
function UI.group(parent, props)
  local group = Instance.new(UI.fx.canvas and "CanvasGroup" or "Frame")
  group.BackgroundTransparency = 1
  group.BorderSizePixel = 0
  if props then
    for key, value in pairs(props) do group[key] = value end
  end
  group.Parent = parent
  return group
end
function UI.fade(group, alpha, preset, done)
  if group:IsA("CanvasGroup") then
    if alpha > 0 then group.Visible = true end
    Motion.to(group, "GroupTransparency", 1 - alpha, preset or "quick", function()
      if alpha <= 0 then group.Visible = false end
      if done then done() end
    end)
  else
    group.Visible = alpha > 0
    if done then done() end
  end
end
function UI.setFade(group, alpha)
  if group:IsA("CanvasGroup") then Motion.snap(group, "GroupTransparency", 1 - alpha) end
  group.Visible = alpha > 0
end

-- ---------------------------------------------------------------- sound
local sounds = {}
function UI.sfx(name, volume)
  if not UI.sfxOn or UI.sfxVolume <= 0 or not UI.soundHost then return end
  local id = Assets.sound(name)
  if not id then return end
  local now = os.clock()
  local entry = sounds[name]
  if entry and now - entry.at < 0.04 then return end
  if not entry then
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Parent = UI.soundHost
    entry = { sound = sound, at = 0 }
    sounds[name] = entry
  end
  entry.at = now
  entry.sound.Volume = (volume or 1) * UI.sfxVolume * 0.5
  entry.sound.PlaybackSpeed = 0.97 + math.random() * 0.06
  entry.sound:Play()
end
-- A look's own sound, by its asset id (src/53: Novoline's), at the volume and speed that look plays
-- it at when the hub's sound volume is where it starts (45 %), and louder or softer with it.
function UI.sfxId(id, volume, speed)
  if not UI.sfxOn or UI.sfxVolume <= 0 or not UI.soundHost then return end
  local key = id .. "@" .. tostring(speed or 1)
  local now = os.clock()
  local entry = sounds[key]
  if entry and now - entry.at < 0.04 then return end
  if not entry then
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Parent = UI.soundHost
    entry = { sound = sound, at = 0 }
    sounds[key] = entry
  end
  entry.at = now
  entry.sound.Volume = math.clamp((volume or 1) * UI.sfxVolume / 0.45, 0, 2)
  entry.sound.PlaybackSpeed = speed or 1
  entry.sound.TimePosition = 0
  entry.sound:Play()
end

-- ---------------------------------------------------------------- input
local function isPress(input)
  return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
UI.isPress = isPress
-- One coordinate space everywhere: the one AbsolutePosition reports. Measured on the client:
-- a ScreenGui that ignores the inset sits at AbsolutePosition (0, -58), InputObject.Position is
-- in that same space, and GetMouseLocation / the camera's viewport are 58 px further down.
function UI.inset() return S.GuiService:GetGuiInset() end
function UI.mouse() return UIS:GetMouseLocation() - S.GuiService:GetGuiInset() end
function UI.point(input) return Vector2.new(input.Position.X, input.Position.Y) end
-- design units -> screen pixels for anything inside the window (set by 06 window)
function UI.unit() return 1 end
function UI.inside(gui, point)
  local p, s = gui.AbsolutePosition, gui.AbsoluteSize
  return point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y
end

-- Attach hover / press / click / alt (right click) handlers to a GuiButton.
function UI.wire(button, handlers)
  local pressing = false
  if handlers.hover then
    button.MouseEnter:Connect(B.safe("ui.hover", function() handlers.hover(true) end))
    button.MouseLeave:Connect(B.safe("ui.hover", function()
      handlers.hover(false)
      if pressing and handlers.press then pressing = false; handlers.press(false) end
    end))
  end
  button.InputBegan:Connect(B.safe("ui.press", function(input)
    if isPress(input) then
      pressing = true
      if handlers.press then handlers.press(true) end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and handlers.alt then
      handlers.alt(input)
    end
  end))
  button.InputEnded:Connect(B.safe("ui.press", function(input)
    if isPress(input) and pressing then
      pressing = false
      if handlers.press then handlers.press(false) end
    end
  end))
  if handlers.click then button.Activated:Connect(B.safe("ui.click", function(input) handlers.click(input) end)) end
  return button
end
-- An invisible button laid over `parent`. Only for parents WITHOUT a list layout or automatic
-- width: a full-size child there is laid out as an item and inflates the parent (measured:
-- a 60 px dropdown pill became 550 px). Those use UI.pressable instead.
function UI.button(parent, handlers, props)
  local button = Instance.new("TextButton")
  button.Name = "Hit"
  button.Text = ""
  button.BackgroundTransparency = 1
  button.BorderSizePixel = 0
  button.AutoButtonColor = false
  button.Size = UDim2.fromScale(1, 1)
  button.ZIndex = 5
  if props then
    for key, value in pairs(props) do button[key] = value end
  end
  UI.wire(button, handlers)
  button.Parent = parent
  return button
end
-- A container that is itself the button: children (labels, icons, layouts) go inside it.
function UI.pressable(parent, props, handlers)
  local button = Instance.new("TextButton")
  button.Text = ""
  button.AutoButtonColor = false
  button.BorderSizePixel = 0
  button.BackgroundTransparency = 1
  if props then
    for key, value in pairs(props) do
      if key == "Theme" then applyTheme(button, value) else button[key] = value end
    end
  end
  if handlers then UI.wire(button, handlers) end
  button.Parent = parent
  return button
end

-- Drag with mouse or finger. onMove(position, deltaFromStart); returns nothing.
function UI.drag(handle, onStart, onMove, onEnd)
  handle.InputBegan:Connect(B.safe("ui.drag", function(input)
    if not isPress(input) then return end
    local start = UI.point(input)
    if onStart and onStart(start) == false then return end
    local touch = input.UserInputType == Enum.UserInputType.Touch
    local moved, ended
    local function finish()
      if moved then moved:Disconnect() end
      if ended then ended:Disconnect() end
      moved, ended = nil, nil
      if onEnd then B.try("ui.drag.end", onEnd) end
    end
    moved = UIS.InputChanged:Connect(B.safe("ui.drag.move", function(change)
      if (touch and change == input) or (not touch and change.UserInputType == Enum.UserInputType.MouseMovement) then
        local p = UI.point(change)
        onMove(p, p - start)
      end
    end))
    ended = UIS.InputEnded:Connect(function(finished)
      if finished == input or (not touch and finished.UserInputType == Enum.UserInputType.MouseButton1) then finish() end
    end)
  end))
end

-- ---------------------------------------------------------------- overlay layer
-- Popovers, menus and tooltips live in one full-screen layer above the window.
local popovers = {}
function UI.mountOverlay(gui, scaleSource)
  UI.overlay = UI.frame(gui, { Name = "Overlay", Size = UDim2.fromScale(1, 1), ZIndex = 50 })
  UI.overlayScale = scaleSource
  -- a click anywhere outside the open popover closes it
  B.connect(UIS.InputBegan, function(input)
    if #popovers == 0 then return end
    if isPress(input) or input.UserInputType == Enum.UserInputType.MouseButton2 then
      local point = UI.point(input)
      for index = #popovers, 1, -1 do
        local pop = popovers[index]
        if not UI.inside(pop.frame, point) and not (pop.anchor and UI.inside(pop.anchor, point)) then pop.close() else break end
      end
    elseif input.KeyCode == Enum.KeyCode.Escape then
      popovers[#popovers].close()
    end
  end, "ui.overlay")
end
function UI.closePopovers()
  for index = #popovers, 1, -1 do popovers[index].close(true) end
end
function UI.popoverOpen() return #popovers > 0 end

-- Open a glass panel next to `anchor`. build(content, close) fills it.
-- opts: width, align ("left" | "right" | "center"), gap, side ("below" | "above")
function UI.popover(anchor, opts, build)
  opts = opts or {}
  local scale = UI.overlayScale and UI.overlayScale() or 1
  local width = opts.width or 220
  local pop = { anchor = anchor }
  local holder = UI.frame(UI.overlay, { Name = "Popover", Size = UDim2.fromOffset(width, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 60 })
  local sizer = Instance.new("UIScale")
  sizer.Scale = scale * 0.92
  sizer.Parent = holder
  local glass = UI.glass(holder, { level = "popover", radius = "rCard", shadow = 34, shadowY = 14, rimHi = 0.62, name = "Panel",
    props = { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y } })
  local group = UI.group(glass, { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.pad(group, opts.pad or 6)
  UI.list(group, "y", opts.gap or 2)
  pop.frame = holder
  local closed = false
  function pop.close(instant)
    if closed then return end
    closed = true
    local at = table.find(popovers, pop)
    if at then table.remove(popovers, at) end
    if opts.onClose then B.try("popover.close", opts.onClose) end
    if instant then holder:Destroy(); return end
    Motion.to(sizer, "Scale", scale * 0.94, "quick")
    UI.fade(group, 0, "quick")
    Motion.to(glass, "BackgroundTransparency", 1, "quick", function() holder:Destroy() end)
  end
  B.try("popover.build", build, group, pop.close)
  -- place it once its height is known
  local function place()
    local view = B.viewport()
    local a, s = anchor.AbsolutePosition, anchor.AbsoluteSize
    local size = holder.AbsoluteSize
    local w, h = width * scale, math.max(size.Y, 1)
    local x
    if opts.align == "left" then x = a.X elseif opts.align == "center" then x = a.X + s.X / 2 - w / 2 else x = a.X + s.X - w end
    local y = a.Y + s.Y + 6 * scale
    local above = opts.side == "above" or (y + h > view.Y - 8 and a.Y - h - 6 * scale > 8)
    if above then y = a.Y - h - 6 * scale end
    local origin = UI.overlay.AbsolutePosition
    x = math.clamp(x - origin.X, 8, math.max(8, view.X - w - 8))
    y = math.clamp(y - origin.Y, 8, math.max(8, view.Y - h - 8))
    holder.Position = UDim2.fromOffset(x, y)
    return above
  end
  place()
  holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if not closed then place() end end)
  UI.setFade(group, 0)
  UI.fade(group, 1, "quick")
  Motion.to(sizer, "Scale", scale, "snappy")
  popovers[#popovers + 1] = pop
  UI.sfx("open", 0.5)
  return pop
end

-- A simple menu: items = { { label, icon?, hint?, danger?, checked?, run } | "divider" }
-- A long one (more than opts.rows of them, 11 unless said) scrolls, and opens on the one that is checked.
function UI.menu(anchor, items, opts)
  opts = opts or {}
  return UI.popover(anchor, { width = opts.width or 208, align = opts.align, side = opts.side }, function(content, close)
    local rows = opts.rows or 11
    if #items > rows then
      local holder = UI.frame(content, { Name = "Long", Size = UDim2.new(1, 0, 0, rows * 34 - 2) })
      local scroller, scroll = UI.scroll(holder, { Size = UDim2.fromScale(1, 1), Name = "Scroll" })
      content = UI.frame(scroller, { Name = "Rows", Size = UDim2.new(1, -9, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
      UI.list(content, "y", 2)
      for index, item in ipairs(items) do
        if type(item) == "table" and item.checked then
          task.defer(function() if holder.Parent then scroll.to((index - 4) * 34, true) end end)
          break
        end
      end
    end
    for index, item in ipairs(items) do
      if item == "divider" then
        local line = UI.frame(content, { Size = UDim2.new(1, -12, 0, 1), LayoutOrder = index, Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "strokeA" } })
        line.Position = UDim2.fromOffset(6, 0)
      else
        local row = UI.frame(content, { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = index, Theme = { BackgroundColor3 = "ink" } })
        UI.corner(row, "rSmall")
        local x = 10
        if item.icon then
          UI.icon(row, item.icon, 16, item.danger and "bad" or "sub", { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
          x = 34
        end
        UI.text(row, item.label, "label", item.danger and "bad" or "ink", { Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13 })
        if item.checked then
          UI.icon(row, "check", 15, "accent", { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
        elseif item.hint then
          UI.text(row, item.hint, "mono", "faint", { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 11 })
        end
        UI.button(row, {
          hover = function(on) Motion.to(row, "BackgroundTransparency", on and T.fill2A or 1, "quick") end,
          click = function()
            UI.sfx("click", 0.6)
            if not item.keepOpen then close() end
            if item.run then item.run() end
          end,
        })
      end
    end
  end)
end

-- ---------------------------------------------------------------- tooltip
-- One tip for the whole hub, in every look (2026-10-30: nearly every control says what it does when
-- the mouse rests on it). It comes beside what it is about (to its right, else its left, else under
-- it, always on the screen), fades and slides in, and goes straight on to the next thing the mouse
-- rests on without going away first. On a screen of its own, above everything.
local TIP_W, TIP_MIN = 250, 110
local tipGui, tipCard, tipTitle, tipBody, tipFor
local tipToken, tipShown, tipGoneAt = 0, false, -math.huge
local tipHideToken = 0          -- (a pending hide: any show, or a later hide, cancels it)
local function tipBuild()
  if tipCard and tipCard.Parent and tipGui and tipGui.Parent then return true end
  if not B.alive then return false end
  tipGui = B.screen(9950)
  tipCard = Instance.new("CanvasGroup")
  tipCard.Name = "Tip"
  -- (one flat colour, no UIGradient: measured live 2026-10-30, a gradient on a CanvasGroup tints all
  -- that is drawn in it, and the words came out near black on the card)
  -- (the card's colour and its white rim are a frame inside the group, not the group's own: a stroke on
  -- the CanvasGroup itself is drawn outside it, so it never faded with it, and hovering a few controls
  -- quickly left the white rim standing. Seen by the user 2026-11-01)
  tipCard.BackgroundTransparency, tipCard.BorderSizePixel = 1, 0
  tipCard.Size, tipCard.AutomaticSize = UDim2.fromOffset(TIP_W, 0), Enum.AutomaticSize.Y
  tipCard.GroupTransparency, tipCard.Visible = 1, false
  local back = Instance.new("Frame")
  back.Name = "Back"
  back.BackgroundColor3, back.BackgroundTransparency, back.BorderSizePixel = Color3.fromRGB(21, 21, 25), 0, 0
  -- (inset a pixel, so the 1-pixel rim is inside the group's canvas, which clips at its edge)
  back.Position, back.Size, back.ZIndex = UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), 0
  local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = back
  local rim = Instance.new("UIStroke")
  rim.ApplyStrokeMode, rim.Color, rim.Transparency, rim.Thickness = Enum.ApplyStrokeMode.Border, Color3.new(1, 1, 1), 0.86, 1
  rim.Parent = back
  back.Parent = tipCard
  -- (the words in a frame of their own, which the card's height follows: the back is not one of its lines)
  local content = Instance.new("Frame")
  content.Name = "Content"
  content.BackgroundTransparency, content.BorderSizePixel, content.ZIndex = 1, 0, 1
  content.Size, content.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
  content.Parent = tipCard
  local padding = Instance.new("UIPadding")
  padding.PaddingTop, padding.PaddingBottom, padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 9), UDim.new(0, 11), UDim.new(0, 11)
  padding.Parent = content
  local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 2); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = content
  local function line(order, font, size, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency, label.BorderSizePixel = 1, 0
    label.Size, label.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
    label.FontFace, label.TextSize, label.TextColor3 = font, size, color
    label.TextWrapped, label.TextXAlignment, label.LayoutOrder = true, Enum.TextXAlignment.Left, order
    label.Text, label.Visible = "", true
    label.Parent = content
    return label
  end
  tipTitle = line(1, B.F.text600, 12, Color3.fromRGB(246, 246, 248))
  tipBody = line(2, B.F.text400, 12, Color3.fromRGB(190, 190, 198))
  tipCard.Parent = tipGui
  return true
end
local TIP_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TIP_MOVE = TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TIP_OUT = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local function tipShow(target, title, text)
  if not tipBuild() then return end
  tipTitle.Text, tipTitle.Visible = title or "", title ~= nil and title ~= ""
  tipBody.Text = text
  -- (as wide as its words want, up to TIP_W: a short tip is a small card)
  local width = math.clamp(math.max(#(title or "") * 7.2, #text * 6.3) + 24, TIP_MIN, TIP_W)
  tipCard.Size = UDim2.fromOffset(width, 0)
  local base = tipGui.AbsolutePosition
  local view = tipGui.AbsoluteSize
  local at, size = target.AbsolutePosition - base, target.AbsoluteSize
  local height = (tipTitle.Visible and 16 or 0) + math.ceil(#text * 6.3 / math.max(width - 22, 40)) * 16 + 20
  local x, y = at.X + size.X + 10, at.Y + size.Y / 2 - height / 2
  local from = Vector2.new(-8, 0)
  if x + width > view.X - 8 then
    x, from = at.X - width - 10, Vector2.new(8, 0)
    if x < 8 then
      -- (no room either side: under it, or over it)
      x = math.clamp(at.X + size.X / 2 - width / 2, 8, math.max(view.X - width - 8, 8))
      y, from = at.Y + size.Y + 8, Vector2.new(0, -6)
      if y + height > view.Y - 8 then y, from = at.Y - height - 8, Vector2.new(0, 6) end
    end
  end
  y = math.clamp(y, 8, math.max(view.Y - height - 8, 8))
  local goal = UDim2.fromOffset(math.floor(x), math.floor(y))
  tipHideToken += 1                -- (a hide still waiting to put the card away is for the last one, not this)
  if tipShown and tipCard.Visible then
    -- (already showing: it moves over to the new one)
    S.TweenService:Create(tipCard, TIP_MOVE, { Position = goal, GroupTransparency = 0 }):Play()
  else
    tipCard.Position = goal + UDim2.fromOffset(from.X, from.Y)
    tipCard.GroupTransparency = 1
    tipCard.Visible = true
    S.TweenService:Create(tipCard, TIP_IN, { Position = goal, GroupTransparency = 0 }):Play()
  end
  tipShown = true
end
local function tipHide()
  -- (put away whenever it is up, faded or not: a tip about to come that was called off, the mouse gone on
  -- before it came, left the card up and faded with nothing to put it away, and its rim standing)
  if not (tipCard and (tipShown or tipCard.Visible)) then return end
  if tipShown then tipGoneAt = os.clock() end
  tipShown = false
  tipHideToken += 1
  local mine = tipHideToken
  S.TweenService:Create(tipCard, TIP_OUT, { GroupTransparency = 1 }):Play()
  task.delay(0.12, function() if mine == tipHideToken and not tipShown and tipCard then tipCard.Visible = false end end)
end
-- target: the thing the mouse rests on; text: what it does; title: its name (optional)
function UI.tooltip(target, text, title)
  if type(text) ~= "string" or text == "" then return end
  target.MouseEnter:Connect(function()
    tipToken += 1
    local mine = tipToken
    tipFor = target
    -- (one tip just showing, or just gone: the next comes at once, the way a menu's tips do)
    local quick = tipShown or os.clock() - tipGoneAt < 0.3
    task.delay(quick and 0.02 or 0.35, function()
      if mine ~= tipToken or tipFor ~= target or not B.alive or not target.Parent then return end
      B.try("ui.tip", tipShow, target, title, text)
    end)
  end)
  target.MouseLeave:Connect(function()
    if tipFor ~= target then return end
    tipFor = nil
    tipToken += 1
    local mine = tipToken
    task.delay(0.06, function() if mine == tipToken then tipHide() end end)
  end)
  -- (a click: it has been read; it goes)
  if target:IsA("GuiButton") then target.MouseButton1Down:Connect(function() tipToken += 1; tipFor = nil; tipHide() end) end
end
function UI.hideTip()
  tipToken += 1
  tipFor = nil
  tipHide()
end

-- ---------------------------------------------------------------- scroll
-- A vertical scroller with a spring-driven wheel and a scrollbar: a thumb that says how far down
-- the page is, grows under the pointer, and can be dragged; a press on the track beside it goes
-- there. UI.scrollbar: "always" (it rests faint), "auto" (only while the page moves), "off".
UI.scrollbar = "always"
local scrollers = setmetatable({}, { __mode = "k" })
function UI.setScrollbar(mode)
  UI.scrollbar = mode
  for _, paint in pairs(scrollers) do B.try("ui.scrollbar", paint) end
end
local BAR_REST, BAR_WIDE, BAR_GRIP = 3, 6, 14     -- the thumb at rest and under the pointer, and the strip that takes the pointer
function UI.scroll(parent, props)
  local scroller = Instance.new("ScrollingFrame")
  scroller.BackgroundTransparency = 1
  scroller.BorderSizePixel = 0
  scroller.ScrollBarThickness = 0
  scroller.ScrollingDirection = Enum.ScrollingDirection.Y
  scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
  scroller.CanvasSize = UDim2.new()
  scroller.ElasticBehavior = Enum.ElasticBehavior.Never
  scroller.ScrollingEnabled = B.touch
  if props then
    for key, value in pairs(props) do scroller[key] = value end
  end
  scroller.Parent = parent
  local thumb = UI.frame(parent, { Name = "Thumb", Size = UDim2.fromOffset(BAR_REST, 40), AnchorPoint = Vector2.new(1, 0), ZIndex = 8,
    Theme = { BackgroundColor3 = "ink" }, BackgroundTransparency = 1 })
  UI.corner(thumb, true)
  local grip = UI.new("TextButton", { Name = "Scrollbar", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.fromOffset(BAR_GRIP, 40), ZIndex = 9, Visible = false, Parent = parent })
  local target = 0
  local spring = Motion.spring(1, "smooth", function(x)
    scroller.CanvasPosition = Vector2.new(0, x[1])
  end, 0.2)
  local function limit()
    return math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
  end
  local hideToken = 0
  local hovered, dragging, flashing, width = false, false, false, BAR_REST
  local bar = { top = 0, size = 0, span = 0 }       -- the thumb as it was last laid out, in screen pixels
  -- false when there is nothing to scroll, or the bar is switched off
  local function refresh()
    local window, canvas = scroller.AbsoluteWindowSize.Y, scroller.AbsoluteCanvasSize.Y
    local needed = canvas > window + 1 and window > 0 and UI.scrollbar ~= "off"
    if grip.Visible ~= needed then grip.Visible = needed end
    if not needed then thumb.BackgroundTransparency = 1; return false end
    local track = scroller.AbsoluteSize.Y - 12
    local size = math.max(28, track * window / canvas)
    local ratio = scroller.CanvasPosition.Y / math.max(1, canvas - window)
    local unit = UI.unit()
    local right = (scroller.AbsolutePosition.X - parent.AbsolutePosition.X + scroller.AbsoluteSize.X) / unit
    local top = scroller.AbsolutePosition.Y - parent.AbsolutePosition.Y
    thumb.Size = UDim2.fromOffset(width, size / unit)
    thumb.Position = UDim2.new(0, right - 3, 0, (top + 6 + (track - size) * ratio) / unit)
    grip.Size = UDim2.fromOffset(BAR_GRIP, scroller.AbsoluteSize.Y / unit)
    grip.Position = UDim2.new(0, right, 0, top / unit)
    bar.top, bar.size, bar.span = scroller.AbsolutePosition.Y + 6, size, track - size
    return true
  end
  local widen = Motion.spring(1, "snappy", function(x)
    width = x[1]
    refresh()
  end, 0.05)
  widen:snap({ BAR_REST })
  -- how solid the thumb is: held, under the pointer, while the page moves, or at rest
  local function paint()
    if not refresh() then return end
    local alpha = dragging and 0.35 or hovered and 0.5 or flashing and 0.62 or (UI.scrollbar == "always" and 0.82 or 1)
    Motion.to(thumb, "BackgroundTransparency", alpha, alpha >= 0.8 and "gentle" or "quick")
    widen:to({ (dragging or hovered) and BAR_WIDE or BAR_REST })
  end
  scrollers[scroller] = paint
  local function flash()
    flashing = true
    paint()
    hideToken += 1
    local mine = hideToken
    task.delay(0.9, function()
      if mine == hideToken and thumb.Parent then flashing = false; paint() end
    end)
  end
  scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(flash)
  scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
    if target > limit() then target = limit(); spring:to({ target }) end
    paint()
  end)
  scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(paint)
  -- the thumb held: the page goes with the pointer, with no spring between them
  local grab = 0
  local function follow(y)
    local ratio = bar.span > 0 and math.clamp((y - grab - bar.top) / bar.span, 0, 1) or 0
    target = ratio * limit()
    spring:snap({ target })
  end
  UI.drag(grip, function(point)
    if not refresh() then return false end
    local at = bar.top + bar.span * (scroller.CanvasPosition.Y / math.max(1, limit()))
    -- on the thumb it is taken where it was pressed; beside it, the thumb comes to the pointer
    grab = (point.Y >= at and point.Y <= at + bar.size) and (point.Y - at) or bar.size * 0.5
    dragging = true
    follow(point.Y)
    paint()
    return true
  end, function(point) follow(point.Y) end, function()
    dragging = false
    paint()
  end)
  grip.MouseEnter:Connect(function() hovered = true; paint() end)
  grip.MouseLeave:Connect(function() hovered = false; paint() end)
  local wheel = B.safe("ui.wheel", function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseWheel or B.touch then return end
    -- An open list (any popover) holds the page under it still: the wheel over it scrolls the list
    -- alone. Before, the page went on scrolling under an open dropdown and left it behind.
    local top = popovers[#popovers]
    if top and not (top.frame and scroller:IsDescendantOf(top.frame)) then return end
    if not spring:moving() then
      spring.x[1], spring.g[1] = scroller.CanvasPosition.Y, scroller.CanvasPosition.Y
      target = scroller.CanvasPosition.Y
    end
    target = math.clamp(target - input.Position.Z * 92, 0, limit())
    spring:to({ target })
  end)
  scroller.InputChanged:Connect(wheel)
  grip.InputChanged:Connect(wheel)        -- (the strip lies over the page's edge: the wheel works there too)
  -- (painted once it is laid out, not only when something about it changes)
  task.defer(function() if scroller.Parent then B.try("ui.scrollbar", paint) end end)
  local api = { frame = scroller, thumb = thumb, grip = grip }
  function api.to(y, instant)
    target = math.clamp(y, 0, limit())
    if instant then spring:snap({ target }) else
      spring.x[1] = scroller.CanvasPosition.Y
      spring:to({ target })
    end
  end
  function api.top(instant) api.to(0, instant) end
  return scroller, api
end

-- ---------------------------------------------------------------- the interface's letters
-- Settings > Font: every word the BASED look writes in one family (its wordmark keeps its own).
-- Done where the letters come from: B.F's keys take the family at their own weight, so whatever is
-- drawn from now on has it, and what is on screen already is moved across once, matched by the
-- face it wore. The other looks keep their own letters (Unnamed has its own font setting).
UI.FAMILIES = {
  { "inter", "Inter (BASED)" },
  { "monocraft", "Monocraft (Minecraft)", function() return B.F0 and B.F0.craft end },
  { "builder", "Builder Sans", "BuilderSans" },
  { "gotham", "Gotham", "GothamSSm" },
  { "montserrat", "Montserrat", "Montserrat" },
  { "nunito", "Nunito", "Nunito" },
  { "ubuntu", "Ubuntu", "Ubuntu" },
  { "titillium", "Titillium", "TitilliumWeb" },
  { "jura", "Jura", "Jura" },
  { "sarpanch", "Sarpanch", "Sarpanch" },
  { "michroma", "Michroma", "Michroma" },
  { "oswald", "Oswald", "Oswald" },
  { "fredoka", "Fredoka", "FredokaOne" },
  { "roboto", "Roboto Mono", "RobotoMono" },
  { "arial", "Arial", function() return Font.fromEnum(Enum.Font.Arial) end },
  { "source", "Source Sans", "SourceSansPro" },
}
-- the keys that follow the pick (the wordmark, wideBlack, stays BASED)
local LETTER_KEYS = { "text400", "text500", "text600", "mono400", "mono500", "wideBold", "serif", "serifItalic" }
local function faceSig(face) return tostring(face.Family) .. "|" .. tostring(face.Weight) .. "|" .. tostring(face.Style) end
function UI.familyOf(id)
  for _, spec in ipairs(UI.FAMILIES) do
    if spec[1] == id then
      local source = spec[3]
      if source == nil then return nil end
      local ok, face = pcall(function()
        if type(source) == "function" then return source() end
        return Font.fromName(source)
      end)
      return ok and typeof(face) == "Font" and face.Family or nil
    end
  end
  return nil
end
-- Which key each text on screen was drawn from (strong, swept): told by its face the first time it
-- is seen, from the hub's own faces (all different), or from the faces in use now. The second can be
-- two keys at once (in one family Inter 400 and Geist 400 are the same face): the body text wins,
-- and texts drawn by UI.text say their key outright. (Matching by face alone turned 381 labels into
-- the serif on the way back to Inter.)
UI.fontKey = {}
function UI.sweepFonts()
  for label in pairs(UI.fontKey) do
    if not label.Parent then UI.fontKey[label] = nil end
  end
end
function UI.setLetters(id)
  if not B.F0 then return end
  local family = UI.familyOf(id)
  local own, now = {}, {}
  for _, key in ipairs(LETTER_KEYS) do
    if B.F0[key] then own[faceSig(B.F0[key])] = own[faceSig(B.F0[key])] or key end
    if B.F[key] then now[faceSig(B.F[key])] = now[faceSig(B.F[key])] or key end
  end
  for label in pairs(UI.fontKey) do
    if not label.Parent then UI.fontKey[label] = nil end
  end
  for _, key in ipairs(LETTER_KEYS) do
    local own = B.F0[key]
    if own then
      if family then
        local ok, face = pcall(Font.new, family, own.Weight, own.Style)
        B.F[key] = ok and face or own
      else
        B.F[key] = own
      end
    end
  end
  -- what is on screen now: each text moved to its key's new face
  -- (the other looks keep their own letters, also where they draw on the HUD)
  local function owns(item) return (B.Unnamed ~= nil and B.Unnamed.owns(item)) or (B.Novoline ~= nil and B.Novoline.owns(item)) end
  for _, gui in ipairs(B.screens or {}) do
    if gui.Parent and not gui:GetAttribute("OwnLetters") then
      for _, item in ipairs(gui:GetDescendants()) do
        if (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) and not owns(item) then
          local key = UI.fontKey[item]
          if not key then
            local sig = faceSig(item.FontFace)
            key = own[sig] or now[sig]
            if key then UI.fontKey[item] = key end
          end
          if key and B.F[key] and item.FontFace ~= B.F[key] then item.FontFace = B.F[key] end
        end
      end
    end
  end
end

-- ---------------------------------------------------------------- misc
function UI.divider(parent, order)
  local line = UI.frame(parent, { Name = "Divider", Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order or 0,
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "strokeA" } })
  return line
end
-- Small rounded tag: "NEW", "BETA", a key name...
function UI.badge(parent, text, color, props)
  local badge = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), Theme = { BackgroundColor3 = color or "accent" },
    BackgroundTransparency = 0.82 })
  UI.corner(badge, 6)
  UI.pad(badge, 0, 6)
  UI.text(badge, text, "eyebrow", color or "accent", { TextSize = 9, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X })
  if props then
    for key, value in pairs(props) do badge[key] = value end
  end
  return badge
end
end
