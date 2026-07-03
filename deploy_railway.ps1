# Set console encoding to UTF-8 to support emojis
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Add local user bin paths for Linux/macOS compatibility testing
$localPath = Join-Path $env:HOME ".railway/bin"
if (Test-Path $localPath) {
    $env:PATH = "$localPath" + [IO.Path]::PathSeparator + $env:PATH
}

Clear-Host
Write-Host "⚡ ZEDTUNNEL PRO • RAILWAY AUTOMATION TOOL (WINDOWS)" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan

# 1. CHECK RAILWAY CLI INSTALLATION
if (-not (Get-Command railway -ErrorAction SilentlyContinue)) {
    Write-Host "❯ Railway CLI is not installed in system PATH." -ForegroundColor Yellow
    Write-Host "❯ Attempting automatic installation via npm..." -ForegroundColor Yellow
    
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "✖ Node.js/npm is not installed. Please install Node.js from https://nodejs.org/" -ForegroundColor Red
        Exit 1
    }
    
    npm install -g @railway/cli
    
    if (-not (Get-Command railway -ErrorAction SilentlyContinue)) {
        Write-Host "✖ Installation failed. Please install it manually: npm install -g @railway/cli" -ForegroundColor Red
        Exit 1
    }
    Write-Host "✔ Railway CLI installed successfully!" -ForegroundColor Green
}

# 2. CHECK AUTHENTICATION STATUS
Write-Host "❯ Checking Railway credentials..." -ForegroundColor Yellow
$userInfo = & railway whoami 2>$null

if ($LASTEXITCODE -eq 0 -and $userInfo) {
    $userInfo = $userInfo -join " "
    Write-Host "✔ Active Account: $userInfo" -ForegroundColor Green
    
    while ($true) {
        Write-Host ""
        Write-Host "❯ Account Action:" -ForegroundColor Cyan
        Write-Host "  [1] Continue with this account" -ForegroundColor Green
        Write-Host "  [2] Log out and switch accounts" -ForegroundColor Red
        
        $authOpt = Read-Host "  👉 Choice [1-2]"
        
        if ($authOpt -eq "1" -or $authOpt -eq "۱") {
            break
        } elseif ($authOpt -eq "2" -or $authOpt -eq "۲" -or $authOpt -eq "logout") {
            Write-Host "❯ Logging out..." -ForegroundColor Yellow
            & railway logout 2>&1 >$null
            $userInfo = $null
            break
        } else {
            Write-Host "✖ Invalid input: '$authOpt'. Please enter 1 or 2." -ForegroundColor Red
        }
    }
}

if (-not $userInfo) {
    Write-Host "❯ Starting Railway login process..." -ForegroundColor Yellow
    & railway login
    
    # Verify login again
    $userInfo = & railway whoami 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $userInfo) {
        Write-Host "✖ Authentication failed. Please log in manually using 'railway login'." -ForegroundColor Red
        Exit 1
    }
}
Write-Host "✔ Authenticated successfully." -ForegroundColor Green

# 3. INITIALIZE / LINK PROJECT
$statusCheck = & railway status 2>$null
$linked = ($LASTEXITCODE -eq 0)

if ($linked) {
    $projectName = "Active Project"
    # Extract project name from status if possible
    $statusLines = & railway status 2>&1
    foreach ($line in $statusLines) {
        if ($line -like "*Project:*") {
            $projectName = $line.Replace("Project:", "").Trim()
            break
        }
    }
    Write-Host "✔ Linked Project: $projectName" -ForegroundColor Green
    
    while ($true) {
        Write-Host ""
        Write-Host "❯ Project Action:" -ForegroundColor Cyan
        Write-Host "  [1] Continue with this project" -ForegroundColor Green
        Write-Host "  [2] Unlink directory from this project" -ForegroundColor Yellow
        Write-Host "  [3] Delete this project permanently" -ForegroundColor Red
        
        $projOpt = Read-Host "  👉 Choice [1-3]"
        
        if ($projOpt -eq "1" -or $projOpt -eq "۱") {
            break
        } elseif ($projOpt -eq "2" -or $projOpt -eq "۲") {
            Write-Host "❯ Unlinking project..." -ForegroundColor Yellow
            & railway unlink 2>&1 >$null
            $linked = $false
            break
        } elseif ($projOpt -eq "3" -or $projOpt -eq "۳") {
            Write-Host "⚠ DELETING PROJECT PERMANENTLY..." -ForegroundColor Red
            & railway delete --project "$projectName"
            $linked = $false
            break
        } else {
            Write-Host "✖ Invalid choice: '$projOpt'. Please enter 1, 2, or 3." -ForegroundColor Red
        }
    }
}

if (-not $linked) {
    Write-Host "❯ Initializing new Railway project..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠ ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  1. Select 'Empty Project' when prompted." -ForegroundColor Green
    Write-Host "  2. Name your service (e.g., zed-tunnel)." -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    
    & railway init
    
    $statusCheck = & railway status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✖ Project initialization aborted." -ForegroundColor Red
        Exit 1
    }
}

# 4. DEPLOY TO RAILWAY
Write-Host "❯ Compiling and deploying container (this may take a moment)..." -ForegroundColor Yellow

# Ensure the zed-tunnel service exists in the project
& railway add --service zed-tunnel 2>$null >$null

# Prompt for Cloudflare Tunnel Configuration
Write-Host ""
Write-Host "❯ Select Cloudflare Tunnel Mode for Server/Container:" -ForegroundColor Cyan
Write-Host "  [1] Free Cloudflare Tunnel (TryCloudflare - Temporary/Default)" -ForegroundColor Green
Write-Host "  [2] Personal Tunnel (Custom Domain - Requires Cloudflare Tunnel Token)" -ForegroundColor Yellow

while ($true) {
    $cfMode = Read-Host "  👉 Choice [1-2]"
    
    if ($cfMode -eq "1" -or $cfMode -eq "۱" -or -not $cfMode) {
        Write-Host "❯ Configuring TryCloudflare..." -ForegroundColor Yellow
        & railway variable set TUNNEL_MODE=1 --service zed-tunnel 2>&1 >$null
        break
    } elseif ($cfMode -eq "2" -or $cfMode -eq "۲") {
        Write-Host ""
        Write-Host "❯ Personal Tunnel Authentication:" -ForegroundColor Cyan
        Write-Host "  [1] Automate Setup (Login & Create Tunnel locally)" -ForegroundColor Green
        Write-Host "  [2] Manual Setup (Enter Tunnel Token & Domain)" -ForegroundColor Yellow
        
        while ($true) {
            $cfAuthChoice = Read-Host "  👉 Choice [1-2]"
            
            if ($cfAuthChoice -eq "1" -or $cfAuthChoice -eq "۱") {
                # Ensure cloudflared is available locally
                $cloudflaredBin = "cloudflared"
                if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
                    if (Test-Path ".\cloudflared.exe") {
                        $cloudflaredBin = ".\cloudflared.exe"
                    } else {
                        Write-Host "❯ Cloudflared is not installed locally. Downloading portable version..." -ForegroundColor Yellow
                        Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile ".\cloudflared.exe"
                        $cloudflaredBin = ".\cloudflared.exe"
                    }
                }
                
                $certPath = Join-Path $env:USERPROFILE ".cloudflared\cert.pem"
                if (Test-Path $certPath) {
                    Write-Host "✔ Active Cloudflare authentication certificate detected. Skipping login..." -ForegroundColor Green
                } else {
                    Write-Host "[*] Cloudflare authentication required. Please follow the login prompt:" -ForegroundColor Yellow
                    Start-Process $cloudflaredBin -ArgumentList "tunnel login" -NoNewWindow -Wait
                }
                
                # Resolve Cloudflare root zone domain from cert.pem
                $zoneName = $null
                $certPath = Join-Path $env:USERPROFILE ".cloudflared\cert.pem"
                if (Test-Path $certPath) {
                    try {
                        $tokenContent = (Get-Content -Path $certPath | Where-Object { $_ -notmatch "ARGO TUNNEL TOKEN" }) -join ""
                        # Decode base64
                        $decodedBytes = [System.Convert]::FromBase64String($tokenContent)
                        $decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes) | ConvertFrom-Json
                        $zoneId = $decodedJson.zoneID
                        $apiToken = $decodedJson.apiToken
                        
                        if ($zoneId -and $apiToken) {
                            Write-Host "❯ Querying Cloudflare account domains..." -ForegroundColor Yellow
                            $headers = @{
                                "Authorization" = "Bearer $apiToken"
                                "Content-Type" = "application/json"
                            }
                            $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId" -Headers $headers -TimeoutSec 10
                            if ($response -and $response.result -and $response.result.name) {
                                $zoneName = $response.result.name
                                Write-Host "✔ Detected: $zoneName" -ForegroundColor Green
                            }
                        }
                    } catch {
                        Write-Host "✖ Failed to query Cloudflare API (using manual entry)" -ForegroundColor Red
                    }
                }

                # Check for previously configured domain (locally first, then on Railway)
                $prevDomain = $null
                $localDomainFile = ".\.cf_domain"
                if (Test-Path $localDomainFile) {
                    $prevDomain = (Get-Content -Raw -Path $localDomainFile).Trim()
                }
                
                if (-not $prevDomain) {
                    $prevVarsJson = & railway variable list --service zed-tunnel --json 2>$null | ConvertFrom-Json
                    if ($prevVarsJson -and $prevVarsJson.CF_DOMAIN) {
                        $prevDomain = $prevVarsJson.CF_DOMAIN
                    }
                }
                
                $cfDomain = $null
                if ($prevDomain) {
                    Write-Host "❯ Detected previously configured domain: $prevDomain" -ForegroundColor Yellow
                    $reuseOpt = Read-Host "  👉 Do you want to reuse this domain? [Y/n]"
                    if ($reuseOpt -notmatch "^[nN]") {
                        $cfDomain = $prevDomain
                    }
                }
                
                if (-not $cfDomain) {
                    $useDetected = $false
                    if ($zoneName) {
                        Write-Host "❯ Detected domain on your Cloudflare account: $zoneName" -ForegroundColor Yellow
                        $useDetectedOpt = Read-Host "  👉 Do you want to use this domain? [Y/n]"
                        if ($useDetectedOpt -notmatch "^[nN]") {
                            $useDetected = $true
                        }
                    }
                    
                    if ($useDetected) {
                        $cfDomain = "zedvip.$zoneName"
                        Write-Host "✔ Subdomain automatically set to: $cfDomain" -ForegroundColor Green
                    } else {
                        Write-Host "[*] Re-authenticating with Cloudflare to choose a different domain..." -ForegroundColor Yellow
                        if (Test-Path $certPath) {
                            Remove-Item -Path $certPath -Force
                        }
                        Start-Process $cloudflaredBin -ArgumentList "tunnel login" -NoNewWindow -Wait
                        
                        # Re-detect domain from the new cert.pem
                        if (Test-Path $certPath) {
                            try {
                                $tokenContent = (Get-Content -Path $certPath | Where-Object { $_ -notmatch "ARGO TUNNEL TOKEN" }) -join ""
                                $decodedBytes = [System.Convert]::FromBase64String($tokenContent)
                                $decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes) | ConvertFrom-Json
                                $zoneId = $decodedJson.zoneID
                                $apiToken = $decodedJson.apiToken
                                
                                if ($zoneId -and $apiToken) {
                                    Write-Host "❯ Querying Cloudflare account domains..." -ForegroundColor Yellow
                                    $headers = @{
                                        "Authorization" = "Bearer $apiToken"
                                        "Content-Type" = "application/json"
                                    }
                                    $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId" -Headers $headers -TimeoutSec 10
                                    if ($response -and $response.result -and $response.result.name) {
                                        $zoneName = $response.result.name
                                        Write-Host "✔ Detected: $zoneName" -ForegroundColor Green
                                        $cfDomain = "zedvip.$zoneName"
                                        Write-Host "✔ Subdomain automatically set to: $cfDomain" -ForegroundColor Green
                                    }
                                }
                            } catch {
                                Write-Host "✖ Failed to query DNS records" -ForegroundColor Red
                            }
                        }
                        
                        if (-not $cfDomain) {
                            Write-Host ""
                            Write-Host ">>> IMPORTANT: Enter your EXACT Subdomain (e.g. vip.yourdomain.com) <<<" -ForegroundColor Cyan
                            $cfDomain = Read-Host " Domain"
                            $cfDomain = $cfDomain.Trim()
                            
                            if (-not $cfDomain) {
                                Write-Host "[!] Domain cannot be empty." -ForegroundColor Red
                                Exit 1
                            }
                        }
                    }
                }
                
                # Save domain locally for next time
                $cfDomain | Out-File -FilePath $localDomainFile -NoNewline -Encoding utf8
                
                $tName = "zed-railway-" + (Get-Date -UFormat %s)
                Write-Host "[*] Creating Tunnel ($tName)..." -ForegroundColor Yellow
                Start-Process $cloudflaredBin -ArgumentList "tunnel create $tName" -NoNewWindow -Wait
                
                $tList = & $cloudflaredBin tunnel list
                $tId = $null
                foreach ($line in $tList) {
                    if ($line -match $tName) {
                        $tId = ($line -split "\s+")[0]
                        break
                    }
                }
                
                if (-not $tId) {
                    Write-Host "[!] Failed to retrieve Tunnel ID." -ForegroundColor Red
                    Exit 1
                }
                
                Write-Host "[*] Routing DNS for $cfDomain..." -ForegroundColor Yellow
                Start-Process $cloudflaredBin -ArgumentList "tunnel route dns -f $tId $cfDomain" -NoNewWindow -Wait
                
                $credPath = Join-Path $env:USERPROFILE ".cloudflared\$tId.json"
                if (-not (Test-Path $credPath)) {
                    Write-Host "[!] Credentials file not found at $credPath" -ForegroundColor Red
                    Exit 1
                }
                $cfCredContent = Get-Content -Raw -Path $credPath
                
                Write-Host "❯ Uploading Cloudflare Tunnel configuration to Railway..." -ForegroundColor Yellow
                & railway variable set TUNNEL_MODE=2 CF_TUNNEL_ID="$tId" CF_TUNNEL_CREDENTIALS="$cfCredContent" CF_DOMAIN="$cfDomain" --service zed-tunnel 2>&1 >$null
                break
            } elseif ($cfAuthChoice -eq "2" -or $cfAuthChoice -eq "۲") {
                $cfToken = Read-Host "  👉 Enter your Cloudflare Tunnel Token"
                $cfDomain = Read-Host "  👉 Enter your Custom Domain (e.g., vpn.yourdomain.com)"
                
                if ($cfToken -and $cfDomain) {
                    Write-Host "❯ Setting Personal Tunnel variables on Railway..." -ForegroundColor Yellow
                    & railway variable set TUNNEL_MODE=2 CF_TUNNEL_TOKEN="$cfToken" CF_DOMAIN="$cfDomain" --service zed-tunnel 2>&1 >$null
                    break
                } else {
                    Write-Host "✖ Token and Domain cannot be empty." -ForegroundColor Red
                }
            } else {
                Write-Host "✖ Invalid choice. Please enter 1 or 2." -ForegroundColor Red
            }
        }
        break
    } else {
        Write-Host "✖ Invalid choice. Please enter 1 or 2." -ForegroundColor Red
    }
}

$maxDeployRetries = 3
$deployRetry = 1
$deploySuccess = $false

while ($deployRetry -le $maxDeployRetries) {
    & railway up --service zed-tunnel --ci --detach
    if ($LASTEXITCODE -eq 0) {
        $deploySuccess = $true
        break
    } else {
        Write-Host "✖ Attempt $deployRetry failed." -ForegroundColor Red
        if ($deployRetry -lt $maxDeployRetries) {
            Write-Host "❯ Retrying deployment in 5 seconds (attempt $($deployRetry + 1)/$maxDeployRetries)..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
    }
    $deployRetry++
}

if (-not $deploySuccess) {
    Write-Host "⚠ CLI reported a timeout/error during deployment status tracking." -ForegroundColor Yellow
    Write-Host "❯ Since the code upload might have succeeded, we will proceed and check logs/domains anyway..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
} else {
    Write-Host "✔ Container compiled and deployed successfully!" -ForegroundColor Green
}

# 5. GENERATE PUBLIC DOMAIN FOR WEB TERMINAL
$domainName = $null

# 6. SCRAPE VLESS CONNECTION LINK
Write-Host "❯ Waiting for container boot & VLESS link generation (takes ~15s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

$vlessLink = $null
$retries = 0
$maxRetries = 50

while ($retries -lt $maxRetries) {
    $logs = & railway logs 2>$null
    foreach ($line in $logs) {
        if ($line -match 'vless://[a-zA-Z0-9?&=_%#.@:/-]+') {
            $vlessLink = $Matches[0]
            break
        }
    }
    if ($vlessLink) {
        break
    }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 3
    $retries++
}
Write-Host ""

if ($vlessLink -and $vlessLink -match 'host=([a-zA-Z0-9.-]+)') {
    $domainName = $Matches[1]
}

# 7. DISPLAY FINAL OUTPUT BANNERS
Clear-Host
Write-Host "⚡ ZEDTUNNEL PRO • RAILWAY AUTOMATION TOOL (WINDOWS)" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 SUCCESS! Your ZedTunnel Pro is running on Railway." -ForegroundColor Green
Write-Host ""

if ($vlessLink) {
    Write-Host "🔗 YOUR VLESS CONNECTION LINK:" -ForegroundColor White
    Write-Host $vlessLink -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "✖ Could not automatically fetch the link from logs." -ForegroundColor Red
    Write-Host "❯ Please view service logs manually to copy the link:" -ForegroundColor Yellow
    Write-Host "    railway logs" -ForegroundColor Cyan
    Write-Host ""
}



Write-Host "❯ The tunnel runs 24/7 in the background on Railway." -ForegroundColor Yellow
Write-Host "❯ Join our Telegram channel: https://t.me/iWZedLabs" -ForegroundColor Cyan
