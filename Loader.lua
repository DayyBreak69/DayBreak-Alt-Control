--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║              ☀️ DAYBREAK ALT CONTROL - LOADER ☀️            ║
  ║               Created by: DayBreak                          ║
  ║                                                              ║
  ║  Instructions:                                               ║
  ║  1. Set 'mainAccount' to your main Roblox username.          ║
  ║  2. Add your alt account usernames to 'altAccounts'.         ║
  ║  3. Execute this script on ALL accounts (Main and Alts).     ║
  ╚══════════════════════════════════════════════════════════════╝
--]]

-- 1. CONFIGURATION --
getgenv().Settings = {
    prefix      = "!",                 -- Command prefix (can be anything, e.g. "!", ".", ";")
    mainAccount = "YourMainUsername",  -- Put your Main Account Username here
    fpsCap      = 10,                  -- FPS limit for alts to save PC performance
    altAccounts = {
        ["DayBreak_Alt01"] = true,
        ["DayBreak_Alt02"] = true,
        ["DayBreak_Alt03"] = true,
        ["DayBreak_Alt04"] = true,
        ["DayBreak_Alt05"] = true,
        -- You can add any amount of Alt Account Usernames here
    }
}

-- 2. LOAD DAYBREAK CORE ENGINE --
loadstring(game:HttpGet("https://raw.githubusercontent.com/DayyBreak69/DayBreak-Alt-Control/main/DayBreakAltControl.lua"))()
