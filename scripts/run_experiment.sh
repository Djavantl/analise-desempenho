#!/bin/bash
# Executa o experimento fatorial 2x3 completo:
#   Fator A: laravel | django
#   Fator B: 10 | 50 | 100 VUs
#   10 repetições cada combinação = 60 execuções no total
#
# Uso: bash scripts/run_experiment.sh
# Requisito: os containers devem estar em execução (docker compose up -d)

set -e

WARMUP_DURATION="${WARMUP_DURATION:-15s}"
MEASURE_DURATION="${MEASURE_DURATION:-30s}"
REPETITIONS=10
RESULTS_DIR="$(dirname "$0")/results"

declare -A SERVICES=(
  [laravel]="laravel-api"
  [django]="django-api"
)

declare -A PUBLIC_URLS=(
  [laravel]="http://localhost:8001"
  [django]="http://localhost:8002"
)

VUS_LIST=(10 50 100)

mkdir -p "$RESULTS_DIR"

TOTAL=$((${#SERVICES[@]} * ${#VUS_LIST[@]} * REPETITIONS))
CURRENT=0

echo "======================================================"
echo " Experimento: Laravel vs Django - Avaliação de Desempenho"
echo " Total de execuções: $TOTAL"
echo " Aquecimento por execução: $WARMUP_DURATION"
echo " Medição por execução: $MEASURE_DURATION"
echo "======================================================"

for framework in "${!SERVICES[@]}"; do
  service="${SERVICES[$framework]}"
  public_url="${PUBLIC_URLS[$framework]}"
  for vu in "${VUS_LIST[@]}"; do
    for rep in $(seq 1 $REPETITIONS); do
      CURRENT=$((CURRENT + 1))
      output="$RESULTS_DIR/${framework}_vu${vu}_rep${rep}.json"

      echo ""
      echo "[$CURRENT/$TOTAL] Framework: $framework | VUs: $vu | Repetição: $rep"

      "$(dirname "$0")/run_k6_service.sh" "$service" "$public_url" \
        --env VUS="$vu" \
        --env WARMUP_DURATION="$WARMUP_DURATION" \
        --env MEASURE_DURATION="$MEASURE_DURATION" \
        --out "json=/scripts/results/${framework}_vu${vu}_rep${rep}.json" \
        /scripts/load_test.js
    done
  done
done

echo ""
echo "======================================================"
echo " Experimento concluído! Resultados em: $RESULTS_DIR"
echo "======================================================"
