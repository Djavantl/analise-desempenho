# Documentação do k6 no Projeto

Este documento explica como o k6 foi configurado neste projeto, como ele executa os testes e como os arquivos JSON resumidos são gerados.

## Papel do k6

O k6 é a ferramenta responsável por gerar carga HTTP contra as APIs Laravel e Django.

No experimento, ele simula usuários virtuais simultâneos, chamados de **VUs**. Cada VU executa repetidamente o mesmo fluxo:

```text
GET /api/items
verifica se o status é 200
registra latência, erro e quantidade de requisições
repete até acabar a duração do teste
```

O número de VUs representa o nível de concorrência do experimento:

```text
10 VUs
50 VUs
100 VUs
```

## Arquivo Principal

O script do k6 fica em:

```text
scripts/load_test.js
```

Ele é usado tanto para Laravel quanto para Django. A API alvo é definida por variável de ambiente.

## Configuração do Teste

No `load_test.js`, as principais variáveis são:

```js
const TARGET_URL = __ENV.TARGET_URL || 'http://laravel-api:8000';
const VUS = parseInt(__ENV.VUS || '10');
const MEASURE_DURATION = __ENV.MEASURE_DURATION || '30s';
const FRAMEWORK = __ENV.FRAMEWORK || 'unknown';
const REPETITION = parseInt(__ENV.REPETITION || '0');
const SUMMARY_FILE = __ENV.SUMMARY_FILE || '';
```

Significado:

| Variável | Função |
| --- | --- |
| `TARGET_URL` | URL interna da API testada |
| `VUS` | Quantidade de usuários virtuais simultâneos |
| `MEASURE_DURATION` | Duração da execução |
| `FRAMEWORK` | Tecnologia testada: `laravel` ou `django` |
| `REPETITION` | Número da repetição |
| `SUMMARY_FILE` | Caminho onde será salvo o JSON-resumo |

O teste usa VUs constantes:

```js
export const options = {
  vus: VUS,
  duration: MEASURE_DURATION,
  thresholds: {
    error_rate: ['rate<0.05'],
  },
};
```

Isso significa que o k6 mantém, por exemplo, 10 VUs ativos durante 30 segundos. Cada VU faz o máximo de requisições que conseguir nesse período.

## Endpoint Testado

O endpoint é fixo:

```js
http.get(`${TARGET_URL}/api/items`);
```

Portanto, para Laravel e Django, a requisição final é equivalente a:

```http
GET /api/items
```

## Métricas Coletadas

O script cria três métricas customizadas:

```js
const latency = new Trend('request_latency_ms', true);
const errorRate = new Rate('error_rate');
const requests = new Counter('total_requests');
```

Elas representam:

| Métrica | Tipo k6 | Uso no experimento |
| --- | --- | --- |
| `request_latency_ms` | `Trend` | Latência média em milissegundos |
| `error_rate` | `Rate` | Percentual de respostas que não passaram no check |
| `total_requests` | `Counter` | Total de requisições feitas |

Também existe o check:

```js
const ok = check(res, {
  'status 200': (r) => r.status === 200,
});
```

Esse check garante que a resposta da API foi HTTP 200.

## Threshold de Erro

O teste define:

```js
thresholds: {
  error_rate: ['rate<0.05'],
}
```

Isso significa que a taxa de erro deve ser menor que 5%.

Se a taxa de erro for maior ou igual a 5%, o k6 marca a execução como falha. Isso ajuda a identificar cenários inválidos para comparação, por exemplo quando a API retorna 500.

## Por Que o JSON Foi Simplificado

Por padrão, o k6 pode gerar um JSON muito grande com uma linha para cada ponto de métrica. Esse formato é útil para análise detalhada, mas fica pesado e desnecessário para este trabalho.

Como o experimento precisa apenas de:

- latência média
- throughput
- taxa de erro
- identificação do cenário

foi implementada a função `handleSummary`.

## Como o JSON-Resumo é Gerado

Ao final de cada execução, o k6 chama automaticamente:

```js
export function handleSummary(data) {
  ...
}
```

O objeto `data` contém todas as métricas consolidadas da execução. A função extrai apenas os campos necessários:

```js
const totalRequests = metricValue(data, 'total_requests', 'count');
const throughput = metricValue(data, 'total_requests', 'rate');
const latencyAvg = metricValue(data, 'request_latency_ms', 'avg');
const errorRatePercent = metricValue(data, 'error_rate', 'rate') * 100;
const checksPassed = metricValue(data, 'checks', 'passes');
const checksFailed = metricValue(data, 'checks', 'fails');
```

Depois monta um JSON simples:

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

Esse arquivo é salvo quando `SUMMARY_FILE` é informado:

```js
if (SUMMARY_FILE) {
  output[SUMMARY_FILE] = `${JSON.stringify(summary, null, 2)}\n`;
}
```

## Como o k6 é Chamado

O k6 roda dentro de um container definido no `docker-compose.yml`:

```yaml
k6:
  image: grafana/k6:latest
  profiles:
    - tools
  user: root
  volumes:
    - ./scripts:/scripts
  networks:
    - perf-network
  entrypoint: ["k6"]
```

O volume:

```yaml
- ./scripts:/scripts
```

permite que o container do k6 leia `load_test.js` e grave os resultados em `scripts/results/`.

## Por Que Existe `run_k6_service.sh`

O script:

```text
scripts/run_k6_service.sh
```

faz três coisas antes de chamar o k6:

1. Espera a API responder em `localhost`
2. Descobre o IP atual do container da API
3. Executa o k6 apontando para esse IP

Isso evita problemas de DNS interno do Docker após restart dos containers.

Exemplo de uso interno:

```bash
./scripts/run_k6_service.sh django-api http://localhost:8002 \
  --env FRAMEWORK=django \
  --env REPETITION=1 \
  --env VUS=10 \
  --env MEASURE_DURATION=30s \
  --env SUMMARY_FILE=/scripts/results/django_vu10_rep1.json \
  /scripts/load_test.js
```

O helper transforma isso em uma execução k6 equivalente a:

```bash
docker compose run --rm k6 run \
  --env TARGET_URL=http://IP_DO_CONTAINER:8000 \
  --env FRAMEWORK=django \
  --env REPETITION=1 \
  --env VUS=10 \
  --env MEASURE_DURATION=30s \
  --env SUMMARY_FILE=/scripts/results/django_vu10_rep1.json \
  /scripts/load_test.js
```

## Comandos do Makefile

O `Makefile` é a interface principal para o k6.

Teste avulso sem salvar JSON:

```bash
make k6-laravel VUS=10 MEASURE_DURATION=30s
make k6-django VUS=10 MEASURE_DURATION=30s
```

Benchmark avulso salvando JSON-resumo:

```bash
make bench-laravel VUS=10 DURATION=30s
make bench-django VUS=10 DURATION=30s
```

Experimento completo:

```bash
make experiment
```

Experimentos separados:

```bash
make experiment-laravel
make experiment-django
```

## Arquivos Gerados

Durante o experimento, os arquivos ficam em:

```text
scripts/results/
```

Exemplos:

```text
laravel_vu10_rep1.json
laravel_vu10_rep2.json
laravel_vu50_rep1.json
django_vu10_rep1.json
django_vu100_rep10.json
```

Cada arquivo representa uma execução independente.

## Geração da Tabela Consolidada

Depois de gerar os JSONs, o comando:

```bash
make summary
```

executa:

```text
scripts/summarize_results.sh
```

Esse script lê todos os JSONs resumidos e gera:

```text
scripts/results/summary.csv
```

O CSV contém:

```csv
tecnologia,concorrencia_vus,repeticoes,latencia_media_ms_media,latencia_media_ms_desvio_padrao,throughput_req_s_media,throughput_req_s_desvio_padrao,taxa_erro_percentual_media
```

Esse arquivo é o mais adequado para montar as tabelas do relatório.

## Interpretação do Throughput

O k6 está configurado com VUs constantes. Isso significa que ele não força uma taxa fixa de requisições por segundo.

Em vez disso, ele mantém N usuários virtuais ativos. Cada usuário faz uma requisição, espera a resposta e imediatamente inicia a próxima.

Por isso, uma API mais rápida consegue produzir mais requisições dentro dos mesmos 30 segundos.

Exemplo:

```text
Laravel com 10 VUs: 1000 requisições em 30s
Django com 10 VUs: 3700 requisições em 30s
```

Isso ocorre porque o Django respondeu mais rápido, permitindo mais ciclos no mesmo tempo.
