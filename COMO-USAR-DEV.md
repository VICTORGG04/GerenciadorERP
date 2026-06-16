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

### Matar por porta (forçado)

```bash
# Descobrir o PID na porta desejada
lsof -ti:4568                              # dev
lsof -ti:4569                              # produção (ou confirme a porta)

# Matar
kill -9 $(lsof -ti:4568)                   # substitua pela porta
```

### Porta

Definida no `.env`:

```
APP_HOST=0.0.0.0
APP_PORT=4568
```

Para alterar, edite o `.env` e reinicie.

> **Atenção:** Em produção, o `postinst` do pacote `.deb` verifica se a porta 4568 está livre. Se estiver ocupada, ele escolhe automaticamente a próxima disponível (4569, 4570...). A porta real fica salva em `/etc/gerenciador-erp/.env`. Verifique com:
> ```bash
> sudo systemctl status gerenciador-erp | grep Listening
> grep APP_PORT /etc/gerenciador-erp/.env
> ```

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

## 5. Licenciamento — Gerar tokens (apenas dev)

Os tokens de licença são assinados digitalmente com **Ed25519**. A chave privada (`chave_privada.pem`) fica apenas na máquina do desenvolvedor. O servidor tem apenas a chave pública (hardcoded na `app.rb`).

### Gerar um token

```bash
ruby GerarLicenca.rb <plano> <dias> <identificador>
```

Exemplos:

```bash
# Gold para o cliente LIC-007, válido por 365 dias
ruby GerarLicenca.rb gold 365 LIC-007

# Platinum para o cliente LIC-012, válido por 730 dias
ruby GerarLicenca.rb platinum 730 LIC-012

# Enterprise para o cliente LIC-042, válido por 1095 dias
ruby GerarLicenca.rb enterprise 1095 LIC-042
```

A saída inclui a linha `LICENSE_TOKEN=...` que deve ser colada no painel admin em `/licenses`.

### Arquivos importantes

| Arquivo | Finalidade |
|---------|------------|
| `GerarLicenca.rb` | Script gerador de tokens (gitignored) |
| `chave_privada.pem` | Chave privada Ed25519 (gitignored) |
| `chave_publica.pem` | Chave pública Ed25519 (opcional, já está hardcoded) |

> ⚠️ `GerarLicenca.rb` e `chave_privada.pem` estão no `.gitignore` e **não** são incluídos em builds `.deb`, Docker ou qualquer distribuição ao cliente.

## 6. Credenciais padrão

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
