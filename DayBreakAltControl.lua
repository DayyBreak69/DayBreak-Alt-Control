-- =================================================================
--          DAYBREAK ALT CONTROL - NOCTURNAL STARLIGHT
--                   DEVELOPED BY DAYBREAK
--              DISCORD: discord.gg/ws5Zb2EzYA
--     PERMANENT CREATOR WHITELIST | DUAL-TAB RAM DASHBOARD
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
    theme = _userSettings.theme or "Dark",
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
-- 17. MAIN ACCOUNT COMMAND GUI (Dual-Tab Nocturnal Starlight)
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

    local T = {
        Bg         = Color3.fromRGB(13, 15, 24),
        Header     = Color3.fromRGB(18, 20, 32),
        Surface    = Color3.fromRGB(22, 26, 42),
        Elevated   = Color3.fromRGB(28, 34, 56),
        Border     = Color3.fromRGB(45, 55, 85),
        BorderGlow = Color3.fromRGB(99, 102, 241),
        Accent     = Color3.fromRGB(129, 140, 248),
        Text       = Color3.fromRGB(241, 245, 249),
        Dim        = Color3.fromRGB(148, 163, 184),
        Muted      = Color3.fromRGB(71, 85, 105),
        Green      = Color3.fromRGB(52, 211, 153),
        Red        = Color3.fromRGB(248, 113, 113),
        Yellow     = Color3.fromRGB(251, 191, 36),
        Cyan       = Color3.fromRGB(34, 211, 238),
        Purple     = Color3.fromRGB(168, 85, 247),
        Pink       = Color3.fromRGB(244, 114, 182),
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

    -- Embedded Assets
    local STAR_LOGO_B64 = ""
    local BANNER_IMAGE_B64 = ""

    local starLogoAsset = "rbxassetid://10723415766"
    if STAR_LOGO_B64 ~= "" and getcustomasset and writefile then
        pcall(function()
            local raw = syn and syn.crypt and syn.crypt.base64.decode(STAR_LOGO_B64) or crypt and crypt.base64decode(STAR_LOGO_B64)
            if raw then
                writefile("daybreak_logo.png", raw)
                starLogoAsset = getcustomasset("daybreak_logo.png")
            end
        end)
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
            color = Color3.fromRGB(160, 100, 255),
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
            color = Color3.fromRGB(255, 105, 180),
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
            color = Color3.fromRGB(120, 180, 255),
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
    -- MINIMIZED ICON
    ----------------------------------------------------------------
    local ICON_SIZE = 44
    local iconBtn = C("ImageButton",{
        Name = "DayBreakIcon",
        Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
        Position = UDim2.new(0, 14, 1, -(ICON_SIZE + 14)),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0.2,
        Image = starLogoAsset,
        ImageColor3 = T.Accent,
        Visible = false,
        Parent = SG,
    })
    Cn(iconBtn, UDim.new(1, 0))
    St(iconBtn, T.BorderGlow, 1.5)
    MakeDraggable(iconBtn, iconBtn)

    ----------------------------------------------------------------
    -- MAIN WINDOW
    ----------------------------------------------------------------
    local WIN_W, WIN_H = 340, 520
    local MF = C("Frame",{
        Name = "MainFrame",
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -(WIN_W / 2), 0.5, -(WIN_H / 2)),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = SG,
    })
    Cn(MF, UDim.new(0, 10))
    St(MF, T.BorderGlow, 1.2)
    MakeDraggable(MF, MF)

    ----------------------------------------------------------------
    -- TITLE BAR & FLEET COUNTER
    ----------------------------------------------------------------
    local TITLE_H = 42
    local TB = C("Frame",{
        Size = UDim2.new(1, 0, 0, TITLE_H),
        BackgroundColor3 = T.Header,
        BorderSizePixel = 0,
        Parent = MF,
    })
    Cn(TB, UDim.new(0, 10))
    MakeDraggable(TB, MF)

    local Title = C("TextLabel",{
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "DAYBREAK",
        TextColor3 = T.Accent,
        TextSize = 13,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TB,
    })

    local BCL = C("TextLabel",{
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.42, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "Bots: 0",
        TextColor3 = T.Green,
        TextSize = 10,
        Font = T.FM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TB,
    })

    local minBtn = C("TextButton",{
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -54, 0.5, -12),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.4,
        Text = "-",
        TextColor3 = T.Dim,
        TextSize = 12,
        Font = T.FB,
        Parent = TB,
    })
    Cn(minBtn, UDim.new(0, 4))

    local closeBtn = C("TextButton",{
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -28, 0.5, -12),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.4,
        Text = "X",
        TextColor3 = T.Red,
        TextSize = 10,
        Font = T.FB,
        Parent = TB,
    })
    Cn(closeBtn, UDim.new(0, 4))

    ----------------------------------------------------------------
    -- SEARCH BAR
    ----------------------------------------------------------------
    local SEARCH_Y = TITLE_H + 6
    local SB = C("Frame",{
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 0, SEARCH_Y),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.2,
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
        BackgroundColor3 = T.BorderGlow,
        BackgroundTransparency = 0.2,
        Text = "Commands",
        TextColor3 = T.Text,
        TextSize = 11,
        Font = T.FB,
        BorderSizePixel = 0,
        Parent = tabFrame,
    })
    Cn(tabCmdsBtn, UDim.new(0, 5))

    local tabBotsBtn = C("TextButton",{
        Size = UDim2.new(0.48, 0, 1, 0),
        Position = UDim2.new(0.52, 0, 0, 0),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.6,
        Text = "Bots & RAM",
        TextColor3 = T.Dim,
        TextSize = 11,
        Font = T.FB,
        BorderSizePixel = 0,
        Parent = tabFrame,
    })
    Cn(tabBotsBtn, UDim.new(0, 5))

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
        tabCmdsBtn.BackgroundColor3 = T.BorderGlow
        tabCmdsBtn.BackgroundTransparency = 0.2
        tabCmdsBtn.TextColor3 = T.Text
        tabBotsBtn.BackgroundColor3 = T.Surface
        tabBotsBtn.BackgroundTransparency = 0.6
        tabBotsBtn.TextColor3 = T.Dim
    end)

    tabBotsBtn.MouseButton1Click:Connect(function()
        listPage.Visible = false
        ramPage.Visible = true
        tabBotsBtn.BackgroundColor3 = T.BorderGlow
        tabBotsBtn.BackgroundTransparency = 0.2
        tabBotsBtn.TextColor3 = T.Text
        tabCmdsBtn.BackgroundColor3 = T.Surface
        tabCmdsBtn.BackgroundTransparency = 0.6
        tabCmdsBtn.TextColor3 = T.Dim
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
        iconBtn.Visible = true
    end

    local function RestoreGUI()
        MF.Visible = true
        iconBtn.Visible = false
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

print("[DayBreak] Alt Control Initialized Successfully | Nocturnal Starlight Edition")
