local UserInputService = game:GetService("UserInputService")

local OutsideClick = {}

local function pointInside(gui, point)
    local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

-- targets: list of GuiObjects that count as "inside"
-- onOutside: called when a click lands outside all visible targets
function OutsideClick.bind(targets, onOutside)
    return UserInputService.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
            return
        end

        local point = Vector2.new(input.Position.X, input.Position.Y)
        for _, gui in ipairs(targets) do
            if gui.Visible and pointInside(gui, point) then
                return
            end
        end

        onOutside()
    end)
end

return OutsideClick
