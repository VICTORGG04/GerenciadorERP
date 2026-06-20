#!/bin/bash
# iniciar.sh — Gerenciador ERP
# Uso: ./iniciar.sh          (modo dev, a partir do repositório)
#      ./iniciar.sh --prod   (força reinício dos serviços systemd)

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ETC_ENV="/etc/gerenciador-erp/.env"
LOCAL_ENV="$REPO_DIR/.env"
APP_DIR="/usr/share/gerenciador-erp"

# ─── Detectar modo ──────────────────────────────────────────────────────────
if [ "$1" = "--prod" ] || systemctl is-active --quiet gerenciador-erp 2>/dev/null; then
  echo "▶ Modo produção — reiniciando serviços..."
  sudo systemctl restart gerenciador-erp 2>/dev/null || true
  sudo systemctl restart gerenciador-caddy 2>/dev/null || true
  sleep 2
  URL="https://localhost"
  echo "✅ Serviços reiniciados"
  echo "   Acesse: $URL"
  exit 0
fi

# ─── Modo desenvolvimento ──────────────────────────────────────────────────
echo "🚀 Iniciando Gerenciador ERP (modo desenvolvimento)..."

# Carregar .env (prioridade: local, depois /etc/)
if [ -f "$LOCAL_ENV" ]; then
  source "$LOCAL_ENV"
elif [ -f "$ETC_ENV" ]; then
  source "$ETC_ENV"
fi

PORT="${APP_PORT:-4568}"
HOST="${APP_HOST:-127.0.0.1}"
DOMAIN="${APP_DOMAIN:-}"

# Parar instância anterior
pkill -f "ruby app.rb" 2>/dev/null || true
sleep 1

# Iniciar app (nohup evita que SIGHUP mate o processo ao fechar o terminal)
cd "$REPO_DIR"
nohup bundle exec ruby app.rb > /dev/null 2>&1 &
sleep 2

# Detectar Caddy (se instalado)
CADDY_BIN="/usr/share/gerenciador-erp/caddy/caddy"
if [ -x "$CADDY_BIN" ]; then
  CADDYFILE="/etc/gerenciador-erp/caddy/Caddyfile"
  if [ -f "$CADDYFILE" ]; then
    echo "  Proxy HTTPS (Caddy) detectado"
    OPEN_URL="https://localhost"
  else
    OPEN_URL="http://$HOST:$PORT"
  fi
else
  OPEN_URL="http://$HOST:$PORT"
fi

xdg-open "$OPEN_URL" 2>/dev/null || true

echo ""
echo "✅ Servidor rodando!"
echo "   Local: http://$HOST:$PORT"
echo "   Acesso: $OPEN_URL"
echo "   Parar:  pkill -f 'ruby app.rb'"
echo ""
