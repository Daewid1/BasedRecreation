-- BASED Hub: the installer.
--
--   local response = request({Url = "https://raw.githubusercontent.com/Daewid1/BasedRecreation/main/Loader.lua", Method = "GET"}); assert(response.StatusCode == 200, "Download failed"); assert(loadstring(response.Body))()
--
-- The first time, it fetches the hub, the files the hub draws with (fonts, icons, textures,
-- sounds) and its films (the two intros, and the one on the Home tab), shows how far along it
-- is, and starts the hub. After that there is
-- no download and no download screen: it looks at what is already here, asks whether a newer
-- build is out, fetches only what changed if one is, and starts the hub. With no network it
-- starts the build that is already installed.
--
-- It writes to two places in the executor's workspace and nowhere else: the file BasedRecreation.lua
-- and the folder BasedRecreation/, and never over the settings you saved there. The list of files is
-- install.json on the main branch. It names one commit and every file is fetched from that
-- commit, so a list and its files always belong together; each file is checked against the
-- size the list gives for it before it is written. A film is a few thousand frames, so it
-- comes as packs of frames (packs/*.pack) that are taken apart here, in the picture sizes that
-- suit the screen; the hub runs without its films, so one that does not arrive never stops a
-- start.
local RAW = "https://raw.githubusercontent.com/Daewid1/BasedRecreation/"
local ROOT, SCRIPT, LIST = "BasedRecreation", "BasedRecreation.lua", "install.json"
local RECORD = ROOT .. "/cache/installed.json"
local FORMAT = 1          -- the newest install.json this file understands
local WORKERS, TRIES = 4, 3
local PATIENCE = 4        -- seconds an installed hub waits to hear whether a newer build is out
local YOURS = { ["prefs.json"] = true, config = true, cache = true }      -- never fetched over

local genv = (type(getgenv) == "function" and getgenv()) or _G
if genv.HUSS_BASED_INSTALLING then return end
genv.HUSS_BASED_INSTALLING = true

local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local canStore = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
  and type(makefolder) == "function" and type(isfolder) == "function"

-- ---------------------------------------------------------------- fetching and storing
local requester = (type(request) == "function" and request) or (type(http_request) == "function" and http_request)
  or (type(syn) == "table" and type(syn.request) == "function" and syn.request) or nil
-- what is at `url`, or nil and why not
local function fetch(url)
  if requester then
    local ok, response = pcall(requester, { Url = url, Method = "GET" })
    if ok and type(response) == "table" then
      local status = tonumber(response.StatusCode) or 0
      if status >= 200 and status < 300 and type(response.Body) == "string" then return response.Body end
      if status >= 400 then return nil, "the server answered " .. status end
    end
  end
  return nil, "request() failed or is unavailable"
end
local function has(path)
  local ok, present = pcall(isfile, path)
  return ok and present == true
end
local function verified(data, size, sha256)
  if type(data) ~= "string" or #data ~= size then return false end
  if type(sha256) ~= "string" or #sha256 ~= 64 or string.find(sha256, "%X") then return false end
  -- Executor string hashes can stop at a binary file's first null byte.
  local ok, digest = pcall(function()
    return game:GetService("EncodingService"):ComputeBufferHash(buffer.fromstring(data), Enum.HashAlgorithm.Sha256)
  end)
  if not ok or typeof(digest) ~= "buffer" or buffer.len(digest) ~= 32 then return false end
  local hex = table.create(32)
  for index = 0, 31 do hex[index + 1] = string.format("%02x", buffer.readu8(digest, index)) end
  return table.concat(hex) == sha256
end
local function store(path, data)
  local built = ""
  for part in string.gmatch(path, "([^/]+)/") do
    built = built == "" and part or (built .. "/" .. part)
    local ok, present = pcall(isfolder, built)
    if not (ok and present) then pcall(makefolder, built) end
  end
  return (pcall(writefile, path, data))
end
-- a name from the list is a plain path inside the hub's own folder, and never one of yours
local function plain(path)
  if type(path) ~= "string" or string.match(path, "^[%w_%-%./]+$") == nil then return false end
  if string.find(path, "..", 1, true) or string.find(path, "//", 1, true) then return false end
  if string.sub(path, 1, 1) == "/" or string.sub(path, -1) == "/" then return false end
  return not YOURS[string.match(path, "^[^/]+")]
end

-- The list, or nil and what is wrong with it.
local function readList(body)
  local ok, list = pcall(function() return Http:JSONDecode(body) end)
  if not ok or type(list) ~= "table" then return nil, "the list of files could not be read" end
  if type(list.format) ~= "number" then return nil, "the list of files could not be read" end
  if list.format > FORMAT then return nil, "this build needs a newer installer: try again in a few minutes" end
  local whole = type(list.build) == "string" and string.match(list.build, "^%d%d%d%d%d%d%d%d%.%d%d%d%d$") ~= nil
    and type(list.commit) == "string" and #list.commit == 40 and string.find(list.commit, "%X") == nil
    and type(list.hub) == "table" and type(list.hub.size) == "number" and type(list.files) == "table"
  if not whole then return nil, "the list of files is not complete" end
  return list
end
-- Which build of the hub is installed. The hub says so itself in its first lines, so this holds
-- whoever put the file there and whatever became of the notes kept beside it.
local function installedBuild()
  if not has(SCRIPT) then return nil end
  local ok, text = pcall(readfile, SCRIPT)
  if not ok or type(text) ~= "string" then return nil end
  return string.match(string.sub(text, 1, 400), 'BUILD = "(%d%d%d%d%d%d%d%d%.%d%d%d%d)"')
end
-- The note of what was fetched here before: the stamp of every file that arrived whole.
local function readRecord()
  local record
  if has(RECORD) then
    local ok, data = pcall(function() return Http:JSONDecode(readfile(RECORD)) end)
    if ok and type(data) == "table" then record = data end
  end
  record = record or {}
  if type(record.files) ~= "table" then record.files = {} end
  if type(record.packs) ~= "table" then record.packs = {} end
  return record
end
local function saveRecord(record)
  record.unsaved = nil
  local ok, json = pcall(function() return Http:JSONEncode({ files = record.files, packs = record.packs }) end)
  if ok then store(RECORD, json) end
end
-- The files of the list that are not here yet, in the order they will be fetched, and their size together.
local function wanted(list, record)
  local need, bytes = {}, 0
  for path, item in pairs(list.files) do
    if plain(path) and type(item) == "table" and type(item.size) == "number" and type(item.stamp) == "string" then
      local to = ROOT .. "/" .. path
      local here = has(to)
      if here and record.files[path] == nil then
        -- here, with no note of it (the notes were lost, or it was put here by hand): the right size is taken as the right file
        local ok, data = pcall(readfile, to)
        if ok and verified(data, item.size, item.sha256) then
          record.files[path] = item.stamp
          record.unsaved = true
        end
      end
      if not here or record.files[path] ~= item.stamp then
        need[#need + 1] = { name = path, from = to, to = to, size = item.size, stamp = item.stamp, sha256 = item.sha256 }
        bytes += item.size
      end
    end
  end
  table.sort(need, function(a, b) return a.name < b.name end)
  return need, bytes
end

-- ---------------------------------------------------------------- the film
-- A pack is a run of numbered frames in one file: "BHPK1 <count>", a line of their sizes, then
-- the frames one after another. The list says which frames a pack holds (prefix, from, to) and
-- they are only ever written inside the hub's two film folders.
local function filmFolder(prefix)
  -- (one folder per film: a pack is only ever unpacked into one of them)
  for _, folder in ipairs({ "film", "board", "reel", "lock", "prates", "brand", "richard" }) do
    if string.match(prefix, "^" .. folder .. "/[%w_%-/]+$") ~= nil then return true end
  end
  return false
end
local function soundPack(pack)
  return type(pack) == "table" and type(pack.at) == "string" and string.match(pack.at, "^packs/[%w_%-]+%.pack$") ~= nil
    and type(pack.size) == "number" and type(pack.stamp) == "string"
    and type(pack.prefix) == "string" and filmFolder(pack.prefix) and string.find(pack.prefix, "//", 1, true) == nil
    and type(pack.from) == "number" and type(pack.to) == "number" and pack.from % 1 == 0 and pack.to % 1 == 0
    and pack.from >= 0 and pack.to >= pack.from and pack.to - pack.from < 2000
    and type(pack.digits) == "number" and pack.digits % 1 == 0 and pack.digits >= 1 and pack.digits <= 8
    and type(pack.ext) == "string" and string.match(pack.ext, "^%.%w+$") ~= nil
end
local function framePath(pack, index)
  return ROOT .. "/" .. pack.prefix .. string.format("%0" .. pack.digits .. "d", index) .. pack.ext
end
-- Whether a pack's frames are all here. Noted: its first and last are enough. Not noted at all
-- (the notes were lost, or the film was put here by hand): every one of them has to be. Noted as
-- another version: no.
local function packHere(pack, record)
  local noted = record.packs[pack.at]
  if noted == pack.stamp then return has(framePath(pack, pack.from)) and has(framePath(pack, pack.to)) end
  if noted ~= nil then return false end
  for index = pack.from, pack.to do
    if not has(framePath(pack, index)) then return false end
  end
  record.packs[pack.at] = pack.stamp
  record.unsaved = true
  return true
end
-- Take a pack apart into its frames. True, or false and what is wrong with it.
local function unpack(pack, data)
  local headEnd = string.find(data, "\n", 1, true)
  local sizesEnd = headEnd and string.find(data, "\n", headEnd + 1, true)
  if not sizesEnd then return false, "it is not a pack" end
  local count = tonumber(string.match(string.sub(data, 1, headEnd - 1), "^BHPK1 (%d+)$"))
  if count ~= pack.to - pack.from + 1 then return false, "it does not hold the frames the list says" end
  local sizes, total = {}, 0
  for digits in string.gmatch(string.sub(data, headEnd + 1, sizesEnd - 1), "%d+") do
    sizes[#sizes + 1] = tonumber(digits)
    total += sizes[#sizes]
  end
  if #sizes ~= count or total ~= #data - sizesEnd then return false, "its frames do not add up" end
  local at = sizesEnd + 1
  for offset = 0, count - 1 do
    local size = sizes[offset + 1]
    if not store(framePath(pack, pack.from + offset), string.sub(data, at, at + size - 1)) then return false, "a frame could not be written" end
    at += size
    if offset % 24 == 23 then task.wait() end       -- a hundred and fifty writes in a row would hold the screen still
  end
  return true
end
-- What of a film is still to fetch, or nil when there is nothing: no such film in the list, or
-- it is here. A film comes in several picture sizes. Of the intro one size is enough: a size
-- that is here, or partly here, is the one kept to; otherwise the first the screen is tall
-- enough for. Of a film marked `all` (the one on the Home tab, which the hub shows small in its
-- card and large when it opens) every size the screen is tall enough for is fetched.
local function filmPlan(film, record, what)
  if type(film) ~= "table" or type(film.sets) ~= "table" then return nil end
  local camera = workspace.CurrentCamera
  local height = camera and camera.ViewportSize.Y or 1080
  -- every size the list describes soundly, with what of it is missing here
  local sizes = {}
  for _, set in ipairs(film.sets) do
    if type(set) == "table" and type(set.packs) == "table" and #set.packs > 0 then
      local missing, have, sound = {}, 0, true
      for _, pack in ipairs(set.packs) do
        if not soundPack(pack) then
          sound = false
          break
        end
        if packHere(pack, record) then have += 1 else missing[#missing + 1] = pack end
      end
      if sound then sizes[#sizes + 1] = { set = set, missing = missing, have = have, fits = (tonumber(set.minHeight) or 0) <= height } end
    end
  end
  local chosen = {}
  if film.all == true then
    for _, this in ipairs(sizes) do
      if this.fits or this.have > 0 then chosen[#chosen + 1] = this end
    end
  else
    local kept, fits
    for _, this in ipairs(sizes) do
      if this.have > (kept and kept.have or 0) then kept = this end
      if not fits and this.fits then fits = this end
    end
    chosen[1] = kept or fits
  end
  if #chosen == 0 then return nil end
  local body, last, bytes = {}, {}, 0
  if type(film.files) == "table" then
    -- the plain files that go with it (its soundtrack)
    for _, item in ipairs((wanted({ files = film.files }, record))) do
      body[#body + 1] = item
      bytes += item.size
    end
  end
  local parts, before = 0, 0
  for _, this in ipairs(chosen) do parts += #this.set.packs end
  for _, this in ipairs(chosen) do
    -- The hub takes a film to be here when the first and the last frame of each strip are. So the
    -- pack that opens each strip is fetched after everything else has arrived: half a film is
    -- then never taken for a whole one.
    local opens = {}
    for _, pack in ipairs(this.set.packs) do
      if opens[pack.prefix] == nil or pack.from < opens[pack.prefix] then opens[pack.prefix] = pack.from end
    end
    for _, pack in ipairs(this.missing) do
      local part = before + (table.find(this.set.packs, pack) or 0)
      local item = { name = string.format("%s, part %d of %d", what, part, parts), from = pack.at, size = pack.size, pack = pack, sha256 = pack.sha256 }
      if pack.from == opens[pack.prefix] then last[#last + 1] = item else body[#body + 1] = item end
      bytes += pack.size
    end
    before += #this.set.packs
  end
  if #body + #last == 0 then return nil end
  return { body = body, last = last, count = #body + #last, bytes = bytes }
end

-- ---------------------------------------------------------------- the screen
local BASE, INK, SUB, FAINT, ACCENT = Color3.fromRGB(11, 11, 15), Color3.fromRGB(245, 244, 239), Color3.fromRGB(169, 168, 180),
  Color3.fromRGB(108, 107, 119), Color3.fromRGB(142, 125, 255)
local function face(name, weight, style)
  local ok, made = pcall(Font.fromName, name, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
  return ok and made or Font.fromEnum(Enum.Font.Gotham)
end
local function make(class, props, parent)
  local item = Instance.new(class)
  for key, value in pairs(props) do item[key] = value end
  item.Parent = parent
  return item
end
local function screen()
  local gui = make("ScreenGui", { Name = "BasedInstall", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 9500,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
  local shade = make("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
    BorderSizePixel = 0 }, gui)
  local card = make("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(480, 244), BackgroundColor3 = BASE, BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
  make("UICorner", { CornerRadius = UDim.new(0, 24) }, card)
  local rim = make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 1, Thickness = 1 }, card)
  local zoom = make("UIScale", { Scale = 1 }, card)
  local texts = {}
  local function label(name, text, font, size, color, props, parent)
    local item = make("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = font, TextSize = size, TextColor3 = color, Text = text,
      TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, TextXAlignment = Enum.TextXAlignment.Left }, parent or card)
    for key, value in pairs(props) do item[key] = value end
    texts[#texts + 1] = item
    return item
  end
  -- the name, set the way the hub sets it: a wide black word and an italic one after it
  local brand = make("Frame", { Name = "Brand", BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 32), Size = UDim2.fromOffset(0, 34),
    AutomaticSize = Enum.AutomaticSize.X }, card)
  make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7) }, brand)
  label("Word", "BASED", face("BuilderExtended", Enum.FontWeight.Heavy), 28, INK, { LayoutOrder = 1 }, brand)
  label("Hub", "hub", face("Merriweather", Enum.FontWeight.Regular, Enum.FontStyle.Italic), 26, ACCENT, { LayoutOrder = 2 }, brand)
  local status = label("Status", "", face("BuilderSans", Enum.FontWeight.Medium), 18, INK, { Position = UDim2.fromOffset(36, 94) })
  local detail = label("Detail", "", face("RobotoMono"), 12, SUB, { Position = UDim2.fromOffset(36, 121), AutomaticSize = Enum.AutomaticSize.None,
    Size = UDim2.new(1, -72, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
  local track = make("Frame", { Name = "Track", Position = UDim2.fromOffset(36, 156), Size = UDim2.new(1, -72, 0, 4),
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, card)
  make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
  local fill = make("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0 }, track)
  make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
  local count = label("Count", "", face("RobotoMono"), 12, SUB, { Position = UDim2.fromOffset(36, 171) })
  local size = label("Size", "", face("RobotoMono"), 12, SUB, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -36, 0, 171),
    TextXAlignment = Enum.TextXAlignment.Right })
  local foot = label("Foot", "This happens once. After it, the hub starts straight away.", face("BuilderSans"), 13, FAINT,
    { Position = UDim2.fromOffset(36, 204) })
  local again = make("TextButton", { Name = "Again", Text = "Try again", FontFace = face("BuilderSans", Enum.FontWeight.Medium), TextSize = 14,
    TextColor3 = INK, AutoButtonColor = false, BackgroundColor3 = ACCENT, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -36, 0, 196), Size = UDim2.fromOffset(108, 32), Visible = false }, card)
  make("UICorner", { CornerRadius = UDim.new(0, 10) }, again)

  local parented = pcall(function() gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui") end)
  if not parented then gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

  -- one loop moves all of it: the card settles in, the bar follows what has arrived
  local view = { goal = 0, shown = 0, alpha = 0, leaving = false, gui = gui }
  local step
  step = RunService.RenderStepped:Connect(function(dt)
    view.alpha += ((view.leaving and 0 or 1) - view.alpha) * math.min(1, dt * 12)
    view.shown += (view.goal - view.shown) * math.min(1, dt * 9)
    local a = view.alpha
    local camera = workspace.CurrentCamera
    local fit = camera and math.clamp(math.min(camera.ViewportSize.Y / 1000, camera.ViewportSize.X / 560), 0.55, 1.3) or 1
    zoom.Scale = fit * (0.965 + 0.035 * a)
    shade.BackgroundTransparency = 1 - 0.55 * a
    card.BackgroundTransparency = 1 - 0.98 * a
    rim.Transparency = 1 - 0.1 * a
    track.BackgroundTransparency = 1 - 0.09 * a
    fill.BackgroundTransparency = 1 - a
    fill.Size = UDim2.fromScale(math.clamp(view.shown, 0, 1), 1)
    for _, item in ipairs(texts) do item.TextTransparency = 1 - a end
    again.TextTransparency, again.BackgroundTransparency = 1 - a, 1 - 0.9 * a
  end)
  function view.say(text, small)
    status.Text = text
    detail.Text = small or ""
  end
  function view.progress(done, total, bytes, allBytes)
    view.goal = allBytes > 0 and bytes / allBytes or 1
    count.Text = string.format("%d of %d %s", done, total, total == 1 and "file" or "files")
    -- a small update is counted in kB: "0.0 of 0.0 MB" would say nothing
    if allBytes < 1e6 then
      size.Text = string.format("%d of %d kB", math.ceil(bytes / 1000), math.ceil(allBytes / 1000))
    else
      size.Text = string.format("%.1f of %.1f MB", bytes / 1e6, allBytes / 1e6)
    end
  end
  -- something went wrong: say what, and wait for the button
  function view.ask(text, small)
    view.say(text, small)
    foot.Visible, again.Visible = false, true
    again.Activated:Wait()
    foot.Visible, again.Visible = true, false
  end
  function view.close()
    view.leaving = true
    task.delay(0.4, function()
      step:Disconnect()
      gui:Destroy()
    end)
  end
  return view
end

-- ---------------------------------------------------------------- installing
-- Fetch what is missing: the hub's files, the hub, then the films. True when the hub and what it
-- draws with are in place (and with it the hub, compiled, when it was fetched), or false and
-- what went wrong. The third value is the film that did not finish, when only a film failed:
-- the hub runs without it. What did arrive is kept, so another go fetches only the rest.
local function bring(list, record, view, updating, films)
  local base = RAW .. list.commit .. "/"
  local need, bytes = wanted(list, record)
  local hubToo = installedBuild() ~= list.build
  local total, allBytes = #need + (hubToo and 1 or 0), bytes + (hubToo and list.hub.size or 0)
  for _, film in ipairs(films) do
    total += film.plan.count
    allBytes += film.plan.bytes
  end
  local title = updating and "Updating the hub" or "Getting the hub ready"
  local done, got = 0, 0
  view.say(title, "")
  view.progress(0, total, 0, allBytes)
  local function one(url, size, sha256)
    local data, why
    for attempt = 1, TRIES do
      data, why = fetch(url)
      if data and not verified(data, size, sha256) then data, why = nil, "size or SHA-256 verification failed" end
      if data then return data end
      if attempt < TRIES then task.wait(0.5 * attempt) end
    end
    return nil, why
  end
  -- one thing, fetched and put in its place: nil, or why not
  local function take(item)
    local data, why = one(base .. item.from, item.size, item.sha256)
    if not data then return why end
    if item.pack then
      local ok, problem = unpack(item.pack, data)
      if not ok then return problem end
      record.packs[item.pack.at] = item.pack.stamp
    else
      if not store(item.to, data) then return "it could not be written" end
      record.files[item.name] = item.stamp
    end
    saveRecord(record)
    return nil
  end
  -- a list of things, a few at a time: nil, or the first that failed and why
  local function run(items, saying)
    local cursor, running, failed = 0, 0, nil
    local function worker()
      running += 1
      while not failed do
        cursor += 1
        local item = items[cursor]
        if not item then break end
        local why = take(item)
        if why then
          failed = failed or (item.name .. ": " .. tostring(why))
          break
        end
        done += 1
        got += item.size
        view.say(saying, item.name)
        view.progress(done, total, got, allBytes)
      end
      running -= 1
    end
    for _ = 1, math.min(WORKERS, #items) do task.spawn(worker) end
    while running > 0 do task.wait() end
    return failed
  end

  -- the hub's files first
  local failed = run(need, title)
  if failed then return false, failed end
  -- then the hub itself, so that a hub is never here without what it draws with
  local chunk
  if hubToo then
    view.say(title, SCRIPT)
    local data, why = one(base .. SCRIPT, list.hub.size, list.hub.sha256)
    if not data then return false, SCRIPT .. ": " .. tostring(why) end
    local problem
    chunk, problem = loadstring(data, "=BasedRecreation")
    if not chunk then return false, SCRIPT .. " does not compile: " .. tostring(problem) end
    if not store(SCRIPT, data) then return false, SCRIPT .. ": it could not be written" end
    done += 1
    got += list.hub.size
    view.progress(done, total, got, allBytes)
  end
  -- and the films last: the hub is whole without them, so nothing that goes wrong from here stops it starting
  local unfinished
  for _, film in ipairs(films) do
    local saying = "Getting " .. film.name
    view.say(saying, "")
    local trouble = run(film.plan.body, saying) or run(film.plan.last, saying)
    if trouble then unfinished = unfinished or film.name end
  end
  if unfinished then return true, chunk, unfinished end
  view.progress(total, total, allBytes, allBytes)
  return true, chunk
end

local function start(chunk)
  if type(chunk) ~= "function" then
    local problem
    chunk, problem = loadstring(readfile(SCRIPT), "=BasedRecreation")
    if not chunk then error("the installed hub does not compile: " .. tostring(problem)) end
  end
  return chunk()
end

local function install()
  if not canStore then
    -- nowhere to keep anything: run the hub straight from the address, without its files
    local body, why = fetch(RAW .. "main/" .. SCRIPT)
    local chunk = body and loadstring(body, "=BasedRecreation")
    if not chunk then error("this executor cannot store files, and the hub could not be fetched (" .. tostring(why) .. ")") end
    return chunk()
  end
  local record = readRecord()
  local view
  while true do
    local build = installedBuild()
    local installed = has(SCRIPT)
    if not installed and not view then
      view = screen()
      view.say("Getting the hub ready", "Looking for the latest build")
    end
    -- ask what is current; a hub that is already here does not wait long for the answer
    local answer = {}
    task.spawn(function()
      answer.body, answer.why = fetch(RAW .. "main/" .. LIST)
      answer.done = true
    end)
    local waited = 0
    while not answer.done and (not installed or waited < PATIENCE) do waited += task.wait() end
    local list, why
    if answer.body then list, why = readList(answer.body) else why = answer.done and answer.why or "no answer in time" end

    -- a list older than the build that is here (a cache that has not caught up, or a newer build of your own) changes nothing
    if list and build ~= nil and list.build < build then list = nil end
    -- already downloaded: nothing to fetch, nothing to show, the hub starts
    local films = {}
    if list then
      -- (the brand film first: it is the intro everyone starts on, so it is the one most wanted here)
      for _, film in ipairs({ { key = "brand", name = "the brand intro" }, { key = "film", name = "the intro film" }, { key = "board", name = "the Home film" },
        { key = "reel", name = "the Invincible intro" }, { key = "lock", name = "the Just use BASED intro" }, { key = "prates", name = "the Prates intro" },
        { key = "richard", name = "the Neverlose vs BASED intro" } }) do
        film.plan = filmPlan(list[film.key], record, film.name)
        if film.plan then films[#films + 1] = film end
      end
    end
    local upToDate = list ~= nil and build == list.build and #wanted(list, record) == 0 and #films == 0
    if record.unsaved then saveRecord(record) end
    if installed and (not list or upToDate) then
      if view then view.close() end
      return start()
    end
    if not list then
      view.ask("Could not reach the download", string.sub(tostring(why), 1, 70))
    else
      view = view or screen()
      local ok, result, unfinished = bring(list, record, view, installed, films)
      if ok then
        if unfinished then
          -- the hub is whole: it starts, and the rest of the film is fetched the next time
          view.say(string.upper(string.sub(unfinished, 1, 1)) .. string.sub(unfinished, 2) .. " did not finish", "It carries on the next time you run this")
          task.wait(1.6)
        else
          view.say("Starting", "")
          task.wait(0.3)
        end
        view.close()
        return start(result)
      elseif installed then
        -- an update that did not finish: the build that is here still runs
        view.say("Could not update just now", "Starting the build you have")
        task.wait(1.1)
        view.close()
        return start()
      else
        view.ask("A file would not download", string.sub(tostring(result), 1, 70))
      end
    end
  end
end

local ok, problem = pcall(install)
genv.HUSS_BASED_INSTALLING = nil
if not ok then
  warn("BASED Hub could not start: " .. tostring(problem))
  pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BASED Hub", Text = "Could not start: " .. string.sub(tostring(problem), 1, 120), Duration = 8 })
  end)
end
