# 🐧 Gerenciador ERP — Linux

Pacote `.deb` para Debian/Ubuntu e derivados.

## Instalação rápida

```bash
sudo bash install.sh
```

O script:
1. Verifica se o `.deb` está presente na pasta
2. Se não, clona o repositório e constrói o pacote
3. Instala com `apt install`

## Instalação manual

### Opção 1: Pacote .deb pronto

```bash
sudo apt install ./gerenciador-erp_1.0.1_amd64.deb
```

### Opção 2: Build do zero

```bash
sudo apt install ruby bundler postgresql libpq-dev ruby-dev
sudo bash build.sh
sudo apt install ./gerenciador-erp_1.0.1_amd64.deb
```

## Configuração pós-instalação

### 1. Banco de dados

```bash
sudo -u postgres createdb gerenciador_estoque
sudo -u postgres psql -c "CREATE USER gerenciador_erp WITH PASSWORD 'sua_senha';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE gerenciador_estoque TO gerenciador_erp;"
```

### 2. Configurar .env

Edite `/etc/gerenciador-erp/.env` com as credenciais.

### 3. Iniciar serviço

```bash
sudo systemctl enable --now gerenciador-erp
sudo systemctl status gerenciador-erp
```

### 4. Acessar

Abra [http://localhost:4568](http://localhost:4568)

- **Login:** `admin@gerenciador.local`
- **Senha:** `admin123`

## Comandos úteis

| Comando | Descrição |
|---------|-----------|
| `systemctl status gerenciador-erp` | Status do servidor |
| `systemctl status gerenciador-erp \| grep Listening` | Ver porta real em uso |
| `grep APP_PORT /etc/gerenciador-erp/.env` | Ver porta configurada |
| `systemctl start gerenciador-erp` | Iniciar |
| `systemctl stop gerenciador-erp` | Parar |
| `systemctl restart gerenciador-erp` | Reiniciar |
| `journalctl -u gerenciador-erp -f` | Logs em tempo real |
| `lsof -ti:4568 \| xargs kill -9` | Matar processo na porta (forçado) |
| `systemctl start gerenciador-caddy` | Ativar HTTPS |

> A porta pode ser 4568 ou outra (o instalador escolhe automaticamente uma porta livre). Confirme com `systemctl status`.

## Remover

```bash
sudo apt remove gerenciador-erp
```
