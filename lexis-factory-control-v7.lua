-- ◆ LEXIS FACTORY CONTROL v7.0 ◆
-- Ultimate AI-Factory Integration - FIXED API COMPATIBILITY

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
local BRIDGE = "https://bridge.kushie.dev"
local API_KEY = "satisfactory-lexis-2026"

print("════════════════════════════════════════════════")
print("  ◆ LEXIS FACTORY CONTROL v7.0 ◆")
print("  🔧 FIXED API COMPATIBILITY")
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
    -- Fixed API endpoint for responses
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

function extractCommand(jsonStr)
    -- Parse JSON to extract command value
    local cmd = jsonStr:match('"command"%s*:%s*"([^"]*)"')
    return cmd
end

function extractCommandId(jsonStr) 
    -- Parse JSON to extract command_id
    local cmdId = jsonStr:match('"command_id"%s*:%s*"([^"]*)"')
    return cmdId or "unknown"
end

function handleCommand(jsonData)
    print("◆ Raw JSON: " .. jsonData:sub(1, 80))
    
    local command = extractCommand(jsonData)
    local commandId = extractCommandId(jsonData)
    
    if not command then
        send(commandId, "Error: No command found in JSON")
        return
    end
    
    print("◆ Command: " .. command .. " | ID: " .. commandId)
    
    if command == "ping" then
        send(commandId, "PONG! Lexis v7.0 alive! 🚀")
    elseif command == "hello" then
        cmdCount = cmdCount + 1
        send(commandId, "Hello Lexis! Command #" .. cmdCount .. " 👋")
    elseif command == "status" then
        local comps = getComponents()
        send(commandId, "Lexis v7.0 | Uptime:" .. getUptime() .. " | Commands:" .. cmdCount .. " | Components:" .. #comps .. " 📊")
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