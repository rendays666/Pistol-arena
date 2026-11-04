--[[
    RENRENHUB CENTAURA — LOADER v2
    URL: https://raw.githubusercontent.com/rendays666/Pistol-arena/refs/heads/main/main.lua

    Fitur loader:
      - Aimbot module (FOV Circle / Full Body, Head / Body, Strong / Medium / Smooth)
      - ESP module (Names / HP / Distance / MaxDist / TeamCheck)
      - Console log dengan tombol Copy (buat debugging di Android)
      - Self-test + Dump config
]]

-- ═══════════════════════════════════════════════════════════════
local MODULES_URL = "https://raw.githubusercontent.com/rendays666/Pistol-arena/refs/heads/main/modules/"
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- LOG SYSTEM
-- ═══════════════════════════════════════════════════════════════
local LOG_LINES, MAX_LOG = {}, 800
local consoleUI = nil
local hasError = false

local function fmtTime()
    local t = tick()
    return string.format("%02d:%02d:%02d",
        math.floor(t / 3600) % 24,
        math.floor(t / 60) % 60,
        math.floor(t) % 60)
end

local function log(level, msg)
    local line = string.format("[%s][%s] %s", fmtTime(), level, tostring(msg))
    table.insert(LOG_LINES, line)
    if #LOG_LINES > MAX_LOG then table.remove(LOG_LINES, 1) end
    if level == "ERR" then hasError = true end
    if consoleUI and consoleUI.refresh then consoleUI.refresh() end
    pcall(function() print("[RH] " .. line) end)
end

local function logErr(ctx, err)
    log("ERR", ctx .. ": " .. tostring(err))
end

-- ═══════════════════════════════════════════════════════════════
-- CLIPBOARD
-- ═══════════════════════════════════════════════════════════════
local function copyToClipboard(text)
    local candidates = { setclipboard, toclipboard, writeclipboard }
    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            local ok = pcall(fn, text)
            if ok then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- CONSOLE UI (floating, draggable, mobile-friendly)
-- ═══════════════════════════════════════════════════════════════
local function createConsole()
    local Players   = game:GetService("Players")
    local UIS       = game:GetService("UserInputService")
    local LP        = Players.LocalPlayer
    local PG        = LP:WaitForChild("PlayerGui")

    local old = PG:FindFirstChild("RH_Console")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "RH_Console"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 1000
    sg.Parent = PG

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.92, 0, 0, 250)
    frame.Position = UDim2.new(0.04, 0, 1, -260)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Visible = false
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 220, 160)
    stroke.Thickness = 1.5

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 26)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -160, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Console Log"
    title.TextColor3 = Color3.fromRGB(0, 220, 160)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local function mkBtn(text, x, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 48, 0, 22)
        b.Position = UDim2.new(1, x, 0, 2)
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Parent = titleBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        return b
    end

    local copyBtn  = mkBtn("Copy",  -154, Color3.fromRGB(30, 140, 50))
    local clearBtn = mkBtn("Clear", -104, Color3.fromRGB(140, 40, 40))
    local closeBtn = mkBtn("✕",     -54,  Color3.fromRGB(80, 40, 40))

    -- Log area
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -32)
    scroll.Position = UDim2.new(0, 5, 0, 29)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 140)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.Parent = frame

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -4, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = ""
    txt.TextColor3 = Color3.fromRGB(200, 220, 210)
    txt.TextSize = 10
    txt.Font = Enum.Font.Code
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextWrapped = true
    txt.AutomaticSize = Enum.AutomaticSize.Y
    txt.Parent = scroll

    local function refresh()
        txt.Text = #LOG_LINES > 0 and table.concat(LOG_LINES, "\n") or "(belum ada log)"
        task.defer(function()
            local abs = scroll.AbsoluteCanvasSize
            scroll.CanvasPosition = Vector2.new(0, math.max(0, abs.Y - scroll.AbsoluteSize.Y))
        end)
    end

    copyBtn.Activated:Connect(function()
        local text = "=== RENRENHUB LOG ===\n" .. table.concat(LOG_LINES, "\n")
        if copyToClipboard(text) then
            copyBtn.Text = "✓"
            task.wait(1)
            copyBtn.Text = "Copy"
        else
            copyBtn.Text = "✗"
            task.wait(1)
            copyBtn.Text = "Copy"
        end
    end)

    clearBtn.Activated:Connect(function()
        LOG_LINES = {}
        hasError = false
        refresh()
    end)

    closeBtn.Activated:Connect(function()
        frame.Visible = false
    end)

    -- Dragging
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    consoleUI = {
        frame = frame,
        refresh = refresh,
        show = function() frame.Visible = true; refresh() end,
        hide = function() frame.Visible = false end,
        toggle = function() frame.Visible = not frame.Visible; if frame.Visible then refresh() end end,
    }
    refresh()
end

log("INFO", "=== LOADER START ===")
createConsole()
log("INFO", "Console UI created")

-- ═══════════════════════════════════════════════════════════════
-- MODULE LOADER
-- ═══════════════════════════════════════════════════════════════
local function loadModule(name)
    log("INFO", "Loading module: " .. name)
    local url = MODULES_URL .. name .. ".lua"
    local ok, result = pcall(function()
        local src = game:HttpGet(url, true)
        if not src or #src < 50 then error("empty source") end
        return loadstring(src)()
    end)
    if not ok then
        logErr("Load '" .. name .. "'", result)
        return nil
    end
    if type(result) ~= "table" then
        log("ERR", "Module '" .. name .. "' returned non-table: " .. type(result))
        return nil
    end
    log("OK", "Module '" .. name .. "' loaded")
    return result
end

-- Safe callback wrapper (log semua error di Rayfield callback)
local function safeFn(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then logErr("Callback " .. label, err) end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- RAYFIELD INIT
-- ═══════════════════════════════════════════════════════════════
local Rayfield
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not res then
        logErr("Rayfield", res or "nil")
        if consoleUI then consoleUI.show() end
        return
    end
    Rayfield = res
    log("OK", "Rayfield loaded")
end

local Window = Rayfield:CreateWindow({
    Name = "RENRENHUB CENTAURA",
    LoadingTitle = "Memuat module...",
    LoadingSubtitle = "Aimbot + ESP",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RenrenHub",
        FileName = "Config",
    },
    KeySystem = false,
})
log("OK", "Window created")

-- ═══════════════════════════════════════════════════════════════
-- LOAD MODULES
-- ═══════════════════════════════════════════════════════════════
local Aimbot = loadModule("aimbot")
local ESP    = loadModule("esp")

local function pickOpt(opt)
    if type(opt) == "table" then return opt[1] end
    return opt
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: AIMBOT
-- ═══════════════════════════════════════════════════════════════
if Aimbot then
    local okInit, errInit = pcall(function() Aimbot:Init() end)
    if okInit then log("OK", "Aimbot:Init() OK") else logErr("Aimbot:Init", errInit) end

    local AimTab = Window:CreateTab("Aimbot", 4483362458)

    AimTab:CreateSection("Aimbot")
    AimTab:CreateToggle({
        Name = "Enable Aimbot",
        CurrentValue = false,
        Flag = "Aim_Enabled",
        Callback = safeFn("Aim_Enabled", function(v)
            Aimbot:SetConfig({ Enabled = v })
            log("CFG", "Aimbot Enabled = " .. tostring(v))
        end),
    })

    AimTab:CreateSection("Mode")
    AimTab:CreateDropdown({
        Name = "Aimbot Mode",
        Options = { "FOV Circle", "Full Body" },
        CurrentOption = { "FOV Circle" },
        MultipleOptions = false,
        Flag = "Aim_Mode",
        Callback = safeFn("Aim_Mode", function(opt)
            local v = pickOpt(opt)
            Aimbot:SetConfig({ FOVMode = v })
            log("CFG", "Aimbot Mode = " .. tostring(v))
        end),
    })
    AimTab:CreateSlider({
        Name = "FOV Radius (Circle mode)",
        Range = { 20, 1000 },
        Increment = 10,
        Suffix = "px",
        CurrentValue = 150,
        Flag = "Aim_FOVRadius",
        Callback = safeFn("Aim_FOVRadius", function(v)
            Aimbot:SetConfig({ FOVRadius = v })
            log("CFG", "FOV Radius = " .. tostring(v))
        end),
    })

    AimTab:CreateSection("Target")
    AimTab:CreateDropdown({
        Name = "Aim Part",
        Options = { "Head", "Body" },
        CurrentOption = { "Head" },
        MultipleOptions = false,
        Flag = "Aim_Part",
        Callback = safeFn("Aim_Part", function(opt)
            local v = pickOpt(opt)
            Aimbot:SetConfig({ AimPart = v })
            log("CFG", "Aim Part = " .. tostring(v))
        end),
    })
    AimTab:CreateDropdown({
        Name = "Priority",
        Options = { "Nearest", "Lowest HP" },
        CurrentOption = { "Nearest" },
        MultipleOptions = false,
        Flag = "Aim_Priority",
        Callback = safeFn("Aim_Priority", function(opt)
            local v = pickOpt(opt)
            Aimbot:SetConfig({ Priority = v })
            log("CFG", "Priority = " .. tostring(v))
        end),
    })

    AimTab:CreateSection("Strength")
    AimTab:CreateDropdown({
        Name = "Aim Strength",
        Options = { "Strong", "Medium", "Smooth" },
        CurrentOption = { "Smooth" },
        MultipleOptions = false,
        Flag = "Aim_Strength",
        Callback = safeFn("Aim_Strength", function(opt)
            local v = pickOpt(opt)
            Aimbot:SetConfig({ Strength = v })
            log("CFG", "Strength = " .. tostring(v))
        end),
    })
    AimTab:CreateSlider({
        Name = "Smoothness (Smooth mode only)",
        Range = { 0.02, 1 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = 0.20,
        Flag = "Aim_Smoothness",
        Callback = safeFn("Aim_Smoothness", function(v)
            Aimbot:SetConfig({ Smoothness = v })
            log("CFG", "Smoothness = " .. tostring(v))
        end),
    })
    AimTab:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = 250,
        Flag = "Aim_MaxDist",
        Callback = safeFn("Aim_MaxDist", function(v)
            Aimbot:SetConfig({ MaxDistance = v })
            log("CFG", "Max Distance = " .. tostring(v))
        end),
    })

    AimTab:CreateSection("Misc")
    AimTab:CreateToggle({
        Name = "Team Check",
        CurrentValue = true,
        Flag = "Aim_TeamCheck",
        Callback = safeFn("Aim_TeamCheck", function(v)
            Aimbot:SetConfig({ TeamCheck = v })
            log("CFG", "TeamCheck = " .. tostring(v))
        end),
    })
else
    log("ERR", "Aimbot module tidak termuat — tab tidak dibuat")
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: ESP
-- ═══════════════════════════════════════════════════════════════
if ESP then
    local okInit, errInit = pcall(function() ESP:Init() end)
    if okInit then log("OK", "ESP:Init() OK") else logErr("ESP:Init", errInit) end

    local ESPTab = Window:CreateTab("ESP", 4483362458)

    ESPTab:CreateSection("Player ESP")
    ESPTab:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = false,
        Flag = "ESP_Enabled",
        Callback = safeFn("ESP_Enabled", function(v)
            ESP:SetConfig({ Enabled = v })
            log("CFG", "ESP Enabled = " .. tostring(v))
        end),
    })
    ESPTab:CreateToggle({
        Name = "Show Names",
        CurrentValue = true,
        Flag = "ESP_Names",
        Callback = safeFn("ESP_Names", function(v)
            ESP:SetConfig({ ShowNames = v })
            log("CFG", "ESP ShowNames = " .. tostring(v))
        end),
    })
    ESPTab:CreateToggle({
        Name = "Show HP",
        CurrentValue = true,
        Flag = "ESP_HP",
        Callback = safeFn("ESP_HP", function(v)
            ESP:SetConfig({ ShowHP = v })
            log("CFG", "ESP ShowHP = " .. tostring(v))
        end),
    })
    ESPTab:CreateToggle({
        Name = "Show Distance",
        CurrentValue = true,
        Flag = "ESP_Dist",
        Callback = safeFn("ESP_Dist", function(v)
            ESP:SetConfig({ ShowDistance = v })
            log("CFG", "ESP ShowDist = " .. tostring(v))
        end),
    })
    ESPTab:CreateToggle({
        Name = "Team Check",
        CurrentValue = true,
        Flag = "ESP_TeamCheck",
        Callback = safeFn("ESP_TeamCheck", function(v)
            ESP:SetConfig({ TeamCheck = v })
            log("CFG", "ESP TeamCheck = " .. tostring(v))
        end),
    })

    ESPTab:CreateSection("Values")
    ESPTab:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = 250,
        Flag = "ESP_MaxDist",
        Callback = safeFn("ESP_MaxDist", function(v)
            ESP:SetConfig({ MaxDistance = v })
            log("CFG", "ESP MaxDist = " .. tostring(v))
        end),
    })
else
    log("ERR", "ESP module tidak termuat — tab tidak dibuat")
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: MISC (Console + Debug)
-- ═══════════════════════════════════════════════════════════════
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Console Log")
MiscTab:CreateButton({
    Name = "Toggle Console Log",
    Callback = safeFn("ToggleConsole", function()
        if consoleUI then consoleUI.toggle(); log("INFO", "Console toggled") end
    end),
})
MiscTab:CreateButton({
    Name = "Copy Console Log",
    Callback = safeFn("CopyLog", function()
        local text = "=== RENRENHUB LOG ===\n" .. table.concat(LOG_LINES, "\n")
        local ok = copyToClipboard(text)
        log(ok and "OK" or "ERR", ok and "Log copied" or "Copy failed (no clipboard)")
    end),
})

MiscTab:CreateSection("Debug")
MiscTab:CreateButton({
    Name = "Run Self-Test",
    Callback = safeFn("SelfTest", function()
        log("TEST", "=== SELF TEST START ===")

        local clipOk = copyToClipboard("RH test")
        log("TEST", "Clipboard: " .. (clipOk and "OK" or "FAIL"))

        local drawOk = pcall(function()
            local d = Drawing.new("Text"); d:Remove()
        end)
        log("TEST", "Drawing lib: " .. (drawOk and "OK" or "FAIL"))

        local cam = workspace.CurrentCamera
        log("TEST", "Camera: " .. (cam and "OK" or "FAIL"))

        local LP = game:GetService("Players").LocalPlayer
        log("TEST", "LocalPlayer: " .. (LP and LP.Name or "FAIL"))
        log("TEST", "Character: " .. (LP.Character and "OK" or "NIL"))
        log("TEST", "Team: " .. (LP.Team and LP.Team.Name or "NONE"))

        if Aimbot then
            log("TEST", "Aimbot module: LOADED")
            local ok = pcall(function() Aimbot:SetConfig({}) end)
            log("TEST", "Aimbot SetConfig: " .. (ok and "OK" or "FAIL"))
        else
            log("TEST", "Aimbot module: MISSING")
        end

        if ESP then
            log("TEST", "ESP module: LOADED")
            local ok = pcall(function() ESP:SetConfig({}) end)
            log("TEST", "ESP SetConfig: " .. (ok and "OK" or "FAIL"))
        else
            log("TEST", "ESP module: MISSING")
        end

        log("TEST", "=== SELF TEST END ===")
    end),
})
MiscTab:CreateButton({
    Name = "Dump Config",
    Callback = safeFn("DumpConfig", function()
        local function dump(name, mod)
            log("CFG", "=== " .. name .. " ===")
            if not mod then log("CFG", "  NOT LOADED"); return end
            local keys = {}
            for k in pairs(mod.Config or {}) do table.insert(keys, k) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                log("CFG", "  " .. k .. " = " .. tostring(mod.Config[k]))
            end
        end
        dump("Aimbot", Aimbot)
        dump("ESP", ESP)
    end),
})
MiscTab:CreateButton({
    Name = "Destroy All Modules",
    Callback = safeFn("DestroyAll", function()
        if Aimbot then pcall(function() Aimbot:Destroy() end) end
        if ESP    then pcall(function() ESP:Destroy()    end) end
        log("INFO", "All modules destroyed")
    end),
})

-- ═══════════════════════════════════════════════════════════════
-- READY
-- ═══════════════════════════════════════════════════════════════
log("INFO", "=== LOADER READY ===")

pcall(function()
    Rayfield:Notify({
        Title = "Loaded",
        Content = string.format("Aimbot: %s | ESP: %s",
            Aimbot and "OK" or "FAIL",
            ESP and "OK" or "FAIL"),
        Duration = 5,
    })
end)

if hasError and consoleUI then
    consoleUI.show()
    log("WARN", "Ada error terdeteksi, console dibuka otomatis")
end
