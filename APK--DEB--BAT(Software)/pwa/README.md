# 🌐 Gerenciador ERP — PWA (Progressive Web App)

Torna o servidor ERP instalável como aplicativo em qualquer dispositivo com navegador moderno.

## Instalação rápida

Execute dentro do repositório do servidor:

```bash
cd APK--DEB--BAT\(Software\)/pwa
bash install.sh
```

O script copia `manifest.json`, `service-worker.js` e cria os ícones SVG em `public/`.

## Instalação manual

Copie os arquivos para a pasta `public/` do servidor:

```bash
cp manifest.json ../../public/
cp service-worker.js ../../public/
mkdir -p ../../public/icons
```

Crie os ícones SVG em `public/icons/`:

**icon-192.svg:**
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 192 192">
  <rect width="192" height="192" rx="32" fill="#16213e"/>
  <text x="96" y="116" font-family="Arial,sans-serif" font-size="80" font-weight="bold" fill="#e94560" text-anchor="middle">ERP</text>
</svg>
```

**icon-512.svg:** (mesmo conteúdo, com 512x512 e font-size 200)

Adicione ao `<head>` do `views/layout.erb`:

```erb
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#16213e">
<meta name="apple-mobile-web-app-capable" content="yes">
<link rel="icon" href="/icons/icon-192.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/icons/icon-192.svg">
```

## Licenciamento

O plano do sistema é definido no servidor. Consulte o README raiz para detalhes sobre planos (Free, Gold, Platinum, Enterprise).

## Como instalar no navegador

| Navegador | Como instalar |
|-----------|---------------|
| **Chrome** | Ícone 🔽 na barra de endereço |
| **Edge** | Menu > Apps > Instalar este site |
| **Firefox** | Ícone + na barra de endereço |
| **Safari (macOS)** | Compartilhar > Adicionar ao Dock |
| **Safari (iOS)** | Compartilhar > Adicionar à Tela de Início |
| **Chrome (Android)** | Banner "Adicionar à tela inicial" |
