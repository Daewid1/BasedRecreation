do -- 06_controls.lua
-- ============================================================================
--  06 controls  rows and the things on their right-hand side
--
--  A control is a row inside a card: label (and description) on the left, the
--  control on the right. Every control is backed by a Config flag, so it saves,
--  reloads with a profile, can be reset from its context menu and, for toggles
--  and buttons, bound to a key.
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config
local UIS = S.UserInputService
local Controls = { bindables = {} }   -- bindables: flag id -> { label, kind, page }, everything a key can be given
B.Controls = Controls

-- ---------------------------------------------------------------- key capture
function Controls.captureKey(done)
  if Config.capturing then return end
  Config.capturing = true
  local connection
  connection = UIS.InputBegan:Connect(function(input)
    local key = Config.keyName(input)
    if not key then return end
    connection:Disconnect()
    -- the press that sets a key must not also fire the bind it just made
    task.delay(0.15, function() Config.capturing = false end)
    if key == "Escape" then B.try("capture", done, nil, true)
    elseif key == "Backspace" or key == "Delete" then B.try("capture", done, nil, false)
    else B.try("capture", done, key, false) end
  end)
  B.own(connection)
end

-- ---------------------------------------------------------------- row
-- section: { body = Frame, count = number, index = function(entry) }
local function makeRow(section, spec, controlWidth)
  section.count = (section.count or 0) + 1
  local row = UI.frame(section.body, { Name = spec.label or "Row", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = section.count })
  if section.count > 1 then
    UI.frame(row, { Name = "Rule", Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0),
      Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "strokeA" } })
  end
  local wash = UI.frame(row, { Name = "Wash", Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Theme = { BackgroundColor3 = "ink" },
    BackgroundTransparency = 1, ZIndex = 0 })
  UI.corner(wash, "rSmall")
  local left = UI.frame(row, { Name = "Left", Size = UDim2.new(1, -((controlWidth or 150) + 30), 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    Position = UDim2.fromOffset(0, 0) })
  UI.pad(left, 12, 0, 12, spec.icon and 42 or 14)
  UI.list(left, "y", 2)
  if spec.icon then
    UI.icon(row, spec.icon, 17, "sub", { Position = UDim2.fromOffset(14, 13), Name = "Icon" })
  end
  local titleLine = UI.frame(left, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
  UI.list(titleLine, "x", 7, { v = "Center" })
  local label = UI.text(titleLine, spec.label or "", "label", "ink", { TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1,
    AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20) })
  if spec.badge then UI.badge(titleLine, spec.badge, spec.badgeColor, { LayoutOrder = 2 }) end
  if spec.desc and spec.desc ~= "" then
    UI.text(left, spec.desc, "caption", "sub", { TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
      LayoutOrder = 2, LineHeight = 1.15 })
  end
  local slot = UI.frame(row, { Name = "Slot", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(0, 44),
    AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6 })
  UI.list(slot, "x", 8, { h = "Right", v = "Center" })
  local api = { frame = row, left = left, slot = slot, label = label, wash = wash }
  -- (what it does, on hover: the tip of a control with no line of its own under its name)
  if spec.tip and spec.tip ~= "" then UI.tooltip(row, spec.tip, spec.label) end
  function api.hover(on) Motion.to(wash, "BackgroundTransparency", on and 0.965 or 1, "quick") end
  function api.flash()
    wash.BackgroundTransparency = 0.86
    Theme.unbind(wash, "BackgroundColor3")
    wash.BackgroundColor3 = T.accent
    Motion.to(wash, "BackgroundTransparency", 1, "lazy", function() Theme.bind(wash, "BackgroundColor3", "ink") end)
  end
  if section.index then
    section.index({ label = spec.label or "", desc = spec.desc or "", row = api, id = spec.id })
  end
  return api
end
Controls.row = makeRow

-- the small chip showing which key a flag is bound to
local function bindChip(slot, id, order)
  local chip = UI.frame(slot, { Name = "Bind", Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 1,
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" }, Visible = false })
  UI.corner(chip, 6)
  UI.pad(chip, 0, 6)
  local text = UI.text(chip, "", "mono", "sub", { TextSize = 11, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X })
  local function refresh()
    local bind = Config.bindOf(id)
    chip.Visible = bind ~= nil and bind.key ~= nil
    if bind and bind.key then text.Text = Config.keyLabel(bind.key) .. (bind.mode == "hold" and " ·hold" or "") end
  end
  Config.bindsChanged:connect(function(changed) if changed == id and chip.Parent then refresh() end end)
  refresh()
  return chip
end

local function contextMenu(anchor, spec, extra)
  local items = {}
  local id = spec.id
  if id then
    items[#items + 1] = { label = "Reset to default", icon = "rotate-ccw", run = function() Config.reset(id) end }
  end
  if spec.bindable and id then
    local bind = Config.bindOf(id)
    items[#items + 1] = { label = bind and "Change key…" or "Bind to a key…", icon = "keyboard", run = function()
      B.Window.toast({ title = "Press a key", text = "Esc cancels · Backspace clears", icon = "keyboard", time = 2.2 })
      Controls.captureKey(function(key, cancelled)
        if cancelled then return end
        Config.bind(id, key)
        B.Window.toast({ title = key and ("Bound to " .. Config.keyLabel(key)) or "Key cleared", text = spec.label, icon = "keyboard" })
      end)
    end }
    if bind then
      if spec.kind == "toggle" then
        items[#items + 1] = { label = "Hold to activate", icon = "hand", checked = bind.mode == "hold", run = function()
          Config.bind(id, bind.key, bind.mode == "hold" and "toggle" or "hold")
        end }
      end
      items[#items + 1] = { label = "Clear key", icon = "x", run = function() Config.bind(id, nil) end }
    end
  end
  if extra then
    for _, item in ipairs(extra) do items[#items + 1] = item end
  end
  if #items > 0 then UI.menu(anchor, items, { align = "right" }) end
end

-- ---------------------------------------------------------------- toggle
function Controls.toggle(section, spec)
  spec.kind = "toggle"
  spec.bindable = spec.bindable ~= false
  local id = spec.id
  local value = id and Config.define(id, spec.default == true) or (spec.default == true)
  local row = makeRow(section, spec, spec.children and 92 or 62)
  if id and spec.bindable then
    bindChip(row.slot, id, 1)
    Controls.bindables[id] = { label = spec.label or id, kind = "toggle", page = section.page }
  end

  local track = UI.frame(row.slot, { Name = "Switch", Size = UDim2.fromOffset(42, 24), LayoutOrder = 3, BackgroundTransparency = 0 })
  UI.corner(track, true)
  local knob = UI.frame(track, { Name = "Knob", Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 })
  UI.corner(knob, true)
  if UI.fx.shadow then
    local shadow = Instance.new("UIShadow")
    shadow.BlurRadius = UDim.new(0, 5); shadow.Offset = UDim2.fromOffset(0, 1); shadow.Transparency = 0.7
    shadow.Parent = knob
  end
  local pressed = false
  local function paint(instant)
    local on = value
    local color = on and T.accent or T.ink
    local alpha = on and 0 or T.fill3A - 0.05
    local width = pressed and 23 or 18
    local x = on and (42 - 3 - width) or 3
    if instant then
      track.BackgroundColor3, track.BackgroundTransparency = color, alpha
      Motion.snap(knob, "Position", UDim2.new(0, x, 0.5, 0)); Motion.snap(knob, "Size", UDim2.fromOffset(width, 18))
    else
      Motion.to(track, "BackgroundColor3", color, "quick")
      Motion.to(track, "BackgroundTransparency", alpha, "quick")
      Motion.to(knob, "Position", UDim2.new(0, x, 0.5, 0), pressed and "quick" or "bouncy")
      Motion.to(knob, "Size", UDim2.fromOffset(width, 18), "snappy")
    end
  end
  paint(true)
  Theme.changed:connect(function() if track.Parent then paint(true) end end)

  local api = { row = row, id = id }
  function api.get() return value end
  function api.set(next, quiet)
    next = next == true
    if next == value then return end
    if id then Config.set(id, next, quiet) else
      value = next
      paint()
      if spec.changed then B.try("toggle", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next == true
      if track.Parent then paint() end
      if spec.changed then spec.changed(value) end
    end)
    if spec.changed and value then task.defer(B.safe("toggle.init", function() spec.changed(value) end)) end
  end

  -- nested options that only matter when the toggle is on
  local sub
  if spec.children then
    local chevron = UI.frame(row.slot, { Name = "More", Size = UDim2.fromOffset(22, 22), LayoutOrder = 2 })
    local icon = UI.icon(chevron, "chevron-down", 15, "faint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local holder = UI.frame(section.body, { Name = "Sub", Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, LayoutOrder = section.count })
    section.count += 1
    holder.LayoutOrder = section.count
    local inner = UI.frame(holder, { Name = "Inner", Size = UDim2.new(1, -18, 0, 0), Position = UDim2.fromOffset(18, 0), AutomaticSize = Enum.AutomaticSize.Y })
    UI.list(inner, "y", 0)
    UI.frame(holder, { Name = "Guide", Size = UDim2.new(0, 1, 1, -12), Position = UDim2.fromOffset(22, 2),
      Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "strokeA" } })
    sub = { body = inner, count = 0, index = section.index, page = section.page, nested = true }
    local open = false
    local built = false
    local function size(instant)
      local h = open and (inner.AbsoluteSize.Y / UI.unit()) or 0
      if instant then Motion.snap(holder, "Size", UDim2.new(1, 0, 0, h)) else Motion.to(holder, "Size", UDim2.new(1, 0, 0, h), "smooth") end
      Motion.to(icon, "Rotation", open and 180 or 0, "snappy")
    end
    local function setOpen(next)
      open = next
      if open and not built then
        built = true
        B.try("toggle.children", spec.children, B.Window.sectionApi(sub))
      end
      size()
    end
    inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if open then size(true) end end)
    UI.button(chevron, {
      hover = function(on) Theme.bind(icon, "ImageColor3", on and "ink" or "faint") end,
      click = function() UI.sfx("click", 0.5); setOpen(not open) end,
    })
    api.open = setOpen
  end

  UI.button(row.frame, {
    hover = row.hover,
    press = function(on) pressed = on; paint() end,
    click = function()
      UI.sfx(value and "toggle_off" or "toggle_on", 0.7)
      api.set(not value)
    end,
    alt = function() contextMenu(track, spec) end,
  })
  return api
end

-- ---------------------------------------------------------------- slider
function Controls.slider(section, spec)
  local id = spec.id
  local min, max, step = spec.min or 0, spec.max or 100, spec.step or 1
  local decimals = spec.decimals or (step < 1 and math.max(0, math.ceil(-math.log10(step))) or 0)
  -- curve: 1 is a straight track. Above 1 the low end of the range gets most of it
  -- (value = min + t ^ curve * span), for a range too wide to set by hand otherwise.
  local curve = spec.curve or 1
  local wide = spec.valueWidth or 64
  local value = id and Config.define(id, spec.default or min) or (spec.default or min)
  local row = makeRow(section, spec, wide + 12)
  row.frame.Name = "Slider"
  local suffix = spec.suffix or ""
  local function text(v) return (spec.format and spec.format(v)) or (util.format(v, decimals) .. suffix) end

  local field = UI.new("TextBox", { Name = "Value", Size = UDim2.fromOffset(wide, 24), BackgroundTransparency = 1, Text = text(value), FontFace = B.F.mono400,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = true, LayoutOrder = 2, Theme = { TextColor3 = "sub" },
    PlaceholderText = "", Parent = row.slot })

  -- the track sits under the label, the full width of the row
  local bar = UI.frame(row.left, { Name = "Bar", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 5 })
  row.left.Size = UDim2.new(1, 0, 0, 0)
  UI.pad(bar, 0, 14, 0, 0)
  local track = UI.frame(bar, { Name = "Track", Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill3A" } })
  UI.corner(track, true)
  local fill = UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "accent" }, BackgroundTransparency = 0 })
  UI.corner(fill, true)
  local knob = UI.frame(track, { Name = "Knob", Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 3 })
  UI.corner(knob, true)
  if UI.fx.shadow then
    local shadow = Instance.new("UIShadow")
    shadow.BlurRadius = UDim.new(0, 6); shadow.Offset = UDim2.fromOffset(0, 1); shadow.Transparency = 0.62
    shadow.Parent = knob
  end

  local dragging = false
  local function place(instant)
    local alpha = util.clamp01((value - min) / (max - min)) ^ (1 / curve)
    if instant then
      Motion.snap(fill, "Size", UDim2.fromScale(alpha, 1)); Motion.snap(knob, "Position", UDim2.fromScale(alpha, 0.5))
    else
      Motion.to(fill, "Size", UDim2.fromScale(alpha, 1), "quick"); Motion.to(knob, "Position", UDim2.fromScale(alpha, 0.5), "quick")
    end
    if not field:IsFocused() then field.Text = text(value) end
  end
  place(true)

  local api = { row = row, id = id }
  function api.get() return value end
  function api.set(next, quiet)
    next = math.clamp(util.round(next, step), min, max)
    if decimals > 0 then next = tonumber(string.format("%." .. decimals .. "f", next)) or next end
    if next == value then return end
    if id then Config.set(id, next, quiet) else
      value = next; place()
      if spec.changed then B.try("slider", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if track.Parent then place(dragging) end
      if spec.changed then spec.changed(value) end
    end)
    if spec.changed then task.defer(B.safe("slider.init", function() spec.changed(value) end)) end
  end

  local hit = UI.new("TextButton", { Name = "Hit", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, 14, 1, 0),
    Position = UDim2.fromOffset(-7, 0), ZIndex = 6, Parent = bar })
  local function at(point)
    local x = track.AbsolutePosition.X
    local w = math.max(1, track.AbsoluteSize.X)
    api.set(min + util.clamp01((point.X - x) / w) ^ curve * (max - min))
  end
  UI.drag(hit, function(point)
    dragging = true
    Motion.to(knob, "Size", UDim2.fromOffset(20, 16), "snappy")
    at(point)
  end, function(point) at(point) end, function()
    dragging = false
    Motion.to(knob, "Size", UDim2.fromOffset(14, 14), "bouncy")
    UI.sfx("click", 0.35)
  end)
  hit.MouseEnter:Connect(function() if not dragging then Motion.to(knob, "Size", UDim2.fromOffset(16, 16), "quick") end; row.hover(true) end)
  hit.MouseLeave:Connect(function() if not dragging then Motion.to(knob, "Size", UDim2.fromOffset(14, 14), "quick") end; row.hover(false) end)
  hit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then contextMenu(knob, spec) end
  end)
  field.FocusLost:Connect(B.safe("slider.field", function()
    local typed = tonumber((string.gsub(field.Text, "[^%d%.%-]", "")))
    if typed then api.set(typed) end
    field.Text = text(value)
    Theme.bind(field, "TextColor3", "sub")
  end))
  field.Focused:Connect(function() Theme.bind(field, "TextColor3", "ink") end)
  return api
end

-- ---------------------------------------------------------------- dropdown / multi-select
local function optionList(options)
  local out = {}
  for _, option in ipairs(options) do
    if type(option) == "table" then out[#out + 1] = { value = option.value or option[1], label = option.label or option[2] or tostring(option.value or option[1]), icon = option.icon }
    else out[#out + 1] = { value = option, label = tostring(option) } end
  end
  return out
end
local function pill(slot, order)
  local button = UI.pressable(slot, { Name = "Select", Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 3,
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(button, "rSmall")
  UI.pad(button, 0, 9, 0, 11)
  UI.list(button, "x", 6, { v = "Center" })
  local label = UI.text(button, "", "label", "ink", { TextSize = 13, LayoutOrder = 1, TextTruncate = Enum.TextTruncate.AtEnd })
  local limit = Instance.new("UISizeConstraint"); limit.MaxSize = Vector2.new(132, 28); limit.Parent = label
  local chevron = UI.icon(button, "chevrons-up-down", 13, "faint", { LayoutOrder = 2 })
  return button, label, chevron
end

function Controls.dropdown(section, spec)
  local id = spec.id
  local options = optionList(spec.options)
  local value = id and Config.define(id, spec.default ~= nil and spec.default or options[1].value) or (spec.default ~= nil and spec.default or options[1].value)
  local row = makeRow(section, spec, 150)
  local button, label = pill(row.slot)
  local function labelOf(v)
    for _, option in ipairs(options) do if option.value == v then return option.label end end
    return tostring(v)
  end
  label.Text = labelOf(value)
  local api = { row = row, id = id }
  function api.get() return value end
  function api.set(next, quiet)
    if next == value then return end
    if id then Config.set(id, next, quiet) else
      value = next; label.Text = labelOf(value)
      if spec.changed then B.try("dropdown", spec.changed, value) end
    end
  end
  function api.options(list)
    options = optionList(list)
    label.Text = labelOf(value)
  end
  if id then
    Config.on(id, function(next)
      value = next
      if label.Parent then label.Text = labelOf(value) end
      if spec.changed then spec.changed(value) end
    end)
    if spec.changed then task.defer(B.safe("dropdown.init", function() spec.changed(value) end)) end
  end
  local function open()
    local items = {}
    for _, option in ipairs(options) do
      items[#items + 1] = { label = option.label, icon = option.icon, checked = option.value == value, run = function() api.set(option.value) end }
    end
    UI.menu(button, items, { align = "right", width = spec.menuWidth })
  end
  UI.wire(button, {
    hover = function(on) Motion.to(button, "BackgroundTransparency", on and T.fill3A or T.fill2A, "quick"); row.hover(on) end,
    click = function() UI.sfx("click", 0.6); open() end,
    alt = function() contextMenu(button, spec) end,
  })
  return api
end

-- value is a set stored as an array of the selected option values
function Controls.multi(section, spec)
  local id = spec.id
  local options = optionList(spec.options)
  local value = id and Config.define(id, spec.default or {}) or (spec.default or {})
  local row = makeRow(section, spec, 150)
  local button, label = pill(row.slot)
  local function has(v) return table.find(value, v) ~= nil end
  local function summary()
    if #value == 0 then return spec.empty or "None" end
    if #value == #options then return "All" end
    if #value <= 2 then
      local names = {}
      for _, option in ipairs(options) do if has(option.value) then names[#names + 1] = option.label end end
      return table.concat(names, ", ")
    end
    return #value .. " selected"
  end
  label.Text = summary()
  local api = { row = row, id = id }
  function api.get() return value end
  function api.has(v) return has(v) end
  function api.set(next, quiet)
    if id then Config.set(id, next, quiet) else
      value = next; label.Text = summary()
      if spec.changed then B.try("multi", spec.changed, value) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if label.Parent then label.Text = summary() end
      if spec.changed then spec.changed(value) end
    end)
    if spec.changed then task.defer(B.safe("multi.init", function() spec.changed(value) end)) end
  end
  local function flip(v)
    local next = table.clone(value)
    local at = table.find(next, v)
    if at then table.remove(next, at) else next[#next + 1] = v end
    -- keep option order, so two identical selections compare equal
    local ordered = {}
    for _, option in ipairs(options) do if table.find(next, option.value) then ordered[#ordered + 1] = option.value end end
    api.set(ordered)
  end
  local function open()
    UI.popover(button, { width = spec.menuWidth or 212, align = "right" }, function(content)
      local checks = {}
      local function refresh()
        for v, icon in pairs(checks) do icon.ImageTransparency = has(v) and 0 or 1 end
      end
      for index, option in ipairs(options) do
        local item = UI.frame(content, { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = index, Theme = { BackgroundColor3 = "ink" } })
        UI.corner(item, "rSmall")
        local x = 10
        if option.icon then
          UI.icon(item, option.icon, 16, "sub", { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
          x = 34
        end
        UI.text(item, option.label, "label", "ink", { Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13 })
        local box = UI.frame(item, { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
          Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill3A" } })
        UI.corner(box, 5)
        checks[option.value] = UI.icon(box, "check", 13, "accent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        UI.button(item, {
          hover = function(on) Motion.to(item, "BackgroundTransparency", on and T.fill2A or 1, "quick") end,
          click = function() UI.sfx("click", 0.6); flip(option.value); refresh() end,
        })
      end
      UI.divider(content, #options + 1)
      local footer = UI.frame(content, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = #options + 2 })
      for index, action in ipairs({ { "All", function() local all = {}; for _, o in ipairs(options) do all[#all + 1] = o.value end; api.set(all) end },
        { "None", function() api.set({}) end } }) do
        local link = UI.new("TextButton", { Text = action[1], FontFace = B.F.text500, TextSize = 12, BackgroundTransparency = 1, AutoButtonColor = false,
          AutomaticSize = Enum.AutomaticSize.XY, Position = UDim2.new(index == 1 and 0 or 1, index == 1 and 10 or -10, 0.5, 0),
          AnchorPoint = Vector2.new(index == 1 and 0 or 1, 0.5), Theme = { TextColor3 = "sub" }, Parent = footer })
        UI.wire(link, { click = function() UI.sfx("click", 0.5); action[2](); refresh() end,
          hover = function(on) Theme.bind(link, "TextColor3", on and "ink" or "sub") end })
      end
      refresh()
    end)
  end
  UI.wire(button, {
    hover = function(on) Motion.to(button, "BackgroundTransparency", on and T.fill3A or T.fill2A, "quick"); row.hover(on) end,
    click = function() UI.sfx("click", 0.6); open() end,
    alt = function() contextMenu(button, spec) end,
  })
  return api
end

-- ---------------------------------------------------------------- segmented
-- A row of mutually exclusive choices with a pill that slides like liquid:
-- its leading edge arrives first, the trailing edge catches up.
function Controls.segmentedBar(parent, options, initial, onPick, props)
  options = optionList(options)
  local bar = UI.frame(parent, { Name = "Segmented", Size = UDim2.new(1, 0, 0, 30), Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(bar, "rSmall")
  if props then
    for key, value in pairs(props) do bar[key] = value end
  end
  local count = #options
  local thumb = UI.frame(bar, { Name = "Thumb", Size = UDim2.new(1 / count, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill3A" } })
  UI.corner(thumb, "rSmall")
  local labels = {}
  local current
  -- left and right edges are separate springs (scale units)
  local edges = Motion.spring(2, "snappy", function(x)
    local a, b = math.min(x[1], x[2]), math.max(x[1], x[2])
    thumb.Position = UDim2.new(a, 2, 0, 2)
    thumb.Size = UDim2.new(b - a, -4, 1, -4)
  end, 0.0004)
  local function select(index, instant)
    local previous = current
    current = index
    for i, label in ipairs(labels) do Theme.bind(label, "TextColor3", i == index and "ink" or "sub") end
    local a, b = (index - 1) / count, index / count
    if instant or not previous then edges:snap({ a, b }); return end
    -- the edge in the direction of travel leads
    if index > previous then
      edges.g[2] = b; edges:to({ edges.g[1], b }, "snappy")
      task.delay(0.045, function() edges:to({ a, b }, "liquid") end)
    else
      edges.g[1] = a; edges:to({ a, edges.g[2] }, "snappy")
      task.delay(0.045, function() edges:to({ a, b }, "liquid") end)
    end
  end
  for index, option in ipairs(options) do
    local cell = UI.frame(bar, { Size = UDim2.new(1 / count, 0, 1, 0), Position = UDim2.fromScale((index - 1) / count, 0), ZIndex = 2 })
    labels[index] = UI.text(cell, option.label, "label", "sub", { TextSize = 12.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    UI.button(cell, { click = function()
      if current == index then return end
      UI.sfx("tab", 0.6)
      select(index)
      onPick(option.value, index)
    end })
  end
  local startIndex = 1
  for index, option in ipairs(options) do if option.value == initial then startIndex = index end end
  select(startIndex, true)
  return bar, function(v)
    for index, option in ipairs(options) do if option.value == v then select(index) end end
  end
end

function Controls.segmented(section, spec)
  local id = spec.id
  local options = optionList(spec.options)
  local value = id and Config.define(id, spec.default ~= nil and spec.default or options[1].value) or (spec.default ~= nil and spec.default or options[1].value)
  local width = spec.width or math.min(64 * #options, 220)
  local row = makeRow(section, spec, width)
  local holder = UI.frame(row.slot, { Size = UDim2.fromOffset(width, 30), LayoutOrder = 3 })
  local api = { row = row, id = id }
  local _, show = Controls.segmentedBar(holder, options, value, function(v)
    if id then Config.set(id, v) else
      value = v
      if spec.changed then B.try("segmented", spec.changed, v) end
    end
  end)
  function api.get() return value end
  function api.set(v) if id then Config.set(id, v) else value = v; show(v) end end
  if id then
    Config.on(id, function(next)
      value = next
      if holder.Parent then show(next) end
      if spec.changed then spec.changed(next) end
    end)
    if spec.changed then task.defer(B.safe("segmented.init", function() spec.changed(value) end)) end
  end
  return api
end

-- ---------------------------------------------------------------- button
function Controls.pillButton(parent, text, style, run, props)
  local primary, danger = style == "primary", style == "danger"
  local button = UI.pressable(parent, { Name = "Button", Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X })
  local function rest() return primary and 0 or (danger and 0.84 or T.fill2A) end
  Theme.bind(button, "BackgroundColor3", primary and "accent" or (danger and "bad" or "ink"))
  button.BackgroundTransparency = rest()
  if not primary and not danger then Theme.bind(button, "BackgroundTransparency", "fill2A") end
  UI.corner(button, "rSmall")
  UI.pad(button, 0, 13)
  local label = UI.text(button, text, "button", primary and "accentInk" or (danger and "bad" or "ink"),
    { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X })
  local scale = UI.scaleOf(button)
  if props then
    for key, value in pairs(props) do button[key] = value end
  end
  UI.wire(button, {
    hover = function(on)
      local base = rest()
      Motion.to(button, "BackgroundTransparency", on and (primary and 0.14 or math.max(0, base - 0.06)) or base, "quick")
    end,
    press = function(on) Motion.to(scale, "Scale", on and 0.95 or 1, on and "quick" or "bouncy") end,
    click = function() UI.sfx("click", 0.8); if run then run() end end,
  })
  return button, label
end

function Controls.button(section, spec)
  local row = makeRow(section, spec, 110)
  local id = spec.id
  if id then
    Config.action(id, function() if spec.run then spec.run() end end)
    spec.bindable = spec.bindable ~= false
    if spec.bindable then
      bindChip(row.slot, id, 1)
      Controls.bindables[id] = { label = spec.label or id, kind = "button", page = section.page }
    end
  end
  local button, label = Controls.pillButton(row.slot, spec.text or "Run", spec.style, function()
    if spec.run then B.try("button." .. (spec.label or "?"), spec.run) end
  end, { LayoutOrder = 3 })
  button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and id then contextMenu(button, { id = id, bindable = spec.bindable, label = spec.label, kind = "button" }) end
  end)
  return { row = row, button = button, setText = function(text) label.Text = text end }
end

-- ---------------------------------------------------------------- keybind
function Controls.keybind(section, spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "None") or (spec.default or "None")
  local row = makeRow(section, spec, 100)
  local chip = UI.pressable(row.slot, { Name = "Key", Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3,
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(chip, "rSmall")
  UI.pad(chip, 0, 11)
  local floor = Instance.new("UISizeConstraint"); floor.MinSize = Vector2.new(46, 28); floor.Parent = chip
  local label = UI.text(chip, Config.keyLabel(value ~= "None" and value or nil), "monoBold", "ink", { Size = UDim2.fromScale(1, 1),
    AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center })
  local stroke = UI.stroke(chip, "accent", 1, 1)
  local api = { row = row, id = id }
  function api.get() return value end
  local function show() label.Text = Config.keyLabel(value ~= "None" and value or nil) end
  if id then
    Config.on(id, function(next)
      value = next
      if label.Parent then show() end
      if spec.changed then spec.changed(next) end
    end)
    if spec.changed then task.defer(B.safe("keybind.init", function() spec.changed(value) end)) end
  end
  UI.wire(chip, {
    hover = function(on) Motion.to(chip, "BackgroundTransparency", on and T.fill3A or T.fill2A, "quick"); row.hover(on) end,
    click = function()
      UI.sfx("click", 0.6)
      label.Text = "…"
      Motion.to(stroke, "Transparency", 0, "quick")
      Controls.captureKey(function(key, cancelled)
        Motion.to(stroke, "Transparency", 1, "smooth")
        if not cancelled then
          local next = key or "None"
          if id then Config.set(id, next) else value = next; if spec.changed then spec.changed(next) end end
        end
        show()
      end)
    end,
    alt = function() contextMenu(chip, spec) end,
  })
  return api
end

-- ---------------------------------------------------------------- text input
function Controls.field(parent, props, onSubmit)
  local field = UI.frame(parent, { Name = "Field", Size = UDim2.fromOffset(150, 28), Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(field, "rSmall")
  local stroke = UI.stroke(field, "accent", 1, 1)
  local box = UI.new("TextBox", { Name = "Box", BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "",
    FontFace = B.F.text400, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true,
    Theme = { TextColor3 = "ink", PlaceholderColor3 = "faint" }, Parent = field })
  if props then
    for key, value in pairs(props) do
      if key == "Width" then field.Size = UDim2.fromOffset(value, 28) else box[key] = value end
    end
  end
  box.Focused:Connect(function() Motion.to(stroke, "Transparency", 0.25, "quick") end)
  box.FocusLost:Connect(B.safe("field", function(enter)
    Motion.to(stroke, "Transparency", 1, "smooth")
    if onSubmit then onSubmit(box.Text, enter) end
  end))
  return field, box
end

function Controls.input(section, spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or "") or (spec.default or "")
  local row = makeRow(section, spec, spec.width or 150)
  local api = { row = row, id = id }
  local _, box = Controls.field(row.slot, { Width = spec.width or 150, PlaceholderText = spec.placeholder or "", Text = tostring(value) }, function(text)
    if spec.numeric then
      local n = tonumber(text)
      if not n then api.box.Text = tostring(value); return end
      text = n
    end
    if id then Config.set(id, text) else
      value = text
      if spec.changed then B.try("input", spec.changed, text) end
    end
  end)
  api.box = box
  function api.get() return value end
  if id then
    Config.on(id, function(next)
      value = next
      if box.Parent and not box:IsFocused() then box.Text = tostring(next) end
      if spec.changed then spec.changed(next) end
    end)
  end
  return api
end

-- ---------------------------------------------------------------- colour
local function hueColor(h) return Color3.fromHSV(h, 1, 1) end
function Controls.colorPopover(anchor, initial, onChange)
  local h, s, v = initial:ToHSV()
  return UI.popover(anchor, { width = 224, align = "right", pad = 10, gap = 10 }, function(content)
    local square = UI.frame(content, { Name = "SV", Size = UDim2.new(1, 0, 0, 132), BackgroundTransparency = 0, BackgroundColor3 = hueColor(h), LayoutOrder = 1 })
    UI.corner(square, 9)
    local white = UI.frame(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 })
    UI.corner(white, 9)
    UI.gradient(white, { Transparency = UI.alphaSeq(0, 0, 1, 1) })
    local black = UI.frame(square, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 2 })
    UI.corner(black, 9)
    UI.gradient(black, { Rotation = 90, Transparency = UI.alphaSeq(0, 1, 1, 0) })
    local dot = UI.frame(square, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, BackgroundTransparency = 1 })
    UI.corner(dot, true)
    local ring = Instance.new("UIStroke"); ring.Color = Color3.new(1, 1, 1); ring.Thickness = 2; ring.Parent = dot

    local hueBar = UI.frame(content, { Name = "Hue", Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, LayoutOrder = 2 })
    UI.corner(hueBar, true)
    local stops = {}
    for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
    UI.gradient(hueBar, { Color = ColorSequence.new(stops) })
    local hueKnob = UI.frame(hueBar, { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1),
      BackgroundTransparency = 0, ZIndex = 3 })
    UI.corner(hueKnob, true)
    local hueRing = Instance.new("UIStroke"); hueRing.Color = Color3.new(0, 0, 0); hueRing.Transparency = 0.7; hueRing.Parent = hueKnob

    local bottom = UI.frame(content, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 3 })
    local preview = UI.frame(bottom, { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = initial })
    UI.corner(preview, 8)
    local hexField, hexBox
    local function emit(fromHex)
      local color = Color3.fromHSV(h, s, v)
      square.BackgroundColor3 = hueColor(h)
      dot.Position = UDim2.fromScale(s, 1 - v)
      hueKnob.Position = UDim2.fromScale(h, 0.5)
      preview.BackgroundColor3 = color
      if hexBox and not fromHex and not hexBox:IsFocused() then hexBox.Text = "#" .. util.toHex(color) end
      onChange(color)
    end
    hexField, hexBox = Controls.field(bottom, { Width = 96, Text = "#" .. util.toHex(initial), FontFace = B.F.mono400, TextSize = 12 }, function(text)
      local clean = string.gsub(text, "[^%x]", "")
      if #clean == 6 then
        h, s, v = util.hex(clean):ToHSV()
        emit(true)
      end
      hexBox.Text = "#" .. util.toHex(Color3.fromHSV(h, s, v))
    end)
    hexField.Position = UDim2.fromOffset(36, 0)
    -- quick picks: the accent family
    local picks = UI.frame(content, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 })
    UI.list(picks, "x", 7)
    for index, accent in ipairs(Theme.accents) do
      local swatch = UI.frame(picks, { Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = accent.color, LayoutOrder = index })
      UI.corner(swatch, true)
      UI.button(swatch, { click = function() h, s, v = accent.color:ToHSV(); emit() end })
    end
    local svHit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, AutoButtonColor = false, Parent = square })
    local function sv(point)
      local p, size = square.AbsolutePosition, square.AbsoluteSize
      s = util.clamp01((point.X - p.X) / size.X)
      v = 1 - util.clamp01((point.Y - p.Y) / size.Y)
      emit()
    end
    UI.drag(svHit, sv, sv)
    local hueHit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 12), Position = UDim2.fromOffset(0, -6), ZIndex = 6,
      AutoButtonColor = false, Parent = hueBar })
    local function hue(point)
      h = util.clamp01((point.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X)
      emit()
    end
    UI.drag(hueHit, hue, hue)
    dot.Position = UDim2.fromScale(s, 1 - v)
    hueKnob.Position = UDim2.fromScale(h, 0.5)
  end)
end

function Controls.color(section, spec)
  local id = spec.id
  local value = id and Config.define(id, spec.default or Color3.new(1, 1, 1)) or (spec.default or Color3.new(1, 1, 1))
  local row = makeRow(section, spec, 60)
  local swatch = UI.frame(row.slot, { Name = "Swatch", Size = UDim2.fromOffset(34, 22), BackgroundTransparency = 0, BackgroundColor3 = value, LayoutOrder = 3 })
  UI.corner(swatch, 7)
  UI.stroke(swatch, "ink", "stroke2A")
  local api = { row = row, id = id }
  function api.get() return value end
  function api.set(next, quiet)
    if id then Config.set(id, next, quiet) else
      value = next; swatch.BackgroundColor3 = next
      if spec.changed then B.try("color", spec.changed, next) end
    end
  end
  if id then
    Config.on(id, function(next)
      value = next
      if swatch.Parent then swatch.BackgroundColor3 = next end
      if spec.changed then spec.changed(next) end
    end)
    if spec.changed then task.defer(B.safe("color.init", function() spec.changed(value) end)) end
  end
  local scale = UI.scaleOf(swatch)
  UI.button(swatch, {
    hover = function(on) Motion.to(scale, "Scale", on and 1.08 or 1, "snappy"); row.hover(on) end,
    click = function() UI.sfx("click", 0.6); Controls.colorPopover(swatch, value, function(color) api.set(color) end) end,
    alt = function() contextMenu(swatch, spec) end,
  })
  return api
end

-- ---------------------------------------------------------------- static rows
function Controls.note(section, spec)
  section.count = (section.count or 0) + 1
  local tone = spec.tone or "sub"
  local box = UI.frame(section.body, { Name = "Note", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = section.count })
  UI.pad(box, 10, 14, 12, 14)
  local inner = UI.frame(box, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.list(inner, "x", 9)
  if spec.icon then UI.icon(inner, spec.icon, 15, tone, { LayoutOrder = 1 }) end
  local text = UI.text(inner, spec.text or "", "caption", tone, { TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
    Size = UDim2.new(1, spec.icon and -24 or 0, 0, 0), LineHeight = 1.2, RichText = spec.rich == true })
  return { frame = box, set = function(value) text.Text = value end }
end
function Controls.custom(section, spec)
  section.count = (section.count or 0) + 1
  local frame = UI.frame(section.body, { Name = spec.name or "Custom", Size = UDim2.new(1, 0, 0, spec.height or 100), LayoutOrder = section.count })
  if spec.height == nil then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("custom", spec.build, frame)
  return frame
end
end
