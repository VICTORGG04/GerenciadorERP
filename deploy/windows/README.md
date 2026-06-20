# Gerenciador ERP v2.0.3 — Windows

## Instalação rápida

### 1. Instalar dependências (como Administrador)

Clique com botão direito em `setup.bat` > "Executar como administrador".

Isso instala via [Chocolatey](https://chocolatey.org/):
- Ruby
- PostgreSQL
- Em seguida, o PowerShell baixa o repositório e instala as gems

### 2. Iniciar o servidor

Dê duplo clique em `start.bat`.

Na primeira execução, o PowerShell:
1. Detecta que não está dentro do repositório
2. Baixa o projeto do GitHub para `C:\Program Files\GerenciadorERP\repo\`
3. Cria o `.env` a partir do `.env.example`
4. Executa `bundle install`
5. Executa `ruby db/setup.rb`
6. Inicia o servidor em http://localhost:4568

### 3. Configurar banco

Edite o `.env` em `C:\Program Files\GerenciadorERP\repo\.env` com as credenciais do PostgreSQL.

### 4. Acessar

Abra: http://localhost:4568

- E-mail: `admin@gerenciador.local`
- Senha: `admin123`

## Se já tem o repositório clonado

```bash
cd GerenciadorClaude\deploy\windows
powershell -ExecutionPolicy Bypass -File gerenciador-erp.ps1
```

## Gerenciar o servidor

```powershell
taskkill /F /IM ruby.exe    # Parar
start.bat                   # Iniciar
netstat -ano | findstr :4568
taskkill /PID <PID> /F
```

## Solução de problemas

- **Erro de execução PowerShell**: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Erro "libpq.dll"**: Adicione o diretório `bin` do PostgreSQL ao PATH do sistema
- **Firewall**: Libere a porta 4568 para acesso de outros dispositivos na rede
