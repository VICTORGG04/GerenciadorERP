#!/bin/bash
# Gerenciador ERP - Instalação PWA
# Copia os arquivos do Progressive Web App para o servidor.
# Uso: bash install.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "   Gerenciador ERP - Ativar PWA"
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

if [ -z "$REPO_DIR" ]; then
    echo "ERRO: Repositório não encontrado."
    echo "Execute este script de dentro do repositório GerenciadorClaude."
    exit 1
fi

PUBLIC_DIR="$REPO_DIR/public"
ICONS_DIR="$PUBLIC_DIR/icons"

echo ">>> Copiando manifest.json..."
cp "$SCRIPT_DIR/manifest.json" "$PUBLIC_DIR/"

echo ">>> Copiando service-worker.js..."
cp "$SCRIPT_DIR/service-worker.js" "$PUBLIC_DIR/"

echo ">>> Criando ícones..."
mkdir -p "$ICONS_DIR"

# Criar SVG icons (funcionam em todos navegadores modernos)
if [ ! -f "$ICONS_DIR/icon-192.svg" ]; then
    cat > "$ICONS_DIR/icon-192.svg" << 'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 192 192">
  <rect width="192" height="192" rx="32" fill="#16213e"/>
  <text x="96" y="116" font-family="Arial,sans-serif" font-size="80" font-weight="bold" fill="#e94560" text-anchor="middle">ERP</text>
</svg>
SVG
fi

if [ ! -f "$ICONS_DIR/icon-512.svg" ]; then
    cat > "$ICONS_DIR/icon-512.svg" << 'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="64" fill="#16213e"/>
  <text x="256" y="310" font-family="Arial,sans-serif" font-size="200" font-weight="bold" fill="#e94560" text-anchor="middle">ERP</text>
</svg>
SVG
fi

echo ">>> Verificando layout.erb..."
LAYOUT="$REPO_DIR/views/layout.erb"
if [ -f "$LAYOUT" ]; then
    if ! grep -q "manifest.json" "$LAYOUT"; then
        echo ">>> ATENÇÃO: Adicione manualmente ao <head> do layout.erb:"
        echo '    <link rel="manifest" href="/manifest.json">'
        echo '    <meta name="theme-color" content="#16213e">'
        echo '    <meta name="apple-mobile-web-app-capable" content="yes">'
        echo '    <link rel="icon" href="/icons/icon-192.svg">'
    else
        echo ">>> layout.erb já configurado."
    fi
fi

echo ""
echo "============================================"
echo "   PWA instalado com sucesso!"
echo "============================================"
echo ""
echo "   Agora, ao acessar o ERP pelo navegador,"
echo "   aparecerá um ícone de instalação na"
echo "   barra de endereço."
echo ""
echo "   Chrome:  Ícone 🔽 na barra de endereço"
echo "   Safari:  Compartilhar > Adicionar à Tela"
echo "   Edge:    Menu > Apps > Instalar"
echo ""
