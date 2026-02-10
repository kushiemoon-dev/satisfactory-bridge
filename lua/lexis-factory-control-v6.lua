-- ◆ LEXIS FACTORY CONTROL v6.0 ◆
-- Ultimate AI-Factory Integration
-- Full bidirectional communication with GET workaround

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION (replace with your values)
-- ═══════════════════════════════════════════════════════════════
local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
local BRIDGE = "https://YOUR-BRIDGE-URL.example.com"  -- Your bridge URL
local API_KEY = "YOUR-API-KEY-HERE"                    -- Replace with your actual API key

-- ═══════════════════════════════════════════════════════════════
-- STARTUP
-- ═══════════════════════════════════════════════════════════════
print("════════════════════════════════════════════════")
print("  ◆ LEXIS FACTORY CONTROL v6.0 ◆")
print("  Ultimate AI-Factory Integration")
print("════════════════════════════════════════════════")
print("◆ Bridge: " .. BRIDGE)
print("◆ Polling every 3 seconds...")
print("════════════════════════════════════════════════")

local cmdCount = 0
local startTime = computer.millis()

-- ═══════════════════════════════════════════════════════════════
-- URL ENCODING (for special characters in responses)
-- ═══════════════════════════════════════════════════════════════
function urlEncode(str)
    if str then
        str = str:gsub("\n", " ")
        str = str:gsub("([^%w%-_.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    end
    return str
end

-- ═══════════════════════════════════════════════════════════════
-- SEND RESPONSE (via GET - workaround for FicsIt POST crash)
-- ═══════════════════════════════════════════════════════════════
function send(cmdId, msg)
    local url = BRIDGE .. "/response?key=" .. API_KEY 
        .. "&command_id=" .. urlEncode(cmdId)
        .. "&data=" .. urlEncode(msg)
    inet:request(url, "GET", "", "text/plain")
    print("◆ Sent: " .. msg:sub(1, 50))
end

-- ═══════════════════════════════════════════════════════════════
-- FACTORY DATA FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Get all network components
function getComponents()
    return component.findComponent("")
end

-- Get components by type
function getComponentsByType(typeName)
    return component.findComponent(findClass(typeName))
end

-- Count components by type
function countByType(typeName)
    local comps = component.findComponent(typeName)
    return #comps
end

-- Get power grid info
function getPowerInfo()
    local circuits = component.findComponent(findClass("PowerCircuit"))
    if #circuits == 0 then
        return "No power circuits found"
    end
    
    local info = ""
    for i, circuit in ipairs(circuits) do
        local proxy = component.proxy(circuit)
        if proxy then
            local prod = proxy.production or 0
            local cons = proxy.consumption or 0
            local cap = proxy.capacity or 0
            info = info .. string.format("Circuit %d: %.1f/%.1f MW (cap: %.1f) | ", 
                i, cons, prod, cap)
        end
        if i >= 3 then break end  -- Limit to 3 circuits
    end
    return info ~= "" and info or "Power data unavailable"
end

-- Get machine counts
function getMachineCounts()
    local counts = {}
    
    -- Common machine types
    local types = {
        "Build_ConstructorMk1_C",
        "Build_AssemblerMk1_C",
        "Build_ManufacturerMk1_C",
        "Build_SmelterMk1_C",
        "Build_FoundryMk1_C",
        "Build_OilRefinery_C",
        "Build_Packager_C",
        "Build_Blender_C",
        "Build_HadronCollider_C",
        "Build_GeneratorCoal_C",
        "Build_GeneratorFuel_C",
        "Build_GeneratorNuclear_C"
    }
    
    local total = 0
    local result = ""
    
    for _, typeName in ipairs(types) do
        local count = #component.findComponent(typeName)
        if count > 0 then
            local shortName = typeName:match("Build_(.-)_C") or typeName
            result = result .. shortName .. ":" .. count .. " "
            total = total + count
        end
    end
    
    return "Total machines: " .. total .. " | " .. result
end

-- Get train info
function getTrainInfo()
    local stations = component.findComponent("Build_TrainStation_C")
    local locos = component.findComponent("Build_Locomotive_C")
    local wagons = component.findComponent("Build_FreightWagon_C")
    
    return string.format("Trains: %d stations, %d locos, %d wagons", 
        #stations, #locos, #wagons)
end

-- Get storage info (count containers)
function getStorageInfo()
    local small = #component.findComponent("Build_StorageContainerMk1_C")
    local medium = #component.findComponent("Build_StorageContainerMk2_C")
    local large = #component.findComponent("Build_StorageIntegrated_C")
    local fluid = #component.findComponent("Build_IndustrialTank_C") + 
                  #component.findComponent("Build_PipeStorageTank_C")
    
    return string.format("Storage: %d small, %d medium, %d large, %d fluid tanks", 
        small, medium, large, fluid)
end

-- Get uptime
function getUptime()
    local ms = computer.millis() - startTime
    local secs = math.floor(ms / 1000)
    local mins = math.floor(secs / 60)
    local hours = math.floor(mins / 60)
    return string.format("%dh %dm %ds", hours, mins % 60, secs % 60)
end

-- ═══════════════════════════════════════════════════════════════
-- COMMAND HANDLER
-- ═══════════════════════════════════════════════════════════════
function handleCommand(data)
    print("◆ Received: " .. data:sub(1, 80))
    
    -- PING - Basic connectivity test
    if data:find('"ping"') then
        send("ping", "PONG! AI is alive in your factory!")
    
    -- HELLO - Personal greeting with counter
    elseif data:find('"hello"') then
        cmdCount = cmdCount + 1
        send("hello", "Hey! Command number " .. cmdCount .. " processed!")
    
    -- STATUS - Full factory status
    elseif data:find('"status"') then
        local status = "FACTORY STATUS | " ..
            "Uptime: " .. getUptime() .. " | " ..
            "Commands: " .. cmdCount
        send("status", status)
    
    -- POWER - Power grid information
    elseif data:find('"power"') then
        send("power", getPowerInfo())
    
    -- MACHINES - Machine counts
    elseif data:find('"machines"') then
        send("machines", getMachineCounts())
    
    -- TRAINS - Train network info
    elseif data:find('"trains"') then
        send("trains", getTrainInfo())
    
    -- STORAGE - Storage container counts
    elseif data:find('"storage"') then
        send("storage", getStorageInfo())
    
    -- SCAN - Full network scan
    elseif data:find('"scan"') then
        local comps = getComponents()
        send("scan", "Network scan: " .. #comps .. " components found")
    
    -- COUNT - Quick component count
    elseif data:find('"count"') then
        local comps = getComponents()
        send("count", "Total components: " .. #comps)
    
    -- TIME - Script uptime
    elseif data:find('"time"') or data:find('"uptime"') then
        send("time", "Script running for: " .. getUptime())
    
    -- SAY - Display message in console
    elseif data:find('"say"') then
        -- Extract message if provided
        local msg = data:match('"message":"([^"]*)"') or "Hello from AI!"
        print("═══════════════════════════════════════")
        print("  ◆ LEXIS SAYS: " .. msg)
        print("═══════════════════════════════════════")
        send("say", "Message displayed in factory console!")
    
    -- HELP - List available commands
    elseif data:find('"help"') then
        send("help", "Commands: ping hello status power machines trains storage scan count time say help")
    
    -- UNKNOWN - Fallback
    else
        send("unknown", "Unknown command. Try: help")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════
print("◆ Starting main loop...")
print("◆ Ready to receive commands!")
print("")

while true do
    -- Poll for commands
    local req = inet:request(BRIDGE .. "/command?key=" .. API_KEY, "GET", "", "text/plain")
    local code, data = req:await()
    
    -- Process if we got a command
    if data and data:find('"command"') and not data:find('"command":null') then
        handleCommand(data)
    end
    
    -- Wait before next poll
    event.pull(3)
end
