# Satisfactory Bridge — Rebuild Plan 🏗️

## État actuel (17 Feb 2026)

### ✅ Ce qui marche
- **Bridge Go server** — tourne sur Alpine LXC, accessible via `YOUR-BRIDGE-URL`
- **API REST** — endpoints `/command`, `/response`, `/responses`, `/queue`, `/status` OK
- **Uptime** — 140h+ stable

### ❌ Ce qui ne marche pas
- **Parsing de saves** — les parsers Python/Go ne fonctionnent plus (format save changé ?)
- **Connexion in-game** — Lua script v7.2 ne communique plus correctement avec le bridge
- **LAN access** — YOUR-LXC-IP:8080 timeout (seulement accessible via reverse proxy)

### ⚠️ Problèmes connus
- FicsIt Networks: POST crash sur serveurs Linux → workaround GET existe déjà
- Nitroserv: permissions mods bloquées, email envoyé sans réponse
- Lua parsing: regex-based, fragile, hardcoded command list

---

## Plan de reconstruction — Phase par Phase

### Phase 1: Diagnostic & Connectivité 🔌
**Objectif:** Vérifier que le bridge est joignable depuis le jeu

**Étapes:**
1. Vérifier LXC Alpine (YOUR-LXC-IP) — est-ce qu'il tourne encore ?
2. Tester le bridge directement: `curl http://YOUR-LXC-IP:8080/status`
3. Tester via reverse proxy: `curl https://YOUR-BRIDGE-URL/status`
4. Vérifier la config NPM (Nginx Proxy Manager) pour YOUR-BRIDGE-URL
5. Depuis le jeu: tester si FicsIt Networks peut atteindre YOUR-BRIDGE-URL

**Livrable:** Bridge accessible et confirmé joignable depuis le jeu

### Phase 2: Lua Client Minimal 🎮
**Objectif:** Un script Lua qui fait UNE chose: ping-pong avec le bridge

**Script minimal (bridge_minimal.lua):**
```lua
-- Satisfactory Bridge - Minimal Test
-- Step 1: Just prove connectivity works

local inet = computer.getPCIDevices(classes.FINInternetCard)[1]
if not inet then
    print("ERROR: No Internet Card found!")
    return
end

local BRIDGE = "https://YOUR-BRIDGE-URL"
local API_KEY = "YOUR-API-KEY-HERE"

print("[Bridge] Testing connection...")

-- Test 1: Can we reach the bridge?
local req = inet:request(BRIDGE .. "/status", "GET", "", "text/plain")
local code, data = req:await()
print("[Bridge] Status response: " .. tostring(data))

-- Test 2: Send a ping response
local url = BRIDGE .. "/response?key=" .. API_KEY 
    .. "&command_id=test-ping"
    .. "&data=PONG-from-game"
local req2 = inet:request(url, "GET", "", "text/plain")
local code2, data2 = req2:await()
print("[Bridge] Ping sent! Response: " .. tostring(data2))

print("[Bridge] ✅ Connection test complete!")
```

**Livrable:** Confirmation que le jeu peut parler au bridge

### Phase 3: Command Loop Propre 🔄
**Objectif:** Boucle de polling fiable avec parsing JSON correct

**Améliorations:**
- Utiliser un vrai parser JSON (pas des regex)
- Gestion d'erreurs propre
- Timeout handling
- Reconnection automatique

### Phase 4: Save Parser v2 📊
**Objectif:** Parser qui fonctionne avec le format save actuel

**Approche:**
- Identifier la version du format save actuel
- Tester avec un fichier save récent
- Parser minimal: juste les stats de base (buildings count, power, machines)

### Phase 5: Commandes avancées ⚡
**Objectif:** Contrôle réel de la factory

**Commandes:**
- `status` — stats globales (machines, power, production)
- `machines` — liste des machines avec état (on/off/standby)
- `toggle <name>` — allumer/éteindre une machine
- `power` — stats de consommation/production électrique
- `inventory <machine>` — contenu des inventaires

### Phase 6: Dashboard & Monitoring 📈
**Objectif:** Visualisation en temps réel

- Endpoint `/factory/stats` sur le bridge
- Intégration avec le trading dashboard existant ou nouveau dashboard
- Métriques Satisfactory en temps réel

---

## Questions à résoudre avant de commencer

1. **Nitroserv mods** — Les mods FicsIt Networks sont-ils installés et fonctionnels ?
2. **Version Satisfactory** — Quelle version exacte du jeu ?
3. **Fichier save** — Peux-tu m'envoyer un save récent pour tester le parser ?
4. **Accès jeu** — Peux-tu lancer le jeu et tester un script Lua maintenant ?

---

## Architecture cible

```
┌──────────┐     HTTPS      ┌─────────────┐     HTTP       ┌──────────┐
│  Lexis   │ ──────────────→│   NPM Proxy  │──────────────→│  Bridge  │
│ (OpenClaw)│←──────────────│bridge.kushie  │←──────────────│  Go LXC  │
└──────────┘                └─────────────┘                └──────────┘
                                                                ↕
                                                          ┌──────────┐
                                                          │Satisfactory│
                                                          │FicsIt Lua │
                                                          └──────────┘
```

*Créé le 17 Feb 2026 — Lexis 🦊*
