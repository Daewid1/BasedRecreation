do -- 53_novoline.lua
-- ============================================================================
--  53 novoline  the third look: Novoline, as it looks with everything on
--
--  Drawn after Novoline's design (its code is PolyForm Strict, so none of it is
--  here: only how it looks and moves, read from its source, 2026-10-29: its
--  "upstream 9" layout). A pill at the bottom of the screen holds the tabs.
--  Opening it shades the game and every tab comes up as a DECK: cards of dark
--  glass (a near-black gradient, 8,8,9 to 26,26,28, a fine white rim lit at
--  the top and bottom, a soft shadow) held in the four corners of the screen,
--  40 px in from the sides, 34 from the top and 90 from the bottom:
--    Home      Novoline's own: the welcome line, the clock and the executor top
--              right; you, quick actions, what is playing and two quick commands
--              bottom left; the game, this server and your friends bottom right.
--    any other Novoline's settings deck: the tab's name, a search pill and your
--              account top right; its sections in a list card beside the card
--              that holds the chosen section's controls (one faint white group,
--              hairlines between rows); quick settings (three tinted tiles: the
--              tab's first switches) and its shortcuts on the right.
--  Cards rise out of the dock when it opens (0.56 s quint out from a 120 x 44
--  pill), sink back into it when it shuts, and change tab by gliding each card
--  into the next tab's card in the same corner (0.5 s quint out). Monochrome
--  controls: Novoline's glass switch (a white pill knob on a clear track that
--  fills when on), glass sliders, soft tile buttons, lists that open in place.
--  An island at the top shows what is playing and every message.
--  The same tabs and settings as the other looks (every control is bound to the
--  same flag); a tab that draws itself takes this look from Window.kit.
-- ============================================================================
local S, util, Motion, UI, Config, Window, Controls = B.S, B.util, B.Motion, B.UI, B.Config, B.Window, B.Controls
local UIS = S.UserInputService
local TS = S.TweenService
local N = { open = false, built = false, pages = {}, tabs = {}, current = nil }
B.Novoline = N

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local P = {
  top = rgb(8, 8, 9), bottom = rgb(26, 26, 28),
  card = rgb(28, 28, 32), raised = rgb(38, 38, 43), hover = rgb(48, 48, 54), line = rgb(55, 55, 61), divider = rgb(42, 42, 48),
  text = rgb(244, 244, 246), sub = rgb(205, 205, 210), dim = rgb(158, 158, 164), faint = rgb(108, 108, 115),
  on = rgb(242, 242, 244), off = rgb(58, 58, 62), knobOn = rgb(18, 18, 20), knobOff = rgb(255, 255, 255),
  rail = rgb(52, 52, 58), fill = rgb(224, 224, 226), danger = rgb(239, 68, 68), good = rgb(82, 214, 160),
  white = Color3.new(1, 1, 1), black = Color3.new(0, 0, 0),
  -- Novoline's own names for what its cards use
  subtle = rgb(150, 150, 156), ink = rgb(18, 18, 20), placeholder = rgb(118, 118, 124),
}
N.P = P
-- the tinted tiles (Novoline's quick settings and quick actions): the plate when on, and its icon
local TINT = {
  { rgb(13, 40, 51), rgb(64, 186, 255) },    -- blue
  { rgb(38, 28, 62), rgb(168, 120, 255) },   -- purple
  { rgb(14, 46, 40), rgb(56, 224, 186) },    -- teal
  { rgb(52, 30, 12), rgb(255, 156, 64) },    -- amber (quick commands)
  { rgb(52, 18, 22), rgb(255, 96, 102) },    -- red
}
local ROW_H, COMPACT_H = 56, 40       -- a setting with its line under it, and one without
local GLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FILL_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACCENT = rgb(230, 30, 30)
local function accent() return Config.get("app.novoline.accent") or ACCENT end
local W, H = 600, 480                 -- the panel, design pixels (Settings can drag it bigger)
local DOCK_H = 52
local OPEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SWITCH_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- Novoline's own sounds, as its source plays them: the menu opening (at 0.9 speed) and closing
-- (the same sound at 0.7), a change of tab on the dock, and a notification. It has none for a
-- click or a switch (its one click sound is fetched from a file host at run time: not used here),
-- so those keep the hub's own.
local NV_SOUND = {
  open = { "rbxassetid://255881176", 0.8, 0.9 },
  close = { "rbxassetid://255881176", 0.8, 0.7 },
  tab = { "rbxassetid://1180994874", 0.8, 1 },
  notify = { "rbxassetid://255881176", 0.6, 1 },
}
local function nvSound(name)
  local own = NV_SOUND[name]
  if own and UI.sfxId then UI.sfxId(own[1], own[2], own[3]) end
end
local function tween(instance, info, props)
  if Motion.reduced then
    for key, value in pairs(props) do instance[key] = value end
    return nil
  end
  local t = TS:Create(instance, info, props)
  t:Play()
  return t
end

-- ---------------------------------------------------------------- the letters
-- Gotham, as Novoline has it; Settings > Novoline font picks another.
local FONTS = {
  { "gotham", "Gotham", "rbxasset://fonts/families/GothamSSm.json", 1 },
  { "builder", "Builder Sans", "rbxasset://fonts/families/BuilderSans.json", 1.04 },
  { "montserrat", "Montserrat", "rbxasset://fonts/families/Montserrat.json", 0.98 },
  { "inter", "Inter", nil, 1 },
  { "ubuntu", "Ubuntu", "rbxasset://fonts/families/Ubuntu.json", 1.04 },
  { "nunito", "Nunito", "rbxasset://fonts/families/Nunito.json", 1.04 },
}
N.FONTS = FONTS
local family, factor = FONTS[1][3], 1
local function pickFont()
  local id = Config.get("app.novoline.font")
  local spec = FONTS[1]
  for _, entry in ipairs(FONTS) do if entry[1] == id then spec = entry end end
  family = spec[3] or ((B.F0 or B.F).text500 and (B.F0 or B.F).text500.Family) or FONTS[1][3]
  factor = spec[4]
end
local WEIGHTS = { regular = Enum.FontWeight.Regular, medium = Enum.FontWeight.Medium, bold = Enum.FontWeight.Bold, black = Enum.FontWeight.Heavy }
local faces = {}
local function face(weight)
  local key = family .. (weight or "medium")
  if not faces[key] then
    local ok, made = pcall(Font.new, family, WEIGHTS[weight or "medium"] or Enum.FontWeight.Medium)
    faces[key] = ok and made or Font.fromEnum(Enum.Font.GothamMedium)
  end
  return faces[key]
end
-- every text drawn here, kept STRONG and swept (weak tables lose labels that are still on screen)
local typed = {}
local function letters(item, size, weight)
  typed[item] = { size, weight or "medium" }
  item.FontFace = face(weight)
  item.TextSize = math.floor(size * factor + 0.5)
  return item
end
local function refont()
  pickFont()
  for item, spec in pairs(typed) do
    if item.Parent then
      item.FontFace = face(spec[2])
      item.TextSize = math.floor(spec[1] * factor + 0.5)
    else
      typed[item] = nil
    end
  end
end
function N.owns(item) return typed[item] ~= nil end
Motion.every(function() for item in pairs(typed) do if not item.Parent then typed[item] = nil end end end, 0.1, "novoline.sweep")

-- ---------------------------------------------------------------- the accent, kept on what wears it
local worn = {}
local function wear(instance, property)
  for _, entry in ipairs(worn) do if entry[1] == instance and entry[2] == property then instance[property] = accent(); return instance end end
  worn[#worn + 1] = { instance, property }
  instance[property] = accent()
  return instance
end
local function unwear(instance, property)
  for index = #worn, 1, -1 do
    local entry = worn[index]
    if entry[1] == instance and (property == nil or entry[2] == property) then table.remove(worn, index) end
  end
end
local function repaint()
  local color = accent()
  for index = #worn, 1, -1 do
    local entry = worn[index]
    if entry[1].Parent then entry[1][entry[2]] = color else table.remove(worn, index) end
  end
end

-- ---------------------------------------------------------------- pieces
local function box(parent, props)
  local frame = Instance.new("Frame")
  frame.BorderSizePixel = 0
  frame.BackgroundTransparency = 1
  if props then for key, value in pairs(props) do frame[key] = value end end
  frame.Parent = parent
  return frame
end
local function round(instance, radius)
  local corner = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
  corner.CornerRadius = radius == true and UDim.new(1, 0) or UDim.new(0, radius or 12)
  corner.Parent = instance
  return corner
end
local function rim(instance, color, transparency)
  local line = Instance.new("UIStroke")
  line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  line.Color = color or P.white
  line.Transparency = transparency or 0.9
  line.Thickness = 1
  line.Parent = instance
  return line
end
local function text(parent, value, size, weight, props)
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency, label.BorderSizePixel = 1, 0
  label.TextColor3 = P.text
  label.TextXAlignment = Enum.TextXAlignment.Left
  label.TextTruncate = Enum.TextTruncate.AtEnd
  label.Text = value or ""
  letters(label, size or 13, weight)
  if props then for key, v in pairs(props) do label[key] = v end end
  label.Parent = parent
  return label
end
local function entryBox(parent, size)
  local entry = Instance.new("TextBox")
  entry.BackgroundTransparency, entry.BorderSizePixel = 1, 0
  entry.TextColor3, entry.PlaceholderColor3 = P.text, P.faint
  entry.TextXAlignment, entry.ClearTextOnFocus, entry.ClipsDescendants = Enum.TextXAlignment.Left, false, true
  letters(entry, size or 13, "medium")
  entry.Parent = parent
  return entry
end
local function hit(parent, props)
  local button = Instance.new("TextButton")
  button.Text, button.AutoButtonColor, button.BackgroundTransparency, button.BorderSizePixel = "", false, 1, 0
  button.Size = UDim2.fromScale(1, 1)
  button.ZIndex = 8
  if props then for key, value in pairs(props) do button[key] = value end end
  button.Parent = parent
  return button
end
local function glyph(parent, name, size, color, props)
  local image = Instance.new("ImageLabel")
  image.BackgroundTransparency, image.BorderSizePixel = 1, 0
  image.Size = UDim2.fromOffset(size, size)
  image.ScaleType = Enum.ScaleType.Fit
  image.ImageColor3 = color or P.dim
  UI.setIcon(image, name)
  if props then for key, value in pairs(props) do image[key] = value end end
  image.Parent = parent
  return image
end
local function list(parent, gap, horizontal, align)
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, gap or 0)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  if align == "center" then
    if horizontal then layout.HorizontalAlignment = Enum.HorizontalAlignment.Center else layout.VerticalAlignment = Enum.VerticalAlignment.Center end
  end
  if horizontal then layout.VerticalAlignment = Enum.VerticalAlignment.Center end
  layout.Parent = parent
  return layout
end
local function pad(parent, top, right, bottom, left)
  local padding = Instance.new("UIPadding")
  padding.PaddingTop, padding.PaddingRight = UDim.new(0, top or 0), UDim.new(0, right or top or 0)
  padding.PaddingBottom, padding.PaddingLeft = UDim.new(0, bottom or top or 0), UDim.new(0, left or right or top or 0)
  padding.Parent = parent
  return padding
end
-- Novoline's glass: the near-black gradient, the rim lit at top and bottom, a shadow under it
local function glass(frame, radius, shadow)
  frame.BackgroundColor3 = P.white
  frame.BackgroundTransparency = 0
  round(frame, radius)
  local body = Instance.new("UIGradient")
  body.Name = "Body"
  body.Rotation = 90
  body.Color = ColorSequence.new(P.top, P.bottom)
  body.Parent = frame
  local line = rim(frame, P.white, 0)
  pcall(function() line.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
  local light = Instance.new("UIGradient")
  light.Rotation = 90
  light.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.5, 0.92), NumberSequenceKeypoint.new(1, 0.78) })
  light.Parent = line
  if shadow ~= false then
    pcall(function()
      local glow = Instance.new("UIShadow")
      glow.Color = P.black
      glow.BlurRadius = UDim.new(0, 26)
      glow.Offset = UDim2.fromOffset(0, 10)
      glow.Transparency = 0.45
      glow.ZIndex = -1
      glow.Parent = frame
    end)
  end
  return line
end
N.glass = glass
-- Novoline's soft button: a dark gradient (46,46,49 to 32,32,35), a rim lit at the top, a lift under the mouse
function N.softFace(holder, radius, hover)
  local face0 = box(holder, { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = holder.ZIndex + 1 })
  round(face0, radius or 16)
  local body = Instance.new("UIGradient"); body.Rotation = 90; body.Color = ColorSequence.new(rgb(46, 46, 49), rgb(32, 32, 35)); body.Parent = face0
  local line = rim(face0, P.white, 0)
  pcall(function() line.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
  local light = Instance.new("UIGradient"); light.Rotation = 90
  light.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 0.97) })
  light.Parent = line
  local lift = box(face0, { Name = "Lift", Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.white, BackgroundTransparency = 1, ZIndex = face0.ZIndex + 1 })
  round(lift, radius or 16)
  if hover then
    face0.MouseEnter:Connect(function() tween(lift, HOVER_INFO, { BackgroundTransparency = 0.95 }) end)
    face0.MouseLeave:Connect(function() tween(lift, HOVER_INFO, { BackgroundTransparency = 1 }) end)
  end
  return face0, lift
end
-- Novoline's tile: the soft button's plate without the lift (a key, an "Open", a value), its rim faint
local function tile(parent, props, radius)
  local plate = box(parent, props)
  plate.BackgroundColor3, plate.BackgroundTransparency = P.white, 0
  round(plate, radius or 14)
  local body = Instance.new("UIGradient"); body.Name = "Body"; body.Rotation = 90; body.Color = ColorSequence.new(rgb(46, 46, 49), rgb(32, 32, 35)); body.Parent = plate
  rim(plate, P.white, 0.9)
  return plate, body
end
N.tile = tile
local function lower(value) return string.lower(tostring(value or "")) end
-- a name that would be cut short on a tile shrinks to fit instead (down to `least`), measured in
-- design px (TextScaled would measure it after the look's own scale, and come out small)
local function shrink(label, most, least, width)
  local function fit()
    local room = width or ((label.Size.X.Scale == 0) and label.Size.X.Offset) or 0
    if room <= 0 then return end
    local weight = label.FontFace and label.FontFace.Weight
    local heavy = weight ~= nil and weight.Value >= Enum.FontWeight.Bold.Value
    local enum = heavy and Enum.Font.GothamBold or Enum.Font.GothamMedium
    local size = most
    while size > (least or 9) do
      local ok, bounds = pcall(S.TextService.GetTextSize, S.TextService, label.Text, size, enum, Vector2.new(4000, 200))
      -- (the look's letters set a little wider than the measure's: kept a tenth short)
      if not ok or bounds.X <= room * 0.9 then break end
      size -= 1
    end
    label.TextSize = size
    return size
  end
  local size = fit()
  label:GetPropertyChangedSignal("Text"):Connect(fit)
  return label, size
end
local function options(spec)
  local out = {}
  for _, option in ipairs(spec or {}) do
    if type(option) == "table" then out[#out + 1] = { value = option.value or option[1], label = option.label or option[2] or tostring(option.value or option[1]) }
    else out[#out + 1] = { value = option, label = tostring(option) } end
  end
  return out
end

-- ---------------------------------------------------------------- the kit (src/07): tabs that draw themselves, in this look
local KIT = { card = P.card, field = P.raised, hover = P.hover, line = P.line, back = rgb(18, 18, 20), text = P.text, dim = P.dim, faint = P.faint,
  onAccent = P.white, good = P.good, bad = P.danger }
local kit = { look = "novoline", radius = 16, small = 10, size = 13 }
function kit.owns(frame) return N.gui ~= nil and frame:IsDescendantOf(N.gui) end
function kit.color(role)
  if role == "accent" then return accent(), 0 end
  return KIT[role] or P.text, 0
end
function kit.paint(instance, property, role)
  unwear(instance, property)
  if role == "accent" then wear(instance, property) else instance[property] = KIT[role] or P.text end
end
function kit.fill(instance, role)
  kit.paint(instance, "BackgroundColor3", role)
  instance.BackgroundTransparency = 0
end
function kit.clear(instance) instance.BackgroundTransparency = 1 end
function kit.font(bold) return face(bold and "bold" or "medium") end
function kit.text(parent, value, props, bold, size) return text(parent, value, size or 13, bold and "bold" or "medium", props) end
function kit.entry(parent, size) return entryBox(parent, size or 13) end
function kit.outline(frame) return rim(frame, P.line, 0.2) end
function kit.corner(frame, radius) return round(frame, radius or 16) end
N.kit = kit
Window.kits.novoline = kit
function N.palette() return { card = P.card, elevated = P.raised, stroke = P.line, text = P.text, dim = P.dim, faint = P.faint, accent = accent(), font = face("medium"), bold = face("bold") } end

-- ---------------------------------------------------------------- floating bits: a tip, a menu (in the overlay layer, above the panel)
local overlay
local tip, tipFor
local function hideTip()
  tipFor = nil
  if tip then tip.Visible = false end
  if UI.hideTip then UI.hideTip() end
end
-- What a control does, on hover (2026-10-30, every look): the hub's one tip, its name over what it
-- does. A row with no words of its own still says its name when the row cuts it short.
local function tooltip(button, desc, holder, title)
  if desc and desc ~= "" and UI.tooltip then
    UI.tooltip(button, desc, title)
    return
  end
  if (not desc or desc == "") and not holder then return end
  button.MouseEnter:Connect(function()
    tipFor = button
    task.delay(0.5, function()
      if tipFor ~= button or not (N.open and button.Parent and overlay) then return end
      local say = desc
      if holder then
        local cutName, cutDesc
        for _, child in ipairs(holder:GetChildren()) do
          if child:IsA("TextLabel") and child.Text ~= "" and not child.TextFits then
            if desc and child.Text == desc then cutDesc = true else cutName = child.Text end
          end
        end
        if not (cutName or cutDesc) then return end
        say = cutName and ((desc and desc ~= "") and (cutName .. ": " .. desc) or cutName) or desc
      end
      if not say or say == "" then return end
      tip.Text = say
      local scale = N.sizer and N.sizer.Scale or 1
      local at = button.AbsolutePosition - overlay.AbsolutePosition
      tip.Position = UDim2.fromOffset(at.X + 6 * scale, at.Y + button.AbsoluteSize.Y + 4)
      tip.Visible = true
      task.defer(function()
        if tipFor ~= button or not tip.Visible then return end
        local view = overlay.AbsoluteSize
        local size = tip.AbsoluteSize
        local x, y = tip.Position.X.Offset, tip.Position.Y.Offset
        if x + size.X > view.X - 8 then x = view.X - 8 - size.X end
        if y + size.Y > view.Y - 8 then y = at.Y - size.Y - 4 end
        tip.Position = UDim2.fromOffset(math.max(x, 8), math.max(y, 8))
      end)
    end)
  end)
  button.MouseLeave:Connect(function() if tipFor == button then hideTip() end end)
end
local menu
local function closeMenu()
  if menu then
    local open = menu
    menu = nil
    open.frame:Destroy()
  end
end
-- items: { label, icon?, checked?, danger?, run } | "divider"; at = a screen point, or under `anchor`
local function openMenu(items, at, anchor)
  closeMenu()
  hideTip()
  if not overlay then return end
  local scale = N.sizer and N.sizer.Scale or 1
  local frame = box(overlay, { Name = "Menu", Size = UDim2.fromOffset(210, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 90 })
  glass(frame, 14)
  local sizer = Instance.new("UIScale"); sizer.Scale = scale; sizer.Parent = frame
  local body = box(frame, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 91 })
  pad(body, 6)
  list(body, 2)
  for index, item in ipairs(items) do
    if item == "divider" then
      box(body, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = P.divider, BackgroundTransparency = 0, LayoutOrder = index, ZIndex = 92 })
    else
      local row = box(body, { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = P.white, BackgroundTransparency = 1, LayoutOrder = index, ZIndex = 92 })
      round(row, 9)
      local x = 10
      if item.icon then
        glyph(row, item.icon, 15, item.danger and P.danger or P.dim, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 93 })
        x = 33
      end
      text(row, item.label, 13, "medium", { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 28, 1, 0), TextColor3 = item.danger and P.danger or P.text, ZIndex = 93 })
      if item.checked then
        wear(glyph(row, "check", 14, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 93 }), "ImageColor3")
      end
      local button = hit(row, { ZIndex = 94 })
      button.MouseEnter:Connect(function() tween(row, HOVER_INFO, { BackgroundTransparency = 0.93 }) end)
      button.MouseLeave:Connect(function() tween(row, HOVER_INFO, { BackgroundTransparency = 1 }) end)
      button.Activated:Connect(B.safe("novoline.menu", function()
        UI.sfx("click", 0.5)
        if not item.keepOpen then closeMenu() end
        if item.run then item.run() end
      end))
    end
  end
  -- (placed once its height is known: kept on screen)
  local function place()
    local view = overlay.AbsoluteSize
    local size = frame.AbsoluteSize
    local p
    if anchor then
      local a = anchor.AbsolutePosition - overlay.AbsolutePosition
      p = Vector2.new(a.X + anchor.AbsoluteSize.X - size.X, a.Y + anchor.AbsoluteSize.Y + 4)
      if p.Y + size.Y > view.Y - 8 then p = Vector2.new(p.X, a.Y - size.Y - 4) end
    else
      p = (at or UI.mouse()) - overlay.AbsolutePosition + Vector2.new(2, 2)
    end
    frame.Position = UDim2.fromOffset(math.clamp(p.X, 8, math.max(8, view.X - size.X - 8)), math.clamp(p.Y, 8, math.max(8, view.Y - size.Y - 8)))
  end
  place()
  task.defer(place)
  menu = { frame = frame, anchor = anchor }
  UI.sfx("open", 0.4)
  return frame
end
function kit.menu(anchor, items) return openMenu(items, nil, anchor) end
N.menu = openMenu

-- ---------------------------------------------------------------- an open list, a colour: they open in place, under their row
local unfolded                           -- { frame, anchor, scroller, close }
local function fold()
  if unfolded then
    local open = unfolded
    unfolded = nil
    if open.scroller and open.scroller.Parent then open.scroller.ScrollingEnabled = true end
    if open.close then B.try("novoline.fold", open.close) end
    open.frame:Destroy()
  end
end
N.fold = fold
local function pageScroller(frame)
  for _, entry in pairs(N.pages) do
    if entry.scroller and frame:IsDescendantOf(entry.scroller) then return entry.scroller end
  end
  return nil
end
-- the frame given takes the place under `row`; the page holds still while it is open
local function unfold(row, frame, closed)
  fold()
  local scroller = pageScroller(row)
  if scroller then scroller.ScrollingEnabled = false end
  unfolded = { frame = frame, anchor = row, scroller = scroller, close = closed }
end

-- ---------------------------------------------------------------- keys on a control (right click)
local function keyMenu(id, label, kind)
  if not id then return end
  local bind = Config.bindOf(id)
  local items = {
    { label = bind and bind.key and ("Change key (" .. Config.keyLabel(bind.key) .. ")") or "Bind a key", icon = "keyboard", run = function()
      Window.toast({ title = "Press a key", text = "Esc: cancel. Backspace: clear.", icon = "keyboard", time = 2.2 })
      Controls.captureKey(function(key, cancelled)
        if cancelled then return end
        Config.bind(id, key)
        Window.toast({ title = key and ("Bound to " .. Config.keyLabel(key)) or "Key cleared", text = label, icon = "keyboard", time = 2 })
      end)
    end },
  }
  if bind and bind.key then
    if kind == "toggle" then
      items[#items + 1] = { label = "Hold to use", icon = "hand", checked = bind.mode == "hold", run = function()
        Config.bind(id, bind.key, bind.mode == "hold" and "toggle" or "hold")
      end }
    end
    items[#items + 1] = { label = "Clear the key", icon = "x", run = function() Config.bind(id, nil) end }
  end
  if Config.get(id) ~= nil and kind ~= "button" then
    items[#items + 1] = "divider"
    items[#items + 1] = { label = "Back to default", icon = "rotate-ccw", run = function() Config.reset(id) end }
  end
  openMenu(items)
end
-- the small pill that shows a control's key
local function keyChip(parent, id)
  local chip = box(parent, { Name = "Key", AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = P.raised,
    BackgroundTransparency = 0, Visible = false, ZIndex = 6 })
  round(chip, true)
  pad(chip, 0, 8, 0, 8)
  local label = text(chip, "", 10, "bold", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = P.sub, ZIndex = 7 })
  local function refresh()
    local bind = id and Config.bindOf(id)
    chip.Visible = bind ~= nil and bind.key ~= nil
    if chip.Visible then label.Text = Config.keyLabel(bind.key) .. (bind.mode == "hold" and " · hold" or "") end
  end
  if id then Config.bindsChanged:connect(function(changed) if changed == id and chip.Parent then refresh() end end) end
  refresh()
  return chip, refresh
end

-- ---------------------------------------------------------------- a card and its controls
local Section = {}
Section.__index = Section
local function nextOrder(section)
  section.count += 2
  return section.count
end
-- a row of a group: Novoline's (14 in from the left, 12 from the right, a hairline over every row
-- but the first, the whole row lit faintly under the mouse)
local function row(section, height)
  local order = nextOrder(section)
  local line = box(section.body, { Name = "Row", Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, BackgroundColor3 = P.white, BackgroundTransparency = 1 })
  round(line, 12)
  pad(line, 0, 12, 0, 14)
  section.made = (section.made or 0) + 1
  if section.made > 1 then
    box(line, { Name = "Line", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -2, 0, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0.93, ZIndex = 2 })
  end
  return line
end
local function sub(section, holder)
  return setmetatable({ body = holder, count = 0, made = 0, page = section.page, card = section.card, wide = section.wide, icon = section.icon }, Section)
end
local function findable(section, frame, label, desc)
  local page = section.page
  if not (page and page.rows) then return end
  page.rows[#page.rows + 1] = { frame = frame, card = section.card, text = lower(tostring(label or "") .. " " .. tostring(desc or "")) }
end
-- a name and its one line under it (Novoline's: bold 13 at 11, the line 11 at 30); `right` is how much
-- of the row the control takes. A row with no line under it is 40 tall and its name is centred.
-- A row's line that is too long for it ends at its first full stop, whole ("Hops round your
-- target."), not cut in the next sentence ("Hops round your target...."): the tip on hover has all
-- of it (2026-10-30). Measured in the row's own width, whatever the look's scale is just then.
local function firstSentence(under, desc)
  local first = string.match(desc, "^(.-[%.!?])%s+%S")
  if not first then return end
  local lastRoom
  local function fit()
    if not under.Parent then return end
    local scale, node = 1, under
    while node do
      local sizer = node:FindFirstChildOfClass("UIScale")
      if sizer then scale *= sizer.Scale end
      node = node.Parent
    end
    if scale <= 0.01 then return end
    local room = math.floor(under.AbsoluteSize.X / scale + 0.5)
    if room <= 0 or room == lastRoom then return end
    lastRoom = room
    local ok, whole = pcall(S.TextService.GetTextSize, S.TextService, desc, 11, Enum.Font.GothamMedium, Vector2.new(4000, 100))
    -- (the look's letters set a little wider than the measure's: kept a tenth short, as in shrink)
    under.Text = (ok and whole.X > room * 0.9) and first or desc
  end
  under:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
  task.defer(fit)
end
local function labels(line, label, desc, right)
  local h = line.Size.Y.Offset
  local name = text(line, label or "", 13, "bold", { Position = UDim2.fromOffset(0, desc and 11 or 0), Size = UDim2.new(1, -(right or 60), 0, desc and 16 or h),
    TextColor3 = P.text, ZIndex = 3 })
  local under
  if desc and desc ~= "" then
    under = text(line, desc, 11, "medium", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -(right or 60), 0, 14), TextColor3 = P.subtle, ZIndex = 3 })
    firstSentence(under, desc)
  end
  return name, under
end
-- the row lights up a little under the mouse (Novoline's: the row itself, to 0.96)
local function washed(line)
  return function(on) tween(line, HOVER_INFO, { BackgroundTransparency = on and 0.96 or 1 }) end
end

-- Novoline's glass switch: a clear track (white at 0.86) that fills white (0.25) when on, and a
-- white pill knob with a soft shadow that glides across (0.3 s quart out)
local function switch(parent)
  local track = box(parent, { Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(52, 26),
    BackgroundColor3 = P.white, BackgroundTransparency = 0.86, ZIndex = 4 })
  round(track, true)
  local fill = box(track, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.white, BackgroundTransparency = 1, ZIndex = 4 })
  round(fill, true)
  local knob = box(track, { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(32, 22), BackgroundColor3 = P.white,
    BackgroundTransparency = 0, ZIndex = 5 })
  round(knob, true)
  pcall(function()
    local shade = Instance.new("UIShadow")
    shade.Color, shade.BlurRadius, shade.Offset, shade.Transparency = P.black, UDim.new(0, 6), UDim2.fromOffset(0, 1), 0.62
    shade.Parent = knob
  end)
  local function set(on, animate)
    local spot = UDim2.new(0, on and 34 or 18, 0.5, 0)
    if animate then
      tween(knob, GLIDE, { Position = spot })
      tween(fill, FILL_INFO, { BackgroundTransparency = on and 0.25 or 1 })
    else
      knob.Position = spot
      fill.BackgroundTransparency = on and 0.25 or 1
    end
  end
  return track, set
end

function Section:toggle(spec)
  local id = spec.id
  local bindable = spec.bindable ~= false
  local value = id and Config.define(id, spec.default == true) or (spec.default == true)
  local desc = spec.desc
  local line = row(self, desc and ROW_H or COMPACT_H)
  findable(self, line, spec.label, desc)
  local hover = washed(line)
  local label = labels(line, spec.label, desc, 120)
  local track, set = switch(line)
  local chip = keyChip(line, id)
  chip.Position = UDim2.new(1, -60, 0.5, 0)
  local children
  if spec.children then
    local order = nextOrder(self)
    children = box(self.body, { Name = "Sub", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Visible = value })
    local edge = box(children, { Size = UDim2.new(0, 2, 1, -8), Position = UDim2.fromOffset(16, 4), BackgroundColor3 = P.white, BackgroundTransparency = 0.88 })
    round(edge, true)
    local inner = box(children, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    pad(inner, 0, 0, 4, 16)
    list(inner, 0)
    B.try("novoline.children", spec.children, sub(self, inner))
  end
  local function paint(animate)
    set(value, animate)
    if children then children.Visible = value end
  end
  paint(false)
  if id then
    Config.on(id, function(next)
      value = next == true
      if line.Parent then paint(true) end
      if spec.changed then spec.changed(value) end
    end)
    if bindable then Controls.bindables[id] = Controls.bindables[id] or { label = spec.label or id, kind = "toggle", page = self.page.source } end
    -- (a tab's first switches are its quick settings)
    if self.top and self.page.toggles then self.page.toggles[#self.page.toggles + 1] = { id = id, label = spec.label or id, icon = self.icon } end
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true) end)
  button.MouseLeave:Connect(function() hover(false) end)
  button.Activated:Connect(B.safe("novoline.toggle", function()
    UI.sfx(value and "toggle_off" or "toggle_on", 0.5)
    if id then Config.set(id, not value) else
      value = not value
      paint(true)
      if spec.changed then B.try("toggle", spec.changed, value) end
    end
  end))
  button.MouseButton2Click:Connect(function() if bindable and id then keyMenu(id, spec.label, "toggle") end end)
  tooltip(button, spec.tip or desc, line, spec.label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = function(next) if id then Config.set(id, next == true) end end,
    open = function() end, track = track }
end

function Section:slider(spec)
  local id = spec.id
  local min, max, step = spec.min or 0, spec.max or 100, spec.step or 1
  local decimals = spec.decimals or (step < 1 and math.max(0, math.ceil(-math.log10(step))) or 0)
  local curve = spec.curve or 1
  local value = id and Config.define(id, spec.default or min) or (spec.default or min)
  local desc = spec.desc
  -- Novoline's glass slider: the name and the amount on one line, a clear track (white at 0.88, 10
  -- tall) under them that fills toward its white pill thumb (30 x 18, a soft shadow; held, it grows
  -- to 36 x 20 and clears to glass)
  local line = row(self, desc and 76 or 60)
  findable(self, line, spec.label, desc)
  local hover = washed(line)
  local label = labels(line, spec.label, desc, 90)
  label.Size = UDim2.new(1, -90, 0, 16)
  label.Position = UDim2.fromOffset(0, 11)
  local amount = text(line, "", 12, "bold", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 11), Size = UDim2.fromOffset(86, 16),
    TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = P.text, ZIndex = 3 })
  local rail = box(line, { Name = "Track", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = P.white,
    BackgroundTransparency = 0.88, ZIndex = 3 })
  round(rail, true)
  local fill = box(rail, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 4 })
  round(fill, true)
  local sheen = Instance.new("UIGradient")
  sheen.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 0) })
  sheen.Parent = fill
  local knob = box(rail, { Name = "Thumb", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(30, 18), BackgroundColor3 = P.white,
    BackgroundTransparency = 0, ZIndex = 5 })
  round(knob, true)
  local knobRim = rim(knob, P.white, 1)
  pcall(function()
    local shade = Instance.new("UIShadow")
    shade.Color, shade.BlurRadius, shade.Offset, shade.Transparency = P.black, UDim.new(0, 8), UDim2.fromOffset(0, 2), 0.62
    shade.Parent = knob
  end)
  local HOLD = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
  local function held(on)
    tween(knob, HOLD, { Size = on and UDim2.fromOffset(36, 20) or UDim2.fromOffset(30, 18), BackgroundTransparency = on and 0.72 or 0 })
    tween(knobRim, HOLD, { Transparency = on and 0.3 or 1 })
  end
  local function shown(v) return (spec.format and spec.format(v)) or (util.format(v, decimals) .. (spec.suffix or "")) end
  -- (the thumb stays inside the track: its centre runs from 15 px in to 15 px short of the end)
  local function place(animate)
    local f = util.clamp01((value - min) / math.max(max - min, 1e-9)) ^ (1 / curve)
    local at = UDim2.new(f, 15 - f * 30, 0.5, 0)
    local filled = UDim2.new(f, 15 - f * 30, 1, 0)
    if animate then
      tween(fill, HOVER_INFO, { Size = filled })
      tween(knob, HOVER_INFO, { Position = at })
    else
      fill.Size = filled
      knob.Position = at
    end
    amount.Text = shown(value)
  end
  place(false)
  local dragging = false
  local function set(next)
    next = math.clamp(util.round(next, step), min, max)
    if decimals > 0 then next = tonumber(string.format("%." .. decimals .. "f", next)) or next end
    if next == value then return end
    if id then Config.set(id, next) else
      value = next
      place(not dragging)
      if spec.changed then B.try("slider", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if line.Parent then place(not dragging) end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true) end)
  button.MouseLeave:Connect(function() hover(false) end)
  local function at(point)
    local width = math.max(rail.AbsoluteSize.X - 30 * (N.sizer and N.sizer.Scale or 1), 1)
    set(min + util.clamp01((point.X - rail.AbsolutePosition.X - 15 * (N.sizer and N.sizer.Scale or 1)) / width) ^ curve * (max - min))
  end
  UI.drag(button, function(point) dragging = true; held(true); at(point) end, function(point) at(point) end, function() dragging = false; held(false) end)
  -- (right click: type a number)
  button.MouseButton2Click:Connect(function()
    local field = box(line, { Size = UDim2.new(0, 120, 0, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), BackgroundColor3 = P.white,
      BackgroundTransparency = 0.94, ZIndex = 12 })
    round(field, 10)
    rim(field, P.white, 0.7)
    local entry = entryBox(field, 12)
    entry.Size, entry.Position, entry.ZIndex = UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 13
    entry.TextXAlignment = Enum.TextXAlignment.Center
    entry.Text, entry.ClearTextOnFocus, entry.PlaceholderText = "", true, "type a number"
    entry.FocusLost:Connect(B.safe("novoline.slider.type", function()
      local typed = tonumber((string.gsub(entry.Text, "[^%d%.%-eE]", "")))
      field:Destroy()
      if typed then set(typed) end
    end))
    entry:CaptureFocus()
  end)
  tooltip(button, spec.tip or desc, line, spec.label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = set }
end

-- a list that opens in place under its row: one value (dropdown) or several (multi)
local function chooser(section, spec, many)
  local id = spec.id
  local choices = options(spec.options)
  local first = choices[1] and choices[1].value
  local value
  if many then value = id and Config.define(id, spec.default or {}) or (spec.default or {})
  else value = id and Config.define(id, spec.default ~= nil and spec.default or first) or (spec.default ~= nil and spec.default or first) end
  local desc = spec.desc
  local line = row(section, desc and ROW_H or COMPACT_H)
  findable(section, line, spec.label, desc)
  local hover = washed(line)
  local label = labels(line, spec.label, desc, 140)
  -- (the value on Novoline's tile, its arrow beside it)
  local field = tile(line, { Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(128, 28), ZIndex = 4 }, 14)
  local fieldRim = field:FindFirstChildOfClass("UIStroke")
  local shown = text(field, "", 12, "bold", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -34, 1, -12), TextColor3 = P.text, ZIndex = 5 })
  shrink(shown, 12, 9, 94)
  local arrow = glyph(field, "chevron-down", 14, P.subtle, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 5 })
  local function has(v) return table.find(value, v) ~= nil end
  local function summary()
    if not many then
      for _, option in ipairs(choices) do if option.value == value then return option.label end end
      return tostring(value)
    end
    if #value == 0 then return spec.empty or "None" end
    local names = {}
    for _, option in ipairs(choices) do if has(option.value) then names[#names + 1] = option.label end end
    return table.concat(names, ", ")
  end
  shown.Text = summary()
  local function set(next)
    if id then Config.set(id, next) else
      value = next
      shown.Text = summary()
      if spec.changed then B.try("chooser", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if shown.Parent then shown.Text = summary() end
      if spec.changed then spec.changed(next) end
    end)
  end
  local open = false
  local function openList()
    local rows = math.min(#choices, 7)
    local order = line.LayoutOrder + 1
    local holder = box(section.body, { Name = "List", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order, ClipsDescendants = true, ZIndex = 6 })
    local panel = box(holder, { Size = UDim2.new(1, -24, 0, rows * 30 + 8), Position = UDim2.fromOffset(12, 0), BackgroundColor3 = rgb(30, 30, 34), BackgroundTransparency = 0, ZIndex = 6 })
    round(panel, 12)
    rim(panel, P.white, 0.92)
    local scroller = Instance.new("ScrollingFrame")
    scroller.BackgroundTransparency, scroller.BorderSizePixel = 1, 0
    scroller.Position, scroller.Size = UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8)
    scroller.CanvasSize = UDim2.fromOffset(0, #choices * 30)
    scroller.ScrollBarThickness = #choices > rows and 3 or 0
    scroller.ScrollBarImageColor3 = P.line
    scroller.ScrollingDirection = Enum.ScrollingDirection.Y
    scroller.ZIndex = 7
    scroller.Parent = panel
    for index, option in ipairs(choices) do
      local item = box(scroller, { Position = UDim2.fromOffset(0, (index - 1) * 30), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = P.white, BackgroundTransparency = 1, ZIndex = 8 })
      round(item, 9)
      local picked = many and has(option.value) or option.value == value
      local name = text(item, option.label, 12, picked and "bold" or "medium", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -40, 1, 0),
        TextColor3 = picked and P.text or P.sub, ZIndex = 9 })
      local check = glyph(item, "check", 14, nil, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 9, Visible = picked })
      wear(check, "ImageColor3")
      local button = hit(item, { ZIndex = 10 })
      button.MouseEnter:Connect(function() tween(item, HOVER_INFO, { BackgroundTransparency = 0.94 }) end)
      button.MouseLeave:Connect(function() tween(item, HOVER_INFO, { BackgroundTransparency = 1 }) end)
      button.Activated:Connect(B.safe("novoline.choose", function()
        UI.sfx("click", 0.4)
        if not many then
          set(option.value)
          fold()
          return
        end
        local next = table.clone(value)
        local at = table.find(next, option.value)
        if at then table.remove(next, at) else next[#next + 1] = option.value end
        local ordered = {}
        for _, o in ipairs(choices) do if table.find(next, o.value) then ordered[#ordered + 1] = o.value end end
        set(ordered)
        local on = at == nil
        check.Visible = on
        name.TextColor3 = on and P.text or P.sub
        name.FontFace = face(on and "bold" or "medium")
      end))
    end
    -- (it opens to its height: the card grows under it)
    local tall = rows * 30 + 8 + 6
    tween(holder, OPEN_INFO, { Size = UDim2.new(1, 0, 0, tall) })
    tween(arrow, HOVER_INFO, { Rotation = 180 })
    open = true
    unfold(line, holder, function()
      open = false
      if arrow.Parent then tween(arrow, HOVER_INFO, { Rotation = 0 }) end
    end)
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true); if fieldRim then tween(fieldRim, HOVER_INFO, { Transparency = 0.78 }) end end)
  button.MouseLeave:Connect(function() hover(false); if fieldRim then tween(fieldRim, HOVER_INFO, { Transparency = 0.9 }) end end)
  button.Activated:Connect(B.safe("novoline.dropdown", function()
    UI.sfx("click", 0.4)
    if open then fold() else openList() end
  end))
  tooltip(button, spec.tip or desc, line, spec.label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = set, has = has,
    options = function(next) choices = options(next); shown.Text = summary() end,
    show = function(next) value = next; if shown.Parent then shown.Text = summary() end end }
end
function Section:dropdown(spec) return chooser(self, spec, false) end
function Section:multi(spec) return chooser(self, spec, true) end
-- a few short choices: a pill bar with the chosen one lit (more, or long ones: a list)
-- a few short choices: Novoline's chips (soft tiles, the chosen one white with dark letters), at the
-- right of the row when they fit beside its name, else on a line of their own under it; more than
-- fit on a line: a list
function Section:segmented(spec)
  local choices = options(spec.options)
  if #choices > 5 then return chooser(self, spec, false) end
  local width = self.wide and 514 or 290
  local widths, total = {}, 0
  for i, option in ipairs(choices) do
    local ok, size = pcall(S.TextService.GetTextSize, S.TextService, option.label, 12, Enum.Font.GothamBold, Vector2.new(300, 28))
    widths[i] = (ok and size.X or #option.label * 7) + 28
    total += widths[i] + (i > 1 and 6 or 0)
  end
  if total > width then return chooser(self, spec, false) end
  local id = spec.id
  local value = id and Config.define(id, spec.default ~= nil and spec.default or choices[1].value) or (spec.default ~= nil and spec.default or choices[1].value)
  local desc = spec.desc
  local inline = total <= width - 100
  local line = row(self, inline and (desc and ROW_H or COMPACT_H) or ((desc and ROW_H or 40) + 36))
  tooltip(line, spec.tip or desc, nil, spec.label)
  findable(self, line, spec.label, desc)
  local label = labels(line, spec.label, desc, inline and (total + 10) or 0)
  if not inline and not desc then label.Size = UDim2.new(1, 0, 0, 40) end
  local holder = box(line, { Name = "Chips", AnchorPoint = inline and Vector2.new(1, 0.5) or Vector2.new(0, 1), Position = inline and UDim2.new(1, 0, 0.5, 0) or UDim2.new(0, 0, 1, -8),
    Size = UDim2.fromOffset(total, 28), ZIndex = 4 })
  local chips = {}
  local x = 0
  local function paint()
    for i, option in ipairs(choices) do
      local on = option.value == value
      local c = chips[i]
      c.body.Enabled = not on
      c.plate.BackgroundColor3 = on and P.on or P.white
      c.name.TextColor3 = on and P.ink or P.text
    end
  end
  for i, option in ipairs(choices) do
    local plate, body = tile(holder, { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(widths[i], 28), ZIndex = 5 }, 14)
    local name = text(plate, option.label, 12, "bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
    chips[i] = { plate = plate, body = body, name = name }
    local press = Instance.new("UIScale"); press.Parent = plate
    local button = hit(plate, { ZIndex = 7 })
    button.MouseButton1Down:Connect(function() tween(press, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }) end)
    button.MouseButton1Up:Connect(function() tween(press, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) end)
    button.MouseLeave:Connect(function() tween(press, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) end)
    button.Activated:Connect(B.safe("novoline.segment", function()
      UI.sfx("tab", 0.4)
      if id then Config.set(id, option.value) else
        value = option.value
        paint()
        if spec.changed then B.try("segmented", spec.changed, value) end
      end
    end))
    x += widths[i] + 6
  end
  paint()
  if id then
    Config.on(id, function(next)
      value = next
      if holder.Parent then paint() end
      if spec.changed then spec.changed(next) end
    end)
  end
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = function(next) if id then Config.set(id, next) end end,
    options = function() end, show = function(next) value = next; if holder.Parent then paint() end end }
end

-- a colour: a dot; the square and the hue strip open in place
function Section:color(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or Color3.new(1, 1, 1)) or (spec.default or Color3.new(1, 1, 1))
  local desc = spec.desc
  local line = row(self, desc and ROW_H or COMPACT_H)
  tooltip(line, spec.tip or desc, nil, spec.label)
  findable(self, line, spec.label, desc)
  local hover = washed(line)
  local label = labels(line, spec.label, desc, 80)
  local swatch = box(line, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(44, 24), BackgroundColor3 = value,
    BackgroundTransparency = 0, ZIndex = 4 })
  round(swatch, true)
  rim(swatch, P.white, 0.75)
  local function set(next)
    if id then Config.set(id, next) else value = next; swatch.BackgroundColor3 = next; if spec.changed then spec.changed(next) end end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if swatch.Parent then swatch.BackgroundColor3 = next end
      if spec.changed then spec.changed(next) end
    end)
  end
  local open = false
  local function openPicker()
    local h, s, v = value:ToHSV()
    local holder = box(self.body, { Name = "Colour", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = line.LayoutOrder + 1, ClipsDescendants = true, ZIndex = 6 })
    local panel = box(holder, { Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = P.raised, BackgroundTransparency = 0, ZIndex = 6 })
    round(panel, 12)
    local square = box(panel, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 118), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BackgroundTransparency = 0, ZIndex = 7 })
    round(square, 8)
    local whiteLayer = box(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 8 })
    round(whiteLayer, 8)
    local across = Instance.new("UIGradient"); across.Transparency = NumberSequence.new(0, 1); across.Parent = whiteLayer
    local blackLayer = box(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.black, BackgroundTransparency = 0, ZIndex = 9 })
    round(blackLayer, 8)
    local down = Instance.new("UIGradient"); down.Rotation = 90; down.Transparency = NumberSequence.new(1, 0); down.Parent = blackLayer
    local dot = box(square, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 11 })
    round(dot, true)
    rim(dot, P.black, 0.4)
    local hueBar = box(panel, { Position = UDim2.fromOffset(10, 138), Size = UDim2.new(1, -96, 0, 12), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 7 })
    round(hueBar, true)
    local stops = {}
    for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
    local rainbow = Instance.new("UIGradient"); rainbow.Color = ColorSequence.new(stops); rainbow.Parent = hueBar
    local mark = box(hueBar, { Size = UDim2.fromOffset(6, 16), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 9 })
    round(mark, true)
    local hexField = box(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 133), Size = UDim2.fromOffset(78, 22), BackgroundColor3 = P.hover,
      BackgroundTransparency = 0, ZIndex = 7 })
    round(hexField, true)
    local hex = entryBox(hexField, 11)
    hex.Size, hex.Position, hex.ZIndex = UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 8
    hex.TextXAlignment = Enum.TextXAlignment.Center
    local function show()
      square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
      dot.Position = UDim2.fromScale(s, 1 - v)
      mark.Position = UDim2.fromScale(h, 0.5)
      if not hex:IsFocused() then hex.Text = "#" .. string.upper(Color3.fromHSV(h, s, v):ToHex()) end
    end
    show()
    local function emit() show(); set(Color3.fromHSV(h, s, v)) end
    local squareHit = hit(square, { ZIndex = 12 })
    local function pickSquare(point)
      s = util.clamp01((point.X - square.AbsolutePosition.X) / square.AbsoluteSize.X)
      v = 1 - util.clamp01((point.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y)
      emit()
    end
    UI.drag(squareHit, pickSquare, pickSquare)
    local hueHit = hit(hueBar, { ZIndex = 12, Size = UDim2.new(1, 0, 1, 10), Position = UDim2.fromOffset(0, -5) })
    local function pickHue(point) h = util.clamp01((point.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X); emit() end
    UI.drag(hueHit, pickHue, pickHue)
    hex.FocusLost:Connect(function()
      local ok, color = pcall(Color3.fromHex, (string.gsub(hex.Text, "[^%x]", "")))
      if ok and color then h, s, v = color:ToHSV(); emit() else show() end
    end)
    tween(holder, OPEN_INFO, { Size = UDim2.new(1, 0, 0, 182) })
    open = true
    unfold(line, holder, function() open = false end)
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true) end)
  button.MouseLeave:Connect(function() hover(false) end)
  button.Activated:Connect(B.safe("novoline.color", function()
    UI.sfx("click", 0.4)
    if open then fold() else openPicker() end
  end))
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = set }
end

function Section:keybind(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "None") or (spec.default or "None")
  local desc = spec.desc
  local line = row(self, desc and ROW_H or COMPACT_H)
  findable(self, line, spec.label, desc)
  local hover = washed(line)
  -- (Novoline's key: the name on a 92 x 28 tile; while it listens, the tile goes white with dark letters)
  local label = labels(line, spec.label, desc, 104)
  local chip, chipBody = tile(line, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 28), ZIndex = 4 }, 14)
  local key = text(chip, "", 12, "bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = P.text, ZIndex = 5 })
  local function listening(on)
    chipBody.Enabled = not on
    chip.BackgroundColor3 = on and P.on or P.white
    key.TextColor3 = on and P.ink or P.text
  end
  local function show() key.Text = Config.keyLabel(value ~= "None" and value or nil) end
  show()
  if id then
    Config.on(id, function(next)
      value = next
      if key.Parent then show() end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true) end)
  button.MouseLeave:Connect(function() hover(false) end)
  button.Activated:Connect(B.safe("novoline.key", function()
    key.Text = "Press a key"
    listening(true)
    Controls.captureKey(function(pressed, cancelled)
      listening(false)
      if not cancelled then
        local next = pressed or "None"
        if id then Config.set(id, next) else value = next; if spec.changed then spec.changed(next) end end
      end
      show()
    end)
  end))
  tooltip(button, spec.tip or desc, line, spec.label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end }
end

-- a pill button the width of the card
local function pillButton(parent, value, style, props)
  local holder = box(parent, props)
  holder.ZIndex = 3
  local face0, lift
  if style == "accent" then
    face0 = box(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent(), BackgroundTransparency = 0, ZIndex = 4 })
    round(face0, 16)
    wear(face0, "BackgroundColor3")
  else
    face0, lift = N.softFace(holder, 16)
  end
  local label = text(face0, value, 13, "bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
    TextColor3 = style == "danger" and P.danger or P.text })
  local button = hit(face0, { ZIndex = 8 })
  button.MouseEnter:Connect(function()
    if lift then tween(lift, HOVER_INFO, { BackgroundTransparency = 0.95 }) else tween(face0, HOVER_INFO, { BackgroundTransparency = 0.15 }) end
  end)
  button.MouseLeave:Connect(function()
    if lift then tween(lift, HOVER_INFO, { BackgroundTransparency = 1 }) else tween(face0, HOVER_INFO, { BackgroundTransparency = 0 }) end
  end)
  button.MouseButton1Down:Connect(function() tween(face0, HOVER_INFO, { Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2) }) end)
  button.MouseButton1Up:Connect(function() tween(face0, SWITCH_INFO, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() }) end)
  button.MouseLeave:Connect(function() tween(face0, SWITCH_INFO, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() }) end)
  return holder, button, label, face0
end
N.pillButton = pillButton
-- an action: Novoline's (its name at the left, a 92 x 28 tile at the right saying what it does)
function Section:button(spec)
  local id = spec.id
  local desc = spec.desc
  local line = row(self, (desc and desc ~= "") and ROW_H or COMPACT_H)
  findable(self, line, spec.label or spec.text, desc)
  local hover = washed(line)
  local name = labels(line, spec.label or spec.text or "", (desc and desc ~= "") and desc or nil, 104)
  local accentStyle = spec.style == "accent"
  local plate, plateBody = tile(line, { Name = "Action", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(92, 28), ZIndex = 4 }, 14)
  if accentStyle then plateBody.Enabled = false; plate.BackgroundColor3 = P.on end
  local said = text(plate, spec.text or (spec.label and "Run") or "Run", 12, "bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
    TextColor3 = accentStyle and P.ink or (spec.style == "danger" and P.danger or P.text) })
  local press = Instance.new("UIScale"); press.Parent = plate
  local chip = keyChip(line, id)
  chip.Position = UDim2.new(1, -100, 0.5, 0)
  if id then
    Config.action(id, function() if spec.run then spec.run() end end)
    if spec.bindable ~= false then Controls.bindables[id] = Controls.bindables[id] or { label = spec.label or id, kind = "button", page = self.page.source } end
  end
  local button = hit(line, { ZIndex = 8, Size = UDim2.new(1, 26, 1, 0), Position = UDim2.fromOffset(-14, 0) })
  button.MouseEnter:Connect(function() hover(true) end)
  button.MouseLeave:Connect(function() hover(false); tween(press, SWITCH_INFO, { Scale = 1 }) end)
  button.MouseButton1Down:Connect(function() tween(press, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }) end)
  button.MouseButton1Up:Connect(function() tween(press, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) end)
  button.Activated:Connect(B.safe("novoline.button", function()
    UI.sfx("click", 0.6)
    if spec.run then B.try("button." .. (spec.label or "?"), spec.run) end
  end))
  button.MouseButton2Click:Connect(function() if id and spec.bindable ~= false then keyMenu(id, spec.label, "button") end end)
  tooltip(button, spec.tip or desc, line, spec.label)
  -- (a new word: on the tile when the action has one of its own, else in place of its name)
  return { row = { frame = line, label = name }, button = plate, setText = function(value) if spec.text then said.Text = value else name.Text = value end end }
end

function Section:input(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "") or (spec.default or "")
  -- (Novoline's field: its name and line over a box of faint white, 30 tall, its rim brighter while typing)
  local desc = spec.desc
  local line = row(self, (desc and desc ~= "") and 92 or 72)
  tooltip(line, spec.tip or desc, nil, spec.label)
  findable(self, line, spec.label, desc)
  local label = labels(line, spec.label or "", (desc and desc ~= "") and desc or nil, 0)
  label.Position, label.Size = UDim2.fromOffset(0, 11), UDim2.new(1, 0, 0, 16)
  local field = box(line, { Position = UDim2.fromOffset(0, (desc and desc ~= "") and 50 or 34), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = P.white,
    BackgroundTransparency = 0.94, ZIndex = 4 })
  round(field, 10)
  local stroke = rim(field, P.white, 0.92)
  local entry = entryBox(field, 13)
  entry.Position, entry.Size, entry.ZIndex = UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 5
  entry.Text, entry.PlaceholderText = tostring(value), spec.placeholder or ""
  entry.Focused:Connect(function() tween(stroke, HOVER_INFO, { Transparency = 0.7 }) end)
  entry.FocusLost:Connect(B.safe("novoline.input", function()
    tween(stroke, HOVER_INFO, { Transparency = 0.92 })
    local typed = entry.Text
    if spec.numeric then
      local number = tonumber(typed)
      if not number then entry.Text = tostring(value); return end
      typed = number
    end
    if id then Config.set(id, typed) else
      value = typed
      if spec.changed then B.try("input", spec.changed, typed) end
    end
  end))
  if id then
    Config.on(id, function(next)
      value = next
      if entry.Parent and not entry:IsFocused() then entry.Text = tostring(next) end
      if spec.changed then spec.changed(next) end
    end)
  end
  return { row = { frame = line }, id = id, box = entry, get = function() return value end }
end

function Section:note(spec)
  local order = nextOrder(self)
  -- (Novoline's foot line: medium 11 in its quiet grey, inside the group)
  local holder = box(self.body, { Name = "Note", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
  pad(holder, 9, 14, 9, spec.icon and 36 or 14)
  if spec.icon then glyph(holder, spec.icon, 14, P.subtle, { Position = UDim2.fromOffset(-22, 0) }) end
  local label = text(holder, spec.text or "", 11, "medium", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
    TextTruncate = Enum.TextTruncate.None, TextColor3 = P.subtle, RichText = spec.rich == true })
  return { frame = holder, set = function(value) label.Text = value end }
end
-- A view a tab draws itself. One drawn wider than the card (the keyboard on Keys is 716 across) is
-- shrunk to fit: its pieces go into a frame of their own width, scaled down as one.
local function fitWide(frame, room)
  local widest = 0
  for _, child in ipairs(frame:GetChildren()) do
    if child:IsA("GuiObject") and child.Size.X.Scale == 0 then widest = math.max(widest, child.Size.X.Offset) end
  end
  if widest <= room then return end
  local k = room / widest
  local tall = frame.Size.Y.Offset
  local inner = box(frame, { Name = "Fit", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(widest, tall) })
  for _, child in ipairs(frame:GetChildren()) do
    if child ~= inner and child:IsA("GuiObject") then child.Parent = inner end
  end
  local scale = Instance.new("UIScale"); scale.Scale = k; scale.Parent = inner
  if tall > 0 then frame.Size = UDim2.new(1, 0, 0, math.ceil(tall * k)) end
end
function Section:custom(spec)
  local frame = box(self.body, { Name = spec.name or "Custom", Size = UDim2.new(1, 0, 0, spec.height or 100), LayoutOrder = nextOrder(self) })
  if spec.height == nil then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("novoline.custom", spec.build, frame)
  -- (in a deck whose Options card is the narrow one, the Music deck's, a view is fitted to that)
  local room = (self.page and self.page.narrow) and 300 or (self.wide and 540 or 316)
  if spec.height then B.try("novoline.fit", fitWide, frame, room) end
  return frame
end
-- for a tab's own version of itself (the Unnamed ones work here too): a line, two buttons, a box
function Section:label(value)
  local line = row(self, 22)
  local label = text(line, value or "", 12, "medium", { Size = UDim2.fromScale(1, 1), TextColor3 = P.sub })
  return { frame = line, set = function(next) label.Text = next end }
end
function Section:pair(a, b)
  local line = row(self, 38)
  local out = {}
  for index, item in ipairs({ a, b }) do
    if item then
      local holder, button, label = pillButton(line, item[1], nil, { Size = UDim2.new(b and 0.5 or 1, b and -4 or 0, 0, 30), Position = UDim2.new((index - 1) * 0.5, index == 2 and 4 or 0, 0, 4) })
      button.Activated:Connect(B.safe("novoline.pair", function() UI.sfx("click", 0.5); if item[2] then item[2]() end end))
      out[index] = { field = holder, label = label }
    end
  end
  return out
end
function Section:field(placeholder, changed)
  local line = row(self, 38)
  local field = box(line, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = P.raised, BackgroundTransparency = 0, ZIndex = 4 })
  round(field, 10)
  glyph(field, "search", 14, P.faint, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 5 })
  local entry = entryBox(field, 13)
  entry.Position, entry.Size, entry.ZIndex = UDim2.fromOffset(30, 0), UDim2.new(1, -40, 1, 0), 5
  entry.Text, entry.PlaceholderText = "", placeholder or ""
  if changed then entry:GetPropertyChangedSignal("Text"):Connect(function() changed(entry.Text) end) end
  return entry
end
N.Section = Section

-- ---------------------------------------------------------------- a tab: its sections, as Novoline's groups
-- A section is one of Novoline's settings groups: a plate of faint white (0.955, 14 round) with
-- hairlines between its rows. The tab's deck shows one section at a time in its Options card (the
-- Sections card beside it picks which); a search shows every section with something that matches,
-- each under its name.
local TextService = S.TextService
local Page = {}
Page.__index = Page
local function card(page, spec)
  page.sections += 1
  local frame = box(page.content, { Name = spec.title or "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = page.sections,
    Visible = false, ZIndex = 21 })
  list(frame, 0)
  local head = box(frame, { Name = "Group", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Visible = false, ZIndex = 21 })
  text(head, spec.title or page.source.title or "", 12, "bold", { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 0, 16), TextColor3 = P.subtle, ZIndex = 22 })
  local body = box(frame, { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = P.white, BackgroundTransparency = 0.955,
    LayoutOrder = 1, ZIndex = 21 })
  round(body, 14)
  list(body, 0)
  local wide = spec.full == true
  local section = setmetatable({ body = body, count = 0, made = 0, page = page, card = frame, wide = wide, icon = spec.icon or page.source.icon, top = true }, Section)
  page.list[#page.list + 1] = { title = spec.title or page.source.title or page.source.id, icon = spec.icon or page.source.icon or "circle", desc = spec.desc,
    frame = frame, head = head, wide = wide, section = section, stage = spec.stage == true }
  page.cards[#page.cards + 1] = { frame = frame, title = lower(spec.title) }
  return section
end
function Page:section(spec) return card(self, spec or {}) end
function Page:custom(height, build, alt)
  local section = card(self, { full = true })
  if alt then
    B.try("novoline.alt", alt, section)
    return section.body
  end
  local frame = box(section.body, { Name = "Custom", Size = UDim2.new(1, 0, 0, height or 0), LayoutOrder = nextOrder(section) })
  if not height then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("novoline.custom", build, frame)
  return frame
end
function Page:empty(icon, title, value)
  local section = card(self, {})
  local holder = box(section.body, { Size = UDim2.new(1, 0, 0, 160), LayoutOrder = nextOrder(section) })
  glyph(holder, icon or "package", 30, P.faint, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), ZIndex = 22 })
  text(holder, title or "Nothing here yet", 16, "bold", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.new(1, 0, 0, 22),
    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22 })
  text(holder, value or "", 12, "medium", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.new(1, -40, 0, 32),
    TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = P.subtle, TextWrapped = true, ZIndex = 22 })
end

-- ---------------------------------------------------------------- the tabs
local function tabsWanted()
  local out = {}
  for _, page in ipairs(Window.order) do
    if not page.hidden and page.build then out[#out + 1] = page end
  end
  return out
end
-- which rows a search keeps: { found anything, which groups show }. The hairline over the first row
-- still showing in each group goes, so a group never starts with a line.
local function filter(entry, query)
  local any, keep = false, {}
  for _, item in ipairs(entry.rows) do
    if item.frame.Parent then
      local found = query == "" or string.find(item.text, query, 1, true) ~= nil
      if found then
        if item.hidden then item.frame.Visible = true; item.hidden = nil end
        keep[item.card] = true
        any = true
      elseif item.frame.Visible then
        item.frame.Visible = false
        item.hidden = true
      end
    end
  end
  local shown = {}
  for _, c in ipairs(entry.cards) do
    local named = query ~= "" and c.title ~= "" and string.find(c.title, query, 1, true) ~= nil
    if named and not keep[c.frame] then
      for _, item in ipairs(entry.rows) do
        if item.card == c.frame and item.hidden then item.frame.Visible = true; item.hidden = nil end
      end
      any = true
    end
    shown[c.frame] = query == "" or keep[c.frame] == true or named
  end
  for _, c in ipairs(entry.cards) do
    local body = c.frame:FindFirstChild("Body")
    if body then
      local rows = {}
      for _, child in ipairs(body:GetChildren()) do
        if child:IsA("GuiObject") and child.Name == "Row" then rows[#rows + 1] = child end
      end
      table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
      local first = true
      for _, r in ipairs(rows) do
        if r.Visible then
          local line = r:FindFirstChild("Line")
          if line then line.Visible = not first end
          first = false
        end
      end
    end
  end
  return any, shown
end

-- ---------------------------------------------------------------- the dock (Novoline's: 52 tall, 40 px items, a capsule behind the chosen one)
local DOCK = { pad = 6, h = 40, w = 40, gap = 2 }
local ICON_OFF, ICON_HOVER, ICON_ON = rgb(150, 150, 156), rgb(235, 235, 238), rgb(242, 242, 244)
local QUICK = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
function N.paintNav(instant)
  if not N.bar then return end
  local x, selX, selW = DOCK.pad, nil, nil
  for _, tab in ipairs(N.tabs) do
    local selected = tab.id == N.current and N.open
    local w = selected and tab.wide or DOCK.w
    local goal = { Size = UDim2.fromOffset(w, DOCK.h), Position = UDim2.fromOffset(x, DOCK.pad) }
    if instant then tab.button.Size, tab.button.Position = goal.Size, goal.Position else tween(tab.button, SLIDE, goal) end
    if selected then selX, selW = x, w end
    tab.select(selected, instant)
    x += w + DOCK.gap
  end
  local barSize = UDim2.fromOffset(x - DOCK.gap + DOCK.pad, DOCK_H)
  if instant then N.bar.Size = barSize else tween(N.bar, SLIDE, { Size = barSize }) end
  local capsule = N.capsule
  if selX then
    local goal = { Position = UDim2.fromOffset(selX, DOCK.pad), Size = UDim2.fromOffset(selW, DOCK.h), BackgroundTransparency = 0 }
    if instant or capsule.BackgroundTransparency > 0.99 then
      capsule.Position, capsule.Size = goal.Position, UDim2.fromOffset(DOCK.w, DOCK.h)
      if instant then capsule.Size, capsule.BackgroundTransparency, N.capsuleRim.Transparency = goal.Size, 0, 0; return end
    end
    tween(capsule, SLIDE, goal)
    tween(N.capsuleRim, SLIDE, { Transparency = 0 })
  else
    tween(capsule, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
    tween(N.capsuleRim, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
  end
end
function N.rebuildTabs()
  if not N.built then return end
  for _, tab in ipairs(N.tabs) do tab.button:Destroy() end
  table.clear(N.tabs)
  local x = DOCK.pad
  for _, page in ipairs(tabsWanted()) do
    local label = page.title or page.id
    local ok, size = pcall(TextService.GetTextSize, TextService, label, 12, Enum.Font.GothamBold, Vector2.new(300, 20))
    local textW = ok and size.X or #label * 7
    local item = Instance.new("TextButton")
    item.Name, item.Text, item.AutoButtonColor = page.id, "", false
    item.Position, item.Size = UDim2.fromOffset(x, DOCK.pad), UDim2.fromOffset(DOCK.w, DOCK.h)
    item.BackgroundColor3, item.BackgroundTransparency, item.BorderSizePixel = P.white, 1, 0
    item.ZIndex, item.ClipsDescendants = 53, true
    item.Parent = N.bar
    round(item, true)
    local press = Instance.new("UIScale"); press.Parent = item
    local img = glyph(item, page.icon or "circle", 20, ICON_OFF, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(DOCK.w / 2, DOCK.h / 2), ZIndex = 54 })
    local name = text(item, label, 12, "bold", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 36, 0.5, 0), Size = UDim2.fromOffset(textW + 4, 16),
      TextColor3 = ICON_ON, TextTransparency = 1, TextTruncate = Enum.TextTruncate.None, ZIndex = 54 })
    local selected, hovered = false, false
    local function paint(instant)
      local over = hovered and not selected
      local goals = {
        { item, QUICK, { BackgroundTransparency = over and 0.92 or 1 } },
        { img, QUICK, { ImageColor3 = selected and ICON_ON or (over and ICON_HOVER or ICON_OFF) } },
        { img, SLIDE, { Position = UDim2.fromOffset(selected and 24 or DOCK.w / 2, DOCK.h / 2) } },
        { name, TweenInfo.new(selected and 0.3 or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, selected and 0.08 or 0), { TextTransparency = selected and 0 or 1 } },
      }
      for _, g in ipairs(goals) do
        if instant then for key, value in pairs(g[3]) do g[1][key] = value end else tween(g[1], g[2], g[3]) end
      end
    end
    item.MouseEnter:Connect(function()
      hovered = true
      paint()
      if not selected then N.showLabel(item, label) end
    end)
    item.MouseLeave:Connect(function() hovered = false; paint(); N.showLabel(nil) end)
    item.MouseButton1Down:Connect(function() tween(press, QUICK, { Scale = 0.94 }) end)
    item.MouseButton1Up:Connect(function() tween(press, SWITCH_INFO, { Scale = 1 }) end)
    item.MouseLeave:Connect(function() tween(press, SWITCH_INFO, { Scale = 1 }) end)
    item.Activated:Connect(B.safe("novoline.tab", function()
      if os.clock() - (N.tabAt or 0) < 0.25 then return end
      N.tabAt = os.clock()
      N.showLabel(nil)
      if N.open and N.current == page.id then N.show(false)
      elseif not N.open then N.current = page.id; N.show(true)
      else N.go(page.id) end
    end))
    N.tabs[#N.tabs + 1] = { id = page.id, button = item, wide = 14 + 20 + 6 + textW + 16, select = function(on, instant) selected = on; paint(instant) end }
    paint(true)
    x += DOCK.w + DOCK.gap
  end
  if not (N.current and Window.pages[N.current]) then
    -- (Novoline opens on its Home deck, the way Novoline does: a game's own tab, the ragebot,
    -- is a click away on the dock, never what the hub opens on)
    local wanted = tabsWanted()
    N.current = (Window.pages.home and "home") or (Window.startPage and Window.pages[Window.startPage] and Window.startPage) or (wanted[1] and wanted[1].id) or nil
  end
  N.paintNav(true)
end

-- ---------------------------------------------------------------- where the cards sit, and how they come and go
-- Novoline's scale: never past 1, and the whole layout (1280 x 712 design px) always on screen;
-- then the hub's own size settings.
local FULL_W, FULL_H = 1280, 712
local MARGIN, TOP, BOTTOM = 40, 34, 90
local function scaleNow()
  local camera = workspace.CurrentCamera
  local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
  local fit = math.min(1, view.X / FULL_W, view.Y / FULL_H)
  return math.max(0.45, fit) * ((Config.get("app.scale") or 100) / 100) * ((Config.get("app.novoline.size") or 100) / 100)
end
N.scaleNow = scaleNow
local function screen()
  return N.gui.AbsoluteSize
end
-- the dock's bottom centre (dragged there, or Novoline's spot)
local function seat()
  if not N.bar then return end
  local x, y = Config.get("app.novoline.x"), Config.get("app.novoline.y")
  if type(x) == "number" and x >= 0 then N.bar.Position = UDim2.fromScale(x, y) else N.bar.Position = UDim2.new(0.5, 0, 1, -24) end
end
local function dockCentre()
  local bar = N.bar
  local at = bar.AbsolutePosition - N.gui.AbsolutePosition
  if not bar.Visible or bar.AbsoluteSize.X < 1 then
    local view = screen()
    return Vector2.new(view.X / 2, view.Y - 24 - DOCK_H / 2)
  end
  return at + bar.AbsoluteSize / 2
end
-- where a card rests: its corner, and how far in from it (design px); its centre and size in pixels
local function cardRest(item)
  local s = N.sizer.Scale
  local view = screen()
  local w, h = item.w * s, item.h * s
  local left = item.corner == "tl" or item.corner == "bl"
  local top = item.corner == "tl" or item.corner == "tr"
  local x = left and (MARGIN + item.x) * s + w / 2 or view.X - (MARGIN + item.x) * s - w / 2
  -- (the top row starts under Roblox's own buttons, which sit in the first 58 pixels)
  local topStart = math.max(TOP * s, UI.inset().Y + 14)
  local y = top and topStart + item.y * s + h / 2 or view.Y - (BOTTOM + item.y) * s - h / 2
  return Vector2.new(x, y), Vector2.new(w, h)
end
-- a card: dark glass whose body fades as one and never reflows while the card's frame grows round it
local function floating(name, w, h, radius, bare)
  local frame = box(N.gui, { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, h), Visible = false, ZIndex = 20, ClipsDescendants = true })
  if not bare then glass(frame, radius or 28) end
  local scale = Instance.new("UIScale"); scale.Parent = frame
  local body = Instance.new("CanvasGroup")
  body.Name = "Body"
  body.BackgroundTransparency, body.BorderSizePixel = 1, 0
  body.AnchorPoint, body.Position, body.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(w, h)
  body.ZIndex = 21
  body.Parent = frame
  return { frame = frame, body = body, scale = scale, w = w, h = h, bare = bare == true }
end
local function settle(item)
  local centre = cardRest(item)
  item.frame.Position = UDim2.fromOffset(centre.X, centre.Y)
  item.frame.Size = UDim2.fromOffset(item.w, item.h)
end
-- out of the dock: from a 120 x 44 pill where the dock is, to its place (0.56 s quint out)
local function rise(item, delay)
  local frame, body = item.frame, item.body
  item.sinking = false
  frame.Visible = true
  local centre = cardRest(item)
  if Motion.reduced then settle(item); body.GroupTransparency = 0; return end
  local dock = dockCentre()
  frame.Position = UDim2.fromOffset(dock.X, dock.Y)
  frame.Size = UDim2.fromOffset(120, 44)
  body.GroupTransparency = 1
  tween(frame, TweenInfo.new(0.56, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0), { Position = UDim2.fromOffset(centre.X, centre.Y), Size = UDim2.fromOffset(item.w, item.h) })
  tween(body, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), { GroupTransparency = 0 })
end
-- a title has no glass: it comes up a little and fades in
local function lift(item, delay, from)
  local frame, body = item.frame, item.body
  item.sinking = false
  frame.Visible = true
  local centre = cardRest(item)
  frame.Size = UDim2.fromOffset(item.w, item.h)
  if Motion.reduced then frame.Position = UDim2.fromOffset(centre.X, centre.Y); body.GroupTransparency = 0; return end
  frame.Position = UDim2.fromOffset(centre.X, centre.Y + (from or 14) * N.sizer.Scale)
  body.GroupTransparency = 1
  tween(frame, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0), { Position = UDim2.fromOffset(centre.X, centre.Y) })
  tween(body, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), { GroupTransparency = 0 })
end
-- from where another card is (a tab change: the card in the same corner turns into this one)
local function morph(item, fromPosition, fromSize, delay)
  local frame, body = item.frame, item.body
  item.sinking = false
  frame.Visible = true
  local centre = cardRest(item)
  if Motion.reduced then settle(item); body.GroupTransparency = 0; return end
  frame.Position, frame.Size = fromPosition, fromSize
  body.GroupTransparency = 1
  tween(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0), { Position = UDim2.fromOffset(centre.X, centre.Y), Size = UDim2.fromOffset(item.w, item.h) })
  tween(body, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), { GroupTransparency = 0 })
end
local function fadeAway(item)
  if not item.frame.Visible then return end
  item.sinking = true
  tween(item.body, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
  task.delay(0.16, function() if item.sinking then item.frame.Visible = false end end)
end
-- back into the dock (0.28 s quint in, most of the way, and gone)
local function sink(item, delay)
  local frame, body = item.frame, item.body
  if not frame.Visible then return end
  item.sinking = true
  if Motion.reduced then frame.Visible = false; return end
  if item.bare then
    tween(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = frame.Position + UDim2.fromOffset(0, 10) })
    tween(body, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { GroupTransparency = 1 })
  else
    local dock = dockCentre()
    local at = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
    local goal = at:Lerp(dock, 0.45)
    tween(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, delay or 0),
      { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(frame.Size.X.Offset * 0.6, frame.Size.Y.Offset * 0.6) })
    tween(body, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, (delay or 0) + 0.15), { GroupTransparency = 1 })
  end
  task.delay((delay or 0) + 0.34, function() if item.sinking then frame.Visible = false end end)
end
local labelTip
function N.showLabel(anchor, value)
  if not labelTip then return end
  if not anchor then labelTip.Visible = false; return end
  labelTip.Text = value
  local at = anchor.AbsolutePosition - overlay.AbsolutePosition
  labelTip.Position = UDim2.fromOffset(at.X + anchor.AbsoluteSize.X / 2, at.Y - 10)
  labelTip.Visible = true
end
-- a soft button on a card (Novoline's: the dark plate, its rim lit at the top, a lift under the mouse,
-- pressed to 95%); `tint` makes it a coloured tile instead
local function soft(parent, x, y, w, h, radius, tint, run)
  local holder = box(parent, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = 22 })
  local plate, liftFrame
  if tint then
    plate = box(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = tint, BackgroundTransparency = 0, ZIndex = 23 })
    round(plate, radius)
    local line = rim(plate, P.white, 0)
    pcall(function() line.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
    local light = Instance.new("UIGradient"); light.Rotation = 90
    light.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 0.97) })
    light.Parent = line
    liftFrame = box(plate, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.white, BackgroundTransparency = 1, ZIndex = 24 })
    round(liftFrame, radius)
  else
    plate, liftFrame = N.softFace(holder, radius)
  end
  local press = Instance.new("UIScale"); press.Parent = holder
  local button = hit(holder, { ZIndex = 30 })
  button.MouseEnter:Connect(function() tween(liftFrame, TweenInfo.new(0.18), { BackgroundTransparency = 0.95 }) end)
  button.MouseLeave:Connect(function() tween(liftFrame, TweenInfo.new(0.18), { BackgroundTransparency = 1 }); tween(press, SWITCH_INFO, { Scale = 1 }) end)
  button.MouseButton1Down:Connect(function() tween(press, QUICK, { Scale = 0.95 }) end)
  button.MouseButton1Up:Connect(function() tween(press, SWITCH_INFO, { Scale = 1 }) end)
  if run then button.Activated:Connect(B.safe("novoline.soft", function() UI.sfx("click", 0.5); run() end)) end
  return holder, plate, button
end
-- a card's own name (Novoline's: bold 14 at 18, 16) and its icon at the right
local function header(item, title, icon)
  text(item.body, title, 14, "bold", { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(item.w - 70, 18), ZIndex = 22 })
  if icon then glyph(item.body, icon, 16, P.subtle, { Position = UDim2.fromOffset(item.w - 34, 17), ZIndex = 22 }) end
end
local function headshot(parent, x, y, size)
  local image = Instance.new("ImageLabel")
  image.BackgroundColor3, image.BorderSizePixel = rgb(40, 40, 44), 0
  image.Size, image.Position = UDim2.fromOffset(size, size), UDim2.fromOffset(x, y)
  image.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(B.LP.UserId) .. "&w=150&h=150"
  image.ZIndex = 22
  image.Parent = parent
  round(image, true)
  return image
end
-- the looks, Settings and Unload, under the account card
local function looksMenu(anchor)
  openMenu({
    { label = "BASED look", icon = "sparkles", run = function() Config.set("app.gui", "based") end },
    { label = "Unnamed look", icon = "app-window", run = function() Config.set("app.gui", "unnamed") end },
    { label = "Novoline look", icon = "layout-grid", checked = true, run = function() end },
    "divider",
    { label = "Settings", icon = "settings", run = function() N.go("settings") end },
    { label = "Keys", icon = "keyboard", run = function() N.go("keys") end },
    { label = "Close", icon = "x", run = function() N.show(false) end },
    { label = "Unload BASED", icon = "power", danger = true, run = function() B.unload() end },
  }, nil, anchor)
end

-- ---------------------------------------------------------------- a tab's deck: Novoline's settings deck
-- tl  the tab's name (black 30) and its line (medium 13)
-- tr  a search pill (260 x 44) and your account beside it (200 x 44)
-- bl  the Sections card (210 x 360) beside the Options card (296 x 360) that holds the chosen section;
--     a wide section (a view of its own, the keyboard, the music) widens Options to 520. A tab of one
--     section has no Sections card: Options is a 520 stage from the corner.
-- br  Quick settings (330 x 173: the tab's first three switches as tinted tiles) over Shortcuts
--     (330 x 173: the keys on this tab)
-- (Options is 340 across, not Novoline's 296: the hub's settings have longer names and lines)
local SECTIONS_W, OPTIONS_W, STAGE_W, CARD_H, SIDE_W = 210, 340, 564, 360, 330
local decks = {}
N.decks = decks
local pick
local function addCard(d, name, corner, x, y, w, h, bare)
  local item = floating(name, w, h, h <= 60 and math.floor(h / 2) or 28, bare)
  item.corner, item.x, item.y = corner, x, y
  item.scale.Scale = N.sizer.Scale
  d.cards[#d.cards + 1] = item
  return item
end
-- the Options card at the width the chosen section wants
local function shape(d, wide, instant)
  if d.fixed then return end
  local item = d.options
  local w = (d.single or wide) and STAGE_W or OPTIONS_W
  if item.w == w then return end
  item.w = w
  item.body.Size = UDim2.fromOffset(w, item.h)
  d.heroTile.Position = UDim2.fromOffset(w - 16 - 36, 14)
  d.heroTitle.Size, d.heroDesc.Size = UDim2.fromOffset(w - 18 - 60, 20), UDim2.fromOffset(w - 18 - 60, 28)
  if not item.frame.Visible or instant or Motion.reduced then
    if item.frame.Visible then settle(item) end
    return
  end
  local centre = cardRest(item)
  tween(item.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(centre.X, centre.Y), Size = UDim2.fromOffset(w, item.h) })
end
local function rowsIn(entry, frame)
  local n = 0
  for _, item in ipairs(entry.rows) do if item.card == frame then n += 1 end end
  return n
end
local function tabDeck(source)
  local d = decks[source.id]
  if d then return d end
  d = { id = source.id, source = source, cards = {}, query = "", catRows = {} }
  decks[source.id] = d
  -- the name, top left
  local title = addCard(d, "Title", "tl", 0, 0, 760, 72, true)
  text(title.body, source.title or source.id, 30, "black", { Size = UDim2.fromOffset(760, 36), ZIndex = 22 })
  d.subtitle = text(title.body, source.eyebrow or source.desc or "", 13, "medium", { Position = UDim2.fromOffset(1, 40), Size = UDim2.fromOffset(760, 18), TextColor3 = P.sub, ZIndex = 22 })
  -- the search pill, top right
  local search = addCard(d, "Search", "tr", 0, 0, 260, 44)
  glyph(search.body, "search", 16, P.subtle, { Position = UDim2.fromOffset(16, 14), ZIndex = 22 })
  local seek = entryBox(search.body, 13)
  seek.Position, seek.Size, seek.ZIndex = UDim2.fromOffset(42, 0), UDim2.fromOffset(176, 44), 22
  seek.PlaceholderText, seek.PlaceholderColor3, seek.Text = "Search " .. lower(source.title or source.id), P.placeholder, ""
  d.seek = seek
  local clear = hit(search.body, { Position = UDim2.fromOffset(260 - 36, 10), Size = UDim2.fromOffset(24, 24), ZIndex = 23, Visible = false })
  glyph(clear, "x", 14, P.subtle, { Position = UDim2.fromOffset(5, 5), ZIndex = 24 })
  clear.Activated:Connect(function() seek.Text = "" end)
  -- you, beside it: a click opens the looks and the rest
  local account = addCard(d, "Account", "tr", 270, 0, 200, 44)
  headshot(account.body, 7, 7, 30)
  text(account.body, B.LP.DisplayName, 13, "bold", { Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(122, 16), ZIndex = 22 })
  text(account.body, "@" .. B.LP.Name, 10, "medium", { Position = UDim2.fromOffset(46, 23), Size = UDim2.fromOffset(122, 14), TextColor3 = P.subtle, ZIndex = 22 })
  glyph(account.body, "chevron-down", 14, P.subtle, { Position = UDim2.fromOffset(200 - 30, 15), ZIndex = 22 })
  local accountHit = hit(account.body, { ZIndex = 24, BackgroundColor3 = P.white })
  round(accountHit, 22)
  accountHit.MouseEnter:Connect(function() tween(accountHit, HOVER_INFO, { BackgroundTransparency = 0.96 }) end)
  accountHit.MouseLeave:Connect(function() tween(accountHit, HOVER_INFO, { BackgroundTransparency = 1 }) end)
  accountHit.Activated:Connect(B.safe("novoline.account", function() UI.sfx("click", 0.5); looksMenu(account.frame) end))
  -- Music is Novoline's music deck: what is playing is the stage, bottom left (its record, the
  -- cover and the Shuffle, Library and Playlists tiles: the hub's wide card), and the tab's sections
  -- sit bottom right, the way Novoline's queue does
  local stage = source.id == "music" and B.Card ~= nil and B.Card.viewWide ~= nil
  -- the Options card first: the tab builds into it
  local optionsW = stage and SIDE_W or OPTIONS_W
  local options = addCard(d, "Options", stage and "br" or "bl", stage and 0 or 224, 0, optionsW, CARD_H)
  d.options = options
  d.heroTitle = text(options.body, "", 16, "bold", { Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(optionsW - 18 - 60, 20), ZIndex = 22 })
  d.heroDesc = text(options.body, "", 11, "medium", { Position = UDim2.fromOffset(18, 35), Size = UDim2.fromOffset(optionsW - 18 - 60, 28), TextColor3 = P.subtle, ZIndex = 22,
    TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
  local heroTile = tile(options.body, { Position = UDim2.fromOffset(optionsW - 16 - 36, 14), Size = UDim2.fromOffset(36, 36), ZIndex = 21 }, 12)
  d.heroTile = heroTile
  d.heroIcon = glyph(heroTile, source.icon or "circle", 18, P.text, { Position = UDim2.fromOffset(9, 9), ZIndex = 22 })
  local scroller = Instance.new("ScrollingFrame")
  scroller.Name = source.id
  scroller.BackgroundTransparency, scroller.BorderSizePixel = 1, 0
  scroller.Position, scroller.Size = UDim2.fromOffset(0, 68), UDim2.new(1, 0, 1, -68)
  scroller.CanvasSize = UDim2.new()
  scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
  scroller.ScrollingDirection = Enum.ScrollingDirection.Y
  scroller.ScrollBarThickness = 0
  scroller.ZIndex = 21
  scroller.Parent = options.body
  scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() hideTip() end)
  local content = box(scroller, { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 21 })
  pad(content, 4, 12, 18, 12)
  list(content, 20)
  -- the tab, built into it
  local entry = setmetatable({ source = source, scroller = scroller, content = content, sections = 0, rows = {}, cards = {}, list = {}, toggles = {}, narrow = stage }, Page)
  N.pages[source.id] = entry
  d.entry = entry
  B.try("novoline.page." .. source.id, source.build, entry)
  -- (what the stage already shows is not a section of its own as well: Music's "Now playing" was
  -- the wide player squeezed into the narrow card beside the same player, 2026-10-30)
  if stage then
    for index = #entry.list, 1, -1 do
      local item = entry.list[index]
      if item.stage then
        item.frame.Visible = false
        table.remove(entry.list, index)
      end
    end
  end
  if #entry.list == 0 then entry:empty(nil, "Nothing here yet", "This tab is ready for its controls.") end
  if B.Keys and B.Keys.repaint then B.Keys.repaint() end
  -- its sections, beside it (a tab of one section is a stage of its own)
  d.single = #entry.list == 1 and not stage
  d.fixed = stage
  if stage then
    local size = B.Card.WIDE
    local now = addCard(d, "NowPlaying", "bl", 0, 0, STAGE_W, CARD_H)
    local k = math.min(STAGE_W / size.X, CARD_H / size.Y)
    local holder = box(now.body, { Name = "Wide", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 21 })
    local grow = Instance.new("UIScale"); grow.Scale = k; grow.Parent = holder
    B.try("novoline.music.stage", B.Card.viewWide, holder, function() return N.open and N.current == "music" end)
  end
  if d.single then
    options.x = 0
  else
    local cats = addCard(d, "Sections", stage and "br" or "bl", stage and (SIDE_W + 14) or 0, 0, SECTIONS_W, CARD_H)
    text(cats.body, "Sections", 14, "bold", { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(160, 18), ZIndex = 22 })
    local many = #entry.list > 8
    local step = many and 35 or 38
    local tall = step - 4
    local holder = Instance.new("ScrollingFrame")
    holder.BackgroundTransparency, holder.BorderSizePixel = 1, 0
    holder.Position, holder.Size = UDim2.fromOffset(0, many and 38 or 40), UDim2.new(1, 0, 1, -(many and 38 or 40) - 8)
    holder.CanvasSize = UDim2.fromOffset(0, #entry.list * step)
    holder.ScrollBarThickness = 0
    holder.ScrollingDirection = Enum.ScrollingDirection.Y
    holder.ZIndex = 21
    holder.Parent = cats.body
    local glide = box(holder, { Name = "Glide", BackgroundColor3 = P.white, BackgroundTransparency = 0.9, ZIndex = 21 })
    round(glide, 12)
    d.glide = glide
    for n, item in ipairs(entry.list) do
      local line = hit(holder, { Name = item.title, Position = UDim2.fromOffset(12, (n - 1) * step), Size = UDim2.fromOffset(186, tall), ZIndex = 22 })
      local mark = tile(line, { Position = UDim2.fromOffset(5, math.floor((tall - 24) / 2)), Size = UDim2.fromOffset(24, 24), ZIndex = 23 }, 8)
      glyph(mark, item.icon, 14, P.text, { Position = UDim2.fromOffset(5, 5), ZIndex = 24 })
      local name, fits = shrink(text(line, item.title, 13, "bold", { Position = UDim2.fromOffset(38, 0), Size = UDim2.fromOffset(112, tall), TextTransparency = 0.35, ZIndex = 23 }), 13, 11)
      d.catSize = math.min(d.catSize or 13, fits or 13)
      local held = rowsIn(entry, item.frame)
      text(line, held > 0 and tostring(held) or "", 11, "medium", { Position = UDim2.fromOffset(186 - 10 - 28, 0), Size = UDim2.fromOffset(28, tall), TextColor3 = P.subtle,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23 })
      d.catRows[item] = { line = line, name = name }
      line.MouseEnter:Connect(function() if item ~= d.current or d.query ~= "" then tween(name, QUICK, { TextTransparency = 0.1 }) end end)
      line.MouseLeave:Connect(function() if item ~= d.current or d.query ~= "" then tween(name, QUICK, { TextTransparency = 0.35 }) end end)
      line.Activated:Connect(B.safe("novoline.section", function()
        UI.sfx("tab", 0.35)
        if d.query ~= "" then seek.Text = "" end
        pick(d, item)
      end))
    end
  end
  -- (the list reads as one: every name at the size the longest one fits)
  for _, r in pairs(d.catRows) do r.name.TextSize = d.catSize or 13 end
  -- quick settings, bottom right: the tab's first three switches as Novoline's tinted tiles
  -- (Music has none of these two: its sections are where they would be)
  local quick = addCard(stage and { cards = {} } or d, "Quick", "br", 0, 187, SIDE_W, 173)
  text(quick.body, "Quick settings", 14, "bold", { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 18), ZIndex = 22 })
  if #entry.toggles == 0 then
    text(quick.body, "No switches on this tab.", 12, "medium", { Position = UDim2.fromOffset(18, 48), Size = UDim2.fromOffset(SIDE_W - 36, 16), TextColor3 = P.subtle, ZIndex = 22 })
  end
  for n = 1, math.min(3, #entry.toggles) do
    local t = entry.toggles[n]
    local tint = TINT[n]
    local holder, plate = soft(quick.body, 16 + (n - 1) * 102, 40, 94, 117, 18, nil, function() Config.set(t.id, not (Config.get(t.id) == true)) end)
    local plateBody = plate:FindFirstChildOfClass("UIGradient")
    local mark = glyph(holder, t.icon or source.icon or "zap", 20, P.text, { Position = UDim2.fromOffset(14, 14), ZIndex = 26 })
    shrink(text(holder, t.label, 12, "bold", { Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(74, 16), ZIndex = 26 }), 12, 8)
    local state = text(holder, "", 11, "medium", { Position = UDim2.fromOffset(14, 92), Size = UDim2.fromOffset(74, 14), TextColor3 = P.subtle, ZIndex = 26 })
    local function paint()
      local on = Config.get(t.id) == true
      if plateBody then plateBody.Enabled = not on end
      plate.BackgroundColor3 = on and tint[1] or P.white
      tween(mark, QUICK, { ImageColor3 = on and tint[2] or P.text })
      state.Text = on and "On" or "Off"
    end
    paint()
    Config.on(t.id, function() if holder.Parent then paint() end end)
  end
  -- its keys, under that
  local keys = addCard(stage and { cards = {} } or d, "Shortcuts", "br", 0, 0, SIDE_W, 173)
  header(keys, "Shortcuts", "keyboard")
  local keyRows = box(keys.body, { Size = UDim2.fromScale(1, 1), ZIndex = 22 })
  local function drawKeys()
    for _, child in ipairs(keyRows:GetChildren()) do child:Destroy() end
    local bound = {}
    for id, info in pairs(Controls.bindables) do
      local bind = Config.bindOf(id)
      if bind and bind.key and info.page == source then bound[#bound + 1] = { id = id, label = info.label, kind = info.kind, bind = bind } end
    end
    table.sort(bound, function(a, b) return a.label < b.label end)
    if #bound == 0 then
      text(keyRows, "Nothing on this tab has a key yet. Right-click a switch to give it one.", 12, "medium", { Position = UDim2.fromOffset(18, 48), Size = UDim2.fromOffset(SIDE_W - 36, 34),
        TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextColor3 = P.subtle, ZIndex = 23 })
      local open = soft(keyRows, 18, 104, 132, 34, 17, nil, function() N.go("keys") end)
      glyph(open, "keyboard", 14, P.text, { Position = UDim2.fromOffset(14, 10), ZIndex = 26 })
      text(open, "All your keys", 12, "bold", { Position = UDim2.fromOffset(36, 0), Size = UDim2.fromOffset(90, 34), ZIndex = 26 })
      return
    end
    for n = 1, math.min(2, #bound) do
      local b = bound[n]
      local y = 44 + (n - 1) * ROW_H
      shrink(text(keyRows, b.label, 13, "bold", { Position = UDim2.fromOffset(18, y + 11), Size = UDim2.fromOffset(SIDE_W - 36 - 104, 16), ZIndex = 23 }), 13, 10)
      local how = b.kind == "button" and "Press to run" or (b.bind.mode == "hold" and "Hold to use" or "Press to switch")
      text(keyRows, how, 11, "medium", { Position = UDim2.fromOffset(18, y + 30), Size = UDim2.fromOffset(SIDE_W - 36 - 104, 14), TextColor3 = P.subtle, ZIndex = 23 })
      local plate = tile(keyRows, { Position = UDim2.fromOffset(SIDE_W - 18 - 92, y + 14), Size = UDim2.fromOffset(92, 28), ZIndex = 23 }, 14)
      text(plate, Config.keyLabel(b.bind.key), 12, "bold", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 24 })
      if n < math.min(2, #bound) then
        box(keyRows, { Position = UDim2.fromOffset(18, y + ROW_H - 1), Size = UDim2.fromOffset(SIDE_W - 36, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0.94, ZIndex = 23 })
      end
    end
    if #bound > 2 then
      text(keyRows, "+" .. (#bound - 2) .. " more on Keys", 11, "medium", { Position = UDim2.fromOffset(18, 173 - 22), Size = UDim2.fromOffset(SIDE_W - 36, 14), TextColor3 = P.subtle, ZIndex = 23 })
    end
  end
  drawKeys()
  Config.bindsChanged:connect(function() if keyRows.Parent then drawKeys() end end)
  -- searching
  local token = 0
  seek:GetPropertyChangedSignal("Text"):Connect(function()
    clear.Visible = seek.Text ~= ""
    token += 1
    local mine = token
    task.delay(0.12, function()
      if mine ~= token then return end
      d.query = string.match(lower(seek.Text), "^%s*(.-)%s*$")
      B.try("novoline.search", pick, d, d.current)
    end)
  end)
  pick(d, entry.list[1], true)
  return d
end
-- show one section (or, while searching, every section that has a match)
pick = function(d, item, instant)
  local entry = d.entry
  if not item then return end
  fold()
  closeMenu()
  d.current = item
  local searching = d.query ~= ""
  local any, shown = filter(entry, d.query)
  local count = 0
  for _, other in ipairs(entry.list) do
    local on
    if searching then on = shown[other.frame] == true else on = other == item end
    other.frame.Visible = on
    other.head.Visible = searching and on
    if on then count += rowsIn(entry, other.frame) end
  end
  if searching then
    d.heroTitle.Text = any and "Results" or "Nothing found"
    d.heroDesc.Text = any and (count == 1 and "1 setting matches" or (count .. " settings match")) or "Try another word."
    UI.setIcon(d.heroIcon, "search")
  else
    d.heroTitle.Text = item.title
    local held = rowsIn(entry, item.frame)
    d.heroDesc.Text = item.desc or (held > 0 and (held == 1 and "1 setting" or (held .. " settings")) or "")
    UI.setIcon(d.heroIcon, item.icon or "circle")
  end
  shape(d, (not searching) and item.wide, instant)
  -- the Sections card: the glide sits under the chosen one, the others dimmed
  if d.glide then
    local at = d.catRows[item]
    if at then
      local goal = { Position = at.line.Position, Size = at.line.Size, BackgroundTransparency = searching and 1 or 0.9 }
      if instant or d.glide.Size.Y.Offset <= 0 then
        d.glide.Position, d.glide.Size, d.glide.BackgroundTransparency = goal.Position, goal.Size, goal.BackgroundTransparency
      else
        tween(d.glide, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
      end
    end
    for other, r in pairs(d.catRows) do
      tween(r.name, QUICK, { TextTransparency = (other == item and not searching) and 0 or 0.35 })
    end
  end
  if not searching then d.entry.scroller.CanvasPosition = Vector2.zero end
end

-- ---------------------------------------------------------------- the Home deck: Novoline's own
local DAY = {
  { 5, "It's the middle of the night, night owl" }, { 7, "It's sunrise, the day is just getting started" }, { 11, "Good morning, have a good one" },
  { 14, "It's midday, sun's at the top" }, { 17, "Good afternoon, hope it's going well" }, { 19, "It's golden hour" }, { 21, "It's sunset, wind down a little" },
  { 24, "Good evening, the night is yours" },
}
local function dayLine()
  local hour = tonumber(os.date("%H")) or 12
  for _, step in ipairs(DAY) do if hour < step[1] then return step[2] end end
  return DAY[#DAY][2]
end
local homeDeck = nil
local function buildHome()
  if homeDeck then return homeDeck end
  local d = { id = "home", cards = {} }
  homeDeck = d
  -- the welcome, top left
  local title = addCard(d, "Title", "tl", 0, 0, 760, 72, true)
  text(title.body, "Welcome back, " .. B.LP.DisplayName, 30, "black", { Size = UDim2.fromOffset(760, 36), ZIndex = 22 })
  local day = text(title.body, dayLine(), 13, "medium", { Position = UDim2.fromOffset(1, 40), Size = UDim2.fromOffset(760, 18), TextColor3 = P.sub, ZIndex = 22 })
  -- the clock and the executor, top right
  local clock = addCard(d, "Clock", "tr", 0, 0, 158, 44)
  glyph(clock.body, "clock", 16, P.subtle, { Position = UDim2.fromOffset(16, 14), ZIndex = 22 })
  local time = text(clock.body, "", 15, "bold", { Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(50, 44), ZIndex = 22 })
  local date = text(clock.body, "", 13, "medium", { Position = UDim2.fromOffset(94, 0), Size = UDim2.fromOffset(56, 44), TextColor3 = P.subtle, ZIndex = 22 })
  local execName = "Executor"
  pcall(function()
    local name = (identifyexecutor or getexecutorname)()
    if type(name) == "string" and name ~= "" then execName = name end
  end)
  local okW, size = pcall(TextService.GetTextSize, TextService, execName, 13, Enum.Font.GothamBold, Vector2.new(400, 44))
  local execW = math.min(okW and size.X or 80, 160) + 58
  local exec = addCard(d, "Executor", "tr", 158 + 10, 0, execW, 44)
  glyph(exec.body, "shield", 16, P.subtle, { Position = UDim2.fromOffset(16, 14), ZIndex = 22 })
  text(exec.body, execName, 13, "bold", { Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(execW - 54, 44), ZIndex = 22 })
  -- you, bottom left
  local profile = addCard(d, "Profile", "bl", 0, 0, 230, 360)
  local banner = box(profile.body, { Name = "Banner", Size = UDim2.fromOffset(230, 110), BackgroundColor3 = P.white, BackgroundTransparency = 0, ZIndex = 21 })
  local bannerFade = Instance.new("UIGradient")
  bannerFade.Rotation = 90
  bannerFade.Color = ColorSequence.new(rgb(46, 46, 50), rgb(16, 16, 18))
  bannerFade.Transparency = NumberSequence.new(0, 1)
  bannerFade.Parent = banner
  local avatar = headshot(profile.body, 18, 70, 76)
  local ring = Instance.new("UIStroke"); ring.Color, ring.Thickness = rgb(12, 12, 14), 4; ring.Parent = avatar
  text(profile.body, B.LP.DisplayName, 18, "bold", { Position = UDim2.fromOffset(18, 158), Size = UDim2.fromOffset(194, 22), ZIndex = 22 })
  text(profile.body, "@" .. B.LP.Name, 12, "medium", { Position = UDim2.fromOffset(18, 182), Size = UDim2.fromOffset(194, 16), TextColor3 = P.subtle, ZIndex = 22 })
  local stat = {}
  for n, key in ipairs({ "Friends", "Account", "Online" }) do
    local x = 18 + (n - 1) * 68
    stat[key] = text(profile.body, "", 16, "bold", { Position = UDim2.fromOffset(x, 232), Size = UDim2.fromOffset(64, 20), ZIndex = 22 })
    text(profile.body, key, 11, "medium", { Position = UDim2.fromOffset(x, 254), Size = UDim2.fromOffset(64, 14), TextColor3 = P.subtle, ZIndex = 22 })
  end
  local ageDays = tonumber(B.LP.AccountAge) or 0
  stat.Account.Text = ageDays >= 365 and (math.floor(ageDays / 365) .. "y") or (ageDays .. "d")
  stat.Friends.Text, stat.Online.Text = "...", "..."
  box(profile.body, { Position = UDim2.fromOffset(18, 288), Size = UDim2.fromOffset(194, 1), BackgroundColor3 = P.white, BackgroundTransparency = 0.93, ZIndex = 22 })
  text(profile.body, os.date("Joined Roblox in %B %Y", os.time() - ageDays * 86400), 11, "medium", { Position = UDim2.fromOffset(18, 304), Size = UDim2.fromOffset(194, 14),
    TextColor3 = P.subtle, ZIndex = 22 })
  text(profile.body, "Account " .. (ageDays >= 365 and (math.floor(ageDays / 365) .. " years") or (ageDays .. " days")) .. " old", 11, "medium",
    { Position = UDim2.fromOffset(18, 324), Size = UDim2.fromOffset(194, 14), TextColor3 = P.subtle, ZIndex = 22 })
  -- over it, Novoline's own first widget: its name and the frames a second
  local widget = addCard(d, "Widget", "bl", 0, 360 + 14, 230, 118)
  text(widget.body, "BASED", 15, "bold", { Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(194, 20), ZIndex = 22 })
  local fpsValue = text(widget.body, "-", 28, "black", { Position = UDim2.fromOffset(18, 48), Size = UDim2.fromOffset(194, 34), ZIndex = 22 })
  text(widget.body, "FPS", 11, "medium", { Position = UDim2.fromOffset(18, 84), Size = UDim2.fromOffset(194, 14), TextColor3 = P.subtle, ZIndex = 22 })
  -- quick actions: the first three tabs, as Novoline's tinted tiles
  local quick = addCard(d, "Quick", "bl", 244, 0, 260, 173)
  header(quick, "Quick actions", "zap")
  local picks = {}
  for _, page in ipairs(tabsWanted()) do
    if page.id ~= "home" and #picks < 3 then picks[#picks + 1] = page end
  end
  for n, page in ipairs(picks) do
    local tint = TINT[n]
    local holder = soft(quick.body, 18 + (n - 1) * 78, 46, 68, 109, 18, tint[1], function() N.go(page.id) end)
    glyph(holder, page.icon or "circle", 20, tint[2], { Position = UDim2.fromOffset(12, 14), ZIndex = 26 })
    shrink(text(holder, page.title or page.id, 13, "bold", { Position = UDim2.fromOffset(9, 109 - 14 - 16), Size = UDim2.fromOffset(56, 16), ZIndex = 26 }), 13, 8)
  end
  -- what is playing
  local music = addCard(d, "NowPlaying", "bl", 244, 187, 260, 173)
  header(music, "Now playing", "music")
  local cover = Instance.new("ImageLabel")
  cover.BackgroundColor3, cover.BorderSizePixel = rgb(40, 40, 44), 0
  cover.Position, cover.Size, cover.ScaleType, cover.ZIndex = UDim2.fromOffset(18, 46), UDim2.fromOffset(56, 56), Enum.ScaleType.Crop, 22
  cover.Parent = music.body
  round(cover, 12)
  local coverMark = glyph(cover, "music", 22, P.subtle, { Position = UDim2.fromOffset(17, 17), ZIndex = 23 })
  local songTitle = text(music.body, "Nothing playing", 14, "bold", { Position = UDim2.fromOffset(86, 54), Size = UDim2.fromOffset(156, 18), ZIndex = 22 })
  local songArtist = shrink(text(music.body, "Pick a song from your library", 12, "medium", { Position = UDim2.fromOffset(86, 73), Size = UDim2.fromOffset(156, 16), TextColor3 = P.subtle, ZIndex = 22 }), 12, 9)
  local playIcon
  local controls = {}
  for n, spec in ipairs({ { "skip-back", function() local M = B.Music; if M then M.front().previous() end end },
    { "play", function()
      local M = B.Music
      local ctl = M and M.front()
      if ctl and ctl.track() then ctl.toggle() elseif M and M.openTab then M.openTab() end
    end },
    { "skip-forward", function() local M = B.Music; if M then M.front().next() end end } }) do
    local main = n == 2
    local dim = main and 40 or 34
    local x = ({ 64, 110, 162 })[n]
    local holder, plate = soft(music.body, x, 173 - 18 - 20 - dim / 2, dim, dim, dim / 2, main and P.on or nil, spec[2])
    local isz = main and 16 or 14
    local mark = glyph(holder, spec[1], isz, main and P.ink or P.text, { Position = UDim2.fromOffset((dim - isz) / 2, (dim - isz) / 2), ZIndex = 26 })
    if main then playIcon = mark end
    controls[n] = holder
    local _ = plate
  end
  local coverKey
  local function refreshMusic()
    local M = B.Music
    local ctl = M and M.front()
    local track = ctl and ctl.track()
    local state = ctl and ctl.state() or "idle"
    if track and state ~= "idle" then
      songTitle.Text = track.title or "Playing"
      songArtist.Text = (ctl.status and ctl.status()) or track.artist or (state == "playing" and "Playing" or "Paused")
      if coverKey ~= track.key then
        coverKey = track.key
        cover.Image = ""
        B.try("novoline.cover", ctl.cover, track, cover)
      end
      coverMark.Visible = cover.Image == ""
    else
      songTitle.Text, songArtist.Text = "Nothing playing", "Pick a song from your library"
      cover.Image, coverMark.Visible, coverKey = "", true, nil
    end
    UI.setIcon(playIcon, state == "playing" and "pause" or "play")
    controls[1].Visible = track ~= nil
    controls[3].Visible = track ~= nil
  end
  -- two quick commands under it
  local cmd = addCard(d, "QuickCommands", "bl", 244, 360 + 14, 260, 118)
  text(cmd.body, "Quick Commands", 13, "bold", { Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(190, 16), ZIndex = 22 })
  glyph(cmd.body, "zap", 14, P.subtle, { Position = UDim2.fromOffset(260 - 30, 13), ZIndex = 22 })
  local cmdW = math.floor((260 - 14 * 2 - 10) / 2)
  local commands = {
    { label = "Music", icon = "music", tint = TINT[4], run = function() if B.Music and B.Music.openTab then B.Music.openTab() else N.go("music") end end },
    { label = "Keys", icon = "keyboard", tint = TINT[5], run = function() N.go("keys") end },
  }
  for n, c in ipairs(commands) do
    local holder = soft(cmd.body, 14 + (n - 1) * (cmdW + 10), 36, cmdW, 70, 16, c.tint[1], c.run)
    glyph(holder, c.icon, 22, c.tint[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 24), ZIndex = 26 })
    text(holder, c.label, 12, "bold", { Position = UDim2.fromOffset(0, 70 - 8 - 14), Size = UDim2.fromOffset(cmdW, 14), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 26 })
  end
  -- the game, bottom right
  local gameCard = addCard(d, "Game", "br", 314, 0, 230, 360)
  local shot = Instance.new("ImageLabel")
  shot.Name, shot.BackgroundColor3, shot.BorderSizePixel = "Thumbnail", rgb(30, 30, 33), 0
  shot.Size, shot.ScaleType, shot.ZIndex = UDim2.fromOffset(230, 128), Enum.ScaleType.Crop, 21
  shot.Image = "rbxthumb://type=Asset&id=" .. tostring(game.PlaceId) .. "&w=768&h=432"
  shot.Parent = gameCard.body
  local shotFade = Instance.new("UIGradient")
  shotFade.Rotation = 90
  shotFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1) })
  shotFade.Parent = shot
  local gameIcon = Instance.new("ImageLabel")
  gameIcon.BackgroundColor3, gameIcon.BorderSizePixel = rgb(40, 40, 44), 0
  gameIcon.Position, gameIcon.Size, gameIcon.ZIndex = UDim2.fromOffset(18, 96), UDim2.fromOffset(52, 52), 22
  gameIcon.Image = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"
  gameIcon.Parent = gameCard.body
  round(gameIcon, 14)
  local iconRing = Instance.new("UIStroke"); iconRing.Color, iconRing.Thickness = rgb(12, 12, 14), 3; iconRing.Parent = gameIcon
  local status = B.Registry and B.Registry.status and B.Registry.status() or {}
  local gameName = text(gameCard.body, status.name or "This game", 16, "bold", { Position = UDim2.fromOffset(18, 158), Size = UDim2.fromOffset(194, 20), ZIndex = 22 })
  local gameBy = text(gameCard.body, "", 12, "medium", { Position = UDim2.fromOffset(18, 180), Size = UDim2.fromOffset(194, 16), TextColor3 = P.subtle, ZIndex = 22 })
  text(gameCard.body, status.engineered and "BASED is engineered for it" or ("Place " .. tostring(game.PlaceId)), 12, "medium",
    { Position = UDim2.fromOffset(18, 214), Size = UDim2.fromOffset(194, 16), TextColor3 = P.sub, ZIndex = 22 })
  task.spawn(function()
    local ok, info = pcall(function() return S.MarketplaceService:GetProductInfo(game.PlaceId) end)
    if ok and type(info) == "table" and gameName.Parent then
      if not status.name then gameName.Text = tostring(info.Name or "This game") end
      local creator = type(info.Creator) == "table" and info.Creator.Name
      gameBy.Text = creator and ("By " .. tostring(creator)) or ""
    end
  end)
  local function copy(label, icon, x, value)
    local holder = soft(gameCard.body, x, 252, 94, 32, 16, nil, function()
      local done = B.clipboard and B.clipboard(value())
      Window.toast({ title = label, text = done and "Copied" or "This executor has no clipboard access.", icon = icon, tone = done and "ok" or "warn", time = 2.4 })
    end)
    glyph(holder, icon, 14, P.text, { Position = UDim2.fromOffset(12, 9), ZIndex = 26 })
    shrink(text(holder, label, 12, "bold", { Position = UDim2.fromOffset(31, 8), Size = UDim2.fromOffset(94 - 36, 16), ZIndex = 26 }), 12, 9)
  end
  copy("Copy link", "link", 18, function() return "https://www.roblox.com/games/" .. tostring(game.PlaceId) end)
  copy("Job ID", "copy", 118, function() return game.JobId end)
  -- this server
  local server = addCard(d, "Server", "br", 0, 187, 300, 173)
  header(server, "This server", "server")
  local sv = {}
  for n, key in ipairs({ "Players", "Ping", "Uptime" }) do
    local x = 18 + (n - 1) * 94
    sv[key] = text(server.body, "", 20, "bold", { Position = UDim2.fromOffset(x, 44), Size = UDim2.fromOffset(90, 24), ZIndex = 22 })
    text(server.body, key, 11, "medium", { Position = UDim2.fromOffset(x, 68), Size = UDim2.fromOffset(90, 14), TextColor3 = P.subtle, ZIndex = 22 })
  end
  local function chip(label, icon, x, w, run)
    local holder = soft(server.body, x, 97, w, 30, 15, nil, run)
    glyph(holder, icon, 14, P.text, { Position = UDim2.fromOffset(12, 8), ZIndex = 26 })
    text(holder, label, 12, "bold", { Position = UDim2.fromOffset(32, 0), Size = UDim2.fromOffset(w - 38, 30), ZIndex = 26 })
  end
  chip("Rejoin", "rotate-ccw", 18, 124, function() if B.Server and B.Server.rejoin then B.Server.rejoin() end end)
  chip("Server hop", "shuffle", 150, 132, function() if B.Server and B.Server.hop then B.Server.hop() end end)
  -- your friends
  local friends = addCard(d, "Friends", "br", 0, 0, 300, 173)
  text(friends.body, "Friends online", 14, "bold", { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 18), ZIndex = 22 })
  local friendCount = text(friends.body, "", 14, "bold", { Position = UDim2.fromOffset(200, 16), Size = UDim2.fromOffset(82, 18), TextColor3 = P.subtle,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22 })
  local faces = {}
  for n = 1, 6 do
    local f = Instance.new("ImageLabel")
    f.BackgroundColor3, f.BorderSizePixel = rgb(40, 40, 44), 0
    f.Position, f.Size, f.ZIndex, f.Visible = UDim2.fromOffset(18 + (n - 1) * 27, 48), UDim2.fromOffset(36, 36), 22 + (7 - n), false
    f.Parent = friends.body
    round(f, true)
    local r = Instance.new("UIStroke"); r.Color, r.Thickness = rgb(14, 14, 16), 3; r.Parent = f
    faces[n] = f
  end
  local more = text(friends.body, "", 12, "bold", { Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(70, 36), TextColor3 = P.subtle, ZIndex = 22 })
  local friendLine = text(friends.body, "Looking for your friends", 12, "medium", { Position = UDim2.fromOffset(18, 104), Size = UDim2.fromOffset(264, 16), TextColor3 = P.sub, ZIndex = 22 })
  local friendsAt, totalAsked = -1e9, false
  local function loadFriends()
    if os.clock() - friendsAt < 30 then return end
    friendsAt = os.clock()
    task.spawn(function()
      local ok, list0 = pcall(function() return B.LP:GetFriendsOnline(50) end)
      if not friendLine.Parent then return end
      if not ok or type(list0) ~= "table" then friendLine.Text = "Friends could not be loaded"; return end
      local here = 0
      for _, f in ipairs(list0) do if f.PlaceId == game.PlaceId then here += 1 end end
      for n, f in ipairs(faces) do
        local friend = list0[n]
        f.Visible = friend ~= nil
        if friend then f.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(friend.VisitorId) .. "&w=48&h=48" end
      end
      local shown = math.min(#list0, #faces)
      more.Position = UDim2.fromOffset(18 + math.max(shown - 1, 0) * 27 + 36 + 10, 48)
      more.Text = #list0 > #faces and ("+" .. (#list0 - #faces)) or ""
      friendCount.Text = tostring(#list0)
      stat.Online.Text = tostring(#list0)
      if #list0 == 0 then friendLine.Text = "No friends online right now"
      elseif here == 0 then friendLine.Text = "None of them are in this game"
      else friendLine.Text = here .. (here == 1 and " of them is" or " of them are") .. " playing this game" end
    end)
    if totalAsked then return end
    totalAsked = true
    task.spawn(function()
      local count = 0
      local ok = pcall(function()
        local pages = S.Players:GetFriendsAsync(B.LP.UserId)
        while true do
          count += #pages:GetCurrentPage()
          if pages.IsFinished then break end
          pages:AdvanceToNextPageAsync()
        end
      end)
      if stat.Friends.Parent then stat.Friends.Text = ok and tostring(count) or "0" end
    end)
  end
  local function uptime(seconds)
    seconds = math.floor(seconds or 0)
    if seconds >= 3600 then return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60) end
    return string.format("%dm", math.max(1, seconds // 60))
  end
  d.refresh = function()
    time.Text = os.date("%H:%M")
    date.Text = (string.gsub(os.date("%a %d"), " 0", " "))
    day.Text = dayLine()
    sv.Players.Text = #S.Players:GetPlayers() .. "/" .. S.Players.MaxPlayers
    local hud = B.Hud
    sv.Ping.Text = tostring(hud and hud.ping and math.floor(hud.ping() + 0.5) or 0) .. "ms"
    sv.Uptime.Text = uptime(workspace.DistributedGameTime)
    fpsValue.Text = tostring(hud and hud.fps and math.floor(hud.fps() + 0.5) or 0)
    B.try("novoline.music", refreshMusic)
    loadFriends()
  end
  Motion.every(function()
    if N.open and N.current == "home" then d.refresh() end
  end, 2, "novoline.home")
  return d
end

-- ---------------------------------------------------------------- showing a deck, and changing decks
local shown = nil
-- opening: every card rises out of the dock, in a shuffled order, a moment apart (Novoline's);
-- changing tab: each card glides out of the card that was in its corner, the rest fade
local function showDeck(d, opening, from)
  shown = d
  if d.refresh then B.try("novoline.refresh", d.refresh) end
  local count = #d.cards
  local order = {}
  for i = 1, count do order[i] = i end
  if opening then for i = count, 2, -1 do local j = math.random(i); order[i], order[j] = order[j], order[i] end end
  local used = {}
  for n, item in ipairs(d.cards) do
    item.scale.Scale = N.sizer.Scale
    local delay = math.min((order[n] - 1) * (opening and 0.04 or 0.018), opening and 0.22 or 0.12)
    if item.bare then
      lift(item, delay, opening and 14 or 6)
    elseif opening or not from then
      rise(item, delay)
    else
      local partner
      for _, other in ipairs(from.cards) do
        if not used[other] and not other.bare and other.corner == item.corner and other.frame.Visible and not other.sinking then
          partner, used[other] = other, true
          break
        end
      end
      if partner then
        morph(item, partner.frame.Position, partner.frame.Size, 0)
      else
        local centre = cardRest(item)
        morph(item, UDim2.fromOffset(centre.X, centre.Y), UDim2.fromOffset(item.w * 0.96, item.h * 0.96), delay)
      end
    end
  end
  if from and from ~= d then
    for _, other in ipairs(from.cards) do fadeAway(other) end
  end
end
local function hideDeck(d)
  if not d then return end
  for n, item in ipairs(d.cards) do sink(item, (n - 1) * 0.012) end
end
function N.go(id)
  local source = Window.pages[id]
  if not (source and N.built) then return end
  fold()
  closeMenu()
  hideTip()
  N.current = id
  N.paintNav()
  if not N.open then return end
  local d
  if id == "home" then d = buildHome() else
    local ok, made = pcall(tabDeck, source)
    if not ok then B.fault("novoline.deck." .. tostring(id), made); return end
    d = made
  end
  if shown == d and not N.opening then return end
  local from = (not N.opening) and shown or nil
  -- (Novoline's tab sound on a change of tab, from the dock or anywhere; opening has its own)
  if from and from ~= d then nvSound("tab") end
  showDeck(d, N.opening, from ~= d and from or nil)
end
-- (for a test, or a tab that wants to point at one of its sections: the n-th section of a tab)
function N.pickSection(id, n)
  local d = decks[id]
  if d and d.entry and d.entry.list[n] then pick(d, d.entry.list[n]) end
end
-- a search from elsewhere (the palette): it goes into the deck the tab has
function N.search(value)
  if not (N.built and N.current and N.current ~= "home") then return end
  local d = decks[N.current]
  if d and d.seek then d.seek.Text = value or "" end
end

-- ---------------------------------------------------------------- the window
function N.build()
  if N.built then return end
  N.built = true
  N.since = os.clock()
  pickFont()
  local gui = B.screen(9060)
  gui:SetAttribute("OwnLetters", true)
  N.gui = gui
  N.modal = Instance.new("TextButton")
  N.modal.Text, N.modal.BackgroundTransparency, N.modal.Size, N.modal.Modal, N.modal.Visible = "", 1, UDim2.fromOffset(0, 0), true, false
  N.modal.Parent = gui
  -- the shade over the game while it is open (Novoline's: darker at the top and the bottom); a click on it closes
  local shade = Instance.new("TextButton")
  shade.Name, shade.Text, shade.AutoButtonColor = "Shade", "", false
  shade.Size, shade.BackgroundColor3, shade.BackgroundTransparency, shade.BorderSizePixel, shade.ZIndex = UDim2.fromScale(1, 1), P.black, 1, 0, 1
  shade.Visible = false
  shade.Parent = gui
  local shadeFade = Instance.new("UIGradient")
  shadeFade.Rotation = 90
  shadeFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(0.16, 0.48), NumberSequenceKeypoint.new(0.45, 0.6),
    NumberSequenceKeypoint.new(1, 0.2) })
  shadeFade.Parent = shade
  shade.Activated:Connect(B.safe("novoline.shade", function() if N.open then N.show(false) end end))
  N.shade = shade
  N.sizer = { Scale = scaleNow() }
  -- the dock: Novoline's pill, its capsule, a tab an item
  local bar = box(gui, { Name = "Dock", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(304, DOCK_H), Visible = false, ZIndex = 40 })
  glass(bar, DOCK_H / 2)
  bar:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
  N.bar = bar
  N.barScale = Instance.new("UIScale"); N.barScale.Parent = bar
  local capsule = box(bar, { Name = "Capsule", BackgroundColor3 = P.white, BackgroundTransparency = 1, Size = UDim2.fromOffset(DOCK.w, DOCK.h),
    Position = UDim2.fromOffset(DOCK.pad, DOCK.pad), ZIndex = 52 })
  round(capsule, true)
  local capsuleBody = Instance.new("UIGradient"); capsuleBody.Rotation = 90; capsuleBody.Color = ColorSequence.new(rgb(46, 46, 49), rgb(32, 32, 35)); capsuleBody.Parent = capsule
  local capsuleRim = rim(capsule, P.white, 1)
  pcall(function() capsuleRim.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
  local capsuleLight = Instance.new("UIGradient"); capsuleLight.Rotation = 90
  capsuleLight.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.4, 0.96), NumberSequenceKeypoint.new(1, 0.97) })
  capsuleLight.Parent = capsuleRim
  N.capsule, N.capsuleRim = capsule, capsuleRim
  seat()
  -- (held on its empty parts, the dock moves)
  local barGrip = hit(bar, { ZIndex = 51 })
  local barFrom, barStart
  UI.drag(barGrip, function(point)
    barFrom, barStart = point, Vector2.new(bar.AbsolutePosition.X + bar.AbsoluteSize.X / 2, bar.AbsolutePosition.Y + bar.AbsoluteSize.Y)
  end, function(point)
    local view = screen()
    local inset = UI.inset()
    local bottom = barStart + (point - barFrom)
    bar.Position = UDim2.fromScale(util.clamp01(bottom.X / view.X), util.clamp01((bottom.Y + inset.Y) / view.Y))
  end, function()
    Config.set("app.novoline.x", bar.Position.X.Scale)
    Config.set("app.novoline.y", bar.Position.Y.Scale)
  end)
  -- the overlay: menus, tips, the tab names over the dock
  overlay = box(gui, { Name = "Overlay", Size = UDim2.fromScale(1, 1), ZIndex = 80 })
  tip = text(overlay, "", 12, "medium", { Name = "Tip", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = true,
    TextTruncate = Enum.TextTruncate.None, BackgroundColor3 = P.raised, BackgroundTransparency = 0, Visible = false, ZIndex = 95 })
  round(tip, 8)
  pad(tip, 6, 10, 6, 10)
  local tipMost = Instance.new("UISizeConstraint"); tipMost.MaxSize = Vector2.new(280, math.huge); tipMost.Parent = tip
  labelTip = text(overlay, "", 11, "bold", { Name = "Label", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None, BackgroundColor3 = P.raised, BackgroundTransparency = 0, Visible = false, ZIndex = 96 })
  round(labelTip, true)
  pad(labelTip, 0, 10, 0, 10)
  -- a click outside an open list or menu closes it
  B.connect(UIS.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseButton2 and input.UserInputType ~= Enum.UserInputType.Touch then
      if input.KeyCode == Enum.KeyCode.Escape then closeMenu(); fold() end
      return
    end
    local point = UI.point(input)
    if menu and not UI.inside(menu.frame, point) and not (menu.anchor and menu.anchor.Parent and UI.inside(menu.anchor, point)) then closeMenu() end
    if unfolded and input.UserInputType ~= Enum.UserInputType.MouseButton2 then
      if not (UI.inside(unfolded.frame, point) or (unfolded.anchor and unfolded.anchor.Parent and UI.inside(unfolded.anchor, point))) then fold() end
    end
  end, "novoline.outside")
  -- the screen's size or the hub's scale changes: everything follows
  local function rescale()
    if not N.sizer then return end
    local s = scaleNow()
    N.sizer.Scale = s
    N.barScale.Scale = s
    local all = { homeDeck }
    for _, d in pairs(decks) do all[#all + 1] = d end
    for _, d in ipairs(all) do
      for _, item in ipairs(d.cards) do
        item.scale.Scale = s
        if N.open and d == shown and item.frame.Visible and not item.sinking then settle(item) end
      end
    end
  end
  N.rescale = rescale
  rescale()
  local camera = workspace.CurrentCamera
  if camera then B.connect(camera:GetPropertyChangedSignal("ViewportSize"), rescale, "novoline.viewport") end
  N.rebuildTabs()
end
-- open: the dock pops up, the tab's deck rises out of it, the shade comes down; shut: all of it goes back
local motionToken = 0
function N.show(on)
  if on and not N.built then N.build() end
  if not N.built or N.open == on then
    if N.built and not on then N.bar.Visible = N.active() and Config.get("app.novoline.dock") == true end
    return
  end
  N.open = on
  motionToken += 1
  local mine = motionToken
  closeMenu()
  fold()
  hideTip()
  N.showLabel(nil)
  N.modal.Visible = on and Config.get("app.freeCursor") ~= false
  if on then
    N.rescale()
    N.rebuildTabs()
    local bar = N.bar
    if not bar.Visible then
      bar.Visible = true
      seat()
      if not Motion.reduced then
        N.barScale.Scale = N.sizer.Scale * 0.86
        tween(N.barScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = N.sizer.Scale })
      end
    end
    N.shade.Visible = true
    N.shade.BackgroundTransparency = 1
    tween(N.shade, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 - (Config.get("app.novoline.shade") or 100) / 100 })
    local id = N.current or "home"
    shown = nil
    N.opening = true
    local ok, err = pcall(N.go, id)
    N.opening = false
    if not ok then B.fault("novoline.open", err) end
    nvSound("open")
  else
    for _, d in pairs(decks) do if d.seek and d.seek:IsFocused() then d.seek:ReleaseFocus() end end
    hideDeck(shown)
    N.paintNav()
    tween(N.shade, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
    task.delay(0.36, function()
      if mine ~= motionToken then return end
      N.shade.Visible = false
      -- (the dock goes too, unless it is kept on screen)
      if Config.get("app.novoline.dock") ~= true and not N.open then
        if Motion.reduced then N.bar.Visible = false; return end
        tween(N.barScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = N.sizer.Scale * 0.86 })
        task.delay(0.2, function() if mine == motionToken and not N.open then N.bar.Visible = false; N.barScale.Scale = N.sizer.Scale end end)
      end
    end)
    nvSound("close")
  end
  if Window.onShow then Window.onShow:fire(Window.anyOpen()) end
end
function N.toggle() N.show(not N.open) end
function N.active() return Config.get("app.gui") == "novoline" end

-- ---------------------------------------------------------------- the island: what is playing, every message
local island
function N.islandHasMusic()
  if not (island ~= nil and island.frame.Visible and B.Music ~= nil) then return false end
  local ctl = B.Music.front()
  return ctl.track() ~= nil and ctl.state() ~= "idle"
end
local function islandWanted() return N.active() and Config.get("app.novoline.island") ~= false and Config.get("app.island") ~= false end
local function makeIsland()
  if island or not N.gui then return end
  local frame = box(N.gui, { Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(196, 36), ZIndex = 70 })
  frame.BackgroundColor3 = P.black
  frame.BackgroundTransparency = 0.02
  round(frame, true)
  rim(frame, P.white, 0.9)
  pcall(function()
    local glow = Instance.new("UIShadow")
    glow.Color, glow.BlurRadius, glow.Offset, glow.Transparency, glow.ZIndex = P.black, UDim.new(0, 18), UDim2.fromOffset(0, 6), 0.5, -1
    glow.Parent = frame
  end)
  local sizer = Instance.new("UIScale"); sizer.Parent = frame
  frame.ClipsDescendants = true
  -- what it shows when nothing else is: the name, frames a second, ping
  local idle = box(frame, { Name = "Idle", Size = UDim2.fromScale(1, 1), ZIndex = 71 })
  local dot = box(idle, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(7, 7), BackgroundTransparency = 0, ZIndex = 72 })
  round(dot, true)
  wear(dot, "BackgroundColor3")
  text(idle, "BASED", 12, "black", { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(0, 56, 1, 0), ZIndex = 72 })
  local stats = text(idle, "", 11, "medium", { Position = UDim2.fromOffset(86, 0), Size = UDim2.new(1, -102, 1, 0), TextColor3 = P.dim, ZIndex = 72,
    TextXAlignment = Enum.TextXAlignment.Right })
  -- the song: a turning cover, its name, bars that move with it
  local song = box(frame, { Name = "Song", Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 71 })
  local art = Instance.new("ImageLabel")
  art.BackgroundColor3, art.BorderSizePixel = P.raised, 0
  art.AnchorPoint, art.Position, art.Size = Vector2.new(0, 0.5), UDim2.new(0, 6, 0.5, 0), UDim2.fromOffset(28, 28)
  art.ScaleType, art.ZIndex = Enum.ScaleType.Crop, 72
  art.Parent = song
  round(art, true)
  local songName = B.Music and B.Music.marquee(song, kit, { Position = UDim2.fromOffset(42, 4), Size = UDim2.new(1, -96, 0, 15), ZIndex = 72 }, true, 12)
  local songWho = text(song, "", 10, "medium", { Position = UDim2.fromOffset(42, 19), Size = UDim2.new(1, -96, 0, 13), TextColor3 = P.dim, ZIndex = 72 })
  local bars = {}
  for i = 1, 5 do
    local bar = box(song, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -46 + (i - 1) * 7, 0.5, 0), Size = UDim2.fromOffset(4, 6), BackgroundTransparency = 0, ZIndex = 72 })
    round(bar, true)
    wear(bar, "BackgroundColor3")
    bars[i] = bar
  end
  -- the line being sung, word by word (src/49): it takes the song's place while there is one
  local plainParts = { art, songWho, bars[1], bars[2], bars[3], bars[4], bars[5] }
  if songName then plainParts[#plainParts + 1] = songName.holder end
  local lyricRow = B.Island and B.Island.row(song, { font = face("bold"), size = 13, z = 72, accent = function()
    return B.Card and B.Card.wordColor(accent()) or accent()
  end }) or nil
  if lyricRow then lyricRow.frame.Visible = false end
  -- a message: its icon, title and text
  local note = box(frame, { Name = "Note", Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 71 })
  local chip = box(note, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0, ZIndex = 72 })
  round(chip, true)
  local chipIcon = glyph(chip, "sparkles", 16, P.white, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 73 })
  local noteTitle = text(note, "", 13, "bold", { Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -62, 0, 17), ZIndex = 72 })
  local noteText = text(note, "", 11, "medium", { Position = UDim2.fromOffset(50, 27), Size = UDim2.new(1, -62, 0, 14), TextColor3 = P.dim, ZIndex = 72 })
  local click = hit(frame, { ZIndex = 75 })
  click.Activated:Connect(B.safe("novoline.island", function()
    if island.showing then island.showing.gone = true end
    N.show(true)
  end))
  island = { frame = frame, idle = idle, song = song, note = note, queue = {}, sizer = sizer }
  local level, peak = 0, 4
  local spin = 0
  local coverKey
  local function shape(width, height)
    if island.width ~= width or island.height ~= height then
      island.width, island.height = width, height
      tween(frame, OPEN_INFO, { Size = UDim2.fromOffset(width, height) })
    end
  end
  Motion.every(function(dt)
    local wanted = islandWanted()
    frame.Visible = wanted
    if not wanted then return end
    local camera = workspace.CurrentCamera
    sizer.Scale = math.clamp((camera and camera.ViewportSize.Y or 900) / 1080, 0.8, 1.1) * ((Config.get("app.scale") or 100) / 100)
    frame.Position = UDim2.new(0.5, 0, 0, 10)
    local M = B.Music
    local message = island.showing
    if message and (message.gone or os.clock() > message.till) then island.showing = nil; message = nil end
    if not message and #island.queue > 0 then
      message = table.remove(island.queue, 1)
      message.till = os.clock() + (message.time or 3)
      island.showing = message
      noteTitle.Text, noteText.Text = message.title or "", message.text or ""
      UI.setIcon(chipIcon, message.icon or "sparkles")
      local tone = message.tone
      chip.BackgroundColor3 = tone == "bad" and P.danger or (tone == "warn" and rgb(244, 180, 95) or (tone == "ok" and P.good or accent()))
    end
    local ctl = M and M.front()
    local playing = ctl ~= nil and ctl.track() ~= nil and ctl.state() ~= "idle" and Config.get("music.island") ~= false
    idle.Visible = not message and not playing
    song.Visible = not message and playing == true
    note.Visible = message ~= nil
    if message then
      shape(math.clamp(64 + math.max(#(message.title or ""), #(message.text or "")) * 6.4, 240, 380), (message.text and message.text ~= "") and 48 or 40)
    elseif playing then
      local track = ctl.track()
      -- a line being sung: the row of words (it says how wide it wants the island)
      local want, singing = 300, false
      if lyricRow then want, singing = lyricRow.step(dt, ctl) end
      if lyricRow then lyricRow.frame.Visible = singing end
      for _, part in ipairs(plainParts) do part.Visible = not singing end
      shape(singing and math.floor(want + 0.5) or 300, 40)
      if songName then songName.set(track.title); songName.step(dt) end
      songWho.Text = ctl.status() or track.artist
      if coverKey ~= track.key then coverKey = track.key; ctl.cover(track, art) end
      local live = ctl.state() == "playing"
      if live then spin = (spin + dt * 120) % 360 end
      art.Rotation = spin
      local raw = live and ctl.loudness() or 0
      peak = math.max(peak * (1 - math.min(dt * 0.35, 1)), raw, 4)
      local loud = live and math.clamp(raw / peak * 1.05, 0, 1.15) or 0
      level += (loud - level) * math.min(dt * 12, 1)
      local now = os.clock()
      for i, bar in ipairs(bars) do
        local wobble = 0.45 + 0.55 * math.abs(math.sin(now * (3.1 + i * 0.9) + i))
        bar.Size = UDim2.fromOffset(4, math.clamp(4 + level * 18 * wobble, 4, 22))
      end
    else
      shape(196, 36)
      local hud = B.Hud
      local fps = hud and hud.fps and math.floor(hud.fps() + 0.5) or 0
      local ping = hud and hud.ping and math.floor(hud.ping() + 0.5) or 0
      stats.Text = string.format("%d fps · %d ms", fps, ping)
    end
  end, nil, "novoline.island")
end
function N.island() if N.gui then makeIsland() end end
-- messages go into the island while this look is in use
Window.toastHook = function(opts)
  if not (N.built and islandWanted() and island) then return nil end
  if opts.music and Config.get("music.island") ~= false then return function() end end
  local message = { title = opts.title, text = opts.text, icon = opts.icon, tone = opts.tone, time = opts.time or 3.2 }
  island.queue[#island.queue + 1] = message
  while #island.queue > 4 do table.remove(island.queue, 1) end
  nvSound("notify")
  return function() message.gone = true end
end

-- ---------------------------------------------------------------- the key list, drawn this way
function N.keyPanel(parent)
  local panel = box(parent, { Name = "KeysNovoline", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY })
  glass(panel, 18)
  local least = Instance.new("UISizeConstraint"); least.MinSize = Vector2.new(200, 0); least.Parent = panel
  local stack = box(panel, { Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 2 })
  pad(stack, 12, 14, 12, 14)
  list(stack, 6)
  local head = box(stack, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 0, ZIndex = 2 })
  local title = text(head, "Keybinds", 13, "bold", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3 })
  local body = box(stack, { Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, ZIndex = 2 })
  list(body, 4)
  local api = { frame = panel, rows = {}, shape = nil }
  -- (lit: the key chip turns white, the name bright, a soft wash behind the row; all of it fades)
  local function light(row, on, animate)
    row.on = on
    local goal = { chip = on and P.on or P.raised, key = on and P.knobOn or P.sub, name = on and P.text or P.dim, wash = on and 0.93 or 1 }
    if animate and not Motion.reduced then
      tween(row.chip, SWITCH_INFO, { BackgroundColor3 = goal.chip })
      tween(row.key, SWITCH_INFO, { TextColor3 = goal.key })
      tween(row.name, SWITCH_INFO, { TextColor3 = goal.name })
      tween(row.wash, SWITCH_INFO, { BackgroundTransparency = goal.wash })
      if on then
        row.pop.Scale = 1.2
        Motion.to(row.pop, "Scale", 1, "bouncy")
      end
    else
      row.chip.BackgroundColor3, row.key.TextColor3, row.name.TextColor3, row.wash.BackgroundTransparency = goal.chip, goal.key, goal.name, goal.wash
    end
  end
  function api.forget() api.shape = nil end
  function api.render(binds, moving)
    local shape = B.Keys.shape(binds, moving, 12)
    if shape == api.shape then
      for _, bind in ipairs(binds) do
        local row = api.rows[bind.id]
        if row and row.on ~= bind.on then light(row, bind.on, true) end
      end
      return
    end
    api.shape = shape
    local before = {}
    for id, row in pairs(api.rows) do before[id] = row.on end
    table.clear(api.rows)
    for _, child in ipairs(body:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    title.Text = moving and "Keybinds  ·  drag, then lock" or "Keybinds"
    if #binds == 0 then
      text(body, "Nothing bound yet", 12, "medium", { Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = P.faint, LayoutOrder = 1, ZIndex = 3 })
      return
    end
    for index, bind in ipairs(binds) do
      if index > 12 then
        text(body, "+" .. (#binds - 12) .. " more", 11, "medium", { Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = P.faint, LayoutOrder = index, ZIndex = 3 })
        break
      end
      local line = box(body, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = index, ZIndex = 3 })
      local wash = box(line, { Size = UDim2.new(1, 10, 1, 2), Position = UDim2.fromOffset(-5, -1), BackgroundColor3 = P.white, BackgroundTransparency = 1, ZIndex = 2 })
      round(wash, 8)
      local inner = box(line, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3 })
      list(inner, 8, true)
      local chip = box(inner, { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = P.raised, BackgroundTransparency = 0, LayoutOrder = 1, ZIndex = 3 })
      round(chip, true)
      pad(chip, 0, 7, 0, 7)
      local pop = Instance.new("UIScale"); pop.Parent = chip
      local key = text(chip, Config.keyLabel(bind.key), 10, "bold", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = P.sub, ZIndex = 4 })
      local name = text(inner, bind.label, 12, "medium", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, TextColor3 = P.dim, ZIndex = 3 })
      if bind.kind == "toggle" and bind.mode == "hold" then
        text(inner, "hold", 10, "medium", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, TextColor3 = P.faint, ZIndex = 3 })
      end
      local row = { chip = chip, key = key, name = name, wash = wash, pop = pop }
      api.rows[bind.id] = row
      local was = before[bind.id]
      light(row, was == nil and bind.on or was, false)
      if was ~= nil and was ~= bind.on then light(row, bind.on, true) end
    end
  end
  return api
end

-- ---------------------------------------------------------------- switching to it, and back
-- Novoline's pieces, for the panels of other files drawn in this look (dahood_hunt's)
N.parts = { P = P, TINT = TINT, box = box, round = round, rim = rim, text = text, entryBox = entryBox, hit = hit, glyph = glyph, list = list, pad = pad,
  glass = glass, tile = tile, tween = tween, HOVER = HOVER_INFO }
function N.start()
  Config.define("app.novoline.accent", ACCENT)
  Config.define("app.novoline.font", "gotham")
  Config.define("app.novoline.size", 100)
  Config.define("app.novoline.dock", false)
  Config.define("app.novoline.island", true)
  Config.define("app.novoline.shade", 100)
  Config.define("app.novoline.x", -1)
  Config.define("app.novoline.y", -1)
  Config.define("app.novoline.px", -1)
  Config.define("app.novoline.py", -1)
  Config.define("app.novoline.w", W)
  Config.define("app.novoline.h", H)
  for _, id in ipairs({ "app.novoline.x", "app.novoline.y", "app.novoline.px", "app.novoline.py", "app.novoline.w", "app.novoline.h" }) do Config.unshared(id) end
  Config.on("app.gui", function(look)
    if look == "novoline" then
      Window.show(false)
      N.show(true)
      N.island()
    elseif N.built then
      N.show(false)
      if N.bar then N.bar.Visible = false end
    end
  end)
  Config.on("app.novoline.accent", repaint)
  Config.on("app.novoline.font", function() refont() end)
  Config.on("app.novoline.size", function() if N.rescale then N.rescale() end end)
  Config.on("app.scale", function() if N.rescale then N.rescale() end end)
  Config.on("app.novoline.dock", function(keep)
    if not N.built or N.open or not N.active() then return end
    N.bar.Visible = keep == true
    if keep then N.paintNav(true) end
  end)
  -- a tab added or taken away later (a game's tabs) shows up here as well
  local rebuildNav = Window.rebuildNav
  Window.rebuildNav = function(...)
    rebuildNav(...)
    if N.built then N.rebuildTabs() end
  end
end
end
