--[[
    MODULE: AutoFire v7 (NATIVE GAME FEATURE)
    Memanfaatkan fitur AutoShoot bawaan game dari Settings > Mobile.
    Jauh lebih aman dan sinkron dengan server.
]]

local AutoFire = {}
AutoFire.Config = {
    Enabled = false,
}

local Players     = game:GetService("Players")
local VIM         = game:GetService("VirtualInputManager")
local LP          = Players.LocalPlayer

local log = function() end

-- ─── LOGIKA TAP UI BAWAAN GAME ───────────────────────────────
local function tapButton(btn)
    if not btn then return false end
    local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
    pcall(function()
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, 1, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, 1, game, 0)
    end)
    return true
end

local function enableNativeAutoShoot()
    local PG = LP:FindFirstChild("PlayerGui")
    if not PG then return end
    
    local SettingsGui = PG:FindFirstChild("SettingsGui")
    if not SettingsGui then
        log("ERR", "SettingsGui tidak ditemukan. Pastikan sudah masuk game.")
        return
    end

    -- Buka tab MOBILE
    local TabTouch = SettingsGui.Settings.Tabs:FindFirstChild("Tab_Touch")
    if TabTouch then
        log("INFO", "Membuka tab Mobile...")
        tapButton(TabTouch)
        task.wait(0.2)
    end

    -- Scroll ke bawah
    local SF = SettingsGui.Settings.ScrollingFrame
    if SF then
        SF.CanvasPosition = Vector2.new(0, SF.AbsoluteCanvasSize.Y)
        task.wait(0.2)
    end

    -- Aktifkan AutoShoot
    local AutoShootBtn = SF and SF:FindFirstChild("AutoShoot_Touch")
    if AutoShootBtn and AutoShootBtn:FindFirstChild("ContentFrame") then
        local Btn = AutoShootBtn.ContentFrame:FindFirstChild("Button_AutoShoot")
        if Btn then
            log("INFO", "Mengaktifkan Native AutoShoot...")
            tapButton(Btn)
            task.wait(0.2)
        end
    else
        log("WARN", "Tombol AutoShoot tidak ditemukan di menu.")
    end

    -- Opsional: Aktifkan AimAssist bawaan game (bisa dimatikan jika bentrok dengan Aimbot kita)
    local AimAssistBtn = SF and SF:FindFirstChild("AimAssist_Touch")
    if AimAssistBtn and AimAssistBtn:FindFirstChild("ContentFrame") then
        local Btn = AimAssistBtn.ContentFrame:FindFirstChild("Button_AimAssist")
        if Btn then
            -- Karena kita punya Aimbot sendiri, kita matikan AimAssist bawaan game
            -- Agar tidak tarik-tarikan dengan kamera kita
            -- tapButton(Btn) 
            log("INFO", "Melewati AimAssist bawaan (menggunakan Aimbot sendiri).")
        end
    end

    -- Tutup menu settings kembali (opsional)
    local CloseSettings = SettingsGui.Settings:FindFirstChild("ResetButton") -- atau tombol close
    -- tapButton(CloseSettings) 
    
    log("OK", "Native AutoShoot berhasil diaktifkan via UI!")
end

-- ─── PUBLIC API ──────────────────────────────────────────────
function AutoFire:Init()
    log("INFO", "AutoFire v7 (Native) Started.")
    -- Tidak butuh loop RenderStepped karena game yang akan nembak
end

function AutoFire:SetLogger(fn) log = fn end
function AutoFire:SetAimbotLock(_) end
function AutoFire:SetShotDebug(_) end

function AutoFire:SetConfig(cfg)
    for k, v in pairs(cfg) do
        if self.Config[k] ~= nil then self.Config[k] = v end
    end
    
    -- Jika user menekan toggle "Auto Fire" di Rayfield
    if cfg.Enabled ~= nil then
        if cfg.Enabled then
            task.spawn(function()
                -- Beri jeda sedikit agar UI sudah siap
                task.wait(1)
                enableNativeAutoShoot()
            end)
        else
            log("INFO", "Native AutoShoot dimatikan di menu (Silakan matikan manual jika perlu).")
        end
    end
end

function AutoFire:TestMethods()
    log("TEST", "Mencoba mengaktifkan Native AutoShoot...")
    enableNativeAutoShoot()
end

function AutoFire:Destroy()
    -- Tidak ada loop yang perlu dihentikan
end

return AutoFire
