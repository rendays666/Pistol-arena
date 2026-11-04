--[[
    MODULE: AutoFire v3
    Priority: replay (via ShotDebug payload) → vim → mouse1 → button
    Replay = paling reliable karena langsung pakai payload ReplicateFakeBullet yg confirmed ada.
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled        = false,
    FireDelay      = 0.12,
    CheckRadius    = 55,
    OnlyWhenAimbot = false,
    TeamCheck      = false,
    Method         = "auto",
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
local fireCount = 0

-- ─── DETEKSI ─────────────────────────────────────────────────
local function detectVIM()
    local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
    if not ok or not VIM then return false end
    return pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, false, 0, game, 0)
    end)
end

local function detectMethods()
    local list = {}
    if ShotDebugRef and ShotDebugRef:GetBestShootPayload() then
        table.insert(list, "replay")
    end
    if detectVIM() then table.insert(list, "VIM") end
    if type(mouse1click) == "function" then table.insert(list, "mouse1click") end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        table.insert(list, "mouse1press")
    end
    return list
end

-- ─── FIRE METHODS ────────────────────────────────────────────
local function fireReplay()
    if not ShotDebugRef then return false end
    local best = ShotDebugRef:GetBestShootPayload()
    if not best then return false end

    -- Ambil remote
    local RE = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    local REs = RE and RE:FindFirstChild("RemoteEvents")
    if not REs then return false end
    local remote = REs:FindFirstChild(best.name)
    if not remote then return false end

    -- Clone args
    local newArgs = {}
    for i, v in ipairs(best.args) do newArgs[i] = v end

    -- Update position/direction ke kamera sekarang
    local camPos = Camera.CFrame.Position
    local camDir = Camera.CFrame.LookVector

    for i, v in ipairs(newArgs) do
        if typeof(v) == "Vector3" then
            local m = v.Magnitude
            if m > 0.5 and m < 3 then
                newArgs[i] = camDir       -- direction
            elseif m > 5 then
                newArgs[i] = camPos       -- origin
            end
        elseif type(v) == "table" then
            for k, vv in pairs(v) do
                if typeof(vv) == "Vector3" then
                    local m = vv.Magnitude
                    if m > 0.5 and m < 3 then v[k] = camDir
                    elseif m > 5 then v[k] = camPos end
                end
            end
        end
    end

    local ok = pcall(function()
        remote:FireServer(table.unpack(newArgs))
    end)
    if ok then fireCount = fireCount + 1 end
    return ok
end

local function fireVIM()
    local VIM = game:GetService("VirtualInputManager")
    if not VIM then return false end
    local vp = Camera.ViewportSize
    local x, y = vp.X / 2, vp.Y / 2
    local ok1 = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, 1, game, 0) end)
    task.wait(0.015)
    local ok2 = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, 1, game, 0) end)
    if ok1 and ok2 then fireCount = fireCount + 1 end
    return ok1 and ok2
end

local function fireMouse1Click()
    if type(mouse1click) ~= "function" then return false end
    local ok = pcall(mouse1click)
    if ok then fireCount = fireCount + 1 end
    return ok
end

local function fireMouse1Press()
    if type(mouse1press) ~= "function" then return false end
    pcall(mouse1press)
    task.wait(0.015)
    pcall(mouse1release)
    fireCount = fireCount + 1
    return true
end

local function fire()
    local m = AutoFire.Config.Method
    local methodsToTry = {}

    if m == "auto" then
        methodsToTry = { "replay", "VIM", "mouse1click", "mouse1press" }
    elseif m == "replay" then
        methodsToTry = { "replay" }
    elseif m == "vim" then
        methodsToTry = { "VIM" }
    elseif m == "mouse1" then
        methodsToTry = { "mouse1click" }
    else
        methodsToTry = { "replay" }
    end

    local dispatch = {
        replay = fireReplay,
        VIM = fireVIM,
        mouse1click = fireMouse1Click,
        mouse1press = fireMouse1Press,
    }

    for _, method in ipairs(methodsToTry) do
        local fn = dispatch[method]
        if fn then
            local ok, err = pcall(fn)
            if ok then
                if activeMethod ~= method then
                    activeMethod = method
                    log("OK", "AutoFire active method = "..method)
                end
                return
            end
        end
    end
    log("ERR", "AutoFire: semua metode gagal")
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
        log("ERR", "AutoFire: TIDAK ADA metode. Tembak manual dulu 3x.")
    else
        log("OK", "AutoFire methods: "..table.concat(methods, ", "))
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
    log("TEST", "replay: "..(ShotDebugRef and ShotDebugRef:GetBestShootPayload() and "OK" or "NO PAYLOAD"))
    log("TEST", "VIM: "..(detectVIM() and "OK" or "FAIL"))
    log("TEST", "mouse1click: "..(type(mouse1click) == "function" and "OK" or "MISSING"))
    log("TEST", "mouse1press: "..(type(mouse1press) == "function" and "OK" or "MISSING"))
    log("TEST", "active: "..activeMethod.." fires="..fireCount)
end

function AutoFire:GetActiveMethod() return activeMethod end
function AutoFire:GetFireCount() return fireCount end

function AutoFire:Destroy()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
end

return AutoFire
