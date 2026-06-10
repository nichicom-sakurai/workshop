/**
 * 生成した usage payload を AWS bcm-pricing-calculator API に送信する薄い wrapper。
 *
 * 実行は AWS CLI（`aws bcm-pricing-calculator batch-create-workload-estimate-usage`）への
 * shell-out で行い、認証は AWS CLI 標準の仕組み（env / profile）に委ねる。
 * 認証情報・account ID・profile 名は本リポジトリに保存しない（usageAccountId は呼び出し側が
 * env から注入、workload-estimate-id は CLI 引数で渡す）。
 *
 * コマンド生成（buildSubmitCommands）は副作用の無い純粋関数で、単体テスト可能。
 * 実送信（submitBatches）は runner を注入でき、テストでは実 API を叩かずに検証する。
 */
import { API_LIMITS } from "./adapter";
import type { WorkloadEstimateUsageEntry } from "./types";

/** submit 時の入力検証・実行エラーで投げる例外。 */
export class SubmitError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SubmitError";
  }
}

/** workload-estimate-id（36 文字 UUID）の形式。 */
const WORKLOAD_ESTIMATE_ID_RE =
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

export interface BuildOptions {
  /** べき等性のための client token（任意、1..64 文字）。 */
  clientToken?: string;
}

/** 1 batch を送信する aws CLI コマンド。 */
export interface SubmitCommand {
  batchIndex: number;
  entryCount: number;
  /** 実行する argv（先頭は "aws"）。 */
  argv: string[];
}

/**
 * 各 batch を `aws bcm-pricing-calculator batch-create-workload-estimate-usage` の
 * argv に変換する。実行はしない。
 */
export function buildSubmitCommands(
  batches: WorkloadEstimateUsageEntry[][],
  workloadEstimateId: string,
  options: BuildOptions = {},
): SubmitCommand[] {
  if (!WORKLOAD_ESTIMATE_ID_RE.test(workloadEstimateId)) {
    throw new SubmitError(
      `workload-estimate-id は 36 文字の UUID 形式である必要があります: ${workloadEstimateId}`,
    );
  }
  if (options.clientToken !== undefined) {
    const len = options.clientToken.length;
    if (len < 1 || len > 64) {
      throw new SubmitError("client-token は 1..64 文字である必要があります");
    }
  }

  return batches.map((batch, batchIndex) => {
    if (batch.length === 0) {
      throw new SubmitError(`batch[${batchIndex}] が空です`);
    }
    if (batch.length > API_LIMITS.batchMax) {
      throw new SubmitError(
        `batch[${batchIndex}] の entry 数が API 上限 ${API_LIMITS.batchMax} を超えています: ${batch.length}`,
      );
    }
    const argv = [
      "aws",
      "bcm-pricing-calculator",
      "batch-create-workload-estimate-usage",
      "--workload-estimate-id",
      workloadEstimateId,
      "--usage",
      JSON.stringify(batch),
    ];
    if (options.clientToken !== undefined) {
      argv.push("--client-token", options.clientToken);
    }
    return { batchIndex, entryCount: batch.length, argv };
  });
}

/** argv を実行して結果を返す関数（テストで差し替え可能）。 */
export type CommandRunner = (
  argv: string[],
) => Promise<{ exitCode: number; stdout: string; stderr: string }>;

/** Bun.spawn で実コマンドを実行する既定 runner。 */
export const defaultRunner: CommandRunner = async (argv) => {
  const proc = Bun.spawn(argv, { stdout: "pipe", stderr: "pipe" });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { exitCode, stdout, stderr };
};

export interface SubmitOutcome {
  batchIndex: number;
  entryCount: number;
  ok: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
}

export interface SubmitRunOptions {
  /** 実行 runner（既定: defaultRunner = aws CLI の実行）。 */
  runner?: CommandRunner;
}

/**
 * 各 batch コマンドを順に実行し、batch ごとの結果を集約して返す。
 * 非 0 終了でも throw せず ok=false として記録する（部分的な成功/失敗を可視化するため）。
 */
export async function submitBatches(
  commands: SubmitCommand[],
  options: SubmitRunOptions = {},
): Promise<SubmitOutcome[]> {
  const runner = options.runner ?? defaultRunner;
  const outcomes: SubmitOutcome[] = [];
  for (const cmd of commands) {
    const { exitCode, stdout, stderr } = await runner(cmd.argv);
    outcomes.push({
      batchIndex: cmd.batchIndex,
      entryCount: cmd.entryCount,
      ok: exitCode === 0,
      exitCode,
      stdout,
      stderr,
    });
  }
  return outcomes;
}
