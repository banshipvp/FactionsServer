# ============================================================
# One-time SSH key setup for VPS deploy
# Run this ONCE - it will ask for your VPS password once,
# then all future deploys will be passwordless.
# ============================================================

$pubKey = (Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" -Raw).Trim()

Write-Host "[1/2] Installing SSH key on VPS (enter your VPS password when prompted)..." -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=accept-new root@187.124.153.190 "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[2/2] Verifying passwordless login..." -ForegroundColor Cyan
    $result = ssh -o BatchMode=yes root@187.124.153.190 "echo OK" 2>&1
    if ($result -eq "OK") {
        Write-Host "SUCCESS - passwordless SSH is working. You can now run deploy.ps1 any time." -ForegroundColor Green
    } else {
        Write-Host "Key was installed but test login failed. Check the VPS." -ForegroundColor Yellow
    }
} else {
    Write-Host 'Failed to install key. Check your password and try again.' -ForegroundColor Red
}
