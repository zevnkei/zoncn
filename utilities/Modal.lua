local TweenService = game:GetService("TweenService")

local Modal = {}

local Pop = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local Leave = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

-- cfg: a plain table that holds the ModalId between calls (pass the same one each time)
-- overlay: optional dimmer Frame, or nil
-- scale: the UIScale on the panel
-- open: true or false
function Modal.toggle(cfg, overlay, scale, open)
    cfg.ModalId = (cfg.ModalId or 0) + 1
    local id = cfg.ModalId
    local dim = cfg.OverlayDim or 0.5

    if open then
        if overlay then
            overlay.Visible = true
            overlay.BackgroundTransparency = 1
            TweenService:Create(overlay, Smooth, {BackgroundTransparency = dim}):Play()
        end

        scale.Scale = 0.9
        TweenService:Create(scale, Pop, {Scale = 1}):Play()
    else
        if overlay then
            TweenService:Create(overlay, Leave, {BackgroundTransparency = 1}):Play()
        end

        local shrink = TweenService:Create(scale, Leave, {Scale = 0.92})
        shrink.Completed:Once(function()
            if overlay and cfg.ModalId == id then
                overlay.Visible = false
            end
        end)
        shrink:Play()
    end
end

return Modal
