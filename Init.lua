local BASE = "https://raw.githubusercontent.com/zevnkei/zoncn/main/"

local function load(path)
    local src = game:HttpGet(BASE .. path)
    local fn, err = loadstring(src)
    assert(fn, err)
    return fn()
end

local Theme = load("themes/Default.lua")
local Spring = load("utilities/Spring.lua")
local Modal = load("utilities/Modal.lua")
local OutsideClick = load("utilities/OutsideClick.lua")

local deps = {Spring = Spring, Modal = Modal, OutsideClick = OutsideClick}

local Components = {}

for _, name in ipairs({"Switch", "Button", "Slider", "DropdownMenu"}) do
    local mod = load("components/" .. name .. ".lua")

    Components[name] = {
        new = function(parent, config, theme)
            return mod.new(parent, config, theme or Theme[name], deps)
        end,
    }
end

return Components
