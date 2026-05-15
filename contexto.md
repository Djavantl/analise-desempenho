# Avaliação de Desempenho: Laravel vs Django

Este repositório implementa um experimento acadêmico para comparar o desempenho de duas APIs REST equivalentes em ambiente conteinerizado.

## Objetivo

Comparar Laravel e Django em uma operação de leitura de dados via API REST, medindo:

- **Latência média**, em milissegundos
- **Throughput**, em requisições por segundo

As duas APIs consultam a mesma tabela `items` no PostgreSQL e retornam a lista de itens em JSON pelo endpoint:

```http
GET /api/items
```

## Tecnologias

| Camada | Tecnologia |
| --- | --- |
| API Laravel | PHP 8.4 + Laravel + Nginx + PHP-FPM |
| API Django | Python 3.12 + Django + Gunicorn |
| Banco de dados | PostgreSQL 15 |
| Geração de carga | k6 |
| Orquestração | Docker Compose |

## Planejamento Experimental

O experimento segue um planejamento fatorial **2 x 3**:

| Fator | Níveis |
| --- | --- |
| Tecnologia | Laravel, Django |
| Concorrência | 10, 50 e 100 VUs simultâneos |

Cada combinação é executada **10 vezes**, totalizando:

```text
2 tecnologias x 3 níveis de concorrência x 10 repetições = 60 execuções
```

Cada execução dura, por padrão, **30 segundos**.

## Controle de Isonomia

No `docker-compose.yml`, os containers das APIs possuem os mesmos limites:

- **CPU:** 1 vCPU
- **Memória:** 512 MB

Além disso:

- Laravel e Django usam a mesma tabela `items`
- O banco PostgreSQL é compartilhado
- O endpoint testado é o mesmo
- Apenas uma API fica ativa durante o teste da outra
- O k6 executa o mesmo script para as duas tecnologias

## Estrutura Atual do Projeto

```text
analise_desempenho/
├── docker-compose.yml
├── Makefile
├── manual-testes.md
├── doc-k6.md
├── db/
│   ├── init.sql
│   └── seed.sql
├── laravel-app/
│   ├── Dockerfile
│   ├── app/
│   │   ├── Http/Controllers/ItemController.php
│   │   └── Models/Item.php
│   ├── config/
│   ├── database/
│   ├── docker/
│   │   ├── entrypoint.sh
│   │   ├── nginx.conf
│   │   └── supervisord.conf
│   ├── public/
│   └── routes/api.php
├── django-app/
│   ├── Dockerfile
│   ├── api/
│   │   ├── models.py
│   │   ├── urls.py
│   │   └── views.py
│   ├── config/
│   ├── docker/entrypoint.sh
│   ├── manage.py
│   └── requirements.txt
└── scripts/
    ├── load_test.js
    ├── run_k6_service.sh
    ├── run_experiment.sh
    ├── summarize_results.sh
    └── results/
```

## Funcionamento das APIs

### Laravel

Fluxo:

```text
Requisição HTTP
→ Nginx
→ PHP-FPM
→ Laravel Router
→ ItemController@index
→ Eloquent
→ PostgreSQL
```

Rota:

```php
Route::get('/items', [ItemController::class, 'index']);
```

Controller:

```php
return response()->json(Item::all());
```

### Django

Fluxo:

```text
Requisição HTTP
→ Gunicorn
→ Django URL Router
→ item_list
→ Django ORM
→ PostgreSQL
```

Rotas:

```python
path('items', views.item_list)
path('items/', views.item_list)
```

A rota sem barra existe para manter o endpoint idêntico ao Laravel e evitar redirect durante o teste.

## Scripts de Experimento

| Arquivo | Função |
| --- | --- |
| `scripts/load_test.js` | Script principal do k6 |
| `scripts/run_k6_service.sh` | Espera a API ficar pronta, descobre o IP do container e executa k6 |
| `scripts/run_experiment.sh` | Alternativa em shell para rodar o experimento completo |
| `scripts/summarize_results.sh` | Gera CSV com médias e desvios padrão |
| `Makefile` | Interface principal para rodar tudo |

## Resultados

Cada execução gera um JSON-resumo em `scripts/results/`.

Exemplo:

```json
{
  "tecnologia": "laravel",
  "concorrencia_vus": 10,
  "repeticao": 1,
  "endpoint": "/api/items",
  "duracao": "30s",
  "total_requisicoes": 1014,
  "throughput_requisicoes_por_segundo": 33.8,
  "latencia_media_ms": 294.9,
  "taxa_erro_percentual": 0,
  "checks_status_200_sucesso": 1014,
  "checks_status_200_falha": 0
}
```

Após todas as execuções:

```bash
make summary
```

gera:

```text
scripts/results/summary.csv
```

com médias e desvios padrão por tecnologia e nível de concorrência.
