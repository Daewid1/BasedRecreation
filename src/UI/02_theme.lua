do -- 02_theme.lua
-- ============================================================================
--  02 theme    tokens, live bindings
--
--  Surfaces are not solid colours: every fill is the scheme's ink at a low alpha
--  laid over glass, so one set of numbers works on a dark, a black and a light
--  scheme. B.T holds the resolved values; Theme.bind keeps an instance property
--  in step with a token, so accent, scheme and the glass slider all change the
--  whole hub live without rebuilding anything.
-- ============================================================================
local util = B.util
local hex = util.hex
local Theme = { changed = B.Signal.new() }
B.Theme = Theme
local T = {}
B.T = T

Theme.schemes = {
  dark = { label = "Graphite", base = hex("0B0B0F"), ink = hex("F5F4EF"), sub = hex("A9A8B4"), faint = hex("6C6B77"),
    shadow = 0.42, fill = { 0.045, 0.075, 0.115 }, stroke = { 0.085, 0.16 }, dark = true },
  midnight = { label = "Midnight", base = hex("000000"), ink = hex("F5F4EF"), sub = hex("9E9DA9"), faint = hex("62616C"),
    shadow = 0.3, fill = { 0.055, 0.09, 0.13 }, stroke = { 0.10, 0.18 }, dark = true },
  light = { label = "Porcelain", base = hex("F3F2EE"), ink = hex("121216"), sub = hex("56555F"), faint = hex("8C8B95"),
    shadow = 0.72, fill = { 0.05, 0.08, 0.12 }, stroke = { 0.10, 0.18 }, dark = false },
}
Theme.schemeOrder = { "dark", "midnight", "light" }
Theme.accents = {
  { id = "ultraviolet", label = "Ultraviolet", color = hex("8E7DFF") },
  { id = "azure", label = "Azure", color = hex("4DA3FF") },
  { id = "mint", label = "Mint", color = hex("45DDA8") },
  { id = "ember", label = "Ember", color = hex("FF7A45") },
  { id = "rose", label = "Rose", color = hex("FF5C93") },
  { id = "gold", label = "Gold", color = hex("F2C14E") },
  { id = "blood", label = "Blood", color = hex("FF4B4B") },
  { id = "bone", label = "Bone", color = hex("EDEBE4") },
}

Theme.state = { scheme = "dark", accent = hex("8E7DFF"), glass = 0.6, radius = 1, blur = false }

-- type ramp: font key (resolved in B.F by 03 assets) and size in design px
Theme.type = {
  display = { "serifItalic", 34 },
  title = { "serif", 25 },
  heading = { "text600", 15 },
  label = { "text500", 14 },
  body = { "text400", 13 },
  caption = { "text400", 12 },
  eyebrow = { "wideBold", 10 },
  mono = { "mono400", 12 },
  monoBold = { "mono500", 12 },
  button = { "text600", 13 },
  brand = { "wideBlack", 18 },
}

local function resolve()
  local state = Theme.state
  local scheme = Theme.schemes[state.scheme] or Theme.schemes.dark
  local glass = util.clamp01(state.glass)
  T.dark = scheme.dark
  T.base, T.ink, T.sub, T.faint = scheme.base, scheme.ink, scheme.sub, scheme.faint
  -- the iOS 27 control: clear glass at 0, tinted glass at 1. Without real blur
  -- behind it a clear panel is unreadable, so the range tightens.
  local alpha = state.blur and util.lerp(0.5, 0.94, glass) or util.lerp(0.84, 0.975, glass)
  T.baseA = 1 - alpha
  T.panelA = 1 - util.lerp(0.34, 0.62, glass)       -- inner panels: sidebar, popovers
  T.fill1A, T.fill2A, T.fill3A = 1 - scheme.fill[1], 1 - scheme.fill[2], 1 - scheme.fill[3]
  T.strokeA, T.stroke2A = 1 - scheme.stroke[1], 1 - scheme.stroke[2]
  T.shadowA = scheme.shadow
  T.accent = state.accent
  T.accentInk = util.luma(state.accent) > 0.62 and hex("101014") or hex("FFFFFF")
  T.accentSoftA = 0.84
  T.accentDim = state.accent:Lerp(scheme.base, 0.55)
  T.ok, T.warn, T.bad = hex("52D6A0"), hex("F4B45F"), hex("FF6577")
  T.white, T.black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
  T.rim = scheme.dark and Color3.new(1, 1, 1) or Color3.new(1, 1, 1)
  T.rimA = scheme.dark and 0.5 or 0.1
  T.popover = scheme.base:Lerp(scheme.ink, scheme.dark and 0.07 or 0.0)
  local r = state.radius
  T.rWindow, T.rPanel, T.rCard, T.rControl, T.rSmall = math.floor(26 * r), math.floor(19 * r), math.floor(16 * r), math.floor(11 * r), math.floor(7 * r)
end
resolve()

-- Strong references on purpose. A weak-keyed table of Instances loses entries whenever Lua holds
-- no other reference to that instance's wrapper, even though the instance is alive in the game:
-- measured as labels that kept their dark-scheme colour after switching to the light scheme.
-- Destroyed instances are swept out instead (their Parent is nil for good).
local bindings = {}
local boundAt = {}
-- Keep instance[property] equal to token `key` (optionally through `map`).
function Theme.bind(instance, property, key, map)
  local list = bindings[instance]
  if not list then list = {}; bindings[instance] = list; boundAt[instance] = os.clock() end
  list[property] = { key, map }
  local value = T[key]
  if map then value = map(value, T) end
  instance[property] = value
  return instance
end
function Theme.unbind(instance, property)
  local list = bindings[instance]
  if list then list[property] = nil end
end
-- forget instances that were destroyed (not ones still being assembled)
function Theme.sweep()
  local now = os.clock()
  for instance in pairs(bindings) do
    if instance.Parent == nil and now - boundAt[instance] > 5 then
      bindings[instance], boundAt[instance] = nil, nil
    end
  end
end
function Theme.apply()
  resolve()
  Theme.sweep()
  for instance, list in pairs(bindings) do
    for property, binding in pairs(list) do
      local value = T[binding[1]]
      if binding[2] then value = binding[2](value, T) end
      pcall(function() instance[property] = value end)
    end
  end
  Theme.changed:fire()
end
B.Motion.every(Theme.sweep, 1 / 20, "theme.sweep")
function Theme.set(changes)
  local state = Theme.state
  for key, value in pairs(changes) do state[key] = value end
  Theme.apply()
end
function Theme.corner(key) return UDim.new(0, T[key] or 10) end
end
