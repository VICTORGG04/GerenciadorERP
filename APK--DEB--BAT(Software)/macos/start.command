#!/bin/bash
# Gerenciador ERP - Launcher macOS
# Duplo clique no Finder ou: bash start.command
# Auto-detecta se está dentro do repositório; se não, baixa do GitHub
# sem necessidade de conta GitHub (tenta git, depois ZIP via curl).

set -e

REPO_URL="https://github.com/VICTORGG04/GerenciadorClaude.git"
ZIP_URL="https://github.com/VICTORGG04/GerenciadorClaude/archive/refs/heads/master.zip"
INSTALL_DIR="$HOME/GerenciadorERP"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "   Gerenciador ERP - macOS"
echo "============================================"
echo ""

# ── Busca app.rb subindo diretórios ─────────────────────────────────────────
find_repo() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/app.rb" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

REPO_DIR=$(find_repo "$SCRIPT_DIR")

# ── Função para baixar e extrair ZIP ───────────────────────────────────────
download_repo() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo ">>> Baixando repositório via ZIP (sem necessidade de git)..."

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$tmpdir/repo.zip" "$ZIP_URL"
    elif command -v wget &>/dev/null; then
        wget -q -O "$tmpdir/repo.zip" "$ZIP_URL"
    else
        echo "ERRO: Nem curl nem wget disponíveis."
        exit 1
    fi

    if [ ! -f "$tmpdir/repo.zip" ] || [ ! -s "$tmpdir/repo.zip" ]; then
        echo "ERRO: Falha ao baixar o repositório."
        exit 1
    fi

    unzip -q "$tmpdir/repo.zip" -d "$tmpdir"
    rm -f "$tmpdir/repo.zip"

    local extracted
    extracted=("$tmpdir"/GerenciadorClaude-*)
    if [ ${#extracted[@]} -eq 0 ] || [ ! -d "${extracted[0]}" ]; then
        echo "ERRO: Falha ao extrair o ZIP."
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"
    cp -R "${extracted[0]}" "$INSTALL_DIR/repo"
    echo "$INSTALL_DIR/repo"
}

# ── Obter repositório ───────────────────────────────────────────────────────
if [ -z "$REPO_DIR" ]; then
    echo ">>> Repositório não encontrado. Baixando do GitHub..."
    mkdir -p "$INSTALL_DIR"

    # Tenta git clone sem prompt
    if command -v git &>/dev/null; then
        echo ">>> Tentando clonar com git..."
        GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$REPO_URL" "$INSTALL_DIR/repo" 2>/dev/null && REPO_DIR="$INSTALL_DIR/repo"
    fi

    # Fallback: ZIP
    if [ -z "$REPO_DIR" ]; then
        echo ">>> Git falhou ou não disponível. Baixando ZIP..."
        REPO_DIR=$(download_repo)
    fi

    echo ">>> Repositório baixado em: $REPO_DIR"
else
    echo ">>> Repositório encontrado em: $REPO_DIR"
fi

cd "$REPO_DIR"

# ── Verificar Ruby ───────────────────────────────────────────────────────────
if ! command -v ruby &>/dev/null; then
    echo ">>> Ruby não encontrado. Instale com: brew install ruby"
    exit 1
fi

# ── Instalar bundler ─────────────────────────────────────────────────────────
if ! command -v bundle &>/dev/null; then
    gem install bundler
fi
bundle install

# ── Configurar .env ──────────────────────────────────────────────────────────
if [ ! -f .env ]; then
    cp .env.example .env
    echo ">>> Arquivo .env criado. Edite com suas configurações do PostgreSQL."
    open -e .env
    read -p "Pressione Enter após configurar o .env..."
fi

# ── Configurar banco ─────────────────────────────────────────────────────────
echo ">>> Configurando banco de dados..."
bundle exec ruby db/setup.rb 2>/dev/null || true

APP_PORT="${APP_PORT:-4568}"

echo "============================================"
echo "   Gerenciador ERP"
echo "============================================"
echo ">>> Servidor iniciando em http://localhost:$APP_PORT"
open "http://localhost:$APP_PORT"

bundle exec ruby app.rb

echo ""
echo ">>> Servidor parou."
read -p "Pressione Enter para fechar..."
