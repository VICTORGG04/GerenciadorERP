# COMO GERAR LICENÇAS — Guia do Desenvolvedor

> ⚠️ Este guia é **exclusivo para o desenvolvedor**. Os arquivos `GerarLicenca.rb` e `chave_privada.pem` **nunca** devem ser distribuídos para clientes ou incluídos em builds.

---

## 1. Visão Geral

O licenciamento do Gerenciador ERP usa **assinatura digital Ed25519**. A chave privada (`chave_privada.pem`) fica apenas na máquina do desenvolvedor. O servidor tem apenas a chave pública (hardcoded na `app.rb`), então mesmo com acesso ao código-fonte o cliente **não consegue forjar** um token.

### Fluxo completo

```
Dev gera token ──▶ Cliente recebe token + Licença.odt ──▶ Cliente cola no /licenses ──▶ Servidor valida (Ed25519/HMAC) ──▶ Plano liberado
```

### Token Free

O plano **Free** é ativado automaticamente quando nenhum `LICENSE_TOKEN` é configurado. Não é necessário gerar token para clientes Free — basta fornecer o `Licença-Free.odt`.

---

## 2. Planos

| Plano | Produtos | Usuários | Funcionalidades | Preço |
|-------|----------|----------|-----------------|-------|
| **Free** | até 50 | 1 | Dashboard, produtos, importação, PWA | Gratuito |
| **Gold** | até 500 | 3 | Free + categorias, movimentações, Android, baixa rápida, usuários | Pago |
| **Platinum** | ilimitado | ilimitado | Gold + pedidos, relatórios, backup, auditoria, estoque completo | Pago |
| **Enterprise** | ilimitado | ilimitado | Platinum + whitelabel, código-fonte, treinamento | Pago |

Apenas **Gold**, **Platinum** e **Enterprise** exigem token gerado manualmente.

---

## 3. Pré-requisitos

- **Ruby 3.x** instalado
- `openssl` disponível no PATH
- `GerarLicenca.rb` no diretório atual
- `chave_privada.pem` no mesmo diretório do script

### Gerar a chave privada (uma vez)

```bash
openssl genpkey -algorithm ed25519 -out chave_privada.pem
```

### Extrair a chave pública (opcional, já está hardcoded)

```bash
openssl pkey -in chave_privada.pem -pubout -out chave_publica.pem
```

> A chave pública extraída deve coincidir com a `ED25519_PUBLIC_KEY` em `app.rb`. Se mudar a chave privada, é preciso atualizar a pública no código e reconstruir o `.deb`.

---

## 4. Gerar Token (passo a passo)

### Sintaxe

```bash
ruby GerarLicenca.rb <plano> <dias> <identificador>
```

| Argumento | Descrição |
|-----------|-----------|
| `plano` | `gold`, `platinum` ou `enterprise` |
| `dias` | Quantidade de dias de validade (padrão: 365) |
| `identificador` | Código de referência (ex: `LIC-001`, CNPJ, nome do cliente) |

### Exemplos

```bash
# Gold — 365 dias — cliente LIC-001
ruby GerarLicenca.rb gold 365 LIC-001

# Platinum — 730 dias (2 anos)
ruby GerarLicenca.rb platinum 730 LIC-002

# Enterprise — 3650 dias (10 anos) — CNPJ como ID
ruby GerarLicenca.rb enterprise 3650 "12.345.678/0001-90"

# Gold — 30 dias (teste/trial)
ruby GerarLicenca.rb gold 30 "Cliente Trial"
```

### Modo interativo

Se executar sem argumentos, o script pergunta plano, dias e identificador:

```bash
ruby GerarLicenca.rb
```

### Exemplo de saída

```
══════════════════════════════════════════════════════
  Gerenciador ERP — Licença Gerada (Ed25519)
══════════════════════════════════════════════════════

  Plano:      GOLD
  Cliente:    LIC-001
  Válido até: 15/06/2027 22:30
  Dias:       365

  LICENSE_TOKEN=gold.1798768200.LIC-001.7sK2mX9...3qBw

══════════════════════════════════════════════════════
```

---

## 5. Criar a Licença.odt do cliente

O arquivo `APK--DEB--BAT(Software)/Licença.odt` é a **matriz** com os 4 planos. Para cada cliente, você deve:

1. **Copiar** `Licença.odt` para um novo arquivo (ex: `Cliente-XYZ-Licenca.odt`)
2. **Abrir** no LibreOffice Writer
3. **Editar** a **Cláusula 4** — remover os planos que o cliente **não** contratou, deixando apenas o plano dele
4. **Personalizar** dados do cliente no cabeçalho se necessário
5. **Exportar como PDF** e enviar ao cliente junto com o token

### Exemplo

Para um cliente **Gold**, remova as linhas de Platinum e Enterprise da Cláusula 4, mantendo apenas Free e Gold.

> O `Licença-Free.odt` já está pronto para clientes Free — basta entregá-lo sem modificações.

---

## 6. Cadastrar o cliente no sistema

1. Acesse o painel admin em **`/licenses`**
2. Clique em **"Novo Cliente"**
3. Preencha os dados:
   - Nome / Razão Social
   - CNPJ/CPF
   - Endereço
   - Contato (telefone, email)
4. **Cole o token** gerado no campo "Token de Licença"
5. O sistema valida a assinatura e mostra o plano detectado
6. Salve — a sidebar passará a exibir o nome do cliente e o plano

> O token também pode ser colado **depois** da criação do cliente, via botão "Editar".

---

## 7. Clientes Free

Clientes no plano Free **não precisam de token**. O sistema funciona em Free automaticamente quando não há `LICENSE_TOKEN` no `.env` nem token vinculado ao registro.

**O que entregar ao cliente Free:**

- `Licença-Free.odt` (ou o PDF exportado) como contrato de adesão
- Instruções de instalação (veja `COMO-USAR-CLIENTE.md`)

---

## 8. Dicas e Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `ERRO: chave_privada.pem não encontrado` | Chave ausente | Gere com `openssl genpkey -algorithm ed25519 -out chave_privada.pem` |
| `Token inválido` no painel | Token corrompido ou de outro plano | Gere novamente e cole com cuidado |
| Token não funciona após colar | Assinatura Ed25519 não confere | Verifique se a chave pública em `app.rb` corresponde à privada |
| Cliente Gold/Platinum vendo features do Free | Token não reconhecido | Confirme se o `LICENSE_TOKEN` está no `.env` ou no registro em `/licenses` |
| Plano não libera após reinício | Token expirado | Verifique a data de expiração no token e gere um novo se necessário |

### Verificar se a chave pública e privada combinam

```bash
# Extrair pública da privada
openssl pkey -in chave_privada.pem -pubout

# Comparar com a hardcoded em app.rb
grep ED25519_PUBLIC_KEY app.rb
```

---

## 9. Arquivos

| Arquivo | Finalidade | Git? | Build? |
|---------|-----------|------|--------|
| `GerarLicenca.rb` | Gerador de tokens Ed25519 | gitignored | ❌ Não incluído |
| `chave_privada.pem` | Chave privada do desenvolvedor | gitignored | ❌ Não incluído |
| `chave_publica.pem` | Chave pública (opcional, já hardcoded) | gitignored | ❌ Não incluído |
| `app.rb` (ED25519_PUBLIC_KEY) | Chave pública para validação no servidor | ✔ Tracked | ✅ Incluído |
| `Licença.odt` | Contrato master (4 planos) — editar por cliente | ✔ Tracked | ✅ Incluído |
| `Licença-Free.odt` | Contrato Free (pronto para uso) | ✔ Tracked | ✅ Incluído |

---

> ⬡ **Gerenciador ERP** — © 2026
