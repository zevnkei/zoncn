local Label = {}
Label.__index = Label

local DEFAULT_THEME = {
    Foreground = Color3.fromRGB(240, 245, 240),
    Muted = Color3.fromRGB(150, 150, 150),
    Font = Enum.Font.GothamSemibold, -- Enum.Font, a Font object, or a font family string
    Weight = Enum.FontWeight.SemiBold, -- only used when Font is a family string
    Style = Enum.FontStyle.Normal,
    Size = 15,
    MutedSize = 14,
    Transparency = 0.1,
    MutedTransparency = 0.3,
    Height = 20,
}

-- font can be an Enum.Font, a Font object (Font.new(...)) or a family string
-- such as "rbxasset://fonts/families/GothamSSm.json" or "rbxassetid://12345"
local function applyFont(label, font, weight, style)
    if typeof(font) == "Font" then
        label.FontFace = font
    elseif typeof(font) == "EnumItem" then
        label.Font = font
    elseif type(font) == "string" then
        label.FontFace = Font.new(font, weight, style)
    end
end

function Label.new(parent, config, theme)
    config = config or {}

    local t = {}
    for k, v in pairs(DEFAULT_THEME) do t[k] = v end
    for k, v in pairs(theme or {}) do t[k] = v end

    local muted = config.Muted and true or false

    local self = setmetatable({}, Label)
    self.Theme = t
    self.Weight = config.Weight or t.Weight
    self.Style = config.Style or t.Style

    local label = Instance.new("TextLabel")
    label.Name = config.Name or "Label"
    label.Text = config.Text or config.Name or "Label"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.TextSize = config.Size or (muted and t.MutedSize or t.Size)
    label.TextColor3 = config.Color or (muted and t.Muted or t.Foreground)
    label.TextTransparency = config.Transparency or (muted and t.MutedTransparency or t.Transparency)
    label.TextXAlignment = config.Align or Enum.TextXAlignment.Left
    label.TextWrapped = config.Wrapped ~= false
    label.Parent = parent

    if config.AutoWidth then
        -- hugs its text instead of filling the row
        label.Size = UDim2.new(0, 0, 0, t.Height)
        label.AutomaticSize = Enum.AutomaticSize.XY
    else
        -- fills the row and grows downward when the text wraps
        label.Size = UDim2.new(1, 0, 0, t.Height)
        label.AutomaticSize = Enum.AutomaticSize.Y
    end

    applyFont(label, config.Font or t.Font, self.Weight, self.Style)

    self.Label = label
    return self
end

function Label:SetText(text)
    self.Label.Text = text or ""
end

function Label:GetText()
    return self.Label.Text
end

function Label:SetFont(font, weight, style)
    self.Weight = weight or self.Weight
    self.Style = style or self.Style
    applyFont(self.Label, font, self.Weight, self.Style)
end

function Label:SetColor(color)
    self.Label.TextColor3 = color
end

function Label:Destroy()
    self.Label:Destroy()
end

return Label
