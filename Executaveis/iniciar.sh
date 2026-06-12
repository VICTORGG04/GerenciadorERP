#!/bin/bash
# iniciar.sh — ERP Gerenciador de Estoque (Linux)

cd "$(dirname "$0")"

echo "🚀 Iniciando ERP Gerenciador de Estoque..."
bundle exec ruby app.rb &

sleep 2
xdg-open http://localhost:4567

echo "✅ Servidor rodando em http://localhost:4567"
echo "   Para parar: pkill -f 'ruby app.rb'"
