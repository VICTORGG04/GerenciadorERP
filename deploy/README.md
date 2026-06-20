# Gerenciador ERP v2.0.3 — Plataformas

Pacotes e scripts para instalar o servidor ERP em diferentes sistemas operacionais.

## Instalação rápida

| Plataforma | Comando |
|---|---|
| Linux | `cd linux && sudo bash install.sh` |
| Windows | `cd windows && setup.bat` (como Administrador) |
| macOS | Duplo clique em `macos/start.command` |
| Docker | `cd docker && bash install.sh` |
| Android | Copiar `android/GerenciadorERP-Android.apk` para o celular |
| PWA | `cd pwa && bash install.sh` |

Os scripts detectam se estão dentro do repositório clonado. Se não estiverem, baixam o projeto do GitHub automaticamente (via ZIP, sem precisar de conta).

## Estrutura

```
android/     → APK + instruções
docker/      → Dockerfile + docker-compose + install.sh
linux/       → .deb + systemd + build.sh + install.sh
macos/       → .app bundle + LaunchAgents + start.command
pwa/         → manifest.json + service-worker.js + install.sh
windows/     → .bat + .ps1 + setup.bat
```

## Acesso padrão

- **URL:** `http://localhost:4568`
- **Login:** `admin@gerenciador.local`
- **Senha:** `admin123`

## Licenciamento

O sistema funciona no plano **Free** (20 produtos, 1 usuário) sem configuração adicional. Para planos pagos, acesse `/pricing` no sistema e compre via Stripe, ou configure o `LICENSE_TOKEN` no `.env`.

## Gerenciar o servidor

```bash
# Linux (systemd)
systemctl start gerenciador-erp
systemctl stop gerenciador-erp
systemctl restart gerenciador-erp
systemctl status gerenciador-erp
journalctl -u gerenciador-erp -f
```

> A porta real pode ser diferente de 4568 (o instalador escolhe automaticamente uma porta livre). Confirme com `systemctl status` ou veja `/etc/gerenciador-erp/.env`.
