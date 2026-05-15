import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

const latency   = new Trend('request_latency_ms', true);
const errorRate = new Rate('error_rate');
const requests  = new Counter('total_requests');

const TARGET_URL  = __ENV.TARGET_URL  || 'http://laravel-api:8000';
const VUS         = parseInt(__ENV.VUS || '10');
const WARMUP_DURATION = __ENV.WARMUP_DURATION || '15s'; // descartado da análise
const MEASURE_DURATION = __ENV.MEASURE_DURATION || '30s'; // janela real de medição

// Fases: ramp-up → estado estável (medição) → ramp-down
// O k6 coleta métricas em todas as fases, mas o que importa
// para a análise é o trecho de estado estável (plateau).
export const options = {
  stages: [
    { duration: WARMUP_DURATION, target: VUS }, // aquecimento: sobe gradualmente
    { duration: MEASURE_DURATION, target: VUS }, // medição: carga constante
    { duration: '5s',            target: 0   }, // ramp-down
  ],
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
