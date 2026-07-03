#!/bin/bash

# ==============================================================================
#   ZED PRO | Container Entrypoint Script
# ==============================================================================

# Set default credentials if not provided
export USERNAME=${USERNAME:-"admin"}
export PASSWORD=${PASSWORD:-"zed123"}
export PORT=${PORT:-"8080"}

# Format shell prompt with customized username
HOME_DIR="${HOME:-$PWD}"
echo "export PS1='\[\033[01;31m\]$USERNAME@zed-pro\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '" >> "$HOME_DIR/.bashrc"

# Run Zed Pro in auto-mode in the background
echo "❯ Launching VLESS Tunnel in TryCloudflare mode..."
bash ./zed.sh --auto &

# Start ttyd web terminal in the foreground
echo "❯ Starting Web Terminal on port $PORT..."
exec ttyd -p "$PORT" -c "$USERNAME:$PASSWORD" ./welcome.sh

