local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Slider = {}
Slider.__index = Slider

local DEFAULT_THEME = {
    Track = Color3.fromRGB(45, 45, 45),
    Fill = Color3.fromRGB(90, 200, 120),
    Knob = Color3.fromRGB(255, 255, 255),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    TrackHeight = 6,
    KnobSize = 14,
    KnobStretch = 1.3,
    IconSize = 16,
    IconGap = 10,
    TweenTime = 0.2,
}

-- config: Name, Min, Max, Default, Increment, StartIcon, EndIcon, Callback, OnComplete
-- Callback(value) runs while dragging, OnComplete(value) once when you let go
function Slider.new(parent, config, theme, deps)
    config = config or {}
    local Spring = deps and deps.Spring
    assert(Spring, "Slider needs deps.Spring")
    local Icons = deps.Icons -- optional

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Slider)
    self.Theme = t
    self.Min = config.Min or 0
    self.Max = config.Max or 100
    self.Increment = config.Increment or config.Step
    self.Callback = config.Callback or function() end
    self.OnComplete = config.OnComplete or function() end
    self.Dragging = false
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    self.Value = self:_normalize(config.Default or self.Min)

    local root = Instance.new("Frame")
    root.Name = config.Name or "Slider"
    root.Size = UDim2.new(1, 0, 0, 24)
    root.BackgroundTransparency = 1
    root.Parent = parent

    local function createIcon(path, alignment)
        local icon = Instance.new("ImageLabel")
        icon.AnchorPoint = Vector2.new(alignment, 0.5)
        icon.Position = UDim2.new(alignment, 0, 0.5, 0)
        icon.Size = UDim2.fromOffset(t.IconSize, t.IconSize)
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0
        icon.ImageColor3 = t.Muted
        icon.Parent = root

        if Icons then
            Icons.apply(icon, "Image", path)
        else
            icon.Image = path
        end

        return icon
    end

    -- the icons take space on the sides, the track fills what's left
    local leftInset, rightInset = 0, 0

    if config.StartIcon then
        self.StartIcon = createIcon(config.StartIcon, 0)
        leftInset = t.IconSize + t.IconGap
    end
    if config.EndIcon then
        self.EndIcon = createIcon(config.EndIcon, 1)
        rightInset = t.IconSize + t.IconGap
    end

    -- press area: everything between the icons
    local hit = Instance.new("Frame")
    hit.Position = UDim2.fromOffset(leftInset, 0)
    hit.Size = UDim2.new(1, -(leftInset + rightInset), 1, 0)
    hit.BackgroundTransparency = 1
    hit.BorderSizePixel = 0
    hit.Parent = root

    -- the rail is inset so the knob (even fully stretched) never sticks out past the ends
    local edge = math.ceil(t.KnobSize * t.KnobStretch / 2)
    local rail = Instance.new("Frame")
    rail.Position = UDim2.fromOffset(edge, 0)
    rail.Size = UDim2.new(1, -edge * 2, 1, 0)
    rail.BackgroundTransparency = 1
    rail.BorderSizePixel = 0
    rail.Parent = hit

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, t.TrackHeight)
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.Position = UDim2.new(0, 0, 0.5, 0)
    track.BorderSizePixel = 0
    track.BackgroundColor3 = t.Track
    track.Parent = rail

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = t.Fill
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.new(0, t.KnobSize, 0, t.KnobSize)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = t.Knob
    knob.Parent = rail

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    self.Root = root
    self.Track = track
    self.Fill = fill
    self.Knob = knob

    -- alpha: 0 to 1 position along the track
    local startAlpha = self:_alphaFor(self.Value)
    self.Alpha = Spring.new(startAlpha, 300, 24)
    self.KnobW = Spring.new(t.KnobSize, 360, 22)

    self.Alpha.OnChanged = function(a)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
    end
    self.KnobW.OnChanged = function(w)
        knob.Size = UDim2.new(0, w, 0, t.KnobSize)
    end
    self.Alpha.OnChanged(startAlpha)

    table.insert(self.Connections, hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Dragging = true
            self.KnobW:SetTarget(t.KnobSize * t.KnobStretch)
            self:_setIcons(true)
            self:_setFromX(input.Position.X)
        end
    end))

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if self.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            self:_setFromX(input.Position.X)
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if self.Dragging then
                self.Dragging = false
                self.KnobW:SetTarget(t.KnobSize)
                self:_setIcons(false)
                self.OnComplete(self.Value)
            end
        end
    end))

    return self
end

function Slider:_alphaFor(value)
    local range = self.Max - self.Min
    return range > 0 and (value - self.Min) / range or 0
end

-- clamp to the range and snap to Increment
function Slider:_normalize(value)
    value = math.clamp(value, self.Min, self.Max)

    if self.Increment then
        value = math.floor((value - self.Min) / self.Increment + 0.5) * self.Increment + self.Min
        value = math.clamp(value, self.Min, self.Max)
    end

    return value
end

-- icons light up while dragging
function Slider:_setIcons(active)
    local color = active and self.Theme.Foreground or self.Theme.Muted

    if self.StartIcon then
        TweenService:Create(self.StartIcon, self.Info, {ImageColor3 = color}):Play()
    end
    if self.EndIcon then
        TweenService:Create(self.EndIcon, self.Info, {ImageColor3 = color}):Play()
    end
end

function Slider:_setFromX(x)
    local left = self.Track.AbsolutePosition.X
    local width = self.Track.AbsoluteSize.X
    if width <= 0 then return end

    local alpha = math.clamp((x - left) / width, 0, 1)
    self:Set(self.Min + alpha * (self.Max - self.Min))
end

function Slider:Set(value, silent)
    if type(value) ~= "number" then return end

    value = self:_normalize(value)

    self.Value = value
    self.Alpha:SetTarget(self:_alphaFor(value))

    if not silent then
        self.Callback(value)
    end
end

function Slider:Get()
    return self.Value
end

function Slider:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Alpha:Destroy()
    self.KnobW:Destroy()
    self.Root:Destroy()
end

return Slider
