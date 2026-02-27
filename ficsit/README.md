# FicsIt-Networks Client

Lua script for in-game computers to connect to the Satisfactory Bridge.

## Requirements

- FicsIt-Networks mod installed
- Computer placed in your factory
- Internet Card connected to the computer
- Machines connected via network cables (and optionally nicknamed)

## Setup

1. Open the Computer's UI in-game
2. Create a new file on the drive
3. Paste the contents of `bridge_client.lua`
4. Edit the `BRIDGE_URL` to point to your bridge server
5. Run the script

## Configuration

Edit these at the top of `bridge_client.lua`:

```lua
local BRIDGE_URL = "http://YOUR_BRIDGE_IP:8080"  -- Your bridge IP
local API_KEY = "YOUR-API-KEY-HERE"            -- Must match bridge
local POLL_INTERVAL = 2                        -- Seconds between polls
```

⚠️ **Security Note**: Replace `YOUR-API-KEY-HERE` with your actual API key from the bridge's `BRIDGE_API_KEY` environment variable.

## Available Commands

Send these via the bridge API:

### `ping`
Test connectivity.
```json
{"action": "ping"}
```

### `get_status`
Get status of all connected machines.
```json
{"action": "get_status"}
```

### `list_machines`
List all discovered machines.
```json
{"action": "list_machines"}
```

### `toggle`
Toggle a machine's standby state.
```json
{"action": "toggle", "target": "machine_name"}
```

### `set_standby`
Set a machine's standby state explicitly.
```json
{"action": "set_standby", "target": "machine_name", "params": {"enabled": true}}
```

### `start_all`
Start all machines.
```json
{"action": "start_all"}
```

### `stop_all`
Stop all machines (set to standby).
```json
{"action": "stop_all"}
```

## Machine Naming

For easier control, nickname your machines in-game:
1. Look at a machine
2. Press Middle Mouse Button
3. Give it a name like "iron_smelter_01"

Then use that name in commands:
```json
{"action": "toggle", "target": "iron_smelter_01"}
```

## Troubleshooting

### "No Internet Card found"
Connect an Internet Card component to your computer.

### Connection timeouts
- Check the bridge server is running
- Verify the IP and port are correct
- Ensure your PC firewall allows the connection

### Machines not discovered
- Connect machines to the computer network with cables
- Only production machines are discovered (constructors, smelters, etc.)
