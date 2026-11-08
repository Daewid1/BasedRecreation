do
local Config, Window, UI, Motion = B.Config, B.Window, B.UI, B.Motion
local Adapter = { Flags = {}, tabs = {} }
local Tab = {}
Tab.__index = Tab
B.HussUI = Adapter

-- Keep transport failures out of executable source and use Potassium's request API.
function B.httpGet(url)
	local response = request({ Url = url, Method = "GET" })
	assert(type(response) == "table" and tonumber(response.StatusCode) and response.StatusCode >= 200 and response.StatusCode < 300, "Download failed: " .. url)
	assert(type(response.Body) == "string", "Empty HTTP response")
	return response.Body
end

local function keyName(value)
	if typeof(value) == "EnumItem" then return value.Name == "Unknown" and "None" or value.Name end
	return type(value) == "string" and value or "None"
end

local function keyCode(value)
	if value == "None" then return Enum.KeyCode.Unknown end
	return Enum.KeyCode[value] or Enum.KeyCode.Unknown
end

local function normalize(kind, opts, value)
	if kind == "Toggle" then
		assert(type(value) == "boolean", "Expected a boolean")
	elseif kind == "Slider" then
		value = tonumber(value)
		assert(value and value == value and math.abs(value) < math.huge, "Expected a finite number")
		local step = opts.Increment or 1
		value = math.clamp(math.round((value - opts.Min) / step) * step + opts.Min, opts.Min, opts.Max)
	elseif kind == "Dropdown" then
		assert(table.find(opts.Options, value), "Unknown dropdown option")
	elseif kind == "Keybind" then
		value = keyName(value)
		assert(value == "None" or Enum.KeyCode[value], "Unknown key")
	end
	return value
end

function Tab:AddSection(title, desc)
	local section = { title = title, desc = desc, rows = {} }
	self.sections[#self.sections + 1] = section
	self.current = section
	self.childRows = nil
	return section
end

function Tab:AddDisclosure(title)
	local rows = {}
	self:queue("disclosure", { label = title, rows = rows, id = "app.huss.advanced." .. self.id })
	self.childRows = rows
end

function Tab:queue(kind, spec)
	if not self.current then self:AddSection(self.name) end
	local rows = self.childRows or self.current.rows
	rows[#rows + 1] = { kind = kind, spec = spec }
end

function Tab:control(kind, opts)
	local id = opts.Flag or (self.id .. "." .. tostring(#self.sections) .. "." .. opts.Text)
	local initial = normalize(kind, opts, opts.Default)
	local saved = Config.define(id, initial)
	local valid, value = pcall(normalize, kind, opts, saved)
	if not valid then value = initial; Config.set(id, value, true) end
	local entry = { Type = kind, Value = kind == "Keybind" and keyCode(value) or value }
	Adapter.Flags[id] = entry
	Config.on(id, function(nextValue, old)
		local ok, normalized = pcall(normalize, kind, opts, nextValue)
		if not ok then Config.set(id, old, true); return end
		entry.Value = kind == "Keybind" and keyCode(normalized) or normalized
		if opts.Callback then
			local success, accepted = pcall(opts.Callback, entry.Value)
			if not success or accepted == false then
				Config.set(id, old, true)
				if not success then B.fault("huss." .. id, accepted) end
			end
		end
	end)
	entry.Set = function(nextValue)
		local normalized = normalize(kind, opts, nextValue)
		Config.set(id, normalized)
	end
	if opts.Callback then B.try("huss.init." .. id, opts.Callback, entry.Value) end
	local spec = { id = id, label = opts.Text, desc = opts.Description, tip = opts.Description,
		default = initial, min = opts.Min, max = opts.Max, step = opts.Increment,
		options = opts.Options, bindable = not opts.NoList and opts.Bind ~= false }
	if kind == "Keybind" and opts.Pressed then
		local target = id == "autoDodgeKey" and "autoDodge" or "huss.action." .. id
		if id ~= "autoDodgeKey" then
			Config.action(target, opts.Pressed)
			B.Controls.bindables[target] = { label = opts.Text, kind = "button", page = self.page }
		end
		local function bind(nextValue)
			Config.bind(target, nextValue ~= "None" and nextValue or nil)
		end
		Config.on(id, bind)
		local existing = Config.bindOf(target)
		if existing then
			Config.set(id, existing.key, true)
		else
			bind(value)
		end
		Config.bindsChanged:connect(function()
			local current = Config.bindOf(target)
			local nextValue = current and current.key or "None"
			if Config.get(id) ~= nextValue then Config.set(id, nextValue, true) end
		end)
	end
	self:queue(string.lower(kind), spec)
	return entry
end

function Tab:AddToggle(opts) return self:control("Toggle", opts) end
function Tab:AddSlider(opts) return self:control("Slider", opts) end
function Tab:AddDropdown(opts) return self:control("Dropdown", opts) end
function Tab:AddKeybind(opts) return self:control("Keybind", opts) end

function Tab:AddButton(opts)
	self:queue("button", { label = opts.Text, text = opts.ButtonText or "Run", run = opts.Callback, bindable = false })
end

function Tab:AddLabel(text)
	local spec = { text = text }
	local api
	self:queue("label", { build = function(section)
		api = section:note(spec)
	end })
	return { SetText = function(_, value)
		spec.text = tostring(value)
		if api then api.set(spec.text) end
	end }
end

function Tab:AddStatRow(specs)
	for _, item in ipairs(specs) do
		local api = self:AddLabel(item.Title .. ": —")
		Motion.every(function()
			local value, _, detail = item.Get()
			api:SetText(item.Title .. ": " .. tostring(value) .. (detail and detail ~= "" and (" · " .. tostring(detail)) or ""))
		end, 2, "huss.stat." .. item.Title)
	end
end

function Adapter:CreateCategory(name) self.category = name end

local function buildRows(section, rows)
	for _, row in ipairs(rows) do
		if row.kind == "label" then
			row.spec.build(section)
		elseif row.kind == "disclosure" then
			local api
			api = section:toggle({ id = row.spec.id, label = row.spec.label, default = false, bindable = false,
				children = function(inner) buildRows(inner, row.spec.rows) end,
				changed = function(value) if api and api.open then api.open(value) end end })
			if api.open and Config.get(row.spec.id) then api.open(true) end
		else
			section[row.kind](section, row.spec)
		end
	end
end

function Adapter:CreateTab(name, icon, subtitle)
	local id = "huss." .. string.lower(name)
	local tab = setmetatable({ id = id, name = name, sections = {} }, Tab)
	tab.page = Window.page({ id = id, title = name, icon = icon, group = self.category or "Huss Valley", order = 100 + #self.tabs,
		eyebrow = subtitle, build = function(page)
			for _, group in ipairs(tab.sections) do
				local section = page:section({ title = group.title, desc = group.desc, full = group.title == "Immortal" })
				buildRows(section, group.rows)
			end
		end })
	self.tabs[#self.tabs + 1] = tab
	return tab
end

function Adapter:Notify(opts)
	Window.toast({ title = opts.Title, text = opts.Text, time = opts.Duration, icon = "sprout" })
end

function Adapter:StyleButton(button, color)
	local base = color or B.T.surface
	UI.wire(button, {
		hover = function(on)
			Motion.to(button, "BackgroundColor3", on and B.T.accent or base, "quick")
			if on then UI.sfx("hover", 0.2) end
		end,
		click = function() UI.sfx("click", 0.5) end,
	})
	return { set = function(_, nextColor) base = nextColor; Motion.to(button, "BackgroundColor3", base, "quick") end }
end

function Adapter:CreatePanel(opts)
	local gui = B.screen(9055)
	gui.Name, gui.Enabled = opts.Name, false
	local root = UI.frame(gui, { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(opts.Width, opts.Height) })
	local sizer = Instance.new("UIScale")
	sizer.Parent = root
	local glass = UI.glass(root, { level = "window", radius = "rWindow", shadow = 36, props = { Size = UDim2.fromScale(1, 1) } })
	local header = UI.frame(glass, { Size = UDim2.new(1, 0, 0, 72) })
	UI.text(header, opts.Title, "title", "ink", { Position = UDim2.fromOffset(22, 20), Size = UDim2.new(1, -90, 0, 32), AutomaticSize = Enum.AutomaticSize.None })
	local body = UI.frame(glass, { Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 1, -98), ClipsDescendants = true })
	local panel = { gui = gui, root = root, body = body, visible = false, revision = 0 }
	function panel:Refit()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		root.Size = UDim2.fromOffset(math.max(1, math.min(opts.Width, viewport.X - 24)), math.max(1, math.min(opts.Height, viewport.Y - 24)))
	end
	function panel:Show()
		self.visible = true
		self.revision += 1
		self:Refit()
		gui.Enabled = true
		sizer.Scale = 0.96
		Motion.to(sizer, "Scale", 1, "bouncy")
	end
	function panel:Hide()
		self.visible = false
		self.revision += 1
		local revision = self.revision
		Motion.to(sizer, "Scale", 0.96, "quick")
		task.delay(0.2, function() if self.revision == revision and gui.Parent then gui.Enabled = false end end)
	end
	function panel:Toggle() if self.visible then self:Hide() else self:Show() end end
	UI.button(header, { click = function() panel:Hide() end }, { Text = "×", TextSize = 24, TextColor3 = B.T.sub, BackgroundTransparency = 1, Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -54, 0, 18) })
	local origin
	UI.drag(header, function() origin = root.Position end, function(_, delta)
		root.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
	end)
	B.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function() panel:Refit() end, "huss.panel.viewport")
	panel:Refit()
	return panel
end

function Adapter:CreateWindow(opts)
	self.onDestroy = opts.OnDestroy
	Config.init()
	B.Assets.init()
	B.Prefs.define()
	B.Prefs.apply()
	B.Unnamed.start()
	B.Novoline.start()
	Window.build()
	B.game({ id = "huss", name = "Huss Valley", icon = "sprout", places = { 107535308163741 }, universal = false, tabs = function() end })
	B.Registry.pick()
	for _, register in ipairs(B.pages) do B.try("pages", register) end
	Window.startPage = "home"
	B.onUnload:connect(function()
		if self.onDestroy then self.onDestroy() end
	end)
	return self
end

function Adapter:Start()
	Window.rebuildNav()
	Config.listen()
	B.HussServer = {
		rejoin = function() B.S.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, B.LP) end,
		hop = function() Window.go("huss.servers"); Window.showActive(true) end,
	}
	B.connect(B.S.UserInputService.InputBegan, function(input)
		if Config.capturing or B.S.UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local name = input.KeyCode.Name
		if name == Config.get("app.key.menu") then
			if not B.Loader.active then Window.toggleActive() end
		elseif name == Config.get("app.key.panic") then
			B.unload()
		elseif input.KeyCode == Enum.KeyCode.K and (B.S.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or B.S.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			Window.palette()
		end
	end, "huss.keys")
	local function reveal()
		Window.showActive(true)
		B.Hud.start()
		B.Unnamed.watermark()
		if B.Novoline.active() then B.Novoline.island() end
		B.Keys.hud()
	end
	local function begin()
		if Config.firstRun and B.genv.HUSS_BASED_INTRO ~= "off" and not B.genv.HUSS_BASED_NO_PICKER then
			B.Picker.show(function(look)
				if look then Config.set("app.gui", look) end
				B.try("huss.reveal", reveal)
			end)
		else
			reveal()
		end
	end
	task.delay(0.7, function() if B.alive then Window.prebuild() end end)
	B.Loader.run(begin)
	B.bootMs = math.floor((os.clock() - B.bootClock) * 1000)
end

function Adapter:Destroy() B.unload() end
end

