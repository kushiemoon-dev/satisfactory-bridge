-- ◆ LEXIS FACTORY CONTROL v7.1 ◆
-- Ultimate AI-Factory Integration - CORRECT API PARSING

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
local BRIDGE = "https://YOUR-BRIDGE-URL"
local API_KEY = "YOUR-API-KEY-HERE"

print("════════════════════════════════════════════════")
print("  ◆ LEXIS FACTORY CONTROL v7.1 ◆")
print("  🔧 CORRECT API PARSING")
print("════════════════════════════════════════════════")
print("◆ Bridge: " .. BRIDGE)
print("◆ Polling every 3 seconds...")
print("════════════════════════════════════════════════")
local cmdCount = 0
local startTime = computer.millis()

function urlEncode(str)
    if str then
        str = str:gsub("\n", " ")
        str = str:gsub("([^%w%-_.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    end
    return str
end

function send(cmdId, msg)
    local url = BRIDGE .. "/response?key=" .. API_KEY 
        .. "&command_id=" .. urlEncode(tostring(cmdId))
        .. "&data=" .. urlEncode(msg)
    inet:request(url, "GET", "", "text/plain")
    print("◆ Sent: " .. msg:sub(1, 50))
end

function getComponents()
    return component.findComponent("")
end

function getUptime()
    local ms = computer.millis() - startTime
    local secs = math.floor(ms / 1000)
    local mins = math.floor(secs / 60)
    local hours = math.floor(mins / 60)
    return string.format("%dh %dm %ds", hours, mins % 60, secs % 60)
end

function parseApiResponse(jsonStr)
    -- Parse the actual API format based on logs:
    -- {"command":"id":"20260215174929.972","action":"hello","created_at":"..."}
    
    -- Try multiple parsing strategies
    local commandId = jsonStr:match('"command":"id":"([^"]*)"') or jsonStr:match('"command_id"%s*:%s*"([^"]*)"')
    local action = jsonStr:match('"action"%s*:%s*"([^"]*)"') or jsonStr:match('"command"%s*:%s*"([^"]*)"')
    
    print("◆ Parsed - ID: " .. (commandId or "nil") .. " | Action: " .. (action or "nil"))
    
    return commandId, action
end

function handleCommand(jsonData)
    print("◆ Raw JSON: " .. jsonData:sub(1, 120))
    
    local commandId, command = parseApiResponse(jsonData)
    
    if not command or command == "" then
        print("◆ No valid command found")
        return
    end
    
    print("◆ Command: " .. command .. " | ID: " .. (commandId or "unknown"))
    
    if command == "ping" then
        send(commandId, "PONG! Lexis v7.1 alive! 🚀")
    elseif command == "hello" then
        cmdCount = cmdCount + 1
        send(commandId, "Hello Lexis! Command #" .. cmdCount .. " 👋")
    elseif command == "status" then
        local comps = getComponents()
        send(commandId, "Lexis v7.1 | Uptime:" .. getUptime() .. " | Commands:" .. cmdCount .. " | Components:" .. #comps .. " 📊")
    elseif command == "scan" then
        local comps = getComponents()
        send(commandId, "Factory scan complete! Found " .. #comps .. " network components 🔍")
    elseif command == "count" then
        send(commandId, "Total components: " .. #getComponents() .. " 📈")
    elseif command == "time" then
        send(commandId, "Factory uptime: " .. getUptime() .. " ⏰")
    elseif command == "say" then
        print("════════════════════════════════════════════════")
        print("          ◆ 🦊 LEXIS SAYS HELLO! 🦊 ◆")
        print("     AI connected to your factory successfully!")
        print("════════════════════════════════════════════════")
        send(commandId, "🦊 Message displayed in factory console! Lexis is connected! ✨")
    elseif command == "help" then
        send(commandId, "Available commands: ping, hello, status, scan, count, time, say, help 📋")
    elseif command == "power" then
        send(commandId, "Power systems operational 🔌 (detailed monitoring coming soon)")
    elseif command == "factory" then
        local comps = getComponents()
        send(commandId, "🏭 Factory Status: " .. #comps .. " components networked | Uptime: " .. getUptime())
    elseif command == "debug" then
        send(commandId, "🔧 DEBUG v7.1 | JSON parsing successful! | Raw: " .. jsonData:sub(1, 60))
    else
        send(commandId, "❓ Unknown command: '" .. command .. "'. Try: help")
    end
end

-- Main loop
print("◆ Ready! Waiting for Lexis commands... 🦊")
while true do
    local req = inet:request(BRIDGE .. "/command?key=" .. API_KEY, "GET", "", "text/plain")
    local code, data = req:await()
    
    -- Debug info
    if data and data ~= '{"command":null,"ok":true,"queued":0}' then
        print("◆ Received data: " .. data:sub(1, 100))
    end
    
    -- Check if we have a real command (not null)  
    if data and data:find('"command"') and not data:find('"command":null') then
        handleCommand(data)
    end
    
    event.pull(3)
end