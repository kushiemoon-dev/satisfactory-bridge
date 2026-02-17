-- ============================================
-- SATISFACTORY BRIDGE v2.1
-- Real factory monitoring & control + toggle by index
-- ============================================

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not inet then
    print("!! NO INTERNET CARD FOUND !!")
    return
end

local BRIDGE = "https://YOUR-BRIDGE-URL"
local KEY = "YOUR-API-KEY-HERE"
local VERSION = "3.0"

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

-- Shorter display names for cleaner output
local SHORT_NAMES = {
    Build_ConstructorMk1_C = "Constructor1",
    Build_Constructor_Mk2_C = "Constructor2",
    Build_SmelterMk1_C = "Smelter",
    Build_FoundryMk1_C = "Foundry",
    Build_AssemblerMk1_C = "Assembler",
    Build_ManufacturerMk1_C = "Manufacturer",
    Build_OilRefinery_C = "Refinery",
    Build_Packager_C = "Packager",
    Build_Blender_C = "Blender",
    Build_MinerMk1_C = "Miner1",
    Build_MinerMk2_C = "Miner2",
    Build_MinerMk3_C = "Miner3",
    Build_GeneratorCoal_C = "CoalGen",
    Build_GeneratorFuel_C = "FuelGen",
    Build_GeneratorNuclear_C = "NuclearGen",
    Build_GeneratorBiomass_C = "BiomassGen",
    Build_WaterPump_C = "WaterPump",
    Build_OilPump_C = "OilPump",
    Build_ComputerCase_C = "FicsItPC",
    Build_NetworkCard_C = "NetCard",
    BP_Microcontroller_C = "Microcontroller",
    Build_StorageContainerMk1_C = "Storage1",
    Build_StorageContainerMk2_C = "Storage2",
}

local function shortName(typeName)
    return SHORT_NAMES[typeName] or typeName:gsub("Build_", ""):gsub("_C$", "")
end

-- Cached machine list (rebuilt on scan)
local machineCache = {}

-- Get all network components with details
local function scanFactory()
    local proxies = component.proxy(component.findComponent(""))
    local machines = {}
    local other = {}
    
    for _, p in pairs(proxies) do
        local info = {
            nick = tostring(p.nick or ""),
            id = tostring(p.id or ""),
            proxy = p,  -- keep reference for toggle
        }
        
        local ok1, typeName = pcall(function()
            return tostring(p:getType().name)
        end)
        info.type = ok1 and typeName or "Unknown"
        info.shortName = shortName(info.type)
        
        -- Display name: nickname > short type name
        info.displayName = info.nick ~= "" and info.nick or info.shortName
        
        -- Detect real production machines by trying to SET standby (read returns nil for non-machines too)
        -- A real machine: standby is a boolean (true/false), not nil
        -- We test by checking if the type looks like a production building
        local isProduction = info.type:find("Constructor") 
            or info.type:find("Smelter") or info.type:find("Foundry")
            or info.type:find("Assembler") or info.type:find("Manufacturer")
            or info.type:find("Refinery") or info.type:find("Packager")
            or info.type:find("Blender") or info.type:find("HadronCollider")
            or info.type:find("Miner") or info.type:find("WaterPump")
            or info.type:find("OilPump") or info.type:find("Generator")
            or info.type:find("Converter") or info.type:find("QuantumEncoder")
            or info.type:find("Fracking")
        
        if isProduction then
            local ok2, standby = pcall(function() return p.standby end)
            if ok2 then info.standby = standby or false end
            info.isMachine = true
            
            local ok3, prod = pcall(function() return p.productivity end)
            if ok3 and prod then info.productivity = prod end
            
            local ok4, prog = pcall(function() return p.progress end)
            if ok4 and prog then info.progress = prog end
            
            local ok5, potential = pcall(function() return p.potential end)
            if ok5 and potential then info.potential = potential end
        end
        
        -- Only check power on production machines (avoids warnings on FicsIt components)
        if isProduction then
            local ok6, powerInfo = pcall(function() return p.powerInfo end)
            if ok6 and powerInfo and powerInfo ~= nil then
                local ok7, dynProd = pcall(function() return powerInfo.dynProduction end)
                local ok8, baseConsume = pcall(function() return powerInfo.baseProduction end)
                if ok7 and dynProd then info.powerProd = dynProd end
                if ok8 and baseConsume then info.powerBase = baseConsume end
            end
        end
        
        if info.isMachine then
            table.insert(machines, info)
        else
            table.insert(other, info)
        end
    end
    
    -- Update cache
    machineCache = machines
    
    return {
        machines = machines,
        other = other,
        total = #proxies
    }
end

-- Get machine by index (1-based) from cache
local function getMachineByIndex(idx)
    if #machineCache == 0 then
        scanFactory()  -- refresh cache
    end
    if idx >= 1 and idx <= #machineCache then
        return machineCache[idx]
    end
    return nil
end

-- Get machine by name or index
local function findMachine(target)
    -- Try as index first
    local idx = tonumber(target)
    if idx then
        return getMachineByIndex(idx), idx
    end
    
    -- Try by nickname or type
    if #machineCache == 0 then scanFactory() end
    for i, m in ipairs(machineCache) do
        if m.nick:lower() == target:lower() 
           or m.shortName:lower() == target:lower()
           or m.type:lower() == target:lower()
           or m.displayName:lower() == target:lower() then
            return m, i
        end
    end
    return nil, nil
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
    respond(id, "Commands: ping, status, summary, machines [page], detail <#>, toggle <#>, toggle-type <type>, all-on, all-off, recipe [#], inventory <#>, bottleneck, low, power, alerts on/off, debug <#>, help")
end

handlers.summary = function(id)
    local factory = scanFactory()
    if #factory.machines == 0 then
        respond(id, "No machines on network.")
        return
    end
    
    -- Group by type
    local byType = {}
    local typeOrder = {}
    local totalProd = 0
    local prodCount = 0
    
    for _, m in ipairs(factory.machines) do
        local t = m.shortName
        if not byType[t] then
            byType[t] = { total = 0, active = 0, standby = 0, prodSum = 0, prodN = 0 }
            table.insert(typeOrder, t)
        end
        byType[t].total = byType[t].total + 1
        if m.standby then
            byType[t].standby = byType[t].standby + 1
        else
            byType[t].active = byType[t].active + 1
        end
        if m.productivity then
            byType[t].prodSum = byType[t].prodSum + m.productivity
            byType[t].prodN = byType[t].prodN + 1
            totalProd = totalProd + m.productivity
            prodCount = prodCount + 1
        end
    end
    
    -- Sort by count descending
    table.sort(typeOrder, function(a, b) return byType[a].total > byType[b].total end)
    
    local lines = {}
    for _, t in ipairs(typeOrder) do
        local info = byType[t]
        local avgProd = info.prodN > 0 and string.format(" avg:%.0f%%", (info.prodSum / info.prodN) * 100) or ""
        local standbyStr = info.standby > 0 and (" (" .. info.standby .. " off)") or ""
        table.insert(lines, t .. ": " .. info.total .. standbyStr .. avgProd)
    end
    
    local avgAll = prodCount > 0 and string.format("%.0f%%", (totalProd / prodCount) * 100) or "?"
    
    respond(id, "Factory: " .. #factory.machines .. " machines, " .. #factory.other .. " other | Avg productivity: " .. avgAll .. " | " .. table.concat(lines, " | "))
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

handlers.machines = function(id, target)
    local factory = scanFactory()
    if #factory.machines == 0 then
        respond(id, "No machines found on network. Connect machines with network cables!")
        return
    end
    
    -- Pagination: 20 machines per page
    local PAGE_SIZE = 20
    local page = tonumber(target) or 1
    local totalPages = math.ceil(#factory.machines / PAGE_SIZE)
    if page < 1 then page = 1 end
    if page > totalPages then page = totalPages end
    
    local startIdx = (page - 1) * PAGE_SIZE + 1
    local endIdx = math.min(page * PAGE_SIZE, #factory.machines)
    
    local lines = {}
    for i = startIdx, endIdx do
        local m = factory.machines[i]
        local state = m.standby and "OFF" or "ON"
        local prod = m.productivity and string.format(" %.0f%%", m.productivity * 100) or ""
        local clock = m.potential and string.format(" @%.0f%%", m.potential * 100) or ""
        table.insert(lines, "#" .. i .. " " .. m.displayName .. ":" .. state .. prod .. clock)
    end
    
    local header = "Machines p" .. page .. "/" .. totalPages .. " (" .. #factory.machines .. " total)"
    respond(id, header .. ": " .. table.concat(lines, " | "))
end

handlers.detail = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: detail <#index or name>. Example: detail 4")
        return
    end
    
    local m, idx = findMachine(target)
    if not m then
        respond(id, "Machine '" .. target .. "' not found. Use 'machines' to list all.")
        return
    end
    
    local info = "#" .. idx .. " " .. m.displayName
    info = info .. " | Type: " .. m.type
    if m.standby ~= nil then info = info .. " | State: " .. (m.standby and "STANDBY" or "ACTIVE") end
    if m.productivity then info = info .. " | Productivity: " .. string.format("%.1f%%", m.productivity * 100) end
    if m.progress then info = info .. " | Progress: " .. string.format("%.1f%%", m.progress * 100) end
    if m.potential then info = info .. " | Clock: " .. string.format("%.0f%%", m.potential * 100) end
    
    respond(id, info)
end

handlers.toggle = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: toggle <#index or name>. Example: toggle 4")
        return
    end
    
    local m, idx = findMachine(target)
    if not m then
        respond(id, "Machine '" .. target .. "' not found. Use 'machines' to list all.")
        return
    end
    
    if m.standby == nil then
        respond(id, "#" .. idx .. " " .. m.displayName .. " cannot be toggled (not a production machine)")
        return
    end
    
    local ok, err = pcall(function()
        m.proxy.standby = not m.standby
    end)
    
    if ok then
        local newState = (not m.standby) and "STANDBY" or "ACTIVE"
        respond(id, "Toggled #" .. idx .. " " .. m.displayName .. " -> " .. newState)
    else
        respond(id, "Failed to toggle #" .. idx .. ": " .. tostring(err))
    end
end

-- Debug: explore what a machine exposes
handlers.debug = function(id, target)
    local idx = tonumber(target) or 1
    if #machineCache == 0 then scanFactory() end
    local m = machineCache[idx]
    if not m then
        respond(id, "Machine #" .. idx .. " not found")
        return
    end
    
    local p = m.proxy
    local props = {}
    
    -- Try all useful FicsIt properties
    local tests = {
        "standby", "productivity", "progress", "potential",
        "powerInfo", "powerConsumProducing", "powerConsumption",
        "recipe", "currentRecipe", "getRecipe", "getRecipes",
        "inputInv", "outputInv", "getInputInv", "getOutputInv",
        "getInventories", "getFactoryConnectors",
        "cycleTime", "maxPotential", "minPotential",
    }
    
    for _, name in ipairs(tests) do
        local ok, val = pcall(function() return p[name] end)
        if ok and val ~= nil then
            local t = type(val)
            if t == "function" then
                -- Try calling it
                local ok2, result = pcall(val, p)
                if ok2 then
                    table.insert(props, name .. "()=" .. tostring(result))
                else
                    table.insert(props, name .. "(FUNC)")
                end
            else
                table.insert(props, name .. "=" .. tostring(val))
            end
        end
    end
    
    respond(id, "#" .. idx .. " " .. m.displayName .. " [" .. m.type .. "] | " .. table.concat(props, " | "))
end

-- Try to get recipe name from a machine
local function getRecipeName(proxy)
    -- Try different ways to get recipe
    local ok1, recipe = pcall(function() return proxy:getRecipe() end)
    if ok1 and recipe then
        local ok2, name = pcall(function() return recipe.name end)
        if ok2 and name then return name end
        local ok3, name2 = pcall(function() return tostring(recipe) end)
        if ok3 then return name2 end
    end
    local ok4, recipe2 = pcall(function() return proxy.currentRecipe end)
    if ok4 and recipe2 then
        local ok5, name3 = pcall(function() return recipe2.name end)
        if ok5 and name3 then return name3 end
        return tostring(recipe2)
    end
    return nil
end

-- Get input/output inventories
local function getInventoryContents(proxy)
    local result = { inputs = {}, outputs = {} }
    
    -- Try getInputInv / getOutputInv
    local ok1, inputInv = pcall(function() return proxy:getInputInv() end)
    if ok1 and inputInv then
        local ok2, stacks = pcall(function() return inputInv:getStack(0) end)
        if ok2 and stacks then
            local ok3, item = pcall(function() return stacks.item end)
            local ok4, count = pcall(function() return stacks.count end)
            if ok3 and item and ok4 then
                local ok5, itemName = pcall(function() return item.type.name end)
                table.insert(result.inputs, (ok5 and itemName or "?") .. "x" .. (count or 0))
            end
        end
    end
    
    -- Try getInventories
    local ok6, invs = pcall(function() return proxy:getInventories() end)
    if ok6 and invs then
        for i, inv in pairs(invs) do
            local ok7, size = pcall(function() return inv.size end)
            if ok7 and size then
                for slot = 0, math.min(size - 1, 5) do
                    local ok8, stack = pcall(function() return inv:getStack(slot) end)
                    if ok8 and stack then
                        local ok9, count = pcall(function() return stack.count end)
                        local ok10, item = pcall(function() return stack.item.type.name end)
                        if ok9 and ok10 and count and count > 0 then
                            table.insert(result.inputs, item .. "x" .. count)
                        end
                    end
                end
            end
        end
    end
    
    return result
end

handlers.recipe = function(id, target)
    if not target or target == "" then
        -- Show all recipes summary
        if #machineCache == 0 then scanFactory() end
        local recipes = {}
        for i, m in ipairs(machineCache) do
            local recipeName = getRecipeName(m.proxy)
            if recipeName then
                if not recipes[recipeName] then
                    recipes[recipeName] = { count = 0, machines = {} }
                end
                recipes[recipeName].count = recipes[recipeName].count + 1
            end
        end
        
        local lines = {}
        for name, info in pairs(recipes) do
            table.insert(lines, name .. ": " .. info.count .. "x")
        end
        
        if #lines == 0 then
            respond(id, "Could not read recipes (API may not support it)")
        else
            table.sort(lines)
            respond(id, "Recipes: " .. table.concat(lines, " | "))
        end
        return
    end
    
    local m, idx = findMachine(target)
    if not m then
        respond(id, "Machine '" .. target .. "' not found")
        return
    end
    
    local recipeName = getRecipeName(m.proxy) or "Unknown"
    respond(id, "#" .. idx .. " " .. m.displayName .. " recipe: " .. recipeName)
end

handlers.inventory = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: inventory <#index>")
        return
    end
    
    local m, idx = findMachine(target)
    if not m then
        respond(id, "Machine '" .. target .. "' not found")
        return
    end
    
    local inv = getInventoryContents(m.proxy)
    local items = {}
    for _, s in ipairs(inv.inputs) do table.insert(items, s) end
    for _, s in ipairs(inv.outputs) do table.insert(items, s) end
    
    if #items == 0 then
        respond(id, "#" .. idx .. " " .. m.displayName .. ": inventory empty or not readable")
    else
        respond(id, "#" .. idx .. " " .. m.displayName .. " inventory: " .. table.concat(items, " | "))
    end
end

handlers.bottleneck = function(id)
    if #machineCache == 0 then scanFactory() end
    
    -- Find machines with lowest productivity
    local lowMachines = {}
    for i, m in ipairs(machineCache) do
        if m.productivity and m.productivity < 0.5 then
            table.insert(lowMachines, { idx = i, machine = m })
        end
    end
    
    -- Sort by productivity ascending (worst first)
    table.sort(lowMachines, function(a, b)
        return (a.machine.productivity or 0) < (b.machine.productivity or 0)
    end)
    
    if #lowMachines == 0 then
        respond(id, "No bottlenecks! All machines above 50% productivity.")
        return
    end
    
    -- Show top 15 worst
    local lines = {}
    local limit = math.min(#lowMachines, 15)
    for i = 1, limit do
        local entry = lowMachines[i]
        local m = entry.machine
        local prod = string.format("%.0f%%", (m.productivity or 0) * 100)
        table.insert(lines, "#" .. entry.idx .. " " .. m.displayName .. " " .. prod)
    end
    
    respond(id, "Bottlenecks (" .. #lowMachines .. " machines <50%): " .. table.concat(lines, " | "))
end

handlers.low = function(id)
    if #machineCache == 0 then scanFactory() end
    
    local lowMachines = {}
    for i, m in ipairs(machineCache) do
        if m.productivity and m.productivity < 0.2 then
            table.insert(lowMachines, { idx = i, machine = m })
        end
    end
    
    table.sort(lowMachines, function(a, b)
        return (a.machine.productivity or 0) < (b.machine.productivity or 0)
    end)
    
    if #lowMachines == 0 then
        respond(id, "No machines below 20%! Nice.")
        return
    end
    
    local lines = {}
    local limit = math.min(#lowMachines, 20)
    for i = 1, limit do
        local entry = lowMachines[i]
        local m = entry.machine
        local prod = string.format("%.0f%%", (m.productivity or 0) * 100)
        table.insert(lines, "#" .. entry.idx .. " " .. m.displayName .. " " .. prod)
    end
    
    local more = #lowMachines > 20 and (" (+" .. (#lowMachines - 20) .. " more)") or ""
    respond(id, "Low <20% (" .. #lowMachines .. " machines): " .. table.concat(lines, " | ") .. more)
end

-- Toggle all machines of a specific type
handlers["toggle-type"] = function(id, target)
    if not target or target == "" then
        respond(id, "Usage: toggle-type <type>. Example: toggle-type Smelter")
        return
    end
    
    if #machineCache == 0 then scanFactory() end
    
    local matched = {}
    for i, m in ipairs(machineCache) do
        if m.shortName:lower():find(target:lower()) or m.type:lower():find(target:lower()) then
            table.insert(matched, { idx = i, machine = m })
        end
    end
    
    if #matched == 0 then
        respond(id, "No machines matching '" .. target .. "'. Use 'summary' to see types.")
        return
    end
    
    -- Determine action: if majority are active, put all to standby. Otherwise activate all.
    local activeCount = 0
    for _, entry in ipairs(matched) do
        if not entry.machine.standby then activeCount = activeCount + 1 end
    end
    
    local newStandby = activeCount > (#matched / 2)  -- majority active → turn off
    local success = 0
    local failed = 0
    
    for _, entry in ipairs(matched) do
        local ok, err = pcall(function()
            entry.machine.proxy.standby = newStandby
        end)
        if ok then
            success = success + 1
        else
            failed = failed + 1
        end
    end
    
    local action = newStandby and "STANDBY" or "ACTIVE"
    local msg = "Toggled " .. success .. "x " .. target .. " -> " .. action
    if failed > 0 then msg = msg .. " (" .. failed .. " failed)" end
    respond(id, msg)
end

-- Alerts: check for critical issues
local alertsEnabled = false
local alertInterval = 30  -- seconds between alert checks
local lastAlertCheck = 0

handlers.alerts = function(id, target)
    if target == "on" then
        alertsEnabled = true
        respond(id, "Alerts ENABLED. Checking every " .. alertInterval .. "s for: machines at 0%, power issues.")
    elseif target == "off" then
        alertsEnabled = false
        respond(id, "Alerts DISABLED.")
    else
        respond(id, "Alerts: " .. (alertsEnabled and "ON" or "OFF") .. " | Usage: alerts on/off")
    end
end

local function checkAlerts()
    if not alertsEnabled then return end
    
    local now = computer.millis()
    if now - lastAlertCheck < alertInterval * 1000 then return end
    lastAlertCheck = now
    
    -- Refresh factory data
    scanFactory()
    
    -- Check for machines that just went to 0%
    local deadMachines = {}
    for i, m in ipairs(machineCache) do
        if m.productivity and m.productivity == 0 and not m.standby then
            table.insert(deadMachines, "#" .. i .. " " .. m.shortName)
        end
    end
    
    if #deadMachines > 0 then
        local msg = "ALERT: " .. #deadMachines .. " machines at 0%"
        if #deadMachines <= 5 then
            msg = msg .. ": " .. table.concat(deadMachines, ", ")
        end
        respond("alert", msg)
    end
end

-- Toggle-all: toggle every machine on/off
handlers["all-on"] = function(id)
    if #machineCache == 0 then scanFactory() end
    local success = 0
    for _, m in ipairs(machineCache) do
        local ok = pcall(function() m.proxy.standby = false end)
        if ok then success = success + 1 end
    end
    respond(id, "All machines ACTIVATED (" .. success .. "/" .. #machineCache .. ")")
end

handlers["all-off"] = function(id)
    if #machineCache == 0 then scanFactory() end
    local success = 0
    for _, m in ipairs(machineCache) do
        local ok = pcall(function() m.proxy.standby = true end)
        if ok then success = success + 1 end
    end
    respond(id, "All machines STANDBY (" .. success .. "/" .. #machineCache .. ")")
end

handlers.power = function(id)
    -- Only check power on production machines to avoid warnings
    if #machineCache == 0 then scanFactory() end
    local circuits = {}
    
    for _, m in pairs(machineCache) do
        local p = m.proxy
        local ok, powerInfo = pcall(function() return p.powerInfo end)
        if ok and powerInfo and powerInfo ~= nil then
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
    
    -- Check alerts
    local ok2, err2 = pcall(checkAlerts)
    if not ok2 then
        print("[!] Alert error: " .. tostring(err2))
    end
    
    event.pull(3)
end
