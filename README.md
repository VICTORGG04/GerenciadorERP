# Gerenciador ERP v2.0.3

Sistema web de gerenciamento de estoque desenvolvido em **Ruby + Sinatra + PostgreSQL**. Controle completo de produtos, categorias, movimentações, pedidos, relatórios e backups, com autenticação por perfis de usuário (Administrador e Operador), pagamentos via Stripe e licenciamento automatizado.

---

## Índice

- [Funcionalidades](#funcionalidades)
- [Tecnologias](#tecnologias)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Banco de Dados](#banco-de-dados)
- [Como Executar](#como-executar)
- [Implantação](#implantação)
- [Mobile](#mobile)
- [Rotas da Aplicação](#rotas-da-aplicação)
- [Perfis de Usuário](#perfis-de-usuário)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Sistema de Licenciamento](#sistema-de-licenciamento)
- [Pagamentos (Stripe)](#pagamentos-stripe)
- [Solução de Problemas](#solução-de-problemas)

---

## Funcionalidades

| Módulo | Descrição |
|---|---|
| Dashboard | Visão geral com totais de produtos, categorias e estoque baixo |
| Produtos | CRUD completo com SKU, preço, custo, quantidade mínima e categoria |
| Categorias | Criação e exclusão de categorias (com proteção de FK) |
| Movimentações | Registro de entradas e saídas de estoque com histórico |
| Pedidos | Criação e acompanhamento de pedidos por status |
| Baixa Rápida | Saída rápida de estoque sem criar pedido |
| Relatórios | Exportação em múltiplos formatos |
| Backups | Geração e download de backups do banco |
| Auditoria | Log de todas as operações críticas |
| Importação | Importação de dados via planilha |
| Usuários | Gerenciamento de usuários (Admin) |
| Licenças | Gerenciamento de clientes e tokens de licença |
| Pagamentos | Checkout integrado com Stripe (cartão de crédito) |
| Recibos | Geração automática de comprovante `.txt` após pagamento |
| Email | Envio automático da licença por email ao pagar |

---

## Tecnologias

- **Ruby** 3.2.3
- **Sinatra** 4.x — framework web minimalista
- **Puma** 6.x — servidor de aplicação
- **PostgreSQL** — banco de dados relacional
- **BCrypt** — hash seguro de senhas
- **Stripe** 13.x — processamento de pagamentos
- **Ed25519** (OpenSSL) — assinatura digital de tokens
- **Google Sheets API** — registro e validação de licenças (via Python `gspread`)
- **net-smtp** — envio de emails com licença
- **Roo / Rubyzip** — exportação de planilhas e ZIP
- **Nokogiri** — geração de XML/HTML
- **Rufus-scheduler** — agendamento de backups e revalidação de licenças
- **Rack Protection** — proteção contra CSRF e XSS

---

## Estrutura do Projeto

```
GerenciadorClaude/
├── app.rb                          # Ponto de entrada da aplicação
├── config.ru                       # Configuração do Rack
├── Gemfile                         # Dependências Ruby
├── .env                            # Variáveis de ambiente (desenvolvimento)
├── .env.example                    # Template do .env
├── db/
│   └── setup.rb                    # Criação do banco, tabelas e admin inicial
│
├── app/
│   ├── controllers/
│   │   ├── auth_controller.rb           # Login e logout
│   │   ├── dashboard_controller.rb      # Página inicial
│   │   ├── categories_controller.rb     # CRUD de categorias
│   │   ├── products_controller.rb       # CRUD de produtos
│   │   ├── movements_controller.rb      # Entradas e saídas
│   │   ├── orders_controller.rb         # Pedidos
│   │   ├── reports_controller.rb        # Relatórios
│   │   ├── backups_controller.rb        # Backups
│   │   ├── audit_controller.rb          # Auditoria
│   │   ├── import_controller.rb         # Importação de dados
│   │   ├── users_controller.rb          # Gerenciamento de usuários
│   │   ├── licenses_controller.rb       # Gerenciamento de licenças
│   │   ├── payments_controller.rb       # Checkout Stripe
│   │   └── webhooks_controller.rb       # Webhooks Stripe
│   │
│   ├── models/
│   │   ├── base.rb                 # Módulo base com conexão PG
│   │   ├── user.rb                 # Usuários
│   │   ├── category.rb             # Categorias
│   │   ├── product.rb              # Produtos
│   │   ├── movement.rb             # Movimentações
│   │   ├── order.rb                # Pedidos
│   │   ├── audit_log.rb            # Log de auditoria
│   │   ├── import.rb               # Importação de planilhas
│   │   ├── license.rb              # Licenças de clientes
│   │   └── subscription.rb         # Assinaturas Stripe
│   │
│   ├── services/
│   │   ├── inventory/
│   │   │   ├── add_stock_service.rb
│   │   │   ├── remove_stock_service.rb
│   │   │   └── adjust_stock_service.rb
│   │   ├── backups/
│   │   │   └── json_backup_service.rb
│   │   ├── license/
│   │   │   └── google_sheet_validator.rb
│   │   └── email_service.rb
│   │
│   ├── lib/
│   │   ├── backup_scheduler.rb     # Backup automático agendado
│   │   └── license_scheduler.rb    # Revalidação periódica de licenças
│   │
│   └── views/
│       ├── layout.erb              # Layout principal
│       ├── login.erb               # Tela de login
│       ├── dashboard.erb           # Dashboard
│       ├── license.erb             # Tela de licença
│       ├── backups.erb
│       ├── reports.erb
│       ├── categories/
│       ├── products/
│       ├── movements/
│       ├── orders/
│       ├── imports/
│       ├── users/
│       ├── licenses/
│       ├── payments/
│       └── errors/
│
├── scripts/
│   ├── google_sheet_validator.py   # Validação e registro de licenças no Google Sheets
│   ├── payment_processor.py        # Processamento de pagamentos (Python)
│   ├── setup_stripe_prices.rb      # Criação de produtos/preços no Stripe
│   ├── resetar_licenca.sh          # Reset de licença local
│   ├── install.sh                  # Instalação rápida
│   └── iniciar.sh                  # Inicialização
│
├── deploy/
│   ├── linux/        # Pacote .deb + systemd
│   ├── windows/      # Script .bat + .ps1
│   ├── macos/        # .app bundle + LaunchAgents
│   ├── docker/       # Dockerfile + docker-compose
│   ├── android/      # APK do app Android
│   └── pwa/          # Manifest + service-worker
│
├── storage/
│   ├── machine_id                # Identificador único da instalação
│   ├── receipts/                 # Comprovantes de pagamento (.txt)
│   └── backups/                  # Backups do banco (.sql.gz)
│
└── public/
    └── style.css                 # Estilos globais
```

---

## Pré-requisitos

- [Ruby 3.2.3](https://www.ruby-lang.org/pt/downloads/)
- [PostgreSQL 14+](https://www.postgresql.org/download/)
- Bundler: `gem install bundler`

---

## Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/VICTORGG04/GerenciadorClaude.git
cd GerenciadorClaude
```

### 2. Instale as dependências

```bash
bundle install
```

### 3. Configure o ambiente

```bash
cp .env.example .env
# Edite .env com suas credenciais (DB, Stripe, Google Sheets, SMTP)
```

### 4. Crie o banco de dados

```bash
ruby db/setup.rb
```

O script cria o banco, as tabelas e o usuário administrador inicial automaticamente.

### 5. Inicie o servidor

```bash
bundle exec ruby app.rb
```

Acesse: [http://localhost:4568](http://localhost:4568)

---

## Banco de Dados

### Criar manualmente (alternativa ao `db/setup.rb`)

```bash
sudo -u postgres psql
```

```sql
CREATE USER gerenciador_erp WITH PASSWORD 'sua_senha';
CREATE DATABASE gerenciador_estoque OWNER gerenciador_erp;
GRANT ALL PRIVILEGES ON DATABASE gerenciador_estoque TO gerenciador_erp;
\q
```

### Credenciais padrão de acesso

| Campo | Valor |
|---|---|
| E-mail | admin@gerenciador.local |
| Senha | admin123 |

> Troque a senha após o primeiro login em produção.

---

## Como Executar

### Desenvolvimento

```bash
bundle exec ruby app.rb
```

Acesse: [http://localhost:4568](http://localhost:4568)

### Produção (Linux — systemd)

```bash
systemctl start gerenciador-erp   # Iniciar
systemctl stop gerenciador-erp    # Parar
systemctl status gerenciador-erp  # Status
systemctl restart gerenciador-erp # Reiniciar

# Logs
journalctl -u gerenciador-erp -f

# Matar processo na porta
lsof -ti:4568 | xargs kill -9
```

---

## Implantação

Cada plataforma possui um instalador auto-contido em `deploy/`:

| Plataforma | Comando |
|---|---|
| **Linux** (Debian/Ubuntu) | `cd deploy/linux && sudo bash install.sh` |
| **Windows** | `cd deploy/windows` → `setup.bat` (como Administrador) |
| **macOS** | Duplo clique em `deploy/macos/start.command` |
| **Docker** | `cd deploy/docker && bash install.sh` |
| **Android** | Copiar `deploy/android/GerenciadorERP-Android.apk` para o celular |
| **PWA** | `cd deploy/pwa && bash install.sh` (dentro do repositório) |

Os scripts detectam se estão dentro do repositório clonado; se não estiverem, baixam o projeto do GitHub automaticamente via ZIP.

---

## Mobile

O app mobile é um **WebView** que exibe o sistema ERP rodando no servidor da empresa. Toda a lógica fica no PC; o celular apenas exibe a interface.

```
[Celular]  ◄── Wi-Fi ──►  [Servidor]
                           Ruby + Sinatra + PostgreSQL
                           Porta: 4568
```

### Android (APK)

1. Transfira `deploy/android/GerenciadorERP-Android.apk` para o celular
2. Abra o arquivo e permita instalação de fontes desconhecidas
3. Na primeira abertura, configure o IP do servidor (ex: `192.168.0.6`) e porta (`4568`)

### iPhone (PWA)

1. Abra o **Safari** e acesse `http://IP_DO_SERVIDOR:4568`
2. Toque em Compartilhar → Adicionar à Tela de Início

> iPhone e servidor devem estar na mesma rede Wi-Fi.

---

## Rotas da Aplicação

### Públicas

| Método | Rota | Descrição |
|---|---|---|
| GET | `/login` | Tela de login |
| POST | `/login` | Autenticar |
| GET | `/license` | Status da licença |
| GET | `/pricing` | Planos e preços |
| GET | `/stripe` | Redirecionar para checkout Stripe |
| GET | `/success` | Sucesso após pagamento |
| GET | `/cancel` | Pagamento cancelado |
| POST | `/webhooks/stripe` | Webhooks Stripe (invoice.paid, etc.) |
| GET | `/receipts/:filename` | Download de comprovante de pagamento |

### Autenticadas (qualquer perfil)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/` | Dashboard |
| GET | `/products` | Listar produtos |
| GET | `/products/:id` | Detalhes do produto |
| GET | `/categories` | Listar categorias |
| GET | `/movements` | Histórico de movimentações |
| POST | `/movements` | Registrar movimentação |
| GET | `/quick_out` | Baixa rápida |
| POST | `/quick_out` | Executar baixa rápida |
| GET | `/orders` | Listar pedidos |
| GET | `/orders/:id` | Detalhes do pedido |
| POST | `/orders` | Criar pedido |
| GET | `/reports` | Relatórios |
| GET | `/import` | Importar planilha |
| POST | `/import` | Executar importação |

### Administrador

| Método | Rota | Descrição |
|---|---|---|
| GET/POST | `/products/new` | Criar produto |
| GET/POST | `/products/:id/edit` | Editar produto |
| POST | `/products/:id/delete` | Excluir produto |
| POST | `/categories` | Criar categoria |
| POST | `/categories/:id/delete` | Excluir categoria |
| GET | `/backups` | Gerenciar backups |
| GET | `/audit` | Log de auditoria |
| GET | `/users` | Gerenciar usuários |
| GET/POST | `/licenses` | Gerenciar licenças de clientes |
| GET/POST | `/licenses/new` | Nova licença |

---

## Perfis de Usuário

| Perfil | `role` | Acesso |
|---|---|---|
| Administrador | `admin` | Acesso total |
| Operador | `operator` | Consultas, movimentações e pedidos |

---

## Variáveis de Ambiente

### Banco de Dados

| Variável | Padrão | Descrição |
|---|---|---|
| `DB_HOST` | `127.0.0.1` | Host do PostgreSQL |
| `DB_PORT` | `5432` | Porta do PostgreSQL |
| `DB_NAME` | `gerenciador_estoque` | Nome do banco |
| `DB_USER` | `gerenciador_erp` | Usuário do banco |
| `DB_PASSWORD` | — | Senha do banco |

### Servidor

| Variável | Padrão | Descrição |
|---|---|---|
| `APP_HOST` | `0.0.0.0` | IP do servidor |
| `APP_PORT` | `4568` | Porta do servidor |
| `SESSION_SECRET` | auto | Chave secreta da sessão |
| `ALLOWED_HOST` | — | Host permitido para redirecionamentos |
| `FREE_TRIAL_DAYS` | `30` | Dias de teste grátis |

### Stripe (Pagamentos)

| Variável | Descrição |
|---|---|
| `STRIPE_SECRET_KEY` | Chave secreta da API Stripe |
| `STRIPE_PUBLISHABLE_KEY` | Chave publicável (frontend) |
| `STRIPE_WEBHOOK_SECRET` | Segredo do webhook Stripe |
| `STRIPE_PRICE_GOLD_MONTHLY` | ID do preço Gold mensal |
| `STRIPE_PRICE_GOLD_SEMIANNUAL` | ID do preço Gold semestral |
| `STRIPE_PRICE_GOLD_LIFETIME` | ID do preço Gold vitalício |
| `STRIPE_PRICE_PLATINUM_MONTHLY` | ID do preço Platinum mensal |
| `STRIPE_PRICE_PLATINUM_SEMIANNUAL` | ID do preço Platinum semestral |
| `STRIPE_PRICE_PLATINUM_LIFETIME` | ID do preço Platinum vitalício |
| `STRIPE_PRICE_ENTERPRISE_MONTHLY` | ID do preço Enterprise mensal |
| `STRIPE_PRICE_ENTERPRISE_SEMIANNUAL` | ID do preço Enterprise semestral |
| `STRIPE_PRICE_ENTERPRISE_LIFETIME` | ID do preço Enterprise vitalício |

### Google Sheets (Licenças)

| Variável | Descrição |
|---|---|
| `GOOGLE_SHEET_ID` | ID da planilha de licenças |
| `GOOGLE_SHEET_CREDENTIALS` | Caminho para o JSON da service account |

### Licenciamento

| Variável | Padrão | Descrição |
|---|---|---|
| `LICENSE_TOKEN` | — | Token de licença (define o plano) |
| `LICENSE_SECRET` | hash interno | Chave HMAC para tokens free trial |

### Email (SMTP)

| Variável | Descrição |
|---|---|
| `SMTP_HOST` | Servidor SMTP (ex: smtp.gmail.com) |
| `SMTP_PORT` | Porta SMTP (ex: 587) |
| `SMTP_USER` | Usuário SMTP |
| `SMTP_PASSWORD` | Senha ou app password |
| `SMTP_FROM` | Remetente dos emails |
| `SMTP_STARTTLS` | `true` para habilitar TLS |

---

## Sistema de Licenciamento

O ERP possui **4 planos** que liberam funcionalidades progressivamente:

| Plano | Produtos | Usuários | Features |
|---|---|---|---|
| **Free** (trial) | 20 | 1 | dashboard, produtos, PWA |
| **Gold** | 500 | 3 | + categorias, movimentações, Android, baixa rápida |
| **Platinum** | ilimitado | ilimitado | + pedidos, relatórios, backup, auditoria |
| **Enterprise** | ilimitado | ilimitado | + whitelabel, código-fonte, treinamento |

### Como funciona

Cada instalação tem um token de licença armazenado no `.env` (`LICENSE_TOKEN`). Se vazio ou inválido, o sistema opera como **Free** (trial de 30 dias).

O token segue o formato: `<plano>.<timestamp>.<identificador>.<assinatura>`.

- **Free trial**: assinado com HMAC-SHA256 (`LICENSE_SECRET`)
- **Planos pagos**: assinados com Ed25519 (chave privada do desenvolvedor)

### Validação automática

O sistema revalida a licença a cada **6 horas** consultando o Google Sheets. Se a licença expirou ou foi revogada, o plano é rebaixado automaticamente.

---

## Pagamentos (Stripe)

### Fluxo de compra

1. Usuário acessa `/pricing` e escolhe um plano
2. É redirecionado ao checkout Stripe (página segura do Stripe)
3. Após pagamento, o Stripe envia webhook `checkout.session.completed` e `invoice.paid`
4. O sistema:
   - Gera um novo token de licença paga
   - Registra no Google Sheets com status `pago`
   - Marca o token free trial como `upgraded`
   - Gera um comprovante `.txt` em `storage/receipts/`
   - Envia o token por email (se SMTP configurado)
5. Usuário é redirecionado para `/success` com o token exibido

### Webhooks

| Evento | Ação |
|---|---|
| `checkout.session.completed` | Registrar assinatura no banco |
| `invoice.paid` | Gerar licença paga + comprovante + email |
| `invoice.payment_failed` | Registrar falha |
| `customer.subscription.updated` | Atualizar status |
| `customer.subscription.deleted` | Cancelar licença |

### Preços

Os IDs dos preços são configurados via variáveis de ambiente (`STRIPE_PRICE_*`) e criados com o script `scripts/setup_stripe_prices.rb`.

---

## Solução de Problemas

### Banco de dados

```bash
# Tabela não existe
ruby db/setup.rb

# Erro de conexão
# Verifique DB_HOST, DB_USER, DB_PASSWORD no .env
```

### Porta em uso

```bash
lsof -ti:4568 | xargs kill -9
```

### Webhook Stripe não funciona

- Verifique se `STRIPE_WEBHOOK_SECRET` está correto
- Teste com Stripe CLI: `stripe trigger invoice.paid`
- Confira os logs: `journalctl -u gerenciador-erp -f`
- O endpoint do webhook deve ser: `https://SEU_DOMINIO/stripe`

### Email não enviado

- Verifique SMTP_HOST, SMTP_USER, SMTP_PASSWORD
- Gmail: use senha de app (2 fatores obrigatório)
- Confira os logs: procure por `[EmailService]`

### Google Sheets não atualiza

- Verifique GOOGLE_SHEET_ID e GOOGLE_SHEET_CREDENTIALS
- A service account precisa ter acesso de edição à planilha
- O Python `gspread` precisa estar instalado: `pip install gspread google-oauth`

### Licença não validada

- Verifique se o token está presente no `.env`
- Confira se o token está registrado no Google Sheets
- A revalidação ocorre a cada 6 horas automaticamente

### Mobile "Servidor não encontrado"

- Servidor rodando com `0.0.0.0` (não `127.0.0.1`)
- Celular e servidor no mesmo Wi-Fi
- Firewall liberado (porta 4568)
- Teste abrindo `http://IP:4568` no navegador do celular

---

## Licença

Projeto privado — todos os direitos reservados.
