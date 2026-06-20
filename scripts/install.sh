#!/bin/bash
# Gerenciador ERP - Instalação universal
# Uso: bash install.sh
# Detecta a plataforma e delega para o instalador correto.
# Também funciona como one-liner:
#   curl -fsSL https://raw.githubusercontent.com/VICTORGG04/GerenciadorClaude/master/install.sh | bash

set -e

REPO_URL="https://github.com/VICTORGG04/GerenciadorClaude.git"
RAW_BASE="https://raw.githubusercontent.com/VICTORGG04/GerenciadorClaude/master"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd 2>/dev/null || pwd)"

# ── Cores para output ─────────────────────────────────────────────────────────
VERDE='\033[0;32m'; AMARELO='\033[1;33m'; VERMELHO='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'
info()  { echo -e "${CYAN}>>>${RESET} $1"; }
ok()    { echo -e "${VERDE}>>>${RESET} $1"; }
erro()  { echo -e "${VERMELHO}ERRO:${RESET} $1"; }
aviso() { echo -e "${AMARELO}>>>${RESET} $1"; }

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

# ── Detecta plataforma ──────────────────────────────────────────────────────
detect_platform() {
    case "$(uname -s)" in
        Linux)  echo "linux" ;;
        Darwin) echo "macos" ;;
        *)      echo "windows" ;;
    esac
}

# ── Função para baixar e executar script remoto ────────────────────────────
run_remote() {
    local script_path="$1"
    local url="$RAW_BASE/$script_path"

    if command -v curl &>/dev/null; then
        bash <(curl -fsSL "$url")
    elif command -v wget &>/dev/null; then
        bash <(wget -q -O - "$url")
    else
        erro "Nem curl nem wget disponíveis."
        exit 1
    fi
}

PLATFORM=$(detect_platform)
REPO_DIR=$(find_repo "$SCRIPT_DIR")

echo "============================================"
echo "   Gerenciador ERP - Instalação Universal"
echo "============================================"
echo ""

if [ -n "$REPO_DIR" ]; then
    ok "Repositório encontrado em: $REPO_DIR"
    INSTALL_SCRIPT="$REPO_DIR/deploy/$PLATFORM/install.sh"

    if [ "$PLATFORM" = "macos" ]; then
        INSTALL_SCRIPT="$REPO_DIR/deploy/macos/start.command"
    fi

    if [ "$PLATFORM" = "windows" ]; then
        aviso "No Windows, execute manualmente:"
        echo "  deploy\\windows\\setup.bat"
        echo "  (como Administrador)"
        exit 0
    fi

    if [ -f "$INSTALL_SCRIPT" ]; then
        ok "Executando instalador para $PLATFORM..."
        bash "$INSTALL_SCRIPT"
    else
        erro "Instalador não encontrado: $INSTALL_SCRIPT"
        echo "Verifique se a plataforma '$PLATFORM' tem install.sh em deploy/"
        exit 1
    fi
else
    info "Repositório não encontrado localmente."
    info "Baixando instalador para $PLATFORM do GitHub..."

    REMOTE_PATH="deploy/$PLATFORM/install.sh"
    if [ "$PLATFORM" = "macos" ]; then
        REMOTE_PATH="deploy/macos/start.command"
    fi

    if [ "$PLATFORM" = "windows" ]; then
        aviso "No Windows, visite o repositório e baixe:"
        echo "  https://github.com/VICTORGG04/GerenciadorClaude"
        echo "  Execute deploy\\windows\\setup.bat como Administrador"
        exit 0
    fi

    run_remote "$REMOTE_PATH"
fi
