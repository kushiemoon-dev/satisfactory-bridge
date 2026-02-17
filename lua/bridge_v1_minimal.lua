-- ============================================
-- SATISFACTORY BRIDGE v1.0 - MINIMAL
-- Just poll + respond. Nothing fancy.
-- ============================================

-- Step 1: Find Internet Card
local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not inet then
    print("!! NO INTERNET CARD FOUND !!")
    print("Connect an Internet Card to this computer.")
    return
end

local BRIDGE = "https://YOUR-BRIDGE-URL"
local KEY = "YOUR-API-KEY-HERE"

-- Simple URL encoder
local function urlencode(s)
    s = tostring(s or "")
    s = s:gsub("\n", " ")
    s = s:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s
end

-- Send a response back to the bridge (GET workaround)
local function respond(cmdId, message)
    local url = BRIDGE .. "/response?key=" .. KEY
        .. "&command_id=" .. urlencode(cmdId)
        .. "&status=ok"
        .. "&data=" .. urlencode(message)
    local req = inet:request(url, "GET", "", "text/plain")
    req:await()
    print("[>] Sent: " .. message:sub(1, 60))
end

-- Extract a JSON string value by key name
-- Works for: "key":"value" or "key": "value"
local function jsonStr(data, key)
    local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
    return data:match(pattern)
end

-- Process one command
local function process(raw)
    -- The bridge returns: {"command":{"id":"xxx","action":"yyy",...},"ok":true,"queued":0}
    -- We need to extract "action" from inside the "command" object
    
    local action = jsonStr(raw, "action")
    local id = jsonStr(raw, "id")
    
    if not action or action == "" then
        print("[!] No action found in: " .. raw:sub(1, 80))
        respond(id or "unknown", "No action found in command")
        return
    end
    
    print("[<] Command: " .. action .. " (id: " .. (id or "?") .. ")")
    
    if action == "ping" then
        respond(id, "PONG from Satisfactory!")
        
    elseif action == "hello" then
        respond(id, "Hello! Bridge v1.0 minimal connected!")
        
    elseif action == "status" then
        local comps = component.findComponent("")
        respond(id, "Online | Components: " .. #comps)
        
    elseif action == "scan" then
        local comps = component.findComponent("")
        local result = "Found " .. #comps .. " components"
        respond(id, result)
        
    elseif action == "help" then
        respond(id, "Commands: ping, hello, status, scan, help")
        
    else
        respond(id, "Unknown command: " .. action)
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================
print("========================================")
print("  BRIDGE v1.0 MINIMAL")
print("  " .. BRIDGE)
print("========================================")

-- Test connection first
print("[*] Testing connection...")
local testReq = inet:request(BRIDGE .. "/status", "GET", "", "text/plain")
local testCode, testData = testReq:await()
if testData and testData:find('"ok":true') then
    print("[*] Bridge connected! OK")
else
    print("[!] Bridge not reachable: " .. tostring(testData))
    print("[!] Check URL and network.")
    return
end

-- Send boot notification
respond("boot", "Game connected! Bridge v1.0 minimal ready.")
print("[*] Polling every 3s...")

-- Poll loop
while true do
    local ok, err = pcall(function()
        local req = inet:request(BRIDGE .. "/command?key=" .. KEY, "GET", "", "text/plain")
        local code, data = req:await()
        
        if data then
            -- Check if there's actually a command (not null)
            -- When empty: {"command":null,"ok":true,"queued":0}
            -- When command: {"command":{"id":"...","action":"..."},"ok":true,...}
            if data:find('"command":null') or data:find('"command": null') then
                -- No command, do nothing
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
