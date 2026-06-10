# catalog スキーマと API mapping リファレンス

見積もり専用 catalog（`catalog/*.yaml`）のスキーマと、AWS bcm-pricing-calculator API への
mapping をまとめます。値は AWS 公式ドキュメント・SDK リファレンス・CUR の慣例に基づく
**段階的検証中**の情報で、各 usage の確度は `mapping_status` で示します。

## catalog スキーマ

カテゴリごとに 1 YAML ファイル。loader（`src/catalog.ts`）が読み込み時に検証します。

```yaml
category: web                       # カテゴリ名（ファイルにつき 1 つ）
description: ...                     # 説明
region: ap-northeast-1              # 見積もり対象リージョン（usageType の prefix に使用）
services:
  - id: ec2                         # サービス短縮 ID（usage key 生成にも使用）
    service: Amazon EC2             # 表示名
    service_code: AmazonEC2         # AWS serviceCode（最大 32 文字）
    no_direct_charge: false         # 任意。true のサービスは usages を空にする（IAM 本体など）
    usages:
      - billing_axis: ...           # 人間可読な課金軸の説明
        usage_type: BoxUsage:t3.micro  # region prefix なしの core 値（最大 128 文字）
        operation: RunInstances     # AWS operation（最大 32 文字、空文字可）
        unit: Hrs                   # 課金単位
        amount: 730                 # サンプル使用量（0 以上の数値）
        mapping_status: mapped      # mapped / schema_only / needs_research
```

検証ルール（抜粋）:

- `category` / `description` / `region` / `service.id` / `service.service` / `service.service_code` /
  `usage.billing_axis` / `usage.usage_type` / `usage.unit` は非空文字列。
- `usage.operation` は文字列（空文字可）。`usage.amount` は 0 以上の有限数。
- `usage.mapping_status` は `mapped` / `schema_only` / `needs_research` のいずれか。
- `no_direct_charge: true` のサービスは `usages` を空に、それ以外は 1 件以上を持つ。

## bcm-pricing-calculator usage entry（検証済み・確度高）

adapter が生成する usage entry は `BatchCreateWorkloadEstimateUsage` の `--usage` 要素です。
必須6フィールドと制約は AWS 公式リファレンスで確認済みです（`mapped`）。

| フィールド | 必須 | 制約 |
| --- | --- | --- |
| `key` | ○ | 英数字のみ・最大 10 文字（batch 内で一意） |
| `usageAccountId` | ○ | 12 桁数字 |
| `serviceCode` | ○ | 最大 32 文字 |
| `usageType` | ○ | 最大 128 文字 |
| `operation` | ○ | 最大 32 文字（空文字可） |
| `amount` | ○ | double（serviceCode/usageType/operation が示す pricing unit） |
| `group` | — | 任意・最大 30 文字 |
| `historicalUsage` | — | 任意。指定時は `billInterval` / `filterExpression` / `serviceCode` / `usageType` / `operation` / `usageAccountId` が必須 |

- CLI: `aws bcm-pricing-calculator batch-create-workload-estimate-usage`
- operation 引数: `--workload-estimate-id`（必須・36 文字 UUID）, `--usage`（必須・1..25 件）, `--client-token`（任意）
- IAM action: `bcm-pricing-calculator:CreateWorkloadEstimateUsage`
- 出典: [CLI v2 reference](https://docs.aws.amazon.com/cli/latest/reference/bcm-pricing-calculator/batch-create-workload-estimate-usage.html) /
  [API reference](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_Types_AWS_Billing_and_Cost_Management_Pricing_Calculator.html)

## region prefix

ほぼすべての `usageType` は region で prefix が変わります。`us-east-1` は **prefix なし**、
それ以外は課金リージョンコード（`APN1-` / `USW2-` / `EUW1-` など）を前置します。
catalog は core 値を保持し、adapter（`src/adapter.ts` の `REGION_BILLING_PREFIX`）が
`region` から prefix を適用します（対応表は best-effort、要検証）。

## カテゴリ別 mapping（概要）

| カテゴリ | サービス | 代表 usageType | 主な確度 |
| --- | --- | --- | --- |
| web | EC2 / ALB / S3 | `BoxUsage:*`, `EBS:VolumeUsage.gp3`, `LoadBalancerUsage`, `LCUUsage`, `TimedStorage-ByteHrs`, `Requests-Tier1/2`, `DataTransfer-Out-Bytes` | EC2/S3 は `mapped`、ALB と egress は `schema_only` |
| database | RDS | `InstanceUsage:db.*`, `RDS:GP3-Storage`, `RDS:ChargedBackupUsage` | instance は `mapped`、storage/backup は `schema_only` |
| container | ECS Fargate | `Fargate-vCPU-Hours:perCPU`, `Fargate-GB-Hours` | vCPU/memory は `mapped`、ephemeral storage は `needs_research` |
| functions | Lambda | `Request`, `Lambda-GB-Second` | CUR 文字列が非公式のため `schema_only` |
| iam | IAM / Access Analyzer | （IAM 本体は無料）`AccessFinding-Monitored-IAM-Resources`, `CustomCheck-API-Requests` | Access Analyzer 主要 2 軸は `mapped`、internal access は `needs_research` |

補足:

- **RDS**: engine は usageType ではなく operation（`CreateDBInstance:NNNN`）で表す（`:0002` MySQL,
  `:0014` PostgreSQL, `:0018` MariaDB）。storage/backup の operation は instance の engine operation を
  継承する**推定**のため、usageType が判明していても `schema_only`。Aurora は usageType 体系が
  異なるため対象外（必要なら `needs_research` で追加）。
- **Lambda**: base 行は CUR 上 operation が空のことが多く、operation は空文字で表現。
- **Access Analyzer**: 課金は usageType 駆動で operation は空。

## 未検証項目（要調査）

段階的検証の残課題です。`--submit` の前に、対象 account / region の実 CUR や Price List API で
確定してください。

- region prefix 対応表（`REGION_BILLING_PREFIX`）は慣例ベースで、全リージョン網羅・正確性は未保証。
- ELBv2 の `serviceCode`（`AWSELB`）と operation（`LoadBalancing:Application`）は確度中・推定。
- EC2/EBS/S3 の operation（`RunInstances:NNNN`, `CreateVolume-Gp3`, storage/egress の帰属）は慣例値で、
  Price List API / 実 CUR と未照合。
- RDS の storage/backup/IOPS と operation の組、Multi-AZ / 他 engine の operation コードは推定。
- Fargate ephemeral storage / Spot の usageType は権威ある出典が無く推定（`needs_research`）。
- Lambda の CUR usageType は公式 pricing ページに記載が無く、`Request` / `Lambda-GB-Second` 以外
  （Lambda@Edge, provisioned concurrency, ephemeral storage）は未検証。
- IAM Access Analyzer の internal access analysis の usageType は CUR リファレンス未掲載。
