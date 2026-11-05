--[[
    RENRENHUB CENTAURA — LOADER v6 (Aimbot + ESP only)
    Config di atas — ubah nama, default value, on/off di sini
    Save config = local file only, no auto execute on teleport
]]

-- ═══════════════════════════════════════════════════════════════
-- ██ CONFIG — EDIT DI SINI ██
-- ═══════════════════════════════════════════════════════════════
local CONFIG = {
    -- URL Modules
    ModulesURL = "https://raw.githubusercontent.com/rendays666/Pistol-arena/refs/heads/main/modules/",

    -- Window
    Window = {
        Name           = "RENRENHUB PISTOL ARENA",
        LoadingTitle   = "Memuat module...",
        LoadingSubtitle = "AUTO WIN",
    },

    -- File config lokal
    ConfigFolder = "RenrenHub",
    ConfigFile   = "RenrenHub/config.json",

    -- ═══════════════════════════════════════════════════
    -- AIMBOT — Label UI + Default value + On/Off
    -- ═══════════════════════════════════════════════════
    Aimbot = {
        Labels = {
            Tab             = "Aimbot",
            SectionMain     = "Aimbot",
            Enable          = "Enable Aimbot",
            SectionMode     = "Mode",
            Mode            = "Aimbot Mode",
            FOVRadius       = "FOV Radius",
            SectionTarget   = "Target",
            AimPart         = "Aim Part",
            Priority        = "Priority",
            SectionStrength = "Strength",
            Strength        = "Aim Strength",
            Smoothness      = "Smoothness",
            MaxDistance     = "Max Distance",
            SectionMisc     = "Misc",
            TeamCheck       = "Team Check",
            WallCheck       = "Wall Check (LOS)",
        },
        Flags = {
            Enabled     = "Aim_Enabled",
            Mode        = "Aim_Mode",
            FOVRadius   = "Aim_FOVRadius",
            AimPart     = "Aim_Part",
            Priority    = "Aim_Priority",
            Strength    = "Aim_Strength",
            Smoothness  = "Aim_Smoothness",
            MaxDistance = "Aim_MaxDist",
            TeamCheck   = "Aim_TeamCheck",
            WallCheck   = "Aim_WallCheck",
        },
        -- ⚠ Key harus SAMA dengan yang dipakai callback SetConfig & dibaca module
        Defaults = {
            Enabled     = true,
            FOVMode     = "Full Body (360°)",
            FOVRadius   = 150,
            AimPart     = "Head",
            Priority    = "Nearest",
            Strength    = "Strong",
            Smoothness  = 0.20,
            MaxDistance = 250,
            TeamCheck   = true,          -- ON (sesuai JSON)
            WallCheck   = true,
        },
        Options = {
            Mode     = { "FOV Circle", "Full Body (360°)" },
            AimPart  = { "Head", "Body" },
            Priority = { "Nearest", "Lowest HP" },
            Strength = { "Strong", "Medium", "Smooth" },
        },
    },

    -- ═══════════════════════════════════════════════════
    -- ESP — Label UI + Default value + On/Off
    -- ═══════════════════════════════════════════════════
    ESP = {
        Labels = {
            Tab           = "ESP",
            SectionMain   = "Player ESP",
            Enable        = "Enable ESP",
            ShowNames     = "Show Names",
            ShowHPBar     = "Show HP Bar",
            ShowDistance  = "Show Distance",
            ShowChams     = "Show Chams",
            ShowTracer    = "Show Tracer",
            TeamCheck     = "Team Check",
            SectionValues = "Values",
            MaxDistance   = "Max Distance",
        },
        Flags = {
            Enabled      = "ESP_Enabled",
            ShowNames    = "ESP_Names",
            ShowHPBar    = "ESP_HPBar",
            ShowDistance = "ESP_Dist",
            ShowChams    = "ESP_Chams",
            ShowTracer   = "ESP_Tracer",
            TeamCheck    = "ESP_TeamCheck",
            MaxDistance  = "ESP_MaxDist",
        },
        Defaults = {
            Enabled      = true,
            ShowNames    = true,
            ShowHPBar    = true,
            ShowDistance = true,
            ShowChams    = false,
            ShowTracer   = false,
            TeamCheck    = true,     -- ON (sesuai JSON)
            MaxDistance  = 250,
        },
    },
}

-- ═══════════════════════════════════════════════════════════════
-- ██ END CONFIG ██
-- ═══════════════════════════════════════════════════════════════


local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

do
    local old = PG:FindFirstChild("RH_Console")
    if old then old:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIG PERSISTENCE (local only)
-- ═══════════════════════════════════════════════════════════════
local function ensureFolder()
    if type(makefolder) ~= "function" then return end
    local exists = false
    if type(isfolder) == "function" then
        local ok, r = pcall(isfolder, CONFIG.ConfigFolder)
        exists = ok and r
    end
    if not exists then pcall(makefolder, CONFIG.ConfigFolder) end
end

local function sanitize(tbl)
    local out = {}
    if type(tbl) ~= "table" then return out end
    for k, v in pairs(tbl) do
        local tv = type(v)
        if tv == "number" or tv == "string" or tv == "boolean" then
            out[k] = v
        end
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
    local ok = pcall(function()
        writefile(CONFIG.ConfigFile, HttpService:JSONEncode(data))
    end)
    return ok
end

local function loadSavedConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return nil end
    if not isfile(CONFIG.ConfigFile) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG.ConfigFile))
    end)
    if not ok then return nil end
    return data
end

local _lastSave, _saveCb = 0, nil
local function scheduleSave()
    local now = tick()
    if now - _lastSave < 0.3 then return end
    _lastSave = now
    if _saveCb then pcall(_saveCb) end
end

-- ═══════════════════════════════════════════════════════════════
-- MODULE LOADER
-- ═══════════════════════════════════════════════════════════════
local function loadModule(name)
    local ok, result = pcall(function()
        local src = game:HttpGet(CONFIG.ModulesURL .. name .. ".lua", true)
        if not src or #src < 50 then error("empty source") end
        return loadstring(src)()
    end)
    if not ok then return nil end
    if type(result) ~= "table" then return nil end
    return result
end

local function safeFn(fn)
    return function(...)
        local ok = pcall(fn, ...)
        if ok then pcall(scheduleSave) end
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
    if not ok or not res then return end
    Rayfield = res
end

local Window = Rayfield:CreateWindow({
    Name = CONFIG.Window.Name,
    LoadingTitle = CONFIG.Window.LoadingTitle,
    LoadingSubtitle = CONFIG.Window.LoadingSubtitle,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ═══════════════════════════════════════════════════════════════
-- LOAD MODULES
-- ═══════════════════════════════════════════════════════════════
local Aimbot = loadModule("aimbot")
local ESP    = loadModule("esp")

local saved     = loadSavedConfig() or {}
local savedAim  = saved.Aimbot or {}
local savedESP  = saved.ESP    or {}

local function mergeConfig(defaults, saved)
    local out = {}
    for k, v in pairs(defaults) do out[k] = v end
    for k, v in pairs(saved) do
        if out[k] ~= nil then out[k] = v end
    end
    return out
end

if Aimbot then
    local init = mergeConfig(CONFIG.Aimbot.Defaults, savedAim)
    Aimbot:SetConfig(init)
    pcall(function() Aimbot:Init() end)
end

if ESP then
    local init = mergeConfig(CONFIG.ESP.Defaults, savedESP)
    ESP:SetConfig(init)
    pcall(function() ESP:Init() end)
end

_saveCb = function() saveConfig(Aimbot, ESP) end

local function pickOpt(opt)
    if type(opt) == "table" then return opt[1] end
    return opt
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: AIMBOT
-- ═══════════════════════════════════════════════════════════════
if Aimbot then
    local C = CONFIG.Aimbot
    local T = Window:CreateTab(C.Labels.Tab, 4483362458)

    T:CreateSection(C.Labels.SectionMain)
    T:CreateToggle({
        Name = C.Labels.Enable,
        CurrentValue = (savedAim.Enabled ~= nil) and savedAim.Enabled or C.Defaults.Enabled,
        Flag = C.Flags.Enabled,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ Enabled = v })
        end),
    })

    T:CreateSection(C.Labels.SectionMode)
    T:CreateDropdown({
        Name = C.Labels.Mode,
        Options = C.Options.Mode,
        CurrentOption = { (savedAim.FOVMode ~= nil) and savedAim.FOVMode or C.Defaults.FOVMode },
        MultipleOptions = false,
        Flag = C.Flags.Mode,
        Callback = safeFn(function(opt)
            Aimbot:SetConfig({ FOVMode = pickOpt(opt) })
        end),
    })
    T:CreateSlider({
        Name = C.Labels.FOVRadius,
        Range = { 20, 1000 }, Increment = 10, Suffix = "px",
        CurrentValue = (savedAim.FOVRadius ~= nil) and savedAim.FOVRadius or C.Defaults.FOVRadius,
        Flag = C.Flags.FOVRadius,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ FOVRadius = v })
        end),
    })

    T:CreateSection(C.Labels.SectionTarget)
    T:CreateDropdown({
        Name = C.Labels.AimPart,
        Options = C.Options.AimPart,
        CurrentOption = { (savedAim.AimPart ~= nil) and savedAim.AimPart or C.Defaults.AimPart },
        MultipleOptions = false,
        Flag = C.Flags.AimPart,
        Callback = safeFn(function(opt)
            Aimbot:SetConfig({ AimPart = pickOpt(opt) })
        end),
    })
    T:CreateDropdown({
        Name = C.Labels.Priority,
        Options = C.Options.Priority,
        CurrentOption = { (savedAim.Priority ~= nil) and savedAim.Priority or C.Defaults.Priority },
        MultipleOptions = false,
        Flag = C.Flags.Priority,
        Callback = safeFn(function(opt)
            Aimbot:SetConfig({ Priority = pickOpt(opt) })
        end),
    })

    T:CreateSection(C.Labels.SectionStrength)
    T:CreateDropdown({
        Name = C.Labels.Strength,
        Options = C.Options.Strength,
        CurrentOption = { (savedAim.Strength ~= nil) and savedAim.Strength or C.Defaults.Strength },
        MultipleOptions = false,
        Flag = C.Flags.Strength,
        Callback = safeFn(function(opt)
            Aimbot:SetConfig({ Strength = pickOpt(opt) })
        end),
    })
    T:CreateSlider({
        Name = C.Labels.Smoothness,
        Range = { 0.02, 1 }, Increment = 0.01, Suffix = "",
        CurrentValue = (savedAim.Smoothness ~= nil) and savedAim.Smoothness or C.Defaults.Smoothness,
        Flag = C.Flags.Smoothness,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ Smoothness = v })
        end),
    })
    T:CreateSlider({
        Name = C.Labels.MaxDistance,
        Range = { 50, 5000 }, Increment = 50, Suffix = "m",
        CurrentValue = (savedAim.MaxDistance ~= nil) and savedAim.MaxDistance or C.Defaults.MaxDistance,
        Flag = C.Flags.MaxDistance,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ MaxDistance = v })
        end),
    })

    T:CreateSection(C.Labels.SectionMisc)
    T:CreateToggle({
        Name = C.Labels.TeamCheck,
        CurrentValue = (savedAim.TeamCheck ~= nil) and savedAim.TeamCheck or C.Defaults.TeamCheck,
        Flag = C.Flags.TeamCheck,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ TeamCheck = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.WallCheck,
        CurrentValue = (savedAim.WallCheck ~= nil) and savedAim.WallCheck or C.Defaults.WallCheck,
        Flag = C.Flags.WallCheck,
        Callback = safeFn(function(v)
            Aimbot:SetConfig({ WallCheck = v })
        end),
    })
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: ESP
-- ═══════════════════════════════════════════════════════════════
if ESP then
    local C = CONFIG.ESP
    local T = Window:CreateTab(C.Labels.Tab, 4483362458)

    T:CreateSection(C.Labels.SectionMain)
    T:CreateToggle({
        Name = C.Labels.Enable,
        CurrentValue = (savedESP.Enabled ~= nil) and savedESP.Enabled or C.Defaults.Enabled,
        Flag = C.Flags.Enabled,
        Callback = safeFn(function(v)
            ESP:SetConfig({ Enabled = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.ShowNames,
        CurrentValue = (savedESP.ShowNames ~= nil) and savedESP.ShowNames or C.Defaults.ShowNames,
        Flag = C.Flags.ShowNames,
        Callback = safeFn(function(v)
            ESP:SetConfig({ ShowNames = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.ShowHPBar,
        CurrentValue = (savedESP.ShowHPBar ~= nil) and savedESP.ShowHPBar or C.Defaults.ShowHPBar,
        Flag = C.Flags.ShowHPBar,
        Callback = safeFn(function(v)
            ESP:SetConfig({ ShowHPBar = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.ShowDistance,
        CurrentValue = (savedESP.ShowDistance ~= nil) and savedESP.ShowDistance or C.Defaults.ShowDistance,
        Flag = C.Flags.ShowDistance,
        Callback = safeFn(function(v)
            ESP:SetConfig({ ShowDistance = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.ShowChams,
        CurrentValue = (savedESP.ShowChams ~= nil) and savedESP.ShowChams or C.Defaults.ShowChams,
        Flag = C.Flags.ShowChams,
        Callback = safeFn(function(v)
            ESP:SetConfig({ ShowChams = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.ShowTracer,
        CurrentValue = (savedESP.ShowTracer ~= nil) and savedESP.ShowTracer or C.Defaults.ShowTracer,
        Flag = C.Flags.ShowTracer,
        Callback = safeFn(function(v)
            ESP:SetConfig({ ShowTracer = v })
        end),
    })
    T:CreateToggle({
        Name = C.Labels.TeamCheck,
        CurrentValue = (savedESP.TeamCheck ~= nil) and savedESP.TeamCheck or C.Defaults.TeamCheck,
        Flag = C.Flags.TeamCheck,
        Callback = safeFn(function(v)
            ESP:SetConfig({ TeamCheck = v })
        end),
    })

    T:CreateSection(C.Labels.SectionValues)
    T:CreateSlider({
        Name = C.Labels.MaxDistance,
        Range = { 50, 5000 }, Increment = 50, Suffix = "m",
        CurrentValue = (savedESP.MaxDistance ~= nil) and savedESP.MaxDistance or C.Defaults.MaxDistance,
        Flag = C.Flags.MaxDistance,
        Callback = safeFn(function(v)
            ESP:SetConfig({ MaxDistance = v })
        end),
    })
end

-- ═══════════════════════════════════════════════════════════════
-- TAB: MISC (config only)
-- ═══════════════════════════════════════════════════════════════
local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateSection("Config")
MiscTab:CreateButton({
    Name = "Save Config Now",
    Callback = safeFn(function()
        saveConfig(Aimbot, ESP)
    end),
})
MiscTab:CreateButton({
    Name = "Reset Config",
    Callback = safeFn(function()
        if type(delfile) == "function" and isfile(CONFIG.ConfigFile) then
            pcall(delfile, CONFIG.ConfigFile)
        end
    end),
})

pcall(function()
    local s = {}
    if Aimbot then table.insert(s, "Aim:OK") else table.insert(s, "Aim:X") end
    if ESP    then table.insert(s, "ESP:OK") else table.insert(s, "ESP:X") end
    Rayfield:Notify({
        Title = "Loaded",
        Content = table.concat(s, " | "),
        Duration = 5,
    })
end)
