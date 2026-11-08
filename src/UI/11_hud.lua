do -- 11_hud.lua
-- ============================================================================
--  11 hud      the island: what is left on screen when the hub is hidden
-- ============================================================================
local S, util, Motion, Theme, T, UI, Config, Window = B.S, B.util, B.Motion, B.Theme, B.T, B.UI, B.Config, B.Window
local Hud = {}
B.Hud = Hud

function Hud.ping()
  local ok, value = pcall(function() return B.LP:GetNetworkPing() * 1000 end)
  if ok and value and value > 0 then return value end
  local ok2, item = pcall(function() return S.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
  return ok2 and item or 0
end
function Hud.fps() return 1 / math.max(Motion.smoothDt, 1 / 1000) end

function Hud.start()
  if Hud.island then return end
  local holder = UI.frame(Window.hud, { Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(0, 34),
    AutomaticSize = Enum.AutomaticSize.X, Visible = false })
  local sizer = Instance.new("UIScale"); sizer.Scale = Window.scale; sizer.Parent = holder
  local glass = UI.glass(holder, { level = "popover", radius = 17, shadow = 22, shadowY = 8, grain = false,
    props = { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X } })
  local body = UI.pressable(glass, { Name = "Body", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X })
  UI.pad(body, 0, 14, 0, 14)
  UI.list(body, "x", 9, { v = "Center" })
  UI.text(body, "HUSS", "brand", "ink", { TextSize = 11, LayoutOrder = 1 })
  local dot = UI.frame(body, { Size = UDim2.fromOffset(4, 4), LayoutOrder = 2, Theme = { BackgroundColor3 = "accent" }, BackgroundTransparency = 0 })
  UI.corner(dot, true)
  local stats = UI.text(body, "", "mono", "sub", { TextSize = 11, LayoutOrder = 3 })
  local key = UI.text(body, "", "mono", "faint", { TextSize = 11, LayoutOrder = 4 })
  Hud.island = holder
  local shown = false
  local function show(on)
    on = on and Config.get("app.island") ~= false and not (B.Unnamed and (B.Unnamed.active() or B.Unnamed.open))
      and not (B.Novoline and (B.Novoline.active() or B.Novoline.open))
    if on == shown then return end
    shown = on
    if on then
      holder.Visible = true
      holder.Position = UDim2.new(0.5, 0, 0, -44)
      Motion.to(holder, "Position", UDim2.new(0.5, 0, 0, 12), "bouncy")
    else
      Motion.to(holder, "Position", UDim2.new(0.5, 0, 0, -48), "quick", function() if not shown then holder.Visible = false end end)
    end
  end
  UI.wire(body, {
    hover = function(on) Motion.to(sizer, "Scale", Window.scale * (on and 1.05 or 1), "snappy") end,
    click = function() Window.show(true) end,
  })
  Window.onShow:connect(function(open) show(not open) end)
  Config.on("app.island", function() show(not Window.open) end)
  Config.on("app.gui", function() show(not Window.open) end)
  local tick = 0
  Motion.every(function()
    if not shown then return end
    tick += 1
    if tick % 4 == 0 or stats.Text == "" then
      stats.Text = string.format("%d fps  ·  %d ms", math.floor(Hud.fps() + 0.5), math.floor(Hud.ping() + 0.5))
    end
    key.Text = Config.keyLabel(Config.get("app.key.menu"))
  end, 8, "hud.island")
  show(not Window.open)
end
end
