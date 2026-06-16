# ERP Estoque — Guia do Cliente

## O que é

Sistema de controle de estoque. Acessado pelo navegador do computador ou pelo aplicativo Android, ambos conectados ao servidor que fica no computador da empresa.

---

## 1. Acessar pelo navegador

Abra o Chrome, Firefox ou Edge e digite:

```
http://192.168.0.6:4568
```

> **A porta pode variar.** Se não conseguir acessar, pergunte ao administrador qual é a porta correta (pode ser 4569, 8080 etc.).

Qualquer computador na rede Wi-Fi da empresa pode acessar.

---

## 2. Acessar pelo celular (App Android)

### Instalação

1. Copie o arquivo `app-debug.apk` para o celular (enviar por e-mail, WhatsApp, Drive, etc.)
2. No celular, abra o arquivo APK e instale
   - Pode ser necessário permitir "Instalar de fontes desconhecidas"
3. Abra o aplicativo "ERP Estoque"

### Configuração inicial

Na primeira vez, o app pede o IP do servidor:

```
IP:   192.168.0.6
Porta: 4568
```

> A porta pode ser diferente (ex: 4569, 8080). Confirme com o administrador.

Toque em **"Conectar"**.

> O celular precisa estar na **mesma rede Wi-Fi** que o computador do servidor.

---

## 3. Login

- **Usuário:** admin
- **Senha:** admin123

(Altere a senha após o primeiro acesso)

---

## 4. O servidor não está ligado?

O sistema funciona enquanto o computador estiver ligado e o servidor rodando.

- Se o computador desligar, o sistema para
- Ligue o computador e inicie o servidor novamente
- O celular tentará reconectar automaticamente quando o servidor voltar

### Como reiniciar o servidor (para o administrador)

```bash
sudo systemctl restart gerenciador-erp
```

Se o servidor estiver rodando manualmente (terminal), pressione `Ctrl + C` e inicie de novo:

```bash
cd ~/RubymineProjects/GerenciadorClaude
bundle exec ruby app.rb
```

---

## 5. Problemas comuns

| Problema | Solução |
|----------|---------|
| "Servidor não encontrado" | Verifique se o computador está ligado e no mesmo Wi-Fi |
| "Sem conexão de rede" | Conecte o celular no Wi-Fi da empresa |
| Tela em branco | Puxe a tela para baixo para recarregar (pull-to-refresh) |
| Esqueceu a senha | Contate o administrador |

---

## 6. Planos do sistema

| Plano | Produtos | Usuários | Descrição |
|-------|:--------:|:--------:|-----------|
| **Free** | 50 | 1 | Padrão — sem custo |
| **Gold** | 500 | 3 | Funcionalidades intermediárias |
| **Platinum** | Ilimitado | Ilimitado | Funcionalidades completas |
| **Enterprise** | Ilimitado | Ilimitado | Completo + personalização |

Seu plano é definido por um token de licença configurado pelo responsável técnico. Para alterar o plano, contate o administrador.

## 7. Suporte

Em caso de dúvidas, entre em contato com o responsável técnico.
