--[[
    MODULE: ESP
    API:
      ESP:Init()
      ESP:SetConfig(cfg)
      ESP:Destroy()
]]

local ESP = {}

ESP.Config = {
    Enabled      = false,
    ShowNames    = true,
    ShowHP       = true,
    ShowDistance = true,
    MaxDistance  = 250,
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local espObjects = {}
local renderConn = nil

-- ─── HELPERS ───────────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function clearAll()
    for _, obj in pairs(espObjects) do
        for _, d in pairs(obj) do pcall(function() d:Remove() end) end
    end
    espObjects = {}
end

local function createESP(plr)
    local okD, n, h, d = pcall(function()
        local a = Drawing.new("Text")
        a.Size = 16; a.Color = Color3.fromRGB(255, 255, 0); a.Center = true; a.Outline = true
        local b = Drawing.new("Text")
        b.Size = 14; b.Color = Color3.fromRGB(0, 255, 0);   b.Center = true; b.Outline = true
        local c = Drawing.new("Text")
        c.Size = 14; c.Color = Color3.fromRGB(0, 180, 255); c.Center = true; c.Outline = true
        return a, b, c
    end)
    if okD then
        espObjects[plr] = { name = n, hp = h, dist = d }
    end
end

local function updateLoop()
    if not ESP.Config.Enabled then
        clearAll()
        return
    end

    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                local dist = (Camera.CFrame.Position - head.Position).Magnitude
                if onScreen and dist <= ESP.Config.MaxDistance then
                    seen[plr] = true
                    if not espObjects[plr] then createESP(plr) end
                    local obj = espObjects[plr]
                    if obj then
                        if ESP.Config.ShowNames then
                            obj.name.Text     = plr.Name
                            obj.name.Position = Vector2.new(headPos.X, headPos.Y - 32)
                            obj.name.Visible  = true
                        else
                            obj.name.Visible = false
                        end

                        if ESP.Config.ShowHP then
                            obj.hp.Text     = "HP: " .. math.floor(hum.Health)
                            obj.hp.Position = Vector2.new(headPos.X, headPos.Y - 14)
                            obj.hp.Visible  = true
                        else
                            obj.hp.Visible = false
                        end

                        if ESP.Config.ShowDistance then
                            obj.dist.Text     = math.floor(dist) .. "m"
                            obj.dist.Position = Vector2.new(headPos.X, headPos.Y + 5)
                            obj.dist.Visible  = true
                        else
                            obj.dist.Visible = false
                        end
                    end
                end
            end
        end
    end

    for plr, obj in pairs(espObjects) do
        if not seen[plr] then
            for _, d in pairs(obj) do pcall(function() d:Remove() end) end
            espObjects[plr] = nil
        end
    end
end

-- Auto-cleanup kalau player leave
Players.PlayerRemoving:Connect(function(plr)
    if espObjects[plr] then
        for _, d in pairs(espObjects[plr]) do pcall(function() d:Remove() end) end
        espObjects[plr] = nil
    end
end)

-- ─── PUBLIC API ────────────────────────────────────────────────
function ESP:Init()
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function()
            pcall(updateLoop)
        end)
    end
end

function ESP:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then
            self.Config[k] = v
        end
    end
end

function ESP:Destroy()
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
    clearAll()
end

return ESP
