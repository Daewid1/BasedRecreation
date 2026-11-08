do -- 08_film.lua
-- ============================================================================
--  08 film     frame-sequence player
--
--  The client cannot play a local video file (measured: VideoFrame and
--  VideoPlayer both refuse), and caps a local image at 1024 px. So a film is a
--  numbered run of JPEGs, and a frame above 1024 px wide is two textures side by
--  side. Each frame is decoded ahead of time in a pool of image slots. A slot
--  waits as a 1 px image; the two frames due next are made full size at alpha
--  0.001 ("primed") so the client has really drawn them; showing a frame is then
--  nothing but an alpha change.
--
--  That priming step is not optional. Measured with a 60 fps screen recording
--  and on-screen frame counters (tools/probes/present_test.lua): resizing a
--  frame to full size at the moment it is shown left the picture BLANK in 45%
--  of the recorded frames, while IsLoaded and every counter in Lua said all was
--  well. Primed, the frame on screen matched the frame Lua had presented in
--  every recorded frame, with no blanks.
--
--  Measured headroom on the test machine (10 slots): 1024x576 decodes at 337
--  frames/s and two-tile 1820x1024 at 171 frames/s against the 60 needed; both
--  presented 240/240 frames with none skipped.
--
--  The clock is wall time from the moment playback starts, so a slow frame
--  skips pictures instead of drifting away from the sound. Frames are counted
--  in an unwrapped sequence (0, 1, 2 ... across loops), which keeps every
--  "is this one newer" comparison a plain integer test.
--
--  Window mode (opts.window) is for a film that is part of the interface rather
--  than the whole screen: it needs rounded corners and may fade into what is
--  behind it, and a clip can do neither. Measured in this client's hidden UI: a
--  CanvasGroup neither clips its children nor takes a gradient, while a UICorner
--  and a UIGradient on the image itself both work, and a corner radius can be
--  set one corner at a time. So in window mode each tile is exactly the part of
--  the picture that shows, cut out of its texture by ImageRect, rounded on its
--  outer corners only and carrying its share of the fade.
-- ============================================================================
local S, Assets, fs = B.S, B.Assets, B.fs
local Film = { spec = B.FILM }
B.Film = Film

local HIDDEN = 0.999   -- a fully transparent image is never decoded; this one is
-- A waiting slot is a 1 px image parked at the CENTRE of the picture. Measured: an image that is
-- clipped out of view is never loaded, and a picture that covers a wider container overflows it,
-- so slots parked at its top-left corner sat off screen and the film stayed black.

function Film.has(setName, spec)
  spec = spec or Film.spec
  local set = spec and spec.sets and spec.sets[setName]
  if not set then return false end
  for _, tile in ipairs(set.tiles) do
    for _, index in ipairs({ 0, spec.count - 1 }) do
      if not Assets.frameIsFree(tile.path, index) and not fs.exists(fs.path(tile.path .. string.format("%0" .. set.digits .. "d.jpg", index))) then
        return false
      end
    end
  end
  return true
end
-- which set to play: the preference, falling back to whatever is installed
function Film.pick(preference, spec)
  local want = preference
  if want ~= "ultra" and want ~= "hd" then want = B.viewport().Y >= 800 and "ultra" or "hd" end
  if Film.has(want, spec) then return want end
  local other = want == "ultra" and "hd" or "ultra"
  if Film.has(other, spec) then return other end
  return nil
end
-- the part of a transparency ramp ({ { at, value }, ... }) between two fractions of its length
local function slice(points, a, b)
  local function at(t)
    local before = points[1]
    for _, point in ipairs(points) do
      if point[1] >= t then
        local span = point[1] - before[1]
        return span <= 0 and point[2] or before[2] + (point[2] - before[2]) * (t - before[1]) / span
      end
      before = point
    end
    return before[2]
  end
  local out = { NumberSequenceKeypoint.new(0, at(a)) }
  for _, point in ipairs(points) do
    if point[1] > a + 1e-3 and point[1] < b - 1e-3 then out[#out + 1] = NumberSequenceKeypoint.new((point[1] - a) / (b - a), point[2]) end
  end
  out[#out + 1] = NumberSequenceKeypoint.new(1, at(b))
  return NumberSequence.new(out)
end

-- opts: spec (which film: the intro unless given), set, slots, from / to (frame range), start
--       (film seconds), loop, audio, muted, volume, zIndex, window (see the header), backdrop,
--       budget (getcustomasset calls allowed per rendered frame), warmTo (last frame to pre-register),
--       clock (a function giving seconds: two players handed the same one are always on the same
--       frame, and one of them can be stopped and started without the other noticing)
function Film.new(parent, opts)
  local spec = opts.spec or Film.spec
  local set = spec and spec.sets[opts.set or "hd"]
  if not set then return nil end
  local fps, digits = spec.fps, set.digits
  local first, last = opts.from or 0, opts.to or (spec.count - 1)
  local length = last - first + 1
  local gapA, gapB = -1, -2          -- a film with no blackout: no frame is ever inside it
  if spec.gap then gapA, gapB = spec.gap[1], spec.gap[2] end
  local windowed = opts.window == true
  local slotCount = opts.slots or 10
  local budget = opts.budget or 2
  local tiles = set.tiles
  local self = { time = opts.start or first / fps, shown = -1, playing = false, ended = false, dead = false, volume = opts.volume or 0.5,
    muted = opts.muted == true, stats = { presented = 0, skipped = 0, late = 0, registered = 0 }, fps = fps, set = opts.set or "hd",
    length = length / fps, fresh = 0 }

  local frame = Instance.new("Frame")
  frame.Name = "Film"
  frame.BackgroundColor3 = Color3.new(0, 0, 0)
  frame.BackgroundTransparency = opts.backdrop == false and 1 or 0
  frame.BorderSizePixel = 0
  frame.Size = UDim2.fromScale(1, 1)
  frame.ClipsDescendants = true
  frame.ZIndex = opts.zIndex or 1
  frame.Parent = parent
  self.frame = frame
  -- the picture covers the container at the film's own aspect
  local picture = Instance.new("Frame")
  picture.Name = "Picture"
  picture.BackgroundTransparency = 1
  picture.BorderSizePixel = 0
  picture.AnchorPoint = Vector2.new(0.5, 0.5)
  picture.Position = UDim2.fromScale(0.5, 0.5)
  if windowed then picture.Size = UDim2.fromScale(1, 1) end
  picture.Parent = frame
  self.picture = picture
  local zoom = Instance.new("UIScale")
  zoom.Parent = picture
  self.zoom = zoom

  local rects = {}
  local slots = {}
  local current
  -- window mode: per tile, the part of it that shows (nil when none of it does)
  local cuts = {}
  local look = { tl = 0, tr = 0, br = 0, bl = 0, fade = nil, focusX = 0.5, focusY = 0.5 }
  self.look = look
  local function place(slot)
    for index, image in ipairs(slot.images) do
      if windowed then
        local cut = cuts[index]
        if cut then
          image.Position = UDim2.fromScale(cut.x, 0)
          image.Size = UDim2.fromScale(cut.w, 1)
          image.ImageRectOffset = Vector2.new(cut.rectX, cut.rectY)
          image.ImageRectSize = Vector2.new(cut.rectW, cut.rectH)
        else
          -- out of the window, but it still has to load for its frame to count as ready
          image.Position = UDim2.fromScale(0.5, 0.5)
          image.Size = UDim2.fromOffset(1, 1)
        end
      else
        image.Position = UDim2.fromOffset(rects[index][1], 0)
        image.Size = UDim2.new(0, rects[index][2], 1, 0)
      end
    end
  end
  local function dress()
    for _, slot in ipairs(slots) do
      for index in ipairs(slot.images) do
        local cut = cuts[index]
        if cut then
          local corner, fade = slot.corners[index], slot.fades[index]
          corner.TopLeftRadius, corner.BottomLeftRadius = UDim.new(0, cut.first and look.tl or 0), UDim.new(0, cut.first and look.bl or 0)
          corner.TopRightRadius, corner.BottomRightRadius = UDim.new(0, cut.last and look.tr or 0), UDim.new(0, cut.last and look.br or 0)
          if look.fade then
            fade.Transparency = slice(look.fade, cut.x, cut.x + cut.w)
            fade.Enabled = true
          elseif fade.Enabled then
            fade.Enabled = false
          end
        end
      end
    end
  end
  local function layout()
    local size = frame.AbsoluteSize
    if size.X < 2 or size.Y < 2 then return end
    if windowed then
      local W, H = math.floor(size.X + 0.5), math.floor(size.Y + 0.5)
      local scale = math.max(W / set.width, H / set.height)             -- screen pixels per film pixel
      local vw, vh = math.min(W / scale, set.width), math.min(H / scale, set.height)
      local vx, vy = (set.width - vw) * look.focusX, (set.height - vh) * look.focusY
      for index, tile in ipairs(tiles) do
        local t0, t1 = tile.x * set.width, (tile.x + tile.w) * set.width
        local a, b = math.max(t0, vx), math.min(t1, vx + vw)
        if b - a < 0.5 then
          cuts[index] = nil
        else
          -- Whole screen pixels, written as fractions of the container: exact under any UIScale,
          -- and both tiles round the seam between them from the same number. The rect follows
          -- the rounded pixel, and may reach a hair into the overlap the tiles were cut with.
          local x0 = a <= vx + 0.01 and 0 or math.floor((a - vx) * scale + 0.5)
          local x1 = b >= vx + vw - 0.01 and W or math.floor((b - vx) * scale + 0.5)
          cuts[index] = { x = x0 / W, w = (x1 - x0) / W, first = x0 == 0, last = x1 == W,
            rectX = tile.rectX + (vx + x0 / scale - t0), rectY = vy, rectW = (x1 - x0) / scale, rectH = vh }
        end
      end
      dress()
      for _, slot in ipairs(slots) do
        if slot == current or slot.primed then place(slot) end
      end
      return
    end
    local scale = math.max(size.X / set.width, size.Y / set.height)
    local w, h = math.ceil(set.width * scale), math.ceil(set.height * scale)
    picture.Size = UDim2.fromOffset(w, h)
    -- whole pixels per tile, so two halves never leave a seam or overlap
    local x = 0
    for index, tile in ipairs(tiles) do
      local right = index == #tiles and w or math.floor((tile.x + tile.w) * w + 0.5)
      rects[index] = { x, right - x }
      x = right
    end
    for _, slot in ipairs(slots) do
      if slot == current or slot.primed then place(slot) end
    end
  end
  for index = 1, slotCount do
    local slot = { images = {}, corners = {}, fades = {}, seq = nil }
    for t, tile in ipairs(tiles) do
      local image = Instance.new("ImageLabel")
      image.Name = "T" .. t
      image.BackgroundTransparency = 1
      image.BorderSizePixel = 0
      image.ScaleType = Enum.ScaleType.Stretch
      image.ImageRectOffset = Vector2.new(tile.rectX, 0)
      image.ImageRectSize = Vector2.new(tile.rectW, set.height)
      image.Size = UDim2.fromOffset(1, 1)
      image.Position = UDim2.fromScale(0.5, 0.5)
      image.ImageTransparency = HIDDEN
      if windowed then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 0)
        corner.Parent = image
        local fade = Instance.new("UIGradient")
        fade.Enabled = false
        fade.Parent = image
        slot.corners[t], slot.fades[t] = corner, fade
      end
      image.Parent = picture
      slot.images[t] = image
    end
    slots[index] = slot
  end
  layout()
  -- corner radii (tl, tr, br, bl, in the container's own units), a fade ({ { at, transparency }, ... }
  -- across the width, or false for none) and which part of the picture shows when it is cropped
  function self:setLook(next)
    local moved = false
    for key, value in pairs(next) do
      if (key == "focusX" or key == "focusY") and look[key] ~= value then moved = true end
      look[key] = value
    end
    if next.fade == false then look.fade = nil end
    if not windowed then return end
    if moved then layout() else dress() end
  end
  if opts.look then self:setLook(opts.look) end
  local resized = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

  local black = Instance.new("Frame")
  black.Name = "Black"
  black.BackgroundColor3 = Color3.new(0, 0, 0)
  black.BorderSizePixel = 0
  black.Size = UDim2.fromScale(1, 1)
  black.ZIndex = 2
  black.Visible = false
  black.Parent = frame

  local function indexOf(seq)
    return first + (opts.loop and seq % length or math.min(seq, length - 1))
  end
  local function inGap(index) return index >= gapA and index <= gapB end
  -- step a sequence number forward until it is on a frame that exists
  local function playable(seq)
    local index = indexOf(seq)
    if inGap(index) then seq += gapB - index + 1 end
    if not opts.loop and seq >= length then return nil end
    return seq
  end
  local function loaded(slot)
    for _, image in ipairs(slot.images) do
      if not image.IsLoaded then return false end
    end
    return true
  end
  local renderFrame = 0
  -- full size but invisible: drawn for real, so showing it later cannot blank
  local function prime(slot)
    if slot.primed then return end
    place(slot)
    slot.primed = renderFrame
  end
  local function reveal(slot, on)
    if on then
      if not slot.primed then place(slot) end
      local alpha = self.alpha or 1
      for index, image in ipairs(slot.images) do image.ImageTransparency = (windowed and not cuts[index]) and HIDDEN or 1 - alpha end
    else
      slot.primed = nil
      for _, image in ipairs(slot.images) do
        image.Size = UDim2.fromOffset(1, 1)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.ImageTransparency = HIDDEN
      end
    end
  end
  local function cost(index)
    local calls = 0
    for _, tile in ipairs(tiles) do
      if not Assets.frameIsFree(tile.path, index) then calls += 1 end
    end
    return calls
  end

  local assignedSeq, warmSeq, shownSeq = nil, nil, -1
  local spend = 0
  self.missing = false

  local function fill(horizon)
    for _, slot in ipairs(slots) do
      if not slot.seq and slot ~= current then
        local candidate = playable(math.max(assignedSeq and assignedSeq + 1 or horizon, horizon))
        if not candidate or candidate - horizon > slotCount + 1 then return end
        local index = indexOf(candidate)
        local need = cost(index)
        if need > spend then return end
        spend -= need
        self.stats.registered += need
        for t, tile in ipairs(tiles) do
          local id = Assets.frame(tile.path, index, digits)
          if not id then self.missing = true; return end
          slot.images[t].Image = id
        end
        slot.seq = candidate
        assignedSeq = candidate
      end
    end
  end
  local function warm()
    -- spare budget registers what comes next: those frames are free on every later launch
    local cursor = warmSeq or assignedSeq
    local guard = 0
    while spend > 0 and cursor and guard < 6 do
      guard += 1
      cursor = playable(cursor + 1)
      if not cursor then break end
      local index = indexOf(cursor)
      if opts.warmTo and index > opts.warmTo then break end
      if opts.loop and cursor >= length then break end
      local need = cost(index)
      if need > spend then break end
      if need > 0 then
        for _, tile in ipairs(tiles) do Assets.frame(tile.path, index, digits) end
        spend -= need
        self.stats.registered += need
      end
      warmSeq = cursor
    end
  end
  local function present(want)
    if inGap(indexOf(want)) then
      if not black.Visible then black.Visible = true end
      return
    end
    local best, waiting
    for _, slot in ipairs(slots) do
      local seq = slot.seq
      if seq and slot ~= current and seq <= want and seq > shownSeq and loaded(slot) then
        if slot.primed and renderFrame - slot.primed >= 1 then
          if not best or seq > best.seq then best = slot end
        elseif not waiting or seq > waiting.seq then
          waiting = slot
        end
      end
    end
    -- a frame that is due but was never primed (after a skip) gets one frame at full size first
    if waiting and (not best or waiting.seq > best.seq) then prime(waiting) end
    if best then
      reveal(best, true)
      if current then reveal(current, false); current.seq = nil end
      local jumped = best.seq - shownSeq - 1
      -- (the first picture after a start is not a skip: what lies before it was never due)
      if shownSeq >= 0 and jumped > 0 and jumped < 30 and self.fresh > 0 and not inGap(indexOf(shownSeq + 1)) then self.stats.skipped += jumped end
      current, shownSeq = best, best.seq
      self.current, self.shown = best, indexOf(best.seq)
      self.stats.presented += 1
      self.fresh += 1
      if black.Visible then black.Visible = false end
    elseif shownSeq >= 0 and shownSeq < want then
      self.stats.late += 1
    end
  end
  local function recycle(want)
    for _, slot in ipairs(slots) do
      local seq = slot.seq
      if seq and slot ~= current then
        -- already superseded, or so far behind the clock it will never be the newest
        if seq <= shownSeq or (seq < want - 3 and not loaded(slot)) then
          slot.seq = nil
          if slot.primed then reveal(slot, false) end
        end
      end
    end
  end
  -- make the two frames due next full size now
  local function primeAhead()
    local a, b
    for _, slot in ipairs(slots) do
      local seq = slot.seq
      if seq and slot ~= current and seq > shownSeq then
        if not a or seq < a.seq then b = a; a = slot
        elseif not b or seq < b.seq then b = slot end
      end
    end
    if a then prime(a) end
    if b then prime(b) end
  end
  local function pump(want)
    spend = budget
    renderFrame += 1
    present(want)
    recycle(want)
    fill(playable(want) or want)
    primeAhead()
    if spend > 0 then warm() end
  end

  local sound
  if opts.audio and spec.audio then
    local id = Assets.id(spec.audio)
    if id then
      sound = Instance.new("Sound")
      sound.Name = "Track"
      sound.SoundId = id
      sound.Volume = 0
      sound.Looped = opts.loop == true
      -- not under the picture: the picture is moved between containers, and a sound that
      -- changes parent starts over
      sound.Parent = opts.soundHost or frame
      self.sound = sound
    end
  end
  function self:setVolume(volume)
    self.volume = volume
    if sound then sound.Volume = volume end
  end
  -- Silent means the sound is not running at all, not running at volume 0. Unmuted, it joins
  -- at the picture's own time.
  function self:setMuted(muted)
    muted = muted == true
    if self.muted == muted then return end
    self.muted = muted
    if sound and muted then sound:Pause() end
  end
  function self:setAlpha(alpha)
    self.alpha = alpha
    if current then
      for index, image in ipairs(current.images) do image.ImageTransparency = (windowed and not cuts[index]) and HIDDEN or 1 - alpha end
    end
  end

  local function seqAt(seconds) return math.max(0, math.floor((seconds - first / fps) * fps + 1e-6)) end
  -- Decode the opening frames before the clock starts; returns when `count` are ready.
  function self:prepare(count, timeout, onProgress)
    local startSeq = playable(seqAt(self.time)) or 0
    count = math.min(count or 6, slotCount)
    local waited = 0
    while waited < (timeout or 4) and not self.dead do
      spend = math.max(budget, 4)
      fill(startSeq)
      local ready = 0
      for _, slot in ipairs(slots) do
        if slot.seq and loaded(slot) then ready += 1 end
      end
      if onProgress then onProgress(math.min(1, ready / count)) end
      renderFrame += 1
      primeAhead()
      if ready >= count or self.missing then break end
      waited += S.RunService.RenderStepped:Wait()
    end
    -- one more rendered frame, so the first pictures have been drawn at full size
    S.RunService.RenderStepped:Wait()
    renderFrame += 1
    if sound then
      local soundWait = 0
      while not sound.IsLoaded and soundWait < 1.5 and not self.dead do soundWait += S.RunService.RenderStepped:Wait() end
    end
    return not self.missing
  end

  -- `held` is how far the clock had run when it was paused. A looping film cannot take that
  -- from its time, which wraps: the frame sequence does not, and would never catch up.
  local started, held, lastJoin = 0, nil, 0
  function self:play()
    if self.dead or self.playing then return end
    self.playing, self.ended = true, false
    started = os.clock() - (held or (self.time - first / fps))
    held = nil
    -- how many pictures it has shown since it was last started: on someone else's clock, what it
    -- holds from before is old, and the one still on show is not to be trusted until this moves
    self.fresh = 0
    if opts.clock then
      for _, slot in ipairs(slots) do
        if slot ~= current then
          slot.seq = nil
          if slot.primed then reveal(slot, false) end
        end
      end
      assignedSeq, warmSeq = nil, nil
    end
    if sound and sound.IsLoaded and not self.muted then
      sound.TimePosition = self.time
      sound.Volume = self.volume
      sound:Play()
      lastJoin = os.clock()
    end
  end
  function self:pause()
    if self.playing then held = os.clock() - started end
    self.playing = false
    if sound then sound:Pause() end
  end
  local lastSync = 0
  local connection = S.RunService.RenderStepped:Connect(function()
    if self.dead then return end
    if not frame.Parent then self:destroy(); return end
    if not self.playing then return end
    local now = os.clock()
    local elapsed = opts.clock and opts.clock() or now - started
    local loopLength = length / fps
    if sound and not self.muted then
      if not sound.IsPlaying then
        -- unmuted, or loaded late, or back from a pause: join at the picture's own time
        local at = first / fps + (opts.loop and elapsed % loopLength or elapsed)
        if sound.IsLoaded and now - lastJoin > 0.25 and (opts.loop or at < sound.TimeLength - 0.05) then
          sound.TimePosition = at
          sound.Volume = self.volume
          sound:Play()
          lastSync, lastJoin = now, now
        end
      elseif now - lastSync > 0.5 then
        -- follow the sound if the two drift apart (its position only updates in coarse steps)
        lastSync = now
        local drift = sound.TimePosition - (first / fps + (opts.loop and elapsed % loopLength or elapsed))
        if opts.loop then drift = (drift + loopLength / 2) % loopLength - loopLength / 2 end
        if math.abs(drift) > 0.12 and math.abs(drift) < 2 then
          if opts.clock then
            -- the clock is not ours to move: bring the sound to the picture instead
            sound.TimePosition = first / fps + (opts.loop and elapsed % loopLength or elapsed)
          else
            started -= drift * 0.5
            elapsed = now - started
          end
        end
      end
    end
    local want = math.floor(elapsed * fps)
    if not opts.loop and want >= length then
      self.time = (last + 1) / fps
      self.playing, self.ended = false, true
      if sound then sound:Stop() end
      if self.onEnded then B.try("film.ended", self.onEnded) end
      return
    end
    self.time = first / fps + (opts.loop and elapsed % (length / fps) or elapsed)
    local ok, err = pcall(pump, want)
    if not ok then B.fault("film", err); self:destroy() end
  end)

  function self:destroy()
    if self.dead then return end
    self.dead, self.playing = true, false
    connection:Disconnect()
    resized:Disconnect()
    if sound then
      pcall(function() sound:Stop() end)
      if sound.Parent ~= frame then sound:Destroy() end
    end
    frame:Destroy()
  end
  B.own(self)
  return self
end
end
