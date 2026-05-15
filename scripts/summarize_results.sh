#!/bin/sh
set -eu

RESULTS_DIR="${RESULTS_DIR:-scripts/results}"
OUTPUT_FILE="$RESULTS_DIR/summary.csv"

mkdir -p "$RESULTS_DIR"

{
  echo "tecnologia,concorrencia_vus,repeticoes,latencia_media_ms_media,latencia_media_ms_desvio_padrao,throughput_req_s_media,throughput_req_s_desvio_padrao,taxa_erro_percentual_media"
  find "$RESULTS_DIR" -maxdepth 1 -type f -name '*.json' -print \
    | xargs -r jq -r '
      select(has("tecnologia") and has("concorrencia_vus")) |
      [
        .tecnologia,
        .concorrencia_vus,
        .latencia_media_ms,
        .throughput_requisicoes_por_segundo,
        .taxa_erro_percentual
      ] | @tsv
    ' \
    | sort -k1,1 -k2,2n \
    | awk '
      function flush() {
        if (n == 0) return

        lat_mean = lat_sum / n
        thr_mean = thr_sum / n
        err_mean = err_sum / n

        lat_std = n > 1 ? sqrt((lat_sq - (lat_sum * lat_sum / n)) / (n - 1)) : 0
        thr_std = n > 1 ? sqrt((thr_sq - (thr_sum * thr_sum / n)) / (n - 1)) : 0

        printf "%s,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f\n", tech, vus, n, lat_mean, lat_std, thr_mean, thr_std, err_mean
      }

      BEGIN { FS = "\t" }
      {
        key = $1 SUBSEP $2
        if (n > 0 && key != current_key) {
          flush()
          n = lat_sum = lat_sq = thr_sum = thr_sq = err_sum = 0
        }

        current_key = key
        tech = $1
        vus = $2
        lat = $3
        thr = $4
        err = $5

        n++
        lat_sum += lat
        lat_sq += lat * lat
        thr_sum += thr
        thr_sq += thr * thr
        err_sum += err
      }
      END { flush() }
    '
} > "$OUTPUT_FILE"

cat "$OUTPUT_FILE"
