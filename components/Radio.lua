local TweenService = game:GetService("TweenService")

local Radio = {}
Radio.__index = Radio

local DEFAULT_THEME = {
    Border = Color3.fromRGB(150, 150, 150),
    Checked = Color3.fromRGB(90, 200, 120),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    DescFont = Enum.Font.Gotham,
    TextSize = 14,
    DescSize = 13,
    Size = 18,       -- the ring
    Thickness = 1.5, -- ring border
    DotSize = 8,
    Gap = 12,        -- between options
    TextGap = 10,    -- ring to text
    TweenTime = 0.15,
}

local function snap(spring, value)
    spring.Value = value
    spring.Target = value
    spring.Velocity = 0
    if spring.OnChanged then spring.OnChanged(value) end
end

local function normalize(option)
    if type(option) == "table" then
        local value = option.Value or option.Title or option.Text or option.Name

        return {
            Value = value,
            Title = option.Title or option.Text or option.Name or tostring(value),
            Desc = option.Desc or option.Description,
        }
    end

    return {Value = option, Title = tostring(option)}
end

-- config: Name, Options, Default (first option when left out), Callback
-- Callback(value) runs when the selection changes
function Radio.new(parent, config, theme, deps)
    config = config or {}
    local Spring = deps and deps.Spring
    assert(Spring, "Radio needs deps.Spring")

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Radio)
    self.Theme = t
    self.Callback = config.Callback or function() end
    self.Options = {}
    self.Entries = {}
    self.Value = nil
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    for _, option in ipairs(config.Options or {}) do
        table.insert(self.Options, normalize(option))
    end

    local root = Instance.new("Frame")
    root.Name = config.Name or "Radio"
    root.Size = UDim2.new(1, 0, 0, 0)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Parent = parent

    local rootLayout = Instance.new("UIListLayout")
    rootLayout.Padding = UDim.new(0, t.Gap)
    rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rootLayout.Parent = root

    self.Root = root

    for index, option in ipairs(self.Options) do
        local row = Instance.new("TextButton")
        row.LayoutOrder = index
        row.Text = ""
        row.AutoButtonColor = false
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.Parent = root

        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        rowLayout.Padding = UDim.new(0, t.TextGap)
        rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rowLayout.Parent = row

        -- the stroke draws outside its frame, so the ring is a little smaller than its slot
        local slot = Instance.new("Frame")
        slot.LayoutOrder = 1
        slot.Size = UDim2.fromOffset(t.Size, t.Size)
        slot.BackgroundTransparency = 1
        slot.BorderSizePixel = 0
        slot.Parent = row

        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromOffset(t.Size - t.Thickness * 2, t.Size - t.Thickness * 2)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.Parent = slot

        local ringCorner = Instance.new("UICorner")
        ringCorner.CornerRadius = UDim.new(1, 0)
        ringCorner.Parent = ring

        local stroke = Instance.new("UIStroke")
        stroke.Color = t.Border
        stroke.Thickness = t.Thickness
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = ring

        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromScale(0.5, 0.5)
        dot.Size = UDim2.fromOffset(t.DotSize, t.DotSize)
        dot.BackgroundColor3 = t.Checked
        dot.BorderSizePixel = 0
        dot.Visible = false
        dot.Parent = ring

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local dotScale = Instance.new("UIScale")
        dotScale.Scale = 0
        dotScale.Parent = dot

        -- title with the description under it, filling what the ring leaves free
        local text = Instance.new("Frame")
        text.LayoutOrder = 2
        text.Size = UDim2.new(0, 0, 0, 0)
        text.AutomaticSize = Enum.AutomaticSize.Y
        text.BackgroundTransparency = 1
        text.BorderSizePixel = 0
        text.Parent = row

        local flex = Instance.new("UIFlexItem")
        flex.FlexMode = Enum.UIFlexMode.Fill
        flex.Parent = text

        local textLayout = Instance.new("UIListLayout")
        textLayout.Padding = UDim.new(0, 2)
        textLayout.SortOrder = Enum.SortOrder.LayoutOrder
        textLayout.Parent = text

        local title = Instance.new("TextLabel")
        title.LayoutOrder = 1
        title.Size = UDim2.new(1, 0, 0, 0)
        title.AutomaticSize = Enum.AutomaticSize.Y
        title.BackgroundTransparency = 1
        title.Font = t.Font
        title.Text = option.Title
        title.TextSize = t.TextSize
        title.TextColor3 = t.Foreground
        title.TextWrapped = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextYAlignment = Enum.TextYAlignment.Top
        title.Parent = text

        if type(option.Desc) == "string" and #option.Desc > 0 then
            local desc = Instance.new("TextLabel")
            desc.LayoutOrder = 2
            desc.Size = UDim2.new(1, 0, 0, 0)
            desc.AutomaticSize = Enum.AutomaticSize.Y
            desc.BackgroundTransparency = 1
            desc.Font = t.DescFont
            desc.Text = option.Desc
            desc.TextSize = t.DescSize
            desc.TextColor3 = t.Muted
            desc.TextWrapped = true
            desc.TextXAlignment = Enum.TextXAlignment.Left
            desc.TextYAlignment = Enum.TextYAlignment.Top
            desc.Parent = text
        end

        local pop = Spring.new(0, 300, 20)
        pop.OnChanged = function(v)
            dotScale.Scale = math.max(v, 0)
            dot.Visible = v > 0.001
        end

        self.Entries[option.Value] = {Stroke = stroke, Pop = pop}

        table.insert(self.Connections, row.MouseButton1Click:Connect(function()
            self:Set(option.Value)
        end))
    end

    local default = config.Default
    if default == nil and self.Options[1] then
        default = self.Options[1].Value
    end

    if self.Entries[default] then
        self.Value = default
    end

    self:_paint(true)

    return self
end

function Radio:_paint(instant)
    local t = self.Theme

    for _, option in ipairs(self.Options) do
        local entry = self.Entries[option.Value]
        local on = option.Value == self.Value
        local color = on and t.Checked or t.Border

        if instant then
            snap(entry.Pop, on and 1 or 0)
            entry.Stroke.Color = color
        else
            entry.Pop:SetTarget(on and 1 or 0)
            TweenService:Create(entry.Stroke, self.Info, {Color = color}):Play()
        end
    end
end

function Radio:Set(value, silent)
    if not self.Entries[value] then return end

    -- a radio can't be switched off by clicking it again
    if value == self.Value then return end

    self.Value = value
    self:_paint(false)

    if not silent then
        self.Callback(value)
    end
end

function Radio:Get()
    return self.Value
end

function Radio:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    for _, entry in pairs(self.Entries) do
        entry.Pop:Destroy()
    end
    self.Root:Destroy()
end

return Radio
