do -- 03_assets.lua
-- ============================================================================
--  03 assets   files on disk -> content ids, fonts, icons, sounds
--
--  Measured on Potassium (2026-10-06): getcustomasset costs 3-5 ms per call on
--  the main thread whatever the file size, the files it copies stay in the
--  client's content folder between sessions, and the id is always
--  <prefix>/<basename>. So a file is registered ONCE, ever; after that its id is
--  built by hand for free. A sentinel is checked at boot because a client update
--  can empty that folder.
-- ============================================================================
local S, fs, util = B.S, B.fs, B.util
local Assets = { ready = false, lite = false, calls = 0 }
B.Assets = Assets
local manifest = B.MANIFEST or { files = {}, icons = { map = {} } }
Assets.manifest = manifest

local canRegister = type(getcustomasset) == "function" and fs.ok
local REGISTRY = fs.path("cache/registry.json")
local registry = { files = {}, seq = {} }
local ids = {}            -- relative path -> content id, or false when unavailable
local seqIds = {}         -- sequence prefix -> { [index] = id }
local seqKnown = {}       -- sequence prefix -> { [index] = true } registered in an earlier session
local dirty = false

local function basename(path) return string.match(path, "[^/\\]+$") or path end
local function prefixOf(id) return string.match(id, "^(rbxasset://[^/]+/)") end

local saveSoon = util.debounce(1.5, function()
  if not dirty then return end
  dirty = false
  local seq = {}
  for key, known in pairs(seqKnown) do
    -- compress the registered indices into [from, to] runs
    local runs, from, last = {}, nil, nil
    local indices = util.keys(known)
    table.sort(indices)
    for _, index in ipairs(indices) do
      if from and index == last + 1 then last = index
      else
        if from then runs[#runs + 1] = { from, last } end
        from, last = index, index
      end
    end
    if from then runs[#runs + 1] = { from, last } end
    seq[key] = runs
  end
  fs.writeJson(REGISTRY, { prefix = registry.prefix, sentinel = registry.sentinel, files = registry.files, seq = seq })
end)
local function touch() dirty = true; saveSoon() end

local function register(path)
  Assets.calls += 1
  local ok, id = pcall(getcustomasset, path)
  if not ok or type(id) ~= "string" or id == "" then return nil end
  local prefix = prefixOf(id)
  if prefix and registry.prefix ~= prefix then
    -- a different content folder: nothing registered before is reachable
    registry.prefix = prefix
    registry.files = {}
    table.clear(seqKnown)
  end
  return id
end

-- Content id for a file under BasedRecreation/, or nil when it is not installed.
function Assets.id(relative)
  local cached = ids[relative]
  if cached ~= nil then return cached or nil end
  if not canRegister then ids[relative] = false; return nil end
  local name = basename(relative)
  local stamp = manifest.files[relative] or "x"
  local id
  if registry.prefix and registry.files[name] == stamp then
    id = registry.prefix .. name
  else
    id = register(fs.path(relative))
    if id then
      registry.files[name] = stamp
      -- the sentinel must be something PreloadAsync can load and report on: an image
      if string.match(name, "%.png$") or string.match(name, "%.jpg$") then registry.sentinel = name end
      touch()
    end
  end
  ids[relative] = id or false
  return id
end

-- Content id for frame `index` of a numbered sequence ("film/hd/bhf1_h_", 4 digits).
function Assets.frame(pathPrefix, index, digits, extension)
  local cache = seqIds[pathPrefix]
  if not cache then cache = {}; seqIds[pathPrefix] = cache end
  local id = cache[index]
  if id ~= nil then return id or nil end
  if not canRegister then return nil end
  local file = pathPrefix .. string.format("%0" .. (digits or 4) .. "d", index) .. (extension or ".jpg")
  local known = seqKnown[pathPrefix]
  if known and known[index] and registry.prefix then
    id = registry.prefix .. basename(file)
  else
    id = register(fs.path(file))
    if id then
      if not known then known = {}; seqKnown[pathPrefix] = known end
      known[index] = true
      touch()
    end
  end
  cache[index] = id or false
  return id
end
-- true when frame `index` can be had without a getcustomasset call
function Assets.frameIsFree(pathPrefix, index)
  local cache = seqIds[pathPrefix]
  if cache and cache[index] then return true end
  local known = seqKnown[pathPrefix]
  return known ~= nil and known[index] == true and registry.prefix ~= nil
end

function Assets.has(relative) return fs.exists(fs.path(relative)) end

-- ---------------------------------------------------------------- fonts
local FONT_FILES = {
  text400 = { "Inter", "fonts/Inter-Regular.ttf", 400 }, text500 = { "Inter", "fonts/Inter-Medium.ttf", 500 },
  text600 = { "Inter", "fonts/Inter-SemiBold.ttf", 600 }, text700 = { "Inter", "fonts/Inter-Bold.ttf", 700 },
  mono400 = { "GeistMono", "fonts/GeistMono-Regular.ttf", 400 }, mono500 = { "GeistMono", "fonts/GeistMono-Medium.ttf", 500 },
  serif = { "InstrumentSerif", "fonts/InstrumentSerif-Regular.ttf", 400 },
  serifItalic = { "InstrumentSerifItalic", "fonts/InstrumentSerif-Italic.ttf", 400 },
  wideBold = { "ArchivoExpanded", "fonts/Archivo-ExpandedBold.ttf", 700 },
  wideBlack = { "ArchivoExpanded", "fonts/Archivo-ExpandedBlack.ttf", 900 },
  -- the Unnamed menu's: Monocraft (the Minecraft letters), and the two Proggy pixel fonts
  craft = { "Monocraft", "fonts/Monocraft.ttf", 400 },
  proggy = { "ProggyClean", "fonts/ProggyClean.ttf", 400 },
  proggyTiny = { "ProggyTiny", "fonts/ProggyTiny.ttf", 400 },
}
local WEIGHTS = { [400] = "Regular", [500] = "Medium", [600] = "SemiBold", [700] = "Bold", [900] = "Heavy" }
local function builtin(name, weight, style)
  local ok, font = pcall(Font.fromName, name, weight or Enum.FontWeight.Regular, style or Enum.FontStyle.Normal)
  if ok and font then return font end
  return Font.fromEnum(Enum.Font.Gotham)
end
local FALLBACK = {
  text400 = function() return builtin("BuilderSans", Enum.FontWeight.Regular) end,
  text500 = function() return builtin("BuilderSans", Enum.FontWeight.Medium) end,
  text600 = function() return builtin("BuilderSans", Enum.FontWeight.SemiBold) end,
  text700 = function() return builtin("BuilderSans", Enum.FontWeight.Bold) end,
  mono400 = function() return builtin("RobotoMono", Enum.FontWeight.Regular) end,
  mono500 = function() return builtin("RobotoMono", Enum.FontWeight.Medium) end,
  serif = function() return builtin("Merriweather", Enum.FontWeight.Regular) end,
  serifItalic = function() return builtin("Merriweather", Enum.FontWeight.Regular, Enum.FontStyle.Italic) end,
  wideBold = function() return builtin("BuilderExtended", Enum.FontWeight.Bold) end,
  wideBlack = function() return builtin("BuilderExtended", Enum.FontWeight.Heavy) end,
  -- (without the files, the closest Roblox has: its own pixel font, and Arial)
  craft = function() return Font.fromEnum(Enum.Font.Arcade) end,
  proggy = function() return Font.fromEnum(Enum.Font.Code) end,
  proggyTiny = function() return Font.fromEnum(Enum.Font.Code) end,
}
B.F = {}

local function loadFonts()
  -- one family file per family, listing each face's registered .ttf
  local families = {}
  for key, spec in pairs(FONT_FILES) do
    local ttf = Assets.id(spec[2])
    if ttf then
      local family = families[spec[1]]
      if not family then family = { name = spec[1], faces = {}, keys = {} }; families[spec[1]] = family end
      family.faces[#family.faces + 1] = { name = WEIGHTS[spec[3]] or "Regular", weight = spec[3], style = "normal", assetId = ttf }
      family.keys[key] = spec[3]
    end
  end
  for name, family in pairs(families) do
    table.sort(family.faces, function(a, b) return a.weight < b.weight end)
    local relative = "fonts/" .. name .. ".json"
    local ok, json = pcall(S.HttpService.JSONEncode, S.HttpService, { name = name, faces = family.faces })
    if ok then
      local path = fs.path(relative)
      local changed = fs.read(path) ~= json
      if changed then fs.write(path, json) end
      -- the stamp is the json itself: a new prefix or face list re-registers the family file
      manifest.files[relative] = tostring(#json) .. ":" .. tostring(registry.prefix)
      if changed then ids[relative] = nil; registry.files[basename(relative)] = nil end
      local id = Assets.id(relative)
      if id then
        for key, weight in pairs(family.keys) do
          local okFont, font = pcall(Font.new, id, Enum.FontWeight[WEIGHTS[weight] or "Regular"], Enum.FontStyle.Normal)
          if okFont then B.F[key] = font end
        end
      end
    end
  end
  local missing = 0
  for key, make in pairs(FALLBACK) do
    if not B.F[key] then B.F[key] = make(); missing += 1 end
  end
  return missing
end

-- ---------------------------------------------------------------- icons, images, sounds
-- Icons live in one atlas (a single registration): returns image, offset, size.
function Assets.icon(name)
  local atlas = manifest.icons
  local index = atlas and atlas.map and atlas.map[name]
  if not index then return nil end
  local id = Assets.id(atlas.image)
  if not id then return nil end
  local cell = atlas.cell
  return id, Vector2.new((index % atlas.cols) * cell, math.floor(index / atlas.cols) * cell), Vector2.new(cell, cell)
end
-- Images are deployed under a content-hashed file name (a changed picture gets a
-- new id, so a cached texture can never be stale); manifest.img maps name -> file.
function Assets.image(name)
  local file = manifest.img and manifest.img[name]
  return file and Assets.id(file) or nil
end
function Assets.sound(name)
  local file = manifest.sfx and manifest.sfx[name]
  return file and Assets.id(file) or nil
end

-- ---------------------------------------------------------------- boot
function Assets.preload(list, timeout)
  local done = false
  task.spawn(function()
    pcall(function() S.ContentProvider:PreloadAsync(list) end)
    done = true
  end)
  local waited = 0
  while not done and waited < (timeout or 3) do waited += task.wait() end
  return done
end

function Assets.init()
  if not canRegister then
    Assets.lite = true
  else
    local saved = fs.readJson(REGISTRY)
    if type(saved) == "table" and type(saved.prefix) == "string" and type(saved.files) == "table" and type(saved.sentinel) == "string" then
      -- is the content folder we registered into still there?
      local status
      local finished = false
      task.spawn(function()
        pcall(function()
          S.ContentProvider:PreloadAsync({ saved.prefix .. saved.sentinel }, function(_, result) status = result end)
        end)
        finished = true
      end)
      local waited = 0
      while not finished and waited < 2 do waited += task.wait() end
      if status == Enum.AssetFetchStatus.Success then
        registry.prefix, registry.files, registry.sentinel = saved.prefix, saved.files, saved.sentinel
        for key, runs in pairs(type(saved.seq) == "table" and saved.seq or {}) do
          local known = {}
          for _, run in ipairs(runs) do
            for index = run[1], run[2] do known[index] = true end
          end
          seqKnown[key] = known
        end
      end
    end
    Assets.lite = not (manifest.icons and manifest.icons.image and Assets.id(manifest.icons.image))
  end
  Assets.fontsMissing = loadFonts()
  -- the hub's own letters, kept: Settings > Font swaps B.F, and Inter is these again
  B.F0 = table.clone(B.F)
  Assets.ready = true
  return not Assets.lite
end
function Assets.registry() return registry end
end
