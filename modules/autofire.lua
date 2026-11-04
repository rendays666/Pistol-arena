--[[
    MODULE: AutoFire v4 (MOBILE FOCUSED)
    Prioritas: Tombol Fire di layar → VIM Center → mouse1click
    Hook ke GUI button HP langsung, jadi pasti tembak.
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled        = false,
    FireDelay      = 0.15,
    CheckRadius    = 120, -- Diperbesar biar gampang kena target
    OnlyWhenAimbot = false,
    TeamCheck      = false,
    Method         = "auto",
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LP          = Players.LocalPlayer

local log = function() end
local renderConn = nil
local lastFire = 0
local activeMethod = "NONE"
local aimbotLockFn = nil
local fireCount = 0
local cachedFireBtn = nil
local lastBtnScan = 0

-- ─── DETEKSI TOMBOL FIRE ─────────────────────────────────────
local function findFireButton()
    if cachedFireBtn and cachedFireBtn.Parent then return cachedFireBtn end
    if tick() - lastBtnScan < 3 then return cachedFireBtn end
    lastBtnScan = tick()

    local PG = LP:FindFirstChild("PlayerGui")
    if not PG then return nil end

    -- 1. Cari di GUI yang diketahui
    local guis = {"WeaponGui", "WeaponTouchGui", "TouchGui", "HotbarGui"}
    for _, gName in ipairs(guis) do
        local g = PG:FindFirstChild(gName)
        if g then
            for _, v in ipairs(g:GetDescendants()) do
                if v:IsA("ImageButton") or v:IsA("TextButton") then
                    local n = v.Name:lower()
                    if n:find("fire") or n:find("shoot") or n:find("attack") or n:find("trigger") then
                        cachedFireBtn = v
                        return v
                    end
                end
            end
        end
    end

    -- 2. Cari di semua GUI (Recursive)
    for _, v in ipairs(PG:GetDescendants()) do
        if v:IsA("ImageButton") or v:IsA("TextButton") then
            local n = v.Name:lower()
            if n:find("fire") or n:find("shoot") or n:find("primary") then
                cachedFireBtn = v
                return v
            end
        end
    end

    return nil
end

-- ─── FIRE METHODS ────────────────────────────────────────────
local function fireMobileButton()
    local btn = findFireButton()
    if not btn then return false end
    
    local VIM = game:GetService("VirtualInputManager")
    if VIM and btn.AbsoluteSize.Magnitude > 0 then
        local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
        pcall(function()
            -- Simulasi tap layar (Touch) via Mouse Event
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, 1, game, 0)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, 1, game, 0)
        end)
        return true
    end
    
    -- Fallback kalau VIM gagal
    pcall(function() btn:Activate() end)
    return true
end

local function fireVIMCenter()
    local VIM = game:GetService("VirtualInputManager")
    if not VIM then return false end
    local vp = Camera.ViewportSize
    local x, y = vp.X / 2, vp.Y / 2
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, 1, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(x, y, 0, false, 1, game, 0)
    end)
    return true
end

local function fireMouse1Click()
    if type(mouse1click) ~= "function" then return false end
    pcall(mouse1click)
    return true
end

local function fire()
    local m = AutoFire.Config.Method
    local success = false

    if m == "auto" then
        -- Prioritas tombol layar untuk HP
        success = fireMobileButton()
        if not success then success = fireVIMCenter() end
        if not success then success = fireMouse1Click() end
    elseif m == "button" then
        success = fireMobileButton()
    elseif m == "vim" then
        success = fireVIMCenter()
    elseif m == "mouse1" then
        success = fireMouse1Click()
    end

    if success then
        fireCount = fireCount + 1
    else
        log("ERR", "AutoFire: gagal nembak (tombol tidak ketemu / VIM error)")
    end
end

-- ─── CEK CROSSHAIR ───────────────────────────────────────────
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
            local head = c and c:FindFirstChild("Head")
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

    local shouldFire
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
    local btn = findFireButton()
    if btn then
        activeMethod = "button"
        log("OK", "AutoFire: Tombol Fire ditemukan ("..btn.Name..")")
    else
        activeMethod = "vim"
        log("WARN", "AutoFire: Tombol Fire tidak ketemu, pakai VIM Center")
    end

    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function() pcall(loop) end)
    end
end

function AutoFire:SetLogger(fn) log = fn end
function AutoFire:SetAimbotLock(fn) aimbotLockFn = fn end
function AutoFire:SetShotDebug(_) end -- Tidak dipakai lagi

function AutoFire:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function AutoFire:TestMethods()
    log("TEST", "=== AutoFire Methods ===")
    local btn = findFireButton()
    log("TEST", "Button: " .. (btn and btn:GetFullName() or "NOT FOUND"))
    log("TEST", "VIM Center: OK")
    log("TEST", "mouse1click: " .. (type(mouse1click) == "function" and "OK" or "MISSING"))
    log("TEST", "active: " .. activeMethod .. " fires=" .. fireCount)
end

function AutoFire:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return AutoFire
