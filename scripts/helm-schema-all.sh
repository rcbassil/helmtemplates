#!/usr/bin/env bash
set -euo pipefail

for chart_dir in charts/*/; do
  [[ -f "${chart_dir}Chart.yaml" ]] || continue

  chart_type=$(grep "^type:" "${chart_dir}Chart.yaml" | awk '{print $2}')
  [[ "$chart_type" == "library" ]] && continue

  chart_name=$(basename "$chart_dir")
  echo "==> Generating schema for ${chart_name}..."

  (cd "$chart_dir" && helm schema \
    -f values.yaml \
    --use-helm-docs \
    -o values.schema.json)
done
