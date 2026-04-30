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

## App-specific templates

Templates unique to a single app live directly in that app's `templates/` directory alongside the shared wrappers:

```
charts/app-alpha/
└── templates/
    ├── deployment.yaml   # calls library.deployment
    ├── service.yaml      # calls library.service
    ├── configmap.yaml    # app-alpha only
    └── ingress.yaml      # app-alpha only
```

Use `common` only for templates that are shared across **all** apps. If the same custom template starts appearing in multiple apps, that is the signal to promote it into `charts/common/templates/` as a new named template (e.g. `library.ingress`) and call it from each app.

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

## Multi-repo setup

This repo uses a monorepo layout where `common` is referenced locally via `file://`. If you split into separate repos — one for `common` and one per app — two things change.

**1. Publish `common` to an OCI registry**

In the `common` repo, package and push on every release:

```bash
helm package charts/common
helm push common-0.1.0.tgz oci://ghcr.io/<org>/helm-charts
```

**2. Update the dependency reference in each app's `Chart.yaml`**

```yaml
# monorepo (file reference)
dependencies:
  - name: common
    version: "0.1.0"
    repository: "file://../common"

# multi-repo (OCI registry)
dependencies:
  - name: common
    version: "0.1.0"
    repository: "oci://ghcr.io/<org>/helm-charts"
```

`helm dependency update` will then pull `common` from the registry. Everything else — lint script, pre-commit hooks, schema, env overlays — stays the same.

**Versioning**

Each app pins to a specific version of `common`. Use [Renovate](https://docs.renovatebot.com/) or Dependabot to automatically open PRs when a new version of `common` is published.

> **Tradeoff:** Multi-repo gives independent release cycles for each app and `common`, but you lose the ability to make a breaking change in `common` and update all apps atomically in a single PR.

**Pre-commit hooks in multi-repo**

Each repo owns its own `.pre-commit-config.yaml`. The responsibility splits as follows:

| Repo | What the hook validates |
|---|---|
| `common` | Library chart structure and template syntax |
| Each app repo | App values + schema + rendered output using the pinned `common` version |

The `common` repo hook lints the library chart in isolation:

```yaml
repos:
  - repo: local
    hooks:
      - id: helm-lint
        name: Helm lint (common)
        language: system
        entry: helm lint charts/common
        pass_filenames: false
        files: ^charts/common/

  - repo: https://github.com/norwoodj/helm-docs
    rev: v1.14.2
    hooks:
      - id: helm-docs
        args:
          - --chart-search-root=charts/common
```

Each app repo hook resolves the `common` dependency from the OCI registry and lints the full chart — this is where schema validation and template rendering are confirmed against the pinned version of `common`.

**Schema generation in multi-repo**

The `@schema` annotations in `values.yaml` and the generation logic stay exactly the same. The only change is that each app repo runs `helm schema` directly for its single chart instead of looping, so `scripts/helm-schema-all.sh` is not needed:

```yaml
# .pre-commit-config.yaml (per app repo)
repos:
  - repo: local
    hooks:
      - id: helm-schema
        name: Helm schema (generate values.schema.json)
        language: system
        entry: bash -c 'cd charts/app-alpha && helm schema -f values.yaml --use-helm-docs -o values.schema.json'
        pass_filenames: false
        files: ^charts/app-alpha/values\.yaml$

      - id: helm-lint
        name: Helm lint
        language: system
        entry: bash -c 'helm dependency update charts/app-alpha && helm lint charts/app-alpha --values charts/app-alpha/values.yaml'
        pass_filenames: false
        files: ^charts/app-alpha/

  - repo: https://github.com/norwoodj/helm-docs
    rev: v1.14.2
    hooks:
      - id: helm-docs
        args:
          - --chart-search-root=charts/app-alpha
          - --document-dependency-values
```

The `common` repo does not need a schema — library charts are never installed directly and their `global.*` defaults are validated by the app schemas.

What changes vs. what stays across both setups:

| | Monorepo | Per-app repo |
|---|---|---|
| `scripts/helm-schema-all.sh` | Loops over all `charts/*/` | Not needed — inline command |
| `@schema` annotations in `values.yaml` | Same | Same |
| `scripts/helm-lint-all.sh` | Loops over all `charts/*/` | Not needed — inline command |
| `helm-docs` `--chart-search-root` | `charts` | `charts/app-alpha` |

## Flux CD HelmRelease

### Monorepo

A single `GitRepository` points to this repo and is shared by all apps. Each app gets its own `HelmRelease` per environment referencing the shared source at its chart path. The `common` library is resolved by Helm directly from the Git artifact via the `file://` reference — Flux does not need to know about it.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: helmtemplates
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/<org>/helmtemplates.git
  ref:
    branch: main
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-alpha
  namespace: staging
spec:
  interval: 10m
  chart:
    spec:
      chart: ./charts/app-alpha
      sourceRef:
        kind: GitRepository
        name: helmtemplates        # shared by all apps
        namespace: flux-system
      valuesFiles:
        - charts/app-alpha/values.yaml
        - charts/app-alpha/values-staging.yaml
  install:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
  upgrade:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-beta
  namespace: staging
spec:
  interval: 10m
  chart:
    spec:
      chart: ./charts/app-beta
      sourceRef:
        kind: GitRepository
        name: helmtemplates        # shared by all apps
        namespace: flux-system
      valuesFiles:
        - charts/app-beta/values.yaml
        - charts/app-beta/values-staging.yaml
  install:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
  upgrade:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
```

The same pattern repeats per environment — only the namespace and last `valuesFiles` entry change:

| Environment | Namespace | Last `valuesFiles` entry |
|---|---|---|
| dev | `dev` | `charts/app-*/values-dev.yaml` |
| staging | `staging` | `charts/app-*/values-staging.yaml` |
| prod | `prod` | `charts/app-*/values-prod.yaml` |

### Multi-repo

In a multi-repo setup, each app repo contains its own Flux manifests. You need one `GitRepository` per app and one `HelmRelease` per environment, using `chart.spec.valuesFiles` to layer the environment overlay directly from the Git source — no ConfigMaps needed.

**`GitRepository`** (one per app, in `flux-system`):

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: app-alpha
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/<org>/app-alpha.git
  ref:
    branch: main
```

**`HelmRelease`** (one per environment, in the target namespace):

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-alpha
  namespace: staging
spec:
  interval: 10m
  chart:
    spec:
      chart: ./charts/app-alpha
      sourceRef:
        kind: GitRepository
        name: app-alpha
        namespace: flux-system
      valuesFiles:
        - charts/app-alpha/values.yaml
        - charts/app-alpha/values-staging.yaml
  install:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
  upgrade:
    strategy:
      name: RetryOnFailure
      retryInterval: 5m
```

The same pattern repeats per environment — only the namespace and last `valuesFiles` entry change:

| Environment | Namespace | Last `valuesFiles` entry |
|---|---|---|
| dev | `dev` | `charts/app-alpha/values-dev.yaml` |
| staging | `staging` | `charts/app-alpha/values-staging.yaml` |
| prod | `prod` | `charts/app-alpha/values-prod.yaml` |

`app-beta` follows the exact same shape with its own `GitRepository` and chart path. The `common` library dependency is resolved by Helm at render time from the OCI registry — Flux does not need to know about it.

**Monorepo vs. multi-repo comparison:**

| | Monorepo | Multi-repo |
|---|---|---|
| `GitRepository` | One, shared by all apps | One per app |
| `common` resolved by | Helm via `file://` from the Git artifact | Helm via OCI registry |
| A change to `common` | All apps reconcile on next poll | Only apps that bump the pinned version |

## Values reference

See each chart's auto-generated `README.md` for its full values reference:

- [charts/common/README.md](charts/common/README.md)
- [charts/app-alpha/README.md](charts/app-alpha/README.md)
- [charts/app-beta/README.md](charts/app-beta/README.md)
