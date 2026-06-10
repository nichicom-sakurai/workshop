# AWS 課金・コストの確認

このリポジトリの学習サンプル、特に Bedrock / AgentCore を使う [`packages/aws/apps/agentcore-strands-basic/`](../../../packages/aws/apps/agentcore-strands-basic/README.md) を動かすと、AWS の**従量課金**が発生します。本ドキュメントは「**どこに課金されるのか**」と「**実費・単価をどう確認するか**(サイト / CLI)」をまとめた調査メモです。

> [INFO] CLI 例は `mise exec -- aws ...` 形式です（AWS CLI は mise 管理。認証は [AWS CLI 基本コマンド](../aws-cli/README.md) / [認証情報の設定](../aws-cli-credentials/README.md) を参照）。

## 課金が発生する場所（ローカル実行時）

`main.py` をローカル起動して `POST /invocations` を叩くと、処理はこう流れます。

```text
curl → 127.0.0.1:8080/invocations（自分の PC 上・無料）
  → invoke_bedrock_agent()
  → BedrockModel 経由で AWS の bedrock-runtime:ConverseStream を実際に呼ぶ ← ここが課金対象
```

ポイントは、**クライアント（uvicorn サーバー）がローカルで動いていても、モデル推論そのものは AWS の Bedrock 上で実行される**点です。したがってローカル実行でもトークン課金は実発生します。

| 項目 | ローカル実行時 | 課金 |
| --- | --- | --- |
| HTTP サーバー（uvicorn `127.0.0.1:8080`） | 自分の PC で動く | [OK] なし |
| Bedrock モデル推論（`ConverseStream`） | AWS 上で実行 | [NG] **あり**（入力 + 出力トークン） |
| AgentCore Runtime | ローカルではプロビジョニングされない | [OK] なし |
| S3 artifact / IAM 等（Terraform 分） | apply していなければ存在しない | [OK] なし |

- **課金先のアカウント** = 起動時に使った AWS 認証情報が属するアカウント（`AWS_PROFILE` / `AWS_ACCESS_KEY_ID` 等で解決）。確認は次のとおり。

  ```bash
  mise exec -- aws sts get-caller-identity   # 返ってくる Account がそのまま課金先
  ```

- **`jp.anthropic.claude-sonnet-4-6`**（cross-region inference profile）は **on-demand のトークン従量課金**です。ルーティング自体に追加料金はなく、リクエスト元リージョンの on-demand 価格で課金されます。
- AgentCore Runtime の利用料は、Terraform で実際に [`agentcore-runtime-basic`](../../../packages/aws/terraform/agentcore-runtime-basic/README.md) を apply し、managed runtime 経由で呼んだときに初めて加わります。

## ① 実費・使用量を確認する（かかった額）

### サイト（コンソール）

| ツール | URL | 用途 |
| --- | --- | --- |
| Billing ホーム | `console.aws.amazon.com/billing/home` | 当月の発生額サマリー |
| Bills（請求書） | `.../billing/home#/bills` | 月次の service 別内訳（Bedrock の行が出る） |
| **Cost Explorer** | `console.aws.amazon.com/cost-management/home#/cost-explorer` | 日別 / service 別にグラフ分析。Bedrock に絞り込み可。最も見やすい |
| Free Tier | `.../billing/home#/freetier` | 無料枠の消化状況 |
| Budgets | `.../billing/home#/budgets` | 予算アラートの設定 |
| Bedrock コンソールのコスト管理 | Bedrock → 使用状況 / コスト | モデル・usage type 単位の使用状況 |

### CLI — Cost Explorer API（`aws ce`）

当月の service 別コスト（期間は適宜調整）。

```bash
mise exec -- aws ce get-cost-and-usage \
  --time-period Start=2026-06-01,End=2026-06-30 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

Bedrock だけに絞る（トークン使用量も取得）。

```bash
mise exec -- aws ce get-cost-and-usage \
  --time-period Start=2026-06-01,End=2026-06-30 \
  --granularity DAILY \
  --metrics "UnblendedCost" "UsageQuantity" \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Bedrock"]}}'
```

`--group-by Type=DIMENSION,Key=USAGE_TYPE` を加えると `APN1-...`（ap-northeast-1）のようなトークン種別単位まで割れます。

## ② 単価（料金表）を確認する（事前見積もり）

### サイト

| ツール | URL | 用途 |
| --- | --- | --- |
| **Bedrock Pricing** | `aws.amazon.com/bedrock/pricing/` | モデル別の入力 / 出力トークン単価 |
| AgentCore Pricing | `aws.amazon.com/bedrock/agentcore/pricing/` | デプロイ時の Runtime 利用料 |
| Pricing Calculator | `calculator.aws` | 構成を入れて事前見積もり |

### CLI — Price List API（`aws pricing`）

東京リージョンの Anthropic on-demand 単価。

```bash
mise exec -- aws pricing get-products \
  --service-code "AmazonBedrock" \
  --filters \
    Type=TERM_MATCH,Field=provider,Value="Anthropic" \
    Type=TERM_MATCH,Field=feature,Value="On-demand Inference" \
    Type=TERM_MATCH,Field=location,Value="Asia Pacific (Tokyo)" \
  --region us-east-1 \
  --output json
```

JSON が大きいので `| jq` で `model` / `pricePerUnit` を抽出すると実用的です。属性名（`model` / `modelName`、`inferenceType` の大小文字など）はアカウント・リージョンで揺れるため、空が返るときは属性名を確認してください。

## 注意点

- **反映に最大 24時間ほどの遅延**があります。直前にローカルで叩いた `curl` の分は、Cost Explorer / `aws ce` にすぐには出ません。
- `aws ce`（Cost Explorer）と `aws pricing`（Price List）は**グローバルサービス**で、エンドポイントは **`us-east-1`** です。`aws ce` は事前に**コンソールで Cost Explorer の有効化**が必要です。
- **`aws ce` の API は 1ページネーションリクエストあたり課金**されます（確認行為自体に微課金。コンソールの Cost Explorer 画面は無料）。最新の単価は [Cost Explorer の料金](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/) を参照してください。
- 単価・課金体系は変わりうるため、金額は必ず公式ページ（[Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)）で最終確認してください。

## 関連

- 見積もり専用ツール: [`packages/aws/cost-estimator/`](../../../packages/aws/cost-estimator/README.md) — `bcm-pricing-calculator` API で②の事前見積もりを出す自作モジュール（実費①ではなく見積もり用途）。
- モデル ID の調べ方 / inference profile 形式: [AgentCore Terraform サンプル](../../../packages/aws/terraform/agentcore-runtime-basic/README.md)。

## 参考

- [aws pricing get-products / Price List Query API](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html)
- [ce get-cost-and-usage コマンドリファレンス](https://docs.aws.amazon.com/cli/latest/reference/ce/get-cost-and-usage.html)
- [Track usage and costs in Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/cost-management.html)
- [Amazon Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
