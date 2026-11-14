local TweenService = game:GetService("TweenService")

local Checkbox = {}
Checkbox.__index = Checkbox

local DEFAULT_THEME = {
    Box = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(60, 60, 60),
    Checked = Color3.fromRGB(90, 200, 120),
    Check = Color3.fromRGB(13, 13, 13),
    CheckImage = "rbxassetid://93898873302694", -- built-in check, used until / unless the icon pack loads
    Size = 20,
    Corner = 6,
    TweenTime = 0.15,
}

function Checkbox.new(parent, config, theme, deps)
    config = config or {}
    local Spring = deps and deps.Spring
    assert(Spring, "Checkbox needs deps.Spring")
    local Icons = deps.Icons -- optional, the built-in check image is used without it

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Checkbox)
    self.State = config.Default and true or false
    self.Callback = config.Callback or function() end
    self.Theme = t
    self.Connections = {}

    local box = Instance.new("TextButton")
    box.Name = config.Name or "Checkbox"
    box.Text = ""
    box.AutoButtonColor = false
    box.Size = UDim2.fromOffset(t.Size, t.Size)
    box.BorderSizePixel = 0
    box.BackgroundColor3 = self.State and t.Checked or t.Box
    box.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.Corner)
    corner.Parent = box

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1
    stroke.Color = self.State and t.Checked or t.Border
    stroke.Parent = box

    -- squishes a little while pressed
    local boxScale = Instance.new("UIScale")
    boxScale.Parent = box

    local icon = Instance.new("ImageLabel")
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromScale(0.7, 0.7)
    icon.BackgroundTransparency = 1
    icon.BorderSizePixel = 0
    icon.ImageColor3 = t.Check
    icon.Parent = box

    -- pops in and out
    local iconScale = Instance.new("UIScale")
    iconScale.Parent = icon

    -- the default check shows instantly, a custom icon waits for the pack
    local path = config.Icon or "lucide/check"
    icon.Image = (config.Icon and Icons) and "" or t.CheckImage

    if Icons then
        Icons.onReady(function()
            local image = Icons.resolve(path)
            icon.Image = image ~= "" and image or t.CheckImage
        end)
    end

    -- check mark size: 0 = hidden, 1 = shown (overshoots a little for the pop)
    self.Pop = Spring.new(self.State and 1 or 0, 300, 20)
    -- box size while pressed
    self.Press = Spring.new(1, 380, 22)

    self.Pop.OnChanged = function(a)
        iconScale.Scale = math.max(a, 0)
        icon.Visible = a > 0.001
    end
    self.Press.OnChanged = function(s)
        boxScale.Scale = s
    end
    self.Pop.OnChanged(self.Pop.Value)

    self.Box = box
    self.Stroke = stroke

    table.insert(self.Connections, box.MouseButton1Click:Connect(function()
        self:Set(not self.State)
    end))
    table.insert(self.Connections, box.MouseButton1Down:Connect(function()
        self.Press:SetTarget(0.9)
    end))
    table.insert(self.Connections, box.MouseButton1Up:Connect(function()
        self.Press:SetTarget(1)
    end))
    table.insert(self.Connections, box.MouseLeave:Connect(function()
        self.Press:SetTarget(1)
    end))

    return self
end

function Checkbox:Set(state, silent)
    self.State = state and true or false

    self.Pop:SetTarget(self.State and 1 or 0)

    local info = TweenInfo.new(self.Theme.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(self.Box, info, {
        BackgroundColor3 = self.State and self.Theme.Checked or self.Theme.Box,
    }):Play()
    TweenService:Create(self.Stroke, info, {
        Color = self.State and self.Theme.Checked or self.Theme.Border,
    }):Play()

    if not silent then
        self.Callback(self.State)
    end
end

function Checkbox:Toggle()
    self:Set(not self.State)
end

function Checkbox:Get()
    return self.State
end

function Checkbox:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Pop:Destroy()
    self.Press:Destroy()
    self.Box:Destroy()
end

return Checkbox
