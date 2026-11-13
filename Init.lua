local BASE = "https://raw.githubusercontent.com/zevnkei/zoncn/main/"

local function load(path)
    local src = game:HttpGet(BASE .. path)
    local fn, err = loadstring(src)
    assert(fn, err)
    return fn()
end

local Theme = load("themes/Default.lua")

local Components = {}

for _, name in ipairs({"Switch", "Button", "Slider"}) do
    local mod = load("components/" .. name .. ".lua")

    Components[name] = {
        new = function(parent, config, theme)
            -- use the passed theme, or fall back to the default for this component
            return mod.new(parent, config, theme or Theme[name])
        end,
    }
end

return Components
