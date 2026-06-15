#!/bin/bash
# Gerenciador ERP - Instalação Linux (Debian/Ubuntu)
# Uso: sudo bash install.sh
# Auto-detecta se está dentro do repositório; se não, baixa do GitHub
# sem necessidade de conta GitHub (usa ZIP via wget/curl).

set -e

REPO_URL="https://github.com/VICTORGG04/GerenciadorClaude.git"
ZIP_URL="https://github.com/VICTORGG04/GerenciadorClaude/archive/refs/heads/master.zip"
RELEASE_DEB_URL="https://github.com/VICTORGG04/GerenciadorClaude/releases/latest/download/gerenciador-erp_1.0.1_amd64.deb"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "   Gerenciador ERP - Instalação Linux"
echo "============================================"
echo ""

# ── Verificar root ──────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash install.sh"
    exit 1
fi

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
download_and_build() {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo ">>> Baixando repositório via ZIP (sem necessidade de git)..."

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$tmpdir/repo.zip" "$ZIP_URL"
    elif command -v wget &>/dev/null; then
        wget -q -O "$tmpdir/repo.zip" "$ZIP_URL"
    else
        echo "ERRO: Nem curl nem wget disponíveis. Instale: sudo apt install curl"
        exit 1
    fi

    if [ ! -f "$tmpdir/repo.zip" ] || [ ! -s "$tmpdir/repo.zip" ]; then
        echo "ERRO: Falha ao baixar o repositório."
        exit 1
    fi

    if ! command -v unzip &>/dev/null; then
        echo ">>> Instalando unzip..."
        apt install -y unzip
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

# ── Função para baixar .deb pré-compilado ──────────────────────────────────
download_deb() {
    local dest="$1"
    echo ">>> Tentando baixar pacote .deb pré-compilado..."
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$dest" "$RELEASE_DEB_URL" && return 0
    elif command -v wget &>/dev/null; then
        wget -q -O "$dest" "$RELEASE_DEB_URL" && return 0
    fi
    return 1
}

# ── Encontrar ou obter o pacote .deb ────────────────────────────────────────
DEB_FILE=""

# Passo 1: .deb local
if [ -z "$DEB_FILE" ]; then
    local_deb=$(find "$SCRIPT_DIR" -maxdepth 1 -name '*.deb' 2>/dev/null | head -1)
    if [ -n "$local_deb" ]; then
        echo ">>> Pacote .deb encontrado localmente."
        DEB_FILE="$local_deb"
    fi
fi

# Passo 2: construir a partir do repositório local
if [ -z "$DEB_FILE" ] && [ -n "$REPO_DIR" ]; then
    echo ">>> Repositório encontrado em: $REPO_DIR"
    cd "$REPO_DIR"
    echo ">>> Construindo pacote .deb..."
    bash "APK--DEB--BAT(Software)/linux/build.sh"
    DEB_FILE=$(ls -t APK--DEB--BAT\(Software\)/linux/gerenciador-erp_*.deb 2>/dev/null | head -1)
fi

# Passo 3: baixar .deb pré-compilado do GitHub Releases
if [ -z "$DEB_FILE" ]; then
    tmp_deb="/tmp/gerenciador-erp_1.0.1_amd64.deb"
    if download_deb "$tmp_deb"; then
        DEB_FILE="$tmp_deb"
    fi
fi

# Passo 4: baixar ZIP, extrair e construir
if [ -z "$DEB_FILE" ]; then
    echo ">>> Baixando repositório para compilar..."
    TMP_REPO=$(download_and_build)
    cd "$TMP_REPO"
    bash "APK--DEB--BAT(Software)/linux/build.sh"
    DEB_FILE=$(ls -t APK--DEB--BAT\(Software\)/linux/gerenciador-erp_*.deb 2>/dev/null | head -1)
fi

# ── Verificar se temos o .deb ───────────────────────────────────────────────
if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
    echo "ERRO: Não foi possível obter o pacote .deb."
    echo ""
    echo "Tente manualmente:"
    echo "  1. git clone $REPO_URL"
    echo "  2. cd GerenciadorClaude"
    echo "  3. sudo bash APK--DEB--BAT\(Software\)/linux/install.sh"
    exit 1
fi

echo ">>> Instalando pacote: $DEB_FILE"
apt install -y "$DEB_FILE"

echo ""
echo "============================================"
echo "   Instalação concluída!"
echo "============================================"
echo ""
echo "   Próximos passos:"
echo ""
echo "   1. Configure o banco PostgreSQL:"
echo "      sudo -u postgres createdb gerenciador_estoque"
echo "      sudo -u postgres psql -c \"CREATE USER gerenciador_erp WITH PASSWORD 'sua_senha';\""
echo "      sudo -u postgres psql -c \"GRANT ALL ON DATABASE gerenciador_estoque TO gerenciador_erp;\""
echo ""
echo "   2. Edite /etc/gerenciador-erp/.env com as credenciais"
echo ""
echo "   3. Inicie o serviço:"
echo "      sudo systemctl enable --now gerenciador-erp"
echo ""
echo "   4. Acesse: http://localhost:4568"
echo "      Login: admin@gerenciador.local"
echo "      Senha: admin123"
echo ""
