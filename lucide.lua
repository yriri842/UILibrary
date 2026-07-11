-- ImageRectSize and ImageRectOffset will always return 0, this is because all icons have their own asset ID, Asphalt did this not me.
-- The only reason the two arguments still exist is for backwards compatibility support with lucide-roblox.

local RunService = game:GetService("RunService")

export type Asset = {
	IconName: string, -- "icon-name"
	Id: number, -- 123456789
	Url: string, -- "rbxassetid://123456789"
	ImageRectSize: Vector2, -- Vector2.new(0, 0)
	ImageRectOffset: Vector2, -- Vector2.new(0, 0)
}

-- local Icons = require(script.Icons) or loadstring(game:HttpGet'https://raw.githubusercontent.com/yriri842/UILibrary/refs/heads/main/icons.lua')()
local Icons;
if RunService:IsStudio() then Icons = require(script.Icons) else loadstring(game:HttpGet'https://raw.githubusercontent.com/yriri842/UILibrary/refs/heads/main/icons.lua')() end

local Type = typeof or type
local function CheckArgTypes(funcName: string, inputArgs: {any}, typeEntries: {[number]: {string}})
	for ArgIndex, TypeEntryArray in typeEntries do
		local ArgName = TypeEntryArray[1]
		local ExpectedType = TypeEntryArray[2]

		local InputArg = inputArgs[ArgIndex]
		local InputArgType = Type(InputArg)

		if InputArgType ~= ExpectedType then
			error("[LucideRoblox] " .. funcName .. ": Argument " .. ArgIndex .. " (" .. ArgName .. "): expected type `" .. ExpectedType .. "`, got `" .. InputArgType .. "`", 3)
		end
	end
end

local function TrimIconIdentifier(inputIconIdentifier: string): string
	return string.match(string.lower(inputIconIdentifier), "^%s*(.*)%s*$") :: string
end

local function ApplyToInstance(object: Instance, properties: {[string]: any}): Instance
	if properties then
		for Property, Value in properties do
			if Property ~= "Parent" then
				object[Property] = Value
			end
		end

		if properties.Parent then
			object.Parent = properties.Parent
		end
	end

	return object
end

local LucideRoblox = {}

do
	local IconNames: {string} = {}
	local _, FirstIconIndex = next(Icons)
	FirstIconIndex = FirstIconIndex or {}

	for IconName in FirstIconIndex do
		table.insert(IconNames, IconName)
	end

	table.sort(IconNames)
	table.freeze(IconNames)
	LucideRoblox.IconNames = IconNames
end

--[[
    Attempts to retrieve and wrap an asset object from a specified icon name, with
    an optional target icon size argument, fetching the closest to what's supported

    *Will* throw an error if the icon name provided is invalid/not found

    *Example:*
    ```lua
    local Asset = LucideRoblox.GetAsset("server", 48) -- iconSize will default to `256` if not provided
    assert(Asset, "Failed to fetch asset!")

    print(Asset.IconName) -- "server"
    print(Asset.Id) -- 140655592907365
    print(Asset.Url) -- "rbxassetid://140655592907365"
    print(Asset.ImageRectSize) -- Vector2.new(0, 0)
    print(Asset.ImageRectOffset) -- Vector2.new(0, 0)
    ```
]]
function LucideRoblox.GetAsset(iconName: string, iconSize: number): Asset
	local IconSize = if iconSize ~= nil then iconSize else 256
	
	CheckArgTypes("Lucide.GetAsset", {iconName, IconSize}, {
		[1] = {"iconName", "string"},
		[2] = {"iconSize", "number"},
	})
	
	local IconName = TrimIconIdentifier(iconName)
	
	-- If reading directly from a UI obj w/ a negative size..?
	if IconSize < 0 then
		IconSize = -IconSize
	end
	
	local RealSizeIndex = if IconSize <= 48 then "48" else "256"
	local IconIndexDict = Icons[RealSizeIndex]

	if not IconIndexDict then
		error("[LucideRoblox] GetAsset: Internal error: Failed to find icon index for specified size")
	end

	local RawAsset = IconIndexDict[IconName]
	if not RawAsset then
		error("[LucideRoblox] GetAsset: Failed to find icon by the name of \"" .. IconName .. "\" (@" .. RealSizeIndex .. "), perhaps a spelling mistake?", 2)
	end

	local Id = RawAsset
	local Url = "rbxassetid://" .. Id

	local Asset: Asset = {
		IconName = IconName,
		Id = Id,
		Url = Url,
		ImageRectSize = Vector2.new(0, 0),
		ImageRectOffset = Vector2.new(0, 0),
	}

	return Asset
end

--[[
    Returns a dictionary of every `Asset` from every icon name in `LucideRoblox.IconNames`

    This could also be useful for, for example, working with a custom asset
    preloading system via `ContentProvider:PreloadAsync()` etc

    *Example:*
    ```lua
    local AllAssets = LucideRoblox.GetAllAssets(256) -- Also defaults to `256`, just like `LucideRoblox.GetAsset()`

    for _, Asset in AllAssets do
        print(Asset.IconName, Asset.Url)
    end
    ```
]]
function LucideRoblox.GetAllAssets(inputSize: number?): {Asset}
	local InputSize = if inputSize == nil then 256 else inputSize

	CheckArgTypes("Lucide.GetAllAssets", {InputSize}, {
		[1] = {"inputSize", "number"},
	})

	local Assets = {}

	for _, IconName in LucideRoblox.IconNames do
		local Asset = LucideRoblox.GetAsset(IconName, InputSize)
		if Asset then
			table.insert(Assets, Asset)
		end
	end

	-- `Lucide.IconNames` is already pre-sorted
	return Assets
end

--[[
    Wrapper around `LucideRoblox.GetAsset()` that fetches asset info for the specified
    icon name and size, anc creates an `ImageLabel` Instance. Accepts an additional
    optional argument for providing a table of properties to automatically apply
    after the asset has been applied to said `ImageLabel`

    Without providing any extra property overrides, the icon is colored to its
    default of #FFFFFF, and theinput from the `imageSize` argument is the
    offset value of `ImageLabel.Size`

    Throws an error under the same terms as `LucideRoblox.GetAsset()`

    *Example:*
    ```lua
    local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
    local ScreenGui = Instance.new("ScreenGui")

    LucideRoblox.ImageLabel("server-crash", 256, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),

        Parent = ScreenGui,
    })

    ScreenGui.Parent = PlayerGui
    ```
]]
function LucideRoblox.ImageLabel(iconName: string, imageSize: number?, propertyOverrides: {[string]: any}?): ImageLabel
	local ImageSize = if imageSize == nil then 256 else imageSize
	local PropertyOverrides = if propertyOverrides == nil then {} else propertyOverrides

	CheckArgTypes("Lucide.ImageLabel", {iconName, imageSize, propertyOverrides}, {
		[1] = {"iconName", "string"},
		[2] = {"imageSize", "number"},
		[3] = {"propertyOverrides", "table"}
	})

	local Asset = LucideRoblox.GetAsset(iconName, ImageSize)

	local ImageLabel = ApplyToInstance(Instance.new("ImageLabel"), {
		Name = Asset.IconName,

		Size = UDim2.fromOffset(ImageSize, ImageSize),

		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		Image = Asset.Url,
		ImageRectSize = Asset.ImageRectSize,
		ImageRectOffset = Asset.ImageRectOffset,
		ImageColor3 = Color3.new(1, 1, 1), -- #FFFFFF
		ScaleType = Enum.ScaleType.Fit,
	})

	-- Apply any provided overrides
	ApplyToInstance(ImageLabel, PropertyOverrides)

	return ImageLabel
end

table.freeze(LucideRoblox)
return LucideRoblox
