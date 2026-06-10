#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${APP_DIR}/.build"
PACKAGE_DIR="${BUILD_DIR}/package"
DIST_DIR="${APP_DIR}/dist"
REQUIREMENTS_FILE="${BUILD_DIR}/requirements.txt"
ARTIFACT_PATH="${DIST_DIR}/agentcore-strands-basic.zip"
PYTHON_BIN="$(mise exec -- python -c 'import sys; print(sys.executable)')"

rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${PACKAGE_DIR}" "${DIST_DIR}"

mise exec -- uv export \
  --directory "${APP_DIR}" \
  --locked \
  --format requirements.txt \
  --no-hashes \
  --no-header \
  --no-annotate \
  --no-emit-project \
  --output-file "${REQUIREMENTS_FILE}" \
  > /dev/null

mise exec -- uv pip install \
  --requirements "${REQUIREMENTS_FILE}" \
  --target "${PACKAGE_DIR}" \
  --python "${PYTHON_BIN}" \
  --python-version "3.13" \
  --python-platform "aarch64-manylinux2014" \
  --only-binary ":all:"

cp "${APP_DIR}/main.py" "${PACKAGE_DIR}/main.py"
find "${PACKAGE_DIR}" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "${PACKAGE_DIR}" -type f -name "*.py[co]" -delete

(
  cd "${PACKAGE_DIR}"
  zip -qr "${ARTIFACT_PATH}" .
)

printf '[OK] Created %s\n' "${ARTIFACT_PATH}"
