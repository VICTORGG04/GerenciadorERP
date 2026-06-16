# 🍎 Gerenciador ERP — macOS

## Instalação rápida

### Pré-requisitos (uma vez)

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ruby + PostgreSQL
brew install ruby postgresql@16
brew services start postgresql@16

# Git (Xcode Command Line Tools)
xcode-select --install
```

### Iniciar

**Opção 1:** Dê duplo clique em `start.command`

**Opção 2:** Arraste `GerenciadorERP.app` para a pasta Aplicativos e clique

Na primeira execução, o script:
1. Detecta que não está dentro do repositório
2. Clona o projeto do GitHub para `~/GerenciadorERP/repo/`
3. Cria o `.env` a partir do `.env.example`
4. Executa `bundle install` + `db/setup.rb`
5. Abre o navegador em http://localhost:4568

### Configurar banco

Crie o banco PostgreSQL manualmente:

```bash
brew services start postgresql@16
createuser -s gerenciador_erp
createdb -O gerenciador_erp gerenciador_estoque
```

Edite `~/GerenciadorERP/repo/.env` com as credenciais.

### Acessar

http://localhost:4568

- E-mail: `admin@gerenciador.local`
- Senha: `admin123`

### Gerenciar o servidor

```bash
# Parar
pkill -f "ruby app.rb"

# Iniciar
bash start.command

# Ver processo na porta
lsof -i :4568

# Matar por porta
lsof -ti:4568 | xargs kill -9
```

> A porta pode ser diferente de 4568. Confirme no arquivo `.env` ou com `lsof -i`.

### Auto-início (opcional)

```bash
cp com.gerenciador.erp.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.gerenciador.erp.plist
```
