#!/data/data/com.termux/files/usr/bin/bash
# iniciar_android.sh — ERP Gerenciador de Estoque (Android/Termux)

echo ""
echo " ⬡ ERP Gerenciador de Estoque"
echo " ─────────────────────────────"
echo ""

# Inicia o PostgreSQL se não estiver rodando
if ! pg_ctl -D $PREFIX/var/lib/postgresql status > /dev/null 2>&1; then
  echo "🗄️  Iniciando banco de dados PostgreSQL..."
  pg_ctl -D $PREFIX/var/lib/postgresql start \
    -l $PREFIX/var/log/postgresql.log
  sleep 2
else
  echo "🗄️  PostgreSQL já está rodando."
fi

# Vai para a pasta do projeto
cd ~/GerenciadorClaude || {
  echo "❌ Pasta do projeto não encontrada em ~/GerenciadorClaude"
  exit 1
}

# Para qualquer instância anterior
pkill -f "ruby app.rb" 2>/dev/null

# Inicia a aplicação em segundo plano
echo "🚀 Iniciando aplicação..."
bundle exec ruby app.rb > /tmp/erp.log 2>&1 &

sleep 3

echo ""
echo "✅ Servidor rodando!"
echo "📱 Abra no navegador: http://localhost:4567"
echo ""
echo "   Para parar o servidor:"
echo "   pkill -f 'ruby app.rb'"
echo "   pg_ctl -D \$PREFIX/var/lib/postgresql stop"
echo ""
