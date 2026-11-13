local UserInputService = game:GetService("UserInputService")

local Slider = {}
Slider.__index = Slider

local DEFAULT_THEME = {
    Track = Color3.fromRGB(45, 45, 45),
    Fill = Color3.fromRGB(90, 200, 120),
    Knob = Color3.fromRGB(255, 255, 255),
    TrackHeight = 6,
    KnobSize = 14,
}

function Slider.new(parent, config, theme)
    config = config or {}

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Slider)
    self.Min = config.Min or 0
    self.Max = config.Max or 100
    self.Increment = config.Increment
    self.Callback = config.Callback or function() end
    self.Value = self.Min
    self.Dragging = false
    self.Connections = {}

    local root = Instance.new("Frame")
    root.Name = config.Name or "Slider"
    root.Size = UDim2.new(1, 0, 0, 24)
    root.BackgroundTransparency = 1
    root.Parent = parent

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, t.TrackHeight)
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.Position = UDim2.new(0, 0, 0.5, 0)
    track.BorderSizePixel = 0
    track.BackgroundColor3 = t.Track
    track.Parent = root

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
    knob.Size = UDim2.new(0, t.KnobSize, 0, t.KnobSize)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = t.Knob
    knob.Parent = root

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    self.Root = root
    self.Track = track
    self.Fill = fill
    self.Knob = knob

    table.insert(self.Connections, root.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Dragging = true
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
            self.Dragging = false
        end
    end))

    self:Set(config.Default or self.Min, true)

    return self
end

function Slider:_setFromX(x)
    local left = self.Track.AbsolutePosition.X
    local width = self.Track.AbsoluteSize.X
    if width <= 0 then return end

    local alpha = math.clamp((x - left) / width, 0, 1)
    self:Set(self.Min + alpha * (self.Max - self.Min))
end

function Slider:Set(value, silent)
    value = math.clamp(value, self.Min, self.Max)

    if self.Increment then
        value = math.floor(value / self.Increment + 0.5) * self.Increment
        value = math.clamp(value, self.Min, self.Max)
    end

    self.Value = value

    local range = self.Max - self.Min
    local alpha = range > 0 and (value - self.Min) / range or 0

    self.Fill.Size = UDim2.new(alpha, 0, 1, 0)
    self.Knob.Position = UDim2.new(alpha, 0, 0.5, 0)

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
    self.Root:Destroy()
end

return Slider
