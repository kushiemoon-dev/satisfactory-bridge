-- Satisfactory Bridge Client for FicsIt-Networks
-- Polls the bridge server and executes commands on factory machines
-- 
-- Setup:
-- 1. Place a Computer in your factory
-- 2. Connect an Internet Card to the computer
-- 3. Connect machines you want to control via network cables
-- 4. Paste this code into the computer's drive

-- ============ CONFIGURATION ============
local BRIDGE_URL = "http://YOUR_BRIDGE_IP:8080"
local API_KEY = "YOUR-API-KEY-HERE"  -- Replace with your actual API key
local POLL_INTERVAL = 2  -- seconds between polls

-- ============ UTILITIES ============

-- Get the Internet Card component
local internet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not internet then
    error("No Internet Card found! Please connect one to this computer.")
end

print("Satisfactory Bridge Client starting...")
print("   Bridge: " .. BRIDGE_URL)
print("   Poll interval: " .. POLL_INTERVAL .. "s")

-- Simple JSON parser (FicsIt has no built-in JSON)
local function parseJSON(str)
    -- Very basic JSON parsing for our simple command format
    local result = {}
    
    -- Extract action
    local action = str:match('"action"%s*:%s*"([^"]*)"')
    if action then result.action = action end
    
    -- Extract target
    local target = str:match('"target"%s*:%s*"([^"]*)"')
    if target then result.target = target end
    
    -- Extract id
    local id = str:match('"id"%s*:%s*"([^"]*)"')
    if id then result.id = id end
    
    -- Extract enabled (boolean)
    local enabled = str:match('"enabled"%s*:%s*(%w+)')
    if enabled then result.enabled = (enabled == "true") end
    
    -- Extract recipe
    local recipe = str:match('"recipe"%s*:%s*"([^"]*)"')
    if recipe then result.recipe = recipe end
    
    return result
end

-- Build JSON string
local function toJSON(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        local val
        if type(v) == "string" then
            val = '"' .. v .. '"'
        elseif type(v) == "boolean" then
            val = v and "true" or "false"
        elseif type(v) == "number" then
            val = tostring(v)
        elseif type(v) == "table" then
            val = toJSON(v)
        else
            val = "null"
        end
        table.insert(parts, '"' .. k .. '":' .. val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- HTTP GET request
local function httpGet(url, headers)
    local req = internet:request(url, "GET", "", headers)
    local code, data = req:await()
    return code, data
end

-- HTTP POST request  
local function httpPost(url, body, headers)
    headers["Content-Type"] = "application/json"
    local req = internet:request(url, "POST", body, headers)
    local code, data = req:await()
    return code, data
end

-- ============ MACHINE DISCOVERY ============

-- Find all controllable machines on the network
local function discoverMachines()
    local machines = {}
    
    -- Get all network components
    local components = component.findComponent("")
    
    for _, comp in ipairs(components) do
        local proxy = component.proxy(comp)
        if proxy then
            local nick = proxy.nick or ""
            local className = proxy:getType().name or "Unknown"
            
            -- Categorize machines
            if className:find("Constructor") or 
               className:find("Assembler") or
               className:find("Manufacturer") or
               className:find("Smelter") or
               className:find("Foundry") or
               className:find("Refinery") or
               className:find("Packager") or
               className:find("Blender") then
                machines[nick ~= "" and nick or comp] = {
                    proxy = proxy,
                    type = className,
                    id = comp
                }
            end
        end
    end
    
    return machines
end

-- ============ COMMAND HANDLERS ============

local handlers = {}

-- Get factory status
handlers["get_status"] = function(cmd, machines)
    local status = {
        machine_count = 0,
        machines = {}
    }
    
    for name, machine in pairs(machines) do
        status.machine_count = status.machine_count + 1
        local info = {
            name = name,
            type = machine.type,
            standby = machine.proxy.standby or false
        }
        
        -- Try to get production info
        pcall(function()
            info.productivity = machine.proxy.productivity
            info.progress = machine.proxy.progress
        end)
        
        table.insert(status.machines, info)
    end
    
    return "success", status
end

-- Toggle machine on/off
handlers["toggle"] = function(cmd, machines)
    local target = cmd.target
    local machine = machines[target]
    
    if not machine then
        return "error", {message = "Machine not found: " .. (target or "nil")}
    end
    
    machine.proxy.standby = not machine.proxy.standby
    
    return "success", {
        machine = target,
        standby = machine.proxy.standby
    }
end

-- Set machine standby state
handlers["set_standby"] = function(cmd, machines)
    local target = cmd.target
    local machine = machines[target]
    
    if not machine then
        return "error", {message = "Machine not found: " .. (target or "nil")}
    end
    
    machine.proxy.standby = cmd.enabled or false
    
    return "success", {
        machine = target,
        standby = machine.proxy.standby
    }
end

-- Stop all machines
handlers["stop_all"] = function(cmd, machines)
    local stopped = 0
    for name, machine in pairs(machines) do
        machine.proxy.standby = true
        stopped = stopped + 1
    end
    
    return "success", {stopped = stopped}
end

-- Start all machines
handlers["start_all"] = function(cmd, machines)
    local started = 0
    for name, machine in pairs(machines) do
        machine.proxy.standby = false
        started = started + 1
    end
    
    return "success", {started = started}
end

-- Ping (test connectivity)
handlers["ping"] = function(cmd, machines)
    return "success", {
        message = "pong",
        time = computer.time(),
        machines = 0
    }
end

-- List machines
handlers["list_machines"] = function(cmd, machines)
    local list = {}
    for name, machine in pairs(machines) do
        table.insert(list, {
            name = name,
            type = machine.type
        })
    end
    return "success", {machines = list, count = #list}
end

-- ============ MAIN LOOP ============

local function pollAndExecute(machines)
    local headers = {["X-API-Key"] = API_KEY}
    
    -- Poll for command
    local code, data = httpGet(BRIDGE_URL .. "/command", headers)
    
    if code ~= 200 then
        print("[WARN] Poll failed: " .. (code or "timeout"))
        return
    end
    
    -- Parse response
    local response = parseJSON(data)
    
    -- Check if there's a command
    if not response.action and data:find('"command":null') then
        -- No command waiting
        return
    end
    
    -- Extract command from nested structure if needed
    local cmd = response
    if data:find('"command":{') then
        cmd = parseJSON(data:match('"command":({[^}]+})'))
    end
    
    if not cmd.action then
        return
    end
    
    print("[CMD] " .. cmd.action .. " -> " .. (cmd.target or "*"))
    
    -- Execute command
    local handler = handlers[cmd.action]
    local status, result
    
    if handler then
        status, result = handler(cmd, machines)
    else
        status = "error"
        result = {message = "Unknown action: " .. cmd.action}
    end
    
    -- Send response back
    local responseBody = toJSON({
        command_id = cmd.id or "unknown",
        status = status,
        data = result
    })
    
    httpPost(BRIDGE_URL .. "/response", responseBody, headers)
    print("[RESP] " .. status)
end

-- Main entry point
local function main()
    print("Discovering machines...")
    local machines = discoverMachines()
    
    local count = 0
    for _ in pairs(machines) do count = count + 1 end
    print("Found " .. count .. " controllable machines")
    
    -- List them
    for name, machine in pairs(machines) do
        print("  - " .. name .. " (" .. machine.type .. ")")
    end
    
    print("\nStarting poll loop...")
    
    while true do
        local ok, err = pcall(pollAndExecute, machines)
        if not ok then
            print("[ERROR] " .. tostring(err))
        end
        
        -- Refresh machine list periodically
        if computer.time() % 60 < POLL_INTERVAL then
            machines = discoverMachines()
        end
        
        -- Wait before next poll
        event.pull(POLL_INTERVAL)
    end
end

-- Run!
main()
