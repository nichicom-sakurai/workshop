import { describe, expect, test } from "bun:test";
import {
  CatalogValidationError,
  parseCatalog,
  parseCatalogYaml,
} from "../src/catalog";
import type { Catalog } from "../src/types";

/** テスト用の最小の妥当な catalog オブジェクト。 */
function validCatalogObject(): unknown {
  return {
    category: "web",
    description: "Web 配信レイヤの代表サービス",
    region: "ap-northeast-1",
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

describe("parseCatalog", () => {
  test("妥当な catalog をそのまま受理する", () => {
    const catalog: Catalog = parseCatalog(validCatalogObject(), "web.yaml");
    expect(catalog.category).toBe("web");
    expect(catalog.region).toBe("ap-northeast-1");
    expect(catalog.services).toHaveLength(2);
    expect(catalog.services[0]!.usages[0]!.mapping_status).toBe("mapped");
    expect(catalog.services[1]!.no_direct_charge).toBe(true);
  });

  test("category が無い場合は CatalogValidationError を投げる", () => {
    const bad = validCatalogObject() as Record<string, unknown>;
    delete bad.category;
    expect(() => parseCatalog(bad, "web.yaml")).toThrow(CatalogValidationError);
  });

  test("region が無い場合は弾く", () => {
    const bad = validCatalogObject() as Record<string, unknown>;
    delete bad.region;
    expect(() => parseCatalog(bad, "web.yaml")).toThrow(/region/);
  });

  test("不正な mapping_status を弾く", () => {
    const bad = validCatalogObject() as any;
    bad.services[0].usages[0].mapping_status = "guessed";
    expect(() => parseCatalog(bad, "web.yaml")).toThrow(/mapping_status/);
  });

  test("no_direct_charge なのに usages が空でない場合は弾く", () => {
    const bad = validCatalogObject() as any;
    bad.services[1].no_direct_charge = true;
    bad.services[1].usages = [
      {
        billing_axis: "x",
        usage_type: "y",
        operation: "",
        unit: "Hrs",
        amount: 1,
        mapping_status: "mapped",
      },
    ];
    expect(() => parseCatalog(bad, "iam.yaml")).toThrow(/no_direct_charge/);
  });

  test("amount が負・非数の場合は弾く", () => {
    const bad = validCatalogObject() as any;
    bad.services[0].usages[0].amount = -1;
    expect(() => parseCatalog(bad, "web.yaml")).toThrow(/amount/);

    const bad2 = validCatalogObject() as any;
    bad2.services[0].usages[0].amount = "730";
    expect(() => parseCatalog(bad2, "web.yaml")).toThrow(/amount/);
  });

  test("service_code が無い場合は弾く", () => {
    const bad = validCatalogObject() as any;
    delete bad.services[0].service_code;
    expect(() => parseCatalog(bad, "web.yaml")).toThrow(/service_code/);
  });

  test("operation は空文字を許容する", () => {
    const ok = validCatalogObject() as any;
    ok.services[0].usages[0].operation = "";
    const catalog = parseCatalog(ok, "web.yaml");
    expect(catalog.services[0]!.usages[0]!.operation).toBe("");
  });
});

describe("parseCatalogYaml", () => {
  test("YAML 文字列を Bun.YAML 経由でパースして検証する", () => {
    const yaml = `
category: functions
description: サーバーレス関数の代表サービス
region: ap-northeast-1
services:
  - id: lambda
    service: AWS Lambda
    service_code: AWSLambda
    usages:
      - billing_axis: number of requests
        usage_type: Request
        operation: Invoke
        unit: Requests
        amount: 1000000
        mapping_status: mapped
`;
    const catalog = parseCatalogYaml(yaml, "functions.yaml");
    expect(catalog.category).toBe("functions");
    expect(catalog.services[0]!.usages[0]!.amount).toBe(1000000);
  });

  test("壊れた YAML / 構造はエラーにする", () => {
    expect(() => parseCatalogYaml("category: web\nservices: 1", "web.yaml")).toThrow(
      CatalogValidationError,
    );
  });
});
