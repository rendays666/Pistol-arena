--[[
    MODULE: ShotDebug v3
    - Fix OnMap: cek Character jika Player nil
    - Tampilkan Tombol Fire yang terdeteksi
]]

local ShotDebug = {}
ShotDebug.Config = { Enabled = true }

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Camera      = workspace.CurrentCamera
local UIS         = game:GetService("UserInputService")
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

local log = function() end
local lastCaptures    = {}
local remoteCallCount = {}
local recentCalls     = {}
local hookedNamecall  = false
local oldNamecall
local gui, mainFrame, textLabel
local dragging, dragStart, startPos = false, nil, nil

local function isShootLike(name)
    local n = name:lower()
    return n:find("shoot") or n:find("bullet") or n:find("fire")
        or n:find("attack") or n:find("hit") or n:find("damage")
end

local function findFireButton()
    local PGui = LP:FindFirstChild("PlayerGui")
    if not PGui then return nil end
    for _, v in ipairs(PGui:GetDescendants()) do
        if v:IsA("ImageButton") or v:IsA("TextButton") then
            local n = v.Name:lower()
            if n:find("fire") or n:find("shoot") or n:find("attack") or n:find("primary") then
                return v
            end
        end
    end
    return nil
end

local function describeArgs(args)
    local parts = {}
    for i = 1, math.min(#args, 6) do
        local v = args[i]
        local t = typeof(v)
        if t == "Vector3" then
            parts[#parts+1] = string.format("a%d=V3(m%.1f)", i, v.Magnitude)
        elseif t == "CFrame" then
            parts[#parts+1] = "a"..i.."=CFrame"
        elseif t == "table" then
            parts[#parts+1] = "a"..i.."=tbl"
        else
            local s = tostring(v)
            if #s > 15 then s = s:sub(1, 15).."..." end
            parts[#parts+1] = "a"..i.."="..t..":"..s
        end
    end
    return table.concat(parts, "  ")
end

local function capture(name, args)
    remoteCallCount[name] = (remoteCallCount[name] or 0) + 1
    lastCaptures[name] = { args = args, time = tick() }
    table.insert(recentCalls, { name = name, args = args, time = tick() })
    if #recentCalls > 30 then table.remove(recentCalls, 1) end

    if isShootLike(name) then
        log("CAP", string.format("[%s] n=%d | %s", name, #args, describeArgs(args)))
    end
end

local function buildGUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "RH_ShotDebug"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 1001
    gui.Parent = PG

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 360)
    mainFrame.Position = UDim2.new(0, 8, 0, 55)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0; mainFrame.Active = true
    mainFrame.Parent = gui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", mainFrame)
    st.Color = Color3.fromRGB(255, 100, 100); st.Thickness = 1.5

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
    titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -50, 1, 0); tLabel.Position = UDim2.new(0, 8, 0, 0)
    tLabel.BackgroundTransparency = 1; tLabel.Text = "SHOT DEBUG v3"
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
    textLabel.TextSize = 9; textLabel.Font = Enum.Font.Code
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.Parent = scroll

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

local function refreshGUI()
    if not textLabel or not gui or not gui.Enabled then return end
    local lines = {}

    -- OnMap fix (Cek Character juga)
    local onMap = LP:GetAttribute("OnMap")
    if onMap == nil and LP.Character then
        onMap = LP.Character:GetAttribute("OnMap")
    end
    local hp = 0
    if LP.Character then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hp = math.floor(hum.Health) end
    end

    table.insert(lines, "── STATUS ──")
    table.insert(lines, "OnMap: " .. tostring(onMap))
    table.insert(lines, "HP: " .. tostring(hp))
    
    local fbtn = findFireButton()
    table.insert(lines, "Fire Btn: " .. (fbtn and (fbtn.Name) or "NOT FOUND"))

    table.insert(lines, "── SHOOT CAPTURED ──")
    local shootFound = false
    for name, info in pairs(lastCaptures) do
        if isShootLike(name) then
            shootFound = true
            local ago = tick() - info.time
            table.insert(lines, string.format("%s x%d (%.1fs|n=%d)",
                name, remoteCallCount[name] or 0, ago, #info.args))
            table.insert(lines, "  " .. describeArgs(info.args))
        end
    end
    if not shootFound then
        table.insert(lines, "Belum ada. Tembak 3x manual.")
    end

    table.insert(lines, "── ALL REMOTES (top 8) ──")
    local names = {}
    for n in pairs(remoteCallCount) do table.insert(names, n) end
    table.sort(names, function(a,b) return remoteCallCount[a] > remoteCallCount[b] end)
    for i = 1, math.min(#names, 8) do
        local n = names[i]
        local marker = isShootLike(n) and " ★" or ""
        table.insert(lines, string.format("%s x%d%s", n, remoteCallCount[n], marker))
    end

    table.insert(lines, "── RECENT (5) ──")
    local start = math.max(1, #recentCalls - 4)
    for i = start, #recentCalls do
        local c = recentCalls[i]
        table.insert(lines, string.format("%.1fs %s(n=%d)",
            tick() - c.time, c.name, #c.args))
    end

    textLabel.Text = table.concat(lines, "\n")
end

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
                local name = typeof(self) == "Instance" and (self.Name or "?") or "?"
                pcall(capture, name, args)
            end
            return oldNamecall(self, ...)
        end)
    end)

    if not ok then
        log("ERR", "ShotDebug hook: " .. tostring(err))
        return false
    end
    hookedNamecall = true
    return true
end

function ShotDebug:Init()
    buildGUI()
    if installHook() then log("OK", "ShotDebug v3 hook installed") end
    task.spawn(function()
        while gui and gui.Parent do
            task.wait(0.25)
            pcall(refreshGUI)
        end
    end)
end

function ShotDebug:SetLogger(fn) log = fn end
function ShotDebug:ToggleGUI() if gui then gui.Enabled = not gui.Enabled end end
function ShotDebug:ClearStats()
    remoteCallCount, recentCalls = {}, {}
    log("INFO", "ShotDebug cleared")
end

function ShotDebug:Destroy()
    if gui then gui:Destroy(); gui = nil end
    if hookedNamecall and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
        hookedNamecall = false
    end
end

return ShotDebug
