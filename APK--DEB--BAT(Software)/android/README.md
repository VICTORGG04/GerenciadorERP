# 📱 Gerenciador ERP — Android

Aplicativo Android que funciona como um wrapper WebView para o servidor ERP.

## Instalação

### Método 1: Transferir o APK

1. Copie o arquivo `GerenciadorERP-Android.apk` para seu celular:
   - **USB**: Conecte o celular ao computador e copie o arquivo
   - **Wi-Fi**: Use um app como `Send Anywhere` ou `WiFi FTP Server`
   - **Google Drive / Dropbox**: Faça upload do APK e baixe no celular

2. No celular, abra o arquivo APK

3. Permita a instalação de fontes desconhecidas (se solicitado)

4. Abra o aplicativo instalado

### Método 2: Build pelo Android Studio

1. Abra a pasta `GerenciadorERP-Android` no Android Studio
2. Conecte o celular via USB (com depuração USB ativada)
3. Clique em **Run** (▶) na toolbar

## Configuração

1. Na tela inicial, insira o IP do servidor (ex: `192.168.0.6`)
2. Confirme que o celular está na mesma rede Wi-Fi que o servidor
3. O app escaneia a rede automaticamente e conecta

## Requisitos

- Android 8.0 (API 26) ou superior
- Conexão Wi-Fi (mesma rede do servidor)
- Servidor ERP rodando na porta 4568

## Licenciamento

O plano do sistema é definido no servidor. Consulte o README do servidor para detalhes sobre planos (Free, Gold, Platinum, Enterprise).

## Porta do servidor

Na configuração do app, a porta padrão é **4568**. Se o servidor estiver usando outra porta (ex: 4569), altere o campo "Porta" na tela de configuração do app para o número correto.

## Solução de problemas

**"Servidor não encontrado"**: Verifique se o servidor está rodando no computador e se o celular está na mesma rede Wi-Fi.

**"Conexão recusada"**: Verifique o firewall do computador — a porta 4568 precisa estar liberada.

**APK não instala**: Vá em Configurações > Segurança > "Instalar apps desconhecidas" e permita.
