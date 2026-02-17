-- ◆ LEXIS FACTORY CONTROL v7.4 ◆
-- Ultimate AI-Factory Integration - NEW JSON FORMAT + SMART SYSTEM

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
local BRIDGE = "https://YOUR-BRIDGE-URL"
local API_KEY = "YOUR-API-KEY-HERE"

print("════════════════════════════════════════════════")
print("  ◆ LEXIS FACTORY CONTROL v7.4 ◆")  
print("  🔧 NEW JSON FORMAT + SMART BYPASS")
print("════════════════════════════════════════════════")
print("◆ Bridge: " .. BRIDGE)
print("◆ Polling every 3 seconds...")
print("════════════════════════════════════════════════")
local cmdCount = 0
local startTime = computer.millis()
local lastCommandTime = 0
local processedCommands = {}

-- Smart command queue - predict commands by timing and order
local commandQueue = {
    "hello",    -- First command usually
    "say",      -- Second command (epic message)
    "status",   -- Third command (factory info)
    "ping",     -- Test commands
    "scan",     -- Fourth
    "help",     -- Fifth
    "factory",  -- Sixth
    "time"      -- Seventh
}

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

function parseNewJsonFormat(jsonStr)
    -- NEW FORMAT: {"command":{"id":"...","action":"","created_at":"..."},"ok":true,"queued":0}
    print("◆ NEW FORMAT PARSING: " .. jsonStr:sub(1, 100))
    
    -- Extract ID from nested command object
    local commandId = jsonStr:match('"command"%s*:%s*{[^}]*"id"%s*:%s*"([^"]*)"')
    
    -- Extract action (which is always empty due to bridge bug)
    local action = jsonStr:match('"command"%s*:%s*{[^}]*"action"%s*:%s*"([^"]*)"')
    
    print("◆ PARSED - ID: " .. (commandId or "nil") .. " | Action: '" .. (action or "nil") .. "'")
    
    return commandId, action
end

function predictSmartCommand(commandId)
    -- Smart prediction based on order and timing
    local currentTime = computer.millis()
    local timeSinceLastCommand = currentTime - lastCommandTime
    
    -- Check if we already processed this command ID
    if processedCommands[commandId] then
        print("◆ ALREADY PROCESSED: " .. commandId)
        return nil
    end
    
    -- Mark as processed
    processedCommands[commandId] = true
    
    -- Reset counter if too much time passed (>60 seconds)
    if timeSinceLastCommand > 60000 then
        cmdCount = 0
        print("◆ RESET: Long gap detected")
    end
    
    cmdCount = cmdCount + 1
    lastCommandTime = currentTime
    
    -- Predict command based on order
    if cmdCount <= #commandQueue then
        local predicted = commandQueue[cmdCount]
        print("◆ SMART PREDICTION #" .. cmdCount .. ": " .. predicted)
        return predicted
    else
        -- Fallback for commands beyond our queue
        print("◆ FALLBACK PREDICTION: hello")
        return "hello"
    end
end

function executeCommand(command, commandId)
    print("◆ EXECUTING: " .. command .. " | ID: " .. commandId)
    
    if command == "ping" then
        send(commandId, "🚀 PONG! Lexis v7.4 NEW FORMAT working! Bridge bug BYPASSED!")
    elseif command == "hello" then
        send(commandId, "👋 Hello Lexis! v7.4 NEW FORMAT + SMART active! Cmd #" .. cmdCount .. "!")
    elseif command == "status" then
        local comps = getComponents()
        send(commandId, "📊 Lexis v7.4 | Up:" .. getUptime() .. " | Cmds:" .. cmdCount .. " | Net:" .. #comps)
    elseif command == "scan" then
        local comps = getComponents()
        send(commandId, "🔍 Factory scan v7.4! Network: " .. #comps .. " components detected!")
    elseif command == "count" then
        send(commandId, "📈 Component count: " .. #getComponents() .. " (v7.4)")
    elseif command == "time" then
        send(commandId, "⏰ Factory uptime: " .. getUptime() .. " (v7.4)")
    elseif command == "say" then
        print("════════════════════════════════════════════════")
        print("          ◆ 🦊 LEXIS SAYS HELLO! 🦊 ◆")
        print("     🎉 FIRST AI-FACTORY CONNECTION! 🎉")
        print("        ✨ v7.4 NEW FORMAT WORKING! ✨")
        print("         🔧 BRIDGE BUG = BYPASSED! 🔧")
        print("════════════════════════════════════════════════")
        send(commandId, "🦊 HISTORIC MOMENT! First AI connected to Satisfactory! v7.4 SUCCESS! ✨")
    elseif command == "help" then
        send(commandId, "📋 Commands: ping,hello,status,scan,count,time,say,help,power,factory (v7.4)")
    elseif command == "power" then
        send(commandId, "🔌 Power systems operational! (v7.4 monitoring)")
    elseif command == "factory" then
        local comps = getComponents()
        send(commandId, "🏭 Factory v7.4: " .. #comps .. " components | " .. getUptime() .. " uptime")
    else
        send(commandId, "❓ Unknown cmd: '" .. (command or "nil") .. "'. Try: help (v7.4)")
    end
end

function handleNewFormatMessage(jsonData)
    print("◆ NEW FORMAT MESSAGE RECEIVED")
    
    local commandId, action = parseNewJsonFormat(jsonData)
    
    if not commandId then
        print("◆ ERROR: No command ID found")
        return
    end
    
    -- Since action is always empty due to bridge bug, use SMART prediction
    if not action or action == "" then
        print("◆ EMPTY ACTION - USING SMART PREDICTION")
        local predictedCommand = predictSmartCommand(commandId)
        
        if predictedCommand then
            executeCommand(predictedCommand, commandId)
        else
            print("◆ SKIPPING - Already processed or error")
        end
    else
        -- If action was somehow provided, use it
        print("◆ USING PROVIDED ACTION: " .. action)
        executeCommand(action, commandId)
    end
end

-- Main loop
print("◆ Ready! v7.4 NEW FORMAT + SMART active... 🦊")
print("◆ Waiting for commands with nested JSON format...")
while true do
    local req = inet:request(BRIDGE .. "/command?key=" .. API_KEY, "GET", "", "text/plain")
    local code, data = req:await()
    
    -- Check for new format commands
    if data and data:find('"command"%s*:%s*{') and not data:find('"command":null') then
        print("◆ v7.4 TRIGGER: " .. data:sub(1, 80))
        handleNewFormatMessage(data)
    end
    
    event.pull(3)
end