do -- 51_keys.lua
-- ============================================================================
--  51 keys     the keyboard, drawn, with what every key does written on it
--
--  A key can be given a feature from either side: right-click a toggle or a
--  button and press a key, or come here, click the key and pick the feature.
--  The picture is the same either way. A bound key carries its feature's name
--  and lights up while that feature is on; the keys the hub and movement already
--  use are marked; a key asked to do two things is flagged. The same list can
--  sit on screen while the hub is hidden.
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Window, Controls = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Window, B.Controls
local UIS = S.UserInputService
local Keys = { caps = {}, builtin = {} }
B.Keys = Keys
B.pages = B.pages or {}

-- An ANSI board in units of one key; every row is fifteen units wide. A unit of 48 keeps every
-- key an even number of pixels wide, which matters: a UDim offset is a whole number, and a key
-- anchored at its centre with an odd width sits half a pixel off its neighbours.
local UNIT, GAP, HEIGHT = 44, 4, 40
local function k(key, width) return { key = key, width = width or 1 } end
local function gap(width) return { width = width } end
local ROWS = {
  { k("Escape"), gap(1), k("F1"), k("F2"), k("F3"), k("F4"), gap(0.5), k("F5"), k("F6"), k("F7"), k("F8"), gap(0.5), k("F9"), k("F10"), k("F11"), k("F12") },
  { k("Backquote"), k("One"), k("Two"), k("Three"), k("Four"), k("Five"), k("Six"), k("Seven"), k("Eight"), k("Nine"), k("Zero"), k("Minus"), k("Equals"), k("Backspace", 2) },
  { k("Tab", 1.5), k("Q"), k("W"), k("E"), k("R"), k("T"), k("Y"), k("U"), k("I"), k("O"), k("P"), k("LeftBracket"), k("RightBracket"), k("BackSlash", 1.5) },
  { k("CapsLock", 1.75), k("A"), k("S"), k("D"), k("F"), k("G"), k("H"), k("J"), k("K"), k("L"), k("Semicolon"), k("Quote"), k("Return", 2.25) },
  { k("LeftShift", 2.25), k("Z"), k("X"), k("C"), k("V"), k("B"), k("N"), k("M"), k("Comma"), k("Period"), k("Slash"), k("RightShift", 2.75) },
  { k("LeftControl", 1.5), k("LeftAlt", 1.25), k("Space", 5.5), k("RightAlt", 1.25), k("RightControl", 1.5), k("Left"), k("Up"), k("Down"), k("Right") },
  { k("Insert", 1.25), k("Delete", 1.25), k("Home", 1.25), k("End", 1.25), k("PageUp", 1.25), k("PageDown", 1.25), gap(0.5), k("MouseButton2", 2.25), k("MouseButton3", 2.25) },
}
Keys.width = 15 * (UNIT + GAP) - GAP
Keys.height = #ROWS * (HEIGHT + GAP) - GAP
local LONG = { MouseButton2 = "Right click", MouseButton3 = "Middle click", Backspace = "Backspace", Return = "Enter", CapsLock = "Caps", Space = "Space",
  LeftShift = "Shift", RightShift = "Shift", LeftControl = "Ctrl", RightControl = "Ctrl", LeftAlt = "Alt", RightAlt = "Alt", Tab = "Tab", Escape = "Esc",
  Insert = "Ins", Delete = "Del", PageUp = "PgUp", PageDown = "PgDn" }
-- on the cap the two Shifts and the two Ctrls are told apart by where they sit; in a sentence they need saying
local function capLabel(key) return LONG[key] or Config.keyLabel(key) end
local function keyName(key) return Config.keyLabel(key) end

-- ---------------------------------------------------------------- what is on a key
-- Read the hub and movement keys fresh after rebinding.
local function readBuiltins()
  local map = {}
  local function put(key, short, what, flag)
    if type(key) ~= "string" or key == "None" then return end
    map[key] = map[key] or {}
    table.insert(map[key], { short = short, what = what, flag = flag })
  end
  put(Config.get("app.key.menu"), "Menu", "opens and closes the hub", "app.key.menu")
  put(Config.get("app.key.panic"), "Panic", "unloads BASED", "app.key.panic")
  put("Space", "Jump", "jump")
  for _, key in ipairs({ "W", "A", "S", "D" }) do put(key, "Move", "walk and steer") end
  Keys.builtin = map
  return map
end
-- (a feature whose switch has not been drawn yet is named from its id: "dahood.airJump" -> "Air jump")
local function nameFromId(id)
  local last = string.match(id, "([^%.]+)$") or id
  last = string.gsub(last, "(%l)(%u)", "%1 %2")
  return string.upper(string.sub(last, 1, 1)) .. string.lower(string.sub(last, 2))
end
local function featureOf(id)
  local entry = Controls.bindables[id]
  local kind = entry and entry.kind or (type(Config.get(id)) == "boolean" and "toggle" or "button")
  return entry and entry.label or nameFromId(id), kind, entry and entry.page and entry.page.title or nil
end
-- every feature bound to `key`, by name
function Keys.on(key)
  local list = {}
  for id, bind in pairs(Config.binds) do
    if bind.key == key then
      local label, kind, page = featureOf(id)
      list[#list + 1] = { id = id, label = label, kind = kind, page = page, mode = bind.mode, on = Config.get(id) == true or (kind == "button" and Config.isActive(id)) }
    end
  end
  table.sort(list, function(a, b) return a.label < b.label end)
  return list
end
-- every bind there is, in keyboard order
function Keys.all()
  local order, list = {}, {}
  for _, row in ipairs(ROWS) do
    for _, item in ipairs(row) do
      if item.key then order[item.key] = #list + 1; list[#list + 1] = item.key end
    end
  end
  local out = {}
  for id, bind in pairs(Config.binds) do
    if bind.key then
      local label, kind, page = featureOf(id)
      out[#out + 1] = { id = id, key = bind.key, label = label, kind = kind, page = page, mode = bind.mode, on = Config.get(id) == true or (kind == "button" and Config.isActive(id)) }
    end
  end
  table.sort(out, function(a, b)
    local ka, kb = order[a.key] or 999, order[b.key] or 999
    if ka ~= kb then return ka < kb end
    return a.label < b.label
  end)
  return out
end
function Keys.describe(key)
  local features, roles = Keys.on(key), Keys.builtin[key]
  local parts = {}
  for _, f in ipairs(features) do
    parts[#parts + 1] = f.label .. (f.kind == "toggle" and (f.mode == "hold" and " (while held" or " (toggle") .. (f.on and ", on)" or ", off)") or " (runs it)")
  end
  for _, role in ipairs(roles or {}) do parts[#parts + 1] = role.what end
  local name = keyName(key)
  if #parts == 0 then return name .. "  ·  free. Click it to give it a feature." end
  local clash = #features > 1 or (#features > 0 and roles ~= nil)
  return name .. "  ·  " .. table.concat(parts, "  +  ") .. (clash and "   — more than one thing on this key" or "")
end

-- ---------------------------------------------------------------- menus
local function menuRow(content, order, item, close)
  local row = UI.frame(content, { Name = item.name or "Item", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = order, Theme = { BackgroundColor3 = "ink" } })
  UI.corner(row, "rSmall")
  local x = 10
  if item.icon then
    UI.icon(row, item.icon, 16, item.danger and "bad" or "sub", { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
    x = 34
  end
  UI.text(row, item.label, "label", item.danger and "bad" or "ink", { Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13,
    Size = UDim2.new(1, -(x + (item.hint and 78 or 30)), 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
  if item.checked then
    UI.icon(row, "check", 15, "accent", { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
  elseif item.hint then
    UI.text(row, item.hint, "mono", "faint", { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 11 })
  end
  UI.button(row, {
    hover = function(on) Motion.to(row, "BackgroundTransparency", on and T.fill2A or 1, "quick") end,
    click = function()
      UI.sfx("click", 0.6)
      close()
      if item.run then B.try("keys.menu", item.run) end
    end,
  })
  return row
end
-- pick a feature for `key`: every toggle and button the hub has, searchable
function Keys.pick(anchor, key)
  local list = {}
  for id, entry in pairs(Controls.bindables) do
    local bind = Config.bindOf(id)
    if not (bind and bind.key == key) then
      list[#list + 1] = { id = id, label = entry.label, page = entry.page and entry.page.title or "", key = bind and bind.key or nil }
    end
  end
  table.sort(list, function(a, b) return a.label < b.label end)
  return UI.popover(anchor, { width = 276, align = "center", pad = 8, gap = 6 }, function(content, close)
    UI.text(content, "Give " .. keyName(key) .. " a feature", "eyebrow", "faint", { LayoutOrder = 1, TextSize = 9 })
    local _, box = Controls.field(content, { Width = 260, PlaceholderText = "Search " .. #list .. " features" }, function() end)
    box.Parent.LayoutOrder = 2
    local holder = UI.frame(content, { Name = "List", Size = UDim2.new(1, 0, 0, 238), LayoutOrder = 3, ClipsDescendants = true })
    local scroller = UI.scroll(holder, { Size = UDim2.fromScale(1, 1), Name = "Scroll" })
    local rows = UI.frame(scroller, { Name = "Rows", Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
    UI.list(rows, "y", 2)
    local made = {}
    for index, feature in ipairs(list) do
      local row = menuRow(rows, index, { name = feature.id, label = feature.label, hint = feature.key and Config.keyLabel(feature.key) or feature.page, run = function()
        Config.bind(feature.id, key)
        Window.toast({ title = feature.label .. " is on " .. keyName(key), text = "Right-click the key to clear it.", icon = "keyboard" })
      end }, close)
      made[index] = { row = row, text = string.lower(feature.label .. " " .. feature.page) }
    end
    if #list == 0 then
      UI.text(rows, "Nothing left to bind: open the other tabs once so their switches are known.", "caption", "sub", { TextWrapped = true, Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y })
    end
    box:GetPropertyChangedSignal("Text"):Connect(function()
      local query = string.lower(box.Text)
      for _, item in ipairs(made) do item.row.Visible = query == "" or string.find(item.text, query, 1, true) ~= nil end
    end)
  end)
end
-- what clicking a key opens: what is on it, and what can be done about that
function Keys.menu(anchor, key)
  local features, roles = Keys.on(key), Keys.builtin[key]
  return UI.popover(anchor, { width = 252, align = "center" }, function(content, close)
    local order = 0
    local function add(item) order += 1; return menuRow(content, order, item, close) end
    local head = UI.frame(content, { Name = "Head", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0 })
    UI.text(head, keyName(key), "heading", "ink", { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
    UI.text(head, #features == 0 and (roles and roles[1].short or "Free") or (#features .. (#features == 1 and " feature" or " features")), "mono", "faint",
      { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 11 })
    for _, f in ipairs(features) do
      if f.kind == "toggle" then
        add({ name = "Hold_" .. f.id, label = f.label .. ": only while held", icon = "hand", checked = f.mode == "hold", run = function()
          Config.bind(f.id, key, f.mode == "hold" and "toggle" or "hold")
        end })
      end
      add({ name = "Unbind_" .. f.id, label = "Take " .. f.label .. " off this key", icon = "x", danger = true, run = function() Config.bind(f.id, nil) end })
    end
    for _, role in ipairs(roles or {}) do
      if role.flag then
        add({ name = "Move_" .. role.flag, label = "Move " .. string.lower(role.short) .. " to another key…", icon = "keyboard", run = function()
          Window.toast({ title = "Press a key", text = "Esc cancels · Backspace clears", icon = "keyboard", time = 2.2 })
          Controls.captureKey(function(next, cancelled)
            if not cancelled then Config.set(role.flag, next or "None") end
          end)
        end })
      end
    end
    add({ name = "Bind", label = "Bind a feature to this key…", icon = "plus", run = function() task.defer(Keys.pick, anchor, key) end })
  end)
end
function Keys.clear(key)
  local cleared = 0
  for _, f in ipairs(Keys.on(key)) do
    Config.bind(f.id, nil)
    cleared += 1
  end
  if cleared > 0 then Window.toast({ title = keyName(key) .. " is free again", text = cleared .. (cleared == 1 and " feature taken off it." or " features taken off it."), icon = "keyboard" }) end
  return cleared
end

-- ---------------------------------------------------------------- the board
local function tint(instance, property, token) Theme.bind(instance, property, token) end
local function fixed(instance, property, value)
  Theme.unbind(instance, property)
  instance[property] = value
end
local function paint(entry)
  local key = entry.key
  local features, roles = Keys.on(key), Keys.builtin[key]
  local on = false
  for _, f in ipairs(features) do on = on or f.on end
  local clash = #features > 1 or (#features > 0 and roles ~= nil)
  entry.features, entry.roles, entry.clash, entry.lit = features, roles, clash, on
  local cap, label, what, stroke = entry.cap, entry.label, entry.what, entry.stroke
  if #features > 0 then
    -- bound: the feature's name on the key, solid while it is on
    tint(cap, "BackgroundColor3", "accent")
    fixed(cap, "BackgroundTransparency", on and 0 or 0.8)
    tint(label, "TextColor3", on and "accentInk" or "ink")
    tint(what, "TextColor3", on and "accentInk" or "ink")
    what.Text = features[1].label .. (#features > 1 and ("  +" .. #features - 1) or "")
    tint(stroke, "Color", clash and "warn" or "accent")
    fixed(stroke, "Transparency", clash and 0 or 0.35)
  elseif roles then
    -- Reserved hub and movement keys.
    tint(cap, "BackgroundColor3", "ink")
    tint(cap, "BackgroundTransparency", "fill2A")
    tint(label, "TextColor3", "ink")
    tint(what, "TextColor3", "faint")
    what.Text = roles[1].short
    tint(stroke, "Color", "ink")
    tint(stroke, "Transparency", "stroke2A")
  else
    tint(cap, "BackgroundColor3", "ink")
    tint(cap, "BackgroundTransparency", "fill1A")
    tint(label, "TextColor3", "sub")
    what.Text = ""
    tint(stroke, "Color", "ink")
    tint(stroke, "Transparency", "strokeA")
  end
  local named = what.Text ~= ""
  what.Visible = named
  label.Position = named and UDim2.new(0.5, 0, 0, 13) or UDim2.fromScale(0.5, 0.5)
end
local repaintQueued = false
function Keys.repaint()
  if repaintQueued then return end
  repaintQueued = true
  task.defer(function()
    repaintQueued = false
    readBuiltins()
    for _, entry in pairs(Keys.caps) do
      if entry.cap.Parent then paint(entry) end
    end
    if Keys.renderList then Keys.renderList() end
    if Keys.renderHud then Keys.renderHud() end
  end)
end
local function board(frame)
  local holder = UI.frame(frame, { Name = "Board", Size = UDim2.fromOffset(Keys.width, Keys.height), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
  local legend = UI.text(frame, "", "caption", "sub", { Name = "Legend", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, Keys.height + 18), Size = UDim2.fromOffset(Keys.width, 16),
    AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
  local RESTING = "Click a key to give it a feature.  Right-click a key to clear it.  Bound keys light up while their feature is on."
  legend.Text = RESTING
  Keys.legend = legend
  readBuiltins()
  for rowIndex, row in ipairs(ROWS) do
    local x = 0
    local y = (rowIndex - 1) * (HEIGHT + GAP)
    for _, item in ipairs(row) do
      local width = item.width * (UNIT + GAP) - GAP
      if item.key then
        local key = item.key
        -- anchored at its centre, so the press shrinks it in place
        local cap = UI.pressable(holder, { Name = "Cap_" .. key, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + width / 2, y + HEIGHT / 2),
          Size = UDim2.fromOffset(width, HEIGHT) })
        UI.corner(cap, "rSmall")
        local entry = { key = key, cap = cap, scale = UI.scaleOf(cap) }
        entry.stroke = UI.stroke(cap, "ink", "strokeA")
        entry.label = UI.text(cap, capLabel(key), "mono", "sub", { Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextSize = 11 })
        entry.what = UI.text(cap, "", "caption", "ink", { Name = "What", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -6, 0, 11),
          AutomaticSize = Enum.AutomaticSize.None, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Visible = false })
        Keys.caps[key] = entry
        paint(entry)
        UI.wire(cap, {
          hover = function(over)
            legend.Text = over and Keys.describe(key) or RESTING
            Theme.bind(legend, "TextColor3", over and (entry.clash and "warn" or "ink") or "sub")
            if not entry.held then Motion.to(entry.scale, "Scale", over and 1.05 or 1, "snappy") end
          end,
          click = function() UI.sfx("click", 0.6); Keys.menu(cap, key) end,
          alt = function() Keys.clear(key) end,
        })
      end
      x += item.width * (UNIT + GAP)
    end
  end
  -- a key pressed for real dips on the board: it is the quickest way to find out which one is which
  B.connect(UIS.InputBegan, function(input)
    local entry = Keys.caps[Config.keyName(input) or ""]
    if entry and entry.cap.Parent and Window.showing("keys") then
      entry.held = true
      Motion.to(entry.scale, "Scale", 0.9, "quick")
    end
  end, "keys.press")
  B.connect(UIS.InputEnded, function(input)
    local entry = Keys.caps[Config.keyName(input) or ""]
    if entry and entry.held then
      entry.held = false
      if entry.cap.Parent then Motion.to(entry.scale, "Scale", 1, "bouncy") end
    end
  end, "keys.release")
  Theme.changed:connect(function() if holder.Parent then Keys.repaint() end end)
end

-- ---------------------------------------------------------------- the list beside it
local function list(frame)
  local holder = UI.frame(frame, { Name = "Bound", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.list(holder, "y", 0)
  UI.pad(holder, 2, 0, 6, 0)
  function Keys.renderList()
    if not holder.Parent then return end
    for _, child in ipairs(holder:GetChildren()) do
      if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    local binds = Keys.all()
    if #binds == 0 then
      local empty = UI.frame(holder, { Name = "Empty", Size = UDim2.new(1, 0, 0, 74) })
      UI.icon(empty, "keyboard", 20, "faint", { Position = UDim2.fromOffset(14, 14) })
      UI.text(empty, "Nothing is bound yet", "label", "ink", { Position = UDim2.fromOffset(44, 12) })
      UI.text(empty, "Click a key on the board, or right-click any switch in the hub and press the key you want for it.", "caption", "sub", { Position = UDim2.fromOffset(44, 32),
        Size = UDim2.new(1, -58, 0, 30), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.15 })
      return
    end
    for index, bind in ipairs(binds) do
      local row = UI.frame(holder, { Name = "Bind_" .. bind.id, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = index })
      if index > 1 then
        UI.frame(row, { Name = "Rule", Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0), Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "strokeA" } })
      end
      local chip = UI.frame(row, { Name = "Chip", Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(58, 24),
        Theme = { BackgroundColor3 = "accent" }, BackgroundTransparency = bind.on and 0 or 0.8 })
      UI.corner(chip, 7)
      UI.text(chip, Config.keyLabel(bind.key), "monoBold", bind.on and "accentInk" or "ink", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextSize = 11 })
      UI.text(row, bind.label, "label", "ink", { Name = "Feature", Position = UDim2.new(0, 84, 0.5, bind.page and -8 or 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13,
        Size = UDim2.new(1, -220, 0, 18), AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
      if bind.page then
        UI.text(row, bind.page, "caption", "faint", { Position = UDim2.new(0, 84, 0.5, 9), AnchorPoint = Vector2.new(0, 0.5), TextSize = 11 })
      end
      -- how the key works it: press to flip, hold to keep on, or simply run
      local mode = UI.pressable(row, { Name = "Mode", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.fromOffset(74, 24),
        Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
      UI.corner(mode, 7)
      UI.text(mode, bind.kind == "toggle" and (bind.mode == "hold" and "While held" or "Toggle") or "Runs it", "caption", bind.kind == "toggle" and "ink" or "faint",
        { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextSize = 11 })
      if bind.kind == "toggle" then
        UI.wire(mode, { click = function() UI.sfx("click", 0.5); Config.bind(bind.id, bind.key, bind.mode == "hold" and "toggle" or "hold") end })
      end
      local remove = UI.pressable(row, { Name = "Unbind", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(24, 24) })
      UI.corner(remove, 7)
      local cross = UI.icon(remove, "x", 14, "faint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
      UI.wire(remove, {
        hover = function(over) Theme.bind(cross, "ImageColor3", over and "bad" or "faint") end,
        click = function() UI.sfx("click", 0.5); Config.bind(bind.id, nil) end,
      })
    end
  end
  Keys.renderList()
end

-- ---------------------------------------------------------------- a list on screen that lights smoothly
-- Rows are kept from one draw to the next: a feature switched on fades its row in (and its key
-- chip pops), switched off it fades back. Only a change of what is bound redraws the rows.
local TS = S.TweenService
local LIGHT = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Keys.LIGHT = LIGHT
-- what the rows show, as one string: equal means only the lights may have changed
function Keys.shape(binds, moving, most)
  local parts = { moving and "m" or "-", tostring(#binds) }
  for index, bind in ipairs(binds) do
    if index > most then break end
    parts[#parts + 1] = bind.id .. "|" .. tostring(bind.key) .. "|" .. tostring(bind.mode) .. "|" .. tostring(bind.label)
  end
  return table.concat(parts, ";")
end
function Keys.basedPanel(holder)
  local glass = UI.glass(holder, { level = "popover", radius = 14, shadow = 20, shadowY = 8, grain = false, props = { Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY } })
  local body = UI.frame(glass, { Name = "Body", Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY })
  UI.pad(body, 9, 10, 10, 10)
  UI.list(body, "y", 3)
  local api = { frame = glass, rows = {}, shape = nil }
  local function light(row, on, animate)
    row.on = on
    local goal = { chip = on and 0 or 0.8, wash = on and 0.88 or 1, key = on and T.accentInk or T.ink, name = on and T.ink or T.sub }
    if animate and not Motion.reduced then
      TS:Create(row.chip, LIGHT, { BackgroundTransparency = goal.chip }):Play()
      TS:Create(row.wash, LIGHT, { BackgroundTransparency = goal.wash }):Play()
      TS:Create(row.key, LIGHT, { TextColor3 = goal.key }):Play()
      TS:Create(row.name, LIGHT, { TextColor3 = goal.name }):Play()
      if on then
        row.pop.Scale = 1.22
        Motion.to(row.pop, "Scale", 1, "bouncy")
      end
    else
      row.chip.BackgroundTransparency, row.wash.BackgroundTransparency = goal.chip, goal.wash
      row.key.TextColor3, row.name.TextColor3 = goal.key, goal.name
    end
  end
  function api.forget() api.shape = nil end
  function api.render(binds, moving)
    local shape = Keys.shape(binds, moving, 9)
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
      if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    UI.text(body, moving and "KEYS  ·  DRAG ME, THEN LOCK" or "KEYS", "eyebrow", moving and "accent" or "faint", { TextSize = 9, LayoutOrder = 0 })
    if #binds == 0 then UI.text(body, "Nothing is bound yet", "caption", "sub", { TextSize = 12, LayoutOrder = 1 }) end
    for index, bind in ipairs(binds) do
      if index > 9 then
        UI.text(body, "+" .. (#binds - 9) .. " more", "caption", "faint", { TextSize = 11, LayoutOrder = index })
        break
      end
      local line = UI.frame(body, { Name = "Bind_" .. bind.id, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = index })
      local wash = UI.frame(line, { Name = "Wash", Size = UDim2.new(1, 8, 1, 0), Position = UDim2.fromOffset(-4, 0), Theme = { BackgroundColor3 = "accent" }, BackgroundTransparency = 1 })
      UI.corner(wash, 6)
      local inner = UI.frame(line, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X })
      UI.list(inner, "x", 8, { v = "Center" })
      -- sized from its text: a chip that sizes itself left a single letter against its left edge
      local name = Config.keyLabel(bind.key)
      local chip = UI.frame(inner, { Name = "Chip", Size = UDim2.fromOffset(math.max(28, #name * 7 + 14), 18), LayoutOrder = 1, Theme = { BackgroundColor3 = "accent" },
        BackgroundTransparency = 0.8 })
      UI.corner(chip, 5)
      local pop = Instance.new("UIScale"); pop.Parent = chip
      local key = UI.text(chip, name, "monoBold", "ink", { TextSize = 10, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
      Theme.unbind(key, "TextColor3")
      local label = UI.text(inner, bind.label, "caption", "sub", { Name = "Feature", TextSize = 12, LayoutOrder = 2 })
      Theme.unbind(label, "TextColor3")
      local row = { chip = chip, wash = wash, key = key, name = label, pop = pop }
      api.rows[bind.id] = row
      local was = before[bind.id]
      light(row, was == nil and bind.on or was, false)
      if was ~= nil and was ~= bind.on then light(row, bind.on, true) end
    end
  end
  return api
end

-- ---------------------------------------------------------------- the list on screen
-- While the hub is hidden: each bound feature with its key, lit while it is on. It sits in the
-- bottom right corner until it is put somewhere else: unlocked (Keys tab), it shows with the hub
-- open too and goes where it is dragged; locked again, it stays there.
function Keys.hud()
  if Keys.panel or not Window.hud then return end
  local holder = UI.frame(Window.hud, { Name = "KeyList", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(0, 0),
    AutomaticSize = Enum.AutomaticSize.XY, Visible = false })
  local function unlocked() return Config.get("app.keyHudLock") == false end
  local function seat()
    local x, y = Config.get("app.keyHudX"), Config.get("app.keyHudY")
    if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
      holder.AnchorPoint = Vector2.new(0.5, 0.5)
      holder.Position = UDim2.fromScale(math.clamp(x, 0.02, 0.98), math.clamp(y, 0.02, 0.98))
    else
      holder.AnchorPoint = Vector2.new(1, 1)
      holder.Position = UDim2.new(1, -16, 1, -16)
    end
  end
  seat()
  local sizer = Instance.new("UIScale"); sizer.Scale = Window.scale or 1; sizer.Parent = holder
  -- three looks, each with its own list: the BASED glass card, the Unnamed box, Novoline's dark card.
  -- Never one with another look's window.
  local style, panel
  local function lookNow()
    if B.Novoline ~= nil and B.Novoline.keyPanel ~= nil and B.Novoline.active() then return "novoline" end
    if B.Unnamed ~= nil and B.Unnamed.keyPanel ~= nil and B.Unnamed.active() then return "unnamed" end
    return "based"
  end
  local function dress()
    if panel then panel.frame:Destroy(); panel = nil end
    style = lookNow()
    if style == "unnamed" then panel = B.Unnamed.keyPanel(holder)
    elseif style == "novoline" then panel = B.Novoline.keyPanel(holder)
    else panel = Keys.basedPanel(holder) end
  end
  dress()
  Keys.panel = holder
  -- the hand it is moved by: over all of it, and only there while it is unlocked
  local grip = UI.new("TextButton", { Name = "Move", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = holder })
  local from
  UI.drag(grip, function(point)
    local centre = holder.AbsolutePosition + holder.AbsoluteSize / 2
    from = centre - point
    return true
  end, function(point)
    local layer = Window.hud
    local size = layer.AbsoluteSize
    if size.X < 1 or size.Y < 1 then return end
    local at = point + from - layer.AbsolutePosition
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(math.clamp(at.X / size.X, 0.02, 0.98), math.clamp(at.Y / size.Y, 0.02, 0.98))
  end, function()
    -- (both read before either is kept: keeping one seats the list again, by the other's old value)
    local x, y = holder.Position.X.Scale, holder.Position.Y.Scale
    Config.set("app.keyHudX", x)
    Config.set("app.keyHudY", y)
  end)
  local function shouldShow()
    if Config.get("app.keyHud") == false then return false end
    if unlocked() then return true end
    return not Window.anyOpen() and next(Config.binds) ~= nil
  end
  function Keys.renderHud()
    if not holder.Parent then return end
    if lookNow() ~= style then dress() end
    sizer.Scale = (style == "unnamed" and B.Unnamed.scaleNow and B.Unnamed.scaleNow())
      or (style == "novoline" and B.Novoline.scaleNow and math.clamp(B.Novoline.scaleNow(), 0.7, 1.2)) or Window.scale or 1
    local binds = Keys.all()
    local moving = unlocked()
    grip.Visible = moving
    holder.Visible = shouldShow() and (#binds > 0 or moving)
    if holder.Visible then panel.render(binds, moving) end
  end
  Window.onShow:connect(function() Keys.renderHud() end)
  -- A bound button lights too: while what it started goes on (an emote playing), or for a moment
  -- after its key. Pressed: drawn at once; then looked at five times a second, drawn only on a change.
  local lit = ""
  local function litNow()
    local parts = {}
    for id, bind in pairs(Config.binds) do
      if bind.key and Config.isAction(id) and Config.isActive(id) then parts[#parts + 1] = id end
    end
    table.sort(parts)
    return table.concat(parts, ",")
  end
  Config.actionRan:connect(function() lit = litNow(); Keys.renderHud() end)
  Motion.every(function()
    if not holder.Visible then return end
    local now = litNow()
    if now ~= lit then lit = now; Keys.renderHud() end
  end, 5, "keys.lit")
  Config.on("app.keyHud", function() Keys.renderHud() end)
  Config.on("app.keyHudLock", function() Keys.renderHud() end)
  Config.on("app.gui", function() Keys.renderHud() end)
  Config.on("app.scale", function() Keys.renderHud() end)
  Theme.changed:connect(function() if panel and panel.forget then panel.forget() end; Keys.renderHud() end)
  Config.on("app.keyHudX", seat)
  Config.on("app.keyHudY", seat)
  Keys.renderHud()
end

-- ---------------------------------------------------------------- the tab
function Keys.define()
  Config.define("app.keyHud", true)
  Config.define("app.keyHudLock", true)
  Config.define("app.keyHudX", -1)          -- where it was put, as a share of the screen; under 0: the corner
  Config.define("app.keyHudY", -1)
end
B.pages[#B.pages + 1] = function()
  Keys.define()
  -- anything that changes what a key does, or whether a bound feature is on, redraws the board
  Config.bindsChanged:connect(function() Keys.repaint() end)
  Config.changed:connect(function(id)
    if Config.binds[id] or id == "app.key.menu" or id == "app.key.panic" then Keys.repaint() end
  end)
  Config.loaded:connect(function() Keys.repaint() end)
  Window.page({ id = "keys", title = "Keys", icon = "keyboard", group = "Hub", order = 890, eyebrow = "What every key does", build = function(page)
    local map = page:section({ title = "Your keyboard", icon = "keyboard", full = true, desc = "Every key the hub listens to, and what it does." })
    map:custom({ height = Keys.height + 46, name = "Keyboard", build = board })

    local bound = page:section({ title = "Bound features", icon = "link", column = 1, weight = 6 })
    bound:custom({ name = "List", build = list })

    local own = page:section({ title = "The hub's own keys", icon = "command", column = 2, weight = 6 })
    own:keybind({ tip = "The key that opens and closes the hub.", id = "app.key.menu", label = "Open / close the hub" })
    own:keybind({ id = "app.key.panic", label = "Panic", desc = "Unloads BASED instantly." })
    own:toggle({ id = "app.keyHud", label = "Show my keys on screen", desc = "A small list while the hub is hidden, lit for whatever is on.", bindable = false })
    own:toggle({ id = "app.keyHudLock", label = "Lock where it sits", desc = "Off: drag the list anywhere on screen. On: it stays.", bindable = false })
    own:button({ label = "Back to the corner", tip = "Moves the key list back to its corner.", text = "Reset", bindable = false, run = function()
      Config.set("app.keyHudX", -1)
      Config.set("app.keyHudY", -1)
    end })
    own:button({ label = "Clear every bound key", desc = "The hub's own keys are kept.", text = "Clear", style = "danger", bindable = false, run = function()
      local cleared = 0
      for id in pairs(table.clone(Config.binds)) do Config.bind(id, nil); cleared += 1 end
      Window.toast({ title = cleared == 0 and "Nothing was bound" or "Keys cleared", text = cleared > 0 and (cleared .. " features are off their keys.") or nil, icon = "keyboard" })
    end })
  end })
end
end
