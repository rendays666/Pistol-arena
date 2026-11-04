--[[
    MODULE: Aimbot
    API:
      Aimbot:Init()             -- panggil sekali saat startup
      Aimbot:SetConfig(cfg)     -- update config kapan saja
      Aimbot:Destroy()          -- cleanup (disconnect loop, remove drawings)
]]

local Aimbot = {}

Aimbot.Config = {
    Enabled     = false,
    FOVEnabled  = true,
    FOVRadius   = 150,
    Smoothness  = 0.20,
    Strength    = "Smooth",   -- Smooth | Medium | Strong
    Priority    = "Nearest",  -- Nearest | Lowest HP
    AimPart     = "Head",     -- Head | Body
    MaxDistance = 250,
}

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

local fovCircle = nil
local renderConn = nil

-- ─── HELPERS ───────────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function getTargetPart(plr)
    local c = plr.Character
    if not c then return nil end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    if Aimbot.Config.AimPart == "Head" then
        return c:FindFirstChild("Head")
    end
    return c:FindFirstChild("HumanoidRootPart")
        or c:FindFirstChild("UpperTorso")
        or c:FindFirstChild("Torso")
end

local function getBestAimEnemy()
    local best, bestDist, bestHP = nil, math.huge, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local part = getTargetPart(plr)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                local dist = (Camera.CFrame.Position - part.Position).Magnitude
                if onScreen and dist <= Aimbot.Config.MaxDistance then
                    local allowed = true
                    if Aimbot.Config.FOVEnabled and fovCircle then
                        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        allowed = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                                  <= Aimbot.Config.FOVRadius
                    end
                    if allowed then
                        local ray = Ray.new(Camera.CFrame.Position,
                            (part.Position - Camera.CFrame.Position).Unit * dist)
                        local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character, false, true)
                        if hit and hit:IsDescendantOf(plr.Character) then
                            if Aimbot.Config.Priority == "Nearest" then
                                if dist < bestDist then
                                    bestDist = dist; best = plr
                                end
                            else
                                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                                local hp = hum and hum.Health or math.huge
                                if hp < bestHP or (hp == bestHP and dist < bestDist) then
                                    bestHP = hp; bestDist = dist; best = plr
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function applyAimAt(targetPos)
    local cur = Camera.CFrame
    local tgt = CFrame.new(cur.Position, targetPos)
    if Aimbot.Config.Strength == "Strong" then
        Camera.CFrame = tgt
    elseif Aimbot.Config.Strength == "Medium" then
        Camera.CFrame = cur:Lerp(tgt, 0.5)
    else
        Camera.CFrame = cur:Lerp(tgt, Aimbot.Config.Smoothness)
    end
end

-- ─── PUBLIC API ────────────────────────────────────────────────
function Aimbot:Init()
    -- FOV Circle
    if not fovCircle then
        pcall(function()
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible      = false
            fovCircle.Radius       = self.Config.FOVRadius
            fovCircle.Color        = Color3.fromRGB(255, 255, 255)
            fovCircle.Thickness    = 1
            fovCircle.Transparency = 1
            fovCircle.Filled       = false
        end)
    end

    -- Render loop
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function()
            if fovCircle then
                pcall(function()
                    fovCircle.Position = Vector2.new(
                        Camera.ViewportSize.X / 2,
                        Camera.ViewportSize.Y / 2
                    )
                    fovCircle.Radius  = self.Config.FOVRadius
                    fovCircle.Visible = self.Config.Enabled and self.Config.FOVEnabled
                end)
            end

            if self.Config.Enabled then
                local target = getBestAimEnemy()
                if target then
                    local part = getTargetPart(target)
                    if part then applyAimAt(part.Position) end
                end
            end
        end)
    end
end

function Aimbot:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then
            self.Config[k] = v
        end
    end
end

function Aimbot:Destroy()
    if renderConn then
        renderConn:Disconnect()
        renderConn = nil
    end
    if fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end
end

return Aimbot
