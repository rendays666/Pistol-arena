--[[
    MODULE: SilentAim v2 — verbose logging
    Hook SEMUA FireServer yang namanya mengandung: shoot/fire/attack/hit/damage
    Log setiap intercept supaya kelihatan mechanisme aslinya.
]]

local SilentAim = {}
SilentAim.Config = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 500,
    SafetyAngle = 180,   -- default longgar biar kelihatan work atau nggak
    LogPayload  = true,
}

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local log = function() end
local hooked, oldNamecall = false, nil
local loggedShapes = {}
local rejectedCount, confirmedCount = 0, 0
local interceptCount, redirectOK, redirectFail = 0, 0, 0

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

-- ─── DEBUG SHAPE ────────────────────────────────────────────
local function describeArgs(args)
    local parts = {}
    for i = 1, #args do
        local v = args[i]
        local t = typeof(v)
        if t == "Vector3" then
            parts[#parts+1] = string.format("a%d=V3(%.1f,%.1f,%.1f | mag=%.2f)",
                i, v.X, v.Y, v.Z, v.Magnitude)
        elseif t == "CFrame" then
            parts[#parts+1] = "a"..i.."=CFrame"
        elseif t == "table" then
            local keys = {}
            for k, vv in pairs(v) do
                local tt = typeof(vv)
                if tt == "Vector3" then
                    keys[#keys+1] = tostring(k).."=V3(mag="..
                        string.format("%.2f", vv.Magnitude)..")"
                else
                    keys[#keys+1] = tostring(k).."="..tt
                end
            end
            parts[#parts+1] = "a"..i.."={ "..table.concat(keys, ", ").." }"
        elseif t == "Instance" then
            parts[#parts+1] = "a"..i.."=Inst("..(v.Name or "?")..")"
        else
            parts[#parts+1] = "a"..i.."="..t..":"..tostring(v):sub(1, 25)
        end
    end
    return table.concat(parts, "  ")
end

local function logShapeOnce(key, args)
    if loggedShapes[key] or not SilentAim.Config.LogPayload then return end
    loggedShapes[key] = true
    log("SA", "SHAPE["..key.."] = "..describeArgs(args))
end

-- ─── REDIRECT ───────────────────────────────────────────────
local function redirectTable(tbl, camPos, aimDir)
    -- Prioritas: nama field umum
    local known = {"Direction","direction","Dir","dir","LookDirection",
                   "AimDir","Vector","Target","target","To","to"}
    for _, k in ipairs(known) do
        if typeof(tbl[k]) == "Vector3" then
            local m = tbl[k].Magnitude
            if m > 0.5 and m < 3 then
                tbl[k] = aimDir
                return tostring(k)
            end
        end
    end
    -- Fallback: cari Vector3 magnitude ~1
    for k, v in pairs(tbl) do
        if typeof(v) == "Vector3" and v.Magnitude > 0.5 and v.Magnitude < 3 then
            tbl[k] = aimDir
            return tostring(k).." (auto)"
        end
    end
    return nil
end

local function modifyArgs(args)
    interceptCount = interceptCount + 1
    logShapeOnce("n"..#args, args)

    -- Kalau disabled, tetap log sekali biar keliatan hook jalan
    if not SilentAim.Config.Enabled then
        if interceptCount <= 3 then
            log("SA", "intercept (disabled) "..describeArgs(args))
        end
        return args
    end

    local target, dist = getBestTarget()
    if not target then
        redirectFail = redirectFail + 1
        log("SA", "no target — pass through")
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
        redirectFail = redirectFail + 1
        log("SA", string.format("SKIP angle %.0f° > %.0f°",
            angle, SilentAim.Config.SafetyAngle))
        return args
    end

    -- Table style
    if type(args[1]) == "table" then
        local field = redirectTable(args[1], camPos, aimDir)
        if field then
            redirectOK = redirectOK + 1
            log("SA", string.format("✓ table.%s | %s | %.0f° %.0fm",
                field, target.Name, angle, dist))
        else
            redirectFail = redirectFail + 1
            log("SA", "✗ table shape unknown")
        end
        return args
    end

    -- Varargs style: cari Vector3 magnitude ~1 (direction)
    local modified, whichArg = false, nil
    for i = 1, #args do
        if typeof(args[i]) == "Vector3" then
            local m = args[i].Magnitude
            if m > 0.5 and m < 3 then
                args[i] = aimDir
                modified = true
                whichArg = i
                break
            end
        end
    end

    if modified then
        redirectOK = redirectOK + 1
        log("SA", string.format("✓ arg%d=dir | %s | %.0f° %.0fm",
            whichArg, target.Name, angle, dist))
    else
        redirectFail = redirectFail + 1
        log("SA", "✗ no direction vector in varargs")
    end

    return args
end

-- ─── HOOK ───────────────────────────────────────────────────
local function installHook()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        log("ERR", "SilentAim: hookmetamethod NOT SUPPORTED di executor ini")
        return false
    end

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance" then
                local n = (self.Name or ""):lower()
                if n:find("shoot") or n:find("fire") or n:find("attack")
                   or n:find("hit") or n:find("damage") then
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
        log("ERR", "SilentAim hook install: "..tostring(err))
        return false
    end

    pcall(function()
        local Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        local RE = Events and Events:FindFirstChild("RemoteEvents")
        if RE then
            local rej = RE:FindFirstChild("HitRejected")
            if rej then
                rej.OnClientEvent:Connect(function()
                    rejectedCount = rejectedCount + 1
                    log("WARN", "HitRejected total="..rejectedCount)
                end)
            end
            local hit = RE:FindFirstChild("ConfirmHit")
            if hit then
                hit.OnClientEvent:Connect(function()
                    confirmedCount = confirmedCount + 1
                end)
            end
        end
    end)

    hooked = true
    log("OK", "SilentAim hook — pattern: shoot/fire/attack/hit/damage")
    return true
end

-- ─── PUBLIC API ─────────────────────────────────────────────
function SilentAim:Init()
    if installHook() then
        log("INFO", "SilentAim READY — tembak 1x, lihat log 'SHAPE[...]'")
    end
end

function SilentAim:SetLogger(fn) log = fn end

function SilentAim:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
end

function SilentAim:GetStats()
    return {
        intercepted = interceptCount,
        redirected  = redirectOK,
        failed      = redirectFail,
        rejected    = rejectedCount,
        confirmed   = confirmedCount,
    }
end

function SilentAim:ResetStats()
    interceptCount, redirectOK, redirectFail = 0, 0, 0
    rejectedCount, confirmedCount = 0, 0
    loggedShapes = {}
end

function SilentAim:Destroy()
    if hooked and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hooked = false
    end
end

return SilentAim
