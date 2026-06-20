# Gerenciador ERP - PowerShell Launcher
# Uso: powershell -ExecutionPolicy Bypass -File gerenciador-erp.ps1
# Auto-detecta se está dentro do repositório; se não, baixa do GitHub
# sem necessidade de conta GitHub (tenta git, depois ZIP).

$REPO_URL = "https://github.com/VICTORGG04/GerenciadorClaude.git"
$ZIP_URL = "https://github.com/VICTORGG04/GerenciadorClaude/archive/refs/heads/master.zip"
$INSTALL_DIR = "$env:ProgramFiles\GerenciadorERP"

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host ">>> $Msg" -ForegroundColor $Color
}

# ── Busca app.rb subindo diretórios ──────────────────────────────────────────
function Find-RepoDir {
    param([string]$StartDir)
    $dir = $StartDir
    while ($dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if (Test-Path (Join-Path $dir "app.rb")) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    # Checa também a raiz (ex: C:\)
    if (Test-Path (Join-Path $dir "app.rb")) {
        return $dir
    }
    return $null
}

# ── Baixar e extrair ZIP ─────────────────────────────────────────────────────
function Download-RepoZip {
    Write-Step "Baixando repositório via ZIP (sem necessidade de git)..." Yellow
    $zipPath = "$env:TEMP\gerenciador-erp.zip"

    try {
        Invoke-WebRequest -Uri $ZIP_URL -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Step "ERRO: Falha ao baixar o ZIP: $_" Red
        exit 1
    }

    $extractDir = "$env:TEMP\gerenciador-erp-extracted"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    } catch {
        Write-Step "ERRO: Falha ao extrair o ZIP: $_" Red
        exit 1
    }
    Remove-Item $zipPath -Force

    $extracted = @(Get-ChildItem "$extractDir" -Directory | Where-Object { $_.Name -like "GerenciadorClaude*" })
    if ($extracted.Count -eq 0) {
        Write-Step "ERRO: Estrutura inesperada no ZIP." Red
        exit 1
    }
    return $extracted[0].FullName
}

# ── Detectar / clonar repositório ────────────────────────────────────────────
$RepoDir = Find-RepoDir -StartDir $PSScriptRoot

if ($RepoDir) {
    Write-Step "Repositório encontrado em: $RepoDir" Green
} else {
    Write-Step "Repositório não encontrado. Baixando do GitHub..." Yellow

    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    # Tenta git clone (sem prompt interativo)
    try {
        $env:GIT_TERMINAL_PROMPT = 0
        git clone --depth 1 $REPO_URL "$INSTALL_DIR\repo" 2>&1 | Out-Null
        $RepoDir = "$INSTALL_DIR\repo"
        Write-Step "Repositório clonado em: $RepoDir" Green
    } catch {
        Write-Step "Git não disponível ou falhou. Usando ZIP..." Yellow
        $RepoDir = Download-RepoZip
    }
}

Set-Location $RepoDir

# ── Verificar Ruby ───────────────────────────────────────────────────────────
try {
    $rubyVer = ruby --version
    Write-Step "Ruby: $rubyVer" Green
} catch {
    Write-Step "Ruby não encontrado. Execute setup.bat como ADMINISTRADOR primeiro." Red
    Write-Step "Comando:  powershell -ExecutionPolicy Bypass -File setup.bat" Yellow
    pause; exit 1
}

# ── Verificar Bundler ────────────────────────────────────────────────────────
try {
    bundle --version | Out-Null
} catch {
    Write-Step "Instalando bundler..." Yellow
    gem install bundler
}

# ── Configurar .env ──────────────────────────────────────────────────────────
$envFile = Join-Path $RepoDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Step ".env não encontrado. Copiando de .env.example..." Yellow
    Copy-Item (Join-Path $RepoDir ".env.example") $envFile
    Write-Step "IMPORTANTE: Edite o .env com as configurações do PostgreSQL!" Red
    pause
}

# ── Instalar gems ────────────────────────────────────────────────────────────
Write-Step "Instalando dependências (bundle install)..." Yellow
bundle install

# ── Inicializar banco ────────────────────────────────────────────────────────
Write-Step "Verificando banco de dados..." Yellow
try {
    bundle exec ruby db/setup.rb
} catch {
    Write-Step "AVISO: Erro ao configurar banco. Verifique o PostgreSQL e o .env" Yellow
}

# ── Iniciar servidor ─────────────────────────────────────────────────────────
Write-Step "Iniciando servidor em http://localhost:4568 ..." Green
Start-Process "http://localhost:4568"
bundle exec ruby app.rb
