# Gerenciador ERP v2.0.3 — PWA (Progressive Web App)

Torna o servidor ERP instalável como aplicativo em qualquer dispositivo com navegador moderno.

## Instalação

```bash
cd deploy/pwa
bash install.sh
```

O script copia `manifest.json`, `service-worker.js` e os ícones SVG para `public/`.

## Manual

Copie os arquivos para `public/`:

```bash
cp manifest.json ../../public/
cp service-worker.js ../../public/
mkdir -p ../../public/icons
```

Crie os ícones SVG em `public/icons/` e adicione ao `<head>` do `views/layout.erb`:

```erb
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#16213e">
<meta name="apple-mobile-web-app-capable" content="yes">
<link rel="icon" href="/icons/icon-192.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/icons/icon-192.svg">
```

## Instalar no navegador

| Navegador | Como instalar |
|---|---|
| **Chrome** | Ícone 🔽 na barra de endereço |
| **Edge** | Menu > Apps > Instalar este site |
| **Firefox** | Ícone + na barra de endereço |
| **Safari (macOS)** | Compartilhar > Adicionar ao Dock |
| **Safari (iOS)** | Compartilhar > Adicionar à Tela de Início |
| **Chrome (Android)** | Banner "Adicionar à tela inicial" |
