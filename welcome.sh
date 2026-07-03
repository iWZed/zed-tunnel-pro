#!/bin/bash

# Clear terminal screen
clear

# Load colors
C='\033[1;36m' # Cyan
G='\033[32m'   # Green
Y='\033[33m'   # Yellow
R='\033[31m'   # Red
W='\033[1;37m' # Bold White
N='\033[0m'    # Reset

# Show header
echo -e "${C}⚡ ZEDTUNNEL PRO ${N}• ${W}WEB TERMINAL PANEL${N}\n"

# Check if VLESS link is ready
HOME_DIR="${HOME:-$PWD}"
VLESS_TXT="$HOME_DIR/vless.txt"

if [ ! -f "$VLESS_TXT" ]; then
    echo -e "${Y}❯ Waiting for VLESS tunnel initialization and link generation...${N}"
    
    # Spinner loop until file is created
    spinstr='|/-\'
    while [ ! -f "$VLESS_TXT" ]; do
        temp=${spinstr#?}
        printf " [%c] Starting tunnel..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "                                      \r"
fi

# Link is ready, read it
LINK=$(cat "$VLESS_TXT")

echo -e "\n🎉 ${G}SUCCESS! Your VLESS connection link is ready:${N}"
echo -e "${W}${LINK}${N}\n"
echo -e "${Y}❯ Note: Scan/use clean Cloudflare IPs (e.g. 188.114.96.6) for optimal routing.${N}"
echo -e "${Y}❯ Join our Telegram channel: ${C}https://t.me/iWZedLabs${N}\n"

# Drop into normal interactive bash shell
exec /bin/bash
