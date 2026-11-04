--[[
    MODULE: AutoFire
    Trigger tembakan otomatis saat crosshair berada di musuh.
    Supports: VIM (PC) / mouse1click (executor) / mouse1press+release
    API: Init / SetConfig / SetLogger / TestMethods / Destroy
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled     = false,
    FireDelay   = 0.08,   -- detik antar tembakan
    CheckRadius = 45,     -- px dari tengah layar
    OnlyWhenAimbot = false, -- jika true, hanya fire saat aimbot lock
    TeamCheck   = false,
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local log = function() end
local renderConn = nil
local lastFire   = 0
local fireMethod = "NONE"
local aimbotLockFn = nil  -- callback opsional dari aimbot

-- ─── DETEKSI METODE FIRE ─────────────────────────────────────
local function detectVIM()
    local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
    if not ok or not VIM then return false end
    local testOk = pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, false, 0, game, 0)
    end)
    return testOk
end

local function detectMethods()
    if detectVIM() then return "VIM" end
    if type(mouse1click) == "function" then return "mouse1click" end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        return "mouse1press"
    end
    return "NONE"
end

-- ─── FIRE ────────────────────────────────────────────────────
local function fire()
    if fireMethod == "VIM" then
        local ok, err = pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            local vp = Camera.ViewportSize
            VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, 1, game, 0)
            task.wait(0.015)
            VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, 1, game, 0)
        end)
        if not ok then log("ERR", "VIM fire: " .. tostring(err)) end
    elseif fireMethod == "mouse1click" then
        local ok, err = pcall(mouse1click)
        if not ok then log("ERR", "mouse1click: " .. tostring(err)) end
    elseif fireMethod == "mouse1press" then
        pcall(mouse1press)
        task.wait(0.015)
        pcall(mouse1release)
    else
        log("ERR", "AutoFire: no fire method")
    end
end

-- ─── CEK CROSSHAIR ───────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if AutoFire.Config.TeamCheck
       and plr.Team and LocalPlayer.Team
       and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function crosshairOnEnemy()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local r2 = AutoFire.Config.CheckRadius ^ 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local sp, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local dx = sp.X - center.X
                    local dy = sp.Y - center.Y
                    if dx*dx + dy*dy <= r2 then return true end
                end
            end
        end
    end
    return false
end

-- ─── LOOP ────────────────────────────────────────────────────
local function loop()
    if not AutoFire.Config.Enabled then return end
    if tick() - lastFire < AutoFire.Config.FireDelay then return end

    local shouldFire = false
    if AutoFire.Config.OnlyWhenAimbot then
        shouldFire = aimbotLockFn and aimbotLockFn() or false
    else
        shouldFire = crosshairOnEnemy()
    end

    if shouldFire then
        fire()
        lastFire = tick()
    end
end

-- ─── PUBLIC API ──────────────────────────────────────────────
function AutoFire:Init()
    fireMethod = detectMethods()
    if fireMethod == "NONE" then
        log("ERR", "AutoFire: TIDAK ADA metode fire yg support. Pakai Silent Aim + tap manual.")
    else
        log("OK", "AutoFire method = " .. fireMethod)
    end
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function()
            pcall(loop)
        end)
    end
end

function AutoFire:SetLogger(fn) log = fn end

function AutoFire:SetAimbotLock(fn) aimbotLockFn = fn end

function AutoFire:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function AutoFire:TestMethods()
    log("TEST", "=== AutoFire Methods ===")
    log("TEST", "VIM: " .. (detectVIM() and "OK" or "FAIL"))
    log("TEST", "mouse1click: " .. (type(mouse1click) == "function" and "OK" or "MISSING"))
    log("TEST", "mouse1press: " .. (type(mouse1press) == "function" and "OK" or "MISSING"))
    log("TEST", "Selected: " .. fireMethod)
end

function AutoFire:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return AutoFire
