# Satisfactory Bridge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/Go-1.22+-blue.svg)](https://golang.org/dl/)

A lightweight HTTP bridge that enables external systems and automation tools to control and monitor your Satisfactory factory through FicsIt-Networks mod integration.

## Overview

**Satisfactory Bridge** acts as a bidirectional communication layer between external systems and the Satisfactory game. It provides a simple REST API for sending commands to your factory and receiving status updates, enabling automated factory control and monitoring.

### Key Features

- 🔌 **Simple REST API** - Easy integration with automation tools and external systems
- 🎮 **FicsIt-Networks Integration** - Full Lua client library for in-game computers
- 🔐 **Secure API Key Authentication** - Protect your factory from unauthorized access
- 📊 **Command Queue Management** - FIFO queue with view/clear capabilities
- 🔄 **Bidirectional Communication** - Send commands and receive responses
- 🐧 **Linux Ready** - Includes Alpine Linux init script for service deployment
- 📝 **Comprehensive Logging** - Monitor all bridge activity with detailed logs

### Use Cases

- **External Factory Control** - Integrate with automation systems to optimize production
- **Remote Monitoring** - Check factory status from external dashboards
- **Scripted Automation** - Automate complex factory operations and workflows
- **Integration Testing** - Automate game state verification for mod development

## Architecture

```
┌─────────────┐                  ┌──────────────┐                 ┌──────────────────┐
│  External   │                  │    Bridge    │                 │   Satisfactory   │
│   System    │                  │    Server    │                 │  FicsIt Computer │
└──────┬──────┘                  └──────┬───────┘                 └────────┬─────────┘
       │                                │                                  │
       │ POST /command                  │                                  │
       │ {"action": "get_status"}       │                                  │
       ├───────────────────────────────►│                                  │
       │                                │                                  │
       │                                │ Stores in queue                  │
       │                                │                                  │
       │                                │         GET /command             │
       │                                │◄─────────────────────────────────┤
       │                                │                                  │
       │                                │ Returns & removes oldest command │
       │                                ├─────────────────────────────────►│
       │                                │                                  │
       │                                │         Executes command         │
       │                                │         in factory               │
       │                                │                                  │
       │                                │         POST /response           │
       │                                │◄─────────────────────────────────┤
       │                                │ {"status": "success", ...}       │
       │                                │                                  │
       │ GET /responses                 │                                  │
       ├───────────────────────────────►│                                  │
       │◄───────────────────────────────┤                                  │
       │ Returns all responses          │                                  │
       │                                │                                  │
```

### Components

1. **Bridge Server** (`main.go`) - Lightweight Go HTTP server managing command queue and responses
2. **Parser** (`parser/`) - Optional log parser for monitoring factory health from game logs
3. **Lua Clients** (`lua/`, `ficsit/`) - In-game scripts for FicsIt-Networks computers

## Installation

### Prerequisites

- Go 1.22 or higher (for building from source)
- Satisfactory game with [FicsIt-Networks](https://github.com/Panakotta00/FicsIt-Networks) mod installed
- Linux server or container (Alpine, Ubuntu, Debian, etc.)

### Quick Start

#### 1. Build the Bridge Server

```bash
# Clone the repository
git clone https://github.com/kushie/satisfactory-bridge.git
cd satisfactory-bridge

# Build the bridge server
go build -o bridge main.go

# (Optional) Build the log parser
cd parser && go build && cd ..
```

#### 2. Configure Environment

Generate a strong API key and set environment variables:

```bash
# Generate a secure API key
export BRIDGE_API_KEY="$(openssl rand -base64 32)"

# Optional: Set custom port (default is :8080)
export BRIDGE_PORT=":8080"
```

⚠️ **Security Warning**: Never commit real API keys to version control. Always use environment variables.

#### 3. Run the Bridge

```bash
./bridge
```

You should see:

```
Satisfactory Bridge Server
   Version: 1.0.0
   Port: :8080
   API Key: ****xxxx
```

#### 4. Set Up In-Game Client

1. Open Satisfactory and place a **Computer** in your factory
2. Connect an **Internet Card** to the computer
3. Connect machines you want to control via **network cables**
4. Open the computer's filesystem and create a new Lua file
5. Copy the contents of `ficsit/bridge_client.lua`
6. Edit the configuration:

```lua
local BRIDGE_URL = "http://<your-bridge-ip>:8080"
local API_KEY = "<your-api-key-here>"
local POLL_INTERVAL = 2
```

7. Run the script and verify connection

### Alpine Linux LXC Deployment

For production deployment on Alpine Linux:

```bash
# Install dependencies
apk add go git openrc

# Clone and build
git clone https://github.com/kushie/satisfactory-bridge.git
cd satisfactory-bridge
go build -o bridge main.go

# Install as a service
cp bridge /usr/local/bin/
cp bridge.initd /etc/init.d/bridge
chmod +x /etc/init.d/bridge

# Create configuration
cat > /etc/conf.d/bridge << EOF
BRIDGE_API_KEY="$(openssl rand -base64 32)"
BRIDGE_PORT=":8080"
EOF

# Enable and start
rc-update add bridge default
rc-service bridge start
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BRIDGE_API_KEY` | **(required)** | API key for authentication. Must be set. |
| `BRIDGE_PORT` | `:8080` | Port to listen on (format: `:PORT`) |

### Security Best Practices

1. **Use Strong API Keys**
   ```bash
   # Generate cryptographically secure key
   openssl rand -base64 32
   ```

2. **Use HTTPS in Production**
   - Run behind a reverse proxy (nginx, Caddy, Traefail)
   - Enable TLS/SSL with Let's Encrypt

3. **Restrict Network Access**
   - Use firewall rules to limit access
   - Only expose to trusted networks

4. **Rotate API Keys Regularly**
   - Change keys periodically
   - Use different keys for dev/staging/production

See [SECURITY.md](SECURITY.md) for comprehensive security guidelines.

## API Documentation

All authenticated endpoints require an API key via header or query parameter:

- Header: `X-API-Key: your-api-key`
- Query: `?key=your-api-key`

### Endpoints

#### `GET /status`

Health check endpoint (no authentication required).

**Response:**
```json
{
  "ok": true,
  "service": "satisfactory-bridge",
  "version": "1.0.0",
  "commands_queued": 0,
  "responses_count": 5,
  "uptime": "2h15m30s"
}
```

#### `POST /command`

Push a command to the queue for the game to execute.

**Request:**
```json
{
  "id": "optional-unique-id",
  "action": "set_standby",
  "target": "iron_smelter_01",
  "params": {
    "enabled": false
  }
}
```

**Response:**
```json
{
  "ok": true,
  "command_id": "20260213123045.123",
  "queued": 1
}
```

#### `GET /command`

Poll for the next command (FIFO). Returns and removes the oldest command from the queue.

**Response (with command):**
```json
{
  "ok": true,
  "command": {
    "id": "20260213123045.123",
    "action": "get_status",
    "target": "factory",
    "created_at": "2026-02-13T12:30:45.123Z"
  },
  "queued": 0
}
```

**Response (empty queue):**
```json
{
  "ok": true,
  "command": null,
  "queued": 0
}
```

#### `GET /queue`

View all pending commands without removing them (non-destructive).

**Response:**
```json
{
  "ok": true,
  "commands": [
    {
      "id": "123",
      "action": "toggle",
      "target": "constructor_01",
      "created_at": "2026-02-13T12:30:45.123Z"
    }
  ],
  "count": 1
}
```

#### `DELETE /queue`

Clear all pending commands.

**Response:**
```json
{
  "ok": true,
  "cleared": 5
}
```

#### `POST /response`

Game reports command execution result.

**Request:**
```json
{
  "command_id": "123",
  "status": "success",
  "data": {
    "machine_count": 42,
    "machines": [...]
  }
}
```

**Response:**
```json
{
  "ok": true
}
```

#### `GET /response`

Alternative response submission via GET (workaround for FicsIt-Networks POST crashes on Linux servers).

**Query Parameters:**
- `command_id` - The command ID
- `status` - Execution status (default: "ok")
- `data` - Response data (optional)

**Example:**
```
GET /response?command_id=123&status=success&data=Machine+started
```

#### `GET /responses`

Retrieve all responses (last 100).

**Response:**
```json
{
  "ok": true,
  "responses": [
    {
      "command_id": "123",
      "status": "success",
      "data": {"message": "pong"},
      "timestamp": "2026-02-13T12:30:50.123Z"
    }
  ]
}
```

## Usage Examples

### Example 1: Check Factory Status

```bash
# Push a status check command
curl -X POST http://localhost:8080/command \
  -H "X-API-Key: YOUR-API-KEY-HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "get_status"
  }'

# Game polls and executes command...

# Retrieve response
curl -H "X-API-Key: YOUR-API-KEY-HERE" \
  http://localhost:8080/responses
```

### Example 2: Toggle Machine

```bash
# Turn off a specific machine
curl -X POST http://localhost:8080/command \
  -H "X-API-Key: YOUR-API-KEY-HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "set_standby",
    "target": "iron_smelter_01",
    "params": {
      "enabled": true
    }
  }'
```

### Example 3: Clear Command Queue

```bash
# Clear all pending commands
curl -X DELETE http://localhost:8080/queue \
  -H "X-API-Key: YOUR-API-KEY-HERE"
```

## Lua Integration

### Available In-Game Commands

When using `ficsit/bridge_client.lua`:

| Action | Description | Parameters |
|--------|-------------|------------|
| `ping` | Test connectivity | None |
| `get_status` | Get all machine statuses | None |
| `list_machines` | List discovered machines | None |
| `toggle` | Toggle machine on/off | `target`: machine name |
| `set_standby` | Set machine standby state | `target`: machine name<br>`params.enabled`: boolean |
| `start_all` | Start all machines | None |
| `stop_all` | Stop all machines | None |

### Machine Naming

For easier control, nickname your machines in-game:

1. Look at a machine
2. Press **Middle Mouse Button**
3. Give it a descriptive name (e.g., `iron_smelter_01`)

Then reference it in commands:

```json
{
  "action": "toggle",
  "target": "iron_smelter_01"
}
```

## Development

### Project Structure

```
satisfactory-bridge/
├── main.go                    # Bridge server
├── parser/                    # Log parser
│   ├── main.go
│   └── go.mod
├── lua/                       # LEXIS factory control script
│   └── lexis-factory-control-v6.lua
├── ficsit/                    # FicsIt-Networks client
│   ├── bridge_client.lua
│   └── README.md
├── bridge.initd               # Alpine init script
├── go.mod                     # Go module definition
├── LICENSE                    # MIT License
├── CONTRIBUTING.md            # Contribution guidelines
├── SECURITY.md                # Security policy
└── README.md                  # This file
```

### Building from Source

```bash
# Build bridge server
go build -o bridge main.go

# Build with optimization
go build -ldflags="-s -w" -o bridge main.go

# Cross-compile for Linux (from macOS/Windows)
GOOS=linux GOARCH=amd64 go build -o bridge main.go
```

### Running Tests

```bash
# Test the bridge server
export BRIDGE_API_KEY="test-key"
./bridge &

# Run test commands
curl http://localhost:8080/status
curl -H "X-API-Key: test-key" http://localhost:8080/queue

# Stop the server
killall bridge
```

## Troubleshooting

### Bridge Won't Start

**Error**: `ERROR: BRIDGE_API_KEY environment variable is required`

**Solution**: Set the `BRIDGE_API_KEY` environment variable before starting:
```bash
export BRIDGE_API_KEY="your-secure-key"
./bridge
```

### Connection Timeouts from Game

**Symptoms**: FicsIt computer shows timeout errors

**Solutions**:
1. Verify bridge is running: `curl http://<bridge-ip>:8080/status`
2. Check firewall allows port 8080
3. Ensure correct IP address in Lua script
4. Verify API key matches in both bridge and Lua script

### "No Internet Card found" Error

**Solution**: Connect an Internet Card component to your FicsIt computer via the component network.

### Commands Not Executing

**Solutions**:
1. Check command queue: `curl -H "X-API-Key: YOUR-KEY" http://<bridge-ip>:8080/queue`
2. Verify Lua script is running in-game
3. Check bridge logs for errors
4. Ensure machines are connected to computer via network cables

### Machines Not Discovered

**Solutions**:
1. Connect machines to computer using **network cables**
2. Only production machines are discoverable (constructors, smelters, assemblers, etc.)
3. Check cables are properly connected to both machine and computer
4. Try restarting the Lua script

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally
5. Commit using conventional commits format
6. Push to your fork
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FicsIt-Networks](https://github.com/Panakotta00/FicsIt-Networks) - The mod that makes this all possible
- Satisfactory game by Coffee Stain Studios
- The Satisfactory modding community

## Support

- **Issues**: Report bugs or request features via [GitHub Issues](https://github.com/kushie/satisfactory-bridge/issues)
- **Security**: Report vulnerabilities privately - see [SECURITY.md](SECURITY.md)

---

**Made with ❤️ for factory automation enthusiasts**
