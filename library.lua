local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")

local Nexo = {}
Nexo.__index = Nexo

local DefaultTheme = {
    Accent = Color3.fromRGB(29, 132, 144),
    WindowBackground = Color3.fromRGB(24, 42, 47),
    TabBackground = Color3.fromRGB(25, 45, 50),
    CategoryBackground = Color3.fromRGB(35, 63, 70),
    CategoryTopBar = Color3.fromRGB(43, 77, 86),
    NavigationBackground = Color3.fromRGB(24, 42, 47),
    NavButtonBackground = Color3.fromRGB(36, 65, 70),
    Stroke = Color3.fromRGB(255, 255, 255),
    MainStroke = Color3.fromRGB(170, 170, 170),
    TitleText = Color3.fromRGB(230, 230, 255),
    PrimaryText = Color3.fromRGB(254, 254, 254),
    SecondaryText = Color3.fromRGB(180, 180, 180),
    NavText = Color3.fromRGB(210, 210, 210),
    ToggleKnob = Color3.fromRGB(190, 190, 190),
    ToggleKnobActive = Color3.fromRGB(235, 235, 235),
    ToggleActive = Color3.fromRGB(59, 108, 120),
    GradientTop = Color3.fromRGB(31, 54, 60),
    GradientBottom = Color3.fromRGB(20, 35, 38),
    SliderFill = Color3.fromRGB(75, 137, 148),
    SliderEmpty = Color3.fromRGB(34, 62, 67),
    HolderColor = Color3.fromRGB(255, 255, 255),
    HolderTransparency = 0.8,
    HoverColor = Color3.fromRGB(255, 255, 255),
    HoverTransparency = 0.91,
    PickerBackground = Color3.fromRGB(32, 55, 61),
}

-- tweens
local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MEDIUM = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- safely creates an instance and applies props, tolerating unsupported properties
local function Create(className: string, props: {[string]: any}?): Instance
	local instance = Instance.new(className)

	if props then
		local parent = props.Parent

		for property, value in pairs(props) do
			if property ~= "Parent" then
				local success, err = pcall(function()
					(instance :: any)[property] = value
				end)

				if not success then
					warn(string.format(
						"[Nexo] %s.%s couldn't apply: %s",
						className,
						property,
						tostring(err)
						))
				end
			end
		end

		if parent ~= nil then
			instance.Parent = parent
		end
	end

	if instance:IsA("GuiButton") then
		instance.AutoButtonColor = false
		instance.Selectable = false
	end

	return instance
end

-- 4 corner radius
local function ApplyCorner(parent: Instance, radius: number, tl: number?, tr: number?, br: number?, bl: number?)
	local corner = Create("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
	pcall(function()
		local c = corner :: any
		c.TopLeftRadius = UDim.new(0, tl or radius)
		c.TopRightRadius = UDim.new(0, tr or radius)
		c.BottomRightRadius = UDim.new(0, br or radius)
		c.BottomLeftRadius = UDim.new(0, bl or radius)
	end)
	return corner
end

-- creates a standard ubuntu/highway style font face
local function MakeFont(family: string, weight: Enum.FontWeight?, style: Enum.FontStyle?): Font
	return Font.new(
		"rbxasset://fonts/families/" .. family .. ".json",
		weight or Enum.FontWeight.Regular,
		style or Enum.FontStyle.Normal
	)
end

-- resolves the lucide module, preferring workspace then falling back gracefully
local Lucide: any = nil
local function LoadLucide()
    if Lucide ~= nil then return Lucide end

    if RunService:IsStudio() then
        local module = Workspace:FindFirstChild("LucideRoblox")
        if module then
            local ok, result = pcall(require, module)
            if ok and type(result) == "table" then
                Lucide = result
                return Lucide
            end
        end
    else
        local ok, chunk = pcall(function()
            return loadstring(game:HttpGet('https://raw.githubusercontent.com/yriri842/UILibrary/refs/heads/main/lucide.lua'))
        end)
        if ok and chunk then
            local ok2, result = pcall(chunk)
            if ok2 and type(result) == "table" then
                Lucide = result
                return Lucide
            end
        end
    end

    Lucide = false
    return Lucide
end

-- turns an icon parameter (name / number / rbxassetid) into an image string
local function ResolveIcon(icon: (string | number)?): string
	if icon == nil then
		return ""
	end

	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end

	if type(icon) == "string" then
		if string.match(icon, "^rbxassetid://") then
			return icon
		end
		if string.match(icon, "^%d+$") then
			return "rbxassetid://" .. icon
		end

		-- treat it as a lucide icon name
		local lib = LoadLucide()
		if lib then
			local ok, asset = pcall(function()
				return lib.GetAsset(icon, 256)
			end)
			if ok and asset and asset.Url then
				return asset.Url
			end
		end
	end

	return ""
end

local function GetGuiParent(): Instance
    local ok, hui = pcall(function()
        return gethui()
    end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end

    local player = Players.LocalPlayer
    if player then
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if pg then
            return pg
        end
        return player:WaitForChild("PlayerGui")
    end

    return game:GetService("CoreGui")
end

-- ========================================================================
-- category (skeleton for now, components come in later parts)
-- ========================================================================

local Category = {}
Category.__index = Category

function Category:_register(api: any)
	self._components = self._components or {}

	api._category = self
	api._window = self._window
	api._userVisible = api._holder == nil or api._holder.Visible

	-- SetVisible durumunu search temizlenince kaybetme.
	local originalSetVisible = api.SetVisible
	if originalSetVisible then
		api.SetVisible = function(object: any, visible: boolean)
			api._userVisible = visible
			originalSetVisible(object, visible)

			if self._window._runSearch then
				self._window:_runSearch()
			end
		end
	end

	-- Runtime'da başlık değişirse search metadata da değişsin.
	local originalSetTitle = api.SetTitle
	if originalSetTitle then
		api.SetTitle = function(object: any, text: string)
			api._searchTitle = text
			originalSetTitle(object, text)

			if self._window._runSearch then
				self._window:_runSearch()
			end
		end
	end

	local originalSetDescription = api.SetDescription
	if originalSetDescription then
		api.SetDescription = function(object: any, text: string)
			api._searchDescription = text
			originalSetDescription(object, text)

			if self._window._runSearch then
				self._window:_runSearch()
			end
		end
	end

	local originalDestroy = api.Destroy
	if originalDestroy then
		api.Destroy = function(object: any)
			for index, component in ipairs(self._components) do
				if component == api then
					table.remove(self._components, index)
					break
				end
			end

			originalDestroy(object)

			if self._window._runSearch then
				self._window:_runSearch()
			end
		end
	end

	table.insert(self._components, api)

	task.defer(function()
		if self._window and self._window._runSearch then
			if self._window._searchInput
				and self._window._searchInput.Text ~= "" then
				self._window:_runSearch()
			end
		end
	end)

	return api
end

function Category:_recalcHeight()
    if self._collapsed or not self._visible then
        return
    end

    local contentHeight = self.ListLayout.AbsoluteContentSize.Y
    local targetHeight = 39 + contentHeight

    if self._heightTween then
        self._heightTween:Cancel()
        self._heightTween = nil
    end

    self._heightTween = TweenService:Create(self.Root, FAST, {
        Size = UDim2.new(1, 0, 0, targetHeight),
    })
    self._heightTween:Play()
end

function Category:SetTitle(text: string)
	self.Title.Text = text
end

function Category:SetIcon(icon: (string | number)?)
	self.Icon.Image = ResolveIcon(icon)
end

function Category:SetVisible(visible: boolean)
	self._visible = visible
	self.Root.Visible = visible
end

function Category:SetCollapsed(collapsed: boolean, animate: boolean?)
	self._collapsed = collapsed

	local newImage = collapsed and ResolveIcon(10734924532) or ResolveIcon(10734896206)

	if animate == false then
		self.CollapseBtn.Image = newImage
		self.CollapseBtn.ImageTransparency = 0
	else
		-- token guards against overlapping fades from rapid clicks
		self._collapseToken = (self._collapseToken or 0) + 1
		local myToken = self._collapseToken

		local fadeOut = TweenService:Create(self.CollapseBtn, FAST, { ImageTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Once(function()
			-- only the latest click gets to swap and fade back in
			if myToken ~= self._collapseToken then
				return
			end
			self.CollapseBtn.Image = newImage
			TweenService:Create(self.CollapseBtn, FAST, { ImageTransparency = 0 }):Play()
		end)
	end

	if collapsed then
		self.LockFrame.Visible = false
		TweenService:Create(self.Root, MEDIUM, { Size = UDim2.new(1, 0, 0, 25) }):Play()
	else
		if self._locked then
			self.LockFrame.Visible = true
		end
		self:_recalcHeight()
	end
end

function Category:SetLocked(locked: boolean)
    self._locked = locked
    local theme = self._window._theme

    if locked then
        if not self._collapsed then
            self.LockFrame.Visible = true
        end
        TweenService:Create(self.LockFrame, MEDIUM, { BackgroundTransparency = 0.35 }):Play()
        TweenService:Create(self.LockIcon, MEDIUM, { ImageTransparency = 0.6 }):Play()
        TweenService:Create(self.LockToggle, MEDIUM, {
            BackgroundTransparency = 0,
            BackgroundColor3 = theme.ToggleActive,
        }):Play()
        TweenService:Create(self.LockKnob, MEDIUM, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = theme.ToggleKnobActive,
        }):Play()
        self.ContainerScroll.ScrollingEnabled = false
    else
        TweenService:Create(self.LockFrame, MEDIUM, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(self.LockIcon, MEDIUM, { ImageTransparency = 1 }):Play()
        TweenService:Create(self.LockToggle, MEDIUM, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(self.LockKnob, MEDIUM, {
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = theme.ToggleKnob,
        }):Play()
        task.delay(0.25, function()
            if not self._locked then
                self.LockFrame.Visible = false
            end
        end)
        self.ContainerScroll.ScrollingEnabled = true
    end
end

function Category:Destroy()
	self.Root:Destroy()
end

-- ========================================================================
-- tab
-- ========================================================================

local Tab = {}
Tab.__index = Tab

function Tab:AddCategory(config: {
	Title: string?,
	Icon: (string | number)?,
	Side: string?,
	Collapsed: boolean?,
	Locked: boolean?,
	})
	local theme = self._window._theme
	local side = config.Side == "Right" and self.Section2 or self.Section1

	local self_cat = setmetatable({}, Category)
	self_cat._window = self._window
	self_cat._collapsed = false
	self_cat._locked = false
	self_cat._visible = true
	self_cat._components = {}

	local root = Create("Frame", {
		Name = "Category",
		BackgroundColor3 = theme.CategoryBackground,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 60),
		Parent = side,
	})
	ApplyCorner(root, 3, 3, 3, 4, 4)
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.95, Parent = root })

	local topBar = Create("Frame", {
		Name = "TopBar",
		BackgroundColor3 = theme.CategoryTopBar,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 25),
		Parent = root,
	})
	ApplyCorner(topBar, 3, 3, 3, 0, 0)
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.95, Parent = topBar })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		Parent = topBar,
	})

	local icon = Create("ImageLabel", {
		Name = "CategoryIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Image = ResolveIcon(config.Icon or 10747373176),
		Parent = topBar,
	})

	local title = Create("TextLabel", {
		Name = "CategoryTitle",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.new(1, -104, 1, 0),
		Font = Enum.Font.Ubuntu,
		Text = config.Title or "Category",
		TextColor3 = theme.TitleText,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		Parent = topBar,
	})
	Create("UIPadding", { PaddingBottom = UDim.new(0, 4), Parent = title })

	-- lock toggle
	local lockHolder = Create("Frame", {
		Name = "LockToggleHolder",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -25, 0, 0),
		Size = UDim2.new(0, 50, 1, 0),
		Parent = topBar,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		Parent = lockHolder,
	})

	local lockToggle = Create("Frame", {
		Name = "Toggle",
		BackgroundColor3 = theme.ToggleActive,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = lockHolder,
	})
	ApplyCorner(lockToggle, 999)
	local lockStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = lockToggle })
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		Parent = lockToggle,
	})

	local lockKnob = Create("Frame", {
		Name = "Knob",
		BackgroundColor3 = theme.ToggleKnob,
		BorderSizePixel = 0,
		Size = UDim2.new(0.45, 0, 1, 0),
		Parent = lockToggle,
	})
	ApplyCorner(lockKnob, 999)
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = lockKnob })

	local lockButton = Create("TextButton", {
		Name = "Button",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = lockToggle,
	})

	-- collapse button
	local collapseBtn = Create("ImageButton", {
		Name = "CollapseCategory",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(21, 21),
		Image = ResolveIcon(10734896206),
		Parent = topBar,
	})

	-- container holder + lock overlay
	local containerHolder = Create("Frame", {
		Name = "ContainerHolder",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	Create("UIPadding", { PaddingTop = UDim.new(0, 27), Parent = containerHolder })

	local lockFrame = Create("Frame", {
		Name = "LockFrame",
		BackgroundColor3 = Color3.fromRGB(21, 21, 21),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 999,
		Parent = containerHolder,
	})
	ApplyCorner(lockFrame, 0, 0, 0, 4, 4)

	local lockIcon = Create("ImageLabel", {
		Name = "LockIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(50, 50),
		Image = ResolveIcon(10723434711),
		ImageTransparency = 1,
		ZIndex = 999,
		Parent = lockFrame,
	})
	
	local lockButtonOverlay = Create("TextButton", {
		Name = "Lock",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 999,
		Parent = lockFrame,
	})

	local containerInner = Create("Frame", {
		Name = "Container",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = containerHolder,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = containerInner,
	})

	local scroll = Create("ScrollingFrame", {
		Name = "ContainerScroll",
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = containerInner,
	})
	local listLayout = Create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 5),
		PaddingRight = UDim.new(0, 5),
		Parent = scroll,
	})

	-- wire references
	self_cat.Root = root
	self_cat.Title = title
	self_cat.Icon = icon
	self_cat.CollapseBtn = collapseBtn
	self_cat.LockFrame = lockFrame
	self_cat.LockIcon = lockIcon
	self_cat.LockToggle = lockToggle
	self_cat.LockKnob = lockKnob
	self_cat.ContainerScroll = scroll
	self_cat.ListLayout = listLayout
	self._window:_track(root, "BackgroundColor3", "CategoryBackground")
	self._window:_track(topBar, "BackgroundColor3", "CategoryTopBar")
	self._window:_track(title, "TextColor3", "TitleText")
	self._window:_track(lockToggle, "BackgroundColor3", "ToggleActive")
	self._window:_track(lockKnob, "BackgroundColor3", "ToggleKnob")
	

	-- collapse interactions
	collapseBtn.MouseEnter:Connect(function()
		TweenService:Create(collapseBtn, FAST, { ImageTransparency = 0.4 }):Play()
	end)
	collapseBtn.MouseLeave:Connect(function()
		TweenService:Create(collapseBtn, FAST, { ImageTransparency = 0 }):Play()
	end)
	collapseBtn.MouseButton1Click:Connect(function()
		self_cat:SetCollapsed(not self_cat._collapsed)
	end)

	-- lock interactions
	lockToggle.MouseEnter:Connect(function()
		TweenService:Create(lockStroke, FAST, { Transparency = 0.8 }):Play()
	end)
	lockToggle.MouseLeave:Connect(function()
		TweenService:Create(lockStroke, FAST, { Transparency = 0.93 }):Play()
	end)
	lockButton.MouseButton1Click:Connect(function()
		self_cat:SetLocked(not self_cat._locked)
	end)

	-- keep height in sync as components get added later
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self_cat:_recalcHeight()
	end)

	self_cat:SetCollapsed(config.Collapsed or false, false)
	self_cat:SetLocked(config.Locked or false)

	table.insert(self._categories, self_cat)
	return self_cat
end

-- ========================================================================
-- window
-- ========================================================================

local Window = {}
Window.__index = Window

local function NormalizeSearchText(value: any): string
	local text = tostring(value or "")

	-- Basit RichText tag temizliği.
	text = string.gsub(text, "<[^>]->", "")
	return string.lower(text)
end

function Window:_getSearchTarget()
	if self._settingsOpen then
		return self._settingsTab
	end

	return self._activeTab
end

function Window:_runSearch()
	if not self._searchInput then
		return
	end

	local targetTab = self:_getSearchTarget()
	if not targetTab then
		return
	end

	local query = NormalizeSearchText(self._searchInput.Text)
	if query == "" then
		for _, category in ipairs(targetTab._categories or {}) do
			category.Root.Visible = category._visible

			for _, component in ipairs(category._components or {}) do
				if component._holder and component._holder.Parent then
					component._holder.Visible = component._userVisible ~= false
				end
			end

			if category.Root.Visible and not category._collapsed then
				category:_recalcHeight()
			end
		end
		return
	end
	for _, category in ipairs(targetTab._categories or {}) do
		local categoryTitle = NormalizeSearchText(category.Title and category.Title.Text)
		local categoryMatched = string.find(categoryTitle, query, 1, true) ~= nil

		local anyVisible = false

		for _, component in ipairs(category._components or {}) do
			local holder = component._holder

			if holder and holder.Parent then
				local title = NormalizeSearchText(component._searchTitle)
				local description = NormalizeSearchText(component._searchDescription)

				local matched = categoryMatched
					or string.find(title, query, 1, true) ~= nil
					or string.find(description, query, 1, true) ~= nil

				local userVisible = component._userVisible ~= false
				local finalVisible = userVisible and matched

				holder.Visible = finalVisible

				if finalVisible then
					anyVisible = true
				end
			end
		end

		category.Root.Visible = category._visible and (categoryMatched or anyVisible)

		if category.Root.Visible and not category._collapsed then
			category:_recalcHeight()
		end
	end
end

function Window:_track(
	instance: Instance,
	property: string,
	themeKey: string
)
	self._themed = self._themed or {}

	table.insert(self._themed, {
		inst = instance,
		prop = property,
		key = themeKey,
	})

	return instance
end

function Window:_trackGradient(
	gradient: UIGradient,
	firstKey: string,
	secondKey: string
)
	self._themed = self._themed or {}

	table.insert(self._themed, {
		inst = gradient,
		gradientKeys = { firstKey, secondKey },
	})

	return gradient
end

-- re-applies every tracked theme color across the ui
function Window:ApplyTheme()
	if not self._themed then
		return
	end

	local validEntries = {}

	for _, entry in ipairs(self._themed) do
		local instance = entry.inst

		if instance and instance.Parent then
			local success, err = pcall(function()
				if entry.gradientKeys then
					local first = self._theme[entry.gradientKeys[1]]
					local second = self._theme[entry.gradientKeys[2]]

					if typeof(first) == "Color3"
						and typeof(second) == "Color3" then
						(instance :: UIGradient).Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, first),
							ColorSequenceKeypoint.new(1, second),
						})
					end
				else
					local value = self._theme[entry.key]

					if value ~= nil then
						(instance :: any)[entry.prop] = value
					end
				end
			end)

			if not success then
				warn("[Nexo] Theme apply error:", err)
			end

			table.insert(validEntries, entry)
		end
	end

	-- Destroy edilmiş instance kayıtlarını temizle.
	self._themed = validEntries
end

function Window:SetAccent(color: Color3)
    self._theme.Accent = color

    if self._tooltipStroke then
        self._tooltipStroke.Color = color
    end

    local bgHolder = self.Main:FindFirstChild("BackgroundGradientHolder")
    if bgHolder then
        local grad = bgHolder:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new(color)
        end
    end

    self._accentObjects = self._accentObjects or {}
    local validEntries = {}

    for _, entry in ipairs(self._accentObjects) do
        if entry.inst and entry.inst.Parent then
            pcall(entry.apply, color)
            table.insert(validEntries, entry)
        end
    end

    self._accentObjects = validEntries

    self:ApplyTheme()
    self:_updateNav()
end

function Window:_trackAccent(inst: Instance, apply: (color: Color3) -> ())
	self._accentObjects = self._accentObjects or {}
	table.insert(self._accentObjects, { inst = inst, apply = apply })
	pcall(apply, self._theme.Accent)
	return inst
end

local ThemePresets = {
    Default = {
        Accent = Color3.fromRGB(29, 132, 144),
        WindowBackground = Color3.fromRGB(24, 42, 47),
        TabBackground = Color3.fromRGB(25, 45, 50),
        CategoryBackground = Color3.fromRGB(35, 63, 70),
        CategoryTopBar = Color3.fromRGB(43, 77, 86),
        NavigationBackground = Color3.fromRGB(24, 42, 47),
        NavButtonBackground = Color3.fromRGB(36, 65, 70),
        Stroke = Color3.fromRGB(255, 255, 255),
        MainStroke = Color3.fromRGB(170, 170, 170),
        TitleText = Color3.fromRGB(230, 230, 255),
        PrimaryText = Color3.fromRGB(254, 254, 254),
        SecondaryText = Color3.fromRGB(180, 180, 180),
        NavText = Color3.fromRGB(210, 210, 210),
        ToggleKnob = Color3.fromRGB(190, 190, 190),
        ToggleKnobActive = Color3.fromRGB(235, 235, 235),
        ToggleActive = Color3.fromRGB(59, 108, 120),
        GradientTop = Color3.fromRGB(31, 54, 60),
        GradientBottom = Color3.fromRGB(20, 35, 38),
        SliderFill = Color3.fromRGB(75, 137, 148),
        SliderEmpty = Color3.fromRGB(34, 62, 67),
        HolderColor = Color3.fromRGB(255, 255, 255),
        HolderTransparency = 0.8,
        HoverColor = Color3.fromRGB(255, 255, 255),
        HoverTransparency = 0.91,
        PickerBackground = Color3.fromRGB(32, 55, 61),
    },

    Dark = {
        Accent = Color3.fromRGB(98, 114, 164),
        WindowBackground = Color3.fromRGB(24, 24, 28),
        TabBackground = Color3.fromRGB(28, 28, 33),
        CategoryBackground = Color3.fromRGB(38, 38, 44),
        CategoryTopBar = Color3.fromRGB(46, 46, 54),
        NavigationBackground = Color3.fromRGB(24, 24, 28),
        NavButtonBackground = Color3.fromRGB(40, 40, 47),
        Stroke = Color3.fromRGB(255, 255, 255),
        MainStroke = Color3.fromRGB(150, 150, 155),
        TitleText = Color3.fromRGB(235, 235, 245),
        PrimaryText = Color3.fromRGB(250, 250, 250),
        SecondaryText = Color3.fromRGB(170, 170, 178),
        NavText = Color3.fromRGB(205, 205, 212),
        ToggleKnob = Color3.fromRGB(185, 185, 190),
        ToggleKnobActive = Color3.fromRGB(240, 240, 245),
        ToggleActive = Color3.fromRGB(88, 102, 148),
        GradientTop = Color3.fromRGB(34, 34, 40),
        GradientBottom = Color3.fromRGB(22, 22, 26),
        SliderFill = Color3.fromRGB(98, 114, 164),
        SliderEmpty = Color3.fromRGB(32, 32, 38),
        HolderColor = Color3.fromRGB(255, 255, 255),
        HolderTransparency = 0.82,
        HoverColor = Color3.fromRGB(255, 255, 255),
        HoverTransparency = 0.91,
        PickerBackground = Color3.fromRGB(32, 32, 38),
    },

    Light = {
        Accent = Color3.fromRGB(60, 145, 165),
        WindowBackground = Color3.fromRGB(235, 238, 242),
        TabBackground = Color3.fromRGB(222, 227, 233),
        CategoryBackground = Color3.fromRGB(210, 216, 222),
        CategoryTopBar = Color3.fromRGB(195, 202, 210),
        NavigationBackground = Color3.fromRGB(225, 230, 235),
        NavButtonBackground = Color3.fromRGB(200, 207, 215),
        Stroke = Color3.fromRGB(120, 120, 130),
        MainStroke = Color3.fromRGB(90, 90, 100),
        TitleText = Color3.fromRGB(30, 30, 60),
        PrimaryText = Color3.fromRGB(20, 20, 30),
        SecondaryText = Color3.fromRGB(70, 70, 80),
        NavText = Color3.fromRGB(40, 40, 55),
        ToggleKnob = Color3.fromRGB(110, 110, 120),
        ToggleKnobActive = Color3.fromRGB(250, 250, 252),
        ToggleActive = Color3.fromRGB(60, 145, 165),
        GradientTop = Color3.fromRGB(225, 230, 235),
        GradientBottom = Color3.fromRGB(205, 212, 220),
        SliderFill = Color3.fromRGB(80, 150, 165),
        SliderEmpty = Color3.fromRGB(188, 195, 203),
        HolderColor = Color3.fromRGB(160, 168, 178),
        HolderTransparency = 0.55,
        HoverColor = Color3.fromRGB(25, 25, 35), 
        HoverTransparency = 0.92,
        PickerBackground = Color3.fromRGB(215, 220, 228),
    },

    Midnight = {
        Accent = Color3.fromRGB(124, 108, 255),
        WindowBackground = Color3.fromRGB(16, 18, 32),
        TabBackground = Color3.fromRGB(19, 22, 38),
        CategoryBackground = Color3.fromRGB(28, 31, 52),
        CategoryTopBar = Color3.fromRGB(35, 39, 64),
        NavigationBackground = Color3.fromRGB(16, 18, 32),
        NavButtonBackground = Color3.fromRGB(30, 33, 56),
        Stroke = Color3.fromRGB(255, 255, 255),
        MainStroke = Color3.fromRGB(150, 145, 190),
        TitleText = Color3.fromRGB(230, 228, 255),
        PrimaryText = Color3.fromRGB(248, 246, 255),
        SecondaryText = Color3.fromRGB(168, 165, 200),
        NavText = Color3.fromRGB(205, 202, 235),
        ToggleKnob = Color3.fromRGB(180, 178, 210),
        ToggleKnobActive = Color3.fromRGB(240, 238, 255),
        ToggleActive = Color3.fromRGB(98, 86, 200),
        GradientTop = Color3.fromRGB(26, 29, 48),
        GradientBottom = Color3.fromRGB(15, 17, 28),
        SliderFill = Color3.fromRGB(110, 96, 220),
        SliderEmpty = Color3.fromRGB(24, 26, 44),
        HolderColor = Color3.fromRGB(255, 255, 255),
        HolderTransparency = 0.82,
        HoverColor = Color3.fromRGB(255, 255, 255),
        HoverTransparency = 0.91,
        PickerBackground = Color3.fromRGB(24, 26, 44),
    },

    Amoled = {
        Accent = Color3.fromRGB(0, 220, 150),
        WindowBackground = Color3.fromRGB(10, 10, 10),
        TabBackground = Color3.fromRGB(14, 14, 14),
        CategoryBackground = Color3.fromRGB(20, 20, 20),
        CategoryTopBar = Color3.fromRGB(26, 26, 26),
        NavigationBackground = Color3.fromRGB(10, 10, 10),
        NavButtonBackground = Color3.fromRGB(24, 24, 24),
        Stroke = Color3.fromRGB(255, 255, 255),
        MainStroke = Color3.fromRGB(120, 120, 120),
        TitleText = Color3.fromRGB(240, 240, 240),
        PrimaryText = Color3.fromRGB(252, 252, 252),
        SecondaryText = Color3.fromRGB(160, 160, 160),
        NavText = Color3.fromRGB(200, 200, 200),
        ToggleKnob = Color3.fromRGB(180, 180, 180),
        ToggleKnobActive = Color3.fromRGB(240, 240, 240),
        ToggleActive = Color3.fromRGB(0, 140, 110),
        GradientTop = Color3.fromRGB(18, 18, 18),
        GradientBottom = Color3.fromRGB(8, 8, 8),
        SliderFill = Color3.fromRGB(0, 160, 120),
        SliderEmpty = Color3.fromRGB(18, 18, 18),
        HolderColor = Color3.fromRGB(255, 255, 255),
        HolderTransparency = 0.85,
        HoverColor = Color3.fromRGB(255, 255, 255),
        HoverTransparency = 0.9,
        PickerBackground = Color3.fromRGB(16, 16, 16),
    },
}

function Window:SetThemePreset(presetName: string)
    local preset = ThemePresets[presetName]
    if not preset then
        warn("[Nexo] unknown theme preset:", presetName)
        return
    end

    for key, value in pairs(preset) do
        self._theme[key] = value
    end

    for key, value in pairs(DefaultTheme) do
        if self._theme[key] == nil then
            self._theme[key] = value
        end
    end

    if preset.Accent then
        self:SetAccent(preset.Accent)
    else
        self:ApplyTheme()
        self:_updateNav()
    end
end

-- lets the user set individual theme keys at runtime
function Window:SetThemeColor(key: string, color: Color3)
	self._theme[key] = color
	if key == "Accent" then
		self:SetAccent(color)
	else
		self:ApplyTheme()
	end
end

function Window:_updateNav()
	local accent = self._theme.Accent
    local h, s, v = accent:ToHSV()
	local inactiveColor = ColorSequence.new(
        Color3.fromHSV(h, s * 0.5, math.clamp(v * 0.75, 0, 1)),
        Color3.new(1, 1, 1)
    )
    local hoverColor = ColorSequence.new(
        Color3.fromHSV(h, s * 0.7, math.clamp(v * 1.15, 0, 1)),
        Color3.new(1, 1, 1)
    )
    local activeColor = ColorSequence.new(
        Color3.fromHSV(h, math.clamp(s * 0.85, 0, 1), 1),
        Color3.new(1, 1, 1)
    )
	local gradientTransparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	})

	for _, tab in ipairs(self._tabs) do
		-- while settings is open, no tab counts as active
		local active = (not self._settingsOpen) and (tab == self._activeTab)
		local hovered = tab._hovered
		local btn = tab._navContainer
		local gradient = tab._navGradient
		local corner = tab._navCorner

		gradient.Transparency = gradientTransparency

		if active then
			gradient.Color = activeColor
			TweenService:Create(btn, FAST, {
				BackgroundTransparency = 0.02,
				Size = UDim2.new(0, 100, 1, 0),
			}):Play()
			pcall(function()
				local c = corner :: any
				c.BottomLeftRadius = UDim.new(0, 0)
				c.BottomRightRadius = UDim.new(0, 0)
			end)
		else
			gradient.Color = hovered and hoverColor or inactiveColor
			TweenService:Create(btn, FAST, {
				BackgroundTransparency = hovered and 0.25 or 0.5,
				Size = UDim2.new(0, 100, 1, -3),
			}):Play()
			pcall(function()
				local c = corner :: any
				c.BottomLeftRadius = UDim.new(0, 2)
				c.BottomRightRadius = UDim.new(0, 2)
			end)
		end
	end
end

function Window:SelectTab(tab)
	if self._settingsOpen then
		self._settingsOpen = false
		if self._settingsPage then
			self._settingsPage.Visible = false
		end
	end

	local previous = self._activeTab
	self._activeTab = tab

	tab.Root.Visible = true

	if previous and previous ~= tab then
		previous.Root.Visible = false
	end

	self:_updateNav()

	if self._searchInput and self._searchInput.Text ~= "" then
		self:_runSearch()
	end
end

function Window:AddTab(config: { Title: string?, Icon: (string | number)? })
    local theme = self._theme

    local self_tab = setmetatable({}, Tab)
    self_tab._window = self
    self_tab._categories = {}
    self_tab._hovered = false

    local page = Create("Frame", {
        Name = "TabPage",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.99,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self._tabHolder,
    })

    local section1 = Create("ScrollingFrame", {
        Name = "Section1",
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0.5, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = page,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = section1,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 5),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        Parent = section1,
    })

    local section2 = Create("ScrollingFrame", {
        Name = "Section2",
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromScale(0.5, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = page,
    })
    Create("UIListLayout", {
        Padding = UDim.new(0, 4),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = section2,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 5),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        Parent = section2,
    })

    local sepBar = Create("Frame", {
        Name = "SeperatorBar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 1, 1, -8),
        Parent = page,
    })
    self:_trackAccent(sepBar, function(accent)
        sepBar.BackgroundColor3 = accent
    end)

    -- nav button (artik tema tracked)
    local navContainer = Create("Frame", {
        Name = "NavigationButtonContainer",
        Active = true,
        BackgroundColor3 = theme.NavButtonBackground,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 100, 1, -3),
        Parent = self._navContainer,
    })
    self:_track(navContainer, "BackgroundColor3", "NavButtonBackground")

    local navCorner = ApplyCorner(navContainer, 2)
    local navStroke = Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = theme.Stroke,
        Transparency = 0.9,
        Parent = navContainer,
    })
    self:_track(navStroke, "Color", "Stroke")

    local navGradient = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Accent),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
        Parent = navContainer,
    })

    local navButton = Create("TextButton", {
        Name = "NavigationButton",
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        Parent = navContainer,
    })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 3), Parent = navButton })

    local navText = Create("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        FontFace = MakeFont("Nunito", Enum.FontWeight.Bold),
        Text = config.Title or "Tab",
        TextColor3 = theme.NavText,
        TextSize = 15,
        TextTransparency = 0.2,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = navButton,
    })
    Create("UIPadding", { Name = "TextPadding", PaddingLeft = UDim.new(0, 16), Parent = navText })
    self:_track(navText, "TextColor3", "NavText")

    local navIcon = Create("ImageButton", {
        Name = "Icon",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(13, 13),
        Image = ResolveIcon(config.Icon or 10747373176),
        Parent = navButton,
    })

    self_tab.Root = page
    self_tab.Section1 = section1
    self_tab.Section2 = section2
    self_tab._navContainer = navContainer
    self_tab._navGradient = navGradient
    self_tab._navCorner = navCorner
    self_tab._navIcon = navIcon
    self_tab._navText = navText

    navButton.MouseEnter:Connect(function()
        self_tab._hovered = true
        self:_updateNav()
    end)
    navButton.MouseLeave:Connect(function()
        self_tab._hovered = false
        self:_updateNav()
    end)
    navButton.MouseButton1Click:Connect(function()
        self:SelectTab(self_tab)
    end)

    table.insert(self._tabs, self_tab)
    if not self._activeTab then
        self:SelectTab(self_tab)
    else
        self:_updateNav()
    end

    return self_tab
end

function Tab:SetIcon(icon: (string | number)?)
	if self._navIcon then
		self._navIcon.Image = ResolveIcon(icon)
	end
end

function Tab:SetTitle(text: string)
	if self._navText then
		self._navText.Text = text
	end
end

function Window:Show()
	self.ScreenGui.Enabled = true
	self.Main.Visible = true
end

function Window:Hide()
	self.Main.Visible = false
end

function Window:ToggleVisibility()
	self.Main.Visible = not self.Main.Visible
end

function Window:UnloadGui()
	self.ScreenGui:Destroy()
	if self._notifyGui then self._notifyGui:Destroy() end
end

function Window:SetTitle(text: string)
	self.TitleLabel.Text = text
end

local function BuildHolder(window, parent: Instance, theme, height: number, withGradient: boolean)
    local holder = Create("Frame", {
        Name = "ComponentHolder",
        BackgroundColor3 = theme.HolderColor,
        BackgroundTransparency = theme.HolderTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, height),
        Parent = parent,
    })
    window:_track(holder, "BackgroundColor3", "HolderColor")
    window:_track(holder, "BackgroundTransparency", "HolderTransparency")

    ApplyCorner(holder, 4)

    local holderStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Transparency = 0.9,
        Parent = holder,
    })
    window:_track(holderStroke, "Color", "Stroke")

    if withGradient then
        local grad = Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, theme.GradientTop),
                ColorSequenceKeypoint.new(1, theme.GradientBottom),
            }),
            Parent = holder,
        })
        window:_trackGradient(grad, "GradientTop", "GradientBottom")
    end

    local bg = Create("ImageLabel", {
        Name = "Background",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = -10,
        Image = "rbxassetid://36169650",
        ImageColor3 = theme.HoverColor,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop,
        Parent = holder,
    })
    window:_track(bg, "ImageColor3", "HoverColor")

    return holder, bg
end

-- adds a title + description pair to a holder
local function BuildInfo(window, parent: Instance, theme, title: string, description: string?)
	local titleLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -85, 0, 20),
		FontFace = MakeFont("HighwayGothic"),
		Text = title,
		TextColor3 = theme.PrimaryText,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		Parent = parent,
	})
	Create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = titleLabel })
	window:_track(titleLabel, "TextColor3", "PrimaryText")

	local descLabel = Create("TextLabel", {
		Name = "Description",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -85, 0, 25),
		FontFace = MakeFont("Roboto"),
		Text = description or "",
		TextColor3 = theme.SecondaryText,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		Parent = parent,
	})
	Create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingTop = UDim.new(0, 4), Parent = descLabel })
	window:_track(descLabel, "TextColor3", "SecondaryText")

	return titleLabel, descLabel
end

-- wires the standard hover fade for a holder background
local function WireHover(window, holder: GuiObject, bg: ImageLabel)
    holder.MouseEnter:Connect(function()
        local t = window._theme
        bg.ImageColor3 = t.HoverColor
        TweenService:Create(bg, FAST, { ImageTransparency = t.HoverTransparency }):Play()
    end)
    holder.MouseLeave:Connect(function()
        TweenService:Create(bg, FAST, { ImageTransparency = 1 }):Play()
    end)
end

local function WireClick(window, button: GuiButton, bg: ImageLabel)
    button.MouseButton1Down:Connect(function()
        local t = window._theme
        bg.ImageColor3 = t.HoverColor
        TweenService:Create(bg, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            ImageTransparency = math.clamp(t.HoverTransparency - 0.18, 0, 1),
        }):Play()
    end)
    button.MouseButton1Up:Connect(function()
        TweenService:Create(bg, FAST, {
            ImageTransparency = window._theme.HoverTransparency,
        }):Play()
    end)
end

-- ========================================================================
-- tooltip (single shared label that follows the mouse)
-- ========================================================================

function Window:_ensureTooltip()
    if self._tooltip then
        return self._tooltip
    end

    local theme = self._theme

    local tip = Create("TextLabel", {
        Name = "Tooltip",
        BackgroundColor3 = theme.GradientBottom,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 5000,
        FontFace = MakeFont("Nunito", Enum.FontWeight.Bold),
        Text = "",
        TextColor3 = theme.PrimaryText,
        TextTransparency = 1,
        TextSize = 14,
        AutomaticSize = Enum.AutomaticSize.XY,
        Parent = self.ScreenGui,
    })
    ApplyCorner(tip, 2)
    self:_track(tip, "BackgroundColor3", "GradientBottom")
    self:_track(tip, "TextColor3", "PrimaryText")

    -- accent-colored border so it matches the current theme
    local tipStroke = Create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = theme.Accent,
        Transparency = 1,
        Thickness = 1,
        Parent = tip,
    })
    self:_trackAccent(tipStroke, function(accent)
        tipStroke.Color = accent
    end)

    Create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = tip,
    })

    self._tooltip = tip
    self._tooltipStroke = tipStroke
    return tip
end

-- attaches tooltip behaviour to any gui object
function Window:AttachTooltip(guiObject: GuiObject, text: string)
	local tip = self:_ensureTooltip()
	local hovering = false

	local function fadeIn()
		self._tooltipToken = (self._tooltipToken or 0) + 1
		local myToken = self._tooltipToken

		tip.Text = text
		tip.Visible = true

		TweenService:Create(tip, FAST, { TextTransparency = 0, BackgroundTransparency = 0.05 }):Play()

		if self._tooltipStroke then
			TweenService:Create(self._tooltipStroke, FAST, { Transparency = 0.3 }):Play()
		end
	end

	local function fadeOut()
		self._tooltipToken = (self._tooltipToken or 0) + 1
		local myToken = self._tooltipToken

		local fade = TweenService:Create(tip, FAST, {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		if self._tooltipStroke then
			TweenService:Create(self._tooltipStroke, FAST, { Transparency = 1 }):Play()
		end
		fade:Play()

		fade.Completed:Once(function()
			if myToken ~= self._tooltipToken then
				return
			end
			tip.Visible = false
		end)
	end

	guiObject.MouseEnter:Connect(function()
    	hovering = true
    	local mouse = UserInputService:GetMouseLocation()
    	tip.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 2)
    	fadeIn()
	end)
	guiObject.MouseLeave:Connect(function()
		hovering = false
		fadeOut()
	end)
	guiObject.MouseMoved:Connect(function()
		if not hovering then return end
		local mouse = UserInputService:GetMouseLocation()
		tip.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 2)
	end)
end

-- ========================================================================
-- button component
-- ========================================================================

function Category:AddButton(config: {
    Title: string?,
    Description: string?,
    Icon: (string | number)?,
    Tooltip: string?,
    Callback: (() -> ())?,
    })
    local theme = self._window._theme
    local holder, bg = BuildHolder(self._window, self.ContainerScroll, theme, 45, true)

    local info = Create("Frame", {
        Name = "ButtonInfo",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = holder,
    })
    local titleLabel, descLabel = BuildInfo(self._window, info, theme, config.Title or "Button", config.Description)

    local icon = Create("ImageLabel", {
        Name = "ButtonIcon",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(22, 22),
        Image = ResolveIcon(config.Icon or 10734898194),
        Parent = info,
    })
    Create("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = info })

    local button = Create("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 20,
        Parent = holder,
    })

    WireHover(self._window, holder, bg)
    WireClick(self._window, button, bg)

    button.MouseButton1Click:Connect(function()
        -- ikon minik bir punch yapsin
        TweenService:Create(icon, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(18, 18),
        }):Play()
        task.delay(0.07, function()
            TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.fromOffset(22, 22),
            }):Play()
        end)

        if config.Callback then
            task.spawn(config.Callback)
        end
    end)

    if config.Tooltip then
        self._window:AttachTooltip(holder, config.Tooltip)
    end

    local api = {}
    function api:SetTitle(t: string) titleLabel.Text = t end
    function api:SetDescription(d: string) descLabel.Text = d end
    function api:SetIcon(i) icon.Image = ResolveIcon(i) end
    function api:SetVisible(v: boolean) holder.Visible = v end
    function api:Destroy() holder:Destroy() end
    api._holder = holder
    api._searchTitle = config.Title or "Button"
    api._searchDescription = config.Description or ""

    return self:_register(api)
end

-- ========================================================================
-- toggle groups registry (window-level)
-- ========================================================================

function Window:_getToggleGroup(name: string)
	self._toggleGroups = self._toggleGroups or {}
	if not self._toggleGroups[name] then
		self._toggleGroups[name] = {}
	end
	return self._toggleGroups[name]
end

-- ========================================================================
-- toggle component
-- ========================================================================

function Category:AddToggle(config: {
    Title: string?,
    Description: string?,
    Default: boolean?,
    Group: string?,
    Tooltip: string?,
    Callback: ((value: boolean) -> ())?,
    })
    local theme = self._window._theme
    local holder, bg = BuildHolder(self._window, self.ContainerScroll, theme, 45, true)

    local titleLabel, descLabel = BuildInfo(self._window, holder, theme, config.Title or "Toggle", config.Description)

    local toggleFrame = Create("Frame", {
        Name = "ToggleFrame",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(50, 25),
        Parent = holder,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 3),
        PaddingBottom = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        Parent = toggleFrame,
    })

    local toggle = Create("Frame", {
        Name = "Toggle",
        BackgroundColor3 = theme.ToggleActive,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = toggleFrame,
    })
    ApplyCorner(toggle, 999)
    local toggleStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = toggle })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 2),
        Parent = toggle,
    })

    local knob = Create("Frame", {
        Name = "Knob",
        BackgroundColor3 = theme.ToggleKnob,
        BorderSizePixel = 0,
        Size = UDim2.new(0.45, 0, 1, 0),
        Parent = toggle,
    })
    ApplyCorner(knob, 999)
    local knobStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = knob })
    self._window:_track(toggleStroke, "Color", "Stroke")
    self._window:_track(knobStroke, "Color", "Stroke")

    local button = Create("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 20,
        Parent = holder,
    })

    WireHover(self._window, holder, bg)

    local state = false

    local function visualUpdate(animate: boolean)
        local info = animate and MEDIUM or TweenInfo.new(0)
        local t = self._window._theme -- her zaman guncel temayi oku
        if state then
            TweenService:Create(toggle, info, {
                BackgroundTransparency = 0,
                BackgroundColor3 = t.ToggleActive,
            }):Play()
            TweenService:Create(knob, info, {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = t.ToggleKnobActive,
            }):Play()
        else
            TweenService:Create(toggle, info, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(knob, info, {
                AnchorPoint = Vector2.new(0, 0),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = t.ToggleKnob,
            }):Play()
        end
    end

    local api = {}

    function api:Set(value: boolean, silent: boolean?)
        if state == value then return end
        state = value
        visualUpdate(true)

        if config.Group and value then
            local group = self._window:_getToggleGroup(config.Group)
            for _, other in ipairs(group) do
                if other ~= api and other:Get() then
                    other:Set(false)
                end
            end
        end

        if not silent and config.Callback then
            task.spawn(config.Callback, state)
        end
    end

    function api:Get(): boolean
        return state
    end

    function api:SetTitle(t: string) titleLabel.Text = t end
    function api:SetDescription(d: string) descLabel.Text = d end
    function api:SetVisible(v: boolean) holder.Visible = v end
    function api:Destroy() holder:Destroy() end
    api._holder = holder
    api._searchTitle = config.Title or "Toggle"
    api._window = self._window

    toggle.MouseEnter:Connect(function()
        TweenService:Create(toggleStroke, FAST, { Transparency = 0.8 }):Play()
    end)
    toggle.MouseLeave:Connect(function()
        TweenService:Create(toggleStroke, FAST, { Transparency = 0.93 }):Play()
    end)
    button.MouseButton1Click:Connect(function()
        api:Set(not state)
    end)

    if config.Group then
        table.insert(self._window:_getToggleGroup(config.Group), api)
    end

    if config.Tooltip then
        self._window:AttachTooltip(holder, config.Tooltip)
    end

    if config.Default then
        state = true
        visualUpdate(false)
    end

    return self:_register(api)
end

-- ========================================================================
-- separator component
-- ========================================================================
function Category:AddSeparator(config: { Text: string? })
	local theme = self._window._theme
	config = config or {}

	local holder = Create("Frame", {
		Name = "SeperatorHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = self.ContainerScroll,
	})

	local bar1 = Create("Frame", {
		Name = "SeperatorBar1",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0.32, 0, 0, 1),
		Parent = holder,
	})
	local bar2 = Create("Frame", {
		Name = "SeperatorBar2",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.32, 0, 0, 1),
		Parent = holder,
	})
	local text = Create("TextLabel", {
		Name = "SeperatorText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 20),
		FontFace = MakeFont("Arial"),
		Text = config.Text or "Separator",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextTransparency = 0.8,
		TextSize = 14,
		Parent = holder,
	})
	self._window:_track(text, "TextColor3", "SecondaryText")
	
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = text,
	})

	-- resizes the side bars to fill whatever space the text leaves behind
	local function updateBars()
		local total = holder.AbsoluteSize.X
		if total <= 0 then return end
		local textWidth = text.AbsoluteSize.X
		local sideSpace = math.max(0, (total - textWidth) / 2 - 4)
		bar1.Size = UDim2.new(0, sideSpace, 0, 1)
		bar2.Size = UDim2.new(0, sideSpace, 0, 1)
	end

	text:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBars)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBars)
	task.defer(updateBars)

	local api = {}
	function api:SetText(t: string)
		text.Text = t
		task.defer(updateBars)
	end
	function api:SetVisible(v: boolean) holder.Visible = v end
	function api:Destroy() holder:Destroy() end
	api._holder = holder
	api._searchTitle = config.Text or "Separator"

	return self:_register(api)
end

Category.AddSeperator = Category.AddSeparator

-- ========================================================================
-- slider component
-- ========================================================================

function Category:AddSlider(config: {
    Title: string?,
    Description: string?,
    Min: number?,
    Max: number?,
    Default: number?,
    Increment: number?,
    Suffix: string?,
    Tooltip: string?,
    Callback: ((value: number) -> ())?,
    })
    local theme = self._window._theme

    local minValue = config.Min or 0
    local maxValue = config.Max or 100

    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end
    if maxValue == minValue then
        maxValue = minValue + 1
    end

    local increment = math.abs(config.Increment or 1)
    if increment <= 0 then
        increment = 1
    end

    local suffix = config.Suffix or ""

    local holder, background = BuildHolder(self._window, self.ContainerScroll, theme, 85, true)

    local titleLabel = Create("TextLabel", {
        Name = "SliderTitle",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -85, 0, 20),
        FontFace = MakeFont("HighwayGothic"),
        Text = config.Title or "Slider",
        TextColor3 = theme.PrimaryText,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        RichText = true,
        Parent = holder,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 5),
        Parent = titleLabel,
    })

    local descriptionLabel = Create("TextLabel", {
        Name = "SliderDescription",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 20),
        Size = UDim2.new(1, -10, 0, 25),
        FontFace = MakeFont("Roboto"),
        Text = config.Description or "",
        TextColor3 = theme.SecondaryText,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        RichText = true,
        Parent = holder,
    })
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        Parent = descriptionLabel,
    })

    local sliderOuter = Create("Frame", {
        Name = "Slider",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0, 0, 1, -10),
        Size = UDim2.new(1, 0, 0, 25),
        Parent = holder,
    })
    ApplyCorner(sliderOuter, 15)
    Create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
        Parent = sliderOuter,
    })

    local canvas = Create("CanvasGroup", {
        Name = "CanvasGroup",
        BackgroundColor3 = theme.SliderEmpty,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = sliderOuter,
    })
    ApplyCorner(canvas, 15)

    local canvasStroke = Create("UIStroke", {
        Color = theme.Stroke,
        Transparency = 0.95,
        Parent = canvas,
    })

    -- gorunmez clip: boyutu animasyonla degisen kisim bu
    local barClip = Create("Frame", {
        Name = "SliderBarClip",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(0, 0, 1, 0),
        Parent = canvas,
    })

    -- dolgu: HER ZAMAN canvas genisliginde sabit, gradient esnemiyor
    local fill = Create("Frame", {
        Name = "SliderFill",
        BackgroundColor3 = theme.SliderFill,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        Parent = barClip,
    })

    local sliderGradient = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, theme.Accent),
        }),
        Parent = fill,
    })
    self._window:_trackAccent(sliderGradient, function(accent)
        sliderGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, accent),
        })
    end)

    local function syncFillWidth()
        fill.Size = UDim2.new(0, canvas.AbsoluteSize.X, 1, 0)
    end
    canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncFillWidth)
    task.defer(syncFillWidth)

    local sliderButton = Create("TextButton", {
        Name = "SliderBtn",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 20,
        Parent = canvas,
    })

    local valueText = Create("TextLabel", {
        Name = "ValueText",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        FontFace = MakeFont("RobotoMono", Enum.FontWeight.Bold),
        Text = "",
        TextColor3 = theme.PrimaryText,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 10,
        Parent = canvas,
    })
    Create("UIPadding", {
        PaddingRight = UDim.new(0, 8),
        Parent = valueText,
    })

    WireHover(self._window, holder, background)

    self._window:_track(titleLabel, "TextColor3", "PrimaryText")
    self._window:_track(descriptionLabel, "TextColor3", "SecondaryText")
    self._window:_track(canvasStroke, "Color", "Stroke")
    self._window:_track(canvas, "BackgroundColor3", "SliderEmpty")
    self._window:_track(fill, "BackgroundColor3", "SliderFill")
    self._window:_track(valueText, "TextColor3", "PrimaryText")

    local value = minValue
    local activeTween: Tween? = nil
    local dragging = false
    local activeTouch: InputObject? = nil
    local connections: {RBXScriptConnection} = {}

    local function decimalPlaces(numberValue: number): number
        local stringValue = tostring(numberValue)
        local decimal = string.match(stringValue, "%.(%d+)")
        if decimal then
            return #decimal
        end
        return 0
    end

    local precision = math.min(decimalPlaces(increment), 6)

    local function snap(rawValue: number): number
        local clamped = math.clamp(rawValue, minValue, maxValue)
        local stepped = math.floor(((clamped - minValue) / increment) + 0.5) * increment + minValue
        local multiplier = 10 ^ precision
        stepped = math.floor(stepped * multiplier + 0.5) / multiplier
        return math.clamp(stepped, minValue, maxValue)
    end

    local function formatNumber(numberValue: number): string
        if precision <= 0 then
            return tostring(math.floor(numberValue + 0.5))
        end
        return string.format("%." .. tostring(precision) .. "f", numberValue)
    end

    local function getAlpha(): number
        return math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
    end

    local function updateVisual(animate: boolean)
        local targetSize = UDim2.new(getAlpha(), 0, 1, 0)

        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end

        if animate then
            activeTween = TweenService:Create(
                barClip,
                TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = targetSize }
            )
            activeTween:Play()
        else
            barClip.Size = targetSize
        end

        valueText.Text = string.format(
            "%s/%s%s",
            formatNumber(value),
            formatNumber(maxValue),
            suffix
        )
    end

    local api = {}

    local function setValue(newValue: number, silent: boolean?, animate: boolean?)
        local snapped = snap(newValue)
        local changed = snapped ~= value

        value = snapped
        updateVisual(animate == true)

        if changed and not silent and config.Callback then
            task.spawn(config.Callback, value)
        end
    end

    function api:Set(newValue: number, silent: boolean?)
        setValue(newValue, silent, true)
    end

    function api:Get(): number
        return value
    end

    function api:SetTitle(text: string)
        titleLabel.Text = text
    end

    function api:SetDescription(text: string)
        descriptionLabel.Text = text
    end

    function api:SetVisible(visible: boolean)
        holder.Visible = visible
    end

    function api:Destroy()
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
        table.clear(connections)
        holder:Destroy()
    end

    api._holder = holder
    api._searchTitle = config.Title or "Slider"
    api._searchDescription = config.Description or ""

    local function updateFromX(xPosition: number)
        local width = canvas.AbsoluteSize.X
        if width <= 0 then
            return
        end
        local alpha = math.clamp((xPosition - canvas.AbsolutePosition.X) / width, 0, 1)
        -- animate = true: surukleme artik tween'li kayiyor
        setValue(minValue + alpha * (maxValue - minValue), false, true)
    end

    table.insert(connections, sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            activeTouch = nil
            updateFromX(input.Position.X)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            activeTouch = input
            updateFromX(input.Position.X)
        end
    end))

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement and activeTouch == nil then
            updateFromX(input.Position.X)
        elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
            updateFromX(input.Position.X)
        end
    end))

    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and activeTouch == nil then
            dragging = false
        elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
            dragging = false
            activeTouch = nil
        end
    end))

    if config.Tooltip then
        self._window:AttachTooltip(holder, config.Tooltip)
    end

    setValue(config.Default or minValue, true, false)

    return self:_register(api)
end

-- ========================================================================
-- input component
-- ========================================================================

function Category:AddInput(config: {
    Title: string?,
    Description: string?,
    Placeholder: string?,
    Default: string?,
    ClearOnFocus: boolean?,
    Tooltip: string?,
    Callback: ((text: string) -> ())?,
    })
    local theme = self._window._theme
    local holder, bg = BuildHolder(self._window, self.ContainerScroll, theme, 45, true)

    local titleLabel, descLabel = BuildInfo(self._window, holder, theme, config.Title or "Input", config.Description)

    local inputFrame = Create("Frame", {
        Name = "InputFrame",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(70, 25),
        Parent = holder,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 3),
        PaddingBottom = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        Parent = inputFrame,
    })

    local inputBox = Create("Frame", {
        Name = "Input",
        BackgroundColor3 = theme.HolderColor,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = inputFrame,
    })
    ApplyCorner(inputBox, 4)
    local inputStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = inputBox })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = inputBox,
    })
    self._window:_track(inputStroke, "Color", "Stroke")

    local textBox = Create("TextBox", {
        Name = "InputText",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        FontFace = MakeFont("Arial"),
        PlaceholderText = config.Placeholder or "Input",
        PlaceholderColor3 = theme.SecondaryText,
        Text = config.Default or "",
        ClearTextOnFocus = config.ClearOnFocus or false,
        TextColor3 = theme.PrimaryText,
        TextScaled = true,
        Parent = inputBox,
    })
    -- TextScaled buyumesin diye tavan koyuyoruz, sadece sigmayinca kuculur
    Create("UITextSizeConstraint", {
        MaxTextSize = 14,
        MinTextSize = 8,
        Parent = textBox,
    })
    self._window:_track(textBox, "TextColor3", "PrimaryText")
    self._window:_track(textBox, "PlaceholderColor3", "SecondaryText")

    WireHover(self._window, holder, bg)

    local api = {}
    function api:Set(text: string, silent: boolean?)
        textBox.Text = text
        if not silent and config.Callback then
            task.spawn(config.Callback, text)
        end
    end
    function api:Get(): string return textBox.Text end
    function api:SetTitle(t: string) titleLabel.Text = t end
    function api:SetDescription(d: string) descLabel.Text = d end
    function api:SetVisible(v: boolean) holder.Visible = v end
    function api:Destroy() holder:Destroy() end
    api._holder = holder
    api._searchTitle = config.Title or "Input"

    textBox.Focused:Connect(function()
        TweenService:Create(inputStroke, FAST, { Transparency = 0.65 }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(inputStroke, FAST, { Transparency = 0.93 }):Play()
        if config.Callback then
            task.spawn(config.Callback, textBox.Text)
        end
    end)

    if config.Tooltip then
        self._window:AttachTooltip(holder, config.Tooltip)
    end

    return self:_register(api)
end

-- ========================================================================
-- keybind component
-- ========================================================================

local KeyNames = {
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "Shift",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.Space] = "Space",
}

function Category:AddKeybind(config: {
    Title: string?,
    Description: string?,
    Default: Enum.KeyCode?,
    Tooltip: string?,
    Callback: ((key: Enum.KeyCode) -> ())?,
    ChangedCallback: ((key: Enum.KeyCode) -> ())?,
    })
    local theme = self._window._theme
    local holder, bg = BuildHolder(self._window, self.ContainerScroll, theme, 45, true)

    local titleLabel, descLabel = BuildInfo(self._window, holder, theme, config.Title or "Keybind", config.Description)

    local keybindFrame = Create("Frame", {
        Name = "KeybindFrame",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(48, 30),
        Parent = holder,
    })

    local keybind = Create("Frame", {
        Name = "Keybind",
        BackgroundColor3 = theme.HolderColor,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = keybindFrame,
    })
    ApplyCorner(keybind, 4)
    local keybindStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.93, Parent = keybind })
    self._window:_track(keybindStroke, "Color", "Stroke")

    local setBtn = Create("TextButton", {
        Name = "SetKeybindBtn",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        FontFace = MakeFont("RobotoMono", Enum.FontWeight.Bold),
        Text = "K",
        TextColor3 = theme.SecondaryText,
        TextScaled = true,
        Parent = keybind,
    })
    Create("UITextSizeConstraint", {
        MaxTextSize = 15,
        MinTextSize = 8,
        Parent = setBtn,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
        Parent = setBtn,
    })
    self._window:_track(setBtn, "TextColor3", "SecondaryText")

    WireHover(self._window, holder, bg)

    local currentKey = config.Default or Enum.KeyCode.K
    local listening = false

    local function keyLabel(key: Enum.KeyCode): string
        return KeyNames[key] or key.Name
    end

    local function updateVisual()
        setBtn.Text = listening and "..." or keyLabel(currentKey)
    end

    local api = {}
    function api:Set(key: Enum.KeyCode, silent: boolean?)
        currentKey = key
        updateVisual()
        if not silent and config.ChangedCallback then
            task.spawn(config.ChangedCallback, key)
        end
    end
    function api:Get(): Enum.KeyCode return currentKey end
    function api:SetTitle(t: string) titleLabel.Text = t end
    function api:SetDescription(d: string) descLabel.Text = d end
    function api:SetVisible(v: boolean) holder.Visible = v end
    api._holder = holder
    api._searchTitle = config.Title or "Keybind"

    setBtn.MouseButton1Click:Connect(function()
        listening = true
        updateVisual()
        TweenService:Create(keybindStroke, FAST, { Transparency = 0.55 }):Play()
    end)

    local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                api:Set(input.KeyCode)
                TweenService:Create(keybindStroke, FAST, { Transparency = 0.93 }):Play()
            end
            return
        end

        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKey then
            if config.Callback then
                task.spawn(config.Callback, currentKey)
            end
        end
    end)

    function api:Destroy()
        inputConn:Disconnect()
        holder:Destroy()
    end

    if config.Tooltip then
        self._window:AttachTooltip(holder, config.Tooltip)
    end

    updateVisual()
    return self:_register(api)
end

-- ========================================================================
-- dropdown component
-- ========================================================================

function Category:AddDropdown(config: {
    Title: string?,
    Description: string?,
    Values: {string}?,
    Default: (string | {string})?,
    Multi: boolean?,
    Searchable: boolean?,
    Tooltip: string?,
    Callback: ((selected: any) -> ())?,
    })
    local window = self._window
    local theme = window._theme
    local values = config.Values or {}
    local multi = config.Multi or false
    local searchable = config.Searchable ~= false -- default true

    local holder = Create("Frame", {
        Name = "DropdownHolder",
        BackgroundColor3 = theme.HolderColor,
        BackgroundTransparency = theme.HolderTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 45),
        Parent = self.ContainerScroll,
    })
    ApplyCorner(holder, 4)
    window:_track(holder, "BackgroundColor3", "HolderColor")
    window:_track(holder, "BackgroundTransparency", "HolderTransparency")

    local holderGradient = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.GradientTop),
            ColorSequenceKeypoint.new(1, theme.GradientBottom),
        }),
        Parent = holder,
    })
    window:_trackGradient(holderGradient, "GradientTop", "GradientBottom")

    local dropStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = holder })
    window:_track(dropStroke, "Color", "Stroke")

    -- top bar (title, desc, collapse arrow)
    local topBar = Create("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 45),
        Parent = holder,
    })
    local topBarStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = topBar })
    window:_track(topBarStroke, "Color", "Stroke")

    local titleLabel = Create("TextLabel", {
        Name = "DropdownTitle",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -85, 0, 20),
        FontFace = MakeFont("HighwayGothic"),
        Text = config.Title or "Dropdown",
        TextColor3 = theme.PrimaryText,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        RichText = true,
        Parent = topBar,
    })
    Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 5), Parent = titleLabel })
    window:_track(titleLabel, "TextColor3", "PrimaryText")

    local descLabel = Create("TextLabel", {
        Name = "DropdownDescription",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, -85, 0, 25),
        FontFace = MakeFont("Roboto"),
        Text = config.Description or "",
        TextColor3 = theme.SecondaryText,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        RichText = true,
        Parent = topBar,
    })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = descLabel })
    window:_track(descLabel, "TextColor3", "SecondaryText")

    local collapseHolder = Create("Frame", {
        Name = "DropdownCollapseHolder",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(27, 27),
        Parent = topBar,
    })
    local collapseArrow = Create("ImageButton", {
        Name = "DropdownCollapse",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = ResolveIcon(10709790948),
        Parent = collapseHolder,
    })

    local topClick = Create("TextButton", {
        Name = "TopClick",
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 10,
        Parent = topBar,
    })

    -- search bar
    local searchHolder, searchInput, clearBtn, searchStroke
    if searchable then
        searchHolder = Create("Frame", {
            Name = "DropdownSearchHolder",
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = theme.HolderColor,
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Position = UDim2.new(0.5, 0, 0, 53),
            Size = UDim2.new(1, -10, 0, 25),
            Parent = holder,
        })
        ApplyCorner(searchHolder, 3)
        window:_track(searchHolder, "BackgroundColor3", "HolderColor")
        Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 86, 89)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
            Parent = searchHolder,
        })
        searchStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = searchHolder })
        window:_track(searchStroke, "Color", "Stroke")
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 22),
            Parent = searchHolder,
        })
        Create("ImageLabel", {
            Name = "DropdownSearchIcon",
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(20, 20),
            Image = ResolveIcon(10734943674),
            Parent = searchHolder,
        })
        searchInput = Create("TextBox", {
            Name = "DropdownSearchInput",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(23, 0),
            Size = UDim2.new(1, -40, 1, 0),
            FontFace = MakeFont("Arial"),
            PlaceholderText = "Search...",
            PlaceholderColor3 = theme.SecondaryText,
            Text = "",
            TextColor3 = theme.PrimaryText,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = searchHolder,
        })
        window:_track(searchInput, "TextColor3", "PrimaryText")
        window:_track(searchInput, "PlaceholderColor3", "SecondaryText")
        clearBtn = Create("ImageButton", {
            Name = "ClearBtn",
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -5, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            Image = ResolveIcon(10723346158),
            Parent = searchHolder,
        })
    end

    -- separator line under search / topbar
    local sepLine = Create("Frame", {
        Name = "DropdownSeperatorFrame",
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = theme.Stroke,
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0, searchable and 85 or 47),
        Size = UDim2.new(1, -12, 0, 1),
        Parent = holder,
    })
    window:_track(sepLine, "BackgroundColor3", "Stroke")

    -- options container
    local container = Create("Frame", {
        Name = "DropdownContainer",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, searchable and -90 or -52),
        Parent = holder,
    })
    local scroller = Create("ScrollingFrame", {
        Name = "DropdownScroller",
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = container,
    })
    local optList = Create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroller,
    })
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        Parent = scroller,
    })

    local expanded = false
    local selected = {} -- set: value -> true
    local optionButtons = {}

    local function isSelected(v: string): boolean
        return selected[v] == true
    end

    local function collapsedHeight(): number
        return 45
    end

    local function expandedHeight(): number
        local visibleCount = 0

        for _, option in ipairs(optionButtons) do
            if option.holder.Visible then
                visibleCount += 1
            end
        end

        local optionHeight = visibleCount * 45
        local spacingHeight = math.max(0, visibleCount - 1) * 6
        local paddingHeight = 12
        local listHeight = optionHeight + spacingHeight + paddingHeight

        local headerHeight = searchable and 90 or 52
        return headerHeight + math.min(listHeight, 200)
    end

    local function refreshSize()
        if searchHolder then searchHolder.Visible = expanded end
        container.Visible = expanded
        if expanded then
            TweenService:Create(holder, MEDIUM, { Size = UDim2.new(1, 0, 0, expandedHeight()) }):Play()
        else
            TweenService:Create(holder, MEDIUM, { Size = UDim2.new(1, 0, 0, collapsedHeight()) }):Play()
        end
        self:_recalcHeight()
    end

    -- styles a single option button by its state, fully theme-aware.
    -- selected/hover colors are derived live from the current accent,
    -- so every theme preset automatically looks right.
    local function styleOption(opt, animate: boolean)
        local t = window._theme
        local info = animate and MEDIUM or TweenInfo.new(0)
        local sel = isSelected(opt.value)
        local grad = opt.gradient

        local selBottom = t.GradientBottom:Lerp(t.Accent, 0.45)
        local hovBottom = t.GradientBottom:Lerp(t.Accent, 0.2)

        if sel then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, t.GradientTop),
                ColorSequenceKeypoint.new(1, selBottom),
            })
        elseif opt.hovered then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, t.GradientTop),
                ColorSequenceKeypoint.new(1, hovBottom),
            })
        else
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, t.GradientTop),
                ColorSequenceKeypoint.new(1, t.GradientBottom),
            })
        end

        local base = t.HolderTransparency
        local bgTransparency
        if sel then
            bgTransparency = math.clamp(base - 0.2, 0, 1)
        elseif opt.hovered then
            bgTransparency = math.clamp(base - 0.1, 0, 1)
        else
            bgTransparency = base
        end
        TweenService:Create(opt.holder, info, { BackgroundTransparency = bgTransparency }):Play()

        opt.stroke.Color = sel and t.Accent or t.Stroke
        TweenService:Create(opt.stroke, info, { Transparency = sel and 0.2 or 0.9 }):Play()

        opt.bg.ImageColor3 = t.HoverColor
        TweenService:Create(opt.bg, info, {
            ImageTransparency = (sel or opt.hovered) and t.HoverTransparency or 1,
        }):Play()
    end

    local api = {}

    local function fireCallback()
        if not config.Callback then return end
        if multi then
            local list = {}
            for _, v in ipairs(values) do
                if selected[v] then table.insert(list, v) end
            end
            task.spawn(config.Callback, list)
        else
            local one
            for v in pairs(selected) do one = v end
            task.spawn(config.Callback, one)
        end
    end

    local function selectValue(v: string, silent: boolean?)
        if multi then
            selected[v] = not selected[v] or nil
        else
            selected = { [v] = true }
            if expanded then
                expanded = false
                refreshSize()
            end
        end
        for _, opt in ipairs(optionButtons) do
            styleOption(opt, true)
        end
        if not silent then fireCallback() end
    end

    -- build option buttons
    for i, v in ipairs(values) do
        local optHolder = Create("Frame", {
            Name = "OptionHolder",
            BackgroundColor3 = theme.HolderColor,
            BackgroundTransparency = theme.HolderTransparency,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 45),
            Parent = scroller,
        })
        ApplyCorner(optHolder, 4)
        window:_track(optHolder, "BackgroundColor3", "HolderColor")

        local optStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = optHolder })
        local optGradient = Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, theme.GradientTop),
                ColorSequenceKeypoint.new(1, theme.GradientBottom),
            }),
            Parent = optHolder,
        })
        local optBg = Create("ImageLabel", {
            Name = "Background",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = -10,
            Image = "rbxassetid://36169650",
            ImageColor3 = theme.HoverColor,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Crop,
            Parent = optHolder,
        })
        local optText = Create("TextLabel", {
            Name = "OptionText",
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.new(1, -16, 0, 20),
            FontFace = MakeFont("HighwayGothic"),
            Text = v,
            TextColor3 = theme.PrimaryText,
            TextSize = 19,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = optHolder,
        })
        Create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = optText })
        window:_track(optText, "TextColor3", "PrimaryText")

        local optBtn = Create("TextButton", {
            Name = "Button",
            BackgroundTransparency = 1,
            Text = "",
            Size = UDim2.fromScale(1, 1),
            ZIndex = 20,
            Parent = optHolder,
        })

        local opt = {
            value = v,
            holder = optHolder,
            gradient = optGradient,
            bg = optBg,
            text = optText,
            stroke = optStroke,
            hovered = false,
        }
        table.insert(optionButtons, opt)

        window:_trackAccent(optHolder, function()
            styleOption(opt, false)
        end)

        optHolder.MouseEnter:Connect(function()
            opt.hovered = true
            styleOption(opt, true)
        end)
        optHolder.MouseLeave:Connect(function()
            opt.hovered = false
            styleOption(opt, true)
        end)
        optBtn.MouseButton1Click:Connect(function()
            selectValue(v)
        end)
    end

    -- collapse arrow toggle
    local function toggleExpanded()
        expanded = not expanded
        local rot = expanded and 180 or 0
        TweenService:Create(collapseArrow, FAST, { Rotation = rot }):Play()
        refreshSize()
    end

    topClick.MouseButton1Click:Connect(toggleExpanded)
    collapseArrow.MouseButton1Click:Connect(toggleExpanded)
    collapseArrow.MouseEnter:Connect(function()
        TweenService:Create(collapseArrow, FAST, { ImageTransparency = 0.4 }):Play()
    end)
    collapseArrow.MouseLeave:Connect(function()
        TweenService:Create(collapseArrow, FAST, { ImageTransparency = 0 }):Play()
    end)

    -- search filtering
    if searchable then
        searchInput.Focused:Connect(function()
            TweenService:Create(searchStroke, FAST, { Transparency = 0.65 }):Play()
        end)
        searchInput.FocusLost:Connect(function()
            TweenService:Create(searchStroke, FAST, { Transparency = 0.9 }):Play()
        end)
        searchInput:GetPropertyChangedSignal("Text"):Connect(function()
            local query = string.lower(searchInput.Text)
            for _, opt in ipairs(optionButtons) do
                opt.holder.Visible = (query == "" or string.find(string.lower(opt.value), query, 1, true) ~= nil)
            end
            if expanded then refreshSize() end
        end)
        clearBtn.MouseButton1Click:Connect(function()
            searchInput.Text = ""
        end)
    end

    function api:Set(value: (string | {string}), silent: boolean?)
        selected = {}
        if type(value) == "table" then
            for _, v in ipairs(value) do selected[v] = true end
        elseif value ~= nil then
            selected[value] = true
        end
        for _, opt in ipairs(optionButtons) do styleOption(opt, false) end
        if not silent then fireCallback() end
    end

    function api:Get()
        if multi then
            local list = {}
            for _, v in ipairs(values) do
                if selected[v] then table.insert(list, v) end
            end
            return list
        else
            for v in pairs(selected) do return v end
            return nil
        end
    end

    function api:SetTitle(t: string) titleLabel.Text = t end
    function api:SetDescription(d: string) descLabel.Text = d end
    function api:SetVisible(v: boolean) holder.Visible = v end
    function api:Destroy() holder:Destroy() end
    api._holder = holder
    api._searchTitle = config.Title or "Dropdown"

    if config.Tooltip then
        window:AttachTooltip(topBar, config.Tooltip)
    end

    -- apply default
    if config.Default then
        api:Set(config.Default, true)
    end

    if searchHolder then searchHolder.Visible = false end
    container.Visible = false
    holder.Size = UDim2.new(1, 0, 0, collapsedHeight())
    return self:_register(api)
end

-- ========================================================================
-- color picker component
-- ========================================================================

local PRESET_COLORS = {
	Color3.fromRGB(245, 114, 66), Color3.fromRGB(245, 66, 191), Color3.fromRGB(124, 54, 245),
	Color3.fromRGB(202, 110, 255), Color3.fromRGB(250, 142, 239), Color3.fromRGB(214, 206, 92),
	Color3.fromRGB(255, 93, 48), Color3.fromRGB(255, 169, 56), Color3.fromRGB(0, 171, 0),
	Color3.fromRGB(0, 116, 224), Color3.fromRGB(120, 0, 76), Color3.fromRGB(255, 194, 245),
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(171, 209, 255),
}

function Category:AddColorPicker(config: {
	Title: string?,
	Description: string?,
	Default: Color3?,
	Tooltip: string?,
	Callback: ((color: Color3) -> ())?,
	})
	local theme = self._window._theme

	local holder = Create("Frame", {
		Name = "ColorPickerHolder",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 45),
		Parent = self.ContainerScroll,
	})
	ApplyCorner(holder, 4)
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.GradientTop),
			ColorSequenceKeypoint.new(1, theme.GradientBottom),
		}),
		Parent = holder,
	})
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = holder })

	local topBar = Create("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 45),
		Parent = holder,
	})
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = topBar })

	local titleLabel = Create("TextLabel", {
		Name = "ColorPickerTitle",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -85, 0, 20),
		FontFace = MakeFont("HighwayGothic"),
		Text = config.Title or "Color Picker",
		TextColor3 = theme.PrimaryText,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		Parent = topBar,
	})
	Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 5), Parent = titleLabel })

	local descLabel = Create("TextLabel", {
		Name = "ColorPickerDescription",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -85, 0, 25),
		FontFace = MakeFont("Roboto"),
		Text = config.Description or "",
		TextColor3 = theme.SecondaryText,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
		Parent = topBar,
	})
	Create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = descLabel })

	-- indicator, properly centered on Y with anchor 0.5
	local indicator = Create("Frame", {
		Name = "ColorIndicator",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = config.Default or Color3.fromRGB(124, 163, 255),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -39, 0.5, 0),
		Size = UDim2.fromOffset(40, 20),
		Parent = topBar,
	})
	ApplyCorner(indicator, 3)
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.6, Parent = indicator })

	-- collapse arrow, centered on Y
	local collapseArrow = Create("ImageButton", {
		Name = "ColorPickerCollapse",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(27, 27),
		Image = ResolveIcon(10709790948),
		Parent = topBar,
	})

	local topClick = Create("TextButton", {
		Name = "TopClick",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, -60, 1, 0),
		ZIndex = 5,
		Parent = topBar,
	})

	-- picker window (holds palette, sliders, presets, hex)
	local pickerWindow = Create("Frame", {
		Name = "ColorpickerWindow",
		BackgroundColor3 = Color3.fromRGB(32, 55, 61),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 50),
		Size = UDim2.new(1, -20, 0, 300),
		Parent = holder,
	})
	ApplyCorner(pickerWindow, 6)

	-- saturation/value palette
	local palette = Create("TextButton", {
		Name = "Palette",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 150),
		Text = "",
		Parent = pickerWindow,
	})
	ApplyCorner(palette, 4)

	-- white gradient (left = white, right = transparent) => saturation
	local whiteGrad = Create("Frame", {
		Name = "RightWhitenessGradient",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = palette,
	})
	ApplyCorner(whiteGrad, 4)
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),  -- left: opaque white
			NumberSequenceKeypoint.new(1, 1),  -- right: shows hue
		}),
		Parent = whiteGrad,
	})

	-- black gradient (top = transparent, bottom = black) => value
	local blackGrad = Create("Frame", {
		Name = "BottomDarknessGradient",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = palette,
	})
	ApplyCorner(blackGrad, 4)
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),  -- top: transparent
			NumberSequenceKeypoint.new(1, 0),  -- bottom: black
		}),
		Parent = blackGrad,
	})

	local circle = Create("Frame", {
		Name = "ColorPickerCircle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 6,
		Parent = palette,
	})
	ApplyCorner(circle, 999)
	Create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 255, 255), Parent = circle })

	-- hue slider
	local hueSlider = Create("TextButton", {
		Name = "ColorSlider",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 170),
		Size = UDim2.new(1, -20, 0, 6),
		Text = "",
		Parent = pickerWindow,
	})
	ApplyCorner(hueSlider, 999)
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueSlider,
	})
	local hueKnob = Create("Frame", {
		Name = "HueKnob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 4,
		Parent = hueSlider,
	})
	ApplyCorner(hueKnob, 999)

	-- darkness (value) slider, below the hue slider
	local darknessSlider = Create("TextButton", {
		Name = "DarknessSlider",
		AutoButtonColor = false,
		BackgroundColor3 = config.Default or Color3.fromRGB(124, 163, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 190),
		Size = UDim2.new(1, -20, 0, 6),
		Text = "",
		Parent = pickerWindow,
	})
	ApplyCorner(darknessSlider, 999)
	local darknessGrad = Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Parent = darknessSlider,
	})
	local darknessKnob = Create("Frame", {
		Name = "DarknessKnob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 4,
		Parent = darknessSlider,
	})
	ApplyCorner(darknessKnob, 999)

	-- preset colors
	local presetScroller = Create("ScrollingFrame", {
		Name = "PresetColors",
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 205),
		Size = UDim2.new(1, -20, 0, 65),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Parent = pickerWindow,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(25, 25),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = presetScroller,
	})
	Create("UIPadding", { PaddingTop = UDim.new(0, 3), Parent = presetScroller })

	-- custom text + hex box
	local customText = Create("TextLabel", {
		Name = "CustomText",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 1, -6),
		Size = UDim2.fromOffset(55, 20),
		FontFace = MakeFont("GothamSSm"),
		Text = "Custom:",
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextTransparency = 0.4,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = pickerWindow,
	})

	local hexBox = Create("TextBox", {
		Name = "HexValue",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 29, 31),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -10, 1, -6),
		Size = UDim2.fromOffset(200, 20),
		FontFace = MakeFont("GothamSSm"),
		Text = "#7ca3ff",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = 0.3,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = pickerWindow,
	})
	ApplyCorner(hexBox, 4)
	Create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = theme.Stroke, Transparency = 0.9, Parent = hexBox })
	Create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = hexBox })

	-- state
	local h, s, v = 0.6, 0.5, 1
	do
		local def = config.Default or Color3.fromRGB(124, 163, 255)
		h, s, v = def:ToHSV()
	end
	local expanded = false
	local selectedPreset = nil -- currently highlighted preset button
	local presetButtons = {}   -- { button = ..., stroke = ..., color = ... }

	local function currentColor(): Color3
		return Color3.fromHSV(h, s, v)
	end

	local function clearSelectedPreset(animate: boolean)
		if selectedPreset then
			local info = animate and MEDIUM or TweenInfo.new(0)
			TweenService:Create(selectedPreset.stroke, info, { Transparency = 1 }):Play()
			selectedPreset = nil
		end
	end

	local function updateVisuals(fire: boolean, keepPreset: boolean?)
		local col = currentColor()
		palette.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		indicator.BackgroundColor3 = col
		circle.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.fromScale(h, 0.5)
		darknessKnob.Position = UDim2.fromScale(v, 0.5)
		darknessSlider.BackgroundColor3 = Color3.fromHSV(h, s, 1)
		hexBox.Text = string.format("#%02x%02x%02x",
			math.floor(col.R * 255 + 0.5),
			math.floor(col.G * 255 + 0.5),
			math.floor(col.B * 255 + 0.5))

		-- clear the selected preset highlight when color changes manually
		if not keepPreset then
			clearSelectedPreset(true)
		end

		if fire and config.Callback then
			task.spawn(config.Callback, col)
		end
	end

	-- build preset buttons
	for i, presetColor in ipairs(PRESET_COLORS) do
		local btn = Create("TextButton", {
			Name = "Preset" .. i,
			AutoButtonColor = false,
			BackgroundColor3 = presetColor,
			BorderSizePixel = 0,
			Text = "",
			LayoutOrder = i,
			Parent = presetScroller,
		})
		ApplyCorner(btn, 6)
		local pStroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(255, 255, 255),
			Transparency = 1,
			Parent = btn,
		})

		local presetEntry = { button = btn, stroke = pStroke, color = presetColor }
		table.insert(presetButtons, presetEntry)

		btn.MouseEnter:Connect(function()
			if selectedPreset ~= presetEntry then
				TweenService:Create(pStroke, FAST, { Transparency = 0.6 }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if selectedPreset ~= presetEntry then
				TweenService:Create(pStroke, FAST, { Transparency = 1 }):Play()
			end
		end)
		btn.MouseButton1Click:Connect(function()
			-- clear old selection
			clearSelectedPreset(true)
			-- highlight this one and keep it
			selectedPreset = presetEntry
			TweenService:Create(pStroke, MEDIUM, { Transparency = 0 }):Play()
			h, s, v = presetColor:ToHSV()
			updateVisuals(true, true) -- keepPreset = true so it stays selected
		end)
	end

	local function collapsedHeight() return 45 end
	local function expandedHeight() return 45 + 300 + 10 end

	local function refreshSize()
		pickerWindow.Visible = expanded
		if expanded then
			TweenService:Create(holder, MEDIUM, { Size = UDim2.new(1, 0, 0, expandedHeight()) }):Play()
			TweenService:Create(pickerWindow, MEDIUM, { BackgroundTransparency = 0 }):Play()
		else
			TweenService:Create(holder, MEDIUM, { Size = UDim2.new(1, 0, 0, collapsedHeight()) }):Play()
			pickerWindow.BackgroundTransparency = 1
		end
		self:_recalcHeight()
	end

	local function toggleExpanded()
		expanded = not expanded
		TweenService:Create(collapseArrow, FAST, { Rotation = expanded and 180 or 0 }):Play()
		refreshSize()
	end

	topClick.MouseButton1Click:Connect(toggleExpanded)
	collapseArrow.MouseButton1Click:Connect(toggleExpanded)
	collapseArrow.MouseEnter:Connect(function()
		TweenService:Create(collapseArrow, FAST, { ImageTransparency = 0.4 }):Play()
	end)
	collapseArrow.MouseLeave:Connect(function()
		TweenService:Create(collapseArrow, FAST, { ImageTransparency = 0 }):Play()
	end)

	-- palette dragging
	local draggingPalette = false
	local function updatePalette(pos: Vector2)
		local abs = palette.AbsolutePosition
		local size = palette.AbsoluteSize
		s = math.clamp((pos.X - abs.X) / size.X, 0, 1)
		v = 1 - math.clamp((pos.Y - abs.Y) / size.Y, 0, 1)
		updateVisuals(true)
	end
	palette.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingPalette = true
			updatePalette(input.Position)
		end
	end)

	-- hue dragging
	local draggingHue = false
	local function updateHue(posX: number)
		local abs = hueSlider.AbsolutePosition.X
		local width = hueSlider.AbsoluteSize.X
		h = math.clamp((posX - abs) / width, 0, 1)
		updateVisuals(true)
	end
	hueSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingHue = true
			updateHue(input.Position.X)
		end
	end)

	-- darkness (value) dragging
	local draggingDark = false
	local function updateDark(posX: number)
		local abs = darknessSlider.AbsolutePosition.X
		local width = darknessSlider.AbsoluteSize.X
		v = math.clamp((posX - abs) / width, 0, 1)
		updateVisuals(true)
	end
	darknessSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingDark = true
			updateDark(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if draggingPalette then updatePalette(input.Position) end
			if draggingHue then updateHue(input.Position.X) end
			if draggingDark then updateDark(input.Position.X) end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingPalette = false
			draggingHue = false
			draggingDark = false
		end
	end)

	-- hex input
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if #hex == 6 then
			local r = tonumber(hex:sub(1, 2), 16)
			local g = tonumber(hex:sub(3, 4), 16)
			local b = tonumber(hex:sub(5, 6), 16)
			if r and g and b then
				h, s, v = Color3.fromRGB(r, g, b):ToHSV()
				updateVisuals(true)
				return
			end
		end
		updateVisuals(false)
	end)

	local api = {}
	function api:Set(color: Color3, silent: boolean?)
		h, s, v = color:ToHSV()
		updateVisuals(not silent)
	end
	function api:Get(): Color3 return currentColor() end
	function api:SetTitle(t: string) titleLabel.Text = t end
	function api:SetDescription(d: string) descLabel.Text = d end
	function api:SetVisible(vis: boolean) holder.Visible = vis end
	function api:Destroy() holder:Destroy() end
	api._holder = holder
	api._searchTitle = config.Title or "Color Picker"

	self._window:_track(pickerWindow, "BackgroundColor3", "PickerBackground")
    self._window:_track(titleLabel, "TextColor3", "PrimaryText")
    self._window:_track(descLabel, "TextColor3", "SecondaryText")
    self._window:_track(customText, "TextColor3", "SecondaryText")
    self._window:_track(hexBox, "TextColor3", "PrimaryText")
	
	if config.Tooltip then
		self._window:AttachTooltip(topBar, config.Tooltip)
	end

	pickerWindow.Visible = false
	holder.Size = UDim2.new(1, 0, 0, collapsedHeight())
	updateVisuals(false)
	return self:_register(api)
end

-- ========================================================================
-- notification system
-- ========================================================================

function Window:Notify(config: {
    Title: string?,
    Content: string?,
    Icon: (string | number)?,
    Duration: number?,
    Callback: (() -> ())?,
})
    config = config or {}
    local theme = self._theme
    local duration = config.Duration or 5
    self._notifyOrder = (self._notifyOrder or 0) + 1

    local width = 240
    local TextService = game:GetService("TextService")
    local contentStr = config.Content or ""
    local measured = TextService:GetTextSize(
        contentStr, 15, Enum.Font.Ubuntu, Vector2.new(width - 28, math.huge)
    )
    local height = math.clamp(34 + measured.Y + 14, 62, 220)

    local slot = Create("Frame", {
        Name = "NotificationSlot",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = self._notifyOrder,
        Size = UDim2.new(0, width, 0, 0),
        Parent = self._notifyHolder,
    })

    local card = Create("Frame", {
        Name = "Card",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(-1, -12, 0, 2),
        Size = UDim2.new(1, -4, 1, -4),
        Parent = slot,
    })
    ApplyCorner(card, 4)

    local grad = Create("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.GradientTop),
            ColorSequenceKeypoint.new(1, theme.GradientBottom),
        }),
        Parent = card,
    })
    self:_trackGradient(grad, "GradientTop", "GradientBottom")

    local stroke = Create("UIStroke", {
        Color = theme.Accent,
        Transparency = 0.45,
        Thickness = 1,
        Parent = card,
    })
    self:_trackAccent(stroke, function(accent) stroke.Color = accent end)

    local accentBar = Create("Frame", {
        Name = "AccentBar",
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
        Parent = card,
    })
    self:_trackAccent(accentBar, function(accent) accentBar.BackgroundColor3 = accent end)

    local textX = 12
    if config.Icon then
        local resolved = ResolveIcon(config.Icon)
        if resolved ~= "" then
            textX = 34
            Create("ImageLabel", {
                Name = "Icon",
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 7),
                Size = UDim2.fromOffset(18, 18),
                Image = resolved,
                Parent = card,
            })
        end
    end

    local title = Create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(textX, 6),
        Size = UDim2.new(1, -(textX + 10), 0, 20),
        Font = Enum.Font.Ubuntu,
        Text = config.Title or "Notification",
        TextColor3 = theme.PrimaryText,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = card,
    })
    self:_track(title, "TextColor3", "PrimaryText")

    local content = Create("TextLabel", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 30),
        Size = UDim2.new(1, -24, 1, -38),
        Font = Enum.Font.Ubuntu,
        Text = contentStr,
        TextColor3 = theme.SecondaryText,
        TextSize = 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })
    self:_track(content, "TextColor3", "SecondaryText")

    local timerBar = Create("Frame", {
        Name = "Timer",
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 3),
        Parent = card,
    })
    self:_trackAccent(timerBar, function(accent) timerBar.BackgroundColor3 = accent end)

    local clickBtn = Create("TextButton", {
        Name = "ClickToClose",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Text = "",
        Size = UDim2.fromScale(1, 1),
        ZIndex = 10,
        Parent = card,
    })

    local dismissed = false
    local timerTween: Tween? = nil

    TweenService:Create(slot, MEDIUM, {
        Size = UDim2.new(0, width, 0, height),
    }):Play()
    TweenService:Create(card,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 2, 0, 2) }
    ):Play()

    local function dismiss()
        if dismissed then return end
        dismissed = true
        if timerTween then timerTween:Cancel() end

        local slideOut = TweenService:Create(card,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(-1, -12, 0, 2) }
        )
        slideOut:Play()
        slideOut.Completed:Once(function()
            local collapse = TweenService:Create(slot, FAST, {
                Size = UDim2.new(0, width, 0, 0),
            })
            collapse:Play()
            collapse.Completed:Once(function()
                slot:Destroy()
            end)
        end)
    end

    clickBtn.MouseButton1Click:Connect(function()
        if config.Callback then task.spawn(config.Callback) end
        dismiss()
    end)

    timerTween = TweenService:Create(timerBar,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, 3) }
    )
    timerTween:Play()
    timerTween.Completed:Once(function(state)
        if state == Enum.PlaybackState.Completed then
            dismiss()
        end
    end)

    local api = {}
    function api:Close() dismiss() end
    function api:SetTitle(t: string) title.Text = t end
    function api:SetContent(t: string) content.Text = t end
    return api
end

-- ========================================================================
-- library entry
-- ========================================================================

function Nexo.CreateWindow(config: {
	Title: string?,
	Icon: (string | number)?,
	Size: UDim2?,
	Theme: {[string]: any}?,
	})
	config = config or {}
	
	

	    local theme = table.clone(DefaultTheme)
    if config.Theme then
        for k, v in pairs(config.Theme) do
            theme[k] = v
        end
    end

    for k, v in pairs(DefaultTheme) do
        if theme[k] == nil then
            theme[k] = v
        end
    end

	local self_win = setmetatable({}, Window)
	self_win._theme = theme
	self_win._themed = {}
	self_win._tabs = {}
	self_win._activeTab = nil
	self_win._minimized = false

	local notifyGui = Create("ScreenGui", {
		Name = "NexoNotify",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 9999,
		Parent = GetGuiParent(),
	})

	local notifyHolder = Create("Frame", {
        Name = "NotificationsHolder",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 260, 1, 0),
        Parent = notifyGui,
    })
	Create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notifyHolder,
		Padding = UDim.new(0, 8),
	})
	Create("UIPadding", {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		Parent = notifyHolder,
	})

	self_win._notifyGui = notifyGui
	self_win._notifyHolder = notifyHolder
	self_win._notifyOrder = 0

	local screenGui = Create("ScreenGui", {
		Name = "NexoLib",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = GetGuiParent(),
	})

	local defaultSize = config.Size or UDim2.fromOffset(700, 800)
	
	local sizeX = defaultSize.X.Offset
	local sizeY = defaultSize.Y.Offset

	if sizeX == 0 then sizeX = 700 end
	if sizeY == 0 then sizeY = 800 end
	
	local main = Create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = theme.WindowBackground,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0.5, -(sizeX / 2), 0.5, -(sizeY / 2)),
		Size = defaultSize,
		Parent = screenGui,
	})
	ApplyCorner(main, 3)
	Create("UIStroke", { Color = theme.MainStroke, Transparency = 0.7, Parent = main })

	-- background gradient
	local bgHolder = Create("Frame", {
		Name = "BackgroundGradientHolder",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = -1,
		Parent = main,
	})
	ApplyCorner(bgHolder, 3)
	local bgGradient = Create("UIGradient", {
		Rotation = -165,
		Color = ColorSequence.new(theme.Accent),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.552, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = bgHolder,
	})

	-- topbar
	local topbar = Create("Frame", {
		Name = "Topbar",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(85, 85, 85),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, 0, 0, 35),
		Parent = main,
	})
	ApplyCorner(topbar, 4, 4, 4, 0, 0)
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 5),
		PaddingRight = UDim.new(0, 5),
		Parent = topbar,
	})

	local logo = Create("ImageLabel", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Image = ResolveIcon(config.Icon or 10747373176),
		Parent = topbar,
	})

	local titleLabel = Create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.Ubuntu,
		Text = config.Title or "Nexo",
		TextColor3 = theme.TitleText,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topbar,
	})
	Create("UIPadding", {
		PaddingBottom = UDim.new(0, 1),
		PaddingLeft = UDim.new(0, 30),
		Parent = titleLabel,
	})

	local minimizeBtn = Create("ImageButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 1),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -30, 1, -4),
		Size = UDim2.fromOffset(24, 24),
		Image = "rbxassetid://78357418744409",
		Parent = topbar,
	})

	local closeBtn = Create("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 1, -4),
		Size = UDim2.fromOffset(24, 24),
		Image = "rbxassetid://84425520427816",
		Parent = topbar,
	})

	local settingsBtn = Create("ImageButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(1, 1),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -60, 1, -4),
		Size = UDim2.fromOffset(24, 24),
		Image = ResolveIcon(10734950309),
		Parent = topbar,
	})

	-- container
	local container = Create("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = main,
	})
	ApplyCorner(container, 4)
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 40),
		PaddingLeft = UDim.new(0, 5),
		PaddingRight = UDim.new(0, 5),
		Parent = container,
	})

	-- navigation
	local navScroller = Create("ScrollingFrame", {
		Name = "NavigationScroller",
		BackgroundColor3 = theme.NavigationBackground,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		Selectable = false,
		Size = UDim2.new(1, 0, 0, 30),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 1,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = container,
	})
	ApplyCorner(navScroller, 2)
	Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = navScroller })

	local navContainer = Create("Frame", {
		Name = "NavigationContainer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = navScroller,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 3),
		PaddingLeft = UDim.new(0, 5),
		Parent = navContainer,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 3),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = navContainer,
	})

	-- tab container
	local tabContainer = Create("Frame", {
		Name = "TabContainer",
		BackgroundColor3 = theme.TabBackground,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 1, -40),
		Parent = container,
	})
	ApplyCorner(tabContainer, 4)
	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = tabContainer,
	})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		Parent = tabContainer,
	})

	    local searchHolder = Create("Frame", {
        Name = "SearchHolder",
        BackgroundColor3 = theme.HolderColor,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 35),
        Parent = tabContainer,
    })
    ApplyCorner(searchHolder, 3)
    self_win:_track(searchHolder, "BackgroundColor3", "HolderColor")
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 86, 89)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }),
        Parent = searchHolder,
    })
    local searchStroke = Create("UIStroke", { Color = theme.Stroke, Transparency = 0.9, Parent = searchHolder })
    self_win:_track(searchStroke, "Color", "Stroke")
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 22),
        Parent = searchHolder,
    })
    Create("ImageLabel", {
        Name = "SearchIcon",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(20, 20),
        Image = ResolveIcon(10734943674),
        Parent = searchHolder,
    })
    local searchInput = Create("TextBox", {
        Name = "SearchInput",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(23, 0),
        Size = UDim2.new(1, -40, 1, 0),
        FontFace = MakeFont("Arial"),
        PlaceholderText = "Search...",
        PlaceholderColor3 = theme.SecondaryText,
        Text = "",
        TextColor3 = theme.PrimaryText,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = searchHolder,
    })
    self_win:_track(searchInput, "TextColor3", "PrimaryText")
    self_win:_track(searchInput, "PlaceholderColor3", "SecondaryText")
    Create("ImageButton", {
        Name = "ClearBtn",
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        Image = ResolveIcon(10723346158),
        Parent = searchHolder,
    })

	local tabHolder = Create("Frame", {
		Name = "TabHolder",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 1, -40),
		Parent = tabContainer,
	})
	
	local settingsPage = Create("Frame", {
		Name = "SettingsTab",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.99,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = tabHolder,
	})
	self_win._settingsPage = settingsPage
	
	-- resize handle
	local resizeHandle = Create("Frame", {
		Name = "ResizeBottomLeft",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 5, 1, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = container,
	})
	local resizer = Create("TextButton", {
		Name = "Resizer",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = resizeHandle,
	})

	-- store references
	self_win:_track(main, "BackgroundColor3", "WindowBackground")
	self_win:_track(titleLabel, "TextColor3", "TitleText")
	self_win.ScreenGui = screenGui
	self_win.Main = main
	self_win.TitleLabel = titleLabel
	self_win._tabHolder = tabHolder
	self_win._navContainer = navContainer
	self_win._searchInput = searchInput

	-- search hover / focus stroke behaviour
	searchHolder.MouseEnter:Connect(function()
		TweenService:Create(searchStroke, FAST, { Transparency = 0.65 }):Play()
	end)
	searchHolder.MouseLeave:Connect(function()
		if not searchInput:IsFocused() then
			TweenService:Create(searchStroke, FAST, { Transparency = 0.9 }):Play()
		end
	end)
	searchInput.Focused:Connect(function()
		TweenService:Create(searchStroke, FAST, { Transparency = 0.65 }):Play()
	end)
	searchInput.FocusLost:Connect(function()
		TweenService:Create(searchStroke, FAST, { Transparency = 0.9 }):Play()
	end)

	-- topbar button hover behaviour (no click animation)
	for _, btn in ipairs({ minimizeBtn, closeBtn, settingsBtn }) do
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, FAST, { ImageTransparency = 0.4 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, FAST, { ImageTransparency = 0 }):Play()
		end)
	end

	-- close hides the window
	closeBtn.MouseButton1Click:Connect(function()
		self_win:Hide()
	end)

	-- minimize collapses down to the topbar
	minimizeBtn.MouseButton1Click:Connect(function()
		if self_win._minimizeAnimating then
			return
		end
		self_win._minimizeAnimating = true

		self_win._minimized = not self_win._minimized

		if self_win._minimized then
			self_win._restoreSize = self_win._restoreSize or main.Size
			if main.Size.Y.Offset > 35 then
				self_win._restoreSize = main.Size
			end

			local tween = TweenService:Create(main, MEDIUM, {
				Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 35),
			})
			tween:Play()
			tween.Completed:Once(function()
				self_win._minimizeAnimating = false
			end)
		else
			local tween = TweenService:Create(main, MEDIUM, {
				Size = self_win._restoreSize or defaultSize,
			})
			tween:Play()
			tween.Completed:Once(function()
				self_win._minimizeAnimating = false
			end)
		end
	end)

	-- window dragging via topbar
	do
		local dragging = false
		local dragStart, startPos
		local targetPos

		topbar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
				targetPos = main.Position
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				targetPos = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
				TweenService:Create(main, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = targetPos,
				}):Play()
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- window resizing via bottom-right handle
	do
		local resizing = false
		local resizeStart, startSize
		local minSize = Vector2.new(400, 300)

		resizer.InputBegan:Connect(function(input)
			if self_win._minimized then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStart = input.Position
				startSize = main.AbsoluteSize
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - resizeStart
				local newX = math.max(minSize.X, startSize.X + delta.X)
				local newY = math.max(minSize.Y, startSize.Y + delta.Y)
				main.Size = UDim2.fromOffset(newX, newY)
				if not self_win._minimized then
					self_win._restoreSize = main.Size
				end
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end)
	end

	self_win._settingsOpen = false
	
	settingsBtn.MouseButton1Click:Connect(function()
		if self_win._settingsOpen then
			return
		end

		self_win._settingsOpen = true

		for _, tab in ipairs(self_win._tabs) do
			tab.Root.Visible = false
		end

		settingsPage.Visible = true
		self_win:_updateNav()
		self_win:_runSearch()
	end)

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		self_win:_runSearch()
	end)
	local searchClear = searchHolder:FindFirstChild("ClearBtn")

	if searchClear and searchClear:IsA("ImageButton") then
		searchClear.MouseButton1Click:Connect(function()
			searchInput.Text = ""
			self_win:_runSearch()
		end)
	end
	
	-- build settings as an internal tab-like object
	local settingsTab = setmetatable({}, Tab)
	settingsTab._window = self_win
	settingsTab._categories = {}
	settingsTab._hovered = false
	settingsTab.Root = settingsPage

	local sSection1 = Create("ScrollingFrame", {
		Name = "Section1", Active = true, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(0.5, 1), CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = settingsPage,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = sSection1 })
	Create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = sSection1 })

	local sSection2 = Create("ScrollingFrame", {
		Name = "Section2", Active = true, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = settingsPage,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = sSection2 })
	Create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = sSection2 })

	Create("Frame", {
		Name = "SeperatorBar", AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(66, 112, 121), BackgroundTransparency = 0.8,
		BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, -8),
		Parent = settingsPage,
	})

	settingsTab.Section1 = sSection1
	settingsTab.Section2 = sSection2
	self_win._settingsTab = settingsTab

	-- default interface category with accent + theme controls
	local themeCat = settingsTab:AddCategory({ Title = "Interface", Icon = "palette", Side = "Left" })
	themeCat:AddColorPicker({
		Title = "Accent Color",
		Description = "Changes highlight color",
		Default = self_win._theme.Accent,
		Callback = function(color)
			self_win:SetAccent(color)
		end,
	})
	themeCat:AddDropdown({
        Title = "Theme Preset",
        Description = "Switch base theme",
        Values = { "Default", "Dark", "Light", "Midnight", "Amoled" },
        Default = "Default",
        Searchable = false,
        Callback = function(preset)
            self_win:SetThemePreset(preset)
        end,
    })
	themeCat:AddSlider({
    Title = "Window Opacity",
    Description = "Background transparency",
    Min = 0, Max = 80, Default = 3, Suffix = "%",
    Callback = function(v)
        main.BackgroundTransparency = v / 100
    end,
	})
	local behaviorCat = settingsTab:AddCategory({ Title = "Behavior", Icon = "settings", Side = "Right" })
	behaviorCat:AddKeybind({
    Title = "Toggle UI",
    Description = "Show/hide the window",
    Default = Enum.KeyCode.RightShift,
    Callback = function()
        self_win:ToggleVisibility()
    end,
	})
	behaviorCat:AddButton({
    Title = "Unload",
    Description = "Removes the UI completely",
    Icon = "trash-2",
    Callback = function()
        self_win:UnloadGui()
    end,
	})

	self_win.GetSettingsTab = function()
		return settingsTab
	end

	return self_win
end

return Nexo
