local TweenService = game:GetService("TweenService")

local DropdownMenu = {}
DropdownMenu.__index = DropdownMenu

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
    Hover = Color3.fromRGB(35, 35, 35),
    Font = Enum.Font.GothamMedium,
    Corner = 20,
    ItemCorner = 8,
    ItemHeight = 32,
    Margin = 24,
    Gap = 6,
    Padding = 8,
    TweenTime = 0.25,
}

local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over or {}) do out[k] = v end
    return out
end

function DropdownMenu.new(parent, config, theme, deps)
    config = config or {}
    assert(config.Anchor, "DropdownMenu needs config.Anchor")
    assert(deps and deps.Modal and deps.OutsideClick, "DropdownMenu needs deps.Modal and deps.OutsideClick")

    local t = merge(DEFAULT_THEME, theme)
    local self = setmetatable({}, DropdownMenu)
    self.Parent = parent
    self.Anchor = config.Anchor
    self.Width = config.Width or 200
    self.HasChild = config.Child or false
    self.OnMain = config.OnMain or function() end
    self.Theme = t
    self.Modal = deps.Modal
    self.OutsideClick = deps.OutsideClick
    self.ModalCfg = {}
    self.Open = false
    self.OnChild = false
    self.OpenedAt = 0
    self.ClosedAt = 0
    self.LastSize = nil
    self.LastPosition = nil
    self.Connections = {}

    local popup = Instance.new("Frame")
    popup.Name = config.Name or "DropdownMenu"
    popup.Size = UDim2.fromOffset(self.Width, 0)
    popup.BackgroundColor3 = t.Background
    popup.BackgroundTransparency = 0.1
    popup.BorderSizePixel = 0
    popup.Active = true
    popup.ClipsDescendants = true
    popup.Visible = false
    popup.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.Corner)
    corner.Parent = popup

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, t.Padding / 2)
    padding.PaddingBottom = UDim.new(0, t.Padding / 2)
    padding.PaddingLeft = UDim.new(0, t.Padding)
    padding.PaddingRight = UDim.new(0, t.Padding)
    padding.Parent = popup

    local scale = Instance.new("UIScale")
    scale.Scale = 0.95
    scale.Parent = popup

    self.Popup = popup
    self.Scale = scale

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
        page.Visible = false
        page.Parent = popup

        local pagePadding = Instance.new("UIPadding")
        pagePadding.PaddingRight = UDim.new(0, 6)
        pagePadding.Parent = page

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        return page, layout
    end

    self.MainPage, self.MainLayout = createPage(1)
    self.MainPage.Visible = true

    if self.HasChild then
        self.ChildPage, self.ChildLayout = createPage(2)

        local back = Instance.new("TextButton")
        back.Size = UDim2.new(1, 0, 0, 20)
        back.LayoutOrder = -1
        back.BackgroundTransparency = 1
        back.AutoButtonColor = false
        back.Text = "< Back"
        back.TextXAlignment = Enum.TextXAlignment.Left
        back.TextColor3 = t.Foreground
        setFont(back, t.Font)
        back.TextSize = 14
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
    table.insert(self.Connections, self.OutsideClick.bind({self.Popup, self.Anchor}, function()
        self:SetVisible(false)
    end))

    for _, layout in ipairs({self.MainLayout, self.ChildLayout}) do
        table.insert(self.Connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            self:_place(os.clock() - self.OpenedAt < 0.1)
        end))
    end

    return self
end

function DropdownMenu:_place(instant)
    if not self.Open then return end

    local t = self.Theme
    local popup = self.Popup
    local layout = self.OnChild and self.ChildLayout or self.MainLayout

    -- work in the container's space so positions line up
    local base = self.Parent:IsA("GuiObject") and self.Parent.AbsolutePosition or Vector2.zero
    local screen = self.Parent:IsA("GuiObject") and self.Parent.AbsoluteSize or workspace.CurrentCamera.ViewportSize

    local origin = self.Anchor.AbsolutePosition - base
    local button = self.Anchor.AbsoluteSize

    local m, gap = t.Margin, t.Gap
    local content = layout.AbsoluteContentSize.Y + t.Padding
    local height = math.min(content, screen.Y - m * 2)
    local width = self.Width

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

    popup.AnchorPoint = chosen and Vector2.zero or Vector2.new(0.5, 0.5)

    local size = UDim2.fromOffset(width, height)
    local position = chosen and UDim2.fromOffset(chosen.X, chosen.Y) or UDim2.fromScale(0.5, 0.5)

    if instant then
        popup.Size = size
        popup.Position = position
    elseif size ~= self.LastSize or position ~= self.LastPosition then
        TweenService:Create(popup, TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = size,
            Position = position,
        }):Play()
    end

    self.LastSize = size
    self.LastPosition = position
end

function DropdownMenu:SetVisible(state)
    if state == nil then
        state = not self.Open
    end
    if state == self.Open then return end

    self.Open = state

    if state then
        self.OpenedAt = os.clock()
        self.Popup.Visible = true
        self:_place(true)
    else
        self.ClosedAt = os.clock()
    end

    self.Modal.toggle(self.ModalCfg, nil, self.Scale, state)

    if not state then
        -- hide after the fade, and return to the main page
        task.delay(0.25, function()
            if not self.Open then
                self.Popup.Visible = false
                if self.OnChild then
                    self:ShowMain()
                end
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
    self.BackButton.Text = "< " .. (title or "")
    self.MainPage.Visible = false
    self.ChildPage.Visible = true
    self:_place(false)
end

function DropdownMenu:ShowMain()
    self.OnChild = false
    if self.ChildPage then
        self.ChildPage.Visible = false
    end
    self.MainPage.Visible = true
    self.OnMain()
    self:_place(false)
end

function DropdownMenu:AddButton(text, callback, page)
    local t = self.Theme
    page = page or self.MainPage

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, t.ItemHeight)
    btn.BackgroundColor3 = t.Hover
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = text or "Button"
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = t.Foreground
    setFont(btn, t.Font)
    btn.TextSize = 14
    btn.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.ItemCorner)
    corner.Parent = btn

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundTransparency = 0
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundTransparency = 1
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

-- build(addChild) fills the submenu page; addChild(text, callback) adds a button to it
function DropdownMenu:AddSubmenu(text, build)
    local btn = self:AddButton(text .. " >", function()
        self:ShowChild(text)
    end)

    if build and self.HasChild then
        build(function(childText, callback)
            return self:AddButton(childText, callback, self.ChildPage)
        end)
    end

    return btn
end

function DropdownMenu:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Popup:Destroy()
end

return DropdownMenu
