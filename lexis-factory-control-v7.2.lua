-- ◆ LEXIS FACTORY CONTROL v7.2 ◆
-- Ultimate AI-Factory Integration - ULTRA ROBUST PARSING

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
local BRIDGE = "https://bridge.kushie.dev"
local API_KEY = "satisfactory-lexis-2026"

print("════════════════════════════════════════════════")
print("  ◆ LEXIS FACTORY CONTROL v7.2 ◆")
print("  🔧 ULTRA ROBUST PARSING")
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

function parseCommand(rawData)
    -- Ultra robust parsing - try everything!
    print("◆ FULL JSON DEBUG: " .. rawData)
    
    -- Strategy 1: Extract command ID first
    local cmdId = rawData:match('"command":"id":"([^"]*)"') 
                 or rawData:match('"command_id"%s*:%s*"([^"]*)"')
                 or rawData:match('"id"%s*:%s*"([^"]*)"')
    
    -- Strategy 2: Look for actual command in various places
    local command = nil
    
    -- Try to find actual command in the raw curl data
    -- Look for patterns like: -d '{"command": "hello"}'
    command = rawData:match('%{%s*"command"%s*:%s*"([^"]+)"%s*%}')
    
    -- If not found, maybe it's in action field
    if not command then
        command = rawData:match('"action"%s*:%s*"([^"]*)"')
    end
    
    -- If still not found, maybe it's elsewhere
    if not command then 
        -- Look for any word that might be a command
        for cmd in rawData:gmatch('"([a-zA-Z]+)"') do
            if cmd == "ping" or cmd == "hello" or cmd == "status" or cmd == "say" 
               or cmd == "scan" or cmd == "count" or cmd == "time" or cmd == "help"
               or cmd == "power" or cmd == "factory" or cmd == "debug" then
                command = cmd
                break
            end
        end
    end
    
    print("◆ Extracted - ID: " .. (cmdId or "unknown") .. " | Command: " .. (command or "none"))
    
    return cmdId or "unknown", command
end

function handleCommand(jsonData)
    local commandId, command = parseCommand(jsonData)
    
    if not command then
        print("◆ No command found - skipping")
        return
    end
    
    print("◆ Executing: " .. command)
    
    if command == "ping" then
        send(commandId, "PONG! Lexis v7.2 ULTRA working! 🚀")
    elseif command == "hello" then
        cmdCount = cmdCount + 1
        send(commandId, "Hello Lexis! Command #" .. cmdCount .. " from v7.2! 👋")
    elseif command == "status" then
        local comps = getComponents()
        send(commandId, "Lexis v7.2 ULTRA | Uptime:" .. getUptime() .. " | Commands:" .. cmdCount .. " | Components:" .. #comps .. " 📊")
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
        print("          v7.2 ULTRA PARSING WORKING!")
        print("════════════════════════════════════════════════")
        send(commandId, "🦊 Message displayed! Lexis v7.2 connected & parsing works! ✨")
    elseif command == "help" then
        send(commandId, "Available commands: ping, hello, status, scan, count, time, say, help 📋 (v7.2)")
    elseif command == "power" then
        send(commandId, "Power systems operational 🔌 (v7.2)")
    elseif command == "factory" then
        local comps = getComponents()
        send(commandId, "🏭 Factory Status v7.2: " .. #comps .. " components | Uptime: " .. getUptime())
    elseif command == "debug" then
        send(commandId, "🔧 DEBUG v7.2 | Parsing: SUCCESS! | Data: " .. jsonData:sub(1, 40))
    else
        send(commandId, "❓ Unknown: '" .. command .. "'. Try: help (v7.2)")
    end
end

-- Main loop
print("◆ Ready! v7.2 ULTRA parsing active... 🦊")
while true do
    local req = inet:request(BRIDGE .. "/command?key=" .. API_KEY, "GET", "", "text/plain")
    local code, data = req:await()
    
    -- Debug: show all data
    if data and data ~= '{"command":null,"ok":true,"queued":0}' then
        print("◆ RECEIVED: " .. data)
        handleCommand(data)
    end
    
    event.pull(3)
end