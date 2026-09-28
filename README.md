# vscode-user-install-windows

Instalación **por usuario** de Visual Studio Code en **Windows 11** con una **cuenta local sin privilegios administrativos**, mediante scripts de **PowerShell** y **CMD** basados en `winget`.

![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?logo=windows11&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![CMD](https://img.shields.io/badge/CMD-batch-4D4D4D)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Tabla de contenidos

1. [Descripción](#descripción)
2. [Requisitos previos](#requisitos-previos)
3. [Instalación paso a paso](#instalación-paso-a-paso)
4. [Entorno virtual y dependencias](#entorno-virtual-y-dependencias)
5. [Configuración de variables de entorno](#configuración-de-variables-de-entorno)
6. [Migraciones y datos iniciales](#migraciones-y-datos-iniciales)
7. [Ejecución](#ejecución)
8. [Pruebas](#pruebas)
9. [Estructura del proyecto](#estructura-del-proyecto)
10. [Solución de problemas](#solución-de-problemas)
11. [Publicación en GitHub y GitLab](#publicación-en-github-y-gitlab)
12. [Autor](#autor)
13. [Licencia](#licencia)

## Descripción

Los scripts automatizan el equivalente a:

```powershell
winget install -e --id Microsoft.VisualStudioCode --scope user
```

> **Nota:** el identificador se escribe con **dos guiones ASCII** (`--id`). Un guion largo tipográfico (`—id`), habitual al copiar desde procesadores de texto, es rechazado por `winget`.

Flujo de ejecución:

1. **Detecta** instalaciones previas de VS Code (registro de Windows y rutas conocidas).
2. **Reemplaza** la instalación de ámbito *usuario* si existe (desinstalación y limpieza de la carpeta de destino).
3. **Crea** `C:\Programs\` y, dentro, `VSCode\`, y comprueba que puede escribir en ella.
4. **Instala** en `C:\Programs\VSCode` habilitando: acceso directo de escritorio y del menú Inicio, menú contextual (archivos y carpetas), asociación de archivos y adición de `bin\` al **PATH del usuario** (variable de entorno).
5. **Respaldo:** si `winget` no está disponible o falla, descarga el instalador de usuario oficial, **valida su firma Authenticode** y lo ejecuta.
6. **Verifica** `Code.exe`, `bin\code.cmd`, PATH y accesos directos.

### Limitaciones conocidas

| Situación | Comportamiento |
|---|---|
| Existe VS Code de ámbito **equipo** (`C:\Program Files\...`) | No puede desinstalarse sin administrador. El script lo **advierte** y continúa; el PATH del sistema precede al del usuario, por lo que `code` podría resolverse a la instalación del equipo. |
| Una directiva (GPO/AppLocker) impide crear `C:\Programs` | Termina con código `2` y un mensaje explícito. Use `VSCODE_PROGRAMS_DIR` con otra ruta. |
| Ruta de instalación con espacios | Se rechaza (restricción de los argumentos de Inno Setup usados por el instalador). |

## Requisitos previos

- Windows 11 (x64) con cuenta local **estándar** (no se requiere administrador).
- PowerShell 5.1 (incluido en Windows 11) para el script `.ps1`; CMD para el `.cmd`.
- `winget` (App Installer) recomendado; si falta, se usa la descarga directa (requiere `curl.exe`, incluido en Windows 11).
- Acceso a Internet.
- Git (solo para clonar/publicar el repositorio).

## Instalación paso a paso

1. Clone el repositorio (o descomprima el `.zip`):

   ```powershell
   git clone https://github.com/andres-gutierrezri/vscode-user-install-windows.git
   cd vscode-user-install-windows
   ```

2. Ejecute **una** de las dos variantes.

   **PowerShell** (`-ExecutionPolicy Bypass` se aplica solo a este proceso y no modifica la política del equipo):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-VSCode.ps1
   ```

   **CMD**:

   ```bat
   src\Install-VSCode.cmd
   ```

3. Abra una **nueva** terminal y compruebe:

   ```powershell
   code --version
   ```

> Si los archivos provienen de Internet y Windows los bloquea: `Unblock-File .\src\Install-VSCode.ps1`.

## Entorno virtual y dependencias

**No aplica.** El proyecto no usa Python ni Node.js; por ello no incluye `requirements.txt` ni `package.json`, ni requiere `venv`. No hay dependencias que instalar.

## Configuración de variables de entorno

Opcionales (véase `.env.example`; los scripts **no** cargan el archivo, se definen en la sesión):

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `VSCODE_PROGRAMS_DIR` | `C:\Programs` | Carpeta contenedora |
| `VSCODE_APP_FOLDER` | `VSCode` | Subcarpeta de instalación |

```powershell
$env:VSCODE_PROGRAMS_DIR = 'D:\Programs'   # PowerShell
```
```bat
set VSCODE_PROGRAMS_DIR=D:\Programs
```

## Migraciones y datos iniciales

**No aplica.**

## Ejecución

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\src\Install-VSCode.ps1
# Parámetros: -ProgramsDir <ruta>  -AppFolderName <nombre>  -SkipWinget
```

El registro de la ejecución se guarda en `%TEMP%` (`vscode-install-*.log` o `vscode-install-cmd.log`).

Códigos de salida: `0` éxito · `1` error general · `2` sin permisos de carpeta · `3` fallo de instalación · `4` verificación fallida.

## Pruebas

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-VSCodeInstall.ps1
```
```bat
tests\test-vscode-install.cmd
```

La sección estática valida sintaxis y contenido esencial; la sección posterior a la instalación verifica el resultado real.

## Estructura del proyecto

```
vscode-user-install-windows/
├── src/
│   ├── Install-VSCode.ps1        # Instalador en PowerShell
│   └── Install-VSCode.cmd        # Instalador en CMD
├── tests/
│   ├── Test-VSCodeInstall.ps1    # Pruebas estáticas y posteriores a la instalación
│   └── test-vscode-install.cmd   # Verificación posterior en CMD
├── docs/
│   ├── ARQUITECTURA.md           # Diagrama de flujo y decisiones de diseño
│   └── PUBLICACION_GIT.md        # Publicación en GitHub y GitLab (detallada)
├── .env.example                  # Variables opcionales
├── .gitattributes                # CRLF para scripts de Windows
├── .gitignore
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Solución de problemas

| Síntoma | Causa probable | Acción |
|---|---|---|
| `winget` no se reconoce | App Installer ausente | El script usa descarga directa automáticamente. |
| Código de salida `2` | Directiva sobre la raíz de `C:\` | Defina `VSCODE_PROGRAMS_DIR` con otra ruta. |
| `code` abre otra versión | Instalación de ámbito equipo con prioridad en PATH | Solicite a TI su retiro. |
| `code` no se reconoce | La terminal se abrió antes de instalar | Abra una terminal nueva. |

## Publicación en GitHub y GitLab

Procedimiento completo, comando por comando (HTTPS/SSH/PAT, doble remoto, Git Flow, Conventional Commits, SemVer): consulte [`docs/PUBLICACION_GIT.md`](docs/PUBLICACION_GIT.md).

## Autor

**Ingeniero Andrés Felipe Gutiérrez Rivera**

- GitHub: <https://github.com/andres-gutierrezri>
- GitLab: <https://gitlab.com/andres.gutierrezri>
- LinkedIn: <https://www.linkedin.com/in/felipe-gutierrezri>

## Licencia

Distribuido bajo licencia [MIT](LICENSE).
