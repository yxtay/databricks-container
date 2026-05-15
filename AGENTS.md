# AI Agent Instructions

Refer to [README.md](README.md) for project overview and usage.

## Project Overview

Minimal container images for Databricks Container Service.
Single multi-stage Dockerfile, parameterized per runtime version via `compose.yaml`.
No application code — infrastructure/packaging project only.

## Key Files

- `Dockerfile` — multi-stage build (base → build → runtime)
- `compose.yaml` — build matrix with per-version args
  (runtime, JDK, PySpark, Python, UV_EXCLUDE_NEWER)
- `requirements.txt` — Python packages installed in container
- `.github/workflows/ci.yml` — build and push images via docker bake
- `.github/workflows/scans.yml` — security scanning
- `.pre-commit-config.yaml` — linting
  (actionlint, markdownlint, yamlfmt,
  gitleaks, editorconfig)
- `renovate.json` — automated dependency updates

## Build and Test

```sh
# build all images
docker compose build

# build single target
docker buildx bake 17_3

# run container smoke test
docker run ghcr.io/yxtay/databricks-container:17.3 uv pip list

# lint
pre-commit run --all-files
```

## Conventions

- Base image pinned by digest in Dockerfile ARG.
- `UV_EXCLUDE_NEWER` per version freezes Python
  dependency resolution to runtime release date.
- PySpark installed then uninstalled — needed for
  dependency resolution, not shipped
  (injected by Databricks at runtime).
- GitHub Actions pinned by commit SHA, not tag.
- Renovate manages all dependency updates with automerge for minor/digest.
- Pre-commit hooks enforce formatting — run before committing.

## Adding a New Runtime Version

1. Add new service block in `compose.yaml` following existing pattern.
2. Set build args based on
  [Databricks Runtime release notes][dbr-notes]:
  `DATABRICKS_RUNTIME_VERSION`, `JDK_VERSION`,
  `PYSPARK_VERSION`, `PYTHON_VERSION`,
  `UV_EXCLUDE_NEWER`.
3. Update `BASE_IMAGE` ubuntu version if needed.
4. Build and verify: `docker buildx bake <target>`.

## Removing an Old Runtime Version

1. Remove service block from `compose.yaml`.
2. No Dockerfile changes needed (parameterized).

## Modifying Python Dependencies

1. Edit `requirements.txt`.
2. Use version specifiers compatible with all
  supported Python versions, or use environment
  markers (e.g., `; python_version >= "3.10"`).
3. Build all targets to verify compatibility across versions.

## CI/CD

- Push to `main` or tag → builds and pushes all images to `ghcr.io/yxtay/databricks-container`.
- PRs → build only (no push), acts as validation.
- Weekly scheduled rebuild picks up base image updates.
- Scans workflow runs security checks (Trivy, Scorecard).

[dbr-notes]: https://docs.databricks.com/aws/en/release-notes/runtime/
