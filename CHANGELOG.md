# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [SemVer](https://semver.org/lang/es/).

## [1.0.0] - 2026-09-28
### Añadido
- Script `src/Install-VSCode.ps1` (PowerShell 5.1+) y `src/Install-VSCode.cmd` (CMD).
- Detección de instalaciones previas (registro y rutas conocidas) y reemplazo de la instalación de usuario.
- Creación de `C:\Programs\VSCode` con prueba real de escritura.
- Instalación con `winget --scope user`, accesos directos, menú contextual, asociación de archivos y PATH de usuario.
- Respaldo por descarga directa con validación de firma Authenticode.
- Pruebas en `tests/` y documentación en `docs/`.
