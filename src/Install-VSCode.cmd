@echo off
rem =====================================================================
rem  Install-VSCode.cmd
rem  Instala Visual Studio Code (edicion "User") en Windows 11 SIN
rem  privilegios administrativos, en C:\Programs\VSCode.
rem
rem  Autor  : Ingeniero Andres Felipe Gutierrez Rivera
rem  Version: 1.0.0   Licencia: MIT
rem
rem  Variables de entorno opcionales:
rem    VSCODE_PROGRAMS_DIR  (por defecto C:\Programs)
rem    VSCODE_APP_FOLDER    (por defecto VSCode)
rem
rem  Codigos de salida: 0 exito | 1 error general | 2 sin permisos de
rem  carpeta | 3 fallo de instalacion | 4 verificacion fallida.
rem
rem  Nota: el archivo usa solo caracteres ASCII para evitar problemas de
rem  pagina de codigos en cmd.exe.
rem =====================================================================
setlocal EnableExtensions DisableDelayedExpansion

set "PACKAGE_ID=Microsoft.VisualStudioCode"
set "DIRECT_URL=https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"

set "PROGRAMS_DIR=C:\Programs"
if defined VSCODE_PROGRAMS_DIR set "PROGRAMS_DIR=%VSCODE_PROGRAMS_DIR%"
set "APP_FOLDER=VSCode"
if defined VSCODE_APP_FOLDER set "APP_FOLDER=%VSCODE_APP_FOLDER%"
set "INSTALL_DIR=%PROGRAMS_DIR%\%APP_FOLDER%"

rem "!runcode" evita abrir VS Code al terminar; el resto habilita acceso directo de
rem escritorio, menu contextual, asociacion de archivos y PATH de usuario.
rem (DelayedExpansion esta deshabilitada a proposito: el signo "!" debe ser literal.)
set "MERGE_TASKS=!runcode,desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"
set "INNO_ARGS=/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=%INSTALL_DIR% /MERGETASKS=%MERGE_TASKS%"
rem Variante con comillas para lanzar el instalador directamente (las comas quedan protegidas).
set "INNO_ARGS_Q=/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=%INSTALL_DIR% /MERGETASKS="%MERGE_TASKS%""
set "LOG_FILE=%TEMP%\vscode-install-cmd.log"

call :log INFO "Registro: %LOG_FILE%"
call :log INFO "Destino de instalacion: %INSTALL_DIR%"

rem ---------- Validaciones iniciales ----------
if "%APP_FOLDER%"=="." goto :bad_folder
if "%APP_FOLDER%"==".." goto :bad_folder
echo "%INSTALL_DIR%"| find " " >nul
if not errorlevel 1 goto :bad_spaces

fltmc >nul 2>&1
if not errorlevel 1 call :log WARN "Se ejecuta como administrador; el script esta pensado para cuentas estandar. Se instalara para el usuario actual."

rem ---------- Paso 1: deteccion de instalaciones previas ----------
call :log INFO "Paso 1: verificando instalaciones previas de Visual Studio Code..."
call :detect
if not defined FOUND_USER if not defined FOUND_MACHINE call :log OK "No se detectaron instalaciones previas."
if defined FOUND_MACHINE call :log WARN "Existe una instalacion de ambito EQUIPO (Program Files). No puede retirarse sin privilegios administrativos; convivira con la de usuario y el comando code podria resolverse a la del equipo."
if not defined FOUND_USER goto :step_folders

rem ---------- Paso 2a: reemplazo de la instalacion de usuario ----------
call :log INFO "Paso 2a: reemplazando la instalacion de usuario existente..."
call :uninstall_user
if errorlevel 1 goto :fail_uninstall

:step_folders
rem ---------- Paso 2b: carpetas C:\Programs\VSCode ----------
call :log INFO "Paso 2b: creando estructura de carpetas..."
if not exist "%PROGRAMS_DIR%" mkdir "%PROGRAMS_DIR%" 2>>"%LOG_FILE%"
if not exist "%PROGRAMS_DIR%" goto :fail_folder
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%" 2>>"%LOG_FILE%"
if not exist "%INSTALL_DIR%" goto :fail_folder
> "%INSTALL_DIR%\.write-test" echo ok 2>nul
if not exist "%INSTALL_DIR%\.write-test" goto :fail_folder
del /q "%INSTALL_DIR%\.write-test" >nul 2>&1
call :log OK "Carpetas listas: %INSTALL_DIR%"

rem ---------- Paso 3: instalacion ----------
call :log INFO "Paso 3: instalando Visual Studio Code (puede tardar unos minutos)..."
where winget >nul 2>&1
if errorlevel 1 goto :do_direct
call :install_winget
if not errorlevel 1 goto :verify
call :log WARN "winget no completo la instalacion; se intentara la descarga directa."
goto :do_direct_run

:do_direct
call :log WARN "winget no esta disponible; se usara la descarga directa."
:do_direct_run
call :install_direct
if errorlevel 1 goto :fail_install

rem ---------- Paso 4: verificacion ----------
:verify
call :log INFO "Paso 4: verificando la instalacion..."
if not exist "%INSTALL_DIR%\Code.exe" goto :fail_verify
call :log OK "Code.exe presente."
if exist "%INSTALL_DIR%\bin\code.cmd" (call :log OK "bin\code.cmd presente.") else (call :log WARN "No se encontro bin\code.cmd")

reg query "HKCU\Environment" /v Path 2>nul | find /i "%INSTALL_DIR%\bin" >nul
if errorlevel 1 (call :log WARN "El PATH de usuario NO contiene %INSTALL_DIR%\bin") else (call :log OK "PATH de usuario contiene %INSTALL_DIR%\bin")

set "LNK_DESKTOP="
if exist "%USERPROFILE%\Desktop\Visual Studio Code.lnk" set "LNK_DESKTOP=1"
if defined OneDrive if exist "%OneDrive%\Desktop\Visual Studio Code.lnk" set "LNK_DESKTOP=1"
if defined LNK_DESKTOP (call :log OK "Acceso directo de escritorio presente.") else (call :log WARN "Acceso directo de escritorio no hallado.")
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk" (call :log OK "Acceso directo del menu Inicio presente.") else (call :log WARN "Acceso directo del menu Inicio no hallado.")

call :log OK "Instalacion completada. Abra una NUEVA terminal y ejecute: code --version"
endlocal
exit /b 0

rem =====================================================================
rem  Salidas de error
rem =====================================================================
:bad_folder
call :log ERROR "Nombre de carpeta de aplicacion no valido."
endlocal
exit /b 1

:bad_spaces
call :log ERROR "La ruta de instalacion no debe contener espacios (restriccion de los argumentos de Inno Setup)."
endlocal
exit /b 1

:fail_uninstall
call :log ERROR "La instalacion previa de usuario no pudo retirarse."
endlocal
exit /b 1

:fail_folder
call :log ERROR "Sin permisos para crear o escribir en %PROGRAMS_DIR%. Una directiva puede restringir la raiz de la unidad."
endlocal
exit /b 2

:fail_install
call :log ERROR "La instalacion no finalizo correctamente. Revise el registro: %LOG_FILE%"
endlocal
exit /b 3

:fail_verify
call :log ERROR "No se encontro %INSTALL_DIR%\Code.exe tras la instalacion."
endlocal
exit /b 4

rem =====================================================================
rem  Subrutinas
rem =====================================================================
:log
echo [%~1] %~2
>>"%LOG_FILE%" echo [%date% %time%] [%~1] %~2
exit /b 0

:detect
set "FOUND_USER="
set "FOUND_MACHINE="
if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" set "FOUND_USER=1"
if exist "%INSTALL_DIR%\Code.exe" set "FOUND_USER=1"
if exist "%ProgramFiles%\Microsoft VS Code\Code.exe" set "FOUND_MACHINE=1"
if exist "%ProgramFiles(x86)%\Microsoft VS Code\Code.exe" set "FOUND_MACHINE=1"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Microsoft Visual Studio Code (User)" /d /e >nul 2>&1
if not errorlevel 1 set "FOUND_USER=1"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Microsoft Visual Studio Code" /d /e >nul 2>&1
if not errorlevel 1 set "FOUND_USER=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Microsoft Visual Studio Code" /d /e >nul 2>&1
if not errorlevel 1 set "FOUND_MACHINE=1"
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Microsoft Visual Studio Code" /d /e >nul 2>&1
if not errorlevel 1 set "FOUND_MACHINE=1"
if defined FOUND_USER call :log WARN "Detectada instalacion de ambito USUARIO."
if defined FOUND_MACHINE call :log WARN "Detectada instalacion de ambito EQUIPO."
exit /b 0

:uninstall_user
call :log INFO "Cerrando procesos de Visual Studio Code del usuario actual..."
taskkill /IM Code.exe /F /T >nul 2>&1
where winget >nul 2>&1
if errorlevel 1 goto :uninstall_inno
call :log INFO "Desinstalando con winget (--scope user)..."
winget uninstall -e --id %PACKAGE_ID% --scope user --silent --accept-source-agreements >>"%LOG_FILE%" 2>&1
:uninstall_inno
rem Respaldo: desinstalador propio de Inno Setup (unins000.exe) en las rutas de usuario.
if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\unins000.exe" start "" /wait "%LOCALAPPDATA%\Programs\Microsoft VS Code\unins000.exe" /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
if exist "%INSTALL_DIR%\Code.exe" if exist "%INSTALL_DIR%\unins000.exe" start "" /wait "%INSTALL_DIR%\unins000.exe" /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
set /a TRIES=0
:wait_removed
if not exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" if not exist "%INSTALL_DIR%\Code.exe" goto :removed_ok
set /a TRIES+=1
if %TRIES% GTR 45 exit /b 1
ping -n 3 127.0.0.1 >nul
goto :wait_removed
:removed_ok
rem Limpieza de residuos SOLO dentro de la carpeta de destino de este script.
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" >nul 2>&1
call :log OK "Instalacion previa de usuario retirada."
exit /b 0

:install_winget
winget install -e --id %PACKAGE_ID% --scope user --silent --accept-package-agreements --accept-source-agreements --override "%INNO_ARGS%" >>"%LOG_FILE%" 2>&1
set "RC=%ERRORLEVEL%"
call :log INFO "winget install finalizo con codigo %RC%."
exit /b %RC%

:install_direct
set "SETUP=%TEMP%\VSCodeUserSetup-x64.exe"
where curl.exe >nul 2>&1
if errorlevel 1 (call :log ERROR "curl.exe no esta disponible." & exit /b 1)
call :log INFO "Descargando instalador de usuario desde %DIRECT_URL%"
curl.exe -L --fail --silent --show-error -o "%SETUP%" "%DIRECT_URL%"
if errorlevel 1 (call :log ERROR "Fallo la descarga del instalador." & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-AuthenticodeSignature -FilePath '%SETUP%'; if ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'Microsoft Corporation') { exit 0 } else { exit 1 }"
if errorlevel 1 (del /q "%SETUP%" >nul 2>&1 & call :log ERROR "La firma digital del instalador no es valida." & exit /b 1)
call :log OK "Firma Authenticode del instalador validada."
start "" /wait "%SETUP%" %INNO_ARGS_Q%
set "RC=%ERRORLEVEL%"
del /q "%SETUP%" >nul 2>&1
call :log INFO "El instalador finalizo con codigo %RC%."
exit /b %RC%
