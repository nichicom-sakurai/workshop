/**
 * Issue の Acceptance Criteria を実 catalog に対して検証する受け入れテスト。
 * catalog/*.yaml を実際に読み込み、各カテゴリの代表サービス・課金軸・
 * mapping_status の区別・セキュリティ（account 固有値の不在）を確認する。
 */
import { describe, expect, test } from "bun:test";
import { loadAllCatalogs } from "../src/catalog";
import { PLACEHOLDER_ACCOUNT_ID, toWorkloadEstimateUsage } from "../src/adapter";
import type { Catalog, MappingStatus } from "../src/types";

const catalogs = await loadAllCatalogs();
const byCategory = new Map<string, Catalog>(catalogs.map((c) => [c.category, c]));

function service(category: string, id: string) {
  return byCategory.get(category)?.services.find((s) => s.id === id);
}

function usageTypes(category: string, id: string): string[] {
  return service(category, id)?.usages.map((u) => u.usage_type) ?? [];
}

describe("AC: 5 カテゴリが定義されている", () => {
  test("web / database / container / functions / iam が揃う", () => {
    for (const cat of ["web", "database", "container", "functions", "iam"]) {
      expect(byCategory.has(cat)).toBe(true);
    }
  });
});

describe("AC: web は EC2 / ALB / S3", () => {
  test("3 サービスが service_code 付きで存在する", () => {
    expect(service("web", "ec2")?.service_code).toBe("AmazonEC2");
    expect(service("web", "alb")?.service_code).toBe("AWSELB");
    expect(service("web", "s3")?.service_code).toBe("AmazonS3");
  });
  test("代表的な使用量入力を表現できる", () => {
    expect(usageTypes("web", "ec2").some((u) => u.startsWith("BoxUsage"))).toBe(true);
    expect(usageTypes("web", "alb")).toContain("LoadBalancerUsage");
    expect(usageTypes("web", "s3")).toContain("TimedStorage-ByteHrs");
  });
});

describe("AC: database は RDS の instance / storage / backup", () => {
  test("主要な課金軸が表現されている", () => {
    const types = usageTypes("database", "rds");
    expect(service("database", "rds")?.service_code).toBe("AmazonRDS");
    expect(types.some((u) => u.startsWith("InstanceUsage"))).toBe(true);
    expect(types.some((u) => u.includes("Storage"))).toBe(true);
    expect(types.some((u) => u.includes("Backup"))).toBe(true);
  });
});

describe("AC: container は Fargate の vCPU / memory / 稼働時間", () => {
  test("vCPU-hours と GB-hours が表現されている", () => {
    const types = usageTypes("container", "fargate");
    expect(service("container", "fargate")?.service_code).toBe("AmazonECS");
    expect(types.some((u) => u.includes("vCPU-Hours"))).toBe(true);
    expect(types.some((u) => u.includes("GB-Hours"))).toBe(true);
  });
});

describe("AC: functions は Lambda の request / 実行時間 / memory", () => {
  test("Request と GB-Second（memory×duration）が表現されている", () => {
    const types = usageTypes("functions", "lambda");
    expect(service("functions", "lambda")?.service_code).toBe("AWSLambda");
    expect(types).toContain("Request");
    expect(types).toContain("Lambda-GB-Second");
  });
});

describe("AC: iam は本体を no_direct_charge とし addon を分離する", () => {
  test("IAM 本体は no_direct_charge / Access Analyzer は課金 addon", () => {
    const iam = byCategory.get("iam")!;
    const core = iam.services.find((s) => s.no_direct_charge === true);
    const analyzer = iam.services.find((s) => s.id === "iam-access-analyzer");
    expect(core).toBeDefined();
    expect(core!.usages).toHaveLength(0);
    expect(analyzer).toBeDefined();
    expect(analyzer!.no_direct_charge).not.toBe(true);
    expect(analyzer!.usages.length).toBeGreaterThan(0);
  });
});

describe("AC: mapping_status で mapped / schema_only / needs_research を区別する", () => {
  test("catalog 全体に 3 状態すべてが存在する", () => {
    const seen = new Set<MappingStatus>();
    for (const c of catalogs) {
      for (const s of c.services) {
        for (const u of s.usages) seen.add(u.mapping_status);
      }
    }
    expect(seen.has("mapped")).toBe(true);
    expect(seen.has("schema_only")).toBe(true);
    expect(seen.has("needs_research")).toBe(true);
  });
});

describe("AC: secret / account 固有値 / profile 名を保存しない", () => {
  test("どの文字列フィールドにも 12 桁の account ID らしき値が無い", () => {
    const accountLike = /\b\d{12}\b/;
    const akia = /AKIA[0-9A-Z]{16}/;
    for (const c of catalogs) {
      const blob = JSON.stringify(c);
      expect(blob).not.toMatch(accountLike);
      expect(blob).not.toMatch(akia);
    }
  });
});

describe("実 catalog から adapter が妥当な payload を生成する", () => {
  test("entry が生成され、key が API 制約を満たす", () => {
    const result = toWorkloadEstimateUsage(catalogs, {
      usageAccountId: PLACEHOLDER_ACCOUNT_ID,
    });
    expect(result.entries.length).toBeGreaterThan(0);
    for (const e of result.entries) {
      expect(e.key).toMatch(/^[a-zA-Z0-9]{1,10}$/);
      expect(e.serviceCode.length).toBeLessThanOrEqual(32);
      expect(e.usageType.length).toBeLessThanOrEqual(128);
      expect(e.operation.length).toBeLessThanOrEqual(32);
    }
    expect(result.summary.noDirectChargeServices).toContain("iam/iam");
  });
});
