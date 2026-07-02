#!/bin/bash

# ==============================================================================
#   ZEDTUNNEL PRO | Railway CLI Auto-Deployer
# ==============================================================================

# Exit on interrupt
trap 'echo -e "\n\033[31m[!] Process interrupted by user. Exiting...\033[0m"; exit 1' INT

# COLOR DEFINITIONS
C='\033[36m'   # Cyan
G='\033[32m'   # Green
Y='\033[33m'   # Yellow
R='\033[31m'   # Red
B='\033[1;34m' # Bold Blue
N='\033[0m'    # Reset

print_header() {
    clear
    echo -e "${B}====================================================${N}"
    echo -e "   ${C}Z E D T U N N E L   |   R A I L W A Y   A U T O${N}"
    echo -e "${B}====================================================${N}"
}

print_header

# 1. CHECK RAILWAY CLI INSTALLATION
if ! command -v railway &> /dev/null; then
    echo -e "${Y}[*] Railway CLI is not installed.${N}"
    echo -e "${Y}[*] Installing Railway CLI via curl (requires sudo)...${N}"
    curl -fsSL https://railway.app/install.sh | sh
    
    if ! command -v railway &> /dev/null; then
        echo -e "${R}[!] Installation failed. Please install Railway CLI manually:${N}"
        echo -e "${C}npm install -g @railway/cli${N}  or  ${C}curl -fsSL https://railway.app/install.sh | sh${N}"
        exit 1
    fi
    echo -e " ${G}Railway CLI installed successfully!${N}"
fi

# 2. CHECK AUTHENTICATION STATUS
echo -e "${Y}[*] Verifying Railway authentication...${N}"
if ! railway status &>/dev/null; then
    echo -e "${Y}[*] Not logged in. Starting login process...${N}"
    railway login
    
    # Verify login again
    if ! railway status &>/dev/null; then
        echo -e "${R}[!] Authentication failed. Please run 'railway login' manually.${N}"
        exit 1
    fi
fi
echo -e "${G}[+] Logged in successfully.${N}"

# 3. INITIALIZE / LINK PROJECT
if [ ! -d .railway ]; then
    echo -e "${Y}[*] Initializing new Railway project...${N}"
    echo -e "${C}>>> Please select 'Empty Project' when prompted and name it (e.g. zed-tunnel) <<<${N}\n"
    railway init
    
    if [ ! -d .railway ]; then
        echo -e "${R}[!] Project initialization aborted.${N}"
        exit 1
    fi
else
    echo -e "${G}[+] Linked Railway project found.${N}"
fi

# 4. GENERATE PUBLIC DOMAIN FOR WEB TERMINAL
echo -e "${Y}[*] Setting up service domain...${N}"
railway domain >/dev/null 2>&1 || true

# Fetch domain name
DOMAIN_NAME=$(railway domain list 2>/dev/null | grep -oE '[a-zA-Z0-9.-]+\.up\.railway\.app' | head -n1)

# 5. DEPLOY TO RAILWAY
echo -e "${Y}[*] Deploying code to Railway...${N}"
railway up --ci

if [ $? -ne 0 ]; then
    echo -e "${R}[!] Deployment failed.${N}"
    exit 1
fi
echo -e "${G}[+] Code uploaded and deployed!${N}"

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
echo -e ""

# 7. DISPLAY FINAL OUTPUT BANNERS
print_header
echo -e "${G}SUCCESS! Your ZedTunnel Pro is running on Railway.${N}"
echo -e "${B}====================================================${N}"

if [ -n "$VLESS_LINK" ]; then
    echo -e " ${G}YOUR VLESS CONNECTION LINK:${N}"
    echo -e "${C}${VLESS_LINK}${N}"
    echo -e "${B}====================================================${N}"
else
    echo -e "${R}[!] Could not automatically fetch the link from logs.${N}"
    echo -e "${Y}[*] Please view service logs manually to copy the link:${N}"
    echo -e "${C}railway logs${N}"
    echo -e "${B}====================================================${N}"
fi

if [ -n "$DOMAIN_NAME" ]; then
    echo -e " ${G}WEB TERMINAL INTERFACE:${N}"
    echo -e " URL:      ${C}https://${DOMAIN_NAME}${N}"
    echo -e " Username: ${Y}admin${N}"
    echo -e " Password: ${Y}zed123${N}"
    echo -e "${B}====================================================${N}"
fi

echo -e "${Y}[*] Done. You can close this terminal. The tunnel runs 24/7 on Railway.${N}\n"
