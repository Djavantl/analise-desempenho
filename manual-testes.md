# Manual de Execução dos Testes

Este projeto executa um experimento comparativo de desempenho entre duas APIs REST equivalentes: uma em Laravel e outra em Django. As duas aplicações consultam a mesma tabela `items` no PostgreSQL e expõem o mesmo endpoint:

```http
GET /api/items
```

## Desenho do Experimento

O experimento segue um planejamento fatorial **2 x 3**:

| Fator | Níveis |
| --- | --- |
| Tecnologia | Laravel, Django |
| Concorrência | 10, 50 e 100 VUs simultâneos |

Configuração:

- **Repetições por combinação:** 10
- **Total:** 2 tecnologias x 3 níveis x 10 repetições = 60 execuções
- **Duração padrão por execução:** 30 segundos
- **Ferramenta de carga:** k6
- **Variáveis de resposta:** latência média (ms) e throughput (requisições por segundo)
- **Controle de recursos:** cada API roda isolada com limite de 1 vCPU e 512 MB de RAM

Cada tecnologia é testada isoladamente. Quando Laravel está em teste, Django fica parado; quando Django está em teste, Laravel fica parado.

## Pré-Requisitos

- Docker
- Docker Compose
- `make`
- Portas livres no host:
  - Laravel: `localhost:8001`
  - Django: `localhost:8002`

## Preparação Inicial

Construir as imagens:

```bash
make build
```

Subir banco e seed:

```bash
make db
```

Verificar quantidade de itens:

```bash
make db-count
```

Resultado esperado: a tabela `items` deve estar populada. Esse banco será usado tanto pelo Laravel quanto pelo Django.

## Fluxo Recomendado de Execução

O fluxo recomendado é executar uma tecnologia por vez, sempre com o banco junto. Primeiro roda Laravel, depois para e remove os containers, e em seguida roda Django.

### 1. Rodar Laravel com o banco

Subir Laravel com o banco:

```bash
make up laravel
```

Esse comando sobe:

- PostgreSQL
- Seed do banco
- API Laravel

Ele também para o Django, caso esteja em execução.

Verificar se o Laravel responde:

```bash
make curl-laravel
```

Executar o experimento do Laravel:

```bash
make experiment-laravel
```

Esse comando executa:

- 10 VUs, 10 repetições
- 50 VUs, 10 repetições
- 100 VUs, 10 repetições

Total: **30 execuções Laravel**.

Os arquivos gerados seguem este padrão:

```text
scripts/results/laravel_vu10_rep1.json
scripts/results/laravel_vu50_rep1.json
scripts/results/laravel_vu100_rep1.json
...
```

Ao terminar o Laravel, pare os containers:

```bash
make stop
```

Depois remova os containers e a rede do projeto:

```bash
make down
```

Observação: `make down` remove os containers, mas não remove o volume do banco. Para apagar também os dados do banco, use `make reset-db`.

### 2. Rodar Django com o banco

Subir Django com o banco:

```bash
make up django
```

Esse comando sobe:

- PostgreSQL
- Seed do banco
- API Django

Ele também para o Laravel, caso esteja em execução.

Verificar se o Django responde:

```bash
make curl-django
```

Executar o experimento do Django:

```bash
make experiment-django
```

Esse comando executa:

- 10 VUs, 10 repetições
- 50 VUs, 10 repetições
- 100 VUs, 10 repetições

Total: **30 execuções Django**.

Os arquivos gerados seguem este padrão:

```text
scripts/results/django_vu10_rep1.json
scripts/results/django_vu50_rep1.json
scripts/results/django_vu100_rep1.json
...
```

Ao terminar o Django, pare e remova os containers:

```bash
make stop
make down
```

### 3. Alternativa: rodar tudo em sequência

Se quiser rodar Laravel e Django em sequência automaticamente:

```bash
make experiment
```

Esse comando executa `experiment-laravel` e depois `experiment-django`.

Para o roteiro do trabalho, porém, o fluxo separado é mais fácil de acompanhar e conferir.

## Formato dos Resultados

Cada arquivo `.json` é um resumo simples de uma execução. Exemplo:

```json
{
  "tecnologia": "django",
  "concorrencia_vus": 10,
  "repeticao": 1,
  "endpoint": "/api/items",
  "duracao": "30s",
  "total_requisicoes": 3719,
  "throughput_requisicoes_por_segundo": 123.97,
  "latencia_media_ms": 80.09,
  "taxa_erro_percentual": 0,
  "checks_status_200_sucesso": 3719,
  "checks_status_200_falha": 0
}
```

Campos usados na análise:

| Campo | Significado |
| --- | --- |
| `tecnologia` | Framework testado |
| `concorrencia_vus` | Nível de concorrência |
| `repeticao` | Número da repetição |
| `latencia_media_ms` | Latência média em milissegundos |
| `throughput_requisicoes_por_segundo` | Requisições por segundo |
| `taxa_erro_percentual` | Percentual de falhas |

## Gerar Tabela Final

Após rodar os experimentos, gere a tabela consolidada:

```bash
make summary
```

O comando cria:

```text
scripts/results/summary.csv
```

Esse CSV contém médias e desvios padrão por cenário:

```csv
tecnologia,concorrencia_vus,repeticoes,latencia_media_ms_media,latencia_media_ms_desvio_padrao,throughput_req_s_media,throughput_req_s_desvio_padrao,taxa_erro_percentual_media
```

Essa é a tabela mais adequada para levar para a análise estatística e para o relatório.

## Limpar Resultados

Antes de uma nova rodada completa, é recomendado limpar os resultados antigos. Depois execute novamente o fluxo separado Laravel -> parada -> Django:

```bash
make clean-results

make up laravel
make curl-laravel
make experiment-laravel
make stop
make down

make up django
make curl-django
make experiment-django
make stop
make down

make summary
```

## Testes Avulsos

Executar um teste rápido no Laravel:

```bash
make k6-laravel VUS=10 MEASURE_DURATION=30s
```

Executar um teste rápido no Django:

```bash
make k6-django VUS=10 MEASURE_DURATION=30s
```

Executar benchmark salvando JSON-resumo:

```bash
make bench-laravel VUS=10 DURATION=30s
make bench-django VUS=10 DURATION=30s
```

## Observação Sobre Versões

O ambiente atual usa:

- Laravel em imagem `php:8.4-fpm-alpine`
- Django em imagem `python:3.12-slim`
- PostgreSQL 15
- k6 via imagem `grafana/k6:latest`

Caso o relatório mencione PHP 8.2, ajuste o texto do relatório ou altere a imagem Docker com cuidado. O projeto atual está configurado para PHP 8.4.
