--[[
    MODULE: SilentAim v5 (ReplicateFakeBullet)
    Hook remote ReplicateFakeBullet yang sudah terbukti tertangkap.
    Argumen: (CFrame, Vector3 Direction, Number)
]]

local SilentAim = {}
SilentAim.Config = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 500,
    SafetyAngle = 180,
}

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local log = function() end
local hooked, oldNamecall = false, nil
local stats = { intercepted=0, redirected=0, failed=0 }

-- ─── TARGET ──────────────────────────────────────────────────
local function isEnemy(plr)
    if plr == LocalPlayer then return false end
    if SilentAim.Config.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        return false
    end
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
                    local ray = Ray.new(camPos, (head.Position - camPos).Unit * d)
                    local filter = {LocalPlayer.Character, Camera, workspace:FindFirstChild("Camera")}
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

-- ─── MODIFY ARGS (KHUSUS REPLICATEFAKEBULLET) ────────────────
local function modifyArgs(args)
    stats.intercepted = stats.intercepted + 1
    if not SilentAim.Config.Enabled then return args end

    local target = getBestTarget()
    if not target then
        stats.failed = stats.failed + 1
        return args
    end

    local head = target.Character and target.Character:FindFirstChild("Head")
    if not head then return args end

    local camPos = Camera.CFrame.Position
    local aimDir = (head.Position - camPos).Unit
    
    -- Struktur payload ReplicateFakeBullet berdasarkan dump:
    -- args[1] = CFrame (Posisi tembak)
    -- args[2] = Vector3 (Arah)
    -- args[3] = Number (Waktu/Jarak)
    
    if typeof(args[2]) == "Vector3" then
        args[2] = aimDir
        stats.redirected = stats.redirected + 1
        log("SA", string.format("✓ ReplicateFakeBullet diarahkan ke %s", target.Name))
    else
        stats.failed = stats.failed + 1
        log("SA", "✗ Format argumen Vector3 tidak ditemukan di indeks 2")
    end

    return args
end

-- ─── HOOK ────────────────────────────────────────────────────
local function installHook()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" then
        log("ERR", "SilentAim: hookmetamethod tidak support")
        return false
    end

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance" then
                local n = self.Name
                -- Kita fokus ke ReplicateFakeBullet karena Shoot tidak terpanggil saat menembak
                if n == "ReplicateFakeBullet" then
                    local args = {...}
                    local ok2, res = pcall(modifyArgs, args)
                    if ok2 and res then args = res
                    elseif not ok2 then log("ERR", "SA modify: "..tostring(res)) end
                    return oldNamecall(self, table.unpack(args))
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not ok then
        log("ERR", "SilentAim hook: "..tostring(err))
        return false
    end

    hooked = true
    log("OK", "SilentAim hook aktif pada ReplicateFakeBullet")
    return true
end

-- ─── PUBLIC API ─────────────────────────────────────────────
function SilentAim:Init()
    if installHook() then
        log("INFO", "SilentAim READY (Mode: ReplicateFakeBullet)")
    end
end

function SilentAim:SetLogger(fn) log = fn end
function SilentAim:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function SilentAim:GetStats()
    return stats
end

function SilentAim:ResetStats()
    stats = { intercepted=0, redirected=0, failed=0 }
end

function SilentAim:Destroy()
    if hooked and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hooked = false
    end
end

return SilentAim
