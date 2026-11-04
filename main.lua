--[[
    RENRENHUB CENTAURA — LOADER v3
    - Aimbot: FOV Circle / Full Body 360° (tembus belakang kamera)
    - ESP: HP Bar berwarna (hijau→merah)
    - Auto-save config ke RenrenHub/config.json
    - Auto-reload via queue_on_teleport (tidak perlu re-execute setiap match)
    - Console log dengan Copy
]]

local SCRIPT_URL = "https://raw.githubusercontent.com/rendays666/Pistol-arena/refs/heads/main/main.lua"
local MODULES_URL = "https://raw.githubusercontent.com/rendays666/Pistol-arena/refs/heads/main/modules/"

-- ═══════════════════════════════════════════════════════════════
-- SERVICES & UTIL
-- ═══════════════════════════════════════════════════════════════
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

-- cleanup previous console
do
    local old = PG:FindFirstChild("RH_Console")
    if old then old:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- LOG SYSTEM
-- ═══════════════════════════════════════════════════════════════
local LOG_LINES, MAX_LOG = {}, 800
local consoleUI = nil
local hasError = false

local function fmtTime()
    local t = tick()
    return string.format("%02d:%02d:%02d",
        math.floor(t / 3600) % 24, math.floor(t / 60) % 60, math.floor(t) % 60)
end

local function log(level, msg)
    local line = string.format("[%s][%s] %s", fmtTime(), level, tostring(msg))
    table.insert(LOG_LINES, line)
    if #LOG_LINES > MAX_LOG then table.remove(LOG_LINES, 1) end
    if level == "ERR" then hasError = true end
    if consoleUI and consoleUI.refresh then consoleUI.refresh() end
    pcall(function() print("[RH] " .. line) end)
end

local function logErr(ctx, err) log("ERR", ctx .. ": " .. tostring(err)) end

-- ═══════════════════════════════════════════════════════════════
-- CLIPBOARD
-- ═══════════════════════════════════════════════════════════════
local function copyToClipboard(text)
    for _, fn in ipairs({ setclipboard, toclipboard, writeclipboard }) do
        if type(fn) == "function" then
            if pcall(fn, text) then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIG PERSISTENCE (file-based, auto save)
-- ═══════════════════════════════════════════════════════════════
local CONFIG_FOLDER = "RenrenHub"
local CONFIG_FILE   = CONFIG_FOLDER .. "/config.json"

local function ensureFolder()
    if type(makefolder) ~= "function" then return end
    local exists = false
    if type(isfolder) == "function" then
        local ok, r = pcall(isfolder, CONFIG_FOLDER)
        exists = ok and r
    end
    if not exists then pcall(makefolder, CONFIG_FOLDER) end
end

local function sanitize(tbl)
    local out = {}
    if type(tbl) ~= "table" then return out end
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv == "number" or tv == "string" or tv == "boolean" then out[k] = v end
    end
    return out
end

local function saveConfig(Aimbot, ESP)
    if type(writefile) ~= "function" then return false end
    ensureFolder()
    local data = {
        Aimbot = sanitize(Aimbot and Aimbot.Config or {}),
        ESP    = sanitize(ESP and ESP.Config or {}),
    }
    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
    if not ok then logErr("saveConfig", err); return false end
    return true
end

local function loadSavedConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    if not isfile(CONFIG_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok then logErr("loadSavedConfig", data); return nil end
    return data
end

-- Debounced save
local _lastSave = 0
local _saveCb = nil
local function scheduleSave()
    local now = tick()
    if now - _lastSave < 0.3 then return end
    _lastSave = now
    if _saveCb then pcall(_saveCb) end
end

-- ═══════════════════════════════════════════════════════════════
-- CONSOLE UI
-- ═══════════════════════════════════════════════════════════════
local function createConsole()
    local sg = Instance.new("ScreenGui")
    sg.Name = "RH_Console"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000; sg.Parent = PG

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.92, 0, 0, 250)
    frame.Position = UDim2.new(0.04, 0, 1, -260)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0; frame.Active = true
    frame.Visible = false; frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", frame)
    st.Color = Color3.fromRGB(0, 220, 160); st.Thickness = 1.5

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 26)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
    titleBar.BorderSizePixel = 0; titleBar.Parent = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -160, 1, 0); title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1; title.Text = "Console Log"
    title.TextColor3 = Color3.fromRGB(0, 220, 160); title.TextSize = 12
    title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local function mkBtn(text, x, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 48, 0, 22); b.Position = UDim2.new(1, x, 0, 2)
        b.BackgroundColor3 = color; b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1); b.TextSize = 11
        b.Font = Enum.Font.GothamBold; b.BorderSizePixel = 0
        b.AutoButtonColor = false; b.Parent = titleBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        return b
    end

    local copyBtn  = mkBtn("Copy",  -154, Color3.fromRGB(30, 140, 50))
    local clearBtn = mkBtn("Clear", -104, Color3.fromRGB(140, 40, 40))
    local closeBtn = mkBtn("✕",     -54,  Color3.fromRGB(80, 40, 40))

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -32); scroll.Position = UDim2.new(0, 5, 0, 29)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 140)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = frame

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -4, 0, 0); txt.BackgroundTransparency = 1
    txt.Text = ""; txt.TextColor3 = Color3.fromRGB(200, 220, 210)
    txt.TextSize = 10; txt.Font = Enum.Font.Code
    txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextWrapped = true; txt.AutomaticSize = Enum.AutomaticSize.Y
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
        local ok = copyToClipboard(text)
        copyBtn.Text = ok and "✓" or "✗"
        task.wait(1); copyBtn.Text = "Copy"
    end)
    clearBtn.Activated:Connect(function()
        LOG_LINES = {}; hasError = false; refresh()
    end)
    closeBtn.Activated:Connect(function() frame.Visible = false end)

    -- Drag
    local drag, ds, sp = false, nil, nil
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; ds = i.Position; sp = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)

    consoleUI = {
        frame = frame, refresh = refresh,
        show = function() frame.Visible = true; refresh() end,
        toggle = function() frame.Visible = not frame.Visible; if frame.Visible then refresh() end end,
    }
    refresh()
end

log("INFO", "=== LOADER START ===")
createConsole()
log("INFO", "Console created")

if type(writefile) == "function" then
    log("OK", "writefile available — config akan disimpan")
else
    log("WARN", "writefile TIDAK tersedia — config tidak bisa disimpan")
end

-- ═══════════════════════════════════════════════════════════════
-- MODULE LOADER
-- ═══════════════════════════════════════════════════════════════
local function loadModule(name)
    log("INFO", "Loading module: " .. name)
    local ok, result = pcall(function()
        local src = game:HttpGet(MODULES_URL .. name .. ".lua", true)
        if not src or #src < 50 then error("empty source") end
        return loadstring(src)()
    end)
    if not ok then logErr("Load '" .. name .. "'", result); return nil end
    if type(result) ~= "table" then
        log("ERR", "Module '" .. name .. "' returned " .. type(result))
        return nil
    end
    log("OK", "Module '" .. name .. "' loaded")
    return result
end

local function safeFn(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then logErr("Callback " .. label, err) end
        pcall(scheduleSave)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- RAYFIELD
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
    ConfigurationSaving = { Enabled = false }, -- pakai config sendiri
    KeySystem = false,
})
log("OK", "Window created")

-- ═══════════════════════════════════════════════════════════════
-- LOAD MODULES + APPLY SAVED CONFIG
-- ═══════════════════════════════════════════════════════════════
local Aimbot = loadModule("aimbot")
local ESP    = loadModule("esp")

local saved = loadSavedConfig() or {}
local savedAim = saved.Aimbot or {}
local savedESP = saved.ESP or {}

if next(savedAim) then log("INFO", "Config aimbot dimuat dari file") end
if next(savedESP) then log("INFO", "Config ESP dimuat dari file") end

if Aimbot then
    Aimbot:SetConfig(savedAim)  -- apply config dulu
    local ok, err = pcall(function() Aimbot:Init() end)
    if ok then log("OK", "Aimbot:Init()") else logErr("Aimbot:Init", err) end
end
if ESP then
    ESP:SetConfig(savedESP)
    local ok, err = pcall(function() ESP:Init() end)
    if ok then log("OK", "ESP:Init()") else logErr("ESP:Init", err) end
end

-- Wire save callback
_saveCb = function() saveConfig(Aimbot, ESP) end

local function pickOpt(opt)
    if type(opt) == "table" then return opt[1] end
    return opt
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: AIMBOT
-- ═══════════════════════════════════════════════════════════════
if Aimbot then
    local T = Window:CreateTab("Aimbot", 4483362458)

    T:CreateSection("Aimbot")
    T:CreateToggle({
        Name = "Enable Aimbot",
        CurrentValue = savedAim.Enabled == true,
        Flag = "Aim_Enabled",
        Callback = safeFn("Aim_Enabled", function(v)
            Aimbot:SetConfig({ Enabled = v })
            log("CFG", "Aimbot Enabled = " .. tostring(v))
        end),
    })

    T:CreateSection("Mode")
    T:CreateDropdown({
        Name = "Aimbot Mode",
        Options = { "FOV Circle", "Full Body (360°)" },
        CurrentOption = { savedAim.FOVMode or "FOV Circle" },
        MultipleOptions = false,
        Flag = "Aim_Mode",
        Callback = safeFn("Aim_Mode", function(opt)
            local v = pickOpt(opt)
            Aimbot:SetConfig({ FOVMode = v })
            log("CFG", "Aimbot Mode = " .. tostring(v))
        end),
    })
    T:CreateSlider({
        Name = "FOV Radius (Circle mode)",
        Range = { 20, 1000 },
        Increment = 10,
        Suffix = "px",
        CurrentValue = savedAim.FOVRadius or 150,
        Flag = "Aim_FOVRadius",
        Callback = safeFn("Aim_FOVRadius", function(v)
            Aimbot:SetConfig({ FOVRadius = v })
        end),
    })

    T:CreateSection("Target")
    T:CreateDropdown({
        Name = "Aim Part",
        Options = { "Head", "Body" },
        CurrentOption = { savedAim.AimPart or "Head" },
        MultipleOptions = false,
        Flag = "Aim_Part",
        Callback = safeFn("Aim_Part", function(opt)
            Aimbot:SetConfig({ AimPart = pickOpt(opt) })
            log("CFG", "Aim Part = " .. tostring(pickOpt(opt)))
        end),
    })
    T:CreateDropdown({
        Name = "Priority",
        Options = { "Nearest", "Lowest HP" },
        CurrentOption = { savedAim.Priority or "Nearest" },
        MultipleOptions = false,
        Flag = "Aim_Priority",
        Callback = safeFn("Aim_Priority", function(opt)
            Aimbot:SetConfig({ Priority = pickOpt(opt) })
        end),
    })

    T:CreateSection("Strength")
    T:CreateDropdown({
        Name = "Aim Strength",
        Options = { "Strong", "Medium", "Smooth" },
        CurrentOption = { savedAim.Strength or "Smooth" },
        MultipleOptions = false,
        Flag = "Aim_Strength",
        Callback = safeFn("Aim_Strength", function(opt)
            Aimbot:SetConfig({ Strength = pickOpt(opt) })
            log("CFG", "Strength = " .. tostring(pickOpt(opt)))
        end),
    })
    T:CreateSlider({
        Name = "Smoothness (Smooth mode)",
        Range = { 0.02, 1 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = savedAim.Smoothness or 0.20,
        Flag = "Aim_Smoothness",
        Callback = safeFn("Aim_Smoothness", function(v)
            Aimbot:SetConfig({ Smoothness = v })
        end),
    })
    T:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = savedAim.MaxDistance or 250,
        Flag = "Aim_MaxDist",
        Callback = safeFn("Aim_MaxDist", function(v)
            Aimbot:SetConfig({ MaxDistance = v })
        end),
    })

    T:CreateSection("Misc")
    T:CreateToggle({
        Name = "Team Check",
        CurrentValue = savedAim.TeamCheck ~= false,
        Flag = "Aim_TeamCheck",
        Callback = safeFn("Aim_TeamCheck", function(v)
            Aimbot:SetConfig({ TeamCheck = v })
        end),
    })
else
    log("ERR", "Aimbot module tidak termuat")
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: ESP
-- ═══════════════════════════════════════════════════════════════
if ESP then
    local T = Window:CreateTab("ESP", 4483362458)

    T:CreateSection("Player ESP")
    T:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = savedESP.Enabled == true,
        Flag = "ESP_Enabled",
        Callback = safeFn("ESP_Enabled", function(v)
            ESP:SetConfig({ Enabled = v })
            log("CFG", "ESP Enabled = " .. tostring(v))
        end),
    })
    T:CreateToggle({
        Name = "Show Names",
        CurrentValue = savedESP.ShowNames ~= false,
        Flag = "ESP_Names",
        Callback = safeFn("ESP_Names", function(v)
            ESP:SetConfig({ ShowNames = v })
        end),
    })
    T:CreateToggle({
        Name = "Show HP Bar",
        CurrentValue = savedESP.ShowHPBar ~= false,
        Flag = "ESP_HPBar",
        Callback = safeFn("ESP_HPBar", function(v)
            ESP:SetConfig({ ShowHPBar = v })
        end),
    })
    T:CreateToggle({
        Name = "Show Distance",
        CurrentValue = savedESP.ShowDistance ~= false,
        Flag = "ESP_Dist",
        Callback = safeFn("ESP_Dist", function(v)
            ESP:SetConfig({ ShowDistance = v })
        end),
    })
    T:CreateToggle({
        Name = "Team Check",
        CurrentValue = savedESP.TeamCheck ~= false,
        Flag = "ESP_TeamCheck",
        Callback = safeFn("ESP_TeamCheck", function(v)
            ESP:SetConfig({ TeamCheck = v })
        end),
    })

    T:CreateSection("Values")
    T:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = savedESP.MaxDistance or 250,
        Flag = "ESP_MaxDist",
        Callback = safeFn("ESP_MaxDist", function(v)
            ESP:SetConfig({ MaxDistance = v })
        end),
    })
else
    log("ERR", "ESP module tidak termuat")
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: MISC
-- ═══════════════════════════════════════════════════════════════
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Console Log")
MiscTab:CreateButton({
    Name = "Toggle Console Log",
    Callback = safeFn("ToggleConsole", function()
        if consoleUI then consoleUI.toggle() end
    end),
})
MiscTab:CreateButton({
    Name = "Copy Console Log",
    Callback = safeFn("CopyLog", function()
        local ok = copyToClipboard("=== RENRENHUB LOG ===\n" .. table.concat(LOG_LINES, "\n"))
        log(ok and "OK" or "ERR", ok and "Log copied" or "Copy failed")
    end),
})

MiscTab:CreateSection("Config")
MiscTab:CreateButton({
    Name = "Save Config Now",
    Callback = safeFn("SaveConfigBtn", function()
        local ok = saveConfig(Aimbot, ESP)
        log(ok and "OK" or "ERR", ok and "Config tersimpan" or "Config gagal disimpan")
    end),
})
MiscTab:CreateButton({
    Name = "Reset Config (default)",
    Callback = safeFn("ResetConfig", function()
        if type(delfile) == "function" and isfile(CONFIG_FILE) then
            pcall(delfile, CONFIG_FILE)
            log("OK", "Config dihapus. Re-execute untuk reset penuh.")
        else
            log("WARN", "delfile tidak tersedia")
        end
    end),
})

MiscTab:CreateSection("Debug")
MiscTab:CreateButton({
    Name = "Run Self-Test",
    Callback = safeFn("SelfTest", function()
        log("TEST", "=== SELF TEST ===")
        log("TEST", "Clipboard: " .. (copyToClipboard("test") and "OK" or "FAIL"))
        local drawOk = pcall(function()
            local d = Drawing.new("Text"); d:Remove()
            local s = Drawing.new("Square"); s:Remove()
        end)
        log("TEST", "Drawing: " .. (drawOk and "OK" or "FAIL"))
        log("TEST", "writefile: " .. (type(writefile) == "function" and "OK" or "FAIL"))
        log("TEST", "queue_on_teleport: " .. (type(queue_on_teleport) == "function" and "OK" or "FAIL"))
        log("TEST", "Aimbot: " .. (Aimbot and "OK" or "MISSING"))
        log("TEST", "ESP: " .. (ESP and "OK" or "MISSING"))
        log("TEST", "=== END ===")
    end),
})
MiscTab:CreateButton({
    Name = "Dump Config",
    Callback = safeFn("DumpConfig", function()
        local function dump(name, mod)
            log("CFG", "=== " .. name .. " ===")
            if not mod then log("CFG", "  NOT LOADED"); return end
            local keys = {}
            for k in pairs(mod.Config) do table.insert(keys, k) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                log("CFG", "  " .. k .. " = " .. tostring(mod.Config[k]))
            end
        end
        dump("Aimbot", Aimbot); dump("ESP", ESP)
    end),
})
MiscTab:CreateButton({
    Name = "Destroy All Modules",
    Callback = safeFn("DestroyAll", function()
        if Aimbot then pcall(function() Aimbot:Destroy() end) end
        if ESP then pcall(function() ESP:Destroy() end) end
        log("INFO", "Semua module di-destroy")
    end),
})

-- ═══════════════════════════════════════════════════════════════
-- AUTO-RELOAD via queue_on_teleport
-- ═══════════════════════════════════════════════════════════════
do
    local registered = false
    if type(queue_on_teleport) == "function" then
        local ok = pcall(queue_on_teleport, string.format([[
            task.wait(1.5)
            pcall(function()
                loadstring(game:HttpGet(%q, true))()
            end)
        ]], SCRIPT_URL))
        registered = ok
    end
    if registered then
        log("OK", "Auto-reload on teleport: AKTIF")
    else
        log("WARN", "queue_on_teleport TIDAK tersedia — perlu re-execute manual setelah pindah server")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- READY
-- ═══════════════════════════════════════════════════════════════
log("INFO", "=== LOADER READY ===")

pcall(function()
    Rayfield:Notify({
        Title = "Loaded",
        Content = string.format("Aimbot: %s | ESP: %s",
            Aimbot and "OK" or "FAIL", ESP and "OK" or "FAIL"),
        Duration = 5,
    })
end)

if hasError and consoleUI then
    consoleUI.show()
    log("WARN", "Ada error — console dibuka otomatis")
end
