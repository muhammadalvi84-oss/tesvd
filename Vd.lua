-- ==============================================
-- 🔰 AlviHub — Dibuat Khusus untuk Delta
-- ==============================================

-- Layanan Inti
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local CurrentCamera = Workspace.CurrentCamera

-- ==============================================
-- ⚙️ Pengaturan Fitur
-- ==============================================
local Settings = {
    AntiAFK = true,
    Noclip = false,
    InfiniteJump = false,
    SpeedBoost = false,
    SpeedValue = 0.03,
    FullBright = false,
    NoFog = false,
    NoShadow = false,
    AutoHeal = false,
    NoSlowdown = false,
    FleeKiller = false,
    FleeRange = 40,
    AutoEscape = false
}

local NoclipConn = nil
local FleeCooldown = 0

-- ==============================================
-- 🛡️ Fungsi Bantuan
-- ==============================================
local function getLocalRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getLocalHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getDistance(targetPos)
    local root = getLocalRoot()
    if not root then return 1e9 end
    return (targetPos - root.Position).Magnitude
end

local function isTeamKiller(player)
    return player.Team and player.Team.Name == "Killer"
end

local function getNearestKiller()
    local root = getLocalRoot()
    if not root then return nil, 1e9 end
    local nearest, dist = nil, 1e9
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isTeamKiller(p) and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = p
                end
            end
        end
    end
    return nearest, dist
end

-- ==============================================
-- 🔄 Anti AFK
-- ==============================================
task.spawn(function()
    while task.wait(45) do
        if Settings.AntiAFK then
            pcall(function()
                game:GetService("VirtualUser"):Button2Down(Vector2.new(), CurrentCamera.CFrame)
                task.wait(0.15)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(), CurrentCamera.CFrame)
            end)
        end
    end
end)

-- ==============================================
-- 🚀 Noclip
-- ==============================================
RunService.Heartbeat:Connect(function()
    if not Settings.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

-- ==============================================
-- ⬆️ Infinite Jump
-- ==============================================
UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump then
        local hum = getLocalHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ==============================================
-- ⚡ Speed Boost & No Slowdown
-- ==============================================
RunService.RenderStepped:Connect(function()
    local root = getLocalRoot()
    local hum = getLocalHumanoid()
    if not root or not hum then return end

    if Settings.SpeedBoost and hum.MoveDirection.Magnitude > 0 then
        root.CFrame = root.CFrame + hum.MoveDirection * Settings.SpeedValue
    end

    if Settings.NoSlowdown then
        hum.WalkSpeed = math.max(hum.WalkSpeed, 16)
    end
end)

-- ==============================================
-- 💡 Pencahayaan
-- ==============================================
local function updateLighting()
    if Settings.FullBright then
        Lighting.Brightness = 5
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end
    if Settings.NoFog then
        Lighting.FogEnd = 100000
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then atmo.Density = 0 end
    end
    Lighting.GlobalShadows = not Settings.NoShadow
end

-- ==============================================
-- ❤️ Auto Heal
-- ==============================================
task.spawn(function()
    while task.wait(3) do
        if not Settings.AutoHeal then continue end
        local root = getLocalRoot()
        local hum = getLocalHumanoid()
        if hum and root and hum.Health < hum.MaxHealth then
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                if remotes and remotes.Healing and remotes.Healing.HealEvent then
                    remotes.Healing.HealEvent:FireServer(root, true)
                end
            end)
        end
    end
end)

-- ==============================================
-- 🏃 Lari Otomatis dari Killer
-- ==============================================
task.spawn(function()
    while task.wait(0.5) do
        if not Settings.FleeKiller then continue end
        local root = getLocalRoot()
        local killer, dist = getNearestKiller()
        if killer and dist <= Settings.FleeRange and os.clock() - FleeCooldown > 3 then
            local kr = killer.Character and killer.Character:FindFirstChild("HumanoidRootPart")
            if kr then
                root.CFrame = CFrame.new(root.Position + (root.Position - kr.Position).Unit * 70)
                FleeCooldown = os.clock()
            end
        end
    end
end)

-- ==============================================
-- 🚪 Teleport ke Exit
-- ==============================================
local function goToExit()
    local root = getLocalRoot()
    local map = Workspace:FindFirstChild("Map")
    if not root or not map then return false end
    local exitPos = nil
    for _, obj in ipairs(map:GetDescendants()) do
        local n = string.lower(obj.Name)
        if n == "finishline" or n == "exit" or string.find(n, "finish") then
            if obj:IsA("BasePart") then
                exitPos = obj.Position
                break
            elseif obj:IsA("Model") then
                local p = obj:FindFirstChildWhichIsA("BasePart")
                if p then exitPos = p.Position break end
            end
        end
    end
    if exitPos then
        root.CFrame = CFrame.new(exitPos + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

-- ==============================================
-- 🔁 Ganti Server
-- ==============================================
local function changeServer()
    local ok, res = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=30")
    end)
    if not ok or not res then return end
    local data = HttpService:JSONDecode(res)
    local list = data and data.data or {}
    local valid = {}
    for _, s in ipairs(list) do
        if s.id and s.id ~= game.JobId then
            table.insert(valid, s.id)
        end
    end
    if #valid > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, valid[math.random(#valid)], LocalPlayer)
    end
end

-- ==============================================
-- 🎨 Antarmuka Menu
-- ==============================================
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/Main.lua"))()
local UI = Lib:CreateWindow({
    Title = "🔰 AlviHub",
    Center = true,
    AutoShow = true
})

local TabUtama = UI:AddTab("Utama", "home")
local TabPemain = UI:AddTab("Pemain", "user")
local TabDunia = UI:AddTab("Dunia", "globe")
local TabLainnya = UI:AddTab("Lainnya", "settings")

-- Tab Utama
TabUtama:AddToggle("AntiAFK", {
    Text = "Anti AFK",
    Default = true,
    Callback = function(s) Settings.AntiAFK = s end
})
TabUtama:AddToggle("Noclip", {
    Text = "Tembus Dinding",
    Callback = function(s) Settings.Noclip = s end
})
TabUtama:AddToggle("InfiniteJump", {
    Text = "Lompat Tanpa Batas",
    Callback = function(s) Settings.InfiniteJump = s end
})
TabUtama:AddToggle("SpeedBoost", {
    Text = "Kecepatan Tambahan",
    Callback = function(s) Settings.SpeedBoost = s end
})
TabUtama:AddSlider("SpeedValue", {
    Text = "Nilai Kecepatan",
    Min = 0.01,
    Max = 0.5,
    Default = 0.03,
    Rounding = 2,
    Callback = function(v) Settings.SpeedValue = v end
})

-- Tab Pemain
TabPemain:AddToggle("AutoHeal", {
    Text = "Penyembuhan Otomatis",
    Callback = function(s) Settings.AutoHeal = s end
})
TabPemain:AddToggle("NoSlowdown", {
    Text = "Tidak Melambat",
    Callback = function(s) Settings.NoSlowdown = s end
})
TabPemain:AddToggle("FleeKiller", {
    Text = "Lari Otomatis dari Musuh",
    Callback = function(s) Settings.FleeKiller = s end
})
TabPemain:AddSlider("FleeRange", {
    Text = "Jarak Pemicu Lari",
    Min = 15,
    Max = 80,
    Default = 40,
    Callback = function(v) Settings.FleeRange = v end
})

-- Tab Dunia
TabDunia:AddToggle("FullBright", {
    Text = "Layar Lebih Terang",
    Callback = function(s) Settings.FullBright = s updateLighting() end
})
TabDunia:AddToggle("NoFog", {
    Text = "Hapus Kabut",
    Callback = function(s) Settings.NoFog = s updateLighting() end
})
TabDunia:AddToggle("NoShadow", {
    Text = "Hapus Bayangan",
    Callback = function(s) Settings.NoShadow = s updateLighting() end
})
TabDunia:AddButton({
    Text = "Teleport ke Pintu Keluar",
    Callback = function()
        local ok = goToExit()
        Lib:Notify(ok and "Berhasil" or "Gagal", ok and "Berpindah ke pintu keluar!" or "Tidak ditemukan posisi keluar.", 4)
    end
})

-- Tab Lainnya
TabLainnya:AddButton({
    Text = "Cari Server Baru",
    Callback = function()
        Lib:Notify("Memproses", "Sedang mencari server lain...", 3)
        changeServer()
    end
})
TabLainnya:AddLabel("AlviHub © 2026 — Dibuat untuk Delta")

-- ==============================================
-- ✅ Selesai Dimuat
-- ==============================================
Lib:Notify("AlviHub", "Berhasil dimuat! 🎉", 5)
