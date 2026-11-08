do -- 07_window.lua
-- ============================================================================
--  07 window   the shell: glass, sidebar, pages, cards, toasts, palette, blur
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Controls = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Controls
local UIS = S.UserInputService
local Window = { open = false, built = false, pages = {}, order = {}, index = {}, scale = 1, onShow = B.Signal.new(), onPage = B.Signal.new() }
B.Window = Window

local W, H = 980, 624
local SIDE = 206
local CONTENT_X = SIDE + 20
local CONTENT_W = W - CONTENT_X - 10
local HEADER = 84

-- ---------------------------------------------------------------- real blur
-- Measured: a Glass part a hair in front of the camera plus a DepthOfField with
-- nothing in its focus range blurs the 3D scene inside the part's rectangle only.
-- A rounded window is five rectangles: the body and two steps per end.
local Blur = { enabled = false, parts = {}, visible = false }
B.Blur = Blur
local DEPTH = 0.012
local function blurPart()
  local part = Instance.new("Part")
  part.Name = util.randomName()
  part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
  part.CastShadow = false
  part.Locked = true
  part.Material = Enum.Material.Glass
  part.Color = Color3.new(0, 0, 0)
  part.Transparency = 0.98
  part.Size = Vector3.new(1, 1, 0.001)
  local mesh = Instance.new("SpecialMesh")
  mesh.MeshType = Enum.MeshType.Brick
  mesh.Offset = Vector3.new(0, 0, -0.000001)
  mesh.Parent = part
  return part, mesh
end
function Blur.supported()
  local ok, level = pcall(function() return settings().Rendering.QualityLevel.Value end)
  -- level 0 is Automatic; the effect needs the post-processing tiers
  return ok and (level == 0 or level >= 8)
end
function Blur.start()
  if Blur.dof then return end
  local dof = Instance.new("DepthOfFieldEffect")
  dof.Name = util.randomName()
  dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius, dof.FocusDistance = 0, 1, 0.1, 0.05
  dof.Enabled = false
  dof.Parent = S.Lighting
  Blur.dof = B.own(dof)
  for index = 1, 5 do
    local part, mesh = blurPart()
    Blur.parts[index] = { part = B.own(part), mesh = mesh }
  end
  -- runs after the camera has moved this frame, so the glass never trails it
  S.RunService:BindToRenderStep("HussBasedBlur", Enum.RenderPriority.Camera.Value + 2, function()
    if not Blur.visible or not B.alive then return end
    B.try("blur", Blur.update)
  end)
  B.own(function() pcall(function() S.RunService:UnbindFromRenderStep("HussBasedBlur") end) end)
end
local function placePart(camera, slot, x, y, w, h)
  if w < 1 or h < 1 then slot.part.Parent = nil; return end
  local a = camera:ViewportPointToRay(x, y)
  local b = camera:ViewportPointToRay(x + w, y + h)
  local c = camera:ViewportPointToRay(x + w, y)
  local p1, p2, p3 = a.Origin + a.Direction * DEPTH, b.Origin + b.Direction * DEPTH, c.Origin + c.Direction * DEPTH
  local cf = camera.CFrame
  -- A game that clears the camera's children takes the glass with them (Da Hood's own client calls
  -- ClearAllChildren on the camera), and a destroyed part cannot be parented again: make it anew.
  if slot.part.Parent ~= camera and not pcall(function() slot.part.Parent = camera end) then
    local part, mesh = blurPart()
    slot.part, slot.mesh = B.own(part), mesh
    part.Parent = camera
  end
  slot.part.CFrame = CFrame.fromMatrix((p1 + p2) / 2, cf.XVector, cf.YVector, cf.ZVector)
  slot.mesh.Scale = Vector3.new((p3 - p1).Magnitude, (p3 - p2).Magnitude, 0) / slot.part.Size
end
function Blur.update()
  local camera = workspace.CurrentCamera
  local holder = Window.holder
  if not camera or not holder then return end
  -- read the rectangle this frame: a dragged window must not outrun its blur
  local p, s = holder.AbsolutePosition, holder.AbsoluteSize
  local inset = S.GuiService:GetGuiInset()
  local x, y, w, h, r = p.X + inset.X, p.Y + inset.Y, s.X, s.Y, T.rWindow * Window.sizer.Scale
  local parts = Blur.parts
  placePart(camera, parts[1], x, y + r, w, h - 2 * r)
  placePart(camera, parts[2], x + 0.063 * r, y + 0.30 * r, w - 0.126 * r, 0.70 * r)
  placePart(camera, parts[3], x + 0.42 * r, y + 0.07 * r, w - 0.84 * r, 0.23 * r)
  placePart(camera, parts[4], x + 0.063 * r, y + h - r, w - 0.126 * r, 0.70 * r)
  placePart(camera, parts[5], x + 0.42 * r, y + h - 0.30 * r, w - 0.84 * r, 0.23 * r)
end
function Blur.show(on)
  Blur.visible = on and Blur.enabled
  if Blur.dof then Blur.dof.Enabled = Blur.visible end
  if not Blur.visible then
    for _, slot in ipairs(Blur.parts) do slot.part.Parent = nil end
  end
end
function Blur.set(on)
  on = on and Blur.supported()
  Blur.enabled = on
  if on then Blur.start() end
  Theme.set({ blur = on })
  Blur.show(Window.open)
end

-- ---------------------------------------------------------------- toasts
local toasts = {}
local function layoutToasts()
  local y = 0
  for _, toast in ipairs(toasts) do
    Motion.to(toast.holder, "Position", UDim2.new(1, -18, 0, 18 + y), "smooth")
    y += toast.height + 10
  end
end
-- opts: title, text, icon, tone ("accent" | "ok" | "warn" | "bad"), time
function Window.toast(opts)
  if Window.toastHook then
    local taken = Window.toastHook(opts)
    if taken then return taken end
  end
  if not Window.hud then return end
  local tone = opts.tone or "accent"
  local hasText = opts.text ~= nil and opts.text ~= ""
  local toast = { height = hasText and 62 or 46 }
  local holder = UI.frame(Window.hud, { Name = "Toast", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(318, toast.height),
    Position = UDim2.new(1, 360, 0, 18) })
  local sizer = Instance.new("UIScale"); sizer.Scale = Window.scale; sizer.Parent = holder
  local glass = UI.glass(holder, { level = "popover", radius = "rCard", shadow = 30, shadowY = 12, props = { Size = UDim2.fromScale(1, 1) } })
  local chip = UI.frame(glass, { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    Theme = { BackgroundColor3 = tone }, BackgroundTransparency = 0.84 })
  UI.corner(chip, 9)
  UI.icon(chip, opts.icon or "sparkles", 16, tone, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
  UI.text(glass, opts.title or "", "heading", "ink", { TextSize = 13.5, Position = UDim2.fromOffset(50, hasText and 12 or 14), Size = UDim2.new(1, -64, 0, 18),
    AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
  if hasText then
    UI.text(glass, opts.text, "caption", "sub", { Position = UDim2.fromOffset(50, 31), Size = UDim2.new(1, -64, 0, 18), AutomaticSize = Enum.AutomaticSize.None,
      TextTruncate = Enum.TextTruncate.AtEnd })
  end
  local timer = UI.frame(glass, { Size = UDim2.new(1, -28, 0, 2), Position = UDim2.new(0, 14, 1, -5), Theme = { BackgroundColor3 = tone }, BackgroundTransparency = 0.45 })
  UI.corner(timer, true)
  toast.holder = holder
  table.insert(toasts, 1, toast)
  while #toasts > 4 do
    local old = table.remove(toasts)
    old.holder:Destroy()
  end
  layoutToasts()
  local life = opts.time or 3.6
  Motion.tween(life, Motion.ease.linear, function(p) timer.Size = UDim2.new(1 - p, -28 * (1 - p), 0, 2) end)
  local function dismiss()
    if toast.gone then return end
    toast.gone = true
    local at = table.find(toasts, toast)
    if at then table.remove(toasts, at) end
    Motion.to(holder, "Position", UDim2.new(1, 380, 0, holder.Position.Y.Offset), "smooth", function() holder:Destroy() end)
    layoutToasts()
  end
  task.delay(life, function() if B.alive then dismiss() end end)
  UI.button(glass, { click = dismiss })
  UI.sfx(tone == "bad" and "close" or "saved", 0.6)
  return dismiss
end

-- ---------------------------------------------------------------- sections
local SectionApi = {}
SectionApi.__index = SectionApi
for _, kind in ipairs({ "toggle", "slider", "dropdown", "multi", "segmented", "color", "keybind", "button", "input", "note", "custom" }) do
  SectionApi[kind] = function(self, spec) return Controls[kind](self.raw, spec) end
end
function Window.sectionApi(raw) return setmetatable({ raw = raw, body = raw.body }, SectionApi) end

local Page = {}
Page.__index = Page
local function band(page, full)
  page.bandCount += 1
  local frame = UI.frame(page.content, { Name = full and "Full" or "Columns", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = page.bandCount })
  if full then
    UI.list(frame, "y", 12)
    return { full = true, frame = frame }
  end
  local columns = {}
  for i = 1, 2 do
    local column = UI.frame(frame, { Name = "Column" .. i, Size = UDim2.new(0.5, -6, 0, 0), Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 6, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y })
    UI.list(column, "y", 12)
    columns[i] = { frame = column, count = 0 }
  end
  return { full = false, frame = frame, columns = columns }
end
-- spec: title, desc, icon, full (span both columns), column (1 | 2)
function Page:section(spec)
  spec = spec or {}
  -- built in the background, a tab is assembled one card per frame (see Window.prebuild)
  if self.slicing then task.wait() end
  local current = self.band
  if spec.full then
    current = band(self, true)
    self.band = nil
  elseif not current or current.full then
    current = band(self, false)
    self.band = current
  end
  local host
  if current.full then host = current.frame else
    local column = spec.column and current.columns[spec.column]
      or (current.columns[1].count <= current.columns[2].count and current.columns[1] or current.columns[2])
    column.count += spec.weight or 1
    host = column.frame
  end
  self.sectionCount += 1
  local card = UI.surface(host, { Name = spec.title or "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self.sectionCount })
  UI.stroke(card, "ink", "strokeA")
  local stack = UI.frame(card, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.list(stack, "y", 0)
  UI.pad(stack, 0, 0, 4, 0)
  if spec.title then
    local head = UI.frame(stack, { Name = "Head", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0 })
    UI.pad(head, 14, 14, 8, 14)
    UI.list(head, "y", 3)
    local line = UI.frame(head, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 })
    UI.list(line, "x", 8, { v = "Center" })
    if spec.icon then UI.icon(line, spec.icon, 16, "accent", { LayoutOrder = 1 }) end
    UI.text(line, spec.title, "heading", "ink", { LayoutOrder = 2 })
    if spec.badge then UI.badge(line, spec.badge, spec.badgeColor, { LayoutOrder = 3 }) end
    if spec.desc then
      UI.text(head, spec.desc, "caption", "sub", { TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, LineHeight = 1.15 })
    end
  end
  local body = UI.frame(stack, { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
  UI.list(body, "y", 0)
  local page = self
  local raw = { body = body, count = spec.title and 1 or 0, page = self, card = card }
  function raw.index(entry)
    entry.page, entry.section = page, spec.title or page.title
    Window.index[#Window.index + 1] = entry
  end
  local api = Window.sectionApi(raw)
  api.card = card
  return api
end
-- a full-width block the caller draws itself
function Page:custom(height, build)
  if self.slicing then task.wait() end
  local current = band(self, true)
  self.band = nil
  local frame = UI.frame(current.frame, { Name = "Custom", Size = UDim2.new(1, 0, 0, height or 0) })
  if not height then frame.AutomaticSize = Enum.AutomaticSize.Y end
  B.try("page.custom", build, frame)
  return frame
end
function Page:empty(icon, title, text)
  return self:custom(380, function(frame)
    local box = UI.frame(frame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(420, 0),
      AutomaticSize = Enum.AutomaticSize.Y })
    UI.list(box, "y", 10, { h = "Center" })
    local orb = UI.frame(box, { Size = UDim2.fromOffset(64, 64), Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" }, LayoutOrder = 1 })
    UI.corner(orb, true)
    UI.stroke(orb, "ink", "strokeA")
    UI.icon(orb, icon or "package", 26, "sub", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    UI.text(box, title or "Nothing here yet", "title", "ink", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center })
    UI.text(box, text or "", "body", "sub", { LayoutOrder = 3, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y, LineHeight = 1.25 })
  end)
end

-- ---------------------------------------------------------------- pages
-- spec: id, title, icon, group, eyebrow, build(page), order
function Window.page(spec)
  local page = setmetatable({ id = spec.id, title = spec.title, icon = spec.icon or "circle", group = spec.group or "", eyebrow = spec.eyebrow,
    build = spec.build, built = false, bandCount = 0, sectionCount = 0, order = spec.order or (#Window.order + 1) * 10 }, Page)
  Window.pages[spec.id] = page
  Window.order[#Window.order + 1] = page
  table.sort(Window.order, function(a, b) return a.order < b.order end)
  if Window.built then Window.rebuildNav() end
  return page
end
function Window.removePage(id)
  local page = Window.pages[id]
  if not page then return end
  Window.pages[id] = nil
  table.remove(Window.order, table.find(Window.order, page))
  if page.frame then page.holder:Destroy() end
  for index = #Window.index, 1, -1 do
    if Window.index[index].page == page then table.remove(Window.index, index) end
  end
  if Window.built then Window.rebuildNav() end
end
-- background = true builds the tab a card at a time across frames. Measured: built in one go a
-- tab costs 5-25 ms, which is a visible hitch; sliced, no frame carries more than one card.
local function ensureBuilt(page, background)
  if page.built then return end
  page.built = true
  page.slicing = background == true
  local holder = UI.group(Window.pageHost, { Name = page.id, Size = UDim2.fromScale(1, 1), Visible = false })
  local scroller, api = UI.scroll(holder, { Size = UDim2.new(1, 0, 1, 0), Name = "Scroll" })
  local content = UI.frame(scroller, { Name = "Content", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.list(content, "y", 12)
  UI.pad(content, 2, 0, 18, 0)
  page.holder, page.frame, page.scroll, page.content = holder, scroller, api, content
  local started = os.clock()
  if page.build then B.try("page." .. page.id, page.build, page) end
  if page.sectionCount == 0 and page.bandCount == 0 then
    page:empty("package", "Nothing here yet", "This tab is ready for its controls.")
  end
  page.slicing = false
  page.ready = true
  page.buildMs = (os.clock() - started) * 1000
end
-- Build every tab that has not been opened yet, quietly, so the first visit never stutters and
-- search can find every control. Runs during the intro when there is one.
function Window.prebuild()
  if Window.prebuilding then return end
  Window.prebuilding = true
  for _, page in ipairs(table.clone(Window.order)) do
    if not B.alive then return end
    if Window.pages[page.id] == page and not page.built then
      B.try("page.prebuild", ensureBuilt, page, true)
      -- (under a film a tab built in one frame shows as a skipped picture: measured 2026-10-29,
      -- 57 of 887 skipped at boot against 17 with the hub idle, so they are spaced out more then)
      task.wait((B.Loader and B.Loader.active) and 0.3 or 0.05)
    end
  end
  Window.prebuilding = false
  -- (the key list on screen names each feature by its switch: they are all known now)
  if B.Keys and B.Keys.repaint then B.Keys.repaint() end
end
Window.ensureBuilt = ensureBuilt

function Window.go(id, instant)
  local page = Window.pages[id]
  if not page or not Window.built then return end
  local previous = Window.current
  if previous == page then return end
  ensureBuilt(page)
  Window.current = page
  UI.closePopovers()
  UI.hideTip()
  if previous and previous.holder then
    local old = previous.holder
    UI.fade(old, 0, "quick")
    Motion.to(old, "Position", UDim2.fromOffset(0, -8), "quick")
  end
  page.holder.Visible = true
  if instant then
    UI.setFade(page.holder, 1)
    page.holder.Position = UDim2.new()
  else
    UI.setFade(page.holder, 0)
    Motion.snap(page.holder, "Position", UDim2.fromOffset(0, 14))
    UI.fade(page.holder, 1, "smooth")
    Motion.to(page.holder, "Position", UDim2.new(), "smooth")
  end
  Window.setTitle(page, instant)
  Window.selectNav(page, instant)
  Window.onPage:fire(page)
  if not instant then UI.sfx("tab", 0.6) end
end

-- ---------------------------------------------------------------- build
local navItems = {}
function Window.build()
  if Window.built then return end
  Window.built = true
  local gui = B.screen(9000)
  local hudGui = B.screen(9100)
  Window.gui, Window.hudGui = gui, hudGui
  Window.hud = UI.frame(hudGui, { Name = "Hud", Size = UDim2.fromScale(1, 1) })
  UI.soundHost = UI.frame(hudGui, { Name = "Sound" })

  -- frees the cursor in first person while the hub is open
  Window.modal = UI.new("TextButton", { Name = "Modal", Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Modal = true, Visible = false, Parent = gui })

  local stage = UI.frame(gui, { Name = "Stage", Size = UDim2.fromScale(1, 1) })
  local holder = UI.frame(stage, { Name = "Window", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false })
  local sizer = Instance.new("UIScale")
  sizer.Parent = holder
  Window.holder, Window.sizer = holder, sizer
  UI.unit = function() return sizer.Scale end

  -- shadow lives outside the canvas: a canvas clips whatever leaves its bounds
  local shadowHost = UI.frame(holder, { Name = "Shadow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
  UI.corner(shadowHost, "rWindow")
  if UI.fx.shadow then
    local shadow = Instance.new("UIShadow")
    shadow.BlurRadius = UDim.new(0, 70)
    shadow.Offset = UDim2.fromOffset(0, 28)
    shadow.Color = Color3.new(0, 0, 0)
    shadow.Transparency = 1
    pcall(function() shadow.ShowBehindParent = false end)
    shadow.Parent = shadowHost
    Window.shadow = shadow
  end

  local root = UI.group(holder, { Name = "Root", Size = UDim2.fromScale(1, 1) })
  UI.corner(root, "rWindow")
  Window.root = root
  local glass, rim = UI.glass(root, { level = "window", radius = "rWindow", name = "Glass", props = { Size = UDim2.fromScale(1, 1), Active = true },
    rimHi = 0.42, rimLo = 0.7, sheenAlpha = 0.95 })
  Window.glass, Window.rim = glass, rim

  -- ---- sidebar
  local side = UI.glass(glass, { level = "panel", radius = "rPanel", name = "Sidebar", fill = "fill1A",
    props = { Size = UDim2.new(0, SIDE, 1, -20), Position = UDim2.fromOffset(10, 10) }, rimHi = 0.72, rimLo = 0.9 })
  Window.side = side
  local brand = UI.frame(side, { Name = "Brand", Size = UDim2.new(1, 0, 0, 58) })
  local mark = UI.frame(brand, { Size = UDim2.fromOffset(0, 26), Position = UDim2.fromOffset(18, 18), AutomaticSize = Enum.AutomaticSize.X })
  UI.list(mark, "x", 3, { v = "Bottom" })
  UI.text(mark, "BASED", "brand", "ink", { LayoutOrder = 1, TextSize = 17 })
  UI.text(mark, "hub", "display", "accent", { LayoutOrder = 2, TextSize = 21 })
  -- The tabs scroll, between the brand and the user chip (a game with tabs of its own, Music and the
  -- rest of the hub ran past the bottom: Keys sat under the chip and Settings could not be reached).
  local navHost, navScroll = UI.scroll(side, { Name = "Nav", Size = UDim2.new(1, -16, 1, -128), Position = UDim2.fromOffset(8, 60),
    AutomaticCanvasSize = Enum.AutomaticSize.None, ClipsDescendants = true })
  Window.navHost, Window.navScroll = navHost, navScroll
  Window.navPill = UI.frame(Window.navHost, { Name = "Pill", Size = UDim2.new(1, 0, 0, 34), Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" }, Visible = false })
  UI.corner(Window.navPill, "rControl")
  UI.stroke(Window.navPill, "ink", "strokeA")

  -- user chip
  local user = UI.frame(side, { Name = "User", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Theme = { BackgroundColor3 = "ink" }, BackgroundTransparency = 1 })
  UI.corner(user, "rControl")
  local avatar = UI.new("ImageLabel", { Name = "Avatar", Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, 9, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 0, Theme = { BackgroundColor3 = "ink" }, Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(B.LP.UserId) .. "&w=150&h=150", Parent = user })
  avatar.BackgroundTransparency = 0.9
  UI.corner(avatar, true)
  UI.text(user, B.LP.DisplayName, "label", "ink", { Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -78, 0, 17), AutomaticSize = Enum.AutomaticSize.None,
    TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 13 })
  Window.userLine = UI.text(user, "@" .. B.LP.Name, "caption", "faint", { Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -78, 0, 15),
    AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 11 })
  local more = UI.icon(user, "ellipsis", 16, "faint", { Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
  UI.button(user, {
    hover = function(on) Motion.to(user, "BackgroundTransparency", on and T.fill2A or 1, "quick") end,
    click = function()
      UI.menu(more, {
        { label = "Settings", icon = "settings", run = function() Window.go("settings") end },
        { label = "Search", icon = "search", hint = "Ctrl K", run = function() Window.palette() end },
        { label = "Unnamed menu", icon = "app-window", run = function() Config.set("app.gui", "unnamed") end },
        { label = "Novoline menu", icon = "layout-grid", run = function() Config.set("app.gui", "novoline") end },
        "divider",
        { label = "Hide hub", icon = "eye-off", hint = Config.keyLabel(Config.get("app.key.menu")), run = function() Window.show(false) end },
        { label = "Unload BASED", icon = "power", danger = true, run = function() B.unload() end },
      }, { side = "above", align = "left", width = 214 })
    end,
  })

  -- ---- header
  local header = UI.frame(glass, { Name = "Header", Size = UDim2.new(0, CONTENT_W, 0, HEADER), Position = UDim2.fromOffset(CONTENT_X, 6) })
  Window.header = header
  Window.eyebrow = UI.text(header, "", "eyebrow", "faint", { Position = UDim2.fromOffset(2, 13) })
  local titleClip = UI.frame(header, { Name = "TitleClip", Size = UDim2.new(1, -250, 0, 46), Position = UDim2.fromOffset(0, 27), ClipsDescendants = true })
  Window.titleClip = titleClip
  -- search pill
  local search = UI.frame(header, { Name = "Search", Size = UDim2.fromOffset(170, 32), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -78, 0, 22),
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill1A" } })
  UI.corner(search, true)
  UI.stroke(search, "ink", "strokeA")
  UI.icon(search, "search", 15, "faint", { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
  UI.text(search, "Search", "body", "faint", { Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
  local hint = UI.frame(search, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
    Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill2A" } })
  UI.corner(hint, 6); UI.pad(hint, 0, 6)
  UI.text(hint, "Ctrl K", "mono", "faint", { TextSize = 10.5, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X })
  UI.button(search, {
    hover = function(on) Motion.to(search, "BackgroundTransparency", on and T.fill2A or T.fill1A, "quick") end,
    click = function() Window.palette() end,
  })
  -- window buttons
  local function roundButton(icon, x, tone, run, tip)
    local button = UI.frame(header, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 23),
      Theme = { BackgroundColor3 = "ink", BackgroundTransparency = "fill1A" } })
    UI.corner(button, true)
    local glyph = UI.icon(button, icon, 15, "sub", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local scale = UI.scaleOf(button)
    local hit = UI.button(button, {
      hover = function(on)
        Motion.to(button, "BackgroundTransparency", on and (tone and 0.8 or T.fill3A) or T.fill1A, "quick")
        Theme.bind(button, "BackgroundColor3", on and tone or "ink")
        Theme.bind(glyph, "ImageColor3", on and (tone or "ink") or "sub")
      end,
      press = function(on) Motion.to(scale, "Scale", on and 0.9 or 1, on and "quick" or "bouncy") end,
      click = run,
    })
    UI.tooltip(hit, tip)
  end
  roundButton("x", -4, "bad", function() Window.show(false) end, "Hide (" .. Config.keyLabel(Config.get("app.key.menu")) .. ")")
  roundButton("minus", -40, nil, function() Window.show(false) end, "Minimise to the island")

  -- ---- pages
  Window.pageHost = UI.frame(glass, { Name = "Pages", Size = UDim2.new(0, CONTENT_W, 1, -(HEADER + 16)), Position = UDim2.fromOffset(CONTENT_X, HEADER + 6), ClipsDescendants = true })
  -- soft edge where content scrolls under the header
  local fade = UI.frame(glass, { Name = "EdgeTop", Size = UDim2.new(0, CONTENT_W, 0, 14), Position = UDim2.fromOffset(CONTENT_X, HEADER + 6), ZIndex = 7,
    Theme = { BackgroundColor3 = "base" }, BackgroundTransparency = 0, Interactable = false })
  UI.gradient(fade, { Rotation = 90, Transparency = UI.alphaSeq(0, 0.25, 1, 1) })
  Window.edgeTop = fade

  UI.mountOverlay(gui, function() return sizer.Scale end)

  -- ---- drag (header and sidebar brand), spring-followed
  local position = Motion.spring(2, "snappy", function(x) holder.Position = UDim2.fromOffset(x[1], x[2]) end, 0.2)
  Window.position = position
  local function clampTo(x, y)
    local view = B.viewport()
    local hw, hh = W * sizer.Scale / 2, H * sizer.Scale / 2
    return math.clamp(x, 140 - hw, view.X + hw - 140), math.clamp(y, hh * 0.25, view.Y + hh - 80)
  end
  Window.clampTo = clampTo
  local startX, startY
  local function dragFrom(handle)
    UI.drag(handle, function()
      UI.closePopovers()
      startX, startY = position.g[1], position.g[2]
    end, function(_, delta)
      local x, y = clampTo(startX + delta.X, startY + delta.Y)
      position:to({ x, y }, "quick")
    end, function()
      local view = B.viewport()
      Config.set("app.window.x", position.g[1] / view.X)
      Config.set("app.window.y", position.g[2] / view.Y)
    end)
  end
  local grip = UI.new("TextButton", { Name = "Grip", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.new(1, -260, 1, 0), ZIndex = 2, Parent = header })
  dragFrom(grip)
  local grip2 = UI.new("TextButton", { Name = "Grip", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = brand })
  dragFrom(grip2)

  -- the rim highlight leans toward the pointer: glass catching a light
  local rimAngle = Motion.spring(1, "gentle", function(x) rim.Rotation = x[1] end, 0.05)
  rimAngle:snap({ 52 })
  Motion.every(function()
    if not Window.open then return end
    local mouse = UI.mouse()
    local p, s = holder.AbsolutePosition, holder.AbsoluteSize
    local dx, dy = mouse.X - (p.X + s.X / 2), mouse.Y - (p.Y + s.Y / 2)
    -- the gradient's bright end sits at angle+180: point it at the cursor
    local angle = math.deg(math.atan2(dy, dx)) + 180
    local current = rimAngle.g[1]
    local diff = (angle - current + 180) % 360 - 180
    if math.abs(diff) > 1.5 then rimAngle:to({ current + diff }) end
  end, 30, "window.rim")

  Window.rebuildNav()
  Window.rescale()
  B.connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function() Window.rescale() end, "window.viewport")
end

function Window.rescale()
  if not Window.built then return end
  local view = B.viewport()
  local auto = math.clamp(math.min(view.Y / 1090, view.X / 1500), 0.55, 1.5)
  local user = (Config.get("app.scale") or 100) / 100
  local scale = math.min(auto * user, (view.X - 24) / W, (view.Y - 24) / H)
  Window.scale = scale
  Motion.to(Window.sizer, "Scale", scale * (Window.open and 1 or 0.95), "smooth")
  local fx, fy = Config.get("app.window.x") or 0.5, Config.get("app.window.y") or 0.5
  local x, y = Window.clampTo(fx * view.X, fy * view.Y)
  Window.position:snap({ x, y })
end

-- ---------------------------------------------------------------- nav
local selected = Motion.spring(2, "snappy", function(x)
  local pill = Window.navPill
  if not pill then return end
  local a, b = math.min(x[1], x[2]), math.max(x[1], x[2])
  pill.Position = UDim2.fromOffset(0, a)
  pill.Size = UDim2.new(1, 0, 0, math.max(8, b - a))
end, 0.15)
function Window.rebuildNav()
  local host = Window.navHost
  for _, item in ipairs(navItems) do item.frame:Destroy() end
  for _, child in ipairs(host:GetChildren()) do
    if child.Name == "Group" then child:Destroy() end
  end
  table.clear(navItems)
  local y = 0
  local lastGroup
  for _, page in ipairs(Window.order) do
    if not page.hidden then
      if page.group ~= lastGroup then
        lastGroup = page.group
        if page.group ~= "" then
          y += 10
          local label = UI.text(host, string.upper(page.group), "eyebrow", "faint", { Name = "Group", Position = UDim2.fromOffset(12, y), TextSize = 9 })
          label.Name = "Group"
          y += 22
        end
      end
      local item = UI.frame(host, { Name = "Item", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, y), Theme = { BackgroundColor3 = "ink" }, ZIndex = 2 })
      UI.corner(item, "rControl")
      local icon = UI.icon(item, page.icon, 17, "sub", { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
      local label = UI.text(item, page.title, "label", "sub", { Position = UDim2.new(0, 39, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13.5 })
      if page.badge then UI.badge(item, page.badge, "accent", { Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) }) end
      local entry = { frame = item, icon = icon, label = label, page = page, y = y }
      navItems[#navItems + 1] = entry
      UI.button(item, {
        hover = function(on)
          if Window.current == page then return end
          Motion.to(item, "BackgroundTransparency", on and 0.955 or 1, "quick")
        end,
        click = function() Window.go(page.id) end,
      })
      y += 36
    end
  end
  host.CanvasSize = UDim2.fromOffset(0, y + 6)
  if Window.current then Window.selectNav(Window.current, true) end
end
function Window.selectNav(page, instant)
  local target
  for _, entry in ipairs(navItems) do
    local on = entry.page == page
    Theme.bind(entry.icon, "ImageColor3", on and "accent" or "sub")
    Theme.bind(entry.label, "TextColor3", on and "ink" or "sub")
    Motion.to(entry.frame, "BackgroundTransparency", 1, "quick")
    if on then target = entry end
  end
  if not target then Window.navPill.Visible = false; return end
  local a, b = target.y, target.y + 34
  -- (scrolled so the chosen tab is in view)
  local host, scroll = Window.navHost, Window.navScroll
  if host and scroll then
    local view = host.AbsoluteWindowSize.Y / math.max(UI.unit(), 0.01)
    local at = host.CanvasPosition.Y / math.max(UI.unit(), 0.01)
    if a < at + 4 then scroll.to((a - 12) * UI.unit(), instant) elseif b > at + view - 4 then scroll.to((b - view + 12) * UI.unit(), instant) end
  end
  if instant or not Window.navPill.Visible then
    Window.navPill.Visible = true
    selected:snap({ a, b })
    return
  end
  -- liquid: the edge facing the destination moves first, the other one follows
  local down = a > selected.g[1]
  if down then selected:to({ selected.g[1], b }, "snappy") else selected:to({ a, selected.g[2] }, "snappy") end
  task.delay(0.05, function() if Window.current == page then selected:to({ a, b }, "liquid") end end)
end

-- title: the old one slides up out of a mask, the new one rises into it
function Window.setTitle(page, instant)
  local clip = Window.titleClip
  local old = Window.titleLabel
  local label = UI.text(clip, page.title, "display", "ink", { Position = UDim2.fromOffset(0, instant and 2 or 46), Name = "Title" })
  Window.titleLabel = label
  Window.eyebrow.Text = string.upper(page.eyebrow or (page.group ~= "" and page.group or "BASED"))
  if instant then
    if old then old:Destroy() end
    return
  end
  Motion.to(label, "Position", UDim2.fromOffset(0, 2), "smooth")
  if old then Motion.to(old, "Position", UDim2.fromOffset(0, -46), "smooth", function() old:Destroy() end) end
end

-- ---------------------------------------------------------------- show / hide
function Window.show(on, instant)
  if not Window.built or Window.open == on then return end
  Window.open = on
  UI.closePopovers()
  UI.hideTip()
  local holder, root, sizer = Window.holder, Window.root, Window.sizer
  Window.modal.Visible = on and Config.get("app.freeCursor") ~= false
  if on then
    holder.Visible = true
    if not Window.current and Window.order[1] then Window.go(Window.startPage or Window.order[1].id, true) end
    if instant then
      UI.setFade(root, 1); Motion.snap(sizer, "Scale", Window.scale)
      if Window.shadow then Window.shadow.Transparency = T.shadowA end
    else
      UI.setFade(root, 0)
      Motion.snap(sizer, "Scale", Window.scale * 0.94)
      UI.fade(root, 1, "smooth")
      Motion.to(sizer, "Scale", Window.scale, "bouncy")
      if Window.shadow then Motion.to(Window.shadow, "Transparency", T.shadowA, "gentle") end
      UI.sfx("open", 0.8)
    end
    Blur.show(true)
  else
    if Window.shadow then Motion.to(Window.shadow, "Transparency", 1, "quick") end
    Motion.to(sizer, "Scale", Window.scale * 0.96, "quick")
    Blur.show(false)
    UI.fade(root, 0, "quick", function() if not Window.open then holder.Visible = false end end)
    if not root:IsA("CanvasGroup") then holder.Visible = false end
    UI.sfx("close", 0.7)
  end
  Window.onShow:fire(on)
end
function Window.toggle() Window.show(not Window.open) end
-- any look of the hub is up: the BASED window, the Unnamed menu (src/52) or the Novoline one (src/53)
function Window.anyOpen()
  return Window.open or (B.Unnamed ~= nil and B.Unnamed.open == true) or (B.Novoline ~= nil and B.Novoline.open == true)
end
-- a tab on screen in any look. (Live parts of a tab asked the BASED window alone, and stood still
-- in the other looks.)
function Window.showing(id)
  if Window.open and Window.current ~= nil and Window.current.id == id then return true end
  local unnamed, novoline = B.Unnamed, B.Novoline
  if unnamed ~= nil and unnamed.open == true and unnamed.current == id then return true end
  return novoline ~= nil and novoline.open == true and novoline.current == id
end
-- which look is in use, and opening or closing it (the menu key)
function Window.look()
  local look = Config.get("app.gui")
  if look == "unnamed" and B.Unnamed then return "unnamed" end
  if look == "novoline" and B.Novoline then return "novoline" end
  return "based"
end
function Window.showActive(on)
  local look = Window.look()
  if look == "unnamed" then B.Unnamed.show(on) elseif look == "novoline" then B.Novoline.show(on) else Window.show(on) end
end
function Window.toggleActive()
  local look = Window.look()
  if look == "unnamed" then B.Unnamed.toggle() elseif look == "novoline" then B.Novoline.toggle() else Window.toggle() end
end

-- ---------------------------------------------------------------- the look kit
-- A tab that draws part of itself (the music player, a preview) takes its colours, letters and
-- corners from the look it is drawn in: Window.kit(frame). The BASED one is here; the Unnamed and
-- Novoline looks put theirs in Window.kits with an `owns(frame)` that says a frame is theirs.
--   kit.paint(instance, property, role)  set a colour and keep it in step (theme, accent)
--   kit.fill(instance, role)             a surface: colour and see-through together
--   kit.text(parent, value, props, bold, size), kit.entry(parent, size)  in the look's letters
--   kit.clear(instance)                  no surface (after a hover)
--   kit.outline(frame), kit.corner(frame, radius), kit.menu(anchor, items)
-- roles: card field hover line back text dim faint accent onAccent good bad
local ROLES = {
  card = { "ink", "fill1A" }, field = { "ink", "fill2A" }, hover = { "ink", "fill3A" }, line = { "ink", "strokeA" }, back = { "base", "baseA" },
  text = { "ink" }, dim = { "sub" }, faint = { "faint" }, accent = { "accent" }, onAccent = { "accentInk" }, good = { "ok" }, bad = { "bad" },
}
local kit = { look = "based", radius = 14, small = 9, size = 13 }
function kit.color(role)
  local r = ROLES[role] or ROLES.text
  return T[r[1]], r[2] and T[r[2]] or 0
end
function kit.paint(instance, property, role)
  Theme.bind(instance, property, (ROLES[role] or ROLES.text)[1])
end
function kit.fill(instance, role)
  local r = ROLES[role] or ROLES.card
  Theme.bind(instance, "BackgroundColor3", r[1])
  if r[2] then Theme.bind(instance, "BackgroundTransparency", r[2]) else
    Theme.unbind(instance, "BackgroundTransparency")
    instance.BackgroundTransparency = 0
  end
end
-- no surface at all (after a hover): the theme lets go of it too
function kit.clear(instance)
  Theme.unbind(instance, "BackgroundTransparency")
  instance.BackgroundTransparency = 1
end
function kit.font(bold) return bold and B.F.text600 or B.F.text500 end
function kit.text(parent, value, props, bold, size)
  local label = UI.text(parent, value, bold and "heading" or "label", "ink", { AutomaticSize = Enum.AutomaticSize.None, TextSize = size or 13 })
  if props then for key, v in pairs(props) do label[key] = v end end
  return label
end
function kit.entry(parent, size)
  local entry = Instance.new("TextBox")
  entry.BackgroundTransparency, entry.BorderSizePixel = 1, 0
  entry.FontFace = B.F.text500
  UI.fontKey[entry] = "text500"
  entry.TextSize = size or 13
  entry.TextXAlignment, entry.ClearTextOnFocus, entry.ClipsDescendants = Enum.TextXAlignment.Left, false, true
  Theme.bind(entry, "TextColor3", "ink")
  Theme.bind(entry, "PlaceholderColor3", "faint")
  entry.Parent = parent
  return entry
end
function kit.outline(frame) return UI.stroke(frame, "ink", "strokeA") end
function kit.corner(frame, radius) return UI.corner(frame, radius or kit.radius) end
function kit.menu(anchor, items) return UI.menu(anchor, items, { align = "right" }) end
Window.kits = { based = kit }
function Window.kit(frame)
  for name, other in pairs(Window.kits) do
    if name ~= "based" and other.owns and frame and other.owns(frame) then return other end
  end
  return kit
end
-- the kit of the look in use (for what sits on the HUD, outside any window)
function Window.activeKit() return Window.kits[Window.look()] or kit end

-- ---------------------------------------------------------------- command palette
local palette
function Window.palette()
  if palette then palette.close(); return end
  if not Window.built then return end
  if not Window.open then Window.show(true) end
  -- everything has to exist before it can be found
  for _, page in ipairs(Window.order) do ensureBuilt(page) end
  local scale = Window.scale
  local view = B.viewport()
  local veil = UI.new("TextButton", { Name = "Veil", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, ZIndex = 70, Parent = UI.overlay })
  Motion.to(veil, "BackgroundTransparency", 0.62, "smooth")
  -- over the hub, wherever the hub has been dragged to
  local at, size = Window.holder.AbsolutePosition - UI.overlay.AbsolutePosition, Window.holder.AbsoluteSize
  local half = 270 * scale
  local holder = UI.frame(veil, { Name = "Palette", Size = UDim2.fromOffset(540, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromOffset(math.clamp(at.X + size.X * 0.5, half + 12, math.max(half + 12, view.X - half - 12)), math.clamp(at.Y + 72 * scale, 16, math.max(16, view.Y - 420 * scale))),
    ZIndex = 71 })
  local sizer = Instance.new("UIScale"); sizer.Scale = scale * 0.95; sizer.Parent = holder
  Motion.to(sizer, "Scale", scale, "bouncy")
  local glass = UI.glass(holder, { level = "popover", radius = "rPanel", shadow = 60, shadowY = 26, props = { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Active = true } })
  local stack = UI.frame(glass, { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y })
  UI.list(stack, "y", 0)
  local top = UI.frame(stack, { Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 1 })
  UI.icon(top, "search", 18, "sub", { Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
  local box = UI.new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(48, 0), Text = "", PlaceholderText = "Search every setting and tab",
    FontFace = B.F.text500, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Theme = { TextColor3 = "ink", PlaceholderColor3 = "faint" }, Parent = top })
  UI.text(top, "esc", "mono", "faint", { Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 11 })
  UI.divider(stack, 2)
  local list = UI.frame(stack, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
  UI.pad(list, 6)
  UI.list(list, "y", 2)
  local rows, results, cursor = {}, {}, 1
  local connection
  local api = {}
  function api.close()
    if not palette then return end
    palette = nil
    if connection then connection:Disconnect() end
    Motion.to(veil, "BackgroundTransparency", 1, "quick", function() veil:Destroy() end)
    holder:Destroy()
  end
  local function highlight()
    for index, row in ipairs(rows) do
      Motion.to(row, "BackgroundTransparency", index == cursor and T.fill2A or 1, "quick")
    end
  end
  local function run(result)
    if not result then return end
    api.close()
    if result.kind == "page" then Window.go(result.page.id); return end
    Window.go(result.page.id)
    task.delay(0.12, function()
      local entry = result.entry
      if not entry.row.frame.Parent then return end
      local scroller = result.page.frame
      local offset = (entry.row.frame.AbsolutePosition.Y - scroller.AbsolutePosition.Y + scroller.CanvasPosition.Y) - 90 * Window.scale
      result.page.scroll.to(offset)
      entry.row.flash()
    end)
  end
  local function refresh()
    for _, row in ipairs(rows) do row:Destroy() end
    table.clear(rows); table.clear(results)
    local query = box.Text
    local scored = {}
    for _, page in ipairs(Window.order) do
      local score = util.fuzzy(query, page.title)
      if score then scored[#scored + 1] = { kind = "page", page = page, label = page.title, sub = "Tab", icon = page.icon, score = score + 1.5 } end
    end
    for _, entry in ipairs(Window.index) do
      local score = util.fuzzy(query, entry.label)
      if not score and query ~= "" and entry.desc ~= "" then
        local other = util.fuzzy(query, entry.desc)
        score = other and other - 4 or nil
      end
      if score then
        scored[#scored + 1] = { kind = "control", page = entry.page, entry = entry, label = entry.label, sub = entry.page.title .. "  ›  " .. tostring(entry.section),
          icon = entry.page.icon, score = score }
      end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    for index = 1, math.min(8, #scored) do
      local result = scored[index]
      results[index] = result
      local row = UI.frame(list, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = index, Theme = { BackgroundColor3 = "ink" } })
      UI.corner(row, "rSmall")
      UI.icon(row, result.icon, 16, result.kind == "page" and "accent" or "sub", { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
      UI.text(row, result.label, "label", "ink", { Position = UDim2.new(0, 40, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = 13.5 })
      UI.text(row, result.sub, "caption", "faint", { Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 11.5 })
      UI.button(row, { hover = function(on) if on then cursor = index; highlight() end end, click = function() run(result) end })
      rows[index] = row
    end
    if #scored == 0 then
      local row = UI.frame(list, { Size = UDim2.new(1, 0, 0, 56) })
      UI.text(row, "No setting matches “" .. query .. "”", "body", "faint", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
      rows[1] = row
    end
    cursor = 1
    highlight()
  end
  box:GetPropertyChangedSignal("Text"):Connect(B.safe("palette", refresh))
  connection = UIS.InputBegan:Connect(B.safe("palette.key", function(input)
    if input.KeyCode == Enum.KeyCode.Down then cursor = math.min(#results, cursor + 1); highlight()
    elseif input.KeyCode == Enum.KeyCode.Up then cursor = math.max(1, cursor - 1); highlight()
    elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then run(results[cursor])
    elseif input.KeyCode == Enum.KeyCode.Escape then api.close() end
  end))
  veil.Activated:Connect(function() api.close() end)
  palette = api
  refresh()
  box:CaptureFocus()
  UI.sfx("open", 0.6)
end
end
