#!/bin/bash
# resetar_licenca.sh — Remove a licença ativa e volta ao plano Free
# Uso: bash scripts/resetar_licenca.sh
#
# Suporta:
#   - Instalação .deb (arquivo em /etc/gerenciador-erp/.env, requer sudo)
#   - Desenvolvimento local (arquivo no repo)
#   - Ambos (prioriza produção)

set -e

# ── Cores ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e ">>> $1"; }
ok()    { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()   { echo -e "${RED}❌ $1${NC}"; }

# ── Localizar .env ────────────────────────────────────────────────────────────
ETC_ENV="/etc/gerenciador-erp/.env"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ENV="$REPO_DIR/.env"

NEED_SUDO=false
ENV_FILE=""

if [ -f "$ETC_ENV" ]; then
  ENV_FILE="$ETC_ENV"
  # Arquivo em /etc/ quase sempre precisa de sudo (pertence ao sistema)
  if [ ! -w "$ETC_ENV" ]; then
    NEED_SUDO=true
  fi
elif [ -f "$REPO_ENV" ]; then
  ENV_FILE="$REPO_ENV"
  if [ ! -w "$REPO_ENV" ]; then
    NEED_SUDO=true
  fi
else
  err "Nenhum arquivo .env encontrado"
  echo "  Procurados:"
  echo "    $ETC_ENV"
  echo "    $REPO_ENV"
  exit 1
fi

info "Arquivo .env: $ENV_FILE"
[ "$NEED_SUDO" = true ] && info "Necessário sudo (arquivo não é acessível pelo user atual)"

# ── Verificar sudo quando necessário ──────────────────────────────────────────
if [ "$NEED_SUDO" = true ]; then
  if ! command -v sudo &>/dev/null; then
    err "sudo não encontrado. Execute manualmente:"
    echo "  sudo bash $0"
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    info "Solicitando senha sudo..."
    if ! sudo true 2>/dev/null; then
      err "Senha sudo incorreta ou cancelada"
      echo "  Execute manualmente com sudo:"
      echo "    sudo bash $0"
      exit 1
    fi
  fi
  ok "sudo autorizado"
fi

# ── Funções helper com/sem sudo ───────────────────────────────────────────────
env_read() {
  if [ "$NEED_SUDO" = true ]; then
    sudo cat "$ENV_FILE"
  else
    cat "$ENV_FILE"
  fi
}

env_backup() {
  local backup="${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
  if [ "$NEED_SUDO" = true ]; then
    sudo cp "$ENV_FILE" "$backup"
    sudo chmod 644 "$backup" 2>/dev/null || true
  else
    cp "$ENV_FILE" "$backup"
  fi
  echo "$backup"
}

env_remove_token() {
  if [ "$NEED_SUDO" = true ]; then
    sudo sed -i '/^LICENSE_TOKEN=/d' "$ENV_FILE"
  else
    sed -i '/^LICENSE_TOKEN=/d' "$ENV_FILE"
  fi
}

# ── Backup ────────────────────────────────────────────────────────────────────
info "Criando backup..."
BACKUP=$(env_backup)
ok "Backup criado: $BACKUP"

# ── Obter token atual ─────────────────────────────────────────────────────────
OLD_TOKEN=$(env_read | grep -oE '^LICENSE_TOKEN=.*' | head -1 | sed 's/^LICENSE_TOKEN=//' || true)

if [ -z "$OLD_TOKEN" ]; then
  warn "Nenhum LICENSE_TOKEN encontrado no .env — já está no Free"
  exit 0
fi

# Mascarar token para exibição (mostrar só início e fim)
TOKEN_LEN=${#OLD_TOKEN}
if [ "$TOKEN_LEN" -gt 40 ]; then
  MASKED="${OLD_TOKEN:0:20}...${OLD_TOKEN: -20}"
else
  MASKED="${OLD_TOKEN:0:40}..."
fi
info "Token atual: $MASKED"

# ── Remover token do .env ─────────────────────────────────────────────────────
env_remove_token
ok "Token removido do .env"

# ── Revogar no Google Sheets ──────────────────────────────────────────────────
if [ -n "$OLD_TOKEN" ] && command -v bundle &>/dev/null; then
  info "Revogando token no Google Sheets..."
  cd "$REPO_DIR"
  bundle exec ruby -e "
    require 'dotenv/load'
    require_relative 'app/services/license/google_sheet_validator'
    GoogleSheetValidator.revoke_token!('$OLD_TOKEN')
  " 2>&1 && ok "Token revogado no Google Sheets" || warn "Não foi possível revogar no Sheets (verifique config)"
else
  if ! command -v bundle &>/dev/null; then
    warn "bundle não encontrado — pulando revogação no Google Sheets"
  fi
fi

# ── Limpar cache de licença ──────────────────────────────────────────────────
CACHE_FILE="$REPO_DIR/storage/license_cache.json"
if [ -f "$CACHE_FILE" ]; then
  rm -f "$CACHE_FILE"
  ok "Cache de licença removido"
fi

# ── Reiniciar serviço ─────────────────────────────────────────────────────────
if systemctl is-active --quiet gerenciador-erp 2>/dev/null; then
  info "Reiniciando serviço gerenciador-erp..."
  if [ "$NEED_SUDO" = true ]; then
    sudo systemctl restart gerenciador-erp
  else
    systemctl restart gerenciador-erp 2>/dev/null || sudo systemctl restart gerenciador-erp
  fi
  ok "Serviço reiniciado"
fi

echo ""
echo -e "${GREEN}🔄 Sistema voltou ao plano FREE${NC}"
echo "   Na próxima inicialização, um novo trial de 30 dias será gerado automaticamente."
