#!/usr/bin/env bash
set -euo pipefail

# AgentCore Runtime の direct code deployment ZIP を作る。
# 依存（strands-agents / bedrock-agentcore / boto3 など）を Linux/aarch64 向けに vendoring し、
# entry point の main.py と実装パッケージ rag_chat/ を同梱して 1 つの ZIP に固める。
# 出力 dist/agentcore-rag-chat.zip は gitignore 対象（apps/*/dist/）。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${APP_DIR}/.build"
PACKAGE_DIR="${BUILD_DIR}/package"
DIST_DIR="${APP_DIR}/dist"
REQUIREMENTS_FILE="${BUILD_DIR}/requirements.txt"
ARTIFACT_PATH="${DIST_DIR}/agentcore-rag-chat.zip"
PYTHON_BIN="$(mise exec -- python -c 'import sys; print(sys.executable)')"

rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${PACKAGE_DIR}" "${DIST_DIR}"

# uv.lock から依存を requirements.txt 形式で書き出す（project 自身は除外）。
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

# 依存を AgentCore Runtime（Linux/aarch64・Python 3.13）向けに wheel のみで install。
mise exec -- uv pip install \
  --requirements "${REQUIREMENTS_FILE}" \
  --target "${PACKAGE_DIR}" \
  --python "${PYTHON_BIN}" \
  --python-version "3.13" \
  --python-platform "aarch64-manylinux2014" \
  --only-binary ":all:"

# entry point と実装パッケージを同梱（chat.py / tests / scripts はデプロイに不要なので含めない）。
cp "${APP_DIR}/main.py" "${PACKAGE_DIR}/main.py"
cp -R "${APP_DIR}/rag_chat" "${PACKAGE_DIR}/rag_chat"

# バイトコードキャッシュは持ち込まない。
find "${PACKAGE_DIR}" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "${PACKAGE_DIR}" -type f -name "*.py[co]" -delete

(
  cd "${PACKAGE_DIR}"
  zip -qr "${ARTIFACT_PATH}" .
)

printf '[OK] Created %s\n' "${ARTIFACT_PATH}"
