# 🐧 NanoRuntime CLI - Linux Desktop Setup Guide

## ✅ What's New

El módulo terminal ha sido adaptado para **Linux Desktop** con las siguientes mejoras:

### Cross-Platform Features
- ✅ **Paths multiplataforma** - Manejo automático de rutas en Linux y Windows
- ✅ **Home directory detection** - Sessiones en `~/.nano-sessions` en Linux
- ✅ **XDG Base Directory** - Soporte para estándares Linux (`~/.config`, `~/.cache`)
- ✅ **Desktop detection** - Auto-detecta DISPLAY/WAYLAND_DISPLAY
- ✅ **Root check** - Detección de permisos para optimizaciones
- ✅ **Input validation** - Validación de parámetros (temperatura, puerto)
- ✅ **Configurable binding** - `--bind` para especificar dirección de escucha

---

## 📋 Installation (Linux)

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y build-essential rustup

# Fedora/RHEL
sudo dnf install -y gcc rustup

# Arch
sudo pacman -S rust base-devel
```

### Build from Source
```bash
cd nanortime-cli
cargo build --release
```

El binario compilado estará en: `target/release/nanortime`

### Install Globally (Optional)
```bash
# Copy to system path
sudo cp target/release/nanortime /usr/local/bin/

# Verify installation
nanortime --version
```

---

## 🚀 Usage on Linux

### Interactive Chat (Recommended for Desktop)
```bash
# Simplest: auto-detect home directory
nanortime

# With custom config
nanortime --config ~/.config/nano-ai/config.json

# With custom session directory
nanortime --session-dir ~/.local/share/nano-ai
```

### Single Prompt
```bash
# Quick query
nanortime --prompt "¿Cuál es la capital de Francia?"

# With model override
nanortime --prompt "..." --model /path/to/model.gguf

# With temperature control
nanortime --prompt "..." --temperature 0.7
```

### Server Mode (For Web/Mobile)
```bash
# Desktop only (localhost)
nanortime --server --port 8080

# Accessible from network (need to be explicit)
nanortime --server --port 8080 --bind 0.0.0.0

# With env var override
NANO_BIND_ADDR=192.168.1.100 nanortime --server --port 8080
```

### Performance Options
```bash
# Pre-load model to page cache (faster prompt processing)
nanortime --preload --prompt "..."

# Save/restore KV cache for faster subsequent runs
nanortime --save-session --prompt "..."
nanortime --load-session --prompt "..."  # ~0.5s vs 5s without cache

# Hybrid routing (auto-select model by complexity)
nanortime --hybrid --prompt "..."

# Response caching
nanortime --cache --prompt "..."

# Natural stop detection (better for formatting)
nanortime --natural-stops --prompt "..."
```

---

## 📂 Directory Structure (Linux)

After first run, the following directories are created:

```
~/.nano-sessions/
├── session_auto.nano      # KV cache (binary)
└── history.json          # Chat history

~/.config/nano-ai/
└── nano.manifest.json    # Configuration file (optional)

~/.cache/nano-ai/
└── responses.json        # Response cache (optional)
```

**Note:** On Windows, these default to:
- `.nano-sessions/` (current directory)
- `data/history.json`

---

## 🔧 Configuration

Create `~/.config/nano-ai/nano.manifest.json`:

```json
{
  "local_model": {
    "path": "/path/to/model.gguf",
    "threads": 4,
    "context_length": 2048
  },
  "generation": {
    "temperature": 0.7,
    "max_tokens": 2048
  },
  "hybrid_routing": {
    "edge_only": false,
    "fast_model": "phi-2-q4.gguf",
    "expert_model": "qwen2.5-7b-q4.gguf"
  },
  "tools": {
    "auto_discover": true,
    "search_paths": ["./tools"]
  }
}
```

---

## 🛡️ Security & Permissions

### CORS (Recommended)
```bash
# Default: insecure (allows any origin)
nanortime --server

# Secure: specify origin
export NANO_CORS_ORIGIN="https://myapp.com"
nanortime --server

# Localhost only (no env var needed)
nanortime --server --bind 127.0.0.1
```

### Ports (Linux)
```bash
# Ports < 1024 require root
sudo nanortime --server --port 80  # ⚠️ Not recommended

# Use high ports (user can bind)
nanortime --server --port 8080  # ✅ Recommended
```

### System Tuning (Advanced)
```bash
# Enable optimizations (requires root)
sudo nanortime --tune-system --prompt "..."

# Sets:
# - vm.page-cluster=0 (faster I/O)
# - vm.swappiness=10 (prefer RAM)
# - /proc/sys/vm/drop_caches optimization
```

---

## 📊 Logging & Debugging

### Verbosity Levels
```bash
# Default (info level)
nanortime --prompt "..."

# Detailed debug info
nanortime --prompt "..." --log-level debug

# Maximum verbosity
nanortime --prompt "..." --log-level trace

# Quiet mode (no llama.cpp output)
nanortime --prompt "..." --quiet
```

### Output Streams

- **stdout**: Generated response text (capturable by pipes)
- **stderr**: Metrics and logs (doesn't interfere with output)

Example:
```bash
# Capture response + metrics separately
nanortime --prompt "Hello" > response.txt 2> metrics.txt
```

Metrics format:
```
[METRICS] tokens=125 elapsed_ms=1250 tok_s=100.00 tier=local confidence=0.950
```

---

## 🖥️ Desktop Integration (Optional)

### Create Desktop Shortcut
```bash
cat > ~/.local/share/applications/nanortime.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NanoAI Terminal
Exec=/usr/local/bin/nanortime
Icon=utilities-terminal
Terminal=true
Categories=Utility;
EOF
```

Then run:
```bash
update-desktop-database ~/.local/share/applications
```

Now "NanoAI Terminal" will appear in your application menu.

### Run in Terminal Emulator
```bash
# Create wrapper script
cat > ~/bin/nanortime-gui << 'EOF'
#!/bin/bash
exec x-terminal-emulator -e nanortime
EOF

chmod +x ~/bin/nanortime-gui
```

---

## 🔌 API Usage (Server Mode)

### SSE Streaming (Compatible with llama.cpp)
```bash
curl -X POST http://localhost:8080/completion \
  -H "Content-Type: application/json" \
  -d '{"prompt":"¿Hola?","n_predict":512}'
```

Response:
```
data: {"content":"Hola","stop":false}
data: {"content":" ","stop":false}
data: {"content":"¿Cómo","stop":false}
...
data: {"content":"","stop":true}
```

### JSON API (Legacy)
```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt":"¿Hola?","max_tokens":150}'
```

Response:
```json
{
  "response": "¡Hola! ¿Cómo estás?",
  "tier": "local",
  "confidence": 0.95
}
```

### Health Check
```bash
curl http://localhost:8080/api/status
```

Response:
```json
{
  "status": "running",
  "tier": "local",
  "message": "NanoAI HTTP+SSE server active"
}
```

---

## 🐛 Troubleshooting

### Issue: "Permission denied" when saving session
**Solution:** Session directory doesn't exist or no write permissions
```bash
mkdir -p ~/.nano-sessions
chmod 700 ~/.nano-sessions
```

### Issue: "Cannot bind to port 8080"
**Solution:** Port in use or insufficient privileges
```bash
# Check which process uses port
sudo lsof -i :8080

# Use different port
nanortime --server --port 8081
```

### Issue: "Model file not found"
**Solution:** Absolute path required in config
```bash
# BAD
"path": "models/model.gguf"

# GOOD
"path": "/home/user/models/model.gguf"
```

### Issue: Poor performance on startup
**Solution:** Use model preloading
```bash
# First run (slow, pre-loads to page cache)
nanortime --preload --prompt "test"

# Subsequent runs (fast from cache)
nanortime --prompt "test"
```

### Issue: Session not restoring
**Solution:** Make sure to use both flags together
```bash
# FIRST RUN: Save session
nanortime --save-session --prompt "..."

# SECOND RUN: Load session
nanortime --load-session --prompt "..."
```

---

## 🚨 Known Limitations (Linux)

1. **No async server** - Current implementation uses thread-per-connection (max ~1000 concurrent)
   - *Workaround:* Use reverse proxy (nginx) for load distribution

2. **No rate limiting** - Server accepts unlimited requests
   - *Workaround:* Configure firewall rules or use systemd-nspawn

3. **CORS default insecure** - Default `*` allows any origin
   - *Recommended:* Use `NANO_CORS_ORIGIN` env var

4. **No TLS/SSL support** - HTTP only
   - *Workaround:* Use reverse proxy (nginx with SSL)

---

## 📝 Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `NANO_BIND_ADDR` | Server bind address | `NANO_BIND_ADDR=0.0.0.0` |
| `NANO_CORS_ORIGIN` | CORS origin for web | `NANO_CORS_ORIGIN=https://myapp.com` |
| `RUST_LOG` | Log level override | `RUST_LOG=debug` |
| `RUST_BACKTRACE` | Enable backtraces | `RUST_BACKTRACE=1` |

Example:
```bash
RUST_LOG=debug NANO_BIND_ADDR=192.168.1.100 nanortime --server
```

---

## 🤝 Contributing

To report issues specific to Linux:
1. Run with `--log-level trace`
2. Include OS info: `uname -a`
3. Include Rust version: `rustc --version`
4. Share the full error message and context

---

## 📞 Support

- **GitHub Issues:** [Report bugs](https://github.com/emmahiguita/NanoRuntime/issues)
- **Documentation:** See `README.md` in parent directory
- **API Docs:** See `server.rs` for HTTP API details

---

**Last Updated:** 2026-08-09  
**Version:** 0.1.0
