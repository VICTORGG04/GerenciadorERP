# Gerenciador ERP v2.0.3 — Linux

Pacote `.deb` para Debian/Ubuntu e derivados.

## Instalação rápida

```bash
sudo bash install.sh
```

O script verifica se o `.deb` está presente; se não, clona o repositório e constrói o pacote.

## Instalação manual

### Opção 1: Pacote .deb pronto

```bash
sudo apt install ./gerenciador-erp_2.0.3_amd64.deb
```

### Opção 2: Build do zero

```bash
sudo apt install ruby bundler postgresql libpq-dev ruby-dev
sudo bash build.sh
sudo apt install ./gerenciador-erp_2.0.3_amd64.deb
```

## Configuração pós-instalação

### 1. Banco de dados

```bash
sudo -u postgres createdb gerenciador_estoque
sudo -u postgres psql -c "CREATE USER gerenciador_erp WITH PASSWORD 'sua_senha';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE gerenciador_estoque TO gerenciador_erp;"
```

### 2. Configurar .env

Edite `/etc/gerenciador-erp/.env` com as credenciais do banco e demais serviços (Stripe, Google Sheets, SMTP).

### 3. Iniciar serviço

```bash
sudo systemctl enable --now gerenciador-erp
sudo systemctl status gerenciador-erp
```

### 4. Configurar banco

```bash
sudo -u gerenciador-erp ruby /usr/share/gerenciador-erp/db/setup.rb
```

### 5. Acessar

Abra [http://localhost:4568](http://localhost:4568)

- **Login:** `admin@gerenciador.local`
- **Senha:** `admin123`

## Comandos úteis

| Comando | Descrição |
|---|---|
| `systemctl status gerenciador-erp` | Status do servidor |
| `systemctl status gerenciador-erp \| grep Listening` | Ver porta real |
| `grep APP_PORT /etc/gerenciador-erp/.env` | Porta configurada |
| `systemctl start gerenciador-erp` | Iniciar |
| `systemctl stop gerenciador-erp` | Parar |
| `systemctl restart gerenciador-erp` | Reiniciar |
| `journalctl -u gerenciador-erp -f` | Logs em tempo real |
| `lsof -ti:4568 \| xargs kill -9` | Matar processo na porta |
| `systemctl start gerenciador-caddy` | Ativar HTTPS (Caddy) |

## Remover

```bash
sudo apt remove gerenciador-erp
```
