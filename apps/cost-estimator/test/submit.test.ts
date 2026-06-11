import { describe, expect, test } from "bun:test";
import {
  buildSubmitCommands,
  SubmitError,
  submitBatches,
  type CommandRunner,
} from "../src/submit";
import type { WorkloadEstimateUsageEntry } from "../src/types";

const VALID_ID = "12345678-90ab-cdef-1234-567890abcdef";

function entry(key: string): WorkloadEstimateUsageEntry {
  return {
    key,
    usageAccountId: "000000000000",
    serviceCode: "AmazonEC2",
    usageType: "APN1-BoxUsage:t3.micro",
    operation: "RunInstances",
    amount: 730,
  };
}

const batches: WorkloadEstimateUsageEntry[][] = [
  [entry("u001"), entry("u002")],
  [entry("u003")],
];

describe("buildSubmitCommands", () => {
  test("batch ごとに 1 コマンドを生成する", () => {
    const cmds = buildSubmitCommands(batches, VALID_ID);
    expect(cmds).toHaveLength(2);
    expect(cmds[0]!.entryCount).toBe(2);
    expect(cmds[1]!.entryCount).toBe(1);
  });

  test("argv に aws CLI のサブコマンドと workload-estimate-id を含む", () => {
    const [cmd] = buildSubmitCommands(batches, VALID_ID);
    expect(cmd!.argv.slice(0, 3)).toEqual([
      "aws",
      "bcm-pricing-calculator",
      "batch-create-workload-estimate-usage",
    ]);
    const idIdx = cmd!.argv.indexOf("--workload-estimate-id");
    expect(idIdx).toBeGreaterThan(-1);
    expect(cmd!.argv[idIdx + 1]).toBe(VALID_ID);
  });

  test("--usage は batch の JSON で、パースし戻せる", () => {
    const [cmd] = buildSubmitCommands(batches, VALID_ID);
    const usageIdx = cmd!.argv.indexOf("--usage");
    expect(usageIdx).toBeGreaterThan(-1);
    const parsed = JSON.parse(cmd!.argv[usageIdx + 1]!);
    expect(parsed).toHaveLength(2);
    expect(parsed[0].key).toBe("u001");
    expect(parsed[0].usageAccountId).toBe("000000000000");
  });

  test("client-token オプションで --client-token を付与する", () => {
    const [cmd] = buildSubmitCommands(batches, VALID_ID, { clientToken: "tok-1" });
    const idx = cmd!.argv.indexOf("--client-token");
    expect(idx).toBeGreaterThan(-1);
    expect(cmd!.argv[idx + 1]).toBe("tok-1");
  });

  test("不正な workload-estimate-id は SubmitError", () => {
    expect(() => buildSubmitCommands(batches, "not-a-uuid")).toThrow(SubmitError);
  });

  test("batch が 25 件を超える場合は SubmitError", () => {
    const big = [Array.from({ length: 26 }, (_, i) => entry(`u${i}`))];
    expect(() => buildSubmitCommands(big, VALID_ID)).toThrow(/25/);
  });
});

describe("submitBatches", () => {
  test("各コマンドを runner で実行し outcome を集約する（実 API は叩かない）", async () => {
    const calls: string[][] = [];
    const runner: CommandRunner = async (argv) => {
      calls.push(argv);
      return { exitCode: 0, stdout: '{"items":[],"errors":[]}', stderr: "" };
    };
    const cmds = buildSubmitCommands(batches, VALID_ID);
    const outcomes = await submitBatches(cmds, { runner });
    expect(calls).toHaveLength(2);
    expect(outcomes.every((o) => o.ok)).toBe(true);
    expect(outcomes[0]!.batchIndex).toBe(0);
    expect(outcomes[0]!.entryCount).toBe(2);
  });

  test("非 0 終了は ok=false として記録する（throw しない）", async () => {
    const runner: CommandRunner = async () => ({
      exitCode: 254,
      stdout: "",
      stderr: "AccessDeniedException",
    });
    const cmds = buildSubmitCommands(batches, VALID_ID);
    const outcomes = await submitBatches(cmds, { runner });
    expect(outcomes.every((o) => !o.ok)).toBe(true);
    expect(outcomes[0]!.stderr).toContain("AccessDenied");
  });
});
