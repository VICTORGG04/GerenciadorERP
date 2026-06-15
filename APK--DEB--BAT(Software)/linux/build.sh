#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.."
echo ">>> Build do pacote .deb - Gerenciador ERP"

PKG_NAME="gerenciador-erp"
PKG_VERSION="1.0.1"
CADDY_VERSION="2.9.1"
STAGING_DIR="/tmp/staging-${PKG_NAME}"

# ── Limpar staging ────────────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

# ── Criar estrutura de diretórios ─────────────────────────────────────────────
mkdir -p "$STAGING_DIR/usr/share/$PKG_NAME"
mkdir -p "$STAGING_DIR/etc/$PKG_NAME/caddy"
mkdir -p "$STAGING_DIR/lib/systemd/system"
mkdir -p "$STAGING_DIR/usr/share/applications"
mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$STAGING_DIR/etc/logrotate.d"

echo "  ✓ Estrutura de diretórios criada"

# ── Copiar código fonte ───────────────────────────────────────────────────────
cp app.rb Gemfile Gemfile.lock config.ru .env.example "$STAGING_DIR/usr/share/$PKG_NAME/"
cp -r controllers models views services lib public db "$STAGING_DIR/usr/share/$PKG_NAME/"

# ── Copiar gems vendored ──────────────────────────────────────────────────────
if [ -d vendor ]; then
  cp -r vendor "$STAGING_DIR/usr/share/$PKG_NAME/"
fi
mkdir -p "$STAGING_DIR/usr/share/$PKG_NAME/.bundle"
if [ -f .bundle/config ]; then
  cp .bundle/config "$STAGING_DIR/usr/share/$PKG_NAME/.bundle/"
fi

# ── Copiar script de inicialização ────────────────────────────────────────────
cp iniciar.sh "$STAGING_DIR/usr/share/$PKG_NAME/"

# ── Criar diretórios de runtime ───────────────────────────────────────────────
mkdir -p "$STAGING_DIR/usr/share/$PKG_NAME"/{logs,storage,backups}

# ── Copiar arquivos de sistema ────────────────────────────────────────────────
cp "$SCRIPT_DIR/systemd/gerenciador-erp.service" "$STAGING_DIR/lib/systemd/system/"
cp "$SCRIPT_DIR/systemd/gerenciador-caddy.service" "$STAGING_DIR/lib/systemd/system/"
cp "$SCRIPT_DIR/gerenciador-erp.desktop" "$STAGING_DIR/usr/share/applications/"
cp "$SCRIPT_DIR/gerenciador-erp.svg" "$STAGING_DIR/usr/share/icons/hicolor/scalable/apps/"
cp "$SCRIPT_DIR/logrotate" "$STAGING_DIR/etc/logrotate.d/$PKG_NAME"

# ── Copiar Caddyfile ─────────────────────────────────────────────────────────
cp "$SCRIPT_DIR/caddy/Caddyfile" "$STAGING_DIR/etc/$PKG_NAME/caddy/"

# ── Placeholder para /etc/gerenciador-erp/ ────────────────────────────────────
touch "$STAGING_DIR/etc/$PKG_NAME/.placeholder"

# ── Download Caddy ────────────────────────────────────────────────────────────
echo ">>> Baixando Caddy..."
CADDY_DIR="$STAGING_DIR/usr/share/$PKG_NAME/caddy"
mkdir -p "$CADDY_DIR"
CADDY_TGZ="$SCRIPT_DIR/.caddy_download.tar.gz"
rm -f "$CADDY_TGZ"
curl -L "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" -o "$CADDY_TGZ"
tar xzf "$CADDY_TGZ" -C "$CADDY_DIR/"
chmod +x "$CADDY_DIR/caddy"
rm -f "$CADDY_TGZ"
echo "  ✓ Caddy v$CADDY_VERSION baixado e incluído"

# ── Ajustar permissões ────────────────────────────────────────────────────────
find "$STAGING_DIR" -type d -exec chmod 755 {} \;
find "$STAGING_DIR" -type f -exec chmod 644 {} \;
chmod 755 "$STAGING_DIR/usr/share/$PKG_NAME/iniciar.sh"

# ── Localizar fpm (gem user-install ou system) ────────────────────────────────
FPM=$(command -v fpm 2>/dev/null || echo "$HOME/.local/share/gem/ruby/3.2.0/bin/fpm")
if [ ! -x "$FPM" ]; then
  echo ">>> Instalando fpm..."
  gem install fpm --no-document --user-install
  FPM="$HOME/.local/share/gem/ruby/3.2.0/bin/fpm"
fi

# ── Build do .deb ─────────────────────────────────────────────────────────────
echo ">>> Gerando pacote .deb..."
"$FPM" -s dir -t deb \
  -n "$PKG_NAME" \
  -v "$PKG_VERSION" \
  -C "$STAGING_DIR" \
  --prefix / \
  --after-install "$SCRIPT_DIR/debian/postinst" \
  --before-remove "$SCRIPT_DIR/debian/prerm" \
  --after-remove "$SCRIPT_DIR/debian/postrm" \
  --description "ERP de Gerenciamento de Estoque" \
  --url "https://github.com/VICTORGG04/GerenciadorClaude" \
  --license "MIT" \
  --vendor "Gerenciador ERP" \
  --depends "ruby (>= 3.2)" \
  --depends "bundler" \
  --depends "postgresql (>= 16)" \
  --depends "libpq-dev" \
  --depends "openssl" \
  --depends "curl" \
  --package "$SCRIPT_DIR" \
  .

echo ""
echo ">>> Pacote criado: $(ls -lh "$SCRIPT_DIR/"*.deb 2>/dev/null | head -1)"
echo ">>> Instalação:  sudo apt install ./${PKG_NAME}_${PKG_VERSION}_amd64.deb"
echo ">>> Remoção:     sudo apt remove ${PKG_NAME}"
