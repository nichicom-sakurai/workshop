#!/usr/bin/env bash
# Vertex AI Agent Engine(reasoning engine)用の source archive(.tar.gz)を生成する。
#
# inline_source 方式では archive に依存を「同梱しない」。Agent Engine の managed
# runtime が archive root の requirements.txt を見て pip install する。よってこの
# script はソース(hello_world/ + agent_engine_app.py)と requirements.txt を
# tar.gz に固めるだけで、AgentCore の package.sh のような依存 vendoring はしない。
#
# 生成物 .build/source.tar.gz は gitignore 対象(packages/gc/apps/*/.build/)。
# Terraform は adk-agent-engine-basic の filebase64(var.source_archive_path) で読む。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${APP_DIR}/.build"
STAGE_DIR="${BUILD_DIR}/source"
ARTIFACT_PATH="${BUILD_DIR}/source.tar.gz"

# 毎回クリーンに作り直す(re-run 安全)。
rm -rf "${BUILD_DIR}"
mkdir -p "${STAGE_DIR}"

# 1) ローカル run と共通の agent パッケージ。ローカル runtime/secret 由来のものは
#    archive に含めない: .env*(secret/template)、.adk/(adk run/web のセッション
#    store)、__pycache__/、*.pyc。.env* の除去は将来 subpackage が独自 .env を
#    持っても漏らさないよう再帰的にする(defense-in-depth)。
cp -R "${APP_DIR}/hello_world" "${STAGE_DIR}/hello_world"
find "${STAGE_DIR}/hello_world" -type f -name '.env*' -delete
find "${STAGE_DIR}/hello_world" -type d -name '.adk' -prune -exec rm -rf {} +
find "${STAGE_DIR}/hello_world" -type d -name '__pycache__' -prune -exec rm -rf {} +
find "${STAGE_DIR}/hello_world" -type f -name '*.py[co]' -delete

# 2) Agent Engine 用 entrypoint と requirements を archive root に置く。
#    entrypoint_module = "agent_engine_app" / requirements_file = "requirements.txt"
#    が archive root のこの 2 ファイルを指す。
cp "${APP_DIR}/agent-engine/agent_engine_app.py" "${STAGE_DIR}/agent_engine_app.py"
cp "${APP_DIR}/agent-engine/requirements.txt" "${STAGE_DIR}/requirements.txt"

# 3) tar.gz 化。archive root 直下に hello_world/ / agent_engine_app.py /
#    requirements.txt が並ぶ。COPYFILE_DISABLE で macOS の ._* メタファイルを抑止し、
#    Linux runtime にゴミを持ち込まない。
COPYFILE_DISABLE=1 tar -czf "${ARTIFACT_PATH}" -C "${STAGE_DIR}" .

printf '[OK] Created %s\n' "${ARTIFACT_PATH}"
printf '[INFO] Archive contents:\n'
tar -tzf "${ARTIFACT_PATH}" | sed 's/^/  /'
printf '[INFO] Next: plan/apply the Terraform sample that reads this archive\n'
printf '       mise exec -- terraform -chdir=packages/gc/terraform/adk-agent-engine-basic plan\n'
