package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

// Command represents an action to execute in Satisfactory
type Command struct {
	ID        string                 `json:"id"`
	Action    string                 `json:"action"`
	Target    string                 `json:"target,omitempty"`
	Params    map[string]interface{} `json:"params,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

// Response from the game
type GameResponse struct {
	CommandID string                 `json:"command_id"`
	Status    string                 `json:"status"`
	Data      map[string]interface{} `json:"data,omitempty"`
	Timestamp time.Time              `json:"timestamp"`
}

// Bridge holds the command queue and responses
type Bridge struct {
	mu        sync.RWMutex
	commands  []Command
	responses []GameResponse
	apiKey    string
}

func NewBridge(apiKey string) *Bridge {
	return &Bridge{
		commands:  make([]Command, 0),
		responses: make([]GameResponse, 0),
		apiKey:    apiKey,
	}
}

// Middleware for API key auth
func (b *Bridge) authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("X-API-Key")
		if key == "" {
			key = r.URL.Query().Get("key")
		}
		if b.apiKey != "" && key != b.apiKey {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

// POST /command - OpenClaw pushes a command
func (b *Bridge) handlePushCommand(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var cmd Command
	if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
		http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Generate ID if not provided
	if cmd.ID == "" {
		cmd.ID = time.Now().Format("20060102150405.000")
	}
	cmd.CreatedAt = time.Now()

	b.mu.Lock()
	b.commands = append(b.commands, cmd)
	b.mu.Unlock()

	log.Printf("[PUSH] Command queued: %s -> %s", cmd.Action, cmd.Target)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":         true,
		"command_id": cmd.ID,
		"queued":     len(b.commands),
	})
}

// GET /command - Game polls for commands (returns and removes oldest)
func (b *Bridge) handlePollCommand(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	b.mu.Lock()
	defer b.mu.Unlock()

	w.Header().Set("Content-Type", "application/json")

	if len(b.commands) == 0 {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"ok":      true,
			"command": nil,
			"queued":  0,
		})
		return
	}

	// Pop first command (FIFO)
	cmd := b.commands[0]
	b.commands = b.commands[1:]

	log.Printf("[POLL] Command sent to game: %s -> %s", cmd.Action, cmd.Target)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":      true,
		"command": cmd,
		"queued":  len(b.commands),
	})
}

// POST/GET /response - Game sends execution result
// POST: JSON body with command_id, status, data
// GET: Query params ?command_id=xxx&data=xxx (workaround for FicsIt crash on POST)
func (b *Bridge) handleResponse(w http.ResponseWriter, r *http.Request) {
	var resp GameResponse

	if r.Method == http.MethodPost {
		if err := json.NewDecoder(r.Body).Decode(&resp); err != nil {
			http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
			return
		}
	} else if r.Method == http.MethodGet {
		// GET workaround for FicsIt Networks POST crash on Linux servers
		resp.CommandID = r.URL.Query().Get("command_id")
		resp.Status = r.URL.Query().Get("status")
		if resp.Status == "" {
			resp.Status = "ok"
		}
		dataStr := r.URL.Query().Get("data")
		if dataStr != "" {
			resp.Data = map[string]interface{}{"raw": dataStr}
		}
	} else {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	resp.Timestamp = time.Now()

	b.mu.Lock()
	b.responses = append(b.responses, resp)
	// Keep only last 100 responses
	if len(b.responses) > 100 {
		b.responses = b.responses[len(b.responses)-100:]
	}
	b.mu.Unlock()

	log.Printf("[RESPONSE] From game: %s = %s", resp.CommandID, resp.Status)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"ok": true})
}

// GET /responses - OpenClaw checks responses
func (b *Bridge) handleGetResponses(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	b.mu.RLock()
	responses := make([]GameResponse, len(b.responses))
	copy(responses, b.responses)
	b.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":        true,
		"responses": responses,
	})
}

// GET /status - Health check
func (b *Bridge) handleStatus(w http.ResponseWriter, r *http.Request) {
	b.mu.RLock()
	queueLen := len(b.commands)
	respLen := len(b.responses)
	b.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":              true,
		"service":         "satisfactory-bridge",
		"version":         "1.0.0",
		"commands_queued": queueLen,
		"responses_count": respLen,
		"uptime":          time.Since(startTime).String(),
	})
}

// GET /queue - View queue without consuming
func (b *Bridge) handleViewQueue(w http.ResponseWriter, r *http.Request) {
	b.mu.RLock()
	commands := make([]Command, len(b.commands))
	copy(commands, b.commands)
	b.mu.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":       true,
		"commands": commands,
		"count":    len(commands),
	})
}

// DELETE /queue - Clear all pending commands
func (b *Bridge) handleClearQueue(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	b.mu.Lock()
	cleared := len(b.commands)
	b.commands = make([]Command, 0)
	b.mu.Unlock()

	log.Printf("[CLEAR] Queue cleared: %d commands removed", cleared)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":      true,
		"cleared": cleared,
	})
}

var startTime time.Time

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func maskAPIKey(key string) string {
	if len(key) <= 4 {
		return "****"
	}
	return "****" + key[len(key)-4:]
}

func main() {
	startTime = time.Now()

	// Config from environment or defaults
	apiKey := getEnv("BRIDGE_API_KEY", "")
	if apiKey == "" {
		log.Fatal("ERROR: BRIDGE_API_KEY environment variable is required")
	}
	port := getEnv("BRIDGE_PORT", ":8080")

	bridge := NewBridge(apiKey)

	// Routes
	http.HandleFunc("/command", bridge.authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			bridge.handlePushCommand(w, r)
		} else if r.Method == http.MethodGet {
			bridge.handlePollCommand(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}))
	http.HandleFunc("/response", bridge.authMiddleware(bridge.handleResponse))
	http.HandleFunc("/responses", bridge.authMiddleware(bridge.handleGetResponses))
	http.HandleFunc("/queue", bridge.authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			bridge.handleViewQueue(w, r)
		} else if r.Method == http.MethodDelete {
			bridge.handleClearQueue(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}))
	http.HandleFunc("/status", bridge.handleStatus) // No auth for health check

	log.Printf("Satisfactory Bridge Server")
	log.Printf("   Version: 1.0.0")
	log.Printf("   Port: %s", port)
	log.Printf("   API Key: %s", maskAPIKey(apiKey))
	log.Fatal(http.ListenAndServe(port, nil))
}
