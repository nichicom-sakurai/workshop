#!/bin/bash
set -euo pipefail

# Project root directory
FILE_PATH=$(dirname "$0")
cd "$FILE_PATH/../" || exit 1

# プロジェクト格納ディレクトリ (この配下を全て bootstrap する)
PROJECTS_DIR="packages"

echo "[INFO] Bootstrap start"
echo "[INFO] Working directory: $(pwd)"

##############################################################################
##
##  mise (root のツール)
##
##############################################################################
echo ""
echo "[INFO] mise install (root): Start"
if type mise >/dev/null 2>&1; then
  mise trust >/dev/null 2>&1 || true
  mise install
  echo "[OK] mise install (root): Success"
else
  echo "[WARNING] mise install: Skip mise because it could not be found."
  echo "[WARNING] mise install: See https://mise.jdx.dev/getting-started.html for installation."
fi

##############################################################################
##
##  packages/* (配下の全プロジェクトを bootstrap)
##  固有 mise.toml があれば mise install / package.json があれば bun install
##
##############################################################################
echo ""
echo "[INFO] ${PROJECTS_DIR}/* bootstrap: Start"
if ! type mise >/dev/null 2>&1; then
  echo "[WARNING] Skip ${PROJECTS_DIR}/* because mise could not be found."
elif [ ! -d "$PROJECTS_DIR" ]; then
  echo "[WARNING] Skip: ${PROJECTS_DIR}/ does not exist."
else
  # 固有 mise.toml / .mise.toml があれば install (root から継承するものは不要)
  find "$PROJECTS_DIR" -name node_modules -prune -o \
    \( -name mise.toml -o -name .mise.toml \) -print |
    while read -r config; do
      dir=$(dirname "$config")
      echo "  -> mise install: ${dir}"
      (cd "$dir" && { mise trust >/dev/null 2>&1 || true; } && mise install)
    done
  # package.json があれば bun install (bun は mise 経由で実行)
  find "$PROJECTS_DIR" -name node_modules -prune -o -name package.json -print |
    while read -r pkg; do
      dir=$(dirname "$pkg")
      echo "  -> bun install: ${dir}"
      (cd "$dir" && mise exec -- bun install)
    done
  echo "[OK] ${PROJECTS_DIR}/* bootstrap: Success"
fi

##############################################################################
##
##  git hooks (commit-msg: Conventional Commits 検証)
##
##############################################################################
echo ""
echo "[INFO] git hooks: Start"
if type git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath tools/git-hooks
  echo "[OK] git hooks: core.hooksPath = tools/git-hooks"
else
  echo "[WARNING] git hooks: Skip (git repository not found)."
fi

##############################################################################
##
##  Finish
##
##############################################################################
echo ""
echo "[INFO] Bootstrap finished"
