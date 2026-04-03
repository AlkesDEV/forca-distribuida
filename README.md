# Forca Distribuída 🎯

Jogo da Forca multiplayer distribuído, construído com **Ruby on Rails** (backend), **React** (frontend) e orquestrado via **Docker Compose**. O sistema garante alta disponibilidade com duas instâncias de backend balanceadas por Nginx, usando Redis como barramento de comunicação e estado compartilhado.

---

## Arquitetura

```
┌──────────────────────────────────────────────────────┐
│                  Cliente (Navegador)                  │
│               WebSocket ws://localhost/cable          │
└────────────────────────┬─────────────────────────────┘
                         │
                ┌────────▼────────┐
                │   Nginx :80     │  ← Load Balancer + Reverse Proxy
                │  least_conn     │    (WebSocket upgrade, failover)
                └───┬─────────┬──┘
                    │         │
          ┌─────────▼──┐  ┌───▼──────────┐
          │ backend-1  │  │  backend-2   │  ← Rails 7 + Action Cable
          │  :3000     │  │   :3000      │    (2 instâncias independentes)
          └─────────┬──┘  └───┬──────────┘
                    │         │
                ┌───▼─────────▼───┐
                │     Redis       │  ← Estado compartilhado
                │   :6379         │    Fila de pareamento, sessões de jogo,
                └─────────────────┘    Pub/Sub para Action Cable
                         │
                ┌────────▼────────┐
                │    frontend     │  ← React SPA (build estático via Nginx)
                │    :80          │
                └─────────────────┘
```

### Decisões de Arquitetura

| Componente | Escolha | Justificativa |
|---|---|---|
| **WebSocket** | Action Cable | Integrado ao Rails, suporte nativo a pub/sub via Redis |
| **Estado compartilhado** | Redis Hash + List | Latência sub-milissegundo; persistência com AOF; sem schema |
| **Fila de pareamento** | Redis List (`LPOP`/`RPUSH`) | Operação atômica — segura com múltiplas instâncias de backend |
| **Sincronização entre backends** | Redis Pub/Sub (Action Cable) | Mensagens são roteadas pelo Redis, qualquer instância pode entregar |
| **Load balancing** | Nginx `least_conn` | Distribui conexões WebSocket de forma justa; failover automático |
| **Reconexão** | WebSocket client (30s) | Em caso de falha, o adversário vence automaticamente |

---

## Requisitos

- [Docker](https://docs.docker.com/get-docker/) ≥ 24
- [Docker Compose](https://docs.docker.com/compose/) ≥ 2.20
- Portas livres: **80**

---

## Início Rápido

```bash
# 1. Clone o repositório
git clone <repo-url> forca-distribuida
cd forca-distribuida

# 2. (Opcional) Edite palavras.txt para adicionar suas palavras
nano palavras.txt

# 3. Suba todos os serviços
docker compose up --build

# 4. Abra dois navegadores em http://localhost
#    Os jogadores são pareados automaticamente!
```

> A primeira build demora ~3-5 minutos (instalação de gems e npm).  
> Builds subsequentes usam cache do Docker e são muito mais rápidas.

---

## Serviços e Portas

| Serviço | Container | Porta externa | Descrição |
|---|---|---|---|
| nginx | forca-nginx | **80** | Ponto de entrada único |
| frontend | forca-frontend | interno | React SPA |
| backend-1 | forca-backend-1 | interno | Rails + Action Cable |
| backend-2 | forca-backend-2 | interno | Rails + Action Cable |
| redis | forca-redis | interno | Estado e pub/sub |

---

## Como Jogar

1. Abra **http://localhost** no navegador.
2. O sistema gera um ID de jogador único (salvo no `localStorage`).
3. **Primeiro jogador** entra na fila e vê "Aguardando adversário...".
4. **Segundo jogador** se conecta → o jogo inicia automaticamente para os dois.
5. Jogadores se alternam adivinhando letras (clique no teclado visual ou use o teclado físico).
6. Vence quem adivinhar a palavra antes de 6 erros!
7. Clique **"Jogar Novamente"** para iniciar um novo pareamento.

---

## Regras do Jogo

- **6 erros máximos**: cabeça, tronco, braço esquerdo, braço direito, perna esquerda, perna direita.
- **Vitória**: palavra completamente adivinhada.
- **Derrota**: 6 partes do boneco desenhadas.
- **Abandono**: se um jogador desconectar por mais de 30s, o adversário vence automaticamente.
- Letras já tentadas não podem ser repetidas.

---

## Monitoramento

### Verificar status dos serviços
```bash
docker compose ps
```

### Logs em tempo real
```bash
# Todos os serviços
docker compose logs -f

# Apenas backends
docker compose logs -f backend-1 backend-2

# Apenas nginx (ver roteamento)
docker compose logs -f nginx
```

### Health check do backend
```bash
# Backend 1
curl http://localhost/api/v1/status | jq

# Exemplo de resposta:
# {
#   "status": "ok",
#   "server_id": "backend-1",
#   "redis": "connected",
#   "timestamp": "2025-01-01T12:00:00Z"
# }
```

### Inspecionar o Redis
```bash
# Conectar ao Redis
docker compose exec redis redis-cli

# Ver jogos ativos
KEYS forca:game:*

# Ver estado de um jogo
HGETALL forca:game:<game-id>

# Ver fila de espera
LRANGE forca:queue 0 -1

# Ver todos os jogadores
KEYS forca:player:*
```

### Métricas de containers
```bash
docker stats forca-backend-1 forca-backend-2 forca-redis forca-nginx
```

---

## Testando Escalabilidade e Redundância

### Simular falha de um backend
```bash
# Derrubar backend-1
docker compose stop backend-1

# Nginx automaticamente redireciona para backend-2
# Abra http://localhost — o sistema continua funcionando

# Restaurar
docker compose start backend-1
```

### Testar múltiplos jogos simultâneos
```bash
# Abrir 4+ abas no navegador = 2+ jogos simultâneos
# Ou usar múltiplos perfis do Chrome
```

### Verificar balanceamento de carga
```bash
# Fazer várias requisições e observar qual backend responde
for i in $(seq 1 10); do
  curl -s http://localhost/api/v1/status | jq -r '.server_id'
done
```

---

## Estrutura do Projeto

```
forca-distribuida/
├── backend/                      # Ruby on Rails (API only)
│   ├── app/
│   │   ├── channels/
│   │   │   ├── application_cable/
│   │   │   │   ├── channel.rb    # Base do Action Cable
│   │   │   │   └── connection.rb # Identificação do jogador
│   │   │   └── game_channel.rb   # Lógica WebSocket do jogo
│   │   ├── controllers/
│   │   │   └── api/v1/
│   │   │       ├── health_controller.rb
│   │   │       └── games_controller.rb
│   │   └── services/
│   │       └── game_service.rb   # Lógica central do jogo + Redis
│   ├── config/
│   │   ├── application.rb
│   │   ├── cable.yml             # Action Cable → Redis adapter
│   │   ├── puma.rb
│   │   ├── routes.rb
│   │   ├── environments/
│   │   └── initializers/
│   │       ├── oj.rb             # JSON otimizado
│   │       └── redis.rb          # Cliente Redis global (REDIS)
│   ├── Dockerfile
│   ├── Gemfile
│   └── entrypoint.sh
├── frontend/                     # React 18
│   ├── src/
│   │   ├── App.js                # WebSocket, reconexão, estado global
│   │   ├── components/
│   │   │   ├── GameBoard.js      # Tabuleiro, teclado, palavra
│   │   │   ├── HangmanSVG.js     # Boneco SVG animado
│   │   │   ├── WaitingScreen.js  # Tela de espera
│   │   │   ├── ResultScreen.js   # Resultado final
│   │   │   └── ConnectionStatus.js
│   ├── Dockerfile
│   └── package.json
├── nginx/
│   └── nginx.conf                # Load balancer + WebSocket proxy
├── docker-compose.yml
├── palavras.txt                  # Lista de palavras do jogo
└── README.md
```

---

## Fluxo de Comunicação WebSocket

```
Cliente A                    Nginx            Backend-1         Redis
    │                          │                  │               │
    │── WS connect ───────────►│── proxy ────────►│               │
    │                          │                  │── RPUSH queue►│
    │◄── {type:"waiting"} ─────│◄────────────────│               │
    │                          │                  │               │
Cliente B                      │                  │               │
    │── WS connect ───────────►│── proxy ────────►│               │
    │                          │                  │── LPOP queue ►│
    │                          │                  │◄─ player_A_id─│
    │                          │                  │               │
    │                          │                  │── HSET game ──►│
    │◄── {game_state} ─────────│◄────────────────│               │
    │                          │                  │               │
    │── guess_letter("a") ────►│── proxy ────────►│               │
    │                          │                  │── HSET game ──►│
    │◄── {game_state} ─────────│◄────────────────│               │
Cliente B ◄── {game_state} ───│◄── broadcast ────│               │
```

---

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
|---|---|---|
| `REDIS_URL` | `redis://redis:6379/0` | URL do Redis |
| `SERVER_ID` | hostname | Identificador do servidor (para logs) |
| `RAILS_ENV` | `production` | Ambiente Rails |
| `PORT` | `3000` | Porta do Puma |
| `WEB_CONCURRENCY` | `2` | Workers Puma |
| `RAILS_MAX_THREADS` | `5` | Threads por worker |
| `SECRET_KEY_BASE` | (definido no compose) | Chave secreta Rails |
| `REACT_APP_CABLE_URL` | `ws://localhost/cable` | URL do WebSocket para o frontend |

---

## Desenvolvimento Local (sem Docker)

```bash
# Redis (necessário)
docker run -d -p 6379:6379 redis:7.2-alpine

# Backend
cd backend
bundle install
REDIS_URL=redis://localhost:6379/0 RAILS_ENV=development bundle exec puma -C config/puma.rb

# Frontend
cd frontend
npm install
REACT_APP_CABLE_URL=ws://localhost:3000/cable npm start
```

---

## Tecnologias Utilizadas

- **Ruby 3.2.2** + **Rails 7.1** — backend API + WebSocket
- **Action Cable** — abstração WebSocket integrada ao Rails
- **Redis 7.2** — estado compartilhado, fila de pareamento, pub/sub
- **React 18** — frontend SPA
- **Nginx 1.25** — load balancer com suporte a WebSocket
- **Docker + Docker Compose** — containerização e orquestração
- **Puma** — servidor web multi-threaded para Rails
