/**
 * cost-estimator CLI。
 *
 * 既定（dry-run）: catalog/*.yaml を読み込み、AWS bcm-pricing-calculator の
 *   usage payload + metadata + summary を JSON で stdout に出力する。
 * --submit: 生成した payload を実際に AWS CLI 経由で送信する（AWS 認証が必要）。
 *
 * 認証情報・account ID・profile 名はリポジトリに保存しない。account ID は --account-id /
 * AWS_ESTIMATE_ACCOUNT_ID env / placeholder の順で解決する。
 */
import { parseArgs } from "node:util";
import { CatalogValidationError, loadAllCatalogs } from "./src/catalog";
import { AdapterError, PLACEHOLDER_ACCOUNT_ID, toWorkloadEstimateUsage } from "./src/adapter";
import { buildSubmitCommands, submitBatches } from "./src/submit";
import type { Catalog } from "./src/types";

const USAGE = `cost-estimator — AWS 構成別料金見積もり用 catalog → bcm-pricing-calculator payload

使い方:
  bun run index.ts [options]                  # dry-run: payload を JSON 出力
  bun run index.ts --submit --workload-estimate-id <uuid>   # 実 API へ送信

options:
  --account-id <id>            12 桁 account ID（既定: AWS_ESTIMATE_ACCOUNT_ID env か placeholder）
  --batch-size <n>             1 batch の entry 数（1..25、既定 25）
  --exclude-needs-research     mapping_status=needs_research の usage を除外する
  --submit                     生成した payload を AWS CLI で送信する
  --workload-estimate-id <id>  送信先 workload estimate の ID（--submit 時に必須）
  --client-token <token>       送信のべき等トークン（任意）
  --help                       このヘルプを表示

注意:
  --submit は AWS 認証（env / profile）と aws CLI を使用します。認証情報はリポジトリに保存しません。
  needs_research の usage は usageType が未検証のため、送信すると API に拒否される可能性があります。
`;

interface CliOptions {
  accountId: string;
  batchSize?: number;
  excludeNeedsResearch: boolean;
  submit: boolean;
  workloadEstimateId?: string;
  clientToken?: string;
}

function parseCliArgs(argv: string[]): CliOptions | "help" {
  const { values } = parseArgs({
    args: argv,
    options: {
      "account-id": { type: "string" },
      "batch-size": { type: "string" },
      "exclude-needs-research": { type: "boolean", default: false },
      submit: { type: "boolean", default: false },
      "workload-estimate-id": { type: "string" },
      "client-token": { type: "string" },
      help: { type: "boolean", default: false },
    },
    allowPositionals: false,
  });

  if (values.help) return "help";

  const accountId =
    values["account-id"] ?? process.env.AWS_ESTIMATE_ACCOUNT_ID ?? PLACEHOLDER_ACCOUNT_ID;

  let batchSize: number | undefined;
  if (values["batch-size"] !== undefined) {
    const raw = values["batch-size"];
    if (!/^\d+$/.test(raw)) {
      throw new Error(`--batch-size は正の整数である必要があります: ${raw}`);
    }
    batchSize = Number(raw);
  }

  return {
    accountId,
    excludeNeedsResearch: values["exclude-needs-research"] ?? false,
    submit: values.submit ?? false,
    ...(batchSize !== undefined && { batchSize }),
    ...(values["workload-estimate-id"] !== undefined && {
      workloadEstimateId: values["workload-estimate-id"],
    }),
    ...(values["client-token"] !== undefined && { clientToken: values["client-token"] }),
  };
}

/** needs_research の usage を catalog から除外する（payload には含めない）。 */
function dropNeedsResearch(catalogs: Catalog[]): Catalog[] {
  return catalogs.map((c) => ({
    ...c,
    services: c.services.map((s) => ({
      ...s,
      usages: s.usages.filter((u) => u.mapping_status !== "needs_research"),
    })),
  }));
}

async function main(): Promise<number> {
  let options: CliOptions | "help";
  try {
    options = parseCliArgs(Bun.argv.slice(2));
  } catch (err) {
    console.error(`引数エラー: ${(err as Error).message}`);
    console.error(USAGE);
    return 2;
  }

  if (options === "help") {
    console.log(USAGE);
    return 0;
  }

  let result;
  try {
    let catalogs = await loadAllCatalogs();
    if (options.excludeNeedsResearch) {
      catalogs = dropNeedsResearch(catalogs);
    }
    result = toWorkloadEstimateUsage(catalogs, {
      usageAccountId: options.accountId,
      ...(options.batchSize !== undefined && { batchSize: options.batchSize }),
    });
  } catch (err) {
    // 入力（--account-id / --batch-size）由来のエラーは引数エラーとして exit 2。
    if (err instanceof AdapterError) {
      console.error(`引数エラー: ${err.message}`);
      return 2;
    }
    // catalog 自体の不整合はデータエラーとして exit 1。
    if (err instanceof CatalogValidationError) {
      console.error(`catalog エラー: ${err.message}`);
      return 1;
    }
    throw err;
  }

  if (!options.submit) {
    const doc = {
      apiOperation: "BatchCreateWorkloadEstimateUsage",
      cliCommand: "aws bcm-pricing-calculator batch-create-workload-estimate-usage",
      usageAccountId: options.accountId,
      summary: result.summary,
      batches: result.batches,
      metadata: result.metadata,
    };
    console.log(JSON.stringify(doc, null, 2));
    return 0;
  }

  // --submit: 実 API 送信。
  if (!options.workloadEstimateId) {
    console.error("--submit には --workload-estimate-id <uuid> が必要です");
    return 2;
  }

  if (result.summary.totalEntries === 0) {
    console.error("[WARNING] 送信対象の entry がありません（フィルタで全て除外された可能性があります）。送信を中止します。");
    return 1;
  }

  const needsResearch = result.summary.byMappingStatus.needs_research;
  if (needsResearch > 0) {
    console.error(
      `[WARNING] needs_research の usage が ${needsResearch} 件含まれています。usageType が未検証のため API に拒否される可能性があります（--exclude-needs-research で除外できます）。`,
    );
  }

  let commands;
  try {
    commands = buildSubmitCommands(result.batches, options.workloadEstimateId, {
      ...(options.clientToken !== undefined && { clientToken: options.clientToken }),
    });
  } catch (err) {
    console.error(`送信コマンド生成エラー: ${(err as Error).message}`);
    return 2;
  }

  console.error(`[INFO] ${commands.length} batch（計 ${result.summary.totalEntries} entry）を送信します...`);
  const outcomes = await submitBatches(commands);

  for (const o of outcomes) {
    if (o.ok) {
      console.error(`[OK] batch ${o.batchIndex}: ${o.entryCount} entry 送信成功`);
      if (o.stdout) console.log(o.stdout);
    } else {
      console.error(
        `[NG] batch ${o.batchIndex}: exit ${o.exitCode} ${o.stderr.split("\n")[0] ?? ""}`,
      );
    }
  }

  const failed = outcomes.filter((o) => !o.ok).length;
  return failed === 0 ? 0 : 1;
}

process.exit(await main());
