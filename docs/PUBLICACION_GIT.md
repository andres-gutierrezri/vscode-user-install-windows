# Publicación en GitHub y GitLab

Cuentas: GitHub `andres-gutierrezri` · GitLab `andres.gutierrezri`. Repositorio sugerido: `vscode-user-install-windows`.

## 1. Inicializar y configurar

```bash
git init                                              # crea el repositorio local (.git)
git config --global user.name  "Andrés Felipe Gutiérrez Rivera"
git config --global user.email "felipe.gutierrezri@gmail.com"
git config --global init.defaultBranch main
git config --global core.autocrlf false               # .gitattributes gestiona los finales de línea
```

## 2. Primer commit

```bash
git add .
git status                                            # revise qué se incluirá
git commit -m "feat: versión inicial del instalador de VS Code sin administrador"
git branch -M main                                    # renombra la rama principal a main
```

## 3. Crear los repositorios remotos (interfaz web)

- GitHub: *New repository* → nombre `vscode-user-install-windows` → **sin** README/.gitignore/licencia (ya existen localmente).
- GitLab: *New project → Create blank project* → mismo nombre → desmarcar *Initialize with a README*.

## 4. Vincular y publicar (un remoto)

```bash
git remote add origin https://github.com/andres-gutierrezri/vscode-user-install-windows.git
git remote -v
git push -u origin main
```

## 5. Doble remoto (push simultáneo a GitHub y GitLab)

**Opción A — un solo remoto `origin` con dos URL de envío:**

```bash
git remote add origin git@github.com:andres-gutierrezri/vscode-user-install-windows.git
git remote set-url --add --push origin git@github.com:andres-gutierrezri/vscode-user-install-windows.git
git remote set-url --add --push origin git@gitlab.com:andres.gutierrezri/vscode-user-install-windows.git
git remote -v            # fetch: GitHub; push: GitHub y GitLab
git push -u origin main  # publica en ambos
```

**Opción B — remotos separados (más explícita):**

```bash
git remote add github git@github.com:andres-gutierrezri/vscode-user-install-windows.git
git remote add gitlab git@gitlab.com:andres.gutierrezri/vscode-user-install-windows.git
git push -u github main
git push -u gitlab main
```

## 6. Autenticación

### 6.1 SSH (recomendado)

```bash
ssh-keygen -t ed25519 -C "felipe.gutierrezri@gmail.com"   # genera ~/.ssh/id_ed25519 y .pub
type $env:USERPROFILE\.ssh\id_ed25519.pub                 # PowerShell: muestra la clave pública
```

Copie la clave pública en *GitHub → Settings → SSH and GPG keys* y en *GitLab → Preferences → SSH Keys*. Luego:

```bash
ssh -T git@github.com
ssh -T git@gitlab.com
```

> En una cuenta estándar no se puede cambiar el tipo de inicio del servicio `ssh-agent` (requiere administrador). Alternativas: usar la clave con frase de paso sin agente, o iniciar el agente incluido en Git Bash con `eval $(ssh-agent -s)` y `ssh-add`.

### 6.2 Token de acceso personal (PAT) sobre HTTPS

- GitHub: *Settings → Developer settings → Personal access tokens* (fine-grained, permiso *Contents: Read and write*).
- GitLab: *Preferences → Access Tokens* con el alcance `write_repository`.

Al ejecutar `git push` por HTTPS, use su usuario y **el token como contraseña**. Git Credential Manager (incluido en Git for Windows) lo almacena de forma segura. No incluya el token en la URL ni lo versione.

## 7. Buenas prácticas

### 7.1 Ramificación (Git Flow)

```bash
git switch -c develop                       # rama de integración
git switch -c feature/soporte-winget-ps1    # nueva funcionalidad desde develop
# ... trabajo y commits ...
git switch develop && git merge --no-ff feature/soporte-winget-ps1
git switch -c release/1.0.0                 # estabilización
git switch main && git merge --no-ff release/1.0.0
git switch develop && git merge --no-ff release/1.0.0
git switch -c hotfix/1.0.1 main             # corrección urgente sobre producción
```

### 7.2 Conventional Commits

```
<tipo>[ámbito opcional]: <descripción>

feat(ps1): detectar instalaciones de ámbito equipo
fix(cmd): conservar el carácter ! en MERGETASKS
docs: ampliar guía de publicación
test: añadir verificación de PATH de usuario
chore: actualizar .gitignore
feat!: cambiar el destino por defecto   # el "!" indica cambio incompatible
```

### 7.3 Etiquetado (SemVer `MAYOR.MENOR.PARCHE`)

```bash
git tag -a v1.0.0 -m "Versión 1.0.0: instalador por usuario para Windows 11"
git push origin v1.0.0        # con doble URL de envío, se publica en ambos
git push origin --tags        # todas las etiquetas
```
