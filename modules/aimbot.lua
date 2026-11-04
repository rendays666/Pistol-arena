--[[
    MODULE: Aimbot
    FOVMode:
      "FOV Circle"       -> hanya target di dalam circle
      "Full Body (360°)" -> target di mana saja (termasuk di belakang kamera)
]]

local Aimbot = {}

Aimbot.Config = {
    Enabled     = false,
    TeamCheck   = true,
    FOVMode     = "FOV Circle",
    FOVRadius   = 150,
    MaxDistance = 250,
    Strength    = "Smooth",     -- Strong | Medium | Smooth
    Smoothness  = 0.20,
    Priority    = "Nearest",    -- Nearest | Lowest HP
    AimPart     = "Head",       -- Head | Body
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local fovCircle  = nil
local renderConn = nil

-- ─── HELPERS ───────────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if Aimbot.Config.TeamCheck then
        if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
            return false
        end
    end
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
    return c:FindFirstChild("UpperTorso")
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("HumanoidRootPart")
end

local function getBestAimEnemy()
    local best, bestDist, bestHP = nil, math.huge, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local isCircle = Aimbot.Config.FOVMode == "FOV Circle"
    local camPos = Camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local part = getTargetPart(plr)
            if part then
                local partPos = part.Position
                local delta   = partPos - camPos
                local dist    = delta.Magnitude

                if dist > 1 and dist <= Aimbot.Config.MaxDistance then
                    local allowed = true

                    if isCircle then
                        -- FOV Circle: harus di layar & dalam radius
                        local screenPos, onScreen = Camera:WorldToViewportPoint(partPos)
                        if not onScreen then
                            allowed = false
                        else
                            local screen2D = Vector2.new(screenPos.X, screenPos.Y)
                            allowed = (screen2D - center).Magnitude <= Aimbot.Config.FOVRadius
                        end
                    end
                    -- Full Body mode: allowed = true, tidak cek onScreen → 360°

                    if allowed then
                        -- Line of sight (tidak ada tembok)
                        local ray = Ray.new(camPos, delta.Unit * dist)
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
    if not fovCircle then
        pcall(function()
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible = false
            fovCircle.Radius = self.Config.FOVRadius
            fovCircle.Color = Color3.fromRGB(255, 255, 255)
            fovCircle.Thickness = 1
            fovCircle.Transparency = 1
            fovCircle.Filled = false
        end)
    end

    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function()
            if fovCircle then
                pcall(function()
                    fovCircle.Position = Vector2.new(
                        Camera.ViewportSize.X / 2,
                        Camera.ViewportSize.Y / 2
                    )
                    fovCircle.Radius = self.Config.FOVRadius
                    -- Circle hanya muncul di FOV Circle mode
                    fovCircle.Visible = self.Config.Enabled
                        and self.Config.FOVMode == "FOV Circle"
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
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function Aimbot:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    if fovCircle then pcall(function() fovCircle:Remove() end); fovCircle = nil end
end

return Aimbot
