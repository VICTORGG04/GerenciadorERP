# Gerenciador ERP v2.0.3 — Android

Aplicativo Android (WebView) para acessar o servidor ERP.

## Instalação

### Método 1: Transferir o APK

1. Copie `GerenciadorERP-Android.apk` para o celular (USB, Google Drive, WhatsApp)
2. Abra o arquivo e permita instalação de fontes desconhecidas

### Método 2: Build pelo Android Studio

1. Abra a pasta `GerenciadorERP-Android` no Android Studio
2. Conecte o celular via USB (depuração USB ativada)
3. Clique em **Run** (▶)

## Configuração

1. Na tela inicial, insira o IP do servidor (ex: `192.168.0.6`) e porta (`4568`)
2. Celular e servidor devem estar na mesma rede Wi-Fi

## Requisitos

- Android 8.0 (API 26) ou superior
- Conexão Wi-Fi (mesma rede do servidor)

## Solução de problemas

- **"Servidor não encontrado"**: Verifique se o servidor está rodando e o Wi-Fi
- **"Conexão recusada"**: Libere a porta 4568 no firewall
- **APK não instala**: Configurações > Segurança > Permitir apps desconhecidas
