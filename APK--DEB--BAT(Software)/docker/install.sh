#!/bin/bash
# Gerenciador ERP - Instalação via Docker
# Uso: bash install.sh
# Auto-detecta se está dentro do repositório; se não, baixa do GitHub
# sem necessidade de conta GitHub (usa ZIP via wget/curl).

set -e

REPO_URL="https://github.com/VICTORGG04/GerenciadorClaude.git"
ZIP_URL="https://github.com/VICTORGG04/GerenciadorClaude/archive/refs/heads/master.zip"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "   Gerenciador ERP - Docker"
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
    echo ">>> Baixando repositório via ZIP..."

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$tmpdir/repo.zip" "$ZIP_URL"
    elif command -v wget &>/dev/null; then
        wget -q -O "$tmpdir/repo.zip" "$ZIP_URL"
    else
        echo "ERRO: Nem curl nem wget disponíveis. Instale um deles."
        exit 1
    fi

    if [ ! -f "$tmpdir/repo.zip" ] || [ ! -s "$tmpdir/repo.zip" ]; then
        echo "ERRO: Falha ao baixar o repositório."
        exit 1
    fi

    if ! command -v unzip &>/dev/null; then
        echo ">>> Instalando unzip..."
        apt install -y unzip 2>/dev/null || brew install unzip 2>/dev/null || true
    fi

    unzip -q "$tmpdir/repo.zip" -d "$tmpdir"
    rm -f "$tmpdir/repo.zip"

    local extracted
    extracted=("$tmpdir"/GerenciadorClaude-*)
    if [ ${#extracted[@]} -eq 0 ] || [ ! -d "${extracted[0]}" ]; then
        echo "ERRO: Falha ao extrair o ZIP."
        exit 1
    fi

    echo "$(cd "${extracted[0]}" && pwd)"
}

# ── Obter repositório ───────────────────────────────────────────────────────
if [ -n "$REPO_DIR" ]; then
    echo ">>> Repositório encontrado em: $REPO_DIR"
else
    # Tenta git clone sem prompt (pode falhar silenciosamente)
    if command -v git &>/dev/null; then
        TARGET_DIR="$SCRIPT_DIR/gerenciador-erp"
        echo ">>> Clonando repositório..."
        GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$REPO_URL" "$TARGET_DIR" 2>/dev/null && REPO_DIR="$TARGET_DIR"
    fi

    # Fallback: ZIP
    if [ -z "$REPO_DIR" ]; then
        REPO_DIR=$(download_repo)
    fi
fi

echo ">>> Copiando arquivos Docker para o repositório..."
cp "$SCRIPT_DIR/Dockerfile" "$REPO_DIR/"
cp "$SCRIPT_DIR/docker-compose.yml" "$REPO_DIR/"
cp "$SCRIPT_DIR/.dockerignore" "$REPO_DIR/"

cd "$REPO_DIR"

echo ">>> Construindo imagem e iniciando containers..."
docker compose up -d --build

echo ""
echo "============================================"
echo "   Servidor rodando!"
echo "============================================"
echo ""
echo "   Acesse: http://localhost:4568"
echo ""
echo "   Login: admin@gerenciador.local"
echo "   Senha: admin123"
echo ""
echo "   Comandos úteis:"
echo "   docker compose logs -f    → Ver logs"
echo "   docker compose down       → Parar"
echo "   docker compose restart    → Reiniciar"
echo ""
