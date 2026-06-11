/**
 * catalog を AWS bcm-pricing-calculator の usage payload に変換する adapter。
 *
 * 変換規則と API 制約は公式リファレンス（BatchCreateWorkloadEstimateUsage）に基づく:
 * - usage entry の必須6フィールド: key / usageAccountId / serviceCode / usageType / operation / amount
 * - key: 英数字のみ・最大 10 文字 / usageAccountId: 12 桁数字 / serviceCode: 最大 32
 * - usageType: 最大 128 / operation: 最大 32（空文字可）
 * - `--usage` は 1 batch あたり最大 25 件
 * 詳細は catalog/README.md を参照。
 */
import {
  MAPPING_STATUSES,
  type AdapterResult,
  type Catalog,
  type MappingStatusCounts,
  type UsageMetadata,
  type WorkloadEstimateUsageEntry,
} from "./types";

/** adapter の変換が API 制約や入力検証に違反した場合に投げる例外。 */
export class AdapterError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdapterError";
  }
}

/** bcm-pricing-calculator usage entry の API 制約（公式リファレンス由来）。 */
export const API_LIMITS = {
  keyMax: 10,
  serviceCodeMax: 32,
  usageTypeMax: 128,
  operationMax: 32,
  batchMax: 25,
} as const;

/** dry-run / 学習用の placeholder account ID（実アカウントではない 12 桁ダミー）。 */
export const PLACEHOLDER_ACCOUNT_ID = "000000000000";

const ACCOUNT_ID_RE = /^\d{12}$/;

/**
 * AWS 課金リージョンコード（usageType の region prefix）。
 * us-east-1 は prefix を持たない（usageType は無印）。
 * 出典: AWS Region billing codes（公式）
 *   https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-region-billing-codes.html
 */
const REGION_BILLING_PREFIX: Record<string, string> = {
  "us-east-1": "",
  "us-east-2": "USE2",
  "us-west-1": "USW1",
  "us-west-2": "USW2",
  "ca-central-1": "CAN1",
  "sa-east-1": "SAE1",
  "eu-west-1": "EU", // eu-west-1 (Ireland) は数値サフィックス無しの例外
  "eu-west-2": "EUW2",
  "eu-west-3": "EUW3",
  "eu-central-1": "EUC1",
  "eu-north-1": "EUN1",
  "ap-south-1": "APS3",
  "ap-southeast-1": "APS1",
  "ap-southeast-2": "APS2",
  "ap-northeast-1": "APN1",
  "ap-northeast-2": "APN2",
  "ap-northeast-3": "APN3",
};

/** リージョンの課金 prefix を返す。us-east-1 は ""。未知なら AdapterError。 */
export function regionBillingPrefix(region: string): string {
  const prefix = REGION_BILLING_PREFIX[region];
  if (prefix === undefined) {
    const supported = Object.keys(REGION_BILLING_PREFIX).join(", ");
    throw new AdapterError(
      `未対応のリージョン: ${region}。REGION_BILLING_PREFIX に追加してください（対応: ${supported}）`,
    );
  }
  return prefix;
}

/** usageType の core 値にリージョン prefix を適用する。 */
export function applyRegionPrefix(usageType: string, region: string): string {
  const prefix = regionBillingPrefix(region);
  return prefix === "" ? usageType : `${prefix}-${usageType}`;
}

/** 一意・英数字・最大 10 文字の usage key を生成する（グローバル連番）。 */
function usageKey(index: number): string {
  const key = `u${String(index).padStart(3, "0")}`;
  if (key.length > API_LIMITS.keyMax) {
    throw new AdapterError(`usage 件数が多すぎて key が ${API_LIMITS.keyMax} 文字を超えました: ${key}`);
  }
  return key;
}

/** 配列を size ごとのチャンクに分割する。 */
function chunk<T>(items: T[], size: number): T[][] {
  const batches: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    batches.push(items.slice(i, i + size));
  }
  return batches;
}

function emptyStatusCounts(): MappingStatusCounts {
  const counts = {} as MappingStatusCounts;
  for (const status of MAPPING_STATUSES) {
    counts[status] = 0;
  }
  return counts;
}

export interface ToUsageOptions {
  /** 使用量を帰属させる 12 桁 account ID。 */
  usageAccountId: string;
  /** 1 batch あたりの entry 数（既定 25、API 上限）。 */
  batchSize?: number;
}

/** catalog 群を bcm-pricing-calculator の usage payload + メタ情報に変換する。 */
export function toWorkloadEstimateUsage(
  catalogs: Catalog[],
  options: ToUsageOptions,
): AdapterResult {
  const { usageAccountId } = options;
  if (!ACCOUNT_ID_RE.test(usageAccountId)) {
    throw new AdapterError(`usageAccountId は 12 桁の数字である必要があります: ${usageAccountId}`);
  }

  const batchSize = options.batchSize ?? API_LIMITS.batchMax;
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > API_LIMITS.batchMax) {
    throw new AdapterError(`batchSize は 1..${API_LIMITS.batchMax} の整数である必要があります: ${batchSize}`);
  }

  const entries: WorkloadEstimateUsageEntry[] = [];
  const metadata: UsageMetadata[] = [];
  const byMappingStatus = emptyStatusCounts();
  const byCategory: Record<string, number> = {};
  const noDirectChargeServices: string[] = [];

  let index = 0;
  for (const catalog of catalogs) {
    for (const service of catalog.services) {
      if (service.no_direct_charge) {
        noDirectChargeServices.push(`${catalog.category}/${service.id}`);
        continue;
      }
      for (const usage of service.usages) {
        index += 1;
        const key = usageKey(index);
        const usageType = applyRegionPrefix(usage.usage_type, catalog.region);

        if (service.service_code.length > API_LIMITS.serviceCodeMax) {
          throw new AdapterError(
            `${catalog.category}/${service.id}: serviceCode が ${API_LIMITS.serviceCodeMax} 文字を超えています: ${service.service_code}`,
          );
        }
        if (usageType.length > API_LIMITS.usageTypeMax) {
          throw new AdapterError(
            `${catalog.category}/${service.id}: usageType が ${API_LIMITS.usageTypeMax} 文字を超えています: ${usageType}`,
          );
        }
        if (usage.operation.length > API_LIMITS.operationMax) {
          throw new AdapterError(
            `${catalog.category}/${service.id}: operation が ${API_LIMITS.operationMax} 文字を超えています: ${usage.operation}`,
          );
        }

        entries.push({
          key,
          usageAccountId,
          serviceCode: service.service_code,
          usageType,
          operation: usage.operation,
          amount: usage.amount,
        });
        metadata.push({
          key,
          category: catalog.category,
          serviceId: service.id,
          service: service.service,
          billingAxis: usage.billing_axis,
          unit: usage.unit,
          mappingStatus: usage.mapping_status,
        });

        byMappingStatus[usage.mapping_status] += 1;
        byCategory[catalog.category] = (byCategory[catalog.category] ?? 0) + 1;
      }
    }
  }

  const batches = chunk(entries, batchSize);

  return {
    batches,
    entries,
    metadata,
    summary: {
      totalEntries: entries.length,
      batchCount: batches.length,
      byMappingStatus,
      byCategory,
      noDirectChargeServices,
    },
  };
}
