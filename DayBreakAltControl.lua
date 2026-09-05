--[[
  ██████╗  █████╗ ██╗   ██╗██████╗ ██████╗ ███████╗ █████╗ ██╗  ██╗
  ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██║ ██╔╝
  ██║  ██║███████║ ╚████╔╝ ██████╔╝██████╔╝█████╗  ███████║█████╔╝ 
  ██║  ██║██╔══██║  ╚██╔╝  ██╔══██╗██╔══██╗██╔══╝  ██╔══██║██╔═██╗ 
  ██████╔╝██║  ██║   ██║   ██████╔╝██║  ██║███████╗██║  ██║██║  ██╗
  ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
                    A L T   C O N T R O L
  
  -------------------------------------------------------------------
  >> DEVELOPED BY: DayBreak
  >> VERSION: 1.0.0
  >> STATUS: Active & Undetected
  -------------------------------------------------------------------
--]]

----------------------------------------------------------------
-- 1. CONFIGURATION
-- Seamlessly preserves user settings provided before loadstring!
----------------------------------------------------------------
local userSettings = getgenv().Settings or {}

local defaultSettings = {
    -- ALT CONTROL
    prefix              = "!",
    mainAccount         = "DayBreak",
    fpsCap              = 10,
    altAccounts         = {},

    -- MUSIC BOT
    musicPrefix         = "/",
    musicBotAccount     = "",
    musicServerURL      = "http://127.0.0.1:5000",
    musicApiKey         = "",
    musicGlobalCooldown = 3,
    musicPlayCooldown   = 10,
    musicEnableQueue    = true,
    musicEnableStats    = true,
    musicEnableVolume   = true,

    -- ANNOUNCEMENTS
    announceOnLoad      = true,

    -- LOW RAM & PERFORMANCE
    lowRamMode          = false,

    -- VC BAN DETECTION
    vcbTimerSeconds     = 360,
    vcbAutoRejoin       = true,
    vcbCheckInterval    = 5,
    vcbChatDelay        = 0.3,

    -- MIC TOGGLE
    micUnmuteDelay      = 30,
    micAutoUnmute       = true,
    micPostRejoinDelay  = 10,

    -- REJOIN & TELEPORT
    rejoinDelay         = 10,
    scriptFile          = "DayBreakAltControl.lua",
    scriptLoadstring    = ""
}

for k, v in pairs(defaultSettings) do
    if userSettings[k] == nil then
        userSettings[k] = v
    end
end
getgenv().Settings = userSettings

-- 0. RE-EXECUTION CLEANUP
----------------------------------------------------------------
if _G.DayBreakCleanup then
    pcall(_G.DayBreakCleanup)
    task.wait(0.3)
end
_G.DayBreakActive     = true
_G.DayBreakCurrentRun = tick()
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
-- 2. SERVICES
----------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local TextChatService   = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer
local isMainAccount     = (LocalPlayer.Name:lower() == getgenv().Settings.mainAccount:lower())
local isAltAccount      = false

do
    local n = LocalPlayer.Name:lower()
    for a in pairs(getgenv().Settings.altAccounts) do
        if a:lower() == n then isAltAccount = true; break end
    end
end

----------------------------------------------------------------
-- 3. DYNAMIC BOT INDEXING (Unlimited, Case-Insensitive)
----------------------------------------------------------------
local _bc = { list = {}, map = {}, total = 0, lastUpdate = 0 }

local function RefreshBotCache()
    local now = tick()
    if now - _bc.lastUpdate < 2 then return end
    _bc.lastUpdate = now
    local am, online = getgenv().Settings.altAccounts, {}
    for _, p in ipairs(Players:GetPlayers()) do
        local nl = p.Name:lower()
        for a in pairs(am) do
            if a:lower() == nl then table.insert(online, nl); break end
        end
    end
    table.sort(online)
    local m = {}
    for i, n in ipairs(online) do m[n] = i end
    _bc.list, _bc.map, _bc.total = online, m, #online
end

local function MyIndex()
    RefreshBotCache()
    return _bc.map[LocalPlayer.Name:lower()] or 0
end

local function TotalBots()
    RefreshBotCache()
    return _bc.total
end

local function GetOnlineBotNames()
    RefreshBotCache()
    return _bc.list
end

local function SafeIndex()
    local i = MyIndex()
    if i > 0 then return i end
    -- Fallback to saved position from last session (before all bots load in)
    if _G.SavedBotPosition and _G.SavedBotPosition > 0 then return _G.SavedBotPosition end
    return 1
end

local function SafeTotal()
    local t = TotalBots(); return t > 0 and t or 1
end

-- Save current position to workspace file (called before rejoin)
local function SaveBotPosition()
    pcall(function()
        local posFile = "DayBreakPos_" .. LocalPlayer.Name .. ".txt"
        writefile(posFile, tostring(SafeIndex()))
    end)
end

----------------------------------------------------------------
-- 4. DATA INITIALIZATION & CREATOR WHITELIST
----------------------------------------------------------------
-- Creator / Developer Accounts (Immune to blacklist, always recognized)
local CREATOR_ACCOUNTS = {
    ["daybreak"] = true,
}

getgenv().ManualWhitelist = getgenv().ManualWhitelist or {}
getgenv().ManualWhitelist[getgenv().Settings.mainAccount:lower()] = true
for cName in pairs(CREATOR_ACCOUNTS) do
    getgenv().ManualWhitelist[cName] = true
end

local function IsCreator(name)
    if not name then return false end
    return CREATOR_ACCOUNTS[name:lower()] == true
end

local function IsWhitelisted(name)
    if not name then return false end
    local nl = name:lower()
    if IsCreator(nl) then return true end
    if getgenv().Settings and getgenv().Settings.mainAccount and getgenv().Settings.mainAccount:lower() == nl then
        return true
    end
    if getgenv().ManualWhitelist and getgenv().ManualWhitelist[nl] then
        return true
    end
    return false
end

----------------------------------------------------------------
-- 5. CHAT DISPATCHER
----------------------------------------------------------------
local _lastChatText = nil
local _lastChatTime = 0
local function ChatSend(text)
    local now = os.clock()
    -- Drop rapid duplicate messages sent within 0.4s
    if text == _lastChatText and (now - _lastChatTime) < 0.4 then
        return
    end
    _lastChatText = text
    _lastChatTime = now
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
            continue
        end
        doMicToggle()
        task.wait(0.5)
        if not isMicMuted() then return end -- Success
        task.wait(1) -- Wait before retry
    end
    warn("[MicToggle] Failed to unmute after 3 attempts")
end

----------------------------------------------------------------
-- 5c. VCB DETECTION ENGINE
-- Monitors CoreGui for toggle_mic_mute existence.
-- When it disappears = VC banned.
----------------------------------------------------------------
_G.VCBDetected = false
_G.VCBTimerActive = false

local function isVCBanned()
    local micFrame = findMicFrame()
    return micFrame == nil
end

----------------------------------------------------------------
-- 5d. REJOIN & TELEPORT ENGINE
-- Saves CFrame, queues teleport script, rejoins same server.
----------------------------------------------------------------
local function doRejoinTP()
    -- Save bot position before rejoin so it remembers on re-execution
    SaveBotPosition()

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = hrp.CFrame:GetComponents()

    local teleportCode = string.format([[
        local targetCFrame = CFrame.new(%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f)
        local Players = game:GetService("Players")
        local LP = Players.LocalPlayer
        local function tpChar(char)
            local hrp = char:WaitForChild("HumanoidRootPart", 15)
            if hrp then task.wait(0.5); hrp.CFrame = targetCFrame end
        end
        if LP.Character then tpChar(LP.Character) end
        LP.CharacterAdded:Connect(tpChar)
    ]], x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)

    local qot = queue_on_teleport or (syn and syn.queue_on_teleport) or queueonteleport
    if qot then
        -- 1) Queue TP-back (runs first on next server)
        qot(teleportCode)

        -- 2) Queue full script re-execution from workspace (not autoexec)
        local scriptURL = getgenv().Settings.scriptLoadstring or ""
        local scriptFile = getgenv().Settings.scriptFile or ""
        if scriptFile ~= "" then
            -- Workspace readfile approach (works on Xeno, Solara, etc.)
            local reExecCode = 'task.wait(3); pcall(function() loadstring(readfile("' .. scriptFile .. '"))() end)'
            qot(reExecCode)
        elseif scriptURL ~= "" then
            -- URL fallback approach
            local reExecCode = 'task.wait(3); pcall(function() loadstring(game:HttpGet("' .. scriptURL .. '"))() end)'
            qot(reExecCode)
        end
    end

    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

----------------------------------------------------------------
-- 5e. VCB MONITOR (runs in background for alt accounts)
-- Detects VC ban, runs countdown, auto-rejoin + TP + unmute
----------------------------------------------------------------
local function StartVCBMonitor()
    if isMainAccount then return end -- Only bots monitor
    if not isAltAccount then return end

    task.spawn(function()
        -- Wait for TopBarApp to load
        task.wait(10)

        while _G.DayBreakActive do
            task.wait(getgenv().Settings.vcbCheckInterval or 5)

            -- Check if mic button disappeared (VC banned)
            if not _G.VCBDetected and isVCBanned() then
                _G.VCBDetected = true
                _G.VCBTimerActive = true

                local totalTime = getgenv().Settings.vcbTimerSeconds or 360
                local chatDelay = getgenv().Settings.vcbChatDelay or 0.3
                local idx = SafeIndex()

                -- Announce VCB detected
                task.wait(idx * chatDelay)
                ChatSend("VCB Detected💀")
                task.wait(1)
                ChatSend("Timer started - " .. math.floor(totalTime / 60) .. "min ⏳")

                -- Countdown
                local elapsed = 0
                local sent3min = false
                local sent1min = false

                while elapsed < totalTime and _G.VCBTimerActive do
                    task.wait(1)
                    elapsed = elapsed + 1
                    local remaining = totalTime - elapsed

                    -- 3 minutes left
                    if remaining <= 180 and remaining > 179 and not sent3min then
                        sent3min = true
                        task.wait(idx * chatDelay)
                        ChatSend("3min left ⌛")
                    end

                    -- 1 minute left
                    if remaining <= 60 and remaining > 59 and not sent1min then
                        sent1min = true
                        task.wait(idx * chatDelay)
                        ChatSend("Rejoining in 1min...")
                    end
                end

                if _G.VCBTimerActive then
                    -- Timer ended
                    task.wait(idx * chatDelay)
                    ChatSend("Unbanned 😼")
                    task.wait(1)
                    ChatSend("Rejoining...")

                    -- Wait before rejoin
                    task.wait(getgenv().Settings.rejoinDelay or 10)

                    if getgenv().Settings.vcbAutoRejoin then
                        doRejoinTP()
                    end
                end

                _G.VCBTimerActive = false
            end
        end
    end)
end

----------------------------------------------------------------
-- 5f. MUSIC BOT ENGINE (merged from MusicBots.lua)
----------------------------------------------------------------
local MusicState = {
    lastCommandTime = {},
    lastPlayTime = {},
}

local function isMusicDesignatedBot()
    return LocalPlayer.Name == getgenv().Settings.musicBotAccount
end

local function shouldMusicExecute()
    -- Only the designated music bot makes HTTP requests
    if isMusicDesignatedBot() then return true end
    -- If designated bot is offline, first available bot handles it
    if not Players:FindFirstChild(getgenv().Settings.musicBotAccount) then
        RefreshBotCache()
        return #_bc.list > 0 and _bc.list[1] == LocalPlayer.Name:lower()
    end
    return false
end

local function musicChat(message)
    if shouldMusicExecute() then
        task.spawn(function()
            ChatSend(message)
        end)
    end
end

local function musicRequest(endpoint, params)
    if not shouldMusicExecute() then return nil end
    params = params or {}
    local url = getgenv().Settings.musicServerURL .. endpoint
    local qp = {}
    for k, v in pairs(params) do
        table.insert(qp, k .. "=" .. HttpService:UrlEncode(tostring(v)))
    end
    if #qp > 0 then url = url .. "?" .. table.concat(qp, "&") end

    local req = (syn and syn.request) or http_request or request
    if not req then return nil end

    for attempt = 1, 3 do
        local ok, resp = pcall(function()
            return req({
                Url = url, Method = "GET",
                Headers = {
                    ["X-API-Key"] = getgenv().Settings.musicApiKey,
                    ["Content-Type"] = "application/json"
                }
            })
        end)
        if ok then
            if resp.StatusCode == 401 then musicChat("❌ API key error"); return nil end
            if resp.StatusCode >= 200 and resp.StatusCode < 500 then
                local pOk, data = pcall(function() return HttpService:JSONDecode(resp.Body) end)
                if pOk then return data end
            end
        end
        if attempt < 3 then task.wait(2 * attempt) end
    end
    return nil
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
    if _G.ActiveLaserBeam then pcall(function() _G.ActiveLaserBeam:Destroy() end); _G.ActiveLaserBeam = nil end
    if _G.ActiveLaserAtt0 then pcall(function() _G.ActiveLaserAtt0:Destroy() end); _G.ActiveLaserAtt0 = nil end
    if _G.ActiveLaserAtt1 then pcall(function() _G.ActiveLaserAtt1:Destroy() end); _G.ActiveLaserAtt1 = nil end

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
-- 12. COMMAND TABLE
----------------------------------------------------------------
local Commands = {}

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
    if t then
        local targetLower = t.Name:lower()
        if IsCreator(targetLower) then
            if SafeIndex() == 1 then ChatSend("Cannot blacklist Creator") end
            return
        end
        if targetLower ~= getgenv().Settings.mainAccount:lower() then
            getgenv().ManualWhitelist[targetLower] = nil
            if SafeIndex() == 1 then ChatSend("Blacklisted " .. t.Name) end
        end
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
                repeat task.wait(0.1); t += 0.1 until done or _G.CurrentCommand ~= "Wonder" or t > 10
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
    StopAll()
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
    StopAll()
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
    StopAll()
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
    StopAll()
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

Commands.emote = function(args, speaker)
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

    -- If already emoting, jump first then play the new emote (clean transition)
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

    -- Stop all currently playing action tracks cleanly
    for _, tr in pairs(anim:GetPlayingAnimationTracks()) do
         if tr.Priority == Enum.AnimationPriority.Action then
             pcall(function() tr:Stop(0) end)
         end
    end

    local function playAction()
        if _G.CurrentEmoteCommand ~= targetId then return end
        -- Stop previous tracked emote to prevent stacking
        StopCurrentEmoteTrack()
        local ok, track = pcall(function() return hum:PlayEmoteAndGetAnimTrackById(targetId) end)
        if ok and track and typeof(track) == "Instance" and track:IsA("AnimationTrack") then
            _G.CurrentEmoteTrack = track
            track.Priority = Enum.AnimationPriority.Action
            track:Play()
            return
        end
        local obj = Instance.new("Animation")
        obj.AnimationId = "rbxassetid://" .. tostring(targetId)
        local ok2, tr = pcall(function() return anim:LoadAnimation(obj) end)
        if ok2 and tr then
            _G.CurrentEmoteTrack = tr
            tr.Priority = Enum.AnimationPriority.Action
            tr.Looped = true
            tr:Play()
        end
    end

    playAction()

    if _G.EmoteFreezeConn then _G.EmoteFreezeConn:Disconnect() end
    local sTarget = tostring(targetId)
    _G.EmoteFreezeConn = anim.AnimationPlayed:Connect(function(atr)
        if _G.CurrentEmoteCommand ~= targetId then 
            if _G.EmoteFreezeConn then _G.EmoteFreezeConn:Disconnect(); _G.EmoteFreezeConn = nil end
            return 
        end
        -- Debounce: prevent recursive feedback loop from playAction triggering AnimationPlayed
        if _G.EmoteDebounce then return end
        if isDancing(char, sTarget) then
            _G.EmoteDebounce = true
            task.wait(0.1)
            if _G.CurrentEmoteCommand == targetId then
                playAction()
            end
            _G.EmoteDebounce = false
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  NPC (wander 30-60s, no duplicate targets, unique lines)
-- ═══════════════════════════════════════════════════════════
Commands.npc = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); _G.CurrentCommand = "NPC"

    local phrases = {
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
    }

    -- Global shared claim table & shared line index (no repeats until all used)
    _G.NPCClaimed = _G.NPCClaimed or {}
    if not _G.NPCLineIndex then _G.NPCLineIndex = 0 end

    local myIdx = SafeIndex()

    -- Get next unique line (atomic increment via shared _G)
    local function GetNextLine()
        _G.NPCLineIndex = (_G.NPCLineIndex % #phrases) + 1
        return phrases[_G.NPCLineIndex]
    end

    task.spawn(function()
        while _G.CurrentCommand == "NPC" do
            local myC = LocalPlayer.Character; local myH = myC and myC:FindFirstChild("Humanoid")
            local myR = myC and myC:FindFirstChild("HumanoidRootPart")

            if myH and myR then
                if myH.Sit then myH.Sit = false end

                -- WANDER phase: 30-60 seconds
                local wanderEnd = tick() + math.random(30, 60)
                while _G.CurrentCommand == "NPC" and tick() < wanderEnd do
                    local rng = Random.new(tick() + myIdx)
                    myH:MoveTo(myR.Position + Vector3.new(rng:NextNumber(-30,30), 0, rng:NextNumber(-30,30)))
                    local done, t, cn = false, 0, nil
                    cn = myH.MoveToFinished:Connect(function() done = true end)
                    repeat task.wait(0.1); t += 0.1 until done or _G.CurrentCommand ~= "NPC" or t > 10
                    if cn then cn:Disconnect() end
                    task.wait(math.random(2, 5))
                end

                if _G.CurrentCommand ~= "NPC" then break end

                -- INTERACTION phase: find a random nearby player (not claimed)
                local candidates = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer
                    and p.Name:lower() ~= getgenv().Settings.mainAccount:lower()
                    and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local isBot = false
                        for a in pairs(getgenv().Settings.altAccounts) do
                            if a:lower() == p.Name:lower() then isBot = true; break end
                        end
                        if not isBot and not _G.NPCClaimed[p.UserId] then
                            local d = (myR.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if d < 60 then table.insert(candidates, p) end
                        end
                    end
                end

                if #candidates > 0 then
                    local chosen = candidates[math.random(#candidates)]
                    _G.NPCClaimed[chosen.UserId] = myIdx

                    local tR = chosen.Character and chosen.Character:FindFirstChild("HumanoidRootPart")
                    if tR then
                        local frontPos = (tR.CFrame * CFrame.new(0, 0, -4)).Position
                        myH:MoveTo(frontPos)
                        local arrived, t, cn = false, 0, nil
                        cn = myH.MoveToFinished:Connect(function() arrived = true end)
                        repeat task.wait(0.1); t += 0.1 until arrived or t > 8 or _G.CurrentCommand ~= "NPC"
                        if cn then cn:Disconnect() end

                        if _G.CurrentCommand == "NPC" and tR.Parent then
                            myR.CFrame = CFrame.new(myR.Position,
                                Vector3.new(tR.Position.X, myR.Position.Y, tR.Position.Z))
                            task.wait(0.5)
                            ChatSend(GetNextLine())
                            task.wait(3)

                            -- Walk AWAY from the player
                            local away = myR.Position - tR.Position
                            if away.Magnitude > 0.1 then
                                myH:MoveTo(myR.Position + away.Unit * 20)
                            else
                                myH:MoveTo(myR.Position + Vector3.new(20, 0, 0))
                            end
                            local d2, t2, cn2 = false, 0, nil
                            cn2 = myH.MoveToFinished:Connect(function() d2 = true end)
                            repeat task.wait(0.1); t2 += 0.1 until d2 or t2 > 6 or _G.CurrentCommand ~= "NPC"
                            if cn2 then cn2:Disconnect() end
                        end
                    end

                    _G.NPCClaimed[chosen.UserId] = nil
                end
            else task.wait(1) end
        end
        _G.NPCClaimed = {}
    end)
end

-- ═══════════════════════════════════════════════════════════
--  FIREWORK (solo-guarded)
-- ═══════════════════════════════════════════════════════════
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
    StopAll(); _G.CurrentCommand = "Swarm"
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
    StopAll(); _G.CurrentCommand = tag or "Orbit"
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
    StopAll(); _G.CurrentCommand = "Helicopter"
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
    StopAll()
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
        task.wait((SafeIndex() - 1) * 0.05)
        ChatSend("[" .. LocalPlayer.Name .. "] Ping: " .. math.round(LocalPlayer:GetNetworkPing()*1000) .. "ms")
    end)
end
Commands.latency = Commands.ping; Commands.net = Commands.ping

Commands.memory = function(args, speaker)
    if not IsSoloCommand(args) then return end
    if _G.MemoryLock then return end; _G.MemoryLock = true
    task.spawn(function()
        pcall(function()
            task.wait((SafeIndex() - 1) * 0.05)
            ChatSend("[" .. LocalPlayer.Name .. "] RAM: " .. math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb()) .. " MB")
        end)
        task.wait(2); _G.MemoryLock = nil
    end)
end
Commands.ram = Commands.memory

-- ═══════════════════════════════════════════════════════════
--  ULTRA LOW RAM & RENDERING ENGINE
-- ═══════════════════════════════════════════════════════════
local function ApplyRenderMode(enabled)
    -- Direct engine 3D toggle
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
    -- Universal camera frustum occlusion fallback (works on ALL executors)
    -- When disabled, points camera into deep void so Roblox stops loading/rendering 3D meshes & textures
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            if not enabled then
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.new(0, 80000, 0) * CFrame.Angles(math.rad(90), 0, 0)
            else
                cam.CameraType = Enum.CameraType.Custom
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    cam.CameraSubject = char.Humanoid
                end
            end
        end
    end)
    -- Texture & material strip
    if not enabled then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            collectgarbage("collect")
        end)
    end
end

Commands.render = function(args, speaker)
    local state = args[2] and tostring(args[2]):lower() or ""
    local enabled = true
    if state == "off" or state == "false" or state == "0" then
        enabled = false
    elseif state == "on" or state == "true" or state == "1" then
        enabled = true
    else
        local ok, is3d = pcall(function() return RunService:Is3dRenderingEnabled() end)
        if ok then enabled = not is3d else enabled = false end
    end
    ApplyRenderMode(enabled)
    if SafeIndex() == 1 then
        ChatSend("[DayBreak] 3D Rendering: " .. (enabled and "Enabled 👁️" or "Disabled (Ultra Low RAM) ⚡"))
    end
end

Commands.lowram = function(args, speaker)
    ApplyRenderMode(false)
    collectgarbage("collect")
    task.wait(0.1)
    collectgarbage("collect")
    if SafeIndex() == 1 then
        ChatSend("[DayBreak] Ultra Low RAM Active ⚡ (-250MB+ saved)")
    end
end
Commands.unlowram = function(args, speaker)
    Commands.render({args[1], "on"}, speaker)
end

Commands.cleanram = function(args, speaker)
    if not IsSoloCommand(args) then return end
    task.spawn(function()
        local before = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
        collectgarbage("collect")
        task.wait(0.05)
        collectgarbage("collect")
        local after = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
        local freed = before - after
        task.wait((SafeIndex() - 1) * 0.05)
        local sign = freed >= 0 and "-" or "+"
        ChatSend("[" .. LocalPlayer.Name .. "] RAM: " .. before .. "MB -> " .. after .. "MB (" .. sign .. math.abs(freed) .. "MB)")
    end)
end
Commands.flush = Commands.cleanram
Commands.ramclean = Commands.cleanram

-- ═══════════════════════════════════════════════════════════
--  FUNNY, VIRAL & MEME COMMANDS
-- ═══════════════════════════════════════════════════════════

-- 1. Secret Service Bodyguards
Commands.bodyguard = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Bodyguard"
    local idx, total = SafeIndex(), SafeTotal()
    local angle = ((idx - 1) / total) * math.pi * 2
    local dist = math.max(4, total * 0.8)
    local lastWarning = 0
    task.spawn(function()
        while _G.CurrentCommand == "Bodyguard" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if tHRP and mHRP and mHum then
                if mHum.Sit then mHum.Sit = false end
                local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                local goalPos = tHRP.Position + offset
                mHRP.CFrame = CFrame.new(goalPos, goalPos + offset)
                mHRP.Velocity = Vector3.zero
                
                local now = os.clock()
                if (now - lastWarning) > 5 then
                    local alts = getgenv().Settings.altAccounts or {}
                    for _, stranger in ipairs(Players:GetPlayers()) do
                        local sName = stranger.Name:lower()
                        local isAlt = alts[sName] or false
                        if not isAlt then
                            for a in pairs(alts) do
                                if a:lower() == sName then isAlt = true; break end
                            end
                        end
                        if stranger ~= target and stranger ~= LocalPlayer and not isAlt and not IsWhitelisted(stranger.Name) then
                            local sChar = stranger.Character
                            local sHRP = sChar and sChar:FindFirstChild("HumanoidRootPart")
                            if sHRP and (sHRP.Position - tHRP.Position).Magnitude < 7 then
                                lastWarning = now
                                if idx == 1 then
                                    ChatSend("Sir " .. stranger.DisplayName .. ", please step away from the VIP. 🛑")
                                end
                                break
                            end
                        end
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 2. The Ritual (Cult chant)
Commands.ritual = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Ritual"
    local idx, total = SafeIndex(), SafeTotal()
    local angle = ((idx - 1) / total) * math.pi * 2
    local dist = math.max(5, total * 0.9)
    task.spawn(function()
        while _G.CurrentCommand == "Ritual" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if tHRP and mHRP and mHum then
                mHum.Sit = true
                local goalPos = tHRP.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                mHRP.CFrame = CFrame.new(goalPos, tHRP.Position)
                mHRP.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
    task.spawn(function()
        local chants = {
            "🔥 THE RITUAL COMMENCES 🔥",
            "HE WHO IS CHOSEN 🕯️",
            "ACCEPT OUR SACRIFICE 👁️",
            "ALL HAIL THE SUN ☀️",
            "AMEN 🙏"
        }
        task.wait((idx - 1) * 0.1)
        if _G.CurrentCommand == "Ritual" then
            local myChant = chants[((idx - 1) % #chants) + 1]
            ChatSend(myChant)
        end
    end)
end

-- 3. Paparazzi (Celebrity Mob)
Commands.paparazzi = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Paparazzi"
    local idx, total = SafeIndex(), SafeTotal()
    local quotes = {
        "📸 OVER HERE PLEASE!",
        "📸 LOOK AT THE CAMERA!",
        "📸 ARE THE RUMORS TRUE?!",
        "📸 WHO ARE YOU DATING?!",
        "📸 JUST ONE PHOTO FOR VOGUE!",
        "📸 SMILE FOR THE FLASH!"
    }
    task.spawn(function()
        local nextFlash = os.clock() + (idx * 0.8)
        while _G.CurrentCommand == "Paparazzi" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if tHRP and mHRP and mHum then
                if mHum.Sit then mHum.Sit = false end
                local angle = tick() * 2 + ((idx / total) * math.pi * 2)
                local dist = 4 + math.sin(tick() * 3 + idx) * 1.5
                local goal = tHRP.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                mHRP.CFrame = CFrame.new(goal, tHRP.Position)
                if math.random(1, 15) == 1 then mHum.Jump = true end
                
                if os.clock() >= nextFlash then
                    nextFlash = os.clock() + math.random(4, 7)
                    ChatSend(quotes[((idx - 1 + math.random(1, 3)) % #quotes) + 1])
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 4. Coffin Dance (Astronomia meme - Scales with any number of bots)
Commands.coffin = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Coffin"
    local idx, total = SafeIndex(), SafeTotal()
    
    if idx == 1 then
        task.spawn(function()
            ChatSend("⚰️ 🎵 (Astronomia Intensifies) 🎵 ⚰️")
        end)
    end
    
    task.spawn(function()
        local t0 = tick()
        while _G.CurrentCommand == "Coffin" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if tHRP and mHRP then
                local el = tick() - t0
                local swayX = math.sin(el * 5) * 1.2
                local hopY = math.abs(math.sin(el * 10)) * 0.8
                
                local baseOffset
                if idx <= 4 then
                    local coreOffsets = {
                        Vector3.new(-3, 0, -3.5),
                        Vector3.new(3, 0, -3.5),
                        Vector3.new(-3, 0, 3.5),
                        Vector3.new(3, 0, 3.5),
                    }
                    baseOffset = coreOffsets[idx]
                else
                    local extraIndex = idx - 5
                    local row = math.floor(extraIndex / 2) + 1
                    local sideX = (extraIndex % 2 == 0) and -2.5 or 2.5
                    local rowZ = 5.5 + (row * 3.5)
                    baseOffset = Vector3.new(sideX, 0, rowZ)
                end
                
                local currentOffset = Vector3.new(baseOffset.X + swayX, baseOffset.Y + hopY, baseOffset.Z)
                mHRP.CFrame = (tHRP.CFrame * CFrame.new(currentOffset)) * CFrame.Angles(0, 0, math.sin(el * 5) * 0.15)
                mHRP.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 5. Conga / Train Line (Scales smoothly with any bot count, zero clipping)
Commands.conga = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Conga"
    local idx = SafeIndex()
    task.spawn(function()
        while _G.CurrentCommand == "Conga" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if tHRP and mHRP and mHum then
                if mHum.Sit then mHum.Sit = false end
                local trainOffset = idx * 3.5
                local waveSway = math.sin(tick() * 6 - (idx * 0.8)) * 1.5
                local goalPos = (tHRP.CFrame * CFrame.new(waveSway, 0, trainOffset)).Position
                local dist = (mHRP.Position - goalPos).Magnitude
                
                if dist > 40 then
                    mHRP.CFrame = CFrame.new(goalPos, tHRP.Position)
                    mHRP.Velocity = Vector3.zero
                else
                    mHum:MoveTo(goalPos)
                end
                
                if math.sin(tick() * 6 - (idx * 0.8)) > 0.7 then
                    mHum.Jump = true
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.train = Commands.conga

-- 6. The Creepy Stare
Commands.stare = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Stare"
    task.spawn(function()
        while _G.CurrentCommand == "Stare" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if tHRP and mHRP and mHum then
                mHum.WalkSpeed = 0
                mHRP.CFrame = CFrame.new(mHRP.Position, Vector3.new(tHRP.Position.X, mHRP.Position.Y, tHRP.Position.Z))
                mHRP.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 7. Supersonic Tornado Blender
Commands.tornado = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Tornado"
    local idx, total = SafeIndex(), SafeTotal()
    task.spawn(function()
        local t0 = tick()
        while _G.CurrentCommand == "Tornado" and target and target.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if tHRP and mHRP then
                local el = tick() - t0
                local spinSpeed = 12
                local angle = (el * spinSpeed) + ((idx / total) * math.pi * 2)
                local heightOffset = ((idx - 1) / total) * 12 - 3
                local radius = 3 + (heightOffset * 0.4)
                local pos = tHRP.Position + Vector3.new(math.cos(angle) * radius, heightOffset, math.sin(angle) * radius)
                mHRP.CFrame = CFrame.new(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle))) * CFrame.Angles(0, el * 20, 0)
                mHRP.Velocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- 8. Sci-Fi Laser Grid Target System
Commands.laser = function(args, speaker)
    StopAll()
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Laser"
    
    local mChar = LocalPlayer.Character
    local tChar = target.Character
    local mHRP = mChar and mChar:FindFirstChild("HumanoidRootPart")
    local tHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not mHRP or not tHRP then return end

    if _G.ActiveLaserBeam then pcall(function() _G.ActiveLaserBeam:Destroy() end); _G.ActiveLaserBeam = nil end
    if _G.ActiveLaserAtt0 then pcall(function() _G.ActiveLaserAtt0:Destroy() end); _G.ActiveLaserAtt0 = nil end
    if _G.ActiveLaserAtt1 then pcall(function() _G.ActiveLaserAtt1:Destroy() end); _G.ActiveLaserAtt1 = nil end

    local att0 = Instance.new("Attachment")
    att0.Name = "DayBreakLaserAtt0"
    att0.Parent = mHRP
    _G.ActiveLaserAtt0 = att0

    local att1 = Instance.new("Attachment")
    att1.Name = "DayBreakLaserAtt1"
    att1.Parent = tHRP
    _G.ActiveLaserAtt1 = att1

    local beam = Instance.new("Beam")
    beam.Name = "DayBreakLaserBeam"
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 35, 35))
    beam.Width0 = 0.45
    beam.Width1 = 0.45
    beam.Texture = "rbxassetid://10842065842"
    beam.TextureMode = Enum.TextureMode.Wrap
    beam.TextureSpeed = 3
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.FaceCamera = true
    beam.Parent = mHRP
    _G.ActiveLaserBeam = beam

    if SafeIndex() == 1 then
        ChatSend("[DayBreak] ⚡ Laser Grid Locked: " .. target.DisplayName)
    end

    task.spawn(function()
        while _G.CurrentCommand == "Laser" and target and target.Character and _G.ActiveLaserBeam do
            RunService.Heartbeat:Wait()
        end
        if _G.ActiveLaserBeam then pcall(function() _G.ActiveLaserBeam:Destroy() end); _G.ActiveLaserBeam = nil end
        if _G.ActiveLaserAtt0 then pcall(function() _G.ActiveLaserAtt0:Destroy() end); _G.ActiveLaserAtt0 = nil end
        if _G.ActiveLaserAtt1 then pcall(function() _G.ActiveLaserAtt1:Destroy() end); _G.ActiveLaserAtt1 = nil end
    end)
end

Commands.unlaser = function(args, speaker)
    if _G.ActiveLaserBeam then pcall(function() _G.ActiveLaserBeam:Destroy() end); _G.ActiveLaserBeam = nil end
    if _G.ActiveLaserAtt0 then pcall(function() _G.ActiveLaserAtt0:Destroy() end); _G.ActiveLaserAtt0 = nil end
    if _G.ActiveLaserAtt1 then pcall(function() _G.ActiveLaserAtt1:Destroy() end); _G.ActiveLaserAtt1 = nil end
    if _G.CurrentCommand == "Laser" then _G.CurrentCommand = "None" end
    if SafeIndex() == 1 then
        ChatSend("[DayBreak] ⚡ Laser Grid Disengaged")
    end
end
Commands.clearlaser = Commands.unlaser


-- ═══════════════════════════════════════════════════════════
--  CARPET / FLOOR / BRIDGE
-- ═══════════════════════════════════════════════════════════
Commands.carpet = function(args, speaker)
    StopAll()
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
    StopAll(); _G.CurrentCommand = "Spin"
    task.spawn(function()
        local rot = 0; local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if h then h.AutoRotate = false end
        while _G.CurrentCommand == "Spin" do
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r then rot += spinSpd; r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(rot), 0)
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
    StopAll()
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
    StopAll(); _G.CurrentCommand = "Bang"
    task.spawn(function()
        local step, inc = 0, true; local stepInc = 0.45 * spd
        while _G.CurrentCommand == "Bang" and target and target.Character and tR.Parent do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if mR and tR then
                if h and h.Sit then h.Sit = false end
                if inc then step += stepInc; if step >= 1 then inc = false end
                else step -= stepInc; if step <= 0 then inc = true end end
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
    StopAll(); _G.CurrentCommand = "FaceBang"
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
                if inc then step += stepInc; if step >= 1 then inc = false end
                else step -= stepInc; if step <= 0 then inc = true end end
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
        StopAll()
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
    StopAll()
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
    StopAll(); _G.CurrentCommand = "MultiBang"
    task.spawn(function()
        local step, inc, oa = 0, true, 0; local stepInc = 0.45 * spd
        while _G.CurrentCommand == "MultiBang" and target and target.Character do
            local mR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local tR = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local tH = target.Character and target.Character:FindFirstChild("Head") or tR
            local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if mR and tR then
                local idx, total = SafeIndex(), SafeTotal()
                if inc then step += stepInc; if step >= 1 then inc = false end
                else step -= stepInc; if step <= 0 then inc = true end end
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
                else oa += 0.05; local si=idx-5; local ts=math.max(total-5,1); local sp=(si/ts)*(math.pi*2)
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
    [1]  = "(့、fเɹჺkɐԀყჿเɹꞅıาาჿıาาꞅลพ、 (့)`",
    [2]  = "(့、ჺlาเɹဌรɐıาาɐıาลıาԀรพลıาԀịνɐჿffลfเɹჺkịıาဌlวꞅịԀဌɐ、 (့)`",
    [3]  = "(့、ị'ƖƖνịჿƖลϯɐყჿเɹꞅlวƖჿჿԀƖịıาɐ,ყჿเɹჺเɹıาϯ、 (့)`",
    [4]  = "(့、ჺลıาพɐԀჿlวჿჿıาาlวลყลlา、 (့)`",
    [5]  = "(့、ꞅลıาาลԀịƖԀჿเɹꞁวყჿเɹꞅꞅɐჺϯเɹıาา、 (့)`",
    [6]  = "(့、ყჿเɹꞅıาาჿıาารɋเɹịꞅϯɐԀჿıาıาาɐ、 (့)`",
    [7]  = "(့、รพลƖƖჿพlวƖɐลჺlาჺเɹıาϯ、 (့)`",
    [8]  = "(့、รkเɹƖƖfเɹჺkჺჿꞅꞁวรɐ、 (့)`",
    [9]  = "(့、ჺเɹıาาꞅลဌlวลlวყlวịϯჺlา、 (့)`",
    [10] = "(့、ဌƖลรรịıาลรรჺเɹıาϯ、 (့)`",
    [11] = "(့、ƖịჺklวลƖƖรϯlาɐıาԀịɐ、 (့)`",
    [12] = "(့、ịƖƖꞅลꞁวɐყჿเɹꞅfลıาาịƖყ、 (့)`",
    [13] = "(့、ɐลϯลรรลıาԀlาลıาဌϯพịჺɐ、 (့)`",
    [14] = "(့、รlาჿνɐลჺลჺϯเɹรเɹꞁวყჿเɹꞅลรรჺเɹıาϯ、 (့)`",
    [15] = "(့、Ԁꞅịıาkꞁวịรรϯlาɐıาɉเɹıาาꞁวịıาϯꞅลffịჺlวịϯჺlา、 (့)`",
    [16] = "(့、ჺเɹꞅlวรϯჿıาาꞁวყჿเɹꞅพlาჿƖɐfเɹჺkịıาဌfลıาาịƖყ、 (့)`",
    [17] = "(့、ყჿเɹჺเɹıาาꞅลဌϯพลϯ,ყჿเɹɉเɹรϯıาาลkɐıาาყfลჺɐıาาɐıาาɐ、 (့)`",
    [18] = "(့、ϯꞅลıาıาყჺเɹıาϯlวịϯჺlา、 (့)`",
    [19] = "(့、ჺเɹıาาဌเɹʑʑƖịıาဌfลဌ、 (့)`",
    [20] = "(့、ลịԀรɋเɹɐɐꞅϯꞅลรlา、 (့)`",
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
    StopAll(); _G.CurrentCommand = "HS"
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
        task.wait((SafeIndex() - 1) * 0.05)
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
            if (mR.Position - tR.Position).Magnitude < 1.7 then lc += 1 else lc = 0 end
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
    if m ~= "" then task.spawn(function() task.wait((SafeIndex() - 1) * 0.05); ChatSend(m) end) end
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
        task.wait((idx - 1) * 0.08)
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
local _lastPlayerMsg = {}
local _lastPlayerTime = {}
local function SetupChatListener(p)
    getgenv().TrackConnection(p.Chatted:Connect(function(msg)
        local now = os.clock()
        local nl = p.Name:lower()
        -- TextChatService duplicate event filter: ignores duplicate message from same speaker within 0.5s
        if _lastPlayerMsg[nl] == msg and (now - (_lastPlayerTime[nl] or 0)) < 0.5 then
            return
        end
        _lastPlayerMsg[nl] = msg
        _lastPlayerTime[nl] = now
        local prefix = getgenv().Settings.prefix
        
        if IsWhitelisted(p.Name) then
            if msg:sub(1, #prefix) == prefix then getgenv().Execute(msg, p) end
        end
        
        -- Mimic System
        if _G.Mimicking and _G.MimicTarget == nl then
            -- Make sure the bot doesn't parrot commands
            if msg:sub(1, #prefix) ~= prefix then
                local idx = SafeIndex() or 1
                task.spawn(function()
                    -- Tiny waterfall to prevent group mute trigger
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
    if message ~= "ᕦ(ò_óˇ)ᕤ" and message ~= "!daybreak_master_key" and message ~= "daybreak::master" then return end
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

-- ═══════════════════════════════════════════════════════════
--  17. MAIN ACCOUNT COMMAND GUI (Refined Compact)
-- ═══════════════════════════════════════════════════════════
if isMainAccount then
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then local o = pg:FindFirstChild("DayBreakCommandGUI"); if o then o:Destroy() end end
    end)

    local TS = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")

    local T = {
        Bg       = Color3.fromRGB(12,12,16),
        Card     = Color3.fromRGB(22,22,30),
        CardHov  = Color3.fromRGB(34,30,40),
        Surface  = Color3.fromRGB(26,24,34),
        Accent   = Color3.fromRGB(255,170,0),    -- Vibrant Sunrise Amber Gold
        AccHov   = Color3.fromRGB(255,200,50),   -- Sunlight Gold
        Green    = Color3.fromRGB(50,210,110),
        Red      = Color3.fromRGB(230,65,65),
        Text     = Color3.fromRGB(240,240,245),
        Dim      = Color3.fromRGB(140,135,155),
        Border   = Color3.fromRGB(55,48,60),
        Section  = Color3.fromRGB(255,140,20),   -- Warm Horizon Orange
        FM       = Enum.Font.GothamBold,
        FB       = Enum.Font.Gotham,
        FC       = Enum.Font.Code,
    }
    local BG_ALPHA = 0.4

    local SG = Instance.new("ScreenGui")
    SG.Name = "DayBreakCommandGUI"; SG.ResetOnSpawn = false; SG.IgnoreGuiInset = true
    SG.DisplayOrder = 100; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local function C(cl,pr) local i=Instance.new(cl); for k,v in pairs(pr) do if k~="Parent" then i[k]=v end end; if pr.Parent then i.Parent=pr.Parent end; return i end
    local function Cn(p,r) C("UICorner",{CornerRadius=r or UDim.new(0,8),Parent=p}) end
    local function St(p,c,th) C("UIStroke",{Color=c or T.Border,Thickness=th or 1,Transparency=0.3,Parent=p}) end
    local function Tw(o,pr,d,s) TS:Create(o,TweenInfo.new(d or 0.18,s or Enum.EasingStyle.Quad),pr):Play() end

    local function MakeDraggable(handle, frame)
        local dg,di,ds,sp = false,nil,nil,nil
        handle.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dg=true; ds=inp.Position; sp=frame.Position
                inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dg=false end end)
            end
        end)
        handle.InputChanged:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then di=inp end
        end)
        UIS.InputChanged:Connect(function(inp)
            if inp==di and dg then
                local d2=inp.Position-ds
                frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d2.X,sp.Y.Scale,sp.Y.Offset+d2.Y)
            end
        end)
    end

    ----------------------------------------------------------------
    -- COMMAND DATA (Professional Descriptions)
    ----------------------------------------------------------------
    local SECTIONS = {
        {
            name = "Movement",
            color = Color3.fromRGB(60,160,255),
            cmds = {
                {cmd="goto",   desc="Teleports to player",      al="[bot] Target",          ha=true},
                {cmd="follow", desc="Follows target",           al="[bot] Target",          ha=true},
                {cmd="walkto", desc="Walks to target",          al="[bot] Target",          ha=true},
                {cmd="bring",  desc="Summons bots directly",    al="[bot] Target",          ha=true},
                {cmd="wonder", desc="Randomly wanders",         ha=false},
                {cmd="stalk",  desc="Stalks from behind",       al="[bot] Target",          ha=true},
                {cmd="worm",   desc="Forms snake chain",        al="[bot] Target",          ha=true},
                {cmd="swarm",  desc="Chaotic swarming",         al="[bot] [Spd] [R] Target",ha=true},
                {cmd="carpet", desc="Grid pattern formation",   al="[bot] Target",          ha=true},
                {cmd="tp",     desc="Teleports via coords",     al="[bot] X Y Z / Target",  ha=true},
                {cmd="scatter",desc="Random scattering",        al="[bot] Range",           ha=true},
            },
        },
        {
            name = "Formations",
            color = Color3.fromRGB(255,160,40),
            cmds = {
                {cmd="circle",    desc="Snaps to circle",   al="[R] Target",ha=true},
                {cmd="loopcircle",desc="Iterative circle",  al="[R] Target",ha=true},
                {cmd="arrow",     desc="V-shape pattern",   al="Target",    ha=true},
                {cmd="box",       desc="Square array",      al="Target",    ha=true},
                {cmd="stackon",   desc="Vertical tower",    al="Target",    ha=true},
                {cmd="rline",     desc="Right side line",   al="Target",    ha=true},
                {cmd="lline",     desc="Left side line",    al="Target",    ha=true},
                {cmd="fline",     desc="Forward line",      al="Target",    ha=true},
                {cmd="bline",     desc="Rear line",         al="Target",    ha=true},
                {cmd="looprline", desc="Loop active right", al="Target",    ha=true},
                {cmd="looplline", desc="Loop active left",  al="Target",    ha=true},
                {cmd="loopfline", desc="Loop active front", al="Target",    ha=true},
                {cmd="loopbline", desc="Loop active rear",  al="Target",    ha=true},
            },
        },

        {
            name = "Orbits",
            color = Color3.fromRGB(255,185,40),
            cmds = {
                {cmd="orbit",   desc="Flat circular orbit",  al="[Spd] [R] Target",ha=true},
                {cmd="orbit1",  desc="Double helix",         al="[Spd] [R] Target",ha=true},
                {cmd="orbit2",  desc="Atomic structure",     al="[Spd] [R] Target",ha=true},
                {cmd="orbit3",  desc="Wide galaxy spin",     al="[Spd] [R] Target",ha=true},
                {cmd="orbit4",  desc="Vertical vortex",      al="[Spd] [R] Target",ha=true},
                {cmd="orbit5",  desc="Figure-eight orbit",   al="[Spd] [R] Target",ha=true},
                {cmd="orbit6",  desc="Layered cascade",      al="[Spd] [R] Target",ha=true},
                {cmd="orbit7",  desc="Target pulsar",        al="[Spd] [R] Target",ha=true},
                {cmd="orbit8",  desc="Planetary ring",       al="[Spd] [R] Target",ha=true},
                {cmd="orbit9",  desc="Floral pattern",       al="[Spd] [R] Target",ha=true},
                {cmd="orbit10", desc="Unpredictable spin",   al="[Spd] [R] Target",ha=true},
            },
        },
        {
            name = "Spirals",
            color = Color3.fromRGB(255,120,40),
            cmds = {
                {cmd="spiral1", desc="Upward ascent",   al="[Spd] [R] Target",ha=true},
                {cmd="spiral2", desc="Cone vortex",     al="[Spd] [R] Target",ha=true},
                {cmd="spiral3", desc="Ladder form",     al="[Spd] [R] Target",ha=true},
                {cmd="spiral4", desc="Dispersal jet",   al="[Spd] [R] Target",ha=true},
                {cmd="spiral5", desc="Funnel tornado",  al="[Spd] [R] Target",ha=true},
                {cmd="spiral6", desc="Golden ratio",    al="[Spd] [R] Target",ha=true},
                {cmd="spiral7", desc="Bouncing spring", al="[Spd] [R] Target",ha=true},
                {cmd="spiral8", desc="Inward pool",     al="[Spd] [R] Target",ha=true},
                {cmd="spiral9", desc="Wavy ascent",     al="[Spd] [R] Target",ha=true},
                {cmd="spiral10",desc="Fluid drop",      al="[Spd] [R] Target",ha=true},
            },
        },
        {
            name = "Shields",
            color = Color3.fromRGB(80,200,160),
            cmds = {
                {cmd="shield1",desc="Protective wall",  al="Target",ha=true},
                {cmd="shield2",desc="Defensive arc",    al="Target",ha=true},
                {cmd="shield3",desc="V-guard array",    al="Target",ha=true},
                {cmd="shield4",desc="Reinforced wall",  al="Target",ha=true},
                {cmd="shield5",desc="Full enclosure",   al="Target",ha=true},
            },
        },
        {
            name = "Action",
            color = Color3.fromRGB(255,70,70),
            cmds = {
                {cmd="helicopter",desc="Overhead mount",        al="[Spd] Target",      ha=true},
                {cmd="bang",      desc="Rear engagement",       al="[bot] [Spd] Target",ha=true},
                {cmd="fbang",     desc="Frontal engagement",    al="[bot] [Spd] Target",ha=true},
                {cmd="mbang",     desc="Group engagement",      al="[Spd] Target",      ha=true},
                {cmd="rizz",      desc="Sequential approach",   al="Target",            ha=true},
                {cmd="hs",        desc="Strike action",         al="Target",            ha=true},
                {cmd="hs2",       desc="Strike: Vibe check",    al="Target",            ha=true},
                {cmd="hs3",       desc="Strike: Council denial",al="Target",            ha=true},
                {cmd="hs4",       desc="Strike: Ancestral",     al="Target",            ha=true},
                {cmd="hs5",       desc="Strike: Eviction",      al="Target",            ha=true},
                {cmd="hs6",       desc="Strike: Expiration",    al="Target",            ha=true},
                {cmd="hs7",       desc="Strike: Target locked", al="Target",            ha=true},
                {cmd="hs8",       desc="Strike: Security breach",al="Target",           ha=true},
                {cmd="hs9",       desc="Strike: Nullified",     al="Target",            ha=true},
                {cmd="hs10",      desc="Strike: Farewell",      al="Target",            ha=true},
                {cmd="hs11",      desc="Strike: Deleted",       al="Target",            ha=true},
                {cmd="hs12",      desc="Strike: Skill deficit", al="Target",            ha=true},
                {cmd="hs13",      desc="Strike: Warranty void", al="Target",            ha=true},
                {cmd="hs14",      desc="Strike: Countdown",     al="Target",            ha=true},
                {cmd="hs15",      desc="Strike: End sim",       al="Target",            ha=true},
                {cmd="hs16",      desc="Strike: False peace",   al="Target",            ha=true},
                {cmd="hs17",      desc="Strike: Authority null",al="Target",            ha=true},
                {cmd="hs18",      desc="Strike: Jurisdiction",  al="Target",            ha=true},
                {cmd="hs19",      desc="Strike: Personal",      al="Target",            ha=true},
                {cmd="hs20",      desc="Strike: Zero escape",   al="Target",            ha=true},
                {cmd="nuke",      desc="Orbital dropdown",      al="Target",            ha=true},
                {cmd="vfling",    desc="Velocity launch",       al="Target",            ha=true},
                {cmd="firework",  desc="Particle array launch",                          ha=false},
                {cmd="spin",      desc="Axial rotation",        al="Speed",             ha=true},
                {cmd="mirror",    desc="Mimics movement",       al="Target",            ha=true},
                {cmd="rest",      desc="Character reset",       al="[bot]",             ha=true},
            },
        },
        {
            name = "Character",
            color = Color3.fromRGB(100,200,255),
            cmds = {
                {cmd="freeze",   desc="Locks root part",                     ha=false},
                {cmd="unfreeze", desc="Unlocks root part",                   ha=false},
                {cmd="ref",      desc="Refreshes avatar",                    ha=false},
                {cmd="ws",       desc="Overrides base speeed",  al="Speed",  ha=true},
                {cmd="unws",     desc="Restores base speed",                 ha=false},
                {cmd="noclip",   desc="Disables collisions",                 ha=false},
                {cmd="clip",     desc="Restores collisions",                 ha=false},
                {cmd="invisible",desc="Obscures character",                  ha=false},
                {cmd="visible",  desc="Reveals character",                   ha=false},
            },
        },
        {
            name = "Emotes",
            color = Color3.fromRGB(255,200,60),
            cmds = {
                {cmd="emote",   desc="Plays catalog emote", al="Name",    ha=true},
                {cmd="unemote", desc="Stops active emote",                ha=false},
                {cmd="sync",     desc="Server-synced emote", al="Name",    ha=true},
                {cmd="dance",  desc="Executes Dance 1", ha=false},
                {cmd="dance2", desc="Executes Dance 2", ha=false},
                {cmd="dance3", desc="Executes Dance 3", ha=false},
                {cmd="jump",   desc="Triggers hop",     ha=false},
                {cmd="sit",    desc="Drops stance",     ha=false},
                {cmd="wave",   desc="Friendly hail",    ha=false},
            },
        },
        {
            name = "Clone",
            color = Color3.fromRGB(255,165,70),
            cmds = {
                {cmd="unloopclone",desc="Ceases cloning",                 ha=false},
            },
        },
        {
            name = "Chat",
            color = Color3.fromRGB(100,255,160),
            cmds = {
                {cmd="w",        desc="Whispers string",    al="Target Msg", ha=true},
                {cmd="spamw",    desc="Loop whisper string",al="User [Dly] Msg", ha=true},
                {cmd="report",   desc="Triggers user report",al="Target Reason",ha=true},
                {cmd="mimic",    desc="Mirrors target's chat",al="Target",   ha=true},
                {cmd="unmimic",  desc="Halts chat mirror",                   ha=false},
                {cmd="friend",   desc="Sends friend request",al="Target",    ha=true},
                {cmd="block",    desc="Blocks target player",al="Target",    ha=true},
                {cmd="npc",      desc="Triggers wandering AI",            ha=false},
                {cmd="say",      desc="Broadcasts string",  al="Message", ha=true},
                {cmd="spam",     desc="Loops string output",al="[Dly] Msg",ha=true},
                {cmd="unspam",   desc="Halts string loop",                ha=false},
                {cmd="countdown",desc="Staggered counting", al="Number",  ha=true},
                {cmd="credits",  desc="Lists attributions",               ha=false},
            },
        },
        {
            name = "Mic Up",
            color = Color3.fromRGB(255,100,100),
            cmds = {
                {cmd="pvp",        desc="Toggles Mic Up PVP",    al="[on/off]", ha=false},
                {cmd="grab",       desc="Detains instance",      al="Target",   ha=true},
                {cmd="clone",      desc="Matches aesthetics",    al="Target",   ha=true},
                {cmd="loopclone",  desc="Forces aesthetics",                    ha=false},
                {cmd="unloopclone",desc="Ceases cloning",                       ha=false},
                {cmd="gentool",    desc="Requests AI asset",     al="[Size] Prompt",ha=true},
            },

        },
        {
            name = "Info",
            color = Color3.fromRGB(180,180,200),
            cmds = {
                {cmd="ping",    desc="Analyzes latency",                       ha=false},
                {cmd="ram",     desc="Analyzes memory",                        ha=false},
                {cmd="uptime",  desc="Core session length",                    ha=false},
                {cmd="altcount",desc="Counts total units",                     ha=false},
            },
        },
        {
            name = "System",
            color = Color3.fromRGB(255,100,100),
            cmds = {
                {cmd="stop",       desc="Halts background tasks",ha=false},
                {cmd="antivoid",   desc="Void immunity up",      ha=false},
                {cmd="unantivoid", desc="Void immunity down",    ha=false},
                {cmd="scanall",    desc="Scans workspace map",   ha=false},
                {cmd="whitelist",  desc="Grants privileges",     al="Target",ha=true},
                {cmd="blacklist",  desc="Revokes privileges",    al="Target",ha=true},
                {cmd="rejoin",     desc="Rebinds to server",     ha=false},
                {cmd="quit",       desc="Ejects all bots",       ha=false},
            },
        },
    }

    ----------------------------------------------------------------
    -- MINIMIZED ICON
    ----------------------------------------------------------------
    local ICON_SIZE = 42
    local iconBtn = C("ImageButton",{
        Name = "DayBreakIcon",
        Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
        Position = UDim2.new(0, 12, 1, -(ICON_SIZE + 12)),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.2,
        Image = "rbxassetid://99251435575806",
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Visible = false,
        Parent = SG,
    })
    Cn(iconBtn, UDim.new(0, 10))
    St(iconBtn, T.Accent, 1.5)
    MakeDraggable(iconBtn, iconBtn)
    iconBtn.MouseEnter:Connect(function() Tw(iconBtn, {BackgroundTransparency=0}, 0.15) end)
    iconBtn.MouseLeave:Connect(function() Tw(iconBtn, {BackgroundTransparency=0.2}, 0.15) end)

    ----------------------------------------------------------------
    -- MAIN WINDOW
    ----------------------------------------------------------------
    local WW, WH = 240, 480

    local MF = C("Frame",{
        Name = "MainWindow",
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(1, -(WW + 16), 0.5, -(WH/2)),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = BG_ALPHA,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = SG,
    })
    Cn(MF, UDim.new(0, 10))
    St(MF, T.Accent, 1.5)
    Tw(MF, {Size = UDim2.new(0, WW, 0, WH)}, 0.45, Enum.EasingStyle.Back)

    ----------------------------------------------------------------
    -- TITLE BAR
    ----------------------------------------------------------------
    local HDR_H = 36
    local hdr = C("Frame",{
        Size = UDim2.new(1, 0, 0, HDR_H),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = MF,
    })
    Cn(hdr, UDim.new(0, 10))
    C("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=T.Card,BackgroundTransparency=0.3,BorderSizePixel=0,Parent=hdr})
    C("Frame",{Size=UDim2.new(1,-16,0,2),Position=UDim2.new(0,8,1,0),BackgroundColor3=T.Accent,BorderSizePixel=0,Parent=hdr})

    C("TextLabel",{
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "DayBreak ALT Control",
        TextColor3 = T.Text,
        TextSize = 13,
        Font = T.FM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = hdr,
    })

    local BCL = C("TextLabel",{
        Size = UDim2.new(0, 50, 0, 14),
        Position = UDim2.new(1, -106, 0.5, -7),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.5,
        Text = "0",
        TextColor3 = T.Green,
        TextSize = 9,
        Font = T.FC,
        TextXAlignment = Enum.TextXAlignment.Center,
        BorderSizePixel = 0,
        Parent = hdr,
    })
    Cn(BCL, UDim.new(0, 4))
    task.spawn(function()
        while _G.DayBreakActive do RefreshBotCache(); BCL.Text = "Bots:" .. _bc.total; task.wait(3) end
    end)

    local minBtn = C("TextButton",{
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -52, 0.5, -11),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.3,
        Text = "--",
        TextColor3 = T.Dim,
        TextSize = 10,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = hdr,
    })
    Cn(minBtn, UDim.new(0, 5))
    minBtn.MouseEnter:Connect(function() Tw(minBtn, {BackgroundTransparency=0, TextColor3=T.Text}, 0.1) end)
    minBtn.MouseLeave:Connect(function() Tw(minBtn, {BackgroundTransparency=0.3, TextColor3=T.Dim}, 0.1) end)

    local closeBtn = C("TextButton",{
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -26, 0.5, -11),
        BackgroundColor3 = T.Red,
        BackgroundTransparency = 0.5,
        Text = "X",
        TextColor3 = T.Dim,
        TextSize = 10,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = hdr,
    })
    Cn(closeBtn, UDim.new(0, 5))
    closeBtn.MouseEnter:Connect(function() Tw(closeBtn, {BackgroundTransparency=0, TextColor3=Color3.new(1,1,1)}, 0.1) end)
    closeBtn.MouseLeave:Connect(function() Tw(closeBtn, {BackgroundTransparency=0.5, TextColor3=T.Dim}, 0.1) end)

    MakeDraggable(hdr, MF)

    ----------------------------------------------------------------
    -- SEARCH BAR
    ----------------------------------------------------------------
    local SEARCH_Y = HDR_H + 6
    local SF = C("Frame",{
        Size = UDim2.new(1, -16, 0, 26),
        Position = UDim2.new(0, 8, 0, SEARCH_Y),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = MF,
    })
    Cn(SF, UDim.new(0, 6))
    St(SF, T.Border, 0.8)

    local SB = C("TextBox",{
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = "Search...",
        PlaceholderColor3 = T.Dim,
        Text = "",
        TextColor3 = T.Text,
        TextSize = 11,
        Font = T.FB,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = SF,
    })

    ----------------------------------------------------------------
    -- LIST PAGE (Unified layout)
    ----------------------------------------------------------------
    local LIST_Y = SEARCH_Y + 32
    local listPage = C("ScrollingFrame",{
        Name = "ListPage",
        Size = UDim2.new(1, -16, 1, -(LIST_Y + 44)),
        Position = UDim2.new(0, 8, 0, LIST_Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = MF,
    })
    C("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2),Parent=listPage})
    C("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2),Parent=listPage})

    local allCmdBtns = {}
    local layoutOrd = 0

    for _, sec in ipairs(SECTIONS) do
        layoutOrd = layoutOrd + 1

        -- Section header
        local secHdr = C("Frame",{
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = sec.color,
            BackgroundTransparency = 0.85,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrd,
            Parent = listPage,
        })
        Cn(secHdr, UDim.new(0, 5))
        C("Frame",{Size=UDim2.new(0,3,1,-4),Position=UDim2.new(0,0,0,2),BackgroundColor3=sec.color,BorderSizePixel=0,Parent=secHdr})

        C("TextLabel",{
            Size = UDim2.new(1, -8, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = sec.name,
            TextColor3 = sec.color,
            TextSize = 10,
            Font = T.FM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = secHdr,
        })

        -- Inline Commands
        for _, d in ipairs(sec.cmds) do
            layoutOrd = layoutOrd + 1

            local btn = C("TextButton",{
                Name = "btn_" .. d.cmd,
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = T.Card,
                BackgroundTransparency = 0.3,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = layoutOrd,
                Parent = listPage,
            })
            Cn(btn, UDim.new(0, 5))

            -- Command name (left)
            C("TextLabel",{
                Size = UDim2.new(0, 75, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                BackgroundTransparency = 1,
                Text = getgenv().Settings.prefix .. d.cmd,
                TextColor3 = T.Text,
                TextSize = 11,
                Font = T.FM,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = btn,
            })

            -- Inline Argument Box if needed
            local argBox = nil
            if d.ha then
                local argFrame = C("Frame", {
                    Size = UDim2.new(1, -88, 1, -8),
                    Position = UDim2.new(0, 80, 0, 4),
                    BackgroundColor3 = T.Surface,
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    Parent = btn
                })
                Cn(argFrame, UDim.new(0, 4))
                
                argBox = C("TextBox", {
                    Size = UDim2.new(1, -8, 1, 0),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    PlaceholderText = d.al or "args",
                    PlaceholderColor3 = T.Dim,
                    Text = "",
                    TextColor3 = T.Text,
                    TextSize = 9,
                    Font = T.FC,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    Active = true,  -- Stops click propagation from the box to the button
                    Parent = argFrame,
                })
            end

            -- Hover & Click Execution
            btn.MouseEnter:Connect(function() Tw(btn, {BackgroundTransparency = 0.1, BackgroundColor3 = T.CardHov}, 0.12) end)
            btn.MouseLeave:Connect(function() Tw(btn, {BackgroundTransparency = 0.3, BackgroundColor3 = T.Card}, 0.12) end)

            btn.MouseButton1Click:Connect(function()
                local pf = getgenv().Settings.prefix
                local fc = pf .. d.cmd
                if d.ha and argBox and argBox.Text ~= "" then fc = fc .. " " .. argBox.Text end
                ChatSend(fc)
                local curC = btn.BackgroundColor3
                Tw(btn, {BackgroundColor3 = T.Green}, 0.1)
                task.delay(0.2, function() Tw(btn, {BackgroundColor3 = curC}, 0.2) end)
            end)

            table.insert(allCmdBtns, {btn = btn, def = d, sec = sec})
        end
    end

    ----------------------------------------------------------------
    -- SEARCH FILTER
    ----------------------------------------------------------------
    SB:GetPropertyChangedSignal("Text"):Connect(function()
        local q = SB.Text:lower()
        local visibleSections = {}
        for _, e in ipairs(allCmdBtns) do
            local show = q == "" or e.def.cmd:find(q, 1, true) or e.def.desc:lower():find(q, 1, true) or e.sec.name:lower():find(q, 1, true)
            e.btn.Visible = show
            if show then visibleSections[e.sec.name] = true end
        end
        for _, child in ipairs(listPage:GetChildren()) do
            if child:IsA("Frame") and child.Name == "Frame" then
                local lbl = child:FindFirstChildOfClass("TextLabel")
                if lbl then
                    child.Visible = q == "" or visibleSections[lbl.Text] or false
                end
            end
        end
    end)

    ----------------------------------------------------------------
    -- GLOBAL STOP BUTTON
    ----------------------------------------------------------------
    local stopBtn = C("TextButton",{
        Name = "GlobalStopBtn",
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 1, -36),
        BackgroundColor3 = T.Red,
        BackgroundTransparency = 0.5,
        Text = "[ STOP ALL ACTION ]",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 10,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = MF,
    })
    Cn(stopBtn, UDim.new(0, 4))
    stopBtn.MouseEnter:Connect(function() Tw(stopBtn, {BackgroundTransparency=0.1}, 0.1) end)
    stopBtn.MouseLeave:Connect(function() Tw(stopBtn, {BackgroundTransparency=0.5}, 0.1) end)
    stopBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "stop")
        local curC = stopBtn.BackgroundColor3
        Tw(stopBtn, {BackgroundColor3 = T.Green}, 0.1)
        task.delay(0.2, function() Tw(stopBtn, {BackgroundColor3 = curC}, 0.2) end)
    end)

    ----------------------------------------------------------------
    -- MINIMIZE / CLOSE / RESTORE
    ----------------------------------------------------------------
    local function MinimizeGUI()
        Tw(MF, {Size = UDim2.new(0, 0, 0, 0)}, 0.25, Enum.EasingStyle.Back)
        task.delay(0.25, function()
            MF.Visible = false
            iconBtn.Visible = true
            Tw(iconBtn, {BackgroundTransparency = 0.2}, 0.15)
        end)
    end

    local function RestoreGUI()
        iconBtn.Visible = false
        MF.Visible = true
        Tw(MF, {Size = UDim2.new(0, WW, 0, WH)}, 0.35, Enum.EasingStyle.Back)
    end

    minBtn.MouseButton1Click:Connect(MinimizeGUI)
    closeBtn.MouseButton1Click:Connect(MinimizeGUI)
    iconBtn.MouseButton1Click:Connect(RestoreGUI)

    UIS.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            if MF.Visible then MinimizeGUI() else RestoreGUI() end
        end
    end)
end
-- ═══════════════════════════════════════════════════════════
--  INVISIBLE (emote-based, no GUI)
-- ═══════════════════════════════════════════════════════════
do
    local INVIS_EMOTE_ID = 92018855869257
    _G.InvisEnabled = false
    _G.InvisEmoteTrack = nil
    local invisCharConns = {}

    local function urlToId(id)
        id = string.gsub(id, "http://www%.roblox%.com/asset/%?id=", "")
        id = string.gsub(id, "rbxassetid://", "")
        return id
    end

    local function isDancing(character, animationTrack)
        local animId = urlToId(animationTrack.Animation.AnimationId)
        local animate = character:FindFirstChild("Animate")
        if not animate then return true end
        for _, holder in ipairs(animate:GetChildren()) do
            if holder:IsA("StringValue") then
                for _, anim in ipairs(holder:GetChildren()) do
                    if anim:IsA("Animation") and urlToId(anim.AnimationId) == animId then
                        return false
                    end
                end
            end
        end
        return true
    end

    local function stopInvisEmote()
        if _G.InvisEmoteTrack then
            pcall(function() _G.InvisEmoteTrack:Stop() end)
            _G.InvisEmoteTrack = nil
        end
    end

    local function playInvisEmote(humanoid, emoteId)
        stopInvisEmote()
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. tostring(emoteId)
        local success, animTrack = pcall(function()
            return humanoid.Animator:LoadAnimation(animation)
        end)
        if not success or not animTrack then return false end
        _G.InvisEmoteTrack = animTrack
        _G.InvisEmoteTrack.Priority = Enum.AnimationPriority.Action
        _G.InvisEmoteTrack.Looped = true
        task.wait(0.1)
        if _G.InvisEnabled then
            _G.InvisEmoteTrack:Play()
            pcall(function() _G.InvisEmoteTrack:AdjustSpeed(1.0) end)
        end
        return true
    end

    local function setupInvisCharacter(character)
        for _, c in pairs(invisCharConns) do pcall(function() c:Disconnect() end) end
        invisCharConns = {}
        _G.InvisEmoteTrack = nil

        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        local animator = humanoid:WaitForChild("Animator", 10)
        if not animator then return end

        table.insert(invisCharConns, animator.AnimationPlayed:Connect(function(animationTrack)
            if not _G.InvisEnabled then return end
            if not isDancing(character, animationTrack) then return end
            local playedId = urlToId(animationTrack.Animation.AnimationId)
            if playedId == "" or playedId == "0" then return end
            if _G.InvisEmoteTrack then
                if urlToId(_G.InvisEmoteTrack.Animation.AnimationId) == playedId then return end
                stopInvisEmote()
            end
            pcall(function() animationTrack:Stop() end)
            task.spawn(function() playInvisEmote(humanoid, playedId) end)
        end))

        table.insert(invisCharConns, humanoid.Died:Connect(function()
            _G.InvisEnabled = false
            stopInvisEmote()
        end))
    end

    if LocalPlayer.Character then task.spawn(function() setupInvisCharacter(LocalPlayer.Character) end) end
    getgenv().TrackConnection(LocalPlayer.CharacterAdded:Connect(function(c)
        task.spawn(function() setupInvisCharacter(c) end)
    end))

    Commands.invisible = function(args, speaker)
        if not IsSoloCommand(args) then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        _G.InvisEnabled = true
        pcall(function() hum:PlayEmoteAndGetAnimTrackById(INVIS_EMOTE_ID) end)
        task.delay(0.6, function()
            if _G.InvisEnabled and (not _G.InvisEmoteTrack or not _G.InvisEmoteTrack.IsPlaying) then
                local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then task.spawn(function() playInvisEmote(h, INVIS_EMOTE_ID) end) end
            end
        end)
    end
    Commands.invis = Commands.invisible

    Commands.visible = function(args, speaker)
        if not IsSoloCommand(args) then return end
        _G.InvisEnabled = false
        stopInvisEmote()
    end
    Commands.vis = Commands.visible
    Commands.hide = Commands.invisible
    Commands.show = Commands.visible
end

-- ═══════════════════════════════════════════════════════════
--  MUSIC BOT COMMANDS (merged from MusicBots.lua)
--  Uses "/" prefix, only designated bot contacts server
-- ═══════════════════════════════════════════════════════════
local MusicCommands = {}

MusicCommands.play = function(player, args, rawMessage)
    local prefix = getgenv().Settings.musicPrefix
    local query = rawMessage:sub(#prefix + 5):gsub("^%s+", ""):gsub("%s+$", "")
    if #query < 2 then musicChat("❌ Search query too short!"); return end

    local now = os.time()
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then
        local cd = getgenv().Settings.musicPlayCooldown or 10
        if MusicState.lastPlayTime[player.Name] and (now - MusicState.lastPlayTime[player.Name]) < cd then
            local rem = cd - (now - MusicState.lastPlayTime[player.Name])
            musicChat(string.format("⏳ @%s wait %d seconds", player.Name, rem))
            return
        end
    end
    MusicState.lastPlayTime[player.Name] = now
    musicChat("🔍 Searching: " .. query)
    task.spawn(function()
        local resp = musicRequest("/play", { query = query, user = player.Name })
        if resp then
            if resp.wait_seconds then
                musicChat(string.format("⏳ Wait %d seconds", resp.wait_seconds))
            elseif resp.reason == "already_playing" then
                musicChat("🎵 That song is already playing!")
            elseif resp.reason == "in_queue" then
                musicChat("📋 That song is already in the queue!")
            elseif resp.error then
                musicChat("❌ " .. resp.error)
            elseif resp.status == "queued" then
                local title = resp.title and ("✅ Queued: " .. resp.title) or "✅ Queued!"
                musicChat(title)
                if resp.queue_position and resp.queue_position > 1 then
                    task.wait(1); musicChat(string.format("📋 Position: #%d", resp.queue_position))
                end
            else musicChat("✅ Request sent!") end
        else musicChat("Ahh Not Sure if ur song got added man, check /queue.") end
    end)
end

MusicCommands.pause = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "pause", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("⛔ You don't have permission!")
            elseif resp.status == "paused" then musicChat("⚠️ Music paused") end
        end
    end)
end

MusicCommands.resume = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "resume", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("⛔ You don't have permission!")
            elseif resp.status == "resumed" then musicChat("✔️ Music resumed") end
        end
    end)
end
MusicCommands.continue = function(p, a) MusicCommands.resume(p, a) end

MusicCommands.skip = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "skip", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("⛔ You don't have permission!")
            elseif resp.status == "skipped" then musicChat("🎵 Skipped current song") end
        end
    end)
end

MusicCommands.musicstop = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "stop", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("⛔ You don't have permission!")
            elseif resp.status == "stopped" then musicChat("✔️ Stopped and cleared queue") end
        end
    end)
end

MusicCommands.volume = function(player, args)
    if not getgenv().Settings.musicEnableVolume then musicChat("❌ Volume control disabled"); return end
    local vol = tonumber(args[2])
    if not vol or vol < 0 or vol > 100 then musicChat("❌ Usage: /volume <0-100>"); return end
    task.spawn(function()
        local resp = musicRequest("/control", { action = "volume", value = vol / 100, user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("⛔ You don't have permission!")
            elseif resp.status == "ok" then musicChat(string.format("🔊 Volume set to %d%%", vol)) end
        end
    end)
end

MusicCommands.status = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/status")
        if resp then
            if resp.current_song then
                musicChat("🎵 Now: " .. resp.current_song.title)
                if resp.playback_position and resp.playback_position > 0 then
                    local mins = math.floor(resp.playback_position / 60)
                    local secs = math.floor(resp.playback_position % 60)
                    musicChat(string.format("⏱️ Position: %d:%02d", mins, secs))
                end
                if resp.queue_size > 0 then musicChat(string.format("📋 Queue: %d songs", resp.queue_size)) end
                musicChat(string.format("🔊 Volume: %d%%", math.floor(resp.volume * 100)))
            else
                musicChat("🙄 Nothing playing")
                if resp.queue_size > 0 then musicChat(string.format("📋 Queue: %d songs waiting", resp.queue_size)) end
            end
        end
    end)
end

MusicCommands.nowplaying = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/nowplaying")
        if resp then
            if resp.playing and resp.title then
                musicChat("🎵 Now Playing: " .. resp.title)
                if resp.position and resp.position > 0 then
                    local mins = math.floor(resp.position / 60)
                    local secs = math.floor(resp.position % 60)
                    local pauseTag = resp.is_paused and " (PAUSED)" or ""
                    musicChat(string.format("⏱️ %d:%02d%s", mins, secs, pauseTag))
                end
                if resp.username then musicChat("👤 Requested by: " .. resp.username) end
                musicChat(string.format("🔊 Volume: %d%%", math.floor((resp.volume or 0.7) * 100)))
            else
                musicChat("🙄 Nothing playing right now")
            end
        end
    end)
end

MusicCommands.queue = function(player, args)
    if not getgenv().Settings.musicEnableQueue then musicChat("❌ Queue display disabled"); return end
    task.spawn(function()
        local resp = musicRequest("/queue")
        if resp and resp.total > 0 then
            musicChat(string.format("📋 Queue (%d songs):", resp.total))
            for i, item in ipairs(resp.queue) do
                if i <= 5 then musicChat(string.format("%d. %s", item.position, item.title)); task.wait(0.5) end
            end
            if resp.total > 5 then musicChat(string.format("...and %d more", resp.total - 5)) end
        else musicChat("📋 Queue is empty") end
    end)
end

MusicCommands.stats = function(player, args)
    if not getgenv().Settings.musicEnableStats then musicChat("❌ Stats disabled"); return end
    local lookupName = args[2] and (function()
        local tp = FindTarget(args[2], player)
        return tp and tp.Name or args[2]
    end)() or player.Name
    local label = args[2] or player.Name
    task.spawn(function()
        local resp = musicRequest("/stats", { user = lookupName })
        if resp then
            musicChat(string.format("📊 %s's Stats:", label)); task.wait(0.5)
            musicChat(string.format("✔️ Played: %d", resp.songs_played or 0)); task.wait(0.5)
            musicChat(string.format("✔️ Skipped: %d", resp.songs_skipped or 0))
        end
    end)
end

MusicCommands.history = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/history")
        if resp and resp.history then
            if #resp.history > 0 then
                musicChat("📜 Recent history:")
                for i, item in ipairs(resp.history) do
                    if i <= 5 then musicChat(string.format("%d. %s", i, item.title)); task.wait(0.5) end
                end
            else musicChat("📜 No history yet") end
        end
    end)
end

MusicCommands.auth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("⛔ Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("❌ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/authorize", { user = tp.Name })
        if resp and resp.status == "authorized" then musicChat(string.format("✅ %s authorized for controls", tp.DisplayName))
        else musicChat("❌ Failed to authorize user") end
    end)
end

MusicCommands.unauth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("⛔ Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("❌ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/revoke", { user = tp.Name })
        if resp and resp.status == "revoked" then musicChat(string.format("❌ %s unauthorized", tp.DisplayName))
        else musicChat("❌ Failed to revoke user") end
    end)
end

MusicCommands.musicblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("⛔ Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("❌ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/blacklist", { user = tp.Name })
        if resp and resp.status == "blacklisted" then musicChat(string.format("🚫 %s blacklisted", tp.DisplayName))
        else musicChat("❌ Failed to blacklist user") end
    end)
end

MusicCommands.unblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("⛔ Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("❌ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/unblacklist", { user = tp.Name })
        if resp and resp.status == "unblacklisted" then musicChat(string.format("✅ %s removed from blacklist", tp.DisplayName))
        else musicChat("❌ Failed to unblacklist user") end
    end)
end

MusicCommands.musiccmds = function(player, args)
    musicChat("🎵 Music Bot Commands:")
    task.wait(0.5); musicChat("./play <song> - Play a song")
    task.wait(0.5); musicChat("./np - What's playing now")
    task.wait(0.5); musicChat("./status - Full status & queue")
    task.wait(0.5); musicChat("./queue - View queue")
    task.wait(0.5); musicChat("./stats [user] - View statistics")
    task.wait(0.5); musicChat("./history - Recent songs")
    task.wait(0.5); musicChat("🎛️ Need controls? Ask for /auth")
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if isMain then task.wait(0.5); musicChat("👑 Admin: /auth /unauth /blacklist") end
end

MusicCommands.checkauth = function(player, args)
    local lookupName = args[2] and (function()
        local tp = FindTarget(args[2], player)
        return tp and tp.Name or args[2]
    end)() or player.Name
    local label = args[2] or player.Name
    task.spawn(function()
        local resp = musicRequest("/admin/check", { user = lookupName })
        if resp then
            local st = "❌ Not authorized"
            if resp.is_main_account then st = "👑 Main Account (always authorized)"
            elseif resp.is_authorized then st = "✅ Authorized" end
            musicChat(string.format("🔐 %s: %s", label, st))
            if resp.is_blacklisted then musicChat("🚫 (Blacklisted)") end
        end
    end)
end

----------------------------------------------------------------
-- MUSIC BOT CHAT LISTENER (separate / prefix)
----------------------------------------------------------------
local musicCmdMap = {
    play = MusicCommands.play,
    pause = MusicCommands.pause,
    resume = MusicCommands.resume,
    ["continue"] = MusicCommands.continue,
    skip = MusicCommands.skip,
    stop = MusicCommands.musicstop,
    volume = MusicCommands.volume,
    status = MusicCommands.status,
    nowplaying = MusicCommands.nowplaying,
    np = MusicCommands.nowplaying,
    queue = MusicCommands.queue,
    stats = MusicCommands.stats,
    history = MusicCommands.history,
    auth = MusicCommands.auth,
    unauth = MusicCommands.unauth,
    blacklist = MusicCommands.musicblacklist,
    unblacklist = MusicCommands.unblacklist,
    cmds = MusicCommands.musiccmds,
    checkauth = MusicCommands.checkauth,
}

local function SetupMusicListener(p)
    getgenv().TrackConnection(p.Chatted:Connect(function(msg)
        local mPrefix = getgenv().Settings.musicPrefix or "/"
        if not msg or #msg == 0 then return end
        if msg:sub(1, #mPrefix) ~= mPrefix then return end

        local args = msg:split(" ")
        if #args == 0 then return end
        local cmdName = args[1]:sub(#mPrefix + 1):lower()
        local handler = musicCmdMap[cmdName]
        if not handler then return end

        -- Cooldown
        local now = os.time()
        local gcd = getgenv().Settings.musicGlobalCooldown or 3
        if MusicState.lastCommandTime[p.Name] and (now - MusicState.lastCommandTime[p.Name]) < gcd then return end
        MusicState.lastCommandTime[p.Name] = now

        local ok, err = pcall(function() handler(p, args, msg) end)
        if not ok then warn("[MusicBot] Error: " .. tostring(err)) end
    end))
end

for _, p in ipairs(Players:GetPlayers()) do SetupMusicListener(p) end
getgenv().TrackConnection(Players.PlayerAdded:Connect(function(p) SetupMusicListener(p) end))

-- -----------------------------------------------------------

--  GLOBAL BACKGROUND ALIASES
-- -----------------------------------------------------------
do
    Commands.to    = Commands.walkto
    Commands.tpto  = Commands.tp
    Commands.b     = Commands.grab
    Commands.fj    = Commands.loopclone
    Commands.unfj  = Commands.unloopclone
    Commands.re    = Commands.rejoin
    Commands.rj    = Commands.rejoin
    Commands.cd    = Commands.countdown
    Commands.f     = Commands.follow
    Commands.unf   = Commands.unall
    Commands.d     = Commands.dance
    Commands.dance1 = Commands.dance
end

-- ═══════════════════════════════════════════════════════════
--  AI TOOLS (Tool Gen & Zoom, Gui-less, Multi-Bot Scaled)
-- ═══════════════════════════════════════════════════════════
do
    local GenRemote = ReplicatedStorage:WaitForChild("event_generation", 10)
    
    local function notify(title, text, dur)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title=title, Text=text, Duration=dur or 4})
        end)
    end

    _G.GenToolGenerating = false
    _G.ZoomOn = false
    _G.ZoomConn = nil
    _G.DefZoom = nil

    local function setZoom(on)
        _G.ZoomOn = on
        if on then
            _G.DefZoom = LocalPlayer.CameraMaxZoomDistance
            LocalPlayer.CameraMaxZoomDistance = 10000
            if _G.ZoomConn then _G.ZoomConn:Disconnect() end
            _G.ZoomConn = getgenv().TrackConnection(game:GetService("RunService").RenderStepped:Connect(function()
                if LocalPlayer.CameraMaxZoomDistance < 9990 then 
                    LocalPlayer.CameraMaxZoomDistance = 10000 
                end
            end))
            notify("Zoom", "Zoom Out ON", 3)
        else
            if _G.ZoomConn then _G.ZoomConn:Disconnect(); _G.ZoomConn = nil end
            LocalPlayer.CameraMaxZoomDistance = _G.DefZoom or 128
            notify("Zoom", "Zoom Out OFF", 3)
        end
    end

    local function generate(prompt, size)
        if _G.GenToolGenerating then notify("Wait", "Already generating…", 3); return end
        prompt = (prompt or ""):match("^%s*(.-)%s*$")
        if prompt == "" then notify("Error", "Enter a prompt", 3); return end
        size = math.clamp(size or 50, 1, 300)
        
        _G.GenToolGenerating = true
        notify("Generating", '"'..prompt..'" size '..size, 5)
        
        local ok, err = pcall(function() 
            GenRemote:FireServer(prompt, Vector3.new(size, size, size)) 
        end)
        
        _G.GenToolGenerating = false
        if not ok then notify("Error", tostring(err), 5) end
    end

    Commands.gentool = function(args, speaker)
        local shouldRun, newArgs = ParseBotTarget(args)
        if not shouldRun then return end
        
        local rest = table.concat(newArgs, " ", 2)
        if rest == "" then notify("!gentool", "Usage: prefix + gentool [size] [prompt]", 4); return end
        
        local sizeStr, prompt = rest:match("^(%d+)%s+(.+)$")
        if sizeStr and prompt then
            generate(prompt, tonumber(sizeStr))
        else
            notify("!gentool", "You must specify [size] and [prompt]!", 4)
        end
    end

    Commands.zoom = function(args, speaker)
        local shouldRun, _ = ParseBotTarget(args)
        if not shouldRun then return end
        setZoom(true)
    end
    
    Commands.unzoom = function(args, speaker)
        local shouldRun, _ = ParseBotTarget(args)
        if not shouldRun then return end
        setZoom(false)
    end
end

-- ═══════════════════════════════════════════════════════════
--  DAYBREAK CLEANUP ENGINE (merged)
--  Strips visual bloat on alt clients for max performance
--  Keeps: HumanoidRootPart, Humanoid, Head, floors, chat, audio
-- ═══════════════════════════════════════════════════════════

local VISUAL_CLASSES = {
    "SpecialMesh", "FileMesh", "CylinderMesh", "BlockMesh",
    "Texture", "Decal", "SurfaceAppearance",
    "ParticleEmitter", "Fire", "Smoke", "Sparkles",
    "Beam", "Trail", "Explosion",
    "PointLight", "SpotLight", "SurfaceLight",
    "SurfaceGui", "BillboardGui",
    "Highlight", "SelectionBox", "SelectionSphere",
}
local VISUAL_SET = {}
for _, cls in ipairs(VISUAL_CLASSES) do VISUAL_SET[cls] = true end

local STRIP_SET = { MeshPart = true, UnionOperation = true }

local KEEP_IN_CHAR = {
    HumanoidRootPart = true,
    Humanoid = true,
    Head = true,
}

local function IsAnyCharObj(obj)
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c and (obj == c or obj:IsDescendantOf(c)) then return true end
    end
    return false
end

local function CleanLightingEffects()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
            pcall(function() child:Destroy() end)
        end
    end
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
end

local function CleanWorkspaceVisuals()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if IsAnyCharObj(desc) then continue end
        if desc == workspace.CurrentCamera or desc:IsDescendantOf(workspace.CurrentCamera) then continue end
        if desc:IsA("Terrain") then continue end

        if VISUAL_SET[desc.ClassName] then
            pcall(function() desc:Destroy() end)
        elseif STRIP_SET[desc.ClassName] then
            pcall(function()
                desc.Material = Enum.Material.SmoothPlastic
                desc.Reflectance = 0
                desc.TextureID = ""
            end)
            if desc.ClassName == "MeshPart" then
                pcall(function() desc.RenderFidelity = Enum.RenderFidelity.Performance end)
                pcall(function() desc.CollisionFidelity = Enum.CollisionFidelity.Box end)
            end
        elseif desc:IsA("Sound") and not desc:IsDescendantOf(game:GetService("SoundService")) then
            pcall(function() desc.Volume = 0 end)
        end
    end
end

local function CleanOtherPlayerChars()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end

        for _, child in ipairs(char:GetChildren()) do
            if KEEP_IN_CHAR[child.Name] then
                if child:IsA("BasePart") then
                    pcall(function() child.Material = Enum.Material.SmoothPlastic; child.Transparency = 1 end)
                end
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("Decal") or sub:IsA("SpecialMesh") or sub:IsA("SurfaceAppearance")
                        or sub:IsA("Texture") or sub:IsA("ParticleEmitter") or sub:IsA("BillboardGui") then
                        pcall(function() sub:Destroy() end)
                    end
                end
            elseif child:IsA("Humanoid") then
                -- keep
            elseif child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants")
                or child:IsA("ShirtGraphic") or child:IsA("BodyColors") or child:IsA("CharacterMesh") then
                pcall(function() child:Destroy() end)
            elseif child:IsA("BasePart") then
                pcall(function() child.Transparency = 1; child.Material = Enum.Material.SmoothPlastic end)
                for _, sub in ipairs(child:GetChildren()) do
                    if not sub:IsA("Motor6D") and not sub:IsA("Weld") then
                        pcall(function() sub:Destroy() end)
                    end
                end
            elseif not child:IsA("Script") and not child:IsA("LocalScript")
                and not child:IsA("Animator") and not child:IsA("Motor6D") then
                pcall(function() child:Destroy() end)
            end
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("MeshPart") then
                pcall(function() part.TextureID = ""; part.Transparency = 1 end)
            end
        end
    end
end

local function CleanTerrain()
    pcall(function()
        local t = workspace:FindFirstChildOfClass("Terrain")
        if t then
            t.Decoration = false
            t.WaterWaveSize = 0; t.WaterWaveSpeed = 0
            t.WaterReflectance = 0; t.WaterTransparency = 0
        end
    end)
end

local function CleanGuis()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local keep = { Chat=true, DayBreakCommandGUI=true, BubbleChat=true, TopBarApp=true }
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and not keep[gui.Name] then
            local n = gui.Name:lower()
            if not (n:find("chat") or n:find("topbar") or n:find("core") or n:find("roblox")) then
                pcall(function() gui.Enabled = false end)
            end
        end
    end
end

local function StartContinuousCleanup()
    getgenv().TrackConnection(Players.PlayerAdded:Connect(function(player)
        getgenv().TrackConnection(player.CharacterAdded:Connect(function()
            task.wait(2)
            CleanOtherPlayerChars()
        end))
    end))

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            getgenv().TrackConnection(p.CharacterAdded:Connect(function()
                task.wait(2)
                CleanOtherPlayerChars()
            end))
        end
    end

    getgenv().TrackConnection(workspace.DescendantAdded:Connect(function(desc)
        if VISUAL_SET[desc.ClassName] and not IsAnyCharObj(desc) then
            task.defer(function()
                if desc.Parent and not IsAnyCharObj(desc) then
                    pcall(function() desc:Destroy() end)
                end
            end)
        end
    end))
end

-- ═══════════════════════════════════════════════════════════
--  AUTO-SYNC ENGINE
--  Measures ping & adjusts bot timing for music/movement sync
-- ═══════════════════════════════════════════════════════════
local function GetPingMs()
    local ok, ping = pcall(function()
        return LocalPlayer:GetNetworkPing() * 1000
    end)
    return ok and ping or 100
end

local function StartAutoSync()
    task.spawn(function()
        while _G.DayBreakActive do
            local ping = GetPingMs()
            _G.DayBreakPing = ping
            _G.DayBreakSyncOffset = ping / 1000

            if ping > 200 then
                _G.DayBreakTickRate = 0.15
            elseif ping > 100 then
                _G.DayBreakTickRate = 0.08
            else
                _G.DayBreakTickRate = 0.03
            end

            local memKB = collectgarbage("count")
            if memKB > 200000 then
                collectgarbage("collect")
            end

            task.wait(5)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  OPTIMIZATION & OVERLAY (main entry)
-- ═══════════════════════════════════════════════════════════
local function OptimizeAndOverlay()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() if setfpscap then setfpscap(getgenv().Settings.fpsCap or 10) end end)
    if getgenv().Settings.lowRamMode then
        ApplyRenderMode(false)
    end

    CleanLightingEffects()
    CleanTerrain()

    task.spawn(function()
        CleanWorkspaceVisuals()
        CleanOtherPlayerChars()
        CleanGuis()
        print("[DayBreak Cleanup] In-game optimization complete")
    end)

    StartContinuousCleanup()
    StartAutoSync()

    local myIndex = SafeIndex()
    local SG = Instance.new("ScreenGui")
    SG.IgnoreGuiInset = true
    SG.ResetOnSpawn = false
    SG.DisplayOrder = -1
    SG.Name = "StealthOverlay"
    local guiParent = LocalPlayer:FindFirstChild("PlayerGui")
    if guiParent then SG.Parent = guiParent end

    local Background = Instance.new("Frame")
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Background.BorderSizePixel = 0
    Background.Parent = SG

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(0.8, 0, 0.4, 0)
    InfoLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    InfoLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    InfoLabel.Font = Enum.Font.Code
    InfoLabel.TextSize = 22
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Center
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    InfoLabel.Text = string.format(
        "ALT Control | Designed by DayBreak\n" ..
        "Join Discord: https://discord.gg/kfxRmYzp3t\n\n" ..
        "USER: %s\n" ..
        "BOT POSITION: %02d",
        LocalPlayer.Name,
        myIndex
    )
    InfoLabel.Parent = Background
end

if LocalPlayer.Name ~= getgenv().Settings.mainAccount then
    OptimizeAndOverlay()
    
    if getgenv().Settings.announceOnLoad then
        local thisRun = _G.DayBreakCurrentRun
        task.spawn(function()
            local idx = SafeIndex() or 1
            task.wait(3.0 + (idx * 1.5))
            if _G.DayBreakActive and _G.DayBreakCurrentRun == thisRun then
                ChatSend("🔥DayBreak Alt Control Loaded.🔥")
            end
        end)
    end
end


-- ═══════════════════════════════════════════════════════════
--  18. INITIALIZE
-- ═══════════════════════════════════════════════════════════
InitAntiAFK()

-- Start VCB Monitor (bots only)
if isAltAccount and not isMainAccount then
    StartVCBMonitor()
end

-- Auto Mic Unmute on Execution (bots only)
if isAltAccount and not isMainAccount and getgenv().Settings.micAutoUnmute then
    task.spawn(function()
        local baseDelay = getgenv().Settings.micUnmuteDelay or 30
        local idx = SafeIndex() or 1
        -- Stagger unmute per bot index (2s gap between each bot)
        -- Prevents all bots clicking the mic button simultaneously
        local staggeredDelay = baseDelay + ((idx - 1) * 2)
        task.wait(staggeredDelay)
        if _G.DayBreakActive then
            doMicUnmute()
            print("[MicToggle] Auto-unmuted bot #" .. idx .. " after " .. staggeredDelay .. "s delay")
        end
    end)
end

-- Music Bot Ready Announcement (designated bot only)
if isAltAccount and shouldMusicExecute() then
    task.spawn(function()
        task.wait(5)
        musicChat("🎵 ˹Music Bot Ready˼ 🎵")
        task.wait(1)
        musicChat("Type /cmds for commands")
    end)
end

print("DayBreak ALT Control | By @DayBreak")
