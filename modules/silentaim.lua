--[[
    MODULE: SilentAim v2 — adaptive payload modifier
    - Cari remote "Shoot" via scan (bukan string match)
    - Deteksi Vector3 direction berdasarkan magnitude ~ 1 (adaptive)
    - Support nested table (Header/Body style)
    - Verbose logging ke console
    - Test button untuk verifikasi
]]

local SilentAim = {}
SilentAim.Config = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 500,
    SafetyAngle = 90,
    LogPayload  = true,
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
local interceptCount = 0
local modifyCount    = 0
local shootRemote    = nil  -- reference ke remote yang terdeteksi
local remoteCandidates = {}

-- ─── DETEKSI REMOTE ──────────────────────────────────────────
local function scanShootRemotes()
    remoteCandidates = {}
    local RS = game.ReplicatedStorage
    local containers = {
        RS:FindFirstChild("Events") and RS.Events:FindFirstChild("RemoteEvents"),
        RS:FindFirstChild("Remotes"),
        RS,
    }
    local seen = {}
    local function addRemote(inst)
        if seen[inst] then return end
        seen[inst] = true
        if inst:IsA("RemoteEvent") then
            local n = inst.Name:lower()
            if n:find("shoot") or n:find("fire") or n:find("attack")
               or n:find("bullet") or n:find("weapon") then
                table.insert(remoteCandidates, inst)
            end
        end
    end
    for _, c in ipairs(containers) do
        if c then
            for _, ch in ipairs(c:GetChildren()) do addRemote(ch) end
        end
    end
    if #remoteCandidates > 0 then
        log("SA", "detected shoot remotes: " ..
            table.concat((function()
                local names = {}
                for _, r in ipairs(remoteCandidates) do
                    table.insert(names, r.Name)
                end
                return names
            end)(), ", "))
    else
        log("SA", "WARN: no shoot remote found — hook by generic name")
    end
    -- Utamakan "Shoot"
    for _, r in ipairs(remoteCandidates) do
        if r.Name:lower() == "shoot" then shootRemote = r; break end
    end
    if not shootRemote and #remoteCandidates > 0 then
        shootRemote = remoteCandidates[1]
    end
end

local function isShootRemote(inst)
    if inst == shootRemote then return true end
    if typeof(inst) ~= "Instance" then return false end
    for _, r in ipairs(remoteCandidates) do
        if inst == r then return true end
    end
    local n = (inst.Name or ""):lower()
    return n == "shoot" or n == "fire" or n == "attack"
end

-- ─── TARGET ──────────────────────────────────────────────────
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
    local filter = {
        LocalPlayer.Character,
        Camera,
        workspace:FindFirstChild("Camera"),
        workspace:FindFirstChild("Effects"),
    }
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local c = plr.Character
            local head = c and c:FindFirstChild("Head")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d = (head.Position - camPos).Magnitude
                if d < bestDist and d <= SilentAim.Config.MaxDistance then
                    local ray = Ray.new(camPos, (head.Position - camPos).Unit * d)
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

-- ─── ADAPTIVE MODIFY ─────────────────────────────────────────
-- Cari semua field Vector3 dengan magnitude ~ 1 (unit vector) → direction
-- Rekursif untuk nested table (Header/Body style)
local function modifyDirections(tbl, aimDir, depth, changes)
    depth = depth or 0
    changes = changes or {}
    if depth > 3 then return changes end
    for k, v in pairs(tbl) do
        if typeof(v) == "Vector3" then
            -- Direction = unit vector (magnitude ~ 1)
            -- Toleransi lebar karena beberapa game pakai "ray direction" non-unit
            local mag = v.Magnitude
            if math.abs(mag - 1) < 0.15 then
                tbl[k] = aimDir
                table.insert(changes, tostring(k))
            end
            -- Kalau ada field Direction/Vector dengan magnitude > 1 (larger magnitude),
            -- kemungkinan "ray direction * distance". Scale aimDir ke magnitude itu.
            local nl = tostring(k):lower()
            if (nl:find("dir") or nl:find("look") or nl:find("vector"))
               and mag > 1 then
                tbl[k] = aimDir * mag
                table.insert(changes, tostring(k).."(scaled)")
            end
        elseif type(v) == "table" then
            local nested = modifyDirections(v, aimDir, depth + 1, {})
            for _, c in ipairs(nested) do
                table.insert(changes, tostring(k).."."..c)
            end
        end
    end
    return changes
end

local function logPayloadShape(tbl)
    if loggedPayload or not SilentAim.Config.LogPayload then return end
    loggedPayload = true
    local parts = {}
    for k, v in pairs(tbl) do
        local vs = typeof(v)
        if vs == "Vector3" then
            vs = string.format("V3(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z)
        end
        table.insert(parts, tostring(k).."="..vs)
    end
    log("SA", "payload shape: {" .. table.concat(parts, ", ") .. "}")
end

-- ─── MODIFY ARGS ─────────────────────────────────────────────
local function modifyArgs(args)
    if not SilentAim.Config.Enabled then return args end
    local target = getBestTarget()
    if not target then return args end

    local head = target.Character and target.Character:FindFirstChild("Head")
    if not head then return args end

    local camPos = Camera.CFrame.Position
    local aimDir = (head.Position - camPos).Unit
    local lookDir = Camera.CFrame.LookVector
    local dot = math.clamp(lookDir:Dot(aimDir), -1, 1)
    local angle = math.deg(math.acos(dot))

    if angle > SilentAim.Config.SafetyAngle then
        log("SA", string.format("SKIP %.0f°>%.0f°", angle, SilentAim.Config.SafetyAngle))
        return args
    end

    -- Table style (paling umum)
    if type(args[1]) == "table" then
        logPayloadShape(args[1])
        local changes = modifyDirections(args[1], aimDir, 0, {})
        if #changes > 0 then
            modifyCount = modifyCount + 1
            log("SA", string.format("OK modify [%s] angle=%.0f°",
                table.concat(changes, ","), angle))
        else
            log("SA", "WARN no unit Vector3 found in payload")
        end
        return args
    end

    -- Varargs style
    if #args >= 2 and typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
        args[2] = aimDir
        modifyCount = modifyCount + 1
        log("SA", string.format("OK varargs angle=%.0f°", angle))
        return args
    end

    if not loggedPayload then
        loggedPayload = true
        local parts = {}
        for i = 1, #args do
            table.insert(parts, "a"..i..":"..typeof(args[i]))
        end
        log("SA", "WARN unknown payload: " .. table.concat(parts, " "))
    end
    return args
end

-- ─── HOOK ────────────────────────────────────────────────────
local function installHook()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        log("ERR", "SilentAim: hookmetamethod missing")
        return false
    end

    scanShootRemotes()

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance"
               and isShootRemote(self) then
                interceptCount = interceptCount + 1
                local args = {...}
                local ok2, res = pcall(modifyArgs, args)
                if ok2 and res then args = res
                elseif not ok2 then log("ERR", "SA modify: " .. tostring(res)) end
                return oldNamecall(self, table.unpack(args))
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not ok then
        log("ERR", "SilentAim hook: " .. tostring(err))
        return false
    end

    -- Listen reject/hit events
    pcall(function()
        local events = game.ReplicatedStorage:FindFirstChild("Events")
        local RE = events and events:FindFirstChild("RemoteEvents")
        if RE then
            local rej = RE:FindFirstChild("HitRejected")
            if rej then
                rej.OnClientEvent:Connect(function()
                    rejectedCount = rejectedCount + 1
                    log("WARN", "HitRejected #" .. rejectedCount)
                    if rejectedCount >= 5 and SilentAim.Config.Enabled then
                        SilentAim.Config.Enabled = false
                        log("ERR", "SilentAim auto-OFF (5 rejects) — server validate direction")
                    end
                end)
            end
            local hit = RE:FindFirstChild("ConfirmHit")
            if hit then
                hit.OnClientEvent:Connect(function() hitsSinceAttach = hitsSinceAttach + 1 end)
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
    return {
        intercepts = interceptCount,
        modified = modifyCount,
        rejected = rejectedCount,
        confirmed = hitsSinceAttach,
        remote = shootRemote and shootRemote:GetFullName() or "none",
    }
end

function SilentAim:ResetStats()
    rejectedCount = 0
    hitsSinceAttach = 0
    interceptCount = 0
    modifyCount = 0
end

function SilentAim:GetShootRemote() return shootRemote end

function SilentAim:Destroy()
    if hooked and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hooked = false
    end
end

return SilentAim
