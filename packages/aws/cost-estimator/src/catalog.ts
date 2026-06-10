/**
 * catalog YAML の読み込みと検証。
 * パースは Bun.YAML（ゼロ依存）、検証は本モジュールで行う。
 */
import { join } from "node:path";
import {
  MAPPING_STATUSES,
  type Catalog,
  type CatalogService,
  type CatalogUsage,
  type MappingStatus,
} from "./types";

/** catalog の構造・値が不正な場合に投げる例外。 */
export class CatalogValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CatalogValidationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** `<source>: <field>` 形式の prefix を付けて投げる。 */
function fail(source: string, message: string): never {
  throw new CatalogValidationError(`${source}: ${message}`);
}

function requireString(source: string, obj: Record<string, unknown>, field: string): string {
  const value = obj[field];
  if (typeof value !== "string" || value.length === 0) {
    fail(source, `${field} は非空文字列である必要があります`);
  }
  return value;
}

function parseUsage(source: string, raw: unknown, idx: number): CatalogUsage {
  const where = `${source} usages[${idx}]`;
  if (!isRecord(raw)) {
    fail(where, "オブジェクトである必要があります");
  }
  const billing_axis = requireString(where, raw, "billing_axis");
  const usage_type = requireString(where, raw, "usage_type");
  const unit = requireString(where, raw, "unit");

  const operation = raw.operation;
  if (typeof operation !== "string") {
    fail(where, "operation は文字列である必要があります（空文字可）");
  }

  const amount = raw.amount;
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount < 0) {
    fail(where, "amount は 0 以上の有限数である必要があります");
  }

  const mapping_status = raw.mapping_status;
  if (
    typeof mapping_status !== "string" ||
    !MAPPING_STATUSES.includes(mapping_status as MappingStatus)
  ) {
    fail(
      where,
      `mapping_status は ${MAPPING_STATUSES.join(" / ")} のいずれかである必要があります`,
    );
  }

  return {
    billing_axis,
    usage_type,
    operation,
    unit,
    amount,
    mapping_status: mapping_status as MappingStatus,
  };
}

function parseService(source: string, raw: unknown, idx: number): CatalogService {
  const where = `${source} services[${idx}]`;
  if (!isRecord(raw)) {
    fail(where, "オブジェクトである必要があります");
  }
  const id = requireString(where, raw, "id");
  const service = requireString(where, raw, "service");
  const service_code = requireString(where, raw, "service_code");

  let no_direct_charge: boolean | undefined;
  if (raw.no_direct_charge !== undefined) {
    if (typeof raw.no_direct_charge !== "boolean") {
      fail(where, "no_direct_charge は boolean である必要があります");
    }
    no_direct_charge = raw.no_direct_charge;
  }

  if (!Array.isArray(raw.usages)) {
    fail(where, "usages は配列である必要があります");
  }
  const usages = raw.usages.map((u, i) => parseUsage(`${source} services[${idx}](${id})`, u, i));

  if (no_direct_charge === true && usages.length > 0) {
    fail(where, "no_direct_charge が true のサービスは usages を空にする必要があります");
  }
  if (no_direct_charge !== true && usages.length === 0) {
    fail(where, "課金サービスは usages を 1 件以上持つ必要があります（無料なら no_direct_charge: true）");
  }

  return { id, service, service_code, no_direct_charge, usages };
}

/** 任意の値（YAML パース結果）を検証済み Catalog に変換する。不正なら投げる。 */
export function parseCatalog(raw: unknown, source: string): Catalog {
  if (!isRecord(raw)) {
    fail(source, "catalog はオブジェクトである必要があります");
  }
  const category = requireString(source, raw, "category");
  const description = requireString(source, raw, "description");
  const region = requireString(source, raw, "region");

  if (!Array.isArray(raw.services) || raw.services.length === 0) {
    fail(source, "services は 1 件以上の配列である必要があります");
  }
  const services = raw.services.map((s, i) => parseService(source, s, i));

  return { category, description, region, services };
}

/** YAML 文字列を Bun.YAML でパースしてから検証する。 */
export function parseCatalogYaml(text: string, source: string): Catalog {
  let parsed: unknown;
  try {
    parsed = Bun.YAML.parse(text);
  } catch (cause) {
    throw new CatalogValidationError(
      `${source}: YAML のパースに失敗しました: ${(cause as Error).message}`,
    );
  }
  return parseCatalog(parsed, source);
}

/** 単一の catalog YAML ファイルを読み込む。 */
export async function loadCatalogFile(path: string): Promise<Catalog> {
  const text = await Bun.file(path).text();
  return parseCatalogYaml(text, path);
}

/** catalog ディレクトリの既定パス（このモジュールからの相対）。 */
export function defaultCatalogDir(): string {
  return join(import.meta.dir, "..", "catalog");
}

/**
 * catalog ディレクトリ内の全 `*.yaml` を読み込む。
 * category 名でソートして決定的な順序を返す。
 */
export async function loadAllCatalogs(dir: string = defaultCatalogDir()): Promise<Catalog[]> {
  const glob = new Bun.Glob("*.yaml");
  const files: string[] = [];
  for await (const entry of glob.scan({ cwd: dir, absolute: true })) {
    files.push(entry);
  }
  files.sort();
  const catalogs = await Promise.all(files.map((f) => loadCatalogFile(f)));
  if (catalogs.length === 0) {
    throw new CatalogValidationError(`${dir}: catalog YAML が 1 件も見つかりません`);
  }
  return catalogs.sort((a, b) => a.category.localeCompare(b.category));
}
