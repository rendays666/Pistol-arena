--[[
    MODULE: SilentAim
    Hook __namecall pada RemoteEvent bernama "Shoot".
    Redirect arah peluru ke kepala musuh terdekat TANPA memutar kamera.
    
    Handling:
      - payload table (dict atau array)
      - payload varargs (Vector3 origin, Vector3 direction, ...)
      - safety angle check (hindari kick dari sanity check server)
    
    API: Init / SetConfig / SetLogger / Destroy
]]

local SilentAim = {}
SilentAim.Config = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 500,
    SafetyAngle = 90,       -- derajat; redirect hanya jika sudut < ini (0 = hanya maju, 180 = bebas)
    LogPayload  = true,     -- log struktur payload first time
}

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local log = function() end
local hooked = false
local oldNamecall
local loggedPayload = false
local rejectedCount = 0
local hitsSinceAttach = 0

-- ─── TARGET SELECTION ────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if SilentAim.Config.TeamCheck
       and plr.Team and LocalPlayer.Team
       and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function getBestTarget()
    local best, bestDist = nil, math.huge
    local camPos = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local c = plr.Character
            local head = c and c:FindFirstChild("Head")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d = (head.Position - camPos).Magnitude
                if d < bestDist and d <= SilentAim.Config.MaxDistance then
                    -- cek LOS
                    local ray = Ray.new(camPos, (head.Position - camPos).Unit * d)
                    local filter = {LocalPlayer.Character, Camera,
                        workspace:FindFirstChild("Camera"),
                        workspace:FindFirstChild("Effects")}
                    local hit = workspace:FindPartOnRayWithIgnoreList(ray, filter, false, true)
                    if not hit or hit:IsDescendantOf(c) then
                        bestDist = d; best = plr
                    end
                end
            end
        end
    end
    return best
end

-- ─── PAYLOAD MODIFY ──────────────────────────────────────────
local function redirectTable(tbl, camPos, aimDir)
    -- coba field umum
    local keys = {"Direction","direction","Dir","dir","LookDirection","AimDir","Vector"}
    for _, k in ipairs(keys) do
        if typeof(tbl[k]) == "Vector3" then
            tbl[k] = aimDir
            return k
        end
    end
    -- array style: posisi 2 sering direction
    if typeof(tbl[1]) == "Vector3" and typeof(tbl[2]) == "Vector3" then
        tbl[2] = aimDir
        return "[2]"
    end
    return nil
end

local function logPayloadShape(tbl)
    if loggedPayload or not SilentAim.Config.LogPayload then return end
    loggedPayload = true
    local parts = {}
    for k, v in pairs(tbl) do
        table.insert(parts, string.format("%s=%s", tostring(k), typeof(v)))
    end
    log("INFO", "SilentAim payload (table): {" .. table.concat(parts, ", ") .. "}")
end

local function modifyArgs(args)
    if not SilentAim.Config.Enabled then return args end
    local target = getBestTarget()
    if not target then return args end

    local head = target.Character and target.Character:FindFirstChild("Head")
    if not head then return args end

    local camPos = Camera.CFrame.Position
    local aimDir = (head.Position - camPos).Unit

    -- Safety angle
    local lookDir = Camera.CFrame.LookVector
    local dot = math.clamp(lookDir:Dot(aimDir), -1, 1)
    local angle = math.deg(math.acos(dot))
    if angle > SilentAim.Config.SafetyAngle then
        log("WARN", string.format("SilentAim: angle %.0f° > %.0f° — skip",
            angle, SilentAim.Config.SafetyAngle))
        return args
    end

    -- Table style
    if type(args[1]) == "table" then
        logPayloadShape(args[1])
        local k = redirectTable(args[1], camPos, aimDir)
        if k then
            log("SILENT", string.format("redirect via field %s (angle %.0f°)", tostring(k), angle))
        else
            log("WARN", "SilentAim: table payload unknown, tidak bisa redirect")
        end
        return args
    end

    -- Varargs style: Vector3 Vector3 → asumsi #2 direction
    if #args >= 2 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
        args[2] = aimDir
        log("SILENT", string.format("redirect arg[2] (angle %.0f°)", angle))
        return args
    end

    -- Unknown
    if not loggedPayload then
        loggedPayload = true
        local parts = {}
        for i = 1, #args do
            table.insert(parts, "arg"..i.."="..typeof(args[i]))
        end
        log("WARN", "SilentAim: payload varargs unknown: " .. table.concat(parts, ", "))
    end
    return args
end

-- ─── HOOK ────────────────────────────────────────────────────
local function installHook()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        log("ERR", "SilentAim: hookmetamethod tidak support di executor ini")
        return false
    end

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance"
               and self.Name == "Shoot" then
                local args = {...}
                local ok2, res = pcall(modifyArgs, args)
                if ok2 and res then args = res
                elseif not ok2 then log("ERR", "SilentAim modify: " .. tostring(res)) end
                return oldNamecall(self, table.unpack(args))
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not ok then
        log("ERR", "SilentAim hook install: " .. tostring(err))
        return false
    end

    -- Hook HitRejected untuk hitungan kegagalan (jika remote ada)
    pcall(function()
        local RE = game.ReplicatedStorage:FindFirstChild("Events")
            and game.ReplicatedStorage.Events:FindFirstChild("RemoteEvents")
        if RE then
            local rej = RE:FindFirstChild("HitRejected")
            if rej then
                rej.OnClientEvent:Connect(function()
                    rejectedCount = rejectedCount + 1
                    log("WARN", "SilentAim: HitRejected count=" .. rejectedCount)
                    if rejectedCount >= 5 and SilentAim.Config.Enabled then
                        SilentAim.Config.Enabled = false
                        log("ERR", "SilentAim auto-OFF setelah 5x reject — server mungkin validate direction")
                    end
                end)
            end
            local hit = RE:FindFirstChild("ConfirmHit")
            if hit then
                hit.OnClientEvent:Connect(function()
                    hitsSinceAttach = hitsSinceAttach + 1
                end)
            end
        end
    end)

    hooked = true
    return true
end

-- ─── PUBLIC API ──────────────────────────────────────────────
function SilentAim:Init()
    local ok = installHook()
    if ok then log("OK", "SilentAim hook installed") end
end

function SilentAim:SetLogger(fn) log = fn end

function SilentAim:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function SilentAim:GetStats()
    return { rejected = rejectedCount, confirmed = hitsSinceAttach }
end

function SilentAim:ResetStats()
    rejectedCount = 0
    hitsSinceAttach = 0
end

function SilentAim:Destroy()
    if hooked and oldNamecall then
        pcall(function()
            hookmetamethod(game, "__namecall", oldNamecall)
        end)
        hooked = false
    end
end

return SilentAim
