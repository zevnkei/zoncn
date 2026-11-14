local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ColorPicker = {}
ColorPicker.__index = ColorPicker

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    Field = Color3.fromRGB(13, 13, 13),
    Border = Color3.fromRGB(60, 60, 60),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    Corner = 20,
    Width = 340,
    Gap = 14,
    Dim = 0.5,
    SwatchWidth = 40,
    SwatchHeight = 20,
    WheelSize = 160,
    BarWidth = 28,
    PresetRows = 2,
    PresetGap = 6,
    Checker = "rbxassetid://121484455191370",
    Wheel = "rbxassetid://6020299385",
    TweenTime = 0.12,
}

local DEFAULT_PRESETS = {
    Color3.fromRGB(239, 68, 68),   -- red
    Color3.fromRGB(249, 115, 22),  -- orange
    Color3.fromRGB(245, 158, 11),  -- amber
    Color3.fromRGB(132, 204, 22),  -- lime
    Color3.fromRGB(34, 197, 94),   -- green
    Color3.fromRGB(20, 184, 166),  -- teal
    Color3.fromRGB(6, 182, 212),   -- cyan
    Color3.fromRGB(14, 165, 233),  -- sky
    Color3.fromRGB(59, 130, 246),  -- blue
    Color3.fromRGB(99, 102, 241),  -- indigo
    Color3.fromRGB(139, 92, 246),  -- violet
    Color3.fromRGB(168, 85, 247),  -- purple
    Color3.fromRGB(236, 72, 153),  -- pink
    Color3.fromRGB(244, 63, 94),   -- rose
    Color3.fromRGB(245, 245, 245), -- white
    Color3.fromRGB(10, 10, 10),    -- black
}

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

local function addCorner(obj, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = obj
    return corner
end

local function addStroke(obj, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = obj
    return stroke
end

-- jump a spring straight to a value (no motion)
local function snap(spring, value)
    spring.Value = value
    spring.Target = value
    spring.Velocity = 0
    if spring.OnChanged then spring.OnChanged(value) end
end

-- Color3, or a "#RRGGBB" string
local function toColor(value)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "string" then
        local ok, color = pcall(Color3.fromHex, value)
        if ok then return color end
    end
    return nil
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- config: Name, Title, Default (Color3), Opacity (0 to 1), Presets (Color3 or hex strings),
--         Columns, Width, Callback
-- Callback(color, opacity) runs when you press Confirm (or on :Set)
function ColorPicker.new(parent, config, theme, deps)
    config = config or {}
    assert(deps and deps.Spring and deps.Modal and deps.OutsideClick, "ColorPicker needs deps.Spring, deps.Modal and deps.OutsideClick")
    local Spring = deps.Spring

    local t = merge(DEFAULT_THEME, theme)

    local self = setmetatable({}, ColorPicker)
    self.Theme = t
    self.Callback = config.Callback or function() end
    self.Modal = deps.Modal
    self.ModalCfg = {OverlayDim = t.Dim}
    self.Width = config.Width or t.Width
    self.Color = toColor(config.Default) or Color3.new(1, 1, 1)
    self.Opacity = math.clamp(config.Opacity or 1, 0, 1)
    self.IsOpen = false
    self.Dragging = nil
    self.Presets = {}
    self.Connections = {}
    self.Info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- staged values: what the picker is showing before you confirm
    self.SH, self.SS, self.SV = self.Color:ToHSV()
    self.SA = self.Opacity

    -- the overlay has to cover the whole screen, so it goes in the root ScreenGui
    local root = parent
    if not parent:IsA("ScreenGui") then
        root = parent:FindFirstAncestorWhichIsA("ScreenGui") or parent
    end

    --// Swatch (the thing you click)
    local swatch = Instance.new("CanvasGroup")
    swatch.Name = config.Name or "ColorPicker"
    swatch.Size = UDim2.fromOffset(t.SwatchWidth, t.SwatchHeight)
    swatch.BackgroundTransparency = 1
    swatch.BorderSizePixel = 0
    swatch.Parent = parent
    addCorner(swatch, t.SwatchHeight / 2)
    addStroke(swatch, t.Border, 1, 0)

    local swatchChecker = Instance.new("ImageLabel")
    swatchChecker.Size = UDim2.fromScale(1, 1)
    swatchChecker.BackgroundTransparency = 1
    swatchChecker.Image = t.Checker
    swatchChecker.ScaleType = Enum.ScaleType.Tile
    swatchChecker.TileSize = UDim2.fromOffset(500, 500)
    swatchChecker.Parent = swatch

    local swatchColor = Instance.new("Frame")
    swatchColor.Size = UDim2.fromScale(1, 1)
    swatchColor.BorderSizePixel = 0
    swatchColor.BackgroundColor3 = self.Color
    swatchColor.BackgroundTransparency = 1 - self.Opacity
    swatchColor.ZIndex = 2
    swatchColor.Parent = swatch

    local swatchButton = Instance.new("TextButton")
    swatchButton.Size = UDim2.fromScale(1, 1)
    swatchButton.BackgroundTransparency = 1
    swatchButton.Text = ""
    swatchButton.AutoButtonColor = false
    swatchButton.ZIndex = 3
    swatchButton.Parent = swatch

    --// Modal
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 6
    overlay.Active = true
    overlay.Visible = false
    overlay.Parent = root

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(self.Width, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.BackgroundColor3 = t.Background
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Parent = overlay
    addCorner(panel, t.Corner)

    local scale = Instance.new("UIScale")
    scale.Scale = 0.95
    scale.Parent = panel

    local panelPad = Instance.new("UIPadding")
    panelPad.PaddingTop = UDim.new(0, 16)
    panelPad.PaddingBottom = UDim.new(0, 16)
    panelPad.PaddingLeft = UDim.new(0, 16)
    panelPad.PaddingRight = UDim.new(0, 16)
    panelPad.Parent = panel

    local panelLayout = Instance.new("UIListLayout")
    panelLayout.Padding = UDim.new(0, t.Gap)
    panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    panelLayout.Parent = panel

    local title = Instance.new("TextLabel")
    title.LayoutOrder = 1
    title.Size = UDim2.new(1, 0, 0, 0)
    title.AutomaticSize = Enum.AutomaticSize.Y
    title.BackgroundTransparency = 1
    title.Font = t.Font
    title.Text = config.Title or config.Name or "Color"
    title.TextSize = 18
    title.TextColor3 = t.Foreground
    title.TextTransparency = 0.1
    title.Parent = panel

    --// Wheel, brightness bar, alpha bar
    local row = Instance.new("Frame")
    row.LayoutOrder = 2
    row.Size = UDim2.new(1, 0, 0, t.WheelSize)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = panel

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 12)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row

    local wheel = Instance.new("ImageLabel")
    wheel.LayoutOrder = 1
    wheel.Size = UDim2.fromOffset(t.WheelSize, t.WheelSize)
    wheel.BackgroundTransparency = 1
    wheel.Image = t.Wheel
    wheel.Parent = row

    local wheelMarker = Instance.new("Frame")
    wheelMarker.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelMarker.Position = UDim2.fromScale(0.5, 0.5)
    wheelMarker.Size = UDim2.fromOffset(14, 14)
    wheelMarker.BackgroundColor3 = self.Color
    wheelMarker.BorderSizePixel = 0
    wheelMarker.ZIndex = 3
    wheelMarker.Parent = wheel
    addCorner(wheelMarker, 7)
    addStroke(wheelMarker, t.Field, 2, 0)

    local bright = Instance.new("Frame")
    bright.LayoutOrder = 2
    bright.Size = UDim2.new(0, t.BarWidth, 1, 0)
    bright.BackgroundColor3 = Color3.new(1, 1, 1)
    bright.BorderSizePixel = 0
    bright.Parent = row
    addCorner(bright, 6)
    addStroke(bright, t.Border, 1, 0)

    local brightGradient = Instance.new("UIGradient")
    brightGradient.Rotation = 90
    brightGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0))
    brightGradient.Parent = bright

    local alpha = Instance.new("ImageLabel")
    alpha.LayoutOrder = 3
    alpha.Size = UDim2.new(0, t.BarWidth, 1, 0)
    alpha.BackgroundTransparency = 1
    alpha.Image = t.Checker
    alpha.ScaleType = Enum.ScaleType.Tile
    alpha.TileSize = UDim2.fromOffset(500, 500)
    alpha.Parent = row
    addCorner(alpha, 6)
    addStroke(alpha, t.Border, 1, 0)

    local alphaColor = Instance.new("Frame")
    alphaColor.Size = UDim2.fromScale(1, 1)
    alphaColor.BackgroundColor3 = self.Color
    alphaColor.BorderSizePixel = 0
    alphaColor.ZIndex = 2
    alphaColor.Parent = alpha
    addCorner(alphaColor, 6)

    local alphaGradient = Instance.new("UIGradient")
    alphaGradient.Rotation = 90
    alphaGradient.Transparency = NumberSequence.new(0, 1)
    alphaGradient.Parent = alphaColor

    -- the bars' handles are a little wider than the bars
    local function createHandle(bar)
        local handle = Instance.new("Frame")
        handle.AnchorPoint = Vector2.new(0.5, 0.5)
        handle.Position = UDim2.fromScale(0.5, 0)
        handle.Size = UDim2.new(1, 4, 0, 8)
        handle.BackgroundColor3 = t.Foreground
        handle.BorderSizePixel = 0
        handle.ZIndex = 4
        handle.Parent = bar
        addCorner(handle, 4)
        addStroke(handle, t.Field, 1.5, 0)
        return handle
    end

    local brightHandle = createHandle(bright)
    local alphaHandle = createHandle(alpha)

    --// Presets
    local presetColors = {}
    for _, value in ipairs(config.Presets or DEFAULT_PRESETS) do
        local color = toColor(value)
        if color then
            table.insert(presetColors, color)
        end
    end

    if #presetColors > 0 then
        local columns = config.Columns or math.ceil(#presetColors / t.PresetRows)
        local rows = math.ceil(#presetColors / columns)
        local gap = t.PresetGap
        local cell = math.floor((self.Width - 32 - gap * (columns - 1)) / columns)

        local grid = Instance.new("Frame")
        grid.LayoutOrder = 3
        grid.Size = UDim2.new(1, 0, 0, rows * cell + (rows - 1) * gap)
        grid.BackgroundTransparency = 1
        grid.BorderSizePixel = 0
        grid.Parent = panel

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.fromOffset(cell, cell)
        gridLayout.CellPadding = UDim2.fromOffset(gap, gap)
        gridLayout.FillDirection = Enum.FillDirection.Horizontal
        gridLayout.FillDirectionMaxCells = columns
        gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = grid

        for index, color in ipairs(presetColors) do
            local button = Instance.new("TextButton")
            button.LayoutOrder = index
            button.Text = ""
            button.AutoButtonColor = false
            button.BackgroundColor3 = color
            button.BorderSizePixel = 0
            button.Parent = grid
            addCorner(button, math.floor(cell * 0.3))

            -- ring around the preset that matches the current color
            local ring = addStroke(button, t.Foreground, 2, 1)

            table.insert(self.Presets, {Color = color, Ring = ring})

            table.insert(self.Connections, button.MouseButton1Click:Connect(function()
                self.SH, self.SS, self.SV = color:ToHSV()
                self:_render()
            end))
        end
    end

    --// Bottom row: preview, hex, cancel, confirm
    local bottom = Instance.new("Frame")
    bottom.LayoutOrder = 4
    bottom.Size = UDim2.new(1, 0, 0, 32)
    bottom.BackgroundTransparency = 1
    bottom.BorderSizePixel = 0
    bottom.Parent = panel

    local bottomLayout = Instance.new("UIListLayout")
    bottomLayout.FillDirection = Enum.FillDirection.Horizontal
    bottomLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    bottomLayout.Padding = UDim.new(0, 8)
    bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bottomLayout.Parent = bottom

    -- new color on the left half, the color you started with on the right
    local preview = Instance.new("CanvasGroup")
    preview.LayoutOrder = 1
    preview.Size = UDim2.fromOffset(52, 30)
    preview.BackgroundTransparency = 1
    preview.BorderSizePixel = 0
    preview.Parent = bottom
    addCorner(preview, 8)
    addStroke(preview, t.Border, 1, 0)

    local previewChecker = Instance.new("ImageLabel")
    previewChecker.Size = UDim2.fromScale(1, 1)
    previewChecker.BackgroundTransparency = 1
    previewChecker.Image = t.Checker
    previewChecker.ScaleType = Enum.ScaleType.Tile
    previewChecker.TileSize = UDim2.fromOffset(500, 500)
    previewChecker.Parent = preview

    local newColor = Instance.new("Frame")
    newColor.Size = UDim2.fromScale(0.5, 1)
    newColor.BorderSizePixel = 0
    newColor.ZIndex = 2
    newColor.Parent = preview

    local oldColor = Instance.new("Frame")
    oldColor.Position = UDim2.fromScale(0.5, 0)
    oldColor.Size = UDim2.fromScale(0.5, 1)
    oldColor.BorderSizePixel = 0
    oldColor.ZIndex = 2
    oldColor.Parent = preview

    local buttonWidth = 72
    local hexWidth = math.max(self.Width - 32 - 52 - buttonWidth * 2 - 8 * 3, 60)

    local hex = Instance.new("TextBox")
    hex.LayoutOrder = 2
    hex.Size = UDim2.fromOffset(hexWidth, 30)
    hex.BackgroundColor3 = t.Field
    hex.BorderSizePixel = 0
    hex.ClearTextOnFocus = false
    hex.Font = t.Font
    hex.PlaceholderText = "#RRGGBB"
    hex.PlaceholderColor3 = t.Muted
    hex.TextSize = 13
    hex.TextColor3 = t.Foreground
    hex.Parent = bottom
    addCorner(hex, 8)
    addStroke(hex, t.Border, 1, 0)

    local cancel = Instance.new("TextButton")
    cancel.LayoutOrder = 3
    cancel.Size = UDim2.fromOffset(buttonWidth, 30)
    cancel.BackgroundTransparency = 1
    cancel.AutoButtonColor = false
    cancel.Font = t.Font
    cancel.Text = "Cancel"
    cancel.TextSize = 14
    cancel.TextColor3 = t.Foreground
    cancel.Parent = bottom
    addCorner(cancel, 8)
    addStroke(cancel, t.Border, 1, 0)

    local confirm = Instance.new("TextButton")
    confirm.LayoutOrder = 4
    confirm.Size = UDim2.fromOffset(buttonWidth, 30)
    confirm.BackgroundColor3 = t.Foreground
    confirm.BorderSizePixel = 0
    confirm.AutoButtonColor = false
    confirm.Font = t.Font
    confirm.Text = "Confirm"
    confirm.TextSize = 14
    confirm.TextColor3 = t.Field
    confirm.Parent = bottom
    addCorner(confirm, 8)

    self.SwatchColor = swatchColor
    self.Swatch = swatch
    self.Overlay = overlay
    self.Panel = panel
    self.Scale = scale
    self.Wheel = wheel
    self.WheelMarker = wheelMarker
    self.Bright = bright
    self.BrightGradient = brightGradient
    self.Alpha = alpha
    self.AlphaColor = alphaColor
    self.NewColor = newColor
    self.OldColor = oldColor
    self.Hex = hex

    --// Marker springs: positions as fractions, so they stay right at any UIScale
    self.WheelX = Spring.new(0.5, 420, 34)
    self.WheelY = Spring.new(0.5, 420, 34)
    self.BrightY = Spring.new(0, 420, 34)
    self.AlphaY = Spring.new(0, 420, 34)

    local wheelX, wheelY = 0.5, 0.5
    self.WheelX.OnChanged = function(v)
        wheelX = v
        wheelMarker.Position = UDim2.fromScale(wheelX, wheelY)
    end
    self.WheelY.OnChanged = function(v)
        wheelY = v
        wheelMarker.Position = UDim2.fromScale(wheelX, wheelY)
    end
    self.BrightY.OnChanged = function(v)
        brightHandle.Position = UDim2.fromScale(0.5, v)
    end
    self.AlphaY.OnChanged = function(v)
        alphaHandle.Position = UDim2.fromScale(0.5, v)
    end

    --// Input
    local function bindDrag(area, kind)
        table.insert(self.Connections, area.InputBegan:Connect(function(input)
            if isPress(input) then
                self.Dragging = kind
                self:_update(Vector2.new(input.Position.X, input.Position.Y))
            end
        end))
    end

    bindDrag(wheel, "wheel")
    bindDrag(bright, "bright")
    bindDrag(alpha, "alpha")

    table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
        if self.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            self:_update(Vector2.new(input.Position.X, input.Position.Y))
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if isPress(input) then
            self.Dragging = nil
        end
    end))

    table.insert(self.Connections, hex.FocusLost:Connect(function()
        local digits = hex.Text:gsub("[^%x]", "")
        local color = #digits == 6 and toColor("#" .. digits) or nil

        if color then
            self.SH, self.SS, self.SV = color:ToHSV()
        end
        self:_render() -- also puts the old text back when it wasn't valid
    end))

    table.insert(self.Connections, swatchButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end))
    table.insert(self.Connections, cancel.MouseButton1Click:Connect(function()
        self:Close()
    end))
    table.insert(self.Connections, confirm.MouseButton1Click:Connect(function()
        self:Set(Color3.fromHSV(self.SH, self.SS, self.SV), self.SA)
        self:Close()
    end))

    -- clicking the dim area cancels
    table.insert(self.Connections, deps.OutsideClick.bind({panel}, function()
        if self.IsOpen then
            self:Close()
        end
    end))

    return self
end

-- pointer position -> staged color
function ColorPicker:_update(point)
    local kind = self.Dragging

    if kind == "wheel" then
        local wheel = self.Wheel
        local radius = wheel.AbsoluteSize.X / 2
        local offset = point - (wheel.AbsolutePosition + wheel.AbsoluteSize / 2)

        if offset.Magnitude > radius then
            offset = offset.Unit * radius
        end

        local angle = math.atan2(offset.Y, offset.X)
        self.SH = (1 - (angle + math.pi) / (math.pi * 2)) % 1
        self.SS = math.clamp(offset.Magnitude / radius, 0, 1)

    elseif kind == "bright" then
        local bar = self.Bright
        self.SV = 1 - math.clamp((point.Y - bar.AbsolutePosition.Y) / bar.AbsoluteSize.Y, 0, 1)

    elseif kind == "alpha" then
        local bar = self.Alpha
        self.SA = 1 - math.clamp((point.Y - bar.AbsolutePosition.Y) / bar.AbsoluteSize.Y, 0, 1)
    end

    self:_render()
end

-- paints the staged color everywhere and moves the markers
function ColorPicker:_render(instant)
    local color = Color3.fromHSV(self.SH, self.SS, self.SV)

    self.NewColor.BackgroundColor3 = color
    self.NewColor.BackgroundTransparency = 1 - self.SA
    self.AlphaColor.BackgroundColor3 = color
    self.WheelMarker.BackgroundColor3 = color
    self.BrightGradient.Color = ColorSequence.new(Color3.fromHSV(self.SH, self.SS, 1), Color3.new(0, 0, 0))

    -- marker targets, as fractions of the wheel / bars
    local phi = (1 - self.SH) * math.pi * 2 - math.pi
    local x = 0.5 + math.cos(phi) * self.SS * 0.5
    local y = 0.5 + math.sin(phi) * self.SS * 0.5

    if instant then
        snap(self.WheelX, x)
        snap(self.WheelY, y)
        snap(self.BrightY, 1 - self.SV)
        snap(self.AlphaY, 1 - self.SA)
    else
        self.WheelX:SetTarget(x)
        self.WheelY:SetTarget(y)
        self.BrightY:SetTarget(1 - self.SV)
        self.AlphaY:SetTarget(1 - self.SA)
    end

    -- don't overwrite the hex while it's being typed
    if not self.Hex:IsFocused() then
        self.Hex.Text = "#" .. color:ToHex():upper()
    end

    local current = color:ToHex()
    for _, preset in ipairs(self.Presets) do
        local on = preset.Color:ToHex() == current
        TweenService:Create(preset.Ring, self.Info, {Transparency = on and 0 or 1}):Play()
    end
end

-- start from the committed color every time it opens
function ColorPicker:_stage()
    self.SH, self.SS, self.SV = self.Color:ToHSV()
    self.SA = self.Opacity

    self.OldColor.BackgroundColor3 = self.Color
    self.OldColor.BackgroundTransparency = 1 - self.Opacity

    self:_render(true)
end

function ColorPicker:SetVisible(state)
    if state == nil then
        state = not self.IsOpen
    end
    if state == self.IsOpen then return end

    self.IsOpen = state
    self.Dragging = nil

    if state then
        self:_stage()
    end

    self.Modal.toggle(self.ModalCfg, self.Overlay, self.Scale, state)
end

function ColorPicker:Open()
    self:SetVisible(true)
end

function ColorPicker:Close()
    self:SetVisible(false)
end

function ColorPicker:Toggle()
    self:SetVisible(nil)
end

-- color: Color3, opacity: 0 (clear) to 1 (solid)
function ColorPicker:Set(color, opacity, silent)
    if typeof(color) == "Color3" then
        self.Color = color
    end
    if type(opacity) == "number" then
        self.Opacity = math.clamp(opacity, 0, 1)
    end

    self.SwatchColor.BackgroundColor3 = self.Color
    self.SwatchColor.BackgroundTransparency = 1 - self.Opacity

    if not silent then
        self.Callback(self.Color, self.Opacity)
    end
end

function ColorPicker:Get()
    return self.Color, self.Opacity
end

function ColorPicker:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.WheelX:Destroy()
    self.WheelY:Destroy()
    self.BrightY:Destroy()
    self.AlphaY:Destroy()
    self.Overlay:Destroy()
    self.Swatch:Destroy()
end

return ColorPicker
