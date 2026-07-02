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
    
    while true; do
        echo -e "\n${C}❯ Account Action:${N}"
        echo -e "  ${G}[1]${N} Continue with this account"
        echo -e "  ${R}[2]${N} Log out and switch accounts"
        read -p "  👉 Choice [1-2]: " auth_opt_raw
        auth_opt=$(echo "$auth_opt_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
        
        if [ "$auth_opt" = "1" ]; then
            break
        elif [ "$auth_opt" = "2" ] || [[ "$auth_opt" =~ ^[nN] ]] || [ "$auth_opt" = "logout" ]; then
            echo -e "${Y}❯ Logging out...${N}"
            railway logout >/dev/null 2>&1 || true
            USER_INFO=""
            break
        else
            echo -e "${R}✖ Invalid input: '$auth_opt_raw'. Please enter 1 or 2.${N}"
        fi
    done
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
LINKED=false
if railway status &>/dev/null; then
    LINKED=true
    PROJECT_NAME=$(railway status 2>/dev/null | grep -i 'Project:' | head -n1 | sed 's/[Pp]roject://g' | xargs)
    [ -z "$PROJECT_NAME" ] && PROJECT_NAME="Active Project"
    echo -e "${G}✔ Linked Project: ${W}${PROJECT_NAME}${N}"
    
    while true; do
        echo -e "\n${C}❯ Project Action:${N}"
        echo -e "  ${G}[1]${N} Continue with this project"
        echo -e "  ${Y}[2]${N} Unlink directory from this project"
        echo -e "  ${R}[3]${N} Delete this project permanently"
        read -p "  👉 Choice [1-3]: " proj_opt_raw
        proj_opt=$(echo "$proj_opt_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
        
        if [ "$proj_opt" = "1" ]; then
            break
        elif [ "$proj_opt" = "2" ]; then
            echo -e "${Y}❯ Unlinking project...${N}"
            railway unlink >/dev/null 2>&1 || true
            LINKED=false
            break
        elif [ "$proj_opt" = "3" ]; then
            echo -e "${R}⚠ DELETING PROJECT PERMANENTLY...${N}"
            railway delete --project "$PROJECT_NAME"
            LINKED=false
            break
        else
            echo -e "${R}✖ Invalid choice: '$proj_opt_raw'. Please enter 1, 2, or 3.${N}"
        fi
    done
fi

if [ "$LINKED" = false ]; then
    echo -e "${Y}❯ Initializing new Railway project...${N}"
    echo -e "\n${Y}⚠ ACTION REQUIRED:${N}"
    echo -e "  1. Select ${G}Empty Project${N} when prompted."
    echo -e "  2. Name your service (e.g., ${C}zed-tunnel${N}).\n"
    railway init
    
    if ! railway status &>/dev/null; then
        echo -e "${R}✖ Project initialization aborted.${N}"
        exit 1
    fi
fi

# 4. DEPLOY TO RAILWAY
echo -e "${Y}❯ Compiling and deploying container (this may take a moment)...${N}"

# Ensure the zed-tunnel service exists in the project
railway add --service zed-tunnel >/dev/null 2>&1 || true

# Prompt for Cloudflare Tunnel Configuration
echo -e "\n${C}❯ Select Cloudflare Tunnel Mode for Server/Container:${N}"
echo -e "  ${G}[1]${N} Free Cloudflare Tunnel (TryCloudflare - Temporary/Default)"
echo -e "  ${Y}[2]${N} Personal Tunnel (Custom Domain - Requires Cloudflare Tunnel Token)"

while true; do
    read -p "  👉 Choice [1-2]: " cf_mode_raw
    cf_mode=$(echo "$cf_mode_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
    
    if [ "$cf_mode" = "1" ] || [ -z "$cf_mode" ]; then
        echo -e "${Y}❯ Configuring TryCloudflare...${N}"
        railway variable set TUNNEL_MODE=1 --service zed-tunnel >/dev/null 2>&1 || true
        break
    elif [ "$cf_mode" = "2" ]; then
        echo -e "\n${C}❯ Personal Tunnel Authentication:${N}"
        echo -e "  ${G}[1]${N} Automate Setup (Login & Create Tunnel locally)"
        echo -e "  ${G}[2]${N} Manual Setup (Enter Tunnel Token & Domain)"
        
        while true; do
            read -p "  👉 Choice [1-2]: " cf_auth_choice_raw
            cf_auth_choice=$(echo "$cf_auth_choice_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
            
            if [ "$cf_auth_choice" = "1" ]; then
                # Ensure cloudflared is available locally
                CLOUDFLARED_BIN="cloudflared"
                if ! command -v cloudflared &>/dev/null; then
                    if [ -f "./cloudflared" ]; then
                        CLOUDFLARED_BIN="./cloudflared"
                    else
                        echo -e "${Y}❯ Cloudflared is not installed locally. Downloading portable version...${N}"
                        curl -L -s https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o ./cloudflared
                        chmod +x ./cloudflared
                        CLOUDFLARED_BIN="./cloudflared"
                    fi
                fi
                
                echo -e "${Y}[*] Cloudflare authentication required. Please follow the login prompt:${N}"
                $CLOUDFLARED_BIN tunnel login
                
                echo -e "\n${C}>>> IMPORTANT: Enter your EXACT Subdomain (e.g. vip.yourdomain.com) <<<${N}"
                read -p " Domain: " cf_domain
                cf_domain=$(echo "$cf_domain" | xargs)
                if [ -z "$cf_domain" ]; then
                    echo -e "${R}[!] Domain cannot be empty.${N}"
                    exit 1
                fi
                
                TNAME="zed-railway-$(date +%s)"
                echo -e "${Y}[*] Creating Tunnel (${TNAME})...${N}"
                $CLOUDFLARED_BIN tunnel create "$TNAME"
                
                TID=$($CLOUDFLARED_BIN tunnel list | grep "$TNAME" | awk '{print $1}' | head -n1)
                if [ -z "$TID" ]; then
                    echo -e "${R}[!] Failed to retrieve Tunnel ID.${N}"
                    exit 1
                fi
                
                echo -e "${Y}[*] Routing DNS for ${cf_domain}...${N}"
                $CLOUDFLARED_BIN tunnel route dns -f "$TID" "$cf_domain"
                
                CRED_FILE="$HOME/.cloudflared/$TID.json"
                if [ ! -f "$CRED_FILE" ]; then
                    echo -e "${R}[!] Credentials file not found at $CRED_FILE${N}"
                    exit 1
                fi
                CF_CRED_CONTENT=$(cat "$CRED_FILE")
                
                echo -e "${Y}❯ Uploading Cloudflare Tunnel configuration to Railway...${N}"
                railway variable set TUNNEL_MODE=2 CF_TUNNEL_ID="$TID" CF_TUNNEL_CREDENTIALS="$CF_CRED_CONTENT" CF_DOMAIN="$cf_domain" --service zed-tunnel >/dev/null 2>&1 || true
                break 2
            elif [ "$cf_auth_choice" = "2" ]; then
                read -p "  👉 Enter your Cloudflare Tunnel Token: " cf_token
                read -p "  👉 Enter your Custom Domain (e.g., vpn.yourdomain.com): " cf_domain
                if [ -n "$cf_token" ] && [ -n "$cf_domain" ]; then
                    echo -e "${Y}❯ Setting Personal Tunnel variables on Railway...${N}"
                    railway variable set TUNNEL_MODE=2 CF_TUNNEL_TOKEN="$cf_token" CF_DOMAIN="$cf_domain" --service zed-tunnel >/dev/null 2>&1 || true
                    break 2
                else
                    echo -e "${R}✖ Token and Domain cannot be empty.${N}"
                fi
            else
                echo -e "${R}✖ Invalid choice. Please enter 1 or 2.${N}"
            fi
        done
    else
        echo -e "${R}✖ Invalid choice. Please enter 1 or 2.${N}"
    fi
done

max_deploy_retries=3
deploy_retry=1
deploy_success=false

while [ $deploy_retry -le $max_deploy_retries ]; do
    railway up --service zed-tunnel --ci
    if [ $? -eq 0 ]; then
        deploy_success=true
        break
    else
        echo -e "${R}✖ Attempt $deploy_retry failed.${N}"
        if [ $deploy_retry -lt $max_deploy_retries ]; then
            echo -e "${Y}❯ Retrying deployment in 5 seconds (attempt $((deploy_retry+1))/$max_deploy_retries)...${N}"
            sleep 5
        fi
    fi
    deploy_retry=$((deploy_retry+1))
done

if [ "$deploy_success" = false ]; then
    echo -e "${R}✖ Deployment failed after $max_deploy_retries attempts due to network timeout or connection issues.${N}"
    echo -e "${Y}❯ Note: If you are in Iran, you might need to use a proxy/VPN to run Railway CLI commands.${N}"
    exit 1
fi
echo -e "${G}✔ Container compiled and deployed successfully!${N}"

# 5. GENERATE PUBLIC DOMAIN FOR WEB TERMINAL
echo -e "\n${C}❯ Public Domain Options:${N}"
echo -e "  ${G}[1]${N} Use a free Railway domain (*.up.railway.app)"
echo -e "  ${Y}[2]${N} Use your own custom domain"

DOMAIN_NAME=""
while true; do
    read -p "  👉 Choice [1-2]: " domain_choice_raw
    domain_choice=$(echo "$domain_choice_raw" | tr '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩' '01234567890123456789')
    
    if [ "$domain_choice" = "1" ]; then
        echo -e "${Y}❯ Setting up free Railway domain...${N}"
        railway domain --service zed-tunnel >/dev/null 2>&1 || true
        DOMAIN_NAME=$(railway domain list --service zed-tunnel 2>/dev/null | grep -oE '[a-zA-Z0-9.-]+\.up\.railway\.app' | head -n1)
        break
    elif [ "$domain_choice" = "2" ]; then
        read -p "  👉 Enter your custom domain: " custom_domain
        if [ -n "$custom_domain" ]; then
            echo -e "${Y}❯ Binding custom domain: $custom_domain...${N}"
            railway domain "$custom_domain" --service zed-tunnel
            DOMAIN_NAME="$custom_domain"
            echo -e "${Y}⚠ IMPORTANT: Make sure to point your DNS (CNAME or ALIAS) to the target shown above.${N}"
            break
        else
            echo -e "${R}✖ Domain cannot be empty.${N}"
        fi
    else
        echo -e "${R}✖ Invalid choice. Please enter 1 or 2.${N}"
    fi
done

# 6. SCRAPE VLESS CONNECTION LINK
echo -e "${Y}❯ Waiting for container boot & VLESS link generation (takes ~15s)...${N}"
sleep 15

VLESS_LINK=""
retries=0
max_retries=50

while [ $retries -lt $max_retries ]; do
    # Fetch logs and grep the VLESS protocol link
    LOGS=$(railway logs 2>/dev/null)
    VLESS_LINK=$(echo "$LOGS" | grep -oE 'vless://[a-zA-Z0-9?&=_%#.@:/-]+' | head -n1)
    
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
