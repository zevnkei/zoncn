local TweenService = game:GetService("TweenService")

local Dialog = {}
Dialog.__index = Dialog

local function setFont(label, font)
    if typeof(font) == "Font" then
        label.FontFace = font
    else
        label.Font = font
    end
end

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold,
    DescFont = Enum.Font.GothamMedium,
    Corner = 20,
    Width = 300,
    Gap = 10,
    Margin = 48,
    Dim = 0.5,
    TweenTime = 0.25,
}

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

local function addCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

local function nonEmpty(s)
    return type(s) == "string" and #s > 0
end

local function countVisible(parent)
    local count = 0
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible then
            count += 1
        end
    end
    return count
end

function Dialog.new(parent, config, theme, deps)
    config = config or {}
    assert(deps and deps.Modal and deps.OutsideClick, "Dialog needs deps.Modal and deps.OutsideClick")

    local t = merge(DEFAULT_THEME, theme)
    local self = setmetatable({}, Dialog)
    self.Theme = t
    self.Title = config.Title or config.Name
    self.Description = config.Description or config.Desc
    self.Width = config.Width or t.Width
    self.IsOpen = false
    self.Modal = deps.Modal
    self.ModalCfg = {OverlayDim = t.Dim}
    self.Connections = {}
    self.Pending = false

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 5
    overlay.Active = true
    overlay.Visible = false
    overlay.Parent = parent

    local canvas = Instance.new("Frame")
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.fromScale(0.5, 0.5)
    canvas.Size = UDim2.fromOffset(self.Width, 0)
    canvas.AutomaticSize = Enum.AutomaticSize.Y
    canvas.BackgroundColor3 = t.Background
    canvas.BorderSizePixel = 0
    canvas.Active = true
    canvas.Parent = overlay
    addCorner(canvas, t.Corner)

    local scale = Instance.new("UIScale")
    scale.Scale = 0.95
    scale.Parent = canvas

    local canvasLayout = Instance.new("UIListLayout")
    canvasLayout.Padding = UDim.new(0, t.Gap)
    canvasLayout.SortOrder = Enum.SortOrder.LayoutOrder
    canvasLayout.Parent = canvas

    local hasText = nonEmpty(self.Title) or nonEmpty(self.Description)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 0)
    header.AutomaticSize = Enum.AutomaticSize.Y
    header.BackgroundTransparency = 1
    header.Visible = hasText
    header.LayoutOrder = 1
    header.Parent = canvas

    local headerPad = Instance.new("UIPadding")
    headerPad.PaddingLeft = UDim.new(0, 16)
    headerPad.PaddingRight = UDim.new(0, 16)
    headerPad.PaddingTop = UDim.new(0, 16)
    headerPad.PaddingBottom = UDim.new(0, 6)
    headerPad.Parent = header

    local headerLayout = Instance.new("UIListLayout")
    headerLayout.Padding = UDim.new(0, 4)
    headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    headerLayout.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 0)
    title.AutomaticSize = Enum.AutomaticSize.Y
    title.BackgroundTransparency = 1
    setFont(title, t.Font)
    title.Text = self.Title or ""
    title.TextSize = 18
    title.TextWrapped = true
    title.TextColor3 = t.Foreground
    title.TextTransparency = 0.1
    title.Visible = nonEmpty(self.Title)
    title.Parent = header

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, 0, 0, 0)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.BackgroundTransparency = 1
    setFont(desc, t.DescFont)
    desc.Text = self.Description or ""
    desc.TextSize = 14
    desc.TextWrapped = true
    desc.TextColor3 = t.Muted
    desc.TextTransparency = 0.3
    desc.Visible = nonEmpty(self.Description)
    desc.Parent = header

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageTransparency = 0.8
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new()
    content.LayoutOrder = 2
    content.Visible = false
    content.Parent = canvas

    local contentPad = Instance.new("UIPadding")
    contentPad.PaddingLeft = UDim.new(0, 8)
    contentPad.PaddingRight = UDim.new(0, 8)
    contentPad.Parent = content

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 5)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = content

    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, 0, 0, 0)
    footer.AutomaticSize = Enum.AutomaticSize.Y
    footer.BackgroundTransparency = 1
    footer.Visible = false
    footer.LayoutOrder = 3
    footer.Parent = canvas

    local footerPad = Instance.new("UIPadding")
    footerPad.PaddingLeft = UDim.new(0, 16)
    footerPad.PaddingRight = UDim.new(0, 16)
    footerPad.PaddingBottom = UDim.new(0, 16)
    footerPad.Parent = footer

    local footerLayout = Instance.new("UIListLayout")
    footerLayout.Padding = UDim.new(0, 10)
    footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    footerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    footerLayout.Parent = footer

    self.Overlay = overlay
    self.Canvas = canvas
    self.Scale = scale
    self.CanvasLayout = canvasLayout
    self.Header = header
    self.Content = content
    self.ContentLayout = contentLayout
    self.Footer = footer
    self.FooterLayout = footerLayout

    -- re-measure when content or footer changes, coalesced to one pass per frame
    local function queue()
        if self.Pending then return end
        self.Pending = true
        task.defer(function()
            self.Pending = false
            self:_refresh(not self.IsOpen)
        end)
    end

    table.insert(self.Connections, contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(queue))
    table.insert(self.Connections, footerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(queue))
    table.insert(self.Connections, content.ChildAdded:Connect(queue))
    table.insert(self.Connections, content.ChildRemoved:Connect(queue))
    table.insert(self.Connections, footer.ChildAdded:Connect(queue))
    table.insert(self.Connections, footer.ChildRemoved:Connect(queue))

    local camera = workspace.CurrentCamera
    if camera then
        table.insert(self.Connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(queue))
    end

    table.insert(self.Connections, deps.OutsideClick.bind({canvas}, function()
        if self.IsOpen then
            self:Close()
        end
    end))

    self:_refresh(true)

    return self
end

function Dialog:_refresh(instant)
    local t = self.Theme
    local hasContent = countVisible(self.Content) > 0
    local hasFooter = countVisible(self.Footer) > 0

    -- hide empty sections so the layout doesn't leave gaps
    self.Content.Visible = hasContent
    self.Footer.Visible = hasFooter

    if not hasContent then return end

    -- everything that isn't the scrolling content, in unscaled units
    local s = self.Scale.Scale
    local chrome = 0
    local blocks = 1

    if self.Header.Visible then
        chrome += self.Header.AbsoluteSize.Y
        blocks += 1
    end
    if hasFooter then
        chrome += self.Footer.AbsoluteSize.Y
        blocks += 1
    end
    chrome = chrome / s + (blocks - 1) * self.CanvasLayout.Padding.Offset

    local screen = self.Overlay.AbsoluteSize.Y / s
    local limit = math.max(screen - t.Margin - chrome, 80)
    local height = math.min(self.ContentLayout.AbsoluteContentSize.Y, limit)
    local size = UDim2.new(1, 0, 0, height)

    if instant then
        self.Content.Size = size
    else
        TweenService:Create(self.Content, TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = size,
        }):Play()
    end
end

function Dialog:SetVisible(state)
    if state == nil then
        state = not self.IsOpen
    end
    if state == self.IsOpen then return end

    self.IsOpen = state

    if state then
        self:_refresh(true)
    end

    self.Modal.toggle(self.ModalCfg, self.Overlay, self.Scale, state)
end

function Dialog:Open()
    self:SetVisible(true)
end

function Dialog:Close()
    self:SetVisible(false)
end

function Dialog:Toggle()
    self:SetVisible(nil)
end

function Dialog:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Overlay:Destroy()
end

return Dialog
