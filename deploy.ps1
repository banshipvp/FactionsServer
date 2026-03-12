# deploy.ps1 - Build & deploy plugins to VPS
# Usage:
#   .\deploy.ps1              (deploy all)
#   .\deploy.ps1 -Plugin factions
#   .\deploy.ps1 -Plugin envoy
#   .\deploy.ps1 -Plugin hub
#   .\deploy.ps1 -Plugin raiding
#   .\deploy.ps1 -Plugin pvp
#   .\deploy.ps1 -Plugin kits
#   .\deploy.ps1 -Plugin shop
#   .\deploy.ps1 -Plugin genblocks
#   .\deploy.ps1 -Plugin crates
#   .\deploy.ps1 -Plugin hud
#   .\deploy.ps1 -Plugin zones
#   .\deploy.ps1 -Plugin anticheat
#   .\deploy.ps1 -Plugin economy
#   .\deploy.ps1 -Plugin enchants

param(
    [string]$Plugin = "all"
)

$VPS_HOST             = "root@187.124.153.190"
$VPS_FACTIONS_PLUGINS = "/minecraft/factions/plugins"
$VPS_HUB_PLUGINS      = "/minecraft/hub/plugins"
$DEV                  = "C:\Users\admin\Dev"
$SSH_KEY              = "$env:USERPROFILE\.ssh\id_ed25519"

function Invoke-Ssh([string]$Cmd) {
    ssh -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=10 $VPS_HOST $Cmd
}

function Deploy-Jar([string]$LocalJar, [string]$RemotePath) {
    $name = Split-Path $LocalJar -Leaf
    Write-Host "  Uploading $name ..." -ForegroundColor Gray
    scp -i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=10 $LocalJar "${VPS_HOST}:${RemotePath}/"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Upload failed for $name" -ForegroundColor Red
        return $false
    }
    Write-Host "  [OK] $name deployed to $RemotePath" -ForegroundColor Green
    return $true
}

function Build-Gradle([string]$ProjectDir, [string]$BuildName) {
    Write-Host ""
    Write-Host "Building $BuildName ..." -ForegroundColor Cyan
    Push-Location $ProjectDir
    & .\gradlew.bat clean build --quiet 2>&1 | Where-Object { $_ -match "error|FAIL|BUILD" }
    $ok = ($LASTEXITCODE -eq 0)
    Pop-Location
    if ($ok) {
        Write-Host "  [OK] $BuildName built" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $BuildName build failed" -ForegroundColor Red
    }
    return $ok
}

$plugins = @(
    [PSCustomObject]@{ Name="factions";  Dir="$DEV\SimpleFactions";          Jar="SimpleFactions-*.jar";        Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="envoy";     Dir="$DEV\SimpleEnvoy";             Jar="SimpleEnvoy-*.jar";           Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="raiding";   Dir="$DEV\SimpleFactionsRaiding";   Jar="SimpleFactionsRaiding-*.jar"; Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="pvp";       Dir="$DEV\SimplePvP";               Jar="SimplePvP-*.jar";             Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="kits";      Dir="$DEV\SimpleKits";              Jar="SimpleKits-*.jar";            Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="shop";      Dir="$DEV\SimpleShop";              Jar="SimpleShop-*.jar";            Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="genblocks"; Dir="$DEV\SimpleGenBlocks";         Jar="SimpleGenBlocks-*.jar";       Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="crates";    Dir="$DEV\SimpleCrates";            Jar="SimpleCrates-*.jar";          Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="hud";       Dir="$DEV\SimpleHUD";               Jar="SimpleHUD-*.jar";             Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="zones";     Dir="$DEV\SimpleZones";             Jar="SimpleZones-*.jar";           Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="anticheat"; Dir="$DEV\SimpleAntiCheat";         Jar="SimpleAntiCheat-*.jar";       Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="economy";   Dir="$DEV\SimpleEconomy";           Jar="SimpleEconomy-*.jar";         Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="enchants";  Dir="$DEV\faction-enchants-plugin"; Jar="FactionEnchants*.jar";        Remote=$VPS_FACTIONS_PLUGINS },
    [PSCustomObject]@{ Name="hub";       Dir="$DEV\SimpleHub";               Jar="SimpleHub-*.jar";             Remote=$VPS_HUB_PLUGINS }
)

Write-Host "Checking VPS connection..." -ForegroundColor Cyan
$ping = Invoke-Ssh "echo pong"
if ($ping -ne "pong") {
    Write-Host "Cannot connect to VPS. Run .\setup-ssh.ps1 first." -ForegroundColor Red
    exit 1
}
Write-Host "  VPS connected." -ForegroundColor Green

if ($Plugin -eq "all") {
    $selected = $plugins
} else {
    $selected = $plugins | Where-Object { $_.Name -eq $Plugin.ToLower() }
}

if (-not $selected) {
    $names = ($plugins | Select-Object -ExpandProperty Name) -join ", "
    Write-Host "Unknown plugin: $Plugin. Valid: $names" -ForegroundColor Red
    exit 1
}

$built  = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($p in $selected) {
    if (-not (Test-Path $p.Dir)) {
        Write-Host "Skipping $($p.Name) - project not found: $($p.Dir)" -ForegroundColor Yellow
        continue
    }

    $ok = Build-Gradle $p.Dir $p.Name
    if (-not $ok) { $failed.Add($p.Name); continue }

    $jar = Get-ChildItem (Join-Path $p.Dir "build\libs") -Filter $p.Jar -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $jar) {
        Write-Host "  [FAIL] Built JAR not found matching $($p.Jar)" -ForegroundColor Red
        $failed.Add($p.Name); continue
    }

    $deployed = Deploy-Jar $jar.FullName $p.Remote
    if ($deployed) { $built.Add($p.Name) } else { $failed.Add($p.Name) }
}

Write-Host ""
Write-Host "=============================" -ForegroundColor White
if ($built.Count  -gt 0) { Write-Host "Deployed:  $($built  -join ', ')" -ForegroundColor Green }
if ($failed.Count -gt 0) { Write-Host "Failed:    $($failed -join ', ')" -ForegroundColor Red }
Write-Host "=============================" -ForegroundColor White
Write-Host ""
Write-Host "Restart the server on the VPS for changes to take effect." -ForegroundColor Yellow
