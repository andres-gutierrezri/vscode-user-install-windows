@echo off
rem ---------------------------------------------------------------------
rem  test-vscode-install.cmd
rem  Verificacion posterior a la instalacion (solo ASCII).
rem  Salida: 0 si todas las pruebas pasan; en otro caso, numero de fallos.
rem ---------------------------------------------------------------------
setlocal EnableExtensions DisableDelayedExpansion
set "PROGRAMS_DIR=C:\Programs"
if defined VSCODE_PROGRAMS_DIR set "PROGRAMS_DIR=%VSCODE_PROGRAMS_DIR%"
set "INSTALL_DIR=%PROGRAMS_DIR%\VSCode"
set /a FALLOS=0
set /a PASADAS=0

if exist "%INSTALL_DIR%\Code.exe" (call :ok "Code.exe existe") else (call :ko "Code.exe existe")
if exist "%INSTALL_DIR%\bin\code.cmd" (call :ok "bin\code.cmd existe") else (call :ko "bin\code.cmd existe")

reg query "HKCU\Environment" /v Path 2>nul | find /i "%INSTALL_DIR%\bin" >nul
if errorlevel 1 (call :ko "PATH de usuario incluye bin de VS Code") else (call :ok "PATH de usuario incluye bin de VS Code")

if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Visual Studio Code\Visual Studio Code.lnk" (call :ok "Acceso directo del menu Inicio") else (call :ko "Acceso directo del menu Inicio")

call "%INSTALL_DIR%\bin\code.cmd" --version >nul 2>&1
if errorlevel 1 (call :ko "code --version responde") else (call :ok "code --version responde")

echo.
echo Resultado: %PASADAS% pasadas, %FALLOS% fallidas.
set "RC=%FALLOS%"
endlocal & exit /b %RC%

:ok
echo [PASA ] %~1
set /a PASADAS+=1
exit /b 0

:ko
echo [FALLA] %~1
set /a FALLOS+=1
exit /b 0
