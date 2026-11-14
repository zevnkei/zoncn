local TweenService = game:GetService("TweenService")

local Segment = {}
Segment.__index = Segment

local DEFAULT_THEME = {
    Track = Color3.fromRGB(13, 13, 13),
    TrackTransparency = 0.3,
    Pill = Color3.fromRGB(45, 45, 45),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    TextSize = 13,
    IconSize = 16,
    Height = 28,
    Corner = 8,
    PillCorner = 6,
    Padding = 2,
    TweenTime = 0.2,
}

-- jump a spring straight to a value (no motion)
local function snap(spring, value)
    spring.Value = value
    spring.Target = value
    spring.Velocity = 0
    if spring.OnChanged then spring.OnChanged(value) end
end

local function apply(obj, property, value, info, instant)
    if instant then
        obj[property] = value
    else
        TweenService:Create(obj, info, {[property] = value}):Play()
    end
end

-- options: "A", or {Value = "a", Text = "A", Icon = "lucide/sun"}
-- icon only, text only, or both
local function normalize(option)
    if type(option) == "table" then
        return {
            Value = option.Value or option.Text or option.Name,
            Text = option.Text,
            Icon = option.Icon,
        }
    end
    return {Value = option, Text = tostring(option)}
end

function Segment.new(parent, config, theme, deps)
    config = config or {}
    local Spring = deps and deps.Spring
    assert(Spring, "Segment needs deps.Spring")
    local Icons = deps.Icons -- optional

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local self = setmetatable({}, Segment)
    self.Theme = t
    self.Multi = config.Multi or false
    self.Callback = config.Callback or function() end
    self.Options = {}
    self.Buttons = {}   -- [Value] = {Button, Icon, Label}
    self.Selected = {}  -- [Value] = true
    self.Value = nil
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    for _, option in ipairs(config.Options or {}) do
        table.insert(self.Options, normalize(option))
    end

    -- AutoWidth: hugs its options instead of filling the row
    local hug = config.AutoWidth or false

    local root = Instance.new("Frame")
    root.Name = config.Name or "Segment"
    root.Size = hug and UDim2.new(0, 0, 0, t.Height) or UDim2.new(1, 0, 0, t.Height)
    root.AutomaticSize = hug and Enum.AutomaticSize.X or Enum.AutomaticSize.None
    root.BackgroundColor3 = t.Track
    root.BackgroundTransparency = t.TrackTransparency
    root.BorderSizePixel = 0
    root.Parent = parent

    local rootCorner = Instance.new("UICorner")
    rootCorner.CornerRadius = UDim.new(0, t.Corner)
    rootCorner.Parent = root

    local rootPad = Instance.new("UIPadding")
    rootPad.PaddingTop = UDim.new(0, t.Padding)
    rootPad.PaddingBottom = UDim.new(0, t.Padding)
    rootPad.PaddingLeft = UDim.new(0, t.Padding)
    rootPad.PaddingRight = UDim.new(0, t.Padding)
    rootPad.Parent = root

    local layer = Instance.new("Frame")
    layer.Size = hug and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 1, 0)
    layer.AutomaticSize = hug and Enum.AutomaticSize.X or Enum.AutomaticSize.None
    layer.BackgroundTransparency = 1
    layer.BorderSizePixel = 0
    layer.Parent = root

    self.Root = root
    self.Layer = layer

    if not self.Multi then
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 0, 1, 0)
        pill.BackgroundColor3 = t.Pill
        pill.BorderSizePixel = 0
        pill.Visible = false
        pill.ZIndex = 1
        pill.Parent = layer

        local pillCorner = Instance.new("UICorner")
        pillCorner.CornerRadius = UDim.new(0, t.PillCorner)
        pillCorner.Parent = pill

        self.Pill = pill

        -- pill position and width as fractions of the layer, so they stay right at any scale
        self.PillX = Spring.new(0, 260, 22)
        self.PillW = Spring.new(0, 260, 22)

        local x, w = 0, 0
        local function place()
            pill.Position = UDim2.new(x, 0, 0, 0)
            pill.Size = UDim2.new(w, 0, 1, 0)
        end
        self.PillX.OnChanged = function(v) x = v place() end
        self.PillW.OnChanged = function(v) w = v place() end
    end

    local holder = Instance.new("Frame")
    holder.Size = hug and UDim2.new(0, 0, 1, 0) or UDim2.new(1, 0, 1, 0)
    holder.AutomaticSize = hug and Enum.AutomaticSize.X or Enum.AutomaticSize.None
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ZIndex = 2
    holder.Parent = layer

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.FillDirection = Enum.FillDirection.Horizontal
    holderLayout.HorizontalFlex = hug and Enum.UIFlexAlignment.None or Enum.UIFlexAlignment.Fill
    holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    holderLayout.Padding = UDim.new(0, 2)
    holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
    holderLayout.Parent = holder

    self.Holder = holder

    for index, option in ipairs(self.Options) do
        local parts = {}

        local button = Instance.new("TextButton")
        button.LayoutOrder = index
        button.Text = ""
        button.AutoButtonColor = false
        button.Size = UDim2.new(0, 0, 1, 0)
        button.AutomaticSize = hug and Enum.AutomaticSize.X or Enum.AutomaticSize.None
        button.BackgroundColor3 = t.Pill
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.ZIndex = 2
        button.Parent = holder
        parts.Button = button

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, t.PillCorner)
        buttonCorner.Parent = button

        local buttonPad = Instance.new("UIPadding")
        buttonPad.PaddingLeft = UDim.new(0, option.Text and 10 or 8)
        buttonPad.PaddingRight = UDim.new(0, option.Text and 10 or 8)
        buttonPad.Parent = button

        local buttonLayout = Instance.new("UIListLayout")
        buttonLayout.FillDirection = Enum.FillDirection.Horizontal
        buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        buttonLayout.Padding = UDim.new(0, 5)
        buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
        buttonLayout.Parent = button

        if option.Icon then
            local icon = Instance.new("ImageLabel")
            icon.LayoutOrder = 1
            icon.Size = UDim2.fromOffset(t.IconSize, t.IconSize)
            icon.BackgroundTransparency = 1
            icon.BorderSizePixel = 0
            icon.ImageColor3 = t.Muted
            icon.ZIndex = 3
            icon.Parent = button
            parts.Icon = icon

            if Icons then
                Icons.apply(icon, "Image", option.Icon)
            else
                icon.Image = option.Icon
            end
        end

        if option.Text then
            local label = Instance.new("TextLabel")
            label.LayoutOrder = 2
            label.Size = UDim2.new(0, 0, 0, 20)
            label.AutomaticSize = Enum.AutomaticSize.X
            label.BackgroundTransparency = 1
            label.Font = t.Font
            label.Text = option.Text
            label.TextSize = t.TextSize
            label.TextColor3 = t.Muted
            label.ZIndex = 3
            label.Parent = button
            parts.Label = label
        end

        self.Buttons[option.Value] = parts

        table.insert(self.Connections, button.MouseButton1Click:Connect(function()
            local value = option.Value

            if self.Multi then
                self.Selected[value] = not self.Selected[value] or nil
                self:_commit()
            elseif not self.Selected[value] then
                table.clear(self.Selected)
                self.Selected[value] = true
                self:_commit()
            end
        end))
    end

    -- layout changed (resize, scale, text), so put the pill back under the right button
    table.insert(self.Connections, holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_movePill(true)
    end))

    local default = config.Default
    if default == nil and not self.Multi and self.Options[1] then
        default = self.Options[1].Value
    end

    self:Set(default, true, true)
    task.defer(function()
        self:_movePill(true)
    end)

    return self
end

function Segment:_movePill(instant)
    if self.Multi then return end

    local parts = self.Value ~= nil and self.Buttons[self.Value]
    if not parts then
        self.Pill.Visible = false
        return
    end

    local layerWidth = self.Layer.AbsoluteSize.X
    local button = parts.Button
    if layerWidth <= 0 or button.AbsoluteSize.X <= 0 then
        return -- not laid out yet, the size signal calls us again
    end

    local x = (button.AbsolutePosition.X - self.Layer.AbsolutePosition.X) / layerWidth
    local w = button.AbsoluteSize.X / layerWidth

    if instant or not self.Pill.Visible then
        snap(self.PillX, x)
        snap(self.PillW, w)
        self.Pill.Visible = true
    else
        self.PillX:SetTarget(x)
        self.PillW:SetTarget(w)
    end
end

function Segment:_paint(instant)
    local t = self.Theme

    for _, option in ipairs(self.Options) do
        local parts = self.Buttons[option.Value]
        local on = self.Selected[option.Value] == true
        local color = on and t.Foreground or t.Muted

        if parts.Icon then
            apply(parts.Icon, "ImageColor3", color, self.Info, instant)
        end
        if parts.Label then
            apply(parts.Label, "TextColor3", color, self.Info, instant)
        end
        if self.Multi then
            apply(parts.Button, "BackgroundTransparency", on and 0 or 1, self.Info, instant)
        end
    end

    self:_movePill(instant)
end

function Segment:_commit(silent, instant)
    local values = {}

    for _, option in ipairs(self.Options) do
        if self.Selected[option.Value] then
            table.insert(values, option.Value)
        end
    end

    self.Value = self.Multi and values or values[1]
    self:_paint(instant)

    if not silent then
        self.Callback(self.Value)
    end
end

-- value: one option value, or a list of them when Multi
function Segment:Set(value, silent, instant)
    table.clear(self.Selected)

    local list = type(value) == "table" and value or {value}

    for _, item in ipairs(list) do
        if self.Buttons[item] then
            self.Selected[item] = true

            if not self.Multi then
                break
            end
        end
    end

    self:_commit(silent, instant)
end

function Segment:Get()
    return self.Value
end

function Segment:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    if self.PillX then
        self.PillX:Destroy()
        self.PillW:Destroy()
    end
    self.Root:Destroy()
end

return Segment
