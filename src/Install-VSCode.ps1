#Requires -Version 5.1
<#
.SYNOPSIS
    Instala Visual Studio Code (edición "User") en Windows 11 sin privilegios administrativos.

.DESCRIPTION
    Flujo de ejecución:
      1. Detecta instalaciones previas de Visual Studio Code (registro y rutas conocidas).
      2. Si existe una instalación de ámbito usuario, la desinstala para reemplazarla.
         Las instalaciones de ámbito equipo (Program Files) NO pueden retirarse sin
         privilegios administrativos; el script lo advierte y continúa.
      3. Crea C:\Programs\VSCode (o la ruta indicada) y valida permisos de escritura.
      4. Instala con: winget install -e --id Microsoft.VisualStudioCode --scope user
         habilitando accesos directos (escritorio), menú contextual, asociación de
         archivos y adición al PATH del usuario (variable de entorno).
      5. Si winget no está disponible o falla, descarga el instalador de usuario desde
         code.visualstudio.com, valida su firma Authenticode y lo ejecuta.
      6. Verifica el resultado (Code.exe, bin\code.cmd, PATH, accesos directos).

.PARAMETER ProgramsDir
    Carpeta contenedora. Por defecto C:\Programs (o la variable VSCODE_PROGRAMS_DIR).

.PARAMETER AppFolderName
    Subcarpeta de instalación. Por defecto VSCode (o la variable VSCODE_APP_FOLDER).

.PARAMETER SkipWinget
    Omite winget y utiliza directamente la descarga del instalador de usuario.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-VSCode.ps1

.NOTES
    Autor : Ingeniero Andrés Felipe Gutiérrez Rivera
    Versión: 1.0.0
    Licencia: MIT
    Códigos de salida: 0 = éxito; 1 = error general; 2 = sin permisos de carpeta;
                       3 = fallo de instalación; 4 = verificación fallida.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProgramsDir = $(if ($env:VSCODE_PROGRAMS_DIR) { $env:VSCODE_PROGRAMS_DIR } else { 'C:\Programs' }),

    [ValidateNotNullOrEmpty()]
    [string]$AppFolderName = $(if ($env:VSCODE_APP_FOLDER) { $env:VSCODE_APP_FOLDER } else { 'VSCode' }),

    [switch]$SkipWinget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --------------------------------------------------------------------------
# Constantes del script
# --------------------------------------------------------------------------
$script:PackageId  = 'Microsoft.VisualStudioCode'
# La URL "thank-you?dv=win64user" es una página HTML; este enlace entrega el mismo instalador.
$script:DirectUrl  = 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user'
# Tareas de Inno Setup: "!runcode" evita abrir VS Code al finalizar; el resto habilita
# acceso directo de escritorio, menú contextual, asociación de archivos y PATH de usuario.
$script:MergeTasks = '!runcode,desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath'
$script:LogFile    = Join-Path $env:TEMP ('vscode-install-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
$script:InstallDir = $null

# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------
function Write-Log {
    <# Escribe un mensaje en consola y en el archivo de registro. #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )
    $linea = '[{0:HH:mm:ss}] [{1}] {2}' -f (Get-Date), $Level, $Message
    $color = switch ($Level) {
        'INFO'  { 'Cyan' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'OK'    { 'Green' }
    }
    Write-Host $linea -ForegroundColor $color
    try { Add-Content -Path $script:LogFile -Value $linea -Encoding UTF8 } catch { }
}

function Test-IsAdministrator {
    $identidad  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal  = New-Object Security.Principal.WindowsPrincipal($identidad)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WingetAvailable {
    return [bool](Get-Command -Name winget -ErrorAction SilentlyContinue)
}

function Get-InnoArguments {
    <# Argumentos silenciosos de Inno Setup (la ruta no debe contener espacios). #>
    return "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=$($script:InstallDir) /MERGETASKS=$($script:MergeTasks)"
}

# --------------------------------------------------------------------------
# Paso 1: detección de instalaciones previas
# --------------------------------------------------------------------------
function Get-VSCodeInstallations {
    <# Devuelve las instalaciones estables de VS Code halladas (registro y rutas conocidas). #>
    $claves = @(
        @{ Ruta = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*';                    Ambito = 'Usuario' },
        @{ Ruta = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';                    Ambito = 'Equipo'  },
        @{ Ruta = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';        Ambito = 'Equipo'  }
    )
    $hallazgos = New-Object System.Collections.Generic.List[object]

    foreach ($clave in $claves) {
        foreach ($item in (Get-ItemProperty -Path $clave.Ruta -ErrorAction SilentlyContinue)) {
            $nombre = if ($item.PSObject.Properties['DisplayName']) { [string]$item.DisplayName } else { '' }
            if ($nombre -like 'Microsoft Visual Studio Code*' -and $nombre -notlike '*Insiders*') {
                $ubicacion = if ($item.PSObject.Properties['InstallLocation']) { [string]$item.InstallLocation } else { '' }
                $hallazgos.Add([pscustomobject]@{
                    Nombre    = $nombre
                    Ambito    = $clave.Ambito
                    Ubicacion = $ubicacion.TrimEnd('\')
                    Origen    = 'Registro'
                })
            }
        }
    }

    # Rutas conocidas (cubre instalaciones huérfanas o sin entrada en el registro).
    $rutas = @(
        @{ Ruta = (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code'); Ambito = 'Usuario' },
        @{ Ruta = (Join-Path $env:ProgramFiles 'Microsoft VS Code');          Ambito = 'Equipo'  }
    )
    if (${env:ProgramFiles(x86)}) {
        $rutas += @{ Ruta = (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code'); Ambito = 'Equipo' }
    }
    if ($script:InstallDir) {
        $rutas += @{ Ruta = $script:InstallDir; Ambito = 'Usuario' }
    }
    foreach ($r in $rutas) {
        $yaRegistrada = $hallazgos | Where-Object { $_.Ubicacion -and ($_.Ubicacion -ieq $r.Ruta.TrimEnd('\')) }
        if ((Test-Path -LiteralPath (Join-Path $r.Ruta 'Code.exe')) -and -not $yaRegistrada) {
            $hallazgos.Add([pscustomobject]@{
                Nombre    = 'Visual Studio Code (detectado por ruta)'
                Ambito    = $r.Ambito
                Ubicacion = $r.Ruta.TrimEnd('\')
                Origen    = 'Ruta'
            })
        }
    }
    return , $hallazgos.ToArray()
}

# --------------------------------------------------------------------------
# Paso 2: reemplazo (desinstalación de la instalación de usuario)
# --------------------------------------------------------------------------
function Wait-ForRemoval {
    <# El desinstalador de Inno se relanza desde %TEMP%; se sondea hasta que Code.exe desaparezca. #>
    param([string[]]$Rutas, [int]$TimeoutSeconds = 90)
    $limite = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $limite) {
        $presentes = $Rutas | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'Code.exe')) }
        if (-not $presentes) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Remove-VSCodeUserInstallation {
    param([Parameter(Mandatory)][object[]]$Instalaciones)

    Write-Log 'Cerrando procesos de Visual Studio Code del usuario actual...'
    Get-Process -Name 'Code' -ErrorAction SilentlyContinue | ForEach-Object {
        try { [void]$_.CloseMainWindow() } catch { }
    }
    Start-Sleep -Seconds 2
    Get-Process -Name 'Code' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    if (Test-WingetAvailable) {
        Write-Log 'Desinstalando con winget (--scope user)...'
        & winget uninstall -e --id $script:PackageId --scope user --silent --accept-source-agreements 2>&1 |
            ForEach-Object { Add-Content -Path $script:LogFile -Value $_ -Encoding UTF8 }
        Write-Log ("winget uninstall finalizó con código {0}." -f $LASTEXITCODE)
    }

    # Respaldo: desinstalador propio de Inno Setup (unins000.exe).
    $rutasUsuario = @($Instalaciones | Where-Object { $_.Ambito -eq 'Usuario' -and $_.Ubicacion } |
                      ForEach-Object { $_.Ubicacion } | Select-Object -Unique)
    foreach ($ruta in $rutasUsuario) {
        $desinstalador = Join-Path $ruta 'unins000.exe'
        if ((Test-Path -LiteralPath (Join-Path $ruta 'Code.exe')) -and (Test-Path -LiteralPath $desinstalador)) {
            Write-Log "Ejecutando desinstalador: $desinstalador"
            Start-Process -FilePath $desinstalador -ArgumentList '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES' -Wait
        }
    }

    if (-not (Wait-ForRemoval -Rutas $rutasUsuario)) {
        throw 'La instalación previa de usuario no pudo retirarse en el tiempo previsto.'
    }

    # Limpieza de residuos SOLO dentro de la carpeta de destino de este script.
    if (Test-Path -LiteralPath $script:InstallDir) {
        $completa = [IO.Path]::GetFullPath($script:InstallDir)
        $raiz     = [IO.Path]::GetPathRoot($completa)
        if ($completa.TrimEnd('\') -ne $raiz.TrimEnd('\')) {
            Remove-Item -LiteralPath $completa -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log 'Instalación previa de usuario retirada.' 'OK'
}

# --------------------------------------------------------------------------
# Paso 3: carpetas C:\Programs\VSCode
# --------------------------------------------------------------------------
function New-InstallFolders {
    try {
        foreach ($carpeta in @($ProgramsDir, $script:InstallDir)) {
            if (-not (Test-Path -LiteralPath $carpeta)) {
                New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
                Write-Log "Carpeta creada: $carpeta" 'OK'
            }
            else {
                Write-Log "Carpeta existente: $carpeta"
            }
        }
        # Prueba real de escritura.
        $prueba = Join-Path $script:InstallDir ('.write-test-{0}' -f [guid]::NewGuid())
        Set-Content -Path $prueba -Value 'ok' -Encoding ASCII
        Remove-Item -LiteralPath $prueba -Force
    }
    catch [System.UnauthorizedAccessException] {
        Write-Log "Sin permisos para crear o escribir en '$ProgramsDir'. Es posible que una directiva restrinja la raíz de la unidad." 'ERROR'
        return $false
    }
    catch {
        Write-Log ("No fue posible preparar las carpetas: {0}" -f $_.Exception.Message) 'ERROR'
        return $false
    }
    return $true
}

# --------------------------------------------------------------------------
# Paso 4: instalación
# --------------------------------------------------------------------------
function Install-ViaWinget {
    $innoArgs = Get-InnoArguments
    Write-Log 'Instalando con winget (esto puede tardar unos minutos)...'
    $wingetArgs = @(
        'install', '-e', '--id', $script:PackageId,
        '--scope', 'user', '--silent',
        '--accept-package-agreements', '--accept-source-agreements',
        '--override', $innoArgs
    )
    & winget @wingetArgs 2>&1 | ForEach-Object { Add-Content -Path $script:LogFile -Value $_ -Encoding UTF8 }
    $codigo = $LASTEXITCODE
    Write-Log ("winget install finalizó con código {0}." -f $codigo)
    return ($codigo -eq 0)
}

function Install-ViaDirectDownload {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $instalador = Join-Path $env:TEMP 'VSCodeUserSetup-x64.exe'
    Write-Log "Descargando instalador de usuario desde $($script:DirectUrl)"
    Invoke-WebRequest -Uri $script:DirectUrl -OutFile $instalador -UseBasicParsing

    $firma = Get-AuthenticodeSignature -FilePath $instalador
    if ($firma.Status -ne 'Valid' -or $firma.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        Remove-Item -LiteralPath $instalador -Force -ErrorAction SilentlyContinue
        throw "La firma digital del instalador no es válida (estado: $($firma.Status))."
    }
    Write-Log 'Firma Authenticode del instalador validada.' 'OK'

    $proceso = Start-Process -FilePath $instalador -ArgumentList (Get-InnoArguments) -Wait -PassThru
    Remove-Item -LiteralPath $instalador -Force -ErrorAction SilentlyContinue
    Write-Log ("El instalador finalizó con código {0}." -f $proceso.ExitCode)
    return ($proceso.ExitCode -eq 0)
}

# --------------------------------------------------------------------------
# Paso 6: verificación posterior
# --------------------------------------------------------------------------
function Test-Installation {
    $correcto = $true
    $codeExe  = Join-Path $script:InstallDir 'Code.exe'
    $codeCmd  = Join-Path $script:InstallDir 'bin\code.cmd'

    if (Test-Path -LiteralPath $codeExe) {
        $version = (Get-Item -LiteralPath $codeExe).VersionInfo.ProductVersion
        Write-Log "Code.exe presente. Versión: $version" 'OK'
    }
    else { Write-Log "No se encontró $codeExe" 'ERROR'; $correcto = $false }

    if (Test-Path -LiteralPath $codeCmd) { Write-Log 'bin\code.cmd presente.' 'OK' }
    else { Write-Log "No se encontró $codeCmd" 'WARN' }

    $pathUsuario = [Environment]::GetEnvironmentVariable('Path', 'User')
    $binDir      = (Join-Path $script:InstallDir 'bin').TrimEnd('\')
    $enPath = @($pathUsuario -split ';' | Where-Object { $_.TrimEnd('\') -ieq $binDir }).Count -gt 0
    if ($enPath) { Write-Log "PATH de usuario contiene: $binDir" 'OK' }
    else { Write-Log "PATH de usuario NO contiene: $binDir" 'WARN' }

    $accesos = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Visual Studio Code.lnk'),
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk')
    )
    foreach ($acceso in $accesos) {
        if (Test-Path -LiteralPath $acceso) { Write-Log "Acceso directo: $acceso" 'OK' }
        else { Write-Log "Acceso directo no hallado: $acceso" 'WARN' }
    }

    # Actualiza el PATH de la sesión actual para poder usar "code" sin reiniciar la consola.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + $pathUsuario
    return $correcto
}

# --------------------------------------------------------------------------
# Programa principal
# --------------------------------------------------------------------------
function Invoke-Main {
    try {
        $script:InstallDir = Join-Path $ProgramsDir $AppFolderName
        Write-Log "Registro: $($script:LogFile)"
        Write-Log "Destino de instalación: $($script:InstallDir)"

        if ($script:InstallDir -match '\s') {
            throw 'La ruta de instalación no debe contener espacios (restricción de los argumentos de Inno Setup).'
        }
        if ($AppFolderName -in @('.', '..')) { throw 'Nombre de carpeta de aplicación no válido.' }
        if (Test-IsAdministrator) {
            Write-Log 'Se ejecuta con privilegios administrativos; el script está diseñado para cuentas estándar. La instalación será del usuario actual.' 'WARN'
        }

        # Paso 1
        Write-Log 'Paso 1: verificando instalaciones previas de Visual Studio Code...'
        $previas = Get-VSCodeInstallations
        $delEquipo  = @($previas | Where-Object { $_.Ambito -eq 'Equipo' })
        $delUsuario = @($previas | Where-Object { $_.Ambito -eq 'Usuario' })

        if ($previas.Count -eq 0) { Write-Log 'No se detectaron instalaciones previas.' 'OK' }
        foreach ($p in $previas) { Write-Log ("Detectada [{0}] {1} -> {2}" -f $p.Ambito, $p.Nombre, $p.Ubicacion) 'WARN' }

        if ($delEquipo.Count -gt 0) {
            Write-Log 'Existe una instalación de ámbito EQUIPO. No puede retirarse sin privilegios administrativos; convivirá con la de usuario y, por el orden del PATH, el comando "code" podría resolverse a la del equipo.' 'WARN'
        }

        # Paso 2
        if ($delUsuario.Count -gt 0) {
            Write-Log 'Paso 2a: reemplazando la instalación de usuario existente...'
            Remove-VSCodeUserInstallation -Instalaciones $delUsuario
        }

        # Paso 2 (carpetas)
        Write-Log 'Paso 2b: creando estructura de carpetas...'
        if (-not (New-InstallFolders)) { return 2 }

        # Paso 3
        Write-Log 'Paso 3: instalando Visual Studio Code...'
        $instalado = $false
        if (-not $SkipWinget -and (Test-WingetAvailable)) {
            $instalado = Install-ViaWinget
            if (-not $instalado) { Write-Log 'winget no completó la instalación; se intentará la descarga directa.' 'WARN' }
        }
        elseif (-not $SkipWinget) {
            Write-Log 'winget no está disponible; se usará la descarga directa.' 'WARN'
        }
        if (-not $instalado) { $instalado = Install-ViaDirectDownload }
        if (-not $instalado) { Write-Log 'La instalación no finalizó correctamente.' 'ERROR'; return 3 }

        # Paso 4
        Write-Log 'Paso 4: verificando la instalación...'
        if (-not (Test-Installation)) { return 4 }

        Write-Log 'Instalación completada. Abra una NUEVA terminal y ejecute: code --version' 'OK'
        return 0
    }
    catch {
        Write-Log ("Error: {0}" -f $_.Exception.Message) 'ERROR'
        return 1
    }
}

# Permite cargar el archivo con "dot-sourcing" en las pruebas sin ejecutar la instalación.
if ($MyInvocation.InvocationName -ne '.') {
    $codigoSalida = Invoke-Main
    exit $codigoSalida
}
