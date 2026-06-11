# cost-estimator

AWS 構成別の月額概算を作るための、**見積もり専用 catalog** と
AWS [bcm-pricing-calculator](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/Welcome.html)
（Billing and Cost Management Pricing Calculator）API 向け adapter の初期土台です。

source of truth は Terraform ではなく、`catalog/*.yaml` の見積もり専用構成ファイルです。
web / database / container / functions / iam の 5 カテゴリを「広く浅く」扱い、各カテゴリの
代表サービスから始めます。API mapping は一度に完全化せず、各 usage に `mapping_status`
（`mapped` / `schema_only` / `needs_research`）を付けて確度を明示します。

> 学習・見積もり補助用です。実際の AWS 請求額の完全再現は目的ではありません。

## 構成

```text
cost-estimator/
├── index.ts            # CLI エントリ（dry-run 出力 / --submit 送信）
├── catalog/            # 見積もり専用 catalog（カテゴリごとに 1 YAML）
│   ├── README.md       # catalog スキーマと API mapping リファレンス
│   ├── web.yaml        # EC2 / ALB / S3
│   ├── database.yaml   # RDS（instance / storage / backup）
│   ├── container.yaml  # ECS Fargate（vCPU / memory / 稼働時間）
│   ├── functions.yaml  # Lambda（request / 実行時間 / memory）
│   └── iam.yaml        # IAM 本体（無料）+ IAM Access Analyzer（課金 addon）
├── src/
│   ├── types.ts        # catalog / payload の型
│   ├── catalog.ts      # YAML loader + バリデーション（Bun.YAML）
│   ├── adapter.ts      # catalog → bcm-pricing-calculator usage 変換
│   └── submit.ts       # AWS CLI 経由の送信 wrapper
└── test/               # bun:test（catalog / adapter / acceptance / submit / cli）
```

依存は dev 用の `@types/bun` のみ。YAML パース（`Bun.YAML`）・テスト（`bun:test`）・
型チェック（`tsc`）はすべて Bun 同梱機能で行い、**ランタイム依存はゼロ**です。

> このツールは root の `apps/` 配下の runnable app です。`mise run dev cost-estimator`
> で実行でき、`mise run bs` の `bun install` も対象です。

## 使い方

bun は mise 管理のため、`mise exec -- ` を前置します（shell を activate 済みなら不要）。

```bash
# dry-run: payload + metadata + summary を JSON で出力（AWS 認証不要）
mise exec -- bun run apps/cost-estimator/index.ts

# needs_research を除外して出力
mise exec -- bun run apps/cost-estimator/index.ts --exclude-needs-research

# account ID を指定（既定は AWS_ESTIMATE_ACCOUNT_ID env か placeholder）
mise exec -- bun run apps/cost-estimator/index.ts --account-id 123456789012

# 実 API へ送信（AWS 認証が必要。workload estimate は事前に作成しておく）
mise exec -- bun run apps/cost-estimator/index.ts \
  --submit --workload-estimate-id <uuid>

# ヘルプ
mise exec -- bun run apps/cost-estimator/index.ts --help
```

出力（dry-run）は次の形です。`batches` は API の `--usage` 上限（25 件/batch）で分割済みです。

```jsonc
{
  "apiOperation": "BatchCreateWorkloadEstimateUsage",
  "cliCommand": "aws bcm-pricing-calculator batch-create-workload-estimate-usage",
  "usageAccountId": "000000000000",
  "summary": {
    "totalEntries": 20,
    "batchCount": 1,
    "byMappingStatus": { "mapped": 10, "schema_only": 8, "needs_research": 2 },
    "byCategory": { "web": 9, "database": 3, "container": 3, "functions": 2, "iam": 3 },
    "noDirectChargeServices": ["iam/iam"]
  },
  "batches": [[{ "key": "u001", "usageAccountId": "...", "serviceCode": "AmazonEC2", "usageType": "APN1-BoxUsage:t3.micro", "operation": "RunInstances", "amount": 730 }]],
  "metadata": [{ "key": "u001", "category": "web", "serviceId": "ec2", "mappingStatus": "mapped", "...": "..." }]
}
```

- `summary` / `batches` は AWS が受理できる純粋な usage payload（`mapping_status` を含まない）。
- `mapping_status` は payload と分離した `metadata` 側に持ち、どの entry が検証済みかを示します。

## mapping_status の意味

| 値 | 意味 |
| --- | --- |
| `mapped` | serviceCode / usageType / operation を AWS 公式情報で確認済み（確度高）。 |
| `schema_only` | 構造は正しいが exact な文字列が未検証（CUR 由来など。確度中）。 |
| `needs_research` | usageType / operation が推定で、要追加調査（確度低）。`--submit` 時は警告し、API に拒否される可能性あり。 |

`--submit` でうまく通らない usage は `mapping_status` を手がかりに、`catalog/README.md`
の「未検証項目（要調査）」と実際の CUR / Price List API で値を確定してください。

## catalog の編集 / 追加

- カテゴリを増やすときは `catalog/<category>.yaml` を 1 つ足すだけです（loader が
  `catalog/*.yaml` を自動で走査します）。
- `usage_type` は **region prefix を含まない core 値**で書きます。adapter が `region`
  から prefix（例: `ap-northeast-1` → `APN1-`）を付与します。
- スキーマと各フィールドの意味は [`catalog/README.md`](./catalog/README.md) を参照してください。

## セキュリティ

- 認証情報・実 account ID・個人 profile 名は**リポジトリに保存しません**。
- `usageAccountId` は `--account-id` / `AWS_ESTIMATE_ACCOUNT_ID` env / placeholder
  （`000000000000`）の順で解決します。
- `--submit` の AWS 認証は AWS CLI 標準の仕組み（env / profile）に委ねます。

## 検証

```bash
cd apps/cost-estimator
mise exec -- bun test          # 全テスト
mise exec -- bunx tsc --noEmit # 型チェック
```
