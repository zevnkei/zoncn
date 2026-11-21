local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Toast = {}
Toast.__index = Toast

local Item = {}
Item.__index = Item

local DEFAULT_THEME = {
    Background = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(45, 45, 45),
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    ActionBackground = Color3.fromRGB(240, 245, 240),
    ActionText = Color3.fromRGB(13, 13, 13),
    Font = Enum.Font.GothamSemibold,
    DescFont = Enum.Font.GothamMedium,
    TitleSize = 14,
    DescSize = 13,
    Width = 260,
    Corner = 12,
    Padding = 16,
    IconSize = 16,
    IconGap = 10,
    RingThickness = 2,
    ActionHeight = 26,
    Margin = 24,
    Gap = 14,
    Peek = 12,
    Max = 3, 
    Duration = 5,
    TweenTime = 0.35,
    Types = {
        Success = {Icon = "lucide/circle-check", Color = Color3.fromRGB(34, 197, 94)},
        Error = {Icon = "lucide/circle-x", Color = Color3.fromRGB(239, 68, 68)},
        Warning = {Icon = "lucide/triangle-alert", Color = Color3.fromRGB(245, 158, 11)},
        Info = {Icon = "lucide/info", Color = Color3.fromRGB(59, 130, 246)},
    },
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

local function tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

local function setFont(label, font)
    if typeof(font) == "Font" then
        label.FontFace = font
    else
        label.Font = font
    end
end

local function normalize(name)
    if type(name) ~= "string" or #name == 0 then
        return "Default"
    end
    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

-- toasts live in their own full-screen host inside the ScreenGui, above the
-- popups host (ZoncnPopups) so they always sit over menus and dialogs
local function getHost(parent)
    local root = parent
    if not parent:IsA("ScreenGui") then
        root = parent:FindFirstAncestorWhichIsA("ScreenGui") or parent
    end

    local host = root:FindFirstChild("ZoncnToasts")
    if not host then
        host = Instance.new("Frame")
        host.Name = "ZoncnToasts"
        host.Size = UDim2.fromScale(1, 1)
        host.BackgroundTransparency = 1
        host.BorderSizePixel = 0
        host.ZIndex = 20
        host.Parent = root
    end

    return host
end

--// Toaster

-- config: Position ("BottomRight", "BottomLeft", "BottomCenter", "TopRight", ...), Max, Duration
function Toast.new(parent, config, theme, deps)
    config = config or {}

    local t = merge(DEFAULT_THEME, theme)
    local self = setmetatable({}, Toast)
    self.Theme = t
    self.Icons = deps and deps.Icons -- optional
    self.Max = config.Max or t.Max
    self.Duration = config.Duration or t.Duration
    self.Host = getHost(parent)

    local position = config.Position or "BottomRight"
    self.Top = position:find("Top") ~= nil
    self.Side = position:find("Left") and "Left" or (position:find("Right") and "Right" or "Center")

    self.Active = {}      -- oldest first
    self.Hovered = 0
    self.Expanded = false
    self.Loop = nil
    self.Destroyed = false

    return self
end

-- offset: distance from the screen edge, past Margin (grows away from the edge)
-- extraX: horizontal slide, used when a toast leaves
function Toast:_position(offset, extraX)
    local t = self.Theme
    local side = self.Side

    local xScale = side == "Left" and 0 or (side == "Right" and 1 or 0.5)
    local xOffset = 0
    if side == "Left" then
        xOffset = t.Margin + t.Width / 2
    elseif side == "Right" then
        xOffset = -(t.Margin + t.Width / 2)
    end

    local yScale = self.Top and 0 or 1
    local yOffset = self.Top and (t.Margin + offset) or -(t.Margin + offset)

    return UDim2.new(xScale, xOffset + (extraX or 0), yScale, yOffset)
end

function Toast:_type(name)
    name = normalize(name)
    if name == "Default" or name == "Loading" or self.Theme.Types[name] then
        return name
    end
    return "Default"
end

-- stacked: newest in front, older ones peek out behind it
-- expanded (while hovered): every toast at full size in a list
function Toast:_restack()
    local t = self.Theme
    local list = self.Active
    local total = #list
    local front = list[total]
    local info = TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    local offset = 0

    for i = total, 1, -1 do
        local item = list[i]

        if item.Height then
            local depth = total - i
            local scale, y, height

            if self.Expanded then
                scale, y, height = 1, offset, item.Height
                offset = offset + item.Height + t.Gap
            else
                scale = math.max(0.8, 1 - depth * 0.05)
                y = depth * t.Peek
                -- back toasts take the front toast's height so only a strip shows
                height = (front and front.Height) or item.Height
            end

            item.Card.ZIndex = i

            tween(item.Card, info, {
                Position = self:_position(y),
                Size = UDim2.fromOffset(t.Width, height),
                GroupTransparency = 0,
            })
            tween(item.Scale, info, {Scale = scale})
        end
    end
end

function Toast:_hover(item, delta)
    item.Hover = math.max(0, item.Hover + delta)
    self.Hovered = math.max(0, self.Hovered + delta)

    if self.Hovered > 0 then
        if not self.Expanded then
            self.Expanded = true
            self:_restack()
        end
    else
        -- moving between a toast and its action button briefly reads as 0
        task.delay(0.12, function()
            if not self.Destroyed and self.Hovered == 0 and self.Expanded then
                self.Expanded = false
                self:_restack()
            end
        end)
    end
end

-- timers pause while the stack is hovered
function Toast:_tick(dt)
    if self.Hovered > 0 then return end

    for _, item in ipairs(table.clone(self.Active)) do
        if item.Remaining ~= math.huge then
            item.Remaining = item.Remaining - dt
            if item.Remaining <= 0 then
                item:Dismiss()
            end
        end
    end
end

function Toast:_remove(item)
    local t = self.Theme

    local index = table.find(self.Active, item)
    if index then
        table.remove(self.Active, index)
    end

    self.Hovered = math.max(0, self.Hovered - item.Hover)
    item.Hover = 0
    item:_stopSpin()

    -- slide out toward the nearest side and fade
    local direction = self.Side == "Left" and -1 or (self.Side == "Right" and 1 or 0)
    local target = self:_position(0, direction * (t.Width + t.Margin + 20))
    local current = item.Card.Position

    local leave = TweenService:Create(item.Card, TweenInfo.new(t.TweenTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        GroupTransparency = 1,
        Position = UDim2.new(target.X.Scale, target.X.Offset, current.Y.Scale, current.Y.Offset),
    })
    leave.Completed:Once(function()
        for _, conn in ipairs(item.Connections) do
            conn:Disconnect()
        end
        item.Card:Destroy()
    end)
    leave:Play()

    if #self.Active == 0 then
        self.Expanded = false
        if self.Loop then
            self.Loop:Disconnect()
            self.Loop = nil
        end
    else
        self:_restack()
    end
end

-- data: Title, Description, Type, Icon, Duration, Action = {Text, Callback}, Dismissable
-- a plain string is treated as the title; returns the toast so you can :Update / :Dismiss it
function Toast:Show(data)
    if type(data) == "string" then
        data = {Title = data}
    end
    data = data or {}

    local t = self.Theme

    local item = setmetatable({}, Item)
    item.Toaster = self
    item.Type = self:_type(data.Type)
    item.IconPath = data.Icon
    item.Action = data.Action
    item.Remaining = data.Duration or (item.Type == "Loading" and math.huge or self.Duration)
    item.Height = nil
    item.Hover = 0
    item.Dismissed = false
    item.Connections = {}

    -- fixed-size card (clips its content), invisible until the content is measured
    local card = Instance.new("CanvasGroup")
    card.Name = "Toast"
    card.AnchorPoint = Vector2.new(0.5, self.Top and 0 or 1)
    card.Size = UDim2.fromOffset(t.Width, 0)
    card.Position = self:_position(0)
    card.BackgroundColor3 = t.Background
    card.BorderSizePixel = 0
    card.GroupTransparency = 1
    card.Parent = self.Host

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, t.Corner)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = t.Border
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = card

    local scale = Instance.new("UIScale")
    scale.Parent = card

    local hit = Instance.new("ImageButton")
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.AutoButtonColor = false
    hit.ZIndex = 1
    hit.Parent = card

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ZIndex = 2
    content.Parent = card

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, t.Padding)
    padding.PaddingBottom = UDim.new(0, t.Padding)
    padding.PaddingLeft = UDim.new(0, t.Padding)
    padding.PaddingRight = UDim.new(0, t.Padding)
    padding.Parent = content

    -- icon, lines up with the first line of the title
    local iconImage = Instance.new("ImageLabel")
    iconImage.Size = UDim2.fromOffset(t.IconSize, t.IconSize)
    iconImage.Position = UDim2.fromOffset(0, 1)
    iconImage.BackgroundTransparency = 1
    iconImage.BorderSizePixel = 0
    iconImage.Visible = false
    iconImage.ZIndex = 2
    iconImage.Parent = content

    -- loading spinner: a ring with a faded tail, spun by a looping tween (no assets needed)
    local ringSize = t.IconSize - t.RingThickness * 2
    local ring = Instance.new("Frame")
    ring.Size = UDim2.fromOffset(ringSize, ringSize)
    ring.Position = UDim2.fromOffset(t.RingThickness, 1 + t.RingThickness)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.Visible = false
    ring.ZIndex = 2
    ring.Parent = content

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = ring

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Thickness = t.RingThickness
    ringStroke.Color = t.Foreground
    ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ringStroke.Parent = ring

    local ringTail = Instance.new("UIGradient")
    ringTail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 0),
    })
    ringTail.Parent = ringStroke

    -- text column
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ZIndex = 2
    body.Parent = content

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 2)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    local title = Instance.new("TextLabel")
    title.LayoutOrder = 1
    title.Size = UDim2.new(1, 0, 0, 0)
    title.AutomaticSize = Enum.AutomaticSize.Y
    title.BackgroundTransparency = 1
    title.TextSize = t.TitleSize
    title.TextColor3 = t.Foreground
    title.TextWrapped = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.ZIndex = 2
    title.Parent = body
    setFont(title, t.Font)

    local desc = Instance.new("TextLabel")
    desc.LayoutOrder = 2
    desc.Size = UDim2.new(1, 0, 0, 0)
    desc.AutomaticSize = Enum.AutomaticSize.Y
    desc.BackgroundTransparency = 1
    desc.TextSize = t.DescSize
    desc.TextColor3 = t.Muted
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.ZIndex = 2
    desc.Parent = body
    setFont(desc, t.DescFont)

    item.Card = card
    item.Scale = scale
    item.Content = content
    item.Body = body
    item.Title = title
    item.Desc = desc
    item.IconImage = iconImage
    item.Ring = ring

    local titleText = data.Title or data.Name or ""
    local descText = data.Description or data.Desc or ""
    title.Text = titleText
    title.Visible = #titleText > 0
    desc.Text = descText
    desc.Visible = #descText > 0

    -- hovering any toast (or its action button) expands the stack
    local function bindHover(gui)
        table.insert(item.Connections, gui.MouseEnter:Connect(function()
            self:_hover(item, 1)
        end))
        table.insert(item.Connections, gui.MouseLeave:Connect(function()
            self:_hover(item, -1)
        end))
    end
    item.BindHover = bindHover
    bindHover(hit)

    item:_applyType()
    item:_applyAction()

    if data.Dismissable ~= false then
        table.insert(item.Connections, hit.MouseButton1Click:Connect(function()
            item:Dismiss()
        end))
    end

    -- measure the content (in unscaled units); the first measurement slides the toast in
    local function measure()
        local height = round(content.AbsoluteSize.Y / math.max(scale.Scale, 0.01))
        if height > 0 and height ~= item.Height then
            local first = item.Height == nil
            item.Height = height

            if first then
                -- start just past its slot (toward the screen edge), restack tweens it in
                card.Size = UDim2.fromOffset(t.Width, height)
                card.Position = self:_position(-24)
            end

            self:_restack()
        end
    end

    table.insert(item.Connections, content:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure))
    task.defer(measure)

    table.insert(self.Active, item)

    if not self.Loop then
        self.Loop = RunService.Heartbeat:Connect(function(dt)
            self:_tick(dt)
        end)
    end

    -- over the limit: the oldest one leaves
    while #self.Active > self.Max do
        self.Active[1]:Dismiss()
    end

    return item
end

local function shortcut(kind)
    return function(self, title, description)
        return self:Show({Type = kind, Title = title, Description = description})
    end
end

Toast.Success = shortcut("Success")
Toast.Error = shortcut("Error")
Toast.Warning = shortcut("Warning")
Toast.Info = shortcut("Info")
Toast.Loading = shortcut("Loading")

function Toast:DismissAll()
    for index = #self.Active, 1, -1 do
        self.Active[index]:Dismiss()
    end
end

function Toast:Destroy()
    self.Destroyed = true

    if self.Loop then
        self.Loop:Disconnect()
        self.Loop = nil
    end

    for _, item in ipairs(table.clone(self.Active)) do
        item:_stopSpin()
        for _, conn in ipairs(item.Connections) do
            conn:Disconnect()
        end
        item.Card:Destroy()
    end
    table.clear(self.Active)

    if #self.Host:GetChildren() == 0 then
        self.Host:Destroy()
    end
end

--// Single toast

-- icon / spinner on the left, text column fills what's left, action button on the right
function Item:_layout()
    local t = self.Toaster.Theme

    local hasIcon = self.IconImage.Visible or self.Ring.Visible
    local left = hasIcon and (t.IconSize + t.IconGap) or 0

    local right = 0
    if self.ActionButton and self.ActionButton.Visible then
        right = self.ActionButton.AbsoluteSize.X / math.max(self.Scale.Scale, 0.01) + t.IconGap
    end

    self.Body.Position = UDim2.fromOffset(left, 0)
    self.Body.Size = UDim2.new(1, -(left + right), 0, 0)
end

function Item:_stopSpin()
    if self.Spin then
        self.Spin:Cancel()
        self.Spin = nil
    end
    self.Ring.Rotation = 0
end

function Item:_applyType()
    local toaster = self.Toaster
    local t = toaster.Theme
    local preset = t.Types[self.Type] or {}

    local loading = self.Type == "Loading" and self.IconPath == nil
    local path = self.IconPath or preset.Icon
    local hasIcon = not loading and type(path) == "string" and #path > 0 and toaster.Icons ~= nil

    self:_stopSpin()

    self.Ring.Visible = loading
    self.IconImage.Visible = hasIcon
    self.IconImage.ImageColor3 = preset.Color or t.Foreground

    if loading then
        self.Spin = TweenService:Create(self.Ring, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
            Rotation = 360,
        })
        self.Spin:Play()
    end

    if hasIcon then
        toaster.Icons.apply(self.IconImage, "Image", path)

        -- the icon pack failed to load: don't leave an empty gap
        toaster.Icons.onReady(function()
            if self.IconImage.Image == "" then
                self.IconImage.Visible = false
                self:_layout()
            end
        end)
    end

    self:_layout()
end

function Item:_applyAction()
    local t = self.Toaster.Theme
    local action = self.Action

    if not action then
        if self.ActionButton then
            self.ActionButton.Visible = false
        end
        self:_layout()
        return
    end

    if not self.ActionButton then
        local button = Instance.new("TextButton")
        button.AnchorPoint = Vector2.new(1, 0.5)
        button.Position = UDim2.new(1, 0, 0.5, 0)
        button.Size = UDim2.new(0, 0, 0, t.ActionHeight)
        button.AutomaticSize = Enum.AutomaticSize.X
        button.AutoButtonColor = false
        button.BorderSizePixel = 0
        button.BackgroundColor3 = t.ActionBackground
        button.TextColor3 = t.ActionText
        button.TextSize = 13
        button.ZIndex = 3
        button.Parent = self.Content
        setFont(button, t.Font)

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button

        local buttonPad = Instance.new("UIPadding")
        buttonPad.PaddingLeft = UDim.new(0, 10)
        buttonPad.PaddingRight = UDim.new(0, 10)
        buttonPad.Parent = button

        table.insert(self.Connections, button.MouseButton1Click:Connect(function()
            local callback = self.Action and self.Action.Callback
            if callback then
                task.spawn(callback)
            end
            self:Dismiss()
        end))
        table.insert(self.Connections, button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            self:_layout()
        end))
        self.BindHover(button)

        self.ActionButton = button
    end

    self.ActionButton.Text = action.Text or action.Name or "Undo"
    self.ActionButton.Visible = true
    self:_layout()
end

-- change a toast that's already showing, e.g. Loading -> Success when the work is done
-- new: Title, Description, Type, Icon, Duration, Action
function Item:Update(new)
    new = new or {}

    local title = new.Title or new.Name
    local desc = new.Description or new.Desc

    if title ~= nil then
        self.Title.Text = title
        self.Title.Visible = #title > 0
    end

    if desc ~= nil then
        self.Desc.Text = desc
        self.Desc.Visible = #desc > 0
    end

    if new.Type ~= nil then
        self.Type = self.Toaster:_type(new.Type)
        self.IconPath = new.Icon
    elseif new.Icon ~= nil then
        self.IconPath = new.Icon
    end

    if new.Action ~= nil then
        self.Action = new.Action or nil
        self:_applyAction()
    end

    self:_applyType()

    if new.Duration ~= nil then
        self.Remaining = new.Duration
    elseif self.Type == "Loading" then
        self.Remaining = math.huge
    elseif self.Remaining == math.huge then
        self.Remaining = self.Toaster.Duration
    end

    return self
end

function Item:Dismiss()
    if self.Dismissed then return end

    self.Dismissed = true
    self.Toaster:_remove(self)
end

return Toast
