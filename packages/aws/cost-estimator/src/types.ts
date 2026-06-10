/**
 * cost-estimator の型定義。
 * catalog (YAML) と AWS bcm-pricing-calculator の usage payload の双方を表す。
 */

/** mapping の検証状態。AWS API mapping の確信度を 3 段階で表す。 */
export type MappingStatus = "mapped" | "schema_only" | "needs_research";

/** 許容される mapping_status 値の一覧（バリデーションに使用）。 */
export const MAPPING_STATUSES: readonly MappingStatus[] = [
  "mapped",
  "schema_only",
  "needs_research",
] as const;

/** catalog 内の 1 課金軸（usage 行）。 */
export interface CatalogUsage {
  /** 人間可読な課金軸の説明（例: on-demand instance hours）。 */
  billing_axis: string;
  /** AWS usageType の core 値（region prefix なし。例: BoxUsage:t3.micro）。 */
  usage_type: string;
  /** AWS operation（例: RunInstances）。無い場合は空文字。 */
  operation: string;
  /** 課金単位（例: Hrs, GB-Mo, Requests, GB-Second）。 */
  unit: string;
  /** サンプル使用量（pricing unit 単位の数値）。 */
  amount: number;
  /** この mapping の検証状態。 */
  mapping_status: MappingStatus;
}

/** catalog 内の 1 サービス。 */
export interface CatalogService {
  /** サービス短縮 ID（例: ec2, alb, s3）。usage entry の key 生成にも使う。 */
  id: string;
  /** サービス表示名（例: Amazon EC2）。 */
  service: string;
  /** AWS serviceCode（例: AmazonEC2）。 */
  service_code: string;
  /** 直接課金が無いサービス（例: IAM 本体）は true。usages は空でなければならない。 */
  no_direct_charge?: boolean;
  /** usage 行。no_direct_charge のサービスは空配列。 */
  usages: CatalogUsage[];
}

/** 1 カテゴリの catalog（1 YAML ファイルに対応）。 */
export interface Catalog {
  /** カテゴリ名（web / database / container / functions / iam）。 */
  category: string;
  /** カテゴリの説明。 */
  description: string;
  /** 見積もり対象リージョン。usageType の region prefix 適用に使用する。 */
  region: string;
  /** サービス一覧。 */
  services: CatalogService[];
}

/**
 * bcm-pricing-calculator の usage entry。
 * BatchCreateWorkloadEstimateUsage の `--usage` 配列の 1 要素に対応する。
 * フィールドと制約は AWS 公式リファレンスに基づく（catalog/README.md 参照）。
 */
export interface WorkloadEstimateUsageEntry {
  /** batch 内で一意な caller 割当 key（英数字のみ・最大 10 文字）。 */
  key: string;
  /** 使用量を帰属させる 12 桁 AWS account ID。 */
  usageAccountId: string;
  /** AWS serviceCode（最大 32 文字）。 */
  serviceCode: string;
  /** region prefix 適用後の usageType（最大 128 文字）。 */
  usageType: string;
  /** AWS operation（最大 32 文字、空文字可）。 */
  operation: string;
  /** 使用量（double）。 */
  amount: number;
}

/** 各 usage entry に対応するメタ情報。API payload には含めない。 */
export interface UsageMetadata {
  key: string;
  category: string;
  serviceId: string;
  service: string;
  billingAxis: string;
  unit: string;
  mappingStatus: MappingStatus;
}

/** mapping_status ごとの件数。 */
export type MappingStatusCounts = Record<MappingStatus, number>;

/** adapter の集計サマリー。 */
export interface AdapterSummary {
  /** 課金対象 entry の総数。 */
  totalEntries: number;
  /** チャンク分割後の batch 数。 */
  batchCount: number;
  /** mapping_status ごとの件数。 */
  byMappingStatus: MappingStatusCounts;
  /** カテゴリごとの entry 件数。 */
  byCategory: Record<string, number>;
  /** no_direct_charge として payload から除外したサービス（"category/serviceId" 形式）。 */
  noDirectChargeServices: string[];
}

/** adapter の変換結果。 */
export interface AdapterResult {
  /** API の `--usage` 上限（25 件）でチャンク分割した batch 群。 */
  batches: WorkloadEstimateUsageEntry[][];
  /** entry の平坦リスト（参照・テスト用）。 */
  entries: WorkloadEstimateUsageEntry[];
  /** entry に対応するメタ情報。 */
  metadata: UsageMetadata[];
  /** 集計サマリー。 */
  summary: AdapterSummary;
}
