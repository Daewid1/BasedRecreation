do -- 52_unnamed.lua
-- ============================================================================
--  52 unnamed    the second look: the old dark menu with its tabs along the top
--
--  The same tabs and the same settings as the BASED window, drawn the way the
--  classic two-column menus are: a square to tick, a bar that fills with its
--  value written on it, a box with a coloured line on top and its title in
--  small letters. Every control here is bound to the very flag its BASED twin
--  is, so the two windows always agree and either one can be used. One is shown
--  at a time: Settings > Menu style, or the button at the top of either window.
--
--  A tab's own drawing (a custom block) can give a version of itself for this
--  window (page:custom(height, build, alt)); one that does not is drawn as it
--  is, inside a box.
-- ============================================================================
local S, util, Motion, UI, Config, Window, Controls = B.S, B.util, B.Motion, B.UI, B.Config, B.Window, B.Controls
local UIS = S.UserInputService
local U = { open = false, built = false, pages = {}, tabs = {} }
B.Unnamed = U

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- the old menu's colours: near black, one grey for boxes, one for what can be clicked, and the accent
local C = {
  back = rgb(12, 12, 12), frame = rgb(18, 18, 18), box = rgb(21, 21, 21), edge = rgb(44, 44, 44), dark = rgb(4, 4, 4),
  field = rgb(31, 31, 31), fieldHi = rgb(40, 40, 40), text = rgb(226, 226, 226), dim = rgb(152, 152, 152), faint = rgb(96, 96, 96),
  tab = rgb(16, 16, 16), tabOn = rgb(27, 27, 27),
}
U.C = C
local ACCENT = rgb(32, 98, 255)
local W, H = 566, 640                  -- design pixels; scaled with the screen
local FONT, BOLD

-- ---------------------------------------------------------------- the letters
-- Settings > Unnamed letters. Monocraft first: the Minecraft letters the old menu was drawn in.
-- `size` is how big each set is drawn against the 13 px the menu was laid out in, so each reads at
-- about the same height (measured in game: the height of "Hg" at 13 px against Arial's).
local FONTS = {
  { "monocraft", "Monocraft", function() return B.F.craft end, 1 },
  { "proggy", "Proggy Clean", function() return B.F.proggy end, 1.25 },
  { "proggytiny", "Proggy Tiny", function() return B.F.proggyTiny end, 1.35 },
  { "arial", "Arial", function() return Font.fromEnum(Enum.Font.Arial) end, 1 },
  { "roboto", "Roboto Mono", function() return Font.fromName("RobotoMono") end, 0.95 },
  { "builder", "Builder Sans", function() return Font.fromName("BuilderSans") end, 1 },
  { "gotham", "Gotham", function() return Font.fromName("GothamSSm") end, 0.95 },
  { "ubuntu", "Ubuntu", function() return Font.fromName("Ubuntu") end, 1 },
  { "inter", "Inter", function() return (B.F0 or B.F).text500 end, 0.97 },
  { "geist", "Geist Mono", function() return (B.F0 or B.F).mono400 end, 0.95 },
  { "arcade", "Arcade", function() return Font.fromEnum(Enum.Font.Arcade) end, 0.75 },
  { "michroma", "Michroma", function() return Font.fromName("Michroma") end, 0.85 },
  { "jura", "Jura", function() return Font.fromName("Jura") end, 1.05 },
  { "sarpanch", "Sarpanch", function() return Font.fromName("Sarpanch") end, 1.05 },
  { "titillium", "Titillium", function() return Font.fromName("TitilliumWeb") end, 1.02 },
}
U.FONTS = FONTS
-- Every label and box drawn here, with its size at 100%. Kept STRONG and swept: a weak-keyed table
-- of Instances loses entries while they are still on screen (their Lua handle is collected and a new
-- one made later), and those labels never took a newly picked font. That was the "fonts don't
-- change fully" bug: whatever had been collected kept the old letters.
local typed = {}
local bolded = {}
local factor = 1
U.fontChanged = B.Signal.new()
local function fontSpec(id)
  for _, spec in ipairs(FONTS) do if spec[1] == id then return spec end end
  return FONTS[1]
end
local function sizeOf(base) return math.max(6, math.floor(base * factor + 0.5)) end
local function pickFont()
  local spec = fontSpec(Config.get("app.unnamed.font"))
  local ok, face = pcall(spec[3])
  FONT = (ok and typeof(face) == "Font") and face or Font.fromEnum(Enum.Font.Arial)
  local okBold, bold = pcall(Font.new, FONT.Family, Enum.FontWeight.Bold, FONT.Style)
  BOLD = okBold and bold or FONT
  factor = spec[4] * ((Config.get("app.unnamed.textSize") or 100) / 100)
end
-- a label or a box takes the menu's letters, and keeps them when they change
local function letters(item, base, bold)
  if not FONT then pickFont() end
  typed[item] = base
  if bold then bolded[item] = true end
  item.FontFace = bold and BOLD or FONT
  item.TextSize = sizeOf(base)
  return item
end
local function refont()
  pickFont()
  for item, base in pairs(typed) do
    if item.Parent then
      item.FontFace = bolded[item] and BOLD or FONT
      item.TextSize = sizeOf(base)
    else
      typed[item], bolded[item] = nil, nil
    end
  end
  U.fontChanged:fire()
end
-- (gone ones swept now and then, so a menu rebuilt many times does not keep them all)
local function sweepTyped()
  for item in pairs(typed) do
    if not item.Parent then typed[item], bolded[item] = nil, nil end
  end
end
U.sweepTyped = sweepTyped
function U.font() if not FONT then pickFont() end return FONT, BOLD end
-- (drawn in this look's letters: the BASED font setting leaves it alone)
function U.owns(item) return typed[item] ~= nil end

-- ---------------------------------------------------------------- the accent, kept on everything that wears it
local accented = {}
local function accent() return Config.get("app.unnamed.accent") or ACCENT end
local function wear(instance, property)
  accented[#accented + 1] = { instance, property }
  instance[property] = accent()
  return instance
end
local function repaint()
  local color = accent()
  for index = #accented, 1, -1 do
    local entry = accented[index]
    if entry[1].Parent then entry[1][entry[2]] = color else table.remove(accented, index) end
  end
end

-- ---------------------------------------------------------------- pieces
local function box(parent, props)
  local frame = Instance.new("Frame")
  frame.BorderSizePixel = 0
  frame.BackgroundColor3 = C.box
  if props then
    for key, value in pairs(props) do frame[key] = value end
  end
  frame.Parent = parent
  return frame
end
-- a 1 px line round it, the way these menus draw every box
local function lined(frame, color)
  frame.BorderSizePixel = 1
  frame.BorderMode = Enum.BorderMode.Inset
  frame.BorderColor3 = color or C.edge
  return frame
end
local function text(parent, value, props, bold)
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency = 1
  label.BorderSizePixel = 0
  label.TextSize = 13
  label.TextColor3 = C.text
  label.TextXAlignment = Enum.TextXAlignment.Left
  label.Text = value or ""
  if props then
    for key, v in pairs(props) do label[key] = v end
  end
  letters(label, label.TextSize, bold)
  label.Parent = parent
  return label
end
-- a box to type in, in the menu's letters
local function entryBox(parent, size)
  local entry = Instance.new("TextBox")
  entry.BackgroundTransparency, entry.BorderSizePixel = 1, 0
  entry.TextColor3, entry.PlaceholderColor3 = C.text, C.faint
  entry.TextXAlignment, entry.ClearTextOnFocus, entry.ClipsDescendants = Enum.TextXAlignment.Left, false, true
  letters(entry, size or 12)
  entry.Parent = parent
  return entry
end
local function hit(parent, props)
  local button = Instance.new("TextButton")
  button.Text = ""
  button.BackgroundTransparency = 1
  button.BorderSizePixel = 0
  button.AutoButtonColor = false
  button.Size = UDim2.fromScale(1, 1)
  button.ZIndex = 8
  if props then
    for key, value in pairs(props) do button[key] = value end
  end
  button.Parent = parent
  return button
end
local function lower(value) return string.lower(tostring(value or "")) end
local function list(parent, gap, horizontal)
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, gap or 0)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
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
local function options(spec)
  local out = {}
  for _, option in ipairs(spec or {}) do
    if type(option) == "table" then out[#out + 1] = { value = option.value or option[1], label = option.label or option[2] or tostring(option.value or option[1]) }
    else out[#out + 1] = { value = option, label = tostring(option) } end
  end
  return out
end

-- ---------------------------------------------------------------- the floating bits: a tip, a list, a colour
-- (all inside the window, so they scale with it; placed from where the thing they belong to is)
local function within(gui)
  local scale = U.sizer and U.sizer.Scale or 1
  return (gui.AbsolutePosition - U.holder.AbsolutePosition) / scale, gui.AbsoluteSize / scale
end
local tip, tipFor
local function hideTip()
  tipFor = nil
  if tip then tip.Visible = false end
end
-- the window's size in design pixels (it can be dragged bigger)
local function frameSize()
  local scale = U.sizer and U.sizer.Scale or 1
  return U.holder and U.holder.AbsoluteSize / scale or Vector2.new(W, H)
end
-- `label`, when given: a name that may be cut short on its row; cut, the tip says it whole
local function tooltip(button, desc, label)
  if (not desc or desc == "") and not label then return end
  button.MouseEnter:Connect(function()
    tipFor = button
    task.delay(0.45, function()
      if tipFor ~= button or not (U.open and button.Parent) then return end
      local value = desc or ""
      if label and label.Parent and not label.TextFits then value = label.Text .. (value ~= "" and ("  -  " .. value) or "") end
      if value == "" then return end
      local at, size = within(button)
      tip.Text = value
      tip.Position = UDim2.fromOffset(at.X + 10, at.Y + size.Y + 4)
      tip.Visible = true
      -- (kept inside the window: moved left of a right edge, above a bottom one, once it has its size)
      task.defer(function()
        if tipFor ~= button or not tip.Visible then return end
        local scale = U.sizer and U.sizer.Scale or 1
        local tipSize, room = tip.AbsoluteSize / scale, frameSize()
        local x, y = at.X + 10, at.Y + size.Y + 4
        if x + tipSize.X > room.X - 4 then x = math.max(4, room.X - 4 - tipSize.X) end
        if y + tipSize.Y > room.Y - 4 then y = math.max(4, at.Y - tipSize.Y - 4) end
        tip.Position = UDim2.fromOffset(x, y)
      end)
    end)
  end)
  button.MouseLeave:Connect(function() if tipFor == button then hideTip() end end)
end
local popup                           -- the open list or colour picker: { frame, anchor, close }
local function closePopup()
  if popup then
    local open = popup
    popup = nil
    open.frame:Destroy()
    if open.locked and open.locked.Parent then open.locked.ScrollingEnabled = true end
    if open.closed then open.closed() end
  end
end
-- The page an open list or colour sits on stays where it is until it closes: the wheel over the
-- list scrolls the list alone. (Before, the wheel went through to the page, the page moved, and
-- moving closed the list.) A click anywhere else closes it and the page scrolls again.
local function lockPage(anchor)
  for _, entry in pairs(U.pages) do
    local scroller = entry.scroller
    if scroller and anchor and anchor:IsDescendantOf(scroller) then
      scroller.ScrollingEnabled = false
      return scroller
    end
  end
  return nil
end
U.closePopup = closePopup
-- a list under `anchor`: items = { { label, checked } }, pick(index) -> keep open?
local function openList(anchor, items, pick, multi)
  closePopup()
  local at, size = within(anchor)
  local rows = math.min(#items, 12)
  local tall = rows * 17 + 4
  -- (under it, or over it when the window ends first)
  local y = at.Y + size.Y + 1
  if y + tall > frameSize().Y - 2 and at.Y - tall - 1 >= 2 then y = at.Y - tall - 1 end
  local frame = lined(box(U.holder, { Name = "List", Position = UDim2.fromOffset(at.X, y), Size = UDim2.fromOffset(size.X, tall),
    BackgroundColor3 = C.field, ZIndex = 60 }), C.dark)
  local scroller = Instance.new("ScrollingFrame")
  scroller.BackgroundTransparency, scroller.BorderSizePixel = 1, 0
  scroller.Size, scroller.Position = UDim2.new(1, -2, 1, -4), UDim2.fromOffset(1, 2)
  scroller.CanvasSize = UDim2.fromOffset(0, #items * 17)
  scroller.ScrollBarThickness = #items > rows and 3 or 0
  scroller.ScrollingDirection = Enum.ScrollingDirection.Y
  scroller.ZIndex = 61
  wear(scroller, "ScrollBarImageColor3")
  scroller.Parent = frame
  local labels = {}
  for index, item in ipairs(items) do
    local row = box(scroller, { Position = UDim2.fromOffset(0, (index - 1) * 17), Size = UDim2.new(1, 0, 0, 17), BackgroundColor3 = C.fieldHi, BackgroundTransparency = 1, ZIndex = 62 })
    local label = text(row, item[1], { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -10, 1, 0), TextSize = 12, ZIndex = 63, TextTruncate = Enum.TextTruncate.AtEnd })
    labels[index] = label
    if item[2] then wear(label, "TextColor3") end
    local button = hit(row, { ZIndex = 64 })
    button.MouseEnter:Connect(function() row.BackgroundTransparency = 0 end)
    button.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
    button.Activated:Connect(B.safe("unnamed.list", function()
      local checked = pick(index)
      if multi then
        item[2] = checked
        if checked then wear(label, "TextColor3") else label.TextColor3 = C.text end
      else
        closePopup()
      end
    end))
  end
  popup = { frame = frame, anchor = anchor, locked = lockPage(anchor) }
  return frame
end
-- a colour: a square of saturation and value, a strip of hue
local function openColor(anchor, initial, set)
  closePopup()
  local at, size = within(anchor)
  local h, s, v = initial:ToHSV()
  local y = at.Y + size.Y + 2
  if y + 166 > frameSize().Y - 2 and at.Y - 168 >= 2 then y = at.Y - 168 end
  local frame = lined(box(U.holder, { Name = "Colour", Position = UDim2.fromOffset(math.max(at.X + size.X - 150, 4), y), Size = UDim2.fromOffset(150, 166),
    BackgroundColor3 = C.field, ZIndex = 60 }), C.dark)
  local square = box(frame, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(138, 128), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 61 })
  local white = box(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62 })
  local fade = Instance.new("UIGradient"); fade.Transparency = NumberSequence.new(0, 1); fade.Parent = white
  local black = box(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 63 })
  local down = Instance.new("UIGradient"); down.Rotation = 90; down.Transparency = NumberSequence.new(1, 0); down.Parent = black
  local dot = lined(box(square, { Size = UDim2.fromOffset(5, 5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 65 }), C.dark)
  local hue = box(frame, { Position = UDim2.fromOffset(6, 140), Size = UDim2.fromOffset(138, 10), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 61 })
  local stops = {}
  for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
  local rainbow = Instance.new("UIGradient"); rainbow.Color = ColorSequence.new(stops); rainbow.Parent = hue
  local mark = lined(box(hue, { Size = UDim2.fromOffset(3, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63 }), C.dark)
  local function show()
    square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    dot.Position = UDim2.fromScale(s, 1 - v)
    mark.Position = UDim2.fromScale(h, 0.5)
  end
  show()
  local function emit() show(); set(Color3.fromHSV(h, s, v)) end
  local squareHit = hit(square, { ZIndex = 66 })
  UI.drag(squareHit, function(point)
    s = util.clamp01((point.X - square.AbsolutePosition.X) / square.AbsoluteSize.X); v = 1 - util.clamp01((point.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y); emit()
  end, function(point)
    s = util.clamp01((point.X - square.AbsolutePosition.X) / square.AbsoluteSize.X); v = 1 - util.clamp01((point.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y); emit()
  end)
  local hueHit = hit(hue, { ZIndex = 66, Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4) })
  UI.drag(hueHit, function(point) h = util.clamp01((point.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X); emit() end,
    function(point) h = util.clamp01((point.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X); emit() end)
  popup = { frame = frame, anchor = anchor, locked = lockPage(anchor) }
end

-- ---------------------------------------------------------------- a key for a flag (right click on a control)
local function bindKey(id, label, chip, refresh)
  if not id then return end
  chip.Visible, chip.Text = true, "..."
  Controls.captureKey(function(key, cancelled)
    if not cancelled then
      Config.bind(id, key)
      Window.toast({ title = key and ("Bound to " .. Config.keyLabel(key)) or "Key cleared", text = label, icon = "keyboard", time = 2 })
    end
    refresh()
  end)
end
-- right click: a short list under the row (bind / hold to use / clear / back to default)
local function keyMenu(id, label, kind, line, chip, refresh)
  if not id then return end
  local bind = Config.bindOf(id)
  local items, runs = {}, {}
  local function add(value, run, checked) items[#items + 1] = { value, checked == true }; runs[#items] = run end
  add(bind and bind.key and ("change key (" .. lower(Config.keyLabel(bind.key)) .. ")") or "bind a key", function() bindKey(id, label, chip, refresh) end)
  if bind and bind.key then
    if kind == "toggle" then add("hold to use", function() Config.bind(id, bind.key, bind.mode == "hold" and "toggle" or "hold") end, bind.mode == "hold") end
    add("clear the key", function() Config.bind(id, nil) end)
  end
  if kind ~= "button" and Config.get(id) ~= nil then add("back to default", function() Config.reset(id) end) end
  openList(line, items, function(index)
    local run = runs[index]
    if run then task.defer(run) end
    return false
  end, false)
end
local function keyChip(row)
  return lined(text(row, "", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 14), TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = C.field, BackgroundTransparency = 0, Visible = false, ZIndex = 4 }), C.dark)
end

-- ---------------------------------------------------------------- a section and its controls
local Section = {}
Section.__index = Section
local function row(section, height)
  section.count += 1
  return box(section.body, { Name = "Row", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = section.count })
end
local function sub(section, holder)
  return setmetatable({ body = holder, count = 0, page = section.page, card = section.card }, Section)
end
-- a row the search box can find, by its name and what it says it does
local function findable(section, frame, label, desc)
  local page = section.page
  if not (page and page.rows) then return end
  page.rows[#page.rows + 1] = { frame = frame, card = section.card, text = lower(tostring(label or "") .. " " .. tostring(desc or "")) }
end

function Section:toggle(spec)
  local id = spec.id
  local bindable = spec.bindable ~= false
  local value = id and Config.define(id, spec.default == true) or (spec.default == true)
  local line = row(self, 16)
  findable(self, line, spec.label, spec.desc)
  local square = lined(box(line, { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 1, 0.5, -5), BackgroundColor3 = C.field }), C.dark)
  local fill = wear(box(square, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }), "BackgroundColor3")
  local label = text(line, lower(spec.label), { Position = UDim2.fromOffset(17, 0), Size = UDim2.new(1, -56, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
  local chip = keyChip(line)
  local children
  local function paint()
    fill.Visible = value
    label.TextColor3 = value and C.text or C.dim
    if children then children.Visible = value end
  end
  local function showKey()
    local bind = id and Config.bindOf(id)
    chip.Visible = bind ~= nil and bind.key ~= nil
    if chip.Visible then chip.Text = Config.keyLabel(bind.key) .. (bind.mode == "hold" and "*" or "") end
    -- (the name has the whole row when there is no key on it)
    label.Size = UDim2.new(1, chip.Visible and -56 or -18, 1, 0)
  end
  if spec.children then
    self.count += 1
    children = box(self.body, { Name = "Sub", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self.count })
    pad(children, 0, 0, 0, 14)
    list(children, 5)
    B.try("unnamed.children", spec.children, sub(self, children))
  end
  paint()
  showKey()
  if id then
    Config.on(id, function(next)
      value = next == true
      if line.Parent then paint() end
      if spec.changed then spec.changed(value) end
    end)
    Config.bindsChanged:connect(function(changed) if changed == id and chip.Parent then showKey() end end)
    if bindable then Controls.bindables[id] = Controls.bindables[id] or { label = spec.label or id, kind = "toggle", page = self.page.source } end
  end
  local button = hit(line)
  button.MouseEnter:Connect(function() label.TextColor3 = C.text end)
  button.MouseLeave:Connect(function() paint() end)
  button.Activated:Connect(B.safe("unnamed.toggle", function()
    if id then Config.set(id, not value) else
      value = not value
      paint()
      if spec.changed then B.try("toggle", spec.changed, value) end
    end
  end))
  button.MouseButton2Click:Connect(function() if bindable then keyMenu(id, spec.label, "toggle", line, chip, showKey) end end)
  tooltip(button, (spec.tip or spec.desc) and ((spec.tip or spec.desc) .. (bindable and id and "  (right click: its key)" or "")) or nil, label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = function(next) if id then Config.set(id, next == true) end end, open = function() end }
end

function Section:slider(spec)
  local id = spec.id
  local min, max, step = spec.min or 0, spec.max or 100, spec.step or 1
  local decimals = spec.decimals or (step < 1 and math.max(0, math.ceil(-math.log10(step))) or 0)
  local curve = spec.curve or 1
  local value = id and Config.define(id, spec.default or min) or (spec.default or min)
  local line = row(self, 16)
  findable(self, line, spec.label, spec.desc)
  local bar = lined(box(line, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.field }), C.dark)
  local fill = wear(box(bar, { Size = UDim2.fromScale(0, 1), ZIndex = 2 }), "BackgroundColor3")
  -- (its name on the left, cut short if it must be; its value on the right, always whole)
  local label = text(bar, lower(spec.label), { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(0.66, -7, 1, 0), TextSize = 12, TextStrokeTransparency = 0.5,
    ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd })
  local amount = text(bar, "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 0), Size = UDim2.new(0.34, -3, 1, 0), TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.5, ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd })
  local function shown(v) return (spec.format and spec.format(v)) or (util.format(v, decimals) .. (spec.suffix or "")) end
  local function place()
    fill.Size = UDim2.fromScale(util.clamp01((value - min) / math.max(max - min, 1e-9)) ^ (1 / curve), 1)
    amount.Text = shown(value)
  end
  place()
  local function set(next)
    next = math.clamp(util.round(next, step), min, max)
    if decimals > 0 then next = tonumber(string.format("%." .. decimals .. "f", next)) or next end
    if next == value then return end
    if id then Config.set(id, next) else
      value = next
      place()
      if spec.changed then B.try("slider", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if bar.Parent then place() end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(bar)
  local function at(point) set(min + util.clamp01((point.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)) ^ curve * (max - min)) end
  UI.drag(button, function(point) at(point) end, function(point) at(point) end)
  -- (right click: type a number, for the far end of a long range)
  button.MouseButton2Click:Connect(function()
    local field = entryBox(bar, 12)
    field.BackgroundTransparency, field.BackgroundColor3 = 0, C.fieldHi
    field.Size, field.Position, field.ZIndex = UDim2.fromScale(1, 1), UDim2.new(), 9
    field.TextXAlignment = Enum.TextXAlignment.Center
    field.Text, field.ClearTextOnFocus, field.PlaceholderText = "", true, lower(spec.label) .. "..."
    field.FocusLost:Connect(B.safe("unnamed.slider.type", function()
      local typed = tonumber((string.gsub(field.Text, "[^%d%.%-eE]", "")))
      field:Destroy()
      if typed then set(typed) end
    end))
    field:CaptureFocus()
  end)
  button.MouseEnter:Connect(function() bar.BackgroundColor3 = C.fieldHi end)
  button.MouseLeave:Connect(function() bar.BackgroundColor3 = C.field end)
  tooltip(button, ((spec.tip or spec.desc) and ((spec.tip or spec.desc) .. "  ") or "") .. "(right click: type a number)", label)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = set }
end

-- a box that opens a list: one value (dropdown, segmented) or several (multi)
local function chooser(section, spec, many)
  local id = spec.id
  local choices = options(spec.options)
  local first = choices[1] and choices[1].value
  local value
  if many then value = id and Config.define(id, spec.default or {}) or (spec.default or {})
  else value = id and Config.define(id, spec.default ~= nil and spec.default or first) or (spec.default ~= nil and spec.default or first) end
  local line = row(section, 34)
  findable(section, line, spec.label, spec.desc)
  text(line, lower(spec.label), { Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.dim, TextSize = 12 })
  local field = lined(box(line, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.field }), C.dark)
  local label = text(field, "", { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -22, 1, 0), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd })
  local arrow = text(field, "v", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 0), Size = UDim2.new(0, 10, 1, 0), TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim })
  local function has(v) return table.find(value, v) ~= nil end
  local function summary()
    if not many then
      for _, option in ipairs(choices) do if option.value == value then return option.label end end
      return tostring(value)
    end
    if #value == 0 then return spec.empty or "--" end
    local names = {}
    for _, option in ipairs(choices) do if has(option.value) then names[#names + 1] = option.label end end
    return table.concat(names, ", ")
  end
  label.Text = summary()
  local function set(next)
    if id then Config.set(id, next) else
      value = next
      label.Text = summary()
      if spec.changed then B.try("chooser", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if label.Parent then label.Text = summary() end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(field)
  button.MouseEnter:Connect(function() field.BackgroundColor3 = C.fieldHi end)
  button.MouseLeave:Connect(function() field.BackgroundColor3 = C.field end)
  button.Activated:Connect(B.safe("unnamed.choose", function()
    if popup and popup.anchor == field then closePopup(); return end
    local items = {}
    for index, option in ipairs(choices) do items[index] = { option.label, many and has(option.value) or option.value == value } end
    openList(field, items, function(index)
      local option = choices[index]
      if not many then set(option.value); return false end
      local next = table.clone(value)
      local at = table.find(next, option.value)
      if at then table.remove(next, at) else next[#next + 1] = option.value end
      local ordered = {}
      for _, o in ipairs(choices) do if table.find(next, o.value) then ordered[#ordered + 1] = o.value end end
      set(ordered)
      return at == nil
    end, many)
    arrow.Text = "^"
    popup.closed = function() if arrow.Parent then arrow.Text = "v" end end
  end))
  tooltip(button, spec.tip or spec.desc)
  return { row = { frame = line, label = label }, id = id, get = function() return value end, set = set, has = has,
    options = function(next) choices = options(next); label.Text = summary() end,
    -- (what it shows, put from outside without a change of its own: an id-less one kept in step)
    show = function(next) value = next; if label.Parent then label.Text = summary() end end }
end
function Section:dropdown(spec) return chooser(self, spec, false) end
function Section:segmented(spec) return chooser(self, spec, false) end
function Section:multi(spec) return chooser(self, spec, true) end

function Section:color(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or Color3.new(1, 1, 1)) or (spec.default or Color3.new(1, 1, 1))
  local line = row(self, 16)
  findable(self, line, spec.label, spec.desc)
  text(line, lower(spec.label), { Size = UDim2.new(1, -40, 1, 0), TextColor3 = C.text })
  local swatch = lined(box(line, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(26, 11), BackgroundColor3 = value }), C.dark)
  local function set(next) if id then Config.set(id, next) else value = next; swatch.BackgroundColor3 = next; if spec.changed then spec.changed(next) end end end
  if id then
    Config.on(id, function(next)
      value = next
      if swatch.Parent then swatch.BackgroundColor3 = next end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(swatch)
  button.Activated:Connect(B.safe("unnamed.color", function()
    if popup and popup.anchor == swatch then closePopup(); return end
    openColor(swatch, value, set)
  end))
  tooltip(button, spec.tip or spec.desc)
  return { row = { frame = line }, id = id, get = function() return value end, set = set }
end

function Section:keybind(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "None") or (spec.default or "None")
  local line = row(self, 16)
  findable(self, line, spec.label, spec.desc)
  text(line, lower(spec.label), { Size = UDim2.new(1, -60, 1, 0) })
  local chip = keyChip(line)
  chip.Size = UDim2.fromOffset(52, 14)
  local function show() chip.Visible, chip.Text = true, Config.keyLabel(value ~= "None" and value or nil) end
  show()
  if id then
    Config.on(id, function(next)
      value = next
      if chip.Parent then show() end
      if spec.changed then spec.changed(next) end
    end)
  end
  local button = hit(chip)
  button.Activated:Connect(B.safe("unnamed.key", function()
    chip.Text = "..."
    Controls.captureKey(function(key, cancelled)
      if not cancelled then
        local next = key or "None"
        if id then Config.set(id, next) else value = next; if spec.changed then spec.changed(next) end end
      end
      show()
    end)
  end))
  tooltip(button, spec.tip or spec.desc)
  return { row = { frame = line }, id = id, get = function() return value end }
end

function Section:button(spec)
  local id = spec.id
  local line = row(self, 18)
  findable(self, line, spec.label or spec.text, spec.desc)
  local field = lined(box(line, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.field }), C.dark)
  local label = text(field, lower(spec.label or spec.text), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12 })
  local chip = keyChip(field)
  chip.Position = UDim2.new(1, -2, 0.5, 0)
  local function showKey()
    local bind = id and Config.bindOf(id)
    chip.Visible = bind ~= nil and bind.key ~= nil
    if chip.Visible then chip.Text = Config.keyLabel(bind.key) end
  end
  showKey()
  if id then
    Config.action(id, function() if spec.run then spec.run() end end)
    Config.bindsChanged:connect(function(changed) if changed == id and chip.Parent then showKey() end end)
    if spec.bindable ~= false then Controls.bindables[id] = Controls.bindables[id] or { label = spec.label or id, kind = "button", page = self.page.source } end
  end
  local button = hit(field)
  button.MouseEnter:Connect(function() field.BackgroundColor3 = C.fieldHi end)
  button.MouseLeave:Connect(function() field.BackgroundColor3 = C.field end)
  button.Activated:Connect(B.safe("unnamed.button", function()
    wear(field, "BorderColor3")
    task.delay(0.12, function() if field.Parent then field.BorderColor3 = C.dark end end)
    if spec.run then B.try("button." .. (spec.label or "?"), spec.run) end
  end))
  button.MouseButton2Click:Connect(function() if id and spec.bindable ~= false then keyMenu(id, spec.label, "button", line, chip, showKey) end end)
  tooltip(button, spec.tip or spec.desc)
  return { row = { frame = line, label = label }, button = field, setText = function(value) label.Text = lower(value) end }
end

function Section:input(spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "") or (spec.default or "")
  local line = row(self, 34)
  findable(self, line, spec.label, spec.desc)
  text(line, lower(spec.label), { Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.dim, TextSize = 12 })
  local field = lined(box(line, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.field }), C.dark)
  local entry = entryBox(field, 12)
  entry.Position, entry.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0)
  entry.Text, entry.PlaceholderText = tostring(value), lower(spec.placeholder or "")
  entry.FocusLost:Connect(B.safe("unnamed.input", function()
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
  self.count += 1
  local label = text(self.body, spec.text or "", { Name = "Note", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 12,
    TextColor3 = C.dim, LayoutOrder = self.count, RichText = spec.rich == true })
  return { frame = label, set = function(value) label.Text = value end }
end
function Section:custom(spec)
  self.count += 1
  local frame = box(self.body, { Name = spec.name or "Custom", Size = UDim2.new(1, 0, 0, spec.height or 100), BackgroundTransparency = 1, LayoutOrder = self.count })
  if spec.height == nil then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("unnamed.custom", spec.build, frame)
  return frame
end
-- for a tab's own version of itself: a line of text, two buttons side by side, a box to type in
function Section:label(value)
  local note = self:note({ text = value })
  note.frame.TextColor3 = C.text
  return note
end
function Section:pair(a, b)
  local line = row(self, 18)
  local out = {}
  for index, item in ipairs({ a, b }) do
    if item then
      local field = lined(box(line, { Position = UDim2.new((index - 1) * 0.5, index == 2 and 3 or 0, 0, 0), Size = UDim2.new(b and 0.5 or 1, b and -3 or 0, 1, 0),
        BackgroundColor3 = C.field }), C.dark)
      local label = text(field, lower(item[1]), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12 })
      local button = hit(field)
      button.MouseEnter:Connect(function() field.BackgroundColor3 = C.fieldHi end)
      button.MouseLeave:Connect(function() field.BackgroundColor3 = C.field end)
      button.Activated:Connect(B.safe("unnamed.pair", function() if item[2] then item[2]() end end))
      out[index] = { field = field, label = label }
    end
  end
  return out
end
function Section:field(placeholder, changed)
  local line = row(self, 18)
  local field = lined(box(line, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.field }), C.dark)
  local entry = entryBox(field, 12)
  entry.Position, entry.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0)
  entry.Text, entry.PlaceholderText = "", placeholder or ""
  if changed then entry:GetPropertyChangedSignal("Text"):Connect(function() changed(entry.Text) end) end
  return entry
end
U.Section = Section

-- ---------------------------------------------------------------- a tab
local Page = {}
Page.__index = Page
local function band(page, full)
  page.bands += 1
  local frame = box(page.content, { Name = full and "Full" or "Columns", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    LayoutOrder = page.bands })
  if full then
    list(frame, 8)
    return { full = true, frame = frame }
  end
  local columns = {}
  for index = 1, 2 do
    local column = box(frame, { Name = "Column" .. index, Size = UDim2.new(0.5, -4, 0, 0), Position = UDim2.new(index == 1 and 0 or 0.5, index == 1 and 0 or 4, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
    list(column, 8)
    columns[index] = { frame = column, count = 0 }
  end
  return { full = false, frame = frame, columns = columns }
end
local function host(page, spec)
  local current = page.band
  if spec.full then
    current = band(page, true)
    page.band = nil
  elseif not current or current.full then
    current = band(page, false)
    page.band = current
  end
  if current.full then return current.frame end
  local column = spec.column and current.columns[spec.column]
    or (current.columns[1].count <= current.columns[2].count and current.columns[1] or current.columns[2])
  column.count += spec.weight or 1
  return column.frame
end
-- a box with its title on the line along its top
local function group(page, spec)
  page.sections += 1
  local frame = lined(box(host(page, spec), { Name = spec.title or "Box", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = page.sections }))
  wear(box(frame, { Name = "Line", Size = UDim2.new(1, 0, 0, 2), ZIndex = 2 }), "BackgroundColor3")
  local top = spec.title and 22 or 8
  if spec.title then
    text(frame, lower(spec.title), { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
  end
  local body = box(frame, { Name = "Body", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
  pad(body, 0, 8, 8, 8)
  list(body, 5)
  if page.cards then page.cards[#page.cards + 1] = { frame = frame, title = lower(spec.title) } end
  return setmetatable({ body = body, count = 0, page = page, card = frame }, Section)
end
function Page:section(spec) return group(self, spec or {}) end
function Page:custom(height, build, alt)
  if alt then
    local section = group(self, { full = true })
    B.try("unnamed.alt", alt, section)
    return section.body
  end
  self.band = nil
  local section = group(self, { full = true })
  local frame = box(section.body, { Name = "Custom", Size = UDim2.new(1, 0, 0, height or 0), BackgroundTransparency = 1 })
  if not height then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("unnamed.custom", build, frame)
  return frame
end
function Page:empty(_, title, value)
  local section = group(self, { full = true, title = title or "nothing here yet" })
  section:note({ text = value or "" })
end

-- ---------------------------------------------------------------- the window
local function tabsWanted()
  local out = {}
  for _, page in ipairs(Window.order) do
    if not page.hidden and page.id ~= "home" and page.build then out[#out + 1] = page end
  end
  return out
end
local query = ""                      -- what the search box holds, lower case
-- Show only the rows of a tab that match the search (and the boxes they are in). Rows hidden for
-- reasons of their own are left as they are: only what the search hid is shown again.
local function filter(entry)
  if not (entry and entry.rows) then return false end
  local any, cards = false, {}
  for _, item in ipairs(entry.rows) do
    if item.frame.Parent then
      local found = query == "" or string.find(item.text, query, 1, true) ~= nil
      if found then
        if item.hidden then item.frame.Visible = true; item.hidden = nil end
        if item.card then cards[item.card] = true end
        any = true
      elseif item.frame.Visible then
        item.frame.Visible, item.hidden = false, true
      end
    end
  end
  for _, card in ipairs(entry.cards or {}) do
    local named = card.title ~= "" and string.find(card.title, query, 1, true) ~= nil
    local shown = query == "" or cards[card.frame] == true or named
    if shown and card.hidden then card.frame.Visible = true; card.hidden = nil
    elseif not shown and card.frame.Visible then card.frame.Visible, card.hidden = false, true end
    -- (a box found by its own title shows all it holds)
    if query ~= "" and named and not cards[card.frame] then
      for _, item in ipairs(entry.rows) do
        if item.card == card.frame and item.hidden then item.frame.Visible = true; item.hidden = nil end
      end
      any = true
    end
  end
  return any
end
local function buildPage(source)
  local entry = U.pages[source.id]
  if entry and entry.built then return entry end
  if not entry then
    local scroller = Instance.new("ScrollingFrame")
    scroller.Name = source.id
    scroller.BackgroundTransparency, scroller.BorderSizePixel = 1, 0
    scroller.Position, scroller.Size = UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12)
    scroller.CanvasSize = UDim2.new()
    scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroller.ScrollingDirection = Enum.ScrollingDirection.Y
    scroller.ScrollBarThickness = 3
    scroller.Visible = false
    wear(scroller, "ScrollBarImageColor3")
    scroller.Parent = U.body
    -- (an open list or tip belongs where it was opened: scrolled away, it goes)
    scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
      if popup and popup.anchor and popup.anchor:IsDescendantOf(scroller) then closePopup() end
      hideTip()
    end)
    local content = box(scroller, { Name = "Content", Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
    list(content, 8)
    entry = setmetatable({ source = source, scroller = scroller, content = content, bands = 0, sections = 0, rows = {}, cards = {} }, Page)
    U.pages[source.id] = entry
  end
  entry.built = true
  B.try("unnamed.page." .. source.id, source.build, entry)
  if entry.sections == 0 then entry:empty(nil, "nothing here yet", "This tab is ready for its controls.") end
  if B.Keys and B.Keys.repaint then B.Keys.repaint() end
  return entry
end
local function unwear(instance)
  for index = #accented, 1, -1 do if accented[index][1] == instance then table.remove(accented, index) end end
end
local found = nil                      -- tab id -> true, for the tabs the search finds something on
local function paintTabs()
  for _, tab in ipairs(U.tabs) do
    local on = tab.id == U.current
    tab.button.BackgroundColor3 = on and C.tabOn or C.tab
    tab.line.Visible = on
    if found and found[tab.id] and not on then wear(tab.label, "TextColor3")
    else
      unwear(tab.label)
      tab.label.TextColor3 = on and C.text or (found and C.faint or C.dim)
    end
  end
end
function U.go(id)
  local source = Window.pages[id]
  if not (source and U.built) then return end
  closePopup()
  hideTip()
  local entry = buildPage(source)
  for _, other in pairs(U.pages) do other.scroller.Visible = other == entry end
  U.current = id
  filter(entry)
  paintTabs()
end
-- the search: this tab first; if nothing here, the first tab that has it
function U.search(value)
  query = lower(value or "")
  query = string.gsub(query, "^%s+", "")
  query = string.gsub(query, "%s+$", "")
  if not U.built then return end
  found = nil
  if query ~= "" then
    found = {}
    for _, source in ipairs(tabsWanted()) do
      if filter(buildPage(source)) then found[source.id] = true end
    end
    if U.current and not found[U.current] then
      for _, source in ipairs(tabsWanted()) do
        if found[source.id] then U.go(source.id); return end
      end
    end
  else
    for _, entry in pairs(U.pages) do filter(entry) end
  end
  if U.current then U.go(U.current) end
end
function U.rebuildTabs()
  if not U.built then return end
  for _, tab in ipairs(U.tabs) do tab.button:Destroy() end
  table.clear(U.tabs)
  local wanted = tabsWanted()
  local count = math.max(#wanted, 1)
  -- (each as wide as its name wants, of the whole bar: "movement" next to "cash")
  local width = 0
  for _, page in ipairs(wanted) do width += #page.title + 2 end
  for index, page in ipairs(wanted) do
    local share = (#page.title + 2) / math.max(width, 1)
    local button = lined(box(U.tabBar, { Name = page.id, Size = UDim2.new(share, index == count and 0 or -2, 1, 0), BackgroundColor3 = C.tab, LayoutOrder = index }), C.dark)
    local label = text(button, lower(page.title), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, TextColor3 = C.dim,
      TextTruncate = Enum.TextTruncate.AtEnd })
    local line = wear(box(button, { Size = UDim2.new(1, 0, 0, 1), Visible = false, ZIndex = 2 }), "BackgroundColor3")
    local click = hit(button)
    click.MouseEnter:Connect(function() if U.current ~= page.id then button.BackgroundColor3 = C.tabOn end end)
    click.MouseLeave:Connect(function() if U.current ~= page.id then button.BackgroundColor3 = C.tab end end)
    click.Activated:Connect(B.safe("unnamed.tab", function() UI.sfx("tab", 0.4); U.go(page.id) end))
    U.tabs[#U.tabs + 1] = { id = page.id, button = button, label = label, line = line }
  end
  if not (U.current and Window.pages[U.current]) and wanted[1] then U.current = (Window.startPage and Window.pages[Window.startPage] and Window.startPage) or wanted[1].id end
end
local function scaleNow()
  local camera = workspace.CurrentCamera
  local tall = camera and camera.ViewportSize.Y or 900
  return math.clamp(tall / 1000, 0.75, 1.6) * ((Config.get("app.scale") or 100) / 100)
end
U.scaleNow = scaleNow
local MIN_W, MIN_H, MAX_W, MAX_H = 470, 360, 1100, 960
local function sizeWanted()
  local w, h = Config.get("app.unnamed.w"), Config.get("app.unnamed.h")
  return math.clamp(type(w) == "number" and w or W, MIN_W, MAX_W), math.clamp(type(h) == "number" and h or H, MIN_H, MAX_H)
end
local function crownOn(frame)
  local crown = wear(box(frame, { Name = "Crown", Size = UDim2.new(1, 0, 0, 2), ZIndex = 5 }), "BackgroundColor3")
  local shade = Instance.new("UIGradient")
  shade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0.55) })
  shade.Parent = crown
  return crown
end
function U.build()
  if U.built then return end
  U.built = true
  pickFont()
  local gui = B.screen(9050)
  gui:SetAttribute("OwnLetters", true)
  U.gui = gui
  U.modal = Instance.new("TextButton")
  U.modal.Text, U.modal.BackgroundTransparency, U.modal.Size, U.modal.Modal, U.modal.Visible = "", 1, UDim2.fromOffset(0, 0), true, false
  U.modal.Parent = gui
  local width, height = sizeWanted()
  local holder = lined(box(gui, { Name = "Unnamed", Size = UDim2.fromOffset(width, height), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.get("app.unnamed.x") or 0.5, Config.get("app.unnamed.y") or 0.5), BackgroundColor3 = C.back, Visible = false }), C.dark)
  U.holder = holder
  U.sizer = Instance.new("UIScale")
  U.sizer.Scale = scaleNow()
  U.sizer.Parent = holder
  -- the thin coloured rim round it all, and the bright line along its top
  wear(box(holder, { Name = "Rim", Size = UDim2.new(1, 2, 1, 2), Position = UDim2.fromOffset(-1, -1), BackgroundTransparency = 1, BorderSizePixel = 1, ZIndex = 0 }), "BorderColor3")
  crownOn(holder)
  -- the top: its name, the game, a search box, and the way back to the other look; held to drag it
  local top = box(holder, { Name = "Top", Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C.back })
  wear(text(top, "based", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 50, 1, 0) }, true), "TextColor3")
  local status = B.Registry and B.Registry.status and B.Registry.status() or {}
  text(top, lower(status.name or "universal"), { Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -330, 1, 0), TextColor3 = C.faint, TextSize = 12,
    TextTruncate = Enum.TextTruncate.AtEnd })
  local swap = lined(box(top, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(84, 14), BackgroundColor3 = C.field }), C.dark)
  text(swap, "based look", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, TextColor3 = C.dim })
  local swapHit = hit(swap, { ZIndex = 9 })
  swapHit.MouseEnter:Connect(function() swap.BackgroundColor3 = C.fieldHi end)
  swapHit.MouseLeave:Connect(function() swap.BackgroundColor3 = C.field end)
  swapHit.Activated:Connect(B.safe("unnamed.swap", function() Config.set("app.gui", "based") end))
  tooltip(swapHit, "Back to the BASED window. Settings has this too.")
  local seek = lined(box(top, { Name = "Search", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -95, 0.5, 0), Size = UDim2.fromOffset(150, 14),
    BackgroundColor3 = C.field }), C.dark)
  local seekBox = entryBox(seek, 11)
  seekBox.Position, seekBox.Size, seekBox.ZIndex = UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0), 9
  seekBox.PlaceholderText, seekBox.Text = "search...", ""
  U.seekBox = seekBox
  local seekToken = 0
  seekBox:GetPropertyChangedSignal("Text"):Connect(function()
    seekToken += 1
    local mine = seekToken
    task.delay(0.12, function() if mine == seekToken then B.try("unnamed.search", U.search, seekBox.Text) end end)
  end)
  seekBox.Focused:Connect(function() wear(seek, "BorderColor3") end)
  seekBox.FocusLost:Connect(function() unwear(seek); seek.BorderColor3 = C.dark end)
  U.tabBar = box(holder, { Name = "Tabs", Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 0, 20), BackgroundTransparency = 1 })
  list(U.tabBar, 2, true)
  U.body = lined(box(holder, { Name = "Body", Position = UDim2.fromOffset(6, 46), Size = UDim2.new(1, -12, 1, -52), BackgroundColor3 = C.frame, ClipsDescendants = true }))
  -- the tip: as wide as it needs, never wider than 260, wrapped past that
  tip = lined(text(holder, "", { Name = "Tip", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextSize = 12, BackgroundColor3 = C.field,
    BackgroundTransparency = 0, Visible = false, ZIndex = 80, TextWrapped = true }), C.dark)
  local tipMost = Instance.new("UISizeConstraint")
  tipMost.MaxSize = Vector2.new(260, math.huge)
  tipMost.Parent = tip
  pad(tip, 3, 6, 3, 6)
  -- dragging by the top
  local grab = hit(top, { ZIndex = 2 })
  local from, start
  UI.drag(grab, function(point)
    from, start = point, holder.AbsolutePosition + holder.AbsoluteSize / 2
  end, function(point)
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local centre = start + (point - from)
    local inset = UI.inset()
    local x, y = util.clamp01(centre.X / size.X), util.clamp01((centre.Y + inset.Y) / size.Y)
    holder.Position = UDim2.fromScale(x, y)
  end, function()
    Config.set("app.unnamed.x", holder.Position.X.Scale)
    Config.set("app.unnamed.y", holder.Position.Y.Scale)
  end)
  -- the corner it is made bigger or smaller by (the top left stays where it is)
  local corner = box(holder, { Name = "Resize", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -1, 1, -1), Size = UDim2.fromOffset(10, 10),
    BackgroundTransparency = 1, ZIndex = 20 })
  for index = 1, 3 do
    wear(box(corner, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -(index - 1) * 3), Size = UDim2.fromOffset(index * 3, 1), ZIndex = 21,
      BackgroundTransparency = 0.25 }), "BackgroundColor3")
  end
  local cornerHit = hit(corner, { ZIndex = 22, Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, -3) })
  local fromPoint, fromSize, fromCorner
  UI.drag(cornerHit, function(point)
    local scale = U.sizer.Scale
    fromPoint, fromSize = point, holder.AbsoluteSize / scale
    fromCorner = holder.AbsolutePosition
    closePopup()
    hideTip()
  end, function(point)
    local scale = U.sizer.Scale
    local camera = workspace.CurrentCamera
    local view = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local wanted = fromSize + (point - fromPoint) / scale
    local w = math.clamp(wanted.X, MIN_W, math.max(MIN_W, math.min(MAX_W, view.X / scale)))
    local h = math.clamp(wanted.Y, MIN_H, math.max(MIN_H, math.min(MAX_H, view.Y / scale)))
    holder.Size = UDim2.fromOffset(w, h)
    -- (held by its centre: keep the top left corner where it was)
    local inset = UI.inset()
    local centre = fromCorner + Vector2.new(w, h) * scale / 2
    holder.Position = UDim2.fromScale(util.clamp01(centre.X / view.X), util.clamp01((centre.Y + inset.Y) / view.Y))
  end, function()
    Config.set("app.unnamed.w", math.floor(holder.Size.X.Offset + 0.5))
    Config.set("app.unnamed.h", math.floor(holder.Size.Y.Offset + 0.5))
    Config.set("app.unnamed.x", holder.Position.X.Scale)
    Config.set("app.unnamed.y", holder.Position.Y.Scale)
  end)
  tooltip(cornerHit, "Drag to resize.")
  -- a click anywhere outside an open list closes it
  B.connect(UIS.InputBegan, function(input)
    if not popup then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local point = UI.point(input)
    if not (UI.inside(popup.frame, point) or (popup.anchor and popup.anchor.Parent and UI.inside(popup.anchor, point))) then closePopup() end
  end, "unnamed.outside")
  Config.on("app.unnamed.accent", repaint)
  Config.on("app.scale", function() if U.sizer then U.sizer.Scale = scaleNow() end end)
  local camera = workspace.CurrentCamera
  if camera then B.connect(camera:GetPropertyChangedSignal("ViewportSize"), function() if U.sizer then U.sizer.Scale = scaleNow() end end, "unnamed.viewport") end
  U.rebuildTabs()
end
function U.show(on)
  if on and not U.built then U.build() end
  if not U.built or U.open == on then return end
  U.open = on
  closePopup()
  hideTip()
  U.holder.Visible = on
  U.modal.Visible = on and Config.get("app.freeCursor") ~= false
  if on then
    U.rebuildTabs()
    if U.current then U.go(U.current) end
    -- (all of it on the screen: one put half off it, or kept from a bigger screen, comes back in)
    task.defer(function()
      if not (U.open and U.holder) then return end
      local camera = workspace.CurrentCamera
      local view = camera and camera.ViewportSize or Vector2.new(1920, 1080)
      local size = U.holder.AbsoluteSize
      local inset = UI.inset()
      local centre = U.holder.AbsolutePosition + size / 2 + Vector2.new(0, inset.Y)
      local x = math.clamp(centre.X, size.X / 2 + 4, math.max(size.X / 2 + 4, view.X - size.X / 2 - 4))
      local y = math.clamp(centre.Y, size.Y / 2 + 4, math.max(size.Y / 2 + 4, view.Y - size.Y / 2 - 4))
      if math.abs(x - centre.X) > 1 or math.abs(y - centre.Y) > 1 then
        U.holder.Position = UDim2.fromScale(x / view.X, y / view.Y)
      end
    end)
    -- (a small rise into place: quick, so it never gets in the way)
    if not Motion.reduced then
      local target = scaleNow()
      U.sizer.Scale = target * 0.965
      Motion.to(U.sizer, "Scale", target, "snappy")
    end
    UI.sfx("open", 0.35)
  else
    if U.seekBox and U.seekBox:IsFocused() then U.seekBox:ReleaseFocus() end
    UI.sfx("close", 0.3)
  end
  if Window.onShow then Window.onShow:fire(Window.anyOpen()) end
end
function U.toggle() U.show(not U.open) end
-- the one that is in use: this, or the BASED window
function U.active() return Config.get("app.gui") == "unnamed" end
function U.toggleActive() Window.toggleActive() end

-- ---------------------------------------------------------------- the key list, drawn this way
-- What Keys puts on screen while the hub is hidden, in this menu's look: a dark box, the line on
-- top, "keybinds" in small letters, and a row a key: [key] name, lit while it is on.
function U.keyPanel(parent)
  local panel = lined(box(parent, { Name = "KeysUnnamed", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = C.back }), C.dark)
  local least = Instance.new("UISizeConstraint")
  least.MinSize = Vector2.new(170, 0)
  least.Parent = panel
  crownOn(panel)
  local title = text(panel, "keybinds", { Name = "Title", Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center,
    TextColor3 = C.dim, TextSize = 12 })
  local body = box(panel, { Name = "Body", Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1 })
  pad(body, 0, 8, 6, 8)
  list(body, 1)
  local api = { frame = panel, rows = {}, shape = nil }
  local TS = S.TweenService
  local INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
  -- (lit: the key in the accent and the name bright; the light fades in and out)
  local function light(row, on, animate)
    row.on = on
    unwear(row.key)
    local goal = { key = on and accent() or C.faint, name = on and C.text or C.dim, wash = on and 0.82 or 1 }
    if animate and not Motion.reduced then
      TS:Create(row.key, INFO, { TextColor3 = goal.key }):Play()
      TS:Create(row.name, INFO, { TextColor3 = goal.name }):Play()
      TS:Create(row.wash, INFO, { BackgroundTransparency = goal.wash }):Play()
      task.delay(0.32, function() if row.on and row.key.Parent then wear(row.key, "TextColor3") end end)
    else
      row.key.TextColor3, row.name.TextColor3, row.wash.BackgroundTransparency = goal.key, goal.name, goal.wash
      if on then wear(row.key, "TextColor3") end
    end
    if row.state then row.state.Text = row.hold and "(hold)" or (on and "(on)" or "(off)") end
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
    for _, child in ipairs(body:GetChildren()) do
      if child:IsA("GuiObject") then child:Destroy() end
    end
    title.Text = moving and "keybinds  (drag, then lock)" or "keybinds"
    if moving then wear(title, "TextColor3") else unwear(title); title.TextColor3 = C.dim end
    if #binds == 0 then
      text(body, "nothing bound yet", { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.faint, TextSize = 12, LayoutOrder = 1 })
      return
    end
    for index, bind in ipairs(binds) do
      if index > 12 then
        text(body, "+" .. (#binds - 12) .. " more", { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C.faint, TextSize = 12, LayoutOrder = index })
        break
      end
      local line = box(body, { Name = "Bind_" .. bind.id, Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = index })
      local wash = box(line, { Name = "Wash", Size = UDim2.new(1, 6, 1, 0), Position = UDim2.fromOffset(-3, 0), BackgroundColor3 = C.fieldHi, BackgroundTransparency = 1 })
      local inner = box(line, { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
      list(inner, 5, true)
      local key = text(inner, "[" .. Config.keyLabel(bind.key) .. "]", { Name = "Key", Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = 1,
        TextColor3 = C.faint })
      local name = text(inner, lower(bind.label), { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = 2, TextColor3 = C.dim })
      local state
      if bind.kind == "toggle" then
        state = text(inner, "", { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = 3, TextColor3 = C.faint })
      end
      local row = { key = key, name = name, wash = wash, state = state, hold = bind.mode == "hold" }
      api.rows[bind.id] = row
      local was = before[bind.id]
      light(row, was == nil and bind.on or was, false)
      if was ~= nil and was ~= bind.on then light(row, bind.on, true) end
    end
  end
  return api
end

-- ---------------------------------------------------------------- the kit (src/07): tabs that draw themselves, in this look
local function unwearOne(instance, property)
  for index = #accented, 1, -1 do
    local entry = accented[index]
    if entry[1] == instance and entry[2] == property then table.remove(accented, index) end
  end
end
local KIT_ROLES = { card = C.box, field = C.field, hover = C.fieldHi, line = C.dark, back = C.back, text = C.text, dim = C.dim, faint = C.faint,
  onAccent = Color3.new(1, 1, 1), good = rgb(82, 214, 160), bad = rgb(255, 101, 119) }
local kit = { look = "unnamed", radius = 0, small = 0, size = 12 }
function kit.owns(frame) return U.gui ~= nil and frame:IsDescendantOf(U.gui) end
function kit.color(role)
  if role == "accent" then return accent(), 0 end
  return KIT_ROLES[role] or C.text, 0
end
function kit.paint(instance, property, role)
  unwearOne(instance, property)
  if role == "accent" then wear(instance, property) else instance[property] = KIT_ROLES[role] or C.text end
end
function kit.fill(instance, role)
  kit.paint(instance, "BackgroundColor3", role)
  instance.BackgroundTransparency = 0
end
function kit.clear(instance) instance.BackgroundTransparency = 1 end
function kit.font(bold) if not FONT then pickFont() end return bold and BOLD or FONT end
function kit.text(parent, value, props, bold, size)
  local all = { TextSize = size or 12, TextTruncate = Enum.TextTruncate.AtEnd }
  if props then for key, v in pairs(props) do all[key] = v end end
  return text(parent, value, all, bold)
end
function kit.entry(parent, size) return entryBox(parent, size or 12) end
function kit.outline(frame) return lined(frame, C.dark) end
function kit.corner() return nil end
-- a short list under `anchor` (inside this menu): items as UI.menu takes them
function kit.menu(anchor, items)
  local rows, map = {}, {}
  for _, item in ipairs(items) do
    if type(item) == "table" then
      rows[#rows + 1] = { lower(item.label), item.checked == true }
      map[#rows] = item
    end
  end
  if #rows == 0 then return end
  openList(anchor, rows, function(index)
    local item = map[index]
    if item and item.run then B.try("unnamed.menu", item.run) end
    return item ~= nil and item.keepOpen == true
  end, false)
end
U.kit = kit
Window.kits.unnamed = kit

-- ---------------------------------------------------------------- the watermark
-- This look's version of the island: top left, under the game's own buttons. The hub's name, who
-- is playing, the game, frames a second, ping and the time; a click opens the menu.
local mark
local function watermarkWanted() return U.active() and Config.get("app.unnamed.watermark") ~= false and Config.get("app.island") ~= false end
function U.watermark()
  if not Window.hud then return end
  if not watermarkWanted() then
    if mark then mark.frame.Visible = false end
    return
  end
  if not mark then
    local frame = lined(box(Window.hud, { Name = "Watermark", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.back }), C.dark)
    local sizer = Instance.new("UIScale"); sizer.Parent = frame
    crownOn(frame)
    local line = box(frame, { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(0, 0, 1, -2), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 })
    pad(line, 0, 8, 0, 8)
    list(line, 0, true)
    wear(text(line, "based", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = 1 }, true), "TextColor3")
    local rest = text(line, "", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = 2 })
    local click = hit(frame, { ZIndex = 9 })
    click.Activated:Connect(B.safe("unnamed.watermark", function() U.show(true) end))
    local status = B.Registry and B.Registry.status and B.Registry.status() or {}
    local where = lower(status.name or "universal")
    local who = lower(B.LP.Name)
    local function seat()
      local inset = UI.inset()
      sizer.Scale = scaleNow()
      frame.Position = UDim2.fromOffset(12, math.max(inset.Y, 0) + 10)
    end
    seat()
    mark = { frame = frame, seat = seat }
    Motion.every(function()
      if not frame.Visible then return end
      local hud = B.Hud
      local fps = hud and hud.fps and math.floor(hud.fps() + 0.5) or 0
      local ping = hud and hud.ping and math.floor(hud.ping() + 0.5) or 0
      rest.Text = string.format("  |  %s  |  %s  |  %d fps  |  %d ms  |  %s", who, where, fps, ping, os.date("%H:%M"))
    end, 2, "unnamed.watermark")
    Config.on("app.scale", function() if mark then mark.seat() end end)
  end
  mark.frame.Visible = true
end

-- switching looks: the other one is closed and this one opened where it was
function U.start()
  Config.define("app.gui", "based")
  Config.define("app.unnamed.accent", ACCENT)
  Config.define("app.unnamed.x", 0.5)
  Config.define("app.unnamed.y", 0.5)
  Config.define("app.unnamed.w", W)
  Config.define("app.unnamed.h", H)
  Config.define("app.unnamed.font", "monocraft")
  Config.define("app.unnamed.textSize", 100)
  Config.define("app.unnamed.watermark", true)
  Config.on("app.gui", function(look)
    if look == "unnamed" then
      Window.show(false)
      U.show(true)
    else
      U.show(false)
      -- (the Novoline look opens itself: src/53)
      if look ~= "novoline" or not B.Novoline then Window.show(true) end
    end
    U.watermark()
  end)
  Config.on("app.unnamed.font", refont)
  Config.on("app.unnamed.textSize", refont)
  Motion.every(sweepTyped, 0.1, "unnamed.sweep")
  Config.on("app.unnamed.watermark", function() U.watermark() end)
  Config.on("app.island", function() U.watermark() end)
  -- a tab added or taken away later (a game's tabs) shows up here as well
  local rebuildNav = Window.rebuildNav
  Window.rebuildNav = function(...)
    rebuildNav(...)
    if U.built then U.rebuildTabs() end
  end
end
end
