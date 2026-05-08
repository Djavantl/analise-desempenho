#!/bin/bash
# Executa o experimento fatorial 2x3 completo:
#   Fator A: laravel | django
#   Fator B: 10 | 50 | 100 VUs
#   10 repetições cada combinação = 60 execuções no total
#
# Uso: bash scripts/run_experiment.sh
# Requisito: os containers devem estar em execução (docker compose up -d)

set -e

DURATION="30s"
REPETITIONS=10
RESULTS_DIR="$(dirname "$0")/results"

declare -A TARGETS=(
  [laravel]="http://laravel-api:8000"
  [django]="http://django-api:8000"
)

VUS_LIST=(10 50 100)

mkdir -p "$RESULTS_DIR"

TOTAL=$((${#TARGETS[@]} * ${#VUS_LIST[@]} * REPETITIONS))
CURRENT=0

echo "======================================================"
echo " Experimento: Laravel vs Django - Avaliação de Desempenho"
echo " Total de execuções: $TOTAL"
echo " Duração por execução: $DURATION"
echo "======================================================"

for framework in "${!TARGETS[@]}"; do
  target="${TARGETS[$framework]}"
  for vu in "${VUS_LIST[@]}"; do
    for rep in $(seq 1 $REPETITIONS); do
      CURRENT=$((CURRENT + 1))
      output="$RESULTS_DIR/${framework}_vu${vu}_rep${rep}.json"

      echo ""
      echo "[$CURRENT/$TOTAL] Framework: $framework | VUs: $vu | Repetição: $rep"

      docker compose run --rm k6 run \
        --env TARGET_URL="$target" \
        --env VUS="$vu" \
        --env DURATION="$DURATION" \
        --out "json=/scripts/results/${framework}_vu${vu}_rep${rep}.json" \
        /scripts/load_test.js
    done
  done
done

echo ""
echo "======================================================"
echo " Experimento concluído! Resultados em: $RESULTS_DIR"
echo "======================================================"
