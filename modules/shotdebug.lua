--[[
    MODULE: ShotDebug
    - Hook __namecall: log SEMUA FireServer/InvokeServer
    - Live GUI: crosshair, enemy check, metode fire, counter remote, payload Shoot terakhir
    - Replay: fire ulang payload terakhir (untuk testing)
    - Decoder: tampilkan struktur table payload
]]

local ShotDebug = {}
ShotDebug.Config = {
    Enabled = true,
}

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local UIS         = game:GetService("UserInputService")
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

local log = function() end

local capturedCalls   = {}   -- {name, args, time} — max 20 terakhir
local remoteCallCount = {}   -- [name] = count
local lastShoot       = nil  -- {remote, args, time}
local hookedNamecall  = false
local oldNamecall
local gui, mainFrame, textLabel
local dragging, dragStart, startPos = false, nil, nil
local detectedFireButton = nil
local fireButtonScanAt   = 0

-- ─── DETEKSI FIRE BUTTON ─────────────────────────────────────
local function findFireButton()
    if tick() - fireButtonScanAt < 3 and detectedFireButton then
        return detectedFireButton
    end
    fireButtonScanAt = tick()
    detectedFireButton = nil
    local guis = {"WeaponGui", "WeaponTouchGui", "HotbarGui"}
    for _, gname in ipairs(guis) do
        local g = PG:FindFirstChild(gname)
        if g then
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    local n = d.Name:lower()
                    if n:find("fire") or n:find("shoot") or n:find("trigger")
                       or n:find("attack") then
                        detectedFireButton = d
                        return d
                    end
                end
            end
        end
    end
    return nil
end

-- ─── DECODE PAYLOAD ─────────────────────────────────────────
local function decodePayload(args, maxDepth, depth)
    depth = depth or 1
    maxDepth = maxDepth or 2
    if depth > maxDepth then return "..." end
    if type(args) ~= "table" then
        if typeof(args) == "Vector3" then
            return string.format("Vector3(%.1f,%.1f,%.1f)", args.X, args.Y, args.Z)
        elseif typeof(args) == "CFrame" then
            return "CFrame"
        end
        return tostring(args)
    end
    local parts = {}
    local count = 0
    for k, v in pairs(args) do
        count = count + 1
        if count > 8 then table.insert(parts, "..."); break end
        local vs
        if type(v) == "table" then
            vs = "{" .. decodePayload(v, maxDepth, depth + 1) .. "}"
        elseif typeof(v) == "Vector3" then
            vs = string.format("V3(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
        elseif typeof(v) == "Instance" then
            vs = v:GetFullName()
        else
            vs = tostring(v)
        end
        table.insert(parts, tostring(k) .. "=" .. vs)
    end
    return table.concat(parts, ", ")
end

-- ─── CAPTURE ─────────────────────────────────────────────────
local function recordCall(name, args)
    remoteCallCount[name] = (remoteCallCount[name] or 0) + 1
    table.insert(capturedCalls, { name = name, args = args, time = tick() })
    if #capturedCalls > 20 then table.remove(capturedCalls, 1) end
end

-- ─── LIVE STATE UNTUK GUI ────────────────────────────────────
local function getNearestEnemyInfo()
    local best, bestDist = nil, math.huge
    local camPos = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local c = plr.Character
            local head = c and c:FindFirstChild("Head")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d = (head.Position - camPos).Magnitude
                if d < bestDist then bestDist = d; best = plr end
            end
        end
    end
    return best, bestDist
end

local function isCrosshairOnEnemy()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local c = plr.Character
            local head = c and c:FindFirstChild("Head")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local sp, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local dx, dy = sp.X - center.X, sp.Y - center.Y
                    if dx*dx + dy*dy <= 45*45 then return true, plr end
                end
            end
        end
    end
    return false, nil
end

-- ─── GUI ─────────────────────────────────────────────────────
local function buildGUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "RH_ShotDebug"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 1001
    gui.Parent = PG

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 320)
    mainFrame.Position = UDim2.new(0, 8, 0, 60)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = gui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", mainFrame)
    st.Color = Color3.fromRGB(255, 100, 100); st.Thickness = 1.5

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -50, 1, 0); tLabel.Position = UDim2.new(0, 8, 0, 0)
    tLabel.BackgroundTransparency = 1; tLabel.Text = "SHOT DEBUG"
    tLabel.TextColor3 = Color3.fromRGB(255, 150, 100); tLabel.TextSize = 11
    tLabel.Font = Enum.Font.GothamBold; tLabel.TextXAlignment = Enum.TextXAlignment.Left
    tLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20); closeBtn.Position = UDim2.new(1, -22, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40); closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.TextSize = 10
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 3)
    closeBtn.Activated:Connect(function() gui.Enabled = not gui.Enabled end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -6, 1, -30)
    scroll.Position = UDim2.new(0, 3, 0, 26)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = mainFrame

    textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -6, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "Starting..."
    textLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
    textLabel.TextSize = 10; textLabel.Font = Enum.Font.Code
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.Parent = scroll

    -- Dragging
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = mainFrame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                           startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ─── REFRESH GUI (tiap 0.25s) ───────────────────────────────
local function refreshGUI()
    if not textLabel or not gui or not gui.Enabled then return end
    local lines = {}

    -- Target
    local plr, dist = getNearestEnemyInfo()
    local onEnemy = isCrosshairOnEnemy()
    table.insert(lines, "── TARGET ──")
    if plr then
        table.insert(lines, string.format("%s  %.0fm  %s",
            plr.Name, dist, onEnemy and "[ON-XHAIR]" or ""))
    else
        table.insert(lines, "(no enemy)")
    end

    -- Fire Methods
    table.insert(lines, "── FIRE METHODS ──")
    local vimOk = false
    pcall(function() vimOk = game:GetService("VirtualInputManager") ~= nil end)
    table.insert(lines, string.format("VIM:%s  m1click:%s  m1press:%s",
        vimOk and "OK" or "X",
        type(mouse1click) == "function" and "OK" or "X",
        type(mouse1press) == "function" and "OK" or "X"))
    local fb = findFireButton()
    table.insert(lines, "Btn: " .. (fb and (fb:GetFullName():sub(-40)) or "NOT FOUND"))

    -- Remote Calls
    table.insert(lines, "── REMOTE CALLS ──")
    local names = {}
    for n in pairs(remoteCallCount) do table.insert(names, n) end
    table.sort(names, function(a, b) return remoteCallCount[a] > remoteCallCount[b] end)
    if #names == 0 then
        table.insert(lines, "(belum ada panggilan remote)")
    else
        for i = 1, math.min(#names, 8) do
            local n = names[i]
            local marker = (n == "Shoot") and " ★" or ""
            table.insert(lines, string.format("%s x%d%s", n, remoteCallCount[n], marker))
        end
    end

    -- Last Shoot Payload
    table.insert(lines, "── LAST SHOOT ──")
    if lastShoot then
        local ago = tick() - lastShoot.time
        table.insert(lines, string.format("%.1fs ago, %d args", ago, #lastShoot.args))
        table.insert(lines, "Payload:")
        table.insert(lines, decodePayload(lastShoot.args, 3))
    else
        table.insert(lines, "Belum ada. Tembak 1x manual.")
    end

    -- Recent calls
    table.insert(lines, "── RECENT (5) ──")
    local start = math.max(1, #capturedCalls - 4)
    for i = start, #capturedCalls do
        local c = capturedCalls[i]
        table.insert(lines, string.format("%.1fs %s(%d)",
            tick() - c.time, c.name, #c.args))
    end

    textLabel.Text = table.concat(lines, "\n")
end

-- ─── HOOK ────────────────────────────────────────────────────
local function installHook()
    if hookedNamecall then return true end
    if type(hookmetamethod) ~= "function" then
        log("ERR", "ShotDebug: hookmetamethod tidak support")
        return false
    end

    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                local name = "?"
                if typeof(self) == "Instance" then
                    name = self.Name or "?"
                end

                -- record semua
                pcall(recordCall, name, args)

                -- shoot special handling
                if name == "Shoot" or name == "Fire" or name == "Attack" then
                    lastShoot = { remote = self, args = args, time = tick(), name = name }
                    pcall(log, "INFO", string.format("ShotDebug captured [%s] args=%d: %s",
                        name, #args, decodePayload(args)))
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not ok then
        log("ERR", "ShotDebug hook install: " .. tostring(err))
        return false
    end
    hookedNamecall = true
    return true
end

-- ─── PUBLIC API ──────────────────────────────────────────────
function ShotDebug:Init()
    buildGUI()
    local ok = installHook()
    if ok then log("OK", "ShotDebug hook installed") end

    task.spawn(function()
        while gui and gui.Parent do
            task.wait(0.25)
            pcall(refreshGUI)
        end
    end)
end

function ShotDebug:SetLogger(fn) log = fn end

function ShotDebug:GetLastShoot() return lastShoot end

function ShotDebug:GetCallCount(name) return remoteCallCount[name] or 0 end

function ShotDebug:ReplayShoot()
    if not lastShoot then
        log("WARN", "ReplayShoot: tidak ada payload tersimpan")
        return false
    end
    local ok, err = pcall(function()
        lastShoot.remote:FireServer(table.unpack(lastShoot.args))
    end)
    if not ok then
        log("ERR", "ReplayShoot: " .. tostring(err))
        return false
    end
    log("OK", "ReplayShoot: fired " .. lastShoot.name)
    return true
end

function ShotDebug:ReplayShootModified(newArgs)
    if not lastShoot then return false end
    local ok, err = pcall(function()
        lastShoot.remote:FireServer(table.unpack(newArgs))
    end)
    if not ok then log("ERR", "ReplayModified: " .. tostring(err)); return false end
    return true
end

function ShotDebug:ClearStats()
    remoteCallCount = {}
    capturedCalls = {}
    log("INFO", "ShotDebug: stats cleared")
end

function ShotDebug:ToggleGUI()
    if gui then gui.Enabled = not gui.Enabled end
end

function ShotDebug:Destroy()
    if gui then gui:Destroy(); gui = nil end
    if hookedNamecall and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hookedNamecall = false
    end
end

return ShotDebug
