# 🪟 Gerenciador ERP — Windows

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
5. Inicia o servidor em http://localhost:4568

### 3. Configurar banco

Edite o arquivo `.env` em `C:\Program Files\GerenciadorERP\repo\.env` com as credenciais do PostgreSQL.

**Importante:** Crie o banco manualmente:
```sql
CREATE DATABASE gerenciador_estoque;
CREATE USER gerenciador_erp WITH PASSWORD 'sua_senha';
GRANT ALL PRIVILEGES ON DATABASE gerenciador_estoque TO gerenciador_erp;
```

### 4. Acessar

Abra: http://localhost:4568

- E-mail: `admin@gerenciador.local`
- Senha: `admin123`

## Se já tem o repositório clonado

Se você já clonou o repositório inteiro, pode executar o script de dentro dele:

```bash
cd GerenciadorClaude\APK--DEB--BAT\(Software\)\windows
powershell -ExecutionPolicy Bypass -File gerenciador-erp.ps1
```

## Licenciamento

O sistema funciona no plano **Free** (50 produtos, 1 usuário). Para ativar planos pagos, edite o `.env` em `C:\Program Files\GerenciadorERP\repo\.env` e preencha o `LICENSE_TOKEN` fornecido pelo desenvolvedor.

## Gerenciar o servidor

```powershell
# Parar
taskkill /F /IM ruby.exe

# Iniciar
start.bat
```

Para descobrir o processo na porta:

```powershell
netstat -ano | findstr :4568
taskkill /PID <PID> /F
```

## Solução de problemas

**Erro de execução PowerShell**: Execute `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` como administrador.

**Erro "libpq.dll"**: Adicione o diretório `bin` do PostgreSQL ao PATH do sistema.

**Firewall**: Libere a porta 4568 para acesso de outros dispositivos na rede.
