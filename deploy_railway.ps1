# Set console encoding to UTF-8 to support emojis
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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

$maxDeployRetries = 3
$deployRetry = 1
$deploySuccess = $false

while ($deployRetry -le $maxDeployRetries) {
    & railway up --ci
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
    Write-Host "✖ Deployment failed after $maxDeployRetries attempts due to network timeout or connection issues." -ForegroundColor Red
    Write-Host "❯ Note: If you are in Iran, you might need to use a proxy/VPN to run Railway CLI commands." -ForegroundColor Yellow
    Exit 1
}
Write-Host "✔ Container compiled and deployed successfully!" -ForegroundColor Green

# 5. GENERATE PUBLIC DOMAIN FOR WEB TERMINAL
Write-Host "❯ Setting up public domain for web terminal..." -ForegroundColor Yellow
& railway domain 2>&1 >$null

# Fetch domain name
$domainName = $null
$domainList = & railway domain list 2>$null
foreach ($line in $domainList) {
    if ($line -match '[a-zA-Z0-9.-]+\.up\.railway\.app') {
        $domainName = $Matches[0]
        break
    }
}

# 6. SCRAPE VLESS CONNECTION LINK
Write-Host "❯ Waiting for container boot & VLESS link generation (takes ~15s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

$vlessLink = $null
$retries = 0
$maxRetries = 20

while ($retries -lt $maxRetries) {
    $logs = & railway logs 2>$null
    foreach ($line in $logs) {
        if ($line -match 'vless://[a-zA-Z0-9?&=-_%#.]+') {
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

if ($domainName) {
    Write-Host "🌐 WEB TERMINAL CONTROL PANEL:" -ForegroundColor White
    Write-Host "   URL:      https://$domainName" -ForegroundColor Cyan
    Write-Host "   Username: admin" -ForegroundColor Yellow
    Write-Host "   Password: zed123" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "❯ The tunnel runs 24/7 in the background on Railway." -ForegroundColor Yellow
Write-Host ""
