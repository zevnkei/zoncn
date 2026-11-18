local TweenService = game:GetService("TweenService")

local Switch = {}
Switch.__index = Switch

local DEFAULT_THEME = {
    Track = Color3.fromRGB(45, 45, 45),
    TrackOn = Color3.fromRGB(90, 200, 120),
    Knob = Color3.fromRGB(255, 255, 255),
    TrackWidth = 44,
    TrackHeight = 24,
    KnobSize = 18,
    PressStretch = 6,
    IconSize = 12,
    TweenTime = 0.15,
}

-- config: Name, Default, Callback, Icon, OnIcon, OffIcon
-- Icon is shown in both states; OnIcon / OffIcon (or ActiveIcon / InactiveIcon) override it per state
function Switch.new(parent, config, theme, deps)
    config = config or {}
    local Spring = deps and deps.Spring
    assert(Spring, "Switch needs deps.Spring")
    local Icons = deps.Icons -- optional

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local iconOff = t.IconOff or t.Track
    local iconOn = t.IconOn or t.TrackOn
    local pad = (t.TrackHeight - t.KnobSize) / 2
    local travel = t.TrackWidth - pad * 2

    local self = setmetatable({}, Switch)
    self.State = config.Default and true or false
    self.Callback = config.Callback or function() end
    self.Theme = t
    self.Connections = {}

    local track = Instance.new("TextButton")
    track.Name = config.Name or "Switch"
    track.Text = ""
    track.AutoButtonColor = false
    track.Size = UDim2.fromOffset(t.TrackWidth, t.TrackHeight)
    track.BorderSizePixel = 0
    track.BackgroundColor3 = self.State and t.TrackOn or t.Track
    track.Parent = parent

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(t.KnobSize, t.KnobSize)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = self.State and (t.KnobOn or t.Knob) or t.Knob
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    -- icons: fixed size and centered, so the knob stretching never distorts them
    local function createIcon(path)
        local icon = Instance.new("ImageLabel")
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.Size = UDim2.fromOffset(t.IconSize, t.IconSize)
        icon.BackgroundTransparency = 1
        icon.BorderSizePixel = 0
        icon.Parent = knob

        if Icons then
            Icons.apply(icon, "Image", path)
        else
            icon.Image = path
        end

        local scale = Instance.new("UIScale")
        scale.Parent = icon

        return icon, scale
    end

    local onPath = config.OnIcon or config.ActiveIcon or config.Icon
    local offPath = config.OffIcon or config.InactiveIcon or config.Icon

    local sharedIcon, onIcon, onScale, offIcon, offScale

    if onPath ~= nil and onPath == offPath then
        -- same icon in both states: it stays put and only changes color
        sharedIcon = createIcon(onPath)
    else
        if onPath then
            onIcon, onScale = createIcon(onPath)
            onIcon.ImageColor3 = iconOn
        end
        if offPath then
            offIcon, offScale = createIcon(offPath)
            offIcon.ImageColor3 = iconOff
        end
    end

    -- c: 0 = off, 1 = on, driven by the knob's own position so the icons swap as it travels
    local function paintIcons(c)
        if sharedIcon then
            sharedIcon.ImageColor3 = iconOff:Lerp(iconOn, c)
            return
        end

        if onIcon then
            onIcon.ImageTransparency = 1 - c
            onScale.Scale = 0.6 + 0.4 * c
        end
        if offIcon then
            offIcon.ImageTransparency = c
            offScale.Scale = 0.6 + 0.4 * (1 - c)
        end
    end

    -- knob position: 0 = left (off), 1 = right (on)
    self.KnobX = Spring.new(self.State and 1 or 0, 260, 20)
    -- knob width: stretches while pressed
    self.KnobW = Spring.new(t.KnobSize, 320, 22)

    self.KnobX.OnChanged = function(a)
        -- anchored to the side it's heading to, so stretching grows inward and never past the track
        knob.AnchorPoint = Vector2.new(a, 0.5)
        knob.Position = UDim2.new(0, pad + a * travel, 0.5, 0)
        paintIcons(math.clamp(a, 0, 1))
    end
    self.KnobW.OnChanged = function(w)
        knob.Size = UDim2.fromOffset(w, t.KnobSize)
    end
    self.KnobX.OnChanged(self.KnobX.Value)

    self.Track = track
    self.Knob = knob

    table.insert(self.Connections, track.MouseButton1Click:Connect(function()
        self:Set(not self.State)
    end))
    table.insert(self.Connections, track.MouseButton1Down:Connect(function()
        self.KnobW:SetTarget(t.KnobSize + t.PressStretch)
    end))
    table.insert(self.Connections, track.MouseButton1Up:Connect(function()
        self.KnobW:SetTarget(t.KnobSize)
    end))
    -- released outside the switch: Up never fires on it, so reset here too
    table.insert(self.Connections, track.MouseLeave:Connect(function()
        self.KnobW:SetTarget(t.KnobSize)
    end))

    return self
end

function Switch:Set(state, silent)
    self.State = state and true or false

    self.KnobX:SetTarget(self.State and 1 or 0)

    local info = TweenInfo.new(self.Theme.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(self.Track, info, {
        BackgroundColor3 = self.State and self.Theme.TrackOn or self.Theme.Track,
    }):Play()
    TweenService:Create(self.Knob, info, {
        BackgroundColor3 = self.State and (self.Theme.KnobOn or self.Theme.Knob) or self.Theme.Knob,
    }):Play()

    if not silent then
        self.Callback(self.State)
    end
end

function Switch:Toggle()
    self:Set(not self.State)
end

function Switch:Get()
    return self.State
end

function Switch:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.KnobX:Destroy()
    self.KnobW:Destroy()
    self.Track:Destroy()
end

return Switch
