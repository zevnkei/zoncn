local BASE = "https://raw.githubusercontent.com/zevnkei/zoncn/main/"

local function load(path)
    local src = game:HttpGet(BASE .. path)
    local fn, err = loadstring(src)
    assert(fn, err)
    return fn()
end

local Theme = load("themes/Default.lua")

local deps = {
    Spring = load("utilities/Spring.lua"),
    Modal = load("utilities/Modal.lua"),
    OutsideClick = load("utilities/OutsideClick.lua"),
    Icons = load("utilities/Icons.lua"),
}

local Components = {}

for _, name in ipairs({"Switch", "Checkbox", "Button", "Dialog", "Slider", "DropdownMenu"}) do
    local mod = load("components/" .. name .. ".lua")

    Components[name] = {
        new = function(parent, config, theme)
            return mod.new(parent, config, theme or Theme[name], deps)
        end,
    }
end

return Components
