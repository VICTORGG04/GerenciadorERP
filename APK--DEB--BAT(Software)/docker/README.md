# 🐳 Gerenciador ERP — Docker

Execute o servidor em qualquer sistema operacional com Docker.

## Pré-requisitos

- Docker instalado ([docs.docker.com/get-docker](https://docs.docker.com/get-docker/))
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

Abra o navegador em: [http://localhost:4568](http://localhost:4568)

- **Login:** `admin@gerenciador.local`
- **Senha:** `admin123`

## Comandos úteis

| Comando | Descrição |
|---------|-----------|
| `docker compose logs -f` | Ver logs em tempo real |
| `docker compose down` | Parar containers |
| `docker compose restart` | Reiniciar serviços |
| `docker compose exec app bundle exec ruby db/setup.rb` | Configurar banco |

## Personalizar senhas

Edite o `docker-compose.yml` (no diretório do projeto) e altere `CHANGE_ME` nos campos `POSTGRES_PASSWORD` e `SESSION_SECRET`. Depois recrie:

```bash
docker compose down -v
docker compose up -d --build
```
