--[[
  +==============================================================+
  |              * DAYBREAK ALT CONTROL - LOADER *               |
  |               Created by: DayBreak                           |
  |                                                              |
  |  Instructions:                                               |
  |  1. Set 'mainAccount' to your main Roblox username.          |
  |  2. Add your alt account usernames to 'altAccounts'.         |
  |  3. Execute this script on ALL accounts (Main and Alts).      |
  +==============================================================+
--]]

-- 1. CONFIGURATION --
getgenv().Settings = {
    prefix      = "!",                 -- Command prefix (e.g. "!", ".", ";")
    mainAccount = "DayyBreak66",       -- Your Main Account Username
    fpsCap      = 10,                  -- FPS limit for alts to save PC performance
    altAccounts = {
        ["DayBreak_Alt01"] = true,
        ["DayBreak_Alt02"] = true,
        ["DayBreak_Alt03"] = true,
        ["DayBreak_Alt04"] = true,
        ["DayBreak_Alt05"] = true,
        -- Add any amount of Alt Account usernames here
    },
    whitelistedUsers = {
        ["daybreak"] = true,
        ["dayybreak66"] = true,
        ["Haylees_Ekitty"] = true,
        ["xOmqhayleealt"] = true,
    }
}

-- 2. LOAD DAYBREAK CORE ENGINE --
local scriptUrl = "https://raw.githubusercontent.com/DayyBreak69/DayBreak-Alt-Control/main/DayBreakAltControl.lua"
local success, content = pcall(function()
    return game:HttpGet(scriptUrl)
end)

if success and content and #content > 100 then
    local engineFunc, parseErr = loadstring(content)
    if engineFunc then
        engineFunc()
    else
        warn("[DayBreak Loader] Syntax parse error:", parseErr)
    end
else
    warn("[DayBreak Loader] Failed to fetch script from GitHub:", tostring(content))
end
