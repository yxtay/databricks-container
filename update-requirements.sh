#!/bin/env bash
set -euxo pipefail

DATABRICKS_RUNTIME_VERSION=${DATABRICKS_RUNTIME_VERSION:-16.4}
VIRTUAL_ENV=${VIRTUAL_ENV:-.venv}
export UV_PYTHON=${PYTHON_VERSION:-3.12}

script_dir=$(dirname "$(readlink -f "$0")")
requirements_in="${script_dir}/${DATABRICKS_RUNTIME_VERSION}/requirements.in"
requirements_txt="${script_dir}/${DATABRICKS_RUNTIME_VERSION}/requirements.txt"

# relax requirements and constraints
sed -Ei 's/~=/>=/' "${requirements_in}"

# compile requirements
uv python install
uv pip compile --no-strip-extras --upgrade --verbose \
  --index-strategy unsafe-best-match \
  "${requirements_in}" \
  --output-file "${requirements_txt}"

# relax compatible requirements
sed -Ei 's/==/~=/' "${requirements_txt}"

# update requirements-extra
uv run merge_requirements.py \
  --requirements_in "${requirements_in}" \
  --requirements_txt "${requirements_txt}" \
  --requirements_out "${requirements_in}"
