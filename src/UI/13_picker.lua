do -- 13_picker.lua
-- ============================================================================
--  13 picker   the first launch: which look to open in
--
--  The first time the hub runs on a machine (nothing saved yet), once the intro
--  is done, three cards fade in: BASED, Novoline and Unnamed, each with a small
--  drawing of what it looks like. A click (or 1, 2, 3) opens that one; it can be
--  changed any time after in Settings > Menu style.
-- ============================================================================
local S, util, Motion, Config = B.S, B.util, B.Motion, B.Config
local UIS = S.UserInputService
local Picker = { active = false }
B.Picker = Picker

local rgb = Color3.fromRGB
local INK, SOFT, FAINT = rgb(245, 244, 239), rgb(170, 170, 180), rgb(110, 110, 120)
local LOOKS = {
  { id = "based", name = "BASED", line = "Glass, a sidebar, and motion everywhere.", accent = rgb(159, 140, 255) },
  { id = "novoline", name = "Novoline", line = "A dock at the bottom. A panel rises from it.", accent = rgb(230, 30, 30) },
  { id = "unnamed", name = "Unnamed", line = "Compact and classic, with pixel letters.", accent = rgb(32, 98, 255) },
}

local function frame(parent, props)
  local item = Instance.new("Frame")
  item.BorderSizePixel = 0
  item.BackgroundTransparency = 1
  for key, value in pairs(props or {}) do item[key] = value end
  item.Parent = parent
  return item
end
local function round(item, radius)
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(0, radius)
  corner.Parent = item
  return corner
end
local function label(parent, text, font, size, color, props)
  local item = Instance.new("TextLabel")
  item.BackgroundTransparency = 1
  item.BorderSizePixel = 0
  item.FontFace = B.F[font] or B.F.text400
  item.TextSize = size
  item.TextColor3 = color
  item.Text = text
  item.TextXAlignment = Enum.TextXAlignment.Left
  for key, value in pairs(props or {}) do item[key] = value end
  item.Parent = parent
  return item
end
local function block(parent, x, y, w, h, color, alpha, radius)
  local item = frame(parent, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, BackgroundTransparency = alpha or 0 })
  if radius then round(item, radius) end
  return item
end

-- ---------------------------------------------------------------- the three drawings (196 x 150)
local DRAW = {}
function DRAW.based(box, accent)
  local glass = block(box, 0, 0, 196, 150, rgb(30, 30, 38), 0, 12)
  local shade = Instance.new("UIGradient")
  shade.Color = ColorSequence.new(rgb(52, 50, 66), rgb(18, 18, 24))
  shade.Rotation = 120
  shade.Parent = glass
  local side = block(glass, 6, 6, 50, 138, rgb(255, 255, 255), 0.93, 9)
  block(side, 8, 9, 24, 5, INK, 0.1, 2)
  for index = 1, 6 do
    local on = index == 2
    local row = block(side, 5, 22 + index * 16, 40, 11, on and accent or INK, on and 0.55 or 0.9, 4)
    if on then block(row, 4, 3, 5, 5, accent, 0, 3) end
  end
  block(glass, 64, 12, 70, 8, INK, 0.15, 3)
  block(glass, 64, 28, 124, 46, rgb(255, 255, 255), 0.92, 8)
  block(glass, 64, 80, 59, 58, rgb(255, 255, 255), 0.92, 8)
  block(glass, 129, 80, 59, 58, rgb(255, 255, 255), 0.92, 8)
  block(glass, 72, 38, 50, 5, INK, 0.4, 2)
  block(glass, 72, 50, 90, 4, INK, 0.7, 2)
  block(glass, 160, 37, 20, 10, accent, 0.1, 5)
end
function DRAW.novoline(box, accent)
  local back = block(box, 0, 0, 196, 150, rgb(10, 10, 11), 0, 12)
  local panel = block(back, 38, 18, 120, 88, rgb(22, 22, 25), 0.02, 10)
  local rim = Instance.new("UIStroke")
  rim.Color, rim.Transparency, rim.Thickness = rgb(255, 255, 255), 0.86, 1
  rim.Parent = panel
  block(panel, 10, 10, 46, 6, INK, 0.1, 3)
  for index = 1, 4 do
    block(panel, 10, 22 + index * 14, 70, 5, INK, 0.72, 2)
    local switch = block(panel, 92, 20 + index * 14, 18, 9, index % 2 == 1 and rgb(242, 242, 244) or rgb(60, 60, 66), 0, 5)
    block(switch, index % 2 == 1 and 10 or 2, 2, 5, 5, rgb(18, 18, 20), 0, 3)
  end
  local dock = block(back, 48, 118, 100, 22, rgb(40, 40, 44), 0, 11)
  for index = 1, 5 do
    local on = index == 3
    block(dock, 8 + (index - 1) * 18, 6, on and 14 or 10, 10, on and rgb(242, 242, 244) or rgb(150, 150, 156), on and 0 or 0.35, 5)
  end
  block(back, 93, 112, 10, 2, accent, 0, 1)
end
function DRAW.unnamed(box, accent)
  local back = block(box, 0, 0, 196, 150, rgb(14, 14, 16), 0, 4)
  local edge = Instance.new("UIStroke")
  edge.Color, edge.Transparency, edge.Thickness = rgb(60, 60, 66), 0, 1
  edge.Parent = back
  block(back, 0, 0, 196, 2, accent, 0)
  for index = 1, 4 do
    local on = index == 1
    block(back, 8 + (index - 1) * 46, 8, 40, 12, on and accent or rgb(34, 34, 38), on and 0.2 or 0, 2)
  end
  for column = 0, 1 do
    local x = 8 + column * 94
    block(back, x, 28, 86, 114, rgb(22, 22, 25), 0, 2)
    for row = 1, 6 do
      local ticked = (row + column) % 3 ~= 0
      block(back, x + 6, 22 + row * 17, 8, 8, ticked and accent or rgb(48, 48, 54), 0, 1)
      block(back, x + 20, 24 + row * 17, 40 + (row * 7 + column * 11) % 22, 4, INK, 0.65, 1)
    end
  end
end

-- ---------------------------------------------------------------- the picker
-- done(look): look is "based", "novoline" or "unnamed"
function Picker.show(done)
  if Picker.active then return end
  Picker.active = true
  local gui = B.screen(9650)
  gui:SetAttribute("OwnLetters", true)
  local view = B.viewport()
  local k = math.clamp(math.min(view.Y / 1080, view.X / 1280), 0.55, 1.6)
  local shade = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(4, 4, 6), BackgroundTransparency = 1 })
  local veil = Instance.new("TextButton")          -- (frees the cursor and keeps clicks from the game)
  veil.Text, veil.AutoButtonColor, veil.BackgroundTransparency, veil.Size, veil.Modal, veil.ZIndex = "", false, 1, UDim2.fromScale(1, 1), true, 1
  veil.Parent = gui
  local stage = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(780, 430), ZIndex = 2 })
  local scale = Instance.new("UIScale")
  scale.Scale = k
  scale.Parent = stage
  local title = label(stage, "Pick your interface", "wideBold", 26, INK, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(780, 34),
    TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1 })
  local sub = label(stage, "You can change it any time in Settings, under Menu style.", "text400", 14, SOFT, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40),
    Size = UDim2.fromOffset(780, 20), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1 })
  local cards, chosen = {}, false
  -- (picked from outside: the same as a click on that card)
  function Picker.pick(look) if Picker.active then Picker.finish(look) end end

  local function finish(look)
    if chosen then return end
    chosen = true
    for _, card in ipairs(cards) do
      local mine = card.look.id == look
      Motion.tween(mine and 0.5 or 0.3, Motion.ease.outCubic, function(p)
        card.fade(mine and 0 or p)
        if mine then card.scale.Scale = 1.04 + 0.03 * math.sin(p * math.pi) end
      end)
    end
    task.delay(0.42, function()
      Motion.tween(0.38, Motion.ease.inCubic, function(p)
        shade.BackgroundTransparency = 0.25 + 0.75 * p
        title.TextTransparency, sub.TextTransparency = p, math.max(p, 0.2)
        for _, card in ipairs(cards) do card.fade(math.max(p, card.look.id == look and 0 or 1)) end
      end, function()
        gui:Destroy()
        Picker.active = false
        done(look)
      end)
    end)
  end

  Picker.finish = finish
  for index, look in ipairs(LOOKS) do
    local x = (index - 2) * 252
    local card = frame(stage, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 104), Size = UDim2.fromOffset(228, 300), BackgroundColor3 = rgb(18, 18, 22),
      BackgroundTransparency = 1, ZIndex = 2 })
    round(card, 16)
    local cardScale = Instance.new("UIScale")
    cardScale.Parent = card
    local rim = Instance.new("UIStroke")
    rim.Color, rim.Thickness, rim.Transparency = rgb(255, 255, 255), 1.2, 1
    rim.Parent = card
    local art = frame(card, { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(196, 150), ZIndex = 3 })
    local group = Instance.new("CanvasGroup")
    group.BackgroundTransparency, group.BorderSizePixel, group.Size, group.GroupTransparency = 1, 0, UDim2.fromScale(1, 1), 1
    group.Parent = art
    DRAW[look.id](group, look.accent)
    local name = label(card, look.name, "wideBold", 17, INK, { Position = UDim2.fromOffset(18, 184), Size = UDim2.fromOffset(192, 22), TextTransparency = 1, ZIndex = 3 })
    local line = label(card, look.line, "text400", 13, SOFT, { Position = UDim2.fromOffset(18, 212), Size = UDim2.fromOffset(192, 40), TextWrapped = true,
      TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 1, ZIndex = 3 })
    local key = label(card, tostring(index), "mono500", 11, FAINT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 266), Size = UDim2.fromOffset(18, 18),
      TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 1, ZIndex = 3 })
    round(key, 5)
    local tag = label(card, "Open", "text500", 12, look.accent, { Position = UDim2.fromOffset(18, 266), Size = UDim2.fromOffset(120, 18), TextTransparency = 1, ZIndex = 3 })
    local entry = { look = look, frame = card, scale = cardScale, hovered = false }
    -- 0 shown, 1 gone (and the rim, which lights on hover)
    function entry.fade(alpha)
      card.BackgroundTransparency = 0.08 + 0.92 * alpha
      group.GroupTransparency = alpha
      name.TextTransparency, line.TextTransparency = alpha, alpha
      key.TextTransparency, key.BackgroundTransparency = alpha, 0.92 + 0.08 * alpha
      tag.TextTransparency = entry.hovered and alpha or 1
      rim.Transparency = entry.hovered and (0.15 + 0.85 * alpha) or (0.88 + 0.12 * alpha)
      rim.Color = entry.hovered and look.accent or rgb(255, 255, 255)
    end
    entry.fade(1)
    local hit = Instance.new("TextButton")
    hit.Text, hit.AutoButtonColor, hit.BackgroundTransparency, hit.Size, hit.ZIndex = "", false, 1, UDim2.fromScale(1, 1), 5
    hit.Parent = card
    hit.MouseEnter:Connect(function()
      if chosen then return end
      entry.hovered = true
      Motion.to(cardScale, "Scale", 1.035, "snappy")
      entry.fade(0)
    end)
    hit.MouseLeave:Connect(function()
      if chosen then return end
      entry.hovered = false
      Motion.to(cardScale, "Scale", 1, "snappy")
      entry.fade(0)
    end)
    hit.Activated:Connect(function() finish(look.id) end)
    cards[index] = entry
  end

  -- in: the room darkens, the words come up, the cards rise one after another
  Motion.tween(0.6, Motion.ease.outCubic, function(p)
    shade.BackgroundTransparency = 1 - 0.75 * p
    title.TextTransparency, sub.TextTransparency = 1 - p, 1 - p * 0.9
    title.Position = UDim2.new(0.5, 0, 0, 10 * (1 - p))
  end)
  for index, entry in ipairs(cards) do
    task.delay(0.18 + index * 0.09, function()
      local x = (index - 2) * 252
      Motion.tween(0.55, Motion.ease.outCubic, function(p)
        if chosen then return end
        entry.frame.Position = UDim2.new(0.5, x, 0, 104 + 26 * (1 - p))
        entry.fade(1 - p)
      end)
    end)
  end
  -- 1, 2, 3 on the keyboard
  local keys = { One = 1, Two = 2, Three = 3, KeypadOne = 1, KeypadTwo = 2, KeypadThree = 3 }
  local link
  link = B.connect(UIS.InputBegan, function(input)
    if chosen then return end
    local pick = keys[input.KeyCode.Name]
    if pick and LOOKS[pick] then finish(LOOKS[pick].id) end
  end, "picker.keys")
  gui.Destroying:Connect(function() pcall(function() link:Disconnect() end) end)
end
end
