#!/bin/bash

# ==============================================================================
#   ZEDTUNNEL PRO | Railway CLI Auto-Deployer
# ==============================================================================

# Exit on interrupt
trap 'echo -e "\n\033[31m[!] Process interrupted by user. Exiting...\033[0m"; exit 1' INT

# Ensure local Railway binary directory is in PATH
export PATH="$HOME/.railway/bin:$PATH"

# COLOR DEFINITIONS
C='\033[36m'   # Cyan
G='\033[32m'   # Green
Y='\033[33m'   # Yellow
R='\033[31m'   # Red
B='\033[1;34m' # Bold Blue
W='\033[1;37m' # Bold White
N='\033[0m'    # Reset

print_header() {
    clear
    echo -e "${C}┌──────────────────────────────────────────────────────────┐${N}"
    echo -e "${C}│${N}   🚀 ${W}Z E D T U N N E L   P R O${N}   |   ${C}R A I L W A Y   A U T O${N}  ${C}│${N}"
    echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"
}

print_header

# 1. CHECK RAILWAY CLI INSTALLATION
if ! command -v railway &> /dev/null; then
    echo -e "${Y}[*] Railway CLI is not installed in system PATH.${N}"
    echo -e "${Y}[*] Attempting automatic installation via official installer...${N}"
    curl -fsSL https://railway.app/install.sh | sh
    
    # Check again after install
    if ! command -v railway &> /dev/null; then
        echo -e "${R}[!] Installation failed or PATH is not configured.${N}"
        echo -e "${Y}[*] Please install it manually or check permissions:${N}"
        echo -e "    ${C}npm install -g @railway/cli${N} or ${C}curl -fsSL https://railway.app/install.sh | sh${N}"
        exit 1
    fi
    echo -e "${G}[+] Railway CLI installed successfully!${N}"
fi

# 2. CHECK AUTHENTICATION STATUS
echo -e "${Y}[*] Checking Railway credentials...${N}"
if ! railway status &>/dev/null; then
    echo -e "${Y}[*] Authentication required. Redirecting to login...${N}"
    railway login
    
    # Verify login again
    if ! railway status &>/dev/null; then
        echo -e "${R}[!] Authentication failed. Please log in manually using 'railway login'.${N}"
        exit 1
    fi
fi
echo -e "${G}[+] Authenticated successfully.${N}"

# 3. INITIALIZE / LINK PROJECT
if [ ! -d .railway ]; then
    echo -e "${Y}[*] Initializing new Railway project...${N}"
    echo -e "${C}┌── ACTION REQUIRED ───────────────────────────────────────┐${N}"
    echo -e "${C}│${N}  👉 Please choose ${G}Empty Project${N} when prompted.            ${C}│${N}"
    echo -e "${C}│${N}  👉 Set a name for your tunnel service (e.g. zed-tunnel). ${C}│${N}"
    echo -e "${C}└──────────────────────────────────────────────────────────┘${N}\n"
    railway init
    
    if [ ! -d .railway ]; then
        echo -e "${R}[!] Project initialization aborted.${N}"
        exit 1
    fi
else
    echo -e "${G}[+] Linked Railway project found.${N}"
fi

# 4. GENERATE PUBLIC DOMAIN FOR WEB TERMINAL
echo -e "${Y}[*] Setting up network domain...${N}"
railway domain >/dev/null 2>&1 || true

# Fetch domain name
DOMAIN_NAME=$(railway domain list 2>/dev/null | grep -oE '[a-zA-Z0-9.-]+\.up\.railway\.app' | head -n1)

# 5. DEPLOY TO RAILWAY
echo -e "${Y}[*] Compiling and deploying container...${N}"
railway up --ci

if [ $? -ne 0 ]; then
    echo -e "${R}[!] Deployment failed.${N}"
    exit 1
fi
echo -e "${G}[+] Container compiled and deployed!${N}"

# 6. SCRAPE VLESS CONNECTION LINK
echo -e "${Y}[*] Waiting for container boot & VLESS link generation (takes ~15s)...${N}"
sleep 15

VLESS_LINK=""
retries=0
max_retries=20

while [ $retries -lt $max_retries ]; do
    # Fetch logs and grep the VLESS protocol link
    LOGS=$(railway logs 2>/dev/null)
    VLESS_LINK=$(echo "$LOGS" | grep -oE 'vless://[a-zA-Z0-9?&=-_%#.]+' | head -n1)
    
    if [ -n "$VLESS_LINK" ]; then
        break
    fi
    
    printf "${Y}.${N}"
    sleep 3
    retries=$((retries+1))
done
echo ""

# 7. DISPLAY FINAL OUTPUT BANNERS
print_header
echo -e "\n${C}┌──────────────────────────────────────────────────────────┐${N}"
echo -e "${C}│${N}   🎉 ${G}SUCCESS! Your ZedTunnel Pro is running on Railway. ${N}   ${C}│${N}"
echo -e "${C}└──────────────────────────────────────────────────────────┘${N}"

if [ -n "$VLESS_LINK" ]; then
    echo -e "\n${W}🔗 YOUR VLESS CONNECTION LINK:${N}"
    echo -e "${C}${VLESS_LINK}${N}"
    echo -e "${C}────────────────────────────────────────────────────────────${N}"
else
    echo -e "\n${R}[!] Could not automatically fetch the link from logs.${N}"
    echo -e "${Y}[*] Please view service logs manually to copy the link:${N}"
    echo -e "    ${C}railway logs${N}"
    echo -e "${C}────────────────────────────────────────────────────────────${N}"
fi

if [ -n "$DOMAIN_NAME" ]; then
    echo -e "\n${W}🌐 WEB TERMINAL CONTROL PANEL:${N}"
    echo -e "   URL:      ${C}https://${DOMAIN_NAME}${N}"
    echo -e "   Username: ${Y}admin${N}"
    echo -e "   Password: ${Y}zed123${N}"
    echo -e "${C}────────────────────────────────────────────────────────────${N}"
fi

echo -e "${Y}[*] The tunnel runs 24/7 in the background on Railway.${N}\n"
