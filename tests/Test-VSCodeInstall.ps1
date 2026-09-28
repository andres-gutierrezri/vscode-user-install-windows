#Requires -Version 5.1
<#
.SYNOPSIS
    Pruebas del proyecto: análisis estático del script y verificación posterior a la instalación.
.DESCRIPTION
    Sección A (estática, no requiere instalar nada): sintaxis y contenido esencial.
    Sección B (posterior a la instalación): Code.exe, code.cmd, PATH y accesos directos.
    Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-VSCodeInstall.ps1
    Salida: código 0 si todas las pruebas pasan; en otro caso, el número de fallos.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = $(if ($env:VSCODE_PROGRAMS_DIR) { Join-Path $env:VSCODE_PROGRAMS_DIR 'VSCode' } else { 'C:\Programs\VSCode' })
)

Set-StrictMode -Version Latest
$script:Fallos = 0
$script:Pasadas = 0

function Assert-That {
    param([string]$Nombre, [bool]$Condicion)
    if ($Condicion) { Write-Host "[PASA ] $Nombre" -ForegroundColor Green; $script:Pasadas++ }
    else            { Write-Host "[FALLA] $Nombre" -ForegroundColor Red;   $script:Fallos++ }
}

# ------------------------- Sección A: análisis estático -------------------------
$raiz = Split-Path -Parent $PSScriptRoot
$ps1  = Join-Path $raiz 'src\Install-VSCode.ps1'
$cmd  = Join-Path $raiz 'src\Install-VSCode.cmd'

Assert-That 'Existe src\Install-VSCode.ps1' (Test-Path -LiteralPath $ps1)
Assert-That 'Existe src\Install-VSCode.cmd' (Test-Path -LiteralPath $cmd)

$errores = $null; $tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$tokens, [ref]$errores)
Assert-That 'Install-VSCode.ps1 no tiene errores de sintaxis' (($errores | Measure-Object).Count -eq 0)

$contenidoPs1 = Get-Content -LiteralPath $ps1 -Raw
$contenidoCmd = Get-Content -LiteralPath $cmd -Raw
foreach ($archivo in @(@{ N = 'ps1'; C = $contenidoPs1 }, @{ N = 'cmd'; C = $contenidoCmd })) {
    Assert-That ("[$($archivo.N)] usa el identificador Microsoft.VisualStudioCode") ($archivo.C -match 'Microsoft\.VisualStudioCode')
    Assert-That ("[$($archivo.N)] instala con ámbito de usuario (--scope user)")     ($archivo.C -match '--scope user|''--scope'', ''user''')
    Assert-That ("[$($archivo.N)] habilita addtopath y desktopicon")                  ($archivo.C -match 'addtopath' -and $archivo.C -match 'desktopicon')
    Assert-That ("[$($archivo.N)] usa el destino C:\Programs")                        ($archivo.C -match 'C:\\Programs')
    Assert-That ("[$($archivo.N)] NO solicita elevación (runas / -Verb RunAs)")       ($archivo.C -notmatch 'runas|RunAs')
}

# ------------------- Sección B: verificación posterior a la instalación -------------------
if (Test-Path -LiteralPath (Join-Path $InstallDir 'Code.exe')) {
    Assert-That 'Code.exe existe en el destino' $true
    Assert-That 'bin\code.cmd existe'           (Test-Path -LiteralPath (Join-Path $InstallDir 'bin\code.cmd'))
    $binDir = (Join-Path $InstallDir 'bin').TrimEnd('\')
    $pathU  = [Environment]::GetEnvironmentVariable('Path', 'User')
    Assert-That 'PATH de usuario incluye bin de VS Code' (@($pathU -split ';' | Where-Object { $_.TrimEnd('\') -ieq $binDir }).Count -gt 0)
    Assert-That 'Acceso directo del menú Inicio existe'  (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk'))
    $salida = & (Join-Path $InstallDir 'bin\code.cmd') --version 2>&1 | Select-Object -First 1
    Assert-That "code --version responde ($salida)" ([string]$salida -match '^\d+\.\d+\.\d+')
}
else {
    Write-Host "[OMITE] Sección B: no hay instalación en '$InstallDir' (ejecute primero el instalador)." -ForegroundColor Yellow
}

Write-Host ("`nResultado: {0} pasadas, {1} fallidas." -f $script:Pasadas, $script:Fallos)
exit $script:Fallos
