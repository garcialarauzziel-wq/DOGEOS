param(
    [string]$Distro = "",
    [switch]$NoSudo
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Error $Message
    exit 1
}

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Fail "WSL no esta instalado. Instala una distro Ubuntu de WSL 2 o ejecuta build-dogeos.sh en Linux."
}

$repo = Resolve-Path $PSScriptRoot
$wslPathArgs = @()
if ($Distro -ne "") {
    $wslPathArgs += @("-d", $Distro)
}
$wslPathArgs += @("wslpath", "-a", $repo.Path)

$linuxRepo = (& wsl.exe @wslPathArgs) 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($linuxRepo)) {
    Fail "No pude convertir la ruta con WSL. Verifica que exista una distro WSL instalada."
}

$prefix = "sudo -E "
if ($NoSudo) {
    $prefix = ""
}

$command = "cd '$($linuxRepo.Trim())' && ${prefix}bash ./build-dogeos.sh"
$runArgs = @()
if ($Distro -ne "") {
    $runArgs += @("-d", $Distro)
}
$runArgs += @("bash", "-lc", $command)

Write-Host "Ejecutando constructor en WSL: $command"
& wsl.exe @runArgs
exit $LASTEXITCODE
