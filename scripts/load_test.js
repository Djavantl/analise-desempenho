import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

const latency   = new Trend('request_latency_ms', true);
const errorRate = new Rate('error_rate');
const requests  = new Counter('total_requests');

const TARGET_URL  = __ENV.TARGET_URL  || 'http://laravel-api:8000';
const VUS         = parseInt(__ENV.VUS || '10');
const MEASURE_DURATION = __ENV.MEASURE_DURATION || '30s';
const FRAMEWORK = __ENV.FRAMEWORK || 'unknown';
const REPETITION = parseInt(__ENV.REPETITION || '0');
const SUMMARY_FILE = __ENV.SUMMARY_FILE || '';

export const options = {
  vus: VUS,
  duration: MEASURE_DURATION,
  thresholds: {
    error_rate: ['rate<0.05'],
  },
};

export default function () {
  const res = http.get(`${TARGET_URL}/api/items`);

  const ok = check(res, {
    'status 200': (r) => r.status === 200,
  });

  latency.add(res.timings.duration);
  errorRate.add(!ok);
  requests.add(1);
}

function metricValue(data, metric, value, fallback = 0) {
  return data.metrics[metric]?.values?.[value] ?? fallback;
}

function round(value, digits = 2) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

export function handleSummary(data) {
  const totalRequests = metricValue(data, 'total_requests', 'count');
  const throughput = metricValue(data, 'total_requests', 'rate');
  const latencyAvg = metricValue(data, 'request_latency_ms', 'avg');
  const errorRatePercent = metricValue(data, 'error_rate', 'rate') * 100;
  const checksPassed = metricValue(data, 'checks', 'passes');
  const checksFailed = metricValue(data, 'checks', 'fails');

  const summary = {
    tecnologia: FRAMEWORK,
    concorrencia_vus: VUS,
    repeticao: REPETITION,
    endpoint: '/api/items',
    duracao: MEASURE_DURATION,
    total_requisicoes: totalRequests,
    throughput_requisicoes_por_segundo: round(throughput, 2),
    latencia_media_ms: round(latencyAvg, 2),
    taxa_erro_percentual: round(errorRatePercent, 2),
    checks_status_200_sucesso: checksPassed,
    checks_status_200_falha: checksFailed,
  };

  const text = [
    '',
    'Resumo do experimento',
    `Tecnologia: ${summary.tecnologia}`,
    `Concorrencia (VUs): ${summary.concorrencia_vus}`,
    `Repeticao: ${summary.repeticao}`,
    `Total de requisicoes: ${summary.total_requisicoes}`,
    `Throughput: ${summary.throughput_requisicoes_por_segundo} req/s`,
    `Latencia media: ${summary.latencia_media_ms} ms`,
    `Taxa de erro: ${summary.taxa_erro_percentual}%`,
    '',
  ].join('\n');

  const output = { stdout: text };
  if (SUMMARY_FILE) {
    output[SUMMARY_FILE] = `${JSON.stringify(summary, null, 2)}\n`;
  }

  return output;
}
