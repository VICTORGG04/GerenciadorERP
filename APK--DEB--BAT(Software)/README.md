# 📦 Gerenciador ERP — Plataformas

Pacotes e scripts para instalar o servidor ERP em diferentes sistemas operacionais.

## Instalação rápida

Cada pasta contém um script de instalação auto-contido:

| Plataforma | Comando |
|------------|---------|
| 🐧 Linux | `cd linux && sudo bash install.sh` |
| 🪟 Windows | `cd windows && setup.bat` (como Administrador) |
| 🍎 macOS | Duplo clique em `macos/start.command` |
| 🐳 Docker | `cd docker && bash install.sh` |
| 📱 Android | Copiar `android/GerenciadorERP-Android.apk` para o celular |
| 🌐 PWA | `cd pwa && bash install.sh` (dentro do repositório) |

## Como funciona

Cada script:
1. **Detecta** se está dentro do repositório clonado (procura `app.rb`)
2. **Se não estiver**, clona o projeto do GitHub automaticamente
3. **Instala** as dependências e configura o ambiente
4. **Inicia** o servidor

## Estrutura

```
📁 android/   → APK + instruções
📁 docker/    → Dockerfile + docker-compose + install.sh
📁 linux/     → .deb + systemd + build.sh + install.sh
📁 macos/     → .app bundle + LaunchAgents + start.command
📁 pwa/       → manifest.json + service-worker.js + install.sh
📁 windows/   → .bat + .ps1 + setup.bat
```

## Acesso padrão

- **URL:** `http://localhost:4568`
- **Login:** `admin@gerenciador.local`
- **Senha:** `admin123`

## Licenciamento

O sistema funciona no plano **Free** (50 produtos, 1 usuário) sem configuração adicional. Para planos pagos (Gold, Platinum, Enterprise), configure o `LICENSE_TOKEN` no `.env` — veja a seção "Sistema de Licenciamento" no `README.md` raiz.

## Gerenciar o servidor

```bash
# Parar
sudo systemctl stop gerenciador-erp

# Iniciar
sudo systemctl start gerenciador-erp

# Reiniciar
sudo systemctl restart gerenciador-erp

# Status + porta real
systemctl status gerenciador-erp | grep Listening

# Logs
journalctl -u gerenciador-erp -f
```

Para matar o processo à força:

```bash
lsof -ti:4568 | xargs kill -9
```

> A porta real pode ser diferente de 4568 (o instalador escolhe automaticamente uma porta livre). Confirme com `systemctl status` ou veja o `/etc/gerenciador-erp/.env`.
