--[[
  â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
  â•‘               â˜€ï¸ DAYBREAK ALT CONTROL v3.0 â˜€ï¸                 â•‘
  â•‘             NOCTURNAL STARLIGHT & MEME SQUAD EDITION         â•‘
  â•‘                                                              â•‘
  â•‘  Developed by: DayBreak                                      â•‘
  â•‘  Discord: discord.gg/ws5Zb2EzYA                              â•‘
  â•‘  GitHub:  github.com/DayyBreak69/DayBreak-Alt-Control        â•‘
  â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--]]

getgenv().Settings = {
    -- CONTROLLER & PREFIX
    prefix              = "!",
    mainAccount         = "DayBreak",
    fpsCap              = 10,

    -- ALT ACCOUNTS (Fill with your alt usernames)
    altAccounts         = {
        ["AltAccount1"] = true,
        ["AltAccount2"] = true,
        ["AltAccount3"] = true,
    },

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

    -- MIC TOGGLE
    micUnmuteDelay      = 30,
    micAutoUnmute       = true,
    micPostRejoinDelay  = 10,

    -- REJOIN & TELEPORT
    rejoinDelay         = 10,
    scriptFile          = "DayBreakAltControl.lua",
    scriptLoadstring    = ""
}

local defaultSettings = getgenv().Settings
local userSettings = getgenv().DayBreakSettings or getgenv().Settings or {}
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

-- Smart Creator & Controller Detection:
local _isPrimaryCreator = (_lpNameLower == "daybreak" or _lpNameLower == "dayybreak66" or _lpNameLower == "haylees_ekitty" or _lpNameLower == "xomqhayleealt")
local isMainAccount = false

if _lpNameLower == _mainAccSetting then
    isMainAccount = true
elseif (_mainAccSetting == "daybreak" or _mainAccSetting == "your_main_account_username" or _mainAccSetting == "") and _isPrimaryCreator then
    isMainAccount = true
end

local isAltAccount = false
if not isMainAccount then
    if getgenv().Settings and getgenv().Settings.altAccounts then
        for a in pairs(getgenv().Settings.altAccounts) do
            if a:lower() == _lpNameLower then
                isAltAccount = true
                break
            end
        end
    end
    if not isAltAccount and getgenv().Settings and not _isPrimaryCreator then
        isAltAccount = true
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
            if resp.StatusCode == 401 then musicChat("âŒ API key error"); return nil end
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

    -- Method 2: Periodic heartbeat â€” proactively simulate input every 60s
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
-- 10. StopAll â€” ONLY clears exclusive commands
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SYSTEM COMMANDS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  PERSISTENT: noclip / clip
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  PERSISTENT: ws / speed
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  PERSISTENT: antivoid / unantivoid
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  PERSISTENT: spam / unspam
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MOVEMENT COMMANDS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  DAYBREAK MULTI-METHOD EMOTE & SYNC ENGINE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  CLONE COMMANDS (loopclone is now PERSISTENT)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  WORM
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  STALK
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  DANCE & EMOTE (solo-guarded)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  EMOTE SYSTEM (Dynamic Catalog)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  NPC (wander 30-60s, no duplicate targets, unique lines)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  FIREWORK (solo-guarded)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  NUKE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SWARM
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MATHEMATICAL CURVE ENGINE â€” time-based, deterministic
--  phase = (t / PERIOD + botOffset) * 2Ï€ â†’ smooth, no drift
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  ORBIT CURVES (orbit = basic, orbit1-20 = patterns)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- orbit2: Double helix â€” two interleaved strands
OrbitCurves[2] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(sin(phase)*R, sin(phase*0.5)*(R*0.7), cos(phase)*R)
end

-- orbit3: Atomic â€” bots on tilted orbital planes
OrbitCurves[3] = function(t, i, count, R)
    local P = 16
    local plane = i % 3
    local gi = math.floor((i-1)/3); local gt = math.max(math.ceil(count/3), 1)
    local phase = (t / P + gi/gt) * PI2
    if plane == 0 then return Vector3.new(cos(phase)*R, sin(phase)*R, 0)
    elseif plane == 1 then return Vector3.new(cos(phase)*R, 0, sin(phase)*R)
    else return Vector3.new(0, cos(phase)*R, sin(phase)*R) end
end

-- orbit4: Galaxy spiral arms â€” expanding outward
OrbitCurves[4] = function(t, i, count, R)
    local arms = math.min(3, math.ceil(count/3))
    local arm = (i-1) % arms
    local posInArm = math.floor((i-1)/arms)
    local armAngle = (arm/arms) * PI2
    local dist = 3 + posInArm * 2.5
    local phase = armAngle + posInArm * 0.5 + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i) * 1.5, sin(phase)*dist)
end

-- orbit5: Vertical vortex â€” cone helix
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

-- orbit7: Pulsating â€” radius breathes in and out
OrbitCurves[7] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local breathe = R + sin(t * 2) * (R * 0.5)
    return Vector3.new(cos(phase)*breathe, sin(t*3 + i)*2, sin(phase)*breathe)
end

-- orbit8: Layered rings â€” tilted ring planes
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

-- orbit11: Saturn rings â€” flat ring with Y wobble
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

-- orbit13: Electron cloud â€” spherical scatter orbit
OrbitCurves[13] = function(t, i, count, R)
    local P = 18
    local golden = i * PI * (3 - sqrt(5))
    local phase = t / P + golden
    local theta = math.acos(1 - 2*((i-0.5)/count))
    return Vector3.new(sin(theta)*cos(phase)*R, cos(theta)*R, sin(theta)*sin(phase)*R)
end

-- orbit14: Ferris wheel â€” vertical circle
OrbitCurves[14] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(0, sin(phase)*R, cos(phase)*R)
end

-- orbit15: Cascading waterfall â€” staggered heights
OrbitCurves[15] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local yOff = ((i-1)/count) * 12 - 6
    local breathe = R + sin(t*2 + (i-1)/count * PI2) * 3
    return Vector3.new(sin(phase)*breathe, yOff + sin(phase*3)*1.5, cos(phase)*breathe)
end

-- orbit16: Tornado funnel â€” radius shrinks upward
OrbitCurves[16] = function(t, i, count, R)
    local P = 12
    local frac = (i-1)/count
    local y = frac * 25 - 12
    local funnelR = R * (1 - frac * 0.7)
    local phase = (t / P + frac * 2) * PI2
    return Vector3.new(sin(phase)*funnelR, y, cos(phase)*funnelR)
end

-- orbit17: Heart pulse â€” radius pulses per bot
OrbitCurves[17] = function(t, i, count, R)
    local P = 15
    local phase = (t / P + (i-1)/count) * PI2
    local beat = 1 + abs(sin(t*3 + i*0.7)) * 0.4
    return Vector3.new(sin(phase)*R*beat, sin(t*2+i)*2, cos(phase)*R*beat)
end

-- orbit18: Comet trails â€” elliptical orbits
OrbitCurves[18] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local a, b = R * 1.5, R * 0.6
    return Vector3.new(sin(phase)*a, sin(phase*2)*2, cos(phase)*b)
end

-- orbit19: Mobius twist â€” rotating orbital plane
OrbitCurves[19] = function(t, i, count, R)
    local P = 20
    local phase = (t / P + (i-1)/count) * PI2
    local twist = phase * 0.5
    local x = cos(phase) * R
    local flat = sin(phase) * R
    return Vector3.new(x, flat * sin(twist), flat * cos(twist))
end

-- orbit20: Jellyfish â€” dome with trailing tentacles
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SPIRAL CURVES (spiral1-20 = patterns)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local SpiralCurves = {}

-- spiral1: Upward helix â€” smooth ascending circle
SpiralCurves[1] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local dynR = R + sin(t * 0.5) * 5
    local y = sin(t + (i-1)/count * PI2) * 6
    return Vector3.new(cos(phase)*dynR, y, sin(phase)*dynR)
end

-- spiral2: Cone vortex â€” expanding upward
SpiralCurves[2] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local hd = frac * 16; local ht = sin(t + hd) * 4 + hd
    local cr = (ht / 16) * R
    return Vector3.new(cos(phase)*cr, ht, sin(phase)*cr)
end

-- spiral3: DNA ladder â€” two interleaved strands
SpiralCurves[3] = function(t, i, count, R)
    local P = 14
    local strand = (i % 2 == 0) and 0 or 1
    local pI = math.floor((i-1)/2)
    local height = (pI / math.max(math.ceil(count/2), 1)) * 16
    local phase = (t / P + (i-1)/count) * PI2 + strand * PI
    return Vector3.new(cos(phase)*R, height + sin(t*0.5)*2 - 8, sin(phase)*R)
end

-- spiral4: Dispersal jet â€” eruption pattern
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

-- spiral5: Tornado funnel â€” tightening upward
SpiralCurves[5] = function(t, i, count, R)
    local P = 14
    local frac = (i-1)/count
    local height = ((t/P*0.5 + frac*20) % 20)
    local nH = height / 20
    local tR = R * (0.3 + nH * 0.7)
    local phase = (t / P + frac) * PI2 + nH * PI * 4
    return Vector3.new(cos(phase)*tR, height - 10, sin(phase)*tR)
end

-- spiral6: Golden ratio â€” Fermat's spiral
SpiralCurves[6] = function(t, i, count, R)
    local ga = i * PI * (3 - sqrt(5))
    local dist = sqrt(i) * 3
    local phase = ga + t * 0.5
    return Vector3.new(cos(phase)*dist, sin(t + i*0.5)*2, sin(phase)*dist)
end

-- spiral7: Bouncing spring â€” compression/expansion
SpiralCurves[7] = function(t, i, count, R)
    local P = 10
    local comp = sin(t * 1.5) * 0.5 + 0.5
    local spacing = 2 + comp * 4
    local y = (i - (count+1)/2) * spacing
    local phase = (t / P + (i-1)/count) * PI2
    return Vector3.new(cos(phase)*(R*(0.5+comp*0.5)), y, sin(phase)*(R*(0.5+comp*0.5)))
end

-- spiral8: Inward pool â€” shrinking spiral
SpiralCurves[8] = function(t, i, count, R)
    local P = 16
    local frac = (i-1)/count
    local cycle = (t/P*0.4 + frac * PI2) % PI2; local ph = cycle / PI2
    local wR = R * (1 - ph * 0.8)
    local phase = (t / P + frac) * PI2 + ph * PI * 4
    return Vector3.new(cos(phase)*wR, -ph*8 + 4, sin(phase)*wR)
end

-- spiral9: Wavy ascent â€” radius waves
SpiralCurves[9] = function(t, i, count, R)
    local P = 14
    local phase = (t / P + (i-1)/count) * PI2
    local wR = R + sin(phase*3 + t) * (R*0.4)
    return Vector3.new(cos(phase)*wR, sin(t + (i-1)/count * PI2)*6, sin(phase)*wR)
end

-- spiral10: Layered cascade â€” stacked rotating rings
SpiralCurves[10] = function(t, i, count, R)
    local layers = math.min(4, math.ceil(count/2))
    local layer = (i-1) % layers
    local pil = math.floor((i-1)/layers)
    local bpl = math.max(math.ceil(count/layers), 1)
    local phase = ((pil/bpl) * PI2) + t * (1 + layer*0.3)
    local y = (layer - (layers-1)/2) * 5
    return Vector3.new(cos(phase)*R, y, sin(phase)*R)
end

-- spiral11: Helix staircase â€” stepped ascent
SpiralCurves[11] = function(t, i, count, R)
    local P = 18
    local phase = (t / P + (i-1)/count) * PI2
    local step = math.floor(phase / (PI/4)) * 2
    local y = step + sin(phase * 2) * 0.5
    return Vector3.new(sin(phase)*R, y - 8, cos(phase)*R)
end

-- spiral12: Whirlpool â€” accelerating inward spiral
SpiralCurves[12] = function(t, i, count, R)
    local P = 20
    local frac = (i-1)/count
    local phase = (t / P + frac) * PI2
    local accel = 1 + frac * 2
    local wR = R * (1 - frac * 0.6)
    return Vector3.new(sin(phase*accel)*wR, frac*15 - 7, cos(phase*accel)*wR)
end

-- spiral13: Aurora wave â€” flowing sine curtain
SpiralCurves[13] = function(t, i, count, R)
    local spread = ((i-1)/count) * PI2
    local x = sin(spread) * R
    local z = cos(spread) * R
    local wave = sin(t + spread * 2) * 5 + sin(t*1.7 + spread) * 3
    return Vector3.new(x, wave, z)
end

-- spiral14: Firework burst â€” expanding outward
SpiralCurves[14] = function(t, i, count, R)
    local golden = i * PI * (3 - sqrt(5))
    local theta = math.acos(1 - 2*((i-0.5)/count))
    local pulse = (sin(t*2) + 1) * 0.5
    local dist = R * (0.3 + pulse * 0.7)
    return Vector3.new(sin(theta)*cos(golden+t*0.3)*dist, cos(theta)*dist, sin(theta)*sin(golden+t*0.3)*dist)
end

-- spiral15: Pendulum â€” swinging column
SpiralCurves[15] = function(t, i, count, R)
    local y = ((i-1)/count) * 20 - 10
    local swing = sin(t + y * 0.2) * R * 0.8
    local depth = cos(t * 0.7 + y * 0.15) * R * 0.4
    return Vector3.new(swing, y, depth)
end

-- spiral16: Galaxy arm â€” logarithmic spiral
SpiralCurves[16] = function(t, i, count, R)
    local frac = (i-1)/count
    local angle = frac * PI * 6 + t * 0.4
    local dist = 2 + frac * R
    local y = sin(t + frac * PI2) * 2
    return Vector3.new(cos(angle)*dist, y, sin(angle)*dist)
end

-- spiral17: Slinky â€” bouncing helix
SpiralCurves[17] = function(t, i, count, R)
    local P = 12
    local phase = (t / P + (i-1)/count) * PI2
    local bounce = abs(sin(t * 1.5)) * 8
    local y = ((i-1)/count) * bounce - bounce/2
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral18: Crown â€” tiara pattern
SpiralCurves[18] = function(t, i, count, R)
    local P = 16
    local phase = (t / P + (i-1)/count) * PI2
    local spikes = 5
    local y = abs(sin(phase * spikes)) * 6
    return Vector3.new(sin(phase)*R, y, cos(phase)*R)
end

-- spiral19: Cyclone eye â€” double vortex
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

-- spiral20: Fountain â€” rising and falling arcs
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  HELICOPTER â€” rigid circle around Head, all bots in sync
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                -- Lie flat: face head, then pitch 90Â° so feet point at head
                mR.CFrame = CFrame.new(orbitalPos, headPos) * CFrame.Angles(math.rad(90), 0, 0)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end
Commands.heli = Commands.helicopter

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  QUIT / EXIT / LEAVE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
Commands.quit = function(args, speaker)
    if not IsSoloCommand(args) then return end
    StopAll(); ChatSend("Quitting - Bye " .. tostring(getgenv().Settings.mainAccount))
    task.delay(3, function() LocalPlayer:Kick("DayBreak: Quit") end)
end
Commands.exit = Commands.quit; Commands.leave = Commands.quit

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SHIELD 1-5
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  PING / RAM / CPU
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    task.wait((idx - 1) * 0.05)
    local memMB = string.format("%.1f", gcinfo() / 1024)
    ChatSend(string.format("â˜€ï¸ Bot #%d Memory: %s MB", idx, memMB))
end
Commands.memory = Commands.ram

Commands.lowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(false)
    if SafeIndex() == 1 then ChatSend("âš¡ Ultra-Low RAM Mode Activated (Max FPS)") end
end

Commands.unlowram = function(args, speaker)
    local shouldRun, _ = ParseBotTarget(args)
    if not shouldRun then return end
    ApplyRenderMode(true)
    if SafeIndex() == 1 then ChatSend("âœ¨ Normal Graphics Restored") end
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
    task.wait((idx - 1) * 0.05)
    ChatSend(string.format("ðŸ§¹ Bot #%d Cleaned %d KB", idx, saved))
end
Commands.flush = Commands.cleanram
Commands.ramclean = Commands.cleanram

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  VIRAL MEME & TROLL SQUAD COMMANDS (Nocturnal Edition)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
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
        local chants = {"âœ¦ LUX NOCTIS âœ¦", "âœ§ THE STAR AWAKENS âœ§", "âœ¦ CONSUME THE LIGHT âœ¦", "âœ§ DAYBREAK ASCENDS âœ§"}
        local chantTimer = 0
        local spinAngle = 0

        while _G.CurrentCommand == "ritual" and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                spinAngle = (spinAngle + 0.04) % (math.pi * 2)
                local radius = 8
                local angle = spinAngle + (((idx - 1) / math.max(1, total)) * math.pi * 2)
                local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
            end

            chantTimer = chantTimer + 0.03
            if chantTimer >= 4 then
                chantTimer = 0
                if idx == 1 then
                    local chant = chants[math.random(1, #chants)]
                    ChatSend(chant)
                end
            end
            task.wait(0.03)
        end
    end)
end

-- 3. PAPARAZZI / FLASH MOB
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
        local questions = {"OMG OVER HERE!! ðŸ“¸", "LOOK THIS WAY!! ðŸ“·", "ONE MORE SMILE!! âœ¨", "IS IT TRUE?! ðŸ“¸", "EXCLUSIVE PHOTO!! ðŸ“·"}
        local flashTimer = 0

        while _G.CurrentCommand == "paparazzi" and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local radius = 5 + (math.sin(os.clock() * 3 + idx) * 1.5)
                local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2 + (math.sin(os.clock() + idx) * 0.3)
                local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
            end

            flashTimer = flashTimer + 0.03
            if flashTimer >= (8 + (idx * 2.0)) then
                flashTimer = 0
                local q = questions[math.random(1, #questions)]
                task.wait((idx - 1) * 0.25)
                ChatSend(string.format("[Bot #%d] %s", idx, q))
            end
            task.wait(0.03)
        end
    end)
end

-- 4. COFFIN DANCE / PALLBEARERS
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
        local step = 0
        while _G.CurrentCommand == "coffin" and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                step = step + 0.08
                local side = (idx % 2 == 0) and 1 or -1
                local row = math.floor((idx - 1) / 2)
                local sideOffset = side * 4
                local backOffset = -row * 3.5

                local bobHeight = math.abs(math.sin(step + (row * 0.5))) * 1.8
                local forwardLook = tHrp.CFrame.LookVector
                local rightLook = tHrp.CFrame.RightVector
                local targetPos = tHrp.Position + (rightLook * sideOffset) + (forwardLook * backOffset) + Vector3.new(0, bobHeight, 0)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + forwardLook)
            end
            task.wait(0.03)
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
        while _G.CurrentCommand == "conga" and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local dist = idx * 3.2
                local sway = math.sin(os.clock() * 4 + (idx * 0.8)) * 1.5
                local targetPos = tHrp.Position - (tHrp.CFrame.LookVector * dist) + (tHrp.CFrame.RightVector * sway)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, targetPos + tHrp.CFrame.LookVector)
            end
            task.wait(0.03)
        end
    end)
end

-- 6. MENACING STARE / VOID GAZE
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
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local radius = 7
                local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2
                local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
            end
            task.wait(0.03)
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
        local angle = ((idx - 1) / math.max(1, total)) * math.pi * 2
        local height = (idx - 1) * 1.5

        while _G.CurrentCommand == "tornado" and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                angle = (angle + 0.12) % (math.pi * 2)
                local radius = 4 + (height * 0.5)
                local targetPos = tHrp.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
                myChar.HumanoidRootPart.CFrame = CFrame.lookAt(targetPos, Vector3.new(tHrp.Position.X, targetPos.Y, tHrp.Position.Z))
            end
            task.wait(0.02)
        end
    end)
end

-- 8. CREEPER STEALTH (Red Light Green Light)
_G.CreeperActive = false
Commands.creeper = function(args, speaker)
    local shouldRun, newArgs = ParseBotTarget(args)
    if not shouldRun then return end
    local target = FindTarget(newArgs[2], speaker)
    if not target or not target.Character then return end

    StopAll()
    _G.CurrentCommand = "creeper"
    _G.CreeperActive = true
    local idx = SafeIndex()

    task.spawn(function()
        while _G.CurrentCommand == "creeper" and _G.CreeperActive and _G.DayBreakActive do
            if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
                task.wait(0.2)
                continue
            end
            local tHrp = target.Character.HumanoidRootPart
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local myHrp = myChar.HumanoidRootPart
                local toTarget = (tHrp.Position - myHrp.Position)
                local targetLook = tHrp.CFrame.LookVector
                local dot = targetLook:Dot((-toTarget).Unit)

                local targetIsLooking = dot > 0.1
                if not targetIsLooking then
                    local stepDist = 0.5 + (idx * 0.05)
                    local newPos = myHrp.Position + (toTarget.Unit * stepDist)
                    if (newPos - tHrp.Position).Magnitude > 3 then
                        myHrp.CFrame = CFrame.lookAt(newPos, Vector3.new(tHrp.Position.X, newPos.Y, tHrp.Position.Z))
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end

Commands.uncreeper = function(args, speaker)
    _G.CreeperActive = false
    StopAll()
    if SafeIndex() == 1 then ChatSend("Creeper mode deactivated") end
end


-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  CARPET / FLOOR / BRIDGE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SPIN
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
Commands.spin = function(args, speaker)
    local spinSpd = tonumber(args[2]) or 20
    StopAll(); task.wait(0.1); _G.CurrentCommand = "Spin"
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  VFLING / KILL
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  BANG
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                if inc then step += stepInc; if step >= 1 then inc = false end
                else step -= stepInc; if step <= 0 then inc = true end end
                mR.CFrame = tR.CFrame * CFrame.new(0, 0, 0.8 + step * 1.2)
                mR.Velocity = Vector3.zero; mR.RotVelocity = Vector3.zero
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  FBANG â€” no spin fix: lock CFrame every frame
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                if inc then step += stepInc; if step >= 1 then inc = false end
                else step -= stepInc; if step <= 0 then inc = true end end
                local zOff = 0.5 + step * 1.5
                local isR15 = LocalPlayer.Character:FindFirstChild("LowerTorso") ~= nil
                local yOffset = isR15 and 0.75 or 0
                local headPos = tHead.Position
                local frontPos = tHead.CFrame.Position + tHead.CFrame.LookVector * zOff
                local botPos = Vector3.new(frontPos.X, headPos.Y + yOffset, frontPos.Z)
                -- Lock facing direction toward target head â€” prevents spin
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MIRROR SUITE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  RIZZ â€” queue approach, walk close to target, say line
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
Commands.rizz = function(args, speaker)
    StopAll(); task.wait(0.1)
    local target = FindTarget(args[2], speaker)
    if not target or not target.Character then return end
    _G.CurrentCommand = "Rizz"
    local lines = {
        "I don't usually get distracted, but you made me forget what I was saying.",
        "You've got that calm energy that makes everything feel easier.",
        "There's something about you that feels different â€” in a good way.",
        "I can tell you're not just pretty, you've got depth.",
        "I don't think you realize how naturally attractive your vibe is.",
        "You seem like the kind of person people feel safe around.",
        "I wasn't planning on staying long, but you changed that.",
        "You've got that quiet confidence that's hard to ignore.",
        "I like how you carry yourself. It says a lot.",
        "Talking to you feels way too easyâ€¦ and I don't mind that at all.",
        "You don't even have to try. That's what makes it dangerous.",
        "I respect how you move â€” it's rare.",
        "I don't throw compliments around, but you earned that one.",
        "If energy is real, yours is undefeated.",
        "I'm not even trying to impress youâ€¦ I just like talking to you.",
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MBANG
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  HS 1-20 (Harassment Strike variants)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local HS_MESSAGES = {
    [1]  = "(á€·ã€fà¹€É¹áƒºkÉÔ€áƒ§áƒ¿à¹€É¹êž…Ä±à¸²à¸²áƒ¿Ä±à¸²à¸²êž…à¸¥à¸žã€ (á€·)`",
    [2]  = "(á€·ã€áƒºlà¸²à¹€É¹á€Œà¸£ÉÄ±à¸²à¸²ÉÄ±à¸²à¸¥Ä±à¸²Ô€à¸£à¸žà¸¥Ä±à¸²Ô€á»‹Î½Éáƒ¿ffà¸¥fà¹€É¹áƒºká»‹Ä±à¸²á€Œlà¸§êž…á»‹Ô€á€ŒÉã€ (á€·)`",
    [3]  = "(á€·ã€á»‹'Æ–Æ–Î½á»‹áƒ¿Æ–à¸¥Ï¯Éáƒ§áƒ¿à¹€É¹êž…là¸§Æ–áƒ¿áƒ¿Ô€Æ–á»‹Ä±à¸²É,áƒ§áƒ¿à¹€É¹áƒºà¹€É¹Ä±à¸²Ï¯ã€ (á€·)`",
    [4]  = "(á€·ã€áƒºà¸¥Ä±à¸²à¸žÉÔ€áƒ¿là¸§áƒ¿áƒ¿Ä±à¸²à¸²là¸§à¸¥áƒ§à¸¥là¸²ã€ (á€·)`",
    [5]  = "(á€·ã€êž…à¸¥Ä±à¸²à¸²à¸¥Ô€á»‹Æ–Ô€áƒ¿à¹€É¹êžà¸§áƒ§áƒ¿à¹€É¹êž…êž…ÉáƒºÏ¯à¹€É¹Ä±à¸²à¸²ã€ (á€·)`",
    [6]  = "(á€·ã€áƒ§áƒ¿à¹€É¹êž…Ä±à¸²à¸²áƒ¿Ä±à¸²à¸²à¸£É‹à¹€É¹á»‹êž…Ï¯ÉÔ€áƒ¿Ä±à¸²Ä±à¸²à¸²Éã€ (á€·)`",
    [7]  = "(á€·ã€à¸£à¸žà¸¥Æ–Æ–áƒ¿à¸žlà¸§Æ–Éà¸¥áƒºlà¸²áƒºà¹€É¹Ä±à¸²Ï¯ã€ (á€·)`",
    [8]  = "(á€·ã€à¸£kà¹€É¹Æ–Æ–fà¹€É¹áƒºkáƒºáƒ¿êž…êžà¸§à¸£Éã€ (á€·)`",
    [9]  = "(á€·ã€áƒºà¹€É¹Ä±à¸²à¸²êž…à¸¥á€Œlà¸§à¸¥là¸§áƒ§là¸§á»‹Ï¯áƒºlà¸²ã€ (á€·)`",
    [10] = "(á€·ã€á€ŒÆ–à¸¥à¸£à¸£á»‹Ä±à¸²à¸¥à¸£à¸£áƒºà¹€É¹Ä±à¸²Ï¯ã€ (á€·)`",
    [11] = "(á€·ã€Æ–á»‹áƒºklà¸§à¸¥Æ–Æ–à¸£Ï¯là¸²ÉÄ±à¸²Ô€á»‹Éã€ (á€·)`",
    [12] = "(á€·ã€á»‹Æ–Æ–êž…à¸¥êžà¸§Éáƒ§áƒ¿à¹€É¹êž…fà¸¥Ä±à¸²à¸²á»‹Æ–áƒ§ã€ (á€·)`",
    [13] = "(á€·ã€Éà¸¥Ï¯à¸¥à¸£à¸£à¸¥Ä±à¸²Ô€là¸²à¸¥Ä±à¸²á€ŒÏ¯à¸žá»‹áƒºÉã€ (á€·)`",
    [14] = "(á€·ã€à¸£là¸²áƒ¿Î½Éà¸¥áƒºà¸¥áƒºÏ¯à¹€É¹à¸£à¹€É¹êžà¸§áƒ§áƒ¿à¹€É¹êž…à¸¥à¸£à¸£áƒºà¹€É¹Ä±à¸²Ï¯ã€ (á€·)`",
    [15] = "(á€·ã€Ô€êž…á»‹Ä±à¸²kêžà¸§á»‹à¸£à¸£Ï¯là¸²ÉÄ±à¸²É‰à¹€É¹Ä±à¸²à¸²êžà¸§á»‹Ä±à¸²Ï¯êž…à¸¥ffá»‹áƒºlà¸§á»‹Ï¯áƒºlà¸²ã€ (á€·)`",
    [16] = "(á€·ã€áƒºà¹€É¹êž…là¸§à¸£Ï¯áƒ¿Ä±à¸²à¸²êžà¸§áƒ§áƒ¿à¹€É¹êž…à¸žlà¸²áƒ¿Æ–Éfà¹€É¹áƒºká»‹Ä±à¸²á€Œfà¸¥Ä±à¸²à¸²á»‹Æ–áƒ§ã€ (á€·)`",
    [17] = "(á€·ã€áƒ§áƒ¿à¹€É¹áƒºà¹€É¹Ä±à¸²à¸²êž…à¸¥á€ŒÏ¯à¸žà¸¥Ï¯,áƒ§áƒ¿à¹€É¹É‰à¹€É¹à¸£Ï¯Ä±à¸²à¸²à¸¥kÉÄ±à¸²à¸²áƒ§fà¸¥áƒºÉÄ±à¸²à¸²ÉÄ±à¸²à¸²Éã€ (á€·)`",
    [18] = "(á€·ã€Ï¯êž…à¸¥Ä±à¸²Ä±à¸²áƒ§áƒºà¹€É¹Ä±à¸²Ï¯là¸§á»‹Ï¯áƒºlà¸²ã€ (á€·)`",
    [19] = "(á€·ã€áƒºà¹€É¹Ä±à¸²à¸²á€Œà¹€É¹Ê‘Ê‘Æ–á»‹Ä±à¸²á€Œfà¸¥á€Œã€ (á€·)`",
    [20] = "(á€·ã€à¸¥á»‹Ô€à¸£É‹à¹€É¹ÉÉêž…Ï¯êž…à¸¥à¸£là¸²ã€ (á€·)`",
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  CREDITS / ALTCOUNT / WHISPER / GRAB / EQUIP / UPTIME
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

Commands.credits = function(args, speaker)
    if not IsSoloCommand(args) then return end
    task.spawn(function()
        task.wait((SafeIndex()-1)*0.5)
        ChatSend("ðŸ”¥ DayBreak ALT Control | Designed by DayBreak ðŸ”¥")
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  FORMATIONS: arrow, box
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SCANALL
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  SAY / TP / SCATTER / FREEZE / COUNTDOWN / REJOIN / WAVE / CMDS
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
        if idx == 1 then ChatSend("GO! ðŸš€") end
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  13. UNIFIED COMMAND DISPATCH (with bot-targeting)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  14. CHAT LISTENER
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  15. PASSCODE GATE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local function HandlePasscode(p, message)
    if message ~= "á•¦(Ã²_Ã³Ë‡)á•¤" and message ~= "!daybreak_master_key" and message ~= "daybreak::master" then return end
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  16. RESOURCE OPTIMIZATION (Alts only)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  17. MAIN ACCOUNT COMMAND GUI (Refined Compact)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    local STAR_LOGO_B64 = [[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]]

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

    local ICON_SIZE = 46
    local iconBtn = C("ImageButton",{
        Name = "DayBreakStarIcon",
        Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
        Position = UDim2.new(0, 14, 1, -(ICON_SIZE + 14)),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.1,
        Image = GetStarLogoAsset(),
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Visible = false,
        Parent = SG,
    })
    Cn(iconBtn, UDim.new(0, 12))
    St(iconBtn, T.BorderGlow, 1.8)
    MakeDraggable(iconBtn, iconBtn)
    iconBtn.MouseEnter:Connect(function() Tw(iconBtn, {BackgroundTransparency=0, Size=UDim2.new(0, ICON_SIZE+4, 0, ICON_SIZE+4)}, 0.15) end)
    iconBtn.MouseLeave:Connect(function() Tw(iconBtn, {BackgroundTransparency=0.1, Size=UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)}, 0.15) end)

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
        Text = "ðŸ“Š Bot Fleet & Memory Status",
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
        Text = "ðŸ§¹ Flush All RAM",
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
        Text = "âš¡ Low-RAM Mode",
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
        local myMem = string.format("%.1f MB", gcinfo() / 1024)

        -- My Account Card
        local myCard = C("Frame",{
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = T.Card,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            Parent = botCardsContainer,
        })
        Cn(myCard, UDim.new(0, 5))
        St(myCard, T.BorderGlow, 0.8)

        C("TextLabel",{
            Size = UDim2.new(0.55, 0, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = "ðŸŸ¢ " .. LocalPlayer.Name .. " (You)",
            TextColor3 = T.Text,
            TextSize = 10,
            Font = T.FM,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = myCard,
        })

        C("TextLabel",{
            Size = UDim2.new(0.4, -6, 1, 0),
            Position = UDim2.new(0.6, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = myMem,
            TextColor3 = T.Green,
            TextSize = 10,
            Font = T.FC,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = myCard,
        })

        -- Each connected Alt Bot Card
        for i, bName in ipairs(bots) do
            if bName ~= LocalPlayer.Name:lower() then
                local bCard = C("Frame",{
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = T.Card,
                    BackgroundTransparency = 0.35,
                    BorderSizePixel = 0,
                    Parent = botCardsContainer,
                })
                Cn(bCard, UDim.new(0, 5))
                St(bCard, T.Border, 0.6)

                C("TextLabel",{
                    Size = UDim2.new(0.55, 0, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1,
                    Text = string.format("ðŸ¤– Bot #%d: %s", i, bName),
                    TextColor3 = T.Sub,
                    TextSize = 9,
                    Font = T.FB,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = bCard,
                })

                local flushOneBtn = C("TextButton",{
                    Size = UDim2.new(0, 48, 0, 18),
                    Position = UDim2.new(1, -54, 0.5, -9),
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
    -- DUAL TAB SWITCHER (Commands / Bot RAM)
    ----------------------------------------------------------------
    local tabBar = C("Frame",{
        Name = "TabBar",
        Size = UDim2.new(1, -16, 0, 24),
        Position = UDim2.new(0, 8, 1, -64),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = MF,
    })
    Cn(tabBar, UDim.new(0, 5))
    St(tabBar, T.Border, 0.6)

    local tabCmdsBtn = C("TextButton",{
        Size = UDim2.new(0.5, -2, 1, -2),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = T.Surface,
        BackgroundTransparency = 0.1,
        Text = "âš¡ Commands",
        TextColor3 = T.Accent,
        TextSize = 10,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = tabBar,
    })
    Cn(tabCmdsBtn, UDim.new(0, 4))

    local tabRamBtn = C("TextButton",{
        Size = UDim2.new(0.5, -2, 1, -2),
        Position = UDim2.new(0.5, 1, 0, 1),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.7,
        Text = "ðŸ“Š Bot & RAM",
        TextColor3 = T.Sub,
        TextSize = 10,
        Font = T.FM,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = tabBar,
    })
    Cn(tabRamBtn, UDim.new(0, 4))

    tabCmdsBtn.MouseButton1Click:Connect(function()
        listPage.Visible = true
        ramPage.Visible = false
        SF.Visible = true
        tabCmdsBtn.BackgroundColor3 = T.Surface
        tabCmdsBtn.TextColor3 = T.Accent
        tabCmdsBtn.BackgroundTransparency = 0.1
        tabRamBtn.BackgroundColor3 = T.Card
        tabRamBtn.TextColor3 = T.Sub
        tabRamBtn.BackgroundTransparency = 0.7
    end)

    tabRamBtn.MouseButton1Click:Connect(function()
        listPage.Visible = false
        ramPage.Visible = true
        SF.Visible = false
        tabRamBtn.BackgroundColor3 = T.Surface
        tabRamBtn.TextColor3 = T.Green
        tabRamBtn.BackgroundTransparency = 0.1
        tabCmdsBtn.BackgroundColor3 = T.Card
        tabCmdsBtn.TextColor3 = T.Sub
        tabCmdsBtn.BackgroundTransparency = 0.7
        RefreshRamMonitor()
    end)

    ----------------------------------------------------------------
    -- GLOBAL STOP BUTTON
    ----------------------------------------------------------------
    local stopBtn = C("TextButton",{
        Name = "GlobalStopBtn",
        Size = UDim2.new(1, -16, 0, 28),
        Position = UDim2.new(0, 8, 1, -36),
        BackgroundColor3 = T.Red,
        BackgroundTransparency = 0.45,
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
    stopBtn.MouseLeave:Connect(function() Tw(stopBtn, {BackgroundTransparency=0.45}, 0.1) end)
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
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  INVISIBLE (emote-based, no GUI)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  MUSIC BOT COMMANDS (merged from MusicBots.lua)
--  Uses "/" prefix, only designated bot contacts server
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local MusicCommands = {}

MusicCommands.play = function(player, args, rawMessage)
    local prefix = getgenv().Settings.musicPrefix
    local query = rawMessage:sub(#prefix + 5):gsub("^%s+", ""):gsub("%s+$", "")
    if #query < 2 then musicChat("âŒ Search query too short!"); return end

    local now = os.time()
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then
        local cd = getgenv().Settings.musicPlayCooldown or 10
        if MusicState.lastPlayTime[player.Name] and (now - MusicState.lastPlayTime[player.Name]) < cd then
            local rem = cd - (now - MusicState.lastPlayTime[player.Name])
            musicChat(string.format("â³ @%s wait %d seconds", player.Name, rem))
            return
        end
    end
    MusicState.lastPlayTime[player.Name] = now
    musicChat("ðŸ” Searching: " .. query)
    task.spawn(function()
        local resp = musicRequest("/play", { query = query, user = player.Name })
        if resp then
            if resp.wait_seconds then
                musicChat(string.format("â³ Wait %d seconds", resp.wait_seconds))
            elseif resp.reason == "already_playing" then
                musicChat("ðŸŽµ That song is already playing!")
            elseif resp.reason == "in_queue" then
                musicChat("ðŸ“‹ That song is already in the queue!")
            elseif resp.error then
                musicChat("âŒ " .. resp.error)
            elseif resp.status == "queued" then
                local title = resp.title and ("âœ… Queued: " .. resp.title) or "âœ… Queued!"
                musicChat(title)
                if resp.queue_position and resp.queue_position > 1 then
                    task.wait(1); musicChat(string.format("ðŸ“‹ Position: #%d", resp.queue_position))
                end
            else musicChat("âœ… Request sent!") end
        else musicChat("Ahh Not Sure if ur song got added man, check /queue.") end
    end)
end

MusicCommands.pause = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "pause", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("â›” You don't have permission!")
            elseif resp.status == "paused" then musicChat("âš ï¸ Music paused") end
        end
    end)
end

MusicCommands.resume = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "resume", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("â›” You don't have permission!")
            elseif resp.status == "resumed" then musicChat("âœ”ï¸ Music resumed") end
        end
    end)
end
MusicCommands.continue = function(p, a) MusicCommands.resume(p, a) end

MusicCommands.skip = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "skip", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("â›” You don't have permission!")
            elseif resp.status == "skipped" then musicChat("ðŸŽµ Skipped current song") end
        end
    end)
end

MusicCommands.musicstop = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/control", { action = "stop", user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("â›” You don't have permission!")
            elseif resp.status == "stopped" then musicChat("âœ”ï¸ Stopped and cleared queue") end
        end
    end)
end

MusicCommands.volume = function(player, args)
    if not getgenv().Settings.musicEnableVolume then musicChat("âŒ Volume control disabled"); return end
    local vol = tonumber(args[2])
    if not vol or vol < 0 or vol > 100 then musicChat("âŒ Usage: /volume <0-100>"); return end
    task.spawn(function()
        local resp = musicRequest("/control", { action = "volume", value = vol / 100, user = player.Name })
        if resp then
            if resp.authorized == false or resp.error == "Not authorized" then musicChat("â›” You don't have permission!")
            elseif resp.status == "ok" then musicChat(string.format("ðŸ”Š Volume set to %d%%", vol)) end
        end
    end)
end

MusicCommands.status = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/status")
        if resp then
            if resp.current_song then
                musicChat("ðŸŽµ Now: " .. resp.current_song.title)
                if resp.playback_position and resp.playback_position > 0 then
                    local mins = math.floor(resp.playback_position / 60)
                    local secs = math.floor(resp.playback_position % 60)
                    musicChat(string.format("â±ï¸ Position: %d:%02d", mins, secs))
                end
                if resp.queue_size > 0 then musicChat(string.format("ðŸ“‹ Queue: %d songs", resp.queue_size)) end
                musicChat(string.format("ðŸ”Š Volume: %d%%", math.floor(resp.volume * 100)))
            else
                musicChat("ðŸ™„ Nothing playing")
                if resp.queue_size > 0 then musicChat(string.format("ðŸ“‹ Queue: %d songs waiting", resp.queue_size)) end
            end
        end
    end)
end

MusicCommands.nowplaying = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/nowplaying")
        if resp then
            if resp.playing and resp.title then
                musicChat("ðŸŽµ Now Playing: " .. resp.title)
                if resp.position and resp.position > 0 then
                    local mins = math.floor(resp.position / 60)
                    local secs = math.floor(resp.position % 60)
                    local pauseTag = resp.is_paused and " (PAUSED)" or ""
                    musicChat(string.format("â±ï¸ %d:%02d%s", mins, secs, pauseTag))
                end
                if resp.username then musicChat("ðŸ‘¤ Requested by: " .. resp.username) end
                musicChat(string.format("ðŸ”Š Volume: %d%%", math.floor((resp.volume or 0.7) * 100)))
            else
                musicChat("ðŸ™„ Nothing playing right now")
            end
        end
    end)
end

MusicCommands.queue = function(player, args)
    if not getgenv().Settings.musicEnableQueue then musicChat("âŒ Queue display disabled"); return end
    task.spawn(function()
        local resp = musicRequest("/queue")
        if resp and resp.total > 0 then
            musicChat(string.format("ðŸ“‹ Queue (%d songs):", resp.total))
            for i, item in ipairs(resp.queue) do
                if i <= 5 then musicChat(string.format("%d. %s", item.position, item.title)); task.wait(0.5) end
            end
            if resp.total > 5 then musicChat(string.format("...and %d more", resp.total - 5)) end
        else musicChat("ðŸ“‹ Queue is empty") end
    end)
end

MusicCommands.stats = function(player, args)
    if not getgenv().Settings.musicEnableStats then musicChat("âŒ Stats disabled"); return end
    local lookupName = args[2] and (function()
        local tp = FindTarget(args[2], player)
        return tp and tp.Name or args[2]
    end)() or player.Name
    local label = args[2] or player.Name
    task.spawn(function()
        local resp = musicRequest("/stats", { user = lookupName })
        if resp then
            musicChat(string.format("ðŸ“Š %s's Stats:", label)); task.wait(0.5)
            musicChat(string.format("âœ”ï¸ Played: %d", resp.songs_played or 0)); task.wait(0.5)
            musicChat(string.format("âœ”ï¸ Skipped: %d", resp.songs_skipped or 0))
        end
    end)
end

MusicCommands.history = function(player, args)
    task.spawn(function()
        local resp = musicRequest("/history")
        if resp and resp.history then
            if #resp.history > 0 then
                musicChat("ðŸ“œ Recent history:")
                for i, item in ipairs(resp.history) do
                    if i <= 5 then musicChat(string.format("%d. %s", i, item.title)); task.wait(0.5) end
                end
            else musicChat("ðŸ“œ No history yet") end
        end
    end)
end

MusicCommands.auth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("â›” Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("âŒ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/authorize", { user = tp.Name })
        if resp and resp.status == "authorized" then musicChat(string.format("âœ… %s authorized for controls", tp.DisplayName))
        else musicChat("âŒ Failed to authorize user") end
    end)
end

MusicCommands.unauth = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("â›” Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("âŒ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/revoke", { user = tp.Name })
        if resp and resp.status == "revoked" then musicChat(string.format("âŒ %s unauthorized", tp.DisplayName))
        else musicChat("âŒ Failed to revoke user") end
    end)
end

MusicCommands.musicblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("â›” Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("âŒ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/blacklist", { user = tp.Name })
        if resp and resp.status == "blacklisted" then musicChat(string.format("ðŸš« %s blacklisted", tp.DisplayName))
        else musicChat("âŒ Failed to blacklist user") end
    end)
end

MusicCommands.unblacklist = function(player, args)
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if not isMain then musicChat("â›” Only main account can use this!"); return end
    local tp = FindTarget(args[2], player)
    if not tp then musicChat("âŒ Player not found in game"); return end
    task.spawn(function()
        local resp = musicRequest("/admin/unblacklist", { user = tp.Name })
        if resp and resp.status == "unblacklisted" then musicChat(string.format("âœ… %s removed from blacklist", tp.DisplayName))
        else musicChat("âŒ Failed to unblacklist user") end
    end)
end

MusicCommands.musiccmds = function(player, args)
    musicChat("ðŸŽµ Music Bot Commands:")
    task.wait(0.5); musicChat("./play <song> - Play a song")
    task.wait(0.5); musicChat("./np - What's playing now")
    task.wait(0.5); musicChat("./status - Full status & queue")
    task.wait(0.5); musicChat("./queue - View queue")
    task.wait(0.5); musicChat("./stats [user] - View statistics")
    task.wait(0.5); musicChat("./history - Recent songs")
    task.wait(0.5); musicChat("ðŸŽ›ï¸ Need controls? Ask for /auth")
    local isMain = player.Name:lower() == getgenv().Settings.mainAccount:lower()
    if isMain then task.wait(0.5); musicChat("ðŸ‘‘ Admin: /auth /unauth /blacklist") end
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
            local st = "âŒ Not authorized"
            if resp.is_main_account then st = "ðŸ‘‘ Main Account (always authorized)"
            elseif resp.is_authorized then st = "âœ… Authorized" end
            musicChat(string.format("ðŸ” %s: %s", label, st))
            if resp.is_blacklisted then musicChat("ðŸš« (Blacklisted)") end
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  AI TOOLS (Tool Gen & Zoom, Gui-less, Multi-Bot Scaled)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
        if _G.GenToolGenerating then notify("Wait", "Already generatingâ€¦", 3); return end
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  DAYBREAK CLEANUP ENGINE (merged)
--  Strips visual bloat on alt clients for max performance
--  Keeps: HumanoidRootPart, Humanoid, Head, floors, chat, audio
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  AUTO-SYNC ENGINE
--  Measures ping & adjusts bot timing for music/movement sync
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  OPTIMIZATION & OVERLAY (main entry)
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
local function OptimizeAndOverlay()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() if setfpscap then setfpscap(10) end end)

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
        "Join Discord: https://discord.gg/ws5Zb2EzYA\n\n" ..
        "USER: %s\n" ..
        "BOT POSITION: %02d",
        LocalPlayer.Name,
        myIndex
    )
    InfoLabel.Parent = Background
end

if LocalPlayer.Name ~= getgenv().Settings.mainAccount then
    OptimizeAndOverlay()
    
    if getgenv().Settings.announceOnLoad and isAltAccount and not isMainAccount then
        task.spawn(function()
            local idx = SafeIndex() or 1
            local total = SafeTotal() or 1
            task.wait(2.0 + ((idx - 1) * 0.25))
            ChatSend(string.format("â˜€ï¸ DayBreak Bot #%d/%d Ready", idx, total))
        end)
    end
end


-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  18. INITIALIZE
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
        musicChat("ðŸŽµ Ë¹Music Bot ReadyË¼ ðŸŽµ")
        task.wait(1)
        musicChat("Type /cmds for commands")
    end)
end

print("DayBreak ALT Control | By @DayBreak")
