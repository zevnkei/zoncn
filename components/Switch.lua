local TweenService = game:GetService("TweenService")

local Switch = {}
Switch.__index = Switch

local DEFAULT_THEME = {
    Track = Color3.fromRGB(45, 45, 45),
    TrackOn = Color3.fromRGB(90, 200, 120),
    Knob = Color3.fromRGB(255, 255, 255),
    TweenTime = 0.15,
}

function Switch.new(parent, config, theme)
    config = config or {}

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Switch)
    self.State = config.Default and true or false
    self.Callback = config.Callback or function() end
    self.Theme = t

    local track = Instance.new("TextButton")
    track.Name = config.Name or "Switch"
    track.Text = ""
    track.AutoButtonColor = false
    track.Size = UDim2.new(0, 44, 0, 24)
    track.BorderSizePixel = 0
    track.BackgroundColor3 = t.Track
    track.Parent = parent

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = t.Knob
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    self.Track = track
    self.Knob = knob

    track.MouseButton1Click:Connect(function()
        self:Set(not self.State)
    end)

    self:Set(self.State, true) -- set initial visuals without firing callback

    return self
end

function Switch:Set(state, silent)
    self.State = state and true or false

    local info = TweenInfo.new(self.Theme.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    TweenService:Create(self.Knob, info, {
        Position = self.State and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
    }):Play()

    TweenService:Create(self.Track, info, {
        BackgroundColor3 = self.State and self.Theme.TrackOn or self.Theme.Track,
    }):Play()

    if not silent then
        self.Callback(self.State)
    end
end

function Switch:Get()
    return self.State
end

function Switch:Destroy()
    self.Track:Destroy()
end

return Switch
