local TweenService = game:GetService("TweenService")

local Button = {}
Button.__index = Button

local DEFAULT_THEME = {
    Background = Color3.fromRGB(13, 13, 13),
    Hover = Color3.fromRGB(28, 28, 28),
    Text = Color3.fromRGB(240, 245, 240),
    Height = 36,
    TweenTime = 0.12,
}

function Button.new(parent, config, theme)
    config = config or {}

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Button)
    self.Callback = config.Callback or function() end
    self.Theme = t

    local button = Instance.new("TextButton")
    button.Name = config.Name or "Button"
    button.Text = config.Name or "Button"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.TextColor3 = t.Text
    button.AutoButtonColor = false
    button.Size = UDim2.new(1, 0, 0, t.Height)
    button.BorderSizePixel = 0
    button.BackgroundColor3 = t.Background
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    local info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, info, {BackgroundColor3 = t.Hover}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, info, {BackgroundColor3 = t.Background}):Play()
    end)

    button.MouseButton1Click:Connect(function()
        self:Fire()
    end)

    self.Button = button
    return self
end

function Button:Fire()
    self.Callback()
end

function Button:Destroy()
    self.Button:Destroy()
end

return Button
