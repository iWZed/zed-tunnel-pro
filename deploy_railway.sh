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
    echo -e "${C}⚡ ZEDTUNNEL PRO ${N}• ${W}RAILWAY AUTOMATION TOOL${N}\n"
}

print_header

# 1. CHECK RAILWAY CLI INSTALLATION
if ! command -v railway &> /dev/null; then
    echo -e "${Y}❯ Railway CLI is not installed in system PATH.${N}"
    echo -e "${Y}❯ Attempting automatic installation via official installer...${N}"
    curl -fsSL https://railway.app/install.sh | sh
    
    # Check again after install
    if ! command -v railway &> /dev/null; then
        echo -e "${R}✖ Installation failed or PATH is not configured.${N}"
        echo -e "${Y}❯ Please install it manually or check permissions:${N}"
        echo -e "    ${C}npm install -g @railway/cli${N} or ${C}curl -fsSL https://railway.app/install.sh | sh${N}"
        exit 1
    fi
    echo -e "${G}✔ Railway CLI installed successfully!${N}"
fi

# 2. CHECK AUTHENTICATION STATUS
echo -e "${Y}❯ Checking Railway credentials...${N}"
USER_INFO=$(railway whoami 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$USER_INFO" ]; then
    echo -e "${G}✔ Active Account: ${W}${USER_INFO}${N}"
    echo -e "\n${C}❯ Account Action:${N}"
    echo -e "  ${G}[y]${N} Continue with this account"
    echo -e "  ${R}[n]${N} Log out and switch accounts"
    read -p "  👉 Choice [y/n]: " auth_opt
    
    if [[ "$auth_opt" =~ ^[nNfF] ]] || [ "$auth_opt" = "logout" ]; then
        echo -e "${Y}❯ Logging out...${N}"
        railway logout >/dev/null 2>&1 || true
        USER_INFO=""
    fi
fi

if [ -z "$USER_INFO" ]; then
    echo -e "${Y}❯ Starting Railway login process...${N}"
    railway login
    
    # Verify login again
    if ! railway whoami &>/dev/null; then
        echo -e "${R}✖ Authentication failed. Please log in manually using 'railway login'.${N}"
        exit 1
    fi
fi
echo -e "${G}✔ Authenticated successfully.${N}"

# 3. INITIALIZE / LINK PROJECT
if [ ! -d .railway ]; then
    echo -e "${Y}❯ Initializing new Railway project...${N}"
    echo -e "\n${Y}⚠ ACTION REQUIRED:${N}"
    echo -e "  1. Select ${G}Empty Project${N} when prompted."
    echo -e "  2. Name your service (e.g., ${C}zed-tunnel${N}).\n"
    railway init
    
    if [ ! -d .railway ]; then
        echo -e "${R}✖ Project initialization aborted.${N}"
        exit 1
    fi
else
    echo -e "${G}✔ Linked Railway project found.${N}"
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
echo -e "\n🎉 ${G}SUCCESS! Your ZedTunnel Pro is running on Railway.${N}\n"

if [ -n "$VLESS_LINK" ]; then
    echo -e "${W}🔗 YOUR VLESS CONNECTION LINK:${N}"
    echo -e "${C}${VLESS_LINK}${N}\n"
else
    echo -e "${R}✖ Could not automatically fetch the link from logs.${N}"
    echo -e "${Y}❯ Please view service logs manually to copy the link:${N}"
    echo -e "    ${C}railway logs${N}\n"
fi

if [ -n "$DOMAIN_NAME" ]; then
    echo -e "${W}🌐 WEB TERMINAL CONTROL PANEL:${N}"
    echo -e "   URL:      ${C}https://${DOMAIN_NAME}${N}"
    echo -e "   Username: ${Y}admin${N}"
    echo -e "   Password: ${Y}zed123${N}\n"
fi

echo -e "${Y}❯ The tunnel runs 24/7 in the background on Railway.${N}\n"
