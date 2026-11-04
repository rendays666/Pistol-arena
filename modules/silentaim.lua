--[[
    MODULE: SilentAim v3
    Hook SEMUA remote shoot-like: Shoot, ReplicateFakeBullet, Fire, Attack, dst.
    Auto-detect: direction vector (mag 0.5-3) ATAU target position (mag > 5)
]]

local SilentAim = {}
SilentAim.Config = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 500,
    SafetyAngle = 180,
    LogPayload  = true,
}

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local log = function() end
local hooked, oldNamecall = false, nil
local loggedShapes = {}
local stats = { intercepted=0, redirected=0, failed=0, rejected=0, confirmed=0 }
local perRemote = {}  -- [name] = { intercepted, redirected, failed }

local function isShootLike(name)
    local n = name:lower()
    return n:find("shoot") or n:find("bullet") or n:find("fire")
        or n:find("attack") or n:find("hit") or n:find("damage")
end

local function stat(name)
    if not perRemote[name] then
        perRemote[name] = { intercepted=0, redirected=0, failed=0 }
    end
    return perRemote[name]
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
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local c = plr.Character
            local head = c and c:FindFirstChild("Head")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d = (head.Position - camPos).Magnitude
                if d < bestDist and d <= SilentAim.Config.MaxDistance then
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
    return best, bestDist
end

-- ─── DESCRIBE (untuk log) ──────────────────────────────────
local function describeArgs(args)
    local parts = {}
    for i = 1, math.min(#args, 5) do
        local v = args[i]
        local t = typeof(v)
        if t == "Vector3" then
            parts[#parts+1] = string.format("a%d=V3(m%.2f)", i, v.Magnitude)
        elseif t == "table" then
            parts[#parts+1] = "a"..i.."=tbl"
        else
            parts[#parts+1] = "a"..i.."="..t
        end
    end
    return table.concat(parts, " ")
end

local function logShapeOnce(name, args)
    if loggedShapes[name] or not SilentAim.Config.LogPayload then return end
    loggedShapes[name] = true
    log("SA", "SHAPE["..name.."] n="..#args.." | "..describeArgs(args))
end

-- ─── REDIRECT ────────────────────────────────────────────────
local function redirectArgs(args, headPos, aimDir, camPos)
    -- Strategi 1: Vector3 dengan magnitude 0.5-3 = direction
    for i = 1, #args do
        local v = args[i]
        if typeof(v) == "Vector3" then
            local m = v.Magnitude
            if m > 0.5 and m < 3 then
                args[i] = aimDir
                return "dir@arg"..i
            end
        end
    end

    -- Strategi 2: Vector3 dengan magnitude > 5 = target position
    for i = 1, #args do
        local v = args[i]
        if typeof(v) == "Vector3" then
            local m = v.Magnitude
            if m > 5 then
                args[i] = headPos
                return "pos@arg"..i
            end
        end
    end

    -- Strategi 3: table → cari direction/target dalam table
    for i = 1, #args do
        local v = args[i]
        if type(v) == "table" then
            for k, vv in pairs(v) do
                if typeof(vv) == "Vector3" then
                    local m = vv.Magnitude
                    if m > 0.5 and m < 3 then
                        v[k] = aimDir
                        return "tbl."..tostring(k).."=dir"
                    elseif m > 5 then
                        v[k] = headPos
                        return "tbl."..tostring(k).."=pos"
                    end
                end
            end
        end
    end

    return nil
end

-- ─── MODIFY ──────────────────────────────────────────────────
local function modifyArgs(remoteName, args)
    stats.intercepted = stats.intercepted + 1
    local rs = stat(remoteName)
    rs.intercepted = rs.intercepted + 1

    logShapeOnce(remoteName, args)

    if not SilentAim.Config.Enabled then
        if stats.intercepted <= 3 then
            log("SA", "intercept(off) ["..remoteName.."] "..describeArgs(args))
        end
        return args
    end

    local target, dist = getBestTarget()
    if not target then
        stats.failed = stats.failed + 1
        rs.failed = rs.failed + 1
        return args
    end

    local head = target.Character and target.Character:FindFirstChild("Head")
    if not head then return args end

    local camPos = Camera.CFrame.Position
    local aimDir = (head.Position - camPos).Unit
    local lookDir = Camera.CFrame.LookVector
    local dot = math.clamp(lookDir:Dot(aimDir), -1, 1)
    local angle = math.deg(math.acos(dot))

    if angle > SilentAim.Config.SafetyAngle then
        stats.failed = stats.failed + 1
        rs.failed = rs.failed + 1
        return args
    end

    local field = redirectArgs(args, head.Position, aimDir, camPos)
    if field then
        stats.redirected = stats.redirected + 1
        rs.redirected = rs.redirected + 1
        log("SA", string.format("✓ [%s] %s → %s (%.0f° %.0fm)",
            remoteName, field, target.Name, angle, dist))
    else
        stats.failed = stats.failed + 1
        rs.failed = rs.failed + 1
        log("SA", "✗ ["..remoteName.."] no redirect target in args")
    end
    return args
end

-- ─── HOOK ────────────────────────────────────────────────────
local function installHook()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        log("ERR", "SilentAim: hookmetamethod tidak support")
        return false
    end

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance" then
                local n = self.Name or ""
                if isShootLike(n) then
                    local args = {...}
                    local ok2, res = pcall(modifyArgs, n, args)
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

    pcall(function()
        local RE = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        local REs = RE and RE:FindFirstChild("RemoteEvents")
        if REs then
            local rej = REs:FindFirstChild("HitRejected")
            if rej then
                rej.OnClientEvent:Connect(function()
                    stats.rejected = stats.rejected + 1
                    log("WARN", "HitRejected total="..stats.rejected)
                end)
            end
            local hit = REs:FindFirstChild("ConfirmHit")
            if hit then
                hit.OnClientEvent:Connect(function()
                    stats.confirmed = stats.confirmed + 1
                end)
            end
        end
    end)

    hooked = true
    log("OK", "SilentAim v3 hooked — pattern: shoot|bullet|fire|attack|hit|damage")
    return true
end

-- ─── PUBLIC API ─────────────────────────────────────────────
function SilentAim:Init()
    if installHook() then log("INFO", "SilentAim READY") end
end

function SilentAim:SetLogger(fn) log = fn end

function SilentAim:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function SilentAim:GetStats()
    return {
        intercepted = stats.intercepted,
        redirected  = stats.redirected,
        failed      = stats.failed,
        rejected    = stats.rejected,
        confirmed   = stats.confirmed,
    }
end

function SilentAim:GetPerRemote()
    return perRemote
end

function SilentAim:ResetStats()
    stats = { intercepted=0, redirected=0, failed=0, rejected=0, confirmed=0 }
    perRemote = {}
    loggedShapes = {}
end

function SilentAim:Destroy()
    if hooked and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hooked = false
    end
end

return SilentAim
