local TextService = game:GetService("TextService")

local TextFit = {}

local function getScale(gui)
    local scale = 1
    local current = gui

    while current do
        local uiScale = current:FindFirstChildOfClass("UIScale")
        if uiScale then
            scale = scale * uiScale.Scale
        end
        current = current.Parent
    end

    return math.max(scale, 0.01)
end

-- keeps target's size fitting the text in textObject
-- config: TextObject, Target, Axis ("X" grows the width, "Y" grows the height),
--  Min, Max, Padding (added to the measured text size)
-- returns {Update, Destroy}
function TextFit.bind(config)
    local textObject = config.TextObject
    local target = config.Target
    local axis = config.Axis or "Y"
    local min = config.Min or 0
    local max = config.Max or math.huge
    local padding = config.Padding or 0

    local params = Instance.new("GetTextBoundsParams")
    params.Font = textObject.FontFace
    params.Size = textObject.TextSize

    local connections = {}
    local ticket = 0
    local destroyed = false

    local function update()
        -- measuring yields, so only the newest call is allowed to resize
        ticket = ticket + 1
        local mine = ticket

        local text = textObject.Text
        if text == "" then
            text = textObject.PlaceholderText
        end
        if text == "" then
            text = " "
        end

        params.Text = text
        -- wrap width is in unscaled units, so undo any UIScale on the way up
        params.Width = axis == "X" and math.huge or math.max(target.AbsoluteSize.X / getScale(target) - padding, 1)

        local ok, bounds = pcall(function()
            return TextService:GetTextBoundsAsync(params)
        end)

        if destroyed or mine ~= ticket or not ok or not bounds then
            return
        end

        local measured = math.ceil(axis == "X" and bounds.X or bounds.Y) + padding
        local value = math.clamp(measured, min, max)

        local size = target.Size
        local newSize
        if axis == "X" then
            newSize = UDim2.new(0, value, size.Y.Scale, size.Y.Offset)
        else
            newSize = UDim2.new(size.X.Scale, size.X.Offset, 0, value)
        end

        if size ~= newSize then
            target.Size = newSize
        end
    end

    table.insert(connections, textObject:GetPropertyChangedSignal("Text"):Connect(update))
    table.insert(connections, textObject:GetPropertyChangedSignal("PlaceholderText"):Connect(update))
    table.insert(connections, textObject:GetPropertyChangedSignal("FontFace"):Connect(function()
        params.Font = textObject.FontFace
        update()
    end))
    table.insert(connections, textObject:GetPropertyChangedSignal("TextSize"):Connect(function()
        params.Size = textObject.TextSize
        update()
    end))

    -- the wrap width depends on the target's width
    if axis == "Y" then
        table.insert(connections, target:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
    end

    task.defer(update)

    return {
        Update = update,
        Destroy = function()
            destroyed = true
            for _, conn in ipairs(connections) do
                conn:Disconnect()
            end
        end,
    }
end

return TextFit
