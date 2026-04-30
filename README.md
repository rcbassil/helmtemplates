# helmtemplates

A Helm chart monorepo with a shared library chart and per-app charts, environment overlays, schema validation, and auto-generated documentation.

## Requirements

- [Helm](https://helm.sh/docs/intro/install/) v3+
- [pre-commit](https://pre-commit.com/#install)

## Repository structure

```
helmtemplates/
├── charts/
│   ├── common/                 # Shared library chart (type: library)
│   │   ├── Chart.yaml
│   │   ├── values.yaml         # Global defaults (securityContext, etc.)
│   │   └── templates/
│   │       ├── _helpers.tpl    # fullname, labels, selectorLabels
│   │       ├── _deployment.tpl # library.deployment named template
│   │       └── _service.tpl    # library.service named template
│   │
│   ├── app-alpha/              # Application chart
│   │   ├── Chart.yaml          # Depends on common
│   │   ├── values.yaml
│   │   ├── values.schema.json  # JSON Schema — validates values at install/upgrade
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   └── values-prod.yaml
│   │
│   └── app-beta/               # Application chart
│       ├── Chart.yaml          # Depends on common
│       ├── values.yaml
│       ├── values.schema.json
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       └── values-prod.yaml
│
├── scripts/
│   └── helm-lint-all.sh        # Resolves deps and lints all charts in charts/
└── .pre-commit-config.yaml
```

## Usage

Install with default values:

```bash
helm install app-alpha charts/app-alpha
```

Install with an environment overlay:

```bash
helm install app-alpha charts/app-alpha \
  -f charts/app-alpha/values.yaml \
  -f charts/app-alpha/values-staging.yaml
```

Upgrade an existing release:

```bash
helm upgrade app-alpha charts/app-alpha \
  -f charts/app-alpha/values.yaml \
  -f charts/app-alpha/values-prod.yaml
```

Dry-run to preview rendered manifests:

```bash
helm template app-alpha charts/app-alpha \
  -f charts/app-alpha/values.yaml \
  -f charts/app-alpha/values-dev.yaml
```

## Schema validation

Each app chart ships a `values.schema.json` that is enforced automatically by Helm on every `install`, `upgrade`, and `lint`. It catches:

- Missing required fields (`replicaCount`, `image.repository`, `service.type`, `service.port`)
- Invalid `image.pullPolicy` — must be `Always`, `IfNotPresent`, or `Never`
- Invalid `service.type` — must be `ClusterIP`, `NodePort`, `LoadBalancer`, or `ExternalName`
- Out-of-range `service.port` (1–65535) and CPU utilization percentages (1–100)
- Unknown top-level keys (`additionalProperties: false`)

> **Note:** `common` must be listed as an allowed property in each app schema because Helm injects the subchart name as a top-level values key. Add the same entry whenever a new subchart dependency is declared.

## Adding a new app chart

1. Create `charts/my-app/` with a `Chart.yaml` that declares `common` as a dependency:

```yaml
dependencies:
  - name: common
    version: "0.1.0"
    repository: "file://../common"
```

2. Pull the dependency:

```bash
helm dependency update charts/my-app
```

3. Add thin template wrappers in `charts/my-app/templates/`:

```yaml
# deployment.yaml
{{- include "library.deployment" . }}

# service.yaml
{{- include "library.service" . }}
```

4. Add a `values.schema.json` alongside `values.yaml`, including `"common"` as an allowed property.

## Development

Install pre-commit hooks after cloning:

```bash
pre-commit install
```

The following hooks run on every commit:

| Hook | What it checks |
|---|---|
| `helm-lint` | Resolves dependencies and lints all charts in `charts/`, including schema validation |
| `helm-docs` | Regenerates each chart's `README.md` from `values.yaml` comments |

Run hooks manually at any time:

```bash
pre-commit run --all-files
```

## Values reference

See each chart's auto-generated `README.md` for its full values reference:

- [charts/common/README.md](charts/common/README.md)
- [charts/app-alpha/README.md](charts/app-alpha/README.md)
- [charts/app-beta/README.md](charts/app-beta/README.md)
