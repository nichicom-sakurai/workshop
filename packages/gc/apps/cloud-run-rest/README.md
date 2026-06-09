# cloud-run-rest

Cloud Run の [container contract](https://docs.cloud.google.com/run/docs/container-contract) を学ぶための、最小の Bun/TypeScript REST service です。
依存パッケージはゼロで、Bun 組み込みの `Bun.serve` だけで動きます。

このアプリを private Cloud Run service として deploy する Terraform サンプルは
[../../terraform/cloud-run-service-basic/](../../terraform/cloud-run-service-basic/) にあります。

## ファイル構成

| ファイル | 内容 |
| --- | --- |
| `src/index.ts` | REST service 本体。`GET /` → 200 JSON、それ以外 → 404 |
| `package.json` | 依存ゼロ。`scripts.start` でエントリポイントを起動 |
| `Dockerfile` | `oven/bun` ベースの single-stage イメージ定義 |
| `.dockerignore` | docker build コンテキストから実行に不要なファイルを除外 |

> この repo のトップレベル package（`packages/<name>/`）は `index.ts` を直下に置く規約ですが、
> このアプリは `packages/gc/apps/` 配下の nested app のため `src/index.ts` をエントリポイントにしています。
> `mise run dev:all` の走査対象（`packages/` 直下）には含まれないので、常駐 server がタスクをブロックしません。

## Cloud Run container contract の要点

`src/index.ts` は contract のうち次の2点をコードで明示しています。

- **`PORT` 環境変数で listen する port が決まる**（未設定なら 8080）。不正な値なら起動時に fail-fast します。
- **全 interface（`0.0.0.0`）で listen する**。`localhost` のみで listen するとリクエストが届きません。

Cloud Run が注入する `K_REVISION` / `K_SERVICE` をレスポンスに含めており、local 実行では `null`、Cloud Run 上では実際の値になります。

## local 実行

```bash
cd packages/gc/apps/cloud-run-rest
mise exec -- bun run start
```

別ターミナルから応答を確認します。

```bash
curl -s localhost:8080/        # 200: {"message":"Hello from cloud-run-rest",...}
curl -i -s localhost:8080/nope # 404
```

`PORT` を上書きすると listen port が変わることを確認できます（contract の動作確認）。

```bash
PORT=9090 mise exec -- bun run start
curl -s localhost:9090/   # 別ターミナルで実行
```

> `0.0.0.0` で listen するため、local 実行中は同一ネットワークの他ホストからも到達できます。
> 学習用の一時起動に留め、起動したままにしないでください。

### Docker での local 実行（任意）

Docker が使える環境なら、Cloud Run と同じコンテナ起動を local で再現できます。

```bash
cd packages/gc/apps/cloud-run-rest
docker build -t cloud-run-rest:local .
docker run --rm -e PORT=8080 -p 8080:8080 cloud-run-rest:local
curl -s localhost:8080/
```

## container image の build / push（Cloud Build）

infrastructure（Artifact Registry / Cloud Run）は Terraform、image の build / push は `gcloud builds submit` と役割を分けています。
Artifact Registry repository の作成を含む全体の流れは [Terraform サンプルの README](../../terraform/cloud-run-service-basic/README.md) を参照してください。

このディレクトリから実行する build / push コマンドは次の形です。

```bash
cd packages/gc/apps/cloud-run-rest
TAG="$(git rev-parse --short HEAD)"
gcloud builds submit --project nck-sakurai \
  --tag "asia-northeast1-docker.pkg.dev/nck-sakurai/cloud-run-rest/cloud-run-rest:${TAG}" .
```

- `--project` を明示しているのは、build の実行先が gcloud の active config に依存するためです（image パスの project と食い違うと push が失敗します）。

- ソースとしてアップロードされるのは**このディレクトリ配下のみ**です（repository 全体は送られません）。誤解を避けるため SOURCE の `.` を明示しています。
- tag には `latest` ではなく short git SHA など一意な値を使います。どの commit の image か追跡でき、Terraform 側の変数 validation も `latest` を拒否します。
- 初回実行時に Cloud Build 用の staging bucket（`nck-sakurai_cloudbuild`）が自動作成されます。中身は自動削除されないため、不要になったら手動で掃除してください。

## バージョン同期の注意

`Dockerfile` の `FROM oven/bun:<version>-slim` は、root の [`mise.toml`](../../../../mise.toml)（`[tools]` の `bun`）と同じバージョンに固定しています。
Docker は `mise.toml` を読めないため、`mise.toml` の bun を更新するときは `Dockerfile` の FROM タグも同時に更新してください。
