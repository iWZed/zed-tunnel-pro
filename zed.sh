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
    echo -e "${C}⚡ ZEDTUNNEL PRO ${N}• ${W}NETWORK TUNNEL AUTOMATION${N}\n"
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
HOME_DIR="${HOME:-$PWD}"
BIN_DIR="$HOME_DIR/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

XRAY_CONFIG_DIR="$HOME_DIR/.local/etc/xray"
XRAY_CONFIG="$XRAY_CONFIG_DIR/config.json"
VLESS_TXT="$HOME_DIR/vless.txt"
CF_CONFIG_DIR="$HOME_DIR/.cloudflared"
CF_CONF="$HOME_DIR/conf.yml"

XRAY_BIN="xray"
CLOUDFLARED_BIN="cloudflared"

if [ "$AUTO_MODE" = false ]; then
    # Check and install curl/jq if missing
    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        echo -e "${Y}[*] Installing Missing Dependencies (curl, jq)...${N}"
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq curl jq >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            apk add --no-cache curl jq >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y -q curl jq >/dev/null 2>&1
        fi
    fi
fi

# Resolve xray binary
if command -v xray &>/dev/null; then
    XRAY_BIN="xray"
elif [ -f "$BIN_DIR/xray" ]; then
    XRAY_BIN="$BIN_DIR/xray"
else
    if [ "$AUTO_MODE" = false ]; then
        echo -ne "${Y}[*] Installing Xray Core...${N}"
        if [ "$EUID" -ne 0 ] || ! command -v unzip &>/dev/null; then
            curl -L -s https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
            if command -v unzip &>/dev/null; then
                unzip -qo /tmp/xray.zip -d /tmp/xray_temp
                mv /tmp/xray_temp/xray "$BIN_DIR/xray"
                chmod +x "$BIN_DIR/xray"
                rm -rf /tmp/xray_temp
            else
                if command -v apt-get &>/dev/null; then
                    apt-get update -qq && apt-get install -y -qq unzip >/dev/null 2>&1
                    unzip -qo /tmp/xray.zip -d /tmp/xray_temp
                    mv /tmp/xray_temp/xray "$BIN_DIR/xray"
                    chmod +x "$BIN_DIR/xray"
                    rm -rf /tmp/xray_temp
                fi
            fi
            rm -f /tmp/xray.zip
            XRAY_BIN="$BIN_DIR/xray"
        else
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root >/dev/null 2>&1 &
            spinner $!
            XRAY_BIN="xray"
        fi
        echo -e " ${G}Done!${N}"
    else
        # Auto mode fallback
        curl -L -s https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
        if ! command -v unzip &>/dev/null && command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq unzip >/dev/null 2>&1
        fi
        if command -v unzip &>/dev/null; then
            unzip -qo /tmp/xray.zip -d /tmp/xray_temp
            mv /tmp/xray_temp/xray "$BIN_DIR/xray"
            chmod +x "$BIN_DIR/xray"
            rm -rf /tmp/xray_temp
            XRAY_BIN="$BIN_DIR/xray"
        fi
        rm -f /tmp/xray.zip
    fi
fi

# Resolve cloudflared binary
if command -v cloudflared &>/dev/null; then
    CLOUDFLARED_BIN="cloudflared"
elif [ -f "$BIN_DIR/cloudflared" ]; then
    CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
else
    if [ "$AUTO_MODE" = false ]; then
        echo -ne "${Y}[*] Downloading Cloudflared...${N}"
        curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$BIN_DIR/cloudflared" &
        spinner $!
        chmod +x "$BIN_DIR/cloudflared"
        CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
        echo -e " ${G}Done!${N}"
    else
        curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$BIN_DIR/cloudflared"
        chmod +x "$BIN_DIR/cloudflared"
        CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
    fi
fi

UUID=$(cat /proc/sys/kernel/random/uuid)
PORT=41054
mkdir -p "$XRAY_CONFIG_DIR"

# 2. XRAY CONFIGURATION
if [ "$AUTO_MODE" = false ]; then
    echo -e "${Y}[*] Configuring Xray (VLESS-WS)...${N}"
fi

cat > "$XRAY_CONFIG" << JSON
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
nohup "$XRAY_BIN" -config "$XRAY_CONFIG" >/dev/null 2>&1 &

# 3. TUNNEL MODE SELECTION
if [ "$AUTO_MODE" = true ]; then
    # In auto mode (like docker/railway), default to TUNNEL_MODE env var if set, otherwise 1 (TryCloudflare)
    mode="${TUNNEL_MODE:-1}"
else
    while true; do
        echo -e "\n${C}❯ Select Cloudflare Tunnel Mode:${N}"
        echo -e "  ${G}[1]${N} Free Cloudflare Tunnel (TryCloudflare - Temporary)"
        echo -e "  ${G}[2]${N} Personal Tunnel (Custom Domain - Requires Login/Token)"
        read -p "  👉 Select Option [1-2]: " mode_raw
        mode=$(echo "$mode_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
        
        if [ "$mode" = "1" ] || [ "$mode" = "2" ]; then
            break
        else
            echo -e "${R}✖ Invalid selection: '$mode_raw'. Please enter 1 or 2.${N}"
        fi
    done
fi

case "$mode" in
    1)
        if [ "$AUTO_MODE" = false ]; then
            print_header
            echo -e "${Y}[!] Launching Free Tunnel...${N}"
        fi
        
        # Kill previous cloudflared to avoid conflicts
        killall cloudflared 2>/dev/null || true
        nohup "$CLOUDFLARED_BIN" tunnel --url http://127.0.0.1:$PORT > /tmp/cf.log 2>&1 &
        tunnel_pid=$!
        
        if [ "$AUTO_MODE" = false ]; then
            echo -ne "${Y}[*] Fetching TryCloudflare Domain...${N}"
            sleep 8
        else
            # In auto mode, wait dynamically up to 30 seconds for the log to contain the domain
            retries=0
            while [ $retries -lt 30 ]; do
                CF_DOMAIN_TEMP=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cf.log | head -n1)
                if [ -n "$CF_DOMAIN_TEMP" ]; then
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
        if [ "$AUTO_MODE" = true ]; then
            if [ -n "$CF_TUNNEL_ID" ] && [ -n "$CF_TUNNEL_CREDENTIALS" ] && [ -n "$CF_DOMAIN" ]; then
                mkdir -p "$CF_CONFIG_DIR"
                echo "$CF_TUNNEL_CREDENTIALS" > "$CF_CONFIG_DIR/$CF_TUNNEL_ID.json"
                
                cat > "$CF_CONF" << CF
tunnel: $CF_TUNNEL_ID
credentials-file: $CF_CONFIG_DIR/$CF_TUNNEL_ID.json
ingress:
  - hostname: $CF_DOMAIN
    service: http://127.0.0.1:$PORT
  - service: http_status:443
CF
                killall cloudflared 2>/dev/null || true
                nohup "$CLOUDFLARED_BIN" tunnel --config "$CF_CONF" run > /tmp/cf.log 2>&1 &
                DOMAIN="$CF_DOMAIN"
            elif [ -n "$CF_TUNNEL_TOKEN" ] && [ -n "$CF_DOMAIN" ]; then
                killall cloudflared 2>/dev/null || true
                nohup "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" > /tmp/cf.log 2>&1 &
                DOMAIN="$CF_DOMAIN"
            else
                echo -e "${R}[!] Missing Cloudflare tunnel configuration in auto mode.${N}"
                exit 1
            fi
        else
            print_header
            # Check Cloudflare credentials
            if [ ! -f "$CF_CONFIG_DIR/cert.pem" ]; then
                echo -e "${Y}[*] Cloudflare authentication required. Please follow the login prompt:${N}"
                "$CLOUDFLARED_BIN" tunnel login
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
            "$CLOUDFLARED_BIN" tunnel create "$TNAME" >/dev/null 2>&1 &
            spinner $!
            
            TID=$("$CLOUDFLARED_BIN" tunnel list | grep "$TNAME" | awk '{print $1}' | head -n1)
            if [ -z "$TID" ]; then
                echo -e " ${R}FAILED${N}"
                echo -e "${R}[!] Failed to create tunnel.${N}"
                exit 1
            fi
            echo -e " ${G}Created! (ID: $TID)${N}"
            
            echo -ne "${Y}[*] Routing DNS for ${DOMAIN}...${N}"
            "$CLOUDFLARED_BIN" tunnel route dns -f "$TID" "$DOMAIN" >/dev/null 2>&1 &
            spinner $!
            
            if ! "$CLOUDFLARED_BIN" tunnel route dns -f "$TID" "$DOMAIN" >/dev/null 2>&1; then
                # Check if routing was already successful or retry
                true
            fi
            echo -e " ${G}Routed!${N}"
            
            # Configuration file generation
            cat > "$CF_CONF" << CF
tunnel: $TID
credentials-file: $CF_CONFIG_DIR/$TID.json
ingress:
  - hostname: $DOMAIN
    service: http://127.0.0.1:$PORT
  - service: http_status:443
CF
            
            # Start Tunnel
            killall cloudflared 2>/dev/null || true
            nohup "$CLOUDFLARED_BIN" tunnel --config "$CF_CONF" run >/dev/null 2>&1 &
        fi
        
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
    echo "$LINK" > "$VLESS_TXT"
    
    # Append VLESS banner display to .bashrc so it shows on every terminal login
    cat << EOF >> "$HOME_DIR/.bashrc"

echo -e "\n🎉 \${G}SUCCESS! Your VLESS connection link is ready:\${N}"
echo -e "\${W}\${LINK}\${N}\n"
echo -e "\${Y}❯ Note: Scan/use clean Cloudflare IPs (e.g. 188.114.96.6) for optimal routing.\${N}"
echo -e "\${Y}❯ Join our Telegram channel: \${C}https://t.me/iWZedLabs\${N}\n"
EOF

    # Print to Docker logs stdout
    echo -e "\n🎉 ${G}SUCCESS! Your VLESS connection link is ready:${N}"
    echo -e "${W}${LINK}${N}\n"
    echo -e "${Y}❯ Join our Telegram channel: ${C}https://t.me/iWZedLabs${N}\n"
else
    print_header
    echo -e "\n🎉 ${G}SUCCESS! Your VLESS connection link is ready:${N}"
    echo -e "${W}${LINK}${N}\n"
    echo -e "${Y}❯ Note: Scan/use clean Cloudflare IPs (e.g. 188.114.96.6) for optimal routing.${N}"
    echo -e "${Y}❯ Join our Telegram channel: ${C}https://t.me/iWZedLabs${N}"
    echo -e "${Y}❯ Background tunnel running. Logs saved to /tmp/cf.log${N}\n"
fi


