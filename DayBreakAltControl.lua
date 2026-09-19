--[[
  +==============================================================+
  |               * DAYBREAK ALT CONTROL v3.0 *                  |
  |             NOCTURNAL STARLIGHT & MEME SQUAD EDITION         |
  |                                                              |
  |  Developed by: DayBreak                                      |
  |  Discord: discord.gg/ws5Zb2EzYA                              |
  |  GitHub:  github.com/DayyBreak69/DayBreak-Alt-Control        |
  +==============================================================+
--]]

local _loaderSettings = getgenv().Settings or getgenv().DayBreakSettings

local defaultSettings = {
    -- CONTROLLER & PREFIX
    prefix              = "!",
    mainAccount         = "YOUR_MAIN_ACCOUNT_USERNAME",
    fpsCap              = 10,

    -- ALT ACCOUNTS
    altAccounts         = {
        ["AltAccount1"] = true,
        ["AltAccount2"] = true,
        ["AltAccount3"] = true,
    },

    -- ANNOUNCEMENTS
    announceOnLoad      = true,

    -- LOW RAM & PERFORMANCE
    lowRamMode          = false,

    -- MIC TOGGLE
    micUnmuteDelay      = 30,
    micAutoUnmute       = true,
    micPostRejoinDelay  = 10,

    -- REJOIN & TELEPORT
    rejoinDelay         = 10,
    scriptFile          = "DayBreakAltControl.lua",
    scriptLoadstring    = ""
}

if _loaderSettings and type(_loaderSettings) == "table" then
    for k, v in pairs(_loaderSettings) do
        defaultSettings[k] = v
    end
end
getgenv().Settings = defaultSettings

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
-- CO-HOST & PERMISSION SYSTEM
----------------------------------------------------------------
getgenv().CoHosts = getgenv().CoHosts or {}

Commands.addhost = function(args, speaker)
    if not isMainAccount and not _isPrimaryCreator then return end
    local target = FindTarget(args[2], speaker)
    if target then
        getgenv().CoHosts[target.Name:lower()] = true
        ChatSend("  Added Co-Host: " .. target.Name)
    end
end

Commands.removehost = function(args, speaker)
    if not isMainAccount and not _isPrimaryCreator then return end
    local target = FindTarget(args[2], speaker)
    if target then
        getgenv().CoHosts[target.Name:lower()] = nil
        ChatSend("  Removed Co-Host: " .. target.Name)
    end
end
Commands.unhost = Commands.removehost

Commands.hosts = function(args, speaker)
    local list = {}
    for h in pairs(getgenv().CoHosts) do table.insert(list, h) end
    ChatSend("  Co-Hosts: " .. (#list > 0 and table.concat(list, ", ") or "None"))
end

----------------------------------------------------------------
-- 2. SERVICES & SMART ROLE RESOLUTION
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

local _lpNameLower = LocalPlayer.Name:lower()
local _mainAccSetting = (getgenv().Settings and getgenv().Settings.mainAccount or ""):lower()

-- Creator / Owner Override list
local _isPrimaryCreator = (_lpNameLower == "daybreak" or _lpNameLower == "dayybreak66" or _lpNameLower == "haylees_ekitty" or _lpNameLower == "xomqhayleealt")

local isMainAccount = false
local isAltAccount = false

if _lpNameLower == _mainAccSetting and _mainAccSetting ~= "" and _mainAccSetting ~= "your_main_account_username" then
    -- Current player username matches mainAccount setting: Main Controller!
    isMainAccount = true
    isAltAccount = false
elseif (_mainAccSetting == "your_main_account_username" or _mainAccSetting == "") and _isPrimaryCreator then
    -- Creator fallback if mainAccount setting is unconfigured
    isMainAccount = true
    isAltAccount = false
else
    -- Any account whose username is NOT mainAccount is an ALT BOT!
    isMainAccount = false
    isAltAccount = true
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
-- 4. DATA INITIALIZATION & PERMANENT WHITELIST
----------------------------------------------------------------
-- Permanent Whitelisted Accounts (Always recognized, immune to blacklist)
local PERMANENT_WHITELIST = {
    ["daybreak"] = true,
    ["dayybreak66"] = true,
    ["haylees_ekitty"] = true,
    ["Haylees_Ekitty"] = true,
    ["xomqhayleealt"] = true,
    ["xOmqhayleealt"] = true,
}

local CREATOR_ACCOUNTS = PERMANENT_WHITELIST

getgenv().ManualWhitelist = getgenv().ManualWhitelist or {}
getgenv().ManualWhitelist[getgenv().Settings.mainAccount:lower()] = true
for cName in pairs(PERMANENT_WHITELIST) do
    getgenv().ManualWhitelist[cName] = true
end

local function IsCreator(name)
    if not name then return false end
    return PERMANENT_WHITELIST[name:lower()] == true
end

local function IsWhitelisted(name)
    if not name then return false end
    local nl = name:lower()
    if PERMANENT_WHITELIST[nl] then return true end
    if getgenv().Settings then
        if nl == getgenv().Settings.mainAccount:lower() then return true end
        if getgenv().Settings.altAccounts and getgenv().Settings.altAccounts[nl] then return true end
    end
    if getgenv().ManualWhitelist and getgenv().ManualWhitelist[nl] then return true end
    return false
end

----------------------------------------------------------------
-- 5. CHAT DISPATCHER
----------------------------------------------------------------
local _lastChatText = nil
local _lastChatTime = 0
local function ChatSend(text)
    local now = os.clock()
    if text == _lastChatText and (now - _lastChatTime) < 0.25 then
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
            task.wait(2)
        else
            doMicToggle()
            task.wait(0.5)
            if not isMicMuted() then return end
            task.wait(1)
        end
    end
    warn("[MicToggle] Failed to unmute after 3 attempts")
end

----------------------------------------------------------------
-- 5c. VCB ENGINE (Removed)
----------------------------------------------------------------

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
            if resp.StatusCode == 401 then musicChat("  API key error"); return nil end
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

    -- Method 2: Periodic heartbeat -- proactively simulate input every 60s
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
-- 10. StopAll -- ONLY clears exclusive commands
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
-- 12. COMMAND TABLE
----------------------------------------------------------------
local Commands = {}

-- ===========================================================
--  SYSTEM COMMANDS
-- ===========================================================
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

-- ===========================================================
--  PERSISTENT: noclip / clip
-- ===========================================================
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

-- ===========================================================
--  PERSISTENT: ws / speed
-- ===========================================================
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

-- ===========================================================
--  PERSISTENT: antivoid / unantivoid
-- ===========================================================
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

-- ===========================================================
--  PERSISTENT: spam / unspam
-- ===========================================================
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

-- ===========================================================
--  MOVEMENT COMMANDS
-- ===========================================================

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

-- ===========================================================
--  DAYBREAK MULTI-METHOD EMOTE & SYNC ENGINE
-- ===========================================================
local _emoteAnimationCache = {}

local function ResolveEmoteAnimation(emoteName)
    if not emoteName or emoteName == "" then return nil end
    local query = emoteName:lower()

    if _emoteAnimationCache[query] then
        return _emoteAnimationCache[query]
    end

    if _G.DayBreakEmoteCatalog then
        for _, e in ipairs(_G.DayBreakEmoteCatalog) do
            local name = tostring(e.name or ""):lower()
            if name == query or name:find(query, 1, true) then
                _emoteAnimationCache[query] = tonumber(e.id)
                return tonumber(e.id)
            end
        end
    end
    return nil
end

local function PlayDayBreakEmote(animId, emoteName)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local anim = hum:FindFirstChildOfClass("Animator")

    StopCurrentEmoteTrack()

    -- Method 1: PlayEmote directly through Humanoid
    local m1Ok = pcall(function()
        if emoteName and hum:FindFirstChild("PlayEmote") then
            hum:PlayEmote(emoteName)
            return true
        end
    end)
    if m1Ok then return true end

    -- Method 2: Load Animation directly on Animator with retry
    if anim and animId then
        local animObj = Instance.new("Animation")
        animObj.AnimationId = "rbxassetid://" .. tostring(animId)
        local ok, track = pcall(function() return anim:LoadAnimation(animObj) end)
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action4
            track.Looped = true
            track:Play(0.15)
            _G.CurrentEmoteTrack = track
            return true
        end
    end

    -- Method 3: Animate Script PlayEmote bindable
    local animateScript = char:FindFirstChild("Animate")
    if animateScript and animateScript:FindFirstChild("playEmote") then
        local m3Ok = pcall(function()
            animateScript.playEmote:Invoke(emoteName or tostring(animId))
        end)
        if m3Ok then return true end
    end

    return false
end

Commands.sync = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    local query = table.concat(newArgs, " ", 2):lower()
    if query == "" then return end

    local animId = ResolveEmoteAnimation(query)
    if not animId then
        if SafeIndex() == 1 then ChatSend("Emote not found in catalog") end
        return
    end

    local wasEmoting = _G.CurrentEmoteCommand ~= nil
    ClearEmotesOnly()
    if wasEmoting then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then h.Jump = true end
        task.wait(0.2)
    end

    _G.CurrentEmoteCommand = animId
    local idx = SafeIndex()

    task.spawn(function()
        -- Staggered bot execution prevents Roblox 429 CDN rate limits
        task.wait((idx - 1) * 0.08)
        if _G.CurrentEmoteCommand == animId and _G.DayBreakActive then
            PlayDayBreakEmote(animId, query)
        end
    end)
end

Commands.emote = Commands.sync
Commands.dance = function(args, speaker)
    local sub = args[2] and tostring(args[2]):lower() or "1"
    if sub == "1" or sub == "" then
        Commands.sync({"!sync", "dance"}, speaker)
    elseif sub == "2" then
        Commands.sync({"!sync", "dance2"}, speaker)
    elseif sub == "3" then
        Commands.sync({"!sync", "dance3"}, speaker)
    else
        Commands.sync(args, speaker)
    end
end

Commands.unemote = function(args, speaker)
    StopCurrentEmoteTrack()
    ClearEmotesOnly()
    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if h then h.Jump = true end
    if SafeIndex() == 1 then ChatSend("Emotes stopped") end
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

-- ===========================================================
--  CLONE COMMANDS (loopclone is now PERSISTENT)
-- ===========================================================
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

-- ===========================================================
--  WORM
-- ===========================================================
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

-- ===========================================================
--  STALK
-- ===========================================================
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

-- ===========================================================
--  DANCE & EMOTE (solo-guarded)
-- ===========================================================
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

-- ===========================================================
--  EMOTE SYSTEM (Dynamic Catalog)
-- ===========================================================
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

-- ===========================================================
--  NPC (wander 30-60s, no duplicate targets, unique lines)
-- ===========================================================
Commands.npc = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); _G.CurrentCommand = "NPC"

    local phrases = {
        -- Original Classics
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

        -- Unhinged & Sarcastic Life Humor
        "I'm not arguing, I'm just explaining why I'm right.",
        "My brain has too many tabs open and 4 of them are playing music.",
        "I have a PhD in making bad decisions quickly.",
        "I'm one minor inconvenience away from an existential crisis.",
        "I don't hold grudges. I remember facts.",
        "My sleep schedule is currently being held together by hope and caffeine.",
        "I'm not lazy, I'm on energy-saving mode.",
        "Common sense is like deodorant. The people who need it most never use it.",
        "I entered a staring contest with my thoughts and lost.",
        "I put the 'pro' in procrastinate.",

        -- Existential Robot & NPC Humor
        "Press E to interact... oh wait, you can't.",
        "I used to be an adventurer like you, then I got scripted into an alt.",
        "I am legally obligated to stand here and look mysterious.",
        "Error 404: Emotion not found. Please try snacks.",
        "I have no thoughts, just vibes and a high ping.",
        "I'm only speaking because the main account pressed Enter.",
        "My entire existence is running on 10 FPS.",
        "Do you have a side quest for me or can I go back to buffering?",
        "I'm not a bot, I'm just socially awkward with fast Wi-Fi.",
        "If I freeze, it's not a feature, it's a personality trait.",

        -- Roblox & Gamer Brainrot Humor
        "Chat is this real?",
        "My ping is higher than my credit score.",
        "I didn't lose, I just participated in an educational defeat.",
        "Bro thought he was the main character.",
        "I'm not lagging, the server is just processing my greatness.",
        "Warning: Approaching this bot may cause emotional damage.",
        "Skill issue detected within a 10-stud radius.",
        "I speak two languages: English and Bad Decisions.",
        "Who let this NPC cook?!",
        "Standing here waiting for my plot armor to kick in.",
        "Negative aura detected within a 15-stud radius.",
        "I didn't choose the alt life, the alt script chose me.",
        "Bro is genuinely flabbergasted.",

        -- Dating & Social Chaos
        "I'm a catch. Like a stray ball heading straight for a car window.",
        "I give fantastic advice. I just don't follow a single word of it.",
        "My standards are high, but my impulse control is non-existent.",
        "I'm 90% water and 10% unresolved drama.",
        "I'm not ghosting, I'm just living in offline mode.",
        "My red flags are festive. Like Christmas decorations.",
        "Looking for someone to blame my life decisions on.",
        "I don't need a relationship, I need 8 hours of uninterrupted sleep.",

        -- Cryptic & Menacing NPC Lore
        "The ancient prophecies spoke of this moment... it's much more disappointing than expected.",
        "Do you hear the whispers, or is that just my Discord notification?",
        "I know what you did last summer... you stayed inside and scrolled TikTok.",
        "Beware the void. It charges hourly parking fees.",
        "I've seen the future. It's mostly just loading screens.",
        "You can't spell 'disaster' without 'me' in the middle of it.",
        "I'm not following you, I'm just aggressively existing in the same direction.",

        -- Daily Life & Relatable Struggles
        "I survived another day that definitely should have been an email.",
        "My bank account says no, but my dopamine receptors say buy it.",
        "I'm great at multitasking: I can procrastinate and be stressed simultaneously.",
        "I have a 5-year plan to figure out what I'm doing in the next 5 minutes.",
        "My therapist told me to touch grass so I bought a plastic plant.",
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
                    repeat task.wait(0.1); t = t + 0.1 until done or _G.CurrentCommand ~= "NPC" or t > 10
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
                        repeat task.wait(0.1); t = t + 0.1 until arrived or t > 8 or _G.CurrentCommand ~= "NPC"
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
                            repeat task.wait(0.1); t2 = t2 + 0.1 until d2 or t2 > 6 or _G.CurrentCommand ~= "NPC"
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

-- ===========================================================
--  FIREWORK (solo-guarded)
-- ===========================================================
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

-- ===========================================================
--  NUKE
-- ===========================================================
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

-- ===========================================================
--  SWARM
-- ===========================================================
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

-- ===========================================================
--  MATHEMATICAL CURVE ENGINE -- time-based, deterministic
--  phase = (t / PERIOD + botOffset) * 2    smooth, no drift
-- ===========================================================
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

-- ===========================================================
--  ORBIT CURVES (orbit = basic, orbit1-20 = patterns)
-- ===========================================================
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

-- orbit2: Double helix -- two interleaved strands
OrbitCurves[2] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(sin(phase)*R, sin(phase*0.5)*(R*0.7), cos(phase)*R)
end

-- orbit3: Atomic -- bots on tilted orbital planes
OrbitCurves[3] = function(t, i, count, R)
    local P = 16
    local plane = i % 3
    local gi = math.floor((i-1)/3); local gt = math.max(math.ceil(count/3), 1)
    local phase = (t / P + gi/gt) * PI2
    if plane == 0 then return Vector3.new(cos(phase)*R, sin(phase)*R, 0)
    elseif plane == 1 then return Vector3.new(cos(phase)*R, 0, sin(phase)*R)
    else return Vector3.new(0, cos(phase)*R, sin(phase)*R) end
end

-- orbit4: Galaxy spiral arms -- expanding outward
OrbitCurves[4] = function(t, i, count, R)
    local arms = math.min(3, math.ceil(count/3))
    local arm = (i-1) % arms
    local posInArm = math.floor((i-1)/arms)
    local armAngle = (arm/arms) * PI2
    local dist = 3 + posInArm * 2.5
    local phase = armAngle + posInArm * 0.5 + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i) * 1.5, sin(phase)*dist)
end

-- orbit5: Vertical vortex -- cone helix
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

-- orbit7: Pulsating -- radius breathes in and out
OrbitCurves[7] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local breathe = R + sin(t * 2) * (R * 0.5)
    return Vector3.new(cos(phase)*breathe, sin(t*3 + i)*2, sin(phase)*breathe)
end

-- orbit8: Layered rings -- tilted ring planes
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

-- orbit11: Saturn rings -- flat ring with Y wobble
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

-- orbit13: Electron cloud -- spherical scatter orbit
OrbitCurves[13] = function(t, i, count, R)
    local P = 18
    local golden = i * PI * (3 - sqrt(5))
    local phase = t / P + golden
    local theta = math.acos(1 - 2*((i-0.5)/count))
    return Vector3.new(sin(theta)*cos(phase)*R, cos(theta)*R, sin(theta)*sin(phase)*R)
end

-- orbit14: Ferris wheel -- vertical circle
OrbitCurves[14] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(0, sin(phase)*R, cos(phase)*R)
end

-- orbit15: Cascading waterfall -- staggered heights
OrbitCurves[15] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local yOff = ((i-1)/count) * 12 - 6
    local breathe = R + sin(t*2 + (i-1)/count * PI2) * 3
    return Vector3.new(sin(phase)*breathe, yOff + sin(phase*3)*1.5, cos(phase)*breathe)
end

-- orbit16: Tornado funnel -- radius shrinks upward
OrbitCurves[16] = function(t, i, count, R)
    local P = 12
    local frac = (i-1)/count
    local y = frac * 25 - 12
    local funnelR = R * (1 - frac * 0.7)
    local phase = (t / P + frac * 2) * PI2
    return Vector3.new(sin(phase)*funnelR, y, cos(phase)*funnelR)
end

-- orbit17: Heart pulse -- radius pulses per bot
OrbitCurves[17] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    local beat = 1 + abs(sin(t*3 + i*0.7)) * 0.4
    return Vector3.new(sin(phase)*R*beat, sin(t*2+i)*2, cos(phase)*R*beat)
end

-- orbit18: Comet trails -- elliptical orbits
OrbitCurves[18] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local a, b = R * 1.5, R * 0.6
    return Vector3.new(sin(phase)*a, sin(phase*2)*2, cos(phase)*b)
end

-- orbit19: Mobius twist -- rotating orbital plane
OrbitCurves[19] = function(t, i, count, R)
    local P = 20
    local phase = (t / P + (i-1)/count) * PI2
    local twist = phase * 0.5
    local x = cos(phase) * R
    local flat = sin(phase) * R
    return Vector3.new(x, flat * sin(twist), flat * cos(twist))
end

-- orbit20: Jellyfish -- dome with trailing tentacles
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

-- ===========================================================
--  SPIRAL CURVES (spiral1-20 = patterns)
-- ===========================================================
local SpiralCurves = {}

-- spiral1: Upward helix -- smooth ascending circle
SpiralCurves[1] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local dynR = R + sin(t * 0.5) * 5
    local y = sin(t + (i-1)/count * PI2) * 6
    return Vector3.new(cos(phase)*dynR, y, sin(phase)*dynR)
end

-- spiral2: Cone vortex -- expanding upward
SpiralCurves[2] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local hd = frac * 16; local ht = sin(t + hd) * 4 + hd
    local cr = (ht / 16) * R
    return Vector3.new(cos(phase)*cr, ht, sin(phase)*cr)
end

-- spiral3: DNA ladder -- two interleaved strands
SpiralCurves[3] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local pI = math.floor((i-1)/2)
    local height = (pI / math.max(math.ceil(count/2), 1)) * 16
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(cos(phase)*R, height + sin(t*0.5)*2 - 8, sin(phase)*R)
end

-- spiral4: Dispersal jet -- eruption pattern
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

-- spiral5: Tornado funnel -- tightening upward
SpiralCurves[5] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local height = ((t/P*0.5 + frac*20) % 20)
    local nH = height / 20
    local tR = R * (0.3 + nH * 0.7)
    local phase = (t / P + frac) * PI2 + nH * PI * 4
    return Vector3.new(cos(phase)*tR, height - 10, sin(phase)*tR)
end

-- spiral6: Golden ratio -- Fermat's spiral
SpiralCurves[6] = function(t, i, count, R)
    local ga = i * PI * (3 - sqrt(5))
    local dist = sqrt(i) * 3
    local phase = ga + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i*0.5)*2, sin(phase)*dist)
end

-- spiral7: Bouncing spring -- compression/expansion
SpiralCurves[7] = function(t, i, count, R)
    local P = 10
    local comp = sin(t * 1.5) * 0.5 + 0.5
    local spacing = 2 + comp * 4
    local y = (i - (count+1)/2) * spacing
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(cos(phase)*(R*(0.5+comp*0.5)), y, sin(phase)*(R*(0.5+comp*0.5)))
end

-- spiral8: Inward pool -- shrinking spiral
SpiralCurves[8] = function(t, i, count, R)
    local P = 16
    local frac = (i-1)/count
    local cycle = (t/P*0.4 + frac * PI2) % PI2; local ph = cycle / PI2
    local wR = R * (1 - ph * 0.8)
    local phase = (t / P + frac) * PI2 + ph * PI * 4
    return Vector3.new(cos(phase)*wR, -ph*8 + 4, sin(phase)*wR)
end

-- spiral9: Wavy ascent -- radius waves
SpiralCurves[9] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local wR = R + sin(phase*3 + t) * (R*0.4)
    return Vector3.new(cos(phase)*wR, sin(t + (i-1)/count * PI2)*6, sin(phase)*wR)
end

-- spiral10: Layered cascade -- stacked rotating rings
SpiralCurves[10] = function(t, i, count, R)
    local layers = math.min(4, math.ceil(count/2))
    local layer = (i-1) % layers
    local pil = math.floor((i-1)/layers)
    local bpl = math.max(math.ceil(count/layers), 1)
    local phase = ((pil/bpl) * PI2) + t * (1 + layer*0.3)
    local y = (layer - (layers-1)/2) * 5
    return Vector3.new(cos(phase)*R, y, sin(phase)*R)
end

-- spiral11: Helix staircase -- stepped ascent
SpiralCurves[11] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local step = math.floor(phase / (PI/4)) * 2
    local y = step + sin(phase * 2) * 0.5
    return Vector3.new(sin(phase)*R, y - 8, cos(phase)*R)
end

-- spiral12: Whirlpool -- accelerating inward spiral
SpiralCurves[12] = function(t, i, count, R)
    local P = 20
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local accel = 1 + frac * 2
    local wR = R * (1 - frac * 0.6)
    return Vector3.new(sin(phase*accel)*wR, frac*15 - 7, cos(phase*accel)*wR)
end

-- spiral13: Aurora wave -- flowing sine curtain
SpiralCurves[13] = function(t, i, count, R)
    local spread = ((i-1)/count) * PI2
    local x = sin(spread) * R
    local z = cos(spread) * R
    local wave = sin(t + spread * 2) * 5 + sin(t*1.7 + spread) * 3
    return Vector3.new(x, wave, z)
end

-- spiral14: Firework burst -- expanding outward
SpiralCurves[14] = function(t, i, count, R)
    local golden = i * PI * (3 - sqrt(5))
    local theta = math.acos(1 - 2*((i-0.5)/count))
    local pulse = (sin(t*2) + 1) * 0.5
    local dist = R * (0.3 + pulse * 0.7)
    return Vector3.new(sin(theta)*cos(golden+t*0.3)*dist, cos(theta)*dist, sin(theta)*sin(golden+t*0.3)*dist)
end

-- spiral15: Pendulum -- swinging column
SpiralCurves[15] = function(t, i, count, R)
    local y = ((i-1)/count) * 20 - 10
    local swing = sin(t + y * 0.2) * R * 0.8
    local depth = cos(t * 0.7 + y * 0.15) * R * 0.4
    return Vector3.new(swing, y, depth)
end

-- spiral16: Galaxy arm -- logarithmic spiral
SpiralCurves[16] = function(t, i, count, R)
    local frac = (i-1)/count
    local angle = frac * PI * 6 + t * 0.4
    local dist = 2 + frac * R
    local y = sin(t + frac * PI2) * 2
    return Vector3.new(cos(angle)*dist, y, sin(angle)*dist)
end

-- spiral17: Slinky -- bouncing helix
SpiralCurves[17] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local bounce = abs(sin(t * 1.5)) * 8
    local y = ((i-1)/count) * bounce - bounce/2
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral18: Crown -- tiara pattern
SpiralCurves[18] = function(t, i, count, R)
    local P = 16
    local phase = (t / P + (i-1)/count) * PI2
    local spikes = 5
    local y = abs(sin(phase * spikes)) * 6
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral19: Cyclone eye -- double vortex
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

-- spiral20: Fountain -- rising and falling arcs
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

-- ===========================================================
--  HELICOPTER -- rigid circle around Head, all bots in sync
-- ===========================================================
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
                -- Lie flat: face head, then pitch 90  so feet point at head
                mR.CFrame = CFrame.new(orbitalPos, headPos) * CFrame.Angles(math.rad(90), 0, 0)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.heli = Commands.helicopter

-- ===========================================================
--  QUIT / EXIT / LEAVE
-- ===========================================================
Commands.quit = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); ChatSend("Quitting - Bye " .. tostring(getgenv().Settings.mainAccount))
    task.delay(3, function() LocalPlayer:Kick("DayBreak: Quit") end)
end
Commands.exit = Commands.quit; Commands.leave = Commands.quit

-- ===========================================================
--  SHIELD 1-5
-- ===========================================================
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

-- ===========================================================
--  PING / RAM / CPU
-- ===========================================================
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
                        _originalMaterials[item] = {item.Material, item.CastShadow}
                    end
                    item.Material = Enum.Material.SmoothPlastic
                    item.CastShadow = false
                elseif _originalMaterials[item] then
                    item.Material = _originalMaterials[item][1]
                    item.CastShadow = _originalMaterials[item][2]
                end
            elseif item:IsA("Decal") or item:IsA("Texture") then
                item.Transparency = enable3D and 0 or 1
            elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") or item:IsA("Fire") or item:IsA("Smoke") then
                item.Enabled = enable3D
            end
        end
    end)
end

Commands.ram = function(args, speaker)
    local idx = SafeIndex()
    local memMB = string.format("%.1f", gcinfo() / 1024)
    LocalPlayer:SetAttribute("DayBreakRAM", memMB .. " MB")
    ChatSend(string.format("* Bot #%d Memory: %s MB", idx, memMB))
end
Commands.memory = Commands.ram

Commands.lowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(false)
    if SafeIndex() == 1 then ChatSend("> Ultra-Low RAM Mode Activated (Max FPS)") end
end

Commands.unlowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(true)
    if SafeIndex() == 1 then ChatSend("* Normal Graphics Restored") end
end

Commands.render = function(args, speaker)
    local sub = args[2] and tostring(args[2]):lower() or ""
    if sub == "off" or sub == "low" or sub == "false" or sub == "0" then
        Commands.lowram(args, speaker)
    else
        Commands.unlowram(args, speaker)
    end
end

Commands.cleanram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    local before = gcinfo()
    pcall(function()
        for k in pairs(_emoteAnimationCache or {}) do
            _emoteAnimationCache[k] = nil
        end
    end)
    local after = gcinfo()
    local saved = math.max(0, before - after)
    local idx = SafeIndex()
    local memMB = string.format("%.1f", gcinfo() / 1024)
    LocalPlayer:SetAttribute("DayBreakRAM", memMB .. " MB")
    ChatSend(string.format("[Clean] Bot #%d Cleaned %d KB", idx, saved))
end
Commands.flush = Commands.cleanram
Commands.ramclean = Commands.cleanram

-- ===========================================================
--  VIRAL MEME & TROLL SQUAD COMMANDS (Nocturnal Edition)
-- ===========================================================

-- 1. BODYGUARD FORMATION
Commands.bodyguard = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "bodyguard"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        while _G.CurrentCommand == "bodyguard" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local radius = 6 + (total * 0.3)
                    local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2
                    local offsetX = math.cos(angle) * radius
                    local offsetZ = math.sin(angle) * radius
                    local targetPos = tHrp.Position + Vector3.new(offsetX, 0, offsetZ)

                    local targetLook = targetPos + (targetPos - tHrp.Position).Unit * 10
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(targetLook.X, targetPos.Y, targetLook.Z))
                end
            else
                task.wait(0.2)
            end
            task.wait(0.03)
        end
    end)
end

-- 2. RITUAL / CULT SACRIFICE
Commands.ritual = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "ritual"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        local chants = {"* LUX NOCTIS *", "* THE STAR AWAKENS *", "* CONSUME THE LIGHT *", "* DAYBREAK ASCENDS *"}
        local chantTimer = 0
        local spinAngle = 0

        while _G.CurrentCommand == "ritual" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    spinAngle = (spinAngle + 0.04) % (math.pi * 2)
                    local radius = 8
                    local angle = spinAngle + (((idx - 1) / math.max(1, total)) * math.pi * 2)
                    local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
                end
                chantTimer = chantTimer + 1
                if chantTimer >= 60 and idx == 1 then
                    chantTimer = 0
                    ChatSend(chants[math.random(1, #chants)])
                end
            else
                task.wait(0.2)
            end
            task.wait(0.03)
        end
    end)
end

-- 3. PAPARAZZI FLASH MOB
Commands.paparazzi = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "paparazzi"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        local lines = {"[Photo] Look over here!", "[Photo] Give us a smile!", "[Photo] Who are you wearing?", "[Photo] Exclusive interview!"}
        local flashTimer = 0

        while _G.CurrentCommand == "paparazzi" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local dist = 5 + (idx * 0.8)
                    local angle = ((idx - 1) / math.max(1, total)) * math.pi
                    local facing = tHrp.CFrame.LookVector
                    local right = tHrp.CFrame.RightVector
                    local targetPos = tHrp.Position + (facing * (dist * 0.7)) + (right * (math.sin(angle) * 6))
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, tHrp.Position)
                end
                flashTimer = flashTimer + 1
                if flashTimer >= 40 and idx == ((tick() % total) + 1) then
                    flashTimer = 0
                    ChatSend(lines[math.random(1, #lines)])
                end
            else
                task.wait(0.2)
            end
            task.wait(0.04)
        end
    end)
end

-- 4. COFFIN DANCE
Commands.coffin = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "coffin"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        local tOffset = 0
        while _G.CurrentCommand == "coffin" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local side = (idx % 2 == 0) and 1 or -1
                    local row = math.floor((idx - 1) / 2)
                    local right = tHrp.CFrame.RightVector
                    local back = -tHrp.CFrame.LookVector
                    tOffset = (tOffset + 0.1) % (math.pi * 2)
                    local bob = math.sin(tOffset + idx) * 0.8
                    local targetPos = tHrp.Position + (right * (side * 4)) + (back * (row * 3)) + Vector3.new(0, bob, 0)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + tHrp.CFrame.LookVector)
                end
            else
                task.wait(0.2)
            end
            task.wait(0.04)
        end
    end)
end

-- 5. CONGA LINE
Commands.conga = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "conga"
    local idx = SafeIndex()

    task.spawn(function()
        local animStep = 0
        while _G.CurrentCommand == "conga" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    animStep = (animStep + 0.12) % (math.pi * 2)
                    local hop = math.abs(math.sin(animStep + (idx * 0.4))) * 1.2
                    local back = -tHrp.CFrame.LookVector
                    local targetPos = tHrp.Position + (back * (idx * 3.5)) + Vector3.new(0, hop, 0)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + tHrp.CFrame.LookVector)
                end
            else
                task.wait(0.2)
            end
            task.wait(0.03)
        end
    end)
end

-- 6. OMINOUS STARE (Silent Intimidation)
Commands.stare = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "stare"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        while _G.CurrentCommand == "stare" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2
                    local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
                end
            else
                task.wait(0.2)
            end
            task.wait(0.05)
        end
    end)
end

-- 7. TORNADO VORTEX SPIN
Commands.tornado = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "tornado"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        local spin = 0
        while _G.CurrentCommand == "tornado" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    spin = (spin + 0.15) % (math.pi * 2)
                    local height = (idx / math.max(1, total)) * 14
                    local radius = 3 + (height * 0.4)
                    local angle = spin + (((idx - 1) / math.max(1, total)) * math.pi * 2)
                    local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
                end
            else
                task.wait(0.2)
            end
            task.wait(0.02)
        end
    end)
end

-- 8. CREEPER (Red Light Green Light Stealth)
Commands.creeper = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "creeper"
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "creeper" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local myHrp = myChar.HumanoidRootPart
                    local toBot = (myHrp.Position - tHrp.Position).Unit
                    local facing = tHrp.CFrame.LookVector
                    local dot = toBot:Dot(facing)

                    if dot < 0.2 then
                        local stepDir = (tHrp.Position - myHrp.Position).Unit
                        local newPos = myHrp.Position + (stepDir * 0.6)
                        if (newPos - tHrp.Position).Magnitude > 3 then
                            myHrp.CFrame = CFrame.lookAt(newPos, tHrp.Position)
                        end
                    end
                end
            else
                task.wait(0.2)
            end
            task.wait(0.04)
        end
    end)
end

-- ===========================================================
--  ULTIMATE ENGINE: VFX PALETTES, SOUND FX & BOT CHECKBOXES
-- ===========================================================
getgenv().DayBreakSFX = getgenv().DayBreakSFX or { Enabled = true }
getgenv().SelectedBots = getgenv().SelectedBots or {}

local function PlaySFX(soundId)
    if not getgenv().DayBreakSFX.Enabled then return end
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = soundId or "rbxassetid://6895079853" -- Cyber click sound
        sound.Volume = 0.5
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 1.5)
    end)
end
getgenv().PlaySFX = PlaySFX

-- VFX Color Presets
local VFXColors = {
    purple  = {Fill = Color3.fromRGB(139, 92, 246),  Outline = Color3.fromRGB(6, 182, 212)},
    cyan    = {Fill = Color3.fromRGB(6, 182, 212),   Outline = Color3.fromRGB(59, 130, 246)},
    gold    = {Fill = Color3.fromRGB(245, 158, 11),  Outline = Color3.fromRGB(251, 191, 36)},
    red     = {Fill = Color3.fromRGB(239, 68, 68),   Outline = Color3.fromRGB(248, 113, 113)},
    green   = {Fill = Color3.fromRGB(16, 185, 129),  Outline = Color3.fromRGB(52, 211, 153)},
    pink    = {Fill = Color3.fromRGB(236, 72, 153),  Outline = Color3.fromRGB(244, 114, 182)},
}

VFX.CurrentPalette = "purple"

-- Update VFX.Update to use VFXColors Palette
local original_VFX_Update = VFX.Update
VFX.Update = function()
    local _lpName = LocalPlayer.Name:lower()
    local isHost = isMainAccount or _isPrimaryCreator or (getgenv().CoHosts and getgenv().CoHosts[_lpName])
    if not isHost then return end

    VFX.Clear()

    local bots = GetActiveBots()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    local pal = VFXColors[VFX.CurrentPalette] or VFXColors["purple"]

    -- 1. Bot Highlights
    if VFX.Highlights then
        for _, bot in ipairs(bots) do
            if bot.Character then
                local hl = Instance.new("Highlight")
                hl.Name = "DayBreakBotHL"
                hl.Adornee = bot.Character
                hl.FillColor = VFX.Rainbow and Color3.fromHSV((tick() % 5) / 5, 0.9, 1) or pal.Fill
                hl.OutlineColor = VFX.Rainbow and Color3.fromHSV(((tick() + 1) % 5) / 5, 0.9, 1) or pal.Outline
                hl.FillTransparency = 0.4
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = bot.Character
                table.insert(VFX.ActiveObjects, hl)
            end
        end
    end

    -- 2. Laser Grid Beams
    if VFX.Lasers and myHrp then
        local controllerAttach = Instance.new("Attachment")
        controllerAttach.Name = "DayBreakVFXAttach"
        controllerAttach.Parent = myHrp
        table.insert(VFX.ActiveObjects, controllerAttach)

        for _, bot in ipairs(bots) do
            local bHrp = bot.Character and bot.Character:FindFirstChild("HumanoidRootPart")
            if bHrp then
                local botAttach = Instance.new("Attachment")
                botAttach.Name = "DayBreakVFXBotAttach"
                botAttach.Parent = bHrp
                table.insert(VFX.ActiveObjects, botAttach)

                local beam = Instance.new("Beam")
                beam.Name = "DayBreakLaser"
                beam.Attachment0 = controllerAttach
                beam.Attachment1 = botAttach
                beam.Color = ColorSequence.new(
                    VFX.Rainbow and Color3.fromHSV((tick() % 5) / 5, 1, 1) or pal.Fill,
                    VFX.Rainbow and Color3.fromHSV(((tick() + 1) % 5) / 5, 1, 1) or pal.Outline
                )
                beam.Width0 = 0.35
                beam.Width1 = 0.35
                beam.TextureSpeed = 3
                beam.FaceCamera = true
                beam.Parent = workspace
                table.insert(VFX.ActiveObjects, beam)
            end
        end
    end

    -- 3. Cosmic Trails
    if VFX.Trails then
        for _, bot in ipairs(bots) do
            local bHrp = bot.Character and bot.Character:FindFirstChild("HumanoidRootPart")
            if bHrp then
                local a0 = Instance.new("Attachment")
                a0.Position = Vector3.new(0, 1, 0)
                a0.Parent = bHrp
                local a1 = Instance.new("Attachment")
                a1.Position = Vector3.new(0, -1, 0)
                a1.Parent = bHrp
                table.insert(VFX.ActiveObjects, a0)
                table.insert(VFX.ActiveObjects, a1)

                local trail = Instance.new("Trail")
                trail.Attachment0 = a0
                trail.Attachment1 = a1
                trail.Lifetime = 0.8
                trail.Color = ColorSequence.new(pal.Fill, pal.Outline)
                trail.Transparency = NumberSequence.new(0.2, 1)
                trail.Parent = bHrp
                table.insert(VFX.ActiveObjects, trail)
            end
        end
    end

    -- 4. Target Lock Beacon
    if VFX.Target and VFX.Target.Character then
        local tHrp = VFX.Target.Character:FindFirstChild("HumanoidRootPart")
        if tHrp then
            local targetHl = Instance.new("Highlight")
            targetHl.Name = "DayBreakTargetHL"
            targetHl.Adornee = VFX.Target.Character
            targetHl.FillColor = Color3.fromRGB(239, 68, 68)
            targetHl.OutlineColor = Color3.fromRGB(255, 255, 255)
            targetHl.FillTransparency = 0.3
            targetHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            targetHl.Parent = VFX.Target.Character
            table.insert(VFX.ActiveObjects, targetHl)
        end
    end
end

-- Updated VFX Command with Palette Support
local orig_vfx_cmd = Commands.vfx
Commands.vfx = function(args, speaker)
    local mode = args[2] and tostring(args[2]):lower() or ""
    local val = args[3] and tostring(args[3]):lower() or ""

    if mode == "color" or mode == "theme" or mode == "palette" then
        if VFXColors[val] then
            VFX.CurrentPalette = val
            VFX.Rainbow = false
            VFX.Update()
            ChatSend("  VFX Color Set To: " .. val:upper())
        else
            ChatSend("  Available Colors: purple, cyan, gold, red, green, pink, rainbow")
        end
    else
        orig_vfx_cmd(args, speaker)
    end
end

-- ===========================================================
--  REWORKED SMART NPC PLAYER-SEEKING INTERACTION ENGINE (70+ PHRASES)
-- ===========================================================
local NPCPhrases = {
    -- Original Classic Phrases
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

    -- Personal Targeted Callouts (Injects Player Name)
    "Hey {name}, what's up?",
    "Yo {name}, watch out!",
    "Excuse me {name}, have you seen my coffee?",
    "Greetings {name}! Beautiful day in the server, isn't it?",
    "{name}, nice outfit you got on!",
    "Hey {name}, are you the squad leader?",
    "Yo {name}, don't mind me, just walking by!",
    "{name}, do you know what time it is?",
    "Hey {name}, I think someone was looking for you!",
    "Yo {name}, 10/10 fit right there.",
    "Hold on {name}, let me get a quick selfie!",
    "Hey {name}, can I ask you a quick question?",
    "{name}, you look suspiciously like an admin...",
    "Yo {name}, stay safe out there!",
    "Hey {name}, rate my walking animation 1 to 10!",
    "Excuse me {name}, is this the way to spawn?",
    "{name}, stay frosty!",
    "Hey {name}, did you drop your main account?",
    "Yo {name}, nice moves!",
    "Hey {name}, legends say DayBreak is watching!",
    "Greetings {name}, hope you're having a great day!",
    "{name}, you can't see me, right?",
    "Hey {name}, 100% real human right here!",
    "Yo {name}, don't look behind you...",
    "Hey {name}, watch out for flying alts!",
    "{name}, pass me the AUX cord!",
    "Hey {name}, speedrunning life right now!",
    "Yo {name}, carry me to victory!",
    "{name}, do you believe in alt controllers?",
    "Hey {name}, rate the squad 10 out of 10!",
    
    -- General Ambient NPC Banter
    "I'm just an NPC doing NPC things...",
    "Did anyone remember to turn off the stove?",
    "My walking animation is top tier.",
    "Just taking my daily 10,000 steps!",
    "Wait, is this a simulation?",
    "I used to be an adventurer like you...",
    "Beep boop... I mean, hello fellow human!",
    "Press E to talk to NPC.",
    "Searching for quest objectives...",
    "My pathfinding AI is doing its absolute best!",
    "Don't mind me, just completing side quests.",
    "Does this server have good wifi?",
    "I think I left my main in another game...",
    "DayBreak v3.0 running at peak performance!",
    "Who called the alt squad?",
    "NPC mode: ACTIVATED!",
    "Walking... walking... and more walking!",
    "I should have taken a left at Albuquerque.",
    "100% organic, non-GMO Roblox character!",
    "Is anyone taking notes on this?",
    "Loading high-res textures... please wait.",
    "I'm not lost, I'm exploring!",
    "Security check: pass!",
    "Keep calm and carry on walking.",
    "Did someone say DayBreak Alt Control?",
    "VFX glowing in full HD!",
    "Standing guard... or maybe just strolling.",
    "No lag detected in this sector!",
    "My stamina bar is infinite!",
    "Out here living my best digital life.",
    "Check out the smooth 60 FPS motion!",
    "Is it time to emote yet?",
    "Hydration check! Stay hydrated gamers.",
    "Alt fleet reporting for duty!",
    "Just patrolling the perimeter.",
    "Everything is going according to plan!",
    "Smooth walking path calculated.",
    "Hello server! Hope everyone is having fun.",
    "Nocturnal Starlight edition in full effect!",
    "System check: All systems operational!"
}

Commands.npc = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end

    StopAll()
    _G.CurrentCommand = "npc"
    local idx = SafeIndex()

    task.spawn(function()
        local PlayersService = game:GetService("Players")
        
        while _G.CurrentCommand == "npc" and _G.DayBreakActive do
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

            if myHrp and myHum then
                -- Find candidate players to visit (exclude bots & self)
                local candidates = {}
                for _, p in ipairs(PlayersService:GetPlayers()) do
                    if p ~= LocalPlayer and not IsBotPlayer(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
                        if dist < 120 then
                            table.insert(candidates, p)
                        end
                    end
                end

                if #candidates > 0 then
                    -- Pick a random nearby candidate player
                    local targetPlayer = candidates[math.random(1, #candidates)]
                    local tHrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

                    if tHrp then
                        -- Walk up to within 5 studs of the target player
                        local stopDist = 5
                        local walkPos = tHrp.Position + (Vector3.new(math.sin(idx), 0, math.cos(idx)).Unit * stopDist)
                        myHum:MoveTo(walkPos)

                        -- Wait until arrived or timeout
                        local startT = tick()
                        while _G.CurrentCommand == "npc" and (myHrp.Position - walkPos).Magnitude > 3.5 and (tick() - startT) < 6 do
                            task.wait(0.2)
                        end

                        -- Turn to face the player
                        if myHrp and tHrp then
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, Vector3.new(tHrp.Position.X, myHrp.Position.Y, tHrp.Position.Z))
                        end

                        -- Chat randomized NPC phrase with name injection
                        local phrase = NPCPhrases[math.random(1, #NPCPhrases)]
                        local pName = targetPlayer.DisplayName or targetPlayer.Name
                        phrase = phrase:gsub("{name}", pName)

                        task.wait(0.3 + (idx * 0.1))
                        ChatSend(phrase)
                    end
                else
                    -- No nearby players, wander randomly nearby
                    local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
                    myHum:MoveTo(myHrp.Position + offset)
                end
            end

            -- Pause before seeking next player
            task.wait(3.5 + (math.random() * 2.5))
        end
    end)
end

Commands.unnpc = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    if _G.CurrentCommand == "npc" then
        StopAll()
        ChatSend("  NPC Wandering Stopped")
    end
end

-- ===========================================================
getgenv().DayBreakVFX = getgenv().DayBreakVFX or {
    Highlights = false,
    Lasers = false,
    Trails = false,
    Target = nil,
    Rainbow = false,
    ActiveObjects = {}
}

local VFX = getgenv().DayBreakVFX

local function IsBotPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if plr:GetAttribute("DayBreakBot") or plr:GetAttribute("DayBreakRAM") then return true end
    local name = plr.Name:lower()
    if getgenv().Settings and getgenv().Settings.altAccounts and getgenv().Settings.altAccounts[name] then return true end
    return false
end

local function GetActiveBots()
    local bots = {}
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if IsBotPlayer(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(bots, p)
        end
    end
    return bots
end

function VFX.Clear()
    for _, obj in ipairs(VFX.ActiveObjects or {}) do
        pcall(function() obj:Destroy() end)
    end
    VFX.ActiveObjects = {}
end

function VFX.Update()
    local _lpName = LocalPlayer.Name:lower()
    local isHost = isMainAccount or _isPrimaryCreator or (getgenv().CoHosts and getgenv().CoHosts[_lpName])
    if not isHost then return end

    VFX.Clear()

    local bots = GetActiveBots()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- 1. Bot Highlights
    if VFX.Highlights then
        for _, bot in ipairs(bots) do
            if bot.Character then
                local hl = Instance.new("Highlight")
                hl.Name = "DayBreakBotHL"
                hl.Adornee = bot.Character
                hl.FillColor = VFX.Rainbow and Color3.fromHSV((tick() % 5) / 5, 0.9, 1) or Color3.fromRGB(139, 92, 246)
                hl.OutlineColor = Color3.fromRGB(6, 182, 212)
                hl.FillTransparency = 0.4
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = bot.Character
                table.insert(VFX.ActiveObjects, hl)
            end
        end
    end

    -- 2. Laser Grid Beams
    if VFX.Lasers and myHrp then
        local controllerAttach = Instance.new("Attachment")
        controllerAttach.Name = "DayBreakVFXAttach"
        controllerAttach.Parent = myHrp
        table.insert(VFX.ActiveObjects, controllerAttach)

        for _, bot in ipairs(bots) do
            local bHrp = bot.Character and bot.Character:FindFirstChild("HumanoidRootPart")
            if bHrp then
                local botAttach = Instance.new("Attachment")
                botAttach.Name = "DayBreakVFXBotAttach"
                botAttach.Parent = bHrp
                table.insert(VFX.ActiveObjects, botAttach)

                local beam = Instance.new("Beam")
                beam.Name = "DayBreakLaser"
                beam.Attachment0 = controllerAttach
                beam.Attachment1 = botAttach
                beam.Color = ColorSequence.new(
                    VFX.Rainbow and Color3.fromHSV((tick() % 5) / 5, 1, 1) or Color3.fromRGB(139, 92, 246),
                    Color3.fromRGB(6, 182, 212)
                )
                beam.Width0 = 0.35
                beam.Width1 = 0.35
                beam.TextureSpeed = 3
                beam.FaceCamera = true
                beam.Parent = workspace
                table.insert(VFX.ActiveObjects, beam)
            end
        end
    end

    -- 3. Cosmic Trails
    if VFX.Trails then
        for _, bot in ipairs(bots) do
            local bHrp = bot.Character and bot.Character:FindFirstChild("HumanoidRootPart")
            if bHrp then
                local a0 = Instance.new("Attachment")
                a0.Position = Vector3.new(0, 1, 0)
                a0.Parent = bHrp
                local a1 = Instance.new("Attachment")
                a1.Position = Vector3.new(0, -1, 0)
                a1.Parent = bHrp
                table.insert(VFX.ActiveObjects, a0)
                table.insert(VFX.ActiveObjects, a1)

                local trail = Instance.new("Trail")
                trail.Attachment0 = a0
                trail.Attachment1 = a1
                trail.Lifetime = 0.8
                trail.Color = ColorSequence.new(Color3.fromRGB(139, 92, 246), Color3.fromRGB(6, 182, 212))
                trail.Transparency = NumberSequence.new(0.2, 1)
                trail.Parent = bHrp
                table.insert(VFX.ActiveObjects, trail)
            end
        end
    end

    -- 4. Target Lock Beacon
    if VFX.Target and VFX.Target.Character then
        local tHrp = VFX.Target.Character:FindFirstChild("HumanoidRootPart")
        if tHrp then
            local targetHl = Instance.new("Highlight")
            targetHl.Name = "DayBreakTargetHL"
            targetHl.Adornee = VFX.Target.Character
            targetHl.FillColor = Color3.fromRGB(239, 68, 68)
            targetHl.OutlineColor = Color3.fromRGB(255, 255, 255)
            targetHl.FillTransparency = 0.3
            targetHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            targetHl.Parent = VFX.Target.Character
            table.insert(VFX.ActiveObjects, targetHl)
        end
    end
end

-- VFX Render Loop
task.spawn(function()
    while _G.DayBreakActive do
        if VFX.Highlights or VFX.Lasers or VFX.Trails or VFX.Target then
            pcall(VFX.Update)
        end
        task.wait(0.15)
    end
end)

Commands.vfx = function(args, speaker)
    local mode = args[2] and tostring(args[2]):lower() or ""
    local val = args[3] and tostring(args[3]):lower() or ""

    if mode == "highlight" or mode == "hl" then
        VFX.Highlights = (val == "off" or val == "false" or val == "0") and false or not VFX.Highlights
        if VFX.Highlights then VFX.Update() else VFX.Clear() end
        ChatSend("* VFX Highlights: " .. (VFX.Highlights and "ON" or "OFF"))
    elseif mode == "laser" or mode == "lasers" or mode == "beam" then
        VFX.Lasers = (val == "off" or val == "false" or val == "0") and false or not VFX.Lasers
        if VFX.Lasers then VFX.Update() else VFX.Clear() end
        ChatSend("> VFX Lasers: " .. (VFX.Lasers and "ON" or "OFF"))
    elseif mode == "trail" or mode == "trails" then
        VFX.Trails = (val == "off" or val == "false" or val == "0") and false or not VFX.Trails
        if VFX.Trails then VFX.Update() else VFX.Clear() end
        ChatSend("  VFX Trails: " .. (VFX.Trails and "ON" or "OFF"))
    elseif mode == "rainbow" then
        VFX.Rainbow = not VFX.Rainbow
        ChatSend("  VFX Rainbow Mode: " .. (VFX.Rainbow and "ON" or "OFF"))
    elseif mode == "target" then
        local t = FindTarget(args[3], speaker)
        if t then
            VFX.Target = t
            VFX.Update()
            ChatSend("  VFX Target Locked: " .. t.Name)
        else
            VFX.Target = nil
            VFX.Update()
            ChatSend("  VFX Target Cleared")
        end
    elseif mode == "off" or mode == "clear" or mode == "stop" then
        VFX.Highlights = false
        VFX.Lasers = false
        VFX.Trails = false
        VFX.Target = nil
        VFX.Clear()
        ChatSend("  All VFX Disabled")
    else
        ChatSend("* VFX Commands: !vfx [highlight/laser/trail/target/rainbow/off]")
    end
end

-- ===========================================================
--  SMART FORMATIONS ENGINE
-- ===========================================================
Commands.line = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker) or speaker
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "line"
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "line" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local right = tHrp.CFrame.RightVector
                    local offset = ((idx - 1) - (SafeTotal() / 2)) * 3.5
                    local targetPos = tHrp.Position + (right * offset) - (tHrp.CFrame.LookVector * 4)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + tHrp.CFrame.LookVector)
                end
            end
            task.wait(0.04)
        end
    end)
end

Commands.circle = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker) or speaker
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "circle"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        while _G.CurrentCommand == "circle" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local radius = 6 + (total * 0.4)
                    local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2
                    local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
                end
            end
            task.wait(0.04)
        end
    end)
end

Commands.wall = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker) or speaker
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "wall"
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "wall" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local right = tHrp.CFrame.RightVector
                    local offset = ((idx - 1) - (SafeTotal() / 2)) * 3.2
                    local targetPos = tHrp.Position + (right * offset) + (tHrp.CFrame.LookVector * 5)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + tHrp.CFrame.LookVector)
                end
            end
            task.wait(0.04)
        end
    end)
end

Commands.orbit = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker) or speaker
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "orbit"
    local idx = SafeIndex()
    local total = SafeTotal()

    task.spawn(function()
        local spin = 0
        while _G.CurrentCommand == "orbit" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    spin = (spin + 0.05) % (math.pi * 2)
                    local radius = 7
                    local angle = spin + (((idx - 1) / math.max(1, total)) * math.pi * 2)
                    local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                    myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
                end
            end
            task.wait(0.03)
        end
    end)
end

-- 8. CREEPER (Red Light Green Light Stealth)
Commands.creeper = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "creeper"
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "creeper" and _G.DayBreakActive do
            if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local tHrp = target.Character.HumanoidRootPart
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    local myHrp = myChar.HumanoidRootPart
                    local toBot = (myHrp.Position - tHrp.Position).Unit
                    local facing = tHrp.CFrame.LookVector
                    local dot = toBot:Dot(facing)

                    if dot < 0.2 then
                        local stepDir = (tHrp.Position - myHrp.Position).Unit
                        local newPos = myHrp.Position + (stepDir * 0.6)
                        if (newPos - tHrp.Position).Magnitude > 3 then
                            myHrp.CFrame = CFrame.lookAt(newPos, tHrp.Position)
                        end
                    end
                end
            else
                task.wait(0.2)
            end
            task.wait(0.04)
        end
    end)
end
Commands.uncreeper = function(args, speaker)
    StopAll()
    if SafeIndex() == 1 then ChatSend("[DayBreak] Stealth mode deactivated") end
end


-- ===========================================================
--  CARPET / FLOOR / BRIDGE
-- ===========================================================
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

-- ===========================================================
--  SPIN
-- ===========================================================
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

-- ===========================================================
--  VFLING / KILL
-- ===========================================================
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

-- ===========================================================
--  BANG
-- ===========================================================
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

-- ===========================================================
--  FBANG -- no spin fix: lock CFrame every frame
-- ===========================================================
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
                -- Lock facing direction toward target head -- prevents spin
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

-- ===========================================================
--  MIRROR SUITE
-- ===========================================================
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

-- ===========================================================
--  RIZZ -- queue approach, walk close to target, say line
-- ===========================================================
Commands.rizz = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Rizz"
    local lines = {
        "I don't usually get distracted, but you made me forget what I was saying.",
        "You've got that calm energy that makes everything feel easier.",
        "There's something about you that feels different -- in a good way.",
        "I can tell you're not just pretty, you've got depth.",
        "I don't think you realize how naturally attractive your vibe is.",
        "You seem like the kind of person people feel safe around.",
        "I wasn't planning on staying long, but you changed that.",
        "You've got that quiet confidence that's hard to ignore.",
        "I like how you carry yourself. It says a lot.",
        "Talking to you feels way too easy... and I don't mind that at all.",
        "You don't even have to try. That's what makes it dangerous.",
        "I respect how you move -- it's rare.",
        "I don't throw compliments around, but you earned that one.",
        "If energy is real, yours is undefeated.",
        "I'm not even trying to impress you... I just like talking to you.",
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

-- ===========================================================
--  MBANG
-- ===========================================================
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

-- ===========================================================
--  HS 1-20 (Harassment Strike variants)
-- ===========================================================
local HS_MESSAGES = {
    [1]  = "Target locked. Commencing operation.",
    [2]  = "Surrounding target perimeter.",
    [3]  = "DayBreak squad assembled and ready.",
    [4]  = "Deploying tactical wave formation.",
    [5]  = "Target designated for inspection.",
    [6]  = "Alt swarm synchronization 100%.",
    [7]  = "Observing target movements.",
    [8]  = "Perimeter check complete.",
    [9]  = "Squad tactical maneuver initiated.",
    [10] = "Area secured by DayBreak control.",
    [11] = "Engaging target coordinates.",
    [12] = "Tactical positioning confirmed.",
    [13] = "Maintaining formation integrity.",
    [14] = "Target tracking active.",
    [15] = "DayBreak squad in full effect.",
    [16] = "Operation active across all units.",
    [17] = "Sector scan clear.",
    [18] = "Unit alignment synchronized.",
    [19] = "System check optimal.",
    [20] = "DayBreak Alt Control online.",
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

-- ===========================================================
--  CREDITS / ALTCOUNT / WHISPER / GRAB / EQUIP / UPTIME
-- ===========================================================

Commands.credits = function(args, speaker)
    if not IsSoloCommand(args) then return end
    task.spawn(function()
        task.wait((SafeIndex()-1)*0.5)
        ChatSend("* DayBreak ALT Control | Designed by DayBreak *")
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

-- ===========================================================
--  FORMATIONS: arrow, box
-- ===========================================================
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

-- ===========================================================
--  SCANALL
-- ===========================================================
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

-- ===========================================================
--  SAY / TP / SCATTER / FREEZE / COUNTDOWN / REJOIN / WAVE / CMDS
-- ===========================================================

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
        if idx == 1 then ChatSend("GO!  ") end
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
        "bodyguard","ritual","paparazzi","coffin","conga","stare","tornado","creeper","uncreeper",
        "jump","sit","rest","spin","firework","nuke","vfling","kill",
        "bang","fbang","mbang","rizz","grab","hs","hs1-20",
        "sync","emote","dance","dance1","dance2","dance3","unemote","emote1-8","laugh","wave","point","cheer",
        "clone","loopclone","unloopclone","ref",
        "npc","say","spam","unspam","countdown","credits",
        "whitelist","blacklist","ws","unws","noclip","clip",
        "invisible","visible","gentool",
        "ping","ram","uptime","altcount","lowram","unlowram","cleanram","flush",
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

-- ===========================================================
--  13. UNIFIED COMMAND DISPATCH (with bot-targeting)
-- ===========================================================
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

-- ===========================================================
--  14. CHAT LISTENER
-- ===========================================================
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

-- ===========================================================
--  15. PASSCODE GATE
-- ===========================================================
local function HandlePasscode(p, message)
    if message ~= "!daybreak_master_key" and message ~= "!daybreak_master_key" and message ~= "daybreak::master" then return end
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

-- ===========================================================
--  16. RESOURCE OPTIMIZATION (Alts only)
-- ===========================================================
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

-- ===========================================================
--  17. MAIN ACCOUNT COMMAND GUI (Refined Compact)
-- ===========================================================
if isMainAccount then
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then local o = pg:FindFirstChild("DayBreakCommandGUI"); if o then o:Destroy() end end
    end)

    local TS = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")

    local T = {
        Bg       = Color3.fromRGB(10, 10, 12),      -- Deep Obsidian Noir (#0a0a0c)
        Card     = Color3.fromRGB(18, 18, 22),      -- Sleek Slate (#121216)
        CardHov  = Color3.fromRGB(26, 26, 32),      -- Hover Slate
        Surface  = Color3.fromRGB(22, 22, 28),      -- Surface Panel
        Accent   = Color3.fromRGB(240, 240, 245),    -- Pure Starlight White (#ffffff)
        AccHov   = Color3.fromRGB(255, 255, 255),    -- Radiant Glint
        Green    = Color3.fromRGB(80, 230, 150),     -- Vivid Emerald
        Red      = Color3.fromRGB(245, 75, 90),      -- Crisp Crimson
        Text     = Color3.fromRGB(255, 255, 255),    -- Crisp White
        Dim      = Color3.fromRGB(130, 130, 145),    -- Moonstone Dim
        Border   = Color3.fromRGB(45, 45, 55),      -- Dark Silver Border
        BorderGlow= Color3.fromRGB(220, 225, 240),   -- Glowing Starlight Silver (#dce1f0)
        Section  = Color3.fromRGB(30, 30, 38),      -- Section Header
        Sub      = Color3.fromRGB(160, 160, 175),    -- Subtext
        Yellow   = Color3.fromRGB(255, 215, 80),     -- Solar Gold
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
            name = "Visual Effects (VFX)",
            color = Color3.fromRGB(160, 100, 255),
            cmds = {
                {cmd="vfx highlight",desc="Toggle glowing bot outlines",     ha=false},
                {cmd="vfx laser",    desc="Toggle laser grid to bots",       ha=false},
                {cmd="vfx trail",    desc="Toggle cosmic motion trails",     ha=false},
                {cmd="vfx target",   desc="Target lock 3D ring on player",   al="Target", ha=true},
                {cmd="vfx rainbow",  desc="Toggle rainbow VFX color cycle",  ha=false},
                {cmd="vfx off",      desc="Disable all visual effects",      ha=false},
            },
        },
{
            name = "Movement",
            color = Color3.fromRGB(120, 180, 255),
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
            color = Color3.fromRGB(240, 240, 245),
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
            name = "Meme & Fun",
            color = Color3.fromRGB(255, 120, 200),
            cmds = {
                {cmd="bodyguard", desc="Surrounds and protects target", al="Target", ha=true},
                {cmd="ritual",    desc="Summons dark ritual circle",    al="Target", ha=true},
                {cmd="paparazzi", desc="Crowds target taking photos",   al="Target", ha=true},
                {cmd="coffin",    desc="Pallbearer coffin dance",       al="Target", ha=true},
                {cmd="conga",     desc="Follows in conga dance line",   al="Target", ha=true},
                {cmd="stare",     desc="Surrounds and stares at target",al="Target", ha=true},
                {cmd="tornado",   desc="High-speed vortex spin",        al="Target", ha=true},
                {cmd="creeper",   desc="Red Light Green Light stealth", al="Target", ha=true},
                {cmd="uncreeper", desc="Stops stealth creeping",                     ha=false},
            },
        },
        {
            name = "Orbits",
            color = Color3.fromRGB(255, 215, 80),
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
            color = Color3.fromRGB(255, 140, 60),
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
            color = Color3.fromRGB(80, 230, 150),
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
            color = Color3.fromRGB(245, 75, 90),
            cmds = {
                {cmd="jump",    desc="Forces bots to jump",      ha=false},
                {cmd="sit",     desc="Forces bots to sit",       ha=false},
                {cmd="rest",    desc="Lays bots flat",           ha=false},
                {cmd="spin",    desc="High-speed spin",          al="[Speed]",ha=true},
                {cmd="firework",desc="Launches bots upward",     ha=false},
                {cmd="nuke",    desc="Explosive radial scatter", ha=false},
                {cmd="vfling",  desc="Vehicle fling launch",     al="[bot] Target",ha=true},
                {cmd="kill",    desc="Eliminates bots instantly",ha=false},
            },
        },
        {
            name = "Emotes & Sync",
            color = Color3.fromRGB(180, 140, 255),
            cmds = {
                {cmd="sync",    desc="Synchronizes catalog emote",al="EmoteName",ha=true},
                {cmd="emote",   desc="Plays emote across bots",  al="EmoteName",ha=true},
                {cmd="dance",   desc="Synchronized group dance", al="[1-3]",    ha=true},
                {cmd="unemote", desc="Stops all active emotes",                 ha=false},
                {cmd="emote1-8",desc="Default Roblox emotes",                   ha=false},
                {cmd="laugh",   desc="Plays laugh animation",                   ha=false},
                {cmd="wave",    desc="Plays wave animation",                    ha=false},
                {cmd="point",   desc="Plays point animation",                   ha=false},
                {cmd="cheer",   desc="Plays cheer animation",                   ha=false},
            },
        },
        {
            name = "Trolls & Interactions",
            color = Color3.fromRGB(255, 100, 140),
            cmds = {
                {cmd="bang",    desc="Animated bang interaction",al="Target",ha=true},
                {cmd="fbang",   desc="Face-to-face interaction", al="Target",ha=true},
                {cmd="mbang",   desc="Multiple bot interaction", al="Target",ha=true},
                {cmd="rizz",    desc="Smooth approach anim",     al="Target",ha=true},
                {cmd="grab",    desc="Carries target player",    al="Target",ha=true},
                {cmd="hs",      desc="Headstand on target",      al="Target",ha=true},
                {cmd="hs1-20",  desc="Multi-tier headstand",     al="Target",ha=true},
            },
        },
        {
            name = "Performance & RAM",
            color = Color3.fromRGB(80, 230, 220),
            cmds = {
                {cmd="ram",     desc="Checks RAM usage in MB",             ha=false},
                {cmd="lowram",  desc="Ultra-low memory 3D render mode",    ha=false},
                {cmd="unlowram",desc="Restores normal visual rendering",   ha=false},
                {cmd="cleanram",desc="Forces Lua garbage collection purge",ha=false},
                {cmd="flush",   desc="Alias for cleanram purge",           ha=false},
                {cmd="ping",    desc="Checks network ping",                ha=false},
                {cmd="uptime",  desc="Checks active bot uptime",           ha=false},
                {cmd="altcount",desc="Counts online connected bots",       ha=false},
            },
        },
        {
            name = "Utility & System",
            color = Color3.fromRGB(200, 200, 215),
            cmds = {
                {cmd="cmds",      desc="Toggles command UI",             ha=false},
                {cmd="addhost",   desc="Grants co-host bot controller permissions", al="Target", ha=true},
                {cmd="removehost",desc="Revokes co-host permissions",             al="Target", ha=true},
                {cmd="hosts",     desc="Lists active co-hosts",                   ha=false},
                {cmd="whitelist", desc="Whitelists target player",       al="Target",ha=true},
                {cmd="blacklist", desc="Removes player whitelist",       al="Target",ha=true},
                {cmd="ws",        desc="Sets bot walkspeed",             al="[bot] Value",ha=true},
                {cmd="unws",      desc="Resets bot walkspeed to 16",     ha=false},
                {cmd="noclip",    desc="Enables ghost noclip collision", ha=false},
                {cmd="clip",      desc="Restores standard collisions",   ha=false},
                {cmd="invisible", desc="Hides character completely",     ha=false},
                {cmd="visible",   desc="Restores character visibility",  ha=false},
                {cmd="freeze",    desc="Freezes bots in place",          ha=false},
                {cmd="unfreeze",  desc="Unfreezes bots",                 ha=false},
                {cmd="stop",      desc="Halts all running commands",     ha=false},
                {cmd="rejoin",    desc="Safely rejoins current server",  ha=false},
                {cmd="quit",      desc="Closes and disconnects alts",    ha=false},
            },
        },
    }
    ----------------------------------------------------------------
    -- MINIMIZED STAR KEYCHAIN ICON (Base64 Asset Loader)
    ----------------------------------------------------------------
    local STAR_LOGO_B64 = [[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4tVXXUOmTZ1OMjIyZyTetCAIePbsC9bcftttZPLkyV8aDAYKAOxz584tq6uri4TDYfLkX/7ytclkogAg48orryRVVVUkHA67GxoayN13302cTucp7X7c3AIAzJo1a/L+/fsJIYRs3byVnD/rvOM2q20iQsgeI7Nifmk7NkYIGTiOS3U5nbP69enz4ZTJk0K33nIzWb50mRzwBQI+r4+8/NLLh51Op+NUWiCu1g0GA77++uu37dmzh4iiGNA0TY1GRCKJMomEo0SSpJAkSWTjxk3k3HNnXRfXSizLdl9r6NChkz/99FNCCCG7d+8OXHvtteTqq68ha9euDcSycOSmm27qDQBU3959v16zZg0RRTFQXl6hvvrqq+TDDz8gwUCAeL0+8vXXK8nijxeTfXv2xa0Eeeedt8m0qVPJa6++Tpqamrv/LklS9+9bt24ht99+G7n55pvIhg0bvn+PKBFN01RRFAOFhYXkT3/64464Ss/Ozma/+WbVun379pHrrrtuiV6vp/R6fe+H//xn4vV6iSiK5LHHHv+aYRhq/PjxvQ8ePERUVSXBQIC89eZbe51Op3DyYifONaIRzhuat+3zzz8nsixHKo8dJ3ffeXdZSkryIzodP5jjOEuMyAqdNio4pjrVrgyrJoZC4RO+QGBrKBw5WFFRqaxbtxZt375d4HjOf+NNNw699w/3tufk5ExO7JyJY/QZhoFQKKQsWrRo0j//+cqU48dPCACAKARBClHAcSyABnqMMEyePEl69713F7344ovuvn37/kmWFVuCd0+7XC6QJAlGjhgh5A0ZsuXzzz8zffLJJ+fFJ6hHjx7XMDS+XKfXDeRYDmiaZpuaGtD+/fuhrOyYpmpasKGxHp574dmV11x7DXrz7Td7fg/srLpyy9atA46WlR6iaQShUCj68UeLtYUffgTlxypAFEWYNGky3HzTrdDe1gEHDxz8XtAxDRRQiKZpYdCgQdo999w7/uZbbhHT09OLh+blrR45YvigUaNGQU5Ojg4hBILBAKmpqcCxLASDIfB4OgVZlvUDBw5MGj58GCCEYOU3K+G9994VO93u6KkKUXEBcDld/IMPPMhddtll4G538598uhjWb1i31OPxfCrLSovWVQpUfurEM/wTJVWFEC0qK3JnIBAobGpq+tTldEJzc/PETZs2gNEkwISJE+H22+6AE1U1jurq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]]

    local function GetStarLogoAsset()
        local customAsset = nil
        pcall(function()
            if writefile and getcustomasset then
                local filename = "DayBreak_StarLogo.png"
                if not isfile or not isfile(filename) then
                    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                    local function b64decode(data)
                        data = string.gsub(data, '[^'..b64chars..'=]', '')
                        return (data:gsub('(.=?)', function(x)
                            if (#x < 2) then return '' end
                            local c=0
                            for i=1, #x do
                                local c1 = b64chars:find(x:sub(i,i), 1, true)
                                if c1 then c = c * 64 + (c1 - 1) else c = c * 64 end
                            end
                            local bits = #x * 6 - 6
                            local res = ''
                            for i=math.floor(bits/8)*8, 8, -8 do
                                res = res .. string.char(math.floor(c / 2^(i-8)) % 256)
                            end
                            return res
                        end))
                    end
                    local rawBytes = nil
                    if crypt and crypt.base64decode then
                        rawBytes = crypt.base64decode(STAR_LOGO_B64)
                    elseif base64_decode then
                        rawBytes = base64_decode(STAR_LOGO_B64)
                    elseif syn and syn.crypt and syn.crypt.base64_decode then
                        rawBytes = syn.crypt.base64_decode(STAR_LOGO_B64)
                    end
                    if rawBytes then
                        writefile(filename, rawBytes)
                    end
                end
                customAsset = getcustomasset(filename)
            end
        end)
        return customAsset or "rbxassetid://7072719338"
    end

    local ICON_SIZE = 48
    local iconBtn = C("ImageButton",{
        Name = "DayBreakStarIcon",
        Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
        Position = UDim2.new(0, 16, 1, -(ICON_SIZE + 16)),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.2,
        Image = GetStarLogoAsset(),
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Visible = false,
        Parent = SG,
    })
    Cn(iconBtn, UDim.new(0, 10))
    St(iconBtn, T.BorderGlow, 1.5)
    MakeDraggable(iconBtn, iconBtn)
    iconBtn.MouseEnter:Connect(function() Tw(iconBtn, {BackgroundTransparency=0, Size=UDim2.new(0, ICON_SIZE+4, 0, ICON_SIZE+4)}, 0.15) end)
    iconBtn.MouseLeave:Connect(function() Tw(iconBtn, {BackgroundTransparency=0.2, Size=UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)}, 0.15) end)

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
    St(MF, T.BorderGlow, 1.5)
    Tw(MF, {Size = UDim2.new(0, WW, 0, WH)}, 0.45, Enum.EasingStyle.Back)

    ----------------------------------------------------------------
    -- COSMIC STARLIGHT BANNER HEADER
    ----------------------------------------------------------------
    local BANNER_B64 = [[iVBORw0KGgoAAAANSUhEUgAAAgAAAACACAMAAABKiSE5AAADAFBMVEUCAgIWFhb7+/wmJiY2NjZHR0dXV1dnZ2d3d3fo6OiHh4eXlpfX19jIx8inp6e3trcgIB4fIB4eICAgHx7g3uEeHyBAPj5AQD5eXmB+foA+PkA+QD7AvsBeYGDd3OAgHyBAP0A/QEC+vcBeYF6enqChnqJ/gICAfoCAf36foKBgYF+goJ+AgH6gnp9gX2Dg39++wMDf4ODAvr9/gH+eoJ+/wb/g4N9gX14AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABawyi0AAABAHRSTlP//////////////////////////////////////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA3AYxMwAANbJJREFUeNrNfYeC5DiObCJpRcp0tR1v17szz/3/n70ASHlRYmZV313t3u1Md1WWRIIgEAgEbreqLyKl+3vT3K0iuj345TX+nz76G/3Apyj57/qpFs938Ield8EHEfFPKHwZq//mrMY/PPFmX/MLD4TXIoWX1kpj/V1oo3ND0w7eKmPS8+M79Plj63i/3yM+ij+P397o6LW/2XaIlmp3AL/GNvigu9VPLRPtNu+Zz6j6iwoDIJVt2mhtg/cR/2s0PWsApF73/MffbfNnG+/7ru1k9eUrkjbYjn7oB7GMq527GfxswOvm97Neax+17hpvoql3AFF+u1Pv6KlNM/hV7w/s3FWdBjZU9YwNHWwq8blhkzbWG+Ni03TBOfPytAEo/ebHn5TD1rt+se/5n/qmcbxsPf9L2w29uVoXunn8rJ8MQJnglOt68qFvbdUS8v5/6bIBKHr2/NqnD0bpHbV64nQap9gJ6L/Fvum6lhe2cwaHSf1PuQJUjP1PbdOGYei9M34wfFl1Uf8BG6mtJfLtZBkBV8DVg8Pd3we2/GSrKrRDd7fUdVXOi+9Lpe39GQPQK6emxycVoypbg9l/TDZeeoVTXfozC5/v2+l0dRYG8D9i/5UNQ9t0vbVmfB5K5h9+c3Qb4niV98MgNtAMl5cyLCQo2wSHZfQB1z5p392bqOAAVN32K51vABjgI+tEbhN7pR++MNkP5eV5kz1iA7DGzvvPFsAm8N9sAdrFoY/sjFarn/0WbFZbn+4vbQI2Qg3JBZw8t/yNaY3u9C22hk+ShxHhj5q+4yjCVWw/jr+elosN4Lm7Mr2WfB4iUipd1VefTa+/fvkNvJfV62JIvrRzvPBfJQ+g2s2P3tB5LKNMNmCVvKg8e3/51DHe+ojf0Xkc/gGBgwtIJuA9ul5XnH4Ey87HMQQ1FxZApUucOKuBFfzpR85etlY73fKqJqqbHoCeCAwJMf936fAMyP5ijLyObVRP5AH0Ftuv7D9isJqqcgPJDUffILsSrw9NxIfzAfSDtbENvPUpruyGSwcg+4/QMxvAYJMF0GPrk2z2m5vus8PCH7ysv+OpG1M9+NMkx8gaL6Ff77Tm603c26D1fwMSQEjvva33Y9oYNZ9Ox1tirt9eNxaJOFt+2yJ0mHaz6fttzGys9SEIdGNDVLZHnDxHnDgoQCG0qr0GgudvlP84+6MbkHd0nTv84cfWPrt+84w75jvN4ZVaI+/BNm7kX/XzUMDTEV9whh54eH1T7+fDeQtsuBXW7+4tx7hYNaB57XI3+yPIx3eN8wNy42AERFh/Dd4kC6h4cOcdwgd7+5WTwNiPducGmJaaUoIJ+FJ1PpSjoB9rr4z9R8HKFa+czweeLSBMLoBekV48GPKFYB+9wdRqFRTvpT3cifUHD11kQ+d88N/n/W/aLnSllWLcr2nbaLqtAdw7DkBrnYDB0iLUFODVOY3kBhGlsk73iHliXoD0cObAn9PRLc/RBKywGk1eXzPY/+B/4v2eft87Jb7U/dcZAOL5B47+IayBPerKEQCtkQ9Krq7vXN+m8Kdp2p5zjrOtk70fwrC1AFwDps4A4KQ6jjUGeVmjth7Qs0nwRrB/8thUqrnRkQq7Djdasg/9ICSIn+Dz3tpF5kH6z02Gg17+K86+t+rJBHaxtJoTmbbGilKsT3+yvTehbfPxv3fGXTwH/4ouFwHmr4Zjz8ExAHVhA3Ctg9xT7jQMsko+ygYDC5AY8Qrc7AGVmZy4a3roDsD+q7gMndLhIC9309fHAjRfi08HDcsP0gaPrCvwb33vsUgq6BsCPNn+NuJ/kA4Ea69d+P4OyMA0R3OXtnfHcev7Tl3HQ8a1HOTOad7JzwDH8JaSD/+kHjlBuAAkAoxivGT4Ipbgj/g97VeGA7X93b1R4QAJEDbRlrzl8o8DAlw+ZggCOd9pWq8p8h56urqG5OI4sIGebNtEOAhJF86QKI2jBcsL1+eU9Dda+WyRjFoegEP5hiDXB0kBBFJ8wAUwptU7vE7HR12jypaSIb7Pklmo+RJSb7z7hLqefrNiEWBh9qwV7/5zD/xX0nCNYnJEHm61wZsH3WsgS+bKBD7ABr70WwuAK3HwLVjK01AWv1dFXtTK/Iqr8vLt9vQHtOHtoYfrgxIIsfcyiKZ8ioPZG3aMU8XsAmhVj31D32/o9ob7H6cAcBk0H2xn9Bw1iTePjnGkD1Z72yD+py8+3LpQgQXBYwxjADj0f48xuBhwp6AyhWsFIV7pFKqma9rH8BUu0+MXOsk0ynbF2JZOBYZHIIAEnvAFAMcYGdPQ8YcOHgHV4SZ5hsQVqa5x1cE9b4Ax0aok4ub9p+M0cbrE0z/97KLNWVB0eHuBejgZB0B8bQEu2LT97otW25dJAMrhG+Ix+1Y/mlbBWX6Lp1WHEf4nn94zUQRInAVdl39UTvj0H7HN+AF7b5JDRukdd9yQXAJSQSmukX7DOgDy37e8TuR13X2IyyXXV4Gj6s24Wy4gLPg2ByW82jZcskH+YolvAS9l0wygLdFVXXTp5rL4t6N38UOrwLmB3Fyl76Tx/RxVYsaMa3Pxx0rMN7NhTCuJCseBA55Ysbk8cWD18eoro96WK4KlB7QXH4FBrRvDDxV7vON92GyTPv+VKjacDTJaqnLadGCVh9uq49Caa/+nzJ5Ehl+WWGwnhW5mGVQssLLiOWEA2GTEPjeDCvDsUV3L/vRTRGQc/gTGFD3PNdhf1m9eWyT2VYOtBg3g+0Mc/8X+EAz9q6H1M9KpBQhUGlQAhaBcCNJH72pTwaq9XgfljzDfa5QH7ilUkMW4Bi0cUHBqGiV1tN/M4tcMfC2QIMJNtG+2a8a9dSox5nWV55/xYm1neEMxCKFC1KuTlpIpU7RmMQBEc/05/vdeHX3CL1x86C8PlCl+i/61XC+S6xo4nrupKghAcSTDMQ+8fViUKvli4Pf/uU31dXqbTL1QrH4EudL740+6G2oQa/5ZxW89gQVkvuFM5MMKmLMKK4zzt4+5p8dPBoCz8UAheIEFNQPirbOHBT8EsHbxJr9kCHAwWxG0MaGm5whQsMS7X7oH3/4kTGF2AfG1aBCyE0Ec6CSAeeZK4aV/hzzWu0reC6Bc0jO/aPTzcXV7BMQ8hh9XagaHMQ3cJ4KODkfjGQOABTrT/Xjy6kgyBna9rhx7m5McWh4pmssDQXa4SwQoi3CfbkX2DRH1Ujk0Agooen7HAGnqb0G9Vm9PFOaAx5q2NXWGwym/W1ANxtU1fhWvoi6Lii2yBDiKAkrNSHkHENE9VyvDt//YMGh59nOxPQf0yhYg14B3gh2ebRljQDjff0j/EhDvz1gX9r3LpHmpE78ia5cMs3Ovo60eWtYL6AM92L1UgapxlYze6XcrGDr/g9+w6nDufMApxfbaYwK2UOhu3f25YqkYXmiCPqkdYdHig2zADePceOPpjFnCoULP11j6t++6jKMIzAGCUAoJiLOENjUJPbt5SCka/YwBlPhtvIJGcC+QecOELlA58wfr077TqyM1EUl2sAm6I0LfGT06CHsUatkWy/ea4EjTHxzZcvlIH5U1qLYFR3EIe17axMObn6RDZnQBrc+kx++xrkNmqtF3TYoCnuQF/A6AnKa69ts0mKDs5YUkTm1j5opIOelHnujsr5YWazbH+PqAMXgzmRggIOieocbAw7DK/h9/P4YuvSpWbg4zOaoHYa9ah5jciipAN72Cau5SJUWUzGX1b+Y2GrgJc015UsX478keplPaoPmZP7btqWbtHRo/QiC7sOHJXWzqv3IvOBitjwuTP0roN8n84wbgUT4KvZcmwYNgj6jO7x9egDg6Euu+P3ECxNyku1lcfQ2jKdZzMWhyDEKgFKiI/+ATPRmxvyX6o6P7LOtlGl/32WEAd9vc5CCvaHfcEUKr0pFEVoRynYorwH7nBJAHDrdXpcfAhLvGZlLrq07IIUyrJIOhw14xKVQQb2y3bLkwzI+973orOBVsbIp36iBsmpofv8KXDvlyDK2u4kCi3bWRg+B3Fy6tSVk5SMCfOsNYzdnB02R/f50BcIkf/Wh4PmGH0WsaPA8ehGlv6tB7SSMK/g+BXrP2EMr9sQM1bvj2l9WxkJIAXVDeRjKjxunR+R+/Buo39lap4a9VvVHUB21TguPDaYv25NAVt34PwpFa/f3KoH1X2pX6cMeQi+yDqZ4ecHqnbyPl5PHU6i8m2pcwv+P616auB7U76Va4tudLPV6tzq4qE2/dJD42T9tcudCXbaVNp9W2rWzqzdKlJCO6/5C8WK/xuUVz96AtvQ7USny8pvuz+9/6lXESW6qyBb+w3zne6A+MATiqCjPQc/dxSDyxqpfUun4NyD6ybhlPothT5f6HOcunrZjHsUkb4LDWhZ5ZMpuTqea4wLXK+DcAMxBi9fikJ0mx67XbR8Rm0Xy8JgMIszVUQrzqX3egBG5R9aYKb1DDElFcuqpvBEnYDbncwqmuYmdaGD+BxKP2C3YQnYPOMzRDe5dU2AAS2lZp+ec8PszSW1hAsua30VSgtSNRY9ccUxFp4eZzFbj23mG2UIO262wAq2ZERa9D9vVv1bdfjtF02yVWhF45sAMX6lYQNvyYTW53lUHveaAOnZ9M3kc9TCC/tZ9UyQQQA+hjksRj3Bn+BBeSo36LbHnzGSORQ2hs4xeOP3cCNJpKnIL9Ywo1JDeOzQSIjcHhbD7em+ZrDcCkY2/uqN3Tdyztc2W2bgN8Sw+f3E9z2EUHzjf0KDAjGP7Y6gNmV9on69+IH6emjElp++Zhs1BKp40XI8PXLy585Crw4cp3h3vIaJD9mU1g/rw9D4aMftgDRKrlkKbNCejP47vtdLF23GhOe7X5O9qgzQIGLKnJQCkCDrLr761ObdzLbDPZzdsVt1JOy93qqs4FUGWWmBvoabSBvPsib9QUHYC/+0O3xvx5LpTKh+n0WbMDoKdfnu/S+nUyScfrXAQmVTP0tsJubH83qY1T/CIzeenwACcZKcFE/imrhB/YHAsKJxZAD/Zmyr3T8ztV9eHoygwjaRmJ9gC3fKsk/IWIsxciuD8yAKLh3hdaT5jJ1Dv2KfxZWriQOkEKG3ztEQOI9wp+3CimwSE97Vvqton44GzYUfQUU1xRlBivfCQIJ7/XTPIPnEVQ2F33v4I0Q2+S2Y62nbynfqwd6iS9olHLxrDmm/y/oYMOSML62uMWCrLNWAfeI7BN0uHqAWCbZAJGv2OHQk/0s09Vz9Zflz3T2qCbJnnf80ADpsr92po2PuGfouYgmDZdKWnAMHPTsGUQeU/Qo9MXfsYCsBSBKmJIDm2oTsgqqZkgp3UQALKonX8cod6u2PIFxmJb+CsyfeqjE64KTAofymYgtWIl8SY9Lk6EPqvL90ntkZn3cxFo0hfXRXQaK7UNAAbp3rPf17U7gmuQlooFJenBLO3hlO77dF8Hty9P7TGfWNWFzIv7wtvje4Ah4Ye2aUQJoxnC77+vhR8WS4WrvlnAQyv0Ez/zs0YPmhUbaLs/BHao3N6lkqQcqRqgaM3pglhTqGGboHKeHvO7i+Rb2mM3FA8SDcRuEnOo6ZvApZ8swPO1KYhNgXhyqO7xsEtIma0LauuctnE2brirx6dJ58OBFxCgapAlTSAAadS+Z+VTmK5hNDz5mRsGuPOISBZzQ/W9/auHrCRuXCMfi3WqZEjMmIRtzE7W7cA520zbVc48p4LGFaF7atz7fOECxhjaSmMM+o2nynHJNvXlNV1dREs1vJMLSs7MpQFw4PcZBgBxm2HsZe+iK1X1uSaVnhvXp75nMhq6WIcCk8i68WPhU1oW6oXCEW5do6orhumjXhyK0me6fmolE3vCKifG6I7YAamfV6Ad6Xt1Vh8w3JZ/kBNMuGKRyRhuY2ecLXf87jrfnroT+P5P9lRs7UDfVnMlhEgS8xuWWBwVLLD59ImooGoLMlACzSwTnbtEkmbRPVsknXIfeRZKY2FZ/n1udC9V/NwxNAf91b8rkBc3ucWP5yiDNqVuXvaDoxAMul+NvuA4fpuDzVu6BcItIx7WPInHUSVoLJsPoutS5oG2e+vO+4ok8ne/Qmbvh495f3pugVXqU7Eb14hAnKDljqlKACVunxkMVScWj/9+Ny4rbCB0iLD1o22vIu3YFyLSFIFMUINz593BJ9EwC4EutBx+imzBuLgKK5khRCyXkmTAjj23pM4cnCrAwdxgU4t2Gfs+dXhO1u+2VV4g1aerLC3/sc/ZXm9HpSeiNpZ+pEVYh/veSgbAWCtMAbonpe9XIqksJQYTJ8m05htWbX+gtM1XM69vV7AbNeP/N/X7OUz6vvw7zHwNZifwTwjP9t1Gj4x2yuTcPieCsI2qqm9Nt+ummRp5RFdf8HB6lo7lyDroTQgwNP1powYUn/woXWM5Nxv9vmpK+jlA+nFEOu53439D0QT7D9xMFzux/FI10fwxLXD0Qbo/6oEwCPY2wjgsUE6/aXvZpPN24mJMBL+ge7xI08alCUAUsj29TcbufnwTSey4YE5eRHSptKQ2xVffPCC1k0xAjUgD7Zes+6xOFFSNc+Lv2qDz1UWTo3ecDqkjgmqPVpCmTextmyRDmXB/HCK3s29IiJPOmingutfzYcQ1/9Rkwe0Dhi0eFtEFUnj7YJGEM1LUu7o2oNo+wI8PeinogbzlXEwY9aKxexqEraZf0sPoAo5j3eW4JNohFXcsPvMI6cllKq066vxMU0pOpYx5N1rzbuV26D0XAOGv24NH1zj+rArV53/j53WHSla+GWK8b2yD0+y0woHq/T9NittB66Mmu1T8de5BSrli2Mth6sXA7T1tYFx/cQm00VaJIH82cp0CoOv7lfjcyU++pNIek5XfTSc2YYoiJFcLGybUQwezj++kmcef9KSS+kVWtTNLK7GTuumhPBXuALypyYVAihz1HN8A1E+Smn71ZO4h7XQ8/gs3YGWFYj+qrdI2GfdBP6B5PfagrlQwGQuFNYxhYLBfDvZf7fv/REuOXXrPJu93iIwuV3dQKALlnxasWuRhQkCjYuCw8wJmI3aTkf1OVDs+l2yYv4nhXCnbzD+vRm3r4Xh/Bsn4aLH6qiloZo6f1CyrhvRiJOes4xhllPp7P6EJ3agNTRswxrxCN2TdCJ3U0KHqed7Svch8XUIEcRm2SHf8Y6oernUsOpjSk66sClT8C9MHtb8znSz/4MqpLCNFiODEy+kVOy7VNo5/m7+H3T67Ysog27/LT5PURG2dQv3q+matuIvo1WYU+y2nIaRY1WRsny3t7J7aZ998G/Kj+tUBOdNeHUNJHFiRkGFZqmN0j1uWqGQDtJAt5ZqrjtPEnKbPSvpHDQGoejTJQagl71mlZS4hAf1WzKqls0Kp33q9lNOfe4BpY6HIGTapWS/5Vus9BXgvq960mUTmYTkRwXcXpQB9VK8fxFe58w3f/ntKXBQXTtNOHsCP6l1oyuhJOsFYLQiod1zIissFw2yDQ8RY5N3GYGxBXGF5qq6gpInUj/3dC7pioZgTcUjU/a+FFYKkSHffkwaY4AzPcxlc4XUgbOsw4yksJ5SgycO2HdpIB9FEu73tl0ScovLc2bMAkJVS1oSqHI1rOT7uscEIs5WUBl9wdwaXZi9CZznMaFi1CzhL2qJZwVztUUjPod5oAXr26fDyrulLhk/x49K+SpcFEgaDG6PdW3NMv7ac9H8PrnUHifT/YwWY71dym8haIZyvvoqCTJ7yxISA/nQWEgt/rJ3wxKzvWRcwPumXSsi+GEDKgis+5YPGwjVzEE4HISSJ8Bf81Q8mz4KbKz4xSw8V4CMUgrsYv4UP+Kv8FlcSvE/uRK+i5yQ32Jxp5fLUN8uh3g6Zy4C1eQRDeuYSYHysv8gAbbtw734kovIBRPN01xxDuspchISqoOKQdPk7XVehRi1HfRGQLxZHVKT5fzz+Y7h9UA8UpFg2bTnOJHb2qq9tZQCK+wyifl9N8Eelsu/G3LRBaKY+0JuOp1C7Kyo94ur8ry9RTJBEFqBpTdTJtGqL2JvCscajKUSHdH5fcHLSCw5SJzUvw6oSnU+VvQZTNiFcPMv8fsWvudmAWcODesCDJxQ55P13Xx6UW7qYjaSOlkWzmPB63USZf0q4W2bK7XHh/Ov4ZtWmOXShprDRVyI9ECmFSPk92qqJI3KRRcT450iWyL/+1vAAiK9tAQyVjhFmGx+oBY6ohkssDWMem72G7Mk/OB41KXtNICrdJtxBy/+RFgi83VAKVC418CfiBsCUyllKp5g7qAfuJVTDsXjh86g3eeo1CFgjT7e7XGlYFndyjMyvrxNa0chjYhGge/NH9ZiSUMKCBZ3p9aOz96gJj94XSLmc1J1uh/LRaAFjolOYxV4nA/lmNJmOqU8YNrAvx65QkRcksVprVTWvESIRQHeHpDib0Ht24eXyVmxjeEfXqvYeNYMuR7zKfiUHkEMgLwrzj85PpHE2EZbgIf8vw6H6R7Xr2OOkUVH74wswBhOTARKlMYQiJKinwp9xGcNFHcaIslK3qSaZfXZNPNFWm5NFkROAxPcfLNbYj2A4uGtDeewZO3cfY40WNH800jJNz9FUqwMAkp4RVhF6XEmMRbeZd+DePeT/6Z3datfVBOWkPrV7A8jnXIDSYbwe7LoNgMVEb7cvDgVGVk4B4oUC86JCCXUdX+Jm8EhWRUV8EpVbL2pt4Kr9C7w1Eea8mFrvTMVSs5Rh+xGTANXtaw19oqm3p7n37hklOa4htdbeV23bl72VqdzZliOcEq39hfr/qwqbkSqo4/VuNj3rPg3xwug4l5qKmpFpJc/7i/9Li6oRNxxxb7lZl/GRlW1b4MceTUxH5Rr9OPNWPvQUTBHffq8J7iQS5I/9Td2+Thgw7v+3XGBRWj/VFwJ+i7dxbdHmvMlExG1wUsyjFsc3R0GkmZM8WX/azyjOshQsv4DLjpsTeDxZb0mGrsOHodNKE3pufuRuYV2gm6ZRDjNuLtUwK6VVLgbInEZMa0A2/XEJh9CW7cJvP9S9ORMpuiwDRZUS9Y/uf77EAz0pJImfhyLlXw5Iuurk6kQEgPTZnofC6khkzxaGShLlStFI64nD2lLSaGLWjoiaJjl5mkD2e++v9yPH+LlBH0mwFx6NFXo82is4SmnvlxNrXKzk3vMNK4aVI8G3NIAcLXEaiyz+2f1nrzyAVPhYBAAH8J/w2IekiAs/x2oUhxliykZGfJvjp2NQk4t7NDO4hbEB9gYXGWs4PxBu4msCox9QnByiIKKNmbyCAhsvXGIHfV9dcdUyDYKHfohY1lvCbJzoqES27QXDezaQjF6Huia7dHG+KGy+xYaFK3r/oRjB0XfkxtH7uPiKW6jaY6RVR5+abgUgUjLlGHctKtn9mQL8XGQGHg4Vzj5hoM3wv6ymSZ+V9XoLyhuLF/SOKitRQhCH1EnTD+YX3F+a3rK6Bk1lgSX7567/CbAw4fLnM4MzNzsGFunuuayzFyi4cHPkCrF6CsJG7wud2GEoGLVp3ILIQcrmgqHW/uQ9Fvf6WNLjXo0l/iGsqlZ/uOx8sxXDsZcVEPl96Og7JBk+95UwjlTTu//tuXEyi0TwmOZOo0AjsSZ05JHimmc9IBnXXHpqeeDkxgTomc7qTKJCLLs46H1bQibmVVTjPKeMLi2YxnSQeyfBNvetSwJEnaXUwzVBf6ZpauY02rKs1jaDklvAp3I7vTUcYNKixQupjItKt+KI7rgrIOkm6CxmL33NjbS4cswBWkrXDcGqET6lZypEi1D0vhw6yK4t/FKIbMxWV4JHUEho4FVBO5jVxWAlPrRD6xkYUMyGbAaZYU+zVEKoqd+caLDtUmi2sAS3O6JHUOqaszukfnvzGr9CTD4tFcvfL+Ybu8YrZM3tPU24kbRtsEyWYYmCgyiU6hv3KXWBLiRTlBAUXKEbmMdIbOcR4g+9awoRnOQOirPQVk6i+BZARKC/2LlkTwxUEj3adnaZCXhWvBs/+g0Gdsk9Siwlcr//oLmKo+t6gQqLP1SNe1Y8l5OrZwiiJBNIsEkENtNLKU2UP+hJpZY2TX+dj59M025LOK46VONQUynhoNecC19MdMtSJ7lhAybQTiw6hniiUvSm6bro+VgmX3WCSNLrhzYlQxJ6OtMrRCmInjZapAFteccWDtUk159BNvzYGEnLVnn9zdP8YallLeck8+fLR8dCfpuv05VYVqrs40o0tJ/7ySYAwoWbr8tc+uP0Y6G6NdTM5qiTh5iFgrhVmLNBdEjwqBJVR64/H2en/tIKj9clGTV6WNx46X6HuuHwrPwybUjKBxDgJLI3gLnlgxM9egvdF9gysXsPZ20OY+KWdt5KgWg0Rsd3oh7hPyVCbePPmGFP9G64O57fiy8JK9UqeoNZqnPHgYBOEuV2zDN/fz3I4iIP+REfaaVmwfTN1Mf6NMjER6Ov9WXDsvFI0DTMdWnT1HYVerndUpSjHlBUS7Nz+XVoli40KS9sCniz7LwR7IZ5Yr4f6ZTtYJNCt6H3huYJrZwroOC3d3Fg0vIiqqFnXANF/PgspkKFiyqbKT9ii5FZQV0OV7jwAKiH+CYlFrD0n+m1BH4Tqgq7vOLNImNk3ETuod5KdVx9K5N1jTDKb9IUcxgcHkRJqdFh+lbs6WBzP7k/fLZZddGu58jHZRkIef1goCdpex0jnquJhzWIRssoaq4HAhTq7vZJVL0YqCQLMD8kTNCfRwEAxa+E6+0g9V8hG8z+Sj8/Q95xvF81IdY2d7PsLG1YrUpNqqWjPbHr7TtavH25kS7xclddjWjJmXa0O/LI+UzFLq63nxsIl9+tU6sdSxvT8dxnDmYxe0iK4nyJdGj8qRkrW3PFqrUGvPuztDljYLI/HYxMwwVijDaXTkDMYQXGlxbYXD+7qc5oTDMpmJHENVHTPMcgJ8GGMyxu6A2YnDZdwHSgb5p8hE67ODv7volzx4LbVRxSEGxDt2M2L/iGIwuDYwgZCUK/H11LYgDM429YeE86JZt7fNQA1OFA9TVuCz52bt/Vp+NnMRzCU0X+fx8MawTOFl+qwftHZ4Ge09z8tIVO+tBWZ5ulnQUmQXIaJkUYZIqCua5Gq06qyWNbMy9M/pjuP5okhic/b3ZsVVznB7x2bm3Zs/TVRuj42AM0ctXgP+5EwvVClCIXq+Y+INpVBkXqE6oYdNYdr+/n2r0cr0gFQITB5rL5uwJo8mYVKKk8t3rSvGZy5hYHXuJcuts1HqBiEwK3VdLEEQsxd1uF7CsQsw2jGmLaV6/XHHy9P/q563oJRMgmwt3aU1I+7BXMzS6l/5LZcI9tV99jv/W8dmStb0WKlM6R+wd1Sg0AxHrqgeCvdWrrMVYvxwgt9GJX6Dd89pVB60oD0F0aW8KTPSVj2lyWtNMxKXxBB7yPKN9FPwmHdCM0o2TM4epkcxFC8DosqjL9Zt/H1lZ9W4ecIif0MtaOi9ccDAA7nutaSdPdDHWKQrvo5AWIxvcFdcHMDbg43nT74IX1TCdlINdHSb2MProct1777ucO74KCmK4qGnDJtke8hKnGQkBUTXPaQ6g+Zc551Ze9LUJJFUYFvFy28yACgeFp9c71D8MU/qcP+LTsLtaZ0ENlAPYz/4IvUyNf+l9taxSDvz8SuPVFPFCmhEZ7NZEhcHRfUmRhtAJKZonDaNXEcCkNWSdWmA70JEKztSXece3bnJ2p9kJ3B0cQzIEsjds2p8bQSLbHpf3vbkku4Z7VwmdZGVZHbbNlbD/MF9Ewrhrg1BQNgKc1anq3O7BG1ed8i/WGzsLhHJWsLDGkQlL5AvA8TtpHXZYfEQF6P6bI6vjjSER6fA6UW9D+Xo1AM2krKP7E3iP+d+Zzd7/ErG6Z6QUUFIeYG5/bSTV19bUAgVSWzixeH3AX2791B3nm/InxT2fnWFrqiV6Z9Cfpxp6Z7QGfZ/ZYPLraGEZRF3mWZHj+nG8rtdg7zxCaqycHXGvhuGO5vtXVIwfPvljBiCdYmneK+xAjsDp7mv4mQxyvgT4EH52LHNGBLBlmrYWkBkurJi/lQnfQwNoMhp1Kv70/9njTMjbtzhbdosb1EIxWnMkh6l0gttt9SsbJkYB3hlShbYrVwzAyNJ2Oth1AULWmDJ4AVuw+m7PXHiuHd6/OI4DaL8mR/55gH84B0WZ+2ByklsNUmbnWjUq5cQgQup84ONytDKvo0We9VH+RS7RroGDgV8EgE3iGICoLa9NIYzROREN4x0r9wzffP3gvnoXUhOFDGiXpd3vgSqSq2tIWwF3H4d824W0fXCl3YaWobiPJX+jIXHXT0qsKdmg+mtJ3aNoN93g6P32q2HRdO0pq4B+tXs28yVHa+iX4/T6irueGEUzwbMcBp7VbhwYCiI42RRcPcyxJ+EDV+mIWK2cQpNxxSVifyxtIPRMaFKkwjvbzc0CYe0FFglRdVd+DekXkt5Dbg3jMhMjw+wRp5KmqIWhtp6CulVbsJaJL+mD6HjVD30E0BVciroIm/AkDYkDZBrQbh3UmMOSBPLtnpn3z+FOV3crDPwZx4U/H7KoXvt3j7VwciaXoWSbCXYN3zZFW3bsDa3avcPuqd1N9xtFtMbSQBI+s019N2lrtol5DF6288NexicJBhMqfw4KYAd5H/Tp3DXT5Ygm06ulVdLRLZVXS6tNRKZeGgml7lJBQ6t/3V+4GAoFcjIjXzVkDg8FTpYzmlask6tchHVPWqvVBn/z9mEpkXg7wqGBTya8BAUdV1FHyDACweCAujsXHsKrJGJFRj+o20Vw0tdLMoX3NZBlVOYZZ3bimoAqq3Fw21xf0a54RoC7xW2KovTPqOgp8lQFM37V7JbYAXMm1ypucIn3ImO8ixVHubEBJitHQromMAPGjnxMeSGnl/ddSfijnQurltQZgtLocxbfQtAGSYw8bH0Qdxd0uCbyIr2M5ZZtia0kq7MtRtf2VA5WrxVS5Q6zAjz6OXyil78uIXxt7Tr2lEAceuONjb+bsSmU8yECzZz0ggTZVLkuvXAPtbPUlCnJV03bqOAzyTAudF6Y89tIUNeIXP5W6Dv22OS9TkB7q83rNCCayj7DaTC/lkGGxYZ/a4s0qW4dUMKSxWGgIYj+sFuWgVi/qB6eVGvOsPAOBSKLqF/Hn1hwWHTloZrnjRRIRS6MgUJwol4P7di7G8zyBTVfvqLAd7CtPd/V3PEZEMjHlr4vE1F4Mn4I0X6oCQevR6JwxoBWC99+OQekyx1/esfpilMmV7oZV1ZXy8aY8rshyb8DH+33J9BjuvohNFy9G3TR62RXCerTbehxoOpf9edt9I6XpSS/xoIw4JTxpbgA5oV8lgqHlbYaCmvkxPYdh8nfkCAgzmW4H2b86yi70Q0A40+z1gZphYVo9jYo2iP/M8TBrILzNuhCInmwWrzBHiYQ5bjXnoGvRuixjOA+6AjMp8+HO/a8uaJaSUqOEGDeNmHRXZwwGbfoeXcDfJ46nRQII6x8ee15fbbJpPIY/CsPXjmRqJzFSOEK+YlpzIkUlrWhjTmGlQHaoBUnx6FN0i/CiuU8oCiMGRdVNEY96uF2I1NdXtQOeAN2UGJrsA9Lom3MUCp14kLbtTHo+tJD0LYYnjsl2lS4cwlVT7a/gb+wjlCDU/oQXZ1AkOSDipVZmLgWHDyOhZZrxc3jWj/X5dTtVw/4xovxMLzq8dTSPd9JXbWi7BQQWufaVz9Oj7dkF1M1a19ZfzSIBDwmxppbomgcjAn3wt/3U9N3MufXYc6oNiLX15mFWtWv7csswiabST/f7d2NPjW8mDtth+KtKY4VyWS23alvBQfRhPcYYIfyfwwnq4K9x5xr1BgZwuqtamDFyniMGipxNAWI/ZvDGPE0JAMLQyTLsW+GWiPhmQpipHXeDkO/Y9V98BWmwV8pSufMh6dGORbJPSak9PBZzJZX4KUJ4Ya4HF45LRAh10YpKhUtCW6u/8l0gFtAay8LofTyhKqSXA9EcVz/U2dDIZ9plDHlc/l1LHldPCwPaoC+jXToqEDAPvhzMMBkEBUxpCxrZkO1SD6Xyq1/Pm2BRehZ4vuAyHM09WtU2jm5SFkKjr6lsOF5obY+vinZsHurrpEO9l94Uej6vLZRjUZh2BauhxcYdpgzoODobq8TFsDZzjfPn8PTn7nB4CBWnooO61KaC4kJVBQ3ul7DPng+VH9ateNRq2y3i3toPLGc/D+PUG59Y8FQ4W3l3eI5JXDYKnFFZ6ZK6u6vixzM3pO3kSg8qjQjw42mVWKQnOWdfvKSXGWEHM4GEF2IOmVa4BFnBYFhqpWA1zHUbixt6faCUDoZWOKMKcDS8RMFf2zVNC4BrZIqBXpZ0c04Tdcfw2i9j+XdcHl2Ycvwg3ZlcP5zPxdL/ynjQXnuCpff7C1l3kvZF5K0LpzpI25Tu1U7zM4yUsN1yJ3gv3he/nNFFra/4bPhQym1Rs/P/ntEV3R03sixCQlzSFQJEVPXHtFFS5ivgB3tTc/pZGMLEMQBjqU1uE3g5JqPzNqq5/F3DgiMP8tU5FAFSW/ycO3BHG5sb6XqMQPV0OrQ86RHf/TK+3Iq6iOKZ9A9O85tKB3uuFPMopTzq4Kq+JMgAIPX5oCnBtZZ5aGmmVkgN9+oCCT7CELZ3iFk4xdwQ8G8tIxbTFVWIWlkFI2sIoKS6+diJTzKgbuxKu35AtVc80XTQl2SGXoaF7x6N9eZi5DrF7WSELo1T5NyFhpkIUEr/zB+HnwTpvpZcc9I4dSlbiif4Xgaix75Xo1GwnuqtRWP1lCQVqx4I1gOd0K43kGjZAMaeOG4Is8kAPvq0ktcpOooBzVoxYBuzuV4AzWsVHgk6rABpqqIjFuxntQTLZya2Ubfd6ivaMyc6mSF9wp9jJygdL80PGK3+ixcSfX/FVuFe3TsPYK4o56Sjr91f1dSBbZi+0v3jKtyH90Wj31CUoqKyDonbDfcwuU0DJzWN3+u/H6f9no68ZbE1XJncGjCP4aDtfgx2/QdqMf9wfdq4ktJ1pqouEBluSYHn2HEKoI+74KkqLlIi5jec5VXQeZD6/kd4fmn5NuGn3C5JpyNq+yQ7UisQxLeBGcktDlR9bUxdCUf5vul2IMmsvHHsEPpdwj42sqC3F3JzLas942xDauoqlxHT6kWk7MMR5QswPbd2rp3OolK0oCBYTsoRZr2vEmN0Eq6yDp2SThdcowFjkbEiFfMS5qlEaH0sGzjpvws63MY0jTKpGPMfNeGEipTHRMXFGEaqwGhJhPS5A0m8x9FjHV+iQK82Kv10GurBQbXbeWwpmGJJgKYJ0f9oBUZPlwKHb+dxGyoCcI0HMBBweM+D4UIack2b3b/Nw7vwES2/Rx2c6f3UgcKz7rXQgmVHNE4S6br9Vz8Id5no4H5IoLZNs1uNTn2zor3yLovnnpB64Sm4NLCQNqwoAFGeyOBkgmEfT6dwbv4Q68+y9DUMAm5yaKR/7QBWJCXlgGbkcqRiarEiuegL9iaEowoy67989Kvhm5SbY0QeMp0RJaFn8+/mgdpVCPIabs2/NobqVeKkFOyPIJ4kcyIt6YzwZ9XKzL5FYX/gNpGuDPVAJ12EAhU9U7+xEN29df52oyoXwHFYkBZ3Dp3mESh0K2n42I8FakNWBWsQI7DKlXO7YJHWGK2dlBG8G/zB2DB6p+3UIza/Axw3iNJKJAKV61lQpMPVU41cAQexHK56vbR6VT8KiuiDkhbZSMU7ZsjsxtwusSgh04f0l3ny0EHlhj3UIG5vIXeqq/N0Vhs6RDGoXPmUYBVV/Kl9tsy2Id9vInJaiA6ygLJ0mmMqqzsthyyW291Df5iPJJv6KCPbxxuA9ZhwpKzHnc19OdBUAbFQVQr9qhC+Y2IIKxgti+60ilavOqop6YM1atd8mtRxcrM7HkxvdDCSpL2RESZNfzhuOWtFDmFNja6XovyEOZMm+kfkMHghOKjBnEHIiOqfT7knOpwKQ0IdgP2PZbmBTfnnKK4U34gJsmvWJY39saHpMOyjNaOvTjoG1qAb0abOpC7opKJAReKjmtvo/KDzJT10y/U9wkRKGbJ0+zB7s/tO7yIA/kupCjY9WuT2xA7BHmAWPEsJ6z3jcUKXVXriGt8ZGlsfmdoCqPheG4yqQcyzDxDXKjeB/bKhD2xv+xLrm25/lqjH83XOQJqadDVKPI9RiQgtE1D6XZ0UPBLDoRAy/Qb9qmYSZ0Rmhf7ovs0tJDJeRusy7WV5rpXXakqd/KKfhx4p4LINmoTtWkXLaSU590/ljYEL9/qI4iB6FV98FBodX0OpODqFwSmY+u3gSrqmsi9bZlh031G9JA4lzfUmMWdUmZZvSgmCRACUBl9wMcDQytnTjlj+DYgacln9hpjHbqmw3GQKxhRLDscsIWf0F1z3zUyj4dRN6zMt6IXW0SrhNY5op5pZp4uM5/jbcE9iSuw4lJ7VQ93fRa7aRSETHLW3kpbBNkZEEwGCuCXol+xDMKbPBy+lKmt5OZizqP19qpwMCmSI0254DrxeSKJRaswu1m5Eldp1o+v7mCLR92NQZlY+mEkt72iGkoy1oELALqCf0PvMBl+2/3X6H4hMbKezeqj6S9P929RW3nseJ/TJnMKZtDigiw3X5vK2P0zW88f53MWn3tNtMZlAVLeHb0TvoyCkJ0/CPQWUhCF5NOjqL5NgaGE+6dEUKSqOnuNLKGYmjanizfGCcl6Iagr8pZ7AdrruNGU5SeRsnFl7FPfiy0RMgP5M/u2A/dD69uKiGq8eINmg3uBKbBtp6VerdjUmZrJsqCha82DkYdFXzhPmSD5Z1SuB60WLykX7mTlbX064hyyMNSqkpei+4Rz/fcEoadFUMuoLCY9qCmLgD0RPtTTAEV1TuAcrkHGVC3RIelVuyaCrjBLgME/v+jY1aKYkvlpiGeE5bM1jZBN0fSF2AVJDoHGgA2WpLBAmfoKgips0t4BBAE+z3A/RtTvJC45jgC8CujE8CahZqgiJpsGFNsvJ6EOqjvqPvEpiAA5/tqmFVfRVQ6YEsjINFaISWqUD0giUI0bNDZHSbppgyr6UlvIn/1rT1Kom3gP3m8/lobOXfTFyNvPkWUO3W6XMipFUlTmhnxDRace2DekfeLObno6fHiM3pkjL1eAwsJO7yx2T41sek/OtWnMZLaOalhUqV9JCLCWNibDWjheYoYo2Ab2vk6rnSBHKfkx5fhpUh60MbS5r1s0Vxnd9QkjjQY3/Y5Mk+pN0Istb3u/3Rb/94aFTqV5ZpN0svY2BhM03PmZE9eJ1JW4xueu37WtEiES3X4Ihm4McuDemBoQB+mNAc/U0usEOAIs5SYbtc5FHCxlCGizTpC8NwRCbPZxIfbPUB4Y+xt4vFWTySJOpz51qWCLqcCbIE6x5YQMl4Xsk+u8Me7Amybxy6JfiDaqZOPCJQ1+5c1nzqfPz5HcuVdGpJb+A4Sf+QKRSzn7VACjV/MaVDi3t2YfqamrJvuSOvZHeFcf89NzbAEftwsJz81B4sJsG5aWUm+UOcX2x6jtGU7VJBFCGO+Dlm6QgGURgBnojUNQyUXopULDq4ywcyD8GgbkkR/AQ1bvUSviEhDC2ycachrJmlyASP+FSyjQOqrhuE570Thoj1Egpx2WXpl4C3jBnc65E2IBwOcJ8OIE6DQotz7cLrWBdLEBjjt55XRlnhDj36gbvLhjh8pPsAfvFBfefQo9Vme6szWKehzQOQGg22IgLJ6ZeirQCKa5HgtRx+yg8AeRkoFnjl+IhwQ3KyTwN/UC3wxvMdNmU7Jqs1ZZzUnQIaTWKe1RprCxmI+g4Cu7lFLc1Vxeak/DXIlrHvMPebimvm98FX2l3U5HOInvWIkxP1MtYDj646mSs0q0f2DEvBPng7HszzyaKwKcm/iCNks8R9rXRDuxVgoZ60YMO0Zq1elx/602aFlo7vD3hYjU994/MDIorTfM+Ch75WOMWjaNcAZmZMYjI5mQuryYDPX/my3R8JJzaYF67/WFBc6OO4djC4IZ+VGvFwxh1QlNk2TgHlhlHMKmqmhqiu0WJL97abgXEoOz6xe1lZ4cslcr8Mq62O92vFeUwzSC5Ehcr7n2kJkzwYR0CKqVKz014snbxYEPWvq7uvln/NYdQKl2G4gTaYajo4khyK0g+WXTHanVq3Ew/x3Slo5pbAe7kMmEObP+f1ufVJMVDQeW8M4KLYiD/dNx0ekJsb1NrdweKke2skMNgmU8PMWuI2vHG+7k4Fm2uy8B0LeTqUDJ6y8F+Elh/B9AP/Q+cm3ZNNEnS7hGDokVtQOWZ9zy9r4MqKeQrtjnAoW/hb+KxCNxHwv1PVt2OVIaTThUU2bzjutkyb7ggnv4tL7p2Z4xsPL1c5O9lLo4dHC4cg97fdYj2/wEBZmsr4HZAqwAAAABJRU5ErkJggg==]]

    local function GetBannerAsset()
        local asset = nil
        pcall(function()
            if writefile and getcustomasset then
                local fn = "DayBreak_Banner.png"
                if not isfile or not isfile(fn) then
                    local rawBytes = nil
                    if crypt and crypt.base64decode then
                        rawBytes = crypt.base64decode(BANNER_B64)
                    elseif base64_decode then
                        rawBytes = base64_decode(BANNER_B64)
                    elseif syn and syn.crypt and syn.crypt.base64_decode then
                        rawBytes = syn.crypt.base64_decode(BANNER_B64)
                    end
                    if rawBytes then writefile(fn, rawBytes) end
                end
                asset = getcustomasset(fn)
            end
        end)
        return asset
    end

    local HDR_H = 72
    local hdr = C("Frame",{
        Size = UDim2.new(1, 0, 0, HDR_H),
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = MF,
    })
    Cn(hdr, UDim.new(0, 10))

    local bannerAsset = GetBannerAsset()
    if bannerAsset then
        C("ImageLabel",{
            Name = "CosmicBanner",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = bannerAsset,
            ScaleType = Enum.ScaleType.Crop,
            ImageTransparency = 0.15,
            BorderSizePixel = 0,
            Parent = hdr,
        })
    end

    local gradOverlay = C("Frame",{
        Name = "GradOverlay",
        Size = UDim2.new(1, 0, 0.45, 0),
        Position = UDim2.new(0, 0, 0.55, 0),
        BackgroundColor3 = T.Bg,
        BorderSizePixel = 0,
        Parent = hdr,
    })
    C("UIGradient",{
        Color = ColorSequence.new(Color3.new(1,1,1)),
        Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
        Rotation = 90,
        Parent = gradOverlay,
    })

    local accentLine = C("Frame",{
        Size = UDim2.new(1, -16, 0, 2),
        Position = UDim2.new(0, 8, 1, -1),
        BackgroundColor3 = T.BorderGlow,
        BorderSizePixel = 0,
        Parent = hdr,
    })
    C("UIGradient",{
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 100, 200)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 100, 200)),
        }),
        Parent = accentLine,
    })

    task.spawn(function()
        while _G.DayBreakActive do
            Tw(accentLine, {BackgroundTransparency = 0.6}, 1.2)
            task.wait(1.2)
            Tw(accentLine, {BackgroundTransparency = 0}, 1.2)
            task.wait(1.2)
        end
    end)

    C("Frame",{Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,1,-12),BackgroundColor3=T.Bg,BackgroundTransparency=0,BorderSizePixel=0,Parent=hdr})

    C("TextLabel",{
        Size = UDim2.new(0, 140, 0, 18),
        Position = UDim2.new(0, 12, 1, -22),
        BackgroundTransparency = 1,
        Text = "DayBreak Control",
        TextColor3 = T.Text,
        TextSize = 12,
        Font = T.FM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = hdr,
    })

    local BCL = C("TextLabel",{
        Size = UDim2.new(0, 50, 0, 14),
        Position = UDim2.new(1, -106, 1, -21),
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
        Position = UDim2.new(1, -52, 0, 6),
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
        Position = UDim2.new(1, -26, 0, 6),
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
    -- CONTENT PAGES (Commands List & Bot / RAM Monitor)
    ----------------------------------------------------------------
    local LIST_Y = SEARCH_Y + 32
    local CONTENT_H = -(LIST_Y + 70)

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

    -- Page 2: Live Bot & RAM Monitor Dashboard
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

    -- Ram Page: Summary Header Card
    local ramSummaryCard = C("Frame",{
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = ramPage,
    })
    Cn(ramSummaryCard, UDim.new(0, 6))
    St(ramSummaryCard, T.Border, 0.8)

    local ramSummaryLbl = C("TextLabel",{
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 6, 0, 4),
        BackgroundTransparency = 1,
        Text = "Bot Fleet & Memory Status",
        TextColor3 = T.Accent,
        TextSize = 10,
        Font = T.FM,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ramSummaryCard,
    })

    local flushAllBtn = C("TextButton",{
        Size = UDim2.new(0.48, 0, 0, 20),
        Position = UDim2.new(0, 4, 1, -24),
        BackgroundColor3 = T.Green,
        BackgroundTransparency = 0.6,
        Text = "Flush All RAM",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 9,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = ramSummaryCard,
    })
    Cn(flushAllBtn, UDim.new(0, 4))
    flushAllBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "cleanram")
        Tw(flushAllBtn, {BackgroundTransparency = 0.2}, 0.1)
        task.delay(0.25, function() Tw(flushAllBtn, {BackgroundTransparency = 0.6}, 0.2) end)
    end)

    local lowRamQuickBtn = C("TextButton",{
        Size = UDim2.new(0.48, 0, 0, 20),
        Position = UDim2.new(0.52, 0, 1, -24),
        BackgroundColor3 = T.Yellow,
        BackgroundTransparency = 0.6,
        Text = "Low-RAM Mode",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 9,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = ramSummaryCard,
    })
    Cn(lowRamQuickBtn, UDim.new(0, 4))
    lowRamQuickBtn.MouseButton1Click:Connect(function()
        ChatSend(getgenv().Settings.prefix .. "lowram")
        Tw(lowRamQuickBtn, {BackgroundTransparency = 0.2}, 0.1)
        task.delay(0.25, function() Tw(lowRamQuickBtn, {BackgroundTransparency = 0.6}, 0.2) end)
    end)

    local botCardsContainer = C("Frame",{
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = ramPage,
    })
    C("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3),Parent=botCardsContainer})

    local function RefreshRamMonitor()
        RefreshBotCache()
        for _, ch in ipairs(botCardsContainer:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy() end
        end

        local bots = GetOnlineBotNames()
        local myMemVal = gcinfo() / 1024
        local myMem = string.format("%.1f MB", myMemVal)
        LocalPlayer:SetAttribute("DayBreakRAM", myMem)
        LocalPlayer:SetAttribute("DayBreakRAMVal", myMemVal)

        local totalMem = myMemVal
        local activeBotCount = 0

        -- My Account Card (Host)
        local myCard = C("Frame",{
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = T.Card,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Parent = botCardsContainer,
        })
        Cn(myCard, UDim.new(0, 5))
        St(myCard, T.BorderGlow, 0.8)

        local myFps = LocalPlayer:GetAttribute("DayBreakFPS") or 60
        local myPing = LocalPlayer:GetAttribute("DayBreakPing") or 0

        C("TextLabel",{
            Size = UDim2.new(0.4, 0, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = "  [Host] " .. LocalPlayer.Name,
            TextColor3 = T.Accent,
            TextSize = 10,
            Font = T.FM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = myCard,
        })

        C("TextLabel",{
            Size = UDim2.new(0.55, -6, 1, 0),
            Position = UDim2.new(0.45, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = string.format("%s  |  %d FPS  |  %d ms", myMem, myFps, myPing),
            TextColor3 = T.Green,
            TextSize = 9,
            Font = T.FC,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = myCard,
        })

        -- Each connected Alt Bot Card with LIVE RAM, FPS, PING & VC STATUS
        for i, bName in ipairs(bots) do
            if bName ~= LocalPlayer.Name:lower() then
                activeBotCount = activeBotCount + 1
                local targetPlayer = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Name:lower() == bName then
                        targetPlayer = p
                        break
                    end
                end

                local bRamStr = "-- MB"
                local bRamVal = 0
                local bFps = 0
                local bPing = 0
                local bVc = "N/A"

                if targetPlayer then
                    bRamStr = tostring(targetPlayer:GetAttribute("DayBreakRAM") or "-- MB")
                    bRamVal = tonumber(targetPlayer:GetAttribute("DayBreakRAMVal")) or 0
                    bFps = tonumber(targetPlayer:GetAttribute("DayBreakFPS")) or 0
                    bPing = tonumber(targetPlayer:GetAttribute("DayBreakPing")) or 0
                    bVc = tostring(targetPlayer:GetAttribute("DayBreakVC") or "N/A")
                end
                totalMem = totalMem + bRamVal

                local bCard = C("Frame",{
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = T.Card,
                    BackgroundTransparency = 0.35,
                    BorderSizePixel = 0,
                    Parent = botCardsContainer,
                })
                Cn(bCard, UDim.new(0, 5))
                St(bCard, T.Border, 0.6)

                -- Bot Name & VC Status
                C("TextLabel",{
                    Size = UDim2.new(0.45, 0, 0, 18),
                    Position = UDim2.new(0, 6, 0, 2),
                    BackgroundTransparency = 1,
                    Text = string.format("#%d: %s", i, bName),
                    TextColor3 = T.Text,
                    TextSize = 9,
                    Font = T.FM,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = bCard,
                })

                C("TextLabel",{
                    Size = UDim2.new(0.45, 0, 0, 14),
                    Position = UDim2.new(0, 6, 0, 18),
                    BackgroundTransparency = 1,
                    Text = "VC: " .. bVc,
                    TextColor3 = T.Sub,
                    TextSize = 8,
                    Font = T.FB,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = bCard,
                })

                -- Live RAM, FPS, Ping Metrics
                C("TextLabel",{
                    Size = UDim2.new(0.35, 0, 1, 0),
                    Position = UDim2.new(0.45, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = string.format("%s | %d FPS | %dms", bRamStr, bFps, bPing),
                    TextColor3 = Color3.fromRGB(100, 240, 180),
                    TextSize = 8,
                    Font = T.FC,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = bCard,
                })

                -- Purge Button
                local flushOneBtn = C("TextButton",{
                    Size = UDim2.new(0, 40, 0, 20),
                    Position = UDim2.new(1, -46, 0.5, -10),
                    BackgroundColor3 = T.Surface,
                    BackgroundTransparency = 0.2,
                    Text = "Purge",
                    TextColor3 = T.Green,
                    TextSize = 8,
                    Font = T.FM,
                    AutoButtonColor = false,
                    BorderSizePixel = 0,
                    Parent = bCard,
                })
                Cn(flushOneBtn, UDim.new(0, 3))
                flushOneBtn.MouseButton1Click:Connect(function()
                    ChatSend(string.format("%scleanram %s", getgenv().Settings.prefix, bName))
                    Tw(flushOneBtn, {BackgroundColor3 = T.Green, TextColor3 = Color3.new(1,1,1)}, 0.1)
                    task.delay(0.2, function() Tw(flushOneBtn, {BackgroundColor3 = T.Surface, TextColor3 = T.Green}, 0.2) end)
                end)
            end
        end

        -- Update Summary Header Label
        if ramSummaryLbl then
            ramSummaryLbl.Text = string.format("Fleet: %d Alts | Combined: %.1f MB", activeBotCount, totalMem)
        end
    end

    task.spawn(function()
        while _G.DayBreakActive do
            if ramPage.Visible then
                RefreshRamMonitor()
            end
            task.wait(2)
        end
    end)

    local allCmdBtns = {}
    local layoutOrd = 0

    for _, sec in ipairs(SECTIONS) do
        layoutOrd = layoutOrd + 1

        -- Section header
        local secHdr = C("Frame",{
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = sec.color,
            BackgroundTransparency = 0.88,
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
                    Active = true,
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
    -- QUICK ACTION TOOLBAR (Bring, Stop, LowRAM, Flush, Unemote)
    ----------------------------------------------------------------
    local toolbarFrame = C("Frame",{
        Name = "QuickToolbar",
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 1, -36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = MF,
    })

    local function MakeQuickBtn(name, text, bgCol, pos, sizeW, cmdStr)
        local qb = C("TextButton",{
            Name = name,
            Size = UDim2.new(sizeW, -2, 1, 0),
            Position = pos,
            BackgroundColor3 = bgCol,
            BackgroundTransparency = 0.3,
            Text = text,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 9,
            Font = T.FM,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Parent = toolbarFrame,
        })
        Cn(qb, UDim.new(0, 4))
        qb.MouseEnter:Connect(function() Tw(qb, {BackgroundTransparency=0.1}, 0.1) end)
        qb.MouseLeave:Connect(function() Tw(qb, {BackgroundTransparency=0.3}, 0.1) end)
        qb.MouseButton1Click:Connect(function()
            ChatSend(getgenv().Settings.prefix .. cmdStr)
            Tw(qb, {BackgroundColor3 = T.Green}, 0.1)
            task.delay(0.2, function() Tw(qb, {BackgroundColor3 = bgCol}, 0.2) end)
        end)
        return qb
    end

    MakeQuickBtn("QbBring", "BRING", T.Accent, UDim2.new(0, 0, 0, 0), 0.2, "bring")
    MakeQuickBtn("QbStop", "STOP ALL", T.Red, UDim2.new(0.2, 0, 0, 0), 0.25, "stop")
    MakeQuickBtn("QbLowRam", "LOW RAM", T.Yellow, UDim2.new(0.45, 0, 0, 0), 0.2, "lowram")
    MakeQuickBtn("QbFlush", "PURGE", T.Green, UDim2.new(0.65, 0, 0, 0), 0.17, "cleanram")
    MakeQuickBtn("QbUnemote", "UNEMOTE", T.Surface, UDim2.new(0.82, 0, 0, 0), 0.18, "unemote")
    local function MinimizeGUI()
        Tw(MF, {Size = UDim2.new(0, 0, 0, 0)}, 0.25, Enum.EasingStyle.Back)
        task.delay(0.25, function()
            MF.Visible = false
            iconBtn.Visible = true
            iconBtn.Size = UDim2.new(0, 0, 0, 0)
            Tw(iconBtn, {Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE), BackgroundTransparency = 0.2}, 0.25, Enum.EasingStyle.Back)
        end)
    end

    local function RestoreGUI()
        Tw(iconBtn, {Size = UDim2.new(0, 0, 0, 0)}, 0.15)
        task.delay(0.15, function()
            iconBtn.Visible = false
            MF.Visible = true
            Tw(MF, {Size = UDim2.new(0, WW, 0, WH)}, 0.35, Enum.EasingStyle.Back)
        end)
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
-- ===========================================================
--  INVISIBLE (emote-based, no GUI)
-- ===========================================================
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

-- ===========================================================
--  MUSIC BOT COMMANDS (merged from MusicBots.lua)
--  Uses "/" prefix, only designated bot contacts server
-- ===========================================================
local MusicCommands = {}

MusicCommands.play = function(player, args, rawMessage)
    local prefix = getgenv().Settings.musicPrefix
    local query = rawMessage:sub(#prefix + 5):gsub("^%s+", ""):gsub("%s+$", "")
    if #query < 2 then musicChat("  Search query too short!"); return end

    local now = os.time()
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then
        local cd = getgenv().Settings.musicPlayCooldown or 10
        if MusicState.lastPlayTime[player.Name] and (now - MusicState.lastPlayTime[player.Name]) < cd then
            local rem = cd - (now - MusicState.lastPlayTime[player.Name])
            musicChat(string.format("  @%s wait %d seconds", player.Name, rem))
            return
        end
    end
    MusicState.lastPlayTime[player.Name] = now
    musicChat("  Searching: " .. query)
    task.spawn(function()
        local resp = musicRequest("/play", { query = query, user = player.Name })
        if resp then
            if resp.wait_seconds then
                musicChat(string.format("  Wait %d seconds", resp.wait_seconds))
            elseif resp.reason == "already_playing" then
                musicChat("  That song is already playing!")
            elseif resp.reason == "in_queue" then
                musicChat("  That song is already in the queue!")
            elseif resp.error then
                musicChat("  " .. resp.error)
            elseif resp.status == "queued" then
                local title = resp.title and ("  Queued: " .. resp.title) or "  Queued!"
                musicChat(title)
                if resp.queue_position and resp.queue_position > 1 then
                    task.wait(1); musicChat(string.format("  Position: #%d", resp.queue_position))
                end
            else musicChat("  Request sent!") end
        else musicChat("Ahh Not Sure if ur song got added man, check /queue.") end
    end)
end

MusicCommands.pause = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "pause", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("  You don't have permission!")
            elseif resp.status == "paused" then musicChat("   Music paused") end
        end
    end)
end

MusicCommands.resume = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "resume", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("  You don't have permission!")
            elseif resp.status == "resumed" then musicChat("   Music resumed") end
        end
    end)
end
-- Music continue alias

MusicCommands.skip = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "skip", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("  You don't have permission!")
            elseif resp.status == "skipped" then musicChat("  Skipped current song") end
        end
    end)
end

MusicCommands.musicstop = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "stop", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("  You don't have permission!")
            elseif resp.status == "stopped" then musicChat("   Stopped and cleared queue") end
        end
    end)
end

MusicCommands.volume = function(player, args)
    if not getgenv().Settings.musicEnableVolume then musicChat("  Volume control disabled"); return end
    local vol = tonumber(args[2])
    if not vol or vol < 0 or vol > 100 then musicChat("  Usage: /volume <0-100>"); return end
    task.spawn(function()
        local resp = musicRequest("/control", { action = "volume", value = vol / 100, user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("  You don't have permission!")
            elseif resp.status == "ok" then musicChat(string.format("  Volume set to %d%%", vol)) end
        end
    end)
end

MusicCommands.status = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/status")
        if resp then
            if resp.current_song then
                musicChat("  Now: " .. resp.current_song.title)
                if resp.playback_position and resp.playback_position > 0 then
                    local mins = math.floor(resp.playback_position / 60)
                    local secs = math.floor(resp.playback_position % 60)
                    musicChat(string.format("   Position: %d:%02d", mins, secs))
                end
                if resp.queue_size > 0 then musicChat(string.format("  Queue: %d songs", resp.queue_size)) end
                musicChat(string.format("  Volume: %d%%", math.floor(resp.volume * 100)))
            else
                musicChat("  Nothing playing")
                if resp.queue_size > 0 then musicChat(string.format("  Queue: %d songs waiting", resp.queue_size)) end
            end
        end
    end)
end

MusicCommands.nowplaying = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/nowplaying")
        if resp then
            if resp.playing and resp.title then
                musicChat("  Now Playing: " .. resp.title)
                if resp.position and resp.position > 0 then
                    local mins = math.floor(resp.position / 60)
                    local secs = math.floor(resp.position % 60)
                    local pauseTag = resp.is_paused and " (PAUSED)" or ""
                    musicChat(string.format("   %d:%02d%s", mins, secs, pauseTag))
                end
                if resp.username then musicChat("  Requested by: " .. resp.username) end
                musicChat(string.format("  Volume: %d%%", math.floor((resp.volume or 0.7) * 100)))
            else
                musicChat("  Nothing playing right now")
            end
        end
    end)
end

MusicCommands.queue = function(player, args)
    if not getgenv().Settings.musicEnableQueue then musicChat("  Queue display disabled"); return end
    task.spawn(function()
        local resp = musicRequest("/queue")
        if resp and resp.total > 0 then
            musicChat(string.format("  Queue (%d songs):", resp.total))
            for i, item in ipairs(resp.queue) do
                if i <= 5 then musicChat(string.format("%d. %s", item.position, item.title)); task.wait(0.5) end
            end
            if resp.total > 5 then musicChat(string.format("...and %d more", resp.total - 5)) end
        else musicChat("  Queue is empty") end
    end)
end

MusicCommands.stats = function(player, args)
    if not getgenv().Settings.musicEnableStats then musicChat("  Stats disabled"); return end
    local lookupName = args[2] and (function()
        local tp = FindTarget(args[2], player)
        return tp and tp.Name or args[2]
    end)() or player.Name
    local label = args[2] or player.Name
    task.spawn(function()
        local resp = musicRequest("/stats", { user = lookupName })
        if resp then
            musicChat(string.format("  %s's Stats:", label)); task.wait(0.5)
            musicChat(string.format("   Played: %d", resp.songs_played or 0)); task.wait(0.5)
            musicChat(string.format("   Skipped: %d", resp.songs_skipped or 0))
        end
    end)
end

MusicCommands.history = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/history")
        if resp and resp.history then
            if #resp.history > 0 then
                musicChat("  Recent history:")
                for i, item in ipairs(resp.history) do
                    if i <= 5 then musicChat(string.format("%d. %s", i, item.title)); task.wait(0.5) end
                end
            else musicChat("  No history yet") end
        end
    end)
end

MusicCommands.auth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("  Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("  Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/authorize", { user = tp.Name })
        if resp and resp.status == "authorized" then musicChat(string.format("  %s authorized for controls", tp.DisplayName))
        else musicChat("  Failed to authorize user") end
    end)
end

MusicCommands.unauth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("  Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("  Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/revoke", { user = tp.Name })
        if resp and resp.status == "revoked" then musicChat(string.format("  %s unauthorized", tp.DisplayName))
        else musicChat("  Failed to revoke user") end
    end)
end

MusicCommands.musicblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("  Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("  Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/blacklist", { user = tp.Name })
        if resp and resp.status == "blacklisted" then musicChat(string.format("  %s blacklisted", tp.DisplayName))
        else musicChat("  Failed to blacklist user") end
    end)
end

MusicCommands.unblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("  Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("  Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/unblacklist", { user = tp.Name })
        if resp and resp.status == "unblacklisted" then musicChat(string.format("  %s removed from blacklist", tp.DisplayName))
        else musicChat("  Failed to unblacklist user") end
    end)
end

MusicCommands.musiccmds = function(player, args)
    musicChat("  Music Bot Commands:")
    task.wait(0.5); musicChat("./play <song> - Play a song")
    task.wait(0.5); musicChat("./np - What's playing now")
    task.wait(0.5); musicChat("./status - Full status & queue")
    task.wait(0.5); musicChat("./queue - View queue")
    task.wait(0.5); musicChat("./stats [user] - View statistics")
    task.wait(0.5); musicChat("./history - Recent songs")
    task.wait(0.5); musicChat("   Need controls? Ask for /auth")
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if isMain then task.wait(0.5); musicChat("  Admin: /auth /unauth /blacklist") end
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
            local st = "  Not authorized"
            if resp.is_main_account then st = "  Main Account (always authorized)"
            elseif resp.is_authorized then st = "  Authorized" end
            musicChat(string.format("  %s: %s", label, st))
            if resp.is_blacklisted then musicChat("  (Blacklisted)") end
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
    ["continue"] = MusicCommands.resume,
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

-- ===========================================================
--  AI TOOLS (Tool Gen & Zoom, Gui-less, Multi-Bot Scaled)
-- ===========================================================
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
        if _G.GenToolGenerating then notify("Wait", "Already generating...", 3); return end
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

-- ===========================================================
--  DAYBREAK CLEANUP ENGINE (merged)
--  Strips visual bloat on alt clients for max performance
--  Keeps: HumanoidRootPart, Humanoid, Head, floors, chat, audio
-- ===========================================================

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
        if not IsAnyCharObj(desc) and desc ~= workspace.CurrentCamera and not desc:IsDescendantOf(workspace.CurrentCamera) and not desc:IsA("Terrain") then
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
end

local function CleanOtherPlayerChars()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character

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

-- ===========================================================
--  AUTO-SYNC ENGINE
--  Measures ping & adjusts bot timing for music/movement sync
-- ===========================================================
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

            local memKB = gcinfo()

            task.wait(5)
        end
    end)
end

-- ===========================================================
--  OPTIMIZATION & OVERLAY (main entry)
-- ===========================================================
local function OptimizeAndOverlay()
    if isMainAccount or _isPrimaryCreator then return end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() if setfpscap then setfpscap(getgenv().Settings.fpsCap or 10) end end)

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
    
    InfoLabel.Text = "ALT Control | Developed by DayBreak\nJoin Discord: https://discord.gg/ws5Zb2EzYA\n\nUSER: " .. tostring(LocalPlayer.Name) .. "\nBOT POSITION: " .. string.format("%02d", myIndex)
    InfoLabel.Parent = Background
end

if isAltAccount and not isMainAccount then
    OptimizeAndOverlay()
    
    if getgenv().Settings.announceOnLoad then
        task.spawn(function()
            local idx = SafeIndex() or 1
            local total = SafeTotal() or 1
            task.wait(2.0 + ((idx - 1) * 0.25))
            ChatSend(string.format("* DayBreak Bot #%d/%d Ready", idx, total))
        end)
    end
end

-- ===========================================================
--  18. INITIALIZE
-- ===========================================================
InitAntiAFK()

-- [VCB Monitor Removed]

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
        musicChat("   Music Bot Ready   ")
        task.wait(1)
        musicChat("Type /cmds for commands")
    end)
end

print("DayBreak ALT Control | By @DayBreak")
