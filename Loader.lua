getgenv().Settings = {
    prefix      = "!",
    mainAccount = "DayyBreak66",
    fpsCap      = 10,
    altAccounts = {
        ["DayBreak_Alt01"] = true,
        ["DayBreak_Alt02"] = true,
        ["DayBreak_Alt03"] = true,
    }
}

local url = "https://raw.githubusercontent.com/DayyBreak69/DayBreak-Alt-Control/main/DayBreakAltControl.lua?t=" .. tostring(os.time())
loadstring(game:HttpGet(url))()
