import { describe, expect, test } from "bun:test";
import {
  AdapterError,
  applyRegionPrefix,
  PLACEHOLDER_ACCOUNT_ID,
  regionBillingPrefix,
  toWorkloadEstimateUsage,
} from "../src/adapter";
import type { Catalog } from "../src/types";

function webCatalog(region = "ap-northeast-1"): Catalog {
  return {
    category: "web",
    description: "web",
    region,
    services: [
      {
        id: "ec2",
        service: "Amazon EC2",
        service_code: "AmazonEC2",
        usages: [
          {
            billing_axis: "on-demand instance hours",
            usage_type: "BoxUsage:t3.micro",
            operation: "RunInstances",
            unit: "Hrs",
            amount: 730,
            mapping_status: "mapped",
          },
          {
            billing_axis: "data transfer out",
            usage_type: "DataTransfer-Out-Bytes",
            operation: "RunInstances",
            unit: "GB",
            amount: 100,
            mapping_status: "schema_only",
          },
        ],
      },
      {
        id: "iam",
        service: "AWS IAM",
        service_code: "AWSIdentityAndAccessManagement",
        no_direct_charge: true,
        usages: [],
      },
    ],
  };
}

describe("regionBillingPrefix / applyRegionPrefix", () => {
  test("us-east-1 は prefix なし", () => {
    expect(regionBillingPrefix("us-east-1")).toBe("");
    expect(applyRegionPrefix("TimedStorage-ByteHrs", "us-east-1")).toBe("TimedStorage-ByteHrs");
  });

  test("ap-northeast-1 は APN1 prefix", () => {
    expect(regionBillingPrefix("ap-northeast-1")).toBe("APN1");
    expect(applyRegionPrefix("BoxUsage:t3.micro", "ap-northeast-1")).toBe(
      "APN1-BoxUsage:t3.micro",
    );
  });

  test("eu-west-1 は数値サフィックス無しの EU（公式 billing code の例外）", () => {
    expect(regionBillingPrefix("eu-west-1")).toBe("EU");
    expect(applyRegionPrefix("BoxUsage:t3.micro", "eu-west-1")).toBe("EU-BoxUsage:t3.micro");
  });

  test("未知のリージョンは AdapterError", () => {
    expect(() => regionBillingPrefix("moon-base-1")).toThrow(AdapterError);
  });
});

describe("toWorkloadEstimateUsage", () => {
  test("課金 usage を entry 化し、no_direct_charge は除外する", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(result.entries).toHaveLength(2);
    expect(result.summary.noDirectChargeServices).toContain("web/iam");
  });

  test("key は英数字のみ・最大 10 文字・一意", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    const keys = result.entries.map((e) => e.key);
    expect(new Set(keys).size).toBe(keys.length);
    for (const key of keys) {
      expect(key).toMatch(/^[a-zA-Z0-9]{1,10}$/);
    }
  });

  test("usageAccountId を全 entry に注入する", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: "123456789012",
    });
    for (const e of result.entries) {
      expect(e.usageAccountId).toBe("123456789012");
    }
  });

  test("region prefix を usageType に適用する", () => {
    const apn = toWorkloadEstimateUsage([webCatalog("ap-northeast-1")], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(apn.entries[0]!.usageType).toBe("APN1-BoxUsage:t3.micro");

    const use1 = toWorkloadEstimateUsage([webCatalog("us-east-1")], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(use1.entries[0]!.usageType).toBe("BoxUsage:t3.micro");
  });

  test("summary.byMappingStatus は 3 状態すべてを 0 込みで集計する", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(result.summary.byMappingStatus).toEqual({
      mapped: 1,
      schema_only: 1,
      needs_research: 0,
    });
    expect(result.summary.byCategory).toEqual({ web: 2 });
    expect(result.summary.totalEntries).toBe(2);
  });

  test("batchSize で 25 件上限のチャンク分割を行う", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
      batchSize: 1,
    });
    expect(result.batches).toHaveLength(2);
    expect(result.batches[0]).toHaveLength(1);
    expect(result.batches[1]).toHaveLength(1);
    expect(result.summary.batchCount).toBe(2);
  });

  test("metadata は entry と 1:1 対応し mappingStatus を保持する", () => {
    const result = toWorkloadEstimateUsage([webCatalog()], {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(result.metadata).toHaveLength(result.entries.length);
    expect(result.metadata.map((m) => m.key)).toEqual(result.entries.map((e) => e.key));
    expect(result.metadata[0]!.mappingStatus).toBe("mapped");
    expect(result.metadata[0]!.category).toBe("web");
    expect(result.metadata[0]!.serviceId).toBe("ec2");
  });

  test("usageAccountId が 12 桁数字でなければ AdapterError", () => {
    expect(() =>
      toWorkloadEstimateUsage([webCatalog()], { usageAccountId: "123" }),
    ).toThrow(AdapterError);
    expect(() =>
      toWorkloadEstimateUsage([webCatalog()], { usageAccountId: "abcdefghijkl" }),
    ).toThrow(AdapterError);
  });

  test("batchSize が 1..25 の範囲外なら AdapterError", () => {
    expect(() =>
      toWorkloadEstimateUsage([webCatalog()], {
        usageAccountId: PLACEHOLDER_ACCOUNT_ID,
        batchSize: 0,
      }),
    ).toThrow(AdapterError);
    expect(() =>
      toWorkloadEstimateUsage([webCatalog()], {
        usageAccountId: PLACEHOLDER_ACCOUNT_ID,
        batchSize: 26,
      }),
    ).toThrow(AdapterError);
  });

  test("API 制約超過（operation > 32 文字）の usageType/operation を弾く", () => {
    const bad = webCatalog();
    bad.services[0]!.usages[0]!.operation = "x".repeat(33);
    expect(() =>
      toWorkloadEstimateUsage([bad], { usageAccountId: PLACEHOLDER_ACCOUNT_ID }),
    ).toThrow(/operation/);
  });
});
