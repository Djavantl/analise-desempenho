# Avaliação de Desempenho: Laravel vs. Django

Estudo comparativo de desempenho entre dois frameworks REST em ambiente controlado via Docker.
Experimento fatorial **2×3**: 2 tecnologias × 3 níveis de concorrência × 10 repetições = **60 execuções**.

---

## Tecnologias

| Camada | Tecnologia |
| --- | --- |
| API A | PHP 8.2 + Laravel 11 + Nginx + PHP-FPM |
| API B | Python 3.12 + Django 4.2 + Gunicorn |
| Banco de dados | PostgreSQL 15 (instância única compartilhada) |
| Geração de carga | k6 (Grafana) |

---

## Fatores e Níveis do Experimento

| Fator | Níveis |
| --- | --- |
| **A — Tecnologia** | Laravel, Django |
| **B — Concorrência** | 10, 50, 100 VUs simultâneos |

**Variáveis de resposta:** latência média (ms) e throughput (RPS).

---

## Estrutura do Projeto

```text
analise_desempenho/
├── docker-compose.yml        # Orquestração de todos os serviços
├── db/
│   └── init.sql              # Cria a tabela `items` no primeiro boot do Postgres
├── laravel-app/
│   ├── Dockerfile            # PHP 8.2-FPM + Nginx + Supervisor
│   ├── nginx.conf            # Nginx escutando na porta 8000, proxy para PHP-FPM
│   ├── supervisord.conf      # Gerencia PHP-FPM e Nginx no mesmo container
│   ├── entrypoint.sh         # Gera APP_KEY, cacheia config/routes, migra e sobe
│   └── src/                  # Código da aplicação (sobrescreve o create-project)
│       ├── bootstrap/app.php # Habilita routes/api.php no Laravel 11
│       ├── app/
│       │   ├── Models/Item.php
│       │   └── Http/Controllers/ItemController.php
│       └── routes/api.php    # GET /api/items
├── django-app/
│   ├── Dockerfile            # Python 3.12 slim
│   ├── entrypoint.sh         # Migra e sobe Gunicorn com 4 workers
│   ├── requirements.txt      # Django, DRF, psycopg2, gunicorn
│   ├── manage.py
│   ├── config/               # Projeto Django (settings, urls, wsgi)
│   └── api/                  # App Django
│       ├── models.py         # Model Item (managed=False, aponta para tabela `items`)
│       ├── serializers.py
│       ├── views.py          # GET /api/items
│       └── urls.py
└── scripts/
    ├── load_test.js          # Script k6 parametrizável
    └── run_experiment.sh     # Executa as 60 combinações automaticamente
```

---

## Endpoint Testado

Ambas as APIs expõem o mesmo endpoint de leitura com consulta ao banco:

```http
GET /api/items
```

Retorna todos os registros da tabela `items` em JSON.
As APIs usam a mesma tabela e os mesmos dados — garantindo isonomia nos testes.

---

## Restrições de Recursos (Isonomia)

Cada container de API tem limites rígidos definidos no `docker-compose.yml`:

- **CPU:** 1 vCPU
- **Memória:** 512 MB RAM
- **Rede:** rede interna Docker (`perf-network`)

---

## Passo a Passo para Rodar

### 1. Subir o banco de dados

```bash
docker compose up -d db
```

O Postgres executa automaticamente `db/init.sql` na primeira inicialização,
criando a tabela `items`.

### 2. Popular a tabela com dados

Conecte ao banco e insira os produtos que serão consultados durante os testes:

```bash
docker compose exec db psql -U user -d perf_db
```

Exemplo de inserção:

```sql
INSERT INTO items (name, description, price)
SELECT
    'Produto ' || i,
    'Descrição do produto ' || i,
    round((random() * 99 + 1)::numeric, 2)
FROM generate_series(1, 100) AS i;
```

### 3. Testar uma API por vez

Os testes são feitos com **uma API no ar de cada vez**.
A API ociosa deve estar parada para não consumir recursos.

**Testar Laravel:**

```bash
docker compose up -d laravel-api
# aguarde o container ficar healthy, então rode os testes
docker compose stop django-api   # garantir que Django está parado
```

**Testar Django:**

```bash
docker compose up -d django-api
docker compose stop laravel-api   # garantir que Laravel está parado
```

### 4. Rodar um teste avulso (k6)

```bash
docker compose run --rm k6 run \
  --env TARGET_URL=http://laravel-api:8000 \
  --env VUS=50 \
  --env DURATION=30s \
  /scripts/load_test.js
```

Parâmetros disponíveis:

| Variável | Descrição | Padrão |
| --- | --- | --- |
| `TARGET_URL` | URL da API alvo | `http://laravel-api:8000` |
| `VUS` | Número de usuários virtuais simultâneos | `10` |
| `DURATION` | Duração do teste | `30s` |

### 5. Rodar o experimento completo (60 execuções)

Com o banco populado e **apenas a API alvo no ar**:

```bash
bash scripts/run_experiment.sh
```

Os resultados são salvos em `scripts/results/` com o formato:

```text
laravel_vu10_rep1.json
laravel_vu50_rep3.json
django_vu100_rep7.json
...
```

---

## Estrutura das APIs

### Laravel

O projeto é gerado via `composer create-project laravel/laravel` no build do Docker.
Os arquivos em `laravel-app/src/` sobrescrevem o scaffolding padrão.

```text
Requisição → Nginx (porta 8000)
           → PHP-FPM (porta 9000, processo interno)
           → Laravel Router → ItemController → Eloquent ORM → PostgreSQL
```

O servidor usa **Nginx + PHP-FPM gerenciados pelo Supervisor** dentro do mesmo container.
PHP-FPM usa o pool padrão com `pm = dynamic`.

### Django

Projeto Django mínimo, sem apps desnecessários (sem admin, auth, sessions).

```text
Requisição → Gunicorn (porta 8000, 4 workers síncronos)
           → Django Router → item_list view → DRF Serializer → ORM → PostgreSQL
```

O model `Item` usa `managed = False`: Django lê a tabela `items` sem tentar criá-la
ou modificá-la via migrations — a tabela é de responsabilidade do `db/init.sql`.

---

## Portas Expostas (acesso do host)

| Serviço | Porta no host |
| --- | --- |
| Laravel API | `localhost:8001` |
| Django API | `localhost:8002` |
| PostgreSQL | não exposta (acesso via `docker compose exec`) |
