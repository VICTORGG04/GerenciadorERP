# ⬡ ERP Gerenciador de Estoque

Sistema web de gerenciamento de estoque desenvolvido em **Ruby + Sinatra + PostgreSQL**. Permite controle completo de produtos, categorias, movimentações, pedidos, relatórios e backups, com autenticação por perfis de usuário (Administrador e Operador).

---

## Índice

- [Funcionalidades](#funcionalidades)
- [Tecnologias](#tecnologias)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Banco de Dados](#banco-de-dados)
- [Como Executar](#como-executar)
- [Executável — Linux](#executável--linux)
- [Executável — Windows](#executável--windows)
- [Mobile — Como funciona](#mobile--como-funciona)
- [Mobile — Configurar o Servidor](#mobile--configurar-o-servidor)
- [Mobile — Android (APK)](#mobile--android-apk)
- [Mobile — Android (compilar o APK)](#mobile--android-compilar-o-apk)
- [Mobile — iPhone (PWA)](#mobile--iphone-pwa)
- [Estrutura do App Android](#estrutura-do-app-android)
- [Rotas da Aplicação](#rotas-da-aplicação)
- [Perfis de Usuário](#perfis-de-usuário)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Solução de Problemas](#solução-de-problemas)

---

## Funcionalidades

| Módulo | Descrição |
|---|---|
| 🏠 Dashboard | Visão geral com totais de produtos, categorias e estoque baixo |
| 📦 Produtos | CRUD completo com SKU, preço, custo, quantidade mínima e categoria |
| 🏷️ Categorias | Criação e exclusão de categorias (com proteção de FK) |
| ⇅ Movimentações | Registro de entradas e saídas de estoque com histórico |
| 🛒 Pedidos | Criação e acompanhamento de pedidos por status |
| ⚡ Baixa Rápida | Saída rápida de estoque sem necessidade de criar pedido |
| 📊 Relatórios | Exportação de dados em diferentes formatos |
| 💾 Backups | Geração e download de backups do banco |
| 👤 Usuários | Gerenciamento de usuários (somente Administrador) |
| 🔐 Autenticação | Login com sessão segura e controle de permissões |

---

## Tecnologias

- **Ruby** 3.2.3
- **Sinatra** 4.x — framework web minimalista
- **Puma** 6.x — servidor de aplicação
- **PostgreSQL** — banco de dados relacional
- **BCrypt** — hash seguro de senhas
- **Roo / Rubyzip** — exportação de planilhas e arquivos ZIP
- **Nokogiri** — geração de XML/HTML
- **Rack Protection** — proteção contra CSRF e XSS

---

## Estrutura do Projeto

```
GerenciadorClaude/
├── app.rb                        # Ponto de entrada da aplicação
├── config.ru                     # Configuração do Rack
├── Gemfile                       # Dependências Ruby
├── schema.sql                    # Schema do banco de dados
├── fix_fk_category.sql           # Correção de FK de categorias
├── iniciar.sh                    # Script de inicialização Linux
├── iniciar.bat                   # Script de inicialização Windows
│
├── models/
│   ├── base.rb                   # Módulo base com conexão ao DB
│   ├── user.rb                   # Model de usuários
│   ├── category.rb               # Model de categorias
│   ├── product.rb                # Model de produtos
│   ├── movement.rb               # Model de movimentações
│   └── order.rb                  # Model de pedidos
│
├── controllers/
│   ├── auth_controller.rb        # Login e logout
│   ├── dashboard_controller.rb   # Página inicial
│   ├── categories_controller.rb  # CRUD de categorias
│   ├── products_controller.rb    # CRUD de produtos
│   ├── movements_controller.rb   # Entradas e saídas
│   ├── orders_controller.rb      # Pedidos
│   ├── reports_controller.rb     # Relatórios
│   └── backups_controller.rb     # Backups
│
├── views/
│   ├── layout.erb                # Layout principal com sidebar
│   ├── login.erb                 # Tela de login
│   ├── dashboard.erb             # Dashboard
│   ├── categories/index.erb
│   ├── products/
│   │   ├── index.erb
│   │   ├── show.erb
│   │   └── form.erb
│   ├── movements/
│   │   ├── index.erb
│   │   └── quick_out.erb
│   ├── orders/
│   │   ├── index.erb
│   │   └── show.erb
│   ├── reports/index.erb
│   ├── backups/index.erb
│   └── errors/
│       ├── forbidden.erb
│       └── low_stock.erb
│
└── public/
    └── style.css                 # Estilos globais
```

---

## Pré-requisitos

### Linux / Windows

- [Ruby 3.2.3](https://www.ruby-lang.org/pt/downloads/)
- [PostgreSQL 14+](https://www.postgresql.org/download/)
- Bundler: `gem install bundler`

### Para compilar o APK Android

- [Android Studio Hedgehog 2023.1.1+](https://developer.android.com/studio)
- JDK 17: `sudo apt install openjdk-17-jdk`
- Android SDK 34

---

## Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/seu-usuario/GerenciadorClaude.git
cd GerenciadorClaude
```

### 2. Instale as dependências

```bash
bundle install
```

---

## Banco de Dados

### Criar o banco e o usuário no PostgreSQL

```bash
sudo -u postgres psql
```

```sql
CREATE USER SEU.USUARIO WITH PASSWORD 'SUA-SENHA';
CREATE DATABASE gerenciador_estoque OWNER SEU.USUARIO;
\q
```

### Criar as tabelas

```bash
psql -U SEU.USUARIO -d gerenciador_estoque -f schema.sql
```

### Criar o usuário administrador inicial

Gere o hash da senha:

```bash
ruby -r bcrypt -e "puts BCrypt::Password.create('admin123', cost: 12)"
```

Copie o hash gerado e insira no banco (substitua `HASH_AQUI`):

```bash
psql -U SEU.USUARIO -d gerenciador_estoque -c \
  "INSERT INTO users (name, email, password_hash, role) \
   VALUES ('Administrador', 'admin@gerenciador.local', 'HASH_AQUI', 'admin');"
```

### Credenciais padrão de acesso

| Campo | Valor |
|---|---|
| E-mail | admin@gerenciador.local |
| Senha | admin123 |

> ⚠️ Troque a senha após o primeiro login em produção.

---

## Como Executar

```bash
bundle exec ruby app.rb
```

Acesse no navegador: [http://localhost:4568](http://localhost:4568)

Para parar o servidor: `Ctrl + C`

---

## Instalação automática (qualquer plataforma)

Cada plataforma possui um script auto-contido em `APK--DEB--BAT(Software)/` que:

1. **Detecta** se você já está dentro do repositório clonado
2. **Se não estiver**, baixa o projeto do GitHub **sem precisar de conta GitHub** (usa ZIP via `curl`/`wget`)
3. **Instala** dependências e configura o ambiente
4. **Inicia** o servidor

| Plataforma | Comando |
|------------|---------|
| 🐧 **Linux** (Debian/Ubuntu) | `cd APK--DEB--BAT\(Software\)/linux && sudo bash install.sh` |
| 🪟 **Windows** | `cd APK--DEB--BAT\(Software\)/windows` → `setup.bat` (como Administrador) |
| 🍎 **macOS** | Duplo clique em `APK--DEB--BAT\(Software\)/macos/start.command` |
| 🐳 **Docker** | `cd APK--DEB--BAT\(Software\)/docker && bash install.sh` |
| 📱 **Android** | Copiar `APK--DEB--BAT\(Software\)/android/GerenciadorERP-Android.apk` para o celular |
| 🌐 **PWA** | `cd APK--DEB--BAT\(Software\)/pwa && bash install.sh` (dentro do repositório) |

> **Não precisa de conta GitHub.** O repositório é público e os scripts baixam via ZIP quando `git` não está disponível.

### Instalação manual (qualquer SO)

```bash
git clone https://github.com/VICTORGG04/GerenciadorClaude.git
cd GerenciadorClaude
bundle install
# Configure o .env (veja .env.example)
ruby db/setup.rb
bundle exec ruby app.rb
```

Acesse: [http://localhost:4568](http://localhost:4568)

---

## Mobile — Como funciona

O app mobile **não processa nada localmente**. Ele é um WebView — uma janela de navegador embutida — que exibe o sistema ERP rodando no servidor do computador da empresa. Toda a lógica, banco de dados e autenticação ficam no PC.

```
[Celular / Tablet]  ◄── Wi-Fi ──►  [PC da Empresa]
  APK Android                       Ruby + Sinatra + PostgreSQL
  PWA iPhone                        Porta: 4568
```

> ⚠️ O celular e o computador **devem** estar conectados ao mesmo Wi-Fi para o app funcionar.

---

## Mobile — Configurar o Servidor

Antes de instalar o app em qualquer dispositivo, configure o servidor para aceitar conexões Wi-Fi.

### 1. Adicione as configurações no `app.rb`

Logo após o bloco `DB = PG.connect(...)`, adicione:

```ruby
# Aceita conexões de qualquer IP da rede local
set :bind, '0.0.0.0'
set :port, 4568
```

### 2. Libere a porta no firewall

**Linux:**
```bash
sudo ufw allow 4568/tcp
sudo ufw reload

# Verificar:
sudo ufw status | grep 4568
```

**Windows:**
Painel de Controle → Firewall do Windows → Regras de Entrada → Nova Regra → Porta → TCP → 4568 → Permitir

### 3. Descubra o IP do servidor

**Linux:**
```bash
ip addr show | grep "inet " | grep -v 127
# Exemplo: inet 192.168.0.6/24 ... wlp6s0
#                ^^^^^^^^^^^^ use este IP no celular
```

**Windows:**
```cmd
ipconfig
# Procure "Endereço IPv4" na interface Wi-Fi
```

### 4. Inicie o servidor

```bash
cd ~/RubymineProjects/GerenciadorClaude
bundle exec ruby app.rb

# Saída esperada — deve ser 0.0.0.0, não 127.0.0.1:
# * Listening on http://0.0.0.0:4568
```

---

## Mobile — Android (APK)

### Opção A — Instalar via cabo USB (recomendado)

**1. Ative o Modo Desenvolvedor no celular**

Vá em **Configurações → Sobre o telefone** e toque **7 vezes seguidas** em **"Número da versão"** até aparecer *"Você agora é um desenvolvedor!"*

> Em alguns celulares fica em: Configurações → Sistema → Sobre o telefone

**2. Ative a Depuração USB**

Vá em **Configurações → Opções do Desenvolvedor**, ative **"Depuração USB"**, conecte o cabo USB ao PC e toque **"OK"** no popup que aparecer no celular.

**3. Verifique se o celular foi reconhecido**

```bash
adb devices

# Saída esperada:
# List of devices attached
# R5CT21XXXXX    device   ← celular reconhecido
```

> Se aparecer `unauthorized`: desbloqueie o celular e aceite o popup.
> Se não aparecer popup: `adb kill-server && adb start-server`

**4. Instale o APK**

```bash
cd ~/RubymineProjects/GerenciadorClaudeAndroide/GerenciadorERP-Android
./gradlew installDebug

# Saída esperada:
# BUILD SUCCESSFUL
# Installed on 1 device.
```

---

### Opção B — Instalar via arquivo (sem cabo)

**1. Localize o APK no PC**

```
~/RubymineProjects/GerenciadorClaudeAndroide/
  GerenciadorERP-Android/app/build/outputs/apk/debug/
    app-debug.apk
```

**2. Transfira o APK para o celular**

Escolha uma das opções:
- **Google Drive** — faça upload e abra no celular
- **WhatsApp** — envie o arquivo para si mesmo
- **Cabo USB** — copie para a pasta Downloads do celular
- **Bluetooth** — envie diretamente

**3. Habilite instalação de fontes desconhecidas**

Vá em **Configurações → Segurança → Instalar apps desconhecidos**, selecione o app que vai abrir o APK (ex: Arquivos, Chrome) e ative **"Permitir desta fonte"**.

> No Android 8+: a permissão é por app, não global.

**4. Instale tocando no arquivo**

Abra o gerenciador de arquivos → pasta Downloads → toque em `app-debug.apk` → toque em **"Instalar"**.

---

### Primeira abertura do app

**5. Configure o servidor**

Na primeira abertura aparecerá a tela de configuração:

- **IP do Servidor:** `192.168.0.6` (o IP do seu PC)
- **Porta:** `4568`
- Toque em **"Conectar"** — ou use **"Encontrar servidor automaticamente"**

> O app salva essa configuração. Nas próximas aberturas vai direto para o sistema.

**6. Faça login**

- **E-mail:** `admin@gerenciador.local`
- **Senha:** `admin123`

**Para trocar o servidor depois:** Menu (⋮) → Trocar Servidor

---

## Mobile — Android (compilar o APK)

### Pré-requisitos

- Android Studio Hedgehog 2023.1.1 ou superior
- JDK 17:
  ```bash
  sudo apt install openjdk-17-jdk -y
  sudo update-alternatives --config java   # selecione Java 17
  java -version                            # confirme: openjdk 17
  ```

### Compilar pelo Android Studio

**1.** File → Open → selecione a pasta `GerenciadorERP-Android`

**2.** Aguarde o Gradle sync terminar

**3. APK de debug (para testes):**
Build → Build Bundle(s) / APK(s) → Build APK(s)
Arquivo: `app/build/outputs/apk/debug/app-debug.apk`

**4. APK de release (para distribuir):**
Build → Generate Signed Bundle / APK → APK
Arquivo: `app/build/outputs/apk/release/app-release.apk`

### Compilar pelo terminal

```bash
cd GerenciadorERP-Android

# Gerar APK debug
./gradlew assembleDebug

# Instalar direto no celular conectado via USB
./gradlew installDebug
```

### Configurar o `local.properties`

Se o Android Studio não encontrar o SDK automaticamente:

```bash
echo "sdk.dir=$HOME/Android/Sdk" > local.properties
```

---

## Mobile — iPhone (PWA)

Não é necessário nenhum arquivo de instalação. O Safari salva o sistema como um app na tela inicial, abrindo em tela cheia sem barra de navegação.

> ⚠️ Use obrigatoriamente o **Safari**. Chrome e Firefox não suportam PWA no iOS.

| Requisito | Valor |
|---|---|
| Versão mínima do iOS | iOS 14+ |
| Navegador obrigatório | Safari |
| Arquivo de instalação | Nenhum |
| Conta Apple | Não necessário |

**1. Conecte o iPhone ao Wi-Fi da empresa**

**2. Abra o Safari e acesse o sistema**

```
http://192.168.0.6:4568
```

(substitua pelo IP do seu servidor)

**3. Adicione à Tela de Início**

Toque no ícone de **compartilhar** (quadrado com seta) → **"Adicionar à Tela de Início"** → **"Adicionar"**.

**4. Abra pelo ícone**

Toque no ícone **ERP Estoque** na tela inicial. Abre em tela cheia sem barra do Safari. Faça login normalmente.

> O iPhone precisa estar na rede Wi-Fi da empresa toda vez que usar o sistema.

---

## Estrutura do App Android

```
GerenciadorERP-Android/
├── app/src/main/
│   ├── java/com/gerenciador/erp/
│   │   ├── ui/
│   │   │   ├── SplashActivity.kt      Tela inicial (1.8s)
│   │   │   ├── SetupActivity.kt       Configuração do IP do servidor
│   │   │   └── MainActivity.kt        WebView principal + monitoramento de rede
│   │   ├── network/
│   │   │   ├── NetworkChecker.kt      Verifica Wi-Fi e alcançabilidade do servidor
│   │   │   └── ServerScanner.kt       Varre a rede para encontrar o servidor
│   │   └── utils/
│   │       └── PreferencesManager.kt  Salva IP/porta em SharedPreferences
│   └── res/
│       ├── layout/
│       │   ├── activity_splash.xml
│       │   ├── activity_setup.xml
│       │   └── activity_main.xml
│       ├── values/
│       │   ├── colors.xml             Paleta dark (igual ao sistema web)
│       │   ├── strings.xml
│       │   └── themes.xml
│       └── xml/
│           └── network_security_config.xml  Permite HTTP em rede local
└── app/build.gradle
```

---

## Rotas da Aplicação

| Método | Rota | Descrição | Permissão |
|---|---|---|---|
| GET | `/login` | Tela de login | Pública |
| POST | `/login` | Autenticar usuário | Pública |
| GET | `/logout` | Encerrar sessão | Logado |
| GET | `/` | Dashboard | Logado |
| GET | `/products` | Listar produtos | Logado |
| GET | `/products/new` | Formulário novo produto | Admin |
| POST | `/products` | Criar produto | Admin |
| GET | `/products/:id` | Detalhes do produto | Logado |
| GET | `/products/:id/edit` | Editar produto | Admin |
| POST | `/products/:id` | Atualizar produto | Admin |
| POST | `/products/:id/delete` | Excluir produto | Admin |
| GET | `/categories` | Listar categorias | Logado |
| POST | `/categories` | Criar categoria | Admin |
| POST | `/categories/:id/delete` | Excluir categoria | Admin |
| GET | `/movements` | Histórico de movimentações | Logado |
| POST | `/movements` | Registrar movimentação | Logado |
| GET | `/quick_out` | Tela de baixa rápida | Logado |
| POST | `/quick_out` | Executar baixa rápida | Logado |
| GET | `/orders` | Listar pedidos | Logado |
| GET | `/orders/:id` | Detalhes do pedido | Logado |
| POST | `/orders` | Criar pedido | Logado |
| GET | `/reports` | Relatórios | Logado |
| GET | `/backups` | Backups | Admin |
| GET | `/users` | Gerenciar usuários | Admin |

---

## Perfis de Usuário

| Perfil | `role` no banco | Acesso |
|---|---|---|
| Administrador | `admin` | Acesso total, incluindo usuários, backups e exclusões |
| Operador | `operator` | Consultas, movimentações e pedidos — sem acesso a configurações |

---

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
|---|---|---|
| `SESSION_SECRET` | valor interno | Chave secreta da sessão — **troque em produção** |
| `DATABASE_URL` | — | Alternativa para configurar conexão via URL |

```bash
SESSION_SECRET="minha_chave_super_secreta" bundle exec ruby app.rb
```

---

## Solução de Problemas

### `PG::UndefinedTable` — tabela não existe
```bash
psql -U SEU.USUARIO -d gerenciador_estoque -f schema.sql
```

### `PG::ForeignKeyViolation` ao excluir categoria
```bash
psql -U SEU.USUARIO -d gerenciador_estoque -f fix_fk_category.sql
```

### `undefined method 'first' for String` no layout.erb
Substitua na linha 63 do `views/layout.erb`:
```erb
<%# antes: %>
<%= current_user.name.split.map(&:first).first(2).join.upcase %>

<%# depois: %>
<%= current_user.name.split.map { |w| w[0] }.first(2).join.upcase %>
```

### Porta 4568 já em uso
```bash
# Linux
lsof -ti:4568 | xargs kill -9

# Windows
netstat -ano | findstr :4568
taskkill /PID <PID> /F
```

### App mobile mostra "Servidor não encontrado"
- Verifique se o servidor Ruby está rodando no PC
- Confirme que aparece `0.0.0.0:4568` (não `127.0.0.1`)
- Certifique-se que celular e PC estão no mesmo Wi-Fi
- Teste abrindo `http://IP:4568` no navegador do celular

### `adb devices` mostra `unauthorized`
```bash
# Desbloqueie o celular e aceite o popup
# Se necessário, reinicie o adb:
adb kill-server && adb start-server
```

### Erro de compilação Android: `Unsupported class file major version`
```bash
sudo apt install openjdk-17-jdk -y
sudo update-alternatives --config java   # selecione Java 17
rm -rf ~/.gradle/caches
./gradlew assembleDebug
```

### SDK não encontrado ao compilar Android
```bash
echo "sdk.dir=$HOME/Android/Sdk" > local.properties
```

### iPhone não salva como app (PWA)
- Use obrigatoriamente o **Safari** (Chrome e Firefox não suportam no iOS)
- Verifique se o iOS é versão 14 ou superior

### IP do servidor mudou e o app não conecta
- **Android:** Menu (⋮) → Trocar Servidor → informe o novo IP
- **iPhone:** Abra o Safari e acesse o novo IP diretamente
- **Dica:** Configure IP fixo no roteador para o PC do servidor

---

## Licença

Projeto privado — todos os direitos reservados.
