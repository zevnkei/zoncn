local TweenService = game:GetService("TweenService")

local Input = {}
Input.__index = Input

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(60, 60, 60),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    Height = 26,
    Corner = 5,
    InnerPadding = 3,
    StrokeThickness = 2,
    FocusTransparency = 0.5,
    MinWidth = 40,
    MaxWidth = 150,
    Padding = 10,
    TweenTime = 0.15,
}

local function setFont(label, font)
    if typeof(font) == "Font" then
        label.FontFace = font
    else
        label.Font = font
    end
end

-- config: Name, Default, Placeholder, ResetOnFocus, AutoWidth, Align, Callback, Changed
-- Callback(text, enterPressed) runs when focus is lost, Changed(text) on every edit
function Input.new(parent, config, theme, deps)
    config = config or {}
    local TextFit = deps and deps.TextFit
    assert(TextFit, "Input needs deps.TextFit")

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Input)
    self.Theme = t
    self.Callback = config.Callback or function() end
    self.Changed = config.Changed or function() end
    self.Focused = false
    self.Setting = false
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- AutoWidth: the box grows with its text (between MinWidth and MaxWidth)
    local hug = config.AutoWidth or false

    local outline = Instance.new("Frame")
    outline.Name = config.Name or "Input"
    outline.Size = hug and UDim2.new(0, t.MinWidth, 0, t.Height) or UDim2.new(1, 0, 0, t.Height)
    outline.BackgroundColor3 = t.Background
    outline.BorderSizePixel = 0
    outline.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.Corner)
    corner.Parent = outline

    local stroke = Instance.new("UIStroke")
    stroke.Color = t.Border
    stroke.Thickness = t.StrokeThickness
    stroke.Transparency = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = outline

    local box = Instance.new("TextBox")
    box.Name = "Box"
    box.Size = UDim2.fromScale(1, 1)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = config.ResetOnFocus or false
    box.MultiLine = false
    box.TextWrapped = false
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.TextSize = t.TextSize
    box.TextColor3 = t.Foreground
    box.PlaceholderColor3 = t.Muted
    box.PlaceholderText = config.Placeholder or "Input here..."
    box.TextXAlignment = config.Align or Enum.TextXAlignment.Center
    box.Text = config.Default or ""
    box.ZIndex = 2
    box.Parent = outline
    setFont(box, t.Font)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, t.InnerPadding)
    pad.PaddingRight = UDim.new(0, t.InnerPadding)
    pad.Parent = box

    self.Outline = outline
    self.Box = box
    self.Stroke = stroke

    if hug then
        self.Auto = TextFit.bind({
            TextObject = box,
            Target = outline,
            Axis = "X",
            Min = t.MinWidth,
            Max = t.MaxWidth,
            Padding = t.Padding,
        })
    end

    table.insert(self.Connections, box.Focused:Connect(function()
        self.Focused = true
        TweenService:Create(stroke, self.Info, {Transparency = t.FocusTransparency}):Play()
    end))

    table.insert(self.Connections, box.FocusLost:Connect(function(enterPressed)
        self.Focused = false
        TweenService:Create(stroke, self.Info, {Transparency = 1}):Play()
        self.Callback(box.Text, enterPressed)
    end))

    table.insert(self.Connections, box:GetPropertyChangedSignal("Text"):Connect(function()
        if not self.Setting then
            self.Changed(box.Text)
        end
    end))

    return self
end

function Input:Set(text, silent)
    self.Setting = true
    self.Box.Text = text or ""
    self.Setting = false

    if not silent then
        self.Callback(self.Box.Text, false)
    end
end

function Input:Get()
    return self.Box.Text
end

function Input:Focus()
    self.Box:CaptureFocus()
end

function Input:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    if self.Auto then
        self.Auto.Destroy()
    end
    self.Outline:Destroy()
end

return Input
