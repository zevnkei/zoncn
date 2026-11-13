local RunService = game:GetService("RunService")

local Spring = {}
Spring.__index = Spring

function Spring.new(value, stiffness, damping)
    return setmetatable({
        Value = value,
        Target = value,
        Velocity = 0,
        Stiffness = stiffness or 260,
        Damping = damping or 20,
        OnChanged = nil,
        _conn = nil,
    }, Spring)
end

function Spring:SetTarget(target)
    self.Target = target
    if not self._conn then
        self._conn = RunService.Heartbeat:Connect(function(dt)
            self:_step(math.min(dt, 1 / 30))
        end)
    end
end

function Spring:_step(dt)
    local force = -self.Stiffness * (self.Value - self.Target) - self.Damping * self.Velocity
    self.Velocity += force * dt
    self.Value += self.Velocity * dt

    if self.OnChanged then self.OnChanged(self.Value) end

    if math.abs(self.Value - self.Target) < 0.001 and math.abs(self.Velocity) < 0.01 then
        self.Value = self.Target
        self.Velocity = 0
        if self.OnChanged then self.OnChanged(self.Value) end
        self._conn:Disconnect()
        self._conn = nil
    end
end

function Spring:Destroy()
    if self._conn then
        self._conn:Disconnect()
        self._conn = nil
    end
end

return Spring
