/**
 * CLI（index.ts）の smoke テスト。実際に `bun run index.ts` を子プロセスで起動し、
 * dry-run の JSON 出力・フィルタ・引数検証を確認する（実 API 送信は行わない）。
 */
import { describe, expect, test } from "bun:test";
import { join } from "node:path";

const PKG_DIR = join(import.meta.dir, "..");

async function runCli(
  args: string[],
  env: Record<string, string> = {},
): Promise<{ exitCode: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn([process.execPath, "run", "index.ts", ...args], {
    cwd: PKG_DIR,
    env: { ...process.env, ...env },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { exitCode, stdout, stderr };
}

describe("dry-run（既定）", () => {
  test("妥当な JSON payload + summary を stdout に出力する", async () => {
    const { exitCode, stdout } = await runCli([]);
    expect(exitCode).toBe(0);
    const doc = JSON.parse(stdout);
    expect(doc.apiOperation).toBe("BatchCreateWorkloadEstimateUsage");
    expect(doc.cliCommand).toContain("bcm-pricing-calculator");
    expect(doc.summary.totalEntries).toBeGreaterThan(0);
    expect(doc.summary.byMappingStatus).toHaveProperty("mapped");
    expect(doc.summary.byMappingStatus).toHaveProperty("needs_research");
    expect(Array.isArray(doc.batches)).toBe(true);
    expect(doc.metadata.length).toBe(doc.summary.totalEntries);
    expect(doc.summary.noDirectChargeServices).toContain("iam/iam");
  });

  test("既定の account ID は placeholder で、実 account を出力しない", async () => {
    const { stdout } = await runCli([]);
    const doc = JSON.parse(stdout);
    expect(doc.usageAccountId).toBe("000000000000");
  });

  test("--account-id で account を上書きできる", async () => {
    const { stdout } = await runCli(["--account-id", "123456789012"]);
    const doc = JSON.parse(stdout);
    expect(doc.usageAccountId).toBe("123456789012");
    expect(doc.batches[0][0].usageAccountId).toBe("123456789012");
  });

  test("AWS_ESTIMATE_ACCOUNT_ID env からも account を取れる", async () => {
    const { stdout } = await runCli([], { AWS_ESTIMATE_ACCOUNT_ID: "210987654321" });
    const doc = JSON.parse(stdout);
    expect(doc.usageAccountId).toBe("210987654321");
  });

  test("--exclude-needs-research で needs_research を除外する", async () => {
    const { stdout } = await runCli(["--exclude-needs-research"]);
    const doc = JSON.parse(stdout);
    const remaining = doc.metadata.filter(
      (m: { mappingStatus: string }) => m.mappingStatus === "needs_research",
    );
    expect(remaining).toHaveLength(0);
    expect(doc.summary.byMappingStatus.needs_research).toBe(0);
  });
});

describe("--help", () => {
  test("usage を表示して exit 0", async () => {
    const { exitCode, stdout } = await runCli(["--help"]);
    expect(exitCode).toBe(0);
    expect(stdout).toContain("cost-estimator");
    expect(stdout).toContain("--submit");
  });
});

describe("--submit の引数検証（実 API は叩かない）", () => {
  test("workload-estimate-id 無しの --submit は exit 非 0 でエラー", async () => {
    const { exitCode, stderr } = await runCli(["--submit"]);
    expect(exitCode).not.toBe(0);
    expect(stderr).toContain("workload-estimate-id");
  });

  test("不正な workload-estimate-id は exit 非 0", async () => {
    const { exitCode } = await runCli(["--submit", "--workload-estimate-id", "bad"]);
    expect(exitCode).not.toBe(0);
  });
});
