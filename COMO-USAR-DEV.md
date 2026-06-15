# COMO USAR — Guia do Desenvolvedor

## 1. Servidor Ruby (ERP)

### Iniciar em modo desenvolvimento

```bash
cd /home/victor/RubymineProjects/GerenciadorClaude
bash iniciar.sh
```

Se entrar em **modo produção** (systemd), pare o serviço antes:

```bash
sudo systemctl stop gerenciador-erp
bash iniciar.sh
```

Ou inicie direto (sem script):

```bash
cd /home/victor/RubymineProjects/GerenciadorClaude
bundle exec ruby app.rb
```

### Iniciar em modo produção

```bash
sudo systemctl start gerenciador-erp
```

### Parar

```bash
pkill -f "ruby app.rb"                    # modo dev
sudo systemctl stop gerenciador-erp        # modo produção
```

### Porta

Definida no `.env`:

```
APP_HOST=0.0.0.0
APP_PORT=4568
```

Para alterar, edite o `.env` e reinicie.

---

## 2. Acesso pelo navegador

| Local | URL |
|-------|-----|
| Navegador na própria máquina | http://127.0.0.1:4568 |
| Navegador na rede local | http://192.168.0.6:4568 |

---

## 3. App Android

### Projeto

```bash
/home/victor/RubymineProjects/GerenciadorClaudeAndroide/GerenciadorERP-Android
```

### Compilar e instalar no emulador

```bash
export ANDROID_HOME=/home/victor/Android/Sdk

# Iniciar emulador
$ANDROID_HOME/emulator/emulator -avd Pixel_6

# Em outro terminal, build + install
cd /home/victor/RubymineProjects/GerenciadorClaudeAndroide/GerenciadorERP-Android
./gradlew installDebug
```

### Configurar no emulador

```
IP:   10.0.2.2
Porta: 4568
```

### Gerar APK para distribuir

```bash
cd /home/victor/RubymineProjects/GerenciadorClaudeAndroide/GerenciadorERP-Android
./gradlew assembleRelease
```

O APK estará em:

```
app/build/outputs/apk/release/app-release.apk
```

### APK debug já compilado

```
app/build/outputs/apk/debug/app-debug.apk
```

---

## 4. Banco de dados (PostgreSQL)

```bash
# Conectar
psql -h 127.0.0.1 -U victor -d gerenciador_estoque

# Resetar banco
ruby db/setup.rb
```

---

## 5. Credenciais padrão

- **Usuário:** admin
- **Senha:** admin123

(altere após o primeiro acesso)

---

## 6. Arquivos importantes

| Arquivo | Finalidade |
|---------|------------|
| `.env` | Configurações e credenciais |
| `app.rb` | Entrypoint do Sinatra |
| `iniciar.sh` | Script de inicialização |
| `db/setup.rb` | Criação do banco e seeds |
| `Gemfile` | Dependências Ruby |
| `packaging/` | Build Debian e systemd |
