-- ============================================
-- SATISFACTORY BRIDGE v2.0
-- Real factory monitoring & control
-- ============================================

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not inet then
    print("!! NO INTERNET CARD FOUND !!")
    return
end

local BRIDGE = "https://bridge.kushie.dev"
local KEY = "satisfactory-lexis-2026"
local VERSION = "2.0"

-- ============================================
-- UTILITIES
-- ============================================

local function urlencode(s)
    s = tostring(s or "")
    s = s:gsub("\n", " ")
    s = s:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s
end

local function respond(cmdId, message)
    local url = BRIDGE .. "/response?key=" .. KEY
        .. "&command_id=" .. urlencode(cmdId)
        .. "&status=ok"
        .. "&data=" .. urlencode(message)
    local req = inet:request(url, "GET", "", "text/plain")
    req:await()
    print("[>] " .. message:sub(1, 80))
end

local function jsonStr(data, key)
    return data:match('"' .. key .. '"%s*:%s*"([^"]*)"')
end

-- ============================================
-- FACTORY SCANNING
-- ============================================

-- Get all network components with details
local function scanFactory()
    local proxies = component.proxy(component.findComponent(""))
    local machines = {}
    local powerGen = {}
    local powerCons = {}
    local storage = {}
    local other = {}
    
    for _, p in pairs(proxies) do
        local info = {
            nick = tostring(p.nick or ""),
            id = tostring(p.id or ""),
        }
        
        -- Try to get class/type name
        local ok1, typeName = pcall(function()
            return tostring(p:getType().name)
        end)
        if ok1 then
            info.type = typeName
        else
            info.type = "Unknown"
        end
        
        -- Try to detect if it's a production machine
        local ok2, standby = pcall(function()
            return p.standby
        end)
        if ok2 then
            info.standby = standby
            info.isMachine = true
        end
        
        -- Try to get productivity/progress
        local ok3, prod = pcall(function()
            return p.productivity
        end)
        if ok3 then
            info.productivity = prod
        end
        
        local ok4, prog = pcall(function()
            return p.progress
        end)
        if ok4 then
            info.progress = prog
        end
        
        -- Try to get potential (clock speed)
        local ok5, potential = pcall(function()
            return p.potential
        end)
        if ok5 then
            info.potential = potential
        end
        
        -- Try power info
        local ok6, powerInfo = pcall(function()
            return p.powerInfo
        end)
        if ok6 and powerInfo then
            local ok7, dynProd = pcall(function()
                return powerInfo.dynProduction
            end)
            local ok8, baseConsume = pcall(function()
                return powerInfo.baseProduction
            end)
            if ok7 then info.powerProd = dynProd end
            if ok8 then info.powerBase = baseConsume end
        end
        
        -- Categorize
        if info.isMachine then
            table.insert(machines, info)
        else
            table.insert(other, info)
        end
    end
    
    return {
        machines = machines,
        other = other,
        total = #proxies
    }
end

-- ============================================
-- COMMAND HANDLERS
-- ============================================

local handlers = {}

handlers.ping = function(id)
    respond(id, "PONG! Bridge v" .. VERSION)
end

handlers.hello = function(id)
    respond(id, "Hello from Satisfactory! Bridge v" .. VERSION .. " connected.")
end

handlers.help = function(id)
    respond(id, "Commands: ping, hello, status, scan, machines, detail, toggle, power, help")
end

handlers.status = function(id)
    local factory = scanFactory()
    local machineCount = #factory.machines
    local activeCount = 0
    local standbyCount = 0
    
    for _, m in pairs(factory.machines) do
        if m.standby then
            standbyCount = standbyCount + 1
        else
            activeCount = activeCount + 1
        end
    end
    
    respond(id, "Factory Status v" .. VERSION 
        .. " | Total components: " .. factory.total
        .. " | Machines: " .. machineCount 
        .. " (active: " .. activeCount .. ", standby: " .. standbyCount .. ")"
        .. " | Other: " .. #factory.other)
end

handlers.scan = function(id)
    local factory = scanFactory()
    local lines = {}
    
    table.insert(lines, "=== FACTORY SCAN v" .. VERSION .. " ===")
    table.insert(lines, "Total: " .. factory.total .. " components")
    
    if #factory.machines > 0 then
        table.insert(lines, "--- MACHINES ---")
        for i, m in ipairs(factory.machines) do
            local name = m.nick ~= "" and m.nick or m.type
            local state = m.standby and "STANDBY" or "ACTIVE"
            local prod = ""
            if m.productivity then
                prod = " | Prod: " .. string.format("%.0f%%", m.productivity * 100)
            end
            table.insert(lines, i .. ". " .. name .. " [" .. m.type .. "] " .. state .. prod)
        end
    end
    
    if #factory.other > 0 then
        table.insert(lines, "--- OTHER ---")
        for i, o in ipairs(factory.other) do
            local name = o.nick ~= "" and o.nick or o.type
            table.insert(lines, i .. ". " .. name .. " [" .. o.type .. "]")
        end
    end
    
    respond(id, table.concat(lines, " | "))
end

handlers.machines = function(id)
    local factory = scanFactory()
    if #factory.machines == 0 then
        respond(id, "No machines found on network. Connect machines with network cables!")
        return
    end
    
    local lines = {}
    for i, m in ipairs(factory.machines) do
        local name = m.nick ~= "" and m.nick or m.type
        local state = m.standby and "OFF" or "ON"
        local prod = m.productivity and string.format(" %.0f%%", m.productivity * 100) or ""
        local clock = m.potential and string.format(" @%.0f%%", m.potential * 100) or ""
        table.insert(lines, name .. ":" .. state .. prod .. clock)
    end
    
    respond(id, "Machines (" .. #factory.machines .. "): " .. table.concat(lines, " | "))
end

handlers.detail = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: detail <machine_name>")
        return
    end
    
    local proxies = component.proxy(component.findComponent(""))
    for _, p in pairs(proxies) do
        local nick = tostring(p.nick or "")
        local ok, typeName = pcall(function() return tostring(p:getType().name) end)
        typeName = ok and typeName or "Unknown"
        
        if nick:lower() == target:lower() or typeName:lower() == target:lower() then
            local info = "Detail: " .. (nick ~= "" and nick or typeName)
            info = info .. " | Type: " .. typeName
            
            local ok2, standby = pcall(function() return p.standby end)
            if ok2 then info = info .. " | State: " .. (standby and "STANDBY" or "ACTIVE") end
            
            local ok3, prod = pcall(function() return p.productivity end)
            if ok3 then info = info .. " | Productivity: " .. string.format("%.1f%%", prod * 100) end
            
            local ok4, prog = pcall(function() return p.progress end)
            if ok4 then info = info .. " | Progress: " .. string.format("%.1f%%", prog * 100) end
            
            local ok5, pot = pcall(function() return p.potential end)
            if ok5 then info = info .. " | Clock: " .. string.format("%.0f%%", pot * 100) end
            
            respond(id, info)
            return
        end
    end
    
    respond(id, "Machine '" .. target .. "' not found. Use 'machines' to list all.")
end

handlers.toggle = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: toggle <machine_name>")
        return
    end
    
    local proxies = component.proxy(component.findComponent(""))
    for _, p in pairs(proxies) do
        local nick = tostring(p.nick or "")
        local ok1, typeName = pcall(function() return tostring(p:getType().name) end)
        typeName = ok1 and typeName or "Unknown"
        
        if nick:lower() == target:lower() or typeName:lower() == target:lower() then
            local ok2, standby = pcall(function() return p.standby end)
            if not ok2 then
                respond(id, "'" .. target .. "' cannot be toggled (not a machine)")
                return
            end
            
            local ok3, err = pcall(function()
                p.standby = not standby
            end)
            
            if ok3 then
                local newState = (not standby) and "STANDBY" or "ACTIVE"
                respond(id, "Toggled " .. (nick ~= "" and nick or typeName) .. " -> " .. newState)
            else
                respond(id, "Failed to toggle: " .. tostring(err))
            end
            return
        end
    end
    
    respond(id, "Machine '" .. target .. "' not found. Use 'machines' to list all.")
end

handlers.power = function(id)
    local proxies = component.proxy(component.findComponent(""))
    local circuits = {}
    
    for _, p in pairs(proxies) do
        local ok, powerInfo = pcall(function() return p.powerInfo end)
        if ok and powerInfo then
            local ok2, circuit = pcall(function() return powerInfo:getCircuit() end)
            if ok2 and circuit then
                local cid = tostring(circuit.id or "main")
                if not circuits[cid] then
                    local ok3, prod = pcall(function() return circuit.production end)
                    local ok4, cons = pcall(function() return circuit.consumption end)
                    local ok5, cap = pcall(function() return circuit.capacity end)
                    local ok6, batt = pcall(function() return circuit.batteryPercent end)
                    
                    circuits[cid] = {
                        production = ok3 and prod or 0,
                        consumption = ok4 and cons or 0,
                        capacity = ok5 and cap or 0,
                        battery = ok6 and batt or nil,
                    }
                end
            end
        end
    end
    
    if next(circuits) == nil then
        respond(id, "No power circuits found on network.")
        return
    end
    
    local lines = {"Power Status:"}
    for cid, c in pairs(circuits) do
        local line = string.format("Circuit %s: %.0f MW / %.0f MW capacity (%.0f MW consumed)",
            cid, c.production, c.capacity, c.consumption)
        if c.battery then
            line = line .. string.format(" | Battery: %.0f%%", c.battery * 100)
        end
        table.insert(lines, line)
    end
    
    respond(id, table.concat(lines, " | "))
end

-- ============================================
-- COMMAND DISPATCHER
-- ============================================

local function process(raw)
    local action = jsonStr(raw, "action")
    local id = jsonStr(raw, "id")
    local target = jsonStr(raw, "target")
    
    if not action or action == "" then
        respond(id or "unknown", "No action found")
        return
    end
    
    print("[<] " .. action .. (target and (" -> " .. target) or "") .. " (id: " .. (id or "?") .. ")")
    
    local handler = handlers[action]
    if handler then
        local ok, err = pcall(handler, id, target)
        if not ok then
            respond(id, "Error executing '" .. action .. "': " .. tostring(err))
        end
    else
        respond(id, "Unknown: '" .. action .. "'. Try: help")
    end
end

-- ============================================
-- MAIN
-- ============================================
print("========================================")
print("  SATISFACTORY BRIDGE v" .. VERSION)
print("  " .. BRIDGE)
print("========================================")

print("[*] Testing connection...")
local testReq = inet:request(BRIDGE .. "/status", "GET", "", "text/plain")
local testCode, testData = testReq:await()
if testData and testData:find('"ok":true') then
    print("[*] Bridge connected!")
else
    print("[!] Bridge unreachable: " .. tostring(testData))
    return
end

respond("boot", "Bridge v" .. VERSION .. " online! Commands: ping, status, scan, machines, detail, toggle, power, help")
print("[*] Polling every 3s...")

while true do
    local ok, err = pcall(function()
        local req = inet:request(BRIDGE .. "/command?key=" .. KEY, "GET", "", "text/plain")
        local code, data = req:await()
        
        if data then
            if data:find('"command":null') or data:find('"command": null') then
                -- empty queue
            elseif data:find('"action"') then
                process(data)
            end
        end
    end)
    
    if not ok then
        print("[!] Error: " .. tostring(err))
    end
    
    event.pull(3)
end
