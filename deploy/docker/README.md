# Gerenciador ERP v2.0.3 — Docker

Execute o servidor em qualquer sistema operacional com Docker.

## Pré-requisitos

- Docker: [docs.docker.com/get-docker](https://docs.docker.com/get-docker/)
- Git

## Instalação (1 comando)

```bash
bash install.sh
```

O script:
1. Detecta se está dentro do repositório
2. Se não, clona do GitHub
3. Copia `Dockerfile` e `docker-compose.yml` para a raiz do projeto
4. Sobe os containers com `docker compose up -d --build`

## Acesso

[http://localhost:4568](http://localhost:4568) — `admin@gerenciador.local` / `admin123`

## Comandos úteis

| Comando | Descrição |
|---|---|
| `docker compose logs -f` | Logs em tempo real |
| `docker compose down` | Parar containers |
| `docker compose restart` | Reiniciar serviços |
| `docker compose exec app bundle exec ruby db/setup.rb` | Configurar banco |
| `docker compose port app 4568` | Ver porta mapeada |

## Licenciamento

O sistema funciona no plano **Free** sem configuração. Para planos pagos, configure as variáveis Stripe no `.env` e recrie os containers:

```bash
docker compose down && docker compose up -d --build
```

## Personalizar senhas

Edite o `docker-compose.yml` e altere `CHANGE_ME` nos campos `POSTGRES_PASSWORD` e `SESSION_SECRET`:

```bash
docker compose down -v
docker compose up -d --build
```
