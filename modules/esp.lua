--[[
    MODULE: ESP
    HP Bar: hijau (penuh) → kuning (50%) → merah (hampir habis)
]]

local ESP = {}

ESP.Config = {
    Enabled      = false,
    TeamCheck    = true,
    ShowNames    = true,
    ShowHPBar    = true,
    ShowDistance = true,
    MaxDistance  = 250,
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local BAR_W = 60
local BAR_H = 5

local espObjects = {}
local renderConn = nil

-- ─── HELPERS ───────────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if ESP.Config.TeamCheck then
        if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

-- Hijau → Kuning → Merah
local function hpColor(ratio)
    ratio = math.clamp(ratio, 0, 1)
    if ratio > 0.5 then
        local t = (ratio - 0.5) * 2          -- 0..1 (kuning → hijau)
        return Color3.new(1 - t, 1, 0)
    else
        local t = ratio * 2                   -- 0..1 (merah → kuning)
        return Color3.new(1, t, 0)
    end
end

local function clearAll()
    for _, obj in pairs(espObjects) do
        for _, d in pairs(obj) do pcall(function() d:Remove() end) end
    end
    espObjects = {}
end

local function createESP(plr)
    local ok, name, hpBg, hpFill, dist = pcall(function()
        local a = Drawing.new("Text")
        a.Size = 16; a.Color = Color3.fromRGB(255, 255, 0)
        a.Center = true; a.Outline = true; a.Visible = false

        local bg = Drawing.new("Square")
        bg.Size = Vector2.new(BAR_W, BAR_H)
        bg.Color = Color3.fromRGB(20, 20, 20)
        bg.Filled = true; bg.Thickness = 1
        bg.Transparency = 0.7; bg.Visible = false

        local fill = Drawing.new("Square")
        fill.Size = Vector2.new(BAR_W, BAR_H)
        fill.Color = Color3.fromRGB(0, 255, 0)
        fill.Filled = true; fill.Thickness = 1
        fill.Transparency = 1; fill.Visible = false

        local c = Drawing.new("Text")
        c.Size = 14; c.Color = Color3.fromRGB(0, 180, 255)
        c.Center = true; c.Outline = true; c.Visible = false

        return a, bg, fill, c
    end)
    if ok then
        espObjects[plr] = { name = name, hpBg = hpBg, hpFill = hpFill, dist = dist }
    end
end

local function updateLoop()
    if not ESP.Config.Enabled then
        if next(espObjects) then clearAll() end
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
                        -- Name
                        if ESP.Config.ShowNames then
                            obj.name.Text = plr.Name
                            obj.name.Position = Vector2.new(headPos.X, headPos.Y - 32)
                            obj.name.Visible = true
                        else
                            obj.name.Visible = false
                        end

                        -- HP Bar
                        if ESP.Config.ShowHPBar then
                            local hp    = hum.Health
                            local maxHP = math.max(hum.MaxHealth, 1)
                            local ratio = math.clamp(hp / maxHP, 0, 1)
                            local barX  = headPos.X - BAR_W / 2
                            local barY  = headPos.Y - 13

                            obj.hpBg.Position = Vector2.new(barX, barY)
                            obj.hpBg.Size     = Vector2.new(BAR_W, BAR_H)
                            obj.hpBg.Visible  = true

                            obj.hpFill.Position = Vector2.new(barX, barY)
                            obj.hpFill.Size     = Vector2.new(BAR_W * ratio, BAR_H)
                            obj.hpFill.Color    = hpColor(ratio)
                            obj.hpFill.Visible  = true
                        else
                            obj.hpBg.Visible   = false
                            obj.hpFill.Visible = false
                        end

                        -- Distance
                        if ESP.Config.ShowDistance then
                            obj.dist.Text = math.floor(dist) .. "m"
                            obj.dist.Position = Vector2.new(headPos.X, headPos.Y + 3)
                            obj.dist.Visible = true
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
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function ESP:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    clearAll()
end

return ESP
