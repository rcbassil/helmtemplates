#!/usr/bin/env bash
set -euo pipefail

for chart_dir in charts/*/; do
  [[ -f "${chart_dir}Chart.yaml" ]] || continue
  chart_name=$(basename "$chart_dir")

  echo "==> Updating dependencies for ${chart_name}..."
  helm dependency update "$chart_dir" --skip-refresh 2>/dev/null \
    || helm dependency update "$chart_dir"

  echo "==> Linting ${chart_name}..."
  helm lint "$chart_dir" --values "${chart_dir}values.yaml"
done
