import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

const latency  = new Trend('request_latency_ms', true);
const errorRate = new Rate('error_rate');
const requests  = new Counter('total_requests');

const TARGET_URL = __ENV.TARGET_URL || 'http://laravel-api:8000';
const VUS        = parseInt(__ENV.VUS || '10');
const DURATION   = __ENV.DURATION   || '30s';

export const options = {
  vus: VUS,
  duration: DURATION,
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
