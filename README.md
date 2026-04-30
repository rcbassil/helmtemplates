# helmtemplates

A Helm chart repository for deploying applications to Kubernetes, with schema validation, environment overlays, and auto-generated documentation.

## Requirements

- [Helm](https://helm.sh/docs/intro/install/) v3+
- [pre-commit](https://pre-commit.com/#install)

## Repository structure

```
helmtemplates/
├── mychart/                  # Helm chart
│   ├── Chart.yaml            # Chart metadata
│   ├── values.yaml           # Default values
│   ├── values-dev.yaml       # Dev environment overrides
│   ├── values-staging.yaml   # Staging environment overrides
│   ├── values-prod.yaml      # Production environment overrides
│   ├── values.schema.json    # JSON Schema for values validation
│   ├── templates/            # Kubernetes manifest templates
│   ├── charts/               # Chart dependencies (populated by helm dep update)
│   └── README.md             # Auto-generated values reference (helm-docs)
└── .pre-commit-config.yaml   # Pre-commit hooks
```

## Usage

Install with default values:

```bash
helm install myapp mychart
```

Install with an environment overlay:

```bash
helm install myapp mychart -f mychart/values.yaml -f mychart/values-staging.yaml
```

Upgrade an existing release:

```bash
helm upgrade myapp mychart -f mychart/values.yaml -f mychart/values-prod.yaml
```

Dry-run to preview rendered manifests:

```bash
helm template myapp mychart -f mychart/values.yaml -f mychart/values-dev.yaml
```

## Development

Install pre-commit hooks after cloning:

```bash
pre-commit install
```

The following hooks run on every commit:

| Hook | What it checks |
|---|---|
| `helm-lint` | Renders all templates against `values.yaml` and validates against `values.schema.json` |
| `helm-docs` | Regenerates `mychart/README.md` from `values.yaml` comments |

Run hooks manually at any time:

```bash
pre-commit run --all-files
```

## Values reference

See [mychart/README.md](mychart/README.md) for the full auto-generated values reference.
