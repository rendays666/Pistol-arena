--[[
    RENRENHUB CENTAURA — MAIN LOADER (Rayfield)
    
    Struktur:
      main.lua              -> file ini (UI + module loader)
      modules/aimbot.lua    -> aimbot logic (auto-contained)
      modules/esp.lua       -> ESP logic (auto-contained)
    
    Cara nambah fitur baru nanti:
      1. Buat /modules/fiturbaru.lua (ikuti pola Init/SetConfig/Destroy)
      2. Di sini: local FiturBaru = loadModule("fiturbaru")
      3. Bikin tab: createTab("Fitur Baru", ...)
]]

-- ═══════════════════════════════════════════════════════════════
-- EDIT URL INI sesuai repo GitHub kamu
-- ═══════════════════════════════════════════════════════════════
local MODULES_URL = "https://raw.githubusercontent.com/USERNAME/REPO/main/modules/"
-- ═══════════════════════════════════════════════════════════════

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ─── MODULE LOADER ─────────────────────────────────────────────
local function loadModule(name)
    local url = MODULES_URL .. name .. ".lua"
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if not ok then
        warn("[MODULES] Failed to load '" .. name .. "': " .. tostring(result))
        return nil
    end
    warn("[MODULES] Loaded: " .. name)
    return result
end

-- ─── WINDOW ────────────────────────────────────────────────────
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

-- ─── LOAD MODULES ──────────────────────────────────────────────
local Aimbot = loadModule("aimbot")
local ESP    = loadModule("esp")

-- ─── TAB: AIMBOT ───────────────────────────────────────────────
if Aimbot then
    Aimbot:Init()
    local AimTab = Window:CreateTab("Aimbot", 4483362458)

    AimTab:CreateSection("Auto Aim")
    AimTab:CreateToggle({
        Name = "Enable Aimbot",
        CurrentValue = false,
        Flag = "Aim_Enabled",
        Callback = function(v) Aimbot:SetConfig({ Enabled = v }) end,
    })
    AimTab:CreateToggle({
        Name = "FOV Circle",
        CurrentValue = true,
        Flag = "Aim_FOV",
        Callback = function(v) Aimbot:SetConfig({ FOVEnabled = v }) end,
    })

    AimTab:CreateSection("Target")
    AimTab:CreateDropdown({
        Name = "Strength",
        Options = { "Smooth", "Medium", "Strong" },
        CurrentOption = { "Smooth" },
        MultipleOptions = false,
        Flag = "Aim_Strength",
        Callback = function(opt)
            if type(opt) == "table" then opt = opt[1] end
            Aimbot:SetConfig({ Strength = opt })
        end,
    })
    AimTab:CreateDropdown({
        Name = "Priority",
        Options = { "Nearest", "Lowest HP" },
        CurrentOption = { "Nearest" },
        MultipleOptions = false,
        Flag = "Aim_Priority",
        Callback = function(opt)
            if type(opt) == "table" then opt = opt[1] end
            Aimbot:SetConfig({ Priority = opt })
        end,
    })
    AimTab:CreateDropdown({
        Name = "Aim Part",
        Options = { "Head", "Body" },
        CurrentOption = { "Head" },
        MultipleOptions = false,
        Flag = "Aim_Part",
        Callback = function(opt)
            if type(opt) == "table" then opt = opt[1] end
            Aimbot:SetConfig({ AimPart = opt })
        end,
    })

    AimTab:CreateSection("Values")
    AimTab:CreateSlider({
        Name = "Smoothness",
        Range = { 0.02, 1 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = 0.20,
        Flag = "Aim_Smoothness",
        Callback = function(v) Aimbot:SetConfig({ Smoothness = v }) end,
    })
    AimTab:CreateSlider({
        Name = "FOV Radius",
        Range = { 20, 1000 },
        Increment = 10,
        Suffix = "px",
        CurrentValue = 150,
        Flag = "Aim_FOVRadius",
        Callback = function(v) Aimbot:SetConfig({ FOVRadius = v }) end,
    })
    AimTab:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = 250,
        Flag = "Aim_MaxDist",
        Callback = function(v) Aimbot:SetConfig({ MaxDistance = v }) end,
    })
end

-- ─── TAB: ESP ──────────────────────────────────────────────────
if ESP then
    ESP:Init()
    local ESPTab = Window:CreateTab("ESP", 4483362458)

    ESPTab:CreateSection("Player ESP")
    ESPTab:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = false,
        Flag = "ESP_Enabled",
        Callback = function(v) ESP:SetConfig({ Enabled = v }) end,
    })
    ESPTab:CreateToggle({
        Name = "Show Names",
        CurrentValue = true,
        Flag = "ESP_Names",
        Callback = function(v) ESP:SetConfig({ ShowNames = v }) end,
    })
    ESPTab:CreateToggle({
        Name = "Show HP",
        CurrentValue = true,
        Flag = "ESP_HP",
        Callback = function(v) ESP:SetConfig({ ShowHP = v }) end,
    })
    ESPTab:CreateToggle({
        Name = "Show Distance",
        CurrentValue = true,
        Flag = "ESP_Dist",
        Callback = function(v) ESP:SetConfig({ ShowDistance = v }) end,
    })

    ESPTab:CreateSection("Values")
    ESPTab:CreateSlider({
        Name = "Max Distance",
        Range = { 50, 5000 },
        Increment = 50,
        Suffix = "m",
        CurrentValue = 250,
        Flag = "ESP_MaxDist",
        Callback = function(v) ESP:SetConfig({ MaxDistance = v }) end,
    })
end

-- ─── TAB: MISC / CLEANUP ───────────────────────────────────────
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Cleanup")
MiscTab:CreateButton({
    Name = "Destroy All Modules",
    Callback = function()
        if Aimbot then Aimbot:Destroy() end
        if ESP    then ESP:Destroy()    end
        Rayfield:Notify({
            Title = "Cleanup",
            Content = "Semua module di-destroy. Re-run script untuk pakai lagi.",
            Duration = 4,
        })
    end,
})

-- ─── READY NOTIFICATION ────────────────────────────────────────
Rayfield:Notify({
    Title = "Loaded",
    Content = string.format("Aimbot: %s | ESP: %s",
        Aimbot and "OK" or "FAIL",
        ESP and "OK" or "FAIL"),
    Duration = 5,
})
