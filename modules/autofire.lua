--[[
    MODULE: AutoFire v6 (BRUTE FORCE MOBILE)
    Mencari tombol paling besar di area kanan bawah layar dan melakukan tap.
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled        = false,
    FireDelay      = 0.15,
    CheckRadius    = 150,
    OnlyWhenAimbot = false,
    TeamCheck      = false,
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

local log = function() end
local renderConn = nil
local lastFire = 0
local fireCount = 0
local cachedFireBtn = nil
local lastScan = 0

-- ─── SCAN TOMBOL FIRE (BRUTE FORCE) ──────────────────────────
local function findFireButton()
    if cachedFireBtn and cachedFireBtn.Parent and cachedFireBtn.Visible then
        return cachedFireBtn
    end
    if tick() - lastScan < 2 then return cachedFireBtn end
    lastScan = tick()
    
    local vp = Camera.ViewportSize
    local bestBtn, maxArea = nil, 0
    
    -- Scan semua GUI Button
    for _, obj in ipairs(PG:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local pos = obj.AbsolutePosition
            local size = obj.AbsoluteSize
            
            -- Cari yang ada di kuadran kanan bawah (X > 50% layar, Y > 40% layar)
            -- Dan bukan menu seperti Shop/Inventory
            if pos.X > vp.X * 0.5 and pos.Y > vp.Y * 0.4 then
                local name = obj.Name:lower()
                -- Filter nama menu
                if not name:find("shop") and not name:find("inventory") and not name:find("setting") then
                    local area = size.X * size.Y
                    if area > maxArea and area < 20000 then -- Batasi ukuran agar tidak ambil frame raksasa
                        maxArea = area
                        bestBtn = obj
                    end
                end
            end
        end
    end
    
    if bestBtn then
        log("INFO", "AutoFire: Menemukan tombol ["..bestBtn.Name.."] di X:"..math.floor(bestBtn.AbsolutePosition.X).." Y:"..math.floor(bestBtn.AbsolutePosition.Y))
        cachedFireBtn = bestBtn
    end
    return bestBtn
end

-- ─── FIRE (TAP LAYAR) ────────────────────────────────────────
local function fire()
    local VIM = game:GetService("VirtualInputManager")
    if not VIM then return false end

    local btn = findFireButton()
    if btn then
        local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
        local ok = pcall(function()
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, 1, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, 1, game, 0)
        end)
        if ok then
            fireCount = fireCount + 1
            if fireCount == 1 then log("OK", "AutoFire berhasil tap tombol.") end
            return true
        end
    else
        -- Jika tidak ketemu tombol, tap pojok kanan bawah sebagai fallback
        local vp = Camera.ViewportSize
        local x, y = vp.X - 80, vp.Y - 80
        pcall(function()
            VIM:SendMouseButtonEvent(x, y, 0, true, 1, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(x, y, 0, false, 1, game, 0)
        end)
        return true
    end
    return false
end

-- ─── CEK TARGET ──────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LP then return false end
    if AutoFire.Config.TeamCheck and plr.Team and LP.Team and plr.Team == LP.Team then
        return false
    end
    return true
end

local function crosshairOnEnemy()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local r2 = AutoFire.Config.CheckRadius ^ 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local c = plr.Character
            local head = c and (c:FindFirstChild("Head") or c:FindFirstChild("UpperTorso"))
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local sp, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local dx, dy = sp.X - center.X, sp.Y - center.Y
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

    if crosshairOnEnemy() then
        if fire() then
            lastFire = tick()
        end
    end
end

-- ─── PUBLIC API ──────────────────────────────────────────────
function AutoFire:Init()
    log("INFO", "AutoFire v6 (Brute Force) Started.")
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function() pcall(loop) end)
    end
end

function AutoFire:SetLogger(fn) log = fn end
function AutoFire:SetAimbotLock(_) end
function AutoFire:SetShotDebug(_) end

function AutoFire:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function AutoFire:TestMethods()
    log("TEST", "Mencari tombol Fire di layar...")
    local btn = findFireButton()
    if btn then
        log("TEST", "Ditemukan: " .. btn:GetFullName())
    else
        log("TEST", "Tidak ada tombol ditemukan di area kanan bawah.")
    end
end

function AutoFire:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return AutoFire
