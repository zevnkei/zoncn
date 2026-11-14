local Icons = {}

local module = nil
local loaded = false
local queue = {}

local function resolveIcon(path)
    if not module then return "" end

    -- "lucide/check" picks the icon set, "check" uses whatever is current
    local kind, name = path:match("^(.+)/(.+)$")
    if kind then
        module.SetIconsType(kind)
        return module.GetIcon(name) or ""
    end

    return module.GetIcon(path) or ""
end

-- the icon pack loads in the background, so loading the library never waits on it
task.spawn(function()
    local ok, result = pcall(function()
        return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
    end)

    if ok and result then
        module = result
    else
        warn("[zoncn] Icons failed to load: " .. tostring(result))
    end

    loaded = true

    for _, callback in ipairs(queue) do
        callback()
    end
    table.clear(queue)
end)

-- runs callback once the icon pack has loaded (or failed to), straight away if it already has
function Icons.onReady(callback)
    if loaded then
        callback()
    else
        table.insert(queue, callback)
    end
end

-- path: "rbxassetid://123", a full url, "123", "lucide/check" or "check"
-- returns the image string, or "" while the icon pack is still loading
function Icons.resolve(path)
    if type(path) ~= "string" or #path == 0 then
        return ""
    end

    if path:match("^rbx") or path:match("^https?://") then
        return path
    end

    if path:match("^%d+$") then
        return "rbxassetid://" .. path
    end

    return resolveIcon(path)
end

-- sets instance[property] now if it can, otherwise as soon as the pack is ready
function Icons.apply(instance, property, path)
    local image = Icons.resolve(path)

    if image ~= "" or loaded then
        instance[property] = image
        return
    end

    Icons.onReady(function()
        instance[property] = Icons.resolve(path)
    end)
end

return Icons
