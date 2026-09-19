-- =================================================================
--        DAYBREAK ALT CONTROL - CELESTIAL STARLIGHT NOIR
--                   DEVELOPED BY DAYBREAK
--              DISCORD: discord.gg/ws5Zb2EzYA
--     CUSTOM STARLIGHT LOGO | DUAL-TAB RAM DASHBOARD
--     CO-HOST SYSTEM | SMART FORMATIONS | LIVE VFX SUITE
-- =================================================================

----------------------------------------------------------------
-- 1. SETTINGS & CONFIGURATION
----------------------------------------------------------------
local _userSettings = getgenv().Settings or {}

getgenv().Settings = {
    prefix = _userSettings.prefix or "!",
    mainAccount = _userSettings.mainAccount or "DayyBreak66",
    altAccounts = _userSettings.altAccounts or {
        ["alt1"] = true,
        ["alt2"] = true,
    },
    whitelistedUsers = _userSettings.whitelistedUsers or {},
    autoReconnect = (_userSettings.autoReconnect ~= nil) and _userSettings.autoReconnect or true,
    reconnectDelay = _userSettings.reconnectDelay or 5,
    antiAfk = (_userSettings.antiAfk ~= nil) and _userSettings.antiAfk or true,
    fpsCap = _userSettings.fpsCap or 60,
    lowGraphicsOnStart = (_userSettings.lowGraphicsOnStart ~= nil) and _userSettings.lowGraphicsOnStart or false,
    passcode = _userSettings.passcode or "",
    uiKeybind = _userSettings.uiKeybind or Enum.KeyCode.RightControl,
    theme = _userSettings.theme or "CelestialNoir",
    customDisplayName = _userSettings.customDisplayName or "[DayBreak]",
    autoAcceptParty = (_userSettings.autoAcceptParty ~= nil) and _userSettings.autoAcceptParty or true,
}
----------------------------------------------------------------
-- 0. RE-EXECUTION CLEANUP
----------------------------------------------------------------
if _G.DayBreakCleanup then
    pcall(_G.DayBreakCleanup)
    task.wait(0.3)
end
_G.DayBreakActive     = true
_G.DayBreakVersion    = "3.1"
_G.DayBreakConnections = {}

getgenv().TrackConnection = function(conn)
    if conn then table.insert(_G.DayBreakConnections, conn) end
    return conn
end

----------------------------------------------------------------
-- 0b. BOT POSITION PERSISTENCE
-- Reads saved position from workspace file on startup.
-- Live in-server counter still adjusts dynamically.
----------------------------------------------------------------
_G.SavedBotPosition = nil
do
    local posFile = "DayBreakPos_" .. game:GetService("Players").LocalPlayer.Name .. ".txt"
    pcall(function()
        local data = readfile(posFile)
        if data and tonumber(data) then
            _G.SavedBotPosition = tonumber(data)
        end
    end)
end

----------------------------------------------------------------
-- 2. SERVICES & CO-HOST INITIALIZATION
----------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local TextChatService   = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local GuiService        = game:GetService("GuiService")
local SoundService      = game:GetService("SoundService")

local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

getgenv().CoHosts = getgenv().CoHosts or {}
getgenv().ManualWhitelist = getgenv().ManualWhitelist or {}

local _lpNameLower = LocalPlayer.Name:lower()
local _mainAccSetting = (getgenv().Settings and getgenv().Settings.mainAccount or ""):lower()

-- Permanent Creator / Developer Whitelist
local _isPrimaryCreator = (_lpNameLower == "daybreak" or _lpNameLower == "dayybreak66" or _lpNameLower == "haylees_ekitty" or _lpNameLower == "xomqhayleealt")

local isMainAccount = false
local isAltAccount = false

if _lpNameLower == _mainAccSetting and _mainAccSetting ~= "" and _mainAccSetting ~= "your_main_account_username" then
    isMainAccount = true
    isAltAccount = false
elseif (_mainAccSetting == "your_main_account_username" or _mainAccSetting == "") and _isPrimaryCreator then
    isMainAccount = true
    isAltAccount = false
else
    isMainAccount = false
    isAltAccount = true
end

-- If running as Alt Bot, broadcast bot attributes immediately
if isAltAccount then
    pcall(function()
        LocalPlayer:SetAttribute("DayBreakBot", true)
        LocalPlayer:SetAttribute("DayBreakRAM", "Online")
    end)
end

----------------------------------------------------------------
-- 3. DYNAMIC BOT INDEXING & DETECTION
----------------------------------------------------------------
local function IsBotPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    local name = plr.Name:lower()
    local mainName = (getgenv().Settings and getgenv().Settings.mainAccount or ""):lower()
    if name == mainName and mainName ~= "" then return false end
    if name == "daybreak" or name == "dayybreak66" or name == "haylees_ekitty" or name == "xomqhayleealt" then return false end
    if getgenv().CoHosts and getgenv().CoHosts[name] then return false end
    if plr:GetAttribute("DayBreakBot") or plr:GetAttribute("DayBreakRAM") then return true end
    if getgenv().Settings and getgenv().Settings.altAccounts and getgenv().Settings.altAccounts[name] then return true end
    return false
end

local _bc = { list = {}, map = {}, total = 0, lastUpdate = 0 }

local function RefreshBotCache()
    local now = tick()
    if now - _bc.lastUpdate < 1 then return end
    _bc.lastUpdate = now
    local online = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local nl = p.Name:lower()
        if IsBotPlayer(p) or (p == LocalPlayer and isAltAccount) then
            table.insert(online, nl)
        end
    end
    table.sort(online)
    local m = {}
    for i, n in ipairs(online) do m[n] = i end
    _bc.list, _bc.map, _bc.total = online, m, #online
end

local function MyIndex()
    RefreshBotCache()
    return _bc.map[LocalPlayer.Name:lower()] or 1
end

local function SafeIndex()
    local idx = MyIndex()
    return (type(idx) == "number" and idx > 0) and idx or 1
end

local function GetOnlineBotNames()
    RefreshBotCache()
    return _bc.list
end

local function IsWhitelisted(name)
    if not name then return false end
    local nl = name:lower()
    if nl == "daybreak" or nl == "dayybreak66" or nl == "haylees_ekitty" or nl == "xomqhayleealt" then return true end
    if getgenv().Settings and getgenv().Settings.mainAccount and nl == getgenv().Settings.mainAccount:lower() then return true end
    if getgenv().ManualWhitelist and getgenv().ManualWhitelist[nl] then return true end
    if getgenv().CoHosts and getgenv().CoHosts[nl] then return true end
    return false
end

----------------------------------------------------------------
-- 4. DATA INITIALIZATION
----------------------------------------------------------------
getgenv().ManualWhitelist = getgenv().ManualWhitelist or {
    ["YOUR_MAIN_ACCOUNT_USERNAME"]   = true,
}
getgenv().ManualWhitelist[getgenv().Settings.mainAccount:lower()] = true

----------------------------------------------------------------
-- 5. CHAT DISPATCHER
----------------------------------------------------------------
local function ChatSend(text)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(text) end
        else
            local r = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local s = r and r:FindFirstChild("SayMessageRequest")
            if s then s:FireServer(text, "All") end
        end
    end)
end
ChatWrapper = ChatSend

----------------------------------------------------------------
-- 5b. MIC TOGGLE ENGINE (VIM Hover + Click)
-- Confirmed working: must SendMouseMoveEvent first (hover),
-- then SendMouseButtonEvent (click). React needs hover state.
----------------------------------------------------------------
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")

local function findMicFrame()
    local topBarApp = CoreGui:FindFirstChild("TopBarApp")
    if not topBarApp then return nil end
    for _, desc in ipairs(topBarApp:GetDescendants()) do
        if desc.Name == "toggle_mic_mute" and desc:IsA("Frame") then
            return desc
        end
    end
    return nil
end

local function getMicScreenPos()
    local micFrame = findMicFrame()
    if not micFrame then return nil, nil end
    local absPos = micFrame.AbsolutePosition
    local absSize = micFrame.AbsoluteSize
    local guiInset = GuiService:GetGuiInset()
    local cx = absPos.X + (absSize.X / 2)
    local cy = absPos.Y + (absSize.Y / 2) + guiInset.Y
    if cy < 5 then cy = 20 end
    return cx, cy
end

local function isMicMuted()
    local adi = LocalPlayer:FindFirstChildOfClass("AudioDeviceInput")
    if not adi then return true end
    return not adi.Active
end

local _micToggling = false
local function doMicToggle()
    if _micToggling then return false end
    _micToggling = true
    local cx, cy = getMicScreenPos()
    if not cx then _micToggling = false; return false end
    local wasMuted = isMicMuted()
    pcall(function() VIM:SendMouseMoveEvent(cx, cy, game) end)
    task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0) end)
    task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
    -- Move mouse away to prevent hover sticking
    task.wait(0.05)
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        VIM:SendMouseMoveEvent(vp.X / 2, vp.Y / 2, game)
    end)
    task.wait(0.2)
    local nowMuted = isMicMuted()
    _micToggling = false
    return nowMuted ~= wasMuted
end

local function doMicUnmute()
    -- Retry up to 3 times with 1s gaps
    for attempt = 1, 3 do
        if not isMicMuted() then return end -- Already unmuted
        local micFrame = findMicFrame()
        if not micFrame then
            -- Mic frame not loaded yet, wait and retry
            task.wait(2)
            -- continue
        end
        doMicToggle()
        task.wait(0.5)
        if not isMicMuted() then return end -- Success
        task.wait(1) -- Wait before retry
    end
    warn("[MicToggle] Failed to unmute after 3 attempts")
end


----------------------------------------------------------------
-- 6. TARGET FINDER
----------------------------------------------------------------
local function FindTarget(name, speaker)
    if not name or name == "" then return speaker end
    local nl = name:lower()
    if nl == "me" then return speaker end
    if nl == "random" then
        local p = Players:GetPlayers()
        return #p > 0 and p[math.random(#p)] or nil
    end
    if nl == "all" then return nil end
    for _, v in ipairs(Players:GetPlayers()) do
        if v.Name:lower():sub(1, #name) == nl
        or v.DisplayName:lower():sub(1, #name) == nl then
            return v
        end
    end
    return nil
end

----------------------------------------------------------------
-- 7. ARGUMENT PARSERS
----------------------------------------------------------------
local function ParseSpeedTarget(args, speaker, defaultSpeed)
    local speed, targetName = defaultSpeed, nil
    if args[2] then
        local n = tonumber(args[2])
        if n then speed = n; targetName = args[3]
        else targetName = args[2] end
    end
    return speed, FindTarget(targetName, speaker)
end

local function ParseSpeedRangeTarget(args, speaker, defaultSpeed, defaultRange)
    local speed, range, targetName = defaultSpeed, defaultRange, nil
    if args[2] then
        local n1 = tonumber(args[2])
        if n1 then
            speed = n1
            if args[3] then
                local n2 = tonumber(args[3])
                if n2 then range = n2; targetName = args[4]
                else targetName = args[3] end
            end
        else targetName = args[2] end
    end
    return speed, range, FindTarget(targetName, speaker)
end

local function IsSoloCommand(args)
    return args[2] == nil or args[2] == ""
end

----------------------------------------------------------------
-- 7b. BOT-TARGETING PARSER
-- Checks if args[2] matches "bot<N>" pattern (e.g. bot1, bot3)
-- If so, strips it from args and returns whether THIS bot should execute.
-- Usage: local shouldRun, newArgs = ParseBotTarget(args)
--        if not shouldRun then return end
----------------------------------------------------------------
local function ParseBotTarget(args)
    if not args[2] then return true, args end
    local botMatch = args[2]:lower():match("^bot(%d+)$")
    if botMatch then
        local targetBotNum = tonumber(botMatch)
        local myIdx = SafeIndex()
        -- Build new args with bot specifier removed
        local newArgs = { args[1] }
        for i = 3, #args do
            table.insert(newArgs, args[i])
        end
        if myIdx ~= targetBotNum then
            return false, newArgs -- Not this bot
        end
        return true, newArgs -- This bot should execute
    end
    return true, args -- No bot specifier, all bots execute
end

----------------------------------------------------------------
-- 8. ANTI-AFK
----------------------------------------------------------------
local function InitAntiAFK()
    -- Method 1: Respond to Roblox Idled event
    local afkConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        -- Anti-AFK: Prevented idle kick.
    end)
    getgenv().TrackConnection(afkConn)

    -- Method 2: Periodic heartbeat — proactively simulate input every 60s
    -- Prevents Roblox from ever reaching the idle threshold
    task.spawn(function()
        while _G.DayBreakActive do
            task.wait(60)
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

----------------------------------------------------------------
-- 9. GLOBAL STATE
----------------------------------------------------------------
_G.CurrentCommand  = "None"
_G.ScriptStartTime = tick()

-- Persistent states (NOT cleared by StopAll)
_G.Spamming       = false
_G.CurrentSpamID  = nil
_G.AntiVoidActive = false
_G.AVPlatform     = nil
_G.SpeedLock      = nil
_G.NoclipEnabled  = false
_G.NoclipConn     = nil
_G.NoclipOriginals = {}
_G.LoopCloneActive = false  -- Persistent: only !unloopclone stops it

-- Exclusive states
_G.IsPlaying      = false
_G.MusicQueue     = {}
_G.GrabActive     = false

----------------------------------------------------------------
-- 10. StopAll — ONLY clears exclusive commands
----------------------------------------------------------------
local function StopAll()
    _G.CurrentCommand = "None"
    _G.IsPlaying      = false
    _G.MusicQueue     = {}
    _G.CurrentEmoteCommand = nil
    _G.EmoteDebounce = false
    if _G.EmoteFreezeConn then _G.EmoteFreezeConn:Disconnect(); _G.EmoteFreezeConn = nil end
    -- Clean up tracked emote animation track
    if _G.CurrentEmoteTrack then
        pcall(function() _G.CurrentEmoteTrack:Stop(0) end)
        pcall(function() _G.CurrentEmoteTrack:Destroy() end)
        _G.CurrentEmoteTrack = nil
    end

    if _G.StackPart then
        pcall(function() _G.StackPart:Destroy() end)
        _G.StackPart = nil
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum    = myChar and myChar:FindFirstChild("Humanoid")

    if myRoot then
        myRoot.Velocity    = Vector3.zero
        myRoot.RotVelocity = Vector3.zero
        myRoot.Anchored    = false
    end
    if hum then
        hum.AutoRotate = true
        if not _G.SpeedLock then hum.WalkSpeed = 16 end
        pcall(function()
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, tr in pairs(animator:GetPlayingAnimationTracks()) do 
                    if tr.Priority == Enum.AnimationPriority.Action then
                        tr:Stop(0) 
                    end
                end
            end
        end)
    end
end

----------------------------------------------------------------
-- 11. MASTER CLEANUP
----------------------------------------------------------------
_G.DayBreakCleanup = function()
    _G.DayBreakActive = false
    _G.Spamming = false; _G.CurrentSpamID = nil; _G.AntiVoidActive = false
    _G.SpeedLock = nil; _G.NoclipEnabled = false; _G.LoopCloneActive = false
    if _G.NoclipConn then pcall(function() _G.NoclipConn:Disconnect() end); _G.NoclipConn = nil end
    for p, o in pairs(_G.NoclipOriginals or {}) do
        if p and p.Parent then pcall(function() p.CanCollide = o end) end
    end
    _G.NoclipOriginals = {}
    if _G.AVPlatform then pcall(function() _G.AVPlatform:Destroy() end); _G.AVPlatform = nil end
    StopAll()
    for _, conn in ipairs(_G.DayBreakConnections or {}) do pcall(function() conn:Disconnect() end) end
    _G.DayBreakConnections = {}
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then local g = pg:FindFirstChild("DayBreakCommandGUI"); if g then g:Destroy() end end
    end)
    _G.CurrentCommand = "None"; _G.ScanInProgress = false
    _G.MemoryLock = nil; _G.CPULock = nil; _G.GrabActive = false
end

----------------------------------------------------------------
-- 12. COMMAND TABLE & CO-HOST MANAGEMENT
----------------------------------------------------------------
local Commands = getgenv().Commands or {}
getgenv().Commands = Commands

Commands.addhost = function(args, speaker)
    local _lpName = LocalPlayer.Name:lower()
    local isHost = isMainAccount or _isPrimaryCreator or (getgenv().CoHosts and getgenv().CoHosts[_lpName])
    if not isHost then return end
    local target = FindTarget(args[2], speaker)
    if target then
        local tName = target.Name:lower()
        getgenv().CoHosts[tName] = true
        getgenv().ManualWhitelist[tName] = true
        ChatSend("[DayBreak] Added Co-Host: " .. target.DisplayName .. " (@" .. target.Name .. ")")
        pcall(function() if getgenv().PlaySFX then getgenv().PlaySFX("rbxassetid://6895079853") end end)
    else
        ChatSend("[DayBreak] Co-Host player not found.")
    end
end

Commands.removehost = function(args, speaker)
    local _lpName = LocalPlayer.Name:lower()
    local isHost = isMainAccount or _isPrimaryCreator or (getgenv().CoHosts and getgenv().CoHosts[_lpName])
    if not isHost then return end
    local target = FindTarget(args[2], speaker)
    if target then
        local tName = target.Name:lower()
        getgenv().CoHosts[tName] = nil
        getgenv().ManualWhitelist[tName] = nil
        ChatSend("[DayBreak] Removed Co-Host: " .. target.DisplayName)
    end
end

Commands.hosts = function(args, speaker)
    local list = {}
    for h in pairs(getgenv().CoHosts or {}) do table.insert(list, h) end
    ChatSend("[DayBreak] Active Co-Hosts (" .. #list .. "): " .. (#list > 0 and table.concat(list, ", ") or "None"))
end

-- ═══════════════════════════════════════════════════════════
--  SYSTEM COMMANDS
-- ═══════════════════════════════════════════════════════════
Commands.stop = function(args, speaker) StopAll() end
Commands.unall = Commands.stop

Commands.whitelist = function(args, speaker)
    local t = FindTarget(args[2], speaker)
    if t then
        local ok = pcall(function() getgenv().ManualWhitelist[t.Name:lower()] = true end)
        if SafeIndex() == 1 then
            if ok then ChatSend("Whitelisted " .. t.Name)
            else ChatSend("Whitelist Fail") end
        end
    else
        if SafeIndex() == 1 then ChatSend("Whitelist Fail") end
    end
end

Commands.blacklist = function(args, speaker)
    local t = FindTarget(args[2], speaker)
    if t and t.Name:lower() ~= getgenv().Settings.mainAccount:lower() then
        getgenv().ManualWhitelist[t.Name:lower()] = nil
        if SafeIndex() == 1 then ChatSend("Blacklisted " .. t.Name) end
    end
end

-- ═══════════════════════════════════════════════════════════
--  PERSISTENT: noclip / clip
-- ═══════════════════════════════════════════════════════════
Commands.noclip = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if _G.NoclipEnabled then return end
    _G.NoclipEnabled = true; _G.NoclipOriginals = {}
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then _G.NoclipOriginals[part] = part.CanCollide end
        end
    end
    _G.NoclipConn = RunService.Stepped:Connect(function()
        if not _G.NoclipEnabled then return end
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    if _G.NoclipOriginals[p] == nil then _G.NoclipOriginals[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        end
    end)
    getgenv().TrackConnection(_G.NoclipConn)
end

Commands.clip = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.NoclipEnabled = false
    if _G.NoclipConn then pcall(function() _G.NoclipConn:Disconnect() end); _G.NoclipConn = nil end
    for p, o in pairs(_G.NoclipOriginals or {}) do
        if p and p.Parent then pcall(function() p.CanCollide = o end) end
    end
    _G.NoclipOriginals = {}
end

-- ═══════════════════════════════════════════════════════════
--  PERSISTENT: ws / speed
-- ═══════════════════════════════════════════════════════════
Commands.ws = function(args, speaker)
    local spd = tonumber(args[2])
    if not spd then
        Commands.unws(args, speaker)
        return
    end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then
        if hum.Sit then hum.Sit = false end
        hum.WalkSpeed = spd; _G.SpeedLock = spd
        task.spawn(function()
            local lv = spd
            while _G.SpeedLock == lv do
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                if h and h.WalkSpeed ~= lv then h.WalkSpeed = lv end
                task.wait(0.5)
            end
        end)
    end
end
Commands.speed = Commands.ws

Commands.unws = function(args, speaker)
    _G.SpeedLock = nil
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end
Commands.unspeed = Commands.unws

-- ═══════════════════════════════════════════════════════════
--  PERSISTENT: antivoid / unantivoid
-- ═══════════════════════════════════════════════════════════
Commands.antivoid = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if _G.AntiVoidActive then return end
    _G.AntiVoidActive = true
    local part = Instance.new("Part")
    part.Name = "DayBreakAntiVoid"; part.Size = Vector3.new(2048,1,2048)
    part.Transparency = 1; part.Anchored = true; part.CanCollide = true; part.Parent = workspace
    _G.AVPlatform = part
    task.spawn(function()
        while _G.AntiVoidActive do
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r and _G.AVPlatform then _G.AVPlatform.CFrame = CFrame.new(r.Position.X, 0, r.Position.Z) end
            RunService.Heartbeat:Wait()
        end
        if _G.AVPlatform then pcall(function() _G.AVPlatform:Destroy() end); _G.AVPlatform = nil end
    end)
end

Commands.unantivoid = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.AntiVoidActive = false
    if _G.AVPlatform then pcall(function() _G.AVPlatform:Destroy() end); _G.AVPlatform = nil end
end

-- ═══════════════════════════════════════════════════════════
--  PERSISTENT: spam / unspam
-- ═══════════════════════════════════════════════════════════
Commands.spam = function(args, speaker)
    _G.Spamming = false; task.wait(0.1)
    local delayInput  = tonumber(args[2])
    local customDelay = delayInput or 1.0
    local spamMsg     = delayInput and table.concat(args, " ", 3) or table.concat(args, " ", 2)
    if spamMsg ~= "" then
        _G.Spamming = true; local id = tick(); _G.CurrentSpamID = id
        task.spawn(function()
            while _G.Spamming and _G.CurrentSpamID == id do ChatSend(spamMsg); task.wait(customDelay) end
        end)
    end
end

Commands.unspam = function(args, speaker)
    if not IsSoloCommand(args) then return end

Commands.mimic = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local tp = FindTarget(newArgs[2], speaker)
    if not tp then return end
    
    _G.Mimicking = true
    _G.MimicTarget = tp.Name:lower()
end

Commands.unmimic = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.Mimicking = false
    _G.MimicTarget = nil
end
    _G.Spamming = false; _G.CurrentSpamID = nil
end

-- ═══════════════════════════════════════════════════════════
--  MOVEMENT COMMANDS
-- ═══════════════════════════════════════════════════════════

Commands.circle = function(args, speaker)
    local radius, target = ParseSpeedTarget(args, speaker, nil)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local idx, total = SafeIndex(), SafeTotal()
    radius = radius or math.max(8, total * 1.2)
    local angle  = (idx / total) * (2 * math.pi)
    local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    local tRoot  = target.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tRoot and myRoot then myRoot.CFrame = CFrame.new(tRoot.Position + offset, tRoot.Position) end
end

Commands.loopcircle = function(args, speaker)
    local radiusIn, target = ParseSpeedTarget(args, speaker, nil)
    if not target or not target.Character then return end
    StopAll(); _G.CurrentCommand = "LoopCircle"
    task.spawn(function()
        while _G.CurrentCommand == "LoopCircle" and target and target.Character do
            local idx, total = SafeIndex(), SafeTotal()
            local radius = radiusIn or math.max(8, total * 1.2)
            local angle  = (idx / total) * (2 * math.pi)
            local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            local tRoot  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and myRoot then myRoot.CFrame = CFrame.new(tRoot.Position + offset, tRoot.Position) end
            task.wait()
        end
    end)
end

-- Line formations
local LINE_DIRS = {
    rline = Vector3.new(4,0,0), lline = Vector3.new(-4,0,0),
    fline = Vector3.new(0,0,-4), bline = Vector3.new(0,0,4),
}

local function DoLine(args, speaker, isLoop)
    local cmd = args[1]:lower():sub(#getgenv().Settings.prefix + 1)
    local base = isLoop and cmd:sub(5) or cmd
    local dir = LINE_DIRS[base]; if not dir then return end
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local idx = SafeIndex(); local off = CFrame.new(dir * idx)
    if isLoop then
        StopAll(); _G.CurrentCommand = "LoopLine"
        task.spawn(function()
            while _G.CurrentCommand == "LoopLine" and target and target.Character do
                local tR = target.Character:FindFirstChild("HumanoidRootPart")
                local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if tR and mR then mR.CFrame = tR.CFrame * off; mR.Velocity = Vector3.zero end
                RunService.Heartbeat:Wait()
            end
        end)
    else
        local tR = target.Character:FindFirstChild("HumanoidRootPart")
        local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tR and mR then mR.CFrame = tR.CFrame * off; mR.Velocity = Vector3.zero end
    end
end

for b in pairs(LINE_DIRS) do
    Commands[b] = function(a, s) DoLine(a, s, false) end
    Commands["loop" .. b] = function(a, s) DoLine(a, s, true) end
end

-- Shared emote track cache: prevents memory leak from repeated LoadAnimation
_G.CurrentEmoteTrack = nil
_G.EmoteDebounce = false

local function StopCurrentEmoteTrack()
    if _G.CurrentEmoteTrack then
        pcall(function() _G.CurrentEmoteTrack:Stop(0) end)
        pcall(function() _G.CurrentEmoteTrack:Destroy() end)
        _G.CurrentEmoteTrack = nil
    end
end

local function ClearEmotesOnly()
    _G.CurrentEmoteCommand = nil
    _G.EmoteDebounce = false
    if _G.EmoteFreezeConn then pcall(function() _G.EmoteFreezeConn:Disconnect() end); _G.EmoteFreezeConn = nil end
    StopCurrentEmoteTrack()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local anim = hum:FindFirstChildOfClass("Animator")
        if anim then
            for _, tr in pairs(anim:GetPlayingAnimationTracks()) do
                 if tr.Priority == Enum.AnimationPriority.Action then
                     pcall(function() tr:Stop(0) end)
                 end
            end
        end
    end
end

Commands.unemote = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ClearEmotesOnly()
end

Commands.sync = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    if not _G.DayBreakEmoteCatalog then return end
    
    local query = table.concat(newArgs, " ", 2):lower()
    if query == "" then return end

    local targetId
    for _, e in ipairs(_G.DayBreakEmoteCatalog) do
        local name = tostring(e.name or ""):lower()
        if name:find(query, 1, true) then
            targetId = tonumber(e.id)
            if name == query then break end
        end
    end

    if not targetId then return end

    -- If already emoting, jump first then play new emote
    local wasEmoting = _G.CurrentEmoteCommand ~= nil
    ClearEmotesOnly()
    if wasEmoting then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.Jump = true end
        task.wait(0.3)
    end

    _G.CurrentEmoteCommand = targetId

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local anim = hum:FindFirstChildOfClass("Animator")
    if not anim then return end

    local function playSyncAction()
        if _G.CurrentEmoteCommand ~= targetId then return end
        StopCurrentEmoteTrack()
        local obj = Instance.new("Animation")
        obj.AnimationId = "rbxassetid://" .. targetId
        local ok2, tr = pcall(function() return anim:LoadAnimation(obj) end)
        if ok2 and tr then
            _G.CurrentEmoteTrack = tr
            tr.Priority = Enum.AnimationPriority.Action
            tr.Looped = true
            tr:Play()
            -- Sync Engine: Perfectly align animation phase with server time
            task.spawn(function()
                local waitCount = 0
                while tr.Length == 0 and waitCount < 40 do task.wait(0.05); waitCount = waitCount + 1 end
                if tr.Length > 0 then
                    pcall(function()
                        tr.TimePosition = math.fmod(workspace:GetServerTimeNow(), tr.Length)
                    end)
                end
            end)
        end
    end

    playSyncAction()

    if _G.EmoteFreezeConn then _G.EmoteFreezeConn:Disconnect() end
    local sTarget = tostring(targetId)
    _G.EmoteFreezeConn = anim.AnimationPlayed:Connect(function(atr)
        if _G.CurrentEmoteCommand ~= targetId then 
            if _G.EmoteFreezeConn then _G.EmoteFreezeConn:Disconnect(); _G.EmoteFreezeConn = nil end
            return 
        end
        -- Debounce: prevent recursive feedback loop
        if _G.EmoteDebounce then return end
        if isDancing(char, sTarget) then
            _G.EmoteDebounce = true
            task.wait(0.1)
            if _G.CurrentEmoteCommand == targetId then
                playSyncAction()
            end
            _G.EmoteDebounce = false
        end
    end)
end

Commands.jump = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ClearEmotesOnly()
    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if h then h.Jump = true end
end

Commands.sit = function(args, speaker)
    if not IsSoloCommand(args) then return end
    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if h then h.Sit = true end
end

Commands.wonder = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); _G.CurrentCommand = "Wonder"
    task.spawn(function()
        while _G.CurrentCommand == "Wonder" do
            local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and r then
                if h.Sit then h.Sit = false end
                local rng = Random.new(tick() + SafeIndex())
                h:MoveTo(r.Position + Vector3.new(rng:NextNumber(-30,30), 0, rng:NextNumber(-30,30)))
                local done, t, cn = false, 0, nil
                cn = h.MoveToFinished:Connect(function() done = true end)
                repeat task.wait(0.1); t = t + 0.1 until done or _G.CurrentCommand ~= "Wonder" or t > 10
                if cn then cn:Disconnect() end
            end
            task.wait(math.random(1, 2))
        end
    end)
end

Commands["goto"] = function(args, speaker)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if mR then
        local idx, total = SafeIndex(), SafeTotal()
        local a = (idx / total) * (math.pi * 2)
        mR.CFrame = target.Character.HumanoidRootPart.CFrame
            * CFrame.new(math.cos(a)*6, 0, math.sin(a)*6)
            * CFrame.Angles(0, a + math.pi, 0)
    end
end

-- FOLLOW: walk normally, face AWAY from target only when stopped
Commands.follow = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Follow"
    task.spawn(function()
        while _G.CurrentCommand == "Follow" and target and target.Character do
            local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
            local mR = c and c:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if h and mR and tR then
                if h.Sit then h.Sit = false end
                local idx, total = SafeIndex(), SafeTotal()
                local a = (idx / total) * (math.pi * 2)
                local goal = tR.Position + Vector3.new(math.cos(a)*5, 0, math.sin(a)*5)
                if (mR.Position - goal).Magnitude > 50 then
                    mR.CFrame = CFrame.new(goal, tR.Position)
                else
                    h:MoveTo(goal)
                end
                -- Only face away when close to goal (stopped walking)
                if (mR.Position - goal).Magnitude < 3 then
                    local away = mR.Position - tR.Position
                    if away.Magnitude > 0.1 then
                        local lookAt = mR.Position + Vector3.new(away.X, 0, away.Z).Unit * 10
                        mR.CFrame = CFrame.new(mR.Position, lookAt)
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

Commands.bring = function(args, speaker)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if mR then
        local idx, total = SafeIndex(), SafeTotal()
        local cols = math.ceil(math.sqrt(total))
        local row = math.floor((idx-1)/cols); local col = (idx-1) % cols
        local xOff = (col - (cols-1)/2) * 4; local zOff = (row + 1) * 4
        mR.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(xOff, 0, zOff)
        mR.Velocity = Vector3.zero
    end
end

Commands.rest = function(args, speaker)
    if not IsSoloCommand(args) then return end
    local c = LocalPlayer.Character; if c then c:BreakJoints() end
end

-- WALKTO: face TOWARD target when stopped
Commands.walkto = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "WalkTo"
    task.spawn(function()
        while _G.CurrentCommand == "WalkTo" and target and target.Character do
            local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
            local mR = c and c:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if h and mR and tR then
                if h.Sit then h.Sit = false end
                local idx, total = SafeIndex(), SafeTotal()
                local cols = math.ceil(math.sqrt(total))
                local row = math.floor((idx-1)/cols); local col = (idx-1) % cols
                local xOff = (col - (cols-1)/2) * 5; local zOff = (row + 1) * 5
                local goalPos = (tR.CFrame * CFrame.new(xOff, 0, zOff)).Position
                h:MoveTo(goalPos)
                -- Face toward target
                task.wait(0.1)
                pcall(function()
                    local mR2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local tR2 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                    if mR2 and tR2 then
                        mR2.CFrame = CFrame.new(mR2.Position,
                            Vector3.new(tR2.Position.X, mR2.Position.Y, tR2.Position.Z))
                    end
                end)
            end
            task.wait(0.1)
        end
    end)
end

Commands.stackon = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker); if not target then return end
    local part = Instance.new("Part"); part.Name = "DayBreakStackPlatform"
    part.Size = Vector3.new(4,1,4); part.Transparency = 1; part.Anchored = true
    part.CanCollide = true; part.Parent = workspace; _G.StackPart = part
    _G.CurrentCommand = "Stack"; local hOff = SafeIndex() * 5
    task.spawn(function()
        while _G.CurrentCommand == "Stack" do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if tR and mR then
                local cf = tR.CFrame * CFrame.new(0, hOff, 0)
                part.CFrame = cf; mR.CFrame = cf * CFrame.new(0, 1.5, 0)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            else break end
            RunService.Heartbeat:Wait()
        end
        if _G.StackPart then pcall(function() _G.StackPart:Destroy() end); _G.StackPart = nil end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  CLONE COMMANDS (loopclone is now PERSISTENT)
-- ═══════════════════════════════════════════════════════════
local RS_clone = ReplicatedStorage:FindFirstChild("GrabStatus")
local cloneRemote = ReplicatedStorage:FindFirstChild("event_clone_avatar")
local refreshRemote = ReplicatedStorage:FindFirstChild("event_modify_refresh")

Commands.clone = function(args, speaker)
    local t = FindTarget(args[2], speaker)
    if t and RS_clone and cloneRemote then
        pcall(function() RS_clone:InvokeServer(t.UserId); task.wait(0.1); cloneRemote:FireServer(t.UserId) end)
    end
end

-- PERSISTENT: only !unloopclone stops it
Commands.loopclone = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.LoopCloneActive = true
    task.spawn(function()
        while _G.LoopCloneActive do
            for _, v in ipairs(Players:GetPlayers()) do
                if not _G.LoopCloneActive then break end
                if v ~= LocalPlayer and LocalPlayer:IsFriendsWith(v.UserId) then
                    if RS_clone and cloneRemote then
                        pcall(function() RS_clone:InvokeServer(v.UserId); task.wait(0.1); cloneRemote:FireServer(v.UserId) end)
                    end
                    task.wait(1.5)
                end
            end
            task.wait(2)
        end
    end)
end

Commands.unloopclone = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.LoopCloneActive = false
end

Commands.ref = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if refreshRemote then pcall(function() refreshRemote:FireServer() end) end
end

-- ═══════════════════════════════════════════════════════════
--  WORM
-- ═══════════════════════════════════════════════════════════
Commands.worm = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker); if not target then return end
    _G.CurrentCommand = "Worm"; local idx = SafeIndex()
    task.spawn(function()
        while _G.CurrentCommand == "Worm" do
            local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
            if h and h.Sit then h.Sit = false end
            local bots = GetOnlineBotNames(); local ft
            if idx == 1 then ft = target
            else
                local pn = bots[idx - 1]
                if pn then for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name:lower() == pn then ft = p; break end
                end end
            end
            if h and ft and ft.Character then
                local tR = ft.Character:FindFirstChild("HumanoidRootPart")
                local mR = c and c:FindFirstChild("HumanoidRootPart")
                if tR and mR then
                    if (mR.Position - tR.Position).Magnitude > 4 then h:MoveTo(tR.Position)
                    else h:MoveTo(mR.Position) end
                end
            end
            task.wait(0.1)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  STALK
-- ═══════════════════════════════════════════════════════════
Commands.stalk = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Stalk"
    task.spawn(function()
        while _G.CurrentCommand == "Stalk" and target and target.Character do
            local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
            local mR = c and c:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if h and mR and tR then
                if h.Sit then h.Sit = false end
                local idx = SafeIndex()
                local col = (idx - 1) % 3; local row = math.floor((idx - 1) / 3)
                local behindCF = tR.CFrame * CFrame.new((col-1)*4, 0, (row+1)*4)
                local diff = mR.Position - tR.Position
                if diff.Magnitude > 0.1 then
                    local dot = diff.Unit:Dot(tR.CFrame.LookVector)
                    if dot > 0.3 or tR.Velocity.Magnitude > 100 then
                        mR.CFrame = behindCF; mR.Velocity = Vector3.zero
                    else h:MoveTo(behindCF.Position) end
                else mR.CFrame = behindCF end
                mR.CFrame = CFrame.new(mR.Position, Vector3.new(tR.Position.X, mR.Position.Y, tR.Position.Z))
            end
            task.wait(0.05)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  DANCE & EMOTE (solo-guarded)
-- ═══════════════════════════════════════════════════════════
for _, n in ipairs({"dance1","dance2","dance3"}) do
    Commands[n] = function(args, speaker)
        if not IsSoloCommand(args) then return end
        StopAll()
        local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
        if h then
            if h.Sit then h.Sit = false; task.wait(0.1) end
            ChatSend("/e " .. (n == "dance1" and "dance" or n))
        end
    end
end
Commands.dance = Commands.dance1

for i = 1, 8 do
    Commands["emote" .. i] = function(args, speaker)
        if not IsSoloCommand(args) then return end
        StopAll()
        local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if h and r then
            h.Sit = false; h:MoveTo(r.Position); r.Velocity = Vector3.zero; r.RotVelocity = Vector3.zero
            h.AutoRotate = false; r.Anchored = true; task.wait(0.2); r.Anchored = false
            ChatSend("/e emote" .. i)
            task.spawn(function() task.wait(0.5); if h and h.Parent then h.AutoRotate = true end end)
        end
    end
end

for _, e in ipairs({"laugh","point","cheer"}) do
    Commands[e] = function(args, speaker)
        if not IsSoloCommand(args) then return end
        ChatSend("/e " .. e)
    end
end

-- ═══════════════════════════════════════════════════════════
--  EMOTE SYSTEM (Dynamic Catalog)
-- ═══════════════════════════════════════════════════════════
if not _G.DayBreakEmoteCatalog then
    task.spawn(function()
        pcall(function()
            local HTTP = game:GetService("HttpService")
            local raw = game:HttpGet("https://raw.githubusercontent.com/DayBreakBackend/DayBreakScripts/refs/heads/main/EmoteIDs.lua")
            local result = HTTP:JSONDecode(raw)
            if result and (result.data or type(result) == "table") then
                _G.DayBreakEmoteCatalog = result.data or result
            end
        end)
    end)
end

local function isDancing(character, animIdStr)
    local animate = character:FindFirstChild("Animate")
    if not animate then return true end
    for _, holder in ipairs(animate:GetChildren()) do
        if holder:IsA("StringValue") then
            for _, anim in ipairs(holder:GetChildren()) do
                if anim:IsA("Animation") then
                    local hId = tostring(anim.AnimationId):gsub("http://www%.roblox%.com/asset/%?id=", ""):gsub("rbxassetid://", "")
                    if hId == animIdStr then return false end
                end
            end
        end
    end
    return true
end

-- ===================================================================
--  UGC & CATALOG EMOTE ENGINE (Triple-Fallback Resolver)
-- ===================================================================
local _currentTrack = nil

local function StopCurrentEmoteTrack()
    if _currentTrack then
        pcall(function() _currentTrack:Stop() end)
        _currentTrack = nil
    end
end

local DAYBREAK_EMOTE_CATALOG = {
    { name = "floss", id = 10714340543 },
    { name = "griddy", id = 10714371458 },
    { name = "hype", id = 3695333480 },
    { name = "shrug", id = 3576968024 },
    { name = "salute", id = 3360689775 },
    { name = "tilt", id = 3360686498 },
    { name = "stadium", id = 3360686498 },
    { name = "point", id = 3576823880 },
    { name = "cheer", id = 3576835634 },
    { name = "wave", id = 3576835634 },
    { name = "laugh", id = 3576813728 },
    { name = "dance", id = 10714340543 },
    { name = "dance2", id = 10714371458 },
    { name = "dance3", id = 3695333480 },
}

local function ResolveEmoteAnimation(query)
    if not query or query == "" then return nil end
    local q = query:lower():gsub("%s+", "")
    if q:match("^%d+$") then
        return tonumber(q)
    end
    for _, item in ipairs(DAYBREAK_EMOTE_CATALOG) do
        if item.name:lower():gsub("%s+", ""):find(q, 1, true) then
            return item.id
        end
    end
    return 10714340543 -- Default Floss fallback
end

local function PlayDayBreakEmote(emoteAssetId, customName)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local anim = hum and hum:FindFirstChildOfClass("Animator")

    StopCurrentEmoteTrack()

    local animAssetId = emoteAssetId and ("rbxassetid://" .. tostring(emoteAssetId)) or nil

    -- Method 1: PlayEmoteAsync
    local m1Ok = pcall(function()
        if hum and customName and hum:FindFirstChild("HumanoidDescription") then
            hum:PlayEmote(customName)
            return true
        end
    end)
    if m1Ok then return true end

    -- Method 2: Load Animation directly on Animator
    if anim and animAssetId then
        local ok, track = pcall(function()
            local a = Instance.new("Animation")
            a.AnimationId = animAssetId
            local tr = anim:LoadAnimation(a)
            tr.Priority = Enum.AnimationPriority.Action
            tr.Looped = true
            tr:Play()
            return tr
        end)
        if ok and track then
            _currentTrack = track
            return true
        end
    end

    -- Method 3: Fallback Animation on Humanoid
    if hum and animAssetId then
        local ok, track = pcall(function()
            local a = Instance.new("Animation")
            a.AnimationId = animAssetId
            local tr = hum:LoadAnimation(a)
            tr.Priority = Enum.AnimationPriority.Action
            tr.Looped = true
            tr:Play()
            return tr
        end)
        if ok and track then
            _currentTrack = track
            return true
        end
    end

    return false
end

Commands.sync = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    local query = table.concat(newArgs, " ", 2)
    if not query or query == "" then
        query = "dance"
    end

    local animId = ResolveEmoteAnimation(query)
    local idx = SafeIndex()

    task.spawn(function()
        -- Staggered sync delay
        task.wait((idx - 1) * 0.08)
        PlayDayBreakEmote(animId, query)
    end)
end

Commands.emote = Commands.sync
Commands.unemote = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    StopCurrentEmoteTrack()
    pcall(function()
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then
            for _, t in ipairs(h:GetPlayingAnimationTracks()) do
                t:Stop()
            end
        end
    end)
end


Commands.firework = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll()
    local c = LocalPlayer.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChild("Humanoid"); if not (r and h) then return end
    if h.Sit then h.Sit = false end
    task.spawn(function()
        local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(1e6,1e6,1e6)
        bv.Velocity = Vector3.new(0,75,0); bv.Parent = r
        local ba = Instance.new("BodyAngularVelocity"); ba.MaxTorque = Vector3.new(1e6,1e6,1e6)
        ba.AngularVelocity = Vector3.new(0,60,0); ba.Parent = r
        task.wait(2.5); bv:Destroy(); ba:Destroy()
        r.Velocity = Vector3.new(Random.new():NextNumber(-50,50), Random.new():NextNumber(80,120), Random.new():NextNumber(-50,50))
        c:BreakJoints()
    end)
end

-- ═══════════════════════════════════════════════════════════
--  NUKE
-- ═══════════════════════════════════════════════════════════
Commands.nuke = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    local c = LocalPlayer.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChild("Humanoid")
    if not (target and target.Character and r and h) then return end
    local tR = target.Character:FindFirstChild("HumanoidRootPart"); if not tR then return end
    r.CFrame = tR.CFrame * CFrame.new(0, 15 + SafeIndex()*2, 0)
    if h.Sit then h.Sit = false end; h:MoveTo(r.Position)
    task.spawn(function()
        local ba = Instance.new("BodyAngularVelocity"); ba.MaxTorque = Vector3.new(1e6,1e6,1e6)
        ba.AngularVelocity = Vector3.new(0,150,0); ba.Parent = r; task.wait(0.6); ba:Destroy()
        r.Velocity = Vector3.new(Random.new():NextNumber(-60,60), Random.new():NextNumber(-30,-10), Random.new():NextNumber(-60,60))
        c:BreakJoints()
    end)
end

-- ═══════════════════════════════════════════════════════════
--  SWARM
-- ═══════════════════════════════════════════════════════════
Commands.swarm = function(args, speaker)
    local speed, range, target = ParseSpeedRangeTarget(args, speaker, 40, 18)
    if not target or not target.Character then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "Swarm"
    _G.NoclipEnabled = true; _G.NoclipOriginals = {}
    local char = LocalPlayer.Character
    if char then for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then _G.NoclipOriginals[p] = p.CanCollide end
    end end
    _G.NoclipConn = RunService.Stepped:Connect(function()
        if _G.CurrentCommand ~= "Swarm" then
            _G.NoclipEnabled = false
            if _G.NoclipConn then pcall(function() _G.NoclipConn:Disconnect() end); _G.NoclipConn = nil end
            for p, o in pairs(_G.NoclipOriginals or {}) do if p and p.Parent then pcall(function() p.CanCollide = o end) end end
            _G.NoclipOriginals = {}; return
        end
        local c = LocalPlayer.Character
        if c then for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                if _G.NoclipOriginals[p] == nil then _G.NoclipOriginals[p] = p.CanCollide end
                p.CanCollide = false
            end
        end end
    end)
    getgenv().TrackConnection(_G.NoclipConn)
    task.spawn(function()
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local goal, gt, st = Vector3.zero, 0, 0
        while _G.CurrentCommand == "Swarm" and target and target.Character do
            local tR = target.Character:FindFirstChild("HumanoidRootPart")
            if h and mR and tR then
                if h.Sit then h.Sit = false end
                if tick() - st > math.random(1,3) then h.WalkSpeed = math.random(speed-15, speed+15); st = tick() end
                if (mR.Position - goal).Magnitude < 5 or tick() - gt > 1.2 then
                    local rng = Random.new()
                    goal = tR.Position + Vector3.new(rng:NextNumber(-range,range), 0, rng:NextNumber(-range,range))
                    gt = tick()
                end
                h:MoveTo(goal)
            end
            task.wait(0.03)
        end
        if h then h.WalkSpeed = _G.SpeedLock or 16 end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  MATHEMATICAL CURVE ENGINE — time-based, deterministic
--  phase = (t / PERIOD + botOffset) * 2π → smooth, no drift
-- ═══════════════════════════════════════════════════════════
local PI2 = math.pi * 2
local PI  = math.pi
local sin, cos, abs, sqrt, rad = math.sin, math.cos, math.abs, math.sqrt, math.rad

local function RunOrbitCurve(args, speaker, curveFn, tag)
    local speed, range, target = ParseSpeedRangeTarget(args, speaker, 4, 10)
    if not target or not target.Character then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = tag or "Orbit"
    task.spawn(function()
        local idx, total = SafeIndex(), SafeTotal()
        local startT = tick()
        while _G.CurrentCommand == (tag or "Orbit") and target and target.Character do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if mR and tR then
                local h = LocalPlayer.Character:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
                local t = (tick() - startT) * (speed / 4)
                local pos = curveFn(t, idx, total, range)
                mR.CFrame = CFrame.new(tR.Position + pos, tR.Position)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  ORBIT CURVES (orbit = basic, orbit1-20 = patterns)
-- ═══════════════════════════════════════════════════════════
local OrbitCurves = {}

-- orbit: Clean flat circle
OrbitCurves[0] = function(t, i, count, R)
    R = math.max(R, count * 3)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(sin(phase)*R, 0, cos(phase)*R)
end

-- orbit1: Flat circle (same as orbit, classic)
OrbitCurves[1] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local breathe = R + sin(t * 0.5) * 1.5
    return Vector3.new(sin(phase)*breathe, 0, cos(phase)*breathe)
end

-- orbit2: Double helix — two interleaved strands
OrbitCurves[2] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(sin(phase)*R, sin(phase*0.5)*(R*0.7), cos(phase)*R)
end

-- orbit3: Atomic — bots on tilted orbital planes
OrbitCurves[3] = function(t, i, count, R)
    local P = 16
    local plane = i % 3
    local gi = math.floor((i-1)/3); local gt = math.max(math.ceil(count/3), 1)
    local phase = (t / P + gi/gt) * PI2
    if plane == 0 then return Vector3.new(cos(phase)*R, sin(phase)*R, 0)
    elseif plane == 1 then return Vector3.new(cos(phase)*R, 0, sin(phase)*R)
    else return Vector3.new(0, cos(phase)*R, sin(phase)*R) end
end

-- orbit4: Galaxy spiral arms — expanding outward
OrbitCurves[4] = function(t, i, count, R)
    local arms = math.min(3, math.ceil(count/3))
    local arm = (i-1) % arms
    local posInArm = math.floor((i-1)/arms)
    local armAngle = (arm/arms) * PI2
    local dist = 3 + posInArm * 2.5
    local phase = armAngle + posInArm * 0.5 + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i) * 1.5, sin(phase)*dist)
end

-- orbit5: Vertical vortex — cone helix
OrbitCurves[5] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local height = frac * 20
    local coneR = 3 + frac * R
    local phase = (t / P + frac) * PI2
    return Vector3.new(cos(phase)*coneR, height - 10, sin(phase)*coneR)
end

-- orbit6: Figure-eight (lemniscate)
OrbitCurves[6] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local denom = 1 + sin(phase) * sin(phase)
    return Vector3.new(R*cos(phase)/denom, sin(phase*2)*3, R*sin(phase)*cos(phase)/denom)
end

-- orbit7: Pulsating — radius breathes in and out
OrbitCurves[7] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local breathe = R + sin(t * 2) * (R * 0.5)
    return Vector3.new(cos(phase)*breathe, sin(t*3 + i)*2, sin(phase)*breathe)
end

-- orbit8: Layered rings — tilted ring planes
OrbitCurves[8] = function(t, i, count, R)
    local P = 14
    local rings = math.min(3, math.ceil(count/3))
    local ring = (i-1) % rings
    local pir = math.floor((i-1)/rings); local bir = math.max(math.ceil(count/rings), 1)
    local phase = (t / P + pir/bir) * PI2
    local tilt = (ring/rings) * PI * 0.6
    local lx, ly = cos(phase)*R, sin(phase)*R
    return Vector3.new(lx, ly*cos(tilt), ly*sin(tilt))
end

-- orbit9: Rose curve (floral petals)
OrbitCurves[9] = function(t, i, count, R)
    local P = 20
    local phase = (t / P + (i-1)/count) * PI2
    local rr = R * abs(cos(3 * phase))
    return Vector3.new(cos(phase)*rr, sin(phase*2)*3, sin(phase)*rr)
end

-- orbit10: Chaotic multi-frequency
OrbitCurves[10] = function(t, i, count, R)
    local seed = i * 1.1
    return Vector3.new(
        sin(t*1.3+seed)*R*cos(t*0.7+seed*2),
        cos(t*0.9+seed*1.5)*(R*0.6)*sin(t*1.1+seed),
        sin(t*1.1+seed*0.8)*R*cos(t*1.3+seed*1.7))
end

-- orbit11: Saturn rings — flat ring with Y wobble
OrbitCurves[11] = function(t, i, count, R)
    local P = 16
    local phase = (t / P + (i-1)/count) * PI2
    local wobble = sin(phase * 3) * 1.5
    local breathe = R + sin(t) * 0.8
    return Vector3.new(sin(phase)*breathe, wobble, cos(phase)*breathe)
end

-- orbit12: Infinity loop (3D figure-eight, tilted)
OrbitCurves[12] = function(t, i, count, R)
    local P = 20
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(sin(phase)*R, sin(phase*2)*(R*0.35), cos(phase)*R*cos(phase*0.5))
end

-- orbit13: Electron cloud — spherical scatter orbit
OrbitCurves[13] = function(t, i, count, R)
    local P = 18
    local golden = i * PI * (3 - sqrt(5))
    local phase = t / P + golden
    local theta = math.acos(1 - 2*((i-0.5)/count))
    return Vector3.new(sin(theta)*cos(phase)*R, cos(theta)*R, sin(theta)*sin(phase)*R)
end

-- orbit14: Ferris wheel — vertical circle
OrbitCurves[14] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(0, sin(phase)*R, cos(phase)*R)
end

-- orbit15: Cascading waterfall — staggered heights
OrbitCurves[15] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local yOff = ((i-1)/count) * 12 - 6
    local breathe = R + sin(t*2 + (i-1)/count * PI2) * 3
    return Vector3.new(sin(phase)*breathe, yOff + sin(phase*3)*1.5, cos(phase)*breathe)
end

-- orbit16: Tornado funnel — radius shrinks upward
OrbitCurves[16] = function(t, i, count, R)
    local P = 12
    local frac = (i-1)/count
    local y = frac * 25 - 12
    local funnelR = R * (1 - frac * 0.7)
    local phase = (t / P + frac * 2) * PI2
    return Vector3.new(sin(phase)*funnelR, y, cos(phase)*funnelR)
end

-- orbit17: Heart pulse — radius pulses per bot
OrbitCurves[17] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    local beat = 1 + abs(sin(t*3 + i*0.7)) * 0.4
    return Vector3.new(sin(phase)*R*beat, sin(t*2+i)*2, cos(phase)*R*beat)
end

-- orbit18: Comet trails — elliptical orbits
OrbitCurves[18] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local a, b = R * 1.5, R * 0.6
    return Vector3.new(sin(phase)*a, sin(phase*2)*2, cos(phase)*b)
end

-- orbit19: Mobius twist — rotating orbital plane
OrbitCurves[19] = function(t, i, count, R)
    local P = 20
    local phase = (t / P + (i-1)/count) * PI2
    local twist = phase * 0.5
    local x = cos(phase) * R
    local flat = sin(phase) * R
    return Vector3.new(x, flat * sin(twist), flat * cos(twist))
end

-- orbit20: Jellyfish — dome with trailing tentacles
OrbitCurves[20] = function(t, i, count, R)
    local P = 16
    local phase = (t / P + (i-1)/count) * PI2
    local dome = cos(phase * 0.5)
    local tentR = R * (0.3 + abs(dome) * 0.7)
    local y = dome * (R * 0.5) + sin(t*2 + i) * 1.5
    return Vector3.new(sin(phase)*tentR, y, cos(phase)*tentR)
end

-- Register all orbit commands
Commands.orbit = function(a, s) RunOrbitCurve(a, s, OrbitCurves[0]) end
for i = 1, 20 do Commands["orbit" .. i] = function(a, s) RunOrbitCurve(a, s, OrbitCurves[i]) end end

-- ═══════════════════════════════════════════════════════════
--  SPIRAL CURVES (spiral1-20 = patterns)
-- ═══════════════════════════════════════════════════════════
local SpiralCurves = {}

-- spiral1: Upward helix — smooth ascending circle
SpiralCurves[1] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local dynR = R + sin(t * 0.5) * 5
    local y = sin(t + (i-1)/count * PI2) * 6
    return Vector3.new(cos(phase)*dynR, y, sin(phase)*dynR)
end

-- spiral2: Cone vortex — expanding upward
SpiralCurves[2] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local hd = frac * 16; local ht = sin(t + hd) * 4 + hd
    local cr = (ht / 16) * R
    return Vector3.new(cos(phase)*cr, ht, sin(phase)*cr)
end

-- spiral3: DNA ladder — two interleaved strands
SpiralCurves[3] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local pI = math.floor((i-1)/2)
    local height = (pI / math.max(math.ceil(count/2), 1)) * 16
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(cos(phase)*R, height + sin(t*0.5)*2 - 8, sin(phase)*R)
end

-- spiral4: Dispersal jet — eruption pattern
SpiralCurves[4] = function(t, i, count, R)
    local P = 16
    local frac = (i-1)/count
    local cycle = (t/P*0.3 + frac * PI2) % PI2; local ph = cycle / PI2
    local y, cr
    if ph < 0.6 then y = (ph/0.6)*15; cr = R*0.4
    else local ap = (ph-0.6)/0.4; y = 15*(1-ap*ap); cr = R*0.4 + R*ap end
    local phase = (t / P + frac) * PI2
    return Vector3.new(cos(phase)*cr, y - 5, sin(phase)*cr)
end

-- spiral5: Tornado funnel — tightening upward
SpiralCurves[5] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local height = ((t/P*0.5 + frac*20) % 20)
    local nH = height / 20
    local tR = R * (0.3 + nH * 0.7)
    local phase = (t / P + frac) * PI2 + nH * PI * 4
    return Vector3.new(cos(phase)*tR, height - 10, sin(phase)*tR)
end

-- spiral6: Golden ratio — Fermat's spiral
SpiralCurves[6] = function(t, i, count, R)
    local ga = i * PI * (3 - sqrt(5))
    local dist = sqrt(i) * 3
    local phase = ga + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i*0.5)*2, sin(phase)*dist)
end

-- spiral7: Bouncing spring — compression/expansion
SpiralCurves[7] = function(t, i, count, R)
    local P = 10
    local comp = sin(t * 1.5) * 0.5 + 0.5
    local spacing = 2 + comp * 4
    local y = (i - (count+1)/2) * spacing
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(cos(phase)*(R*(0.5+comp*0.5)), y, sin(phase)*(R*(0.5+comp*0.5)))
end

-- spiral8: Inward pool — shrinking spiral
SpiralCurves[8] = function(t, i, count, R)
    local P = 16
    local frac = (i-1)/count
    local cycle = (t/P*0.4 + frac * PI2) % PI2; local ph = cycle / PI2
    local wR = R * (1 - ph * 0.8)
    local phase = (t / P + frac) * PI2 + ph * PI * 4
    return Vector3.new(cos(phase)*wR, -ph*8 + 4, sin(phase)*wR)
end

-- spiral9: Wavy ascent — radius waves
SpiralCurves[9] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local wR = R + sin(phase*3 + t) * (R*0.4)
    return Vector3.new(cos(phase)*wR, sin(t + (i-1)/count * PI2)*6, sin(phase)*wR)
end

-- spiral10: Layered cascade — stacked rotating rings
SpiralCurves[10] = function(t, i, count, R)
    local layers = math.min(4, math.ceil(count/2))
    local layer = (i-1) % layers
    local pil = math.floor((i-1)/layers)
    local bpl = math.max(math.ceil(count/layers), 1)
    local phase = ((pil/bpl) * PI2) + t * (1 + layer*0.3)
    local y = (layer - (layers-1)/2) * 5
    return Vector3.new(cos(phase)*R, y, sin(phase)*R)
end

-- spiral11: Helix staircase — stepped ascent
SpiralCurves[11] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local step = math.floor(phase / (PI/4)) * 2
    local y = step + sin(phase * 2) * 0.5
    return Vector3.new(sin(phase)*R, y - 8, cos(phase)*R)
end

-- spiral12: Whirlpool — accelerating inward spiral
SpiralCurves[12] = function(t, i, count, R)
    local P = 20
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local accel = 1 + frac * 2
    local wR = R * (1 - frac * 0.6)
    return Vector3.new(sin(phase*accel)*wR, frac*15 - 7, cos(phase*accel)*wR)
end

-- spiral13: Aurora wave — flowing sine curtain
SpiralCurves[13] = function(t, i, count, R)
    local spread = ((i-1)/count) * PI2
    local x = sin(spread) * R
    local z = cos(spread) * R
    local wave = sin(t + spread * 2) * 5 + sin(t*1.7 + spread) * 3
    return Vector3.new(x, wave, z)
end

-- spiral14: Firework burst — expanding outward
SpiralCurves[14] = function(t, i, count, R)
    local golden = i * PI * (3 - sqrt(5))
    local theta = math.acos(1 - 2*((i-0.5)/count))
    local pulse = (sin(t*2) + 1) * 0.5
    local dist = R * (0.3 + pulse * 0.7)
    return Vector3.new(sin(theta)*cos(golden+t*0.3)*dist, cos(theta)*dist, sin(theta)*sin(golden+t*0.3)*dist)
end

-- spiral15: Pendulum — swinging column
SpiralCurves[15] = function(t, i, count, R)
    local y = ((i-1)/count) * 20 - 10
    local swing = sin(t + y * 0.2) * R * 0.8
    local depth = cos(t * 0.7 + y * 0.15) * R * 0.4
    return Vector3.new(swing, y, depth)
end

-- spiral16: Galaxy arm — logarithmic spiral
SpiralCurves[16] = function(t, i, count, R)
    local frac = (i-1)/count
    local angle = frac * PI * 6 + t * 0.4
    local dist = 2 + frac * R
    local y = sin(t + frac * PI2) * 2
    return Vector3.new(cos(angle)*dist, y, sin(angle)*dist)
end

-- spiral17: Slinky — bouncing helix
SpiralCurves[17] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local bounce = abs(sin(t * 1.5)) * 8
    local y = ((i-1)/count) * bounce - bounce/2
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral18: Crown — tiara pattern
SpiralCurves[18] = function(t, i, count, R)
    local P = 16
    local phase = (t / P + (i-1)/count) * PI2
    local spikes = 5
    local y = abs(sin(phase * spikes)) * 6
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral19: Cyclone eye — double vortex
SpiralCurves[19] = function(t, i, count, R)
    local P = 14
    local half = math.ceil(count/2)
    local isTop = i <= half
    local li = isTop and i or (i - half)
    local lc = isTop and half or (count - half)
    local frac = (li-1)/math.max(lc, 1)
    local phase = (t / P + frac) * PI2
    local dir = isTop and 1 or -1
    local y = frac * 12 * dir
    local wR = R * (1 - frac * 0.5)
    return Vector3.new(sin(phase)*wR, y, cos(phase)*wR)
end

-- spiral20: Fountain — rising and falling arcs
SpiralCurves[20] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local arc = sin(phase * 0.5)
    local y = abs(arc) * 15
    local spread = R * (1 - abs(arc) * 0.5)
    return Vector3.new(sin(phase)*spread, y - 3, cos(phase)*spread)
end

-- Register all spiral commands
Commands.spiral = function(a, s) RunOrbitCurve(a, s, SpiralCurves[1], "Spiral") end
for i = 1, 20 do Commands["spiral"..i] = function(a, s) RunOrbitCurve(a, s, SpiralCurves[i], "Spiral") end end

-- ═══════════════════════════════════════════════════════════
--  HELICOPTER — rigid circle around Head, all bots in sync
-- ═══════════════════════════════════════════════════════════
Commands.helicopter = function(args, speaker)
    local speed, target = ParseSpeedTarget(args, speaker, 18)
    if not target or not target.Character then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "Helicopter"
    task.spawn(function()
        local idx, total = SafeIndex(), SafeTotal()
        -- Fixed angular offset for THIS bot
        local myOffset = ((idx - 1) / total) * (math.pi * 2)
        -- Bigger circle: keep distance between head and bot feet
        -- footToHRP = ~3 studs from feet to HRP center + gap of ~3 studs from head
        local footToHRP = 6
        while _G.CurrentCommand == "Helicopter" and target and target.Character do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tHead = target.Character and target.Character:FindFirstChild("Head")
            if mR and tHead then
                local h = LocalPlayer.Character:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
                -- All bots share the same tick() for perfect sync
                local rotation = tick() * speed
                local angle = myOffset + rotation
                -- Position HRP in circle at head height, offset by footToHRP
                local headPos = tHead.Position
                local orbitalPos = headPos + Vector3.new(math.cos(angle) * footToHRP, 0, math.sin(angle) * footToHRP)
                -- Lie flat: face head, then pitch 90° so feet point at head
                mR.CFrame = CFrame.new(orbitalPos, headPos) * CFrame.Angles(math.rad(90), 0, 0)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.heli = Commands.helicopter

-- ═══════════════════════════════════════════════════════════
--  QUIT / EXIT / LEAVE
-- ═══════════════════════════════════════════════════════════
Commands.quit = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); ChatSend("Quitting - Bye " .. tostring(getgenv().Settings.mainAccount))
    task.delay(3, function() LocalPlayer:Kick("DayBreak: Quit") end)
end
Commands.exit = Commands.quit; Commands.leave = Commands.quit

-- ═══════════════════════════════════════════════════════════
--  SHIELD 1-5
-- ═══════════════════════════════════════════════════════════
local function DoShield(args, speaker, sn)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Shield"
    task.spawn(function()
        local idx, total = SafeIndex(), SafeTotal()
        while _G.CurrentCommand == "Shield" and target and target.Character do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if mR and tR then
                local h = LocalPlayer.Character:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
                local off = CFrame.new(0,0,0)
                if sn==1 then local tw=(total-1)*4; off=CFrame.new(((idx-1)*4)-(tw/2),0,-6)
                elseif sn==2 then local a=((idx-1)/math.max(total-1,1))*math.pi-(math.pi/2); off=CFrame.new(math.sin(a)*8,0,-math.cos(a)*8)
                elseif sn==3 then local s=(idx%2==0) and 1 or -1; local d=math.floor(idx/2)*3; off=CFrame.new(s*(d*0.8),0,-d-3)
                elseif sn==4 then local bpr=math.ceil(total/2); local cr=math.floor((idx-1)/bpr); local pr=(idx-1)%bpr; off=CFrame.new((pr*4)-((bpr-1)*4/2),cr*6,-7)
                elseif sn==5 then local sc=math.ceil(total/4); local si=math.floor((idx-1)/sc); local ps=(idx-1)%sc; local o=(ps-(sc-1)/2)*4; local d=8
                    if si==0 then off=CFrame.new(o,0,-d) elseif si==1 then off=CFrame.new(o,0,d) elseif si==2 then off=CFrame.new(-d,0,o) else off=CFrame.new(d,0,o) end
                end
                mR.CFrame = tR.CFrame * off; mR.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.shield = function(a,s) DoShield(a,s,1) end
for i = 1, 5 do Commands["shield"..i] = function(a,s) DoShield(a,s,i) end end

-- ═══════════════════════════════════════════════════════════
--  PING / RAM / CPU
-- ═══════════════════════════════════════════════════════════
Commands.ping = function(args, speaker)
    if not IsSoloCommand(args) then return end
    task.spawn(function()
        task.wait(SafeIndex() * 0.3)
        ChatSend("[" .. LocalPlayer.Name .. "] Ping: " .. math.round(LocalPlayer:GetNetworkPing()*1000) .. "ms")
    end)
end
Commands.latency = Commands.ping; Commands.net = Commands.ping

local _lowRamEnabled = false
local _originalMaterials = {}

local function ApplyRenderMode(enable3D)
    _lowRamEnabled = not enable3D
    pcall(function()
        pcall(function()
            if RunService.Set3dRenderingEnabled then
                RunService:Set3dRenderingEnabled(enable3D)
            end
        end)
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = enable3D
        if not enable3D then
            lighting.FogEnd = 9e9
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end

        for _, item in ipairs(workspace:GetDescendants()) do
            if item:IsA("BasePart") then
                if not enable3D then
                    if not _originalMaterials[item] then
                        _originalMaterials[item] = item.Material
                    end
                    item.Material = Enum.Material.SmoothPlastic
                    item.CastShadow = false
                else
                    if _originalMaterials[item] then
                        item.Material = _originalMaterials[item]
                    end
                    item.CastShadow = true
                end
            elseif item:IsA("Decal") or item:IsA("Texture") then
                item.Transparency = enable3D and 0 or 1
            elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") then
                item.Enabled = enable3D
            end
        end
    end)
end

Commands.memory = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    local count = collectgarbage("count")
    local memMB = string.format("%.2f", count / 1024)
    local idx = SafeIndex()
    LocalPlayer:SetAttribute("DayBreakRAM", memMB .. " MB")
    ChatSend(string.format("[RAM] Bot #%d: %s MB (Render: %s)", idx, memMB, _lowRamEnabled and "LowRAM" or "Normal"))
end
Commands.ram = Commands.memory

Commands.lowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(false)
    collectgarbage("collect")
    local idx = SafeIndex()
    local count = collectgarbage("count")
    local memMB = string.format("%.2f", count / 1024)
    LocalPlayer:SetAttribute("DayBreakRAM", memMB .. " MB")
    if idx == 1 or args[2] then
        ChatSend(string.format("[LowRAM] Bot #%d Mode ON | RAM: %s MB", idx, memMB))
    end
end

Commands.unlowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(true)
    local idx = SafeIndex()
    if idx == 1 or args[2] then
        ChatSend(string.format("[LowRAM] Bot #%d Mode OFF (Graphics Restored)", idx))
    end
end

Commands.cleanram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    local saved = math.max(0, math.floor(before - after))
    local idx = SafeIndex()
    local memMB = string.format("%.2f", after / 1024)
    LocalPlayer:SetAttribute("DayBreakRAM", memMB .. " MB")
    ChatSend(string.format("[Clean] Bot #%d Cleaned %d KB | RAM: %s MB", idx, saved, memMB))
end
Commands.flush = Commands.cleanram
Commands.ramclean = Commands.cleanram

Commands.altcount = function(args, speaker)
    RefreshBotCache()
    ChatSend(string.format("[DayBreak] Connected Alts Online: %d", _bc.total))
end

-- ===================================================================
--  SOUND FX (SFX) & VISUAL EFFECTS (VFX) SUITE
-- ===================================================================
getgenv().DayBreakSFX = getgenv().DayBreakSFX or { Enabled = true }
getgenv().SelectedBots = getgenv().SelectedBots or {}

local function PlaySFX(soundId)
    if not getgenv().DayBreakSFX.Enabled then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = soundId or "rbxassetid://6895079853"
        sound.Volume = 0.5
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 3)
    end)
end
getgenv().PlaySFX = PlaySFX

Commands.sfx = function(args, speaker)
    local sub = args[2] and args[2]:lower()
    if sub == "off" then
        getgenv().DayBreakSFX.Enabled = false
        ChatSend("[SFX] Sound effects muted.")
    elseif sub == "on" then
        getgenv().DayBreakSFX.Enabled = true
        PlaySFX()
        ChatSend("[SFX] Sound effects enabled.")
    elseif sub and sub:match("^%d+$") then
        PlaySFX("rbxassetid://" .. sub)
    else
        PlaySFX()
    end
end

-- Full VFX Suite
getgenv().DayBreakVFX = getgenv().DayBreakVFX or {
    Highlight = false,
    Laser = false,
    Trail = false,
    Rainbow = false,
    CurrentPalette = "purple",
}

local VFX_PALETTES = {
    purple  = Color3.fromRGB(168, 85, 247),
    cyan    = Color3.fromRGB(34, 211, 238),
    gold    = Color3.fromRGB(251, 191, 36),
    red     = Color3.fromRGB(248, 113, 113),
    green   = Color3.fromRGB(52, 211, 153),
    pink    = Color3.fromRGB(244, 114, 182),
    white   = Color3.fromRGB(240, 240, 255),
}

local function GetVFXColor()
    if getgenv().DayBreakVFX.Rainbow then
        local hue = (tick() * 0.3) % 1
        return Color3.fromHSV(hue, 0.85, 1)
    end
    local pal = getgenv().DayBreakVFX.CurrentPalette or "purple"
    return VFX_PALETTES[pal] or VFX_PALETTES.purple
end

local function ClearBotVFX(char)
    if not char then return end
    pcall(function()
        local h = char:FindFirstChild("DayBreakHighlight")
        if h then h:Destroy() end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj.Name == "DayBreakTrail" or obj.Name == "DayBreakLaser" or obj.Name == "DayBreakAtt0" or obj.Name == "DayBreakAtt1" then
                obj:Destroy()
            end
        end
    end)
end

local function ApplyBotHighlight(char)
    if not char or not getgenv().DayBreakVFX.Highlight then return end
    pcall(function()
        local hl = char:FindFirstChild("DayBreakHighlight") or Instance.new("Highlight")
        hl.Name = "DayBreakHighlight"
        hl.FillColor = GetVFXColor()
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 0.1
        hl.Adornee = char
        hl.Parent = char
    end)
end

local function ApplyBotTrail(char)
    if not char or not getgenv().DayBreakVFX.Trail then return end
    pcall(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if hrp:FindFirstChild("DayBreakTrail") then return end

        local a0 = Instance.new("Attachment", hrp)
        a0.Name = "DayBreakAtt0"
        a0.Position = Vector3.new(0, 1.5, 0)

        local a1 = Instance.new("Attachment", hrp)
        a1.Name = "DayBreakAtt1"
        a1.Position = Vector3.new(0, -1.5, 0)

        local tr = Instance.new("Trail", hrp)
        tr.Name = "DayBreakTrail"
        tr.Attachment0 = a0
        tr.Attachment1 = a1
        tr.Color = ColorSequence.new(GetVFXColor())
        tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
        tr.Lifetime = 0.8
    end)
end

Commands.vfx = function(args, speaker)
    local sub = args[2] and args[2]:lower() or "help"
    local p = args[3] and args[3]:lower()

    if sub == "highlight" or sub == "hl" then
        getgenv().DayBreakVFX.Highlight = not getgenv().DayBreakVFX.Highlight
        if getgenv().DayBreakVFX.Highlight then
            ApplyBotHighlight(LocalPlayer.Character)
        else
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("DayBreakHighlight")
            if h then h:Destroy() end
        end
        if SafeIndex() == 1 then ChatSend("[VFX] Highlight " .. (getgenv().DayBreakVFX.Highlight and "ENABLED" or "DISABLED")) end

    elseif sub == "trail" or sub == "tr" then
        getgenv().DayBreakVFX.Trail = not getgenv().DayBreakVFX.Trail
        if getgenv().DayBreakVFX.Trail then
            ApplyBotTrail(LocalPlayer.Character)
        else
            ClearBotVFX(LocalPlayer.Character)
        end
        if SafeIndex() == 1 then ChatSend("[VFX] Trails " .. (getgenv().DayBreakVFX.Trail and "ENABLED" or "DISABLED")) end

    elseif sub == "rainbow" or sub == "rb" then
        getgenv().DayBreakVFX.Rainbow = not getgenv().DayBreakVFX.Rainbow
        if SafeIndex() == 1 then ChatSend("[VFX] Rainbow Cycle " .. (getgenv().DayBreakVFX.Rainbow and "ENABLED" or "DISABLED")) end

    elseif sub == "color" or sub == "palette" then
        if p and VFX_PALETTES[p] then
            getgenv().DayBreakVFX.CurrentPalette = p
            getgenv().DayBreakVFX.Rainbow = false
            if getgenv().DayBreakVFX.Highlight then ApplyBotHighlight(LocalPlayer.Character) end
            if SafeIndex() == 1 then ChatSend("[VFX] Palette set to: " .. p:upper()) end
        else
            if SafeIndex() == 1 then ChatSend("[VFX] Available palettes: purple, cyan, gold, red, green, pink, white") end
        end

    elseif sub == "laser" then
        getgenv().DayBreakVFX.Laser = not getgenv().DayBreakVFX.Laser
        if SafeIndex() == 1 then ChatSend("[VFX] Laser Grid " .. (getgenv().DayBreakVFX.Laser and "ENABLED" or "DISABLED")) end

    elseif sub == "off" or sub == "stop" or sub == "clear" then
        getgenv().DayBreakVFX.Highlight = false
        getgenv().DayBreakVFX.Trail = false
        getgenv().DayBreakVFX.Rainbow = false
        getgenv().DayBreakVFX.Laser = false
        ClearBotVFX(LocalPlayer.Character)
        if SafeIndex() == 1 then ChatSend("[VFX] All visual effects cleared.") end
    end
end
Commands.unvfx = function(args, speaker)
    Commands.vfx({"vfx", "off"}, speaker)
end

-- ===================================================================
--  SMART FORMATIONS (Smart dynamic positioning)
-- ===================================================================
local function GetFormationTargetHRP(args, speaker)
    local targetPlr = FindTarget(args[2], speaker) or speaker
    if targetPlr and targetPlr.Character then
        return targetPlr.Character:FindFirstChild("HumanoidRootPart"), targetPlr
    end
    return nil, nil
end

Commands.line = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "line"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local spacing = 4

    task.spawn(function()
        while _G.CurrentCommand == "line" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local offset = (myIdx - (total + 1) / 2) * spacing
                local targetCFrame = hrp.CFrame * CFrame.new(offset, 0, 0)
                myHrp.CFrame = myHrp.CFrame:Lerp(targetCFrame, 0.25)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.circle = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "circle"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local radius = 8

    task.spawn(function()
        while _G.CurrentCommand == "circle" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local angle = (myIdx / total) * (math.pi * 2)
                local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                local targetPos = hrp.Position + offset
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.wall = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "wall"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local spacing = 3.5

    task.spawn(function()
        while _G.CurrentCommand == "wall" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local offset = (myIdx - (total + 1) / 2) * spacing
                local targetCFrame = hrp.CFrame * CFrame.new(offset, 0, -6)
                myHrp.CFrame = CFrame.lookAt(targetCFrame.Position, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.orbit = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "orbit"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local radius = 9
    local speed = 2.5

    task.spawn(function()
        while _G.CurrentCommand == "orbit" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local angle = (tick() * speed) + ((myIdx / total) * (math.pi * 2))
                local targetPos = hrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.box = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "box"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local dist = 6

    task.spawn(function()
        while _G.CurrentCommand == "box" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local side = (myIdx % 4)
                local offset = Vector3.new(0,0,0)
                if side == 0 then offset = Vector3.new(dist, 0, 0)
                elseif side == 1 then offset = Vector3.new(-dist, 0, 0)
                elseif side == 2 then offset = Vector3.new(0, 0, dist)
                elseif side == 3 then offset = Vector3.new(0, 0, -dist) end
                myHrp.CFrame = CFrame.lookAt(hrp.Position + offset, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.star = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "star"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)

    task.spawn(function()
        while _G.CurrentCommand == "star" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local r = (myIdx % 2 == 0) and 12 or 6
                local angle = ((myIdx / total) * (math.pi * 2)) + (tick() * 0.8)
                local targetPos = hrp.Position + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

Commands.triangle = Commands.box
Commands.v = Commands.box

-- ===================================================================
--  75+ COMEDY NPC ENGINE (Dynamic Player Seeking & {name} Injection)
-- ===================================================================
local NPCPhrases = {
    -- Classic NPC & AI Self-Awareness Humor
    "My trust issues have trust issues.",
    "I don't fall in love. I trip into mild attachment.",
    "I'm not a red flag. I'm a limited-edition warning label.",
    "We don't need couples therapy. We need a user manual.",
    "Love is temporary. Taxes are forever.",
    "My bank account and I are in a toxic relationship.",
    "Looking for something serious. Like, 'split rent' serious.",
    "My love language is sending memes instead of addressing problems.",
    "I'm not emotionally unavailable. I'm emotionally buffering.",
    "Therapist says I need stability. So here I am.",
    "I'm not toxic. I just come with extended lore.",
    "I bring two things to the table: trust issues and snacks.",
    "If you can't handle me at my worst, that's honestly fair.",
    "I'm not lost. I'm on an unplanned adventure.",
    "My vibe? Controlled chaos with a splash of overthinking.",

    -- Targeted Player Jokes ({name} injection)
    "Excuse me {name}, do you have a map? I keep getting lost in your vibes.",
    "Hey {name}, are you WiFi? Because I'm feeling a completely unstable connection.",
    "Yo {name}, on a scale of 1 to 10, how chaotic is your life right now?",
    "Wait {name}, did you hear that? Sounded like your last brain cell logging off.",
    "{name} watch out! There is a high chance of spontaneous bot dancing nearby.",
    "Breaking news: {name} was spotted carrying the entire server.",
    "Hey {name}, quick question: why are we like this?",
    "{name}, I was told you hold the secrets to the universe. Spill.",
    "Don't panic {name}, but I think we are living in a simulation.",
    "Hey {name}, rate my outfit from 1 to 'needs immediate intervention'.",
    "Psst {name}... whatever you did, I saw nothing.",
    "{name}, my sensors indicate an 87% chance you need a coffee break.",
    "Hold on {name}, let me calculate the velocity of this server's downfall.",
    "{name}, you look like someone who knows how to evade taxes in Bloxburg.",
    "Alert! {name} has entered my primary visual radius. Commencing awkward stare.",
    "Hey {name}, are you an NPC too, or are you just pretending to be functional?",
    "Greetings {name}! I was programmed to follow great people, but I ended up here.",
    "{name}, legend says if you stand still long enough, the server resets.",
    "Stop right there {name}! You have violated the laws of casual gaming.",
    "Hey {name}, do you believe in aliens or just extreme lag?",

    -- Sarcastic & Meme Life Humor
    "I'm not arguing, I'm just explaining why I'm right.",
    "My brain has too many tabs open and 4 of them are playing music.",
    "I have a PhD in making bad decisions quickly.",
    "I'm one minor inconvenience away from an existential crisis.",
    "I don't hold grudges. I remember facts.",
    "I told my doctor I hear voices. He told me I don't have a doctor.",
    "I'm not lazy, I'm on energy-saving mode.",
    "Common sense is like deodorant. The people who need it most never use it.",
    "I'm not dramatic, I'm just exceptionally theatrical.",
    "My life is a constant battle between wanting snacks and wanting to lay down.",
    "I woke up today and chose peace. Then I logged on and chose violence.",
    "I'm fluent in three languages: English, sarcasm, and real talk.",
    "Why fall in love when you can fall asleep?",
    "I put the 'pro' in procrastination.",
    "Running away from my responsibilities counts as cardio, right?",

    -- Brainrot & Gaming Lore
    "Level 100 Boss behavior detected.",
    "My latency is higher than my credit score.",
    "Did someone order a tactical bot squad?",
    "Error 404: Motivation not found.",
    "Bro is locked in with zero spatial awareness.",
    "Chat, is this real?",
    "Skill issue detected in local sector.",
    "Executing advanced tactical standing-around protocol.",
    "I didn't choose the alt life, the alt life chose me.",
    "Lag isn't an excuse, it's a lifestyle.",
    "Powered by Nocturnal Starlight and pure caffeine.",
    "My ping is playing chess while I'm playing checkers.",
    "No thoughts, head empty, just vibes.",
    "NPC energy at maximum capacity.",
    "Warning: Extreme swag levels approaching critical mass.",
    "Bro really thought he was the main character.",
    "Standing here waiting for my plot armor to kick in.",
    "Negative aura detected within a 15-stud radius.",
    "Bro is genuinely flabbergasted.",
    "I know what you did last summer... you stayed inside and scrolled TikTok.",
    "Beware the void. It charges hourly parking fees.",
    "I've seen the future. It's mostly just loading screens.",
    "I survived another day that definitely should have been an email.",
    "My bank account says no, but my dopamine receptors say buy it.",
    "I'm great at multitasking: I can procrastinate and be stressed simultaneously.",
    "I have a 5-year plan to figure out what I'm doing in the next 5 minutes.",
    "My therapist told me to touch grass so I bought a plastic plant."
}

Commands.npc = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    StopAll()
    _G.CurrentCommand = "npc"
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "npc" and _G.DayBreakActive do
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

            if myHrp and myHum then
                local candidates = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and not IsBotPlayer(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
                        if dist < 120 then
                            table.insert(candidates, p)
                        end
                    end
                end

                if #candidates > 0 then
                    local targetPlayer = candidates[math.random(1, #candidates)]
                    local tHrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

                    if tHrp then
                        local stopDist = 5
                        local walkPos = tHrp.Position + (Vector3.new(math.sin(idx), 0, math.cos(idx)).Unit * stopDist)
                        myHum:MoveTo(walkPos)

                        local startT = tick()
                        while _G.CurrentCommand == "npc" and (myHrp.Position - walkPos).Magnitude > 3.5 and (tick() - startT) < 6 do
                            task.wait(0.2)
                        end

                        if myHrp and tHrp then
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, Vector3.new(tHrp.Position.X, myHrp.Position.Y, tHrp.Position.Z))
                        end

                        local phrase = NPCPhrases[math.random(1, #NPCPhrases)]
                        local pName = targetPlayer.DisplayName or targetPlayer.Name
                        phrase = phrase:gsub("{name}", pName)

                        task.wait(0.3 + (idx * 0.1))
                        ChatSend(phrase)
                    end
                else
                    local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
                    myHum:MoveTo(myHrp.Position + offset)
                end
            end

            task.wait(3.5 + (math.random() * 2.5))
        end
    end)
end

Commands.unnpc = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    if _G.CurrentCommand == "npc" then
        StopAll()
        ChatSend("[DayBreak] NPC Wandering Stopped")
    end
end

-- ===================================================================
--  MEME & TROLL SQUAD COMMANDS
-- ===================================================================

-- 1. BODYGUARD FORMATION
Commands.bodyguard = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "bodyguard"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local radius = 6

    task.spawn(function()
        while _G.CurrentCommand == "bodyguard" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local angle = (myIdx / total) * (math.pi * 2)
                local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                local targetPos = hrp.Position + offset
                myHrp.CFrame = CFrame.lookAt(targetPos, targetPos + (offset.Unit * 10))
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 2. RITUAL FORMATION
Commands.ritual = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "ritual"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local radius = 8
    local chants = { "ALL HAIL", "THE CHOSEN ONE", "ASCEND", "JOIN US", "ARISE" }

    task.spawn(function()
        local lastChant = 0
        while _G.CurrentCommand == "ritual" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local angle = (tick() * 1.5) + ((myIdx / total) * (math.pi * 2))
                local targetPos = hrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position)

                if tick() - lastChant > (4 + (myIdx * 0.5)) then
                    lastChant = tick()
                    ChatSend(chants[(myIdx % #chants) + 1] .. " " .. (target and target.DisplayName or ""))
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 3. PAPARAZZI SWARM
Commands.paparazzi = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "paparazzi"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local photoSayings = { "*CLICK*", "Over here!", "Look at the camera!", "Who are you wearing?!", "Smile!" }

    task.spawn(function()
        local lastPic = 0
        while _G.CurrentCommand == "paparazzi" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist > 7 and myHum then
                    myHum:MoveTo(hrp.Position + Vector3.new(math.sin(myIdx)*4, 0, math.cos(myIdx)*4))
                else
                    myHrp.CFrame = CFrame.lookAt(myHrp.Position, hrp.Position)
                end

                if tick() - lastPic > (3 + (myIdx * 0.3)) then
                    lastPic = tick()
                    ChatSend(photoSayings[(myIdx % #photoSayings) + 1])
                    pcall(function()
                        local flash = Instance.new("PointLight")
                        flash.Color = Color3.new(1, 1, 1)
                        flash.Range = 15
                        flash.Brightness = 8
                        flash.Parent = myHrp
                        game:GetService("Debris"):AddItem(flash, 0.15)
                    end)
                end
            end
            task.wait(0.1)
        end
    end)
end

-- 4. COFFIN DANCE
Commands.coffin = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "coffin"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local offsets = {
        Vector3.new(3, 0, 4), Vector3.new(-3, 0, 4),
        Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
        Vector3.new(3, 0, -4), Vector3.new(-3, 0, -4)
    }

    task.spawn(function()
        while _G.CurrentCommand == "coffin" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local myHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                local relOffset = offsets[((myIdx - 1) % #offsets) + 1]
                local targetCFrame = hrp.CFrame * CFrame.new(relOffset)

                local bounce = math.sin(tick() * 6) * 1.5
                myHrp.CFrame = CFrame.new(targetCFrame.Position + Vector3.new(0, bounce, 0), hrp.Position + (hrp.CFrame.LookVector * 10))
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 5. CONGA LINE
Commands.conga = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "conga"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local spacing = 3.5

    task.spawn(function()
        while _G.CurrentCommand == "conga" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local targetCFrame = hrp.CFrame * CFrame.new(0, 0, myIdx * spacing)
                myHrp.CFrame = myHrp.CFrame:Lerp(targetCFrame, 0.3)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 6. STARE COMMAND
Commands.stare = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "stare"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)
    local radius = 7

    task.spawn(function()
        while _G.CurrentCommand == "stare" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local angle = (myIdx / total) * (math.pi * 2)
                local targetPos = hrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position)
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.unstare = function(args, speaker)
    StopAll()
    ChatSend("[DayBreak] Staring halted.")
end

-- 7. TORNADO VORTEX
Commands.tornado = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "tornado"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myIdx = SafeIndex()
    local total = math.max(1, _bc.total)

    task.spawn(function()
        while _G.CurrentCommand == "tornado" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local t = tick() * 4
                local yOffset = ((math.sin(t + myIdx) + 1) / 2) * 14
                local radius = 5 + (yOffset * 0.4)
                local angle = t + ((myIdx / total) * (math.pi * 2))
                local targetPos = hrp.Position + Vector3.new(math.cos(angle) * radius, yOffset, math.sin(angle) * radius)
                myHrp.CFrame = CFrame.lookAt(targetPos, hrp.Position + Vector3.new(0, yOffset, 0))
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 8. CREEPER SNEAK
Commands.creeper = function(args, speaker)
    StopAll()
    _G.CurrentCommand = "creeper"
    local hrp, target = GetFormationTargetHRP(args, speaker)
    if not hrp then return end
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

    task.spawn(function()
        while _G.CurrentCommand == "creeper" and _G.DayBreakActive do
            if hrp and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = LocalPlayer.Character.HumanoidRootPart
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist > 4 and myHum then
                    myHum:MoveTo(hrp.Position)
                elseif dist <= 4 then
                    ChatSend("Sssssssss...")
                    pcall(function()
                        local exp = Instance.new("Explosion")
                        exp.Position = myHrp.Position
                        exp.BlastRadius = 6
                        exp.Parent = workspace
                    end)
                    task.wait(1.5)
                    break
                end
            end
            task.wait(0.3)
        end
    end)
end
Commands.uncreeper = function(args, speaker)
    StopAll()
    ChatSend("[DayBreak] Creeper mode stopped.")
end


Commands.carpet = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Carpet"
    task.spawn(function()
        local idx = SafeIndex(); local tileSize, yOff = 7.5, -3.2; local conn
        conn = RunService.Heartbeat:Connect(function()
            if _G.CurrentCommand ~= "Carpet" then if conn then conn:Disconnect() end; return end
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local tH = target.Character and target.Character:FindFirstChild("Humanoid")
            if mR and tR and tH then
                local dir = (tH.MoveDirection.Magnitude > 0) and tH.MoveDirection or tR.CFrame.LookVector
                local offset = dir * (idx * tileSize)
                mR.CFrame = CFrame.new(tR.Position + offset + Vector3.new(0,yOff,0), tR.Position + offset + Vector3.new(0,yOff,0) + dir) * CFrame.Angles(math.rad(90),0,0)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
                local h = LocalPlayer.Character:FindFirstChild("Humanoid"); if h and h.Sit then h.Sit = false end
            end
        end)
        getgenv().TrackConnection(conn)
        while _G.CurrentCommand == "Carpet" and target and target.Character do task.wait(0.5) end
        if conn then pcall(function() conn:Disconnect() end) end
    end)
end
Commands.floor = Commands.carpet; Commands.bridge = Commands.carpet

-- ═══════════════════════════════════════════════════════════
--  SPIN
-- ═══════════════════════════════════════════════════════════
Commands.spin = function(args, speaker)
    local spinSpd = tonumber(args[2]) or 20
    StopAll(); task.wait(0.1); _G.CurrentCommand = "Spin"
    task.spawn(function()
        local rot = 0; local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.AutoRotate = false end
        while _G.CurrentCommand == "Spin" do
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r then rot = rot + spinSpd; r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(rot), 0)
                r.Velocity = Vector3.zero; r.RotVelocity = Vector3.zero end
            RunService.Heartbeat:Wait()
        end
        pcall(function() local hh = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if hh then hh.AutoRotate = true end end)
    end)
end

-- ═══════════════════════════════════════════════════════════
--  VFLING / KILL
-- ═══════════════════════════════════════════════════════════
Commands.vfling = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    local tR = target.Character:FindFirstChild("HumanoidRootPart"); if not tR then return end
    _G.CurrentCommand = "Fling"
    task.spawn(function()
        local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if mR and h then
            h.Sit = false; local conn
            conn = RunService.Heartbeat:Connect(function()
                if _G.CurrentCommand ~= "Fling" or not tR or not tR.Parent then
                    if conn then conn:Disconnect() end
                    if mR and mR.Parent then mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero end; return
                end
                mR.RotVelocity = Vector3.new(150000,150000,150000)
                local j = Vector3.new(math.random(-10,10)/100, math.random(-10,10)/100, math.random(-10,10)/100)
                mR.CFrame = tR.CFrame * CFrame.new(j) + (tR.Velocity*0.15); mR.Velocity = Vector3.new(500,500,500)
            end)
            getgenv().TrackConnection(conn)
            task.delay(10, function() if _G.CurrentCommand == "Fling" then _G.CurrentCommand = "None" end end)
        end
    end)
end
Commands.kill = Commands.vfling

-- ═══════════════════════════════════════════════════════════
--  BANG
-- ═══════════════════════════════════════════════════════════
Commands.bang = function(args, speaker)
    local spd, target = ParseSpeedTarget(args, speaker, 1)
    if not target or not target.Character then return end
    local tR = target.Character:FindFirstChild("HumanoidRootPart"); if not tR then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "Bang"
    task.spawn(function()
        local step, inc = 0, true; local stepInc = 0.45 * spd
        while _G.CurrentCommand == "Bang" and target and target.Character and tR.Parent do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if mR and tR then
                if h and h.Sit then h.Sit = false end
                if inc then step = step + stepInc; if step >= 1 then inc = false end
                else step = step - stepInc; if step <= 0 then inc = true end end
                mR.CFrame = tR.CFrame * CFrame.new(0, 0, 0.8 + step * 1.2)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  FBANG — no spin fix: lock CFrame every frame
-- ═══════════════════════════════════════════════════════════
Commands.fbang = function(args, speaker)
    local spd, target = ParseSpeedTarget(args, speaker, 1)
    if not target or not target.Character then return end
    local tHead = target.Character:FindFirstChild("Head"); if not tHead then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "FaceBang"
    -- Disable AutoRotate to prevent the spin
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if myHum then myHum.AutoRotate = false end
    task.spawn(function()
        local step, inc = 0, true; local stepInc = 0.45 * spd
        while _G.CurrentCommand == "FaceBang" and target and target.Character and tHead.Parent do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if mR and tHead then
                local h = LocalPlayer.Character:FindFirstChild("Humanoid")
                if h and h.Sit then h.Sit = false end
                if inc then step = step + stepInc; if step >= 1 then inc = false end
                else step = step - stepInc; if step <= 0 then inc = true end end
                local zOff = 0.5 + step * 1.5
                local isR15 = LocalPlayer.Character:FindFirstChild("LowerTorso") ~= nil
                local yOffset = isR15 and 0.75 or 0
                local headPos = tHead.Position
                local frontPos = tHead.CFrame.Position + tHead.CFrame.LookVector * zOff
                local botPos = Vector3.new(frontPos.X, headPos.Y + yOffset, frontPos.Z)
                -- Lock facing direction toward target head — prevents spin
                mR.CFrame = CFrame.new(botPos, Vector3.new(headPos.X, botPos.Y, headPos.Z))
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
        -- Restore AutoRotate on exit
        pcall(function()
            local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if h2 then h2.AutoRotate = true end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════
--  MIRROR SUITE
-- ═══════════════════════════════════════════════════════════
local MIRROR_OFFS = {
    mirror={0,0,0}, rmirror={5,0,0}, lmirror={-5,0,0}, fmirror={0,0,-5}, bmirror={0,0,5},
}
for mc, off in pairs(MIRROR_OFFS) do
    Commands[mc] = function(args, speaker)
        StopAll(); task.wait(0.1)
        local target = FindTarget(args[2], speaker)
        if not target or not target.Character then return end
        local tag = mc:upper(); _G.CurrentCommand = tag
        task.spawn(function()
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if _G.CurrentCommand ~= tag or not target.Character then if conn then conn:Disconnect() end; return end
                local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if mR and tR then
                    mR.CFrame = tR.CFrame * CFrame.new(off[1],off[2],off[3])
                    local mH = LocalPlayer.Character:FindFirstChild("Humanoid"); local tH = target.Character:FindFirstChild("Humanoid")
                    if mH and tH then mH.Jump = tH.Jump; if tH.Sit ~= mH.Sit then mH.Sit = tH.Sit end end
                    mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
                end
            end)
            getgenv().TrackConnection(conn)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
--  RIZZ — queue approach, walk close to target, say line
-- ═══════════════════════════════════════════════════════════
Commands.rizz = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Rizz"
    local lines = {
        "I don't usually get distracted, but you made me forget what I was saying.",
        "You've got that calm energy that makes everything feel easier.",
        "There's something about you that feels different — in a good way.",
        "I can tell you're not just pretty, you've got depth.",
        "I don't think you realize how naturally attractive your vibe is.",
        "You seem like the kind of person people feel safe around.",
        "I wasn't planning on staying long, but you changed that.",
        "You've got that quiet confidence that's hard to ignore.",
        "I like how you carry yourself. It says a lot.",
        "Talking to you feels way too easy… and I don't mind that at all.",
        "You don't even have to try. That's what makes it dangerous.",
        "I respect how you move — it's rare.",
        "I don't throw compliments around, but you earned that one.",
        "If energy is real, yours is undefeated.",
        "I'm not even trying to impress you… I just like talking to you.",
    }
    task.spawn(function()
        local idx, total = SafeIndex(), SafeTotal()
        local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local mH = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not (mR and mH and tR) then return end
        -- Queue up behind target, spaced out
        local q = tR.CFrame * CFrame.new(0, 0, -(15 + idx*4))
        mH:MoveTo(q.Position)
        -- Wait for turn (stagger by bot index)
        task.wait((idx-1)*7)
        if _G.CurrentCommand ~= "Rizz" then return end
        -- Walk RIGHT IN FRONT of target (close: 3 studs)
        local tR2 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tR2 then
            mH:MoveTo((tR2.CFrame * CFrame.new(0, 0, -3)).Position)
        end
        task.wait(2.2)
        -- Face the target
        local tR3 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tR3 then
            mR.CFrame = CFrame.new(mR.Position, Vector3.new(tR3.Position.X, mR.Position.Y, tR3.Position.Z))
        end
        ChatSend(lines[((idx-1)%#lines)+1])
        task.wait(4)
        -- After delivering line, orbit target
        while _G.CurrentCommand == "Rizz" and target and target.Character do
            local lR = target.Character:FindFirstChild("HumanoidRootPart")
            if lR then
                local sp = (idx/total)*(math.pi*2)
                mR.CFrame = CFrame.new(lR.Position + Vector3.new(math.cos(sp)*8, 0, math.sin(sp)*8), lR.Position)
                mR.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  MBANG
-- ═══════════════════════════════════════════════════════════
Commands.mbang = function(args, speaker)
    local spd, target = ParseSpeedTarget(args, speaker, 1)
    if not target or not target.Character then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "MultiBang"
    task.spawn(function()
        local step, inc, oa = 0, true, 0; local stepInc = 0.45 * spd
        while _G.CurrentCommand == "MultiBang" and target and target.Character do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local tH = target.Character and target.Character:FindFirstChild("Head") or tR
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if mR and tR then
                local idx, total = SafeIndex(), SafeTotal()
                if inc then step = step + stepInc; if step >= 1 then inc = false end
                else step = step - stepInc; if step <= 0 then inc = true end end
                local cf = tR.CFrame
                if idx==1 then
                    local isR15 = LocalPlayer.Character:FindFirstChild("LowerTorso") ~= nil
                    local yO = isR15 and 0.75 or 0; local zO = 0.5+step*1.5
                    local fp = tH.CFrame.Position+tH.CFrame.LookVector*zO
                    cf = CFrame.new(Vector3.new(fp.X,tH.Position.Y+yO,fp.Z), Vector3.new(tH.Position.X,tH.Position.Y+yO,tH.Position.Z))
                elseif idx==2 then cf = tR.CFrame*CFrame.new(0,0,0.8+step*1.2)
                elseif idx==3 then cf = tR.CFrame*CFrame.new(0.8+step*1.2,0,0)*CFrame.Angles(0,math.rad(-90),0)
                elseif idx==4 then cf = tR.CFrame*CFrame.new(-(0.8+step*1.2),0,0)*CFrame.Angles(0,math.rad(90),0)
                elseif idx==5 then cf = tR.CFrame*CFrame.new(0,1+step*1.5,0)*CFrame.Angles(math.rad(-90),0,0)
                else oa = oa + 0.05; local si=idx-5; local ts=math.max(total-5,1); local sp=(si/ts)*(math.pi*2)
                    cf = CFrame.new(tR.Position+Vector3.new(math.cos(oa+sp)*8,0,math.sin(oa+sp)*8), tR.Position) end
                if h and h.Sit then h.Sit = false end
                mR.CFrame = cf; mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.multibang = Commands.mbang

-- ═══════════════════════════════════════════════════════════
--  HS 1-20 (Harassment Strike variants)
-- ═══════════════════════════════════════════════════════════
local HS_MESSAGES = {
    [1] = "DayBreak Alt Control active.",
    [2] = "Security system online.",
    [3] = "Fleet synchronizer connected.",
    [4] = "Fleet command initialized.",
    [5] = "DayBreak fleet ready.",
    [6] = "Command receiver active.",
    [7] = "Multi-bot matrix engaged.",
    [8] = "System operational.",
    [9] = "Listening for host commands.",
}
local HS_EMOTES = {
    [1]  = "/e point",
    [2]  = "/e point",
    [3]  = "/e point",
    [4]  = "/e wave",
    [5]  = "/e point",
    [6]  = "/e point",
    [7]  = "/e shrug",
    [8]  = "/e point",
    [9]  = "/e laugh",
    [10] = "/e point",
    [11] = "/e point",
    [12] = "/e laugh",
    [13] = "/e wave",
    [14] = "/e point",
    [15] = "/e shrug",
    [16] = "/e wave",
    [17] = "/e point",
    [18] = "/e point",
    [19] = "/e shrug",
    [20] = "/e laugh",
}

local function DoHS(args, speaker, hsNum)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    local tR = target.Character:FindFirstChild("HumanoidRootPart"); if not tR then return end
    StopAll(); task.wait(0.1); _G.CurrentCommand = "HS"
    task.spawn(function()
        local idx, total = SafeIndex(), SafeTotal()
        local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not mR then return end
        local origCF = mR.CFrame
        local angle = ((idx - 1) / total) * (math.pi * 2)
        local R = math.max(6, total * 1.2)
        mR.CFrame = CFrame.new(tR.Position + Vector3.new(math.cos(angle)*R, 0, math.sin(angle)*R), tR.Position)
        mR.Velocity = Vector3.zero
        task.wait(0.3)
        ChatSend(HS_MESSAGES[hsNum] or HS_MESSAGES[1])
        ChatSend(HS_EMOTES[hsNum] or "/e point")
        local holdEnd = tick() + 20
        while _G.CurrentCommand == "HS" and tick() < holdEnd do
            local mR2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR2 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if mR2 and tR2 then
                local a = ((idx - 1) / total) * (math.pi * 2)
                mR2.CFrame = CFrame.new(tR2.Position + Vector3.new(math.cos(a)*R, 0, math.sin(a)*R), tR2.Position)
                mR2.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
        local curR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if curR then curR.CFrame = origCF end
    end)
end

-- !hs = !hs1 = original HS message
Commands.hs = function(a, s) DoHS(a, s, 1) end
for i = 1, 20 do Commands["hs"..i] = function(a, s) DoHS(a, s, i) end end

-- ═══════════════════════════════════════════════════════════
--  CREDITS / ALTCOUNT / WHISPER / GRAB / EQUIP / UPTIME
-- ═══════════════════════════════════════════════════════════

Commands.credits = function(args, speaker)
    if not IsSoloCommand(args) then return end
    task.spawn(function()
        task.wait((SafeIndex()-1)*0.5)
        ChatSend("🔥 DayBreak ALT Control | Designed by DayBreak 🔥")
    end)
end

Commands.altcount = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if SafeIndex() == 1 then ChatSend("[System] Alts Online: " .. TotalBots()) end
end
Commands.alts = Commands.altcount

Commands.w = function(args, speaker)
    local ts = args[2]; local wm = table.concat(args, " ", 3)
    if not ts or wm == "" then return end
    local tp = FindTarget(ts, speaker); if not tp then return end

    local chatBox
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local eg = game:GetService("CoreGui"):FindFirstChild("ExperienceChat")
        if eg then chatBox = eg:FindFirstChildWhichIsA("TextBox", true) end
    else
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and pGui:FindFirstChild("Chat") then chatBox = pGui.Chat:FindFirstChild("ChatBar", true) end
    end
    if not chatBox then return end

    task.spawn(function()
        local botIndex = SafeIndex() or 1
        -- 1 second waterfall delay per bot
        task.wait((botIndex - 1) * 1.0)
        
        chatBox:CaptureFocus()
        task.wait(0.1)

        local targetName = tp.DisplayName or tp.Name
        local fullString = "/w " .. targetName .. " || " .. wm
        
        for i = 1, #fullString do
            chatBox.Text = chatBox.Text .. fullString:sub(i, i)
            chatBox.CursorPosition = #chatBox.Text + 1
            task.wait(math.random(1, 4) * 0.01)
        end
        
        task.wait(0.15)
        
        local currentRaw = chatBox.Text
        local splitIdx = currentRaw:find("||")
        if splitIdx then
            local msg = currentRaw:sub(splitIdx + 2)
            chatBox.Text = msg:match("^%s*(.-)$") or msg
            chatBox.CursorPosition = #chatBox.Text + 1
        end
        
        task.wait(0.1)
        
        if type(getgenv().keypress) == "function" then
            getgenv().keypress(0x0D)
            task.wait(0.05)
            if type(getgenv().keyrelease) == "function" then getgenv().keyrelease(0x0D) end
        end
        
        -- 1. Native Enter Simulation
        chatBox:ReleaseFocus(true)
        
        -- 2. Fallback: Force fire the CoreGui SendButton
        pcall(function()
            local sysParent = chatBox.Parent
            local sendBtn = sysParent and sysParent.Parent and sysParent.Parent:FindFirstChild("SendButton", true)
            if sendBtn and type(getgenv().getconnections) == "function" then
                for _, connection in pairs(getgenv().getconnections(sendBtn.MouseButton1Click) or {}) do
                    pcall(function() connection:Fire() end)
                end
                for _, connection in pairs(getgenv().getconnections(sendBtn.Activated) or {}) do
                    pcall(function() connection:Fire() end)
                end
            end
        end)
        
        -- 3. Whisper target badge cleanup sequence
        task.wait(10)
        if chatBox.Parent then
            chatBox:CaptureFocus()
            task.wait(0.1)
            
            -- Send Backspace (0x08) x3
            if type(getgenv().keypress) == "function" then
                for _ = 1, 3 do
                    getgenv().keypress(0x08)
                    task.wait(0.05)
                    if type(getgenv().keyrelease) == "function" then getgenv().keyrelease(0x08) end
                    task.wait(0.05)
                end
            else
                local vim = game:GetService("VirtualInputManager")
                for _ = 1, 3 do
                    vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                    task.wait(0.05)
                    vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                    task.wait(0.05)
                end
            end
            
            task.wait(0.1)
            
            -- Send Enter (0x0D) x1 to commit clear
            if type(getgenv().keypress) == "function" then
                getgenv().keypress(0x0D)
                task.wait(0.05)
                if type(getgenv().keyrelease) == "function" then getgenv().keyrelease(0x0D) end
            else
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            end
            
            task.wait(0.1)
            chatBox:ReleaseFocus(false)
        end
    end)
end
Commands.whisper = Commands.w

Commands.spamw = function(args, speaker)
    local ts = args[2]
    local delayInput = tonumber(args[3])
    local customDelay = delayInput or 5.0
    local wm = delayInput and table.concat(args, " ", 4) or table.concat(args, " ", 3)
    
    if not ts or wm == "" then return end
    local tp = FindTarget(ts, speaker); if not tp then return end

    local chatBox
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local eg = game:GetService("CoreGui"):FindFirstChild("ExperienceChat")
        if eg then chatBox = eg:FindFirstChildWhichIsA("TextBox", true) end
    else
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and pGui:FindFirstChild("Chat") then chatBox = pGui.Chat:FindFirstChild("ChatBar", true) end
    end
    if not chatBox then return end

    _G.Spamming = false; task.wait(0.1)
    _G.Spamming = true
    local id = tick()
    _G.CurrentSpamID = id

    task.spawn(function()
        local botIndex = SafeIndex() or 1
        task.wait((botIndex - 1) * 1.0)
        
        while _G.Spamming and _G.CurrentSpamID == id do
            if not chatBox.Parent then break end
            
            chatBox:CaptureFocus()
            task.wait(0.1)

            -- Completely clear previous badge state internally
            if type(getgenv().keypress) == "function" then
                for _ = 1, 3 do
                    getgenv().keypress(0x08)
                    task.wait(0.05)
                    if type(getgenv().keyrelease) == "function" then getgenv().keyrelease(0x08) end
                    task.wait(0.05)
                end
            else
                local vim = game:GetService("VirtualInputManager")
                for _ = 1, 3 do
                    vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                    task.wait(0.05)
                    vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                    task.wait(0.05)
                end
            end
            
            chatBox.Text = "" 
            task.wait(0.1)

            local targetName = tp.DisplayName or tp.Name
            local fullString = "/w " .. targetName .. " || " .. wm
            
            for i = 1, #fullString do
                chatBox.Text = chatBox.Text .. fullString:sub(i, i)
                chatBox.CursorPosition = #chatBox.Text + 1
                task.wait(math.random(1, 4) * 0.01)
            end
            
            task.wait(0.15)
            
            local currentRaw = chatBox.Text
            local splitIdx = currentRaw:find("||")
            if splitIdx then
                local msg = currentRaw:sub(splitIdx + 2)
                chatBox.Text = msg:match("^%s*(.-)$") or msg
                chatBox.CursorPosition = #chatBox.Text + 1
            end
            
            task.wait(0.1)
            
            if type(getgenv().keypress) == "function" then
                getgenv().keypress(0x0D)
                task.wait(0.05)
                if type(getgenv().keyrelease) == "function" then getgenv().keyrelease(0x0D) end
            end
            
            chatBox:ReleaseFocus(true)
            
            pcall(function()
                local sysParent = chatBox.Parent
                local sendBtn = sysParent and sysParent.Parent and sysParent.Parent:FindFirstChild("SendButton", true)
                if sendBtn and type(getgenv().getconnections) == "function" then
                    for _, connection in pairs(getgenv().getconnections(sendBtn.MouseButton1Click) or {}) do
                        pcall(function() connection:Fire() end)
                    end
                    for _, connection in pairs(getgenv().getconnections(sendBtn.Activated) or {}) do
                        pcall(function() connection:Fire() end)
                    end
                end
            end)
            
            task.wait(customDelay)
        end
    end)
end

Commands.grab = function(args, speaker)
    if SafeIndex() ~= 1 then return end
    local target = FindTarget(args[2], speaker); local ic = speaker and speaker.Character
    if not (target and target.Character and ic) then return end
    _G.GrabActive = true
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local tR = target.Character:FindFirstChild("HumanoidRootPart"); local iR = ic:FindFirstChild("HumanoidRootPart")
    if not (mR and tR and iR) then return end
    task.spawn(function()
        mR.CFrame = tR.CFrame * CFrame.new(0,0,3)
        ChatSend("Accept Grab! "..speaker.DisplayName.." wants to see you.")
        local start, lc, ok = tick(), 0, false; local GR = ReplicatedStorage:FindFirstChild("GrabRequest")
        while _G.GrabActive and (tick()-start) < 15 do
            if GR then pcall(function() GR:FireServer(target.UserId, "cute") end) end
            if (mR.Position - tR.Position).Magnitude < 1.7 then lc = lc + 1 else lc = 0 end
            if lc >= 5 then ok = true; break end; task.wait(0.2)
        end
        mR.CFrame = iR.CFrame * CFrame.new(0,0,3); task.wait(0.5)
        ChatSend(target.Name .. (ok and " accepted the grab." or " did not accept in time."))
        _G.GrabActive = false
    end)
end
Commands.xbring = Commands.grab

for i = 1, 10 do
    Commands["equip"..i] = function(args, speaker)
        local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Humanoid")
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if h and bp then
            h:UnequipTools(); task.wait(0.05)
            local tools = {}; for _, it in ipairs(bp:GetChildren()) do if it:IsA("Tool") then table.insert(tools, it) end end
            if tools[i] then h:EquipTool(tools[i]) end
        end
    end
end

Commands.unequip = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChild("Humanoid")
        if h then h:UnequipTools() end
    end
end

Commands.pvp = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    local rs = game:GetService("ReplicatedStorage")
    local pvpEvent = rs:FindFirstChild("event_option_pvp")
    if pvpEvent then
        pcall(function() pvpEvent:FireServer() end)
    end
end

-- UPTIME: only bot01 sends, plain text format (won't get tagged)
Commands.uptime = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if SafeIndex() ~= 1 then return end
    local s = tick() - _G.ScriptStartTime
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = math.floor(s % 60)
    ChatSend("Session Up time : " .. h .. "h " .. m .. "m " .. sec .. "s")
end

-- ═══════════════════════════════════════════════════════════
--  FORMATIONS: arrow, box
-- ═══════════════════════════════════════════════════════════
Commands.arrow = function(args, speaker)
    local target = FindTarget(args[2], speaker) or speaker
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = target.Character.HumanoidRootPart
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not mR then return end
    local idx, total = SafeIndex(), SafeTotal(); local sp = 4; local fwd = root.CFrame.LookVector
    local headCount = (total >= 8) and 5 or 3
    if idx <= headCount then
        if idx==1 then mR.CFrame = CFrame.new((root.CFrame*CFrame.new(0,0,-sp*1.5)).Position, (root.CFrame*CFrame.new(0,0,-sp*1.5)).Position+fwd)
        elseif idx<=3 then local s=(idx==2) and 1 or -1; mR.CFrame = CFrame.new((root.CFrame*CFrame.new(s*sp,0,-sp*0.5)).Position, (root.CFrame*CFrame.new(s*sp,0,-sp*0.5)).Position+fwd)
        else local s=(idx==4) and 2 or -2; mR.CFrame = CFrame.new((root.CFrame*CFrame.new(s*sp,0,sp*0.5)).Position, (root.CFrame*CFrame.new(s*sp,0,sp*0.5)).Position+fwd) end
    else local si=idx-headCount; mR.CFrame = CFrame.new((root.CFrame*CFrame.new(0,0,si*sp+sp*0.5)).Position, (root.CFrame*CFrame.new(0,0,si*sp+sp*0.5)).Position+fwd) end
end

Commands.box = function(args, speaker)
    local target = FindTarget(args[2], speaker) or speaker
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = target.Character.HumanoidRootPart
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not mR then return end
    local idx = SafeIndex(); local sp = 6
    local grid = {{x=-1,z=-1},{x=0,z=-1},{x=1,z=-1},{x=-1,z=0},{x=1,z=0},{x=-1,z=1},{x=0,z=1},{x=1,z=1}}
    local coord = grid[((idx-1)%#grid)+1]
    if idx > #grid then coord = {x=grid[((idx-1)%#grid)+1].x*2, z=grid[((idx-1)%#grid)+1].z*2} end
    local fwd = root.CFrame.LookVector; local rgt = root.CFrame.RightVector
    local fp = root.CFrame.Position + (rgt*(coord.x*sp)) + (fwd*(coord.z*sp))
    mR.CFrame = CFrame.new(fp, fp + fwd)
end
Commands.square = Commands.box

-- ═══════════════════════════════════════════════════════════
--  SCANALL
-- ═══════════════════════════════════════════════════════════
local function FetchLeakData(username)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://leakcheck.io/api/public?check="..HttpService:UrlEncode(username)))
    end)
    return (ok and data and data.success) and data or nil
end

local function CleanSource(str)
    if not str then return "Unknown" end; local c = str:lower()
    for _, f in ipairs({".com",".net",".org",".io",".xyz",".me","http://","https://","www."}) do c = c:gsub(f:gsub("%%.", "%%."), "") end
    return c
end

Commands.scanall = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if getgenv().ScanInProgress then return end; local idx = SafeIndex()
    if idx == 1 then
        getgenv().ScanInProgress = true; getgenv().ServerScanActive = true
        _G.GlobalBreachTable = {}; _G.CurrentScanningUser = "Init..."; _G.ScanAllFinished = false
        task.spawn(function()
            pcall(function()
                ChatSend("Scan Protocol Started..."); local found = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Name:lower() ~= getgenv().Settings.mainAccount:lower() then
                        _G.CurrentScanningUser = p.Name; local d = FetchLeakData(p.Name)
                        if d and d.found and d.found > 0 then table.insert(_G.GlobalBreachTable, {name=p.Name,data=d}); table.insert(found, p.Name) end
                        task.wait(0.8)
                    end
                end
                getgenv().ServerScanActive = false; task.wait(1)
                ChatSend("Scan Done. Breached: "..#found)
                if #found > 0 then task.wait(1.5); ChatSend("Found: "..table.concat(found, ", ")) end
                _G.ScanAllFinished = true
            end)
            getgenv().ScanInProgress = false
        end)
    elseif idx == 2 then
        task.spawn(function() task.wait(2)
            while getgenv().ServerScanActive do ChatSend("Scanning: ["..tostring(_G.CurrentScanningUser).."]..."); task.wait(7) end
        end)
    elseif idx >= 3 then
        task.spawn(function()
            repeat task.wait(0.5) until _G.ScanAllFinished == true
            local e = _G.GlobalBreachTable and _G.GlobalBreachTable[idx-2]
            if e then task.wait((idx-2)*1.8); local src = "Unknown"
                if e.data.result and e.data.result[1] then src = CleanSource(e.data.result[1].line) end
                ChatSend("["..e.name.."] | Sources: "..src)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
--  SAY / TP / SCATTER / FREEZE / COUNTDOWN / REJOIN / WAVE / CMDS
-- ═══════════════════════════════════════════════════════════

Commands.say = function(args, speaker)
    local m = table.concat(args, " ", 2)
    if m ~= "" then task.spawn(function() task.wait((SafeIndex()-1)*0.15); ChatSend(m) end) end
end
Commands.chat = Commands.say

Commands.report = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    local targetNameQuery = newArgs[2]
    local reasonQuery = newArgs[3]
    if not targetNameQuery or not reasonQuery then return end

    local tp = FindTarget(targetNameQuery, speaker)
    if not tp then return end

    local abuseReasons = {
        "Swearing", "Personal information", "Dating/Sex", "Cheating",
        "Username", "Bullying", "Scamming"
    }
    local targetReason = nil
    local qLower = reasonQuery:lower()
    for _, r in ipairs(abuseReasons) do
        if r:lower():sub(1, #qLower) == qLower then
            targetReason = r
            break
        end
    end
    if not targetReason then return end

    task.spawn(function()
        local idx = SafeIndex() or 1
        local delayCounter = 0
        local rng = Random.new()
        
        for _ = 1, idx - 1 do
            delayCounter = delayCounter + rng:NextNumber(5, 10)
        end
        
        task.wait(delayCounter)

        local VIM = game:GetService("VirtualInputManager")
        local CoreGui = game:GetService("CoreGui")

        -- Simulate a real mouse click at center of a GUI element
        local function ClickElement(element)
            if not element then return false end
            local ok, err = pcall(function()
                local pos = element.AbsolutePosition
                local size = element.AbsoluteSize
                local cx = pos.X + size.X / 2
                local cy = pos.Y + size.Y / 2
                VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            return ok
        end

        -- Find a visible GUI element by its text content
        local function FindElement(searchText, exact)
            for _, v in ipairs(CoreGui:GetDescendants()) do
                pcall(function()
                    if (v:IsA("TextLabel") or v:IsA("TextButton")) then
                        local t = v.Text
                        local match = false
                        if exact then
                            match = (t == searchText)
                        else
                            match = (t:find(searchText, 1, true) ~= nil)
                        end
                        if match then
                            -- Bubble up to find clickable parent if needed
                            local target = v
                            if not target:IsA("GuiButton") then
                                local p = target.Parent
                                for _ = 1, 5 do
                                    if not p or p == CoreGui then break end
                                    if p:IsA("GuiButton") or p:IsA("ImageButton") or p:IsA("TextButton") then
                                        target = p
                                        break
                                    end
                                    p = p.Parent
                                end
                            end
                            -- Store result via error throw to escape pcall
                            error({found = target})
                        end
                    end
                end)
            end
            return nil
        end

        -- Robust find + click with pcall-based element extraction
        local function FindAndClick(searchText, exact)
            local result = nil
            for _, v in ipairs(CoreGui:GetDescendants()) do
                local ok2, ret = pcall(function()
                    if (v:IsA("TextLabel") or v:IsA("TextButton")) then
                        local t = v.Text
                        local match = false
                        if exact then
                            match = (t == searchText)
                        else
                            match = (t:find(searchText, 1, true) ~= nil)
                        end
                        if match then
                            local target = v
                            if not target:IsA("GuiButton") then
                                local p = target.Parent
                                for _ = 1, 5 do
                                    if not p or p == CoreGui then break end
                                    if p:IsA("GuiButton") or p:IsA("ImageButton") or p:IsA("TextButton") then
                                        target = p
                                        break
                                    end
                                    p = p.Parent
                                end
                            end
                            return target
                        end
                    end
                    return nil
                end)
                if ok2 and ret then
                    result = ret
                    break
                end
            end
            if result then
                return ClickElement(result)
            end
            return false
        end

        -- Step 1: Click target player in the PlayerList (right sidebar)
        local tDisplay = tp.DisplayName
        local tUser = tp.Name
        if not FindAndClick(tDisplay, true) then
            FindAndClick(tUser, true)
        end
        task.wait(0.8)

        -- Step 2: Click "Report Abuse" on the context popup
        FindAndClick("Report Abuse", true)
        task.wait(2.0)

        -- Step 3: Click "Choose One" reason dropdown
        FindAndClick("Choose One", true)
        task.wait(1.0)

        -- Step 4: Click the matched abuse reason from dropdown list
        FindAndClick(targetReason, true)
        task.wait(1.0)

        -- Step 5: Click "Submit" to finalize the report
        FindAndClick("Submit", true)
    end)
end

-- Multi-method click helper: tries every executor click method available
local function SimClick(element)
    if not element then return false end
    local clicked = false

    -- Method 1: fireclick via getgenv (executor-level CoreGui click)
    pcall(function()
        if not clicked and type(getgenv().fireclick) == "function" then
            getgenv().fireclick(element)
            clicked = true
        end
    end)

    -- Method 2: firesignal via getgenv
    pcall(function()
        if not clicked and type(getgenv().firesignal) == "function" then
            getgenv().firesignal(element.MouseButton1Click)
            clicked = true
        end
    end)

    -- Method 3: getconnections -> Fire
    pcall(function()
        if not clicked and type(getgenv().getconnections) == "function" then
            for _, conn in pairs(getgenv().getconnections(element.MouseButton1Click) or {}) do
                pcall(function() conn:Fire() end)
                clicked = true
            end
            for _, conn in pairs(getgenv().getconnections(element.Activated) or {}) do
                pcall(function() conn:Fire() end)
                clicked = true
            end
        end
    end)

    -- Method 4: VirtualInputManager with GuiInset correction
    pcall(function()
        if not clicked then
            local VIM = game:GetService("VirtualInputManager")
            local guiInset = game:GetService("GuiService"):GetGuiInset()
            local pos = element.AbsolutePosition
            local size = element.AbsoluteSize
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2 + guiInset.Y
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            clicked = true
        end
    end)

    return clicked
end

local function FindGuiByText(searchText, exact, root)
    root = root or game:GetService("CoreGui")
    for _, v in ipairs(root:GetDescendants()) do
        local ok, res = pcall(function()
            if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("ImageButton") then
                local t = ""
                pcall(function() t = v.Text end)
                local match = false
                if exact then match = (t == searchText)
                else match = (t:find(searchText, 1, true) ~= nil) end
                if match then
                    local target = v
                    if not target:IsA("GuiButton") then
                        local p = target.Parent
                        for _ = 1, 6 do
                            if not p or p == root then break end
                            if p:IsA("GuiButton") or p:IsA("TextButton") or p:IsA("ImageButton") then
                                target = p; break
                            end
                            p = p.Parent
                        end
                    end
                    return target
                end
            end
            return nil
        end)
        if ok and res then return res end
    end
    return nil
end

local function FindAndSimClick(searchText, exact, root)
    local el = FindGuiByText(searchText, exact, root)
    if el then return SimClick(el) end
    return false
end

----------------------------------------------------------------
-- FRIEND REQUEST
----------------------------------------------------------------
Commands.friend = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local tp = FindTarget(newArgs[2], speaker)
    if not tp then return end

    task.spawn(function()
        local idx = SafeIndex() or 1
        local rng = Random.new()
        local delay = 0
        for _ = 1, idx - 1 do delay = delay + rng:NextNumber(3, 6) end
        task.wait(delay)

        -- Direct API: opens friend request prompt
        pcall(function()
            game:GetService("StarterGui"):SetCore("PromptSendFriendRequest", tp)
        end)
        task.wait(1.5)

        -- Click "Send Request" on the confirmation dialog
        FindAndSimClick("Send Request", true)
    end)
end

----------------------------------------------------------------
-- BLOCK PLAYER
----------------------------------------------------------------
Commands.block = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local tp = FindTarget(newArgs[2], speaker)
    if not tp then return end

    task.spawn(function()
        local idx = SafeIndex() or 1
        local rng = Random.new()
        local delay = 0
        for _ = 1, idx - 1 do delay = delay + rng:NextNumber(3, 6) end
        task.wait(delay)

        -- Step 1: Click target player name in the PlayerList sidebar
        local tDisplay = tp.DisplayName
        local tUser = tp.Name
        if not FindAndSimClick(tDisplay, true) then
            FindAndSimClick(tUser, true)
        end
        task.wait(1.0)

        -- Step 2: Click "Block" on the context popup menu
        FindAndSimClick("Block", true)
        task.wait(1.5)

        -- Step 3: Click "Block" on the confirmation dialog ("Block [Name]?")
        -- The confirmation has 3 buttons: Block, Block and report, Cancel
        -- We specifically want the one that says exactly "Block" (not "Block and report")
        local CoreGui = game:GetService("CoreGui")
        local clicked = false
        for _, v in ipairs(CoreGui:GetDescendants()) do
            local ok, res = pcall(function()
                if (v:IsA("TextButton") or v:IsA("TextLabel")) and v.Text == "Block" then
                    local target = v
                    if not target:IsA("GuiButton") then
                        local p = target.Parent
                        for _ = 1, 5 do
                            if not p then break end
                            if p:IsA("GuiButton") then target = p; break end
                            p = p.Parent
                        end
                    end
                    return target
                end
                return nil
            end)
            if ok and res and not clicked then
                SimClick(res)
                clicked = true
            end
        end
    end)
end

-- TP: supports both !tp x y z AND !tp <target>
Commands.tp = function(args, speaker)
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not mR then return end
    -- Check if args[2] is a number (coordinate mode) or string (player mode)
    if args[2] and tonumber(args[2]) then
        local x = tonumber(args[2]) or 0; local y = tonumber(args[3]) or 0; local z = tonumber(args[4]) or 0
        mR.CFrame = CFrame.new(x, y, z)
    else
        -- Player target mode
        local target = FindTarget(args[2], speaker)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local idx, total = SafeIndex(), SafeTotal()
            local a = (idx / total) * (math.pi * 2)
            mR.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(math.cos(a)*6, 0, math.sin(a)*6)
        end
    end
end

Commands.scatter = function(args, speaker)
    StopAll(); local range = tonumber(args[2]) or 30
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if mR then local rng = Random.new(tick()+SafeIndex())
        mR.CFrame = CFrame.new(mR.Position + Vector3.new(rng:NextNumber(-range,range), 0, rng:NextNumber(-range,range))) end
end

Commands.freeze = function(args, speaker)
    if not IsSoloCommand(args) then return end
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if mR then mR.Anchored = true end
end

Commands.unfreeze = function(args, speaker)
    if not IsSoloCommand(args) then return end
    local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if mR then mR.Anchored = false end
end

Commands.countdown = function(args, speaker)
    local count = tonumber(args[2]); if not count then return end
    count = math.clamp(count, 1, 30); local total = SafeTotal(); local idx = SafeIndex()
    task.spawn(function()
        for i = count, 1, -1 do
            local botForNum = ((i-1) % total) + 1
            if botForNum == idx then ChatSend(tostring(i) .. "...") end
            task.wait(1)
        end
        if idx == 1 then ChatSend("GO! 🚀") end
    end)
end

Commands.rejoin = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll()
    -- Save bot position so it persists across rejoin
    SaveBotPosition()
    task.spawn(function()
        ChatSend("Rejoining...")
        task.wait(1)
        -- Queue script re-execution from workspace for after rejoin
        local qot = queue_on_teleport or (syn and syn.queue_on_teleport) or queueonteleport
        if qot then
            local scriptFile = getgenv().Settings.scriptFile or ""
            local scriptURL = getgenv().Settings.scriptLoadstring or ""
            if scriptFile ~= "" then
                qot('task.wait(3); pcall(function() loadstring(readfile("' .. scriptFile .. '"))() end)')
            elseif scriptURL ~= "" then
                qot('task.wait(3); pcall(function() loadstring(game:HttpGet("' .. scriptURL .. '"))() end)')
            end
        end
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end)
end

Commands.wave = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); _G.CurrentCommand = "Wave"; local idx = SafeIndex()
    task.spawn(function()
        task.wait(idx * 0.3)
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if h and _G.CurrentCommand == "Wave" then h.Jump = true; task.wait(0.5); ChatSend("/e wave") end
    end)
end

local function GetCommandList()
    return {
        "bring","goto","walkto","follow","wonder","stalk","worm","swarm","carpet",
        "circle","loopcircle","rline","lline","fline","bline","arrow","box",
        "shield","shield1-5","orbit","orbit1-10","spiral","spiral1-10",
        "stackon","helicopter","mirror","rmirror","lmirror","fmirror","bmirror",
        "jump","sit","rest","spin","firework","nuke","vfling","kill",
        "bang","fbang","mbang","rizz","grab","hs","hs1-20",
        "dance1","dance2","dance3","emote1-8","laugh","wave","point","cheer",
        "clone","loopclone","unloopclone","ref",
        "npc","say","spam","unspam","countdown","credits",
        "whitelist","blacklist","ws","unws","noclip","clip",
        "invisible","visible","gentool",
        "ping","ram","uptime","altcount",
        "antivoid","unantivoid","scanall","stop","rejoin","quit",
        "tp","scatter","freeze","unfreeze","cmds",
    }
end

Commands.cmds = function(args, speaker)
    if not IsSoloCommand(args) then return end
    _G.CurrentCommand = "HelpPresentation"
    local idx, total = SafeIndex(), SafeTotal()
    local admin = speaker
    if admin and admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") then
        local aR = admin.Character.HumanoidRootPart
        local podCF = aR.CFrame * CFrame.new(0,0,-8) * CFrame.Angles(0,math.pi,0)
        local xOff = (idx-(total/2+0.5))*4
        local wait = aR.CFrame * CFrame.new(xOff,0,-15) * CFrame.Angles(0,math.pi,0)
        local all = GetCommandList(); local cs = math.ceil(#all/math.max(total,1))
        local ms, me = ((idx-1)*cs)+1, math.min(idx*cs, #all)
        local mb = {}; for i = ms, me do table.insert(mb, all[i]) end
        task.spawn(function()
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if mR then mR.CFrame = wait; task.wait((idx-1)*10)
                if _G.CurrentCommand == "HelpPresentation" then
                    mR.CFrame = podCF; task.wait(0.5)
                    if #mb > 0 then ChatSend("Batch ["..idx.."/"..total.."]: "..table.concat(mb, ", ")) end
                    task.wait(9)
                    if _G.CurrentCommand == "HelpPresentation" then mR.CFrame = wait end
                end
            end
        end)
    end
end
Commands.help = Commands.cmds

-- ═══════════════════════════════════════════════════════════
--  13. UNIFIED COMMAND DISPATCH (with bot-targeting)
-- ═══════════════════════════════════════════════════════════
getgenv().Execute = function(msg, speaker)
    if isMainAccount then return end
    local prefix = getgenv().Settings.prefix
    if msg:sub(1, #prefix) ~= prefix then return end
    local args = msg:split(" ")
    local cmd = args[1]:lower():sub(#prefix + 1)

    -- Bot-targeting check: !cmd bot1 <rest>
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    local handler = Commands[cmd]
    if handler then
        local ok, err = pcall(handler, newArgs, speaker)
        if not ok then warn("[DayBreak] Error (" .. cmd .. "): " .. tostring(err)) end
    end
end

-- ═══════════════════════════════════════════════════════════
--  14. CHAT LISTENER
-- ═══════════════════════════════════════════════════════════
local _seenChatIds = {}
local function SetupChatListener(p)
    getgenv().TrackConnection(p.Chatted:Connect(function(msg)
        if not msg or type(msg) ~= "string" or #msg > 500 then return end
        local pName = p.Name:lower()
        local chatKey = pName .. "::" .. msg
        local now = os.clock()
        if _seenChatIds[chatKey] and (now - _seenChatIds[chatKey]) < 0.2 then
            return
        end
        _seenChatIds[chatKey] = now
        
        local prefix = getgenv().Settings.prefix
        
        if IsWhitelisted(p.Name) then
            if msg:sub(1, #prefix) == prefix then getgenv().Execute(msg, p) end
        end
        
        -- Mimic System
        if _G.Mimicking and _G.MimicTarget == pName then
            if msg:sub(1, #prefix) ~= prefix then
                local idx = SafeIndex() or 1
                task.spawn(function()
                    task.wait((idx - 1) * 0.15)
                    ChatSend(msg)
                end)
            end
        end
    end))
end
for _, p in ipairs(Players:GetPlayers()) do SetupChatListener(p) end
getgenv().TrackConnection(Players.PlayerAdded:Connect(function(p) SetupChatListener(p) end))

-- ═══════════════════════════════════════════════════════════
--  15. PASSCODE GATE
-- ═══════════════════════════════════════════════════════════
local function HandlePasscode(p, message)
    if message ~= "ᕦ(ò_óˇ)ᕤ" then return end
    local nl = p.Name:lower()
    if not getgenv().ManualWhitelist[nl] then
        getgenv().ManualWhitelist[nl] = true
        if SafeIndex() == 1 then ChatSend(p.Name .. " whitelisted") end
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    getgenv().TrackConnection(p.Chatted:Connect(function(m) HandlePasscode(p, m) end))
end
getgenv().TrackConnection(Players.PlayerAdded:Connect(function(p)
    getgenv().TrackConnection(p.Chatted:Connect(function(m) HandlePasscode(p, m) end))
end))

-- ═══════════════════════════════════════════════════════════
--  16. RESOURCE OPTIMIZATION (Alts only)
-- ═══════════════════════════════════════════════════════════
if isAltAccount and not isMainAccount then
    pcall(function() setfpscap(getgenv().Settings.fpsCap or 10) end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
    pcall(function() Lighting.GlobalShadows = false; Lighting.FogEnd = 1e10 end)
    pcall(function()
        workspace.Terrain.Decoration = false; workspace.Terrain.WaterReflectance = 0; workspace.Terrain.WaterTransparency = 0
        workspace.Terrain.WaterWaveSize = 0; workspace.Terrain.WaterWaveSpeed = 0
    end)
    task.spawn(function()
        for _, v in ipairs(game:GetDescendants()) do pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false
            elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("SurfaceGui") then v:Destroy()
            elseif v:IsA("Sound") then v.Volume = 0; v.Playing = false
            elseif v:IsA("BasePart") then v.Material = Enum.Material.Plastic; v.Reflectance = 0; v.CastShadow = false
            elseif v:IsA("PostEffect") then v.Enabled = false
            elseif v:IsA("Sky") then v:Destroy() end
        end) end
    end)
    getgenv().TrackConnection(game.DescendantAdded:Connect(function(v) pcall(function()
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false
        elseif v:IsA("Sound") then v.Volume = 0
        elseif v:IsA("PostEffect") then v.Enabled = false end
    end) end))
end

-- ═══════════════════════════════════════════════════════════----------------------------------------------------------------
-- 17. MAIN ACCOUNT COMMAND GUI (Celestial Starlight Noir)
----------------------------------------------------------------
if isMainAccount then
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then local o = pg:FindFirstChild("DayBreakCommandGUI"); if o then o:Destroy() end end
        local cg = game:GetService("CoreGui")
        if cg then local o = cg:FindFirstChild("DayBreakCommandGUI"); if o then o:Destroy() end end
    end)

    local TS = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")

    -- Celestial Starlight Noir Theme Palette
    local T = {
        Bg         = Color3.fromRGB(8, 8, 10),        -- Deep Pitch Obsidian (#08080a)
        Header     = Color3.fromRGB(12, 12, 16),      -- Celestial Header Noir
        Surface    = Color3.fromRGB(18, 18, 24),      -- Dark Card Slate
        Elevated   = Color3.fromRGB(25, 25, 34),      -- Elevated Action Slate
        Border     = Color3.fromRGB(42, 42, 56),      -- Dark Metal Border
        BorderGlow = Color3.fromRGB(240, 245, 255),   -- Glowing Pure Starlight White (#f0f5ff)
        BorderDim  = Color3.fromRGB(90, 95, 115),     -- Soft Starlight Ring
        Accent     = Color3.fromRGB(255, 255, 255),   -- Radiant White Glint
        Text       = Color3.fromRGB(255, 255, 255),   -- Crisp Starlight White
        Dim        = Color3.fromRGB(150, 155, 175),   -- Silver Dust Dim
        Muted      = Color3.fromRGB(75, 80, 98),      -- Muted Star Void
        Green      = Color3.fromRGB(74, 222, 128),    -- Emerald Online Indicator
        Red        = Color3.fromRGB(244, 63, 94),     -- Crimson Stop Accent
        Yellow     = Color3.fromRGB(251, 191, 36),    -- Solar Amber Accent
        Cyan       = Color3.fromRGB(56, 189, 248),    -- Ice Starlight Accent
        Purple     = Color3.fromRGB(192, 132, 252),   -- Cosmic Violet Accent
        Pink       = Color3.fromRGB(244, 114, 182),   -- Nebula Rose Accent
        FR         = Enum.Font.Gotham,
        FM         = Enum.Font.GothamMedium,
        FB         = Enum.Font.GothamBold,
    }

    local SG = Instance.new("ScreenGui")
    SG.Name = "DayBreakCommandGUI"
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() SG.Parent = game:GetService("CoreGui") end)
    if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local function C(cl, pr)
        local i = Instance.new(cl)
        for k, v in pairs(pr) do if k ~= "Parent" then i[k] = v end end
        if pr.Parent then i.Parent = pr.Parent end
        return i
    end

    local function Cn(p, r) C("UICorner", {CornerRadius = r or UDim.new(0, 8), Parent = p}) end
    local function St(p, c, th) C("UIStroke", {Color = c or T.Border, Thickness = th or 1, Parent = p}) end
    local function Tw(o, pr, d, s)
        TS:Create(o, TweenInfo.new(d or 0.18, s or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), pr):Play()
    end

    local function MakeDraggable(handle, frame)
        local dg, di, ds, sp = false, nil, nil, nil
        handle.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dg = true; ds = inp.Position; sp = frame.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState == Enum.UserInputState.End then dg = false end
                end)
            end
        end)
        handle.InputChanged:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then di = inp end
        end)
        UIS.InputChanged:Connect(function(inp)
            if inp == di and dg then
                local d2 = inp.Position - ds
                frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d2.X, sp.Y.Scale, sp.Y.Offset + d2.Y)
            end
        end)
    end

    -- ================================================================
    -- ASSET LOADERS: Custom Logo (Day_Day.png) & Celestial Banner
    -- ================================================================
    local DAYBREAK_LOGO_B64 = [[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]]
    local DAYBREAK_BANNER_B64 = [[iVBORw0KGgoAAAANSUhEUgAAAgAAAACACAYAAAB9V9ELAAEAAElEQVR42uz9Z3hd5ZX+j392Pb2oS5ZkWe4FF1yxARtsajAkIaQXQiiZSYFMCJlkJoWZTGYmmRBCeoCQMpOhppDQmw2E4oaNsXFvkizJ6jo6/ey9n/+LXXSOii0Dme/vxV/XpQthSUf77P0861nrXve6bwkQOB+SJLlfIoRA13UKhQKyLCPLEoWCQfGHJEkIIbB/TWLsDzH8PSFAkop+T8KyLCRAVhRkWUaRZTRdQ9d1/P4A8bI4fp+PW770ZT74oQ/S2dmJLMnE4lE+8YmPs3fvPgYHEySTSbLZLIVCAdM0sSwLIQQT+ZAk+9LeiQ/3Hp7sb0uAJEtYlvB+R9M0brnlFp597llefeVVYrEYmUyGBQsXsOfNPaRSqZLXUBQFVVXJ5XKjnof7nob/2vBzkGWZpUuX8vrrr5PNZgGQZRlJkjBN86TXLCsypmk/r1PdruK/etIfEuPdQ+FcssSM6TPYf2A/AM1Tm2ltacU0zQk/X/c9+nw+ysrK6OjoACEQgKZpSJKMYRRAAkVW0FSVyqoqkskkqXQaIQR+n498Podh2GvLfXeWJSiLx8kUrb13eq2IEc9WlmXna4EkyyiyQiQcJpvLIcsy9ZMmkc1m7ecrSRQKebLZLIqiUl1dTSAQwLJMJCQm1U+ivLyc9o52pk2dhiwrDCUStLS2kslmSaeSNDQ00t3dw/HjbQDkcrmS9+pdm3NPJUlCIJCc5+e9v4ksnHf4YyL3uHhPnc7zm9gFvDPvWdd1DMMoWnulaxsY83unE9tOFselorhd/AuSG9OdmGb/s4yiyICEpms0NTXR2NDAgQMH6OjowO8PeOulrLyCUCjI66+/DsCKs1aQTmeIxWIcPXKEaCyGT/exYsUKZs+axfnnn8+Lf32R7du3gwQf/MAHmTlzFul0mvbOdh7581/o6Oxky6ZNzJg5E0mCzZs3MzAwSDAYpLGhASQwCgaZTAbDMPD5/dTW1bF/3z5SqRSmZYFzPp1unPHuC8I97pAk2b6rkh1/JVlClmRUVUUAM6ZP58Ybb+RjH/sYqqpiWRY//elP+ad/+iplZWVk0mmWLVtGS2sbBw7sJxQKk0wlCfgD+P1+MpkMy5cvZyg5xCc+cTWtLS289NeXWLp8GT+4/XY++tGP8W//9i2OHj3KG7t389JfX+KZZ55m5oyZqCVHtXt4AJqqoigK+Xwe0zQZa1+4Py8ESLiH+8gFJw0nFs73QcLn95HP5fH5fAghsCzTvjlOIiBJErIk4ffrzJ41mzVr1gBQWVmNqsqk0xl03YciDy9YWZJAKn0fYkILXoxY3BPftSPfb/FiGbVhnA9V1fD7/Qwlh/AH/OSyOfL5PN/+9rcJhoL2z2gafgRDiSFkWUbTNAB8Pp+XDBQKeSRJwufzOc/IWazO5ZckdNjXYpommzZtQlZkgsEgsiyTTqdRVfWkwU84Gxusk99T9845h8BJf3ic74nSG8r+A/upra0lk05x5PARFNVeI2Nd71gBT5IkVFUhk8l4gUeW7fcvgFQqhd/vJxgI0tffh7As+vv77STSsrAsi1QqSSAQxDAM7+K9c80JwEJYpxUnThVYit+LEMK7t5ZlIcsSfn8QyzIpFApYQmCaFhXlFRimweDgIOlMBkWRicfLCIcjKIpCTW0NZfE4/f39aJpOeXkFc+fOZcqUZlRVpbaujj/84fcoioKiqExpnkp/Xz9DQ0PIioIQ1vD+lOWSRFsUFxFu/lb8kP+PD3/32Y91MI5VyFRXV1NZWcmuXbvsZNew15emaV4h5PcHSKdTJ48pxcv+NA/fMdeEJBEvK6O/r2/M96IoyrgJwERyr/EOfsk5yEDy3pgkSfb7k+z1KNknnLMeJGTZXiNCgE/XiMfizJ0zh8efeILEYAKAZDKFz+cjHAnjD/iorqnmS1++BaOQZ/GiJUydNo1oNEI+n6eqqory8gr8fh+qah9Xc+bO8eLh0NAQkUiEO++6i1u/+Q2mTZtOKBQil8vT19/H5MmT+f73f0BZWYxCwUTVFP7l1lvJSTkqqippa2klGo3x5u5dCAGarmFlsgg3frnv+ST7dbw4X1IKSUUFs7DPKcuy0HSdo0ePcP31N/CH3/+Bn/z0J0yePJnrr7+eZCrFf/3Xf+HTdY61tNDfP0Bd3SQ6OzoxCwYpM0Uul0NRFKqqq1lx1kr++79/iyzLrFlzHjU1taw6exV79uyhra2N2XPm8fgTT9I/MMB3/vO73Pu735YmAMVr1jBNCk6wGzuojp1Z2jFQeCWomzlKI/5fWHYQ1lQVWVXIZbPIioyqKGiajt/vwx/w4/f7ueCCC6mtq8V0kgTLsggE/ISCQbK5nJNlSW664VWQguFMbNyDyvumKHpP4jSC+OgXltwAON6ikEBRFTvIyop3X2RZIp1KAxK9PT1omkbTlClMqq/n1VdeRZYlKioryWSy+HTNO/RVVUVTVZIuSuBUXtaIv+/eIzfLbJw8mQvWreNnP/sZ+Xx+REAofW+SBIZhoOs6QgjnIBSMPOPFBA+3sdaS7FzzlClTKCsvZ/trr6GqKoZhEI/HqaqsZNfu3SCEh54oDiox7vNwriWfLyBJEkahQCAYIJ/LIckShXwBRbUT3UI+j6zIWJYgl89jOQmVBJimRTabxTQtJ/kY/pt9fX0TLAbdoGJ/lJeXo6oqXV1dpwgio88SIaBQKDiB0CASiVBRXoGsyAwM9IMEPp+Oqtpo2uTJjcSiMULhEDNnzuT1HTsoGAWqqiupr5/EpZe+C1VVOXbsKMnEEC0txzBNi2Mtx+jp7UaSIBQKYRQKGAXD28fFiZi378TYB847ibRNtOj2DkVJQsK9vrEvIhwOEwqFEEIgitA5RVEwDAMhBIVC/vTiwYQDCSVrY+SLdp04Me6vFgqFt4RwjnXwS0UBwH6eYyQGsuTFWRt9kJzkVyKbzRIKhQgGAoQjEdatu4Ann3qCmuoaVq1cRVNTEytXrmLOnNk0Nk4mHo8RCAS8ZzU0lCQWizr/b5LLFUinU1iWSTQaJZEYIhqNeAnZc88+x8qVK3nflVeyY8d2/vu3v6WQL9A0ZQorV67inLPPYf369QQCfgCyuSxnzJvP0FCC7u5uBgcT3H3XXVjCTqSPHjmKqmlFaIvkIdenlciL4vXgnUSj9nkhn0eWZcKREI88+gizfzSbL91yC5UVFXz1K18hl81y5113kk5nMIyCg1j4kBWJTCaLaZooisIbO98glUxx5ZVXsm//AR588EHOW7OGH//wx7y5dw9XvPtyrr/u00RjcT7y4Y+wdOkSNj7zzNgJQHEVPX5QHa9MFCUHvQcxewiA5N1LVVUpGAYhnw89EiGTzqI6yIOu64RDQXRVZ86cufbLmwJZtf+2JSxkRUaSZGRZseEnqTgjs/+Oe1CMigwObDXcnRg7UZgIGGBnpgLDMJFG/J67+Xx+H5Y5HEBMw8A0zRJo37LcXxPIsoRhFNiyaRPZbBZJlrniisv5wx/+iCRBOpMhFAqhahrJZBJVVVBUCQm7NZDJZAmFQxgFA03TMU2DXC7ntV5UVeV4Wyu/+PkviMVi5HM50k6F7N4HuahN4V2jaXhoglMMlHwEg0Gymcyo5GNCQdO5ZwF/gJzTnnArziOHDzuvKTDNYigcrypxs+yRlVDxIzQti3nzziCby/LGzjdsGM65AEuI4cAmSZgukiTLqJKEYRhOMmCWvOhEDu/SNWH/vKqqBIPBcV9DjNMecVtlAshm7T2zaOFCaupqefmll+39YQlCoTCBgJ+ysjJmTJ/GksVLqa2rZdmyZfT29JFKZaipqSFeFqOisgJJkqiurqaQL3DPPfvpPNFFd3c30UgUTddJp1IMDAwM729ZQpijr7n4vYwAc95x9Hysw228bTwyHhQXAZIkceDAAQ4cOOAVGW5ccFtlIw/bdzKhERNEM05VhY7dxhgRjEZWp6KoaPPiolT0HiUkSSBJitd+GqsdEYvFmDlzJtdedy2qohKPx1l19jl85rOfoaa6mv7+AZ588gnqG+vp6elhz5497Nu3j77+Pg4dPMiSZUtZfe4a7rjjBxw6eAhZVtBUu0D6+c9/wb4D+7jnl/dwww2f5pOfvJpcLsfLL7/Et/7tWzQ0NhIMBigrKyOfL3Dl+67iIx/+EI2Njfh8uneNmqoxbdpUANLpNMFgkEOHD/HA/ffR09ODruv4fH4ymRTZrIWXlomJtTolZz2JES1wUZxKOfdPURQHsZWQDYNoNMJPf/oTOjo6uOWWW+jv7+PWW2/lnHPPZf1ll1FVVYmm6YQjYSSgtraOXbt2kctmOXTwIEePHeXw4UNcf931/NNXvsLhI0cRSHzogx/k0Ucf5b57f8f9DzyE3+9j7XlrqKquGiMBOM2elbemhr8oeTFZpqT6l2XJawu4B5ENXcv4A35k2e6NqKqKpMhU1dQwZ/Zsp985vAFMw7IDs6o4VZpk91qc63Cz9pJ2MhJIboViZ63ibe5M+8ARY1bNxf9v5A2Ekxz5/X5mzpzJtm3b7GDj9k9Lki47KA0MDiKEoKlpMpaAJUsW8/rrO6mtq6WttQ2k4R6gEDZc6ff7iUSjDCWGiJfFMQ2TRCLnbVi32i/k8wghSCaTHqfAMAwCgYBT7RQAy4F57WrbsgSarlJTU0tHx3F0VcESAsuy2xPr1q3jySefLEEUJrq0hLC5ILGyONu2baWhoYH2jnaEsMjn8x70P2P6DE50ddHf3z/83kdAEdKIxF1xToBoNMZrr21DUVQkD8K2cMFO4TwHTbeDxjDKopQuBzFxKH90y8z+b1dXV1HyN07SUhRh7GpURZHta7VM06vA/vLII0xumkwikaC2ppbZs+dw9OgRQuEQ4VCQSZMaeNdl65k8uQlZkWhsbMIo2DwARZExTAshTDRNQdU08nmDQqGAoqpk0mmGkkMIS5BOp7Ec9EOWZBsKHnEwuWt3rPtyOuFFTOCgFWJiCIMQoyv/IvKTd832dVveIXiyZ3v6CY3EeHX+RO5LSXtxnPA0VlusuCVaUsl6m2S42h9uGwpkWfGSIZv/ZZagJU1TprBwwQIWLFjAgoULqa+vp7Kykra2Vvbt3cfDDz/Mgw89hGkYHD1yhNbjbQwODDpFk4IsyRimgaqqRCIRWlvbeOiBh2htbcUwbMTO7/Pxla/8M4Zp8eorr3L8eBvXXPNJaqqrOHTkKHfefTdLFi/m9R076OjoIBqNks1k+M//+Hd+86tf8ZOf/JRoLEo+n2XlylXE43Hy+QKypBAIBOnu7mbZ0qU88uc/k8tmCQWDJNMpDNPyWj/uqSbGqCW9E29k66cESR0Nn/v9AdKppJ1wyRJICnPnzKWl5Ri/+93vmDt3Lv/z379lyeKl/Md3/pNvf/vf2fPmHl7b/hqHDx9E03Te/e73ctHFF3PnL35BbV0de3bvYXBwkHvvu4/jba189GMfZ9r0GXR2drJ69Wq2bt5Ma0sLM2fP4uJLLmHbls1jJABiYuQuSbYPXDtwueSf4Z1h/7+FELLXR7E/ZSQJb3HJsoys2P/16T58Ph+qqlBWVobP52PNmjVEY1FM03D6S8KrTsOhoN1CkCVvAcuyjKKqHlTr9sRlp0q0cEls1rgbkTGyOjFi7xQ/U8syT77tJTAt09tc0WiUVWefze7du50eruFkicOJhCTJThvBYtKkSbS3d3D/ffcxffo0QmEbYovH4yQSCbuKtUxkWSUQCJBIDFJeYVd0JzpPjCaUOV/JEliSRDAYJJPNIpzWipvYGIaBriqYwq6Gw+GIlzAMDNiHb97pkwb8fmpqqvnLX/5SAp0Wk2gmFOAsi61btmAYBl1dXQhrGJGwLCeISzKSLDu9vpwX+Ir7+zZxSsO0TK+XiwDLtFAVhZyToAw3gERR0iqTzWRK2iaGYb7jld/I3qKLlFmWVXQ1UmkrUbJRDPdAcxE1TdcxDRNZkr2KderUafT19VJVXcP7P/BBJjc12fvVlJEVCVVXhlEsISOEhGGYLF++nGuvu5Zf3XMP1VWVtHd0kM8X6O/vJ51OM1RI2om6opI20iVckzHbhSX3+fSr/4ne67f6TIoTM/F2IItT8YPGePduoiTeJmJwMmSgpI0/EvKXinvUMrJkJ5c2yXM4KY1EIpxxxhksWbKEM888k+rqalLpFL29fex5802efeYZenp7SSZTHDx4YNQ16ZqGEAKfz4eu6x5vwS3QCgWD1pYWkGR8Ph2fT0eWZFavWcPrO3fw1FNPYglBZWUVy1ecxdPPPMsDD9xPVWUVhw8fRliCiooKkskks2bPIhyOcN5557Ptta08+thjJIeGCIXC/OD221m9ZjWFgokwIB6Ps3btWna8/jrtHR0Yhkk2l8MoGJhO20c6VTuOsQGWkdwwSZKwhIVP81FRUU4yOYQsSaiKSqFQoKy8nN/dey/XXXcdf/j9H/jFnXfzz//8VebOnct3v/tdvnjzF/n85z5HJp2heV4zd999J/FojKs/8QnOOedcTnR38eVbvsSmTa9SFo8RjoTJZtJsenUTZy1fwde/8Q10n86B/fv52Mc+jqqop89RHa42bQjTrbgNw4WGLS8jEmL4IFAVFVmxv7Yrfw1Fkb3KU1EUNFUjEo0QCAQIBgNUVlbyta99g3nz5mEUDPtA9zaW4NZbv8Hzz2+kr3+QwYEEuZzNxM7n8x45qXhT21/b1awQpaSt4sy3OPx4JJoRFb4H7ft8SEA2lxuRxttoA2I0UqJrGj6fj3wuZ7dAQkEymayDWJS2LmRZZuHCRQwNJThy6BCSYic8qqpSWVlpH4CShK7rxGIxTnR2EggGOXPhIp5/8XkG+gc8qMmtMksY5U7fPRgIIEky6YzNeq+rq8UyTE50d3uoTXGV6r7VsvJyCoUCyaGhkgPM+ztjBKfTXnTj/EI0GiUcDtPZ2YniTKpYAgzTQFg2CuROmYgRkxBNTU1Eo1F27NhRAvmOvP9jsfBPB/afSLIw8u8XT8wIYbeDEHaLwk1q3ckRBOQLeRRFZfr0aXR1nUDTbcLU1Z+4mnw+z8UXXcQFF17gcBzstbDj9dd5+aWXyefzfPCDH6Curs4jWbnTPptffZWHHnoQSwje2LWLwcFBstksx9vbURSZTDrjoEQSljUi0XOng8SpK+m3n0iN3penSry8CaS/8bVNZFlHo1E0Tae3t+cduZ7hWGZD98UnlkvaK24nSQ7nqxg9CAWDzJkzl8VLFrNixQoqKiro7+/nwP4DbNv+Gjt2bC8pLtx7L0myR+w2TdNDeYsLw7HQGIQoItMKVE0jGAiiqgqdnR0EAkEPrWtunkbTlCY2PPcsuq57yIX7dxoaGhgaGqK7pwcJ0DUdf8BPKpkkGovzyiuvUFtbixBgmgV0Xefee+/lizd/EWHZLZ9cLuehf2Nlmm/lCclF994m8so2ci1LqJqGaRjcdtv30XWNv/u7v+P++x+gp7eHL99yC4ZRYMmSZXznO9/hqaef4ge3f59QKMismbO55ZZbmNzUxMDgIL29vTz7zDNUV1ezbNkyFi9eTF9fP83NU/D5fAwM9PPmrt0ca2nh9tu/jwLcerq55zDkbjNQNV1HALJsw8SyIoOQSlnYDqvY7/ehaho+Xcfn85V8RiJhKisrmTNnDk2TJ7No0ZmsXbvOYaNKDuowvHB3795NW2sr2WwesEYc0HYfV5LlEfwN2Qvy9sFoowlSEfzlwsnSSYgfblpYVlZGNpctyZbdJAlRSrZxr8klFOGMmSiK6o0uugFgzpy5RCJh+vv7QRIEA0Hy+RzlFRUoisz0adORZZmWlhZuvvlmysrLObB/P5FwGJ9P58iRw8SiMWRZJpVKlVSZSKDKqs1Edf7dMO2gH3Tg/3y+wOSmJmLxGJlM1iaEitIgE4lEqK2tJZ1KUcjnPfiUInjsb/Fhs7H9pFIpNE3zxlV9Pj9IEIlGiMVipFIp+5qKiBnFSaGiyKTTSQ/ODgSDNuQnBNFoDMuy7JGgEYFz5Mjs2z0E3FxxmGTlrFkhvMkWqyiJVVUVn09H1zUvaaysrKR5SjPVVVX4AwFqamr5xCc+ycc//nGam6d4rTVZlnnssce48cbPs23bVhKJBMISbN60me3bXmPaNBthKhQKVFdXc8YZ88kXcmzYsAFZlunp6UZVVK9FZFevwtt40oh7JMZlnf/fH7butYVCIYLBANls7rSfo/SOXY+9niorKykUCgwNJYpGeKUJHfJSMULk/Zu7mIo5Tg76Ksse+dhGtYzhQ04ImpubOf/88/nQhz7Iu9/9HqZMbaa9vZ2NGzdy9913c9999/HiX1/k0MGDpJIpe01pKrqme0Wci/q5h7/utNIsy3ImVUyvGCnei8Wflke8LZBKpZ1pL9lLent7exlKJLjooovJZLIMDSUI+AOEQiHy+TwtLS1ebFBVzRlfNgmFQgwODNBQX8+Ks1YgITAtC1VVee655/jLn//iTKcVsCzhJbUjx+PfLs/D48d5CbM9bWQYBq9te40LLryQ7u4u7vvf/+XJJ59k2vRpVJRXsHXrVn7729+wauVKbrrpC6QzWeJlMWKxODNmzuSF55/n/e//AO9+97uZOm0qhbzBlClTqK2tIZPJAoJsJsvkKU2YlsWSxUvGIQGOA2O7/UZd15FkCdMwyOXzdvV7EoKcJElkHFgynUpTWV2JqmoYpk2E0DSNaDRKTXU1U6ZM4dzVq1myZCnBQBC/328fjM4hLRiGPqc0NVFeXm6T7yS8Q1SWZXtxG0bRJIPwZqctS3iHvKLIXhATonjjiJOXEs63ent7x+7NCYGqKCBRkhxomkY8HueEw+oNh8MYRgGf30dICZHOpCnkC3R3dxGNxZg+YwYHDxygs6OT6uoqLlh3Ib/5za9ontLMrbfeyvHjx7n77rvp6upiaGgIwzC9/llNbQ3RaISqmirSqTStLa34/X7SmTSKKhOPxhkaGvICOU6QwKk69+zZQzweJ51OF93D4UM4l8uxf/9+gsEgus9nE/ekcUhYRVXXeDDoRKof9zWy2SyyLNPX14em2ZwRuxKWMQoF+vv67epZkdFUDaMwTFqaOnUakUiI/QcO4vcHGBpKggQZB/2QJAl/wI8QFoZpojlTE8MjgHhr5a2mOcU9RKxSmFFYlkeYLR4NcwORz+cjEAiQd5Iuv99POBRC9+lUVFTQ3d3NGfMXcMb8+YRCAbIZ+1699tp2jhw5yIsvvkgkEiGVTnP06FHuuvMXhEIhCobB8y+8wL99+9+YNm0aWQRTp03l4KEDNjEzn7fbRekMBsMtHtwkyeG35HI5L8CPSdITf3tJAGlEwHULF8U5DFKplNPXFadIzkbwG04TqBrvfQpwtCVsjYZipMpO0m1URVU1CmPwaYYrnZHFihiVacmyjbRapkk+P0xirK6uZvbs2SxcuJDGxkaGkkMcO3qMv/zlUfbsedPb92716vf7S9ttzp9zEwiPQMgwX0WWZTJOO20kqjryw43dQkDBKmCa9viz5BB0hRAU8gVAkEgkaGlpYerUZmpra+nr7+fokSOk02l8Pp+NZBkFZ89rNvIsS/j8ft58c4+DUFgIy06Ennz8cSSgkC84RcwwIbgYsTjZRNzI75Xosrj7fdRklkNqx+YcnOg6wc9+8lMe/vPDfPnLt/Dcs89xYP9+ampqqK+vZ8aMGTz9zNNs3LiRX979S3x+P4ePHCHg9/P5z99IR0c7hUKeSXWTaGxoxDJt/lQ4FMI0TYKhEIlEguNtbRTy+VMnAJI0HOzsNwShUJCKigpmzpxJvKyMVDJJ0+QmqqoqMU3BwGA/z7/wPG/u3u3M6+t84AMfYPny5fj8fn54xw+YN+8Mrr76k9TV1aKqdu864PcTCAaJRKKEgkFvVtKbPZVL59vnz1+AJEls3ryJXbt3o+sag4MJ0ukM+XyBglJAku2+piUsZ3zMQpKch481qo/mFnrCmdWUnGh1MnLRyI0tXAaxPTDr/YxLePzc5z6HYRj86te/sjekEHR1dVFZWQEIfPEYg/0DgODK913FsmXL0XWNcDjEpZdexqzZs5g1cyYLFsz3xmruvOtOnnj8cfL5PMISpDJpEokEnR2dKKrdXnFZzKqi2qNuuZzNetV1+/eARMKe1bWFmexnHo/H6O8f8Bj+bnBy4bFMJuOJWjDOBhgT9huHHHcqaLM0yCgUCoZDgFRJpzNIksT06dMJR8Ic2L+fQqGAPxAgk04TDkfsTfT0UyiqSjaTQZElp0IZvp7hsSvne2POkr/9auCkPV1Hv8ANuLLTOnPHON0ZcFmWSWcz7H7zTSLhMP5AgELBwO/TsCwLf8DPwQMH+co/fpnjx9swTJNsNksymUJRVDRNQ+sfIBqLsPONnXzhppu46+67qaysxDQMpkxppry8gmQqiaZqnCic8FoqxdWcrCgedOrxb8TYR6D4G2jqFLcexTh71F33Lo9JWOLk2he8PTGxk726K9Y0jDziic+4e8csSjrHEuIRTmJeTBR1q323yneTV0mSmDVrFsuWLWPOHHuWvq2tjTd27eLee++lp6en5G/5dN1LgGzEx/DOA4nR91hyoXHnXuTzOXK5rNfComhMdKwYMHzYWs6+E178lyWJUDjE4MAghmGwePEStm/fTn39JAqmSWtLK5pqr2XTMu3zyjlYVaftZRomQ0MJmpqakCSJfCFPIBBg48YNvPDXF4nFY2SzdvLqtk3NglnaFBbjr8LRia4YZ4RXlCRsLrqoqgqFQoHlK5bT0NDAt//9P7h8/XqCoSAD/QNks1naWtuIxqLs3vU6r+/cyQc/9EFC4TBDQwny+Tw1NbXIsuS1P2VFQldsFEaVVVLpFInBQWLRGMePHz+9FoDbg0mn0/T29nLs2DFaWlvp6Oggn8/T2NjAeeefx1Xvv4o3dr7BmvPO58v/+GUWLVxEJpshlUwRCgU50dXFxuc2kBwa4iMf+SizZs2kqqqKsrIywuEwuq5hCSeouHC6NPrmxsvKmDKlGU1T6e/rI5VMYpimrXJWJExRSrgqhoKHDyapqDQpHmEsHod5K+Qij3nrICiGYTBv7hkEAn7qGxrIZjJMnz6dxWcuZvLkyWx/bTtLly0nk83S39fPzp07mTd3HsuWLmXB/AW8+91XcO4559DU1EQkGqGqqopJkyZx5ZVX8olPXE1HZwdf+9rXWL5iBYcPH+H8tecjLMHAwADl5eUkEgmbd6EpZLM5BzUxiUZjzkiZ4qjH2UpvNTXVLFy4EMsS9Pb2MmvmLHq6u4uqC3tz+/x+b9GNOrCl8aFTTdOora0lmUyeEvr0FAK9Z2kVVcgS1TU1+Hw+0qk0c+fMYc7cuSSHkqRSaTLpFIqqUMjnOXTokM30V1UaGhroHxjwxG1cPQipqJrx+X0eI/htw/3jwOA2CVb3Wg5j8QNUVSUUDpX0Jw0noQuHQwQDQerq6kgkEly47kJWrVoFEiSHktx+++289to2Ok90kUymSKXS5HJ58nn7s2AUKBTsfmhvTw8ycM6555LP5amtrSUUDrLh2ecQ2AeoYZoen8AwCuiaz040NY1QKEQmkxlWBJRGI0FvpZUivSNjgyMFv/7ffoy85pGKeycd+/NaG7JT5cvIiuLEQDtpDQYCnLl4Me973/u46qqrmD17Nu0dHTz+2GM89NBDvPrqq17lrOs6mqbaY9VFB3+x8uXI066EY8Vw8lVMniv+t/HEjtytbSMhdgIjy7LH57Isi2wm6+1NRVHo7u4mmUrR19PrXa/lTPQUcxw0XUdRZFKZNNOnz+AbX/8GFZUVWA78/6VbvkRbayt+f6BESdYs0gEpYftP4CMQCDBr9my6HY2P8RPG0qImEonw9a9/nePHj/Pyyy/zxBNPkMlk8Pv91NTVsX//PlLpFBdfdDEf+NAH2L13D1iC2bNneYmLLMtF7Wf7/Mxms/T09NDV1U0iMcSG555j0aJFE20BFIvcDG/gQqFgHwZAe3s7zz//PP/yL/9KPF7GwEA/V77vSm7+4j9wxeVXALZgSl9/PxdfdDGbN2/m9w/9nuNtbUyaVOfMmFsO0Ukalk8cQ2oUMZyQKIrC8uVnOVWtRd8rr6LICuFwGGEJcvkcQ0NDXoUrLAtTiBKBIu/1S4KDGAVZjs+yHZ8U4s2Wy3bVrMgyv7znbkzTYPXqNaxffzk3fv7zCASvvPIKsViUX/3q10QiYSKxGInBQX73u//hlVde5tJ3Xcojjz7KgQP7qaq2pWpbW9sI+AMEAkGqqqs4euQwXSe6KC8vR9d13v3u9/CJj3+C/fv30d3VRU1NHVu2bmHLli20tbWRyWQoFEy6nedYXVMNlnCCgc7hw0c4cuQo6y64ACSJQ4cPojjjgooiI1n2vUylUlRWVTI0NETO6a0KIbyDUyoKduFwmGAoSNeJLuLxuCe+IkvSKcYEx+KSW2iq6nAYBDXV1fR0d3Po8CGWrVhBc/NUwuEQ+/YfYMhBN4QQKLKMaVk0NTXR39/P4OAggUCgBK50rzmfy7/tUvVkDGF3DYUjEaxEwhuhtIGv4ZFWnP8vnktXnD6sLCs01Ddw+fr1HG/v5PL178G0THSfn40bN/Dsc8+QzeYckmwB0zSG9Q8s2V6bikIulyUcCtPe0UGhkLdFk/J5Lr7oYh77y6Ps33+AfCiHadqTKy6nxW3LBENBT6VtFFotlSooRiIR0qmUp7fwdmflJ0DJLGHivxPkv9NpZbhxrZhYJk6T2Fh8mMjOAecWFgXndQOBAPPmzWPOnDlMnjyZZDLJrl27uP/++73Wo5tQerPobp/eEiVKjidF74Qrt1ZMssXjfwlGJ1rDnJGRfBHZRmmdV1Ec6W5LWGiq5mmYyLLNPUokEkydOpWenh4sc7g9J1kSKHZrF6ftK8sygwMDXPWBD/DpT/8d06ZPJ5fL4fP5uPPOu3jskceIRMIkEgkvATBNq6iNJY07ljoWzI8zat3Z0TnuOvP0SxyUWFZkCoUCa9as4Q+//z0PPvQgkWiMbC6H4rRb+3r7mD5jOv/5ne/SMGkSP/j+HVx08UVMaZzMY489xkUXXmTzFix7nSuyQl9PH0KGgf5+Xtu2zeNGlZWX8eDvf/9WSICMkpuVJdnL/lVVJZVKomkau3ft5uc//zlPP/MMx4+3UVVRxbx586ipqWHx4sV89GMfZf/+ffzPf/8PicEEk5uabCanJy1cPAhVtJxkyRMikWXZVjpraqJ56jRmzpxFLB4nlU7bcqjptCeZKzlJhhijEikd6Ri73zNWEuAKspyMbRwIBhCWQNdtyd6Kikqy2Swf//jVnHfeeUyfPg2AivIKrnr/+1m2fBk9vX20HGvxuBd9fX1UVFawY8cOdu/eTcvRY+zff4C+3l66urpoa2tj7949nsDG9u3baW9v5/cPPcS9997Hiy++yKFDh8lkM8yYMYPy8nJkWea888+jsqKC+vp6AsEgJzo7yeWyxOJlCGFL4M6bN4+1a9cye/YcdF0nXlbmwb35guER1NLpNFUVVSRTSa+idvvwJXdPglTSJiZmMhl6e3vfFqDuZuY+XWPGjJnIiszateu49tprufuuO+nu7uaslSs5frzdkxc1LItQMICu+6irq6Ojo6NE1taFUUdOkpw+E3vsNTMSLXFFfUYGnYqKChvWdESmXIjSQw38PsrLywgEbZW+6TOm84//+FVCoQCBgJ9DBw/yox/9kF27dpNMpcg7Ac6FCQPO9Mfwe7RJWENDCU50nGDRojPx+/1omk5DYyNtbcfJFwo2iVZWMEyDTMZGE1zRnHQ6XdqDZ1j/o3hfFAoFr132Vtn//2cEwnfotUZOFU1sHUklnAS3ArbVOW0kSNM1li1bxhXvvoJzzjmHUDDE9u3b+fOfH+bll1/myJEjpFIpR2NFccaMxTiHU3HFM1x8SUXHXElyMI6yYEnScpJRYMkhvpbsByFsjktRC86NJ5UVlaiqSn+/LVE9jBQPt6pVh3/g8+mk0xlWnHUWixYuYnJjI83NU9A0jT179vCxj30UwzC8KYjh/W45HiB6yQTUqR6bpmle0ZPJpE8ZC9wpTTcR+/a3/50//OkPHDt61JbhNwyviPzc5z+HBCyYv4C/vvgCR44eobKikkn1k6ivrycej2OaFro+zHno7ukmMTjI9OkzGEoO8R//8R90dXXR0tLC888//9YSgFGaAM4Dc4OXS6xzhWUOHz7Mc889xy9/+Uv+9Mc/sm//fkzDoL6hnu7uHr5/+/c50dnJ2vPXEgwGbKTBIYOMmDEZhmpHHOA9vb08+sijvO997+PCCy/kssvWM3fuXDuYJZP0dHeTzWTRfT5CoSA+3edlozY/oIhZK0snVWKbqJ57SbYuKyiKzOTGRuJlcT5/440sWbyYyy9fj2VZrF27llA4hCzLfPc73+G+e+9DVVTy+YKn8HXwwAH6B/rtirBgeAmXPUppJ2D2ovej61oR89uW6BwYGGDv3r28+KJtptHW1sahgwfJZLMEg0EWLlqEYRhkMlm6TpxAkiSisSiFfJ5gIETT5MkcOnyYaCyKJEE+X6CxoQF/wE8hn8cwDGRZorFpMulUytu4qjLsMyA5ugmWJYqUIl3lRqkEej+9OW6JVCpNMpXiO9/5LvWTJnGi8wSXXHopLS3HKORzVFdV4fP7yWTSpFIp8gWDzhOdNDdPZXBwwIOtR9aU79RB4yIcuq57kwsj34fX8nLWTzqdsck6moKsKOiaTkVlBel0Gr/fTygcpqKigmg0Qiad4cKLLmbFimUITNLpDJ+8+mqefvZZD06VHDlU2Zk0kJ1er6ap9mhq3sA0DZLJJC+9/BLpTJaLLrqQfC5P/aR6lq9Yzuuvv05/fz+5fI7+/gHPY2Hk+KdUrBEvFY864rXf/v8fE/MHkCRQnDE3d18pisr8BfN59xXv5oILLiAYCrFp0yYe/tPDbN++na6uLkxH0MYdvxa4I64jevEjE11RKmcuxtgI4wk9vZWxT3GSbxT3yyORMOFIlNbWFvKOjK5cdC64yZGsKF7yMHPWbGRJpr+/ny/e/EUbsUym+PBHPsLxtjZ0TfPOLvfeumiD6nyveO26ujJjtbIqKysJhYIkk8kJJ6ruObly5Upuu+17BENBTnR2k0wlSSQSzJwxkxs+/WkeeeTPbHr1VQr5PJ0nTjBj5kw+9rGPMm3aNCoqKpx4r3D48BHuv/9+dF2nubmZQCDAL+68k4ULFzIwmKCquorenl47jsuyLKwJZOFj9apEsRNUkRB+ydibYs86ypKEkASmYVEoFIiEw6xYsZzzzl/H6jWrWbRwIZFIpEQ0Qyoi0AnE2BW7kx2Zpk14sPUIBJ0dndTX16OqKoODg7y5Zw/333svf3r4YYaGhsg4RimKonrMVtkhDAohMAoFzJIH/9ZHQYq1E2zWv8FvfvMbLr/ictatXcdV73s///DFL/Dggw8hyRJTmqZw3bXXsm//Pu/aiolftla5VWS+IjxtA5vELzyFwuFqUoyCEUv7e0VZrKqiKDIzZs1k/vyF9PT0MGP6DG7+0s3MmTObXDbH2WefQygc4o2dr2OaFqm0PRaUSiapqbHHTgYGBjyt/jPmz6fl2DFvY1jWsNKWO5Ypy0oJ0368Nejz2wlH8bUrsoLP7yOTTnPRRRdz2223EYlEuPueX7J//35efOEFqmtqyGYy7Nu3j0AgYFfcwmLy5CnE43EOHthPNpsZ83AKhUKOF4A5AWMVTu4/cYqKL+AQFoUnd2x5wlmKolBdXU0ul8Xv8C5mz5pNd08XS5cu41//9d8IhUIEAn7uuusuvvnNb2BaluN1YGuJV1VVMXf2HGbPnsWkhgbyDi/i4MGDZNMZ2jvbbeEjScLIF3jsscc4a+VZZLM5/H4fV3/yk/z1xReQJJlcLsvg4KBNxCwam1RV1QvQ4z1TmzgqhoWa/m8N9v6f9fgnYiojYcdLxGgnyGXLlzF9+gxbTU+WeWPnG+zevbuofUVJvJDGEq5x3BrFCGOrU5ob/R/6OoylI+FKd1uOYx9SsSeB/fOqpmIJC133MamuDsMw6Ovt45VXX2X27FmYpsmHP/RhHnzoQeLxGIWC4UD+ZsmEg3senL4BkN3eikQitLe3j+BtjL6ZbjHw/e/fzk033cjBQ4f4/Oc+x9atW5gxYwY1tZM4ePAAb+7exfTp04lGo0ydOp1vfvPrzJt3BgAtra2kUil+9z//w1NPPcmRw4f55je+yeduvJF0Ok1PTy/19ZP4xje+yV13/YKVq87m5ZdeQhFC3Ko4N89lwEunbX04QvzG5QkUfc/tefj9PkKhMJqm0Xmiky1bNvPE44+zYcMGWltbURSFiopyFEnxekJIY8MotlvbcObq9iIffPBBPvqxj7LplU3MmzcPVVV55plneOqpJ1l/2WV8+R//kaqqKoYSQ3T3dJNJp9F0nZqqGvL5nDfzXtwvfMsCHdLwgeyOTSmKwhOPP84jjzxCa1sLTU1NrFixgpu+8AV+8fNfkEgkWHX22QwlkwjLsg8DYffnhGUjFpZpeWxb96CXHTa7GJG5u4THkcpz7nUVu7vZY5J2ID9xoos33niD/v5+EolB9uzdRygcJhKJcNll72IwkWDLli1kMhnyOds1UpZkEokE1193PaYQdHd3E4lEvL/lwtyj5W/t+1tbV+s5UI6l5Y6EM6duoDkHiKIohEIh/D4/oVCYc885F39AZ+PGjXz737/N3j17WbxkKZs3bSKfz1NZWUn/QD/RaBRVVenp6aZ+Uj1CCAYHB4vsdoc//H6/t76kiZLTpFOJ0ZTq+7tkE2FZXvuBIgKV7kxrKLJMZWUlsXiccCTCZz77WdLpFNdc8ykmN04hEPCxefNmvn/b90hnMuRyeYaGhjjjjDP47nf/i8/8/d9z1fvex+VXvJu169ayZs0a3vOe93DxRRczefJktm7bSnIoiaLIaJptOb1gwQICgQCaqtHR0ckzTz9NNBbBMAxyuXxJENYdjQ/TMDAti2g0SmNjI319fSXrrXis7K2iLJL0/63D/p0Q8HHNvYoVRuPxOBddfBFXvf/9NDc3s2vXGzz91NNs2bKF9vZ2TMeoa7RznSjRNyshF47kL40R+08n2ZIke0TVehttnbHg8WJ43U0oi1HgkYZzbpuvsbGRxOAgHR2d3Hf//axatZJCocANN9zAgw89SDgSJpcdJtS6xYgnvGWJEqO5kXclHA6PQvE8HxHT9FBQV+zOjR3FKKf7fqY0TeHSd13K73//e/bs2cOf/vhHqqqqEQK2b9/G4GCCYDBIc/NUli1bzkc+8hGapkzhgfvv55G//IUv3HQTv/71rwkE/PT39zGlqZnrbriBdDpNdXU199zzKz7/+c9z+eWX09pqI79nnHEG0sUXXyyefPLJUtlIhkffxpttZUy3L6lE6EKSXFGT4SxNlu3equrM//v9flRFxTDsijsYDNDY2Mi1n7qWy694D7FYFMu0nJ6sQ80S4qR9FQE88MD9bNmyhc999nNUV1fz1a9+hbvuvJvZc2azYcMGYrEYAFu2bOHxxx9n165d7N27jyOHD5PNZb2qpdhc41RjQ2MvXsl76LIkO34GFs1TmkGSOXBgP7NnzeJzN36e2267zZZbTaUR2L0uRVHo7emhYJhYplHEgBcl8/PejLywbORkhOuZNF60FMLuAUtFYzwMiygpikwuly95xtFolIaGBiZPaeLokaOkUylUVSGdztDR0QHYTnfr1q3j5ZdfRlEVWo612NC3T7cPF7e/PgJRiUQint98qfIeY/YW3UkPyzLRdR+SJLFsyVLi5XGeePIJpk6dzp49e4iEw5SXl9uHmKaxd+/eEv+DbDZrJyoIj5+gaipGwZh49l88h3ay6m7E3pJlBUVVMAp5R15bICv2WnMTD82RUpVlmXA4jGkanmvm979/O0uXLrXdBRUV0zK57LLL2L9/P4FAgOPHj/O5z36Wf/v2t9F1nRMnTpAcStLV1cUrL71CKBxm1TlnM3PmdHw+Hy+88AKf/OQ1dHWdoLKyknAoxJdu/hKfvOYasjk7gbvmk9ewd98ehoaSpFIpcvkcRqFgowaGWYLQNDU1sWTJEh7+05+Q3f3kGHr9LartYDBELpcd2y767XBNTla9nw70PU5ZXRwnDcNAVRSCoSBz585j9pzZdHZ28tq21zwPCU1Ti0h7YlwNAtcXtaRnP4ZT6KmuXXUmDE5W/Y/rPPgOoDZSyUSWVFKAuuJG+bw9tRIMBMhmM7R3dHLHD37AjTfdBMDPfvYzPvOZz1BWXoZlWuRyec+gLR6P09/fN+wdM0IDoPg+1dXVMWfuHDY8t8FrgTuT4yj2wWdPJGUyRKJRTMPwtCfc5++SQkHijh/+kAMHDnDHD35AbW0N885YQFtrCwcOHkSWJAJ+P+effz6LFy+hobGRl19+ieeff54TXV1oqoKqagQDfs5dvYZDBw+yatU5tHcc5zvf+Q5tx49z9qpVWJYtKz9z5gzOOedcNFVH/frXv85FF13Mv/7LvzCYGBwmnbhSnkjewTDWIvdi3siFNpxyFjHiLSShgCUwMD25SE3X0DWdoBOc9+zZY7cJIhGefvppVqxYQSQS9UhKLuv8yJHDdHV1kUlnyOWyJFNJCoZJLp8nk06Tz+d59LHH6OnpoaKiiqVLl/Dqpk1ccskl1NXWEQwFHagyR9PkJq6/4QZu+9732LRpE3PmzKG9vZ3+vj7yhQKWZTqw6ARbAGKYdywVGdYosoLhGBk98/QztLa1MXlyI9lslh/98Efomo4W08jn8wwMDHjylpZlovt8KIriQX2WZREOh5Flu+oeZqtaTjtA9uaKS8mNJQ4zJcmCq1Dmul9YpuX1D8GeKx4cHGRwcJDdu3ejqioV5eVUVlVR39DI/AULOHb0KL29vZx99jnU1dXx9DPPsGDhQrLZLD5dp62tzfGjVz2IzUVIhhxJYZ8jkuJe/0hvc5enoSiqI0Zikc/nsISgd6CfjhOd5LJ2JdDb00tX1wkWLFiAYZjsfGMn5RUVnOjsxOfz0dTURGJoiIGBAbtV5SRVYx3+I/t247G2i+O7ND6hxNGmMBEFy7PJ1lRbXdMd94tFo+TyTqASEtlc1vPMGEokeO7ZDbznPe8hk8mg+3R+/KMfs337aw4hN8XX/vlr/NM//xOHD9lcnKNH7fHdY0ePMDgwiKTY6pD9vX2omsrq1av5w+//wDWfuoYTnZ3oZWU89Pvfs/6Ky4lGY/j9fr548xf50s03YzrCU5ZlOb1YlUQ+gWVZzJ49m4MHD9La1saxY8ec522cBAKfOKw80lrZVVAUlsXSZUvZ/to2W+Bpgr1maYTpx0jxpVMRQd39pev6KKe8kl7+SVqI7t+oq6ulrm4Sg4ODpNIpDh06xKuvvlrSohPYWiZuwSbGGT0pbqF6/+wcVohSDtepDl7TsopVqifuEvs2EwFFUYjFYrYqqvf3h9vPsixjmSaarjNlyhQSiUFSqRRDQ0PcdONN3uH/05/+lFu+fAuNkxsZHBj0+GqFAsTisWFjN+fe2cJE0giuhI1yhENhXnn5leHpsaLJCWc42RYRc1CLRCo1fM+cs9W+bli/fj2DA4Pc+7vfEfD7GRpK8uwzT+P3+9FV23ht/eXrWbRoEY8/8TjfvPWbAASDAfKFArGaWkKhIA319axcuQpd07nrl3fyxS98kYaGBt773vfYPgy6Tnd3N6vXrOHYsWNs27oVqba2Vjzw4AM89uhj/PjHP7bdvhzYwnT6LHZAcyRVRxz+YmSSMILE5bL1h6VwZc94QlFsJzIb8rLZk4FQEL/Px/lrzqN2Uh07d77Bz37+C6KRCKZhoekq+/ftZd/+vTz11FO8+eZuBgYGyWZzGEaBbC5HNpNzxD4EqXTGq9rt0TaNVCrtjDHhOVNpms7cuXMJBIK0tBxDkiRyuRzJVJJQMIhRMOjt6/MyzZG94PFQkWJSly26YkOq137qWu744Q/J5XM888wzzJg+nc/feCOv79hhj4Tkco7LnvCEPIQzt+pKahaLC43Vx1MU2TH1MSfUrx5rMkL1oEjJaz8IIWxnPskeXVFkm3RjWiaT6iYxY8Z0zlq5El3TaWhoYMPGDTz6yCPU19fbRJmqSnbs2EEqmfL+Rs4ZdzEt4SkOuonHeD1kNxtvaprCe658Lz/9yU9QVYWZM2Zy5MgRhoaGUFWVlStXsmPHDk/kaPacORTyeQYHB8nlcsTicZYuWczmzVvI521xkNbW1lFByL1OV3fchf+kMfVBTh3qPKlcV+/fIS1NbmwkMTREQ2MjmXSa1tZWW/kvl0fVVIKBIIGgn3gsRiQc5tpr/44PfOAD6H6V13e8zpVXvpd8IU9/Xz+XXbaeh37/ED29Pfzg9jt47LHHOHT4EInBQbvCDIdQFZXy8nLOPedcpjbP4OJLLmTZ8qU8+uhjfObvP4OsSPT29vL5G2/i2//2LdLpNIFAgJu+cBN/ffFFwuEQLS1tmKZBX18/lgP7z549m61bt5HP57zk8W0L/YxxuL3VtsHJTIvcYO22ZgQQjkS8UdLi7xcnqWMpqI485AN+P/Hycnp7urFME8NBOGfOnMG5q1fj9/t58YUXefPNN7015hIphRiWKvcO9ZP41ZcUa/L4zP+3ZWbxN+ZsuBLAbkHgvqaNKCsILOrqJtmaFoW8La2cGOKzn/kct33/ezzzzLMcOXKYm2++mWgsiizJpNMZj+lvF0jCG/eVJJv8t2rlSja9+iqGaSKE5Sm6ukqDnqDUqLZLadwodmksqq3s2KfpzJ07m52v77TPQk1DkmwFRIFg6pRm/umf/5l7fvUrnnziCed3NHRN8xQYFy5ahGUaLF68lFlz5vDVr/wj3/72v/OlL93Mrbf+C//yL7fi9/uc0V9QVY3FS5bQOHmyfS1VVVWsOGsFAX+AhQsW8p/f+Q+STnAej7gwFlu1eC1KRWZAUkmKLXkKc5JjalPcDojF7Arj8vXr2bnzdbZu28Ydd/zIqXDy6JrCN77xNVpaW+jv66O9vZ18wRg1v2lZJqZzcBp5OyMvmCbCyeokedhtT9d1TNO0iVIFgxkzphMIBHjzzTe9h1ysgeBueHtDWt4bHmukaXjOVqDIqkd8mj5tGnV1dUiKwlNPPkksFicYDJBMJpEVmXwuP6wG5vAG3N74WNK5xY6FJ4Pgirs8o/y+kb3VKTsEyWAwSCqVdLgGprOAFEDyiHS6pnls2UwmQ31DPcfbjjNt+jSuu+56Xn/9dV595RW6urrI5/PU1dViWhbdXd1ks1nKyssYHBhAkmSvQnTXlGVZ+Hy6Nw0x1uYKBoNEYzE6OzpQZNlTfnTvTygUQtM0BgcHS/T0Q6EQVdXVHDxwgEgkzCc/9Snuv/9+EgMDjoypRHIo6U2fuAnAuAfTKTQhTu4EKBW5iklMmdJMMBjk2NEj9vN3kCCfY/oUCoVQNZX3v+/9XH/93+P36/gCPq679lr+/Oc/OUFE58knn2T6jOncd+99PPDAAzz9zFNouu5V0JqqoTjSswjB8uUr+NnPf86kSXWoqsZNN97IL+/5JaqqEo3FefzRR1m4aCGWabHx+Rf44s1fpKqqgmAwyN4395BMJSmLl6PpGjt37qSiosIb8xxLKtXn8zlqeKeGjkd6bSHGm5ufiKT0xM41TVVRNJVCvsDKVavYsnmztw5M0yQUDoOwvHg5Fs/D5eS4X8diMaprajiwfz+67sPn05gypZn6hnqOHTvGnjf3jNM6cn08h43GSuJAcVXv/FvQ8bcoFAoet+VkbQzxNsZwx7NnfjsJgOYcdilntNQtHouLt2g0RllZGd3d3Wi6Sm9vH5/7zOe444d3sHPnTrZs2cb9D9zHc889RzAQLFExdfv/roBQMdkyHLa1ATQnthXH3hJhspMYXvn9PrLZnBc/XI2PaDRKNpsln8/bhW8g4BUofr+fyy5bT3lZGaFwiE2bN/PKyy8TjoRRZIV0OgWShKZqTKqbxBe/eDOVFeX4AgG+9vWvUV1ZzTPPPs1jjz/OFZdfgaLKnhR6cfIbCARQJEm6VQjBnj17aGtt43j7cWbMmElDYyMnOjsdwRdlXCWvUbaTxcpf3r8V77YSf0yPeOaOuvkDfkzT4Lw15/OVr/4Tjz/yCG1tbaw5/3xi0QhHjh7hzjvvoq+vj97ePgcmS5PNZMnlsp66WcEoYBQMWyDDKGBYhqvTi2kJLHPYCCObzVIoGMiSDS2fOHGCbDZLLBYj4PeTzeVKev8evCcVz8uK8c2T3PlUhwOhaRqWabJn7x7Ky8q49dZ/4dM33MANN9zA0aNHaT1mV3ymZXjVu6o65j2m9fZIieNse48AWqTh3dDQyJmLF3P02DGvZ+9WPIZhJ11+v9+7h25rwtU3HxpKsG3rNrZt3Uq8rIz6hgZqJ9WRzeZoP36cYDBAKp0ml80RjkTIZjMloiKl0wpiDLhWICxssSdnoxqmieq45Lk95kKh4InnnHnmmRQKBbtvncsRDIV412XrCYVC9Pb0YFmCoUTC3uwOC9j1Hyiu8k4lWsRbmQ93UA/Lspg8eTIzZ83kjZ07HSUzxU4YJQmfz4aZg4EgN9zw9zRObiAUDvKXP/+Fhx/+I7Kq0t3Tw+pzV/MPX/wHdr1hi8A8/OeHbcSoYK994SB87hxyVVU1PT1dDCaGmDtnLlXVlRw+fIRHH32MaCxCKBhiavNU5p8xn3Q6S3PzFAYGBpg8uYmaqhq6uk4QLyujr7+Pzs5OZFkmErGJUoYjHDRSynk0GXRizLqTDYu+1bn9kWGtWL/dNE1aWlpKRsWqa6pJDA6UcmSKiGCjpV8lr3LUVJVJ9ZPQnBZkV1cX+/buo6e7p6g37KB6zqE3fNCXknpPRohUNdVZyzZM/v9SA+FUI9VjXb8k2VbkwnELlCW5xBOjutrWHUkMJtBUlaGhJF/60pf43m3fI5fLsXXrNh577FH+8uc/e2x7jzAuhg/1sca73WS/WB9kou/LjaeWZY9nxeMxysriZLN5Is4kmKIo9jSXZU/GXX311Vx77bX4fD6WLFnCnLlzuOOOO9i7Z4+NyBvDbXM3/l5y6SVccskl7N6zh3vvu5cD+w+wbNlSlixdyvr1l9kFpSSXqF+6yFWhUECJRiO36rpOU1MTmUyGo0ePkk6naZ46DX/ATzqdIpvJDvuVj5MAjO53jcbHh2UVhTMsIJX4DLhZkmWazJ09hwsvupie3h42bthAJpNl3rx5PPHkEzz+2GMIIRgaSlIwCrY0aWH4QDcsE8sRyLAZ7Sa2FYDlmEpYHnPecufnECWa2fYBNsS8eWcghPDmLDOZjNMnH/vML74/UhGz1nXq0n06F1xwIR0nOshksnzpS7dwzac+xYwZ06mtrWXF8hX8z+9+RyDgR1FUEkMJfD4/hlFwtLilUcY878RGtL3AbeOcgN+PJEFVVTXnnLOKzZs2O4ztUg8A7345M+YlAh6ShGmZTlIg6O7q5vjx4ySH7JZK89SpdHd1ec8gl83aZMRRUwp4mgG2SJQYt09Y7DQWiUZsYw8nkXBd9RKJIU88pKy8DNM06O3t5aqrruK+e+/F5/MRCofp6e5Gle3DWFEVr9pyER3NQY3eFsV5nLFWWZbJZrN0dnRQWVWNP+BncNCWcvb7/ei6jqqpfP7zX+DSSy5FUgTJoSTXfPIajrW0eNLPn/3MZ1mxYgX79u/n2eeeZf/+/ciOAqKH1smy046zFQVjsRiJRIJFi86kobEBTdN47LFHcfwy2bFjB5Zlce65Z+Pz65y56EzOWrGCAwf2kxhMcOjwIQYHEzbyZhh2a0ex20WWE2wpMlkZSzr6LR8m0turYsciNUuyXNJuk+RhlCqdShfZdkueXbkiu6p20qhXjkajrD5vDYvPXExbaxstLS2OeZLpma2Vms84a9e1gnautnjM72QHq3tojGoH/H9oeuJkvX/JG9GWPZMkd9pB13QSQ0O2SJYkYZkm3/rXf+Ub3/gGhw8f5s9//jP33HMPTz75JH6f33tNwzBskznTKpHaLkZTi+XAvUkA6WTSv/6SRMFt6blnXiabJZEYQvfpCMuyY48z4TVnzhwaGxvQfT6GhpIcOXKUl176K3/645/o6+stSZLdBGbmzJlcf931qKrCvffdyy9/eTeWZfEP//APTGlu5mtf+xr79u5DK9IbEcXQr3OdSlV19a3JZIqoIxHoZiY7d75OZ0cHZ5wxjzlz59LV1U0+n/MCoMcXLxFDGCM+F63/eDxGLp93eACles2yLHtQiKqpLFy0kHPPPZcz5s9n5aqzufTSd/HkU0/w61//ikQiQTaTI5PNknfYx66mvWmatqSwM8rmjs65KEOx0IVrYypGMbbcURCJ4+3HSaXs+xMJ245K+UL+pLO8xSM1QiqqewToPh9dXZ309vaRy+VIp9O8593vprOzk2g0QkVFBdU1NfzqnnsIBoOemIVbRUgTJNtMpJCSRgQDz3VRkclksixdspj1V1zBAw88gN/n8zLP4o3i8hF8zvdL3P0YrvDcxCibzdLX10dHe7vDKLbnmpunTqO9vd1OKBxYXzgjjS7UFo/H0R23OVka3/DF7Te7CmTF+uG5fI5Jk+psyG0wQTqdRlUVtm7ZihAWTU1TWL36XPbt38+U5ma6uk44fBhHPrgIOny7lsBjVbEeqUlYjo2z5bTHAvgDfmprqukfGGDWrDn80z99FU1T0HWdb33rWzz40IPOPc5QVl7BP3zxizQ01HP//ffzl7/8hXQ6M6qacZMs1TFS0TS71RAIBpk2bRpz5szmscce4+DBg+TyOVKpNDtff51L33WZPa6r2kz1I0eOcPcv76ZgFBACEoODJZM0lhBeBTpek0Q6Bco4fh4lFREDOSVaeTp7ZOS6skl+ZqkUs8OTURxTM93n8xJm15lz3hlnUOVZ/w7xysuv0tV1YtSzGJmGjJShHW4lCGKxmLcfA4EA0WiUTCYz5hjr20ELx6zM32bVHy8rY/HiJbS2to55vd7PFo2om6aJ3++zZd4R5HM5W0YcQSwaY2rzND77uc+zZ8+brF+/nqeffpq9+/Z5bp6WZREIBj2FveG25snvjd/vJxQKkcvmxr43Es44un25LlrjFi4CqKurY/GSJRw6eBBd15k0qZ7E4ACRSJRAMMik+nr8wQAPPvAAmWyGvt5eryVQzPWqqalh9Zo1zJo1m4MHD7Dx+RfYvXsXmqYSjUT45T338L/33suf/vhH4rGYh3aM9yyUSy99162FgkEsFmVSQz3d3d3U1tXxsY99nJ07d6LpGoV8jng8hqrpDA4ODh9Gnv90kWjDON4BdXV11Nfbr+8Z8Dh3Ty4iAwb8foQQLFq4mNWrVzM0lKSmtoZ4LEZ1VTW//tWvnNGNAqZh65qHwxGHAGKANayUZT8Uq9SwwlW8KoHnx6IJ2302d7MNDgw4c8ylwj4Tgc+KJYwNI086nXGSHT/H29uZNWsWzdOmsv217VRXVzNt6lQURWXj8xspL4s7QhWmNxfuTiLII9QSpbcQ6Nx+vt/vp662lmgsyrx5Z3DOOefw9a99naVLl3HixAmOHj1KoVAglx+2ehWMrwzmBV4xGgFymbUuYtPV1W2b1qRSqIojUyqJkhlbCSgU8h7Sc6o36z5nG2azr9VeCzYE61anqqra7Z54jN6eXs477zzyTssgEonQ09PlVf+jtAmkkx/mth30xFo1xa/lqjv6/X5SqRTJZJLZs2cB0NQ0mXPOPod151/A7Blz0fwqO3a8zhe/+EWEsGx4WbOVBtesOY85s2fzxz/+kU2bXqVQyI/5HiRJ9iRi844d6pSmZs5cfCZDQ0l+/rOf0dPb46jK2fbeFeXlnHPuOc7f09i8aTMvv/IyiqLYiYtjaazpGqqiUMgX7MR/xEcwGBxOcIuQwP8vFqhuMHXBG0WR7HaiJYhGI8yeNZvJkydz4MABcrkc0WiEukn1TJ48mXg8RsuxFrq6uhjoHyAajThtLqVk3p/TUJUMhcKeCqPt1lcYleC9E5W+9DcY6TNNk2QqSca1Gh8ncRMIT+tl0qRJhIIhOjs7bfO5yY0UCgUqyiv4r+9+l1gsxrPPPcs//uOXnVHiPFjCizN2qzKDcDhiLgp8qg83VoyVqLitbxupKSVDRKJRG30WgoqKSk50nSCZTLJwwUIuufQStr22jebmqei6TmtbGy//9SVbPyCd9tQaJVzVQaivb2D+/IUMDAzw6KOPcOjQIYaGhrzWxn/8x39y51138su778IfCJDP58jncyddA+qKs86iu6eb7q4u2vfuY83q1bz22nY2bniOMx1p2K1bt2JZFhdceCHr11/Go48+xvG2NttwwalsXRJKyaCAGDYzmTlzJs8///wI0uCwiqDraGmaFoZp0NnRQSKRoNdx+Vu8+ExeePEF2o4ft73JnSDuVkoI7DnkUf3xYai8mOBhWqZnWuFmcdaIeY9icq27ILPZ3LgboISIVPQzLs/BTZJkx5Pc9pu3+N73buOBBx4gHI3w4IMP0XKshW99+1scbz/On/74R+8wsCx71E2WZUzDpGAYyLJnx/4WZTclJ5jZo2d+v5/588/gXe+6jPkL5iPLMt+89RssP2s527dv57FHHqWiooI9e/ZgOjwKyxSjCDKjRkUZraTo/nwul+XQwYN2ReXA7WvXXYDf5+Olv77EUHKIXC6PYZgEgz6nypwYkclyFBOLyXmuA144bAdQ91CMxWM8+eQTZLJZjILBd7/7XcrLynn00UcIhUOEQ2FOOBLJbuvKvv/CG8SSPE1y5+uTtAncw1c4DmgUrTU7wTXw+f2oqkJnZwdLly7jmms+xdrzLyA5mEKS7UD6vdtu8/TdbShaIp1KeXLOM6ZPJxQKkc6kURQZyxRea8RWw7QnHNy+s2VZzJ8/j0mTJnHkyGHyhbxDJrOJRKqm8oc//oHL1l/G7DmzMS2T2XPmICsqILxDXXV7z0XSqpilQ2vhsC0mVOyCaJommtPuOf3+68nZ/afz4fJbXAJdKBRy2kfg9+lYQjB9+lTmzZvriC0lOf/889myZQvve9+VVFVX8fTTz7LnzTe9FpnsBBtbJVN5S6I5bmticHDAuzfuAfdWbJdd86bx3C5FyQz+sDfA2/koFAr0OvbDJSRHabiPo8gyBcMgHo9RX9/A8bbjJIYSNDY2ctbKlQR8fgYTg/zgBz/AsizuuvtuNmzcQCgY8kjdLn+nmFhcYvAjJp4EjeV26hKK7ZaEZovIOUm87tNJJBIEgwFUVeHEsU7i8TgtrS10d3Wzes15dLR3sHnTqyXOn8XSw8FgwNFeidHQUM/GDc8gkPD57CkBWbIJqevWXUBnZycP/+lPRKMxpk6dyp49b55kPs1BsNo7Om6tra2htbWF+oYGFElhwcKFbN68iaDfxy1f/gqGYXDgwAEKhZzdG6xvQJIk2tvbbYUyTSvqkbjGH6WZ87Fjx0oWkaeEJtkPWlbsNoDqyMMuW7qcSZPq+a/vfId169ZRVVXJ7d+/nT1vvumNbNjsVoNcNkuhUKC2tsYTdhiWwi119x6piOWiEMXo20QDxijS0FhtXUkqUeKzZXxtKV/DIWINDNhudK+/voNt27axYuVZXPneK/nYRz/KG2+8wa43dhJ03A1tsRUbiswXCoDwNvBbgflcZqhhmPT19dHd3c3mzZv54x/+wKRJdZTFy/jgBz/IA/ffz5bNWxhMDNraCLmcc3+totEpqbR/N1IzwnNeHJ844/ZUT5zooqqqismTJ5PJZD0Z3mJTEE7DhW2sH3eNp+LxGIqiks1k6e8fIBqL8pm//wxHjx2lrLwcYVm0tLQQiURQNRVFVrxWmCSB7tOJRqPkcnnvQFUU1WlJWaPfp5v8SiM0GZBG3EMVTdNRFRvm7+3t5azlZzF/wQIs0yQYDfCb3/wP//nv3wYgk8k4gUNC1zUWzF/EylVnkUqmefGlvzI4MICu654imawo+HTb6lhRFYLBIJqqUltbyz984YvU1Nawb/9+HnroIdLpNLlc1p75FxbH29oYGBjgyiuvZCiRZNq0qbS3t3Ng/37bLdI0nD1oepCoYZjIioxlWp5iXCqVHJU8eqJWp3n4n+ywPPVUgDTm3hgZ8D1NCpccaBi0d7Szfft2zl61ittuu41169ax+83d/OqeX9PR0eGR8IpjT01Njc31yGVHtbMmguYVo6ijqtLTVE0snlQoHlse65XeyvM4KXF8jNfXdd0j6Pl9fiqrq8nnc1RWVnLu6nO59F2XsuqsVZy9ahX/9M//xJatW3n3Fe9m586dlMXLUBTb9ts9UF3+kKc4OWEfCqmk6i+WhS+Wu/f7/V4b2nRG6CORCD3dPdTU1DLJQb5raqppaGjAMAps3ryF3bt20dbWSjQadXr7pbLz7uTXWWetZPacOWza9Cq5fMGbJnD3lWmafPRjH+cnP/0J/f39CKC/v892wD3F2lAiodCtZ5xxBrt27SIcDrH2gguprKpC1zUqKyro6Oygqqqa/fv3YZoWtTW1PPzww/R0dzF7zmwi0ZhjJSvZWTvD8qXjK6GV9v9d72dXOTCbzbBo4SL2H9jHj3/yEz71qWuoqa3hm9/8pncQuCSj4p5sLBYnn8970qQnE9ygSFVKiGLWuTRxp67xqroxNl0p+WlYx1+WZcKhMJMm1THQP4Cm6by+fTvVVVVMqq+np7eXzs4TdLa3U15ejqbrqKrG4GCi5P0V23qePuwnlcy6RyIRTMtEEhL5fJ5f/vIegkE/2UwWISwK+YJDphQn3dTF8rDj2SaP16PN53McOXKEgwcPkslkiMViCGx970I+75DXJpapjbUM3M3lVqO9fX02/0TVSA4N0TylmWMtLTQ3N9PT08t733slW7duIZvJOox2G7UyTJNoJIKsKGTSGU+3wTSMEsOjkdoQY69NyUucZMfXW1Ht0VFZsacyli5ZwfQZ09EDGn19/XzhCzfR09PljYi6gTwUCpFKplm6dBmLlyxGCMGGDRvtsTZVscf/FAXd50PXNXw+H2VlZaiKwvr1l7P2gnWYhslf/vIITz39dIk6oyRsOeZcLseKs1YypakJS1jMmDGDDRs2eq0GWZY8hryu62SzWRRZKZKsLU56xClnqsd6huOR4aQJEAvHMnMZ67Bzg71hGKiaWmJ8ZlgWqWSSz994Izd/6UuEw2H8fj+3/+AHtLa2egqOkrNghMMDUhWFpCP1XRwwPPLYBCB8O9FUSsa7TtqOHGdyZeRooFwEoxQf3hUVlUye3Ehvb+9oBv9pKiiWai7Yv11VVc3CRQs4evQo4XCYiy+5iN7eXnq6e5gyxXbwe+WVV1i6ZCmrVq1i+YrlfPe73+VT11zD0FCCWCyGpun09/d5SJwQgjlz55DL5RxCsjQmB8VFw9zrdL8eC/KXpGKFV2wfDGDG9Bmk02mCwSDZXI7LLn0X06dN5dixIzQ1NROPl7F//346OjopGCayJDm+KwqmURiOZ47BkWVZzF+wgK7uLrZs3uy0eywKjkCZLNsx/4orruBPf/wDpmURj8cZHBjwiJPjIUxuDFKSyeStzVObWbXqHAYHB5k3dy719fW8613v4plnnuXQocO0trVw+PBhBLBjxw5y2Sz5Qp5sNsfyZcuYP38+7e3tJFMpx9f55L0VD+50OAKyYxrkzkKnUimapzTzuc/fyJ/+9Cee37CBQCDIA/c/gM/nK5r5N0uq2P7+gRI2+niLzduQYxhhTPRQkUaU+9IpNoOqqsiSraZVzJ+wxzHy9HT3OOpe9sJ44oknePnll3n66Wf4ylf+iXg8zoED+zjrrFWctfIsDh46WEICcoO+YZjDuvKnRfIZhu4N07RH88JhCobBzp078TlWxrb6mDilYMtINr+iKKia5s2/jhc9pDFElNy+GEJQXlFJXV0diUSihIx1uoS84oPGhXhlRUGWJCbV12NZJoFAgPvuu5eWlmM0N0+lr7+frhMnkB29AkvYUr25XM4et5lApVlMEJUASZERlvDMkDxHM4cUGwwG0XUdWZZpbp7KtZ+6gVAogN/v40c/+jEbNm7w3sNIKLW3t5eyeDlnn3M2ZfE4mqax8fmNRKNRfD4dWZIIhkJEoxGCwSCVVVVccsm7uPCCi2horOeFF/7K9267jYHB/mHrXklCURUCgSCGafDqq5u4bP16dF2nsrySZCLJtte22YJRTo81l8shOeOvsiwTi8c85UrZ0QAxHdLm6IB7coOtk0HokiTZ989TlRzHkKiomh7LjdJF2ADnWUlEIxE+9OEPceaZi3njjTcwCgVuv/12+vr6+e///i3CshgaGrLX7RitSFdwbZRgmpj4dM+wyZcoKT7G2wtinPs48r6P2ecG6usnUVVZRWtb68TX+gSIsLIiEwgEuOjii9j+2naWLFnC+vXr6e3pZWgogc/ns8ejW1uJRCJ8/7bvU1ldxac+9Sl++tOfOgRWu33Z3z9QNElhoSi2gFBfX9/JkyNnPSlO4j2ajDk6UXeLLsVBFy666GI6OjsYSg7xd5/+O6LRCP39/eg+P5MbJ/Pyyy/R39/vxWfLsiirKKemtpaenm40TfEKJcsSrF69mtqaWjZv3lSE9pQiVJqmoWoqR44cQlVtvQR7XYlR6GMpCuskOkKIW090nuBjH/sYr21/jXvv/V8Sg4NUlFeQzmZ54fmN9PX2YRoFdN2WHy2vKCcQCNLX18e+ffuQJDhr5Ur8wQAd7R3OxcrjnqTFrF1JkhBFsKhP10ln0ixdsoxrrvkkCxcu5He/+x0bN27A59dtzfGi6t+ynNE+axgOC0fC1NbWMjg46Gjvn76b0zs9BzuyN+5ll85/dV13dNQNkCX8Pj/HWo/xoQ9+hK9//Z+5wpFhLeRzPPnEk7S1tbFkyRL6+/tsdqqwPH94W1hFOmVSIp3kPcuyhKprDPT303nihDdlYfe7T1FZFTE8FFUpWawVFRX2vL9U5LEtS6NIdMMBplh/QTA0NEQymcTv93HmmYvp6+sbt3c5VjXoBrxipzSbA2HzKvJ5W+Dl0OFDVFVW0d7eQSGf441du5hUX095ebmnxU5RBeB6Eoy1ptyDz5YWlR3SkOz8bdnbL8NcEXvUyafbjOdAIICua1x//adZtGAR0XiYbdte46abbvQmSUzD8ISe3OrBsky6uk7woQ99kMmTGzn//POZNWsW+/fvZ3AwQTqTtoWFolEmTarnxs9/gauvvpqq6iq6Orv46c9+xoYNzzpyqXmPI+MSOC1LsH//PnTNx4UXXkA2k2H2zFm88NcXSSQGUVXN6ZHaY4CBgJ9EYoh0Ku2NdJmG6bgBOqNuDmQ/vEdLx2kZR6N9rAfu9/upr2+gp7fHa8ONnB7wTFqKzJmKlW2Khb9c/X2fT2fWrNkMDSV4+smnsCyLltZW0uk0qXSa7q5utm3b5pEq7RaUKBJhEWO2qcY6/MeCz93/dRPEkeJUqqri9/tPuS/GkzgeywBHkiT6+vpobWudMAF6Ih+qM75bVzcJXdNYvnw5y5YuZefOnezatZuu3m4y6QyZTIY5s+fw/MbneWPXG6y/bD07dmy3k2NJorKqisHBQUyzNJG0LKsoCRt/osG9Dy7J1WXOF7cti++Li1zb6JZGoWCwbNlSBvv7ueWWL/OJT3yctuMdNDVN5sEHH2T69OkcOXoEozBcsPn8PqKRKMePtxexpSU0TWfatGl0dXWxdeuWUdfrCtdd+b73MW/ePJ595hl8Ph+ZjN0Kd+QiR5M3i+7LokWLOG/NapRAIHBroVAgGgnT0NjESy/9lZqaKqLxMubOnccrL79km484Km+5nG0rquoamaw9ctLV1cXu3buJxaIeKSKXy45906VhxrQkDfdZiv0CctksU5qn8oEPfICpU6ey9oJ13Hfv/xII2OSiRGLIg+FsFSdRIm/nXoMNxZoTcmSb6GIeZ3z7lNCbZ7BdBN+Fw2GP1OdK7HqsUqcHfP75a3nxry9QU1PDBRdcwI7tO1h/xeXMmTOHp556ikQiwWRHyz7njMUsXLiQtra2t5ili5JqIZfL2uY4UCLGM7HkSRpV5SQckR2bdBe3RwGdxe+iGLIsefLGY91PwzTJ5fKkU2lMy6S8vJxwOGyTQU+SuLnz6KZllpA/QXLUBvPMnTuPuro62tramFQ3iXA4QldXF5qmc6Kjg2AoxHnnnWev8SIlLxf6Hw+N8Pl0D6Iv1rxwESFNU71q1D4ch19n5sxZfPjDH+XqT1yNosrk8jmuu+469uzZ4xBTsyX32d0bwVAQWZbp7Oxk1apVKIrKokWLqK9vZGgowZw5czjvvLVceNGlfPYzN7Jq1QqnGjf579/9jt/d+zskIJkcwjRL169hGBTyefz+APlclssvv4JgJEwoEkIIwWuvveZ4diQdn4Y8mUyWurpJNgnMKNjjuS6hzBn5GtlfdR+UO0EwXLGefB/quo5pWfT0dJfcG9mp2tzRY6MIeRhLXMc9pALBIBGn1ZPL52lra6OlpRXTtNt5impXb+l0GkuYpJIp8vlCidPlSSv5cVA1GzmUS8aui2OE5Ai6DIvPSN7s/GjYXXp7M/nScML6TmiPqKqKYZqsXrOG6667DtMocPjQQV7f+QabN2+hp6cb0zDJ5XJc9q53cd/99/ODO37AzTff7Ehy28+vurqGgcEBT6Z7+FkWT0uJk8txFxFQR5Ip7QS+dI24IV1RFXL5LAj4wPs/wDXXforB/gFuv/12tm7bSltbG2/u3s2SJUtQFMXWF9FtobJwJMLQ0JCtgeLEV9Pdt5JMW1ubJ8Dmrn1FUaitrWXatOmsWHEWf/zDH9B9Opl0ZkyPHntbDRfB1dXVnHPuuUQjETZufB7F7/fdqigyBw8e4mMf+zhv7NpJf38/rW3HWbhgPsePH+fw4UOUl5cxNDRkb37T9FTfihmVPT09njpRRUUFx9vax8wHhwUWXMc5xXM9K+QLyLJCyhHZWHnWCnbu3Mlv//u3CCfYmYYj8CPM4UxHEkXzonbWN1KjWyr+lCRUVcF0dLj5GyldibF8LYseZqFglMzTW04VhBBkczmCwSDd3d184xtf58ILL2DturXccccd7Hh9BzNnz2aqkym6EJc9fhSlkM+TyWYdP4CJdQSK56jt4AyGaZDPFTzznfGIRxMlHHojhEX2zTgwmqqq5PK5Ighv7MTLfVqZbMZWmTMMysvLyeVyVNdUk8/lMK1hnkWJoqBHtCmVjjVNy7MD7unpQQgLv8/Peeefx5GjR0klk96z6DpxguqaGjRNo6enB13XiiSMRxJdpeHpBi9xkrzerz3yJ+MP+IlH4whJOCN5tm+EqmlEQmH+7d++TTQaRvfp7HlzL7++5x5S6YwnSTsKwVFkJAdR27N3Lxue20BFRSWRcJxFZy5g9ZrVvOfd72X1uecxf/5CKisqQAgKhsGPf/QTfv7zn9pjU7kchXx+nKrVhm4zmTSGabL2/PPJ5/JMbmxiw4YNHGs55slxuzc9m83YvhHOHnb3gXCr/yKuzMgevcufKebrMKYoS8BrixSrsslO4lVsRx0vK6PgtA2ra2rIZbMlkLrf7+fsc86hoaGBAwcPksvmvKRBcqXAGR5htNEtucT7QJzEvdTtPVvWyQ2CSl9D8hJEtwVVipxZ477e20EwxYTJcycnA7qMecuyWLhwEe95z7t59ZVXePjPD5NMpWhrbfUIbEIIvvOf3+Ezn/scV199NQ8++CCRcBjLspGlqVOn2mOB2axD9rRGxDrJI9dN9BpHJgx2MVlKunTNwEzTZMmZi7nwgguJx2NcdNFF/PRnP+XAgf0cPHCQw4cOIYTgkksupby8jL179+Hz+ezRwmyWnNMOLeZ85LI5EokEipN0yDK4JXI0FuPEiRMsX76M5194ntbWFgr5wpiS/cVTD9FolKXLllJRUcH27dvZ9cYum5MD0q3xeJxEcoiB/j7OXLSYcCjMk08+yfLly4nHYvzhj3+09dUtqwgCkUYRdtwDd++evQjL7nPJReIpHiFsxCIuJou5hKcpTU386U9/ZPebu9m1ezfbtm6zYdqiQ6S44vcC64geia7rHhpQrIXv031oDiN6LI/3d8LMWjrFhnIDlCgKEsVZq6ZpHDt6jAsuXEc6leZ7//VfXPneK7nxxht5/LHHefhPf6Kuro55Z8yjr6/X7qMi6O7p4cILL6C7u2e43y5OX/7TNE0KThUjsIZFXIoPurdxi7zn6KybGsfGMzWGrvrJ0BXLsmz2q6N9rqgKuWyuZGzHhdddlv7I3nHxOJX9XGSWrVhOLBrljTfeIBKJUlldxUD/AJlMhq6uLibV1aHrOkNDSVRFIRQOYxqGQyAaEVAs4THihRBEIhFwvg4E7Eo9Eo14Vaqu64TDYUCw7oILWbt2HZqm0tffxze++U1aWlsYGkp4icuodoeTxGVz9gTFkSOHee21bbS1tdHb04ciK4SCQbLZDD3dvWzetJX/vfc+vv3tb/HnP/8JwxGsGZ72EKOCpCTL4PT2X375Fc5auZJpU6fi9/sJBIM8/thj+Pw+T0DMQysctrTsHKL2OHEpvFqMFJ5KPraYNe3Kq/p8fibV1zOUSHiHoXC02aurqwmGQsycOYubbvoCR44cBqBxciOdJzq9OKdpOpUVFZzoOoHP70eRZa+HO5Zoj3vjC/nCGHoLUgnJbzxPiJMijx5ZdxgN0TTNm1F3nUNHJhz/15oKI1FSaVTrwkbb4vE4559/Pj/58Y/Z+cZOJFkilRxCwh6DnTKlmd/9z+9Alrjqqqs4dPAgPp+PXC6Pqtmj5V1dXQwNDTlW6KV8iGINkolORDAiFlOEpsiOPbp7/dXV1dx1191Mqqvj1U2bMAyDukn1/Oa3v2Hfvv2YpkkwGCCXy3PeeedRVV3NE48/ATKOuZsYVrAsVbDyYoZ7RiqqSv2kerKZDI2TJ/Pattfo7u7yWijjxXhVVamurqKysor2jnb2vLnHIePKnvGImDVrpqhvqBc1NdVi9erV4qMf/Zh45JFHhRBCFAoFceGFFwpN08SkSXViwfwFQpZl71OSJFGEb4/6rK6uFpdffrmIxaLevymK4v2uLMtCVVXhD/hFMBgU0UhE+P1+8YUvfEG88sqrIhAICEVVRCwWE9FoREQiEREOh0UgEBCapglFkYU8xjW411VZWSHq6upK/g3w/v7ixYtFVVXVqO+f7HPkz0kg3HP8VL8jjfg9nN/1vu/cE0VRhN/nE7quC0VRxflrzxfVVVXimmuuET/96c+EaZri0ksvFYAoi8ZEeVmZKIvHhSJJQlFkUV1dLeobGrz3OdH3VvwpO9cy8rrf6U9d04QEQlVVb234/f5xn4n3fiSEJEvOPRu+f9FoVCiKIuLxuJi/YL6YNWuWs+7staKqqve+3LWgKIqQJISqKM7XkqipqRZLliwVsiyLc889V0SjUSFJCE1VRTxeJkKhkJg6daqYNnWamD9/gYhGo0JVVeHz+YTP7xeKogif3+e9vqIoQtNU4ff7RWVlpdB1XaiqKkKhkAiHw84aj4rq6mrR1NQkpk6dKs4//zzR1npcGAVTCCHEnXfeJSoqq0RVVZUIOH9jvGcry8NrKRKOiLKychGLx0R1dZWYNm2aOHPhIrH0zCViwfyFYvLkySIWi4pIJCzi8ZjQfbpQnWfhhCf7viOVrFGfrotYNCYikYh4z3vfK/L5vMhkMkIIId7//veL6qoqMW3aVFFWViaisZgIhcIiFAqJYCAgwiF7H/t8PuHz+YSqqkLTNKGqqlA1VSiqIlTFWROSLGRF9p6d7Dz34k93/bjvf1J9vff/mmb/XjgcFlOnThNlZXHx2c9/TnzgAx8Quu4TiiJ779FdJ5o6fG/PXLxYNDQ2Ck3ThM+nj7knivfwePHgrexDNz7IkhMr/X7h03URCPhFPB4Xuk8XwWBAhEIhoapKSZxVVfVvtm9P9p6K37997ZJ37YCYO3eeuP766729qqqq8Om69xw+8pGPiI0bnxdXXXWV9zruewmFw2LZsmUiGo16+9q+BmncWHs69/pk70+W7ft7xhlniDvu+KHo7uoWGzduFCtWrBBz584Vuu7z1puu68Lv9wtd18XkyZNFXV2tKCsrE5WVlSIajQq/3yc0zV6zkiyf9Hr9gYBYtGiRmDJlilh05plClhXvXo11DkmSJPx+v4hEIiISjYyInc6aAqFEIpFbM5ksDY2NHDl8mK4TJ/jEJz7JSy+/zBnz51NeXkY0GmPHju309PTQ19/PvHnzGBgYwDBsMZti9qzLRJWdNDCVSpFIJAgEA5y1ciWFQp7EUKJEIlQChCNOoun2eJIiyyxwvOVXrVxFR3u7zURGwnSgl0AgYBPnCoWxEz0J0ukM+XyeSZNsf+1iExfbT2CIQsFwtANOUxKzKNMVJ/mZiYzmSaN9Q70vY7EYR48eI5fP0dHRwebNm/n9Q7/nnl/dw1Xvfz811TU0Tm7k2uuvo6u7m+Ntx0kmkzQ3NxMIBEZULafHBhBC/E2qhOLrEUV9axfNMYtkZItbJqNY36L0RlfXVFNXW8vAwCDpdJrKqirmzp3HiROddvXpCNKomu5p06uqVsIdwYGLh4aSdHS0o2k62WzGm1fXdR/pTIpc1q6Os/kssXgZ+UKeTMZWeXTnjm35Uj8+nw5iGALNF/L2qKXH+lfQ/T5PkjcWi5HPZfnSzbdw9jlnY5oGRsHgzjt/wd59e50piOEWyqnWlj1XbVcdBcNu4bUdb2VgcIDBxCBGvuDRaLJO1T+s0CdOuicsYcs0Dw4OMn3adObOnUvL0RaqamrYt/8A4WCIVDplV6me6NAwtOoSAH1+v9ebl5wxp2KJal3TUVTVc910uQA+n89DGotlp23rXuFA+QHAIpPJ0t/fTzabZdu2rezatQshLGRJZv7ChdTVTaK3p8duJVqm18JzhclsES7jdEG18Ulwqoqma2NzlZwYWoyE+H0+giGbZ1FWVsaFF13Ivr37CIcjXlutuP/ttQKk/7vqf0zCt1PVKs6Y6XnnnccjjzxCR0eH9+xM06SivIIf3HEHZy5ezKdvuIFXX32VUDCIIsvkCwVUTWPhwoXs27fPex7DcJsocSY81X0/mZiY4noPCJuk7I6pCyFobp7KZz7zWXLZDE8/+wz/9q1vceTIEe+96Lpt6as6k0+6rpHL57lg3QU2aTuXc6ZkhkGKYuXSMfevZRIOhSkYJocPHkCWXB+b0paF20Zzx4nT6bTnLDtKawNQzj///FsHBgZsreLFi5k1YyaWZVJbV4tlWjRPaaZxciOPPPIIg4ODFAoFTpywXb+0oj6I1xZAGrU5ksmkPfYjy5RXlNPT3UM4HPZGu1z4SnO8kBOJBO9593u5+JKLueuuu5AVhXdd+i42b95UIuvoBsWJbEZ7TtooUSEr+fcRM/TSKQ7tiY8Lji8sNPJvKMWHnANp2dat9j00DINkMkksGuX1nTt5/vnn+fQNN1AoFLj7l3fT0d7OojMXUVVdhSLL7Nq1i2Qy6bFU3wnY/i2JI7wFZ7CR0LyiKOiajmmZRGNRz7t75EcqlaK7u9tL9LpOnGDPnjcJhUL2a+j2a4RD4ZKWlsuitxxVPndN2/1pi0wmDdijOQODg0VOYfaI4omuTmRZIhwKe22deDxOOp12+C2mp74nOT4Tuk9Hxmb8y4pMKBwmEAwSjUYI+H0sPnMJN970D56D5Pduu42H/vB7Mum0pyRZQrI8hXSra95kFAzn+iWv5ZHL5+1Zf9NwpmqsMXrPYwvIGIa9F13tgbXnr6Wjo5MVZy1HkW3Rkp6eHi8oFTPvFcV2w/OCMgKfz4em6R7hT3HaDa6DYbFATzQaRZZljwCGKE7Mh+ORPSY5DO+6XAD3mlzJ4uNtx53+s4W9De0x5XPOOZcTJzqdImQCcPIppmSK1/d4plLDkzzCc3BTVJXKygqQJOLxMi656BI2bNxANBrx1FHHZPbzf//hPg5VsZPheDzOrJkziZfF+dU9v6S3pwd/wE8+X6CysopPXv1J/vlrX+OZZ57hK//4jyQS9gigwE5KZ8+ezZTmZra/9hqZdBpZlkraO2PRQorH9WRHxl0AjY2NJfd/lCaENOxsq7oGYJpOdXU1lmWyc+frvPDiCzz5xBPO9IHptWAkZCTZhu0jkQgCie/+53f456/9M//z37+lr6/f2TuWI3FecBIHfdzJDPvva3R2djjEYUraHu6+UousiydiVqa898qrbjUtg7179oCw+OznPs8nPnk1siwxtbmZaCxGIBikoaGeDc89h6oo9Pb1sfKslVz9yU9iFAxWrlxJS0sL+UK+SF52mMwjF80ld7R3eNamS5Yto7ury9FdjyLLkif0c+455/Dhj3yYH/7oR+zevZvGyY0ca2lhYGBg2EbUtIble6Xxx/fcfruu++yDdZz+7+lIhkqnmA+Uxpm7Oxnh0O+YiBSzWd2g7VantnpYjqnTprF3717uu+8+Vq5ayfr1l3Pnnb/guWefo/14O+FImOnTZzhJm60aZTl9V07hbPV/lQMUjzMVV26jHBWdw8uVAPYqX4cFLY3ok9qBwSrZGG4CFQ6HsEyLSXW1VJRXcOLEiRJlyNIe4DA/xTBMps+YTktrK6ZlazWYpomua2iaRjgUdhS6ckSiEZomN5EaGkLTdQyj4NmY2g5n9jVqqoaq6wSDQSLRCNFoFL/PhyUs4vEyvvH1b1BbW0sgGOD3D/2Bf/nXW8nlsrYYkWFgmsbEkJxR6mei5N67GgLFY6mlxjOnnhqxTZwk9h/YjyRJvP/9V5FKpZkzZzaxWJQXXnjB9irI2oJClrDs8UBHGdDv9ztjgAqWY4DkVkPFktqmaXqmYQ0NDQgJ+vv6kZ2+OCNH7RyegeRwloKhEDHH+Mzns5MMy7TX1MDAgCMONVIWHDo6Oh1dden/8ACVhiXWi/aEZVnk8nmaJjfxiauv5tFH/4IsK94ad3k10gSTkL9ZEBDDz2zRooVUV1dz7FgLW7duRSDw++3RtRUrzuIvf/4zM2fP4tpPfYpnnnnaZrvX1THomEotXbKUNeefx4svvEAmk/EMuk6GMAJMnzGd8opyent6bJdGp7gaHLBllN14WzyJJsmSZ+4jSTKGaRIMBvn4xz9Ob28vQ0NDtLS0MDQ0VOILM1KYzR7TDOD3+fnwhz/M3Llz2fD8Rg4fPIQ/YJPe05kM0WiUhoZGhoaGSmzHXV0Qn8/PkiVLOHbsmJesuLycqqoq1q1bx8DAgGNrXzgt1FZ55ZWXbz3//LXMnTuPGdNnEAgGUWWVc889l6qqKpKpNL09PcyePYdnNzzH8bY2gqEg/f39NDVNoaa6ikDAz6GDBx05RMtjWpdAyUUwkGnasrOaqhCJxFh05iKOt7WRzWYIBm2FsXPOPodoLMZ3v/MdzjzzTA4cOEBrayvxsvioudcJHUiOXaRUNN8L0NTUxIyZM2lvbx8Nk0tvZ+OenhmHBBQc0wlphPuXNz9e9HN+v59MJsPAwAB//vOfqaquZt3a8/nrX18ik8nQ19NHMplkctNkCvkC1dVV1Dc00NXVXTSL/s4V89JpVvrFLG6f7vNG84pHVuTxUAFrHNLbGMp/apEsLQibsW6YxMvKyOfztrmVVXrgu2IgLkQtySBLMj3dPSQSCWqqq4nH4ySTSUKhkGMykvUEqkKhIAMD/cTLytEdnfBQKOTpiWuqhiwr6LqG3+8DB8aOx+NMnz6dwcEEH/zAh7jyfe9FkqCtrZ3Pfvaz9PfZz9T9O28pKZPc+6KhyDLz58/3ZITHGkc7KQpWvK8l2SOKbnr1VS644AKmNE/BNG0Z8aeffhrLsg/aknFHB8pWFdUTBhp2HLXXg+WIT8mKLVfstnoA+vv7S4sNZw+P5QpoWRaVlZVc9b6rKC8v59ixFkzLLEkWS9jqI8bDTsVsPx1ka6IxSypqAbiIiGmamI4ffHl5Odu2bSOTSRe1baxRJMl3Om+RTpHYy9Kw3sbatWuZP38+Tz/9DIODgx7KWTAMLrnkUh5++GF0n866tWs5duwY8XiM5ctX0Nlpo2oXX3wJ2WyWP/z+98PTXZY5qv031nX09vbR39c3bP0+auTPwOfzFQkC2YertwaFoLKqEk3RmDl7Fq+88gq9vb1FLQHJS7jkojaHW43bUuNxVqw4i+9+5zvs37ePcCSM3+dHIJg1cyaxeJy21layWTuxr6mpwefzk89nwbGiz6Qz9Pb1loi+1U2axJo1azhw4AAtLS2jXP+kCTwvRVGUW7dvf40rrriCM+bP4/rrr2f6zBmcMe8Mb+Tp4OFDBAMBVq9ezXMbNjCUGCKbzbFp0yb2HzjA7l27SDjZiwuzjmdB6DrQaZpGciiFpmsYBcOrnlzlsOnTp3Hw0CE2bdpEX18fvb29HhxrmcXWvuKU1XjxXRCW8KBGdwHVT5pEa2vrsEqg28oQExfOeSsbRyo5EBlXL7t4MZoOZyKRGGTmrFkkEglUTeOVl19my5atrDp7FQsWzGfvvn1ks1l6e3qpr59EKBxm3rx5mIZJd3d3iXTwOxUQThZk5BG2pnawlkrcFYvHjSTpnbEzi0Qi3ry55Yw2yrJET08vicFBQqEgijLcD3RRlmIUQFU1z4DJ59NZuGgR3d3d+P0BQqEQmqZiWibxaBx/wE82l6WQz2OZli35KdswvyLbML+iKAQCAXy67k0l6LpOPBaneWozy5Ys44NXfZBAwI/u0/n2v/87Tz75OIoik8tlbRh8PBb6BPUq/H4/fr+fX/3q1xw9eoT9+/d7ugRvNem1LMvmU0i2YM4ll1yCaVpMqpvE6zte5/DBQ4TDoeEEQJII+AP2+G+hYE/sOJWT7HjBq7KCqqn4A0E0TcXvt1GyfC7H4GCi1DFSAk3VyBfyw/7xI3gsbnAeGBykpaVleO0VJQ02J0RMyFVv1CTUW6gbxvIUGcuEx05KFfyBAKZhMH36dM455xyeeupJpw3jwr5SCRIrxtJm/xt+eDKzssw5q1czdWoz//u/v7OdI1UVw7Bl2//1X7/FzJkz2LJlMz/80Q/ZtnUbwWCQ5SvOYs+eN8lks1xyySUc2L+f7dtfG7OPzQQkwF2EcVRS5JgwuMZwbuJU6yiNhsIhzjxzMYnBBN3d3Wx/7TWv+HSnzrzpjiK00IXzQ85EUmVlFdu3byebzXLd9bZ+h4REbe0kqqqrePXVV+zXFbDq7FXUOjokrimYAHp6uvH5fKy74AJ8Ph+hcIjuri5ee+01uk6cmLCp1ChtlEDAf6uiqDz11FMcPHCIf//3b3PRBRcSjUaJx2O8uulV6urq2L17N+eddx5r167lheefR1UVysrLOHr0KLrPR1NTE8ePH8cwDHx+Hw0NjQwMDIy72AWSB2F2d3fZfVtnNKGsrJyzzzmHJ594gq6uLk873IXyvQdQnOlLpzd+Jjt9mmw2S0tLS4ldrRCndpl7O9l9iTTABFkrxfPL7uIbGBggFAqSz+XQfD4Mo0B7ewef/OQnec973sNzG55DURSam5tJDiXp7e3DKBTo7esdtWAm8l5OVQ2esiwY8X7sT4WKigpyObvvKor68sXqaW/1w52THxk8XCU6e5RKJxaPE4vHSQwMYFnCg5RVVcXv8zmKkgJfwE97ezvV1dU0TZ5M54lOfD4/mqaha5qtPyBsgyAchcGK8nLS6bQN9wcCFIwCmu5D4MzIC3s0KhD0c845a7jhuhuIRiP4g37a2tq4/fu32SpzqbTnyDeqUj8d9TWHoPjpv/t7brjhenbs2MGWLVtG6Wac3tiXzXuwFf8CZDNZzlp5FpMmTUKRVNauPQ9Jkuju7qKvt5dkKunB/Pa+zqMqClVVVQhntNHv99mBNBRC0zRSqRTpdIr6hnp8Pj99vX1omupdh6b7EEJQXm57GriZZHEikM8XaG1r8eD+kjXh8AHGEtH5W5HkJnJfPWKk83UoHCKVTPL+97+fr33ta/z6N79haDBRKk1e3AoR8LfuXIzU2wgGg/gCfgb6B/jrX1/y+CamZXHhhRdy880388orL3PX3Xdx4sQJNm7YiM/nY968eezavZtMJkM0GuGNnTtpb2+3BXFOm5QslfTPNVVzpLetkrFKgEmT6ggEQ4QjdiuuurqGT11zLS0tLezdu9fmoZwC5XHXkqzIaKqKrmvMnDGDQMBPdU01H/7wh7n88st5/LFHURSZVDpFV1cXZWXlqKpGJBzGNA1e3/m6jfA64j7f+95tXH755Zx77moAtmzZQltrm7d+J0rwHssLQjnzzMW3dnZ2Ut/QwIH9+xkcHOTjn/g4sXgMgKlTpxKNRFmyZAmWZREKhfFpOrve2MnRY0eRJLsqGRgYpKKigqlTp9La2srixYtpb2/3TEGG6Y5OlefMk+ccFTOb8Ws/KL/fz4UXXEhtbS2dnZ0kEglyudwoW9+JroGxqiEhDc/TBoMhamtrbaGjoh8c3RKQTt4+l8Y3Biqu8MfnB4xF5JI8i9WysjJSqZSnwWBZFqZlz5SnHQ92y7J44oknaG5u5qYbb+Lpp5/m0KFDqKrKsaNHaZzcSDwe92BfxQmUYpQo/1vrH0rjaSIUHVhuX97t8TY3N9vwlnP4lzJ7pXdMyMTup/nsTN8h90jIGKZBJpPBKBTw++3NOjiYQFVkQqGwZ8VsC/doyJKMrqlkc1kURfXgRFlRCDk95ng8TiQcwe+zmf3VNTXU1tRhGAbtHZ0YRp5IOMzsWXO4+KJL+NAHP8Sqs87m0ksupbyqDM2nkRhM8J3vfpf9+/fT29vrQYQjBZFORzNBVRXHC8DPF7/4RWbNsmepn3rqKccVsnDaB1kxV8IWY4HOE53s3rWbc889l8qqCjTVlm5es3oNM6bPQNd9KKpCJpMllUxSXVVFbU0t2WyOeFkMn6479tQ+clnb0zwYDFJZWUEsFqO3tw9LWB4KE4/H0XTNU8PM5LKYpt06c/1BwuEQwWCQdCrtWf16BDBJQlPsCZBhRce/Adv1JIeHrruTKaV20cUS1oqi4PfZpNKPffRjLFm6hCefeNLRwB+eWR8p2vO3bgEUC+SsWnW2k+x1MzQ0hKIoGIZBY+NkvvrVf6KisoLvfve7bNq0iUg4zMEDB/H5/axbt5aenh66u7qQJYn+vn4Mw7B5ImMULBMqwJzrKisrIxQJ2YdqkYeEW1hNmzqNO+64A7/fR0VlJZdeeil33HE7e/fudQrQUt0SaSyEU5JQNRVZslEmxUk8161by09/+jMaGxuJRCLs2buX48fbEQIqKipoaTlGIpEglUrR1d2NItvcGFXTmDp1KmvWrKa3t5fvf/82nn/+ea8NclqqrOMgJ8qJrq5b3bE6n+5j3759bNmylY9+9KMeHBoIBrAsO3vWNJWXXvorR44c4Yr3vJfXX3/dI0PEYjGuueZTtLW1smvXLioqK0kkEt7pJo1QxBOiSDDHgYJVVaWQz5NIJnnllVeIx+N85jOfYd/+fY4Xt5hgj0M6ZeByX8plcNo3dnzry1IUQDpdPsxbLhFcKCiXy5Vo2LsHpWEUqK6uJu3YwSqKwquvvkomlWZK8xSqq6udcSdBZ0cn+XyembNmcfz4cfvnPQhenNYljqerPR750W2tuMHOdVYLBoMMJga99YZLwhLiHWUreQYhqkbAH/AkdH0+H7qmOcFK9vr6wWDIY+C7xCC/3084HCLg9xMIBAgGg1RXV1IWLyMQDODz+Z3R2QiarttvQZbx6T5uuvEmPvKRDxMLRVkwdwE3fv4mPnXNtVx0wYUsOnMh06fPIFoWQZIk9u7dy7e+9S1+/Ztfk06nSaaS9rirJI1Z748KhtLYFZrfZ4/aXXH5u7nuuutsoZ5cnj/8/vfkcnmHVS1KVCEnVsI62uumSaGQwzIturq72fDcBlRVo6lpCmXlMSoqK1iwYAHr1q1l+fIVXPaud7F6zRoaGhq49NJLicVi9HT3MJQccnxC7DaOy5BubGgkOZQklU7ZDG9VJRaNEQwFHF8Im9dhFAxMw3SIUpWEwxEMw7QNpIQ1qgUmSZLn8ugKvozn5jge6iJNeEMwbqvPNM2i1mApKVZ1nBwtZx1HwmFmzJxJf38/GzdsJBAMYJq2C6UoEW+S/iZJQImGqASVlZWcfc45ZDIZ3nxzN7qmUDBsSe+r3v9+rnrf+/nLXx7mf3/3O9LptCeiFY/H+exnPkNbWxtvvLEL0zRLeF4TLfhO9vbS6QxJp02taZqTHEroPh8XXXQRd991N4vOXMTzzz/PkaNHeOON3eRyeaY0N6MqCvlCwTOxc1U87VhlJ2fBUAhFsb1YNFUlHAoRCoeQZZl3X34FCxYu9ITpkskh9ux9k6FEguPH28iks56/RsgZ8TQNk3DENul64IEHePzxx0mlUmia6qkdno4jI0X+LCUJgBDiVlmWyedsa9RIJMLevXuprKoiEAhSW1vrmO+YaLpGvlBg/oIFPLPhWZttHg4ze84cWlqO2Sz/jnbWr1/Pjh07MByZVr/fdvCTGD4ApCIbUDFiEyiqQvvxdrq6uujs7OTAgf0Yhj1u5fYPvYkfF9p92weD/d6z2dxpjctJo0x05Le0SE+FnguBx5R3rQ/cLN8w7FGuaDQKjpSkrmkMJgbZv/8ACxYu4OOf+ISH8ORyOY63tVFeXsbceWdw/Pjxk46RjXvYn5T8xBhjNZL3td8XIB6L4ff7WX/Zenbt2lXi9PiO+MCPZlx4Yz+FQsEJBIb3fXfcZ2BgkEgkYvcOhfB06HVdJxqNout2n7k8XsbkyY2EQmGam5uJRiNIzsFRUVaBz+enLB5n9bmrWbduHcuXLiMUDHPBBetYseIs5syZQyQeRvOpjgujwY4dO/jqV77Kj3/0Iw4c2E82lxuWvx45kicVSziL8bUSita5qmkY+QKfuPpqzjv/PPvvFgr86eGHyaQzmJbhEHnFKCha1zQsp0XgGpKMbSwjOaRbi0QiwXPPPsfWbZsRTnIajUQIhkLU1NYQjUQIBYOcd955nHnmmZx55iJHxVFFYKEqKrpPp6qyirq6OkKhEP39/bbaYMBeQxWV5aRTKduu2rLvQ11tLdlcjvqGBqKRKG1tbfh8Ov6AH9Mw7TEtxxK6GOmznRelUQqLb7XuPxk3Rtd1b82Pki33CiOnBaDIKIpqw9gStrJbezvbtm5j+owZbNz4HLpPx3BaRC4RW5yCKzK+wqI0Zhwcta+dmKfrOvUN9ezbt5eDBw5iOXoTs2bN4pPXfArTMLjjjts5cuQIfr/PK2oaJzey/l2X0dLawgsvvOh4KVhvnWQ8gSrYNE0URSEWi7F0yWIaGhqZPmM6jzzyCENDQ0QjEXp6ekhn0qRTSXp7e0gl08NrxKejOMZfbmJmG7r5HFn7ANU1NZSVlVFTU8P5a9cyffp0hyOjkkqm2b1rt+OQquPz+W1ukiJjOC1uWya+wPG2NjtW6ToIMYL8eOrnWUweF2PcINVN3iUHChEOA/LnP/s5L/31Jc44Yy5f//o3SKcTyFIQLNsK85Yv3cLl69cjywqLFi2irrYWyxK8+eabWJbF7NlzeOONnU41ZRAI+MnnsjZPWAzPMLpWtJYAqWjEyzItLyFobW0bnpOXZSznWqUSK0xphKe1jO7TR1vPjmBEDxuLSEybPp2tTi90ovXw8PypVDL2cvKhqdG98+JpRjEOmcV17Y1EIqRSSWcUBEeDPIsQFmetXMmbu9+ku7ub3p5edJ+Phx58iH179/GFf/gHdu/axS9/+UsAUqk0jY0NTJs2lcceecyuqhwWvhg1Kjn+jP5oCeQxAqcYRnls5MJuV8SiMc6YPw+/z4dhWk46KIraRUVs85M8k5EMdvf3RstV42m1uy2tXC5nE1E11Zb0DYbJ52y7a1VV0DWNyvIKhhwNhkAggGWZRKJRJjc2seKss+jo7KC3u4dYLM6kukksXbqc8rJyqqoqCQYD5AsF4mVxhhJJ+vr7aWxq4Pjx4+zevZtNmzZx8PAhQPD6jtfp6Oi0A4DjYV7sTFZyuIvh9Tt9+gxaW1vIO/4ROQcCH3mPTMNgyeIlXHLJxSSTSYYSQ0xpbmbNmjXcf//96JpONpsbtUoDgQDpdJqyeBlLly/jlZdfLhnHHHlCWJaFgS2wpagKr27axJatWwn4A9TW1rBixQrWnHcee998k51v7OQXd94FwIkTXXz67/+eXC5HW1srfX197N9/gP7+Pjo7O9mydSuyohALhwiHw8yYMRPTsnjxheepqqwkFArR09NDVVUlmq7R29tHezpFeUU55fEyOk+cwB8MkkomicViKLJCMpUs4RidzGlQjLHWpBF7u2Qi5SSBRFEUfD6dXDZrSyMXOVXaSb6rWSK8tezz2chZZWUVd9zxA2688UYs06SmppZCIU9eUTxr5dOBI4vjqN1ilIsk10dU+7Lk6US4MdowDPbu2ev9VE1tDevWXUB5WRkPPfQgR48cRZEldF3z1teaNecxaVIdDz/8ML2Ol8mYltDj3NuJWh6PKYLjxP7XXtvOxo3P86tf/YrFSxZz2WXr+e1vf0tvXy+maaOjpmkXv/b0hWlzexw3TwtXR8B+TVd6XiAIBu12YEV5hSMtbRcUs+fO4fLLr2DDxufI5XIkBgdRVAWfz3bbTaczdruvUHBey9EpGTHdcbIaSYx0nR3n/imqqt5qz9baWUxFRQXBYJAjR47QNKWJ/733PkzD4KKLLsIsmKiagmWZNNQ30Nffz6svv0pnRwfhcJjJk5vo7e2lu7sbTVPJZrNMmzaVVCZDJp2huroaTdPIZLJjp8VOhqNICpI8nBGrzuy05SldCa/qr6qqwueMxLkP2xYUGl6Y4xIRi9JzV+CocfJkEoMDRTC3NIpFWgx7FSccNplk0jAb9xR2pW+1s1hcIRePYhmGSUd7B6ZpMqW5mUwmQzKZpK6ujv8fb+8dZ1dZru9fq+0+vWUmyaT3HlJJoYUuofeiR4qCRxE9elSEgygWsCCCgCCCjaL0HiAQSCjpvZdJpvfd+1rr98e71tp7z0wa8v3lfDA5KTN7r73W+z7v89z3dTc2NrJs2TLmzJ3Ll750Hu3t7bS1tbFz505CoRDFJUVkMmlLjGcek7WpvLy8IH74aAIhOS/8ScRXxhk5YiTnLV3Kv5//d96iYxRKAMxjEFSaRw/4EPO+QtqWDaByu91UVFTgcbudkB6v14uqKpQUlyDLMhPGT2D8hPHs2L4dn8+HJMP48eO57LLLqKutY9LkyUydOp3Fi09ixIjh1A2pI1AUwO3x4PP7CIfDbNm6leXL3+Nn9/ychx56kH//61988MEH7Nq5k02bNhOLxtB1nUQi7sz87RTBgS6EXeEXFRVx++2343F76GhrR9VU6xSbu2/dLhcmJj/+8Y85/fTTee/d93juuX+xZMlpNDY2sfKjj4QiP5u1xgBCzR8IBECSOPWUU/nFL37BBytWsHfvXlGM900f6fNBGJbAL5sVCY7RWJSOjg42btzAK6++xrZt2xg+fASxWAyPx4uiKBQVFeH3+ygvq6SubjAzT5jBrBNmUzu4jurqatxuD0VFRcybM4evfOUrFJeUkEwmUa1F1Ofz0d3TSyQcxuUWwsCa6kEMqhvEwYaDwnFRKuzEIkwqUyCwlQYQDeVrU6R8jcrRnuEjPNDZbJZkMonL5ULTNExMhgwe4rBO7GdGOBc03C6ReS/LMtOmTefiiy7i3Xfe5bLLLuPjVatIJBPohlHQvegfjtP/h8/nY8SI4XR39zjdkAJrZIF1V1yjgN8vDo2mianryBiW993FFZdfzjXXXMeqlSv597//TTAYxOtxixGMrjN8+HAuv/wyIpEIL7/8MolEokCoebyt7cOJJwNFRf3ASDasx06odLvdznttbWnlwxUriMViTqZEfmEmoobJJQIqCrJkWXtdLlRFhHhVVlagaRq1tYOYNm0qp522BJ/PZ9mNxWvo6Oygp6ebUDBonfA1stkM8XiSbFaEr0m2pdVCBhYKLb+Y4Y3qDwRwuVxCeCHLtLS04PV6kSSJ1avXcOYZZ3LnnXcSjUb51a9+ZV0ssVB//3vf5/33lnPw0EHa2tppbGpCU1T8Ph8HDuzHNGHnzl2c96WlvPDiv2lr7ygIrBioPSNbmNT838s6SNI+1aD1cCw+6WT279vLnj17HJ+0lJfGdTh7SD4cxQa7lBaX0OXxkkgm8khRxgAVqemc+O2RhKKoGKaBrCgik9066faLAzWPr4IdqADo+/ft15BOp0mn07S2tqKqKn6faJmWlgnf+sN//CPjx0/gjDPOIBIJ09bWRlNTk/O51NTU4A8E2L9v32HVpfbvpVOpPPDK8fVFJVmiqLiYRCKB1+tjxPDhNDY2WS1sFdPIYFgRmebnVFnk9iPRKRGI3lzbX8R8iofb7/NRUlxCJBrB4/UKQEegiOrqKrot1XosJk6N1133FTLZDJMnT2b27NmoqhDr2ImJ9o9wOMz2HTvZsmULW7dsZuuWLbR3tJNIJAmGgqLYsGKfU6mklQAp2tgO9c5ZEM0B4z4xTVRFoaWlmblz53Hbbbdx9TXX8OzTT+P1eR1aoCzLaC6NkSNGctJJJwHw4Ycf8vGqj0mn0yw5fQl/+tOfOHBgv4ADpU1cbg3N5UaWZG686Qbuve8+3lv+Hh+v+lgU1307XQPcBGK9kND1tENndLncyLKCoRvEEwk+WPEB7777HsOHDWP8uHEUlRRz1plnsWDhQkotMbLmUpkyeQpTJk8mHksQjcbQXEJpPWrkSHp6etixfSfDhg9Hc7lIJBP4AwFS6RRVlZVUVlawe+duTjppMTt27CQcCQv2gSxRVlZGOBwmk8kWFL82KjoX0231p45iuTKP84G2QTSSJJFKpayExYQlqhSncVmRnf9flmU8bjdf/vKXOevMszjttNPw+jyWhkHq08LPPRv5TiIKKKkpDh1qzGGXB2j329Q9WZYpLi6morKSlubmXCfA+vz9/gDxeILvfOc2UqmUo7VIpkR4zpy5cxkxYgSvvPwyDQ0NBQXHQJ3FY9VPSXnrkGlZfV2aRhyYMnkK9fX1fLjyQ1yai2Cw19LDuAsOiSI5VcSF9+26CW6FUlB0yxIEiooxTBNFVvB5vXi8Hurq6pg1axaD6wYzdeo0R3QtOyFhJhMnTaStrYX2tlYy6RQtra243W4CAT+yDKlUWmz6moRiKE7r39B1jIG6gX320aFDh5LJZGhra8tbPwboQhm6fte5X/oSSDJdXZ3WXCyDy6URCYeZMGE848aN489//jM93T2cedaZ6IZBJqMTCPgZNXoUT/z5CVRVLAhC2VhJKCQ43Nlsll27d3HZZVdw4MCBHHCkIBY4f+2Qcg9bXhvjcCe7aDTKju3bSaVSjBkzBsOqfrPZbB6HXzqiTcr2qJdXVDBkyGB00yDYG7Q+MLNfOpT9mhVVVOY20lSWZUaPGk1XV5dQrzpV7f9/qD0bgZpOi9mxx+tBQiIUDDFo0CBGjxrNli1b+Oyzz/B6vZx9ztn4/X4aGxvFRqHIzJ4924E15RLMcp+NIktWa8wgncoc9RF1hEzW6d+luSguKqaouIi5c+dx7bXX8MyzzxKLxvJ45mY/q6f0Hyos7Y3QBPxWjoRu6KiWmEzXdSoqKvAHApiGgdfyyqdSKWbMnMn8+SeyaMFJXHLZpSxevJiRI0ZSWlaGy+2yOjBZ9u3bx8svv8xjjz/Gn//8Z/7whwdZuXIl27dvpbe3l2w2QyQiiG2xWIxkUrT7MumMSLrURWqg7Tqwhx/mAK4I+61rmogjHjduHAsWnMiM6dOJx+OCAmmz4WWJbCbL4kWL+drXvkZTUxO//MUvCIfDLFy0iIkTJ7Bx00Y2b9rk3EPJVIrRo0bz8MOPcMs3bkHXde64806279gm/NzHahm0RCsmAjGc1bNOjHMmLbpOkiSRTCXZsWMbq9es5o3X3+CD999n7do1bN68mZ07djF16hSLmaARCPhxu4U7w6W5GT9uPCXFpaRTKdraWh1KWkVZOSfMnMXsuXMJhsK0t7URjUbRFBWP10sqnUaWZAdSZK83Lk3rt/b0xYXzBYG07LXJMAwqqwTGOxaLFWicJGv86XK7cLlcLFy0iKJAMQsWLGD06NFs3rKZvbv3IMu5dDj79Rqmidst9CvJZNJ5nh37pmkekdti34UlpSXWegftbW3Ov/H5fJSVl5NMJEkk4uzYscOiZApXg6woXHvddRQVF9He3sZLL75IMBg8bEHyRQl+k8kkiqIwdtw4NJfGgf0HLFG61QmQJNLpdMHnnvP3048GalMCnVwDVUOWJHxenxAF+7z4fH7cHi+TJ03h9NOXMHbsWNwet6PVsZ8HW080YsRIUukMwWCIaCQqKKPW2mqapjMCzFpdZcOabdqgJbvz3FeYHY/HiUajhUyVgTgAsizftWfPHm684UYSySSNhw6hqooQFUky3V3dnHPuuWzYsIGPPvqI4qIiFi1a5ARvjBo1Gp/Px/Lly/H5A4BENpvB43UTCAQcyMeUKVMoKy9n//79uFyuPnx66fBBMaZ5xEfJLiaSySStra0Y1onI7XGTTqYsspx5ZK973nzIbc1wBLs81+ozCy5yrqXsdntwuTQhVnK5mDt3Lvv378+7qThs+/bz/rAxk4WioYFXlnQq7eBTTdPkxBNPxOfzEQwG6e3tpa2tjbnz5jFt2jRaWloI9gbZvXs3hmEwceIkgZ5NJvLmzaZVJRvU1FQ7Hu4jQoCccBerAHC78Pq8BPwBBg0axPTp0/noo49osrQe9r1lE936ij6PSVQp9Y8iNa2vLRTlEm6PG0VWKK+oIOD3U15RwaxZswVdThFt1rPOOptrrr6OSy6+lDNPP5PRY0c5bgVVU+nu7mbNmrV89tmnPPanP3Hfr3/Ns88+w949ewiHQoInYMIFF1yIoescOHCAdEqEBum6bgFcjDzio5Rn4co9G0cTN6mqSiqV4pJLLqG6qprzli5l7NixvLNsmWh1etx4XB6uv/56Zs6cybe//W1WrPiAcDiMacI555xNa3Mzb7/9tqUV0Fm0YCGPPvooi09aTDKZJB6Lc++999LV1WWRG81j98BIDDiTNB2uv3j/Y0aPwcgaxBNxWtta2bp1K8vff5833niN5e99QHdPNwF/AK/Pi8fjsbDAHurqapk2bTonnngic+bMoaq6hrFjx/Bf//VfjBs3jpdfeYW21jZURRaQJtMkncmQiMdJJBKOVTD/cGLzEj6PaPd4iwD7igSDQWKxWKEoWhFjKo/XQ1EggMfr4Zqrr+G2b3+b6upqPB4PnV1dfLb6MwdYpeuGU0hKVss7EY+LtrJTWBTibx1xdt7rVhQFWZKpq6tj+owZNBw4QDKZwDBMSkpKGDy4Dp8/QFdHB5lsFlmW8HhcVkfVYGj9UK659hrS6TSvvfoajYcajxvoczzRw/bGOm7cOMflc+jQQXbt2lUYv27dd30/X1mWkS2dkMMKkWRkSzSqyOI/l8uFx+sV4+N0GsPQyeoGZeUVLFq0kMUnLWb8+PH4/D5BsrTUTTYGXJEVSsvKGDJkCHPnzefMs85m6QUXUlpawgprDOHz+Zg7dy5Tpkxh6NChTJ48mfr6ejKZtIBB5a+T5mGi1vtQV/vtJZqq3JVKp9myZQunL1nCunXrnLANWZYJR8KoqkZXVyfJZJLGxkYURaWiopyqqiqy2SwLFixgzZq17NmzR6gcYzHi8TjDR4wgbYWMbN68mWgsxvDhw2lvb0eSZaqrq60qpX/wQT4K89hkjzm7nN0GlyQJj8fDWOtmsB/ygTz+xcXFZNIZZEWmrKyMtrY2sHQHA/mdFdl+MFV8Xh+yBXw5+5xz+OSTT5yFLtc+kgdQ1Eqf49CfawfntyuP9iwJlbkuHubBg5kwYQKxWIzW1la2bN6MbhiCQ2999vF4HMiSyWSt1Eczl4ltfXaXXnoJ7e3tYmbZJx4xH6vrbMJyrmpVNZWy0lLqBg9hzdq1DKqpZsuWLUIJm82KVpd1/QqzzaUBUbR9/7xvuIe94Kmq6izsIiXOg9/vc8ZeV199NaNGj+HMM87gxutvZP68+QwfMYzSkhIUTVTm+/fv57XXXueXv/olD/7hQZYtW8Y7y5axbfs2YtEosqyQSCQcXYqqqvzxj3/E5/Xy2quvISuKw5VXFLkgx9zZIPNu+2NxubhcLpKJBBdddDGBogC7du1k3rz5TJk8hbXr1nLoUCNf+tKX+MUvfsH+Awf45S9+TjKZIpvN4Pf7ueSSS6gdXMczzzyDYZj89re/5YE/PICqqTz9j6eZPn06/3z6Hzz37HNOZ8/8D4LmnOCwPH/74No6Xnj+Bfbu38O2bdstYbKJpmp4PF6am5v49NPP+Gz1ap5//nlisThlZWXEYwk0lwu/XwQpDR06lJkzZjJ9+kxGjhpJcUkx7y//gKlTp5HNZOjoaGfSpEk0NzaRTCWRFYXaulrHFWCHFZHXmj6u93gsoAyp8ECRr5Gx8diKBTmSFRmXpjlchPLyMq699jqqq6vBlFE1hVAwxLvvLCObzZJKpzBsMXVecqLX47XyQESrmz7ZG1JeJobdrfP6vOiGTlVlFevWrnUONnPmzGXw4DoaDjbQ0d5O1hCYddFJ0Rk7bhxnn3sWlVXVrFq1iuXvLXe6ov+xw2eA3wsEAk4olLDtynR2dlhriYEiK/3gWX1HDTYnw74uiio2e4dZYhU1woHiQVVUampqmD59OlddfTVf+9rXuPnrN3PRhRcybNgwx7oqK3JuXXQe61znRVVUDjTs59NVqygqKSGVTjF8+DB++MMfcckllwjeiCxC8jZv2kRXVzfxeJxsNuPog6Q+xav969LSUpG9YQzsrFANq93V3d3N00//k8suvYwXXnzBOYlpmkpraysLFy7kpZdeYs/ePTzzzNO4NI3Ro8c4b+L+++/n7LPO5lDjQbweUZ1s27JFiCOs1MBgMMiw+nprxpghEomISsrjIRQKHZvK/AgldA5nY40QJIlEMklLS4sINfJ66ejoKJifyIqMIkt43SK0pbW1FbfHjdvtLvCi9m0H2UhRMa/NgiRRX1/PqaeeykN/fMgKR8GJSy7UAJjHNDiX8gZbBXQ8WcQl2zGmfafkAxVUpmlipNOs37CeTZs3CTHgeefx6Scfs2H9BrZt3YosSRSXluJ2e6iqrKC9vQ0JMTtWZJmhQ4fSGwwSiYRxaRp1dXX4/T4HuCLeK84ilhPPGIhi2qp+VcURzlx4wQVMmDCBjz/5mLffXkYqlSKdstpyei4gyGlr5r1Xc4D3a/95f42J7HhtPR6PI9ycPXs2p556Gk2NTXi9Hs477zy8Xg/JZApFFosrQFtbO6+88gpvvf02G9avR3Mp7N2zj4qKCgIBP5lMhmg0RjaTIZPNks1mHSFRRUUFXq+PhYsXU1JSSigccua6mXTmqIPkIz0H+fdWLB6jpaWZkSNH8Pe//YMvnfclTl1yGk888QTXXncdkyZNQpIknnv2WVpb25yEsy1bNvPhhx9yxhlnsHDhQk45+VSuv+F6mpua+c53buOSSy7B7Xbz97/9nZjFyjhGScvASm4rzERVFaebkslkuPqaaxg5ehR1tYMtB0/KOYioqmohxjOWTsHFr3/zax57/HHKSgWC+bJLLuWUU05m8JChgsRoQjqTweP2MHf+fFqam5k1ezb79u0lGokwcdIEtm7dRjqdJpNOE4vFMEwDyZRyLIr89ygduzWonzOgwHqUP37sM9axeBkmJpIV9So2VgND19ENnfphwykvKycUDBEoEjHAI0eNZPDgOvbt3Y+mauiaaBtr1jhHlmQUVXFYBzl7oOxY41RVw+NR83j7BtFIFICGhgbcHjeXX3YF3/ve/7B27Vr++c+n8bg9xNW4M7YdM2Ysi05ahKHrvP/BB+zZvadAf/BFtPzNPkhrTdOYOHEiuyz8eSQSEVC3vEtu2NHOA3QnfT4f8XjcGWvar7HvWETAvGro6elmUG0t377125xzzjnceuu3qKkZxORJk4kl4vz5iSdYctpp1NfX93NYFGROWAwB3dQpLi5mzLhxnHjifCZNnMidd97B3Xf/hN27dhG3xuZ2BkC+U8U0D6/BkYBEPH54WzCguFyuu9LpNKeedho93T1CmZpIEIlGUVUVn89HV1cnw4ePxOfz0dnRSSKZYNz48YwcMYLy8nIHAnTCrBN49pnnBGgjj/Rmq9az2SwtLS0MGz6caCRizWhkysvLrGx1A0WWDutZPG7MrvUjmUwSDYcdS2BNTQ2z58wmFAySTAi7VDweZ+iQoYQjEVRFtTb//HxpqaC9gvWAeDwefBb04YzTz+Dcc8/l1VdexWIdCjsjuU2RvNOceUSwhlQgUMwlCYoTke1ht+NMCxSi9tzePDxSuKmxkW1bt1JfX8+S007D5/Nx6NAhS9EPpWXlYg6cTJK2vPmyouDxuDFN6OjoYN26dbS1tecSyOyTnWMlkpDIeZjtosnr8eL1ehg/bjxf+cpX8PsFH3/lRx8Ri4u5uD0eMvO6AIf771g8zfldE4/bg+YSp4SaQYNIJRPIisyVV17FsGH1FpdeQ1EVdmzfzsMP/5H77r2Pf/3rOQ4eaiARi5NOZygtLXWcFk4gkLVoiFODTCweZ/r0GXz1+q9SO2gQ+/bvY9euncyYMYNRo0Yzc+ZMJ9RJGoAwdrRukX2N7JGQrhtccMEFtLe3873/+R4A5y1dyrnnnMvEiRNJJBL8+Mc/pqWlhXQmbUFX0mQzGb503nmcffY5zJs3j5dffpmrrrqKUDDEr3/7G1auXMljjz9ucRqM4z7F5WtoVFWlpqbaojKaxGIxAkVF3P/7+6koL+fgwYO8/vrrBRkNtmbARjsbhkEkHCISiRAKhWhrbeH1N9/gww9WEAr1oqgqtbW1DgL2hBNmMnfOXCZNmkg2k2Hbtu3Iskx7u7h/I5GIcxojjxTXH53y+fznh4M1F1IUJcvqLFxQAikruh+ay4XX46GkuJh5c+cxdep0Mpk0paWl6LqBz+dj3do17D9wwCl87IyJ/BCh/LZ/33XB7/c5M3HRhTVRLBBWbV0tI0eMwjRMUskUW7ZsYfee3fR09zBmzBiqqio59bRTqR0ymA8/WME777xLj+UqOO7D3DF0uySLyilGX2ln7TrW7qqUp+VKpdJISFTVVBOLxSivqGDkiBGcfuYZlJeVcfPNN3PPPfdwy803EwgEePnllxk5YiS33fYd1m9Yz+0/+hEb16+nrKyMrK7zy1/+kiGDhzBx0kRRUA5Ag+07SjZNk7379vCrX/6Se+75OTt37qSrs9PK1XA567yDwjeMAS3lYqmTnIOQfXCSCsah4lfV1dWoArFrEg6HGTlyFJ988jETJkygrLychoYDhEJhPB43b7zxOkOGDGHEyBG0tLTw8ssvsW3bVu677z5Wf/YZS88/n3lz5/Hwww/z5euus+arMrrV9nFCX0yTtpYWysrKiEajxONxmpubLXa3qLr9RUUMHjyYXTt3HkMcab+iut/ft1utmuYikUjQ1dXFnt178Pl8DB48hClTpnLaaadx769+ia7roghQVUxTJ2vqmIYthDMtm0elaFkOHuwoyUePGsW3vvUtSstKOeOM0/nTY48R7A1aC7RB1oKPFKhmj1Djmn3bv6aNChYbeNaCWciyLMAZhqhyZVnJqZQlu3uQuyb2wqbIMqlkko9XruJgw0FOO+00xo8fz4YNG1i/fj0HDuwXpy63m0GDBjmoy7a2Nuv7CgFmfou+bzvRxphKjpVJsSiAQjg5e/ZsZFkhFosyevRoBg8ZwqHGQ072uXjdiqPjsGFIfTsb+dacw2VpY0qWvU9gNjVNJZvJsn7tWrZs3khRoISrr74GwzBIp4UQZ/uOHdz+ox+xZctm0ZmwxkuGYeAyTWfjN02DZDLlPGyaquJxC6sZssKpp5yKx+1G17P85Cc/4Zvf/BY1NTVUVJTT0NDA0qVLrW6SgX7cC6XpLO6a5mLrli0kEgnGjxtPMpnipz/9KQcPHuInd9+F1+vl6WeeYceOHaIrl8ySNbNkMxl279zlwLnuuOMO/va3v9HV1ckNN9yE2+3mxZdepK2tTQi7DP2IOsyBntn8DAbTNLnm2uu47du3sWvXTnbv3kMmozNq5GgkSWL48BG43R4ymTSmoZPOZAue5ZT1GdhFjx2j6vV6aGpp5plnn+XNN9/m+htu4IorLieTzaDICl6L4miaJm1traTSKWuRzBWwNiQo35J2uGwQ+vr9j4KhziMJ9HtmxOxZslT+ihUSpTpodJ/Ph8frIRAIUF1dw/Dhw8SJOiuYKS63i7q6wVRVVhGNxaipqSESjRIKBa3iSXcU79lsvsA2N0oMR8JgmlbUro5moZ2RZSKRKIcOrgHgzbfexOf3MW3qNC6/4grAZNv2bby9bBkd7R0Fn/N/euK3tRh29yCXKJt1Rr2FRX7hc5GfBWBb6uwxiNChZRg1ZjSzZ8+mtbWVBQsX4NJcVFZWEvD7GFxbR0lJCR3t7fzq3l/x4gsvMnrMaG6+5WZ0Pcua1Ws57bQlPPHEE9TV1Tmv+8T58x1nVc5iikjMtNYqXddpaGjg7bff5rPPPqGluZlgKIzb7cbr9ZGUk6SsMV3+tbS1Ubl1r+DoiGEB/VKplHN9Bro/Ozs7UO0rtnbNGmdjONR4CEM3WHDiAiRZ5v3336e4pETYVRSZUaNH0dzczLp165AkmaVLl/LSiy+x9PylXHbZpbS0tvA/3/0uVZWVBV5g3ZoTJVMpFMd2Vk0wGBS2B+tHLBpl3969BR2Eo7f/D28LEe0cncFDqvH5fOzYvoOWZiE46+npYeTIUSw+aTEul8Z3vvMdenq6qa2vp6HhYM4upli0RAu963G7GTJ0KIsWLuSkk05m4sQJ4sHJ6nznO99l7rz5fPrJJ6xcuZLW1hYMw2T//v2WqAcLSWoeU1vRRlBKVs9QWFhcVhtVzavaDefBNkyzwKKX38QwTdCth0lTVVqam3nyyScZMnQoJ590ElOnT2fd2rVs2byZbDZLXV0dZ599Np9+9hnNzc1WHoHcr71VsKhZQhdR4YqH2L6xA0UBZEli8ODBVFdXoetZMhmdmpoaQKK0tJR4Ik4mnSGTzaBnspbDxOwncCkAJVknaBHqQkE7z66IDcMkEo3i0oSSfEjdYEpKy7j66muYP38eqVQWr8+DLEFPdzempcpNpUSb2O6EpFIpx+ZkGLrggKsqhm5w0cUX86Mf/pBAoIiS0lKKi4qtMYhCdXW1mN0CGzZs5Ctf+Qrbt293xlKHK3gPC6axqkP7ZLBv/3527RKK+aFDB7Nt+3b+9Nij7NixnTvvvIOnnnqKdCqNqimOGlxzuWk4eJBHHnmEVR+v4tlnn6WiogLThEULF6LrOhs3bHRGeUezrh5pwwQTWVZ56smnmDl9OldceSUnn3xyQUF3yskn89HKlTQ2NpJMJNi4cSO///39hMMRx56XtZ5LEfCTdrQ/um5YRUGUd999l4svvlgULVabW0+nicVj1NTW0NnRSTKV6uOyKBQqmkdgeZjHwKcgj9ppuyukPqd/RbFP/Za2SLNnzwpujwevx0NRcZHYlAJ+6ofVW12RLKqsOl9vytTphMIiIbGxsZGmJkH4TCYSpDPiGimWnTCdTqObYkRpd+tURSFjjS6LSkrQNI1wOEI6lbLyGCSHFXPNdddSVlbGe+++x6effOLcf8e/8RcugLIiO1dIVVWLuyDlZRyYA8Ld+hf91r1mFQwjRowglUzS0dUpus2YZHUDj9eHqqqsW7+O3p5eent7CxIm7Y5xIpEgHA4jSRKtLa187Wtfo6S0BE1VKS4u4b//+7/x+/0UlxRTXFTEoQMHGFo/lKFDhzF27Bg0l8s5ENnUzmg0ymuvvsKHH31IMBgkkUiQTKaIx+PioKEbeZCz/nHzOVCURQO1HQKyxJAhQzjU2GgVAJLTzbbXaJ/fx4SJk1BkRb5LliQnbcmw0KBiZh/iRz+8ndb2NhoPHSKdTgtlpW4wacpkIuEIW7du4cKLLiYaibBm9Rpmz5nNvHnzCAaDfPjhh5SWlFhirhyf2sR0IByyVdH3/QANw6CsrIxp06bR3Nyc89vntzOkgUMp+s0ArIcxk8mgapoVgiNOqelMhl27dvHCCy9SXVNDQ8MBenp6+cUvfskJs06grb3dOWXYC1gsFicSibB161beeust3njjTTKZDDOmT8fjEQlua9asobW1ldaWFjIZnbKyMpqbm/F6vXg8XkeYMTBuU3J45MJuolhZ6bIFrnFRUlzizE/T6Yz1IAs2tdvtEtfZGDgMxE5dtAsB+3uGQyE2b95MV1cXixctYtGiRZSWlbFy5UreffddWlpb8ft8wrJmtWH7tuPtNr+djmd3Xvz+AD6fl6KiAH6/H6/Xw7XXXEvNoEEOhe/FF1+ip6eH6qoq0bq02pW2E8AwDUxD/NoOchoo7SqfqJZv58EUnnufxyO0Jz4vmksj2NvLvHnzmThxIh6Pi/379tHW1s6ePXvo7u7C4/EStuaK5eXlpCxCX64YyT2kIpAmzYgRI5g9ZzalpaXW52gBp5I6Jgbvr/iASy69lP379n7uFL6+C6CiKKTSKc4480wmTpzI8uXL2bhRbNw7d+zg388/z549ewYg+EmkMhk+/fQzGhsPYRjCcjRyxEi+//3vs3vPbu69916HiX7c7f+8HqRpbTrJZJJ/P/9vR92cTmWRJAV00TkaNKiaMaNHU1xcwpo1q/nss9XOPWert+0NSVAwTQuaozqKdlVRCAZ76enpZfiwYQ7Ua+WqVaxft4FoLEYikcxTUptHRXkfSe1/OFy23T3MobDzbWayaGVrGoqqorlEoex2iSREl6bhcrspLilm5syZXHThRcyceQJFRUXIsoSsiHVBkiRqawcxa/YJlJdVCE1KJEpvUESpRyIREomkEI/pOj6vF0nOOQ3EMyPjdrupqq4inc4QDIbJWnG09usdMmQopy05jYaGg/ztqb9y4MAB695THXTnsdwdbrdbsFLy1xBro7IzGHRdWEZtEfLxRhLbz4Usy3R1dTkZEXZCov25d3R00NPT4+xJzvrl0ggEAqiqKsTw1hjT/nepdJpoNEpvby8NDQdoaGhgz67dbN+xg63btrJ921ba29pwud1CL4dhOQqE5mXnzh2sX7+OA/sP0NnZSSgcIpFIkEqKw3JuzTPz7WRWx8Z0OgnOz3kHxs7OTjLpdJ6FO6//ZF2bufPmo4B5l+kE9OaqC80Kx1m+fDlLlixh06aNpFIpampqSKdTbNm8hfknzsfj8fLWm2/ywB8eoKqqiscee5zBdbVcceWVhMNhVqxYQcDvJ2upuvsGcKQstX7ACkHIX5gSiQStra0Fbd7PE8QjWbPpVDrjtA2TyZRzTQV3Oc369esJhYJIssTwYcO5/vrr6ekNMmrUaKZMngKmSSKRxOP1MnjIYGRJJp1Kkcmm+XDFCk5bsoRQKMTFF1/Mu++9y/r169m5cyft7e2Oz94pogryqftXMsLz6xZJWJZ6X7YUqWBSVV1J0hrf2H/fDqqwaWG6rueEkdbnmtsczcMS80KhEBs2bCAQCHDTTTcxZepU2lrbrOCKOCYmbo9HnLKdtpzkiFpyWgPTWuAU6/ShEAgUM3PGDE495TROW3IaLpcL06r2TdMgnUoTDAVJJOKCO2+NMUTrTiyioqjQrFAOqd9G2FdspMiykwLodrsdwpemamQzWWoH1/LVr95Aff1Qent7+NEPb+e1V19h+fLl7N2717LuJRk7bhxtLa3O7NxxdljXzTDFxtTb28NLL73EKy+9jCzLTJw0CVlS0LMGppTF5XJx++0/4tNPPsHj9RxeCCgde4KLJGGlxGWpr6/ntNNOY/++fbz51lsWE0MSzg7TRFaVgohZ2yqWyWSET1ySyWTS/PTuuznl1FO45557+Pjjjy2HRubo/nfpKNHREs58+8MVH3LppZdQUVlJKqYjGSayDM2tzfzud7/j61/7Gm+9+ZaVUZDt0+2xrWyW08bq/BiGQLaqqsrWrVtYs3Yt06fNYOjQIVZKXRdr16wmHI7kjXHMPLrnwLZh6ShZGAO9bylvs7ehOPkWT1vc6Ha7nUNONpPF7RYxyIPq6pg9ezaXXnwJl1x8qbP5m04GfW705Xa78fv8DKsfxonz53POl85l9JjRFBWXcPY55zBt2nQWLhBwpfUbNiDLCn5/wHlWiouLxf3b05sLyvJ48Pm8uDSN+vp6stks69dvYNfOnRimgaLIeL0+ZFm4d8zjWJkN0yggmpJnV+ubYfB5oteP2sWxwUdSbt3AGSMKJkcylbQ6nkqumJMkJDP3bxVFRbUKT1VVneLN4xHR3y63m7lz51ro2ZxP/5lnn2bH9u10dnXS1dlFNquTtg7fDgHUMAtSCAcC6PW3VNpFp1RwbaW8v5/NZmlra0XNJ6WJwA+VqpoaWpqbkSSJUDjEo48+YlHUVFpamjFNKC0p4eOVq/D6fPT09PA///M9Hn30EYYOHUJZeTnpdJr77rsPRVb44x8fwuPxONY8u2oxrFOrrusoqsqgsjK6urqcij6//V8wEy8AckjOxcE0qaisJJ1KEbXTxKyNTrd+7urqoq6u1sHXis1CJ5vJiDARQFFlHnjgAR566EEWn3Qy+/budWZxU6dOZdbs2Rw4sJ9EPGHZI1Ns27aNzZs209rWyo4dOygpKSGbzTKodhBer5eW5hbhk5UKW9imOfANmtV1svG4wwvHBFVT8Xi8pFNJLrjgQqLRqNOuTSaTJBNJMnLamVPbLVv7QRuIHpV/De05u/0Zvffee7z33nvU19fzP9/9Lhs3beIvf/kLqkuzFhwPPp9SIAI0DCFI8vsDlJaWWHjloVx77bVUVlUxcfxEhgweQnlFOWL/NJ0wjaVLlzJz5kzWrV3H6jWr2bB+Pdu3bycaiTpYTLfb5di1FFXFzGYKqnJbMQ6QzqRRrdaqbogCwjktWl9v0KAafL4AXV29JBNpsrrOnj17aWtrIRoTII1kIoFu6IRDIZHwh0ldXR0HDhxwHi7d8vrm8tC9bNuxnQf+8ABXX30NGSmLx+sCVHTD4OqrruL11163vMmHaSebAzazDjsKSGfEKGjD+g1IkkS1JbTTdcOJ+c3qOujgdrssTQ4OEMV+LagmQ4cM5ZxzzmHz5s288soruN1uq9N05EauxJFzLZxn2TrdLFi4gLrBgzH0LP4SF/FoApfby6OPPMo9P78Hn88r3BKZHJnNbutqLo3ysjKaW1oce6o42YnxT1tbK2VlZYRCYQcAY+gGu3fuEmMgSyCXzWZEga2q1nUqJC+KEZx5WF3DkUYfFm8dj1tYxwzDJBaNkrEW+GQy6QC7htUPY/iIEYwbO5bGpkbmzp3HTTfdRGlJibMB6tlcV8vELKASGbq4x3UjS2Oj6EJ2dXXx6/vuAwRxsDcYJNjby5QpU4jFYvztb3/j+9//Pueffz6bNm3ik08/pb2jnV3bd7Bn7x4RfKMoxGMxMZJJCvqnrCjClaAbDrfg6Fn0uVltLoQrXxkhLqLH7UayyIO2LRMkK+nQQJYkQeuMxw87TDj2joGV4SLlOo1YByRJ0nNte8PAkCRMUxRdGetULlgBlgNKt0OkwO1xEwyFkGSZAwf209XVSVVVNelUBpdbo6O9jYMNDRxqbCISiaIbpiN0tVHy9kEmn4diX6jclmceZvSdrzsRBYskC+G6/btjxoy1woDyLlo6kyUUDFlcdt0JhnC5XPi8PqKxCIoqOP+6YZBKpaiqquIvf3mCSy65mB07dlBUXMLJixeTzWb55a9+STwe4w8PPkhpSalzejIxMbKCqy2bJsFgkFAoRG1trZWJLDyd+V5vWQLDhNLSEuJxG95RaKlLxOOOR3ngm0By0L75bdd0RkAsJBNMXSzgiUSS8ePG03DgAPv27XP+7qbNm6msqKB+2DASiSSa28WChQuQFJnm5mY8Hg/RaAxdzwqkbHExRUVFRGMx4W/Xjbw7/ij8fCtf3c6VDwT8GD4vNdXV/O///q8Tx2wrRE00kMVcOpNKOScQmyduz8/y5/WF18nENCXHvqgoCocOHeI3v/0t9cOGCctQRrcIbEIdXD+03vK9uhk8dAjtbW1cfOFFLFq8iA8//JC//u1vfPrJp8ybN58ZV04vGH04BagBuqEzuG4IQy4YwpRp0/hk1SpGjR7FocZD/Pq+X9PU3ER5eQWHDh50vLkCppMt8PK6ra6CruuC5Z2vhu0zstB1g7179tB06BCKolBdVc2ZZ53Jnx9/DFVVSSSSwo+ezbB37x5cLjc+n5/zL7yQN15/XWgiolFL4EkeXlWclBcvPolAUQBJknjxxRepHVTLvPnzOPW00xgzdgwbN260LIrGgAK6I1sAC/Uv2WwWTdNYt34dr776KitWrHAY5tXV1Xh9XoYMHsyihYvx+rwMHToUv99PWVkZe/fsYeXKVew/sI+mpmaKioqprKpi2bvv0tXZiappBbbYw+kAzKMGs2AlnwnR4wUXXIjX6yWbzbJ69RpmzToBgKnTplqhS4KMmO+ZN6wbJ6vrtLW3W+Muu0OkOy4Yw1CsEKYyxo0fh67rBHsirN+wns6ODrFpGgLVrWqqKO7ihmPrFSPHwo3r85xCM2khQrSJo6oqEk+rqqoZNnw4Y8eMYd+B/XS2dzJq5CiQJAbV1DJm9BjKSku5//4HOPucsxgzagx61kRV++ZxWxn1soSqyMTDMWKxGI888jCbNm1izZo1/PCHPyAcDvPXv/6Vr3/9Zu688/9YtuwtXnv9dd586y0+WLGC1pYWgsEg0WiEcDji0GD73YIWkvaYBNoFduajXyvbfmjqZkF3LZ1OOQcFW8vzxfwQnSNRlOa6ATnxp1nw2vLpmw61NJVGscazSAbpjCD7edxi1Lxv71727d1LdXUNmayB2yPR2tYm9lkkZxys61mHgVII+SnMZjDzRF1ut4t0wQhdnP5lScmzsdo6CoO6ujrS6TSRcISv3fS1wgLAfqMFHkpTRLklkkkWLlzA7t27OXCgwbElxGIxqqqqKCkp4ZZbbqG4uJjnnnuOHTt2kE5n0Q2DB/7wBxRF4/7f/46SkhLn9GVHKmYMO5/boKWlRdCcSorp7urGtPGtppA8yJJIsRtoZqrIcr+qcKAPvL29Pa99m9eSMnBmK6lkClmS+de/nsPr9VqCRDGfCodChEMh9u/f71T4tbW17Nm9m67uLsrKSonHRTpfKpkUoSQuF5LVvs5kREWnyNbJ1Tk5DdzeQZIE0tW68VOpNB2dXZSWlnLPz3/O739/P1s2bxa8cFNBtjQXojLVBfI0mSKZSh7GOicVVI75N33WShY7ePAgBw8eLCicopEo+/buY+eOnVRWVqCqGjGrAHv3nXcYPnwEixYt4owzTufll15h0aJFBfM5Xc8xEiQkC5ghrsbaNWsoKS1l3rx59PT0cKChgWuuvoZzzjmbTz/7lEOHGvnoww/ZvXs3brcbTdMcVXDUEik6rgByI6R8CpjH47FmfApNzQfJpjMoCpx15lk898yzdPd2Od0ESRICLcMK6vnXs89RW1dLS0vLgL59IbDUmDptOpIk8etf/5of/OAH+P1+rrrySn5y993ceuu3+cp116G5XDm1rnl882ezr9tFVojH4tx9991s2LCRyspy7rzz/zj3nHOpqq7C5/MN+PVOP/10br7lFkzTZN++faxbuw4JiTdef01YG7+gMHlbo2EaBvPnzeeyyy7jww8/4t5f/Yq33n6b//3+D7jn5z9l3LixeNxuQuFwQbdMkuzQMIOiQBGxeMx5RnRDR1FdKKo1hlIUgsEQt37r2wweXEc8lmDPnl3s2rXLul8yeemFpuAO9ImiPdxE+3DdDQmQbFGfBCXFJdQNHkxpWSnjx09g2LBhjBw5kvqhQ1m/fj2DBw9hyemnsXbdWh78/YPMnDmT6dOmccIJM8Fq1VZUVBDsDVrf0QBJATnvRZi5G8cwTQKBANOmTeXxxx/nuWef5cUXXqS7qwev34Nh6Fx08UUYuk5LSwumabJrZy7Fzw4+s7VFDJCoebSOx7EKWAvYJtZNbT/HIlVPI5lMWAAhJedkMk1BJ+3zIXzekmCgvcQ0zT5OENPJZSwEsNnjSVGAi3AhnWQiAZjEY3F61V52797D/BMXoCimpcDvpKu72xJri7RNPZslqaccjYthCZDtDd+J/baSdJEoOPyQl/9gWn9frHti35QUhYryCiLRCN/85q1cdtklAgWc473nc49zb1wkGRmEwxHuuPP/WLNmdUHbJxIOk0qmME0DlxXBWV8/jOnTp/PWW29RO2gQS89fSm1dHW+88TqKrDg3Wr6q2P7eghGeseaqZmHGuUS/vHjbXmjkz5OOoAmwcasF7VUzfw5lfy2TeDxOKp3zHhcgI2XFQkTK9Pb2Ul5ezs5dO2ltaxezSJvdbM1XM9mMs6HaDgfTBE1R8Hi9oiiy7GD24qNY0B9VVfF4PLjdbiRZ5oQZMzn55JMZMmQI7y9/X4wprMxo+z87/lW0fSQUS4AikRMi5bjXR0PrDpwPbl+TRCJhdSDE3+3s6GDnzp18+OGHfPbJJ8iKzM6dO2k8dIhUKoXP58fn9+W+miEWt1g8TlNTE+lMikgkzN/+9jd++tOf0tvTw6ZNG3nppZfYvGUzWzZvoaurq+Ahzv+M8scd+d0OWZYpKy0VC2VRkSNUPHToIGNHj6OkpIwx40YxefJkdu3cSTKVcshf9tdwud0YuuD+q6raTzVst41dbhff/973eOXlV7jjx3egaaKjsHrNGl577XUC/gDbtm0bUNV8uNmzdJQ5gLCcZhk/YTy33HILv/nNbzn99NOJxWLs3buXt956m48++oi33nqbV199jbVrBGt/+44dQtgoweDaOqZNn4aiKLz5xpts2rRJwFR047Aam2MuWszcZ3POOefw2erV3HLzLezcuQNFkVnx4Qd0d/dw5ZVX8NLLL9PS0mJR3HLzbsM0GTliJNF4jFQqhdvtwtBNx/fucXsoLhZz8ssvu5Lbb7+dZCJBNBzhwYf/wIYN68lksqTt7HXbJ2+LI/sI2aQjaIv6rl35oDBJklA0wVIpChRRM2gQzc3NbFi/nueee4433nidxx9/nA3rN+BxeTjz7LNYcvppQl8kC6eJy+ViypTJQr9gQbTsbpPcj/9hOj7/rq4uurq7SKXTNB46xL/+/RyPPvooGzZsFNciGnWYIPZr7Zs0+h8T+6TDI8r7aY+sADXZei0utwvVAmnJlnbiSOsQX1jESk7M7Pf7ceUV5/kCRkwhZC8oYqxRmq4bDmBO1VQ0VaO0tIxTTz3VAi4Jbconn3xCMBh0HADRWMzhXPQ9+dNnBF5UXITb7SKbyQVJ2e9AlnJ7eT6DQnO5iEajtLe3U1ZWygknnIA6aFAtLS3NlsjBFm+J5CExh4GysjIuueRiHn74EV584Xkuv+xyHnzwQQenKisqWT1LOBKhvaOD4SOG88+nn2bp0vMYP248v/jFL7jggvM595xzSMTj3HPPPXR3d+Pzefu1oO35bL7KvMD/aNLvosuyzNgJorp+7913xYKcV1X2Df4x+p4oCrK7C+1lsixobWVlpY6KNle1GhbeVojMduzYQU9PD6YhVM6YphOX2vc95usAslmhdpUVBcVK+yorK8U0xSk7HxYhyRIe1SXiaK0P+JprrmXN6jWoqkJICRGJ5BTNejbjVK19W/6i0hcVohCCmYc91Zh9qGh9tRh2lK+txHe73fj9ftFGT6bYvXsPBw8eZP36dVRVVTJj+gx+cvdP8fv9mKaBoqk8/vjjvPPuMlpaWujs6CSVSjunEX/ATywaIx5PEAqFnHtkIL58IciFgpGDYQphU6C4iPb2DjLptNMJePvdN5k0dRIAJ518Eoauc8GFF1BeXobL5SaV7nEKX/veTSWTKKoqBIt5948d6vGd73yHjRs3Ct1CKoWuG7hcLnbu3MHOnTsK2pqHtQD2OexJh0lgNK0v4vN5KSsrY9u27bS0tLBq1Sr27dtHPJFwfMVO4Wxt7C63m5LiYoqLiwgEirjhhhuZOXMGvcEgLrdrgCJH6n8+7osvHuDEaIfeKIrCk08+SSKRcDLUDcMgEPDzpz89Sjqdsu4NC6hlncw1VcUfCDiURZvYKcRZNulRiLBmzZrN3Xf/ROBdTRevvv4yqz/7DM3lFgp3K95VkQQhL9dmPfLJcsDTv+Opp+Bgk0ql6O3pZffu3axatQpFESdr+75WVIVly5bx/vvvo7k0PG439UPrGTlyFD29PUydKpLshg4ZwuAhQygpLaWmsobSkjJ0S0MlyblTaWPjIV584XlWrVrJgYYGurt7hehVF6FXXq/X2dDE82MWzJqdTtkXAu6R+oi+bf1HXtS6qom1z97EJAmX5nIAavbByKbfOUFhWM3CzxUPfqQ/N533b5qmg6u37+e+BX++e8Qe49msAd3OGpBg566dtLe1U1lV6XjwU6mksMdnhWPDsL5O31wKe9+yP+fq6hqKi0s4ePCAM8bULOywrZEw8u5jRVFIJpNcedWVDB8+gldefol33lmGy+VCGTt27F0gokvt6ivXmhVq3VAwxMGDB8lmsmzfsYNNmzZRVFSEoiiUV5ShZ3MUNE3TkEw41NjI9u3bufHGG5Ekmb//7W/c+u1vM2vWLH7961+zes0aOjs68fv9ThiIaLDk0gC9Pp/V9tb7t62l3AcpuhNhho8YTnNzk7iAUs66oioSumlSWVFJWXlZgajMbq04//8ApCjDimcVEBEcC1J+upNhChhH1Ep6w8xlcR9zIIhhChCJBMmkQOKCiaTIqIqwpfh8Purq6li8cBHTpk8jHo8zevRoYvEYm7dsQVFkIdSxbwYrTAREda2pqnPyL2jF2dfCZoTDYV0C/dGu/ZW6ktWqM/NyuEVR4ENTVULhCEtOP52SkhJ0XSedTvPcc8+xbfsOouGIY1VLp9MW9zrrfC/Dysc+3ObPEV6X2+Mhk04LxKkFCPF6PPi8PrZt286WrVuYPmUGmDBx8kQG1dTw/vsf4HZ7HGSqoshONKr9cKqq6GhJcm51SafTNDc3C5FdKuXMLXVdd7jv/4n9TxqgO2BaJ9lt27axYcMGPvnkE5qamsTCaYUN2UJJUXCqqIoIa0ql08RjcTo6O1ixYgX//Mc/2LFjuwgsMvRjp+FJEtJRNhD7Wmq2UNVaA4QlVGP16tU0NzcVzD69Xi9+n+BINDQ0YOiG07m00/v8fj8uj5srrriC3/zmN7jdbhLRBO+8+w6/uveXpNMZMmnBDMhmMs56k2+NPFzqZEG47gDOnYHa2/nq/4JuWl7r26FkKiqmAT29vezfv5/e3h527dzF+vXrWPXxKj5csYJ33l5GKp1g/oITxTpk6RgURaGtrY1//OPv7Nmzh8bGJhLxJFk9K/RaWZ101mYlZAcIkjGPp9d0zBCf/J+VPid5gQPXHAurUNC7kBWF0tJSamvr6OrqKmALOCNKc+DCrGBdOswNeiRHgc/nY8yYsY4tMBgMFvy5Law2B4y+NgtyR2RZQtU0/H4/yUSSSZOnMHr0KBKJBE899Vf27d9HPBYXJE5dzP6zVofALtSEDsaw1hgFwzCZPGkykWiY3p5eDMNk4sSJjB8/gQMHDuD1esnoOv5AwHmmFEXG5XLzxONPcMkll7BkyRJCvb38/R//QOkNBu8SwjS9X8s0l3UvEYlESFtpStlsFkmWWbhoES3NzYQsQILX46Wyqgq/3088FmPdunXE43FuuukmTj7lFM4++xweeugh3nvvXZ7+5z9xu90sX76crKXkdrvcOa+/VfH0TzUaWCiXyWbZt28/ixYtpqHhgAVGyKmSfT5xGu3s6Mgjy0kDB0PYG50kOR0H3SLvlZWUktF1TEN3IosNy6KWyaQtpbT5uWZSDi2R3PVXVdUKHhLtzUBREUVFRUyaPJkZM2bw8MMPU1payhlnnIFL1QiHQsRiMSQgq+d8p7IiFfjq87Gz9rUWFbthFS9mgac/fwxj9m2RSgMgU/OUq/mBvslUirSVHuh1ewiHwoweM5pgMMhTTz1FNBolFA4RiydIJoRCOpPJ9BPFHO9ClO8Lzg/HUBQFA4NIJEomk2bnzh10d3dTXVlDUXERCxYuYOqUqaxc9ZGjljcMQyjmkSwLaQZFUR1ilz3esdvLAhTU/7Q+0PuQjsPy1I/Al1cQKVbXyG7v2nNFoaQWi6mezWLoArLk/Ll1XQzDIGXlGph5G+Phtoj8cZp0HHOBvq4U0xIzys5BBCdBMp1K4/F68AeKyWTSTJg4gdbWVnGSUTVUTaW3N8jll1/Bb379axRF5cDeBpYtW8ZDDz9EKBQiFos746pMJuO0wfNFov9p3s/hvo7jtDEM64QmFVBSrSfGIQBK9vPvYNUloS9QVE444QT8fj+Kqjhr045t23jqqb/Q1d1DIp4gGota97V4frKZrIOLzt/8cz9/QW3/fgUA/Tq2+fel/WvbaRWPx/nmf3+TYcOHsWLFCjwezzE5p/pZ447Rlmr/m4Dfj9fSyIRCoX6F29GgdPktdyfcyQKERaMxhg0bxrx584jHY7z44ou0tbaRTCQFZCybcToGdgGQTCaZPn06mUyGuBULLMkSjY2NaKrmdAtGjR7NgQMHiIRDGIbBpEmTiFg023Hjx3Ho4CEuufgSbvnGLWTSGSorqhgzbizPPPMMSjabvctt5Z5nMhlBLLLeTH4uu/1hFhcXM278eJqbmjh06BCTJ0+mNxJCz2QxjazF6xYncJfmYsWKFZxyyqn4fH7efPMNKquq2LBhA+vWruV39/+e2bNn8/HHHxOxZlLZbAZFVa0kMCOHdJRyW4wDN7D6oaYEMhIlxcV4PF5aW1sLuPiCya+TyaQsKBEFC3X9sHrqhw0jlUw4Suf8jUaWEOK9dIZMOiXEYBZd0KSwxTWwze7wYBR785WQ+wVG5M8U7ZObLMt4vB4H3fv8v//FRx9+xPkXXMDUadPZv3+vEPcgChNVUa1FRCmI/pQtZ4cky0J3YFVLXl+Ox1BRUYGh6znnxtFCafL6a4XWFVtolSWRSAh+dzLFktNOp35YPR+8/wGJRILnn/83wd5eYrE4qaTVHrM2KnvhtG2dfQu2o1qQ8mZqtsVLUTQkySSdyjht25LiYto62tm0cSPTp0xnUG0No8eMZuSIkXy2+jO6e7rx+XwO5VC0JUVoVv2wekExtESI+RbWI/riD9u9kI48T5cOXwz0nSEerUvSj6OgGwVWuMMCcI4h+lb6nDuJosj4vD7LfSRse0OGDKGpqYlUKomu6yTicVRr4wgGg1x79bX8/oHfo2kasUiMd5e/y+8f+D3RSIR0OkMimSSdTpFJZ5xTf260mKOrfSHvYaANIu9zsp9v8VHLTgFndxz1vMLMMHLUt46ODqZPn8HIkSPQs8IrrqgKK1d9xIoP3icejzt26kwmTTark7E2f/ugJ1jyFqDNzKGBv+gf9pp1WK1EPpNCFjHURUVF/OXJv7B//z5Wr15DcXGRkz/hZIMc5nt9HmCQ3Y3I6ro4gOQF0x3P18t9loXvUdU0stksgUCApUuXEgqFePrpZwmFQqTSaVLpVIEWLpvNOrqglpaWHBPA6n6oimzRAsVe1djY6ATr/eGBB6murmLZsmWcfvrpLDltCcVFxdx55x0kEgmhI/O4+fvf/85LL72Eqmri1FhSUiIicTMZsLLFh48YQW9vL6Fg0BkJSJKIWdSsXO1kMsXF51/EU089idvtJmMVAD6fj7Lycid85L777mPVqlWkU0kqK8rYsnUrixYt4u233+Ken93D+g3r+csTT+DSXKSsqFTxxm2bWG54VGABMU1xylVkgqEQp5x8Mh0d7XR2dJLVcwWMbhj01TDlU9zGjhtriYAamTJlCpIkTqvhUJBDDQfFqRGIJ1NAzg6VD/fIf135sY8DAS2kgoAUyfF2ypKM15+b08l5JzlNU3FpKnW1tYwaNRqAqupqXnn5cZ7+5z+58sormTJ1OqtXrxUQIVkW3HRr1pdIJJ0M+lgsRjgcRtd1ysvLGT1mNOFQmDlz5/LySy9hGDqdnZ3HrIA2c2EDTsyZaWFzDUMnldLJZhUhYkSyFuMEZaWlRKNRVq1aSU9PN+l01jmhGbpujYDywD5S395foT87f35rHmYWDZJli8li6EItnslkcGku4okE6UyGSDjEK6+9zNgJY5BlidOWnEZRcRHf+MY3RIR1CXS0d1inL8lBd06fPp2W1hZHMJc7tRzujjjMjNkE+wxj9plbSgNs/ObnaRlQ+DX7sjbsYqv/65Uct8wXvWfkvw7ThEQySTKVJOAvwu/3smfPHtH6toJ8AgE/w4cNZ9TIkUydNp27f3q3QL62d/LOO8v45a9+SVbPkkmlHQqentWdZ+toha3d2sgBtT7ne5akgjco5Xs4JUmk1ZmSwxywYUmmBZcyTYN0OoUnlUKWYfVnn7J48SIy2QyqKsYfe/bsJRgMOZ0qAfMxkWWJTCZtHXwM8Z+R8zjY1jfzPyhsDo+qNvsdIk1HjC2jSAqqJjocPr+PUDDEN275BpWVlVRUVlFRUSHW4mROiO24wgbAUh/t1j/c2mVvwPZIqS9u/Kj2j748A+v+tdcuTXOxc/cu4VKKRmltbXGSQ3OHRjOvW5G7pgX2W1O4p4TWx4+pG6huF2PHjmXv7j2sXbeGt95+i1GjRnHOOedy3tLzuPba66gdVMNDf/wjGzZsoKenm2XL3kFzuVA0Vb2rorKSWTNPYMKECWzavAm/P0AylWLcuHEiKrinx8pGlikqCtDe1m61lWWam1uorq5myemnk81mabUqFp/PR8TaYJqaGhkzZiw/+OEPOOuss3nhxRfYt3cvnV1dLHv7bWbMmMFNX7uJM888CwlhQwqFQk6r1hGXWa0ft8ftLLCKJWxJpVIsPW8pj//5cZ595hna2ttxubU8eILUDxNpX9FQMCSITJ2dYJr09gZJplIEivyMGzeekaNHE4tGmDRxEuMnTMDr84oYSa/IkbeFYQ6VT5EcL7JdIOS3ofNnUYWn/Fx4jqapVna9mP273R7Hsz1i+AhOOflkysrKePfdd9i8aTPBnl7Ov+BCRo8Zg2QH0njdRCNR4ok42UyWVDKFogh8cN3gOk4+5RSuuPxybrzxRvbs2cu2bdtoaW6xbKDSYbGe0tFmn9a/CxQVOT79fEywy+WymOLlrF23jvKKcjRNY/ny962sCFGo2BoCXdcLRgrO0mUe/TUVtNTzZ5JmTnDqVOqWEM3lclFUVExrWyubt2xhwoRJVJSXM7R+KLNnz+HFF17E7/fT09PtpOMZhkiUbGpqYsyYMbS0tPQJfLG0JkfZrKVjX2s+1wn1PznJSp/jdeE4Tj7fdzYMg+LiEoqKighHwtazZAX7+P34/X6qqqp46I8Pc+mll5JJZVEUlX8+/U/uu+8+JIQmQqRapslm9Dy8rOGMqGSkz/Hejn59c+AzsxB5m7/Qk4O8mLbVL08Q7TwDkozbQgbXDqrlnHPOIRQK8re//52ZM2fy17/9lT179pBOZ0gmxakybR3SCsR+Rp75ZoCNTjrGz6tv/kfhwUbqJ9Z21kKLhW8L2xRVwe1y4Xa5OPuss7jrrrtwuV2EwyHee+cdDMMgkUoKiJX1mRlWB+NIdkMbcVwAjpMK3WD23H7cuLFMnTaNgw0N/cSLx1MIKYri6EqcBFjTRNVUgsEwZ51xJqqq8te//tVxDaStjJGCbswR1lu74CorK3PonV3d3UhI7Nm7h1g0SmVFJVOnTeX0JUucfJTe3l4efOAB1q5bL9ZWw0DxeNx3YUJjUyPjx48nHo/T2dlBRXkZO3fupLu727HsGabh2Ed0izqlKAp79+5l4YITaTh4kEg4zJAhQ8Rszu1i/rx5nHX2uaz88EPi8Ri1tYPQNBfrNqxHliR27tzJxo0bmTRpMnPmzGHu3Llc9+UvM3nyZHx+v5PVbbfFhKJXJIEpkmwpeSXGjhnLCy++gMfjobWtjffff59sRsw77cvp9/v7CTjcbrewgllRnNlsVpz8wyFaWlrYsX07DQcOCO5zLEYmm6W8vIyJEycyfNhwBg0axOQpU/JuNoN0OmOlMaUJBPwOrCEnGpOdGa3IhRcWPUWWLTWn6GpoLnvzd+PxePC43ZSVV1BZWcnkyZMZNGgQr77yClu2bCWeiFNaVsb06dMZNWoUU6ZOcUA2g2sHc+KJJ3LxxRfz9Ztv5mtf+xq3futWrrryShYvXszqz1Zz7733YmISCYXz/POHq/YH3mD7Yint1lX+35HziGCxWAyXJpDTH3/8iWhrZQSNL5sVs2mP251nwzE/5+nr8AIgxRIeiVlq1sJwZhwQ0vbt2+ls72Dc2InEozHGTxzPrJmzGTd2HFu2biMaizjdKpfLRTKVIplMOshpO9DE6vIWMBekY4iyPurWPcC8XTpSe/IL3NyOae8/3CJ2LB+ZIlNcXIzfH6C9s93RXdgkQLfbTSgU5rprv8xFF19EJBgBQ+atZW+x4sP3aWttJZGMizZrKkUylRKQFcPIBWeRi0+V+sxVpAFtbdLxX4MBR0BmjkthFjIHbGEzedjW/Px4TVMZXDeYSZMm88Mf/YimxkYuvvhinnrqSTo7O9F1sQZlrWepwCLrBMaIwrekpIQJEybQ0dFx5MJUOsotmKcXK4g4tnDN+dS6nMZMssLRxCHO7/dz909/yujRIhUylUrx9ttvE41Frdh23QK5ic0Sc4CiWc6Js81+6HnxcyAQwO12kcmknWIsECiio72dcDhyTGMDzeUqiNot6AhLIOXxAyTJxOV2E4vGmH/iiQwdOph//OMfqKpKMpGwSKNivGly7BqnWCzmOBJEyqoLj9tNoKgI0zT45n9/i8FDBoMk4XZ7UBSFxYtPYsOGDXR0dIiCRdezdyWTItls+PBhDBs2nO3bt1unT9WxKRXwiA2j4IGQZZnNW7bylS9/hfXr12GaJlVVwj5x6FAjZWVlDB8xHJ/HS1FRCevXr2ff3r00NTVRWlZKW1sbr7/+KkOHDGX06NEMHTqEmTNmsHjxIhbMX8DCxSdRUVFBJBKhp6dHpHvpWapqapgyZSoHDjQwedJk2tvbWbVyJVdceSXPv/ACJy5YIHKxZZkhQ4YQDoeprKxk/vz5JJNJ5sydy6xZs6iqrhHEN6si8/n91NYOsnLhRYSw/SC2trbSeKiRHdt3sGv3Djo7O1EUhSVLlhAIFLFz524qqirIpDNWYlzayRvAgv/kiwxtrr2iKiJCWVEtUpgI/XG73Xi8HooCAWbNnsWZZ5zFnDlzmDptGm63mxdeeJG9+/bidrn49ONPGDduHGPHjsXt9jJ69BguvugiLrjwAk499VRmzJhhWYUaWbNmLSNGDGfHjh18/eavi46Gx+fw7MHsg5Oknxq27yllILsj1uKQ3+WQZaE/6O3tYeGixfzyl7/koYceFLP/VMpJ3TMMw0qJPEIsq9RfjHZYXYADx8ijIFoEOdOkwActFLcGkiRzoOEA3d1d1NUOobK6kpGjRjB12hTGj5/Ap59+Rmtri8N6kCzm/uDBdZSXV5BIJMlms1Z4keQ4Qz7PpivlLcTSUQRn/y86AMci/BqwW5pvDzxc3qXUt0gU2QbFJcV0dHaIcZLNsVBkioqKiIQj/OAHP+Qnd9+FkdXZu3sPf/rzn/jDg78Xm71h0BsMEo/HSKcE6hhJKtRFHOXDkI4xDOiInag8x5DZD5doFgxx7NemWN0ou3uWf3S1DxpTp0ylqbmJjo52otEoa9etI9QbJJ3JOOmrgidv9MthsX+taRqjx4ymtbkF09AxTZF+V1xcXJhZksdwkPoU/6aT8pgXcmT/WpactMH84CGbTGoL/4T1uYzvfve7rF+/nt7eIEOHDuX1V18jFA6R0bMiICfvlNz3WXLGKnnPuN3SVyzan2jLizGorpsO4jkYDOYAeBJ4LfvhwMW62Y+JIeU5n5wRj9UFsLsCyWSCmTNnMnjIYB566CHcbjexWMzBkx+LwLlQfyPlaRjkgnVg3tz5fP3mr1u/J1s00CqKSor4/e8fIJ1OWV1PRSAwM5k0r732OsVFInZSksClaU4GumhBSeB4qnOJSoqiEotFefnll7jo4ot4/LHHGT9+PBdffDGvvPoKb77xBpMmT2LYsOEkU2mKi4s5++xz+OMfH8LQRVJeOBzmtddeZeToUbz/wQe8/PJLvPfee8yYMYMJEyewctVKgsEgEjBkyFA0l5tFCxdSVBTgxptuoqS4mHvvu5f9+/Zx0kkn8ewzz/DGG29QW1vLtm1biUYijgK8o7ODRDLJ9m3b+KCjI4egtE5sYv7dRTKZcDZvASdKo1q59iYSxcVFGIbJmjVrWGPFKUuSzPhx48Tvr15NRUUFvT09ZPUsHq8HTdUIBYNgKXtz/8lO6zmRSIgN2edFVUXc5/hx4zjj9DM56+yz8Lg9BbZFXdeJxmLo2Sw///k9TJ06jYrKClwujV27dvHOO+/Q1dXJvn37WLVyFTNnnMAfHvoDPd09XP/V661xSxqXy513yrceYjtDwPLAVldX09LSwuzZs9m5cye9vb39g43yugcFC6KJs9mapoGiqqxYsYIVH3xAT0+vk0JXCF3qT+TK7zKYh5lpM1CAlONIKMQd63oGXc/i8XjIhXUkiMUTFAUCDBtWz/r16wgHg1RV3c6wEcNxezROOmkRw4YNY+/ePaia6vjSE4k4LS0t+P1+EokE5eUVhEJBDD2dd12kwwJnDqcPyN88zMO0PvvaM/t2a8xj9EpzXLjbXHFimhxRoGAeduifK8pshbw/4Ke7uwdDN0RinqricrsZMngwpmny37f8N3f+350kEgk0zcXyFe/zlyf/THFxCXv37CYeTzgbYDarO1jk/BavOWD0dn9diWkem5fcPGz4Qd58uA9ZTxrAM29ap3Ub6qIoiiB9SjKaqhLs7WHo0CHc/7vfsXLlSt57911amppIZ9Kk0ykMQ3c0Tod7vTb19b133ysQV6dSKYYMGWK5QnRCwZAzhhjIkdUXry3bYH2JAiCN43awCgnbYeR2u2lvb+fb376N0tJSfnLXT7jpazcxafJEiktL8Hg8JG1AjmGSyYpYY9NUMIwsHq8X8tw99qYoxjyFYkRHE2ZlETh/LuVGMZIVVFRfX08w2Etvb7CgADDN/neO81xZY5x8x0cmk0WWxUl99erPGD16FPF4DJfV3cwfbxc+rwORWfprypxOsqygaSJBcsqUKcISmMngcqmkUqJb8cTjT9Dc3ITf6q6rhuVr9/sCnHTSLC655FJqaqq59dZbBWs9EkGy7DK5QATTwg2KIsCuUjdv3kw8Ecfv9zubg33i3bF9J0OH1PPEE49zwqxZXHTRRZxwwgk0NzfT1taGLMu89vrr7N69m/rhI+joaKerq4t33nmHd955h7LyMlJJMQdqaGhAUWT27tlFKpXm5q99nd/efz+nnHoqmPDWW2+yfccOfvWrX/V7FpPJZAFBLn9TsdvWOc+5VOAWyGYyGFb+uOZyE4nEBJKyDzr0wxUfAlBaWkp9fT16NoPH6yWRTBKLRCktKyMWiyMrQtFvP9RlZWXOw+q2NuNAIEBlVQWjR4+hqaWFbVu3M3P6dKtlqREKiQwFTXXhdrvYtm073/jvbzBs2DDS6TRr161l967d+Hw+3C4XFZUV/Oq+X1FVXc355y1l27atuD0ea26YdE5I9iJkWlY2O4sgGo1YN/LqIyI0+25rtl1SMg0y2TRKWrRwJ06cxJ69e4nFYuiGEDrp+e6TAQI+HNXuEURA/Z/RQsBTX7GZLAnfvqZpZDKCre21Fpb29nZURWVjLMKfHnuU22+/A59PAD3uv/+3vPfeezz04IPE4nEny1uSZGKxOKNGjSCVSpFOewtAJg534SiY+cNBf47G5D8sKOgIG9V/NP+WjlCMHaV6sN+jne1w5ZVXOs9+fmu1qKiI8goxArvuuuv4r//6L2KxGPFIjEf+9Cceevgh/D4fwWDQiZDNZjLOKSydTVtCXbOPPbUP+tc80n10fJ/HQDAn+38K6qO+ICv7wGX9azt90jDECCMYDNPQ0MDHn3zKggULuOHGG/nTY3+y7LqmM6K1UeOHf72SNQs3HBGzTaeTkHB73I5FL5sR6xgghLDWtbItjLZd2S6sJdlOILULAyVHmUV2up6pdJIZM2Zy/VevZ8UHH9DQcIDaujoUWaG2dhCbNm1ClmRURSWrZCgpLhbcGlkcSgyrMLGLDxvNmz8ytNNIJUli7NgxNDU1k81mc7He+cWYaZJKpmhoOOjQhsxj/pztAsJKpZJANmTRRZZh+7btbNq4UbAfZBm3y006ncobSZn9MNT5nJZcaqXpFC5CIC5ssH6/n0E1g5g7Z05BKquAj+3k4UceRtM0QbfN6qiiUpQYO24cEydMYtGiRUyYMJ733lvO88//G9W6aLaoQTINMCgIyshv3e3dsxebw93e3p5rGcsmy997l+9+939obG7ipRdfRNOEd7qoqIhoVPhVd+/ZzZ69+6iqqmTe/Pls3bKZeDyBS3Vxx8/uZNmyt3jrrbedC1NVVUlPKMgtt9zMA7//A4FiP42Nh9izexd33HEnf3jwAUFgc2AmeSdBU3zw0lHCKWwKVY4fgPWh4dDJZEWgO+32jyxJhEIhPv30U/yBAKFwmJNPOZWRI0fx0ksvUFxaQrsVdTx58iSWnnc+GzasZ9PmjdTW1VFUVMSCBQs54YSZHGg4wNAh9YwbN5ahQ4c6r6+np0fEt8qCZJaJZVAVhbfeegtV09BUlZKSYuf0lEgk+MMfHmTUqFH87Gf38N7y9ygpLbXiLnNiI5vs5/f7HTuKy+UqAPIcF8Am3wdnCtiRp8RDNBrl1FNPIVAUQNM0kuEIelZ3MMx9jy72gpkvXLJ1FTmhqHkcSuW8k6D1fYQrosKB0ui6TiwWp6ioiMrKKlavW8ujjz3CN7/xTXx+HyNHjmTYsGFs2ryZTRs3ggmbNm8iFosJoWN5BSNGjOTNt97E4/UQi8byEvNMTKn/qb6w6PnCMPzHVTwcbzFQ4HKQpP56jT5fUMr7H/taZC2x5/bt20kmk5SWlDJl6hQSySShYJDKyioWLlzIVVdd6fijZWSWvfsOzzzzT7xut+Pvz2QzOWGVkRX2X10IxyTzP4THf87rZPb5lXmMowVrMmwJaq3NWs/S0tLCnr37ePDBh7jiyssthr7bQZDnyHTmEV9V32CdfPGe/fzbs2aPFTttkxkVWSkII8tkMoJPYAn+bAuzJMkoiu1oEpHmmstFIBBAkRUeeOD3lJQW8+c//xmfxZEBqK6uxuf1iH0IrFhoXXASkC0GS+6k78zI7GCfvAutW12V1tY2q9gUAXD5e0BhEJdxTB/u4Sy49p6om7pIZAU6uzrpDQYF9CkvwEd8VuYR9qFcp83+H2GdzMXEez0+fD4fS5aczqLFi62RpEwmk8HjcfPvf/2bltZWigIBceDCQDFN865x48bxxhuvc8455+DzeQmFQkycOJGnn3nG8cqK9g9OopXN30cqXEwdxr3VigkEAg4WVZIVdu3ehSIrLF26lMrKSrbv2IGqqGQyWQJFRfh8PiorK+nu7mbEiBF0d3eTSAqRxKGDB5k/fz6jRo8WYr/WVhKJBF1dXUycMIGS0hKefuYZIpEoxUVFzJgxg9NOW8Irr7yCP1DkzK3tGFTTBjbkQW7yoRH2e8m1jujnJMjPD9BUleKiInQrPMXn84k5tmXH6enpYeOGjYSCQebPn8+ixSdRO6iWH9/xY84+52zKysuZPmMmN910E1dddTWnnnoKw4cPZ8b0GYwcOZJ4PMaaNWt46q9P8dhjj/HAAw+wd+8+p7ORtbj/LpcLw9Cdjb+0tIS21lZu+853ue7L1/Hqa69y909+gqZpJJLJXDqjdQ00zY2u64wbN45MJkMkEiFlzVT5PD7gvMVAnOQCmKagT44aNYo9e/ayft0652a1E9oGWpwGXjDlY1Iu5+dcYB4e3hIIBBy7jqNzUCzhq66ze/dudu7ajUsT+pCamhoWLFhITc0glpy+hMZDhxg6dCiBgJ/S0jLGThhPJBwhGOwV4CBnrjvwM3+sTgDpc2ohpWOA1vwnRcfxFg/2M6cqKiUlJURjMSQTvD4f2WyGqdOm0tbaQv2wYfz0pz9jzJgx4n40TV5/7TUefuSPKKpCb28QwxQY7kw6K4pJIyd+cxbmo94nx2jp+3/yo9Cp4rTVpRzv3e32UFpaRnNTE00tzZxx+um89cabdLS3k7FErEZeC9r8ghgGdpcsFotbTJRMQXjPSSedTGVVFe3tHcRiUSdi2hb72XkmgYAfr8/rdCWvuPwKLrvsMv7217/y5JNP4nZpzJs7j4kTJ9LU1EzDgQZi8RiRaEQcQp11W3YyWQrshnmt/HzRrSxLVsplJdlMlnAoZIG6zAHdD/8JDyJfH2FYaGCXy4XH42XChAmsW7uWrK6Lw6lh9LORH/HrWuuorafQNM2hZPoDfq6++iomTppo3fcSpmEiyfDrX/+GhgMNlohf7OuKx+26q72jk5kzT8AwdG668UZGjBhJb28Pzz77rFOBGobhzIjyoRTSAJilfEGY/fDZp7ZwOMyhQwdRVYVf/OIXdHV2sWLFCjSXSjqVJhwOk0qlqB82jN27d4kZuKUIbWtro+FAA729PYyfOIF0KkUikaC3p4f169fx/PPPs2vXLg42NNDc3MK6tesIBALEYnGSqSQZSw3scgsbmqHruD0eB8lqZ4prmgu/3y9oetlMvxukbzqWaYlCXJqLSVMmoxvCLREoCpBIJPH5PGiaSigURlNVvB4vO3ZsY/iI4fz3f3+TE044AbfbzejRo5k6ZQoVFRW4XC52797Na6+9xiOPPsL9v/sdf33qKd5Z9g6ffvIJ+/ftp6e3m0QiKao567QjPPdpp/VmI2ovvfRSfvazn7Jt2zZuvfVbpJIpUum0xacXEcW2BsImdLW2th5DuuKx5YDnM7NdmmYps5OMHDGK9rZ2tm3bhtvtdk4chYjSo6eNHU5AoxRYPvM7V+SKAZsIaN2j8VhMUC+tmFg70tVxNUgyiXgMTJMhQ4cyeHAdPp+PiRMnMHLkCCQJyssrkGWZt5e9zUcffkhRcRHFxUWUl5XT0dFRYA/9POEmEtIXpuiT+hLcDnfVpS/YTpgnxtQ0F1OnT0NRNFqbm4nGRMEUCoWYPHEyl1x8KUvPP5/JkycRjcbw+bzIisxvfn0fe/fuIRgMEQmHHeGcbuQgOgMxDv4jF0Tem1cVpeAAcaxUwKNtK3YXxRbd5bqwoh0vSwrhSJhJEyby29/9ll27d7Jn914kSczwc1a5PnoD6fgwvkOGDBEdAIvNIiuC5bF06fn4/QEOHTpEdXU1Q4YMYdy4MZy4YAFf/sqXOf30JcyZM4dZs2ZTVl4mItGLS8hmsxQF/EybNo1xY8cyc+YsbrzpJuLxGN++9VYi4TDhcISi4mLOPvtsVFVl/779jBo5iuHDhxEOhUkmEqiaKjZ+y1Jo567kXyvd6goqlvUYJKoqK2lqaiKRiKMosvV3CnUCR7tHjuYG6bsn2r90u0W7PxyKEAyFLEeKoDhiiROlw3693HNvd5hVRXHWeFtMmUgmmDp1KieccIIzRHC5ND76aCV3//RuNE11mCWGYaBmrA3u+uu/SklxESNGjCTU28uUaVPQNBeapgrlpTVPsiu6/FAeuy1hE/byfxTOaXXnVP3aa68x/8QTURWVsWPHsn37dufNZjIZdm7fgcfrIR5PUFdXR29PD9FYjNa2VlrbWtmxYwdVVVXMn38ik6dMZtuWLTQcPEh3dzfNTY1kdQOvx8uqVatYfNJJ1NTU0NTYaDEEdEHWU2SRvmToKLIist69XsKRMOl0imQyhaZpTJ4yhW1btzqs5sP19hLJBJ9+8qnYOFSV7q5uhgwZQigYYlDtIFEFahq79+zmxhu/TnVVNX/5y19IJpKMHzeWvfv2MWzYMEaNGoUsywSDQd555x2WL19OKBSitLSE0pJSgT5VFJSMQjoddoRzOZiE2NjS6QyxaISxM2Zyx4/vIBQMctdd/ydOtnJObGVXk7Zv+FgAH3B8qFf7XslkMoTDYYuWpZBKp3C73bjdQiBZGPxkHmGxNI/tuGktoJqmURQIMHzECDZu3Oh4/u1Rq67b3Oyc2CqTEU4ORVHRVPFaTevvxKIxli1bhqZpzJ83l6wuiIUul8acOXN5/LHH2bZ9G5qmoWkqB/bvx+PxMGrUqAKPcr7g8biudL5QrY/C61hO4NIAmgCpD0hpoPtc5A0cQVx41I8j/x+LWabosCjs3LGTWDSK1+sRtibNxcyZJ7DopMVc/9WvIlk2Xa/Xw6effMLWLVuorasjHk/Q3d1DJpNBVVSnoLVb4Jj/WRujr5bRHn2Wl5ejqiqhUChPrU+/cCezj+ikL+jlaGQZM2/2a3cvDdPgQEMDV115FYZhsG37dqKxKH6/3zoRZ53Wcf7J8ngf57KyMnFStU75YgyoU1pWSntHO9XVVcRicQ4damTbtm0oisIjj/6Jr3/t62DF3gpRubg27e3tJOJxvF6vUzhVVVVy//2/41DjIYoCRSSSCRoO7Mc0TWpra7niqivIpNOEgiGGDBnKrl072bxpM13d3bhdbmHbRUNSZDRFIxaPgQTFJcXEonGy2TSowsV1qLFR5KHIitNpFK8tBxuzLaaKohCPxwvWQaGF668fydeymtaHJkk5xLK9r6XTaTK6cDbZaYJ2l70gj6avY0OioBjEos7aowTdMMhmM3i9PhYuWGh9HRnDyCBJKi+++AKyhDV2zzrfQzFN7lIUhXQ6zcknn8Jf//pXZsycSV1dHYlEklAwhCRJRKMRVGt2k6+0zrXUpGM+rdnQle6uLubPP5EzzzqbESOGc+DAAaHG9vpQFVWgbFWViKXgF8EZsgOzEeCVRnbv2oVhmgwbNoxp06dTV1dHSXEx6XSGdCbN3r17uP76G2g8dMhaxWRrVi8XzI4NQ2BvDcPA5/eRzYiUqmgkQiKR6Kd2t1vabrcQyowZM4ZJkyfT2dlBeUU58xecSDKZQFFkLrvsck4+5RS+973vcdFFF3HuueeyZv0aujo6+Wjlh7zzzrs8/vjj/OMf/2D9+vV4vV4WLVrEJZdcwle+8hXmzptHb7CXPXv20BsMCj62aZDN5ESLiqJgmLmYULfbTTqV4vvf/z4LFi7gV7/6Fa+/9jqyLBMKhXOnf1OE7mB+QYKww2Btpbx+r8fjQZYkigJFRKIREfxiGrmkrbwCoB9/Xjqe2XSuLehyuxk6dChtbW2W1sCw7HmFvHInJ0BVxTjHxEJki1ANt0sjnc2QzeoMqq1lwcJFaKqG2+0Sdpuaaj777FO2btuGP+B3FOjRaAxVU6gfWk97ezuaqubBjcz/GDErHYeX7YgnmM+RS3C4fIAjnaAURcGlufB43IK/kUiIaF/DQFM1SkpKSGeznH/++YwZO5Z0UnTv3n77bZ74859599136OruJhqO4vV56e3pdfCyiqo4lrE8gPwXdk/bavloNFqghxloFGWPC0Wwi+6o+o+la1B4OhWjAEVVLJpmmltuvpnhw4fx81/8go7ODjJpi6DpUOj0z5WfYb+G9vZ2SktLKSopJhIOU1VViQl8+sknNDeJ4DXb6upyuZBlmbVr13Kg4SCzZ8/id7/7Hd/9znfZuWunWN+zOl6fn5pBNZSUlBAIBGhuaubbt35bBDRZ8/2xY8Zy3tKlaJpGdXU1O7fv4K9PPsn77y9HkiUmTprMmDFjCIWC4vobYvc1MBk6ZIjoghgGiUQc0wS3S9xnqqo51lSbCGn2wYqbponP58Pv9xOLxfB6PLhcLrJW2J2NwHQsj/nxu/b/HSa3RgT7KCRstr8jujbJocKsUXuecyI/s8WJolcUgZCXRCeqt7eXq666mquvvqpg9NLT08P9999PIiG64Nm8PBAFuMsOpNANk1tvvRWPRyjQ6wbXCYWhqrJ12zYRzZjHYjcHqJiP5UaTLEeBLEl0WmlPXp+f1pYWUmmBEZ41azYNVgKh0BbIuYCfvJmSHcbS2dnJvr372L17N7FYjKFD6pk3bx7z5s9j6pSp/N+dd5A1sixf/gHlZWVkMlnxsFizmVwGs3hdqWTSKXZspWjfoCTx/UW1WFJSzIgRI7jwggvp6uqitU3kEbQ0NxOLxTjp5FM4++yzKSkupqi4iGuuvpJlby9jx46dNDU20dbeTiqZJJVKsn79el544QVefvll3n//A1599TUuuugivnHLLUydOo2glRYWjUbxeDwF4TM2U9tW5Lo9Hg4ebOCSSy5l0KBBvPLyy8SiMYuGlu1j7fnPrGHSMc5N7ZATe8EPhkJ0dnY6wSxH1RpIx/+iDEvQdPDgQTH/su4pu5i0oz7tzkBOoS6jqjKqqjltdwfwg8nEiZPZu3cvLc1NDBteTyYt2BEjR43mnXfeIRaLinxwC+ASiUapKC9j9qzZpNJpenp6+qnhj+SrP56C6yi8oH6bzDHnFHwB94etC/EH/Fx19TVs274dSRbzbbfbjc/vQ1ZUfvvb37J06Xkk4nF8Ph8ffvAhd/7f/yHJErF4nK6ubnp7exk0qJpgMIhL0wgUFZFKpoSexGaXfMGbf8HGIQ1stdM0ocEpKipyrNSFmRRH18+Qx5cv6IyZEItEuf7665FlmT888Ifc86ML2qFpHBs4S+oDbMovYmRZJhqNEglHHGqd3SW059Z2EW0YJpqqEQz20tXZyRWXX8HFl1zM1i1befjhh9m0aROvvPIKL7/8Cu8sW8Zz/3qOlSs/4vl//4vNmzdjgAVMk9BUlUsvuwy/34+maowdO5Ylp5/OrFmzKCoqoq21lbq6Wq6/4SZOOukkkskknZ2dlJWVEY/HyGazjB49lrFjxxIJRxyRaXFxsQDopDPIiuzU3XIfkFEqlRKhapKE6tJwu9wWTtnIteIHgKDl/iskP0pyzmaYszqb/Z/XAXz+drGYs/vlwpRyRYtBIBDg/t/9noqKcgcZrGkqL730Is8//4Jg2uQhla0gJukuQzdwaxodnZ0UBYpYfNJiUqkUJaWllJWWsXDhAt5e9jaxSCSX29zHlmUOoKY/3MKiWMIwJIlMJsvOnTsxdAHZEarrGB0dHU70ol1Z2q1qMftQCnz0qqrg8XodAltrSzNbt2yhu7OLe++7l/r6eubMmYPH7eGNN98kGo3g8/pQNZV0Ji0UqpYf0xHQmIUYy8JWEMiygq4buD0uXJqbPXv3EI/FCPb2MKi2FlmWWHLamcyaPZuDDQe5//7f8X//93+sWrWSUDhER1sHbrc7l1BngS0CgQAul4uO9na2bNvK7p07efqfT/PxJx9z8UUXcfMtt7B06VLKy8rZvHmzoGRZQkuB2BSnBEwRbxmPx+ju7uHaa6/FNE3WrFmN1+sT7y2vpXW4qvVYDoH9kukOE4JkWouNfRMmEgnisZhzzQ/L4P4PADWy1AcDbN2pum4UFEGqoqC5XHg8QrNhF4fi74hZoW6d5rEsfZ2dHWzatJHe3l6aG5sYNnw4paWl1NTUcMLMmWzcuInp06aJjkteDvv8+SfS1tZOW1urhYM1v4Auy7FvxLIlorLnifYnKB0rU/0o94V0tI0GyRKC+dm9exfB3l7cLtF2LSsro6iomHvuuYeLL77I8Uqn02nWrPmMNavX0NnZSTQitC+pVJLm5haqqqswDD2XJWFthvbpSj6WWLhjCZfqu/DnbSATJkygsrKCrq5u3G4hpo3H48d8Cs8XINuRsP2fSyH8crldzJo1i5EjR/LIww9bIy0hBC54jqyfy8rKrJGAjmkeebjWt+gwDIPikhLcLpezMeb2ARwYjSwrFBcXE4lG2LptK2eecSaXXHoJiqLw8ccfWxtwlKbGRg4ebGD9+vXs3bMXVdNIp5LOew+Hw5RYEKit27Za8DGNyZMnM2/ePM4//3wWLz6JIYOHMm3qFM4662wuvOB8LrroIlRVpaOjg0mTJhONRdm3bx/xeMIR9qqqrb+RC6KK3W6PYxe0R3SyLJPNZK3CRCmEo8mF0b8DFQI5GrbUp6NmFsz3HXxwnzChvqFFtp3SBv/ISu5gcdYZZ3HLN24WnQpVQ5IgnUrz05/9jI72djHyttJVbTuy4vG47wpY7XLDMNiyZQtXXXUVJSUlZNMZqmuqqampxufz8tFHH1FULDCDhhUWYvYBteTbFo7UGyx4gGRIpVOkUyLAwt5wp06bSk93N263xznt56tJVUUBWbSTXS43LpfLyZ2vqKhg2rRpfPd//od58+ZhmkKlv3DRQs444wymT59O0PLQmwZOi79vO0iRZee1a5pGIBBwTopFRQEGDx7MqFEjqa2tpburm56ebrq6uhk5ciTTpk6jsqqS9959h8kTJzJ5ymS6OjtpbGqipaXVSj8U+fKmYTiJV4YpNiZV03C7NDwe4SHfuXMny955l7a2NpYuPZ8TTzyRJ596kkgkgtvlsgRCgh7os/y6sixh6Cbr1q1j5swTuPSyS2lsauLgwYNWO6uQCZ4vYMl9ptJ/wEE//EJnGKYVaarmuizWSU06YkresdDXcFTA9nzb6/Ggalpe2w0HzYwERfbpwArpwDRJJlP4fH48Xg9RK3HL7RbcBLvt5/f5SKZSrPp4FX6fjxEjR6IoCsNHjGD2nDnE4gk62lrp7OwkFothGAYjR4/m0MEGK+/82LQW0hdUHAjfNowdN9bS9ugDd/WOgimWPm9RJkl4vR5q6+oYP348O3bucEY0lRUVfPm6L3PXT+7mlFNOJpVKIcsKK1as4LHHHuNQYyOt1rUMBoNEolELKqNYjpWoc43tcaN90jIPs8EfD+1P0O1yi7ONnrU/P1VVSWcyjq35eJ0z+d/Pjs2W8sc8VvfMZW3Eo0aOwu1x8+RTT+HSNDKZPln19ohWsjgmhnncsb/2JuXxeNE0MebqG5/skD6tboDH7WHHzp1sWL+euXPnce6559Ld3cOHH35IeVmZGJ1YM/j8iG57fZdkmc2bN/Huu+/yzrJlvP766zzzzDP87a9/58CBA7z22quk0xnGjRtLVtfxej2UV1TQ3NyCpqm0t3fw8ssvCadTIlEgZjYdIJkgftqkxurqKnw+n8MDsQsFsdnKBahzRVEcZ4YsK/1a931JfX0zCgbuHOCIk/vliOThlW0rpaIouF1uAoEAhm5w6623Mn36dGcPUVWV3bt38e9//5tUKkVPTy/JZBI9m/v8lLLS8rt8Pi/TZ86gp7uHdDpNwF/ESSefZCkkZQxdZ9LkSXS0t9PS3OwkajnhEs7JQTrsYyX1UYXn2hkSMkLZWl5e7rS1RWRsUkTVGqYz9xAbvUYqlaK8ooI5c+ZQXFxEb2+IbCbN0KFDufPOO/n+//4vX/3q9UyaPElc8Dylf21tLX/961/Zv38/w4YPd3gCI0eNEulu1uw3Pyp09uxZ1NXV4fP7aGpqwuPxMGfuXIK9vTQ0HGTbtm2k0mkikQi6nqWnu5vt27fx3nvv0dLSwqDaQZx//vm8+cabdHR05FpOVmvKyOs42KdSO59dt+BEbrebqFVZX37FFaiqwvP//reoyBUZl+aiuLjYEarVDx1CMpnE7RGwoY6OTi67/DJGjR7Fc88951SCmUzGcTIM5B0+ngXzaMEh+aQ12x8sIkuz5CUHDzjrP9KIwv77dts1f4Fyu90gS1RVVTnhGflCPNl6qG2ro1gcxM+lpaWCmmUhpW2UqGka1NXWYpg6kixZoA+Z9evX4/f6mTNbgDhqamrweN1k0mmaGg8RtDoBPT09tLa0oGriXlNkxWlVwxcqvujXfdM0DVmWqKutswRIuqWe1//zb3G03HVZcjp7kiRxwqwT2Lp5M0OH1lNaVsrUadP51q23MmHCeItxIfPqq6/w/e9/j95esYA1NDQ4HQHxmVnCzFicQYMGCZdGIu7MTo/Ehvg8bgnZum/yA77sjT4ajeaQsl+gfia/gPF4PBi6TiQapaysjGlTp/LmW285hW2+0DIfMuSAgT7nPZZKJonHYwXcjX7X0up0ZLJpvF4vTc2NPP30M0wYP4FvfOMWMpk0n3z8CYqmOryGbCbjYH11XbdS8jJOUI+No4+Ew1RVVxEJhfF6fSxZchp1FjDo409W8ZO77ubnv/g5r736KuFwmK9/XXRKu3u6BWQslXLWhiFDhlBdXS2gcJYINZlKUlVd5eB5PR63laYoRuT2AdTn8/UJcMud8vO74n2vj93Fzm3wuS5ELpI6R1OUbfaOdZCzQUr2+FnTVLxeUbBcccUV/OAHP3DyErJZA1VVePPNN3n/g/cFMyaVck7+dndKSaVSd5WUlHLmmWexbft2Zs2azZVXXsGgQYNwaZozJ3G5XEycOJH3P/jAqrBtnrKeA5nki7bs058kO+wAZx6S13aRZck5lYnKCEflLiExffo0Oju7cLndFjUpTSAQ4JJLLuGnd/+UCy+8kHQqzbhxY7n+hhu49Vu3smDhQkpLS1FVxYkOtRe/7du28cmnn7Juw3r27d3H2rVr6erqdCA+SDBp0iTC4TBV1dXMnz+fRCJBa2sr7R3tJJMpiotLKK8op6ujg7379pFIJAgEAlaIjElJSQlz583nzLPO4eabbxa+5XSaP/zhDzQ2HsqbM0uWHjFPV5GXdmVjTO04UHszqxtcx1f/66uoqsLLL79MOBzG4/FgGiZ+f4Df/Oa3nH766VRWVXKgoQHFElS6NI2xY8cxbepUVFXl7bffRlNVUqlkAYqyf4iG9IX4iPPpVnYbOJNHXjxS6NCxWm7s61ZUXERxUZFYFHUdXc8SiYg5pu3rt1HWzoy4z3uWJYlRo0bR2Nhkib6SjsVKkiRBc5RlEvEEiURCsBjSaXZs30F19SBKi8vQ3Br1Q4cyrH44PT297N27h0mTJ3H5FVdw8NAh2lpbrQLVXrw/J3i/D8PiSB5ir8cDEpxzzrl0dnbS09NjXTfj6FkE/+lmZlk7dcNg+PAR/O/3v4/f56ehoYFLL72U22+/nUE1gxzdxIH9+/jxj35Ee3u7s4hHIhEx4zRFcawoYsP3eDwiGTSdctCwx+pkGZiFkDt1OaNAS3ylquKZoo+9MD+M5ovr5OS49rmCQ4ytxo4dS3l5Odu2baOquppEIk4qmbT85+YXWlA6J2DDHCBfo1AfpVhtar/F1Ojo6OC0Jadx9tln09sbZPXqz6zwrKQIbbPEyLlcCHHKdVldynAoTFl5Gbfddhu333475y09j5qaGv75z39y772/4vf338/GjRutkVCapqYmDh06RN3gwTzzzDMEAgH8fj9D64fS0dHBjBnTmT17DmPHjiESiRIMBslkMvR093DGGWeSzWaJRqO4rVh1l9uFS3NZXJVSK6WymFgsLlr2fRJd80cIZh6xz+4ey5amTerTIeibEGtbLyUr8t7Ow3BpGi636Hp7vV5++9vfUV1d7YziVUXlUOMhbrnlZrq6ushYh0rb/mcXAuqkSRM599zzWHr+x9/wEgAAtt9JREFUBSxYsJC//fUpXnn1FQJW+IxpmiiaqJoGDx7MxIkT2L1rF6oqAmwUxVLS2ze+9UzI+boAux1rFt5ImqaJzckQp+5kMmmF4ajCFqapbNu6DZ/PSzajoyoKZ515Jl//+teZN3+eM0+97TvfcWYwtvUwf2aiW///w488yk/v/gm6rhOJRMnqWcrLy4nFYkQiEadyb2psEqEuVjvY43Zz/vkXcOHFF3H/736LqrkYPWoUjz/2GFdedRUXXHABv7nv13zlq1/FMAxefPEFBtfVcfDgAb5xyy2EwyEeefhhYrEYHo+HTCadh/gULTrJNArGKPkxovaJQ1VFgTR0yBCKi4vo6Oigu7tbxE0qCknD4Fu3foulS89zrsW1117Hyo8+4l//+hcHGw5wwdLzeP6FF7jhhht4+623WbVqJW6Xi7gVhpSn1z8C3vc/EEzlWwTz4nj7tkqP+Xv2+XtFRQHHLpVMppz5q92eVRXFSoUzBtwAZKtodblcjBo1in379lvQDL0ADiW6SbpTUNj3nEvTCIaD/Pkvf6amshpZAteQGoaPGM7td/yYYKiXjRs3kU6lCIeCfPW/vsrqNZ+xa+du63SSHfC9S4dBxh4PntbMgxq5VQ8jR4xk165dNLc0W6FLR2CcD8jNPzKkaKB3YWKiWxvIwYMHeOKJv3DZ5Zezes1qvvyVrzB06BBnFKaqYhacTqVxe9yYhkEwGLSsugJOZes33G4PEhKNjU3IMkydOpXt23cUCHiP9EJza5XktM3zxbGyvQDni8WQMBHJpPaC+kW6Z/KtkvYoy+5UuTQXg2pqSKfTbN+2nYMNBy1lfSnBYLAfSLOvbuuLeoZx2PfWqVXOKSJ13SCdTOEP+Fm/YR033/x1fn//A/z0p3ezZcsmXnvtdVwul0OZtdvfiqJYh0CZdCZDTXk5l1xyKd/85jepq6ujq6uLp//0T9av38BHH31kOa1UhyOStnJN9u3by0MP/oF4NMb+6D4URaGxqREwWblqFQDnnPslNm3ahKIozJg5E1VVaWw8xM9+9jNGjhrJueecQygUElz9dAZJFgJBn89LIhF3LKv2mMQUqFLMPJ2TXGCFtgp9keqEnBdLXOgyK7Sd2r+nyAqSIqOoKl6vh0xW58LzljJx4gTHqil+Vnj++X/T1tZOwO8nnY45ib5OvDSg1tbWMmnSRN5Z9jbf//73OOfsszBNk0QikROJWfN+SZG46qqref31N0inU1aVpzpVWyaTdexVtlhFtDnyfK92MSBJZHXdqaYVWXQDbBa/LKfRXBp33HEHU6ZOZc3qNUyfMZ1FixYB4nvJTsa0QSaj56EnxdcSUbSihfTnPz/Orbd+i6qqKiTTxOP15LUQDUfVLQoSUSWl0mlampuZPWs211xzLXfccTsfvP8+Xp+Xl18UrbCPPlxBcVERP7n7bt56603+9a9/0dLSwsSJE1FUhUsvu5Q1q1dbymfZ6hLkAihk1fZl2vGgAihkvwbJUoCqigBfSJJMV2cnmUyWSCRKZ2cX5eXlGIbOWWefww033EBTcxMvv/gSFRUVnLhgAVdedRVXXnUVq1au5B9//zsbN25k9pw53PebX/Ptb93K2nVrcbkMp31kmPpxLxSf10Fg9onrPNLXyF/M8sNcVFXB4/bg8XlRFZVwOEQkkhiQSeD2+52TkWM5tBYeXdcxJRsTJESeyWSisLVqFQGappHVdVKplNAxyAp+vw9ZUaiurmbUyOGs+HA5k6ZPRJJlMpksJSUl3PKN/2bb1m08+eRfaGlppaZ2ENdc82V+fPuPnOfsaJjegdrvx3Pts1kdlyYzceIEtu/Yxo4d2wUURZc43Mja/Jx8gf4QJvHnxUXFDBs2jKef/idLTlvCw488wqhRI4X2RVXp7u5m1aqPkZA4ceEC3nvvPQceFY1mxUnGGtOJdq3H6c6YyDQ1NqGpKng9JBLJY+If5xdYUkHojdjYVEVFkiX8fj9z5sxh+fLlaJqHeCKOZNp6Iemobfbje0zs1rDptMTFfFchkUyyedMWFEVFN3Ta29vx+/0OX55c5ES/jIMviuyYPxcXz4mJkYfrVaw1r6S4hGQiZcXH72HXrt0UlxSjZ3XHvUBeoaWqCgF/ETfccAPXXXcdtXW1hEJBHnzwDzzxlz9z6GCjRcDzOU6tbDZLJpsV9ENTdJC6u7spLS0V/I8NG0AXY0KX5mLlylV4vX72798vQolcGoOHDOWC88/nyiuvAOCxxx5j1+7dRMJhgsGgA6TbtXMn0ViMVDJqWalNR5shWWNFJ/7dOuToFkfGLijzu0X5/BNbpOlo6ZzDoIAJyYrIEPD7A0iyzGWXXmpt6pDJCNZOJBLh/eUrKC0tI5lMFCRgGtZrAFBvuvFrzF8wn0jsFRobGxk+fDiGYVJUVOTAf8SnL5NKZJgxYwZLlpzGa6+9ZqX4hRzko306kgxpgLhGs99cxGulryVTSdKRCG7NRW1dLTNmzGDOnDksWLCAE088EYB58+Y5cywTE01Tc9UnoCpygfhC13VHTfrd7/4PH330IeXl5eh6llgs7mywfa05xUVCCJbNE8WtW7+O2267lZ07dnDiggU0NTehuYLEojHGTZhAa1sb3/jGLezfvx9JgsGDBzN7zmw++eRTtmze4tg4DN2wNhgLnGRCcVGAYG/QebjtOVg+3c4JuDANB0kLQjjp9Qh08+WXX84dd9xJT08Pjz7yKJ9+8jFtrW34/H7GjRvHddddx5LTT2fBwoVEo0lisTgjhg/nS186l9WrV+N2uy2hjJkTN5l9oinMwy8Mn/dgURhRelSMTC6mGIGKTaXSDBk6hO6ubsJ5Svv8dK9cASBCMZIW/lhVlAL3gZg3amQyGWpqBnHwYIMzM8yFjYiHW9d1oc2QJGIWtzyTyVBaWsqgQbV09/Sw+rPPGD12DJdfcbkjKBo3bhzTp0+nubWFnt5ennrySUpLSzlxwQI+/HCFBerQj0oiw6Qg6e1YfsiWqNXlcqFZrcyKsgoM3fhcYx7zCL9nDhhoJPQfsiSTyqTo6Opg+rTpVFdXMXPGDFKptENI3LBhA4/96VESyQS9Pb2EI4IQZ8d1Z7IZYSVMp5FlAW2SZAlFEsJavz+ArCiEgkE0VSWrH19RO1D3wjANFIQOaczYsSx/f7lY0LH92Yozrvui4cD2S1cUBZeigWVVkySJ1rZW0VaWZSGilnPxt4bNKDCPvXg/rnyDvDGD7T23rWqy5dZyu4Xg8wc/+AGDagfxgx/+nu7uboqLioUq3e6e2AI7S3l/8skn878/+F9i0Sh/++tTPPb44+zbuwdFEbNvGypmd18MSy9l2EJiayyRzmSoq6ujo6MDPStcI7quM3nKFEJhwbkRQsEEwd4gD//xj7S1tXHDDTdw4YUXDvi+9+/fT3NzCxs2rmfXzl0EAgF6enro6Oigq7uLVDJJb28v3d3dZLO6EBvaI1YAxURBIZFKWNo2DVXTUCxAkb03CfG5KjpShoHP56OiotKKTy7lqquuZvac2ZiGidutOXZBVVE5Y8kSIpEQe/fvswoA8XU9Xi+ZdFoULZWVFaRSaZZ+aSm1dbUkE0k0TWXPnj0MHTpUIBQlwc7RFfFhf/3mm9m5YydRS4EbiYStLkBWbFCOQDAvvtW6sWw/P9bCWVJSwqLZC5k1azaLFy9m2rRpDBo0qJAkZ52MRSUsOhIGhuPLLsCimlgtIBd79+7lq1/9KuvWCSSwra5Pp9LOLLpvtd7T2ysSrzLiVC5awiY7dmxHVRQaGxtpbGx0wB6frPrEEca4XC4ymQxTp06lpKSU3bt2OQle+V5TI49X3dPd028zdBSa9hjDCX0QACPFckRISMQTcerr6/nWt76FpqncfvtPeX/5cjLZLOFIhFgiQVNTE5s2bWTevPnMnHkCF1x4ITU11VYL7Bz+9NifaDjQYBUqOpDH1jbMw57/Dtse/tx9UPOIIT52h6empka0QV0uOjo6ONhw0Pk7dgvMME3H/mfP5DKZDNdccy2vv/E6e3bvttp4SYoCAVKZtOWdFSeSM04/g1dff4VQKJSb7dkBKamUAwrKh3lkMxmCIYnPPvuUgN+PrMi8995y5s6bT/2woU53at/efezds4fi4mK6ujrp7e3l1FNPdWKrVUUik80c9iRWEMExUPElFWYp2cAryImKhg8fzrRp09m0aZNgHEhivmhIRqGA7Bg7PUc++Rf2EUzTZPTo0YTDYSHWU2S6urspL6sQ1DZJpaW5mXQ6afmvhVjVZSm6s9msaPl6XGiaRjgczsW4GoaACZk6He3tVFZVkUqlRFv8WLDVfTpSToytYom4VJVUMkGHddpOxoVQ2aVpIjwK/bi/z7HZLnOfoxAI51q5O3fssNC3AiWryKoTMGMe/xSt378xjzHzI98KqKkaXov77/f7WXLaEhYuWsj2bVt5d9ky/H4//oDf6TInk2LfsS2OhqETDosY4hUrVnDPPfeIjAhZJZlOo2d1p1C2dVPOs2idtGVJwuf343a5eOP116mvr6e0tIwd27eCCdu3biWdSVuR7zLbt29DVXeTyWRYuWoV//jH33nkkUeYPXsOiXgSRRWUUEWWGTlyJCNHjmTRooX9rkUimSSdShMKBTl0qJF9+/bReOggPT3dOcy8JNHe0cGBhgN0dnbR091NLBolHAlbFNI0um7g9XoJBAJOVHllZSVnnXUWNYMGocoq1117HbqF6be7Vdlslnvvu5e1a9fS0dlJJp1x7hkbJDRu/HhS6TRqKp0lEgozfMRwMuk0Xq/HykOP5wQwhgkyuCQNwzCZOGEiD/3xjzz66KOsWrUKl8tFNBq1FOVp0mmRCpVOpUDCUlBbuFnd2oBNk0WLFvPLX/yCufPmFsBsDF2cdh0hhCyBKTsPQl/boR2TaJrC9+jxuvl41SquvuYaWtta8fsDRCJRVE212N1yHqbYOmVbCiqfz8e0GdPZt3efExaRzmSYPXsO7733Hl/96o20tbfx7LNPE4/HnJO7rUoGaGtvZ9XHH+dx8HPpUoqqoGf1o56Y5fxuiZnTNmSs2F7RJu2ioryc3/z6NwwaNIgnn3yCd995h6yuE7Jmp5qqoLncxBIJlr//Ph9//DHPP/9vTjr5JE6cfyKnnHoqv/71b7juuutQNQ3TNIQ+wrGKmMccderMTb/AIai9UBYXFyPLsuXHlZ3Kv+9qmc1mBSlNkshmspZtK+fVPniwAb/PJ+x8Lg+pVJqodYKXLdTs1KlTWb36M1pbWkUWeTI5INnN0HVUlyuHyVUUVE2xhDk+0ukUwVCQrJ51/MSyLLF+w3reWbYMVdPo7u5BkiT++c9/kkwm8Pn9BC36Zt9NwjzWRdkcOLvcHs0J/GoVRcVFzmnR4/GQsfQMdjudPpwP08o7HzBbvkAUltedyPtzu5tSW1tHff0w3nzjDdENaW6lYu9+quZVYhg5v7TL5cHr81FUXCw+I1PC7fFgGgZpPUsymcDr9QpYmPUcFxUXkUxaHa5RI0kkEgSDQUpKS4hFYyJ10orwzif0Opx9RcsD3diaS9EZ8gdESl1ZeQ0//MEP2LBhPT3dPdTX19PS2urArExTRtU0ZMmKgbWU7PZM+PPN4SXncCBJkNVzoKp58+by2WefOeTDbCa3rn2hnYg8kZ9Nr8xnpeSDagT4xsTj9qAoKgsWLCSZTPJ/d/2EQ42NBIoChIMhQuEw9cPqmTRpEps3baLI6sDaUfLpdJqJkyYybvw4NmzYSCyeEJ23vHhk+5rqhoFpdfLsolzPZtEt4d2hQ4cK3ksqD3suCqrc8+3z+Vm/fgMnnXQy99xzD7fddlvB4SzXpTNzFECrtet2ufG4PZSUFFNfX8/ChQuOeF2TySQ9Pb10d3VysLGRTDpNS2sLzc3NyJLECSfMorunm907dzF6zBjOPedcBg8ZjJ410LMGpmRiGBKGIcKZVq5ayeOPP44sC9S9SAMUz3QiEUdVVWKxGAcPHkR94cUXuO222/D5fJiG6VjPpk2blnuIZclpE4o5ts6YMWP4yle+IsQ8DQ00NQssZHtHB8lkEp/PB0AsGmX0mNEkrPZKfX09o0eN5rLLL+Pqq6+2WjRZstlUTmUryyiS0q/NJMsykUiEvXv3MmXyZBQr3Q9njqLj8bp59dVXuffeX9Hb20NxUTGSJDF4yGAy6bSwzFkkQr/fTzqdcmAbinVjr/70MwKBADU1NXR0dGCaJlu3bWPY8GEsf385nZ0dZDJZNFVFVcSNnslkqaysZM6cubz33ruW0E+0O005J3LTD2O16h8w5JyXnPZWfmCPjUK+5557mDN3Dp999hn/+Mc/UTWNUDhiKd91TMMkncmiphTcLheYJvv272fDxo385te/5cSFC/jObbdxw4038MD9D5DJZpwF0EZU9j1xHnbP6cOj5zh1AX03PY/Hw9ixY2lqakLTNKLRKPF43PH0Fthu8jpGLtXlbLher5eq6irCoRCZTBafz09xSTGGaZBIJpzi0c5CAOjoaLdU6KJrYHesJImCWZptB0qlUhbcShTLyWQSn9eLYRrU1dVSXVXlOCBcmovOzk6rQEuRTCWdkY7oXkQs/Ypx7CfEAaJ2C7j1ponP6yVQFCAej1NSUsKUKVMxrTAj1aUS74kjKwqlfj/hcHhAKJSD0jWPcJo1By5UVFVFc2lk41lGjRrF3r178Xq9zJ41G6/Pw2drPqN6UDXD6usBGDZ8OIOHDqWpsYlkKmUtZILNkLKKQF3X6bY4IbZ4MplIisS6eJxEIkE6I8iitpUsncnkNnxMx1qVyWQwdZOsmXXeqyTnqGuY4tmtHTSIyZMmMWHiRM4990s0NzXR09vDnj178ohtitONEJulYUF4JDo6Oigvr6C7u+uYGmVmnnjShs2LDdfuFmaJJ+LWZqc7s36bLVFWXoYsiVl4vw5Hv1HNkTsTpmkWzKvt3/N6vc6zk58t4vWIZ+CsM89kwcIFPP/883z66acMG1ZPV3c3Pr+PK6+6ihtvvJHRo0fzx4ce4v7778dndQc2b91CR0cHHo8QeHq9XpLJFGnLHWWYpjgQSHIB8tjRmkhic7XtpAXFbL+1Ki/oTjJQVJMRI0dg6CbPP/8827dv5+c//7mwEqczAilsihO15WzOjXf76I7yI87tZEcz7wnVNBd1dbXU1dUyZerUY3rudd3WTAjRsgnOyP6JPz9BJCLw2FlrFJ4bc8pOEWAYBsqOHdvuenvZ28RjSWbPmW1ZW0xLDCTR1dVJsDdIoKgoL5BCsuxupYwaNRKPz4PfH2DsuAmMGzueKVMmU1JSQlNTExMnTeT/Y+694+yo6z3u98yc3vZs32xPNr1XSOgJXQiRotJVQAWvoqJe0XtVvIL9Wq7XLoqCSpNepSWEhEB679t739PbzDx//GbmzNnshqD3eV7Pvl6+EJLdPefMr3y/n++nzJk9h3Q6xc9+9j98/evf4NbbbmXhwoXWrN5pVGjm3KqgdzA6ShPm2LhxI+l0hmlN06w3ZM5MHA4Hv/3tb7nzzjuJRiLIxjzF6/ESj8cZHBwUXu0VlbhcLiJGeph52JpdYqioCE3VGBoeJp1OEQgEmTN3Lt1dnTQ3NzNt2jSrCzWr+qrKKsLFxRQVhdB13ejs5EkdwCaTHdnxR9lwmbJrSDPpNFMbG7n5ox+lrq6OuXPncvjwIb7whc/T29NDJBIhnoijGsE+2VxW+AzkVDLZrJDd5HKARDqT5sCB/fz9iScYHhrm9NMFzyJqZB/8Kwmo401j3o8EyyTZNTU1UVpWQvPxZiKRiEXaO8FrfZyMRuSm5yxUKZVMWrP/W2+9haKiMBvffBO3x03KIIjZ9bXpTIZoJCoMmswDRToRAcgZPADTlMPj8YiMA1kmGBSw3U03fZQlSxajaRrdPd088sijvPba6+zZs1sk1hlrz2Q+ZzIZy8f+lB3/xqWTjffwN6HBmTNnUFZWxkB/PxdfcglnnHEGiXicDRvexOVyccEFF1hmRXnHy39V/Jf/zKoqq5AkicoplTQ3NxMMhiivqOD5555n+/btNDU1Ma1xqvgsfT7cLjdHDh+hu7tLsLsNhNK0nzUNT6oqKw1Zssg/x7gYMhmBgKmqRmQsYsRLaxNebGXlZRbClJf8iWRQl1tIrSRJYvGiRfzghz+itLSUc845h86uTl544UXD1TRb4OFhKQMkgaiaI0/diCz+V5ExE5UZHRm1Xvd4WN/pcFpZKv9vfJlSblMFI+bPgpTrcrmpr6/jJz/9Kel0in//yr+TSaVxOJxceuml/PjHP+EjH/kIxcVhspkMp59+Oj29vezcuQO/T4QarV17BT6flz/+4Q+MRSKomk4uK8400zzITP6zFwAF79fYCwU23wUufIUbS5aF900qLYLKQOLll1/i2WefZenSpTQ2NjI6MiIKE9v3ZXNZ9u3dx+DAIOlMmlQqia4JwrnTmb/jZEW2udgaLoKGrXJOzVnniqapaKrdnyWPCEsm5G8gV6bxT2dXFz/58U9wOB3E46JhSmfSTJ8+g4HBfnRdo6SkjNlz5gqOUy6nsn/ffr75za+zZOli1qxZQyIeJxgMGl2YV0j+FNl2EEpGvKGLGdNnUldfbzAUPSiKTFd3N7t37+Gb3/wms2fPJpfL0dbWjtvtprikBFUFRTEgcUWx2JXZbI7S0lLcLpdhLmTzDJAVNE3n3HPPtRzszIpbeFHL3HPPPfz0pz8hGAyRMZKXcrmccVELo5lsNktHR/uElazb4zWY3yI0QVUFczuTSbNl80bhh+B00Nffx0D/AJWVlSxatJhEKsHoyCj79u5l6tRGVE0tmFufqqRGt7O69MJgGjNNStM12tvbGRoapry8jHgsxic+8QmOHT0mLrSUccEb35/JZIQJkjGfE52uahFCAr4AkiSxe/dujh49iqzInL5yJR3t7Rw9etRm9jSZsAvbGGa8hv/k3YZJbDEP3HBxMamk6Mqz6YxIiDwwMRegQPpXFCIWixuGOnmplrnBfD4xhzzrrLNZsGABIyOjXPOhD/HkE0+wYOFCQsEg27dvB3RrrZuOWYrROeZZ1JLFyzBNdRwOhxXAojgUI0VTJGnWGsEkbreb40eP8dtf/8YYb+VT2lxuNxXlFXR2diCBkBtNUnGdMP+3SbHsIzFFzruNmaS/ttZWbr3tE7S3tzNr5iwxUywvY83qNdTV1/Lw3x4mEokQCARJJhPWCEgUyGabo08qU7QkdRNwBlRVZXh4GJ/fR093D4lEnEw6zcGDB6goL2f/gf3s2rmTj3z4w6RSKUqLi1m79nK2b9vKrl078Hg8qKpqkVVzOZVsLocsC+RmbCxiabbT6bRlopLJZPH5nUb3mDwhic98tvFYnPLyckqKSxgeHsbj8RiI3gpqamqpKK9g5aqVLFq0GK/XYzhE+vjCF+5i7eVr6e7u5tVXX6WlpQWv18uGDRtob2/H6/OSTqUNiFlYX6cNDsm/xgpkQpe58eOZ/0tToonQOnEG2xQTppmPmiUSGeOKtesoKSnh+9//Pu1t7XzqU59izZrzWbJkMel0mj/96U8cO3aM0pISbv7Yx7j3vvuIRmMcOnQQNZdjaGiQ+vpacqpKKpXOk/xsb9Ku5pnsdUrjYsFPUCCRjy03Yf5UMkVPsofunh6Ki4vp7u7miiuu4Gtf+xp33nmnhYabUnhFUgiGQjz91JP09/WKiPtMlnBxMeUVlfi9fsLhIqY1NRkhdzFAp6Kiwggf8hW4sxYiCbrluSMuf5H2J4SoQn2hOCU2vbWRVDolrI/TGevz2n9gv3FGaQwPD3Hs2FHmzpuHQzM85HO5HNdcfRUvvvgSZ5xxBul0xmDFB4VLnAFnmYeNVWVK4PP6bC9Upaa6mprqamtu7Xa7mTt3DqqqocgSbe0daKpKbV0Nqprlc5//PLd/6lMsW7bMNvPPH3Gqplm2iw5FsKRN6YiiyMTjcb721bt58KGHCIeLBfRnXP4YNqETVYfjIa9EIimIXdkss2bNIpFI0NPTA7qG8PyQ0HI5erp7rJnqVVddTXdPF9+65x5kWeaVV1/JBybx/nXBpquUxWDXdTTjkNdkQXwJBkOW5vWnP/uZgMhdLpH2ZEgxdU3Px0zqOroxExMQlwGsaBoZNWPpmyPRKLqm84+XX8bv9xVukveSNRWgwDbppzE3Ni+ogkvcmDebnbrX4yEyNlaQrmZJhE7yFRmLWBrioqIiXC4Xmq4L85DiYhYuWMTHb72VC88/n3BxmI0bhffBvffeh6qp/O63v8Xr87Fq1Sr+8fLLeR6DEdVpjqbsRaPpcyH+XDZyDRKEQkEUoKuri9vvuN3in7jdbtavX09Laws1NTUGhKij5rLIYEDCeT/+k7nXjf8zaZx/uGWpqiiomorT6cDv91NSUsL2bdu599v3MWfubLLZLKWlZXz2zs/yox/9iIGBQfx+P319fcKOVZJxu11WIVkYO33yNTBRwRKLxaiaUkU0GhFBXIrG/v37SU6bhiwr7N9/gGg0itfrRVEUYrEY02fM4Nxzz+OVV19BMV6TYrDtXS4XmXSakZFRFIco3F0uF+HiYkZHRpBEPrlhLy6PIyMWMuwTiQRtbW2UV1QgAWNjYySSCQYG+q25dk1NNXPnzuXrX/8G06fPIBKJ8OMf/4Tnn3+OZDLJ8PCwNU6MRqNgrJtsNms9M5O5/54d+QkVc6HEwj7nFk6e/4Iax8bbmIjfYc9/GO90J+Jss9Z5aNoBZzJZPvvZO/nMZz9LNBqlobGRN15/g5raGgD+9Kc/8dBDD3L82DErnXXTpk387ne/57vf/Q6PPvYYTz/5JCMjI/j9Aerr6mlv7xBjGUVG0ZQCdc7JGi3JOvsK+QHTpk0Tc3ZZFmZoxrltFo92t1Ah9/Uhywpf+cpXOHjwEN///vcoKSkhlcwgK2L3Tps2ldvvuJ2XXnqJ5ubj5LJiRKOrGm+/vRlVU1m0aDEPPfQgiUSCkdFRHIoDr89LMBiiob6embNmEy4S6FhtbS1N06ZRUlKK2+1i8th1lXg8xi9+8UsGBweNUaXIT8jlsuQyGZsqKkd3Vxfz583HISB9UbVVV9fw17/9lbc2beLcc85lxowZuD1uZEkilxPMSjMSWLKtSE3VLIKeroGet8/H4XAwMjJCLpdj566d/PjHP6a3p4/f/e53YhY0OMi6dVewatWqQu9q43dkjUtMcTksWaEsifmu0+kkkYjxyU9+gpdfeoni4mLi8YQFvYnDRx9nhKFNepDKsky4qIihoSGOHz9ekBJo23mGcYMYPyxbtoTvXXOfBZcW2KnqpyJqm1jyY10Ckqni1XE6XGQyWebNm0coFOTzn/88f/zjA5SUGt7aas6ClHNaLq8tNd3uJApQHN3YtJIOuZw4LAXkK2xVCy0tJ04W0yfLMLf/qTH3sqMZ5eXlLFm6lEQ8zs6dO0gkkpacbvwMreA3TfSh2XgTY0YB4fV6KC8vp7Ori66ubt5+ezObN7/Nrt27+PVvfsXYqGAYP/Hkk2QzGRqnNrJ586YCYqEZuJHL5vJqCCOLXVdtMLSmWpfW4OAg8+fP57K16/j4R2+hvLJcpEumM2zZsgWHQ2SMq4ZmuaqqCl3X6e3tfQ/3w7z2byLVhUil9OD3+3E4HVSUV1BRUUFVZSX1DY1UV1ez6oyVBPxBysrKBA9CEyY2TqeTf/vMZ7j1ttvo7enlwIEDtLa10tzcQjDgp62tjeaWZoaHhonH48b7tj+bk5e5uk1X39bahqI48rGrfp9lR91i/I6GxgYAdu7axZ8feIBwuAhZlshm0mTSabKq+PtIeVhXkWVUw/sja6iAVFW1mhWfz4eiKIyMjFpcDhGfrRlRsqKzGjIOTzOnPZlIWmt21Ah8cjld/P7++/n2t7/Nk08+SW9vL+lM2uBbaEb8M9ZZGQ4XGdkeLkaGh/85/b0+0RxYzZOZ3+Pml2w/TJ90v07+zZIN2VOMhkHTBckvLZm+LALOlmQFNJULLzhfNIh+P9d+5CNC9vqnB9i48S02bFgv8jQkSKcSeNweNr75Jv/xtbv5xa9+za233IKuaaSSomBatHgR6zesx+l0CTRY0gpMuczXeDJk1USMba7FFvmzurqGsbExfH4fmXTGUo0IgrgoOsbGIsycNYPy8nL++Mc/sHfPbn79m1+zePES7CZ0Xq+PK6+8irfffputW7fi9fmorqmmt78XRXZQUV7OqpWreOXVV3AahLxYLEp7Wzs7d+wgm82gazpOl4tAwE9VVRWVlRVMb5pB49SpqGqOkZFRVq06A3/Az9jYKNu2bUNXNbZv347fyDPQ7aFQdntoXXghLFq4EIeuZYWu0uPhgQf+RGNjI1/96t20t7UhKw6KQiFuuvlGZs6YmWehIlnpc5IiF04IZQFhtrQ0s/ntt9nyzhYOHzrCf/7nf/LOO+/y8ksv8+lPf5oVK5aTU3O88cZ61qxeY7EqHQ5HQdvgMIh+JhtXl4Wzn8vtpKuriwf/8iCDA4PU1TUwPDJsHAQmBJyXhgjSUK4gCCNPjtANqFOQikwXsuKSEhKdnXlv7XFEvZHhYb56991UVFbS0tpKLqeyaOEiSkpLeOONN1AUZdKOabIqQBvXSum6DhpoUp6lOq1pGo8+8ij/+7//S3FxMWNjETEXy+UEj0FRjLmRnq+Aja5WkrSCjS26WNWSampG1zSeLCNJJznkxzO/pcJuxPw5fr/fkhbW1tZy6OBB2traCrvbSdoYXZ/8ILSHvJhIlapqDA8P41AUvP4AwWCQX/3yVzQ0NdLZ0cmKFacze/YcZEkYJuWyWcZGx4RPviSTU3MWhwMpDw+aMKeOIZGUddxGEFXKkCbOmD6DefPmMjg0SGVVBbIsc+jQfvbs2UMmk2EsMkYmm0WWZUZHR6158ElNkQxTBt0Gt0u2Q0yWFaqnVLNy1UoaGxupqqpiWlMTc2bNoqGxccLLQ5ZkIzLUyVTj78yZPZvVq88DYNu2rRw8eIi+vj7a2tvYtHETe/fttdZ1Phr1RMLn+Nev2+BaEVol/BYcitOwVY4zMDjI9h07qG+oN8Z+Ei63m87OTlxOJ41Tp9Lc3GLldEhisReE7mgGzC4hWS5ziqJQXVNDW1sbiiwZZiySlfduSvcKw80wIl1lS2LodnuQFYUXXniBvXv38sYbbzAwMIA/EEAbE+RpTc/796uqyujomFCxFIXwejwkDLXFRKOs8Re+fpJmYTJe0WQdsa6f+FMm/3sTczjy55luWWinM2lcLrfVYHk8XsYiEa64/HLOW73aINX28/bmTXzl7rsZGhrE5fLgcChi7GsUSzklR7i4mL179vDAHx/gox/7KFdeeSV79u4FoLi4xPCJcIgQIcObXzWepa69t+TR/LvmWmlpabb+zKGYeQNRQqEQTocDt1cU1LqqkTT8CpqPt+J0OSgrK+PY8eOsXXsFjz76KJIk4fP5WbhwgUUcXrVqFYGAn3379lNTXUM0EmPW7FlkMhk++clPcuz4Mbq7e8jlRGKkQN0k2z8FJ667u4fOri62bdtuGZQlEgnefvttjh8/Tm9vL16vF3SdUCjE6Oio9WzVXM7q/O0kTkmWeeWVf+BwuTykUhlCRW5am5s5/fTT+MUvf0l/bx+jo6Ps2LmDL931JSqrKrju2utZc/4ashkVp8thsRFjsSj9fX2MRsZ44u9PoKkqL730EseOH0dVc9zzzXs47bTTePTRR3C73dx4481kMjlcLgdnn322yC9GwmHAveYDtYdtmBCUajiFbd26lbvuuovuri5xUScS5LLGJjT9jlWVXDZHeUW5dbHLEgYcLj4c63CyJf4JY6McXZ2dhRC0JT3ULRbyK6++SkVFhdUx9vT2MDI6ks8hmGj2bU9eex+QXTYnOpu3336bBx54AJ/Ph5pTUc10Rl0EC6HmjTGw+Q4wDsLTNXvwT2GHf+LBoJ/UK11U4aJatnfuiiwzpaaGObNno2ka27ZtIxqNsmPHjlOzGn0fXZK5dkweQCqZxOPxUFJaQiIe5/G/P8bsOXOYMqWKkZFh2traUDXV8MIXaZGAiCbNZgqKt/GOZ3aiptfnJZFIEAgEqK9vYNv2bRw6cphv3fNfzJwxA4/Xw4YN6xkdHcXj9aJr4kB1uZwnkLcmPYj1ieb+eQlsLpejuaWZ7p5ucRgYfIbysjLKKysIBgKsWrmKmto6Fi9ezPz58yzXvbGxMZ5+5hmSiQSbNm2itbUVn8/LoUMH6e7uFQetEa2raSJXwc5EmMhlbvLQJskwjJENx9GEIEvpOqMjI7z22mtcddWVJBIJwqFi/H4fkYiTYKiIocEhPG434VCIgYEBMtmsLa0yj/TpmiAHZtJpwsXFRKNRuro6ScTjOBwOAoGApSgpKGJsmnvLuthyYxOGZal0Ck3TeOON1xkeGbbei8frJRaLWmjC+GTFyFiEyFjEci4NBkNk0mkR9mUWUzYW+ckkoJPtm/fiHZ3g43GKGQkmsXbq1EaOHztuncWyItQT2WwWl8slEgoTCcpKSvnlL3/FkSNHuP/+3/P6a68xMjLKWGQMl8uNpqrE00J9pRnha7Ikk3QoxBIJvvfd+xgcHOBLX/4y551zDiDszx1mJLum2sZR+oSKIP09PitpXOJpLBazvk/TNJwuFyCRNGKEzedsosiaquFyucnlcnzxri+iaioN9fV8+tP/xnlGAZ1OZ1iwYCH19fVomk7j1Kn4/cJ5sLSsjBXLV/DEE0+gqqr1O+wIZC4nG5kIimU0ZebHeD0e2traqKqqIhKJGGiIIAwKlNKQmlvZDbpF6DXlkbt278bhCwRR9SgDA0Pc+bnPsfr8Nbz7zrukUimmNU2jtKyMsvJS/vbXv9HZ3kkwFGLevHls3bqDuvoG6upqiUaiPPf8i4xFRikKh0km4qQzaRoaGygtKWXdBz/Ijh3baW/vQNd1du3eSSQyRjaXZdnSpaLKRieWEN7KmUxOxNsCmqpbaemqwXR8+umn+fKXvkQ6k8HpdNDd1Y1mkNpENyAIIyYzs7u7W0DoigNJkdDUHFObptHf1y9QASCVSiPJWGFDJSUltLe3G3bG2gnHmKnr9fv9zDXCg5xOJ/39/RO7a00gPzlVUoB5WRSFwzgdLt555x1kRWhkc7Ixo3Y40Gw6fNMcY7xMr6AAmYA1fKoEIHvwhbkRJdvF7/P5yOWEXKaysoL9+/fT3d1dkEev/4ve5CYooRg+4i5Dk5/JZMAIgUql06KDdLkoKipi2bJlXHzRRSTTaX75i1+ia8IS2OvzkkqmjFS5WAHqYUeNLImYySx2OhkbHUNWZLxeD+3trSgOB01TmygpLiOTyeLxeixplkj5EpaemjbxTP3E7v9kJ5pZBGjoukQ6lbYUEG63RntHB0eOHsHn87P+jfVMmzaN++77Dn6fj4bGBgYGBmhva2fTxo389a9/teJsTVtWl9MpxnAGgSiv7//nfO91DETLGMW53W7SBr8gGAyyZcsWurt7qKgoZ+78ucycMZPm5maD2yKY0emsMHrKR1hjqZOwITU6OkNDQzgcDkqKiwW/obcPn89LJpPF6/WSSMSFeoDxnvlYoz7zZ5vokqap7N93gHg8YZFuxSjCzAiQJ9Thm3tFkiRiBkdAhIjlSKVS7zs6+P/tL9MIye12U1NdzQ9/+CNef+N1Hn74YUaGR2xwuiSI09kcTdObuGLtOr5977088sjDxGJRikJhHE6HQbBOFzjdaZqGpGnCkCch9qLT4eCBP97PggXzufiSS9F1neqaGlxul3G+63m3VO2fs1o214ipvDFlouga2WyGVMoWF25cviZ/yvzduVwOj8fDkaNHjIRNmb/+7W8cO36MVStXMW/+PDKZDEVF4Tyqo2s0NTWRiMcJhUIcbz4ugtyM5k23JTeabrYSoGaFkY8smbLzLC4j0S+dSeNyug0eQAKn04mq6jbJsjZxqqskoaTSqXvmzp3DvPnz2L9/P3W1dZy3ejWHDx3i9fVvsH79ero6u6iprmZgsJ/HHn2MbVvfRVYUnnn6KVauWkVXdxcvvPgCR48e4dKLL6a8ooJXX3lVGHIk4mx86y1+8uMfc/ToUZxOF089+RSPPPoIDz34IA8//DCv/OMVNFWlt6+XSCTCyMgwU6qniLPNFpTgdDr54Q9/yH/8x39YDzCVShkmEKphsKNbTGE7SQQdpk6dKtiXsTjz5y8gnU4xOhYRASVWfCyouZxwNzRkRuMvcbFYNAs6mjtnNsUlJQz0D5BOpyac5b4fq1WpQOKW76jLSsvo6+/H6/Ua+QfZArzddI8THZD+HlU9Ro5D3mHv1ORcovLPfw5iI5g6+JqaWs4/fw1lZaV0d3WTSqXo7u4mGo0WyHD0f4EAPX5kYBYjqpH6Z2Z925GIXC5HKBjiy1/+d266+SYqq6r45S9+QVlZqSHdU6xLT7Dezc/E1IvL1s90GtCyuWbM359KpfG4xez5A5dcxrp1VxAI+hkcHOKll17g0KHDZIwgqEw2NyEb/FQzFSaMaJbyZjGqqpHLZYUnPILk6/Z4+NIXv8gLLzxPLpdlxYoVtLa28o1vfIMzzzyL7u4uWlpbAYmsIaMzD6V/xsBmQi+BCWBZMW4RkPzI8DCnrVjBnLlzrKJ+374DJJMJMtkMmqZbJlBmEW6m/pVXVFgXqTQuIXJ0dIyK8grOOvss9uzZSyAQIJVI2vTjhX4H9kvCjvwoBhQ+MDjA0OCQRbRVcyoOp8OKHbd3o9IE798snsXFmZe3er1eiouLhaugpv7/ohBQFIVwcTELFy5k185dHDt6TEhYjQLAzKfPZrPU1tbQ0trMs888YzQubjIGSmB2uGYBYP4vv/AFhwJdx+v18Pbbb5PLqaxYsYJ4PM6fHniAaCyW98q3jWwmOlAmOnKlcVLe81afh6ZpFgpoH5uatsbjVSPSOHM2VdWQgM4uIVedPXs2Tz75JNObmphSXU0uK/g+MjAyPELWUDfs3buXvXv34vf5GR0dzdsZa6otklygDUi6FeMtlAeCvxIZM6Xo4nUIq18PiixGLPokts1m8a4oinLP6Ogoak6wFd99912OHD7MW29t4rHHHmX//v10dnYyNDxMRWUFq1evwel0ceWVVzI4PMhPf/oTtr6zldHRUZ577jl6e/uYOXMWmWyWhYsWsW3rVg4dPGhldmuasDd0OhQaGhqorKokk05z+ukryao5plSJcCKL0WxEbDocDn7+85/zzDPPiFhXI9c9l1NJJpNWh5DLqaRSiRPmW0IHnmR4eARZlmltbWVsLJL/gO2za4OA6HQ6kZCQHYq1UCurKsllcpYjXSaTxhcIMDYWoauzw/JIeN9RoJNEuUpG11hdPYXOzi5yBhSlGlHMkiShG9aXBSqHcdr1iX6hYkBqSIWs3kmrReP56Zq4/DMZoRQJBgK43W4aGhoIhoK0trWxe9cuS4VhZ97+30SSFjbFbpfLglLt9NR8YSN4HtXVU/jd737H8PAwf7j/fssIR9M0RkdGUbM5ckZRVbDhJQoLAKPwkSQJp8OZP7w9YmYYDAa47bZPMnvObGRFZu/e3WzatJn9Bw6gKA7qGxoZHR2ZUL6k2Mxn9PF2ehMUQIXWEYUCQc0Id5JkcDmdrD7vPN7atIktW7YwY8YMzr/gArZv386f/vwnNmx8k9mzZzM0PEwsHrU4DyfKpd5HzK1UOCbiBH8CrLx1M/1t6tRGwkVhzjn3HCHvGx1jw8YNRKJRy8JbMkaP2Vy24OebNsHjkQmHw4HX62VoaEBo4lWdRDyOx+sVow0bO3yyUZeiKNbIUNN16uvrGR0bs5JG9XFOTIXR6PlO2oR4J0MDhZWxO+9sGAwWXpQTPfd/oYie7PulgvCoHENDQ2zZ8jYHDh4UcLnxnk2rdlVTWbJ4MdFIlCNHjhIIBKzALXvHb15SWgFBLW9YJaTfoojK5nI89fTT6KrGpZd+gN/97nfCmtvm/VIwkpvk4pcmQ6J0GBwYRJYkYvG4bY2eDE+QrECmgpwRXcftcdPV1cXu3bsJhYL8z89+hiIrLF+x3CClikbV4XBQUlLKM888y4EDBxgdGzPsiwsje811ks1mqa+r58Mf+bBIEs1kRFJiOh9mZ18j6VTaMnN7z+JO1/V7stksIyOjaAYMV1NbR21dLYcOHbb+YjKZpL9/gJWnn87iJcsoLi5m9py5tLa00tTUxA033cjy5cu5fO1aDhzYj9vt4u+PP8boyBg+n9/wNlYtoo7T4UTXoa2tjdKyMkJGjOsVV6w1NodwHzQlfD//+f/w5z//mbKyMrq7u0XlZUivamvryGQyxKJRQQYxZoCScYGKpDY/iUTSVuHJk+vapXxUraqqVFUJ7/l58+YKYs/YiAERioU4Y+ZMxkZHBenMoRRUiBORaQKBwEm1q+MPEr8/aJmJmH79mUwODDhKsw5qU66onxAfr8j2ZEbx3woOv3FkukKpD7icLpAknA4Hl176AYLBAF6fl5UrV+Lz+enp7WVwcJCe7h6DhFIIXev/p3akeS2+LElMqa62/ODtz1ExDimX00V5eTk33XQTkWiU48eP09LczNJly3jn3Xfo6uwil8taeuaJCFJW5W+xr/NRxg6nE7fbjdfQ8s6ZPZvbP32HkQ2R46V/vEx3Txf79+4jXFJCd3cXaQMKtXeJZpqY1+vF5XSRU3On7MR4snmBpENROExnZyctLc24XW7q6upYt24dmzZt4vnnnmd0dISjR4/icDos5vv/RZ69efG5XC58Pm8BGcu6dIGpjVNxu90UhYqoqa1l0aLFBIMBSktKePbZZ2lpbcHlcqJmTYMr4XVhkf/sxaVk8/EHPB43LqeDZDJNNBIlp6r4/D5j3BMv2JumKcv4S8RkvZtrQZC2lHyKpJ6XSouY9BMJwII7Yb62yaFp0dBkjbwJRWQb2D6zf2lsNkFQk33fy7bCc7yZlBm/bPFtyLunmgY3AwP9lgGb2VyZSI5ZTJtnsB11tY8mzcyWVDqNLMs8//zzFBeFkWSZg4cO4vMJBPRU3TJP5qOQyWSIxWJcesmlRKNRaz0Ujm9lW2JhfgQoWc1e/v04nU7i8Tjtbe2k0mk2b97MO++8w4yZM6itrcHj8VhF3ssvv8yG9etxuz1WvogYsxWaGimKQiKZIJlIMnfuXObOncv+/fsthVfhuFc/NfMwc13nHb9E9TMw0E97Wxvbtm8lk0kb3Yj4s3A4TElpGegaIyPDbNz4JnW1dURjUTZu2EBbayvdPT1MnTqNY0eP0dnZhQ6UV5RRVVmFy+22FnEqnSESETD78NAQN910M1/4wueNSF4FTRVEw/b2dtZ98IPc953vWLCJpW83Dk2hK84Ym1SzXKHM1a1qKmNjYwQCAcu5arLELt02C8xmsxSFw0xvmoGiKMyaNVtYLHo9BXat72zZwsjISKFazfCflyYoAEyZ4nvN3tAxUhlV+vsHCk5fSRJe9KaRjmawYHUmYPXKkgg4slWw9s7c9NHWxrlpCchTbHJTerVs+XJq6mpomj6NCy44nz179rB169Z892X9TMvE0fKBf789ykQLN49uiF3s9njo6+u1Dl/JyCPXEe5gVZVVZDNZbr7pZj7zmc/wh/v/wM9+9lM8Hg/PPP00aYuBTz4W2vhMzOS/fN63ZI1lZAMalGRZMIZdLsrKynA6HcycNZtQKIQkQ3NLMz/84Q/o6uzG7w/Q0tyMruqAhqKIz9eM/FQ1jSuuuILPf+7zokh2OgusoSf7pKTxK1gqlG9iWND29/cjyTLpbIaBwUFBTotESGXSFndiaHDoPcdV+vuEj7OZDJdd9gFuveUWqyM31TcSOook0dfbS2VlFZIs0dXZRWtrq1XszZs3jylVU4QbnxG5a49adZn6aOlEJYXD4SCVTBIIBiktLbMu4lgsJhzSZkyntLSU0tJSPF6vFUs7nhBravlFkSZS12LRWJ60bHyDGTbmcrlOGKvlOQbSSZMcRVysQMzisbhQ+Rje9zU1tUyprsbj8Zywp6Rxaavv99mZUbETJ3UWmpJJOtZ8OuDzcdrpp9PV2UXaQAVNF1JzVFBQEBhogM/rM5CVvHNiNivyTrLZHOlUhlw2i9/v59777hWJsxaPQLdGb7pNofV+MscEG158Zi0tLRY643S6rIh6i/RneNFQ4GNi8jo06/ULa2KBWOdyOZYvX85NN9/Mxz92C1dedRVHjx7F4/GQy+U4//zzLRmfsGkf1+AYR46iiEJlaGiY73znO4yOjVo6f22cv42uv3fY0zjEUbpHMubM5sI///wL2L9vnyC2uZykU2luu+025s2bZ1WCv/jFLzhy9Cj79+/jyOHDRCIRNmx4g8OHjzC9aTpur5vtW7dRU1tLOBwmq+YIF4UYGxuzCFHJVJKA309DfQPnn38+U6qnWB+uy+XkeHMzN1x3PXv27Mbn8wlPcGNmls3ljPAir5A+jIwIfTLiUDE3paZbwilrPmgSfMQHPdkGFDCsz+fj6NGjFJeUcOjQIeKJONl0FjTBqtR0nYsvuYR5c+eyb98+g2WpT/qha5p2YoiNzdJWHwfz6Trk1FzBQxYXlWJJuSZiuI6H9EVHIVnuivZQJcbBpbIsWfMwTdeRFYXKykq+/4MfsGzFCrZufZd9+w6wZcsWBgcGC4KcJpMPndClvceXIMnlbXgVI1oUhD7W9KUPFYVwOV1WRoK5YU1bX9Cpqqzivu9+h09/+tO89vrrtLa28dprr+E2SDQmhGzBilohAWg8mVMyLn6Hw4HD6cRlIQBedE3jQ1d/mJkzZ+FwOnjuuWdF6Ibi4MiRI6L694iEO1XVTL9L68K44447+PgtH+fvf/87oyNiXoiVsiZNCHm+V4qc/fVrmobTIWRMN9xwAy+++CJbt24VhERNty4e6V8gjpkNg6mq0XSdu79yNxdedBGPPPKIuCjNUQuSZVqVzgjnsksuvZRoNMaSJYsZHByis62DZcuW0d8/wODQoHXRmgWrkBTmLB24WTyba13VdKqra3A4HYyNisNWVVWymSyBQIA7P/c5vF4vBw8cmFS2K5n8INW80IQpl/k6TK24+bvNePTxa34ytnowGLSkkZM9Xk3TiEYjpNNpPB43/oAfVVUJBPyWNHKygkCaoFiUkP4pZM6e7qoDReFiurq6jJGMbO0hu4mYfeRhds1mcZB/UfaLTLPWrrk3xyJj6JpOZGzsxGbln7Art59/g0ODBWvKHOucuNdE0a6Z/gAmUdRUfdicJh0OB/v37ycWiXLDDTfw8//5GY88+gi1tfXMnz+PmTNnct7q1bxroJD+gN9yac0XAqYqXoTN9Q8M8NyzzxW4bP0rLs+Kosj3SDbhqa7rtLa2oGlaIZEOifNWr2bWrJmsX7+e9Rs2EIsIz/gjR4+SzQr2PJrOsebjrFx5hiGzUWltbcXldFJbW8fw0DCZrJA8VJRV8MILL1JaVsrWbVu54IILSCZSeDxujh8/zn9967/YtWcXbpfbciLTNI1sLicelq5RWVnFzJkzOXr0mM1a9kSbR3ORhcNh5i9YQE9PjziodP3EKY/BPQgFg9Q3NAgVga4Ri8Usfb0kSzhkcREEAsI2ua+/z3L6mujwOJXqXLJdPKaWeKKL09Qn22fThRtUP+Gyl2wCcrOvdLlcTKmutrz/xe8TJJzGxgYuuvgS4ok4sWiMnp4efvG//8uRw0cYGhoSlquyNMnrK+wcCmaYJ/G4N/9pJ52Z4Ucm8U43IpF1XScRi5NMpQiFgpbXg+IQdsdOp4NkMsnc+Qt44IE/cPzYcQaHBnn3nXcs0lJe1zz5LjILCauDMzgBTqcTn9dLbU2NQRbVWXX6Kq798I14vW6cLiddnV0cOXSId959h2QqhQQkk4mCIlGWZdweNy6Xm09+8lMsWDCf48ePs3XrVmRFweV0IhtxxmYk9KkUAJadltFRYmPLu5wurrvuOp599ln27t0jPm9VO/ULQZoY3cJK8hMGYoqisGjhIu6999s4XC5efuklhoaGLPc6+6WQzWYZGBhAURRmzpjBvHnzKCoK0Th1Kr/69a+Ix2NGnrtIOFMNFUUqkbSeoV2imW8AYHBwEKdTPHOfz8uK5cu5/vobeP7559mzZw9Hjh4hEU8QDAaN8YJuaLGdeS6SlReiTLDm7XwNvWA8MVFnbl6ipWWlOB1OSsvKcBjuh5MZQpl7XVXFZyAcDg2Wfm0t9XX1QiVhuLiOt91GOtFboIBXI52i8sb4Xk0TIUeKIjM8PGwVqHminD5ub+ftg00ESLfZa8u2/W2ObzRdsxqgyFhEED/tUstxvgf/SmqFNZKAcQRyvVAiqpvFipZfc6ZZElKBp4rP52Pf/n0cOHAAv99HV1c3jz/+OGeffQ6NjY3U1tRw7bXX09XdxY4dO/B6PJb5HUaHL/hTKplMliWLFzMyMoLL6cLhdAiS7yQP7lQ+CwW4pxCOEgd6XV0dQ0NDFoyXSCY4evQo8XgcTdfo6+u1fMLXXbGOeQsWMGPGLFLpNLV1tfzoBz8gmUwwODRkwMNZmpubOW/1eaRSKUqKS3j55ZdZvGQxu3bvQpJkVq1aidvt4q233uLGG28gl82STCYZGh4uuEjMxRcIBOjv7+fw4cNWIIR957jd7jxxzXbQKLLMyMiIBVOPv6h1HUpKSigKhzl06JClXS7cxKJ7cSoyHZ2dVFZV4XZ7rAPM3Gput9uCacy5uMvlEql1LldBZWzvNnX9FKw7x8Ui2w+a8QE5si2YSNeF5l2SJCrKK6ipqaG7q4u6ujpmzZpFRUUF4XAYkDh8+DCdnR0kEkk6OjqsXIbx6YV2voHJvZAkmdWrV7Nu3TohXTQh0QkKJN1eoNien9fntdjDZmdvHiKhUMgqXMrLyy12uKqqLFi4kFQqxe2330EykWB0dJRZc+bQ0d4mCjnDFtkOm42HbAt8KAzPeHtCnKIIbkk4XEQmm6W+vo4vfenfqamuxe11kc5keP3V13j00ceIRKOGQkS2pKWyccEIR8skTqeT//iPrxEOh6moqOCRRx6mvLycWbNns3jxYmpra+np6ZkUQXovLbd9Jq/pOosXL2Hjxjc5fuy4JTuSJtCwTzhLlAq7SnMmWldby+zZcygOh/H6fIyMjHLXXXdx3urz8Ho8vPD8i+zdu8fgUCjWAStL4HK78Hi8HDp8iNmzZnHZZZeRSqcpDofZsmULhw4JMnEymSCbzRQwyPN7SJmQYCdLEslEAkkSHu+RWJTe7h5GxkYFqTiVRlEUoTd3OIR9q67jMcaW6nhoXBrH7pfyZjsnKoAoSJS0f5mErZGREWKx2ElJryYXJ/9axPmbSqWsQCAThfJ6vbhcLqurHV+knVCYTOIGKI0jCNvfmylfGxkZMS6p/DknSfKE5FSzOZuQAGkouKwz25hxW92+pluXMxIFOSKnUrScSKItfG2hkEiOzRpW8+NZ85aFusmlsplGyDaZdz6oSUfLiSJAhNENcccdnyYcLuLhh//GrbfeZoyEs7z55pvIskJLaytut8v4rDULRVNVjdWr13DvvfeSSMaJxeL09fUL5ZcuvW/ip40EyD26DYoyO4V4TMTmYnQ2iUSSgYEBdu/eTWlpGddccw0vv/wyZ599Ltdedy0zZkwnGo3R29vLY48+wlnnnk1lRRXxeJxINAKAz+enf6Cf8849j+99//vEE3Ea6uv5+te/zpzZs1i5ciXPPvscN954A0NDQ3R2dYr4XsOKWDVYkuICELN/zer4NYtgIlmZzmLGZGpLdQM6jETGCjS/dg9++y4wpRnmA7evWROuN6vRkeFhbrnlVjZv3oQs65b3eEGnoINDUSgKF1njiMJAolM4yC2USbaFhdoOmUkOffPL5/NRUVFBJBJFVTXi8ThOl4sbbryRlatWWsFAra1tDAwMWIeSeRlOmLY1fqNJ+cTIyspKxsYiHD9+/KQEJlmWbDM3nYryctxuN7FozIIAhb2qmPOHQkUsXryYkZFhzjzzbOLxBP39/SiKwqqVq1i8ZCnz5i+gra2N+77zHXZs38HLL71Iyjjo7Qe6x+tFlmUjHlowbBXjIskjRJJBBpJwOh0Wh0JVVeKJuJgbKg7OWHkmM2fPwOlysn//AR55+GEOHj5EIh4XqYzmoWU8K5/PS1VVJdOmTuPMM8/i2o98BAmZ8vJyLrr4Yj51++186pOf5JprrmHHjh28++67J5AST1WOZxZOXo8HVddYvHgxe/fupbW1tcCv3m6ucsoHizEamdo4lb/85S/cfscdXLH2Cq655hrOPOscPG4fToeDru4eotEIXnPejoSm5Sz2t8vlNPLKE0yfPp2maU3IkkRvby8HDx1AlgSHQWSC5GyNgTjFFNkh0BhJOpHbQz6AKZlM0T/Qj0NRCIdDJJJCTlxZUcHwyDC1tTXU1tTQ29tXINObTNpYICOcBN1zuVy43e4CArDdx2AiNrvVURrFhcPltOKJtYLGQZzRkTExItB1nXA4zNSpUymvKEfTtAKvAbOIzTt8SpOupxNihM3ZtMNhFFVSgbsqts85/570Sf1RJvpdqmpC4bINldUshNKMw/1Xuv4TXouR8FkgeZ0wtTX/jqyGRBYNQc5Yy4rhxqrpQiJqpiQODQ9z8SUXs2H9Blqam1m4aCGPPPIIxSUlfOfe+0glk2zcuFHER9uQUIF8aHzkwx/mpRdf4pVXXikw1PpnpbkKcM94woCm6eiaxrSmaYwZ8xYziEfTNNra2qirq2fW7Nm8+uo/iEbGeOaZZwiFAvz7l/+dnu4e9u7bRzwRx+F04nF7jFQqHQmZ3/7udyxfvox3tmxBAh5/4u/kcoKY84nbbjOYtAL2RTLn5sIy0u12k0wmSGcyeYjJIHLomi7kJ4YjUiaTMSB5jGJGQOYVlRXWxWZCquM/QnvlbIenpQk2RDgcJplK8oFLLwVJ4ujRYwUXZUlxsaF3Vq2NWjC7mujgkN67jMvDcdKkboMCwlYs0qKmqsQTCaZMqWbNmtWcedZZhIJBjh09yquvvcquXbsYHR0dlzQ2uYlRnkshDimHbe6pA52dnTQ3Hy/w6R6vjRaLuJDDoKqqxey3R/JKskQupzFlSjV+v5+e7i4CgQCjo6MEg0EaGhvo7+tHcSiMDA9x6NABHv/742zZsoVQUYhsRriW6Vp+9o8mErmWrziNo0eOoMhKXlZpjQEUi/Xt8XitDHSXy2VJRgPBAKefdiaNUxtxOh088MCfeOqpJ0kkkxasJ2xTxeG9cuXp/O2vf+Mzn/0Mn/70v3HttdeKIgMFRXFQW1tNcXExiUSSG264nr/+9a8ndKPvN6rZymuXFRYvXsy+ffsYGhq05FmMM8SZaJR1slHJyOgomzdt5tzV5zF//jwaGhoI+IIYQRScdc4ZfPzjt3D11Vdzyy0fJxgM8ObGt4zEQEECczgcjEXGcDqcXHzxxSCBPxBgz569JOIxUimRdibGgVk0g4Rlvm5FUSwn0ff6aExzoyVLlnDppZdSW1fHli3voGZzVFVNQdVUpk2bRn9/v+UxMt4h8lQPYNP4yel04na7LNIs9nA1ChM1y8srwFAaCHfTHKUlpWiGgdV4gqFk84KIRqP09/ejqSqVlZUsXLSQmtoa3C43Y2NjtrhikWzJpBHluojsNX6fybkzDafsTYxJ8JzM5ni8bPUEoqSmFXqY6HkjHrP5E8ow9V+afVvZL+GwNUpxOpx86EMfsrg6p/IlgrYCws7b1oSZ+SvmmzfXTH9/P5s2bcLn9bJ12zZeeeVV7rzzc1x11ZV4PB4+8IEPkEgmeOWVV3Aa7oqCTyIzODBIX28/8+fPo7KqCh2d/v5+nI68csNEZSY6aycdAUy4WHWdocEhw4kPFEV04aFQiJkzZ3K8+TiXXXY5Bw4eoKauji1vv43L7WHt2rUsX7GcZ555hpbmZiJjY0jAlClTWLRwEfv27+O0FSuYNWs2gWCQv/ztrzzx9yfo7u7iqaeeRjaqUmETaUI/mgGDqAacLsx6ZEW2eAtOh4NgKGQEragF0JC9E5cQEZnXXX89iXicYSOcY/xRkbcYPfErGBQMb6fDyWmnncaa889n//79vP3OOyJjWVEEq9t46Mlk8r0zAU6SvV4AsxaQ+6QTdPzmxS1JEqFQEL9he2qOTObOncsFF17AqjNW0dzSwiv/eIU9e/bQadgep1Npy+v7hPma7fc4nS4rXthumCJZhYPdUEMukFbZgZbJ0v7sMLdu+17NIKoNjwwzc8ZMbrntVlxOF7/85S9ZtGgxv//d77jw4ouIx2O89tprFBUV0T8wYCRRmoY9KdtYBHRNJRqJcvTo0RPIiibT2CQVjk80NLkAiiIzffoMbr7xZkpKw+jofOPr36Crs1NkZxjWpcGgOCxkWSaRSBIOF3PWWWdTVFQkDjtFRnFg+XgfPnyYD33ow6xfvx63233K+t7JulG7R0RJSQltba0iStnmI2Efxdgv0ZOHFZnkS4m29nZeeP4FzjzzDCrKK4QLp8soQo0Ez1AoxPr16/nLXx6it7fX4liYozG3y0VtTS2XXXY5kgShkAjpOnToEKl02oj2FZd9Kpm0ZrEOIwK6MMRrssPbCbpOJpuluLgYl8vF4NAg/X39wrc/maCvv585s2ezeNFiotEYY2NjJ8DO45EB6b2Y9jblzvgLyRyfOQzvkYrKCi666CLa2loN7xFhWzuxjDi/s0xJo9lwDAwM0NPdhaI4WLBgPsuWr6ChsZFMNsvIyEjBfjdJnPa17g/4RbysUTibZ4/P58PhUMhmcydwd06VhGciEeNJzPkmRir4uea44f/iy+/3W4iJqgofmeHhoUmLbHM35CXBotHMZ4XY/EKcDmESZNrx6ro4Nx0OMtkMTqeTzs5Otm3bxmUfuEwUI8kUl156KeXlFRw7eqSgEfX7A3zs4x9jxvTpXHvtdRby3NfXh2agBFOmTLFshSXpvUmekxYAduKGLEs4nC7q6+soKyuno6OD3t5eZFniK1+5mw0bNjAwMIDP50WSZK6+6ipcTifzFy5gcHCQZDLFn//8Zy668EJeefll/u0zn6FxaiPFxSUsXbqUDRvW09HeIWZWqpCB2OUjqi2dK5VMitmIyca2veCmpib6+vqsveCQlYJqMu+AJ6opl8vFV+6+m507dpBIJnA6HSet/MxLOJPJcumllzJ79mw6Ojt59ZVXyGYyJBIJMukMXkPeIqJB3y8r9USzF2yyPSzCjlRwIYNgpTqdTlRNw6EoNE6dRjweZ8GCBaz74Ac5/4LzyeayvLXxLV588UVaW1oNyFscNuZGGO9CWPD+ZRlZVnA6FWOeLfIZ3B6PdXGb2e36OEc1+2o0+Q/v1xxIthkSfeqOO3jxhRfIpDMkkgkefPBBUskko6MjpFNpzj3vPA4cEBGzpnqlEOnSrC7f7nnAuILL6XRYaI0JT0qShMvpBFnGaSAsH7r6Q5x37mpcbifvbt3KM888TSgYEDPmdJpAIEBRUZEV1pFKpnhj/Rs88sijaJrO3LnzcChO1JxuOPe5+PWvf8NDDz2I1+slnUpNSOKabG6MLp2wjxWjOBXueKMMD49Y/Iq8g964cvhURgEGnGqqMUZGRuju6ub6668XsGpOskZp69ev57bbbuNnP/sZHZ0dFiHMXmgVhcM4XS7WnL+G0tISZFlm2tRpHDt6lH379llEuPwBmSdfZbO5CU2UTiy2RaOjKDJ9ff0cOXKElmZBgPb5/ZSXlzM8PEx3Vxdd3d2Ei4uIRCIFML7P5yWXy1ps9VOVSWqahuJQjBAazZCDSniMfYQE4aIwRUUherq76e7uttQ5Juxrn2FLJ5XTiiI8mxWGPgcPHuLIkSN4PR7mzJnD3LlzKCsvJ5fNCqMkmzTcvJiTiSQOpzBUymQyYlwnQSaTFsZFhlurVMCNKJSDmpe9lcp3kkyC8RJEfZyN+f/VVyqVyocKyTL9/f0TXP6SLU5aP+kozC7b1Y21ZTWfRoGHJMzEHA4HLreb1tZWduzYweWXX06oSPCazjjjDC699FK2vL2F008/nZtuvJlrP3KtSDjt7GRgoB+nw4nD4SIejxE3CPdxI3p8IpfR91UA2L8CgQDhcJhYLE4qlWJoaAiv183hw0cYGR5m3bp17N23l6HBQXw+H42NU9mwYQOKw8HFF1/Mt751D8uXLyOVTrNj+w4+9OEPU1xcTDqd4otf/CL/+Mc/cBs+z2YqoIRkSZN00yva2Oi6riOZEjWbfEvM7mqJx+ICHUAax4bNO19ks8JIp7Ojg5FRQWIpLSszRhXiPZtdhZ3AZy6C4ZER9u7dS19vr5VEZV4Y6XTqpJ3aZHNCi4k7rtO3d/amPaWZWW2H6k0tqq7rLFm6lDVr1nD+mjXU1tXx7rvv8vDDj7B/7z6isSgup9s6SDRb8JIJ79ln/nZXOvOzsIJ3FMXyZc/lchSXlJBKpUSnYPjeO2QhxfJ6PaLTBSsER7L4AsbBrEww05Ly0K4syaiayjnnnssLzz/Hvn378Hg9/P3xv1NaWkr1lCksXbaUkZEx3tq4kVQqhcMhC28I8lp/j8dLNps5hUtNtyxnhZGSbL0Wj9dHUVGIYCBIRXkFl1x8CWUVImq3r28Av8/LO+++w/DoCIlEkurqGjRNJRIZsw4Gt9tFJBph69at3HjDTRSFilAkBadH/M4pU6bw1JNPChMWw/TjlGRa+rh5raygOBy4XG4jfAVLq61pqrVXZFvUq12bcjI43T4ik2XJcPVT+M//+E/mL5iPy+lEccqk0xlcbhdf+vIXeeGFFy0fdhPps+dL+Hw+EskkxeFiTjvtNMZGIxw5fJRgKMjRI0fp6u62ZqRmBPf7mYfaR05m5KviUKz9EI/HrVwPxeEgkUgwOCAkiI2NDZRVVFBdPUVYuxpa9fGKnfxFLU0Ie7vdbrxeLx63RyhEjFhdSZKQjQSUnp5e5syZY5jUiIhur9dLIBAgnc5YKXBIEuHiMJl0xlbgTJzqKYoBkZFy8MABWlvbCIVCLFu+jFWrzqCkpJhEImEVA6Znvim5FEiOap0T2WxOFAETFPQmoiAuWe0UrdGlf5rk+s/IAO2v2Yz4Hv8SdF2fFKEdPwazryd7MWp26T6fz9rP2VwWj8fD0aNHeeP11znrrLOorKxEzeUoLSvjwx/+COvWrWPhwoUEQ0E62jvw+n3ouk4gGOBrX71bWHZns0bjrBnusRMjq+N4vPkCQDoJRJJIJMgY1WE8HgcJclkVj8dDcTjMwYMHGR0bJZFIsGvXLjQ0vF4Pc2fP5qabbqSmtpaRkVGKQiG8Xi8NjQ0oisJ9993HXx56SOQ7azo5M89e10gkk8iKw4LCTKtIfRxcbkotTA/8ZCIhWPaqYampF0LIJvNfkiSKw8UcOnRIMMl1sek9HrelydYMj3I729jUmsfjcatS9Pq8+Lw+Q9uMzcjhxIXpdDoJhoIGOmCXr9h1VZKtAy2E9xVFweFwWPOhVCpldduNjY1ceeWV3HjjjcydO5eR4WH+9Kc/8eILL9De3g5m3LIxj7TDai6Xi2rDUc/OOh4vqcwTfXRKSkqMGbU4mKZOnYqiKIyOjhrJXeAwUARBRNJJp9MnIA0OhzOv4Z9k0Zokqmw2S1lpGeXlZezfv58HH3yIsvJSamtqqKmpYWBwkA0bNnDs2FGrAs/l8nbP5joxPfklSZq0wTW935mAqOR0OpEVifq6eiRg6rQmrr3uWmpragSEqyh85777aG9vt0KqautqSSTiRKMxYwSBBVtfcMGFfOzjH8XldnLw8AE62tupqamhrKyM7du3sXv3biSb+dTEMi5jfUqFYyyHw2GtG6/Xi8crEJpEPI5sdJ0et0hpM1Ee0+8Ay49i8o7aPt81L7eZM2fyne9+R8igDuxn+7btwt9f0xjsH+CNN97IG88Y69s8PP0+Px63B13XqK2r5cILLhSIiMvFyOgw7e3tDPYPCK6PcbnJsmJ0yJNA/9J7QPPoBZwf832Yha3dNGtoaIh0KkX1lGo8Xg/RWIwzzzoTl9PJsMGINwsaxaYiMWfEXq/XyjBIpVLMnTfXSmVUZCX/u3WdW2+7je9+57u8+uorjI2NUVRUhMvlIhgMCjKzpou9rOsixdIoAOrrG6zRzoRBOLYOP5vJ0NvTw769+2htaaG8ooIzzzqLFcuXi/cXiQj1l2Hwo+qaCFazFZomt8EMsJEN5Ew1nq+aUyft6CdrkKRxrqT/X3xNtHYUi/x8aoRYs2nI5rIsXboUVVOJx+I0NDTgcruIRqMWAiIbDYXb42ZwaIgr1q5j6tSp1r4T40WFdCaFy+3h+eeeY2hwiDPPPJMXXnqJY8eOChthw3uhpKTE8IQQBUI6lf5nRwDi7axYsQKAoaEhqwoUbGyRVRwKBVm4cBFVVVM4ePAguq7T093DdR+5lhtvvtlw19Lx+3243W4WLFiAoih88Yt38dxzzxtdQNpg6GfFbF+SWblqFf39fQaLP4P9/FEU2Vp8ZoCG3a3L5A2k02lDDqdbOlPzQMzlcjidTiuLXdU0yz9dURSSyYR18Gm6bkVRqrZZmcfjoaysjFw2i6I4DEmaZJAKxx2cNujPnEEXLG4pzzQ3oX4TTLIsZx2KdXknkynS6TQ1NTVcffXV3HrrrZxzzjkMDQ3z8MN/49FHH2X37l1EozEhKzHm8KrJq7D5BJgb2CTdSQYbP2/wkycKKQ6HYdKjMW/uXObOnceBAwcoLy8nEArS1tZmweuapqNqOpoOU6dOY3BwkGwmY2lbFUXBafgIlBSXkjP8HSb6crlcqLmcgTA14vF4uP/39zM8PMyLL7yAqqs8+9xzHD923Pp8Tcex8dam5gV+snRGyWS2K4rx+ec7f5fLjcvlRNc0SktKmDVzFgsXLuTiiy/G6VDo7Ormq1/9Khs2bAAgYbgkCmJWzEI/TJOqbDbHxRdfzGWXXca27dv4yIev4Te/+Q0jIyMsX76M+vp6Hn30UbIWaUvKE1vHKUjcbjeaqlmOl5Ik43A6cLvc+HxefD4fVVVTmDZ1GqeddjrV1dWEi8JG4SesYM1ZtHkJ6SeM0Sb3opcVmVw2xxc+93lWr17Nvd/9Dnfcfju///3vqZlSw/IVy+nr7+fRRx8VvAgTCrahXLquEYvHyGQzSLLMRRddTElJCZIs8+tf/ZKWlmaqa2pob28nZ/gJqGrO8kWfiFH/fhvL8fJa3So0RBGeSqXo6uriiivW8oPv/4DGxkb279/P6Oio5S5pt9Z1u91WJGs2m0XXdFxOJz6/j/7+PrxeHy63m3hc8HVKSor59L/9G9XVU2hvb2f69Om8/vrreL1eotEoQ0NDwvdCU9GMUY+AfXULwUwmE9a46gRr3/HmYbLgxCQSCVpbW9m+bRsDAwNMm9bEylUrmTNnDqVlpdRU1zAyPEIyKUiYbkPSbBKxHQ6HVdSVlJRY0cv5S/09MkfII6C65SnhmiQ1UzLQPM8J5MxT1gWekLUhnWCmpk9irjbZ6zHP+erqaq6+5hq2bdtKJi0sh5PJpOGfIhdwocQ4SKGhvp6zzznHGJnmvSzMsUk8kaC3r5c9u3ezedMm0qk0/f0DRiaFwoIFC5AVB/FYvMDmeiLkRZIkHJPJPcx/bt68uQBmNl3QJOMyOP+Ci2luOUZFeTm64Y43a+Zsrr/hBpwOh5DLyfkqUZZlNm/eTHPzccJhQdCSZYVMJmVZIWZzWatLNCF5O6zmUBxCBWB8RSKRcQ5yGplcjqlTp9LT023JBDMZwaYsLi4mMjbG4OBggRRE03Q0dPR0xniQEm6Xi7nz5rFz1y5kdMjqFis3k8kwOjpqFRH2AB+JvGe0Pg7+E12KiG+VpLx2WFYK5+SKLOH2eEGHWCxqRUCWl1dw8cUXc/7551NcXMzOnTv54x//yI4dO/IXptMp5CcGRDf+sjMRlQKdu/HnbiPtzgxYMbXrspVJjRXu5Pd6qayopK6+jrfffltI5Mh7WJeWlTLQP8C+fXtxOhRcbheZbBafV8BY8ViU8spKkbudzeBQBAPfvlBFQloJXV2dnHHmmaxevYYZTdMpLS3jf3/5Sza//TbJRALFoeByu8kaa0OxQcJ2LwaHLQXx1MTDIgNBVkQIE0bOhNvjJZFIUFNbw+rVa0gmU3g8RezYsYM3N2xg2bJl7Ny5S3RHDgfxeNzyLRi/18477zy2b9/ONVddLfzUFQc//OEPefW117jzzjuZUj2FY8eOjXvdhc+0pqaGeDxOLpvF5XYZfg0CwvZ6PFRXV7Nu3Qe5/LLLmT17Fm6Ph2w2S093D/f/4X4eevBBSxYajyeIxaLGgTeRtt5W4NozHzQdn8+H2+vh47d8nL/85SHcbhcer4cv3HUXsixzzYevsWaZ1udg84c3i3OX08XmTZvZsOFNPvLhD+Fxu1kwfyG7du5kZGQUxeFA0VRQIZnM2YxnpLzVq5RH/N7v7PiEMCRbKqBsnCMHDhxg8+ZN/Pa3v7VMtZqmT+fokSMW+dblchEuDtPb01vY2Up5Tklvby/zFyxg3ry5HD50GEmC5uPNVFVWsH3bDv73l7/gvvvuI5fNWpeMWSybz0GWjZBmXRfRx/0TGwDbCy7z0tQ1IzSCPAmwra2NtrY2AGbNmsVpp63gkksuoay8nKNHjvLXv/6N1tYWMtkM8VjcGguaxOOBgQHjPLBvKb3gxj1hrm8Ul5pmN4jKEQqFCs55bHJBh9NBMBC0LjyHYQR24nbOj4/1iTycDAO1gn/XdWpqahgaGrLIu5OFZJlNqPl9Y2NjPPTQg6SSKZFNowsemyxLwsbdlhvhcXsoKSlh46ZNrHnnHebOnYvf57dGzqlkkuHhYcpKSjly5AgPP/wwM2fOFMTuefMYHOhnYGCQAwcPEI1ExxWxOsXFJWi6ZiFEDoeDWCx2cg7AeMmbPfRCkWVB1HG7WH3eGh5/7DFcbjfTm2YwFhmltq6OpqYmRkZG8Pl8FhNSVkQn2dbaQntHB4lEglQylbdhNGC4jo6O/AKXZcu+04RXyivKrcrSHuwjSeD1eEml03z1q19lYGCAjo4OHA4XM2fOIJ3OsG7dOlrb2kkYGlZL8228X5/PRzgcRlEUotGoIP54PMgGEVGRZQsJsMODeZjfba0rxdgAJ7L35bx233YRy7JkQOJOnE6BVCQSCWpra/m3f/s37v/97/noRz9G1ZQpPP/88zz22GM89thjdHR04HQKUxk7E1WbJCRiPMPfDu+bntZIErqar+5lWVyEwrI0wyWXXMqKFafR3dVFX18vqqZaqWmVVVWASE9Mp9PU1tYyOjoqXL0Mt7JMJkO4uAS/P0B/X19+ZmokvjmdTvx+H9mskIj+9W9/Y8mSJfzjHy9x/Ngxurq7efHFF0iYAR6afgKL35TcuVwuZsyYyfDwcKGM6z3uflmScLmcKIqjYJ243W6ByEgQLi7hkosvIRQSqYh/+OMfmTdnLpIkC2WBZIssttZLHmYOBINUVU3hBz/4PkePHUM3yEmCJdzFU089SSqdEiMmg0gnS4Us/erqahoaG2lrbcHpcuFxu/EHAqLY8nmZO2ce9377Xm66+SaqqqpQZIeBpglfitWrV7NgwQK8Ph+qqjE2lpeCKg47LK2N06ZzwqEoSRIvvfQS+/btw+v1Cfa4qqKjsf6N9ZRXlNPT00NbW5vhxknBczOVFQ6jgSgtKeWSiy9GcSik0xleeOEFkayn5qwRVdY2fpMl2cbKHpcrIb1/rXiB94euU1QUpiQcJhaNMTI6SlXVFLZs2UI2p9LZ0cHw8BBTp02jtq6OGdOnU1VVxdEjR1i2bDnBYIiR0RERQZ4TdsIuw+l00Ij6Hh4eYnBwiOrqaurr6nnuxef50pe+zK5du9h/YL/lYDmZF4fDoeD1+oxic3JJ3nhS5PiLze61PzQ0xJ49e3jiiSfYs3sPc+fO5fbbP8Ws2bPo7x8gnU5be2v69OmMjoyKsBzbSEk8G6kgywH0E/1YJuhYq6urhZmTrdkyL/V0Km0RfXVdZ+q0abjdbuLxeEEE+ak8azsqanbdCxYssMbfp9Q8GF/ZbJbIWIQzzzqLYcMQzy7ZVBQZl8OJy+3Gb5BOa2trRf7F3Hl4jMwZyeDVhMNhJEmg8ps2vcXBgwcpKytFzeWYNXsOOjojwyOiGDQ+9wLfB1mhtLSMkZERK8n1lEiAE7JojcCegwcOMDQ0REVFBQG/n8FBwab1eDxcccUVOF3iUrLIfRIcPHiAd999l86uLqLRmDXHNv9nv5wsGN6opH0+H06nk7raOnp7ew1Sk3CFA91g1YoD4Wt3fw2v3wc6nHHGGUyfMYPDR46wZcsWFEWhuLhYVEGKYpGrTAliLGZAkMZhrGsqqVTa0HQKFzeny3UC0bCxsZFIJILHIwhv2UzWCKrJw/sFpD5Fwe12I1vyJTFny+Wy1NXVc9aZZ/Gd73yXe++9l4bGRnp6e/jiXXfxne98h507dzI8NIykmD4IppbbiAXS8gEpkn3aqRse7ZNsDMmS2mhWGJQsi9fn8/kI+H3owB2f/jSXXX4ZD/75QUZGRiztfDAYIhgMkkgkDBtlnWg0QsYa0eR/l5rLMTIyYhHtzE1XUlpKWVkZA0ODFIWK+O53v4em5vjVr35FJBpBliU2vLme9ra2gmjQ8e8p76yoE4lGUXM5GhobiRvdmT5hw5/3uDPNpEzjEacxAnG6XHi8brxeH1esvUI43Xk97D9wgC1vb2HF8mX8+Cc/tnILcrmcSAAsgNNlyz3tzTc3MDg4iMPhtApfAd+Kl5JJZ8hnnkgGCVQUr4FAQGRWHDlsJO+58ft96JrO3Dlz+OEPf8TXvvY1pk+fTjQSZbBviGMHj7H+1Q0MdA8iSTKBkJ+m6U1cdNFFrDpjJfv3H+TQwQPkcjkC/oDwO7BB4WYRY/d9MCdZ9gLLHHeYxF5d03nxhRcZGBwQ8L0uLALGw6rmWeD1uFmwQIxXVMMO9eWXX7LCktLpNIlEnFwua6xRxdJd2+Wp/6xdjDTOOk4CMrksuWyOTCZLMBRkoH+AQMDPjFkzqKyspLe7l76+PmKxGNOmTeOGG2/gqquu5owzVvHOO1uEp4BRrMqKgt/vo6S0hExa5JycdtppLF60CEWReeXVf5BOprjxppu45ppraGhoYOHixUyfPp2xSMQa29mLMEmSGBkZ4dzzzsOhOBg8ScCTnRs1ITPC1g0LMzWdvt4+XnnlFf7217/i9/u5/PLL+eC6daxauYpt27fR1tZGMBQkVFSELMnkstlxoyPphO4/r1w5MZUUIBaNCo5DJoPb7aKoqEg4a5KXQZvvf2R41GL3l1eUE4vGKAoVUVpaahUK0qQkbBH0JckGz0eWKS4OExmLiO5elk5ZGWOe8bmcSllZKbNmz2ZocEjch4ZaxuRyuT1uwkVhotEIIyMjrF27VrigZnLWuC8SiZBKpXnggT/w2muvGZ+FB7fHw7vvvGOdf8IiW7PM8BwOp62ZHSsoHv/pAsAkj8iyRHd3N+lMmr6+PoaGhjnzzDMF/ONyUz2lGl2X8Pk81uz+5//7c7Zt20Y8kSSTTpM2dIumN30mk8Hv91NSWkIsGitwhzIzAcbGxpCNTaQ4FEJFIUZHRkWiVC6H3x/A4XRw2mkreeSRv7F37x42vfVWnkhWVkYoFDI8rAXnVsDzRrSl5WsufNpTqXT+IJMlPG63zaEuTxAyIzOFvWv8BITAhNFNDoHbJebzsViMXC5HaWkpV155Jffddx/f/8EPuPqqq9mzdw/f+MY3+NOf/8z//vx/OX78OB6PR6T05XKoObXgMstfsno+G1UHXSp0j5u0ijU2gjnzFl784nD1+ryEw8XoOnz2s5+loqKchx/+G5qm4/G4qa6uMWaUgxYxTMi11IJRkizLNDQ2kk4myRiZ4ZIxN3Q6ncRiUcbGxggFQpx11lm89tpr/PGPD1BTW8NAfz/Hjx+jv6/fgPW0CQ+w8XpiM8+9vLwMv88vDI+sGV9he+h0OvF6PegaeRtig4fh83pRjMKtpLiYj3/8FhobG5CA4eFhXC4nTzz5BAcOHLQiR83sCkmSTwjwMEdjsuH5bSd+mqljZgdqWd0ah7biEFV9MBjE5/ejOBykUinOOONMvvKVr/DNb36TuXPnks3kGO4fYd/+vTz99FM8/PjDvPCP59m6/V06uzpobGhEQbEMcC67/HJmzpjB0aNH6ezqJBwqwu1y54NPbDCq3SdivE11waeqC8KajtgnE8VPu9wuXA6nhfT5/X4qKypZc/75ovh3OYlEo0KtIMn09PRYsKtdSmgWUfYx12R1gPQ+igBTeWDm3MdjcYaGhojH48RjMYKBAOGiIkZHRlFzWY4cOcqrr77KkaNHyGVVkem+c2f+Z6gqqWTKmuEWFxdz6aWXcvNNN7P+jfXs278Xl9vNJRdfwrJly3C53bQ0H+eYEWmdTCVPcLUz1Uvt7e0MDQ1NyGqf2Or3vaWL5ufbNH26ESzl5Mjhw2zevJmGxga+8IUvsGTpUmbMmM7xo8fo6ekx0BynEc/NCZHIwWAIVVPRNd0Kj5LH7V3T9MkkzYWLw4yNRdAnkeWZTUEingBdp6a2Fo/Xy+jo6OSNjykTl2UcTidOl4tsJsPatWuRZJnurm4RwGRbW5N7tuVfeyQixs1z5s6hKFREJp0iYyDJwjtDIRgMMmPGDGpqqnlzw3oCgQALFy/G7RaE9Gg0ytZt2zh0+CBPP/MMx5tbwOCWzJw5k2gsxvDQkDAnc7pYsGAhTdObiMfjZFLpAj6Aw6FYBegpFwDjF4eAmsWmC4VCOBxOiopCTJ06lQsuuIC//OUv9PX2Uj2lhrGxETRNEOlUTaOzs4tnn30OHZ24LXDInpSnKEIja8L0dpKFqgp3rlgijsPpsCJHvT6f9XO8Xg87d2znE7fdRk9vHzu2bxee/sYMJp1OU15ezsDAAA6HYi3IqilTwEheUlWVpulNjI1FLDJNaWmpKFKyGdScaknx3G4XJSXFJJMpi7iIYQmZZ/DL1riiqChMKpUkGo1RVFTEqlWr+PKXv8zvfvc7LrvsMsbGxoiMjfGpT32SH/7wh3R0dBj6ceF3bo/vnUg3a3fxMv+9qKiowAOfE9z49AJSomWsYiQEygYhp6S0hM9+9k4uuuhCHA6FTDbH2NgofX19ZDIZxiJjOBwiRVKWZaZUTyEylnf1c7lF3Ob0GTPo6OigoqKCs84+m77eXlauXMnpK1cyZ/ZccjmhPDl+/DjZnOA/HD92jOHhEStJTyuQYJ7c69P84+HhYTLZrAGp2zqScVwYK7NcF87LiuGEmUqn8Pv9yLJMfX09t9xyCy5jo27buo1nnn2GWDxGLBolbjCxzUtKtt2S46U62kQmPLaCSbG5rJkKB4/HQ21NDSWlpZSUlODxeLjpxpv5/ve/z9KlS5Ekma7WLnZs38Hfn3yMP//lT+zavZOevh7i8QTxZIxjLcd4a9NGhodGmTa1iWAohNfrZtGiRdxww42Ei4ro6e5idHRUhBY5XdYM1p74Zt6w+nj2tnRix2c/Na0L2qiMiktKcLlcuJxOvF4fbW3t1NXWsWjxIhTFIdI/h4Y5fvwYHZ2d1vzbfG4m6uDz+XB7CjXRE6XivS8D+QnQIoFaqcRicXp6eohEowSDATIZwb0pDhfT29PL4cOHCAaC6EBXVyf1DQ1Mn96EyyWY4clkktHRUeELL8l857vfJVwcZsH8Bfz+/vt54YUXeGPDen7/+/s5cviwUN+MS4STxl2C/1eaeXO8aCKsY2NjJBIJQkUhOjq7OHLkCMePNxPw+5k6dSrXXnsdl3zgUkrLyqiurqG5pZloNCrOSgM5zaf9icJWU1VkRRHcKUPlJcsy05qacLmcRKMxy9E0MhahoaEBh0MhmUyekHGQV32IdTk8PMzQ0BA+v4/ysjILnaIgu0RCURxIioLiUAgGgsSiUe666y5yuRzbd2zH6XSQMsKWJpPZjbeVN8/WbDpDT08PAwMDBINBgSzrIgNDkiQGBwYoKS7hg1deyaZNb/H6669z6NBBywSrr6+Xf7z0MgcOHECRxd04e/ZsampriEZjLFy4EFlW8Hg9jI6M0NnZSSwaJZVO4Xa78XjcBr9KRjZeqCK9TwTArBjtMEJOVYnH41RNmUI8FuOpJ5/C6/XS2trK1VdfxcUXX4ymqgwZ3fasmTP5wx/+wFgkQi6b9/fXbBBuNpu1Ln/7xSTcuzTrkpFlmTPOOAO3x0tNTTVTG6fS1dnJtKbpZDNZ3tr8Fk1NTRw8eIh5C+Zbh34qlSYSGcvPHiUZRRHQTDwWE7wDtxvF6UBVcwYEK8g1yWSSXFZUWopBiHQ4XQUMV1N6JTpopzVbz2ZzrFq1iuXLluEP+Pnu977HT3/6Uz75yU9SWVnJf//3f3P33V/lkUcf4Uc//CHHjjfjdDgxU8Y0Q/bDeKMMg9U/mUe8IitkMmlrfGF2WBh/XzM0vqYphkNx4HK5RNxyMCQSx2pqOG/NGlafdx633HIrXq8PkFiwcD6HDx8mEokyNjoKiGCNaCRKOBzG7/MTjUaZMWMG8+bPo6Ojg4XzF7D2iivo6uzgnHPPpa+vn2OGE9+yZcuZ1jSNjRs3ks1lre8fGxuzkgHNDuzkuuLJ7VHGO6lJ4+LQzMvN7/fhNvK7FYeCy+UiEAwRCgXJZNKsXbuOiy6+yOJNPP/c8xw+dJDe3l6GhoYYGRk1Qo18ZNJpNExdtfOEQszku2AjkIKw9zQVGU6Hw1JReL1efD4vFRUVfOITt3H99TfwqU9+irVrLxeGMjocP9bM8y88x98efpBtO95ldHiEZCpNNBoT4y9ZxuUUF9A7727h4KGDuFwukvEMLqeLYMjP2WefzUUXXYzH62Hv3r2UV1bidruFt7yq4nS7rK5TeAhoeZMuO5MekE5i+qIjOppEIkE6ncbpdCErMul0kmAwyOWXX27ZL7e0NrN12zYGh4dsOnPVIuTKsjDsMsOPwuGwJVeVJoi+O3H5SBMm4J1MOiqR19inUim8Pi85VcXldJJIJEgkEuzZs4fTVqygq6uLrq4u0KGktJRly5ezePFiSkpKSKdSrLtiHRdfcgmrVq1k//79BIMhRkdH2bFtG01N00hnUjgUU2fOCQjHKeU4GH+nvLz8pDHlhTwPgS6ayGZvby+RsTHUXI5YLMLmt9/m0Ucf5emnnyLg93Prbbdx/XXXsWbNarweL+3t7RZXQJEVfD6vkcyZEc2RFcUr1o/b7SabTpPJCq27ZrsLFKNBFAhdPopa08Zp9m02yYLbJMymTFKfqXIykSNh257DoSisvXwtt9x6KwsXLaK3p4d4TDSd4aIwXq/HuAtzJ6hGLOTV1lBUVU8hm8uSiCeQZZmSkhJrPft8XrK5LOeecy633347H/jAZfT39RMMhdiyZQv/eOUVtm3dxuOPPc7UaVOJRqN4PR6cLhfr33iDRDxOwjBrKi4upqioiL6+Pm66+WZ6enpEhLTXSyqZwulQCAaF4ZBVp5wY+DC565LZpBR4V8vCSzmXE17eikOEITQ0NHD+mjVce+11NE2fjtfrJRgMcscdd/DHP/yBYJHQxOtm/rxl96sXsHknIq15PB7S6QzFxWEWL16Mx+th2ZLl6LrKrt172PjWm4yNjvGtb32LY8eOkVNV9uzZw1HD6zmXy1EULhKa/pyYP0tAcXEJiYQIQ1JVlVBRiLHRMWtxCHRCMYhGUFFRTiadIZ3OCOKLoTowCxkzzrKhvoFLLr2Uj3zoQ1RUVuLz+qitq2XHjh389re/5aG/PEQ8FkcxLmb7xjvRDUsr8Og3kZE8b6KQ2CfLspjR2yyRsXWXqqpSVFSEJEuMjozi8/mQZZna2lo+cNlluF0uLr30A5x99lm2+a6KLGPJEwF27trJiy++SEd7B0ePHiORiLN92zZCRUUsWboUl8vFxg1vMmPGdIaGh+np7bVkU4uXLGH58uX09PTw/HPPUVpaSkPjVPbv22vFLJ/AvD2JJ7t0iq5sk7na+Xw+AsGgsLM2LhKv14vX48XtEXG3v/jFLznjzDOMrHid3bt38eUvfYmjx47hcDgY6B8gk81Q39BAJp22bFdz2Ryarp4wf7U/b9MgqaysDFmWicdiOF1OS5/vMyRhl112Ob/93W/x+/1omuiOjh45ylub3uK5558jm83gcrkYHhokFk8Qj8dJxJNkc1mCgQB+v9/S4DucColEksqqKr75H/ew+rzzcfuc1nm2e/duXn3lFR740wMcPXoMr9eLIsuk0iLVzuf1EovH8051SAWFvXjtYjTlcjrJ5vK8EMnGsjfPnjlz5iBJOrU1dTz62OMEAn6jsBrh7rvvZv/+/SiKQjweZ3R01CI32dNDnU4nDQ315FSV7q7ufOc3zub6VJrlgjU3IZlOtvacaviIuD0eEvGEVaTU19fT1DSdDevfsM4QSZKor69nxsyZTG1s5OMf/xirVp1BJBLlogsvZMeO7fz+/vtRNY1bPv5xAn4/Ho8bfyBIR0eH1WDYm6X3Os9NhDAcLiYSiUyKGEz42Rhv3oL1zbm60b0XFRUxPDyMJMnc/qnbufa662hqmkZxSQnPP/ccb6xfz0svvkhLSyvh4iJSBnIaN9aOy+UybN6FE6zV4RujJ5NnIgpjQagzuQaKw2HFTWOD6fVJcjFMg6OiUIj5CxZQWlpqpKJWcv3111FSUgJAd3c3r7/xBq++8grxWJye3h5aW1vo7x+wCqKTEQ4VRbESDs37S5ZlgoEAxSXFZLM5HnzwQVauXGmNWwaHBpk1axbDQ8MEAgG8Xi+lZWUcOniQYDBopXCOjY5Z72lq41RGRkcMorKDgYEBiorEPWeG60nG6FQJhUL3jI+MtOR2DscJXuz2y7++od7qjoQfdNZaVGpOQOb9/cJXO5fL8acH/khXZze7du+is6OD9vZ2JFkWMY+mI5zNr9w05/B6PRbMZg++ERWrTjKZFIzyoiJqqmtYtHgRn7jtk6iaSmlpKb/431+QzeW455vfJJNOk0wmDV93WXiKI0wrFFkQ+5xOofFWHMLQYmxszGCk+3G7hcuZx5CAzZg1C7/fRyQyhs/vN/SoWavTrqyqYvWaNXzqk5/kf/7nZ1x11VXUNzSQSqU4dvw4n7r9dr721bvZunUbsiRbzl5269lCSRIWw9n0yR7v9jVRlS+gbH2C+NL8zzYzxk2NqqZpDA0NsnnzZsHgz2V5++23effdd5k3bx5+v9eC15588kl+//vf873vfZfNm9+mtaWVPXv2CCMcXUS4Hj9+nKNHjpDNCRey0dFR1FyOmtpazjzzDMJFYV566SX27tkjYEFFpsc4sMdfDqfqrvg+4u1PYEWbFbOAJmULcXI6nbhdTurr6/nApZfj9/txuZy4XC5+8b8/56mnn0LXdLJqTsgTjbx0RZEJBAICebK6A7mgGLMCogy0y0Rl0HVkg7gqyzJen4+LL7mEm27+KF/+8pcJhUKWPe4zzzzLf937Xzz00EPCzQ2JWCxKIiH2SSqdJmvIybI5FVUXI4p0KkVOFdK5SDTKrj07OHL0MNmMiprNoWoa06c3ccYZZ7Bs2TLGRscYGh4ibfwsTdPIGIWaUIuIvZJTtQJEwxwR+AN+MplsoQe83YhIksik01xy0cXU1zeSyWaYP38euVyOvXv3snPnDnR0EYc7OkoymTQ4OoLEhQ1VHB4eIZUSUGhZeRkSeWtoeZxN9clsqJnE99/pdBbC7oYxj6qqZDNZK2nSocjEEwmOHz9mBEqpBbKx5uZmduzYweOPP8627dvJ5VR8fi8HDh7gmaee5rOf+SylZeVs2LAeHR2fz08sLoLNTP+H8b4X40d91l4ynoWqqlRNmWIVupO7SkqTojeSTWwkGcRU05JWkmWKisJ86Utf5Pjx46xb90FuuvFGbr31VmbPmS3WqKrR3d1NU1MT561eQ2d7O9lcFsXI38gbcylIshjFxuNxKquqUHM5w4sln0tiRluf7LwoIA1LeUl5R2cHe/fuZfPmzezcsYPTTjsdVdP4z//8T374/e+zY8d29u3fT0dHh2XqcyrKAHsTZylsjAIqEoly4QUX8OlPf9paQyIvJMHo6BgOh0Jrawuf+9xdVFZWoBoOmFdddRVLFi+mu7vbGrEMjwyTSgllXTKZJJVKWf9ecIZKEko4XHxPdfUUywt+vEXiRNWfeThNbZzKlVdeRXFJCQf2H8Dpclq2nuYFXV5ejiQrfOYznyUaj9PX18vZZ53J4OAQ6Uya7q4uwyTDSCE0CV02fbqpOND1vPmJOfNzOpz4/H50XSOZSNDX10tfXz+33nYrF114IevWXYnb7aKxcSojo0McPnSI0rIyMUvK5iwuA7rQSzsdDgHXGgzlXC7Hueeeaxhu6Ph9PlwuF2NjY8yePQe3201bawuVVVUk4wkisRhlZWVceumlfOazn+WWW27B4/WwfNkypk+fwaZNm/jG17/Btq3bSSTi/O73vwdNVIOmcY39ICmwLEVI5MZ39xOmb0l5/sF7yWAki18hCh7VeB1ut5vTT1/JaaedhqIotDQ3E0sk2LVzF2+/vZlzzjkXv9/H9773Pf7yl4fYt3c/vb19ls+82IR5ba256DVNHFSNjY3Mn7+AdCpFd3cX27ZtF4ekdZmI8BETplMUeUK710k13tIp3PqTQKa6DtlsBlXVcBmdfyAQwOV0UFRURDgcZvbsOVx51ZX4fB5cbje//c1v+clPf0o2mxWafyP1UQQRSWIjptMiytXIa5Bth5bb7cLnFciL0+UStrpOF04jItfhcOB2ubjsssu4+yt3c+fn7mT58uWiaESMhn7/+9/x29/+mkxGyP+y2SyZTIZkMknSOAgymSyykY0grHhVQSY1ECSn00kgEMTpdPLOO1t46aUXGR4eorK8iqrKKpwuB7W1tVxzzTXMmzufnTt3kUgmUBSHgUTl8uoW2RgXkifXmpeKvRM3OT8iOMpWlGYyRKNRFixayKqVq6isqhRmYz297Ny+nZKSErq7uy0yr9vjwe12WT/DLmnLZoW/iNvt4fTTT6e0tNRCDU6liJSN+fdEo4NQUciSBWO7WO2InejSVeu/F3bswuzK7/ehqsLo6+CBgzz99NPEYlF+8Ytf4vJ6+dUvf8WXv/hFNE1j27btjBmXtl15YbfWPpnDpbnPHEaRaY5ITr1oLkz3MnX0uq4JebchZR0dHeXAwf2UlZXx9FNP89Of/pTNmzcTDAa5/rrruf666zn7nHOQZYX+/j6mVFWiapol89Y0jWwmK4pwI69l7ty5LFmyhKNHjhh23wYXzFjHExvf2Gb0up2/YUi6s1kikQjRiBg3xmJROrs6rfPwB9//vrCwN7hNJ8sGGH8EmSiCRfi1EaJNYm0mk+Hcc86loqLC+ixefull5s2dyx/++AdSqQy9vT0Uh4tpbWnhoosupK6+DjWXY8qUKbS0tFhIaSAQIGsoVWRZxKiPV6wBKJls+p6cquF0CveggqCJPIeiYPZlLi6Px8O2bVvZu3evoXFWT8iLT2fS9Pf1URQq4pvf/CbNzc1IksK3/uvbRlek2EJZdMFOLMjBFuxt82DKX44ijS8/R5XIqSqdHZ3Mnzefy9eutbzjO9o7KCsro7SklPa2NissJhAMiEs3p1qkN6/Px+DgoDG/l2lqauKyyy5n967deDweJEkml1O57LLLWbZiBQf27eess85ibHSMxYsWc+edd/KfX/86H/voRykrK6Ojo4OS4lLaOzv40pe/xPe++z2ikQiJVIKHHnqI0rJSa35sh+nMy1+WbWtM5wRPAc3yNp54o5sP3OFwGGiLNinsbbKoZ82azVe/+lVOX7WKluYW4vE4b765wfIiHxoeoq21jcsuuxx/wMe3v30vsXg8Pz8z4DBZFhne473Xi4uLmTFzJh6vh97eXlpaWohGYwXFzAluYTqEiopwuz0G0VKeFOb8v/iSbFacwWAQl1u4YHo9QgEwOjLClVdew1lnnQkSDA4O8W+f+QyZTFqMwoxDSJBvxKwup2pihm8qR2w5Fk6nk+LiEhwup5jTGfLZQDBEMBhAkmRmzpjNF+66iy998Us0TW8ilxXIRDweF8jJ3r08+eSTVu573JgLiowN49lkcxQifrrlYS8cHPN7OJfLWRd3c0sL7a0tBkQrE4vE8Xp9zJozk6uvvoqmadNoPt7M0NCQGCUZxXnG+N0iglhkDCgO8f/NC9DhUCxZqsPpMDzUBUejtLQUVdPYuWM7F19yCTNmzECRZSqnVFJRWYkkwUB/P5FIlEAwgNsg6JocEbOTssiUkkQ8HufYsWMEgwEWL1mMhGSLPcdADyZOO5xsHGB2WOPXoN2yPF/ouQuMiuxqEEESlvD6xGjF7/cjSTL/9a1v89rrr7Fj5w4OHznM2eecw6JFizje3EzUMMgR71OgSoqiGJeAgcqaLbqxDx1OJ26Ph7RBdk4kErjcLpDA7XKfYKRzqpb94wskU7kVGYsQj8WYNnUqqq6xb+8+Hn/8cR577DESiQRr165l7dq1XHPNNXT39JDJZBkaGmKgv5+iopD1nJLJJC63i+PHj1tOhCOjo1bhaRIH7UiHSX5WVe0E7sZ4GXDej0U2PPuFgicYCPDSiy+SzeWs5zmp7fREZ4nBSRk/KtI140wwiqZPfvKTFBcXk1MFN+CtzW9x4OAB1q27kllzZvPG66+zY8cO/H4/paWlrF+/gUAoyDvvbKGxoZG+/n7LBVcUlU6D06BZZ2Z5eTnBYJBwuAjF5XTdE41G8Xi9OBTFNmstDNCRx0lFTOjClJnYQ2WCwSDFxWEx3wiFyGbSdHZ08Pjf/872bdv57//+by648AJee/1Vw6THac0lLA/y8fCuruN2uQkEA4SLi6mtqaWvvw8d3bpA3W43OhIf+tCHmTVzJkeOHqGzo529e/eyYOECxsbGeOnFFxkaHCKeSBAKhSxPf0VRhM40m2HGjJmoao5oJEpJSSmKLDMyMsL8+QsI+P2ceeaZLF26lMcfe5Q5c+Zwx+23c/PNH+WOT9/B4sWLKS4uBuD48eO8uXEjv/rVr/j1r35FZCxCSUkJI6MjdHV2URQOk0omSSYTVvJeYQElPM71U4CXrKLAsAGdN28evT09Voc5ffp0An6/lURnMvxlK51Lp76+HrfXy1VXXcXSpUv53W9/w5Z3ttDT00MoVGTlWQsda44zzjyDaCzGz//nf0RiWDJBTs0JTbYkHBtT6STmXeN2i5mX3++ns7OTrs4uyirKyRidqL1bszvdmf89lUqRyWatWE2Tu1BaWkpxSQkxQ+P7zwP/heE5AMFQUMCssRgYsPW0qVOZ3jSNa675ECUlpbhcTnbv2cPbm98m4BeQbDabI51OMXPmTBRFEbN/q0PMhwr5DekeQDQWJRqJ4vP78Hq9+P0BZFkUIZ/9zJ1867++JeaDukYqlSaZSvLkU0/y5S99iUhkjFQqyeHDh+nu6SGZSJBOp0il0gUFgB0xkSQJh5F0aPpHqCbSZsDv0WjcImJmsmne3bqFJ558kpKSYubNn08ymaSkpJgFCxZw+dq1FIXDDAz0MzIiintTFmuOEyUbcrVkyRIaGhoN+2jx2dTW1dE0bRpdXV14vV4LoSspKWGgr5/TT19JKBRElp1UVVbxyqv/oLmlVVgHp9NkjFFGJptFHyfRxZq3i/c3ODhIa0srFZWVXHTRhWQyGSFf1U8k+0l2hvf7WlrShByB8fG2km2saapGcrZ/RqNR/v7Y4/T399F8/DivvfoqNTW1XL72cgLBIDo6w0NDBdbN/kAACYlAwE86mTrBu98eWCZegyDheTweMpn0xAEy0vv1UMgX8plMhnBYjGllRSZnjAJfeeUVNm7cyLbt25kxYyZXX30169ZewdSp05AVGb/fR3FYjL48Pi+jIyM4nQ4GBwcZGR213F9NIqrZvJnE2aVLl1oqC7uFvD6p8iMvHTWL19LSUnbs3Gm4gebed5KpqmkGiq2PG+vqeL0+IpEoX/n3r3D1NVeTSWdQHAr9AwOEw8UcPXKMXbt28cwzT4EmzsHz15zP7Nmz2bRpE3v37sHjdjN33lwkSdzJZWXlSEAikTAs+0OoqlhbZaWlRlEoI7ndbt3tdpNJZ6iorKC/v9/yUjchZFXNWRbAum0+bc+8d7nchMPikpgyZQq9Rkqex+Ohv7+PVDrDunUf5IorruD++++nsqKcWDxGRUUlr732mtU5qrmc5bJnHgp2yYVpBhQOh6moqKSzo52q6mokJFpamnHICpvffptpTdP4zGc+QywWJzI6yi2fuI3LL7uMSy+9hJdeeplwOGzZMkqybEQrColReUUFXrebbDbHihUraG1tYe7ceTidDubMmcuixYsYGBjA4/WyZPHiguo3Fo/z8ssvs3Hjmzz/3PMcP34cJIkVy5aj6Rod7R2Ei8O4XC66u7uFn4GsGPNKzTqkLCKYJJ1SAWBfv06nm0DAz/DwcL77lwRCIlsbRLHgKJ/XS3FpCVdfdTVvvfUW/QMDFiPf6RSzXI/HQyadQZZlXB4Xo6Oj3H33V6mtreWLd91FSXExiWTCktelDamMw+m0CCdlZWWMjY0ZGxHD7VAwpF0up1Uhm/I4O6HKztq3tMvGeKG4uMQ60N+L2Hcqf8Fa+wieSyKRJBaLUV9fR2NjA6tWreTyD1zOnLnzcRixyAMDA3z5S1/irU2bLIlUMpmkoqJCxHXGE3nI1eGguKQEt8tFUVGYzq4O4WNvIGihImGkZI4PvvmNb3DLrbeK52WYlAC8+MKL3HbbrcTjcZYsW0pxcTEdHe20NLegKA7LKCeZTFrGOiZ0qWqqFQgjG+9V10QmumlOomu6lVbm9/ssmDUejzN71izOPvMsKqqm0NQkeAHBkCAl3XrrLRw8eIjh4SGam1vx+324nE50g2eiqSrpTIbzzjuP6dNn8Oc//wmP10MsErXm5qlUSiRH6rpQOwT8BH1+fvXr37DqjFXoOqx/fQP//pUvMjI6wvDICMlEIt+dGYWMQaQp8Mmwk2DNfRUMBqlvqKdpWhP9/f3s27dPFH0nGTFNRpQ2GxZ9grWnGLkSSHmt+qnG3J63+jwy6Qw7DR+BdDqNoijMmTuHCy64iP6+Xg4dOsTSZct4/LHHrJmwLMtkzQJ73Px/ot+dPx9EOJtuAAinuH1O6sWh6zrFxcW4PW7UnEoylcTvD9DX22v97muvu44vfP7zLFu2jOHhYb7y7/9OPBGnpaWFzo5OOru6CAQCVFZU0N7RQePURhJxMf71eLxC/59I4PV6BXk2Hqe2ro7RkWFisfjEAT4T+OSbr7e0tJQVK1bw0ksvGWNutQClnZQkarj9FRWFLfLveD6Gy/AaKC0tpbm5BZ/fJ+6saISvf/3rvPTSi3R3dVufjSRJXH75WlRVZemSJbz8j5dpbWslEU+wfPly9h84wODAAMFAkEwuI9RqLjc1tdXibk+mLEdCAEVCv8ftEdKbpUuXEY1FxexFkYwDQrGIKnaWucslrDjNcB6Hw8kHP3gliiJTV1/PeavXEA4Xs3XruygGQ/3w4cN8/vNfYPXq1Rw4eJCuri6Ki4sZHBgw5BkGQ9Ige5jpU4pFRtSMQynHyOgIHo8bj9tDQ+NU5sydw/nnn8/yFSuErKy3jzlz5/Lte7/NwUMHKQkXc6Eh13rhhRfw+rwW0dHlFHK3YCDA9OnTicdjyIqA3d7atJHKyio+f9cXaGhoZNUZq/D5fEybNo0pVVWW1040EiWRSDAyPMJvfvMbDh46yJEjh5kxfSazZs1G0zRamo9TXVPN6Ogora2tZLNiFqvZOn5LvaqfCFOdTKMr4kHTVnWfTCYpLS3F6XDidDlxORU0NYeu6VahZW76885bTU1tLS+88ALHm48zYMSgyrJsKC0EORADHjXzwf2BAJGxCG1trWDFIOflecXFJfi8Xsu+MxaL2vgbpuwmiyTJlJSWWF2p3cTF1M6bxhX2DkQ3Pq9kMonf5yNhEO5Ohf1/sk7G5ET4/D5cLjeRSARZkQkGg4RCITKZLDNmzGT6jBlkDALck08+ydNPP00kEjHknlkaGhqIRsV+mjt3DjW1dfT29aKj43F7iEQiDA4O4PMKXonT5aKstJTp02dw9llncd311/GRaz7Ch6/9CJGxCKODY2x59x1+8pOf0N/fT3t7O80tzRbc19PTQzKVMmD+bAEB1CzUxf/PFRz4eahcssGbGpou3DcbGxvweDwMDAhzJ7dLpGwODw3x1DNP0draQmPjVGqqa8lk0mSzOS677DI+8YlPWJdoOBwW3bnx55qqcvTYMY4cPYyEZKF4mpFoZkpVJcN90ulwUFpWwkUXXURtXZ0RnZvmH//4B6OjY8Z8P2ONFexzYH3c5T/+WSuSUDEMGJa2p51+esHfN7thUylhZWlYVrbjLINtmnSMxDcRm63Z5uT6KVvKmjauXV1dhEIhVq9Zw8GDB3A4HWQzWfr7+9my5W0WLV7ErNmzBWnVKPRS6RSpZErYkiv5UCt7VPBEEdhFRUU0TZtGX3+/1fhNdLmfUgTzOJWLSdouLStD16F6iigi6+vrmTVzFi+88By/+tWvOXrkKK2trTz00IOMjoxQUVHJBz94JUuWLqPl+HESySQlJSVEjQTT8vJyRkeGKS4uYcVpp9PS0myNt+Jx4Vng9XgN1KpEqHHUiTMDTrBEVhSGhgYN/o7+vlBGeyBSvrE2n4WOx+3lrLPOIhKNcP/995NKJo2snGKefPLJApLhtddey5lnncXTTz9NfX29SAV84UVS6RT9ff1kjf2VTCW59NJLCQRDdHR2MGxkGUybNlX4aBgmaIqOfk8qJVy5hoeHGBoaYurUqZx++kpmzphFKpXAoTi4/sabCAQCDA8P4w/4xSzERhTU1ByHDh9m2tSpFJcUMzDQz623fYLu7i66e7pYveZ8xsbG+MtDD/LBK6/kzs9+hnVXXIHb42FKTQ07d+60dM7ZbBZVU3G5XUxrmma5ZslGUWDqjIeGxOs9cuQw27ZuZceOHWQyGZYsWcIdt99BLpehsWGaoX/P8dILL3LJJR9g797dxKJRazYrGx2Vy+mktr6W7q4ePnDpB7hi3RXU1dVx8UUXUVtbS0VFuUiwczotaCieiJNIJFBzWV597TWeeOoJXnv1Vfbt3U9lRQVVU6rp6Oiguqaa3t5e4vEYw8PDhgYfoQsvCFiZnNE//mAxDx23243b7bYMMRwOBy6DgevxeIhGo0YspCCaVVdXUxQuYkr1FDweD4cOHWb3rl3CJlOXkBVxQReFw7hcIqFsfCSx0+mgtKSEaDRKa0uL2Eg6Vjfl8XpIJQU72z7TNzkfllRLFYdzPBYXP9fltKlJOCWoTVEUS2I4MjIsnqfpGWGgRtoJG106wTzEeo1G3oHTmTdoyWVzJJMphoaGOXasmbLScmbNmI3X68HhcPDoo49y6NAhfF4vmXSKcFEY1bCkFh1tmu7ubjRVrF0TfpVlCZfLjdPlxu/zcdllH+B73/0e199wA4sXL6axsZFYJME7m9/lpz//CT/67x9x4OB+NE1j67atRCJRYvE4mXSGVCptJOKpaKqGZhCLrEJ6HGHUTsqUJeFE6HC6DA192lIb6LrO8PCwQBKMdR+LxQgWFVFSXMKBAwd49bVXGRoYZO68eZx55hk0NDZQWVnJunXrWL5iBbU1taKD6+wUHZS5niURrW1+HiYforSsFHTIZXOW+mbG9BmsXXuFiDzNauzdvY+XX3kJVVWJJ+KWu2BeVpgvE0/auZr5Csao79ixYyiyQmVVJZWVlWQzWUpKSqxxoWwka0pmMYtU0KFZng0mr8HhsMaCpmVxQSgXp8AeN0adg4ODDJlIlwQet8dwHnXQ2tLCnDlzqa6uYdfuXQDcfffdrFy1kqNHj1lqJvNzdrlcXHTxxfR0dwv+gs18J5NOEzdIgWoud0KOvN2YzY5iOByOAvkdk3yfqqpGcmKagYF+BowmcM7cOZxz9rmk0ileffVVdu7cwdy581i6ZDlf+epXWH3eeVx99dVcdvlabrjhBi666EJhGT44iCRLVFRUWCFEvb29eLweKioqGBsbs6Tm2WyWUFGIbDZry5CYoEGQ8tyPZDxBOp2xnpVpbT15RyFM02bOmkVnZ6ftzFEsUrPDyLaYM2cO0WiUP/zhD4SCQTxeN6+88irf/va3KS4OM33GDELBIFVTpjBn1mzOPPsc2lrbaGtpYdHCRezes5vGxgYScaEYCAT8qGqOwcEBegwkXkfEtas5lXXr1uHz+2lpack7AQb8fqKxGMuXr+C+e+/l9NNP4/TTT6Ojs4NsLsvBgwdYcdpp3HrrbezYvp3BwcHCAAlg+vTp6LrOli1vEwqGqK2t5YxVZzAyLJiq11xzNe0d7cybN5+a2hpSqTQLFy7k0ksu4cjhI+zZs4dQKIjb4yEUCjG1oZFAIEBbW3uB1nx8opaiKLicLlKpJLlc1rIvffzxvzM0NEhnZyfxeIJVq87gox+9mV27drF58yZ8Xi+yotDYOJWmpukUFxfT2DCVOz97Jx+/5Rbcbg8NDQ2Ew2GrA7VHgjY3N/PE35/g4MED/OrXv+bPD/6JN15/HZfLxe133IEkS7z66quMjY3S09NDWVkZ3d09VgVudv7iEhTsWRMEmKwAmOi/m3KP8YdaNpPB6XSQyWZwud0oDif1DfUoioPu7m5GhkcMoljcOrgE+9/D8hWn0dPdzejoSKFftyxZEH1xsXA+7OjswOfz4ff7yakqiUScuGHmYi58r9drzYN9Pn9Bmlk+TUsjl82K2beBBEw20zclWaWlpZx99tls3bqVSCQixggGvwHj9waDQWKG/nUyGNfsfsXF7xBRxgZEaU+U83jcZLMZpjZOZfasOVRUlhshNWmOHjtGLBbD6/EQi8fo7u4ml83idLlwOATPwuEQtp9erxe322XNuC+5+BK+/p9f58abbqZqShVZQ9Y0OjrKL375C37wo++zdeu7Qv/v8xMKBdm3dy/xeIJ0Js1YZEx4UaRSosM2umALFTKCtuyjFXuRJSuy9YxNKD+XzRqFT9JQD2Ssw15VVcrLK4wRg9Bw7923h9aWNs4++yxrLquqKjXV1SxesphEIklrawvZbIZgIEA6kyYcKqKktIxYLGaZPMmyTCIWF4E6tbWkMylqamu59dZPsHjxYquQeWfLu7yx4XWBLhlFkDW/tclmTwX5kWxrPJ1OE4vFqKmpweN2MzQ0RGNjI4sWLcLj9ZLNZJhSPYVEKmEVsLqeH7WpqmqhJ7phfxyPxy0rZ/tI832F1RiGXZFIBFmWLe7LQH+/SHrLZNn67rs0Hz+OQ1Gob2hgw4YNNDU1cfbZZ9Pd3c3g4KDIWDD244IF8xkcGiIRj1NcXIym52fV6UyGsrIyYftuK8rHW+7av9xut+VJcDK5rnmWmK6QOTVHNBrF7XZz9tlnc9NNH8Xn87Jp0yba29sZHBrE5/Oz5vw1okAsLaWysoK62jp279nNli1v09XVbSA/Ei0tLdTX1aGpmpHlohkoUxpZlohGY2SzYrw1oYrKFkusaZqVPmuarb23wZIu8lCSCeKxuPU9pl+L3zgDRfOsUlFRwRfuuou62jp+9etfs3fvXpKpFDt27GBq41QWLFgAEoJrtGkTu/fsoqGhgZ/+7KfMnDmLjo4OBgcG+Pznv8CevXuQJZmxyBi6qhEKBYnFYoSLw3g8Ho4eO0ZLSwvJRBLF5ZDvkRVB1jv3nHN54403hNmIJHH22edwxplnsXz5Mnbu3MnQ4DCpdJLdu3aRM0gkIiDGL8hYJSVkslmGh0d59bXXWb58OceOHuUb3/w6w0MDvLVxI9VTqmlsbGDNmjUAPPHEk4DOhRdeyLPPPE08IVySUskkPT09dPf24nY7rQPYZLlKNmavGV/pdLpYtmw53V3ddHR0WG5L55x3HpdccgmJRJzXXnmNq6+5hiNHjnLLrbdyy6238pnPfIabbrqJtWvXcsmllzBj5gxjwWN1UiY0Zl6Szz37HAMDA7z55hs8+OCDHDx4SGSpSxJTpkyho6OD7du329j3KpomiHImI9Xsgj0e0UXmcjmQJlewTbbwzFlSXkIoigrzMDMJf5lshoGBAYYMz2jNgIPNA1XTNGbMmMHSZUvZvm2bFZxRMOOTxKxY18TGikYjllf+yMgIqWRSzJhVVbjRCdoxmUyGKVOmEAgE0DTVIjvZiVZmQZTJZKzUvInmqz5Dpml2XS0tgp1u8gRMcqBJdJooF9thaOvH+yqYGfUBf4BkOmU5kwnvf5fFh1i8eCEXXnQRPr9IumxqaqIoVEQoWEQmm6G9owOX00UoFMTv85JIpHC5XHjcHopLigmHw6TSaUpLyrjj9jv41n99i5kzZxrPREgwDx48wA033Mjzzz1jjdlyOZF739fXRyAYJBgIkk6lSCQSNqY5BReNcHYsVNvk0ZW8E6Ruc4MUUba6ZV1tPQtJwqHIAhlKxEmlUgSCQRyKcBfz+wPMmT2buro6MpmsFeetqioLFy7gxhtvZMH8+Qz09xMOF/GFL3yB4ZFhYTNssONFFLCTWCzG1VdfTV1dLXPnzOVjH/sYbrdH8BScDo4cPcymzW8ZLPak6NAsnbVi+Wn8MwoQVVWFlWosRkVFBaNjo7S1tlFTW8vS5csMF7z+giLXfrHLssh1MHkTZrCM0+koILzmg5QkC60yzxhssjW7VYHpaCdIoxHqjIsuk8kgKzKjI6MMDAxQXT2FqVOn8Ztf/5ojRw4LG3O3C7fbTUNDA9dddx3xWIL+vj4L4clrxQ10SNdwe9wkE6LBMC2w7V2/nRyZM9CCk3/uUkEGgR2R6+rq4tDhQ7S1tXHuueeyb/8+kgnR2L3xxhs8++yzwjBpxgzx+zSV009fSVXVFHp6uxkeGmZ4ZERYSRs5K5qmWmNkTdOtoBzz9Z7KGhHjH433s5xyuRxxg3OgWFbeQj13+ukrOd58HF2HcLiYuvo6tr77LrV1dWzYsB6Hw8FbGzcKB1pgzuzZ/OOVl9F1WLRoEb3d3cyaNZuzzz6bhYsWsmz5cj760Y+ydu1a/vTAA/iDQc4880yOHj7CnLlz8fsD+Px+9u3bx+DgoCH51FFkWb5H1TRmzZjFT376M/p7e5k3bx411dVoukZpSQnTm6ZTUlzCzBkz2b5tG7t378brdjNn3jxi8TgxY5OHi4s588yzOH78GAMD/ezauYurrrqK0pISzjjjTJYsXcrBgwf50Q9/iKrpXHzxRSxZsohYLMaU6mrhcHToIMFAgGuvvZ4jR44wNjZqRGdq1gFlzs2NN0AmI2DW2tpaZs2aRUlJKfUNjURGR5lSU82mTW/x6iuvUFNdQ29fL5UVlfzkJz9h0eLFlBr+6V6vF6/XW0DUkg2plimdkWWJjo521qw+j6GhITZt2sgbb7yB2+PF6XQQjcS47AMfIFRUxOuvv4bT6SqYSSYSCRobpyJJcO655zEyOkIymWTlylVWgpdkQ1U4hYAOu9yGfJJPgb+6JekqYNlLBvQpWZv5rLPPpnrKFDas30AsFitAeEyDFsX4uWblnMmkLR25y+UWxCFNY2rjVMbGxvJdvMHkVjWV4aHCSN7J3NYmg+nt79cM2pnIx38yXbRsyNEKWNjjbIAFi7zQgVFRZDRVJVxcTElxmHPPOZdAMISky+hozJ49m717d7N582YxcjDWTzAYxGmQZP1+P+FwmLnz5nPlB6/kW9+6hyuuuMJyB/T6vNbm/8UvfsGO7dtwuz1iRDc0TE7NGYY3WETW4ZFhMbvXRXSzQ3EU5A9IkmSNQNxud0FA1XhfexFoZUraRFhJ/jkY4yFZEfB8LmcgNSo+n4+6ujq6ursYGxPhJy+/9BI/++lPkZCorKiiuKQYt9vNvHnzuPCii1i+bAXtHe0cPXKUYCCAquaM6GXhxe7zepk/fz7/8R9fZ/68+Xh9XtAFH0TTNV559WX27N5DIpGwkCxzjCgZ0cv6Keo/pAmUIA6HIDwODQ1Zl3J3Vxc7duzA6/HQ2NjI9BkzkICRkRGrIK2sqjSKT3EuVU+ZQiQSwel0EgqFhBrEaDDsKgVzfKdqAtLXjARKyQiKGs9tMc8VM23VTC81ib6tra20NDdTWlrKggULWb58haW/P+30lfj8PlauOp0F8+dTUlzC9JkzUFWV4eFhGwlb2BpXVU7Ba4TpmMVJPqRqfC6Cdkq2igWKJzOdTlEYGR7h8OHD7Nu3l6KiIiNm3ElxcRF1tXW4XW7+8Mf7Wbx4CaWlpWSzGosWLeCGG27kg1d+kEWLFlNUFKK7p4fBwUHLnda0+A2FiozCTT/lhOhTjxSWbBL2fKFRXl6OrDhIJOKsXr2G9o52BgcHaWpqoqWlhd7eXoKhELIss2/vXutMHh0dYXh4SPz9gUF8Pi+D/QO0tLbi9XiYO28eNTU1+Hx+/vKXvxCPxVm6dCkvv/wy6HDttdcxbdo0kqk0kiT2tmTE2bucThRZdtyjqiqKQ2bL21vYtn07Pq+PcHEx2WyWH/3oh3R2dnPZZZexcuVKrrzqKl5++SVWnr6Kb/3Xt/jQhz5EKpXk4IGDDA0NWRKvXbt28sYbbzB//nwWL17M6OgodXV1nHfeaqpra9m7Zw9nnHGmsDYsLcPhEOYiL734AroOZ5x1JkVFISoqKmhqaqKisoLy8nISySTl5RVEDbg3p+ZoamrCHwgQT4j853feeYc1a87n1k98gv/+4Y8oKgpx//1/5Otf/0+amqbT1tZGR3s7jz7yKNlslpkzZ+BwOC09vSRLSLpIpTdDV+LxOC6Xiwf++EfiiQR7du/hwIEDeDxeUukUmqbz85//nN7+Pp568kmLuV4QvagoeL1eEskkFeXldLS3k81maW9vtw6Qf8a7VrFFsr4XWpCXYcmWlfCcOXOpr68nlUrx1saNVidtl0PpBTNj1eJAmGiGy+nC4XJajlyZTIbqmmp8fj+RSAQkGBsdMwqLfNKg02B9n8xpzLqg7QE97+Nr/EdhFUJmgWePe7UCewyCl1G9h4pCFBUVUVdfy7x5c1m8aBELFi6iqCiEoeBEkmDvnr20tbfhdonglEwmw7y587j88rWk0ylqamq5+ppr+PznPseFF15gzLNz9PcO8u7Wd2ltbeXJJ5/kBz/8Prt37yZgjC8ymSwVVZWkjQAREWyVtdjFbrcLp8uN0+G0Ln8T1TFto80Pw4yONv0z7IFV9oPZLlkDCUk2EDFNI5fL4vV5Bc8gm6GoqIj29nYi0RhjY2MMj4zw9FNP0dXdSUtLC80tzQSDIcNgyEEwEKS2rpaysjIWzJ/PhRddiK5pdLR3/j+1nXl8VOW5x79zZp/JZJmsBLIQFllCErQWBQQSNi+1UEGvte7i/mlv21vFpbbXz0dbta3ihrW3tq7FhRbUC8iSCGoJtCUsCokmhOzJJCHJJJlJ5sycOXP/eM85mYTYYm3zLySZzHnnfZ/3eX6/3xezWSIjI4OCKQXk509m8eJFJKcka0FC4nUOBYOcOPEpZ7q78WtOGj37X3/dkXHa0Mbm/A+KApOxbsRnJBgMIodlikpKKCycw+G//Y3GxkZiMZV5F82jdEkpHo+H7u4z2nvjIj8vn+wJ2Zw3Y6YQUZ7pxt/Xx5QpBQwODBpe+/h1r7uehNZAI4cicu914XVczDwmLdcgHJa19M6RQ9WqheYoSpTHHnucCROyeO211/D7/WRmpLP+llt59NFHeeWVV7BYLCxatISOjjbC4QjfuOwyXC6nwOCGI3i9KaR4vcy7aB5RNUpgMCASU7W0Rf2y4HA4RFE4Kozn7EPWbrczddo0Bvr74+iWMUNXYLc76Pf76ezqJCkpickFBfT393P77bfj6/Tx/PO/Zvv27cyYMYOCgnzC4QhmbSxSXFzM6tWrWb1mDXl5efj9fny+DkOgnJ2dzdSp02hvbzfGqi6Xa0Tk/pXyQ0bcJfG6qZAso0QjqDGVqKLQ0txCVmYmJSVzmT7jPF5++VVSkpPZ+OSThoZEf/5DQ0O0trbi9/uZOXMWrW2ttLW1c/V3ruHmm28C4NMTn7Ju7Vra29u49757KSycw+7duymcM4dXX32Vo0ePEg7LZGVN4EzPGXJzckWX1ev1xvR84GhUIcXrpWByASnJKUSUMM3NLSiKgtfr5b++/32uu/Za3nhjM0VzipldONvwZ+/Zu5dHHn6YmppqYjFwu1yUlpbxwI8foLBwDjFtRtXa2orXm4LD6eT0qXpmzZ6lqSpFnv0TTzzBz372CF6vl4KCAnJz88jPz2PZsuW4XC6e3LiRidmTmDw5n5defonk5GRWrFhBUmIS77z7Dnt27yIWE3ajDfdsoKSkhKXLllJRUUEwGOTGG28ipqpUV9cwbdpUXG6XIMuNemBig4hqleO7777HjBkzKC/fS0tzC/mT83jwwQcxS+KQDw4FkSQz8y+eT+XBSjEy0JGU2lz/X0nmGi/xL77QGC8hL/6mYdGElhaLhZUrL8XlcrJz506CwaBARWotQDWqYtWDJOI2U31ePlpUFjPIXjFMRDUks9PpMNLAdFBLfBymxTLSEo23/+kiJUmSjO/7d3yNxxdAMiGZJOMmY3c4yMhIx+0SiGpvSjLuBA8rVqzg+utviOsgxAgGh9izZzfle/eQlJRMaloaZaVlnH/BBXz85z8zMXsSBQX5Yo0Oy7Q1d9LQXM+2d/9EeUU5mRmZtLW1iuS+4WGtkyAO3hSvl0AgQCgU0rza4VHPxePxGMImXW+hC45GLHEjoU/xljVBtTRpYUDqGN2JeK5myaxhW4W9U+eZuwy/vrAoxtQo5503kxMnT+Cw2zRxpp/ExETWrF7DPRvuIT09HVkWbHf9Sw7JPPvss3R1d+F0uTh9uoHLLruMdWsvF+tNkohpM/6DByspLy+nsvIAn9V8TlCD7cSHHI22jprOwhT/s+skMyuL0iVL6Ozs5KOPPiYaVcjKymLlypUUFhbS1t7OH7dsISMjg+K5JcihEA2nG8mckMWxo0dpbGiIG6mMhtXEO4F0RbrZbCYjM5PurtEjh7EJ90bGwRhhYjgc5oYbbsBitYn9WVU5ePAgv3z8F6y94gqu/s7V2G02Tp48SW9vL3aHg9LSUoJDQXztHWRnZ2OWJA5XVRlFu9/vx6Fh0iORCFar1Sg6x83WwDQK5GOxWCiZW2KER8VnU+jiUKvZgknz3efm5tHW3k44LOP1erFoyYXFRcX89sUXxfhMc5AJtLIQdD7//POoapTW1jZ27NjBwMAAQ0NDJLjdpKWn09jYaKxxh90mChcNdf9VigC9eHS5nMRiMewOuxC6xmLYrDaiqsqGezawdu3l5OVPxu12sW3bNtauXUuiJxElGkVRIgL8phWt0WgUT6KH5KQkPB4Pzz3zHItLlwBCG1BWWkpvby8zZ85i41Mbefzxx9n3wQeawF0EZAEsWLAAm9XGvv37MLnc7phDE+yASIiymM0iA11VkbTDJRAIEIvFuOqqq8jJzSUwGMDucDAw0M/s2YUcqTrM0qXLiRHj5z97hNOnT/P8pk3cedddDA3L2G1WwmGZoeFhrr/mGn7zv79lUs4koz2jb/w9PT28//771NbW8sbmzfh8HVjtdiSTRHFxMT+8+7/xuBPYV7GPxORktrz1JhElQlZmJj5fJ6cbGpg7t4TZswtZvnw5LpebpUvLeOaZZ+jt6eXe++4zGMvx0B6Rc2DSvNDilmOzW9m48UkaGxpZ86013Hbb7axYsYKK8gqsVgv+/n76+vrIyMggJyeXjz/+KE74o8ale8WJrSST8fvSMzLo8/sNGM6/8lAbe3s26H/axlhcVEz+5HxOVp/kVN0pjXUv2o82mx2r1SoyuseBacQr5vWbpMksGe3gsRtmQoJbi6WURwOkTKaz4oxVVRW20TgB4L+jcDqXNp4ah9zVo3t1lLHNZmPZsmU8+vPHSE31EotpDgmTBGaoP1VPfcNp8vPymD59+qgMblkOYzHZOHrkGI/98jE+rvyQvNwcBgYGMWm3QD1ZTp/5Czy1iseTIBgZmrhJUaKYNEGp0+k0IFd6p2Qk+OTs8YgeeBTVNhlNvq0dQeKaqY89dFKhLr7UbylOp7BVCVZGgmbjDOOw24lEBeM9EomQ4EnA6XCSlpbKdddeR1lZGS5XAg6nA4fdjt1h17IXTETVKD5fp2BtTJ1qIJmjahSL1UJ1dTX333evsFH29NDa2mbsTzFiSNprH48W+UWwnHMBAOljIEWJ4vF4uPLKK8nMyuLY8WNU7N1LOBzBbrfzn1dcyY8ffBCL1cqJkyeIRqPccvPNRBSFF174DTt27GDLlreNNnF2djY9Z3oIybKRhBqv/pdMkjG60Zkk/n4/Ee3Wa5LMo1IKTaPUjibNMhnRImlTeeE3L7Br1y4q9uxl/oL5vPnWWyxYuJBIJEJ1dTXDwaBxg3e7haI8FJK/sCDSxx5+fz/DQ0NIOgApPlr4HGlL8eM44yZskpDDMklJSaSlptLU1CRyMoBFiy7hV796gpQUoauRtEI2GhWfgzfffJMN99xNLBZjcHCQ5StXkp6eSVenD0VRaGlpEYh4kx6WE6Oq6jBWiwBVjf17Tf/Amm2KS46yWqyjYG365dKiJdhu2rSJpEQPq9esIRAI8OsXXuAvhw6xbds2Y9xtkkyEZQHzkmXhzEnxpmCz2iicXcgDP36A4uJi1KjK+7t38dLvf8/nn32G39+PElUwmyVjHKW/p4keD1d9+9tceMHXMN+0fv1DNZ/VkOB2c93113H82HH6+vzGrU+P1BSpfh6qDldRWVlJVVUVn35ynEhEYfMfXsNisbJ37x4uOP98Nm3ahNvtotPnY+myZVqGu6gcHXY7q1Z9g/SM9LMfegxcbhdFRUUsXryYzMxMqqtrCA4FiRGjqamJd7a+Q0N9A5csuoSM9DTKP/iAxoYG6k/VUzBlCtOnT2fpsuVkZGby/q73Kd9bzqyZs7j00pWUlZUJypR+OErGJxtJy2pXtQ3L6XTw+muvsuGeu7n9tjv43e9/R1NTI35/n2G9MplEpyFrwgRy83JFeI4OotAWjN5aGvFyjsTiCvug8tUOK2mEMT+2hZ6UlCRuD+kZRtqeqqpcddW3WbxkMbt376Knp4f0tHTQhEW6TWaEC3F2y1S3TIlbo5moquJ2u3E4nIwFS0mShCyHx23z6xurSO2yjPj//868zWQynePUDr4U8t1kMlqmuld75AasjorFNZvNpKen8x+rvkH1yRO4nC4mTJxgCEVVRSU1PZUpU6aQmppq8DEkSWKgv5+d23ey/8MPeeKpX1BevoekpESImeg5c8aAqDQ1NRnxvELQqGpzaQvDQ+LAVWNxTHJdRGa3GejqeEXyFxVTusDVpCdRjoJFxbDZ7GCK05iYhL1JB4CF5BBWixWzxYKidR9isRhuj4dIOEJEgw/JsozHk8D0adOoqKjgwIEDHKyspKOjg+SUFCZMyBIzb23DT0xKJDVV4FKJYUQEm0wmWltbKd9bQVd3t3GjU6KiENL1Jl8mpW1scN/4qF8MEZkkiZTEo0ePGpGs/r4+EhI89PX1UV1TYwRd5Ws01KiqkpOTQ0lJMe3t7QQCAXw+H6oqPPehkDzG9SL0TZJJEjdSDZfrcrlITU0lNBwy9rJ4LcHYMJt4ZorVZiU4FGDrn7Zx949+xE3rbyY7O5tAIMBfDh0iP1+00nt7e7FarWRmZgohW3DIiK6WDN3IaBz54OAgkUiEiRMnEtVCisZGHZ+Tqylei6Pjo00xQyStqiqpaWmEwzJ2u52GhgY+Of4JXq+XwjmFWgGqGmPG88+fy7Tp53HsyDFK5s7lxKcn+KymhrS0VJqbW7Da7SQmJNDX14vP5xOwLK34/tJsEcPaql8g1LhwMYmEBDc2m53e3l5uvOEGzpw5w4sv/pa+3j4Sk5K4/bbb6OnpwZuays3r19PV1cVQMIiqiRbnzCnim99czaFDBwkNy9TV1fLKK6/wwQcfcMcddxCWZY5UHeFUfZ3hmguHIyiKSgzV0LINDw9TW1vL/AULMb/99paHvrl6NQ0NDZSXl+Pv6xs1u47PsI5oFa7NZsdms5KalobXm0J7ezvTpk9l8SWLSPQksaR0CYsXL2bhJYs0wIw0albk0rzFovWlB7eMqGKj0Sg7d+7kw/37GRoawuGw09fbh80qbtcNjQ387a9/5cjRo1oU750sWLiQ2ro6+np72bljB4mJiTQ1NPHd732PCy/8GmaLGYtlxE2gPxjBpZaMcBs9wrTy4AFuuWU9OZNymL9wIa+//jqxmEp3dw+RiACohEIhrrnmWlatWsXHH32Iz+fTSIIxI+krHtN7rqr+8RZb/AdJh6o4nU7UqJj/6r/D7XaTmZnJlIIp3HjzTeJDiInu7i7mz5/PT3/6P8ycOYN333uP+lOnjBmTUH2rxnOIV/iOBaLrqvF494CiKHg8HiZNmkRPT88orO14GQZjBTb/aK6v/7y/93P+ufBfDPZEfMCHKc4CpB/EaP8nMTGRSy9dRW1tLfX19aR4vRQVzUEOh4UAT+scKMpIcp8kSQwODFJ58ADP/3oTBw8dQA4Na2tQFeFT2kikpblFhLxEFFQ1SlSJGuJKve3v8XhEARlXbNrtNpGkqahn/R1frAkxjUrEG/ueC0eFOuKCsVgMT3xYjhi3G1XTHeiz60AgaEQQCwCPjenTp9PS2kp9/WmGQ8N0dvqoqKigtbWVC752AckpySMkPyCqaKyDQJCmpma6urs4fPgwg4MDfFb7ubFuh4aCcQXmua0Pl8slihZFGUUYPbeFMyK0PVVXR1dnJ6VlpYTkEB0dHVitZg5UVvLRR/sJBoew2ezs27ePEydPsn//PhobGimcU0iK14skmWlpbkaOcwYIV5B1FONDj7eNRqMEgwHC4bCw3SoKEUWw6602q+FU0p+d7mDRI58dDgdqNMrhqsPcf//9XHjhhRQVFREOh0lMTCTFm8Ll69YRCoWorz9FaloaihIZUdRHFaN76nI5Dc2Bvl+EhkOYpbMj5fkSriYTEIsbV+mXJkkSrqacnBxCoRBySBQB9adP0dzcRF9fH5kZmSLkJ6oimYWVePasWRQXF1NdfZKoomB3OjhSdZQOn4/uri5aWloYHh7G40nC7+/VKIbh0XvgOayLkWCkkUuS2WzGYjFjs9mYmD0Rs8VMVlYWb2x+g9WrV7Nu3RUMy8M899xz9Pb20NbWiizLNDc1kZaahiyHKJg2lYGBAa5Ytw5ZDnH82CckJLiw22zMnDmLO+64k0AwwLcuv5wjR44YDq9IRDFCv0xxe6juDtu1axfmW2+99aGenl6eemojFrOZvPw8Ojo6RmEliVNC6z5RVcNXNjc3o6oqq1at4plnn2XexRcZnkvd1hPTnqQUd7MYqVpHbh36RqW/aX/csoXmlhZkrSrTq0qdXNXc0sKnn3xCTU0NPl8HdafqmFIwjdKyMo4cqeJbl19OaWkpWVmZxpPqH+hHDoWEsjruQNEP0NTUVFRV5ZGHHyZn0iRCIRl/Xz8d7W309PQAQiEeDofJSM/gxhtv4pZb1vP0008bsywxOx6x63zRXOxcbqhjW2I6idHtduPxeEQBY7GSnJxMSclccnNzUJQIxcXFrFmzhilTppKUnMTV37mGH/7gB5QtLeOuu+6k6nAVw5p9TAcRjSfW+SIRj5GYFRdGEggEjDje+Ope35Bi/6Qta1z8qOnLv5/jqr/H6+lpONt4u5O+mSYnJ1M0p4i29nbqamsBsSkXFBSwf99+jn9ynDPd3cICaRKfkdraWiKRCFu3buXll17GYrHS398vEuw0OlxEiWCWzNjtYqwmCg/FII7Fv3cWi4VAIGCMm/R/j0QUw91xrq3us0Y7xAUiSQLBPYohoIpiRVVjZGRlgBrTQnxiI4mhShSH06Ft2GG8Xi/p6RkEg0Ha2zvEQSHL4hA2m/F6U6iprmHy5MkaWEkot+vq6mhuauKNt9/iD5s3U1tXy/6PPqS5qZnG0w10dnYatEM9FlcXlcYjzMdr0c6cNROnw6kx601fuojUtQRms1mEYTU2kpubi8PpJKwlElqtVoJDQ2zdupWpU6ZyxRXraG9rpfZUHZ9//jkpKSlcdNE8Fi1exLSp05k2bSqKohAIBHG5nIRkWSu+hM03fjRls9mERkRVcblcSJKADLmcLkAje8YVy06X04h0dzqdDAwOsn37Dny+Dg4dOsT2HTu4+OKLUYkxt3gujQ2NIrskNZVAIIBZMuN0uQSMx2Y39p4RzUjM2Ms9Hs+oXJKvps+Jr7lMGt++CyWuILbbbXR1d7P9vf+jf6Cf1WtWo8ZUw4IpyzK5ubls3vwGvX29zJ+/gCNHjhj7qb7/Dw4OYrXaKC4poaura9wugOnv5BpIJuEGcjqdxvhC7xharVbkiIjlfuD+B1h4yUJCIZkUbzIFBZN58Cc/ocvXybyvf11kqIRCNDY2sHzFCjbcswGLZGbJkiXU15/m9Ol6Lvz6PNIzMvjed79LQkICzzzzNCdOnCAxMVGMDqMK0agaZ2FEQ9VHR2kt/h/lxCWAkPP1hwAAAABJRU5ErkJggg==]]

    local function GetLogoAsset()
        local asset = nil
        pcall(function()
            if writefile and getcustomasset then
                local fn = "DayBreak_CustomLogo.png"
                if not isfile or not isfile(fn) then
                    local rawBytes = nil
                    if crypt and crypt.base64decode then
                        rawBytes = crypt.base64decode(DAYBREAK_LOGO_B64)
                    elseif base64_decode then
                        rawBytes = base64_decode(DAYBREAK_LOGO_B64)
                    elseif syn and syn.crypt and syn.crypt.base64_decode then
                        rawBytes = syn.crypt.base64_decode(DAYBREAK_LOGO_B64)
                    end
                    if rawBytes then writefile(fn, rawBytes) end
                end
                asset = getcustomasset(fn)
            end
        end)
        return asset or "https://raw.githubusercontent.com/DayyBreak69/DayBreak-Alt-Control/main/DayBreak-Alt-Control/assets/Day_Day.png"
    end

    local function GetBannerAsset()
        local asset = nil
        pcall(function()
            if writefile and getcustomasset then
                local fn = "DayBreak_CustomBanner.png"
                if not isfile or not isfile(fn) then
                    local rawBytes = nil
                    if crypt and crypt.base64decode then
                        rawBytes = crypt.base64decode(DAYBREAK_BANNER_B64)
                    elseif base64_decode then
                        rawBytes = base64_decode(DAYBREAK_BANNER_B64)
                    elseif syn and syn.crypt and syn.crypt.base64_decode then
                        rawBytes = syn.crypt.base64_decode(DAYBREAK_BANNER_B64)
                    end
                    if rawBytes then writefile(fn, rawBytes) end
                end
                asset = getcustomasset(fn)
            end
        end)
        return asset or "rbxassetid://10723415766"
    end

    ----------------------------------------------------------------
    -- COMMAND SECTIONS DEFINITIONS
    ----------------------------------------------------------------
    local SECTIONS = {
        {
            name = "Co-Host & Access Control",
            color = Color3.fromRGB(245, 158, 11),
            cmds = {
                {cmd="addhost",   desc="Grant player Co-Host privileges", al="Target", ha=true},
                {cmd="removehost",desc="Revoke Co-Host privileges",       al="Target", ha=true},
                {cmd="hosts",     desc="List all active Co-Hosts",        ha=false},
                {cmd="whitelist", desc="Whitelists player for commands",  al="[bot] Target", ha=true},
                {cmd="blacklist", desc="Blacklists player from commands", al="[bot] Target", ha=true},
            },
        },
        {
            name = "Visual Effects (VFX Suite)",
            color = Color3.fromRGB(192, 132, 252),
            cmds = {
                {cmd="vfx highlight",desc="Toggle glowing bot outlines",     ha=false},
                {cmd="vfx laser",    desc="Toggle laser grid to bots",       ha=false},
                {cmd="vfx trail",    desc="Toggle cosmic motion trails",     ha=false},
                {cmd="vfx rainbow",  desc="Toggle rainbow VFX color cycle",  ha=false},
                {cmd="vfx color purple",desc="Set VFX Palette: Purple",      ha=false},
                {cmd="vfx color cyan",  desc="Set VFX Palette: Cyan",        ha=false},
                {cmd="vfx color gold",  desc="Set VFX Palette: Gold",        ha=false},
                {cmd="vfx color red",   desc="Set VFX Palette: Red",         ha=false},
                {cmd="vfx color green", desc="Set VFX Palette: Green",       ha=false},
                {cmd="vfx color pink",  desc="Set VFX Palette: Pink",        ha=false},
                {cmd="vfx off",      desc="Disable all visual effects",      ha=false},
            },
        },
        {
            name = "Meme & Viral Troll Squad",
            color = Color3.fromRGB(244, 114, 182),
            cmds = {
                {cmd="npc",       desc="Player-seeking comedy chat engine",ha=false},
                {cmd="unnpc",     desc="Stop NPC chat loop",               ha=false},
                {cmd="bodyguard", desc="Protective outward circle",        al="Target", ha=true},
                {cmd="ritual",    desc="Cult sacrifice circle chanting",   al="Target", ha=true},
                {cmd="paparazzi", desc="Swarm target taking flash photos", al="Target", ha=true},
                {cmd="coffin",    desc="Coffin dance carry target",       al="Target", ha=true},
                {cmd="conga",     desc="Snake dance line behind leader",   al="Target", ha=true},
                {cmd="stare",     desc="Ominous 7-stud silent staring",    al="Target", ha=true},
                {cmd="unstare",   desc="Stop stare routine",               ha=false},
                {cmd="tornado",   desc="Rising vortex spin around target", al="Target", ha=true},
                {cmd="creeper",   desc="Red Light Green Light stealth",    al="Target", ha=true},
                {cmd="uncreeper", desc="Stop stealth mode",                ha=false},
            },
        },
        {
            name = "Tactical Formations",
            color = Color3.fromRGB(56, 189, 248),
            cmds = {
                {cmd="line",     desc="Linear horizontal formation",  al="Target", ha=true},
                {cmd="circle",   desc="Circular formation",           al="Target", ha=true},
                {cmd="wall",     desc="Frontal defensive barrier",    al="Target", ha=true},
                {cmd="orbit",    desc="Dynamic orbiting formation",   al="Target", ha=true},
                {cmd="box",      desc="Box enclosure formation",      al="Target", ha=true},
                {cmd="star",     desc="Star polygon formation",       al="Target", ha=true},
            },
        },
        {
            name = "Movement & Position",
            color = Color3.fromRGB(220, 230, 255),
            cmds = {
                {cmd="bring",    desc="Summons bots directly",    al="[bot] Target", ha=true},
                {cmd="goto",     desc="Teleports to player",      al="[bot] Target", ha=true},
                {cmd="follow",   desc="Follows target",           al="[bot] Target", ha=true},
                {cmd="walkto",   desc="Walks to target",          al="[bot] Target", ha=true},
                {cmd="freeze",   desc="Freezes bots in place",    ha=false},
                {cmd="unfreeze", desc="Unfreezes bots",          ha=false},
                {cmd="jump",     desc="Forces bots to jump",      ha=false},
                {cmd="sit",      desc="Forces bots to sit",       ha=false},
                {cmd="stop",     desc="Halts all active routines",ha=false},
                {cmd="unall",    desc="Complete command reset",   ha=false},
            },
        },
        {
            name = "Emotes & Animation Sync",
            color = Color3.fromRGB(244, 114, 182),
            cmds = {
                {cmd="emote",    desc="Plays catalog or UGC emote",  al="EmoteName/Id",ha=true},
                {cmd="sync",     desc="Synchronize emote across fleet",al="EmoteName/Id",ha=true},
                {cmd="dance",    desc="Standard dance emote",       ha=false},
                {cmd="dance2",   desc="Standard dance 2",           ha=false},
                {cmd="dance3",   desc="Standard dance 3",           ha=false},
                {cmd="wave",     desc="Wave emote",                 ha=false},
                {cmd="point",    desc="Point emote",                ha=false},
                {cmd="cheer",    desc="Cheer emote",                ha=false},
                {cmd="laugh",    desc="Laugh emote",                ha=false},
                {cmd="unemote",  desc="Stops all emote playback",   ha=false},
            },
        },
        {
            name = "Performance & RAM Dashboard",
            color = Color3.fromRGB(74, 222, 128),
            cmds = {
                {cmd="ram",      desc="Checks RAM usage in MB",             ha=false},
                {cmd="lowram",   desc="Ultra-low memory 3D render mode",    ha=false},
                {cmd="unlowram", desc="Restores normal visual rendering",   ha=false},
                {cmd="cleanram", desc="Forces Lua garbage collection purge",ha=false},
                {cmd="flush",    desc="Alias for cleanram purge",           ha=false},
                {cmd="altcount", desc="Counts online connected bots",       ha=false},
            },
        },
    }

    ----------------------------------------------------------------
    -- MINIMIZED FLOATING STAR KEYCHAIN ICON (Custom Logo + Halo Glow)
    ----------------------------------------------------------------
    local ICON_SIZE = 50
    local iconContainer = C("Frame",{
        Name = "DayBreakFloatingWidget",
        Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
        Position = UDim2.new(0, 16, 1, -(ICON_SIZE + 16)),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        Parent = SG,
    })
    Cn(iconContainer, UDim.new(1, 0))
    local iconGlowStroke = C("UIStroke",{
        Color = T.BorderGlow,
        Thickness = 1.8,
        Transparency = 0.2,
        Parent = iconContainer,
    })

    local iconBtn = C("ImageButton",{
        Name = "LogoImage",
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundTransparency = 1,
        Image = GetLogoAsset(),
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        Parent = iconContainer,
    })
    Cn(iconBtn, UDim.new(1, 0))
    MakeDraggable(iconContainer, iconContainer)

    -- Hover & Pulsing Starlight Glow Effect
    iconBtn.MouseEnter:Connect(function()
        Tw(iconContainer, {Size = UDim2.new(0, ICON_SIZE + 4, 0, ICON_SIZE + 4), BackgroundTransparency = 0}, 0.15)
        Tw(iconGlowStroke, {Color = Color3.fromRGB(255, 255, 255), Transparency = 0}, 0.15)
    end)
    iconBtn.MouseLeave:Connect(function()
        Tw(iconContainer, {Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE), BackgroundTransparency = 0.1}, 0.15)
        Tw(iconGlowStroke, {Color = T.BorderGlow, Transparency = 0.2}, 0.15)
    end)

    task.spawn(function()
        while _G.DayBreakActive do
            Tw(iconGlowStroke, {Transparency = 0.6}, 1.4)
            task.wait(1.4)
            Tw(iconGlowStroke, {Transparency = 0.1}, 1.4)
            task.wait(1.4)
        end
    end)

    ----------------------------------------------------------------
    -- MAIN WINDOW
    ----------------------------------------------------------------
    local WIN_W, WIN_H = 345, 530
    local MF = C("Frame",{
        Name = "MainFrame",
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -(WIN_W / 2), 0.5, -(WIN_H / 2)),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = SG,
    })
    Cn(MF, UDim.new(0, 10))
    St(MF, T.BorderDim, 1.4)
    MakeDraggable(MF, MF)

    ----------------------------------------------------------------
    -- CELESTIAL BANNER HEADER (Constellation Art + Gradients)
    ----------------------------------------------------------------
    local BANNER_H = 68
    local bannerFrame = C("Frame",{
        Size = UDim2.new(1, 0, 0, BANNER_H),
        BackgroundColor3 = T.Header,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = MF,
    })
    Cn(bannerFrame, UDim.new(0, 10))
    MakeDraggable(bannerFrame, MF)

    local bannerImg = C("ImageLabel",{
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = GetBannerAsset(),
        ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 0.18,
        BorderSizePixel = 0,
        Parent = bannerFrame,
    })

    local bannerFade = C("Frame",{
        Size = UDim2.new(1, 0, 0.5, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Parent = bannerFrame,
    })
    C("UIGradient",{
        Color = ColorSequence.new(Color3.new(1,1,1)),
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
        Rotation = 90,
        Parent = bannerFade,
    })

    local headerLine = C("Frame",{
        Size = UDim2.new(1, -16, 0, 2),
        Position = UDim2.new(0, 8, 1, -1),
        BackgroundColor3 = T.BorderGlow,
        BorderSizePixel = 0,
        Parent = bannerFrame,
    })
    C("UIGradient",{
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 80)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 80)),
        }),
        Parent = headerLine,
    })

    -- Header Controls & Title
    C("ImageLabel",{
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 10, 1, -22),
        BackgroundTransparency = 1,
        Image = "rbxassetid://10723415766",
        ImageColor3 = T.Accent,
        Parent = bannerFrame,
    })

    local Title = C("TextLabel",{
        Size = UDim2.new(0, 95, 0, 20),
        Position = UDim2.new(0, 28, 1, -25),
        BackgroundTransparency = 1,
        Text = "DAYBREAK",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bannerFrame,
    })

    C("ImageLabel",{
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 115, 1, -22),
        BackgroundTransparency = 1,
        Image = "rbxassetid://10723415766",
        ImageColor3 = T.Accent,
        Parent = bannerFrame,
    })

    local BCL = C("TextLabel",{
        Size = UDim2.new(0, 70, 0, 18),
        Position = UDim2.new(0, 142, 1, -23),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.4,
        Text = "Bots: 0",
        TextColor3 = T.Green,
        TextSize = 9,
        Font = T.FB,
        Parent = bannerFrame,
    })
    Cn(BCL, UDim.new(0, 4))
    St(BCL, T.Border, 0.8)

    local minBtn = C("TextButton",{
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -52, 0, 8),
        BackgroundColor3 = T.Header,
        BackgroundTransparency = 0.2,
        Text = "-",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = T.FB,
        Parent = bannerFrame,
    })
    Cn(minBtn, UDim.new(0, 4))
    St(minBtn, T.Border, 0.8)

    local closeBtn = C("TextButton",{
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -26, 0, 8),
        BackgroundColor3 = T.Header,
        BackgroundTransparency = 0.2,
        Text = "X",
        TextColor3 = T.Red,
        TextSize = 10,
        Font = T.FB,
        Parent = bannerFrame,
    })
    Cn(closeBtn, UDim.new(0, 4))
    St(closeBtn, T.Border, 0.8)

    ----------------------------------------------------------------
    -- SEARCH BAR
    ----------------------------------------------------------------
    local SEARCH_Y = BANNER_H + 6
    local SB = C("Frame",{
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 0, SEARCH_Y),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.3,
        Parent = MF,
    })
    Cn(SB, UDim.new(0, 6))
    St(SB, T.Border, 0.8)

    local searchBox = C("TextBox",{
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = "Search commands...",
        PlaceholderColor3 = T.Muted,
        Text = "",
        TextColor3 = T.Text,
        TextSize = 11,
        Font = T.FR,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = SB,
    })

    ----------------------------------------------------------------
    -- TAB SWITCHER BAR (Commands vs Bots & RAM Dashboard)
    ----------------------------------------------------------------
    local TAB_Y = SEARCH_Y + 32
    local tabFrame = C("Frame",{
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, TAB_Y),
        BackgroundTransparency = 1,
        Parent = MF,
    })

    local tabCmdsBtn = C("TextButton",{
        Size = UDim2.new(0.48, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = T.Elevated,
        BackgroundTransparency = 0.1,
        Text = "",
        BorderSizePixel = 0,
        Parent = tabFrame,
    })
    Cn(tabCmdsBtn, UDim.new(0, 5))
    local tabCmdsStroke = C("UIStroke",{Color = T.BorderGlow, Thickness = 1.2, Parent = tabCmdsBtn})

    local tabCmdsIcon = C("ImageLabel",{
        Size = UDim2.new(0, 13, 0, 13),
        Position = UDim2.new(0, 10, 0.5, -6.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://10723415766",
        ImageColor3 = T.Accent,
        Parent = tabCmdsBtn,
    })

    local tabCmdsLbl = C("TextLabel",{
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        BackgroundTransparency = 1,
        Text = "Commands",
        TextColor3 = T.Text,
        TextSize = 10,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tabCmdsBtn,
    })

    local tabBotsBtn = C("TextButton",{
        Size = UDim2.new(0.48, 0, 1, 0),
        Position = UDim2.new(0.52, 0, 0, 0),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.6,
        Text = "",
        BorderSizePixel = 0,
        Parent = tabFrame,
    })
    Cn(tabBotsBtn, UDim.new(0, 5))
    local tabBotsStroke = C("UIStroke",{Color = T.Border, Thickness = 0.8, Parent = tabBotsBtn})

    local tabBotsIcon = C("ImageLabel",{
        Size = UDim2.new(0, 13, 0, 13),
        Position = UDim2.new(0, 10, 0.5, -6.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://10723415766",
        ImageColor3 = T.Green,
        Parent = tabBotsBtn,
    })

    local tabBotsLbl = C("TextLabel",{
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        BackgroundTransparency = 1,
        Text = "Bots & RAM",
        TextColor3 = T.Dim,
        TextSize = 10,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tabBotsBtn,
    })

    ----------------------------------------------------------------
    -- CONTENT PAGES (Commands List & Bot / RAM Fleet Monitor)
    ----------------------------------------------------------------
    local LIST_Y = TAB_Y + 30
    local CONTENT_H = -(LIST_Y + 44)

    -- Page 1: Commands List
    local listPage = C("ScrollingFrame",{
        Name = "ListPage",
        Size = UDim2.new(1, -16, 1, CONTENT_H),
        Position = UDim2.new(0, 8, 0, LIST_Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.BorderGlow,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = true,
        Parent = MF,
    })
    C("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2),Parent=listPage})
    C("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2),Parent=listPage})

    -- Page 2: Live Bot & RAM Fleet Dashboard
    local ramPage = C("ScrollingFrame",{
        Name = "RamPage",
        Size = UDim2.new(1, -16, 1, CONTENT_H),
        Position = UDim2.new(0, 8, 0, LIST_Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Green,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = MF,
    })
    C("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4),Parent=ramPage})
    C("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2),Parent=ramPage})

    -- Tab Switching Logic
    tabCmdsBtn.MouseButton1Click:Connect(function()
        listPage.Visible = true
        ramPage.Visible = false
        tabCmdsBtn.BackgroundColor3 = T.Elevated
        tabCmdsBtn.BackgroundTransparency = 0.1
        tabCmdsBtn.TextColor3 = T.Text
        tabCmdsStroke.Color = T.BorderGlow
        tabCmdsStroke.Thickness = 1.2
        tabBotsBtn.BackgroundColor3 = T.Surface
        tabBotsBtn.BackgroundTransparency = 0.6
        tabBotsBtn.TextColor3 = T.Dim
        tabBotsStroke.Color = T.Border
        tabBotsStroke.Thickness = 0.8
    end)

    tabBotsBtn.MouseButton1Click:Connect(function()
        listPage.Visible = false
        ramPage.Visible = true
        tabBotsBtn.BackgroundColor3 = T.Elevated
        tabBotsBtn.BackgroundTransparency = 0.1
        tabBotsBtn.TextColor3 = T.Text
        tabBotsStroke.Color = T.BorderGlow
        tabBotsStroke.Thickness = 1.2
        tabCmdsBtn.BackgroundColor3 = T.Surface
        tabCmdsBtn.BackgroundTransparency = 0.6
        tabCmdsBtn.TextColor3 = T.Dim
        tabCmdsStroke.Color = T.Border
        tabCmdsStroke.Thickness = 0.8
    end)

    -- Ram Page Summary Header Card
    local ramSummaryCard = C("Frame",{
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = 0,
        Parent = ramPage,
    })
    Cn(ramSummaryCard, UDim.new(0, 6))
    St(ramSummaryCard, T.Border, 0.8)

    local ramSummaryLbl = C("TextLabel",{
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "Fleet: Calculating...",
        TextColor3 = T.Text,
        TextSize = 10,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ramSummaryCard,
    })

    local cleanAllQuickBtn = C("TextButton",{
        Size = UDim2.new(0.2, -4, 0, 22),
        Position = UDim2.new(0.56, 0, 0.5, -11),
        BackgroundColor3 = T.Green,
        BackgroundTransparency = 0.4,
        Text = "Flush RAM",
        TextColor3 = Color3.new(1,1,1),
        TextSize = 9,
        Font = T.FM,
        BorderSizePixel = 0,
        Parent = ramSummaryCard,
    })
    Cn(cleanAllQuickBtn, UDim.new(0, 4))
    cleanAllQuickBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "cleanram")
        Tw(cleanAllQuickBtn, {BackgroundTransparency = 0.1}, 0.1)
        task.delay(0.25, function() Tw(cleanAllQuickBtn, {BackgroundTransparency = 0.4}, 0.2) end)
    end)

    local lowRamQuickBtn = C("TextButton",{
        Size = UDim2.new(0.22, -4, 0, 22),
        Position = UDim2.new(0.77, 0, 0.5, -11),
        BackgroundColor3 = T.Yellow,
        BackgroundTransparency = 0.5,
        Text = "Low-RAM",
        TextColor3 = Color3.new(1,1,1),
        TextSize = 9,
        Font = T.FM,
        BorderSizePixel = 0,
        Parent = ramSummaryCard,
    })
    Cn(lowRamQuickBtn, UDim.new(0, 4))
    lowRamQuickBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "lowram")
        Tw(lowRamQuickBtn, {BackgroundTransparency = 0.2}, 0.1)
        task.delay(0.25, function() Tw(lowRamQuickBtn, {BackgroundTransparency = 0.5}, 0.2) end)
    end)

    local botCardsContainer = C("Frame",{
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = ramPage,
    })
    C("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3),Parent=botCardsContainer})

    local function RefreshRamMonitor()
        for _, ch in ipairs(botCardsContainer:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end

        local bots = GetOnlineBotNames()
        local totalMem = 0
        local activeBotCount = 0

        local myCount = collectgarbage("count")
        local myMemVal = math.floor((myCount / 1024) * 10) / 10
        local myMem = string.format("%.1f MB", myMemVal)
        LocalPlayer:SetAttribute("DayBreakRAM", myMem)
        LocalPlayer:SetAttribute("DayBreakRAMVal", myMemVal)

        -- Host Controller Card
        local myCard = C("Frame",{
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = T.Elevated,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            LayoutOrder = 0,
            Parent = botCardsContainer,
        })
        Cn(myCard, UDim.new(0, 5))
        St(myCard, T.BorderGlow, 0.7)

        local myDot = C("Frame",{
            Size = UDim2.new(0, 8, 0, 8),
            Position = UDim2.new(0, 8, 0.5, -4),
            BackgroundColor3 = T.Cyan,
            BorderSizePixel = 0,
            Parent = myCard,
        })
        Cn(myDot, UDim.new(1, 0))

        C("TextLabel",{
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            Text = "HOST: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
            TextColor3 = T.Text,
            TextSize = 10,
            Font = T.FB,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = myCard,
        })

        C("TextLabel",{
            Size = UDim2.new(0.4, -8, 1, 0),
            Position = UDim2.new(0.6, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = myMem .. " | Controller",
            TextColor3 = T.Dim,
            TextSize = 9,
            Font = T.FR,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = myCard,
        })

        -- Connected Alt Bot Cards
        for i, bName in ipairs(bots) do
            local targetPlayer = Players:FindFirstChild(bName)
            if targetPlayer and targetPlayer ~= LocalPlayer then
                activeBotCount = activeBotCount + 1
                local bRamStr = tostring(targetPlayer:GetAttribute("DayBreakRAM") or "-- MB")
                local bRamVal = tonumber(targetPlayer:GetAttribute("DayBreakRAMVal")) or 0
                totalMem = totalMem + bRamVal

                local bCard = C("Frame",{
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = T.Surface,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    LayoutOrder = i,
                    Parent = botCardsContainer,
                })
                Cn(bCard, UDim.new(0, 5))
                St(bCard, T.Border, 0.9)

                local bDot = C("Frame",{
                    Size = UDim2.new(0, 7, 0, 7),
                    Position = UDim2.new(0, 8, 0.5, -3.5),
                    BackgroundColor3 = T.Green,
                    BorderSizePixel = 0,
                    Parent = bCard,
                })
                Cn(bDot, UDim.new(1, 0))

                C("TextLabel",{
                    Size = UDim2.new(0.5, 0, 1, 0),
                    Position = UDim2.new(0, 22, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "#" .. i .. " " .. targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")",
                    TextColor3 = T.Text,
                    TextSize = 10,
                    Font = T.FM,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = bCard,
                })

                C("TextLabel",{
                    Size = UDim2.new(0.4, -8, 1, 0),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = bRamStr .. " | Connected",
                    TextColor3 = T.Dim,
                    TextSize = 9,
                    Font = T.FR,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = bCard,
                })
            end
        end

        ramSummaryLbl.Text = string.format("Fleet: %d Alts Connected | %s MB", activeBotCount, string.format("%.1f", totalMem))
    end

    -- Build Command Rows
    local allRows = {}
    for secIdx, sec in ipairs(SECTIONS) do
        local secHeader = C("Frame",{
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = (secIdx * 100),
            Parent = listPage,
        })

        local secDot = C("Frame",{
            Size = UDim2.new(0, 6, 0, 6),
            Position = UDim2.new(0, 4, 0.5, -3),
            BackgroundColor3 = sec.color,
            BorderSizePixel = 0,
            Parent = secHeader,
        })
        Cn(secDot, UDim.new(1, 0))

        C("TextLabel",{
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 16, 0, 0),
            BackgroundTransparency = 1,
            Text = string.upper(sec.name),
            TextColor3 = sec.color,
            TextSize = 9,
            Font = T.FB,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = secHeader,
        })

        for cmdIdx, item in ipairs(sec.cmds) do
            local cmdRow = C("Frame",{
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = T.Surface,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                LayoutOrder = (secIdx * 100) + cmdIdx,
                Parent = listPage,
            })
            Cn(cmdRow, UDim.new(0, 5))
            St(cmdRow, T.Border, 0.9)

            local execBtn = C("TextButton",{
                Size = UDim2.new(item.ha and 0.5 or 0.95, 0, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                BackgroundTransparency = 1,
                Text = "",
                Parent = cmdRow,
            })

            C("TextLabel",{
                Size = UDim2.new(0.45, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = getgenv().Settings.prefix .. item.cmd,
                TextColor3 = T.Accent,
                TextSize = 10,
                Font = T.FB,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = execBtn,
            })

            C("TextLabel",{
                Size = UDim2.new(0.55, 0, 1, 0),
                Position = UDim2.new(0.45, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = item.desc,
                TextColor3 = T.Dim,
                TextSize = 8.5,
                Font = T.FR,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = execBtn,
            })

            local argBox = nil
            if item.ha then
                argBox = C("TextBox",{
                    Size = UDim2.new(0.42, 0, 0, 20),
                    Position = UDim2.new(0.56, 0, 0.5, -10),
                    BackgroundColor3 = T.Elevated,
                    BackgroundTransparency = 0.3,
                    PlaceholderText = item.al or "Target",
                    PlaceholderColor3 = T.Muted,
                    Text = "",
                    TextColor3 = T.Text,
                    TextSize = 9,
                    Font = T.FR,
                    ClearTextOnFocus = false,
                    Parent = cmdRow,
                })
                Cn(argBox, UDim.new(0, 4))
            end

            execBtn.MouseButton1Click:Connect(function()
                local fullCmd = getgenv().Settings.prefix .. item.cmd
                if argBox and argBox.Text ~= "" then
                    fullCmd = fullCmd .. " " .. argBox.Text
                end
                ChatSend(fullCmd)
                Tw(cmdRow, {BackgroundColor3 = T.BorderGlow, BackgroundTransparency = 0.2}, 0.1)
                task.delay(0.2, function() Tw(cmdRow, {BackgroundColor3 = T.Surface, BackgroundTransparency = 0.5}, 0.2) end)
            end)

            table.insert(allRows, {
                row = cmdRow,
                header = secHeader,
                text = (item.cmd .. " " .. item.desc):lower(),
            })
        end
    end

    -- Search Filter Logic
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = searchBox.Text:lower():gsub("%s+", "")
        for _, entry in ipairs(allRows) do
            if entry.row then
                if q == "" then
                    entry.row.Visible = true
                    if entry.header then entry.header.Visible = true end
                else
                    local match = (entry.text:find(q, 1, true) ~= nil)
                    entry.row.Visible = match
                    if entry.header then entry.header.Visible = true end
                end
            end
        end
    end)

    -- Bottom Global Stop Button
    local STOP_H = 34
    local stopFrame = C("Frame",{
        Size = UDim2.new(1, -16, 0, STOP_H),
        Position = UDim2.new(0, 8, 1, -(STOP_H + 8)),
        BackgroundTransparency = 1,
        Parent = MF,
    })

    local stopBtn = C("TextButton",{
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Red,
        BackgroundTransparency = 0.3,
        Text = "STOP ALL ACTIONS",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11,
        Font = T.FB,
        Parent = stopFrame,
    })
    Cn(stopBtn, UDim.new(0, 6))

    stopBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "stop")
        Tw(stopBtn, {BackgroundTransparency = 0.05}, 0.1)
        task.delay(0.25, function() Tw(stopBtn, {BackgroundTransparency = 0.3}, 0.2) end)
    end)

    -- Minimize and Restore Logic
    local function MinimizeGUI()
        MF.Visible = false
        iconContainer.Visible = true
    end

    local function RestoreGUI()
        MF.Visible = true
        iconContainer.Visible = false
    end

    minBtn.MouseButton1Click:Connect(MinimizeGUI)
    closeBtn.MouseButton1Click:Connect(MinimizeGUI)
    iconBtn.MouseButton1Click:Connect(RestoreGUI)

    UIS.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.RightShift or (getgenv().Settings and inp.KeyCode == getgenv().Settings.uiKeybind) then
            if MF.Visible then
                MinimizeGUI()
            else
                RestoreGUI()
            end
        end
    end)

    -- Periodic Bot Cache and Fleet RAM update loop
    task.spawn(function()
        while task.wait(1.5) do
            RefreshBotCache()
            if BCL and BCL.Parent then
                BCL.Text = "Bots: " .. _bc.total
            end
            if ramPage.Visible then
                pcall(RefreshRamMonitor)
            end
        end
    end)
end

----------------------------------------------------------------
-- 18. INITIALIZE
----------------------------------------------------------------
InitAntiAFK()

if isAltAccount and not isMainAccount then
    task.spawn(function()
        local idx = SafeIndex() or 1
        local total = math.max(1, _bc.total)
        task.wait(1.5 + ((idx - 1) * 0.2))
        ChatSend(string.format("[DayBreak] Bot #%d/%d Online & Ready", idx, total))
    end)
end

print("[DayBreak] Alt Control Initialized Successfully | Celestial Starlight Noir Edition")
