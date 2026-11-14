local TweenService = game:GetService("TweenService")

local TextArea = {}
TextArea.__index = TextArea

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(60, 60, 60),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    Corner = 5,
    InnerPadding = 8,
    StrokeThickness = 2,
    FocusTransparency = 0.5,
    MinHeight = 80,
    MaxHeight = 250,
    TweenTime = 0.15,
}

local function setFont(label, font)
    if typeof(font) == "Font" then
        label.FontFace = font
    else
        label.Font = font
    end
end

-- config: Name, Default, Placeholder, ResetOnFocus, MinHeight, MaxHeight, Callback, Changed
-- the box grows with its text between MinHeight and MaxHeight
-- Callback(text, enterPressed) runs when focus is lost, Changed(text) on every edit
function TextArea.new(parent, config, theme, deps)
    config = config or {}
    local TextFit = deps and deps.TextFit
    assert(TextFit, "TextArea needs deps.TextFit")

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local minHeight = config.MinHeight or t.MinHeight
    local maxHeight = config.MaxHeight or t.MaxHeight
    local inner = t.InnerPadding

    local self = setmetatable({}, TextArea)
    self.Theme = t
    self.Callback = config.Callback or function() end
    self.Changed = config.Changed or function() end
    self.Focused = false
    self.Setting = false
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local outline = Instance.new("Frame")
    outline.Name = config.Name or "TextArea"
    outline.Size = UDim2.new(1, 0, 0, minHeight)
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
    box.Position = UDim2.fromOffset(inner, inner)
    box.Size = UDim2.new(1, -inner * 2, 1, -inner * 2)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = config.ResetOnFocus or false
    box.MultiLine = true
    box.TextWrapped = true
    box.TextSize = t.TextSize
    box.TextColor3 = t.Foreground
    box.PlaceholderColor3 = t.Muted
    box.PlaceholderText = config.Placeholder or "Type here..."
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Text = config.Default or ""
    box.ZIndex = 2
    box.Parent = outline
    setFont(box, t.Font)

    self.Outline = outline
    self.Box = box
    self.Stroke = stroke

    self.Auto = TextFit.bind({
        TextObject = box,
        Target = outline,
        Axis = "Y",
        Min = minHeight,
        Max = maxHeight,
        Padding = inner * 2,
    })

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

function TextArea:Set(text, silent)
    self.Setting = true
    self.Box.Text = text or ""
    self.Setting = false

    if not silent then
        self.Callback(self.Box.Text, false)
    end
end

function TextArea:Get()
    return self.Box.Text
end

function TextArea:Focus()
    self.Box:CaptureFocus()
end

function TextArea:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Auto.Destroy()
    self.Outline:Destroy()
end

return TextArea
