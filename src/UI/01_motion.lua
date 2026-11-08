do -- 01_motion.lua
-- ============================================================================
--  01 motion   one render loop: analytic springs, timelines, jobs
--
--  Springs are described the way SwiftUI does it: a duration (how long the move
--  feels) and a bounce (0 = critically damped, 0.3 = lively). They are solved in
--  closed form, so a 20 fps hitch and a 240 fps frame land on the same curve and
--  nothing ever explodes. A spring at rest is removed from the loop: an idle hub
--  costs one empty table scan per frame.
-- ============================================================================
local S, util = B.S, B.util
local Motion = { speed = 1, reduced = false, frame = 0, dt = 1 / 60, smoothDt = 1 / 60, now = os.clock() }
B.Motion = Motion

Motion.presets = {
  quick  = { 0.16, 0 },     -- hover tints, tiny state changes
  snappy = { 0.24, 0.10 },  -- presses, toggles
  smooth = { 0.34, 0 },     -- panels, pages
  gentle = { 0.52, 0 },     -- large surfaces
  bouncy = { 0.40, 0.24 },  -- things that should feel alive
  liquid = { 0.46, 0.30 },  -- the trailing edge of a moving pill
  lazy   = { 0.90, 0 },     -- ambient drift
}

local awake = {}       -- springs that are moving
local stepping = {}    -- the ones being stepped this frame, in a list of their own (see the loop)
local jobs = {}        -- per-frame callbacks
local tweens = {}      -- fixed-duration timelines

-- ---------------------------------------------------------------- springs
local Spring = {}
Spring.__index = Spring

local function tune(spring, preset)
  local p = type(preset) == "table" and preset or Motion.presets[preset or "smooth"] or Motion.presets.smooth
  local duration, bounce = p[1], p[2] or 0
  if Motion.reduced then duration, bounce = duration * 0.55, 0 end
  duration = math.max(duration / Motion.speed, 0.02)
  spring.w0 = 2 * math.pi / duration
  spring.zeta = math.clamp(1 - bounce, 0.08, 1)
end

function Motion.spring(n, preset, onStep, eps)
  local spring = setmetatable({ n = n, x = table.create(n, 0), v = table.create(n, 0), g = table.create(n, 0),
    onStep = onStep, eps = eps or 0.001 }, Spring)
  tune(spring, preset)
  return spring
end
function Spring:snap(values)
  for i = 1, self.n do self.x[i], self.g[i], self.v[i] = values[i], values[i], 0 end
  awake[self] = nil
  if self.onStep then self.onStep(self.x) end
end
function Spring:to(values, preset)
  if preset then tune(self, preset) end
  local g = self.g
  for i = 1, self.n do g[i] = values[i] end
  awake[self] = true
end
function Spring:impulse(index, velocity)
  self.v[index] += velocity
  awake[self] = true
end
function Spring:moving() return awake[self] == true end
function Spring:stop() awake[self] = nil end

local function stepSpring(spring, dt)
  local w0, zeta, eps = spring.w0, spring.zeta, spring.eps
  local x, v, g = spring.x, spring.v, spring.g
  local rest = true
  if zeta < 0.999 then
    local wd = w0 * math.sqrt(1 - zeta * zeta)
    local decay = math.exp(-zeta * w0 * dt)
    local c, s = math.cos(wd * dt), math.sin(wd * dt)
    for i = 1, spring.n do
      local a = x[i] - g[i]
      local b = (v[i] + zeta * w0 * a) / wd
      local y = decay * (a * c + b * s)
      local nv = decay * ((b * wd - a * zeta * w0) * c - (a * wd + b * zeta * w0) * s)
      x[i], v[i] = g[i] + y, nv
      local tolerance = type(eps) == "table" and eps[i] or eps
      if rest and (math.abs(y) > tolerance or math.abs(nv) > tolerance * 20) then rest = false end
    end
  else
    local decay = math.exp(-w0 * dt)
    for i = 1, spring.n do
      local a = x[i] - g[i]
      local k = v[i] + w0 * a
      local y = decay * (a + k * dt)
      local nv = decay * (v[i] - k * w0 * dt)
      x[i], v[i] = g[i] + y, nv
      local tolerance = type(eps) == "table" and eps[i] or eps
      if rest and (math.abs(y) > tolerance or math.abs(nv) > tolerance * 20) then rest = false end
    end
  end
  if rest then
    for i = 1, spring.n do x[i], v[i] = g[i], 0 end
    awake[spring] = nil
  end
  if spring.onStep then spring.onStep(x) end
  if rest and spring.onRest then
    local done = spring.onRest
    spring.onRest = nil
    done()
  end
end

-- ---------------------------------------------------------------- properties
local PX, UNIT = 0.08, 0.0008
local packers = {
  number = { 1, function(value) return { value } end, function(x) return x[1] end, UNIT },
  UDim2 = { 4, function(value) return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } end,
    function(x) return UDim2.new(x[1], x[2], x[3], x[4]) end, { UNIT, PX, UNIT, PX } },
  UDim = { 2, function(value) return { value.Scale, value.Offset } end, function(x) return UDim.new(x[1], x[2]) end, { UNIT, PX } },
  Vector2 = { 2, function(value) return { value.X, value.Y } end, function(x) return Vector2.new(x[1], x[2]) end, UNIT },
  Vector3 = { 3, function(value) return { value.X, value.Y, value.Z } end, function(x) return Vector3.new(x[1], x[2], x[3]) end, UNIT },
  Color3 = { 3, function(value) return { value.R, value.G, value.B } end,
    function(x) return Color3.new(util.clamp01(x[1]), util.clamp01(x[2]), util.clamp01(x[3])) end, 0.002 },
}
-- Properties that must stay inside 0..1: a bouncy spring overshoots, the engine rejects it.
local unitProps = { BackgroundTransparency = true, TextTransparency = true, ImageTransparency = true, Transparency = true,
  GroupTransparency = true, TextStrokeTransparency = true, ScrollBarImageTransparency = true, FillTransparency = true,
  OutlineTransparency = true }

local bound = setmetatable({}, { __mode = "k" })
-- Spring `instance[property]` toward `target`. The spring is kept per
-- (instance, property) and re-aimed in flight, so interrupted motion never jumps.
function Motion.to(instance, property, target, preset, done)
  local packer = packers[typeof(target)]
  if not packer then instance[property] = target; if done then done() end; return nil end
  local map = bound[instance]
  if not map then map = {}; bound[instance] = map end
  local spring = map[property]
  if not spring then
    local unpack, clampUnit = packer[3], unitProps[property]
    spring = Motion.spring(packer[1], preset, function(x)
      local value = unpack(x)
      if clampUnit then value = util.clamp01(value) end
      instance[property] = value
    end, packer[4])
    local current = packer[2](instance[property])
    for i = 1, spring.n do spring.x[i], spring.g[i] = current[i], current[i] end
    map[property] = spring
  end
  spring.onRest = done
  spring:to(packer[2](target), preset)
  return spring
end
function Motion.snap(instance, property, value)
  local map = bound[instance]
  local spring = map and map[property]
  local packer = packers[typeof(value)]
  if spring and packer then
    spring.onRest = nil
    spring:snap(packer[2](value))
  else
    instance[property] = value
  end
end
function Motion.kick(instance, property, index, velocity)
  local map = bound[instance]
  local spring = map and map[property]
  if spring then spring:impulse(index or 1, velocity) end
end
function Motion.target(instance, property)
  local map = bound[instance]
  local spring = map and map[property]
  if not spring then return instance[property] end
  local packer = packers[typeof(instance[property])]
  return packer and packer[3](spring.g) or instance[property]
end

-- ---------------------------------------------------------------- easing + timelines
local ease = {}
function ease.linear(t) return t end
function ease.outCubic(t) return 1 - (1 - t) ^ 3 end
function ease.inCubic(t) return t * t * t end
function ease.inOutCubic(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
function ease.outQuint(t) return 1 - (1 - t) ^ 5 end
function ease.inOutQuint(t) return t < 0.5 and 16 * t ^ 5 or 1 - (-2 * t + 2) ^ 5 / 2 end
function ease.outExpo(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end
function ease.inExpo(t) return t <= 0 and 0 or 2 ^ (10 * t - 10) end
function ease.outBack(t) local c = 1.70158; return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2 end
function ease.outSine(t) return math.sin(t * math.pi / 2) end
Motion.ease = ease
-- progress of `t` through the window [from, from + length], eased and clamped
function Motion.window(t, from, length, curve)
  local p = util.clamp01((t - from) / length)
  return curve and curve(p) or p
end

function Motion.tween(duration, curve, step, done)
  local tween = { t = 0, duration = math.max(duration / Motion.speed, 0.001), curve = curve or ease.outCubic, step = step, done = done }
  if Motion.reduced then tween.duration *= 0.5 end
  tweens[#tweens + 1] = tween
  function tween.cancel() tween.dead = true end
  step(tween.curve(0))
  return tween
end

-- ---------------------------------------------------------------- jobs
-- fn(elapsed) every frame, or at `hz` with the time since it last ran.
function Motion.every(fn, hz, scope)
  local job = { fn = fn, interval = hz and 1 / hz or 0, acc = 0, scope = scope or "job" }
  jobs[#jobs + 1] = job
  function job.cancel() job.dead = true end
  return job
end
function Motion.after(seconds, fn, scope)
  local job
  local left = seconds
  job = Motion.every(function(dt)
    left -= dt
    if left <= 0 then job.dead = true; fn() end
  end, nil, scope or "after")
  return job
end

-- ---------------------------------------------------------------- the loop
Motion.stats = { springs = 0, jobs = 0, ms = 0 }
local function frame(dt)
  if not B.alive then return end
  local started = os.clock()
  dt = math.min(dt, 0.1)
  Motion.frame += 1
  Motion.dt = dt
  Motion.smoothDt += (dt - Motion.smoothDt) * 0.08
  Motion.now = started

  -- A spring's step runs code that may start other springs, and a table cannot be given new keys
  -- while it is being walked ("invalid key to 'next'", one frame in thousands): so this frame's
  -- springs are listed first. One started during the frame is stepped from the next; one put to
  -- rest by another before its turn is left alone.
  local measuring = B.prof ~= nil
  local springCount = 0
  for spring in pairs(awake) do
    springCount += 1
    stepping[springCount] = spring
  end
  for index = 1, springCount do
    local spring = stepping[index]
    stepping[index] = nil
    if awake[spring] then
      local ok, err = pcall(stepSpring, spring, dt)
      if not ok then awake[spring] = nil; B.fault("spring", err) end
    end
  end

  local mark = measuring and os.clock()
  if measuring then B.charge("motion.springs", mark - started) end
  local count = #tweens
  if count > 0 then
    for index = count, 1, -1 do
      local tween = tweens[index]
      if tween.dead then
        table.remove(tweens, index)
      else
        tween.t += dt
        local p = util.clamp01(tween.t / tween.duration)
        local ok, err = pcall(tween.step, tween.curve(p))
        if not ok then tween.dead = true; B.fault("tween", err) end
        if p >= 1 and not tween.dead then
          tween.dead = true
          table.remove(tweens, index)
          if tween.done then B.try("tween.done", tween.done) end
        end
      end
    end
  end

  if measuring then B.charge("motion.tweens", os.clock() - mark) end
  count = #jobs
  if count > 0 then
    for index = 1, count do
      local job = jobs[index]
      if job and not job.dead then
        local elapsed = dt
        local run = true
        if job.interval > 0 then
          job.acc += dt
          if job.acc < job.interval then run = false else elapsed = math.min(job.acc, 0.5); job.acc = 0 end
        end
        if run then
          local before = measuring and os.clock()
          local ok, err = pcall(job.fn, elapsed)
          if not ok then job.dead = true; B.fault(job.scope, err) end
          if measuring then B.charge("job." .. job.scope, os.clock() - before) end
        end
      end
    end
    for index = #jobs, 1, -1 do
      if jobs[index].dead then table.remove(jobs, index) end
    end
  end
  local stats = Motion.stats
  stats.springs, stats.jobs, stats.ms = springCount, #jobs, (os.clock() - started) * 1000
end
B.own(S.RunService.RenderStepped:Connect(frame))
Motion._frame = frame
end
