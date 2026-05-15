# Manual de Execução dos Testes

## Experimento

**Planejamento fatorial 2×3:**

| Fator | Níveis |
| --- | --- |
| A — Tecnologia | Laravel (PHP 8.4), Django (Python 3.12) |
| B — Concorrência | 10, 50 e 100 VUs simultâneos |

- **Repetições por combinação:** 10
- **Total de execuções:** 60
- **Duração por execução:** 15s aquecimento + 30s medição + 5s ramp-down
- **Ferramenta de carga:** k6 (Grafana)
- **Endpoint testado:** `GET /api/items` (leitura com consulta ao banco)
- **Variáveis de resposta:** latência média (ms) e throughput (RPS)

Cada API é testada isoladamente. Enquanto uma está sendo testada, a outra fica parada.

---

## Controle de Validade das Repetições

Para que as 10 repetições sejam **de fato independentes** (como descrito ao professor), o experimento adota três mecanismos:

### 1. Pausa entre repetições

Após cada execução, o experimento aguarda 15 segundos antes de iniciar a próxima repetição. Isso permite que o servidor libere conexões, filas e buffers acumulados durante a carga, aproximando o estado inicial de cada repetição.

### 2. Fase de aquecimento no k6 (ramp-up de 15s)

Cada execução k6 começa com 15 segundos de ramp-up gradual até atingir o número de VUs alvo. Esse período aquece o servidor de forma controlada antes da janela de medição estável de 30 segundos.

```text
Timeline de cada execução:
|-- 15s ramp-up --|-- 30s medição --|-- 5s ramp-down --|
   (aquecimento)     (dados válidos)     (encerramento)
```

**O resumo do k6 no terminal e o arquivo JSON contêm dados de todo o período.** Para a análise acadêmica, o que vale são os números consolidados do `http_req_duration` (latência) e `http_reqs` (RPS) reportados ao final de cada execução — o k6 calcula esses valores sobre toda a janela, mas como o ramp-up é gradual e curto, o impacto na média é pequeno e aceitável para o nível do experimento.

---

## Pré-requisitos

- Docker e Docker Compose instalados
- `make` instalado
- Porta 8001 (Laravel) e 8002 (Django) livres no host

---

## Configuração Inicial (fazer uma única vez)

### 1. Construir as imagens

```bash
make build
```

### 2. Subir o banco e popular com os dados

```bash
make db
```

O banco sobe, executa `db/init.sql` (cria a tabela `items`) e em seguida `db/seed.sql` (insere os 100 produtos). Aguarde o container `db-seed` terminar com status `Exited (0)`.

Verifique se os dados foram inseridos:

```bash
make db-count
```

Resultado esperado: `total_items = 100`.

---

## Parte 1 — Testes com Laravel

### Subir apenas o Laravel (Django fica parado)

```bash
make up laravel
```

Aguarde o container `laravel-api` estar pronto. Verifique:

```bash
make curl-laravel
```

Deve retornar um JSON com a lista de produtos.

### Executar o experimento completo do Laravel (30 execuções)

```bash
make experiment-laravel
```

Isso roda automaticamente:

- 10 VUs × 10 repetições = 10 arquivos
- 50 VUs × 10 repetições = 10 arquivos
- 100 VUs × 10 repetições = 10 arquivos

**Total: 30 execuções de 30 segundos cada.**

Os resultados ficam em `scripts/results/`:

```text
laravel_vu10_rep1.json
laravel_vu10_rep2.json
...
laravel_vu100_rep10.json
```

### Executar um teste avulso (opcional)

```bash
make k6-laravel VUS=50 DURATION=30s
```

### Parar o Laravel ao terminar

```bash
make stop
```

---

## Parte 2 — Testes com Django

### Subir apenas o Django (Laravel fica parado)

```bash
make up django
```

Aguarde o container `django-api` estar pronto. Verifique:

```bash
make curl-django
```

Deve retornar o mesmo JSON de produtos.

### Executar o experimento completo do Django (30 execuções)

```bash
make experiment-django
```

Mesma lógica do Laravel:

- 10 VUs × 10 repetições
- 50 VUs × 10 repetições
- 100 VUs × 10 repetições

**Total: 30 execuções de 30 segundos cada.**

Os resultados ficam em `scripts/results/`:

```text
django_vu10_rep1.json
django_vu10_rep2.json
...
django_vu100_rep10.json
```

### Parar tudo ao terminar

```bash
make down
```

---

## Rodando tudo de uma vez (opcional)

Se quiser rodar as 60 execuções em sequência sem intervenção manual:

```bash
make experiment
```

O comando roda `experiment-laravel` (sobe Laravel, testa, para) e depois `experiment-django` (sobe Django, testa, para).

---

## Onde Ficam os Resultados

```bash
make results
```

Lista todos os arquivos JSON gerados em `scripts/results/`.

---

## Como Ler os Resultados

Cada arquivo JSON do k6 contém as métricas brutas de cada execução.
As métricas mais relevantes para o trabalho estão no final de cada arquivo, no objeto com `type: "Point"` e `metric`:

| Métrica k6 | Variável do experimento |
| --- | --- |
| `http_req_duration` → `avg` | **Latência média (ms)** |
| `http_reqs` → `rate` | **Throughput (RPS)** |

Para extrair os valores rapidamente de um arquivo:

```bash
# Latência média (ms)
grep '"http_req_duration"' scripts/results/laravel_vu10_rep1.json \
  | grep '"avg"' | head -1

# Throughput (RPS)
grep '"http_reqs"' scripts/results/laravel_vu10_rep1.json \
  | grep '"rate"' | head -1
```

Ou veja o resumo direto no terminal ao final de cada execução k6 — o k6 imprime uma tabela com `avg`, `min`, `med`, `max`, `p(90)` e `p(95)` para latência, e `req/s` para throughput.

---

## Anotação dos Resultados

Monte uma tabela por framework com as 10 repetições de cada nível de concorrência:

| Framework | VUs | Rep | Latência média (ms) | Throughput (RPS) |
| --- | --- | --- | --- | --- |
| Laravel | 10 | 1 | — | — |
| Laravel | 10 | 2 | — | — |
| ... | ... | ... | ... | ... |
| Django | 100 | 10 | — | — |

Calcule **média** e **desvio padrão** de cada combinação para a análise comparativa.

---

## Resumo dos Comandos

| Comando | O que faz |
| --- | --- |
| `make build` | Constrói as imagens Docker |
| `make db` | Sobe Postgres e insere os dados |
| `make db-count` | Confirma quantos itens estão na tabela |
| `make up laravel` | Sobe Laravel (para Django) |
| `make up django` | Sobe Django (para Laravel) |
| `make experiment-laravel` | 30 execuções k6 contra Laravel |
| `make experiment-django` | 30 execuções k6 contra Django |
| `make experiment` | 60 execuções completas (Laravel + Django) |
| `make k6-laravel VUS=N` | Teste avulso contra Laravel |
| `make k6-django VUS=N` | Teste avulso contra Django |
| `make results` | Lista arquivos de resultado |
| `make curl-laravel` | Verifica se a API Laravel responde |
| `make curl-django` | Verifica se a API Django responde |
| `make logs-laravel` | Logs do container Laravel |
| `make logs-django` | Logs do container Django |
| `make stop` | Para os containers |
| `make down` | Para e remove os containers |
