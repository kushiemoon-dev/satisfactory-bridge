# FicsIt Networks Lua Scripts

Lua scripts for connecting AI assistants to Satisfactory via FicsIt Networks mod.

## Requirements

- Satisfactory with [FicsIt Networks](https://ficsit.app/mod/FicsItNetworks) mod
- Computer Case with Internet Card installed
- HTTP bridge server running (see main README)

## Setup

1. Build a Computer Case in-game
2. Install an Internet Card (PCI slot)
3. Connect to your factory network
4. Copy script to EEPROM
5. Update `BRIDGE` and `API_KEY` variables
6. Run the script

## Scripts

### lexis-factory-control-v6.lua

Full-featured factory control script with:

**Commands:**
| Command | Description |
|---------|-------------|
| `ping` | Connectivity test |
| `hello` | Greeting with counter |
| `status` | Factory status overview |
| `power` | Power grid information |
| `machines` | Machine counts by type |
| `trains` | Train network info |
| `storage` | Storage container counts |
| `scan` | Network component scan |
| `count` | Total component count |
| `time` | Script uptime |
| `say` | Display message in console |
| `help` | List available commands |

## Important Notes

### Linux Dedicated Server Workaround

FicsIt Networks `inet:request()` with POST method crashes on Linux dedicated servers. This script uses GET requests for responses as a workaround:

```lua
-- Instead of POST:
-- inet:request(url, "POST", body, "application/json")  -- CRASHES!

-- Use GET with URL parameters:
inet:request(url .. "?data=" .. urlEncode(msg), "GET", "", "text/plain")  -- WORKS!
```

### HTTP Request Pattern

```lua
-- Correct pattern (use await, not get):
local req = inet:request(url, "GET", "", "text/plain")
local code, data = req:await()  -- Blocks until response

-- Wrong pattern (errors on pending future):
-- local code, data = req:get()  -- ERROR!
```

## License

MIT
