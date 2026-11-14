local TweenService = game:GetService("TweenService")

local DropdownMenu = {}
DropdownMenu.__index = DropdownMenu

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    BackgroundTransparency = 0.1,
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Hover = Color3.fromRGB(35, 35, 35),
    Stroke = Color3.fromRGB(255, 255, 255),
    StrokeTransparency = 0.9,
    Font = Enum.Font.GothamMedium,
    TextSize = 14,
    Corner = 20,
    ItemCorner = 8,
    ItemHeight = 32,
    ItemGap = 5,
    Margin = 24, -- keep this far from the screen edges
    Gap = 6, -- space between the anchor and the popup
    Padding = 16, -- total vertical padding (top + bottom)
    SidePadding = 8,
    OpenScale = 0.95, -- scale it grows from / shrinks to
    TweenTime = 0.2, -- open / close / resize
    PageTime = 0.18, -- slide between pages
    HoverTime = 0.1,
}

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

local function round(n)
    return math.floor(n + 0.5)
end

-- all popups live in one full-screen host inside the ScreenGui, so they are
-- never clipped or pushed around by whatever container the anchor sits in
local function getHost(parent)
    local root = parent
    if not parent:IsA("ScreenGui") then
        root = parent:FindFirstAncestorWhichIsA("ScreenGui") or parent
    end

    local host = root:FindFirstChild("zoncn-popups")
    if not host then
        host = Instance.new("Frame")
        host.Name = "zoncn-popups"
        host.Size = UDim2.fromScale(1, 1)
        host.BackgroundTransparency = 1
        host.BorderSizePixel = 0
        host.ZIndex = 10
        host.Parent = root
    end

    return host
end

function DropdownMenu.new(parent, config, theme, deps)
    config = config or {}
    assert(config.Anchor, "DropdownMenu needs config.Anchor")
    assert(deps and deps.OutsideClick, "DropdownMenu needs deps.OutsideClick")

    local t = merge(DEFAULT_THEME, theme)
    local self = setmetatable({}, DropdownMenu)
    self.Theme = t
    self.Anchor = config.Anchor
    self.Width = config.Width or 200
    self.HasChild = config.Child or false
    self.CloseOnClick = config.CloseOnClick ~= false
    self.OnMain = config.OnMain or function() end
    self.Host = getHost(parent)
    self.Open = false
    self.OnChild = false
    self.OpenedAt = 0
    self.ClosedAt = 0
    self.Token = 0
    self.Destroyed = false
    self.Last = {}
    self.Orders = {}
    self.Connections = {}

    -- CanvasGroup so the whole popup can fade as one piece
    local popup = Instance.new("CanvasGroup")
    popup.Name = config.Name or "DropdownMenu"
    popup.Size = UDim2.fromOffset(self.Width, 0)
    popup.BackgroundColor3 = t.Background
    popup.BackgroundTransparency = t.BackgroundTransparency
    popup.GroupTransparency = 1
    popup.BorderSizePixel = 0
    popup.Active = true
    popup.Visible = false
    popup.Parent = self.Host

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.Corner)
    corner.Parent = popup

    local stroke = Instance.new("UIStroke")
    stroke.Color = t.Stroke
    stroke.Transparency = t.StrokeTransparency
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = popup

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, t.Padding / 2)
    padding.PaddingBottom = UDim.new(0, t.Padding / 2)
    padding.PaddingLeft = UDim.new(0, t.SidePadding)
    padding.PaddingRight = UDim.new(0, t.SidePadding)
    padding.Parent = popup

    local scale = Instance.new("UIScale")
    scale.Scale = t.OpenScale
    scale.Parent = popup

    local pageLayout = Instance.new("UIPageLayout")
    pageLayout.FillDirection = Enum.FillDirection.Horizontal
    pageLayout.EasingStyle = Enum.EasingStyle.Quad
    pageLayout.EasingDirection = Enum.EasingDirection.Out
    pageLayout.TweenTime = t.PageTime
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Circular = false
    pageLayout.Padding = UDim.new(0, 5)
    pageLayout.GamepadInputEnabled = false
    pageLayout.ScrollWheelInputEnabled = false
    pageLayout.TouchInputEnabled = false
    pageLayout.Parent = popup

    self.Popup = popup
    self.Scale = scale
    self.PageLayout = pageLayout

    local function createPage(order)
        local page = Instance.new("ScrollingFrame")
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Size = UDim2.fromScale(1, 1)
        page.LayoutOrder = order
        page.CanvasSize = UDim2.new()
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.ScrollBarThickness = 3
        page.ScrollBarImageTransparency = 0.8
        page.Parent = popup

        local pagePadding = Instance.new("UIPadding")
        pagePadding.PaddingRight = UDim.new(0, 6) -- room for the scrollbar
        pagePadding.Parent = page

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, t.ItemGap)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        return page, layout
    end

    self.MainPage, self.MainLayout = createPage(1)

    local layouts = {self.MainLayout}

    if self.HasChild then
        self.ChildPage, self.ChildLayout = createPage(2)
        table.insert(layouts, self.ChildLayout)

        local back = Instance.new("TextButton")
        back.Size = UDim2.new(1, 0, 0, 20)
        back.LayoutOrder = -1
        back.BackgroundTransparency = 1
        back.AutoButtonColor = false
        back.Text = "<"
        back.TextXAlignment = Enum.TextXAlignment.Left
        back.TextColor3 = t.Muted
        back.Font = t.Font
        back.TextSize = t.TextSize
        back.Parent = self.ChildPage
        self.BackButton = back

        table.insert(self.Connections, back.MouseButton1Click:Connect(function()
            self:ShowMain()
        end))
    end

    if config.Click ~= false then
        table.insert(self.Connections, self.Anchor.MouseButton1Click:Connect(function()
            self:Toggle()
        end))
    end

    -- outside click closes it, clicks on the anchor are left to the anchor
    table.insert(self.Connections, deps.OutsideClick.bind({popup, self.Anchor}, function()
        if self.Open then
            self:SetVisible(false)
        end
    end))

    -- re-place whenever the content or the anchor changes
    for _, layout in ipairs(layouts) do
        table.insert(self.Connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            self:_place(os.clock() - self.OpenedAt < 0.1)
        end))
    end

    table.insert(self.Connections, self.Anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        self:_place(true)
    end))
    table.insert(self.Connections, self.Anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_place(true)
    end))

    return self
end

function DropdownMenu:_place(instant)
    if not self.Open then return end

    local t = self.Theme
    local popup = self.Popup
    local layout = self.OnChild and self.ChildLayout or self.MainLayout

    -- everything is measured against the host, so GUI insets cancel out
    local screen = self.Host.AbsoluteSize
    local origin = self.Anchor.AbsolutePosition - self.Host.AbsolutePosition
    local button = self.Anchor.AbsoluteSize

    local m, gap = t.Margin, t.Gap
    local width = self.Width

    -- AbsoluteContentSize is scaled by the popup's UIScale, so undo that
    local content = layout.AbsoluteContentSize.Y / self.Scale.Scale + t.Padding
    local height = round(math.min(content, screen.Y - m * 2))

    local top, bottom = origin.Y, origin.Y + button.Y
    local left, right = origin.X, origin.X + button.X
    local maxX = math.max(m, screen.X - width - m)
    local maxY = math.max(m, screen.Y - height - m)

    local placements = {
        { -- below, right-aligned to the anchor
            Fits = bottom + gap + height <= screen.Y - m,
            X = math.clamp(right - width, m, maxX),
            Y = bottom + gap,
        },
        { -- above
            Fits = top - gap - height >= m,
            X = math.clamp(right - width, m, maxX),
            Y = top - gap - height,
        },
        { -- right
            Fits = right + gap + width <= screen.X - m,
            X = right + gap,
            Y = math.clamp(top, m, maxY),
        },
        { -- left
            Fits = left - gap - width >= m,
            X = left - gap - width,
            Y = math.clamp(top, m, maxY),
        },
    }

    local chosen
    for _, p in ipairs(placements) do
        if p.Fits then
            chosen = p
            break
        end
    end

    local x = chosen and round(chosen.X) or 0
    local y = chosen and round(chosen.Y) or 0

    popup.AnchorPoint = chosen and Vector2.zero or Vector2.new(0.5, 0.5)

    local size = UDim2.fromOffset(width, height)
    local position = chosen and UDim2.fromOffset(x, y) or UDim2.fromScale(0.5, 0.5)

    local last = self.Last
    local changed = last.Height ~= height or last.X ~= x or last.Y ~= y or last.Centered ~= (chosen == nil)

    if instant then
        popup.Size = size
        popup.Position = position
    elseif changed then
        TweenService:Create(popup, TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = size,
            Position = position,
        }):Play()
    end

    last.Height, last.X, last.Y, last.Centered = height, x, y, (chosen == nil)
end

function DropdownMenu:SetVisible(state)
    if state == nil then
        state = not self.Open
    end
    if state == self.Open then return end

    self.Open = state
    self.Token = self.Token + 1
    local token = self.Token
    local t = self.Theme

    if state then
        self.OpenedAt = os.clock()
        self.Popup.Visible = true
        self:_place(true)

        local info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(self.Scale, info, {Scale = 1}):Play()
        TweenService:Create(self.Popup, info, {GroupTransparency = 0}):Play()
    else
        self.ClosedAt = os.clock()

        local info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        TweenService:Create(self.Scale, info, {Scale = t.OpenScale}):Play()
        TweenService:Create(self.Popup, info, {GroupTransparency = 1}):Play()

        -- hide after the fade, and go back to the main page
        task.delay(t.TweenTime, function()
            if self.Destroyed or self.Token ~= token then return end

            self.Popup.Visible = false
            if self.OnChild then
                self:ShowMain()
            end
        end)
    end
end

function DropdownMenu:Toggle()
    self:SetVisible(nil)
end

function DropdownMenu:Show()
    self:SetVisible(true)
end

function DropdownMenu:Hide()
    self:SetVisible(false)
end

function DropdownMenu:ShowChild(title)
    if not self.HasChild then return end

    self.OnChild = true
    self.BackButton.Text = "<  " .. (title or "")
    self.PageLayout:JumpTo(self.ChildPage)
    self:_place(false)
end

function DropdownMenu:ShowMain()
    self.OnChild = false
    self.PageLayout:JumpTo(self.MainPage)
    self.OnMain()
    self:_place(false)
end

function DropdownMenu:_item(page, text, callback, closes)
    local t = self.Theme

    self.Orders[page] = (self.Orders[page] or 0) + 1

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, t.ItemHeight)
    btn.LayoutOrder = self.Orders[page]
    btn.BackgroundColor3 = t.Hover
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = text or "Button"
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = t.Foreground
    btn.Font = t.Font
    btn.TextSize = t.TextSize
    btn.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.ItemCorner)
    corner.Parent = btn

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = btn

    local info = TweenInfo.new(t.HoverTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, info, {BackgroundTransparency = 0}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, info, {BackgroundTransparency = 1}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if closes then
            self:SetVisible(false)
        end
        if callback then callback() end
    end)

    return btn
end

function DropdownMenu:AddButton(text, callback, page)
    return self:_item(page or self.MainPage, text, callback, self.CloseOnClick)
end

-- build(add) fills the submenu page; add(text, callback) adds a button to it
function DropdownMenu:AddSubmenu(text, build)
    local btn = self:_item(self.MainPage, text, function()
        self:ShowChild(text)
    end, false)

    local chevron = Instance.new("TextLabel")
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, 0, 0.5, 0)
    chevron.Size = UDim2.fromOffset(16, 16)
    chevron.BackgroundTransparency = 1
    chevron.Text = ">"
    chevron.Font = self.Theme.Font
    chevron.TextSize = self.Theme.TextSize
    chevron.TextColor3 = self.Theme.Muted
    chevron.Parent = btn

    if build and self.HasChild then
        build(function(childText, callback)
            return self:_item(self.ChildPage, childText, callback, self.CloseOnClick)
        end)
    end

    return btn
end

function DropdownMenu:Destroy()
    self.Destroyed = true
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Popup:Destroy()
end

return DropdownMenu
