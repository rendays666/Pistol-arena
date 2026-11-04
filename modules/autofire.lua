--[[
    MODULE: AutoFire v2
    Fallback chain: VIM → mouse1click → mouse1press → ReplayCached → FireButton
    Jika tidak ada satupun yang kerja, pakai silent tap + replay manual.
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled        = false,
    FireDelay      = 0.08,
    CheckRadius    = 45,
    OnlyWhenAimbot = false,
    TeamCheck      = false,
    Method         = "auto",  -- "auto" | "vim" | "mouse1" | "replay" | "button"
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local LP          = Players.LocalPlayer

local log = function() end
local ShotDebugRef = nil
local renderConn = nil
local lastFire = 0
local activeMethod = "NONE"
local aimbotLockFn = nil

-- ─── DETEKSI ─────────────────────────────────────────────────
local function detectVIM()
    local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
    if not ok or not VIM then return false end
    return pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, false, 0, game, 0)
    end)
end

local function detectFireButton()
    if not ShotDebugRef then return nil end
    -- fallback: cari manual
    local PG = LP:FindFirstChild("PlayerGui")
    if not PG then return nil end
    for _, gname in ipairs({"WeaponGui", "WeaponTouchGui"}) do
        local g = PG:FindFirstChild(gname)
        if g then
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    local n = d.Name:lower()
                    if n:find("fire") or n:find("shoot") or n:find("trigger") then
                        return d
                    end
                end
            end
        end
    end
    return nil
end

local function detectMethods()
    local list = {}
    if detectVIM() then table.insert(list, "VIM") end
    if type(mouse1click) == "function" then table.insert(list, "mouse1click") end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        table.insert(list, "mouse1press")
    end
    if ShotDebugRef and ShotDebugRef:GetLastShoot() then table.insert(list, "replay") end
    if detectFireButton() then table.insert(list, "button") end
    return list
end

-- ─── FIRE METHODS ────────────────────────────────────────────
local function fireVIM()
    local VIM = game:GetService("VirtualInputManager")
    local vp = Camera.ViewportSize
    local x, y = vp.X / 2, vp.Y / 2
    VIM:SendMouseButtonEvent(x, y, 0, true, 1, game, 0)
    task.wait(0.01)
    VIM:SendMouseButtonEvent(x, y, 0, false, 1, game, 0)
    return true
end

local function fireMouse1Click()
    mouse1click()
    return true
end

local function fireMouse1Press()
    mouse1press()
    task.wait(0.01)
    mouse1release()
    return true
end

local function fireReplay()
    if not ShotDebugRef then return false end
    local s = ShotDebugRef:GetLastShoot()
    if not s then return false end
    -- Replay payload dengan origin/direction dimodifikasi ke arah crosshair sekarang
    local newArgs = {}
    for i, v in ipairs(s.args) do newArgs[i] = v end

    -- Coba modifikasi Vector3 kedua ke direction kamera (heuristik)
    local camDir = Camera.CFrame.LookVector
    local camPos = Camera.CFrame.Position

    -- Jika arg1 Vector3 & arg2 Vector3 → kemungkinan (origin, direction)
    if typeof(newArgs[1]) == "Vector3" and typeof(newArgs[2]) == "Vector3" then
        newArgs[1] = camPos
        newArgs[2] = camDir
    elseif type(newArgs[1]) == "table" then
        local t = newArgs[1]
        for k, v in pairs(t) do
            if typeof(v) == "Vector3" then
                if v.Magnitude > 5 then
                    t[k] = camPos
                else
                    t[k] = camDir
                end
            end
        end
    end

    return ShotDebugRef:ReplayShootModified(newArgs)
end

local function fireButton()
    local btn = detectFireButton()
    if not btn then return false end
    -- Simulasi tap
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, 1, game, 0)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, 1, game, 0)
        return true
    end
    return false
end

local function fire()
    local m = AutoFire.Config.Method
    local ok, err = false, nil

    if m == "vim" or (m == "auto" and activeMethod == "VIM") then
        ok, err = pcall(fireVIM)
    elseif m == "mouse1" or (m == "auto" and activeMethod == "mouse1click") then
        ok, err = pcall(fireMouse1Click)
    elseif m == "replay" or (m == "auto" and activeMethod == "replay") then
        ok, err = pcall(fireReplay)
    elseif m == "button" or (m == "auto" and activeMethod == "button") then
        ok, err = pcall(fireButton)
    elseif m == "auto" then
        -- coba semua sampai ada yang berhasil
        for _, method in ipairs({"VIM","mouse1click","mouse1press","replay","button"}) do
            local fn = ({VIM=fireVIM, mouse1click=fireMouse1Click,
                        mouse1press=fireMouse1Press, replay=fireReplay,
                        button=fireButton})[method]
            if fn then
                local o, e = pcall(fn)
                if o then activeMethod = method; ok = true; break end
            end
        end
        if not ok then err = "all methods failed" end
    else
        err = "unknown method: " .. m
    end

    if not ok then
        log("ERR", "AutoFire fire: " .. tostring(err))
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
    local methods = detectMethods()
    if #methods == 0 then
        activeMethod = "NONE"
        log("ERR", "AutoFire: TIDAK ADA metode. Silent tap + replay manual.")
    else
        activeMethod = methods[1]
        log("OK", "AutoFire methods: " .. table.concat(methods, ", ")
            .. " (default: " .. activeMethod .. ")")
    end
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(function() pcall(loop) end)
    end
end

function AutoFire:SetLogger(fn) log = fn end
function AutoFire:SetShotDebug(ref) ShotDebugRef = ref end
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
    log("TEST", "replay: " .. (ShotDebugRef and ShotDebugRef:GetLastShoot() and "OK" or "NO PAYLOAD"))
    log("TEST", "button: " .. (detectFireButton() and "OK" or "MISSING"))
    log("TEST", "active: " .. activeMethod)
end

function AutoFire:GetActiveMethod() return activeMethod end

function AutoFire:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return AutoFire
