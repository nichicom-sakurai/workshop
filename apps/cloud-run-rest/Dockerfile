# bun のバージョンは root の mise.toml（[tools] bun）と同じ値に固定しています。
# Docker は mise.toml を読めないため、ここに版数を直接書く必要があります。
# mise.toml の bun を更新するときは、この FROM タグも同時に更新してください。
FROM oven/bun:1.3.14-slim

WORKDIR /app

# 依存ゼロ（Bun.serve 組み込みのみ）のため bun install は不要で、
# ソースのコピーだけで実行できます。依存を追加したら install ステップが必要になります。
COPY package.json ./
COPY src ./src

# oven/bun イメージ同梱の非 root ユーザーで実行します（最小権限）。
USER bun

# Cloud Run は実行時に $PORT（既定 8080）を注入します。
# EXPOSE は公開 port の文書化であり、実際の listen port は $PORT が決めます。
EXPOSE 8080

CMD ["bun", "run", "src/index.ts"]
