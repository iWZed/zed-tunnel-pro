#!/bin/bash

# ==============================================================================
#   ZED PRO | Network Tunnel Automation Script
#   Automated VLESS + WebSocket over Cloudflare Tunnel (TryCloudflare / Custom)
# ==============================================================================

# Exit on interrupt
trap 'echo -e "\n\033[31m[!] Process interrupted by user. Exiting...\033[0m"; exit 1' INT

# COLOR DEFINITIONS
C='\033[36m'   # Cyan
G='\033[32m'   # Green
Y='\033[33m'   # Yellow
R='\033[31m'   # Red
B='\033[1;34m' # Bold Blue
W='\033[1;37m' # Bold White
N='\033[0m'    # Reset

# UI FUNCTIONS
print_header() {
    clear
    echo -e "${C}┌──────────────────────────────────────────────────────────┐${N}"
    echo -e "${C}│${N}   🚀 ${W}Z E D T U N N E L   P R O${N}   |   ${C}N E T W O R K   A U T O${N}   ${C}│${N}"
    echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"
}

# Optimized spinner using kill -0 instead of heavy ps/grep pipe
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check if auto mode is enabled
AUTO_MODE=false
if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
    AUTO_MODE=true
fi

if [ "$AUTO_MODE" = false ]; then
    print_header
fi

# 1. SETUP & ENVIRONMENT INITIALIZATION
if [ "$AUTO_MODE" = false ]; then
    echo -e "${Y}[*] Initializing Environment & Dependencies...${N}"
    apt-get update -qq && apt-get install -y -qq curl jq >/dev/null 2>&1
fi

# Install Xray if not exists
if [ ! -f /usr/local/bin/xray ]; then
    if [ "$AUTO_MODE" = false ]; then
        echo -ne "${Y}[*] Installing Xray Core...${N}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root >/dev/null 2>&1 &
        spinner $!
        echo -e " ${G}Done!${N}"
    else
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root >/dev/null 2>&1
    fi
fi

# Install Cloudflared if not exists
if [ ! -f /root/cloudflared ]; then
    if [ "$AUTO_MODE" = false ]; then
        echo -ne "${Y}[*] Downloading Cloudflared...${N}"
        curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /root/cloudflared &
        spinner $!
        chmod +x /root/cloudflared
        echo -e " ${G}Done!${N}"
    else
        curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /root/cloudflared
        chmod +x /root/cloudflared
    fi
fi

UUID=$(cat /proc/sys/kernel/random/uuid)
PORT=41054
mkdir -p /usr/local/etc/xray

# 2. XRAY CONFIGURATION
if [ "$AUTO_MODE" = false ]; then
    echo -e "${Y}[*] Configuring Xray (VLESS-WS)...${N}"
fi

cat > /usr/local/etc/xray/config.json << JSON
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
JSON

# Restart Xray service
killall xray 2>/dev/null || true
nohup /usr/local/bin/xray -config /usr/local/etc/xray/config.json >/dev/null 2>&1 &

# 3. TUNNEL MODE SELECTION
if [ "$AUTO_MODE" = true ]; then
    mode="1"
else
    echo -e "\n${W}┌── SELECT CLOUDFLARE TUNNEL MODE ─────────────────────────┐${N}"
    echo -e "${W}│${N}  ${G}1)${N} Free Cloudflare Tunnel (TryCloudflare - Temporary)    ${W}│${N}"
    echo -e "${W}│${N}  ${G}2)${N} Personal Tunnel (Custom Domain - Requires Login)      ${W}│${N}"
    echo -e "${W}└──────────────────────────────────────────────────────────┘${N}"
    read -p " 👉 Select Option [1-2]: " mode_raw
    mode=$(echo "$mode_raw" | tr '۰۱۲۳۴۵۶۷۸۹' '0123456789')
fi

case "$mode" in
    1)
        if [ "$AUTO_MODE" = false ]; then
            print_header
            echo -e "${Y}[!] Launching Free Tunnel...${N}"
        fi
        
        # Kill previous cloudflared to avoid conflicts
        killall cloudflared 2>/dev/null || true
        nohup /root/cloudflared tunnel --url http://127.0.0.1:$PORT > /tmp/cf.log 2>&1 &
        tunnel_pid=$!
        
        if [ "$AUTO_MODE" = false ]; then
            echo -ne "${Y}[*] Fetching TryCloudflare Domain...${N}"
            sleep 8
        else
            # In auto mode, wait dynamically up to 30 seconds for the log to contain the domain
            retries=0
            while [ $retries -lt 30 ]; do
                CF_DOMAIN=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf.log | head -n1)
                if [ -n "$CF_DOMAIN" ]; then
                    break
                fi
                sleep 1
                retries=$((retries+1))
            done
        fi
        
        # Double check domain
        CF_DOMAIN=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf.log | head -n1)
        
        if [ -z "$CF_DOMAIN" ]; then
            if [ "$AUTO_MODE" = false ]; then
                echo -e " ${R}FAILED${N}"
                echo -e "${R}[!] Could not retrieve tunnel domain. Check /tmp/cf.log for details.${N}"
            fi
            kill "$tunnel_pid" 2>/dev/null || true
            exit 1
        fi
        
        if [ "$AUTO_MODE" = false ]; then
            echo -e " ${G}Done!${N}"
        fi
        
        LINK="vless://${UUID}@188.114.96.6:443?encryption=none&security=tls&sni=${CF_DOMAIN}&fp=random&alpn=http%2F1.1&type=ws&host=${CF_DOMAIN}&path=%2F#zed-Free"
        ;;
    2)
        print_header
        # Check Cloudflare credentials
        if [ ! -f /root/.cloudflared/cert.pem ]; then
            echo -e "${Y}[*] Cloudflare authentication required. Please follow the login prompt:${N}"
            /root/cloudflared tunnel login
        fi
        
        echo -e "\n${C}>>> IMPORTANT: Enter your EXACT Subdomain (e.g. vip.yourdomain.com) <<<${N}"
        read -p " Domain: " raw_domain
        DOMAIN=$(echo "$raw_domain" | xargs)
        
        if [ -z "$DOMAIN" ]; then
            echo -e "${R}[!] Domain cannot be empty.${N}"
            exit 1
        fi
        
        TNAME="zed-$(date +%s)"
        echo -ne "${Y}[*] Creating Tunnel (${TNAME})...${N}"
        /root/cloudflared tunnel create "$TNAME" >/dev/null 2>&1 &
        spinner $!
        
        TID=$(/root/cloudflared tunnel list | grep "$TNAME" | awk '{print $1}' | head -n1)
        if [ -z "$TID" ]; then
            echo -e " ${R}FAILED${N}"
            echo -e "${R}[!] Failed to create tunnel.${N}"
            exit 1
        fi
        echo -e " ${G}Created! (ID: $TID)${N}"
        
        echo -ne "${Y}[*] Routing DNS for ${DOMAIN}...${N}"
        /root/cloudflared tunnel route dns -f "$TID" "$DOMAIN" >/dev/null 2>&1 &
        spinner $!
        
        if ! /root/cloudflared tunnel route dns -f "$TID" "$DOMAIN" >/dev/null 2>&1; then
            # Check if routing was already successful or retry
            true
        fi
        echo -e " ${G}Routed!${N}"
        
        # Configuration file generation
        cat > /root/conf.yml << CF
tunnel: $TID
credentials-file: /root/.cloudflared/$TID.json
ingress:
  - hostname: $DOMAIN
    service: http://127.0.0.1:$PORT
  - service: http_status:443
CF
        
        # Start Tunnel
        killall cloudflared 2>/dev/null || true
        nohup /root/cloudflared tunnel --config /root/conf.yml run >/dev/null 2>&1 &
        
        LINK="vless://${UUID}@188.114.96.6:443?encryption=none&security=tls&sni=$DOMAIN&fp=random&alpn=http%2F1.1&type=ws&host=$DOMAIN&path=%2F#zed-Personal"
        ;;
    *)
        echo -e "${R}[!] Invalid selection: $mode_raw${N}"
        exit 1
        ;;
esac

# 4. FINAL OUTPUT DISPLAY
if [ "$AUTO_MODE" = true ]; then
    # Save to persistent file
    echo "$LINK" > /root/vless.txt
    
    # Append VLESS banner display to .bashrc so it shows on every terminal login
    cat << EOF >> /root/.bashrc

echo -e "${C}┌──────────────────────────────────────────────────────────┐${N}"
echo -e "${C}│${N}   🎉 ${G}SUCCESS! Your VLESS connection link is ready:      ${C}│${N}"
echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"
echo -e "${W}${LINK}${N}"
echo -e "${C}────────────────────────────────────────────────────────────${N}"
echo -e "${Y}[*] Note: Scan/use clean Cloudflare IPs (e.g. 188.114.96.6) for optimal routing.${N}\n"
EOF

    # Print to Docker logs stdout
    echo -e "\n${C}┌──────────────────────────────────────────────────────────┐${N}"
    echo -e "${C}│${N}   🎉 ${G}SUCCESS! Your VLESS connection link is ready:      ${C}│${N}"
    echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"
    echo -e "${W}${LINK}${N}"
    echo -e "${C}────────────────────────────────────────────────────────────${N}\n"
else
    print_header
    echo -e "\n${C}┌──────────────────────────────────────────────────────────┐${N}"
    echo -e "${C}│${N}   🎉 ${G}SUCCESS! Your VLESS connection link is ready:      ${C}│${N}"
    echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"
    echo -e "${W}${LINK}${N}"
    echo -e "${C}────────────────────────────────────────────────────────────${N}"
    echo -e "${Y}[*] Note: Scan/use clean Cloudflare IPs (e.g. 188.114.96.6) for optimal routing.${N}"
    echo -e "${Y}[*] Background tunnel running. Logs saved to /tmp/cf.log${N}\n"
fi


