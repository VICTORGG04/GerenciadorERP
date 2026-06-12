#!/bin/bash
cd "$(dirname "$0")"
source .env 2>/dev/null
PORT="${APP_PORT:-4567}"
echo "🚀 Iniciando ERP Gerenciador de Estoque..."
bundle exec ruby app.rb &
sleep 2
xdg-open "http://localhost:$PORT"
echo "✅ Servidor rodando em http://localhost:$PORT"
echo "   Para parar: pkill -f 'ruby app.rb'"
